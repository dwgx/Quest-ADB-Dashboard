@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title Quest_ADB_Tools

set "SCRIPT_DIR=%~dp0"
set "ADB="
set "DEVICE="
set "DEVICE_LINE="
set "UNAUTH_DEVICE="
set "OFFLINE_DEVICE="
set "OTHER_DEVICE="
set "OTHER_STATE="
set "WIFI_IP="
set "BACKUP_FILE="
REM Known-good SHA256 of the embedded WebUI EXE; stamped by scripts\build-webui.ps1 at build time.
REM Empty on a hand-built/unstamped BAT, in which case :verify_webui_hash skips the check.
set "WEBUI_EXE_SHA256=54c025bbd03409ff04d9e8f86d48e0ff1973d3290d61353bffa2bc5112093a36"

call :find_adb

if /i "%~1"=="webui" goto :arg_webui
if /i "%~1"=="ui" goto :arg_webui
if /i "%~1"=="console" goto :arg_console
if /i "%~1"=="doctor" goto :arg_doctor
if /i "%~1"=="status" goto :arg_status
if /i "%~1"=="watch" goto :arg_watch
if /i "%~1"=="keepawake" goto :arg_keepawake
if /i "%~1"=="keepalive" goto :arg_keepalive
if /i "%~1"=="wireless" goto :arg_wireless
if /i "%~1"=="wireless-off" goto :arg_wireless_off
if /i "%~1"=="wirelessoff" goto :arg_wireless_off
if /i "%~1"=="sleep" goto :arg_sleep
if /i "%~1"=="restore" goto :arg_restore
if /i "%~1"=="menu-test" goto :boot_intro
if /i "%~1"=="help-test" goto :show_help
if /i "%~1"=="adb-scan" goto :arg_adb_scan
if /i "%~1"=="adbcheck" goto :arg_adb_scan

goto :boot_intro

:arg_webui
call :start_webui
exit /b !ERRORLEVEL!

:arg_console
goto :menu

:arg_doctor
call :diagnose_connection
exit /b !ERRORLEVEL!

:arg_status
call :print_status
exit /b !ERRORLEVEL!

:arg_watch
call :watch_loop
exit /b !ERRORLEVEL!

:arg_keepawake
call :apply_keep_awake
exit /b !ERRORLEVEL!

:arg_keepalive
call :keepalive_loop
exit /b !ERRORLEVEL!

:arg_wireless
call :enable_wireless_adb
exit /b !ERRORLEVEL!

:arg_wireless_off
call :disable_wireless_adb
exit /b !ERRORLEVEL!

:arg_sleep
call :safe_sleep_headset
exit /b !ERRORLEVEL!

:arg_restore
call :restore_backup
exit /b !ERRORLEVEL!

:arg_adb_scan
call :adb_self_check
exit /b !ERRORLEVEL!

:find_adb
if defined ADB_EXE if exist "%ADB_EXE%" (
  set "ADB=%ADB_EXE%"
  exit /b 0
)
if exist "%SCRIPT_DIR%adb.exe" (
  set "ADB=%SCRIPT_DIR%adb.exe"
  exit /b 0
)
if exist "%SCRIPT_DIR%platform-tools\adb.exe" (
  set "ADB=%SCRIPT_DIR%platform-tools\adb.exe"
  exit /b 0
)
if exist "%SCRIPT_DIR%tools\adb.exe" (
  set "ADB=%SCRIPT_DIR%tools\adb.exe"
  exit /b 0
)
for /f "delims=" %%A in ('where adb 2^>nul') do (
  if not defined ADB set "ADB=%%A"
)
if defined ADB exit /b 0

REM Generic Android SDK locations across common drive letters (covers author's
REM D:\Software\Android\Sdk\platform-tools\adb.exe without hardcoding one machine).
for %%D in (C D E) do (
  if not defined ADB if exist "%%D:\Software\Android\Sdk\platform-tools\adb.exe" set "ADB=%%D:\Software\Android\Sdk\platform-tools\adb.exe"
  if not defined ADB if exist "%%D:\Android\Sdk\platform-tools\adb.exe" set "ADB=%%D:\Android\Sdk\platform-tools\adb.exe"
)
if defined ADB exit /b 0

for %%A in (
  "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  "%ProgramFiles%\Android\platform-tools\adb.exe"
  "%ProgramFiles(x86)%\Android\platform-tools\adb.exe"
  "%ProgramFiles%\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
  "%LOCALAPPDATA%\Programs\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
  "%ProgramFiles%\Oculus\Support\oculus-diagnostics\adb.exe"
  "%ProgramFiles%\Oculus\Support\oculus-runtime\adb.exe"
  "%ProgramFiles%\Meta Quest Developer Hub\resources\bin\adb.exe"
  "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\bin\adb.exe"
  "%ProgramFiles%\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
  "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
  "D:\Software\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Business Streaming\Updater\App\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Hub\Updater\App\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Ultimate Tracker\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Ultimate Tracker\Updater\App\CommonTools\ADB\adb.exe"
  "D:\Software\VIVE Hub\VIVE Ultimate Tracker\ViveUTServer\Tools\adb.exe"
  "C:\Program Files\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe"
  "C:\Program Files\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe"
) do (
  if not defined ADB if exist "%%~A" set "ADB=%%~A"
)
exit /b 0

:select_device
set "DEVICE="
set "DEVICE_LINE="
set "UNAUTH_DEVICE="
set "OFFLINE_DEVICE="
set "OTHER_DEVICE="
set "OTHER_STATE="
set "DEVICE_COUNT=0"
set "QUEST_DEVICE="
set "QUEST_LINE="
set "QUEST_USB_DEVICE="
set "QUEST_USB_LINE="
if not defined ADB exit /b 1
for /f "skip=1 tokens=1,2,*" %%A in ('call "%ADB%" devices -l 2^>nul') do (
  if "%%B"=="device" (
    set /a DEVICE_COUNT+=1
    set "CURRENT_LINE=%%A %%B %%C"
    if not defined DEVICE (
      set "DEVICE=%%A"
      set "DEVICE_LINE=%%A %%B %%C"
    )
    echo !CURRENT_LINE! | findstr /i /c:"model:Quest" /c:"product:eureka" /c:"device:eureka" >nul
    if not errorlevel 1 (
      if not defined QUEST_DEVICE (
        set "QUEST_DEVICE=%%A"
        set "QUEST_LINE=!CURRENT_LINE!"
      )
      echo %%A | find ":" >nul
      if errorlevel 1 (
        if not defined QUEST_USB_DEVICE (
          set "QUEST_USB_DEVICE=%%A"
          set "QUEST_USB_LINE=!CURRENT_LINE!"
        )
      )
    )
  )
  if "%%B"=="unauthorized" if not defined UNAUTH_DEVICE set "UNAUTH_DEVICE=%%A"
  if "%%B"=="offline" if not defined OFFLINE_DEVICE set "OFFLINE_DEVICE=%%A"
  if not "%%B"=="" (
    if not "%%B"=="device" if not "%%B"=="unauthorized" if not "%%B"=="offline" (
      if not defined OTHER_DEVICE (
        set "OTHER_DEVICE=%%A"
        set "OTHER_STATE=%%B"
      )
    )
  )
)
if defined QUEST_DEVICE (
  set "DEVICE=!QUEST_DEVICE!"
  set "DEVICE_LINE=!QUEST_LINE!"
)
if defined QUEST_USB_DEVICE (
  set "DEVICE=!QUEST_USB_DEVICE!"
  set "DEVICE_LINE=!QUEST_USB_LINE!"
)
exit /b 0

:adb_missing
call :say "adb.exe was not found."
echo.
call :print_adb_scan
echo.
call :print_adb_download_links
echo.
exit /b 1

:adb_self_check
call :say "Quest ADB Tools - ADB self check"
echo.
set "ADB="
call :find_adb
call :print_adb_scan
echo.
if defined ADB (
  call :say "Self check: usable adb.exe found"
  echo   !ADB!
  echo.
  "!ADB!" version
  exit /b 0
)
call :say "Self check: adb.exe was not found"
echo.
call :print_adb_download_links
exit /b 1

:print_adb_scan
call :say "ADB search paths:"
if defined ADB_EXE (
  call :print_adb_candidate "Environment ADB_EXE" "%ADB_EXE%"
) else (
  call :say "  [--] Environment ADB_EXE is not set"
)
call :print_adb_candidate "BAT directory adb.exe" "%SCRIPT_DIR%adb.exe"
call :print_adb_candidate "BAT directory platform-tools" "%SCRIPT_DIR%platform-tools\adb.exe"
call :print_adb_candidate "BAT directory tools" "%SCRIPT_DIR%tools\adb.exe"
set "PATH_ADB_FOUND="
for /f "delims=" %%A in ('where adb 2^>nul') do (
  set "PATH_ADB_FOUND=1"
  call :print_adb_candidate "PATH search" "%%A"
)
if not defined PATH_ADB_FOUND echo   [--] adb.exe was not found in PATH
call :print_adb_candidate "Android SDK user directory" "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
call :print_adb_candidate "Android SDK ProgramFiles" "%ProgramFiles%\Android\platform-tools\adb.exe"
call :print_adb_candidate "Android SDK ProgramFiles x86" "%ProgramFiles(x86)%\Android\platform-tools\adb.exe"
call :print_adb_candidate "SideQuest ProgramFiles" "%ProgramFiles%\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "SideQuest user directory" "%LOCALAPPDATA%\Programs\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "Oculus diagnostics" "%ProgramFiles%\Oculus\Support\oculus-diagnostics\adb.exe"
call :print_adb_candidate "Oculus runtime" "%ProgramFiles%\Oculus\Support\oculus-runtime\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub bin" "%ProgramFiles%\Meta Quest Developer Hub\resources\bin\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub user bin" "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\bin\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub platform-tools" "%ProgramFiles%\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub user platform-tools" "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "VIVE Business Streaming" "C:\Program Files\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe"
call :print_adb_candidate "VIVE Hub" "C:\Program Files\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe"
if defined ADB (
  echo.
  call :say "Selected adb:"
  echo   !ADB!
) else (
  echo.
  call :say "Selected adb: not found"
)
exit /b 0

:print_adb_candidate
set "SCAN_LABEL=%~1"
set "SCAN_PATH=%~2"
if not defined SCAN_PATH (
  call :say "  [--] !SCAN_LABEL!: not set"
  exit /b 0
)
if exist "!SCAN_PATH!" (
  echo   [OK] !SCAN_LABEL!
  echo        !SCAN_PATH!
) else (
  echo   [--] !SCAN_LABEL!
  echo        !SCAN_PATH!
)
exit /b 0

:print_adb_download_links
call :say "ADB download and fallback options:"
call :say "  1. Official Android SDK Platform-Tools page:"
echo      https://developer.android.com/tools/releases/platform-tools
call :say "  2. Windows ZIP direct link:"
echo      https://dl.google.com/android/repository/platform-tools-latest-windows.zip
call :say "  3. Meta Quest Developer Hub, which also includes ADB:"
echo      https://developers.meta.com/horizon/downloads/package/oculus-developer-hub-win/
echo.
call :say "After installing, use one of these options:"
call :say "  - Extract platform-tools next to this BAT as .\platform-tools\adb.exe"
call :say "  - Or put adb.exe next to this BAT"
call :say "  - Or set ADB_EXE to the full adb.exe path"
call :say "  - Or add platform-tools to Windows PATH"
exit /b 0

:offer_download_adb
echo.
call :say "adb.exe was not found on this PC."
call :say "Download Google Android Platform-Tools into this folder now?"
set /p "DL_ADB=Download platform-tools? [Y/N] "
if /i not "!DL_ADB!"=="Y" if /i not "!DL_ADB!"=="YES" exit /b 1
set "PT_ZIP=%TEMP%\quest-platform-tools.zip"
set "PT_DEST=%SCRIPT_DIR%"
call :say "Downloading platform-tools-latest-windows.zip ..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $env:PT_ZIP -UseBasicParsing; if (Test-Path -LiteralPath ($env:PT_DEST + 'platform-tools')) { Remove-Item -LiteralPath ($env:PT_DEST + 'platform-tools') -Recurse -Force -ErrorAction SilentlyContinue }; Expand-Archive -LiteralPath $env:PT_ZIP -DestinationPath $env:PT_DEST -Force; exit 0 } catch { Write-Host $_; exit 1 }"
if errorlevel 1 (
  call :say "Download or extract failed."
  exit /b 1
)
if exist "%SCRIPT_DIR%platform-tools\adb.exe" (
  call :say "Installed: %SCRIPT_DIR%platform-tools\adb.exe"
  exit /b 0
)
call :say "Download finished but adb.exe was not found in platform-tools."
exit /b 1

:need_adb
if defined ADB exit /b 0
call :offer_download_adb
set "ADB="
call :find_adb
if defined ADB exit /b 0
call :adb_missing
exit /b 1

:need_device
call :need_adb
if errorlevel 1 exit /b 1
call :select_device
if defined DEVICE exit /b 0
call :say "No authorized online ADB device is available."
echo.
"%ADB%" devices -l
echo.
if defined UNAUTH_DEVICE (
  call :say "Device !UNAUTH_DEVICE! is unauthorized. Put on the headset and allow USB debugging."
) else if defined OFFLINE_DEVICE (
  call :say "Device !OFFLINE_DEVICE! is offline. Press [S] to restart ADB, or reconnect USB."
) else if defined OTHER_DEVICE (
  call :say "Device !OTHER_DEVICE! state is !OTHER_STATE!, not normal ADB device mode."
) else (
  call :say "Connect Quest, enable Developer Mode, and allow USB debugging."
)
echo.
exit /b 1

:confirm_danger
echo.
call :say "Risk confirmation: %~1"
call :say "This changes Quest or ADB state. Type YES to continue, or press Enter to cancel."
set "CONFIRM="
set /p "CONFIRM=Confirm: "
if /i "!CONFIRM!"=="YES" exit /b 0
call :say "Canceled."
exit /b 1

:boot_intro
mode con: cols=100 lines=34 >nul 2>nul
title Quest_ADB_Tools By dwgx1337
if /i "%~1"=="menu-test" (
  call :print_intro_static
  exit /b 0
)
call :intro_animation
call :say_b64 "ICAg5oyJ56m65qC86L+b5YWl5bel5YW3Li4u"
call :wait_space
goto :menu

:show_help
mode con: cols=100 lines=34 >nul 2>nul
cls
call :say_b64 "44CQ6YeN6KaB44CR5aaC5p6c5L2g6L+b5YWl5q2k5biu5Yqp6aG16Z2i77yM6KGo56S65L2g5bey57uP6ZiF6K+75bm255+l5pmT5pys6aG16Z2i5Lit55qE5YaF5a6544CC"
echo.
call :write_b64 "ICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiAgICAgICAgICAgICAgICAgICAgICAgIOW4ruWKqSAvIOS9v+eUqOivtOaYjg0KICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICDpobnnm67nlKjpgJTvvJoNCiAgICAtIOivu+WPliBRdWVzdCAvIE1ldGEg5aS05pi+55qEIEFEQiDov57mjqXjgIHkvpvnlLXjgIHkvJHnnKDjgIHnlLXph4/jgIHmiYvmn4Tnur/ntKLlkozluLjnlKjorr7nva7jgIINCiAgICAtIOaPkOS+m+iPnOWNleWSjCBXZWJVSSDkuKTnp43lhaXlj6PvvJtXZWJVSSDmm7Tnm7Top4LvvIzmjqjojZDkvb/nlKjjgIINCiAgICAtIOWbnuWIsOS4u+iPnOWNleWQjuaMiSBbV10g5Y2z5Y+v5ZCv5YqoIFdlYlVJ77yM5Y+q55uR5ZCsIDEyNy4wLjAuMeOAgg0KDQogIOmHjeimgeivtOaYju+8mg0KICAgIC0g5pys5bel5YW35LiN5Lya57uV6L+H5o6I5p2D77yb5b+F6aG755Sx55So5oi36Ieq5bex5byA5ZCv5byA5Y+R6ICF5qih5byP5bm25YWB6K64IFVTQiDosIPor5XjgIINCiAgICAtIFF1ZXN0IOaXoOazleivhuWIq+OAgeacquaOiOadg+OAgeaOiee6v+OAgeayoeeUteOAgempseWKqOW8guW4uOOAgee6v+adkOW8guW4uOOAgee9kee7nOW8guW4uO+8jA0KICAgICAg6YCa5bi45p2l6Ieq55So5oi36K6+5aSH44CB55S16ISR546v5aKD5oiW6L+e5o6l5p2h5Lu277yb6K+35YWI5oyJIFtUXSDor4rmlq3jgIINCiAgICAtIOWGmeWFpeexu+WKn+iDveS8muaJp+ihjCBBREIgc2V0dGluZ3MgLyBpbnB1dCAvIGJyb2FkY2FzdCDnrYnlkb3ku6TjgIINCiAgICAtIOS4jeaVouS9v+eUqOaXtu+8jOivt+WFiOWuoeafpei/meS4qiBCQVQg5rqQ56CB77yM56Gu6K6k5ZG95Luk5ZCr5LmJ5ZCO5YaN5pON5L2c44CCDQoNCiAg5bu66K6u5rWB56iL77yaDQogICAgMS4g5YWI5oyJIFtUXSDor4rmlq3ov57mjqXvvIzlho3mjIkgWzFdIOafpeeci+eKtuaAge+8m+ehruiupOaXoOivr+WQjuWGjeWGmeWFpeiuvue9ruOAgg0KICAgIDIuIOaOqOiNkOaMiSBbV10g5L2/55SoIFdlYlVJ77yM5Y+v5p+l55yL5Y+C5pWw5L+u5pS55YiX6KGo44CB5pel5b+X44CB6YCa55+l5ZKM5Y2V6aG56YeN572u44CCDQogICAgMy4g55+t5pe25rWL6K+V5ZCO5omn6KGMIFtQXSDlronlhajnhoTlsY/miJYgWzZdIOS/neWuiOm7mOiupOWAvO+8jOmBv+WFjemVv+aXtumXtOS/nea0u+OAgg0KICAgIDQuIOaDs+e7p+e7reaPkOWNh++8jOivt+WtpuS5oCBBRELjgIFBbmRyb2lkIHNldHRpbmdz44CBUXVlc3Qg5byA5Y+R6ICF5qih5byP5ZKMIFVTQiDpqbHliqjjgIINCg0KICBXZWJVSe+8mg0KICAgIC0g5o6o6I2Q5L2/55So44CC5Li76I+c5Y2V5oyJIFtXXSDlkK/liqjvvIzmtY/op4jlmajmiZPlvIAgMTI3LjAuMC4x44CCDQogICAgLSBXZWJVSSDmj5DkvpvnirbmgIHmn6XnnIvjgIHlv6vmjbfmjqfliLblj7DjgIHml6Xlv5fjgIHpgJrnn6XjgIHlj4LmlbDkv67mlLnliJfooajlkozljZXpobnph43nva7jgII="
if /i "%~1"=="help-test" exit /b 0
echo.
pause
exit /b 0
:print_intro_static
color 0F >nul 2>nul
cls
echo.
echo    ==================================================================================
echo.
echo       ____                  __
echo      / __ \__  _____  _____/ /_
echo     / / / / / / / _ \/ ___/ __/
echo    / /_/ / /_/ /  __(__  ) /_
echo    \___\_\__,_/\___/____/\__/
echo.
echo        ___    ____  ____     ______            __
echo       /   ^|  / __ \/ __ )   /_  __/___  ____  / /____
echo      / / ^| ^| / / / / __  ^|    / / / __ \/ __ \/ / ___/
echo     / ___ ^|/ /_/ / /_/ /    / / / /_/ / /_/ / (__  )
echo    /_/  ^|_/_____/_____/    /_/  \____/\____/_/____/
echo.
echo                              By dwgx1337
echo.
echo    ==================================================================================
echo.
call :say_b64 "ICAgW1dFQlVJXSDmjqjojZDov5vlhaXkuLvoj5zljZXlkI7mjIkgVyDlkK/liqjmnKzlnLAgV2ViVUkg5o6n5Yi26Z2i5p2/44CC"
call :say_b64 "ICAgW0hFTFAgXSDkuLvoj5zljZXmjIkgSCDmn6XnnIvluK7liqnjgIHor7TmmI7lkozpo47pmanmj5DnpLrjgII="
echo    [ADB  ] %ADB%
echo.
exit /b 0

:intro_animation
call :intro_slant_white
exit /b 0

:intro_slant_white
call :print_intro_static
exit /b 0

:wait_space
pause >nul
exit /b 0

:menu
mode con: cols=100 lines=34 >nul 2>nul
call :print_header
echo [AI Agent] MCP: mcp\quest_adb_control_mcp.py (control, two-phase confirm) + mcp\quest_adb_safe_mcp.py (read-only). Skill: quest-control. Docs: docs\CONTROL_MCP.md
echo.
call :write_b64 "6I+c5Y2V77yaDQogIFtXXSDlkK/liqggV2ViVUkg5o6n5Yi26Z2i5p2/ICAgICAgIFtIXSDluK7liqkgLyDpo47pmanmj5DnpLoNCiAgW0ZdIEFEQiDoh6rmo4AgLyDmiavmj4/nm67lvZUgICAgICAgW1RdIOiviuaWrei/nuaOpSAvIEFEQg0KICBbMV0g5p+l55yL5Y+q6K+754q25oCBICAgICAgICAgICAgICBbUl0g5p+l55yL55u45YWzIHNldHRpbmdzDQogIFtTXSDph43lkK/nlLXohJHnq68gQURCIOacjeWKoSAgICAgICBbTV0g5q+PIDUg56eS55uR5o6n54q25oCBDQogIFtQXSDlronlhajnhoTlsY8gICAgICAgICAgICAgICAgICBbNl0g5oGi5aSN5L+d5a6I6buY6K6k5YC8DQogIFtLXSDnn63mnJ/kv53mtLsgLyDosIPor5XmqKHlvI8gICAgICAgW0xdIOWPquivuyBrZWVwYWxpdmUg55uR5o6nDQogIFs3XSDlvIDlkK/ml6Dnur8gQURCICAgICAgICAgICAgICBbOF0g5YWz6Zet5peg57q/IEFEQg0KICBbOV0g5LuO5aSH5Lu95oGi5aSN6K6+572uICAgICAgICAgICAgW1FdIOmAgOWHug0K"
set "CHOICE="
call :write_b64 "6K+36YCJ5oup77ya"
set /p "CHOICE="
if not defined CHOICE exit /b 0
if /i "!CHOICE!"=="Q" exit /b 0
if "!CHOICE!"=="0" exit /b 0
if /i "!CHOICE!"=="W" (
  call :start_webui
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="H" (
  call :show_help
  goto :menu
)
if /i "!CHOICE!"=="F" (
  call :adb_self_check
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="T" (
  call :diagnose_connection
  call :pause_back
  goto :menu
)
if "!CHOICE!"=="1" (
  call :print_status
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="R" (
  call :print_related_full
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="S" (
  call :restart_adb_server
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="M" (
  call :watch_loop
  goto :menu
)
if /i "!CHOICE!"=="P" (
  call :safe_sleep_headset
  call :pause_back
  goto :menu
)
if "!CHOICE!"=="6" (
  call :restore_sleep_defaults
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="K" (
  call :apply_keep_awake
  call :pause_back
  goto :menu
)
if /i "!CHOICE!"=="L" (
  call :keepalive_loop
  goto :menu
)
if "!CHOICE!"=="7" (
  call :enable_wireless_adb
  call :pause_back
  goto :menu
)
if "!CHOICE!"=="8" (
  call :disable_wireless_adb
  call :pause_back
  goto :menu
)
if "!CHOICE!"=="9" (
  call :restore_backup
  call :pause_back
  goto :menu
)
call :write_b64 "5pyq6K+G5Yir55qE6YCJ6aG577ya"
echo !CHOICE!
call :pause_back
goto :menu

:pause_back
echo.
call :say_b64 "5oyJ5Lu75oSP6ZSu6L+U5Zue5Li76I+c5Y2VLi4u"
pause >nul
exit /b 0

:say
setlocal DisableDelayedExpansion
set "SAY_TEXT=%~1"
setlocal EnableDelayedExpansion
echo(!SAY_TEXT!
endlocal
endlocal
exit /b 0

:write_b64
setlocal DisableDelayedExpansion
set "QB64=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$enc=New-Object System.Text.UTF8Encoding($false); [Console]::OutputEncoding=$enc; [Console]::Write([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:QB64)))"
endlocal
exit /b 0

:say_b64
call :write_b64 "%~1"
echo.
exit /b 0
:init_ansi
if defined ESC exit /b 0
where powershell.exe >nul 2>nul
if errorlevel 1 exit /b 0
for /F "delims=" %%E in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[char]27"') do if not defined ESC set "ESC=%%E"
exit /b 0

:print_red
call :init_ansi
if defined ESC (
  echo !ESC![91m%~1!ESC![0m
) else (
  echo %~1
)
exit /b 0

:print_header
cls
echo ============================================================
echo                    Quest_ADB_Tools
echo ============================================================
echo.
call :write_b64 "V2ViVUkg5o6n5Yi26Z2i5p2/77yaDQogIOaMiSBbV10g5ZCv5Yqo5pys5ZywIFdlYlVJ77yM5rWP6KeI5Zmo5omT5byAIDEyNy4wLjAuMSDmjqfliLbpnaLmnb/jgIINCiAgV2ViVUkg5Y+v5p+l55yL5Y+C5pWw5L+u5pS55YiX6KGo44CB5omL5p+E55S16YeP44CB5pel5b+X44CB6YCa55+l5ZKM5Y2V6aG56YeN572u44CCDQoNCg=="
if defined ADB (
  call :say_b64 "QURCIOi3r+W+hO+8mg=="
  echo   %ADB%
) else (
  call :say_b64 "QURCIOi3r+W+hO+8mg=="
  call :say_b64 "ICDmnKrmib7liLAgYWRiLmV4ZQ=="
)
echo.
call :select_device
call :print_connection_hint
echo.
exit /b 0

:print_connection_hint
if defined DEVICE (
  call :say_b64 "6L+e5o6l54q25oCB77ya5bey6L+e5o6l5bm25bey5o6I5p2D"
  call :write_b64 "6K6+5aSH5L+h5oGv77ya"
  echo !DEVICE_LINE!
  call :get_wifi_ip
  if defined WIFI_IP (
    call :write_b64 "V2ktRmkgSVDvvJo="
    echo !WIFI_IP!
  )
  exit /b 0
)
if defined UNAUTH_DEVICE (
  call :say_b64 "6L+e5o6l54q25oCB77ya5Y+R546w5aS05pi+77yM5L2G5bCa5pyq5o6I5p2D"
  call :write_b64 "6K6+5aSH5bqP5YiX77ya"
  echo !UNAUTH_DEVICE!
  call :say_b64 "5aSE55CG5o+Q56S677ya5oi05LiK5aS05pi+77yM5ZyoIFVTQiDosIPor5XlvLnnqpfkuK3pgInmi6nlhYHorrjjgII="
  exit /b 0
)
if defined OFFLINE_DEVICE (
  call :say_b64 "6L+e5o6l54q25oCB77ya5Y+R546w5aS05pi+77yM5L2GIEFEQiDnirbmgIHkuLogb2ZmbGluZQ=="
  call :write_b64 "6K6+5aSH5bqP5YiX77ya"
  echo !OFFLINE_DEVICE!
  call :say_b64 "5aSE55CG5o+Q56S677ya5oyJIFtTXSDph43lkK8gQURCIOacjeWKoe+8m+S4jeihjOWwsemHjeaPkiBVU0Ig5oiW5pu05o2i5pWw5o2u57q/44CC"
  exit /b 0
)
if defined OTHER_DEVICE (
  call :say_b64 "6L+e5o6l54q25oCB77ya5Y+R546w6K6+5aSH77yM5L2G54q25oCB5byC5bi4"
  call :write_b64 "6K6+5aSH5bqP5YiX77ya"
  echo !OTHER_DEVICE!
  call :write_b64 "5b2T5YmN54q25oCB77ya"
  echo !OTHER_STATE!
  call :say_b64 "5aSE55CG5o+Q56S677ya6YeN5ZCv5aS05pi+5ZCO6YeN5paw6L+e5o6lIFVTQuOAgg=="
  exit /b 0
)
call :say_b64 "6L+e5o6l54q25oCB77ya5pyq5Y+R546wIEFEQiDorr7lpIc="
call :say_b64 "5aSE55CG5o+Q56S677ya5qOA5p+l5byA5Y+R6ICF5qih5byP44CBVVNCIOiwg+ivleaOiOadg+OAgeaVsOaNrue6v+OAgVdpbmRvd3Mg6amx5Yqo77yM54S25ZCO5oyJIFtUXSDor4rmlq3jgII="
exit /b 0
:get_wifi_ip
set "WIFI_IP="
set "IP_CIDR="
if not defined DEVICE exit /b 1
for /f "tokens=2" %%A in ('call "%ADB%" -s "!DEVICE!" shell ip -f inet addr show wlan0 2^>nul ^| findstr /c:"inet "') do set "IP_CIDR=%%A"
for /f "tokens=1 delims=/" %%A in ("!IP_CIDR!") do set "WIFI_IP=%%A"
exit /b 0

:set_backup_path
set "SAFE_DEVICE=!DEVICE::=_!"
set "SAFE_DEVICE=!SAFE_DEVICE:.=_!"
set "BACKUP_FILE=%SCRIPT_DIR%quest_adb_settings_!SAFE_DEVICE!.bak"
exit /b 0

:backup_settings
call :set_backup_path
if exist "!BACKUP_FILE!" exit /b 0
set "BACKUP_TMP=!BACKUP_FILE!.tmp"
(
  call :say "# Quest ADB Tools settings backup"
  echo # device=!DEVICE!
  echo # created=%DATE% %TIME%
)>"!BACKUP_TMP!"
call :write_backup global stay_on_while_plugged_in
if errorlevel 1 goto :backup_failed
call :write_backup global wifi_sleep_policy
if errorlevel 1 goto :backup_failed
call :write_backup system screen_off_timeout
if errorlevel 1 goto :backup_failed
call :write_backup secure sleep_timeout
if errorlevel 1 goto :backup_failed
move /y "!BACKUP_TMP!" "!BACKUP_FILE!" >nul
exit /b 0

:backup_failed
if exist "!BACKUP_TMP!" del /q "!BACKUP_TMP!" >nul 2>nul
call :say "Backup failed: ADB settings read was incomplete; no write action will continue."
exit /b 1

:write_backup
set "_VAL="
for /f "delims=" %%V in ('call "%ADB%" -s "!DEVICE!" shell settings get %~1 %~2 2^>nul') do set "_VAL=%%V"
if errorlevel 1 exit /b 1
if not defined _VAL set "_VAL=null"
>>"!BACKUP_TMP!" echo %~1 %~2 !_VAL!
exit /b 0

:print_setting
set "_VAL="
for /f "delims=" %%V in ('call "%ADB%" -s "!DEVICE!" shell settings get %~1 %~2 2^>nul') do set "_VAL=%%V"
if not defined _VAL set "_VAL=[empty]"
echo   %~1.%~2 = !_VAL!
exit /b 0

:print_prop
set "_VAL="
for /f "delims=" %%V in ('call "%ADB%" -s "!DEVICE!" shell getprop %~1 2^>nul') do set "_VAL=%%V"
if not defined _VAL set "_VAL=[empty]"
echo   %~1 = !_VAL!
exit /b 0

:print_power_lines
call :say "Power state:"
"%ADB%" -s "!DEVICE!" shell dumpsys power 2>nul | findstr /i /c:"mWakefulness" /c:"mStayOn=" /c:"mProximityPositive" /c:"mStayOnWhilePluggedInSetting" /c:"Sleep timeout"
exit /b 0

:print_battery_lines
call :say "Battery state:"
"%ADB%" -s "!DEVICE!" shell dumpsys battery 2>nul | findstr /i /c:"level" /c:"temperature" /c:"status" /c:"health" /c:"AC powered" /c:"USB powered" /c:"Wireless powered"
exit /b 0

:print_controller_lines
call :say "Controller hints:"
"%ADB%" -s "!DEVICE!" shell dumpsys OVRRemoteService 2>nul | findstr /i /c:"Type:" /c:"Battery:" /c:"TrackingStatus" /c:"Controller" /c:"Remote"
if errorlevel 1 (
  "%ADB%" -s "!DEVICE!" shell dumpsys input 2>nul | findstr /i /c:"touch" /c:"controller" /c:"oculus" /c:"quest"
)
exit /b 0

:print_status
call :need_device
if errorlevel 1 exit /b 1
call :get_wifi_ip
echo.
call :say_b64 "QURCIOi3r+W+hO+8mg=="
echo   %ADB%
call :say "Current device:"
echo   !DEVICE_LINE!
echo.
call :say "Device properties:"
call :print_prop ro.product.model
call :print_prop ro.build.version.release
call :print_prop ro.build.version.sdk
call :print_prop ro.build.version.security_patch
echo.
call :say "ADB and network:"
call :print_setting global adb_enabled
call :print_setting global adb_wifi_enabled
call :print_setting global wifi_on
call :print_setting global wifi_sleep_policy
if defined WIFI_IP (call :say "  wlan0.ip = !WIFI_IP!") else (call :say "  wlan0.ip = [empty]")
echo.
call :say "Sleep and keep-awake:"
call :print_setting global stay_on_while_plugged_in
call :print_setting system screen_off_timeout
call :print_setting secure sleep_timeout
call :print_setting global low_power
echo.
call :say "Display:"
call :print_setting system screen_brightness
call :print_setting system screen_brightness_mode
call :print_setting system dim_screen
echo.
call :print_battery_lines
echo.
call :print_power_lines
echo.
call :print_controller_lines
echo.
call :say "Value notes:"
call :say "  stay_on_while_plugged_in: 0=off, 1=AC, 2=USB, 3=AC+USB, 4=wireless, 8=dock; values can add."
call :say "  wifi_sleep_policy: 0=default, 1=legacy no-sleep while plugged, 2=legacy never sleep."
call :say "  screen_off_timeout: milliseconds. 86400000 = 24 hours."
echo.
exit /b 0

:print_related_full
call :need_device
if errorlevel 1 exit /b 1
echo.
call :say "=== related global settings ==="
"%ADB%" -s "!DEVICE!" shell settings list global | findstr /i "stay sleep screen wifi adb development debug power"
echo.
call :say "=== related secure settings ==="
"%ADB%" -s "!DEVICE!" shell settings list secure | findstr /i "stay sleep screen wifi adb development debug power prox guardian oculus meta"
echo.
call :say "=== related system settings ==="
"%ADB%" -s "!DEVICE!" shell settings list system | findstr /i "stay sleep screen timeout wake power wifi brightness dim"
echo.
call :print_battery_lines
echo.
call :print_power_lines
echo.
call :print_controller_lines
echo.
exit /b 0

:diagnose_connection
call :say "Quest ADB Tools - connection diagnostics"
echo.
call :say "ADB self-check:"
call :print_adb_scan
echo.
if not defined ADB (
  call :adb_missing
  call :say "Common Windows checks:"
  call :say "  - Use a data-capable USB cable, not a charge-only cable."
  call :say "  - Prefer motherboard USB ports before docks or hubs."
  call :say "  - Install Meta Quest Developer Hub, SideQuest, or Android platform-tools."
  call :say "  - Enable Developer Mode for this Quest account in the Meta mobile app."
  echo.
  exit /b 1
)
call :say_b64 "QURCIOi3r+W+hO+8mg=="
echo   %ADB%
echo.
"%ADB%" version
echo.
call :say "ADB server:"
"%ADB%" start-server
echo.
call :say "ADB device list:"
"%ADB%" devices -l
echo.
call :select_device
if defined DEVICE (
  call :say "Diagnosis: OK. Authorized ADB device is online."
  echo   !DEVICE_LINE!
  echo.
  exit /b 0
)
if defined UNAUTH_DEVICE (
  call :say "Diagnosis: device found, but not authorized."
  call :say "Fix: allow USB debugging in the headset; reconnect USB if the prompt is missing."
  exit /b 2
)
if defined OFFLINE_DEVICE (
  call :say "Diagnosis: device found, but state is offline."
  call :say "Fix: press [S] to restart ADB, reconnect USB, or change cable/port."
  exit /b 3
)
if defined OTHER_DEVICE (
  call :say "Diagnosis: device found, but current state is !OTHER_STATE!."
  call :say "Fix: restart the headset and reconnect USB."
  exit /b 4
)
call :say "Diagnosis: no ADB device found."
echo.
call :say "Most common causes:"
call :say "  1. Developer Mode is not enabled."
call :say "  2. USB debugging was not approved in the headset."
call :say "  3. USB cable is charge-only or unstable."
call :say "  4. Windows driver is missing or broken."
call :say "  5. Another ADB server is conflicting."
echo.
where pnputil >nul 2>nul
if not errorlevel 1 (
  call :say "Connected Windows device keywords:"
  pnputil /enum-devices /connected | findstr /i "Quest Oculus Meta Android ADB XR MTP WinUSB Google"
)
echo.
exit /b 5

:restart_adb_server
call :need_adb
if errorlevel 1 exit /b 1
call :say "Restarting ADB server..."
"%ADB%" kill-server
timeout /t 1 /nobreak >nul
"%ADB%" start-server
echo.
"%ADB%" devices -l
echo.
exit /b 0

:restore_sleep_defaults
call :need_device
if errorlevel 1 exit /b 1
call :say "Restoring conservative sleep defaults..."
"%ADB%" -s "!DEVICE!" shell settings put global stay_on_while_plugged_in 0
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global wifi_sleep_policy 1
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put system screen_off_timeout 300000
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings delete secure sleep_timeout
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell am broadcast -a com.oculus.vrpowermanager.prox_open
call :say "Restored normal sleep, conservative Wi-Fi policy, 5-minute screen timeout, and prox_open."
exit /b 0

:safe_sleep_headset
call :restore_sleep_defaults
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell input keyevent KEYCODE_SLEEP
call :say "Sent KEYCODE_SLEEP."
exit /b 0

:apply_keep_awake
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "Enable short keep-awake/debug mode: stay awake, Wi-Fi no sleep, 24-hour screen, prox_close. Use safe sleep afterwards."
if errorlevel 1 exit /b 1
call :backup_settings
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global stay_on_while_plugged_in 3
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global wifi_sleep_policy 2
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put system screen_off_timeout 86400000
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put secure sleep_timeout -1
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell am broadcast -a com.oculus.vrpowermanager.prox_close
call :say "Applied short keep-awake / debug mode."
exit /b 0

:enable_wireless_adb
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "Enable wireless ADB: adbd will listen on 5555. Use briefly only on trusted local networks."
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global adb_wifi_enabled 1
"%ADB%" -s "!DEVICE!" tcpip 5555
call :say "Requested wireless ADB on port 5555."
if defined WIFI_IP (
  call :say "Try: adb connect !WIFI_IP!:5555"
) else (
  call :get_wifi_ip
  if defined WIFI_IP echo Try: adb connect !WIFI_IP!:5555
)
exit /b 0

:disable_wireless_adb
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "Disable wireless ADB and switch back to USB. If currently wireless, disconnect is expected."
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global adb_wifi_enabled 0
"%ADB%" -s "!DEVICE!" usb
call :say "Requested wireless ADB off and USB mode."
exit /b 0

:restore_backup
call :need_device
if errorlevel 1 exit /b 1
call :set_backup_path
if not exist "!BACKUP_FILE!" (
  call :say "Backup file not found: !BACKUP_FILE!"
  exit /b 1
)
call :confirm_danger "Restore settings from backup: !BACKUP_FILE!"
if errorlevel 1 exit /b 1
for /f "usebackq tokens=1,2,*" %%A in ("!BACKUP_FILE!") do (
  if not "%%A"=="#" (
    if /i "%%C"=="null" (
      "%ADB%" -s "!DEVICE!" shell settings delete %%A %%B
    ) else (
      "%ADB%" -s "!DEVICE!" shell settings put %%A %%B %%C
    )
  )
)
"%ADB%" -s "!DEVICE!" shell am broadcast -a com.oculus.vrpowermanager.prox_open
call :say "Tried restoring settings from backup and sent prox_open."
exit /b 0

:watch_loop
call :need_device
if errorlevel 1 exit /b 1
call :say "Refreshing read-only status every 5 seconds. Press Ctrl+C to exit."
:watch_loop_tick
cls
call :print_status
timeout /t 5 /nobreak >nul
goto :watch_loop_tick

:keepalive_loop
call :need_device
if errorlevel 1 exit /b 1
call :say "Read-only keepalive monitor: every 10 seconds, run adb shell echo keepalive and read power hints."
call :say "Press Ctrl+C to exit."
:keepalive_loop_tick
echo.
echo [%DATE% %TIME%]
"%ADB%" -s "!DEVICE!" shell echo keepalive
call :print_power_lines
timeout /t 10 /nobreak >nul
goto :keepalive_loop_tick

:start_webui
call :find_adb
if not defined ADB (
  call :say "ADB not found yet. WebUI can download Google platform-tools."
  set "ADB=adb.exe"
)
where certutil >nul 2>nul
if errorlevel 1 (
  call :say "Cannot start WebUI: Windows certutil.exe was not found, so embedded service cannot be unpacked."
  call :say "The plain BAT menu is still available."
  exit /b 1
)
set "WEBUI_DIR=%TEMP%\Quest_ADB_Tools_WebUI"
set "WEBUI_CACHE_KEY=%~z0"
set "WEBUI_B64=!WEBUI_DIR!\QuestAdbWebUi_!WEBUI_CACHE_KEY!.exe.b64"
set "WEBUI_EXE=!WEBUI_DIR!\QuestAdbWebUi_!WEBUI_CACHE_KEY!.exe"
set "WEBUI_ADB=%ADB%"
set "WEBUI_LOG_ROOT=%SCRIPT_DIR%."
if not exist "!WEBUI_DIR!" mkdir "!WEBUI_DIR!" >nul 2>nul
REM Cache-hit: only launch a cached EXE that still matches the baked-in hash.
REM A mismatch means a same-user process may have pre-planted a file here; drop it and re-unpack.
if exist "!WEBUI_EXE!" (
  call :verify_webui_hash "!WEBUI_EXE!"
  if not errorlevel 1 goto :start_webui_launch
  call :say "Cached WebUI service failed its integrity check; removing it and re-unpacking a trusted copy."
  del /q "!WEBUI_EXE!" >nul 2>nul
)
if exist "!WEBUI_B64!" del /q "!WEBUI_B64!" >nul 2>nul
call :say_b64 "5q2j5Zyo6aaW5qyh6Kej5YyFIFdlYlVJIOacjeWKoe+8jOivt+eojeetiS4uLg=="
call :write_webui_payload_fast "!WEBUI_B64!"
if errorlevel 1 call :write_webui_payload "!WEBUI_B64!"
if errorlevel 1 (
  call :say "Cannot write WebUI payload: !WEBUI_B64!"
  exit /b 1
)
certutil -f -decode "!WEBUI_B64!" "!WEBUI_EXE!" >nul 2>nul
if errorlevel 1 (
  call :say "Cannot unpack WebUI service. certutil may be blocked by policy or security software."
  exit /b 1
)
del /q "!WEBUI_B64!" >nul 2>nul
if not exist "!WEBUI_EXE!" (
  call :say "WebUI EXE was not found after unpacking: !WEBUI_EXE!"
  exit /b 1
)
REM Freshly unpacked EXE must match the baked-in hash. If not, refuse to launch it.
call :verify_webui_hash "!WEBUI_EXE!"
if errorlevel 1 (
  del /q "!WEBUI_EXE!" >nul 2>nul
  call :say "Freshly unpacked WebUI service failed its integrity check; refusing to launch."
  exit /b 1
)
:start_webui_launch
call :say_b64 "5q2j5Zyo5ZCv5YqoIFdlYlVJ77yM5Y+q55uR5ZCsIDEyNy4wLjAuMS4uLg=="
call :write_b64 "5pel5b+X55uu5b2V77ya"
echo %SCRIPT_DIR%Quest_ADB_Logs
start "Quest ADB WebUI" "!WEBUI_EXE!" "!WEBUI_ADB!" "!WEBUI_LOG_ROOT!"
exit /b 0

REM :verify_webui_hash "<exe path>"
REM Returns 0 = hash matches OR verification skipped (empty expected hash); 1 = mismatch.
REM certutil -hashfile prints the hex hash on the middle line, sometimes with spaces between bytes;
REM we strip all spaces and lowercase both sides before comparing.
:verify_webui_hash
setlocal EnableDelayedExpansion
set "VWH_FILE=%~1"
REM Backward-compatible: an unstamped BAT has an empty expected hash, so skip (but warn) and allow launch.
if not defined WEBUI_EXE_SHA256 (
  call :say "Warning: this BAT has no baked-in WebUI hash, so the integrity check is skipped."
  endlocal & exit /b 0
)
set "VWH_EXPECT=!WEBUI_EXE_SHA256: =!"
set "VWH_ACTUAL="
for /f "usebackq skip=1 delims=" %%H in (`certutil -hashfile "!VWH_FILE!" SHA256 2^>nul`) do (
  if not defined VWH_ACTUAL (
    set "VWH_LINE=%%H"
    if /i not "!VWH_LINE:CertUtil=!"=="!VWH_LINE!" (
      REM final "CertUtil: -hashfile command completed successfully." line, ignore
      rem noop
    ) else (
      set "VWH_ACTUAL=!VWH_LINE: =!"
    )
  )
)
if not defined VWH_ACTUAL (
  call :say "Could not compute the WebUI service hash via certutil; treating as an integrity failure."
  endlocal & exit /b 1
)
REM Case-insensitive compare (if /i), after both sides have had spaces stripped.
if /i "!VWH_ACTUAL!"=="!VWH_EXPECT!" (
  endlocal & exit /b 0
)
endlocal & exit /b 1

:write_webui_payload_fast
setlocal DisableDelayedExpansion
set "QUEST_ADB_BAT_PATH=%~f0"
set "QUEST_ADB_WEBUI_B64=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $bat=$env:QUEST_ADB_BAT_PATH; $out=$env:QUEST_ADB_WEBUI_B64; $lines=[IO.File]::ReadAllLines($bat,[Text.Encoding]::UTF8); $start=-1; for($i=0;$i -lt $lines.Length;$i++){ if($lines[$i] -eq ':write_webui_payload'){ $start=$i; break } }; if($start -lt 0){ throw 'payload label not found' }; $outLines=New-Object 'System.Collections.Generic.List[string]'; $inside=$false; for($i=$start+1;$i -lt $lines.Length;$i++){ $line=$lines[$i]; if($line -like '*echo -----BEGIN CERTIFICATE-----'){ [void]$outLines.Add('-----BEGIN CERTIFICATE-----'); $inside=$true; continue }; if($inside){ if($line -like '*echo -----END CERTIFICATE-----'){ [void]$outLines.Add('-----END CERTIFICATE-----'); break }; $marker=' echo '; $pos=$line.IndexOf($marker); if($pos -ge 0){ [void]$outLines.Add($line.Substring($pos + $marker.Length)) } } }; if($outLines.Count -lt 3 -or $outLines[$outLines.Count-1] -ne '-----END CERTIFICATE-----'){ throw 'payload end marker not found' }; [IO.File]::WriteAllLines($out,$outLines,[Text.Encoding]::ASCII)"
set "WEBUI_FAST_RC=%ERRORLEVEL%"
endlocal & exit /b %WEBUI_FAST_RC%

:write_webui_payload
break > "%~1"
>> "%~1" echo -----BEGIN CERTIFICATE-----
>> "%~1" echo TVqQAAMAAAAEAAAA//8AALgAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAgAAAAA4fug4AtAnNIbgBTM0hVGhpcyBwcm9ncmFtIGNhbm5v
>> "%~1" echo dCBiZSBydW4gaW4gRE9TIG1vZGUuDQ0KJAAAAAAAAABQRQAATAEDAFyzj2oAAAAA
>> "%~1" echo AAAAAOAAAgELAQsAANoEAAAIAAAAAAAAXvgEAAAgAAAAAAUAAABAAAAgAAAAAgAA
>> "%~1" echo BAAAAAAAAAAEAAAAAAAAAABABQAAAgAAAAAAAAMAQIUAABAAABAAAAAAEAAAEAAA
>> "%~1" echo AAAAABAAAAAAAAAAAAAAABD4BABLAAAAAAAFAPAEAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo ACAFAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAIAAACAAAAAAAAAAAAAAACCAAAEgAAAAAAAAAAAAAAC50ZXh0AAAA
>> "%~1" echo ZNgEAAAgAAAA2gQAAAIAAAAAAAAAAAAAAAAAACAAAGAucnNyYwAAAPAEAAAAAAUA
>> "%~1" echo AAYAAADcBAAAAAAAAAAAAAAAAABAAABALnJlbG9jAAAMAAAAACAFAAACAAAA4gQA
>> "%~1" echo AAAAAAAAAAAAAAAAQAAAQgAAAAAAAAAAAAAAAAAAAABA+AQAAAAAAEgAAAACAAUA
>> "%~1" echo xOQAAEwTBAABAAAAAQAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAABswAgBEAAAAAQAAEQAAAnQEAAABKBAAAAYAAN4xCgAA
>> "%~1" echo AnQEAAABbwcAAAoAAN4FJgAA3gAAcgEAAHAGbwgAAAooCQAACig5AAAGAADeAAAq
>> "%~1" echo ARwAAAAAEwAQIwAFAQAAAQAAAQAQEQAxEQAAARswBACeAgAAAgAAEQAAKAoAAAoo
>> "%~1" echo CwAACgAA3gUmAADeAAACjmkWMRICFppyEQAAcCgMAAAKFv4BKwEXABMHEQctEQAo
>> "%~1" echo AgAABigNAAAKADhWAgAAAo5pFv4CFv4BEwcRBy0IAhaagAIAAAQCjmkXMAwoDgAA
>> "%~1" echo Cm8PAAAKKwMCF5oAKDgAAAYAFAogPSIAAAsrLwAAcikAAHAoEAAACgdzEQAACgoG
>> "%~1" echo bxIAAAoAB4AEAAAE3h4mABQKAN4AAAAHF1gLByBRIgAA/gIW/gETBxEHLcAABhT+
>> "%~1" echo ARb+ARMHEQctIgByPQAAcCgTAAAKAHKLAABwKDkAAAYAKBQAAAomOKkBAAAajQEA
>> "%~1" echo AAETCBEIFnK5AABwohEIF34EAAAEjBkAAAGiEQgYct0AAHCiEQgZfgMAAASiEQgo
>> "%~1" echo FQAACgxy7wAAcAgoCQAACigTAAAKAHIdAQBwKBMAAAoAclsBAHB+AgAABCgJAAAK
>> "%~1" echo KBMAAAoAcmcBAHB+BwAABCgJAAAKKBMAAAoAcnEBAHB+BAAABIwZAAABcp8BAHAo
>> "%~1" echo FgAACig5AAAGAHJbAQBwfgIAAAQoCQAACig5AAAGAAAcjRIAAAETCREJFnKjAQBw
>> "%~1" echo ohEJFxIDEgQoOwAABqIRCRhyswEAcKIRCRkJKIMAAAaiEQkacrMBAHCiEQkbEQSi
>> "%~1" echo EQkoFwAACig5AAAGAADeBSYAAN4AAHK3AQBwcrsBAHAoGAAAChtvGQAAChMHEQct
>> "%~1" echo EwAACCgaAAAKJgDeBSYAAN4AAAAragAABm8bAAAKEwV+DgAABC0TFP4GqAAABnMc
>> "%~1" echo AAAKgA4AAAQrAH4OAAAEEQUoHQAACiYA3jQTBgBy8QEAcBEGbwgAAAooCQAACigT
>> "%~1" echo AAAKAHLxAQBwEQZvCAAACigJAAAKKDkAAAYAAN4AAAAXEwcrkSoAAAFAAAAAAAEA
>> "%~1" echo DxAABQEAAAEAAIUAIaYABwEAAAEAAKcBUfgBBQEAAAEAABoCCyUCBQEAAAEAAC8C
>> "%~1" echo M2ICNBEAAAEbMAYAmQEAAAMAABEAcx4AAAoKcgECAHALBnLsAwBwcgIEAHAHcuwD
>> "%~1" echo AHAoawAABigFAAAGAAZyEAQAcHIkBABwB3IQBABwKGsAAAYoBQAABgAGcjIEAHBy
>> "%~1" echo RgQAcAdyMgQAcChrAAAGKAUAAAYABnJuBABwcoYEAHAHcm4EAHAoawAABigFAAAG
>> "%~1" echo AAZyjgQAcHKkBABwB3KOBABwKGsAAAYoBQAABgAGcs4EAHAHKHcAAAYajRIAAAET
>> "%~1" echo BREFFnICBABwohEFF3IkBABwohEFGHLsBABwohEFGXL8BABwohEFKAYAAAYAcjYF
>> "%~1" echo AHAMBnLZBQBwcvUFAHAIKHYAAAYZjRIAAAETBREFFnL3BQBwohEFF3IHBgBwohEF
>> "%~1" echo GHIZBgBwohEFKAYAAAYABigDAAAGAAYoBAAABgAGKJcAAAYABm8fAAAKFv4BFv4B
>> "%~1" echo EwYRBi0RAHIrBgBwKBMAAAoAFhMEK0MABm8gAAAKEwcrFBIHKCEAAAoNKCIAAAoJ
>> "%~1" echo byMAAAoAEgcoJAAAChMGEQYt394PEgf+FgIAABtvJQAACgDcABcTBCsAEQQqAAAA
>> "%~1" echo ARAAAAIAXAElgQEPAAAAABswBAAUAQAABAAAEQBzJgAACgoGcmUGAHBypQYAcG8n
>> "%~1" echo AAAKAAZywwYAcHLrBgBwbycAAAoABnIDBwBwciUHAHBvJwAACgAGcj0HAHByYwcA
>> "%~1" echo cG8nAAAKAAZycwcAcHKVBwBwbycAAAoABnKrBwBwcgEIAHBvJwAACgAGchcIAHBy
>> "%~1" echo TwgAcG8nAAAKAAAGbygAAAoTBCs3EgQoKQAACgsAEgEoKgAACiiAAAAGDAJyYQgA
>> "%~1" echo cBIBKCsAAAooCQAACggSASgrAAAKKAcAAAYAABIEKCwAAAoTBREFLbzeDxIE/hYE
>> "%~1" echo AAAbbyUAAAoA3ABycQgAcA0CcrsIAHAJCSiAAAAGKAUAAAYAAnLXCABwcu8IAHAo
>> "%~1" echo gAAABnJPCQBwKAcAAAYAKgEQAAACAIcASM8ADwAAAAAbMAQAqQEAAAUAABEAcmsJ
>> "%~1" echo AHBynwkAcB8qcqsJAHAoCwAABgpzsAAABgsGBygfAAAGAAJy4wkAcHJrCQBwB3sj
>> "%~1" echo AAAEKAUAAAYAAnL9CQBwcp8JAHAHeyQAAAQoBQAABgACch8KAHByQQoAcAd7JQAA
>> "%~1" echo BCgFAAAGAAd7JgAABG8fAAAKFzMbB3smAAAEFm8tAAAKcqsJAHAoLgAAChb+ASsB
>> "%~1" echo FgATBREFLSsCckcKAHByzAoAcAd7JgAABG8vAAAKKDAAAApy0AoAcCgxAAAKbzIA
>> "%~1" echo AAoAKDMAAApy1AoAcCg0AAAKEwYSBnL8CgBwKDUAAApyAAsAcCgxAAAKKDYAAAoM
>> "%~1" echo AAhyCgsAcAYoDwAABig3AAAKAAgoHAAABg0CcjILAHByQAsAcAl8IQAABCg4AAAK
>> "%~1" echo KAUAAAYAAnJKCwBwcmsJAHAJeyMAAAQoBQAABgACcmILAHBynwkAcAl7JAAABCgF
>> "%~1" echo AAAGAAJyggsAcHJBCgBwCXslAAAEKAUAAAYAAN4eEwQAAnKiCwBwEQRvCAAACigJ
>> "%~1" echo AAAKbzIAAAoAAN4AAN4UAAAIKDkAAAoAAN4FJgAA3gAAANwAKgAAAAEoAAAAAPQA
>> "%~1" echo fnIBHhEAAAEAAJQBC58BBQEAAAECAPQAn5MBFAAAAAATMAQASAAAAAYAABEABQQo
>> "%~1" echo LgAAChb+AQoGLTgCHI0SAAABCwcWA6IHF3K2CwBwogcYBKIHGXLQCwBwogcaBaIH
>> "%~1" echo G3LQCgBwogcoFwAACm8yAAAKACoTMAQAfQAAAAcAABEAAAULFgwragcImgoABCUt
>> "%~1" echo BiZy9QUAcAYbbzoAAAoW/gQW/gENCS1FAhyNEgAAARMEEQQWA6IRBBdy6AsAcKIR
>> "%~1" echo BBgGohEEGXIADABwohEEGgQogwAABqIRBBty0AoAcKIRBCgXAAAKbzIAAAoAAAgX
>> "%~1" echo WAwIB45p/gQNCS2MKgAAABMwBABXAAAABgAAEQAEJS0GJnL1BQBwBRpvOgAAChb+
>> "%~1" echo BAoGLT0CHI0SAAABCwcWA6IHF3IODABwogcYBaIHGXIkDABwogcaBCiDAAAGogcb
>> "%~1" echo ctAKAHCiBygXAAAKbzIAAAoAKooAAgMg/wAAAF/SbzsAAAoAAgMeYyD/AAAAX9Jv
>> "%~1" echo OwAACgAqhgACAyD//wAAXygIAAAGAAIDHxBjIP//AABfKAgAAAYAKhMwBACxAAAA
>> "%~1" echo CAAAEQAoCgAACgJvPAAACgpzPQAACgsCbz4AAAoMCCCAAAAA/gQTBREFLSQAByCA
>> "%~1" echo AAAACB5jYNJvOwAACgAHCCD/AAAAX9JvOwAACgAAKwkHCNJvOwAACgAGjmkNCSCA
>> "%~1" echo AAAA/gQTBREFLSQAByCAAAAACR5jYNJvOwAACgAHCSD/AAAAX9JvOwAACgAAKwkH
>> "%~1" echo CdJvOwAACgAHBm8/AAAKAAcWbzsAAAoAB29AAAAKEwQrABEEKgAAABMwAwBDAgAA
>> "%~1" echo CQAAEQAfCY0SAAABEw4RDhZyTgwAcKIRDhdyYAwAcKIRDhhycAwAcKIRDhlyiAwA
>> "%~1" echo cKIRDhpyoAwAcKIRDhtywAwAcKIRDhwCohEOHQOiEQ4eBaIRDgpzQQAACgtzQgAA
>> "%~1" echo CgwWDRYTBCsrAAgJb0MAAAoABhEEmigKAAAGEwUHEQVvRAAACgAJEQWOaVgNABEE
>> "%~1" echo F1gTBBEEBo5p/gQTDxEPLcgfHAaOaRpaWBMGEQYJWBMHKwYRBxdYEwcRBxlfFv4B
>> "%~1" echo Fv4BEw8RDy3qcz0AAAoTCBEIFygIAAAGABEIHxwoCAAABgARCBEHKAkAAAYAEQgG
>> "%~1" echo jmkoCQAABgARCBYoCQAABgARCCAAAQAAKAkAAAYAEQgRBigJAAAGABEIFigJAAAG
>> "%~1" echo ABYTBCsWEQgIEQRvRQAACigJAAAGABEEF1gTBBEECG9GAAAK/gQTDxEPLdoWEwQr
>> "%~1" echo FhEIBxEEb0cAAApvPwAACgARBBdYEwQRBAdvSAAACv4EEw8RDy3aKwkRCBZvOwAA
>> "%~1" echo CgARCG9JAAAKEQf+BBMPEQ8t5nM9AAAKEwkRCRYZKAwAAAYAEQkXHCgNAAAGABEJ
>> "%~1" echo GB0oDQAABgARCRkEKA4AAAYAcz0AAAoTChEKGhcoDAAABgARChseKA0AAAYAHhEI
>> "%~1" echo b0kAAApYEQlvSQAAClgRCm9JAAAKWBMLcz0AAAoTDBEMGSgIAAAGABEMHigIAAAG
>> "%~1" echo ABEMEQsoCQAABgARDBEIbz8AAAoAEQwRCW8/AAAKABEMEQpvPwAACgARDG9AAAAK
>> "%~1" echo Ew0rABENKgATMAMAeQAAAAoAABEAHyQfFARaWAoCIAIBAAAoCAAABgACHxAoCAAA
>> "%~1" echo BgACBigJAAAGAAIXKAkAAAYAAhUoCQAABgACFSgJAAAGAAIDKAkAAAYAAh8UKAgA
>> "%~1" echo AAYAAh8UKAgAAAYAAgQoCAAABgACFigIAAAGAAIWKAgAAAYAAhYoCAAABgAq6gAC
>> "%~1" echo FSgJAAAGAAIDKAkAAAYAAgQoCQAABgACHigIAAAGAAIWbzsAAAoAAhlvOwAACgAC
>> "%~1" echo BCgJAAAGACruAAIVKAkAAAYAAgMoCQAABgACFSgJAAAGAAIeKAgAAAYAAhZvOwAA
>> "%~1" echo CgACHxBvOwAACgACBCgJAAAGACoTMAIAgwEAAAsAABEAKAoAAAoCbzwAAAoKcz0A
>> "%~1" echo AAoLByBQSwMEKAkAAAYABx8UKAgAAAYABxYoCAAABgAHFigIAAAGAAcWKAgAAAYA
>> "%~1" echo BxYoCAAABgAHFigJAAAGAAcDjmkoCQAABgAHA45pKAkAAAYABwaOaSgIAAAGAAcW
>> "%~1" echo KAgAAAYABwZvPwAACgAHA28/AAAKAAdvSQAACgwHIFBLAQIoCQAABgAHHxQoCAAA
>> "%~1" echo BgAHHxQoCAAABgAHFigIAAAGAAcWKAgAAAYABxYoCAAABgAHFigIAAAGAAcWKAkA
>> "%~1" echo AAYABwOOaSgJAAAGAAcDjmkoCQAABgAHBo5pKAgAAAYABxYoCAAABgAHFigIAAAG
>> "%~1" echo AAcWKAgAAAYABxYoCAAABgAHFigJAAAGAAcWKAkAAAYABwZvPwAACgAHb0kAAAoI
>> "%~1" echo WQ0HIFBLBQYoCQAABgAHFigIAAAGAAcWKAgAAAYABxcoCAAABgAHFygIAAAGAAcJ
>> "%~1" echo KAkAAAYABwgoCQAABgAHFigIAAAGAAdvQAAAChMEKwARBCoAGzAFAHcKAAAMAAAR
>> "%~1" echo AAITFAACIMDUAQBvSgAACgACIMDUAQBvSwAACgACb0wAAAoKBhIBKBEAAAYTFREV
>> "%~1" echo LQXdPgoAAChNAAAKB29OAAAKDAgXjRIAAAETFhEWFnLKDABwohEWFm9PAAAKDQmO
>> "%~1" echo aSwNCRaaKFAAAAoW/gErARYAExURFS0F3fgJAAAJFpoXjSkAAAETFxEXFh8gnREX
>> "%~1" echo b1EAAAoTBBEEjmkY/gQW/gETFREVLQXdyQkAABEEFppvUgAAChMFEQQXmhMGFmoT
>> "%~1" echo B3L1BQBwEwhy9QUAcBMJFxMKOMcAAAAACREKmhMLEQtvPgAAChb+ARb+ARMVERUt
>> "%~1" echo BTiiAAAAEQsfOm9TAAAKEwwRDBb+BBb+ARMVERUtBTiEAAAAEQsWEQxvVAAACm9V
>> "%~1" echo AAAKb1YAAAoTDRELEQwXWG9XAAAKb1UAAAoTDhENctAMAHAoDAAAChb+ARMVERUt
>> "%~1" echo DgARDhIHKFgAAAomACs4EQ1y7gwAcCgMAAAKFv4BExURFS0IABEOEwgAKxsRDXIK
>> "%~1" echo DQBwKAwAAAoW/gETFREVLQYAEQ4TCQAAEQoXWBMKEQoJjmn+BBMVERU6Kf///xEJ
>> "%~1" echo KJUAAAaACgAABHK5AABwfgQAAASMGQAAAREGKBYAAApzWQAAChMPEQ9vWgAACnIk
>> "%~1" echo DQBwKI0AAAYTEBEQbz4AAAoW/gIW/gETFREVLQwRECiVAAAGgAoAAAQRCH4DAAAE
>> "%~1" echo KAwAAAotHREPb1oAAApyLg0AcCiNAAAGfgMAAAQoDAAACisBFwATEREPb1sAAApy
>> "%~1" echo Og0AcCgMAAAKFv4BExURFS0xABERExURFS0XAAZyUg0AcCiLAAAGKI8AAAYA3QMI
>> "%~1" echo AAAGKBQAAAYojwAABgDd8gcAABEPb1sAAApyZA0AcCgMAAAKFv4BExURFTrBAAAA
>> "%~1" echo ABERExURFS0XAAZyUg0AcCiLAAAGKI8AAAYA3bUHAAARBXJ8DQBwKC4AAAoW/gET
>> "%~1" echo FREVLRcABnKGDQBwKIsAAAYojwAABgDdiQcAABEPb1oAAApyqg0AcCiNAAAGExIR
>> "%~1" echo EiiHAAAGLCARD29aAAAKcrgNAHAojQAABnLIDQBwKC4AAAoW/gErARcAExURFS0X
>> "%~1" echo AAZy0A0AcCiLAAAGKI8AAAYA3S4HAAAGERIRD29aAAAKKBUAAAYojwAABgDdFAcA
>> "%~1" echo ABEPb1sAAApy6A0AcCgMAAAKFv4BExURFS0xABERExURFS0XAAZyUg0AcCiLAAAG
>> "%~1" echo KI8AAAYA3doGAAAGKBYAAAYojwAABgDdyQYAABEPb1sAAApy/A0AcCgMAAAKFv4B
>> "%~1" echo ExURFS1dABERExURFS0XAAZyUg0AcCiLAAAGKI8AAAYA3Y8GAAARBXJ8DQBwKC4A
>> "%~1" echo AAoW/gETFREVLRcABnIUDgBwKIsAAAYojwAABgDdYwYAAAYoFwAABiiPAAAGAN1S
>> "%~1" echo BgAAEQ9vWwAACnI0DgBwKAwAAAoW/gETFREVLXkAERETFREVLSAABhEHKBMAAAYA
>> "%~1" echo BnJSDQBwKIsAAAYojwAABgDdDwYAABEFcnwNAHAoLgAAChb+ARMVERUtIAAGEQco
>> "%~1" echo EwAABgAGclQOAHAoiwAABiiPAAAGAN3aBQAABgYRD29aAAAKEQcoJwAABiiPAAAG
>> "%~1" echo AN2/BQAAEQ9vWwAACnJ0DgBwKAwAAAoW/gETFREVOp8AAAAAERETFREVLRcABnJS
>> "%~1" echo DQBwKIsAAAYojwAABgDdggUAABEFcnwNAHAoLgAAChb+ARMVERUtFwAGcpYOAHAo
>> "%~1" echo iwAABiiPAAAGAN1WBQAAEQ9vWgAACnK4DQBwKI0AAAZyyA0AcCguAAAKFv4BExUR
>> "%~1" echo FS0XAAZytg4AcCiLAAAGKI8AAAYA3RsFAAAGEQ9vWgAACigoAAAGKI8AAAYA3QMF
>> "%~1" echo AAARD29bAAAKctQOAHAoDAAAChb+ARMVERU6mAAAAAARERMVERUtIQAGcrYOAHBy
>> "%~1" echo BA8AcCiWAAAGKIsAAAYojwAABgDdvAQAABEPb1oAAApyuA0AcCiNAAAGcsgNAHAo
>> "%~1" echo LgAAChb+ARMVERUtIQAGcrYOAHByBA8AcCiWAAAGKIsAAAYojwAABgDddwQAAAAC
>> "%~1" echo IMAnCQBvSwAACgAA3gUmAADeAAAGEQ9vWgAACigtAAAGAN1OBAAAEQ9vWwAACnJK
>> "%~1" echo DwBwKAwAAAoW/gETFREVLUwAERETFREVLSEABnJSDQBwcl4PAHAolgAABiiLAAAG
>> "%~1" echo KI8AAAYA3QoEAAAGEQ9vWgAACnJ6DwBwKI0AAAYonAAABiiPAAAGAN3oAwAAEQ9v
>> "%~1" echo WwAACnKGDwBwKAwAAAoW/gETFREVLUwAERETFREVLSEABnJSDQBwcl4PAHAolgAA
>> "%~1" echo BiiLAAAGKI8AAAYA3aQDAAAGEQ9vWgAACnJgDABwKI0AAAYonQAABiiPAAAGAN2C
>> "%~1" echo AwAAEQ9vWwAACnKoDwBwKAwAAAoW/gETFREVOt0AAAAAERETFREVLSEABnJSDQBw
>> "%~1" echo cl4PAHAolgAABiiLAAAGKI8AAAYA3TsDAAARBXJ8DQBwKC4AAAoW/gETFREVLSEA
>> "%~1" echo BnKGDQBwcsoPAHAolgAABiiLAAAGKI8AAAYA3QUDAAARD29aAAAKcggQAHAojQAA
>> "%~1" echo BhMTERMomwAABiwgEQ9vWgAACnK4DQBwKI0AAAZyyA0AcCguAAAKFv4BKwEXABMV
>> "%~1" echo ERUtIQAGctANAHByDhAAcCiWAAAGKIsAAAYojwAABgDdoAIAAAYRD29aAAAKKKAA
>> "%~1" echo AAYojwAABgDdiAIAABEPb1sAAApyThAAcCgMAAAKFv4BExURFS1tABEPb1oAAApy
>> "%~1" echo Lg0AcCiNAAAGfgMAAAQoLgAAChb+ARMVERUtKwAGcmwQAHAoCgAACnJSDQBwcl4P
>> "%~1" echo AHAolgAABm88AAAKKJAAAAYA3R4CAAAGEQ9vWgAACnLADABwKI0AAAYoowAABgDd
>> "%~1" echo AQIAABEPb1sAAApyoBAAcCgMAAAKFv4BExURFS07ABERExURFS0hAAZyUg0AcHJe
>> "%~1" echo DwBwKJYAAAYoiwAABiiPAAAGAN29AQAABiikAAAGKI8AAAYA3awBAAARD29bAAAK
>> "%~1" echo csgQAHAoDAAAChb+ARMVERU6tgAAAAARERMVERUtIQAGclINAHByXg8AcCiWAAAG
>> "%~1" echo KIsAAAYojwAABgDdZQEAABEFcnwNAHAoLgAAChb+ARMVERUtIQAGcuwQAHByDBEA
>> "%~1" echo cCiWAAAGKIsAAAYojwAABgDdLwEAABEPb1oAAApyuA0AcCiNAAAGcsgNAHAoLgAA
>> "%~1" echo Chb+ARMVERUtIQAGcjwRAHByVhEAcCiWAAAGKIsAAAYojwAABgDd6gAAAAYopgAA
>> "%~1" echo BiiPAAAGAN3ZAAAAEQ9vWwAACnKYEQBwG29cAAAKFv4BExURFS1TABEPb1oAAApy
>> "%~1" echo Lg0AcCiNAAAGfgMAAAQoLgAAChb+ARMVERUtHgAGcmwQAHAoCgAACnJSDQBwbzwA
>> "%~1" echo AAookAAABgDeewYRD29bAAAKKBkAAAYA3msRD29bAAAKcqwRAHAoDAAAChb+ARMV
>> "%~1" echo ERUtHgAGcsYRAHAoCgAACnLiEQBwbzwAAAookAAABgDeMwZylxMAcCgKAAAKKJMA
>> "%~1" echo AAZvPAAACiiQAAAGAADeFBEUFP4BExURFS0IERRvJQAACgDcAAAqAEE0AAAAAAAA
>> "%~1" echo /gUAABAAAAAOBgAABQAAAAEAAAECAAAABAAAAFwKAABgCgAAFAAAAAAAAAATMAQA
>> "%~1" echo wgAAAA0AABEAAxRRIAAIAABzXQAACgoXjSwAAAELFgwgAAABAA04hQAAAAACBxYX
>> "%~1" echo b14AAAoTBBEEFv4CEwcRBy0CK34HFpETBQYRBW87AAAKABEFHw3+ARb+ARMHEQct
>> "%~1" echo DAgYLgMXKwEZAAwrJxEFHwozEQgXLgkIGf4BFv4BKwEWACsBFwATBxEHLQYIF1gM
>> "%~1" echo KwIWDAga/gEW/gETBxEHLQ4AAwZvQAAAClEXEwYrGAAGb0kAAAoJ/gQTBxEHOmn/
>> "%~1" echo //8WEwYrABEGKgAAGzAEAKUAAAAOAAARAAMKFmoLIAAAAQCNLAAAAQwEGBhzXwAA
>> "%~1" echo Cg0AK14ACI5pagYoYAAACmkTBAIIFhEEb14AAAoTBREFFv4CEwcRBy0CK0IHEQVq
>> "%~1" echo WAX+Ahb+ARMHEQctDgAJb2EAAAoAFWoTBt4+CQgWEQVvYgAACgAHEQVqWAsGEQVq
>> "%~1" echo WQoABhZq/gITBxEHLZcA3hIJFP4BEwcRBy0HCW8lAAAKANwABxMGKwAAEQYqAAAA
>> "%~1" echo ARAAAAIAGgBviQASAAAAABswBABPAAAADwAAEQAAAwogAAABAI0sAAABCyspAAeO
>> "%~1" echo aWoGKGAAAAppDAIHFghvXgAACg0JFv4CEwQRBC0CKxEGCWpZCgAGFmr+AhMEEQQt
>> "%~1" echo zADeBSYAAN4AACoAARAAAAAAAQBHSAAFAQAAARMwBQAHBQAAEAAAEQAoigAABgoG
>> "%~1" echo cskTAHBy2RMAcH4EAAAEjBkAAAEoYwAACm8nAAAKAAZy7xMAcH4CAAAEbycAAAoA
>> "%~1" echo BnL/EwBwfgcAAARvJwAACgAGcg8UAHAolAAABm8nAAAKAAZyJxQAcH4CAAAEKGQA
>> "%~1" echo AAotB3I5FABwKwVyRRQAcABvJwAACgASARICKDsAAAYNBnJPFABwCW8nAAAKAAZy
>> "%~1" echo ZxQAcAcogwAABm8nAAAKAAZyfRQAcAhvJwAACgAGcocUAHAJcpsUAHAoDAAACi0H
>> "%~1" echo cjkUAHArBXJFFABwAG8nAAAKAAlymxQAcCguAAAKFv4BEwYRBi1NAByNEgAAARMH
>> "%~1" echo EQcWcqkUAHCiEQcXCaIRBxhyswEAcKIRBxkHKIMAAAaiEQcacrMBAHCiEQcbCKIR
>> "%~1" echo BygXAAAKKDkAAAYABhMFOMgDAAAHF40pAAABEwgRCBYfIJ0RCG9RAAAKFpoTBAZy
>> "%~1" echo tRQAcBEEbycAAAoABnLDFABwEQRyzxQAcCg8AAAGbycAAAoABnLxFABwEQRyARUA
>> "%~1" echo cCg8AAAGbycAAAoABnIzFQBwEQRyOxUAcCg8AAAGbycAAAoABnJlFQBwEQRygRUA
>> "%~1" echo cCg8AAAGbycAAAoABnLBFQBwEQRy2xUAcCg8AAAGbycAAAoABnILFgBwEQRyFxYA
>> "%~1" echo cCg8AAAGbycAAAoABnI5FgBwEQRyURYAcCg8AAAGbycAAAoABnJxFgBwEQRyjRYA
>> "%~1" echo cCg8AAAGbycAAAoABnKxFgBwEQRyvRYAcCg8AAAGbycAAAoABnLfFgBwEQRy5xYA
>> "%~1" echo cCg8AAAGEQRyDxcAcCg8AAAGKFwAAAZvJwAACgAGcikXAHARBHI5FwBwKDwAAAZv
>> "%~1" echo JwAACgAGcmEXAHARBHJ5FwBwKDwAAAZvJwAACgAGcpkXAHARBHK7FwBwKDwAAAZv
>> "%~1" echo JwAACgAGcvUXAHARBHINGABwKDwAAAZvJwAACgAGcksYAHARBHJTGABwKDwAAAZv
>> "%~1" echo JwAACgAGcnkYAHARBChWAAAGbycAAAoABnKHGABwEQRynxgAcCg8AAAGbycAAAoA
>> "%~1" echo BnKHGABwb2UAAApyxRgAcCgMAAAKFv4BEwYRBi0dBnKHGABwEQRyyRgAcHLXGABw
>> "%~1" echo KD0AAAZvJwAACgAGcvUYAHARBHILGQBwchkZAHAoPQAABm8nAAAKAAZyMRkAcBEE
>> "%~1" echo cgsZAHByQRkAcCg9AAAGbycAAAoABnJjGQBwEQRyCxkAcHJxGQBwKD0AAAZvJwAA
>> "%~1" echo CgAGcqMZAHARBHILGQBwcrcZAHAoPQAABm8nAAAKAAZy2xkAcBEEcskYAHBy7xkA
>> "%~1" echo cCg9AAAGbycAAAoABnIVGgBwEQRyLxoAcHI9GgBwKD0AAAZvJwAACgAGclkaAHAR
>> "%~1" echo BHILGQBwcmsaAHAoPQAABm8nAAAKAAYRBChGAAAGAAYRBChHAAAGAAYRBChIAAAG
>> "%~1" echo AAYRBChJAAAGAAYRBChKAAAGAAYRBChLAAAGAAYRBChMAAAGAAYRBChNAAAGAB8M
>> "%~1" echo jRIAAAETBxEHFnJ/GgBwohEHFwZywxQAcG9lAAAKohEHGHKZGgBwohEHGQZyrRoA
>> "%~1" echo cG9lAAAKohEHGnLHGgBwohEHGwZy1xoAcG9lAAAKohEHHHLvGgBwohEHHQZy/xoA
>> "%~1" echo cG9lAAAKohEHHnIXGwBwohEHHwkGcmMZAHBvZQAACqIRBx8KcikbAHCiEQcfCwZy
>> "%~1" echo MRkAcG9lAAAKohEHKBcAAAooOQAABgAGEwUrABEFKgAbMAUAUggAABEAABEAKIoA
>> "%~1" echo AAYKBnKqDQBwAiiDAAAGbycAAAoAKDcAAAYLcj0bAHACKIMAAAZySRsAcAcoZgAA
>> "%~1" echo Cig5AAAGAAACclsbAHAoDAAAChb+ARMIEQgtXwAgoA8AABeNEgAAARMJEQkWcnMb
>> "%~1" echo AHCiEQkoQQAABiYgXgEAAChnAAAKACCgDwAAF40SAAABEwkRCRZyixsAcKIRCShB
>> "%~1" echo AAAGJgZypRsAcHKzGwBwbycAAAoAADgQBwAAAAdyxRgAcCgMAAAKFv4BEwgRCC0L
>> "%~1" echo ctEbAHBzaAAACnoCcvMbAHAoDAAAChb+ARMIEQgtOwAHKDYAAAYAIPoAAAAoZwAA
>> "%~1" echo CgAHIKwNAAByCRwAcChAAAAGJgZypRsAcHJDHABwbycAAAoAADigBgAAAnKNHABw
>> "%~1" echo KAwAAAoW/gETCBEILR8AByg1AAAGAAZypRsAcHKjHABwbycAAAoAADhtBgAAAnK1
>> "%~1" echo HABwKAwAAAoW/gETCBEILR8AByg1AAAGAAZypRsAcHLLHABwbycAAAoAADg6BgAA
>> "%~1" echo AnJLHQBwKAwAAAoW/gETCBEILR8AByg2AAAGAAZypRsAcHJnHQBwbycAAAoAADgH
>> "%~1" echo BgAAAnKNHQBwKAwAAAoW/gETCBEILR8AByg2AAAGAAZypRsAcHKnHQBwbycAAAoA
>> "%~1" echo ADjUBQAAAnK7HQBwKAwAAAoW/gETCBEILR8AByhEAAAGAAZypRsAcHLZHQBwbycA
>> "%~1" echo AAoAADihBQAAAnIJHgBwKAwAAAoW/gETCBEILSkAByCsDQAAch0eAHAoQAAABiYG
>> "%~1" echo cqUbAHByhR4AcG8nAAAKAAA4ZAUAAAJyox4AcCgMAAAKFv4BEwgRCC0pAAcgrA0A
>> "%~1" echo AHK5HgBwKEAAAAYmBnKlGwBwciMfAHBvJwAACgAAOCcFAAACckMfAHAoDAAAChb+
>> "%~1" echo ARMIEQgtTQAgiBMAABqNEgAAARMJEQkWclUfAHCiEQkXB6IRCRhyWx8AcKIRCRly
>> "%~1" echo Zx8AcKIRCShBAAAGJgZypRsAcHJxHwBwbycAAAoAADjGBAAAAnKVHwBwKAwAAAoW
>> "%~1" echo /gETCBEILVUAByCsDQAAcq8fAHAoQAAABiYgiBMAABmNEgAAARMJEQkWclUfAHCi
>> "%~1" echo EQkXB6IRCRhy/R8AcKIRCShBAAAGJgZypRsAcHIFIABwbycAAAoAADhdBAAAAnJj
>> "%~1" echo IABwKAwAAAoW/gETCBEILSkAByCsDQAAcgkcAHAoQAAABiYGcqUbAHBydyAAcG8n
>> "%~1" echo AAAKAAA4IAQAAAJynSAAcCgMAAAKFv4BEwgRCC0pAAcgrA0AAHKzIABwKEAAAAYm
>> "%~1" echo BnKlGwBwcu8gAHBvJwAACgAAOOMDAAACcjMhAHAoDAAAChb+ARMIEQgtKQAHIKwN
>> "%~1" echo AAByRyEAcChAAAAGJgZypRsAcHKjIQBwbycAAAoAADimAwAAAnLdIQBwKAwAAAoW
>> "%~1" echo /gETCBEILTAAByhCAAAGAAcgrA0AAHLzIQBwKEAAAAYmBnKlGwBwclMiAHBvJwAA
>> "%~1" echo CgAAOGIDAAACcpEiAHAoDAAAChb+ARMIEQgtKQAHIKwNAAByoyIAcChAAAAGJgZy
>> "%~1" echo pRsAcHIBIwBwbycAAAoAADglAwAAAnI9IwBwKAwAAAoW/gETCBEILTAAByhCAAAG
>> "%~1" echo AAcgrA0AAHJVIwBwKEAAAAYmBnKlGwBwcrMjAHBvJwAACgAAOOECAAACcu8jAHAo
>> "%~1" echo DAAAChb+ARMIEQgtKQAHIKwNAAByRyEAcChAAAAGJgZypRsAcHIRJABwbycAAAoA
>> "%~1" echo ADikAgAAAnJTJABwKAwAAAoW/gETCBEILSkAByCsDQAAcqMiAHAoQAAABiYGcqUb
>> "%~1" echo AHBybyQAcG8nAAAKAAA4ZwIAAAJysyQAcCgMAAAKFv4BEwgRCC0pAAcgrA0AAHLV
>> "%~1" echo JABwKEAAAAYmBnKlGwBwciUlAHBvJwAACgAAOCoCAAACclslAHAoDAAAChb+ARMI
>> "%~1" echo EQgtOgAHIKwNAABygyUAcChAAAAGJgcgrA0AAHIdHgBwKEAAAAYmBnKlGwBwcs0l
>> "%~1" echo AHBvJwAACgAAONwBAAACcg8mAHAoDAAACi0QAnIjJgBwKAwAAAoW/gErARYAEwgR
>> "%~1" echo CDo8AQAAAANyQSYAcCiNAAAGDANyRyYAcCiNAAAGDQNyTyYAcCiNAAAGEwQIKIUA
>> "%~1" echo AAYsCAkohgAABisBFgATCBEILRVyWyYAcHJ/JgBwKJYAAAZzaAAACnoJKIgAAAYW
>> "%~1" echo /gETCBEILRVysyYAcHLfJgBwKJYAAAZzaAAACnoCcg8mAHAoDAAACiwJCAkopQAA
>> "%~1" echo BisBFwATCBEILRVyIycAcHJDJwBwKJYAAAZzaAAACnoHKEIAAAYAByCsDQAAHI0S
>> "%~1" echo AAABEwkRCRZymycAcKIRCRcIohEJGHKzAQBwohEJGQmiEQkacrMBAHCiEQkbEQQo
>> "%~1" echo iQAABqIRCSgXAAAKKEAAAAYmBnKlGwBwG40SAAABEwkRCRYIohEJF3K3JwBwohEJ
>> "%~1" echo GAmiEQkZcrsnAHCiEQkaEQSiEQkoFwAACm8nAAAKAAAreAJywycAcCgMAAAKFv4B
>> "%~1" echo EwgRCC1ZAANywAwAcCiNAAAGEwURBSiGAAAGEwgRCC0LcuUnAHBzaAAACnoHIKwN
>> "%~1" echo AABy9ycAcBEFKAkAAAooQAAABiYGcqUbAHByGSgAcBEFKAkAAApvJwAACgAAKwty
>> "%~1" echo JygAcHNoAAAKegByMygAcAIogwAABnI/KABwBnKlGwBwb2kAAAotB3LFGABwKwsG
>> "%~1" echo cqUbAHBvZQAACgAoZgAACig5AAAGAADeTBMGAAZyUSgAcHI5FABwbycAAAoABnJX
>> "%~1" echo KABwEQZvCAAACm8nAAAKAHJjKABwAiiDAAAGcm8oAHARBm8IAAAKKGYAAAooOQAA
>> "%~1" echo BgAA3gAABhMHKwARByoAAEEcAAAAAAAAOwAAAMIHAAD9BwAATAAAABEAAAETMAMA
>> "%~1" echo LwAAABIAABEAKIoAAAYKBnL/EwBwfgcAAARvJwAACgAGcn8oAHAoOgAABm8nAAAK
>> "%~1" echo AAYLKwAHKgAbMAQARAIAABMAABEAKIoAAAYKKGoAAAoLcokoAHAoOQAABgAAEgIS
>> "%~1" echo Ayg7AAAGEwQRBHKbFABwKC4AAAoW/gETEBEQLQcJc2gAAAp6CBeNKQAAARMREREW
>> "%~1" echo HyCdERFvUQAAChaaEwURBQgoTgAABhMGKGoAAAoTEhIScq8oAHAoawAAChMHfgYA
>> "%~1" echo AARyzygAcBEHKGwAAAoTCBEIKG0AAAomct8oAHARB3IXKQBwKDEAAAoTCXIjKQBw
>> "%~1" echo EQdyFykAcCgxAAAKEwoRCBEJKDYAAAoTCxEIEQooNgAAChMMEQsRBhYoUwAABn4J
>> "%~1" echo AAAEKG4AAAoAEQwRBhcoUwAABn4JAAAEKG4AAAoAKGoAAAoHKG8AAAoTDQZyVykA
>> "%~1" echo cBELbycAAAoABnJvKQBwEQxvJwAACgAGcoEpAHARBxEJKBgAAAZvJwAACgAGcpcp
>> "%~1" echo AHARBxEKKBgAAAZvJwAACgAGcqcpAHASDShwAAAKahMTEhMocQAACihyAAAKbycA
>> "%~1" echo AAoABnK9KQBwEQZ7HwAABG9zAAAKExQSFChxAAAKKHQAAApvJwAACgAGctcpAHAR
>> "%~1" echo BnsgAAAEbx8AAAosGHLpKQBwEQZ7IAAABG8vAAAKKDAAAAorBXLFGABwAG8nAAAK
>> "%~1" echo AAZypRsAcHLxKQBwbycAAAoAchsqAHARC3InKgBwEQwoZgAACig5AAAGAADeQRMO
>> "%~1" echo AAZyUSgAcHI5FABwbycAAAoABnJXKABwEQ5vCAAACm8nAAAKAHIvKgBwEQ5vCAAA
>> "%~1" echo CigJAAAKKDkAAAYAAN4AAAYTDysAEQ8qQRwAAAAAAAAYAAAA4gEAAPoBAABBAAAA
>> "%~1" echo EQAAARMwAwBKAAAAFAAAEQAcjRIAAAELBxZymBEAcKIHFwIodQAACqIHGHKfAQBw
>> "%~1" echo ogcZAyh1AAAKogcacjsqAHCiBxt+AwAABCh1AAAKogcoFwAACgorAAYqAAAbMAUA
>> "%~1" echo EgEAABUAABEAAANymBEAcG8+AAAKb1cAAAoodgAACh8vfncAAApveAAACgoGcksq
>> "%~1" echo AHAabzoAAAoWLxkGHzpvUwAAChYvDgZyFykAcBtveQAACisBFgATBBEELSEAAnJs
>> "%~1" echo EABwKAoAAApyUSoAcG88AAAKKJAAAAYA3ZsAAAB+BgAABHLPKABwKDYAAAooegAA
>> "%~1" echo CgsHBig2AAAKKHoAAAoMCAcbb1wAAAosCAgoZAAACisBFgATBBEELR4AAnJsEABw
>> "%~1" echo KAoAAApyXyoAcG88AAAKKJAAAAYA3kECcpcTAHAIKHsAAAookAAABgAA3isNAAJy
>> "%~1" echo bBAAcCgKAAAKcmsqAHAJbwgAAAooCQAACm88AAAKKJAAAAYAAN4AAAAqAAABEAAA
>> "%~1" echo AAABAOPkACsRAAABEzAEABEAAAAKAAARAAIDkQIDF1iRHmJgCisABioAAAATMAQA
>> "%~1" echo JAAAABYAABEAAgORAgMXWJEeYmACAxhYkR8QYmACAxlYkR8YYmBuCisABiobMAMA
>> "%~1" echo xAAAABcAABEAc7AAAAYKAAIZF3NfAAAKCwAHcgoLAHAoHgAABgwIFP4BFv4BEwUR
>> "%~1" echo BS0UAAZyeyoAcH0iAAAEBhME3YEAAAAIBigfAAAGAADeEgcU/gETBREFLQcHbyUA
>> "%~1" echo AAoA3AAGBnsjAAAEbz4AAAoW/gJ9IQAABAZ7IQAABC0TBnsiAAAEbz4AAAoW/gEW
>> "%~1" echo /gErARcAEwURBS0LBnK1KgBwfSIAAAQA3hgNAAYWfSEAAAQGCW8IAAAKfSIAAAQA
>> "%~1" echo 3gAABhMEKwAAEQQqARwAAAIAEQA5SgASAAAAAAAABwCbogAYEQAAARMwBQA8AAAA
>> "%~1" echo GAAAEQACAxZvfAAACiYWCislAAIEBgUGWW9eAAAKCwcW/gIMCC0Lcs8qAHBzfQAA
>> "%~1" echo CnoGB1gKAAYF/gQMCC3TKhswBACvAwAAGQAAEQACb34AAAoKBh8Wav4EFv4BEx0R
>> "%~1" echo HS0IFBMcOIwDAAAGIBUAAQBqKGAAAAppCweNLAAAAQwCBgdqWQgHKB0AAAYAFQ0H
>> "%~1" echo HxZZEwQrPwAIEQSRH1AzIQgRBBdYkR9LMxcIEQQYWJEbMw4IEQQZWJEc/gEW/gEr
>> "%~1" echo ARcAEx0RHS0GABEEDSsVABEEF1kTBBEEFv4EFv4BEx0RHS2zCRb+BBb+ARMdER0t
>> "%~1" echo CBQTHDj+AgAACAkfClgoGgAABhMFCAkfDFgoGwAABhMGCAkfEFgoGwAABhMHEQcW
>> "%~1" echo ajIdEQYWajEXEQcRBlgGMA8RBiAAAAAEav4CFv4BKwEWABMdER0tCBQTHDinAgAA
>> "%~1" echo EQbUjSwAAAETCAIRBxEIEQZpKB0AAAYAFhMJFhMKOF4CAAAAEQgRCZEfUDMhEQgR
>> "%~1" echo CRdYkR9LMxYRCBEJGFiRFzMMEQgRCRlYkRj+ASsBFgATHREdLQU4RwIAABEIEQkf
>> "%~1" echo ClgoGgAABhMLEQgRCR8UWCgbAAAGEwwRCBEJHxxYKBoAAAYTDREIEQkfHlgoGgAA
>> "%~1" echo BhMOEQgRCR8gWCgaAAAGEw8RCBEJHypYKBsAAAYTECgKAAAKEQgRCR8uWBENb38A
>> "%~1" echo AAoTERERAygMAAAKFv4BEx0RHTqSAQAAABEMFmoyDxEMIAAAAARq/gIW/gErARYA
>> "%~1" echo Ex0RHS0IFBMcOKkBAAAfHo0sAAABExICERAREh8eKB0AAAYAERIWkR9QMxgREheR
>> "%~1" echo H0szEBESGJEZMwkREhmRGv4BKwEWABMdER0tCBQTHDhjAQAAERIfGigaAAAGExMR
>> "%~1" echo Eh8cKBoAAAYTFBEQHx5qWBETalgRFGpYExURFRZqMg0RFREMWAb+Ahb+ASsBFgAT
>> "%~1" echo HREdLQgUExw4GgEAABEM1I0sAAABExYCERURFhEMaSgdAAAGABELFv4BFv4BEx0R
>> "%~1" echo HS0JERYTHDjrAAAAEQse/gEW/gETHREdOpgAAAAAERZzgAAAChMXERcWc4EAAAoT
>> "%~1" echo GHOCAAAKExkAIAAgAACNLAAAARMaKw0RGREaFhEbb2IAAAoAERgRGhYRGo5pb14A
>> "%~1" echo AAolExsW/gITHREdLdkRGW+DAAAKExzefhEZFP4BEx0RHS0IERlvJQAACgDcERgU
>> "%~1" echo /gETHREdLQgRGG8lAAAKANwRFxT+ARMdER0tCBEXbyUAAAoA3BQTHCs9EQkfLhEN
>> "%~1" echo WBEOWBEPWFgTCQARChdYEwoRChEFLxARCR8uWBEIjmn+Ahb+ASsBFgATHREdOoH9
>> "%~1" echo //8UExwrAAARHCoAASgAAAIA7AJBLQMUAAAAAAIA5QJcQQMUAAAAAAIA2wJ6VQMU
>> "%~1" echo AAAAABMwBQBxAQAAGgAAEQACjmkeMh0CFpEZMxMCF5EtDgIYkR4zCAIZkRb+ASsB
>> "%~1" echo FgArARYAEwoRCi0RAANy5SoAcH0iAAAEODMBAAAUCh4Lcx4AAAoMOAkBAAAAAgco
>> "%~1" echo GgAABg0CBxpYKBsAAAYTBBEEHmoyEAdqEQRYAo5pav4CFv4BKwEWABMKEQotBTjm
>> "%~1" echo AAAACRf+ARb+ARMKEQotDQIHKCMAAAYKOLEAAAAJIAIBAAD+ARb+ARMKEQo6nQAA
>> "%~1" echo AAACBx8UWCgbAAAGaRMFBhEFKCIAAAYTBgIHHxxYKBoAAAYTBwcfJFgTCBEGck4M
>> "%~1" echo AHAoDAAAChb+ARMKEQotDwIRCBEHBgMoIAAABgArThEGcqAMAHAoDAAAChb+ARMK
>> "%~1" echo EQotOQACEQgRBwZywAwAcCghAAAGEwkRCW8+AAAKFjEKCBEJb4QAAAorARcAEwoR
>> "%~1" echo Ci0JCBEJbzIAAAoAAAAHEQRpWAsABx5YAo5p/gIW/gETChEKOuP+//8DCH0mAAAE
>> "%~1" echo KgAAABMwAwAGAQAAGwAAEQAWCjjwAAAAAAMGHxRaWAsHHxRYAo5p/gIW/gETBxEH
>> "%~1" echo LQU43gAAAAIHGlgoGwAABmkMBQgoIgAABg0CBx8PWJEg/wAAAF8TBAIHHxBYKBsA
>> "%~1" echo AAYTBQIHHlgoGwAABmkTBglyYAwAcCgMAAAKFv4BEwcRBy0iDgQRBBkuCwURBWko
>> "%~1" echo IgAABisIBREGKCIAAAYAfSMAAAQrXQlycAwAcCgMAAAKFv4BEwcRBy0iDgQRBBku
>> "%~1" echo CwURBWkoIgAABisIBREGKCIAAAYAfSQAAAQrJwlyiAwAcCgMAAAKFv4BEwcRBy0T
>> "%~1" echo DgQSBShxAAAKKHIAAAp9JQAABAAGF1gKBgT+BBMHEQc6A////yoAABMwAwCmAAAA
>> "%~1" echo HAAAEQAWCjiFAAAAAAMGHxRaWAsHHxRYAo5p/gIW/gETBxEHLQIrdgIHGlgoGwAA
>> "%~1" echo BmkMBQgoIgAABg4EKC4AAAoW/gETBxEHLQIrQQIHHw9YkSD/AAAAXw0CBx5YKBsA
>> "%~1" echo AAZpEwQCBx8QWCgbAAAGEwUJGS4LBREFaSgiAAAGKwgFEQQoIgAABgATBisaBhdY
>> "%~1" echo CgYE/gQTBxEHOm7///9y9QUAcBMGKwARBioAABMwAgAvAAAAHQAAEQACLAwDFjII
>> "%~1" echo AwKOaf4EKwEWAAsHLQhy9QUAcAorDwIDmiUtBiZy9QUAcAorAAYqABswBADQAAAA
>> "%~1" echo HgAAEQACAx5YKBsAAAZpCgIDHxBYKBsAAAYLAgMfFFgoGwAABgwHIAABAABqXxZq
>> "%~1" echo /gEW/gENBo0SAAABEwQDHxxYEwUDCGlYEwYWEwcrcQACEQURBxpaWCgbAAAGEwgR
>> "%~1" echo BhEIaVgTCREJFjIJEQkCjmn+BCsBFgATCxELLQ0AEQQRB3L1BQBwoiswABEEEQcJ
>> "%~1" echo LQoCEQkoJQAABisIAhEJKCQAAAYAogDeDyYAEQQRB3L1BQBwogDeAAAAEQcXWBMH
>> "%~1" echo EQcG/gQTCxELLYQRBBMKKwARCioBEAAAAACGAB+lAA8BAAABEzAEAGgAAAAfAAAR
>> "%~1" echo AAMKAgaRIIAAAABfFv4BDQktBgYYWAorBAYXWAoCBpEg/wAAAF8LByCAAAAAXxb+
>> "%~1" echo AQ0JLRsABx9/Xx5iAgYXWJEg/wAAAF9gCwYYWAoAKwYABhdYCgAoCgAACgIGB29/
>> "%~1" echo AAAKDCsACCoTMAUASgAAAB8AABEAAwoCBigaAAAGCwYYWAoHIACAAABfFv4BDQkt
>> "%~1" echo GQAHIP9/AABfHxBiAgYoGgAABmALBhhYCgAohQAACgIGBxhab38AAAoMKwAIKgAA
>> "%~1" echo GzADAHIAAAAgAAARAAB+BgAABHL/KgBwKDYAAAoKBiiGAAAKDQktAt5SBiiHAAAK
>> "%~1" echo c4gAAAoLByiJAAAKb4oAAAoAFgwrHgAABwhvLQAAChcoiwAACgAA3gUmAADeAAAA
>> "%~1" echo CBdYDAgHbx8AAAoCWf4EDQkt0wDeBSYAAN4AAAAqAAABHAAAAAA7ABJNAAUBAAAB
>> "%~1" echo AAABAGlqAAUBAAABGzAEACUEAAAhAAARACiKAAAGCgAEFmr+AhMQERAtFAACBCgT
>> "%~1" echo AAAGAHIPKwBwc2gAAAp6BCEAAAAAAQAAAP4CFv4BExAREC0UAAIEKBMAAAYAckMr
>> "%~1" echo AHBzaAAACnoDcsAMAHAojQAABgsHKDIAAAYMKGoAAAoTERIRcmkrAHAoawAACg1+
>> "%~1" echo BgAABHL/KgBwCShsAAAKEwQRBChtAAAKJhkoJgAABgARBHKRKwBwKDYAAAoTBQIE
>> "%~1" echo EQUhAAAAAAEAAAAoEgAABhMGEQYWav4EFv4BExAREC0eAAARBSg5AAAKAADeBSYA
>> "%~1" echo AN4AAHJDKwBwc2gAAAp6Go0sAAABEwcRBRkXc18AAAoTCAARCBEHFhpvXgAAChMJ
>> "%~1" echo EQkaMjYRBxaRH1AzLhEHF5EfSzMmEQcYkRkzBxEHGZEaLhQRBxiRGzMJEQcZkRz+
>> "%~1" echo ASsBFgArARcAKwEWABMQERAtLwARCG+MAAAKAAARBSg5AAAKABEEFyiLAAAKAADe
>> "%~1" echo BSYAAN4AAHKhKwBwc2gAAAp6AN4UEQgU/gETEBEQLQgRCG8lAAAKANwAEQUoHAAA
>> "%~1" echo BhMKFhMNfgsAAAQlExISDSiNAAAKAAB+DAAABAkRBW8nAAAKAADeFBENFv4BExAR
>> "%~1" echo EC0IERIojgAACgDcAAZy0ysAcAlvJwAACgAGcuUrAHAIbycAAAoABnL3KwBwEgYo
>> "%~1" echo cQAACihyAAAKbycAAAoABnILLABwEQYoMwAABm8nAAAKAAZyYAwAcBEKeyMAAARv
>> "%~1" echo JwAACgAGcnAMAHARCnskAAAEbycAAAoABnKIDABwEQp7JQAABG8nAAAKAAZyHSwA
>> "%~1" echo cBEKeyYAAARvHwAAChMTEhMocQAACih0AAAKbycAAAoABnI9LABwclUsAHARCnsm
>> "%~1" echo AAAEby8AAAooMAAACm8nAAAKAAZyWSwAcBEKeyEAAAQtB3I5FABwKwVyRRQAcABv
>> "%~1" echo JwAACgARCnshAAAEExAREC0TBnJpLABwEQp7IgAABG8nAAAKABEKeyEAAAQsFBEK
>> "%~1" echo eyMAAARvPgAAChb+Ahb+ASsBFwATEBEQLWEAKDcAAAYTCxELcsUYAHAoLgAAChb+
>> "%~1" echo ARMQERAtQwARCxEKeyMAAAQoLwAABhMMBnJ/LABwEQxvJwAACgAGcqksAHARDG8+
>> "%~1" echo AAAKFjAHcjkUAHArBXJFFABwAG8nAAAKAAAAHwqNEgAAARMUERQWcsssAHCiERQX
>> "%~1" echo CKIRFBhy2ywAcKIRFBkRBigzAAAGohEUGnLhLABwohEUGxEKeyMAAASiERQccu8s
>> "%~1" echo AHCiERQdEQp7JAAABKIRFB5y/ywAcKIRFB8JEQp7JQAABKIRFCgXAAAKKDkAAAYA
>> "%~1" echo AN5BEw4ABnJRKABwcjkUAHBvJwAACgAGclcoAHARDm8IAAAKbycAAAoAcg8tAHAR
>> "%~1" echo Dm8IAAAKKAkAAAooOQAABgAA3gAABhMPKwARDyoAAABBfAAAAAAAAMoAAAAMAAAA
>> "%~1" echo 1gAAAAUAAAABAAABAAAAAFQBAAAVAAAAaQEAAAUAAAABAAABAgAAAPoAAACDAAAA
>> "%~1" echo fQEAABQAAAAAAAAAAgAAAJ4BAAAiAAAAwAEAABQAAAAAAAAAAAAAAAcAAADUAwAA
>> "%~1" echo 2wMAAEEAAAARAAABGzAFAGcFAAAiAAARACiKAAAGCgACctMrAHAojQAABgsWExF+
>> "%~1" echo CwAABCUTFBIRKI0AAAoAAH4MAAAEBxICb48AAAoTFREVLQIUDADeFBERFv4BExUR
>> "%~1" echo FS0IERQojgAACgDcAAgoUAAACi0ICChkAAAKKwEWABMVERUtC3IjLQBwc2gAAAp6
>> "%~1" echo KDcAAAYNCXLFGABwKAwAAAoW/gETFREVLQty0RsAcHNoAAAKegJySS0AcCiNAAAG
>> "%~1" echo crcBAHAoDAAAChMEAnJZLQBwKI0AAAZytwEAcCgMAAAKEwUCcmUtAHAojQAABnK3
>> "%~1" echo AQBwKAwAAAoTBgJyeS0AcCiNAAAGcrcBAHAoDAAAChMHAnJgDABwKI0AAAYTCHOQ
>> "%~1" echo AAAKEwkfDI0BAAABExYRFhZyly0AcKIRFhcJohEWGHK5LQBwohEWGREIohEWGnLF
>> "%~1" echo LQBwohEWGxEEjCUAAAGiERYccs0tAHCiERYdEQWMJQAAAaIRFh5y1S0AcKIRFh8J
>> "%~1" echo EQaMJQAAAaIRFh8Kct0tAHCiERYfCxEHjCUAAAGiERYoFQAACig5AAAGABEHLAwR
>> "%~1" echo CCgxAAAGFv4BKwEXABMVERUtcQARCXLnLQBwEQhy8y0AcCgxAAAKb5EAAAomfgIA
>> "%~1" echo AAQajRIAAAETFxEXFnJVHwBwohEXFwmiERcYcv0tAHCiERcZEQiiERcgYOoAAChY
>> "%~1" echo AAAGEwoRCXIRLgBwEQpvqwAABihnAAAGKAkAAApvkQAACiYAcx4AAAoTCxELclUf
>> "%~1" echo AHBvMgAACgARCwlvMgAACgARC3IXLgBwbzIAAAoAEQQW/gETFREVLQ0RC3InLgBw
>> "%~1" echo bzIAAAoAEQUW/gETFREVLQ0RC3ItLgBwbzIAAAoAEQYW/gETFREVLQ0RC3IzLgBw
>> "%~1" echo bzIAAAoAEQsIbzIAAAoAEQlyOS4AcBELby8AAAooWgAABigJAAAKb5EAAAomfgIA
>> "%~1" echo AAQRC28vAAAKIOCTBAAoWAAABhMMEQxvqwAABiiDAAAGEw0RCXIRLgBwEQ0oNAAA
>> "%~1" echo BigJAAAKb5EAAAomEQx7EwAABC0eEQx7EgAABC0VEQ1ySS4AcBtvOgAAChb+BBb+
>> "%~1" echo ASsBFgATDhEOLUMRBy0/EQgoMQAABiw2EQ1yWS4AcBtvOgAAChYvIhENcp8uAHAb
>> "%~1" echo bzoAAAoWLxIRDXLPLgBwG286AAAKFv4EKwEWACsBFwATFREVOt8AAAAAEQlyAy8A
>> "%~1" echo cBEIcvMtAHAoMQAACm+RAAAKJn4CAAAEGo0SAAABExcRFxZyVR8AcKIRFxcJohEX
>> "%~1" echo GHL9LQBwohEXGREIohEXIGDqAAAoWAAABhMKEQlyES4AcBEKb6sAAAYoZwAABigJ
>> "%~1" echo AAAKb5EAAAomfgIAAAQRC28vAAAKIOCTBAAoWAAABhMPEQ9vqwAABiiDAAAGEw0R
>> "%~1" echo CXIjLwBwEQ0oNAAABigJAAAKb5EAAAomEQ97EwAABC0eEQ97EgAABC0VEQ1ySS4A
>> "%~1" echo cBtvOgAAChb+BBb+ASsBFgATDhEPEwwABnIvLwBwEQlvkgAACm8nAAAKAAZyOy8A
>> "%~1" echo cBENbycAAAoAEQ4W/gETFREVLU8ABnKlGwBwckMvAHARCG8+AAAKFjAHcvUFAHAr
>> "%~1" echo DHJNLwBwEQgoCQAACgByUS8AcCgxAAAKbycAAAoAclUvAHARCCgJAAAKKDkAAAYA
>> "%~1" echo ACtPAAZyUSgAcHI5FABwbycAAAoAEQ0RDHsTAAAEKDAAAAYTEAZyVygAcBEQbycA
>> "%~1" echo AAoAcmkvAHAREHJ9LwBwEQ0oNAAABihmAAAKKDkAAAYAAADeQRMSAAZyUSgAcHI5
>> "%~1" echo FABwbycAAAoABnJXKABwERJvCAAACm8nAAAKAHKJLwBwERJvCAAACigJAAAKKDkA
>> "%~1" echo AAYAAN4AAAYTEysAERMqAEE0AAACAAAAFwAAACkAAABAAAAAFAAAAAAAAAAAAAAA
>> "%~1" echo BwAAABYFAAAdBQAAQQAAABEAAAETMAQAJwAAACMAABEAcp0vAHAKKE0AAAoGbzwA
>> "%~1" echo AAoLAgcWB45pb2IAAAoAAm9hAAAKACoAEzAEAGkAAAAkAAARAHOQAAAKCgZyrDAA
>> "%~1" echo cG+TAAAKA2+TAAAKclUsAHBvkwAACiYGcrwwAHBvkwAACgQokQAABm+TAAAKcsow
>> "%~1" echo AHBvkwAACiYoCgAACgZvkgAACm88AAAKCwIHFgeOaW9iAAAKAAJvYQAACgAqAAAA
>> "%~1" echo EzAEAEcAAAAlAAARAHMmAAAKCgZy0DAAcANvJwAACgAGcn8oAHAEbycAAAoABnLc
>> "%~1" echo MABwDwMocQAACih0AAAKbycAAAoAAnLQMABwBigqAAAGACoAEzADACIAAAAlAAAR
>> "%~1" echo AHMmAAAKCgZy7DAAcANvJwAACgACcvYwAHAGKCoAAAYAKh4CKJQAAAoqHgIolAAA
>> "%~1" echo CioeAiiUAAAKKj4AAns/AAAEAygsAAAGACoAABMwBADfAAAAJgAAEQACe0AAAAR7
>> "%~1" echo PwAABAMoLAAABgADckkuAHAbbzoAAAoW/gQKBi0HAhd9QQAABANyWS4AcBtvOgAA
>> "%~1" echo ChYvIANyny4AcBtvOgAAChYvEQNyzy4AcBtvOgAAChb+BCsBFgAKBi0HAhd9QgAA
>> "%~1" echo BANyBDEAcBtvOgAAChYvEQNyFDEAcBtvOgAAChb+BCsBFgAKBi0MAgNvVQAACn1D
>> "%~1" echo AAAEA3IgMQBwG286AAAKFi8RA3JCMQBwG286AAAKFv4EKwEWAAoGLR0Ce0AAAAR7
>> "%~1" echo PwAABHIXLgBwclgxAHAfRigrAAAGACo+AAJ7PwAABAMoLAAABgAqABMwAwBlAAAA
>> "%~1" echo JgAAEQACe0UAAAR7PwAABAMoLAAABgADckkuAHAbbzoAAAoW/gQKBi0HAhd9RgAA
>> "%~1" echo BANyBDEAcBtvOgAAChYvEQNyFDEAcBtvOgAAChb+BCsBFgAKBi0RAntEAAAEA29V
>> "%~1" echo AAAKfUMAAAQqAAAAGzAFALwFAAAnAAARFBMRFBMSc7MAAAYTExETAn0/AAAEABET
>> "%~1" echo ez8AAAQoKQAABgBztgAABhMPEQ8RE31AAAAEAANy0ysAcCiNAAAGChYTDn4LAAAE
>> "%~1" echo JRMUEg4ojQAACgAAfgwAAAQGEgFvjwAAChMVERUtAhQLAN4UEQ4W/gETFREVLQgR
>> "%~1" echo FCiOAAAKANwAByhQAAAKLQgHKGQAAAorARYAExURFS0eABETez8AAAQWciMtAHBy
>> "%~1" echo 9QUAcCguAAAGAN0DBQAAKDcAAAYMCHLFGABwKAwAAAoW/gETFREVLR4AERN7PwAA
>> "%~1" echo BBZy0RsAcHL1BQBwKC4AAAYA3csEAAADckktAHAojQAABnK3AQBwKAwAAAoNA3JZ
>> "%~1" echo LQBwKI0AAAZytwEAcCgMAAAKEwQDcmUtAHAojQAABnK3AQBwKAwAAAoTBQNyeS0A
>> "%~1" echo cCiNAAAGcrcBAHAoDAAAChMGA3JgDABwKI0AAAYTBx8MjQEAAAETFhEWFnJoMQBw
>> "%~1" echo ohEWFwiiERYYcrktAHCiERYZEQeiERYacsUtAHCiERYbCYwlAAABohEWHHLNLQBw
>> "%~1" echo ohEWHREEjCUAAAGiERYectUtAHCiERYfCREFjCUAAAGiERYfCnLdLQBwohEWHwsR
>> "%~1" echo BowlAAABohEWKBUAAAooOQAABgARE3s/AAAEco4xAHBynjEAcBsoKwAABgARBiwM
>> "%~1" echo EQcoMQAABhb+ASsBFwATFREVOpgAAAAAERN7PwAABHL9LQBwcuctAHARB3KqMQBw
>> "%~1" echo KDEAAAofDCgrAAAGAH4CAAAEGo0SAAABExcRFxZyVR8AcKIRFxcIohEXGHL9LQBw
>> "%~1" echo ohEXGREHohEXIGDqAAARES0RERP+BrQAAAZzlQAAChMRKwAREShZAAAGEwgRCHsT
>> "%~1" echo AAAEFv4BExURFS0SERN7PwAABHKuMQBwKCwAAAYAAHMeAAAKEwkRCXJVHwBwbzIA
>> "%~1" echo AAoAEQkIbzIAAAoAEQlyFy4AcG8yAAAKAAkW/gETFREVLQ0RCXInLgBwbzIAAAoA
>> "%~1" echo EQQW/gETFREVLQ0RCXItLgBwbzIAAAoAEQUW/gETFREVLQ0RCXIzLgBwbzIAAAoA
>> "%~1" echo EQkHbzIAAAoAERN7PwAABHLKMQBwctQxAHAfHigrAAAGABETez8AAARy8jEAcBEJ
>> "%~1" echo by8AAAooWgAABigJAAAKKCwAAAYAEQ8WfUEAAAQRDxZ9QgAABBEPcvUFAHB9QwAA
>> "%~1" echo BH4CAAAEEQlvLwAACiDAJwkAEQ/+BrcAAAZzlQAACihZAAAGEwoRCnsTAAAELRIR
>> "%~1" echo CnsSAAAELQkRD3tBAAAEKwEWABMLEQsW/gETFREVLVUAERN7PwAABBdyQy8AcBEH
>> "%~1" echo bz4AAAoWMAdy9QUAcCsMck0vAHARBygJAAAKAHJRLwBwKDEAAAoRByguAAAGAHL8
>> "%~1" echo MQBwEQcoCQAACig5AAAGAN2dAQAAEQ97QgAABCwQEQYtDBEHKDEAAAYW/gErARcA
>> "%~1" echo ExURFToGAQAAc7gAAAYTDRENEQ99RAAABBENERN9RQAABAARE3s/AAAEchQyAHBy
>> "%~1" echo IDIAcB8oKCsAAAYAfgIAAAQajRIAAAETFxEXFnJVHwBwohEXFwiiERcYcv0tAHCi
>> "%~1" echo ERcZEQeiERcgYOoAABESLRERE/4GtQAABnOVAAAKExIrABESKFkAAAYmEQ0WfUYA
>> "%~1" echo AAR+AgAABBEJby8AAAogwCcJABEN/ga5AAAGc5UAAAooWQAABhMMEQx7EwAABC0V
>> "%~1" echo EQx7EgAABC0MEQ17RgAABBb+ASsBFwATFREVLTEAERN7PwAABBdyPDIAcBEHKAkA
>> "%~1" echo AAoRByguAAAGAHJYMgBwEQcoCQAACig5AAAGAN50ABETez8AAAQWEQ97QwAABBEK
>> "%~1" echo exMAAAQoMAAABhEHKC4AAAYAAN5LExAAABETez8AAAQWcngyAHAREG8IAAAKKAkA
>> "%~1" echo AApy9QUAcCguAAAGAADeBSYAAN4AAHKEMgBwERBvCAAACigJAAAKKDkAAAYAAN4A
>> "%~1" echo AAAAKkFMAAACAAAAQwAAACkAAABsAAAAFAAAAAAAAAAAAAAAcAUAACgAAACYBQAA
>> "%~1" echo BQAAAAEAAAEAAAAAIwAAAEoFAABtBQAASwAAABEAAAETMAMAZwAAACUAABEAcyYA
>> "%~1" echo AAoKBnJRKABwAy0HcjkUAHArBXJFFABwAG8nAAAKAAZynDIAcARvJwAACgAGcmAM
>> "%~1" echo AHAFbycAAAoABnLcMABwAy0HcqwyAHArBXKsMgBwAG8nAAAKAAJytDIAcAYoKgAA
>> "%~1" echo BgAqABMwBADkAAAAKAAAEQADKDEAAAYTCBEILQxy9QUAcBMHOMcAAAACIKAPAABy
>> "%~1" echo vjIAcAMoCQAACig+AAAGCgAGKIQAAAYTCRYTCjiFAAAAEQkRCpoLAAdvVQAACgwI
>> "%~1" echo cuAyAHAbbzoAAAoNCRb+BBMIEQgtWQAICXLgMgBwbz4AAApYb1cAAAoTBBEEHyBv
>> "%~1" echo UwAAChMFEQUWLwQRBCsKEQQWEQVvVAAACgATBhEGb1UAAAoTBhEGbz4AAAoW/gIW
>> "%~1" echo /gETCBEILQYRBhMH3iIAABEKF1gTChEKEQmOaf4EEwgRCDpq////cvUFAHATBysA
>> "%~1" echo ABEHKhMwAwAvAQAAKQAAEQADFv4BDQktC3L6MgBwDDgZAQAAAiUtBiZy9QUAcAoG
>> "%~1" echo clkuAHAbbzoAAAoWLyAGcp8uAHAbbzoAAAoWLxEGcs8uAHAbbzoAAAoW/gQrARYA
>> "%~1" echo DQktC3IyMwBwDDjOAAAABnKAMwBwG286AAAKFv4EDQktC3LCMwBwDDiwAAAABnL8
>> "%~1" echo MwBwG286AAAKFv4EDQktC3I4NABwDDiSAAAABnJsNABwG286AAAKFv4EDQktCHK0
>> "%~1" echo NABwDCt3BnLINABwG286AAAKFv4EDQktCHIINQBwDCtcBnI+NQBwG286AAAKFv4E
>> "%~1" echo DQktCHJwNQBwDCtBBnKaNQBwG286AAAKFv4EDQktCHLENQBwDCsmBig0AAAGCwdv
>> "%~1" echo PgAAChYwB3L2NQBwKwtyDjYAcAcoCQAACgAMKwAIKgATMAIAdAAAACoAABEAAihQ
>> "%~1" echo AAAKFv4BDAgtBBYLK18Cbz4AAAoggAAAAP4CFv4BDAgtBBYLK0cAAg0WEwQrLQkR
>> "%~1" echo BG+WAAAKCgYolwAACi0MBh8uLgcGH1/+ASsBFwAMCC0EFgveGBEEF1gTBBEECW8+
>> "%~1" echo AAAK/gQMCC3FFwsrAAAHKhMwAwDHAAAAKwAAEQACKFAAAAoW/gETBBEELQtykSsA
>> "%~1" echo cA04qgAAAHOQAAAKCgACEwUWEwYrQxEFEQZvlgAACgsAByiXAAAKLRkHHy4uFAcf
>> "%~1" echo Xy4PBx8tLgoHHyD+ARb+ASsBFgATBBEELQgGB2+YAAAKJgARBhdYEwYRBhEFbz4A
>> "%~1" echo AAr+BBMEEQQtrAZvkgAACm9VAAAKDAhvPgAAChb+ARb+ARMEEQQtCHKRKwBwDSsh
>> "%~1" echo CG8+AAAKH1D+Ahb+ARMEEQQtCggWH1BvVAAACgwIDSsACSoAEzADANQAAAAsAAAR
>> "%~1" echo AAIgAAQAAGr+BBb+ARMEEQQtFgKMKgAAAXIaNgBwKGMAAAoNOKkAAAACbCMAAAAA
>> "%~1" echo AACQQFsKBiMAAAAAAACQQP4EFv4BEwQRBC0eEgByIDYAcChxAAAKKJkAAApyKDYA
>> "%~1" echo cCgJAAAKDStpBiMAAAAAAACQQFsLByMAAAAAAACQQP4EFv4BEwQRBC0eEgFyIDYA
>> "%~1" echo cChxAAAKKJkAAApyMDYAcCgJAAAKDSsqByMAAAAAAACQQFsMEgJyODYAcChxAAAK
>> "%~1" echo KJkAAApyQjYAcCgJAAAKDSsACSoTMAMAuAAAAC0AABEAcvUFAHAKAAIlLQYmcvUF
>> "%~1" echo AHAohAAABhMEFhMFK30RBBEFmgsAB29VAAAKDAhvPgAAChb+ARb+ARMGEQYtAitV
>> "%~1" echo Bm8+AAAKFv4BFv4BEwYRBi0CCAoIckkuAHAbbzoAAAoWLyAIcgQxAHAbbzoAAAoW
>> "%~1" echo LxEIchQxAHAbbzoAAAoW/gQrARYAEwYRBi0JCCiDAAAGDd4hABEFF1gTBREFEQSO
>> "%~1" echo af4EEwYRBjpy////BiiDAAAGDSsAAAkqAzADAF4AAAAAAAAAAAIoQgAABgACIKwN
>> "%~1" echo AAByVSMAcChAAAAGJgIgrA0AAHJKNgBwKEAAAAYmAiCsDQAAcvMhAHAoQAAABiYC
>> "%~1" echo IKwNAABymjYAcChAAAAGJgIgrA0AAHK5HgBwKEAAAAYmKgAAAzADAFcAAAAAAAAA
>> "%~1" echo AAIgrA0AAHKjIgBwKEAAAAYmAiCsDQAActUkAHAoQAAABiYCIKwNAAByRyEAcChA
>> "%~1" echo AAAGJgIgrA0AAHKDJQBwKEAAAAYmAiCsDQAAch0eAHAoQAAABiYqABMwBAA4AAAA
>> "%~1" echo LgAAEQASABIBKDsAAAZymxQAcCgMAAAKLQdyxRgAcCsVBheNKQAAAQ0JFh8gnQlv
>> "%~1" echo UQAAChaaAAwrAAgqGzAEAOIAAAAvAAARAAACKFAAAAotAwIrCigOAAAKbw8AAAoA
>> "%~1" echo CgYXjSkAAAELBxYfIp0Hb5oAAAoKBih6AAAKCgYohgAACgwILQcGKG0AAAomBoAF
>> "%~1" echo AAAEBnLkNgBwKDYAAAqABgAABH4GAAAEKG0AAAomfgYAAARyAjcAcChqAAAKDRID
>> "%~1" echo cq8oAHAoawAACnIQNwBwKDEAAAooNgAACoAHAAAEfgcAAARy9QUAcH4JAAAEKJsA
>> "%~1" echo AAoAAN4yJgAoDgAACm8PAAAKgAUAAAR+BQAABIAGAAAEfgYAAARyGjcAcCg2AAAK
>> "%~1" echo gAcAAAQA3gAAKgAAARAAAAAAAQCtrgAyAQAAARswBQBkAAAAMAAAEQAAFgp+CAAA
>> "%~1" echo BCULEgAojQAACgAAfgcAAAQoagAACgwSAnJCNwBwKGsAAApyES4AcAIonAAACihm
>> "%~1" echo AAAKfgkAAAQomwAACgAA3hAGFv4BDQktBwcojgAACgDcAADeBSYAAN4AACoBHAAA
>> "%~1" echo AgAEAEVJABAAAAAAAAABAFxdAAUBAAABGzAFAKwAAAAxAAARAAB+BwAABChQAAAK
>> "%~1" echo LQx+BwAABChkAAAKKwEWABMHEQctCXJyNwBwEwbefX4HAAAEKHsAAAoKIFBGAAAL
>> "%~1" echo Bo5pBzADFisFBo5pB1kADCgKAAAKBggGjmkIWW9/AAAKDQkfCm9TAAAKEwQIFjEH
>> "%~1" echo EQQW/gQrARcAEwcRBy0LCREEF1hvVwAACg0JKIMAAAYTBt4YEwUAcoY3AHARBW8I
>> "%~1" echo AAAKKAkAAAoTBt4AABEGKgEQAAAAAAEAj5AAGBEAAAETMAQAFgMAADIAABEAAnL1
>> "%~1" echo BQBwUQNyljcAcFFy9QUAcApy9QUAcAty9QUAcAxy9QUAcA1y9QUAcBMEcvUFAHAT
>> "%~1" echo BQAguAsAABiNEgAAARMLEQsWcvA3AHCiEQsXcgA4AHCiEQsoPwAABiiEAAAGEwwW
>> "%~1" echo Ew04lwEAABEMEQ2aEwYAEQZvVQAAChMHEQdvPgAACiwSEQdyBjgAcBtvXAAAChb+
>> "%~1" echo ASsBFgATDhEOLQU4WAEAABEHGI0pAAABEw8RDxYfIJ0RDxcfCZ0RDxdvnQAAChMI
>> "%~1" echo EQiOaRj+BBb+ARMOEQ4tBTgjAQAAEQgXmnKbFABwKAwAAAoW/gETDhEOOp0AAAAA
>> "%~1" echo CW8+AAAKFv4BFv4BEw4RDi0DEQcNEQdyFjgAcBtvOgAAChYvJREHci44AHAbbzoA
>> "%~1" echo AAoWLxURB3JMOABwG286AAAKFv4EFv4BKwEXABMJEQksDxEEbz4AAAoW/gEW/gEr
>> "%~1" echo ARcAEw4RDi0EEQcTBBEJLB0RCBaaHzpvUwAAChYvDxEFbz4AAAoW/gEW/gErARcA
>> "%~1" echo Ew4RDi0EEQcTBStsEQgXmnJoOABwKAwAAAosDgZvPgAAChb+ARb+ASsBFwATDhEO
>> "%~1" echo LQURBworQBEIF5pygjgAcCgMAAAKLA4Hbz4AAAoW/gEW/gErARcAEw4RDi0FEQcL
>> "%~1" echo KxUIbz4AAAoW/gEW/gETDhEOLQMRBwwAEQ0XWBMNEQ0RDI5p/gQTDhEOOlj+//8R
>> "%~1" echo BW8+AAAKFv4CFv4BEw4RDi0YAAIRBVEDcpI4AHBRcpsUAHATCjjVAAAAEQRvPgAA
>> "%~1" echo Chb+Ahb+ARMOEQ4tGAACEQRRA3LEOABwUXKbFABwEwo4qgAAAAlvPgAAChb+Ahb+
>> "%~1" echo ARMOEQ4tFwACCVEDcuo4AHBRcpsUAHATCjiBAAAABm8+AAAKFv4CFv4BEw4RDi0U
>> "%~1" echo AAIGUQNyOjkAcFFyaDgAcBMKK1sHbz4AAAoW/gIW/gETDhEOLRQAAgdRA3J2OQBw
>> "%~1" echo UXKCOABwEworNQhvPgAAChb+Ahb+ARMOEQ4tGgACCFEDcrI5AHAIKAkAAApRcsg5
>> "%~1" echo AHATCisJctg5AHATCisAEQoqAAATMAQAIQAAADMAABEAAiDECQAAcuI5AHADKAkA
>> "%~1" echo AAooPgAABiiDAAAGCisABioAAAATMAYAPgAAADQAABEAAiDECQAAcvQ5AHADcrMB
>> "%~1" echo AHAEKGYAAAooPgAABiiDAAAGCgZyEDoAcCgMAAAKLQMGKwVyEDoAcAALKwAHKgAA
>> "%~1" echo EzAEADEAAAAUAAARAAMajRIAAAELBxZyVR8AcKIHFwKiBxhyGjoAcKIHGQSiByg/
>> "%~1" echo AAAGKIMAAAYKKwAGKgAAABMwAwASAAAAMwAAEQB+AgAABAMCKFcAAAYKKwAGKgAA
>> "%~1" echo EzAEADEAAAAUAAARAAMajRIAAAELBxZyVR8AcKIHFwKiBxhyGjoAcKIHGQSiByhB
>> "%~1" echo AAAGKIMAAAYKKwAGKgAAABMwAwCLAAAANQAAEQB+AgAABAMCKFgAAAYKBm+rAAAG
>> "%~1" echo KIMAAAYLBnsTAAAEFv4BDQktFnImOgBwAyhaAAAGKAkAAApzaAAACnoGexIAAAQW
>> "%~1" echo /gENCS07Go0BAAABEwQRBBZyOjoAcKIRBBcGexIAAASMGQAAAaIRBBhyTjoAcKIR
>> "%~1" echo BBkHohEEKBUAAApzaAAACnoHDCsACCoAEzAEAM0AAAA2AAARAAIoRQAABgoGKGQA
>> "%~1" echo AAoW/gEMCC0FOLIAAABzkAAACgsHclQ6AHBvkQAACiYHcno6AHACKAkAAApvkQAA
>> "%~1" echo CiYHco46AHAoagAACg0SA3KkOgBwKGsAAAooCQAACm+RAAAKJgcCcgsZAHBycRkA
>> "%~1" echo cChDAAAGAAcCcgsZAHBytxkAcChDAAAGAAcCcskYAHBy7xkAcChDAAAGAAcCci8a
>> "%~1" echo AHByPRoAcChDAAAGAAYHb5IAAAp+CQAABChuAAAKAHLMOgBwBigJAAAKKDkAAAYA
>> "%~1" echo KgAAABMwBgBqAAAAHQAAEQADIKwNAABy9DkAcARyswEAcAUoZgAACihAAAAGCgZy
>> "%~1" echo xRgAcCgMAAAKFv4BCwctF3LeOgBwBHK3JwBwBShmAAAKc2gAAAp6AgRvkwAACh8g
>> "%~1" echo b5gAAAoFb5MAAAofIG+YAAAKBm+RAAAKJioAABMwBwByAQAANwAAEQACKEUAAAYK
>> "%~1" echo BihkAAAKEwQRBC0RcvA6AHAGKAkAAApzaAAACnoABigKAAAKKJ4AAAoTBRYTBjgD
>> "%~1" echo AQAAEQURBpoLAAdvVQAACgwIbz4AAAosEQhyBDsAcBpvXAAAChb+ASsBFgATBBEE
>> "%~1" echo LQU4yQAAAAgXjSkAAAETBxEHFh8gnREHGW+fAAAKDQmOaRkyFAkWmiiFAAAGLAoJ
>> "%~1" echo F5oohgAABisBFgATBBEELQU4igAAAAkYmnIQOgBwKAwAAAoW/gETBBEELSMCIKwN
>> "%~1" echo AAByCDsAcAkWmnKzAQBwCReaKGYAAAooQAAABiYrUAIgrA0AAByNEgAAARMIEQgW
>> "%~1" echo cpsnAHCiEQgXCRaaohEIGHKzAQBwohEIGQkXmqIRCBpyswEAcKIRCBsJGJooiQAA
>> "%~1" echo BqIRCCgXAAAKKEAAAAYmABEGF1gTBhEGEQWOaf4EEwQRBDrs/v//AiCsDQAAch0e
>> "%~1" echo AHAoQAAABiZyKjsAcAYoCQAACig5AAAGACoAABMwBACEAAAAOAAAEQACJS0GJnKb
>> "%~1" echo FABwCgZyOjsAcHI+OwBwb6AAAApytycAcHI+OwBwb6AAAApyQjsAcHI+OwBwb6AA
>> "%~1" echo AApynwEAcHI+OwBwb6AAAAoKfgUAAAQoUAAACi0HfgUAAAQrCigOAAAKbw8AAAoA
>> "%~1" echo CwdyRjsAcAZybjsAcCgxAAAKKDYAAAoMKwAIKhMwBADXAAAAOQAAEQADIMQJAABy
>> "%~1" echo eDsAcCg+AAAGCgJyrRoAcAZymDsAcChgAAAGbycAAAoABnKkOwBwKGAAAAYLByD/
>> "%~1" echo AQAAKHEAAAoSAiihAAAKLBEIIwAAAAAAAFlA/gIW/gErARcADQktHwgjAAAAAAAA
>> "%~1" echo JEBbEwQSBHK8OwBwKHEAAAoomQAACgsCctcaAHAHbycAAAoAAnLEOwBwBnLgOwBw
>> "%~1" echo KGAAAAYoXQAABm8nAAAKAAJy7jsAcAZyCjwAcChgAAAGKF4AAAZvJwAACgACchg8
>> "%~1" echo AHAGKF8AAAZvJwAACgAqABMwBACGAAAAMwAAEQADIIgTAAByMDwAcCg+AAAGCgJy
>> "%~1" echo /xoAcAZyTDwAcChhAAAGbycAAAoAAnJmPABwBnJmPABwKGEAAAZvJwAACgACcnY8
>> "%~1" echo AHAGcnY8AHAoYQAABm8nAAAKAAJynDwAcAZyujwAcChhAAAGbycAAAoAAnL0PABw
>> "%~1" echo BnISPQBwKGIAAAZvJwAACgAqAAATMAQAtgEAADoAABEAAnIwPQBwcsUYAHBvJwAA
>> "%~1" echo CgACclw9AHByxRgAcG8nAAAKAAJyij0AcHLFGABwbycAAAoAAnK0PQBwcsUYAHBv
>> "%~1" echo JwAACgACcuA9AHBy/j0AcG8nAAAKAAMgiBMAAHISPgBwKD4AAAYKcx4AAAoLAAYo
>> "%~1" echo hAAABhMHFhMIOPgAAAARBxEImgwACG9VAAAKDQlyRD4AcBtvOgAAChYyFAlyVj4A
>> "%~1" echo cBtvOgAAChb+BBb+ASsBFgATCREJLQU4tAAAAAlyYj4AcChjAAAGEwQJcmw+AHAo
>> "%~1" echo YwAABhMFCXJ8PgBwKGMAAAYTBhEEcoo+AHAbbxkAAAoW/gETCREJLR4AAnIwPQBw
>> "%~1" echo EQVvJwAACgACcoo9AHARBm8nAAAKAAARBHKUPgBwG28ZAAAKFv4BEwkRCS0eAAJy
>> "%~1" echo XD0AcBEFbycAAAoAAnK0PQBwEQZvJwAACgAABwlvPgAACiCMAAAAMAMJKwwJFiCM
>> "%~1" echo AAAAb1QAAAoAbzIAAAoAABEIF1gTCBEIEQeOaf4EEwkRCTr3/v//B28fAAAKFv4C
>> "%~1" echo Fv4BEwkRCS0cAnLgPQBwcukpAHAHby8AAAooMAAACm8nAAAKACoAABMwBgByAQAA
>> "%~1" echo OwAAEQACcqA+AHByxRgAcG8nAAAKAAJysD4AcHLFGABwbycAAAoAAyCsDQAAcr4+
>> "%~1" echo AHAoPgAABgoABiiEAAAGEwcWEwg4pwAAABEHEQiaCwAHb1UAAAoMCG8+AAAKLBEI
>> "%~1" echo cto+AHAbb1wAAAoW/gErARYAEwkRCS0CK3AIGI0pAAABEwoRChYfIJ0RChcfCZ0R
>> "%~1" echo ChdvnQAACg0Jjmkb/gQTCREJLUUAAnKgPgBwG40SAAABEwsRCxYJGJqiEQsXcicq
>> "%~1" echo AHCiEQsYCReaohELGXLwPgBwohELGgkamqIRCygXAAAKbycAAAoAKxgAEQgXWBMI
>> "%~1" echo EQgRB45p/gQTCREJOkj///8DIKwNAABy+j4AcCg+AAAGEwQRBHIePwBwKGUAAAYT
>> "%~1" echo BREEcjI/AHAoZQAABhMGEQVyxRgAcCguAAAKLBERBnLFGABwKC4AAAoW/gErARcA
>> "%~1" echo EwkRCS0fAnKwPgBwck4/AHARBnJWPwBwEQUoZgAACm8nAAAKACoAABMwBACcAAAA
>> "%~1" echo KQAAEQACcmQ/AHByxRgAcG8nAAAKAAJyeD8AcHLFGABwbycAAAoAcow/AHAKAyCI
>> "%~1" echo EwAAcr4yAHAGKAkAAAooPgAABgsHcro/AHAGctAKAHAoMQAAChtvOgAAChb+BBb+
>> "%~1" echo AQ0JLQIrOAJyZD8AcAZvJwAACgAHcs4/AHAoZAAABgwIcsUYAHAoLgAAChb+AQ0J
>> "%~1" echo LQ0Ccng/AHAIbycAAAoAKhMwBABQAQAAPAAAEQACcug/AHByxRgAcG8nAAAKAAMg
>> "%~1" echo iBMAAHIGQABwKD4AAAYKBnImQABwKGIAAAYLB3LFGABwKAwAAAoW/gETBxEHLQU4
>> "%~1" echo BwEAAAdySkAAcChpAAAGDAdyekAAcChpAAAGDQdyskAAcChpAAAGEwQHcthAAHBy
>> "%~1" echo zAoAcChoAAAGEwVzHgAAChMGCHLFGABwKC4AAAoW/gETBxEHLRgRBghyswEAcHL1
>> "%~1" echo BQBwb6AAAApvMgAACgAJcsUYAHAoLgAAChb+ARMHEQctExEGCXIIQQBwKAkAAApv
>> "%~1" echo MgAACgARBHLFGABwKC4AAAoW/gETBxEHLRQRBnIOQQBwEQQoCQAACm8yAAAKABEF
>> "%~1" echo csUYAHAoLgAAChb+ARMHEQctChEGEQVvMgAACgACcug/AHARBm8fAAAKLBNyJyoA
>> "%~1" echo cBEGby8AAAooMAAACisFcsUYAHAAbycAAAoAKhMwBwC5AAAAKQAAEQACciBBAHBy
>> "%~1" echo xRgAcG8nAAAKAAMgiBMAAHI+QQBwKD4AAAYKBnJsQQBwKGAAAAYLBnKKQQBwKGoA
>> "%~1" echo AAYMCHLFGABwKAwAAAoW/gENCS0MBnLOQQBwKGoAAAYMB3LFGABwKC4AAAotEAhy
>> "%~1" echo xRgAcCguAAAKFv4BKwEWAA0JLTwCciBBAHByDEIAcAcIcsUYAHAoLgAACi0HcvUF
>> "%~1" echo AHArEHIcQgBwCHI0QgBwKDEAAAoAKDEAAApvJwAACgAqAAAAEzAEAEoBAAA8AAAR
>> "%~1" echo AAJyOEIAcHLFGABwbycAAAoAAyBwFwAAclZCAHAoPgAABgoGchAEAHAoawAABgsG
>> "%~1" echo cuwDAHAoawAABgwGcjIEAHAoawAABg0Gcm4EAHAoawAABhMEBnKOBABwKGsAAAYT
>> "%~1" echo BXMeAAAKEwYIcsUYAHAoLgAAChb+ARMHEQctCREGCG8yAAAKAAdyxRgAcCguAAAK
>> "%~1" echo Fv4BEwcRBy0JEQYHbzIAAAoACXLFGABwKC4AAAoW/gETBxEHLRMRBnKCQgBwCSgJ
>> "%~1" echo AAAKbzIAAAoAEQRyxRgAcCguAAAKFv4BEwcRBy0UEQZylEIAcBEEKAkAAApvMgAA
>> "%~1" echo CgARBXLFGABwKC4AAAoW/gETBxEHLRQRBnKeQgBwEQUoCQAACm8yAAAKAAJyOEIA
>> "%~1" echo cBEGbx8AAAosE3InKgBwEQZvLwAACigwAAAKKwVyxRgAcABvJwAACgAqAAATMAcA
>> "%~1" echo 6AIAAD0AABEAc68AAAYKBihqAAAKDBICcqQ6AHAoawAACn0bAAAEBgJ9HAAABAYD
>> "%~1" echo fR0AAAQGcrBCAHAgoA8AABYYjRIAAAENCRZy8DcAcKIJF3IAOABwogkoUAAABgAG
>> "%~1" echo cshCAHACILgLAAByyEIAcChPAAAGAAZyzkIAcAIgcBcAAHLOQgBwKE8AAAYABnLe
>> "%~1" echo QgBwAiBwFwAAcv5CAHAoTwAABgAGcihDAHACIHAXAABySEMAcChPAAAGAAZyckMA
>> "%~1" echo cAIgcBcAAHKSQwBwKE8AAAYABnK8QwBwAiCIEwAAcng7AHAoTwAABgAGcsxDAHAC
>> "%~1" echo IFgbAAByMDwAcChPAAAGAAZy2EMAcAIgKCMAAHIGQABwKE8AAAYABnL9HwBwAiBY
>> "%~1" echo GwAAcuhDAHAoTwAABgAGcgBEAHACICgjAAByCkQAcChPAAAGAAZyJEQAcAIgQB8A
>> "%~1" echo AHI+RABwKE8AAAYABnJoRABwAiBYGwAAcnxEAHAoTwAABgAGcrBEAHACIEAfAABy
>> "%~1" echo vkQAcChPAAAGAAZy6EQAcAIg4C4AAHJWQgBwKE8AAAYABnIERQBwAiBYGwAAcj5B
>> "%~1" echo AHAoTwAABgAGchRFAHACIFgbAAByIEUAcChPAAAGAAZyPEUAcAIg4C4AAHJORQBw
>> "%~1" echo KE8AAAYABnJ8RQBwAiBAHwAAco5FAHAoTwAABgAGcrBFAHACIEAfAAByxEUAcChP
>> "%~1" echo AAAGAAZy+kUAcAIgiBMAAHIARgBwKE8AAAYABnIoRgBwAiCIEwAAcvo+AHAoTwAA
>> "%~1" echo BgAGcjhGAHACIIgTAABySEYAcChPAAAGAAZybEYAcAIguAsAAHJ4RgBwKE8AAAYA
>> "%~1" echo BnKKRgBwAiCIEwAAcppGAHAoTwAABgAGcqpGAHACIIgTAAByvEYAcChPAAAGAAZy
>> "%~1" echo zkYAcAIgQB8AAHLsRgBwKE8AAAYABnI6RwBwAiAQJwAAclpHAHAoTwAABgAGcpBH
>> "%~1" echo AHACIBAnAAByuEcAcChPAAAGAAYoUgAABgAGCysAByoTMAcALQAAAD4AABEAAgMF
>> "%~1" echo FhqNEgAAAQoGFnJVHwBwogYXBKIGGHIaOgBwogYZDgSiBihQAAAGACoAAAATMAQA
>> "%~1" echo FgEAAD8AABEAKKIAAAoKfgIAAAQOBAQoWAAABgsGb6MAAAoAc64AAAYMCAN9FAAA
>> "%~1" echo BAhy8jEAcA4EKFoAAAYoCQAACn0VAAAECAd7EAAABCiDAAAGfRYAAAQIB3sRAAAE
>> "%~1" echo KIMAAAZ9FwAABAgHexIAAAR9GAAABAgHexMAAAR9GQAABAgGb6QAAAp9GgAABAJ7
>> "%~1" echo HwAABAhvpQAACgAHexMAAAQW/gENCS0ZAnsgAAAEA3LcRwBwKAkAAApvMgAACgAr
>> "%~1" echo XAd7EgAABCwGBRb+ASsBFwANCS0kAnsgAAAEA3LkRwBwB2+rAAAGKIMAAAYoMQAA
>> "%~1" echo Cm8yAAAKACskB3sSAAAEFv4BDQktFwJ7IAAABANy7kcAcCgJAAAKbzIAAAoAKgAA
>> "%~1" echo GzACAFcAAABAAAARAAACex8AAARvpgAACgwrHxICKKcAAAoKBnsUAAAEAygMAAAK
>> "%~1" echo Fv4BDQktBAYL3iUSAiioAAAKDQkt1t4PEgL+FgsAABtvJQAACgDcAHOuAAAGCysA
>> "%~1" echo AAcqAAEQAAACAA4ALjwADwAAAAATMAUAlAYAAEEAABEAAnseAAAECgJyzkIAcChR
>> "%~1" echo AAAGb60AAAYLAnK8QwBwKFEAAAZvrQAABgwCcsxDAHAoUQAABm+tAAAGDQJy2EMA
>> "%~1" echo cChRAAAGb60AAAYTBAJyBEUAcChRAAAGb60AAAYTBQJy6EQAcChRAAAGb60AAAYT
>> "%~1" echo BgJyAEQAcChRAAAGb60AAAYTBwJyaEQAcChRAAAGb60AAAYTCAJy/R8AcChRAAAG
>> "%~1" echo b60AAAYTCQJysEQAcChRAAAGb60AAAYTCgJyPEUAcChRAAAGb60AAAYTCwJyfEUA
>> "%~1" echo cChRAAAGb60AAAYTDAZytRQAcAJ7HAAABG8nAAAKAAZyZxQAcAJ7HQAABG8nAAAK
>> "%~1" echo AAZy/kcAcAJ7GwAABG8nAAAKAAZywxQAcAdyzxQAcChmAAAGbycAAAoABnLBFQBw
>> "%~1" echo B3LbFQBwKGYAAAZvJwAACgAGcgsWAHAHchcWAHAoZgAABm8nAAAKAAZyDkgAcAdy
>> "%~1" echo URYAcChmAAAGbycAAAoABnKbFABwB3KNFgBwKGYAAAZvJwAACgAGcrEWAHAHcr0W
>> "%~1" echo AHAoZgAABm8nAAAKAAZy3xYAcAdy5xYAcChmAAAGB3IPFwBwKGYAAAYoXAAABm8n
>> "%~1" echo AAAKAAZy8RQAcAdyARUAcChmAAAGbycAAAoABnIzFQBwB3I7FQBwKGYAAAZvJwAA
>> "%~1" echo CgAGcmUVAHAHcoEVAHAoZgAABm8nAAAKAAZy9RcAcAdyDRgAcChmAAAGbycAAAoA
>> "%~1" echo BnIpFwBwB3I5FwBwKGYAAAZvJwAACgAGcpkXAHAHcrsXAHAoZgAABm8nAAAKAAZy
>> "%~1" echo YRcAcAdyeRcAcChmAAAGbycAAAoABnIeSABwB3I2SABwKGYAAAZvJwAACgAGcksY
>> "%~1" echo AHAHclMYAHAoZgAABm8nAAAKAAZyYEgAcAJybEYAcChRAAAGb60AAAYoZwAABm8n
>> "%~1" echo AAAKAAZyrRoAcAhymDsAcChgAAAGcm5IAHAoCQAACm8nAAAKAAhypDsAcChgAAAG
>> "%~1" echo Ew0RDSD/AQAAKHEAAAoSDiihAAAKLBIRDiMAAAAAAABZQP4CFv4BKwEXABMPEQ8t
>> "%~1" echo IREOIwAAAAAAACRAWxMQEhByvDsAcChxAAAKKJkAAAoTDQZy1xoAcBENcsUYAHAo
>> "%~1" echo DAAACi0OEQ1yNEIAcCgJAAAKKwVyxRgAcABvJwAACgAGcu47AHAIcgo8AHAoYAAA
>> "%~1" echo BiheAAAGbycAAAoABnIYPABwCChfAAAGbycAAAoABnL/GgBwCXJMPABwKGEAAAZv
>> "%~1" echo JwAACgAGcmMZAHAJcmY8AHAoYQAABm8nAAAKAAZyckgAcAlydjwAcChhAAAGbycA
>> "%~1" echo AAoABnKgPgBwAnL6RQBwKFEAAAZvrQAABihuAAAGbycAAAoABnKwPgBwAnIoRgBw
>> "%~1" echo KFEAAAZvrQAABihvAAAGbycAAAoABnKGSABwAnI4RgBwKFEAAAZvrQAABihwAAAG
>> "%~1" echo bycAAAoABnLYQwBwEQQocQAABm8nAAAKAAZyjkgAcBEEcppIAHAoYgAABnLYQABw
>> "%~1" echo cswKAHAoaAAABm8nAAAKAAZyBEUAcBEFKHIAAAZvJwAACgAGcv0fAHARCShzAAAG
>> "%~1" echo bycAAAoABnIARABwEQcCcopGAHAoUQAABm+tAAAGKHQAAAZvJwAACgAGcmhEAHAR
>> "%~1" echo CCh1AAAGbycAAAoABnKwRABwEQoRBih2AAAGbycAAAoABnK+SABwEQYodwAABm8n
>> "%~1" echo AAAKAAZyzkgAcBEGcuwDAHAoawAABm8nAAAKAAZy6kgAcBEGchAEAHAoawAABm8n
>> "%~1" echo AAAKAAZyBEkAcBEGcjIEAHAoawAABm8nAAAKAAZyHEkAcBEGcm4EAHAoawAABm8n
>> "%~1" echo AAAKAAZyPEkAcBEGco4EAHAoawAABm8nAAAKAAZyWkkAcBEGcoBJAHAoawAABm8n
>> "%~1" echo AAAKAAZymkkAcBEGcrJJAHAoawAABm8nAAAKAAZyykkAcBEGcupJAHAoawAABm8n
>> "%~1" echo AAAKAAZyAkoAcBEGcihKAHAoawAABm8nAAAKAAZySkoAcBEGcm5KAHAbbzoAAAoW
>> "%~1" echo LwdyxRgAcCsFcp5KAHAAbycAAAoABnI8RQBwEQsoeQAABhMREhEocQAACih0AAAK
>> "%~1" echo bycAAAoABnJ8RQBwEQxy1koAcCh6AAAGExESEShxAAAKKHQAAApvJwAACgAGcuhK
>> "%~1" echo AHACcs5GAHAoUQAABm+tAAAGKHgAAAZvJwAACgAGctcpAHACeyAAAARvHwAACiwX
>> "%~1" echo cukpAHACeyAAAARvLwAACigwAAAKKwVyxRgAcABvJwAACgAqEzAHAN8GAABCAAAR
>> "%~1" echo AAJ7HgAABAoDLQdy7koAcCsFciBLAHAACwMtB3JSSwBwKwVybEsAcAAMcoJLAHAo
>> "%~1" echo agAAChMHEgdyjksAcChxAAAKKKkAAAooCQAACg0GcrUUAHAofAAABgMofgAABhME
>> "%~1" echo c5AAAAoTBREFcq5LAHAHKH0AAAZywUwAcCgxAAAKb5EAAAomEQVy00wAcG+RAAAK
>> "%~1" echo JhEFG40SAAABEwgRCBZy40wAcKIRCBcDLQdymFoAcCsFcrBaAHAAohEIGHLEWgBw
>> "%~1" echo ohEIGQMtB3KYWgBwKwVysFoAcACiEQgactRaAHCiEQgoFwAACm+RAAAKJhEFct11
>> "%~1" echo AHBvkQAACiYRBXIJdgBwb5EAAAomEQVypHcAcG+RAAAKJhEFcvB3AHBvkQAACiYR
>> "%~1" echo BR8LjRIAAAETCBEIFnKzeQBwohEIFwkofQAABqIRCBhyMXoAcKIRCBkGcv5HAHAo
>> "%~1" echo fAAABih9AAAGohEIGnKbegBwohEIGwgofQAABqIRCBxyKHsAcKIRCB0Gcu8TAHAo
>> "%~1" echo fAAABih9AAAGohEIHnKtewBwohEIHwkGcu8TAHAofAAABih/AAAGKH0AAAaiEQgf
>> "%~1" echo CnKzewBwohEIKBcAAApvkQAACiYRBR8RjRIAAAETCBEIFnLrewBwohEIFwZywxQA
>> "%~1" echo cCh8AAAGKH0AAAaiEQgYcqx8AHCiEQgZBnLBFQBwKHwAAAYofQAABqIRCBpyJyoA
>> "%~1" echo cKIRCBsGcg5IAHAofAAABih9AAAGohEIHHInKgBwohEIHQZymxQAcCh8AAAGKH0A
>> "%~1" echo AAaiEQgecuB8AHCiEQgfCREEKH0AAAaiEQgfCnJIfQBwohEIHwsGcvEUAHAofAAA
>> "%~1" echo Bih9AAAGohEIHwxyfn0AcKIRCB8NBnIzFQBwKHwAAAYofQAABqIRCB8Ockh9AHCi
>> "%~1" echo EQgfDwZy3xYAcCh8AAAGKH0AAAaiEQgfEHKOfQBwohEIKBcAAApvkQAACiYRBRuN
>> "%~1" echo EgAAARMIEQgWcsJ9AHCiEQgXAy0Hck9+AHArBXJbfgBwACh9AAAGohEIGHKsfABw
>> "%~1" echo ohEIGQMtB3JnfgBwKwVym34AcAAofQAABqIRCBpyKH8AcKIRCCgXAAAKb5EAAAom
>> "%~1" echo EQUfC40SAAABEwgRCBZyf4AAcKIRCBcGcq0aAHAofAAABih9AAAGohEIGHInKgBw
>> "%~1" echo ohEIGQZy1xoAcCh8AAAGKH0AAAaiEQgacg6BAHCiEQgbBnLYQwBwKHwAAAYofQAA
>> "%~1" echo BqIRCBxydIEAcKIRCB0GcqA+AHAofAAABih9AAAGohEIHnLagQBwohEIHwkGcr5I
>> "%~1" echo AHAofAAABih9AAAGohEIHwpyQIIAcKIRCCgXAAAKb5EAAAomEQVyaoIAcAYDHwqN
>> "%~1" echo EgAAARMIEQgWcnSCAHCiEQgXcraCAHCiEQgYcvqCAHCiEQgZckqDAHCiEQgacn6D
>> "%~1" echo AHCiEQgbcrKDAHCiEQgccuyDAHCiEQgdciiEAHCiEQgeclyEAHCiEQgfCXKGhABw
>> "%~1" echo ohEIKFQAAAYAEQVyvIQAcAYDHwmNEgAAARMIEQgWcsiEAHCiEQgXcviEAHCiEQgY
>> "%~1" echo chiFAHCiEQgZclKFAHCiEQgacpKFAHCiEQgbcsSFAHCiEQgccg6GAHCiEQgdckSG
>> "%~1" echo AHCiEQgecoSGAHCiEQgoVAAABgARBXKyhgBwBgMfEY0SAAABEwgRCBZy1IYAcKIR
>> "%~1" echo CBdyDocAcKIRCBhyRIcAcKIRCBlyhIcAcKIRCBpyxocAcKIRCBtyDIgAcKIRCBxy
>> "%~1" echo SogAcKIRCB1yiIgAcKIRCB5y0ogAcKIRCB8JchyJAHCiEQgfCnJiiQBwohEIHwty
>> "%~1" echo iokAcKIRCB8Mcs6JAHCiEQgfDXIcigBwohEIHw5ygooAcKIRCB8PcqSKAHCiEQgf
>> "%~1" echo EHLUigBwohEIKFQAAAYAEQVyAIsAcAYDHwqNEgAAARMIEQgWcjSLAHCiEQgXcpSL
>> "%~1" echo AHCiEQgYcvCLAHCiEQgZclqMAHCiEQgacsCMAHCiEQgbciKNAHCiEQgccpCNAHCi
>> "%~1" echo EQgdcu6NAHCiEQgeclSOAHCiEQgfCXLKjgBwohEIKFQAAAYAEQVyQo8AcG+RAAAK
>> "%~1" echo JhEFcsGQAHAGAxqNEgAAARMIEQgWcs+QAHCiEQgXcguRAHCiEQgYclWRAHCiEQgZ
>> "%~1" echo csmRAHCiEQgoVAAABgARBQIDKFUAAAYAEQUdjRIAAAETCBEIFnIHkgBwohEIFwZy
>> "%~1" echo PEUAcCh8AAAGKH0AAAaiEQgYcuiTAHCiEQgZBnJ8RQBwKHwAAAYofQAABqIRCBpy
>> "%~1" echo OJQAcKIRCBsDLQdyhJQAcCsFcpSUAHAAKH0AAAaiEQgccqqUAHCiEQgoFwAACm+R
>> "%~1" echo AAAKJhEFct6UAHBvkQAACiYRBW+SAAAKEwYrABEGKgATMAQACgEAAEMAABEAAnIW
>> "%~1" echo lQBwAyh9AAAGclKVAHAoMQAACm+RAAAKJgAOBBMGFhMHOMIAAAARBhEHmgoABheN
>> "%~1" echo KQAAARMIEQgWH3ydEQgZb58AAAoLBxaaDAeOaRcwAwgrAwcXmgANB45pGDAHcheW
>> "%~1" echo AHArAwcYmgATBAQIKHwAAAYTBQUW/gETCREJLQoRBRcofgAABhMFAh2NEgAAARMK
>> "%~1" echo EQoWch+WAHCiEQoXCSh9AAAGohEKGHIxlgBwohEKGREFKH0AAAaiEQoacjGWAHCi
>> "%~1" echo EQobEQQofQAABqIRChxyRZYAcKIRCigXAAAKb5EAAAomABEHF1gTBxEHEQaOaf4E
>> "%~1" echo EwkRCTot////AnJblgBwb5EAAAomKgAAGzAFAGUBAABEAAARAAJykZYAcG+RAAAK
>> "%~1" echo JgADex8AAARvpgAACgw4GQEAABICKKcAAAoKAAQsFgZ7FAAABHL1lgBwG286AAAK
>> "%~1" echo Fv4EKwEXAA0JLQU47AAAAAZvrQAABgsEFv4BDQktCAcDKIEAAAYLB28+AAAKIGDq
>> "%~1" echo AAD+Ahb+AQ0JLRcHFiBg6gAAb1QAAApyA5cAcCgJAAAKCwIfCo0SAAABEwQRBBZy
>> "%~1" echo NZcAcKIRBBcGexQAAAQofQAABqIRBBhyW5cAcKIRBBkGfBoAAAQocQAACihyAAAK
>> "%~1" echo KH0AAAaiEQQacmOXAHCiEQQbBnwYAAAEKHEAAAoodAAACih9AAAGohEEHAZ7GQAA
>> "%~1" echo BC0HcvUFAHArBXJ5lwBwAKIRBB1yj5cAcKIRBB4HKH0AAAaiEQQfCXKvlwBwohEE
>> "%~1" echo KBcAAApvkQAACiYAEgIoqAAACg0JOtn+///eDxIC/hYLAAAbbyUAAAoA3AACctGX
>> "%~1" echo AHBvkQAACiYqAAAAQRwAAAIAAAAaAAAALgEAAEgBAAAPAAAAAAAAABMwAwDbAAAA
>> "%~1" echo RQAAEQACIMQJAABy55cAcCg+AAAGCgZyxRgAcCguAAAKLBAGciGYAHAoLgAAChb+
>> "%~1" echo ASsBFwATBxEHLQgGEwY4mAAAAAACIMQJAAByMZgAcCg+AAAGKIQAAAYTCBYTCStk
>> "%~1" echo EQgRCZoLAAdvVQAACgwIcmeYAHBvqgAACg0JFv4EEwcRBy05AAgJG1hvVwAACm9V
>> "%~1" echo AAAKEwQRBB8vb1MAAAoTBREFFv4CFv4BEwcRBy0OEQQWEQVvVAAAChMG3h8AABEJ
>> "%~1" echo F1gTCREJEQiOaf4EEwcRBy2OcsUYAHATBisAABEGKgATMAMAGAAAADMAABEAAgME
>> "%~1" echo KFgAAAZvqwAABiiDAAAGCisABioeAiiUAAAKKh4CKJQAAAoqCzACACwAAAAAAAAA
>> "%~1" echo AAACe0gAAAR7RwAABAJ7SQAABG+rAAAKb6wAAAp9EAAABADeBSYAAN4AACoBEAAA
>> "%~1" echo AAABACQlAAUBAAABCzACACwAAAAAAAAAAAACe0gAAAR7RwAABAJ7SQAABG+tAAAK
>> "%~1" echo b6wAAAp9EQAABADeBSYAAN4AACoBEAAAAAABACQlAAUBAAABGzACADwBAABGAAAR
>> "%~1" echo c7oAAAYTBQARBXOsAAAGfUcAAARzuwAABg0JEQV9SAAABABzrgAACgoGAm+vAAAK
>> "%~1" echo AAYDKFoAAAZvsAAACgAGFm+xAAAKAAYXb7IAAAoABhdvswAACgAGF2+0AAAKAAkG
>> "%~1" echo KLUAAAp9SQAABAn+BrwAAAZztgAACnO3AAAKCwn+Br0AAAZztgAACnO3AAAKDAdv
>> "%~1" echo uAAACgAIb7gAAAoACXtJAAAEBG+5AAAKEwcRBy0vABEFe0cAAAQXfRMAAAQACXtJ
>> "%~1" echo AAAEb7oAAAoAAN4FJgAA3gAAEQV7RwAABBMG3lsRBXtHAAAECXtJAAAEb7sAAAp9
>> "%~1" echo EgAABAcg6AMAAG+8AAAKJggg6AMAAG+8AAAKJhEFe0cAAAQTBt4hEwQAEQV7RwAA
>> "%~1" echo BBEEbwgAAAp9EQAABBEFe0cAAAQTBt4AABEGKkE0AAAAAAAAvAAAABAAAADMAAAA
>> "%~1" echo BQAAAAEAAAEAAAAAFAAAAAMBAAAXAQAAIQAAABEAAAEeAiiUAAAKKh4CKJQAAAoq
>> "%~1" echo GzACAHwAAABHAAARAAArUgACe0wAAAR7SwAABBT+AQwILT4WCwJ7TAAABHtKAAAE
>> "%~1" echo JQ0SASiNAAAKAAACe0wAAAR7SwAABAZvvQAACgAA3hAHFv4BDAgtBwkojgAACgDc
>> "%~1" echo AAACe00AAARvqwAACm++AAAKJQoU/gEW/gEMCC2SAN4FJgAA3gAAKgEcAAACABkA
>> "%~1" echo K0QAEAAAAAAAAAEAdHUABQEAAAEbMAIAfAAAAEcAABEAACtSAAJ7TAAABHtLAAAE
>> "%~1" echo FP4BDAgtPhYLAntMAAAEe0oAAAQlDRIBKI0AAAoAAAJ7TAAABHtLAAAEBm+9AAAK
>> "%~1" echo AADeEAcW/gEMCC0HCSiOAAAKANwAAAJ7TQAABG+tAAAKb74AAAolChT+ARb+AQwI
>> "%~1" echo LZIA3gUmAADeAAAqARwAAAIAGQArRAAQAAAAAAAAAQB0dQAFAQAAARswAgCnAQAA
>> "%~1" echo SAAAEXO+AAAGEwcRBwV9SwAABABzrAAABgoRB3OUAAAKfUoAAARzvwAABhMEEQQR
>> "%~1" echo B31MAAAEAHOuAAAKCwcCb68AAAoABwMoWgAABm+wAAAKAAcWb7EAAAoABxdvsgAA
>> "%~1" echo CgAHF2+zAAAKAAcXb7QAAAoAEQQHKLUAAAp9TQAABBEE/gbAAAAGc7YAAApztwAA
>> "%~1" echo CgwRBP4GwQAABnO2AAAKc7cAAAoNCG+4AAAKAAlvuAAACgARBHtNAAAEBG+5AAAK
>> "%~1" echo EwkRCS0/AAYXfRMAAAQAEQR7TQAABG+6AAAKAADeBSYAAN4AAAgg9AEAAG+8AAAK
>> "%~1" echo Jgkg9AEAAG+8AAAKJgYTCN2iAAAABhEEe00AAARvuwAACn0SAAAECCDQBwAAb7wA
>> "%~1" echo AAomCSDQBwAAb7wAAAomBhMI3nMTBQAGEQVvCAAACn0RAAAEEQd7SwAABBT+ARMJ
>> "%~1" echo EQktTgAAFhMGEQd7SgAABCUTChIGKI0AAAoAABEHe0sAAAQRBW8IAAAKb70AAAoA
>> "%~1" echo AN4UEQYW/gETCREJLQgRCiiOAAAKANwAAN4FJgAA3gAAAAYTCN4AABEIKgBBZAAA
>> "%~1" echo AAAAAMoAAAARAAAA2wAAAAUAAAABAAABAgAAAFUBAAAqAAAAfwEAABQAAAAAAAAA
>> "%~1" echo AAAAAFEBAABGAAAAlwEAAAUAAAABAAABAAAAACIAAAAOAQAAMAEAAHMAAAARAAAB
>> "%~1" echo EzADAEkAAABJAAARAHOQAAAKChYLKykABxb+Ahb+AQ0JLQkGHyBvmAAACiYGAgea
>> "%~1" echo KFsAAAZvkwAACiYABxdYCwcCjmn+BA0JLc0Gb5IAAAoMKwAIKgAAACAACQAiACYA
>> "%~1" echo fAA8AD4AXgATMAQAXQAAAB0AABEAAhT+ARb+AQsHLQhyc5gAcAorRwIejSkAAAEl
>> "%~1" echo 0E4AAAQovwAACm/AAAAKFv4EFv4BCwctBAIKKyJyeZgAcAJyeZgAcHJ9mABwb6AA
>> "%~1" echo AApyeZgAcCgxAAAKCisABioAAAATMAMATgAAAB0AABEAAiiDAAAGEAADKIMAAAYQ
>> "%~1" echo AQJyxRgAcCgMAAAKFv4BCwctBAMKKyUDcsUYAHAoDAAAChb+AQsHLQQCCisPAnKz
>> "%~1" echo AQBwAygxAAAKCisABioAABMwAgBrAAAAHQAAEQACcoOYAHAoDAAAChb+AQsHLQhy
>> "%~1" echo h5gAcAorTgJyj5gAcCgMAAAKLRACcpOYAHAoDAAAChb+ASsBFgALBy0IcpeYAHAK
>> "%~1" echo KyMCcp+YAHAoDAAAChb+AQsHLQhyo5gAcAorCQIogwAABgorAAYqABMwAgCOAAAA
>> "%~1" echo HQAAEQACcoOYAHAoDAAAChb+AQsHLQhyq5gAcAorcQJyj5gAcCgMAAAKFv4BCwct
>> "%~1" echo CHKxmABwCitXAnKTmABwKAwAAAoW/gELBy0IcreYAHAKKz0Ccp+YAHAoDAAAChb+
>> "%~1" echo AQsHLQhyvZgAcAorIwJyw5gAcCgMAAAKFv4BCwctCHLHmABwCisJAiiDAAAGCisA
>> "%~1" echo BioAABMwAgB3AAAAHQAAEQACcs2YAHAoYgAABnJFFABwb8EAAAoW/gELBy0IcuWY
>> "%~1" echo AHAKK1ACcuuYAHAoYgAABnJFFABwb8EAAAoW/gELBy0IcgWZAHAKKywCcg2ZAHAo
>> "%~1" echo YgAABnJFFABwb8EAAAoW/gELBy0IcjGZAHAKKwhyN5kAcAorAAYqABMwAwBrAAAA
>> "%~1" echo SgAAEQAAAiiEAAAGDRYTBCtFCREEmgoABm9VAAAKCwcDcjo7AHAoCQAAChtvXAAA
>> "%~1" echo Chb+ARMFEQUtFgcDbz4AAAoXWG9XAAAKKIMAAAYM3hwAEQQXWBMEEQQJjmn+BBMF
>> "%~1" echo EQUtrnLFGABwDCsAAAgqABMwAwCTAAAASwAAEQAAAiiEAAAGEwYWEwcraREGEQea
>> "%~1" echo CgAGb1UAAAoLBwNyP5kAcCgJAAAKGm86AAAKDAgW/gQTCBEILTcABwgDbz4AAApY
>> "%~1" echo F1hvVwAACg0JHyxvUwAAChMEEQQWLwMJKwkJFhEEb1QAAAoAKIMAAAYTBd4eABEH
>> "%~1" echo F1gTBxEHEQaOaf4EEwgRCC2JcsUYAHATBSsAABEFKgATMAMAVAAAAEoAABEAAAIo
>> "%~1" echo hAAABg0WEwQrLgkRBJoKAAZvVQAACgsHAxtvOgAAChb+BBMFEQUtCQcogwAABgze
>> "%~1" echo HAARBBdYEwQRBAmOaf4EEwURBS3FcsUYAHAMKwAACCoTMAMAZQAAAEwAABEAA3I6
>> "%~1" echo OwBwKAkAAAoKAgYbbzoAAAoLBxb+BBb+ARMFEQUtCXLFGABwEwQrNgIHBm8+AAAK
>> "%~1" echo WG9XAAAKb1UAAAoMCB8sb1MAAAoNCRYvAwgrCAgWCW9UAAAKACiDAAAGEwQrABEE
>> "%~1" echo KgAAABMwAwBmAAAATQAAEQAAAiiEAAAGEwQWEwUrPhEEEQWaCgAGb1UAAAoLBwMb
>> "%~1" echo bzoAAAoMCBb+BBMGEQYtFgcIA28+AAAKWG9XAAAKKIMAAAYN3h0AEQUXWBMFEQUR
>> "%~1" echo BI5p/gQTBhEGLbRyxRgAcA0rAAAJKgAAEzAEAMYAAABOAAARAAACKIQAAAYTBRYT
>> "%~1" echo BjiWAAAAEQURBpoKAAZvVQAACgsHAxtvXAAAChMHEQctAityBxiNKQAAARMIEQgW
>> "%~1" echo HyCdEQgXHwmdEQgXb50AAAoMCI5pGDIZCBeaIP8BAAAocQAAChIDKKEAAAoW/gEr
>> "%~1" echo ARcAEwcRBy0sCSMAAAAAAAAwQVsTCRIJcrw7AHAocQAACiiZAAAKckI2AHAoCQAA
>> "%~1" echo ChME3iEAEQYXWBMGEQYRBY5p/gQTBxEHOln///9yxRgAcBMEKwAAEQQqAAATMAQA
>> "%~1" echo vwAAAE8AABEAAAIohAAABhMEFhMFOJEAAAARBBEFmgoABm9VAAAKC3JDmQBwA3JH
>> "%~1" echo mQBwKDEAAAoMBwgab1wAAAoW/gETBhEGLSkHCG8+AAAKb1cAAAoXjSkAAAETBxEH
>> "%~1" echo Fh9dnREHb8IAAAoogwAABg3eUQcDcj+ZAHAoCQAAChpvXAAAChb+ARMGEQYtFgcD
>> "%~1" echo bz4AAAoXWG9XAAAKKIMAAAYN3iAAEQUXWBMFEQURBI5p/gQTBhEGOl7///9yxRgA
>> "%~1" echo cA0rAAAJKgATMAIAUgAAAEoAABEAAAIohAAABg0WEwQrLAkRBJoKAAYogwAABgsH
>> "%~1" echo csUYAHAoLgAAChb+ARMFEQUtBAcM3hwAEQQXWBMEEQQJjmn+BBMFEQUtx3LFGABw
>> "%~1" echo DCsAAAgqAAATMAQAZwAAAB8AABEAAiUtBiZy9QUAcAMbbzoAAAoKBhb+BBb+AQ0J
>> "%~1" echo LQhyxRgAcAwrPwYDbz4AAApYCgIEBhtvwwAACgsHFv4EFv4BDQktDwIGb1cAAAoo
>> "%~1" echo gwAABgwrEgIGBwZZb1QAAAoogwAABgwrAAgqABMwAwBMAAAAUAAAEQACJS0GJnL1
>> "%~1" echo BQBwAxcoxAAACgoGb8UAAAosDgZvxgAACm/HAAAKFzAHcsUYAHArFgZvxgAAChdv
>> "%~1" echo yAAACm/JAAAKKIMAAAYACysAByoTMAIADQAAADMAABEAAgMoaQAABgorAAYqAAAA
>> "%~1" echo EzACAEUAAAApAAARAAIDKGwAAAYKBnLFGABwKC4AAAoW/gENCS0EBgwrJAIobQAA
>> "%~1" echo BgsHAijKAAAKDQktCgcDKGwAAAYMKwhyxRgAcAwrAAgqAAAAEzAEALAAAABRAAAR
>> "%~1" echo AAIlLQYmcvUFAHByfZgAcAMoywAACnJRmQBwKDEAAAoXKMQAAAoKBm/FAAAKFv4B
>> "%~1" echo DAgtGQZvxgAAChdvyAAACm/JAAAKKIMAAAYLK2ECJS0GJnL1BQBwcn2YAHADKMsA
>> "%~1" echo AApyfZkAcCgxAAAKFyjEAAAKCgZvxQAACi0HcsUYAHArKAZvxgAAChdvyAAACm/J
>> "%~1" echo AAAKF40pAAABDQkWHyKdCW+aAAAKKIMAAAYACysAByoTMAMASQAAAFIAABEAAiUt
>> "%~1" echo BiZy9QUAcAoWCysVBnJ9mABwcnmYAHBvoAAACgoHF1gLBxgvFAZyfZgAcBpvOgAA
>> "%~1" echo Chb+BBb+ASsBFgANCS3NBgwrAAgqAAAAEzAEAPwAAABTAAARAAACKIQAAAYTBBYT
>> "%~1" echo BTjOAAAAEQQRBZoKAAZvVQAACgsHbz4AAAosEQdy2j4AcBtvXAAAChb+ASsBFgAT
>> "%~1" echo BhEGLQU4lAAAAAcYjSkAAAETBxEHFh8gnREHFx8JnREHF2+dAAAKDAiOaRwyLggI
>> "%~1" echo jmkXWZpypZkAcCgMAAAKLRcICI5pF1macrGZAHAbbzoAAAoW/gQrARYAKwEXABMG
>> "%~1" echo EQYtORuNEgAAARMIEQgWCBiaohEIF3InKgBwohEIGAgXmqIRCBlyw5kAcKIRCBoI
>> "%~1" echo GpqiEQgoFwAACg3eIAARBRdYEwURBREEjmn+BBMGEQY6If///3LFGABwDSsAAAkq
>> "%~1" echo EzAEAFoAAAApAAARAAJyHj8AcChlAAAGCgJyMj8AcChlAAAGCwZyxRgAcCgMAAAK
>> "%~1" echo LBAHcsUYAHAoDAAAChb+ASsBFwANCS0IcsUYAHAMKxRyTj8AcAdyVj8AcAYoZgAA
>> "%~1" echo CgwrAAgqAAATMAMAVgAAAFQAABEAAnLRmQBwKHoAAAYKAnLlmQBwKGkAAAYLBi0Q
>> "%~1" echo B3LFGABwKAwAAAoW/gErARcADQktCHLFGABwDCsaEgAocQAACih0AAAKciWaAHAH
>> "%~1" echo KDEAAAoMKwAIKgAAEzAEAB8BAABVAAARAAJyJkAAcChiAAAGCgZySkAAcChpAAAG
>> "%~1" echo CwZyekAAcChpAAAGDAZyskAAcChpAAAGDQZyOZoAcCh7AAAGEwcSByhxAAAKKHQA
>> "%~1" echo AAoTBHMeAAAKEwUHcsUYAHAoLgAAChb+ARMIEQgtGBEFB3KzAQBwcvUFAHBvoAAA
>> "%~1" echo Cm8yAAAKAAhyxRgAcCguAAAKFv4BEwgRCC0TEQUIcghBAHAoCQAACm8yAAAKAAly
>> "%~1" echo xRgAcCguAAAKFv4BEwgRCC0TEQVyDkEAcAkoCQAACm8yAAAKABEEcluaAHAoLgAA
>> "%~1" echo Chb+ARMIEQgtFBEFEQRyX5oAcCgJAAAKbzIAAAoAEQVvHwAACiwTcicqAHARBW8v
>> "%~1" echo AAAKKDAAAAorBXLFGABwABMGKwARBioAEzAEAMkAAABWAAARAAJybEEAcChgAAAG
>> "%~1" echo CgJybZoAcChgAAAGCwJyikEAcChqAAAGDHMeAAAKDQZyxRgAcCguAAAKFv4BEwUR
>> "%~1" echo BS0SCXIMQgBwBigJAAAKbzIAAAoAB3LFGABwKC4AAAoW/gETBREFLRIJcoGaAHAH
>> "%~1" echo KAkAAApvMgAACgAIcsUYAHAoLgAAChb+ARMFEQUtFwlyi5oAcAhyNEIAcCgxAAAK
>> "%~1" echo bzIAAAoACW8fAAAKLBJyJyoAcAlvLwAACigwAAAKKwVyxRgAcAATBCsAEQQqAAAA
>> "%~1" echo EzADALoAAABWAAARAAJynZoAcChpAAAGCgJyw5oAcChpAAAGCwJy65oAcChpAAAG
>> "%~1" echo DHMeAAAKDQZyxRgAcCguAAAKFv4BEwURBS0SCXIlmwBwBigJAAAKbzIAAAoAB3LF
>> "%~1" echo GABwKC4AAAoW/gETBREFLRIJcjubAHAHKAkAAApvMgAACgAIcsUYAHAoLgAAChb+
>> "%~1" echo ARMFEQUtCAkIbzIAAAoACW8fAAAKLBJyJyoAcAlvLwAACigwAAAKKwVyxRgAcAAT
>> "%~1" echo BCsAEQQqAAATMAMAMwEAAFcAABEAAnJTmwBwKGkAAAYKAnKRmwBwKGkAAAYLAnK9
>> "%~1" echo mwBwKGkAAAYMAnLrmwBwKGkAAAYNA3IRnABwKGkAAAYTBHMeAAAKEwURBHLFGABw
>> "%~1" echo KC4AAAoW/gETBxEHLRQRBXJhnABwEQQoCQAACm8yAAAKAAZyxRgAcCguAAAKFv4B
>> "%~1" echo EwcRBy0TEQVyaZwAcAYoCQAACm8yAAAKAAdyxRgAcCguAAAKFv4BEwcRBy0TEQUH
>> "%~1" echo cn2cAHAoCQAACm8yAAAKAAhyxRgAcCguAAAKFv4BEwcRBy0TEQUIcoWcAHAoCQAA
>> "%~1" echo Cm8yAAAKAAlyxRgAcCguAAAKFv4BEwcRBy0TEQVyj5wAcAkoCQAACm8yAAAKABEF
>> "%~1" echo bx8AAAosE3InKgBwEQVvLwAACigwAAAKKwVyxRgAcAATBisAEQYqABMwBABgAAAA
>> "%~1" echo KQAAEQACcpucAHAoaQAABgoCcsOcAHAoaQAABgsGcsUYAHAoDAAACiwQB3LFGABw
>> "%~1" echo KAwAAAoW/gErARcADQktDgJy6ZwAcChiAAAGDCsUcgudAHAGcicqAHAHKGYAAAoM
>> "%~1" echo KwAIKhMwBADxAAAAWAAAEQACch2dAHAoewAABgoDKG0AAAYLB3J9nQBwKHsAAAYM
>> "%~1" echo B3KznQBwKHsAAAYNB3LrnQBwKHsAAAYTBHMeAAAKEwUGFv4CFv4BEwcRBy0YEQUG
>> "%~1" echo jBkAAAFyI54AcChjAAAKbzIAAAoACAlYEQRYFv4CFv4BEwcRBy1REQUcjQEAAAET
>> "%~1" echo CBEIFnJDngBwohEIFwiMGQAAAaIRCBhyaZ4AcKIRCBkJjBkAAAGiEQgacn+eAHCi
>> "%~1" echo EQgbEQSMGQAAAaIRCCgVAAAKbzIAAAoAEQVvHwAACiwTcicqAHARBW8vAAAKKDAA
>> "%~1" echo AAorBXLFGABwABMGKwARBioAAAATMAMAHwEAAFcAABEAAnLsAwBwKGsAAAYKAnIQ
>> "%~1" echo BABwKGsAAAYLAnIyBABwKGsAAAYMAnJuBABwKGsAAAYNAnKOBABwKGsAAAYTBHMe
>> "%~1" echo AAAKEwUGcsUYAHAoLgAAChb+ARMHEQctCREFBm8yAAAKAAdyxRgAcCguAAAKFv4B
>> "%~1" echo EwcRBy0JEQUHbzIAAAoACHLFGABwKC4AAAoW/gETBxEHLRMRBXKCQgBwCCgJAAAK
>> "%~1" echo bzIAAAoACXLFGABwKC4AAAoW/gETBxEHLRMRBXKUQgBwCSgJAAAKbzIAAAoAEQRy
>> "%~1" echo xRgAcCguAAAKFv4BEwcRBy0UEQVynkIAcBEEKAkAAApvMgAACgARBW8fAAAKLBNy
>> "%~1" echo JyoAcBEFby8AAAooMAAACisFcsUYAHAAEwYrABEGKgATMAMAWgAAAFkAABEAAnKV
>> "%~1" echo ngBwG286AAAKFv4EFv4BDAgtCHLFGABwCys5AnLOPwBwKGQAAAYKcow/AHAGcsUY
>> "%~1" echo AHAoDAAACi0NcicqAHAGKAkAAAorBXL1BQBwACgJAAAKCysAByoAABMwAwBMAAAA
>> "%~1" echo WgAAEQAWCgACKIQAAAYNFhMEKykJEQSaCwdvVQAACnLXngBwG29cAAAKFv4BEwUR
>> "%~1" echo BS0EBhdYChEEF1gTBBEECY5p/gQTBREFLcoGDCsACCoTMAMASAAAAFoAABEAFgoA
>> "%~1" echo AiiEAAAGDRYTBCslCREEmgsHb1UAAAoDG29cAAAKFv4BEwURBS0EBhdYChEEF1gT
>> "%~1" echo BBEECY5p/gQTBREFLc4GDCsACCoTMAMAHAAAAAoAABEAAiUtBiZy9QUAcAMXKMwA
>> "%~1" echo AApvzQAACgorAAYqEzACACMAAAAzAAARAAIDb2kAAAotB3LFGABwKwwCA29lAAAK
>> "%~1" echo KIMAAAYACisABioAEzABABEAAAAzAAARAAIogwAABijOAAAKCisABioAAAATMAEA
>> "%~1" echo GAAAADMAABEAAy0IAiiDAAAGKwYCKIAAAAYACisABioTMAMArwAAAFkAABEAAiiD
>> "%~1" echo AAAGCgZyxRgAcCgMAAAKFv4BDAgtBwYLOIwAAAAGcumeAHAbbzoAAAoW/gQMCC0I
>> "%~1" echo chmfAHALK3EGclGfAHAbbzoAAAoWMhEGcmGfAHAbbzoAAAoW/gQrARcADAgtCHJ/
>> "%~1" echo nwBwCytDBnK1nwBwG295AAAKLREGcsWfAHAbb3kAAAoW/gErARYADAgtCHLNnwBw
>> "%~1" echo CysWBm8+AAAKHzT+AgwILQQGCysEBgsrAAcqABMwAgA6AAAAWQAAEQACb8kAAAoK
>> "%~1" echo BnLrnwBwKM8AAAosEAZy958AcCjPAAAKFv4BKwEXAAwILQkGKIIAAAYLKwQGCysA
>> "%~1" echo ByoAABMwBAA6AAAANAAAEQACFCiBAAAGCgZyA6AAcH4PAAAELRMU/gapAAAGc9AA
>> "%~1" echo AAqADwAABCsAfg8AAAQo0QAACgoGCysAByoAABMwBABOAQAAWQAAEQACJS0GJnL1
>> "%~1" echo BQBwCgMsIgN7HAAABChQAAAKLRUDexwAAARyxRgAcCguAAAKFv4BKwEXAAwILRgG
>> "%~1" echo A3scAAAEA3scAAAEKIIAAAZvoAAACgoGcimgAHByd6AAcCjSAAAKCgZym6AAcHLx
>> "%~1" echo oABwKNIAAAoKBnIRoQBwcvGgAHAo0gAACgoGcl+hAHBy8aAAcCjSAAAKCgZyt6EA
>> "%~1" echo cHIFogBwKNIAAAoKBnIVogBwchajAHAZKNMAAAoKBnI8owBwco6jAHAXKNMAAAoK
>> "%~1" echo BnKqowBwcvijAHAXKNMAAAoKBnI+pABwcmqkAHAXKNMAAAoKBnKYpABwcs6kAHAX
>> "%~1" echo KNMAAAoKBnICpQBwcjClAHAXKNMAAAoKBnJcpQBwcvUFAHBvoAAACm9VAAAKbz4A
>> "%~1" echo AAosFwZyXKUAcHL1BQBwb6AAAApvVQAACisFcsUYAHAACysAByoAABMwBQBKAAAA
>> "%~1" echo HQAAEQACKFAAAAotDgJvPgAAChz+BBb+ASsBFgALBy0IcmClAHAKKyMCFhlvVAAA
>> "%~1" echo CnJypQBwAgJvPgAAChlZb1cAAAooMQAACgorAAYqAAATMAMAQQAAAB0AABEAAhT+
>> "%~1" echo ARb+AQsHLQhyxRgAcAorKwJyXKUAcHL1BQBwb6AAAApvVQAAChAAAm8+AAAKLAMC
>> "%~1" echo KwVyxRgAcAAKKwAGKgAAABMwBAAxAAAAWwAAEQACJS0GJnL1BQBwclylAHBy9QUA
>> "%~1" echo cG+gAAAKF40pAAABCwcWHwqdB29RAAAKCisABioAAAATMAIALwAAACYAABEAAnIL
>> "%~1" echo GQBwKAwAAAotGgJyyRgAcCgMAAAKLQ0Cci8aAHAoDAAACisBFwAKKwAGKgATMAIA
>> "%~1" echo ZgAAACoAABEAAihQAAAKFv4BDAgtBBYLK1EAAg0WEwQrNwkRBG+WAAAKCgYolwAA
>> "%~1" echo Ci0WBh9fLhEGHy4uDAYfLS4HBh86/gErARcADAgtBBYL3hgRBBdYEwQRBAlvPgAA
>> "%~1" echo Cv4EDAgtuxcLKwAAByoAABMwAgCaAAAAJgAAEQACcrUcAHAoDAAACjqCAAAAAnKN
>> "%~1" echo HABwKAwAAAotdQJyQx8AcCgMAAAKLWgCcpUfAHAoDAAACi1bAnKjHgBwKAwAAAot
>> "%~1" echo TgJy3SEAcCgMAAAKLUECcj0jAHAoDAAACi00AnK7HQBwKAwAAAotJwJyIyYAcCgM
>> "%~1" echo AAAKLRoCcsMnAHAoDAAACi0NAnIPJgBwKAwAAAorARcACisABioAABMwAgCqAAAA
>> "%~1" echo HQAAEQACJS0GJnL1BQBwb1YAAAoKBnIZGQBwKAwAAAo6ggAAAAZyQRkAcCgMAAAK
>> "%~1" echo LXUGcnqlAHAoDAAACi1oBnK0pQBwKAwAAAotWwZy2qUAcCgMAAAKLU4GcgKmAHAo
>> "%~1" echo DAAACi1BBnISpgBwKAwAAAotNAZyNKYAcCgMAAAKLScGckqmAHAoDAAACi0aBnJu
>> "%~1" echo pgBwKAwAAAotDQZynqYAcCgMAAAKKwEXAAsrAAcqAAATMAQALgAAADMAABEActim
>> "%~1" echo AHACJS0GJnL1BQBwctimAHBy3KYAcG+gAAAKctimAHAoMQAACgorAAYqAAATMAMA
>> "%~1" echo HgAAABIAABEAcyYAAAoKBnJRKABwckUUAHBvJwAACgAGCysAByoAABMwAwArAAAA
>> "%~1" echo EgAAEQAoigAABgoGclEoAHByORQAcG8nAAAKAAZyVygAcAJvJwAACgAGCysAByoA
>> "%~1" echo EzACABsAAAAmAAARAAJyLg0AcCiNAAAGfgMAAAQoDAAACgorAAYqABMwBAC0AAAA
>> "%~1" echo XAAAEQACcuamAHBv1AAAChb+ARMFEQUtCQIXb1cAAAoQAAACF40pAAABEwYRBhYf
>> "%~1" echo Jp0RBm9RAAAKEwcWEwgrXREHEQiaCgAGHz1vUwAACgsHFi8DBisIBhYHb1QAAAoA
>> "%~1" echo DAcWLwdy9QUAcCsJBgcXWG9XAAAKAA0IKI4AAAYDKAwAAAoW/gETBREFLQoJKI4A
>> "%~1" echo AAYTBN4eABEIF1gTCBEIEQeOaf4EEwURBS2VcvUFAHATBCsAABEEKhMwAwAkAAAA
>> "%~1" echo MwAAEQACJS0GJnL1BQBwcuqmAHByswEAcG+gAAAKKHYAAAoKKwAGKnoAAnLupgBw
>> "%~1" echo KAoAAAoDKJEAAAZvPAAACiiQAAAGACoAEzAEAFsAAABdAAARABuNAQAAAQwIFnIu
>> "%~1" echo pwBwoggXA6IIGHJupwBwoggZBI5pjBkAAAGiCBpylKcAcKIIKBUAAAoKKE0AAAoG
>> "%~1" echo bzwAAAoLAgcWB45pb2IAAAoAAgQWBI5pb2IAAAoAKgAbMAIArgAAAF4AABEAcvan
>> "%~1" echo AHBz1QAACgoXCwACbygAAAoTBCthEgQoKQAACgwABxMFEQUtDAZyzAoAcG+TAAAK
>> "%~1" echo JhYLBnJ5mABwb5MAAAoSAigqAAAKKJIAAAZvkwAACnL6pwBwb5MAAAoSAigrAAAK
>> "%~1" echo KJIAAAZvkwAACnJ5mABwb5MAAAomABIEKCwAAAoTBREFLZLeDxIE/hYEAAAbbyUA
>> "%~1" echo AAoA3AAGcgKoAHBvkwAACm+SAAAKDSsACSoAAAEQAAACABcAcokADwAAAAATMAMA
>> "%~1" echo FAEAAF8AABEAc5AAAAoKAAIlLQYmcvUFAHANFhMEONsAAAAJEQRvlgAACgsABx9c
>> "%~1" echo /gEW/gETBREFLREGcgaoAHBvkwAACiY4qwAAAAcfIv4BFv4BEwURBS0RBnJ9mABw
>> "%~1" echo b5MAAAomOIwAAAAHHwr+ARb+ARMFEQUtDgZyDKgAcG+TAAAKJitwBx8N/gEW/gET
>> "%~1" echo BREFLQ4GchKoAHBvkwAACiYrVAcfCf4BFv4BEwURBS0OBnIYqABwb5MAAAomKzgH
>> "%~1" echo HyD+BBb+ARMFEQUtIgZyHqgAcG+TAAAKBxMGEgZyJKgAcCjWAAAKb5MAAAomKwgG
>> "%~1" echo B2+YAAAKJgARBBdYEwQRBAlvPgAACv4EEwURBToS////Bm+SAAAKDCsACCoTMAMA
>> "%~1" echo OgAAADQAABEAciqoAHAKKAoAAAoGKNcAAApvTgAACnJPrwNwfgMAAARvoAAACnJj
>> "%~1" echo rwNwKJQAAAZvoAAACgsrAAcqAAAbMAMAXgAAAB0AABEAACjYAAAKb9kAAApyda8D
>> "%~1" echo cBtvGQAAChb+AQsHLQhyda8DcAreNSjaAAAKb9kAAApyda8DcBtvGQAAChb+AQsH
>> "%~1" echo LQhyda8DcAreEQDeBSYAAN4AAHJ7rwNwCisAAAYqAAABEAAAAAABAExNAAUBAAAB
>> "%~1" echo EzACAFQAAABZAAARAAIlLQYmcvUFAHBvVQAACm9WAAAKCgZyda8DcG/UAAAKFv4B
>> "%~1" echo DAgtCHJ1rwNwCysiBnJ7rwNwb9QAAAoW/gEMCC0IcnuvA3ALKwgolAAABgsrAAcq
>> "%~1" echo EzACACUAAAAzAAARAH4KAAAEJS0GJiiUAAAGcnWvA3AoDAAACi0DAysBAgAKKwAG
>> "%~1" echo KgAAABMwBgDGAQAAYAAAEQByga8DcAoGFyiZAAAGCwJysrADcHKDmABwB2/bAAAK
>> "%~1" echo EwQSBCjcAAAKKAUAAAYAAnLMsANwcow/AHAHFm/dAAAKeycAAAQoBQAABgACct6w
>> "%~1" echo A3ByBLEDcAcWb90AAAp7KQAABCgFAAAGAAJyJLEDcHI2sQNwBxdv3QAACnsnAAAE
>> "%~1" echo KAUAAAYAAnJssQNwcn6xA3ByjD8AcCiYAAAGKAUAAAYAcpyxA3AMCHKMPwBwKJoA
>> "%~1" echo AAYNAnKDtwNwcpW3A3AJey0AAAQoBQAABgACcqm3A3ByvbcDcAl7LgAABCgFAAAG
>> "%~1" echo AAJyybcDcHLbtwNwCXsvAAAEKAUAAAYAAnLhtwNwcvm3A3AJezAAAAQoBQAABgAC
>> "%~1" echo cv+3A3ByBLEDcAl7MQAABCgFAAAGAAJyHbgDcHIvuANwCXszAAAEKAUAAAYAAnJD
>> "%~1" echo uANwcswKAHAJez0AAARvLwAACigwAAAKF40SAAABEwURBRZyqwkAcKIRBSgGAAAG
>> "%~1" echo AAJyVbgDcHLMCgBwCXs+AAAEby8AAAooMAAAChiNEgAAARMFEQUWcmW4A3CiEQUX
>> "%~1" echo com4A3CiEQUoBgAABgACcru4A3By0bgDcAl7NwAABCgFAAAGACoAABMwBADBAAAA
>> "%~1" echo YQAAEQACKFAAAAoW/gETBREFLQxyxRgAcBMEOKIAAAACF40pAAABEwYRBhYfLp0R
>> "%~1" echo Bm9RAAAKCgaOaRdZCys9AAYHmgwIcvEUAHAbbxkAAAotGQhy+bgDcBtvGQAACi0L
>> "%~1" echo CG8+AAAKGP4CKwEWABMFEQUtBwAHF1kLKwIrCgcW/gITBREFLbkGB5oNCW8+AAAK
>> "%~1" echo Fv4BFv4BEwURBS0FAhMEKyEJFm+WAAAKKN4AAAqMKQAAAQkXb1cAAAooYwAAChME
>> "%~1" echo KwARBCoAAAATMAQAgAEAAGIAABEAc98AAAoKAAIohAAABhMKFhMLOE8BAAARChEL
>> "%~1" echo mgsAB29VAAAKDAhy154AcBtvXAAAChMMEQwtBTgkAQAACB5vVwAACg1y9QUAcBME
>> "%~1" echo CXIHuQNwG286AAAKEwURBRb+BBb+ARMMEQwtDglyIbkDcBtvOgAAChMFEQUW/gQT
>> "%~1" echo DBEMLTsACR89EQVv4AAAChMGEQYWLwdy9QUAcCsPCREGF1hvVwAACm9VAAAKABME
>> "%~1" echo CRYRBW9UAAAKb1UAAAoNAAkfPW/hAAAKEwcRBxb+AhMMEQwtBTiLAAAAc7EAAAYT
>> "%~1" echo CBEICRYRB29UAAAKb1UAAAp9KAAABBEICREHF1hvVwAACm9VAAAKfScAAAQRCBEE
>> "%~1" echo chA6AHAoDAAACi0EEQQrBXL1BQBwAH0pAAAEEQgRCHsnAAAEKJgAAAZ9KgAABBEI
>> "%~1" echo A30rAAAEEQh7JwAABCgxAAAGFv4BEwwRDC0JBhEIb+IAAAoAABELF1gTCxELEQqO
>> "%~1" echo af4EEwwRDDqg/v//BhMJKwARCSoTMAQAqwMAAGMAABEAc7IAAAYKBgN9LAAABHK6
>> "%~1" echo PwBwA3LQCgBwKDEAAAoLAiUtBiZy9QUAcAcbbzoAAAoMCBYvDAIlLQYmcvUFAHAr
>> "%~1" echo BwIIb1cAAAoADQYJcjm5A3AoagAABn0tAAAEBglyY7kDcChqAAAGfS4AAAQGCXKH
>> "%~1" echo uQNwKGoAAAZ9LwAABAYJcqG5A3AoagAABn0wAAAEBglywbkDcChqAAAGfTEAAAQG
>> "%~1" echo ezEAAARyEDoAcCgMAAAKFv4BEw4RDi0LBnL1BQBwfTEAAAQGCXL9uQNwKGoAAAZ9
>> "%~1" echo MgAABAYJchW6A3AoagAABn0zAAAEBglyQ7oDcChqAAAGfTQAAAQGCXJnugNwKGoA
>> "%~1" echo AAZ9NgAABAYJcom6A3AoagAABn04AAAEBgly9boDcChqAAAGfTcAAAQGCXJluwNw
>> "%~1" echo KGoAAAZ9OwAABAlyi7sDcChqAAAGEwQGEQRyW5oAcCgMAAAKLRURBHLFGABwKAwA
>> "%~1" echo AAotB3I5FABwKwVyRRQAcAB9OQAABAYJcqe7A3AbbzoAAAoWLwdyORQAcCsFckUU
>> "%~1" echo AHAAfToAAAQWEwUWEwYACSiEAAAGEw8WExA44wEAABEPERCaEwcAEQdvVQAAChMI
>> "%~1" echo EQhywbsDcBtvXAAAChb+ARMOEQ4tDAAXEwUWEwY4qgEAABEIcu+7A3Abb1wAAAot
>> "%~1" echo IREIchm8A3Abb1wAAAotEhEIckW8A3Aab1wAAAoW/gErARYAEw4RDi0YABEIckW8
>> "%~1" echo A3Aab1wAAAoTDhEOLQMWEwUAEQhyUbwDcBtvXAAAChb+ARMOEQ4tDAAXEwYWEwU4
>> "%~1" echo OAEAABEIcnu8A3Abb1wAAAotEhEIco28A3Abb1wAAAoW/gErARYAEw4RDi0IABYT
>> "%~1" echo BRYTBgARBSwhEQhym7wDcBtvOgAAChYyEREIHzpvUwAAChb+BBb+ASsBFwATDhEO
>> "%~1" echo LSMABns9AAAEEQhvhAAAChMOEQ4tDgZ7PQAABBEIbzIAAAoAABEGLCIRCHKbvANw
>> "%~1" echo G286AAAKFjISEQhys7wDcBtvOgAAChb+BCsBFwATDhEOOoUAAAAAEQgTCREIHzpv
>> "%~1" echo UwAAChMKEQoW/gIW/gETDhEOLRERCBYRCm9UAAAKb1UAAAoTCREIcsW8A3AbbzoA
>> "%~1" echo AAoW/gQW/gETCxEJcjo7AHARCy0HcjkUAHArBXJFFABwACgxAAAKEwwGez4AAAQR
>> "%~1" echo DG+EAAAKEw4RDi0OBns+AAAEEQxvMgAACgAAABEQF1gTEBEQEQ+Oaf4EEw4RDjoM
>> "%~1" echo /v//BhMNKwARDSoAEzACAGMAAAAmAAARAAJy/S0AcCgMAAAKLU4Cct+8A3AoDAAA
>> "%~1" echo Ci1BAnLrvANwKAwAAAotNAJy+7wDcCgMAAAKLScCcgm9A3AoDAAACi0aAnJZLQBw
>> "%~1" echo KAwAAAotDQJyH70DcCgMAAAKKwEXAAorAAYqABswBABYAwAAZAAAEQAoigAABgoo
>> "%~1" echo NwAABgsHcsUYAHAoDAAAChb+ARMOEQ4tG3LRGwBwci29A3AolgAABiiLAAAGEw04
>> "%~1" echo GQMAAAIlLQYmcmW9A3BvVgAACgwIcmW9A3AoLgAACiwdCHLJGABwKC4AAAosEAhy
>> "%~1" echo b70DcCguAAAKFv4BKwEXABMOEQ4tBnJlvQNwDAhyyRgAcCgMAAAKLRwIcm+9A3Ao
>> "%~1" echo DAAACi0Hcne9A3ArBXJORQBwACsFcqu9A3AADQcg4C4AAAkoPgAABhMECHLJGABw
>> "%~1" echo KC4AAAoTBREECHJlvQNwKAwAAAotDQhyb70DcCgMAAAKKwEXACiZAAAGEwYIcskY
>> "%~1" echo AHAoDAAAChb+ARMOEQ4tPAARBm/jAAAKEw8rERIPKOQAAAoTBxEHFn0rAAAEEg8o
>> "%~1" echo 5QAAChMOEQ4t4t4PEg/+Fg0AABtvJQAACgDcAAhyb70DcCgMAAAKFv4BEw4RDjqz
>> "%~1" echo AAAAAAcgQB8AAHLfvQNwKD4AAAYXKJkAAAYTCCjmAAAKc+cAAAoTCQARCG/jAAAK
>> "%~1" echo Ew8rGRIPKOQAAAoTChEJEQp7JwAABBdv6AAACgASDyjlAAAKEw4RDi3a3g8SD/4W
>> "%~1" echo DQAAG28lAAAKANwAABEGb+MAAAoTDyseEg8o5AAAChMHEQcRCREHeycAAARv6QAA
>> "%~1" echo Cn0rAAAEEg8o5QAAChMOEQ4t1d4PEg/+Fg0AABtvJQAACgDcAAByQ5kAcHPVAAAK
>> "%~1" echo EwsWEww4zAAAAAARBhEMb90AAAoTBxEMFv4CFv4BEw4RDi0NEQtyzAoAcG+TAAAK
>> "%~1" echo JhELcge+A3BvkwAAChEHeycAAAQokgAABm+TAAAKciG+A3BvkwAAChEHeyoAAAQo
>> "%~1" echo kgAABm+TAAAKcjm+A3BvkwAAChEHeygAAAQokgAABm+TAAAKck++A3BvkwAAChEH
>> "%~1" echo eykAAAQokgAABm+TAAAKcm++A3BvkwAAChEHeysAAAQtB3I5FABwKwVyRRQAcABv
>> "%~1" echo kwAACnKFvgNwb5MAAAomABEMF1gTDBEMEQZv2wAACv4EEw4RDjog////EQty0AoA
>> "%~1" echo cG+TAAAKJgZyeg8AcAhvJwAACgAGcou+A3ARBm/bAAAKExASEChxAAAKKHQAAApv
>> "%~1" echo JwAACgAGcpe+A3ARC2+SAAAKbycAAAoABhMNKwARDSoBKAAAAgASASI0AQ8AAAAA
>> "%~1" echo AgCKASq0AQ8AAAAAAgDOAS/9AQ8AAAAAEzAEAF8EAABlAAARACiKAAAGCgIoMQAA
>> "%~1" echo BhMSERItG3KpvgNwcre+A3AolgAABiiLAAAGExE4LgQAACg3AAAGCwdyxRgAcCgM
>> "%~1" echo AAAKFv4BExIREi0bctEbAHByLb0DcCiWAAAGKIsAAAYTETj5AwAAByAQJwAAcr4y
>> "%~1" echo AHACKAkAAAooPgAABgwIAiiaAAAGDQcgoA8AAHLjvgNwAigJAAAKKD4AAAYTBAAR
>> "%~1" echo BCiEAAAGExMWExQrRBETERSaEwUAEQVvVQAAChMGEQZy154AcBtvXAAAChb+ARMS
>> "%~1" echo ERItFgAJEQYeb1cAAApvVQAACn01AAAEKxUAERQXWBMUERQRE45p/gQTEhESLa4J
>> "%~1" echo ezUAAARvPgAAChb+Ahb+ARMSERI6ygAAAAAgiBMAAByNEgAAARMVERUWclUfAHCi
>> "%~1" echo ERUXB6IRFRhyGjoAcKIRFRly9b4DcKIRFRpyADgAcKIRFRsJezUAAASiERUoPwAA
>> "%~1" echo BhMHEQclLQYmcvUFAHBy+74DcCjqAAAKEwgRCG/FAAAKExIREi0XEQclLQYmcvUF
>> "%~1" echo AHByHb8DcCjqAAAKEwgRCG/FAAAKLCYRCG/GAAAKF2/IAAAKb8kAAAoSCShYAAAK
>> "%~1" echo LAsRCRZq/gIW/gErARcAExIREi0NCREJKDMAAAZ9PAAABAAHAiifAAAGEwoGcmAM
>> "%~1" echo AHAJeywAAARvJwAACgAGckO/A3AJeywAAAQomAAABm8nAAAKAAZycAwAcAl7LQAA
>> "%~1" echo BG8nAAAKAAZyiAwAcAl7LgAABG8nAAAKAAZyT78DcAl7LwAABG8nAAAKAAZyXb8D
>> "%~1" echo cAl7MAAABG8nAAAKAAZycb8DcAl7MQAABG8nAAAKAAZyhb8DcAl7MgAABG8nAAAK
>> "%~1" echo AAZySxgAcAl7MwAABG8nAAAKAAZyjb8DcAl7NAAABG8nAAAKAAZyn78DcAl7NQAA
>> "%~1" echo BG8nAAAKAAZyr78DcAl7NgAABG8nAAAKAAZyv78DcAl7NwAABG8nAAAKAAZy2b8D
>> "%~1" echo cAl7OAAABG8nAAAKAAZy778DcAl7OQAABG8nAAAKAAZy/78DcAl7OgAABG8nAAAK
>> "%~1" echo AAZyD8ADcAl7OwAABG8nAAAKAAZyCywAcAl7PAAABG8nAAAKAAZyZb0DcBEKLQdy
>> "%~1" echo ORQAcCsFckUUAHAAbycAAAoABnIbwANwCXs9AAAEKJ4AAAZvJwAACgByQ5kAcHPV
>> "%~1" echo AAAKEwsWEww4pgAAAAAJez4AAAQRDG8tAAAKEw0RDR86b+EAAAoTDhEOFjAEEQ0r
>> "%~1" echo ChENFhEOb1QAAAoAEw8RDhYwB3I5FABwKwsRDREOF1hvVwAACgATEBEMFv4CFv4B
>> "%~1" echo ExIREi0NEQtyzAoAcG+TAAAKJhELcjfAA3BvkwAAChEPKJIAAAZvkwAACnJLwANw
>> "%~1" echo b5MAAAoRECiSAAAGb5MAAApyhb4DcG+TAAAKJgARDBdYEwwRDAl7PgAABG8fAAAK
>> "%~1" echo /gQTEhESOkL///8RC3LQCgBwb5MAAAomBnJnwANwEQtvkgAACm8nAAAKAAYTESsA
>> "%~1" echo EREqABMwAwB2AAAASQAAEQByQ5kAcHPVAAAKChYLK0QABxb+Ahb+AQ0JLQwGcswK
>> "%~1" echo AHBvkwAACiYGcnmYAHBvkwAACgIHby0AAAookgAABm+TAAAKcnmYAHBvkwAACiYA
>> "%~1" echo BxdYCwcCbx8AAAr+BA0JLa8GctAKAHBvkwAACm+SAAAKDCsACCoAABMwAwBkAAAA
>> "%~1" echo ZgAAEQACIEAfAABy370DcCg+AAAGCgAGKIQAAAYNFhMEKzEJEQSaCwAHb1UAAApy
>> "%~1" echo 154AcAMoCQAAChtvGQAAChb+ARMFEQUtBBcM3hgAEQQXWBMEEQQJjmn+BBMFEQUt
>> "%~1" echo whYMKwAACCobMAQAnwUAAGcAABEAAnIIEABwKI0AAAYKAnJgDABwKI0AAAYLBygx
>> "%~1" echo AAAGEwkRCS0bcqm+A3Byt74DcCiWAAAGKIsAAAYTCDhbBQAAKDcAAAYMCHLFGABw
>> "%~1" echo KAwAAAoW/gETCREJLRty0RsAcHItvQNwKJYAAAYoiwAABhMIOCYFAAAIByifAAAG
>> "%~1" echo DQAGcn/AA3AoDAAAChb+ARMJEQk6hAAAAAAgQB8AAB8JjRIAAAETChEKFnJVHwBw
>> "%~1" echo ohEKFwiiEQoYcho6AHCiEQoZco3AA3CiEQoacpvAA3CiEQobB6IRChxyocADcKIR
>> "%~1" echo Ch1yp8ADcKIRCh5ytwEAcKIRCihBAAAGEwRy6cADcHL3wANwKJYAAAYHKAkAAAoR
>> "%~1" echo BCihAAAGEwjdggQAAAZyCb0DcCgMAAAKFv4BEwkRCS1qACCIEwAAHI0SAAABEwoR
>> "%~1" echo ChZyVR8AcKIRChcIohEKGHIaOgBwohEKGXIdwQNwohEKGnIJvQNwohEKGweiEQoo
>> "%~1" echo QQAABiZyI8EDcHIxwQNwKJYAAAYHKAkAAApy9QUAcCihAAAGEwjdBAQAAAZyT8ED
>> "%~1" echo cCgMAAAKFv4BEwkRCS0PAAgHKKIAAAYTCN3hAwAABnL9LQBwKAwAAAoW/gETCREJ
>> "%~1" echo OtIAAAAACRMJEQktG3JfwQNwcnXBA3AolgAABiiLAAAGEwjdpwMAAH4CAAAEGo0S
>> "%~1" echo AAABEwoRChZyVR8AcKIRChcIohEKGHL9LQBwohEKGQeiEQogYOoAAChYAAAGEwUR
>> "%~1" echo BW+rAAAGJS0GJnL1BQBwckkuAHAbbzoAAAoW/gQTCREJLShyycEDcHLTwQNwKJYA
>> "%~1" echo AAYHKAkAAAoRBW+rAAAGKKEAAAYTCN0kAwAAcu3BA3By+cEDcCiWAAAGEQVvqwAA
>> "%~1" echo Big0AAAGKAkAAAooiwAABhMI3fgCAAAGct+8A3AoDAAAChb+ARMJEQk6igAAAAAJ
>> "%~1" echo EwkRCS0bch/CA3ByOcIDcCiWAAAGKIsAAAYTCN2+AgAAIJg6AAAcjRIAAAETChEK
>> "%~1" echo FnJVHwBwohEKFwiiEQoYcho6AHCiEQoZco3CA3CiEQoact+8A3CiEQobB6IRCihB
>> "%~1" echo AAAGEwRyk8IDcHKhwgNwKJYAAAYHKAkAAAoRBCihAAAGEwjdVwIAAAZy67wDcCgM
>> "%~1" echo AAAKFv4BEwkRCTqcAAAAAAkTCREJLRtyxcIDcHLbwgNwKJYAAAYoiwAABhMI3R0C
>> "%~1" echo AAAgQB8AAB6NEgAAARMKEQoWclUfAHCiEQoXCKIRChhyGjoAcKIRChlyjcIDcKIR
>> "%~1" echo ChpyKcMDcKIRChtyQ8MDcKIRChxyW5oAcKIRCh0HohEKKEEAAAYTBHJRwwNwclvD
>> "%~1" echo A3AolgAABgcoCQAAChEEKKEAAAYTCN2kAQAABnL7vANwKAwAAAoW/gETCREJLWgA
>> "%~1" echo IEAfAAAcjRIAAAETChEKFnJVHwBwohEKFwiiEQoYcho6AHCiEQoZco3CA3CiEQoa
>> "%~1" echo cvu8A3CiEQobB6IRCihBAAAGEwRyb8MDcHJ5wwNwKJYAAAYHKAkAAAoRBCihAAAG
>> "%~1" echo EwjdKAEAAAZyWS0AcCgMAAAKLRAGch+9A3AoDAAAChb+ASsBFgATCREJOtUAAAAA
>> "%~1" echo AnKLwwNwKI0AAAYTBhEGKIYAAAYsFREGcpu8A3AbbzoAAAoW/gQW/gErARYAEwkR
>> "%~1" echo CS0bcqHDA3ByscMDcCiWAAAGKIsAAAYTCN2xAAAAIEAfAAAdjRIAAAETChEKFnJV
>> "%~1" echo HwBwohEKFwiiEQoYcho6AHCiEQoZco3CA3CiEQoaBqIRChsHohEKHBEGohEKKEEA
>> "%~1" echo AAYTBAZyWS0AcCgMAAAKLRFy48MDcHLtwwNwKJYAAAYrD3L/wwNwcgnEA3AolgAA
>> "%~1" echo BgARBigJAAAKEQQooQAABhMI3ityG8QDcHIrxANwKJYAAAYoiwAABhMI3hMTBwAR
>> "%~1" echo B28IAAAKKIsAAAYTCN4AABEIKgBBHAAAAAAAAH0AAAALBQAAiAUAABMAAAARAAAB
>> "%~1" echo EzADADgAAABoAAARACiKAAAGCgZypRsAcAJvJwAACgADKFAAAAoMCC0NBnL2MABw
>> "%~1" echo A28nAAAKAAIoOQAABgAGCysAByoAAAAAOwB8ACYAPAA+AGAACgANABMwBgCKAgAA
>> "%~1" echo aQAAEQACIKAPAABy474DcAMoCQAACig+AAAGCnL1BQBwCwAGKIQAAAYTDRYTDis6
>> "%~1" echo EQ0RDpoMAAhvVQAACg0JcteeAHAbb1wAAAoW/gETDxEPLRAACR5vVwAACm9VAAAK
>> "%~1" echo CysVABEOF1gTDhEOEQ2Oaf4EEw8RDy24B28+AAAKFv4BFv4BEw8RDy0bclnEA3By
>> "%~1" echo ecQDcCiWAAAGKIsAAAYTDDjmAQAABx6NKQAAASXQTwAABCi/AAAKb8AAAAoW/gQT
>> "%~1" echo DxEPLRtys8QDcHLPxANwKJYAAAYoiwAABhMMOKsBAAB+BgAABHIbxQNwKDYAAAoT
>> "%~1" echo BBEEKG0AAAomAiBAHwAAcr4yAHADKAkAAAooPgAABhMFEQUDKJoAAAYTBhEGey0A
>> "%~1" echo AAQoUAAACi0cEQZ7LQAABHLFGABwKAwAAAotCREGey0AAAQrBXIzxQNwABMHA3LF
>> "%~1" echo GABwEQcoMQAACigyAAAGcgALAHAoCQAAChMIEQQRCCg2AAAKEwl+AgAABBuNEgAA
>> "%~1" echo ARMQERAWclUfAHCiERAXAqIREBhyO8UDcKIREBkHohEQGhEJohEQICC/AgAoWAAA
>> "%~1" echo BhMKEQkoZAAAChMPEQ8tPXJFxQNwclHFA3AolgAABhEKb6sAAAZyswEAcBEKexEA
>> "%~1" echo AAQoMQAACig0AAAGKAkAAAooiwAABhMMOI4AAAByc8UDcHJ/xQNwKJYAAAYRCSgJ
>> "%~1" echo AAAKEQpvqwAABiihAAAGEwsRC3KbxQNwEQlvJwAACgARC3LlKwBwEQhvJwAACgAR
>> "%~1" echo C3KlxQNwcq3FA3ARCCh1AAAKctfFA3B+AwAABChmAAAKbycAAAoAEQtyCywAcBEJ
>> "%~1" echo c+sAAAoo7AAACigzAAAGbycAAAoAEQsTDCsAEQwqAAAbMAUAPwEAAGoAABEAAygy
>> "%~1" echo AAAGCgZyAAsAcBtveQAAChMIEQgtIQACcmwQAHAoCgAACnLnxQNwbzwAAAookAAA
>> "%~1" echo BgA4AwEAAH4GAAAEchvFA3AGKGwAAAoLByhkAAAKEwgRCC0hAAJybBAAcCgKAAAK
>> "%~1" echo cvnFA3BvPAAACiiQAAAGADjFAAAAB3PrAAAKDBuNAQAAARMJEQkWcgnGA3CiEQkX
>> "%~1" echo BnJ5mABwcvUFAHBvoAAACqIRCRhy8sYDcKIRCRkIb+wAAAqMKgAAAaIRCRpylKcA
>> "%~1" echo cKIRCSgVAAAKDShNAAAKCW88AAAKEwQCEQQWEQSOaW9iAAAKAAco7QAAChMFACAA
>> "%~1" echo AAEAjSwAAAETBisMAhEGFhEHb2IAAAoAEQURBhYRBo5pb14AAAolEwcW/gITCBEI
>> "%~1" echo LdoA3hQRBRT+ARMIEQgtCBEFbyUAAAoA3AAqAAEQAAACAPEAOCkBFAAAAAATMAMA
>> "%~1" echo QwEAAGsAABEAKIoAAAYKKDcAAAYLB3LFGABwKAwAAAoW/gETChEKLRty0RsAcHIt
>> "%~1" echo vQNwKJYAAAYoiwAABhMJOAQBAAByQ5kAcHPVAAAKDBYNOLwAAAAAfg0AAAQJmhME
>> "%~1" echo EQQfLm9TAAAKEwURBBYRBW9UAAAKEwYRBBEFF1hvVwAAChMHBxEGEQcoPQAABhMI
>> "%~1" echo CRb+Ahb+ARMKEQotDAhyzAoAcG+TAAAKJghyGscDcG+TAAAKEQQokgAABm+TAAAK
>> "%~1" echo cirHA3BvkwAAChEGKJIAAAZvkwAACnI8xwNwb5MAAAoRByiSAAAGb5MAAApyUMcD
>> "%~1" echo cG+TAAAKEQgokgAABm+TAAAKcoW+A3BvkwAACiYACRdYDQl+DQAABI5p/gQTChEK
>> "%~1" echo OjH///8IctAKAHBvkwAACiYGcmjHA3AIb5IAAApvJwAACgAGEwkrABEJKgATMAMA
>> "%~1" echo TQAAAGYAABEAAnK3JwBwAygxAAAKCgB+DQAABA0WEwQrHwkRBJoLBwYoDAAAChb+
>> "%~1" echo ARMFEQUtBBcM3hcRBBdYEwQRBAmOaf4EEwURBS3UFgwrAAAIKgAAABswBACmAgAA
>> "%~1" echo bAAAEQAAKDMAAApygscDcCg0AAAKEw0SDXL8CgBwKDUAAApyrscDcCgxAAAKKDYA
>> "%~1" echo AAoKfgUAAAQoUAAACi0HfgUAAAQrCigOAAAKbw8AAAoACwcZjSkAAAETDhEOFh9c
>> "%~1" echo nREOFx8vnREOGB8unREOb8IAAAoLB3K3JwBwb8EAAAoW/gETDxEPLRcHF40pAAAB
>> "%~1" echo Ew4RDhYfLp0RDm/CAAAKCwdyYZ8AcCg2AAAKDHK4xwNwCCgJAAAKKDkAAAYAACAA
>> "%~1" echo DAAAKO4AAAoAAN4FJgAA3gAAc+8AAAoNAAlv8AAACnLmxwNwcvzHA3Bv8QAACgAJ
>> "%~1" echo ciTIA3AGb/IAAAoAAN4SCRT+ARMPEQ8tBwlvJQAACgDcAAgobQAACiYZjRIAAAET
>> "%~1" echo EBEQFnK7yANwohEQF3LpyANwohEQGHIjyQNwohEQEwQGGRdzXwAAChMFAAARBBMR
>> "%~1" echo FhMSK3ERERESmhMGABEFEQYoHgAABhMHEQcU/gEW/gETDxEPLRQRBREGHy8fXG94
>> "%~1" echo AAAKKB4AAAYTBxEHFP4BFv4BEw8RDy0CKyYRBh8vfncAAApveAAACijzAAAKEwgI
>> "%~1" echo EQgoNgAAChEHKDcAAAoAABESF1gTEhESERGOaf4EEw8RDy2BAN4UEQUU/gETDxEP
>> "%~1" echo LQgRBW8lAAAKANwAAAYoOQAACgAA3gUmAADeAAAIcrWfAHAoNgAAChMJEQkoZAAA
>> "%~1" echo ChMPEQ8tGHJjyQNwcofJA3AolgAABiiLAAAGEwzedxEJgAIAAARy3ckDcHLvyQNw
>> "%~1" echo KJYAAAYRCSgJAAAKcvUFAHAooQAABhMKEQpy7xMAcBEJbycAAAoAEQpyJxQAcHJF
>> "%~1" echo FABwbycAAAoAEQoTDN4nEwsAcg/KA3ByJcoDcCiWAAAGEQtvCAAACigJAAAKKIsA
>> "%~1" echo AAYTDN4AABEMKgAAQXwAAAAAAAC5AAAADwAAAMgAAAAFAAAAAQAAAQIAAADUAAAA
>> "%~1" echo JwAAAPsAAAASAAAAAAAAAAIAAABGAQAAjQAAANMBAAAUAAAAAAAAAAAAAADoAQAA
>> "%~1" echo CwAAAPMBAAAFAAAAAQAAAQAAAAABAAAAegIAAHsCAAAnAAAAEQAAARMwAwDSAAAA
>> "%~1" echo bQAAEXK1nwBwgAIAAAQoNAAACgoSAHL8CgBwKDUAAAqAAwAABCA9IgAAgAQAAARy
>> "%~1" echo 9QUAcIAFAAAEcvUFAHCABgAABHL1BQBwgAcAAARzlAAACoAIAAAEFnP0AAAKgAkA
>> "%~1" echo AARzlAAACoALAAAEcyYAAAqADAAABB8KjRIAAAELBxZyUcoDcKIHF3KRygNwogcY
>> "%~1" echo csXKA3CiBxly78oDcKIHGnIhywNwogcbclPLA3CiBxxyd8sDcKIHHXK1ywNwogce
>> "%~1" echo cgnMA3CiBx8JcmnMA3CiB4ANAAAEKh4CKJQAAAoqAAATMAIAIwAAADMAABEAAnsQ
>> "%~1" echo AAAEbz4AAAoWMAgCexEAAAQrBgJ7EAAABAAKKwAGKrICcvUFAHB9EAAABAJy9QUA
>> "%~1" echo cH0RAAAEAhV9EgAABAIWfRMAAAQCKJQAAAoAKhMwAgAjAAAAMwAAEQACexYAAARv
>> "%~1" echo PgAAChYwCAJ7FwAABCsGAnsWAAAEAAorAAYqAAMwAgBKAAAAAAAAAAJy9QUAcH0U
>> "%~1" echo AAAEAnL1BQBwfRUAAAQCcvUFAHB9FgAABAJy9QUAcH0XAAAEAhV9GAAABAIWfRkA
>> "%~1" echo AAQCFmp9GgAABAIolAAACgAqAAADMAIASgAAAAAAAAACcvUFAHB9GwAABAJy9QUA
>> "%~1" echo cH0cAAAEAnL1BQBwfR0AAAQCcyYAAAp9HgAABAJz9QAACn0fAAAEAnMeAAAKfSAA
>> "%~1" echo AAQCKJQAAAoAKgAAAzACAEYAAAAAAAAAAhZ9IQAABAJy9QUAcH0iAAAEAnL1BQBw
>> "%~1" echo fSMAAAQCcvUFAHB9JAAABAJy9QUAcH0lAAAEAnMeAAAKfSYAAAQCKJQAAAoAKu4C
>> "%~1" echo cvUFAHB9JwAABAJy9QUAcH0oAAAEAnL1BQBwfSkAAAQCcvUFAHB9KgAABAIWfSsA
>> "%~1" echo AAQCKJQAAAoAKgAAAzACANkAAAAAAAAAAnL1BQBwfSwAAAQCcvUFAHB9LQAABAJy
>> "%~1" echo 9QUAcH0uAAAEAnL1BQBwfS8AAAQCcvUFAHB9MAAABAJy9QUAcH0xAAAEAnL1BQBw
>> "%~1" echo fTIAAAQCcvUFAHB9MwAABAJy9QUAcH00AAAEAnL1BQBwfTUAAAQCcvUFAHB9NgAA
>> "%~1" echo BAJy9QUAcH03AAAEAnL1BQBwfTgAAAQCcvUFAHB9OQAABAJy9QUAcH06AAAEAnL1
>> "%~1" echo BQBwfTsAAAQCcvUFAHB9PAAABAJzHgAACn09AAAEAnMeAAAKfT4AAAQCKJQAAAoA
>> "%~1" echo KgAAAEJTSkIBAAEAAAAAAAwAAAB2NC4wLjMwMzE5AAAAAAUAbAAAAMweAAAjfgAA
>> "%~1" echo OB8AABQaAAAjU3RyaW5ncwAAAABMOQAA4MwDACNVUwAsBgQAEAAAACNHVUlEAAAA
>> "%~1" echo PAYEABANAAAjQmxvYgAAAAAAAAACAAABV52iKQkCAAAA+iUzABYAAAEAAABbAAAA
>> "%~1" echo EQAAAE8AAADBAAAALQEAAPUAAAABAAAAEwAAAAEAAABtAAAAAgAAAAIAAAACAAAA
>> "%~1" echo DgAAAAIAAAABAAAAAgAAAA4AAAAAAAoAAQAAAAAABgBzAGwABgDEALgABgAIAe0A
>> "%~1" echo CgDQAb0BBgDqAeABBgAcAu0ABgByAuABBgBDBLgABgB6BWwABgBwCmwABgAeC/8K
>> "%~1" echo BgAUDfQMBgA0DfQMBgBSDWwABgCGDXUNBgC6DfQMBgDbDWwABgDxDWwABgAIDmwA
>> "%~1" echo BgAvDmwABgBADmwACgB5Dm4OCgCJDr0BBgClDmwABgC8DmwABgDZDmwACgAED/EO
>> "%~1" echo BgAcD3UNDwBDDwAABgBoD+ABBgCGD2wAGwBDDwAABgCjD+0ABgCwCeABBgD4D2wA
>> "%~1" echo BgAWEOABBgApEGwABgBUEO0ACgCOEL0BBgC6EGwABgDhEGwABgAXEWwACgAmEWwA
>> "%~1" echo BgBQEWwABgBaEeABBgBjEeABBgBuEWwABgCKEXUNBgCjEWwABgC0EeABBgC+EeAB
>> "%~1" echo BgDpEWwABgAsEhcSBgBNEmwABgDCEuABBgDSEuABBgDeEuABCgABE+sSCgAPE+sS
>> "%~1" echo BgBDE2wABgBeE+0ABgBvE3UNBgCXFGwABgDFFBcSCgDSFPEOBgBdFeABBgB9FeAB
>> "%~1" echo CgCkFfEOBgAsFnUNBgALF2wABgBGF/QMBgBVF2wABgBbF2wACgCwF5EXCgC2F5EX
>> "%~1" echo CgC8F5EXCgDJF5EXCgDbF5EXCgA0AJEXCgANGJEXCgAlGG4OCgBQGJEXBgCPGGwA
>> "%~1" echo BgAPGe0ABgA3GeABCgBJGW4OCgBdGW4OCgCHGW4OCgCRGW4OCgDQGbEZBgAEGrgA
>> "%~1" echo AAAAAAEAAAAAAAEAAQAAABAAHAAAAAUAAQABAAMAEAAqAAAABQAQAKsAAwAQADQA
>> "%~1" echo AAAFABQArQADABAAPAAAAAUAGwCvAAMAEABFAAAABQAhALAAAwAQAE0AAAAFACcA
>> "%~1" echo sQADABAAWQAAAAUALACyAAMBEACbEwAABQA/ALMAAwEQAN8TAAAFAEAAtgADARAA
>> "%~1" echo PxQAAAUARAC4AAMBEAACFQAABQBHALoAAwEQABYVAAAFAEgAuwADARAAVhYAAAUA
>> "%~1" echo SgC+AAMBEABvFgAABQBMAL8AAAAAAMYWAAAFAE4AwgATAQAAFRcAABkBUADCAFGA
>> "%~1" echo egAKABEAhgAWABEAjgAWABEAlAAZABEAmQAWABEAoQAWABEAqAAWADEAsAAcADEA
>> "%~1" echo zQAfABEA1wAWADEA8QIcABEA/AIWATEA0wiAAhEAkw2xAhEAXxjkCgYAEgkWAAYA
>> "%~1" echo ygcWAAYAGQkZAAYAIgmIAgYAOQkWAAYAPgkWAAYAEgkWAAYAygcWAAYAGQkZAAYA
>> "%~1" echo IgmIAgYARgkKAAYAUQkWAAYAWQkWAAYAYAkWAAYAawkWAQYAcgmTAgYAewmbAgYA
>> "%~1" echo xweIAgYAygcWAAYAhAkWAAYAjAkWAAYAmAkWAAYApAmbAgYAhAkWAAYAsAkWAAYA
>> "%~1" echo tQkWAAYAvwkWAAYAxQmIAgYAhAkWAAYAjAkWAAYAmAkWAAYAygkWAAYA0QkWAAYA
>> "%~1" echo tQkWAAYA2wkWAAYA3wkWAAYA4wkWAAYA7AkWAAYA9AkWAAYA/AkWAAYACQoWAAYA
>> "%~1" echo FAoWAAYAHAoWAAYAJAoWAAYAKgoWAAYAMwqbAgYAPQqbAgYAjwpHBwYA8hNLBwYA
>> "%~1" echo AhSIAgYADRSIAgYAHBQWAAYAUhRPBwYA8hNLBwYAYhSIAgYA5wxcCQYAKhVgCQYA
>> "%~1" echo WgtkCQYAahYcAAYATwycCQYAgxajCQYAWgtkCRMBMhfPCRMBIxnPCbwgAAAAAJEA
>> "%~1" echo 3wAjAAEAqCMAAAAAkQDkACkAAgBgJQAAAACRAA8BLQACAJAmAAAAAJEAIQEtAAMA
>> "%~1" echo cCgAAAAAkQAyATYABADEKAAAAACRADkBQgAIAFApAAAAAJEASAE2AAwAsykAAAAA
>> "%~1" echo kQBaAU8AEADWKQAAAACRAGEBTwASAPgpAAAAAJEAaAFZABQAuCoAAAAAkQB3AV8A
>> "%~1" echo FQAILQAAAACRAIgBaAAZAI0tAAAAAJEAlgFoABwAyC0AAAAAkQCmAWgAHwAELgAA
>> "%~1" echo AACRALMBcwAiAJQvAAAAAJEA2gF7ACQATDoAAAAAkQDxAYEAJQAcOwAAAACRAAEC
>> "%~1" echo igAnAOA7AAAAAJEAEgKTACsATDwAAAAAkQApApoALQBgQQAAAACRADACowAtANxJ
>> "%~1" echo AAAAAJEANwKaAC8AGEoAAAAAkQA8ApoALwCETAAAAACRAEkCrgAvANxMAAAAAJEA
>> "%~1" echo UwK0ADEADE4AAAAAkQBfArsAMwAsTgAAAACRAGQCwgA1AFxOAAAAAJEAaQLJADcA
>> "%~1" echo SE8AAAAAkQB9As8AOACQTwAAAACRAIYC2QA8AHRTAAAAAJEAlgLhAD4A9FQAAAAA
>> "%~1" echo kQCgAukAQAAIVgAAAACRALIC9QBFALxWAAAAAJEAwQIAAUoA+FYAAAAAkQDJAgcB
>> "%~1" echo TADkVwAAAACRANgCDwFOAFhYAAAAAJEA5AIPAVAAsFgAAAAAkQAIAx4BUgBMWQAA
>> "%~1" echo AACRABUDIwFTAPxdAAAAAJEAHwMwAVYApGMAAAAAkQAqAzoBVwDYYwAAAACRADMD
>> "%~1" echo QAFYAFBkAAAAAJEAOwNNAVsApGQAAAAAkQBEA7QAXwBsZgAAAACRAEsDtABhAIBs
>> "%~1" echo AAAAAJEAXANWAWMA9GwAAAAAkQBkA64AZwDkbQAAAACRAHkDXwFpACBvAAAAAJEA
>> "%~1" echo jwNlAWsAoG8AAAAAkQCbA2oBbAB0cAAAAACRAK8DbwFtAFRxAAAAAJEAuQNqAW4A
>> "%~1" echo GHIAAAAAkQDNA3QBbwCEcgAAAACRANcDdAFwAOhyAAAAAJEA5AN5AXEALHMAAAAA
>> "%~1" echo kQDyA3QBcQAsdAAAAACRAPoDdAFyALh0AAAAAJEA/gN5AXMAgHUAAAAAkQAKBH0B
>> "%~1" echo cwCkeAAAAACRABcErgB1ANR4AAAAAJEAHASFAXcAIHkAAAAAkQAkBIwBegBgeQAA
>> "%~1" echo AACRACcEkwF9AIB5AAAAAJEAKQSMAX8AwHkAAAAAkQAwBJMBggBYegAAAACRADYE
>> "%~1" echo dAGEADR7AAAAAJEAUQSaAYUArHsAAAAAkQBhBHQBiQAsfQAAAACRAG8EagGKALx9
>> "%~1" echo AAAAAJEAegSjAYsAoH4AAAAAkQCGBKMBjQA0fwAAAACRAJAEowGPAPiAAAAAAJEA
>> "%~1" echo pASjAZEAeIIAAAAAkQCyBKMBkwAggwAAAACRAMUEowGVAHyEAAAAAJEA1QSjAZcA
>> "%~1" echo RIUAAAAAkQDlBKMBmQCchgAAAACRAPUErgGbAJCJAAAAAJEABQW1AZ0AzIkAAAAA
>> "%~1" echo kQAVBb8BogDwigAAAACRACAFygGnAGSLAAAAAJEAJAXSAakABJIAAAAAkQA3BdgB
>> "%~1" echo qgDwmAAAAACRAEcF3wGsAAiaAAAAAJEAVwXvAbEAmJsAAAAAkQBlBWoBtACAnAAA
>> "%~1" echo AACRAGwF+AG1AESdAAAAAJEAcAUAArgAGKAAAAAAkQCDBQkCuwAwogAAAACRAI0F
>> "%~1" echo FwK/AJiiAAAAAJEAlgVqAcAABKMAAAAAkQCfBa4AwQBgowAAAACRAKwFagHDANij
>> "%~1" echo AAAAAJEAugVqAcQAdKQAAAAAkQDIBWoBxQD4pAAAAACRANQFrgDGAHClAAAAAJEA
>> "%~1" echo 3wWuAMgAEKYAAAAAkQDrBa4AygBwpgAAAACRAPQFrgDMAOSmAAAAAJEA+gWuAM4A
>> "%~1" echo WKcAAAAAkQALBq4A0AAsqAAAAACRABEGrgDSAPioAAAAAJEAGgZqAdQAWKkAAAAA
>> "%~1" echo kQAkBoUB1QDMqQAAAACRACwGrgDYACSqAAAAAJEANwauANoAQKoAAAAAkQBCBq4A
>> "%~1" echo 3ACUqgAAAACRAFEGrgDeAFCrAAAAAJEAYwZqAeAAqKsAAAAAkQB5BmoB4QCwrAAA
>> "%~1" echo AACRAIgGagHiABitAAAAAJEAlgZqAeMAfK0AAAAAkQChBmoB5ACorgAAAACRALAG
>> "%~1" echo agHlAICvAAAAAJEAvwZqAeYASLAAAAAAkQDKBq4A5wCIsQAAAACRANYGagHpAPSx
>> "%~1" echo AAAAAJEA5wauAOoA9LIAAAAAkQD1BmoB7AAgtAAAAACRAAQHagHtAIi0AAAAAJEA
>> "%~1" echo GgcdAu4A4LQAAAAAkQAsByIC7wA0tQAAAACRAD0HIgLxAFy1AAAAAJEASAcoAvMA
>> "%~1" echo jLUAAAAAkQBKB2oB9QCstQAAAACRAEwHXwH2ANC1AAAAAJEAVAdqAfgA1LYAAAAA
>> "%~1" echo kQBjB2oB+QActwAAAACRAG8HMwL6AHi4AAAAAJEAdgdqAfwA0LgAAAAAkQCBB2oB
>> "%~1" echo /QAguQAAAACRAIcHOgL+AGC5AAAAAJEAjQdlAf8AnLkAAAAAkQCVB2UBAAEQugAA
>> "%~1" echo AACRAJ4HZQEBAbi6AAAAAJEArgdlAQIBcLsAAAAAkQC8B2oBAwGsuwAAAACRAMcH
>> "%~1" echo mgAEAdi7AAAAAJEAygcwAQQBELwAAAAAkQDQB2UBBQE4vAAAAACRANsHrgAGAfi8
>> "%~1" echo AAAAAJEA4QdqAQgBKL0AAAAAkQDlB0ACCQFIvQAAAACRAO8HTAILAbC9AAAAAJEA
>> "%~1" echo +gdVAg4BfL4AAAAAkQD/B2oBDwGcvwAAAACRAAMIeQEQAeS/AAAAAJEACAh5ARAB
>> "%~1" echo YMAAAAAAkQATCGoBEAHAwAAAAACRACEIrgARAfTAAAAAAJEAIwgtABMByMIAAAAA
>> "%~1" echo kQA2CGoBFAGYwwAAAACRAEMIXwIVASTFAAAAAJEATwhqAhcB3MgAAAAAkQBgCGUB
>> "%~1" echo GQFMyQAAAACRAHIIMAEaAdjMAAAAAJEAewgwARsBRNEAAAAAkQCFCHECHAHI0QAA
>> "%~1" echo AACRAJUIegIdATjSAAAAAJEAowgwAR8BANgAAAAAkQCtCKMAIAFY2AAAAACRALYI
>> "%~1" echo owAiAfDaAAAAAJEAwQi0ACQBTNwAAAAAkQDjCJoAJgGc3QAAAACRAPEIegImAfjd
>> "%~1" echo AAAAAJEAAAmaACgBBuIAAAAAhhgMCYQCKAFQIAAAAACRAGgNrAIoAYy2AAAAAJEA
>> "%~1" echo OxjdCikBKOEAAAAAkRj9GdwMKgEQ4gAAAACGCCsJiwIqAT/iAAAAAIYYDAmEAioB
>> "%~1" echo bOIAAAAAhggrCYsCKgGc4gAAAACGGAwJhAIqAfTiAAAAAIYYDAmEAioBTOMAAAAA
>> "%~1" echo hhgMCYQCKgGe4wAAAACGGAwJhAIqAdzjAAAAAIYYDAmEAioB0mQAAAAAhhgMCYQC
>> "%~1" echo KgHqZAAAAACGAK4TPQMqAedlAAAAAIYAxRM9AysB2mQAAAAAhhgMCYQCLAH8ZAAA
>> "%~1" echo AACGACgUPQMsAeJkAAAAAIYYDAmEAi0B+GUAAAAAhgBmFD0DLQGknAAAAACGGAwJ
>> "%~1" echo hAIuAaycAAAAAIYYDAmEAi4BtJwAAAAAhgA7FYQCLgH8nAAAAACGAEwVhAIuAcCe
>> "%~1" echo AAAAAIYYDAmEAi4ByJ4AAAAAhhgMCYQCLgHQngAAAACGAJQWhAIuAXSfAAAAAIYA
>> "%~1" echo pRaEAi4BAAABAEUKAAABAEoKAAABAEoKAAABAEoKAAACAFMKAAADAFgKAAAEAGEK
>> "%~1" echo AAABAEoKAAACAFMKAAADAGEKAAAEAGgKAAABAEoKAAACAFMKAAADAGEKAAAEAIQK
>> "%~1" echo AAABAIsKAAACAI0KAAABAIsKAAACAI0KAAABAI8KAAABAJEKAAACAJkKAAADAKUK
>> "%~1" echo AAAEALEKAAABAIsKAAACALwKAAADAMQKAAABAIsKAAACALwKAAADAM4KAAABAIsK
>> "%~1" echo AAACALwKAAADANcKAAABAN0KAAACAOcKAAABAOwKAAABAPMKAgACAPoKAAABAPMK
>> "%~1" echo AAACACsLAAADADkLAAAEAD4LAAABAPMKAAACACsLAAABAEcLAAACAE4LAAABAFQL
>> "%~1" echo AAACAFMKAAABAPMKAAACADkLAAABAIsKAAACAFoLAAABAIsKAAACAFoLAAABAFwL
>> "%~1" echo AAABAGQLAAACAGcLAAADAG4LAAAEAHILAAABAGQLAAACAN0KAAABAIsKAAACAHgL
>> "%~1" echo AAABAIsKAAACAH0LAAADAMQKAAAEAIYLAAAFAHgLAAABAIsKAAACAH0LAAADAMQK
>> "%~1" echo AAAEAIYLAAAFAI4LAAABAJcLAAACAJwLAAABAIsKAAACAKALAAABAIsKAAACAFoL
>> "%~1" echo AAABAIsKAAACAFoLAAABAKkLAAABAPMKAAACAE4LAAADACsLAAABAE4LAAABAI8K
>> "%~1" echo AAABAI8KAAACAK4LAAADAOcKAAABAI8KAAACALELAAADALcLAAAEALwLAAABAI8K
>> "%~1" echo AAACAMQLAAABAI8KAAACAE4LAAABAI8KAAACAMkLAAADAMwLAAAEAJEKAAABANQL
>> "%~1" echo AAACAJEKAAABANsLAAACAOMLAAABAOwLAAABAFMKAAABAPALAAABALcLAAABANQL
>> "%~1" echo AAABANQLAAABAPYLAAABALcLAgABAP4LAgACAAkMAAABANQLAAACAFMKAAABANQL
>> "%~1" echo AAACAA4MAAADABEMAAABANQLAAACABUMAAADAB0MAAABABUMAAACAEUKAAABANQL
>> "%~1" echo AAACABUMAAADAB0MAAABABUMAAACAEUKAAABANQLAAABACUMAAACANQLAAADAA4M
>> "%~1" echo AAAEABEMAAABANQLAAABANQLAAABACgMAAACANQLAAABACgMAAACANQLAAABACgM
>> "%~1" echo AAACANQLAAABACgMAAACANQLAAABACgMAAACANQLAAABACgMAAACANQLAAABACgM
>> "%~1" echo AAACANQLAAABACgMAAACANQLAAABANQLAAACAP4LAAABACoMAAACAFMKAAADANQL
>> "%~1" echo AAAEABUMAAAFAB0MAAABACoMAAACAFMKAAADABUMAAAEAC8MAAAFAEUKAAABACoM
>> "%~1" echo AAACAFMKAAABACoMAAABACoMAAACADgMAAABACUMAAACAD0MAAADAEMMAAAEADgM
>> "%~1" echo AAAFAEUMAAABACUMAAACACoMAAADADgMAAABANQLAAABAEoMAAACAEUKAAADABUM
>> "%~1" echo AAABAEoMAAACAEUKAAADABUMAAABAEoMAAACAEUKAAADABUMAAAEAE8MAAABAEUK
>> "%~1" echo AAABAI8KAAABAFYMAAACAIsKAAABAI0KAAABAI0KAAABAI8KAAABALcLAAACABEM
>> "%~1" echo AAABALcLAAACABEMAAABALcLAAACAFgMAAABAMQLAAACABEMAAABALcLAAACABEM
>> "%~1" echo AAABALcLAAACABEMAAABALcLAAACABEMAAABALcLAAABALcLAAACAF8MAAADAGQM
>> "%~1" echo AAABALcLAAACAGoMAAABALcLAAACAGoMAAABALcLAAACABEMAAABALcLAAACABEM
>> "%~1" echo AAABALcLAAABAHIMAAABAHUMAAABAHkMAAABAH0MAAABAIUMAAABAI0MAAABAJEM
>> "%~1" echo AAACAJYMAAABAJ0MAAABAKAMAAACAKcMAAABAKcMAAABALcLAAABALcLAAABALcL
>> "%~1" echo AAACAK4MAAABALcLAAACAGoMAAABACgMAAACABEMAAABAI8KAAABALcLAAACADgM
>> "%~1" echo AAABADkLAAABALcLAAABALcLAAACACoMAAABANQLAAABAI8KAAABAI8KAAABAA4M
>> "%~1" echo AAABAFMKAAABAEcLAAABABEMAAABANcKAAABALUMAAABALkMAAABAE4LAAACABEM
>> "%~1" echo AAABAI8KAAABAI8KAAACACgMAAABAPMKAAACALsMAAADAMAMAAABACgMAAABAI8K
>> "%~1" echo AAABAMUMAAABAMkMAAACAMwMAAABAEoKAAABAOwLAAABALcLAAACAM8MAAABALcL
>> "%~1" echo AAACAOwLAAABANgMAAABANsMAAABAOwLAAABAOEMAAABANQLAAACAOwLAAABAE4L
>> "%~1" echo AAABAOcMAAACAO4MAAABANQLAAACAOwLAAABAPMKAAACAFMKAAABAA4MAAACABEM
>> "%~1" echo AAABAHMNAAABAE4YAAABANwTAAABANwTAAABANwTAAABANwTUQAMCYQCWQAMCYQC
>> "%~1" echo YQAMCacCaQAMCYQCcQAMCYQCgQAMCYQCIQDVDYQCiQDlDYsCkQD4Da4AEQD/DboC
>> "%~1" echo mQAQDr8CkQAjDnoCoQA7Dh4BqQBKDsUCqQBcDosCsQCDDsoCuQAMCdACuQCVDoQC
>> "%~1" echo mQCbDnQBmQC0DtcCkQD4DdwCkQD4DeICkQD4DRcCoQDCDmoBkQDqDukC2QCVDvAC
>> "%~1" echo uQAMD/YCeQAMCfsC4QAnDwEDDAAMCYQCDAA5DyADDABODyQDFABcDzMDmQBzDzgD
>> "%~1" echo 8QCbDj0DFAB9D0ID+QCSD4QCHAAMCYQCHACaD2EDHABOD2kDJABcD30DLACyDzMD
>> "%~1" echo LAC6D5EDJAB9D0IDDADED7ADkQDND3oCDADbD7YDkQDjD7wDkQD4DYUBDADoD8MD
>> "%~1" echo EQHsD3kBGQH9D8kDGQEFEM8DEQEOEK4AIQEbENQDKQEFEIsCIQExEHQBkQA4EPED
>> "%~1" echo NADoD8MDEQBAEAgENAAMCYQCkQBJECADNABiEA4ENADbD7YDPAAMCYQCRAAMCYQC
>> "%~1" echo RADoD8MDPADoD8MDRADED7ADRAA5DyADPADED7ADPAA5DyADNAA5DyADIQBrEKcC
>> "%~1" echo IQB+EKcCIQCcEHcEEQCmELoCEQCwEH0EkQDNEIMEkQDTEGUBkQDNEI0EkQDmEIsC
>> "%~1" echo kQA4EJQEkQD3EJkEkQABEYsCkQAGEYsCkQD3EJ8EUQEdEaQEWQEMCT0DWQEqEYsC
>> "%~1" echo WQE0EYsCkQBFEekCNAAMCacCKQBVEc8EOQAMCecEeQFzEfIEKQB3EYQCKQB9EfgE
>> "%~1" echo kQD4DRYFIQGDEWUBHADEDxwFkQD4DTsFgQGRER4BiQAMCT0DHACXEUMFiQGsEXEF
>> "%~1" echo iQEFEM8DEQEOEIUBkQHMEXcFIQHcEX4FiQHyEYYFoQEBEpIFqQE4EpYFUQEFEJwF
>> "%~1" echo TAA5DyADyQAFEJwFWQFdEmoBWQFuEmoBEQGBEtsFkQCYEt4FkQCgEukCEQGpEmoB
>> "%~1" echo IQG1ElkAKQDNEv8FwQEMCT0DKQBJEA0GEQCwEBEGyQEMCRkG0QEMCR8GyQEMCYQC
>> "%~1" echo yQHbDygGDAAfE0MFEQAoE7oCkQGDEWUBkQE0EzoCDAAMCQ4E4QFSE6AGDABqE6YG
>> "%~1" echo kQExELEGKQDVDYQC8QF3E8IG8QE7DqwCHAB9E/IGQQAMCYQCQQCJE/sGCQAFEIsC
>> "%~1" echo QQCUE/sGCQAMCYQCVAAMCfsCkQB9FKMHSQGHFKgHQQCUE7UH+QEFEMYHkQABEekH
>> "%~1" echo IQGeFH4FoQCsFHkBkQDNEA8IIQG4FE0IkQDNEFUIkQCYEm0I+QEdEXkICQLcFNMI
>> "%~1" echo CQLlFIQCCQLqFA0GTADoD8MDTABODyQDXABcDzMDXAB9D0IDiQEFEMYHkQA4EEkJ
>> "%~1" echo 2QBqFWgJGQKIFYsC2QCSFWgJIQIMCYQCIQK1FT0DIQLCFT0DIQLQFW4JIQLkFW4J
>> "%~1" echo IQL/FW4JIQIZFm4J2QCVDnMJKQIMCfsCgQEMCXsJgQGVDoQC2QA4FoIJ2QBEFoQC
>> "%~1" echo 2QBJFiADgQHjD4IJVAC2FsMDGQK9FosCOQJuF9MJkQB+F90JkQCgEuMJkQCJF+kH
>> "%~1" echo kQA4EDAKUQK2FzgKaQLPF0IDWQLrF0MKcQI5DyADcQLED0kKeQK6D4sCCQD2F1cK
>> "%~1" echo UQIGGGoBUQIdGNIKgQI5DyADiQIwGGoBUQKHGHoCkQIMCfsCUQKYEukKUQKYEoUB
>> "%~1" echo UQKYEvIKkQBFEeMJQQAMCT0DyQAFEM8DmQKXGFkAqQGoGJYFqQG9GIsCqQHaGJYF
>> "%~1" echo ZAA5DyADyQAFEIsCZADED7ADSQHmEFELZAAMCYQCkQA4EGILkQDtGJQEZADoD8MD
>> "%~1" echo ZABODyQDbABcDzMDbAB9D0ID4QH5GKAGdAAMCakLdACaD2EDdACXEUMFUQK2F+kL
>> "%~1" echo qQIMCT0DqQJJEA0GIQFAGWwMsQJyGZ4MwQIMCYQCwQKlGaUM0QLoD6sMwQLkGasM
>> "%~1" echo EQHxGWoB2QIMCW4JTAAMCYQCCgAEAA0ALgAbAOgMLgAjAPEMIwEzAKICQQErAKIC
>> "%~1" echo QwEzAKICYwEzAKICZAELAKICgwEzAKICowEzAKICwQEzAKICwwEzAKIC4QEzAKIC
>> "%~1" echo 4wEzAKICAwIzAKICxA8LAKICZBALAKICxBQLAKICABUzAKICIBUzAKICAQAQAAAA
>> "%~1" echo EQC1AggDRgOWA9sD6wP4AxkENQRlBGkEqwTXBAAFDQUjBUkFYgWqBdUF5AXtBfEF
>> "%~1" echo BwYtBloGbQZ4BoMGiAaZBrcGyQYBBzEHNwc+B1MHXQeNB5wHrQe7B84H1gfhB+8H
>> "%~1" echo +QcCCBkIMAg0CDkIQwhdCHMIhgiOCKAIswjCCM4I2QjrCPkIEwkoCToJTgmHCacJ
>> "%~1" echo rgnHCegJ8gn/CQgKEwojClAKXQpnCm4KfgqFCpUKogqxCsIKyAr8CgMLEQsZCy8L
>> "%~1" echo QQtWC2gLhAu0C/ELGgwkDDoMSgxyDIUMsQzgDAMAAQAEAAIAAAA0CY8CAAA0CY8C
>> "%~1" echo AgCrAAMAAgCtAAUAGgMtA1oDdQOJAwIEKAQvBKMFVwfkCDoLmwuiC4iiAABOAEjY
>> "%~1" echo AABPAASAAAAAAAAAAAAAAAAAAAAAABwAAAAEAAAAAAAAAAAAAAABAGMAAAAAAAQA
>> "%~1" echo AAAAAAAAAAAAAAEAbAAAAAAAAwACAAQAAgAFAAIABgACAAcAAgAIAAIACQACAAoA
>> "%~1" echo AgALAAIADAACAA0AAgAOAAIADwACABEAEAAAAAA8TW9kdWxlPgBRdWVzdEFkYldl
>> "%~1" echo YlVpLmV4ZQBRdWVzdEFkYldlYlVpAENtZFJlc3VsdABDYXB0dXJlAFNuYXBzaG90
>> "%~1" echo AEFwa0luZm8AUGtnTGlzdEl0ZW0AUGtnRGV0YWlsAG1zY29ybGliAFN5c3RlbQBP
>> "%~1" echo YmplY3QATWF4QXBrQnl0ZXMAQWRiUGF0aABUb2tlbgBQb3J0AFJvb3REaXIATG9n
>> "%~1" echo RGlyAExvZ0ZpbGUATG9nTG9jawBTeXN0ZW0uVGV4dABFbmNvZGluZwBVdGY4Tm9C
>> "%~1" echo b20AUmVxTGFuZwBNYWluAFNlbGZUZXN0AFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5l
>> "%~1" echo cmljAExpc3RgMQBTZWxmVGVzdFJlZGFjdGlvbgBTZWxmVGVzdEFwa1BhcnNlAEV4
>> "%~1" echo cGVjdABFeHBlY3RDb250YWlucwBFeHBlY3ROb3RDb250YWlucwBaaXBVMTYAWmlw
>> "%~1" echo VTMyAFV0ZjhQb29sU3RyaW5nAEJ1aWxkTWluaW1hbEF4bWwAV3JpdGVTdGFydFRh
>> "%~1" echo ZwBXcml0ZUF0dHJTdHJpbmcAV3JpdGVBdHRySW50AFN0b3JlZFppcABTeXN0ZW0u
>> "%~1" echo TmV0LlNvY2tldHMAVGNwQ2xpZW50AFNlcnZlAFN5c3RlbS5JTwBTdHJlYW0AUmVh
>> "%~1" echo ZFJlcXVlc3RIZWFkAFN0cmVhbUJvZHlUb0ZpbGUARHJhaW5Cb2R5AERpY3Rpb25h
>> "%~1" echo cnlgMgBTdGF0dXMAQWN0aW9uAExvZ3MARXhwb3J0UmVwb3J0AEV4cG9ydFVybABT
>> "%~1" echo ZXJ2ZUV4cG9ydABMRTE2AExFMzIAUGFyc2VBcGsARmlsZVN0cmVhbQBSZWFkRnVs
>> "%~1" echo bABFeHRyYWN0WmlwRW50cnkAUGFyc2VBeG1sAFJlYWRNYW5pZmVzdEF0dHJzAFJl
>> "%~1" echo YWRBdHRyU3RyaW5nAFNhZmVTdHIAUmVhZFN0cmluZ1Bvb2wAUmVhZFV0ZjhTdHIA
>> "%~1" echo UmVhZFV0ZjE2U3RyAFVwbG9hZExvY2sAVXBsb2FkUGF0aHMAUHJ1bmVVcGxvYWRz
>> "%~1" echo AEFwa1VwbG9hZABBcGtJbnN0YWxsAFNzZUJlZ2luAFNzZVNlbmQAU3NlU3RhZ2UA
>> "%~1" echo U3NlT3V0AEFwa0luc3RhbGxTdHJlYW0AU3NlRG9uZQBJbnN0YWxsZWRWZXJzaW9u
>> "%~1" echo Q29kZQBUcmFuc2xhdGVJbnN0YWxsRXJyb3IAU2FmZVBhY2thZ2UAU2FuaXRpemVE
>> "%~1" echo aXNwbGF5TmFtZQBIdW1hblNpemUARmlyc3RNZWFuaW5nZnVsTGluZQBEZWJ1Z01v
>> "%~1" echo ZGUAQ29uc2VydmF0aXZlAEN1cnJlbnRTZXJpYWwASW5pdExvZwBMb2cAUmVhZExv
>> "%~1" echo Z1RhaWwAU2VsZWN0RGV2aWNlAFByb3AAU2V0dGluZwBTaABBAE11c3RTaABNdXN0
>> "%~1" echo QQBFbnN1cmVCYWNrdXAAU3RyaW5nQnVpbGRlcgBXcml0ZUJhY2t1cExpbmUAUmVz
>> "%~1" echo dG9yZUJhY2t1cABCYWNrdXBGaWxlAEZpbGxCYXR0ZXJ5AEZpbGxQb3dlcgBGaWxs
>> "%~1" echo Q29udHJvbGxlcnNGYXN0AEZpbGxSZXNvdXJjZXMARmlsbFZpcnR1YWxEZXNrdG9w
>> "%~1" echo AEZpbGxEaXNwbGF5TGl0ZQBGaWxsVGhlcm1hbExpdGUARmlsbEZhY3RvcnlMaXRl
>> "%~1" echo AENvbGxlY3RTbmFwc2hvdABBZGRTaGVsbENhcHR1cmUAQWRkQ2FwdHVyZQBDYXAA
>> "%~1" echo RmlsbFNuYXBzaG90RmllbGRzAEJ1aWxkUmVwb3J0SHRtbABBZGRJbnZvaWNlRmFj
>> "%~1" echo dHMAQWRkSW52b2ljZVJhdwBXaWZpSXAAUnVuAFJ1blJlc3VsdABBY3Rpb25gMQBS
>> "%~1" echo dW5TdHJlYW0ASm9pbkFyZ3MAUXVvdGVBcmcASm9pbk5vbkVtcHR5AEJhdHRlcnlT
>> "%~1" echo dGF0dXMAQmF0dGVyeUhlYWx0aABQb3dlclNvdXJjZQBBZnRlckNvbG9uAEFmdGVy
>> "%~1" echo RXF1YWxzAEZpbmRMaW5lAEZpZWxkAEZpbmRQYWNrYWdlRmllbGQATWVtR2IAUHJv
>> "%~1" echo cEZyb20ARmlyc3RMaW5lAEJldHdlZW4AUmVnZXhWYWx1ZQBGaXJzdFJlZ2V4AEV4
>> "%~1" echo dHJhY3RKc29uaXNoAEV4dHJhY3RKc29uaXNoUmF3AE5vcm1hbGl6ZUVtYmVkZGVk
>> "%~1" echo SnNvbgBTdG9yYWdlU3VtbWFyeQBNZW1vcnlTdW1tYXJ5AENwdVN1bW1hcnkARGlz
>> "%~1" echo cGxheVN1bW1hcnkAVGhlcm1hbFN1bW1hcnkAVXNiU3VtbWFyeQBXaWZpU3VtbWFy
>> "%~1" echo eQBCbHVldG9vdGhTdW1tYXJ5AENhbWVyYVN1bW1hcnkARmFjdG9yeVN1bW1hcnkA
>> "%~1" echo VmlydHVhbERlc2t0b3BTdW1tYXJ5AENvdW50UGFja2FnZUxpbmVzAENvdW50UHJl
>> "%~1" echo Zml4TGluZXMAQ291bnRSZWdleABWAEgAUHJpdmFjeQBBZGJTb3VyY2VMYWJlbABS
>> "%~1" echo ZWRhY3RMb29zZQBSZWRhY3QAU2VyaWFsTWFzawBDbGVhbgBMaW5lcwBWYWxpZE5z
>> "%~1" echo AFNhZmVOYW1lAERhbmdlcm91c0FjdGlvbgBEZW5pZWRTZXR0aW5nAFNoZWxsUXVv
>> "%~1" echo dGUAT2sARXJyb3IAQ2hlY2tUb2tlbgBRdWVyeQBVcmwAV3JpdGVKc29uAFdyaXRl
>> "%~1" echo Qnl0ZXMASnNvbgBFc2MASHRtbABEZXRlY3RMYW5nAE5vcm1hbGl6ZUxhbmcAVABT
>> "%~1" echo ZWxmVGVzdEFwcFBhcnNlcnMAUGFja2FnZVRpdGxlAFBhcnNlUG1MaXN0AFBhcnNl
>> "%~1" echo UGFja2FnZUR1bXAAQXBwT3BOZWVkc0NvbmZpcm0AQXBwc0xpc3QAQXBwRGV0YWls
>> "%~1" echo AEpzb25TdHJpbmdBcnJheQBJc1VzZXJQYWNrYWdlAEFwcEFjdGlvbgBBY3Rpb25P
>> "%~1" echo awBFeHRyYWN0QXBrAFNlcnZlRXh0cmFjdGVkQXBrAFF1ZXN0U2V0dGluZ0lkcwBR
>> "%~1" echo dWVzdFNldHRpbmdzAENhdGFsb2dTZXR0aW5nAEFkYkRvd25sb2FkAC5jdG9yAE91
>> "%~1" echo dHB1dABFeGl0Q29kZQBUaW1lZE91dABnZXRfVGV4dABUZXh0AE5hbWUAQ29tbWFu
>> "%~1" echo ZABEdXJhdGlvbk1zAENyZWF0ZWQAU2VyaWFsAERldmljZUxpbmUARmllbGRzAENh
>> "%~1" echo cHR1cmVzAFdhcm5pbmdzAFBhY2thZ2UAVmVyc2lvbk5hbWUAVmVyc2lvbkNvZGUA
>> "%~1" echo UGVybWlzc2lvbnMAUGF0aABJbnN0YWxsZXIAVGl0bGUAVXNlcgBNaW5TZGsAVGFy
>> "%~1" echo Z2V0U2RrAFVpZABBYmkAQ29kZVBhdGgAQXBrUGF0aABEYXRhRGlyAEZpcnN0SW5z
>> "%~1" echo dGFsbABMYXN0VXBkYXRlAEVuYWJsZWQAU3RvcHBlZABGbGFncwBTaXplVGV4dABS
>> "%~1" echo ZXF1ZXN0ZWQAUnVudGltZQBhcmdzAGZhaWx1cmVzAG5hbWUAZXhwZWN0ZWQAYWN0
>> "%~1" echo dWFsAG5lZWRsZXMAUGFyYW1BcnJheUF0dHJpYnV0ZQBzZWNyZXQAYgB2AHMAcGFj
>> "%~1" echo a2FnZQB2ZXJzaW9uTmFtZQB2ZXJzaW9uQ29kZQBwZXJtaXNzaW9uAG5hbWVJZHgA
>> "%~1" echo YXR0ckNvdW50AHZhbHVlSWR4AHZhbHVlAGVudHJ5TmFtZQBkYXRhAGNsaWVudABz
>> "%~1" echo dHJlYW0AaGVhZABTeXN0ZW0uUnVudGltZS5JbnRlcm9wU2VydmljZXMAT3V0QXR0
>> "%~1" echo cmlidXRlAGNvbnRlbnRMZW5ndGgAcGF0aABtYXhCeXRlcwBhY3Rpb24AcXVlcnkA
>> "%~1" echo c3RhbXAAcABhcGtQYXRoAGZzAG9mZnNldABidWYAY291bnQAaW5mbwBhdHRyQmFz
>> "%~1" echo ZQBzdHJpbmdzAHdhbnROYW1lAHBvb2wAaWR4AGNodW5rUG9zAGtlZXAAZXYAc3Rh
>> "%~1" echo Z2UAdGV4dABwZXJjZW50AGxpbmUAb2sAbWVzc2FnZQBzZXJpYWwAb3V0VGV4dAB0
>> "%~1" echo aW1lZE91dABwa2cAYnl0ZXMAYmFzZURpcgBkZXZpY2VMaW5lAGhpbnQAbnMAa2V5
>> "%~1" echo AHRpbWVvdXQAY29tbWFuZABzYgBkAHNuYXAAcmVxdWlyZWQAc2FmZQB0aXRsZQBm
>> "%~1" echo AGRlZnMAZmlsZQBvbkxpbmUAYQBuZWVkbGUAbGVmdAByaWdodABwYXR0ZXJuAGRm
>> "%~1" echo AG1lbQBjcHUAZGlzcGxheQB0aGVybWFsAHVzYgB3aWZpAGlwQWRkcgBidABjYW1l
>> "%~1" echo cmEAc2Vuc29yAHByZWZpeABtc2cAcQB0eXBlAGJvZHkAcmF3AHpoAGVuAG1hcmtV
>> "%~1" echo c2VyAG9wAHNjb3BlAGl0ZW1zAHJlc3VsdABleHRyYQBTeXN0ZW0uUnVudGltZS5D
>> "%~1" echo b21waWxlclNlcnZpY2VzAENvbXBpbGF0aW9uUmVsYXhhdGlvbnNBdHRyaWJ1dGUA
>> "%~1" echo UnVudGltZUNvbXBhdGliaWxpdHlBdHRyaWJ1dGUAVGhyZWFkU3RhdGljQXR0cmli
>> "%~1" echo dXRlADxNYWluPmJfXzAAbwBTeXN0ZW0uVGhyZWFkaW5nAFdhaXRDYWxsYmFjawBD
>> "%~1" echo UyQ8PjlfX0NhY2hlZEFub255bW91c01ldGhvZERlbGVnYXRlMQBDb21waWxlckdl
>> "%~1" echo bmVyYXRlZEF0dHJpYnV0ZQBDbG9zZQBFeGNlcHRpb24AZ2V0X01lc3NhZ2UAU3Ry
>> "%~1" echo aW5nAENvbmNhdABnZXRfVVRGOABDb25zb2xlAHNldF9PdXRwdXRFbmNvZGluZwBv
>> "%~1" echo cF9FcXVhbGl0eQBFbnZpcm9ubWVudABFeGl0AEFwcERvbWFpbgBnZXRfQ3VycmVu
>> "%~1" echo dERvbWFpbgBnZXRfQmFzZURpcmVjdG9yeQBTeXN0ZW0uTmV0AElQQWRkcmVzcwBQ
>> "%~1" echo YXJzZQBUY3BMaXN0ZW5lcgBTdGFydABXcml0ZUxpbmUAQ29uc29sZUtleUluZm8A
>> "%~1" echo UmVhZEtleQBJbnQzMgBHZXRFbnZpcm9ubWVudFZhcmlhYmxlAFN0cmluZ0NvbXBh
>> "%~1" echo cmlzb24ARXF1YWxzAFN5c3RlbS5EaWFnbm9zdGljcwBQcm9jZXNzAEFjY2VwdFRj
>> "%~1" echo cENsaWVudABUaHJlYWRQb29sAFF1ZXVlVXNlcldvcmtJdGVtAGdldF9Db3VudABF
>> "%~1" echo bnVtZXJhdG9yAEdldEVudW1lcmF0b3IAZ2V0X0N1cnJlbnQAVGV4dFdyaXRlcgBn
>> "%~1" echo ZXRfRXJyb3IATW92ZU5leHQASURpc3Bvc2FibGUARGlzcG9zZQBzZXRfSXRlbQBL
>> "%~1" echo ZXlWYWx1ZVBhaXJgMgBnZXRfS2V5AGdldF9WYWx1ZQBnZXRfSXRlbQBvcF9JbmVx
>> "%~1" echo dWFsaXR5AFRvQXJyYXkASm9pbgBBZGQAR2V0VGVtcFBhdGgAR3VpZABOZXdHdWlk
>> "%~1" echo AFRvU3RyaW5nAENvbWJpbmUARmlsZQBXcml0ZUFsbEJ5dGVzAEJvb2xlYW4ARGVs
>> "%~1" echo ZXRlAEluZGV4T2YAR2V0Qnl0ZXMAZ2V0X0xlbmd0aABJRW51bWVyYWJsZWAxAEFk
>> "%~1" echo ZFJhbmdlAHNldF9SZWNlaXZlVGltZW91dABzZXRfU2VuZFRpbWVvdXQATmV0d29y
>> "%~1" echo a1N0cmVhbQBHZXRTdHJlYW0AZ2V0X0FTQ0lJAEdldFN0cmluZwBTdHJpbmdTcGxp
>> "%~1" echo dE9wdGlvbnMAU3BsaXQASXNOdWxsT3JFbXB0eQBDaGFyAFRvVXBwZXJJbnZhcmlh
>> "%~1" echo bnQAU3Vic3RyaW5nAFRyaW0AVG9Mb3dlckludmFyaWFudABJbnQ2NABUcnlQYXJz
>> "%~1" echo ZQBVcmkAZ2V0X1F1ZXJ5AGdldF9BYnNvbHV0ZVBhdGgAU3RhcnRzV2l0aABCeXRl
>> "%~1" echo AFJlYWQARmlsZU1vZGUARmlsZUFjY2VzcwBNYXRoAE1pbgBGbHVzaABXcml0ZQBF
>> "%~1" echo eGlzdHMAVGhyZWFkAFNsZWVwAENvbnRhaW5zS2V5AERhdGVUaW1lAGdldF9Ob3cA
>> "%~1" echo RGlyZWN0b3J5AERpcmVjdG9yeUluZm8AQ3JlYXRlRGlyZWN0b3J5AFdyaXRlQWxs
>> "%~1" echo VGV4dABUaW1lU3BhbgBvcF9TdWJ0cmFjdGlvbgBnZXRfVG90YWxNaWxsaXNlY29u
>> "%~1" echo ZHMAU3lzdGVtLkdsb2JhbGl6YXRpb24AQ3VsdHVyZUluZm8AZ2V0X0ludmFyaWFu
>> "%~1" echo dEN1bHR1cmUASUZvcm1hdFByb3ZpZGVyAEVzY2FwZURhdGFTdHJpbmcAVW5lc2Nh
>> "%~1" echo cGVEYXRhU3RyaW5nAERpcmVjdG9yeVNlcGFyYXRvckNoYXIAUmVwbGFjZQBFbmRz
>> "%~1" echo V2l0aABHZXRGdWxsUGF0aABSZWFkQWxsQnl0ZXMAU2Vla09yaWdpbgBTZWVrAElP
>> "%~1" echo RXhjZXB0aW9uAE1lbW9yeVN0cmVhbQBTeXN0ZW0uSU8uQ29tcHJlc3Npb24ARGVm
>> "%~1" echo bGF0ZVN0cmVhbQBDb21wcmVzc2lvbk1vZGUAQ29udGFpbnMAZ2V0X1VuaWNvZGUA
>> "%~1" echo R2V0RGlyZWN0b3JpZXMAU3RyaW5nQ29tcGFyZXIAZ2V0X09yZGluYWwASUNvbXBh
>> "%~1" echo cmVyYDEAU29ydABNb25pdG9yAEVudGVyAFRyeUdldFZhbHVlAEFwcGVuZExpbmUA
>> "%~1" echo QXBwZW5kADw+Y19fRGlzcGxheUNsYXNzYgA8QXBrSW5zdGFsbFN0cmVhbT5iX181
>> "%~1" echo ADxBcGtJbnN0YWxsU3RyZWFtPmJfXzcAbG4APD5jX19EaXNwbGF5Q2xhc3NkAENT
>> "%~1" echo JDw+OF9fbG9jYWxzYwBzYXdTdWNjZXNzAHNhd1NpZ01pc21hdGNoAGxhc3RFcnJM
>> "%~1" echo aW5lADxBcGtJbnN0YWxsU3RyZWFtPmJfXzYAPD5jX19EaXNwbGF5Q2xhc3NmAENT
>> "%~1" echo JDw+OF9fbG9jYWxzZQBvazIAPEFwa0luc3RhbGxTdHJlYW0+Yl9fOABnZXRfQ2hh
>> "%~1" echo cnMASXNMZXR0ZXJPckRpZ2l0AERvdWJsZQBBcHBlbmRBbGxUZXh0AGdldF9OZXdM
>> "%~1" echo aW5lAFJlYWRBbGxMaW5lcwBOdW1iZXJTdHlsZXMAU3RvcHdhdGNoAFN0YXJ0TmV3
>> "%~1" echo AFN0b3AAZ2V0X0VsYXBzZWRNaWxsaXNlY29uZHMAPD5jX19EaXNwbGF5Q2xhc3Mx
>> "%~1" echo NAA8PmNfX0Rpc3BsYXlDbGFzczE2AENTJDw+OF9fbG9jYWxzMTUAPFJ1blJlc3Vs
>> "%~1" echo dD5iX18xMgA8UnVuUmVzdWx0PmJfXzEzAFN0cmVhbVJlYWRlcgBnZXRfU3RhbmRh
>> "%~1" echo cmRPdXRwdXQAVGV4dFJlYWRlcgBSZWFkVG9FbmQAZ2V0X1N0YW5kYXJkRXJyb3IA
>> "%~1" echo UHJvY2Vzc1N0YXJ0SW5mbwBzZXRfRmlsZU5hbWUAc2V0X0FyZ3VtZW50cwBzZXRf
>> "%~1" echo VXNlU2hlbGxFeGVjdXRlAHNldF9SZWRpcmVjdFN0YW5kYXJkT3V0cHV0AHNldF9S
>> "%~1" echo ZWRpcmVjdFN0YW5kYXJkRXJyb3IAc2V0X0NyZWF0ZU5vV2luZG93AFRocmVhZFN0
>> "%~1" echo YXJ0AFdhaXRGb3JFeGl0AEtpbGwAZ2V0X0V4aXRDb2RlADw+Y19fRGlzcGxheUNs
>> "%~1" echo YXNzMWYAZ2F0ZQA8PmNfX0Rpc3BsYXlDbGFzczIxAENTJDw+OF9fbG9jYWxzMjAA
>> "%~1" echo PFJ1blN0cmVhbT5iX18xZAA8UnVuU3RyZWFtPmJfXzFlAEludm9rZQBSZWFkTGlu
>> "%~1" echo ZQA8UHJpdmF0ZUltcGxlbWVudGF0aW9uRGV0YWlscz57OUQxNEZCM0QtNjFDQS00
>> "%~1" echo QzYxLTk5M0QtOTI4NjU4RTkyMUFCfQBWYWx1ZVR5cGUAX19TdGF0aWNBcnJheUlu
>> "%~1" echo aXRUeXBlU2l6ZT0xNgAkJG1ldGhvZDB4NjAwMDA1Yi0xAFJ1bnRpbWVIZWxwZXJz
>> "%~1" echo AEFycmF5AFJ1bnRpbWVGaWVsZEhhbmRsZQBJbml0aWFsaXplQXJyYXkASW5kZXhP
>> "%~1" echo ZkFueQBUcmltRW5kAFN5c3RlbS5UZXh0LlJlZ3VsYXJFeHByZXNzaW9ucwBSZWdl
>> "%~1" echo eABNYXRjaABSZWdleE9wdGlvbnMAR3JvdXAAZ2V0X1N1Y2Nlc3MAR3JvdXBDb2xs
>> "%~1" echo ZWN0aW9uAGdldF9Hcm91cHMAUmVmZXJlbmNlRXF1YWxzAEVzY2FwZQBNYXRjaENv
>> "%~1" echo bGxlY3Rpb24ATWF0Y2hlcwBXZWJVdGlsaXR5AEh0bWxFbmNvZGUAPFJlZGFjdExv
>> "%~1" echo b3NlPmJfXzIzAG0ATWF0Y2hFdmFsdWF0b3IAQ1MkPD45X19DYWNoZWRBbm9ueW1v
>> "%~1" echo dXNNZXRob2REZWxlZ2F0ZTI0AElzTWF0Y2gAQ29udmVydABGcm9tQmFzZTY0U3Ry
>> "%~1" echo aW5nAGdldF9DdXJyZW50VUlDdWx0dXJlAGdldF9Ud29MZXR0ZXJJU09MYW5ndWFn
>> "%~1" echo ZU5hbWUAZ2V0X0N1cnJlbnRDdWx0dXJlAExhc3RJbmRleE9mAGdldF9PcmRpbmFs
>> "%~1" echo SWdub3JlQ2FzZQBJRXF1YWxpdHlDb21wYXJlcmAxACQkbWV0aG9kMHg2MDAwMGEy
>> "%~1" echo LTEARmlsZUluZm8AT3BlblJlYWQAU2VydmljZVBvaW50TWFuYWdlcgBTZWN1cml0
>> "%~1" echo eVByb3RvY29sVHlwZQBzZXRfU2VjdXJpdHlQcm90b2NvbABXZWJDbGllbnQAV2Vi
>> "%~1" echo SGVhZGVyQ29sbGVjdGlvbgBnZXRfSGVhZGVycwBTeXN0ZW0uQ29sbGVjdGlvbnMu
>> "%~1" echo U3BlY2lhbGl6ZWQATmFtZVZhbHVlQ29sbGVjdGlvbgBEb3dubG9hZEZpbGUAR2V0
>> "%~1" echo RmlsZU5hbWUALmNjdG9yAFVURjhFbmNvZGluZwAAAAAAD/eLQmy/fgt6Al84Xhr/
>> "%~1" echo ARctAC0AcwBlAGwAZgAtAHQAZQBzAHQAARMxADIANwAuADAALgAwAC4AMQAATVEA
>> "%~1" echo dQBlAHMAdAAgAEEARABCACAAVwBlAGIAVQBJACAAL1SoUjFZJY0a/zgANwA2ADUA
>> "%~1" echo LQA4ADcAOAA1ACAA73rjU/2QDU7vUyh1AjABLS9UqFIxWSWNGv84ADcANgA1AC0A
>> "%~1" echo OAA3ADgANQAgAO9641P9kA1O71ModQIwASNoAHQAdABwADoALwAvADEAMgA3AC4A
>> "%~1" echo MAAuADAALgAxADoAABEvAD8AdABvAGsAZQBuAD0AAC1RAHUAZQBzAHQAIABBAEQA
>> "%~1" echo QgAgAFcAZQBiAFUASQAgAA1noVLyXS9UqFIa/wE96lPRdixUIAAxADIANwAuADAA
>> "%~1" echo LgAwAC4AMQAb/3NR7ZUsZ5d641MOVCAAVwBlAGIAVQBJACAAXFBiawIwAQtBAEQA
>> "%~1" echo QgA6ACAAAAnlZddfOgAgAAEtDWehUi9UqFIa/2gAdAB0AHAAOgAvAC8AMQAyADcA
>> "%~1" echo LgAwAC4AMAAuADEAOgABAy8AAA8dUstZ3o+lY7ZyAWAa/wEDIAAAAzEAADVRAFUA
>> "%~1" echo RQBTAFQAXwBBAEQAQgBfAFcARQBCAFUASQBfAE4ATwBfAEIAUgBPAFcAUwBFAFIA
>> "%~1" echo AA/3i0JsBFkGdDFZJY0a/wGB6XsAXAAiAEQAZQB2AGkAYwBlAFwAIgA6AHsAXAAi
>> "%~1" echo AEIAdQBpAGwAZABUAHkAcABlAFwAIgA6AFwAIgBQAFYAVAAxAC4AMQBcACIALABc
>> "%~1" echo ACIARABlAHYAaQBjAGUAVAB5AHAAZQBcACIAOgBcACIARQB1AHIAZQBrAGEAXAAi
>> "%~1" echo AH0ALABcACIARgBpAGwAZQBGAG8AcgBtAGEAdABcACIAOgB7AFwAIgBUAGkAbQBl
>> "%~1" echo AHMAdABhAG0AcABcACIAOgBcACIAMgAwADIANQAtADEAMQAtADEANQBUADAAOAA6
>> "%~1" echo ADEANQA6ADQANQBcACIAfQAsAFwAIgBNAGUAdABhAGQAYQB0AGEAXAAiADoAewBc
>> "%~1" echo ACIATgBhAG0AZQBkAFQAYQBnAHMAXAAiADoAewBcACIAbABvAGMAYQB0AGkAbwBu
>> "%~1" echo AF8AaQBkAFwAIgA6AFwAIgBnAHQAawBcACIALABcACIAcwB0AGEAdABpAG8AbgBf
>> "%~1" echo AGkAZABcACIAOgBcACIAdwBmAC0AZQB1AHIAZQBrAGEALQBpAG8AdAAtADIAdQBw
>> "%~1" echo AC0ANAAxAFwAIgAsAFwAIgBjAGEAbABpAGIAcgBhAHQAaQBvAG4AXwB0AHkAcABl
>> "%~1" echo AFwAIgA6AFwAIgBJAE8AVABcACIAfQB9AH0AARVEAGUAdgBpAGMAZQBUAHkAcABl
>> "%~1" echo AAANRQB1AHIAZQBrAGEAABNCAHUAaQBsAGQAVAB5AHAAZQAADVAAVgBUADEALgAx
>> "%~1" echo AAATVABpAG0AZQBzAHQAYQBtAHAAACcyADAAMgA1AC0AMQAxAC0AMQA1AFQAMAA4
>> "%~1" echo ADoAMQA1ADoANAA1AAEXbABvAGMAYQB0AGkAbwBuAF8AaQBkAAAHZwB0AGsAABVz
>> "%~1" echo AHQAYQB0AGkAbwBuAF8AaQBkAAApdwBmAC0AZQB1AHIAZQBrAGEALQBpAG8AdAAt
>> "%~1" echo ADIAdQBwAC0ANAAxAAEdRgBhAGMAdABvAHIAeQBTAHUAbQBtAGEAcgB5AAAPbABv
>> "%~1" echo AGMAIABnAHQAawAAOXMAdABhAHQAaQBvAG4AIAB3AGYALQBlAHUAcgBlAGsAYQAt
>> "%~1" echo AGkAbwB0AC0AMgB1AHAALQA0ADEAAYChewBcACIAUwBlAG4AcwBvAHIAVAB5AHAA
>> "%~1" echo ZQBcACIAOgBcACIATwBHADAAMQBBAFwAIgB9AHsAXAAiAFMAZQBuAHMAbwByAFQA
>> "%~1" echo eQBwAGUAXAAiADoAXAAiAE8AVgA3ADIANQAxAFwAIgB9AHsAXAAiAFMAZQBuAHMA
>> "%~1" echo bwByAFQAeQBwAGUAXAAiADoAXAAiAEkATQBYADQANwAxAFwAIgB9AAAbQwBhAG0A
>> "%~1" echo ZQByAGEAUwB1AG0AbQBhAHIAeQAAAQAPTwBHADAAMQBBACAAMQAAEU8AVgA3ADIA
>> "%~1" echo NQAxACAAMQAAEUkATQBYADQANwAxACAAMQAAOVEAdQBlAHMAdABBAGQAYgBXAGUA
>> "%~1" echo YgBVAGkAIABzAGUAbABmAC0AdABlAHMAdAAgAFAAQQBTAFMAAT9bAHIAbwAuAHMA
>> "%~1" echo ZQByAGkAYQBsAG4AbwBdADoAIABbADEAUABBAFMASAA5AEIARwAwAEcAMAA0ADMA
>> "%~1" echo MQBdAAAdMQBQAEEAUwBIADkAQgBHADAARwAwADQAMwAxAAAnaQBuAGUAdAAgADEA
>> "%~1" echo MAAuADQAMgAuADAALgAxADMANwAvADIANAAAFzEAMAAuADQAMgAuADAALgAxADMA
>> "%~1" echo NwAAIWkAbgBlAHQAIAAxADkAMgAuADEANgA4AC4AMQAuADUAABcxADkAMgAuADEA
>> "%~1" echo NgA4AC4AMQAuADUAACVwAHUAYgBsAGkAYwAgADgALgA4AC4AOAAuADgAIABkAG4A
>> "%~1" echo cwAADzgALgA4AC4AOAAuADgAACFjAGcAbgBhAHQAIAAxADAAMAAuADYANAAuADMA
>> "%~1" echo LgA5AAAVMQAwADAALgA2ADQALgAzAC4AOQAAVWkAbgBlAHQANgAgAGYAZQA4ADAA
>> "%~1" echo OgA6ADEAMgAzADQAOgA1ADYANwA4ADoAOQBhAGIAYwA6AGQAZQBmADAAIABzAGMA
>> "%~1" echo bwBwAGUAIABsAGkAbgBrAAAVZgBlADgAMAA6ADoAMQAyADMANAAAN2EAZABkAHIA
>> "%~1" echo IAAyADAAMAAxADoAZABiADgAOgA6AGYAZgAwADAAOgA0ADIAOgA4ADMAMgA5AAAR
>> "%~1" echo MgAwADAAMQA6AGQAYgA4AAAPcgBlAGQAYQBjAHQAOgAASXYAZQByAHMAaQBvAG4A
>> "%~1" echo IAAxADQAIABiAHUAaQBsAGQAIABQAFIAMQAuADAAIABtAG8AZABlAGwAIABRAHUA
>> "%~1" echo ZQBzAHQAXwAzAAAbcgBlAGQAYQBjAHQALQBiAGUAbgBpAGcAbgABF3IAZQBkAGEA
>> "%~1" echo YwB0AC0AdABpAG0AZQABXzAANgAtADAAOQAgADEAMgA6ADAAMAA6ADAAMQAuADAA
>> "%~1" echo MAAzACAASQAgAFQAaABlAHIAbQBhAGwAUwBlAHIAdgBpAGMAZQA6ACAAcwBrAGkA
>> "%~1" echo bgA9ADMAMgAuADAAQwABG1IARQBEAEEAQwBUAEUARABfAEkAUABWADYAADNjAG8A
>> "%~1" echo bQAuAGUAeABhAG0AcABsAGUALgBxAHUAZQBzAHQAcwBlAGwAZgB0AGUAcwB0AAAL
>> "%~1" echo MQAuADIALgAzAAA3YQBuAGQAcgBvAGkAZAAuAHAAZQByAG0AaQBzAHMAaQBvAG4A
>> "%~1" echo LgBJAE4AVABFAFIATgBFAFQAABlhAHgAbQBsAC4AcABhAGMAawBhAGcAZQAAIWEA
>> "%~1" echo eABtAGwALgB2AGUAcgBzAGkAbwBuAE4AYQBtAGUAACFhAHgAbQBsAC4AdgBlAHIA
>> "%~1" echo cwBpAG8AbgBDAG8AZABlAAAFNAAyAACAg2EAeABtAGwALgBwAGUAcgBtAGkAcwBz
>> "%~1" echo AGkAbwBuADoAIABlAHgAcABlAGMAdABlAGQAIABbAGEAbgBkAHIAbwBpAGQALgBw
>> "%~1" echo AGUAcgBtAGkAcwBzAGkAbwBuAC4ASQBOAFQARQBSAE4ARQBUAF0AIABiAHUAdAAg
>> "%~1" echo AGcAbwB0ACAAWwAAAywAAANdAAAncQB1AGUAcwB0AC0AYQBkAGIALQBzAGUAbABm
>> "%~1" echo AHQAZQBzAHQALQABA04AAAkuAGEAcABrAAAnQQBuAGQAcgBvAGkAZABNAGEAbgBp
>> "%~1" echo AGYAZQBzAHQALgB4AG0AbAAADWEAcABrAC4AbwBrAAAJVAByAHUAZQAAF2EAcABr
>> "%~1" echo AC4AcABhAGMAawBhAGcAZQAAH2EAcABrAC4AdgBlAHIAcwBpAG8AbgBOAGEAbQBl
>> "%~1" echo AAAfYQBwAGsALgB2AGUAcgBzAGkAbwBuAEMAbwBkAGUAABNhAHAAawAuAHoAaQBw
>> "%~1" echo ADoAIAAAGToAIABlAHgAcABlAGMAdABlAGQAIABbAAAXXQAgAGIAdQB0ACAAZwBv
>> "%~1" echo AHQAIABbAAAXOgAgAG0AaQBzAHMAaQBuAGcAIABbAAANXQAgAGkAbgAgAFsAABU6
>> "%~1" echo ACAAcwBlAGMAcgBlAHQAIABbAAApXQAgAHMAdABpAGwAbAAgAHAAcgBlAHMAZQBu
>> "%~1" echo AHQAIABpAG4AIABbAAARbQBhAG4AaQBmAGUAcwB0AAAPcABhAGMAawBhAGcAZQAA
>> "%~1" echo F3YAZQByAHMAaQBvAG4ATgBhAG0AZQAAF3YAZQByAHMAaQBvAG4AQwBvAGQAZQAA
>> "%~1" echo H3UAcwBlAHMALQBwAGUAcgBtAGkAcwBzAGkAbwBuAAEJbgBhAG0AZQAABQ0ACgAA
>> "%~1" echo HWMAbwBuAHQAZQBuAHQALQBsAGUAbgBnAHQAaAABG3gALQBxAHUAZQBzAHQALQB0
>> "%~1" echo AG8AawBlAG4AARl4AC0AcQB1AGUAcwB0AC0AbABhAG4AZwABCWwAYQBuAGcAAAt0
>> "%~1" echo AG8AawBlAG4AABcvAGEAcABpAC8AcwB0AGEAdAB1AHMAABF0AG8AawBlAG4AIADg
>> "%~1" echo ZUhlARcvAGEAcABpAC8AYQBjAHQAaQBvAG4AAAlQAE8AUwBUAAAj7k85Zc1kXE/F
>> "%~1" echo X3uYf08odSAAUABPAFMAVAAgAPeLQmwCMAENYQBjAHQAaQBvAG4AAA9jAG8AbgBm
>> "%~1" echo AGkAcgBtAAAHWQBFAFMAABdxU2mWzWRcTwCXgYmMTiFrbnikiwIwARMvAGEAcABp
>> "%~1" echo AC8AbABvAGcAcwAAFy8AYQBwAGkALwBlAHgAcABvAHIAdAAAH/xb+lHFX3uYf08o
>> "%~1" echo dSAAUABPAFMAVAAgAPeLQmwCMAEfLwBhAHAAaQAvAGEAcABrAC8AdQBwAGwAbwBh
>> "%~1" echo AGQAAB8KTiBPxV97mH9PKHUgAFAATwBTAFQAIAD3i0JsAjABIS8AYQBwAGkALwBh
>> "%~1" echo AHAAawAvAGkAbgBzAHQAYQBsAGwAAB+JW8WIxV97mH9PKHUgAFAATwBTAFQAIAD3
>> "%~1" echo i0JsAjABHYlbxYggAEEAUABLACAAAJeBiYxOIWtueKSLAjABLy8AYQBwAGkALwBh
>> "%~1" echo AHAAawAvAGkAbgBzAHQAYQBsAGwALQBzAHQAcgBlAGEAbQABRUEAUABLACAAaQBu
>> "%~1" echo AHMAdABhAGwAbAAgAHIAZQBxAHUAaQByAGUAcwAgAGMAbwBuAGYAaQByAG0AYQB0
>> "%~1" echo AGkAbwBuAC4AABMvAGEAcABpAC8AYQBwAHAAcwAAG2kAbgB2AGEAbABpAGQAIAB0
>> "%~1" echo AG8AawBlAG4AAAtzAGMAbwBwAGUAACEvAGEAcABpAC8AYQBwAHAAcwAvAGQAZQB0
>> "%~1" echo AGEAaQBsAAAhLwBhAHAAaQAvAGEAcABwAHMALwBhAGMAdABpAG8AbgAAPU0AdQB0
>> "%~1" echo AGEAdABpAG4AZwAgAGEAYwB0AGkAbwBuAHMAIAByAGUAcQB1AGkAcgBlACAAUABP
>> "%~1" echo AFMAVAAuAAAFbwBwAAA/VABoAGkAcwAgAGEAYwB0AGkAbwBuACAAbgBlAGUAZABz
>> "%~1" echo ACAAYwBvAG4AZgBpAHIAbQBhAHQAaQBvAG4ALgAAHS8AYQBwAGkALwBhAHAAcABz
>> "%~1" echo AC8AZgBpAGwAZQAAM3QAZQB4AHQALwBwAGwAYQBpAG4AOwAgAGMAaABhAHIAcwBl
>> "%~1" echo AHQAPQB1AHQAZgAtADgAAScvAGEAcABpAC8AcQB1AGUAcwB0AC0AcwBlAHQAdABp
>> "%~1" echo AG4AZwBzAAEjLwBhAHAAaQAvAGEAZABiAC8AZABvAHcAbgBsAG8AYQBkAAAfC059
>> "%~1" echo j8Vfe5h/Tyh1IABQAE8AUwBUACAA94tCbAIwAS9EAG8AdwBuAGwAbwBhAGQAIABy
>> "%~1" echo AGUAcQB1AGkAcgBlAHMAIABQAE8AUwBUAC4AABkLTn2PIABBAEQAQgAgAACXgYlu
>> "%~1" echo eKSLAjABQUEARABCACAAZABvAHcAbgBsAG8AYQBkACAAbgBlAGUAZABzACAAYwBv
>> "%~1" echo AG4AZgBpAHIAbQBhAHQAaQBvAG4ALgAAEy8AZQB4AHAAbwByAHQAcwAvAAAZLwBm
>> "%~1" echo AGEAdgBpAGMAbwBuAC4AaQBjAG8AABtpAG0AYQBnAGUALwBzAHYAZwArAHgAbQBs
>> "%~1" echo AACBszwAcwB2AGcAIAB4AG0AbABuAHMAPQAnAGgAdAB0AHAAOgAvAC8AdwB3AHcA
>> "%~1" echo LgB3ADMALgBvAHIAZwAvADIAMAAwADAALwBzAHYAZwAnACAAdgBpAGUAdwBCAG8A
>> "%~1" echo eAA9ACcAMAAgADAAIAAyADQAIAAyADQAJwAgAGYAaQBsAGwAPQAnAG4AbwBuAGUA
>> "%~1" echo JwAgAHMAdAByAG8AawBlAD0AJwAjADIANQA2ADMAZQBiACcAIABzAHQAcgBvAGsA
>> "%~1" echo ZQAtAHcAaQBkAHQAaAA9ACcAMgAnAD4APABwAGEAdABoACAAZAA9ACcATQA2ACAA
>> "%~1" echo OQBoADEAMgBhADMAIAAzACAAMAAgADAAIAAxACAAMwAgADMAdgAzAGEAMwAgADMA
>> "%~1" echo IAAwACAAMAAgADEALQAzACAAMwBoAC0AMQAuADUAbAAtADIALgA1AC0AMwBoAC0A
>> "%~1" echo NABsAC0AMgAuADUAIAAzAEgANgBhADMAIAAzACAAMAAgADAAIAAxAC0AMwAtADMA
>> "%~1" echo dgAtADMAYQAzACAAMwAgADAAIAAwACAAMQAgADMALQAzAHoAJwAvAD4APAAvAHMA
>> "%~1" echo dgBnAD4AATF0AGUAeAB0AC8AaAB0AG0AbAA7ACAAYwBoAGEAcgBzAGUAdAA9AHUA
>> "%~1" echo dABmAC0AOAABD3MAZQByAHYAaQBjAGUAABUxADIANwAuADAALgAwAC4AMQA6AAAP
>> "%~1" echo YQBkAGIAUABhAHQAaAAAD2wAbwBnAEYAaQBsAGUAABd3AGkAbgBkAG8AdwBzAEwA
>> "%~1" echo YQBuAGcAABFhAGQAYgBGAG8AdQBuAGQAAAtmAGEAbABzAGUAAAl0AHIAdQBlAAAX
>> "%~1" echo ZABlAHYAaQBjAGUAUwB0AGEAdABlAAAVZABlAHYAaQBjAGUATABpAG4AZQAACWgA
>> "%~1" echo aQBuAHQAABNjAG8AbgBuAGUAYwB0AGUAZAAADWQAZQB2AGkAYwBlAAALtnIBYPuL
>> "%~1" echo 1lMa/wENcwBlAHIAaQBhAGwAAAttAG8AZABlAGwAACFyAG8ALgBwAHIAbwBkAHUA
>> "%~1" echo YwB0AC4AbQBvAGQAZQBsAAAPYQBuAGQAcgBvAGkAZAAAMXIAbwAuAGIAdQBpAGwA
>> "%~1" echo ZAAuAHYAZQByAHMAaQBvAG4ALgByAGUAbABlAGEAcwBlAAAHcwBkAGsAAClyAG8A
>> "%~1" echo LgBiAHUAaQBsAGQALgB2AGUAcgBzAGkAbwBuAC4AcwBkAGsAABtzAGUAYwB1AHIA
>> "%~1" echo aQB0AHkAUABhAHQAYwBoAAA/cgBvAC4AYgB1AGkAbABkAC4AdgBlAHIAcwBpAG8A
>> "%~1" echo bgAuAHMAZQBjAHUAcgBpAHQAeQBfAHAAYQB0AGMAaAAAGW0AYQBuAHUAZgBhAGMA
>> "%~1" echo dAB1AHIAZQByAAAvcgBvAC4AcAByAG8AZAB1AGMAdAAuAG0AYQBuAHUAZgBhAGMA
>> "%~1" echo dAB1AHIAZQByAAALYgByAGEAbgBkAAAhcgBvAC4AcAByAG8AZAB1AGMAdAAuAGIA
>> "%~1" echo cgBhAG4AZAAAF3AAcgBvAGQAdQBjAHQATgBhAG0AZQAAH3IAbwAuAHAAcgBvAGQA
>> "%~1" echo dQBjAHQALgBuAGEAbQBlAAAbcAByAG8AZAB1AGMAdABEAGUAdgBpAGMAZQAAI3IA
>> "%~1" echo bwAuAHAAcgBvAGQAdQBjAHQALgBkAGUAdgBpAGMAZQAAC2IAbwBhAHIAZAAAIXIA
>> "%~1" echo bwAuAHAAcgBvAGQAdQBjAHQALgBiAG8AYQByAGQAAAdzAG8AYwAAJ3IAbwAuAHMA
>> "%~1" echo bwBjAC4AbQBhAG4AdQBmAGEAYwB0AHUAcgBlAHIAABlyAG8ALgBzAG8AYwAuAG0A
>> "%~1" echo bwBkAGUAbAAAD2IAdQBpAGwAZABJAGQAACdyAG8ALgBiAHUAaQBsAGQALgBkAGkA
>> "%~1" echo cwBwAGwAYQB5AC4AaQBkAAAXYgB1AGkAbABkAEIAcgBhAG4AYwBoAAAfcgBvAC4A
>> "%~1" echo YgB1AGkAbABkAC4AYgByAGEAbgBjAGgAACFiAHUAaQBsAGQASQBuAGMAcgBlAG0A
>> "%~1" echo ZQBuAHQAYQBsAAA5cgBvAC4AYgB1AGkAbABkAC4AdgBlAHIAcwBpAG8AbgAuAGkA
>> "%~1" echo bgBjAHIAZQBtAGUAbgB0AGEAbAAAF3YAZQBuAGQAbwByAFAAYQB0AGMAaAAAPXIA
>> "%~1" echo bwAuAHYAZQBuAGQAbwByAC4AYgB1AGkAbABkAC4AcwBlAGMAdQByAGkAdAB5AF8A
>> "%~1" echo cABhAHQAYwBoAAAHYQBiAGkAACVyAG8ALgBwAHIAbwBkAHUAYwB0AC4AYwBwAHUA
>> "%~1" echo LgBhAGIAaQAADXcAaQBmAGkASQBwAAAXcQB1AGUAcwB0AEwAbwBjAGEAbABlAAAl
>> "%~1" echo cABlAHIAcwBpAHMAdAAuAHMAeQBzAC4AbABvAGMAYQBsAGUAAAMtAAENcwB5AHMA
>> "%~1" echo dABlAG0AAB1zAHkAcwB0AGUAbQBfAGwAbwBjAGEAbABlAHMAABVhAGQAYgBFAG4A
>> "%~1" echo YQBiAGwAZQBkAAANZwBsAG8AYgBhAGwAABdhAGQAYgBfAGUAbgBhAGIAbABlAGQA
>> "%~1" echo AA9hAGQAYgBXAGkAZgBpAAAhYQBkAGIAXwB3AGkAZgBpAF8AZQBuAGEAYgBsAGUA
>> "%~1" echo ZAAADXMAdABhAHkATwBuAAAxcwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAA
>> "%~1" echo bAB1AGcAZwBlAGQAXwBpAG4AABN3AGkAZgBpAFMAbABlAGUAcAAAI3cAaQBmAGkA
>> "%~1" echo XwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAAE3MAYwByAGUAZQBuAE8AZgBmAAAl
>> "%~1" echo cwBjAHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAABlzAGwAZQBlAHAA
>> "%~1" echo VABpAG0AZQBvAHUAdAAADXMAZQBjAHUAcgBlAAAbcwBsAGUAZQBwAF8AdABpAG0A
>> "%~1" echo ZQBvAHUAdAAAEWwAbwB3AFAAbwB3AGUAcgAAE2wAbwB3AF8AcABvAHcAZQByAAAZ
>> "%~1" echo tnIBYPuL1lMa/2QAZQB2AGkAYwBlACAAARMgAGIAYQB0AHQAZQByAHkAPQAAGWIA
>> "%~1" echo YQB0AHQAZQByAHkATABlAHYAZQBsAAAPJQAgAHQAZQBtAHAAPQAAF2IAYQB0AHQA
>> "%~1" echo ZQByAHkAVABlAG0AcAAAD0MAIAB3AGEAawBlAD0AABd3AGEAawBlAGYAdQBsAG4A
>> "%~1" echo ZQBzAHMAABEgAHMAdABhAHkATwBuAD0AABMgAGEAZABiAFcAaQBmAGkAPQAAC81k
>> "%~1" echo XE8AX8tZGv8BESAAcwBlAHIAaQBhAGwAPQAAF3IAZQBzAHQAYQByAHQAXwBhAGQA
>> "%~1" echo YgAAF2sAaQBsAGwALQBzAGUAcgB2AGUAcgABGXMAdABhAHIAdAAtAHMAZQByAHYA
>> "%~1" echo ZQByAAENcgBlAHMAdQBsAHQAAB3yXc2RL1Q1dRGB73ogAEEARABCACAADWehUgIw
>> "%~1" echo ASGhbAlnKFe/fhRO8l2IY0NnhHYgAFEAdQBlAHMAdAACMAEVcwBhAGYAZQBfAHMA
>> "%~1" echo bABlAGUAcAAAOWkAbgBwAHUAdAAgAGsAZQB5AGUAdgBlAG4AdAAgAEsARQBZAEMA
>> "%~1" echo TwBEAEUAXwBTAEwARQBFAFAAAEnyXWJgDVndT4hbPFB2XtFTAZAgAHAAcgBvAHgA
>> "%~1" echo XwBvAHAAZQBuACAAKwAgAEsARQBZAEMATwBEAEUAXwBTAEwARQBFAFAAAjABFWsA
>> "%~1" echo ZQBlAHAAXwBhAHcAYQBrAGUAABHyXZReKHXtd/Zl3U87bQIwARVkAGUAYgB1AGcA
>> "%~1" echo XwBtAG8AZABlAAB/8l0vVCh1A4zVi+VdXE8hag9fGv9VAFMAQgAvAEEAQwAgAN1P
>> "%~1" echo AWMkVZKRATBXAGkALQBGAGkAIAANThFPIHcBME9cVV4gADIANAAgAA9c9mUBMCFq
>> "%~1" echo 32JpTzRiYJfRjwIw035fZw5U94tnYkyIHCBiYA1ZEU8gd4WN9mUdIAIwARtyAGUA
>> "%~1" echo cwB0AG8AcgBlAF8AcwBsAGUAZQBwAAAl8l1iYA1ZY2s4XhFPIHcOTiAANQAgAAZS
>> "%~1" echo n5RPXFVehY32ZQIwARljAG8AbgBzAGUAcgB2AGEAdABpAHYAZQAAE/JdYmANWd1P
>> "%~1" echo iFvYnqSLPFACMAEdcgBlAHMAdABvAHIAZQBfAGIAYQBjAGsAdQBwAAAv8l3OTgdZ
>> "%~1" echo /U5iYA1Zvotufwz/dl7RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgACMAETcAByAG8A
>> "%~1" echo eABfAG8AcABlAG4AAGdhAG0AIABiAHIAbwBhAGQAYwBhAHMAdAAgAC0AYQAgAGMA
>> "%~1" echo bwBtAC4AbwBjAHUAbAB1AHMALgB2AHIAcABvAHcAZQByAG0AYQBuAGEAZwBlAHIA
>> "%~1" echo LgBwAHIAbwB4AF8AbwBwAGUAbgABHfJd0VMBkCAAcAByAG8AeABfAG8AcABlAG4A
>> "%~1" echo AjABFXAAcgBvAHgAXwBjAGwAbwBzAGUAAGlhAG0AIABiAHIAbwBhAGQAYwBhAHMA
>> "%~1" echo dAAgAC0AYQAgAGMAbwBtAC4AbwBjAHUAbAB1AHMALgB2AHIAcABvAHcAZQByAG0A
>> "%~1" echo YQBuAGEAZwBlAHIALgBwAHIAbwB4AF8AYwBsAG8AcwBlAAEf8l3RUwGQIABwAHIA
>> "%~1" echo bwB4AF8AYwBsAG8AcwBlAAIwARF3AGkAcgBlAGwAZQBzAHMAAAUtAHMAAQt0AGMA
>> "%~1" echo cABpAHAAAAk1ADUANQA1AAAj8l33i0JsAF8vVOBlv34gAEEARABCACAANQA1ADUA
>> "%~1" echo NQACMAEZdwBpAHIAZQBsAGUAcwBzAF8AbwBmAGYAAE1zAGUAdAB0AGkAbgBnAHMA
>> "%~1" echo IABwAHUAdAAgAGcAbABvAGIAYQBsACAAYQBkAGIAXwB3AGkAZgBpAF8AZQBuAGEA
>> "%~1" echo YgBsAGUAZAAgADAAAAd1AHMAYgAAXfJd94tCbHNR7ZXgZb9+IABBAEQAQgAM/2EA
>> "%~1" echo ZABiAGQAIADyXQdS3lYgAFUAUwBCACAAIWoPXwIw5YJTX01SL2bgZb9+3o+lYwz/
>> "%~1" echo rWUAX15cjk5jazhesHNhjAIwARNrAGUAeQBfAHMAbABlAGUAcAAAJfJd0VMBkCAA
>> "%~1" echo SwBFAFkAQwBPAEQARQBfAFMATABFAEUAUAACMAEVawBlAHkAXwB3AGEAawBlAHUA
>> "%~1" echo cAAAO2kAbgBwAHUAdAAgAGsAZQB5AGUAdgBlAG4AdAAgAEsARQBZAEMATwBEAEUA
>> "%~1" echo XwBXAEEASwBFAFUAUAAAQ/Jd0VMBkCAASwBFAFkAQwBPAEQARQBfAFcAQQBLAEUA
>> "%~1" echo VQBQAAIwxU4oVyAAQQBEAEIAIADNTihXv372ZQlnSGUCMAETcwBjAHIAZQBlAG4A
>> "%~1" echo XwA1AG0AAFtzAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAHMAeQBzAHQAZQBtACAA
>> "%~1" echo cwBjAHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAIAAzADAAMAAwADAA
>> "%~1" echo MAAAOXMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAAPQAgADMA
>> "%~1" echo MAAwADAAMAAwAAIwARVzAGMAcgBlAGUAbgBfADIANABoAABfcwBlAHQAdABpAG4A
>> "%~1" echo ZwBzACAAcAB1AHQAIABzAHkAcwB0AGUAbQAgAHMAYwByAGUAZQBuAF8AbwBmAGYA
>> "%~1" echo XwB0AGkAbQBlAG8AdQB0ACAAOAA2ADQAMAAwADAAMAAwAAA9cwBjAHIAZQBlAG4A
>> "%~1" echo XwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAIAA9ACAAOAA2ADQAMAAwADAAMAAwAAIw
>> "%~1" echo ARFzAHQAYQB5AF8AbwBmAGYAAF1zAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcA
>> "%~1" echo bABvAGIAYQBsACAAcwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcA
>> "%~1" echo ZwBlAGQAXwBpAG4AIAAwAAA7cwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAA
>> "%~1" echo bAB1AGcAZwBlAGQAXwBpAG4AIAA9ACAAMAACMAEXcwB0AGEAeQBfAHUAcwBiAF8A
>> "%~1" echo YQBjAABdcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHMA
>> "%~1" echo dABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBuACAA
>> "%~1" echo MwAAO3MAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8A
>> "%~1" echo aQBuACAAPQAgADMAAjABIXIAZQBzAGUAdABfAHMAYwByAGUAZQBuAF8AbwBmAGYA
>> "%~1" echo AEHyXc2Rbn8gAHMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAA
>> "%~1" echo PQAgADMAMAAwADAAMAAwAAIwARtyAGUAcwBlAHQAXwBzAHQAYQB5AF8AbwBuAABD
>> "%~1" echo 8l3NkW5/IABzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUA
>> "%~1" echo ZABfAGkAbgAgAD0AIAAwAAIwASFyAGUAcwBlAHQAXwB3AGkAZgBpAF8AcwBsAGUA
>> "%~1" echo ZQBwAABPcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHcA
>> "%~1" echo aQBmAGkAXwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAgADEAADXyXc2Rbn8gAHcA
>> "%~1" echo aQBmAGkAXwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAgAD0AIAAxAAIwASdyAGUA
>> "%~1" echo cwBlAHQAXwBzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0AABJcwBlAHQAdABpAG4A
>> "%~1" echo ZwBzACAAZABlAGwAZQB0AGUAIABzAGUAYwB1AHIAZQAgAHMAbABlAGUAcABfAHQA
>> "%~1" echo aQBtAGUAbwB1AHQAAEHyXSBSZJYgAHMAbABlAGUAcABfAHQAaQBtAGUAbwB1AHQA
>> "%~1" echo IAB2XtFTAZAgAHAAcgBvAHgAXwBvAHAAZQBuAAIwARNxAHUAZQBzAHQAXwBwAHUA
>> "%~1" echo dAAAHWMAdQBzAHQAbwBtAF8AcwBlAHQAdABpAG4AZwAABW4AcwAAB2sAZQB5AAAL
>> "%~1" echo dgBhAGwAdQBlAAAjbgBhAG0AZQBzAHAAYQBjAGUAIAAWYi6VDVQNTghU1WwCMAEz
>> "%~1" echo SQBuAHYAYQBsAGkAZAAgAG4AYQBtAGUAcwBwAGEAYwBlACAAbwByACAAawBlAHkA
>> "%~1" echo LgAAK+WLLpUNVF5cjk7Yms6YaZb7fN9+LpUM//JdO5Zia+qBmltJTplRZVECMAFD
>> "%~1" echo VABoAGEAdAAgAGsAZQB5ACAAaQBzACAAYgBsAG8AYwBrAGUAZAAgAGEAcwAgAGgA
>> "%~1" echo aQBnAGgALQByAGkAcwBrAC4AAR/li76Lbn8NTihXNFk+ZmKXf2dBUbiLF1JoiC1O
>> "%~1" echo AjABV1QAaABhAHQAIABzAGUAdAB0AGkAbgBnACAAaQBzACAAbgBvAHQAIABpAG4A
>> "%~1" echo IAB0AGgAZQAgAGgAZQBhAGQAcwBlAHQAIABjAGEAdABhAGwAbwBnAC4AABtzAGUA
>> "%~1" echo dAB0AGkAbgBnAHMAIABwAHUAdAAgAAADLgAAByAAPQAgAAAhYwB1AHMAdABvAG0A
>> "%~1" echo XwBiAHIAbwBhAGQAYwBhAHMAdAAAEX9erWQNVPB5DU4IVNVsAjABIWEAbQAgAGIA
>> "%~1" echo cgBvAGEAZABjAGEAcwB0ACAALQBhACAAAQ3yXdFTAZB/Xq1kGv8BCypn5XfNZFxP
>> "%~1" echo AjABC81kXE+MWxBiGv8BESAAcgBlAHMAdQBsAHQAPQAABW8AawAAC2UAcgByAG8A
>> "%~1" echo cgAAC81kXE8xWSWNGv8BDyAAZQByAHIAbwByAD0AAAl0AGUAeAB0AAAl/Fv6UQBf
>> "%~1" echo y1ka/+pT+4uMW3RlvosHWeFPb2AgAEgAVABNAEwAAR95AHkAeQB5AE0ATQBkAGQA
>> "%~1" echo XwBIAEgAbQBtAHMAcwAAD2UAeABwAG8AcgB0AHMAADdRAHUAZQBzAHQAMwBfAGQA
>> "%~1" echo ZQB2AGkAYwBlAF8AcAByAGkAdgBhAHQAZQBfAGYAdQBsAGwAXwAACy4AaAB0AG0A
>> "%~1" echo bAAAM1EAdQBlAHMAdAAzAF8AZABlAHYAaQBjAGUAXwBzAGgAYQByAGUAXwBzAGEA
>> "%~1" echo ZgBlAF8AABdwAHIAaQB2AGEAdABlAFAAYQB0AGgAABFzAGEAZgBlAFAAYQB0AGgA
>> "%~1" echo ABVwAHIAaQB2AGEAdABlAFUAcgBsAAAPcwBhAGYAZQBVAHIAbAAAFWQAdQByAGEA
>> "%~1" echo dABpAG8AbgBNAHMAABlzAGUAYwB0AGkAbwBuAEMAbwB1AG4AdAAAEXcAYQByAG4A
>> "%~1" echo aQBuAGcAcwAAByAAfAAgAAAp8l0fdRBiwXkJZ4xbdGVIcoxUBlKrTolbaFFIciAA
>> "%~1" echo SABUAE0ATAACMAEL/Fv6UYxbEGIa/wEHIAAvACAAAAv8W/pRMVkljRr/AQ8/AHQA
>> "%~1" echo bwBrAGUAbgA9AAAFLgAuAAANXpfVbKViSlTvjYRfAQulYkpUDU5YWyhXAQ/7i9ZT
>> "%~1" echo pWJKVDFZJY0a/wE5QQBQAEsAIACFUSpnfmIwUiAAQQBuAGQAcgBvAGkAZABNAGEA
>> "%~1" echo bgBpAGYAZQBzAHQALgB4AG0AbAABGUEAWABNAEwAIADjiZBnKmeXXzBSBVMNVAEV
>> "%~1" echo QQBQAEsAIAD7i9ZTD2EWWdN+X2cBGQ1OL2YJZ0hlhHYgAEEAWABNAEwAIAA0WQEP
>> "%~1" echo dQBwAGwAbwBhAGQAcwAAMwpOIE+FUblbOk56ehZiOn8RXCAAQwBvAG4AdABlAG4A
>> "%~1" echo dAAtAEwAZQBuAGcAdABoAAIwASVBAFAASwAgAIWNx48nWQ9cCk5Qlgj/NAAgAEcA
>> "%~1" echo aQBCAAn/AjABJ3kAeQB5AHkATQBNAGQAZABfAEgASABtAG0AcwBzAF8AZgBmAGYA
>> "%~1" echo AA9hAHAAcAAuAGEAcABrAAAx2Y8NTi9mCWdIZYR2IABBAFAASwAI/zp/EVwgAFoA
>> "%~1" echo SQBQAC8AUABLACAANFkJ/wIwARF1AHAAbABvAGEAZABJAGQAABFmAGkAbABlAE4A
>> "%~1" echo YQBtAGUAABNzAGkAegBlAEIAeQB0AGUAcwAAEXMAaQB6AGUAVABlAHgAdAAAH3AA
>> "%~1" echo ZQByAG0AaQBzAHMAaQBvAG4AQwBvAHUAbgB0AAAXcABlAHIAbQBpAHMAcwBpAG8A
>> "%~1" echo bgBzAAADCgAAD3AAYQByAHMAZQBPAGsAABVwAGEAcgBzAGUARQByAHIAbwByAAAp
>> "%~1" echo aQBuAHMAdABhAGwAbABlAGQAVgBlAHIAcwBpAG8AbgBDAG8AZABlAAAhYQBsAHIA
>> "%~1" echo ZQBhAGQAeQBJAG4AcwB0AGEAbABsAGUAZAAAD0EAUABLACAACk4gTxr/AQUgACgA
>> "%~1" echo AA0pACAAcABrAGcAPQAADyAAdgBOAGEAbQBlAD0AAA8gAHYAQwBvAGQAZQA9AAAT
>> "%~1" echo QQBQAEsAIAAKTiBPMVkljRr/ASV+Yg1OMFLyXQpOIE+EdiAAQQBQAEsADP/3i82R
>> "%~1" echo sGUKTiBPAjABD3IAZQBwAGwAYQBjAGUAAAtnAHIAYQBuAHQAABNkAG8AdwBuAGcA
>> "%~1" echo cgBhAGQAZQAAHXUAbgBpAG4AcwB0AGEAbABsAEYAaQByAHMAdAAAIUEAUABLACAA
>> "%~1" echo iVvFiABfy1ka/3MAZQByAGkAYQBsAD0AAQsgAHAAawBnAD0AAAcgAHIAPQAAByAA
>> "%~1" echo ZwA9AAAHIABkAD0AAAkgAHUAZgA9AAALeFN9j+dlBVMgAAEJIAAuAC4ALgAAE3UA
>> "%~1" echo bgBpAG4AcwB0AGEAbABsAAAFIAAgAAAPaQBuAHMAdABhAGwAbAAABS0AcgABBS0A
>> "%~1" echo ZwABBS0AZAABD4lbxYga/2EAZABiACAAAQ9TAHUAYwBjAGUAcwBzAABFSQBOAFMA
>> "%~1" echo VABBAEwATABfAEYAQQBJAEwARQBEAF8AVQBQAEQAQQBUAEUAXwBJAE4AQwBPAE0A
>> "%~1" echo UABBAFQASQBCAEwARQAAL3MAaQBnAG4AYQB0AHUAcgBlAHMAIABkAG8AIABuAG8A
>> "%~1" echo dAAgAG0AYQB0AGMAaAAAM0kATgBDAE8ATgBTAEkAUwBUAEUATgBUAF8AQwBFAFIA
>> "%~1" echo VABJAEYASQBDAEEAVABFAFMAAB9+ew1UDU4mewz/6oGoUnhTfY/nZQVTDlTNkcWI
>> "%~1" echo IAABCyAAIADNkcWIGv8BC3MAdABlAHAAcwAAB3IAYQB3AAAJiVvFiBBin1IBAxr/
>> "%~1" echo AQMCMAETQQBQAEsAIACJW8WIEGKfUhr/ARNBAFAASwAgAIlbxYgxWSWNGv8BCyAA
>> "%~1" echo cgBhAHcAPQAAE0EAUABLACAAiVvFiAJfOF4a/wGBDUgAVABUAFAALwAxAC4AMQAg
>> "%~1" echo ADIAMAAwACAATwBLAA0ACgBDAG8AbgB0AGUAbgB0AC0AVAB5AHAAZQA6ACAAdABl
>> "%~1" echo AHgAdAAvAGUAdgBlAG4AdAAtAHMAdAByAGUAYQBtADsAIABjAGgAYQByAHMAZQB0
>> "%~1" echo AD0AdQB0AGYALQA4AA0ACgBDAGEAYwBoAGUALQBDAG8AbgB0AHIAbwBsADoAIABu
>> "%~1" echo AG8ALQBzAHQAbwByAGUADQAKAEMAbwBuAG4AZQBjAHQAaQBvAG4AOgAgAGMAbABv
>> "%~1" echo AHMAZQANAAoAWAAtAEEAYwBjAGUAbAAtAEIAdQBmAGYAZQByAGkAbgBnADoAIABu
>> "%~1" echo AG8ADQAKAA0ACgABD2UAdgBlAG4AdAA6ACAAAA1kAGEAdABhADoAIAAABQoACgAA
>> "%~1" echo C3MAdABhAGcAZQAAD3AAZQByAGMAZQBuAHQAAAlsAGkAbgBlAAANbwB1AHQAcAB1
>> "%~1" echo AHQAAA9GAGEAaQBsAHUAcgBlAAALRQByAHIAbwByAAAhUwB0AHIAZQBhAG0AZQBk
>> "%~1" echo ACAASQBuAHMAdABhAGwAbAAAFVAAZQByAGYAbwByAG0AaQBuAGcAAA8oV76LB1kK
>> "%~1" echo TolbxYgmIAElQQBQAEsAIABBbQ9fiVvFiABfy1ka/3MAZQByAGkAYQBsAD0AAQ9w
>> "%~1" echo AHIAZQBwAGEAcgBlAAALxlEHWYlbxYgmIAEDJiABGygAeFN9j4WN9mUM/+d+7X4d
>> "%~1" echo XNWLiVvFiCkAAQlwAHUAcwBoAAAdqGMBkCAAQQBQAEsAIAAwUjRZPmZ2XolbxYgm
>> "%~1" echo IAEJYQBkAGIAIAAAF0EAUABLACAAQW0PX4lbxYgQYp9SGv8BC3IAZQB0AHIAeQAA
>> "%~1" echo G357DVQNTiZ7DP94U32P52UFUw5UzZHFiCYgARuJW8WIEGKfUgj/8l1IUXhTfY/n
>> "%~1" echo ZQVTCf8a/wEfQQBQAEsAIABBbQ9fiVvFiBBin1IoAM2RxYgpABr/AQuJW8WIAl84
>> "%~1" echo Xhr/ARdBAFAASwAgAEFtD1+JW8WIAl84Xhr/AQ9tAGUAcwBzAGEAZwBlAAAHMQAw
>> "%~1" echo ADAAAAlkAG8AbgBlAAAhZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBnAGUAIAAA
>> "%~1" echo GXYAZQByAHMAaQBvAG4AQwBvAGQAZQA9AAA3iVvFiIWN9mUI/ydZBVMWYr6LB1ng
>> "%~1" echo Zc1UlF4J/wIw94tueKSLNFk+ZvJd44kBlXZezZHViwIwAU1+ew1UDk7yXYlbxYhI
>> "%~1" echo cixnDU4ATvSBGv/+UgmQHCB+ew1UDU4me/ZlSFF4U32PHSAOVM2R1YsI/xpPBW5k
>> "%~1" echo luWLlF4odXBlbmMJ/wIwAUFJAE4AUwBUAEEATABMAF8ARgBBAEkATABFAEQAXwBW
>> "%~1" echo AEUAUgBTAEkATwBOAF8ARABPAFcATgBHAFIAQQBEAEUAADlIcixn91NOT45O8l2J
>> "%~1" echo W8WISHIsZxr//lIJkBwgQVG4i02Wp34gACgALQBkACkAHSAOVM2R1YsCMAE7SQBO
>> "%~1" echo AFMAVABBAEwATABfAEYAQQBJAEwARQBEAF8AQQBMAFIARQBBAEQAWQBfAEUAWABJ
>> "%~1" echo AFMAVABTAAAzlF4odfJdWFsoVxr//lIJkBwgzZHFiN1PWXVwZW5jIAAoAC0AcgAp
>> "%~1" echo AB0gDlTNkdWLAjABR0kATgBTAFQAQQBMAEwAXwBGAEEASQBMAEUARABfAEkATgBT
>> "%~1" echo AFUARgBGAEkAQwBJAEUATgBUAF8AUwBUAE8AUgBBAEcARQAAE76LB1lYW6hQenr0
>> "%~1" echo lQ1Os40CMAE/SQBOAFMAVABBAEwATABfAEYAQQBJAEwARQBEAF8ATgBPAF8ATQBB
>> "%~1" echo AFQAQwBIAEkATgBHAF8AQQBCAEkAUwAANUEAUABLACAAhHYgAEMAUABVACAAtmeE
>> "%~1" echo ZyAAKABBAEIASQApACAADk6+iwdZDU45U02RAjABMUkATgBTAFQAQQBMAEwAXwBG
>> "%~1" echo AEEASQBMAEUARABfAE8ATABEAEUAUgBfAFMARABLAAApQQBQAEsAIACBiUJshHb7
>> "%~1" echo fN9+SHIsZ9iajk6+iwdZU19NUkhyLGcCMAEpSQBOAFMAVABBAEwATABfAFAAQQBS
>> "%~1" echo AFMARQBfAEYAQQBJAEwARQBEAAAxQQBQAEsAIADjiZBnMVkljRr/h2X2Tu9T/YBf
>> "%~1" echo Y09XFmINTi9mCWdIZYlbxYgFUwIwAReJW8WIMVkljQj/KmfldxmV74sJ/wIwAQuJ
>> "%~1" echo W8WIMVkljRr/AQUgAEIAAAcwAC4AMAAAByAASwBCAAAHIABNAEIAAAkwAC4AMAAw
>> "%~1" echo AAAHIABHAEIAAE9zAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcAbABvAGIAYQBs
>> "%~1" echo ACAAdwBpAGYAaQBfAHMAbABlAGUAcABfAHAAbwBsAGkAYwB5ACAAMgAASXMAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAHAAdQB0ACAAcwBlAGMAdQByAGUAIABzAGwAZQBlAHAAXwB0
>> "%~1" echo AGkAbQBlAG8AdQB0ACAALQAxAAEdUQB1AGUAcwB0AF8AQQBEAEIAXwBMAG8AZwBz
>> "%~1" echo AAANdwBlAGIAdQBpAF8AAAkuAGwAbwBnAAAnUQB1AGUAcwB0AF8AQQBEAEIAXwBX
>> "%~1" echo AGUAYgBVAEkALgBsAG8AZwAAL3kAeQB5AHkALQBNAE0ALQBkAGQAIABIAEgAOgBt
>> "%~1" echo AG0AOgBzAHMALgBmAGYAZgABE+Vl11+HZfZOGlwqZxtS+l4CMAEP+4vWU+Vl118x
>> "%~1" echo WSWNGv8BWSpn0VOwcyAAQQBEAEIAIAC+iwdZAjDAaOVnAF/RUwWAIWoPXwEwVQBT
>> "%~1" echo AEIAIAADjNWLiGNDZwEwcGVuY79+jFQgAFcAaQBuAGQAbwB3AHMAIABxmqhSAjAB
>> "%~1" echo D2QAZQB2AGkAYwBlAHMAAAUtAGwAAQ9MAGkAcwB0ACAAbwBmAAAXbQBvAGQAZQBs
>> "%~1" echo ADoAUQB1AGUAcwB0AAAdcAByAG8AZAB1AGMAdAA6AGUAdQByAGUAawBhAAAbZABl
>> "%~1" echo AHYAaQBjAGUAOgBlAHUAcgBlAGsAYQAAGXUAbgBhAHUAdABoAG8AcgBpAHoAZQBk
>> "%~1" echo AAAPbwBmAGYAbABpAG4AZQAAMfJd3o+lY3Ze8l2IY0NnDP/yXRhPSFEJkOliIABV
>> "%~1" echo AFMAQgAgAFEAdQBlAHMAdAACMAEl8l3ej6Vjdl7yXYhjQ2cM//JdCZDpYiAAUQB1
>> "%~1" echo AGUAcwB0AAIwAU/yXd6PpWN2XvJdiGNDZwIw6GwPYRr/KmfGiytSMFIgAFEAdQBl
>> "%~1" echo AHMAdAAgAItX91MM//JdCZDpYix7AE4qTiAAQQBEAEIAIAC+iwdZAjABO76LB1kq
>> "%~1" echo Z4hjQ2ca/zRiCk40WT5mDP8oVyAAVQBTAEIAIAADjNWLiGNDZzlfl3rMkQmQ6WJB
>> "%~1" echo UbiLAjABO76LB1m7eb9+Gv/NkS9UIABBAEQAQgAgAA1noVIBMM2R0mMgAFUAUwBC
>> "%~1" echo ACAAFmL0ZmJjcGVuY79+AjABFdFTsHO+iwdZRk+2cgFgAl84Xhr/AQ91AG4AawBu
>> "%~1" echo AG8AdwBuAAAJbgBvAG4AZQAAEWcAZQB0AHAAcgBvAHAAIAAAG3MAZQB0AHQAaQBu
>> "%~1" echo AGcAcwAgAGcAZQB0ACAAAAluAHUAbABsAAALcwBoAGUAbABsAAATQQBEAEIAIAB9
>> "%~1" echo VOROhY32ZRr/ARNBAEQAQgAgAH1U5E4xWSWNKAABBSkAGv8BJSMAIABRAHUAZQBz
>> "%~1" echo AHQAIABBAEQAQgAgAOVdd1G+i25/B1n9TgETIwAgAGQAZQB2AGkAYwBlAD0AABUj
>> "%~1" echo ACAAYwByAGUAYQB0AGUAZAA9AAAneQB5AHkAeQAtAE0ATQAtAGQAZAAgAEgASAA6
>> "%~1" echo AG0AbQA6AHMAcwABEfJdG1L6Xr6Lbn8HWf1OGv8BEfuL1lMHWf1OPFAxWSWNGv8B
>> "%~1" echo E6FsCWd+YjBSB1n9Todl9k4a/wEDIwAAIXMAZQB0AHQAaQBuAGcAcwAgAGQAZQBs
>> "%~1" echo AGUAdABlACAAAA/yXc5OB1n9TmJgDVka/wEDOgAAA18AAANcAAAncQB1AGUAcwB0
>> "%~1" echo AF8AYQBkAGIAXwBzAGUAdAB0AGkAbgBnAHMAXwAACS4AYgBhAGsAAB9kAHUAbQBw
>> "%~1" echo AHMAeQBzACAAYgBhAHQAdABlAHIAeQAAC2wAZQB2AGUAbAAAF3QAZQBtAHAAZQBy
>> "%~1" echo AGEAdAB1AHIAZQAABzAALgAjAAAbYgBhAHQAdABlAHIAeQBTAHQAYQB0AHUAcwAA
>> "%~1" echo DXMAdABhAHQAdQBzAAAbYgBhAHQAdABlAHIAeQBIAGUAYQBsAHQAaAAADWgAZQBh
>> "%~1" echo AGwAdABoAAAXcABvAHcAZQByAFMAbwB1AHIAYwBlAAAbZAB1AG0AcABzAHkAcwAg
>> "%~1" echo AHAAbwB3AGUAcgAAGW0AVwBhAGsAZQBmAHUAbABuAGUAcwBzAAAPbQBTAHQAYQB5
>> "%~1" echo AE8AbgAAJW0AUAByAG8AeABpAG0AaQB0AHkAUABvAHMAaQB0AGkAdgBlAAAdbQBT
>> "%~1" echo AHQAYQB5AE8AbgBTAGUAdAB0AGkAbgBnAAA5bQBTAHQAYQB5AE8AbgBXAGgAaQBs
>> "%~1" echo AGUAUABsAHUAZwBnAGUAZABJAG4AUwBlAHQAdABpAG4AZwAAHXAAbwB3AGUAcgBT
>> "%~1" echo AGwAZQBlAHAATABpAG4AZQAAHVMAbABlAGUAcAAgAHQAaQBtAGUAbwB1AHQAOgAA
>> "%~1" echo K2MAbwBuAHQAcgBvAGwAbABlAHIATABlAGYAdABCAGEAdAB0AGUAcgB5AAAtYwBv
>> "%~1" echo AG4AdAByAG8AbABsAGUAcgBSAGkAZwBoAHQAQgBhAHQAdABlAHIAeQAAKWMAbwBu
>> "%~1" echo AHQAcgBvAGwAbABlAHIATABlAGYAdABTAHQAYQB0AHUAcwAAK2MAbwBuAHQAcgBv
>> "%~1" echo AGwAbABlAHIAUgBpAGcAaAB0AFMAdABhAHQAdQBzAAAdYwBvAG4AdAByAG8AbABs
>> "%~1" echo AGUAcgBIAGkAbgB0AAATKmf7i9ZTMFJLYsRnNXXPkQIwATFkAHUAbQBwAHMAeQBz
>> "%~1" echo ACAATwBWAFIAUgBlAG0AbwB0AGUAUwBlAHIAdgBpAGMAZQAAEUIAYQB0AHQAZQBy
>> "%~1" echo AHkAOgAAC1QAeQBwAGUAOgAACVQAeQBwAGUAAA9CAGEAdAB0AGUAcgB5AAANUwB0
>> "%~1" echo AGEAdAB1AHMAAAlMAGUAZgB0AAALUgBpAGcAaAB0AAAPcwB0AG8AcgBhAGcAZQAA
>> "%~1" echo DW0AZQBtAG8AcgB5AAAbZABmACAALQBoACAALwBzAGQAYwBhAHIAZAABFUYAaQBs
>> "%~1" echo AGUAcwB5AHMAdABlAG0AAAkgAPJdKHUgAAEjYwBhAHQAIAAvAHAAcgBvAGMALwBt
>> "%~1" echo AGUAbQBpAG4AZgBvAAATTQBlAG0AVABvAHQAYQBsADoAABtNAGUAbQBBAHYAYQBp
>> "%~1" echo AGwAYQBiAGwAZQA6AAAH71ModSAAAQ0gAC8AIAA7YKGLIAABE3YAZABQAGEAYwBr
>> "%~1" echo AGEAZwBlAAATdgBkAFYAZQByAHMAaQBvAG4AAC1WAGkAcgB0AHUAYQBsAEQAZQBz
>> "%~1" echo AGsAdABvAHAALgBBAG4AZAByAG8AaQBkAAATUABhAGMAawBhAGcAZQAgAFsAABl2
>> "%~1" echo AGUAcgBzAGkAbwBuAE4AYQBtAGUAPQAAHWQAaQBzAHAAbABhAHkAUwB1AG0AbQBh
>> "%~1" echo AHIAeQAAH2QAdQBtAHAAcwB5AHMAIABkAGkAcwBwAGwAYQB5AAAjRABpAHMAcABs
>> "%~1" echo AGEAeQBEAGUAdgBpAGMAZQBJAG4AZgBvAAAvKABcAGQAewAzACwANQB9AFwAcwAq
>> "%~1" echo AHgAXABzACoAXABkAHsAMwAsADUAfQApAAA3cgBlAG4AZABlAHIARgByAGEAbQBl
>> "%~1" echo AFIAYQB0AGUAXABzACsAKABbADAALQA5AC4AXQArACkAASVkAGUAbgBzAGkAdAB5
>> "%~1" echo AFwAcwArACgAWwAwAC0AOQBdACsAKQABL0QAZQB2AGkAYwBlAFAAcgBvAGQAdQBj
>> "%~1" echo AHQASQBuAGYAbwB7AG4AYQBtAGUAPQAABUgAegAAEWQAZQBuAHMAaQB0AHkAIAAA
>> "%~1" echo HXQAaABlAHIAbQBhAGwAUwB1AG0AbQBhAHIAeQAALWQAdQBtAHAAcwB5AHMAIAB0
>> "%~1" echo AGgAZQByAG0AYQBsAHMAZQByAHYAaQBjAGUAAB1UAGgAZQByAG0AYQBsACAAUwB0
>> "%~1" echo AGEAdAB1AHMAAENtAE4AYQBtAGUAPQBiAGEAdAB0AGUAcgB5ACwAXABzACoAbQBW
>> "%~1" echo AGEAbAB1AGUAPQAoAFsAMAAtADkALgBdACsAKQABPWIAYQB0AHQAZQByAHkAWwBe
>> "%~1" echo ADAALQA5AF0AKwAoAFsAMAAtADkAXQArAFwALgBbADAALQA5AF0AKwApAAEPcwB0
>> "%~1" echo AGEAdAB1AHMAIAAAFyAALwAgAGIAYQB0AHQAZQByAHkAIAAAA0MAAB1mAGEAYwB0
>> "%~1" echo AG8AcgB5AFMAdQBtAG0AYQByAHkAACtkAHUAbQBwAHMAeQBzACAAcwBlAG4AcwBv
>> "%~1" echo AHIAcwBlAHIAdgBpAGMAZQAAEUYAYQBjAHQAbwByAHkAIAAACWwAbwBjACAAABFz
>> "%~1" echo AHQAYQB0AGkAbwBuACAAABdhAGQAYgBfAGQAZQB2AGkAYwBlAHMAAAVpAGQAAA9n
>> "%~1" echo AGUAdABwAHIAbwBwAAAfcwBlAHQAdABpAG4AZwBzAF8AZwBsAG8AYgBhAGwAAClz
>> "%~1" echo AGUAdAB0AGkAbgBnAHMAIABsAGkAcwB0ACAAZwBsAG8AYgBhAGwAAB9zAGUAdAB0
>> "%~1" echo AGkAbgBnAHMAXwBzAHkAcwB0AGUAbQAAKXMAZQB0AHQAaQBuAGcAcwAgAGwAaQBz
>> "%~1" echo AHQAIABzAHkAcwB0AGUAbQAAH3MAZQB0AHQAaQBuAGcAcwBfAHMAZQBjAHUAcgBl
>> "%~1" echo AAApcwBlAHQAdABpAG4AZwBzACAAbABpAHMAdAAgAHMAZQBjAHUAcgBlAAAPYgBh
>> "%~1" echo AHQAdABlAHIAeQAAC3AAbwB3AGUAcgAAD2QAaQBzAHAAbABhAHkAABdkAHUAbQBw
>> "%~1" echo AHMAeQBzACAAdQBzAGIAAAl3AGkAZgBpAAAZZAB1AG0AcABzAHkAcwAgAHcAaQBm
>> "%~1" echo AGkAABljAG8AbgBuAGUAYwB0AGkAdgBpAHQAeQAAKWQAdQBtAHAAcwB5AHMAIABj
>> "%~1" echo AG8AbgBuAGUAYwB0AGkAdgBpAHQAeQAAE2IAbAB1AGUAdABvAG8AdABoAAAzZAB1
>> "%~1" echo AG0AcABzAHkAcwAgAGIAbAB1AGUAdABvAG8AdABoAF8AbQBhAG4AYQBnAGUAcgAA
>> "%~1" echo DWMAYQBtAGUAcgBhAAApZAB1AG0AcABzAHkAcwAgAG0AZQBkAGkAYQAuAGMAYQBt
>> "%~1" echo AGUAcgBhAAAbcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAAD3QAaABlAHIAbQBh
>> "%~1" echo AGwAAAtpAG4AcAB1AHQAABtkAHUAbQBwAHMAeQBzACAAaQBuAHAAdQB0AAARcABh
>> "%~1" echo AGMAawBhAGcAZQBzAAAtcABtACAAbABpAHMAdAAgAHAAYQBjAGsAYQBnAGUAcwAg
>> "%~1" echo AC0AZgAgAC0AaQABEWYAZQBhAHQAdQByAGUAcwAAIXAAbQAgAGwAaQBzAHQAIABm
>> "%~1" echo AGUAYQB0AHUAcgBlAHMAABNsAGkAYgByAGEAcgBpAGUAcwAANWMAbQBkACAAcABh
>> "%~1" echo AGMAawBhAGcAZQAgAGwAaQBzAHQAIABsAGkAYgByAGEAcgBpAGUAcwAABWQAZgAA
>> "%~1" echo J2QAZgAgAC0AaAAgAC8AZABhAHQAYQAgAC8AcwBkAGMAYQByAGQAAQ9tAGUAbQBp
>> "%~1" echo AG4AZgBvAAAPYwBwAHUAaQBuAGYAbwAAI2MAYQB0ACAALwBwAHIAbwBjAC8AYwBw
>> "%~1" echo AHUAaQBuAGYAbwAAC3UAbgBhAG0AZQAAEXUAbgBhAG0AZQAgAC0AYQABD2kAcABf
>> "%~1" echo AGEAZABkAHIAAA9pAHAAIABhAGQAZAByAAARaQBwAF8AcgBvAHUAdABlAAARaQBw
>> "%~1" echo ACAAcgBvAHUAdABlAAAddgBpAHIAdAB1AGEAbABkAGUAcwBrAHQAbwBwAABNZAB1
>> "%~1" echo AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBnAGUAIABWAGkAcgB0AHUAYQBsAEQAZQBz
>> "%~1" echo AGsAdABvAHAALgBBAG4AZAByAG8AaQBkAAAfbwBjAHUAbAB1AHMAXwBwAGEAYwBr
>> "%~1" echo AGEAZwBlAHMAADVkAHUAbQBwAHMAeQBzACAAcABhAGMAawBhAGcAZQAgAGMAbwBt
>> "%~1" echo AC4AbwBjAHUAbAB1AHMAACdsAG8AZwBjAGEAdABfAHQAYQBpAGwAXwBwAHIAaQB2
>> "%~1" echo AGEAdABlAAAjbABvAGcAYwBhAHQAIAAtAGQAIAAtAHQAIAAzADAAMAAwAAEHIACF
>> "%~1" echo jfZlAQkgADFZJY0a/wEPIADXU1CWFmLgZZOP+lEBD2MAcgBlAGEAdABlAGQAAA9w
>> "%~1" echo AHIAbwBkAHUAYwB0AAAXZgBpAG4AZwBlAHIAcAByAGkAbgB0AAApcgBvAC4AYgB1
>> "%~1" echo AGkAbABkAC4AZgBpAG4AZwBlAHIAcAByAGkAbgB0AAANawBlAHIAbgBlAGwAAAMl
>> "%~1" echo AAATcAByAG8AeABpAG0AaQB0AHkAAAdjAHAAdQAAC3AAYQBuAGUAbAAAI0QAZQB2
>> "%~1" echo AGkAYwBlAFAAcgBvAGQAdQBjAHQASQBuAGYAbwAAD2YAYQBjAHQAbwByAHkAABtm
>> "%~1" echo AGEAYwB0AG8AcgB5AEQAZQB2AGkAYwBlAAAZZgBhAGMAdABvAHIAeQBCAHUAaQBs
>> "%~1" echo AGQAABdmAGEAYwB0AG8AcgB5AFQAaQBtAGUAAB9mAGEAYwB0AG8AcgB5AEwAbwBj
>> "%~1" echo AGEAdABpAG8AbgAAHWYAYQBjAHQAbwByAHkAUwB0AGEAdABpAG8AbgAAJWYAYQBj
>> "%~1" echo AHQAbwByAHkAUwB0AGEAdABpAG8AbgBUAHkAcABlAAAZcwB0AGEAdABpAG8AbgBf
>> "%~1" echo AHQAeQBwAGUAABdmAGEAYwB0AG8AcgB5AFQAZQBzAHQAABdjAGEAbABfAHQAZQBz
>> "%~1" echo AHQAXwBpAGQAAB9mAGEAYwB0AG8AcgB5AE8AcABlAHIAYQB0AG8AcgAAF28AcABl
>> "%~1" echo AHIAYQB0AG8AcgBfAGkAZAAAJWYAYQBjAHQAbwByAHkAQwBhAGwAaQBiAHIAYQB0
>> "%~1" echo AGkAbwBuAAAhYwBhAGwAaQBiAHIAYQB0AGkAbwBuAF8AdAB5AHAAZQAAI28AbgBs
>> "%~1" echo AGkAbgBlAEMAYQBsAGkAYgByAGEAdABpAG8AbgAAL3YAZQBnAGEAXwBvAG4AbABp
>> "%~1" echo AG4AZQBfAGMAYQBsAGkAYgByAGEAdABpAG8AbgAAN8BoS20wUiAAdgBlAGcAYQBf
>> "%~1" echo AG8AbgBsAGkAbgBlAF8AYwBhAGwAaQBiAHIAYQB0AGkAbwBuAAERZgBlAGEAdAB1
>> "%~1" echo AHIAZQA6AAAFdgBkAAAxUQB1AGUAcwB0ACAAQQBEAEIAIAC+iwdZoVuhi6ViSlQg
>> "%~1" echo AC0AIADBeQlnjFt0ZUhyATFRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mhW6GLpWJK
>> "%~1" echo VCAALQAgAAZSq06JW2hRSHIBGVAAUgBJAFYAQQBUAEUAIABGAFUATABMAAAVUwBI
>> "%~1" echo AEEAUgBFAC0AUwBBAEYARQABC1EAQQBEAEIALQABH3kAeQB5AHkATQBNAGQAZAAt
>> "%~1" echo AEgASABtAG0AcwBzAAGBETwAIQBkAG8AYwB0AHkAcABlACAAaAB0AG0AbAA+ADwA
>> "%~1" echo aAB0AG0AbAAgAGwAYQBuAGcAPQAiAHoAaAAtAEMATgAiAD4APABoAGUAYQBkAD4A
>> "%~1" echo PABtAGUAdABhACAAYwBoAGEAcgBzAGUAdAA9ACIAdQB0AGYALQA4ACIAPgA8AG0A
>> "%~1" echo ZQB0AGEAIABuAGEAbQBlAD0AIgB2AGkAZQB3AHAAbwByAHQAIgAgAGMAbwBuAHQA
>> "%~1" echo ZQBuAHQAPQAiAHcAaQBkAHQAaAA9AGQAZQB2AGkAYwBlAC0AdwBpAGQAdABoACwA
>> "%~1" echo aQBuAGkAdABpAGEAbAAtAHMAYwBhAGwAZQA9ADEAIgA+ADwAdABpAHQAbABlAD4A
>> "%~1" echo ARE8AC8AdABpAHQAbABlAD4AAA88AHMAdAB5AGwAZQA+AACNszoAcgBvAG8AdAB7
>> "%~1" echo AC0ALQBwAGEAZwBlADoAIwBlAGUAZgAxAGYANQA7AC0ALQBwAGEAcABlAHIAOgAj
>> "%~1" echo AGYAZgBmADsALQAtAGkAbgBrADoAIwAxADgAMgAwADMAMwA7AC0ALQBtAHUAdABl
>> "%~1" echo AGQAOgAjADYANgA3ADAAOAA1ADsALQAtAGwAaQBuAGUAOgAjAGQAOABlADAAZQBi
>> "%~1" echo ADsALQAtAGwAaQBuAGUAMgA6ACMAZQBkAGYAMQBmADYAOwAtAC0AcwBvAGYAdAA6
>> "%~1" echo ACMAZgA3AGYAOQBmAGMAOwAtAC0AYQBjAGMAZQBuAHQAOgAjADEAZAA0AGUAZAA4
>> "%~1" echo ADsALQAtAGEAYwBjAGUAbgB0ADIAOgAjADAAZgAxADcAMgBhADsALQAtAG8AawA6
>> "%~1" echo ACMAMQAxADgANAA0ADcAOwAtAC0AdwBhAHIAbgA6ACMAOQBhADUAYgAwADAAOwAt
>> "%~1" echo AC0AcwBoAGEAZABvAHcAOgAwACAAMQA4AHAAeAAgADQAOABwAHgAIAByAGcAYgBh
>> "%~1" echo ACgAMQA1ACwAMgAzACwANAAyACwALgAxADMAKQB9ACoAewBiAG8AeAAtAHMAaQB6
>> "%~1" echo AGkAbgBnADoAYgBvAHIAZABlAHIALQBiAG8AeAB9AGgAdABtAGwALABiAG8AZAB5
>> "%~1" echo AHsAbQBhAHIAZwBpAG4AOgAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQBy
>> "%~1" echo ACgALQAtAHAAYQBnAGUAKQA7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAGkAbgBr
>> "%~1" echo ACkAOwBmAG8AbgB0ADoAMQA0AHAAeAAvADEALgA1ADIAIAAiAFMAZQBnAG8AZQAg
>> "%~1" echo AFUASQAiACwAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFkAYQBIAGUAaQAiACwAQQBy
>> "%~1" echo AGkAYQBsACwAcwBhAG4AcwAtAHMAZQByAGkAZgA7AGwAZQB0AHQAZQByAC0AcwBw
>> "%~1" echo AGEAYwBpAG4AZwA6ADAAfQAuAHMAaABlAGUAdAB7AHcAaQBkAHQAaAA6AG0AaQBu
>> "%~1" echo ACgAMQAxADIAMABwAHgALABjAGEAbABjACgAMQAwADAAJQAgAC0AIAA0ADAAcAB4
>> "%~1" echo ACkAKQA7AG0AYQByAGcAaQBuADoAMwAwAHAAeAAgAGEAdQB0AG8AOwBiAGEAYwBr
>> "%~1" echo AGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0AcABhAHAAZQByACkAOwBiAG8AcgBk
>> "%~1" echo AGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBkAGYAZQA2AGYAMAA7AGIAbwB4
>> "%~1" echo AC0AcwBoAGEAZABvAHcAOgB2AGEAcgAoAC0ALQBzAGgAYQBkAG8AdwApAH0ALgBw
>> "%~1" echo AGEAZAB7AHAAYQBkAGQAaQBuAGcAOgAzADgAcAB4ACAANAA0AHAAeAB9AC4AYQBj
>> "%~1" echo AHQAaQBvAG4AcwB7AHAAbwBzAGkAdABpAG8AbgA6AHMAdABpAGMAawB5ADsAdABv
>> "%~1" echo AHAAOgAwADsAegAtAGkAbgBkAGUAeAA6ADMAOwBkAGkAcwBwAGwAYQB5ADoAZgBs
>> "%~1" echo AGUAeAA7AGoAdQBzAHQAaQBmAHkALQBjAG8AbgB0AGUAbgB0ADoAZgBsAGUAeAAt
>> "%~1" echo AGUAbgBkADsAZwBhAHAAOgA4AHAAeAA7AHcAaQBkAHQAaAA6AG0AaQBuACgAMQAx
>> "%~1" echo ADIAMABwAHgALABjAGEAbABjACgAMQAwADAAJQAgAC0AIAA0ADAAcAB4ACkAKQA7
>> "%~1" echo AG0AYQByAGcAaQBuADoAMQA4AHAAeAAgAGEAdQB0AG8AIAAtADEANgBwAHgAfQAu
>> "%~1" echo AGIAdABuAHsAYgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAYwBi
>> "%~1" echo AGQANQBlADEAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgA7AGMAbwBs
>> "%~1" echo AG8AcgA6ACMAMABmADEANwAyAGEAOwBiAG8AcgBkAGUAcgAtAHIAYQBkAGkAdQBz
>> "%~1" echo ADoANgBwAHgAOwBwAGEAZABkAGkAbgBnADoAOABwAHgAIAAxADIAcAB4ADsAZgBv
>> "%~1" echo AG4AdAAtAHcAZQBpAGcAaAB0ADoAOAAwADAAOwBjAHUAcgBzAG8AcgA6AHAAbwBp
>> "%~1" echo AG4AdABlAHIAfQAuAGIAdABuAC4AcAByAGkAbQBhAHIAeQB7AGIAYQBjAGsAZwBy
>> "%~1" echo AG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAApADsAYgBvAHIAZABl
>> "%~1" echo AHIALQBjAG8AbABvAHIAOgB2AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAApADsAYwBv
>> "%~1" echo AGwAbwByADoAIwBmAGYAZgB9AC4AZABvAGMALQBoAGUAYQBkAHsAZABpAHMAcABs
>> "%~1" echo AGEAeQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBv
>> "%~1" echo AGwAdQBtAG4AcwA6ADEAZgByACAAMwA0ADAAcAB4ADsAZwBhAHAAOgAyADgAcAB4
>> "%~1" echo ADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADMAcAB4ACAAcwBvAGwAaQBk
>> "%~1" echo ACAAdgBhAHIAKAAtAC0AYQBjAGMAZQBuAHQAMgApADsAcABhAGQAZABpAG4AZwAt
>> "%~1" echo AGIAbwB0AHQAbwBtADoAMgA0AHAAeAB9AC4AawBpAGMAawBlAHIAewBkAGkAcwBw
>> "%~1" echo AGwAYQB5ADoAaQBuAGwAaQBuAGUALQBiAGwAbwBjAGsAOwBjAG8AbABvAHIAOgB2
>> "%~1" echo AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAApADsAZgBvAG4AdAAtAHMAaQB6AGUAOgAx
>> "%~1" echo ADIAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOQAwADAAOwBsAGUAdAB0
>> "%~1" echo AGUAcgAtAHMAcABhAGMAaQBuAGcAOgAuADAAOABlAG0AOwB0AGUAeAB0AC0AdABy
>> "%~1" echo AGEAbgBzAGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AG0AYQByAGcAaQBu
>> "%~1" echo AC0AYgBvAHQAdABvAG0AOgAxADAAcAB4AH0AaAAxAHsAZgBvAG4AdAAtAHMAaQB6
>> "%~1" echo AGUAOgAzADIAcAB4ADsAbABpAG4AZQAtAGgAZQBpAGcAaAB0ADoAMQAuADEAMgA7
>> "%~1" echo AG0AYQByAGcAaQBuADoAMAAgADAAIAAxADAAcAB4ADsAZgBvAG4AdAAtAHcAZQBp
>> "%~1" echo AGcAaAB0ADoAOQAwADAAOwBjAG8AbABvAHIAOgAjADAAZgAxADcAMgBhAH0ALgBz
>> "%~1" echo AHUAYgB7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAG0AdQB0AGUAZAApADsAbQBh
>> "%~1" echo AHgALQB3AGkAZAB0AGgAOgA2ADgAMABwAHgAOwBtAGEAcgBnAGkAbgA6ADAAfQAu
>> "%~1" echo AG0AZQB0AGEAewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBh
>> "%~1" echo AHIAKAAtAC0AbABpAG4AZQApADsAYQBsAGkAZwBuAC0AcwBlAGwAZgA6AHMAdABh
>> "%~1" echo AHIAdAA7AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9AC4AbQBlAHQAYQAtAHIAbwB3
>> "%~1" echo AHsAZABpAHMAcABsAGEAeQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABs
>> "%~1" echo AGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEAMQA4AHAAeAAgAG0AaQBuAG0AYQB4
>> "%~1" echo ACgAMAAsADEAZgByACkAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBw
>> "%~1" echo AHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AG0AaQBu
>> "%~1" echo AC0AaABlAGkAZwBoAHQAOgAzADgAcAB4AH0ALgBtAGUAdABhAC0AcgBvAHcAOgBs
>> "%~1" echo AGEAcwB0AC0AYwBoAGkAbABkAHsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6
>> "%~1" echo ADAAfQAuAG0AZQB0AGEALQByAG8AdwAgAHMAcABhAG4AewBiAGEAYwBrAGcAcgBv
>> "%~1" echo AHUAbgBkADoAdgBhAHIAKAAtAC0AcwBvAGYAdAApADsAYwBvAGwAbwByADoAdgBh
>> "%~1" echo AHIAKAAtAC0AbQB1AHQAZQBkACkAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4
>> "%~1" echo ADAAMAA7AHAAYQBkAGQAaQBuAGcAOgA5AHAAeAAgADEAMgBwAHgAOwBiAG8AcgBk
>> "%~1" echo AGUAcgAtAHIAaQBnAGgAdAA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAt
>> "%~1" echo AC0AbABpAG4AZQAyACkAfQAuAG0AZQB0AGEALQByAG8AdwAgAGIAewBwAGEAZABk
>> "%~1" echo AGkAbgBnADoAOQBwAHgAIAAxADIAcAB4ADsAbQBpAG4ALQB3AGkAZAB0AGgAOgAw
>> "%~1" echo ADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcAaABlAHIAZQA7
>> "%~1" echo AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8AcgBkAH0ALgBz
>> "%~1" echo AHQAYQBtAHAAewBkAGkAcwBwAGwAYQB5ADoAaQBuAGwAaQBuAGUALQBiAGwAbwBj
>> "%~1" echo AGsAOwBiAG8AcgBkAGUAcgA6ADIAcAB4ACAAcwBvAGwAaQBkACAAARd2AGEAcgAo
>> "%~1" echo AC0ALQB3AGEAcgBuACkAARN2AGEAcgAoAC0ALQBvAGsAKQABDzsAYwBvAGwAbwBy
>> "%~1" echo ADoAAJsHOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAA7AHAAYQBkAGQA
>> "%~1" echo aQBuAGcAOgA0AHAAeAAgADgAcAB4ADsAYgBvAHIAZABlAHIALQByAGEAZABpAHUA
>> "%~1" echo cwA6ADQAcAB4ADsAdAByAGEAbgBzAGYAbwByAG0AOgByAG8AdABhAHQAZQAoAC0A
>> "%~1" echo MQBkAGUAZwApAH0ALgBwAGEAcgB0AHkALQBnAHIAaQBkAHsAZABpAHMAcABsAGEA
>> "%~1" echo eQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwA
>> "%~1" echo dQBtAG4AcwA6ADEAZgByACAAMQBmAHIAOwBnAGEAcAA6ADEAOABwAHgAOwBtAGEA
>> "%~1" echo cgBnAGkAbgA6ADIANgBwAHgAIAAwAH0ALgBiAG8AeAB7AGIAbwByAGQAZQByADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBiAGEA
>> "%~1" echo YwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgA7AG0AaQBuAC0AdwBpAGQAdABoADoA
>> "%~1" echo MAB9AC4AYgBvAHgAIABoADIALAAuAHMAZQBjAHQAaQBvAG4AIABoADIAewBmAG8A
>> "%~1" echo bgB0AC0AcwBpAHoAZQA6ADEAMwBwAHgAOwB0AGUAeAB0AC0AdAByAGEAbgBzAGYA
>> "%~1" echo bwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AGwAZQB0AHQAZQByAC0AcwBwAGEA
>> "%~1" echo YwBpAG4AZwA6AC4AMAA4AGUAbQA7AGMAbwBsAG8AcgA6ACMAMwA0ADQAMAA1ADQA
>> "%~1" echo OwBtAGEAcgBnAGkAbgA6ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIA
>> "%~1" echo KAAtAC0AcwBvAGYAdAApADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADEA
>> "%~1" echo cAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQApADsAcABhAGQA
>> "%~1" echo ZABpAG4AZwA6ADEAMABwAHgAIAAxADIAcAB4AH0ALgBiAG8AeAAtAGIAbwBkAHkA
>> "%~1" echo ewBwAGEAZABkAGkAbgBnADoAMQAzAHAAeAAgADEANABwAHgAfQAuAGIAaQBnAHsA
>> "%~1" echo ZgBvAG4AdAAtAHMAaQB6AGUAOgAyADIAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcA
>> "%~1" echo aAB0ADoAOQAwADAAOwBtAGEAcgBnAGkAbgAtAGIAbwB0AHQAbwBtADoANgBwAHgA
>> "%~1" echo fQAuAG0AdQB0AGUAZAB7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAG0AdQB0AGUA
>> "%~1" echo ZAApAH0ALgBjAGgAaQBwAHMAewBkAGkAcwBwAGwAYQB5ADoAZgBsAGUAeAA7AGYA
>> "%~1" echo bABlAHgALQB3AHIAYQBwADoAdwByAGEAcAA7AGcAYQBwADoANwBwAHgAOwBtAGEA
>> "%~1" echo cgBnAGkAbgAtAHQAbwBwADoAMQAyAHAAeAB9AC4AYwBoAGkAcAB7AGIAbwByAGQA
>> "%~1" echo ZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkA
>> "%~1" echo OwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0AcwBvAGYAdAApADsA
>> "%~1" echo YgBvAHIAZABlAHIALQByAGEAZABpAHUAcwA6ADkAOQA5AHAAeAA7AHAAYQBkAGQA
>> "%~1" echo aQBuAGcAOgA1AHAAeAAgADkAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoA
>> "%~1" echo OAAwADAAfQAuAHMAdQBtAG0AYQByAHkAewBkAGkAcwBwAGwAYQB5ADoAZwByAGkA
>> "%~1" echo ZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoA
>> "%~1" echo cgBlAHAAZQBhAHQAKAA0ACwAbQBpAG4AbQBhAHgAKAAwACwAMQBmAHIAKQApADsA
>> "%~1" echo YgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwA
>> "%~1" echo aQBuAGUAKQA7AG0AYQByAGcAaQBuADoAMgAwAHAAeAAgADAAIAAyADQAcAB4AH0A
>> "%~1" echo LgBzAHUAbQAtAGMAZQBsAGwAewBwAGEAZABkAGkAbgBnADoAMQAzAHAAeAAgADEA
>> "%~1" echo NABwAHgAOwBiAG8AcgBkAGUAcgAtAHIAaQBnAGgAdAA6ADEAcAB4ACAAcwBvAGwA
>> "%~1" echo aQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQAyACkAOwBtAGkAbgAtAHcAaQBkAHQA
>> "%~1" echo aAA6ADAAfQAuAHMAdQBtAC0AYwBlAGwAbAA6AGwAYQBzAHQALQBjAGgAaQBsAGQA
>> "%~1" echo ewBiAG8AcgBkAGUAcgAtAHIAaQBnAGgAdAA6ADAAfQAuAHMAdQBtAC0AYwBlAGwA
>> "%~1" echo bAAgAHMAcABhAG4AewBkAGkAcwBwAGwAYQB5ADoAYgBsAG8AYwBrADsAYwBvAGwA
>> "%~1" echo bwByADoAdgBhAHIAKAAtAC0AbQB1AHQAZQBkACkAOwBmAG8AbgB0AC0AcwBpAHoA
>> "%~1" echo ZQA6ADEAMgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAA7AHQA
>> "%~1" echo ZQB4AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlAH0A
>> "%~1" echo LgBzAHUAbQAtAGMAZQBsAGwAIABiAHsAZABpAHMAcABsAGEAeQA6AGIAbABvAGMA
>> "%~1" echo awA7AGYAbwBuAHQALQBzAGkAegBlADoAMQA4AHAAeAA7AG0AYQByAGcAaQBuAC0A
>> "%~1" echo dABvAHAAOgA1AHAAeAA7AG8AdgBlAHIAZgBsAG8AdwAtAHcAcgBhAHAAOgBhAG4A
>> "%~1" echo eQB3AGgAZQByAGUAOwB3AG8AcgBkAC0AYgByAGUAYQBrADoAYgByAGUAYQBrAC0A
>> "%~1" echo dwBvAHIAZAB9AC4AcwBlAGMAdABpAG8AbgB7AG0AYQByAGcAaQBuAC0AdABvAHAA
>> "%~1" echo OgAyADIAcAB4AH0ALgBhAHUAZABpAHQALQB0AGEAYgBsAGUAewB3AGkAZAB0AGgA
>> "%~1" echo OgAxADAAMAAlADsAYgBvAHIAZABlAHIALQBjAG8AbABsAGEAcABzAGUAOgBjAG8A
>> "%~1" echo bABsAGEAcABzAGUAOwBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAA
>> "%~1" echo dgBhAHIAKAAtAC0AbABpAG4AZQApADsAdABhAGIAbABlAC0AbABhAHkAbwB1AHQA
>> "%~1" echo OgBmAGkAeABlAGQAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAaAB7AGIA
>> "%~1" echo YQBjAGsAZwByAG8AdQBuAGQAOgAjAGYAMgBmADUAZgA5ADsAYwBvAGwAbwByADoA
>> "%~1" echo IwAzADQANAAwADUANAA7AHQAZQB4AHQALQBhAGwAaQBnAG4AOgBsAGUAZgB0ADsA
>> "%~1" echo ZgBvAG4AdAAtAHMAaQB6AGUAOgAxADIAcAB4ADsAdABlAHgAdAAtAHQAcgBhAG4A
>> "%~1" echo cwBmAG8AcgBtADoAdQBwAHAAZQByAGMAYQBzAGUAOwBsAGUAdAB0AGUAcgAtAHMA
>> "%~1" echo cABhAGMAaQBuAGcAOgAuADAANgBlAG0AOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQA
>> "%~1" echo bwBtADoAMgBwAHgAIABzAG8AbABpAGQAIAAjADEAMQAxADgAMgA3ADsAcABhAGQA
>> "%~1" echo ZABpAG4AZwA6ADEAMABwAHgAIAAxADIAcAB4AH0ALgBhAHUAZABpAHQALQB0AGEA
>> "%~1" echo YgBsAGUAIAB0AGQAewBiAG8AcgBkAGUAcgAtAHQAbwBwADoAMQBwAHgAIABzAG8A
>> "%~1" echo bABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AHAAYQBkAGQAaQBuAGcA
>> "%~1" echo OgAxADAAcAB4ACAAMQAyAHAAeAA7AHYAZQByAHQAaQBjAGEAbAAtAGEAbABpAGcA
>> "%~1" echo bgA6AHQAbwBwADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcA
>> "%~1" echo aABlAHIAZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8A
>> "%~1" echo cgBkAH0ALgBhAHUAZABpAHQALQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMA
>> "%~1" echo aABpAGwAZAAoADEAKQB7AHcAaQBkAHQAaAA6ADIAMgAlADsAYwBvAGwAbwByADoA
>> "%~1" echo IwA0ADcANQA0ADYANwA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwAH0A
>> "%~1" echo LgBhAHUAZABpAHQALQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwA
>> "%~1" echo ZAAoADIAKQB7AHcAaQBkAHQAaAA6ADQANAAlADsAZgBvAG4AdAAtAHcAZQBpAGcA
>> "%~1" echo aAB0ADoAOAAwADAAOwBjAG8AbABvAHIAOgAjADEAMAAxADgAMgA4AH0ALgBhAHUA
>> "%~1" echo ZABpAHQALQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwAZAAoADMA
>> "%~1" echo KQB7AHcAaQBkAHQAaAA6ADMANAAlADsAYwBvAGwAbwByADoAIwA2ADYANwAwADgA
>> "%~1" echo NQB9AC4AbgBvAHQAZQB7AGIAbwByAGQAZQByAC0AbABlAGYAdAA6ADQAcAB4ACAA
>> "%~1" echo cwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AdwBhAHIAbgApADsAYgBhAGMAawBnAHIA
>> "%~1" echo bwB1AG4AZAA6ACMAZgBmAGYAOABlAGIAOwBiAG8AcgBkAGUAcgAtAHQAbwBwADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAAjAGYAMwBkADEAOQBjADsAYgBvAHIAZABlAHIA
>> "%~1" echo LQByAGkAZwBoAHQAOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAZgAzAGQAMQA5AGMA
>> "%~1" echo OwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABzAG8AbABpAGQA
>> "%~1" echo IAAjAGYAMwBkADEAOQBjADsAcABhAGQAZABpAG4AZwA6ADEAMwBwAHgAIAAxADQA
>> "%~1" echo cAB4ADsAbQBhAHIAZwBpAG4ALQB0AG8AcAA6ADEAOABwAHgAfQAuAHIAYQB3ACAA
>> "%~1" echo ZABlAHQAYQBpAGwAcwB7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQA
>> "%~1" echo IAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBtAGEAcgBnAGkAbgA6ADEAMABwAHgA
>> "%~1" echo IAAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6ACMAZgBmAGYAfQAuAHIAYQB3ACAA
>> "%~1" echo cwB1AG0AbQBhAHIAeQB7AGMAdQByAHMAbwByADoAcABvAGkAbgB0AGUAcgA7AGIA
>> "%~1" echo YQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBwAGEA
>> "%~1" echo ZABkAGkAbgBnADoAMQAwAHAAeAAgADEAMgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkA
>> "%~1" echo ZwBoAHQAOgA5ADAAMAB9AC4AcgBhAHcAIABwAHIAZQB7AG0AYQByAGcAaQBuADoA
>> "%~1" echo MAA7AG0AYQB4AC0AaABlAGkAZwBoAHQAOgA0ADIAMABwAHgAOwBvAHYAZQByAGYA
>> "%~1" echo bABvAHcAOgBhAHUAdABvADsAdwBoAGkAdABlAC0AcwBwAGEAYwBlADoAcAByAGUA
>> "%~1" echo LQB3AHIAYQBwADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcA
>> "%~1" echo aABlAHIAZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8A
>> "%~1" echo cgBkADsAYwBvAGwAbwByADoAIwA0ADcANQA0ADYANwA7AHAAYQBkAGQAaQBuAGcA
>> "%~1" echo OgAxADIAcAB4ADsAZgBvAG4AdAA6ADEAMgBwAHgALwAxAC4ANQAgAEMAbwBuAHMA
>> "%~1" echo bwBsAGEAcwAsACIATQBpAGMAcgBvAHMAbwBmAHQAIABZAGEASABlAGkAIgAsAG0A
>> "%~1" echo bwBuAG8AcwBwAGEAYwBlAH0ALgBmAG8AbwB0AHsAZABpAHMAcABsAGEAeQA6AGcA
>> "%~1" echo cgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4A
>> "%~1" echo cwA6ADEAZgByACAAYQB1AHQAbwA7AGcAYQBwADoAMgAwAHAAeAA7AGEAbABpAGcA
>> "%~1" echo bgAtAGkAdABlAG0AcwA6AGUAbgBkADsAbQBhAHIAZwBpAG4ALQB0AG8AcAA6ADIA
>> "%~1" echo OABwAHgAOwBiAG8AcgBkAGUAcgAtAHQAbwBwADoAMgBwAHgAIABzAG8AbABpAGQA
>> "%~1" echo IAAjADEAMQAxADgAMgA3ADsAcABhAGQAZABpAG4AZwAtAHQAbwBwADoAMQA2AHAA
>> "%~1" echo eAB9AC4AZgBvAG8AdAAgAGIAewBmAG8AbgB0AC0AcwBpAHoAZQA6ADEAMgBwAHgA
>> "%~1" echo OwB0AGUAeAB0AC0AdAByAGEAbgBzAGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMA
>> "%~1" echo ZQA7AGwAZQB0AHQAZQByAC0AcwBwAGEAYwBpAG4AZwA6AC4AMAA4AGUAbQB9AC4A
>> "%~1" echo dABvAHQAYQBsAHsAbQBpAG4ALQB3AGkAZAB0AGgAOgAyADUAMABwAHgAOwBiAG8A
>> "%~1" echo cgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4A
>> "%~1" echo ZQApAH0ALgB0AG8AdABhAGwAIABkAGkAdgB7AGQAaQBzAHAAbABhAHkAOgBnAHIA
>> "%~1" echo aQBkADsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMA
>> "%~1" echo OgAxAGYAcgAgAGEAdQB0AG8AOwBwAGEAZABkAGkAbgBnADoAOQBwAHgAIAAxADIA
>> "%~1" echo cAB4ADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwA
>> "%~1" echo aQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQAyACkAfQAuAHQAbwB0AGEAbAAgAGQA
>> "%~1" echo aQB2ADoAbABhAHMAdAAtAGMAaABpAGwAZAB7AGIAbwByAGQAZQByAC0AYgBvAHQA
>> "%~1" echo dABvAG0AOgAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAtAHMA
>> "%~1" echo bwBmAHQAKQA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwAH0AQABtAGUA
>> "%~1" echo ZABpAGEAKABtAGEAeAAtAHcAaQBkAHQAaAA6ADgANgAwAHAAeAApAHsALgBkAG8A
>> "%~1" echo YwAtAGgAZQBhAGQALAAuAHAAYQByAHQAeQAtAGcAcgBpAGQALAAuAHMAdQBtAG0A
>> "%~1" echo YQByAHkAewBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4A
>> "%~1" echo cwA6ADEAZgByAH0ALgBwAGEAZAB7AHAAYQBkAGQAaQBuAGcAOgAyADQAcAB4ACAA
>> "%~1" echo MQA4AHAAeAB9AC4AcwBoAGUAZQB0ACwALgBhAGMAdABpAG8AbgBzAHsAdwBpAGQA
>> "%~1" echo dABoADoAYwBhAGwAYwAoADEAMAAwACUAIAAtACAAMQA4AHAAeAApAH0ALgBzAHUA
>> "%~1" echo bQBtAGEAcgB5AHsAZABpAHMAcABsAGEAeQA6AGIAbABvAGMAawB9AC4AcwB1AG0A
>> "%~1" echo LQBjAGUAbABsAHsAYgBvAHIAZABlAHIALQByAGkAZwBoAHQAOgAwADsAYgBvAHIA
>> "%~1" echo ZABlAHIALQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIA
>> "%~1" echo KAAtAC0AbABpAG4AZQAyACkAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQB7AHQA
>> "%~1" echo YQBiAGwAZQAtAGwAYQB5AG8AdQB0ADoAYQB1AHQAbwB9AC4AYQB1AGQAaQB0AC0A
>> "%~1" echo dABhAGIAbABlACAAdABoADoAbgB0AGgALQBjAGgAaQBsAGQAKAAzACkALAAuAGEA
>> "%~1" echo dQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkAbABkACgA
>> "%~1" echo MwApAHsAZABpAHMAcABsAGEAeQA6AG4AbwBuAGUAfQAuAGYAbwBvAHQAewBnAHIA
>> "%~1" echo aQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEAZgByAH0A
>> "%~1" echo LgB0AG8AdABhAGwAewBtAGkAbgAtAHcAaQBkAHQAaAA6ADAAfQB9AEAAbQBlAGQA
>> "%~1" echo aQBhACgAbQBhAHgALQB3AGkAZAB0AGgAOgA1ADIAMABwAHgAKQB7AC4AbQBlAHQA
>> "%~1" echo YQAtAHIAbwB3AHsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUA
>> "%~1" echo bQBuAHMAOgAxADAANQBwAHgAIABtAGkAbgBtAGEAeAAoADAALAAxAGYAcgApAH0A
>> "%~1" echo aAAxAHsAZgBvAG4AdAAtAHMAaQB6AGUAOgAyADgAcAB4AH0ALgBhAGMAdABpAG8A
>> "%~1" echo bgBzAHsAagB1AHMAdABpAGYAeQAtAGMAbwBuAHQAZQBuAHQAOgBmAGwAZQB4AC0A
>> "%~1" echo cwB0AGEAcgB0ADsAbwB2AGUAcgBmAGwAbwB3ADoAYQB1AHQAbwB9AH0AQABtAGUA
>> "%~1" echo ZABpAGEAIABwAHIAaQBuAHQAewBiAG8AZAB5AHsAYgBhAGMAawBnAHIAbwB1AG4A
>> "%~1" echo ZAA6ACMAZgBmAGYAfQAuAGEAYwB0AGkAbwBuAHMAewBkAGkAcwBwAGwAYQB5ADoA
>> "%~1" echo bgBvAG4AZQB9AC4AcwBoAGUAZQB0AHsAdwBpAGQAdABoADoAYQB1AHQAbwA7AG0A
>> "%~1" echo YQByAGcAaQBuADoAMAA7AGIAbwByAGQAZQByADoAMAA7AGIAbwB4AC0AcwBoAGEA
>> "%~1" echo ZABvAHcAOgBuAG8AbgBlAH0ALgBwAGEAZAB7AHAAYQBkAGQAaQBuAGcAOgAwAH0A
>> "%~1" echo LgByAGEAdwAgAHAAcgBlAHsAbQBhAHgALQBoAGUAaQBnAGgAdAA6AG4AbwBuAGUA
>> "%~1" echo fQAuAGIAbwB4ACwALgBhAHUAZABpAHQALQB0AGEAYgBsAGUALAAuAHIAYQB3ACAA
>> "%~1" echo ZABlAHQAYQBpAGwAcwB7AGIAcgBlAGEAawAtAGkAbgBzAGkAZABlADoAYQB2AG8A
>> "%~1" echo aQBkAH0AQABwAGEAZwBlAHsAcwBpAHoAZQA6AEEANAA7AG0AYQByAGcAaQBuADoA
>> "%~1" echo MQAzAG0AbQB9AH0AASs8AC8AcwB0AHkAbABlAD4APAAvAGgAZQBhAGQAPgA8AGIA
>> "%~1" echo bwBkAHkAPgAAgZk8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBhAGMAdABpAG8AbgBz
>> "%~1" echo ACIAPgA8AGIAdQB0AHQAbwBuACAAYwBsAGEAcwBzAD0AIgBiAHQAbgAgAHAAcgBp
>> "%~1" echo AG0AYQByAHkAIgAgAG8AbgBjAGwAaQBjAGsAPQAiAHcAaQBuAGQAbwB3AC4AcABy
>> "%~1" echo AGkAbgB0ACgAKQAiAD4AU2JwUyAALwAgAN1PWFsgAFAARABGADwALwBiAHUAdAB0
>> "%~1" echo AG8AbgA+ADwAYgB1AHQAdABvAG4AIABjAGwAYQBzAHMAPQAiAGIAdABuACIAIABv
>> "%~1" echo AG4AYwBsAGkAYwBrAD0AIgBkAG8AYwB1AG0AZQBuAHQALgBxAHUAZQByAHkAUwBl
>> "%~1" echo AGwAZQBjAHQAbwByAEEAbABsACgAJwBkAGUAdABhAGkAbABzACcAKQAuAGYAbwBy
>> "%~1" echo AEUAYQBjAGgAKABkAD0APgBkAC4AbwBwAGUAbgA9AHQAcgB1AGUAKQAiAD4AVVwA
>> "%~1" echo X0SWVV88AC8AYgB1AHQAdABvAG4APgA8AC8AZABpAHYAPgABSzwAbQBhAGkAbgAg
>> "%~1" echo AGMAbABhAHMAcwA9ACIAcwBoAGUAZQB0ACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBz
>> "%~1" echo AD0AIgBwAGEAZAAiAD4AAIHBPABoAGUAYQBkAGUAcgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo ZABvAGMALQBoAGUAYQBkACIAPgA8AGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAawBpAGMAawBlAHIAIgA+AFEAdQBlAHMAdAAgAEEARABCACAAVABvAG8A
>> "%~1" echo bABzACAALwAgAFIAZQBhAGQALQBvAG4AbAB5ACAAZQB4AHAAbwByAHQAPAAvAGQA
>> "%~1" echo aQB2AD4APABoADEAPgBRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mhW6GLpWJKVDwA
>> "%~1" echo LwBoADEAPgA8AHAAIABjAGwAYQBzAHMAPQAiAHMAdQBiACIAPgD6V45ObFEAXyAA
>> "%~1" echo QQBEAEIAIADqU/uLfVTkTh91EGIM/yh1jk50ZQZ0IABRAHUAZQBzAHQAIAA0WT5m
>> "%~1" echo q479TgEw+3zffgEwZVC3XgEw5V2CUy8AIWjGUb9+In0BMAVTDk79gJtSAjD8W/pR
>> "%~1" echo QW0Leg1OmVFlUb6Lbn8M/w1O7k85Zb6LB1kCMFxPBYBLbdWLvosHWUhyLGca/1EA
>> "%~1" echo dQBlAHMAdAAgADMAAjA8AC8AcAA+ADwALwBkAGkAdgA+AAF9PABhAHMAaQBkAGUA
>> "%~1" echo IABjAGwAYQBzAHMAPQAiAG0AZQB0AGEAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMA
>> "%~1" echo PQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABzAHAAYQBuAD4ApWJKVBZ/91M8AC8A
>> "%~1" echo cwBwAGEAbgA+ADwAYgA+AAFpPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2ACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBtAGUAdABhAC0AcgBvAHcAIgA+ADwAcwBwAGEAbgA+AB91
>> "%~1" echo EGL2ZfSVPAAvAHMAcABhAG4APgA8AGIAPgABgIs8AC8AYgA+ADwALwBkAGkAdgA+
>> "%~1" echo ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABz
>> "%~1" echo AHAAYQBuAD4AkJbBead+K1I8AC8AcwBwAGEAbgA+ADwAYgA+ADwAaQAgAGMAbABh
>> "%~1" echo AHMAcwA9ACIAcwB0AGEAbQBwACIAPgABgIM8AC8AaQA+ADwALwBiAD4APAAvAGQA
>> "%~1" echo aQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAbQBlAHQAYQAtAHIAbwB3ACIA
>> "%~1" echo PgA8AHMAcABhAG4APgBBAEQAQgAgAGVnkG48AC8AcwBwAGEAbgA+ADwAYgAgAHQA
>> "%~1" echo aQB0AGwAZQA9ACIAAQUiAD4AADc8AC8AYgA+ADwALwBkAGkAdgA+ADwALwBhAHMA
>> "%~1" echo aQBkAGUAPgA8AC8AaABlAGEAZABlAHIAPgAAgL88AHMAZQBjAHQAaQBvAG4AIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAHAAYQByAHQAeQAtAGcAcgBpAGQAIgA+ADwAZABpAHYAIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAGIAbwB4ACIAPgA8AGgAMgA+AL6LB1k8AC8AaAAyAD4APABk
>> "%~1" echo AGkAdgAgAGMAbABhAHMAcwA9ACIAYgBvAHgALQBiAG8AZAB5ACIAPgA8AGQAaQB2
>> "%~1" echo ACAAYwBsAGEAcwBzAD0AIgBiAGkAZwAiAD4AATM8AC8AZABpAHYAPgA8AGQAaQB2
>> "%~1" echo ACAAYwBsAGEAcwBzAD0AIgBtAHUAdABlAGQAIgA+AABnPAAvAGQAaQB2AD4APABk
>> "%~1" echo AGkAdgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcABzACIAPgA8AHMAcABhAG4AIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AFMAZQByAGkAYQBsACAAADU8AC8AcwBw
>> "%~1" echo AGEAbgA+ADwAcwBwAGEAbgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4AAA8g
>> "%~1" echo AC8AIABTAEQASwAgAAAzPAAvAHMAcABhAG4APgA8AC8AZABpAHYAPgA8AC8AZABp
>> "%~1" echo AHYAPgA8AC8AZABpAHYAPgAAgIs8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBiAG8A
>> "%~1" echo eAAiAD4APABoADIAPgDHkcaWVntldTwALwBoADIAPgA8AGQAaQB2ACAAYwBsAGEA
>> "%~1" echo cwBzAD0AIgBiAG8AeAAtAGIAbwBkAHkAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMA
>> "%~1" echo PQAiAGIAaQBnACIAPgABC8F5CWeMW3RlSHIBCwZSq06JW2hRSHIBM91PWXWMW3Rl
>> "%~1" echo wXkJZ8GLbmMM/wKQCFQsZzpnWXVjaBv/DU6BifR2pWNsUQBfBlKrTgIwAYCL8l1u
>> "%~1" echo kD2Fj14XUvdTATBoUeiQIABJAFAAdgA0AC8ASQBQAHYANgABME0AQQBDAC8AQgBT
>> "%~1" echo AFMASQBEAAEwZgBpAG4AZwBlAHIAcAByAGkAbgB0AAEwcwBlAHMAcwBpAG8AbgAg
>> "%~1" echo AEl7T2UfYVdbtWsb//ONx48gAGwAbwBnAGMAYQB0ACAARJZVXwIwAYFVPAAvAGQA
>> "%~1" echo aQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcABzACIAPgA8AHMA
>> "%~1" echo cABhAG4AIABjAGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AE4AbwAgAEEARABCACAA
>> "%~1" echo dwByAGkAdABlADwALwBzAHAAYQBuAD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0A
>> "%~1" echo IgBjAGgAaQBwACIAPgBIAFQATQBMAC8AUABEAEYAIAByAGUAYQBkAHkAPAAvAHMA
>> "%~1" echo cABhAG4APgA8AHMAcABhAG4AIABjAGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AFEA
>> "%~1" echo dQBlAHMAdAAgADMAIABuAG8AdABlAGQAPAAvAHMAcABhAG4APgA8AC8AZABpAHYA
>> "%~1" echo PgA8AC8AZABpAHYAPgA8AC8AZABpAHYAPgA8AC8AcwBlAGMAdABpAG8AbgA+AACA
>> "%~1" echo jTwAcwBlAGMAdABpAG8AbgAgAGMAbABhAHMAcwA9ACIAcwB1AG0AbQBhAHIAeQAi
>> "%~1" echo AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0ALQBjAGUAbABsACIAPgA8
>> "%~1" echo AHMAcABhAG4APgA1dc+RIAAvACAAKW6mXjwALwBzAHAAYQBuAD4APABiAD4AAWU8
>> "%~1" echo AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHMAdQBt
>> "%~1" echo AC0AYwBlAGwAbAAiAD4APABzAHAAYQBuAD4APmY6eTwALwBzAHAAYQBuAD4APABi
>> "%~1" echo AD4AAWU8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AHMAdQBtAC0AYwBlAGwAbAAiAD4APABzAHAAYQBuAD4AWFuoUDwALwBzAHAAYQBu
>> "%~1" echo AD4APABiAD4AAWU8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAHMAdQBtAC0AYwBlAGwAbAAiAD4APABzAHAAYQBuAD4AIWjGUTwALwBz
>> "%~1" echo AHAAYQBuAD4APABiAD4AASk8AC8AYgA+ADwALwBkAGkAdgA+ADwALwBzAGUAYwB0
>> "%~1" echo AGkAbwBuAD4AAAm+iwdZq479TgFBcwBlAHIAaQBhAGwAfACPXhdS91N8AGEAZABi
>> "%~1" echo ACAAZABlAHYAaQBjAGUAcwAgAC8AIABnAGUAdABwAHIAbwBwAAFDZABlAHYAaQBj
>> "%~1" echo AGUATABpAG4AZQB8AEEARABCACAAvosHWUyIfABhAGQAYgAgAGQAZQB2AGkAYwBl
>> "%~1" echo AHMAIAAtAGwAAU9tAGEAbgB1AGYAYQBjAHQAdQByAGUAcgB8AIJTRlV8AHIAbwAu
>> "%~1" echo AHAAcgBvAGQAdQBjAHQALgBtAGEAbgB1AGYAYQBjAHQAdQByAGUAcgABM2IAcgBh
>> "%~1" echo AG4AZAB8AMFUTHJ8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBiAHIAYQBuAGQAATNt
>> "%~1" echo AG8AZABlAGwAfACLV/dTfAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AbQBvAGQAZQBs
>> "%~1" echo AAE5cAByAG8AZAB1AGMAdAB8AKdOwVTjTvdTfAByAG8ALgBwAHIAbwBkAHUAYwB0
>> "%~1" echo AC4AbgBhAG0AZQABO2QAZQB2AGkAYwBlAHwAvosHWeNO91N8AHIAbwAuAHAAcgBv
>> "%~1" echo AGQAdQBjAHQALgBkAGUAdgBpAGMAZQABM2IAbwBhAHIAZAB8AH9np358AHIAbwAu
>> "%~1" echo AHAAcgBvAGQAdQBjAHQALgBiAG8AYQByAGQAASlzAG8AYwB8AFMAbwBDAHwAcgBv
>> "%~1" echo AC4AcwBvAGMALgBtAG8AZABlAGwAADVhAGIAaQB8AEEAQgBJAHwAcgBvAC4AcABy
>> "%~1" echo AG8AZAB1AGMAdAAuAGMAcAB1AC4AYQBiAGkAAAv7fN9+Dk6EZ/peAS9hAG4AZABy
>> "%~1" echo AG8AaQBkAHwAQQBuAGQAcgBvAGkAZAB8AGcAZQB0AHAAcgBvAHAAAB9zAGQAawB8
>> "%~1" echo AFMARABLAHwAZwBlAHQAcAByAG8AcAAAOXMAZQBjAHUAcgBpAHQAeQBQAGEAdABj
>> "%~1" echo AGgAfAD7fN9+iVtoUWWIAU58AGcAZQB0AHAAcgBvAHAAAT92AGUAbgBkAG8AcgBQ
>> "%~1" echo AGEAdABjAGgAfABWAGUAbgBkAG8AcgAgAIlbaFFliAFOfABnAGUAdABwAHIAbwBw
>> "%~1" echo AAExYgB1AGkAbABkAEkAZAB8AEIAdQBpAGwAZAAgAEkARAB8AGcAZQB0AHAAcgBv
>> "%~1" echo AHAAAEliAHUAaQBsAGQASQBuAGMAcgBlAG0AZQBuAHQAYQBsAHwASQBuAGMAcgBl
>> "%~1" echo AG0AZQBuAHQAYQBsAHwAZwBlAHQAcAByAG8AcAAANWIAdQBpAGwAZABCAHIAYQBu
>> "%~1" echo AGMAaAB8AEIAcgBhAG4AYwBoAHwAZwBlAHQAcAByAG8AcAAAP2YAaQBuAGcAZQBy
>> "%~1" echo AHAAcgBpAG4AdAB8AEYAaQBuAGcAZQByAHAAcgBpAG4AdAB8AGcAZQB0AHAAcgBv
>> "%~1" echo AHAAAC1rAGUAcgBuAGUAbAB8AEsAZQByAG4AZQBsAHwAdQBuAGEAbQBlACAALQBh
>> "%~1" echo AAEhPmY6eSAALwAgADV1kG4gAC8AIABRf9x+IAAvACAA7XABOWQAaQBzAHAAbABh
>> "%~1" echo AHkAfAA+Zjp5WGSBiXwAZAB1AG0AcABzAHkAcwAgAGQAaQBzAHAAbABhAHkAATVw
>> "%~1" echo AGEAbgBlAGwAfABil39nv34ifXwAZAB1AG0AcABzAHkAcwAgAGQAaQBzAHAAbABh
>> "%~1" echo AHkAAT9iAGEAdAB0AGUAcgB5AEwAZQB2AGUAbAB8ADV1z5F8AGQAdQBtAHAAcwB5
>> "%~1" echo AHMAIABiAGEAdAB0AGUAcgB5AAFBYgBhAHQAdABlAHIAeQBUAGUAbQBwAHwANXVg
>> "%~1" echo bClupl58AGQAdQBtAHAAcwB5AHMAIABiAGEAdAB0AGUAcgB5AAFFYgBhAHQAdABl
>> "%~1" echo AHIAeQBIAGUAYQBsAHQAaAB8ADV1YGxlULdefABkAHUAbQBwAHMAeQBzACAAYgBh
>> "%~1" echo AHQAdABlAHIAeQABPXAAbwB3AGUAcgBTAG8AdQByAGMAZQB8AJtPNXV8AGQAdQBt
>> "%~1" echo AHAAcwB5AHMAIABiAGEAdAB0AGUAcgB5AAE9dwBhAGsAZQBmAHUAbABuAGUAcwBz
>> "%~1" echo AHwAJFWSkbZyAWB8AGQAdQBtAHAAcwB5AHMAIABwAG8AdwBlAHIAAUlzAHQAYQB5
>> "%~1" echo AE8AbgB8AN1PAWMkVZKRfABzAGUAdAB0AGkAbgBnAHMAIAAvACAAZAB1AG0AcABz
>> "%~1" echo AHkAcwAgAHAAbwB3AGUAcgABSXAAcgBvAHgAaQBtAGkAdAB5AHwApWPRj7ZyAWB8
>> "%~1" echo AGQAdQBtAHAAcwB5AHMAIABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlAAFFdABo
>> "%~1" echo AGUAcgBtAGEAbAB8AO1wtnIBYHwAZAB1AG0AcABzAHkAcwAgAHQAaABlAHIAbQBh
>> "%~1" echo AGwAcwBlAHIAdgBpAGMAZQABJ3UAcwBiAHwAVQBTAEIAfABkAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAdQBzAGIAAEN3AGkAZgBpAHwAVwBpAC0ARgBpAHwAZAB1AG0AcABzAHkAcwAg
>> "%~1" echo AHcAaQBmAGkAIAAvACAAaQBwACAAYQBkAGQAcgABTWIAbAB1AGUAdABvAG8AdABo
>> "%~1" echo AHwA3YRZcnwAZAB1AG0AcABzAHkAcwAgAGIAbAB1AGUAdABvAG8AdABoAF8AbQBh
>> "%~1" echo AG4AYQBnAGUAcgABZWMAYQBtAGUAcgBhAHwA+HY6Zy8AIE8fYWhWfABkAHUAbQBw
>> "%~1" echo AHMAeQBzACAAbQBlAGQAaQBhAC4AYwBhAG0AZQByAGEAIAAvACAAcwBlAG4AcwBv
>> "%~1" echo AHIAcwBlAHIAdgBpAGMAZQABIXMAdABvAHIAYQBnAGUAfABYW6hQfABkAGYAIAAt
>> "%~1" echo AGgAAS9tAGUAbQBvAHIAeQB8AIVRWFt8AC8AcAByAG8AYwAvAG0AZQBtAGkAbgBm
>> "%~1" echo AG8AAStjAHAAdQB8AEMAUABVAHwALwBwAHIAbwBjAC8AYwBwAHUAaQBuAGYAbwAA
>> "%~1" echo M0YAYQBjAHQAbwByAHkAIAAvACAAQwBhAGwAaQBiAHIAYQB0AGkAbwBuACAAQ1Fw
>> "%~1" echo ZW5jAV9mAGEAYwB0AG8AcgB5AEQAZQB2AGkAYwBlAHwARABlAHYAaQBjAGUAVAB5
>> "%~1" echo AHAAZQB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0
>> "%~1" echo AGEAAFtmAGEAYwB0AG8AcgB5AEIAdQBpAGwAZAB8AEIAdQBpAGwAZABUAHkAcABl
>> "%~1" echo AHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAA
>> "%~1" echo aWYAYQBjAHQAbwByAHkAVABpAG0AZQB8AEYAYQBjAHQAbwByAHkAIABUAGkAbQBl
>> "%~1" echo AHMAdABhAG0AcAB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABh
>> "%~1" echo AGQAYQB0AGEAAGVmAGEAYwB0AG8AcgB5AEwAbwBjAGEAdABpAG8AbgB8AGwAbwBj
>> "%~1" echo AGEAdABpAG8AbgBfAGkAZAB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABt
>> "%~1" echo AGUAdABhAGQAYQB0AGEAAGFmAGEAYwB0AG8AcgB5AFMAdABhAHQAaQBvAG4AfABz
>> "%~1" echo AHQAYQB0AGkAbwBuAF8AaQBkAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAg
>> "%~1" echo AG0AZQB0AGEAZABhAHQAYQAAbWYAYQBjAHQAbwByAHkAUwB0AGEAdABpAG8AbgBU
>> "%~1" echo AHkAcABlAHwAcwB0AGEAdABpAG8AbgBfAHQAeQBwAGUAfABzAGUAbgBzAG8AcgBz
>> "%~1" echo AGUAcgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABdZgBhAGMAdABvAHIAeQBU
>> "%~1" echo AGUAcwB0AHwAYwBhAGwAXwB0AGUAcwB0AF8AaQBkAHwAcwBlAG4AcwBvAHIAcwBl
>> "%~1" echo AHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAZWYAYQBjAHQAbwByAHkATwBw
>> "%~1" echo AGUAcgBhAHQAbwByAHwAbwBwAGUAcgBhAHQAbwByAF8AaQBkAHwAcwBlAG4AcwBv
>> "%~1" echo AHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAdWYAYQBjAHQAbwBy
>> "%~1" echo AHkAQwBhAGwAaQBiAHIAYQB0AGkAbwBuAHwAYwBhAGwAaQBiAHIAYQB0AGkAbwBu
>> "%~1" echo AF8AdAB5AHAAZQB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABh
>> "%~1" echo AGQAYQB0AGEAAHdvAG4AbABpAG4AZQBDAGEAbABpAGIAcgBhAHQAaQBvAG4AfABP
>> "%~1" echo AG4AbABpAG4AZQAgAGMAYQBsAGkAYgByAGEAdABpAG8AbgB8AHMAZQBuAHMAbwBy
>> "%~1" echo AHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAIF9PABkAGkAdgAgAGMA
>> "%~1" echo bABhAHMAcwA9ACIAbgBvAHQAZQAiAD4APABiAD4AqGOtZbmPTHUa/zwALwBiAD4A
>> "%~1" echo 71PlTrCLVV++iwdZz2UBMGx49k42lrVrATAhaMZRsItVX4xU5V2CU0tt1Yu/fiJ9
>> "%~1" echo DP+LT4JZIABRAHUAZQBzAHQAIAAzACAALwAgAEUAdQByAGUAawBhACAALwAgAFAA
>> "%~1" echo VgBUACAALwAgAEYAYQBjAHQAbwByAHkAIAAvACAATwBuAGwAaQBuAGUAIABjAGEA
>> "%~1" echo bABpAGIAcgBhAHQAaQBvAG4AAjANTv2AimIgAGwAbwBjAGEAdABpAG8AbgBfAGkA
>> "%~1" echo ZAABMHMAdABhAHQAaQBvAG4AXwBpAGQAATBzAHQAYQB0AGkAbwBuAF8AdAB5AHAA
>> "%~1" echo ZQAgAO9TYJf7f9GLEGL9VrZbATDOVwJeFmJ3UVNP5V2CUxv/VwBpAC0ARgBpACAA
>> "%~1" echo /Va2WwF4X04NTi9m+lGnTjBXAjA8AC8AZABpAHYAPgABDQVTDk77fN9+/YCbUgE7
>> "%~1" echo cABhAGMAawBhAGcAZQBzAHwABVNwZc+RfABwAG0AIABsAGkAcwB0ACAAcABhAGMA
>> "%~1" echo awBhAGcAZQBzAAFJZgBlAGEAdAB1AHIAZQBzAHwARgBlAGEAdAB1AHIAZQAgAHBl
>> "%~1" echo z5F8AHAAbQAgAGwAaQBzAHQAIABmAGUAYQB0AHUAcgBlAHMAAXN2AGQAfABWAGkA
>> "%~1" echo cgB0AHUAYQBsACAARABlAHMAawB0AG8AcAB8AGQAdQBtAHAAcwB5AHMAIABwAGEA
>> "%~1" echo YwBrAGEAZwBlACAAVgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAC4AQQBuAGQA
>> "%~1" echo cgBvAGkAZAAAPXcAYQByAG4AaQBuAGcAcwB8AMeRxpZmi0pUfABlAHgAcABvAHIA
>> "%~1" echo dAAgAGMAbwBsAGwAZQBjAHQAbwByAAGB3zwAZgBvAG8AdABlAHIAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAGYAbwBvAHQAIgA+ADwAZABpAHYAPgA8AGIAPgBRAHUAZQBzAHQAIABB
>> "%~1" echo AEQAQgAgAFQAbwBvAGwAcwAgAGIAeQAgAGQAdwBnAHgAMQAzADMANwA8AC8AYgA+
>> "%~1" echo ADwAYgByAD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBtAHUAdABlAGQAIgA+
>> "%~1" echo AFAAdQBiAGwAaQBjACAAcgBlAHAAbwAgAHMAYQBtAHAAbABlACAAbQB1AHMAdAAg
>> "%~1" echo AHUAcwBlACAAcwBoAGEAcgBlAC0AcwBhAGYAZQAgAGUAeABwAG8AcgB0AC4AIABQ
>> "%~1" echo AHIAaQB2AGEAdABlACAAZgB1AGwAbAAgAGUAeABwAG8AcgB0ACAAaQBzACAAZgBv
>> "%~1" echo AHIAIABsAG8AYwBhAGwAIABlAHYAaQBkAGUAbgBjAGUAIABvAG4AbAB5AC4APAAv
>> "%~1" echo AHMAcABhAG4APgA8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgB0
>> "%~1" echo AG8AdABhAGwAIgA+ADwAZABpAHYAPgA8AHMAcABhAG4APgBQAGEAYwBrAGEAZwBl
>> "%~1" echo AHMAPAAvAHMAcABhAG4APgA8AGIAPgABTzwALwBiAD4APAAvAGQAaQB2AD4APABk
>> "%~1" echo AGkAdgA+ADwAcwBwAGEAbgA+AEYAZQBhAHQAdQByAGUAcwA8AC8AcwBwAGEAbgA+
>> "%~1" echo ADwAYgA+AABLPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2AD4APABzAHAAYQBu
>> "%~1" echo AD4AUwB0AGEAdAB1AHMAPAAvAHMAcABhAG4APgA8AGIAPgAAD1AAcgBpAHYAYQB0
>> "%~1" echo AGUAABVTAGgAYQByAGUALQBzAGEAZgBlAAEzPAAvAGIAPgA8AC8AZABpAHYAPgA8
>> "%~1" echo AC8AZABpAHYAPgA8AC8AZgBvAG8AdABlAHIAPgAANzwALwBkAGkAdgA+ADwALwBt
>> "%~1" echo AGEAaQBuAD4APAAvAGIAbwBkAHkAPgA8AC8AaAB0AG0AbAA+AAA7PABzAGUAYwB0
>> "%~1" echo AGkAbwBuACAAYwBsAGEAcwBzAD0AIgBzAGUAYwB0AGkAbwBuACIAPgA8AGgAMgA+
>> "%~1" echo AACAwzwALwBoADIAPgA8AHQAYQBiAGwAZQAgAGMAbABhAHMAcwA9ACIAYQB1AGQA
>> "%~1" echo aQB0AC0AdABhAGIAbABlACIAPgA8AHQAaABlAGEAZAA+ADwAdAByAD4APAB0AGgA
>> "%~1" echo PgBXW7VrPAAvAHQAaAA+ADwAdABoAD4APFA8AC8AdABoAD4APAB0AGgAPgDBi25j
>> "%~1" echo ZWeQbjwALwB0AGgAPgA8AC8AdAByAD4APAAvAHQAaABlAGEAZAA+ADwAdABiAG8A
>> "%~1" echo ZAB5AD4AAQdBAEQAQgAAETwAdAByAD4APAB0AGQAPgAAEzwALwB0AGQAPgA8AHQA
>> "%~1" echo ZAA+AAAVPAAvAHQAZAA+ADwALwB0AHIAPgAANTwALwB0AGIAbwBkAHkAPgA8AC8A
>> "%~1" echo dABhAGIAbABlAD4APAAvAHMAZQBjAHQAaQBvAG4APgAAYzwAcwBlAGMAdABpAG8A
>> "%~1" echo bgAgAGMAbABhAHMAcwA9ACIAcwBlAGMAdABpAG8AbgAgAHIAYQB3ACIAPgA8AGgA
>> "%~1" echo MgA+AJ9Ty1kgAEEARABCACAAk4/6UUSWVV88AC8AaAAyAD4AAQ1sAG8AZwBjAGEA
>> "%~1" echo dAAAMQoALgAuAC4AIADyXSpirWUM/4xbdGWFUblb94sLd8F5CWeMW3RlSHIgAC4A
>> "%~1" echo LgAuAAElPABkAGUAdABhAGkAbABzAD4APABzAHUAbQBtAGEAcgB5AD4AAAcgALcA
>> "%~1" echo IAABFW0AcwAgALcAIABlAHgAaQB0ACAAARUgALcAIAB0AGkAbQBlAG8AdQB0AAEf
>> "%~1" echo PAAvAHMAdQBtAG0AYQByAHkAPgA8AHAAcgBlAD4AACE8AC8AcAByAGUAPgA8AC8A
>> "%~1" echo ZABlAHQAYQBpAGwAcwA+AAAVPAAvAHMAZQBjAHQAaQBvAG4APgAAOWcAZQB0AHAA
>> "%~1" echo cgBvAHAAIABkAGgAYwBwAC4AdwBsAGEAbgAwAC4AaQBwAGEAZABkAHIAZQBzAHMA
>> "%~1" echo AA8wAC4AMAAuADAALgAwAAA1aQBwACAALQBmACAAaQBuAGUAdAAgAGEAZABkAHIA
>> "%~1" echo IABzAGgAbwB3ACAAdwBsAGEAbgAwAAELaQBuAGUAdAAgAAAFIgAiAAADIgAABVwA
>> "%~1" echo IgAAAzIAAAdFUTV1LU4BAzMAAAM0AAAHKmdFUTV1AQM1AAAH8l1FUeFuAQVjazhe
>> "%~1" echo AQXHj+1wAQVfY09XAQXHj4tTAQM3AAAFx4+3UQEXQQBDACAAcABvAHcAZQByAGUA
>> "%~1" echo ZAA6AAAFQQBDAAAZVQBTAEIAIABwAG8AdwBlAHIAZQBkADoAAAdVAFMAQgAAI1cA
>> "%~1" echo aQByAGUAbABlAHMAcwAgAHAAbwB3AGUAcgBlAGQAOgAABeBlv34BBypnm081dQED
>> "%~1" echo PQAAA1sAAAldADoAIABbAAArXAAiAFwAcwAqADoAXABzACoAXAAiACgAWwBeAFwA
>> "%~1" echo IgBdACoAKQBcACIAACdcACIAXABzACoAOgBcAHMAKgAoAFsAXgAsAH0AXABzAF0A
>> "%~1" echo KwApAAALLwBkAGEAdABhAAARLwBzAHQAbwByAGEAZwBlAAANIAB1AHMAZQBkACAA
>> "%~1" echo ABNwAHIAbwBjAGUAcwBzAG8AcgAAP0MAUABVACAAcABhAHIAdABcAHMAKgA6AFwA
>> "%~1" echo cwAqACgAMAB4AFsAMAAtADkAYQAtAGYAQQAtAEYAXQArACkAARMgAGMAbwByAGUA
>> "%~1" echo cwAgAC8AIAAAIWkAZAA9AFwAZAArACwAXABzACoAdwBpAGQAdABoAD0AAAMwAAAN
>> "%~1" echo IABtAG8AZABlAHMAABNIAEEATAAgAFIAZQBhAGQAeQAACUgAQQBMACAAABFiAGEA
>> "%~1" echo dAB0AGUAcgB5ACAAACVjAG8AbgBuAGUAYwB0AGUAZAA9ACgAWwBhAC0AegBdACsA
>> "%~1" echo KQABJ2MAbwBuAGYAaQBnAHUAcgBlAGQAPQAoAFsAYQAtAHoAXQArACkAATltAEMA
>> "%~1" echo dQByAHIAZQBuAHQARgB1AG4AYwB0AGkAbwBuAHMAPQAoAFsAXgBcAG4AXAByAF0A
>> "%~1" echo KwApAAAVYwBvAG4AbgBlAGMAdABlAGQAIAAAF2MAbwBuAGYAaQBnAHUAcgBlAGQA
>> "%~1" echo IAAAPXMAdABhAG4AZABhAHIAZAA6AFwAcwAqACgAWwAwAC0AOQBBAC0AWgBhAC0A
>> "%~1" echo egAgAC4AXwAtAF0AKwApAAErRgByAGUAcQB1AGUAbgBjAHkAOgBcAHMAKgAoAFsA
>> "%~1" echo MAAtADkAXQArACkAAS1MAGkAbgBrACAAcwBwAGUAZQBkADoAXABzACoAKABbADAA
>> "%~1" echo LQA5AF0AKwApAAElUgBTAFMASQA6AFwAcwAqACgALQA/AFsAMAAtADkAXQArACkA
>> "%~1" echo AU9pAG4AZQB0AFwAcwArACgAWwAwAC0AOQBdACsAXAAuAFsAMAAtADkAXQArAFwA
>> "%~1" echo LgBbADAALQA5AF0AKwBcAC4AWwAwAC0AOQBdACsAKQABB0kAUAAgAAATcwB0AGEA
>> "%~1" echo bgBkAGEAcgBkACAAAAdNAEgAegAACU0AYgBwAHMAAAtSAFMAUwBJACAAACdlAG4A
>> "%~1" echo YQBiAGwAZQBkADoAXABzACoAKABbAGEALQB6AF0AKwApAAElcwB0AGEAdABlADoA
>> "%~1" echo XABzACoAKABbAEEALQBaAF8AXQArACkAASFCAGwAdQBlAHQAbwBvAHQAaAAgAFMA
>> "%~1" echo dABhAHQAdQBzAAARZQBuAGEAYgBsAGUAZAAgAABfQwBhAG0AZQByAGEARABlAHYA
>> "%~1" echo aQBjAGUAQwBsAGkAZQBuAHQAfABDAGEAbQBlAHIAYQBcAHMAKwBJAEQAfAA9AD0A
>> "%~1" echo IABDAGEAbQBlAHIAYQAgAGQAZQB2AGkAYwBlAAA1IgBTAGUAbgBzAG8AcgBUAHkA
>> "%~1" echo cABlACIAXABzACoAOgBcAHMAKgAiAE8ARwAwADEAQQAiAAA3IgBTAGUAbgBzAG8A
>> "%~1" echo cgBUAHkAcABlACIAXABzACoAOgBcAHMAKgAiAE8AVgA3ADIANQAxACIAADciAFMA
>> "%~1" echo ZQBuAHMAbwByAFQAeQBwAGUAIgBcAHMAKgA6AFwAcwAqACIASQBNAFgANAA3ADEA
>> "%~1" echo IgAAHyAAYwBhAG0AZQByAGEAIABlAG4AdAByAGkAZQBzAAAlYwBhAGwAIABzAGUA
>> "%~1" echo bgBzAG8AcgBzACAATwBHADAAMQBBACAAABUgAC8AIABPAFYANwAyADUAMQAgAAAV
>> "%~1" echo IAAvACAASQBNAFgANAA3ADEAIAAAQVAAYQBjAGsAYQBnAGUAIABbAFYAaQByAHQA
>> "%~1" echo dQBhAGwARABlAHMAawB0AG8AcAAuAEEAbgBkAHIAbwBpAGQAXQAAEXAAYQBjAGsA
>> "%~1" echo YQBnAGUAOgAAL1YASQBWAEUAIABCAHUAcwBpAG4AZQBzAHMAIABTAHQAcgBlAGEA
>> "%~1" echo bQBpAG4AZwAAN1YASQBWAEUAIABCAHUAcwBpAG4AZQBzAHMAIABTAHQAcgBlAGEA
>> "%~1" echo bQBpAG4AZwAgAEEARABCAAAPQQBuAGQAcgBvAGkAZAAAHXAAbABhAHQAZgBvAHIA
>> "%~1" echo bQAtAHQAbwBvAGwAcwABNUEAbgBkAHIAbwBpAGQAIABwAGwAYQB0AGYAbwByAG0A
>> "%~1" echo LQB0AG8AbwBsAHMAIABBAEQAQgABD2EAZABiAC4AZQB4AGUAAAdhAGQAYgAAHUEA
>> "%~1" echo RABCACAAZQB4AGUAYwB1AHQAYQBiAGwAZQAAC1sAQQAtAFoAXQABC1sAMAAtADkA
>> "%~1" echo XQABJVwAYgBbAEEALQBaADAALQA5AF0AewA4ACwAMgAwAH0AXABiAAFNXABiACgA
>> "%~1" echo WwAwAC0AOQBBAC0ARgBhAC0AZgBdAHsAMgB9ADoAKQB7ADUAfQBbADAALQA5AEEA
>> "%~1" echo LQBGAGEALQBmAF0AewAyAH0AXABiAAEjKgAqADoAKgAqADoAKgAqADoAKgAqADoA
>> "%~1" echo KgAqADoAKgAqAABVKAA/AGkAKQAoAD8AOgBbADAALQA5AGEALQBmAF0AewAxACwA
>> "%~1" echo NAB9ADoAKQArADoAWwAwAC0AOQBhAC0AZgBdAFsAMAAtADkAYQAtAGYAOgBdACoA
>> "%~1" echo AR9bAFIARQBEAEEAQwBUAEUARABfAEkAUABWADYAXQAATSgAPwBpACkAKAA/ADwA
>> "%~1" echo IQBbADAALQA5AGEALQBmADoAXQApADoAOgBbADAALQA5AGEALQBmAF0AWwAwAC0A
>> "%~1" echo OQBhAC0AZgA6AF0AKgABVygAPwBpACkAXABiACgAPwA6AFsAMAAtADkAYQAtAGYA
>> "%~1" echo XQB7ADEALAA0AH0AOgApAHsANAAsAH0AWwAwAC0AOQBhAC0AZgBdAHsAMQAsADQA
>> "%~1" echo fQBcAGIAAU1cAGIAXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAC4A
>> "%~1" echo XABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAGIAAA94AC4AeAAuAHgA
>> "%~1" echo LgB4AACA/14AXABbACgAcgBvAFwALgBzAGUAcgBpAGEAbABuAG8AfAByAG8AXAAu
>> "%~1" echo AGIAbwBvAHQAXAAuAHMAZQByAGkAYQBsAG4AbwB8AGEAbgBkAHIAbwBpAGQAYgBv
>> "%~1" echo AG8AdABcAC4AcwBlAHIAaQBhAGwAbgBvAHwAZwBzAG0AXAAuAFsAXgBcAF0AXQAq
>> "%~1" echo AGkAbQBlAGkAWwBeAFwAXQBdACoAfABwAGUAcgBzAGkAcwB0AFwALgBbAF4AXABd
>> "%~1" echo AF0AKgBzAGUAcgBpAGEAbABbAF4AXABdAF0AKgApAFwAXQBcAHMAKgA6AFwAcwAq
>> "%~1" echo AFwAWwBbAF4AXABdAF0AKgBcAF0AACVbACQAMQBdADoAIABbADwAcgBlAGQAYQBj
>> "%~1" echo AHQAZQBkAD4AXQAAUSgAUwBTAEkARAB8AEIAUwBTAEkARAB8AFcAaQBmAGkAUwBz
>> "%~1" echo AGkAZAB8AG0AVwBpAGYAaQBJAG4AZgBvACkAWwBeACwAXABuAFwAcgBdACoAABsk
>> "%~1" echo ADEAPQA8AHIAZQBkAGEAYwB0AGUAZAA+AABNcgBvAFwALgBiAHUAaQBsAGQAXAAu
>> "%~1" echo AGYAaQBuAGcAZQByAHAAcgBpAG4AdABcAF0AOgAgAFwAWwBbAF4AXABdAFwAbgBc
>> "%~1" echo AHIAXQArAABFcgBvAC4AYgB1AGkAbABkAC4AZgBpAG4AZwBlAHIAcAByAGkAbgB0
>> "%~1" echo AF0AOgAgAFsAPAByAGUAZABhAGMAdABlAGQAPgAAK2YAaQBuAGcAZQByAHAAcgBp
>> "%~1" echo AG4AdAA9AFsAXgAsAFwAbgBcAHIAXQArAAAtZgBpAG4AZwBlAHIAcAByAGkAbgB0
>> "%~1" echo AD0APAByAGUAZABhAGMAdABlAGQAPgAANW8AcwBfAGYAaQBuAGcAZQByAHAAcgBp
>> "%~1" echo AG4AdABbAF4ALABcAG4AXAByAFwAXAB9AF0AKwAAM28AcwBfAGYAaQBuAGcAZQBy
>> "%~1" echo AHAAcgBpAG4AdAA9ADwAcgBlAGQAYQBjAHQAZQBkAD4AAC1zAGUAcwBzAGkAbwBu
>> "%~1" echo AF8AaQBkAFsAXgAsAFwAbgBcAHIAXABcAH0AXQArAAArcwBlAHMAcwBpAG8AbgBf
>> "%~1" echo AGkAZAA9ADwAcgBlAGQAYQBjAHQAZQBkAD4AAAMNAAARPABzAGUAcgBpAGEAbAA+
>> "%~1" echo AAAHKgAqACoAADlkAGUAdgBlAGwAbwBwAG0AZQBuAHQAXwBzAGUAdAB0AGkAbgBn
>> "%~1" echo AHMAXwBlAG4AYQBiAGwAZQBkAAAlZABlAHYAaQBjAGUAXwBwAHIAbwB2AGkAcwBp
>> "%~1" echo AG8AbgBlAGQAACd1AHMAZQByAF8AcwBlAHQAdQBwAF8AYwBvAG0AcABsAGUAdABl
>> "%~1" echo AAAPdwBpAGYAaQBfAG8AbgAAIWEAaQByAHAAbABhAG4AZQBfAG0AbwBkAGUAXwBv
>> "%~1" echo AG4AABVoAHQAdABwAF8AcAByAG8AeAB5AAAjZwBsAG8AYgBhAGwAXwBoAHQAdABw
>> "%~1" echo AF8AcAByAG8AeAB5AAAvaQBuAHMAdABhAGwAbABfAG4AbwBuAF8AbQBhAHIAawBl
>> "%~1" echo AHQAXwBhAHAAcABzAAA5dgBlAHIAaQBmAGkAZQByAF8AdgBlAHIAaQBmAHkAXwBh
>> "%~1" echo AGQAYgBfAGkAbgBzAHQAYQBsAGwAcwAAAycAAQknAFwAJwAnAAEDPwAAAysAAD9h
>> "%~1" echo AHAAcABsAGkAYwBhAHQAaQBvAG4ALwBqAHMAbwBuADsAIABjAGgAYQByAHMAZQB0
>> "%~1" echo AD0AdQB0AGYALQA4AAE/SABUAFQAUAAvADEALgAxACAAMgAwADAAIABPAEsADQAK
>> "%~1" echo AEMAbwBuAHQAZQBuAHQALQBUAHkAcABlADoAIAABJQ0ACgBDAG8AbgB0AGUAbgB0
>> "%~1" echo AC0ATABlAG4AZwB0AGgAOgAgAAFhDQAKAEMAYQBjAGgAZQAtAEMAbwBuAHQAcgBv
>> "%~1" echo AGwAOgAgAG4AbwAtAHMAdABvAHIAZQANAAoAQwBvAG4AbgBlAGMAdABpAG8AbgA6
>> "%~1" echo ACAAYwBsAG8AcwBlAA0ACgANAAoAAQN7AAAHIgA6ACIAAAN9AAAFXABcAAAFXABu
>> "%~1" echo AAAFXAByAAAFXAB0AAAFXAB1AAAFeAA0AADAAwchUABDAEYAawBiADIATgAwAGUA
>> "%~1" echo WABCAGwASQBHAGgAMABiAFcAdwArAEQAUQBvADgAYQBIAFIAdABiAEMAQgBzAFkA
>> "%~1" echo VwA1AG4AUABTAEoANgBhAEMAMQBEAFQAaQBJACsARABRAG8AOABhAEcAVgBoAFoA
>> "%~1" echo RAA0AE4AQwBqAHgAdABaAFgAUgBoAEkARwBOAG8AWQBYAEoAegBaAFgAUQA5AEkA
>> "%~1" echo bgBWADAAWgBpADAANABJAGoANABOAEMAagB4AHQAWgBYAFIAaABJAEcANQBoAGIA
>> "%~1" echo VwBVADkASQBuAFoAcABaAFgAZAB3AGIAMwBKADAASQBpAEIAagBiADIANQAwAFoA
>> "%~1" echo VwA1ADAAUABTAEoAMwBhAFcAUgAwAGEARAAxAGsAWgBYAFoAcABZADIAVQB0AGQA
>> "%~1" echo MgBsAGsAZABHAGcAcwBhAFcANQBwAGQARwBsAGgAYgBDADEAegBZADIARgBzAFoA
>> "%~1" echo VAAwAHgASQBqADQATgBDAGoAeAAwAGEAWABSAHMAWgBUADUAUgBkAFcAVgB6AGQA
>> "%~1" echo QwBCAEIAUgBFAEkAZwA1AG8ANgBuADUAWQBpADIANQBZACsAdwBQAEMAOQAwAGEA
>> "%~1" echo WABSAHMAWgBUADQATgBDAGoAeAB6AGQASABsAHMAWgBUADQATgBDAGoAcAB5AGIA
>> "%~1" echo MgA5ADAAZQB5ADAAdABZAG0AYwA2AEkAMgBWAGwAWgBqAEYAbQBOAHoAcwB0AEwA
>> "%~1" echo WABOAHAAWgBHAFUANgBJADIAWgBtAFoAagBzAHQATABXAE4AaABjAG0AUQA2AEkA
>> "%~1" echo MgBaAG0AWgBqAHMAdABMAFgATgB2AFoAbgBRADYASQAyAFkAMQBaAGoAZABtAFkA
>> "%~1" echo agBzAHQATABXAHgAcABiAG0AVQA2AEkAMgBVAHkAWgBUAGgAbQBNAEQAcwB0AEwA
>> "%~1" echo WABSAGwAZQBIAFEANgBJAHoAQgBtAE0AVABjAHkAWQBUAHMAdABMAFcAMQAxAGQA
>> "%~1" echo RwBWAGsATwBpAE0AMgBOAEQAYwAwAE8ARwBJADcATABTADEAaQBiAEgAVgBsAE8A
>> "%~1" echo aQBNAHkATgBUAFkAegBaAFcASQA3AEwAUwAxAGkAYgBIAFYAbABNAGoAbwBqAE0A
>> "%~1" echo MgBJADQATQBtAFkAMgBPAHkAMAB0AFoAMwBKAGwAWgBXADQANgBJAHoARQAyAFkA
>> "%~1" echo VABNADAAWQBUAHMAdABMAFcARgB0AFkAbQBWAHkATwBpAE4AawBPAFQAYwAzAE0A
>> "%~1" echo RABZADcATABTADEAeQBaAFcAUQA2AEkAMgBVAHgATQBXAFEAMABPAEQAcwB0AEwA
>> "%~1" echo VwA1AGgAZABqAG8AeQBOAEQAUgB3AGUARABzAHQATABYAEoAaABaAEcAbAAxAGMA
>> "%~1" echo egBvAHgATQBuAEIANABPAHkAMAB0AGMAMgBoAGgAWgBHADkAMwBPAGoAQQBnAE0A
>> "%~1" echo WABCADQASQBEAEoAdwBlAEMAQgB5AFoAMgBKAGgASwBEAEUAMQBMAEQASQB6AEwA
>> "%~1" echo RABRAHkATABDADQAdwBOAFMAawBzAE0AQwBBADQAYwBIAGcAZwBNAGoAUgB3AGUA
>> "%~1" echo QwBCAHkAWgAyAEoAaABLAEQARQAxAEwARABJAHoATABEAFEAeQBMAEMANAB3AE4A
>> "%~1" echo UwBsADkARABRAHAAaQBiADIAUgA1AEwAbQBSAGgAYwBtAHQANwBMAFMAMQBpAFoA
>> "%~1" echo egBvAGoATQBHAEkAdwBaAGoARQAyAE8AeQAwAHQAYwAyAGwAawBaAFQAbwBqAE0A
>> "%~1" echo RwBZAHgATgBqAEkAdwBPAHkAMAB0AFkAMgBGAHkAWgBEAG8AagBNAFQATQB4AFkA
>> "%~1" echo agBJADIATwB5ADAAdABjADIAOQBtAGQARABvAGoATQBHAFkAeABOAHoASQB3AE8A
>> "%~1" echo eQAwAHQAYgBHAGwAdQBaAFQAbwBqAE0AagBRAHoATQBEAFEAMABPAHkAMAB0AGQA
>> "%~1" echo RwBWADQAZABEAG8AagBaAFQAWgBsAFoARwBZADMATwB5ADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRADYASQB6AGsAegBZAFQASgBpAE8ARABzAHQATABYAE4AbwBZAFcAUgB2AGQA
>> "%~1" echo egBvAHcASQBEAEYAdwBlAEMAQQB5AGMASABnAGcAYwBtAGQAaQBZAFMAZwB3AEwA
>> "%~1" echo RABBAHMATQBDAHcAdQBNAHkAawBzAE0AQwBBAHgATQBuAEIANABJAEQATQB3AGMA
>> "%~1" echo SABnAGcAYwBtAGQAaQBZAFMAZwB3AEwARABBAHMATQBDAHcAdQBNAHoAVQBwAGYA
>> "%~1" echo UQAwAEsASwBuAHQAaQBiADMAZwB0AGMAMgBsADYAYQBXADUAbgBPAG0ASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAaQBiADMAaAA5AGEASABSAHQAYgBDAHgAaQBiADIAUgA1AGUA
>> "%~1" echo MgAxAGgAYwBtAGQAcABiAGoAbwB3AE8AMgAxAHAAYgBpADEAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATQBUAEEAdwBKAFQAdABtAGIAMgA1ADAATABXAFoAaABiAFcAbABzAGUA
>> "%~1" echo VABvAGkAVQAyAFYAbgBiADIAVQBnAFYAVQBrAGkATABDAEoATgBhAFcATgB5AGIA
>> "%~1" echo MwBOAHYAWgBuAFEAZwBXAFcARgBJAFoAVwBrAGkATABIAE4ANQBjADMAUgBsAGIA
>> "%~1" echo UwAxADEAYQBTAHgAQgBjAG0AbABoAGIAQwB4AHoAWQBXADUAegBMAFgATgBsAGMA
>> "%~1" echo bQBsAG0ATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAWQBtAGMAcABPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo WABSAGwAZQBIAFEAcABPADIAWgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB4AE4A
>> "%~1" echo SABCADQAZgBRADAASwBZAG4AVgAwAGQARwA5AHUATABHAGwAdQBjAEgAVgAwAEwA
>> "%~1" echo SABOAGwAYgBHAFYAagBkAEgAdABtAGIAMgA1ADAATwBtAGwAdQBhAEcAVgB5AGEA
>> "%~1" echo WABSADkARABRAG8AdQBZAFgAQgB3AGUAMgAxAHAAYgBpADEAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATQBUAEEAdwBkAG0AZwA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMA
>> "%~1" echo bQBsAGsATwAyAGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkA
>> "%~1" echo MgA5AHMAZABXADEAdQBjAHoAcAAyAFkAWABJAG8ATABTADEAdQBZAFgAWQBwAEkA
>> "%~1" echo RABGAG0AYwBuADAATgBDAGkANQB6AGEAVwBSAGwAZQAzAEIAdgBjADIAbAAwAGEA
>> "%~1" echo VwA5AHUATwBtAFoAcABlAEcAVgBrAE8AMgBsAHUAYwAyAFYAMABPAGoAQQBnAFkA
>> "%~1" echo WABWADAAYgB5AEEAdwBJAEQAQQA3AGQAMgBsAGsAZABHAGcANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBtAEYAMgBLAFQAdABvAFoAVwBsAG4AYQBIAFEANgBNAFQAQQB3AGQA
>> "%~1" echo bQBnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHoAYQBXAFIAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0AbABuAGEA
>> "%~1" echo SABRADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABPADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaAG0AeABsAGUA
>> "%~1" echo RAB0AG0AYgBHAFYANABMAFcAUgBwAGMAbQBWAGoAZABHAGwAdgBiAGoAcABqAGIA
>> "%~1" echo MgB4ADEAYgBXADQANwBlAGkAMQBwAGIAbQBSAGwAZQBEAG8AMQBmAFEAMABLAEwA
>> "%~1" echo bQBKAHkAWQBXADUAawBlADIAaABsAGEAVwBkAG8AZABEAG8AMwBPAEgAQgA0AE8A
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcAbABuAGIA
>> "%~1" echo aQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBaADIARgB3AE8A
>> "%~1" echo agBFAHkAYwBIAGcANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AdwBJAEQASQB3AGMA
>> "%~1" echo SABnADcAWQBtADkAeQBaAEcAVgB5AEwAVwBKAHYAZABIAFIAdgBiAFQAbwB4AGMA
>> "%~1" echo SABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoA
>> "%~1" echo UwBsADkARABRAG8AdQBZAG4ASgBoAGIAbQBSAEoAWQAyADkAdQBlADMAZABwAFoA
>> "%~1" echo SABSAG8ATwBqAE0ANABjAEgAZwA3AGEARwBWAHAAWgAyAGgAMABPAGoATQA0AGMA
>> "%~1" echo SABnADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwB4AE0A
>> "%~1" echo SABCADQATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBiAEcAbAB1AFoA
>> "%~1" echo VwBGAHkATABXAGQAeQBZAFcAUgBwAFoAVwA1ADAASwBEAEUAegBOAFcAUgBsAFoA
>> "%~1" echo eQB4ADIAWQBYAEkAbwBMAFMAMQBpAGIASABWAGwASwBTAHgAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABNAGkAawBwAE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoA
>> "%~1" echo MwBKAHAAWgBEAHQAdwBiAEcARgBqAFoAUwAxAHAAZABHAFYAdABjAHoAcABqAFoA
>> "%~1" echo VwA1ADAAWgBYAEkANwBZADIAOQBzAGIAMwBJADYASQAyAFoAbQBaAGoAdABpAGIA
>> "%~1" echo MwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AagBBAGcATgBuAEIANABJAEQARQAyAGMA
>> "%~1" echo SABnAGcAYwBtAGQAaQBZAFMAZwB6AE4AeQB3ADUATwBTAHcAeQBNAHoAVQBzAEwA
>> "%~1" echo agBNADEASwBYADAATgBDAGkANQBpAGMAbQBGAHUAWgBDAEIAaQBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgBzADcAWgBtADkAdQBkAEMAMQB6AGEA
>> "%~1" echo WABwAGwATwBqAEUAMgBjAEgAaAA5AEwAbQBKAHkAWQBXADUAawBJAEgATgB3AFkA
>> "%~1" echo VwA1ADcAWgBHAGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkAagBhAHoAdAB0AFkA
>> "%~1" echo WABKAG4AYQBXADQAdABkAEcAOQB3AE8AagBOAHcAZQBEAHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxAHoAYQBYAHAAbABPAGoARQB5AGMASABoADkARABRAG8AdQBZAG4ASgBoAGIA
>> "%~1" echo bQBSAEoAWQAyADkAdQBJAEgATgAyAFoAeQB3AHUAYgBtAEYAMgBJAEgATgAyAFoA
>> "%~1" echo eQB3AHUAWgBHAFYAMgBhAFcATgBsAFMAVwBOAHYAYgBpAEIAegBkAG0AYwBzAEwA
>> "%~1" echo bQBSAHkAYgAzAEEAZwBjADMAWgBuAGUAMgBaAHAAYgBHAHcANgBiAG0AOQB1AFoA
>> "%~1" echo VAB0AHoAZABIAEoAdgBhADIAVQA2AFkAMwBWAHkAYwBtAFYAdQBkAEUATgB2AGIA
>> "%~1" echo RwA5AHkATwAzAE4AMABjAG0AOQByAFoAUwAxADMAYQBXAFIAMABhAEQAbwB5AE8A
>> "%~1" echo MwBOADAAYwBtADkAcgBaAFMAMQBzAGEAVwA1AGwAWQAyAEYAdwBPAG4ASgB2AGQA
>> "%~1" echo VwA1AGsATwAzAE4AMABjAG0AOQByAFoAUwAxAHMAYQBXADUAbABhAG0AOQBwAGIA
>> "%~1" echo agBwAHkAYgAzAFYAdQBaAEgAMABOAEMAaQA1AHUAWQBYAFoANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAGgAYwBEAG8AegBjAEgAZwA3AGMA
>> "%~1" echo RwBGAGsAWgBHAGwAdQBaAHoAbwB4AE4ASABCADQASQBEAEUAeQBjAEgAZwA3AGIA
>> "%~1" echo MwBaAGwAYwBtAFoAcwBiADMAYwA2AFkAWABWADAAYgAzADAATgBDAGkANQB1AFkA
>> "%~1" echo WABZAGcAWQBYAHQAbwBaAFcAbABuAGEASABRADYATgBEAEIAdwBlAEQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBqAGwAdwBlAEQAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEA
>> "%~1" echo WABSAGwAYgBYAE0ANgBZADIAVgB1AGQARwBWAHkATwAyAGQAaABjAEQAbwB4AE0A
>> "%~1" echo WABCADQATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBDAEEAeABNADMAQgA0AE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsA
>> "%~1" echo VAB0ADAAWgBYAGgAMABMAFcAUgBsAFkAMgA5AHkAWQBYAFIAcABiADIANAA2AGIA
>> "%~1" echo bQA5AHUAWgBUAHQAbQBiADIANQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwAzAE0A
>> "%~1" echo RABBADcAZABIAEoAaABiAG4ATgBwAGQARwBsAHYAYgBqAHAAaQBZAFcATgByAFoA
>> "%~1" echo MwBKAHYAZABXADUAawBJAEMANAB4AE4AWABNAHMAWQAyADkAcwBiADMASQBnAEwA
>> "%~1" echo agBFADEAYwAzADAATgBDAGkANQB1AFkAWABZAGcAWQBTAEIAegBkAG0AZAA3AGQA
>> "%~1" echo MgBsAGsAZABHAGcANgBNAFQAaAB3AGUARAB0AG8AWgBXAGwAbgBhAEgAUQA2AE0A
>> "%~1" echo VABoAHcAZQBIADAAdQBiAG0ARgAyAEkARwBFADYAYQBHADkAMgBaAFgASgA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwAHkAWgAyAEoAaABLAEQARQAwAE8A
>> "%~1" echo QwB3AHgATgBqAE0AcwBNAFQAZwAwAEwAQwA0AHgATQBpAGsANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGQARwBWADQAZABDAGwAOQBEAFEAbwB1AGIA
>> "%~1" echo bQBGADIASQBHAEUAdQBZAFcATgAwAGEAWABaAGwAZQAyAEoAaABZADIAdABuAGMA
>> "%~1" echo bQA5ADEAYgBtAFEANgBjAG0AZABpAFkAUwBnAHoATgB5AHcANQBPAFMAdwB5AE0A
>> "%~1" echo egBVAHMATABqAEUAeQBLAFQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABLAFgAMABOAEMAaQA1AHUAWQBYAFoARwBiADIAOQAwAGUA
>> "%~1" echo MgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYAWQBYAFYAMABiAHoAdAB3AFkA
>> "%~1" echo VwBSAGsAYQBXADUAbgBPAGoARQAwAGMASABnAGcATQBUAGgAdwBlAEQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkAdABkAEcAOQB3AE8AagBGAHcAZQBDAEIAegBiADIAeABwAFoA
>> "%~1" echo QwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxAHoAYQBYAHAAbABPAGoARQB5AGMASABnADcAYgBHAGwAdQBaAFMAMQBvAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBNAFMANAAxAGYAUQAwAEsATABtADEAaABhAFcANQA3AFoA
>> "%~1" echo MwBKAHAAWgBDADEAagBiADIAeAAxAGIAVwA0ADYATQBqAHQAdABhAFcANAB0AGQA
>> "%~1" echo MgBsAGsAZABHAGcANgBNAEQAdAB0AGEAVwA0AHQAYQBHAFYAcABaADIAaAAwAE8A
>> "%~1" echo agBFAHcATQBIAFoAbwBmAFEAMABLAEwAbgBSAHYAYwBIAHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATgB6AGgAdwBlAEQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcATgBoAGMAbQBRAHAATwAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo aQAxAGkAYgAzAFIAMABiADIAMAA2AE0AWABCADQASQBIAE4AdgBiAEcAbABrAEkA
>> "%~1" echo SABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADYAWgBtAHgAbABlAEQAdABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMA
>> "%~1" echo egBwAGoAWgBXADUAMABaAFgASQA3AGEAbgBWAHoAZABHAGwAbQBlAFMAMQBqAGIA
>> "%~1" echo MgA1ADAAWgBXADUAMABPAG4ATgB3AFkAVwBOAGwATABXAEoAbABkAEgAZABsAFoA
>> "%~1" echo VwA0ADcAYwBHAEYAawBaAEcAbAB1AFoAegBvAHcASQBEAEkAMgBjAEgAZwA3AGMA
>> "%~1" echo RwA5AHoAYQBYAFIAcABiADIANAA2AGMAMwBSAHAAWQAyAHQANQBPADMAUgB2AGMA
>> "%~1" echo RABvAHcATwAzAG8AdABhAFcANQBrAFoAWABnADYATQAzADAATgBDAGkANQAwAGEA
>> "%~1" echo WABSAHMAWgBTAEIAbwBNAFgAdAB0AFkAWABKAG4AYQBXADQANgBNAEQAdABtAGIA
>> "%~1" echo MgA1ADAATABYAE4AcABlAG0AVQA2AE0AagBGAHcAZQBIADAAdQBkAEcAbAAwAGIA
>> "%~1" echo RwBVAGcAYwBIAHQAdABZAFgASgBuAGEAVwA0ADYATgBYAEIANABJAEQAQQBnAE0A
>> "%~1" echo RAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAdABkAFgAUgBsAFoA
>> "%~1" echo QwBrADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAegBjAEgAaAA5AEQA
>> "%~1" echo UQBvAHUAZABHADkAdgBiAEcASgBoAGMAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBaAHMAWgBYAGcANwBZAFcAeABwAFoAMgA0AHQAYQBYAFIAbABiAFgATQA2AFkA
>> "%~1" echo MgBWAHUAZABHAFYAeQBPADIAZABoAGMARABvADQAYwBIAGcANwBaAG0AeABsAGUA
>> "%~1" echo QwAxADMAYwBtAEYAdwBPAG4AZAB5AFkAWABBADcAYQBuAFYAegBkAEcAbABtAGUA
>> "%~1" echo UwAxAGoAYgAyADUAMABaAFcANQAwAE8AbQBaAHMAWgBYAGcAdABaAFcANQBrAGYA
>> "%~1" echo UQAwAEsATABtAE4AbwBhAFgAQQBzAEwAbQBKADAAYgBuAHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATQB6AFoAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkA
>> "%~1" echo SABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8A
>> "%~1" echo MgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMA
>> "%~1" echo MgA5AG0AZABDAGsANwBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGQA
>> "%~1" echo RwBWADQAZABDAGsANwBZAG0AOQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMA
>> "%~1" echo egBvADUAYwBIAGcANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AdwBJAEQARQB5AGMA
>> "%~1" echo SABnADcAWgBHAGwAegBjAEcAeABoAGUAVABwAHAAYgBtAHgAcABiAG0AVQB0AFoA
>> "%~1" echo bQB4AGwAZQBEAHQAaABiAEcAbABuAGIAaQAxAHAAZABHAFYAdABjAHoAcABqAFoA
>> "%~1" echo VwA1ADAAWgBYAEkANwBaADIARgB3AE8AagBkAHcAZQBEAHQAbQBiADIANQAwAEwA
>> "%~1" echo WABkAGwAYQBXAGQAbwBkAEQAbwAzAE0ARABCADkARABRAG8AdQBZADIAaABwAGMA
>> "%~1" echo RQBSAHYAZABIAHQAMwBhAFcAUgAwAGEARABvADQAYwBIAGcANwBhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAGgAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEA
>> "%~1" echo WABWAHoATwBqAFUAdwBKAFQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFgASgBsAFoAQwBrADcAWQBtADkANABMAFgATgBvAFkA
>> "%~1" echo VwBSAHYAZAB6AG8AdwBJAEQAQQBnAE0AQwBBAHoAYwBIAGcAZwBjAG0AZABpAFkA
>> "%~1" echo UwBnAHkATQBqAFUAcwBNAGoAawBzAE4AegBJAHMATABqAEUAMQBLAFgAMABOAEMA
>> "%~1" echo aQA1AGoAYgAyADUAdQBaAFcATgAwAFoAVwBRAGcATABtAE4AbwBhAFgAQgBFAGIA
>> "%~1" echo MwBSADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAG4AYwBtAFYAbABiAGkAawA3AFkAbQA5ADQATABYAE4AbwBZAFcAUgB2AGQA
>> "%~1" echo egBvAHcASQBEAEEAZwBNAEMAQQB6AGMASABnAGcAYwBtAGQAaQBZAFMAZwB5AE0A
>> "%~1" echo aQB3AHgATgBqAE0AcwBOAHoAUQBzAEwAagBFADEASwBYADAATgBDAGkANQBpAGQA
>> "%~1" echo RwA1ADcAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBXADUAMABaAFgASQA3AGQA
>> "%~1" echo SABKAGgAYgBuAE4AcABkAEcAbAB2AGIAagBwADAAYwBtAEYAdQBjADIAWgB2AGMA
>> "%~1" echo bQAwAGcATABqAEEANABjAHkAeABtAGEAVwB4ADAAWgBYAEkAZwBMAGoARQAxAGMA
>> "%~1" echo MwAwAHUAWQBuAFIAdQBPAG0AaAB2AGQAbQBWAHkAZQAyAFoAcABiAEgAUgBsAGMA
>> "%~1" echo agBwAGkAYwBtAGwAbgBhAEgAUgB1AFoAWABOAHoASwBEAEUAdQBNAEQATQBwAGYA
>> "%~1" echo UwA1AGkAZABHADQANgBZAFcATgAwAGEAWABaAGwAZQAzAFIAeQBZAFcANQB6AFoA
>> "%~1" echo bQA5AHkAYgBUAHAAMABjAG0ARgB1AGMAMgB4AGgAZABHAFYAWgBLAEQARgB3AGUA
>> "%~1" echo QwBsADkARABRAG8AdQBZAG4AUgB1AEwAbgBCAHkAYQBXADEAaABjAG4AbAA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQBpAGIA
>> "%~1" echo SABWAGwASwBUAHQAaQBiADMASgBrAFoAWABJAHQAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABZAG0AeAAxAFoAUwBrADcAWQAyADkAcwBiADMASQA2AEkA
>> "%~1" echo MgBaAG0AWgBuADAAdQBZAG4AUgB1AEwAbQBkAG8AYgAzAE4AMABlADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGQASABKAGgAYgBuAE4AdwBZAFgASgBsAGIA
>> "%~1" echo bgBSADkARABRAG8AdQBkADMASgBoAGMASAB0AHcAWQBXAFIAawBhAFcANQBuAE8A
>> "%~1" echo agBJAHcAYwBIAGcAZwBNAGoAWgB3AGUAQwBBADAATQBIAEIANABPADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaAG0AeABsAGUARAB0AG0AYgBHAFYANABMAFcAUgBwAGMA
>> "%~1" echo bQBWAGoAZABHAGwAdgBiAGoAcABqAGIAMgB4ADEAYgBXADQANwBaADIARgB3AE8A
>> "%~1" echo agBFADEAYwBIAGcANwBiAFcARgA0AEwAWABkAHAAWgBIAFIAbwBPAGoARQAxAE0A
>> "%~1" echo agBCAHcAZQBIADAATgBDAGkANQB1AGIAMwBSAHAAWQAyAFYANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAeQBaADIASgBoAEsA
>> "%~1" echo RABJAHgATgB5AHcAeABNAFQAawBzAE4AaQB3AHUATQB6AEEAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAeQBNAFQAYwBzAE0A
>> "%~1" echo VABFADUATABEAFkAcwBMAGoAQQAzAEsAVAB0AGoAYgAyAHgAdgBjAGoAbwBqAFkA
>> "%~1" echo agBNADIATgBUAEEAMQBPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQA
>> "%~1" echo WABNADYATQBUAEIAdwBlAEQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoARQB4AGMA
>> "%~1" echo SABnAGcATQBUAFIAdwBlAEQAdABtAGIAMgA1ADAATABYAGQAbABhAFcAZABvAGQA
>> "%~1" echo RABvADMATQBEAEEANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0A
>> "%~1" echo UwA0ADEAZgBRADAASwBZAG0AOQBrAGUAUwA1AGsAWQBYAEoAcgBJAEMANQB1AGIA
>> "%~1" echo MwBSAHAAWQAyAFYANwBZADIAOQBzAGIAMwBJADYASQAyAFkAMABZAHoAQQAyAFkA
>> "%~1" echo WAAwAE4AQwBpADUAdwBZAFcAZABsAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AGIA
>> "%~1" echo bQA5AHUAWgBYADAAdQBjAEcARgBuAFoAUwA1AGgAWQAzAFIAcABkAG0AVgA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABuAGMAbQBsAGsATwAyAGQAaABjAEQAbwB4AE4A
>> "%~1" echo WABCADQAZgBRADAASwBMAG4ASgB2AGQAMwB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBkAHkAYQBXAFEANwBaADMASgBwAFoAQwAxADAAWgBXADEAdwBiAEcARgAwAFoA
>> "%~1" echo UwAxAGoAYgAyAHgAMQBiAFcANQB6AE8AagBGAG0AYwBpAEEAeABaAG4ASQA3AFoA
>> "%~1" echo MgBGAHcATwBqAEUAMQBjAEgAaAA5AEwAbgBKAHYAZAB6AE4ANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMA
>> "%~1" echo RwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AHAAeQBaAFgAQgBsAFkA
>> "%~1" echo WABRAG8ATQB5AHcAeABaAG4ASQBwAE8AMgBkAGgAYwBEAG8AeABOAFgAQgA0AGYA
>> "%~1" echo UQAwAEsATABtAE4AaABjAG0AUgA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoA
>> "%~1" echo RABwADIAWQBYAEkAbwBMAFMAMQBqAFkAWABKAGsASwBUAHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQA
>> "%~1" echo WABNADYAZABtAEYAeQBLAEMAMAB0AGMAbQBGAGsAYQBYAFYAegBLAFQAdAB2AGQA
>> "%~1" echo bQBWAHkAWgBtAHgAdgBkAHoAcABvAGEAVwBSAGsAWgBXADQANwBZAG0AOQA0AEwA
>> "%~1" echo WABOAG8AWQBXAFIAdgBkAHoAcAAyAFkAWABJAG8ATABTADEAegBhAEcARgBrAGIA
>> "%~1" echo MwBjAHAAZgBRADAASwBMAG0AaABsAFkAVwBSADcAYQBHAFYAcABaADIAaAAwAE8A
>> "%~1" echo agBRADQAYwBIAGcANwBZAG0AOQB5AFoARwBWAHkATABXAEoAdgBkAEgAUgB2AGIA
>> "%~1" echo VABvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBTAGsANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbQBiAEcAVgA0AE8A
>> "%~1" echo MgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMA
>> "%~1" echo agB0AHEAZABYAE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4AUQA2AGMA
>> "%~1" echo MwBCAGgAWQAyAFUAdABZAG0AVgAwAGQAMgBWAGwAYgBqAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEEAZwBNAFQAWgB3AGUASAAwAE4AQwBpADUAbwBaAFcARgBrAEkA
>> "%~1" echo RwBnAHkAZQAyADEAaABjAG0AZABwAGIAagBvAHcATwAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeABOAFgAQgA0AGYAUwA1ADAAWQBXAGQANwBhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAEkAMQBjAEgAZwA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABwAGIA
>> "%~1" echo bQB4AHAAYgBtAFUAdABaAG0AeABsAGUARAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQA
>> "%~1" echo RwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAWQBtADkAeQBaAEcAVgB5AE8A
>> "%~1" echo agBGAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEA
>> "%~1" echo VwA1AGwASwBUAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAE4AdgBaAG4AUQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkA
>> "%~1" echo VwBSAHAAZABYAE0ANgBPAFQAawA1AGMASABnADcAYwBHAEYAawBaAEcAbAB1AFoA
>> "%~1" echo egBvAHcASQBEAEUAdwBjAEgAZwA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoA
>> "%~1" echo VABvAHgATQBuAEIANABmAFEAMABLAEwAbQBKAHYAWgBIAGwANwBjAEcARgBrAFoA
>> "%~1" echo RwBsAHUAWgB6AG8AeABOAG4AQgA0AGYAUQAwAEsATABtAFIAbABkAG0AbABqAFoA
>> "%~1" echo VQBsAGoAYgAyADUANwBkADIAbABrAGQARwBnADYATgB6AEIAdwBlAEQAdABvAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBOAHoAQgB3AGUARAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBGAGsAYQBYAFYAegBPAGoARQAwAGMASABnADcAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VABwAG4AYwBtAGwAawBPADMAQgBzAFkAVwBOAGwATABXAGwAMABaAFcAMQB6AE8A
>> "%~1" echo bQBOAGwAYgBuAFIAbABjAGoAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBKAG4AWQBtAEUAbwBNAHoAYwBzAE8AVABrAHMATQBqAE0AMQBMAEMANAB4AE0A
>> "%~1" echo QwBrADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAG0AeAAxAFoA
>> "%~1" echo UwBsADkATABtAFIAbABkAG0AbABqAFoAVQBsAGoAYgAyADQAZwBjADMAWgBuAGUA
>> "%~1" echo MwBkAHAAWgBIAFIAbwBPAGoAUQAwAGMASABnADcAYQBHAFYAcABaADIAaAAwAE8A
>> "%~1" echo agBRADAAYwBIAGgAOQBEAFEAbwB1AGEARwBWAGgAWgBIAE4AbABkAEUASgB2AGUA
>> "%~1" echo SAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMASgBwAFoA
>> "%~1" echo QwAxADAAWgBXADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8A
>> "%~1" echo agBjAHcAYwBIAGcAZwBNAFcAWgB5AE8AMgBkAGgAYwBEAG8AeABOAEgAQgA0AE8A
>> "%~1" echo MgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMA
>> "%~1" echo bgAwAE4AQwBpADUAawBaAFgAWgBwAFkAMgBWAE8AWQBXADEAbABlADIAWgB2AGIA
>> "%~1" echo bgBRAHQAYwAyAGwANgBaAFQAbwB5AE0AbgBCADQATwAyAFoAdgBiAG4AUQB0AGQA
>> "%~1" echo MgBWAHAAWgAyAGgAMABPAGoAZwB3AE0ASAAwAHUAYQBHAGwAdQBkAEgAdAB0AFkA
>> "%~1" echo WABKAG4AYQBXADQAdABkAEcAOQB3AE8AagBkAHcAZQBEAHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBiAEcAbAB1AFoA
>> "%~1" echo UwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0AUwA0ADEATgBYADAATgBDAGkANQB6AGQA
>> "%~1" echo RwBGADAAWgBYAHQAdABZAFgASgBuAGEAVwA0AHQAZABHADkAdwBPAGoAaAB3AGUA
>> "%~1" echo RAB0AG0AYgAyADUAMABMAFgATgBwAGUAbQBVADYATQBqAFIAdwBlAEQAdABtAGIA
>> "%~1" echo MgA1ADAATABYAGQAbABhAFcAZABvAGQARABvADUATQBEAEEANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAAdQBjADMAUgBoAGQA
>> "%~1" echo RwBVAHUAWgAyADkAdgBaAEgAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAG4AYwBtAFYAbABiAGkAbAA5AEQAUQBvAHUAYwBtAGwAbgBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AYwBtAGwAawBMAFgAUgBsAGIA
>> "%~1" echo WABCAHMAWQBYAFIAbABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AEkA
>> "%~1" echo RABFAHUATQAyAFoAeQBJAEQARgBtAGMAagB0AG4AWQBYAEEANgBNAFQASgB3AGUA
>> "%~1" echo RAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQARwBWAHQAYwB6AHAAagBaAFcANQAwAFoA
>> "%~1" echo WABJADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8AeABOAG4AQgA0AGYA
>> "%~1" echo UQAwAEsATABtAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoAQwBiADMAaAA3AGIA
>> "%~1" echo VwBsAHUATABXAGgAbABhAFcAZABvAGQARABvADMATwBIAEIANABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoA
>> "%~1" echo RwBsADEAYwB6AG8AeABNAEgAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBjAEcARgBrAFoA
>> "%~1" echo RwBsAHUAWgB6AG8AeABNAFgAQgA0AEkARABFAHoAYwBIAGcANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBGAHMAYQBXAGQAdQBMAFcATgB2AGIA
>> "%~1" echo bgBSAGwAYgBuAFEANgBZADIAVgB1AGQARwBWAHkATwAyAGQAaABjAEQAbwAxAGMA
>> "%~1" echo SABoADkARABRAG8AdQBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGsASgB2AGUA
>> "%~1" echo QwBBAHUAYwBtADkAcwBaAFgAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8A
>> "%~1" echo agBFAHkAYwBIAGgAOQBMAG0ATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBDAGIA
>> "%~1" echo MwBnAGcAWQBuAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAGoAQgB3AGUA
>> "%~1" echo SAAwAHUAWQAyADkAdQBkAEgASgB2AGIARwB4AGwAYwBrAEoAdgBlAEMAQQB1AGMA
>> "%~1" echo MwBSAGgAZABHAFYAVQBaAFgAaAAwAGUAMgBaAHYAYgBuAFEAdABjADIAbAA2AFoA
>> "%~1" echo VABvAHgATQBuAEIANABPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwAxADEAZABHAFYAawBLAFgAMABOAEMAaQA1AGoAYgAyADUAMABjAG0AOQBzAGIA
>> "%~1" echo RwBWAHkAUQBtADkANABMAG0AeABsAFoAbgBSADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo VwB4AGwAWgBuAFEANgBNADMAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAEoAcwBkAFcAVQBwAGYAUwA1AGoAYgAyADUAMABjAG0AOQBzAGIA
>> "%~1" echo RwBWAHkAUQBtADkANABMAG4ASgBwAFoAMgBoADAAZQAzAFIAbABlAEgAUQB0AFkA
>> "%~1" echo VwB4AHAAWgAyADQANgBjAG0AbABuAGEASABRADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo WABKAHAAWgAyAGgAMABPAGoATgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkA
>> "%~1" echo WABJAG8ATABTADEAaQBiAEgAVgBsAEsAWAAwAE4AQwBpADUAdABaAFgAUgBoAFMA
>> "%~1" echo WABSAGwAYgBYAHQAaQBiADMASgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIA
>> "%~1" echo RwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATwBYAEIANABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQA
>> "%~1" echo QwBrADcAYwBHAEYAawBaAEcAbAB1AFoAegBvAHgATQBIAEIANABJAEQARQB5AGMA
>> "%~1" echo SABoADkATABtADEAbABkAEcARgBKAGQARwBWAHQASQBIAE4AdwBZAFcANQA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABpAGIARwA5AGoAYQB6AHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxAHoAYQBYAHAAbABPAGoARQB5AGMASABoADkATABtADEAbABkAEcARgBKAGQA
>> "%~1" echo RwBWAHQASQBHAEoANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEA
>> "%~1" echo egB0AHQAWQBYAEoAbgBhAFcANAB0AGQARwA5AHcATwBqAFYAdwBlAEQAdAAzAGEA
>> "%~1" echo RwBsADAAWgBTADEAegBjAEcARgBqAFoAVABwAHUAYgAzAGQAeQBZAFgAQQA3AGIA
>> "%~1" echo MwBaAGwAYwBtAFoAcwBiADMAYwA2AGEARwBsAGsAWgBHAFYAdQBPADMAUgBsAGUA
>> "%~1" echo SABRAHQAYgAzAFoAbABjAG0AWgBzAGIAMwBjADYAWgBXAHgAcwBhAFgAQgB6AGEA
>> "%~1" echo WABOADkARABRAG8AdQBiAFcAVgAwAGMAbQBsAGoAUgAzAEoAcABaAEgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAG4ASgBsAGMA
>> "%~1" echo RwBWAGgAZABDAGcAegBMAEQARgBtAGMAaQBrADcAWgAyAEYAdwBPAGoARQB5AGMA
>> "%~1" echo SABoADkARABRAG8AdQBiAFcAVgAwAGMAbQBsAGoAZQAyAGgAbABhAFcAZABvAGQA
>> "%~1" echo RABvAHgATQBUAFoAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkA
>> "%~1" echo SABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8A
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBNAFQAQgB3AGUA
>> "%~1" echo RAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo WABOAHYAWgBuAFEAcABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQAUgB3AGUA
>> "%~1" echo RAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMASgBwAFoA
>> "%~1" echo QwAxADAAWgBXADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8A
>> "%~1" echo agBjAHcAYwBIAGcAZwBNAFcAWgB5AE8AMgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoA
>> "%~1" echo VwAxAHoATwBtAE4AbABiAG4AUgBsAGMAagB0AG4AWQBYAEEANgBNAFQARgB3AGUA
>> "%~1" echo SAAwAE4AQwBpADUAdABaAFgAUgB5AGEAVwBNAGcAYwAzAFoAbgBMAG4ASgBwAGIA
>> "%~1" echo bQBkADcAZAAyAGwAawBkAEcAZwA2AE4AegBCAHcAZQBEAHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATgB6AEIAdwBlAEQAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGMA
>> "%~1" echo bQA5ADAAWQBYAFIAbABLAEMAMAA1AE0ARwBSAGwAWgB5AGwAOQBMAG4AUgB5AFkA
>> "%~1" echo VwBOAHIAZQAyAFoAcABiAEcAdwA2AGIAbQA5AHUAWgBUAHQAegBkAEgASgB2AGEA
>> "%~1" echo MgBVADYAYwBtAGQAaQBZAFMAZwB4AE4ARABnAHMATQBUAFkAegBMAEQARQA0AE4A
>> "%~1" echo QwB3AHUATQBqAFUAcABPADMATgAwAGMAbQA5AHIAWgBTADEAMwBhAFcAUgAwAGEA
>> "%~1" echo RABvADQAZgBTADUAdABaAFgAUgBsAGMAbgB0AG0AYQBXAHgAcwBPAG0ANQB2AGIA
>> "%~1" echo bQBVADcAYwAzAFIAeQBiADIAdABsAE8AbgBaAGgAYwBpAGcAdABMAFcASgBzAGQA
>> "%~1" echo VwBVAHAATwAzAE4AMABjAG0AOQByAFoAUwAxADMAYQBXAFIAMABhAEQAbwA0AE8A
>> "%~1" echo MwBOADAAYwBtADkAcgBaAFMAMQBzAGEAVwA1AGwAWQAyAEYAdwBPAG4ASgB2AGQA
>> "%~1" echo VwA1AGsATwAzAFIAeQBZAFcANQB6AGEAWABSAHAAYgAyADQANgBjADMAUgB5AGIA
>> "%~1" echo MgB0AGwATABXAFIAaABjADIAaABoAGMAbgBKAGgAZQBTAEEAdQBOAFgATQBnAFoA
>> "%~1" echo VwBGAHoAWgBYADAATgBDAGkANQB0AFoAWABSAHkAYQBXAE0AdQBaADMASgBsAFoA
>> "%~1" echo VwA0AGcATABtADEAbABkAEcAVgB5AGUAMwBOADAAYwBtADkAcgBaAFQAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAbgBjAG0AVgBsAGIAaQBsADkATABtADEAbABkAEgASgBwAFkA
>> "%~1" echo eQA1AGgAYgBXAEoAbABjAGkAQQB1AGIAVwBWADAAWgBYAEoANwBjADMAUgB5AGIA
>> "%~1" echo MgB0AGwATwBuAFoAaABjAGkAZwB0AEwAVwBGAHQAWQBtAFYAeQBLAFgAMAB1AGIA
>> "%~1" echo VwBWADAAYwBtAGwAagBMAG4ASgBsAFoAQwBBAHUAYgBXAFYAMABaAFgASgA3AGMA
>> "%~1" echo MwBSAHkAYgAyAHQAbABPAG4AWgBoAGMAaQBnAHQATABYAEoAbABaAEMAbAA5AEQA
>> "%~1" echo UQBvAHUAYgBXAFYAMABjAG0AbABqAFYAbQBGAHMAZABXAFYANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxAHoAYQBYAHAAbABPAGoASQB6AGMASABnADcAWgBtADkAdQBkAEMAMQAzAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBPAFQAQQB3AE8AMwBkAG8AYQBYAFIAbABMAFgATgB3AFkA
>> "%~1" echo VwBOAGwATwBtADUAdgBkADMASgBoAGMASAAwAHUAYgBXAFYAMABjAG0AbABqAFQA
>> "%~1" echo RwBGAGkAWgBXAHgANwBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwAyAGMA
>> "%~1" echo SABnADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNAG4AQgA0AGYA
>> "%~1" echo UQAwAEsATABtAGwAdQBaAG0AOQBIAGMAbQBsAGsAZQAyAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkA
>> "%~1" echo WABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYAYwBtAFYAdwBaAFcARgAwAEsA
>> "%~1" echo RABNAHMATQBXAFoAeQBLAFQAdABuAFkAWABBADYATQBUAEYAdwBlAEgAMABOAEMA
>> "%~1" echo aQA1AHAAYgBtAFoAdgBWAEcAbABzAFoAWAB0AGkAYgAzAEoAawBaAFgASQA2AE0A
>> "%~1" echo WABCADQASQBIAE4AdgBiAEcAbABrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIA
>> "%~1" echo bQBVAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8A
>> "%~1" echo WABCADQATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYwAyADkAbQBkAEMAawA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0A
>> "%~1" echo bgBCADQATwAyADEAcABiAGkAMQBvAFoAVwBsAG4AYQBIAFEANgBOAGoAQgB3AGUA
>> "%~1" echo SAAwAHUAYQBXADUAbQBiADEAUgBwAGIARwBVAGcAYwAzAEIAaABiAG4AdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAyAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcAMQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwA
>> "%~1" echo WABOAHAAZQBtAFUANgBNAFQASgB3AGUASAAwAHUAYQBXADUAbQBiADEAUgBwAGIA
>> "%~1" echo RwBVAGcAWQBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIATgByAE8A
>> "%~1" echo MgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYATgBuAEIANABPADMAZAB2AGMA
>> "%~1" echo bQBRAHQAWQBuAEoAbABZAFcAcwA2AFkAbgBKAGwAWQBXAHMAdABkADIAOQB5AFoA
>> "%~1" echo SAAwAE4AQwBpADUAbABlAEgAQgB2AGMAbgBSAEMAYgAzAGgANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMA
>> "%~1" echo RwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AG8AeABaAG4ASQBnAFkA
>> "%~1" echo WABWADAAYgB6AHQAbgBZAFgAQQA2AE0AVABSAHcAZQBEAHQAaABiAEcAbABuAGIA
>> "%~1" echo aQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAeQBaADIASgBoAEsA
>> "%~1" echo RABNADMATABEAGsANQBMAEQASQB6AE4AUwB3AHUATQB6AFUAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8A
>> "%~1" echo UwB3AHkATQB6AFUAcwBMAGoAQQAzAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBGAGsAYQBYAFYAegBPAGoARQB3AGMASABnADcAYwBHAEYAawBaAEcAbAB1AFoA
>> "%~1" echo egBvAHgATgBIAEIANABmAFEAMABLAEwAbQBWADQAYwBHADkAeQBkAEUAeABwAGIA
>> "%~1" echo bQB0AHoAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQAdABuAFkA
>> "%~1" echo WABBADYATwBIAEIANABmAFMANQBsAGUASABCAHYAYwBuAFIATQBhAFcANQByAGMA
>> "%~1" echo eQBCAGgAZQAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcASgBzAGQA
>> "%~1" echo VwBVAHAATwAyAFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAawB3AE0A
>> "%~1" echo RAB0ADMAYgAzAEoAawBMAFcASgB5AFoAVwBGAHIATwBtAEoAeQBaAFcARgByAEwA
>> "%~1" echo VwBGAHMAYgBIADAATgBDAGkANQAwAFkAVwBKAHMAWgBYAHQAMwBhAFcAUgAwAGEA
>> "%~1" echo RABvAHgATQBEAEEAbABPADIASgB2AGMAbQBSAGwAYwBpADEAagBiADIAeABzAFkA
>> "%~1" echo WABCAHoAWgBUAHAAagBiADIAeABzAFkAWABCAHoAWgBYADAAdQBkAEcARgBpAGIA
>> "%~1" echo RwBVAGcAZABHAFIANwBZAG0AOQB5AFoARwBWAHkATABXAEoAdgBkAEgAUgB2AGIA
>> "%~1" echo VABvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBTAGsANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABNAEgAQgA0AEkA
>> "%~1" echo RABBADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAzAFoAbABjAG4AUgBwAFkAMgBGAHMATABXAEYAcwBhAFcAZAB1AE8A
>> "%~1" echo bgBSAHYAYwBIADAAdQBkAEcARgBpAGIARwBVAGcAZABIAEkANgBiAEcARgB6AGQA
>> "%~1" echo QwAxAGoAYQBHAGwAcwBaAEMAQgAwAFoASAB0AGkAYgAzAEoAawBaAFgASQB0AFkA
>> "%~1" echo bQA5ADAAZABHADkAdABPAGoAQgA5AEwAbgBSAGgAWQBtAHgAbABJAEgAUgBrAE8A
>> "%~1" echo bQB4AGgAYwAzAFEAdABZADIAaABwAGIARwBSADcAZABHAFYANABkAEMAMQBoAGIA
>> "%~1" echo RwBsAG4AYgBqAHAAeQBhAFcAZABvAGQARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAMABaAFgAaAAwAEsAVAB0AG0AYgAyADUAMABMAFgAZABsAGEA
>> "%~1" echo VwBkAG8AZABEAG8AMwBNAEQAQQA3AGQAMgA5AHkAWgBDADEAaQBjAG0AVgBoAGEA
>> "%~1" echo egBwAGkAYwBtAFYAaABhAHkAMQAzAGIAMwBKAGsAZgBRADAASwBMAG0ATgB0AFoA
>> "%~1" echo RQBkAHkAYQBXAFIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8A
>> "%~1" echo MgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQA
>> "%~1" echo VwAxAHUAYwB6AHAAeQBaAFgAQgBsAFkAWABRAG8ATQBpAHgAdABhAFcANQB0AFkA
>> "%~1" echo WABnAG8ATQBDAHcAeABaAG4ASQBwAEsAVAB0AG4AWQBYAEEANgBNAFQARgB3AGUA
>> "%~1" echo SAAwAE4AQwBpADUAagBiAFcAUgA3AGIAVwBsAHUATABXAGgAbABhAFcAZABvAGQA
>> "%~1" echo RABvADIATQBIAEIANABPADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMA
>> "%~1" echo MgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcAeABsAFoAbgBRADYATQAzAEIANABJAEgATgB2AGIA
>> "%~1" echo RwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQA
>> "%~1" echo QwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwA1AGMA
>> "%~1" echo SABnADcAZABHAFYANABkAEMAMQBoAGIARwBsAG4AYgBqAHAAcwBaAFcAWgAwAE8A
>> "%~1" echo MwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABGAHcAZQBDAEEAeABNADMAQgA0AE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIAbABlAEgAUQBwAE8A
>> "%~1" echo MgBOADEAYwBuAE4AdgBjAGoAcAB3AGIAMgBsAHUAZABHAFYAeQBPADMAUgB5AFkA
>> "%~1" echo VwA1AHoAYQBYAFIAcABiADIANAA2AGQASABKAGgAYgBuAE4AbQBiADMASgB0AEkA
>> "%~1" echo QwA0AHcATwBIAE0AcwBaAG0AbABzAGQARwBWAHkASQBDADQAeABOAFgATgA5AEwA
>> "%~1" echo bQBOAHQAWgBEAHAAbwBiADMAWgBsAGMAbgB0AG0AYQBXAHgAMABaAFgASQA2AFkA
>> "%~1" echo bgBKAHAAWgAyAGgAMABiAG0AVgB6AGMAeQBnAHgATABqAEEAegBLAFgAMAB1AFkA
>> "%~1" echo MgAxAGsATwBtAEYAagBkAEcAbAAyAFoAWAB0ADAAYwBtAEYAdQBjADIAWgB2AGMA
>> "%~1" echo bQAwADYAZABIAEoAaABiAG4ATgBzAFkAWABSAGwAVwBTAGcAeABjAEgAZwBwAGYA
>> "%~1" echo UQAwAEsATABtAE4AdABaAEMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFkA
>> "%~1" echo bQB4AHYAWQAyAHQAOQBMAG0ATgB0AFoAQwBCAHoAYwBHAEYAdQBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgBzADcAYgBXAEYAeQBaADIAbAB1AEwA
>> "%~1" echo WABSAHYAYwBEAG8AMABjAEgAZwA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoA
>> "%~1" echo VABvAHgATQBuAEIANABmAFEAMABLAEwAbQBOAHQAWgBDADUAaQBiAEgAVgBsAGUA
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQBzAFoAVwBaADAATABXAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAAZgBTADUAagBiAFcAUQB1AFoA
>> "%~1" echo MwBKAGwAWgBXADUANwBZAG0AOQB5AFoARwBWAHkATABXAHgAbABaAG4AUQB0AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWgAzAEoAbABaAFcANABwAGYA
>> "%~1" echo UwA1AGoAYgBXAFEAdQBZAFcAMQBpAFoAWABKADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo VwB4AGwAWgBuAFEAdABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFkA
>> "%~1" echo VwAxAGkAWgBYAEkAcABmAFMANQBqAGIAVwBRAHUAYwBtAFYAawBlADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAcwBaAFcAWgAwAEwAVwBOAHYAYgBHADkAeQBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAEoAbABaAEMAbAA5AEQAUQBvAHUAWgBtADkAeQBiAFgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAGoARQB6AE0A
>> "%~1" echo SABCADQASQBEAEYAbQBjAGkAQQB4AFoAbgBJAGcATwBUAEIAdwBlAEQAdABuAFkA
>> "%~1" echo WABBADYATQBUAEIAdwBlAEgAMABOAEMAbQBsAHUAYwBIAFYAMABMAEgATgBsAGIA
>> "%~1" echo RwBWAGoAZABIAHQAbwBaAFcAbABuAGEASABRADYATQB6AGgAdwBlAEQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkA
>> "%~1" echo VwBSAHAAZABYAE0ANgBPAFgAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGQARwBWADQAZABDAGsANwBjAEcARgBrAFoA
>> "%~1" echo RwBsAHUAWgB6AG8AdwBJAEQARQB4AGMASABoADkARABRAHAAcABiAG4AQgAxAGQA
>> "%~1" echo RABwAG0AYgAyAE4AMQBjAHkAeAB6AFoAVwB4AGwAWQAzAFEANgBaAG0AOQBqAGQA
>> "%~1" echo WABOADcAYgAzAFYAMABiAEcAbAB1AFoAVABwAHUAYgAyADUAbABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQBpAGIA
>> "%~1" echo SABWAGwASwBUAHQAaQBiADMAZwB0AGMAMgBoAGgAWgBHADkAMwBPAGoAQQBnAE0A
>> "%~1" echo QwBBAHcASQBEAE4AdwBlAEMAQgB5AFoAMgBKAGgASwBEAE0AMwBMAEQAawA1AEwA
>> "%~1" echo RABJAHoATgBTAHcAdQBNAFQAVQBwAGYAUQAwAEsATABtAHgAdgBaADMAdAAzAGEA
>> "%~1" echo RwBsADAAWgBTADEAegBjAEcARgBqAFoAVABwAHcAYwBtAFUAdABkADMASgBoAGMA
>> "%~1" echo RAB0AHQAYQBXADQAdABhAEcAVgBwAFoAMgBoADAATwBqAGcAdwBjAEgAZwA3AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8A
>> "%~1" echo MgBaAHYAYgBuAFEAdABaAG0ARgB0AGEAVwB4ADUATwBrAE4AdgBiAG4ATgB2AGIA
>> "%~1" echo RwBGAHoATABDAEoATgBhAFcATgB5AGIAMwBOAHYAWgBuAFEAZwBXAFcARgBJAFoA
>> "%~1" echo VwBrAGkATABHADEAdgBiAG0AOQB6AGMARwBGAGoAWgBUAHQAcwBhAFcANQBsAEwA
>> "%~1" echo VwBoAGwAYQBXAGQAbwBkAEQAbwB4AEwAagBVADEATwAzAGQAdgBjAG0AUQB0AFkA
>> "%~1" echo bgBKAGwAWQBXAHMANgBZAG4ASgBsAFkAVwBzAHQAZAAyADkAeQBaAEgAMABOAEMA
>> "%~1" echo aQA4AHEASQBDADAAdABMAFMAQgBCAFUARQBzAGcAYQBXADUAegBkAEcARgBzAGIA
>> "%~1" echo RwBWAHkATwBpAEIAQgBjAEgAQQBnAFUAMwBSAHYAYwBtAFUAZwBaAEcAVgAwAFkA
>> "%~1" echo VwBsAHMASQBHAE4AaABjAG0AUQBnAEwAUwAwAHQASQBDAG8AdgBEAFEAbwB1AFkA
>> "%~1" echo WABCAHcAVgAzAEoAaABjAEgAdAB0AFkAWABnAHQAZAAyAGwAawBkAEcAZwA2AE4A
>> "%~1" echo agBBAHcAYwBIAGcANwBiAFcARgB5AFoAMgBsAHUATwBqAEEAZwBZAFgAVgAwAGIA
>> "%~1" echo egB0ADMAYQBXAFIAMABhAEQAbwB4AE0ARABBAGwAZgBRADAASwBMAG0ARgB3AGMA
>> "%~1" echo RQBOAGgAYwBtAFIANwBZAG0AOQB5AFoARwBWAHkATwBqAEYAdwBlAEMAQgB6AGIA
>> "%~1" echo MgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBqAEUAMgBjAEgAZwA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwAHMAYQBXADUAbABZAFgASQB0AFoA
>> "%~1" echo MwBKAGgAWgBHAGwAbABiAG4AUQBvAE0AVABnAHcAWgBHAFYAbgBMAEgASgBuAFkA
>> "%~1" echo bQBFAG8ATQB6AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAdwBOAFMAawBzAGQA
>> "%~1" echo bQBGAHkASwBDADAAdABZADIARgB5AFoAQwBrAGcATQBUAEkAdwBjAEgAZwBwAE8A
>> "%~1" echo MgBKAHYAZQBDADEAegBhAEcARgBrAGIAMwBjADYAZABtAEYAeQBLAEMAMAB0AGMA
>> "%~1" echo MgBoAGgAWgBHADkAMwBLAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoASQB5AGMA
>> "%~1" echo SABnADcAWQBXADUAcABiAFcARgAwAGEAVwA5AHUATwBtAE4AaABjAG0AUgBKAGIA
>> "%~1" echo aQBBAHUATgBIAE0AZwBZADMAVgBpAGEAVwBNAHQAWQBtAFYANgBhAFcAVgB5AEsA
>> "%~1" echo QwA0AHkATABDADQANABMAEMANAB5AEwARABFAHAAZgBRADAASwBRAEcAdABsAGUA
>> "%~1" echo VwBaAHkAWQBXADEAbABjAHkAQgBqAFkAWABKAGsAUwBXADUANwBaAG4ASgB2AGIA
>> "%~1" echo WAB0AHYAYwBHAEYAagBhAFgAUgA1AE8AagBBADcAZABIAEoAaABiAG4ATgBtAGIA
>> "%~1" echo MwBKAHQATwBuAFIAeQBZAFcANQB6AGIARwBGADAAWgBWAGsAbwBNAFQAUgB3AGUA
>> "%~1" echo QwBsADkAZABHADkANwBiADMAQgBoAFkAMgBsADAAZQBUAG8AeABPADMAUgB5AFkA
>> "%~1" echo VwA1AHoAWgBtADkAeQBiAFQAcAB1AGIAMgA1AGwAZgBYADAATgBDAGkANQBoAGMA
>> "%~1" echo SABCAEQAWQBYAEoAawBMAG0AZABzAGIAMwBkADcAWQBXADUAcABiAFcARgAwAGEA
>> "%~1" echo VwA5AHUATwBtAE4AaABjAG0AUgBKAGIAaQBBAHUATgBIAE0AZwBZADMAVgBpAGEA
>> "%~1" echo VwBNAHQAWQBtAFYANgBhAFcAVgB5AEsAQwA0AHkATABDADQANABMAEMANAB5AEwA
>> "%~1" echo RABFAHAATABIAE4AMQBZADIATgBsAGMAMwBOAEgAYgBHADkAMwBJAEQARQB1AE0A
>> "%~1" echo WABNAGcAWgBXAEYAegBaAFgAMABOAEMAawBCAHIAWgBYAGwAbQBjAG0ARgB0AFoA
>> "%~1" echo WABNAGcAYwAzAFYAagBZADIAVgB6AGMAMABkAHMAYgAzAGQANwBNAEMAVgA3AFkA
>> "%~1" echo bQA5ADQATABYAE4AbwBZAFcAUgB2AGQAegBwADIAWQBYAEkAbwBMAFMAMQB6AGEA
>> "%~1" echo RwBGAGsAYgAzAGMAcABmAFQATQB3AEoAWAB0AGkAYgAzAGcAdABjADIAaABoAFoA
>> "%~1" echo RwA5ADMATwBqAEEAZwBNAEMAQQB3AEkARABOAHcAZQBDAEIAeQBaADIASgBoAEsA
>> "%~1" echo RABJAHkATABEAEUAMgBNAHkAdwAzAE4AQwB3AHUATQB6AFUAcABMAEQAQQBnAE0A
>> "%~1" echo VABKAHcAZQBDAEEAMABNAEgAQgA0AEkASABKAG4AWQBtAEUAbwBNAGoASQBzAE0A
>> "%~1" echo VABZAHoATABEAGMAMABMAEMANAB5AE4AUwBsADkATQBUAEEAdwBKAFgAdABpAGIA
>> "%~1" echo MwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AbgBaAGgAYwBpAGcAdABMAFgATgBvAFkA
>> "%~1" echo VwBSAHYAZAB5AGwAOQBmAFEAMABLAEwAeQBvAGcAWgBXADEAdwBkAEgAawBnAEwA
>> "%~1" echo eQBCAGsAYwBtADkAdwBJAEgATgAwAFkAWABSAGwASQBDAG8AdgBEAFEAbwB1AFoA
>> "%~1" echo SABKAHYAYwBFAFYAdABjAEgAUgA1AGUAMgBKAHYAYwBtAFIAbABjAGoAbwB5AGMA
>> "%~1" echo SABnAGcAWgBHAEYAegBhAEcAVgBrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIA
>> "%~1" echo bQBVAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE0A
>> "%~1" echo VABSAHcAZQBEAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAE4AdgBaAG4AUQBwAE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE4A
>> "%~1" echo RABaAHcAZQBDAEEAeQBNAEgAQgA0AE8AMwBSAGwAZQBIAFEAdABZAFcAeABwAFoA
>> "%~1" echo MgA0ADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBOADEAYwBuAE4AdgBjAGoAcAB3AGIA
>> "%~1" echo MgBsAHUAZABHAFYAeQBPADMAUgB5AFkAVwA1AHoAYQBYAFIAcABiADIANAA2AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcATgB2AGIARwA5AHkASQBDADQAeABPAEgATQBzAFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoAQwBBAHUATQBUAGgAegBmAFEAMABLAEwA
>> "%~1" echo bQBSAHkAYgAzAEIARgBiAFgAQgAwAGUAVABwAG8AYgAzAFoAbABjAG4AdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkAdABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFkA
>> "%~1" echo bQB4ADEAWgBTAGwAOQBEAFEAbwB1AFoASABKAHYAYwBFAFYAdABjAEgAUgA1AEwA
>> "%~1" echo bQA5ADIAWgBYAEoANwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAATwAyAEoAaABZADIAdABuAGMA
>> "%~1" echo bQA5ADEAYgBtAFEANgBjAG0AZABpAFkAUwBnAHoATgB5AHcANQBPAFMAdwB5AE0A
>> "%~1" echo egBVAHMATABqAEUAdwBLAFgAMABOAEMAaQA1AGsAYwBtADkAdwBSAFcAMQB3AGQA
>> "%~1" echo SABrAGcAYwAzAFoAbgBlADMAZABwAFoASABSAG8ATwBqAFUAeQBjAEgAZwA3AGEA
>> "%~1" echo RwBWAHAAWgAyAGgAMABPAGoAVQB5AGMASABnADcAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABZAG0AeAAxAFoAUwBrADcAWQBXADUAcABiAFcARgAwAGEA
>> "%~1" echo VwA5AHUATwBtAGgAcABiAG4AUgBHAGIARwA5AGgAZABDAEEAeQBMAGoAUgB6AEkA
>> "%~1" echo RwBWAGgAYwAyAFUAdABhAFcANAB0AGIAMwBWADAASQBHAGwAdQBaAG0AbAB1AGEA
>> "%~1" echo WABSAGwAZgBRADAASwBRAEcAdABsAGUAVwBaAHkAWQBXADEAbABjAHkAQgBvAGEA
>> "%~1" echo VwA1ADAAUgBtAHgAdgBZAFgAUgA3AE0AQwBVAHMATQBUAEEAdwBKAFgAdAAwAGMA
>> "%~1" echo bQBGAHUAYwAyAFoAdgBjAG0AMAA2AGQASABKAGgAYgBuAE4AcwBZAFgAUgBsAFcA
>> "%~1" echo UwBnAHcASwBUAHQAdgBjAEcARgBqAGEAWABSADUATwBpADQANABOAFgAMAAxAE0A
>> "%~1" echo QwBWADcAZABIAEoAaABiAG4ATgBtAGIAMwBKAHQATwBuAFIAeQBZAFcANQB6AGIA
>> "%~1" echo RwBGADAAWgBWAGsAbwBMAFQAVgB3AGUAQwBrADcAYgAzAEIAaABZADIAbAAwAGUA
>> "%~1" echo VABvAHgAZgBYADAATgBDAGkANQBrAGMAbQA5AHcAUgBXADEAdwBkAEgAawBnAFkA
>> "%~1" echo bgB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBKAHMAYgAyAE4AcgBPADIAWgB2AGIA
>> "%~1" echo bgBRAHQAYwAyAGwANgBaAFQAbwB4AE4AbgBCADQATwAyADEAaABjAG0AZABwAGIA
>> "%~1" echo aQAxADAAYgAzAEEANgBPAEgAQgA0AGYAUwA1AGsAYwBtADkAdwBSAFcAMQB3AGQA
>> "%~1" echo SABrAGcAYwAzAEIAaABiAG4AdABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIA
>> "%~1" echo MgBOAHIATwAyADEAaABjAG0AZABwAGIAaQAxADAAYgAzAEEANgBOAG4AQgA0AE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsA
>> "%~1" echo WAAwAE4AQwBpADgAcQBJAEcAaABsAGMAbQA4AGcASwBpADgATgBDAGkANQBoAGMA
>> "%~1" echo SABCAEkAWgBYAEoAdgBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaADMASgBwAFoA
>> "%~1" echo RAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcATgB2AGIA
>> "%~1" echo SABWAHQAYgBuAE0ANgBOAHoASgB3AGUAQwBBAHgAWgBuAEkANwBaADIARgB3AE8A
>> "%~1" echo agBFADIAYwBIAGcANwBZAFcAeABwAFoAMgA0AHQAYQBYAFIAbABiAFgATQA2AFkA
>> "%~1" echo MgBWAHUAZABHAFYAeQBmAFEAMABLAEwAbQBGAHcAYwBFAGwAagBiADIANQBVAGEA
>> "%~1" echo VwB4AGwAZQAzAGQAcABaAEgAUgBvAE8AagBjAHkAYwBIAGcANwBhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAGMAeQBjAEgAZwA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoA
>> "%~1" echo RwBsADEAYwB6AG8AeABPAEgAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAYgBHAGwAdQBaAFcARgB5AEwAVwBkAHkAWQBXAFIAcABaAFcANQAwAEsA
>> "%~1" echo RABFAHoATgBXAFIAbABaAHkAeAAyAFkAWABJAG8ATABTADEAaQBiAEgAVgBsAEsA
>> "%~1" echo UwB4ADIAWQBYAEkAbwBMAFMAMQBpAGIASABWAGwATQBpAGsAcABPADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AHcAYgBHAEYAagBaAFMAMQBwAGQA
>> "%~1" echo RwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAWQAyADkAcwBiADMASQA2AEkA
>> "%~1" echo MgBaAG0AWgBqAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAHoAQgB3AGUA
>> "%~1" echo RAB0AG0AYgAyADUAMABMAFgAZABsAGEAVwBkAG8AZABEAG8ANQBNAEQAQQA3AFkA
>> "%~1" echo bQA5ADQATABYAE4AbwBZAFcAUgB2AGQAegBvAHcASQBEAGgAdwBlAEMAQQB5AE0A
>> "%~1" echo bgBCADQASQBIAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwA
>> "%~1" echo QwA0ADAASwBYADAATgBDAGkANQBoAGMASABCAEoAWQAyADkAdQBWAEcAbABzAFoA
>> "%~1" echo UwBCAHoAZABtAGQANwBkADIAbABrAGQARwBnADYATQB6AGgAdwBlAEQAdABvAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBNAHoAaAB3AGUARAB0AG0AYQBXAHgAcwBPAG0ANQB2AGIA
>> "%~1" echo bQBVADcAYwAzAFIAeQBiADIAdABsAE8AbQBOADEAYwBuAEoAbABiAG4AUgBEAGIA
>> "%~1" echo MgB4AHYAYwBqAHQAegBkAEgASgB2AGEAMgBVAHQAZAAyAGwAawBkAEcAZwA2AE0A
>> "%~1" echo bgAwAE4AQwBpADUAaABjAEgAQgBPAFkAVwAxAGwAZQAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeQBNAFgAQgA0AE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAGcAdwBNAEQAdAAzAGIAMwBKAGsATABXAEoAeQBaAFcARgByAE8A
>> "%~1" echo bQBKAHkAWgBXAEYAcgBMAFcARgBzAGIARAB0AHMAYQBXADUAbABMAFcAaABsAGEA
>> "%~1" echo VwBkAG8AZABEAG8AeABMAGoASgA5AEQAUQBvAHUAYwBHAGwAcwBiAEYASgB2AGQA
>> "%~1" echo MwB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBaAHMAWgBYAGcANwBaAG0AeABsAGUA
>> "%~1" echo QwAxADMAYwBtAEYAdwBPAG4AZAB5AFkAWABBADcAWgAyAEYAdwBPAGoAZAB3AGUA
>> "%~1" echo RAB0AHQAWQBYAEoAbgBhAFcANAB0AGQARwA5AHcATwBqAGwAdwBlAEgAMABOAEMA
>> "%~1" echo aQA1AHcAYQBXAHgAcwBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBhAFcANQBzAGEA
>> "%~1" echo VwA1AGwATABXAFoAcwBaAFgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIA
>> "%~1" echo WABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBoAGwAYQBXAGQAbwBkAEQAbwB5AE4A
>> "%~1" echo WABCADQATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBDAEEAeABNAFgAQgA0AE8A
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAFQAawA1AGMA
>> "%~1" echo SABnADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAeQBjAEgAZwA3AFoA
>> "%~1" echo bQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATgB6AEEAdwBPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoA
>> "%~1" echo RABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBUAHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGwAOQBEAFEAbwB1AGMA
>> "%~1" echo RwBsAHMAYgBDADUAMgBaAFgASgA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAWQBtAHgAMQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFcATgB2AGIA
>> "%~1" echo RwA5AHkATwBuAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwA
>> "%~1" echo QwA0AHoATgBTAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoA
>> "%~1" echo MgBKAGgASwBEAE0AMwBMAEQAawA1AEwARABJAHoATgBTAHcAdQBNAEQAZwBwAGYA
>> "%~1" echo UQAwAEsATABuAEIAcABiAEcAdwB1AGMARwBWAHkAYgBYAHQAagBkAFgASgB6AGIA
>> "%~1" echo MwBJADYAYwBHADkAcABiAG4AUgBsAGMAbgAwAE4AQwBpADUAdwBhAFcAeABzAEwA
>> "%~1" echo bgBkAGgAYwBtADUANwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo bgBKAG4AWQBtAEUAbwBNAGoARQAzAEwARABFAHgATwBTAHcAMgBMAEMANAAwAEsA
>> "%~1" echo VAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAaABiAFcASgBsAGMA
>> "%~1" echo aQBrADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAeQBaADIASgBoAEsA
>> "%~1" echo RABJAHgATgB5AHcAeABNAFQAawBzAE4AaQB3AHUATQBEAGcAcABmAFEAMABLAEwA
>> "%~1" echo bgBCAHAAYgBHAHcAdQBiADIAdAA3AFkAbQA5AHkAWgBHAFYAeQBMAFcATgB2AGIA
>> "%~1" echo RwA5AHkATwBuAEoAbgBZAG0ARQBvAE0AagBJAHMATQBUAFkAegBMAEQAYwAwAEwA
>> "%~1" echo QwA0ADAASwBUAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQBuAGMA
>> "%~1" echo bQBWAGwAYgBpAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoA
>> "%~1" echo MgBKAGgASwBEAEkAeQBMAEQARQAyAE0AeQB3ADMATgBDAHcAdQBNAEQAZwBwAGYA
>> "%~1" echo UQAwAEsATABuAFoAbABjAGsASgBoAFoARwBkAGwAZQAyADEAaABjAG0AZABwAGIA
>> "%~1" echo aQAxADAAYgAzAEEANgBNAFQAUgB3AGUARAB0AHcAWQBXAFIAawBhAFcANQBuAE8A
>> "%~1" echo agBFAHcAYwBIAGcAZwBNAFQASgB3AGUARAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBGAGsAYQBYAFYAegBPAGoARQB3AGMASABnADcAWQBtADkAeQBaAEcAVgB5AE8A
>> "%~1" echo agBGAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEA
>> "%~1" echo VwA1AGwASwBUAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAE4AdgBaAG4AUQBwAE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAGMAdwBNAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo VABOAHcAZQBEAHQAawBhAFgATgB3AGIARwBGADUATwBtADUAdgBiAG0AVgA5AEQA
>> "%~1" echo UQBvAHUAZABtAFYAeQBRAG0ARgBrAFoAMgBVAHUAYwAyAGgAdgBkADMAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIAZgBRADAASwBMAG4AWgBsAGMA
>> "%~1" echo awBKAGgAWgBHAGQAbABMAG4AVgB3AGUAMgBKAHYAYwBtAFIAbABjAGkAMQBqAGIA
>> "%~1" echo MgB4AHYAYwBqAHAAeQBaADIASgBoAEsARABJAHkATABEAEUAMgBNAHkAdwAzAE4A
>> "%~1" echo QwB3AHUATgBDAGsANwBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFoA
>> "%~1" echo MwBKAGwAWgBXADQAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGMA
>> "%~1" echo bQBkAGkAWQBTAGcAeQBNAGkAdwB4AE4AagBNAHMATgB6AFEAcwBMAGoAQQAzAEsA
>> "%~1" echo WAAwAE4AQwBpADUAMgBaAFgASgBDAFkAVwBSAG4AWgBTADUAawBiADMAZAB1AGUA
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQBqAGIAMgB4AHYAYwBqAHAAeQBaADIASgBoAEsA
>> "%~1" echo RABJAHgATgB5AHcAeABNAFQAawBzAE4AaQB3AHUATgBEAFUAcABPADIATgB2AGIA
>> "%~1" echo RwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwBGAHQAWQBtAFYAeQBLAFQAdABpAFkA
>> "%~1" echo VwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBKAG4AWQBtAEUAbwBNAGoARQAzAEwA
>> "%~1" echo RABFAHgATwBTAHcAMgBMAEMANAB3AE4AeQBsADkARABRAG8AdgBLAGkAQgB2AGMA
>> "%~1" echo SABSAHAAYgAyADUAegBJAEMAbwB2AEQAUQBvAHUAYgAzAEIAMABVAG0AOQAzAGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAbQBiAEcAVgA0AEwA
>> "%~1" echo WABkAHkAWQBYAEEANgBkADMASgBoAGMARAB0AG4AWQBYAEEANgBNAFQAQgB3AGUA
>> "%~1" echo QwBBAHgATgBuAEIANABPADIAMQBoAGMAbQBkAHAAYgBpADEAMABiADMAQQA2AE0A
>> "%~1" echo VABaAHcAZQBIADAATgBDAGkANQB2AGMASABSAEQAYQBHAGwAdwBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBhAFcANQBzAGEAVwA1AGwATABXAFoAcwBaAFgAZwA3AFkA
>> "%~1" echo VwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcAVgB5AE8A
>> "%~1" echo MgBkAGgAYwBEAG8ANABjAEgAZwA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATgB6AEEAdwBPADIAWgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB4AE0A
>> "%~1" echo MwBCADQATwAyAE4AMQBjAG4ATgB2AGMAagBwAHcAYgAyAGwAdQBkAEcAVgB5AE8A
>> "%~1" echo MwBWAHoAWgBYAEkAdABjADIAVgBzAFoAVwBOADAATwBtADUAdgBiAG0AVQA3AGMA
>> "%~1" echo RwBGAGsAWgBHAGwAdQBaAHoAbwAzAGMASABnAGcATQBUAEYAdwBlAEQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkA
>> "%~1" echo VwBSAHAAZABYAE0ANgBPAFgAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGwAOQBEAFEAbwB1AGIA
>> "%~1" echo MwBCADAAUQAyAGgAcABjAEMAQgBwAGIAbgBCADEAZABIAHQAaABZADIATgBsAGIA
>> "%~1" echo bgBRAHQAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAG0AeAAxAFoA
>> "%~1" echo UwBrADcAZAAyAGwAawBkAEcAZwA2AFkAWABWADAAYgB6AHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYAWQBYAFYAMABiADMAMABOAEMAaQA1AHYAYwBIAFIARABhAEcAbAB3AEkA
>> "%~1" echo SABOAHQAWQBXAHgAcwBlADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABYAGQAbABhAFcAZABvAGQA
>> "%~1" echo RABvADAATQBEAEIAOQBEAFEAbwB2AEsAaQBCADAAYQBHAFUAZwBiAFcAOQB5AGMA
>> "%~1" echo RwBoAHAAYgBtAGMAZwBhAFcANQB6AGQARwBGAHMAYgBDAEIAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0AGcASwBpADgATgBDAGkANQBwAGIAbgBOADAAWQBXAHgAcwBRAG4AUgB1AGUA
>> "%~1" echo MwBCAHYAYwAyAGwAMABhAFcAOQB1AE8AbgBKAGwAYgBHAEYAMABhAFgAWgBsAE8A
>> "%~1" echo MgA5ADIAWgBYAEoAbQBiAEcAOQAzAE8AbQBoAHAAWgBHAFIAbABiAGoAdAAzAGEA
>> "%~1" echo VwBSADAAYQBEAG8AeABNAEQAQQBsAE8AMgBoAGwAYQBXAGQAbwBkAEQAbwAxAE4A
>> "%~1" echo SABCADQATwAyADEAaABjAG0AZABwAGIAaQAxADAAYgAzAEEANgBNAFQAaAB3AGUA
>> "%~1" echo RAB0AGkAYgAzAEoAawBaAFgASQA2AGIAbQA5AHUAWgBUAHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJAHQAYwBtAEYAawBhAFgAVgB6AE8AagBFAHkAYwBIAGcANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAaQBiAEgAVgBsAEsA
>> "%~1" echo VAB0AGoAYgAyAHgAdgBjAGoAbwBqAFoAbQBaAG0ATwAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeABOAG4AQgA0AE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAGcAdwBNAEQAdABqAGQAWABKAHoAYgAzAEkANgBjAEcAOQBwAGIA
>> "%~1" echo bgBSAGwAYwBqAHQAMABjAG0ARgB1AGMAMgBsADAAYQBXADkAdQBPAG0AWgBwAGIA
>> "%~1" echo SABSAGwAYwBpAEEAdQBNAFQAVgB6AEwASABSAHkAWQBXADUAegBaAG0AOQB5AGIA
>> "%~1" echo UwBBAHUATQBEAGgAegBmAFEAMABLAEwAbQBsAHUAYwAzAFIAaABiAEcAeABDAGQA
>> "%~1" echo RwA0ADYAYQBHADkAMgBaAFgASgA3AFoAbQBsAHMAZABHAFYAeQBPAG0ASgB5AGEA
>> "%~1" echo VwBkAG8AZABHADUAbABjADMATQBvAE0AUwA0AHcATgBTAGwAOQBMAG0AbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgAQwBkAEcANAA2AFkAVwBOADAAYQBYAFoAbABlADMAUgB5AFkA
>> "%~1" echo VwA1AHoAWgBtADkAeQBiAFQAcAAwAGMAbQBGAHUAYwAyAHgAaABkAEcAVgBaAEsA
>> "%~1" echo RABGAHcAZQBDAGwAOQBEAFEAbwB1AGEAVwA1AHoAZABHAEYAcwBiAEUASgAwAGIA
>> "%~1" echo aQBBAHUAYQBXADUAegBkAEcARgBzAGIARQBaAHAAYgBHAHgANwBjAEcAOQB6AGEA
>> "%~1" echo WABSAHAAYgAyADQANgBZAFcASgB6AGIAMgB4ADEAZABHAFUANwBhAFcANQB6AFoA
>> "%~1" echo WABRADYATQBDAEIAaABkAFgAUgB2AEkARABBAGcATQBEAHQAMwBhAFcAUgAwAGEA
>> "%~1" echo RABvAHcATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBiAEcAbAB1AFoA
>> "%~1" echo VwBGAHkATABXAGQAeQBZAFcAUgBwAFoAVwA1ADAASwBEAGsAdwBaAEcAVgBuAEwA
>> "%~1" echo SABaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAATABIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwBKAHMAZABXAFUAeQBLAFMAawA3AGQASABKAGgAYgBuAE4AcABkAEcAbAB2AGIA
>> "%~1" echo agBwADMAYQBXAFIAMABhAEMAQQB1AE0AMwBNAGcAWgBXAEYAegBaAFgAMABOAEMA
>> "%~1" echo aQA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUATABtAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AHAAYgBtAGQANwBZADMAVgB5AGMAMgA5AHkATwBuAEIAeQBiADIAZAB5AFoA
>> "%~1" echo WABOAHoATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBjAG0AZABpAFkA
>> "%~1" echo UwBnAHoATgB5AHcANQBPAFMAdwB5AE0AegBVAHMATABqAEUANABLAFgAMABOAEMA
>> "%~1" echo aQA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUATABtAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AHAAYgBtAGMAZwBMAG0AbAB1AGMAMwBSAGgAYgBHAHgARwBhAFcAeABzAGUA
>> "%~1" echo MgBKAHYAZQBDADEAegBhAEcARgBrAGIAMwBjADYATQBDAEEAdwBJAEQARQA0AGMA
>> "%~1" echo SABnAGcAYwBtAGQAaQBZAFMAZwB6AE4AeQB3ADUATwBTAHcAeQBNAHoAVQBzAEwA
>> "%~1" echo agBVAHAAZgBRADAASwBMAG0AbAB1AGMAMwBSAGgAYgBHAHgAQwBkAEcANAB1AGEA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEcAbAB1AFoAeQBBAHUAYQBXADUAegBkAEcARgBzAGIA
>> "%~1" echo RQBaAHAAYgBHAHcANgBZAFcAWgAwAFoAWABKADcAWQAyADkAdQBkAEcAVgB1AGQA
>> "%~1" echo RABvAGkASQBqAHQAdwBiADMATgBwAGQARwBsAHYAYgBqAHAAaABZAG4ATgB2AGIA
>> "%~1" echo SABWADAAWgBUAHQAcABiAG4ATgBsAGQARABvAHcATwAyAEoAaABZADIAdABuAGMA
>> "%~1" echo bQA5ADEAYgBtAFEANgBiAEcAbAB1AFoAVwBGAHkATABXAGQAeQBZAFcAUgBwAFoA
>> "%~1" echo VwA1ADAASwBEAGsAdwBaAEcAVgBuAEwASABSAHkAWQBXADUAegBjAEcARgB5AFoA
>> "%~1" echo VwA1ADAATABIAEoAbgBZAG0ARQBvAE0AagBVADEATABEAEkAMQBOAFMAdwB5AE4A
>> "%~1" echo VABVAHMATABqAE0AMQBLAFMAeAAwAGMAbQBGAHUAYwAzAEIAaABjAG0AVgB1AGQA
>> "%~1" echo QwBrADcAWQBXADUAcABiAFcARgAwAGEAVwA5AHUATwBuAE4AbwBaAFcAVgB1AEkA
>> "%~1" echo RABFAHUATQBuAE0AZwBiAEcAbAB1AFoAVwBGAHkASQBHAGwAdQBaAG0AbAB1AGEA
>> "%~1" echo WABSAGwAZgBRADAASwBRAEcAdABsAGUAVwBaAHkAWQBXADEAbABjAHkAQgB6AGEA
>> "%~1" echo RwBWAGwAYgBuAHQAbQBjAG0AOQB0AGUAMwBSAHkAWQBXADUAegBaAG0AOQB5AGIA
>> "%~1" echo VABwADAAYwBtAEYAdQBjADIAeABoAGQARwBWAFkASwBDADAAeABNAEQAQQBsAEsA
>> "%~1" echo WAAxADAAYgAzAHQAMABjAG0ARgB1AGMAMgBaAHYAYwBtADAANgBkAEgASgBoAGIA
>> "%~1" echo bgBOAHMAWQBYAFIAbABXAEMAZwB4AE0ARABBAGwASwBYADEAOQBEAFEAbwB1AGEA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEUASgAwAGIAaQBBAHUAYQBXADUAegBkAEcARgBzAGIA
>> "%~1" echo RQB4AGgAWQBtAFYAcwBlADMAQgB2AGMAMgBsADAAYQBXADkAdQBPAG4ASgBsAGIA
>> "%~1" echo RwBGADAAYQBYAFoAbABPADMAbwB0AGEAVwA1AGsAWgBYAGcANgBNAFQAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEA
>> "%~1" echo WABSAGwAYgBYAE0ANgBZADIAVgB1AGQARwBWAHkATwAyAHAAMQBjADMAUgBwAFoA
>> "%~1" echo bgBrAHQAWQAyADkAdQBkAEcAVgB1AGQARABwAGoAWgBXADUAMABaAFgASQA3AFoA
>> "%~1" echo MgBGAHcATwBqAGwAdwBlAEQAdABvAFoAVwBsAG4AYQBIAFEANgBNAFQAQQB3AEoA
>> "%~1" echo WAAwAE4AQwBpADUAcABiAG4ATgAwAFkAVwB4AHMAUQBuAFIAdQBMAG0AUgB2AGIA
>> "%~1" echo bQBWADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAG4AYwBtAFYAbABiAGkAbAA5AEwAbQBsAHUAYwAzAFIAaABiAEcAeABDAGQA
>> "%~1" echo RwA0AHUAWgBHADkAdQBaAFMAQQB1AGEAVwA1AHoAZABHAEYAcwBiAEUAWgBwAGIA
>> "%~1" echo RwB4ADcAZAAyAGwAawBkAEcAZwA2AE0AVABBAHcASgBTAEYAcABiAFgAQgB2AGMA
>> "%~1" echo bgBSAGgAYgBuAFEANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAbgBjAG0AVgBsAGIAaQBsADkARABRAG8AdQBhAFcANQB6AGQA
>> "%~1" echo RwBGAHMAYgBFAEoAMABiAGkANQBtAFkAVwBsAHMAWgBXAFIANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAeQBaAFcAUQBwAGYA
>> "%~1" echo UwA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUATABtAFoAaABhAFcAeABsAFoA
>> "%~1" echo QwBBAHUAYQBXADUAegBkAEcARgBzAGIARQBaAHAAYgBHAHgANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAeQBaAFcAUQBwAGYA
>> "%~1" echo UQAwAEsATABtAGwAdQBjADMAUgBoAGIARwB4AEMAZABHADQAdQBaAG0ARgBwAGIA
>> "%~1" echo RwBWAGsAZQAyAEYAdQBhAFcAMQBoAGQARwBsAHYAYgBqAHAAegBhAEcARgByAFoA
>> "%~1" echo UwBBAHUATgBIAE4AOQBEAFEAcABBAGEAMgBWADUAWgBuAEoAaABiAFcAVgB6AEkA
>> "%~1" echo SABOAG8AWQBXAHQAbABlAHoARQB3AEoAUwB3ADUATQBDAFYANwBkAEgASgBoAGIA
>> "%~1" echo bgBOAG0AYgAzAEoAdABPAG4AUgB5AFkAVwA1AHoAYgBHAEYAMABaAFYAZwBvAEwA
>> "%~1" echo VABKAHcAZQBDAGwAOQBNAHoAQQBsAEwARABjAHcASgBYAHQAMABjAG0ARgB1AGMA
>> "%~1" echo MgBaAHYAYwBtADAANgBkAEgASgBoAGIAbgBOAHMAWQBYAFIAbABXAEMAZwAwAGMA
>> "%~1" echo SABnAHAAZgBUAFUAdwBKAFgAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGQA
>> "%~1" echo SABKAGgAYgBuAE4AcwBZAFgAUgBsAFcAQwBnAHQATgBIAEIANABLAFgAMQA5AEQA
>> "%~1" echo UQBvAHUAWQAyAGgAcgBlADMAZABwAFoASABSAG8ATwBqAEkAeQBjAEgAZwA3AGEA
>> "%~1" echo RwBWAHAAWgAyAGgAMABPAGoASQB5AGMASABoADkATABtAE4AbwBhAHkAQgB3AFkA
>> "%~1" echo WABSAG8AZQAzAE4AMABjAG0AOQByAFoAVABvAGoAWgBtAFoAbQBPADMATgAwAGMA
>> "%~1" echo bQA5AHIAWgBTADEAMwBhAFcAUgAwAGEARABvAHoATwAyAFoAcABiAEcAdwA2AGIA
>> "%~1" echo bQA5AHUAWgBUAHQAegBkAEgASgB2AGEAMgBVAHQAYgBHAGwAdQBaAFcATgBoAGMA
>> "%~1" echo RABwAHkAYgAzAFYAdQBaAEQAdAB6AGQASABKAHYAYQAyAFUAdABiAEcAbAB1AFoA
>> "%~1" echo VwBwAHYAYQBXADQANgBjAG0AOQAxAGIAbQBRADcAYwAzAFIAeQBiADIAdABsAEwA
>> "%~1" echo VwBSAGgAYwAyAGgAaABjAG4ASgBoAGUAVABvAHkATgBqAHQAegBkAEgASgB2AGEA
>> "%~1" echo MgBVAHQAWgBHAEYAegBhAEcAOQBtAFoAbgBOAGwAZABEAG8AeQBOAG4AMABOAEMA
>> "%~1" echo aQA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUATABtAFIAdgBiAG0AVQBnAEwA
>> "%~1" echo bQBOAG8AYQB5AEIAdwBZAFgAUgBvAGUAMgBGAHUAYQBXADEAaABkAEcAbAB2AGIA
>> "%~1" echo agBwAGoAYQBHAHQARQBjAG0ARgAzAEkAQwA0ADEAYwB5AEEAdQBNAFgATQBnAFoA
>> "%~1" echo bQA5AHkAZAAyAEYAeQBaAEgATQBnAFoAVwBGAHoAWgBYADAATgBDAGsAQgByAFoA
>> "%~1" echo WABsAG0AYwBtAEYAdABaAFgATQBnAFkAMgBoAHIAUgBIAEoAaABkADMAdAAwAGIA
>> "%~1" echo MwB0AHoAZABIAEoAdgBhADIAVQB0AFoARwBGAHoAYQBHADkAbQBaAG4ATgBsAGQA
>> "%~1" echo RABvAHcAZgBYADAATgBDAGkAOABxAEkASABOADAAWQBXAGQAbABJAEMAcwBnAGMA
>> "%~1" echo MwBSAHkAWgBXAEYAdABaAFcAUQBnAFkAVwBSAGkASQBHADkAMQBkAEgAQgAxAGQA
>> "%~1" echo QwBBAHEATAB3ADAASwBMAG4ATgAwAFkAVwBkAGwAVQBtADkAMwBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBiAG0AOQB1AFoAVAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQA
>> "%~1" echo RwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAYQBuAFYAegBkAEcAbABtAGUA
>> "%~1" echo UwAxAGoAYgAyADUAMABaAFcANQAwAE8AbgBOAHcAWQBXAE4AbABMAFcASgBsAGQA
>> "%~1" echo SABkAGwAWgBXADQANwBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwB4AE4A
>> "%~1" echo SABCADQATwAyAFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAYwB3AE0A
>> "%~1" echo SAAwAE4AQwBpADUAegBkAEcARgBuAFoAVgBKAHYAZAB5ADUAegBhAEcAOQAzAGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBIADAATgBDAGkANQB6AGQA
>> "%~1" echo RwBGAG4AWgBWAEoAdgBkAHkAQQB1AFoAVwB4AGgAYwBIAE4AbABaAEgAdABtAGIA
>> "%~1" echo MgA1ADAATABXAFoAaABiAFcAbABzAGUAVABwAEQAYgAyADUAegBiADIAeABoAGMA
>> "%~1" echo eQB4AHQAYgAyADUAdgBjADMAQgBoAFkAMgBVADcAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABiAFgAVgAwAFoAVwBRAHAATwAyAFoAdgBiAG4AUQB0AGQA
>> "%~1" echo MgBWAHAAWgAyAGgAMABPAGoAUQB3AE0ASAAwAE4AQwBpADUAaABaAEcASgBQAGQA
>> "%~1" echo WABSADcAWgBHAGwAegBjAEcAeABoAGUAVABwAHUAYgAyADUAbABPADIAMQBoAGMA
>> "%~1" echo bQBkAHAAYgBpADEAMABiADMAQQA2AE0AVABKAHcAZQBEAHQAdABZAFgAZwB0AGEA
>> "%~1" echo RwBWAHAAWgAyAGgAMABPAGoARQAzAE0ASABCADQATwAyADkAMgBaAFgASgBtAGIA
>> "%~1" echo RwA5ADMATwBtAEYAMQBkAEcAOAA3AFkAbQA5AHkAWgBHAFYAeQBPAGoARgB3AGUA
>> "%~1" echo QwBCAHoAYgAyAHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEAcwBhAFcANQBsAEsA
>> "%~1" echo VAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYAegBPAGoARQB3AGMA
>> "%~1" echo SABnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAG8AagBNAEcARQB3AFoA
>> "%~1" echo agBFADIATwAyAE4AdgBiAEcAOQB5AE8AaQBNADUAWgBtAEkAegBZAHoAZwA3AGMA
>> "%~1" echo RwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0AWABCADQASQBEAEUAeQBjAEgAZwA3AFoA
>> "%~1" echo bQA5AHUAZABDADEAbQBZAFcAMQBwAGIASABrADYAUQAyADkAdQBjADIAOQBzAFkA
>> "%~1" echo WABNAHMAYgBXADkAdQBiADMATgB3AFkAVwBOAGwATwAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeABNAG4AQgA0AE8AMgB4AHAAYgBtAFUAdABhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAEUAdQBOAFQAVQA3AGQAMgBoAHAAZABHAFUAdABjADMAQgBoAFkA
>> "%~1" echo MgBVADYAYwBIAEoAbABMAFgAZAB5AFkAWABBADcAZAAyADkAeQBaAEMAMQBpAGMA
>> "%~1" echo bQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEAeQAxADMAYgAzAEoAawBmAFEAMABLAFkA
>> "%~1" echo bQA5AGsAZQBUAHAAdQBiADMAUQBvAEwAbQBSAGgAYwBtAHMAcABJAEMANQBoAFoA
>> "%~1" echo RwBKAFAAZABYAFIANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAbwBqAE0A
>> "%~1" echo RwBZAHgATgB6AEkAdwBPADIATgB2AGIARwA5AHkATwBpAE4AagBaAG0AVQB3AFoA
>> "%~1" echo agBCADkARABRAG8AdQBZAFcAUgBpAFQAMwBWADAATABuAE4AbwBiADMAZAA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABpAGIARwA5AGoAYQAzADAATgBDAGkANQB3AFoA
>> "%~1" echo WABKAHQAYwAxAEIAdgBjAEgAdABrAGEAWABOAHcAYgBHAEYANQBPAG0ANQB2AGIA
>> "%~1" echo bQBVADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8AeABNAG4AQgA0AE8A
>> "%~1" echo MgAxAGgAZQBDADEAbwBaAFcAbABuAGEASABRADYATQBUAFUAdwBjAEgAZwA3AGIA
>> "%~1" echo MwBaAGwAYwBtAFoAcwBiADMAYwA2AFkAWABWADAAYgB6AHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQA
>> "%~1" echo WABNADYATQBUAEIAdwBlAEQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFgATgB2AFoAbgBRAHAATwAzAEIAaABaAEcAUgBwAGIA
>> "%~1" echo bQBjADYATQBUAEYAdwBlAEQAdABtAGIAMgA1ADAATABXAFoAaABiAFcAbABzAGUA
>> "%~1" echo VABwAEQAYgAyADUAegBiADIAeABoAGMAeQB4AHQAYgAyADUAdgBjADMAQgBoAFkA
>> "%~1" echo MgBVADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAeQBjAEgAZwA3AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8A
>> "%~1" echo MwBkAG8AYQBYAFIAbABMAFgATgB3AFkAVwBOAGwATwBuAEIAeQBaAFMAMQAzAGMA
>> "%~1" echo bQBGAHcATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgAMABPAGoARQB1AE4A
>> "%~1" echo bgAwAE4AQwBpADUAdwBaAFgASgB0AGMAMQBCAHYAYwBDADUAegBhAEcAOQAzAGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFkAbQB4AHYAWQAyAHQAOQBEAFEAcABBAGIA
>> "%~1" echo VwBWAGsAYQBXAEUAZwBLAEgAQgB5AFoAVwBaAGwAYwBuAE0AdABjAG0AVgBrAGQA
>> "%~1" echo VwBOAGwAWgBDADEAdABiADMAUgBwAGIAMgA0ADYASQBIAEoAbABaAEgAVgBqAFoA
>> "%~1" echo UwBsADcATABtAEYAdwBjAEUATgBoAGMAbQBRAHMATABtAEYAdwBjAEUATgBoAGMA
>> "%~1" echo bQBRAHUAWgAyAHgAdgBkAHkAdwB1AFoASABKAHYAYwBFAFYAdABjAEgAUgA1AEkA
>> "%~1" echo SABOADIAWgB5AHcAdQBhAFcANQB6AGQARwBGAHMAYgBFAEoAMABiAGkANQBwAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBhAFcANQBuAEkAQwA1AHAAYgBuAE4AMABZAFcAeABzAFIA
>> "%~1" echo bQBsAHMAYgBEAHAAaABaAG4AUgBsAGMAaQB3AHUAYQBXADUAegBkAEcARgBzAGIA
>> "%~1" echo RQBKADAAYgBpADUAawBiADIANQBsAEkAQwA1AGoAYQBHAHMAZwBjAEcARgAwAGEA
>> "%~1" echo QwB3AHUAYQBXADUAegBkAEcARgBzAGIARQBKADAAYgBpADUAbQBZAFcAbABzAFoA
>> "%~1" echo VwBSADcAWQBXADUAcABiAFcARgAwAGEAVwA5AHUATwBtADUAdgBiAG0AVgA5AGYA
>> "%~1" echo UQAwAEsAUQBHADEAbABaAEcAbABoAEsARwAxAGgAZQBDADEAMwBhAFcAUgAwAGEA
>> "%~1" echo RABvADQATQBqAEIAdwBlAEMAbAA3AEwAbQBGAHcAYwBFAGgAbABjAG0AOQA3AFoA
>> "%~1" echo MwBKAHAAWgBDADEAMABaAFcAMQB3AGIARwBGADAAWgBTADEAagBiADIAeAAxAGIA
>> "%~1" echo VwA1AHoATwBqAEYAbQBjAGoAdAAwAFoAWABoADAATABXAEYAcwBhAFcAZAB1AE8A
>> "%~1" echo bQBOAGwAYgBuAFIAbABjAGoAdABxAGQAWABOADAAYQBXAFoANQBMAFcAbAAwAFoA
>> "%~1" echo VwAxAHoATwBtAE4AbABiAG4AUgBsAGMAbgAxADkARABRAG8AdQBkAEcARgBpAGMA
>> "%~1" echo MwB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBaAHMAWgBYAGcANwBaADIARgB3AE8A
>> "%~1" echo agBaAHcAZQBEAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAE4AdgBaAG4AUQBwAE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMA
>> "%~1" echo SABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoA
>> "%~1" echo UwBrADcAYwBHAEYAawBaAEcAbAB1AFoAegBvADAAYwBIAGcANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvAHgATQBuAEIANABPADMAZABwAFoA
>> "%~1" echo SABSAG8ATwBtAFoAcABkAEMAMQBqAGIAMgA1ADAAWgBXADUAMABmAFEAMABLAEwA
>> "%~1" echo bgBSAGgAWQBuAE0AZwBZAG4AVgAwAGQARwA5AHUAZQAyAGgAbABhAFcAZABvAGQA
>> "%~1" echo RABvAHoATgBIAEIANABPADIASgB2AGMAbQBSAGwAYwBqAG8AdwBPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGQASABKAGgAYgBuAE4AdwBZAFgASgBsAGIA
>> "%~1" echo bgBRADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8A
>> "%~1" echo WABCADQATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBDAEEAeABOAEgAQgA0AE8A
>> "%~1" echo MgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBqAGcAdwBNAEQAdABqAGQA
>> "%~1" echo WABKAHoAYgAzAEkANgBjAEcAOQBwAGIAbgBSAGwAYwBuADAATgBDAGkANQAwAFkA
>> "%~1" echo VwBKAHoASQBHAEoAMQBkAEgAUgB2AGIAaQA1AHYAYgBuAHQAaQBZAFcATgByAFoA
>> "%~1" echo MwBKAHYAZABXADUAawBPAG4AWgBoAGMAaQBnAHQATABXAE4AaABjAG0AUQBwAE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIAbABlAEgAUQBwAE8A
>> "%~1" echo MgBKAHYAZQBDADEAegBhAEcARgBrAGIAMwBjADYAZABtAEYAeQBLAEMAMAB0AGMA
>> "%~1" echo MgBoAGgAWgBHADkAMwBLAFgAMABOAEMAaQA1AGgAYwBIAEIATQBhAFcASgA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABuAGMAbQBsAGsATwAyAGQAeQBhAFcAUQB0AGQA
>> "%~1" echo RwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoAbwB6AE0A
>> "%~1" echo RABCAHcAZQBDAEEAeABaAG4ASQA3AFoAMgBGAHcATwBqAEUAMQBjAEgAZwA3AGIA
>> "%~1" echo VwBsAHUATABXAGgAbABhAFcAZABvAGQARABvADEATQBqAEIAdwBlAEgAMABOAEMA
>> "%~1" echo aQA1AGgAYwBIAEIATQBhAFgATgAwAGUAMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAZABtAEYAeQBLAEMAMAB0AFkAMgBGAHkAWgBDAGsANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHMAYQBXADUAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEA
>> "%~1" echo WABWAHoATwBuAFoAaABjAGkAZwB0AEwAWABKAGgAWgBHAGwAMQBjAHkAawA3AGIA
>> "%~1" echo MwBaAGwAYwBtAFoAcwBiADMAYwA2AGEARwBsAGsAWgBHAFYAdQBPADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaAG0AeABsAGUARAB0AG0AYgBHAFYANABMAFcAUgBwAGMA
>> "%~1" echo bQBWAGoAZABHAGwAdgBiAGoAcABqAGIAMgB4ADEAYgBXADUAOQBEAFEAbwB1AFkA
>> "%~1" echo WABCAHcAVQAyAFYAaABjAG0ATgBvAGUAMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0A
>> "%~1" echo VABCAHcAZQBDAEEAeABNAG4AQgA0AE8AMgBKAHYAYwBtAFIAbABjAGkAMQBpAGIA
>> "%~1" echo MwBSADAAYgAyADAANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAHgAcABiAG0AVQBwAGYAUQAwAEsATABtAEYAdwBjAEYATgBsAFkA
>> "%~1" echo WABKAGoAYQBDAEIAcABiAG4AQgAxAGQASAB0ADMAYQBXAFIAMABhAEQAbwB4AE0A
>> "%~1" echo RABBAGwAZgBRADAASwBMAG0ARgB3AGMARgBKAHYAZAAzAE4ANwBiADMAWgBsAGMA
>> "%~1" echo bQBaAHMAYgAzAGMANgBZAFgAVgAwAGIAegB0AG0AYgBHAFYANABPAGoARgA5AEQA
>> "%~1" echo UQBvAHUAWQBYAEIAdwBVAG0AOQAzAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoA
>> "%~1" echo MwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwA
>> "%~1" echo VwBOAHYAYgBIAFYAdABiAG4ATQA2AE4ARABCAHcAZQBDAEEAeABaAG4ASQA3AFoA
>> "%~1" echo MgBGAHcATwBqAEUAdwBjAEgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIA
>> "%~1" echo WABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0A
>> "%~1" echo VABCAHcAZQBDAEEAeABNAG4AQgA0AE8AMgBOADEAYwBuAE4AdgBjAGoAcAB3AGIA
>> "%~1" echo MgBsAHUAZABHAFYAeQBPADIASgB2AGMAbQBSAGwAYwBpADEAaQBiADMAUgAwAGIA
>> "%~1" echo MgAwADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABmAFEAMABLAEwAbQBGAHcAYwBGAEoAdgBkAHoAcABvAGIA
>> "%~1" echo MwBaAGwAYwBuAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4ASgBuAFkA
>> "%~1" echo bQBFAG8ATQB6AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAdwBOAGkAbAA5AEwA
>> "%~1" echo bQBGAHcAYwBGAEoAdgBkAHkANQB2AGIAbgB0AGkAWQBXAE4AcgBaADMASgB2AGQA
>> "%~1" echo VwA1AGsATwBuAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwA
>> "%~1" echo QwA0AHgATQBpAGwAOQBEAFEAbwB1AFkAWABCAHcAUgAyAHgANQBjAEcAaAA3AGQA
>> "%~1" echo MgBsAGsAZABHAGcANgBOAEQAQgB3AGUARAB0AG8AWgBXAGwAbgBhAEgAUQA2AE4A
>> "%~1" echo RABCAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8A
>> "%~1" echo agBFAHgAYwBIAGcANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8A
>> "%~1" echo MwBCAHMAWQBXAE4AbABMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMA
>> "%~1" echo agB0AGoAYgAyAHgAdgBjAGoAbwBqAFoAbQBaAG0ATwAyAFoAdgBiAG4AUQB0AGQA
>> "%~1" echo MgBWAHAAWgAyAGgAMABPAGoAawB3AE0ASAAwAE4AQwBpADUAaABjAEgAQgBTAGIA
>> "%~1" echo MwBjAGcAWQBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIATgByAE8A
>> "%~1" echo MgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHgATQAzAEIANABmAFMANQBoAGMA
>> "%~1" echo SABCAFMAYgAzAGMAZwBjADMAQgBoAGIAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBKAHMAYgAyAE4AcgBPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo VABGAHcAZQBEAHQAMwBiADMASgBrAEwAVwBKAHkAWgBXAEYAcgBPAG0ASgB5AFoA
>> "%~1" echo VwBGAHIATABXAEYAcwBiAEgAMABOAEMAaQA1AGgAYwBIAEIARQBaAFgAUgBoAGEA
>> "%~1" echo VwB4ADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGoAWQBYAEoAawBLAFQAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkA
>> "%~1" echo SABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8A
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYwBtAEYAawBhAFgAVgB6AEsAVAB0AHQAYQBXADQAdABhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAFUAeQBNAEgAQgA0AGYAUQAwAEsATABtAEYAdwBjAEUAVgB0AGMA
>> "%~1" echo SABSADUAZQAzAEIAaABaAEcAUgBwAGIAbQBjADYATgBEAGgAdwBlAEMAQQB5AE4A
>> "%~1" echo SABCADQATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcAMQAxAGQA
>> "%~1" echo RwBWAGsASwBUAHQAMABaAFgAaAAwAEwAVwBGAHMAYQBXAGQAdQBPAG0ATgBsAGIA
>> "%~1" echo bgBSAGwAYwBuADAATgBDAGkANQBoAFkAMwBSAEMAWQBYAEoANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbQBiAEcAVgA0AE8AMgBaAHMAWgBYAGcAdABkADMASgBoAGMA
>> "%~1" echo RABwADMAYwBtAEYAdwBPADIAZABoAGMARABvADQAYwBIAGcANwBiAFcARgB5AFoA
>> "%~1" echo MgBsAHUATABYAFIAdgBjAEQAbwB4AE4ASABCADQAZgBRADAASwBMAG4AQgBsAGMA
>> "%~1" echo bQAxAFMAYgAzAGQANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8A
>> "%~1" echo MgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQA
>> "%~1" echo VwAxAHUAYwB6AG8AeABaAG4ASQBnAFkAWABWADAAYgB5AEIAaABkAFgAUgB2AE8A
>> "%~1" echo MgBkAGgAYwBEAG8ANABjAEgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIA
>> "%~1" echo WABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE8A
>> "%~1" echo SABCADQASQBEAEEANwBZAG0AOQB5AFoARwBWAHkATABXAEoAdgBkAEgAUgB2AGIA
>> "%~1" echo VABvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBTAGsANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQB5AGMA
>> "%~1" echo SABoADkARABRAG8AdQBjAEcAVgB5AGIAVgBKAHYAZAB6AHAAcwBZAFgATgAwAEwA
>> "%~1" echo VwBOAG8AYQBXAHgAawBlADIASgB2AGMAbQBSAGwAYwBpADEAaQBiADMAUgAwAGIA
>> "%~1" echo MgAwADYATQBIADAATgBDAGkANQB6AFoAWABSAEgAYwBtAGwAawBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AWQBYAEEANgBNAFQASgB3AGUA
>> "%~1" echo SAAwAE4AQwBpADUAegBaAFgAUgBTAGIAMwBkADcAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VABwAG4AYwBtAGwAawBPADIAZAB5AGEAVwBRAHQAZABHAFYAdABjAEcAeABoAGQA
>> "%~1" echo RwBVAHQAWQAyADkAcwBkAFcAMQB1AGMAegBvAHgATABqAFIAbQBjAGkAQQB4AFoA
>> "%~1" echo bgBJAGcAWQBYAFYAMABiAHoAdABuAFkAWABBADYATQBUAEoAdwBlAEQAdABoAGIA
>> "%~1" echo RwBsAG4AYgBpADEAcABkAEcAVgB0AGMAegBwAGoAWgBXADUAMABaAFgASQA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBPAGoARgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkA
>> "%~1" echo WABJAG8ATABTADEAcwBhAFcANQBsAEsAVAB0AGkAWQBXAE4AcgBaADMASgB2AGQA
>> "%~1" echo VwA1AGsATwBuAFoAaABjAGkAZwB0AEwAWABOAHYAWgBuAFEAcABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATQBUAEIAdwBlAEQAdAB3AFkA
>> "%~1" echo VwBSAGsAYQBXADUAbgBPAGoARQB5AGMASABoADkARABRAG8AdQBjADIAVgAwAFUA
>> "%~1" echo bQA5ADMASQBHAEoANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEA
>> "%~1" echo MwAwAHUAYwAyAFYAMABVAG0AOQAzAEkASABOAHcAWQBXADUANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEAegB0AGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQB6AGEA
>> "%~1" echo WABwAGwATwBqAEUAeQBjAEgAZwA3AGIAVwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMA
>> "%~1" echo RABvAHoAYwBIAGgAOQBEAFEAbwB1AFkAbQBGAHUAYgBtAFYAeQBlADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBjAG0AZABpAFkA
>> "%~1" echo UwBnAHkATQBUAGMAcwBNAFQARQA1AEwARABZAHMATABqAE0AMQBLAFQAdABpAFkA
>> "%~1" echo VwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBKAG4AWQBtAEUAbwBNAGoARQAzAEwA
>> "%~1" echo RABFAHgATwBTAHcAMgBMAEMANAB3AE8AQwBrADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo WABKAGgAWgBHAGwAMQBjAHoAbwB4AE0ASABCADQATwAzAEIAaABaAEcAUgBwAGIA
>> "%~1" echo bQBjADYATQBUAEoAdwBlAEMAQQB4AE4ASABCADQATwAyAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADYAYgBtADkAdQBaAFQAdABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMA
>> "%~1" echo egBwAGoAWgBXADUAMABaAFgASQA3AGEAbgBWAHoAZABHAGwAbQBlAFMAMQBqAGIA
>> "%~1" echo MgA1ADAAWgBXADUAMABPAG4ATgB3AFkAVwBOAGwATABXAEoAbABkAEgAZABsAFoA
>> "%~1" echo VwA0ADcAWgAyAEYAdwBPAGoARQB5AGMASABoADkARABRAG8AdQBZAG0ARgB1AGIA
>> "%~1" echo bQBWAHkATABuAE4AbwBiADMAZAA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABtAGIA
>> "%~1" echo RwBWADQAZgBRADAASwBMAG0AeABoAGIAbQBkAEMAZABHADUANwBhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBqAE0AMgBjAEgAZwA3AGIAVwBsAHUATABYAGQAcABaAEgAUgBvAE8A
>> "%~1" echo agBVAHkAYwBIAGgAOQBEAFEAcABBAGIAVwBWAGsAYQBXAEUAbwBiAFcARgA0AEwA
>> "%~1" echo WABkAHAAWgBIAFIAbwBPAGoARQB4AE0ARABCAHcAZQBDAGwANwBMAG0ARgB3AGMA
>> "%~1" echo RQB4AHAAWQBpAHcAdQBjADIAVgAwAFUAbQA5ADMAZQAyAGQAeQBhAFcAUQB0AGQA
>> "%~1" echo RwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoAbwB4AFoA
>> "%~1" echo bgBKADkAZgBRADAASwBMAHkAbwBnAEwAUwAwAHQASQBIAE4AbwBZAFgASgBsAFoA
>> "%~1" echo QwBBAHQATABTADAAZwBLAGkAOABOAEMAaQA1AHcAWQBYAEoAaABiAFUAeABwAGMA
>> "%~1" echo MwBSADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADIAZABoAGMA
>> "%~1" echo RABvAHgATQBYAEIANABmAFEAMABLAEwAbgBCAGgAYwBtAEYAdABTAFgAUgBsAGIA
>> "%~1" echo WAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMASgBwAFoA
>> "%~1" echo QwAxADAAWgBXADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8A
>> "%~1" echo agBFAHUATQBtAFoAeQBJAEMANAA0AFoAbgBJAGcATABqAGgAbQBjAGkAQgBoAGQA
>> "%~1" echo WABSAHYATwAyAGQAaABjAEQAbwB4AE0AWABCADQATwAyAEYAcwBhAFcAZAB1AEwA
>> "%~1" echo VwBsADAAWgBXADEAegBPAG0ATgBsAGIAbgBSAGwAYwBqAHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo WABKAGgAWgBHAGwAMQBjAHoAbwA1AGMASABnADcAYwBHAEYAawBaAEcAbAB1AFoA
>> "%~1" echo egBvAHgATQBYAEIANABJAEQARQB6AGMASABoADkARABRAG8AdQBjAEcARgB5AFkA
>> "%~1" echo VwAxAE8AWQBXADEAbABJAEcASgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABpAGIA
>> "%~1" echo RwA5AGoAYQAzADAAdQBjAEcARgB5AFkAVwAxAE8AWQBXADEAbABJAEgATgB3AFkA
>> "%~1" echo VwA0AHMATABuAEIAaABjAG0ARgB0AFYAbQBGAHMAZABXAFUAZwBjADMAQgBoAGIA
>> "%~1" echo bgB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBKAHMAYgAyAE4AcgBPADIATgB2AGIA
>> "%~1" echo RwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwAxADEAZABHAFYAawBLAFQAdABtAGIA
>> "%~1" echo MgA1ADAATABYAE4AcABlAG0AVQA2AE0AVABKAHcAZQBEAHQAdABZAFgASgBuAGEA
>> "%~1" echo VwA0AHQAZABHADkAdwBPAGoATgB3AGUASAAwAHUAYwBHAEYAeQBZAFcAMQBXAFkA
>> "%~1" echo VwB4ADEAWgBTAEIAaQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkA
>> "%~1" echo MgBzADcAZAAyADkAeQBaAEMAMQBpAGMAbQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEA
>> "%~1" echo eQAxADMAYgAzAEoAawBmAFEAMABLAEwAbgBCAGgAYwBtAEYAdABVADMAUgBoAGQA
>> "%~1" echo RwBWADcAYQBHAFYAcABaADIAaAAwAE8AagBJADIAYwBIAGcANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHMAYQBXADUAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEA
>> "%~1" echo WABWAHoATwBqAGsANQBPAFgAQgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AGEA
>> "%~1" echo VwA1AHMAYQBXADUAbABMAFcAWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEA
>> "%~1" echo WABSAGwAYgBYAE0ANgBZADIAVgB1AGQARwBWAHkATwAyAHAAMQBjADMAUgBwAFoA
>> "%~1" echo bgBrAHQAWQAyADkAdQBkAEcAVgB1AGQARABwAGoAWgBXADUAMABaAFgASQA3AGMA
>> "%~1" echo RwBGAGsAWgBHAGwAdQBaAHoAbwB3AEkARABFAHgAYwBIAGcANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxADMAWgBXAGwAbgBhAEgAUQA2AE8ARABBAHcATwAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeABNAG4AQgA0AGYAUQAwAEsATABuAEIAaABjAG0ARgB0AFMA
>> "%~1" echo WABSAGwAYgBTADUAagBhAEcARgB1AFoAMgBWAGsAZQAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo aQAxAGoAYgAyAHgAdgBjAGoAcAB5AFoAMgBKAGgASwBEAEkAeABOAHkAdwB4AE0A
>> "%~1" echo VABrAHMATgBpAHcAdQBOAEQAVQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAYwBtAGQAaQBZAFMAZwB5AE0AVABjAHMATQBUAEUANQBMAEQAWQBzAEwA
>> "%~1" echo agBBADIASwBYADAAdQBjAEcARgB5AFkAVwAxAEoAZABHAFYAdABMAG0ATgBvAFkA
>> "%~1" echo VwA1AG4AWgBXAFEAZwBMAG4AQgBoAGMAbQBGAHQAVQAzAFIAaABkAEcAVgA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcATgB2AGIARwA5AHkATwBuAEoAbgBZAG0ARQBvAE0A
>> "%~1" echo agBFADMATABEAEUAeABPAFMAdwAyAEwAQwA0ADAATgBTAGsANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AFkAVwAxAGkAWgBYAEkAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAeQBNAFQAYwBzAE0A
>> "%~1" echo VABFADUATABEAFkAcwBMAGoAQQA0AEsAWAAwAE4AQwBpADUAdwBZAFgASgBoAGIA
>> "%~1" echo VQBsADAAWgBXADAAdQBiADIAcwBnAEwAbgBCAGgAYwBtAEYAdABVADMAUgBoAGQA
>> "%~1" echo RwBWADcAWQBtADkAeQBaAEcAVgB5AEwAVwBOAHYAYgBHADkAeQBPAG4ASgBuAFkA
>> "%~1" echo bQBFAG8ATQBqAEkAcwBNAFQAWQB6AEwARABjADAATABDADQAegBOAFMAawA3AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWgAzAEoAbABaAFcANABwAE8A
>> "%~1" echo MgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQAaQBZAFMAZwB5AE0A
>> "%~1" echo aQB3AHgATgBqAE0AcwBOAHoAUQBzAEwAagBBADQASwBYADAATgBDAGkANQB5AFoA
>> "%~1" echo WABOAGwAZABFAEoAMABiAG4AdABvAFoAVwBsAG4AYQBIAFEANgBNAHoARgB3AGUA
>> "%~1" echo RAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYAegBPAGoAaAB3AGUA
>> "%~1" echo RAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBIAE4AdgBiAEcAbABrAEkA
>> "%~1" echo SABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAEoAaABZADIAdABuAGMA
>> "%~1" echo bQA5ADEAYgBtAFEANgBkAG0ARgB5AEsAQwAwAHQAWQAyAEYAeQBaAEMAawA3AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAZABHAFYANABkAEMAawA3AFoA
>> "%~1" echo bQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATwBEAEEAdwBPADMAQgBoAFoA
>> "%~1" echo RwBSAHAAYgBtAGMANgBNAEMAQQB4AE0AWABCADQATwAyAE4AMQBjAG4ATgB2AGMA
>> "%~1" echo agBwAHcAYgAyAGwAdQBkAEcAVgB5AGYAUwA1AHkAWgBYAE4AbABkAEUASgAwAGIA
>> "%~1" echo aQA1AHcAYwBtAGwAdABZAFgASgA1AGUAMgBKAHYAYwBtAFIAbABjAGkAMQBqAGIA
>> "%~1" echo MgB4AHYAYwBqAHAAeQBaADIASgBoAEsARABNADMATABEAGsANQBMAEQASQB6AE4A
>> "%~1" echo UwB3AHUATgBEAFUAcABPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwBKAHMAZABXAFUAcABmAFEAMABLAEwAbgBSAHYAWQBYAE4AMABjADMAdAB3AGIA
>> "%~1" echo MwBOAHAAZABHAGwAdgBiAGoAcABtAGEAWABoAGwAWgBEAHQAeQBhAFcAZABvAGQA
>> "%~1" echo RABvAHkATQBuAEIANABPADIASgB2AGQASABSAHYAYgBUAG8AeQBNAG4AQgA0AE8A
>> "%~1" echo MwBvAHQAYQBXADUAawBaAFgAZwA2AE4AagBBADcAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VABwAG0AYgBHAFYANABPADIAWgBzAFoAWABnAHQAWgBHAGwAeQBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUATwBtAE4AdgBiAEgAVgB0AGIAaQAxAHkAWgBYAFoAbABjAG4ATgBsAE8A
>> "%~1" echo MgBkAGgAYwBEAG8AeABNAEgAQgA0AE8AMwBkAHAAWgBIAFIAbwBPAG0AMQBwAGIA
>> "%~1" echo aQBnAHoATwBUAEIAdwBlAEMAeABqAFkAVwB4AGoASwBEAEUAdwBNAEgAWgAzAEkA
>> "%~1" echo QwAwAGcATQBqAGgAdwBlAEMAawBwAE8AMwBCAHYAYQBXADUAMABaAFgASQB0AFoA
>> "%~1" echo WABaAGwAYgBuAFIAegBPAG0ANQB2AGIAbQBWADkARABRAG8AdQBkAEcAOQBoAGMA
>> "%~1" echo MwBSADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBDAEIAegBiADIAeABwAFoA
>> "%~1" echo QwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJAHQAYgBHAFYAbQBkAEQAbwAwAGMASABnAGcAYwAyADkAcwBhAFcAUQBnAGQA
>> "%~1" echo bQBGAHkASwBDADAAdABZAG0AeAAxAFoAUwBrADcAWQBtAEYAagBhADIAZAB5AGIA
>> "%~1" echo MwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAGoAWQBYAEoAawBLAFQAdABpAGIA
>> "%~1" echo MwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AagBBAGcATQBUAFoAdwBlAEMAQQB6AE8A
>> "%~1" echo SABCADQASQBIAEoAbgBZAG0ARQBvAE0AVABVAHMATQBqAE0AcwBOAEQASQBzAEwA
>> "%~1" echo agBJAHcASwBUAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8A
>> "%~1" echo agBFAHcAYwBIAGcANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABNAG4AQgA0AEkA
>> "%~1" echo RABFAHoAYwBIAGcANwBiADMAQgBoAFkAMgBsADAAZQBUAG8AdwBPADMAUgB5AFkA
>> "%~1" echo VwA1AHoAWgBtADkAeQBiAFQAcAAwAGMAbQBGAHUAYwAyAHgAaABkAEcAVgBZAEsA
>> "%~1" echo RABJADAAYwBIAGcAcABJAEgAUgB5AFkAVwA1AHoAYgBHAEYAMABaAFYAawBvAE0A
>> "%~1" echo VABCAHcAZQBDAGsAZwBjADIATgBoAGIARwBVAG8ATABqAGsANABLAFQAdAAwAGMA
>> "%~1" echo bQBGAHUAYwAyAGwAMABhAFcAOQB1AE8AbQA5AHcAWQBXAE4AcABkAEgAawBnAEwA
>> "%~1" echo agBJAHkAYwB5AEIAbABZAFgATgBsAEwASABSAHkAWQBXADUAegBaAG0AOQB5AGIA
>> "%~1" echo UwBBAHUATQBqAEoAegBJAEcATgAxAFkAbQBsAGoATABXAEoAbABlAG0AbABsAGMA
>> "%~1" echo aQBnAHUATQBpAHcAdQBPAEMAdwB1AE0AaQB3AHgASwBUAHQAdwBiADIAbAB1AGQA
>> "%~1" echo RwBWAHkATABXAFYAMgBaAFcANQAwAGMAegBwAGgAZABYAFIAdgBmAFEAMABLAEwA
>> "%~1" echo bgBSAHYAWQBYAE4AMABMAG4ATgBvAGIAMwBkADcAYgAzAEIAaABZADIAbAAwAGUA
>> "%~1" echo VABvAHgATwAzAFIAeQBZAFcANQB6AFoAbQA5AHkAYgBUAHAAdQBiADIANQBsAGYA
>> "%~1" echo UwA1ADAAYgAyAEYAegBkAEMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFkA
>> "%~1" echo bQB4AHYAWQAyAHMANwBiAFcARgB5AFoAMgBsAHUATABXAEoAdgBkAEgAUgB2AGIA
>> "%~1" echo VABvADAAYwBIAGgAOQBMAG4AUgB2AFkAWABOADAASQBIAE4AdwBZAFcANQA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABpAGIARwA5AGoAYQB6AHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBiAEcAbAB1AFoA
>> "%~1" echo UwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0AUwA0ADAATgBUAHQAMwBiADMASgBrAEwA
>> "%~1" echo VwBKAHkAWgBXAEYAcgBPAG0ASgB5AFoAVwBGAHIATABYAGQAdgBjAG0AUgA5AEQA
>> "%~1" echo UQBvAHUAZABHADkAaABjADMAUQB1AGIAMgB0ADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo VwB4AGwAWgBuAFEAdABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFoA
>> "%~1" echo MwBKAGwAWgBXADQAcABmAFMANQAwAGIAMgBGAHoAZABDADUAbABjAG4ASgA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcAeABsAFoAbgBRAHQAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABjAG0AVgBrAEsAWAAwAHUAZABHADkAaABjADMAUQB1AGQA
>> "%~1" echo MgBGAHkAYgBuAHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYAbQBkAEMAMQBqAGIA
>> "%~1" echo MgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAGgAYgBXAEoAbABjAGkAbAA5AEQA
>> "%~1" echo UQBvAHUAYgBXADkAawBZAFcAeABOAFkAWABOAHIAZQAzAEIAdgBjADIAbAAwAGEA
>> "%~1" echo VwA5AHUATwBtAFoAcABlAEcAVgBrAE8AMgBsAHUAYwAyAFYAMABPAGoAQQA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwAHkAWgAyAEoAaABLAEQASQBzAE4A
>> "%~1" echo aQB3AHkATQB5AHcAdQBOAFQAWQBwAE8AMwBvAHQAYQBXADUAawBaAFgAZwA2AE4A
>> "%~1" echo egBBADcAWgBHAGwAegBjAEcAeABoAGUAVABwAHUAYgAyADUAbABPADMAQgBzAFkA
>> "%~1" echo VwBOAGwATABXAGwAMABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdAB3AFkA
>> "%~1" echo VwBSAGsAYQBXADUAbgBPAGoARQA0AGMASABoADkATABtADEAdgBaAEcARgBzAFQA
>> "%~1" echo VwBGAHoAYQB5ADUAegBhAEcAOQAzAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoA
>> "%~1" echo MwBKAHAAWgBIADAATgBDAGkANQB0AGIAMgBSAGgAYgBIAHQAMwBhAFcAUgAwAGEA
>> "%~1" echo RABwAHQAYQBXADQAbwBOAEQAYwB3AGMASABnAHMATQBUAEEAdwBKAFMAawA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQBqAFkA
>> "%~1" echo WABKAGsASwBUAHQAaQBiADMASgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIA
>> "%~1" echo RwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATQBUAEoAdwBlAEQAdABpAGIA
>> "%~1" echo MwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AagBBAGcATQBqAFIAdwBlAEMAQQAzAE0A
>> "%~1" echo SABCADQASQBIAEoAbgBZAG0ARQBvAE0AQwB3AHcATABEAEEAcwBMAGoATQAxAEsA
>> "%~1" echo VAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBJAHcAYwBIAGgAOQBEAFEAbwB1AGIA
>> "%~1" echo VwA5AGsAWQBXAHcAZwBhAEQATgA3AGIAVwBGAHkAWgAyAGwAdQBPAGoAQQBnAE0A
>> "%~1" echo QwBBADQAYwBIAGcANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQA0AGMA
>> "%~1" echo SABoADkATABtADEAdgBaAEcARgBzAEkASABCADcAYgBXAEYAeQBaADIAbAB1AE8A
>> "%~1" echo agBBADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgAMABPAGoARQB1AE4A
>> "%~1" echo agBVADcAZAAyAGgAcABkAEcAVQB0AGMAMwBCAGgAWQAyAFUANgBjAEgASgBsAEwA
>> "%~1" echo WABkAHkAWQBYAEEANwBkADIAOQB5AFoAQwAxAGkAYwBtAFYAaABhAHoAcABpAGMA
>> "%~1" echo bQBWAGgAYQB5ADEAMwBiADMASgBrAGYAUQAwAEsATABtADEAdgBaAEcARgBzAFEA
>> "%~1" echo VwBOADAAYQBXADkAdQBjADMAdABrAGEAWABOAHcAYgBHAEYANQBPAG0AWgBzAFoA
>> "%~1" echo WABnADcAYQBuAFYAegBkAEcAbABtAGUAUwAxAGoAYgAyADUAMABaAFcANQAwAE8A
>> "%~1" echo bQBaAHMAWgBYAGcAdABaAFcANQBrAE8AMgBkAGgAYwBEAG8AeABNAEgAQgA0AE8A
>> "%~1" echo MgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYATQBUAGgAdwBlAEgAMABOAEMA
>> "%~1" echo aQA1AHQAYgAyAFIAaABiAEUARgBqAGQARwBsAHYAYgBuAE0AZwBZAG4AVgAwAGQA
>> "%~1" echo RwA5AHUAZQAyAGgAbABhAFcAZABvAGQARABvAHoATgBuAEIANABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATwBIAEIANABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoA
>> "%~1" echo RABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBUAHQAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQAwAFoAWABoADAASwBUAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEEAZwBNAFQAUgB3AGUARAB0AG0AYgAyADUAMABMAFgAZABsAGEA
>> "%~1" echo VwBkAG8AZABEAG8ANABNAEQAQQA3AFkAMwBWAHkAYwAyADkAeQBPAG4AQgB2AGEA
>> "%~1" echo VwA1ADAAWgBYAEoAOQBEAFEAbwB1AGIAVwA5AGsAWQBXAHgAQgBZADMAUgBwAGIA
>> "%~1" echo MgA1AHoASQBDADUAawBZAFcANQBuAFoAWABKADcAWQBtAEYAagBhADIAZAB5AGIA
>> "%~1" echo MwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAGgAYgBXAEoAbABjAGkAawA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwBGAHQAWQBtAFYAeQBLAFQAdABqAGIAMgB4AHYAYwBqAG8AagBNAFQARQB4AE8A
>> "%~1" echo RABJADMAZgBRADAASwBMAG0ATgB0AFoAQwA1AHAAYwB5ADEAaQBkAFgATgA1AEwA
>> "%~1" echo QwA1AGkAZABHADQAdQBhAFgATQB0AFkAbgBWAHoAZQBYAHQAdgBjAEcARgBqAGEA
>> "%~1" echo WABSADUATwBpADQAMgBPAEQAdABqAGQAWABKAHoAYgAzAEkANgBkADIARgBwAGQA
>> "%~1" echo SAAwAHUAWQAyADEAawBPAG0AUgBwAGMAMgBGAGkAYgBHAFYAawBMAEMANQBpAGQA
>> "%~1" echo RwA0ADYAWgBHAGwAegBZAFcASgBzAFoAVwBRAHMATABuAEoAbABjADIAVgAwAFEA
>> "%~1" echo bgBSAHUATwBtAFIAcABjADIARgBpAGIARwBWAGsAZQAzAEIAdgBhAFcANQAwAFoA
>> "%~1" echo WABJAHQAWgBYAFoAbABiAG4AUgB6AE8AbQA1AHYAYgBtAFUANwBiADMAQgBoAFkA
>> "%~1" echo MgBsADAAZQBUAG8AdQBOAG4AMABOAEMAawBCAHQAWgBXAFIAcABZAFMAaAB0AFkA
>> "%~1" echo WABnAHQAZAAyAGwAawBkAEcAZwA2AE0AVABFADQATQBIAEIANABLAFgAcwB1AGMA
>> "%~1" echo bQA5ADMATABDADUAeQBiADMAYwB6AGUAMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMA
>> "%~1" echo RwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AG8AeABaAG4ASgA5AEwA
>> "%~1" echo bQBsAHUAWgBtADkASABjAG0AbABrAEwAQwA1AGgAYwBHAHQASABjAG0AbABrAGUA
>> "%~1" echo MgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQA
>> "%~1" echo VwAxAHUAYwB6AG8AeABaAG4ASQBnAE0AVwBaAHkAZgBYADAATgBDAGsAQgB0AFoA
>> "%~1" echo VwBSAHAAWQBTAGgAdABZAFgAZwB0AGQAMgBsAGsAZABHAGcANgBPAEQASQB3AGMA
>> "%~1" echo SABnAHAAZQB5ADUAaABjAEgAQgA3AFoAMwBKAHAAWgBDADEAMABaAFcAMQB3AGIA
>> "%~1" echo RwBGADAAWgBTADEAagBiADIAeAAxAGIAVwA1AHoATwBqAEYAbQBjAG4AMAB1AGMA
>> "%~1" echo MgBsAGsAWgBYAHQAdwBiADMATgBwAGQARwBsAHYAYgBqAHAAegBkAEcARgAwAGEA
>> "%~1" echo VwBNADcAZAAyAGwAawBkAEcAZwA2AFkAWABWADAAYgB6AHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYAWQBYAFYAMABiADMAMAB1AGIAVwBGAHAAYgBuAHQAbgBjAG0AbABrAEwA
>> "%~1" echo VwBOAHYAYgBIAFYAdABiAGoAbwB4AGYAUwA1ADAAYgAzAEIANwBjAEcAOQB6AGEA
>> "%~1" echo WABSAHAAYgAyADQANgBjADMAUgBoAGQARwBsAGoATwAyAGgAbABhAFcAZABvAGQA
>> "%~1" echo RABwAGgAZABYAFIAdgBPADIARgBzAGEAVwBkAHUATABXAGwAMABaAFcAMQB6AE8A
>> "%~1" echo bQBaAHMAWgBYAGcAdABjADMAUgBoAGMAbgBRADcAWgBtAHgAbABlAEMAMQBrAGEA
>> "%~1" echo WABKAGwAWQAzAFIAcABiADIANAA2AFkAMgA5AHMAZABXADEAdQBPADIAZABoAGMA
>> "%~1" echo RABvAHgATQBIAEIANABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQAWgB3AGUA
>> "%~1" echo SAAwAHUAZAAzAEoAaABjAEgAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoARQAwAGMA
>> "%~1" echo SABoADkATABtADEAbABkAEgASgBwAFkAMABkAHkAYQBXAFEAcwBMAG0ATgB0AFoA
>> "%~1" echo RQBkAHkAYQBXAFEAcwBMAG0AWgB2AGMAbQAwAHMATABuAEIAaABjAG0ARgB0AFMA
>> "%~1" echo WABSAGwAYgBTAHcAdQBhAFcANQBtAGIAMABkAHkAYQBXAFEAcwBMAG0ARgB3AGEA
>> "%~1" echo MABkAHkAYQBXAFEAcwBMAG0AVgA0AGMARwA5AHkAZABFAEoAdgBlAEgAdABuAGMA
>> "%~1" echo bQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIA
>> "%~1" echo bgBNADYATQBXAFoAeQBmAFMANQB5AGEAVwBkADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAGoARgBtAGMA
>> "%~1" echo bgAwAHUAZABHADkAaABjADMAUgB6AGUAMwBKAHAAWgAyAGgAMABPAGoARQAwAGMA
>> "%~1" echo SABnADcAWQBtADkAMABkAEcAOQB0AE8AagBFADAAYwBIAGgAOQBmAFEAMABLAFAA
>> "%~1" echo QwA5AHoAZABIAGwAcwBaAFQANABOAEMAagB3AHYAYQBHAFYAaABaAEQANABOAEMA
>> "%~1" echo agB4AGkAYgAyAFIANQBJAEcATgBzAFkAWABOAHoAUABTAEoAawBZAFgASgByAEkA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgB2AFkA
>> "%~1" echo WABOADAAYwB5AEkAZwBhAFcAUQA5AEkAbgBSAHYAWQBYAE4AMABjAHkASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHQAYgAyAFIAaABiAEUAMQBoAGMAMgBzAGkASQBHAGwAawBQAFMASgBqAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABUAFcARgB6AGEAeQBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAFcAOQBrAFkAVwB3AGkAUABqAHgAbwBNAHkAQgBwAFoA
>> "%~1" echo RAAwAGkAWQAyADkAdQBaAG0AbAB5AGIAVgBSAHAAZABHAHgAbABJAGoANwBuAG8A
>> "%~1" echo YQA3AG8AcgBxAFQAbQBpAGEAZgBvAG8AWQB3ADgATAAyAGcAegBQAGoAeAB3AEkA
>> "%~1" echo RwBsAGsAUABTAEoAagBiADIANQBtAGEAWABKAHQAVABYAE4AbgBJAGoANwBvAHYA
>> "%~1" echo NQBuAGsAdQBLAHIAbQBrADQAMwBrAHYAWgB6AGsAdgBKAHIAawB2ADYANwBtAGwA
>> "%~1" echo TABrAGcAVQBYAFYAbABjADMAUQBnADUANABxADIANQBvAEMAQgA0ADQAQwBDAFAA
>> "%~1" echo QwA5AHcAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQB2AFoA
>> "%~1" echo RwBGAHMAUQBXAE4AMABhAFcAOQB1AGMAeQBJACsAUABHAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo aQBCAHAAWgBEADAAaQBZADIAOQB1AFoAbQBsAHkAYgBVAE4AaABiAG0ATgBsAGIA
>> "%~1" echo QwBJACsANQBZACsAVwA1AHIAYQBJAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAA
>> "%~1" echo RwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBaAEcARgB1AFoA
>> "%~1" echo MgBWAHkASQBpAEIAcABaAEQAMABpAFkAMgA5AHUAWgBtAGwAeQBiAFUAOQByAEkA
>> "%~1" echo agA3AG4AbwBhADcAbwByAHEAVABtAGkAYQBmAG8AbwBZAHcAOABMADIASgAxAGQA
>> "%~1" echo SABSAHYAYgBqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAeAB6AGQAbQBjAGcAZAAyAGwAawBkAEcAZwA5AEkA
>> "%~1" echo agBBAGkASQBHAGgAbABhAFcAZABvAGQARAAwAGkATQBDAEkAZwBjADMAUgA1AGIA
>> "%~1" echo RwBVADkASQBuAEIAdgBjADIAbAAwAGEAVwA5AHUATwBtAEYAaQBjADIAOQBzAGQA
>> "%~1" echo WABSAGwASQBqADQATgBDAGoAeAB6AGUAVwAxAGkAYgAyAHcAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBrAHQAZABuAEkAaQBJAEgAWgBwAFoAWABkAEMAYgAzAGcAOQBJAGoAQQBnAE0A
>> "%~1" echo QwBBAHkATgBDAEEAeQBOAEMASQArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQA
>> "%~1" echo VABZAGcATwBXAGcAeABNAG0ARQB6AEkARABNAGcATQBDAEEAdwBJAEQARQBnAE0A
>> "%~1" echo eQBBAHoAZABqAE4AaABNAHkAQQB6AEkARABBAGcATQBDAEEAeABMAFQATQBnAE0A
>> "%~1" echo MgBnAHQATQBTADQAMQBiAEMAMAB5AEwAagBVAHQATQAyAGcAdABOAEcAdwB0AE0A
>> "%~1" echo aQA0ADEASQBEAE4ASQBOAG0ARQB6AEkARABNAGcATQBDAEEAdwBJAEQARQB0AE0A
>> "%~1" echo eQAwAHoAZABpADAAegBZAFQATQBnAE0AeQBBAHcASQBEAEEAZwBNAFMAQQB6AEwA
>> "%~1" echo VABOADYASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAawBnAE0A
>> "%~1" echo VABKAG8ATABqAEEAeABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQA
>> "%~1" echo VABFADEASQBEAEUAeQBhAEMANAB3AE0AUwBJAHYAUABqAHgAdwBZAFgAUgBvAEkA
>> "%~1" echo RwBRADkASQBrADAAeABNAEMAQQB4AE4AVwBnADAASQBpADgAKwBQAEMAOQB6AGUA
>> "%~1" echo VwAxAGkAYgAyAHcAKwBEAFEAbwA4AGMAMwBsAHQAWQBtADkAcwBJAEcAbABrAFAA
>> "%~1" echo UwBKAHAATABXAGgAdgBiAFcAVQBpAEkASABaAHAAWgBYAGQAQwBiADMAZwA5AEkA
>> "%~1" echo agBBAGcATQBDAEEAeQBOAEMAQQB5AE4AQwBJACsAUABIAEIAaABkAEcAZwBnAFoA
>> "%~1" echo RAAwAGkAVABUAFUAZwBNAFQASgBzAE4AeQAwADMAYgBEAGMAZwBOAHkASQB2AFAA
>> "%~1" echo agB4AHcAWQBYAFIAbwBJAEcAUQA5AEkAawAwADIASQBEAEUAdwBkAGoAbABvAE0A
>> "%~1" echo VABKADIATABUAGsAaQBMAHoANAA4AEwAMwBOADUAYgBXAEoAdgBiAEQANABOAEMA
>> "%~1" echo agB4AHoAZQBXADEAaQBiADIAdwBnAGEAVwBRADkASQBtAGsAdABZADIAOQB1AGMA
>> "%~1" echo MgA5AHMAWgBTAEkAZwBkAG0AbABsAGQAMABKAHYAZQBEADAAaQBNAEMAQQB3AEkA
>> "%~1" echo RABJADAASQBEAEkAMABJAGoANAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE8A
>> "%~1" echo QwBBADUAYgBEAE0AZwBNADIAdwB0AE0AeQBBAHoASQBpADgAKwBQAEgAQgBoAGQA
>> "%~1" echo RwBnAGcAWgBEADAAaQBUAFQARQB6AEkARABFADEAYQBEAE0AaQBMAHoANAA4AGMA
>> "%~1" echo RwBGADAAYQBDAEIAawBQAFMASgBOAE0AeQBBADAAYQBEAEUANABkAGoARQAyAFMA
>> "%~1" echo RABOADYASQBpADgAKwBQAEMAOQB6AGUAVwAxAGkAYgAyAHcAKwBEAFEAbwA4AGMA
>> "%~1" echo MwBsAHQAWQBtADkAcwBJAEcAbABrAFAAUwBKAHAATABXAEYAdwBhAHkASQBnAGQA
>> "%~1" echo bQBsAGwAZAAwAEoAdgBlAEQAMABpAE0AQwBBAHcASQBEAEkAMABJAEQASQAwAEkA
>> "%~1" echo agA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATQBUAEkAZwBNADMAWQB4AE0A
>> "%~1" echo aQBJAHYAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAANABJAEQARQB4AGIA
>> "%~1" echo RABRAGcATgBHAHcAMABMAFQAUQBpAEwAegA0ADgAYwBHAEYAMABhAEMAQgBrAFAA
>> "%~1" echo UwBKAE4ATgBDAEEAeABOADMAWQB5AFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0A
>> "%~1" echo QwBBAHkASQBEAEoAbwBNAFQASgBoAE0AaQBBAHkASQBEAEEAZwBNAEMAQQB3AEkA
>> "%~1" echo RABJAHQATQBuAFkAdABNAGkASQB2AFAAagB3AHYAYwAzAGwAdABZAG0AOQBzAFAA
>> "%~1" echo ZwAwAEsAUABIAE4ANQBiAFcASgB2AGIAQwBCAHAAWgBEADAAaQBhAFMAMQBwAGIA
>> "%~1" echo bQBaAHYASQBpAEIAMgBhAFcAVgAzAFEAbQA5ADQAUABTAEkAdwBJAEQAQQBnAE0A
>> "%~1" echo agBRAGcATQBqAFEAaQBQAGoAeAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAB4AE0A
>> "%~1" echo aQBBADUAYQBDADQAdwBNAFMASQB2AFAAagB4AHcAWQBYAFIAbwBJAEcAUQA5AEkA
>> "%~1" echo awAwAHgATQBTAEEAeABNAG0AZwB4AGQAagBSAG8ATQBTAEkAdgBQAGoAeAB3AFkA
>> "%~1" echo WABSAG8ASQBHAFEAOQBJAGsAMAB4AE0AaQBBAHoAWQBUAGsAZwBPAFMAQQB3AEkA
>> "%~1" echo RABFAGcATQBDAEEAdwBJAEQARQA0AFkAVABrAGcATwBTAEEAdwBJAEQAQQBnAE0A
>> "%~1" echo QwBBAHcATABUAEUANABlAGkASQB2AFAAagB3AHYAYwAzAGwAdABZAG0AOQBzAFAA
>> "%~1" echo ZwAwAEsAUABIAE4ANQBiAFcASgB2AGIAQwBCAHAAWgBEADAAaQBhAFMAMQB6AFoA
>> "%~1" echo WABSADAAYQBXADUAbgBjAHkASQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQAMABpAE0A
>> "%~1" echo QwBBAHcASQBEAEkAMABJAEQASQAwAEkAagA0ADgAYwBHAEYAMABhAEMAQgBrAFAA
>> "%~1" echo UwBKAE4ATQBUAEEAdQBNAHoASQAxAEkARABRAHUATQB6AEUAMwBZAFQASQBnAE0A
>> "%~1" echo aQBBAHcASQBEAEEAZwBNAFMAQQB6AEwAagBNADEASQBEAEIAcwBMAGoASQB1AE0A
>> "%~1" echo egBRADAAWQBUAEkAZwBNAGkAQQB3AEkARABBAGcATQBDAEEAeQBMAGoAQQB3AE8A
>> "%~1" echo UwA0ADUATgBtAHcAdQBNAHoAawB5AEwAUwA0AHcATgB6AFIAaABNAGkAQQB5AEkA
>> "%~1" echo RABBAGcATQBDAEEAeABJAEQASQB1AE0AegBZAGcATQBpADQAegBOAG0AdwB0AEwA
>> "%~1" echo agBBADMATgBDADQAegBPAFQASgBoAE0AaQBBAHkASQBEAEEAZwBNAEMAQQB3AEkA
>> "%~1" echo QwA0ADUATgBpAEEAeQBMAGoAQQB3AE8AVwB3AHUATQB6AFEAMABMAGoASgBoAE0A
>> "%~1" echo aQBBAHkASQBEAEEAZwBNAEMAQQB4AEkARABBAGcATQB5ADQAegBOAFcAdwB0AEwA
>> "%~1" echo agBNADAATgBDADQAeQBZAFQASQBnAE0AaQBBAHcASQBEAEEAZwBNAEMAMAB1AE8A
>> "%~1" echo VABZAGcATQBpADQAdwBNAEQAbABzAEwAagBBADMATgBDADQAegBPAFQASgBoAE0A
>> "%~1" echo aQBBAHkASQBEAEEAZwBNAEMAQQB4AEwAVABJAHUATQB6AFkAZwBNAGkANAB6AE4A
>> "%~1" echo bQB3AHQATABqAE0ANQBNAGkAMAB1AE0ARABjADAAWQBUAEkAZwBNAGkAQQB3AEkA
>> "%~1" echo RABBAGcATQBDADAAeQBMAGoAQQB3AE8AUwA0ADUATgBtAHcAdABMAGoASQB1AE0A
>> "%~1" echo egBRADAAWQBUAEkAZwBNAGkAQQB3AEkARABBAGcATQBTADAAegBMAGoATQAxAEkA
>> "%~1" echo RABCAHMATABTADQAeQBMAFMANAB6AE4ARABSAGgATQBpAEEAeQBJAEQAQQBnAE0A
>> "%~1" echo QwBBAHcATABUAEkAdQBNAEQAQQA1AEwAUwA0ADUATgBtAHcAdABMAGoATQA1AE0A
>> "%~1" echo aQA0AHcATgB6AFIAaABNAGkAQQB5AEkARABBAGcATQBDAEEAeABMAFQASQB1AE0A
>> "%~1" echo egBZAHQATQBpADQAegBOAG0AdwB1AE0ARABjADAATABTADQAegBPAFQASgBoAE0A
>> "%~1" echo aQBBAHkASQBEAEEAZwBNAEMAQQB3AEwAUwA0ADUATgBpADAAeQBMAGoAQQB3AE8A
>> "%~1" echo VwB3AHQATABqAE0AMABOAEMAMAB1AE0AbQBFAHkASQBEAEkAZwBNAEMAQQB3AEkA
>> "%~1" echo RABFAGcATQBDADAAegBMAGoATQAxAGIAQwA0AHoATgBEAFEAdABMAGoASgBoAE0A
>> "%~1" echo aQBBAHkASQBEAEEAZwBNAEMAQQB3AEkAQwA0ADUATgBpADAAeQBMAGoAQQB3AE8A
>> "%~1" echo VwB3AHQATABqAEEAMwBOAEMAMAB1AE0AegBrAHkAWQBUAEkAZwBNAGkAQQB3AEkA
>> "%~1" echo RABBAGcATQBTAEEAeQBMAGoATQAyAEwAVABJAHUATQB6AFoAcwBMAGoATQA1AE0A
>> "%~1" echo aQA0AHcATgB6AFIAaABNAGkAQQB5AEkARABBAGcATQBDAEEAdwBJAEQASQB1AE0A
>> "%~1" echo RABBADUATABTADQANQBOAG4AbwBpAEwAegA0ADgAYwBHAEYAMABhAEMAQgBrAFAA
>> "%~1" echo UwBKAE4ATwBTAEEAeABNAG0ARQB6AEkARABNAGcATQBDAEEAeABJAEQAQQBnAE4A
>> "%~1" echo aQBBAHcAWQBUAE0AZwBNAHkAQQB3AEkARABBAGcATQBDADAAMgBJAEQAQQBpAEwA
>> "%~1" echo egA0ADgATAAzAE4ANQBiAFcASgB2AGIARAA0AE4AQwBqAHgAegBlAFcAMQBpAGIA
>> "%~1" echo MgB3AGcAYQBXAFEAOQBJAG0AawB0AGIARwA5AG4ASQBpAEIAMgBhAFcAVgAzAFEA
>> "%~1" echo bQA5ADQAUABTAEkAdwBJAEQAQQBnAE0AagBRAGcATQBqAFEAaQBQAGoAeAB3AFkA
>> "%~1" echo WABSAG8ASQBHAFEAOQBJAGsAMAAxAEkARABWAG8ATQBUAFIAMgBNAFQAUgBJAE4A
>> "%~1" echo WABvAGkATAB6ADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBPAFMAQQA1AGEA
>> "%~1" echo RABZAGkATAB6ADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBPAFMAQQB4AE0A
>> "%~1" echo MgBnADIASQBpADgAKwBQAEMAOQB6AGUAVwAxAGkAYgAyAHcAKwBEAFEAbwA4AGMA
>> "%~1" echo MwBsAHQAWQBtADkAcwBJAEcAbABrAFAAUwBKAHAATABYAFYAdwBiAEcAOQBoAFoA
>> "%~1" echo QwBJAGcAZABtAGwAbABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQASQAwAEkA
>> "%~1" echo RABJADAASQBqADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBNAFQASQBnAE0A
>> "%~1" echo VABWAFcATgBDAEkAdgBQAGoAeAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAA0AEkA
>> "%~1" echo RABoAHMATgBDADAAMABiAEQAUQBnAE4AQwBJAHYAUABqAHgAdwBZAFgAUgBvAEkA
>> "%~1" echo RwBRADkASQBrADAAMABJAEQARQAxAGQAagBOAGgATQBpAEEAeQBJAEQAQQBnAE0A
>> "%~1" echo QwBBAHcASQBEAEkAZwBNAG0AZwB4AE0AbQBFAHkASQBEAEkAZwBNAEMAQQB3AEkA
>> "%~1" echo RABBAGcATQBpADAAeQBkAGkAMAB6AEkAaQA4ACsAUABDADkAegBlAFcAMQBpAGIA
>> "%~1" echo MgB3ACsARABRAG8AOABMADMATgAyAFoAegA0AE4AQwBqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ARgB3AGMAQwBJACsARABRAG8AOABZAFgATgBwAFoA
>> "%~1" echo RwBVAGcAWQAyAHgAaABjADMATQA5AEkAbgBOAHAAWgBHAFUAaQBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBuAEoAaABiAG0AUQBpAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAeQBZAFcANQBrAFMA
>> "%~1" echo VwBOAHYAYgBpAEkAKwBQAEgATgAyAFoAeQBCADMAYQBXAFIAMABhAEQAMABpAE0A
>> "%~1" echo agBJAGkASQBHAGgAbABhAFcAZABvAGQARAAwAGkATQBqAEkAaQBQAGoAeAAxAGMA
>> "%~1" echo MgBVAGcAYQBIAEoAbABaAGoAMABpAEkAMgBrAHQAZABuAEkAaQBMAHoANAA4AEwA
>> "%~1" echo MwBOADIAWgB6ADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBQAGoAeABpAFAA
>> "%~1" echo bABGADEAWgBYAE4AMABJAEUARgBFAFEAagB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAGsAWQBYAFIAaABMAFcAawB4AE8ARwA0ADkASQBtAEoAeQBZAFcANQBrAFUA
>> "%~1" echo MwBWAGkASQBqADUAVABhAFcANQBuAGIARwBVAHQAUQBrAEYAVQBJAEYAZABsAFkA
>> "%~1" echo bABWAEoAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABnADAASwBQAEcANQBoAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo bQBGADIASQBqADQATgBDAGoAeABoAEkARwBoAHkAWgBXAFkAOQBJAGkATgB2AGQA
>> "%~1" echo bQBWAHkAZABtAGwAbABkAHkASQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ARgBqAGQA
>> "%~1" echo RwBsADIAWgBTAEkAKwBQAEgATgAyAFoAegA0ADgAZABYAE4AbABJAEcAaAB5AFoA
>> "%~1" echo VwBZADkASQBpAE4AcABMAFcAaAB2AGIAVwBVAGkATAB6ADQAOABMADMATgAyAFoA
>> "%~1" echo egA0ADgAYwAzAEIAaABiAGkAQgBrAFkAWABSAGgATABXAGsAeABPAEcANAA5AEkA
>> "%~1" echo bQA1AGgAZABrADkAMgBaAFgASgAyAGEAVwBWADMASQBqADcAbQBnAEwAdgBvAHAA
>> "%~1" echo NABnADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGgAUABnADAASwBQAEcARQBnAGEA
>> "%~1" echo SABKAGwAWgBqADAAaQBJADIATgB2AGIAbgBOAHYAYgBHAFUAaQBQAGoAeAB6AGQA
>> "%~1" echo bQBjACsAUABIAFYAegBaAFMAQgBvAGMAbQBWAG0AUABTAEkAagBhAFMAMQBqAGIA
>> "%~1" echo MgA1AHoAYgAyAHgAbABJAGkAOAArAFAAQwA5AHoAZABtAGMAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWgBHAEYAMABZAFMAMQBwAE0AVABoAHUAUABTAEoAdQBZAFgAWgBEAGIA
>> "%~1" echo MgA1AHoAYgAyAHgAbABJAGoANwBsAHYANgB2AG0AagBiAGYAbQBqAHEAZgBsAGkA
>> "%~1" echo TABiAGwAagA3AEEAOABMADMATgB3AFkAVwA0ACsAUABDADkAaABQAGcAMABLAFAA
>> "%~1" echo RwBFAGcAYQBIAEoAbABaAGoAMABpAEkAMgBGAHcAYwBIAE0AaQBQAGoAeAB6AGQA
>> "%~1" echo bQBjACsAUABIAFYAegBaAFMAQgBvAGMAbQBWAG0AUABTAEkAagBhAFMAMQBoAGMA
>> "%~1" echo RwBzAGkATAB6ADQAOABMADMATgAyAFoAegA0ADgAYwAzAEIAaABiAGkAQgBrAFkA
>> "%~1" echo WABSAGgATABXAGsAeABPAEcANAA5AEkAbQA1AGgAZABrAEYAdwBjAEgATQBpAFAA
>> "%~1" echo dQBXADYAbABPAGUAVQBxAEQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIARQArAEQA
>> "%~1" echo UQBvADgAWQBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBHAFYAaABaAEgATgBsAGQA
>> "%~1" echo QwBJACsAUABIAE4AMgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkA
>> "%~1" echo aQBOAHAATABYAE4AbABkAEgAUgBwAGIAbQBkAHoASQBpADgAKwBQAEMAOQB6AGQA
>> "%~1" echo bQBjACsAUABIAE4AdwBZAFcANABnAFoARwBGADAAWQBTADEAcABNAFQAaAB1AFAA
>> "%~1" echo UwBKAHUAWQBYAFoASQBaAFcARgBrAGMAMgBWADAASQBqADcAbABwAEwAVABtAG0A
>> "%~1" echo TAA3AG8AcgByADcAbgB2AGEANAA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBoAFAA
>> "%~1" echo ZwAwAEsAUABHAEUAZwBhAEgASgBsAFoAagAwAGkASQAyAFIAbABkAG0AbABqAFoA
>> "%~1" echo UwBJACsAUABIAE4AMgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkA
>> "%~1" echo aQBOAHAATABXAGwAdQBaAG0AOABpAEwAegA0ADgATAAzAE4AMgBaAHoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAawBZAFgAUgBoAEwAVwBrAHgATwBHADQAOQBJAG0ANQBoAGQA
>> "%~1" echo awBSAGwAZABtAGwAagBaAFMASQArADYASwA2ACsANQBhAFMASAA1AEwAKwBoADUA
>> "%~1" echo bwBHAHYAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBUADQATgBDAGoAeABoAEkA
>> "%~1" echo RwBoAHkAWgBXAFkAOQBJAGkATgBzAGIAMgBkAHoASQBqADQAOABjADMAWgBuAFAA
>> "%~1" echo agB4ADEAYwAyAFUAZwBhAEgASgBsAFoAagAwAGkASQAyAGsAdABiAEcAOQBuAEkA
>> "%~1" echo aQA4ACsAUABDADkAegBkAG0AYwArAFAASABOAHcAWQBXADQAZwBaAEcARgAwAFkA
>> "%~1" echo UwAxAHAATQBUAGgAdQBQAFMASgB1AFkAWABaAE0AYgAyAGQAegBJAGoANwBtAGwA
>> "%~1" echo NgBYAGwAdgA1AGMAOABMADMATgB3AFkAVwA0ACsAUABDADkAaABQAGcAMABLAFAA
>> "%~1" echo QwA5AHUAWQBYAFkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHUAWQBYAFoARwBiADIAOQAwAEkAaQBCAGsAWQBYAFIAaABMAFcAawB4AE8A
>> "%~1" echo RwA0ADkASQBtADUAaABkAGsAWgB2AGIAMwBRAGkAUAB1AFcAUABxAHUAZQBiAGsA
>> "%~1" echo ZQBXAFEAcgBDAEEAeABNAGoAYwB1AE0AQwA0AHcATABqAEUAOABZAG4ASQArADUA
>> "%~1" echo WQBXAHoANgBaAGUAdAA1ADYAcQBYADUAWQArAGoANQBZADIAegA1AFkARwBjADUA
>> "%~1" echo cQAyAGkANQBwAHkATgA1AFkAcQBoAFAAQwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwA
>> "%~1" echo MgBGAHoAYQBXAFIAbABQAGcAMABLAFAARwAxAGgAYQBXADQAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADEAaABhAFcANABpAFAAZwAwAEsAUABHAGgAbABZAFcAUgBsAGMA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGQARwA5AHcASQBqADQATgBDAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbgBSAHAAZABHAHgAbABJAGoANAA4AGEA
>> "%~1" echo RABFAGcAYQBXAFEAOQBJAG4AQgBoAFoAMgBWAFUAYQBYAFIAcwBaAFMASQArADUA
>> "%~1" echo bwBDADcANgBLAGUASQBQAEMAOQBvAE0AVAA0ADgAYwBDAEIAcABaAEQAMABpAGMA
>> "%~1" echo RwBGAG4AWgBWAE4AMQBZAGkASQArADUANABxADIANQBvAEMAQgA1AG8AeQBIADUA
>> "%~1" echo cQBDAEgANQBaAEsATQA2AEsANgArADUAYQBTAEgANQBxAGEAQwA2AEsAZQBJAFAA
>> "%~1" echo QwA5AHcAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBkAEcAOQB2AGIARwBKAGgAYwBpAEkAKwBEAFEAbwA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAGgAcABjAEMASQBnAGEA
>> "%~1" echo VwBRADkASQBuAE4AMABZAFgAUgAxAGMAMABOAG8AYQBYAEEAaQBQAGoAeABwAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAGEARwBsAHcAUgBHADkAMABJAGoANAA4AEwA
>> "%~1" echo MgBrACsAUABIAE4AdwBZAFcANAArADUAcAB5AHEANgBMACsAZQA1AG8ANgBsAFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGoAdwB2AGMAMwBCAGgAYgBqADQATgBDAGoAeAB6AGMA
>> "%~1" echo RwBGAHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYQBHAGwAdwBJAGoANQBCAFIA
>> "%~1" echo RQBJAGcAUABHAEkAZwBhAFcAUQA5AEkAbQBGAGsAWQBsAE4AbwBiADMASgAwAEkA
>> "%~1" echo agA1AGgAWgBHAEkAdQBaAFgAaABsAFAAQwA5AGkAUABqAHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0AE4AQwBqAHgAegBjAEcARgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGEA
>> "%~1" echo RwBsAHcASQBqADUAWABhAFMAMQBHAGEAUwBBADgAWQBpAEIAcABaAEQAMABpAGQA
>> "%~1" echo MgBsAG0AYQBVAE4AbwBhAFgAQQBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABnADAASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQBuAFIAdQBJAEcAZABvAGIAMwBOADAASQBHAHgAaABiAG0AZABDAGQA
>> "%~1" echo RwA0AGkASQBHAGwAawBQAFMASgBzAFkAVwA1AG4AUQBuAFIAdQBJAGoANQBGAFQA
>> "%~1" echo agB3AHYAWQBuAFYAMABkAEcAOQB1AFAAZwAwAEsAUABHAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAFkAbgBSAHUASQBHAGQAbwBiADMATgAwAEkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBkAEcAaABsAGIAVwBWAEMAZABHADQAaQBQAHUAYQAxAGgA
>> "%~1" echo ZQBpAEoAcwBqAHcAdgBZAG4AVgAwAGQARwA5AHUAUABnADAASwBQAEcASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQBuAFIAdQBJAEgAQgB5AGEA
>> "%~1" echo VwAxAGgAYwBuAGsAaQBJAEcAbABrAFAAUwBKAHkAWgBXAFoAeQBaAFgATgBvAFEA
>> "%~1" echo bgBSAHUASQBqADcAbABpAEwAZgBtAGwAcgBBADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0AE4AQwBqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABDADkAbwBaAFcARgBrAFoA
>> "%~1" echo WABJACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgAzAGMA
>> "%~1" echo bQBGAHcASQBqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBKAGgAYgBtADUAbABjAGkASQBnAGEAVwBRADkASQBtAEYAawBZAGsASgBoAGIA
>> "%~1" echo bQA1AGwAYwBpAEkAKwBQAEcAUgBwAGQAagA0ADgAWQBpAEIAawBZAFgAUgBoAEwA
>> "%~1" echo VwBrAHgATwBHADQAOQBJAG0ARgBrAFkAawAxAHAAYwAzAE4AcABiAG0AZABVAGEA
>> "%~1" echo WABSAHMAWgBTAEkAKwA1AHAAeQBxADUAbwBtACsANQBZAGkAdwBJAEUARgBFAFEA
>> "%~1" echo agB3AHYAWQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAGEA
>> "%~1" echo VwA1ADAASQBpAEIAawBZAFgAUgBoAEwAVwBrAHgATwBHADQAOQBJAG0ARgBrAFkA
>> "%~1" echo awAxAHAAYwAzAE4AcABiAG0AZABJAGEAVwA1ADAASQBqADcAbQBuAEsAegBtAG4A
>> "%~1" echo TAByAG0AcwBxAEgAbQBuAEkAbgBsAGoANgAvAG4AbABLAGoAbgBtAG8AUQBnAFkA
>> "%~1" echo VwBSAGkATABtAFYANABaAGUATwBBAGcAdQBXAFAAcgArAFMANwBwAGUAUwA0AGkA
>> "%~1" echo KwBpADkAdgBTAEIASABiADIAOQBuAGIARwBVAGcAYwBHAHgAaABkAEcAWgB2AGMA
>> "%~1" echo bQAwAHQAZABHADkAdgBiAEgATQBnADUAWQBpAHcANQBiAGUAbAA1AFkAVwAzADUA
>> "%~1" echo NQB1AHUANQBiADIAVgA0ADQAQwBDAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo bgBSAHUASQBIAEIAeQBhAFcAMQBoAGMAbgBrAGkASQBHAGwAawBQAFMASgBoAFoA
>> "%~1" echo RwBKAEUAYgAzAGQAdQBiAEcAOQBoAFoARQBKADAAYgBpAEkAZwBaAEcARgAwAFkA
>> "%~1" echo UwAxAHAATQBUAGgAdQBQAFMASgBoAFoARwBKAEUAYgAzAGQAdQBiAEcAOQBoAFoA
>> "%~1" echo QwBJACsANQBMAGkATAA2AEwAMgA5AEkARQBGAEUAUQBqAHcAdgBZAG4AVgAwAGQA
>> "%~1" echo RwA5AHUAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAG0AOQAwAGEAVwBOAGwASQBpAEIAawBZAFgAUgBoAEwA
>> "%~1" echo VwBrAHgATwBHADQAOQBJAG4AUgB2AGMARQA1AHYAZABHAGwAagBaAFMASQArADUA
>> "%~1" echo TAArAGQANQByAFMANwA0ADQAQwBCAE0AagBRAGcANQBiAEMAUAA1AHAAZQAyADUA
>> "%~1" echo TABxAHUANQBiAEcAUAA1AFoASwBNADUAcABlAGcANQA3AHEALwBJAEUARgBFAFEA
>> "%~1" echo aQBEAGwAagA2AHIAbAB1ADcAcgBvAHIAcQA3AG4AbgA2ADMAbQBsADcAYgBwAGwA
>> "%~1" echo NwBUAG0AdABZAHYAbwByADUAWAB2AHYASgB2AG4AdQA1AFAAbQBuAFoALwBsAGsA
>> "%~1" echo SQA3AG0AaQBhAGYAbwBvAFkAegBpAGcASgB6AGwAcgBvAG4AbABoAGEAagBuAGgA
>> "%~1" echo bwBUAGwAcwBZAC8AaQBnAEoAMwBtAGkASgBiAGkAZwBKAHoAawB2ADUAMwBsAHIA
>> "%~1" echo bwBqAHAAdQA1AGoAbwByAHEAVABsAGcATAB6AGkAZwBKADMAagBnAEkATABsAHIA
>> "%~1" echo bwBuAG8AbwA0AFUAZwBRAFYAQgBMAEkATwBTADgAbQB1AFMALwByAHUAYQBVAHUA
>> "%~1" echo ZQBpAHUAdgB1AFcAawBoACsAKwA4AGoATwBpAHYAdAArAGUAaAByAHUAaQB1AHAA
>> "%~1" echo TwBhAGQAcABlAGEANgBrAE8AVwBQAHIAKwBTAC8AbwBlAE8AQQBnAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABnADAASwBEAFEAbwA4AGMAMgBWAGoAZABHAGwAdgBiAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBjAEcARgBuAFoAUwBCAGgAWQAzAFIAcABkAG0AVQBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAdgBkAG0AVgB5AGQAbQBsAGwAZAB5AEkAKwBEAFEAbwA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHkAYgAzAGMAaQBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAA
>> "%~1" echo RwBnAHkAUAB1AGkAdQB2AHUAVwBrAGgAegB3AHYAYQBEAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5AEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBSAGwAZABtAGwAagBaAFYAUgBoAFoAeQBJACsAVQBYAFYAbABjADMAUQA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUAUwBJACsARABRAG8AOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsAYwAyAFYAMABRAG0AOQA0AEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAawBaAFgAWgBwAFkA
>> "%~1" echo MgBWAEoAWQAyADkAdQBJAGoANAA4AGMAMwBaAG4AUABqAHgAMQBjADIAVQBnAGEA
>> "%~1" echo SABKAGwAWgBqADAAaQBJADIAawB0AGQAbgBJAGkATAB6ADQAOABMADMATgAyAFoA
>> "%~1" echo egA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AUgBsAGQAbQBsAGoAWgBVADUAaABiAFcAVQBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAbwBaAFgASgB2AFQAVwA5AGsAWgBXAHcAaQBQAGwARgAxAFoA
>> "%~1" echo WABOADAAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBHAGwAdQBkAEMASQBnAGEAVwBRADkASQBuAE4AMABZAFgAUgBsAFMA
>> "%~1" echo RwBsAHUAZABDAEkAKwA1ADYAMgBKADUAYgA2AEYANgBLACsANwA1AFkAKwBXADYA
>> "%~1" echo SwA2ACsANQBhAFMASAA1ADQAcQAyADUAbwBDAEIANAA0AEMAQwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjADMAUgBoAGQA
>> "%~1" echo RwBVAGkASQBHAGwAawBQAFMASgB6AGQARwBGADAAWgBVAEoAcABaAHkASQArAGIA
>> "%~1" echo bQA5AHUAWgBUAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABnADAASwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
>> "%~1" echo bQBsAG4ASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIA
>> "%~1" echo MgA1ADAAYwBtADkAcwBiAEcAVgB5AFEAbQA5ADQASQBHAHgAbABaAG4AUQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAeQBiADIAeABsAEkA
>> "%~1" echo agA3AGwAdAA2AGIAbQBpAFkAdgBtAG4ANABRADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo RwBJAGcAYQBXAFEAOQBJAG0AeABsAFoAbgBSAEQAYgAyADUAMABjAG0AOQBzAGIA
>> "%~1" echo RwBWAHkAVABHAGwAMABaAFMASQArAEwAUwAwADgATAAyAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBOADAAWQBYAFIAbABWAEcAVgA0AGQA
>> "%~1" echo QwBJAGcAYQBXAFEAOQBJAG0AeABsAFoAbgBSAEQAYgAyADUAMABjAG0AOQBzAGIA
>> "%~1" echo RwBWAHkAVQAzAFIAaABkAEcAVQBpAFAAaQAwADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo VwBWADAAWQBVAGwAMABaAFcAMABpAFAAagB4AHoAYwBHAEYAdQBQAGwAZABwAEwA
>> "%~1" echo VQBaAHAASQBFAGwAUQBQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKADMAYQBXAFoAcABTAFgAQgBNAGEAWABSAGwASQBqADQAdABQAEMAOQBpAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAEMAYgAzAGcAZwBjAG0AbABuAGEA
>> "%~1" echo SABRAGkAUABqAHgAegBjAEcARgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgB5AGIA
>> "%~1" echo MgB4AGwASQBqADcAbABqADcAUABtAGkAWQB2AG0AbgA0AFEAOABMADMATgB3AFkA
>> "%~1" echo VwA0ACsAUABHAEkAZwBhAFcAUQA5AEkAbgBKAHAAWgAyAGgAMABRADIAOQB1AGQA
>> "%~1" echo SABKAHYAYgBHAHgAbABjAGsAeABwAGQARwBVAGkAUABpADAAdABQAEMAOQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAegBkAEcARgAwAFoA
>> "%~1" echo VgBSAGwAZQBIAFEAaQBJAEcAbABrAFAAUwBKAHkAYQBXAGQAbwBkAEUATgB2AGIA
>> "%~1" echo bgBSAHkAYgAyAHgAcwBaAFgASgBUAGQARwBGADAAWgBTAEkAKwBMAFQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABnADAASwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAFkAMgBGAHkAWgBDAEkAKwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGEARwBWAGgAWgBDAEkAKwBQAEcAZwB5AFAA
>> "%~1" echo dQBlAEsAdAB1AGEAQQBnAGUAYQBNAGgAKwBhAGcAaAB6AHcAdgBhAEQASQArAFAA
>> "%~1" echo SABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABaAHkASQBnAGEA
>> "%~1" echo VwBRADkASQBtAE4AcwBiADIATgByAFYARwBWADQAZABDAEkAKwBMAFQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0AE4AQwBqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQASABKAHAAWQAwAGQAeQBhAFcAUQBpAFAA
>> "%~1" echo ZwAwAEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMA
>> "%~1" echo bQBsAGoASQBpAEIAcABaAEQAMABpAFkAbQBGADAAZABHAFYAeQBlAFUAZABoAGQA
>> "%~1" echo VwBkAGwASQBqADQAOABjADMAWgBuAEkARwBOAHMAWQBYAE4AegBQAFMASgB5AGEA
>> "%~1" echo VwA1AG4ASQBpAEIAMgBhAFcAVgAzAFEAbQA5ADQAUABTAEkAdwBJAEQAQQBnAE0A
>> "%~1" echo VABBAHcASQBEAEUAdwBNAEMASQArAFAARwBOAHAAYwBtAE4AcwBaAFMAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBkAEgASgBoAFkAMgBzAGkASQBHAE4ANABQAFMASQAxAE0A
>> "%~1" echo QwBJAGcAWQAzAGsAOQBJAGoAVQB3AEkAaQBCAHkAUABTAEkAMABNAEMASQBnAGMA
>> "%~1" echo RwBGADAAYQBFAHgAbABiAG0AZAAwAGEARAAwAGkATQBUAEEAdwBJAGkAOAArAFAA
>> "%~1" echo RwBOAHAAYwBtAE4AcwBaAFMAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAFoA
>> "%~1" echo WABJAGkASQBHAE4ANABQAFMASQAxAE0AQwBJAGcAWQAzAGsAOQBJAGoAVQB3AEkA
>> "%~1" echo aQBCAHkAUABTAEkAMABNAEMASQBnAGMARwBGADAAYQBFAHgAbABiAG0AZAAwAGEA
>> "%~1" echo RAAwAGkATQBUAEEAdwBJAGkAQgB6AGQASABKAHYAYQAyAFUAdABaAEcARgB6AGEA
>> "%~1" echo RwBGAHkAYwBtAEYANQBQAFMASQB3AEkARABFAHcATQBDAEkAdgBQAGoAdwB2AGMA
>> "%~1" echo MwBaAG4AUABqAHgAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYgBXAFYAMABjAG0AbABqAFYAbQBGAHMAZABXAFUAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAGkAWQBYAFIAMABaAFgASgA1AFYARwBWADQAZABDAEkAKwBMAFMAMABsAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo VwBWADAAYwBtAGwAagBUAEcARgBpAFoAVwB3AGkASQBHAGwAawBQAFMASgBpAFkA
>> "%~1" echo WABSADAAWgBYAEoANQBVADMAVgBpAEkAagA3AG4AbABMAFgAcABoADQAOAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADEAbABkAEgASgBwAFkA
>> "%~1" echo eQBJAGcAYQBXAFEAOQBJAG4AUgBsAGIAWABCAEgAWQBYAFYAbgBaAFMASQArAFAA
>> "%~1" echo SABOADIAWgB5AEIAagBiAEcARgB6AGMAegAwAGkAYwBtAGwAdQBaAHkASQBnAGQA
>> "%~1" echo bQBsAGwAZAAwAEoAdgBlAEQAMABpAE0AQwBBAHcASQBEAEUAdwBNAEMAQQB4AE0A
>> "%~1" echo RABBAGkAUABqAHgAagBhAFgASgBqAGIARwBVAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bgBSAHkAWQBXAE4AcgBJAGkAQgBqAGUARAAwAGkATgBUAEEAaQBJAEcATgA1AFAA
>> "%~1" echo UwBJADEATQBDAEkAZwBjAGoAMABpAE4ARABBAGkASQBIAEIAaABkAEcAaABNAFoA
>> "%~1" echo VwA1AG4AZABHAGcAOQBJAGoARQB3AE0AQwBJAHYAUABqAHgAagBhAFgASgBqAGIA
>> "%~1" echo RwBVAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABHAFYAeQBJAGkAQgBqAGUA
>> "%~1" echo RAAwAGkATgBUAEEAaQBJAEcATgA1AFAAUwBJADEATQBDAEkAZwBjAGoAMABpAE4A
>> "%~1" echo RABBAGkASQBIAEIAaABkAEcAaABNAFoAVwA1AG4AZABHAGcAOQBJAGoARQB3AE0A
>> "%~1" echo QwBJAGcAYwAzAFIAeQBiADIAdABsAEwAVwBSAGgAYwAyAGgAaABjAG4ASgBoAGUA
>> "%~1" echo VAAwAGkATQBDAEEAeABNAEQAQQBpAEwAegA0ADgATAAzAE4AMgBaAHoANAA4AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQA
>> "%~1" echo SABKAHAAWQAxAFoAaABiAEgAVgBsAEkAaQBCAHAAWgBEADAAaQBkAEcAVgB0AGMA
>> "%~1" echo RgBSAGwAZQBIAFEAaQBQAGkAMAB0AHcAcgBCAEQAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYAMABjAG0AbABqAFQA
>> "%~1" echo RwBGAGkAWgBXAHcAaQBJAEcAbABrAFAAUwBKADAAWgBXADEAdwBVADMAVgBpAEkA
>> "%~1" echo agA3AG0AdQBLAG4AbAB1AHEAWQA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANABOAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADEAbABkAEgASgBwAFkAeQBJAGcAYQBXAFEAOQBJAG4ATgBzAFoA
>> "%~1" echo VwBWAHcAUgAyAEYAMQBaADIAVQBpAFAAagB4AHoAZABtAGMAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBuAEoAcABiAG0AYwBpAEkASABaAHAAWgBYAGQAQwBiADMAZwA5AEkA
>> "%~1" echo agBBAGcATQBDAEEAeABNAEQAQQBnAE0AVABBAHcASQBqADQAOABZADIAbAB5AFkA
>> "%~1" echo MgB4AGwASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAYwBtAEYAagBhAHkASQBnAFkA
>> "%~1" echo MwBnADkASQBqAFUAdwBJAGkAQgBqAGUAVAAwAGkATgBUAEEAaQBJAEgASQA5AEkA
>> "%~1" echo agBRAHcASQBpAEIAdwBZAFgAUgBvAFQARwBWAHUAWgAzAFIAbwBQAFMASQB4AE0A
>> "%~1" echo RABBAGkATAB6ADQAOABZADIAbAB5AFkAMgB4AGwASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHQAWgBYAFIAbABjAGkASQBnAFkAMwBnADkASQBqAFUAdwBJAGkAQgBqAGUA
>> "%~1" echo VAAwAGkATgBUAEEAaQBJAEgASQA5AEkAagBRAHcASQBpAEIAdwBZAFgAUgBvAFQA
>> "%~1" echo RwBWAHUAWgAzAFIAbwBQAFMASQB4AE0ARABBAGkASQBIAE4AMABjAG0AOQByAFoA
>> "%~1" echo UwAxAGsAWQBYAE4AbwBZAFgASgB5AFkAWABrADkASQBqAEEAZwBNAFQAQQB3AEkA
>> "%~1" echo aQA4ACsAUABDADkAegBkAG0AYwArAFAARwBSAHAAZABqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgB0AFoAWABSAHkAYQBXAE4AVwBZAFcAeAAxAFoA
>> "%~1" echo UwBJAGcAYQBXAFEAOQBJAG4ATgBzAFoAVwBWAHcAVgBHAFYANABkAEMASQArAEwA
>> "%~1" echo VAB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQAxAGwAZABIAEoAcABZADAAeABoAFkAbQBWAHMASQBpAEIAcABaAEQAMABpAGMA
>> "%~1" echo MgB4AGwAWgBYAEIAVABkAFcASQBpAFAAdQBXAFUAcABPAG0ARwBrAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGcAMABLAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0AE4AQwBqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUAUwA0AGcA
>> "%~1" echo TwBtAFUAcgB1AFcAdgB2AE8AVwBIAHUAagB3AHYAYQBEAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5AEkAKwA1AFkAKwBxADYA
>> "%~1" echo SwArADcANgBZAGUASAA2AFoAdQBHAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoA
>> "%~1" echo SABrAGkAUABnADAASwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFoA
>> "%~1" echo WABoAHcAYgAzAEoAMABRAG0AOQA0AEkAagA0ADgAWgBHAGwAMgBQAGoAeABpAFAA
>> "%~1" echo dQBXAHYAdgBPAFcASAB1AHUAaQB1AHYAdQBXAGsAaAArAFcARgBxAE8AbQBEAHEA
>> "%~1" echo TwBTAC8AbwBlAGEAQgByAHoAdwB2AFkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAbwBhAFcANQAwAEkAaQBCAHAAWgBEADAAaQBaAFgAaAB3AGIA
>> "%~1" echo MwBKADAAVQAzAFIAaABkAEgAVgB6AEkAagA3AG4AbABKAC8AbQBpAEoARABuAHAA
>> "%~1" echo NABIAG0AbgBJAG4AbAByAG8AegBtAGwAYgBUAG4AaQBZAGoAawB1AEkANwBsAGkA
>> "%~1" echo SQBiAGsAdQBxAHYAbAByAG8AbgBsAGgAYQBqAG4AaQBZAGoAawB1AEsAVABrAHUA
>> "%~1" echo NwAwAGcAUwBGAFIATgBUAE8ATwBBAGcAdQBXAEkAaAB1AFMANgBxACsAVwBKAGoA
>> "%~1" echo ZQBpAHYAdAArAFMANgB1AHUAVwAzAHAAZQBXAGsAagBlAGEAZwB1AE8ATwBBAGcA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBWADQAYwBHADkAeQBkAEUAeABwAGIAbQB0AHoASQBpAEIAcABaAEQAMABpAFoA
>> "%~1" echo WABoAHcAYgAzAEoAMABUAEcAbAB1AGEAMwBNAGkAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEoAMABiAGkAQgB3AGMAbQBsAHQAWQBYAEoANQBJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAWgBYAGgAdwBiADMASgAwAFEAbgBSAHUASQBqADcAbAB2AEkARABsAHAA
>> "%~1" echo NAB2AGwAcgA3AHoAbABoADcAbwA4AEwAMgBKADEAZABIAFIAdgBiAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo ZwAwAEsAUABDADkAegBaAFcATgAwAGEAVwA5AHUAUABnADAASwBEAFEAbwA4AGMA
>> "%~1" echo MgBWAGoAZABHAGwAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAEcARgBuAFoA
>> "%~1" echo UwBJAGcAYQBXAFEAOQBJAG0ATgB2AGIAbgBOAHYAYgBHAFUAaQBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAA
>> "%~1" echo RwBnAHkAUAB1AFcANAB1AE8AZQBVAHEATwBhAFQAagBlAFMAOQBuAEQAdwB2AGEA
>> "%~1" echo RABJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoA
>> "%~1" echo eQBJACsANQA0AEsANQA1AFkAZQA3ADUAbwBtAG4ANgBLAEcATQBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEoAdgBaAEgAawBpAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIAMQBrAFIAMwBKAHAAWgBDAEkAKwBEAFEAbwA4AFkA
>> "%~1" echo bgBWADAAZABHADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBiAFcAUQBnAFoA
>> "%~1" echo MwBKAGwAWgBXADQAaQBJAEcAUgBoAGQARwBFAHQAWQBXAE4AMABhAFcAOQB1AFAA
>> "%~1" echo UwBKAHIAWgBYAGwAZgBkADIARgByAFoAWABWAHcASQBqADQAOABZAGoANwBsAGwA
>> "%~1" echo SwBUAHAAaABwAEwAbABzAFkALwBsAHUAWgBVADgATAAyAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0ACsAUwAwAFYAWgBRADAAOQBFAFIAVgA5AFgAUQBVAHQARgBWAFYAQQA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBEAFEAbwA4AFkA
>> "%~1" echo bgBWADAAZABHADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBiAFcAUQBnAFkA
>> "%~1" echo bQB4ADEAWgBTAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkA
>> "%~1" echo bgBOAGgAWgBtAFYAZgBjADIAeABsAFoAWABBAGkAUABqAHgAaQBQAHUAVwB1AGkA
>> "%~1" echo ZQBXAEYAcQBPAGUARwBoAE8AVwB4AGoAegB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA3AG0AZwBhAEwAbABwAEkAMwBrAHYANQAzAGwAcgBvAGoAbABnAEwAegBsAHUA
>> "%~1" echo YgBZAGcAVQAwAHgARgBSAFYAQQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBEAFEAbwA4AFkAbgBWADAAZABHADkAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAagBiAFcAUQBnAFkAbQB4ADEAWgBTAEkAZwBaAEcARgAwAFkA
>> "%~1" echo UwAxAGgAWQAzAFIAcABiADIANAA5AEkAbgBKAGwAYwAzAFIAdgBjAG0AVgBmAGMA
>> "%~1" echo MgB4AGwAWgBYAEEAaQBQAGoAeABpAFAAdQBhAEIAbwB1AFcAawBqAGUAUwA4AGsA
>> "%~1" echo ZQBlAGMAbwBEAHcAdgBZAGoANAA4AGMAMwBCAGgAYgBqADcAbQByAGEAUABsAHUA
>> "%~1" echo TABqAGsAdgBKAEgAbgBuAEsAQQBnAEsAeQBBADEASQBPAFcASQBoAHUAbQBTAG4A
>> "%~1" echo KwBpADIAaABlAGEAWAB0AGoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQA
>> "%~1" echo SABSAHYAYgBqADQATgBDAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAE4AdABaAEMAQgBpAGIASABWAGwASQBpAEIAawBZAFgAUgBoAEwA
>> "%~1" echo VwBGAGoAZABHAGwAdgBiAGoAMABpAFkAMgA5AHUAYwAyAFYAeQBkAG0ARgAwAGEA
>> "%~1" echo WABaAGwASQBqADQAOABZAGoANwBrAHYANQAzAGwAcgBvAGoAcAB1ADUAagBvAHIA
>> "%~1" echo cQBUAGwAZwBMAHcAOABMADIASQArAFAASABOAHcAWQBXADQAKwA1AG8ARwBpADUA
>> "%~1" echo YQBTAE4ANQBhADYASgA1AFkAVwBvADYAYgB1AFkANgBLADYAawA1AFkAKwBDADUA
>> "%~1" echo cABXAHcAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAA
>> "%~1" echo ZwAwAEsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgAxAGsASQBHAEYAdABZAG0AVgB5AEkARwBSAGgAYgBtAGQAbABjAGsARgBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkA
>> "%~1" echo bQBSAGwAWQBuAFYAbgBYADIAMQB2AFoARwBVAGkAUABqAHgAaQBQAHUAaQB3AGcA
>> "%~1" echo KwBpAHYAbABlAFcAMwBwAGUAUwA5AG4ATwBhAG8AbwBlAFcAOABqAHoAdwB2AFkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANwBrAHYANQAzAG0AdABMAHMAZwBLAHkAQQB5AE4A
>> "%~1" echo RwBnAGcANQBMAHEAdQA1AGIARwBQADcANwB5AEkANQA1ACsAdAA1AHAAZQAyADcA
>> "%~1" echo NwB5AEoAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAA
>> "%~1" echo ZwAwAEsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgAxAGsASQBHAEYAdABZAG0AVgB5AEkARwBSAGgAYgBtAGQAbABjAGsARgBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkA
>> "%~1" echo bQB0AGwAWgBYAEIAZgBZAFgAZABoAGEAMgBVAGkAUABqAHgAaQBQAHUAZQBmAHIA
>> "%~1" echo ZQBhAFgAdAB1AFMALwBuAGUAYQAwAHUAegB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA3AGwAaABwAG4AbABoAGEAWABrAHYANQAzAG0AagBJAEgAbABsAEsAVABwAGgA
>> "%~1" echo cABMAGwAagA0AEwAbQBsAGIAQQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBEAFEAbwA4AFkAbgBWADAAZABHADkAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAagBiAFcAUQBnAFkAVwAxAGkAWgBYAEkAZwBaAEcARgB1AFoA
>> "%~1" echo MgBWAHkAUQBXAE4AMABhAFcAOQB1AEkAaQBCAGsAWQBYAFIAaABMAFcARgBqAGQA
>> "%~1" echo RwBsAHYAYgBqADAAaQBkADIAbAB5AFoAVwB4AGwAYwAzAE0AaQBQAGoAeABpAFAA
>> "%~1" echo dQBXADgAZwBPAFcAUQByACsAYQBYAG8ATwBlADYAdgB5AEIAQgBSAEUASQA4AEwA
>> "%~1" echo MgBJACsAUABIAE4AdwBZAFcANAArAGQARwBOAHcAYQBYAEEAZwBOAFQAVQAxAE4A
>> "%~1" echo VAB3AHYAYwAzAEIAaABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANABOAEMA
>> "%~1" echo agB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoA
>> "%~1" echo QwBCAGgAYgBXAEoAbABjAGkAQgBrAFkAVwA1AG4AWgBYAEoAQgBZADMAUgBwAGIA
>> "%~1" echo MgA0AGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBXADkAdQBQAFMASgAzAGEA
>> "%~1" echo WABKAGwAYgBHAFYAegBjADEAOQB2AFoAbQBZAGkAUABqAHgAaQBQAHUAVwBGAHMA
>> "%~1" echo KwBtAFgAcgBlAGEAWABvAE8AZQA2AHYAeQBCAEIAUgBFAEkAOABMADIASQArAFAA
>> "%~1" echo SABOAHcAWQBXADQAKwA1AFkAaQBIADUAWgB1AGUASQBGAFYAVABRAGoAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBqADQATgBDAGoAeABpAGQA
>> "%~1" echo WABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBpAGIA
>> "%~1" echo SABWAGwASQBpAEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGEA
>> "%~1" echo MgBWADUAWAAzAE4AcwBaAFcAVgB3AEkAagA0ADgAWQBqADcAbABqADUASABwAGcA
>> "%~1" echo SQBFAGcAVQAwAHgARgBSAFYAQQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAFMA
>> "%~1" echo MABWAFoAUQAwADkARQBSAFYAOQBUAFQARQBWAEYAVQBEAHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgATAAyAEoAMQBkAEgAUgB2AGIAagA0AE4AQwBqAHgAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBOAHQAWgBDAEIAaQBiAEgAVgBsAEkA
>> "%~1" echo aQBCAGsAWQBYAFIAaABMAFcARgBqAGQARwBsAHYAYgBqADAAaQBjAEgASgB2AGUA
>> "%~1" echo RgA5AHYAYwBHAFYAdQBJAGoANAA4AFkAagA1AHcAYwBtADkANABYADIAOQB3AFoA
>> "%~1" echo VwA0ADgATAAyAEkAKwBQAEgATgB3AFkAVwA0ACsANgBLAGUAagA2AFoAbQBrADUA
>> "%~1" echo cQBpAGgANQBvAHUAZgA1AEwAMgBwADUAbwBpADAAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWQBuAFYAMABkAEcAOQB1AFAAZwAwAEsAUABHAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAFkAMgAxAGsASQBHAEYAdABZAG0AVgB5AEkA
>> "%~1" echo RwBSAGgAYgBtAGQAbABjAGsARgBqAGQARwBsAHYAYgBpAEkAZwBaAEcARgAwAFkA
>> "%~1" echo UwAxAGgAWQAzAFIAcABiADIANAA5AEkAbgBCAHkAYgAzAGgAZgBZADIAeAB2AGMA
>> "%~1" echo MgBVAGkAUABqAHgAaQBQAG4AQgB5AGIAMwBoAGYAWQAyAHgAdgBjADIAVQA4AEwA
>> "%~1" echo MgBJACsAUABIAE4AdwBZAFcANAArADUAcQBpAGgANQBvAHUAZgA1AEwAMgBwADUA
>> "%~1" echo bwBpADAANgBaADIAZwA2AEwAKwBSAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkA
>> "%~1" echo bgBWADAAZABHADkAdQBQAGcAMABLAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIAMQBrAEkARwBKAHMAZABXAFUAaQBJAEcAUgBoAGQA
>> "%~1" echo RwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAHoAWQAzAEoAbABaAFcANQBmAE4A
>> "%~1" echo VwAwAGkAUABqAHgAaQBQAHUAVwB4AGoAKwBXADUAbABlAGkAMgBoAGUAYQBYAHQA
>> "%~1" echo aQBBADEASQBPAFcASQBoAHUAbQBTAG4AegB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA1AHoAWQAzAEoAbABaAFcANQBmAGIAMgBaAG0AWAAzAFIAcABiAFcAVgB2AGQA
>> "%~1" echo WABRADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIANAArAEQA
>> "%~1" echo UQBvADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIA
>> "%~1" echo VwBRAGcAWQBXADEAaQBaAFgASQBnAFoARwBGAHUAWgAyAFYAeQBRAFcATgAwAGEA
>> "%~1" echo VwA5AHUASQBpAEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGMA
>> "%~1" echo MgBOAHkAWgBXAFYAdQBYAHoASQAwAGEAQwBJACsAUABHAEkAKwA1AGIARwBQADUA
>> "%~1" echo YgBtAFYANgBMAGEARgA1AHAAZQAyAEkARABJADAASQBPAFcAdwBqACsAYQBYAHQA
>> "%~1" echo agB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AHAAbABiAC8AbQBsADcAYgBwAGwA
>> "%~1" echo NwBUAGsAdQBJADMAbgBoAG8AVABsAHMAWQA4ADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAEQAUQBvADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGcAWQBtAHgAMQBaAFMASQBnAFoA
>> "%~1" echo RwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBuAE4AMABZAFgAbABmAGIA
>> "%~1" echo MgBaAG0ASQBqADQAOABZAGoANwBsAGoANQBiAG0AdABvAGoAbQBqADUATABuAGwA
>> "%~1" echo TABYAGsAdgA1ADMAbQBqAEkARQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAGMA
>> "%~1" echo MwBSAGgAZQBWADkAdgBiAGkAQQA5AEkARABBADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAEQAUQBvADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGcAWQBXADEAaQBaAFgASQBnAFoA
>> "%~1" echo RwBGAHUAWgAyAFYAeQBRAFcATgAwAGEAVwA5AHUASQBpAEIAawBZAFgAUgBoAEwA
>> "%~1" echo VwBGAGoAZABHAGwAdgBiAGoAMABpAGMAMwBSAGgAZQBWADkAMQBjADIASgBmAFkA
>> "%~1" echo VwBNAGkAUABqAHgAaQBQAGwAVgBUAFEAaQA5AEIAUQB5AEQAawB2ADUAMwBtAGoA
>> "%~1" echo SQBIAGwAbABLAFQAcABoAHAASQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAGMA
>> "%~1" echo MwBSAGgAZQBWADkAdgBiAGkAQQA5AEkARABNADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAEQAUQBvADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGcAWQBtAHgAMQBaAFMASQBnAFoA
>> "%~1" echo RwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBuAEoAbABjADMAUgBoAGMA
>> "%~1" echo bgBSAGYAWQBXAFIAaQBJAGoANAA4AFkAagA3AHAAaAA0ADMAbABrAEsAOABnAFEA
>> "%~1" echo VQBSAEMASQBPAGEAYwBqAGUAVwBLAG8AVAB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA1AHIAYQBXAHgAcwBJAEMAcwBnAGMAMwBSAGgAYwBuAFEAZwBjADIAVgB5AGQA
>> "%~1" echo bQBWAHkAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAA
>> "%~1" echo ZwAwAEsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgAxAGsASQBHAEYAdABZAG0AVgB5AEkARwBSAGgAYgBtAGQAbABjAGsARgBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkA
>> "%~1" echo bgBKAGwAYwAzAFIAdgBjAG0AVgBmAFkAbQBGAGoAYQAzAFYAdwBJAGoANAA4AFkA
>> "%~1" echo agA3AGsAdQA0ADcAbABwAEkAZgBrAHUANwAzAG0AZwBhAEwAbABwAEkAMAA4AEwA
>> "%~1" echo MgBJACsAUABIAE4AdwBZAFcANAArADYATAArAFkANQBZADYAZgA2AGEAYQBXADUA
>> "%~1" echo cQB5AGgANQBZAGEAWgA1AFkAVwBsADUAWQBtAE4ANQA1AHEARQA1AFkAQwA4AFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGcAMABLAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBsAHIAcAA3AG0AbAA3AGIAbQBwAG8ATABvAHAA
>> "%~1" echo NABnADgATAAyAGcAeQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgAMABZAFcASgBzAFoA
>> "%~1" echo UwBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAGkAYgBHAFUAaQBQAGcAMABLAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANwBvAHYANQA3AG0AagBxAFUAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFkAMgA5AHUAYwAyADkAcwBaAFUATgB2AGIA
>> "%~1" echo bQA0AGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAbgBsAEwAWABwAGgANAA4ADgATAAzAFIAawBQAGoAeAAwAFoA
>> "%~1" echo QwBCAHAAWgBEADAAaQBZADIAOQB1AGMAMgA5AHMAWgBVAEoAaABkAEgAUgBsAGMA
>> "%~1" echo bgBrAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAawB2AEoASABuAG4ASwBBADgATAAzAFIAawBQAGoAeAAwAFoA
>> "%~1" echo QwBCAHAAWgBEADAAaQBZADIAOQB1AGMAMgA5AHMAWgBWAGQAaABhADIAVQBpAFAA
>> "%~1" echo aQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIAeQBQAGoAeAAwAFoA
>> "%~1" echo RAA1AFgAYQBTADEARwBhAFQAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAA
>> "%~1" echo UwBKAGoAYgAyADUAegBiADIAeABsAFYAMgBsAG0AYQBTAEkAKwBMAFQAdwB2AGQA
>> "%~1" echo RwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABIAFIAawBQAHUAaQB1AHYA
>> "%~1" echo dQBXAGsAaAArAGUASwB0AHUAYQBBAGcAVAB3AHYAZABHAFEAKwBQAEgAUgBrAEkA
>> "%~1" echo RwBsAGsAUABTAEoAagBiADIANQB6AGIAMgB4AGwAVQAzAFIAaABkAEcAVQBpAFAA
>> "%~1" echo aQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIAeQBQAGoAeAAwAFoA
>> "%~1" echo RAA3AG4AbABMAFgAbQB1AHAAQQA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAYwBHADkAMwBaAFgASgBUAGIAMwBWAHkAWQAyAFUAeQBJAGoANAB0AFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABMADMAUgB5AFAAZwAwAEsAUABDADkAMABZAFcASgBzAFoA
>> "%~1" echo VAA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQATgBDAGoAdwB2AGMA
>> "%~1" echo MgBWAGoAZABHAGwAdgBiAGoANABOAEMAZwAwAEsAUABIAE4AbABZADMAUgBwAGIA
>> "%~1" echo MgA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBCAGgAWgAyAFUAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAGgAYwBIAEIAegBJAGoANABOAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBuAFIAaABZAG4ATQBpAEkARwBsAGsAUABTAEoAaABjAEgAQgBVAFkA
>> "%~1" echo VwBKAHoASQBqADQAOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHYAYgBpAEkAZwBaAEcARgAwAFkAUwAxADAAWQBXAEkAOQBJAG0AbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgAbABaAEMASQBnAGEAVwBRADkASQBuAFIAaABZAGsAbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgAbABaAEMASQArADUAYgBlAHkANQBhADYASgA2AEsATwBGAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAFAARwBKADEAZABIAFIAdgBiAGkAQgBrAFkA
>> "%~1" echo WABSAGgATABYAFIAaABZAGoAMABpAGMAMgBsAGsAWgBXAHgAdgBZAFcAUQBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAMABZAFcASgBUAGEAVwBSAGwAYgBHADkAaABaAEMASQArADUA
>> "%~1" echo YQA2AEoANgBLAE8ARgBJAEUARgBRAFMAegB3AHYAWQBuAFYAMABkAEcAOQB1AFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAARwBSAHAAZABpAEIAcABaAEQAMABpAFkA
>> "%~1" echo WABCAHcAYwAwAGwAdQBjADMAUgBoAGIARwB4AGwAWgBDAEkAKwBEAFEAbwA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGgAYwBIAEIATQBhAFcASQBpAFAA
>> "%~1" echo ZwAwAEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAFgAQgB3AFQA
>> "%~1" echo RwBsAHoAZABDAEkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGgAYwBIAEIAVABaAFcARgB5AFkAMgBnAGkAUABqAHgAcABiAG4AQgAxAGQA
>> "%~1" echo QwBCAHAAWgBEADAAaQBZAFgAQgB3AFIAbQBsAHMAZABHAFYAeQBJAGkAQgB3AGIA
>> "%~1" echo RwBGAGoAWgBXAGgAdgBiAEcAUgBsAGMAagAwAGkANQBwAEMAYwA1ADcAUwBpADUA
>> "%~1" echo WQB5AEYANQBaAEMATgBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHcAYQBXAHgAcwBVAG0AOQAzAEkAaQBCAHoAZABIAGwAcwBaAFQAMABpAGIA
>> "%~1" echo VwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMARABvADQAYwBIAGcAaQBQAGoAeAB6AGMA
>> "%~1" echo RwBGAHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAYQBXAHgAcwBJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAYwAyAE4AdgBjAEcAVgBWAGMAMgBWAHkASQBpAEIAegBkAEgAbABzAFoA
>> "%~1" echo VAAwAGkAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBXADUAMABaAFgASQBpAFAA
>> "%~1" echo dQBlAHMAcgBPAFMANABpAGUAYQBXAHUAVAB3AHYAYwAzAEIAaABiAGoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAYwBHAGwAcwBiAEMASQBnAGEA
>> "%~1" echo VwBRADkASQBuAE4AagBiADMAQgBsAFEAVwB4AHMASQBpAEIAegBkAEgAbABzAFoA
>> "%~1" echo VAAwAGkAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBXADUAMABaAFgASQBpAFAA
>> "%~1" echo dQBXAEYAcQBPAG0ARABxAEQAdwB2AGMAMwBCAGgAYgBqADQAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGMARwBsAHMAYgBDAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bgBOAGoAYgAzAEIAbABVADMAbAB6AGQARwBWAHQASQBpAEIAegBkAEgAbABzAFoA
>> "%~1" echo VAAwAGkAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBXADUAMABaAFgASQBpAFAA
>> "%~1" echo dQBlAHoAdQArAGUANwBuAHoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANABOAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEYAdwBjAEYASgB2AGQAMwBNAGkASQBHAGwAawBQAFMASgBoAGMA
>> "%~1" echo SABCAFMAYgAzAGQAegBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGgAYwBIAEIARgBiAFgAQgAwAGUAUwBJAGcAYQBXAFEAOQBJAG0ARgB3AGMA
>> "%~1" echo RQB4AHAAYwAzAFIARgBiAFgAQgAwAGUAUwBJACsANgBMACsAZQA1AG8ANgBsAEkA
>> "%~1" echo RgBGADEAWgBYAE4AMABJAE8AVwBRAGoAdQBXAGMAcQBPAGkALwBtAGUAbQBIAGoA
>> "%~1" echo TwBXAEkAbAArAFcASAB1AHUAVwA2AGwATwBlAFUAcQBPAE8AQQBnAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABDADkAawBhAFgAWQArAEQA
>> "%~1" echo UQBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaABjAEgAQgBFAFoA
>> "%~1" echo WABSAGgAYQBXAHcAaQBJAEcAbABrAFAAUwBKAGgAYwBIAEIARQBaAFgAUgBoAGEA
>> "%~1" echo VwB4AFEAWQBXADUAbABJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGgAYwBIAEIARgBiAFgAQgAwAGUAUwBJAGcAYQBXAFEAOQBJAG0ARgB3AGMA
>> "%~1" echo RQBSAGwAZABHAEYAcABiAEUAVgB0AGMASABSADUASQBqADcAcABnAEkAbgBtAGkA
>> "%~1" echo NgBuAGwAdAA2AGIAawB2AHEAZgBsAHUAcABUAG4AbABLAGoAbQBuADYAWABuAG4A
>> "%~1" echo SQB2AG8AcgA2AGIAbQBnADQAWABqAGcASQBIAG0AbgBZAFAAcABtAFoARABqAGcA
>> "%~1" echo SQBIAG0AagA1AEQAbABqADUAWQBnAFEAVgBCAEwASQBPAGEASQBsAHUAVwBOAHUA
>> "%~1" echo TwBpADkAdgBlAE8AQQBnAGoAdwB2AFoARwBsADIAUABnADAASwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAHAAWgBEADAAaQBZAFgAQgB3AFIARwBWADAAWQBXAGwAcwBRAG0AOQBrAGUA
>> "%~1" echo UwBJAGcAYwAzAFIANQBiAEcAVQA5AEkAbQBSAHAAYwAzAEIAcwBZAFgAawA2AGIA
>> "%~1" echo bQA5AHUAWgBUAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUANABjAEgAZwBpAFAA
>> "%~1" echo ZwAwAEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAFgAQgB3AFMA
>> "%~1" echo RwBWAHkAYgB5AEkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGgAYwBIAEIASgBZADIAOQB1AFYARwBsAHMAWgBTAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBSAGwAZABFAGQAcwBlAFgAQgBvAEkAagA1AEIAUABDADkAawBhAFgAWQArAEQA
>> "%~1" echo UQBvADgAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBGAHcAYwBFADUAaABiAFcAVQBpAEkARwBsAGsAUABTAEoAawBaAFgAUgBVAGEA
>> "%~1" echo WABSAHMAWgBTAEkAKwBMAFQAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4AQgBwAGIARwB4AFMAYgAzAGMAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAGsAWgBYAFIAUQBhAFcAeABzAGMAeQBJACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwAMgBSAHAAZABqADQATgBDAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBGAGoAZABFAEoAaABjAGkASQArAEQA
>> "%~1" echo UQBvADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBpAGQA
>> "%~1" echo RwA0AGcAYwBIAEoAcABiAFcARgB5AGUAUwBJAGcAYQBXAFEAOQBJAG0AUgBsAGQA
>> "%~1" echo RQB4AGgAZABXADUAagBhAEMASQArADUAbwBtAFQANQBiAHkAQQBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBEAFEAbwA4AFkAbgBWADAAZABHADkAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAaQBkAEcANABpAEkARwBsAGsAUABTAEoAawBaAFgAUgBGAGUA
>> "%~1" echo SABSAHkAWQBXAE4AMABJAGoANwBtAGoANQBEAGwAagA1AFkAZwBRAFYAQgBMAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAEQAUQBvADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGQARwA0AGkASQBHAGwAawBQAFMASgBrAFoA
>> "%~1" echo WABSAFQAZABHADkAdwBJAGoANwBsAHYATAByAG8AbwBZAHoAbABnAFoAegBtAHIA
>> "%~1" echo YQBJADgATAAyAEoAMQBkAEgAUgB2AGIAagA0AE4AQwBqAHgAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBKADAAYgBpAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBSAGwAZABFAFYAdQBZAFcASgBzAFoAUwBJACsANQBaAEMAdgA1ADUAUwBvAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAEQAUQBvADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGQARwA0AGkASQBHAGwAawBQAFMASgBrAFoA
>> "%~1" echo WABSAEUAYQBYAE4AaABZAG0AeABsAEkAagA3AG4AcABvAEgAbgBsAEsAZwA4AEwA
>> "%~1" echo MgBKADEAZABIAFIAdgBiAGoANABOAEMAagB4AGkAZABYAFIAMABiADIANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ASgAwAGIAaQBJAGcAYQBXAFEAOQBJAG0AUgBsAGQA
>> "%~1" echo RQBOAHMAWgBXAEYAeQBJAGoANwBtAHUASQBYAHAAbQBhAFQAbQBsAGIARABtAGoA
>> "%~1" echo YQA0ADgATAAyAEoAMQBkAEgAUgB2AGIAagA0AE4AQwBqAHgAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBKADAAYgBpAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBSAGwAZABGAFYAdQBhAFcANQB6AGQARwBGAHMAYgBDAEkAZwBjADMAUgA1AGIA
>> "%~1" echo RwBVADkASQBtAEoAdgBjAG0AUgBsAGMAaQAxAGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAeQBaAFcAUQBwAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABYAEoAbABaAEMAawBpAFAAdQBXAE4AdQBPAGkAOQB2AFQAdwB2AFkA
>> "%~1" echo bgBWADAAZABHADkAdQBQAGcAMABLAFAAQwA5AGsAYQBYAFkAKwBEAFEAbwA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AYQBXADUAMABJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAWgBHAFYAMABSAFgAaAAwAGMAbQBGAGoAZABFAGgAcABiAG4AUQBpAEkA
>> "%~1" echo SABOADAAZQBXAHgAbABQAFMASgB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8A
>> "%~1" echo agBoAHcAZQBDAEkAKwBQAEMAOQBrAGEAWABZACsARABRAG8AOABkAEcARgBpAGIA
>> "%~1" echo RwBVAGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWQBtAHgAbABJAGkAQgB6AGQA
>> "%~1" echo SABsAHMAWgBUADAAaQBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwB4AE4A
>> "%~1" echo bgBCADQASQBqADQATgBDAGoAeAAwAGMAagA0ADgAZABHAFEAKwA1AFkAeQBGADUA
>> "%~1" echo WgBDAE4AUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG0AUgBsAGQA
>> "%~1" echo RgBCAGgAWQAyAHQAaABaADIAVQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQA
>> "%~1" echo SABJACsARABRAG8AOABkAEgASQArAFAASABSAGsAUAB1AGUASgBpAE8AYQBjAHIA
>> "%~1" echo RAB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoAawBaAFgAUgBXAFoA
>> "%~1" echo WABKAHoAYQBXADkAdQBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAA
>> "%~1" echo ZwAwAEsAUABIAFIAeQBQAGoAeAAwAFoARAA1AFQAUgBFAHMAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFoARwBWADAAVQAyAFIAcgBJAGoANAB0AFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABMADMAUgB5AFAAZwAwAEsAUABIAFIAeQBQAGoAeAAwAFoA
>> "%~1" echo RAA3AGwAcgBvAG4AbwBvADQAWABtAG4AYQBYAG0AdQBwAEEAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFoARwBWADAAUwBXADUAegBkAEcARgBzAGIA
>> "%~1" echo RwBWAHkASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGcAMABLAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANQBWAFMAVQBRAGcATAB5AEIAQgBRAGsAawA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAWgBHAFYAMABWAFcAbABrAFEA
>> "%~1" echo VwBKAHAASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGcAMABLAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANwBsAHAASwBmAGwAcwBJADgAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFoARwBWADAAVQAyAGwANgBaAFMASQArAEwA
>> "%~1" echo VAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0AE4AQwBqAHgAMABjAGoANAA4AGQA
>> "%~1" echo RwBRACsANgBhAGEAVwA1AHEAeQBoADUAYQA2AEoANgBLAE8ARgBQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQBSAGwAZABFAFoAcABjAG4ATgAwAEkA
>> "%~1" echo agA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABnADAASwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAbQBuAEkARABvAHYANQBIAG0AbQA3AFQAbQBsAHIAQQA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAWgBHAFYAMABWAFgAQgBrAFkA
>> "%~1" echo WABSAGwASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGcAMABLAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANQBCAFUARQBzAGcANgBMAGUAdgA1AGIANgBFAFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABkAEcAUQBnAGEAVwBRADkASQBtAFIAbABkAEYAQgBoAGQA
>> "%~1" echo RwBnAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBEAFEAbwA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAHUAYQBWAHMATwBhAE4AcgB1AGUAYgByAHUAVwA5AGwA
>> "%~1" echo VAB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoAawBaAFgAUgBFAFkA
>> "%~1" echo WABSAGgASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGcAMABLAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANwBuAGkAcgBiAG0AZwBJAEUAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFoARwBWADAAVQAzAFIAaABkAEcAVQBpAFAA
>> "%~1" echo aQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsARABRAG8AOABMADMAUgBoAFkA
>> "%~1" echo bQB4AGwAUABnADAASwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEA
>> "%~1" echo RwBWAGgAWgBDAEkAZwBjADMAUgA1AGIARwBVADkASQBuAEIAaABaAEcAUgBwAGIA
>> "%~1" echo bQBjADYATQBUAEoAdwBlAEMAQQB3AEkARABaAHcAZQBEAHQAbwBaAFcAbABuAGEA
>> "%~1" echo SABRADYAWQBYAFYAMABiAHoAdABpAGIAMwBKAGsAWgBYAEkANgBNAEMASQArAFAA
>> "%~1" echo RwBnAHkAUAB1AGkALwBrAE8AaQBoAGoATwBhAFgAdAB1AGEAZABnACsAbQBaAGsA
>> "%~1" echo RAB3AHYAYQBEAEkAKwBQAEMAOQBrAGEAWABZACsARABRAG8AOABaAEcAbAAyAEkA
>> "%~1" echo RwBsAGsAUABTAEoAawBaAFgAUgBTAGQAVwA1ADAAYQBXADEAbABJAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBoAGwAWQBXAFEAaQBJAEgATgAwAGUAVwB4AGwAUABTAEoAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEUAeQBjAEgAZwBnAE0AQwBBADIAYwBIAGcANwBhAEcAVgBwAFoA
>> "%~1" echo MgBoADAATwBtAEYAMQBkAEcAOAA3AFkAbQA5AHkAWgBHAFYAeQBPAGoAQQBpAFAA
>> "%~1" echo agB4AG8ATQBqADcAbABvADcARABtAG0ASQA3AG0AbgBZAFAAcABtAFoAQQA4AEwA
>> "%~1" echo MgBnAHkAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAEcAOQBuAEkAaQBCAHAAWgBEADAAaQBaAEcAVgAwAFUA
>> "%~1" echo bQBWAHgAZABXAFYAegBkAEcAVgBrAEkAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAAQwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAdwB2AFoARwBsADIAUABnADAASwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAHAAWgBEADAAaQBZAFgAQgB3AGMAMQBOAHAAWgBHAFYAcwBiADIARgBrAEkA
>> "%~1" echo aQBCAHoAZABIAGwAcwBaAFQAMABpAFoARwBsAHoAYwBHAHgAaABlAFQAcAB1AGIA
>> "%~1" echo MgA1AGwASQBqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBGAHcAYwBGAGQAeQBZAFgAQQBpAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZAFgAQgB3AFEAMgBGAHkAWgBDAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBGAHcAYwBFAE4AaABjAG0AUQBpAFAAZwAwAEsAUABDAEUAdABMAFMAQgBsAGIA
>> "%~1" echo WABCADAAZQBTAEEAdgBJAEcAUgB5AGIAMwBBAGcAYwAzAFIAaABkAEcAVQBnAEwA
>> "%~1" echo UwAwACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBrAGMA
>> "%~1" echo bQA5AHcAUgBXADEAdwBkAEgAawBpAEkARwBsAGsAUABTAEoAaABjAEcAdABFAGMA
>> "%~1" echo bQA5AHcASQBqADQAOABjADMAWgBuAFAAagB4ADEAYwAyAFUAZwBhAEgASgBsAFoA
>> "%~1" echo agAwAGkASQAyAGsAdABkAFgAQgBzAGIAMgBGAGsASQBpADgAKwBQAEMAOQB6AGQA
>> "%~1" echo bQBjACsAUABHAEkAKwA1AG8AdQBXADUAbwB1ADkASQBFAEYAUQBTAHkARABsAGkA
>> "%~1" echo TABEAG8AdgA1AG4AcABoADQAegB2AHYASQB6AG0AaQBKAGIAbgBnAHIAbgBsAGgA
>> "%~1" echo NwB2AHAAZwBJAG4AbQBpADYAawA4AEwAMgBJACsAUABIAE4AdwBZAFcANABnAGEA
>> "%~1" echo VwBRADkASQBtAFIAeQBiADMAQgBJAGEAVwA1ADAASQBqADcAbQBuAEsAegBsAG4A
>> "%~1" echo TABEAGsAdQBJAHIAawB2AEsARABsAGsASQA3AG4AbABMAEUAZwBRAFUAUgBDAEkA
>> "%~1" echo TwBXAHUAaQBlAGkAagBoAGUAVwBJAHMATwBXADMAcwB1AGkALwBuAHUAYQBPAHAA
>> "%~1" echo ZQBlAGEAaABDAEIAUgBkAFcAVgB6AGQATwBPAEEAZwB1AFcAdQBpAGUAaQBqAGgA
>> "%~1" echo ZQBXAEoAagBlAFMAOABtAHUAUwA2AGoATwBhAHMAbwBlAGUAaAByAHUAaQB1AHAA
>> "%~1" echo TwBPAEEAZwBqAHcAdgBjADMAQgBoAGIAagA0ADgAYQBXADUAdwBkAFgAUQBnAGQA
>> "%~1" echo SABsAHcAWgBUADAAaQBaAG0AbABzAFoAUwBJAGcAYQBXAFEAOQBJAG0ARgB3AGEA
>> "%~1" echo MABaAHAAYgBHAFUAaQBJAEcARgBqAFkAMgBWAHcAZABEADAAaQBMAG0ARgB3AGEA
>> "%~1" echo eQB4AGgAYwBIAEIAcwBhAFcATgBoAGQARwBsAHYAYgBpADkAMgBiAG0AUQB1AFkA
>> "%~1" echo VwA1AGsAYwBtADkAcABaAEMANQB3AFkAVwBOAHIAWQBXAGQAbABMAFcARgB5AFkA
>> "%~1" echo MgBoAHAAZABtAFUAaQBJAEgATgAwAGUAVwB4AGwAUABTAEoAawBhAFgATgB3AGIA
>> "%~1" echo RwBGADUATwBtADUAdgBiAG0AVQBpAFAAagB3AHYAWgBHAGwAMgBQAGcAMABLAFAA
>> "%~1" echo QwBFAHQATABTAEIAawBaAFgAUgBoAGEAVwB3AGcAYwAzAFIAaABkAEcAVQBnAEsA
>> "%~1" echo SABKAGwAZABtAFYAaABiAEcAVgBrAEkARwBGAG0AZABHAFYAeQBJAEgAVgB3AGIA
>> "%~1" echo RwA5AGgAWgBDAGsAZwBMAFMAMAArAEQAUQBvADgAWgBHAGwAMgBJAEcAbABrAFAA
>> "%~1" echo UwBKAGgAYwBHAHQARQBaAFgAUgBoAGEAVwB3AGkASQBIAE4AMABlAFcAeABsAFAA
>> "%~1" echo UwBKAGsAYQBYAE4AdwBiAEcARgA1AE8AbQA1AHYAYgBtAFUAaQBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBYAEIAdwBTAEcAVgB5AGIA
>> "%~1" echo eQBJACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBoAGMA
>> "%~1" echo SABCAEoAWQAyADkAdQBWAEcAbABzAFoAUwBJAGcAYQBXAFEAOQBJAG0ARgB3AGEA
>> "%~1" echo MABsAGoAYgAyADUAVQBhAFcAeABsAEkAagA0ADgAYwAzAFoAbgBJAEgAWgBwAFoA
>> "%~1" echo WABkAEMAYgAzAGcAOQBJAGoAQQBnAE0AQwBBAHkATgBDAEEAeQBOAEMASQArAFAA
>> "%~1" echo SABWAHoAWgBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBTADEAaABjAEcAcwBpAEwA
>> "%~1" echo egA0ADgATAAzAE4AMgBaAHoANAA4AEwAMgBSAHAAZABqADQATgBDAGoAeABrAGEA
>> "%~1" echo WABZACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBoAGMA
>> "%~1" echo SABCAE8AWQBXADEAbABJAGkAQgBwAFoARAAwAGkAWQBYAEIAcgBUAG0ARgB0AFoA
>> "%~1" echo UwBJACsATABUAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBjAEcAbABzAGIARgBKAHYAZAB5AEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBGAHcAYQAxAEIAcABiAEcAeAB6AEkAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAAQwA5AGsAYQBYAFkAKwBEAFEAbwA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKADIAWgBYAEoAQwBZAFcAUgBuAFoA
>> "%~1" echo UwBJAGcAYQBXAFEAOQBJAG0ARgB3AGEAMQBaAGwAYwBrAEoAaABaAEcAZABsAEkA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANABOAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADkAdwBkAEYASgB2AGQAeQBJACsARABRAG8AOABiAEcARgBpAFoA
>> "%~1" echo VwB3AGcAWQAyAHgAaABjADMATQA5AEkAbQA5AHcAZABFAE4AbwBhAFgAQQBpAFAA
>> "%~1" echo agB4AHAAYgBuAEIAMQBkAEMAQgAwAGUAWABCAGwAUABTAEoAagBhAEcAVgBqAGEA
>> "%~1" echo MgBKAHYAZQBDAEkAZwBhAFcAUQA5AEkAbQA5AHcAZABGAEoAbABjAEcAeABoAFkA
>> "%~1" echo MgBVAGkASQBHAE4AbwBaAFcATgByAFoAVwBRACsANgBZAGUATgA2AEsATwBGADUA
>> "%~1" echo TAArAGQANQA1AFcAWgA1AHAAVwB3ADUAbwAyAHUASQBEAHgAegBiAFcARgBzAGIA
>> "%~1" echo RAA0AHQAYwBqAHcAdgBjADIAMQBoAGIARwB3ACsAUABDADkAcwBZAFcASgBsAGIA
>> "%~1" echo RAA0AE4AQwBqAHgAcwBZAFcASgBsAGIAQwBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo MwBCADAAUQAyAGgAcABjAEMASQArAFAARwBsAHUAYwBIAFYAMABJAEgAUgA1AGMA
>> "%~1" echo RwBVADkASQBtAE4AbwBaAFcATgByAFkAbQA5ADQASQBpAEIAcABaAEQAMABpAGIA
>> "%~1" echo MwBCADAAUgAzAEoAaABiAG4AUQBpAFAAdQBhAE8AaQBPAFMANgBpAE8AVwBGAHEA
>> "%~1" echo TwBtAEQAcQBPAGEAZABnACsAbQBaAGsAQwBBADgAYwAyADEAaABiAEcAdwArAEwA
>> "%~1" echo VwBjADgATAAzAE4AdABZAFcAeABzAFAAagB3AHYAYgBHAEYAaQBaAFcAdwArAEQA
>> "%~1" echo UQBvADgAYgBHAEYAaQBaAFcAdwBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AOQB3AGQA
>> "%~1" echo RQBOAG8AYQBYAEEAaQBQAGoAeABwAGIAbgBCADEAZABDAEIAMABlAFgAQgBsAFAA
>> "%~1" echo UwBKAGoAYQBHAFYAagBhADIASgB2AGUAQwBJAGcAYQBXAFEAOQBJAG0AOQB3AGQA
>> "%~1" echo RQBSAHYAZAAyADUAbgBjAG0ARgBrAFoAUwBJACsANQBZAFcAQgA2AEsANgA0ADYA
>> "%~1" echo WgBtAE4ANQA3AHEAbgBJAEQAeAB6AGIAVwBGAHMAYgBEADQAdABaAEQAdwB2AGMA
>> "%~1" echo MgAxAGgAYgBHAHcAKwBQAEMAOQBzAFkAVwBKAGwAYgBEADQATgBDAGoAeABzAFkA
>> "%~1" echo VwBKAGwAYgBDAEIAagBiAEcARgB6AGMAegAwAGkAYgAzAEIAMABRADIAaABwAGMA
>> "%~1" echo QwBJACsAUABHAGwAdQBjAEgAVgAwAEkASABSADUAYwBHAFUAOQBJAG0ATgBvAFoA
>> "%~1" echo VwBOAHIAWQBtADkANABJAGkAQgBwAFoARAAwAGkAYgAzAEIAMABWAFcANQBwAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBSAG0AbAB5AGMAMwBRAGkAUAB1AGUAdAB2AHUAVwBRAGoA
>> "%~1" echo ZQBTADQAagBlAGUAcwBwAHUAVwBGAGkATwBXAE4AdQBPAGkAOQB2AFMAQQA4AGMA
>> "%~1" echo MgAxAGgAYgBHAHcAKwA1AHIAaQBGADUAcABXAHcANQBvADIAdQBQAEMAOQB6AGIA
>> "%~1" echo VwBGAHMAYgBEADQAOABMADIAeABoAFkAbQBWAHMAUABnADAASwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsARABRAG8AOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUASQBpAEIAcABaAEQAMABpAGEA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEUASgAwAGIAaQBJACsAUABIAE4AdwBZAFcANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AbAB1AGMAMwBSAGgAYgBHAHgARwBhAFcAeABzAEkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBhAFcANQB6AGQARwBGAHMAYgBFAFoAcABiAEcAdwBpAFAA
>> "%~1" echo agB3AHYAYwAzAEIAaABiAGoANAA4AGMAMwBCAGgAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBXADUAegBkAEcARgBzAGIARQB4AGgAWQBtAFYAcwBJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAYQBXADUAegBkAEcARgBzAGIARQB4AGgAWQBtAFYAcwBJAGoANwBsAHIA
>> "%~1" echo bwBuAG8AbwA0AFgAbABpAEwAQQBnAFUAWABWAGwAYwAzAFEAOABMADMATgB3AFkA
>> "%~1" echo VwA0ACsAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsARABRAG8AOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgB6AGQARwBGAG4AWgBWAEoAdgBkAHkASQBnAGEA
>> "%~1" echo VwBRADkASQBuAE4AMABZAFcAZABsAFUAbQA5ADMASQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAHAAWgBEADAAaQBjADMAUgBoAFoAMgBWAFUAWgBYAGgAMABJAGoANwBsAGgA
>> "%~1" echo NABiAGwAcABJAGYAawB1AEsAMwBpAGcASwBZADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo SABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBtAFYAcwBZAFgAQgB6AFoA
>> "%~1" echo VwBRAGkASQBHAGwAawBQAFMASgBsAGIARwBGAHcAYwAyAFYAawBJAGoANAB3AE8A
>> "%~1" echo agBBAHcAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYwBHAFYAeQBiAFgATgBRAGIA
>> "%~1" echo MwBBAGkASQBHAGwAawBQAFMASgBoAGMARwB0AFEAWgBYAEoAdABjAHkASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGgAWgBHAEoAUABkAFgAUQBpAEkARwBsAGsAUABTAEoAaABaAEcASgBQAGQA
>> "%~1" echo WABRAGkAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgB6AGQA
>> "%~1" echo SABsAHMAWgBUADAAaQBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwB4AE0A
>> "%~1" echo bgBCADQATwAyAFIAcABjADMAQgBzAFkAWABrADYAWgBtAHgAbABlAEQAdABuAFkA
>> "%~1" echo WABBADYATQBUAFIAdwBlAEQAdABtAGIARwBWADQATABYAGQAeQBZAFgAQQA2AGQA
>> "%~1" echo MwBKAGgAYwBDAEkAKwBQAEcARQBnAGEASABKAGwAWgBqADAAaQBJAHkASQBnAGEA
>> "%~1" echo VwBRADkASQBtAEYAdwBhADEAQgBsAGMAbQAxAHoAUQBuAFIAdQBJAGkAQgB6AGQA
>> "%~1" echo SABsAHMAWgBUADAAaQBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFkA
>> "%~1" echo bQB4ADEAWgBTAGsANwBaAG0AOQB1AGQAQwAxADMAWgBXAGwAbgBhAEgAUQA2AE4A
>> "%~1" echo egBBAHcATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNADMAQgA0AEkA
>> "%~1" echo agA3AG0AbgA2AFgAbgBuAEkAdgBtAG4AWQBQAHAAbQBaAEEAOABMADIARQArAFAA
>> "%~1" echo RwBFAGcAYQBIAEoAbABaAGoAMABpAEkAeQBJAGcAYQBXAFEAOQBJAG0ARgB3AGEA
>> "%~1" echo MQBKAGwAYwAyAFYAMABJAGkAQgB6AGQASABsAHMAWgBUADAAaQBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABPADIAWgB2AGIA
>> "%~1" echo bgBRAHQAZAAyAFYAcABaADIAaAAwAE8AagBjAHcATQBEAHQAbQBiADIANQAwAEwA
>> "%~1" echo WABOAHAAZQBtAFUANgBNAFQATgB3AGUAQwBJACsANQBvADIAaQA1AEwAaQBBADUA
>> "%~1" echo TABpAHEASQBFAEYAUQBTAHoAdwB2AFkAVAA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAAQwA5AGsAYQBYAFkAKwBEAFEAbwA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAdwB2AFoARwBsADIAUABnADAASwBQAEMAOQB6AFoA
>> "%~1" echo VwBOADAAYQBXADkAdQBQAGcAMABLAEQAUQBvAE4AQwBqAHgAegBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAWgBHAFYAMgBhAFcATgBsAEkAagA0AE4AQwBqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AaABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBvAHIA
>> "%~1" echo cgA3AGwAcABJAGYAbQBvAGEAUABtAG8AWQBnADgATAAyAGcAeQBQAGoAeAB6AGMA
>> "%~1" echo RwBGAHUASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAWQBXAGMAaQBQAHUAVwBGAHIA
>> "%~1" echo TwBXADgAZwBDAEIAQgBSAEUASQBnADUAWQArAHEANgBLACsANwBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEoAdgBaAEgAawBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAGwAdQBaAG0AOQBIAGMAbQBsAGsASQBqADQATgBDAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBsAHUAWgBtADkAVQBhAFcAeABsAEkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANwBsAGoAbwBMAGwAbABZAFkAZwBMAHkARABsAGsA
>> "%~1" echo NABIAG4AaQBZAHcAOABMADMATgB3AFkAVwA0ACsAUABHAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAYQBXAFEAOQBJAG0AMQBoAGIAbgBWAG0AWQBXAE4AMABkAFgASgBsAGMA
>> "%~1" echo aQBJACsATABUAHcAdgBjADMAQgBoAGIAagA0AGcATAB5AEEAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAHAAWgBEADAAaQBZAG4ASgBoAGIAbQBRAGkAUABpADAAOABMADMATgB3AFkA
>> "%~1" echo VwA0ACsAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABnADAASwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGEAVwA1AG0AYgAxAFIAcABiAEcAVQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBQAHUAVwBlAGkAKwBXAFAAdAB6AHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgAWQBpAEIAcABaAEQAMABpAGIAVwA5AGsAWgBXAHcAaQBQAGkAMAA4AEwA
>> "%~1" echo MgBJACsAUABDADkAawBhAFgAWQArAEQAUQBvADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAcABiAG0AWgB2AFYARwBsAHMAWgBTAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0ACsANQBMAHEAbgA1AFoATwBCAEkAQwA4AGcANgBLADYAKwA1AGEAUwBIAEkA
>> "%~1" echo QwA4AGcANQBwADIALwA1ADcAcQBuAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBJAEcAbABrAFAAUwBKAHcAYwBtADkAawBkAFcATgAwAFQA
>> "%~1" echo bQBGAHQAWgBTAEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAcABaAEQAMABpAGMASABKAHYAWgBIAFYAagBkAEUAUgBsAGQA
>> "%~1" echo bQBsAGoAWgBTAEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAcABaAEQAMABpAFkAbQA5AGgAYwBtAFEAaQBQAGkAMAA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBpAFAAagB3AHYAWgBHAGwAMgBQAGcAMABLAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBXADUAbQBiADEAUgBwAGIA
>> "%~1" echo RwBVAGkAUABqAHgAegBjAEcARgB1AFAAbABOAHYAUQB6AHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgAWQBpAEIAcABaAEQAMABpAGMAMgA5AGoASQBqADQAdABQAEMAOQBpAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBXADUAbQBiADEAUgBwAGIARwBVAGkAUABqAHgAegBjAEcARgB1AFAA
>> "%~1" echo awBKADEAYQBXAHgAawBQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAGkAZABXAGwAcwBaAEUAbABrAEkAagA0AHQAUABDADkAaQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABnADAASwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEA
>> "%~1" echo VwA1AG0AYgAxAFIAcABiAEcAVQBpAFAAagB4AHoAYwBHAEYAdQBQAGsASgB5AFkA
>> "%~1" echo VwA1AGoAYQBEAHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAFkA
>> "%~1" echo bgBWAHAAYgBHAFIAQwBjAG0ARgB1AFkAMgBnAGkAUABpADAAOABMADIASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBEAFEAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcANAArAFMA
>> "%~1" echo VwA1AGoAYwBtAFYAdABaAFcANQAwAFkAVwB3ADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo RwBJAGcAYQBXAFEAOQBJAG0ASgAxAGEAVwB4AGsAUwBXADUAagBjAG0AVgB0AFoA
>> "%~1" echo VwA1ADAAWQBXAHcAaQBQAGkAMAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAEQA
>> "%~1" echo UQBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAcABiAG0AWgB2AFYA
>> "%~1" echo RwBsAHMAWgBTAEkAKwBQAEgATgB3AFkAVwA0ACsAUQBVAEoASgBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABqAHgAaQBJAEcAbABrAFAAUwBKAGgAWQBtAGsAaQBQAGkAMAA4AEwA
>> "%~1" echo MgBJACsAUABDADkAawBhAFgAWQArAEQAUQBvADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAcABiAG0AWgB2AFYARwBsAHMAWgBTAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0ACsAVgBtAFYAdQBaAEcAOQB5AEkARgBCAGgAZABHAE4AbwBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABqAHgAaQBJAEcAbABrAFAAUwBKADIAWgBXADUAawBiADMASgBRAFkA
>> "%~1" echo WABSAGoAYQBDAEkAKwBMAFQAdwB2AFkAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo ZwAwAEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAG0AOQAzAEkA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBvAHIAcgA3AGwAcABJAGYAawB1AEkANwBvAHYA
>> "%~1" echo NQA3AG0AagBxAFUAOABMADIAZwB5AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeAAwAFkA
>> "%~1" echo VwBKAHMAWgBTAEIAagBiAEcARgB6AGMAegAwAGkAZABHAEYAaQBiAEcAVQBpAFAA
>> "%~1" echo ZwAwAEsAUABIAFIAeQBQAGoAeAAwAFoARAA1AEIAUgBFAEkAZwA2AEwAZQB2ADUA
>> "%~1" echo YgA2AEUAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG0ARgBrAFkA
>> "%~1" echo bABCAGgAZABHAGcAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANwBvAHIAcgA3AGwAcABJAGYAbwBvAFkAdwA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAWgBHAFYAMgBhAFcATgBsAFQA
>> "%~1" echo RwBsAHUAWgBTAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAGwAZABwAEwAVQBaAHAASQBFAGwAUQBQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbgBkAHAAWgBtAGwASgBjAEMASQArAEwA
>> "%~1" echo VAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAA
>> "%~1" echo awBGAHUAWgBIAEoAdgBhAFcAUQA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAWQBXADUAawBjAG0AOQBwAFoAQwBJACsATABUAHcAdgBkAEcAUQArAFAA
>> "%~1" echo QwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUABsAE4ARQBTAHoAdwB2AGQA
>> "%~1" echo RwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAHoAWgBHAHMAaQBQAGkAMAA4AEwA
>> "%~1" echo MwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQANwBsAHIA
>> "%~1" echo bwBuAGwAaABhAGoAbwBvAGEAWABrAHUASQBFADgATAAzAFIAawBQAGoAeAAwAFoA
>> "%~1" echo QwBCAHAAWgBEADAAaQBjADIAVgBqAGQAWABKAHAAZABIAGwAUQBZAFgAUgBqAGEA
>> "%~1" echo QwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQATgBDAGoAdwB2AGQA
>> "%~1" echo RwBGAGkAYgBHAFUAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAEQA
>> "%~1" echo UQBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkA
>> "%~1" echo agA0ADgAYQBEAEkAKwA1ADYARwBzADUATAB1ADIANQBwAEcAWQA2AEsAYQBCAFAA
>> "%~1" echo QwA5AG8ATQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0ADgAZABHAEYAaQBiAEcAVQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4AUgBoAFkAbQB4AGwASQBqADQATgBDAGoAeAAwAGMA
>> "%~1" echo agA0ADgAZABHAFEAKwA1AHAAaQArADUANgBTADYAUABDADkAMABaAEQANAA4AGQA
>> "%~1" echo RwBRAGcAYQBXAFEAOQBJAG0AUgBwAGMAMwBCAHMAWQBYAGwAVABkAFcAMQB0AFkA
>> "%~1" echo WABKADUASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGoAeAAwAGMA
>> "%~1" echo agA0ADgAZABHAFEAKwA1ADQATwB0ADUANABxADIANQBvAEMAQgBQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbgBSAG8AWgBYAEoAdABZAFcAeABUAGQA
>> "%~1" echo VwAxAHQAWQBYAEoANQBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAA
>> "%~1" echo agB4ADAAYwBqADQAOABkAEcAUQArADUAYgBlAGwANQBZADYAQwBMACsAYQBnAG8A
>> "%~1" echo ZQBXAEgAaABqAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMASgBtAFkA
>> "%~1" echo VwBOADAAYgAzAEoANQBVADMAVgB0AGIAVwBGAHkAZQBTAEkAKwBMAFQAdwB2AGQA
>> "%~1" echo RwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABIAFIAawBQAGwAWgBwAGMA
>> "%~1" echo bgBSADEAWQBXAHcAZwBSAEcAVgB6AGEAMwBSAHYAYwBEAHcAdgBkAEcAUQArAFAA
>> "%~1" echo SABSAGsAUABqAHgAegBjAEcARgB1AEkARwBsAGsAUABTAEoAMgBaAEYAQgBoAFkA
>> "%~1" echo MgB0AGgAWgAyAFUAaQBQAGkAMAA4AEwAMwBOAHcAWQBXADQAKwBJAEQAeAB6AGMA
>> "%~1" echo RwBGAHUASQBHAGwAawBQAFMASgAyAFoARgBaAGwAYwBuAE4AcABiADIANABpAFAA
>> "%~1" echo aQAwADgATAAzAE4AdwBZAFcANAArAFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAA
>> "%~1" echo ZwAwAEsAUABDADkAMABZAFcASgBzAFoAVAA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAGgAYwBtAFEAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBoAGwAWQBXAFEAaQBQAGoAeABvAE0AagA3AG0AaQBZAHYAbQBuADQAVABuAHUA
>> "%~1" echo cgAvAG4AdABLAEkAOABMADIAZwB5AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeAAwAFkA
>> "%~1" echo VwBKAHMAWgBTAEIAagBiAEcARgB6AGMAegAwAGkAZABHAEYAaQBiAEcAVQBpAFAA
>> "%~1" echo ZwAwAEsAUABIAFIAeQBQAGoAeAAwAFoARAA3AGwAdAA2AGIAbQBpAFkAdgBtAG4A
>> "%~1" echo NABUAG4AbABMAFgAcABoADQAOAA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAWQAyADkAdQBkAEgASgB2AGIARwB4AGwAYwBrAHgAbABaAG4AUgBDAFkA
>> "%~1" echo WABSADAAWgBYAEoANQBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAA
>> "%~1" echo agB4ADAAYwBqADQAOABkAEcAUQArADUAWQArAHoANQBvAG0ATAA1AHAAKwBFADUA
>> "%~1" echo NQBTADEANgBZAGUAUABQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAFMAYQBXAGQAbwBkAEUASgBoAGQA
>> "%~1" echo SABSAGwAYwBuAGsAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAA
>> "%~1" echo SABSAHkAUABqAHgAMABaAEQANwBsAHQANgBiAG0AaQBZAHYAbQBuADQAVABuAGkA
>> "%~1" echo cgBiAG0AZwBJAEUAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQAMABpAFkA
>> "%~1" echo MgA5AHUAZABIAEoAdgBiAEcAeABsAGMAawB4AGwAWgBuAFIAVABkAEcARgAwAGQA
>> "%~1" echo WABNAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAbABqADcAUABtAGkAWQB2AG0AbgA0AFQAbgBpAHIAYgBtAGcA
>> "%~1" echo SQBFADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBZADIAOQB1AGQA
>> "%~1" echo SABKAHYAYgBHAHgAbABjAGwASgBwAFoAMgBoADAAVQAzAFIAaABkAEgAVgB6AEkA
>> "%~1" echo agA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABnADAASwBQAEMAOQAwAFkA
>> "%~1" echo VwBKAHMAWgBUADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBzAGIA
>> "%~1" echo MgBjAGkASQBHAGwAawBQAFMASgBqAGIAMgA1ADAAYwBtADkAcwBiAEcAVgB5AFMA
>> "%~1" echo RwBsAHUAZABDAEkAKwBMAFQAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGcAMABLAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AGUAVQB0AGUAYQA2AGsA
>> "%~1" echo TwBlAEsAdAB1AGEAQQBnAFQAdwB2AGEARABJACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBtADkAawBlAFMASQArAFAA
>> "%~1" echo SABSAGgAWQBtAHgAbABJAEcATgBzAFkAWABOAHoAUABTAEoAMABZAFcASgBzAFoA
>> "%~1" echo UwBJACsARABRAG8AOABkAEgASQArAFAASABSAGsAUABtADEAVABkAEcARgA1AFQA
>> "%~1" echo MgA0ADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBiAFYATgAwAFkA
>> "%~1" echo WABsAFAAYgBpAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAG0AMQBRAGMAbQA5ADQAYQBXADEAcABkAEgAbABRAGIA
>> "%~1" echo MwBOAHAAZABHAGwAMgBaAFQAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAA
>> "%~1" echo UwBKAHQAVQBIAEoAdgBlAEcAbAB0AGEAWABSADUAVQBHADkAegBhAFgAUgBwAGQA
>> "%~1" echo bQBVAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADUAdABVADMAUgBoAGUAVQA5AHUAVgAyAGgAcABiAEcAVgBRAGIA
>> "%~1" echo SABWAG4AWgAyAFYAawBTAFcANQBUAFoAWABSADAAYQBXADUAbgBQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQAxAFQAZABHAEYANQBUADIANQBUAFoA
>> "%~1" echo WABSADAAYQBXADUAbgBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAA
>> "%~1" echo agB4ADAAYwBqADQAOABkAEcAUQArAFUAMgB4AGwAWgBYAEEAZwBkAEcAbAB0AFoA
>> "%~1" echo VwA5ADEAZABEAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMASgB3AGIA
>> "%~1" echo MwBkAGwAYwBsAE4AcwBaAFcAVgB3AFQARwBsAHUAWgBTAEkAKwBMAFQAdwB2AGQA
>> "%~1" echo RwBRACsAUABDADkAMABjAGoANABOAEMAagB3AHYAZABHAEYAaQBiAEcAVQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsARABRAG8AOABMADIAUgBwAGQA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBsAGoANABMAG0AbABiAEQAbAByADcAbgBuAGgA
>> "%~1" echo YQBjADgATAAyAGcAeQBQAGoAeAB6AGMARwBGAHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKADAAWQBXAGMAaQBJAEcAbABrAFAAUwBKAHcAWQBYAEoAaABiAFYATgAxAGIA
>> "%~1" echo VwAxAGgAYwBuAGsAaQBQAGkAMAA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUA
>> "%~1" echo UwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAEcARgB5AFkA
>> "%~1" echo VwAxAE0AYQBYAE4AMABJAGkAQgBwAFoARAAwAGkAYwBHAEYAeQBZAFcAMQBNAGEA
>> "%~1" echo WABOADAASQBqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAGgAYwBtAFEAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBoAGwAWQBXAFEAaQBQAGoAeABvAE0AagA3AGwAdAA2AFgAbABqAG8ASQBnAEwA
>> "%~1" echo eQBEAG0AbwBLAEgAbABoADQAYgBtAGoAcQBqAG0AbABxADMAbwB2AHIAbgBuAGwA
>> "%~1" echo WQB3ADgATAAyAGcAeQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AeAB2AFoAeQBJACsANQBZACsAdgA1AEwAdQBsADUA
>> "%~1" echo cABpACsANQA2AFMANgBJAEYARgAxAFoAWABOADAASQBPAFcARgByAE8AVwA4AGcA
>> "%~1" echo QwBCAEIAUgBFAEkAZwA1AHAAcQAwADYAWgB5AHkANQA1AHEARQBJAEUAWgBoAFkA
>> "%~1" echo MwBSAHYAYwBuAGsAZwBMAHkAQgBQAGIAbQB4AHAAYgBtAFUAZwBZADIARgBzAGEA
>> "%~1" echo VwBKAHkAWQBYAFIAcABiADIANABnADUANwBxAC8ANQA3AFMAaQA3ADcAeQBNADUA
>> "%~1" echo TAA2AEwANQBhAGEAQwBJAEUAVgAxAGMAbQBWAHIAWQBlAE8AQQBnAFYAQgBXAFYA
>> "%~1" echo RABFAHUATQBlAE8AQQBnAFgATgAwAFkAWABSAHAAYgAyADQAdgBiAEcAOQBqAFkA
>> "%~1" echo WABSAHAAYgAyADQAdgBkAEcAVgB6AGQAQwBEAGsAdQA2AFAAbgBvAEkASABqAGcA
>> "%~1" echo SQBMAGsAdQBJADMAbwBnADcAMwBtAGkAbwByAGwAaABvAFgAcABnADYAagBrAHUA
>> "%~1" echo NgBQAG4AbwBJAEgAbABqADYALwBwAG4AYQBEAG4AdgA3AHYAbwByADUASABtAGkA
>> "%~1" echo SgBEAGwAaABiAGYAawB2AFoAUABsAG0ANwAzAGwAcgByAGIAagBnAEkASABsAG4A
>> "%~1" echo NAA3AGwAdQBJAEwAbQBpAEoAYgBsAHQANgBYAGwAagBvAEwAdgB2AEoAdABYAGEA
>> "%~1" echo UwAxAEcAYQBTAEQAbABtADcAMwBsAHIAcgBiAG4AbwBJAEgAawB1AFoALwBrAHUA
>> "%~1" echo SQAzAG4AcgBZAG4AawB1AG8ANwBsAGgANwByAGsAdQBxAGYAbABuAEwARABqAGcA
>> "%~1" echo SQBMAGwAcgBvAHoAbQBsAGIAVABsAHIAWgBmAG0AcgByAFgAbwByADcAZgBuAGwA
>> "%~1" echo SwBqAGkAZwBKAHoAawB1AEkARABwAGwASwA3AGwAcgA3AHoAbABoADcAcgBvAHIA
>> "%~1" echo cgA3AGwAcABJAGYAbABoAGEAagBwAGcANgBqAGsAdgA2AEgAbQBnAGEALwBpAGcA
>> "%~1" echo SgAzAGoAZwBJAEkAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAdwB2AGMAMgBWAGoAZABHAGwAdgBiAGoANABOAEMA
>> "%~1" echo ZwAwAEsAUABIAE4AbABZADMAUgBwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bgBCAGgAWgAyAFUAaQBJAEcAbABrAFAAUwBKAG8AWgBXAEYAawBjADIAVgAwAEkA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGkAQgBrAFkAWABSAGgATABXAGsAeABPAEcANAA5AEkA
>> "%~1" echo bQBoAHoAVQBHADkAMwBaAFgASQBpAFAAdQBlAFUAdABlAGEANgBrAE8AUwA0AGoA
>> "%~1" echo dQBTADgAawBlAGUAYwBvAEQAdwB2AGEARABJACsAUABIAE4AdwBZAFcANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoAeQBJAGcAYQBXAFEAOQBJAG0AaAB6AFYA
>> "%~1" echo MgBGAHkAYgBpAEkAKwBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgAawBpAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABjAG0ARgB0AFQA
>> "%~1" echo RwBsAHoAZABDAEkAZwBhAFcAUQA5AEkAbQBoAHoAVQBHADkAMwBaAFgASgBNAGEA
>> "%~1" echo WABOADAASQBqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQATgBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAGgAYwBtAFEAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBoAGwAWQBXAFEAaQBQAGoAeABvAE0AaQBCAGsAWQBYAFIAaABMAFcAawB4AE8A
>> "%~1" echo RwA0ADkASQBtAGgAegBSAEcAbAB6AGMARwB4AGgAZQBTAEkAKwA1AHAAaQArADUA
>> "%~1" echo NgBTADYAUABDADkAbwBNAGoANAA4AGMAMwBCAGgAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAZABHAEYAbgBJAGkAQgBwAFoARAAwAGkAYQBIAE4ARQBhAFgATgB3AGIA
>> "%~1" echo RwBGADUAVgBHAEYAbgBJAGoANAB0AFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoA
>> "%~1" echo SABrAGcAYwAyAFYAMABSADMASgBwAFoAQwBJAGcAYQBXAFEAOQBJAG0AaAB6AFIA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFMASQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBqAFkA
>> "%~1" echo WABKAGsASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAFoA
>> "%~1" echo VwBGAGsASQBqADQAOABhAEQASQBnAFoARwBGADAAWQBTADEAcABNAFQAaAB1AFAA
>> "%~1" echo UwBKAG8AYwAwAE4AdgBiAFcAWgB2AGMAbgBRAGkAUAB1AGkASQBrAHUAbQBBAGcA
>> "%~1" echo aQBBAHYASQBPAGUAbgB1ACsAVwBLAHEARAB3AHYAYQBEAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5AEkAKwBhAEcAOQB5AGEA
>> "%~1" echo WABwAHYAYgBtADkAegBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgAawBnAGMA
>> "%~1" echo MgBWADAAUgAzAEoAcABaAEMASQBnAGEAVwBRADkASQBtAGgAegBRADIAOQB0AFoA
>> "%~1" echo bQA5AHkAZABDAEkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAEQA
>> "%~1" echo UQBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkA
>> "%~1" echo agA0ADgAYQBEAEkAZwBaAEcARgAwAFkAUwAxAHAATQBUAGgAdQBQAFMASgBvAGMA
>> "%~1" echo MQBkAHAAYwBtAFYAcwBaAFgATgB6AEkAagA3AG0AbAA2AEQAbgB1AHIAOABnAFEA
>> "%~1" echo VQBSAEMAUABDADkAbwBNAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGIAMgBSADUASQBHAE4AdABaAEUAZAB5AGEA
>> "%~1" echo VwBRAGkAUABnADAASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyADEAawBJAEcARgB0AFkAbQBWAHkASQBHAFIAaABiAG0AZABsAGMA
>> "%~1" echo awBGAGoAZABHAGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEAaABZADMAUgBwAGIA
>> "%~1" echo MgA0ADkASQBuAGQAcABjAG0AVgBzAFoAWABOAHoASQBqADQAOABZAGkAQgBrAFkA
>> "%~1" echo WABSAGgATABXAGsAeABPAEcANAA5AEkAbQBOAHQAWgBGAGQAcABjAG0AVgBzAFoA
>> "%~1" echo WABOAHoASQBqADcAbAB2AEkARABsAGsASwAvAG0AbAA2AEQAbgB1AHIAOABnAFEA
>> "%~1" echo VQBSAEMAUABDADkAaQBQAGoAeAB6AGMARwBGAHUAUABuAFIAagBjAEcAbAB3AEkA
>> "%~1" echo RABVADEATgBUAFUAOABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0ACsARABRAG8AOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGoAYgBXAFEAZwBZAFcAMQBpAFoAWABJAGcAWgBHAEYAdQBaADIAVgB5AFEA
>> "%~1" echo VwBOADAAYQBXADkAdQBJAGkAQgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIA
>> "%~1" echo agAwAGkAZAAyAGwAeQBaAFcAeABsAGMAMwBOAGYAYgAyAFoAbQBJAGoANAA4AFkA
>> "%~1" echo aQBCAGsAWQBYAFIAaABMAFcAawB4AE8ARwA0ADkASQBtAE4AdABaAEYAZABwAGMA
>> "%~1" echo bQBWAHMAWgBYAE4AegBUADIAWgBtAEkAagA3AGwAaABiAFAAcABsADYAMwBtAGwA
>> "%~1" echo NgBEAG4AdQByADgAZwBRAFUAUgBDAFAAQwA5AGkAUABqAHgAegBjAEcARgB1AFAA
>> "%~1" echo bABWAFQAUQBqAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0AE4AQwBqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAHQAWgBDAEIAaQBiAEgAVgBsAEkAaQBCAGsAWQBYAFIAaABMAFcARgBqAGQA
>> "%~1" echo RwBsAHYAYgBqADAAaQBZADIAOQB1AGMAMgBWAHkAZABtAEYAMABhAFgAWgBsAEkA
>> "%~1" echo agA0ADgAWQBpAEIAawBZAFgAUgBoAEwAVwBrAHgATwBHADQAOQBJAG0ATgB0AFoA
>> "%~1" echo RQBOAHYAYgBuAE4AbABjAG4AWgBoAGQARwBsADIAWgBTAEkAKwA1AEwAKwBkADUA
>> "%~1" echo YQA2AEkANgBiAHUAWQA2AEsANgBrADUAWQBDADgAUABDADkAaQBQAGoAeAB6AGMA
>> "%~1" echo RwBGAHUAUAB1AGEAQgBvAHUAVwBrAGoAZQBTADgAawBlAGUAYwBvAEQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBqADQATgBDAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBJAEcAUgBoAGQA
>> "%~1" echo RwBFAHQAYQBUAEUANABiAGoAMABpAGEASABOAEIAWgBIAFoAaABiAG0ATgBsAFoA
>> "%~1" echo QwBJACsANgBhAHUAWQA1ADcAcQBuAFAAQwA5AG8ATQBqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkA
>> "%~1" echo agA0AE4AQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AWgB2AGMA
>> "%~1" echo bQAwAGkAUABqAHgAegBaAFcAeABsAFkAMwBRAGcAYQBXAFEAOQBJAG0ATgAxAGMA
>> "%~1" echo MwBSAHYAYgBVADUAegBJAGoANAA4AGIAMwBCADAAYQBXADkAdQBQAG0AZABzAGIA
>> "%~1" echo MgBKAGgAYgBEAHcAdgBiADMAQgAwAGEAVwA5AHUAUABqAHgAdgBjAEgAUgBwAGIA
>> "%~1" echo MgA0ACsAYwAzAGwAegBkAEcAVgB0AFAAQwA5AHYAYwBIAFIAcABiADIANAArAFAA
>> "%~1" echo RwA5AHcAZABHAGwAdgBiAGoANQB6AFoAVwBOADEAYwBtAFUAOABMADIAOQB3AGQA
>> "%~1" echo RwBsAHYAYgBqADQAOABMADMATgBsAGIARwBWAGoAZABEADQAOABhAFcANQB3AGQA
>> "%~1" echo WABRAGcAYQBXAFEAOQBJAG0ATgAxAGMAMwBSAHYAYgBVAHQAbABlAFMASQBnAGMA
>> "%~1" echo RwB4AGgAWQAyAFYAbwBiADIAeABrAFoAWABJADkASQBuAE4AagBjAG0AVgBsAGIA
>> "%~1" echo bAA5AHYAWgBtAFoAZgBkAEcAbAB0AFoAVwA5ADEAZABDAEkAKwBQAEcAbAB1AGMA
>> "%~1" echo SABWADAASQBHAGwAawBQAFMASgBqAGQAWABOADAAYgAyADEAVwBZAFcAeAAxAFoA
>> "%~1" echo UwBJAGcAYwBHAHgAaABZADIAVgBvAGIAMgB4AGsAWgBYAEkAOQBJAG4AWgBoAGIA
>> "%~1" echo SABWAGwASQBqADQAOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGkAZABHADQAaQBJAEcAbABrAFAAUwBKAGoAZABYAE4AMABiADIAMQBUAFoA
>> "%~1" echo WABRAGkAUABuAEIAMQBkAEQAdwB2AFkAbgBWADAAZABHADkAdQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABnADAASwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFoA
>> "%~1" echo bQA5AHkAYgBTAEkAZwBjADMAUgA1AGIARwBVADkASQBtAGQAeQBhAFcAUQB0AGQA
>> "%~1" echo RwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoAbwB4AFoA
>> "%~1" echo bgBJAGcATwBUAEIAdwBlAEQAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8A
>> "%~1" echo agBFAHkAYwBIAGcAaQBQAGoAeABwAGIAbgBCADEAZABDAEIAcABaAEQAMABpAFkA
>> "%~1" echo bgBKAHYAWQBXAFIAagBZAFgATgAwAFQAbQBGAHQAWgBTAEkAZwBjAEcAeABoAFkA
>> "%~1" echo MgBWAG8AYgAyAHgAawBaAFgASQA5AEkAbQBOAHYAYgBTADUAdgBZADMAVgBzAGQA
>> "%~1" echo WABNAHUAZABuAEoAdwBiADMAZABsAGMAbQAxAGgAYgBtAEYAbgBaAFgASQB1AGMA
>> "%~1" echo SABKAHYAZQBGADkAdgBjAEcAVgB1AEkAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGQARwA0AGkASQBHAGwAawBQAFMASgBqAGQA
>> "%~1" echo WABOADAAYgAyADEAQwBjAG0AOQBoAFoARwBOAGgAYwAzAFEAaQBQAG4ATgBsAGIA
>> "%~1" echo bQBRADgATAAyAEoAMQBkAEgAUgB2AGIAagA0ADgATAAyAFIAcABkAGoANABOAEMA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABnADAASwBQAEMAOQB6AFoA
>> "%~1" echo VwBOADAAYQBXADkAdQBQAGcAMABLAFAASABOAGwAWQAzAFIAcABiADIANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4AQgBoAFoAMgBVAGkASQBHAGwAawBQAFMASgB6AFoA
>> "%~1" echo WABSADAAYQBXADUAbgBjAHkASQArAFAAQwA5AHoAWgBXAE4AMABhAFcAOQB1AFAA
>> "%~1" echo ZwAwAEsAUABIAE4AbABZADMAUgBwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bgBCAGgAWgAyAFUAaQBJAEcAbABrAFAAUwBKAHAAYgBuAE4AMABZAFcAeABzAEkA
>> "%~1" echo agA0ADgATAAzAE4AbABZADMAUgBwAGIAMgA0ACsARABRAG8ATgBDAGoAeAB6AFoA
>> "%~1" echo VwBOADAAYQBXADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAdwBZAFcAZABsAEkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBiAEcAOQBuAGMAeQBJACsARABRAG8AOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAFkAWABKAGsASQBqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQAOABhAEQASQArADUA
>> "%~1" echo cABlAGwANQBiACsAWABQAEMAOQBvAE0AagA0ADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGQARwA0AGcAWgAyAGgAdgBjADMAUQBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAeQBaAFcAWgB5AFoAWABOAG8AVABHADkAbgBjAHkASQArADUA
>> "%~1" echo WQBpADMANQBwAGEAdwA1AHAAZQBsADUAYgArAFgAUABDADkAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0ACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQBtADkAawBlAFMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYgBXAFYAMABZAFUAbAAwAFoAVwAwAGkASQBIAE4AMABlAFcAeABsAFAA
>> "%~1" echo UwBKAHQAWQBYAEoAbgBhAFcANAB0AFkAbQA5ADAAZABHADkAdABPAGoARQB5AGMA
>> "%~1" echo SABnAGkAUABqAHgAegBjAEcARgB1AFAAdQBhAFgAcABlAFcALwBsACsAYQBXAGgA
>> "%~1" echo KwBTADcAdABqAHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAGIA
>> "%~1" echo RwA5AG4AVQBHAEYAMABhAEMASQArAEwAVAB3AHYAWQBqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAcwBiADIAYwBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAcwBiADIAZABDAGIAMwBnAGkAUAB1AGUAdABpAGUAVwArAGgA
>> "%~1" echo ZQBhAFQAagBlAFMAOQBuAEMANAB1AEwAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAZwAwAEsAUABDADkAegBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUAUABnADAASwBEAFEAbwA4AEwAMgBSAHAAZABqADQAOABMADIAMQBoAGEA
>> "%~1" echo VwA0ACsAUABDADkAawBhAFgAWQArAEQAUQBvADgAYwAyAE4AeQBhAFgAQgAwAFAA
>> "%~1" echo ZwAwAEsAWQAyADkAdQBjADMAUQBnAFYARQA5AEwAUgBVADQAOQBKADEAdABiAFYA
>> "%~1" echo RQA5AEwAUgBVADUAZABYAFMAYwA3AEQAUQBwAGoAYgAyADUAegBkAEMAQgBDAFQA
>> "%~1" echo MAA5AFUAWAAwAHgAQgBUAGsAYwA5AEoAMQB0AGIAVABFAEYATwBSADEAMQBkAEoA
>> "%~1" echo egBzAE4AQwBtAE4AdgBiAG4ATgAwAEkAQwBRADkAYQBXAFEAOQBQAG0AUgB2AFkA
>> "%~1" echo MwBWAHQAWgBXADUAMABMAG0AZABsAGQARQBWAHMAWgBXADEAbABiAG4AUgBDAGUA
>> "%~1" echo VQBsAGsASwBHAGwAawBLAFQAcwBOAEMAbQBOAHYAYgBuAE4AMABJAEUAawB4AE8A
>> "%~1" echo RQA0ADkAZQB3ADAASwBlAG0AZwA2AGUAMgA1AGgAZABrADkAMgBaAFgASgAyAGEA
>> "%~1" echo VwBWADMATwBpAGYAbQBnAEwAdgBvAHAANABnAG4ATABHADUAaABkAGsATgB2AGIA
>> "%~1" echo bgBOAHYAYgBHAFUANgBKACsAVwAvAHEAKwBhAE4AdAArAGEATwBwACsAVwBJAHQA
>> "%~1" echo dQBXAFAAcwBDAGMAcwBiAG0ARgAyAFEAWABCAHcAYwB6AG8AbgA1AGIAcQBVADUA
>> "%~1" echo NQBTAG8ASgB5AHgAdQBZAFgAWgBJAFoAVwBGAGsAYwAyAFYAMABPAGkAZgBsAHAA
>> "%~1" echo TABUAG0AbQBMADcAbwByAHIANwBuAHYAYQA0AG4ATABHADUAaABkAGsAUgBsAGQA
>> "%~1" echo bQBsAGoAWgBUAG8AbgA2AEsANgArADUAYQBTAEgANQBMACsAaAA1AG8ARwB2AEoA
>> "%~1" echo eQB4AHUAWQBYAFoATQBiADIAZAB6AE8AaQBmAG0AbAA2AFgAbAB2ADUAYwBuAEwA
>> "%~1" echo RwA1AGgAZABrAFoAdgBiADMAUQA2AEoAKwBXAFAAcQB1AGUAYgBrAGUAVwBRAHIA
>> "%~1" echo QwBBAHgATQBqAGMAdQBNAEMANAB3AEwAagBGAGMAYgB1AFcARgBzACsAbQBYAHIA
>> "%~1" echo ZQBlAHEAbAArAFcAUABvACsAVwBOAHMAKwBXAEIAbgBPAGEAdABvAHUAYQBjAGoA
>> "%~1" echo ZQBXAEsAbwBTAGMAcwBZAG4ASgBoAGIAbQBSAFQAZABXAEkANgBKACsAYQBjAHIA
>> "%~1" echo TwBXAGMAcwBDAEIAWABaAFcASgBWAFMAUwBjAHMAZABHADkAdwBUAG0AOQAwAGEA
>> "%~1" echo VwBOAGwATwBpAGYAawB2ADUAMwBtAHQATAB2AGoAZwBJAEUAeQBOAEMARABsAHMA
>> "%~1" echo SQAvAG0AbAA3AGIAawB1AHEANwBsAHMAWQAvAGwAawBvAHoAbQBsADYARABuAHUA
>> "%~1" echo cgA4AGcAUQBVAFIAQwBJAE8AVwBQAHEAdQBXADcAdQB1AGkAdQByAHUAZQBmAHIA
>> "%~1" echo ZQBhAFgAdAB1AG0AWAB0AE8AYQAxAGkAKwBpAHYAbABlACsAOABtACsAZQA3AGsA
>> "%~1" echo KwBhAGQAbgArAFcAUQBqAHUAYQBKAHAAKwBpAGgAagBPAEsAQQBuAE8AVwB1AGkA
>> "%~1" echo ZQBXAEYAcQBPAGUARwBoAE8AVwB4AGoAKwBLAEEAbgBlAGEASQBsAHUASwBBAG4A
>> "%~1" echo TwBTAC8AbgBlAFcAdQBpAE8AbQA3AG0ATwBpAHUAcABPAFcAQQB2AE8ASwBBAG4A
>> "%~1" echo ZQBPAEEAZwB1AFcAdQBpAGUAaQBqAGgAUwBCAEIAVQBFAHMAZwA1AEwAeQBhADUA
>> "%~1" echo TAArAHUANQBwAFMANQA2AEsANgArADUAYQBTAEgANwA3AHkATQA2AEsAKwAzADUA
>> "%~1" echo NgBHAHUANgBLADYAawA1AHAAMgBsADUAcgBxAFEANQBZACsAdgA1AEwAKwBoADQA
>> "%~1" echo NABDAEMASgB5AHgAaABaAEcASgBOAGEAWABOAHoAYQBXADUAbgBWAEcAbAAwAGIA
>> "%~1" echo RwBVADYASgArAGEAYwBxAHUAYQBKAHYAdQBXAEkAcwBDAEIAQgBSAEUASQBuAEwA
>> "%~1" echo RwBGAGsAWQBrADEAcABjADMATgBwAGIAbQBkAEkAYQBXADUAMABPAGkAZgBtAG4A
>> "%~1" echo SwB6AG0AbgBMAHIAbQBzAHEASABtAG4ASQBuAGwAagA2AC8AbgBsAEsAagBuAG0A
>> "%~1" echo bwBRAGcAWQBXAFIAaQBMAG0AVgA0AFoAZQBPAEEAZwB1AFcAUAByACsAUwA3AHAA
>> "%~1" echo ZQBTADQAaQArAGkAOQB2AFMAQgBIAGIAMgA5AG4AYgBHAFUAZwBjAEcAeABoAGQA
>> "%~1" echo RwBaAHYAYwBtADAAdABkAEcAOQB2AGIASABNAGcANQBZAGkAdwA1AGIAZQBsADUA
>> "%~1" echo WQBXADMANQA1AHUAdQA1AGIAMgBWADQANABDAEMASgB5AHgAaABaAEcASgBFAGIA
>> "%~1" echo MwBkAHUAYgBHADkAaABaAEQAbwBuADUATABpAEwANgBMADIAOQBJAEUARgBFAFEA
>> "%~1" echo aQBjAHMAYwBHAEYAbgBaAFUAOQAyAFoAWABKADIAYQBXAFYAMwBPAGwAcwBuADUA
>> "%~1" echo bwBDADcANgBLAGUASQBKAHkAdwBuADUANABxADIANQBvAEMAQgA1AG8AeQBIADUA
>> "%~1" echo cQBDAEgANQBaAEsATQA2AEsANgArADUAYQBTAEgANQBxAGEAQwA2AEsAZQBJAEoA
>> "%~1" echo MQAwAHMAYwBHAEYAbgBaAFUATgB2AGIAbgBOAHYAYgBHAFUANgBXAHkAZgBsAHYA
>> "%~1" echo NgB2AG0AagBiAGYAbQBqAHEAZgBsAGkATABiAGwAagA3AEEAbgBMAEMAZgBsAHUA
>> "%~1" echo TABqAG4AbABLAGcAZwBRAFUAUgBDAEkATwBhAFQAagBlAFMAOQBuAEMAZABkAEwA
>> "%~1" echo SABCAGgAWgAyAFYAQgBjAEgAQgB6AE8AbABzAG4ANQBiAHEAVQA1ADUAUwBvAEoA
>> "%~1" echo eQB3AG4ANQBiAGUAeQA1AGEANgBKADYASwBPAEYANQBiAHEAVQA1ADUAUwBvADQA
>> "%~1" echo NABDAEIANgBLACsAbQA1AG8ATwBGADQANABDAEIANQBvACsAUQA1AFkAKwBXADUA
>> "%~1" echo TABpAE8ANQBZADIANAA2AEwAMgA5AEoAMQAwAHMAYwBHAEYAbgBaAFUAaABsAFkA
>> "%~1" echo VwBSAHoAWgBYAFEANgBXAHkAZgBsAHAATABUAG0AbQBMADcAbwByAHIANwBuAHYA
>> "%~1" echo YQA0AG4ATABDAGYAbgBsAEwAWABtAHUAcABEAGoAZwBJAEgAbQBtAEwANwBuAHAA
>> "%~1" echo TAByAGoAZwBJAEgAbwBpAEoATABwAGcASQBMAG4AcAA3AHYAbABpAHEAagBrAHUA
>> "%~1" echo SQA3AHAAcQA1AGoAbgB1AHEAZgBsAGgAcABuAGwAaABhAFUAbgBYAFMAeAB3AFkA
>> "%~1" echo VwBkAGwAUgBHAFYAMgBhAFcATgBsAE8AbABzAG4ANgBLADYAKwA1AGEAUwBIADUA
>> "%~1" echo TAArAGgANQBvAEcAdgBKAHkAdwBuADUANwBPADcANQA3AHUAZgA0ADQAQwBCAFYA
>> "%~1" echo bQBsAHkAZABIAFYAaABiAEMAQgBFAFoAWABOAHIAZABHADkAdwA0ADQAQwBCADUA
>> "%~1" echo bwBtAEwANQBwACsARQA1AFoASwBNADUANQBTADEANQByAHEAUQA1ADcAcQAvADUA
>> "%~1" echo NwBTAGkASgAxADAAcwBjAEcARgBuAFoAVQB4AHYAWgAzAE0ANgBXAHkAZgBtAGwA
>> "%~1" echo NgBYAGwAdgA1AGMAbgBMAEMAZgBtAG4ASQBEAG8AdgA1AEgAawB1AEkARABtAHIA
>> "%~1" echo SwBIAG0AawA0ADMAawB2AFoAegBuAHUANQBQAG0AbgBwAHcAbgBYAFMAeAAwAFkA
>> "%~1" echo VwBKAEoAYgBuAE4AMABZAFcAeABzAFoAVwBRADYASgArAFcAMwBzAHUAVwB1AGkA
>> "%~1" echo ZQBpAGoAaABTAGMAcwBkAEcARgBpAFUAMgBsAGsAWgBXAHgAdgBZAFcAUQA2AEoA
>> "%~1" echo KwBXAHUAaQBlAGkAagBoAFMAQgBCAFUARQBzAG4ATABIAE4AagBiADMAQgBsAFYA
>> "%~1" echo WABOAGwAYwBqAG8AbgA1ADYAeQBzADUATABpAEoANQBwAGEANQBKAHkAeAB6AFkA
>> "%~1" echo MgA5AHcAWgBVAEYAcwBiAEQAbwBuADUAWQBXAG8ANgBZAE8AbwBKAHkAeAB6AFkA
>> "%~1" echo MgA5AHcAWgBWAE4ANQBjADMAUgBsAGIAVABvAG4ANQA3AE8ANwA1ADcAdQBmAEoA
>> "%~1" echo eQB4AGwAZQBIAFIAeQBZAFcATgAwAFQAMgBzADYASgArAGEAUABrAE8AVwBQAGwA
>> "%~1" echo dQBXAHUAagBPAGEASQBrAEMAYwBzAGQAVwA1AHAAYgBuAE4AMABZAFcAeABzAFEA
>> "%~1" echo WABOAHIATwBpAGYAbABzAEkAYgBsAGoAYgBqAG8AdgBiADMAbwByADYAWABsAHUA
>> "%~1" echo cABUAG4AbABLAGoAbAB1AGIAYgBtAHUASQBYAHAAbQBhAFQAbABoAGIAYgBtAGwA
>> "%~1" echo YgBEAG0AagBhADcAagBnAEkASQBuAEwARwBOAHMAWgBXAEYAeQBRAFgATgByAE8A
>> "%~1" echo aQBmAGwAcwBJAGIAbQB1AEkAWABwAG0AYQBUAG8AcgA2AFgAbAB1AHAAVABuAGwA
>> "%~1" echo SwBqAGwAaABhAGoAcABnADYAagBtAGwAYgBEAG0AagBhADcAagBnAEkASQBuAEwA
>> "%~1" echo RwBSAHAAYwAyAEYAaQBiAEcAVgBCAGMAMgBzADYASgArAFcAdwBoAHUAZQBtAGcA
>> "%~1" echo ZQBlAFUAcQBPAGkAdgBwAGUAVwA2AGwATwBlAFUAcQBPAE8AQQBnAGkAZAA5AEwA
>> "%~1" echo QQAwAEsAWgBXADQANgBlADIANQBoAGQAawA5ADIAWgBYAEoAMgBhAFcAVgAzAE8A
>> "%~1" echo aQBkAFAAZABtAFYAeQBkAG0AbABsAGQAeQBjAHMAYgBtAEYAMgBRADIAOQB1AGMA
>> "%~1" echo MgA5AHMAWgBUAG8AbgBRADIAOQB1AGMAMgA5AHMAWgBTAGMAcwBiAG0ARgAyAFEA
>> "%~1" echo WABCAHcAYwB6AG8AbgBRAFgAQgB3AGMAeQBjAHMAYgBtAEYAMgBTAEcAVgBoAFoA
>> "%~1" echo SABOAGwAZABEAG8AbgBTAEcAVgBoAFoASABOAGwAZABDAGMAcwBiAG0ARgAyAFIA
>> "%~1" echo RwBWADIAYQBXAE4AbABPAGkAZABFAFoAWABaAHAAWQAyAFUAbgBMAEcANQBoAGQA
>> "%~1" echo awB4AHYAWgAzAE0ANgBKADAAeAB2AFoAMwBNAG4ATABHADUAaABkAGsAWgB2AGIA
>> "%~1" echo MwBRADYASgAwAHgAdgBiADMAQgBpAFkAVwBOAHIASQBEAEUAeQBOAHkANAB3AEwA
>> "%~1" echo agBBAHUATQBTAEIAdgBiAG0AeAA1AFgARwA1AEQAYgBHADkAegBaAFMAQgAwAGEA
>> "%~1" echo RwBVAGcAZAAyAGwAdQBaAEcAOQAzAEkASABSAHYASQBIAE4AMABiADMAQQBuAEwA
>> "%~1" echo RwBKAHkAWQBXADUAawBVADMAVgBpAE8AaQBkAE0AYgAyAE4AaABiAEMAQgBYAFoA
>> "%~1" echo VwBKAFYAUwBTAGMAcwBkAEcAOQB3AFQAbQA5ADAAYQBXAE4AbABPAGkAZABMAFoA
>> "%~1" echo VwBWAHcATABXAEYAMwBZAFcAdABsAEwAQwBBAHkATgBHAGcAZwBjADIATgB5AFoA
>> "%~1" echo VwBWAHUATABDAEIAaABiAG0AUQBnAGQAMgBsAHkAWgBXAHgAbABjADMATQBnAFEA
>> "%~1" echo VQBSAEMASQBHAEYAeQBaAFMAQgBtAGIAMwBJAGcAYwAyAGgAdgBjAG4AUQBnAGQA
>> "%~1" echo RwBWAHoAZABIAE0AdQBJAEYAVgB6AFoAUwBCAFQAWQBXAFoAbABJAEgATgBzAFoA
>> "%~1" echo VwBWAHcASQBHADkAeQBJAEUATgB2AGIAbgBOAGwAYwBuAFoAaABkAEcAbAAyAFoA
>> "%~1" echo UwBCAGsAWgBXAFoAaABkAFcAeAAwAGMAeQBCADMAYQBHAFYAdQBJAEcAUgB2AGIA
>> "%~1" echo bQBVAHUASQBFAGwAdQBjADMAUgBoAGIARwB4AHAAYgBtAGMAZwBRAFYAQgBMAGMA
>> "%~1" echo eQBCAGoAYQBHAEYAdQBaADIAVgB6AEkASABSAG8AWgBTAEIAbwBaAFcARgBrAGMA
>> "%~1" echo MgBWADAASQBPAEsAQQBsAEMAQgB2AGIAbQB4ADUASQBIAFYAegBaAFMAQgB3AFkA
>> "%~1" echo VwBOAHIAWQBXAGQAbABjAHkAQgA1AGIAMwBVAGcAZABIAEoAMQBjADMAUQB1AEoA
>> "%~1" echo eQB4AGgAWgBHAEoATgBhAFgATgB6AGEAVwA1AG4AVgBHAGwAMABiAEcAVQA2AEoA
>> "%~1" echo MABGAEUAUQBpAEIAdQBiADMAUQBnAFoAbQA5ADEAYgBtAFEAbgBMAEcARgBrAFkA
>> "%~1" echo awAxAHAAYwAzAE4AcABiAG0AZABJAGEAVwA1ADAATwBpAGQATwBiAHkAQgBoAFoA
>> "%~1" echo RwBJAHUAWgBYAGgAbABJAEcAOQB1AEkASABSAG8AYQBYAE0AZwBVAEUATQB1AEkA
>> "%~1" echo RgBsAHYAZABTAEIAagBZAFcANABnAFoARwA5ADMAYgBtAHgAdgBZAFcAUQBnAFIA
>> "%~1" echo MgA5AHYAWgAyAHgAbABJAEgAQgBzAFkAWABSAG0AYgAzAEoAdABMAFgAUgB2AGIA
>> "%~1" echo MgB4AHoASQBHAGwAdQBkAEcAOABnAGQARwBoAGwASQBIAFIAdgBiADIAdwBnAFoA
>> "%~1" echo bQA5AHMAWgBHAFYAeQBMAGkAYwBzAFkAVwBSAGkAUgBHADkAMwBiAG0AeAB2AFkA
>> "%~1" echo VwBRADYASgAwAFIAdgBkADIANQBzAGIAMgBGAGsASQBFAEYARQBRAGkAYwBzAGMA
>> "%~1" echo RwBGAG4AWgBVADkAMgBaAFgASgAyAGEAVwBWADMATwBsAHMAbgBUADMAWgBsAGMA
>> "%~1" echo bgBaAHAAWgBYAGMAbgBMAEMAZABUAGQARwBGADAAZABYAE0AZwBZAFcANQBrAEkA
>> "%~1" echo RwBSAGwAZABtAGwAagBaAFMAQgB6AGIAbQBGAHcAYwAyAGgAdgBkAEMAZABkAEwA
>> "%~1" echo SABCAGgAWgAyAFYARABiADIANQB6AGIAMgB4AGwATwBsAHMAbgBRADIAOQB1AGMA
>> "%~1" echo MgA5AHMAWgBTAGMAcwBKADAATgB2AGIAVwAxAHYAYgBpAEIAQgBSAEUASQBnAFkA
>> "%~1" echo VwBOADAAYQBXADkAdQBjAHkAZABkAEwASABCAGgAWgAyAFYAQgBjAEgAQgB6AE8A
>> "%~1" echo bABzAG4AUQBYAEIAdwBjAHkAYwBzAEoAMABsAHUAYwAzAFIAaABiAEcAeABsAFoA
>> "%~1" echo QwBCAGgAYwBIAEIAegBMAEMAQgBrAFoAWABSAGgAYQBXAHgAegBMAEMAQgBsAGUA
>> "%~1" echo SABSAHkAWQBXAE4AMABMAEMAQgAxAGIAbQBsAHUAYwAzAFIAaABiAEcAdwBuAFgA
>> "%~1" echo UwB4AHcAWQBXAGQAbABTAEcAVgBoAFoASABOAGwAZABEAHAAYgBKADAAaABsAFkA
>> "%~1" echo VwBSAHoAWgBYAFEAbgBMAEMAZABRAGIAMwBkAGwAYwBpAHcAZwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBTAHcAZwBZADIAOQB0AFoAbQA5AHkAZABDAHcAZwBZAFcAUgAyAFkA
>> "%~1" echo VwA1AGoAWgBXAFEAZwBkADMASgBwAGQARwBWAHoASgAxADAAcwBjAEcARgBuAFoA
>> "%~1" echo VQBSAGwAZABtAGwAagBaAFQAcABiAEoAMABSAGwAZABtAGwAagBaAFMAYwBzAEoA
>> "%~1" echo MQBOADUAYwAzAFIAbABiAFMAdwBnAFYAbQBsAHkAZABIAFYAaABiAEMAQgBFAFoA
>> "%~1" echo WABOAHIAZABHADkAdwBMAEMAQgBqAGIAMgA1ADAAYwBtADkAcwBiAEcAVgB5AGMA
>> "%~1" echo eQB3AGcAYwBHADkAMwBaAFgASQBuAFgAUwB4AHcAWQBXAGQAbABUAEcAOQBuAGMA
>> "%~1" echo egBwAGIASgAwAHgAdgBaADMATQBuAEwAQwBkAE0AWQBYAFIAbABjADMAUQBnAFkA
>> "%~1" echo MgA5AHQAYgBXAEYAdQBaAEMAQgB2AGQAWABSAHcAZABYAFEAbgBYAFMAeAAwAFkA
>> "%~1" echo VwBKAEoAYgBuAE4AMABZAFcAeABzAFoAVwBRADYASgAwAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AGwAWgBDAGMAcwBkAEcARgBpAFUAMgBsAGsAWgBXAHgAdgBZAFcAUQA2AEoA
>> "%~1" echo MABsAHUAYwAzAFIAaABiAEcAdwBnAFEAVgBCAEwASgB5AHgAegBZADIAOQB3AFoA
>> "%~1" echo VgBWAHoAWgBYAEkANgBKADEAVgB6AFoAWABJAG4ATABIAE4AagBiADMAQgBsAFEA
>> "%~1" echo VwB4AHMATwBpAGQAQgBiAEcAdwBuAEwASABOAGoAYgAzAEIAbABVADMAbAB6AGQA
>> "%~1" echo RwBWAHQATwBpAGQAVABlAFgATgAwAFoAVwAwAG4ATABHAFYANABkAEgASgBoAFkA
>> "%~1" echo MwBSAFAAYQB6AG8AbgBSAFgAaAAwAGMAbQBGAGoAZABHAFYAawBKAHkAeAAxAGIA
>> "%~1" echo bQBsAHUAYwAzAFIAaABiAEcAeABCAGMAMgBzADYASgAxAFIAbwBhAFgATQBnAGQA
>> "%~1" echo VwA1AHAAYgBuAE4AMABZAFcAeABzAGMAeQBCADAAYQBHAFUAZwBZAFgAQgB3AEkA
>> "%~1" echo RwBGAHUAWgBDAEIAawBaAFcAeABsAGQARwBWAHoASQBHAGwAMABjAHkAQgBrAFkA
>> "%~1" echo WABSAGgATABpAGMAcwBZADIAeABsAFkAWABKAEIAYwAyAHMANgBKADEAUgBvAGEA
>> "%~1" echo WABNAGcAWQAyAHgAbABZAFgASgB6AEkARwBGAHMAYgBDAEIAaABjAEgAQQBnAFoA
>> "%~1" echo RwBGADAAWQBTADQAbgBMAEcAUgBwAGMAMgBGAGkAYgBHAFYAQgBjADIAcwA2AEoA
>> "%~1" echo MQBSAG8AYQBYAE0AZwBaAEcAbAB6AFkAVwBKAHMAWgBYAE0AZwBkAEcAaABsAEkA
>> "%~1" echo RwBGAHcAYwBDADQAbgBmAFEAMABLAGYAVABzAE4AQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAFIAbABkAEcAVgBqAGQARQB4AGgAYgBtAGMAbwBLAFgAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAegBQAFcAeAB2AFkAMgBGAHMAVQAzAFIAdgBjAG0ARgBuAFoA
>> "%~1" echo UwA1AG4AWgBYAFIASgBkAEcAVgB0AEsAQwBkAHgAZABXAFYAegBkAEUARgBrAFkA
>> "%~1" echo awB4AGgAYgBtAGMAbgBLAFQAdABwAFoAaQBoAHoAUABUADAAOQBKADMAcABvAEoA
>> "%~1" echo MwB4ADgAYwB6ADAAOQBQAFMAZABsAGIAaQBjAHAAYwBtAFYAMABkAFgASgB1AEkA
>> "%~1" echo SABNADcAWQAyADkAdQBjADMAUQBnAGMAVAAwAG8AYgBHAEYAegBkAEMAWQBtAGIA
>> "%~1" echo RwBGAHoAZABDADUAeABkAFcAVgB6AGQARQB4AHYAWQAyAEYAcwBaAFgAeAA4AEoA
>> "%~1" echo eQBjAHAATABuAFIAdgBUAEcAOQAzAFoAWABKAEQAWQBYAE4AbABLAEMAawA3AGEA
>> "%~1" echo VwBZAG8AYwBTADUAcABiAG0AUgBsAGUARQA5AG0ASwBDAGQANgBhAEMAYwBwAFAA
>> "%~1" echo VAAwADkATQBDAGwAeQBaAFgAUgAxAGMAbQA0AGcASgAzAHAAbwBKAHoAdABwAFoA
>> "%~1" echo aQBoAEMAVAAwADkAVQBYADAAeABCAFQAawBjADkAUABUADAAbgBlAG0AZwBuAGYA
>> "%~1" echo SAB4AEMAVAAwADkAVQBYADAAeABCAFQAawBjADkAUABUADAAbgBaAFcANABuAEsA
>> "%~1" echo WABKAGwAZABIAFYAeQBiAGkAQgBDAFQAMAA5AFUAWAAwAHgAQgBUAGsAYwA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBiAGoAMABvAGIAbQBGADIAYQBXAGQAaABkAEcAOQB5AEwA
>> "%~1" echo bQB4AGgAYgBtAGQAMQBZAFcAZABsAGYASAB3AG4ASgB5AGsAdQBkAEcAOQBNAGIA
>> "%~1" echo MwBkAGwAYwBrAE4AaABjADIAVQBvAEsAVAB0AHkAWgBYAFIAMQBjAG0ANABnAGIA
>> "%~1" echo aQA1AHAAYgBtAFIAbABlAEUAOQBtAEsAQwBkADYAYQBDAGMAcABQAFQAMAA5AE0A
>> "%~1" echo RAA4AG4AZQBtAGcAbgBPAGkAZABsAGIAaQBkADkARABRAHAAcwBaAFgAUQBnAFQA
>> "%~1" echo RQBGAE8AUgB6ADEAawBaAFgAUgBsAFkAMwBSAE0AWQBXADUAbgBLAEMAawA3AEQA
>> "%~1" echo UQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCADAASwBHAHMAcABlADIATgB2AGIA
>> "%~1" echo bgBOADAASQBIAEIAaABZADIAcwA5AFMAVABFADQAVABsAHQATQBRAFUANQBIAFgA
>> "%~1" echo WAB4ADgAUwBUAEUANABUAGkANQA2AGEARAB0AHkAWgBYAFIAMQBjAG0ANABnAGMA
>> "%~1" echo RwBGAGoAYQAxAHQAcgBYAFMARQA5AGIAbgBWAHMAYgBEADkAdwBZAFcATgByAFcA
>> "%~1" echo MgB0AGQATwBpAGcAbwBTAFQARQA0AFQAaQA1ADYAYQBGAHQAcgBYAFMAbAA4AGYA
>> "%~1" echo RwBzAHAAZgBRADAASwBaAG4AVgB1AFkAMwBSAHAAYgAyADQAZwBZAFgAQgB3AGIA
>> "%~1" echo SABsAEoATQBUAGgAdQBLAEMAbAA3AFoARwA5AGoAZABXADEAbABiAG4AUQB1AGMA
>> "%~1" echo WABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBrAEYAcwBiAEMAZwBuAFcA
>> "%~1" echo MgBSAGgAZABHAEUAdABhAFQARQA0AGIAbAAwAG4ASwBTADUAbQBiADMASgBGAFkA
>> "%~1" echo VwBOAG8ASwBHAFYAcwBQAFQANQA3AFkAMgA5AHUAYwAzAFEAZwBhAHoAMQBsAGIA
>> "%~1" echo QwA1AG4AWgBYAFIAQgBkAEgAUgB5AGEAVwBKADEAZABHAFUAbwBKADIAUgBoAGQA
>> "%~1" echo RwBFAHQAYQBUAEUANABiAGkAYwBwAE8AMgBOAHYAYgBuAE4AMABJAEgAWQA5AGQA
>> "%~1" echo QwBoAHIASwBUAHQAcABaAGkAaABsAGIAQwA1ADAAWQBXAGQATwBZAFcAMQBsAFAA
>> "%~1" echo VAAwADkASgAwAGwATwBVAEYAVgBVAEoAeQBsAGwAYgBDADUAdwBiAEcARgBqAFoA
>> "%~1" echo VwBoAHYAYgBHAFIAbABjAGoAMQAyAE8AMgBWAHMAYwAyAFUAZwBaAFcAdwB1AGQA
>> "%~1" echo RwBWADQAZABFAE4AdgBiAG4AUgBsAGIAbgBRADkAZABuADAAcABPADIAbABtAEsA
>> "%~1" echo QwBRAG8ASgAyAHgAaABiAG0AZABDAGQARwA0AG4ASwBTAGsAawBLAEMAZABzAFkA
>> "%~1" echo VwA1AG4AUQBuAFIAdQBKAHkAawB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkAVABFAEYATwBSAHoAMAA5AFAAUwBkADYAYQBDAGMALwBKADAAVgBPAEoA
>> "%~1" echo egBvAG4ANQBMAGkAdAA1AHAAYQBIAEoAegB0AHAAWgBpAGcAawBLAEMAZAAwAFkA
>> "%~1" echo VwBKAEoAYgBuAE4AMABZAFcAeABzAFoAVwBRAG4ASwBTAGsAawBLAEMAZAAwAFkA
>> "%~1" echo VwBKAEoAYgBuAE4AMABZAFcAeABzAFoAVwBRAG4ASwBTADUAMABaAFgAaAAwAFEA
>> "%~1" echo MgA5AHUAZABHAFYAdQBkAEQAMQAwAEsAQwBkADAAWQBXAEoASgBiAG4ATgAwAFkA
>> "%~1" echo VwB4AHMAWgBXAFEAbgBLAFQAdABwAFoAaQBnAGsASwBDAGQAMABZAFcASgBUAGEA
>> "%~1" echo VwBSAGwAYgBHADkAaABaAEMAYwBwAEsAUwBRAG8ASgAzAFIAaABZAGwATgBwAFoA
>> "%~1" echo RwBWAHMAYgAyAEYAawBKAHkAawB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkAZABDAGcAbgBkAEcARgBpAFUAMgBsAGsAWgBXAHgAdgBZAFcAUQBuAEsA
>> "%~1" echo VAB0AHAAWgBpAGcAawBLAEMAZAB6AFkAMgA5AHcAWgBWAFYAegBaAFgASQBuAEsA
>> "%~1" echo UwBrAGsASwBDAGQAegBZADIAOQB3AFoAVgBWAHoAWgBYAEkAbgBLAFMANQAwAFoA
>> "%~1" echo WABoADAAUQAyADkAdQBkAEcAVgB1AGQARAAxADAASwBDAGQAegBZADIAOQB3AFoA
>> "%~1" echo VgBWAHoAWgBYAEkAbgBLAFQAdABwAFoAaQBnAGsASwBDAGQAegBZADIAOQB3AFoA
>> "%~1" echo VQBGAHMAYgBDAGMAcABLAFMAUQBvAEoAMwBOAGoAYgAzAEIAbABRAFcAeABzAEoA
>> "%~1" echo eQBrAHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBkAEMAZwBuAGMA
>> "%~1" echo MgBOAHYAYwBHAFYAQgBiAEcAdwBuAEsAVAB0AHAAWgBpAGcAawBLAEMAZAB6AFkA
>> "%~1" echo MgA5AHcAWgBWAE4ANQBjADMAUgBsAGIAUwBjAHAASwBTAFEAbwBKADMATgBqAGIA
>> "%~1" echo MwBCAGwAVQAzAGwAegBkAEcAVgB0AEoAeQBrAHUAZABHAFYANABkAEUATgB2AGIA
>> "%~1" echo bgBSAGwAYgBuAFEAOQBkAEMAZwBuAGMAMgBOAHYAYwBHAFYAVABlAFgATgAwAFoA
>> "%~1" echo VwAwAG4ASwBYADAATgBDAG0ATgB2AGIAbgBOADAASQBIAEIAaABaADIAVgB6AFAA
>> "%~1" echo WAB0AHYAZABtAFYAeQBkAG0AbABsAGQAegBvAG4AYwBHAEYAbgBaAFUAOQAyAFoA
>> "%~1" echo WABKADIAYQBXAFYAMwBKAHkAeABqAGIAMgA1AHoAYgAyAHgAbABPAGkAZAB3AFkA
>> "%~1" echo VwBkAGwAUQAyADkAdQBjADIAOQBzAFoAUwBjAHMAWQBYAEIAdwBjAHoAbwBuAGMA
>> "%~1" echo RwBGAG4AWgBVAEYAdwBjAEgATQBuAEwARwBoAGwAWQBXAFIAegBaAFgAUQA2AEoA
>> "%~1" echo MwBCAGgAWgAyAFYASQBaAFcARgBrAGMAMgBWADAASgB5AHgAawBaAFgAWgBwAFkA
>> "%~1" echo MgBVADYASgAzAEIAaABaADIAVgBFAFoAWABaAHAAWQAyAFUAbgBMAEcAeAB2AFoA
>> "%~1" echo MwBNADYASgAzAEIAaABaADIAVgBNAGIAMgBkAHoASgB5AHgAcABiAG4ATgAwAFkA
>> "%~1" echo VwB4AHMATwBpAGQAdwBZAFcAZABsAFEAWABCAHcAYwB5AGMAcwBjADIAVgAwAGQA
>> "%~1" echo RwBsAHUAWgAzAE0ANgBKADMAQgBoAFoAMgBWAEkAWgBXAEYAawBjADIAVgAwAEoA
>> "%~1" echo MwAwADcARABRAHAAagBiADIANQB6AGQAQwBCADAAYQBHAFYAdABaAFUAdABsAGUA
>> "%~1" echo VAAwAG4AYwBYAFYAbABjADMAUgBCAFoARwBKAFUAYQBHAFYAdABaAFYAWQAzAEoA
>> "%~1" echo egBzAE4AQwBtAE4AdgBiAG4ATgAwAEkARwBOAHYAYgBtAFoAcABjAG0AMQBVAFoA
>> "%~1" echo WABoADAAUABYAHMATgBDAGkAQQBnAFoARwBWAGkAZABXAGQAZgBiAFcAOQBrAFoA
>> "%~1" echo VABvAG4ANQBMAHkAYQA1AGIAeQBBADUAWgBDAHYANQBMACsAZAA1AG8AeQBCADUA
>> "%~1" echo WgBTAGsANgBZAGEAUwA0ADQAQwBCAFYAMgBrAHQAUgBtAGsAZwA1AEwAaQBOADUA
>> "%~1" echo TAB5AFIANQA1AHkAZwA0ADQAQwBCAE0AagBRAGcANQBiAEMAUAA1AHAAZQAyADUA
>> "%~1" echo YgBHAFAANQBiAG0AVgA1AFoASwBNAEkASABCAHkAYgAzAGgAZgBZADIAeAB2AGMA
>> "%~1" echo MgBYAHYAdgBJAHoAbABqADYAcgBsAHUANwByAG8AcgBxADcAbgBuADYAMwBtAGwA
>> "%~1" echo NwBiAHAAbAA3AFQAbwBzAEkAUABvAHIANQBYAGoAZwBJAEkAbgBMAEEAMABLAEkA
>> "%~1" echo QwBCAHIAWgBXAFYAdwBYADIARgAzAFkAVwB0AGwATwBpAGYAawB2AEoAcgBsAGgA
>> "%~1" echo cABuAGwAaABhAFgAawB2ADUAMwBtAGoASQBIAGwAbABLAFQAcABoAHAATABqAGcA
>> "%~1" echo SQBGAFgAYQBTADEARwBhAFMARABrAHUASQAzAGsAdgBKAEgAbgBuAEsARABqAGcA
>> "%~1" echo SQBFAHkATgBDAEQAbABzAEkALwBtAGwANwBiAGwAcwBZAC8AbAB1AFoAWABqAGcA
>> "%~1" echo SQBGAHoAYgBHAFYAbABjAEYAOQAwAGEAVwAxAGwAYgAzAFYAMABQAFMAMAB4ADcA
>> "%~1" echo NwB5AE0ANQBiAG0AMgA1AFkAKwBSADYAWQBDAEIASQBIAEIAeQBiADMAaABmAFkA
>> "%~1" echo MgB4AHYAYwAyAFgAagBnAEkASQBuAEwAQQAwAEsASQBDAEIAMwBhAFgASgBsAGIA
>> "%~1" echo RwBWAHoAYwB6AG8AbgA1AEwAeQBhADUAYgB5AEEANQBaAEMAdgBJAEQAVQAxAE4A
>> "%~1" echo VABVAGcANQBwAGUAZwA1ADcAcQAvAEkARQBGAEUAUQB1ACsAOABqAE8AVwBRAGoA
>> "%~1" echo TwBTADQAZwBPAFcAeABnAE8AVwBmAG4AKwBlADkAawBlAFcARwBoAGUAVwBQAHIA
>> "%~1" echo KwBpAEQAdgBlAGkAaQBxACsAaQAvAG4AdQBhAE8AcABlAE8AQQBnAHUAZQBVAHEA
>> "%~1" echo TwBXAHUAagBPAGkAdgB0ACsAVwBGAHMAKwBtAFgAcgBlAGEAWABvAE8AZQA2AHYA
>> "%~1" echo eQBCAEIAUgBFAEwAagBnAEkASQBuAEwAQQAwAEsASQBDAEIAMwBhAFgASgBsAGIA
>> "%~1" echo RwBWAHoAYwAxADkAdgBaAG0AWQA2AEoAKwBTADgAbQB1AGkAdQBxAFMAQgBoAFoA
>> "%~1" echo RwBKAGsASQBPAFcASQBoACsAVwBiAG4AaQBCAFYAVQAwAEwAdgB2AEoAdgBsAHAA
>> "%~1" echo bwBMAG0AbgBwAHoAbAB2AFoAUABsAGkAWQAzAHAAbgBhAEEAZwBWADIAawB0AFIA
>> "%~1" echo bQBrAGcANgBMACsAZQA1AG8ANgBsADcANwB5AE0ANQBwAGEAdAA1AGIAeQBBADUA
>> "%~1" echo YgBHAGUANQBMAHEATwA1AHEAMgBqADUAYgBpADQANQA0ADYAdwA2AEwARwBoADQA
>> "%~1" echo NABDAEMASgB5AHcATgBDAGkAQQBnAGMAMgBOAHkAWgBXAFYAdQBYAHoASQAwAGEA
>> "%~1" echo RABvAG4ANQBMAHkAYQA1AG8AcQBLADUAYgBHAFAANQBiAG0AVgA2AEwAYQBGADUA
>> "%~1" echo cABlADIANQBwAFMANQA1AEwAaQA2AEkARABJADAASQBPAFcAdwBqACsAYQBYAHQA
>> "%~1" echo dQArADgAagBPAFcAUAByACsAaQBEAHYAZQBXAHYAdgBPAGkASAB0AE8AVwBrAHQA
>> "%~1" echo TwBhAFkAdgB1AG0AVgB2ACsAYQBYAHQAdQBtAFgAdABPAFMANABqAGUAZQBHAGgA
>> "%~1" echo TwBXAHgAagArAE8AQQBnAGkAYwBzAEQAUQBvAGcASQBIAE4AMABZAFgAbABmAGQA
>> "%~1" echo WABOAGkAWAAyAEYAagBPAGkAZgBrAHYASgByAG8AcgBxAGsAZwBWAFYATgBDAEwA
>> "%~1" echo MABGAEQASQBPAGEAUABrAHUAZQBVAHQAZQBhAFgAdAB1AFMALwBuAGUAYQBNAGcA
>> "%~1" echo ZQBXAFUAcABPAG0ARwBrAHUATwBBAGcAaQBjAHMARABRAG8AZwBJAEgAQgB5AGIA
>> "%~1" echo MwBoAGYAWQAyAHgAdgBjADIAVQA2AEoAKwBTADgAbQB1AGEAbwBvAGUAYQBMAG4A
>> "%~1" echo KwBTADkAcQBlAGEASQB0AE8AbQBkAG8ATwBpAC8AawBlACsAOABqAE8AVwBQAHIA
>> "%~1" echo KwBpAEQAdgBlAG0AWQB1ACsAYQB0AG8AdQBpAEgAcQB1AFcASwBxAE8AZQBHAGgA
>> "%~1" echo TwBXAHgAagArAE8AQQBnAGkAYwBzAEQAUQBvAGcASQBIAEoAbABjADMAUgB2AGMA
>> "%~1" echo bQBWAGYAWQBtAEYAagBhADMAVgB3AE8AaQBmAGsAdgBKAHIAbQBpAG8AcgBwAHAA
>> "%~1" echo cABiAG0AcgBLAEgAbABoAHAAbgBsAGgAYQBYAGwAaQBZADMAbABwAEkAZgBrAHUA
>> "%~1" echo NwAzAGwAZwBMAHoAbQBnAGEATABsAHAASQAzAGwAbQA1ADQAZwBVAFgAVgBsAGMA
>> "%~1" echo MwBUAHYAdgBJAHoAbAB1AGIAYgBsAGoANQBIAHAAZwBJAEUAZwBjAEgASgB2AGUA
>> "%~1" echo RgA5AHYAYwBHAFYAdQA0ADQAQwBDAEoAeQB3AE4AQwBpAEEAZwBZADMAVgB6AGQA
>> "%~1" echo RwA5AHQAWAAzAE4AbABkAEgAUgBwAGIAbQBjADYASgArAFMAOABtAHUAZQBiAHQA
>> "%~1" echo TwBhAE8AcABlAFcARwBtAFMAQgBCAGIAbQBSAHkAYgAyAGwAawBJAEgATgBsAGQA
>> "%~1" echo SABSAHAAYgBtAGQAegA0ADQAQwBDADYAWgBTAFoANgBLACsAdgA2AFoAUwB1ADUA
>> "%~1" echo WQBDADgANQBZACsAdgA2AEkATwA5ADUAYgAyAHgANQBaAE8ATgA1AEwAeQBSADUA
>> "%~1" echo NQB5AGcANAA0AEMAQgA1ADcAMgBSADUANwB1AGMANQBvAGkAVwA2AEwAQwBEADYA
>> "%~1" echo SwArAFYANAA0AEMAQwBKAHkAdwBOAEMAaQBBAGcAWQAzAFYAegBkAEcAOQB0AFgA
>> "%~1" echo MgBKAHkAYgAyAEYAawBZADIARgB6AGQARABvAG4ANQBMAHkAYQA1AFkAKwBSADYA
>> "%~1" echo WQBDAEIANgBJAGUAcQA1AGEANgBhADUATABtAEoASQBFAEYAdQBaAEgASgB2AGEA
>> "%~1" echo VwBRAGcANQBiAG0ALwA1AHAASwB0ADcANwB5AE0ANQBZACsAcQA1AGIAdQA2ADYA
>> "%~1" echo SwA2AHUANQBMADIAZwA1AHAAaQBPADUANgBHAHUANQA1ACsAbAA2AFkARwBUAEkA
>> "%~1" echo RwBGAGoAZABHAGwAdgBiAGkARABsAGsASwB2AGsAdQBZAG4AbQBsADcAYgBrAHYA
>> "%~1" echo YgAvAG4AbABLAGoAagBnAEkASQBuAEwAQQAwAEsASQBDAEIAeABkAFcAVgB6AGQA
>> "%~1" echo RgA5AHcAZABYAFEANgBKACsAUwA4AG0AdQBXAEcAbQBlAFcARgBwAGUAVwBrAHQA
>> "%~1" echo TwBhAFkAdgB1AGkAdQB2AHUAZQA5AHIAdQBtAGQAbwB1AGEAZAB2ACsAUwA0AHIA
>> "%~1" echo ZQBlAGEAaABPAFcARgBnAGUAaQB1AHUATwBtAGgAdQBlAE8AQQBnAHUAbQBVAG0A
>> "%~1" echo ZQBpAHYAcgArAFcAQQB2AE8AVwBQAHIAKwBpAEQAdgBlAFcAOQBzAGUAVwBUAGoA
>> "%~1" echo ZQBTADgAawBlAGUAYwBvAE8AYQBJAGwAdQBhAFkAdgB1AGUAawB1AHUATwBBAGcA
>> "%~1" echo aQBjAE4AQwBuADAANwBEAFEAcABqAGIAMgA1AHoAZABDAEIAdwBZAFgASgBoAGIA
>> "%~1" echo VQBSAGwAWgBuAE0AOQBXAHcAMABLAEkAQwBCADcAYQAyAFYANQBPAGkAZAB6AGQA
>> "%~1" echo RwBGADUAVAAyADQAbgBMAEcANQBoAGIAVwBVADYASgArAFMALwBuAGUAYQBNAGcA
>> "%~1" echo ZQBXAFUAcABPAG0ARwBrAGkAYwBzAGMAMgBWADAAZABHAGwAdQBaAHoAbwBuAFoA
>> "%~1" echo MgB4AHYAWQBtAEYAcwBMAG4ATgAwAFkAWABsAGYAYgAyADUAZgBkADIAaABwAGIA
>> "%~1" echo RwBWAGYAYwBHAHgAMQBaADIAZABsAFoARgA5AHAAYgBpAGMAcwBjADIARgBtAFoA
>> "%~1" echo VABvAG4ATQBDAGMAcwBZAFcATgAwAGEAVwA5AHUATwBpAGQAeQBaAFgATgBsAGQA
>> "%~1" echo RgA5AHoAZABHAEYANQBYADIAOQB1AEoAeQB4AHUAYgAzAFIAbABPAGkAYwB3AFAA
>> "%~1" echo ZQBXAEYAZwBlAGkAdQB1AE8AYQB0AG8AKwBXADQAdQBPAFMAOABrAGUAZQBjAG8A
>> "%~1" echo TwArADgAbQB6AE0AOQBWAFYATgBDAEwAMABGAEQASQBPAGEAUABrAHUAZQBVAHQA
>> "%~1" echo ZQBTAC8AbgBlAGEATQBnAGUAVwBVAHAATwBtAEcAawBpAGQAOQBMAEEAMABLAEkA
>> "%~1" echo QwBCADcAYQAyAFYANQBPAGkAZAAzAGEAVwBaAHAAVQAyAHgAbABaAFgAQQBuAEwA
>> "%~1" echo RwA1AGgAYgBXAFUANgBKADEAZABwAEwAVQBaAHAASQBPAFMAOABrAGUAZQBjAG8A
>> "%~1" echo TwBlAHQAbAB1AGUAVgBwAFMAYwBzAGMAMgBWADAAZABHAGwAdQBaAHoAbwBuAFoA
>> "%~1" echo MgB4AHYAWQBtAEYAcwBMAG4AZABwAFoAbQBsAGYAYwAyAHgAbABaAFgAQgBmAGMA
>> "%~1" echo RwA5AHMAYQBXAE4ANQBKAHkAeAB6AFkAVwBaAGwATwBpAGMAeABKAHkAeABoAFkA
>> "%~1" echo MwBSAHAAYgAyADQANgBKADMASgBsAGMAMgBWADAAWAAzAGQAcABaAG0AbABmAGMA
>> "%~1" echo MgB4AGwAWgBYAEEAbgBMAEcANQB2AGQARwBVADYASgB6AEUAOQA1AEwAKwBkADUA
>> "%~1" echo YQA2AEkANgBiAHUAWQA2AEsANgBrADcANwB5AGIATQBqADMAbQBsADYAZgBuAGkA
>> "%~1" echo WQBqAG0AcwBMAGoAawB1AEkAMwBrAHYASgBIAG4AbgBLAEEAbgBmAFMAdwBOAEMA
>> "%~1" echo aQBBAGcAZQAyAHQAbABlAFQAbwBuAGMAMgBOAHkAWgBXAFYAdQBUADIAWgBtAEoA
>> "%~1" echo eQB4AHUAWQBXADEAbABPAGkAZgBsAHMAWQAvAGwAdQBaAFgAbwB0AG8AWABtAGwA
>> "%~1" echo NwBZAG4ATABIAE4AbABkAEgAUgBwAGIAbQBjADYASgAzAE4ANQBjADMAUgBsAGIA
>> "%~1" echo UwA1AHoAWQAzAEoAbABaAFcANQBmAGIAMgBaAG0AWAAzAFIAcABiAFcAVgB2AGQA
>> "%~1" echo WABRAG4ATABIAE4AaABaAG0AVQA2AEoAegBNAHcATQBEAEEAdwBNAEMAYwBzAFkA
>> "%~1" echo VwBOADAAYQBXADkAdQBPAGkAZAB5AFoAWABOAGwAZABGADkAegBZADMASgBsAFoA
>> "%~1" echo VwA1AGYAYgAyAFoAbQBKAHkAeAB1AGIAMwBSAGwATwBpAGYAbABqAFoAWABrAHYA
>> "%~1" echo WQAzAG0AcgA2AHYAbgBwADUATAB2AHYASgBzAHoATQBEAEEAdwBNAEQAQQA5AE4A
>> "%~1" echo UwBEAGwAaQBJAGIAcABrAHAALwB2AHYASQB3ADQATgBqAFEAdwBNAEQAQQB3AE0A
>> "%~1" echo RAAwAHkATgBDAEQAbABzAEkALwBtAGwANwBZAG4AZgBTAHcATgBDAGkAQQBnAGUA
>> "%~1" echo MgB0AGwAZQBUAG8AbgBjADIAeABsAFoAWABCAFUAYQBXADEAbABiADMAVgAwAEoA
>> "%~1" echo eQB4AHUAWQBXADEAbABPAGkAZgBuAHMANwB2AG4AdQA1AC8AbgBuAGEASABuAG4A
>> "%~1" echo SwBEAG8AdABvAFgAbQBsADcAWQBuAEwASABOAGwAZABIAFIAcABiAG0AYwA2AEoA
>> "%~1" echo MwBOAGwAWQAzAFYAeQBaAFMANQB6AGIARwBWAGwAYwBGADkAMABhAFcAMQBsAGIA
>> "%~1" echo MwBWADAASgB5AHgAegBZAFcAWgBsAE8AaQBkAHUAZABXAHgAcwBKAHkAeABoAFkA
>> "%~1" echo MwBSAHAAYgAyADQANgBKADMASgBsAGMAMgBWADAAWAAzAE4AcwBaAFcAVgB3AFgA
>> "%~1" echo MwBSAHAAYgBXAFYAdgBkAFgAUQBuAEwARwA1AHYAZABHAFUANgBKADIANQAxAGIA
>> "%~1" echo RwB3ADkANQA3AE8ANwA1ADcAdQBmADYAYgB1AFkANgBLADYAawA3ADcAeQBiAEwA
>> "%~1" echo VABFADkANQBMAGkATgA2AEkAZQBxADUAWQBxAG8ANQA1ADIAaAA1ADUAeQBnAEoA
>> "%~1" echo MwAwAE4AQwBsADAANwBEAFEAcABzAFoAWABRAGcAYgBHAEYAegBkAEQAMQA3AGYA
>> "%~1" echo UwB4AGkAZABYAE4ANQBQAFcAWgBoAGIASABOAGwATABIAEIAbABiAG0AUgBwAGIA
>> "%~1" echo bQBkAEQAYgAyADUAbQBhAFgASgB0AFAAVwA1ADEAYgBHAHcAcwBZAFgAQgByAFAA
>> "%~1" echo VwA1ADEAYgBHAHcANwBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgBsAGMA
>> "%~1" echo MgBNAG8AYwB5AGwANwBjAG0AVgAwAGQAWABKAHUASQBGAE4AMABjAG0AbAB1AFoA
>> "%~1" echo eQBoAHoAUAB6ADgAbgBKAHkAawB1AGMAbQBWAHcAYgBHAEYAagBaAFMAZwB2AFcA
>> "%~1" echo eQBZADgAUABpAEkAbgBYAFMAOQBuAEwARwBNADkAUABpAGgANwBKAHkAWQBuAE8A
>> "%~1" echo aQBjAG0AWQBXADEAdwBPAHkAYwBzAEoAegB3AG4ATwBpAGMAbQBiAEgAUQA3AEoA
>> "%~1" echo eQB3AG4AUABpAGMANgBKAHkAWgBuAGQARABzAG4ATABDAGMAaQBKAHoAbwBuAEoA
>> "%~1" echo bgBGADEAYgAzAFEANwBKAHkAdwBpAEoAeQBJADYASgB5AFkAagBNAHoAawA3AEoA
>> "%~1" echo MwAxAGIAWQAxADAAcABLAFgAMABOAEMAbQBaADEAYgBtAE4AMABhAFcAOQB1AEkA
>> "%~1" echo RwBWAHQAYwBIAFIANQBLAEgAWQBwAGUAMwBKAGwAZABIAFYAeQBiAGkAQgAyAFAA
>> "%~1" echo VAAwADkAZABXADUAawBaAFcAWgBwAGIAbQBWAGsAZgBIAHgAMgBQAFQAMAA5AGIA
>> "%~1" echo bgBWAHMAYgBIAHgAOABkAGoAMAA5AFAAUwBjAG4AZgBIAHgAMgBQAFQAMAA5AEoA
>> "%~1" echo MgA1ADEAYgBHAHcAbgBmAFEAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGMA
>> "%~1" echo MgBoAHYAZAAyADQAbwBkAGkAbAA3AGMAbQBWADAAZABYAEoAdQBJAEcAVgB0AGMA
>> "%~1" echo SABSADUASwBIAFkAcABQAHkAYwB0AEoAegBwAFQAZABIAEoAcABiAG0AYwBvAGQA
>> "%~1" echo aQBsADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAegBaAFgAUQBvAGEA
>> "%~1" echo VwBRAHMAZABpAGwANwBZADIAOQB1AGMAMwBRAGcAWgBUADAAawBLAEcAbABrAEsA
>> "%~1" echo VAB0AHAAWgBpAGgAbABLAFcAVQB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkAYwAyAGgAdgBkADIANABvAGQAaQBsADkARABRAHAAbQBkAFcANQBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEIAMgBLAEcAcwBwAGUAMwBKAGwAZABIAFYAeQBiAGkAQgB6AGEA
>> "%~1" echo RwA5ADMAYgBpAGgAcwBZAFgATgAwAFcAMgB0AGQASwBUAHQAOQBEAFEAcABtAGQA
>> "%~1" echo VwA1AGoAZABHAGwAdgBiAGkAQgB1AGIAMwBSAHAAWgBuAGsAbwBkAEcAbAAwAGIA
>> "%~1" echo RwBVAHMAYgBYAE4AbgBMAEgAUgA1AGMARwBVADkASgAyADkAcgBKAHkAeAB0AGMA
>> "%~1" echo egAwAHoATQBqAEEAdwBLAFgAdABqAGIAMgA1AHoAZABDAEIAbwBiADMATgAwAFAA
>> "%~1" echo UwBRAG8ASgAzAFIAdgBZAFgATgAwAGMAeQBjAHAATwAyAGwAbQBLAEMARgBvAGIA
>> "%~1" echo MwBOADAASwBYAEoAbABkAEgAVgB5AGIAagB0AGoAYgAyADUAegBkAEMAQgBsAGIA
>> "%~1" echo RAAxAGsAYgAyAE4AMQBiAFcAVgB1AGQAQwA1AGoAYwBtAFYAaABkAEcAVgBGAGIA
>> "%~1" echo RwBWAHQAWgBXADUAMABLAEMAZABrAGEAWABZAG4ASwBUAHQAbABiAEMANQBqAGIA
>> "%~1" echo RwBGAHoAYwAwADUAaABiAFcAVQA5AEoAMwBSAHYAWQBYAE4AMABJAEMAYwByAGQA
>> "%~1" echo SABsAHcAWgBUAHQAbABiAEMANQBwAGIAbQA1AGwAYwBrAGgAVQBUAFUAdwA5AEoA
>> "%~1" echo egB4AGkAUABpAGMAcgBaAFgATgBqAEsASABSAHAAZABHAHgAbABLAFMAcwBuAFAA
>> "%~1" echo QwA5AGkAUABqAHgAegBjAEcARgB1AFAAaQBjAHIAWgBYAE4AagBLAEcAMQB6AFoA
>> "%~1" echo MwB4ADgASgB5AGMAcABLAHkAYwA4AEwAMwBOAHcAWQBXADQAKwBKAHoAdABvAGIA
>> "%~1" echo MwBOADAATABtAEYAdwBjAEcAVgB1AFoARQBOAG8AYQBXAHgAawBLAEcAVgBzAEsA
>> "%~1" echo VAB0AHkAWgBYAEYAMQBaAFgATgAwAFEAVwA1AHAAYgBXAEYAMABhAFcAOQB1AFIA
>> "%~1" echo bgBKAGgAYgBXAFUAbwBLAEMAawA5AFAAbQBWAHMATABtAE4AcwBZAFgATgB6AFQA
>> "%~1" echo RwBsAHoAZABDADUAaABaAEcAUQBvAEoAMwBOAG8AYgAzAGMAbgBLAFMAawA3AGMA
>> "%~1" echo MgBWADAAVgBHAGwAdABaAFcAOQAxAGQAQwBnAG8ASwBUADAAKwBlADIAVgBzAEwA
>> "%~1" echo bQBOAHMAWQBYAE4AegBUAEcAbAB6AGQAQwA1AHkAWgBXADEAdgBkAG0AVQBvAEoA
>> "%~1" echo MwBOAG8AYgAzAGMAbgBLAFQAdAB6AFoAWABSAFUAYQBXADEAbABiADMAVgAwAEsA
>> "%~1" echo QwBnAHAAUABUADUAbABiAEMANQB5AFoAVwAxAHYAZABtAFUAbwBLAFMAdwB5AE0A
>> "%~1" echo agBBAHAAZgBTAHgAdABjAHkAbAA5AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIA
>> "%~1" echo aQBCAHoAYQBHADkAMwBRADIAOQB1AFoAbQBsAHkAYgBTAGgAaABZADMAUgBwAGIA
>> "%~1" echo MgA0AHMAYgBHAEYAaQBaAFcAdwBzAFoAWABoADAAYwBtAEUAOQBKAHkAYwBwAGUA
>> "%~1" echo MwBCAGwAYgBtAFIAcABiAG0AZABEAGIAMgA1AG0AYQBYAEoAdABQAFgAdABoAFkA
>> "%~1" echo MwBSAHAAYgAyADQAcwBiAEcARgBpAFoAVwB3AHMAWgBYAGgAMABjAG0ARgA5AE8A
>> "%~1" echo eQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMAbQAxAFUAYQBYAFIAcwBaAFMAYwBwAEwA
>> "%~1" echo bgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABTAGYAbgBvAGEANwBvAHIA
>> "%~1" echo cQBUAG0AaQBhAGYAbwBvAFkAegB2AHYASgBvAG4ASwAyAHgAaABZAG0AVgBzAE8A
>> "%~1" echo eQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMAbQAxAE4AYwAyAGMAbgBLAFMANQAwAFoA
>> "%~1" echo WABoADAAUQAyADkAdQBkAEcAVgB1AGQARAAxAGoAYgAyADUAbQBhAFgASgB0AFYA
>> "%~1" echo RwBWADQAZABGAHQAaABZADMAUgBwAGIAMgA1AGQAZgBIAHcAbgA2AEwAKwBaADUA
>> "%~1" echo TABpAHEANQBwAE8ATgA1AEwAMgBjADUATAB5AGEANQBMACsAdQA1AHAAUwA1AEkA
>> "%~1" echo RgBGADEAWgBYAE4AMABJAE8AZQBLAHQAdQBhAEEAZwBlAE8AQQBnAGkAYwA3AEoA
>> "%~1" echo QwBnAG4AWQAyADkAdQBaAG0AbAB5AGIAVQAxAGgAYwAyAHMAbgBLAFMANQBqAGIA
>> "%~1" echo RwBGAHoAYwAwAHgAcABjADMAUQB1AFkAVwBSAGsASwBDAGQAegBhAEcAOQAzAEoA
>> "%~1" echo eQBsADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAaABjADIAdABEAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABLAEgAUgBwAGQARwB4AGwATABHADEAegBaAHkAbAA3AGMA
>> "%~1" echo bQBWADAAZABYAEoAdQBJAEcANQBsAGQAeQBCAFEAYwBtADkAdABhAFgATgBsAEsA
>> "%~1" echo SABKAGwAYwB6ADAAKwBlADMAQgBsAGIAbQBSAHAAYgBtAGQARABiADIANQBtAGEA
>> "%~1" echo WABKAHQAUABYAHQAagBkAFgATgAwAGIAMgAwADYAZABIAEoAMQBaAFMAeAB5AFoA
>> "%~1" echo WABOAHYAYgBIAFoAbABPAG4ASgBsAGMAMwAwADcASgBDAGcAbgBZADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBWAFIAcABkAEcAeABsAEoAeQBrAHUAZABHAFYANABkAEUATgB2AGIA
>> "%~1" echo bgBSAGwAYgBuAFEAOQBkAEcAbAAwAGIARwBVADcASgBDAGcAbgBZADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBVADEAegBaAHkAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoA
>> "%~1" echo VwA1ADAAUABXADEAegBaAHoAcwBrAEsAQwBkAGoAYgAyADUAbQBhAFgASgB0AFQA
>> "%~1" echo VwBGAHoAYQB5AGMAcABMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMANQBoAFoA
>> "%~1" echo RwBRAG8ASgAzAE4AbwBiADMAYwBuAEsAWAAwAHAAZgBRADAASwBaAG4AVgB1AFkA
>> "%~1" echo MwBSAHAAYgAyADQAZwBZADIAeAB2AGMAMgBWAEQAYgAyADUAbQBhAFgASgB0AEsA
>> "%~1" echo QwBsADcAWQAyADkAdQBjADMAUQBnAGMARAAxAHcAWgBXADUAawBhAFcANQBuAFEA
>> "%~1" echo MgA5AHUAWgBtAGwAeQBiAFQAdAB3AFoAVwA1AGsAYQBXADUAbgBRADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBUADEAdQBkAFcAeABzAE8AeQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAxAE4AWQBYAE4AcgBKAHkAawB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwA
>> "%~1" echo bgBKAGwAYgBXADkAMgBaAFMAZwBuAGMAMgBoAHYAZAB5AGMAcABPADIAbABtAEsA
>> "%~1" echo SABBAG0ASgBuAEEAdQBZADMAVgB6AGQARwA5AHQASgBpAFoAdwBMAG4ASgBsAGMA
>> "%~1" echo MgA5AHMAZABtAFUAcABjAEMANQB5AFoAWABOAHYAYgBIAFoAbABLAEcAWgBoAGIA
>> "%~1" echo SABOAGwASwBYADAATgBDAG0AWgAxAGIAbQBOADAAYQBXADkAdQBJAEgAUgBvAFoA
>> "%~1" echo VwAxAGwASwBDAGwANwBZADIAOQB1AGMAMwBRAGcAYgBHAGwAbgBhAEgAUQA5AGIA
>> "%~1" echo RwA5AGoAWQBXAHgAVABkAEcAOQB5AFkAVwBkAGwATABtAGQAbABkAEUAbAAwAFoA
>> "%~1" echo VwAwAG8AZABHAGgAbABiAFcAVgBMAFoAWABrAHAAUABUADAAOQBKADIAeABwAFoA
>> "%~1" echo MgBoADAASgB6AHQAawBiADIATgAxAGIAVwBWAHUAZABDADUAaQBiADIAUgA1AEwA
>> "%~1" echo bQBOAHMAWQBYAE4AegBUAEcAbAB6AGQAQwA1ADAAYgAyAGQAbgBiAEcAVQBvAEoA
>> "%~1" echo MgBSAGgAYwBtAHMAbgBMAEMARgBzAGEAVwBkAG8AZABDAGsANwBKAEMAZwBuAGQA
>> "%~1" echo RwBoAGwAYgBXAFYAQwBkAEcANABuAEsAUwA1ADAAWgBYAGgAMABRADIAOQB1AGQA
>> "%~1" echo RwBWAHUAZABEADEAcwBhAFcAZABvAGQARAA4AG4ANQByAGUAeAA2AEkAbQB5AEoA
>> "%~1" echo egBvAG4ANQByAFcARgA2AEkAbQB5AEoAMwAwAE4AQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAHgAdgBaAHkAaAAwAEsAWAB0AHoAWgBYAFEAbwBKADIAeAB2AFoA
>> "%~1" echo MABKAHYAZQBDAGMAcwBiAG0AVgAzAEkARQBSAGgAZABHAFUAbwBLAFMANQAwAGIA
>> "%~1" echo MAB4AHYAWQAyAEYAcwBaAFYAUgBwAGIAVwBWAFQAZABIAEoAcABiAG0AYwBvAEsA
>> "%~1" echo UwBzAG4ASQBDAEEAbgBLADMAUQBwAGYAUQAwAEsAWgBuAFYAdQBZADMAUgBwAGIA
>> "%~1" echo MgA0AGcAYwAyAGgAdgBjAG4AUgBRAFkAWABSAG8ASwBIAEEAcABlADIAbABtAEsA
>> "%~1" echo QwBGAHcASwBYAEoAbABkAEgAVgB5AGIAaQBkAGgAWgBHAEkAdQBaAFgAaABsAEoA
>> "%~1" echo egB0AGoAYgAyADUAegBkAEMAQgBoAFAAVgBOADAAYwBtAGwAdQBaAHkAaAB3AEsA
>> "%~1" echo UwA1AHoAYwBHAHgAcABkAEMAZwB2AFcAMQB4AGMATAAxADAAdgBLAFQAdAB5AFoA
>> "%~1" echo WABSADEAYwBtADQAZwBZAFYAdABoAEwAbQB4AGwAYgBtAGQAMABhAEMAMAB4AFgA
>> "%~1" echo WAB4ADgAYwBIADAATgBDAG0AWgAxAGIAbQBOADAAYQBXADkAdQBJAEgAQgBqAGQA
>> "%~1" echo QwBoADQATABHADEAaABlAEQAMAB4AE0ARABBAHAAZQAyAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo RwA0ADkAYwBHAEYAeQBjADIAVgBHAGIARwA5AGgAZABDAGgANABLAFQAdAB5AFoA
>> "%~1" echo WABSADEAYwBtADQAZwBhAFgATgBHAGEAVwA1AHAAZABHAFUAbwBiAGkAawAvAFQA
>> "%~1" echo VwBGADAAYQBDADUAdABZAFgAZwBvAE0AQwB4AE4AWQBYAFIAbwBMAG0AMQBwAGIA
>> "%~1" echo aQBnAHgATQBEAEEAcwBiAGkAOQB0AFkAWABnAHEATQBUAEEAdwBLAFMAawA2AE0A
>> "%~1" echo SAAwAE4AQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAEoAcABiAG0AYwBvAGEA
>> "%~1" echo VwBRAHMAZABHAFYANABkAEMAeABzAFkAVwBKAGwAYgBDAHgAdwBaAFgASgBqAFoA
>> "%~1" echo VwA1ADAATABHAE4AcwBjAHkAbAA3AFkAMgA5AHUAYwAzAFEAZwBZAG0AOQA0AFAA
>> "%~1" echo UwBRAG8AYQBXAFEAcABPADIAbABtAEsAQwBGAGkAYgAzAGcAcABjAG0AVgAwAGQA
>> "%~1" echo WABKAHUATwAyAEoAdgBlAEMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AGMA
>> "%~1" echo bQBWAHQAYgAzAFoAbABLAEMAZABuAGMAbQBWAGwAYgBpAGMAcwBKADIARgB0AFkA
>> "%~1" echo bQBWAHkASgB5AHcAbgBjAG0AVgBrAEoAeQBrADcAYQBXAFkAbwBZADIAeAB6AEsA
>> "%~1" echo VwBKAHYAZQBDADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBZAFcAUgBrAEsA
>> "%~1" echo RwBOAHMAYwB5AGsANwBZADIAOQB1AGMAMwBRAGcAYgBXAFYAMABaAFgASQA5AFkA
>> "%~1" echo bQA5ADQATABuAEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMASQBvAEoA
>> "%~1" echo eQA1AHQAWgBYAFIAbABjAGkAYwBwAE8AMgBsAG0ASwBHADEAbABkAEcAVgB5AEsA
>> "%~1" echo VwAxAGwAZABHAFYAeQBMAG4ATgBsAGQARQBGADAAZABIAEoAcABZAG4AVgAwAFoA
>> "%~1" echo UwBnAG4AYwAzAFIAeQBiADIAdABsAEwAVwBSAGgAYwAyAGgAaABjAG4ASgBoAGUA
>> "%~1" echo UwBjAHMASwBIAEIAbABjAG0ATgBsAGIAbgBSADgAZgBEAEEAcABLAHkAYwBnAE0A
>> "%~1" echo VABBAHcASgB5AGsANwBhAFcAWQBvAGEAVwBRADkAUABUADAAbgBZAG0ARgAwAGQA
>> "%~1" echo RwBWAHkAZQBVAGQAaABkAFcAZABsAEoAeQBsADcAYwAyAFYAMABLAEMAZABpAFkA
>> "%~1" echo WABSADAAWgBYAEoANQBWAEcAVgA0AGQAQwBjAHMAZABHAFYANABkAEMAawA3AGMA
>> "%~1" echo MgBWADAASwBDAGQAaQBZAFgAUgAwAFoAWABKADUAVQAzAFYAaQBKAHkAeABzAFkA
>> "%~1" echo VwBKAGwAYgBDAGwAOQBhAFcAWQBvAGEAVwBRADkAUABUADAAbgBkAEcAVgB0AGMA
>> "%~1" echo RQBkAGgAZABXAGQAbABKAHkAbAA3AGMAMgBWADAASwBDAGQAMABaAFcAMQB3AFYA
>> "%~1" echo RwBWADQAZABDAGMAcwBkAEcAVgA0AGQAQwBrADcAYwAyAFYAMABLAEMAZAAwAFoA
>> "%~1" echo VwAxAHcAVQAzAFYAaQBKAHkAeABzAFkAVwBKAGwAYgBDAGwAOQBhAFcAWQBvAGEA
>> "%~1" echo VwBRADkAUABUADAAbgBjADIAeABsAFoAWABCAEgAWQBYAFYAbgBaAFMAYwBwAGUA
>> "%~1" echo MwBOAGwAZABDAGcAbgBjADIAeABsAFoAWABCAFUAWgBYAGgAMABKAHkAeAAwAFoA
>> "%~1" echo WABoADAASwBUAHQAegBaAFgAUQBvAEoAMwBOAHMAWgBXAFYAdwBVADMAVgBpAEoA
>> "%~1" echo eQB4AHMAWQBXAEoAbABiAEMAbAA5AGYAUQAwAEsAWgBuAFYAdQBZADMAUgBwAGIA
>> "%~1" echo MgA0AGcAYgBtADkAeQBiAFMAaAA0AEsAWAB0AHkAWgBYAFIAMQBjAG0ANABnAGMA
>> "%~1" echo MgBoAHYAZAAyADQAbwBlAEMAawB1AGQASABKAHAAYgBTAGcAcABmAFEAMABLAFoA
>> "%~1" echo bgBWAHUAWQAzAFIAcABiADIANABnAGEAWABOAFQAWQBXAFoAbABWAG0ARgBzAGQA
>> "%~1" echo VwBVAG8AWgBHAFYAbQBMAEgAWgBoAGIASABWAGwASwBYAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCADIAWQBXAHcAOQBiAG0AOQB5AGIAUwBoADIAWQBXAHgAMQBaAFMAawA3AGEA
>> "%~1" echo VwBZAG8AWgBHAFYAbQBMAG4ATgBoAFoAbQBVADkAUABUADAAbgBiAG4AVgBzAGIA
>> "%~1" echo QwBjAHAAYwBtAFYAMABkAFgASgB1AEkASABaAGgAYgBEADAAOQBQAFMAZAB1AGQA
>> "%~1" echo VwB4AHMASgAzAHgAOABkAG0ARgBzAFAAVAAwADkASgB5ADAAbgBPADMASgBsAGQA
>> "%~1" echo SABWAHkAYgBpAEIAMgBZAFcAdwA5AFAAVAAxAGsAWgBXAFkAdQBjADIARgBtAFoA
>> "%~1" echo WAAwAE4AQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAEoAbABiAG0AUgBsAGMA
>> "%~1" echo bABCAGgAYwBtAEYAdABjAHkAZwBwAGUAMgBOAHYAYgBuAE4AMABJAEcAaAB2AGMA
>> "%~1" echo MwBRADkASgBDAGcAbgBjAEcARgB5AFkAVwAxAE0AYQBYAE4AMABKAHkAawA3AGEA
>> "%~1" echo VwBZAG8ASQBXAGgAdgBjADMAUQBwAGMAbQBWADAAZABYAEoAdQBPADIAaAB2AGMA
>> "%~1" echo MwBRAHUAYQBXADUAdQBaAFgASgBJAFYARQAxAE0AUABTAGMAbgBPADIAeABsAGQA
>> "%~1" echo QwBCAGoAYQBHAEYAdQBaADIAVgBrAFAAVABBADcAWQAyADkAdQBjADMAUQBnAGIA
>> "%~1" echo MgBaAG0AYgBHAGwAdQBaAFQAMQBzAFkAWABOADAATABtAE4AdgBiAG0ANQBsAFkA
>> "%~1" echo MwBSAGwAWgBDAEUAOQBQAFMAZAAwAGMAbgBWAGwASgB6AHQAdwBZAFgASgBoAGIA
>> "%~1" echo VQBSAGwAWgBuAE0AdQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAawBaAFcAWQA5AFAA
>> "%~1" echo bgB0AGoAYgAyADUAegBkAEMAQgAyAFkAVwB3ADkAYgBtADkAeQBiAFMAaABzAFkA
>> "%~1" echo WABOADAAVwAyAFIAbABaAGkANQByAFoAWABsAGQASwBUAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAHYAYQB6ADAAaABiADIAWgBtAGIARwBsAHUAWgBTAFkAbQBhAFgATgBUAFkA
>> "%~1" echo VwBaAGwAVgBtAEYAcwBkAFcAVQBvAFoARwBWAG0ATABIAFoAaABiAEMAawA3AGEA
>> "%~1" echo VwBZAG8ASQBXADkAcgBKAGkAWQBoAGIAMgBaAG0AYgBHAGwAdQBaAFMAbABqAGEA
>> "%~1" echo RwBGAHUAWgAyAFYAawBLAHkAcwA3AFkAMgA5AHUAYwAzAFEAZwBhAFgAUgBsAGIA
>> "%~1" echo VAAxAGsAYgAyAE4AMQBiAFcAVgB1AGQAQwA1AGoAYwBtAFYAaABkAEcAVgBGAGIA
>> "%~1" echo RwBWAHQAWgBXADUAMABLAEMAZABrAGEAWABZAG4ASwBUAHQAcABkAEcAVgB0AEwA
>> "%~1" echo bQBOAHMAWQBYAE4AegBUAG0ARgB0AFoAVAAwAG4AYwBHAEYAeQBZAFcAMQBKAGQA
>> "%~1" echo RwBWAHQASQBDAGMAcgBLAEcAOQBtAFoAbQB4AHAAYgBtAFUALwBKAHkAYwA2AGIA
>> "%~1" echo MgBzAC8ASgAyADkAcgBKAHoAbwBuAFkAMgBoAGgAYgBtAGQAbABaAEMAYwBwAE8A
>> "%~1" echo MgBOAHYAYgBuAE4AMABJAEgATgAwAFkAWABSAGwAUABXADkAbQBaAG0AeABwAGIA
>> "%~1" echo bQBVAC8ASgArAGEAYwBxAHUAaQB2AHUAKwBXAFAAbABpAGMANgBLAEcAOQByAFAA
>> "%~1" echo eQBmAHAAdQA1AGoAbwByAHEAVABsAGcATAB3AG4ATwBpAGYAbAB0ADcATABrAHYA
>> "%~1" echo NgA3AG0AbABMAGsAbgBLAFQAdABwAGQARwBWAHQATABtAGwAdQBiAG0AVgB5AFMA
>> "%~1" echo RgBSAE4AVABEADAAbgBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
>> "%~1" echo RwBGAHkAWQBXADEATwBZAFcAMQBsAEkAagA0ADgAWQBqADQAbgBLADIAVgB6AFkA
>> "%~1" echo eQBoAGsAWgBXAFkAdQBiAG0ARgB0AFoAUwBrAHIASgB6AHcAdgBZAGoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBqADQAbgBLADIAVgB6AFkAeQBoAGsAWgBXAFkAdQBjADIAVgAwAGQA
>> "%~1" echo RwBsAHUAWgB5AGsAcgBKAHoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdwBZAFgASgBoAGIA
>> "%~1" echo VgBaAGgAYgBIAFYAbABJAGoANAA4AGMAMwBCAGgAYgBqADcAbAB2AFoAUABsAGkA
>> "%~1" echo WQAzAGwAZwBMAHcAOABMADMATgB3AFkAVwA0ACsAUABHAEkAKwBKAHkAdABsAGMA
>> "%~1" echo MgBNAG8AZABtAEYAcwBLAFMAcwBuAFAAQwA5AGkAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABjAG0ARgB0AFYA
>> "%~1" echo bQBGAHMAZABXAFUAaQBQAGoAeAB6AGMARwBGAHUAUAB1AG0ANwBtAE8AaQB1AHAA
>> "%~1" echo TwBXAEEAdgBEAHcAdgBjADMAQgBoAGIAagA0ADgAWQBqADQAbgBLADIAVgB6AFkA
>> "%~1" echo eQBoAGsAWgBXAFkAdQBjADIARgBtAFoAUwBrAHIASgB6AHcAdgBZAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABaAEcAbAAyAFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAdwBZAFgASgBoAGIAVgBOADAAWQBYAFIAbABJAGoANABuAEsA
>> "%~1" echo MgBWAHoAWQB5AGgAegBkAEcARgAwAFoAUwBrAHIASgB6AHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0AGcASgB5AHMAbwBJAFcAOQBtAFoAbQB4AHAAYgBtAFUAbQBKAGkARgB2AGEA
>> "%~1" echo egA4AG4AUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
>> "%~1" echo bQBWAHoAWgBYAFIAQwBkAEcANABnAGMASABKAHAAYgBXAEYAeQBlAFMASQBnAFoA
>> "%~1" echo RwBGADAAWQBTADEAeQBaAFgATgBsAGQARAAwAGkASgB5AHQAbABjADIATQBvAFoA
>> "%~1" echo RwBWAG0ATABtAEYAagBkAEcAbAB2AGIAaQBrAHIASgB5AEkAKwA2AFkAZQBOADUA
>> "%~1" echo NwAyAHUAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsASgB6AG8AbgBKAHkAawByAEoA
>> "%~1" echo egB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bgBCAGgAYwBtAEYAdABUAG0ARgB0AFoAUwBJAGcAYwAzAFIANQBiAEcAVQA5AEkA
>> "%~1" echo bQBkAHkAYQBXAFEAdABZADIAOQBzAGQAVwAxAHUATwBqAEUAdgBMAFQARQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBQAGkAYwByAFoAWABOAGoASwBHAFIAbABaAGkANQB1AGIA
>> "%~1" echo MwBSAGwASwBTAHMAbgBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo aQBjADcAYQBHADkAegBkAEMANQBoAGMASABCAGwAYgBtAFIARABhAEcAbABzAFoA
>> "%~1" echo QwBoAHAAZABHAFYAdABLAFgAMABwAE8AMwBOAGwAZABDAGcAbgBjAEcARgB5AFkA
>> "%~1" echo VwAxAFQAZABXADEAdABZAFgASgA1AEoAeQB4AHYAWgBtAFoAcwBhAFcANQBsAFAA
>> "%~1" echo eQBmAG0AbgBLAHIAbwB2ADUANwBtAGoAcQBVAG4ATwBtAE4AbwBZAFcANQBuAFoA
>> "%~1" echo VwBRAC8AWQAyAGgAaABiAG0AZABsAFoAQwBzAG4ASQBPAG0AaAB1AGUAVwAzAHMA
>> "%~1" echo dQBTAC8AcgB1AGEAVQB1AFMAYwA2AEoAKwBXAEYAcQBPAG0ARABxAE8AbQA3AG0A
>> "%~1" echo TwBpAHUAcABDAGMAcABPADIAaAB2AGMAMwBRAHUAYwBYAFYAbABjAG4AbABUAFoA
>> "%~1" echo VwB4AGwAWQAzAFIAdgBjAGsARgBzAGIAQwBnAG4AVwAyAFIAaABkAEcARQB0AGMA
>> "%~1" echo bQBWAHoAWgBYAFIAZABKAHkAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMAaABpAGQA
>> "%~1" echo RwA0ADkAUABtAEoAMABiAGkANQB2AGIAbQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAA
>> "%~1" echo VAA1AGgAWQAzAFIAcABiADIANABvAFkAbgBSAHUATABtAFIAaABkAEcARgB6AFoA
>> "%~1" echo WABRAHUAYwBtAFYAegBaAFgAUQBzAEoAeQBjAHMASgArAG0ASABqAGUAZQA5AHIA
>> "%~1" echo dQBXAFAAZwB1AGEAVgBzAEMAYwBzAFkAbgBSAHUATABHAFoAaABiAEgATgBsAEsA
>> "%~1" echo UwBsADkARABRAHAAaABjADMAbAB1AFkAeQBCAG0AZABXADUAagBkAEcAbAB2AGIA
>> "%~1" echo aQBCAGgAYwBHAGsAbwBjAEcARgAwAGEAQwB4AHYAYwBIAFIAegBQAFgAdAA5AEsA
>> "%~1" echo WAB0AGoAYgAyADUAegBkAEMAQgB2AFAAVQA5AGkAYQBtAFYAagBkAEMANQBoAGMA
>> "%~1" echo MwBOAHAAWgAyADQAbwBlADIATgBoAFkAMgBoAGwATwBpAGQAdQBiAHkAMQB6AGQA
>> "%~1" echo RwA5AHkAWgBTAGQAOQBMAEcAOQB3AGQASABNAHAATwAyADgAdQBhAEcAVgBoAFoA
>> "%~1" echo RwBWAHkAYwB6ADEAUABZAG0AcABsAFkAMwBRAHUAWQBYAE4AegBhAFcAZAB1AEsA
>> "%~1" echo SABzAG4AVwBDADEAUgBkAFcAVgB6AGQAQwAxAFUAYgAyAHQAbABiAGkAYwA2AFYA
>> "%~1" echo RQA5AEwAUgBVADQAcwBKADEAZwB0AFUAWABWAGwAYwAzAFEAdABUAEcARgB1AFoA
>> "%~1" echo eQBjADYAVABFAEYATwBSADMAMABzAGIAMwBCADAAYwB5ADUAbwBaAFcARgBrAFoA
>> "%~1" echo WABKAHoAZgBIAHgANwBmAFMAawA3AFkAMgA5AHUAYwAzAFEAZwBjAGoAMQBoAGQA
>> "%~1" echo MgBGAHAAZABDAEIAbQBaAFgAUgBqAGEAQwBoAHcAWQBYAFIAbwBMAEcAOABwAE8A
>> "%~1" echo MgBsAG0ASwBDAEYAeQBMAG0AOQByAEsAWABSAG8AYwBtADkAMwBJAEcANQBsAGQA
>> "%~1" echo eQBCAEYAYwBuAEoAdgBjAGkAZwBuAFMARgBSAFUAVQBDAEEAbgBLADMASQB1AGMA
>> "%~1" echo MwBSAGgAZABIAFYAegBLAFQAdAB5AFoAWABSADEAYwBtADQAZwBZAFgAZABoAGEA
>> "%~1" echo WABRAGcAYwBpADUAcQBjADIAOQB1AEsAQwBsADkARABRAHAAaABjADMAbAB1AFkA
>> "%~1" echo eQBCAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHMAYgAyAEYAawBUAEcAOQBuAGMA
>> "%~1" echo eQBoAHoAYQBHADkAMwBUAG0AOQAwAGEAVwBOAGwAUABXAFoAaABiAEgATgBsAEsA
>> "%~1" echo WAB0ADAAYwBuAGwANwBZADIAOQB1AGMAMwBRAGcAYwBqADEAaABkADIARgBwAGQA
>> "%~1" echo QwBCAGgAYwBHAGsAbwBKAHkAOQBoAGMARwBrAHYAYgBHADkAbgBjAHkAYwBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBiAEcAOQBuAFUARwBGADAAYQBDAGMAcwBjAGkANQBzAGIA
>> "%~1" echo MgBkAEcAYQBXAHgAbABLAFQAdAB6AFoAWABRAG8ASgAyAHgAdgBaADAASgB2AGUA
>> "%~1" echo QwBjAHMAYwBpADUAMABaAFgAaAAwAGYASAB3AG4ANQBwAHEAQwA1AHAAZQBnADUA
>> "%~1" echo cABlAGwANQBiACsAWABKAHkAawA3AGEAVwBZAG8AYwAyAGgAdgBkADAANQB2AGQA
>> "%~1" echo RwBsAGoAWgBTAGwAdQBiADMAUgBwAFoAbgBrAG8ASgArAGEAWABwAGUAVwAvAGwA
>> "%~1" echo KwBXADMAcwB1AFcASQB0ACsAYQBXAHMAQwBjAHMAYwBpADUAcwBiADIAZABHAGEA
>> "%~1" echo VwB4AGwAZgBIAHcAbgBMAFMAYwBzAEoAMgA5AHIASgB5AGwAOQBZADIARgAwAFkA
>> "%~1" echo MgBnAG8AWgBTAGwANwBjADIAVgAwAEsAQwBkAHMAYgAyAGQAQwBiADMAZwBuAEwA
>> "%~1" echo QwBmAG0AbAA2AFgAbAB2ADUAZgBvAHIANwB2AGwAagA1AGIAbABwAEwASABvAHQA
>> "%~1" echo SwBYAHYAdgBKAG8AbgBLADIAVQB1AGIAVwBWAHoAYwAyAEYAbgBaAFMAawA3AGEA
>> "%~1" echo VwBZAG8AYwAyAGgAdgBkADAANQB2AGQARwBsAGoAWgBTAGwAdQBiADMAUgBwAFoA
>> "%~1" echo bgBrAG8ASgArAGEAWABwAGUAVwAvAGwAKwBpAHYAdQArAFcAUABsAHUAVwBrAHMA
>> "%~1" echo ZQBpADAAcABTAGMAcwBaAFMANQB0AFoAWABOAHoAWQBXAGQAbABMAEMAZABsAGMA
>> "%~1" echo bgBJAG4ATABEAFEAeQBNAEQAQQBwAGYAWAAwAE4AQwBtAEYAegBlAFcANQBqAEkA
>> "%~1" echo RwBaADEAYgBtAE4AMABhAFcAOQB1AEkASABKAGwAWgBuAEoAbABjADIAZwBvAGMA
>> "%~1" echo MgBoAHYAZAAwADUAdgBkAEcAbABqAFoAVAAxAG0AWQBXAHgAegBaAFMAbAA3AGQA
>> "%~1" echo SABKADUAZQAyAHgAaABjADMAUQA5AFkAWABkAGgAYQBYAFEAZwBZAFgAQgBwAEsA
>> "%~1" echo QwBjAHYAWQBYAEIAcABMADMATgAwAFkAWABSADEAYwB5AGMAcABPADIATgB2AGIA
>> "%~1" echo bgBOADAASQBHAE0AOQBiAEcARgB6AGQAQwA1AGoAYgAyADUAdQBaAFcATgAwAFoA
>> "%~1" echo VwBRADkAUABUADAAbgBkAEgASgAxAFoAUwBjADcASgBDAGcAbgBjADMAUgBoAGQA
>> "%~1" echo SABWAHoAUQAyAGgAcABjAEMAYwBwAEwAbQBOAHMAWQBYAE4AegBUAEcAbAB6AGQA
>> "%~1" echo QwA1ADAAYgAyAGQAbgBiAEcAVQBvAEoAMgBOAHYAYgBtADUAbABZADMAUgBsAFoA
>> "%~1" echo QwBjAHMAWQB5AGsANwBKAEMAZwBuAGMAMwBSAGgAZABIAFYAegBRADIAaABwAGMA
>> "%~1" echo QwBjAHAATABuAEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMASQBvAEoA
>> "%~1" echo MwBOAHcAWQBXADQAbgBLAFMANQAwAFoAWABoADAAUQAyADkAdQBkAEcAVgB1AGQA
>> "%~1" echo RAAxAGoAUAB5AGYAbAB0ADcATABvAHYANQA3AG0AagBxAFUAbgBPAGkAaABzAFkA
>> "%~1" echo WABOADAATABtAFIAbABkAG0AbABqAFoAVgBOADAAWQBYAFIAbABQAFQAMAA5AEoA
>> "%~1" echo MwBWAHUAWQBYAFYAMABhAEcAOQB5AGEAWABwAGwAWgBDAGMALwBKACsAYQBjAHEA
>> "%~1" echo dQBhAE8AaQBPAGEAZABnAHkAYwA2AGIARwBGAHoAZABDADUAawBaAFgAWgBwAFkA
>> "%~1" echo MgBWAFQAZABHAEYAMABaAFQAMAA5AFAAUwBkAHYAWgBtAFoAcwBhAFcANQBsAEoA
>> "%~1" echo egA4AG4ANQA2AGEANwA1ADcAcQAvAEoAegBvAG4ANQBwAHkAcQA2AEwAKwBlADUA
>> "%~1" echo bwA2AGwASgB5AGsANwBjADIAVgAwAEsAQwBkAHoAZABHAEYAMABaAFUASgBwAFoA
>> "%~1" echo eQBjAHMAYgBHAEYAegBkAEMANQBrAFoAWABaAHAAWQAyAFYAVABkAEcARgAwAFoA
>> "%~1" echo WAB4ADgASgAyADUAdgBiAG0AVQBuAEsAVABzAGsASwBDAGQAegBkAEcARgAwAFoA
>> "%~1" echo VQBKAHAAWgB5AGMAcABMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMANQAwAGIA
>> "%~1" echo MgBkAG4AYgBHAFUAbwBKADIAZAB2AGIAMgBRAG4ATABHAE0AcABPADMATgBsAGQA
>> "%~1" echo QwBnAG4AYwAzAFIAaABkAEcAVgBJAGEAVwA1ADAASgB5AHgAcwBZAFgATgAwAEwA
>> "%~1" echo bQBoAHAAYgBuAFEAcABPADMATgBsAGQAQwBnAG4AYQBHAFYAeQBiADAAMQB2AFoA
>> "%~1" echo RwBWAHMASgB5AHgAcwBZAFgATgAwAEwAbQAxAHYAWgBHAFYAcwBKAGkAWgBzAFkA
>> "%~1" echo WABOADAATABtADEAdgBaAEcAVgBzAEkAVAAwADkASgB5ADAAbgBQADIAeABoAGMA
>> "%~1" echo MwBRAHUAYgBXADkAawBaAFcAdwA2AEoAMQBGADEAWgBYAE4AMABKAHkAawA3AGMA
>> "%~1" echo MgBWADAASwBDAGQAawBaAFgAWgBwAFkAMgBWAFUAWQBXAGMAbgBMAEcAeABoAGMA
>> "%~1" echo MwBRAHUAWgBHAFYAMgBhAFcATgBsAFUAMwBSAGgAZABHAFYAOABmAEMAZAB1AGIA
>> "%~1" echo MgA1AGwASgB5AGsANwBjADIAVgAwAEsAQwBkAGgAWgBHAEoAVABhAEcAOQB5AGQA
>> "%~1" echo QwBjAHMAYwAyAGgAdgBjAG4AUgBRAFkAWABSAG8ASwBHAHgAaABjADMAUQB1AFkA
>> "%~1" echo VwBSAGkAVQBHAEYAMABhAEMAawBwAE8AMwBOAGwAZABDAGcAbgBkADIAbABtAGEA
>> "%~1" echo VQBOAG8AYQBYAEEAbgBMAEgAWQBvAEoAMwBkAHAAWgBtAGwASgBjAEMAYwBwAEsA
>> "%~1" echo VAB0AHoAWgBYAFEAbwBKADMAZABwAFoAbQBsAEoAYwBFAHgAcABkAEcAVQBuAEwA
>> "%~1" echo SABZAG8ASgAzAGQAcABaAG0AbABKAGMAQwBjAHAASwBUAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgB4AGwAWgBuAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoA
>> "%~1" echo UwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGsAeABsAFoA
>> "%~1" echo bgBSAEMAWQBYAFIAMABaAFgASgA1AEoAeQBrAHAATwAzAE4AbABkAEMAZwBuAGMA
>> "%~1" echo bQBsAG4AYQBIAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoA
>> "%~1" echo UwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGwASgBwAFoA
>> "%~1" echo MgBoADAAUQBtAEYAMABkAEcAVgB5AGUAUwBjAHAASwBUAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgB4AGwAWgBuAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBVADMAUgBoAGQA
>> "%~1" echo RwBVAG4ATABIAFkAbwBKADIATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBNAFoA
>> "%~1" echo VwBaADAAVQAzAFIAaABkAEgAVgB6AEoAeQBrAHAATwAzAE4AbABkAEMAZwBuAGMA
>> "%~1" echo bQBsAG4AYQBIAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBVADMAUgBoAGQA
>> "%~1" echo RwBVAG4ATABIAFkAbwBKADIATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBTAGEA
>> "%~1" echo VwBkAG8AZABGAE4AMABZAFgAUgAxAGMAeQBjAHAASwBUAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgBOAHMAYgAyAE4AcgBWAEcAVgA0AGQAQwBjAHMAYgBtAFYAMwBJAEUAUgBoAGQA
>> "%~1" echo RwBVAG8ASwBTADUAMABiADAAeAB2AFkAMgBGAHMAWgBWAFIAcABiAFcAVgBUAGQA
>> "%~1" echo SABKAHAAYgBtAGMAbwBLAFMAawA3AFkAMgA5AHUAYwAzAFEAZwBZAGoAMQAyAEsA
>> "%~1" echo QwBkAGkAWQBYAFIAMABaAFgASgA1AFQARwBWADIAWgBXAHcAbgBLAFMAeAAwAFAA
>> "%~1" echo WABZAG8ASgAyAEoAaABkAEgAUgBsAGMAbgBsAFUAWgBXADEAdwBKAHkAawBzAGQA
>> "%~1" echo egAxADIASwBDAGQAMwBZAFcAdABsAFoAbgBWAHMAYgBtAFYAegBjAHkAYwBwAEwA
>> "%~1" echo RwBKAHUAUABYAEIAaABjAG4ATgBsAFIAbQB4AHYAWQBYAFEAbwBZAGkAawBzAGQA
>> "%~1" echo RwA0ADkAYwBHAEYAeQBjADIAVgBHAGIARwA5AGgAZABDAGgAMABLAFQAdAB5AGEA
>> "%~1" echo VwA1AG4ASwBDAGQAaQBZAFgAUgAwAFoAWABKADUAUgAyAEYAMQBaADIAVQBuAEwA
>> "%~1" echo RwBJADkAUABUADAAbgBMAFMAYwAvAEoAeQAwAHQASgBTAGMANgBZAGkAcwBuAEoA
>> "%~1" echo UwBjAHMASgArAGUAVQB0AGUAbQBIAGoAeQBjAHMAYwBHAE4AMABLAEcASQBwAEwA
>> "%~1" echo QwBGAHAAYwAwAFoAcABiAG0AbAAwAFoAUwBoAGkAYgBpAGsALwBKAHkAYwA2AFkA
>> "%~1" echo bQA0ADgATQBqAEEALwBKADMASgBsAFoAQwBjADYAWQBtADQAOABOAEQAVQAvAEoA
>> "%~1" echo MgBGAHQAWQBtAFYAeQBKAHoAbwBuAFoAMwBKAGwAWgBXADQAbgBLAFQAdAB5AGEA
>> "%~1" echo VwA1AG4ASwBDAGQAMABaAFcAMQB3AFIAMgBGADEAWgAyAFUAbgBMAEgAUQA5AFAA
>> "%~1" echo VAAwAG4ATABTAGMALwBKAHkAMAB0AHcAcgBCAEQASgB6AHAAMABLAHkAZgBDAHMA
>> "%~1" echo RQBNAG4ATABDAGYAbQB1AEsAbgBsAHUAcQBZAG4ATABIAEIAagBkAEMAaAAwAEwA
>> "%~1" echo RABVADEASwBTAHcAaABhAFgATgBHAGEAVwA1AHAAZABHAFUAbwBkAEcANABwAFAA
>> "%~1" echo eQBjAG4ATwBuAFIAdQBQAGoAMAAwAE4AVAA4AG4AYwBtAFYAawBKAHoAcAAwAGIA
>> "%~1" echo agA0ADkATQB6AGcALwBKADIARgB0AFkAbQBWAHkASgB6AG8AbgBaADMASgBsAFoA
>> "%~1" echo VwA0AG4ASwBUAHQAagBiADIANQB6AGQAQwBCAGgAZAAyAEYAcgBaAFQAMABvAGQA
>> "%~1" echo MwB4ADgASgB5AGMAcABMAG4AUgB2AFQARwA5ADMAWgBYAEoARABZAFgATgBsAEsA
>> "%~1" echo QwBrAHUAYQBXADUAagBiAEgAVgBrAFoAWABNAG8ASgAyAEYAMwBZAFcAdABsAEoA
>> "%~1" echo eQBrADcAYwBtAGwAdQBaAHkAZwBuAGMAMgB4AGwAWgBYAEIASABZAFgAVgBuAFoA
>> "%~1" echo UwBjAHMAZAB6ADAAOQBQAFMAYwB0AEoAegA4AG4ATABTAGMANgBkAHkAeABzAFkA
>> "%~1" echo WABOADAATABtADEAVABkAEcARgA1AFQAMgA0ADkAUABUADAAbgBkAEgASgAxAFoA
>> "%~1" echo UwBjAC8ASgArAFMALwBuAGUAYQBNAGcAZQBXAFUAcABPAG0ARwBrAGkAYwA2AEoA
>> "%~1" echo KwBTADgAawBlAGUAYwBvAEMAYwBzAFkAWABkAGgAYQAyAFUALwBNAFQAQQB3AE8A
>> "%~1" echo agBJADQATABHAEYAMwBZAFcAdABsAFAAeQBkAGgAYgBXAEoAbABjAGkAYwA2AEoA
>> "%~1" echo MgBkAHkAWgBXAFYAdQBKAHkAawA3AFQAMgBKAHEAWgBXAE4AMABMAG0AdABsAGUA
>> "%~1" echo WABNAG8AYgBHAEYAegBkAEMAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMAaAByAFAA
>> "%~1" echo VAA1AHoAWgBYAFEAbwBhAHkAeABzAFkAWABOADAAVwAyAHQAZABLAFMAawA3AGMA
>> "%~1" echo MgBWADAASwBDAGQAdwBiADMAZABsAGMAbABOAHYAZABYAEoAagBaAFQASQBuAEwA
>> "%~1" echo RwB4AGgAYwAzAFEAdQBjAEcAOQAzAFoAWABKAFQAYgAzAFYAeQBZADIAVQBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBiAEcAOQBuAFUARwBGADAAYQBDAGMAcwBiAEcARgB6AGQA
>> "%~1" echo QwA1AHMAYgAyAGQARwBhAFcAeABsAEsAVAB0AHoAWgBYAFEAbwBKADIATgB2AGIA
>> "%~1" echo bgBOAHYAYgBHAFYAVABkAEcARgAwAFoAUwBjAHMAYgBHAEYAegBkAEMANQBrAFoA
>> "%~1" echo WABaAHAAWQAyAFYAVABkAEcARgAwAFoAUwBrADcAYwAyAFYAMABLAEMAZABqAGIA
>> "%~1" echo MgA1AHoAYgAyAHgAbABRADIAOQB1AGIAaQBjAHMAWQB6ADgAbgA1AGIAZQB5ADYA
>> "%~1" echo TAArAGUANQBvADYAbABKAHoAbwBuADUAcAB5AHEANgBMACsAZQA1AG8ANgBsAEoA
>> "%~1" echo eQBrADcAYwAyAFYAMABLAEMAZABqAGIAMgA1AHoAYgAyAHgAbABRAG0ARgAwAGQA
>> "%~1" echo RwBWAHkAZQBTAGMAcwBZAGoAMAA5AFAAUwBjAHQASgB6ADgAbgBMAFMAYwA2AFkA
>> "%~1" echo aQBzAG4ASgBTAGMAcABPADMATgBsAGQAQwBnAG4AWQAyADkAdQBjADIAOQBzAFoA
>> "%~1" echo VgBkAGgAYQAyAFUAbgBMAEgAYwBwAE8AMwBOAGwAZABDAGcAbgBZADIAOQB1AGMA
>> "%~1" echo MgA5AHMAWgBWAGQAcABaAG0AawBuAEwASABZAG8ASgAzAGQAcABaAG0AbABKAGMA
>> "%~1" echo QwBjAHAASwBUAHQAeQBaAFcANQBrAFoAWABKAFEAWQBYAEoAaABiAFgATQBvAEsA
>> "%~1" echo VAB0AHkAWgBXADUAawBaAFgASgBJAFoAVwBGAGsAYwAyAFYAMABLAEMAawA3AGMA
>> "%~1" echo MwBsAHUAWQAwAEYAawBZAGsASgBoAGIAbQA1AGwAYwBpAGcAcABPADIAbABtAEsA
>> "%~1" echo QwBGAHMAYgAyAE4AaABiAEYATgAwAGIAMwBKAGgAWgAyAFUAdQBaADIAVgAwAFMA
>> "%~1" echo WABSAGwAYgBTAGcAbgBjAFgAVgBsAGMAMwBSAEIAWgBHAEoATQBZAFcANQBuAEoA
>> "%~1" echo eQBrAHAAZQAyAE4AdgBiAG4ATgAwAEkARwA1AGwAZQBIAFEAOQBaAEcAVgAwAFoA
>> "%~1" echo VwBOADAAVABHAEYAdQBaAHkAZwBwAE8AMgBsAG0ASwBHADUAbABlAEgAUQBoAFAA
>> "%~1" echo VAAxAE0AUQBVADUASABLAFgAdABNAFEAVQA1AEgAUABXADUAbABlAEgAUQA3AFkA
>> "%~1" echo WABCAHcAYgBIAGwASgBNAFQAaAB1AEsAQwBsADkAZgBXAGwAbQBLAEgATgBvAGIA
>> "%~1" echo MwBkAE8AYgAzAFIAcABZADIAVQBwAGIAbQA5ADAAYQBXAFoANQBLAEMAZgBsAGkA
>> "%~1" echo TABmAG0AbAByAEQAbAByAG8AegBtAGkASgBBAG4ATABHAE0ALwBKACsAVwAzAHMA
>> "%~1" echo dQBpAC8AbgB1AGEATwBwAGUAKwA4AG0AaQBjAHIASwBHAHgAaABjADMAUQB1AGIA
>> "%~1" echo VwA5AGsAWgBXAHgAOABmAEMAZABSAGQAVwBWAHoAZABDAGMAcABLAHkAZgB2AHYA
>> "%~1" echo SQB6AG4AbABMAFgAcABoADQAOABnAEoAeQB0AGkASwB5AGMAbABKAHoAbwBvAGIA
>> "%~1" echo RwBGAHoAZABDADUAbwBhAFcANQAwAGYASAB3AG4ANQBwAHkAcQA2AEwAKwBlADUA
>> "%~1" echo bwA2AGwASgB5AGsAcwBZAHoAOABuAGIAMgBzAG4ATwBpAGQAMwBZAFgASgB1AEoA
>> "%~1" echo eQBsADkAWQAyAEYAMABZADIAZwBvAFoAUwBsADcAYgBHADkAbgBLAEMAZgBsAGkA
>> "%~1" echo TABmAG0AbAByAEQAbABwAEwASABvAHQASwBYAHYAdgBKAG8AbgBLADIAVQB1AGIA
>> "%~1" echo VwBWAHoAYwAyAEYAbgBaAFMAawA3AGMAbQBWAHUAWgBHAFYAeQBVAEcARgB5AFkA
>> "%~1" echo VwAxAHoASwBDAGsANwBhAFcAWQBvAGMAMgBoAHYAZAAwADUAdgBkAEcAbABqAFoA
>> "%~1" echo UwBsAHUAYgAzAFIAcABaAG4AawBvAEoAKwBXAEkAdAArAGEAVwBzAE8AVwBrAHMA
>> "%~1" echo ZQBpADAAcABTAGMAcwBaAFMANQB0AFoAWABOAHoAWQBXAGQAbABMAEMAZABsAGMA
>> "%~1" echo bgBJAG4ATABEAFEAeQBNAEQAQQBwAGYAWAAwAE4AQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBIAE4AbABkAEUASgAxAGMAMwBrAG8AYgAyADQAcwBZAG4AUgB1AEsA
>> "%~1" echo WAB0AGkAZABYAE4ANQBQAFcAOQB1AE8AMgBSAHYAWQAzAFYAdABaAFcANQAwAEwA
>> "%~1" echo bgBGADEAWgBYAEoANQBVADIAVgBzAFoAVwBOADAAYgAzAEoAQgBiAEcAdwBvAEoA
>> "%~1" echo MgBKADEAZABIAFIAdgBiAGkAYwBwAEwAbQBaAHYAYwBrAFYAaABZADIAZwBvAFkA
>> "%~1" echo agAwACsAWQBpADUAawBhAFgATgBoAFkAbQB4AGwAWgBEADEAdgBiAGkAawA3AGEA
>> "%~1" echo VwBZAG8AWQBuAFIAdQBLAFcASgAwAGIAaQA1AGoAYgBHAEYAegBjADAAeABwAGMA
>> "%~1" echo MwBRAHUAZABHADkAbgBaADIAeABsAEsAQwBkAHAAYwB5ADEAaQBkAFgATgA1AEoA
>> "%~1" echo eQB4AHYAYgBpAGwAOQBEAFEAcABoAGMAMwBsAHUAWQB5AEIAbQBkAFcANQBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEIAaABZADMAUgBwAGIAMgA0AG8AWQBTAHgAbABlAEgAUgB5AFkA
>> "%~1" echo VAAwAG4ASgB5AHgAcwBZAFcASgBsAGIARAAwAG4ANQBwAE8ATgA1AEwAMgBjAEoA
>> "%~1" echo eQB4AGkAZABHADQAOQBiAG4AVgBzAGIAQwB4AGoAYgAyADUAbQBhAFgASgB0AFoA
>> "%~1" echo VwBRADkAWgBtAEYAcwBjADIAVQBwAGUAMgBsAG0ASwBHAEoAMQBjADMAawBwAGMA
>> "%~1" echo bQBWADAAZABYAEoAdQBJAEcANQB2AGQARwBsAG0AZQBTAGcAbgA1AGIAZQB5ADUA
>> "%~1" echo cAB5AEoANQBwAE8ATgA1AEwAMgBjADUAbwBtAG4ANgBLAEcATQA1AEwAaQB0AEoA
>> "%~1" echo eQB3AG4ANgBLACsAMwA1ADYAMgBKADUAYgA2AEYANQBMAGkASwA1AEwAaQBBADUA
>> "%~1" echo cAAyAGgANQBaAEcAOQA1AEwAdQBrADUAYQA2AE0ANQBvAGkAUQA0ADQAQwBDAEoA
>> "%~1" echo eQB3AG4AZAAyAEYAeQBiAGkAYwBwAE8AMwBSAHkAZQBYAHQAegBaAFgAUgBDAGQA
>> "%~1" echo WABOADUASwBIAFIAeQBkAFcAVQBzAFkAbgBSAHUASwBUAHQAcwBiADIAYwBvAEoA
>> "%~1" echo KwBhAEoAcAArAGkAaABqAE8AUwA0AHIAZQArADgAbQBpAGMAcgBiAEcARgBpAFoA
>> "%~1" echo VwB3AHAATwAyADUAdgBkAEcAbABtAGUAUwBoAHMAWQBXAEoAbABiAEMAdwBuADUA
>> "%~1" echo cQAyAGoANQBaAHkAbwA1AFkAKwBSADYAWQBDAEIANQBaAEcAOQA1AEwAdQBrAEwA
>> "%~1" echo aQA0AHUASgB5AHcAbgBkADIARgB5AGIAaQBjAHMATQBUAGcAdwBNAEMAawA3AGIA
>> "%~1" echo RwBWADAASQBIAFYAeQBiAEQAMABuAEwAMgBGAHcAYQBTADkAaABZADMAUgBwAGIA
>> "%~1" echo MgA0AC8AWQBXAE4AMABhAFcAOQB1AFAAUwBjAHIAWgBXADUAagBiADIAUgBsAFYA
>> "%~1" echo VgBKAEoAUQAyADkAdABjAEcAOQB1AFoAVwA1ADAASwBHAEUAcABLADIAVgA0AGQA
>> "%~1" echo SABKAGgATwAyAGwAbQBLAEcATgB2AGIAbQBaAHAAYwBtADEAbABaAEMAbAAxAGMA
>> "%~1" echo bQB3AHIAUABTAGMAbQBZADIAOQB1AFoAbQBsAHkAYgBUADEAWgBSAFYATQBuAE8A
>> "%~1" echo MgBOAHYAYgBuAE4AMABJAEgASQA5AFkAWABkAGgAYQBYAFEAZwBZAFgAQgBwAEsA
>> "%~1" echo SABWAHkAYgBDAHgANwBiAFcAVgAwAGEARwA5AGsATwBpAGQAUQBUADEATgBVAEoA
>> "%~1" echo MwAwAHAATwAyAGwAbQBLAEgASQB1AGIAMgBzAGgAUABUADAAbgBkAEgASgAxAFoA
>> "%~1" echo UwBjAHAAZABHAGgAeQBiADMAYwBnAGIAbQBWADMASQBFAFYAeQBjAG0AOQB5AEsA
>> "%~1" echo SABJAHUAWgBYAEoAeQBiADMASgA4AGYAQwBmAG0AawA0ADMAawB2AFoAegBsAHAA
>> "%~1" echo TABIAG8AdABLAFUAbgBLAFQAdABzAGIAMgBjAG8AYwBpADUAeQBaAFgATgAxAGIA
>> "%~1" echo SABSADgAZgBDAGYAbAByAG8AegBtAGkASgBBAG4ASwBUAHQAdQBiADMAUgBwAFoA
>> "%~1" echo bgBrAG8AYgBHAEYAaQBaAFcAdwByAEoAKwBXAHUAagBPAGEASQBrAEMAYwBzAGMA
>> "%~1" echo aQA1AHkAWgBYAE4AMQBiAEgAUgA4AGYAQwBmAGwAcgBvAHoAbQBpAEoAQQBuAEwA
>> "%~1" echo QwBkAHYAYQB5AGMAcABPADMATgBsAGQARgBSAHAAYgBXAFYAdgBkAFgAUQBvAEsA
>> "%~1" echo QwBrADkAUABuAHQAeQBaAFcAWgB5AFoAWABOAG8ASwBHAFoAaABiAEgATgBsAEsA
>> "%~1" echo VAB0AHMAYgAyAEYAawBUAEcAOQBuAGMAeQBoAG0AWQBXAHgAegBaAFMAbAA5AEwA
>> "%~1" echo RABVAHcATQBDAGwAOQBZADIARgAwAFkAMgBnAG8AWgBTAGwANwBiAEcAOQBuAEsA
>> "%~1" echo QwBmAG0AawA0ADMAawB2AFoAegBsAHAATABIAG8AdABLAFgAdgB2AEoAbwBuAEsA
>> "%~1" echo MgBVAHUAYgBXAFYAegBjADIARgBuAFoAUwBrADcAYgBtADkAMABhAFcAWgA1AEsA
>> "%~1" echo RwB4AGgAWQBtAFYAcwBLAHkAZgBsAHAATABIAG8AdABLAFUAbgBMAEcAVQB1AGIA
>> "%~1" echo VwBWAHoAYwAyAEYAbgBaAFMAdwBuAFoAWABKAHkASgB5AHcAMABOAGoAQQB3AEsA
>> "%~1" echo VAB0AHMAYgAyAEYAawBUAEcAOQBuAGMAeQBoAG0AWQBXAHgAegBaAFMAbAA5AFoA
>> "%~1" echo bQBsAHUAWQBXAHgAcwBlAFgAdAB6AFoAWABSAEMAZABYAE4ANQBLAEcAWgBoAGIA
>> "%~1" echo SABOAGwATABHAEoAMABiAGkAbAA5AGYAUQAwAEsAWQBYAE4ANQBiAG0ATQBnAFoA
>> "%~1" echo bgBWAHUAWQAzAFIAcABiADIANABnAFoAWABoAHcAYgAzAEoAMABTAEgAUgB0AGIA
>> "%~1" echo QwBnAHAAZQAyAGwAbQBLAEcASgAxAGMAMwBrAHAAYwBtAFYAMABkAFgASgB1AEkA
>> "%~1" echo RwA1AHYAZABHAGwAbQBlAFMAZwBuADUAYgBlAHkANQBwAHkASgA1AHAATwBOADUA
>> "%~1" echo TAAyAGMANQBvAG0AbgA2AEsARwBNADUATABpAHQASgB5AHcAbgA2AEsAKwAzADUA
>> "%~1" echo NgAyAEoANQBiADYARgA1AEwAaQBLADUATABpAEEANQBwADIAaAA1AFoARwA5ADUA
>> "%~1" echo TAB1AGsANQBhADYATQA1AG8AaQBRADQANABDAEMASgB5AHcAbgBkADIARgB5AGIA
>> "%~1" echo aQBjAHAATwAyAE4AdgBiAG4ATgAwAEkARwBKADAAYgBqADAAawBLAEMAZABsAGUA
>> "%~1" echo SABCAHYAYwBuAFIAQwBkAEcANABuAEsAVAB0ADAAYwBuAGwANwBjADIAVgAwAFEA
>> "%~1" echo bgBWAHoAZQBTAGgAMABjAG4AVgBsAEwARwBKADAAYgBpAGsANwBjADIAVgAwAEsA
>> "%~1" echo QwBkAGwAZQBIAEIAdgBjAG4AUgBUAGQARwBGADAAZABYAE0AbgBMAEMAZgBtAHIA
>> "%~1" echo YQBQAGwAbgBLAGoAbABqADYAcgBvAHIANwB2AHAAaAA0AGYAcABtADQAYgBsAHIA
>> "%~1" echo bwB6AG0AbABiAFQAbwByAHIANwBsAHAASQBmAGsAdgA2AEgAbQBnAGEALwB2AHYA
>> "%~1" echo SQB6AGwAagA2AC8AbwBnADcAMwBwAG4ASQBEAG8AcABvAEUAZwBNAFQAQQB0AE4A
>> "%~1" echo RABBAGcANQA2AGUAUwBMAGkANAB1AEoAeQBrADcASgBDAGcAbgBaAFgAaAB3AGIA
>> "%~1" echo MwBKADAAVABHAGwAdQBhADMATQBuAEsAUwA1AHAAYgBtADUAbABjAGsAaABVAFQA
>> "%~1" echo VQB3ADkASgB5AGMANwBiAG0AOQAwAGEAVwBaADUASwBDAGYAbAB2AEkARABsAHAA
>> "%~1" echo NAB2AGwAcgA3AHoAbABoADcAbwBuAEwAQwBmAG0AcgBhAFAAbABuAEsAagBuAGwA
>> "%~1" echo SgAvAG0AaQBKAEQAbgBwADQASABtAG4ASQBuAGwAcgBvAHoAbQBsAGIAVABuAGkA
>> "%~1" echo WQBqAGwAawBvAHoAbABpAEkAYgBrAHUAcQB2AGwAcgBvAG4AbABoAGEAagBuAGkA
>> "%~1" echo WQBnAGcAUwBGAFIATgBUAEMAYwBzAEoAMwBkAGgAYwBtADQAbgBMAEQASQB5AE0A
>> "%~1" echo RABBAHAATwAyAE4AdgBiAG4ATgAwAEkASABJADkAWQBYAGQAaABhAFgAUQBnAFkA
>> "%~1" echo WABCAHAASwBDAGMAdgBZAFgAQgBwAEwAMgBWADQAYwBHADkAeQBkAEQAOQB0AGIA
>> "%~1" echo MgBSAGwAUABXAEoAdgBkAEcAZwBuAEwASAB0AHQAWgBYAFIAbwBiADIAUQA2AEoA
>> "%~1" echo MQBCAFAAVQAxAFEAbgBmAFMAawA3AGEAVwBZAG8AYwBpADUAdgBhAHkARQA5AFAA
>> "%~1" echo UwBkADAAYwBuAFYAbABKAHkAbAAwAGEASABKAHYAZAB5AEIAdQBaAFgAYwBnAFIA
>> "%~1" echo WABKAHkAYgAzAEkAbwBjAGkANQBsAGMAbgBKAHYAYwBuAHgAOABKACsAVwB2AHYA
>> "%~1" echo TwBXAEgAdQB1AFcAawBzAGUAaQAwAHAAUwBjAHAATwAzAE4AbABkAEMAZwBuAFoA
>> "%~1" echo WABoAHcAYgAzAEoAMABVADMAUgBoAGQASABWAHoASgB5AHcAbgA1AGEAKwA4ADUA
>> "%~1" echo WQBlADYANQBhADYATQA1AG8AaQBRADcANwB5AGEASgB5AHMAbwBjAGkANQB6AFoA
>> "%~1" echo VwBOADAAYQBXADkAdQBRADIAOQAxAGIAbgBSADgAZgBDAGMAdABKAHkAawByAEoA
>> "%~1" echo eQBEAGsAdQBLAHIAcABoADQAZgBwAG0ANABiAG0AcgByAFgAdgB2AEkAegBvAGcA
>> "%~1" echo SgBmAG0AbAA3AFkAZwBKAHkAdABOAFkAWABSAG8ATABuAEoAdgBkAFcANQBrAEsA
>> "%~1" echo QwBoAHcAWQBYAEoAegBaAFUAbAB1AGQAQwBoAHkATABtAFIAMQBjAG0ARgAwAGEA
>> "%~1" echo VwA5AHUAVABYAE4AOABmAEMAYwB3AEoAeQB3AHgATQBDAGwAOABmAEQAQQBwAEwA
>> "%~1" echo egBFAHcATQBEAEEAcABLAHkAYwBnADUANgBlAFMANAA0AEMAQwBKAHkAawA3AEoA
>> "%~1" echo QwBnAG4AWgBYAGgAdwBiADMASgAwAFQARwBsAHUAYQAzAE0AbgBLAFMANQBwAGIA
>> "%~1" echo bQA1AGwAYwBrAGgAVQBUAFUAdwA5AEoAegB4AGgASQBIAFIAaABjAG0AZABsAGQA
>> "%~1" echo RAAwAGkAWAAyAEoAcwBZAFcANQByAEkAaQBCAG8AYwBtAFYAbQBQAFMASQBuAEsA
>> "%~1" echo MgBWAHoAWQB5AGgAeQBMAG4AQgB5AGEAWABaAGgAZABHAFYAVgBjAG0AdwBwAEsA
>> "%~1" echo eQBjAGkAUAB1AGEASgBrACsAVwA4AGcATwBlAG4AZwBlAGEAYwBpAGUAVwB1AGoA
>> "%~1" echo TwBhAFYAdABPAGUASgBpAEMAQgBJAFYARQAxAE0AUABDADkAaABQAGoAeABoAEkA
>> "%~1" echo SABSAGgAYwBtAGQAbABkAEQAMABpAFgAMgBKAHMAWQBXADUAcgBJAGkAQgBvAGMA
>> "%~1" echo bQBWAG0AUABTAEkAbgBLADIAVgB6AFkAeQBoAHkATABuAE4AaABaAG0AVgBWAGMA
>> "%~1" echo bQB3AHAASwB5AGMAaQBQAHUAYQBKAGsAKwBXADgAZwBPAFcASQBoAHUAUwA2AHEA
>> "%~1" echo KwBXAHUAaQBlAFcARgBxAE8AZQBKAGkAQwBCAEkAVgBFADEATQBQAEMAOQBoAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBQAGkAYwByAFoAWABOAGoASwBIAEkAdQBjADIARgBtAFoA
>> "%~1" echo VgBCAGgAZABHAGgAOABmAEMAYwBuAEsAUwBzAG4AUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo aQBjADcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGwAcgA3AHoAbABoADcAcgBsAHIA
>> "%~1" echo bwB6AG0AaQBKAEEAbgBMAEMAZgBsAHQANwBMAG4AbABKAC8AbQBpAEoARABrAHUA
>> "%~1" echo SwBUAGsAdQA3ADAAZwBTAEYAUgBOAFQAQwBEAG0AaQBxAFgAbABrAFkAbwBuAEwA
>> "%~1" echo QwBkAHYAYQB5AGMAcABPADIAeAB2AFkAVwBSAE0AYgAyAGQAegBLAEcAWgBoAGIA
>> "%~1" echo SABOAGwASwBYADEAagBZAFgAUgBqAGEAQwBoAGwASwBYAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgBWADQAYwBHADkAeQBkAEYATgAwAFkAWABSADEAYwB5AGMAcwBKACsAVwB2AHYA
>> "%~1" echo TwBXAEgAdQB1AFcAawBzAGUAaQAwAHAAZQArADgAbQBpAGMAcgBaAFMANQB0AFoA
>> "%~1" echo WABOAHoAWQBXAGQAbABLAFQAdAB1AGIAMwBSAHAAWgBuAGsAbwBKACsAVwB2AHYA
>> "%~1" echo TwBXAEgAdQB1AFcAawBzAGUAaQAwAHAAUwBjAHMAWgBTADUAdABaAFgATgB6AFkA
>> "%~1" echo VwBkAGwATABDAGQAbABjAG4ASQBuAEwARABVAHkATQBEAEEAcABPADIAeAB2AFkA
>> "%~1" echo VwBSAE0AYgAyAGQAegBLAEcAWgBoAGIASABOAGwASwBYADEAbQBhAFcANQBoAGIA
>> "%~1" echo RwB4ADUAZQAzAE4AbABkAEUASgAxAGMAMwBrAG8AWgBtAEYAcwBjADIAVQBzAFkA
>> "%~1" echo bgBSAHUASwBYADEAOQBEAFEAbwBOAEMAaQA4AHEASQBDADAAdABMAFMAMAB0AEwA
>> "%~1" echo UwAwAHQATABTADAAZwBRAFYAQgBMAEkARwBsAHUAYwAzAFIAaABiAEcAeABsAGMA
>> "%~1" echo aQBBAG8AUQBYAEIAdwBJAEYATgAwAGIAMwBKAGwASQBHAE4AaABjAG0AUQBnAEsA
>> "%~1" echo eQBCAFQAVQAwAFUAZwBjAEgASgB2AFoAMwBKAGwAYwAzAE0AcABJAEMAMAB0AEwA
>> "%~1" echo UwAwAHQATABTADAAdABMAFMAMABnAEsAaQA4AE4AQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBIAEoAbABjADIAVgAwAFEAWABCAHIASwBDAGwANwBZAFgAQgByAFAA
>> "%~1" echo VwA1ADEAYgBHAHcANwBKAEMAZwBuAFkAWABCAHIAUgBHAFYAMABZAFcAbABzAEoA
>> "%~1" echo eQBrAHUAYwAzAFIANQBiAEcAVQB1AFoARwBsAHoAYwBHAHgAaABlAFQAMABuAGIA
>> "%~1" echo bQA5AHUAWgBTAGMANwBKAEMAZwBuAFkAWABCAHIAUgBIAEoAdgBjAEMAYwBwAEwA
>> "%~1" echo bgBOADAAZQBXAHgAbABMAG0AUgBwAGMAMwBCAHMAWQBYAGsAOQBKAHkAYwA3AEoA
>> "%~1" echo QwBnAG4AWQBYAEIAcgBVAEcAVgB5AGIAWABNAG4ASwBTADUAagBiAEcARgB6AGMA
>> "%~1" echo MAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIAMwBaAGwASwBDAGQAegBhAEcAOQAzAEoA
>> "%~1" echo eQBrADcASgBDAGcAbgBZAFcAUgBpAFQAMwBWADAASgB5AGsAdQBZADIAeABoAGMA
>> "%~1" echo MwBOAE0AYQBYAE4AMABMAG4ASgBsAGIAVwA5ADIAWgBTAGcAbgBjADIAaAB2AGQA
>> "%~1" echo eQBjAHAATwB5AFEAbwBKADIARgBrAFkAawA5ADEAZABDAGMAcABMAG4AUgBsAGUA
>> "%~1" echo SABSAEQAYgAyADUAMABaAFcANQAwAFAAUwBjAG4ATwB5AFEAbwBKADMATgAwAFkA
>> "%~1" echo VwBkAGwAVQBtADkAMwBKAHkAawB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwA
>> "%~1" echo bgBKAGwAYgBXADkAMgBaAFMAZwBuAGMAMgBoAHYAZAB5AGMAcABPADIATgB2AGIA
>> "%~1" echo bgBOADAASQBHAEkAOQBKAEMAZwBuAGEAVwA1AHoAZABHAEYAcwBiAEUASgAwAGIA
>> "%~1" echo aQBjAHAATwAyAEkAdQBZADIAeABoAGMAMwBOAE8AWQBXADEAbABQAFMAZABwAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBRAG4AUgB1AEoAegB0AGkATABtAFIAcABjADIARgBpAGIA
>> "%~1" echo RwBWAGsAUABXAFoAaABiAEgATgBsAE8AeQBRAG8ASgAyAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AEcAYQBXAHgAcwBKAHkAawB1AGMAMwBSADUAYgBHAFUAdQBkADIAbABrAGQA
>> "%~1" echo RwBnADkASgB6AEEAbgBPAHkAUQBvAEoAMgBsAHUAYwAzAFIAaABiAEcAeABNAFkA
>> "%~1" echo VwBKAGwAYgBDAGMAcABMAG4AUgBsAGUASABSAEQAYgAyADUAMABaAFcANQAwAFAA
>> "%~1" echo UwBmAGwAcgBvAG4AbwBvADQAWABsAGkATABBAGcAVQBYAFYAbABjADMAUQBuAE8A
>> "%~1" echo eQBRAG8ASgAyAEYAdwBjAEUATgBoAGMAbQBRAG4ASwBTADUAagBiAEcARgB6AGMA
>> "%~1" echo MAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIAMwBaAGwASwBDAGQAbgBiAEcAOQAzAEoA
>> "%~1" echo eQBsADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAMQBjAEcAeAB2AFkA
>> "%~1" echo VwBSAEIAYwBHAHMAbwBaAG0AbABzAFoAUwBsADcARABRAG8AZwBJAEcAbABtAEsA
>> "%~1" echo RwBKADEAYwAzAGsAcABjAG0AVgAwAGQAWABKAHUASQBHADUAdgBkAEcAbABtAGUA
>> "%~1" echo UwBnAG4ANQBiAGUAeQA1AHAAeQBKADUAcABPAE4ANQBMADIAYwA1AG8AbQBuADYA
>> "%~1" echo SwBHAE0ANQBMAGkAdABKAHkAdwBuADYASwArADMANQA2ADIASgA1AGIANgBGADUA
>> "%~1" echo TABpAEsANQBMAGkAQQA1AHAAMgBoADUAWgBHADkANQBMAHUAawA1AGEANgBNADUA
>> "%~1" echo bwBpAFEANAA0AEMAQwBKAHkAdwBuAGQAMgBGAHkAYgBpAGMAcABPAHcAMABLAEkA
>> "%~1" echo QwBCAHAAWgBpAGcAaABaAG0AbABzAFoAUwBsAHkAWgBYAFIAMQBjAG0ANAA3AEQA
>> "%~1" echo UQBvAGcASQBHAGwAbQBLAEMARQB2AFgAQwA1AGgAYwBHAHMAawBMADIAawB1AGQA
>> "%~1" echo RwBWAHoAZABDAGgAbQBhAFcAeABsAEwAbQA1AGgAYgBXAFUAcABLAFgASgBsAGQA
>> "%~1" echo SABWAHkAYgBpAEIAdQBiADMAUgBwAFoAbgBrAG8ASgArAGEAVwBoACsAUwA3AHQA
>> "%~1" echo dQBlAHgAdQArAFcAZQBpACsAUwA0AGoAZQBhAFUAcgArAGEATQBnAFMAYwBzAEoA
>> "%~1" echo KwBpAHYAdAArAG0AQQBpAGUAYQBMAHEAUwBBAHUAWQBYAEIAcgBJAE8AYQBXAGgA
>> "%~1" echo KwBTADcAdAB1AE8AQQBnAGkAYwBzAEoAMwBkAGgAYwBtADQAbgBLAFQAcwBOAEMA
>> "%~1" echo aQBBAGcATAB5ADgAZwBjADIAaAB2AGQAeQBCAGgASQBHAHgAcABaADIAaAAwAGQA
>> "%~1" echo MgBWAHAAWgAyAGgAMABJAEgAVgB3AGIARwA5AGgAWgBHAGwAdQBaAHkAQgB6AGQA
>> "%~1" echo RwBGADAAWgBTAEIAdgBiAGkAQgAwAGEARwBVAGcAWgBIAEoAdgBjAEMAQgAwAGEA
>> "%~1" echo VwB4AGwARABRAG8AZwBJAEcATgB2AGIAbgBOADAASQBHAFIAeQBiADMAQQA5AEoA
>> "%~1" echo QwBnAG4AWQBYAEIAcgBSAEgASgB2AGMAQwBjAHAATwAyAFIAeQBiADMAQQB1AGMA
>> "%~1" echo WABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBpAGcAbgBZAGkAYwBwAEwA
>> "%~1" echo bgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABTAGYAbQByAGEAUABsAG4A
>> "%~1" echo SwBqAGsAdQBJAHIAawB2AEsAQQBnAEoAeQB0AG0AYQBXAHgAbABMAG0ANQBoAGIA
>> "%~1" echo VwBVAHIASgB5AEQAaQBnAEsAWQBuAE8AdwAwAEsASQBDAEIAagBiADIANQB6AGQA
>> "%~1" echo QwBCADQAYQBIAEkAOQBiAG0AVgAzAEkARgBoAE4AVABFAGgAMABkAEgAQgBTAFoA
>> "%~1" echo WABGADEAWgBYAE4AMABLAEMAawA3AEQAUQBvAGcASQBIAGgAbwBjAGkANQB2AGMA
>> "%~1" echo RwBWAHUASwBDAGQAUQBUADEATgBVAEoAeQB3AG4ATAAyAEYAdwBhAFMAOQBoAGMA
>> "%~1" echo RwBzAHYAZABYAEIAcwBiADIARgBrAFAAMgA1AGgAYgBXAFUAOQBKAHkAdABsAGIA
>> "%~1" echo bQBOAHYAWgBHAFYAVgBVAGsAbABEAGIAMgAxAHcAYgAyADUAbABiAG4AUQBvAFoA
>> "%~1" echo bQBsAHMAWgBTADUAdQBZAFcAMQBsAEsAUwBrADcARABRAG8AZwBJAEgAaABvAGMA
>> "%~1" echo aQA1AHoAWgBYAFIAUwBaAFgARgAxAFoAWABOADAAUwBHAFYAaABaAEcAVgB5AEsA
>> "%~1" echo QwBkAFkATABWAEYAMQBaAFgATgAwAEwAVgBSAHYAYQAyAFYAdQBKAHkAeABVAFQA
>> "%~1" echo MAB0AEYAVABpAGsANwBEAFEAbwBnAEkASABoAG8AYwBpADUAegBaAFgAUgBTAFoA
>> "%~1" echo WABGADEAWgBYAE4AMABTAEcAVgBoAFoARwBWAHkASwBDAGQARABiADIANQAwAFoA
>> "%~1" echo VwA1ADAATABWAFIANQBjAEcAVQBuAEwAQwBkAGgAYwBIAEIAcwBhAFcATgBoAGQA
>> "%~1" echo RwBsAHYAYgBpADkAdgBZADMAUgBsAGQAQwAxAHoAZABIAEoAbABZAFcAMABuAEsA
>> "%~1" echo VABzAE4AQwBpAEEAZwBlAEcAaAB5AEwAbgBWAHcAYgBHADkAaABaAEMANQB2AGIA
>> "%~1" echo bgBCAHkAYgAyAGQAeQBaAFgATgB6AFAAVwBVADkAUABuAHQAcABaAGkAaABsAEwA
>> "%~1" echo bQB4AGwAYgBtAGQAMABhAEUATgB2AGIAWABCADEAZABHAEYAaQBiAEcAVQBwAGUA
>> "%~1" echo MgBOAHYAYgBuAE4AMABJAEgAQQA5AFQAVwBGADAAYQBDADUAeQBiADMAVgB1AFoA
>> "%~1" echo QwBoAGwATABtAHgAdgBZAFcAUgBsAFoAQwA5AGwATABuAFIAdgBkAEcARgBzAEsA
>> "%~1" echo agBFAHcATQBDAGsANwBaAEgASgB2AGMAQwA1AHgAZABXAFYAeQBlAFYATgBsAGIA
>> "%~1" echo RwBWAGoAZABHADkAeQBLAEMAYwBqAFoASABKAHYAYwBFAGgAcABiAG4AUQBuAEsA
>> "%~1" echo UwA1ADAAWgBYAGgAMABRADIAOQB1AGQARwBWAHUAZABEADAAbgA1AEwAaQBLADUA
>> "%~1" echo TAB5AGcANQBMAGkAdABJAEMAYwByAGMAQwBzAG4ASgBTAGQAOQBmAFQAcwBOAEMA
>> "%~1" echo aQBBAGcAYwAyAFYAMABRAG4AVgB6AGUAUwBoADAAYwBuAFYAbABMAEcANQAxAGIA
>> "%~1" echo RwB3AHAATwB3ADAASwBJAEMAQgA0AGEASABJAHUAYgAyADUAcwBiADIARgBrAFAA
>> "%~1" echo UwBnAHAAUABUADUANwBjADIAVgAwAFEAbgBWAHoAZQBTAGgAbQBZAFcAeAB6AFoA
>> "%~1" echo UwB4AHUAZABXAHgAcwBLAFQAdAAwAGMAbgBsADcAWQAyADkAdQBjADMAUQBnAGMA
>> "%~1" echo agAxAEsAVQAwADkATwBMAG4AQgBoAGMAbgBOAGwASwBIAGgAbwBjAGkANQB5AFoA
>> "%~1" echo WABOAHcAYgAyADUAegBaAFYAUgBsAGUASABRAHAATwAyAGwAbQBLAEgASQB1AGIA
>> "%~1" echo MgBzAGgAUABUADAAbgBkAEgASgAxAFoAUwBjAHAAZABHAGgAeQBiADMAYwBnAGIA
>> "%~1" echo bQBWADMASQBFAFYAeQBjAG0AOQB5AEsASABJAHUAWgBYAEoAeQBiADMASgA4AGYA
>> "%~1" echo QwBmAGsAdQBJAHIAawB2AEsARABsAHAATABIAG8AdABLAFUAbgBLAFQAdABoAGMA
>> "%~1" echo RwBzADkAYwBqAHQAegBhAEcAOQAzAFEAWABCAHIASwBIAEkAcABPADIANQB2AGQA
>> "%~1" echo RwBsAG0AZQBTAGcAbgA1AEwAaQBLADUATAB5AGcANQBhADYATQA1AG8AaQBRAEoA
>> "%~1" echo eQB3AG8AYwBpADUAdwBZAFcATgByAFkAVwBkAGwAZgBIAHgAeQBMAG0AWgBwAGIA
>> "%~1" echo RwBWAE8AWQBXADEAbABLAFMAcwBuAEkATwBXADMAcwB1AGkAbgBvACsAYQBlAGsA
>> "%~1" echo QwBjAHMASgAyADkAcgBKAHkAbAA5AFkAMgBGADAAWQAyAGcAbwBaAFMAbAA3AGIA
>> "%~1" echo bQA5ADAAYQBXAFoANQBLAEMAZgBrAHUASQByAGsAdgBLAEQAbABwAEwASABvAHQA
>> "%~1" echo SwBVAG4ATABHAFUAdQBiAFcAVgB6AGMAMgBGAG4AWgBTAHcAbgBaAFgASgB5AEoA
>> "%~1" echo eQB3ADEATQBEAEEAdwBLAFQAdABrAGMAbQA5AHcATABuAEYAMQBaAFgASgA1AFUA
>> "%~1" echo MgBWAHMAWgBXAE4AMABiADMASQBvAEoAMgBJAG4ASwBTADUAMABaAFgAaAAwAFEA
>> "%~1" echo MgA5AHUAZABHAFYAdQBkAEQAMABuADUAbwB1AFcANQBvAHUAOQBJAEUARgBRAFMA
>> "%~1" echo eQBEAGwAaQBMAEQAbwB2ADUAbgBwAGgANAB6AHYAdgBJAHoAbQBpAEoAYgBuAGcA
>> "%~1" echo cgBuAGwAaAA3AHYAcABnAEkAbgBtAGkANgBrAG4ATwAyAFIAeQBiADMAQQB1AGMA
>> "%~1" echo WABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBpAGcAbgBJADIAUgB5AGIA
>> "%~1" echo MwBCAEkAYQBXADUAMABKAHkAawB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkASgArAGEAYwByAE8AVwBjAHMATwBTADQAaQB1AFMAOABvAE8AVwBRAGoA
>> "%~1" echo dQBlAFUAcwBTAEIAQgBSAEUASQBnADUAYQA2AEoANgBLAE8ARgA1AFkAaQB3ADUA
>> "%~1" echo YgBlAHkANgBMACsAZQA1AG8ANgBsADUANQBxAEUASQBGAEYAMQBaAFgATgAwADQA
>> "%~1" echo NABDAEMANQBhADYASgA2AEsATwBGADUAWQBtAE4ANQBMAHkAYQA1AEwAcQBNADUA
>> "%~1" echo cQB5AGgANQA2AEcAdQA2AEsANgBrADQANABDAEMASgAzADEAOQBPAHcAMABLAEkA
>> "%~1" echo QwBCADQAYQBIAEkAdQBiADIANQBsAGMAbgBKAHYAYwBqADAAbwBLAFQAMAArAGUA
>> "%~1" echo MwBOAGwAZABFAEoAMQBjADMAawBvAFoAbQBGAHMAYwAyAFUAcwBiAG4AVgBzAGIA
>> "%~1" echo QwBrADcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGsAdQBJAHIAawB2AEsARABsAHAA
>> "%~1" echo TABIAG8AdABLAFUAbgBMAEMAZgBuAHYAWgBIAG4AdQA1AHoAcABsAEoAbgBvAHIA
>> "%~1" echo NgA4AG4ATABDAGQAbABjAG4ASQBuAEsAVAB0AGsAYwBtADkAdwBMAG4ARgAxAFoA
>> "%~1" echo WABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBJAG8ASgAyAEkAbgBLAFMANQAwAFoA
>> "%~1" echo WABoADAAUQAyADkAdQBkAEcAVgB1AGQARAAwAG4ANQBvAHUAVwA1AG8AdQA5AEkA
>> "%~1" echo RQBGAFEAUwB5AEQAbABpAEwARABvAHYANQBuAHAAaAA0AHoAdgB2AEkAegBtAGkA
>> "%~1" echo SgBiAG4AZwByAG4AbABoADcAdgBwAGcASQBuAG0AaQA2AGsAbgBmAFQAcwBOAEMA
>> "%~1" echo aQBBAGcAZQBHAGgAeQBMAG4ATgBsAGIAbQBRAG8AWgBtAGwAcwBaAFMAawA3AEQA
>> "%~1" echo UQBwADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAegBhAEcAOQAzAFEA
>> "%~1" echo WABCAHIASwBIAEkAcABlAHcAMABLAEkAQwBBAHYATAB5AEIAbwBaAFgASgB2AEQA
>> "%~1" echo UQBvAGcASQBHAE4AdgBiAG4ATgAwAEkARwBsAHUAYQBYAFIAcABZAFcAdwA5AEsA
>> "%~1" echo SABJAHUAYwBHAEYAagBhADIARgBuAFoAWAB4ADgAYwBpADUAbQBhAFcAeABsAFQA
>> "%~1" echo bQBGAHQAWgBYAHgAOABKADAARQBuAEsAUwA1AHkAWgBYAEIAcwBZAFcATgBsAEsA
>> "%~1" echo QwA5AGUATABpAHAAYwBMAGkAOABzAEoAeQBjAHAATABtAE4AbwBZAFgASgBCAGQA
>> "%~1" echo QwBnAHcASwBTADUAMABiADEAVgB3AGMARwBWAHkAUQAyAEYAegBaAFMAZwBwAGYA
>> "%~1" echo SAB3AG4AUQBTAGMANwBEAFEAbwBnAEkAQwBRAG8ASgAyAEYAdwBhADAAbABqAGIA
>> "%~1" echo MgA1AFUAYQBXAHgAbABKAHkAawB1AGEAVwA1AHUAWgBYAEoASQBWAEUAMQBNAFAA
>> "%~1" echo UwBjADgAYwAzAFoAbgBJAEgAWgBwAFoAWABkAEMAYgAzAGcAOQBJAGoAQQBnAE0A
>> "%~1" echo QwBBAHkATgBDAEEAeQBOAEMASQArAFAASABWAHoAWgBTAEIAbwBjAG0AVgBtAFAA
>> "%~1" echo UwBJAGoAYQBTADEAaABjAEcAcwBpAEwAegA0ADgATAAzAE4AMgBaAHoANABuAE8A
>> "%~1" echo dwAwAEsASQBDAEIAegBaAFgAUQBvAEoAMgBGAHcAYQAwADUAaABiAFcAVQBuAEwA
>> "%~1" echo SABJAHUAYwBHAEYAagBhADIARgBuAFoAWAB4ADgAYwBpADUAbQBhAFcAeABsAFQA
>> "%~1" echo bQBGAHQAWgBYAHgAOABKADIARgB3AGMAQwA1AGgAYwBHAHMAbgBLAFQAcwBOAEMA
>> "%~1" echo aQBBAGcATAB5ADgAZwBjAEcAbABzAGIASABNADYASQBIAFoAbABjAG4ATgBwAGIA
>> "%~1" echo MgA0AHMASQBIAE4AcABlAG0AVQBzAEkASABCAGwAYwBtADAAdABZADIAOQAxAGIA
>> "%~1" echo bgBRAE4AQwBpAEEAZwBZADIAOQB1AGMAMwBRAGcAYwBHAFYAeQBiAFgATQA5AEsA
>> "%~1" echo SABJAHUAYwBHAFYAeQBiAFcAbAB6AGMAMgBsAHYAYgBuAE4AOABmAEMAYwBuAEsA
>> "%~1" echo UwA1AHoAYwBHAHgAcABkAEMAZwBuAFgARwA0AG4ASwBTADUAbQBhAFcAeAAwAFoA
>> "%~1" echo WABJAG8AZQBEADAAKwBlAEMAawA3AEQAUQBvAGcASQBHAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo SABCAGoAUABYAEkAdQBjAEcAVgB5AGIAVwBsAHoAYwAyAGwAdgBiAGsATgB2AGQA
>> "%~1" echo VwA1ADAAZgBIAHgAdwBaAFgASgB0AGMAeQA1AHMAWgBXADUAbgBkAEcAaAA4AGYA
>> "%~1" echo RABBADcARABRAG8AZwBJAEcAeABsAGQAQwBCAHcAYQBXAHgAcwBjAHoAMABuAEoA
>> "%~1" echo egBzAE4AQwBpAEEAZwBhAFcAWQBvAGMAaQA1ADIAWgBYAEoAegBhAFcAOQB1AFQA
>> "%~1" echo bQBGAHQAWgBYAHgAOABjAGkANQAyAFoAWABKAHoAYQBXADkAdQBRADIAOQBrAFoA
>> "%~1" echo UwBsAHcAYQBXAHgAcwBjAHkAcwA5AEoAegB4AHoAYwBHAEYAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAdwBhAFcAeABzAEkASABaAGwAYwBpAEkAKwBkAGkAYwByAFoA
>> "%~1" echo WABOAGoASwBIAEkAdQBkAG0AVgB5AGMAMgBsAHYAYgBrADUAaABiAFcAVgA4AGYA
>> "%~1" echo QwBjAC8ASgB5AGsAcgBLAEgASQB1AGQAbQBWAHkAYwAyAGwAdgBiAGsATgB2AFoA
>> "%~1" echo RwBVAC8ASgB5AEEAbwBKAHkAdABsAGMAMgBNAG8AYwBpADUAMgBaAFgASgB6AGEA
>> "%~1" echo VwA5AHUAUQAyADkAawBaAFMAawByAEoAeQBrAG4ATwBpAGMAbgBLAFMAcwBuAFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGkAYwA3AEQAUQBvAGcASQBHAGwAbQBLAEgASQB1AGMA
>> "%~1" echo MgBsADYAWgBWAFIAbABlAEgAUQBwAGMARwBsAHMAYgBIAE0AcgBQAFMAYwA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAYwBHAGwAcwBiAEMASQArAEoA
>> "%~1" echo eQB0AGwAYwAyAE0AbwBjAGkANQB6AGEAWABwAGwAVgBHAFYANABkAEMAawByAEoA
>> "%~1" echo egB3AHYAYwAzAEIAaABiAGoANABuAE8AdwAwAEsASQBDAEIAdwBhAFcAeABzAGMA
>> "%~1" echo eQBzADkASgB6AHgAegBjAEcARgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgB3AGEA
>> "%~1" echo VwB4AHMASQBIAEIAbABjAG0AMABpAEkARwBsAGsAUABTAEoAdwBaAFgASgB0AFUA
>> "%~1" echo RwBsAHMAYgBDAEkAKwA1AHAAMgBEADYAWgBtAFEASQBDAGMAcgBjAEcATQByAEoA
>> "%~1" echo egB3AHYAYwAzAEIAaABiAGoANABuAE8AdwAwAEsASQBDAEIAcABaAGkAaAB5AEwA
>> "%~1" echo bgBCAGgAYwBuAE4AbABUADIAcwBoAFAAVAAwAG4AZABIAEoAMQBaAFMAYwBwAGMA
>> "%~1" echo RwBsAHMAYgBIAE0AcgBQAFMAYwA4AGMAMwBCAGgAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYwBHAGwAcwBiAEMAQgAzAFkAWABKAHUASQBqADcAbwBwADYAUABtAG4A
>> "%~1" echo cABEAGwAagA1AGYAcABtAFoAQQA4AEwAMwBOAHcAWQBXADQAKwBKAHoAcwBOAEMA
>> "%~1" echo aQBBAGcASgBDAGcAbgBZAFgAQgByAFUARwBsAHMAYgBIAE0AbgBLAFMANQBwAGIA
>> "%~1" echo bQA1AGwAYwBrAGgAVQBUAFUAdwA5AGMARwBsAHMAYgBIAE0ANwBEAFEAbwBnAEkA
>> "%~1" echo QwA4AHYASQBIAFoAbABjAG4ATgBwAGIAMgA0AGcAWQBtAEYAawBaADIAVQBnAEsA
>> "%~1" echo SABWAHcAWgAzAEoAaABaAEcAVQB2AFoARwA5ADMAYgBtAGQAeQBZAFcAUgBsAEwA
>> "%~1" echo MwBOAGgAYgBXAFUAcABEAFEAbwBnAEkARwBOAHYAYgBuAE4AMABJAEcASgBoAFoA
>> "%~1" echo RwBkAGwAUABTAFEAbwBKADIARgB3AGEAMQBaAGwAYwBrAEoAaABaAEcAZABsAEoA
>> "%~1" echo eQBrADcAWQBtAEYAawBaADIAVQB1AFkAMgB4AGgAYwAzAE4ATwBZAFcAMQBsAFAA
>> "%~1" echo UwBkADIAWgBYAEoAQwBZAFcAUgBuAFoAUwBjADcARABRAG8AZwBJAEcAbABtAEsA
>> "%~1" echo SABJAHUAWQBXAHgAeQBaAFcARgBrAGUAVQBsAHUAYwAzAFIAaABiAEcAeABsAFoA
>> "%~1" echo RAAwADkAUABTAGQAMABjAG4AVgBsAEoAeQBsADcARABRAG8AZwBJAEMAQQBnAFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBhAFgAWQA5AGMARwBGAHkAYwAyAFYASgBiAG4AUQBvAGMA
>> "%~1" echo aQA1AHAAYgBuAE4AMABZAFcAeABzAFoAVwBSAFcAWgBYAEoAegBhAFcAOQB1AFEA
>> "%~1" echo MgA5AGsAWgBYAHgAOABKAHoAQQBuAEwARABFAHcASwBTAHgAdQBkAGoAMQB3AFkA
>> "%~1" echo WABKAHoAWgBVAGwAdQBkAEMAaAB5AEwAbgBaAGwAYwBuAE4AcABiADIANQBEAGIA
>> "%~1" echo MgBSAGwAZgBIAHcAbgBNAEMAYwBzAE0AVABBAHAATwB3ADAASwBJAEMAQQBnAEkA
>> "%~1" echo RwBsAG0ASwBHADUAMgBKAGkAWgBwAGQAaQBsADcAYQBXAFkAbwBiAG4AWQA4AGEA
>> "%~1" echo WABZAHAAZQAyAEoAaABaAEcAZABsAEwAbQBOAHMAWQBYAE4AegBUAG0ARgB0AFoA
>> "%~1" echo VAAwAG4AZABtAFYAeQBRAG0ARgBrAFoAMgBVAGcAYwAyAGgAdgBkAHkAQgBrAGIA
>> "%~1" echo MwBkAHUASgB6AHQAaQBZAFcAUgBuAFoAUwA1ADAAWgBYAGgAMABRADIAOQB1AGQA
>> "%~1" echo RwBWAHUAZABEADAAbgA0AHAAcQBnAEkATwBtAFoAagBlAGUANgBwACsAKwA4AG0A
>> "%~1" echo dQBpAHUAdgB1AFcAawBoAHkAQgAyAEoAeQB0AHAAZABpAHMAbgBJAE8ASwBHAGsA
>> "%~1" echo aQBCAEIAVQBFAHMAZwBkAGkAYwByAGIAbgBZAHIASgArACsAOABpAE8AbQA3AG0A
>> "%~1" echo TwBpAHUAcABPAFcAMwBzAHUAVwBMAHYAdQBtAEEAaQBlAFcARgBnAGUAaQB1AHUA
>> "%~1" echo TwBtAFoAagBlAGUANgBwACsAKwA4AGkAUwBjADcASgBDAGcAbgBiADMAQgAwAFIA
>> "%~1" echo RwA5ADMAYgBtAGQAeQBZAFcAUgBsAEoAeQBrAHUAWQAyAGgAbABZADIAdABsAFoA
>> "%~1" echo RAAxADAAYwBuAFYAbABmAFEAMABLAEkAQwBBAGcASQBDAEEAZwBaAFcAeAB6AFoA
>> "%~1" echo UwBCAHAAWgBpAGgAdQBkAGoAMAA5AFAAVwBsADIASwBYAHQAaQBZAFcAUgBuAFoA
>> "%~1" echo UwA1AGoAYgBHAEYAegBjADAANQBoAGIAVwBVADkASgAzAFoAbABjAGsASgBoAFoA
>> "%~1" echo RwBkAGwASQBIAE4AbwBiADMAYwBuAE8AMgBKAGgAWgBHAGQAbABMAG4AUgBsAGUA
>> "%~1" echo SABSAEQAYgAyADUAMABaAFcANQAwAFAAUwBmAG4AaQBZAGoAbQBuAEsAegBuAG0A
>> "%~1" echo NwBqAGwAawBJAHcAZwBkAGkAYwByAGEAWABZAHIASgArACsAOABpAE8AbQBIAGoA
>> "%~1" echo ZQBpAGoAaABlAFMALwBuAGUAZQBWAG0AZQBhAFYAcwBPAGEATgByAHUAKwA4AGkA
>> "%~1" echo UwBkADkARABRAG8AZwBJAEMAQQBnAEkAQwBCAGwAYgBIAE4AbABlADIASgBoAFoA
>> "%~1" echo RwBkAGwATABtAE4AcwBZAFgATgB6AFQAbQBGAHQAWgBUADAAbgBkAG0AVgB5AFEA
>> "%~1" echo bQBGAGsAWgAyAFUAZwBjADIAaAB2AGQAeQBCADEAYwBDAGMANwBZAG0ARgBrAFoA
>> "%~1" echo MgBVAHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBKACsAVwBOAGgA
>> "%~1" echo KwBlADYAcAArACsAOABtAHUAaQB1AHYAdQBXAGsAaAB5AEIAMgBKAHkAdABwAGQA
>> "%~1" echo aQBzAG4ASQBPAEsARwBrAGkAQgBCAFUARQBzAGcAZABpAGMAcgBiAG4AWgA5AGYA
>> "%~1" echo UQAwAEsASQBDAEEAZwBJAEcAVgBzAGMAMgBWADcAWQBtAEYAawBaADIAVQB1AFkA
>> "%~1" echo MgB4AGgAYwAzAE4ATwBZAFcAMQBsAFAAUwBkADIAWgBYAEoAQwBZAFcAUgBuAFoA
>> "%~1" echo UwBCAHoAYQBHADkAMwBKAHoAdABpAFkAVwBSAG4AWgBTADUAMABaAFgAaAAwAFEA
>> "%~1" echo MgA5AHUAZABHAFYAdQBkAEQAMABuADYASwA2ACsANQBhAFMASAA1AGIAZQB5ADUA
>> "%~1" echo YQA2AEoANgBLAE8ARgBJAEgAWQBuAEsAMgBWAHoAWQB5AGgAeQBMAG0AbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgAbABaAEYAWgBsAGMAbgBOAHAAYgAyADUARABiADIAUgBsAEsA
>> "%~1" echo WAAwAE4AQwBpAEEAZwBJAEMAQQBrAEsAQwBkAHYAYwBIAFIAUwBaAFgAQgBzAFkA
>> "%~1" echo VwBOAGwASgB5AGsAdQBZADIAaABsAFkAMgB0AGwAWgBEADEAMABjAG4AVgBsAE8A
>> "%~1" echo dwAwAEsASQBDAEIAOQBEAFEAbwBnAEkAQwBRAG8ASgAyAEYAdwBhADEAQgBsAGMA
>> "%~1" echo bQAxAHoASgB5AGsAdQBkAEcAVgA0AGQARQBOAHYAYgBuAFIAbABiAG4AUQA5AGMA
>> "%~1" echo RwBWAHkAYgBYAE0AdQBiAEcAVgB1AFoAMwBSAG8AUAAzAEIAbABjAG0AMQB6AEwA
>> "%~1" echo bQBwAHYAYQBXADQAbwBKADEAeAB1AEoAeQBrADYASgArACsAOABpAE8AYQBjAHEA
>> "%~1" echo dQBpAG4AbwArAGEAZQBrAE8AVwBJAHMATwBhAGQAZwArAG0AWgBrAE8AVwBqAHMA
>> "%~1" echo TwBhAFkAagB1ACsAOABpAFMAYwA3AEQAUQBvAGcASQBDAFEAbwBKADIARgB3AGEA
>> "%~1" echo MQBCAGwAYwBtADEAegBKAHkAawB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwA
>> "%~1" echo bgBKAGwAYgBXADkAMgBaAFMAZwBuAGMAMgBoAHYAZAB5AGMAcABPAHcAMABLAEkA
>> "%~1" echo QwBBAGsASwBDAGQAaABjAEcAdABFAGMAbQA5AHcASgB5AGsAdQBjADMAUgA1AGIA
>> "%~1" echo RwBVAHUAWgBHAGwAegBjAEcAeABoAGUAVAAwAG4AYgBtADkAdQBaAFMAYwA3AEQA
>> "%~1" echo UQBvAGcASQBDAFEAbwBKADIARgB3AGEAMABSAGwAZABHAEYAcABiAEMAYwBwAEwA
>> "%~1" echo bgBOADAAZQBXAHgAbABMAG0AUgBwAGMAMwBCAHMAWQBYAGsAOQBKAHkAYwA3AEQA
>> "%~1" echo UQBwADkARABRAHAAaABjADMAbAB1AFkAeQBCAG0AZABXADUAagBkAEcAbAB2AGIA
>> "%~1" echo aQBCAHAAYgBuAE4AMABZAFcAeABzAFEAWABCAHIASwBDAGwANwBEAFEAbwBnAEkA
>> "%~1" echo RwBsAG0ASwBDAEYAaABjAEcAdAA4AGYAQwBGAGgAYwBHAHMAdQBkAFgAQgBzAGIA
>> "%~1" echo MgBGAGsAUwBXAFEAcABjAG0AVgAwAGQAWABKAHUASQBHADUAdgBkAEcAbABtAGUA
>> "%~1" echo UwBnAG4ANgBLACsAMwA1AFkAVwBJADUATABpAEsANQBMAHkAZwBJAEUARgBRAFMA
>> "%~1" echo eQBjAHMASgArAGEATABsAHUAVwBGAHAAZQBhAEkAbAB1AG0AQQBpAGUAYQBMAHEA
>> "%~1" echo ZQBTADQAZwBPAFMANABxAGkAQQB1AFkAWABCAHIASQBPAGEAVwBoACsAUwA3AHQA
>> "%~1" echo dQBPAEEAZwBpAGMAcwBKADMAZABoAGMAbQA0AG4ASwBUAHMATgBDAGkAQQBnAGEA
>> "%~1" echo VwBZAG8AWQBuAFYAegBlAFMAbAB5AFoAWABSADEAYwBtADQAZwBiAG0AOQAwAGEA
>> "%~1" echo VwBaADUASwBDAGYAbAB0ADcATABtAG4ASQBuAG0AawA0ADMAawB2AFoAegBtAGkA
>> "%~1" echo YQBmAG8AbwBZAHoAawB1AEsAMABuAEwAQwBmAG8AcgA3AGYAbgByAFkAbgBsAHYA
>> "%~1" echo bwBYAGsAdQBJAHIAawB1AEkARABtAG4AYQBIAGwAawBiADMAawB1ADYAVABsAHIA
>> "%~1" echo bwB6AG0AaQBKAEQAagBnAEkASQBuAEwAQwBkADMAWQBYAEoAdQBKAHkAawA3AEQA
>> "%~1" echo UQBvAGcASQBHAE4AdgBiAG4ATgAwAEkASABJADkAWQBYAEIAcgBPAHcAMABLAEkA
>> "%~1" echo QwBCAGoAYgAyADUAegBkAEMAQgB2AGMASABSAHoAUABWAHQAZABPADIAbABtAEsA
>> "%~1" echo QwBRAG8ASgAyADkAdwBkAEYASgBsAGMARwB4AGgAWQAyAFUAbgBLAFMANQBqAGEA
>> "%~1" echo RwBWAGoAYQAyAFYAawBLAFcAOQB3AGQASABNAHUAYwBIAFYAegBhAEMAZwBuAEwA
>> "%~1" echo WABJAG4ASwBUAHQAcABaAGkAZwBrAEsAQwBkAHYAYwBIAFIASABjAG0ARgB1AGQA
>> "%~1" echo QwBjAHAATABtAE4AbwBaAFcATgByAFoAVwBRAHAAYgAzAEIAMABjAHkANQB3AGQA
>> "%~1" echo WABOAG8ASwBDAGMAdABaAHkAYwBwAE8AMgBsAG0ASwBDAFEAbwBKADIAOQB3AGQA
>> "%~1" echo RQBSAHYAZAAyADUAbgBjAG0ARgBrAFoAUwBjAHAATABtAE4AbwBaAFcATgByAFoA
>> "%~1" echo VwBRAHAAYgAzAEIAMABjAHkANQB3AGQAWABOAG8ASwBDAGMAdABaAEMAYwBwAE8A
>> "%~1" echo dwAwAEsASQBDAEIAagBiADIANQB6AGQAQwBCADEAWgBqADAAawBLAEMAZAB2AGMA
>> "%~1" echo SABSAFYAYgBtAGwAdQBjADMAUgBoAGIARwB4AEcAYQBYAEoAegBkAEMAYwBwAEwA
>> "%~1" echo bQBOAG8AWgBXAE4AcgBaAFcAUQA3AEQAUQBvAGcASQBHAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo RwBOAHQAWgBEADAAbgBZAFcAUgBpAEkAQwAxAHoASQBEAHgAawBaAFgAWgBwAFkA
>> "%~1" echo MgBVACsASQBHAGwAdQBjADMAUgBoAGIARwB3AGcASgB5AHQAdgBjAEgAUgB6AEwA
>> "%~1" echo bQBwAHYAYQBXADQAbwBKAHkAQQBuAEsAUwBzAG4ASQBDAGMAcgBLAEgASQB1AFoA
>> "%~1" echo bQBsAHMAWgBVADUAaABiAFcAVgA4AGYAQwBkAGgAYwBIAEEAdQBZAFgAQgByAEoA
>> "%~1" echo eQBrADcARABRAG8AZwBJAEcATgB2AGIAbgBOADAASQBHADEAegBaAHoAMABuADUA
>> "%~1" echo WQAyAHoANQBiAEMARwA1AG8AbQBuADYASwBHAE0ANwA3AHkAYQBYAEcANABuAEsA
>> "%~1" echo MgBOAHQAWgBDAHMAbwBkAFcAWQAvAEoAMQB4AHUANwA3AHkASQA1AGEANgBKADYA
>> "%~1" echo SwBPAEYANQBZAG0ATgA1AEwAeQBhADUAWQBXAEkANQBZADIANAA2AEwAMgA5AEkA
>> "%~1" echo QwBjAHIASwBIAEkAdQBjAEcARgBqAGEAMgBGAG4AWgBYAHgAOABKACsAaQB2AHAA
>> "%~1" echo ZQBXAE0AaABTAGMAcABLAHkAZgB2AHYASQB6AG0AdQBJAFgAcABtAGEAVABsAGgA
>> "%~1" echo YgBiAG0AbABiAEQAbQBqAGEANwB2AHYASQBrAG4ATwBpAGMAbgBLAFMAcwBuAFgA
>> "%~1" echo RwA1AGMAYgB1AGUAYgByAHUAYQBnAGgAKwArADgAbQBpAGMAcgBLAEgASQB1AGMA
>> "%~1" echo RwBGAGoAYQAyAEYAbgBaAFgAeAA4AEoAKwBhAGMAcQB1AGUAZgBwAGUAVwBNAGgA
>> "%~1" echo ZQBXAFEAagBTAGMAcABLAHkAYwBnAEkAQwBjAHIASwBIAEkAdQBkAG0AVgB5AGMA
>> "%~1" echo MgBsAHYAYgBrADUAaABiAFcAVgA4AGYAQwBjAG4ASwBUAHMATgBDAGkAQQBnAFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBiADIAcwA5AFkAWABkAGgAYQBYAFEAZwBZAFgATgByAFEA
>> "%~1" echo MgA5AHUAWgBtAGwAeQBiAFMAZwBuADUANgBHAHUANgBLADYAawA1AGEANgBKADYA
>> "%~1" echo SwBPAEYASQBFAEYAUQBTAHkAYwBzAGIAWABOAG4ASwBUAHMATgBDAGkAQQBnAGEA
>> "%~1" echo VwBZAG8ASQBXADkAcgBLAFgASgBsAGQASABWAHkAYgBqAHMATgBDAGkAQQBnAFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBZAG4AUgB1AFAAUwBRAG8ASgAyAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AEMAZABHADQAbgBLAFMAeABtAGEAVwB4AHMAUABTAFEAbwBKADIAbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgARwBhAFcAeABzAEoAeQBrAHMAYgBHAEYAaQBaAFcAdwA5AEoA
>> "%~1" echo QwBnAG4AYQBXADUAegBkAEcARgBzAGIARQB4AGgAWQBtAFYAcwBKAHkAawBzAGMA
>> "%~1" echo MwBSAGgAWgAyAFYAUwBiADMAYwA5AEoAQwBnAG4AYwAzAFIAaABaADIAVgBTAGIA
>> "%~1" echo MwBjAG4ASwBTAHgAdgBkAFgAUQA5AEoAQwBnAG4AWQBXAFIAaQBUADMAVgAwAEoA
>> "%~1" echo eQBrADcARABRAG8AZwBJAEMAOAB2AEkARwBWAHUAZABHAFYAeQBJAEcAbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHgAcABiAG0AYwBnAGMAMwBSAGgAZABHAFUANgBJAEcASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAEIAdABiADMASgB3AGEASABNAGcAYQBXADUAMABiAHkAQgBoAEkA
>> "%~1" echo SABCAHkAYgAyAGQAeQBaAFgATgB6AEkASABSAHkAWQBXAE4AcgBEAFEAbwBnAEkA
>> "%~1" echo SABOAGwAZABFAEoAMQBjADMAawBvAGQASABKADEAWgBTAHgAdQBkAFcAeABzAEsA
>> "%~1" echo VAB0AGkAZABHADQAdQBaAEcAbAB6AFkAVwBKAHMAWgBXAFEAOQBkAEgASgAxAFoA
>> "%~1" echo VAB0AGkAZABHADQAdQBZADIAeABoAGMAMwBOAE8AWQBXADEAbABQAFMAZABwAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBRAG4AUgB1AEkARwBsAHUAYwAzAFIAaABiAEcAeABwAGIA
>> "%~1" echo bQBjAG4ATwAyAFoAcABiAEcAdwB1AGMAMwBSADUAYgBHAFUAdQBkADIAbABrAGQA
>> "%~1" echo RwBnADkASgB6AEEAbgBPAHcAMABLAEkAQwBCAHMAWQBXAEoAbABiAEMANQAwAFoA
>> "%~1" echo WABoADAAUQAyADkAdQBkAEcAVgB1AGQARAAwAG4ANQBhADYASgA2AEsATwBGADUA
>> "%~1" echo TABpAHQASQBEAEEAbABKAHoAdAB6AGQARwBGAG4AWgBWAEoAdgBkAHkANQBqAGIA
>> "%~1" echo RwBGAHoAYwAwAHgAcABjADMAUQB1AFkAVwBSAGsASwBDAGQAegBhAEcAOQAzAEoA
>> "%~1" echo eQBrADcAYwAyAFYAMABLAEMAZAB6AGQARwBGAG4AWgBWAFIAbABlAEgAUQBuAEwA
>> "%~1" echo QwBmAG8AdgA1ADcAbQBqAHEAWABrAHUASwAzAGkAZwBLAFkAbgBLAFQAdAB2AGQA
>> "%~1" echo WABRAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABtAEYAawBaAEMAZwBuAGMA
>> "%~1" echo MgBoAHYAZAB5AGMAcABPADIAOQAxAGQAQwA1ADAAWgBYAGgAMABRADIAOQB1AGQA
>> "%~1" echo RwBWAHUAZABEADAAbgBKAHoAcwBOAEMAaQBBAGcAWQAyADkAdQBjADMAUQBnAGQA
>> "%~1" echo RABBADkAUgBHAEYAMABaAFMANQB1AGIAMwBjAG8ASwBUAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCADAAYQBXADEAbABjAGoAMQB6AFoAWABSAEoAYgBuAFIAbABjAG4AWgBoAGIA
>> "%~1" echo QwBnAG8ASwBUADAAKwBlADIATgB2AGIAbgBOADAASQBIAE0AOQBUAFcARgAwAGEA
>> "%~1" echo QwA1AG0AYgBHADkAdgBjAGkAZwBvAFIARwBGADAAWgBTADUAdQBiADMAYwBvAEsA
>> "%~1" echo UwAxADAATQBDAGsAdgBNAFQAQQB3AE0AQwBrADcAYwAyAFYAMABLAEMAZABsAGIA
>> "%~1" echo RwBGAHcAYwAyAFYAawBKAHkAeABOAFkAWABSAG8ATABtAFoAcwBiADIAOQB5AEsA
>> "%~1" echo SABNAHYATgBqAEEAcABLAHkAYwA2AEoAeQB0AFQAZABIAEoAcABiAG0AYwBvAGMA
>> "%~1" echo eQBVADIATQBDAGsAdQBjAEcARgBrAFUAMwBSAGgAYwBuAFEAbwBNAGkAdwBuAE0A
>> "%~1" echo QwBjAHAASwBYADAAcwBNAGoAVQB3AEsAVABzAE4AQwBpAEEAZwBiAEcAVgAwAEkA
>> "%~1" echo RwBOADEAYwBsAEIAagBkAEQAMAB3AE8AdwAwAEsASQBDAEIAbQBkAFcANQBqAGQA
>> "%~1" echo RwBsAHYAYgBpAEIAegBaAFgAUgBRAFkAMwBRAG8AYwBDAGwANwBZADMAVgB5AFUA
>> "%~1" echo RwBOADAAUABVADEAaABkAEcAZwB1AGIAVwBGADQASwBHAE4AMQBjAGwAQgBqAGQA
>> "%~1" echo QwB4AHcASwBUAHQAbQBhAFcAeABzAEwAbgBOADAAZQBXAHgAbABMAG4AZABwAFoA
>> "%~1" echo SABSAG8AUABXAE4AMQBjAGwAQgBqAGQAQwBzAG4ASgBTAGMANwBiAEcARgBpAFoA
>> "%~1" echo VwB3AHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBKACsAVwB1AGkA
>> "%~1" echo ZQBpAGoAaABlAFMANAByAFMAQQBuAEsAMgBOADEAYwBsAEIAagBkAEMAcwBuAEoA
>> "%~1" echo UwBkADkARABRAG8AZwBJAEcAeABsAGQAQwBCAHgAYwB6ADAAbgBMADIARgB3AGEA
>> "%~1" echo UwA5AGgAYwBHAHMAdgBhAFcANQB6AGQARwBGAHMAYgBDADEAegBkAEgASgBsAFkA
>> "%~1" echo VwAwAC8AWQAyADkAdQBaAG0AbAB5AGIAVAAxAFoAUgBWAE0AbQBkAEcAOQByAFoA
>> "%~1" echo VwA0ADkASgB5AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwARABiADIAMQB3AGIA
>> "%~1" echo MgA1AGwAYgBuAFEAbwBWAEUAOQBMAFIAVQA0AHAASwB5AGMAbQBkAFgAQgBzAGIA
>> "%~1" echo MgBGAGsAUwBXAFEAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIA
>> "%~1" echo MgAxAHcAYgAyADUAbABiAG4AUQBvAGMAaQA1ADEAYwBHAHgAdgBZAFcAUgBKAFoA
>> "%~1" echo QwBrADcARABRAG8AZwBJAEgARgB6AEsAegAwAG4ASgBuAEoAbABjAEcAeABoAFkA
>> "%~1" echo MgBVADkASgB5AHMAbwBKAEMAZwBuAGIAMwBCADAAVQBtAFYAdwBiAEcARgBqAFoA
>> "%~1" echo UwBjAHAATABtAE4AbwBaAFcATgByAFoAVwBRAC8ATQBUAG8AdwBLAFMAcwBuAEoA
>> "%~1" echo bQBkAHkAWQBXADUAMABQAFMAYwByAEsAQwBRAG8ASgAyADkAdwBkAEUAZAB5AFkA
>> "%~1" echo VwA1ADAASgB5AGsAdQBZADIAaABsAFkAMgB0AGwAWgBEADgAeABPAGoAQQBwAEsA
>> "%~1" echo eQBjAG0AWgBHADkAMwBiAG0AZAB5AFkAVwBSAGwAUABTAGMAcgBLAEMAUQBvAEoA
>> "%~1" echo MgA5AHcAZABFAFIAdgBkADIANQBuAGMAbQBGAGsAWgBTAGMAcABMAG0ATgBvAFoA
>> "%~1" echo VwBOAHIAWgBXAFEALwBNAFQAbwB3AEsAUwBzAG4ASgBuAFYAdQBhAFcANQB6AGQA
>> "%~1" echo RwBGAHMAYgBFAFoAcABjAG4ATgAwAFAAUwBjAHIASwBIAFYAbQBQAHoARQA2AE0A
>> "%~1" echo QwBrADcARABRAG8AZwBJAEcAbABtAEsASABJAHUAYwBHAEYAagBhADIARgBuAFoA
>> "%~1" echo UwBsAHgAYwB5AHMAOQBKAHkAWgB3AFkAVwBOAHIAWQBXAGQAbABQAFMAYwByAFoA
>> "%~1" echo VwA1AGoAYgAyAFIAbABWAFYASgBKAFEAMgA5AHQAYwBHADkAdQBaAFcANQAwAEsA
>> "%~1" echo SABJAHUAYwBHAEYAagBhADIARgBuAFoAUwBrADcARABRAG8AZwBJAEcANQB2AGQA
>> "%~1" echo RwBsAG0AZQBTAGcAbgA1AGIAeQBBADUAYQBlAEwANQBhADYASgA2AEsATwBGAEoA
>> "%~1" echo eQB4AHkATABuAEIAaABZADIAdABoAFoAMgBWADgAZgBIAEkAdQBaAG0AbABzAFoA
>> "%~1" echo VQA1AGgAYgBXAFUAcwBKADMAZABoAGMAbQA0AG4ATABEAEkAdwBNAEQAQQBwAE8A
>> "%~1" echo dwAwAEsASQBDAEIAagBiADIANQB6AGQAQwBCAGwAYwB6ADEAdQBaAFgAYwBnAFIA
>> "%~1" echo WABaAGwAYgBuAFIAVABiADMAVgB5AFkAMgBVAG8AYwBYAE0AcABPAHcAMABLAEkA
>> "%~1" echo QwBCAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAGgAYwBIAEIAbABiAG0AUgBQAGQA
>> "%~1" echo WABRAG8AYgBHAGwAdQBaAFMAbAA3AGIAMwBWADAATABuAFIAbABlAEgAUgBEAGIA
>> "%~1" echo MgA1ADAAWgBXADUAMABLAHoAMABvAGIAMwBWADAATABuAFIAbABlAEgAUgBEAGIA
>> "%~1" echo MgA1ADAAWgBXADUAMABQAHkAZABjAGIAaQBjADYASgB5AGMAcABLADIAeABwAGIA
>> "%~1" echo bQBVADcAYgAzAFYAMABMAG4ATgBqAGMAbQA5AHMAYgBGAFIAdgBjAEQAMQB2AGQA
>> "%~1" echo WABRAHUAYwAyAE4AeQBiADIAeABzAFMARwBWAHAAWgAyAGgAMABmAFEAMABLAEkA
>> "%~1" echo QwBCAGwAYwB5ADUAaABaAEcAUgBGAGQAbQBWAHUAZABFAHgAcABjADMAUgBsAGIA
>> "%~1" echo bQBWAHkASwBDAGQAegBkAEcARgBuAFoAUwBjAHMAWgBUADAAKwBlADMAUgB5AGUA
>> "%~1" echo WAB0AGoAYgAyADUAegBkAEMAQgBrAFAAVQBwAFQAVAAwADQAdQBjAEcARgB5AGMA
>> "%~1" echo MgBVAG8AWgBTADUAawBZAFgAUgBoAEsAVAB0AHoAWgBYAFEAbwBKADMATgAwAFkA
>> "%~1" echo VwBkAGwAVgBHAFYANABkAEMAYwBzAFoAQwA1ADAAWgBYAGgAMABmAEgAdwBuAEoA
>> "%~1" echo eQBrADcAYQBXAFkAbwBaAEMANQB3AFoAWABKAGoAWgBXADUAMABLAFgATgBsAGQA
>> "%~1" echo RgBCAGoAZABDAGgAdwBZAFgASgB6AFoAVQBsAHUAZABDAGgAawBMAG4AQgBsAGMA
>> "%~1" echo bQBOAGwAYgBuAFEAcwBNAFQAQQBwAGYASAB3AHcASwBYADEAagBZAFgAUgBqAGEA
>> "%~1" echo QwBoAGYASwBYAHQAOQBmAFMAawA3AEQAUQBvAGcASQBHAFYAegBMAG0ARgBrAFoA
>> "%~1" echo RQBWADIAWgBXADUAMABUAEcAbAB6AGQARwBWAHUAWgBYAEkAbwBKADIAOQAxAGQA
>> "%~1" echo SABCADEAZABDAGMAcwBaAFQAMAArAGUAMwBSAHkAZQBYAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAGsAUABVAHAAVABUADAANAB1AGMARwBGAHkAYwAyAFUAbwBaAFMANQBrAFkA
>> "%~1" echo WABSAGgASwBUAHQAcABaAGkAaABrAEwAbQB4AHAAYgBtAFUAcABZAFgAQgB3AFoA
>> "%~1" echo VwA1AGsAVAAzAFYAMABLAEcAUQB1AGIARwBsAHUAWgBTAGwAOQBZADIARgAwAFkA
>> "%~1" echo MgBnAG8AWAB5AGwANwBmAFgAMABwAE8AdwAwAEsASQBDAEIAbABjAHkANQBoAFoA
>> "%~1" echo RwBSAEYAZABtAFYAdQBkAEUAeABwAGMAMwBSAGwAYgBtAFYAeQBLAEMAZABrAGIA
>> "%~1" echo MgA1AGwASgB5AHgAbABQAFQANQA3AEQAUQBvAGcASQBDAEEAZwBaAFgATQB1AFkA
>> "%~1" echo MgB4AHYAYwAyAFUAbwBLAFQAdABqAGIARwBWAGgAYwBrAGwAdQBkAEcAVgB5AGQA
>> "%~1" echo bQBGAHMASwBIAFIAcABiAFcAVgB5AEsAVAB0AHoAWgBYAFIAQwBkAFgATgA1AEsA
>> "%~1" echo RwBaAGgAYgBIAE4AbABMAEcANQAxAGIARwB3AHAATwAyAEoAMABiAGkANQBrAGEA
>> "%~1" echo WABOAGgAWQBtAHgAbABaAEQAMQBtAFkAVwB4AHoAWgBUAHMATgBDAGkAQQBnAEkA
>> "%~1" echo QwBCAHMAWgBYAFEAZwBaAEQAMQA3AGYAVAB0ADAAYwBuAGwANwBaAEQAMQBLAFUA
>> "%~1" echo MAA5AE8ATABuAEIAaABjAG4ATgBsAEsARwBVAHUAWgBHAEYAMABZAFMAbAA5AFkA
>> "%~1" echo MgBGADAAWQAyAGcAbwBYAHkAbAA3AGYAUQAwAEsASQBDAEEAZwBJAEcAbABtAEsA
>> "%~1" echo RwBRAHUAYgAyAHMAOQBQAFQAMABuAGQASABKADEAWgBTAGMAcABlAHcAMABLAEkA
>> "%~1" echo QwBBAGcASQBDAEEAZwBjADIAVgAwAFUARwBOADAASwBEAEUAdwBNAEMAawA3AFkA
>> "%~1" echo bgBSAHUATABtAE4AcwBZAFgATgB6AFQAbQBGAHQAWgBUADAAbgBhAFcANQB6AGQA
>> "%~1" echo RwBGAHMAYgBFAEoAMABiAGkAQgBrAGIAMgA1AGwASgB6AHMATgBDAGkAQQBnAEkA
>> "%~1" echo QwBBAGcASQBHAHgAaABZAG0AVgBzAEwAbQBsAHUAYgBtAFYAeQBTAEYAUgBOAFQA
>> "%~1" echo RAAwAG4AUABIAE4AMgBaAHkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIAaAByAEkA
>> "%~1" echo aQBCADIAYQBXAFYAMwBRAG0AOQA0AFAAUwBJAHcASQBEAEEAZwBNAGoAUQBnAE0A
>> "%~1" echo agBRAGkAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAAMABJAEQARQB5AGIA
>> "%~1" echo RABVAGcATgBXAHcAeABNAFMAMAB4AE0AUwBJAHYAUABqAHcAdgBjADMAWgBuAFAA
>> "%~1" echo aQBEAGwAcgBvAG4AbwBvADQAWABtAGkASgBEAGwAaQBwADgAbgBPAHcAMABLAEkA
>> "%~1" echo QwBBAGcASQBDAEEAZwBjADIAVgAwAEsAQwBkAHoAZABHAEYAbgBaAFYAUgBsAGUA
>> "%~1" echo SABRAG4ATABDAGYAbAByAG8AegBtAGkASgBBAG4ASwBUAHMAawBLAEMAZABoAGMA
>> "%~1" echo SABCAEQAWQBYAEoAawBKAHkAawB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwA
>> "%~1" echo bQBGAGsAWgBDAGcAbgBaADIAeAB2AGQAeQBjAHAATwB3ADAASwBJAEMAQQBnAEkA
>> "%~1" echo QwBBAGcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGwAcgBvAG4AbwBvADQAWABtAGkA
>> "%~1" echo SgBEAGwAaQBwADgAbgBMAEcAUQB1AGIAVwBWAHoAYwAyAEYAbgBaAFgAeAA4AGMA
>> "%~1" echo aQA1AHcAWQBXAE4AcgBZAFcAZABsAGYASAB4AHkATABtAFoAcABiAEcAVgBPAFkA
>> "%~1" echo VwAxAGwATABDAGQAdgBhAHkAYwBzAE4ARABZAHcATQBDAGsANwBjAG0AVgBtAGMA
>> "%~1" echo bQBWAHoAYQBDAGgAbQBZAFcAeAB6AFoAUwBrADcAYgBHADkAaABaAEUAeAB2AFoA
>> "%~1" echo MwBNAG8AWgBtAEYAcwBjADIAVQBwAE8AdwAwAEsASQBDAEEAZwBJAEgAMQBsAGIA
>> "%~1" echo SABOAGwAZQB3ADAASwBJAEMAQQBnAEkAQwBBAGcAWQBuAFIAdQBMAG0ATgBzAFkA
>> "%~1" echo WABOAHoAVABtAEYAdABaAFQAMABuAGEAVwA1AHoAZABHAEYAcwBiAEUASgAwAGIA
>> "%~1" echo aQBCAG0AWQBXAGwAcwBaAFcAUQBuAE8AMgB4AGgAWQBtAFYAcwBMAG4AUgBsAGUA
>> "%~1" echo SABSAEQAYgAyADUAMABaAFcANQAwAFAAUwBmAGwAcgBvAG4AbwBvADQAWABsAHAA
>> "%~1" echo TABIAG8AdABLAFUAbgBPAHcAMABLAEkAQwBBAGcASQBDAEEAZwBjADIAVgAwAEsA
>> "%~1" echo QwBkAHoAZABHAEYAbgBaAFYAUgBsAGUASABRAG4ATABHAFEAdQBiAFcAVgB6AGMA
>> "%~1" echo MgBGAG4AWgBYAHgAOABKACsAVwB1AGkAZQBpAGoAaABlAFcAawBzAGUAaQAwAHAA
>> "%~1" echo UwBjAHAATwB3ADAASwBJAEMAQQBnAEkAQwBBAGcAYgBtADkAMABhAFcAWgA1AEsA
>> "%~1" echo QwBmAGwAcgBvAG4AbwBvADQAWABsAHAATABIAG8AdABLAFUAbgBMAEcAUQB1AGIA
>> "%~1" echo VwBWAHoAYwAyAEYAbgBaAFgAeAA4AEoAKwBXAHUAaQBlAGkAagBoAGUAVwBrAHMA
>> "%~1" echo ZQBpADAAcABTAGMAcwBKADIAVgB5AGMAaQBjAHMATgBqAEEAdwBNAEMAawA3AGIA
>> "%~1" echo RwA5AGgAWgBFAHgAdgBaADMATQBvAFoAbQBGAHMAYwAyAFUAcABPAHcAMABLAEkA
>> "%~1" echo QwBBAGcASQBDAEEAZwBMAHkAOABnAGIARwBWADAASQBIAFIAbwBaAFMAQgAxAGMA
>> "%~1" echo MgBWAHkASQBIAEoAbABkAEgASgA1AE8AaQBCAHkAWgBYAFoAbABjAG4AUQBnAGQA
>> "%~1" echo RwBoAGwASQBHAEoAMQBkAEgAUgB2AGIAaQBCADAAYgB5AEIAcABaAEcAeABsAEkA
>> "%~1" echo RwBGAG0AZABHAFYAeQBJAEcARQBnAGIAVwA5AHQAWgBXADUAMABEAFEAbwBnAEkA
>> "%~1" echo QwBBAGcASQBDAEIAegBaAFgAUgBVAGEAVwAxAGwAYgAzAFYAMABLAEMAZwBwAFAA
>> "%~1" echo VAA1ADcAWQBuAFIAdQBMAG0ATgBzAFkAWABOAHoAVABtAEYAdABaAFQAMABuAGEA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEUASgAwAGIAaQBjADcAYgBHAEYAaQBaAFcAdwB1AGQA
>> "%~1" echo RwBWADQAZABFAE4AdgBiAG4AUgBsAGIAbgBRADkASgArAG0ASABqAGUAaQB2AGwA
>> "%~1" echo ZQBXAHUAaQBlAGkAagBoAFMAYwA3AFoAbQBsAHMAYgBDADUAegBkAEgAbABzAFoA
>> "%~1" echo UwA1ADMAYQBXAFIAMABhAEQAMABuAE0AQwBkADkATABEAEkAMgBNAEQAQQBwAE8A
>> "%~1" echo dwAwAEsASQBDAEEAZwBJAEgAMABOAEMAaQBBAGcAZgBTAGsANwBEAFEAbwBnAEkA
>> "%~1" echo RwBWAHoATABtADkAdQBaAFgASgB5AGIAMwBJADkASwBDAGsAOQBQAG4AdABsAGMA
>> "%~1" echo eQA1AGoAYgBHADkAegBaAFMAZwBwAE8AMgBOAHMAWgBXAEYAeQBTAFcANQAwAFoA
>> "%~1" echo WABKADIAWQBXAHcAbwBkAEcAbAB0AFoAWABJAHAATwAzAE4AbABkAEUASgAxAGMA
>> "%~1" echo MwBrAG8AWgBtAEYAcwBjADIAVQBzAGIAbgBWAHMAYgBDAGsANwBZAG4AUgB1AEwA
>> "%~1" echo bQBSAHAAYwAyAEYAaQBiAEcAVgBrAFAAVwBaAGgAYgBIAE4AbABPADIASgAwAGIA
>> "%~1" echo aQA1AGoAYgBHAEYAegBjADAANQBoAGIAVwBVADkASgAyAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AEMAZABHADQAZwBaAG0ARgBwAGIARwBWAGsASgB6AHQAcwBZAFcASgBsAGIA
>> "%~1" echo QwA1ADAAWgBYAGgAMABRADIAOQB1AGQARwBWAHUAZABEADAAbgA2AEwAKwBlADUA
>> "%~1" echo bwA2AGwANQBMAGkAdAA1AHAAYQB0AEoAegB0AHoAWgBYAFEAbwBKADMATgAwAFkA
>> "%~1" echo VwBkAGwAVgBHAFYANABkAEMAYwBzAEoAKwBTADQAagB1AGEAYwByAE8AVwBjAHMA
>> "%~1" echo TwBhAGMAagBlAFcASwBvAGUAZQBhAGgATwBpAC8AbgB1AGEATwBwAGUAUwA0AHIA
>> "%~1" echo ZQBhAFcAcgBTAGMAcABPADIANQB2AGQARwBsAG0AZQBTAGcAbgA1AGEANgBKADYA
>> "%~1" echo SwBPAEYANQBMAGkAdAA1AHAAYQB0AEoAeQB3AG4AVQAxAE4ARgBJAE8AaQAvAG4A
>> "%~1" echo dQBhAE8AcABlAG0AVQBtAGUAaQB2AHIAeQBjAHMASgAyAFYAeQBjAGkAYwBzAE4A
>> "%~1" echo VABBAHcATQBDAGsANwBjADIAVgAwAFYARwBsAHQAWgBXADkAMQBkAEMAZwBvAEsA
>> "%~1" echo VAAwACsAZQAyAEoAMABiAGkANQBqAGIARwBGAHoAYwAwADUAaABiAFcAVQA5AEoA
>> "%~1" echo MgBsAHUAYwAzAFIAaABiAEcAeABDAGQARwA0AG4ATwAyAHgAaABZAG0AVgBzAEwA
>> "%~1" echo bgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABTAGYAcABoADQAMwBvAHIA
>> "%~1" echo NQBYAGwAcgBvAG4AbwBvADQAVQBuAE8AMgBaAHAAYgBHAHcAdQBjADMAUgA1AGIA
>> "%~1" echo RwBVAHUAZAAyAGwAawBkAEcAZwA5AEoAegBBAG4AZgBTAHcAeQBOAGoAQQB3AEsA
>> "%~1" echo WAAwADcARABRAHAAOQBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgBwAGIA
>> "%~1" echo bQBsADAAUwBXADUAegBkAEcARgBzAGIARwBWAHkASwBDAGwANwBEAFEAbwBnAEkA
>> "%~1" echo RwBOAHYAYgBuAE4AMABJAEcAUgB5AGIAMwBBADkASgBDAGcAbgBZAFgAQgByAFIA
>> "%~1" echo SABKAHYAYwBDAGMAcABMAEcAWgBwAGIARwBVADkASgBDAGcAbgBZAFgAQgByAFIA
>> "%~1" echo bQBsAHMAWgBTAGMAcABPAHcAMABLAEkAQwBCAGsAYwBtADkAdwBMAG0AOQB1AFkA
>> "%~1" echo MgB4AHAAWQAyAHMAOQBLAEMAawA5AFAAbQBaAHAAYgBHAFUAdQBZADIAeABwAFkA
>> "%~1" echo MgBzAG8ASwBUAHMATgBDAGkAQQBnAFoAbQBsAHMAWgBTADUAdgBiAG0ATgBvAFkA
>> "%~1" echo VwA1AG4AWgBUADAAbwBLAFQAMAArAGUAMgBsAG0ASwBHAFoAcABiAEcAVQB1AFoA
>> "%~1" echo bQBsAHMAWgBYAE0AbQBKAG0AWgBwAGIARwBVAHUAWgBtAGwAcwBaAFgATgBiAE0A
>> "%~1" echo RgAwAHAAZABYAEIAcwBiADIARgBrAFEAWABCAHIASwBHAFoAcABiAEcAVQB1AFoA
>> "%~1" echo bQBsAHMAWgBYAE4AYgBNAEYAMABwAE8AMgBaAHAAYgBHAFUAdQBkAG0ARgBzAGQA
>> "%~1" echo VwBVADkASgB5AGQAOQBPAHcAMABLAEkAQwBCAGIASgAyAFIAeQBZAFcAZABsAGIA
>> "%~1" echo bgBSAGwAYwBpAGMAcwBKADIAUgB5AFkAVwBkAHYAZABtAFYAeQBKADEAMAB1AFoA
>> "%~1" echo bQA5AHkAUgBXAEYAagBhAEMAaABsAGQAagAwACsAWgBIAEoAdgBjAEMANQBoAFoA
>> "%~1" echo RwBSAEYAZABtAFYAdQBkAEUAeABwAGMAMwBSAGwAYgBtAFYAeQBLAEcAVgAyAEwA
>> "%~1" echo RwBVADkAUABuAHQAbABMAG4AQgB5AFoAWABaAGwAYgBuAFIARQBaAFcAWgBoAGQA
>> "%~1" echo VwB4ADAASwBDAGsANwBaAEgASgB2AGMAQwA1AGoAYgBHAEYAegBjADAAeABwAGMA
>> "%~1" echo MwBRAHUAWQBXAFIAawBLAEMAZAB2AGQAbQBWAHkASgB5AGwAOQBLAFMAawA3AEQA
>> "%~1" echo UQBvAGcASQBGAHMAbgBaAEgASgBoAFoAMgB4AGwAWQBYAFoAbABKAHkAdwBuAFoA
>> "%~1" echo SABKAHYAYwBDAGQAZABMAG0AWgB2AGMAawBWAGgAWQAyAGcAbwBaAFgAWQA5AFAA
>> "%~1" echo bQBSAHkAYgAzAEEAdQBZAFcAUgBrAFIAWABaAGwAYgBuAFIATQBhAFgATgAwAFoA
>> "%~1" echo VwA1AGwAYwBpAGgAbABkAGkAeABsAFAAVAA1ADcAWgBTADUAdwBjAG0AVgAyAFoA
>> "%~1" echo VwA1ADAAUgBHAFYAbQBZAFgAVgBzAGQAQwBnAHAATwAyAGwAbQBLAEcAVgAyAFAA
>> "%~1" echo VAAwADkASgAyAFIAeQBZAFcAZABzAFoAVwBGADIAWgBTAGMAbQBKAG0AUgB5AGIA
>> "%~1" echo MwBBAHUAWQAyADkAdQBkAEcARgBwAGIAbgBNAG8AWgBTADUAeQBaAFcAeABoAGQA
>> "%~1" echo RwBWAGsAVgBHAEYAeQBaADIAVgAwAEsAUwBsAHkAWgBYAFIAMQBjAG0ANAA3AFoA
>> "%~1" echo SABKAHYAYwBDADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIA
>> "%~1" echo MwBaAGwASwBDAGQAdgBkAG0AVgB5AEoAeQBsADkASwBTAGsANwBEAFEAbwBnAEkA
>> "%~1" echo RwBSAHkAYgAzAEEAdQBZAFcAUgBrAFIAWABaAGwAYgBuAFIATQBhAFgATgAwAFoA
>> "%~1" echo VwA1AGwAYwBpAGcAbgBaAEgASgB2AGMAQwBjAHMAWgBUADAAKwBlADIATgB2AGIA
>> "%~1" echo bgBOADAASQBHAFkAOQBaAFMANQBrAFkAWABSAGgAVgBIAEoAaABiAG4ATgBtAFoA
>> "%~1" echo WABJAG0ASgBtAFUAdQBaAEcARgAwAFkAVgBSAHkAWQBXADUAegBaAG0AVgB5AEwA
>> "%~1" echo bQBaAHAAYgBHAFYAegBKAGkAWgBsAEwAbQBSAGgAZABHAEYAVQBjAG0ARgB1AGMA
>> "%~1" echo MgBaAGwAYwBpADUAbQBhAFcAeABsAGMAMQBzAHcAWABUAHQAcABaAGkAaABtAEsA
>> "%~1" echo WABWAHcAYgBHADkAaABaAEUARgB3AGEAeQBoAG0ASwBYADAAcABPAHcAMABLAEkA
>> "%~1" echo QwBCAGoAYgAyADUAegBkAEMAQgB3AFkAVwBkAGwAUABTAFEAbwBKADIARgB3AGMA
>> "%~1" echo SABOAFQAYQBXAFIAbABiAEcAOQBoAFoAQwBjAHAAZgBIAHcAawBLAEMAZABoAGMA
>> "%~1" echo SABCAHoASgB5AGsANwBhAFcAWQBvAGMARwBGAG4AWgBTAGwANwBjAEcARgBuAFoA
>> "%~1" echo UwA1AGgAWgBHAFIARgBkAG0AVgB1AGQARQB4AHAAYwAzAFIAbABiAG0AVgB5AEsA
>> "%~1" echo QwBkAGsAYwBtAEYAbgBiADMAWgBsAGMAaQBjAHMAWgBUADAAKwBaAFMANQB3AGMA
>> "%~1" echo bQBWADIAWgBXADUAMABSAEcAVgBtAFkAWABWAHMAZABDAGcAcABLAFQAdAB3AFkA
>> "%~1" echo VwBkAGwATABtAEYAawBaAEUAVgAyAFoAVwA1ADAAVABHAGwAegBkAEcAVgB1AFoA
>> "%~1" echo WABJAG8ASgAyAFIAeQBiADMAQQBuAEwARwBVADkAUABuAHQAbABMAG4AQgB5AFoA
>> "%~1" echo WABaAGwAYgBuAFIARQBaAFcAWgBoAGQAVwB4ADAASwBDAGsANwBZADIAOQB1AGMA
>> "%~1" echo MwBRAGcAWgBqADEAbABMAG0AUgBoAGQARwBGAFUAYwBtAEYAdQBjADIAWgBsAGMA
>> "%~1" echo aQBZAG0AWgBTADUAawBZAFgAUgBoAFYASABKAGgAYgBuAE4AbQBaAFgASQB1AFoA
>> "%~1" echo bQBsAHMAWgBYAE0AbQBKAG0AVQB1AFoARwBGADAAWQBWAFIAeQBZAFcANQB6AFoA
>> "%~1" echo bQBWAHkATABtAFoAcABiAEcAVgB6AFcAegBCAGQATwAyAGwAbQBLAEcAWQBtAEoA
>> "%~1" echo aQA5AGMATABtAEYAdwBhAHkAUQB2AGEAUwA1ADAAWgBYAE4AMABLAEcAWQB1AGIA
>> "%~1" echo bQBGAHQAWgBTAGsAcABkAFgAQgBzAGIAMgBGAGsAUQBYAEIAcgBLAEcAWQBwAGYA
>> "%~1" echo UwBsADkARABRAG8AZwBJAEMAUQBvAEoAMgBsAHUAYwAzAFIAaABiAEcAeABDAGQA
>> "%~1" echo RwA0AG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABXAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AEIAYwBHAHMANwBEAFEAbwBnAEkAQwBRAG8ASgAyAEYAdwBhADEAQgBsAGMA
>> "%~1" echo bQAxAHoAUQBuAFIAdQBKAHkAawB1AGIAMgA1AGoAYgBHAGwAagBhAHoAMQBsAFAA
>> "%~1" echo VAA1ADcAWgBTADUAdwBjAG0AVgAyAFoAVwA1ADAAUgBHAFYAbQBZAFgAVgBzAGQA
>> "%~1" echo QwBnAHAATwB5AFEAbwBKADIARgB3AGEAMQBCAGwAYwBtADEAegBKAHkAawB1AFkA
>> "%~1" echo MgB4AGgAYwAzAE4ATQBhAFgATgAwAEwAbgBSAHYAWgAyAGQAcwBaAFMAZwBuAGMA
>> "%~1" echo MgBoAHYAZAB5AGMAcABmAFQAcwBOAEMAaQBBAGcASgBDAGcAbgBZAFgAQgByAFUA
>> "%~1" echo bQBWAHoAWgBYAFEAbgBLAFMANQB2AGIAbQBOAHMAYQBXAE4AcgBQAFcAVQA5AFAA
>> "%~1" echo bgB0AGwATABuAEIAeQBaAFgAWgBsAGIAbgBSAEUAWgBXAFoAaABkAFcAeAAwAEsA
>> "%~1" echo QwBrADcASgBDAGcAbgBZAFgAQgByAFIASABKAHYAYwBDAGMAcABMAG4ARgAxAFoA
>> "%~1" echo WABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBJAG8ASgAyAEkAbgBLAFMANQAwAFoA
>> "%~1" echo WABoADAAUQAyADkAdQBkAEcAVgB1AGQARAAwAG4ANQBvAHUAVwA1AG8AdQA5AEkA
>> "%~1" echo RQBGAFEAUwB5AEQAbABpAEwARABvAHYANQBuAHAAaAA0AHoAdgB2AEkAegBtAGkA
>> "%~1" echo SgBiAG4AZwByAG4AbABoADcAdgBwAGcASQBuAG0AaQA2AGsAbgBPAHkAUQBvAEoA
>> "%~1" echo MgBGAHcAYQAwAFIAeQBiADMAQQBuAEsAUwA1AHgAZABXAFYAeQBlAFYATgBsAGIA
>> "%~1" echo RwBWAGoAZABHADkAeQBLAEMAYwBqAFoASABKAHYAYwBFAGgAcABiAG4AUQBuAEsA
>> "%~1" echo UwA1ADAAWgBYAGgAMABRADIAOQB1AGQARwBWAHUAZABEADAAbgA1AHAAeQBzADUA
>> "%~1" echo WgB5AHcANQBMAGkASwA1AEwAeQBnADUAWgBDAE8ANQA1AFMAeABJAEUARgBFAFEA
>> "%~1" echo aQBEAGwAcgBvAG4AbwBvADQAWABsAGkATABEAGwAdAA3AEwAbwB2ADUANwBtAGoA
>> "%~1" echo cQBYAG4AbQBvAFEAZwBVAFgAVgBsAGMAMwBUAGoAZwBJAEwAbAByAG8AbgBvAG8A
>> "%~1" echo NABYAGwAaQBZADMAawB2AEoAcgBrAHUAbwB6AG0AcgBLAEgAbgBvAGEANwBvAHIA
>> "%~1" echo cQBUAGoAZwBJAEkAbgBPADMASgBsAGMAMgBWADAAUQBYAEIAcgBLAEMAbAA5AE8A
>> "%~1" echo dwAwAEsASQBDAEEAdgBMAHkAQgBqAGIARwBsAGoAYQAyAGwAdQBaAHkAQgAwAGEA
>> "%~1" echo RwBVAGcAYwBHAFYAeQBiAFMAQgB3AGEAVwB4AHMASQBHAEYAcwBjADIAOABnAGIA
>> "%~1" echo MwBCAGwAYgBuAE0AZwBjAEcAVgB5AGIAWABNAE4AQwBpAEEAZwBaAEcAOQBqAGQA
>> "%~1" echo VwAxAGwAYgBuAFEAdQBZAFcAUgBrAFIAWABaAGwAYgBuAFIATQBhAFgATgAwAFoA
>> "%~1" echo VwA1AGwAYwBpAGcAbgBZADIAeABwAFkAMgBzAG4ATABHAFUAOQBQAG4AdABwAFoA
>> "%~1" echo aQBoAGwATABuAFIAaABjAG0AZABsAGQAQwBZAG0AWgBTADUAMABZAFgASgBuAFoA
>> "%~1" echo WABRAHUAYQBXAFEAOQBQAFQAMABuAGMARwBWAHkAYgBWAEIAcABiAEcAdwBuAEsA
>> "%~1" echo UwBRAG8ASgAyAEYAdwBhADEAQgBsAGMAbQAxAHoASgB5AGsAdQBZADIAeABoAGMA
>> "%~1" echo MwBOAE0AYQBYAE4AMABMAG4AUgB2AFoAMgBkAHMAWgBTAGcAbgBjADIAaAB2AGQA
>> "%~1" echo eQBjAHAAZgBTAGsANwBEAFEAcAA5AEQAUQBvAE4AQwBtAHgAbABkAEMAQgBoAGMA
>> "%~1" echo SABCAFQAWQAyADkAdwBaAFQAMABuAGQAWABOAGwAYwBpAGMAcwBZAFgAQgB3AFEA
>> "%~1" echo MgBGAGoAYQBHAFUAOQBXADEAMABzAFkAWABCAHcAVQAyAFYAcwBQAFcANQAxAGIA
>> "%~1" echo RwB3AHMAYQBIAE4ARABZAFcATgBvAFoAVAAxAGIAWABUAHMATgBDAG0AWgAxAGIA
>> "%~1" echo bQBOADAAYQBXADkAdQBJAEcAaAAxAFoAUwBoAHoASwBYAHQAcwBaAFgAUQBnAGEA
>> "%~1" echo RAAwAHcATwAyAFoAdgBjAGkAaABzAFoAWABRAGcAYQBUADAAdwBPADIAawA4AEsA
>> "%~1" echo SABOADgAZgBDAGMAbgBLAFMANQBzAFoAVwA1AG4AZABHAGcANwBhAFMAcwByAEsA
>> "%~1" echo VwBnADkASwBHAGcAcQBNAHoARQByAGMAeQA1AGoAYQBHAEYAeQBRADIAOQBrAFoA
>> "%~1" echo VQBGADAASwBHAGsAcABLAFQANAArAFAAagBBADcAYwBtAFYAMABkAFgASgB1AEkA
>> "%~1" echo RwBnAGwATQB6AFkAdwBmAFEAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGMA
>> "%~1" echo MwBsAHUAWQAwAEYAawBZAGsASgBoAGIAbQA1AGwAYwBpAGcAcABlADIATgB2AGIA
>> "%~1" echo bgBOADAASQBHADEAcABjADMATQA5AGIARwBGAHoAZABDADUAaABaAEcASgBHAGIA
>> "%~1" echo MwBWAHUAWgBEADAAOQBQAFMAZABtAFkAVwB4AHoAWgBTAGMANwBhAFcAWQBvAEoA
>> "%~1" echo QwBnAG4AWQBXAFIAaQBRAG0ARgB1AGIAbQBWAHkASgB5AGsAcABKAEMAZwBuAFkA
>> "%~1" echo VwBSAGkAUQBtAEYAdQBiAG0AVgB5AEoAeQBrAHUAWQAyAHgAaABjADMATgBNAGEA
>> "%~1" echo WABOADAATABuAFIAdgBaADIAZABzAFoAUwBnAG4AYwAyAGgAdgBkAHkAYwBzAGIA
>> "%~1" echo VwBsAHoAYwB5AGwAOQBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgB6AFoA
>> "%~1" echo WABSAEIAYwBIAEIAVQBZAFcASQBvAGQARwBGAGkASwBYAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAHAAYgBuAE4AMABQAFgAUgBoAFkAaQBFADkAUABTAGQAegBhAFcAUgBsAGIA
>> "%~1" echo RwA5AGgAWgBDAGMANwBKAEMAZwBuAFkAWABCAHcAYwAwAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AGwAWgBDAGMAcABMAG4ATgAwAGUAVwB4AGwATABtAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADkAYQBXADUAegBkAEQAOABuAEoAegBvAG4AYgBtADkAdQBaAFMAYwA3AEoA
>> "%~1" echo QwBnAG4AWQBYAEIAdwBjADEATgBwAFoARwBWAHMAYgAyAEYAawBKAHkAawB1AGMA
>> "%~1" echo MwBSADUAYgBHAFUAdQBaAEcAbAB6AGMARwB4AGgAZQBUADEAcABiAG4ATgAwAFAA
>> "%~1" echo eQBkAHUAYgAyADUAbABKAHoAbwBuAEoAegBzAGsASwBDAGQAMABZAFcASgBKAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBaAFcAUQBuAEsAUwA1AGoAYgBHAEYAegBjADAAeABwAGMA
>> "%~1" echo MwBRAHUAZABHADkAbgBaADIAeABsAEsAQwBkAHYAYgBpAGMAcwBhAFcANQB6AGQA
>> "%~1" echo QwBrADcASgBDAGcAbgBkAEcARgBpAFUAMgBsAGsAWgBXAHgAdgBZAFcAUQBuAEsA
>> "%~1" echo UwA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAZABHADkAbgBaADIAeABsAEsA
>> "%~1" echo QwBkAHYAYgBpAGMAcwBJAFcAbAB1AGMAMwBRAHAATwAyAGwAbQBLAEcAbAB1AGMA
>> "%~1" echo MwBRAHAAYgBHADkAaABaAEUARgB3AGMASABNAG8AWgBtAEYAcwBjADIAVQBwAGYA
>> "%~1" echo UQAwAEsAWQBYAE4ANQBiAG0ATQBnAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGIA
>> "%~1" echo RwA5AGgAWgBFAEYAdwBjAEgATQBvAFoAbQA5AHkAWQAyAFUAcABlADIAbABtAEsA
>> "%~1" echo RwB4AGgAYwAzAFEAdQBZADIAOQB1AGIAbQBWAGoAZABHAFYAawBJAFQAMAA5AEoA
>> "%~1" echo MwBSAHkAZABXAFUAbgBLAFgAdABwAFoAaQBnAGsASwBDAGQAaABjAEgAQgBNAGEA
>> "%~1" echo WABOADAAUgBXADEAdwBkAEgAawBuAEsAUwBrAGsASwBDAGQAaABjAEgAQgBNAGEA
>> "%~1" echo WABOADAAUgBXADEAdwBkAEgAawBuAEsAUwA1ADAAWgBYAGgAMABRADIAOQB1AGQA
>> "%~1" echo RwBWAHUAZABEADEATQBRAFUANQBIAFAAVAAwADkASgAzAHAAbwBKAHoAOABuADUA
>> "%~1" echo cAB5AHEANgBMACsAZQA1AG8ANgBsADQANABDAEMASgB6AG8AbgBUAG0AOQAwAEkA
>> "%~1" echo RwBOAHYAYgBtADUAbABZADMAUgBsAFoAQwA0AG4ATwAzAEoAbABkAEgAVgB5AGIA
>> "%~1" echo bgAxADAAYwBuAGwANwBZADIAOQB1AGMAMwBRAGcAYwBqADEAaABkADIARgBwAGQA
>> "%~1" echo QwBCAGgAYwBHAGsAbwBKAHkAOQBoAGMARwBrAHYAWQBYAEIAdwBjAHoAOQB6AFkA
>> "%~1" echo MgA5AHcAWgBUADAAbgBLADIAVgB1AFkAMgA5AGsAWgBWAFYAUwBTAFUATgB2AGIA
>> "%~1" echo WABCAHYAYgBtAFYAdQBkAEMAaABoAGMASABCAFQAWQAyADkAdwBaAFMAawBwAE8A
>> "%~1" echo MgBsAG0ASwBIAEkAdQBiADIAcwBoAFAAVAAwAG4AZABIAEoAMQBaAFMAYwBwAGQA
>> "%~1" echo RwBoAHkAYgAzAGMAZwBiAG0AVgAzAEkARQBWAHkAYwBtADkAeQBLAEgASQB1AFoA
>> "%~1" echo WABKAHkAYgAzAEoAOABmAEMAZABzAGEAWABOADAASQBHAFoAaABhAFcAeABsAFoA
>> "%~1" echo QwBjAHAATwAyAEYAdwBjAEUATgBoAFkAMgBoAGwAUABVAHAAVABUADAANAB1AGMA
>> "%~1" echo RwBGAHkAYwAyAFUAbwBjAGkANQBoAGMASABCAHoAUwBuAE4AdgBiAG4AeAA4AEoA
>> "%~1" echo MQB0AGQASgB5AGsANwBjAG0AVgB1AFoARwBWAHkAUQBYAEIAdwBUAEcAbAB6AGQA
>> "%~1" echo QwBnAHAAZgBXAE4AaABkAEcATgBvAEsARwBVAHAAZQAyAGwAbQBLAEMAUQBvAEoA
>> "%~1" echo MgBGAHcAYwBFAHgAcABjADMAUgBGAGIAWABCADAAZQBTAGMAcABLAFMAUQBvAEoA
>> "%~1" echo MgBGAHcAYwBFAHgAcABjADMAUgBGAGIAWABCADAAZQBTAGMAcABMAG4AUgBsAGUA
>> "%~1" echo SABSAEQAYgAyADUAMABaAFcANQAwAFAAVwBVAHUAYgBXAFYAegBjADIARgBuAFoA
>> "%~1" echo WAAxADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAeQBaAFcANQBrAFoA
>> "%~1" echo WABKAEIAYwBIAEIATQBhAFgATgAwAEsAQwBsADcAWQAyADkAdQBjADMAUQBnAGMA
>> "%~1" echo VAAwAG8ASgBDAGcAbgBZAFgAQgB3AFIAbQBsAHMAZABHAFYAeQBKAHkAawBtAEoA
>> "%~1" echo aQBRAG8ASgAyAEYAdwBjAEUAWgBwAGIASABSAGwAYwBpAGMAcABMAG4AWgBoAGIA
>> "%~1" echo SABWAGwAZgBIAHcAbgBKAHkAawB1AGQARwA5AE0AYgAzAGQAbABjAGsATgBoAGMA
>> "%~1" echo MgBVAG8ASwBUAHQAagBiADIANQB6AGQAQwBCAG8AYgAzAE4AMABQAFMAUQBvAEoA
>> "%~1" echo MgBGAHcAYwBGAEoAdgBkADMATQBuAEsAVAB0AHAAWgBpAGcAaABhAEcAOQB6AGQA
>> "%~1" echo QwBsAHkAWgBYAFIAMQBjAG0ANAA3AFkAMgA5AHUAYwAzAFEAZwBjAG0AOQAzAGMA
>> "%~1" echo egAxAGgAYwBIAEIARABZAFcATgBvAFoAUwA1AG0AYQBXAHgAMABaAFgASQBvAFkA
>> "%~1" echo VAAwACsASQBYAEYAOABmAEMAaABoAEwAbgBCAGgAWQAyAHQAaABaADIAVgA4AGYA
>> "%~1" echo QwBjAG4ASwBTADUAMABiADAAeAB2AGQAMgBWAHkAUQAyAEYAegBaAFMAZwBwAEwA
>> "%~1" echo bQBsAHUAWgBHAFYANABUADIAWQBvAGMAUwBrACsAUABUAEIAOABmAEMAaABoAEwA
>> "%~1" echo bgBSAHAAZABHAHgAbABmAEgAdwBuAEoAeQBrAHUAZABHADkATQBiADMAZABsAGMA
>> "%~1" echo awBOAGgAYwAyAFUAbwBLAFMANQBwAGIAbQBSAGwAZQBFADkAbQBLAEgARQBwAFAA
>> "%~1" echo agAwAHcASwBUAHQAbwBiADMATgAwAEwAbQBsAHUAYgBtAFYAeQBTAEYAUgBOAFQA
>> "%~1" echo RAAwAG4ASgB6AHQAcABaAGkAZwBoAGMAbQA5ADMAYwB5ADUAcwBaAFcANQBuAGQA
>> "%~1" echo RwBnAHAAZQAyAGgAdgBjADMAUQB1AGEAVwA1AHUAWgBYAEoASQBWAEUAMQBNAFAA
>> "%~1" echo UwBjADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaABjAEgAQgBGAGIA
>> "%~1" echo WABCADAAZQBTAEkAKwBKAHkAcwBvAFQARQBGAE8AUgB6ADAAOQBQAFMAZAA2AGEA
>> "%~1" echo QwBjAC8ASgArAGEAeQBvAGUAYQBjAGkAZQBXAE0AdQBlAG0ARgBqAGUAZQBhAGgA
>> "%~1" echo TwBXADYAbABPAGUAVQBxAE8ATwBBAGcAaQBjADYASgAwADUAdgBJAEcAMQBoAGQA
>> "%~1" echo RwBOAG8AYQBXADUAbgBJAEcARgB3AGMASABNAHUASgB5AGsAcgBKAHoAdwB2AFoA
>> "%~1" echo RwBsADIAUABpAGMANwBjAG0AVgAwAGQAWABKAHUAZgBYAEoAdgBkADMATQB1AFoA
>> "%~1" echo bQA5AHkAUgBXAEYAagBhAEMAaABoAFAAVAA1ADcAWQAyADkAdQBjADMAUQBnAFoA
>> "%~1" echo VwB3ADkAWgBHADkAagBkAFcAMQBsAGIAbgBRAHUAWQAzAEoAbABZAFgAUgBsAFIA
>> "%~1" echo VwB4AGwAYgBXAFYAdQBkAEMAZwBuAFoARwBsADIASgB5AGsANwBaAFcAdwB1AFkA
>> "%~1" echo MgB4AGgAYwAzAE4ATwBZAFcAMQBsAFAAUwBkAGgAYwBIAEIAUwBiADMAYwBuAEsA
>> "%~1" echo eQBoAGgAYwBIAEIAVABaAFcAdwA5AFAAVAAxAGgATABuAEIAaABZADIAdABoAFoA
>> "%~1" echo MgBVAC8ASgB5AEIAdgBiAGkAYwA2AEoAeQBjAHAATwAyAFYAcwBMAG0AbAB1AGIA
>> "%~1" echo bQBWAHkAUwBGAFIATgBUAEQAMABuAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQBYAEIAdwBSADIAeAA1AGMARwBnAGkASQBIAE4AMABlAFcAeABsAFAA
>> "%~1" echo UwBKAGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBtAGgAegBiAEMAZwBuAEsA
>> "%~1" echo MgBoADEAWgBTAGgAaABMAG4AQgBoAFkAMgB0AGgAWgAyAFUAcABLAHkAYwBnAE4A
>> "%~1" echo agBJAGwASQBEAFEAeQBKAFMAawBpAFAAaQBjAHIASwBHAFYAegBZAHkAZwBvAFkA
>> "%~1" echo UwA1ADAAYQBYAFIAcwBaAFgAeAA4AEoAMABFAG4ASwBTADUAagBhAEcARgB5AFEA
>> "%~1" echo WABRAG8ATQBDAGsAcABLAFMAcwBuAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQA
>> "%~1" echo agA0ADgAWQBqADQAbgBLADIAVgB6AFkAeQBoAGgATABuAFIAcABkAEcAeABsAGYA
>> "%~1" echo SAB4AGgATABuAEIAaABZADIAdABoAFoAMgBVAHAASwB5AGMAOABMADIASQArAFAA
>> "%~1" echo SABOAHcAWQBXADQAKwBKAHkAdABsAGMAMgBNAG8AWQBTADUAdwBZAFcATgByAFkA
>> "%~1" echo VwBkAGwASwBTAHMAbwBZAFMANQBwAGIAbgBOADAAWQBXAHgAcwBaAFgASQAvAEoA
>> "%~1" echo eQBEAEMAdAB5AEEAbgBLADIAVgB6AFkAeQBoAGgATABtAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AGwAYwBpAGsANgBKAHkAYwBwAEsAeQBjADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBKAHoAdABsAGIAQwA1AHYAYgBtAE4AcwBhAFcATgByAFAA
>> "%~1" echo UwBnAHAAUABUADUAdgBjAEcAVgB1AFEAWABCAHcASwBHAEUAdQBjAEcARgBqAGEA
>> "%~1" echo MgBGAG4AWgBTAGsANwBhAEcAOQB6AGQAQwA1AGgAYwBIAEIAbABiAG0AUgBEAGEA
>> "%~1" echo RwBsAHMAWgBDAGgAbABiAEMAbAA5AEsAWAAwAE4AQwBtAEYAegBlAFcANQBqAEkA
>> "%~1" echo RwBaADEAYgBtAE4AMABhAFcAOQB1AEkARwA5AHcAWgBXADUAQgBjAEgAQQBvAGMA
>> "%~1" echo RwB0AG4ASwBYAHQAaABjAEgAQgBUAFoAVwB3ADkAYwBHAHQAbgBPADMASgBsAGIA
>> "%~1" echo bQBSAGwAYwBrAEYAdwBjAEUAeABwAGMAMwBRAG8ASwBUAHQAMABjAG4AbAA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBjAGoAMQBoAGQAMgBGAHAAZABDAEIAaABjAEcAawBvAEoA
>> "%~1" echo eQA5AGgAYwBHAGsAdgBZAFgAQgB3AGMAeQA5AGsAWgBYAFIAaABhAFcAdwAvAGMA
>> "%~1" echo RwBGAGoAYQAyAEYAbgBaAFQAMABuAEsAMgBWAHUAWQAyADkAawBaAFYAVgBTAFMA
>> "%~1" echo VQBOAHYAYgBYAEIAdgBiAG0AVgB1AGQAQwBoAHcAYQAyAGMAcABLAFQAdABwAFoA
>> "%~1" echo aQBoAHkATABtADkAcgBJAFQAMAA5AEoAMwBSAHkAZABXAFUAbgBLAFgAUgBvAGMA
>> "%~1" echo bQA5ADMASQBHADUAbABkAHkAQgBGAGMAbgBKAHYAYwBpAGgAeQBMAG0AVgB5AGMA
>> "%~1" echo bQA5AHkAZgBIAHcAbgBaAEcAVgAwAFkAVwBsAHMASQBHAFoAaABhAFcAeABsAFoA
>> "%~1" echo QwBjAHAATwB5AFEAbwBKADIARgB3AGMARQBSAGwAZABHAEYAcABiAEUAVgB0AGMA
>> "%~1" echo SABSADUASgB5AGsAdQBjADMAUgA1AGIARwBVAHUAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VAAwAG4AYgBtADkAdQBaAFMAYwA3AEoAQwBnAG4AWQBYAEIAdwBSAEcAVgAwAFkA
>> "%~1" echo VwBsAHMAUQBtADkAawBlAFMAYwBwAEwAbgBOADAAZQBXAHgAbABMAG0AUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsAOQBKAHkAYwA3AEoAQwBnAG4AWgBHAFYAMABSADIAeAA1AGMA
>> "%~1" echo RwBnAG4ASwBTADUAMABaAFgAaAAwAFEAMgA5AHUAZABHAFYAdQBkAEQAMABvAGMA
>> "%~1" echo aQA1ADAAYQBYAFIAcwBaAFgAeAA4AGMAaQA1AHcAWQBXAE4AcgBZAFcAZABsAGYA
>> "%~1" echo SAB3AG4AUQBTAGMAcABMAG0ATgBvAFkAWABKAEIAZABDAGcAdwBLAFQAdAB6AFoA
>> "%~1" echo WABRAG8ASgAyAFIAbABkAEYAUgBwAGQARwB4AGwASgB5AHgAeQBMAG4AUgBwAGQA
>> "%~1" echo RwB4AGwAZgBIAHgAeQBMAG4AQgBoAFkAMgB0AGgAWgAyAFUAcABPAHkAUQBvAEoA
>> "%~1" echo MgBSAGwAZABGAEIAcABiAEcAeAB6AEoAeQBrAHUAYQBXADUAdQBaAFgASgBJAFYA
>> "%~1" echo RQAxAE0AUABTAGMAOABjADMAQgBoAGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
>> "%~1" echo RwBsAHMAYgBDAEIAMgBaAFgASQBpAFAAbgBZAG4ASwAyAFYAegBZAHkAaAB5AEwA
>> "%~1" echo bgBaAGwAYwBuAE4AcABiADIANQBPAFkAVwAxAGwAZgBIAHcAbgBQAHkAYwBwAEsA
>> "%~1" echo eQBoAHkATABuAFoAbABjAG4ATgBwAGIAMgA1AEQAYgAyAFIAbABQAHkAYwBnAEsA
>> "%~1" echo QwBjAHIAWgBYAE4AagBLAEgASQB1AGQAbQBWAHkAYwAyAGwAdgBiAGsATgB2AFoA
>> "%~1" echo RwBVAHAASwB5AGMAcABKAHoAbwBuAEoAeQBrAHIASgB6AHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0AG4ASwB5AGgAeQBMAG4ATgBwAGUAbQBWAFUAWgBYAGgAMABQAHkAYwA4AGMA
>> "%~1" echo MwBCAGgAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAYwBHAGwAcwBiAEMASQArAEoA
>> "%~1" echo eQB0AGwAYwAyAE0AbwBjAGkANQB6AGEAWABwAGwAVgBHAFYANABkAEMAawByAEoA
>> "%~1" echo egB3AHYAYwAzAEIAaABiAGoANABuAE8AaQBjAG4ASwBTAHMAbgBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBCAHAAYgBHAHcAaQBQAGkAYwByAEsA
>> "%~1" echo SABJAHUAZABYAE4AbABjAGoAMAA5AFAAUwBkADAAYwBuAFYAbABKAHoAOABvAFQA
>> "%~1" echo RQBGAE8AUgB6ADAAOQBQAFMAZAA2AGEAQwBjAC8ASgArAGUAcwByAE8AUwA0AGkA
>> "%~1" echo ZQBhAFcAdQBTAGMANgBKADEAVgB6AFoAWABJAG4ASwBUAG8AbwBUAEUARgBPAFIA
>> "%~1" echo egAwADkAUABTAGQANgBhAEMAYwAvAEoAKwBlAHoAdQArAGUANwBuAHkAYwA2AEoA
>> "%~1" echo MQBOADUAYwAzAFIAbABiAFMAYwBwAEsAUwBzAG4AUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo aQBjADcAYwAyAFYAMABLAEMAZABrAFoAWABSAFEAWQBXAE4AcgBZAFcAZABsAEoA
>> "%~1" echo eQB4AHkATABuAEIAaABZADIAdABoAFoAMgBVAHAATwAzAE4AbABkAEMAZwBuAFoA
>> "%~1" echo RwBWADAAVgBtAFYAeQBjADIAbAB2AGIAaQBjAHMASwBIAEkAdQBkAG0AVgB5AGMA
>> "%~1" echo MgBsAHYAYgBrADUAaABiAFcAVgA4AGYAQwBjAHQASgB5AGsAcgBKAHkAQQB2AEkA
>> "%~1" echo QwBjAHIASQBDAGgAeQBMAG4AWgBsAGMAbgBOAHAAYgAyADUARABiADIAUgBsAGYA
>> "%~1" echo SAB3AG4ATABTAGMAcABLAFQAdAB6AFoAWABRAG8ASgAyAFIAbABkAEYATgBrAGEA
>> "%~1" echo eQBjAHMASgAyADEAcABiAGkAQQBuAEsAeQBoAHkATABtADEAcABiAGwATgBrAGEA
>> "%~1" echo MwB4ADgASgB5ADAAbgBLAFMAcwBuAEkAQwA4AGcAZABHAEYAeQBaADIAVgAwAEkA
>> "%~1" echo QwBjAHIASwBIAEkAdQBkAEcARgB5AFoAMgBWADAAVQAyAFIAcgBmAEgAdwBuAEwA
>> "%~1" echo UwBjAHAASwBUAHQAegBaAFgAUQBvAEoAMgBSAGwAZABFAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB4AGwAYwBpAGMAcwBjAGkANQBwAGIAbgBOADAAWQBXAHgAcwBaAFgASgA4AGYA
>> "%~1" echo QwBjAHQASgB5AGsANwBjADIAVgAwAEsAQwBkAGsAWgBYAFIAVgBhAFcAUgBCAFkA
>> "%~1" echo bQBrAG4ATABDAGgAeQBMAG4AVgBwAFoASAB4ADgASgB5ADAAbgBLAFMAcwBuAEkA
>> "%~1" echo QwA4AGcASgB5AHMAbwBjAGkANQBoAFkAbQBsADgAZgBDAGMAdABKAHkAawBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBaAEcAVgAwAFUAMgBsADYAWgBTAGMAcwBjAGkANQB6AGEA
>> "%~1" echo WABwAGwAVgBHAFYANABkAEgAeAA4AEoAeQAwAG4ASwBUAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgBSAGwAZABFAFoAcABjAG4ATgAwAEoAeQB4AHkATABtAFoAcABjAG4ATgAwAFMA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEgAeAA4AEoAeQAwAG4ASwBUAHQAegBaAFgAUQBvAEoA
>> "%~1" echo MgBSAGwAZABGAFYAdwBaAEcARgAwAFoAUwBjAHMAYwBpADUAcwBZAFgATgAwAFYA
>> "%~1" echo WABCAGsAWQBYAFIAbABmAEgAdwBuAEwAUwBjAHAATwAzAE4AbABkAEMAZwBuAFoA
>> "%~1" echo RwBWADAAVQBHAEYAMABhAEMAYwBzAGMAaQA1AGgAYwBHAHQAUQBZAFgAUgBvAGYA
>> "%~1" echo SAB4AHkATABtAE4AdgBaAEcAVgBRAFkAWABSAG8AZgBIAHcAbgBMAFMAYwBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBaAEcAVgAwAFIARwBGADAAWQBTAGMAcwBjAGkANQBrAFkA
>> "%~1" echo WABSAGgAUgBHAGwAeQBmAEgAdwBuAEwAUwBjAHAATwAzAE4AbABkAEMAZwBuAFoA
>> "%~1" echo RwBWADAAVQAzAFIAaABkAEcAVQBuAEwAQwBoAHkATABtAFYAdQBZAFcASgBzAFoA
>> "%~1" echo VwBRADkAUABUADAAbgBkAEgASgAxAFoAUwBjAC8ASwBFAHgAQgBUAGsAYwA5AFAA
>> "%~1" echo VAAwAG4AZQBtAGcAbgBQAHkAZgBsAGsASwAvAG4AbABLAGcAbgBPAGkAZABsAGIA
>> "%~1" echo bQBGAGkAYgBHAFYAawBKAHkAawA2AEsARQB4AEIAVABrAGMAOQBQAFQAMABuAGUA
>> "%~1" echo bQBnAG4AUAB5AGYAbgBwAG8ASABuAGwASwBnAG4ATwBpAGQAawBhAFgATgBoAFkA
>> "%~1" echo bQB4AGwAWgBDAGMAcABLAFMAcwBvAGMAaQA1AHoAZABHADkAdwBjAEcAVgBrAFAA
>> "%~1" echo VAAwADkASgAzAFIAeQBkAFcAVQBuAFAAeQBjAGcATAB5AEIAegBkAEcAOQB3AGMA
>> "%~1" echo RwBWAGsASgB6AG8AbgBKAHkAawBwAE8AMgBOAHYAYgBuAE4AMABJAEgASgAwAFAA
>> "%~1" echo VQBwAFQAVAAwADQAdQBjAEcARgB5AGMAMgBVAG8AYwBpADUAeQBkAFcANQAwAGEA
>> "%~1" echo VwAxAGwAUwBuAE4AdgBiAG4AeAA4AEoAMQB0AGQASgB5AGsANwBKAEMAZwBuAFoA
>> "%~1" echo RwBWADAAVQBuAFYAdQBkAEcAbAB0AFoAUwBjAHAATABtAGwAdQBiAG0AVgB5AFMA
>> "%~1" echo RgBSAE4AVABEADEAeQBkAEMANQBzAFoAVwA1AG4AZABHAGcALwBjAG4AUQB1AGIA
>> "%~1" echo VwBGAHcASwBIAEEAOQBQAGkAYwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHcAWgBYAEoAdABVAG0AOQAzAEkAagA0ADgAYwAzAEIAaABiAGoANABuAEsA
>> "%~1" echo MgBWAHoAWQB5AGgAdwBMAG0ANQBoAGIAVwBVAHAASwB5AGMAOABMADMATgB3AFkA
>> "%~1" echo VwA0ACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AQgBwAGIA
>> "%~1" echo RwB3AGcASgB5AHMAbwBjAEMANQBuAGMAbQBGAHUAZABHAFYAawBQAFQAMAA5AEoA
>> "%~1" echo MwBSAHkAZABXAFUAbgBQAHkAZAB2AGEAeQBjADYASgAzAGQAaABjAG0ANABuAEsA
>> "%~1" echo UwBzAG4ASQBqADQAbgBLAHkAaAB3AEwAbQBkAHkAWQBXADUAMABaAFcAUQA5AFAA
>> "%~1" echo VAAwAG4AZABIAEoAMQBaAFMAYwAvAEoAMgBkAHkAWQBXADUAMABaAFcAUQBuAE8A
>> "%~1" echo aQBkAGsAWgBXADUAcABaAFcAUQBuAEsAUwBzAG4AUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo aQBjAHIASwBIAEkAdQBkAFgATgBsAGMAagAwADkAUABTAGQAMABjAG4AVgBsAEoA
>> "%~1" echo egA4AG4AUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
>> "%~1" echo bQBWAHoAWgBYAFIAQwBkAEcANABpAEkARwBSAGgAZABHAEUAdABjAEcAVgB5AGIA
>> "%~1" echo VAAwAGkASgB5AHQAbABjADIATQBvAGMAQwA1AHUAWQBXADEAbABLAFMAcwBuAEkA
>> "%~1" echo aQBCAGsAWQBYAFIAaABMAFcAZAB5AFkAVwA1ADAAUABTAEkAbgBLAHkAaAB3AEwA
>> "%~1" echo bQBkAHkAWQBXADUAMABaAFcAUQA5AFAAVAAwAG4AZABIAEoAMQBaAFMAYwAvAEoA
>> "%~1" echo egBBAG4ATwBpAGMAeABKAHkAawByAEoAeQBJACsASgB5AHMAbwBjAEMANQBuAGMA
>> "%~1" echo bQBGAHUAZABHAFYAawBQAFQAMAA5AEoAMwBSAHkAZABXAFUAbgBQAHkAZAB5AFoA
>> "%~1" echo WABaAHYAYQAyAFUAbgBPAGkAZABuAGMAbQBGAHUAZABDAGMAcABLAHkAYwA4AEwA
>> "%~1" echo MgBKADEAZABIAFIAdgBiAGoANABuAE8AaQBjAG4ASwBTAHMAbgBQAEMAOQBrAGEA
>> "%~1" echo WABZACsASgB5AGsAdQBhAG0AOQBwAGIAaQBnAG4ASgB5AGsANgBKAHoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAHAAYgBuAFEAaQBQAGkAMAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAbgBPAHkAUQBvAEoAMgBSAGwAZABGAEoAbABjAFgAVgBsAGMA
>> "%~1" echo MwBSAGwAWgBDAGMAcABMAG4AUgBsAGUASABSAEQAYgAyADUAMABaAFcANQAwAFAA
>> "%~1" echo UwBoAEsAVQAwADkATwBMAG4AQgBoAGMAbgBOAGwASwBIAEkAdQBjAG0AVgB4AGQA
>> "%~1" echo VwBWAHoAZABHAFYAawBTAG4ATgB2AGIAbgB4ADgASgAxAHQAZABKAHkAbAA4AGYA
>> "%~1" echo RgB0AGQASwBTADUAcQBiADIAbAB1AEsAQwBkAGMAYgBpAGMAcABmAEgAdwBuAEwA
>> "%~1" echo UwBjADcASgBDAGcAbgBaAEcAVgAwAFUAbgBWAHUAZABHAGwAdABaAFMAYwBwAEwA
>> "%~1" echo bgBGADEAWgBYAEoANQBVADIAVgBzAFoAVwBOADAAYgAzAEoAQgBiAEcAdwBvAEoA
>> "%~1" echo MQB0AGsAWQBYAFIAaABMAFgAQgBsAGMAbQAxAGQASgB5AGsAdQBaAG0AOQB5AFIA
>> "%~1" echo VwBGAGoAYQBDAGgAaQBkAEcANAA5AFAAbQBKADAAYgBpADUAdgBiAG0ATgBzAGEA
>> "%~1" echo VwBOAHIAUABTAGcAcABQAFQANQBoAGMASABCAFAAYwBDAGgAaQBkAEcANAB1AFoA
>> "%~1" echo RwBGADAAWQBYAE4AbABkAEMANQBuAGMAbQBGAHUAZABEADAAOQBQAFMAYwB4AEoA
>> "%~1" echo egA4AG4AWgAzAEoAaABiAG4AUQBuAE8AaQBkAHkAWgBYAFoAdgBhADIAVQBuAEwA
>> "%~1" echo SAB0AHcAWgBYAEoAdABhAFgATgB6AGEAVwA5AHUATwBtAEoAMABiAGkANQBrAFkA
>> "%~1" echo WABSAGgAYwAyAFYAMABMAG4AQgBsAGMAbQAxADkASwBTAGsANwBKAEMAZwBuAFoA
>> "%~1" echo RwBWADAAVgBXADUAcABiAG4ATgAwAFkAVwB4AHMASgB5AGsAdQBjADMAUgA1AGIA
>> "%~1" echo RwBVAHUAWgBHAGwAegBjAEcAeABoAGUAVAAxAHkATABuAFYAegBaAFgASQA5AFAA
>> "%~1" echo VAAwAG4AZABIAEoAMQBaAFMAYwAvAEoAeQBjADYASgAyADUAdgBiAG0AVQBuAE8A
>> "%~1" echo eQBRAG8ASgAyAFIAbABkAEUATgBzAFoAVwBGAHkASgB5AGsAdQBjADMAUgA1AGIA
>> "%~1" echo RwBVAHUAWgBHAGwAegBjAEcAeABoAGUAVAAxAHkATABuAFYAegBaAFgASQA5AFAA
>> "%~1" echo VAAwAG4AZABIAEoAMQBaAFMAYwAvAEoAeQBjADYASgAyADUAdgBiAG0AVQBuAE8A
>> "%~1" echo eQBRAG8ASgAyAFIAbABkAEUAUgBwAGMAMgBGAGkAYgBHAFUAbgBLAFMANQB6AGQA
>> "%~1" echo SABsAHMAWgBTADUAawBhAFgATgB3AGIARwBGADUAUABYAEkAdQBkAFgATgBsAGMA
>> "%~1" echo agAwADkAUABTAGQAMABjAG4AVgBsAEoAegA4AG4ASgB6AG8AbgBiAG0AOQB1AFoA
>> "%~1" echo UwBkADkAWQAyAEYAMABZADIAZwBvAFoAUwBsADcAYgBtADkAMABhAFcAWgA1AEsA
>> "%~1" echo QwBmAG8AcgA2AGIAbQBnADQAWABsAHAATABIAG8AdABLAFUAbgBMAEcAVQB1AGIA
>> "%~1" echo VwBWAHoAYwAyAEYAbgBaAFMAdwBuAFoAWABKAHkASgB5AGwAOQBmAFEAMABLAFkA
>> "%~1" echo WABOADUAYgBtAE0AZwBaAG4AVgB1AFkAMwBSAHAAYgAyADQAZwBZAFgAQgB3AFQA
>> "%~1" echo MwBBAG8AYgAzAEEAcwBaAFgAaAAwAGMAbQBFAHAAZQAyAGwAbQBLAEMARgBoAGMA
>> "%~1" echo SABCAFQAWgBXAHcAcABjAG0AVgAwAGQAWABKAHUATwAyAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo RwB4AGgAWQBtAFYAcwBjAHoAMQA3AGIARwBGADEAYgBtAE4AbwBPAGsAeABCAFQA
>> "%~1" echo awBjADkAUABUADAAbgBlAG0AZwBuAFAAeQBmAG0AaQBaAFAAbAB2AEkAQQBuAE8A
>> "%~1" echo aQBkAE0AWQBYAFYAdQBZADIAZwBuAEwARwBWADQAZABIAEoAaABZADMAUQA2AFQA
>> "%~1" echo RQBGAE8AUgB6ADAAOQBQAFMAZAA2AGEAQwBjAC8ASgArAGEAUABrAE8AVwBQAGwA
>> "%~1" echo aQBCAEIAVQBFAHMAbgBPAGkAZABGAGUASABSAHkAWQBXAE4AMABJAEUARgBRAFMA
>> "%~1" echo eQBjAHMASgAyAFoAdgBjAG0ATgBsAEwAWABOADAAYgAzAEEAbgBPAGsAeABCAFQA
>> "%~1" echo awBjADkAUABUADAAbgBlAG0AZwBuAFAAeQBmAGwAdgBMAHIAbwBvAFkAegBsAGcA
>> "%~1" echo WgB6AG0AcgBhAEkAbgBPAGkAZABHAGIAMwBKAGoAWgBTAEIAegBkAEcAOQB3AEoA
>> "%~1" echo eQB4ADEAYgBtAGwAdQBjADMAUgBoAGIARwB3ADYAVABFAEYATwBSAHoAMAA5AFAA
>> "%~1" echo UwBkADYAYQBDAGMALwBKACsAVwBOAHUATwBpADkAdgBTAGMANgBKADEAVgB1AGEA
>> "%~1" echo VwA1AHoAZABHAEYAcwBiAEMAYwBzAFkAMgB4AGwAWQBYAEkANgBUAEUARgBPAFIA
>> "%~1" echo egAwADkAUABTAGQANgBhAEMAYwAvAEoAKwBhADQAaABlAG0AWgBwAE8AYQBWAHMA
>> "%~1" echo TwBhAE4AcgBpAGMANgBKADAATgBzAFoAVwBGAHkASQBHAFIAaABkAEcARQBuAEwA
>> "%~1" echo RwBSAHAAYwAyAEYAaQBiAEcAVQA2AFQARQBGAE8AUgB6ADAAOQBQAFMAZAA2AGEA
>> "%~1" echo QwBjAC8ASgArAGUAbQBnAGUAZQBVAHEAQwBjADYASgAwAFIAcABjADIARgBpAGIA
>> "%~1" echo RwBVAG4ATABHAFYAdQBZAFcASgBzAFoAVABwAE0AUQBVADUASABQAFQAMAA5AEoA
>> "%~1" echo MwBwAG8ASgB6ADgAbgA1AFoAQwB2ADUANQBTAG8ASgB6AG8AbgBSAFcANQBoAFkA
>> "%~1" echo bQB4AGwASgB5AHgAbgBjAG0ARgB1AGQARABvAG4AWgAzAEoAaABiAG4AUQBuAEwA
>> "%~1" echo SABKAGwAZABtADkAcgBaAFQAbwBuAGMAbQBWADIAYgAyAHQAbABKADMAMAA3AGEA
>> "%~1" echo VwBZAG8AYgAzAEEAOQBQAFQAMABuAGQAVwA1AHAAYgBuAE4AMABZAFcAeABzAEoA
>> "%~1" echo eQBZAG0ASQBTAGgAaABkADIARgBwAGQAQwBCAGgAYwAyAHQARABiADIANQBtAGEA
>> "%~1" echo WABKAHQASwBHAHgAaABZAG0AVgBzAGMAeQA1ADEAYgBtAGwAdQBjADMAUgBoAGIA
>> "%~1" echo RwB3AHMAZABDAGcAbgBkAFcANQBwAGIAbgBOADAAWQBXAHgAcwBRAFgATgByAEoA
>> "%~1" echo eQBrAHIASgAxAHgAdQBKAHkAdABoAGMASABCAFQAWgBXAHcAcABLAFMAbAB5AFoA
>> "%~1" echo WABSADEAYwBtADQANwBhAFcAWQBvAGIAMwBBADkAUABUADAAbgBZADIAeABsAFkA
>> "%~1" echo WABJAG4ASgBpAFkAaABLAEcARgAzAFkAVwBsADAASQBHAEYAegBhADAATgB2AGIA
>> "%~1" echo bQBaAHAAYwBtADAAbwBiAEcARgBpAFoAVwB4AHoATABtAE4AcwBaAFcARgB5AEwA
>> "%~1" echo SABRAG8ASgAyAE4AcwBaAFcARgB5AFEAWABOAHIASgB5AGsAcgBKADEAeAB1AEoA
>> "%~1" echo eQB0AGgAYwBIAEIAVABaAFcAdwBwAEsAUwBsAHkAWgBYAFIAMQBjAG0ANAA3AGEA
>> "%~1" echo VwBZAG8AYgAzAEEAOQBQAFQAMABuAFoARwBsAHoAWQBXAEoAcwBaAFMAYwBtAEoA
>> "%~1" echo aQBFAG8AWQBYAGQAaABhAFgAUQBnAFkAWABOAHIAUQAyADkAdQBaAG0AbAB5AGIA
>> "%~1" echo UwBoAHMAWQBXAEoAbABiAEgATQB1AFoARwBsAHoAWQBXAEoAcwBaAFMAeAAwAEsA
>> "%~1" echo QwBkAGsAYQBYAE4AaABZAG0AeABsAFEAWABOAHIASgB5AGsAcgBKADEAeAB1AEoA
>> "%~1" echo eQB0AGgAYwBIAEIAVABaAFcAdwBwAEsAUwBsAHkAWgBYAFIAMQBjAG0ANAA3AGIA
>> "%~1" echo RwBWADAASQBIAEYAegBQAFMAZAB2AGMARAAwAG4ASwAyAFYAdQBZADIAOQBrAFoA
>> "%~1" echo VgBWAFMAUwBVAE4AdgBiAFgAQgB2AGIAbQBWAHUAZABDAGgAdgBjAEMAawByAEoA
>> "%~1" echo eQBaAHcAWQBXAE4AcgBZAFcAZABsAFAAUwBjAHIAWgBXADUAagBiADIAUgBsAFYA
>> "%~1" echo VgBKAEoAUQAyADkAdABjAEcAOQB1AFoAVwA1ADAASwBHAEYAdwBjAEYATgBsAGIA
>> "%~1" echo QwBrADcAYQBXAFkAbwBaAFgAaAAwAGMAbQBFAG0ASgBtAFYANABkAEgASgBoAEwA
>> "%~1" echo bgBCAGwAYwBtADEAcABjADMATgBwAGIAMgA0AHAAYwBYAE0AcgBQAFMAYwBtAGMA
>> "%~1" echo RwBWAHkAYgBXAGwAegBjADIAbAB2AGIAagAwAG4ASwAyAFYAdQBZADIAOQBrAFoA
>> "%~1" echo VgBWAFMAUwBVAE4AdgBiAFgAQgB2AGIAbQBWAHUAZABDAGgAbABlAEgAUgB5AFkA
>> "%~1" echo UwA1AHcAWgBYAEoAdABhAFgATgB6AGEAVwA5AHUASwBUAHQAcABaAGkAaAB2AGMA
>> "%~1" echo QwBFADkAUABTAGQAbABlAEgAUgB5AFkAVwBOADAASgB5AFkAbQBiADMAQQBoAFAA
>> "%~1" echo VAAwAG4AYgBHAEYAMQBiAG0ATgBvAEoAeQBsAHgAYwB5AHMAOQBKAHkAWgBqAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABQAFYAbABGAFUAeQBjADcAZABIAEoANQBlADMATgBsAGQA
>> "%~1" echo RQBKADEAYwAzAGsAbwBkAEgASgAxAFoAUwB4AHUAZABXAHgAcwBLAFQAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAeQBQAFcARgAzAFkAVwBsADAASQBHAEYAdwBhAFMAZwBuAEwA
>> "%~1" echo MgBGAHcAYQBTADkAaABjAEgAQgB6AEwAMgBGAGoAZABHAGwAdgBiAGoAOABuAEsA
>> "%~1" echo MwBGAHoATABIAHQAdABaAFgAUgBvAGIAMgBRADYASgAxAEIAUABVADEAUQBuAGYA
>> "%~1" echo UwBrADcAYQBXAFkAbwBjAGkANQB2AGEAeQBFADkAUABTAGQAMABjAG4AVgBsAEoA
>> "%~1" echo eQBsADAAYQBIAEoAdgBkAHkAQgB1AFoAWABjAGcAUgBYAEoAeQBiADMASQBvAGMA
>> "%~1" echo aQA1AGwAYwBuAEoAdgBjAG4AeAA4AEoAMgBaAGgAYQBXAHgAbABaAEMAYwBwAE8A
>> "%~1" echo MgA1AHYAZABHAGwAbQBlAFMAaABzAFkAVwBKAGwAYgBIAE4AYgBiADMAQgBkAGYA
>> "%~1" echo SAB4AHYAYwBDAHgAeQBMAG4ASgBsAGMAMwBWAHMAZABIAHgAOABKADIAOQByAEoA
>> "%~1" echo eQB3AG4AYgAyAHMAbgBLAFQAdABwAFoAaQBoAHkATABuAFYAeQBiAEMAbAA3AGMA
>> "%~1" echo MgBWADAASwBDAGQAawBaAFgAUgBGAGUASABSAHkAWQBXAE4AMABTAEcAbAB1AGQA
>> "%~1" echo QwBjAHMASwBIAEkAdQBjADIAbAA2AFoAVgBSAGwAZQBIAFIAOABmAEMAYwBuAEsA
>> "%~1" echo UwBzAG4ASQBDAEEAbgBLAHkAQQBvAGMAaQA1AG0AYQBXAHgAbABUAG0ARgB0AFoA
>> "%~1" echo WAB4ADgASgB5AGMAcABLAFQAdABqAGIAMgA1AHoAZABDAEIAaABQAFcAUgB2AFkA
>> "%~1" echo MwBWAHQAWgBXADUAMABMAG0ATgB5AFoAVwBGADAAWgBVAFYAcwBaAFcAMQBsAGIA
>> "%~1" echo bgBRAG8ASgAyAEUAbgBLAFQAdABoAEwAbQBoAHkAWgBXAFkAOQBjAGkANQAxAGMA
>> "%~1" echo bQB3ADcAWQBTADUAMABaAFgAaAAwAFEAMgA5AHUAZABHAFYAdQBkAEQAMQB5AEwA
>> "%~1" echo bQBaAHAAYgBHAFYATwBZAFcAMQBsAGYASAB3AG4AWQBYAEIAcgBKAHoAdABoAEwA
>> "%~1" echo bgBOADAAZQBXAHgAbABMAG0AMQBoAGMAbQBkAHAAYgBrAHgAbABaAG4AUQA5AEoA
>> "%~1" echo egBoAHcAZQBDAGMANwBKAEMAZwBuAFoARwBWADAAUgBYAGgAMABjAG0ARgBqAGQA
>> "%~1" echo RQBoAHAAYgBuAFEAbgBLAFMANQBoAGMASABCAGwAYgBtAFIARABhAEcAbABzAFoA
>> "%~1" echo QwBoAGgASwBYADEAcABaAGkAaAB2AGMARAAwADkAUABTAGQAMQBiAG0AbAB1AGMA
>> "%~1" echo MwBSAGgAYgBHAHcAbgBLAFgAdABoAGMASABCAFQAWgBXAHcAOQBiAG4AVgBzAGIA
>> "%~1" echo RABzAGsASwBDAGQAaABjAEgAQgBFAFoAWABSAGgAYQBXAHgAQwBiADIAUgA1AEoA
>> "%~1" echo eQBrAHUAYwAzAFIANQBiAEcAVQB1AFoARwBsAHoAYwBHAHgAaABlAFQAMABuAGIA
>> "%~1" echo bQA5AHUAWgBTAGMANwBKAEMAZwBuAFkAWABCAHcAUgBHAFYAMABZAFcAbABzAFIA
>> "%~1" echo VwAxAHcAZABIAGsAbgBLAFMANQB6AGQASABsAHMAWgBTADUAawBhAFgATgB3AGIA
>> "%~1" echo RwBGADUAUABTAGMAbgBPADIARgAzAFkAVwBsADAASQBHAHgAdgBZAFcAUgBCAGMA
>> "%~1" echo SABCAHoASwBIAFIAeQBkAFcAVQBwAGYAVwBWAHMAYwAyAFUAZwBZAFgAZABoAGEA
>> "%~1" echo WABRAGcAYgAzAEIAbABiAGsARgB3AGMAQwBoAGgAYwBIAEIAVABaAFcAdwBwAGYA
>> "%~1" echo VwBOAGgAZABHAE4AbwBLAEcAVQBwAGUAMgA1AHYAZABHAGwAbQBlAFMAaABzAFkA
>> "%~1" echo VwBKAGwAYgBIAE4AYgBiADMAQgBkAGYASAB4AHYAYwBDAHgAbABMAG0AMQBsAGMA
>> "%~1" echo MwBOAGgAWgAyAFUAcwBKADIAVgB5AGMAaQBjAHAAZgBXAFoAcABiAG0ARgBzAGIA
>> "%~1" echo SABsADcAYwAyAFYAMABRAG4AVgB6AGUAUwBoAG0AWQBXAHgAegBaAFMAeAB1AGQA
>> "%~1" echo VwB4AHMASwBYADEAOQBEAFEAcABqAGIAMgA1AHoAZABDAEIAbwBjADAAMQBsAGQA
>> "%~1" echo RwBFADkAZQB3ADAASwBKADIAZABzAGIAMgBKAGgAYgBDADUAegBkAEcARgA1AFgA
>> "%~1" echo MgA5AHUAWAAzAGQAbwBhAFcAeABsAFgAMwBCAHMAZABXAGQAbgBaAFcAUgBmAGEA
>> "%~1" echo VwA0AG4ATwBuAHQANgBhAEQAbwBuADUAbwArAFMANQA1AFMAMQA1AEwAKwBkADUA
>> "%~1" echo bwB5AEIANQBaAFMAawA2AFkAYQBTAEoAeQB4AGwAYgBqAG8AbgBVADMAUgBoAGUA
>> "%~1" echo UwBCAHYAYgBpAEIAMwBhAEcAbABzAFoAUwBCAHcAYgBIAFYAbgBaADIAVgBrAEoA
>> "%~1" echo eQB4AHUAYgAzAFIAbABPAGkAYwB3AFAAVwA5AG0AWgBpAEEAegBQAFYAVgBUAFEA
>> "%~1" echo aQA5AEIAUQB5AGQAOQBMAEEAMABLAEoAMwBOADUAYwAzAFIAbABiAFMANQB6AFkA
>> "%~1" echo MwBKAGwAWgBXADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgAUQBuAE8A
>> "%~1" echo bgB0ADYAYQBEAG8AbgA1AGIARwBQADUAYgBtAFYANgBMAGEARgA1AHAAZQAyAEkA
>> "%~1" echo QwBoAHQAYwB5AGsAbgBMAEcAVgB1AE8AaQBkAFQAWQAzAEoAbABaAFcANABnAGIA
>> "%~1" echo MgBaAG0ASQBIAFIAcABiAFcAVgB2AGQAWABRAGcASwBHADEAegBLAFMAYwBzAGIA
>> "%~1" echo bQA5ADAAWgBUAG8AbgBNAHoAQQB3AE0ARABBAHcAUABUAFYAdABhAFcANABnAE8A
>> "%~1" echo RABZADAATQBEAEEAdwBNAEQAQQA5AE0AagBSAG8ASgAzADAAcwBEAFEAbwBuAGMA
>> "%~1" echo MgBWAGoAZABYAEoAbABMAG4ATgBzAFoAVwBWAHcAWAAzAFIAcABiAFcAVgB2AGQA
>> "%~1" echo WABRAG4ATwBuAHQANgBhAEQAbwBuADUANwBPADcANQA3AHUAZgA1ADUAMgBoADUA
>> "%~1" echo NQB5AGcANgBMAGEARgA1AHAAZQAyAEoAeQB4AGwAYgBqAG8AbgBVADIAeABsAFoA
>> "%~1" echo WABBAGcAZABHAGwAdABaAFcAOQAxAGQAQwBjAHMAYgBtADkAMABaAFQAbwBuAGIA
>> "%~1" echo bgBWAHMAYgBEADEAawBaAFcAWgBoAGQAVwB4ADAASQBDADAAeABQAFcANQBsAGQA
>> "%~1" echo bQBWAHkASgAzADAAcwBEAFEAbwBuAFoAMgB4AHYAWQBtAEYAcwBMAG4AZABwAFoA
>> "%~1" echo bQBsAGYAYwAyAHgAbABaAFgAQgBmAGMARwA5AHMAYQBXAE4ANQBKAHoAcAA3AGUA
>> "%~1" echo bQBnADYASgAxAGQAcABMAFUAWgBwAEkATwBTADgAawBlAGUAYwBvAE8AZQB0AGwA
>> "%~1" echo dQBlAFYAcABTAGMAcwBaAFcANAA2AEoAMQBkAHAATABVAFoAcABJAEgATgBzAFoA
>> "%~1" echo VwBWAHcASQBIAEIAdgBiAEcAbABqAGUAUwBjAHMAYgBtADkAMABaAFQAbwBuAE0A
>> "%~1" echo VAAxAGsAWgBXAFoAaABkAFcAeAAwAEkARABJADkAYgBtAFYAMgBaAFgASQBuAGYA
>> "%~1" echo UwB3AE4AQwBpAGQAegBlAFgATgAwAFoAVwAwAHUAYwAyAE4AeQBaAFcAVgB1AFgA
>> "%~1" echo MgBKAHkAYQBXAGQAbwBkAEcANQBsAGMAMwBNAG4ATwBuAHQANgBhAEQAbwBuADUA
>> "%~1" echo TABxAHUANQBiAHEAbQBJAEQAQQB0AE0AagBVADEASgB5AHgAbABiAGoAbwBuAFEA
>> "%~1" echo bgBKAHAAWgAyAGgAMABiAG0AVgB6AGMAeQBBAHcATABUAEkAMQBOAFMAYwBzAGIA
>> "%~1" echo bQA5ADAAWgBUAG8AbgBKADMAMABzAEQAUQBvAG4AYwAzAGwAegBkAEcAVgB0AEwA
>> "%~1" echo bQBaAHYAYgBuAFIAZgBjADIATgBoAGIARwBVAG4ATwBuAHQANgBhAEQAbwBuADUA
>> "%~1" echo YQAyAFgANQBMADIAVAA1ADcAeQBwADUAcABTACsASgB5AHgAbABiAGoAbwBuAFIA
>> "%~1" echo bQA5AHUAZABDAEIAegBZADIARgBzAFoAUwBjAHMAYgBtADkAMABaAFQAbwBuAEoA
>> "%~1" echo MwAwAHMARABRAG8AbgBjADMAbAB6AGQARwBWAHQATABtAGgAaABjAEgAUgBwAFkA
>> "%~1" echo MQA5AG0AWgBXAFYAawBZAG0ARgBqAGEAMQA5AGwAYgBtAEYAaQBiAEcAVgBrAEoA
>> "%~1" echo egBwADcAZQBtAGcANgBKACsAaQBuAHAAdQBhAEUAbgArAFcAUABqAGUAbQBtAGkA
>> "%~1" echo QwBjAHMAWgBXADQANgBKADAAaABoAGMASABSAHAAWQAzAE0AbgBMAEcANQB2AGQA
>> "%~1" echo RwBVADYASgB6AEEAdgBNAFMAZAA5AEwAQQAwAEsASgAzAE4AbABZADMAVgB5AFoA
>> "%~1" echo UwA1AG8AYgAzAEoAcABlAG0AOQB1AGIAMwBNADYAZAAyADkAeQBiAEcAUgBmAGIA
>> "%~1" echo VwA5ADIAWgBXADEAbABiAG4AUgBmAGQASABWAHkAYgBsADkAMABlAFgAQgBsAEoA
>> "%~1" echo egBwADcAZQBtAGcANgBKACsAaQA5AHIATwBXAFEAawBlAGUAeAB1ACsAVwBlAGkA
>> "%~1" echo eQBjAHMAWgBXADQANgBKADEAUgAxAGMAbQA0AGcAZABIAGwAdwBaAFMAYwBzAGIA
>> "%~1" echo bQA5ADAAWgBUAG8AbgBVAFgAVgBsAGMAMwBRAGcAYgBXADkAMgBaAFcAMQBsAGIA
>> "%~1" echo bgBRAG4AZgBTAHcATgBDAGkAZAB6AFoAVwBOADEAYwBtAFUAdQBhAEcAOQB5AGEA
>> "%~1" echo WABwAHYAYgBtADkAegBPAG4AZAB2AGMAbQB4AGsAWAAyADEAdgBkAG0AVgB0AFoA
>> "%~1" echo VwA1ADAAWAAzAE4AdQBZAFgAQgBmAGQASABWAHkAYgBsADkAaABiAG0AZABzAFoA
>> "%~1" echo UwBjADYAZQAzAHAAbwBPAGkAZgBsAHYANgB2AG8AdgBhAHoAbwBwADUATABsAHUA
>> "%~1" echo cQBZAG4ATABHAFYAdQBPAGkAZABUAGIAbQBGAHcASQBIAFIAMQBjAG0ANABnAFkA
>> "%~1" echo VwA1AG4AYgBHAFUAbgBMAEcANQB2AGQARwBVADYASgB5AGQAOQBMAEEAMABLAEoA
>> "%~1" echo MwBOAGwAWQAzAFYAeQBaAFMANQBvAGIAMwBKAHAAZQBtADkAdQBiADMATQA2AGQA
>> "%~1" echo MgA5AHkAYgBHAFIAZgBiAFcAOQAyAFoAVwAxAGwAYgBuAFIAZgBiAG0ARgB5AGMA
>> "%~1" echo bQA5ADMAWAAzAFoAcABjADIAbAB2AGIAbAA5AG0AYgAzAEoAZgBZADIAOQB0AFoA
>> "%~1" echo bQA5AHkAZABDAGMANgBlADMAcABvAE8AaQBmAG8AaQBKAEwAcABnAEkATABuAHEA
>> "%~1" echo bwBUAG8AcAA0AGIAcABoADQANABuAEwARwBWAHUATwBpAGQARABiADIAMQBtAGIA
>> "%~1" echo MwBKADAASQBIAFIAMQBiAG0ANQBsAGIAQwBCADIAYQBYAE4AcABiADIANABuAEwA
>> "%~1" echo RwA1AHYAZABHAFUANgBKAHoAQQB2AE0AUwBkADkARABRAHAAOQBPAHcAMABLAFoA
>> "%~1" echo bgBWAHUAWQAzAFIAcABiADIANABnAGEASABOAEgAYwBtADkAMQBjAEMAaABwAFoA
>> "%~1" echo QwBsADcAYQBXAFkAbwBhAFcAUQB1AGEAVwA1AGsAWgBYAGgAUABaAGkAZwBuAGEA
>> "%~1" echo RwA5AHkAYQBYAHAAdgBiAG0AOQB6AEoAeQBrACsAUABUAEEAcABjAG0AVgAwAGQA
>> "%~1" echo WABKAHUASQBDAGQAbwBjADAATgB2AGIAVwBaAHYAYwBuAFEAbgBPADIAbABtAEsA
>> "%~1" echo RwBsAGsATABtAGwAdQBaAEcAVgA0AFQAMgBZAG8ASgAyAEoAeQBhAFcAZABvAGQA
>> "%~1" echo RwA1AGwAYwAzAE0AbgBLAFQANAA5AE0ASAB4ADgAYQBXAFEAdQBhAFcANQBrAFoA
>> "%~1" echo WABoAFAAWgBpAGcAbgBaAG0AOQB1AGQARgA5AHoAWQAyAEYAcwBaAFMAYwBwAFAA
>> "%~1" echo agAwAHcAZgBIAHgAcABaAEMANQBwAGIAbQBSAGwAZQBFADkAbQBLAEMAZABvAFkA
>> "%~1" echo WABCADAAYQBXAE0AbgBLAFQANAA5AE0AQwBsAHkAWgBYAFIAMQBjAG0ANABnAEoA
>> "%~1" echo MgBoAHoAUgBHAGwAegBjAEcAeABoAGUAUwBjADcAYwBtAFYAMABkAFgASgB1AEkA
>> "%~1" echo QwBkAG8AYwAxAEIAdgBkADIAVgB5AFQARwBsAHoAZABDAGQAOQBEAFEAcABoAGMA
>> "%~1" echo MwBsAHUAWQB5AEIAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAeQBaAFcANQBrAFoA
>> "%~1" echo WABKAEkAWgBXAEYAawBjADIAVgAwAEsAQwBsADcAWQAyADkAdQBjADMAUQBnAGMA
>> "%~1" echo RwA5ADMAWgBYAEkAOQBKAEMAZwBuAGEASABOAFEAYgAzAGQAbABjAGsAeABwAGMA
>> "%~1" echo MwBRAG4ASwBUAHQAcABaAGkAZwBoAGMARwA5ADMAWgBYAEkAcABjAG0AVgAwAGQA
>> "%~1" echo WABKAHUATwAyAGwAbQBLAEcAeABoAGMAMwBRAHUAWQAyADkAdQBiAG0AVgBqAGQA
>> "%~1" echo RwBWAGsAUABUADAAOQBKADMAUgB5AGQAVwBVAG4ASwBYAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCADMAWQBYAEoAdQBQAFMAaABUAGQASABKAHAAYgBtAGMAbwBiAEcARgB6AGQA
>> "%~1" echo QwA1AHoAWQAzAEoAbABaAFcANQBQAFoAbQBZAHAAUABUADAAOQBKAHoAZwAyAE4A
>> "%~1" echo RABBAHcATQBEAEEAdwBKADMAeAA4AFUAMwBSAHkAYQBXADUAbgBLAEcAeABoAGMA
>> "%~1" echo MwBRAHUAYwAyAHgAbABaAFgAQgBVAGEAVwAxAGwAYgAzAFYAMABLAFQAMAA5AFAA
>> "%~1" echo UwBjAHQATQBTAGMAcABPAHkAUQBvAEoAMgBoAHoAVgAyAEYAeQBiAGkAYwBwAEwA
>> "%~1" echo bgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABYAGQAaABjAG0ANAAvAEsA
>> "%~1" echo RQB4AEIAVABrAGMAOQBQAFQAMABuAGUAbQBnAG4AUAB5AGYAbAB2AFoAUABsAGkA
>> "%~1" echo WQAzAG0AbQBLADgAZwBNAGoAUgBvAEwAKwBTADQAagBlAFMAOABrAGUAZQBjAG8A
>> "%~1" echo QwBEAG8AcwBJAFAAbwByADUAWABsAGcATAB3AG4ATwBpAGMAeQBOAEcAZwBnAEwA
>> "%~1" echo eQBCAHUAYgB5ADEAegBiAEcAVgBsAGMAQwBCAGsAWgBXAEoAMQBaAHkAQgAyAFkA
>> "%~1" echo VwB4ADEAWgBYAE0AbgBLAFQAbwBuAEoAegBzAGsASwBDAGQAbwBjADAAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGwAVQBZAFcAYwBuAEsAUwA1ADAAWgBYAGgAMABRADIAOQB1AGQA
>> "%~1" echo RwBWAHUAZABEADEAcwBZAFgATgAwAEwAbQBSAHAAYwAzAEIAcwBZAFgAbABUAGQA
>> "%~1" echo VwAxAHQAWQBYAEoANQBmAEgAdwBuAEwAUwBjADcAZABIAEoANQBlADIATgB2AGIA
>> "%~1" echo bgBOADAASQBIAEkAOQBZAFgAZABoAGEAWABRAGcAWQBYAEIAcABLAEMAYwB2AFkA
>> "%~1" echo WABCAHAATAAzAEYAMQBaAFgATgAwAEwAWABOAGwAZABIAFIAcABiAG0AZAB6AEoA
>> "%~1" echo eQBrADcAYQBXAFkAbwBjAGkANQB2AGEAegAwADkAUABTAGQAMABjAG4AVgBsAEoA
>> "%~1" echo eQBsAG8AYwAwAE4AaABZADIAaABsAFAAVQBwAFQAVAAwADQAdQBjAEcARgB5AGMA
>> "%~1" echo MgBVAG8AYwBpADUAegBaAFgAUgAwAGEAVwA1AG4AYwAwAHAAegBiADIANQA4AGYA
>> "%~1" echo QwBkAGIAWABTAGMAcABmAFcATgBoAGQARwBOAG8ASwBHAFUAcABlADIAaAB6AFEA
>> "%~1" echo MgBGAGoAYQBHAFUAOQBXADEAMQA5AGYAVgBzAG4AYQBIAE4AUQBiADMAZABsAGMA
>> "%~1" echo awB4AHAAYwAzAFEAbgBMAEMAZABvAGMAMABSAHAAYwAzAEIAcwBZAFgAawBuAEwA
>> "%~1" echo QwBkAG8AYwAwAE4AdgBiAFcAWgB2AGMAbgBRAG4AWABTADUAbQBiADMASgBGAFkA
>> "%~1" echo VwBOAG8ASwBHAGwAawBQAFQANQA3AGEAVwBZAG8ASgBDAGgAcABaAEMAawBnAEoA
>> "%~1" echo aQBZAGcAYQBXAFEAaABQAFQAMABuAGEASABOAFEAYgAzAGQAbABjAGsAeABwAGMA
>> "%~1" echo MwBRAG4ASwBTAFEAbwBhAFcAUQBwAEwAbQBsAHUAYgBtAFYAeQBTAEYAUgBOAFQA
>> "%~1" echo RAAwAG4ASgAzADAAcABPADIAbABtAEsAQwBRAG8ASgAyAGgAegBVAEcAOQAzAFoA
>> "%~1" echo WABKAE0AYQBYAE4AMABKAHkAawBwAGUAeQA4AHEASQBHAHQAbABaAFgAQQBnAGMA
>> "%~1" echo RwBGAHkAWQBXADEATQBhAFgATgAwAEkARwBOAHMAYgAyADUAbABJAEgAWgBwAFkA
>> "%~1" echo UwBCAHoAWgBYAFEAZwBjAG0AOQAzAGMAeQBBAHEATAAzADAATgBDAG0ATgB2AGIA
>> "%~1" echo bgBOADAASQBHAGgAdgBjADMAUgB6AFAAWAB0AG8AYwAxAEIAdgBkADIAVgB5AFQA
>> "%~1" echo RwBsAHoAZABEAG8AawBLAEMAZABvAGMAMQBCAHYAZAAyAFYAeQBUAEcAbAB6AGQA
>> "%~1" echo QwBjAHAATABHAGgAegBSAEcAbAB6AGMARwB4AGgAZQBUAG8AawBLAEMAZABvAGMA
>> "%~1" echo MABSAHAAYwAzAEIAcwBZAFgAawBuAEsAUwB4AG8AYwAwAE4AdgBiAFcAWgB2AGMA
>> "%~1" echo bgBRADYASgBDAGcAbgBhAEgATgBEAGIAMgAxAG0AYgAzAEoAMABKAHkAbAA5AE8A
>> "%~1" echo MAA5AGkAYQBtAFYAagBkAEMANQByAFoAWABsAHoASwBHAGgAdgBjADMAUgB6AEsA
>> "%~1" echo UwA1AG0AYgAzAEoARgBZAFcATgBvAEsARwBzADkAUABuAHQAcABaAGkAaAByAEkA
>> "%~1" echo VAAwADkASgAyAGgAegBVAEcAOQAzAFoAWABKAE0AYQBYAE4AMABKAHkAQQBtAEoA
>> "%~1" echo aQBCAG8AYgAzAE4AMABjADEAdAByAFgAUwBsAG8AYgAzAE4AMABjADEAdAByAFgA
>> "%~1" echo UwA1AHAAYgBtADUAbABjAGsAaABVAFQAVQB3ADkASgB5AGQAOQBLAFQAcwBOAEMA
>> "%~1" echo bQBsAG0ASwBDAFEAbwBKADIAaAB6AFUARwA5ADMAWgBYAEoATQBhAFgATgAwAEoA
>> "%~1" echo eQBrAHAASgBDAGcAbgBhAEgATgBRAGIAMwBkAGwAYwBrAHgAcABjADMAUQBuAEsA
>> "%~1" echo UwA1AHAAYgBtADUAbABjAGsAaABVAFQAVQB3ADkASgB5AGMANwBEAFEAcABvAGMA
>> "%~1" echo MABOAGgAWQAyAGgAbABMAG0AWgB2AGMAawBWAGgAWQAyAGcAbwBhAFgAUgBsAGIA
>> "%~1" echo VAAwACsAZQAyAE4AdgBiAG4ATgAwAEkARwAxAGwAZABHAEUAOQBhAEgATgBOAFoA
>> "%~1" echo WABSAGgAVwAyAGwAMABaAFcAMAB1AGEAVwBSAGQAZgBIAHgANwBlAG0AZwA2AGEA
>> "%~1" echo WABSAGwAYgBTADUAcgBaAFgAawBzAFoAVwA0ADYAYQBYAFIAbABiAFMANQByAFoA
>> "%~1" echo WABrAHMAYgBtADkAMABaAFQAcABwAGQARwBWAHQATABtAGwAawBmAFQAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAbwBiADMATgAwAFAAVwBoAHYAYwAzAFIAegBXADIAaAB6AFIA
>> "%~1" echo MwBKAHYAZABYAEEAbwBhAFgAUgBsAGIAUwA1AHAAWgBDAGwAZABPADIAbABtAEsA
>> "%~1" echo QwBGAG8AYgAzAE4AMABLAFgASgBsAGQASABWAHkAYgBqAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAHkAYgAzAGMAOQBaAEcAOQBqAGQAVwAxAGwAYgBuAFEAdQBZADMASgBsAFkA
>> "%~1" echo WABSAGwAUgBXAHgAbABiAFcAVgB1AGQAQwBnAG4AWgBHAGwAMgBKAHkAawA3AGMA
>> "%~1" echo bQA5ADMATABtAE4AcwBZAFgATgB6AFQAbQBGAHQAWgBUADAAbgBjADIAVgAwAFUA
>> "%~1" echo bQA5ADMASgB6AHQAeQBiADMAYwB1AGEAVwA1AHUAWgBYAEoASQBWAEUAMQBNAFAA
>> "%~1" echo UwBjADgAWgBHAGwAMgBQAGoAeABpAFAAaQBjAHIAWgBYAE4AagBLAEUAeABCAFQA
>> "%~1" echo awBjADkAUABUADAAbgBlAG0AZwBuAFAAMgAxAGwAZABHAEUAdQBlAG0AZwA2AGIA
>> "%~1" echo VwBWADAAWQBTADUAbABiAGkAawByAEoAegB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA0AG4ASwAyAFYAegBZAHkAaABwAGQARwBWAHQATABtAGwAawBLAFMAcwBuAEkA
>> "%~1" echo TQBLADMASQBDAGMAcgBaAFgATgBqAEsARwAxAGwAZABHAEUAdQBiAG0AOQAwAFoA
>> "%~1" echo WAB4ADgASgB5AGMAcABLAHkAYwA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAGwAdQBjAEgAVgAwAEkARwBSAGgAZABHAEUAdABhAEgATQA5AEkA
>> "%~1" echo aQBjAHIAWgBYAE4AagBLAEcAbAAwAFoAVwAwAHUAYQBXAFEAcABLAHkAYwBpAEkA
>> "%~1" echo SABaAGgAYgBIAFYAbABQAFMASQBuAEsAMgBWAHoAWQB5AGgAcABkAEcAVgB0AEwA
>> "%~1" echo bgBaAGgAYgBIAFYAbABmAEgAdwBuAEoAeQBrAHIASgB5AEkAKwBQAEcASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAYwBtAFYAegBaAFgAUgBDAGQA
>> "%~1" echo RwA0AGcAYwBIAEoAcABiAFcARgB5AGUAUwBJAGcAWgBHAEYAMABZAFMAMQBvAGMA
>> "%~1" echo eQAxAHoAWQBYAFoAbABQAFMASQBuAEsAMgBWAHoAWQB5AGgAcABkAEcAVgB0AEwA
>> "%~1" echo bQBsAGsASwBTAHMAbgBJAGoANABuAEsAeQBoAE0AUQBVADUASABQAFQAMAA5AEoA
>> "%~1" echo MwBwAG8ASgB6ADgAbgA1AFkAYQBaADUAWQBXAGwASgB6AG8AbgBVADIAVgAwAEoA
>> "%~1" echo eQBrAHIASgB6AHcAdgBZAG4AVgAwAGQARwA5AHUAUABpAGMANwBhAEcAOQB6AGQA
>> "%~1" echo QwA1AGgAYwBIAEIAbABiAG0AUgBEAGEARwBsAHMAWgBDAGgAeQBiADMAYwBwAGYA
>> "%~1" echo UwBrADcARABRAHAAawBiADIATgAxAGIAVwBWAHUAZABDADUAeABkAFcAVgB5AGUA
>> "%~1" echo VgBOAGwAYgBHAFYAagBkAEcAOQB5AFEAVwB4AHMASwBDAGQAYgBaAEcARgAwAFkA
>> "%~1" echo UwAxAG8AYwB5ADEAegBZAFgAWgBsAFgAUwBjAHAATABtAFoAdgBjAGsAVgBoAFkA
>> "%~1" echo MgBnAG8AWQBuAFIAdQBQAFQANQBpAGQARwA0AHUAYgAyADUAagBiAEcAbABqAGEA
>> "%~1" echo egAwAG8ASwBUADAAKwBlADIATgB2AGIAbgBOADAASQBHAGwAawBQAFcASgAwAGIA
>> "%~1" echo aQA1AG4AWgBYAFIAQgBkAEgAUgB5AGEAVwBKADEAZABHAFUAbwBKADIAUgBoAGQA
>> "%~1" echo RwBFAHQAYQBIAE0AdABjADIARgAyAFoAUwBjAHAATwAyAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo RwBsAHUAYwBEADEAawBiADIATgAxAGIAVwBWAHUAZABDADUAeABkAFcAVgB5AGUA
>> "%~1" echo VgBOAGwAYgBHAFYAagBkAEcAOQB5AEsAQwBkAGIAWgBHAEYAMABZAFMAMQBvAGMA
>> "%~1" echo egAwAGkASgB5AHQAcABaAEMAcwBuAEkAbAAwAG4ASwBUAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAGsAYgAzAFEAOQBhAFcAUQB1AGEAVwA1AGsAWgBYAGgAUABaAGkAZwBuAEwA
>> "%~1" echo aQBjAHAATwAyAE4AdgBiAG4ATgAwAEkARwA1AHoAUABXAGwAawBMAG4ATgBzAGEA
>> "%~1" echo VwBOAGwASwBEAEEAcwBaAEcAOQAwAEsAUwB4AHIAWgBYAGsAOQBhAFcAUQB1AGMA
>> "%~1" echo MgB4AHAAWQAyAFUAbwBaAEcAOQAwAEsAegBFAHAATwAzAE4AbwBiADMAZABEAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABLAEMAZAB4AGQAVwBWAHoAZABGADkAdwBkAFgAUQBuAEwA
>> "%~1" echo RQB4AEIAVABrAGMAOQBQAFQAMABuAGUAbQBnAG4AUAB5AGYAbABoAHAAbgBsAGgA
>> "%~1" echo YQBYAG8AcgByADcAbgB2AGEANABuAE8AaQBkAFgAYwBtAGwAMABaAFMAQgB6AFoA
>> "%~1" echo WABSADAAYQBXADUAbgBKAHkAdwBuAEoAbQA1AHoAUABTAGMAcgBaAFcANQBqAGIA
>> "%~1" echo MgBSAGwAVgBWAEoASgBRADIAOQB0AGMARwA5AHUAWgBXADUAMABLAEcANQB6AEsA
>> "%~1" echo UwBzAG4ASgBtAHQAbABlAFQAMABuAEsAMgBWAHUAWQAyADkAawBaAFYAVgBTAFMA
>> "%~1" echo VQBOAHYAYgBYAEIAdgBiAG0AVgB1AGQAQwBoAHIAWgBYAGsAcABLAHkAYwBtAGQA
>> "%~1" echo bQBGAHMAZABXAFUAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIA
>> "%~1" echo MgAxAHcAYgAyADUAbABiAG4AUQBvAGEAVwA1AHcAUAAyAGwAdQBjAEMANQAyAFkA
>> "%~1" echo VwB4ADEAWgBUAG8AbgBKAHkAawBwAGYAUwBsADkARABRAHAAaABjADMAbAB1AFkA
>> "%~1" echo eQBCAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAGsAYgAzAGQAdQBiAEcAOQBoAFoA
>> "%~1" echo RQBGAGsAWQBpAGcAcABlADIAbABtAEsAQwBFAG8AWQBYAGQAaABhAFgAUQBnAFkA
>> "%~1" echo WABOAHIAUQAyADkAdQBaAG0AbAB5AGIAUwBoADAASwBDAGQAaABaAEcASgBFAGIA
>> "%~1" echo MwBkAHUAYgBHADkAaABaAEMAYwBwAEwASABRAG8ASgAyAEYAawBZAGsAMQBwAGMA
>> "%~1" echo MwBOAHAAYgBtAGQASQBhAFcANQAwAEoAeQBrAHAASwBTAGwAeQBaAFgAUgAxAGMA
>> "%~1" echo bQA0ADcAZABIAEoANQBlADMATgBsAGQARQBKADEAYwAzAGsAbwBkAEgASgAxAFoA
>> "%~1" echo UwB4AHUAZABXAHgAcwBLAFQAdABqAGIAMgA1AHoAZABDAEIAeQBQAFcARgAzAFkA
>> "%~1" echo VwBsADAASQBHAEYAdwBhAFMAZwBuAEwAMgBGAHcAYQBTADkAaABaAEcASQB2AFoA
>> "%~1" echo RwA5ADMAYgBtAHgAdgBZAFcAUQAvAFkAMgA5AHUAWgBtAGwAeQBiAFQAMQBaAFIA
>> "%~1" echo VgBNAG4ATABIAHQAdABaAFgAUgBvAGIAMgBRADYASgAxAEIAUABVADEAUQBuAGYA
>> "%~1" echo UwBrADcAYQBXAFkAbwBjAGkANQB2AGEAeQBFADkAUABTAGQAMABjAG4AVgBsAEoA
>> "%~1" echo eQBsADAAYQBIAEoAdgBkAHkAQgB1AFoAWABjAGcAUgBYAEoAeQBiADMASQBvAGMA
>> "%~1" echo aQA1AGwAYwBuAEoAdgBjAG4AeAA4AEoAMgBSAHYAZAAyADUAcwBiADIARgBrAEkA
>> "%~1" echo RwBaAGgAYQBXAHgAbABaAEMAYwBwAE8AMgA1AHYAZABHAGwAbQBlAFMAaAAwAEsA
>> "%~1" echo QwBkAGgAWgBHAEoARQBiADMAZAB1AGIARwA5AGgAWgBDAGMAcABMAEgASQB1AGMA
>> "%~1" echo bQBWAHoAZABXAHgAMABmAEgAdwBuAGIAMgBzAG4ATABDAGQAdgBhAHkAYwBwAE8A
>> "%~1" echo MwBKAGwAWgBuAEoAbABjADIAZwBvAGQASABKADEAWgBTAGwAOQBZADIARgAwAFkA
>> "%~1" echo MgBnAG8AWgBTAGwANwBiAG0AOQAwAGEAVwBaADUASwBIAFEAbwBKADIARgBrAFkA
>> "%~1" echo awBSAHYAZAAyADUAcwBiADIARgBrAEoAeQBrAHMAWgBTADUAdABaAFgATgB6AFkA
>> "%~1" echo VwBkAGwATABDAGQAbABjAG4ASQBuAEsAWAAxAG0AYQBXADUAaABiAEcAeAA1AGUA
>> "%~1" echo MwBOAGwAZABFAEoAMQBjADMAawBvAFoAbQBGAHMAYwAyAFUAcwBiAG4AVgBzAGIA
>> "%~1" echo QwBsADkAZgBRADAASwBEAFEAbwB2AEsAaQBBAHQATABTADAAdABMAFMAMAB0AEwA
>> "%~1" echo UwAwAHQASQBIAGQAcABjAG0AbAB1AFoAeQBBAHQATABTADAAdABMAFMAMAB0AEwA
>> "%~1" echo UwAwAHQASQBDAG8AdgBEAFEAcABrAGIAMgBOADEAYgBXAFYAdQBkAEMANQB4AGQA
>> "%~1" echo VwBWAHkAZQBWAE4AbABiAEcAVgBqAGQARwA5AHkAUQBXAHgAcwBLAEMAZABiAFoA
>> "%~1" echo RwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA1AGQASgB5AGsAdQBaAG0AOQB5AFIA
>> "%~1" echo VwBGAGoAYQBDAGgAaQBQAFQANQBpAEwAbQA5AHUAWQAyAHgAcABZADIAcwA5AEsA
>> "%~1" echo QwBrADkAUABuAHQAagBiADIANQB6AGQAQwBCAHMAWQBXAEoAbABiAEQAMQBpAEwA
>> "%~1" echo bgBGADEAWgBYAEoANQBVADIAVgBzAFoAVwBOADAAYgAzAEkAbwBKADIASQBuAEsA
>> "%~1" echo VAA4AHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFIAOABmAEcASQB1AFoA
>> "%~1" echo RwBGADAAWQBYAE4AbABkAEMANQBoAFkAMwBSAHAAYgAyADQANwBhAFcAWQBvAFkA
>> "%~1" echo aQA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAWQAyADkAdQBkAEcARgBwAGIA
>> "%~1" echo bgBNAG8ASgAyAFIAaABiAG0AZABsAGMAawBGAGoAZABHAGwAdgBiAGkAYwBwAEsA
>> "%~1" echo WABOAG8AYgAzAGQARABiADIANQBtAGEAWABKAHQASwBHAEkAdQBaAEcARgAwAFkA
>> "%~1" echo WABOAGwAZABDADUAaABZADMAUgBwAGIAMgA0AHMAYgBHAEYAaQBaAFcAdwBzAEoA
>> "%~1" echo eQBjAHAATwAyAFYAcwBjADIAVQBnAFkAVwBOADAAYQBXADkAdQBLAEcASQB1AFoA
>> "%~1" echo RwBGADAAWQBYAE4AbABkAEMANQBoAFkAMwBSAHAAYgAyADQAcwBKAHkAYwBzAGIA
>> "%~1" echo RwBGAGkAWgBXAHcAcwBZAGkAeABtAFkAVwB4AHoAWgBTAGwAOQBLAFQAcwBOAEMA
>> "%~1" echo aQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMAbQAxAEQAWQBXADUAagBaAFcAdwBuAEsA
>> "%~1" echo UwA1AHYAYgBtAE4AcwBhAFcATgByAFAAVwBOAHMAYgAzAE4AbABRADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBUAHMATgBDAGkAUQBvAEoAMgBOAHYAYgBtAFoAcABjAG0AMQBQAGEA
>> "%~1" echo eQBjAHAATABtADkAdQBZADIAeABwAFkAMgBzADkASwBDAGsAOQBQAG4AdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAdwBQAFgAQgBsAGIAbQBSAHAAYgBtAGQARABiADIANQBtAGEA
>> "%~1" echo WABKAHQATwAzAEIAbABiAG0AUgBwAGIAbQBkAEQAYgAyADUAbQBhAFgASgB0AFAA
>> "%~1" echo VwA1ADEAYgBHAHcANwBKAEMAZwBuAFkAMgA5AHUAWgBtAGwAeQBiAFUAMQBoAGMA
>> "%~1" echo MgBzAG4ASwBTADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIA
>> "%~1" echo MwBaAGwASwBDAGQAegBhAEcAOQAzAEoAeQBrADcAYQBXAFkAbwBJAFgAQQBwAGMA
>> "%~1" echo bQBWADAAZABYAEoAdQBPADIAbABtAEsASABBAHUAWQAzAFYAegBkAEcAOQB0AEoA
>> "%~1" echo aQBaAHcATABuAEoAbABjADIAOQBzAGQAbQBVAHAAZQAzAEEAdQBjAG0AVgB6AGIA
>> "%~1" echo MgB4ADIAWgBTAGgAMABjAG4AVgBsAEsAVAB0AHkAWgBYAFIAMQBjAG0ANQA5AGEA
>> "%~1" echo VwBZAG8AYwBDAGwAaABZADMAUgBwAGIAMgA0AG8AYwBDADUAaABZADMAUgBwAGIA
>> "%~1" echo MgA0AHMAYwBDADUAbABlAEgAUgB5AFkAUwB4AHcATABtAHgAaABZAG0AVgBzAEwA
>> "%~1" echo RwA1ADEAYgBHAHcAcwBkAEgASgAxAFoAUwBsADkATwB3ADAASwBKAEMAZwBuAGMA
>> "%~1" echo bQBWAG0AYwBtAFYAegBhAEUASgAwAGIAaQBjAHAATABtADkAdQBZADIAeABwAFkA
>> "%~1" echo MgBzADkASwBDAGsAOQBQAG4AdAB1AGIAMwBSAHAAWgBuAGsAbwBKACsAVwBJAHQA
>> "%~1" echo KwBhAFcAcwBPAGUASwB0AHUAYQBBAGcAUwBjAHMASgArAGEAdABvACsAVwBjAHEA
>> "%~1" echo TwBpAHYAdQArAFcAUABsAGkAQgBSAGQAVwBWAHoAZABDAEQAbgBpAHIAYgBtAGcA
>> "%~1" echo SQBFAHUATABpADQAbgBMAEMAZAAzAFkAWABKAHUASgB5AHcAeABOAGoAQQB3AEsA
>> "%~1" echo VAB0AHkAWgBXAFoAeQBaAFgATgBvAEsASABSAHkAZABXAFUAcABPADIAeAB2AFkA
>> "%~1" echo VwBSAE0AYgAyAGQAegBLAEcAWgBoAGIASABOAGwASwBYADAANwBEAFEAbwBrAEsA
>> "%~1" echo QwBkAHkAWgBXAFoAeQBaAFgATgBvAFQARwA5AG4AYwB5AGMAcABMAG0AOQB1AFkA
>> "%~1" echo MgB4AHAAWQAyAHMAOQBLAEMAawA5AFAAbQB4AHYAWQBXAFIATQBiADIAZAB6AEsA
>> "%~1" echo SABSAHkAZABXAFUAcABPAHcAMABLAEoAQwBnAG4AWgBYAGgAdwBiADMASgAwAFEA
>> "%~1" echo bgBSAHUASgB5AGsAdQBiADIANQBqAGIARwBsAGoAYQB6ADEAbABlAEgAQgB2AGMA
>> "%~1" echo bgBSAEkAZABHADEAcwBPAHcAMABLAEoAQwBnAG4AZABHAGgAbABiAFcAVgBDAGQA
>> "%~1" echo RwA0AG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcAcABQAFQANQA3AGIA
>> "%~1" echo RwA5AGoAWQBXAHgAVABkAEcAOQB5AFkAVwBkAGwATABuAE4AbABkAEUAbAAwAFoA
>> "%~1" echo VwAwAG8AZABHAGgAbABiAFcAVgBMAFoAWABrAHMAWgBHADkAagBkAFcAMQBsAGIA
>> "%~1" echo bgBRAHUAWQBtADkAawBlAFMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AFkA
>> "%~1" echo MgA5AHUAZABHAEYAcABiAG4ATQBvAEoAMgBSAGgAYwBtAHMAbgBLAFQAOABuAGIA
>> "%~1" echo RwBsAG4AYQBIAFEAbgBPAGkAZABrAFkAWABKAHIASgB5AGsANwBkAEcAaABsAGIA
>> "%~1" echo VwBVAG8ASwBUAHQAdQBiADMAUgBwAFoAbgBrAG8ASgArAFMANAB1ACsAbQBpAG0A
>> "%~1" echo TwBXADMAcwB1AFcASQBoACsAYQBOAG8AaQBjAHMAWgBHADkAagBkAFcAMQBsAGIA
>> "%~1" echo bgBRAHUAWQBtADkAawBlAFMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AFkA
>> "%~1" echo MgA5AHUAZABHAEYAcABiAG4ATQBvAEoAMgBSAGgAYwBtAHMAbgBLAFQAOABuADUA
>> "%~1" echo YgAyAFQANQBZAG0ATgA1AEwAaQA2ADUAcgBlAHgANgBJAG0AeQA1AHEAaQBoADUA
>> "%~1" echo YgB5AFAASgB6AG8AbgA1AGIAMgBUADUAWQBtAE4ANQBMAGkANgA1AHIAVwBGADYA
>> "%~1" echo SQBtAHkANQBxAGkAaAA1AGIAeQBQAEoAeQB3AG4AYgAyAHMAbgBLAFgAMAA3AEQA
>> "%~1" echo UQBvAGsASwBDAGQAagBkAFgATgAwAGIAMgAxAFQAWgBYAFEAbgBLAFMANQB2AGIA
>> "%~1" echo bQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAAVAA1AHoAYQBHADkAMwBRADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBTAGcAbgBZADMAVgB6AGQARwA5AHQAWAAzAE4AbABkAEgAUgBwAGIA
>> "%~1" echo bQBjAG4ATABDAGYAbABoAHAAbgBsAGgAYQBVAGcAYwAyAFYAMABkAEcAbAB1AFoA
>> "%~1" echo MwBNAG4ATABDAGMAbQBiAG4ATQA5AEoAeQB0AGwAYgBtAE4AdgBaAEcAVgBWAFUA
>> "%~1" echo awBsAEQAYgAyADEAdwBiADIANQBsAGIAbgBRAG8ASgBDAGcAbgBZADMAVgB6AGQA
>> "%~1" echo RwA5AHQAVABuAE0AbgBLAFMANQAyAFkAVwB4ADEAWgBTAGsAcgBKAHkAWgByAFoA
>> "%~1" echo WABrADkASgB5AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwARABiADIAMQB3AGIA
>> "%~1" echo MgA1AGwAYgBuAFEAbwBKAEMAZwBuAFkAMwBWAHoAZABHADkAdABTADIAVgA1AEoA
>> "%~1" echo eQBrAHUAZABtAEYAcwBkAFcAVQBwAEsAeQBjAG0AZABtAEYAcwBkAFcAVQA5AEoA
>> "%~1" echo eQB0AGwAYgBtAE4AdgBaAEcAVgBWAFUAawBsAEQAYgAyADEAdwBiADIANQBsAGIA
>> "%~1" echo bgBRAG8ASgBDAGcAbgBZADMAVgB6AGQARwA5AHQAVgBtAEYAcwBkAFcAVQBuAEsA
>> "%~1" echo UwA1ADIAWQBXAHgAMQBaAFMAawBwAE8AdwAwAEsASgBDAGcAbgBZADMAVgB6AGQA
>> "%~1" echo RwA5AHQAUQBuAEoAdgBZAFcAUgBqAFkAWABOADAASgB5AGsAdQBiADIANQBqAGIA
>> "%~1" echo RwBsAGoAYQB6ADAAbwBLAFQAMAArAGMAMgBoAHYAZAAwAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAwAG8ASgAyAE4AMQBjADMAUgB2AGIAVgA5AGkAYwBtADkAaABaAEcATgBoAGMA
>> "%~1" echo MwBRAG4ATABDAGYAbABqADUASABwAGcASQBIAGwAdQBiAC8AbQBrAHEAMABuAEwA
>> "%~1" echo QwBjAG0AYgBtAEYAdABaAFQAMABuAEsAMgBWAHUAWQAyADkAawBaAFYAVgBTAFMA
>> "%~1" echo VQBOAHYAYgBYAEIAdgBiAG0AVgB1AGQAQwBnAGsASwBDAGQAaQBjAG0AOQBoAFoA
>> "%~1" echo RwBOAGgAYwAzAFIATwBZAFcAMQBsAEoAeQBrAHUAZABtAEYAcwBkAFcAVQBwAEsA
>> "%~1" echo VABzAE4AQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAEoAdgBkAFgAUgBsAEsA
>> "%~1" echo QwBsADcAYgBHAFYAMABJAEcAbABrAFAAUwBoAHMAYgAyAE4AaABkAEcAbAB2AGIA
>> "%~1" echo aQA1AG8AWQBYAE4AbwBmAEgAdwBuAEkAMgA5ADIAWgBYAEoAMgBhAFcAVgAzAEoA
>> "%~1" echo eQBrAHUAYwAyAHgAcABZADIAVQBvAE0AUwBrADcAYQBXAFkAbwBhAFcAUQA5AFAA
>> "%~1" echo VAAwAG4AYQBXADUAegBkAEcARgBzAGIAQwBjAHAAYQBXAFEAOQBKADIARgB3AGMA
>> "%~1" echo SABNAG4ATwAyAGwAbQBLAEcAbABrAFAAVAAwADkASgAzAE4AbABkAEgAUgBwAGIA
>> "%~1" echo bQBkAHoASgB5AGwAcABaAEQAMABuAGEARwBWAGgAWgBIAE4AbABkAEMAYwA3AFoA
>> "%~1" echo RwA5AGoAZABXADEAbABiAG4AUQB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkA
>> "%~1" echo MwBSAHYAYwBrAEYAcwBiAEMAZwBuAEwAbgBCAGgAWgAyAFUAbgBLAFMANQBtAGIA
>> "%~1" echo MwBKAEYAWQBXAE4AbwBLAEgAQQA5AFAAbgBBAHUAWQAyAHgAaABjADMATgBNAGEA
>> "%~1" echo WABOADAATABuAFIAdgBaADIAZABzAFoAUwBnAG4AWQBXAE4AMABhAFgAWgBsAEoA
>> "%~1" echo eQB4AHcATABtAGwAawBQAFQAMAA5AGEAVwBRAHAASwBUAHQAawBiADIATgAxAGIA
>> "%~1" echo VwBWAHUAZABDADUAeABkAFcAVgB5AGUAVgBOAGwAYgBHAFYAagBkAEcAOQB5AFEA
>> "%~1" echo VwB4AHMASwBDAGMAdQBiAG0ARgAyAEkARwBFAG4ASwBTADUAbQBiADMASgBGAFkA
>> "%~1" echo VwBOAG8ASwBHAEUAOQBQAG0ARQB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwA
>> "%~1" echo bgBSAHYAWgAyAGQAcwBaAFMAZwBuAFkAVwBOADAAYQBYAFoAbABKAHkAeABoAEwA
>> "%~1" echo bQBkAGwAZABFAEYAMABkAEgASgBwAFkAbgBWADAAWgBTAGcAbgBhAEgASgBsAFoA
>> "%~1" echo aQBjAHAAUABUADAAOQBKAHkATQBuAEsAMgBsAGsASwBTAGsANwBZADIAOQB1AGMA
>> "%~1" echo MwBRAGcAYQAyAFYANQBQAFgAQgBoAFoAMgBWAHoAVwAyAGwAawBYAFgAeAA4AGMA
>> "%~1" echo RwBGAG4AWgBYAE0AdQBiADMAWgBsAGMAbgBaAHAAWgBYAGMANwBZADIAOQB1AGMA
>> "%~1" echo MwBRAGcAYgBUADEAMABLAEcAdABsAGUAUwBrADcAYwAyAFYAMABLAEMAZAB3AFkA
>> "%~1" echo VwBkAGwAVgBHAGwAMABiAEcAVQBuAEwARQBGAHkAYwBtAEYANQBMAG0AbAB6AFEA
>> "%~1" echo WABKAHkAWQBYAGsAbwBiAFMAawAvAGIAVgBzAHcAWABUAHAAdABLAFQAdAB6AFoA
>> "%~1" echo WABRAG8ASgAzAEIAaABaADIAVgBUAGQAVwBJAG4ATABFAEYAeQBjAG0ARgA1AEwA
>> "%~1" echo bQBsAHoAUQBYAEoAeQBZAFgAawBvAGIAUwBrAC8AYgBWAHMAeABYAFQAbwBuAEoA
>> "%~1" echo eQBrADcAYQBXAFkAbwBhAFcAUQA5AFAAVAAwAG4AYgBHADkAbgBjAHkAYwBwAGIA
>> "%~1" echo RwA5AGgAWgBFAHgAdgBaADMATQBvAFoAbQBGAHMAYwAyAFUAcABPADIAbABtAEsA
>> "%~1" echo RwBsAGsAUABUADAAOQBKADIARgB3AGMASABNAG4ASwBXAHgAdgBZAFcAUgBCAGMA
>> "%~1" echo SABCAHoASwBHAFoAaABiAEgATgBsAEsAVAB0AHAAWgBpAGgAcABaAEQAMAA5AFAA
>> "%~1" echo UwBkAG8AWgBXAEYAawBjADIAVgAwAEoAeQBsAHkAWgBXADUAawBaAFgASgBJAFoA
>> "%~1" echo VwBGAGsAYwAyAFYAMABLAEMAbAA5AEQAUQBwADAAYQBHAFYAdABaAFMAZwBwAE8A
>> "%~1" echo MgBGAHcAYwBHAHgANQBTAFQARQA0AGIAaQBnAHAATwAyAGwAdQBhAFgAUgBKAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBaAFgASQBvAEsAVABzAE4AQwBtAGwAbQBLAEMAUQBvAEoA
>> "%~1" echo MwBSAGgAWQBrAGwAdQBjADMAUgBoAGIARwB4AGwAWgBDAGMAcABLAFMAUQBvAEoA
>> "%~1" echo MwBSAGgAWQBrAGwAdQBjADMAUgBoAGIARwB4AGwAWgBDAGMAcABMAG0AOQB1AFkA
>> "%~1" echo MgB4AHAAWQAyAHMAOQBLAEMAawA5AFAAbgBOAGwAZABFAEYAdwBjAEYAUgBoAFkA
>> "%~1" echo aQBnAG4AYQBXADUAegBkAEcARgBzAGIARwBWAGsASgB5AGsANwBEAFEAcABwAFoA
>> "%~1" echo aQBnAGsASwBDAGQAMABZAFcASgBUAGEAVwBSAGwAYgBHADkAaABaAEMAYwBwAEsA
>> "%~1" echo UwBRAG8ASgAzAFIAaABZAGwATgBwAFoARwBWAHMAYgAyAEYAawBKAHkAawB1AGIA
>> "%~1" echo MgA1AGoAYgBHAGwAagBhAHoAMABvAEsAVAAwACsAYwAyAFYAMABRAFgAQgB3AFYA
>> "%~1" echo RwBGAGkASwBDAGQAegBhAFcAUgBsAGIARwA5AGgAWgBDAGMAcABPAHcAMABLAGEA
>> "%~1" echo VwBZAG8ASgBDAGcAbgBZAFgAQgB3AFIAbQBsAHMAZABHAFYAeQBKAHkAawBwAEoA
>> "%~1" echo QwBnAG4AWQBYAEIAdwBSAG0AbABzAGQARwBWAHkASgB5AGsAdQBiADIANQBwAGIA
>> "%~1" echo bgBCADEAZABEADEAeQBaAFcANQBrAFoAWABKAEIAYwBIAEIATQBhAFgATgAwAE8A
>> "%~1" echo dwAwAEsAVwB5AGQAegBZADIAOQB3AFoAVgBWAHoAWgBYAEkAbgBMAEMAZAB6AFkA
>> "%~1" echo MgA5AHcAWgBVAEYAcwBiAEMAYwBzAEoAMwBOAGoAYgAzAEIAbABVADMAbAB6AGQA
>> "%~1" echo RwBWAHQASgAxADAAdQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAcABaAEQAMAArAGUA
>> "%~1" echo MgBOAHYAYgBuAE4AMABJAEcAVgBzAFAAUwBRAG8AYQBXAFEAcABPADIAbABtAEsA
>> "%~1" echo QwBGAGwAYgBDAGwAeQBaAFgAUgAxAGMAbQA0ADcAWgBXAHcAdQBiADIANQBqAGIA
>> "%~1" echo RwBsAGoAYQB6ADAAbwBLAFQAMAArAGUAMgBGAHcAYwBGAE4AagBiADMAQgBsAFAA
>> "%~1" echo VwBsAGsAUABUADAAOQBKADMATgBqAGIAMwBCAGwAUQBXAHgAcwBKAHoAOABuAFkA
>> "%~1" echo VwB4AHMASgB6AG8AbwBhAFcAUQA5AFAAVAAwAG4AYwAyAE4AdgBjAEcAVgBUAGUA
>> "%~1" echo WABOADAAWgBXADAAbgBQAHkAZAB6AGUAWABOADAAWgBXADAAbgBPAGkAZAAxAGMA
>> "%~1" echo MgBWAHkASgB5AGsANwBiAEcAOQBoAFoARQBGAHcAYwBIAE0AbwBkAEgASgAxAFoA
>> "%~1" echo UwBsADkAZgBTAGsANwBEAFEAcABwAFoAaQBnAGsASwBDAGQAawBaAFgAUgBNAFkA
>> "%~1" echo WABWAHUAWQAyAGcAbgBLAFMAawBrAEsAQwBkAGsAWgBYAFIATQBZAFgAVgB1AFkA
>> "%~1" echo MgBnAG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcAcABQAFQANQBoAGMA
>> "%~1" echo SABCAFAAYwBDAGcAbgBiAEcARgAxAGIAbQBOAG8ASgB5AGsANwBEAFEAcABwAFoA
>> "%~1" echo aQBnAGsASwBDAGQAawBaAFgAUgBGAGUASABSAHkAWQBXAE4AMABKAHkAawBwAEoA
>> "%~1" echo QwBnAG4AWgBHAFYAMABSAFgAaAAwAGMAbQBGAGoAZABDAGMAcABMAG0AOQB1AFkA
>> "%~1" echo MgB4AHAAWQAyAHMAOQBLAEMAawA5AFAAbQBGAHcAYwBFADkAdwBLAEMAZABsAGUA
>> "%~1" echo SABSAHkAWQBXAE4AMABKAHkAawA3AEQAUQBwAHAAWgBpAGcAawBLAEMAZABrAFoA
>> "%~1" echo WABSAFQAZABHADkAdwBKAHkAawBwAEoAQwBnAG4AWgBHAFYAMABVADMAUgB2AGMA
>> "%~1" echo QwBjAHAATABtADkAdQBZADIAeABwAFkAMgBzADkASwBDAGsAOQBQAG0ARgB3AGMA
>> "%~1" echo RQA5AHcASwBDAGQAbQBiADMASgBqAFoAUwAxAHoAZABHADkAdwBKAHkAawA3AEQA
>> "%~1" echo UQBwAHAAWgBpAGcAawBLAEMAZABrAFoAWABSAEYAYgBtAEYAaQBiAEcAVQBuAEsA
>> "%~1" echo UwBrAGsASwBDAGQAawBaAFgAUgBGAGIAbQBGAGkAYgBHAFUAbgBLAFMANQB2AGIA
>> "%~1" echo bQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAAVAA1AGgAYwBIAEIAUABjAEMAZwBuAFoA
>> "%~1" echo VwA1AGgAWQBtAHgAbABKAHkAawA3AEQAUQBwAHAAWgBpAGcAawBLAEMAZABrAFoA
>> "%~1" echo WABSAEUAYQBYAE4AaABZAG0AeABsAEoAeQBrAHAASgBDAGcAbgBaAEcAVgAwAFIA
>> "%~1" echo RwBsAHoAWQBXAEoAcwBaAFMAYwBwAEwAbQA5AHUAWQAyAHgAcABZADIAcwA5AEsA
>> "%~1" echo QwBrADkAUABtAEYAdwBjAEUAOQB3AEsAQwBkAGsAYQBYAE4AaABZAG0AeABsAEoA
>> "%~1" echo eQBrADcARABRAHAAcABaAGkAZwBrAEsAQwBkAGsAWgBYAFIARABiAEcAVgBoAGMA
>> "%~1" echo aQBjAHAASwBTAFEAbwBKADIAUgBsAGQARQBOAHMAWgBXAEYAeQBKAHkAawB1AGIA
>> "%~1" echo MgA1AGoAYgBHAGwAagBhAHoAMABvAEsAVAAwACsAWQBYAEIAdwBUADMAQQBvAEoA
>> "%~1" echo MgBOAHMAWgBXAEYAeQBKAHkAawA3AEQAUQBwAHAAWgBpAGcAawBLAEMAZABrAFoA
>> "%~1" echo WABSAFYAYgBtAGwAdQBjADMAUgBoAGIARwB3AG4ASwBTAGsAawBLAEMAZABrAFoA
>> "%~1" echo WABSAFYAYgBtAGwAdQBjADMAUgBoAGIARwB3AG4ASwBTADUAdgBiAG0ATgBzAGEA
>> "%~1" echo VwBOAHIAUABTAGcAcABQAFQANQBoAGMASABCAFAAYwBDAGcAbgBkAFcANQBwAGIA
>> "%~1" echo bgBOADAAWQBXAHgAcwBKAHkAawA3AEQAUQBwAHAAWgBpAGcAawBLAEMAZABoAFoA
>> "%~1" echo RwBKAEUAYgAzAGQAdQBiAEcAOQBoAFoARQBKADAAYgBpAGMAcABLAFMAUQBvAEoA
>> "%~1" echo MgBGAGsAWQBrAFIAdgBkADIANQBzAGIAMgBGAGsAUQBuAFIAdQBKAHkAawB1AGIA
>> "%~1" echo MgA1AGoAYgBHAGwAagBhAHoAMQBrAGIAMwBkAHUAYgBHADkAaABaAEUARgBrAFkA
>> "%~1" echo agBzAE4AQwBtAGwAbQBLAEMAUQBvAEoAMgB4AGgAYgBtAGQAQwBkAEcANABuAEsA
>> "%~1" echo UwBrAGsASwBDAGQAcwBZAFcANQBuAFEAbgBSAHUASgB5AGsAdQBiADIANQBqAGIA
>> "%~1" echo RwBsAGoAYQB6ADAAbwBLAFQAMAArAGUAMAB4AEIAVABrAGMAOQBUAEUARgBPAFIA
>> "%~1" echo egAwADkAUABTAGQANgBhAEMAYwAvAEoAMgBWAHUASgB6AG8AbgBlAG0AZwBuAE8A
>> "%~1" echo MgB4AHYAWQAyAEYAcwBVADMAUgB2AGMAbQBGAG4AWgBTADUAegBaAFgAUgBKAGQA
>> "%~1" echo RwBWAHQASwBDAGQAeABkAFcAVgB6AGQARQBGAGsAWQBrAHgAaABiAG0AYwBuAEwA
>> "%~1" echo RQB4AEIAVABrAGMAcABPADIARgB3AGMARwB4ADUAUwBUAEUANABiAGkAZwBwAE8A
>> "%~1" echo MwBKAHYAZABYAFIAbABLAEMAawA3AGMAbQBWAHUAWgBHAFYAeQBRAFgAQgB3AFQA
>> "%~1" echo RwBsAHoAZABDAGcAcABPADMASgBsAGIAbQBSAGwAYwBrAGgAbABZAFcAUgB6AFoA
>> "%~1" echo WABRAG8ASwBUAHQAdQBiADMAUgBwAFoAbgBrAG8ASgAwAHgAaABiAG0AZAAxAFkA
>> "%~1" echo VwBkAGwASgB5AHgATQBRAFUANQBIAEwAQwBkAHYAYQB5AGMAcABmAFQAcwBOAEMA
>> "%~1" echo bQBGAGsAWgBFAFYAMgBaAFcANQAwAFQARwBsAHoAZABHAFYAdQBaAFgASQBvAEoA
>> "%~1" echo MgBoAGgAYwAyAGgAagBhAEcARgB1AFoAMgBVAG4ATABIAEoAdgBkAFgAUgBsAEsA
>> "%~1" echo VAB0AHkAYgAzAFYAMABaAFMAZwBwAE8AMwBKAGwAWgBuAEoAbABjADIAZwBvAEsA
>> "%~1" echo VAB0AHMAYgAyAEYAawBUAEcAOQBuAGMAeQBoAG0AWQBXAHgAegBaAFMAawA3AGMA
>> "%~1" echo MgBWADAAUwBXADUAMABaAFgASgAyAFkAVwB3AG8ASwBDAGsAOQBQAG4ATgBsAGQA
>> "%~1" echo QwBnAG4AWQAyAHgAdgBZADIAdABVAFoAWABoADAASgB5AHgAdQBaAFgAYwBnAFIA
>> "%~1" echo RwBGADAAWgBTAGcAcABMAG4AUgB2AFQARwA5AGoAWQBXAHgAbABWAEcAbAB0AFoA
>> "%~1" echo VgBOADAAYwBtAGwAdQBaAHkAZwBwAEsAUwB3AHgATQBEAEEAdwBLAFQAdAB6AFoA
>> "%~1" echo WABSAEoAYgBuAFIAbABjAG4AWgBoAGIAQwBnAG8ASwBUADAAKwBjAG0AVgBtAGMA
>> "%~1" echo bQBWAHoAYQBDAGgAbQBZAFcAeAB6AFoAUwBrAHMATQBUAFUAdwBNAEQAQQBwAE8A
>> "%~1" echo dwAwAEsAUABDADkAegBZADMASgBwAGMASABRACsAUABDADkAaQBiADIAUgA1AFAA
>> "%~1" echo agB3AHYAYQBIAFIAdABiAEQANABOAEMAZwA9AD0AABNbAFsAVABPAEsARQBOAF0A
>> "%~1" echo XQAAEVsAWwBMAEEATgBHAF0AXQAABXoAaAAABWUAbgAAgS9wAGEAYwBrAGEAZwBl
>> "%~1" echo ADoALwBkAGEAdABhAC8AYQBwAHAALwB4AC8AYgBhAHMAZQAuAGEAcABrAD0AVgBp
>> "%~1" echo AHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAC4AQQBuAGQAcgBvAGkAZAAgACAAaQBu
>> "%~1" echo AHMAdABhAGwAbABlAHIAPQBjAG8AbQAuAG8AYwB1AGwAdQBzAC4AbwBjAG0AcwAK
>> "%~1" echo AHAAYQBjAGsAYQBnAGUAOgAvAGQAYQB0AGEALwBhAHAAcAAvAHkALwBiAGEAcwBl
>> "%~1" echo AC4AYQBwAGsAPQBvAHIAZwAuAHQAZQBsAGUAZwByAGEAbQAuAG0AZQBzAHMAZQBu
>> "%~1" echo AGcAZQByAC4AdwBlAGIAIAAgAGkAbgBzAHQAYQBsAGwAZQByAD0AbgB1AGwAbAAK
>> "%~1" echo AAAZcABtAGwAaQBzAHQALgBjAG8AdQBuAHQAABFwAG0AbABpAHMAdAAuADAAACVw
>> "%~1" echo AG0AbABpAHMAdAAuADAALgBpAG4AcwB0AGEAbABsAGUAcgAAH2MAbwBtAC4AbwBj
>> "%~1" echo AHUAbAB1AHMALgBvAGMAbQBzAAARcABtAGwAaQBzAHQALgAxAAA1bwByAGcALgB0
>> "%~1" echo AGUAbABlAGcAcgBhAG0ALgBtAGUAcwBzAGUAbgBnAGUAcgAuAHcAZQBiAAARdABp
>> "%~1" echo AHQAbABlAC4AdgBkAAAdVgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAACF5VAA
>> "%~1" echo YQBjAGsAYQBnAGUAcwA6AAoAIAAgAFAAYQBjAGsAYQBnAGUAIABbAFYAaQByAHQA
>> "%~1" echo dQBhAGwARABlAHMAawB0AG8AcAAuAEEAbgBkAHIAbwBpAGQAXQAgACgAYwAzADYA
>> "%~1" echo YQAzAGMANgApADoACgAgACAAIAAgAGEAcABwAEkAZAA9ADEAMAAxADcAMQAKACAA
>> "%~1" echo IAAgACAAYwBvAGQAZQBQAGEAdABoAD0ALwBkAGEAdABhAC8AYQBwAHAALwBWAGkA
>> "%~1" echo cgB0AHUAYQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBkAC0AeAAKACAA
>> "%~1" echo IAAgACAAcAByAGkAbQBhAHIAeQBDAHAAdQBBAGIAaQA9AGEAcgBtADYANAAtAHYA
>> "%~1" echo OABhAAoAIAAgACAAIAB2AGUAcgBzAGkAbwBuAEMAbwBkAGUAPQAxADAANwAwADMA
>> "%~1" echo IABtAGkAbgBTAGQAawA9ADIAOQAgAHQAYQByAGcAZQB0AFMAZABrAD0AMwAyAAoA
>> "%~1" echo IAAgACAAIAB2AGUAcgBzAGkAbwBuAE4AYQBtAGUAPQAxAC4AMwA0AC4AMgAyAC4A
>> "%~1" echo MAAKACAAIAAgACAAZgBsAGEAZwBzAD0AWwAgAEgAQQBTAF8AQwBPAEQARQAgAEEA
>> "%~1" echo TABMAE8AVwBfAEMATABFAEEAUgBfAFUAUwBFAFIAXwBEAEEAVABBACAAXQAKACAA
>> "%~1" echo IAAgACAAZABhAHQAYQBEAGkAcgA9AC8AZABhAHQAYQAvAHUAcwBlAHIALwAwAC8A
>> "%~1" echo VgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAC4AQQBuAGQAcgBvAGkAZAAKACAA
>> "%~1" echo IAAgACAAbABhAHMAdABVAHAAZABhAHQAZQBUAGkAbQBlAD0AMgAwADIANgAtADAA
>> "%~1" echo OAAtADIANgAgADAAOAA6ADIAMgA6ADAANwAKACAAIAAgACAAaQBuAHMAdABhAGwA
>> "%~1" echo bABlAHIAUABhAGMAawBhAGcAZQBOAGEAbQBlAD0AYwBvAG0ALgBvAGMAdQBsAHUA
>> "%~1" echo cwAuAG8AYwBtAHMACgAgACAAIAAgAHIAZQBxAHUAZQBzAHQAZQBkACAAcABlAHIA
>> "%~1" echo bQBpAHMAcwBpAG8AbgBzADoACgAgACAAIAAgACAAIABhAG4AZAByAG8AaQBkAC4A
>> "%~1" echo cABlAHIAbQBpAHMAcwBpAG8AbgAuAEkATgBUAEUAUgBOAEUAVAAKACAAIAAgACAA
>> "%~1" echo IAAgAGEAbgBkAHIAbwBpAGQALgBwAGUAcgBtAGkAcwBzAGkAbwBuAC4AUgBFAEMA
>> "%~1" echo TwBSAEQAXwBBAFUARABJAE8ACgAgACAAIAAgAFUAcwBlAHIAIAAwADoAIABjAGUA
>> "%~1" echo RABhAHQAYQBJAG4AbwBkAGUAPQAxACAAaQBuAHMAdABhAGwAbABlAGQAPQB0AHIA
>> "%~1" echo dQBlACAAaABpAGQAZABlAG4APQBmAGEAbABzAGUAIABzAHQAbwBwAHAAZQBkAD0A
>> "%~1" echo ZgBhAGwAcwBlACAAZQBuAGEAYgBsAGUAZAA9ADAACgAgACAAIAAgACAAIABmAGkA
>> "%~1" echo cgBzAHQASQBuAHMAdABhAGwAbABUAGkAbQBlAD0AMgAwADIANgAtADAANwAtADAA
>> "%~1" echo NQAgADEANgA6ADAANQA6ADEANAAKACAAIAAgACAAIAAgAHIAdQBuAHQAaQBtAGUA
>> "%~1" echo IABwAGUAcgBtAGkAcwBzAGkAbwBuAHMAOgAKACAAIAAgACAAIAAgACAAIABhAG4A
>> "%~1" echo ZAByAG8AaQBkAC4AcABlAHIAbQBpAHMAcwBpAG8AbgAuAFIARQBDAE8AUgBEAF8A
>> "%~1" echo QQBVAEQASQBPADoAIABnAHIAYQBuAHQAZQBkAD0AdAByAHUAZQAKACAAIAAgACAA
>> "%~1" echo IAAgACAAIABhAG4AZAByAG8AaQBkAC4AcABlAHIAbQBpAHMAcwBpAG8AbgAuAFAA
>> "%~1" echo TwBTAFQAXwBOAE8AVABJAEYASQBDAEEAVABJAE8ATgBTADoAIABnAHIAYQBuAHQA
>> "%~1" echo ZQBkAD0AZgBhAGwAcwBlAAoAARFkAHUAbQBwAC4AdgBlAHIAABMxAC4AMwA0AC4A
>> "%~1" echo MgAyAC4AMAAAE2QAdQBtAHAALgBjAG8AZABlAAALMQAwADcAMAAzAAARZAB1AG0A
>> "%~1" echo cAAuAG0AaQBuAAAFMgA5AAAXZAB1AG0AcAAuAHQAYQByAGcAZQB0AAAFMwAyAAAd
>> "%~1" echo ZAB1AG0AcAAuAGkAbgBzAHQAYQBsAGwAZQByAAARZAB1AG0AcAAuAGEAYgBpAAAT
>> "%~1" echo YQByAG0ANgA0AC0AdgA4AGEAARFkAHUAbQBwAC4AcgBlAHEAAA9kAHUAbQBwAC4A
>> "%~1" echo cgB0AAAjUgBFAEMATwBSAEQAXwBBAFUARABJAE8AOgB0AHIAdQBlAAAxUABPAFMA
>> "%~1" echo VABfAE4ATwBUAEkARgBJAEMAQQBUAEkATwBOAFMAOgBmAGEAbABzAGUAABVkAHUA
>> "%~1" echo bQBwAC4AZgBpAHIAcwB0AAAnMgAwADIANgAtADAANwAtADAANQAgADEANgA6ADAA
>> "%~1" echo NQA6ADEANAABDW8AYwB1AGwAdQBzAAAZIAAgAGkAbgBzAHQAYQBsAGwAZQByAD0A
>> "%~1" echo ABcgAGkAbgBzAHQAYQBsAGwAZQByAD0AACl2AGUAcgBzAGkAbwBuAE4AYQBtAGUA
>> "%~1" echo PQAoAFsAXgBcAHMAXQArACkAACN2AGUAcgBzAGkAbwBuAEMAbwBkAGUAPQAoAFwA
>> "%~1" echo ZAArACkAABltAGkAbgBTAGQAawA9ACgAXABkACsAKQAAH3QAYQByAGcAZQB0AFMA
>> "%~1" echo ZABrAD0AKABcAGQAKwApAAA7aQBuAHMAdABhAGwAbABlAHIAUABhAGMAawBhAGcA
>> "%~1" echo ZQBOAGEAbQBlAD0AKABbAF4AXABzAF0AKwApAAAXYQBwAHAASQBkAD0AKABcAGQA
>> "%~1" echo KwApAAAtcAByAGkAbQBhAHIAeQBDAHAAdQBBAGIAaQA9ACgAWwBeAFwAcwBdACsA
>> "%~1" echo KQAAI2MAbwBkAGUAUABhAHQAaAA9ACgAWwBeAFwAcwBdACsAKQAAIWQAYQB0AGEA
>> "%~1" echo RABpAHIAPQAoAFsAXgBcAHMAXQArACkAAGtsAGEAcwB0AFUAcABkAGEAdABlAFQA
>> "%~1" echo aQBtAGUAPQAoAFsAMAAtADkAXQB7ADQAfQAtAFsAMAAtADkAXQB7ADIAfQAtAFsA
>> "%~1" echo MAAtADkAXQB7ADIAfQAgAFsAMAAtADkAOgBdAHsAOAB9ACkAAW9mAGkAcgBzAHQA
>> "%~1" echo SQBuAHMAdABhAGwAbABUAGkAbQBlAD0AKABbADAALQA5AF0AewA0AH0ALQBbADAA
>> "%~1" echo LQA5AF0AewAyAH0ALQBbADAALQA5AF0AewAyAH0AIABbADAALQA5ADoAXQB7ADgA
>> "%~1" echo fQApAAElZgBsAGEAZwBzAD0AXABbACgAWwBeAFwAXQBdACoAKQBcAF0AABtlAG4A
>> "%~1" echo YQBiAGwAZQBkAD0AKABcAGQAKwApAAAZcwB0AG8AcABwAGUAZAA9AHQAcgB1AGUA
>> "%~1" echo AC1yAGUAcQB1AGUAcwB0AGUAZAAgAHAAZQByAG0AaQBzAHMAaQBvAG4AcwA6AAAp
>> "%~1" echo aQBuAHMAdABhAGwAbAAgAHAAZQByAG0AaQBzAHMAaQBvAG4AcwA6AAArZABlAGMA
>> "%~1" echo bABhAHIAZQBkACAAcABlAHIAbQBpAHMAcwBpAG8AbgBzADoAAAtVAHMAZQByACAA
>> "%~1" echo AClyAHUAbgB0AGkAbQBlACAAcABlAHIAbQBpAHMAcwBpAG8AbgBzADoAABFRAHUA
>> "%~1" echo ZQByAGkAZQBzADoAAA1EAGUAeABvAHAAdAAAF3AAZQByAG0AaQBzAHMAaQBvAG4A
>> "%~1" echo LgAAEWcAcgBhAG4AdABlAGQAPQAAGWcAcgBhAG4AdABlAGQAPQB0AHIAdQBlAAAL
>> "%~1" echo YwBsAGUAYQByAAAPZABpAHMAYQBiAGwAZQAADWUAbgBhAGIAbABlAAAVZgBvAHIA
>> "%~1" echo YwBlAC0AcwB0AG8AcAABDXIAZQB2AG8AawBlAAA3TgBvACAAYQB1AHQAaABvAHIA
>> "%~1" echo aQB6AGUAZAAgAFEAdQBlAHMAdAAgAG8AbgBsAGkAbgBlAC4AAAl1AHMAZQByAAAH
>> "%~1" echo YQBsAGwAADNwAG0AIABsAGkAcwB0ACAAcABhAGMAawBhAGcAZQBzACAALQBmACAA
>> "%~1" echo LQBpACAALQAzAAEzcABtACAAbABpAHMAdAAgAHAAYQBjAGsAYQBnAGUAcwAgAC0A
>> "%~1" echo ZgAgAC0AaQAgAC0AcwABJ3AAbQAgAGwAaQBzAHQAIABwAGEAYwBrAGEAZwBlAHMA
>> "%~1" echo IAAtADMAARl7ACIAcABhAGMAawBhAGcAZQAiADoAIgAAFyIALAAiAHQAaQB0AGwA
>> "%~1" echo ZQAiADoAIgAAFSIALAAiAHAAYQB0AGgAIgA6ACIAAB8iACwAIgBpAG4AcwB0AGEA
>> "%~1" echo bABsAGUAcgAiADoAIgAAFSIALAAiAHUAcwBlAHIAIgA6ACIAAAUiAH0AAAtjAG8A
>> "%~1" echo dQBuAHQAABFhAHAAcABzAEoAcwBvAG4AAA0FUw1UDU4IVNVsAjABK0kAbgB2AGEA
>> "%~1" echo bABpAGQAIABwAGEAYwBrAGEAZwBlACAAbgBhAG0AZQAuAAARcABtACAAcABhAHQA
>> "%~1" echo aAAgAAAFbABzAAAhXABzACgAXABkACsAKQBcAHMAKwBcAGQAewA0AH0ALQABJVwA
>> "%~1" echo cwAoAFwAZAArACkAXABzACsAWwBBAC0AWgBhAC0AegBdAAELdABpAHQAbABlAAAN
>> "%~1" echo bQBpAG4AUwBkAGsAABN0AGEAcgBnAGUAdABTAGQAawAAE2kAbgBzAHQAYQBsAGwA
>> "%~1" echo ZQByAAAHdQBpAGQAABFjAG8AZABlAFAAYQB0AGgAAA9hAHAAawBQAGEAdABoAAAP
>> "%~1" echo ZABhAHQAYQBEAGkAcgAAGWYAaQByAHMAdABJAG4AcwB0AGEAbABsAAAVbABhAHMA
>> "%~1" echo dABVAHAAZABhAHQAZQAAD2UAbgBhAGIAbABlAGQAAA9zAHQAbwBwAHAAZQBkAAAL
>> "%~1" echo ZgBsAGEAZwBzAAAbcgBlAHEAdQBlAHMAdABlAGQASgBzAG8AbgAAE3sAIgBuAGEA
>> "%~1" echo bQBlACIAOgAiAAAbIgAsACIAZwByAGEAbgB0AGUAZAAiADoAIgAAF3IAdQBuAHQA
>> "%~1" echo aQBtAGUASgBzAG8AbgAADWwAYQB1AG4AYwBoAAANbQBvAG4AawBlAHkAAAUtAHAA
>> "%~1" echo AQUtAGMAAUFhAG4AZAByAG8AaQBkAC4AaQBuAHQAZQBuAHQALgBjAGEAdABlAGcA
>> "%~1" echo bwByAHkALgBMAEEAVQBOAEMASABFAFIAAA3yXfeLQmwvVKhSIAABJUwAYQB1AG4A
>> "%~1" echo YwBoACAAcgBlAHEAdQBlAHMAdABlAGQAOgAgAAAFYQBtAAAN8l06X0yIXFBiayAA
>> "%~1" echo AR1GAG8AcgBjAGUALQBzAHQAbwBwAHAAZQBkACAAAQ9lAHgAdAByAGEAYwB0AAAV
>> "%~1" echo 6lP9gHhTfY8sewlOuWWUXih1AjABU08AbgBsAHkAIAB0AGgAaQByAGQALQBwAGEA
>> "%~1" echo cgB0AHkAIABhAHAAcABzACAAYwBhAG4AIABiAGUAIAB1AG4AaQBuAHMAdABhAGwA
>> "%~1" echo bABlAGQALgABCfJdeFN9jyAAARlVAG4AaQBuAHMAdABhAGwAbABlAGQAIAAAC3hT
>> "%~1" echo fY8xWSWNGv8BJVUAbgBpAG4AcwB0AGEAbABsACAAZgBhAGkAbABlAGQAOgAgAAAZ
>> "%~1" echo 6lP9gAVuZJYsewlOuWWUXih1cGVuYwIwAVNPAG4AbAB5ACAAdABoAGkAcgBkAC0A
>> "%~1" echo cABhAHIAdAB5ACAAYQBwAHAAIABkAGEAdABhACAAYwBhAG4AIABiAGUAIABjAGwA
>> "%~1" echo ZQBhAHIAZQBkAC4AAQVwAG0AAA3yXQVuZJZwZW5jIAABI0MAbABlAGEAcgBlAGQA
>> "%~1" echo IABkAGEAdABhACAAZgBvAHIAIAAAFepT/YCBeSh1LHsJTrlllF4odQIwAU1PAG4A
>> "%~1" echo bAB5ACAAdABoAGkAcgBkAC0AcABhAHIAdAB5ACAAYQBwAHAAcwAgAGMAYQBuACAA
>> "%~1" echo YgBlACAAZABpAHMAYQBiAGwAZQBkAC4AARlkAGkAcwBhAGIAbABlAC0AdQBzAGUA
>> "%~1" echo cgABDS0ALQB1AHMAZQByAAEJ8l2BeSh1IAABE0QAaQBzAGEAYgBsAGUAZAAgAAAJ
>> "%~1" echo 8l0vVCh1IAABEUUAbgBhAGIAbABlAGQAIAAAFXAAZQByAG0AaQBzAHMAaQBvAG4A
>> "%~1" echo AA9DZ1CWDVQNTghU1WwCMAExSQBuAHYAYQBsAGkAZAAgAHAAZQByAG0AaQBzAHMA
>> "%~1" echo aQBvAG4AIABuAGEAbQBlAC4AAAnyXaRkAJUgAAERUgBlAHYAbwBrAGUAZAAgAAAJ
>> "%~1" echo 8l2IY4hOIAABEUcAcgBhAG4AdABlAGQAIAAADypn5XeUXih1zWRcTwIwAS1VAG4A
>> "%~1" echo awBuAG8AdwBuACAAYQBwAHAAIABvAHAAZQByAGEAdABpAG8AbgAuAAAffmINTjBS
>> "%~1" echo 5YuUXih1hHYgAEEAUABLACAA742EXwIwATlDAG8AdQBsAGQAIABuAG8AdAAgAGYA
>> "%~1" echo aQBuAGQAIAB0AGgAZQAgAEEAUABLACAAcABhAHQAaAAuAAAbQQBQAEsAIADvjYRf
>> "%~1" echo BVMrVF6X1WxXWyZ7AjABS0EAUABLACAAcABhAHQAaAAgAGMAbwBuAHQAYQBpAG4A
>> "%~1" echo cwAgAGkAbABsAGUAZwBhAGwAIABjAGgAYQByAGEAYwB0AGUAcgBzAC4AABdhAHAA
>> "%~1" echo awAtAGUAeAB0AHIAYQBjAHQAAQdhAHAAawAACXAAdQBsAGwAAAvQY9ZTMVkljRr/
>> "%~1" echo ASFFAHgAdAByAGEAYwB0ACAAZgBhAGkAbABlAGQAOgAgAAAL8l3QY9ZTMFIgAAEb
>> "%~1" echo RQB4AHQAcgBhAGMAdABlAGQAIAB0AG8AIAAACWYAaQBsAGUAAAd1AHIAbAAAKS8A
>> "%~1" echo YQBwAGkALwBhAHAAcABzAC8AZgBpAGwAZQA/AG4AYQBtAGUAPQAADyYAdABvAGsA
>> "%~1" echo ZQBuAD0AABFiAGEAZAAgAG4AYQBtAGUAAA9tAGkAcwBzAGkAbgBnAACA50gAVABU
>> "%~1" echo AFAALwAxAC4AMQAgADIAMAAwACAATwBLAA0ACgBDAG8AbgB0AGUAbgB0AC0AVAB5
>> "%~1" echo AHAAZQA6ACAAYQBwAHAAbABpAGMAYQB0AGkAbwBuAC8AdgBuAGQALgBhAG4AZABy
>> "%~1" echo AG8AaQBkAC4AcABhAGMAawBhAGcAZQAtAGEAcgBjAGgAaQB2AGUADQAKAEMAbwBu
>> "%~1" echo AHQAZQBuAHQALQBEAGkAcwBwAG8AcwBpAHQAaQBvAG4AOgAgAGEAdAB0AGEAYwBo
>> "%~1" echo AG0AZQBuAHQAOwAgAGYAaQBsAGUAbgBhAG0AZQA9ACIAASciAA0ACgBDAG8AbgB0
>> "%~1" echo AGUAbgB0AC0ATABlAG4AZwB0AGgAOgAgAAEPewAiAGkAZAAiADoAIgAAESIALAAi
>> "%~1" echo AG4AcwAiADoAIgAAEyIALAAiAGsAZQB5ACIAOgAiAAAXIgAsACIAdgBhAGwAdQBl
>> "%~1" echo ACIAOgAiAAAZcwBlAHQAdABpAG4AZwBzAEoAcwBvAG4AACtxAHUAZQBzAHQALQBw
>> "%~1" echo AGwAYQB0AGYAbwByAG0ALQB0AG8AbwBsAHMALQABCS4AegBpAHAAAC1BAEQAQgAg
>> "%~1" echo AGQAbwB3AG4AbABvAGEAZAAgAHMAdABhAHIAdAAgAC0APgAgAAEVVQBzAGUAcgAt
>> "%~1" echo AEEAZwBlAG4AdAABJ1EAdQBlAHMAdAAtAEEARABCAC0ARABhAHMAaABiAG8AYQBy
>> "%~1" echo AGQAAYCVaAB0AHQAcABzADoALwAvAGQAbAAuAGcAbwBvAGcAbABlAC4AYwBvAG0A
>> "%~1" echo LwBhAG4AZAByAG8AaQBkAC8AcgBlAHAAbwBzAGkAdABvAHIAeQAvAHAAbABhAHQA
>> "%~1" echo ZgBvAHIAbQAtAHQAbwBvAGwAcwAtAGwAYQB0AGUAcwB0AC0AdwBpAG4AZABvAHcA
>> "%~1" echo cwAuAHoAaQBwAAEtcABsAGEAdABmAG8AcgBtAC0AdABvAG8AbABzAC8AYQBkAGIA
>> "%~1" echo LgBlAHgAZQABOXAAbABhAHQAZgBvAHIAbQAtAHQAbwBvAGwAcwAvAEEAZABiAFcA
>> "%~1" echo aQBuAEEAcABpAC4AZABsAGwAAT9wAGwAYQB0AGYAbwByAG0ALQB0AG8AbwBsAHMA
>> "%~1" echo LwBBAGQAYgBXAGkAbgBVAHMAYgBBAHAAaQAuAGQAbABsAAEjC059j4xbEGJGTypn
>> "%~1" echo fmIwUiAAYQBkAGIALgBlAHgAZQACMAFVRABvAHcAbgBsAG8AYQBkACAAZgBpAG4A
>> "%~1" echo aQBzAGgAZQBkACAAYgB1AHQAIABhAGQAYgAuAGUAeABlACAAdwBhAHMAIABtAGkA
>> "%~1" echo cwBzAGkAbgBnAC4AABHyXYlbxYggAEEARABCABr/AR9BAEQAQgAgAGkAbgBzAHQA
>> "%~1" echo YQBsAGwAZQBkADoAIAAAFQtOfY8gAEEARABCACAAMVkljRr/AStBAEQAQgAgAGQA
>> "%~1" echo bwB3AG4AbABvAGEAZAAgAGYAYQBpAGwAZQBkADoAIAAAP2cAbABvAGIAYQBsAC4A
>> "%~1" echo cwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4A
>> "%~1" echo ADNzAHkAcwB0AGUAbQAuAHMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8A
>> "%~1" echo dQB0AAApcwBlAGMAdQByAGUALgBzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0AAAx
>> "%~1" echo ZwBsAG8AYgBhAGwALgB3AGkAZgBpAF8AcwBsAGUAZQBwAF8AcABvAGwAaQBjAHkA
>> "%~1" echo ADFzAHkAcwB0AGUAbQAuAHMAYwByAGUAZQBuAF8AYgByAGkAZwBoAHQAbgBlAHMA
>> "%~1" echo cwAAI3MAeQBzAHQAZQBtAC4AZgBvAG4AdABfAHMAYwBhAGwAZQAAPXMAeQBzAHQA
>> "%~1" echo ZQBtAC4AaABhAHAAdABpAGMAXwBmAGUAZQBkAGIAYQBjAGsAXwBlAG4AYQBiAGwA
>> "%~1" echo ZQBkAABTcwBlAGMAdQByAGUALgBoAG8AcgBpAHoAbwBuAG8AcwA6AHcAbwByAGwA
>> "%~1" echo ZABfAG0AbwB2AGUAbQBlAG4AdABfAHQAdQByAG4AXwB0AHkAcABlAABfcwBlAGMA
>> "%~1" echo dQByAGUALgBoAG8AcgBpAHoAbwBuAG8AcwA6AHcAbwByAGwAZABfAG0AbwB2AGUA
>> "%~1" echo bQBlAG4AdABfAHMAbgBhAHAAXwB0AHUAcgBuAF8AYQBuAGcAbABlAABzcwBlAGMA
>> "%~1" echo dQByAGUALgBoAG8AcgBpAHoAbwBuAG8AcwA6AHcAbwByAGwAZABfAG0AbwB2AGUA
>> "%~1" echo bQBlAG4AdABfAG4AYQByAHIAbwB3AF8AdgBpAHMAaQBvAG4AXwBmAG8AcgBfAGMA
>> "%~1" echo bwBtAGYAbwByAHQAAAAAAD37FJ3KYWFMmT2ShljpIasACLd6XFYZNOCJAgYKCAAA
>> "%~1" echo AAABAAAAAgYOAgYIAgYcAwYSCQUAAQEdDgMAAAgIAAEBFRINAQ4LAAQBFRINAQ4O
>> "%~1" echo Dg4MAAQBFRINAQ4ODh0OCQACARUSDQEFCAUAAR0FDggABB0FDg4IDgoAAwEVEg0B
>> "%~1" echo BQgIBwACHQUOHQUFAAEBEhEIAAICEhUQHQUIAAQKEhUKDgoGAAIBEhUKCAAAFRIZ
>> "%~1" echo Ag4OCgACFRIZAg4ODg4FAAIODg4GAAIBEhUOBgACCB0FCAYAAgodBQgFAAESGA4J
>> "%~1" echo AAQBEh0KHQUIBwACHQUSHQ4HAAIBHQUSGAsABQEdBQgIHQ4SGAoABQ4dBQgIHQ4O
>> "%~1" echo BgACDh0OCAcAAh0OHQUIBgACDh0FCAcGFRIZAg4OBAABAQgMAAMVEhkCDg4SFQ4K
>> "%~1" echo CQABFRIZAg4ODgUAAQESFQwAAwESFQ4VEhkCDg4IAAQBEhUODggIAAQBEhUCDg4F
>> "%~1" echo AAIODgIEAAECDgQAAQ4OBAABDgoEAAEBDgMAAA4HAAIOEA4QDgYAAw4ODg4GAAMO
>> "%~1" echo DggOBgACDggdDggABAESIQ4ODgoAAgEVEhkCDg4OBgACEhQODgkABQESFA4OCA4K
>> "%~1" echo AAUBEhQOCAIdDgcAAhIQEhQOBQABARIUBgACDhIUAg8ABQESIQ4VEhkCDg4CHQ4I
>> "%~1" echo AAMBEiESFAIHAAMODh0OCAgAAxIMDh0OCA0ABBIMDh0OCBUSJQEOBQABDh0OBAAB
>> "%~1" echo CA4FAAIIDg4KAAIOFRIZAg4ODgYAAg4OEhQFAAEdDg4LAAIBEhUVEhkCDg4IAAMB
>> "%~1" echo EhUOHQUJAAEOFRIZAg4OCgACFRINARIcDgIGAAISIA4OCAABDhUSDQEOBQACAg4O
>> "%~1" echo AwYdDgMgAAECBgIDIAAOAygADgcGFRINARIQBgYVEg0BDgQBAAAABCABAQgEAAEB
>> "%~1" echo HAMGEj0EBwESRQQAABIJBQABARIJBAAAElUFAAESWQ4GIAIBElkIBAAAEWEFAAEO
>> "%~1" echo HRwGAAMOHBwcBiACAg4RaQUAARJtDgQgABIRBSACARwYBgACAhI9HBEHChJdCA4O
>> "%~1" echo DhIREkUCHRwdDgUVEg0BDgMgAAgIIAAVEXUBEwAFFRF1AQ4EIAATAAQAABJ5BCAB
>> "%~1" echo AQ4DIAACEwcIFRINAQ4ODg4IHQ4CFRF1AQ4GFRIZAg4OByACARMAEwELIAAVEYCB
>> "%~1" echo AhMAEwEHFRGAgQIODgsgABURgIUCEwATAQcVEYCFAg4OBCAAEwEZBwYVEhkCDg4V
>> "%~1" echo EYCFAg4ODg4VEYCBAg4OAgUgARMACAUgAB0TAAYAAg4OHQ4FIAEBEwAFAAARgI0E
>> "%~1" echo IAEODgYAAgEOHQUPBwcdBRIYDhIYEkUCEYCNBQcCAh0OBiACCA4RaQkHBQ4dDggC
>> "%~1" echo HQ4FFRINAQUFIAEdBQ4KIAEBFRKAmQETAA4HBh0FFRINAQUICB0FAgYVEg0BHQUF
>> "%~1" echo FRINAQgvBxAdDhUSDQEdBRUSDQEICAgdBQgIFRINAQUVEg0BBRUSDQEFCBUSDQEF
>> "%~1" echo HQUdDgIDBwEIDQcFHQUVEg0BBQgIHQUFIAASgJ0FIAEOHQUJIAIdDh0OEYChBiAB
>> "%~1" echo HQ4dAwQgAQgDBSACDggIBCABDggGAAICDhAKIwcYEhUdBQ4dDh0ODg4KDg4IDggO
>> "%~1" echo DhKArQ4CDg4SEQIdDh0DByADCB0FCAgPBwgVEg0BBR0FCAgIBQICCiADAQ4RgLUR
>> "%~1" echo gLkFAAIKCgoHIAMBHQUICAwHCAoKHQUSHQgICgIIBwUKHQUICAIFAAIOHBwGIAET
>> "%~1" echo ARMAFwcJFRIZAg4ODg4ODhUSGQIODgIdDh0DBwAEDg4ODg4FIAECEwAYBwoVEhkC
>> "%~1" echo Dg4ODg4ODhJFFRIZAg4OAh0ODgcCFRIZAg4OFRIZAg4OBQAAEYDFBgABEoDNDgcA
>> "%~1" echo AwEODhIJCwACEYDREYDFEYDFAyAADQUAABKA1QYgAQ4SgNkGFRINARIQKgcVFRIZ
>> "%~1" echo Ag4OEYDFDg4ODhIUDg4ODg4OEYDREkUVEhkCDg4CHQMRgMUKCAUHAg4dDgIGAwUg
>> "%~1" echo Ag4DAwgHBQ4ODhJFAgMHAQoNBwYSGBIdHQUSRRIYAgcgAgoKEYDdBQcDCAgCAyAA
>> "%~1" echo CgcgAw4dBQgIBSABAR0FCCACARIVEYDtBCAAHQUsBx4KCB0FCAgICgodBQgICAoI
>> "%~1" echo CAgKDh0FCAgKHQUSgOUSgOkSgOUdBQgdBQISBwsdDggVEg0BDggKCA4ICA4CCgcI
>> "%~1" echo CAgIDggKCAIKBwgICAgICAoOAgQHAg4CEAcMCAoKAh0OCAgICggdDgIGBwQICA4C
>> "%~1" echo BQAAEoDxCiABARUSgPUBEwAFAAIBDgIKBwQOFRINAQ4IAgYAAgEcEAIoBxUVEhkC
>> "%~1" echo Dg4ODg4ODgodBRIdCBIYDg4CEkUVEhkCDg4CEYDFHAgdDgggAgITABATAQUgARIh
>> "%~1" echo Di8HGBUSGQIODg4ODgICAgIOEiESDBUSDQEOEgwOAhIMDgISRRUSGQIODhwCHRwd
>> "%~1" echo DgUHAg4dBQYHAhIhHQUIBwEVEhkCDg4DBhIVAwYSJAMGEigDBwECBRUSJQEOLwcY
>> "%~1" echo Dg4OAgICAg4SDBUSDQEOEgwCEgwSLAISKBJFFRIlAQ4VEiUBDhIkHAIdHB0ODgcL
>> "%~1" echo Dg4OCA4IDg4CHQ4IBgcEDg4OAgQgAQMIBAABAgMHBwUDAgIOCAUgARIhAwoHBxIh
>> "%~1" echo Aw4OAg4IByACDg4SgNkHBwUNDQ0OAgoHBw4ODg4dDggCBwcEDg4OHQMFIAEOHQMJ
>> "%~1" echo BwQOHQMCEYDFCAcEAhwRgMUCDAcIHQUICA4IEkUOAgkgAh0OHQMRgKEWBxAODg4O
>> "%~1" echo Dg4ODh0OAg4dDh0OCAIdAwMHAQ4EBwIODgkHBRIMDg4CHRwJBwQOEiECEYDFBwAC
>> "%~1" echo HQ4OEgkHIAIdDh0DCA8HCQ4ODh0OAh0OCB0DHQ4FIAIODg4FBwMODg4MAAQCDhGB
>> "%~1" echo ARKA2RANBwcFDg4NAg0RBwoOFRINAQ4ODg4ODh0OCAISBwwODg4dDg4ODh0OCAId
>> "%~1" echo Ax0ODgcIDg4ODg4OFRINAQ4CCwcEEhQSFBGAxR0OBAcBHQ4FAAASgQUKBwQSgQUS
>> "%~1" echo DBIQAgYVEXUBEhANBwQSEBIQFRF1ARIQAhkHEhUSGQIODg4ODg4ODg4ODg4ODg4N
>> "%~1" echo Ag0IFAcJFRIZAg4ODg4ODhIhDhGAxR0OEQcLDh0ODg4ODh0OCB0DAh0ODgcFEhAO
>> "%~1" echo FRF1ARIQAh0OBCABCA4NBwoODg4IDggOAh0OCAMGEgwDBhIwAwYSbQUgABKBCQQg
>> "%~1" echo AQECBwABEm0SgREGIAEBEoEVBCABAggUBwgSgRESgMESgMESNBJFEjASDAIGBhUS
>> "%~1" echo JQEOAwYSOAYHBA4CAhwYBwsSDBKBERKAwRKAwRI8EkUCEjgSDAIcBwcEEiEIDgID
>> "%~1" echo BhFECQACARKBIRGBJQUgAQgdAwQgAQIOCQcGDg4OHQ4IAgwHCQ4OCA4IDh0OCAII
>> "%~1" echo BwYOCA4IDgIKBwcODggOHQ4IAg8HCg4OHQ4NDh0OCAIdAw0MBwgODg4OHQ4IAh0D
>> "%~1" echo ByADCA4IEWkKAAMSgS0ODhGBMQUgABKBOQYgARKBNQgGBwISgS0OBQACAhwcCQcE
>> "%~1" echo EoEtDgIdAwYHBA4IDgIPBwkODh0ODh0OCAIdAx0OBgcECA4OAg8HCQ4ODg4OFRIN
>> "%~1" echo AQ4OCAIMBwYODg4VEg0BDg4CDgcIDg4ODg4VEg0BDg4CEAcJCA4ICAgVEg0BDg4C
>> "%~1" echo HRwFBwMODgIJBwYIDggdDggCCgADEoFBDg4RgTEGAAEOEoEtBAYSgUkIAAMODg4S
>> "%~1" echo gUkJAAQODg4OEYExBgcCHQ4dAw0HCQ4IDg4OAh0DHQ4IBwcDDh0FHRwVBwYSIQIV
>> "%~1" echo EYCFAg4ODhURgIECDg4CCgcHEiEDDg4IAggGFRINARIcDwcGDhUSDQESHA4SIAgd
>> "%~1" echo DgQAAQMDCwcHHQ4IDg4OAh0DBSACCAMIGwcNFRINARIcDg4ODggICBIcFRINARIc
>> "%~1" echo HQ4IAhYHERIgDggODgICDg4OCAIOEiACHQ4IBhURdQESHAYVEhkCDgIKIAEBFRKB
>> "%~1" echo UQETADQHERUSGQIODg4ODg4CFRINARIcEhwVEg0BEhwVEhkCDgISHBIhCBUSGQIO
>> "%~1" echo DgIVEXUBEhwIBwACEoEtDg4oBxYVEhkCDg4ODhIgDg4ODhKBLQoCEiEIDggODhUS
>> "%~1" echo GQIODgIdDggdDgkHBg4OAh0OCAIVBwsODg4CDhIMDhJFFRIZAg4OAh0ODwcDFRIZ
>> "%~1" echo Ag4OFRIZAg4OAiEHEQ4ODg4ODhIgDg4OEgwVEhkCDg4VEhkCDg4dDggCHQ4FAAES
>> "%~1" echo HQ4SBwoODhKBVQ4dBRIdHQUIAh0cGAcLFRIZAg4ODhIhCA4IDg4OFRIZAg4OAgYA
>> "%~1" echo AQERgV0FIAASgWUFIAIBDg4qBxMODg4SgWEdDhIdDh0FDg4VEhkCDg4SRRUSGQIO
>> "%~1" echo DhGAjR0DAh0OHQ4IAwAAAQcHAhGAjR0OCAEACAAAAAAAHgEAAQBUAhZXcmFwTm9u
>> "%~1" echo RXhjZXB0aW9uVGhyb3dzATj4BAAAAAAAAAAAAE74BAAAIAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAABA+AQAAAAAAAAAX0NvckV4ZU1haW4AbXNjb3JlZS5kbGwAAAAAAP8l
>> "%~1" echo ACBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIA
>> "%~1" echo EAAAACAAAIAYAAAAOAAAgAAAAAAAAAAAAAAAAAAAAQABAAAAUAAAgAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAQABAAAAaAAAgAAAAAAAAAAAAAAAAAAAAQAAAAAAgAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAQAAAAAAkAAAAKAABQBcAgAAAAAAAAAAAAAAAwUA6gEAAAAAAAAAAAAA
>> "%~1" echo XAI0AAAAVgBTAF8AVgBFAFIAUwBJAE8ATgBfAEkATgBGAE8AAAAAAL0E7/4AAAEA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAD8AAAAAAAAABAAAAAEAAAAAAAAAAAAAAAAAAABEAAAA
>> "%~1" echo AQBWAGEAcgBGAGkAbABlAEkAbgBmAG8AAAAAACQABAAAAFQAcgBhAG4AcwBsAGEA
>> "%~1" echo dABpAG8AbgAAAAAAAACwBLwBAAABAFMAdAByAGkAbgBnAEYAaQBsAGUASQBuAGYA
>> "%~1" echo bwAAAJgBAAABADAAMAAwADAAMAA0AGIAMAAAACwAAgABAEYAaQBsAGUARABlAHMA
>> "%~1" echo YwByAGkAcAB0AGkAbwBuAAAAAAAgAAAAMAAIAAEARgBpAGwAZQBWAGUAcgBzAGkA
>> "%~1" echo bwBuAAAAAAAwAC4AMAAuADAALgAwAAAARAASAAEASQBuAHQAZQByAG4AYQBsAE4A
>> "%~1" echo YQBtAGUAAABRAHUAZQBzAHQAQQBkAGIAVwBlAGIAVQBpAC4AZQB4AGUAAAAoAAIA
>> "%~1" echo AQBMAGUAZwBhAGwAQwBvAHAAeQByAGkAZwBoAHQAAAAgAAAATAASAAEATwByAGkA
>> "%~1" echo ZwBpAG4AYQBsAEYAaQBsAGUAbgBhAG0AZQAAAFEAdQBlAHMAdABBAGQAYgBXAGUA
>> "%~1" echo YgBVAGkALgBlAHgAZQAAADQACAABAFAAcgBvAGQAdQBjAHQAVgBlAHIAcwBpAG8A
>> "%~1" echo bgAAADAALgAwAC4AMAAuADAAAAA4AAgAAQBBAHMAcwBlAG0AYgBsAHkAIABWAGUA
>> "%~1" echo cgBzAGkAbwBuAAAAMAAuADAALgAwAC4AMAAAAAAAAADvu788P3htbCB2ZXJzaW9u
>> "%~1" echo PSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+DQo8YXNz
>> "%~1" echo ZW1ibHkgeG1sbnM9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206YXNtLnYxIiBt
>> "%~1" echo YW5pZmVzdFZlcnNpb249IjEuMCI+DQogIDxhc3NlbWJseUlkZW50aXR5IHZlcnNp
>> "%~1" echo b249IjEuMC4wLjAiIG5hbWU9Ik15QXBwbGljYXRpb24uYXBwIi8+DQogIDx0cnVz
>> "%~1" echo dEluZm8geG1sbnM9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206YXNtLnYyIj4N
>> "%~1" echo CiAgICA8c2VjdXJpdHk+DQogICAgICA8cmVxdWVzdGVkUHJpdmlsZWdlcyB4bWxu
>> "%~1" echo cz0idXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTphc20udjMiPg0KICAgICAgICA8
>> "%~1" echo cmVxdWVzdGVkRXhlY3V0aW9uTGV2ZWwgbGV2ZWw9ImFzSW52b2tlciIgdWlBY2Nl
>> "%~1" echo c3M9ImZhbHNlIi8+DQogICAgICA8L3JlcXVlc3RlZFByaXZpbGVnZXM+DQogICAg
>> "%~1" echo PC9zZWN1cml0eT4NCiAgPC90cnVzdEluZm8+DQo8L2Fzc2VtYmx5Pg0KAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8AQADAAAAGA4AAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAA==
>> "%~1" echo -----END CERTIFICATE-----
exit /b 0
