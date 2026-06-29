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

import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCREENSHOT_DIR = ROOT / "Quest_ADB_Logs" / "control-screenshots"
MAX_OUTPUT_CHARS = 120_000

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

def _find_adb() -> str:
    env_adb = os.environ.get("ADB_EXE")
    candidates = [
        env_adb,
        shutil.which("adb"),
        str(ROOT / "adb.exe"),
        str(ROOT / "platform-tools" / "adb.exe"),
        str(ROOT / "tools" / "adb.exe"),
        str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / "adb.exe"),
        r"D:\Software\Android\Sdk\platform-tools\adb.exe",
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


@mcp.tool()
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
        "capability_boundary": [
            "Can: native screenshot, whitelisted keyevents, tap/swipe/text on 2D system panels, launch apps, wake/sleep.",
            "Cannot: emulate 6DoF VR controllers (laser + trigger) - controllers are Bluetooth HID, not in /dev/input.",
            "Coordinate taps only affect 2D system surfaces (Settings, browser), not immersive VR scenes.",
            "Screenshot requires the headset to be awake/worn; an asleep headset produces no image.",
        ],
        "never_exposed": "No install/uninstall/reboot/tcpip/usb/push/pull/pm clear-disable/factory-reset tool exists here.",
        "preview_note": "confirm=False issues only read-only probes (adb devices -l, dumpsys power) to build the preview; it never changes device state.",
    }


@mcp.tool()
def list_devices() -> dict[str, Any]:
    """List ADB devices with transport state. Read-only."""
    try:
        result = _run_adb(["devices", "-l"], timeout_seconds=6)
        return {"ok": result["exit_code"] == 0, "result": result, "devices": _parse_devices(result["stdout"])}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@mcp.tool()
def capture_screenshot(
    serial: str | None = None,
    output_dir: str | None = None,
    confirm: bool = False,
) -> dict[str, Any]:
    """Trigger a native Quest screenshot and pull it to the local workspace.

    Two-phase: confirm=False returns a preview only. Requires the headset to be
    awake; an asleep/unworn headset will not produce an image.
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
    return {
        "ok": True, "executed": True, "device": selected["device"],
        "device_path": f"/sdcard/Oculus/Screenshots/{newest}",
        "local_path": str(local_path), "bytes": len(data),
    }


@mcp.tool()
def send_keyevent(key: str, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Send one whitelisted Android key event (HOME/BACK/DPAD/VOLUME/MEDIA/...).

    Two-phase: confirm=False returns a preview only.
    """
    key_upper = key.strip().upper()
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


@mcp.tool()
def tap(x: int, y: int, serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Tap at (x, y). Only meaningful on 2D system panels, not VR scenes.

    Two-phase: confirm=False returns a preview only.
    """
    if not (0 <= int(x) <= 20000 and 0 <= int(y) <= 20000):
        return {"ok": False, "error": "x/y out of sane range"}
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    argv = ["-s", serial_value, "shell", "input", "tap", str(int(x)), str(int(y))]
    if not _is_confirmed(confirm):
        return _preview("tap", argv, f"Injects a tap at ({int(x)},{int(y)}) on the 2D input layer.",
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=8)
    return {"ok": result["exit_code"] == 0, "executed": True, "result": result, "device": selected["device"]}


@mcp.tool()
def swipe(x1: int, y1: int, x2: int, y2: int, duration_ms: int = 300,
          serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Swipe from (x1,y1) to (x2,y2). 2D system panels only.

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
    argv = ["-s", serial_value, "shell", "input", "swipe", str(int(x1)), str(int(y1)), str(int(x2)), str(int(y2)), str(dur)]
    if not _is_confirmed(confirm):
        return _preview("swipe", argv, f"Injects a swipe ({x1},{y1})->({x2},{y2}) over {dur}ms.",
                        {"device": selected["device"]})
    result = _run_adb(argv, timeout_seconds=12)
    return {"ok": result["exit_code"] == 0, "executed": True, "result": result, "device": selected["device"]}


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
def wake_headset(serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Wake the headset display (KEYCODE_WAKEUP). Needed before screenshots.

    Two-phase: confirm=False returns a preview only.
    """
    return send_keyevent("WAKEUP", serial=serial, confirm=confirm)


@mcp.tool()
def sleep_headset(serial: str | None = None, confirm: bool = False) -> dict[str, Any]:
    """Put the headset display to sleep (KEYCODE_SLEEP).

    Two-phase: confirm=False returns a preview only.
    """
    return send_keyevent("SLEEP", serial=serial, confirm=confirm)


if __name__ == "__main__":
    mcp.run()
