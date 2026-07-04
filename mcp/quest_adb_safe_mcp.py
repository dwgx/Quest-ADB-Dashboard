#!/usr/bin/env python3
"""Read-only MCP server for Quest ADB Dashboard.

This server intentionally exposes only read-only ADB inventory helpers. It does
not provide a generic shell, install, uninstall, reboot, settings write, input,
broadcast, tcpip, usb, push, pull, or file mutation tool.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "Quest_ADB_Logs" / "mcp-readonly"
MAX_OUTPUT_CHARS = 120_000

INSTRUCTIONS = (
    "Quest ADB read-only MCP bridge. This server is intentionally safe for "
    "authorized local Quest devices: it only runs whitelisted read commands. "
    "It refuses install, uninstall, push, pull, reboot, tcpip, usb, input, "
    "am, settings put/delete, pm clear/disable/enable, and arbitrary shell."
)

mcp = FastMCP("quest-adb-safe", instructions=INSTRUCTIONS, log_level="ERROR")


SAFE_ADB_COMMANDS: dict[str, list[str]] = {
    "devices": ["devices", "-l"],
    "version": ["version"],
}

SAFE_SHELL_COMMANDS: dict[str, str] = {
    "id": "id",
    "getprop": "getprop",
    "settings_global": "settings list global",
    "settings_system": "settings list system",
    "settings_secure": "settings list secure",
    "battery": "dumpsys battery",
    "power": "dumpsys power",
    "display": "dumpsys display",
    "usb": "dumpsys usb",
    "wifi": "dumpsys wifi",
    "connectivity": "dumpsys connectivity",
    "bluetooth": "dumpsys bluetooth_manager",
    "camera": "dumpsys media.camera",
    "sensorservice": "dumpsys sensorservice",
    "thermal": "dumpsys thermalservice",
    "input_dump": "dumpsys input",
    "packages": "pm list packages -f -i",
    "features": "pm list features",
    "libraries": "cmd package list libraries",
    "df": "df -h /data /sdcard",
    "meminfo": "cat /proc/meminfo",
    "cpuinfo": "cat /proc/cpuinfo",
    "uname": "uname -a",
    "ip_addr": "ip addr",
    "ip_route": "ip route",
    "virtualdesktop_package": "dumpsys package VirtualDesktop.Android",
    "virtualdesktop_recovered_package": "dumpsys package com.dwgx1.virtualdesktop.recovered",
    "oculus_packages": "dumpsys package com.oculus",
    "logcat_tail_private": "logcat -d -t 3000",
}

BLOCKED_ADB_COMMANDS = {
    "install",
    "install-multiple",
    "install-multi-package",
    "uninstall",
    "push",
    "pull",
    "reboot",
    "tcpip",
    "usb",
    "root",
    "unroot",
    "remount",
    "sideload",
    "sync",
}

ADB_OPTIONS_WITH_VALUE = {
    "-s",
    "-t",
    "-H",
    "-P",
    "-L",
}

ADB_OPTIONS_WITHOUT_VALUE = {
    "-a",
    "-d",
    "-e",
}

BLOCKED_SHELL_PREFIXES = (
    ("am",),
    ("input",),
    ("svc",),
    ("settings", "put"),
    ("settings", "delete"),
    ("settings", "reset"),
    ("pm", "clear"),
    ("pm", "disable"),
    ("pm", "disable-user"),
    ("pm", "enable"),
    ("pm", "hide"),
    ("pm", "install"),
    ("pm", "suspend"),
    ("pm", "uninstall"),
    ("appops", "set"),
    ("setprop",),
    ("stop",),
    ("start",),
    ("reboot",),
    ("rm",),
    ("mv",),
    ("cp",),
    ("chmod",),
    ("chown",),
    ("mount",),
    ("logcat", "-c"),
)

SERIAL_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


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
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Oculus" / "Support" / "oculus-runtime" / "adb.exe"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Meta Quest Developer Hub" / "resources" / "bin" / "adb.exe"),
        str(Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Meta Quest Developer Hub" / "resources" / "bin" / "adb.exe"),
        r"D:\Software\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Business Streaming\Updater\App\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Hub\Updater\App\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Ultimate Tracker\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Ultimate Tracker\Updater\App\CommonTools\ADB\adb.exe",
        r"D:\Software\VIVE Hub\VIVE Ultimate Tracker\ViveUTServer\Tools\adb.exe",
        r"C:\Program Files\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe",
        r"C:\Program Files\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    raise FileNotFoundError("adb.exe not found. Set ADB_EXE or install Android platform-tools.")


def _validate_serial(serial: str) -> str:
    if not serial or not SERIAL_RE.fullmatch(serial):
        raise ValueError("Invalid ADB serial. Use a value returned by list_devices().")
    return serial


def _shell_words(command: str) -> list[str]:
    return [part for part in re.split(r"\s+", command.strip()) if part]


def _has_prefix(words: list[str], prefix: tuple[str, ...]) -> bool:
    return len(words) >= len(prefix) and tuple(words[: len(prefix)]) == prefix


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


def _refuse_if_dangerous(argv: list[str]) -> None:
    args = [item.lower() for item in argv[1:]]
    rendered = " ".join(argv)
    command_words = _adb_command_words(args)
    if command_words and command_words[0] in BLOCKED_ADB_COMMANDS:
        raise ValueError(f"Refusing state-changing ADB command: {rendered}")

    if "shell" not in args:
        return

    shell_index = args.index("shell")
    shell_args = args[shell_index + 1 :]
    if not shell_args:
        raise ValueError(f"Refusing empty arbitrary shell: {rendered}")
    shell_words = _shell_words(" ".join(shell_args))
    for prefix in BLOCKED_SHELL_PREFIXES:
        if _has_prefix(shell_words, prefix):
            raise ValueError(f"Refusing state-changing ADB shell command: {rendered}")

    if shell_words[:1] == ["cmd"] and shell_words[:4] != ["cmd", "package", "list", "libraries"]:
        raise ValueError(f"Refusing non-whitelisted cmd shell command: {rendered}")


def _run_adb(args: list[str], timeout_seconds: float = 10.0) -> dict[str, Any]:
    adb = _find_adb()
    argv = [adb] + args
    _refuse_if_dangerous(argv)
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
    stdout = proc.stdout[-MAX_OUTPUT_CHARS:]
    stderr = proc.stderr[-MAX_OUTPUT_CHARS:]
    return {
        "adb": adb,
        "args": args,
        "command": " ".join(argv),
        "exit_code": proc.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "duration_ms": int((time.monotonic() - started) * 1000),
        "truncated": len(proc.stdout) > MAX_OUTPUT_CHARS or len(proc.stderr) > MAX_OUTPUT_CHARS,
    }


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
    listed = _run_adb(SAFE_ADB_COMMANDS["devices"], timeout_seconds=6)
    devices = _parse_devices(listed["stdout"])
    if serial:
        serial = _validate_serial(serial)
        matches = [d for d in devices if d.get("serial") == serial]
        if not matches:
            return {"ok": False, "reason": "requested serial not found", "adb_result": listed, "devices": devices}
        selected = matches[0]
    else:
        online = [d for d in devices if d.get("state") == "device"]
        quest = [
            d for d in online
            if "Quest" in d.get("model", "")
            or d.get("product") == "eureka"
            or d.get("device") == "eureka"
        ]
        usb_quest = [d for d in quest if ":" not in d.get("serial", "")]
        pool = usb_quest or quest or online
        if not pool:
            return {"ok": False, "reason": "no authorized online device", "adb_result": listed, "devices": devices}
        selected = pool[0]
    return {"ok": True, "device": selected, "adb_result": listed, "devices": devices}


def _shell_args(serial: str, command_key: str) -> list[str]:
    if command_key not in SAFE_SHELL_COMMANDS:
        raise ValueError(f"Unknown safe shell command key: {command_key}")
    command = SAFE_SHELL_COMMANDS[command_key]
    return ["-s", _validate_serial(serial), "shell", command]


def _redact_share_safe(text: str) -> str:
    text = re.sub(r"([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}", "[REDACTED_MAC]", text)
    # IPv6 (incl. compressed :: forms like fe80::1) — redact before IPv4.
    text = re.sub(
        r"\b(?:[0-9A-Fa-f]{1,4}:){1,7}:?(?:[0-9A-Fa-f]{1,4})?(?::[0-9A-Fa-f]{1,4})*\b"
        r"|\b[0-9A-Fa-f]{1,4}::(?:[0-9A-Fa-f]{1,4}:?)*[0-9A-Fa-f]{0,4}\b",
        "[REDACTED_IPV6]",
        text,
    )
    # Redact ALL IPv4 addresses (private, CGNAT, public, link-local). A
    # share-safe export should never carry any routable or local address;
    # the previous RFC1918-only rule leaked public/CGNAT/IPv6 and the 10/8
    # last octet. Redact the whole dotted quad.
    text = re.sub(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "[REDACTED_IP]", text)
    # getprop format is `[ro.serialno]: [VALUE]`; the older `key=value` rule
    # missed it. Redact the bracketed value for sensitive property keys.
    text = re.sub(
        r"(?im)^\[(ro\.serialno|ro\.boot\.serialno|androidboot\.serialno|gsm\.[^\]]*imei[^\]]*|persist\.[^\]]*serial[^\]]*)\]\s*:\s*\[[^\]]*\]",
        r"[\1]: [REDACTED]",
        text,
    )
    text = re.sub(r"(?i)\b(serial|ro\.serialno|androidboot\.serialno|wifi_ssid|ssid|bssid|imei)\b[=: ]+[^\r\n]+", r"\1=[REDACTED]", text)
    # Catch-all for long opaque IDs (Quest serials are ~14 alnum). Lowered to
    # 8 so shorter serials are not missed by the length heuristic.
    text = re.sub(r"(?i)\b[A-Z0-9]{8,}\b", "[REDACTED_ID]", text)
    return text


@mcp.tool()
def safety_policy() -> dict[str, Any]:
    """Return the safety boundary enforced by this MCP server."""
    return {
        "mode": "read-only",
        "allowed_adb_commands": sorted(SAFE_ADB_COMMANDS),
        "allowed_shell_commands": sorted(SAFE_SHELL_COMMANDS),
        "blocked_examples": [
            "adb install",
            "adb uninstall",
            "adb reboot",
            "adb tcpip",
            "adb usb",
            "adb push",
            "adb pull",
            "adb shell settings put/delete",
            "adb shell input keyevent",
            "adb shell am broadcast/start",
            "adb shell pm clear/disable/enable",
        ],
        "notes": [
            "No arbitrary shell tool is exposed.",
            "logcat command is read-only tail only: logcat -d -t 3000.",
            "Generated reports are written to local workspace logs only.",
        ],
    }


@mcp.tool()
def find_adb() -> dict[str, Any]:
    """Find adb.exe using the same common Windows locations as the dashboard."""
    try:
        adb = _find_adb()
        version = _run_adb(SAFE_ADB_COMMANDS["version"], timeout_seconds=5)
        return {"ok": True, "adb": adb, "version": version}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@mcp.tool()
def list_devices() -> dict[str, Any]:
    """List ADB devices with transport state. This is read-only."""
    try:
        result = _run_adb(SAFE_ADB_COMMANDS["devices"], timeout_seconds=6)
        return {"ok": result["exit_code"] == 0, "result": result, "devices": _parse_devices(result["stdout"])}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@mcp.tool()
def read_device_status(serial: str | None = None) -> dict[str, Any]:
    """Read a small safe Quest status snapshot without changing device state."""
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    device = selected["device"]
    serial_value = device["serial"]
    fields = {
        "model": ("getprop", "ro.product.model"),
        "manufacturer": ("getprop", "ro.product.manufacturer"),
        "android": ("getprop", "ro.build.version.release"),
        "sdk": ("getprop", "ro.build.version.sdk"),
        "product": ("getprop", "ro.product.name"),
        "device": ("getprop", "ro.product.device"),
        "build": ("getprop", "ro.build.display.id"),
        "abi": ("getprop", "ro.product.cpu.abi"),
        "battery": ("shell", "dumpsys battery"),
        "power": ("shell", "dumpsys power"),
        "thermal": ("shell", "dumpsys thermalservice"),
    }
    data: dict[str, Any] = {"ok": True, "device": device, "captures": {}}
    for name, spec in fields.items():
        if spec[0] == "getprop":
            args = ["-s", serial_value, "shell", "getprop", spec[1]]
        else:
            args = ["-s", serial_value, "shell", spec[1]]
        try:
            data["captures"][name] = _run_adb(args, timeout_seconds=8)
        except Exception as exc:
            data["captures"][name] = {"exit_code": -1, "error": str(exc)}
    return data


@mcp.tool()
def run_safe_capture(command_key: str, serial: str | None = None, timeout_seconds: float = 10.0) -> dict[str, Any]:
    """Run one whitelisted read-only capture by key."""
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    try:
        result = _run_adb(_shell_args(serial_value, command_key), timeout_seconds=timeout_seconds)
        return {"ok": result["exit_code"] == 0, "device": selected["device"], "command_key": command_key, "result": result}
    except Exception as exc:
        return {"ok": False, "error": str(exc), "command_key": command_key}


@mcp.tool()
def export_readonly_snapshot(
    serial: str | None = None,
    output_dir: str | None = None,
    include_private_logcat: bool = False,
) -> dict[str, Any]:
    """Capture a read-only JSON snapshot and a redacted share-safe JSON copy."""
    selected = _select_device(serial)
    if not selected.get("ok"):
        return selected
    serial_value = selected["device"]["serial"]
    out_root = Path(output_dir).resolve() if output_dir else DEFAULT_OUTPUT_DIR
    out_root.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    private_path = out_root / f"quest_adb_private_full_{stamp}.json"
    safe_path = out_root / f"quest_adb_share_safe_{stamp}.json"
    keys = [k for k in SAFE_SHELL_COMMANDS if include_private_logcat or "logcat" not in k]
    captures: dict[str, Any] = {}
    for key in keys:
        try:
            timeout = 15 if key in {"packages", "sensorservice", "logcat_tail_private"} else 10
            captures[key] = _run_adb(_shell_args(serial_value, key), timeout_seconds=timeout)
        except Exception as exc:
            captures[key] = {"exit_code": -1, "error": str(exc)}
    payload = {
        "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "policy": "read-only whitelist; no ADB writes",
        "device": selected["device"],
        "captures": captures,
    }
    private_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    safe_payload = json.loads(json.dumps(payload, ensure_ascii=False))
    safe_payload["device"]["serial"] = "[REDACTED_SERIAL]"
    safe_payload["captures"] = {
        key: {
            **value,
            "stdout": _redact_share_safe(value.get("stdout", "")),
            "stderr": _redact_share_safe(value.get("stderr", "")),
        }
        for key, value in captures.items()
        if "logcat" not in key
    }
    safe_path.write_text(json.dumps(safe_payload, indent=2, ensure_ascii=False), encoding="utf-8")
    return {
        "ok": True,
        "device": selected["device"],
        "private_path": str(private_path),
        "share_safe_path": str(safe_path),
        "capture_count": len(captures),
        "include_private_logcat": include_private_logcat,
    }


if __name__ == "__main__":
    mcp.run()
