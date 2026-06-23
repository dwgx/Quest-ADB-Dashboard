# Self Review Checklist

## Findings To Check Before Commit

- The repository must not contain real Quest serial numbers, LAN IPs, BSSIDs, MAC addresses, or private `logcat` output.
- The share-safe export must redact serial-like values, MAC/BSSID values, LAN IPs, SSID/BSSID lines, fingerprints, and session-like IDs.
- The export endpoint must be read-only and must not call write/state-changing ADB commands.
- The safe MCP server must expose only whitelisted read-only ADB commands and no arbitrary shell.
- WebUI service must stay on `127.0.0.1`.
- The BAT must keep `:write_webui_payload` as a real label, not accidentally replaced from a `call :write_webui_payload` occurrence.
- `menu-test`, `help-test`, `adb-scan`, and `status` must run without stderr.

## Current Known Risk

The broader tool includes interactive state-changing convenience actions. They are useful for local debugging but should be documented clearly in public README/docs so users do not confuse them with the read-only export path.

## Pre-Publish Review Commands

```powershell
rg -n "real_serial|192\\.168\\.|BSSID|SSID|logcat|session_id" .
rg -n "settings put|settings delete|input keyevent|am broadcast|tcpip|install|uninstall|push|reboot" src dist docs
python -m py_compile mcp\quest_adb_safe_mcp.py
python -m unittest tests.test_safe_mcp_policy
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1
cmd /d /c "call dist\Quest_ADB_Tools.bat menu-test"
cmd /d /c "call dist\Quest_ADB_Tools.bat help-test"
cmd /d /c "call dist\Quest_ADB_Tools.bat adb-scan"
```

Run `status` separately only when a live Quest read is intended.
