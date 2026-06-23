# Release Notes

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
