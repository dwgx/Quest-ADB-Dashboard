#!/usr/bin/env python3
"""Control MCP server for Quest ADB Dashboard.

This server is SEPARATE from the read-only ``quest_adb_safe_mcp.py``. It can
change Quest state (screenshots, key events, taps, launching apps, wake/sleep),
so every state-changing tool uses a strict two-phase confirmation:

1. First call with ``confirm=False`` (the default) never changes device state.
   It issues only read-only probes (adb devices -l, dumpsys power) and then
   returns a preview: the exact adb command that would run, a human-readable
   risk note, and ``requires_confirmation: True``.
2. Only a second call with ``confirm=True`` actually runs the command.

Even with ``confirm=True`` this server still HARD-BLOCKS irreversible or
high-risk families (install, uninstall, reboot, tcpip, usb, push, pull,
pm clear/disable/enable, settings put for system-critical keys, factory reset,
root/remount). Those are never exposed by any tool here.

Honest capability boundary: adb cannot emulate the Quest's 6DoF VR controllers
(laser pointer + trigger). Quest controllers are independent Bluetooth HID
devices and are not present in the headset's /dev/input. This server can only
inject Android-layer input (keyevents, taps/swipes on 2D system panels, text)
and launch apps. Coordinate taps only make sense on 2D system surfaces such as
Settings or the browser, not inside immersive VR scenes.
"""

from __future__ import annotations

import io
import os
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP, Image
from mcp.types import ToolAnnotations


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCREENSHOT_DIR = ROOT / "Quest_ADB_Logs" / "control-screenshots"
MAX_OUTPUT_CHARS = 120_000

# Longest edge (px) for the image returned inline to the agent. The full-res
# file is always kept on disk; only the inline copy is downscaled so a single
# screenshot cannot blow up the model's context window.
INLINE_SCREENSHOT_MAX_EDGE = 1024

# MCP tool annotations (spec rev 2025-03-26) are advisory hints clients use to
# decide confirmation UX. They are NOT the enforcement layer: the real
# guarantees here are the two-phase confirm, the hard-block policy, and the
# metacharacter guards. Defaults in the spec are pessimistic (destructive,
# non-read-only, open-world), so annotating is purely additive safety signal.
READ_ONLY = ToolAnnotations(readOnlyHint=True, destructiveHint=False, idempotentHint=True, openWorldHint=False)
# State-changing but reversible and safe to repeat (tap/keyevent/wake/sleep).
REVERSIBLE = ToolAnnotations(readOnlyHint=False, destructiveHint=False, idempotentHint=False, openWorldHint=False)

INSTRUCTIONS = (
    "Quest ADB control bridge for authorized local Quest devices. Every "
    "state-changing tool is two-phase: the first call with confirm=False only "
    "returns a preview of the exact adb command and never touches the device; "
    "a second call with confirm=True runs it. This server still hard-blocks "
    "install, uninstall, reboot, tcpip, usb, push, pull, pm clear/disable/"
    "enable, factory reset, root, and remount. It cannot emulate VR controllers."
)

mcp = FastMCP("quest-adb-control", instructions=INSTRUCTIONS, log_level="ERROR")


# --- shared adb discovery / device selection (mirrors quest_adb_safe_mcp) ---

def _sdk_root_candidates() -> list[str]:
    # Generic scan for platform-tools\adb.exe under common Android SDK roots on
    # each available drive. Replaces an author-specific hardcoded path while
    # staying discoverable on machines where adb is not on PATH.
    found: list[str] = []
    for drive in ("C:", "D:", "E:"):
        if not Path(drive + "\\").exists():
            continue
        for sub in (r"\Software\Android\Sdk\platform-tools\adb.exe",
                    r"\Android\Sdk\platform-tools\adb.exe"):
            found.append(drive + sub)
    return found


