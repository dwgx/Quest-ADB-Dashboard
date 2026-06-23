# Safe MCP And CI

This project includes a separate read-only MCP server for CI and agent-driven
Quest inventory work:

```text
mcp/quest_adb_safe_mcp.py
```

It is intentionally not a generic ADB bridge. The server exposes only
whitelisted read helpers and refuses state-changing commands.

## Safety Boundary

Allowed command groups:

- `adb devices -l`
- `adb version`
- `adb shell getprop`
- `adb shell settings list global/system/secure`
- `adb shell dumpsys ...`
- `adb shell pm list packages/features`
- `adb shell cmd package list libraries`
- `adb shell df`, `/proc` reads, `uname`, `ip addr`, `ip route`
- optional private local `logcat -d -t 3000`

Blocked command families:

- `adb install`, `adb uninstall`
- `adb push`, `adb pull`
- `adb reboot`, `adb tcpip`, `adb usb`
- `adb shell settings put/delete/reset`
- `adb shell input ...`
- `adb shell am ...`
- `adb shell pm clear/disable/enable/install/uninstall`
- `adb shell setprop`, `svc`, `stop`, `start`, filesystem mutation commands

No arbitrary `adb shell` tool is exposed.

## Local Smoke Test

Run this without a connected headset to validate MCP protocol and tool
registration:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1
```

Run this only when you explicitly want a live read from an already authorized
Quest:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1 -LiveAdb
```

The live mode is still read-only. It does not install, launch, wake, sleep,
change settings, switch wireless ADB, or clear logs.

## Codex MCP Configuration

Codex cannot hot-add new MCP tools inside an already running session. Add this
server to `%USERPROFILE%\.codex\config.toml` or a project profile, then start a
new Codex session.

Example command:

```toml
[mcp_servers.quest-adb-safe]
command = "<repo>\\.venv-mcp\\Scripts\\python.exe"
args = ["<repo>\\mcp\\quest_adb_safe_mcp.py"]
enabled = true
```

Create the venv first with:

```powershell
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1
```

The server searches common ADB locations, including:

- `D:\Software\Android\Sdk\platform-tools\adb.exe`
- VIVE Hub ADB copies under `D:\Software\VIVE Hub\...`
- Android SDK, SideQuest, Oculus, Meta Quest Developer Hub, and VIVE Hub
  paths under standard Windows locations

## CI

The GitHub Actions workflow runs offline checks only:

- Python syntax compile for the MCP server.
- MCP handshake/tool-list smoke test without a real Quest.
- Text scan to verify dangerous ADB command families remain visible to review.
- BAT menu/help/ADB-scan smoke tests.

CI must not require a real headset and must not run live ADB mutation commands.
