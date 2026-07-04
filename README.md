# Quest ADB Dashboard

Audit and sideload your Meta Quest over ADB — one file, bundled ADB, local WebUI.

Point it at a headset and you get a local control panel: inspect device state,
generate share-safe audit reports, and install APKs with live progress — all
served on `127.0.0.1`, with `adb.exe` bundled so there is no SDK to set up.

Built around one principle: **evidence, not guessing.** Every reported value is
traceable to the command that produced it, state changes are quarantined behind
explicit confirmation, and the read-only paths stay read-only. Verified on Meta
Quest 3 (`eureka`); most read-only features work on other Quest headsets once
USB debugging is authorized.

![Share-safe Quest 3 report preview](examples/sample_quest3_share_safe.png)

## What It Does

- Bundles Google `platform-tools` (`adb.exe`) in the release archive, so a
  fresh download works without a separate Android SDK install. If you prefer
  your own ADB, the tool still finds one from `ADB_EXE`, PATH, and common
  Android platform-tools / SideQuest / Meta Quest Developer Hub / VIVE Hub
  locations under `C:\Program Files` or `D:\Software`.
- Runs as one end-user file: `dist/Quest_ADB_Tools.bat`.
- Starts a local WebUI bound to `127.0.0.1`.
- Shows connection, battery, power, Wi-Fi, storage, memory, display, thermal, controller hints, build metadata, and factory/calibration clues.
- Installs an APK from the browser: drag a file onto the **应用安装** page to
  see its package, version, and permissions, then confirm to `adb install`
  (with reinstall / grant-permissions / downgrade options).
- Provides an optional read-only MCP server for CI/agent inventory workflows.
- Exports two standalone HTML reports:
  - `share-safe`: redacted report intended for support posts, GitHub issues, and screenshots.
  - `private-full`: complete local report for personal troubleshooting only.
- Adds explicit inference notes for factory/calibration metadata so internal station codes are not overclaimed as country, city, or factory names.

## Safety Model

The **HTML export path is read-only**. It uses public ADB reads such as:

- `getprop`
- `settings list`
- `dumpsys battery`
- `dumpsys power`
- `dumpsys display`
- `dumpsys sensorservice`
- `dumpsys thermalservice`
- `pm list packages`
- `pm list features`

The broader WebUI and BAT menu also contain interactive convenience actions for sleep, wake, keep-awake, wireless ADB, restore, and custom settings. Those actions are separate from export and can change headset state. Use them only when you understand the effect.

APK install lives only in the WebUI and is state-changing. The browser uploads
the APK to the local server, which parses it and shows the exact `adb install`
command and target package; nothing installs until you confirm. Install and
uninstall are deliberately **not** available in either MCP server, so an agent
cannot silently modify the device.

The project ships two MCP servers. The default one is read-only: it exposes
only ADB inventory tools and has no generic shell, install, uninstall, push,
pull, reboot, wireless ADB, settings write, input, or broadcast tool. See
[Safe MCP and CI](docs/SAFE_MCP_CI.md).

A separate, opt-in control server (`mcp/quest_adb_control_mcp.py`) can change
device state (screenshot, key events, tap/swipe/text, launch app, wake/sleep).
Every state-changing tool is two-phase: it previews the exact adb command and
touches nothing until you confirm, and it hard-blocks irreversible families
(install/uninstall/reboot/factory-reset/...) even when confirmed. See
[Control MCP](docs/CONTROL_MCP.md).

## Quick Start

1. Enable Developer Mode for the Quest headset.
2. Connect the headset by USB and approve the USB debugging prompt inside the headset.
3. Run:

```bat
dist\Quest_ADB_Tools.bat
```

   The release archive already ships `adb.exe` next to the BAT, so no separate
   Android SDK install is required. To use your own ADB instead, set `ADB_EXE`
   or put `adb.exe` on PATH.

4. Press `W` to open the local WebUI.
5. Use **一键导出设备全部信息** to create both HTML reports.
6. Share only the `share-safe` report after manual review.

To install an APK, open the WebUI, go to the **应用安装** page, drag an `.apk`
onto it, review the parsed package/version/permissions, then confirm.

## Public Sharing Checklist

Do not upload private evidence unless you have reviewed it manually. Public posts should avoid:

- Real Quest serial numbers.
- Private Wi-Fi SSIDs, BSSIDs, MAC addresses, or LAN IPs.
- Real `logcat` dumps.
- Full bugreports.
- Account, token, login, app-private, or local machine data.

Example reports in `examples/` use synthetic Quest 3-like data. The private example is still synthetic and exists only to show the report layout.

## Knowledge Base

- [ADB and Quest notes](docs/ADB_QUEST_NOTES.md)
- [Methods and inference limits](docs/METHODS.md)
- [HTML export reports](docs/EXPORT_REPORTS.md)
- [Public sharing guide](docs/PUBLIC_SHARING.md)
- [Safe MCP and CI](docs/SAFE_MCP_CI.md)
- [Control MCP (state-changing, two-phase confirm)](docs/CONTROL_MCP.md)
- [Development and rebuild workflow](docs/DEVELOPMENT.md)
- [Self-review checklist](docs/SELF_REVIEW.md)
- [Release notes](docs/RELEASE_NOTES.md)

## Project Layout

```text
dist/
  Quest_ADB_Tools.bat        End-user single-file tool.
  adb.exe                    Bundled ADB (release archive only; not in git).
src/
  QuestAdbWebUi.cs           Local 127.0.0.1 WebUI server and report generator.
  QuestAdbWebUi.html         Embedded WebUI frontend.
scripts/
  build-webui.ps1            Rebuilds WebUI EXE and embeds it into the BAT.
  generate-sample-reports.ps1
docs/
  *.md                       Public Quest/ADB knowledge base and workflow docs.
mcp/
  quest_adb_safe_mcp.py      Read-only MCP server for CI/agent workflows.
examples/
  sample_quest3_share_safe.html
  sample_quest3_share_safe.png
  sample_quest3_private_full.html
  sample_quest3_private_full.png
```

## Notes

This project is not affiliated with Meta, Oculus, Qualcomm, VIVE, or Virtual Desktop. It is a local Windows utility for authorized devices you control.

## License

MIT. See `LICENSE`.