def _find_adb() -> str:
    env_adb = os.environ.get("ADB_EXE")
    candidates = [
        env_adb,
        shutil.which("adb"),
        str(ROOT / "adb.exe"),
        str(ROOT / "platform-tools" / "adb.exe"),
        str(ROOT / "tools" / "adb.exe"),
        str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / "adb.exe"),
        *_sdk_root_candidates(),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Android" / "platform-tools" / "adb.exe"),
        str(Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Android" / "platform-tools" / "adb.exe"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "SideQuest" / "resources" / "app.asar.unpacked" / "build" / "platform-tools" / "adb.exe"),
        str(Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "SideQuest" / "resources" / "app.asar.unpacked" / "build" / "platform-tools" / "adb.exe"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Oculus" / "Support" / "oculus-diagnostics" / "adb.exe"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Meta Quest Developer Hub" / "resources" / "bin" / "adb.exe"),
        str(Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Meta Quest Developer Hub" / "resources" / "bin" / "adb.exe"),
        r"D:\Software\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    raise FileNotFoundError("adb.exe not found. Set ADB_EXE or install Android platform-tools.")


SERIAL_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


def _validate_serial(serial: str) -> str:
    if not serial or not SERIAL_RE.fullmatch(serial):
        raise ValueError("Invalid ADB serial. Use a value returned by list_devices().")
    return serial


# --- hard-block policy (applies even when confirm=True) ---
#
# SECURITY INVARIANT: No @mcp.tool must ever forward a caller-supplied
# free-form shell/adb string. Every tool builds a fixed argv from validated
# params. The hard-block denylist below is defense-in-depth for that
# internally built argv, NOT the primary gate. If a future tool needs to
# accept a shell string, this denylist model is insufficient -- switch to an
# allowlist.

BLOCKED_ADB_COMMANDS = {
    "install", "install-multiple", "install-multi-package",
    "uninstall", "push", "pull", "reboot", "tcpip", "usb",
    "root", "unroot", "remount", "sideload", "sync", "bugreport",
    "backup", "restore", "disable-verity", "enable-verity", "emu",
}

BLOCKED_SHELL_PREFIXES = (
    ("pm", "clear"),
    ("pm", "disable"),
    ("pm", "disable-user"),
    ("pm", "enable"),
    ("pm", "hide"),
    ("pm", "install"),
    ("pm", "suspend"),
    ("pm", "uninstall"),
    ("pm", "revoke"),
    ("pm", "set-app-link"),
    # cmd is an alias surface that re-reaches pm/settings; block the
    # destructive cmd forms (a benign read like `cmd package list` is fine).
    ("cmd", "package", "uninstall"),
    ("cmd", "package", "clear"),
    ("cmd", "package", "install"),
    ("cmd", "settings", "put"),
    ("cmd", "settings", "delete"),
    ("svc", "power", "reboot"),
    ("svc", "power", "shutdown"),
    ("svc", "wifi", "disable"),
    ("svc", "data", "disable"),
    ("svc", "bluetooth", "disable"),
    ("am", "force-stop"),
    ("am", "kill"),
    ("am", "kill-all"),
    ("appops", "set"),
    ("ime", "disable"),
    ("bmgr", "wipe"),
    ("stop",),
    ("start",),
    ("reboot",),
    ("recovery",),
    ("halt",),
    ("poweroff",),
    ("killall",),
    ("pkill",),
    ("rm",),
    ("mv",),
    ("cp",),
    ("dd",),
    ("mkfs",),
    ("make_ext4fs",),
    ("fsck",),
    ("truncate",),
    ("blockdev",),
    ("format",),
    ("wipe",),
    ("fastboot",),
    ("bootloader",),
    ("setprop", "ctl.start"),
    ("setprop", "ctl.stop"),
    ("setprop", "sys.powerctl"),
)

# Intent action strings that trigger factory reset / shutdown when broadcast.
# `am`/`am broadcast` is otherwise allowed (capture_screenshot needs am startservice).
BLOCKED_INTENT_ACTIONS = (
    "android.intent.action.master_clear",
    "android.intent.action.factory_reset",
    "com.android.internal.intent.action.request_shutdown",
    "android.intent.action.reboot",
    "masterclear",
)

# settings put keys that could brick or factory-touch the device
BLOCKED_SETTINGS_KEYS = (
    "device_provisioned",
    "user_setup_complete",
)

ADB_OPTIONS_WITH_VALUE = {"-s", "-t", "-H", "-P", "-L"}
ADB_OPTIONS_WITHOUT_VALUE = {"-a", "-d", "-e"}


def _shell_words(command: str) -> list[str]:
    return [part for part in re.split(r"\s+", command.strip()) if part]


def _has_prefix(words: list[str], prefix: tuple[str, ...]) -> bool:
    return len(words) >= len(prefix) and tuple(w.lower() for w in words[: len(prefix)]) == prefix


def _adb_command_words(args: list[str]) -> list[str]:
    index = 0
    while index < len(args):
        arg = args[index]
        if arg in ADB_OPTIONS_WITH_VALUE:
            index += 2
            continue
        if arg in ADB_OPTIONS_WITHOUT_VALUE:
            index += 1
            continue
        break
    return args[index:]


def _refuse_if_hard_blocked(argv: list[str]) -> None:
    """Refuse irreversible/high-risk commands even under confirm=True.

    Skips ADB global options (e.g. ``-s SERIAL``) before inspecting the real
    subcommand, so ``adb -s SERIAL reboot`` is still blocked.
    """
    args = [item.lower() for item in argv[1:]]
    rendered = " ".join(argv)
    command_words = _adb_command_words(args)
    if command_words and command_words[0] in BLOCKED_ADB_COMMANDS:
        raise ValueError(f"Hard-blocked state-changing ADB command: {rendered}")

    # exec-out also runs its argument on the device via sh (just with raw
    # binary stdout), so apply the same metacharacter refusal there. The
    # screenshot pull (`exec-out cat <devicepath>`) interpolates a
    # device-supplied filename, which is separately charset-validated.
    if "exec-out" in args:
        eo_index = args.index("exec-out")
        eo_blob = " ".join(args[eo_index + 1 :])
        if re.search(r"[;&|\n\r`$><]", eo_blob):
            raise ValueError(f"Refusing exec-out command with chaining/substitution metacharacters: {rendered}")

    if "shell" not in args:
        return
    shell_index = args.index("shell")
    shell_blob = " ".join(args[shell_index + 1 :])

    # The device runs shell args through /system/bin/sh, where ; & | newline
    # $() `` and redirection chain or hide additional commands. The prefix
    # checks below only see the first word, so any metacharacter that could
    # smuggle a second command is refused outright. This closes the
    # `input text x;reboot` / `$(...)` / `${IFS}` class of bypass.
    if re.search(r"[;&|\n\r`$><]", shell_blob):
        raise ValueError(f"Refusing shell command with chaining/substitution metacharacters: {rendered}")

    shell_words = _shell_words(shell_blob)
    if not shell_words:
        raise ValueError(f"Refusing empty arbitrary shell: {rendered}")
    for prefix in BLOCKED_SHELL_PREFIXES:
        if _has_prefix(shell_words, prefix):
            raise ValueError(f"Hard-blocked state-changing shell command: {rendered}")
    if _has_prefix(shell_words, ("settings", "put")):
        for key in BLOCKED_SETTINGS_KEYS:
            if key in shell_words:
                raise ValueError(f"Hard-blocked critical settings key: {rendered}")
    # Factory-reset / shutdown intents fired via am broadcast.
    for action in BLOCKED_INTENT_ACTIONS:
        if action in shell_words:
            raise ValueError(f"Hard-blocked factory-reset/shutdown intent: {rendered}")


def _run_adb(args: list[str], timeout_seconds: float = 10.0) -> dict[str, Any]:
    adb = _find_adb()
    argv = [adb] + args
    _refuse_if_hard_blocked(argv)
    started = time.monotonic()
    proc = subprocess.run(
        argv,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=max(1.0, min(float(timeout_seconds), 60.0)),
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    return {
        "adb": adb,
        "args": args,
        "command": " ".join(argv),
        "exit_code": proc.returncode,
        "stdout": proc.stdout[-MAX_OUTPUT_CHARS:],
        "stderr": proc.stderr[-MAX_OUTPUT_CHARS:],
        "duration_ms": int((time.monotonic() - started) * 1000),
    }


def _run_adb_binary(args: list[str], timeout_seconds: float = 20.0) -> bytes:
    adb = _find_adb()
    argv = [adb] + args
    _refuse_if_hard_blocked(argv)
    proc = subprocess.run(
        argv,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=max(1.0, min(float(timeout_seconds), 60.0)),
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", "replace")[:2000] or "adb binary read failed")
    return proc.stdout


def _parse_devices(text: str) -> list[dict[str, str]]:
    devices: list[dict[str, str]] = []
    for raw in text.splitlines()[1:]:
        line = raw.strip()
        if not line:
            continue
        parts = line.split()
        serial = parts[0] if parts else ""
        state = parts[1] if len(parts) > 1 else "unknown"
        attrs: dict[str, str] = {}
        for item in parts[2:]:
            if ":" in item:
                key, value = item.split(":", 1)
                attrs[key] = value
        devices.append({"serial": serial, "state": state, "line": line, **attrs})
    return devices


def _select_device(serial: str | None = None) -> dict[str, Any]:
    listed = _run_adb(["devices", "-l"], timeout_seconds=6)
    devices = _parse_devices(listed["stdout"])
    if serial:
        serial = _validate_serial(serial)
        matches = [d for d in devices if d.get("serial") == serial]
        if not matches:
            return {"ok": False, "reason": "requested serial not found", "devices": devices}
        return {"ok": True, "device": matches[0], "devices": devices}
    online = [d for d in devices if d.get("state") == "device"]
    quest = [
        d for d in online
        if "Quest" in d.get("model", "") or d.get("product") == "eureka" or d.get("device") == "eureka"
    ]
    usb_quest = [d for d in quest if ":" not in d.get("serial", "")]
    pool = usb_quest or quest or online
    if not pool:
        return {"ok": False, "reason": "no authorized online device", "devices": devices}
    return {"ok": True, "device": pool[0], "devices": devices}


def _is_awake(serial: str) -> bool:
    try:
        res = _run_adb(["-s", serial, "shell", "dumpsys", "power"], timeout_seconds=8)
        return "mWakefulness=Awake" in res.get("stdout", "")
    except Exception:
        return False


# --- perception helpers (read-only): let the agent "see" the screen ---

def _list_displays(serial: str) -> list[dict[str, Any]]:
    """Enumerate displays with id + resolution. Quest renders each 2D panel on
    its own virtual display, so the agent must know which display to act on."""
    displays: list[dict[str, Any]] = []
    try:
        res = _run_adb(["-s", serial, "shell", "dumpsys", "SurfaceFlinger", "--display-id"], timeout_seconds=8)
        # lines like: Display 4630946882202380434 (HWC display 0): ... 4128x2208
        for line in res.get("stdout", "").splitlines():
            m = re.search(r"Display\s+(\d+)\s+\(.*?display\s+(\d+)\)", line)
            if m:
                displays.append({"display_token": m.group(1), "display_id": int(m.group(2)), "line": line.strip()})
    except Exception:
        pass
    return displays


def _focused_state(serial: str) -> dict[str, Any]:
    """Return focused package/activity/display so the agent is grounded before
    it taps. On Quest, global focus on display 0 is often null while a panel is
    focused on its own virtual display, so report all non-null focus windows."""
    state: dict[str, Any] = {"focused_windows": []}
    try:
        res = _run_adb(["-s", serial, "shell", "dumpsys", "window", "displays"], timeout_seconds=8)
        out = res.get("stdout", "")
        cur_display = None
        for line in out.splitlines():
            dm = re.search(r"Display:\s+mDisplayId=(\d+)", line)
            if dm:
                cur_display = int(dm.group(1))
            fm = re.search(r"mCurrentFocus=Window\{[^ ]+ \S+ (\S+)\}", line)
            if fm and "null" not in line:
                state["focused_windows"].append({"display_id": cur_display, "window": fm.group(1)})
    except Exception:
        pass
    try:
        act = _run_adb(["-s", serial, "shell", "dumpsys", "activity", "activities"], timeout_seconds=8)
        rm = re.search(r"(?:topResumedActivity|ResumedActivity).*?(\S+/\S+)", act.get("stdout", ""))
        if rm:
            state["resumed_activity"] = rm.group(1).rstrip("}")
    except Exception:
        pass
    return state


_BOUNDS_RE = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")


def _parse_ui_nodes(xml_text: str, max_nodes: int = 80) -> list[dict[str, Any]]:
    """Parse a uiautomator hierarchy XML into a compact, token-frugal list of
    interactable elements with server-computed tap centers. Mirrors the
    mobile-mcp/AutoDroid filter: keep only nodes that carry text/desc/id or are
    clickable, drop zero-size rects, and emit a flat list with stable ids."""
    try:
        # uiautomator brackets the XML with noise: a possible leading
        # "UI hierarchy dumped..." line and a trailing one appended AFTER
        # </hierarchy>. Slice to the XML declaration and to the closing tag so
        # ElementTree doesn't choke on "junk after document element".
        start = xml_text.find("<?xml")
        if start < 0:
            start = xml_text.find("<hierarchy")
        end = xml_text.rfind("</hierarchy>")
        if start < 0 or end < 0:
            return []
        root = ET.fromstring(xml_text[start:end + len("</hierarchy>")])
    except ET.ParseError:
        return []
    nodes: list[dict[str, Any]] = []
    for el in root.iter("node"):
        text = (el.get("text") or "").strip()
        desc = (el.get("content-desc") or "").strip()
        rid = (el.get("resource-id") or "").strip()
        clickable = el.get("clickable") == "true"
        if not (text or desc or (rid and clickable) or clickable):
            continue
        m = _BOUNDS_RE.fullmatch(el.get("bounds", "") or "")
        if not m:
            continue
        l, t, r, b = (int(g) for g in m.groups())
        if r - l <= 0 or b - t <= 0:
            continue
        nodes.append({
            "id": len(nodes),
            "text": text[:80],
            "desc": desc[:80],
            "resource_id": rid.split("/")[-1][:48],
            "clickable": clickable,
            "bounds": [l, t, r, b],
            "center": [(l + r) // 2, (t + b) // 2],
        })
        if len(nodes) >= max_nodes:
            break
    return nodes


def _uiautomator_dump(serial: str) -> str:
    """Dump the focused window's UI hierarchy as XML via exec-out (no on-device
    file). Retries because uiautomator can transiently return a null root."""
    for _ in range(6):
        try:
            data = _run_adb_binary(["-s", serial, "exec-out", "uiautomator", "dump", "/dev/tty"], timeout_seconds=12)
        except Exception:
            time.sleep(0.4)
            continue
        text = data.decode("utf-8", "replace")
        if "<?xml" in text and "<hierarchy" in text:
            return text
        time.sleep(0.4)
    return ""


# in-process cache of the last observed elements, keyed by serial, so
# tap_element(id) can resolve an id to its server-computed center.
_LAST_OBSERVATION: dict[str, list[dict[str, Any]]] = {}


# --- two-phase confirmation helper ---

def _is_confirmed(confirm: Any) -> bool:
    """Strictly interpret the confirm flag.

    A real ``True`` confirms. The literal strings ``"true"``/``"1"``/``"yes"``
    (case-insensitive) also confirm, because some MCP transports deliver bools
    as strings. Everything else — including the string ``"false"`` (which is
    truthy in plain Python) and any unexpected value — is treated as NOT
    confirmed, so it stays in preview mode and never touches the device.
    """
    if confirm is True:
        return True
    if isinstance(confirm, str):
        return confirm.strip().lower() in {"true", "1", "yes"}
    if isinstance(confirm, (int, float)) and not isinstance(confirm, bool):
        return confirm == 1
    return False


def _preview(action: str, argv_tail: list[str], risk: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    payload = {
        "ok": True,
        "requires_confirmation": True,
        "executed": False,
        "action": action,
        "would_run": "adb " + " ".join(argv_tail),
        "risk": risk,
        "how_to_proceed": f"Call {action}(..., confirm=True) to execute. The device is untouched until then.",
    }
    if extra:
        payload.update(extra)
    return payload


# allowlisted, reversible Android key events
KEYEVENT_WHITELIST = {
    "HOME": "KEYCODE_HOME",
    "BACK": "KEYCODE_BACK",
    "ENTER": "KEYCODE_ENTER",
    "DPAD_UP": "KEYCODE_DPAD_UP",
    "DPAD_DOWN": "KEYCODE_DPAD_DOWN",
    "DPAD_LEFT": "KEYCODE_DPAD_LEFT",
    "DPAD_RIGHT": "KEYCODE_DPAD_RIGHT",
    "DPAD_CENTER": "KEYCODE_DPAD_CENTER",
    "VOLUME_UP": "KEYCODE_VOLUME_UP",
    "VOLUME_DOWN": "KEYCODE_VOLUME_DOWN",
    "VOLUME_MUTE": "KEYCODE_VOLUME_MUTE",
    "MEDIA_PLAY_PAUSE": "KEYCODE_MEDIA_PLAY_PAUSE",
    "MEDIA_NEXT": "KEYCODE_MEDIA_NEXT",
    "MEDIA_PREVIOUS": "KEYCODE_MEDIA_PREVIOUS",
    "APP_SWITCH": "KEYCODE_APP_SWITCH",
    "WAKEUP": "KEYCODE_WAKEUP",
    "SLEEP": "KEYCODE_SLEEP",
}


@mcp.tool(annotations=READ_ONLY)
def control_policy() -> dict[str, Any]:
    """Return this control server's safety policy and capability boundary."""
    return {
        "mode": "control (two-phase confirmation)",
        "confirmation": "Every state-changing tool defaults to confirm=False (preview only). Pass confirm=True to execute.",
        "hard_blocked_adb": sorted(BLOCKED_ADB_COMMANDS),
        "hard_blocked_shell_prefixes": [" ".join(p) for p in BLOCKED_SHELL_PREFIXES],
        "hard_blocked_intent_actions": list(BLOCKED_INTENT_ACTIONS),
        "shell_metacharacters_refused": "; & | newline $ ` < > and ${ are refused so free text cannot chain a second device command",
        "keyevent_whitelist": sorted(KEYEVENT_WHITELIST),
        "perception": (
            "observe_screen (read-only) reports focused window/activity, the display list, and a flat list "
            "of interactable elements (text/desc/bounds/center) parsed from uiautomator. Use it before tapping, "
            "then tap_element(id) or tap(x,y,display_id=...). Falls back to capture_screenshot for surfaces with no hierarchy."
        ),
        "capability_boundary": [
            "Can: native screenshot (returned inline as an image), whitelisted keyevents, observe_screen perception, "
            "tap/swipe/tap_element on 2D system panels, text input, launch apps, wake/sleep.",
            "Cannot: emulate 6DoF VR controllers (laser + trigger) - controllers are Bluetooth HID, not in /dev/input.",
            "Quest renders each 2D panel on its own virtual display. A plain tap hits the default display (0), which is the "
            "empty composited buffer; target the panel's display_id with display-local coordinates (verified: input -d works, "
            "but driving a panel requires the correct display + local coords). Immersive VR scenes are not tappable.",
            "Screenshot requires the headset to be awake/worn; an asleep headset produces no image.",
        ],
        "never_exposed": "No install/uninstall/reboot/tcpip/usb/push/pull/pm clear-disable/factory-reset tool exists here.",
        "preview_note": "confirm=False issues only read-only probes (adb devices -l, dumpsys power) to build the preview; it never changes device state.",
    }


@mcp.tool(annotations=READ_ONLY)
def list_devices() -> dict[str, Any]:
    """List ADB devices with transport state. Read-only."""
    try:
        result = _run_adb(["devices", "-l"], timeout_seconds=6)
        return {"ok": result["exit_code"] == 0, "result": result, "devices": _parse_devices(result["stdout"])}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@mcp.tool(annotations=READ_ONLY)
def observe_screen(serial: str | None = None, include_elements: bool = True) -> dict[str, Any]:
    """Perceive the current screen so you can decide what to tap. Read-only.

    Returns grounding context plus a flat list of interactable UI elements with
    server-computed tap centers, so a screenshot->reason->tap loop can run
    without guessing coordinates:

      {
        "ok": true,
        "focused": {"focused_windows": [{"display_id": 0, "window": "..."}],
                    "resumed_activity": "pkg/.Activity"},
        "displays": [{"display_id": 0, ...}],   # Quest panels live on their own display
        "elements": [{"id": 3, "text": "Wi-Fi", "desc": "", "resource_id": "...",
                      "clickable": true, "bounds": [l,t,r,b], "center": [x,y]}],
        "element_source": "uiautomator" | "none"
      }

    Pass an element id to tap_element(id, confirm=True) to act on it. If
    "elements" is empty (immersive VR or custom-drawn surfaces have no
    hierarchy), fall back to capture_screenshot and reason over the image.
    """
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    observation: dict[str, Any] = {
        "ok": True,
        "device": selected["device"],
        "focused": _focused_state(serial_value),
        "displays": _list_displays(serial_value),
        "elements": [],
        "element_source": "none",
    }
    if include_elements:
        xml_text = _uiautomator_dump(serial_value)
        if xml_text:
            elements = _parse_ui_nodes(xml_text)
            observation["elements"] = elements
            observation["element_source"] = "uiautomator" if elements else "none"
            _LAST_OBSERVATION[serial_value] = elements
        else:
            observation["hint"] = (
                "No UI hierarchy available (immersive VR scene or custom surface). "
                "Use capture_screenshot and reason over the image instead."
            )
    return observation


def _downscale_for_inline(data: bytes) -> tuple[bytes, str, dict[str, Any]]:
    """Return a context-friendly inline copy of a screenshot: downscale the
    longest edge to INLINE_SCREENSHOT_MAX_EDGE and JPEG-encode. Falls back to
    the original bytes if Pillow is unavailable. The full-res file on disk is
    untouched; only this inline copy is shrunk to protect the context window."""
    try:
        from PIL import Image as PILImage
    except Exception:
        return data, "png", {"inline_downscaled": False, "reason": "Pillow not installed"}
    try:
        im = PILImage.open(io.BytesIO(data))
        orig = im.size
        im = im.convert("RGB")
        longest = max(im.size)
        if longest > INLINE_SCREENSHOT_MAX_EDGE:
            scale = INLINE_SCREENSHOT_MAX_EDGE / longest
            im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))))
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=70)
        return buf.getvalue(), "jpeg", {"inline_downscaled": True, "original_size": list(orig), "inline_size": list(im.size)}
    except Exception as exc:
        return data, "png", {"inline_downscaled": False, "reason": str(exc)[:120]}


@mcp.tool(annotations=REVERSIBLE)
def capture_screenshot(
    serial: str | None = None,
    output_dir: str | None = None,
    return_image: bool = True,
    confirm: bool = False,
) -> Any:
    """Trigger a native Quest screenshot and pull it to the local workspace.

    Two-phase: confirm=False returns a preview only. Requires the headset to be
    awake; an asleep/unworn headset will not produce an image.

    On confirm=True, returns the screenshot inline (downscaled JPEG image
    content) so you can actually see the screen and decide the next action,
    alongside a text record with the full-resolution local_path and device_path.
    Set return_image=False to skip the inline image and get only the metadata.
    """
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    trigger = ["-s", serial_value, "shell", "am", "startservice", "-n",
               "com.oculus.metacam/.capture.CaptureService", "-a", "TAKE_SCREENSHOT"]
    if not _is_confirmed(confirm):
        return _preview(
            "capture_screenshot",
            trigger,
            "Triggers the headset's own screenshot service, then pulls the newest image to the PC. "
            "Non-destructive, but the headset must be awake/worn or no image is produced.",
            {"device": selected["device"], "awake": _is_awake(serial_value)},
        )

    if not _is_awake(serial_value):
        return {
            "ok": False, "executed": False,
            "reason": "headset is asleep; screenshot service produces no image. Wake/wear the headset first (or use wake_headset).",
            "device": selected["device"],
        }

    before = _run_adb(["-s", serial_value, "shell", "ls", "-t", "/sdcard/Oculus/Screenshots/"], timeout_seconds=8)
    before_set = set(before.get("stdout", "").split())
    trig = _run_adb(trigger, timeout_seconds=10)
    newest = None
    for _ in range(10):
        time.sleep(0.6)
        listing = _run_adb(["-s", serial_value, "shell", "ls", "-t", "/sdcard/Oculus/Screenshots/"], timeout_seconds=8)
        names = [n for n in listing.get("stdout", "").split() if n.lower().endswith((".png", ".jpg"))]
        # Only accept simple, safe filenames. `newest` is device-supplied and is
        # interpolated into an `exec-out cat <path>` that the device runs via sh,
        # so a planted name like `$(reboot).png` would otherwise execute. The
        # exec-out path does not pass through the shell metacharacter guard.
        names = [n for n in names if re.fullmatch(r"[A-Za-z0-9._-]{1,128}", n)]
        fresh = [n for n in names if n not in before_set]
        if fresh:
            newest = fresh[0]
            break
    if not newest:
        return {"ok": False, "executed": True, "trigger": trig,
                "reason": "no new screenshot appeared in /sdcard/Oculus/Screenshots/ within timeout.",
                "device": selected["device"]}

    out_root = Path(output_dir).resolve() if output_dir else DEFAULT_SCREENSHOT_DIR
    out_root.mkdir(parents=True, exist_ok=True)
    local_path = out_root / newest
    data = _run_adb_binary(["-s", serial_value, "exec-out", "cat", f"/sdcard/Oculus/Screenshots/{newest}"], timeout_seconds=30)
    local_path.write_bytes(data)
    record = {
        "ok": True, "executed": True, "device": selected["device"],
        "device_path": f"/sdcard/Oculus/Screenshots/{newest}",
        "local_path": str(local_path), "bytes": len(data),
    }
    if not return_image:
        return record
    inline, fmt, meta = _downscale_for_inline(data)
    record.update(meta)
    # Mixed return: the agent sees the image AND gets the structured record.
    return [Image(data=inline, format=fmt), record]


@mcp.tool(annotations=REVERSIBLE)
def send_keyevent(key: str, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Send one whitelisted Android key event (HOME/BACK/DPAD/VOLUME/MEDIA/...).

    Two-phase: confirm=False returns a preview only.
    """
    # Accept both short ("HOME") and full ("KEYCODE_HOME") forms; the full
    # form is what adb uses and what most callers/LLMs reach for first.
    key_upper = key.strip().upper()
    if key_upper.startswith("KEYCODE_"):
        key_upper = key_upper[len("KEYCODE_"):]
    if key_upper not in KEYEVENT_WHITELIST:
        return {"ok": False, "error": f"key not in whitelist: {key}", "allowed": sorted(KEYEVENT_WHITELIST)}
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    keycode = KEYEVENT_WHITELIST[key_upper]
    argv = ["-s", serial_value, "shell", "input", "keyevent", keycode]
    if not _is_confirmed(confirm):
        return _preview("send_keyevent", argv, f"Injects Android key event {keycode}. Reversible.",
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=8)
    return {"ok": result["exit_code"] == 0, "executed": True, "key": keycode, "result": result, "device": selected["device"]}


@mcp.tool(annotations=REVERSIBLE)
def tap(x: int, y: int, display_id: int | None = None, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Tap at (x, y). Only meaningful on 2D system panels, not VR scenes.

    On Quest, each 2D panel renders on its own virtual display. If a tap seems
    to do nothing, call observe_screen first: act on the display_id its
    "focused" / "displays" report, and pass coordinates LOCAL to that display
    (origin 0,0 at the panel's top-left). Without display_id the tap goes to the
    default display (0), which on Quest is the empty composited buffer.

    Two-phase: confirm=False returns a preview only.
    """
    if not (0 <= int(x) <= 20000 and 0 <= int(y) <= 20000):
        return {"ok": False, "error": "x/y out of sane range"}
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    disp = ["-d", str(int(display_id))] if display_id is not None else []
    argv = ["-s", serial_value, "shell", "input", *disp, "tap", str(int(x)), str(int(y))]
    if not _is_confirmed(confirm):
        return _preview("tap", argv, f"Injects a tap at ({int(x)},{int(y)})"
                        + (f" on display {int(display_id)}" if display_id is not None else " on the default display"),
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=8)
    return {"ok": result["exit_code"] == 0, "executed": True, "result": result, "device": selected["device"]}


@mcp.tool(annotations=REVERSIBLE)
def tap_element(element_id: int, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Tap a UI element by its id from the most recent observe_screen call.

    Resolves the element's server-computed center so you never compute pixel
    coordinates yourself. Call observe_screen first to populate the element
    list, then tap_element(element_id, confirm=True).

    Two-phase: confirm=False returns a preview only.
    """
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    elements = _LAST_OBSERVATION.get(serial_value, [])
    match = next((e for e in elements if e["id"] == int(element_id)), None)
    if match is None:
        return {"ok": False, "error": f"element id {element_id} not found; call observe_screen first to refresh the element list",
                "available_ids": [e["id"] for e in elements]}
    cx, cy = match["center"]
    return tap(cx, cy, serial=serial_value, confirm=confirm)


@mcp.tool(annotations=REVERSIBLE)
def swipe(x1: int, y1: int, x2: int, y2: int, duration_ms: int = 300,
          display_id: int | None = None, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Swipe from (x1,y1) to (x2,y2). 2D system panels only.

    Like tap, accepts an optional display_id to target a specific Quest panel
    display with display-local coordinates.

    Two-phase: confirm=False returns a preview only.
    """
    for v in (x1, y1, x2, y2):
        if not (0 <= int(v) <= 20000):
            return {"ok": False, "error": "coordinate out of sane range"}
    dur = max(50, min(int(duration_ms), 10000))
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    disp = ["-d", str(int(display_id))] if display_id is not None else []
    argv = ["-s", serial_value, "shell", "input", *disp, "swipe", str(int(x1)), str(int(y1)), str(int(x2)), str(int(y2)), str(dur)]
    if not _is_confirmed(confirm):
        return _preview("swipe", argv, f"Injects a swipe ({x1},{y1})->({x2},{y2}) over {dur}ms.",
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=12)
    return {"ok": result["exit_code"] == 0, "executed": True, "result": result, "device": selected["device"]}


@mcp.tool(annotations=REVERSIBLE)
def input_text(text: str, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Type text into the currently focused 2D field.

    Two-phase: confirm=False returns a preview only.
    """
    if not text or len(text) > 500:
        return {"ok": False, "error": "text must be 1..500 chars"}
    if "\n" in text or "\r" in text:
        return {"ok": False, "error": "newlines not allowed; use send_keyevent ENTER"}
    # Reject shell chaining/substitution so free text cannot smuggle a second
    # device-side command through `adb shell input text <payload>`. This is the
    # primary guard for this tool (the global guard in _run_adb backs it up).
    if re.search(r"[;&|`$><]", text) or "${" in text:
        return {"ok": False, "error": "text contains shell metacharacters (; & | ` $ < >); refused"}
    # A bare `%` collides with `adb shell input text` own %s escaping (used for
    # spaces below), producing malformed/ambiguous input; refuse it outright.
    if "%" in text:
        return {"ok": False, "error": "text contains '%' which conflicts with input-text escaping; refused"}
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    # adb input text uses %s for spaces; keep it simple and safe
    escaped = text.replace(" ", "%s")
    argv = ["-s", serial_value, "shell", "input", "text", escaped]
    if not _is_confirmed(confirm):
        return _preview("input_text", argv, f"Types {len(text)} characters into the focused field.",
                        {"device": selected["device"], "text_preview": text[:80]})
    result = _run_adb(argv, timeout_seconds=10)
    return {"ok": result["exit_code"] == 0, "executed": True, "result": result, "device": selected["device"]}


@mcp.tool(annotations=REVERSIBLE)
def launch_app(package: str, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Launch an app by package via its monkey launch intent.

    Two-phase: confirm=False returns a preview only.
    """
    if not re.fullmatch(r"[A-Za-z0-9_.]{3,128}", package or ""):
        return {"ok": False, "error": "invalid package name"}
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    argv = ["-s", serial_value, "shell", "monkey", "-p", package, "-c",
            "android.intent.category.LAUNCHER", "1"]
    if not _is_confirmed(confirm):
        return _preview("launch_app", argv, f"Launches package {package} via its launcher intent.",
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=12)
    return {"ok": result["exit_code"] == 0, "executed": True, "package": package, "result": result, "device": selected["device"]}


@mcp.tool(annotations=REVERSIBLE)
def wake_headset(serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Wake the headset display (KEYCODE_WAKEUP). Needed before screenshots.

    Two-phase: confirm=False returns a preview only.
    """
    return send_keyevent("WAKEUP", serial=serial, confirm=confirm)


@mcp.tool(annotations=REVERSIBLE)
def sleep_headset(serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Put the headset display to sleep (KEYCODE_SLEEP).

    Two-phase: confirm=False returns a preview only.
    """
    return send_keyevent("SLEEP", serial=serial, confirm=confirm)


if __name__ == "__main__":
    mcp.run()
