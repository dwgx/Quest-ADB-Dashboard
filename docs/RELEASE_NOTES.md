# Release Notes

## v0.2.0

APK install support in the WebUI, bundled ADB, and audit hardening.

New:

- Added an **应用安装** page to the WebUI, styled as an App Store-style detail
  card. Drag an `.apk` onto the page (or pick a file), and the server stages it
  locally and shows package name, version name/code, size, declared
  permissions, and whether the package is already installed on the connected
  headset (with an upgrade/downgrade badge).
- Install streams **real-time progress** over Server-Sent Events: the install
  button morphs in place into a progress bar with a live stage label, an
  elapsed timer, and the actual `adb install` output line-by-line, finishing
  with a success checkmark animation (or a red failure state you can retry).
  `adb install` has no true byte-percentage, so progress is honest
  stage-weighted checkpoints plus real upload progress, not a faked number.
- APK metadata is read by a self-contained ZIP + binary-XML (AXML) parser. It
  seeks the ZIP central directory and inflates only `AndroidManifest.xml`, so
  it never loads a multi-GB APK into memory. Verified against a real ~940 MB
  Quest APK.
- Install runs `adb install` with per-attempt options (`-r` reinstall, `-g`
  grant runtime permissions, `-d` allow downgrade, and an optional
  "uninstall first" for signature mismatches). Every install requires a
  two-phase confirm (`confirm=YES`); the browser previews the exact command and
  target package before anything touches the headset. Failed installs surface
  the raw failure code with a Chinese explanation.
- The release archive now bundles Google `platform-tools` (`adb.exe` plus its
  `AdbWinApi.dll` / `AdbWinUsbApi.dll`) next to the BAT, so a fresh download
  works with no separate Android SDK install. The BAT still prefers a
  user-provided ADB (`ADB_EXE`, then a bundled `adb.exe`, then PATH and common
  SDK/SideQuest/MQDH/VIVE locations).

Safety notes:

- Install/uninstall remain **hard-blocked in both MCP servers** by design. The
  install path exists only in the WebUI, which is the human-in-the-loop surface
  (nothing installs without an explicit browser confirm).
- The local WebUI is bound to `127.0.0.1` and requires a per-session token,
  now sent via the `X-Quest-Token` request header instead of the URL query.
- Uploaded APKs are staged under the log directory and pruned to the most
  recent few, so repeated installs cannot silently fill the disk.

Hardening (audit follow-up):

- The BAT now verifies the SHA-256 of the unpacked WebUI EXE against a hash
  stamped in at build time before running it, so a corrupted or tampered
  payload is rejected instead of executed.
- Control MCP: added a policy invariant plus a drift test so the blocked
  command families cannot silently shrink, and `input_text` now refuses a bare
  `%` that would collide with `adb shell input text` escaping.
- ADB discovery no longer hardcodes a single author machine path; it scans
  common drive letters and SDK/tool locations generically.

Boundary unchanged:

- The tool still does not translate internal `location_id` / `station_id` /
  `station_type` codes into country, city, factory, or production-line claims.

## v0.1.3

Factory/calibration parser fix.

- Fixed WebUI and export parsing for `dumpsys sensorservice` metadata where
  Quest firmware returns JSON embedded as escaped strings such as `\"Device\"`.
- Factory/calibration summaries can now show exposed values such as `Eureka`,
  `PVT1.1`, factory timestamp, `location_id`, and `station_id` when the
  firmware makes them visible.
- Fixed camera calibration sensor counting for escaped `SensorType` metadata.
- Added a WebUI parser self-test and CI coverage so escaped calibration
  metadata does not regress silently.

Known boundary:

- The tool still does not translate internal `location_id`, `station_id`, or
  `station_type` codes into country, city, factory, or production-line claims.
  Those mappings are not proven by public ADB output.

## v0.1.2

CI smoke fix for clean GitHub Actions runners.

- Fixed `scripts/smoke-safe-mcp.ps1` so the expected "MCP dependency missing"
  import check does not abort under PowerShell 7 with
  `$ErrorActionPreference = 'Stop'`.
- Increased first-time MCP dependency install timeout for clean CI runners.
- Verified GitHub Actions CI passes on `main`.

## v0.1.1

Reliability and release-readiness update.

- Fixed the Windows BAT Chinese UI path so UTF-8 menu/help/status text is no
  longer parsed by `cmd.exe` as commands.
- Fixed WebUI first launch feedback and cache behavior. First launch now shows
  an unpacking message, extracts the embedded WebUI faster, and reuses a stable
  cached EXE for the same BAT size.
- Added a WebUI smoke-test switch:
  `QUEST_ADB_WEBUI_NO_BROWSER=1`.
- Added an optional read-only MCP server for CI/agent inventory workflows.
- Added offline CI checks for BAT smoke, MCP protocol registration, and MCP
  safety-policy unit tests.
- Hardened MCP ADB safety checks so state-changing commands are blocked even
  when ADB global options such as `-s SERIAL` are present.
- Added public documentation for the MCP safety boundary and CI workflow.

Known boundary:

- The export path and MCP path are read-only. The broader BAT/WebUI tool still
  includes interactive state-changing convenience actions for local debugging;
  those actions are documented and require explicit user action.

## v0.1.0

Initial public release.

- Single-file Windows BAT launcher: `dist/Quest_ADB_Tools.bat`.
- Local WebUI bound to `127.0.0.1`.
- Quest 3-focused ADB status dashboard.
- Read-only full device export path.
- Two standalone HTML report modes:
  - `share-safe` for public support and screenshots.
  - `private-full` for local troubleshooting only.
- Invoice-style HTML audit report with evidence-source tables.
- Factory/calibration metadata display with explicit inference limits.
- Synthetic Quest 3 example reports and screenshots.

Known boundary:

- The export path is read-only, but the broader tool includes interactive state-changing actions. Review the safety notes before using keep-awake, wireless ADB, custom settings, or broadcast actions.
