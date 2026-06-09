# Release Notes

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
