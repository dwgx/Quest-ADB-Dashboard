# Development

## Build Requirements

- Windows.
- .NET Framework C# compiler:

```text
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
```

- Windows `certutil.exe` for the BAT runtime to decode the embedded WebUI EXE.

## Rebuild

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-webui.ps1
```

The script:

1. Embeds `src/QuestAdbWebUi.html` into `src/QuestAdbWebUi.cs`.
2. Compiles `build/QuestAdbWebUi.exe`.
3. Replaces the `:write_webui_payload` block in `dist/Quest_ADB_Tools.bat`.

## Regenerate Synthetic Examples

The public example reports are synthetic and should not be generated from a real headset export:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-sample-reports.ps1
```

Screenshots can be refreshed with a local browser from the generated HTML. Review the images before committing.

## Smoke Tests

```powershell
cmd /d /c "call dist\Quest_ADB_Tools.bat menu-test"
cmd /d /c "call dist\Quest_ADB_Tools.bat help-test"
cmd /d /c "call dist\Quest_ADB_Tools.bat adb-scan"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1
python -m unittest tests.test_safe_mcp_policy
```

Expected:

- No `The system cannot find the batch label specified`.
- No `not recognized`.
- No `syntax is incorrect`.
- WebUI starts on `127.0.0.1`.
- Safe MCP server registers tools and keeps only read-only ADB helpers.
- `adb-scan` may report no ADB on a clean runner; that is acceptable as long
  as it prints diagnostics instead of crashing.

Run `status` only when a connected Quest is available and you explicitly want a live read.

Run MCP live status only when a connected authorized Quest is available and you
explicitly want a read-only device snapshot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-safe-mcp.ps1 -LiveAdb
```

## Release Notes

Before publishing:

- Review the BAT for accidental local paths.
- Verify no real serial/IP/MAC/logcat data is committed.
- Generate screenshots from synthetic example HTML, not from a private headset report.
- Confirm `docs/RELEASE_NOTES.md` matches the GitHub release notes.
