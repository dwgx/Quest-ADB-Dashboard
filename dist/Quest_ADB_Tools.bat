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
set "WEBUI_EXE_SHA256=0fb605a0d69bfc4ac03d8b71c372917d365a7614d930cabc29d3418ca7dfc25b"

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

:need_adb
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
call :need_adb
if errorlevel 1 exit /b 1
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
>> "%~1" echo dCBiZSBydW4gaW4gRE9TIG1vZGUuDQ0KJAAAAAAAAABQRQAATAEDAEC4SGoAAAAA
>> "%~1" echo AAAAAOAAAgELAQsAAJoDAAAIAAAAAAAAfrkDAAAgAAAAwAMAAABAAAAgAAAAAgAA
>> "%~1" echo BAAAAAAAAAAEAAAAAAAAAAAABAAAAgAAAAAAAAMAQIUAABAAABAAAAAAEAAAEAAA
>> "%~1" echo AAAAABAAAAAAAAAAAAAAACi5AwBTAAAAAMADAPAEAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AOADAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAIAAACAAAAAAAAAAAAAAACCAAAEgAAAAAAAAAAAAAAC50ZXh0AAAA
>> "%~1" echo hJkDAAAgAAAAmgMAAAIAAAAAAAAAAAAAAAAAACAAAGAucnNyYwAAAPAEAAAAwAMA
>> "%~1" echo AAYAAACcAwAAAAAAAAAAAAAAAABAAABALnJlbG9jAAAMAAAAAOADAAACAAAAogMA
>> "%~1" echo AAAAAAAAAAAAAAAAQAAAQgAAAAAAAAAAAAAAAAAAAABguQMAAAAAAEgAAAACAAUA
>> "%~1" echo QLMAAOgFAwABAAAAAQAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAABswAgBEAAAAAQAAEQAAAnQEAAABKAUAAAYAAN4xCgAA
>> "%~1" echo AnQEAAABbwYAAAoAAN4FJgAA3gAAcgEAAHAGbwcAAAooCAAACiguAAAGAADeAAAq
>> "%~1" echo ARwAAAAAEwAQIwAFAQAAAQAAAQAQEQAxEAAAARswBACeAgAAAgAAEQAAKAkAAAoo
>> "%~1" echo CgAACgAA3gUmAADeAAACjmkWMRICFppyEQAAcCgLAAAKFv4BKwEXABMHEQctEQAo
>> "%~1" echo AgAABigMAAAKADhWAgAAAo5pFv4CFv4BEwcRBy0IAhaagAIAAAQCjmkXMAwoDQAA
>> "%~1" echo Cm8OAAAKKwMCF5oAKC0AAAYAFAogPSIAAAsrLwAAcikAAHAoDwAACgdzEAAACgoG
>> "%~1" echo bxEAAAoAB4AEAAAE3h4mABQKAN4AAAAHF1gLByBRIgAA/gIW/gETBxEHLcAABhT+
>> "%~1" echo ARb+ARMHEQctIgByPQAAcCgSAAAKAHKLAABwKC4AAAYAKBMAAAomOKkBAAAajQEA
>> "%~1" echo AAETCBEIFnK5AABwohEIF34EAAAEjBgAAAGiEQgYct0AAHCiEQgZfgMAAASiEQgo
>> "%~1" echo FAAACgxy7wAAcAgoCAAACigSAAAKAHIdAQBwKBIAAAoAclsBAHB+AgAABCgIAAAK
>> "%~1" echo KBIAAAoAcmcBAHB+BwAABCgIAAAKKBIAAAoAcnEBAHB+BAAABIwYAAABcp8BAHAo
>> "%~1" echo FQAACiguAAAGAHJbAQBwfgIAAAQoCAAACiguAAAGAAAcjREAAAETCREJFnKjAQBw
>> "%~1" echo ohEJFxIDEgQoMAAABqIRCRhyswEAcKIRCRkJKHgAAAaiEQkacrMBAHCiEQkbEQSi
>> "%~1" echo EQkoFgAACiguAAAGAADeBSYAAN4AAHK3AQBwcrsBAHAoFwAAChtvGAAAChMHEQct
>> "%~1" echo EwAACCgZAAAKJgDeBSYAAN4AAAAragAABm8aAAAKEwV+DAAABC0TFP4GigAABnMb
>> "%~1" echo AAAKgAwAAAQrAH4MAAAEEQUoHAAACiYA3jQTBgBy8QEAcBEGbwcAAAooCAAACigS
>> "%~1" echo AAAKAHLxAQBwEQZvBwAACigIAAAKKC4AAAYAAN4AAAAXEwcrkSoAAAFAAAAAAAEA
>> "%~1" echo DxAABQEAAAEAAIUAIaYABwEAAAEAAKcBUfgBBQEAAAEAABoCCyUCBQEAAAEAAC8C
>> "%~1" echo M2ICNBAAAAEbMAYAhAEAAAMAABEAcx0AAAoKcgECAHALBnLsAwBwcgIEAHAHcuwD
>> "%~1" echo AHAoYAAABigDAAAGAAZyEAQAcHIkBABwB3IQBABwKGAAAAYoAwAABgAGcjIEAHBy
>> "%~1" echo RgQAcAdyMgQAcChgAAAGKAMAAAYABnJuBABwcoYEAHAHcm4EAHAoYAAABigDAAAG
>> "%~1" echo AAZyjgQAcHKkBABwB3KOBABwKGAAAAYoAwAABgAGcs4EAHAHKGwAAAYajREAAAET
>> "%~1" echo BREFFnICBABwohEFF3IkBABwohEFGHLsBABwohEFGXL8BABwohEFKAQAAAYAcjYF
>> "%~1" echo AHAMBnLZBQBwcvUFAHAIKGsAAAYZjREAAAETBREFFnL3BQBwohEFF3IHBgBwohEF
>> "%~1" echo GHIZBgBwohEFKAQAAAYABm8eAAAKFv4BFv4BEwYRBi0RAHIrBgBwKBIAAAoAFhME
>> "%~1" echo K0MABm8fAAAKEwcrFBIHKCAAAAoNKCEAAAoJbyIAAAoAEgcoIwAAChMGEQYt394P
>> "%~1" echo Egf+FgIAABtvJAAACgDcABcTBCsAEQQqARAAAAIARwElbAEPAAAAABMwBABIAAAA
>> "%~1" echo BAAAEQAFBCglAAAKFv4BCgYtOAIcjREAAAELBxYDogcXcmUGAHCiBxgEogcZcn8G
>> "%~1" echo AHCiBxoFogcbcpcGAHCiBygWAAAKbyYAAAoAKhMwBAB9AAAABQAAEQAABQsWDCtq
>> "%~1" echo BwiaCgAEJS0GJnL1BQBwBhtvJwAAChb+BBb+AQ0JLUUCHI0RAAABEwQRBBYDohEE
>> "%~1" echo F3KbBgBwohEEGAaiEQQZcrMGAHCiEQQaBCh4AAAGohEEG3KXBgBwohEEKBYAAApv
>> "%~1" echo JgAACgAACBdYDAgHjmn+BA0JLYwqAAAAGzAEAIkGAAAGAAARAAITEQACIMDUAQBv
>> "%~1" echo KAAACgACIMDUAQBvKQAACgACbyoAAAoKBhIBKAYAAAYTEhESLQXdUAYAACgrAAAK
>> "%~1" echo B28sAAAKDAgXjREAAAETExETFnLBBgBwohETFm8tAAAKDQmOaSwNCRaaKC4AAAoW
>> "%~1" echo /gErARYAExIREi0F3QoGAAAJFpoXjSEAAAETFBEUFh8gnREUby8AAAoTBBEEjmkY
>> "%~1" echo /gQW/gETEhESLQXd2wUAABEEFppvMAAAChMFEQQXmhMGFmoTB3L1BQBwEwgXEwk4
>> "%~1" echo pwAAAAAJEQmaEwoRCm8xAAAKFv4BFv4BExIREi0FOIIAAAARCh86bzIAAAoTCxEL
>> "%~1" echo Fv4EFv4BExIREi0CK2cRChYRC28zAAAKbzQAAApvNQAAChMMEQoRCxdYbzYAAApv
>> "%~1" echo NAAAChMNEQxyxwYAcCgLAAAKFv4BExIREi0OABENEgcoNwAACiYAKxsRDHLlBgBw
>> "%~1" echo KAsAAAoW/gETEhESLQYAEQ0TCAAAEQkXWBMJEQkJjmn+BBMSERI6Sf///3K5AABw
>> "%~1" echo fgQAAASMGAAAAREGKBUAAApzOAAAChMOEQh+AwAABCgLAAAKLR0RDm85AAAKcgEH
>> "%~1" echo AHAoggAABn4DAAAEKAsAAAorARcAEw8RDm86AAAKcg0HAHAoCwAAChb+ARMSERIt
>> "%~1" echo MQARDxMSERItFwAGciUHAHAogAAABiiEAAAGAN16BAAABigJAAAGKIQAAAYA3WkE
>> "%~1" echo AAARDm86AAAKcjcHAHAoCwAAChb+ARMSERI6wQAAAAARDxMSERItFwAGciUHAHAo
>> "%~1" echo gAAABiiEAAAGAN0sBAAAEQVyTwcAcCglAAAKFv4BExIREi0XAAZyWQcAcCiAAAAG
>> "%~1" echo KIQAAAYA3QAEAAARDm85AAAKcn0HAHAoggAABhMQERAofAAABiwgEQ5vOQAACnKL
>> "%~1" echo BwBwKIIAAAZymwcAcCglAAAKFv4BKwEXABMSERItFwAGcqMHAHAogAAABiiEAAAG
>> "%~1" echo AN2lAwAABhEQEQ5vOQAACigKAAAGKIQAAAYA3YsDAAARDm86AAAKcrsHAHAoCwAA
>> "%~1" echo Chb+ARMSERItMQARDxMSERItFwAGciUHAHAogAAABiiEAAAGAN1RAwAABigLAAAG
>> "%~1" echo KIQAAAYA3UADAAARDm86AAAKcs8HAHAoCwAAChb+ARMSERItXQARDxMSERItFwAG
>> "%~1" echo ciUHAHAogAAABiiEAAAGAN0GAwAAEQVyTwcAcCglAAAKFv4BExIREi0XAAZy5wcA
>> "%~1" echo cCiAAAAGKIQAAAYA3doCAAAGKAwAAAYohAAABgDdyQIAABEObzoAAApyBwgAcCgL
>> "%~1" echo AAAKFv4BExIREi15ABEPExIREi0gAAYRBygIAAAGAAZyJQcAcCiAAAAGKIQAAAYA
>> "%~1" echo 3YYCAAARBXJPBwBwKCUAAAoW/gETEhESLSAABhEHKAgAAAYABnInCABwKIAAAAYo
>> "%~1" echo hAAABgDdUQIAAAYGEQ5vOQAAChEHKBwAAAYohAAABgDdNgIAABEObzoAAApyRwgA
>> "%~1" echo cCgLAAAKFv4BExIREjqfAAAAABEPExIREi0XAAZyJQcAcCiAAAAGKIQAAAYA3fkB
>> "%~1" echo AAARBXJPBwBwKCUAAAoW/gETEhESLRcABnJpCABwKIAAAAYohAAABgDdzQEAABEO
>> "%~1" echo bzkAAApyiwcAcCiCAAAGcpsHAHAoJQAAChb+ARMSERItFwAGcokIAHAogAAABiiE
>> "%~1" echo AAAGAN2SAQAABhEObzkAAAooHQAABiiEAAAGAN16AQAAEQ5vOgAACnKnCABwKAsA
>> "%~1" echo AAoW/gETEhESOoQAAAAAEQ8TEhESLRcABnIlBwBwKIAAAAYohAAABgDdPQEAABEO
>> "%~1" echo bzkAAApyiwcAcCiCAAAGcpsHAHAoJQAAChb+ARMSERItFwAGcokIAHAogAAABiiE
>> "%~1" echo AAAGAN0CAQAAAAIgwCcJAG8pAAAKAADeBSYAAN4AAAYRDm85AAAKKCIAAAYA3dkA
>> "%~1" echo AAARDm86AAAKctcIAHAbbzsAAAoW/gETEhESLVMAEQ5vOQAACnIBBwBwKIIAAAZ+
>> "%~1" echo AwAABCglAAAKFv4BExIREi0eAAZy6wgAcCgJAAAKciUHAHBvPAAACiiFAAAGAN57
>> "%~1" echo BhEObzoAAAooDgAABgDeaxEObzoAAApyHwkAcCgLAAAKFv4BExIREi0eAAZyOQkA
>> "%~1" echo cCgJAAAKclUJAHBvPAAACiiFAAAGAN4zBnIKCwBwKAkAAAooiAAABm88AAAKKIUA
>> "%~1" echo AAYAAN4UEREU/gETEhESLQgREW8kAAAKANwAACoAAABBNAAAAAAAAIUFAAAQAAAA
>> "%~1" echo lQUAAAUAAAABAAABAgAAAAQAAABuBgAAcgYAABQAAAAAAAAAEzAEAMIAAAAHAAAR
>> "%~1" echo AAMUUSAACAAAcz0AAAoKF40kAAABCxYMIAAAAQANOIUAAAAAAgcWF28+AAAKEwQR
>> "%~1" echo BBb+AhMHEQctAit+BxaREwUGEQVvPwAACgARBR8N/gEW/gETBxEHLQwIGC4DFysB
>> "%~1" echo GQAMKycRBR8KMxEIFy4JCBn+ARb+ASsBFgArARcAEwcRBy0GCBdYDCsCFgwIGv4B
>> "%~1" echo Fv4BEwcRBy0OAAMGb0AAAApRFxMGKxgABm9BAAAKCf4EEwcRBzpp////FhMGKwAR
>> "%~1" echo BioAABswBAClAAAACAAAEQADChZqCyAAAAEAjSQAAAEMBBgYc0IAAAoNACteAAiO
>> "%~1" echo aWoGKEMAAAppEwQCCBYRBG8+AAAKEwURBRb+AhMHEQctAitCBxEFalgF/gIW/gET
>> "%~1" echo BxEHLQ4ACW9EAAAKABVqEwbePgkIFhEFb0UAAAoABxEFalgLBhEFalkKAAYWav4C
>> "%~1" echo EwcRBy2XAN4SCRT+ARMHEQctBwlvJAAACgDcAAcTBisAABEGKgAAAAEQAAACABoA
>> "%~1" echo b4kAEgAAAAAbMAQATwAAAAkAABEAAAMKIAAAAQCNJAAAAQsrKQAHjmlqBihDAAAK
>> "%~1" echo aQwCBxYIbz4AAAoNCRb+AhMEEQQtAisRBglqWQoABhZq/gITBBEELcwA3gUmAADe
>> "%~1" echo AAAqAAEQAAAAAAEAR0gABQEAAAETMAUAfgQAAAoAABEAKH8AAAYKBnI8CwBwckwL
>> "%~1" echo AHB+BAAABIwYAAABKEYAAApvRwAACgAGcmILAHB+AgAABG9HAAAKAAZycgsAcH4H
>> "%~1" echo AAAEb0cAAAoAEgESAigwAAAGDQZyggsAcAlvRwAACgAGcpoLAHAHKHgAAAZvRwAA
>> "%~1" echo CgAGcrALAHAIb0cAAAoABnK6CwBwCXLOCwBwKAsAAAotB3LcCwBwKwVy6AsAcABv
>> "%~1" echo RwAACgAJcs4LAHAoJQAAChb+ARMGEQYtTQAcjREAAAETBxEHFnLyCwBwohEHFwmi
>> "%~1" echo EQcYcrMBAHCiEQcZByh4AAAGohEHGnKzAQBwohEHGwiiEQcoFgAACiguAAAGAAYT
>> "%~1" echo BTh1AwAABxeNIQAAARMIEQgWHyCdEQhvLwAAChaaEwQGcv4LAHARBG9HAAAKAAZy
>> "%~1" echo DAwAcBEEchgMAHAoMQAABm9HAAAKAAZyOgwAcBEEckoMAHAoMQAABm9HAAAKAAZy
>> "%~1" echo fAwAcBEEcoQMAHAoMQAABm9HAAAKAAZyrgwAcBEEcsoMAHAoMQAABm9HAAAKAAZy
>> "%~1" echo Cg0AcBEEciQNAHAoMQAABm9HAAAKAAZyVA0AcBEEcmANAHAoMQAABm9HAAAKAAZy
>> "%~1" echo gg0AcBEEcpoNAHAoMQAABm9HAAAKAAZyug0AcBEEctYNAHAoMQAABm9HAAAKAAZy
>> "%~1" echo +g0AcBEEcgYOAHAoMQAABm9HAAAKAAZyKA4AcBEEcjAOAHAoMQAABhEEclgOAHAo
>> "%~1" echo MQAABihRAAAGb0cAAAoABnJyDgBwEQRygg4AcCgxAAAGb0cAAAoABnKqDgBwEQRy
>> "%~1" echo wg4AcCgxAAAGb0cAAAoABnLiDgBwEQRyBA8AcCgxAAAGb0cAAAoABnI+DwBwEQRy
>> "%~1" echo Vg8AcCgxAAAGb0cAAAoABnKUDwBwEQRynA8AcCgxAAAGb0cAAAoABnLCDwBwEQQo
>> "%~1" echo SwAABm9HAAAKAAZy0A8AcBEEcuYPAHBy9A8AcCgyAAAGb0cAAAoABnIMEABwEQRy
>> "%~1" echo 5g8AcHIcEABwKDIAAAZvRwAACgAGcj4QAHARBHLmDwBwckwQAHAoMgAABm9HAAAK
>> "%~1" echo AAZyfhAAcBEEcuYPAHBykhAAcCgyAAAGb0cAAAoABnK2EABwEQRyyhAAcHLYEABw
>> "%~1" echo KDIAAAZvRwAACgAGcv4QAHARBHIYEQBwciYRAHAoMgAABm9HAAAKAAZyQhEAcBEE
>> "%~1" echo cuYPAHByVBEAcCgyAAAGb0cAAAoABhEEKDsAAAYABhEEKDwAAAYABhEEKD0AAAYA
>> "%~1" echo BhEEKD4AAAYABhEEKD8AAAYABhEEKEAAAAYABhEEKEEAAAYABhEEKEIAAAYAHwyN
>> "%~1" echo EQAAARMHEQcWcmgRAHCiEQcXBnIMDABwb0gAAAqiEQcYcoIRAHCiEQcZBnKWEQBw
>> "%~1" echo b0gAAAqiEQcacrARAHCiEQcbBnLAEQBwb0gAAAqiEQccctgRAHCiEQcdBnLoEQBw
>> "%~1" echo b0gAAAqiEQcecgASAHCiEQcfCQZyPhAAcG9IAAAKohEHHwpyEhIAcKIRBx8LBnIM
>> "%~1" echo EABwb0gAAAqiEQcoFgAACiguAAAGAAYTBSsAEQUqAAAbMAUA+gcAAAsAABEAKH8A
>> "%~1" echo AAYKBnJ9BwBwAih4AAAGb0cAAAoAKCwAAAYLciYSAHACKHgAAAZyMhIAcAcoSQAA
>> "%~1" echo CiguAAAGAAACckQSAHAoCwAAChb+ARMIEQgtXwAgoA8AABeNEQAAARMJEQkWclwS
>> "%~1" echo AHCiEQkoNgAABiYgXgEAAChKAAAKACCgDwAAF40RAAABEwkRCRZydBIAcKIRCSg2
>> "%~1" echo AAAGJgZyjhIAcHKcEgBwb0cAAAoAADi4BgAAAAdyuhIAcCgLAAAKFv4BEwgRCC0L
>> "%~1" echo cr4SAHBzSwAACnoCcuASAHAoCwAAChb+ARMIEQgtOwAHKCsAAAYAIPoAAAAoSgAA
>> "%~1" echo CgAHIKwNAABy9hIAcCg1AAAGJgZyjhIAcHIwEwBwb0cAAAoAADhIBgAAAnJ6EwBw
>> "%~1" echo KAsAAAoW/gETCBEILR8ABygqAAAGAAZyjhIAcHKQEwBwb0cAAAoAADgVBgAAAnKi
>> "%~1" echo EwBwKAsAAAoW/gETCBEILR8ABygqAAAGAAZyjhIAcHK4EwBwb0cAAAoAADjiBQAA
>> "%~1" echo AnI4FABwKAsAAAoW/gETCBEILR8ABygrAAAGAAZyjhIAcHJUFABwb0cAAAoAADiv
>> "%~1" echo BQAAAnJ6FABwKAsAAAoW/gETCBEILR8ABygrAAAGAAZyjhIAcHKUFABwb0cAAAoA
>> "%~1" echo ADh8BQAAAnKoFABwKAsAAAoW/gETCBEILR8AByg5AAAGAAZyjhIAcHLGFABwb0cA
>> "%~1" echo AAoAADhJBQAAAnL2FABwKAsAAAoW/gETCBEILSkAByCsDQAAcgoVAHAoNQAABiYG
>> "%~1" echo co4SAHBychUAcG9HAAAKAAA4DAUAAAJykBUAcCgLAAAKFv4BEwgRCC0pAAcgrA0A
>> "%~1" echo AHKmFQBwKDUAAAYmBnKOEgBwchAWAHBvRwAACgAAOM8EAAACcjAWAHAoCwAAChb+
>> "%~1" echo ARMIEQgtTQAgiBMAABqNEQAAARMJEQkWckIWAHCiEQkXB6IRCRhySBYAcKIRCRly
>> "%~1" echo VBYAcKIRCSg2AAAGJgZyjhIAcHJeFgBwb0cAAAoAADhuBAAAAnKCFgBwKAsAAAoW
>> "%~1" echo /gETCBEILVUAByCsDQAAcpwWAHAoNQAABiYgiBMAABmNEQAAARMJEQkWckIWAHCi
>> "%~1" echo EQkXB6IRCRhy6hYAcKIRCSg2AAAGJgZyjhIAcHLyFgBwb0cAAAoAADgFBAAAAnJQ
>> "%~1" echo FwBwKAsAAAoW/gETCBEILSkAByCsDQAAcvYSAHAoNQAABiYGco4SAHByZBcAcG9H
>> "%~1" echo AAAKAAA4yAMAAAJyihcAcCgLAAAKFv4BEwgRCC0pAAcgrA0AAHKgFwBwKDUAAAYm
>> "%~1" echo BnKOEgBwctwXAHBvRwAACgAAOIsDAAACciAYAHAoCwAAChb+ARMIEQgtKQAHIKwN
>> "%~1" echo AAByNBgAcCg1AAAGJgZyjhIAcHKQGABwb0cAAAoAADhOAwAAAnLKGABwKAsAAAoW
>> "%~1" echo /gETCBEILTAAByg3AAAGAAcgrA0AAHLgGABwKDUAAAYmBnKOEgBwckAZAHBvRwAA
>> "%~1" echo CgAAOAoDAAACcn4ZAHAoCwAAChb+ARMIEQgtKQAHIKwNAABykBkAcCg1AAAGJgZy
>> "%~1" echo jhIAcHLuGQBwb0cAAAoAADjNAgAAAnIqGgBwKAsAAAoW/gETCBEILTAAByg3AAAG
>> "%~1" echo AAcgrA0AAHJCGgBwKDUAAAYmBnKOEgBwcqAaAHBvRwAACgAAOIkCAAACctwaAHAo
>> "%~1" echo CwAAChb+ARMIEQgtKQAHIKwNAAByNBgAcCg1AAAGJgZyjhIAcHL+GgBwb0cAAAoA
>> "%~1" echo ADhMAgAAAnJAGwBwKAsAAAoW/gETCBEILSkAByCsDQAAcpAZAHAoNQAABiYGco4S
>> "%~1" echo AHByXBsAcG9HAAAKAAA4DwIAAAJyoBsAcCgLAAAKFv4BEwgRCC0pAAcgrA0AAHLC
>> "%~1" echo GwBwKDUAAAYmBnKOEgBwchIcAHBvRwAACgAAONIBAAACckgcAHAoCwAAChb+ARMI
>> "%~1" echo EQgtOgAHIKwNAABycBwAcCg1AAAGJgcgrA0AAHIKFQBwKDUAAAYmBnKOEgBwcroc
>> "%~1" echo AHBvRwAACgAAOIQBAAACcvwcAHAoCwAAChb+ARMIEQg69QAAAAADchodAHAoggAA
>> "%~1" echo BgwDciAdAHAoggAABg0DcigdAHAoggAABhMECCh6AAAGLAgJKHsAAAYrARYAEwgR
>> "%~1" echo CC0LcjQdAHBzSwAACnoJKH0AAAYW/gETCBEILQtyWB0AcHNLAAAKegcoNwAABgAH
>> "%~1" echo IKwNAAAcjREAAAETCREJFnKEHQBwohEJFwiiEQkYcrMBAHCiEQkZCaIRCRpyswEA
>> "%~1" echo cKIRCRsRBCh+AAAGohEJKBYAAAooNQAABiYGco4SAHAbjREAAAETCREJFgiiEQkX
>> "%~1" echo cqAdAHCiEQkYCaIRCRlypB0AcKIRCRoRBKIRCSgWAAAKb0cAAAoAACt4AnKsHQBw
>> "%~1" echo KAsAAAoW/gETCBEILVkAA3LOHQBwKIIAAAYTBREFKHsAAAYTCBEILQty2B0AcHNL
>> "%~1" echo AAAKegcgrA0AAHLqHQBwEQUoCAAACig1AAAGJgZyjhIAcHIMHgBwEQUoCAAACm9H
>> "%~1" echo AAAKAAArC3IaHgBwc0sAAAp6AHImHgBwAih4AAAGcjIeAHAGco4SAHBvTAAACi0H
>> "%~1" echo croSAHArCwZyjhIAcG9IAAAKAChJAAAKKC4AAAYAAN5MEwYABnJEHgBwctwLAHBv
>> "%~1" echo RwAACgAGckoeAHARBm8HAAAKb0cAAAoAclYeAHACKHgAAAZyYh4AcBEGbwcAAAoo
>> "%~1" echo SQAACiguAAAGAADeAAAGEwcrABEHKgAAQRwAAAAAAAA7AAAAagcAAKUHAABMAAAA
>> "%~1" echo EAAAARMwAwAvAAAADAAAEQAofwAABgoGcnILAHB+BwAABG9HAAAKAAZych4AcCgv
>> "%~1" echo AAAGb0cAAAoABgsrAAcqABswBABEAgAADQAAEQAofwAABgooTQAACgtyfB4AcCgu
>> "%~1" echo AAAGAAASAhIDKDAAAAYTBBEEcs4LAHAoJQAAChb+ARMQERAtBwlzSwAACnoIF40h
>> "%~1" echo AAABExERERYfIJ0REW8vAAAKFpoTBREFCChDAAAGEwYoTQAAChMSEhJyoh4AcChO
>> "%~1" echo AAAKEwd+BgAABHLCHgBwEQcoTwAAChMIEQgoUAAACiZy0h4AcBEHcgofAHAoUQAA
>> "%~1" echo ChMJchYfAHARB3IKHwBwKFEAAAoTChEIEQkoUgAAChMLEQgRCihSAAAKEwwRCxEG
>> "%~1" echo FihIAAAGfgkAAAQoUwAACgARDBEGFyhIAAAGfgkAAAQoUwAACgAoTQAACgcoVAAA
>> "%~1" echo ChMNBnJKHwBwEQtvRwAACgAGcmIfAHARDG9HAAAKAAZydB8AcBEHEQkoDQAABm9H
>> "%~1" echo AAAKAAZyih8AcBEHEQooDQAABm9HAAAKAAZymh8AcBINKFUAAApqExMSEyhWAAAK
>> "%~1" echo KFcAAApvRwAACgAGcrAfAHARBnsdAAAEb1gAAAoTFBIUKFYAAAooWQAACm9HAAAK
>> "%~1" echo AAZyyh8AcBEGex4AAARvHgAACiwYctwfAHARBnseAAAEb1oAAAooWwAACisFcroS
>> "%~1" echo AHAAb0cAAAoABnKOEgBwcuQfAHBvRwAACgByDiAAcBELchogAHARDChJAAAKKC4A
>> "%~1" echo AAYAAN5BEw4ABnJEHgBwctwLAHBvRwAACgAGckoeAHARDm8HAAAKb0cAAAoAciIg
>> "%~1" echo AHARDm8HAAAKKAgAAAooLgAABgAA3gAABhMPKwARDypBHAAAAAAAABgAAADiAQAA
>> "%~1" echo +gEAAEEAAAAQAAABEzADAEoAAAAOAAARAByNEQAAAQsHFnLXCABwogcXAihcAAAK
>> "%~1" echo ogcYcp8BAHCiBxkDKFwAAAqiBxpyLiAAcKIHG34DAAAEKFwAAAqiBygWAAAKCisA
>> "%~1" echo BioAABswBQASAQAADwAAEQAAA3LXCABwbzEAAApvNgAACihdAAAKHy9+XgAACm9f
>> "%~1" echo AAAKCgZyPiAAcBpvJwAAChYvGQYfOm8yAAAKFi8OBnIKHwBwG29gAAAKKwEWABME
>> "%~1" echo EQQtIQACcusIAHAoCQAACnJEIABwbzwAAAoohQAABgDdmwAAAH4GAAAEcsIeAHAo
>> "%~1" echo UgAACihhAAAKCwcGKFIAAAooYQAACgwIBxtvOwAACiwICChiAAAKKwEWABMEEQQt
>> "%~1" echo HgACcusIAHAoCQAACnJSIABwbzwAAAoohQAABgDeQQJyCgsAcAgoYwAACiiFAAAG
>> "%~1" echo AADeKw0AAnLrCABwKAkAAApyXiAAcAlvBwAACigIAAAKbzwAAAoohQAABgAA3gAA
>> "%~1" echo ACoAAAEQAAAAAAEA4+QAKxAAAAETMAQAEQAAABAAABEAAgORAgMXWJEeYmAKKwAG
>> "%~1" echo KgAAABMwBAAkAAAAEQAAEQACA5ECAxdYkR5iYAIDGFiRHxBiYAIDGViRHxhiYG4K
>> "%~1" echo KwAGKhswAwDEAAAAEgAAEQBzkgAABgoAAhkXc0IAAAoLAAdybiAAcCgTAAAGDAgU
>> "%~1" echo /gEW/gETBREFLRQABnKWIABwfSAAAAQGEwTdgQAAAAgGKBQAAAYAAN4SBxT+ARMF
>> "%~1" echo EQUtBwdvJAAACgDcAAYGeyEAAARvMQAAChb+An0fAAAEBnsfAAAELRMGeyAAAARv
>> "%~1" echo MQAAChb+ARb+ASsBFwATBREFLQsGctAgAHB9IAAABADeGA0ABhZ9HwAABAYJbwcA
>> "%~1" echo AAp9IAAABADeAAAGEwQrAAARBCoBHAAAAgARADlKABIAAAAAAAAHAJuiABgQAAAB
>> "%~1" echo EzAFADwAAAATAAARAAIDFm9kAAAKJhYKKyUAAgQGBQZZbz4AAAoLBxb+AgwILQty
>> "%~1" echo 6iAAcHNlAAAKegYHWAoABgX+BAwILdMqGzAEAK8DAAAUAAARAAJvZgAACgoGHxZq
>> "%~1" echo /gQW/gETHREdLQgUExw4jAMAAAYgFQABAGooQwAACmkLB40kAAABDAIGB2pZCAco
>> "%~1" echo EgAABgAVDQcfFlkTBCs/AAgRBJEfUDMhCBEEF1iRH0szFwgRBBhYkRszDggRBBlY
>> "%~1" echo kRz+ARb+ASsBFwATHREdLQYAEQQNKxUAEQQXWRMEEQQW/gQW/gETHREdLbMJFv4E
>> "%~1" echo Fv4BEx0RHS0IFBMcOP4CAAAICR8KWCgPAAAGEwUICR8MWCgQAAAGEwYICR8QWCgQ
>> "%~1" echo AAAGEwcRBxZqMh0RBhZqMRcRBxEGWAYwDxEGIAAAAARq/gIW/gErARYAEx0RHS0I
>> "%~1" echo FBMcOKcCAAARBtSNJAAAARMIAhEHEQgRBmkoEgAABgAWEwkWEwo4XgIAAAARCBEJ
>> "%~1" echo kR9QMyERCBEJF1iRH0szFhEIEQkYWJEXMwwRCBEJGViRGP4BKwEWABMdER0tBThH
>> "%~1" echo AgAAEQgRCR8KWCgPAAAGEwsRCBEJHxRYKBAAAAYTDBEIEQkfHFgoDwAABhMNEQgR
>> "%~1" echo CR8eWCgPAAAGEw4RCBEJHyBYKA8AAAYTDxEIEQkfKlgoEAAABhMQKAkAAAoRCBEJ
>> "%~1" echo Hy5YEQ1vZwAAChMREREDKAsAAAoW/gETHREdOpIBAAAAEQwWajIPEQwgAAAABGr+
>> "%~1" echo Ahb+ASsBFgATHREdLQgUExw4qQEAAB8ejSQAAAETEgIREBESHx4oEgAABgAREhaR
>> "%~1" echo H1AzGBESF5EfSzMQERIYkRkzCRESGZEa/gErARYAEx0RHS0IFBMcOGMBAAAREh8a
>> "%~1" echo KA8AAAYTExESHxwoDwAABhMUERAfHmpYERNqWBEUalgTFREVFmoyDREVEQxYBv4C
>> "%~1" echo Fv4BKwEWABMdER0tCBQTHDgaAQAAEQzUjSQAAAETFgIRFREWEQxpKBIAAAYAEQsW
>> "%~1" echo /gEW/gETHREdLQkRFhMcOOsAAAARCx7+ARb+ARMdER06mAAAAAARFnNoAAAKExcR
>> "%~1" echo FxZzaQAAChMYc2oAAAoTGQAgACAAAI0kAAABExorDREZERoWERtvRQAACgARGBEa
>> "%~1" echo FhEajmlvPgAACiUTGxb+AhMdER0t2REZb2sAAAoTHN5+ERkU/gETHREdLQgRGW8k
>> "%~1" echo AAAKANwRGBT+ARMdER0tCBEYbyQAAAoA3BEXFP4BEx0RHS0IERdvJAAACgDcFBMc
>> "%~1" echo Kz0RCR8uEQ1YEQ5YEQ9YWBMJABEKF1gTChEKEQUvEBEJHy5YEQiOaf4CFv4BKwEW
>> "%~1" echo ABMdER06gf3//xQTHCsAABEcKgABKAAAAgDsAkEtAxQAAAAAAgDlAlxBAxQAAAAA
>> "%~1" echo AgDbAnpVAxQAAAAAEzAFAHEBAAAVAAARAAKOaR4yHQIWkRkzEwIXkS0OAhiRHjMI
>> "%~1" echo AhmRFv4BKwEWACsBFgATChEKLREAA3IAIQBwfSAAAAQ4MwEAABQKHgtzHQAACgw4
>> "%~1" echo CQEAAAACBygPAAAGDQIHGlgoEAAABhMEEQQeajIQB2oRBFgCjmlq/gIW/gErARYA
>> "%~1" echo EwoRCi0FOOYAAAAJF/4BFv4BEwoRCi0NAgcoGAAABgo4sQAAAAkgAgEAAP4BFv4B
>> "%~1" echo EwoRCjqdAAAAAAIHHxRYKBAAAAZpEwUGEQUoFwAABhMGAgcfHFgoDwAABhMHBx8k
>> "%~1" echo WBMIEQZyGiEAcCgLAAAKFv4BEwoRCi0PAhEIEQcGAygVAAAGACtOEQZyLCEAcCgL
>> "%~1" echo AAAKFv4BEwoRCi05AAIRCBEHBnLOHQBwKBYAAAYTCREJbzEAAAoWMQoIEQlvbAAA
>> "%~1" echo CisBFwATChEKLQkIEQlvJgAACgAAAAcRBGlYCwAHHlgCjmn+Ahb+ARMKEQo64/7/
>> "%~1" echo /wMIfSQAAAQqAAAAEzADAAYBAAAWAAARABYKOPAAAAAAAwYfFFpYCwcfFFgCjmn+
>> "%~1" echo Ahb+ARMHEQctBTjeAAAAAgcaWCgQAAAGaQwFCCgXAAAGDQIHHw9YkSD/AAAAXxME
>> "%~1" echo AgcfEFgoEAAABhMFAgceWCgQAAAGaRMGCXJMIQBwKAsAAAoW/gETBxEHLSIOBBEE
>> "%~1" echo GS4LBREFaSgXAAAGKwgFEQYoFwAABgB9IQAABCtdCXJcIQBwKAsAAAoW/gETBxEH
>> "%~1" echo LSIOBBEEGS4LBREFaSgXAAAGKwgFEQYoFwAABgB9IgAABCsnCXJ0IQBwKAsAAAoW
>> "%~1" echo /gETBxEHLRMOBBIFKFYAAAooVwAACn0jAAAEAAYXWAoGBP4EEwcRBzoD////KgAA
>> "%~1" echo EzADAKYAAAAXAAARABYKOIUAAAAAAwYfFFpYCwcfFFgCjmn+Ahb+ARMHEQctAit2
>> "%~1" echo AgcaWCgQAAAGaQwFCCgXAAAGDgQoJQAAChb+ARMHEQctAitBAgcfD1iRIP8AAABf
>> "%~1" echo DQIHHlgoEAAABmkTBAIHHxBYKBAAAAYTBQkZLgsFEQVpKBcAAAYrCAURBCgXAAAG
>> "%~1" echo ABMGKxoGF1gKBgT+BBMHEQc6bv///3L1BQBwEwYrABEGKgAAEzACAC8AAAAYAAAR
>> "%~1" echo AAIsDAMWMggDAo5p/gQrARYACwctCHL1BQBwCisPAgOaJS0GJnL1BQBwCisABioA
>> "%~1" echo GzAEANAAAAAZAAARAAIDHlgoEAAABmkKAgMfEFgoEAAABgsCAx8UWCgQAAAGDAcg
>> "%~1" echo AAEAAGpfFmr+ARb+AQ0GjREAAAETBAMfHFgTBQMIaVgTBhYTBytxAAIRBREHGlpY
>> "%~1" echo KBAAAAYTCBEGEQhpWBMJEQkWMgkRCQKOaf4EKwEWABMLEQstDQARBBEHcvUFAHCi
>> "%~1" echo KzAAEQQRBwktCgIRCSgaAAAGKwgCEQkoGQAABgCiAN4PJgARBBEHcvUFAHCiAN4A
>> "%~1" echo AAARBxdYEwcRBwb+BBMLEQsthBEEEworABEKKgEQAAAAAIYAH6UADwEAAAETMAQA
>> "%~1" echo aAAAABoAABEAAwoCBpEggAAAAF8W/gENCS0GBhhYCisEBhdYCgIGkSD/AAAAXwsH
>> "%~1" echo IIAAAABfFv4BDQktGwAHH39fHmICBhdYkSD/AAAAX2ALBhhYCgArBgAGF1gKACgJ
>> "%~1" echo AAAKAgYHb2cAAAoMKwAIKhMwBQBKAAAAGgAAEQADCgIGKA8AAAYLBhhYCgcgAIAA
>> "%~1" echo AF8W/gENCS0ZAAcg/38AAF8fEGICBigPAAAGYAsGGFgKAChtAAAKAgYHGFpvZwAA
>> "%~1" echo CgwrAAgqAAAbMAMAcgAAABsAABEAAH4GAAAEcowhAHAoUgAACgoGKG4AAAoNCS0C
>> "%~1" echo 3lIGKG8AAApzcAAACgsHKHEAAApvcgAACgAWDCseAAAHCG9zAAAKFyh0AAAKAADe
>> "%~1" echo BSYAAN4AAAAIF1gMCAdvHgAACgJZ/gQNCS3TAN4FJgAA3gAAACoAAAEcAAAAADsA
>> "%~1" echo Ek0ABQEAAAEAAAEAaWoABQEAAAEbMAQAJQQAABwAABEAKH8AAAYKAAQWav4CExAR
>> "%~1" echo EC0UAAIEKAgAAAYAcpwhAHBzSwAACnoEIQAAAAABAAAA/gIW/gETEBEQLRQAAgQo
>> "%~1" echo CAAABgBy0CEAcHNLAAAKegNyzh0AcCiCAAAGCwcoJwAABgwoTQAAChMREhFy9iEA
>> "%~1" echo cChOAAAKDX4GAAAEcowhAHAJKE8AAAoTBBEEKFAAAAomGSgbAAAGABEEch4iAHAo
>> "%~1" echo UgAAChMFAgQRBSEAAAAAAQAAACgHAAAGEwYRBhZq/gQW/gETEBEQLR4AABEFKHUA
>> "%~1" echo AAoAAN4FJgAA3gAActAhAHBzSwAACnoajSQAAAETBxEFGRdzQgAAChMIABEIEQcW
>> "%~1" echo Gm8+AAAKEwkRCRoyNhEHFpEfUDMuEQcXkR9LMyYRBxiRGTMHEQcZkRouFBEHGJEb
>> "%~1" echo MwkRBxmRHP4BKwEWACsBFwArARYAExAREC0vABEIb3YAAAoAABEFKHUAAAoAEQQX
>> "%~1" echo KHQAAAoAAN4FJgAA3gAAci4iAHBzSwAACnoA3hQRCBT+ARMQERAtCBEIbyQAAAoA
>> "%~1" echo 3AARBSgRAAAGEwoWEw1+CgAABCUTEhINKHcAAAoAAH4LAAAECREFb0cAAAoAAN4U
>> "%~1" echo EQ0W/gETEBEQLQgREih4AAAKANwABnJgIgBwCW9HAAAKAAZyciIAcAhvRwAACgAG
>> "%~1" echo coQiAHASBihWAAAKKFcAAApvRwAACgAGcpgiAHARBigoAAAGb0cAAAoABnJMIQBw
>> "%~1" echo EQp7IQAABG9HAAAKAAZyXCEAcBEKeyIAAARvRwAACgAGcnQhAHARCnsjAAAEb0cA
>> "%~1" echo AAoABnKqIgBwEQp7JAAABG8eAAAKExMSEyhWAAAKKFkAAApvRwAACgAGcsoiAHBy
>> "%~1" echo 4iIAcBEKeyQAAARvWgAACihbAAAKb0cAAAoABnLmIgBwEQp7HwAABC0HctwLAHAr
>> "%~1" echo BXLoCwBwAG9HAAAKABEKex8AAAQTEBEQLRMGcvYiAHARCnsgAAAEb0cAAAoAEQp7
>> "%~1" echo HwAABCwUEQp7IQAABG8xAAAKFv4CFv4BKwEXABMQERAtYQAoLAAABhMLEQtyuhIA
>> "%~1" echo cCglAAAKFv4BExAREC1DABELEQp7IQAABCgkAAAGEwwGcgwjAHARDG9HAAAKAAZy
>> "%~1" echo NiMAcBEMbzEAAAoWMAdy3AsAcCsFcugLAHAAb0cAAAoAAAAfCo0RAAABExQRFBZy
>> "%~1" echo WCMAcKIRFBcIohEUGHJoIwBwohEUGREGKCgAAAaiERQacm4jAHCiERQbEQp7IQAA
>> "%~1" echo BKIRFBxyfCMAcKIRFB0RCnsiAAAEohEUHnKMIwBwohEUHwkRCnsjAAAEohEUKBYA
>> "%~1" echo AAooLgAABgAA3kETDgAGckQeAHBy3AsAcG9HAAAKAAZySh4AcBEObwcAAApvRwAA
>> "%~1" echo CgBynCMAcBEObwcAAAooCAAACiguAAAGAADeAAAGEw8rABEPKgAAAEF8AAAAAAAA
>> "%~1" echo ygAAAAwAAADWAAAABQAAAAEAAAEAAAAAVAEAABUAAABpAQAABQAAAAEAAAECAAAA
>> "%~1" echo +gAAAIMAAAB9AQAAFAAAAAAAAAACAAAAngEAACIAAADAAQAAFAAAAAAAAAAAAAAA
>> "%~1" echo BwAAANQDAADbAwAAQQAAABAAAAEbMAUAZwUAAB0AABEAKH8AAAYKAAJyYCIAcCiC
>> "%~1" echo AAAGCxYTEX4KAAAEJRMUEhEodwAACgAAfgsAAAQHEgJveQAAChMVERUtAhQMAN4U
>> "%~1" echo EREW/gETFREVLQgRFCh4AAAKANwACCguAAAKLQgIKGIAAAorARYAExURFS0LcrAj
>> "%~1" echo AHBzSwAACnooLAAABg0JcroSAHAoCwAAChb+ARMVERUtC3K+EgBwc0sAAAp6AnLW
>> "%~1" echo IwBwKIIAAAZytwEAcCgLAAAKEwQCcuYjAHAoggAABnK3AQBwKAsAAAoTBQJy8iMA
>> "%~1" echo cCiCAAAGcrcBAHAoCwAAChMGAnIGJABwKIIAAAZytwEAcCgLAAAKEwcCckwhAHAo
>> "%~1" echo ggAABhMIc3oAAAoTCR8MjQEAAAETFhEWFnIkJABwohEWFwmiERYYckYkAHCiERYZ
>> "%~1" echo EQiiERYaclIkAHCiERYbEQSMOgAAAaIRFhxyWiQAcKIRFh0RBYw6AAABohEWHnJi
>> "%~1" echo JABwohEWHwkRBow6AAABohEWHwpyaiQAcKIRFh8LEQeMOgAAAaIRFigUAAAKKC4A
>> "%~1" echo AAYAEQcsDBEIKCYAAAYW/gErARcAExURFS1xABEJcnQkAHARCHKAJABwKFEAAApv
>> "%~1" echo ewAACiZ+AgAABBqNEQAAARMXERcWckIWAHCiERcXCaIRFxhyiiQAcKIRFxkRCKIR
>> "%~1" echo FyBg6gAAKE0AAAYTChEJcp4kAHARCm+NAAAGKFwAAAYoCAAACm97AAAKJgBzHQAA
>> "%~1" echo ChMLEQtyQhYAcG8mAAAKABELCW8mAAAKABELcqQkAHBvJgAACgARBBb+ARMVERUt
>> "%~1" echo DRELcrQkAHBvJgAACgARBRb+ARMVERUtDRELcrokAHBvJgAACgARBhb+ARMVERUt
>> "%~1" echo DRELcsAkAHBvJgAACgARCwhvJgAACgARCXLGJABwEQtvWgAACihPAAAGKAgAAApv
>> "%~1" echo ewAACiZ+AgAABBELb1oAAAog4JMEAChNAAAGEwwRDG+NAAAGKHgAAAYTDREJcp4k
>> "%~1" echo AHARDSgpAAAGKAgAAApvewAACiYRDHsRAAAELR4RDHsQAAAELRURDXLWJABwG28n
>> "%~1" echo AAAKFv4EFv4BKwEWABMOEQ4tQxEHLT8RCCgmAAAGLDYRDXLmJABwG28nAAAKFi8i
>> "%~1" echo EQ1yLCUAcBtvJwAAChYvEhENclwlAHAbbycAAAoW/gQrARYAKwEXABMVERU63wAA
>> "%~1" echo AAARCXKQJQBwEQhygCQAcChRAAAKb3sAAAomfgIAAAQajREAAAETFxEXFnJCFgBw
>> "%~1" echo ohEXFwmiERcYcookAHCiERcZEQiiERcgYOoAAChNAAAGEwoRCXKeJABwEQpvjQAA
>> "%~1" echo BihcAAAGKAgAAApvewAACiZ+AgAABBELb1oAAAog4JMEAChNAAAGEw8RD2+NAAAG
>> "%~1" echo KHgAAAYTDREJcrAlAHARDSgpAAAGKAgAAApvewAACiYRD3sRAAAELR4RD3sQAAAE
>> "%~1" echo LRURDXLWJABwG28nAAAKFv4EFv4BKwEWABMOEQ8TDAAGcrwlAHARCW98AAAKb0cA
>> "%~1" echo AAoABnLIJQBwEQ1vRwAACgARDhb+ARMVERUtTwAGco4SAHBy0CUAcBEIbzEAAAoW
>> "%~1" echo MAdy9QUAcCsMctolAHARCCgIAAAKAHLeJQBwKFEAAApvRwAACgBy4iUAcBEIKAgA
>> "%~1" echo AAooLgAABgAAK08ABnJEHgBwctwLAHBvRwAACgARDREMexEAAAQoJQAABhMQBnJK
>> "%~1" echo HgBwERBvRwAACgBy9iUAcBEQcgomAHARDSgpAAAGKEkAAAooLgAABgAAAN5BExIA
>> "%~1" echo BnJEHgBwctwLAHBvRwAACgAGckoeAHAREm8HAAAKb0cAAAoAchYmAHAREm8HAAAK
>> "%~1" echo KAgAAAooLgAABgAA3gAABhMTKwAREyoAQTQAAAIAAAAXAAAAKQAAAEAAAAAUAAAA
>> "%~1" echo AAAAAAAAAAAHAAAAFgUAAB0FAABBAAAAEAAAARMwBAAnAAAAHgAAEQByKiYAcAoo
>> "%~1" echo KwAACgZvPAAACgsCBxYHjmlvRQAACgACb0QAAAoAKgATMAQAaQAAAB8AABEAc3oA
>> "%~1" echo AAoKBnI5JwBwb30AAAoDb30AAApy4iIAcG99AAAKJgZySScAcG99AAAKBCiGAAAG
>> "%~1" echo b30AAApyVycAcG99AAAKJigJAAAKBm98AAAKbzwAAAoLAgcWB45pb0UAAAoAAm9E
>> "%~1" echo AAAKACoAAAATMAQARwAAACAAABEAc34AAAoKBnJdJwBwA29HAAAKAAZych4AcARv
>> "%~1" echo RwAACgAGcmknAHAPAyhWAAAKKFkAAApvRwAACgACcl0nAHAGKB8AAAYAKgATMAMA
>> "%~1" echo IgAAACAAABEAc34AAAoKBnJ5JwBwA29HAAAKAAJygycAcAYoHwAABgAqHgIofwAA
>> "%~1" echo CioeAih/AAAKKh4CKH8AAAoqPgACeyUAAAQDKCEAAAYAKgAAEzAEAN8AAAAhAAAR
>> "%~1" echo AAJ7JgAABHslAAAEAyghAAAGAANy1iQAcBtvJwAAChb+BAoGLQcCF30nAAAEA3Lm
>> "%~1" echo JABwG28nAAAKFi8gA3IsJQBwG28nAAAKFi8RA3JcJQBwG28nAAAKFv4EKwEWAAoG
>> "%~1" echo LQcCF30oAAAEA3KRJwBwG28nAAAKFi8RA3KhJwBwG28nAAAKFv4EKwEWAAoGLQwC
>> "%~1" echo A280AAAKfSkAAAQDcq0nAHAbbycAAAoWLxEDcs8nAHAbbycAAAoW/gQrARYACgYt
>> "%~1" echo HQJ7JgAABHslAAAEcqQkAHBy5ScAcB9GKCAAAAYAKj4AAnslAAAEAyghAAAGACoA
>> "%~1" echo EzADAGUAAAAhAAARAAJ7KwAABHslAAAEAyghAAAGAANy1iQAcBtvJwAAChb+BAoG
>> "%~1" echo LQcCF30sAAAEA3KRJwBwG28nAAAKFi8RA3KhJwBwG28nAAAKFv4EKwEWAAoGLREC
>> "%~1" echo eyoAAAQDbzQAAAp9KQAABCoAAAAbMAUAvAUAACIAABEUExEUExJzkwAABhMTERMC
>> "%~1" echo fSUAAAQAERN7JQAABCgeAAAGAHOWAAAGEw8RDxETfSYAAAQAA3JgIgBwKIIAAAYK
>> "%~1" echo FhMOfgoAAAQlExQSDih3AAAKAAB+CwAABAYSAW95AAAKExURFS0CFAsA3hQRDhb+
>> "%~1" echo ARMVERUtCBEUKHgAAAoA3AAHKC4AAAotCAcoYgAACisBFgATFREVLR4AERN7JQAA
>> "%~1" echo BBZysCMAcHL1BQBwKCMAAAYA3QMFAAAoLAAABgwIcroSAHAoCwAAChb+ARMVERUt
>> "%~1" echo HgARE3slAAAEFnK+EgBwcvUFAHAoIwAABgDdywQAAANy1iMAcCiCAAAGcrcBAHAo
>> "%~1" echo CwAACg0DcuYjAHAoggAABnK3AQBwKAsAAAoTBANy8iMAcCiCAAAGcrcBAHAoCwAA
>> "%~1" echo ChMFA3IGJABwKIIAAAZytwEAcCgLAAAKEwYDckwhAHAoggAABhMHHwyNAQAAARMW
>> "%~1" echo ERYWcvUnAHCiERYXCKIRFhhyRiQAcKIRFhkRB6IRFhpyUiQAcKIRFhsJjDoAAAGi
>> "%~1" echo ERYcclokAHCiERYdEQSMOgAAAaIRFh5yYiQAcKIRFh8JEQWMOgAAAaIRFh8Kcmok
>> "%~1" echo AHCiERYfCxEGjDoAAAGiERYoFAAACiguAAAGABETeyUAAARyGygAcHIrKABwGygg
>> "%~1" echo AAAGABEGLAwRBygmAAAGFv4BKwEXABMVERU6mAAAAAARE3slAAAEcookAHBydCQA
>> "%~1" echo cBEHcjcoAHAoUQAACh8MKCAAAAYAfgIAAAQajREAAAETFxEXFnJCFgBwohEXFwii
>> "%~1" echo ERcYcookAHCiERcZEQeiERcgYOoAABERLRERE/4GlAAABnOAAAAKExErABERKE4A
>> "%~1" echo AAYTCBEIexEAAAQW/gETFREVLRIRE3slAAAEcjsoAHAoIQAABgAAcx0AAAoTCREJ
>> "%~1" echo ckIWAHBvJgAACgARCQhvJgAACgARCXKkJABwbyYAAAoACRb+ARMVERUtDREJcrQk
>> "%~1" echo AHBvJgAACgARBBb+ARMVERUtDREJcrokAHBvJgAACgARBRb+ARMVERUtDREJcsAk
>> "%~1" echo AHBvJgAACgARCQdvJgAACgARE3slAAAEclcoAHByYSgAcB8eKCAAAAYAERN7JQAA
>> "%~1" echo BHJ/KABwEQlvWgAACihPAAAGKAgAAAooIQAABgARDxZ9JwAABBEPFn0oAAAEEQ9y
>> "%~1" echo 9QUAcH0pAAAEfgIAAAQRCW9aAAAKIMAnCQARD/4GlwAABnOAAAAKKE4AAAYTChEK
>> "%~1" echo exEAAAQtEhEKexAAAAQtCREPeycAAAQrARYAEwsRCxb+ARMVERUtVQARE3slAAAE
>> "%~1" echo F3LQJQBwEQdvMQAAChYwB3L1BQBwKwxy2iUAcBEHKAgAAAoAct4lAHAoUQAAChEH
>> "%~1" echo KCMAAAYAcokoAHARBygIAAAKKC4AAAYA3Z0BAAARD3soAAAELBARBi0MEQcoJgAA
>> "%~1" echo Bhb+ASsBFwATFREVOgYBAABzmAAABhMNEQ0RD30qAAAEEQ0RE30rAAAEABETeyUA
>> "%~1" echo AARyoSgAcHKtKABwHygoIAAABgB+AgAABBqNEQAAARMXERcWckIWAHCiERcXCKIR
>> "%~1" echo FxhyiiQAcKIRFxkRB6IRFyBg6gAAERItERET/gaVAAAGc4AAAAoTEisAERIoTgAA
>> "%~1" echo BiYRDRZ9LAAABH4CAAAEEQlvWgAACiDAJwkAEQ3+BpkAAAZzgAAACihOAAAGEwwR
>> "%~1" echo DHsRAAAELRURDHsQAAAELQwRDXssAAAEFv4BKwEXABMVERUtMQARE3slAAAEF3LJ
>> "%~1" echo KABwEQcoCAAAChEHKCMAAAYAcuUoAHARBygIAAAKKC4AAAYA3nQAERN7JQAABBYR
>> "%~1" echo D3spAAAEEQp7EQAABCglAAAGEQcoIwAABgAA3ksTEAAAERN7JQAABBZyBSkAcBEQ
>> "%~1" echo bwcAAAooCAAACnL1BQBwKCMAAAYAAN4FJgAA3gAAchEpAHAREG8HAAAKKAgAAAoo
>> "%~1" echo LgAABgAA3gAAAAAqQUwAAAIAAABDAAAAKQAAAGwAAAAUAAAAAAAAAAAAAABwBQAA
>> "%~1" echo KAAAAJgFAAAFAAAAAQAAAQAAAAAjAAAASgUAAG0FAABLAAAAEAAAARMwAwBnAAAA
>> "%~1" echo IAAAEQBzfgAACgoGckQeAHADLQdy3AsAcCsFcugLAHAAb0cAAAoABnIpKQBwBG9H
>> "%~1" echo AAAKAAZyTCEAcAVvRwAACgAGcmknAHADLQdyOSkAcCsFcjkpAHAAb0cAAAoAAnJB
>> "%~1" echo KQBwBigfAAAGACoAEzAEAOQAAAAjAAARAAMoJgAABhMIEQgtDHL1BQBwEwc4xwAA
>> "%~1" echo AAIgoA8AAHJLKQBwAygIAAAKKDMAAAYKAAYoeQAABhMJFhMKOIUAAAARCREKmgsA
>> "%~1" echo B280AAAKDAhybSkAcBtvJwAACg0JFv4EEwgRCC1ZAAgJcm0pAHBvMQAAClhvNgAA
>> "%~1" echo ChMEEQQfIG8yAAAKEwURBRYvBBEEKwoRBBYRBW8zAAAKABMGEQZvNAAAChMGEQZv
>> "%~1" echo MQAAChb+Ahb+ARMIEQgtBhEGEwfeIgAAEQoXWBMKEQoRCY5p/gQTCBEIOmr///9y
>> "%~1" echo 9QUAcBMHKwAAEQcqEzADAC8BAAAkAAARAAMW/gENCS0LcocpAHAMOBkBAAACJS0G
>> "%~1" echo JnL1BQBwCgZy5iQAcBtvJwAAChYvIAZyLCUAcBtvJwAAChYvEQZyXCUAcBtvJwAA
>> "%~1" echo Chb+BCsBFgANCS0Lcr8pAHAMOM4AAAAGcg0qAHAbbycAAAoW/gQNCS0Lck8qAHAM
>> "%~1" echo OLAAAAAGcokqAHAbbycAAAoW/gQNCS0LcsUqAHAMOJIAAAAGcvkqAHAbbycAAAoW
>> "%~1" echo /gQNCS0IckErAHAMK3cGclUrAHAbbycAAAoW/gQNCS0IcpUrAHAMK1wGcssrAHAb
>> "%~1" echo bycAAAoW/gQNCS0Icv0rAHAMK0EGcicsAHAbbycAAAoW/gQNCS0IclEsAHAMKyYG
>> "%~1" echo KCkAAAYLB28xAAAKFjAHcoMsAHArC3KbLABwBygIAAAKAAwrAAgqABMwAgB0AAAA
>> "%~1" echo JQAAEQACKC4AAAoW/gEMCC0EFgsrXwJvMQAACiCAAAAA/gIW/gEMCC0EFgsrRwAC
>> "%~1" echo DRYTBCstCREEb4EAAAoKBiiCAAAKLQwGHy4uBwYfX/4BKwEXAAwILQQWC94YEQQX
>> "%~1" echo WBMEEQQJbzEAAAr+BAwILcUXCysAAAcqEzADAMcAAAAmAAARAAIoLgAAChb+ARME
>> "%~1" echo EQQtC3IeIgBwDTiqAAAAc3oAAAoKAAITBRYTBitDEQURBm+BAAAKCwAHKIIAAAot
>> "%~1" echo GQcfLi4UBx9fLg8HHy0uCgcfIP4BFv4BKwEWABMEEQQtCAYHb4MAAAomABEGF1gT
>> "%~1" echo BhEGEQVvMQAACv4EEwQRBC2sBm98AAAKbzQAAAoMCG8xAAAKFv4BFv4BEwQRBC0I
>> "%~1" echo ch4iAHANKyEIbzEAAAofUP4CFv4BEwQRBC0KCBYfUG8zAAAKDAgNKwAJKgATMAMA
>> "%~1" echo 1AAAACcAABEAAiAABAAAav4EFv4BEwQRBC0WAowiAAABcqcsAHAoRgAACg04qQAA
>> "%~1" echo AAJsIwAAAAAAAJBAWwoGIwAAAAAAAJBA/gQW/gETBBEELR4SAHKtLABwKFYAAAoo
>> "%~1" echo hAAACnK1LABwKAgAAAoNK2kGIwAAAAAAAJBAWwsHIwAAAAAAAJBA/gQW/gETBBEE
>> "%~1" echo LR4SAXKtLABwKFYAAAoohAAACnK9LABwKAgAAAoNKyoHIwAAAAAAAJBAWwwSAnLF
>> "%~1" echo LABwKFYAAAoohAAACnLPLABwKAgAAAoNKwAJKhMwAwC4AAAAKAAAEQBy9QUAcAoA
>> "%~1" echo AiUtBiZy9QUAcCh5AAAGEwQWEwUrfREEEQWaCwAHbzQAAAoMCG8xAAAKFv4BFv4B
>> "%~1" echo EwYRBi0CK1UGbzEAAAoW/gEW/gETBhEGLQIICghy1iQAcBtvJwAAChYvIAhykScA
>> "%~1" echo cBtvJwAAChYvEQhyoScAcBtvJwAAChb+BCsBFgATBhEGLQkIKHgAAAYN3iEAEQUX
>> "%~1" echo WBMFEQURBI5p/gQTBhEGOnL///8GKHgAAAYNKwAACSoDMAMAXgAAAAAAAAAAAig3
>> "%~1" echo AAAGAAIgrA0AAHJCGgBwKDUAAAYmAiCsDQAActcsAHAoNQAABiYCIKwNAABy4BgA
>> "%~1" echo cCg1AAAGJgIgrA0AAHInLQBwKDUAAAYmAiCsDQAAcqYVAHAoNQAABiYqAAADMAMA
>> "%~1" echo VwAAAAAAAAAAAiCsDQAAcpAZAHAoNQAABiYCIKwNAABywhsAcCg1AAAGJgIgrA0A
>> "%~1" echo AHI0GABwKDUAAAYmAiCsDQAAcnAcAHAoNQAABiYCIKwNAAByChUAcCg1AAAGJioA
>> "%~1" echo EzAEADgAAAApAAARABIAEgEoMAAABnLOCwBwKAsAAAotB3K6EgBwKxUGF40hAAAB
>> "%~1" echo DQkWHyCdCW8vAAAKFpoADCsACCobMAQA4gAAACoAABEAAAIoLgAACi0DAisKKA0A
>> "%~1" echo AApvDgAACgAKBheNIQAAAQsHFh8inQdvhQAACgoGKGEAAAoKBihuAAAKDAgtBwYo
>> "%~1" echo UAAACiYGgAUAAAQGcnEtAHAoUgAACoAGAAAEfgYAAAQoUAAACiZ+BgAABHKPLQBw
>> "%~1" echo KE0AAAoNEgNyoh4AcChOAAAKcp0tAHAoUQAACihSAAAKgAcAAAR+BwAABHL1BQBw
>> "%~1" echo fgkAAAQohgAACgAA3jImACgNAAAKbw4AAAqABQAABH4FAAAEgAYAAAR+BgAABHKn
>> "%~1" echo LQBwKFIAAAqABwAABADeAAAqAAABEAAAAAABAK2uADIBAAABGzAFAGQAAAArAAAR
>> "%~1" echo AAAWCn4IAAAEJQsSACh3AAAKAAB+BwAABChNAAAKDBICcs8tAHAoTgAACnKeJABw
>> "%~1" echo AiiHAAAKKEkAAAp+CQAABCiGAAAKAADeEAYW/gENCS0HByh4AAAKANwAAN4FJgAA
>> "%~1" echo 3gAAKgEcAAACAAQARUkAEAAAAAAAAAEAXF0ABQEAAAEbMAUArAAAACwAABEAAH4H
>> "%~1" echo AAAEKC4AAAotDH4HAAAEKGIAAAorARYAEwcRBy0Jcv8tAHATBt59fgcAAAQoYwAA
>> "%~1" echo CgogUEYAAAsGjmkHMAMWKwUGjmkHWQAMKAkAAAoGCAaOaQhZb2cAAAoNCR8KbzIA
>> "%~1" echo AAoTBAgWMQcRBBb+BCsBFwATBxEHLQsJEQQXWG82AAAKDQkoeAAABhMG3hgTBQBy
>> "%~1" echo Ey4AcBEFbwcAAAooCAAAChMG3gAAEQYqARAAAAAAAQCPkAAYEAAAARMwBAAWAwAA
>> "%~1" echo LQAAEQACcvUFAHBRA3IjLgBwUXL1BQBwCnL1BQBwC3L1BQBwDHL1BQBwDXL1BQBw
>> "%~1" echo EwRy9QUAcBMFACC4CwAAGI0RAAABEwsRCxZyfS4AcKIRCxdyjS4AcKIRCyg0AAAG
>> "%~1" echo KHkAAAYTDBYTDTiXAQAAEQwRDZoTBgARBm80AAAKEwcRB28xAAAKLBIRB3KTLgBw
>> "%~1" echo G287AAAKFv4BKwEWABMOEQ4tBThYAQAAEQcYjSEAAAETDxEPFh8gnREPFx8JnREP
>> "%~1" echo F2+IAAAKEwgRCI5pGP4EFv4BEw4RDi0FOCMBAAARCBeacs4LAHAoCwAAChb+ARMO
>> "%~1" echo EQ46nQAAAAAJbzEAAAoW/gEW/gETDhEOLQMRBw0RB3KjLgBwG28nAAAKFi8lEQdy
>> "%~1" echo uy4AcBtvJwAAChYvFREHctkuAHAbbycAAAoW/gQW/gErARcAEwkRCSwPEQRvMQAA
>> "%~1" echo Chb+ARb+ASsBFwATDhEOLQQRBxMEEQksHREIFpofOm8yAAAKFi8PEQVvMQAAChb+
>> "%~1" echo ARb+ASsBFwATDhEOLQQRBxMFK2wRCBeacvUuAHAoCwAACiwOBm8xAAAKFv4BFv4B
>> "%~1" echo KwEXABMOEQ4tBREHCitAEQgXmnIPLwBwKAsAAAosDgdvMQAAChb+ARb+ASsBFwAT
>> "%~1" echo DhEOLQURBwsrFQhvMQAAChb+ARb+ARMOEQ4tAxEHDAARDRdYEw0RDREMjmn+BBMO
>> "%~1" echo EQ46WP7//xEFbzEAAAoW/gIW/gETDhEOLRgAAhEFUQNyHy8AcFFyzgsAcBMKONUA
>> "%~1" echo AAARBG8xAAAKFv4CFv4BEw4RDi0YAAIRBFEDclEvAHBRcs4LAHATCjiqAAAACW8x
>> "%~1" echo AAAKFv4CFv4BEw4RDi0XAAIJUQNydy8AcFFyzgsAcBMKOIEAAAAGbzEAAAoW/gIW
>> "%~1" echo /gETDhEOLRQAAgZRA3LHLwBwUXL1LgBwEworWwdvMQAAChb+Ahb+ARMOEQ4tFAAC
>> "%~1" echo B1EDcgMwAHBRcg8vAHATCis1CG8xAAAKFv4CFv4BEw4RDi0aAAIIUQNyPzAAcAgo
>> "%~1" echo CAAAClFyVTAAcBMKKwlyZTAAcBMKKwARCioAABMwBAAhAAAALgAAEQACIMQJAABy
>> "%~1" echo bzAAcAMoCAAACigzAAAGKHgAAAYKKwAGKgAAABMwBgA+AAAALwAAEQACIMQJAABy
>> "%~1" echo gTAAcANyswEAcAQoSQAACigzAAAGKHgAAAYKBnKdMABwKAsAAAotAwYrBXKdMABw
>> "%~1" echo AAsrAAcqAAATMAQAMQAAAA4AABEAAxqNEQAAAQsHFnJCFgBwogcXAqIHGHKnMABw
>> "%~1" echo ogcZBKIHKDQAAAYoeAAABgorAAYqAAAAEzADABIAAAAuAAARAH4CAAAEAwIoTAAA
>> "%~1" echo BgorAAYqAAATMAQAMQAAAA4AABEAAxqNEQAAAQsHFnJCFgBwogcXAqIHGHKnMABw
>> "%~1" echo ogcZBKIHKDYAAAYoeAAABgorAAYqAAAAEzADAIsAAAAwAAARAH4CAAAEAwIoTQAA
>> "%~1" echo BgoGb40AAAYoeAAABgsGexEAAAQW/gENCS0WcrMwAHADKE8AAAYoCAAACnNLAAAK
>> "%~1" echo egZ7EAAABBb+AQ0JLTsajQEAAAETBBEEFnLHMABwohEEFwZ7EAAABIwYAAABohEE
>> "%~1" echo GHLbMABwohEEGQeiEQQoFAAACnNLAAAKegcMKwAIKgATMAQAzQAAADEAABEAAig6
>> "%~1" echo AAAGCgYoYgAAChb+AQwILQU4sgAAAHN6AAAKCwdy4TAAcG97AAAKJgdyBzEAcAIo
>> "%~1" echo CAAACm97AAAKJgdyGzEAcChNAAAKDRIDcjExAHAoTgAACigIAAAKb3sAAAomBwJy
>> "%~1" echo 5g8AcHJMEABwKDgAAAYABwJy5g8AcHKSEABwKDgAAAYABwJyyhAAcHLYEABwKDgA
>> "%~1" echo AAYABwJyGBEAcHImEQBwKDgAAAYABgdvfAAACn4JAAAEKFMAAAoAclkxAHAGKAgA
>> "%~1" echo AAooLgAABgAqAAAAEzAGAGoAAAAYAAARAAMgrA0AAHKBMABwBHKzAQBwBShJAAAK
>> "%~1" echo KDUAAAYKBnK6EgBwKAsAAAoW/gELBy0XcmsxAHAEcqAdAHAFKEkAAApzSwAACnoC
>> "%~1" echo BG99AAAKHyBvgwAACgVvfQAACh8gb4MAAAoGb3sAAAomKgAAEzAHAHIBAAAyAAAR
>> "%~1" echo AAIoOgAABgoGKGIAAAoTBBEELRFyfTEAcAYoCAAACnNLAAAKegAGKAkAAAooiQAA
>> "%~1" echo ChMFFhMGOAMBAAARBREGmgsAB280AAAKDAhvMQAACiwRCHKRMQBwGm87AAAKFv4B
>> "%~1" echo KwEWABMEEQQtBTjJAAAACBeNIQAAARMHEQcWHyCdEQcZb4oAAAoNCY5pGTIUCRaa
>> "%~1" echo KHoAAAYsCgkXmih7AAAGKwEWABMEEQQtBTiKAAAACRiacp0wAHAoCwAAChb+ARME
>> "%~1" echo EQQtIwIgrA0AAHKVMQBwCRaacrMBAHAJF5ooSQAACig1AAAGJitQAiCsDQAAHI0R
>> "%~1" echo AAABEwgRCBZyhB0AcKIRCBcJFpqiEQgYcrMBAHCiEQgZCReaohEIGnKzAQBwohEI
>> "%~1" echo GwkYmih+AAAGohEIKBYAAAooNQAABiYAEQYXWBMGEQYRBY5p/gQTBBEEOuz+//8C
>> "%~1" echo IKwNAAByChUAcCg1AAAGJnK3MQBwBigIAAAKKC4AAAYAKgAAEzAEAIQAAAAzAAAR
>> "%~1" echo AAIlLQYmcs4LAHAKBnLHMQBwcssxAHBviwAACnKgHQBwcssxAHBviwAACnLPMQBw
>> "%~1" echo cssxAHBviwAACnKfAQBwcssxAHBviwAACgp+BQAABCguAAAKLQd+BQAABCsKKA0A
>> "%~1" echo AApvDgAACgALB3LTMQBwBnL7MQBwKFEAAAooUgAACgwrAAgqEzAEANcAAAA0AAAR
>> "%~1" echo AAMgxAkAAHIFMgBwKDMAAAYKAnKWEQBwBnIlMgBwKFUAAAZvRwAACgAGcjEyAHAo
>> "%~1" echo VQAABgsHIP8BAAAoVgAAChICKIwAAAosEQgjAAAAAAAAWUD+Ahb+ASsBFwANCS0f
>> "%~1" echo CCMAAAAAAAAkQFsTBBIEckkyAHAoVgAACiiEAAAKCwJywBEAcAdvRwAACgACclEy
>> "%~1" echo AHAGcm0yAHAoVQAABihSAAAGb0cAAAoAAnJ7MgBwBnKXMgBwKFUAAAYoUwAABm9H
>> "%~1" echo AAAKAAJypTIAcAYoVAAABm9HAAAKACoAEzAEAIYAAAAuAAARAAMgiBMAAHK9MgBw
>> "%~1" echo KDMAAAYKAnLoEQBwBnLZMgBwKFYAAAZvRwAACgACcvMyAHAGcvMyAHAoVgAABm9H
>> "%~1" echo AAAKAAJyAzMAcAZyAzMAcChWAAAGb0cAAAoAAnIpMwBwBnJHMwBwKFYAAAZvRwAA
>> "%~1" echo CgACcoEzAHAGcp8zAHAoVwAABm9HAAAKACoAABMwBAC2AQAANQAAEQACcr0zAHBy
>> "%~1" echo uhIAcG9HAAAKAAJy6TMAcHK6EgBwb0cAAAoAAnIXNABwcroSAHBvRwAACgACckE0
>> "%~1" echo AHByuhIAcG9HAAAKAAJybTQAcHKLNABwb0cAAAoAAyCIEwAAcp80AHAoMwAABgpz
>> "%~1" echo HQAACgsABih5AAAGEwcWEwg4+AAAABEHEQiaDAAIbzQAAAoNCXLRNABwG28nAAAK
>> "%~1" echo FjIUCXLjNABwG28nAAAKFv4EFv4BKwEWABMJEQktBTi0AAAACXLvNABwKFgAAAYT
>> "%~1" echo BAly+TQAcChYAAAGEwUJcgk1AHAoWAAABhMGEQRyFzUAcBtvGAAAChb+ARMJEQkt
>> "%~1" echo HgACcr0zAHARBW9HAAAKAAJyFzQAcBEGb0cAAAoAABEEciE1AHAbbxgAAAoW/gET
>> "%~1" echo CREJLR4AAnLpMwBwEQVvRwAACgACckE0AHARBm9HAAAKAAAHCW8xAAAKIIwAAAAw
>> "%~1" echo AwkrDAkWIIwAAABvMwAACgBvJgAACgAAEQgXWBMIEQgRB45p/gQTCREJOvf+//8H
>> "%~1" echo bx4AAAoW/gIW/gETCREJLRwCcm00AHBy3B8AcAdvWgAACihbAAAKb0cAAAoAKgAA
>> "%~1" echo EzAGAHIBAAA2AAARAAJyLTUAcHK6EgBwb0cAAAoAAnI9NQBwcroSAHBvRwAACgAD
>> "%~1" echo IKwNAABySzUAcCgzAAAGCgAGKHkAAAYTBxYTCDinAAAAEQcRCJoLAAdvNAAACgwI
>> "%~1" echo bzEAAAosEQhyZzUAcBtvOwAAChb+ASsBFgATCREJLQIrcAgYjSEAAAETChEKFh8g
>> "%~1" echo nREKFx8JnREKF2+IAAAKDQmOaRv+BBMJEQktRQACci01AHAbjREAAAETCxELFgkY
>> "%~1" echo mqIRCxdyGiAAcKIRCxgJF5qiEQsZcn01AHCiEQsaCRqaohELKBYAAApvRwAACgAr
>> "%~1" echo GAARCBdYEwgRCBEHjmn+BBMJEQk6SP///wMgrA0AAHKHNQBwKDMAAAYTBBEEcqs1
>> "%~1" echo AHAoWgAABhMFEQRyvzUAcChaAAAGEwYRBXK6EgBwKCUAAAosEREGcroSAHAoJQAA
>> "%~1" echo Chb+ASsBFwATCREJLR8Ccj01AHBy2zUAcBEGcuM1AHARBShJAAAKb0cAAAoAKgAA
>> "%~1" echo EzAEAJwAAAAkAAARAAJy8TUAcHK6EgBwb0cAAAoAAnIFNgBwcroSAHBvRwAACgBy
>> "%~1" echo GTYAcAoDIIgTAABySykAcAYoCAAACigzAAAGCwdyRzYAcAZylwYAcChRAAAKG28n
>> "%~1" echo AAAKFv4EFv4BDQktAis4AnLxNQBwBm9HAAAKAAdyWzYAcChZAAAGDAhyuhIAcCgl
>> "%~1" echo AAAKFv4BDQktDQJyBTYAcAhvRwAACgAqEzAEAFABAAA3AAARAAJydTYAcHK6EgBw
>> "%~1" echo b0cAAAoAAyCIEwAAcpM2AHAoMwAABgoGcrM2AHAoVwAABgsHcroSAHAoCwAAChb+
>> "%~1" echo ARMHEQctBTgHAQAAB3LXNgBwKF4AAAYMB3IHNwBwKF4AAAYNB3I/NwBwKF4AAAYT
>> "%~1" echo BAdyZTcAcHKVNwBwKF0AAAYTBXMdAAAKEwYIcroSAHAoJQAAChb+ARMHEQctGBEG
>> "%~1" echo CHKzAQBwcvUFAHBviwAACm8mAAAKAAlyuhIAcCglAAAKFv4BEwcRBy0TEQYJcpk3
>> "%~1" echo AHAoCAAACm8mAAAKABEEcroSAHAoJQAAChb+ARMHEQctFBEGcp83AHARBCgIAAAK
>> "%~1" echo byYAAAoAEQVyuhIAcCglAAAKFv4BEwcRBy0KEQYRBW8mAAAKAAJydTYAcBEGbx4A
>> "%~1" echo AAosE3IaIABwEQZvWgAACihbAAAKKwVyuhIAcABvRwAACgAqEzAHALkAAAAkAAAR
>> "%~1" echo AAJysTcAcHK6EgBwb0cAAAoAAyCIEwAAcs83AHAoMwAABgoGcv03AHAoVQAABgsG
>> "%~1" echo chs4AHAoXwAABgwIcroSAHAoCwAAChb+AQ0JLQwGcl84AHAoXwAABgwHcroSAHAo
>> "%~1" echo JQAACi0QCHK6EgBwKCUAAAoW/gErARYADQktPAJysTcAcHKdOABwBwhyuhIAcCgl
>> "%~1" echo AAAKLQdy9QUAcCsQcq04AHAIcsU4AHAoUQAACgAoUQAACm9HAAAKACoAAAATMAQA
>> "%~1" echo SgEAADcAABEAAnLJOABwcroSAHBvRwAACgADIHAXAABy5zgAcCgzAAAGCgZyEAQA
>> "%~1" echo cChgAAAGCwZy7AMAcChgAAAGDAZyMgQAcChgAAAGDQZybgQAcChgAAAGEwQGco4E
>> "%~1" echo AHAoYAAABhMFcx0AAAoTBghyuhIAcCglAAAKFv4BEwcRBy0JEQYIbyYAAAoAB3K6
>> "%~1" echo EgBwKCUAAAoW/gETBxEHLQkRBgdvJgAACgAJcroSAHAoJQAAChb+ARMHEQctExEG
>> "%~1" echo chM5AHAJKAgAAApvJgAACgARBHK6EgBwKCUAAAoW/gETBxEHLRQRBnIlOQBwEQQo
>> "%~1" echo CAAACm8mAAAKABEFcroSAHAoJQAAChb+ARMHEQctFBEGci85AHARBSgIAAAKbyYA
>> "%~1" echo AAoAAnLJOABwEQZvHgAACiwTchogAHARBm9aAAAKKFsAAAorBXK6EgBwAG9HAAAK
>> "%~1" echo ACoAABMwBwDoAgAAOAAAEQBzkQAABgoGKE0AAAoMEgJyMTEAcChOAAAKfRkAAAQG
>> "%~1" echo An0aAAAEBgN9GwAABAZyQTkAcCCgDwAAFhiNEQAAAQ0JFnJ9LgBwogkXco0uAHCi
>> "%~1" echo CShFAAAGAAZyWTkAcAIguAsAAHJZOQBwKEQAAAYABnJfOQBwAiBwFwAAcl85AHAo
>> "%~1" echo RAAABgAGcm85AHACIHAXAAByjzkAcChEAAAGAAZyuTkAcAIgcBcAAHLZOQBwKEQA
>> "%~1" echo AAYABnIDOgBwAiBwFwAAciM6AHAoRAAABgAGck06AHACIIgTAAByBTIAcChEAAAG
>> "%~1" echo AAZyXToAcAIgWBsAAHK9MgBwKEQAAAYABnJpOgBwAiAoIwAAcpM2AHAoRAAABgAG
>> "%~1" echo cuoWAHACIFgbAAByeToAcChEAAAGAAZykToAcAIgKCMAAHKbOgBwKEQAAAYABnK1
>> "%~1" echo OgBwAiBAHwAAcs86AHAoRAAABgAGcvk6AHACIFgbAAByDTsAcChEAAAGAAZyQTsA
>> "%~1" echo cAIgQB8AAHJPOwBwKEQAAAYABnJ5OwBwAiDgLgAAcuc4AHAoRAAABgAGcpU7AHAC
>> "%~1" echo IFgbAAByzzcAcChEAAAGAAZypTsAcAIgWBsAAHKxOwBwKEQAAAYABnLNOwBwAiDg
>> "%~1" echo LgAAct87AHAoRAAABgAGcg08AHACIEAfAAByHzwAcChEAAAGAAZyQTwAcAIgQB8A
>> "%~1" echo AHJVPABwKEQAAAYABnKLPABwAiCIEwAAcpE8AHAoRAAABgAGcrk8AHACIIgTAABy
>> "%~1" echo hzUAcChEAAAGAAZyyTwAcAIgiBMAAHLZPABwKEQAAAYABnL9PABwAiC4CwAAcgk9
>> "%~1" echo AHAoRAAABgAGchs9AHACIIgTAAByKz0AcChEAAAGAAZyOz0AcAIgiBMAAHJNPQBw
>> "%~1" echo KEQAAAYABnJfPQBwAiBAHwAAcn09AHAoRAAABgAGcss9AHACIBAnAABy6z0AcChE
>> "%~1" echo AAAGAAZyIT4AcAIgECcAAHJJPgBwKEQAAAYABihHAAAGAAYLKwAHKhMwBwAtAAAA
>> "%~1" echo OQAAEQACAwUWGo0RAAABCgYWckIWAHCiBhcEogYYcqcwAHCiBhkOBKIGKEUAAAYA
>> "%~1" echo KgAAABMwBAAWAQAAOgAAEQAojQAACgp+AgAABA4EBChNAAAGCwZvjgAACgBzkAAA
>> "%~1" echo BgwIA30SAAAECHJ/KABwDgQoTwAABigIAAAKfRMAAAQIB3sOAAAEKHgAAAZ9FAAA
>> "%~1" echo BAgHew8AAAQoeAAABn0VAAAECAd7EAAABH0WAAAECAd7EQAABH0XAAAECAZvjwAA
>> "%~1" echo Cn0YAAAEAnsdAAAECG+QAAAKAAd7EQAABBb+AQ0JLRkCex4AAAQDcm0+AHAoCAAA
>> "%~1" echo Cm8mAAAKACtcB3sQAAAELAYFFv4BKwEXAA0JLSQCex4AAAQDcnU+AHAHb40AAAYo
>> "%~1" echo eAAABihRAAAKbyYAAAoAKyQHexAAAAQW/gENCS0XAnseAAAEA3J/PgBwKAgAAApv
>> "%~1" echo JgAACgAqAAAbMAIAVwAAADsAABEAAAJ7HQAABG+RAAAKDCsfEgIokgAACgoGexIA
>> "%~1" echo AAQDKAsAAAoW/gENCS0EBgveJRICKJMAAAoNCS3W3g8SAv4WBwAAG28kAAAKANwA
>> "%~1" echo c5AAAAYLKwAAByoAARAAAAIADgAuPAAPAAAAABMwBQCUBgAAPAAAEQACexwAAAQK
>> "%~1" echo AnJfOQBwKEYAAAZvjwAABgsCck06AHAoRgAABm+PAAAGDAJyXToAcChGAAAGb48A
>> "%~1" echo AAYNAnJpOgBwKEYAAAZvjwAABhMEAnKVOwBwKEYAAAZvjwAABhMFAnJ5OwBwKEYA
>> "%~1" echo AAZvjwAABhMGAnKROgBwKEYAAAZvjwAABhMHAnL5OgBwKEYAAAZvjwAABhMIAnLq
>> "%~1" echo FgBwKEYAAAZvjwAABhMJAnJBOwBwKEYAAAZvjwAABhMKAnLNOwBwKEYAAAZvjwAA
>> "%~1" echo BhMLAnINPABwKEYAAAZvjwAABhMMBnL+CwBwAnsaAAAEb0cAAAoABnKaCwBwAnsb
>> "%~1" echo AAAEb0cAAAoABnKPPgBwAnsZAAAEb0cAAAoABnIMDABwB3IYDABwKFsAAAZvRwAA
>> "%~1" echo CgAGcgoNAHAHciQNAHAoWwAABm9HAAAKAAZyVA0AcAdyYA0AcChbAAAGb0cAAAoA
>> "%~1" echo BnKfPgBwB3KaDQBwKFsAAAZvRwAACgAGcs4LAHAHctYNAHAoWwAABm9HAAAKAAZy
>> "%~1" echo +g0AcAdyBg4AcChbAAAGb0cAAAoABnIoDgBwB3IwDgBwKFsAAAYHclgOAHAoWwAA
>> "%~1" echo BihRAAAGb0cAAAoABnI6DABwB3JKDABwKFsAAAZvRwAACgAGcnwMAHAHcoQMAHAo
>> "%~1" echo WwAABm9HAAAKAAZyrgwAcAdyygwAcChbAAAGb0cAAAoABnI+DwBwB3JWDwBwKFsA
>> "%~1" echo AAZvRwAACgAGcnIOAHAHcoIOAHAoWwAABm9HAAAKAAZy4g4AcAdyBA8AcChbAAAG
>> "%~1" echo b0cAAAoABnKqDgBwB3LCDgBwKFsAAAZvRwAACgAGcq8+AHAHcsc+AHAoWwAABm9H
>> "%~1" echo AAAKAAZylA8AcAdynA8AcChbAAAGb0cAAAoABnLxPgBwAnL9PABwKEYAAAZvjwAA
>> "%~1" echo BihcAAAGb0cAAAoABnKWEQBwCHIlMgBwKFUAAAZy/z4AcCgIAAAKb0cAAAoACHIx
>> "%~1" echo MgBwKFUAAAYTDRENIP8BAAAoVgAAChIOKIwAAAosEhEOIwAAAAAAAFlA/gIW/gEr
>> "%~1" echo ARcAEw8RDy0hEQ4jAAAAAAAAJEBbExASEHJJMgBwKFYAAAoohAAAChMNBnLAEQBw
>> "%~1" echo EQ1yuhIAcCgLAAAKLQ4RDXLFOABwKAgAAAorBXK6EgBwAG9HAAAKAAZyezIAcAhy
>> "%~1" echo lzIAcChVAAAGKFMAAAZvRwAACgAGcqUyAHAIKFQAAAZvRwAACgAGcugRAHAJctky
>> "%~1" echo AHAoVgAABm9HAAAKAAZyPhAAcAly8zIAcChWAAAGb0cAAAoABnIDPwBwCXIDMwBw
>> "%~1" echo KFYAAAZvRwAACgAGci01AHACcos8AHAoRgAABm+PAAAGKGMAAAZvRwAACgAGcj01
>> "%~1" echo AHACcrk8AHAoRgAABm+PAAAGKGQAAAZvRwAACgAGchc/AHACcsk8AHAoRgAABm+P
>> "%~1" echo AAAGKGUAAAZvRwAACgAGcmk6AHARBChmAAAGb0cAAAoABnIfPwBwEQRyKz8AcChX
>> "%~1" echo AAAGcmU3AHBylTcAcChdAAAGb0cAAAoABnKVOwBwEQUoZwAABm9HAAAKAAZy6hYA
>> "%~1" echo cBEJKGgAAAZvRwAACgAGcpE6AHARBwJyGz0AcChGAAAGb48AAAYoaQAABm9HAAAK
>> "%~1" echo AAZy+ToAcBEIKGoAAAZvRwAACgAGckE7AHARChEGKGsAAAZvRwAACgAGck8/AHAR
>> "%~1" echo BihsAAAGb0cAAAoABnJfPwBwEQZy7AMAcChgAAAGb0cAAAoABnJ7PwBwEQZyEAQA
>> "%~1" echo cChgAAAGb0cAAAoABnKVPwBwEQZyMgQAcChgAAAGb0cAAAoABnKtPwBwEQZybgQA
>> "%~1" echo cChgAAAGb0cAAAoABnLNPwBwEQZyjgQAcChgAAAGb0cAAAoABnLrPwBwEQZyEUAA
>> "%~1" echo cChgAAAGb0cAAAoABnIrQABwEQZyQ0AAcChgAAAGb0cAAAoABnJbQABwEQZye0AA
>> "%~1" echo cChgAAAGb0cAAAoABnKTQABwEQZyuUAAcChgAAAGb0cAAAoABnLbQABwEQZy/0AA
>> "%~1" echo cBtvJwAAChYvB3K6EgBwKwVyL0EAcABvRwAACgAGcs07AHARCyhuAAAGExESEShW
>> "%~1" echo AAAKKFkAAApvRwAACgAGcg08AHARDHJnQQBwKG8AAAYTERIRKFYAAAooWQAACm9H
>> "%~1" echo AAAKAAZyeUEAcAJyXz0AcChGAAAGb48AAAYobQAABm9HAAAKAAZyyh8AcAJ7HgAA
>> "%~1" echo BG8eAAAKLBdy3B8AcAJ7HgAABG9aAAAKKFsAAAorBXK6EgBwAG9HAAAKACoTMAcA
>> "%~1" echo 3wYAAD0AABEAAnscAAAECgMtB3J/QQBwKwVysUEAcAALAy0HcuNBAHArBXL9QQBw
>> "%~1" echo AAxyE0IAcChNAAAKEwcSB3IfQgBwKFYAAAoolAAACigIAAAKDQZy/gsAcChxAAAG
>> "%~1" echo AyhzAAAGEwRzegAAChMFEQVyP0IAcAcocgAABnJSQwBwKFEAAApvewAACiYRBXJk
>> "%~1" echo QwBwb3sAAAomEQUbjREAAAETCBEIFnJ0QwBwohEIFwMtB3IpUQBwKwVyQVEAcACi
>> "%~1" echo EQgYclVRAHCiEQgZAy0HcilRAHArBXJBUQBwAKIRCBpyZVEAcKIRCCgWAAAKb3sA
>> "%~1" echo AAomEQVybmwAcG97AAAKJhEFcppsAHBvewAACiYRBXI1bgBwb3sAAAomEQVygW4A
>> "%~1" echo cG97AAAKJhEFHwuNEQAAARMIEQgWckRwAHCiEQgXCShyAAAGohEIGHLCcABwohEI
>> "%~1" echo GQZyjz4AcChxAAAGKHIAAAaiEQgacixxAHCiEQgbCChyAAAGohEIHHK5cQBwohEI
>> "%~1" echo HQZyYgsAcChxAAAGKHIAAAaiEQgecj5yAHCiEQgfCQZyYgsAcChxAAAGKHQAAAYo
>> "%~1" echo cgAABqIRCB8KckRyAHCiEQgoFgAACm97AAAKJhEFHxGNEQAAARMIEQgWcnxyAHCi
>> "%~1" echo EQgXBnIMDABwKHEAAAYocgAABqIRCBhyPXMAcKIRCBkGcgoNAHAocQAABihyAAAG
>> "%~1" echo ohEIGnIaIABwohEIGwZynz4AcChxAAAGKHIAAAaiEQgcchogAHCiEQgdBnLOCwBw
>> "%~1" echo KHEAAAYocgAABqIRCB5ycXMAcKIRCB8JEQQocgAABqIRCB8KctlzAHCiEQgfCwZy
>> "%~1" echo OgwAcChxAAAGKHIAAAaiEQgfDHIPdABwohEIHw0GcnwMAHAocQAABihyAAAGohEI
>> "%~1" echo Hw5y2XMAcKIRCB8PBnIoDgBwKHEAAAYocgAABqIRCB8Qch90AHCiEQgoFgAACm97
>> "%~1" echo AAAKJhEFG40RAAABEwgRCBZyU3QAcKIRCBcDLQdy4HQAcCsFcux0AHAAKHIAAAai
>> "%~1" echo EQgYcj1zAHCiEQgZAy0Hcvh0AHArBXIsdQBwAChyAAAGohEIGnKqdQBwohEIKBYA
>> "%~1" echo AApvewAACiYRBR8LjREAAAETCBEIFnIBdwBwohEIFwZylhEAcChxAAAGKHIAAAai
>> "%~1" echo EQgYchogAHCiEQgZBnLAEQBwKHEAAAYocgAABqIRCBpykHcAcKIRCBsGcmk6AHAo
>> "%~1" echo cQAABihyAAAGohEIHHL2dwBwohEIHQZyLTUAcChxAAAGKHIAAAaiEQgeclx4AHCi
>> "%~1" echo EQgfCQZyTz8AcChxAAAGKHIAAAaiEQgfCnLCeABwohEIKBYAAApvewAACiYRBXLs
>> "%~1" echo eABwBgMfCo0RAAABEwgRCBZy9ngAcKIRCBdyOHkAcKIRCBhyfHkAcKIRCBlyzHkA
>> "%~1" echo cKIRCBpyAHoAcKIRCBtyNHoAcKIRCBxybnoAcKIRCB1yqnoAcKIRCB5y3noAcKIR
>> "%~1" echo CB8Jcgh7AHCiEQgoSQAABgARBXI+ewBwBgMfCY0RAAABEwgRCBZySnsAcKIRCBdy
>> "%~1" echo ensAcKIRCBhymnsAcKIRCBly1HsAcKIRCBpyFHwAcKIRCBtyRnwAcKIRCBxykHwA
>> "%~1" echo cKIRCB1yxnwAcKIRCB5yBn0AcKIRCChJAAAGABEFcjR9AHAGAx8RjREAAAETCBEI
>> "%~1" echo FnJWfQBwohEIF3KQfQBwohEIGHLGfQBwohEIGXIGfgBwohEIGnJIfgBwohEIG3KO
>> "%~1" echo fgBwohEIHHLMfgBwohEIHXIKfwBwohEIHnJUfwBwohEIHwlynn8AcKIRCB8KcuR/
>> "%~1" echo AHCiEQgfC3IMgABwohEIHwxyUIAAcKIRCB8Ncp6AAHCiEQgfDnIEgQBwohEIHw9y
>> "%~1" echo JoEAcKIRCB8QclaBAHCiEQgoSQAABgARBXKCgQBwBgMfCo0RAAABEwgRCBZytoEA
>> "%~1" echo cKIRCBdyFoIAcKIRCBhycoIAcKIRCBly3IIAcKIRCBpyQoMAcKIRCBtypIMAcKIR
>> "%~1" echo CBxyEoQAcKIRCB1ycIQAcKIRCB5y1oQAcKIRCB8JckyFAHCiEQgoSQAABgARBXLE
>> "%~1" echo hQBwb3sAAAomEQVyQ4cAcAYDGo0RAAABEwgRCBZyUYcAcKIRCBdyjYcAcKIRCBhy
>> "%~1" echo 14cAcKIRCBlyS4gAcKIRCChJAAAGABEFAgMoSgAABgARBR2NEQAAARMIEQgWcomI
>> "%~1" echo AHCiEQgXBnLNOwBwKHEAAAYocgAABqIRCBhyaooAcKIRCBkGcg08AHAocQAABihy
>> "%~1" echo AAAGohEIGnK6igBwohEIGwMtB3IGiwBwKwVyFosAcAAocgAABqIRCBxyLIsAcKIR
>> "%~1" echo CCgWAAAKb3sAAAomEQVyYIsAcG97AAAKJhEFb3wAAAoTBisAEQYqABMwBAAKAQAA
>> "%~1" echo PgAAEQACcpiLAHADKHIAAAZy1IsAcChRAAAKb3sAAAomAA4EEwYWEwc4wgAAABEG
>> "%~1" echo EQeaCgAGF40hAAABEwgRCBYffJ0RCBlvigAACgsHFpoMB45pFzADCCsDBxeaAA0H
>> "%~1" echo jmkYMAdymYwAcCsDBxiaABMEBAgocQAABhMFBRb+ARMJEQktChEFFyhzAAAGEwUC
>> "%~1" echo HY0RAAABEwoRChZyoYwAcKIRChcJKHIAAAaiEQoYcrOMAHCiEQoZEQUocgAABqIR
>> "%~1" echo Chpys4wAcKIRChsRBChyAAAGohEKHHLHjABwohEKKBYAAApvewAACiYAEQcXWBMH
>> "%~1" echo EQcRBo5p/gQTCREJOi3///8Cct2MAHBvewAACiYqAAAbMAUAZQEAAD8AABEAAnIT
>> "%~1" echo jQBwb3sAAAomAAN7HQAABG+RAAAKDDgZAQAAEgIokgAACgoABCwWBnsSAAAEcneN
>> "%~1" echo AHAbbycAAAoW/gQrARcADQktBTjsAAAABm+PAAAGCwQW/gENCS0IBwModgAABgsH
>> "%~1" echo bzEAAAogYOoAAP4CFv4BDQktFwcWIGDqAABvMwAACnKFjQBwKAgAAAoLAh8KjREA
>> "%~1" echo AAETBBEEFnK3jQBwohEEFwZ7EgAABChyAAAGohEEGHLdjQBwohEEGQZ8GAAABChW
>> "%~1" echo AAAKKFcAAAoocgAABqIRBBpy5Y0AcKIRBBsGfBYAAAQoVgAACihZAAAKKHIAAAai
>> "%~1" echo EQQcBnsXAAAELQdy9QUAcCsFcvuNAHAAohEEHXIRjgBwohEEHgcocgAABqIRBB8J
>> "%~1" echo cjGOAHCiEQQoFgAACm97AAAKJgASAiiTAAAKDQk62f7//94PEgL+FgcAABtvJAAA
>> "%~1" echo CgDcAAJyU44AcG97AAAKJioAAABBHAAAAgAAABoAAAAuAQAASAEAAA8AAAAAAAAA
>> "%~1" echo EzADANsAAABAAAARAAIgxAkAAHJpjgBwKDMAAAYKBnK6EgBwKCUAAAosEAZyo44A
>> "%~1" echo cCglAAAKFv4BKwEXABMHEQctCAYTBjiYAAAAAAIgxAkAAHKzjgBwKDMAAAYoeQAA
>> "%~1" echo BhMIFhMJK2QRCBEJmgsAB280AAAKDAhy6Y4AcG+VAAAKDQkW/gQTBxEHLTkACAkb
>> "%~1" echo WG82AAAKbzQAAAoTBBEEHy9vMgAAChMFEQUW/gIW/gETBxEHLQ4RBBYRBW8zAAAK
>> "%~1" echo EwbeHwAAEQkXWBMJEQkRCI5p/gQTBxEHLY5yuhIAcBMGKwAAEQYqABMwAwAYAAAA
>> "%~1" echo LgAAEQACAwQoTQAABm+NAAAGKHgAAAYKKwAGKh4CKH8AAAoqHgIofwAACioLMAIA
>> "%~1" echo LAAAAAAAAAAAAAJ7LgAABHstAAAEAnsvAAAEb5YAAApvlwAACn0OAAAEAN4FJgAA
>> "%~1" echo 3gAAKgEQAAAAAAEAJCUABQEAAAELMAIALAAAAAAAAAAAAAJ7LgAABHstAAAEAnsv
>> "%~1" echo AAAEb5gAAApvlwAACn0PAAAEAN4FJgAA3gAAKgEQAAAAAAEAJCUABQEAAAEbMAIA
>> "%~1" echo PAEAAEEAABFzmgAABhMFABEFc44AAAZ9LQAABHObAAAGDQkRBX0uAAAEAHOZAAAK
>> "%~1" echo CgYCb5oAAAoABgMoTwAABm+bAAAKAAYWb5wAAAoABhdvnQAACgAGF2+eAAAKAAYX
>> "%~1" echo b58AAAoACQYooAAACn0vAAAECf4GnAAABnOhAAAKc6IAAAoLCf4GnQAABnOhAAAK
>> "%~1" echo c6IAAAoMB2+jAAAKAAhvowAACgAJey8AAAQEb6QAAAoTBxEHLS8AEQV7LQAABBd9
>> "%~1" echo EQAABAAJey8AAARvpQAACgAA3gUmAADeAAARBXstAAAEEwbeWxEFey0AAAQJey8A
>> "%~1" echo AARvpgAACn0QAAAEByDoAwAAb6cAAAomCCDoAwAAb6cAAAomEQV7LQAABBMG3iET
>> "%~1" echo BAARBXstAAAEEQRvBwAACn0PAAAEEQV7LQAABBMG3gAAEQYqQTQAAAAAAAC8AAAA
>> "%~1" echo EAAAAMwAAAAFAAAAAQAAAQAAAAAUAAAAAwEAABcBAAAhAAAAEAAAAR4CKH8AAAoq
>> "%~1" echo HgIofwAACiobMAIAfAAAAEIAABEAACtSAAJ7MgAABHsxAAAEFP4BDAgtPhYLAnsy
>> "%~1" echo AAAEezAAAAQlDRIBKHcAAAoAAAJ7MgAABHsxAAAEBm+oAAAKAADeEAcW/gEMCC0H
>> "%~1" echo CSh4AAAKANwAAAJ7MwAABG+WAAAKb6kAAAolChT+ARb+AQwILZIA3gUmAADeAAAq
>> "%~1" echo ARwAAAIAGQArRAAQAAAAAAAAAQB0dQAFAQAAARswAgB8AAAAQgAAEQAAK1IAAnsy
>> "%~1" echo AAAEezEAAAQU/gEMCC0+FgsCezIAAAR7MAAABCUNEgEodwAACgAAAnsyAAAEezEA
>> "%~1" echo AAQGb6gAAAoAAN4QBxb+AQwILQcJKHgAAAoA3AAAAnszAAAEb5gAAApvqQAACiUK
>> "%~1" echo FP4BFv4BDAgtkgDeBSYAAN4AACoBHAAAAgAZACtEABAAAAAAAAABAHR1AAUBAAAB
>> "%~1" echo GzACAKcBAABDAAARc54AAAYTBxEHBX0xAAAEAHOOAAAGChEHc38AAAp9MAAABHOf
>> "%~1" echo AAAGEwQRBBEHfTIAAAQAc5kAAAoLBwJvmgAACgAHAyhPAAAGb5sAAAoABxZvnAAA
>> "%~1" echo CgAHF2+dAAAKAAcXb54AAAoABxdvnwAACgARBAcooAAACn0zAAAEEQT+BqAAAAZz
>> "%~1" echo oQAACnOiAAAKDBEE/gahAAAGc6EAAApzogAACg0Ib6MAAAoACW+jAAAKABEEezMA
>> "%~1" echo AAQEb6QAAAoTCREJLT8ABhd9EQAABAARBHszAAAEb6UAAAoAAN4FJgAA3gAACCD0
>> "%~1" echo AQAAb6cAAAomCSD0AQAAb6cAAAomBhMI3aIAAAAGEQR7MwAABG+mAAAKfRAAAAQI
>> "%~1" echo INAHAABvpwAACiYJINAHAABvpwAACiYGEwjecxMFAAYRBW8HAAAKfQ8AAAQRB3sx
>> "%~1" echo AAAEFP4BEwkRCS1OAAAWEwYRB3swAAAEJRMKEgYodwAACgAAEQd7MQAABBEFbwcA
>> "%~1" echo AApvqAAACgAA3hQRBhb+ARMJEQktCBEKKHgAAAoA3AAA3gUmAADeAAAABhMI3gAA
>> "%~1" echo EQgqAEFkAAAAAAAAygAAABEAAADbAAAABQAAAAEAAAECAAAAVQEAACoAAAB/AQAA
>> "%~1" echo FAAAAAAAAAAAAAAAUQEAAEYAAACXAQAABQAAAAEAAAEAAAAAIgAAAA4BAAAwAQAA
>> "%~1" echo cwAAABAAAAETMAMASQAAAEQAABEAc3oAAAoKFgsrKQAHFv4CFv4BDQktCQYfIG+D
>> "%~1" echo AAAKJgYCB5ooUAAABm99AAAKJgAHF1gLBwKOaf4EDQktzQZvfAAACgwrAAgqAAAA
>> "%~1" echo IAAJACIAJgB8ADwAPgBeABMwBABdAAAAGAAAEQACFP4BFv4BCwctCHL1jgBwCitH
>> "%~1" echo Ah6NIQAAASXQNAAABCiqAAAKb6sAAAoW/gQW/gELBy0EAgorInL7jgBwAnL7jgBw
>> "%~1" echo cv+OAHBviwAACnL7jgBwKFEAAAoKKwAGKgAAABMwAwBOAAAAGAAAEQACKHgAAAYQ
>> "%~1" echo AAMoeAAABhABAnK6EgBwKAsAAAoW/gELBy0EAworJQNyuhIAcCgLAAAKFv4BCwct
>> "%~1" echo BAIKKw8CcrMBAHADKFEAAAoKKwAGKgAAEzACAGsAAAAYAAARAAJyBY8AcCgLAAAK
>> "%~1" echo Fv4BCwctCHIJjwBwCitOAnIRjwBwKAsAAAotEAJyFY8AcCgLAAAKFv4BKwEWAAsH
>> "%~1" echo LQhyGY8AcAorIwJyIY8AcCgLAAAKFv4BCwctCHIljwBwCisJAih4AAAGCisABioA
>> "%~1" echo EzACAI4AAAAYAAARAAJyBY8AcCgLAAAKFv4BCwctCHItjwBwCitxAnIRjwBwKAsA
>> "%~1" echo AAoW/gELBy0IcjOPAHAKK1cCchWPAHAoCwAAChb+AQsHLQhyOY8AcAorPQJyIY8A
>> "%~1" echo cCgLAAAKFv4BCwctCHI/jwBwCisjAnJFjwBwKAsAAAoW/gELBy0IckmPAHAKKwkC
>> "%~1" echo KHgAAAYKKwAGKgAAEzACAHcAAAAYAAARAAJyT48AcChXAAAGcugLAHBvrAAAChb+
>> "%~1" echo AQsHLQhyZ48AcAorUAJybY8AcChXAAAGcugLAHBvrAAAChb+AQsHLQhyh48AcAor
>> "%~1" echo LAJyj48AcChXAAAGcugLAHBvrAAAChb+AQsHLQhys48AcAorCHK5jwBwCisABioA
>> "%~1" echo EzADAGsAAABFAAARAAACKHkAAAYNFhMEK0UJEQSaCgAGbzQAAAoLBwNyxzEAcCgI
>> "%~1" echo AAAKG287AAAKFv4BEwURBS0WBwNvMQAAChdYbzYAAAooeAAABgzeHAARBBdYEwQR
>> "%~1" echo BAmOaf4EEwURBS2ucroSAHAMKwAACCoAEzADAJMAAABGAAARAAACKHkAAAYTBhYT
>> "%~1" echo BytpEQYRB5oKAAZvNAAACgsHA3LBjwBwKAgAAAoabycAAAoMCBb+BBMIEQgtNwAH
>> "%~1" echo CANvMQAAClgXWG82AAAKDQkfLG8yAAAKEwQRBBYvAwkrCQkWEQRvMwAACgAoeAAA
>> "%~1" echo BhMF3h4AEQcXWBMHEQcRBo5p/gQTCBEILYlyuhIAcBMFKwAAEQUqABMwAwBUAAAA
>> "%~1" echo RQAAEQAAAih5AAAGDRYTBCsuCREEmgoABm80AAAKCwcDG28nAAAKFv4EEwURBS0J
>> "%~1" echo Byh4AAAGDN4cABEEF1gTBBEECY5p/gQTBREFLcVyuhIAcAwrAAAIKhMwAwBlAAAA
>> "%~1" echo RwAAEQADcscxAHAoCAAACgoCBhtvJwAACgsHFv4EFv4BEwURBS0JcroSAHATBCs2
>> "%~1" echo AgcGbzEAAApYbzYAAApvNAAACgwIHyxvMgAACg0JFi8DCCsICBYJbzMAAAoAKHgA
>> "%~1" echo AAYTBCsAEQQqAAAAEzADAGYAAABIAAARAAACKHkAAAYTBBYTBSs+EQQRBZoKAAZv
>> "%~1" echo NAAACgsHAxtvJwAACgwIFv4EEwYRBi0WBwgDbzEAAApYbzYAAAooeAAABg3eHQAR
>> "%~1" echo BRdYEwURBREEjmn+BBMGEQYttHK6EgBwDSsAAAkqAAATMAQAxgAAAEkAABEAAAIo
>> "%~1" echo eQAABhMFFhMGOJYAAAARBREGmgoABm80AAAKCwcDG287AAAKEwcRBy0CK3IHGI0h
>> "%~1" echo AAABEwgRCBYfIJ0RCBcfCZ0RCBdviAAACgwIjmkYMhkIF5og/wEAAChWAAAKEgMo
>> "%~1" echo jAAAChb+ASsBFwATBxEHLSwJIwAAAAAAADBBWxMJEglySTIAcChWAAAKKIQAAApy
>> "%~1" echo zywAcCgIAAAKEwTeIQARBhdYEwYRBhEFjmn+BBMHEQc6Wf///3K6EgBwEwQrAAAR
>> "%~1" echo BCoAABMwBAC/AAAASgAAEQAAAih5AAAGEwQWEwU4kQAAABEEEQWaCgAGbzQAAAoL
>> "%~1" echo csWPAHADcsmPAHAoUQAACgwHCBpvOwAAChb+ARMGEQYtKQcIbzEAAApvNgAACheN
>> "%~1" echo IQAAARMHEQcWH12dEQdvrQAACih4AAAGDd5RBwNywY8AcCgIAAAKGm87AAAKFv4B
>> "%~1" echo EwYRBi0WBwNvMQAAChdYbzYAAAooeAAABg3eIAARBRdYEwURBREEjmn+BBMGEQY6
>> "%~1" echo Xv///3K6EgBwDSsAAAkqABMwAgBSAAAARQAAEQAAAih5AAAGDRYTBCssCREEmgoA
>> "%~1" echo Bih4AAAGCwdyuhIAcCglAAAKFv4BEwURBS0EBwzeHAARBBdYEwQRBAmOaf4EEwUR
>> "%~1" echo BS3HcroSAHAMKwAACCoAABMwBABnAAAAGgAAEQACJS0GJnL1BQBwAxtvJwAACgoG
>> "%~1" echo Fv4EFv4BDQktCHK6EgBwDCs/BgNvMQAAClgKAgQGG2+uAAAKCwcW/gQW/gENCS0P
>> "%~1" echo AgZvNgAACih4AAAGDCsSAgYHBllvMwAACih4AAAGDCsACCoAEzADAEwAAABLAAAR
>> "%~1" echo AAIlLQYmcvUFAHADFyivAAAKCgZvsAAACiwOBm+xAAAKb7IAAAoXMAdyuhIAcCsW
>> "%~1" echo Bm+xAAAKF2+zAAAKb7QAAAooeAAABgALKwAHKhMwAgANAAAALgAAEQACAyheAAAG
>> "%~1" echo CisABioAAAATMAIARQAAACQAABEAAgMoYQAABgoGcroSAHAoJQAAChb+AQ0JLQQG
>> "%~1" echo DCskAihiAAAGCwcCKLUAAAoNCS0KBwMoYQAABgwrCHK6EgBwDCsACCoAAAATMAQA
>> "%~1" echo sAAAAEwAABEAAiUtBiZy9QUAcHL/jgBwAyi2AAAKctOPAHAoUQAAChcorwAACgoG
>> "%~1" echo b7AAAAoW/gEMCC0ZBm+xAAAKF2+zAAAKb7QAAAooeAAABgsrYQIlLQYmcvUFAHBy
>> "%~1" echo /44AcAMotgAACnL/jwBwKFEAAAoXKK8AAAoKBm+wAAAKLQdyuhIAcCsoBm+xAAAK
>> "%~1" echo F2+zAAAKb7QAAAoXjSEAAAENCRYfIp0Jb4UAAAooeAAABgALKwAHKhMwAwBJAAAA
>> "%~1" echo TQAAEQACJS0GJnL1BQBwChYLKxUGcv+OAHBy+44AcG+LAAAKCgcXWAsHGC8UBnL/
>> "%~1" echo jgBwGm8nAAAKFv4EFv4BKwEWAA0JLc0GDCsACCoAAAATMAQA/AAAAE4AABEAAAIo
>> "%~1" echo eQAABhMEFhMFOM4AAAARBBEFmgoABm80AAAKCwdvMQAACiwRB3JnNQBwG287AAAK
>> "%~1" echo Fv4BKwEWABMGEQYtBTiUAAAABxiNIQAAARMHEQcWHyCdEQcXHwmdEQcXb4gAAAoM
>> "%~1" echo CI5pHDIuCAiOaRdZmnInkABwKAsAAAotFwgIjmkXWZpyM5AAcBtvJwAAChb+BCsB
>> "%~1" echo FgArARcAEwYRBi05G40RAAABEwgRCBYIGJqiEQgXchogAHCiEQgYCBeaohEIGXJF
>> "%~1" echo kABwohEIGggamqIRCCgWAAAKDd4gABEFF1gTBREFEQSOaf4EEwYRBjoh////croS
>> "%~1" echo AHANKwAACSoTMAQAWgAAACQAABEAAnKrNQBwKFoAAAYKAnK/NQBwKFoAAAYLBnK6
>> "%~1" echo EgBwKAsAAAosEAdyuhIAcCgLAAAKFv4BKwEXAA0JLQhyuhIAcAwrFHLbNQBwB3Lj
>> "%~1" echo NQBwBihJAAAKDCsACCoAABMwAwBWAAAATwAAEQACclOQAHAobwAABgoCcmeQAHAo
>> "%~1" echo XgAABgsGLRAHcroSAHAoCwAAChb+ASsBFwANCS0IcroSAHAMKxoSAChWAAAKKFkA
>> "%~1" echo AApyp5AAcAcoUQAACgwrAAgqAAATMAQAHwEAAFAAABEAAnKzNgBwKFcAAAYKBnLX
>> "%~1" echo NgBwKF4AAAYLBnIHNwBwKF4AAAYMBnI/NwBwKF4AAAYNBnK7kABwKHAAAAYTBxIH
>> "%~1" echo KFYAAAooWQAAChMEcx0AAAoTBQdyuhIAcCglAAAKFv4BEwgRCC0YEQUHcrMBAHBy
>> "%~1" echo 9QUAcG+LAAAKbyYAAAoACHK6EgBwKCUAAAoW/gETCBEILRMRBQhymTcAcCgIAAAK
>> "%~1" echo byYAAAoACXK6EgBwKCUAAAoW/gETCBEILRMRBXKfNwBwCSgIAAAKbyYAAAoAEQRy
>> "%~1" echo 3ZAAcCglAAAKFv4BEwgRCC0UEQURBHLhkABwKAgAAApvJgAACgARBW8eAAAKLBNy
>> "%~1" echo GiAAcBEFb1oAAAooWwAACisFcroSAHAAEwYrABEGKgATMAQAyQAAAFEAABEAAnL9
>> "%~1" echo NwBwKFUAAAYKAnLvkABwKFUAAAYLAnIbOABwKF8AAAYMcx0AAAoNBnK6EgBwKCUA
>> "%~1" echo AAoW/gETBREFLRIJcp04AHAGKAgAAApvJgAACgAHcroSAHAoJQAAChb+ARMFEQUt
>> "%~1" echo EglyA5EAcAcoCAAACm8mAAAKAAhyuhIAcCglAAAKFv4BEwURBS0XCXINkQBwCHLF
>> "%~1" echo OABwKFEAAApvJgAACgAJbx4AAAosEnIaIABwCW9aAAAKKFsAAAorBXK6EgBwABME
>> "%~1" echo KwARBCoAAAATMAMAugAAAFEAABEAAnIfkQBwKF4AAAYKAnJFkQBwKF4AAAYLAnJt
>> "%~1" echo kQBwKF4AAAYMcx0AAAoNBnK6EgBwKCUAAAoW/gETBREFLRIJcqeRAHAGKAgAAApv
>> "%~1" echo JgAACgAHcroSAHAoJQAAChb+ARMFEQUtEglyvZEAcAcoCAAACm8mAAAKAAhyuhIA
>> "%~1" echo cCglAAAKFv4BEwURBS0ICQhvJgAACgAJbx4AAAosEnIaIABwCW9aAAAKKFsAAAor
>> "%~1" echo BXK6EgBwABMEKwARBCoAABMwAwAzAQAAUgAAEQACctWRAHAoXgAABgoCchOSAHAo
>> "%~1" echo XgAABgsCcj+SAHAoXgAABgwCcm2SAHAoXgAABg0DcpOSAHAoXgAABhMEcx0AAAoT
>> "%~1" echo BREEcroSAHAoJQAAChb+ARMHEQctFBEFcuOSAHARBCgIAAAKbyYAAAoABnK6EgBw
>> "%~1" echo KCUAAAoW/gETBxEHLRMRBXLrkgBwBigIAAAKbyYAAAoAB3K6EgBwKCUAAAoW/gET
>> "%~1" echo BxEHLRMRBQdy/5IAcCgIAAAKbyYAAAoACHK6EgBwKCUAAAoW/gETBxEHLRMRBQhy
>> "%~1" echo B5MAcCgIAAAKbyYAAAoACXK6EgBwKCUAAAoW/gETBxEHLRMRBXIRkwBwCSgIAAAK
>> "%~1" echo byYAAAoAEQVvHgAACiwTchogAHARBW9aAAAKKFsAAAorBXK6EgBwABMGKwARBioA
>> "%~1" echo EzAEAGAAAAAkAAARAAJyHZMAcCheAAAGCgJyRZMAcCheAAAGCwZyuhIAcCgLAAAK
>> "%~1" echo LBAHcroSAHAoCwAAChb+ASsBFwANCS0OAnJrkwBwKFcAAAYMKxRyjZMAcAZyGiAA
>> "%~1" echo cAcoSQAACgwrAAgqEzAEAPEAAABTAAARAAJyn5MAcChwAAAGCgMoYgAABgsHcv+T
>> "%~1" echo AHAocAAABgwHcjWUAHAocAAABg0Hcm2UAHAocAAABhMEcx0AAAoTBQYW/gIW/gET
>> "%~1" echo BxEHLRgRBQaMGAAAAXKllABwKEYAAApvJgAACgAICVgRBFgW/gIW/gETBxEHLVER
>> "%~1" echo BRyNAQAAARMIEQgWcsWUAHCiEQgXCIwYAAABohEIGHLrlABwohEIGQmMGAAAAaIR
>> "%~1" echo CBpyAZUAcKIRCBsRBIwYAAABohEIKBQAAApvJgAACgARBW8eAAAKLBNyGiAAcBEF
>> "%~1" echo b1oAAAooWwAACisFcroSAHAAEwYrABEGKgAAABMwAwAfAQAAUgAAEQACcuwDAHAo
>> "%~1" echo YAAABgoCchAEAHAoYAAABgsCcjIEAHAoYAAABgwCcm4EAHAoYAAABg0Cco4EAHAo
>> "%~1" echo YAAABhMEcx0AAAoTBQZyuhIAcCglAAAKFv4BEwcRBy0JEQUGbyYAAAoAB3K6EgBw
>> "%~1" echo KCUAAAoW/gETBxEHLQkRBQdvJgAACgAIcroSAHAoJQAAChb+ARMHEQctExEFchM5
>> "%~1" echo AHAIKAgAAApvJgAACgAJcroSAHAoJQAAChb+ARMHEQctExEFciU5AHAJKAgAAApv
>> "%~1" echo JgAACgARBHK6EgBwKCUAAAoW/gETBxEHLRQRBXIvOQBwEQQoCAAACm8mAAAKABEF
>> "%~1" echo bx4AAAosE3IaIABwEQVvWgAACihbAAAKKwVyuhIAcAATBisAEQYqABMwAwBaAAAA
>> "%~1" echo VAAAEQACcheVAHAbbycAAAoW/gQW/gEMCC0IcroSAHALKzkCcls2AHAoWQAABgpy
>> "%~1" echo GTYAcAZyuhIAcCgLAAAKLQ1yGiAAcAYoCAAACisFcvUFAHAAKAgAAAoLKwAHKgAA
>> "%~1" echo EzADAEwAAABVAAARABYKAAIoeQAABg0WEwQrKQkRBJoLB280AAAKclmVAHAbbzsA
>> "%~1" echo AAoW/gETBREFLQQGF1gKEQQXWBMEEQQJjmn+BBMFEQUtygYMKwAIKhMwAwBIAAAA
>> "%~1" echo VQAAEQAWCgACKHkAAAYNFhMEKyUJEQSaCwdvNAAACgMbbzsAAAoW/gETBREFLQQG
>> "%~1" echo F1gKEQQXWBMEEQQJjmn+BBMFEQUtzgYMKwAIKhMwAwAcAAAAEAAAEQACJS0GJnL1
>> "%~1" echo BQBwAxcotwAACm+4AAAKCisABioTMAIAIwAAAC4AABEAAgNvTAAACi0HcroSAHAr
>> "%~1" echo DAIDb0gAAAooeAAABgAKKwAGKgATMAEAEQAAAC4AABEAAih4AAAGKLkAAAoKKwAG
>> "%~1" echo KgAAABMwAQAYAAAALgAAEQADLQgCKHgAAAYrBgIodQAABgAKKwAGKhMwAwCvAAAA
>> "%~1" echo VAAAEQACKHgAAAYKBnK6EgBwKAsAAAoW/gEMCC0HBgs4jAAAAAZya5UAcBtvJwAA
>> "%~1" echo Chb+BAwILQhym5UAcAsrcQZy05UAcBtvJwAAChYyEQZy45UAcBtvJwAAChb+BCsB
>> "%~1" echo FwAMCC0IcgGWAHALK0MGcjeWAHAbb2AAAAotEQZyR5YAcBtvYAAAChb+ASsBFgAM
>> "%~1" echo CC0Ick+WAHALKxYGbzEAAAofNP4CDAgtBAYLKwQGCysAByoAEzACADoAAABUAAAR
>> "%~1" echo AAJvtAAACgoGcm2WAHAougAACiwQBnJ5lgBwKLoAAAoW/gErARcADAgtCQYodwAA
>> "%~1" echo BgsrBAYLKwAHKgAAEzAEADoAAAAvAAARAAIUKHYAAAYKBnKFlgBwfg0AAAQtExT+
>> "%~1" echo BosAAAZzuwAACoANAAAEKwB+DQAABCi8AAAKCgYLKwAHKgAAEzAEAO8AAABUAAAR
>> "%~1" echo AAIoeAAABgoDLCIDexoAAAQoLgAACi0VA3saAAAEcroSAHAoJQAAChb+ASsBFwAM
>> "%~1" echo CC0YBgN7GgAABAN7GgAABCh3AAAGb4sAAAoKBnKtlgBwcvuWAHAovQAACgoGch+X
>> "%~1" echo AHByXZcAcCi9AAAKCgZydZcAcHK5lwBwKL0AAAoKBnLLlwBwci+YAHAovQAACgoG
>> "%~1" echo ckOYAHBylZgAcBcovgAACgoGcrGYAHBy/5gAcBcovgAACgoGckWZAHBycZkAcBco
>> "%~1" echo vgAACgoGcp+ZAHBy1ZkAcBcovgAACgoGcgmaAHByN5oAcBcovgAACgoGCysAByoA
>> "%~1" echo EzAFAEoAAAAYAAARAAIoLgAACi0OAm8xAAAKHP4EFv4BKwEWAAsHLQhyY5oAcAor
>> "%~1" echo IwIWGW8zAAAKcnWaAHACAm8xAAAKGVlvNgAACihRAAAKCisABioAABMwAwBBAAAA
>> "%~1" echo GAAAEQACFP4BFv4BCwctCHK6EgBwCisrAnJ9mgBwcvUFAHBviwAACm80AAAKEAAC
>> "%~1" echo bzEAAAosAwIrBXK6EgBwAAorAAYqAAAAEzAEADEAAABWAAARAAIlLQYmcvUFAHBy
>> "%~1" echo fZoAcHL1BQBwb4sAAAoXjSEAAAELBxYfCp0Hby8AAAoKKwAGKgAAABMwAgAvAAAA
>> "%~1" echo IQAAEQACcuYPAHAoCwAACi0aAnLKEABwKAsAAAotDQJyGBEAcCgLAAAKKwEXAAor
>> "%~1" echo AAYqABMwAgBhAAAAJQAAEQACKC4AAAoW/gEMCC0EFgsrTAACDRYTBCsyCREEb4EA
>> "%~1" echo AAoKBiiCAAAKLREGH18uDAYfLi4HBh8t/gErARcADAgtBBYL3hgRBBdYEwQRBAlv
>> "%~1" echo MQAACv4EDAgtwBcLKwAAByoAAAATMAIAigAAACEAABEAAnKiEwBwKAsAAAotdQJy
>> "%~1" echo ehMAcCgLAAAKLWgCcjAWAHAoCwAACi1bAnKCFgBwKAsAAAotTgJykBUAcCgLAAAK
>> "%~1" echo LUECcsoYAHAoCwAACi00AnIqGgBwKAsAAAotJwJyqBQAcCgLAAAKLRoCcvwcAHAo
>> "%~1" echo CwAACi0NAnKsHQBwKAsAAAorARcACisABioAABMwAgCqAAAAGAAAEQACJS0GJnL1
>> "%~1" echo BQBwbzUAAAoKBnL0DwBwKAsAAAo6ggAAAAZyHBAAcCgLAAAKLXUGcoGaAHAoCwAA
>> "%~1" echo Ci1oBnK7mgBwKAsAAAotWwZy4ZoAcCgLAAAKLU4GcgmbAHAoCwAACi1BBnIZmwBw
>> "%~1" echo KAsAAAotNAZyO5sAcCgLAAAKLScGclGbAHAoCwAACi0aBnJ1mwBwKAsAAAotDQZy
>> "%~1" echo pZsAcCgLAAAKKwEXAAsrAAcqAAATMAQALgAAAC4AABEAct+bAHACJS0GJnL1BQBw
>> "%~1" echo ct+bAHBy45sAcG+LAAAKct+bAHAoUQAACgorAAYqAAATMAMAHgAAAAwAABEAc34A
>> "%~1" echo AAoKBnJEHgBwcugLAHBvRwAACgAGCysAByoAABMwAwArAAAADAAAEQAofwAABgoG
>> "%~1" echo ckQeAHBy3AsAcG9HAAAKAAZySh4AcAJvRwAACgAGCysAByoAEzACABsAAAAhAAAR
>> "%~1" echo AAJyAQcAcCiCAAAGfgMAAAQoCwAACgorAAYqABMwBAC0AAAAVwAAEQACcu2bAHBv
>> "%~1" echo vwAAChb+ARMFEQUtCQIXbzYAAAoQAAACF40hAAABEwYRBhYfJp0RBm8vAAAKEwcW
>> "%~1" echo EwgrXREHEQiaCgAGHz1vMgAACgsHFi8DBisIBhYHbzMAAAoADAcWLwdy9QUAcCsJ
>> "%~1" echo BgcXWG82AAAKAA0IKIMAAAYDKAsAAAoW/gETBREFLQoJKIMAAAYTBN4eABEIF1gT
>> "%~1" echo CBEIEQeOaf4EEwURBS2VcvUFAHATBCsAABEEKhMwAwAkAAAALgAAEQACJS0GJnL1
>> "%~1" echo BQBwcvGbAHByswEAcG+LAAAKKF0AAAoKKwAGKnoAAnL1mwBwKAkAAAoDKIYAAAZv
>> "%~1" echo PAAACiiFAAAGACoAEzAEAFsAAABYAAARABuNAQAAAQwIFnI1nABwoggXA6IIGHJ1
>> "%~1" echo nABwoggZBI5pjBgAAAGiCBpym5wAcKIIKBQAAAoKKCsAAAoGbzwAAAoLAgcWB45p
>> "%~1" echo b0UAAAoAAgQWBI5pb0UAAAoAKgAbMAIArgAAAFkAABEAcv2cAHBzwAAACgoXCwAC
>> "%~1" echo b8EAAAoTBCthEgQowgAACgwABxMFEQUtDAZylTcAcG99AAAKJhYLBnL7jgBwb30A
>> "%~1" echo AAoSAijDAAAKKIcAAAZvfQAACnIBnQBwb30AAAoSAijEAAAKKIcAAAZvfQAACnL7
>> "%~1" echo jgBwb30AAAomABIEKMUAAAoTBREFLZLeDxIE/hYIAAAbbyQAAAoA3AAGcgmdAHBv
>> "%~1" echo fQAACm98AAAKDSsACSoAAAEQAAACABcAcokADwAAAAATMAMAFAEAAFoAABEAc3oA
>> "%~1" echo AAoKAAIlLQYmcvUFAHANFhMEONsAAAAJEQRvgQAACgsABx9c/gEW/gETBREFLREG
>> "%~1" echo cg2dAHBvfQAACiY4qwAAAAcfIv4BFv4BEwURBS0RBnL/jgBwb30AAAomOIwAAAAH
>> "%~1" echo Hwr+ARb+ARMFEQUtDgZyE50AcG99AAAKJitwBx8N/gEW/gETBREFLQ4GchmdAHBv
>> "%~1" echo fQAACiYrVAcfCf4BFv4BEwURBS0OBnIfnQBwb30AAAomKzgHHyD+BBb+ARMFEQUt
>> "%~1" echo IgZyJZ0AcG99AAAKBxMGEgZyK50AcCjGAAAKb30AAAomKwgGB2+DAAAKJgARBBdY
>> "%~1" echo EwQRBAlvMQAACv4EEwURBToS////Bm98AAAKDCsACCoTMAMAKwAAAC8AABEAcjGd
>> "%~1" echo AHAKKAkAAAoGKMcAAApvLAAACnI2ywJwfgMAAARviwAACgsrAAcqABMwAgBzAAAA
>> "%~1" echo WwAAEXI3lgBwgAIAAAQoyAAACgoSAHJKywJwKMkAAAqAAwAABCA9IgAAgAQAAARy
>> "%~1" echo 9QUAcIAFAAAEcvUFAHCABgAABHL1BQBwgAcAAARzfwAACoAIAAAEFnPKAAAKgAkA
>> "%~1" echo AARzfwAACoAKAAAEc34AAAqACwAABCoeAih/AAAKKgATMAIAIwAAAC4AABEAAnsO
>> "%~1" echo AAAEbzEAAAoWMAgCew8AAAQrBgJ7DgAABAAKKwAGKrICcvUFAHB9DgAABAJy9QUA
>> "%~1" echo cH0PAAAEAhV9EAAABAIWfREAAAQCKH8AAAoAKhMwAgAjAAAALgAAEQACexQAAARv
>> "%~1" echo MQAAChYwCAJ7FQAABCsGAnsUAAAEAAorAAYqAAMwAgBKAAAAAAAAAAJy9QUAcH0S
>> "%~1" echo AAAEAnL1BQBwfRMAAAQCcvUFAHB9FAAABAJy9QUAcH0VAAAEAhV9FgAABAIWfRcA
>> "%~1" echo AAQCFmp9GAAABAIofwAACgAqAAADMAIASgAAAAAAAAACcvUFAHB9GQAABAJy9QUA
>> "%~1" echo cH0aAAAEAnL1BQBwfRsAAAQCc34AAAp9HAAABAJzywAACn0dAAAEAnMdAAAKfR4A
>> "%~1" echo AAQCKH8AAAoAKgAAAzACAEYAAAAAAAAAAhZ9HwAABAJy9QUAcH0gAAAEAnL1BQBw
>> "%~1" echo fSEAAAQCcvUFAHB9IgAABAJy9QUAcH0jAAAEAnMdAAAKfSQAAAQCKH8AAAoAKgAA
>> "%~1" echo QlNKQgEAAQAAAAAADAAAAHY0LjAuMzAzMTkAAAAABQBsAAAAtBkAACN+AAAgGgAA
>> "%~1" echo 2BUAACNTdHJpbmdzAAAAAPgvAABQywIAI1VTAEj7AgAQAAAAI0dVSUQAAABY+wIA
>> "%~1" echo kAoAACNCbG9iAAAAAAAAAAIAAAFXnaIpCQIAAAD6JTMAFgAAAQAAAFMAAAAPAAAA
>> "%~1" echo NAAAAKEAAAD7AAAAywAAAAEAAAASAAAAAQAAAFsAAAACAAAAAgAAAAIAAAAJAAAA
>> "%~1" echo AQAAAAEAAAACAAAADAAAAAAACgABAAAAAAAGAF0AVgAGAK4AogAGAOoAzwAKABoB
>> "%~1" echo BwEGADQBKgEGAGYBzwAGALwBKgEGAI0DogAGAMQEVgAGACEIVgAGAGcISAgGAFsK
>> "%~1" echo OwoGAHsKOwoGALcKpgoGAOsKOwoGAAwLVgAGACILVgAGADkLVgAGAGALVgAGAHEL
>> "%~1" echo VgAKAKoLnwsKALoLBwEGANYLVgAGAO0LVgAGAAoMVgAKADUMIgwGAE0MpgoPAHQM
>> "%~1" echo AAAGAJkMKgEGALcMVgAKAAgNBwEGADQNVgAGAFsNVgAGAJwNVgAKAKsNVgAGAN4N
>> "%~1" echo VgAGAPANKgEGAPkNKgEGAAQOVgAGACsOpgoGAEQOVgAGAF4OKgEGAGsOKgEGAHUO
>> "%~1" echo KgEGAJMOKgEGAKUOVgAGAOgO0w4GAAkPVgAGAIoPKgEGAJoPKgEGAKYPKgEKAMkP
>> "%~1" echo sw8KANcPsw8GAAsQzwAGABkQVgAGADQQzwAGAEwQpgoGAGYQVgAGAHwRVgAGAKoR
>> "%~1" echo 0w4KALcRIgwGAEkSKgEGAGkSKgEKAJASIgwGABgTpgoGAPcTVgAGADIUOwoGAEEU
>> "%~1" echo VgAGAEcUVgAKAJwUfRQKAKIUfRQKAKgUfRQKALUUfRQKAMcUfRQKADQAfRQKAAMV
>> "%~1" echo fRQKABsVnwsKAEYVfRQbAHQMAAAGAIUVzwAGAJwVVgAGALwVVgAGAMkVogAAAAAA
>> "%~1" echo AQAAAAAAAQABAAAAEAAcAAAABQABAAEAAwAQACoAAAAFAA4AjQADABAANAAAAAUA
>> "%~1" echo EgCPAAMAEAA8AAAABQAZAJEAAwAQAEUAAAAFAB8AkgADARAAgBAAAAUAJQCTAAMB
>> "%~1" echo EADEEAAABQAmAJYAAwEQACQRAAAFACoAmAADARAA5xEAAAUALQCaAAMBEAACEgAA
>> "%~1" echo BQAuAJsAAwEQAEITAAAFADAAngADARAAWxMAAAUAMgCfAAAAAACyEwAABQA0AKIA
>> "%~1" echo EwEAAAEUAAAJATUAogBRgGQACgARAHAAFgARAHgAFgARAH4AGQARAIMAFgARAIsA
>> "%~1" echo FgARAJIAFgAxAJoAHAAxALcAHwAxADsCHAARAEYC4QARAMQKVwIRAFUV1AkGAFgH
>> "%~1" echo FgAGABQHFgAGAF8HGQAGAGgHLgIGAH8HFgAGAIQHFgAGAFgHFgAGABQHFgAGAF8H
>> "%~1" echo GQAGAGgHLgIGAIwHCgAGAJcHFgAGAJ8HFgAGAKYHFgAGALEH4QAGALgHOQIGAMEH
>> "%~1" echo QQIGABEHLgIGABQHFgAGAMoHFgAGANIHFgAGAN4HFgAGAOoHQQIGAA0JNwYGANcQ
>> "%~1" echo OwYGAOcQLgIGAPIQLgIGAAERFgAGADcRPwYGANcQOwYGAEcRLgIGAPsRTAgGABYS
>> "%~1" echo UAgGAKUIVAgGAFYTHAAGAL0JjAgGAG8TkwgGAKUIVAgTAR4Uvwi8IAAAAACRAMEA
>> "%~1" echo IwABAKgjAAAAAJEAxgApAAIASCUAAAAAkQDxAC0AAgCcJQAAAACRAPgAOQAGACgm
>> "%~1" echo AAAAAJEAJAFGAAoA9CwAAAAAkQA7AUwACwDELQAAAACRAEsBVQANAIguAAAAAJEA
>> "%~1" echo XAFeABEA9C4AAAAAkQBzAWUAEwCAMwAAAACRAHoBbgATAKQ7AAAAAJEAgQFlABUA
>> "%~1" echo 4DsAAAAAkQCGAWUAFQBMPgAAAACRAJMBeQAVAKQ+AAAAAJEAnQF/ABcA1D8AAAAA
>> "%~1" echo kQCpAYYAGQD0PwAAAACRAK4BjQAbACRAAAAAAJEAswGUAB0AEEEAAAAAkQDHAZoA
>> "%~1" echo HgBYQQAAAACRANABpAAiADxFAAAAAJEA4AGsACQAvEYAAAAAkQDqAbQAJgDQRwAA
>> "%~1" echo AACRAPwBwAArAIRIAAAAAJEACwLLADAAwEgAAAAAkQATAtIAMgCsSQAAAACRACIC
>> "%~1" echo 2gA0ACBKAAAAAJEALgLaADYAeEoAAAAAkQBSAukAOAAUSwAAAACRAF8C7gA5AMRP
>> "%~1" echo AAAAAJEAaQL7ADwAbFUAAAAAkQB0AgUBPQCgVQAAAACRAH0CCwE+ABhWAAAAAJEA
>> "%~1" echo hQIYAUEAbFYAAAAAkQCOAn8ARQA0WAAAAACRAJUCfwBHAEheAAAAAJEApgIhAUkA
>> "%~1" echo vF4AAAAAkQCuAnkATQCsXwAAAACRAMMCKgFPAOhgAAAAAJEA2QIwAVEAaGEAAAAA
>> "%~1" echo kQDlAjUBUgA8YgAAAACRAPkCOgFTABxjAAAAAJEAAwM1AVQA4GMAAAAAkQAXAz8B
>> "%~1" echo VQBMZAAAAACRACEDPwFWALBkAAAAAJEALgNEAVcA9GQAAAAAkQA8Az8BVwD0ZQAA
>> "%~1" echo AACRAEQDPwFYAIBmAAAAAJEASANEAVkASGcAAAAAkQBUA0gBWQBsagAAAACRAGED
>> "%~1" echo eQBbAJxqAAAAAJEAZgNQAV0A6GoAAAAAkQBuA1cBYAAoawAAAACRAHEDXgFjAEhr
>> "%~1" echo AAAAAJEAcwNXAWUAiGsAAAAAkQB6A14BaAAgbAAAAACRAIADPwFqAPxsAAAAAJEA
>> "%~1" echo mwNlAWsAdG0AAAAAkQCrAz8BbwD0bgAAAACRALkDNQFwAIRvAAAAAJEAxANuAXEA
>> "%~1" echo aHAAAAAAkQDQA24BcwD8cAAAAACRANoDbgF1AMByAAAAAJEA7gNuAXcAQHQAAAAA
>> "%~1" echo kQD8A24BeQDodAAAAACRAA8EbgF7AER2AAAAAJEAHwRuAX0ADHcAAAAAkQAvBG4B
>> "%~1" echo fwBkeAAAAACRAD8EeQGBAFh7AAAAAJEATwSAAYMAlHsAAAAAkQBfBIoBiAC4fAAA
>> "%~1" echo AACRAGoElQGNACx9AAAAAJEAbgSdAY8AzIMAAAAAkQCBBKMBkAC4igAAAACRAJEE
>> "%~1" echo qgGSANCLAAAAAJEAoQS6AZcAYI0AAAAAkQCvBDUBmgBIjgAAAACRALYEwwGbAAyP
>> "%~1" echo AAAAAJEAugTLAZ4A4JEAAAAAkQDNBNQBoQD4kwAAAACRANcE4gGlAGCUAAAAAJEA
>> "%~1" echo 4AQ1AaYAzJQAAAAAkQDpBHkApwAolQAAAACRAPYENQGpAKCVAAAAAJEABAU1AaoA
>> "%~1" echo PJYAAAAAkQASBTUBqwDAlgAAAACRAB4FeQCsADiXAAAAAJEAKQV5AK4A2JcAAAAA
>> "%~1" echo kQA1BXkAsAA4mAAAAACRAD4FeQCyAKyYAAAAAJEARAV5ALQAIJkAAAAAkQBVBXkA
>> "%~1" echo tgD0mQAAAACRAFsFeQC4AMCaAAAAAJEAZAU1AboAIJsAAAAAkQBuBVABuwCUmwAA
>> "%~1" echo AACRAHYFeQC+AOybAAAAAJEAgQV5AMAACJwAAAAAkQCMBXkAwgBcnAAAAACRAJsF
>> "%~1" echo eQDEABidAAAAAJEArQU1AcYAcJ0AAAAAkQDDBTUBxwB4ngAAAACRANIFNQHIAOCe
>> "%~1" echo AAAAAJEA4AU1AckARJ8AAAAAkQDrBTUBygBwoAAAAACRAPoFNQHLAEihAAAAAJEA
>> "%~1" echo CQY1AcwAEKIAAAAAkQAUBnkAzQBQowAAAACRACAGNQHPALyjAAAAAJEAMQZ5ANAA
>> "%~1" echo vKQAAAAAkQA/BjUB0gDopQAAAACRAE4GNQHTAFCmAAAAAJEAZAboAdQAqKYAAAAA
>> "%~1" echo kQB2Bu0B1QD8pgAAAACRAIcG7QHXACSnAAAAAJEAkgbzAdkAVKcAAAAAkQCUBjUB
>> "%~1" echo 2wB0pwAAAACRAJYGKgHcAJinAAAAAJEAngY1Ad4AnKgAAAAAkQCtBjUB3wDkqAAA
>> "%~1" echo AACRALkG/gHgAOCpAAAAAJEAwAY1AeIAOKoAAAAAkQDLBjUB4wCIqgAAAACRANEG
>> "%~1" echo BQLkAMiqAAAAAJEA1wYwAeUABKsAAAAAkQDfBjAB5gB0qwAAAACRAOgGMAHnAAys
>> "%~1" echo AAAAAJEA+AYwAegAxKwAAAAAkQAGBzUB6QAArQAAAACRABEHZQDqACytAAAAAJEA
>> "%~1" echo FAf7AOoAZK0AAAAAkQAaBzAB6wCMrQAAAACRACUHeQDsAEyuAAAAAJEAKwc1Ae4A
>> "%~1" echo fK4AAAAAkQAvBwsC7wCcrgAAAACRADkHFwLxAASvAAAAAJEARAcgAvQA0K8AAAAA
>> "%~1" echo kQBJBzUB9QDwsAAAAACRAE0HRAH2AKexAAAAAIYYUgcqAvYAUCAAAAAAkQCZClIC
>> "%~1" echo 9gBUqAAAAACRADEVzQn3ACixAAAAAJEYtRVXCvgAsLEAAAAAhghxBzEC+ADfsQAA
>> "%~1" echo AACGGFIHKgL4AAyyAAAAAIYIcQcxAvgAPLIAAAAAhhhSByoC+ACUsgAAAACGGFIH
>> "%~1" echo KgL4AOyyAAAAAIYYUgcqAvgAmlYAAAAAhhhSByoC+ACyVgAAAACGAJMQ6QL4AK9X
>> "%~1" echo AAAAAIYAqhDpAvkAolYAAAAAhhhSByoC+gDEVgAAAACGAA0R6QL6AKpWAAAAAIYY
>> "%~1" echo UgcqAvsAwFcAAAAAhgBLEekC+wBsjgAAAACGGFIHKgL8AHSOAAAAAIYYUgcqAvwA
>> "%~1" echo fI4AAAAAhgAnEioC/ADEjgAAAACGADgSKgL8AIiQAAAAAIYYUgcqAvwAkJAAAAAA
>> "%~1" echo hhhSByoC/ACYkAAAAACGAIATKgL8ADyRAAAAAIYAkRMqAvwAAAABAPYHAAABAPsH
>> "%~1" echo AAACAAQIAAADAAkIAAAEABIIAAABAPsHAAACAAQIAAADABIIAAAEABkIAAABADUI
>> "%~1" echo AAABADwIAgACAEMIAAABADwIAAACAHQIAAADAIIIAAAEAIcIAAABADwIAAACAHQI
>> "%~1" echo AAABAJAIAAACAJcIAAABAJ0IAAACAAQIAAABADwIAAACAIIIAAABAKMIAAACAKUI
>> "%~1" echo AAABAKMIAAACAKUIAAABAKcIAAABAK8IAAACALIIAAADALkIAAAEAL0IAAABAK8I
>> "%~1" echo AAACAMMIAAABAKMIAAACAM0IAAABAKMIAAACANIIAAADANsIAAAEAOUIAAAFAM0I
>> "%~1" echo AAABAKMIAAACANIIAAADANsIAAAEAOUIAAAFAO0IAAABAPYIAAACAPsIAAABAKMI
>> "%~1" echo AAACAP8IAAABAKMIAAACAKUIAAABAKMIAAACAKUIAAABAAgJAAABADwIAAACAJcI
>> "%~1" echo AAADAHQIAAABAJcIAAABAA0JAAABAA0JAAACAA8JAAADABIJAAABAA0JAAACABcJ
>> "%~1" echo AAADAB0JAAAEACIJAAABAA0JAAACACoJAAABAA0JAAACAJcIAAABAA0JAAACAC8J
>> "%~1" echo AAADADIJAAAEADoJAAABAEIJAAACADoJAAABAEkJAAACAFEJAAABAFoJAAABAAQI
>> "%~1" echo AAABAF4JAAABAB0JAAABAEIJAAABAEIJAAABAGQJAAABAB0JAgABAGwJAgACAHcJ
>> "%~1" echo AAABAEIJAAACAAQIAAABAEIJAAACAHwJAAADAH8JAAABAEIJAAACAIMJAAADAIsJ
>> "%~1" echo AAABAIMJAAACAPYHAAABAEIJAAACAIMJAAADAIsJAAABAIMJAAACAPYHAAABAEIJ
>> "%~1" echo AAABAJMJAAACAEIJAAADAHwJAAAEAH8JAAABAEIJAAABAEIJAAABAJYJAAACAEIJ
>> "%~1" echo AAABAJYJAAACAEIJAAABAJYJAAACAEIJAAABAJYJAAACAEIJAAABAJYJAAACAEIJ
>> "%~1" echo AAABAJYJAAACAEIJAAABAJYJAAACAEIJAAABAJYJAAACAEIJAAABAEIJAAACAGwJ
>> "%~1" echo AAABAJgJAAACAAQIAAADAEIJAAAEAIMJAAAFAIsJAAABAJgJAAACAAQIAAADAIMJ
>> "%~1" echo AAAEAJ0JAAAFAPYHAAABAJgJAAACAAQIAAABAJgJAAABAJgJAAACAKYJAAABAJMJ
>> "%~1" echo AAACAKsJAAADALEJAAAEAKYJAAAFALMJAAABAJMJAAACAJgJAAADAKYJAAABAEIJ
>> "%~1" echo AAABALgJAAACAPYHAAADAIMJAAABALgJAAACAPYHAAADAIMJAAABALgJAAACAPYH
>> "%~1" echo AAADAIMJAAAEAL0JAAABAPYHAAABAA0JAAABAMQJAAACAKMIAAABAMYJAAABAMYJ
>> "%~1" echo AAABAA0JAAABAB0JAAACAH8JAAABAB0JAAACAH8JAAABAB0JAAACAMgJAAABACoJ
>> "%~1" echo AAACAH8JAAABAB0JAAACAH8JAAABAB0JAAACAH8JAAABAB0JAAACAH8JAAABAB0J
>> "%~1" echo AAABAB0JAAACAM8JAAADANQJAAABAB0JAAACANoJAAABAB0JAAACANoJAAABAB0J
>> "%~1" echo AAACAH8JAAABAB0JAAACAH8JAAABAB0JAAABAOIJAAABAOUJAAABAOkJAAABAO0J
>> "%~1" echo AAABAPUJAAABAP0JAAABAAEKAAACAAYKAAABAA0KAAABABAKAAACABcKAAABABcK
>> "%~1" echo AAABAB0JAAABAB0JAAABAB0JAAACAB4KAAABAB0JAAACANoJAAABAJYJAAACAH8J
>> "%~1" echo AAABAA0JAAABAB0JAAACAKYJAAABAIIIAAABAB0JAAABAB0JAAACAJgJAAABAEIJ
>> "%~1" echo AAABAA0JAAABAA0JAAABAHwJAAABAAQIAAABAJAIAAABAH8JAAABACUKAAABACsK
>> "%~1" echo AAABAC8KAAABAJcIAAACAH8JAAABAA0JAAABAA0JAAACAJYJAAABADwIAAACADEK
>> "%~1" echo AAADADYKAAABAJYJAAABAA0JAAABAKQKAAABAEQVAAABAMEQAAABAMEQAAABAMEQ
>> "%~1" echo AAABAMEQUQBSByoCWQBSByoCYQBSB00CaQBSByoCeQBSByoCIQAGCyoCgQAWCzEC
>> "%~1" echo iQApC3kAEQAwC2ACkQBBC2UCiQBUC2sCmQBsC+kAoQB7C3ECoQCNCzECqQC0C3YC
>> "%~1" echo sQBSB3wCsQDGCyoCkQDMCz8BkQDlC4MCiQApC4gCiQApC44CiQApC+IBmQDzCzUB
>> "%~1" echo iQAbDJUC0QDGC5wCsQA9DKICcQBSB6cC2QBYDK0CDABSByoCDABqDMwCDAB/DNAC
>> "%~1" echo FACNDN8CkQCkDOQC6QDMC+kCFACuDO4C8QDDDCoCiQDLDGsCDADZDAYDiQDdDBID
>> "%~1" echo IQDlDE0CIQD4DE0CIQAWDSMDEQAgDWACEQAqDSgDiQBHDS4DiQBNDTABiQBHDTgD
>> "%~1" echo iQBgDTECiQBxDcwCiQDdDD8DiQB8DUQDiQCGDTECiQCLDTECiQB8DUoDEQGiDU8D
>> "%~1" echo GQFSB+kCGQGvDTECGQG5DTECiQDKDZUCEQDVDVYDHABSB00CKQDjDYMDHADZDAYD
>> "%~1" echo HADoDYsDHABqDMwCOQBSB6EDOQEJDqwDKQANDioCKQATDrIDiQApC9ADJAAZDt0D
>> "%~1" echo JAAiDuUDiQApCwQEQQEyDukAgQBSB+kCJAA4DgwESQFNDjoESQFVDkAEUQFjDlAB
>> "%~1" echo WQGDDkUEiQApC1ABUQFjDnkAaQGYDkwESQGuDlQEcQG9DmAEeQH0DmQEEQFVDmoE
>> "%~1" echo LABqDMwCwQBVDmoEDADoDYsDiQAZD3gEGQEeDzUBGQEvDzUBUQFCD7AEiQBZD7ME
>> "%~1" echo iQBhD5UCUQFqDzUBaQF2DzABaQF9D7kEKQCVD94EkQFSB+kCKQBxDewEEQAqDfAE
>> "%~1" echo mQFSB/gEoQFSB/4EmQFSByoCmQHoDQcFDADnDwwEEQDwD2ACWQF2DzABWQH8DwUC
>> "%~1" echo DABSB38FuQEoEIoFDABAEJAFDAAiDpsFWQFFEKEFaQFFED8BKQAGCyoCyQFUELIF
>> "%~1" echo yQFsC1ICJABaEOIFQQBSByoCQQBuEOsFCQBVDjECQQB5EOsFJABSByoCCQBSByoC
>> "%~1" echo NABSB6cCiQBiEZMGCQFsEZgGQQB5EKUG2QFVDrYGiQCGDdkGaQGDEUwEmQCREUQB
>> "%~1" echo iQBHDf8GaQGdET0HiQBHDUUHiQBZD10H2QGiDWkH6QHBEcMH6QHKESoC6QHPEewE
>> "%~1" echo LADZDAYDLAB/DNACPACNDN8CPACuDO4CSQFVDrYGiQDdDDkI0QBWElgI+QF0EjEC
>> "%~1" echo 0QB+ElgIAQJSByoCAQKhEukCAQKuEukCAQK8El4IAQLQEl4IAQLrEl4IAQIFE14I
>> "%~1" echo 0QDGC2MICQJSB6cCQQFSB2sIQQHGCyoC0QAkE3II0QAwEyoC0QA1E8wCQQEZD3II
>> "%~1" echo NACiEwYD+QGpEzECGQJaFMMIiQBqFM0IiQBhD9MIiQB1FNkGiQDdDCAJMQKiFCgJ
>> "%~1" echo SQK7FO4COQLXFDMJUQJqDMwCUQIiDjkJWQLiFDECCQDsFEcJMQL8FDUBMQITFcIJ
>> "%~1" echo YQJqDMwCaQImFTUBMQJ9FWsCcQJSB6cCMQJZD9kJMQJZD1ABMQJZD+IJiQDKDdMI
>> "%~1" echo QQBSB+kCJAB/DAkKRACNDB0KTACUFd8CTADiFDEKRACuDO4CwQBVDkAEiQKkFbkE
>> "%~1" echo kQLBFVsKkQJVDkAEmQJSB14ILABSByoCCgAEAA0ALgAbAGcKLgAjAHAK4wArAEgC
>> "%~1" echo AwErAEgCIwErAEgCJAELAEgCQwErAEgCYwErAEgCgQErAEgCgwErAEgCoQErAEgC
>> "%~1" echo owErAEgCwwErAEgChAwLAEgCJA0LAEgCQBErAEgCYBErAEgChBELAEgCAQAQAAAA
>> "%~1" echo DwBbArQC8gIMAxkDXAORA7oDxwPsAxIEKwR/BKoEvwTIBMwE0ATmBAwFOQVMBVcF
>> "%~1" echo YgVnBXgFpwW5BfEFIQYnBi4GQwZNBn0GjAadBqsGvgbGBtEG3wbpBvIGCQcgByQH
>> "%~1" echo KQczB00HYwd2B34HkAejB7IHvgfJB9sH6QcDCBgIKgg+CHcIlwieCLcI2AjiCO8I
>> "%~1" echo +AgDCRMJQAlNCVcJXgluCXUJhQmSCaEJsgm4CewJ8wkBCjYKTAphCgMAAQAEAAIA
>> "%~1" echo AAB6BzUCAAB6BzUCAgCNAAMAAgCPAAUAxgLZAn0D1gNxBEcG1AcVCikKUJQAADQA
>> "%~1" echo BIAAAAAAAAAAAAAAAAAAAAAAHAAAAAQAAAAAAAAAAAAAAAEATQAAAAAABAAAAAAA
>> "%~1" echo AAAAAAAAAQBWAAAAAAADAAIABAACAAUAAgAGAAIABwACAAgAAgAJAAIACgACAAsA
>> "%~1" echo AgAMAAIADQACAA8ADgAAAAA8TW9kdWxlPgBRdWVzdEFkYldlYlVpLmV4ZQBRdWVz
>> "%~1" echo dEFkYldlYlVpAENtZFJlc3VsdABDYXB0dXJlAFNuYXBzaG90AEFwa0luZm8AbXNj
>> "%~1" echo b3JsaWIAU3lzdGVtAE9iamVjdABNYXhBcGtCeXRlcwBBZGJQYXRoAFRva2VuAFBv
>> "%~1" echo cnQAUm9vdERpcgBMb2dEaXIATG9nRmlsZQBMb2dMb2NrAFN5c3RlbS5UZXh0AEVu
>> "%~1" echo Y29kaW5nAFV0ZjhOb0JvbQBNYWluAFNlbGZUZXN0AFN5c3RlbS5Db2xsZWN0aW9u
>> "%~1" echo cy5HZW5lcmljAExpc3RgMQBFeHBlY3QARXhwZWN0Q29udGFpbnMAU3lzdGVtLk5l
>> "%~1" echo dC5Tb2NrZXRzAFRjcENsaWVudABTZXJ2ZQBTeXN0ZW0uSU8AU3RyZWFtAFJlYWRS
>> "%~1" echo ZXF1ZXN0SGVhZABTdHJlYW1Cb2R5VG9GaWxlAERyYWluQm9keQBEaWN0aW9uYXJ5
>> "%~1" echo YDIAU3RhdHVzAEFjdGlvbgBMb2dzAEV4cG9ydFJlcG9ydABFeHBvcnRVcmwAU2Vy
>> "%~1" echo dmVFeHBvcnQATEUxNgBMRTMyAFBhcnNlQXBrAEZpbGVTdHJlYW0AUmVhZEZ1bGwA
>> "%~1" echo RXh0cmFjdFppcEVudHJ5AFBhcnNlQXhtbABSZWFkTWFuaWZlc3RBdHRycwBSZWFk
>> "%~1" echo QXR0clN0cmluZwBTYWZlU3RyAFJlYWRTdHJpbmdQb29sAFJlYWRVdGY4U3RyAFJl
>> "%~1" echo YWRVdGYxNlN0cgBVcGxvYWRMb2NrAFVwbG9hZFBhdGhzAFBydW5lVXBsb2FkcwBB
>> "%~1" echo cGtVcGxvYWQAQXBrSW5zdGFsbABTc2VCZWdpbgBTc2VTZW5kAFNzZVN0YWdlAFNz
>> "%~1" echo ZU91dABBcGtJbnN0YWxsU3RyZWFtAFNzZURvbmUASW5zdGFsbGVkVmVyc2lvbkNv
>> "%~1" echo ZGUAVHJhbnNsYXRlSW5zdGFsbEVycm9yAFNhZmVQYWNrYWdlAFNhbml0aXplRGlz
>> "%~1" echo cGxheU5hbWUASHVtYW5TaXplAEZpcnN0TWVhbmluZ2Z1bExpbmUARGVidWdNb2Rl
>> "%~1" echo AENvbnNlcnZhdGl2ZQBDdXJyZW50U2VyaWFsAEluaXRMb2cATG9nAFJlYWRMb2dU
>> "%~1" echo YWlsAFNlbGVjdERldmljZQBQcm9wAFNldHRpbmcAU2gAQQBNdXN0U2gATXVzdEEA
>> "%~1" echo RW5zdXJlQmFja3VwAFN0cmluZ0J1aWxkZXIAV3JpdGVCYWNrdXBMaW5lAFJlc3Rv
>> "%~1" echo cmVCYWNrdXAAQmFja3VwRmlsZQBGaWxsQmF0dGVyeQBGaWxsUG93ZXIARmlsbENv
>> "%~1" echo bnRyb2xsZXJzRmFzdABGaWxsUmVzb3VyY2VzAEZpbGxWaXJ0dWFsRGVza3RvcABG
>> "%~1" echo aWxsRGlzcGxheUxpdGUARmlsbFRoZXJtYWxMaXRlAEZpbGxGYWN0b3J5TGl0ZQBD
>> "%~1" echo b2xsZWN0U25hcHNob3QAQWRkU2hlbGxDYXB0dXJlAEFkZENhcHR1cmUAQ2FwAEZp
>> "%~1" echo bGxTbmFwc2hvdEZpZWxkcwBCdWlsZFJlcG9ydEh0bWwAQWRkSW52b2ljZUZhY3Rz
>> "%~1" echo AEFkZEludm9pY2VSYXcAV2lmaUlwAFJ1bgBSdW5SZXN1bHQAQWN0aW9uYDEAUnVu
>> "%~1" echo U3RyZWFtAEpvaW5BcmdzAFF1b3RlQXJnAEpvaW5Ob25FbXB0eQBCYXR0ZXJ5U3Rh
>> "%~1" echo dHVzAEJhdHRlcnlIZWFsdGgAUG93ZXJTb3VyY2UAQWZ0ZXJDb2xvbgBBZnRlckVx
>> "%~1" echo dWFscwBGaW5kTGluZQBGaWVsZABGaW5kUGFja2FnZUZpZWxkAE1lbUdiAFByb3BG
>> "%~1" echo cm9tAEZpcnN0TGluZQBCZXR3ZWVuAFJlZ2V4VmFsdWUARmlyc3RSZWdleABFeHRy
>> "%~1" echo YWN0SnNvbmlzaABFeHRyYWN0SnNvbmlzaFJhdwBOb3JtYWxpemVFbWJlZGRlZEpz
>> "%~1" echo b24AU3RvcmFnZVN1bW1hcnkATWVtb3J5U3VtbWFyeQBDcHVTdW1tYXJ5AERpc3Bs
>> "%~1" echo YXlTdW1tYXJ5AFRoZXJtYWxTdW1tYXJ5AFVzYlN1bW1hcnkAV2lmaVN1bW1hcnkA
>> "%~1" echo Qmx1ZXRvb3RoU3VtbWFyeQBDYW1lcmFTdW1tYXJ5AEZhY3RvcnlTdW1tYXJ5AFZp
>> "%~1" echo cnR1YWxEZXNrdG9wU3VtbWFyeQBDb3VudFBhY2thZ2VMaW5lcwBDb3VudFByZWZp
>> "%~1" echo eExpbmVzAENvdW50UmVnZXgAVgBIAFByaXZhY3kAQWRiU291cmNlTGFiZWwAUmVk
>> "%~1" echo YWN0TG9vc2UAUmVkYWN0AFNlcmlhbE1hc2sAQ2xlYW4ATGluZXMAVmFsaWROcwBT
>> "%~1" echo YWZlTmFtZQBEYW5nZXJvdXNBY3Rpb24ARGVuaWVkU2V0dGluZwBTaGVsbFF1b3Rl
>> "%~1" echo AE9rAEVycm9yAENoZWNrVG9rZW4AUXVlcnkAVXJsAFdyaXRlSnNvbgBXcml0ZUJ5
>> "%~1" echo dGVzAEpzb24ARXNjAEh0bWwALmN0b3IAT3V0cHV0AEV4aXRDb2RlAFRpbWVkT3V0
>> "%~1" echo AGdldF9UZXh0AFRleHQATmFtZQBDb21tYW5kAER1cmF0aW9uTXMAQ3JlYXRlZABT
>> "%~1" echo ZXJpYWwARGV2aWNlTGluZQBGaWVsZHMAQ2FwdHVyZXMAV2FybmluZ3MAUGFja2Fn
>> "%~1" echo ZQBWZXJzaW9uTmFtZQBWZXJzaW9uQ29kZQBQZXJtaXNzaW9ucwBhcmdzAGZhaWx1
>> "%~1" echo cmVzAG5hbWUAZXhwZWN0ZWQAYWN0dWFsAG5lZWRsZXMAUGFyYW1BcnJheUF0dHJp
>> "%~1" echo YnV0ZQBjbGllbnQAc3RyZWFtAGhlYWQAU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNl
>> "%~1" echo cnZpY2VzAE91dEF0dHJpYnV0ZQBjb250ZW50TGVuZ3RoAHBhdGgAbWF4Qnl0ZXMA
>> "%~1" echo YWN0aW9uAHF1ZXJ5AHN0YW1wAGIAcABhcGtQYXRoAGZzAG9mZnNldABidWYAY291
>> "%~1" echo bnQAZW50cnlOYW1lAGluZm8AYXR0ckJhc2UAYXR0ckNvdW50AHN0cmluZ3MAd2Fu
>> "%~1" echo dE5hbWUAcG9vbABpZHgAY2h1bmtQb3MAa2VlcABzAGV2AGRhdGEAc3RhZ2UAdGV4
>> "%~1" echo dABwZXJjZW50AGxpbmUAb2sAbWVzc2FnZQBwYWNrYWdlAHNlcmlhbABvdXRUZXh0
>> "%~1" echo AHRpbWVkT3V0AHBrZwBieXRlcwBiYXNlRGlyAGRldmljZUxpbmUAaGludABucwBr
>> "%~1" echo ZXkAdGltZW91dABjb21tYW5kAHNiAGQAc25hcAByZXF1aXJlZABzYWZlAHRpdGxl
>> "%~1" echo AGYAZGVmcwBmaWxlAG9uTGluZQBhAHYAbmVlZGxlAGxlZnQAcmlnaHQAcGF0dGVy
>> "%~1" echo bgBkZgBtZW0AY3B1AGRpc3BsYXkAdGhlcm1hbAB1c2IAd2lmaQBpcEFkZHIAYnQA
>> "%~1" echo Y2FtZXJhAHNlbnNvcgBwcmVmaXgAdmFsdWUAbXNnAHEAdHlwZQBib2R5AFN5c3Rl
>> "%~1" echo bS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMAQ29tcGlsYXRpb25SZWxheGF0aW9u
>> "%~1" echo c0F0dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJpbGl0eUF0dHJpYnV0ZQA8TWFpbj5i
>> "%~1" echo X18wAG8AU3lzdGVtLlRocmVhZGluZwBXYWl0Q2FsbGJhY2sAQ1MkPD45X19DYWNo
>> "%~1" echo ZWRBbm9ueW1vdXNNZXRob2REZWxlZ2F0ZTEAQ29tcGlsZXJHZW5lcmF0ZWRBdHRy
>> "%~1" echo aWJ1dGUAQ2xvc2UARXhjZXB0aW9uAGdldF9NZXNzYWdlAFN0cmluZwBDb25jYXQA
>> "%~1" echo Z2V0X1VURjgAQ29uc29sZQBzZXRfT3V0cHV0RW5jb2RpbmcAb3BfRXF1YWxpdHkA
>> "%~1" echo RW52aXJvbm1lbnQARXhpdABBcHBEb21haW4AZ2V0X0N1cnJlbnREb21haW4AZ2V0
>> "%~1" echo X0Jhc2VEaXJlY3RvcnkAU3lzdGVtLk5ldABJUEFkZHJlc3MAUGFyc2UAVGNwTGlz
>> "%~1" echo dGVuZXIAU3RhcnQAV3JpdGVMaW5lAENvbnNvbGVLZXlJbmZvAFJlYWRLZXkASW50
>> "%~1" echo MzIAR2V0RW52aXJvbm1lbnRWYXJpYWJsZQBTdHJpbmdDb21wYXJpc29uAEVxdWFs
>> "%~1" echo cwBTeXN0ZW0uRGlhZ25vc3RpY3MAUHJvY2VzcwBBY2NlcHRUY3BDbGllbnQAVGhy
>> "%~1" echo ZWFkUG9vbABRdWV1ZVVzZXJXb3JrSXRlbQBnZXRfQ291bnQARW51bWVyYXRvcgBH
>> "%~1" echo ZXRFbnVtZXJhdG9yAGdldF9DdXJyZW50AFRleHRXcml0ZXIAZ2V0X0Vycm9yAE1v
>> "%~1" echo dmVOZXh0AElEaXNwb3NhYmxlAERpc3Bvc2UAb3BfSW5lcXVhbGl0eQBBZGQASW5k
>> "%~1" echo ZXhPZgBzZXRfUmVjZWl2ZVRpbWVvdXQAc2V0X1NlbmRUaW1lb3V0AE5ldHdvcmtT
>> "%~1" echo dHJlYW0AR2V0U3RyZWFtAGdldF9BU0NJSQBHZXRTdHJpbmcAU3RyaW5nU3BsaXRP
>> "%~1" echo cHRpb25zAFNwbGl0AElzTnVsbE9yRW1wdHkAQ2hhcgBUb1VwcGVySW52YXJpYW50
>> "%~1" echo AGdldF9MZW5ndGgAU3Vic3RyaW5nAFRyaW0AVG9Mb3dlckludmFyaWFudABJbnQ2
>> "%~1" echo NABUcnlQYXJzZQBVcmkAZ2V0X1F1ZXJ5AGdldF9BYnNvbHV0ZVBhdGgAU3RhcnRz
>> "%~1" echo V2l0aABHZXRCeXRlcwBCeXRlAFJlYWQAVG9BcnJheQBGaWxlTW9kZQBGaWxlQWNj
>> "%~1" echo ZXNzAE1hdGgATWluAEZsdXNoAFdyaXRlAHNldF9JdGVtAGdldF9JdGVtAFRocmVh
>> "%~1" echo ZABTbGVlcABDb250YWluc0tleQBEYXRlVGltZQBnZXRfTm93AFRvU3RyaW5nAFBh
>> "%~1" echo dGgAQ29tYmluZQBEaXJlY3RvcnkARGlyZWN0b3J5SW5mbwBDcmVhdGVEaXJlY3Rv
>> "%~1" echo cnkARmlsZQBXcml0ZUFsbFRleHQAVGltZVNwYW4Ab3BfU3VidHJhY3Rpb24AZ2V0
>> "%~1" echo X1RvdGFsTWlsbGlzZWNvbmRzAFN5c3RlbS5HbG9iYWxpemF0aW9uAEN1bHR1cmVJ
>> "%~1" echo bmZvAGdldF9JbnZhcmlhbnRDdWx0dXJlAElGb3JtYXRQcm92aWRlcgBKb2luAEVz
>> "%~1" echo Y2FwZURhdGFTdHJpbmcAVW5lc2NhcGVEYXRhU3RyaW5nAERpcmVjdG9yeVNlcGFy
>> "%~1" echo YXRvckNoYXIAUmVwbGFjZQBFbmRzV2l0aABHZXRGdWxsUGF0aABFeGlzdHMAUmVh
>> "%~1" echo ZEFsbEJ5dGVzAFNlZWtPcmlnaW4AU2VlawBJT0V4Y2VwdGlvbgBNZW1vcnlTdHJl
>> "%~1" echo YW0AU3lzdGVtLklPLkNvbXByZXNzaW9uAERlZmxhdGVTdHJlYW0AQ29tcHJlc3Np
>> "%~1" echo b25Nb2RlAENvbnRhaW5zAGdldF9Vbmljb2RlAEdldERpcmVjdG9yaWVzAElFbnVt
>> "%~1" echo ZXJhYmxlYDEAU3RyaW5nQ29tcGFyZXIAZ2V0X09yZGluYWwASUNvbXBhcmVyYDEA
>> "%~1" echo U29ydABEZWxldGUATW9uaXRvcgBFbnRlcgBUcnlHZXRWYWx1ZQBCb29sZWFuAEFw
>> "%~1" echo cGVuZExpbmUAQXBwZW5kADw+Y19fRGlzcGxheUNsYXNzYgA8QXBrSW5zdGFsbFN0
>> "%~1" echo cmVhbT5iX181ADxBcGtJbnN0YWxsU3RyZWFtPmJfXzcAbG4APD5jX19EaXNwbGF5
>> "%~1" echo Q2xhc3NkAENTJDw+OF9fbG9jYWxzYwBzYXdTdWNjZXNzAHNhd1NpZ01pc21hdGNo
>> "%~1" echo AGxhc3RFcnJMaW5lADxBcGtJbnN0YWxsU3RyZWFtPmJfXzYAPD5jX19EaXNwbGF5
>> "%~1" echo Q2xhc3NmAENTJDw+OF9fbG9jYWxzZQBvazIAPEFwa0luc3RhbGxTdHJlYW0+Yl9f
>> "%~1" echo OABnZXRfQ2hhcnMASXNMZXR0ZXJPckRpZ2l0AERvdWJsZQBBcHBlbmRBbGxUZXh0
>> "%~1" echo AGdldF9OZXdMaW5lAFJlYWRBbGxMaW5lcwBOdW1iZXJTdHlsZXMAU3RvcHdhdGNo
>> "%~1" echo AFN0YXJ0TmV3AFN0b3AAZ2V0X0VsYXBzZWRNaWxsaXNlY29uZHMAPD5jX19EaXNw
>> "%~1" echo bGF5Q2xhc3MxNAByZXN1bHQAPD5jX19EaXNwbGF5Q2xhc3MxNgBDUyQ8PjhfX2xv
>> "%~1" echo Y2FsczE1ADxSdW5SZXN1bHQ+Yl9fMTIAPFJ1blJlc3VsdD5iX18xMwBTdHJlYW1S
>> "%~1" echo ZWFkZXIAZ2V0X1N0YW5kYXJkT3V0cHV0AFRleHRSZWFkZXIAUmVhZFRvRW5kAGdl
>> "%~1" echo dF9TdGFuZGFyZEVycm9yAFByb2Nlc3NTdGFydEluZm8Ac2V0X0ZpbGVOYW1lAHNl
>> "%~1" echo dF9Bcmd1bWVudHMAc2V0X1VzZVNoZWxsRXhlY3V0ZQBzZXRfUmVkaXJlY3RTdGFu
>> "%~1" echo ZGFyZE91dHB1dABzZXRfUmVkaXJlY3RTdGFuZGFyZEVycm9yAHNldF9DcmVhdGVO
>> "%~1" echo b1dpbmRvdwBUaHJlYWRTdGFydABXYWl0Rm9yRXhpdABLaWxsAGdldF9FeGl0Q29k
>> "%~1" echo ZQA8PmNfX0Rpc3BsYXlDbGFzczFmAGdhdGUAPD5jX19EaXNwbGF5Q2xhc3MyMQBD
>> "%~1" echo UyQ8PjhfX2xvY2FsczIwADxSdW5TdHJlYW0+Yl9fMWQAPFJ1blN0cmVhbT5iX18x
>> "%~1" echo ZQBJbnZva2UAUmVhZExpbmUAPFByaXZhdGVJbXBsZW1lbnRhdGlvbkRldGFpbHM+
>> "%~1" echo e0JERDVBREE5LTlDQ0YtNDUwQi04MDU5LTU5RDYxNkFCNDA2RX0AVmFsdWVUeXBl
>> "%~1" echo AF9fU3RhdGljQXJyYXlJbml0VHlwZVNpemU9MTYAJCRtZXRob2QweDYwMDAwNTAt
>> "%~1" echo MQBSdW50aW1lSGVscGVycwBBcnJheQBSdW50aW1lRmllbGRIYW5kbGUASW5pdGlh
>> "%~1" echo bGl6ZUFycmF5AEluZGV4T2ZBbnkAVHJpbUVuZABTeXN0ZW0uVGV4dC5SZWd1bGFy
>> "%~1" echo RXhwcmVzc2lvbnMAUmVnZXgATWF0Y2gAUmVnZXhPcHRpb25zAEdyb3VwAGdldF9T
>> "%~1" echo dWNjZXNzAEdyb3VwQ29sbGVjdGlvbgBnZXRfR3JvdXBzAGdldF9WYWx1ZQBSZWZl
>> "%~1" echo cmVuY2VFcXVhbHMARXNjYXBlAE1hdGNoQ29sbGVjdGlvbgBNYXRjaGVzAFdlYlV0
>> "%~1" echo aWxpdHkASHRtbEVuY29kZQA8UmVkYWN0TG9vc2U+Yl9fMjMAbQBNYXRjaEV2YWx1
>> "%~1" echo YXRvcgBDUyQ8PjlfX0NhY2hlZEFub255bW91c01ldGhvZERlbGVnYXRlMjQASXNN
>> "%~1" echo YXRjaABLZXlWYWx1ZVBhaXJgMgBnZXRfS2V5AENvbnZlcnQARnJvbUJhc2U2NFN0
>> "%~1" echo cmluZwAuY2N0b3IAR3VpZABOZXdHdWlkAFVURjhFbmNvZGluZwAAAAAP94tCbL9+
>> "%~1" echo C3oCXzheGv8BFy0ALQBzAGUAbABmAC0AdABlAHMAdAABEzEAMgA3AC4AMAAuADAA
>> "%~1" echo LgAxAABNUQB1AGUAcwB0ACAAQQBEAEIAIABXAGUAYgBVAEkAIAAvVKhSMVkljRr/
>> "%~1" echo OAA3ADYANQAtADgANwA4ADUAIADveuNT/ZANTu9TKHUCMAEtL1SoUjFZJY0a/zgA
>> "%~1" echo NwA2ADUALQA4ADcAOAA1ACAA73rjU/2QDU7vUyh1AjABI2gAdAB0AHAAOgAvAC8A
>> "%~1" echo MQAyADcALgAwAC4AMAAuADEAOgAAES8APwB0AG8AawBlAG4APQAALVEAdQBlAHMA
>> "%~1" echo dAAgAEEARABCACAAVwBlAGIAVQBJACAADWehUvJdL1SoUhr/AT3qU9F2LFQgADEA
>> "%~1" echo MgA3AC4AMAAuADAALgAxABv/c1HtlSxnl3rjUw5UIABXAGUAYgBVAEkAIABcUGJr
>> "%~1" echo AjABC0EARABCADoAIAAACeVl1186ACAAAS0NZ6FSL1SoUhr/aAB0AHQAcAA6AC8A
>> "%~1" echo LwAxADIANwAuADAALgAwAC4AMQA6AAEDLwAADx1Sy1nej6VjtnIBYBr/AQMgAAAD
>> "%~1" echo MQAANVEAVQBFAFMAVABfAEEARABCAF8AVwBFAEIAVQBJAF8ATgBPAF8AQgBSAE8A
>> "%~1" echo VwBTAEUAUgAAD/eLQmwEWQZ0MVkljRr/AYHpewBcACIARABlAHYAaQBjAGUAXAAi
>> "%~1" echo ADoAewBcACIAQgB1AGkAbABkAFQAeQBwAGUAXAAiADoAXAAiAFAAVgBUADEALgAx
>> "%~1" echo AFwAIgAsAFwAIgBEAGUAdgBpAGMAZQBUAHkAcABlAFwAIgA6AFwAIgBFAHUAcgBl
>> "%~1" echo AGsAYQBcACIAfQAsAFwAIgBGAGkAbABlAEYAbwByAG0AYQB0AFwAIgA6AHsAXAAi
>> "%~1" echo AFQAaQBtAGUAcwB0AGEAbQBwAFwAIgA6AFwAIgAyADAAMgA1AC0AMQAxAC0AMQA1
>> "%~1" echo AFQAMAA4ADoAMQA1ADoANAA1AFwAIgB9ACwAXAAiAE0AZQB0AGEAZABhAHQAYQBc
>> "%~1" echo ACIAOgB7AFwAIgBOAGEAbQBlAGQAVABhAGcAcwBcACIAOgB7AFwAIgBsAG8AYwBh
>> "%~1" echo AHQAaQBvAG4AXwBpAGQAXAAiADoAXAAiAGcAdABrAFwAIgAsAFwAIgBzAHQAYQB0
>> "%~1" echo AGkAbwBuAF8AaQBkAFwAIgA6AFwAIgB3AGYALQBlAHUAcgBlAGsAYQAtAGkAbwB0
>> "%~1" echo AC0AMgB1AHAALQA0ADEAXAAiACwAXAAiAGMAYQBsAGkAYgByAGEAdABpAG8AbgBf
>> "%~1" echo AHQAeQBwAGUAXAAiADoAXAAiAEkATwBUAFwAIgB9AH0AfQABFUQAZQB2AGkAYwBl
>> "%~1" echo AFQAeQBwAGUAAA1FAHUAcgBlAGsAYQAAE0IAdQBpAGwAZABUAHkAcABlAAANUABW
>> "%~1" echo AFQAMQAuADEAABNUAGkAbQBlAHMAdABhAG0AcAAAJzIAMAAyADUALQAxADEALQAx
>> "%~1" echo ADUAVAAwADgAOgAxADUAOgA0ADUAARdsAG8AYwBhAHQAaQBvAG4AXwBpAGQAAAdn
>> "%~1" echo AHQAawAAFXMAdABhAHQAaQBvAG4AXwBpAGQAACl3AGYALQBlAHUAcgBlAGsAYQAt
>> "%~1" echo AGkAbwB0AC0AMgB1AHAALQA0ADEAAR1GAGEAYwB0AG8AcgB5AFMAdQBtAG0AYQBy
>> "%~1" echo AHkAAA9sAG8AYwAgAGcAdABrAAA5cwB0AGEAdABpAG8AbgAgAHcAZgAtAGUAdQBy
>> "%~1" echo AGUAawBhAC0AaQBvAHQALQAyAHUAcAAtADQAMQABgKF7AFwAIgBTAGUAbgBzAG8A
>> "%~1" echo cgBUAHkAcABlAFwAIgA6AFwAIgBPAEcAMAAxAEEAXAAiAH0AewBcACIAUwBlAG4A
>> "%~1" echo cwBvAHIAVAB5AHAAZQBcACIAOgBcACIATwBWADcAMgA1ADEAXAAiAH0AewBcACIA
>> "%~1" echo UwBlAG4AcwBvAHIAVAB5AHAAZQBcACIAOgBcACIASQBNAFgANAA3ADEAXAAiAH0A
>> "%~1" echo ABtDAGEAbQBlAHIAYQBTAHUAbQBtAGEAcgB5AAABAA9PAEcAMAAxAEEAIAAxAAAR
>> "%~1" echo TwBWADcAMgA1ADEAIAAxAAARSQBNAFgANAA3ADEAIAAxAAA5UQB1AGUAcwB0AEEA
>> "%~1" echo ZABiAFcAZQBiAFUAaQAgAHMAZQBsAGYALQB0AGUAcwB0ACAAUABBAFMAUwABGToA
>> "%~1" echo IABlAHgAcABlAGMAdABlAGQAIABbAAAXXQAgAGIAdQB0ACAAZwBvAHQAIABbAAAD
>> "%~1" echo XQAAFzoAIABtAGkAcwBzAGkAbgBnACAAWwAADV0AIABpAG4AIABbAAAFDQAKAAAd
>> "%~1" echo YwBvAG4AdABlAG4AdAAtAGwAZQBuAGcAdABoAAEbeAAtAHEAdQBlAHMAdAAtAHQA
>> "%~1" echo bwBrAGUAbgABC3QAbwBrAGUAbgAAFy8AYQBwAGkALwBzAHQAYQB0AHUAcwAAEXQA
>> "%~1" echo bwBrAGUAbgAgAOBlSGUBFy8AYQBwAGkALwBhAGMAdABpAG8AbgAACVAATwBTAFQA
>> "%~1" echo ACPuTzllzWRcT8Vfe5h/Tyh1IABQAE8AUwBUACAA94tCbAIwAQ1hAGMAdABpAG8A
>> "%~1" echo bgAAD2MAbwBuAGYAaQByAG0AAAdZAEUAUwAAF3FTaZbNZFxPAJeBiYxOIWtueKSL
>> "%~1" echo AjABEy8AYQBwAGkALwBsAG8AZwBzAAAXLwBhAHAAaQAvAGUAeABwAG8AcgB0AAAf
>> "%~1" echo /Fv6UcVfe5h/Tyh1IABQAE8AUwBUACAA94tCbAIwAR8vAGEAcABpAC8AYQBwAGsA
>> "%~1" echo LwB1AHAAbABvAGEAZAAAHwpOIE/FX3uYf08odSAAUABPAFMAVAAgAPeLQmwCMAEh
>> "%~1" echo LwBhAHAAaQAvAGEAcABrAC8AaQBuAHMAdABhAGwAbAAAH4lbxYjFX3uYf08odSAA
>> "%~1" echo UABPAFMAVAAgAPeLQmwCMAEdiVvFiCAAQQBQAEsAIAAAl4GJjE4ha254pIsCMAEv
>> "%~1" echo LwBhAHAAaQAvAGEAcABrAC8AaQBuAHMAdABhAGwAbAAtAHMAdAByAGUAYQBtAAET
>> "%~1" echo LwBlAHgAcABvAHIAdABzAC8AADN0AGUAeAB0AC8AcABsAGEAaQBuADsAIABjAGgA
>> "%~1" echo YQByAHMAZQB0AD0AdQB0AGYALQA4AAEZLwBmAGEAdgBpAGMAbwBuAC4AaQBjAG8A
>> "%~1" echo ABtpAG0AYQBnAGUALwBzAHYAZwArAHgAbQBsAACBszwAcwB2AGcAIAB4AG0AbABu
>> "%~1" echo AHMAPQAnAGgAdAB0AHAAOgAvAC8AdwB3AHcALgB3ADMALgBvAHIAZwAvADIAMAAw
>> "%~1" echo ADAALwBzAHYAZwAnACAAdgBpAGUAdwBCAG8AeAA9ACcAMAAgADAAIAAyADQAIAAy
>> "%~1" echo ADQAJwAgAGYAaQBsAGwAPQAnAG4AbwBuAGUAJwAgAHMAdAByAG8AawBlAD0AJwAj
>> "%~1" echo ADIANQA2ADMAZQBiACcAIABzAHQAcgBvAGsAZQAtAHcAaQBkAHQAaAA9ACcAMgAn
>> "%~1" echo AD4APABwAGEAdABoACAAZAA9ACcATQA2ACAAOQBoADEAMgBhADMAIAAzACAAMAAg
>> "%~1" echo ADAAIAAxACAAMwAgADMAdgAzAGEAMwAgADMAIAAwACAAMAAgADEALQAzACAAMwBo
>> "%~1" echo AC0AMQAuADUAbAAtADIALgA1AC0AMwBoAC0ANABsAC0AMgAuADUAIAAzAEgANgBh
>> "%~1" echo ADMAIAAzACAAMAAgADAAIAAxAC0AMwAtADMAdgAtADMAYQAzACAAMwAgADAAIAAw
>> "%~1" echo ACAAMQAgADMALQAzAHoAJwAvAD4APAAvAHMAdgBnAD4AATF0AGUAeAB0AC8AaAB0
>> "%~1" echo AG0AbAA7ACAAYwBoAGEAcgBzAGUAdAA9AHUAdABmAC0AOAABD3MAZQByAHYAaQBj
>> "%~1" echo AGUAABUxADIANwAuADAALgAwAC4AMQA6AAAPYQBkAGIAUABhAHQAaAAAD2wAbwBn
>> "%~1" echo AEYAaQBsAGUAABdkAGUAdgBpAGMAZQBTAHQAYQB0AGUAABVkAGUAdgBpAGMAZQBM
>> "%~1" echo AGkAbgBlAAAJaABpAG4AdAAAE2MAbwBuAG4AZQBjAHQAZQBkAAANZABlAHYAaQBj
>> "%~1" echo AGUAAAtmAGEAbABzAGUAAAl0AHIAdQBlAAALtnIBYPuL1lMa/wENcwBlAHIAaQBh
>> "%~1" echo AGwAAAttAG8AZABlAGwAACFyAG8ALgBwAHIAbwBkAHUAYwB0AC4AbQBvAGQAZQBs
>> "%~1" echo AAAPYQBuAGQAcgBvAGkAZAAAMXIAbwAuAGIAdQBpAGwAZAAuAHYAZQByAHMAaQBv
>> "%~1" echo AG4ALgByAGUAbABlAGEAcwBlAAAHcwBkAGsAAClyAG8ALgBiAHUAaQBsAGQALgB2
>> "%~1" echo AGUAcgBzAGkAbwBuAC4AcwBkAGsAABtzAGUAYwB1AHIAaQB0AHkAUABhAHQAYwBo
>> "%~1" echo AAA/cgBvAC4AYgB1AGkAbABkAC4AdgBlAHIAcwBpAG8AbgAuAHMAZQBjAHUAcgBp
>> "%~1" echo AHQAeQBfAHAAYQB0AGMAaAAAGW0AYQBuAHUAZgBhAGMAdAB1AHIAZQByAAAvcgBv
>> "%~1" echo AC4AcAByAG8AZAB1AGMAdAAuAG0AYQBuAHUAZgBhAGMAdAB1AHIAZQByAAALYgBy
>> "%~1" echo AGEAbgBkAAAhcgBvAC4AcAByAG8AZAB1AGMAdAAuAGIAcgBhAG4AZAAAF3AAcgBv
>> "%~1" echo AGQAdQBjAHQATgBhAG0AZQAAH3IAbwAuAHAAcgBvAGQAdQBjAHQALgBuAGEAbQBl
>> "%~1" echo AAAbcAByAG8AZAB1AGMAdABEAGUAdgBpAGMAZQAAI3IAbwAuAHAAcgBvAGQAdQBj
>> "%~1" echo AHQALgBkAGUAdgBpAGMAZQAAC2IAbwBhAHIAZAAAIXIAbwAuAHAAcgBvAGQAdQBj
>> "%~1" echo AHQALgBiAG8AYQByAGQAAAdzAG8AYwAAJ3IAbwAuAHMAbwBjAC4AbQBhAG4AdQBm
>> "%~1" echo AGEAYwB0AHUAcgBlAHIAABlyAG8ALgBzAG8AYwAuAG0AbwBkAGUAbAAAD2IAdQBp
>> "%~1" echo AGwAZABJAGQAACdyAG8ALgBiAHUAaQBsAGQALgBkAGkAcwBwAGwAYQB5AC4AaQBk
>> "%~1" echo AAAXYgB1AGkAbABkAEIAcgBhAG4AYwBoAAAfcgBvAC4AYgB1AGkAbABkAC4AYgBy
>> "%~1" echo AGEAbgBjAGgAACFiAHUAaQBsAGQASQBuAGMAcgBlAG0AZQBuAHQAYQBsAAA5cgBv
>> "%~1" echo AC4AYgB1AGkAbABkAC4AdgBlAHIAcwBpAG8AbgAuAGkAbgBjAHIAZQBtAGUAbgB0
>> "%~1" echo AGEAbAAAF3YAZQBuAGQAbwByAFAAYQB0AGMAaAAAPXIAbwAuAHYAZQBuAGQAbwBy
>> "%~1" echo AC4AYgB1AGkAbABkAC4AcwBlAGMAdQByAGkAdAB5AF8AcABhAHQAYwBoAAAHYQBi
>> "%~1" echo AGkAACVyAG8ALgBwAHIAbwBkAHUAYwB0AC4AYwBwAHUALgBhAGIAaQAADXcAaQBm
>> "%~1" echo AGkASQBwAAAVYQBkAGIARQBuAGEAYgBsAGUAZAAADWcAbABvAGIAYQBsAAAXYQBk
>> "%~1" echo AGIAXwBlAG4AYQBiAGwAZQBkAAAPYQBkAGIAVwBpAGYAaQAAIWEAZABiAF8AdwBp
>> "%~1" echo AGYAaQBfAGUAbgBhAGIAbABlAGQAAA1zAHQAYQB5AE8AbgAAMXMAdABhAHkAXwBv
>> "%~1" echo AG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBuAAATdwBpAGYAaQBT
>> "%~1" echo AGwAZQBlAHAAACN3AGkAZgBpAF8AcwBsAGUAZQBwAF8AcABvAGwAaQBjAHkAABNz
>> "%~1" echo AGMAcgBlAGUAbgBPAGYAZgAADXMAeQBzAHQAZQBtAAAlcwBjAHIAZQBlAG4AXwBv
>> "%~1" echo AGYAZgBfAHQAaQBtAGUAbwB1AHQAABlzAGwAZQBlAHAAVABpAG0AZQBvAHUAdAAA
>> "%~1" echo DXMAZQBjAHUAcgBlAAAbcwBsAGUAZQBwAF8AdABpAG0AZQBvAHUAdAAAEWwAbwB3
>> "%~1" echo AFAAbwB3AGUAcgAAE2wAbwB3AF8AcABvAHcAZQByAAAZtnIBYPuL1lMa/2QAZQB2
>> "%~1" echo AGkAYwBlACAAARMgAGIAYQB0AHQAZQByAHkAPQAAGWIAYQB0AHQAZQByAHkATABl
>> "%~1" echo AHYAZQBsAAAPJQAgAHQAZQBtAHAAPQAAF2IAYQB0AHQAZQByAHkAVABlAG0AcAAA
>> "%~1" echo D0MAIAB3AGEAawBlAD0AABd3AGEAawBlAGYAdQBsAG4AZQBzAHMAABEgAHMAdABh
>> "%~1" echo AHkATwBuAD0AABMgAGEAZABiAFcAaQBmAGkAPQAAC81kXE8AX8tZGv8BESAAcwBl
>> "%~1" echo AHIAaQBhAGwAPQAAF3IAZQBzAHQAYQByAHQAXwBhAGQAYgAAF2sAaQBsAGwALQBz
>> "%~1" echo AGUAcgB2AGUAcgABGXMAdABhAHIAdAAtAHMAZQByAHYAZQByAAENcgBlAHMAdQBs
>> "%~1" echo AHQAAB3yXc2RL1Q1dRGB73ogAEEARABCACAADWehUgIwAQMtAAEhoWwJZyhXv34U
>> "%~1" echo TvJdiGNDZ4R2IABRAHUAZQBzAHQAAjABFXMAYQBmAGUAXwBzAGwAZQBlAHAAADlp
>> "%~1" echo AG4AcAB1AHQAIABrAGUAeQBlAHYAZQBuAHQAIABLAEUAWQBDAE8ARABFAF8AUwBM
>> "%~1" echo AEUARQBQAABJ8l1iYA1Z3U+IWzxQdl7RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgAg
>> "%~1" echo ACsAIABLAEUAWQBDAE8ARABFAF8AUwBMAEUARQBQAAIwARVrAGUAZQBwAF8AYQB3
>> "%~1" echo AGEAawBlAAAR8l2UXih17Xf2Zd1PO20CMAEVZABlAGIAdQBnAF8AbQBvAGQAZQAA
>> "%~1" echo f/JdL1QodQOM1YvlXVxPIWoPXxr/VQBTAEIALwBBAEMAIADdTwFjJFWSkQEwVwBp
>> "%~1" echo AC0ARgBpACAADU4RTyB3ATBPXFVeIAAyADQAIAAPXPZlATAhat9iaU80YmCX0Y8C
>> "%~1" echo MNN+X2cOVPeLZ2JMiBwgYmANWRFPIHeFjfZlHSACMAEbcgBlAHMAdABvAHIAZQBf
>> "%~1" echo AHMAbABlAGUAcAAAJfJdYmANWWNrOF4RTyB3Dk4gADUAIAAGUp+UT1xVXoWN9mUC
>> "%~1" echo MAEZYwBvAG4AcwBlAHIAdgBhAHQAaQB2AGUAABPyXWJgDVndT4hb2J6kizxQAjAB
>> "%~1" echo HXIAZQBzAHQAbwByAGUAXwBiAGEAYwBrAHUAcAAAL/Jdzk4HWf1OYmANWb6Lbn8M
>> "%~1" echo /3Ze0VMBkCAAcAByAG8AeABfAG8AcABlAG4AAjABE3AAcgBvAHgAXwBvAHAAZQBu
>> "%~1" echo AABnYQBtACAAYgByAG8AYQBkAGMAYQBzAHQAIAAtAGEAIABjAG8AbQAuAG8AYwB1
>> "%~1" echo AGwAdQBzAC4AdgByAHAAbwB3AGUAcgBtAGEAbgBhAGcAZQByAC4AcAByAG8AeABf
>> "%~1" echo AG8AcABlAG4AAR3yXdFTAZAgAHAAcgBvAHgAXwBvAHAAZQBuAAIwARVwAHIAbwB4
>> "%~1" echo AF8AYwBsAG8AcwBlAABpYQBtACAAYgByAG8AYQBkAGMAYQBzAHQAIAAtAGEAIABj
>> "%~1" echo AG8AbQAuAG8AYwB1AGwAdQBzAC4AdgByAHAAbwB3AGUAcgBtAGEAbgBhAGcAZQBy
>> "%~1" echo AC4AcAByAG8AeABfAGMAbABvAHMAZQABH/Jd0VMBkCAAcAByAG8AeABfAGMAbABv
>> "%~1" echo AHMAZQACMAERdwBpAHIAZQBsAGUAcwBzAAAFLQBzAAELdABjAHAAaQBwAAAJNQA1
>> "%~1" echo ADUANQAAI/Jd94tCbABfL1TgZb9+IABBAEQAQgAgADUANQA1ADUAAjABGXcAaQBy
>> "%~1" echo AGUAbABlAHMAcwBfAG8AZgBmAABNcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABn
>> "%~1" echo AGwAbwBiAGEAbAAgAGEAZABiAF8AdwBpAGYAaQBfAGUAbgBhAGIAbABlAGQAIAAw
>> "%~1" echo AAAHdQBzAGIAAF3yXfeLQmxzUe2V4GW/fiAAQQBEAEIADP9hAGQAYgBkACAA8l0H
>> "%~1" echo Ut5WIABVAFMAQgAgACFqD18CMOWCU19NUi9m4GW/ft6PpWMM/61lAF9eXI5OY2s4
>> "%~1" echo XrBzYYwCMAETawBlAHkAXwBzAGwAZQBlAHAAACXyXdFTAZAgAEsARQBZAEMATwBE
>> "%~1" echo AEUAXwBTAEwARQBFAFAAAjABFWsAZQB5AF8AdwBhAGsAZQB1AHAAADtpAG4AcAB1
>> "%~1" echo AHQAIABrAGUAeQBlAHYAZQBuAHQAIABLAEUAWQBDAE8ARABFAF8AVwBBAEsARQBV
>> "%~1" echo AFAAAEPyXdFTAZAgAEsARQBZAEMATwBEAEUAXwBXAEEASwBFAFUAUAACMMVOKFcg
>> "%~1" echo AEEARABCACAAzU4oV79+9mUJZ0hlAjABE3MAYwByAGUAZQBuAF8ANQBtAABbcwBl
>> "%~1" echo AHQAdABpAG4AZwBzACAAcAB1AHQAIABzAHkAcwB0AGUAbQAgAHMAYwByAGUAZQBu
>> "%~1" echo AF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAAMwAwADAAMAAwADAAADlzAGMAcgBl
>> "%~1" echo AGUAbgBfAG8AZgBmAF8AdABpAG0AZQBvAHUAdAAgAD0AIAAzADAAMAAwADAAMAAC
>> "%~1" echo MAEVcwBjAHIAZQBlAG4AXwAyADQAaAAAX3MAZQB0AHQAaQBuAGcAcwAgAHAAdQB0
>> "%~1" echo ACAAcwB5AHMAdABlAG0AIABzAGMAcgBlAGUAbgBfAG8AZgBmAF8AdABpAG0AZQBv
>> "%~1" echo AHUAdAAgADgANgA0ADAAMAAwADAAMAAAPXMAYwByAGUAZQBuAF8AbwBmAGYAXwB0
>> "%~1" echo AGkAbQBlAG8AdQB0ACAAPQAgADgANgA0ADAAMAAwADAAMAACMAERcwB0AGEAeQBf
>> "%~1" echo AG8AZgBmAABdcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAg
>> "%~1" echo AHMAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBu
>> "%~1" echo ACAAMAAAO3MAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBk
>> "%~1" echo AF8AaQBuACAAPQAgADAAAjABF3MAdABhAHkAXwB1AHMAYgBfAGEAYwAAXXMAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAHAAdQB0ACAAZwBsAG8AYgBhAGwAIABzAHQAYQB5AF8AbwBu
>> "%~1" echo AF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUAZABfAGkAbgAgADMAADtzAHQAYQB5
>> "%~1" echo AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUAZABfAGkAbgAgAD0AIAAz
>> "%~1" echo AAIwASFyAGUAcwBlAHQAXwBzAGMAcgBlAGUAbgBfAG8AZgBmAABB8l3NkW5/IABz
>> "%~1" echo AGMAcgBlAGUAbgBfAG8AZgBmAF8AdABpAG0AZQBvAHUAdAAgAD0AIAAzADAAMAAw
>> "%~1" echo ADAAMAACMAEbcgBlAHMAZQB0AF8AcwB0AGEAeQBfAG8AbgAAQ/JdzZFufyAAcwB0
>> "%~1" echo AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4AIAA9
>> "%~1" echo ACAAMAACMAEhcgBlAHMAZQB0AF8AdwBpAGYAaQBfAHMAbABlAGUAcAAAT3MAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAHAAdQB0ACAAZwBsAG8AYgBhAGwAIAB3AGkAZgBpAF8AcwBs
>> "%~1" echo AGUAZQBwAF8AcABvAGwAaQBjAHkAIAAxAAA18l3NkW5/IAB3AGkAZgBpAF8AcwBs
>> "%~1" echo AGUAZQBwAF8AcABvAGwAaQBjAHkAIAA9ACAAMQACMAEncgBlAHMAZQB0AF8AcwBs
>> "%~1" echo AGUAZQBwAF8AdABpAG0AZQBvAHUAdAAASXMAZQB0AHQAaQBuAGcAcwAgAGQAZQBs
>> "%~1" echo AGUAdABlACAAcwBlAGMAdQByAGUAIABzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0
>> "%~1" echo AABB8l0gUmSWIABzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0ACAAdl7RUwGQIABw
>> "%~1" echo AHIAbwB4AF8AbwBwAGUAbgACMAEdYwB1AHMAdABvAG0AXwBzAGUAdAB0AGkAbgBn
>> "%~1" echo AAAFbgBzAAAHawBlAHkAAAt2AGEAbAB1AGUAACNuAGEAbQBlAHMAcABhAGMAZQAg
>> "%~1" echo ABZiLpUNVA1OCFTVbAIwASvliy6VDVReXI5O2JrOmGmW+3zffi6VDP/yXTuWYmvq
>> "%~1" echo gZpbSU6ZUWVRAjABG3MAZQB0AHQAaQBuAGcAcwAgAHAAdQB0ACAAAAMuAAAHIAA9
>> "%~1" echo ACAAACFjAHUAcwB0AG8AbQBfAGIAcgBvAGEAZABjAGEAcwB0AAAJbgBhAG0AZQAA
>> "%~1" echo EX9erWQNVPB5DU4IVNVsAjABIWEAbQAgAGIAcgBvAGEAZABjAGEAcwB0ACAALQBh
>> "%~1" echo ACAAAQ3yXdFTAZB/Xq1kGv8BCypn5XfNZFxPAjABC81kXE+MWxBiGv8BESAAcgBl
>> "%~1" echo AHMAdQBsAHQAPQAABW8AawAAC2UAcgByAG8AcgAAC81kXE8xWSWNGv8BDyAAZQBy
>> "%~1" echo AHIAbwByAD0AAAl0AGUAeAB0AAAl/Fv6UQBfy1ka/+pT+4uMW3RlvosHWeFPb2Ag
>> "%~1" echo AEgAVABNAEwAAR95AHkAeQB5AE0ATQBkAGQAXwBIAEgAbQBtAHMAcwAAD2UAeABw
>> "%~1" echo AG8AcgB0AHMAADdRAHUAZQBzAHQAMwBfAGQAZQB2AGkAYwBlAF8AcAByAGkAdgBh
>> "%~1" echo AHQAZQBfAGYAdQBsAGwAXwAACy4AaAB0AG0AbAAAM1EAdQBlAHMAdAAzAF8AZABl
>> "%~1" echo AHYAaQBjAGUAXwBzAGgAYQByAGUAXwBzAGEAZgBlAF8AABdwAHIAaQB2AGEAdABl
>> "%~1" echo AFAAYQB0AGgAABFzAGEAZgBlAFAAYQB0AGgAABVwAHIAaQB2AGEAdABlAFUAcgBs
>> "%~1" echo AAAPcwBhAGYAZQBVAHIAbAAAFWQAdQByAGEAdABpAG8AbgBNAHMAABlzAGUAYwB0
>> "%~1" echo AGkAbwBuAEMAbwB1AG4AdAAAEXcAYQByAG4AaQBuAGcAcwAAByAAfAAgAAAp8l0f
>> "%~1" echo dRBiwXkJZ4xbdGVIcoxUBlKrTolbaFFIciAASABUAE0ATAACMAEL/Fv6UYxbEGIa
>> "%~1" echo /wEHIAAvACAAAAv8W/pRMVkljRr/AQ8/AHQAbwBrAGUAbgA9AAAFLgAuAAANXpfV
>> "%~1" echo bKViSlTvjYRfAQulYkpUDU5YWyhXAQ/7i9ZTpWJKVDFZJY0a/wEnQQBuAGQAcgBv
>> "%~1" echo AGkAZABNAGEAbgBpAGYAZQBzAHQALgB4AG0AbAAAOUEAUABLACAAhVEqZ35iMFIg
>> "%~1" echo AEEAbgBkAHIAbwBpAGQATQBhAG4AaQBmAGUAcwB0AC4AeABtAGwAARlBAFgATQBM
>> "%~1" echo ACAA44mQZypnl18wUgVTDVQBFUEAUABLACAA+4vWUw9hFlnTfl9nARkNTi9mCWdI
>> "%~1" echo ZYR2IABBAFgATQBMACAANFkBEW0AYQBuAGkAZgBlAHMAdAAAH3UAcwBlAHMALQBw
>> "%~1" echo AGUAcgBtAGkAcwBzAGkAbwBuAAEPcABhAGMAawBhAGcAZQAAF3YAZQByAHMAaQBv
>> "%~1" echo AG4ATgBhAG0AZQAAF3YAZQByAHMAaQBvAG4AQwBvAGQAZQAAD3UAcABsAG8AYQBk
>> "%~1" echo AHMAADMKTiBPhVG5WzpOenoWYjp/EVwgAEMAbwBuAHQAZQBuAHQALQBMAGUAbgBn
>> "%~1" echo AHQAaAACMAElQQBQAEsAIACFjcePJ1kPXApOUJYI/zQAIABHAGkAQgAJ/wIwASd5
>> "%~1" echo AHkAeQB5AE0ATQBkAGQAXwBIAEgAbQBtAHMAcwBfAGYAZgBmAAAPYQBwAHAALgBh
>> "%~1" echo AHAAawAAMdmPDU4vZglnSGWEdiAAQQBQAEsACP86fxFcIABaAEkAUAAvAFAASwAg
>> "%~1" echo ADRZCf8CMAERdQBwAGwAbwBhAGQASQBkAAARZgBpAGwAZQBOAGEAbQBlAAATcwBp
>> "%~1" echo AHoAZQBCAHkAdABlAHMAABFzAGkAegBlAFQAZQB4AHQAAB9wAGUAcgBtAGkAcwBz
>> "%~1" echo AGkAbwBuAEMAbwB1AG4AdAAAF3AAZQByAG0AaQBzAHMAaQBvAG4AcwAAAwoAAA9w
>> "%~1" echo AGEAcgBzAGUATwBrAAAVcABhAHIAcwBlAEUAcgByAG8AcgAAKWkAbgBzAHQAYQBs
>> "%~1" echo AGwAZQBkAFYAZQByAHMAaQBvAG4AQwBvAGQAZQAAIWEAbAByAGUAYQBkAHkASQBu
>> "%~1" echo AHMAdABhAGwAbABlAGQAAA9BAFAASwAgAApOIE8a/wEFIAAoAAANKQAgAHAAawBn
>> "%~1" echo AD0AAA8gAHYATgBhAG0AZQA9AAAPIAB2AEMAbwBkAGUAPQAAE0EAUABLACAACk4g
>> "%~1" echo TzFZJY0a/wElfmINTjBS8l0KTiBPhHYgAEEAUABLAAz/94vNkbBlCk4gTwIwAQ9y
>> "%~1" echo AGUAcABsAGEAYwBlAAALZwByAGEAbgB0AAATZABvAHcAbgBnAHIAYQBkAGUAAB11
>> "%~1" echo AG4AaQBuAHMAdABhAGwAbABGAGkAcgBzAHQAACFBAFAASwAgAIlbxYgAX8tZGv9z
>> "%~1" echo AGUAcgBpAGEAbAA9AAELIABwAGsAZwA9AAAHIAByAD0AAAcgAGcAPQAAByAAZAA9
>> "%~1" echo AAAJIAB1AGYAPQAAC3hTfY/nZQVTIAABCSAALgAuAC4AABN1AG4AaQBuAHMAdABh
>> "%~1" echo AGwAbAAABSAAIAAAD2kAbgBzAHQAYQBsAGwAAAUtAHIAAQUtAGcAAQUtAGQAAQ+J
>> "%~1" echo W8WIGv9hAGQAYgAgAAEPUwB1AGMAYwBlAHMAcwAARUkATgBTAFQAQQBMAEwAXwBG
>> "%~1" echo AEEASQBMAEUARABfAFUAUABEAEEAVABFAF8ASQBOAEMATwBNAFAAQQBUAEkAQgBM
>> "%~1" echo AEUAAC9zAGkAZwBuAGEAdAB1AHIAZQBzACAAZABvACAAbgBvAHQAIABtAGEAdABj
>> "%~1" echo AGgAADNJAE4AQwBPAE4AUwBJAFMAVABFAE4AVABfAEMARQBSAFQASQBGAEkAQwBB
>> "%~1" echo AFQARQBTAAAffnsNVA1OJnsM/+qBqFJ4U32P52UFUw5UzZHFiCAAAQsgACAAzZHF
>> "%~1" echo iBr/AQtzAHQAZQBwAHMAAAdyAGEAdwAACYlbxYgQYp9SAQMa/wEDAjABE0EAUABL
>> "%~1" echo ACAAiVvFiBBin1Ia/wETQQBQAEsAIACJW8WIMVkljRr/AQsgAHIAYQB3AD0AABNB
>> "%~1" echo AFAASwAgAIlbxYgCXzheGv8BgQ1IAFQAVABQAC8AMQAuADEAIAAyADAAMAAgAE8A
>> "%~1" echo SwANAAoAQwBvAG4AdABlAG4AdAAtAFQAeQBwAGUAOgAgAHQAZQB4AHQALwBlAHYA
>> "%~1" echo ZQBuAHQALQBzAHQAcgBlAGEAbQA7ACAAYwBoAGEAcgBzAGUAdAA9AHUAdABmAC0A
>> "%~1" echo OAANAAoAQwBhAGMAaABlAC0AQwBvAG4AdAByAG8AbAA6ACAAbgBvAC0AcwB0AG8A
>> "%~1" echo cgBlAA0ACgBDAG8AbgBuAGUAYwB0AGkAbwBuADoAIABjAGwAbwBzAGUADQAKAFgA
>> "%~1" echo LQBBAGMAYwBlAGwALQBCAHUAZgBmAGUAcgBpAG4AZwA6ACAAbgBvAA0ACgANAAoA
>> "%~1" echo AQ9lAHYAZQBuAHQAOgAgAAANZABhAHQAYQA6ACAAAAUKAAoAAAtzAHQAYQBnAGUA
>> "%~1" echo AA9wAGUAcgBjAGUAbgB0AAAJbABpAG4AZQAADW8AdQB0AHAAdQB0AAAPRgBhAGkA
>> "%~1" echo bAB1AHIAZQAAC0UAcgByAG8AcgAAIVMAdAByAGUAYQBtAGUAZAAgAEkAbgBzAHQA
>> "%~1" echo YQBsAGwAABVQAGUAcgBmAG8AcgBtAGkAbgBnAAAPKFe+iwdZCk6JW8WIJiABJUEA
>> "%~1" echo UABLACAAQW0PX4lbxYgAX8tZGv9zAGUAcgBpAGEAbAA9AAEPcAByAGUAcABhAHIA
>> "%~1" echo ZQAAC8ZRB1mJW8WIJiABAyYgARsoAHhTfY+FjfZlDP/nfu1+HVzVi4lbxYgpAAEJ
>> "%~1" echo cAB1AHMAaAAAHahjAZAgAEEAUABLACAAMFI0WT5mdl6JW8WIJiABCWEAZABiACAA
>> "%~1" echo ABdBAFAASwAgAEFtD1+JW8WIEGKfUhr/AQtyAGUAdAByAHkAABt+ew1UDU4mewz/
>> "%~1" echo eFN9j+dlBVMOVM2RxYgmIAEbiVvFiBBin1II//JdSFF4U32P52UFUwn/Gv8BH0EA
>> "%~1" echo UABLACAAQW0PX4lbxYgQYp9SKADNkcWIKQAa/wELiVvFiAJfOF4a/wEXQQBQAEsA
>> "%~1" echo IABBbQ9fiVvFiAJfOF4a/wEPbQBlAHMAcwBhAGcAZQAABzEAMAAwAAAJZABvAG4A
>> "%~1" echo ZQAAIWQAdQBtAHAAcwB5AHMAIABwAGEAYwBrAGEAZwBlACAAABl2AGUAcgBzAGkA
>> "%~1" echo bwBuAEMAbwBkAGUAPQAAN4lbxYiFjfZlCP8nWQVTFmK+iwdZ4GXNVJReCf8CMPeL
>> "%~1" echo bnikizRZPmbyXeOJAZV2Xs2R1YsCMAFNfnsNVA5O8l2JW8WISHIsZw1OAE70gRr/
>> "%~1" echo /lIJkBwgfnsNVA1OJnv2ZUhReFN9jx0gDlTNkdWLCP8aTwVuZJbli5ReKHVwZW5j
>> "%~1" echo Cf8CMAFBSQBOAFMAVABBAEwATABfAEYAQQBJAEwARQBEAF8AVgBFAFIAUwBJAE8A
>> "%~1" echo TgBfAEQATwBXAE4ARwBSAEEARABFAAA5SHIsZ/dTTk+OTvJdiVvFiEhyLGca//5S
>> "%~1" echo CZAcIEFRuItNlqd+IAAoAC0AZAApAB0gDlTNkdWLAjABO0kATgBTAFQAQQBMAEwA
>> "%~1" echo XwBGAEEASQBMAEUARABfAEEATABSAEUAQQBEAFkAXwBFAFgASQBTAFQAUwAAM5Re
>> "%~1" echo KHXyXVhbKFca//5SCZAcIM2RxYjdT1l1cGVuYyAAKAAtAHIAKQAdIA5UzZHViwIw
>> "%~1" echo AUdJAE4AUwBUAEEATABMAF8ARgBBAEkATABFAEQAXwBJAE4AUwBVAEYARgBJAEMA
>> "%~1" echo SQBFAE4AVABfAFMAVABPAFIAQQBHAEUAABO+iwdZWFuoUHp69JUNTrONAjABP0kA
>> "%~1" echo TgBTAFQAQQBMAEwAXwBGAEEASQBMAEUARABfAE4ATwBfAE0AQQBUAEMASABJAE4A
>> "%~1" echo RwBfAEEAQgBJAFMAADVBAFAASwAgAIR2IABDAFAAVQAgALZnhGcgACgAQQBCAEkA
>> "%~1" echo KQAgAA5OvosHWQ1OOVNNkQIwATFJAE4AUwBUAEEATABMAF8ARgBBAEkATABFAEQA
>> "%~1" echo XwBPAEwARABFAFIAXwBTAEQASwAAKUEAUABLACAAgYlCbIR2+3zffkhyLGfYmo5O
>> "%~1" echo vosHWVNfTVJIcixnAjABKUkATgBTAFQAQQBMAEwAXwBQAEEAUgBTAEUAXwBGAEEA
>> "%~1" echo SQBMAEUARAAAMUEAUABLACAA44mQZzFZJY0a/4dl9k7vU/2AX2NPVxZiDU4vZgln
>> "%~1" echo SGWJW8WIBVMCMAEXiVvFiDFZJY0I/ypn5XcZle+LCf8CMAELiVvFiDFZJY0a/wEF
>> "%~1" echo IABCAAAHMAAuADAAAAcgAEsAQgAAByAATQBCAAAJMAAuADAAMAAAByAARwBCAABP
>> "%~1" echo cwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHcAaQBmAGkA
>> "%~1" echo XwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAgADIAAElzAGUAdAB0AGkAbgBnAHMA
>> "%~1" echo IABwAHUAdAAgAHMAZQBjAHUAcgBlACAAcwBsAGUAZQBwAF8AdABpAG0AZQBvAHUA
>> "%~1" echo dAAgAC0AMQABHVEAdQBlAHMAdABfAEEARABCAF8ATABvAGcAcwAADXcAZQBiAHUA
>> "%~1" echo aQBfAAAJLgBsAG8AZwAAJ1EAdQBlAHMAdABfAEEARABCAF8AVwBlAGIAVQBJAC4A
>> "%~1" echo bABvAGcAAC95AHkAeQB5AC0ATQBNAC0AZABkACAASABIADoAbQBtADoAcwBzAC4A
>> "%~1" echo ZgBmAGYAARPlZddfh2X2ThpcKmcbUvpeAjABD/uL1lPlZddfMVkljRr/AVkqZ9FT
>> "%~1" echo sHMgAEEARABCACAAvosHWQIwwGjlZwBf0VMFgCFqD18BMFUAUwBCACAAA4zVi4hj
>> "%~1" echo Q2cBMHBlbmO/foxUIABXAGkAbgBkAG8AdwBzACAAcZqoUgIwAQ9kAGUAdgBpAGMA
>> "%~1" echo ZQBzAAAFLQBsAAEPTABpAHMAdAAgAG8AZgAAF20AbwBkAGUAbAA6AFEAdQBlAHMA
>> "%~1" echo dAAAHXAAcgBvAGQAdQBjAHQAOgBlAHUAcgBlAGsAYQAAG2QAZQB2AGkAYwBlADoA
>> "%~1" echo ZQB1AHIAZQBrAGEAABl1AG4AYQB1AHQAaABvAHIAaQB6AGUAZAAAD28AZgBmAGwA
>> "%~1" echo aQBuAGUAADHyXd6PpWN2XvJdiGNDZwz/8l0YT0hRCZDpYiAAVQBTAEIAIABRAHUA
>> "%~1" echo ZQBzAHQAAjABJfJd3o+lY3Ze8l2IY0NnDP/yXQmQ6WIgAFEAdQBlAHMAdAACMAFP
>> "%~1" echo 8l3ej6Vjdl7yXYhjQ2cCMOhsD2Ea/ypnxosrUjBSIABRAHUAZQBzAHQAIACLV/dT
>> "%~1" echo DP/yXQmQ6WIsewBOKk4gAEEARABCACAAvosHWQIwATu+iwdZKmeIY0NnGv80YgpO
>> "%~1" echo NFk+Zgz/KFcgAFUAUwBCACAAA4zVi4hjQ2c5X5d6zJEJkOliQVG4iwIwATu+iwdZ
>> "%~1" echo u3m/fhr/zZEvVCAAQQBEAEIAIAANZ6FSATDNkdJjIABVAFMAQgAgABZi9GZiY3Bl
>> "%~1" echo bmO/fgIwARXRU7BzvosHWUZPtnIBYAJfOF4a/wEPdQBuAGsAbgBvAHcAbgAACW4A
>> "%~1" echo bwBuAGUAABFnAGUAdABwAHIAbwBwACAAABtzAGUAdAB0AGkAbgBnAHMAIABnAGUA
>> "%~1" echo dAAgAAAJbgB1AGwAbAAAC3MAaABlAGwAbAAAE0EARABCACAAfVTkToWN9mUa/wET
>> "%~1" echo QQBEAEIAIAB9VOROMVkljSgAAQUpABr/ASUjACAAUQB1AGUAcwB0ACAAQQBEAEIA
>> "%~1" echo IADlXXdRvotufwdZ/U4BEyMAIABkAGUAdgBpAGMAZQA9AAAVIwAgAGMAcgBlAGEA
>> "%~1" echo dABlAGQAPQAAJ3kAeQB5AHkALQBNAE0ALQBkAGQAIABIAEgAOgBtAG0AOgBzAHMA
>> "%~1" echo ARHyXRtS+l6+i25/B1n9Thr/ARH7i9ZTB1n9TjxQMVkljRr/AROhbAlnfmIwUgdZ
>> "%~1" echo /U6HZfZOGv8BAyMAACFzAGUAdAB0AGkAbgBnAHMAIABkAGUAbABlAHQAZQAgAAAP
>> "%~1" echo 8l3OTgdZ/U5iYA1ZGv8BAzoAAANfAAADXAAAJ3EAdQBlAHMAdABfAGEAZABiAF8A
>> "%~1" echo cwBlAHQAdABpAG4AZwBzAF8AAAkuAGIAYQBrAAAfZAB1AG0AcABzAHkAcwAgAGIA
>> "%~1" echo YQB0AHQAZQByAHkAAAtsAGUAdgBlAGwAABd0AGUAbQBwAGUAcgBhAHQAdQByAGUA
>> "%~1" echo AAcwAC4AIwAAG2IAYQB0AHQAZQByAHkAUwB0AGEAdAB1AHMAAA1zAHQAYQB0AHUA
>> "%~1" echo cwAAG2IAYQB0AHQAZQByAHkASABlAGEAbAB0AGgAAA1oAGUAYQBsAHQAaAAAF3AA
>> "%~1" echo bwB3AGUAcgBTAG8AdQByAGMAZQAAG2QAdQBtAHAAcwB5AHMAIABwAG8AdwBlAHIA
>> "%~1" echo ABltAFcAYQBrAGUAZgB1AGwAbgBlAHMAcwAAD20AUwB0AGEAeQBPAG4AACVtAFAA
>> "%~1" echo cgBvAHgAaQBtAGkAdAB5AFAAbwBzAGkAdABpAHYAZQAAHW0AUwB0AGEAeQBPAG4A
>> "%~1" echo UwBlAHQAdABpAG4AZwAAOW0AUwB0AGEAeQBPAG4AVwBoAGkAbABlAFAAbAB1AGcA
>> "%~1" echo ZwBlAGQASQBuAFMAZQB0AHQAaQBuAGcAAB1wAG8AdwBlAHIAUwBsAGUAZQBwAEwA
>> "%~1" echo aQBuAGUAAB1TAGwAZQBlAHAAIAB0AGkAbQBlAG8AdQB0ADoAACtjAG8AbgB0AHIA
>> "%~1" echo bwBsAGwAZQByAEwAZQBmAHQAQgBhAHQAdABlAHIAeQAALWMAbwBuAHQAcgBvAGwA
>> "%~1" echo bABlAHIAUgBpAGcAaAB0AEIAYQB0AHQAZQByAHkAACljAG8AbgB0AHIAbwBsAGwA
>> "%~1" echo ZQByAEwAZQBmAHQAUwB0AGEAdAB1AHMAACtjAG8AbgB0AHIAbwBsAGwAZQByAFIA
>> "%~1" echo aQBnAGgAdABTAHQAYQB0AHUAcwAAHWMAbwBuAHQAcgBvAGwAbABlAHIASABpAG4A
>> "%~1" echo dAAAEypn+4vWUzBSS2LEZzV1z5ECMAExZAB1AG0AcABzAHkAcwAgAE8AVgBSAFIA
>> "%~1" echo ZQBtAG8AdABlAFMAZQByAHYAaQBjAGUAABFCAGEAdAB0AGUAcgB5ADoAAAtUAHkA
>> "%~1" echo cABlADoAAAlUAHkAcABlAAAPQgBhAHQAdABlAHIAeQAADVMAdABhAHQAdQBzAAAJ
>> "%~1" echo TABlAGYAdAAAC1IAaQBnAGgAdAAAD3MAdABvAHIAYQBnAGUAAA1tAGUAbQBvAHIA
>> "%~1" echo eQAAG2QAZgAgAC0AaAAgAC8AcwBkAGMAYQByAGQAARVGAGkAbABlAHMAeQBzAHQA
>> "%~1" echo ZQBtAAAJIADyXSh1IAABI2MAYQB0ACAALwBwAHIAbwBjAC8AbQBlAG0AaQBuAGYA
>> "%~1" echo bwAAE00AZQBtAFQAbwB0AGEAbAA6AAAbTQBlAG0AQQB2AGEAaQBsAGEAYgBsAGUA
>> "%~1" echo OgAAB+9TKHUgAAENIAAvACAAO2ChiyAAARN2AGQAUABhAGMAawBhAGcAZQAAE3YA
>> "%~1" echo ZABWAGUAcgBzAGkAbwBuAAAtVgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAC4A
>> "%~1" echo QQBuAGQAcgBvAGkAZAAAE1AAYQBjAGsAYQBnAGUAIABbAAAZdgBlAHIAcwBpAG8A
>> "%~1" echo bgBOAGEAbQBlAD0AAB1kAGkAcwBwAGwAYQB5AFMAdQBtAG0AYQByAHkAAB9kAHUA
>> "%~1" echo bQBwAHMAeQBzACAAZABpAHMAcABsAGEAeQAAI0QAaQBzAHAAbABhAHkARABlAHYA
>> "%~1" echo aQBjAGUASQBuAGYAbwAALygAXABkAHsAMwAsADUAfQBcAHMAKgB4AFwAcwAqAFwA
>> "%~1" echo ZAB7ADMALAA1AH0AKQAAN3IAZQBuAGQAZQByAEYAcgBhAG0AZQBSAGEAdABlAFwA
>> "%~1" echo cwArACgAWwAwAC0AOQAuAF0AKwApAAElZABlAG4AcwBpAHQAeQBcAHMAKwAoAFsA
>> "%~1" echo MAAtADkAXQArACkAAS9EAGUAdgBpAGMAZQBQAHIAbwBkAHUAYwB0AEkAbgBmAG8A
>> "%~1" echo ewBuAGEAbQBlAD0AAAMsAAAFSAB6AAARZABlAG4AcwBpAHQAeQAgAAAddABoAGUA
>> "%~1" echo cgBtAGEAbABTAHUAbQBtAGEAcgB5AAAtZAB1AG0AcABzAHkAcwAgAHQAaABlAHIA
>> "%~1" echo bQBhAGwAcwBlAHIAdgBpAGMAZQAAHVQAaABlAHIAbQBhAGwAIABTAHQAYQB0AHUA
>> "%~1" echo cwAAQ20ATgBhAG0AZQA9AGIAYQB0AHQAZQByAHkALABcAHMAKgBtAFYAYQBsAHUA
>> "%~1" echo ZQA9ACgAWwAwAC0AOQAuAF0AKwApAAE9YgBhAHQAdABlAHIAeQBbAF4AMAAtADkA
>> "%~1" echo XQArACgAWwAwAC0AOQBdACsAXAAuAFsAMAAtADkAXQArACkAAQ9zAHQAYQB0AHUA
>> "%~1" echo cwAgAAAXIAAvACAAYgBhAHQAdABlAHIAeQAgAAADQwAAHWYAYQBjAHQAbwByAHkA
>> "%~1" echo UwB1AG0AbQBhAHIAeQAAK2QAdQBtAHAAcwB5AHMAIABzAGUAbgBzAG8AcgBzAGUA
>> "%~1" echo cgB2AGkAYwBlAAARRgBhAGMAdABvAHIAeQAgAAAJbABvAGMAIAAAEXMAdABhAHQA
>> "%~1" echo aQBvAG4AIAAAF2EAZABiAF8AZABlAHYAaQBjAGUAcwAABWkAZAAAD2cAZQB0AHAA
>> "%~1" echo cgBvAHAAAB9zAGUAdAB0AGkAbgBnAHMAXwBnAGwAbwBiAGEAbAAAKXMAZQB0AHQA
>> "%~1" echo aQBuAGcAcwAgAGwAaQBzAHQAIABnAGwAbwBiAGEAbAAAH3MAZQB0AHQAaQBuAGcA
>> "%~1" echo cwBfAHMAeQBzAHQAZQBtAAApcwBlAHQAdABpAG4AZwBzACAAbABpAHMAdAAgAHMA
>> "%~1" echo eQBzAHQAZQBtAAAfcwBlAHQAdABpAG4AZwBzAF8AcwBlAGMAdQByAGUAAClzAGUA
>> "%~1" echo dAB0AGkAbgBnAHMAIABsAGkAcwB0ACAAcwBlAGMAdQByAGUAAA9iAGEAdAB0AGUA
>> "%~1" echo cgB5AAALcABvAHcAZQByAAAPZABpAHMAcABsAGEAeQAAF2QAdQBtAHAAcwB5AHMA
>> "%~1" echo IAB1AHMAYgAACXcAaQBmAGkAABlkAHUAbQBwAHMAeQBzACAAdwBpAGYAaQAAGWMA
>> "%~1" echo bwBuAG4AZQBjAHQAaQB2AGkAdAB5AAApZAB1AG0AcABzAHkAcwAgAGMAbwBuAG4A
>> "%~1" echo ZQBjAHQAaQB2AGkAdAB5AAATYgBsAHUAZQB0AG8AbwB0AGgAADNkAHUAbQBwAHMA
>> "%~1" echo eQBzACAAYgBsAHUAZQB0AG8AbwB0AGgAXwBtAGEAbgBhAGcAZQByAAANYwBhAG0A
>> "%~1" echo ZQByAGEAAClkAHUAbQBwAHMAeQBzACAAbQBlAGQAaQBhAC4AYwBhAG0AZQByAGEA
>> "%~1" echo ABtzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlAAAPdABoAGUAcgBtAGEAbAAAC2kA
>> "%~1" echo bgBwAHUAdAAAG2QAdQBtAHAAcwB5AHMAIABpAG4AcAB1AHQAABFwAGEAYwBrAGEA
>> "%~1" echo ZwBlAHMAAC1wAG0AIABsAGkAcwB0ACAAcABhAGMAawBhAGcAZQBzACAALQBmACAA
>> "%~1" echo LQBpAAERZgBlAGEAdAB1AHIAZQBzAAAhcABtACAAbABpAHMAdAAgAGYAZQBhAHQA
>> "%~1" echo dQByAGUAcwAAE2wAaQBiAHIAYQByAGkAZQBzAAA1YwBtAGQAIABwAGEAYwBrAGEA
>> "%~1" echo ZwBlACAAbABpAHMAdAAgAGwAaQBiAHIAYQByAGkAZQBzAAAFZABmAAAnZABmACAA
>> "%~1" echo LQBoACAALwBkAGEAdABhACAALwBzAGQAYwBhAHIAZAABD20AZQBtAGkAbgBmAG8A
>> "%~1" echo AA9jAHAAdQBpAG4AZgBvAAAjYwBhAHQAIAAvAHAAcgBvAGMALwBjAHAAdQBpAG4A
>> "%~1" echo ZgBvAAALdQBuAGEAbQBlAAARdQBuAGEAbQBlACAALQBhAAEPaQBwAF8AYQBkAGQA
>> "%~1" echo cgAAD2kAcAAgAGEAZABkAHIAABFpAHAAXwByAG8AdQB0AGUAABFpAHAAIAByAG8A
>> "%~1" echo dQB0AGUAAB12AGkAcgB0AHUAYQBsAGQAZQBzAGsAdABvAHAAAE1kAHUAbQBwAHMA
>> "%~1" echo eQBzACAAcABhAGMAawBhAGcAZQAgAFYAaQByAHQAdQBhAGwARABlAHMAawB0AG8A
>> "%~1" echo cAAuAEEAbgBkAHIAbwBpAGQAAB9vAGMAdQBsAHUAcwBfAHAAYQBjAGsAYQBnAGUA
>> "%~1" echo cwAANWQAdQBtAHAAcwB5AHMAIABwAGEAYwBrAGEAZwBlACAAYwBvAG0ALgBvAGMA
>> "%~1" echo dQBsAHUAcwAAJ2wAbwBnAGMAYQB0AF8AdABhAGkAbABfAHAAcgBpAHYAYQB0AGUA
>> "%~1" echo ACNsAG8AZwBjAGEAdAAgAC0AZAAgAC0AdAAgADMAMAAwADAAAQcgAIWN9mUBCSAA
>> "%~1" echo MVkljRr/AQ8gANdTUJYWYuBlk4/6UQEPYwByAGUAYQB0AGUAZAAAD3AAcgBvAGQA
>> "%~1" echo dQBjAHQAABdmAGkAbgBnAGUAcgBwAHIAaQBuAHQAAClyAG8ALgBiAHUAaQBsAGQA
>> "%~1" echo LgBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAAA1rAGUAcgBuAGUAbAAAAyUAABNwAHIA
>> "%~1" echo bwB4AGkAbQBpAHQAeQAAB2MAcAB1AAALcABhAG4AZQBsAAAjRABlAHYAaQBjAGUA
>> "%~1" echo UAByAG8AZAB1AGMAdABJAG4AZgBvAAAPZgBhAGMAdABvAHIAeQAAG2YAYQBjAHQA
>> "%~1" echo bwByAHkARABlAHYAaQBjAGUAABlmAGEAYwB0AG8AcgB5AEIAdQBpAGwAZAAAF2YA
>> "%~1" echo YQBjAHQAbwByAHkAVABpAG0AZQAAH2YAYQBjAHQAbwByAHkATABvAGMAYQB0AGkA
>> "%~1" echo bwBuAAAdZgBhAGMAdABvAHIAeQBTAHQAYQB0AGkAbwBuAAAlZgBhAGMAdABvAHIA
>> "%~1" echo eQBTAHQAYQB0AGkAbwBuAFQAeQBwAGUAABlzAHQAYQB0AGkAbwBuAF8AdAB5AHAA
>> "%~1" echo ZQAAF2YAYQBjAHQAbwByAHkAVABlAHMAdAAAF2MAYQBsAF8AdABlAHMAdABfAGkA
>> "%~1" echo ZAAAH2YAYQBjAHQAbwByAHkATwBwAGUAcgBhAHQAbwByAAAXbwBwAGUAcgBhAHQA
>> "%~1" echo bwByAF8AaQBkAAAlZgBhAGMAdABvAHIAeQBDAGEAbABpAGIAcgBhAHQAaQBvAG4A
>> "%~1" echo ACFjAGEAbABpAGIAcgBhAHQAaQBvAG4AXwB0AHkAcABlAAAjbwBuAGwAaQBuAGUA
>> "%~1" echo QwBhAGwAaQBiAHIAYQB0AGkAbwBuAAAvdgBlAGcAYQBfAG8AbgBsAGkAbgBlAF8A
>> "%~1" echo YwBhAGwAaQBiAHIAYQB0AGkAbwBuAAA3wGhLbTBSIAB2AGUAZwBhAF8AbwBuAGwA
>> "%~1" echo aQBuAGUAXwBjAGEAbABpAGIAcgBhAHQAaQBvAG4AARFmAGUAYQB0AHUAcgBlADoA
>> "%~1" echo AAV2AGQAADFRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mhW6GLpWJKVCAALQAgAMF5
>> "%~1" echo CWeMW3RlSHIBMVEAdQBlAHMAdAAgAEEARABCACAAvosHWaFboYulYkpUIAAtACAA
>> "%~1" echo BlKrTolbaFFIcgEZUABSAEkAVgBBAFQARQAgAEYAVQBMAEwAABVTAEgAQQBSAEUA
>> "%~1" echo LQBTAEEARgBFAAELUQBBAEQAQgAtAAEfeQB5AHkAeQBNAE0AZABkAC0ASABIAG0A
>> "%~1" echo bQBzAHMAAYERPAAhAGQAbwBjAHQAeQBwAGUAIABoAHQAbQBsAD4APABoAHQAbQBs
>> "%~1" echo ACAAbABhAG4AZwA9ACIAegBoAC0AQwBOACIAPgA8AGgAZQBhAGQAPgA8AG0AZQB0
>> "%~1" echo AGEAIABjAGgAYQByAHMAZQB0AD0AIgB1AHQAZgAtADgAIgA+ADwAbQBlAHQAYQAg
>> "%~1" echo AG4AYQBtAGUAPQAiAHYAaQBlAHcAcABvAHIAdAAiACAAYwBvAG4AdABlAG4AdAA9
>> "%~1" echo ACIAdwBpAGQAdABoAD0AZABlAHYAaQBjAGUALQB3AGkAZAB0AGgALABpAG4AaQB0
>> "%~1" echo AGkAYQBsAC0AcwBjAGEAbABlAD0AMQAiAD4APAB0AGkAdABsAGUAPgABETwALwB0
>> "%~1" echo AGkAdABsAGUAPgAADzwAcwB0AHkAbABlAD4AAI2zOgByAG8AbwB0AHsALQAtAHAA
>> "%~1" echo YQBnAGUAOgAjAGUAZQBmADEAZgA1ADsALQAtAHAAYQBwAGUAcgA6ACMAZgBmAGYA
>> "%~1" echo OwAtAC0AaQBuAGsAOgAjADEAOAAyADAAMwAzADsALQAtAG0AdQB0AGUAZAA6ACMA
>> "%~1" echo NgA2ADcAMAA4ADUAOwAtAC0AbABpAG4AZQA6ACMAZAA4AGUAMABlAGIAOwAtAC0A
>> "%~1" echo bABpAG4AZQAyADoAIwBlAGQAZgAxAGYANgA7AC0ALQBzAG8AZgB0ADoAIwBmADcA
>> "%~1" echo ZgA5AGYAYwA7AC0ALQBhAGMAYwBlAG4AdAA6ACMAMQBkADQAZQBkADgAOwAtAC0A
>> "%~1" echo YQBjAGMAZQBuAHQAMgA6ACMAMABmADEANwAyAGEAOwAtAC0AbwBrADoAIwAxADEA
>> "%~1" echo OAA0ADQANwA7AC0ALQB3AGEAcgBuADoAIwA5AGEANQBiADAAMAA7AC0ALQBzAGgA
>> "%~1" echo YQBkAG8AdwA6ADAAIAAxADgAcAB4ACAANAA4AHAAeAAgAHIAZwBiAGEAKAAxADUA
>> "%~1" echo LAAyADMALAA0ADIALAAuADEAMwApAH0AKgB7AGIAbwB4AC0AcwBpAHoAaQBuAGcA
>> "%~1" echo OgBiAG8AcgBkAGUAcgAtAGIAbwB4AH0AaAB0AG0AbAAsAGIAbwBkAHkAewBtAGEA
>> "%~1" echo cgBnAGkAbgA6ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0A
>> "%~1" echo cABhAGcAZQApADsAYwBvAGwAbwByADoAdgBhAHIAKAAtAC0AaQBuAGsAKQA7AGYA
>> "%~1" echo bwBuAHQAOgAxADQAcAB4AC8AMQAuADUAMgAgACIAUwBlAGcAbwBlACAAVQBJACIA
>> "%~1" echo LAAiAE0AaQBjAHIAbwBzAG8AZgB0ACAAWQBhAEgAZQBpACIALABBAHIAaQBhAGwA
>> "%~1" echo LABzAGEAbgBzAC0AcwBlAHIAaQBmADsAbABlAHQAdABlAHIALQBzAHAAYQBjAGkA
>> "%~1" echo bgBnADoAMAB9AC4AcwBoAGUAZQB0AHsAdwBpAGQAdABoADoAbQBpAG4AKAAxADEA
>> "%~1" echo MgAwAHAAeAAsAGMAYQBsAGMAKAAxADAAMAAlACAALQAgADQAMABwAHgAKQApADsA
>> "%~1" echo bQBhAHIAZwBpAG4AOgAzADAAcAB4ACAAYQB1AHQAbwA7AGIAYQBjAGsAZwByAG8A
>> "%~1" echo dQBuAGQAOgB2AGEAcgAoAC0ALQBwAGEAcABlAHIAKQA7AGIAbwByAGQAZQByADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAAjAGQAZgBlADYAZgAwADsAYgBvAHgALQBzAGgA
>> "%~1" echo YQBkAG8AdwA6AHYAYQByACgALQAtAHMAaABhAGQAbwB3ACkAfQAuAHAAYQBkAHsA
>> "%~1" echo cABhAGQAZABpAG4AZwA6ADMAOABwAHgAIAA0ADQAcAB4AH0ALgBhAGMAdABpAG8A
>> "%~1" echo bgBzAHsAcABvAHMAaQB0AGkAbwBuADoAcwB0AGkAYwBrAHkAOwB0AG8AcAA6ADAA
>> "%~1" echo OwB6AC0AaQBuAGQAZQB4ADoAMwA7AGQAaQBzAHAAbABhAHkAOgBmAGwAZQB4ADsA
>> "%~1" echo agB1AHMAdABpAGYAeQAtAGMAbwBuAHQAZQBuAHQAOgBmAGwAZQB4AC0AZQBuAGQA
>> "%~1" echo OwBnAGEAcAA6ADgAcAB4ADsAdwBpAGQAdABoADoAbQBpAG4AKAAxADEAMgAwAHAA
>> "%~1" echo eAAsAGMAYQBsAGMAKAAxADAAMAAlACAALQAgADQAMABwAHgAKQApADsAbQBhAHIA
>> "%~1" echo ZwBpAG4AOgAxADgAcAB4ACAAYQB1AHQAbwAgAC0AMQA2AHAAeAB9AC4AYgB0AG4A
>> "%~1" echo ewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBjAGIAZAA1AGUA
>> "%~1" echo MQA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgAjAGYAZgBmADsAYwBvAGwAbwByADoA
>> "%~1" echo IwAwAGYAMQA3ADIAYQA7AGIAbwByAGQAZQByAC0AcgBhAGQAaQB1AHMAOgA2AHAA
>> "%~1" echo eAA7AHAAYQBkAGQAaQBuAGcAOgA4AHAAeAAgADEAMgBwAHgAOwBmAG8AbgB0AC0A
>> "%~1" echo dwBlAGkAZwBoAHQAOgA4ADAAMAA7AGMAdQByAHMAbwByADoAcABvAGkAbgB0AGUA
>> "%~1" echo cgB9AC4AYgB0AG4ALgBwAHIAaQBtAGEAcgB5AHsAYgBhAGMAawBnAHIAbwB1AG4A
>> "%~1" echo ZAA6AHYAYQByACgALQAtAGEAYwBjAGUAbgB0ACkAOwBiAG8AcgBkAGUAcgAtAGMA
>> "%~1" echo bwBsAG8AcgA6AHYAYQByACgALQAtAGEAYwBjAGUAbgB0ACkAOwBjAG8AbABvAHIA
>> "%~1" echo OgAjAGYAZgBmAH0ALgBkAG8AYwAtAGgAZQBhAGQAewBkAGkAcwBwAGwAYQB5ADoA
>> "%~1" echo ZwByAGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0A
>> "%~1" echo bgBzADoAMQBmAHIAIAAzADQAMABwAHgAOwBnAGEAcAA6ADIAOABwAHgAOwBiAG8A
>> "%~1" echo cgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMwBwAHgAIABzAG8AbABpAGQAIAB2AGEA
>> "%~1" echo cgAoAC0ALQBhAGMAYwBlAG4AdAAyACkAOwBwAGEAZABkAGkAbgBnAC0AYgBvAHQA
>> "%~1" echo dABvAG0AOgAyADQAcAB4AH0ALgBrAGkAYwBrAGUAcgB7AGQAaQBzAHAAbABhAHkA
>> "%~1" echo OgBpAG4AbABpAG4AZQAtAGIAbABvAGMAawA7AGMAbwBsAG8AcgA6AHYAYQByACgA
>> "%~1" echo LQAtAGEAYwBjAGUAbgB0ACkAOwBmAG8AbgB0AC0AcwBpAHoAZQA6ADEAMgBwAHgA
>> "%~1" echo OwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAA7AGwAZQB0AHQAZQByAC0A
>> "%~1" echo cwBwAGEAYwBpAG4AZwA6AC4AMAA4AGUAbQA7AHQAZQB4AHQALQB0AHIAYQBuAHMA
>> "%~1" echo ZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlADsAbQBhAHIAZwBpAG4ALQBiAG8A
>> "%~1" echo dAB0AG8AbQA6ADEAMABwAHgAfQBoADEAewBmAG8AbgB0AC0AcwBpAHoAZQA6ADMA
>> "%~1" echo MgBwAHgAOwBsAGkAbgBlAC0AaABlAGkAZwBoAHQAOgAxAC4AMQAyADsAbQBhAHIA
>> "%~1" echo ZwBpAG4AOgAwACAAMAAgADEAMABwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQA
>> "%~1" echo OgA5ADAAMAA7AGMAbwBsAG8AcgA6ACMAMABmADEANwAyAGEAfQAuAHMAdQBiAHsA
>> "%~1" echo YwBvAGwAbwByADoAdgBhAHIAKAAtAC0AbQB1AHQAZQBkACkAOwBtAGEAeAAtAHcA
>> "%~1" echo aQBkAHQAaAA6ADYAOAAwAHAAeAA7AG0AYQByAGcAaQBuADoAMAB9AC4AbQBlAHQA
>> "%~1" echo YQB7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0A
>> "%~1" echo LQBsAGkAbgBlACkAOwBhAGwAaQBnAG4ALQBzAGUAbABmADoAcwB0AGEAcgB0ADsA
>> "%~1" echo bQBpAG4ALQB3AGkAZAB0AGgAOgAwAH0ALgBtAGUAdABhAC0AcgBvAHcAewBkAGkA
>> "%~1" echo cwBwAGwAYQB5ADoAZwByAGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUA
>> "%~1" echo LQBjAG8AbAB1AG0AbgBzADoAMQAxADgAcAB4ACAAbQBpAG4AbQBhAHgAKAAwACwA
>> "%~1" echo MQBmAHIAKQA7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0AOgAxAHAAeAAgAHMA
>> "%~1" echo bwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAMgApADsAbQBpAG4ALQBoAGUA
>> "%~1" echo aQBnAGgAdAA6ADMAOABwAHgAfQAuAG0AZQB0AGEALQByAG8AdwA6AGwAYQBzAHQA
>> "%~1" echo LQBjAGgAaQBsAGQAewBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMAB9AC4A
>> "%~1" echo bQBlAHQAYQAtAHIAbwB3ACAAcwBwAGEAbgB7AGIAYQBjAGsAZwByAG8AdQBuAGQA
>> "%~1" echo OgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBjAG8AbABvAHIAOgB2AGEAcgAoAC0A
>> "%~1" echo LQBtAHUAdABlAGQAKQA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwADsA
>> "%~1" echo cABhAGQAZABpAG4AZwA6ADkAcAB4ACAAMQAyAHAAeAA7AGIAbwByAGQAZQByAC0A
>> "%~1" echo cgBpAGcAaAB0ADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkA
>> "%~1" echo bgBlADIAKQB9AC4AbQBlAHQAYQAtAHIAbwB3ACAAYgB7AHAAYQBkAGQAaQBuAGcA
>> "%~1" echo OgA5AHAAeAAgADEAMgBwAHgAOwBtAGkAbgAtAHcAaQBkAHQAaAA6ADAAOwBvAHYA
>> "%~1" echo ZQByAGYAbABvAHcALQB3AHIAYQBwADoAYQBuAHkAdwBoAGUAcgBlADsAdwBvAHIA
>> "%~1" echo ZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEAawAtAHcAbwByAGQAfQAuAHMAdABhAG0A
>> "%~1" echo cAB7AGQAaQBzAHAAbABhAHkAOgBpAG4AbABpAG4AZQAtAGIAbABvAGMAawA7AGIA
>> "%~1" echo bwByAGQAZQByADoAMgBwAHgAIABzAG8AbABpAGQAIAABF3YAYQByACgALQAtAHcA
>> "%~1" echo YQByAG4AKQABE3YAYQByACgALQAtAG8AawApAAEPOwBjAG8AbABvAHIAOgAAmwc7
>> "%~1" echo AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwADsAcABhAGQAZABpAG4AZwA6
>> "%~1" echo ADQAcAB4ACAAOABwAHgAOwBiAG8AcgBkAGUAcgAtAHIAYQBkAGkAdQBzADoANABw
>> "%~1" echo AHgAOwB0AHIAYQBuAHMAZgBvAHIAbQA6AHIAbwB0AGEAdABlACgALQAxAGQAZQBn
>> "%~1" echo ACkAfQAuAHAAYQByAHQAeQAtAGcAcgBpAGQAewBkAGkAcwBwAGwAYQB5ADoAZwBy
>> "%~1" echo AGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBz
>> "%~1" echo ADoAMQBmAHIAIAAxAGYAcgA7AGcAYQBwADoAMQA4AHAAeAA7AG0AYQByAGcAaQBu
>> "%~1" echo ADoAMgA2AHAAeAAgADAAfQAuAGIAbwB4AHsAYgBvAHIAZABlAHIAOgAxAHAAeAAg
>> "%~1" echo AHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAKQA7AGIAYQBjAGsAZwBy
>> "%~1" echo AG8AdQBuAGQAOgAjAGYAZgBmADsAbQBpAG4ALQB3AGkAZAB0AGgAOgAwAH0ALgBi
>> "%~1" echo AG8AeAAgAGgAMgAsAC4AcwBlAGMAdABpAG8AbgAgAGgAMgB7AGYAbwBuAHQALQBz
>> "%~1" echo AGkAegBlADoAMQAzAHAAeAA7AHQAZQB4AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6
>> "%~1" echo AHUAcABwAGUAcgBjAGEAcwBlADsAbABlAHQAdABlAHIALQBzAHAAYQBjAGkAbgBn
>> "%~1" echo ADoALgAwADgAZQBtADsAYwBvAGwAbwByADoAIwAzADQANAAwADUANAA7AG0AYQBy
>> "%~1" echo AGcAaQBuADoAMAA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBz
>> "%~1" echo AG8AZgB0ACkAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABz
>> "%~1" echo AG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBwAGEAZABkAGkAbgBn
>> "%~1" echo ADoAMQAwAHAAeAAgADEAMgBwAHgAfQAuAGIAbwB4AC0AYgBvAGQAeQB7AHAAYQBk
>> "%~1" echo AGQAaQBuAGcAOgAxADMAcAB4ACAAMQA0AHAAeAB9AC4AYgBpAGcAewBmAG8AbgB0
>> "%~1" echo AC0AcwBpAHoAZQA6ADIAMgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA5
>> "%~1" echo ADAAMAA7AG0AYQByAGcAaQBuAC0AYgBvAHQAdABvAG0AOgA2AHAAeAB9AC4AbQB1
>> "%~1" echo AHQAZQBkAHsAYwBvAGwAbwByADoAdgBhAHIAKAAtAC0AbQB1AHQAZQBkACkAfQAu
>> "%~1" echo AGMAaABpAHAAcwB7AGQAaQBzAHAAbABhAHkAOgBmAGwAZQB4ADsAZgBsAGUAeAAt
>> "%~1" echo AHcAcgBhAHAAOgB3AHIAYQBwADsAZwBhAHAAOgA3AHAAeAA7AG0AYQByAGcAaQBu
>> "%~1" echo AC0AdABvAHAAOgAxADIAcAB4AH0ALgBjAGgAaQBwAHsAYgBvAHIAZABlAHIAOgAx
>> "%~1" echo AHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAKQA7AGIAYQBj
>> "%~1" echo AGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBiAG8AcgBk
>> "%~1" echo AGUAcgAtAHIAYQBkAGkAdQBzADoAOQA5ADkAcAB4ADsAcABhAGQAZABpAG4AZwA6
>> "%~1" echo ADUAcAB4ACAAOQBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAB9
>> "%~1" echo AC4AcwB1AG0AbQBhAHIAeQB7AGQAaQBzAHAAbABhAHkAOgBnAHIAaQBkADsAZwBy
>> "%~1" echo AGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgByAGUAcABl
>> "%~1" echo AGEAdAAoADQALABtAGkAbgBtAGEAeAAoADAALAAxAGYAcgApACkAOwBiAG8AcgBk
>> "%~1" echo AGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQAp
>> "%~1" echo ADsAbQBhAHIAZwBpAG4AOgAyADAAcAB4ACAAMAAgADIANABwAHgAfQAuAHMAdQBt
>> "%~1" echo AC0AYwBlAGwAbAB7AHAAYQBkAGQAaQBuAGcAOgAxADMAcAB4ACAAMQA0AHAAeAA7
>> "%~1" echo AGIAbwByAGQAZQByAC0AcgBpAGcAaAB0ADoAMQBwAHgAIABzAG8AbABpAGQAIAB2
>> "%~1" echo AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9
>> "%~1" echo AC4AcwB1AG0ALQBjAGUAbABsADoAbABhAHMAdAAtAGMAaABpAGwAZAB7AGIAbwBy
>> "%~1" echo AGQAZQByAC0AcgBpAGcAaAB0ADoAMAB9AC4AcwB1AG0ALQBjAGUAbABsACAAcwBw
>> "%~1" echo AGEAbgB7AGQAaQBzAHAAbABhAHkAOgBiAGwAbwBjAGsAOwBjAG8AbABvAHIAOgB2
>> "%~1" echo AGEAcgAoAC0ALQBtAHUAdABlAGQAKQA7AGYAbwBuAHQALQBzAGkAegBlADoAMQAy
>> "%~1" echo AHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwADsAdABlAHgAdAAt
>> "%~1" echo AHQAcgBhAG4AcwBmAG8AcgBtADoAdQBwAHAAZQByAGMAYQBzAGUAfQAuAHMAdQBt
>> "%~1" echo AC0AYwBlAGwAbAAgAGIAewBkAGkAcwBwAGwAYQB5ADoAYgBsAG8AYwBrADsAZgBv
>> "%~1" echo AG4AdAAtAHMAaQB6AGUAOgAxADgAcAB4ADsAbQBhAHIAZwBpAG4ALQB0AG8AcAA6
>> "%~1" echo ADUAcAB4ADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcAaABl
>> "%~1" echo AHIAZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8AcgBk
>> "%~1" echo AH0ALgBzAGUAYwB0AGkAbwBuAHsAbQBhAHIAZwBpAG4ALQB0AG8AcAA6ADIAMgBw
>> "%~1" echo AHgAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQB7AHcAaQBkAHQAaAA6ADEAMAAw
>> "%~1" echo ACUAOwBiAG8AcgBkAGUAcgAtAGMAbwBsAGwAYQBwAHMAZQA6AGMAbwBsAGwAYQBw
>> "%~1" echo AHMAZQA7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAo
>> "%~1" echo AC0ALQBsAGkAbgBlACkAOwB0AGEAYgBsAGUALQBsAGEAeQBvAHUAdAA6AGYAaQB4
>> "%~1" echo AGUAZAB9AC4AYQB1AGQAaQB0AC0AdABhAGIAbABlACAAdABoAHsAYgBhAGMAawBn
>> "%~1" echo AHIAbwB1AG4AZAA6ACMAZgAyAGYANQBmADkAOwBjAG8AbABvAHIAOgAjADMANAA0
>> "%~1" echo ADAANQA0ADsAdABlAHgAdAAtAGEAbABpAGcAbgA6AGwAZQBmAHQAOwBmAG8AbgB0
>> "%~1" echo AC0AcwBpAHoAZQA6ADEAMgBwAHgAOwB0AGUAeAB0AC0AdAByAGEAbgBzAGYAbwBy
>> "%~1" echo AG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AGwAZQB0AHQAZQByAC0AcwBwAGEAYwBp
>> "%~1" echo AG4AZwA6AC4AMAA2AGUAbQA7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0AOgAy
>> "%~1" echo AHAAeAAgAHMAbwBsAGkAZAAgACMAMQAxADEAOAAyADcAOwBwAGEAZABkAGkAbgBn
>> "%~1" echo ADoAMQAwAHAAeAAgADEAMgBwAHgAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAg
>> "%~1" echo AHQAZAB7AGIAbwByAGQAZQByAC0AdABvAHAAOgAxAHAAeAAgAHMAbwBsAGkAZAAg
>> "%~1" echo AHYAYQByACgALQAtAGwAaQBuAGUAMgApADsAcABhAGQAZABpAG4AZwA6ADEAMABw
>> "%~1" echo AHgAIAAxADIAcAB4ADsAdgBlAHIAdABpAGMAYQBsAC0AYQBsAGkAZwBuADoAdABv
>> "%~1" echo AHAAOwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoAYQBuAHkAdwBoAGUAcgBl
>> "%~1" echo ADsAdwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEAawAtAHcAbwByAGQAfQAu
>> "%~1" echo AGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkAbABk
>> "%~1" echo ACgAMQApAHsAdwBpAGQAdABoADoAMgAyACUAOwBjAG8AbABvAHIAOgAjADQANwA1
>> "%~1" echo ADQANgA3ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOAAwADAAfQAuAGEAdQBk
>> "%~1" echo AGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkAbABkACgAMgAp
>> "%~1" echo AHsAdwBpAGQAdABoADoANAA0ACUAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4
>> "%~1" echo ADAAMAA7AGMAbwBsAG8AcgA6ACMAMQAwADEAOAAyADgAfQAuAGEAdQBkAGkAdAAt
>> "%~1" echo AHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkAbABkACgAMwApAHsAdwBp
>> "%~1" echo AGQAdABoADoAMwA0ACUAOwBjAG8AbABvAHIAOgAjADYANgA3ADAAOAA1AH0ALgBu
>> "%~1" echo AG8AdABlAHsAYgBvAHIAZABlAHIALQBsAGUAZgB0ADoANABwAHgAIABzAG8AbABp
>> "%~1" echo AGQAIAB2AGEAcgAoAC0ALQB3AGEAcgBuACkAOwBiAGEAYwBrAGcAcgBvAHUAbgBk
>> "%~1" echo ADoAIwBmAGYAZgA4AGUAYgA7AGIAbwByAGQAZQByAC0AdABvAHAAOgAxAHAAeAAg
>> "%~1" echo AHMAbwBsAGkAZAAgACMAZgAzAGQAMQA5AGMAOwBiAG8AcgBkAGUAcgAtAHIAaQBn
>> "%~1" echo AGgAdAA6ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBmADMAZAAxADkAYwA7AGIAbwBy
>> "%~1" echo AGQAZQByAC0AYgBvAHQAdABvAG0AOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAZgAz
>> "%~1" echo AGQAMQA5AGMAOwBwAGEAZABkAGkAbgBnADoAMQAzAHAAeAAgADEANABwAHgAOwBt
>> "%~1" echo AGEAcgBnAGkAbgAtAHQAbwBwADoAMQA4AHAAeAB9AC4AcgBhAHcAIABkAGUAdABh
>> "%~1" echo AGkAbABzAHsAYgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQBy
>> "%~1" echo ACgALQAtAGwAaQBuAGUAKQA7AG0AYQByAGcAaQBuADoAMQAwAHAAeAAgADAAOwBi
>> "%~1" echo AGEAYwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgB9AC4AcgBhAHcAIABzAHUAbQBt
>> "%~1" echo AGEAcgB5AHsAYwB1AHIAcwBvAHIAOgBwAG8AaQBuAHQAZQByADsAYgBhAGMAawBn
>> "%~1" echo AHIAbwB1AG4AZAA6AHYAYQByACgALQAtAHMAbwBmAHQAKQA7AHAAYQBkAGQAaQBu
>> "%~1" echo AGcAOgAxADAAcAB4ACAAMQAyAHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6
>> "%~1" echo ADkAMAAwAH0ALgByAGEAdwAgAHAAcgBlAHsAbQBhAHIAZwBpAG4AOgAwADsAbQBh
>> "%~1" echo AHgALQBoAGUAaQBnAGgAdAA6ADQAMgAwAHAAeAA7AG8AdgBlAHIAZgBsAG8AdwA6
>> "%~1" echo AGEAdQB0AG8AOwB3AGgAaQB0AGUALQBzAHAAYQBjAGUAOgBwAHIAZQAtAHcAcgBh
>> "%~1" echo AHAAOwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoAYQBuAHkAdwBoAGUAcgBl
>> "%~1" echo ADsAdwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEAawAtAHcAbwByAGQAOwBj
>> "%~1" echo AG8AbABvAHIAOgAjADQANwA1ADQANgA3ADsAcABhAGQAZABpAG4AZwA6ADEAMgBw
>> "%~1" echo AHgAOwBmAG8AbgB0ADoAMQAyAHAAeAAvADEALgA1ACAAQwBvAG4AcwBvAGwAYQBz
>> "%~1" echo ACwAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFkAYQBIAGUAaQAiACwAbQBvAG4AbwBz
>> "%~1" echo AHAAYQBjAGUAfQAuAGYAbwBvAHQAewBkAGkAcwBwAGwAYQB5ADoAZwByAGkAZAA7
>> "%~1" echo AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQBm
>> "%~1" echo AHIAIABhAHUAdABvADsAZwBhAHAAOgAyADAAcAB4ADsAYQBsAGkAZwBuAC0AaQB0
>> "%~1" echo AGUAbQBzADoAZQBuAGQAOwBtAGEAcgBnAGkAbgAtAHQAbwBwADoAMgA4AHAAeAA7
>> "%~1" echo AGIAbwByAGQAZQByAC0AdABvAHAAOgAyAHAAeAAgAHMAbwBsAGkAZAAgACMAMQAx
>> "%~1" echo ADEAOAAyADcAOwBwAGEAZABkAGkAbgBnAC0AdABvAHAAOgAxADYAcAB4AH0ALgBm
>> "%~1" echo AG8AbwB0ACAAYgB7AGYAbwBuAHQALQBzAGkAegBlADoAMQAyAHAAeAA7AHQAZQB4
>> "%~1" echo AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlADsAbABl
>> "%~1" echo AHQAdABlAHIALQBzAHAAYQBjAGkAbgBnADoALgAwADgAZQBtAH0ALgB0AG8AdABh
>> "%~1" echo AGwAewBtAGkAbgAtAHcAaQBkAHQAaAA6ADIANQAwAHAAeAA7AGIAbwByAGQAZQBy
>> "%~1" echo ADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAfQAu
>> "%~1" echo AHQAbwB0AGEAbAAgAGQAaQB2AHsAZABpAHMAcABsAGEAeQA6AGcAcgBpAGQAOwBn
>> "%~1" echo AHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEAZgBy
>> "%~1" echo ACAAYQB1AHQAbwA7AHAAYQBkAGQAaQBuAGcAOgA5AHAAeAAgADEAMgBwAHgAOwBi
>> "%~1" echo AG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABzAG8AbABpAGQAIAB2
>> "%~1" echo AGEAcgAoAC0ALQBsAGkAbgBlADIAKQB9AC4AdABvAHQAYQBsACAAZABpAHYAOgBs
>> "%~1" echo AGEAcwB0AC0AYwBoAGkAbABkAHsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6
>> "%~1" echo ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0AcwBvAGYAdAAp
>> "%~1" echo ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOQAwADAAfQBAAG0AZQBkAGkAYQAo
>> "%~1" echo AG0AYQB4AC0AdwBpAGQAdABoADoAOAA2ADAAcAB4ACkAewAuAGQAbwBjAC0AaABl
>> "%~1" echo AGEAZAAsAC4AcABhAHIAdAB5AC0AZwByAGkAZAAsAC4AcwB1AG0AbQBhAHIAeQB7
>> "%~1" echo AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQBm
>> "%~1" echo AHIAfQAuAHAAYQBkAHsAcABhAGQAZABpAG4AZwA6ADIANABwAHgAIAAxADgAcAB4
>> "%~1" echo AH0ALgBzAGgAZQBlAHQALAAuAGEAYwB0AGkAbwBuAHMAewB3AGkAZAB0AGgAOgBj
>> "%~1" echo AGEAbABjACgAMQAwADAAJQAgAC0AIAAxADgAcAB4ACkAfQAuAHMAdQBtAG0AYQBy
>> "%~1" echo AHkAewBkAGkAcwBwAGwAYQB5ADoAYgBsAG8AYwBrAH0ALgBzAHUAbQAtAGMAZQBs
>> "%~1" echo AGwAewBiAG8AcgBkAGUAcgAtAHIAaQBnAGgAdAA6ADAAOwBiAG8AcgBkAGUAcgAt
>> "%~1" echo AGIAbwB0AHQAbwBtADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBs
>> "%~1" echo AGkAbgBlADIAKQB9AC4AYQB1AGQAaQB0AC0AdABhAGIAbABlAHsAdABhAGIAbABl
>> "%~1" echo AC0AbABhAHkAbwB1AHQAOgBhAHUAdABvAH0ALgBhAHUAZABpAHQALQB0AGEAYgBs
>> "%~1" echo AGUAIAB0AGgAOgBuAHQAaAAtAGMAaABpAGwAZAAoADMAKQAsAC4AYQB1AGQAaQB0
>> "%~1" echo AC0AdABhAGIAbABlACAAdABkADoAbgB0AGgALQBjAGgAaQBsAGQAKAAzACkAewBk
>> "%~1" echo AGkAcwBwAGwAYQB5ADoAbgBvAG4AZQB9AC4AZgBvAG8AdAB7AGcAcgBpAGQALQB0
>> "%~1" echo AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQBmAHIAfQAuAHQAbwB0
>> "%~1" echo AGEAbAB7AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9AH0AQABtAGUAZABpAGEAKABt
>> "%~1" echo AGEAeAAtAHcAaQBkAHQAaAA6ADUAMgAwAHAAeAApAHsALgBtAGUAdABhAC0AcgBv
>> "%~1" echo AHcAewBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6
>> "%~1" echo ADEAMAA1AHAAeAAgAG0AaQBuAG0AYQB4ACgAMAAsADEAZgByACkAfQBoADEAewBm
>> "%~1" echo AG8AbgB0AC0AcwBpAHoAZQA6ADIAOABwAHgAfQAuAGEAYwB0AGkAbwBuAHMAewBq
>> "%~1" echo AHUAcwB0AGkAZgB5AC0AYwBvAG4AdABlAG4AdAA6AGYAbABlAHgALQBzAHQAYQBy
>> "%~1" echo AHQAOwBvAHYAZQByAGYAbABvAHcAOgBhAHUAdABvAH0AfQBAAG0AZQBkAGkAYQAg
>> "%~1" echo AHAAcgBpAG4AdAB7AGIAbwBkAHkAewBiAGEAYwBrAGcAcgBvAHUAbgBkADoAIwBm
>> "%~1" echo AGYAZgB9AC4AYQBjAHQAaQBvAG4AcwB7AGQAaQBzAHAAbABhAHkAOgBuAG8AbgBl
>> "%~1" echo AH0ALgBzAGgAZQBlAHQAewB3AGkAZAB0AGgAOgBhAHUAdABvADsAbQBhAHIAZwBp
>> "%~1" echo AG4AOgAwADsAYgBvAHIAZABlAHIAOgAwADsAYgBvAHgALQBzAGgAYQBkAG8AdwA6
>> "%~1" echo AG4AbwBuAGUAfQAuAHAAYQBkAHsAcABhAGQAZABpAG4AZwA6ADAAfQAuAHIAYQB3
>> "%~1" echo ACAAcAByAGUAewBtAGEAeAAtAGgAZQBpAGcAaAB0ADoAbgBvAG4AZQB9AC4AYgBv
>> "%~1" echo AHgALAAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAsAC4AcgBhAHcAIABkAGUAdABh
>> "%~1" echo AGkAbABzAHsAYgByAGUAYQBrAC0AaQBuAHMAaQBkAGUAOgBhAHYAbwBpAGQAfQBA
>> "%~1" echo AHAAYQBnAGUAewBzAGkAegBlADoAQQA0ADsAbQBhAHIAZwBpAG4AOgAxADMAbQBt
>> "%~1" echo AH0AfQABKzwALwBzAHQAeQBsAGUAPgA8AC8AaABlAGEAZAA+ADwAYgBvAGQAeQA+
>> "%~1" echo AACBmTwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGEAYwB0AGkAbwBuAHMAIgA+ADwA
>> "%~1" echo YgB1AHQAdABvAG4AIABjAGwAYQBzAHMAPQAiAGIAdABuACAAcAByAGkAbQBhAHIA
>> "%~1" echo eQAiACAAbwBuAGMAbABpAGMAawA9ACIAdwBpAG4AZABvAHcALgBwAHIAaQBuAHQA
>> "%~1" echo KAApACIAPgBTYnBTIAAvACAA3U9YWyAAUABEAEYAPAAvAGIAdQB0AHQAbwBuAD4A
>> "%~1" echo PABiAHUAdAB0AG8AbgAgAGMAbABhAHMAcwA9ACIAYgB0AG4AIgAgAG8AbgBjAGwA
>> "%~1" echo aQBjAGsAPQAiAGQAbwBjAHUAbQBlAG4AdAAuAHEAdQBlAHIAeQBTAGUAbABlAGMA
>> "%~1" echo dABvAHIAQQBsAGwAKAAnAGQAZQB0AGEAaQBsAHMAJwApAC4AZgBvAHIARQBhAGMA
>> "%~1" echo aAAoAGQAPQA+AGQALgBvAHAAZQBuAD0AdAByAHUAZQApACIAPgBVXABfRJZVXzwA
>> "%~1" echo LwBiAHUAdAB0AG8AbgA+ADwALwBkAGkAdgA+AAFLPABtAGEAaQBuACAAYwBsAGEA
>> "%~1" echo cwBzAD0AIgBzAGgAZQBlAHQAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHAA
>> "%~1" echo YQBkACIAPgAAgcE8AGgAZQBhAGQAZQByACAAYwBsAGEAcwBzAD0AIgBkAG8AYwAt
>> "%~1" echo AGgAZQBhAGQAIgA+ADwAZABpAHYAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBr
>> "%~1" echo AGkAYwBrAGUAcgAiAD4AUQB1AGUAcwB0ACAAQQBEAEIAIABUAG8AbwBsAHMAIAAv
>> "%~1" echo ACAAUgBlAGEAZAAtAG8AbgBsAHkAIABlAHgAcABvAHIAdAA8AC8AZABpAHYAPgA8
>> "%~1" echo AGgAMQA+AFEAdQBlAHMAdAAgAEEARABCACAAvosHWaFboYulYkpUPAAvAGgAMQA+
>> "%~1" echo ADwAcAAgAGMAbABhAHMAcwA9ACIAcwB1AGIAIgA+APpXjk5sUQBfIABBAEQAQgAg
>> "%~1" echo AOpT+4t9VOROH3UQYgz/KHWOTnRlBnQgAFEAdQBlAHMAdAAgADRZPmarjv1OATD7
>> "%~1" echo fN9+ATBlULdeATDlXYJTLwAhaMZRv34ifQEwBVMOTv2Am1ICMPxb+lFBbQt6DU6Z
>> "%~1" echo UWVRvotufwz/DU7uTzllvosHWQIwXE8FgEtt1Yu+iwdZSHIsZxr/UQB1AGUAcwB0
>> "%~1" echo ACAAMwACMDwALwBwAD4APAAvAGQAaQB2AD4AAX08AGEAcwBpAGQAZQAgAGMAbABh
>> "%~1" echo AHMAcwA9ACIAbQBlAHQAYQAiAD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAbQBl
>> "%~1" echo AHQAYQAtAHIAbwB3ACIAPgA8AHMAcABhAG4APgClYkpUFn/3UzwALwBzAHAAYQBu
>> "%~1" echo AD4APABiAD4AAWk8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABzAHAAYQBuAD4AH3UQYvZl9JU8
>> "%~1" echo AC8AcwBwAGEAbgA+ADwAYgA+AAGAizwALwBiAD4APAAvAGQAaQB2AD4APABkAGkA
>> "%~1" echo dgAgAGMAbABhAHMAcwA9ACIAbQBlAHQAYQAtAHIAbwB3ACIAPgA8AHMAcABhAG4A
>> "%~1" echo PgCQlsF5p34rUjwALwBzAHAAYQBuAD4APABiAD4APABpACAAYwBsAGEAcwBzAD0A
>> "%~1" echo IgBzAHQAYQBtAHAAIgA+AAGAgzwALwBpAD4APAAvAGIAPgA8AC8AZABpAHYAPgA8
>> "%~1" echo AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBtAGUAdABhAC0AcgBvAHcAIgA+ADwAcwBw
>> "%~1" echo AGEAbgA+AEEARABCACAAZWeQbjwALwBzAHAAYQBuAD4APABiACAAdABpAHQAbABl
>> "%~1" echo AD0AIgABBSIAPgAANzwALwBiAD4APAAvAGQAaQB2AD4APAAvAGEAcwBpAGQAZQA+
>> "%~1" echo ADwALwBoAGUAYQBkAGUAcgA+AACAvzwAcwBlAGMAdABpAG8AbgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAcABhAHIAdAB5AC0AZwByAGkAZAAiAD4APABkAGkAdgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAYgBvAHgAIgA+ADwAaAAyAD4AvosHWTwALwBoADIAPgA8AGQAaQB2ACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBiAG8AeAAtAGIAbwBkAHkAIgA+ADwAZABpAHYAIABjAGwA
>> "%~1" echo YQBzAHMAPQAiAGIAaQBnACIAPgABMzwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwA
>> "%~1" echo YQBzAHMAPQAiAG0AdQB0AGUAZAAiAD4AAGc8AC8AZABpAHYAPgA8AGQAaQB2ACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBjAGgAaQBwAHMAIgA+ADwAcwBwAGEAbgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAYwBoAGkAcAAiAD4AUwBlAHIAaQBhAGwAIAAANTwALwBzAHAAYQBuAD4A
>> "%~1" echo PABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBwACIAPgAADyAALwAgAFMA
>> "%~1" echo RABLACAAADM8AC8AcwBwAGEAbgA+ADwALwBkAGkAdgA+ADwALwBkAGkAdgA+ADwA
>> "%~1" echo LwBkAGkAdgA+AACAizwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGIAbwB4ACIAPgA8
>> "%~1" echo AGgAMgA+AMeRxpZWe2V1PAAvAGgAMgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AGIAbwB4AC0AYgBvAGQAeQAiAD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAYgBp
>> "%~1" echo AGcAIgA+AAELwXkJZ4xbdGVIcgELBlKrTolbaFFIcgEz3U9ZdYxbdGXBeQlnwYtu
>> "%~1" echo Ywz/ApAIVCxnOmdZdWNoG/8NToGJ9HalY2xRAF8GUqtOAjABffJdbpA9hY9eF1L3
>> "%~1" echo UwEwQFzfV1F/MFdAVwEwTQBBAEMALwBCAFMAUwBJAEQAATBmAGkAbgBnAGUAcgBw
>> "%~1" echo AHIAaQBuAHQAATBzAGUAcwBzAGkAbwBuACAASXtPZR9hV1u1axv/843HjyAAbABv
>> "%~1" echo AGcAYwBhAHQAIABEllVfAjABgVU8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBsAGEA
>> "%~1" echo cwBzAD0AIgBjAGgAaQBwAHMAIgA+ADwAcwBwAGEAbgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo YwBoAGkAcAAiAD4ATgBvACAAQQBEAEIAIAB3AHIAaQB0AGUAPAAvAHMAcABhAG4A
>> "%~1" echo PgA8AHMAcABhAG4AIABjAGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AEgAVABNAEwA
>> "%~1" echo LwBQAEQARgAgAHIAZQBhAGQAeQA8AC8AcwBwAGEAbgA+ADwAcwBwAGEAbgAgAGMA
>> "%~1" echo bABhAHMAcwA9ACIAYwBoAGkAcAAiAD4AUQB1AGUAcwB0ACAAMwAgAG4AbwB0AGUA
>> "%~1" echo ZAA8AC8AcwBwAGEAbgA+ADwALwBkAGkAdgA+ADwALwBkAGkAdgA+ADwALwBkAGkA
>> "%~1" echo dgA+ADwALwBzAGUAYwB0AGkAbwBuAD4AAICNPABzAGUAYwB0AGkAbwBuACAAYwBs
>> "%~1" echo AGEAcwBzAD0AIgBzAHUAbQBtAGEAcgB5ACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBz
>> "%~1" echo AD0AIgBzAHUAbQAtAGMAZQBsAGwAIgA+ADwAcwBwAGEAbgA+ADV1z5EgAC8AIAAp
>> "%~1" echo bqZePAAvAHMAcABhAG4APgA8AGIAPgABZTwALwBiAD4APAAvAGQAaQB2AD4APABk
>> "%~1" echo AGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0ALQBjAGUAbABsACIAPgA8AHMAcABh
>> "%~1" echo AG4APgA+Zjp5PAAvAHMAcABhAG4APgA8AGIAPgABZTwALwBiAD4APAAvAGQAaQB2
>> "%~1" echo AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0ALQBjAGUAbABsACIAPgA8
>> "%~1" echo AHMAcABhAG4APgBYW6hQPAAvAHMAcABhAG4APgA8AGIAPgABZTwALwBiAD4APAAv
>> "%~1" echo AGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0ALQBjAGUAbABs
>> "%~1" echo ACIAPgA8AHMAcABhAG4APgAhaMZRPAAvAHMAcABhAG4APgA8AGIAPgABKTwALwBi
>> "%~1" echo AD4APAAvAGQAaQB2AD4APAAvAHMAZQBjAHQAaQBvAG4APgAACb6LB1mrjv1OAUFz
>> "%~1" echo AGUAcgBpAGEAbAB8AI9eF1L3U3wAYQBkAGIAIABkAGUAdgBpAGMAZQBzACAALwAg
>> "%~1" echo AGcAZQB0AHAAcgBvAHAAAUNkAGUAdgBpAGMAZQBMAGkAbgBlAHwAQQBEAEIAIAC+
>> "%~1" echo iwdZTIh8AGEAZABiACAAZABlAHYAaQBjAGUAcwAgAC0AbAABT20AYQBuAHUAZgBh
>> "%~1" echo AGMAdAB1AHIAZQByAHwAglNGVXwAcgBvAC4AcAByAG8AZAB1AGMAdAAuAG0AYQBu
>> "%~1" echo AHUAZgBhAGMAdAB1AHIAZQByAAEzYgByAGEAbgBkAHwAwVRMcnwAcgBvAC4AcABy
>> "%~1" echo AG8AZAB1AGMAdAAuAGIAcgBhAG4AZAABM20AbwBkAGUAbAB8AItX91N8AHIAbwAu
>> "%~1" echo AHAAcgBvAGQAdQBjAHQALgBtAG8AZABlAGwAATlwAHIAbwBkAHUAYwB0AHwAp07B
>> "%~1" echo VONO91N8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBuAGEAbQBlAAE7ZABlAHYAaQBj
>> "%~1" echo AGUAfAC+iwdZ4073U3wAcgBvAC4AcAByAG8AZAB1AGMAdAAuAGQAZQB2AGkAYwBl
>> "%~1" echo AAEzYgBvAGEAcgBkAHwAf2enfnwAcgBvAC4AcAByAG8AZAB1AGMAdAAuAGIAbwBh
>> "%~1" echo AHIAZAABKXMAbwBjAHwAUwBvAEMAfAByAG8ALgBzAG8AYwAuAG0AbwBkAGUAbAAA
>> "%~1" echo NWEAYgBpAHwAQQBCAEkAfAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AYwBwAHUALgBh
>> "%~1" echo AGIAaQAAC/t8334OToRn+l4BL2EAbgBkAHIAbwBpAGQAfABBAG4AZAByAG8AaQBk
>> "%~1" echo AHwAZwBlAHQAcAByAG8AcAAAH3MAZABrAHwAUwBEAEsAfABnAGUAdABwAHIAbwBw
>> "%~1" echo AAA5cwBlAGMAdQByAGkAdAB5AFAAYQB0AGMAaAB8APt8336JW2hRZYgBTnwAZwBl
>> "%~1" echo AHQAcAByAG8AcAABP3YAZQBuAGQAbwByAFAAYQB0AGMAaAB8AFYAZQBuAGQAbwBy
>> "%~1" echo ACAAiVtoUWWIAU58AGcAZQB0AHAAcgBvAHAAATFiAHUAaQBsAGQASQBkAHwAQgB1
>> "%~1" echo AGkAbABkACAASQBEAHwAZwBlAHQAcAByAG8AcAAASWIAdQBpAGwAZABJAG4AYwBy
>> "%~1" echo AGUAbQBlAG4AdABhAGwAfABJAG4AYwByAGUAbQBlAG4AdABhAGwAfABnAGUAdABw
>> "%~1" echo AHIAbwBwAAA1YgB1AGkAbABkAEIAcgBhAG4AYwBoAHwAQgByAGEAbgBjAGgAfABn
>> "%~1" echo AGUAdABwAHIAbwBwAAA/ZgBpAG4AZwBlAHIAcAByAGkAbgB0AHwARgBpAG4AZwBl
>> "%~1" echo AHIAcAByAGkAbgB0AHwAZwBlAHQAcAByAG8AcAAALWsAZQByAG4AZQBsAHwASwBl
>> "%~1" echo AHIAbgBlAGwAfAB1AG4AYQBtAGUAIAAtAGEAASE+Zjp5IAAvACAANXWQbiAALwAg
>> "%~1" echo AFF/3H4gAC8AIADtcAE5ZABpAHMAcABsAGEAeQB8AD5mOnlYZIGJfABkAHUAbQBw
>> "%~1" echo AHMAeQBzACAAZABpAHMAcABsAGEAeQABNXAAYQBuAGUAbAB8AGKXf2e/fiJ9fABk
>> "%~1" echo AHUAbQBwAHMAeQBzACAAZABpAHMAcABsAGEAeQABP2IAYQB0AHQAZQByAHkATABl
>> "%~1" echo AHYAZQBsAHwANXXPkXwAZAB1AG0AcABzAHkAcwAgAGIAYQB0AHQAZQByAHkAAUFi
>> "%~1" echo AGEAdAB0AGUAcgB5AFQAZQBtAHAAfAA1dWBsKW6mXnwAZAB1AG0AcABzAHkAcwAg
>> "%~1" echo AGIAYQB0AHQAZQByAHkAAUViAGEAdAB0AGUAcgB5AEgAZQBhAGwAdABoAHwANXVg
>> "%~1" echo bGVQt158AGQAdQBtAHAAcwB5AHMAIABiAGEAdAB0AGUAcgB5AAE9cABvAHcAZQBy
>> "%~1" echo AFMAbwB1AHIAYwBlAHwAm081dXwAZAB1AG0AcABzAHkAcwAgAGIAYQB0AHQAZQBy
>> "%~1" echo AHkAAT13AGEAawBlAGYAdQBsAG4AZQBzAHMAfAAkVZKRtnIBYHwAZAB1AG0AcABz
>> "%~1" echo AHkAcwAgAHAAbwB3AGUAcgABSXMAdABhAHkATwBuAHwA3U8BYyRVkpF8AHMAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAC8AIABkAHUAbQBwAHMAeQBzACAAcABvAHcAZQByAAFJcABy
>> "%~1" echo AG8AeABpAG0AaQB0AHkAfAClY9GPtnIBYHwAZAB1AG0AcABzAHkAcwAgAHMAZQBu
>> "%~1" echo AHMAbwByAHMAZQByAHYAaQBjAGUAAUV0AGgAZQByAG0AYQBsAHwA7XC2cgFgfABk
>> "%~1" echo AHUAbQBwAHMAeQBzACAAdABoAGUAcgBtAGEAbABzAGUAcgB2AGkAYwBlAAEndQBz
>> "%~1" echo AGIAfABVAFMAQgB8AGQAdQBtAHAAcwB5AHMAIAB1AHMAYgAAQ3cAaQBmAGkAfABX
>> "%~1" echo AGkALQBGAGkAfABkAHUAbQBwAHMAeQBzACAAdwBpAGYAaQAgAC8AIABpAHAAIABh
>> "%~1" echo AGQAZAByAAFNYgBsAHUAZQB0AG8AbwB0AGgAfADdhFlyfABkAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAYgBsAHUAZQB0AG8AbwB0AGgAXwBtAGEAbgBhAGcAZQByAAFlYwBhAG0AZQBy
>> "%~1" echo AGEAfAD4djpnLwAgTx9haFZ8AGQAdQBtAHAAcwB5AHMAIABtAGUAZABpAGEALgBj
>> "%~1" echo AGEAbQBlAHIAYQAgAC8AIABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlAAEhcwB0
>> "%~1" echo AG8AcgBhAGcAZQB8AFhbqFB8AGQAZgAgAC0AaAABL20AZQBtAG8AcgB5AHwAhVFY
>> "%~1" echo W3wALwBwAHIAbwBjAC8AbQBlAG0AaQBuAGYAbwABK2MAcAB1AHwAQwBQAFUAfAAv
>> "%~1" echo AHAAcgBvAGMALwBjAHAAdQBpAG4AZgBvAAAzRgBhAGMAdABvAHIAeQAgAC8AIABD
>> "%~1" echo AGEAbABpAGIAcgBhAHQAaQBvAG4AIABDUXBlbmMBX2YAYQBjAHQAbwByAHkARABl
>> "%~1" echo AHYAaQBjAGUAfABEAGUAdgBpAGMAZQBUAHkAcABlAHwAcwBlAG4AcwBvAHIAcwBl
>> "%~1" echo AHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAW2YAYQBjAHQAbwByAHkAQgB1
>> "%~1" echo AGkAbABkAHwAQgB1AGkAbABkAFQAeQBwAGUAfABzAGUAbgBzAG8AcgBzAGUAcgB2
>> "%~1" echo AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABpZgBhAGMAdABvAHIAeQBUAGkAbQBl
>> "%~1" echo AHwARgBhAGMAdABvAHIAeQAgAFQAaQBtAGUAcwB0AGEAbQBwAHwAcwBlAG4AcwBv
>> "%~1" echo AHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAZWYAYQBjAHQAbwBy
>> "%~1" echo AHkATABvAGMAYQB0AGkAbwBuAHwAbABvAGMAYQB0AGkAbwBuAF8AaQBkAHwAcwBl
>> "%~1" echo AG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAYWYAYQBj
>> "%~1" echo AHQAbwByAHkAUwB0AGEAdABpAG8AbgB8AHMAdABhAHQAaQBvAG4AXwBpAGQAfABz
>> "%~1" echo AGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABtZgBh
>> "%~1" echo AGMAdABvAHIAeQBTAHQAYQB0AGkAbwBuAFQAeQBwAGUAfABzAHQAYQB0AGkAbwBu
>> "%~1" echo AF8AdAB5AHAAZQB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABh
>> "%~1" echo AGQAYQB0AGEAAF1mAGEAYwB0AG8AcgB5AFQAZQBzAHQAfABjAGEAbABfAHQAZQBz
>> "%~1" echo AHQAXwBpAGQAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQAYQBk
>> "%~1" echo AGEAdABhAABlZgBhAGMAdABvAHIAeQBPAHAAZQByAGEAdABvAHIAfABvAHAAZQBy
>> "%~1" echo AGEAdABvAHIAXwBpAGQAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBl
>> "%~1" echo AHQAYQBkAGEAdABhAAB1ZgBhAGMAdABvAHIAeQBDAGEAbABpAGIAcgBhAHQAaQBv
>> "%~1" echo AG4AfABjAGEAbABpAGIAcgBhAHQAaQBvAG4AXwB0AHkAcABlAHwAcwBlAG4AcwBv
>> "%~1" echo AHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAd28AbgBsAGkAbgBl
>> "%~1" echo AEMAYQBsAGkAYgByAGEAdABpAG8AbgB8AE8AbgBsAGkAbgBlACAAYwBhAGwAaQBi
>> "%~1" echo AHIAYQB0AGkAbwBuAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0
>> "%~1" echo AGEAZABhAHQAYQAAgX08AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBuAG8AdABlACIA
>> "%~1" echo PgA8AGIAPgCoY61luY9MdRr/PAAvAGIAPgDvU+VOsItVX76LB1nPZQEwbHj2TjaW
>> "%~1" echo tWsBMCFoxlGwi1VfjFTlXYJTS23Vi79+In0M/4tPglkgAFEAdQBlAHMAdAAgADMA
>> "%~1" echo IAAvACAARQB1AHIAZQBrAGEAIAAvACAAUABWAFQAIAAvACAARgBhAGMAdABvAHIA
>> "%~1" echo eQAgAC8AIABPAG4AbABpAG4AZQAgAGMAYQBsAGkAYgByAGEAdABpAG8AbgACMA1O
>> "%~1" echo /YCKYiAAbABvAGMAYQB0AGkAbwBuAF8AaQBkAAEwcwB0AGEAdABpAG8AbgBfAGkA
>> "%~1" echo ZAABMHMAdABhAHQAaQBvAG4AXwB0AHkAcABlACAA71Ngl/t/0YsQYv1WtlsBMM5X
>> "%~1" echo Al4WYndRU0/lXYJTG/9XAGkALQBGAGkAIAD9VrZbAXhfTg1OL2b6UadOMFcCMDwA
>> "%~1" echo LwBkAGkAdgA+AAENBVMOTvt83379gJtSATtwAGEAYwBrAGEAZwBlAHMAfAAFU3Bl
>> "%~1" echo z5F8AHAAbQAgAGwAaQBzAHQAIABwAGEAYwBrAGEAZwBlAHMAAUlmAGUAYQB0AHUA
>> "%~1" echo cgBlAHMAfABGAGUAYQB0AHUAcgBlACAAcGXPkXwAcABtACAAbABpAHMAdAAgAGYA
>> "%~1" echo ZQBhAHQAdQByAGUAcwABc3YAZAB8AFYAaQByAHQAdQBhAGwAIABEAGUAcwBrAHQA
>> "%~1" echo bwBwAHwAZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBnAGUAIABWAGkAcgB0AHUA
>> "%~1" echo YQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBkAAA9dwBhAHIAbgBpAG4A
>> "%~1" echo ZwBzAHwAx5HGlmaLSlR8AGUAeABwAG8AcgB0ACAAYwBvAGwAbABlAGMAdABvAHIA
>> "%~1" echo AYHfPABmAG8AbwB0AGUAcgAgAGMAbABhAHMAcwA9ACIAZgBvAG8AdAAiAD4APABk
>> "%~1" echo AGkAdgA+ADwAYgA+AFEAdQBlAHMAdAAgAEEARABCACAAVABvAG8AbABzACAAYgB5
>> "%~1" echo ACAAZAB3AGcAeAAxADMAMwA3ADwALwBiAD4APABiAHIAPgA8AHMAcABhAG4AIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAG0AdQB0AGUAZAAiAD4AUAB1AGIAbABpAGMAIAByAGUAcABv
>> "%~1" echo ACAAcwBhAG0AcABsAGUAIABtAHUAcwB0ACAAdQBzAGUAIABzAGgAYQByAGUALQBz
>> "%~1" echo AGEAZgBlACAAZQB4AHAAbwByAHQALgAgAFAAcgBpAHYAYQB0AGUAIABmAHUAbABs
>> "%~1" echo ACAAZQB4AHAAbwByAHQAIABpAHMAIABmAG8AcgAgAGwAbwBjAGEAbAAgAGUAdgBp
>> "%~1" echo AGQAZQBuAGMAZQAgAG8AbgBsAHkALgA8AC8AcwBwAGEAbgA+ADwALwBkAGkAdgA+
>> "%~1" echo ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHQAbwB0AGEAbAAiAD4APABkAGkAdgA+
>> "%~1" echo ADwAcwBwAGEAbgA+AFAAYQBjAGsAYQBnAGUAcwA8AC8AcwBwAGEAbgA+ADwAYgA+
>> "%~1" echo AAFPPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2AD4APABzAHAAYQBuAD4ARgBl
>> "%~1" echo AGEAdAB1AHIAZQBzADwALwBzAHAAYQBuAD4APABiAD4AAEs8AC8AYgA+ADwALwBk
>> "%~1" echo AGkAdgA+ADwAZABpAHYAPgA8AHMAcABhAG4APgBTAHQAYQB0AHUAcwA8AC8AcwBw
>> "%~1" echo AGEAbgA+ADwAYgA+AAAPUAByAGkAdgBhAHQAZQAAFVMAaABhAHIAZQAtAHMAYQBm
>> "%~1" echo AGUAATM8AC8AYgA+ADwALwBkAGkAdgA+ADwALwBkAGkAdgA+ADwALwBmAG8AbwB0
>> "%~1" echo AGUAcgA+AAA3PAAvAGQAaQB2AD4APAAvAG0AYQBpAG4APgA8AC8AYgBvAGQAeQA+
>> "%~1" echo ADwALwBoAHQAbQBsAD4AADs8AHMAZQBjAHQAaQBvAG4AIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AHMAZQBjAHQAaQBvAG4AIgA+ADwAaAAyAD4AAIDDPAAvAGgAMgA+ADwAdABhAGIA
>> "%~1" echo bABlACAAYwBsAGEAcwBzAD0AIgBhAHUAZABpAHQALQB0AGEAYgBsAGUAIgA+ADwA
>> "%~1" echo dABoAGUAYQBkAD4APAB0AHIAPgA8AHQAaAA+AFdbtWs8AC8AdABoAD4APAB0AGgA
>> "%~1" echo PgA8UDwALwB0AGgAPgA8AHQAaAA+AMGLbmNlZ5BuPAAvAHQAaAA+ADwALwB0AHIA
>> "%~1" echo PgA8AC8AdABoAGUAYQBkAD4APAB0AGIAbwBkAHkAPgABB0EARABCAAARPAB0AHIA
>> "%~1" echo PgA8AHQAZAA+AAATPAAvAHQAZAA+ADwAdABkAD4AABU8AC8AdABkAD4APAAvAHQA
>> "%~1" echo cgA+AAA1PAAvAHQAYgBvAGQAeQA+ADwALwB0AGEAYgBsAGUAPgA8AC8AcwBlAGMA
>> "%~1" echo dABpAG8AbgA+AABjPABzAGUAYwB0AGkAbwBuACAAYwBsAGEAcwBzAD0AIgBzAGUA
>> "%~1" echo YwB0AGkAbwBuACAAcgBhAHcAIgA+ADwAaAAyAD4An1PLWSAAQQBEAEIAIACTj/pR
>> "%~1" echo RJZVXzwALwBoADIAPgABDWwAbwBnAGMAYQB0AAAxCgAuAC4ALgAgAPJdKmKtZQz/
>> "%~1" echo jFt0ZYVRuVv3iwt3wXkJZ4xbdGVIciAALgAuAC4AASU8AGQAZQB0AGEAaQBsAHMA
>> "%~1" echo PgA8AHMAdQBtAG0AYQByAHkAPgAAByAAtwAgAAEVbQBzACAAtwAgAGUAeABpAHQA
>> "%~1" echo IAABFSAAtwAgAHQAaQBtAGUAbwB1AHQAAR88AC8AcwB1AG0AbQBhAHIAeQA+ADwA
>> "%~1" echo cAByAGUAPgAAITwALwBwAHIAZQA+ADwALwBkAGUAdABhAGkAbABzAD4AABU8AC8A
>> "%~1" echo cwBlAGMAdABpAG8AbgA+AAA5ZwBlAHQAcAByAG8AcAAgAGQAaABjAHAALgB3AGwA
>> "%~1" echo YQBuADAALgBpAHAAYQBkAGQAcgBlAHMAcwAADzAALgAwAC4AMAAuADAAADVpAHAA
>> "%~1" echo IAAtAGYAIABpAG4AZQB0ACAAYQBkAGQAcgAgAHMAaABvAHcAIAB3AGwAYQBuADAA
>> "%~1" echo AQtpAG4AZQB0ACAAAAUiACIAAAMiAAAFXAAiAAADMgAAB0VRNXUtTgEDMwAAAzQA
>> "%~1" echo AAcqZ0VRNXUBAzUAAAfyXUVR4W4BBWNrOF4BBceP7XABBV9jT1cBBcePi1MBAzcA
>> "%~1" echo AAXHj7dRARdBAEMAIABwAG8AdwBlAHIAZQBkADoAAAVBAEMAABlVAFMAQgAgAHAA
>> "%~1" echo bwB3AGUAcgBlAGQAOgAAB1UAUwBCAAAjVwBpAHIAZQBsAGUAcwBzACAAcABvAHcA
>> "%~1" echo ZQByAGUAZAA6AAAF4GW/fgEHKmebTzV1AQM9AAADWwAACV0AOgAgAFsAACtcACIA
>> "%~1" echo XABzACoAOgBcAHMAKgBcACIAKABbAF4AXAAiAF0AKgApAFwAIgAAJ1wAIgBcAHMA
>> "%~1" echo KgA6AFwAcwAqACgAWwBeACwAfQBcAHMAXQArACkAAAsvAGQAYQB0AGEAABEvAHMA
>> "%~1" echo dABvAHIAYQBnAGUAAA0gAHUAcwBlAGQAIAAAE3AAcgBvAGMAZQBzAHMAbwByAAA/
>> "%~1" echo QwBQAFUAIABwAGEAcgB0AFwAcwAqADoAXABzACoAKAAwAHgAWwAwAC0AOQBhAC0A
>> "%~1" echo ZgBBAC0ARgBdACsAKQABEyAAYwBvAHIAZQBzACAALwAgAAAhaQBkAD0AXABkACsA
>> "%~1" echo LABcAHMAKgB3AGkAZAB0AGgAPQAAAzAAAA0gAG0AbwBkAGUAcwAAE0gAQQBMACAA
>> "%~1" echo UgBlAGEAZAB5AAAJSABBAEwAIAAAEWIAYQB0AHQAZQByAHkAIAAAJWMAbwBuAG4A
>> "%~1" echo ZQBjAHQAZQBkAD0AKABbAGEALQB6AF0AKwApAAEnYwBvAG4AZgBpAGcAdQByAGUA
>> "%~1" echo ZAA9ACgAWwBhAC0AegBdACsAKQABOW0AQwB1AHIAcgBlAG4AdABGAHUAbgBjAHQA
>> "%~1" echo aQBvAG4AcwA9ACgAWwBeAFwAbgBcAHIAXQArACkAABVjAG8AbgBuAGUAYwB0AGUA
>> "%~1" echo ZAAgAAAXYwBvAG4AZgBpAGcAdQByAGUAZAAgAAA9cwB0AGEAbgBkAGEAcgBkADoA
>> "%~1" echo XABzACoAKABbADAALQA5AEEALQBaAGEALQB6ACAALgBfAC0AXQArACkAAStGAHIA
>> "%~1" echo ZQBxAHUAZQBuAGMAeQA6AFwAcwAqACgAWwAwAC0AOQBdACsAKQABLUwAaQBuAGsA
>> "%~1" echo IABzAHAAZQBlAGQAOgBcAHMAKgAoAFsAMAAtADkAXQArACkAASVSAFMAUwBJADoA
>> "%~1" echo XABzACoAKAAtAD8AWwAwAC0AOQBdACsAKQABT2kAbgBlAHQAXABzACsAKABbADAA
>> "%~1" echo LQA5AF0AKwBcAC4AWwAwAC0AOQBdACsAXAAuAFsAMAAtADkAXQArAFwALgBbADAA
>> "%~1" echo LQA5AF0AKwApAAEHSQBQACAAABNzAHQAYQBuAGQAYQByAGQAIAAAB00ASAB6AAAJ
>> "%~1" echo TQBiAHAAcwAAC1IAUwBTAEkAIAAAJ2UAbgBhAGIAbABlAGQAOgBcAHMAKgAoAFsA
>> "%~1" echo YQAtAHoAXQArACkAASVzAHQAYQB0AGUAOgBcAHMAKgAoAFsAQQAtAFoAXwBdACsA
>> "%~1" echo KQABIUIAbAB1AGUAdABvAG8AdABoACAAUwB0AGEAdAB1AHMAABFlAG4AYQBiAGwA
>> "%~1" echo ZQBkACAAAF9DAGEAbQBlAHIAYQBEAGUAdgBpAGMAZQBDAGwAaQBlAG4AdAB8AEMA
>> "%~1" echo YQBtAGUAcgBhAFwAcwArAEkARAB8AD0APQAgAEMAYQBtAGUAcgBhACAAZABlAHYA
>> "%~1" echo aQBjAGUAADUiAFMAZQBuAHMAbwByAFQAeQBwAGUAIgBcAHMAKgA6AFwAcwAqACIA
>> "%~1" echo TwBHADAAMQBBACIAADciAFMAZQBuAHMAbwByAFQAeQBwAGUAIgBcAHMAKgA6AFwA
>> "%~1" echo cwAqACIATwBWADcAMgA1ADEAIgAANyIAUwBlAG4AcwBvAHIAVAB5AHAAZQAiAFwA
>> "%~1" echo cwAqADoAXABzACoAIgBJAE0AWAA0ADcAMQAiAAAfIABjAGEAbQBlAHIAYQAgAGUA
>> "%~1" echo bgB0AHIAaQBlAHMAACVjAGEAbAAgAHMAZQBuAHMAbwByAHMAIABPAEcAMAAxAEEA
>> "%~1" echo IAAAFSAALwAgAE8AVgA3ADIANQAxACAAABUgAC8AIABJAE0AWAA0ADcAMQAgAABB
>> "%~1" echo UABhAGMAawBhAGcAZQAgAFsAVgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBwAC4A
>> "%~1" echo QQBuAGQAcgBvAGkAZABdAAARcABhAGMAawBhAGcAZQA6AAAvVgBJAFYARQAgAEIA
>> "%~1" echo dQBzAGkAbgBlAHMAcwAgAFMAdAByAGUAYQBtAGkAbgBnAAA3VgBJAFYARQAgAEIA
>> "%~1" echo dQBzAGkAbgBlAHMAcwAgAFMAdAByAGUAYQBtAGkAbgBnACAAQQBEAEIAAA9BAG4A
>> "%~1" echo ZAByAG8AaQBkAAAdcABsAGEAdABmAG8AcgBtAC0AdABvAG8AbABzAAE1QQBuAGQA
>> "%~1" echo cgBvAGkAZAAgAHAAbABhAHQAZgBvAHIAbQAtAHQAbwBvAGwAcwAgAEEARABCAAEP
>> "%~1" echo YQBkAGIALgBlAHgAZQAAB2EAZABiAAAdQQBEAEIAIABlAHgAZQBjAHUAdABhAGIA
>> "%~1" echo bABlAAALWwBBAC0AWgBdAAELWwAwAC0AOQBdAAEnXABiAFsAQQAtAFoAMAAtADkA
>> "%~1" echo XQB7ADEAMgAsADIAMAB9AFwAYgABTVwAYgAoAFsAMAAtADkAQQAtAEYAYQAtAGYA
>> "%~1" echo XQB7ADIAfQA6ACkAewA1AH0AWwAwAC0AOQBBAC0ARgBhAC0AZgBdAHsAMgB9AFwA
>> "%~1" echo YgABIyoAKgA6ACoAKgA6ACoAKgA6ACoAKgA6ACoAKgA6ACoAKgAAPVwAYgAxADkA
>> "%~1" echo MgBcAC4AMQA2ADgAXAAuAFwAZAB7ADEALAAzAH0AXAAuAFwAZAB7ADEALAAzAH0A
>> "%~1" echo XABiAAAXMQA5ADIALgAxADYAOAAuAHgALgB4AABDXABiADEAMABcAC4AXABkAHsA
>> "%~1" echo MQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAGIA
>> "%~1" echo ABExADAALgB4AC4AeAAuAHgAAGNcAGIAMQA3ADIAXAAuACgAMQBbADYALQA5AF0A
>> "%~1" echo fAAyAFsAMAAtADkAXQB8ADMAWwAwAC0AMQBdACkAXAAuAFwAZAB7ADEALAAzAH0A
>> "%~1" echo XAAuAFwAZAB7ADEALAAzAH0AXABiAAETMQA3ADIALgB4AC4AeAAuAHgAAFEoAFMA
>> "%~1" echo UwBJAEQAfABCAFMAUwBJAEQAfABXAGkAZgBpAFMAcwBpAGQAfABtAFcAaQBmAGkA
>> "%~1" echo SQBuAGYAbwApAFsAXgAsAFwAbgBcAHIAXQAqAAAbJAAxAD0APAByAGUAZABhAGMA
>> "%~1" echo dABlAGQAPgAATXIAbwBcAC4AYgB1AGkAbABkAFwALgBmAGkAbgBnAGUAcgBwAHIA
>> "%~1" echo aQBuAHQAXABdADoAIABcAFsAWwBeAFwAXQBcAG4AXAByAF0AKwAARXIAbwAuAGIA
>> "%~1" echo dQBpAGwAZAAuAGYAaQBuAGcAZQByAHAAcgBpAG4AdABdADoAIABbADwAcgBlAGQA
>> "%~1" echo YQBjAHQAZQBkAD4AACtmAGkAbgBnAGUAcgBwAHIAaQBuAHQAPQBbAF4ALABcAG4A
>> "%~1" echo XAByAF0AKwAALWYAaQBuAGcAZQByAHAAcgBpAG4AdAA9ADwAcgBlAGQAYQBjAHQA
>> "%~1" echo ZQBkAD4AADVvAHMAXwBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAWwBeACwAXABuAFwA
>> "%~1" echo cgBcAFwAfQBdACsAADNvAHMAXwBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAPQA8AHIA
>> "%~1" echo ZQBkAGEAYwB0AGUAZAA+AAAtcwBlAHMAcwBpAG8AbgBfAGkAZABbAF4ALABcAG4A
>> "%~1" echo XAByAFwAXAB9AF0AKwAAK3MAZQBzAHMAaQBvAG4AXwBpAGQAPQA8AHIAZQBkAGEA
>> "%~1" echo YwB0AGUAZAA+AAARPABzAGUAcgBpAGEAbAA+AAAHKgAqACoAAAMNAAA5ZABlAHYA
>> "%~1" echo ZQBsAG8AcABtAGUAbgB0AF8AcwBlAHQAdABpAG4AZwBzAF8AZQBuAGEAYgBsAGUA
>> "%~1" echo ZAAAJWQAZQB2AGkAYwBlAF8AcAByAG8AdgBpAHMAaQBvAG4AZQBkAAAndQBzAGUA
>> "%~1" echo cgBfAHMAZQB0AHUAcABfAGMAbwBtAHAAbABlAHQAZQAAD3cAaQBmAGkAXwBvAG4A
>> "%~1" echo ACFhAGkAcgBwAGwAYQBuAGUAXwBtAG8AZABlAF8AbwBuAAAVaAB0AHQAcABfAHAA
>> "%~1" echo cgBvAHgAeQAAI2cAbABvAGIAYQBsAF8AaAB0AHQAcABfAHAAcgBvAHgAeQAAL2kA
>> "%~1" echo bgBzAHQAYQBsAGwAXwBuAG8AbgBfAG0AYQByAGsAZQB0AF8AYQBwAHAAcwAAOXYA
>> "%~1" echo ZQByAGkAZgBpAGUAcgBfAHYAZQByAGkAZgB5AF8AYQBkAGIAXwBpAG4AcwB0AGEA
>> "%~1" echo bABsAHMAAAMnAAEJJwBcACcAJwABAz8AAAMrAAA/YQBwAHAAbABpAGMAYQB0AGkA
>> "%~1" echo bwBuAC8AagBzAG8AbgA7ACAAYwBoAGEAcgBzAGUAdAA9AHUAdABmAC0AOAABP0gA
>> "%~1" echo VABUAFAALwAxAC4AMQAgADIAMAAwACAATwBLAA0ACgBDAG8AbgB0AGUAbgB0AC0A
>> "%~1" echo VAB5AHAAZQA6ACAAASUNAAoAQwBvAG4AdABlAG4AdAAtAEwAZQBuAGcAdABoADoA
>> "%~1" echo IAABYQ0ACgBDAGEAYwBoAGUALQBDAG8AbgB0AHIAbwBsADoAIABuAG8ALQBzAHQA
>> "%~1" echo bwByAGUADQAKAEMAbwBuAG4AZQBjAHQAaQBvAG4AOgAgAGMAbABvAHMAZQANAAoA
>> "%~1" echo DQAKAAEDewAAByIAOgAiAAADfQAABVwAXAAABVwAbgAABVwAcgAABVwAdAAABVwA
>> "%~1" echo dQAABXgANAAAwAIuAVAAQwBGAGsAYgAyAE4AMABlAFgAQgBsAEkARwBoADAAYgBX
>> "%~1" echo AHcAKwBDAGoAeABvAGQARwAxAHMASQBHAHgAaABiAG0AYwA5AEkAbgBwAG8ATABV
>> "%~1" echo AE4ATwBJAGoANABLAFAARwBoAGwAWQBXAFEAKwBDAGoAeAB0AFoAWABSAGgASQBH
>> "%~1" echo AE4AbwBZAFgASgB6AFoAWABRADkASQBuAFYAMABaAGkAMAA0AEkAagA0AEsAUABH
>> "%~1" echo ADEAbABkAEcARQBnAGIAbQBGAHQAWgBUADAAaQBkAG0AbABsAGQAMwBCAHYAYwBu
>> "%~1" echo AFEAaQBJAEcATgB2AGIAbgBSAGwAYgBuAFEAOQBJAG4AZABwAFoASABSAG8AUABX
>> "%~1" echo AFIAbABkAG0AbABqAFoAUwAxADMAYQBXAFIAMABhAEMAeABwAGIAbQBsADAAYQBX
>> "%~1" echo AEYAcwBMAFgATgBqAFkAVwB4AGwAUABUAEUAaQBQAGcAbwA4AGQARwBsADAAYgBH
>> "%~1" echo AFUAKwBVAFgAVgBsAGMAMwBRAGcAUQBVAFIAQwBJAE8AYQBPAHAAKwBXAEkAdAB1
>> "%~1" echo AFcAUABzAEQAdwB2AGQARwBsADAAYgBHAFUAKwBDAGoAeAB6AGQASABsAHMAWgBU
>> "%~1" echo ADQASwBPAG4ASgB2AGIAMwBSADcATABTADEAaQBaAHoAbwBqAFoAVwBWAG0ATQBX
>> "%~1" echo AFkAMwBPAHkAMAB0AGMAMgBsAGsAWgBUAG8AagBaAG0AWgBtAE8AeQAwAHQAWQAy
>> "%~1" echo AEYAeQBaAEQAbwBqAFoAbQBaAG0ATwB5ADAAdABjADIAOQBtAGQARABvAGoAWgBq
>> "%~1" echo AFYAbQBOADIAWgBpAE8AeQAwAHQAYgBHAGwAdQBaAFQAbwBqAFoAVABKAGwATwBH
>> "%~1" echo AFkAdwBPAHkAMAB0AGQARwBWADQAZABEAG8AagBNAEcAWQB4AE4AegBKAGgATwB5
>> "%~1" echo ADAAdABiAFgAVgAwAFoAVwBRADYASQB6AFkAMABOAHoAUQA0AFkAagBzAHQATABX
>> "%~1" echo AEoAcwBkAFcAVQA2AEkAegBJADEATgBqAE4AbABZAGoAcwB0AEwAVwBKAHMAZABX
>> "%~1" echo AFUAeQBPAGkATQB6AFkAagBnAHkAWgBqAFkANwBMAFMAMQBuAGMAbQBWAGwAYgBq
>> "%~1" echo AG8AagBNAFQAWgBoAE0AegBSAGgATwB5ADAAdABZAFcAMQBpAFoAWABJADYASQAy
>> "%~1" echo AFEANQBOAHoAYwB3AE4AagBzAHQATABYAEoAbABaAEQAbwBqAFoAVABFAHgAWgBE
>> "%~1" echo AFEANABPAHkAMAB0AGIAbQBGADIATwBqAEkAMABOAEgAQgA0AE8AeQAwAHQAYwBt
>> "%~1" echo AEYAawBhAFgAVgB6AE8AagBFAHkAYwBIAGcANwBMAFMAMQB6AGEARwBGAGsAYgAz
>> "%~1" echo AGMANgBNAEMAQQB4AGMASABnAGcATQBuAEIANABJAEgASgBuAFkAbQBFAG8ATQBU
>> "%~1" echo AFUAcwBNAGoATQBzAE4ARABJAHMATABqAEEAMQBLAFMAdwB3AEkARABoAHcAZQBD
>> "%~1" echo AEEAeQBOAEgAQgA0AEkASABKAG4AWQBtAEUAbwBNAFQAVQBzAE0AagBNAHMATgBE
>> "%~1" echo AEkAcwBMAGoAQQAxAEsAWAAwAEsAWQBtADkAawBlAFMANQBrAFkAWABKAHIAZQB5
>> "%~1" echo ADAAdABZAG0AYwA2AEkAegBCAGkATQBHAFkAeABOAGoAcwB0AEwAWABOAHAAWgBH
>> "%~1" echo AFUANgBJAHoAQgBtAE0AVABZAHkATQBEAHMAdABMAFcATgBoAGMAbQBRADYASQB6
>> "%~1" echo AEUAegBNAFcASQB5AE4AagBzAHQATABYAE4AdgBaAG4AUQA2AEkAegBCAG0ATQBU
>> "%~1" echo AGMAeQBNAEQAcwB0AEwAVwB4AHAAYgBtAFUANgBJAHoASQAwAE0AegBBADAATgBE
>> "%~1" echo AHMAdABMAFgAUgBsAGUASABRADYASQAyAFUAMgBaAFcAUgBtAE4AegBzAHQATABX
>> "%~1" echo ADEAMQBkAEcAVgBrAE8AaQBNADUATQAyAEUAeQBZAGoAZwA3AEwAUwAxAHoAYQBH
>> "%~1" echo AEYAawBiADMAYwA2AE0AQwBBAHgAYwBIAGcAZwBNAG4AQgA0AEkASABKAG4AWQBt
>> "%~1" echo AEUAbwBNAEMAdwB3AEwARABBAHMATABqAE0AcABMAEQAQQBnAE0AVABKAHcAZQBD
>> "%~1" echo AEEAegBNAEgAQgA0AEkASABKAG4AWQBtAEUAbwBNAEMAdwB3AEwARABBAHMATABq
>> "%~1" echo AE0AMQBLAFgAMABLAEsAbgB0AGkAYgAzAGcAdABjADIAbAA2AGEAVwA1AG4ATwBt
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAGkAYgAzAGgAOQBhAEgAUgB0AGIAQwB4AGkAYgAy
>> "%~1" echo AFIANQBlADIAMQBoAGMAbQBkAHAAYgBqAG8AdwBPADIAMQBwAGIAaQAxAG8AWgBX
>> "%~1" echo AGwAbgBhAEgAUQA2AE0AVABBAHcASgBUAHQAbQBiADIANQAwAEwAVwBaAGgAYgBX
>> "%~1" echo AGwAcwBlAFQAbwBpAFUAMgBWAG4AYgAyAFUAZwBWAFUAawBpAEwAQwBKAE4AYQBX
>> "%~1" echo AE4AeQBiADMATgB2AFoAbgBRAGcAVwBXAEYASQBaAFcAawBpAEwASABOADUAYwAz
>> "%~1" echo AFIAbABiAFMAMQAxAGEAUwB4AEIAYwBtAGwAaABiAEMAeAB6AFkAVwA1AHoATABY
>> "%~1" echo AE4AbABjAG0AbABtAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAbQBjAHAATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFgAUgBsAGUASABRAHAATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBU
>> "%~1" echo AG8AeABOAEgAQgA0AGYAUQBwAGkAZABYAFIAMABiADIANABzAGEAVwA1AHcAZABY
>> "%~1" echo AFEAcwBjADIAVgBzAFoAVwBOADAAZQAyAFoAdgBiAG4AUQA2AGEAVwA1AG8AWgBY
>> "%~1" echo AEoAcABkAEgAMABLAEwAbQBGAHcAYwBIAHQAdABhAFcANAB0AGEARwBWAHAAWgAy
>> "%~1" echo AGgAMABPAGoARQB3AE0ASABaAG8ATwAyAFIAcABjADMAQgBzAFkAWABrADYAWgAz
>> "%~1" echo AEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABX
>> "%~1" echo AE4AdgBiAEgAVgB0AGIAbgBNADYAZABtAEYAeQBLAEMAMAB0AGIAbQBGADIASwBT
>> "%~1" echo AEEAeABaAG4ASgA5AEMAaQA1AHoAYQBXAFIAbABlADMAQgB2AGMAMgBsADAAYQBX
>> "%~1" echo ADkAdQBPAG0AWgBwAGUARwBWAGsATwAyAGwAdQBjADIAVgAwAE8AagBBAGcAWQBY
>> "%~1" echo AFYAMABiAHkAQQB3AEkARABBADcAZAAyAGwAawBkAEcAZwA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABiAG0ARgAyAEsAVAB0AG8AWgBXAGwAbgBhAEgAUQA2AE0AVABBAHcAZABt
>> "%~1" echo AGcANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABT
>> "%~1" echo ADEAegBhAFcAUgBsAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBsAG4AYQBI
>> "%~1" echo AFEANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABX
>> "%~1" echo AHgAcABiAG0AVQBwAE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBE
>> "%~1" echo AHQAbQBiAEcAVgA0AEwAVwBSAHAAYwBtAFYAagBkAEcAbAB2AGIAagBwAGoAYgAy
>> "%~1" echo AHgAMQBiAFcANAA3AGUAaQAxAHAAYgBtAFIAbABlAEQAbwAxAGYAUQBvAHUAWQBu
>> "%~1" echo AEoAaABiAG0AUgA3AGEARwBWAHAAWgAyAGgAMABPAGoAYwA0AGMASABnADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAG0AYgBHAFYANABPADIARgBzAGEAVwBkAHUATABX
>> "%~1" echo AGwAMABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABuAFkAWABBADYATQBU
>> "%~1" echo AEoAdwBlAEQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAQQBnAE0AagBCAHcAZQBE
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAWQBtADkAMABkAEcAOQB0AE8AagBGAHcAZQBD
>> "%~1" echo AEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBY
>> "%~1" echo ADAASwBMAG0ASgB5AFkAVwA1AGsAUwBXAE4AdgBiAG4AdAAzAGEAVwBSADAAYQBE
>> "%~1" echo AG8AegBPAEgAQgA0AE8AMgBoAGwAYQBXAGQAbwBkAEQAbwB6AE8ASABCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE0AVABCAHcAZQBE
>> "%~1" echo AHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG0AeABwAGIAbQBWAGgAYwBp
>> "%~1" echo ADEAbgBjAG0ARgBrAGEAVwBWAHUAZABDAGcAeABNAHoAVgBrAFoAVwBjAHMAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsAcwBkAG0ARgB5AEsAQwAwAHQAWQBt
>> "%~1" echo AHgAMQBaAFQASQBwAEsAVAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBX
>> "%~1" echo AFEANwBjAEcAeABoAFkAMgBVAHQAYQBYAFIAbABiAFgATQA2AFkAMgBWAHUAZABH
>> "%~1" echo AFYAeQBPADIATgB2AGIARwA5AHkATwBpAE4AbQBaAG0AWQA3AFkAbQA5ADQATABY
>> "%~1" echo AE4AbwBZAFcAUgB2AGQAegBvAHcASQBEAFoAdwBlAEMAQQB4AE4AbgBCADQASQBI
>> "%~1" echo AEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwAQwA0AHoATgBT
>> "%~1" echo AGwAOQBDAGkANQBpAGMAbQBGAHUAWgBDAEIAaQBlADIAUgBwAGMAMwBCAHMAWQBY
>> "%~1" echo AGsANgBZAG0AeAB2AFkAMgBzADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBq
>> "%~1" echo AEUAMgBjAEgAaAA5AEwAbQBKAHkAWQBXADUAawBJAEgATgB3AFkAVwA1ADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkAagBhAHoAdAB0AFkAWABKAG4AYQBX
>> "%~1" echo ADQAdABkAEcAOQB3AE8AagBOAHcAZQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBaAG0AOQB1AGQAQwAxAHoAYQBY
>> "%~1" echo AHAAbABPAGoARQB5AGMASABoADkAQwBpADUAaQBjAG0ARgB1AFoARQBsAGoAYgAy
>> "%~1" echo ADQAZwBjADMAWgBuAEwAQwA1AHUAWQBYAFkAZwBjADMAWgBuAEwAQwA1AGsAWgBY
>> "%~1" echo AFoAcABZADIAVgBKAFkAMgA5AHUASQBIAE4AMgBaAHkAdwB1AFoASABKAHYAYwBD
>> "%~1" echo AEIAegBkAG0AZAA3AFoAbQBsAHMAYgBEAHAAdQBiADIANQBsAE8AMwBOADAAYwBt
>> "%~1" echo ADkAcgBaAFQAcABqAGQAWABKAHkAWgBXADUAMABRADIAOQBzAGIAMwBJADcAYwAz
>> "%~1" echo AFIAeQBiADIAdABsAEwAWABkAHAAWgBIAFIAbwBPAGoASQA3AGMAMwBSAHkAYgAy
>> "%~1" echo AHQAbABMAFcAeABwAGIAbQBWAGoAWQBYAEEANgBjAG0AOQAxAGIAbQBRADcAYwAz
>> "%~1" echo AFIAeQBiADIAdABsAEwAVwB4AHAAYgBtAFYAcQBiADIAbAB1AE8AbgBKAHYAZABX
>> "%~1" echo ADUAawBmAFEAbwB1AGIAbQBGADIAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAz
>> "%~1" echo AEoAcABaAEQAdABuAFkAWABBADYATQAzAEIANABPADMAQgBoAFoARwBSAHAAYgBt
>> "%~1" echo AGMANgBNAFQAUgB3AGUAQwBBAHgATQBuAEIANABPADIAOQAyAFoAWABKAG0AYgBH
>> "%~1" echo ADkAMwBPAG0ARgAxAGQARwA5ADkAQwBpADUAdQBZAFgAWQBnAFkAWAB0AG8AWgBX
>> "%~1" echo AGwAbgBhAEgAUQA2AE4ARABCAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAYwBt
>> "%~1" echo AEYAawBhAFgAVgB6AE8AagBsAHcAZQBEAHQAawBhAFgATgB3AGIARwBGADUATwBt
>> "%~1" echo AFoAcwBaAFgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAy
>> "%~1" echo AFYAdQBkAEcAVgB5AE8AMgBkAGgAYwBEAG8AeABNAFgAQgA0AE8AMwBCAGgAWgBH
>> "%~1" echo AFIAcABiAG0AYwA2AE0AQwBBAHgATQAzAEIANABPADIATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwAxADEAZABHAFYAawBLAFQAdAAwAFoAWABoADAATABX
>> "%~1" echo AFIAbABZADIAOQB5AFkAWABSAHAAYgAyADQANgBiAG0AOQB1AFoAVAB0AG0AYgAy
>> "%~1" echo ADUAMABMAFgAZABsAGEAVwBkAG8AZABEAG8AMwBNAEQAQQA3AGQASABKAGgAYgBu
>> "%~1" echo AE4AcABkAEcAbAB2AGIAagBwAGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsASQBD
>> "%~1" echo ADQAeABOAFgATQBzAFkAMgA5AHMAYgAzAEkAZwBMAGoARQAxAGMAMwAwAEsATABt
>> "%~1" echo ADUAaABkAGkAQgBoAEkASABOADIAWgAzAHQAMwBhAFcAUgAwAGEARABvAHgATwBI
>> "%~1" echo AEIANABPADIAaABsAGEAVwBkAG8AZABEAG8AeABPAEgAQgA0AGYAUwA1AHUAWQBY
>> "%~1" echo AFkAZwBZAFQAcABvAGIAMwBaAGwAYwBuAHQAaQBZAFcATgByAFoAMwBKAHYAZABX
>> "%~1" echo ADUAawBPAG4ASgBuAFkAbQBFAG8ATQBUAFEANABMAEQARQAyAE0AeQB3AHgATwBE
>> "%~1" echo AFEAcwBMAGoARQB5AEsAVAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABT
>> "%~1" echo ADEAMABaAFgAaAAwAEsAWAAwAEsATABtADUAaABkAGkAQgBoAEwAbQBGAGoAZABH
>> "%~1" echo AGwAMgBaAFgAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBKAG4AWQBt
>> "%~1" echo AEUAbwBNAHoAYwBzAE8AVABrAHMATQBqAE0AMQBMAEMANAB4AE0AaQBrADcAWQAy
>> "%~1" echo ADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAG0AeAAxAFoAUwBsADkAQwBp
>> "%~1" echo ADUAdQBZAFgAWgBHAGIAMgA5ADAAZQAyADEAaABjAG0AZABwAGIAaQAxADAAYgAz
>> "%~1" echo AEEANgBZAFgAVgAwAGIAegB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBFADAAYwBI
>> "%~1" echo AGcAZwBNAFQAaAB3AGUARAB0AGkAYgAzAEoAawBaAFgASQB0AGQARwA5AHcATwBq
>> "%~1" echo AEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBX
>> "%~1" echo ADUAbABLAFQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABY
>> "%~1" echo AFIAbABaAEMAawA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFAHkAYwBI
>> "%~1" echo AGcANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0AUwA0ADEAZgBR
>> "%~1" echo AG8AdQBiAFcARgBwAGIAbgB0AG4AYwBtAGwAawBMAFcATgB2AGIASABWAHQAYgBq
>> "%~1" echo AG8AeQBPADIAMQBwAGIAaQAxADMAYQBXAFIAMABhAEQAbwB3AE8AMgAxAHAAYgBp
>> "%~1" echo ADEAbwBaAFcAbABuAGEASABRADYATQBUAEEAdwBkAG0AaAA5AEMAaQA1ADAAYgAz
>> "%~1" echo AEIANwBhAEcAVgBwAFoAMgBoADAATwBqAGMANABjAEgAZwA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQBqAFkAWABKAGsASwBU
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAWQBtADkAMABkAEcAOQB0AE8AagBGAHcAZQBD
>> "%~1" echo AEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBU
>> "%~1" echo AHQAawBhAFgATgB3AGIARwBGADUATwBtAFoAcwBaAFgAZwA3AFkAVwB4AHAAWgAy
>> "%~1" echo ADQAdABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBwADEAYwAz
>> "%~1" echo AFIAcABaAG4AawB0AFkAMgA5AHUAZABHAFYAdQBkAEQAcAB6AGMARwBGAGoAWgBT
>> "%~1" echo ADEAaQBaAFgAUgAzAFoAVwBWAHUATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBD
>> "%~1" echo AEEAeQBOAG4AQgA0AE8AMwBCAHYAYwAyAGwAMABhAFcAOQB1AE8AbgBOADAAYQBX
>> "%~1" echo AE4AcgBlAFQAdAAwAGIAMwBBADYATQBEAHQANgBMAFcAbAB1AFoARwBWADQATwBq
>> "%~1" echo AE4AOQBDAGkANQAwAGEAWABSAHMAWgBTAEIAbwBNAFgAdAB0AFkAWABKAG4AYQBX
>> "%~1" echo ADQANgBNAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0AagBGAHcAZQBI
>> "%~1" echo ADAAdQBkAEcAbAAwAGIARwBVAGcAYwBIAHQAdABZAFgASgBuAGEAVwA0ADYATgBY
>> "%~1" echo AEIANABJAEQAQQBnAE0ARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABT
>> "%~1" echo ADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBq
>> "%~1" echo AEUAegBjAEgAaAA5AEMAaQA1ADAAYgAyADkAcwBZAG0ARgB5AGUAMgBSAHAAYwAz
>> "%~1" echo AEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcAbABuAGIAaQAxAHAAZABH
>> "%~1" echo AFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBaADIARgB3AE8AagBoAHcAZQBE
>> "%~1" echo AHQAbQBiAEcAVgA0AEwAWABkAHkAWQBYAEEANgBkADMASgBoAGMARAB0AHEAZABY
>> "%~1" echo AE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4AUQA2AFoAbQB4AGwAZQBD
>> "%~1" echo ADEAbABiAG0AUgA5AEMAaQA1AGoAYQBHAGwAdwBMAEMANQBpAGQARwA1ADcAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBNADIAYwBIAGcANwBZAG0AOQB5AFoARwBWAHkATwBq
>> "%~1" echo AEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBX
>> "%~1" echo ADUAbABLAFQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFgATgB2AFoAbgBRAHAATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFgAUgBsAGUASABRAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBX
>> "%~1" echo AFIAcABkAFgATQA2AE8AWABCADQATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBD
>> "%~1" echo AEEAeABNAG4AQgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AGEAVwA1AHMAYQBX
>> "%~1" echo ADUAbABMAFcAWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEAWABSAGwAYgBY
>> "%~1" echo AE0ANgBZADIAVgB1AGQARwBWAHkATwAyAGQAaABjAEQAbwAzAGMASABnADcAWgBt
>> "%~1" echo ADkAdQBkAEMAMQAzAFoAVwBsAG4AYQBIAFEANgBOAHoAQQB3AGYAUQBvAHUAWQAy
>> "%~1" echo AGgAcABjAEUAUgB2AGQASAB0ADMAYQBXAFIAMABhAEQAbwA0AGMASABnADcAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBoAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAYwBt
>> "%~1" echo AEYAawBhAFgAVgB6AE8AagBVAHcASgBUAHQAaQBZAFcATgByAFoAMwBKAHYAZABX
>> "%~1" echo ADUAawBPAG4AWgBoAGMAaQBnAHQATABYAEoAbABaAEMAawA3AFkAbQA5ADQATABY
>> "%~1" echo AE4AbwBZAFcAUgB2AGQAegBvAHcASQBEAEEAZwBNAEMAQQB6AGMASABnAGcAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB5AE0AagBVAHMATQBqAGsAcwBOAHoASQBzAEwAagBFADEASwBY
>> "%~1" echo ADAASwBMAG0ATgB2AGIAbQA1AGwAWQAzAFIAbABaAEMAQQB1AFkAMgBoAHAAYwBF
>> "%~1" echo AFIAdgBkAEgAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFcAZAB5AFoAVwBWAHUASwBUAHQAaQBiADMAZwB0AGMAMgBoAGgAWgBH
>> "%~1" echo ADkAMwBPAGoAQQBnAE0AQwBBAHcASQBEAE4AdwBlAEMAQgB5AFoAMgBKAGgASwBE
>> "%~1" echo AEkAeQBMAEQARQAyAE0AeQB3ADMATgBDAHcAdQBNAFQAVQBwAGYAUQBvAHUAWQBu
>> "%~1" echo AFIAdQBlADIATgAxAGMAbgBOAHYAYwBqAHAAdwBiADIAbAB1AGQARwBWAHkATwAz
>> "%~1" echo AFIAeQBZAFcANQB6AGEAWABSAHAAYgAyADQANgBkAEgASgBoAGIAbgBOAG0AYgAz
>> "%~1" echo AEoAdABJAEMANAB3AE8ASABNAHMAWgBtAGwAcwBkAEcAVgB5AEkAQwA0AHgATgBY
>> "%~1" echo AE4AOQBMAG0ASgAwAGIAagBwAG8AYgAzAFoAbABjAG4AdABtAGEAVwB4ADAAWgBY
>> "%~1" echo AEkANgBZAG4ASgBwAFoAMgBoADAAYgBtAFYAegBjAHkAZwB4AEwAagBBAHoASwBY
>> "%~1" echo ADAAdQBZAG4AUgB1AE8AbQBGAGoAZABHAGwAMgBaAFgAdAAwAGMAbQBGAHUAYwAy
>> "%~1" echo AFoAdgBjAG0AMAA2AGQASABKAGgAYgBuAE4AcwBZAFgAUgBsAFcAUwBnAHgAYwBI
>> "%~1" echo AGcAcABmAFEAbwB1AFkAbgBSAHUATABuAEIAeQBhAFcAMQBoAGMAbgBsADcAWQBt
>> "%~1" echo AEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAGkAYgBI
>> "%~1" echo AFYAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABZADIAOQBzAGIAMwBJADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsANwBZADIAOQBzAGIAMwBJADYASQAy
>> "%~1" echo AFoAbQBaAG4AMAB1AFkAbgBSAHUATABtAGQAbwBiADMATgAwAGUAMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAZABIAEoAaABiAG4ATgB3AFkAWABKAGwAYgBu
>> "%~1" echo AFIAOQBDAGkANQAzAGMAbQBGAHcAZQAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBq
>> "%~1" echo AEIAdwBlAEMAQQB5AE4AbgBCADQASQBEAFEAdwBjAEgAZwA3AFoARwBsAHoAYwBH
>> "%~1" echo AHgAaABlAFQAcABtAGIARwBWADQATwAyAFoAcwBaAFgAZwB0AFoARwBsAHkAWgBX
>> "%~1" echo AE4AMABhAFcAOQB1AE8AbQBOAHYAYgBIAFYAdABiAGoAdABuAFkAWABBADYATQBU
>> "%~1" echo AFYAdwBlAEQAdAB0AFkAWABnAHQAZAAyAGwAawBkAEcAZwA2AE0AVABVAHkATQBI
>> "%~1" echo AEIANABmAFEAbwB1AGIAbQA5ADAAYQBXAE4AbABlADIASgB2AGMAbQBSAGwAYwBq
>> "%~1" echo AG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBjAG0AZABpAFkAUwBnAHkATQBU
>> "%~1" echo AGMAcwBNAFQARQA1AEwARABZAHMATABqAE0AdwBLAFQAdABpAFkAVwBOAHIAWgAz
>> "%~1" echo AEoAdgBkAFcANQBrAE8AbgBKAG4AWQBtAEUAbwBNAGoARQAzAEwARABFAHgATwBT
>> "%~1" echo AHcAMgBMAEMANAB3AE4AeQBrADcAWQAyADkAcwBiADMASQA2AEkAMgBJAHoATgBq
>> "%~1" echo AFUAdwBOAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBq
>> "%~1" echo AEUAdwBjAEgAZwA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0AWABCADQASQBE
>> "%~1" echo AEUAMABjAEgAZwA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATgB6
>> "%~1" echo AEEAdwBPADIAeABwAGIAbQBVAHQAYQBHAFYAcABaADIAaAAwAE8AagBFAHUATgBY
>> "%~1" echo ADAASwBZAG0AOQBrAGUAUwA1AGsAWQBYAEoAcgBJAEMANQB1AGIAMwBSAHAAWQAy
>> "%~1" echo AFYANwBZADIAOQBzAGIAMwBJADYASQAyAFkAMABZAHoAQQAyAFkAWAAwAEsATABu
>> "%~1" echo AEIAaABaADIAVgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcAB1AGIAMgA1AGwAZgBT
>> "%~1" echo ADUAdwBZAFcAZABsAEwAbQBGAGoAZABHAGwAMgBaAFgAdABrAGEAWABOAHcAYgBH
>> "%~1" echo AEYANQBPAG0AZAB5AGEAVwBRADcAWgAyAEYAdwBPAGoARQAxAGMASABoADkAQwBp
>> "%~1" echo ADUAeQBiADMAZAA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMAbQBsAGsATwAy
>> "%~1" echo AGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABX
>> "%~1" echo ADEAdQBjAHoAbwB4AFoAbgBJAGcATQBXAFoAeQBPADIAZABoAGMARABvAHgATgBY
>> "%~1" echo AEIANABmAFMANQB5AGIAMwBjAHoAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAz
>> "%~1" echo AEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABX
>> "%~1" echo AE4AdgBiAEgAVgB0AGIAbgBNADYAYwBtAFYAdwBaAFcARgAwAEsARABNAHMATQBX
>> "%~1" echo AFoAeQBLAFQAdABuAFkAWABBADYATQBUAFYAdwBlAEgAMABLAEwAbQBOAGgAYwBt
>> "%~1" echo AFIANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABT
>> "%~1" echo ADEAagBZAFgASgBrAEsAVAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBI
>> "%~1" echo AE4AdgBiAEcAbABrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABjAG0ARgBrAGEAWABWAHoASwBUAHQAdgBkAG0AVgB5AFoAbQB4AHYAZAB6
>> "%~1" echo AHAAbwBhAFcAUgBrAFoAVwA0ADcAWQBtADkANABMAFgATgBvAFkAVwBSAHYAZAB6
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAHoAYQBHAEYAawBiADMAYwBwAGYAUQBvAHUAYQBH
>> "%~1" echo AFYAaABaAEgAdABvAFoAVwBsAG4AYQBIAFEANgBOAEQAaAB3AGUARAB0AGkAYgAz
>> "%~1" echo AEoAawBaAFgASQB0AFkAbQA5ADAAZABHADkAdABPAGoARgB3AGUAQwBCAHoAYgAy
>> "%~1" echo AHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEAcwBhAFcANQBsAEsAVAB0AGsAYQBY
>> "%~1" echo AE4AdwBiAEcARgA1AE8AbQBaAHMAWgBYAGcANwBZAFcAeABwAFoAMgA0AHQAYQBY
>> "%~1" echo AFIAbABiAFgATQA2AFkAMgBWAHUAZABHAFYAeQBPADIAcAAxAGMAMwBSAHAAWgBu
>> "%~1" echo AGsAdABZADIAOQB1AGQARwBWAHUAZABEAHAAegBjAEcARgBqAFoAUwAxAGkAWgBY
>> "%~1" echo AFIAMwBaAFcAVgB1AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AQwBBAHgATgBu
>> "%~1" echo AEIANABmAFEAbwB1AGEARwBWAGgAWgBDAEIAbwBNAG4AdAB0AFkAWABKAG4AYQBX
>> "%~1" echo ADQANgBNAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0AVABWAHcAZQBI
>> "%~1" echo ADAAdQBkAEcARgBuAGUAMgBoAGwAYQBXAGQAbwBkAEQAbwB5AE4AWABCADQATwAy
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAYQBXADUAcwBhAFcANQBsAEwAVwBaAHMAWgBY
>> "%~1" echo AGcANwBZAFcAeABwAFoAMgA0AHQAYQBYAFIAbABiAFgATQA2AFkAMgBWAHUAZABH
>> "%~1" echo AFYAeQBPADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBX
>> "%~1" echo AFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBU
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8AagBrADUATwBY
>> "%~1" echo AEIANABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAEMAQQB4AE0ASABCADQATwAy
>> "%~1" echo AE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcAMQAxAGQARwBWAGsASwBU
>> "%~1" echo AHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAFQASgB3AGUASAAwAEsATABt
>> "%~1" echo AEoAdgBaAEgAbAA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE4AbgBCADQAZgBR
>> "%~1" echo AG8AdQBaAEcAVgAyAGEAVwBOAGwAUwBXAE4AdgBiAG4AdAAzAGEAVwBSADAAYQBE
>> "%~1" echo AG8AMwBNAEgAQgA0AE8AMgBoAGwAYQBXAGQAbwBkAEQAbwAzAE0ASABCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE0AVABSAHcAZQBE
>> "%~1" echo AHQAawBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUQA3AGMARwB4AGgAWQAy
>> "%~1" echo AFUAdABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQAaQBZAFMAZwB6AE4AeQB3ADUATwBT
>> "%~1" echo AHcAeQBNAHoAVQBzAEwAagBFAHcASwBUAHQAagBiADIAeAB2AGMAagBwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQBpAGIASABWAGwASwBYADAAdQBaAEcAVgAyAGEAVwBOAGwAUwBX
>> "%~1" echo AE4AdgBiAGkAQgB6AGQAbQBkADcAZAAyAGwAawBkAEcAZwA2AE4ARABSAHcAZQBE
>> "%~1" echo AHQAbwBaAFcAbABuAGEASABRADYATgBEAFIAdwBlAEgAMABLAEwAbQBoAGwAWQBX
>> "%~1" echo AFIAegBaAFgAUgBDAGIAMwBoADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG4AYwBt
>> "%~1" echo AGwAawBPADIAZAB5AGEAVwBRAHQAZABHAFYAdABjAEcAeABoAGQARwBVAHQAWQAy
>> "%~1" echo ADkAcwBkAFcAMQB1AGMAegBvADMATQBIAEIANABJAEQARgBtAGMAagB0AG4AWQBY
>> "%~1" echo AEEANgBNAFQAUgB3AGUARAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQARwBWAHQAYwB6
>> "%~1" echo AHAAagBaAFcANQAwAFoAWABKADkAQwBpADUAawBaAFgAWgBwAFkAMgBWAE8AWQBX
>> "%~1" echo ADEAbABlADIAWgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB5AE0AbgBCADQATwAy
>> "%~1" echo AFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAZwB3AE0ASAAwAHUAYQBH
>> "%~1" echo AGwAdQBkAEgAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8AagBkAHcAZQBE
>> "%~1" echo AHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBD
>> "%~1" echo AGsANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0AUwA0ADEATgBY
>> "%~1" echo ADAASwBMAG4ATgAwAFkAWABSAGwAZQAyADEAaABjAG0AZABwAGIAaQAxADAAYgAz
>> "%~1" echo AEEANgBPAEgAQgA0AE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHkATgBI
>> "%~1" echo AEIANABPADIAWgB2AGIAbgBRAHQAZAAyAFYAcABaADIAaAAwAE8AagBrAHcATQBE
>> "%~1" echo AHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB5AFoAVwBRAHAAZgBT
>> "%~1" echo ADUAegBkAEcARgAwAFoAUwA1AG4AYgAyADkAawBlADIATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwBkAHkAWgBXAFYAdQBLAFgAMABLAEwAbgBKAHAAWgAz
>> "%~1" echo AHQAawBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUQA3AFoAMwBKAHAAWgBD
>> "%~1" echo ADEAMABaAFcAMQB3AGIARwBGADAAWgBTADEAagBiADIAeAAxAGIAVwA1AHoATwBq
>> "%~1" echo AEYAbQBjAGkAQQB4AEwAagBOAG0AYwBpAEEAeABaAG4ASQA3AFoAMgBGAHcATwBq
>> "%~1" echo AEUAeQBjAEgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAy
>> "%~1" echo AFYAdQBkAEcAVgB5AE8AMgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYATQBU
>> "%~1" echo AFoAdwBlAEgAMABLAEwAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAEMAYgAz
>> "%~1" echo AGgANwBiAFcAbAB1AEwAVwBoAGwAYQBXAGQAbwBkAEQAbwAzAE8ASABCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0AOQB5AFoARwBWAHkATABY
>> "%~1" echo AEoAaABaAEcAbAAxAGMAegBvAHgATQBIAEIANABPADIASgBoAFkAMgB0AG4AYwBt
>> "%~1" echo ADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrADcAYwBH
>> "%~1" echo AEYAawBaAEcAbAB1AFoAegBvAHgATQBYAEIANABJAEQARQB6AGMASABnADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADIARgBzAGEAVwBkAHUATABX
>> "%~1" echo AE4AdgBiAG4AUgBsAGIAbgBRADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBkAGgAYwBE
>> "%~1" echo AG8AMQBjAEgAaAA5AEMAaQA1AGoAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAUQBt
>> "%~1" echo ADkANABJAEMANQB5AGIAMgB4AGwAZQAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFcAMQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABOAHAAZQBt
>> "%~1" echo AFUANgBNAFQASgB3AGUASAAwAHUAWQAyADkAdQBkAEgASgB2AGIARwB4AGwAYwBr
>> "%~1" echo AEoAdgBlAEMAQgBpAGUAMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHkATQBI
>> "%~1" echo AEIANABmAFMANQBqAGIAMgA1ADAAYwBtADkAcwBiAEcAVgB5AFEAbQA5ADQASQBD
>> "%~1" echo ADUAegBkAEcARgAwAFoAVgBSAGwAZQBIAFIANwBaAG0AOQB1AGQAQwAxAHoAYQBY
>> "%~1" echo AHAAbABPAGoARQB5AGMASABnADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABiAFgAVgAwAFoAVwBRAHAAZgBRAG8AdQBZADIAOQB1AGQASABKAHYAYgBH
>> "%~1" echo AHgAbABjAGsASgB2AGUAQwA1AHMAWgBXAFoAMABlADIASgB2AGMAbQBSAGwAYwBp
>> "%~1" echo ADEAcwBaAFcAWgAwAE8AagBOAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQBpAGIASABWAGwASwBYADAAdQBZADIAOQB1AGQASABKAHYAYgBH
>> "%~1" echo AHgAbABjAGsASgB2AGUAQwA1AHkAYQBXAGQAbwBkAEgAdAAwAFoAWABoADAATABX
>> "%~1" echo AEYAcwBhAFcAZAB1AE8AbgBKAHAAWgAyAGgAMABPADIASgB2AGMAbQBSAGwAYwBp
>> "%~1" echo ADEAeQBhAFcAZABvAGQARABvAHoAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGwAOQBDAGkANQB0AFoAWABSAGgAUwBY
>> "%~1" echo AFIAbABiAFgAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBH
>> "%~1" echo AGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBt
>> "%~1" echo AFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAFgAQgA0AE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABD
>> "%~1" echo AGsANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABNAEgAQgA0AEkARABFAHkAYwBI
>> "%~1" echo AGgAOQBMAG0AMQBsAGQARwBGAEoAZABHAFYAdABJAEgATgB3AFkAVwA1ADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkAagBhAHoAdABqAGIAMgB4AHYAYwBq
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABD
>> "%~1" echo ADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGgAOQBMAG0AMQBsAGQARwBGAEoAZABH
>> "%~1" echo AFYAdABJAEcASgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABpAGIARwA5AGoAYQB6
>> "%~1" echo AHQAdABZAFgASgBuAGEAVwA0AHQAZABHADkAdwBPAGoAVgB3AGUARAB0ADMAYQBH
>> "%~1" echo AGwAMABaAFMAMQB6AGMARwBGAGoAWgBUAHAAdQBiADMAZAB5AFkAWABBADcAYgAz
>> "%~1" echo AFoAbABjAG0AWgBzAGIAMwBjADYAYQBHAGwAawBaAEcAVgB1AE8AMwBSAGwAZQBI
>> "%~1" echo AFEAdABiADMAWgBsAGMAbQBaAHMAYgAzAGMANgBaAFcAeABzAGEAWABCAHoAYQBY
>> "%~1" echo AE4AOQBDAGkANQB0AFoAWABSAHkAYQBXAE4ASABjAG0AbABrAGUAMgBSAHAAYwAz
>> "%~1" echo AEIAcwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBY
>> "%~1" echo AEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AGMAbQBWAHcAWgBX
>> "%~1" echo AEYAMABLAEQATQBzAE0AVwBaAHkASwBUAHQAbgBZAFgAQQA2AE0AVABKAHcAZQBI
>> "%~1" echo ADAASwBMAG0AMQBsAGQASABKAHAAWQAzAHQAbwBaAFcAbABuAGEASABRADYATQBU
>> "%~1" echo AEUAMgBjAEgAZwA3AFkAbQA5AHkAWgBHAFYAeQBPAGoARgB3AGUAQwBCAHoAYgAy
>> "%~1" echo AHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEAcwBhAFcANQBsAEsAVAB0AGkAYgAz
>> "%~1" echo AEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYAegBPAGoARQB3AGMASABnADcAWQBt
>> "%~1" echo AEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAHoAYgAy
>> "%~1" echo AFoAMABLAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoARQAwAGMASABnADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADIAZAB5AGEAVwBRAHQAZABH
>> "%~1" echo AFYAdABjAEcAeABoAGQARwBVAHQAWQAyADkAcwBkAFcAMQB1AGMAegBvADMATQBI
>> "%~1" echo AEIANABJAEQARgBtAGMAagB0AGgAYgBHAGwAbgBiAGkAMQBwAGQARwBWAHQAYwB6
>> "%~1" echo AHAAagBaAFcANQAwAFoAWABJADcAWgAyAEYAdwBPAGoARQB4AGMASABoADkAQwBp
>> "%~1" echo ADUAdABaAFgAUgB5AGEAVwBNAGcAYwAzAFoAbgBMAG4ASgBwAGIAbQBkADcAZAAy
>> "%~1" echo AGwAawBkAEcAZwA2AE4AegBCAHcAZQBEAHQAbwBaAFcAbABuAGEASABRADYATgB6
>> "%~1" echo AEIAdwBlAEQAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGMAbQA5ADAAWQBY
>> "%~1" echo AFIAbABLAEMAMAA1AE0ARwBSAGwAWgB5AGwAOQBMAG4AUgB5AFkAVwBOAHIAZQAy
>> "%~1" echo AFoAcABiAEcAdwA2AGIAbQA5AHUAWgBUAHQAegBkAEgASgB2AGEAMgBVADYAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB4AE4ARABnAHMATQBUAFkAegBMAEQARQA0AE4AQwB3AHUATQBq
>> "%~1" echo AFUAcABPADMATgAwAGMAbQA5AHIAWgBTADEAMwBhAFcAUgAwAGEARABvADQAZgBT
>> "%~1" echo ADUAdABaAFgAUgBsAGMAbgB0AG0AYQBXAHgAcwBPAG0ANQB2AGIAbQBVADcAYwAz
>> "%~1" echo AFIAeQBiADIAdABsAE8AbgBaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAATwAz
>> "%~1" echo AE4AMABjAG0AOQByAFoAUwAxADMAYQBXAFIAMABhAEQAbwA0AE8AMwBOADAAYwBt
>> "%~1" echo ADkAcgBaAFMAMQBzAGEAVwA1AGwAWQAyAEYAdwBPAG4ASgB2AGQAVwA1AGsATwAz
>> "%~1" echo AFIAeQBZAFcANQB6AGEAWABSAHAAYgAyADQANgBjADMAUgB5AGIAMgB0AGwATABX
>> "%~1" echo AFIAaABjADIAaABoAGMAbgBKAGgAZQBTAEEAdQBOAFgATQBnAFoAVwBGAHoAWgBY
>> "%~1" echo ADAASwBMAG0AMQBsAGQASABKAHAAWQB5ADUAbgBjAG0AVgBsAGIAaQBBAHUAYgBX
>> "%~1" echo AFYAMABaAFgASgA3AGMAMwBSAHkAYgAyAHQAbABPAG4AWgBoAGMAaQBnAHQATABX
>> "%~1" echo AGQAeQBaAFcAVgB1AEsAWAAwAHUAYgBXAFYAMABjAG0AbABqAEwAbQBGAHQAWQBt
>> "%~1" echo AFYAeQBJAEMANQB0AFoAWABSAGwAYwBuAHQAegBkAEgASgB2AGEAMgBVADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAVwAxAGkAWgBYAEkAcABmAFMANQB0AFoAWABSAHkAYQBX
>> "%~1" echo AE0AdQBjAG0AVgBrAEkAQwA1AHQAWgBYAFIAbABjAG4AdAB6AGQASABKAHYAYQAy
>> "%~1" echo AFUANgBkAG0ARgB5AEsAQwAwAHQAYwBtAFYAawBLAFgAMABLAEwAbQAxAGwAZABI
>> "%~1" echo AEoAcABZADEAWgBoAGIASABWAGwAZQAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBU
>> "%~1" echo AG8AeQBNADMAQgA0AE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBq
>> "%~1" echo AGsAdwBNAEQAdAAzAGEARwBsADAAWgBTADEAegBjAEcARgBqAFoAVABwAHUAYgAz
>> "%~1" echo AGQAeQBZAFgAQgA5AEwAbQAxAGwAZABIAEoAcABZADAAeABoAFkAbQBWAHMAZQAy
>> "%~1" echo ADEAaABjAG0AZABwAGIAaQAxADAAYgAzAEEANgBOAG4AQgA0AE8AMgBOAHYAYgBH
>> "%~1" echo ADkAeQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsAVAB0AG0AYgAy
>> "%~1" echo ADUAMABMAFgATgBwAGUAbQBVADYATQBUAEoAdwBlAEgAMABLAEwAbQBsAHUAWgBt
>> "%~1" echo ADkASABjAG0AbABrAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBE
>> "%~1" echo AHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBI
>> "%~1" echo AFYAdABiAG4ATQA2AGMAbQBWAHcAWgBXAEYAMABLAEQATQBzAE0AVwBaAHkASwBU
>> "%~1" echo AHQAbgBZAFgAQQA2AE0AVABGAHcAZQBIADAASwBMAG0AbAB1AFoAbQA5AFUAYQBX
>> "%~1" echo AHgAbABlADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBX
>> "%~1" echo AFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQA5AHkAWgBH
>> "%~1" echo AFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8ANQBjAEgAZwA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBU
>> "%~1" echo AHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUAeQBjAEgAZwA3AGIAVwBsAHUATABX
>> "%~1" echo AGgAbABhAFcAZABvAGQARABvADIATQBIAEIANABmAFMANQBwAGIAbQBaAHYAVgBH
>> "%~1" echo AGwAcwBaAFMAQgB6AGMARwBGAHUAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWQBt
>> "%~1" echo AHgAdgBZADIAcwA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAYgBY
>> "%~1" echo AFYAMABaAFcAUQBwAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHgATQBu
>> "%~1" echo AEIANABmAFMANQBwAGIAbQBaAHYAVgBHAGwAcwBaAFMAQgBpAGUAMgBSAHAAYwAz
>> "%~1" echo AEIAcwBZAFgAawA2AFkAbQB4AHYAWQAyAHMANwBiAFcARgB5AFoAMgBsAHUATABY
>> "%~1" echo AFIAdgBjAEQAbwAyAGMASABnADcAZAAyADkAeQBaAEMAMQBpAGMAbQBWAGgAYQB6
>> "%~1" echo AHAAaQBjAG0AVgBoAGEAeQAxADMAYgAzAEoAawBmAFEAbwB1AFoAWABoAHcAYgAz
>> "%~1" echo AEoAMABRAG0AOQA0AGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBE
>> "%~1" echo AHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBI
>> "%~1" echo AFYAdABiAG4ATQA2AE0AVwBaAHkASQBHAEYAMQBkAEcAOAA3AFoAMgBGAHcATwBq
>> "%~1" echo AEUAMABjAEgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAy
>> "%~1" echo AFYAdQBkAEcAVgB5AE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMASABnAGcAYwAy
>> "%~1" echo ADkAcwBhAFcAUQBnAGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8AUwB3AHkATQB6
>> "%~1" echo AFUAcwBMAGoATQAxAEsAVAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBu
>> "%~1" echo AEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwAQwA0AHcATgB5
>> "%~1" echo AGsANwBZAG0AOQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvAHgATQBI
>> "%~1" echo AEIANABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQAUgB3AGUASAAwAEsATABt
>> "%~1" echo AFYANABjAEcAOQB5AGQARQB4AHAAYgBtAHQAegBlADIAUgBwAGMAMwBCAHMAWQBY
>> "%~1" echo AGsANgBaADMASgBwAFoARAB0AG4AWQBYAEEANgBPAEgAQgA0AGYAUwA1AGwAZQBI
>> "%~1" echo AEIAdgBjAG4AUgBNAGEAVwA1AHIAYwB5AEIAaABlADIATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwBKAHMAZABXAFUAcABPADIAWgB2AGIAbgBRAHQAZAAy
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBrAHcATQBEAHQAMwBiADMASgBrAEwAVwBKAHkAWgBX
>> "%~1" echo AEYAcgBPAG0ASgB5AFoAVwBGAHIATABXAEYAcwBiAEgAMABLAEwAbgBSAGgAWQBt
>> "%~1" echo AHgAbABlADMAZABwAFoASABSAG8ATwBqAEUAdwBNAEMAVQA3AFkAbQA5AHkAWgBH
>> "%~1" echo AFYAeQBMAFcATgB2AGIARwB4AGgAYwBIAE4AbABPAG0ATgB2AGIARwB4AGgAYwBI
>> "%~1" echo AE4AbABmAFMANQAwAFkAVwBKAHMAWgBTAEIAMABaAEgAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABZAG0AOQAwAGQARwA5AHQATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBD
>> "%~1" echo AEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdAB3AFkAVwBSAGsAYQBX
>> "%~1" echo ADUAbgBPAGoARQB3AGMASABnAGcATQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBkAG0AVgB5AGQARwBsAGoAWQBX
>> "%~1" echo AHcAdABZAFcAeABwAFoAMgA0ADYAZABHADkAdwBmAFMANQAwAFkAVwBKAHMAWgBT
>> "%~1" echo AEIAMABjAGoAcABzAFkAWABOADAATABXAE4AbwBhAFcAeABrAEkASABSAGsAZQAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAGkAYgAzAFIAMABiADIAMAA2AE0ASAAwAHUAZABH
>> "%~1" echo AEYAaQBiAEcAVQBnAGQARwBRADYAYgBHAEYAegBkAEMAMQBqAGEARwBsAHMAWgBI
>> "%~1" echo AHQAMABaAFgAaAAwAEwAVwBGAHMAYQBXAGQAdQBPAG4ASgBwAFoAMgBoADAATwAy
>> "%~1" echo AE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFgAUgBsAGUASABRAHAATwAy
>> "%~1" echo AFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAYwB3AE0ARAB0ADMAYgAz
>> "%~1" echo AEoAawBMAFcASgB5AFoAVwBGAHIATwBtAEoAeQBaAFcARgByAEwAWABkAHYAYwBt
>> "%~1" echo AFIAOQBDAGkANQBqAGIAVwBSAEgAYwBtAGwAawBlADIAUgBwAGMAMwBCAHMAWQBY
>> "%~1" echo AGsANgBaADMASgBwAFoARAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBY
>> "%~1" echo AFIAbABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBjAG0AVgB3AFoAVwBGADAASwBE
>> "%~1" echo AEkAcwBiAFcAbAB1AGIAVwBGADQASwBEAEEAcwBNAFcAWgB5AEsAUwBrADcAWgAy
>> "%~1" echo AEYAdwBPAGoARQB4AGMASABoADkAQwBpADUAagBiAFcAUgA3AGIAVwBsAHUATABX
>> "%~1" echo AGgAbABhAFcAZABvAGQARABvADIATQBIAEIANABPADIASgB2AGMAbQBSAGwAYwBq
>> "%~1" echo AG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBH
>> "%~1" echo AGwAdQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFcAeABsAFoAbgBRADYATQAz
>> "%~1" echo AEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBt
>> "%~1" echo AFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABjADIAOQBtAGQAQwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBH
>> "%~1" echo AGwAMQBjAHoAbwA1AGMASABnADcAZABHAFYANABkAEMAMQBoAGIARwBsAG4AYgBq
>> "%~1" echo AHAAcwBaAFcAWgAwAE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABGAHcAZQBD
>> "%~1" echo AEEAeABNADMAQgA0AE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABY
>> "%~1" echo AFIAbABlAEgAUQBwAE8AMgBOADEAYwBuAE4AdgBjAGoAcAB3AGIAMgBsAHUAZABH
>> "%~1" echo AFYAeQBPADMAUgB5AFkAVwA1AHoAYQBYAFIAcABiADIANAA2AGQASABKAGgAYgBu
>> "%~1" echo AE4AbQBiADMASgB0AEkAQwA0AHcATwBIAE0AcwBaAG0AbABzAGQARwBWAHkASQBD
>> "%~1" echo ADQAeABOAFgATgA5AEwAbQBOAHQAWgBEAHAAbwBiADMAWgBsAGMAbgB0AG0AYQBX
>> "%~1" echo AHgAMABaAFgASQA2AFkAbgBKAHAAWgAyAGgAMABiAG0AVgB6AGMAeQBnAHgATABq
>> "%~1" echo AEEAegBLAFgAMAB1AFkAMgAxAGsATwBtAEYAagBkAEcAbAAyAFoAWAB0ADAAYwBt
>> "%~1" echo AEYAdQBjADIAWgB2AGMAbQAwADYAZABIAEoAaABiAG4ATgBzAFkAWABSAGwAVwBT
>> "%~1" echo AGcAeABjAEgAZwBwAGYAUQBvAHUAWQAyADEAawBJAEcASgA3AFoARwBsAHoAYwBH
>> "%~1" echo AHgAaABlAFQAcABpAGIARwA5AGoAYQAzADAAdQBZADIAMQBrAEkASABOAHcAWQBX
>> "%~1" echo ADUANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEAegB0AHQAWQBY
>> "%~1" echo AEoAbgBhAFcANAB0AGQARwA5AHcATwBqAFIAdwBlAEQAdABqAGIAMgB4AHYAYwBq
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABD
>> "%~1" echo ADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGgAOQBDAGkANQBqAGIAVwBRAHUAWQBt
>> "%~1" echo AHgAMQBaAFgAdABpAGIAMwBKAGsAWgBYAEkAdABiAEcAVgBtAGQAQwAxAGoAYgAy
>> "%~1" echo AHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAaQBiAEgAVgBsAEsAWAAwAHUAWQAy
>> "%~1" echo ADEAawBMAG0AZAB5AFoAVwBWAHUAZQAyAEoAdgBjAG0AUgBsAGMAaQAxAHMAWgBX
>> "%~1" echo AFoAMABMAFcATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwBkAHkAWgBX
>> "%~1" echo AFYAdQBLAFgAMAB1AFkAMgAxAGsATABtAEYAdABZAG0AVgB5AGUAMgBKAHYAYwBt
>> "%~1" echo AFIAbABjAGkAMQBzAFoAVwBaADAATABXAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFcARgB0AFkAbQBWAHkASwBYADAAdQBZADIAMQBrAEwAbgBKAGwAWgBI
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYAbQBkAEMAMQBqAGIAMgB4AHYAYwBq
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAHkAWgBXAFEAcABmAFEAbwB1AFoAbQA5AHkAYgBY
>> "%~1" echo AHQAawBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUQA3AFoAMwBKAHAAWgBD
>> "%~1" echo ADEAMABaAFcAMQB3AGIARwBGADAAWgBTADEAagBiADIAeAAxAGIAVwA1AHoATwBq
>> "%~1" echo AEUAegBNAEgAQgA0AEkARABGAG0AYwBpAEEAeABaAG4ASQBnAE8AVABCAHcAZQBE
>> "%~1" echo AHQAbgBZAFgAQQA2AE0AVABCAHcAZQBIADAASwBhAFcANQB3AGQAWABRAHMAYwAy
>> "%~1" echo AFYAcwBaAFcATgAwAGUAMgBoAGwAYQBXAGQAbwBkAEQAbwB6AE8ASABCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0AOQB5AFoARwBWAHkATABY
>> "%~1" echo AEoAaABaAEcAbAAxAGMAegBvADUAYwBIAGcANwBZAG0ARgBqAGEAMgBkAHkAYgAz
>> "%~1" echo AFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIAWgAwAEsAVAB0AGoAYgAy
>> "%~1" echo AHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAMABaAFgAaAAwAEsAVAB0AHcAWQBX
>> "%~1" echo AFIAawBhAFcANQBuAE8AagBBAGcATQBUAEYAdwBlAEgAMABLAGEAVwA1AHcAZABY
>> "%~1" echo AFEANgBaAG0AOQBqAGQAWABNAHMAYwAyAFYAcwBaAFcATgAwAE8AbQBaAHYAWQAz
>> "%~1" echo AFYAegBlADIAOQAxAGQARwB4AHAAYgBtAFUANgBiAG0AOQB1AFoAVAB0AGkAYgAz
>> "%~1" echo AEoAawBaAFgASQB0AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBt
>> "%~1" echo AHgAMQBaAFMAawA3AFkAbQA5ADQATABYAE4AbwBZAFcAUgB2AGQAegBvAHcASQBE
>> "%~1" echo AEEAZwBNAEMAQQB6AGMASABnAGcAYwBtAGQAaQBZAFMAZwB6AE4AeQB3ADUATwBT
>> "%~1" echo AHcAeQBNAHoAVQBzAEwAagBFADEASwBYADAASwBMAG0AeAB2AFoAMwB0ADMAYQBH
>> "%~1" echo AGwAMABaAFMAMQB6AGMARwBGAGoAWgBUAHAAdwBjAG0AVQB0AGQAMwBKAGgAYwBE
>> "%~1" echo AHQAdABhAFcANAB0AGEARwBWAHAAWgAyAGgAMABPAGoAZwB3AGMASABnADcAWQAy
>> "%~1" echo ADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoAVwBRAHAATwAy
>> "%~1" echo AFoAdgBiAG4AUQB0AFoAbQBGAHQAYQBXAHgANQBPAGsATgB2AGIAbgBOAHYAYgBH
>> "%~1" echo AEYAegBMAEMASgBOAGEAVwBOAHkAYgAzAE4AdgBaAG4AUQBnAFcAVwBGAEkAWgBX
>> "%~1" echo AGsAaQBMAEcAMQB2AGIAbQA5AHoAYwBHAEYAagBaAFQAdABzAGEAVwA1AGwATABX
>> "%~1" echo AGgAbABhAFcAZABvAGQARABvAHgATABqAFUAMQBPADMAZAB2AGMAbQBRAHQAWQBu
>> "%~1" echo AEoAbABZAFcAcwA2AFkAbgBKAGwAWQBXAHMAdABkADIAOQB5AFoASAAwAEsATAB5
>> "%~1" echo AG8AZwBMAFMAMAB0AEkARQBGAFEAUwB5AEIAcABiAG4ATgAwAFkAVwB4AHMAWgBY
>> "%~1" echo AEkANgBJAEUARgB3AGMAQwBCAFQAZABHADkAeQBaAFMAQgBrAFoAWABSAGgAYQBX
>> "%~1" echo AHcAZwBZADIARgB5AFoAQwBBAHQATABTADAAZwBLAGkAOABLAEwAbQBGAHcAYwBG
>> "%~1" echo AGQAeQBZAFgAQgA3AGIAVwBGADQATABYAGQAcABaAEgAUgBvAE8AagBZAHcATQBI
>> "%~1" echo AEIANABPADIAMQBoAGMAbQBkAHAAYgBqAG8AdwBJAEcARgAxAGQARwA4ADcAZAAy
>> "%~1" echo AGwAawBkAEcAZwA2AE0AVABBAHcASgBYADAASwBMAG0ARgB3AGMARQBOAGgAYwBt
>> "%~1" echo AFIANwBZAG0AOQB5AFoARwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBD
>> "%~1" echo AEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABjAG0ARgBrAGEAWABWAHoATwBqAEUAMgBjAEgAZwA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwAHMAYQBXADUAbABZAFgASQB0AFoAMwBKAGgAWgBH
>> "%~1" echo AGwAbABiAG4AUQBvAE0AVABnAHcAWgBHAFYAbgBMAEgASgBuAFkAbQBFAG8ATQB6
>> "%~1" echo AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAdwBOAFMAawBzAGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABZADIARgB5AFoAQwBrAGcATQBUAEkAdwBjAEgAZwBwAE8AMgBKAHYAZQBD
>> "%~1" echo ADEAegBhAEcARgBrAGIAMwBjADYAZABtAEYAeQBLAEMAMAB0AGMAMgBoAGgAWgBH
>> "%~1" echo ADkAMwBLAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoASQB5AGMASABnADcAWQBX
>> "%~1" echo ADUAcABiAFcARgAwAGEAVwA5AHUATwBtAE4AaABjAG0AUgBKAGIAaQBBAHUATgBI
>> "%~1" echo AE0AZwBZADMAVgBpAGEAVwBNAHQAWQBtAFYANgBhAFcAVgB5AEsAQwA0AHkATABD
>> "%~1" echo ADQANABMAEMANAB5AEwARABFAHAAZgBRAHAAQQBhADIAVgA1AFoAbgBKAGgAYgBX
>> "%~1" echo AFYAegBJAEcATgBoAGMAbQBSAEoAYgBuAHQAbQBjAG0AOQB0AGUAMgA5AHcAWQBX
>> "%~1" echo AE4AcABkAEgAawA2AE0ARAB0ADAAYwBtAEYAdQBjADIAWgB2AGMAbQAwADYAZABI
>> "%~1" echo AEoAaABiAG4ATgBzAFkAWABSAGwAVwBTAGcAeABOAEgAQgA0AEsAWAAxADAAYgAz
>> "%~1" echo AHQAdgBjAEcARgBqAGEAWABSADUATwBqAEUANwBkAEgASgBoAGIAbgBOAG0AYgAz
>> "%~1" echo AEoAdABPAG0ANQB2AGIAbQBWADkAZgBRAG8AdQBZAFgAQgB3AFEAMgBGAHkAWgBD
>> "%~1" echo ADUAbgBiAEcAOQAzAGUAMgBGAHUAYQBXADEAaABkAEcAbAB2AGIAagBwAGoAWQBY
>> "%~1" echo AEoAawBTAFcANABnAEwAagBSAHoASQBHAE4AMQBZAG0AbABqAEwAVwBKAGwAZQBt
>> "%~1" echo AGwAbABjAGkAZwB1AE0AaQB3AHUATwBDAHcAdQBNAGkAdwB4AEsAUwB4AHoAZABX
>> "%~1" echo AE4AagBaAFgATgB6AFIAMgB4AHYAZAB5AEEAeABMAGoARgB6AEkARwBWAGgAYwAy
>> "%~1" echo AFYAOQBDAGsAQgByAFoAWABsAG0AYwBtAEYAdABaAFgATQBnAGMAMwBWAGoAWQAy
>> "%~1" echo AFYAegBjADAAZABzAGIAMwBkADcATQBDAFYANwBZAG0AOQA0AEwAWABOAG8AWQBX
>> "%~1" echo AFIAdgBkAHoAcAAyAFkAWABJAG8ATABTADEAegBhAEcARgBrAGIAMwBjAHAAZgBU
>> "%~1" echo AE0AdwBKAFgAdABpAGIAMwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AagBBAGcATQBD
>> "%~1" echo AEEAdwBJAEQATgB3AGUAQwBCAHkAWgAyAEoAaABLAEQASQB5AEwARABFADIATQB5
>> "%~1" echo AHcAMwBOAEMAdwB1AE0AegBVAHAATABEAEEAZwBNAFQASgB3AGUAQwBBADAATQBI
>> "%~1" echo AEIANABJAEgASgBuAFkAbQBFAG8ATQBqAEkAcwBNAFQAWQB6AEwARABjADAATABD
>> "%~1" echo ADQAeQBOAFMAbAA5AE0AVABBAHcASgBYAHQAaQBiADMAZwB0AGMAMgBoAGgAWgBH
>> "%~1" echo ADkAMwBPAG4AWgBoAGMAaQBnAHQATABYAE4AbwBZAFcAUgB2AGQAeQBsADkAZgBR
>> "%~1" echo AG8AdgBLAGkAQgBsAGIAWABCADAAZQBTAEEAdgBJAEcAUgB5AGIAMwBBAGcAYwAz
>> "%~1" echo AFIAaABkAEcAVQBnAEsAaQA4AEsATABtAFIAeQBiADMAQgBGAGIAWABCADAAZQBY
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJADYATQBuAEIANABJAEcAUgBoAGMAMgBoAGwAWgBD
>> "%~1" echo AEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABjAG0ARgBrAGEAWABWAHoATwBqAEUAMABjAEgAZwA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBU
>> "%~1" echo AHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAFEAMgBjAEgAZwBnAE0AagBCAHcAZQBE
>> "%~1" echo AHQAMABaAFgAaAAwAEwAVwBGAHMAYQBXAGQAdQBPAG0ATgBsAGIAbgBSAGwAYwBq
>> "%~1" echo AHQAagBkAFgASgB6AGIAMwBJADYAYwBHADkAcABiAG4AUgBsAGMAagB0ADAAYwBt
>> "%~1" echo AEYAdQBjADIAbAAwAGEAVwA5AHUATwBtAEoAdgBjAG0AUgBsAGMAaQAxAGoAYgAy
>> "%~1" echo AHgAdgBjAGkAQQB1AE0AVABoAHoATABHAEoAaABZADIAdABuAGMAbQA5ADEAYgBt
>> "%~1" echo AFEAZwBMAGoARQA0AGMAMwAwAEsATABtAFIAeQBiADMAQgBGAGIAWABCADAAZQBU
>> "%~1" echo AHAAbwBiADMAWgBsAGMAbgB0AGkAYgAzAEoAawBaAFgASQB0AFkAMgA5AHMAYgAz
>> "%~1" echo AEkANgBkAG0ARgB5AEsAQwAwAHQAWQBtAHgAMQBaAFMAbAA5AEMAaQA1AGsAYwBt
>> "%~1" echo ADkAdwBSAFcAMQB3AGQASABrAHUAYgAzAFoAbABjAG4AdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBT
>> "%~1" echo AGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoAMgBKAGgASwBE
>> "%~1" echo AE0AMwBMAEQAawA1AEwARABJAHoATgBTAHcAdQBNAFQAQQBwAGYAUQBvAHUAWgBI
>> "%~1" echo AEoAdgBjAEUAVgB0AGMASABSADUASQBIAE4AMgBaADMAdAAzAGEAVwBSADAAYQBE
>> "%~1" echo AG8AMQBNAG4AQgA0AE8AMgBoAGwAYQBXAGQAbwBkAEQAbwAxAE0AbgBCADQATwAy
>> "%~1" echo AE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAATwAy
>> "%~1" echo AEYAdQBhAFcAMQBoAGQARwBsAHYAYgBqAHAAbwBhAFcANQAwAFIAbQB4AHYAWQBY
>> "%~1" echo AFEAZwBNAGkANAAwAGMAeQBCAGwAWQBYAE4AbABMAFcAbAB1AEwAVwA5ADEAZABD
>> "%~1" echo AEIAcABiAG0AWgBwAGIAbQBsADAAWgBYADAASwBRAEcAdABsAGUAVwBaAHkAWQBX
>> "%~1" echo ADEAbABjAHkAQgBvAGEAVwA1ADAAUgBtAHgAdgBZAFgAUgA3AE0AQwBVAHMATQBU
>> "%~1" echo AEEAdwBKAFgAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGQASABKAGgAYgBu
>> "%~1" echo AE4AcwBZAFgAUgBsAFcAUwBnAHcASwBUAHQAdgBjAEcARgBqAGEAWABSADUATwBp
>> "%~1" echo ADQANABOAFgAMAAxAE0AQwBWADcAZABIAEoAaABiAG4ATgBtAGIAMwBKAHQATwBu
>> "%~1" echo AFIAeQBZAFcANQB6AGIARwBGADAAWgBWAGsAbwBMAFQAVgB3AGUAQwBrADcAYgAz
>> "%~1" echo AEIAaABZADIAbAAwAGUAVABvAHgAZgBYADAASwBMAG0AUgB5AGIAMwBCAEYAYgBY
>> "%~1" echo AEIAMABlAFMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFkAbQB4AHYAWQAy
>> "%~1" echo AHMANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQAyAGMASABnADcAYgBX
>> "%~1" echo AEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8ANABjAEgAaAA5AEwAbQBSAHkAYgAz
>> "%~1" echo AEIARgBiAFgAQgAwAGUAUwBCAHoAYwBHAEYAdQBlADIAUgBwAGMAMwBCAHMAWQBY
>> "%~1" echo AGsANgBZAG0AeAB2AFkAMgBzADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBE
>> "%~1" echo AG8AMgBjAEgAZwA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAYgBY
>> "%~1" echo AFYAMABaAFcAUQBwAGYAUQBvAHYASwBpAEIAbwBaAFgASgB2AEkAQwBvAHYAQwBp
>> "%~1" echo ADUAaABjAEgAQgBJAFoAWABKAHYAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAz
>> "%~1" echo AEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABX
>> "%~1" echo AE4AdgBiAEgAVgB0AGIAbgBNADYATgB6AEoAdwBlAEMAQQB4AFoAbgBJADcAWgAy
>> "%~1" echo AEYAdwBPAGoARQAyAGMASABnADcAWQBXAHgAcABaADIANAB0AGEAWABSAGwAYgBY
>> "%~1" echo AE0ANgBZADIAVgB1AGQARwBWAHkAZgBRAG8AdQBZAFgAQgB3AFMAVwBOAHYAYgBs
>> "%~1" echo AFIAcABiAEcAVgA3AGQAMgBsAGsAZABHAGcANgBOAHoASgB3AGUARAB0AG8AWgBX
>> "%~1" echo AGwAbgBhAEgAUQA2AE4AegBKAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAYwBt
>> "%~1" echo AEYAawBhAFgAVgB6AE8AagBFADQAYwBIAGcANwBZAG0ARgBqAGEAMgBkAHkAYgAz
>> "%~1" echo AFYAdQBaAEQAcABzAGEAVwA1AGwAWQBYAEkAdABaADMASgBoAFoARwBsAGwAYgBu
>> "%~1" echo AFEAbwBNAFQATQAxAFoARwBWAG4ATABIAFoAaABjAGkAZwB0AEwAVwBKAHMAZABX
>> "%~1" echo AFUAcABMAEgAWgBoAGMAaQBnAHQATABXAEoAcwBkAFcAVQB5AEsAUwBrADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADMAQgBzAFkAVwBOAGwATABX
>> "%~1" echo AGwAMABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABqAGIAMgB4AHYAYwBq
>> "%~1" echo AG8AagBaAG0AWgBtAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHoATQBI
>> "%~1" echo AEIANABPADIAWgB2AGIAbgBRAHQAZAAyAFYAcABaADIAaAAwAE8AagBrAHcATQBE
>> "%~1" echo AHQAaQBiADMAZwB0AGMAMgBoAGgAWgBHADkAMwBPAGoAQQBnAE8ASABCADQASQBE
>> "%~1" echo AEkAeQBjAEgAZwBnAGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8AUwB3AHkATQB6
>> "%~1" echo AFUAcwBMAGoAUQBwAGYAUQBvAHUAWQBYAEIAdwBTAFcATgB2AGIAbABSAHAAYgBH
>> "%~1" echo AFUAZwBjADMAWgBuAGUAMwBkAHAAWgBIAFIAbwBPAGoATQA0AGMASABnADcAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBNADQAYwBIAGcANwBaAG0AbABzAGIARABwAHUAYgAy
>> "%~1" echo ADUAbABPADMATgAwAGMAbQA5AHIAWgBUAHAAagBkAFgASgB5AFoAVwA1ADAAUQAy
>> "%~1" echo ADkAcwBiADMASQA3AGMAMwBSAHkAYgAyAHQAbABMAFgAZABwAFoASABSAG8ATwBq
>> "%~1" echo AEoAOQBDAGkANQBoAGMASABCAE8AWQBXADEAbABlADIAWgB2AGIAbgBRAHQAYwAy
>> "%~1" echo AGwANgBaAFQAbwB5AE0AWABCADQATwAyAFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAy
>> "%~1" echo AGgAMABPAGoAZwB3AE0ARAB0ADMAYgAzAEoAawBMAFcASgB5AFoAVwBGAHIATwBt
>> "%~1" echo AEoAeQBaAFcARgByAEwAVwBGAHMAYgBEAHQAcwBhAFcANQBsAEwAVwBoAGwAYQBX
>> "%~1" echo AGQAbwBkAEQAbwB4AEwAagBKADkAQwBpADUAdwBhAFcAeABzAFUAbQA5ADMAZQAy
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAWgBtAHgAbABlAEQAdABtAGIARwBWADQATABY
>> "%~1" echo AGQAeQBZAFgAQQA2AGQAMwBKAGgAYwBEAHQAbgBZAFgAQQA2AE4AMwBCADQATwAy
>> "%~1" echo ADEAaABjAG0AZABwAGIAaQAxADAAYgAzAEEANgBPAFgAQgA0AGYAUQBvAHUAYwBH
>> "%~1" echo AGwAcwBiAEgAdABrAGEAWABOAHcAYgBHAEYANQBPAG0AbAB1AGIARwBsAHUAWgBT
>> "%~1" echo ADEAbQBiAEcAVgA0AE8AMgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBt
>> "%~1" echo AE4AbABiAG4AUgBsAGMAagB0AG8AWgBXAGwAbgBhAEgAUQA2AE0AagBWAHcAZQBE
>> "%~1" echo AHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEAZwBNAFQARgB3AGUARAB0AGkAYgAz
>> "%~1" echo AEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYAegBPAGoAawA1AE8AWABCADQATwAy
>> "%~1" echo AFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNAG4AQgA0AE8AMgBaAHYAYgBu
>> "%~1" echo AFEAdABkADIAVgBwAFoAMgBoADAATwBqAGMAdwBNAEQAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABX
>> "%~1" echo AHgAcABiAG0AVQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBZADIAOQBzAGIAMwBJADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABmAFEAbwB1AGMARwBsAHMAYgBD
>> "%~1" echo ADUAMgBaAFgASgA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBt
>> "%~1" echo AHgAMQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFcATgB2AGIARwA5AHkATwBu
>> "%~1" echo AEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsAcwBNAGoATQAxAEwAQwA0AHoATgBT
>> "%~1" echo AGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoAMgBKAGgASwBE
>> "%~1" echo AE0AMwBMAEQAawA1AEwARABJAHoATgBTAHcAdQBNAEQAZwBwAGYAUQBvAHUAYwBH
>> "%~1" echo AGwAcwBiAEMANQB3AFoAWABKAHQAZQAyAE4AMQBjAG4ATgB2AGMAagBwAHcAYgAy
>> "%~1" echo AGwAdQBkAEcAVgB5AGYAUQBvAHUAYwBHAGwAcwBiAEMANQAzAFkAWABKAHUAZQAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAGoAYgAyAHgAdgBjAGoAcAB5AFoAMgBKAGgASwBE
>> "%~1" echo AEkAeABOAHkAdwB4AE0AVABrAHMATgBpAHcAdQBOAEMAawA3AFkAMgA5AHMAYgAz
>> "%~1" echo AEkANgBkAG0ARgB5AEsAQwAwAHQAWQBXADEAaQBaAFgASQBwAE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQAaQBZAFMAZwB5AE0AVABjAHMATQBU
>> "%~1" echo AEUANQBMAEQAWQBzAEwAagBBADQASwBYADAASwBMAG4AQgBwAGIARwB3AHUAYgAy
>> "%~1" echo AHQANwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8AbgBKAG4AWQBt
>> "%~1" echo AEUAbwBNAGoASQBzAE0AVABZAHoATABEAGMAMABMAEMANAAwAEsAVAB0AGoAYgAy
>> "%~1" echo AHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAbgBjAG0AVgBsAGIAaQBrADcAWQBt
>> "%~1" echo AEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAeQBaADIASgBoAEsARABJAHkATABE
>> "%~1" echo AEUAMgBNAHkAdwAzAE4AQwB3AHUATQBEAGcAcABmAFEAbwB1AGQAbQBWAHkAUQBt
>> "%~1" echo AEYAawBaADIAVgA3AGIAVwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMARABvAHgATgBI
>> "%~1" echo AEIANABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQAQgB3AGUAQwBBAHgATQBu
>> "%~1" echo AEIANABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATQBU
>> "%~1" echo AEIAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBH
>> "%~1" echo AGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABD
>> "%~1" echo AGsANwBaAG0AOQB1AGQAQwAxADMAWgBXAGwAbgBhAEgAUQA2AE4AegBBAHcATwAy
>> "%~1" echo AFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNADMAQgA0AE8AMgBSAHAAYwAz
>> "%~1" echo AEIAcwBZAFgAawA2AGIAbQA5AHUAWgBYADAASwBMAG4AWgBsAGMAawBKAGgAWgBH
>> "%~1" echo AGQAbABMAG4ATgBvAGIAMwBkADcAWgBHAGwAegBjAEcAeABoAGUAVABwAGkAYgBH
>> "%~1" echo ADkAagBhADMAMABLAEwAbgBaAGwAYwBrAEoAaABaAEcAZABsAEwAbgBWAHcAZQAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAGoAYgAyAHgAdgBjAGoAcAB5AFoAMgBKAGgASwBE
>> "%~1" echo AEkAeQBMAEQARQAyAE0AeQB3ADMATgBDAHcAdQBOAEMAawA3AFkAMgA5AHMAYgAz
>> "%~1" echo AEkANgBkAG0ARgB5AEsAQwAwAHQAWgAzAEoAbABaAFcANABwAE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQAaQBZAFMAZwB5AE0AaQB3AHgATgBq
>> "%~1" echo AE0AcwBOAHoAUQBzAEwAagBBADMASwBYADAASwBMAG4AWgBsAGMAawBKAGgAWgBH
>> "%~1" echo AGQAbABMAG0AUgB2AGQAMgA1ADcAWQBtADkAeQBaAEcAVgB5AEwAVwBOAHYAYgBH
>> "%~1" echo ADkAeQBPAG4ASgBuAFkAbQBFAG8ATQBqAEUAMwBMAEQARQB4AE8AUwB3ADIATABD
>> "%~1" echo ADQAMABOAFMAawA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBX
>> "%~1" echo ADEAaQBaAFgASQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB5AE0AVABjAHMATQBUAEUANQBMAEQAWQBzAEwAagBBADMASwBY
>> "%~1" echo ADAASwBMAHkAbwBnAGIAMwBCADAAYQBXADkAdQBjAHkAQQBxAEwAdwBvAHUAYgAz
>> "%~1" echo AEIAMABVAG0AOQAzAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBE
>> "%~1" echo AHQAbQBiAEcAVgA0AEwAWABkAHkAWQBYAEEANgBkADMASgBoAGMARAB0AG4AWQBY
>> "%~1" echo AEEANgBNAFQAQgB3AGUAQwBBAHgATgBuAEIANABPADIAMQBoAGMAbQBkAHAAYgBp
>> "%~1" echo ADEAMABiADMAQQA2AE0AVABaAHcAZQBIADAASwBMAG0AOQB3AGQARQBOAG8AYQBY
>> "%~1" echo AEIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAcABiAG0AeABwAGIAbQBVAHQAWgBt
>> "%~1" echo AHgAbABlAEQAdABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMAegBwAGoAWgBX
>> "%~1" echo ADUAMABaAFgASQA3AFoAMgBGAHcATwBqAGgAdwBlAEQAdABtAGIAMgA1ADAATABY
>> "%~1" echo AGQAbABhAFcAZABvAGQARABvADMATQBEAEEANwBaAG0AOQB1AGQAQwAxAHoAYQBY
>> "%~1" echo AHAAbABPAGoARQB6AGMASABnADcAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBX
>> "%~1" echo ADUAMABaAFgASQA3AGQAWABOAGwAYwBpADEAegBaAFcAeABsAFkAMwBRADYAYgBt
>> "%~1" echo ADkAdQBaAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAZAB3AGUAQwBBAHgATQBY
>> "%~1" echo AEIANABPADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBX
>> "%~1" echo AFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQA5AHkAWgBH
>> "%~1" echo AFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8ANQBjAEgAZwA3AFkAbQBGAGoAYQAy
>> "%~1" echo AGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBY
>> "%~1" echo ADAASwBMAG0AOQB3AGQARQBOAG8AYQBYAEEAZwBhAFcANQB3AGQAWABSADcAWQBX
>> "%~1" echo AE4AagBaAFcANQAwAEwAVwBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABX
>> "%~1" echo AEoAcwBkAFcAVQBwAE8AMwBkAHAAWgBIAFIAbwBPAG0ARgAxAGQARwA4ADcAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AbQBGADEAZABHADkAOQBDAGkANQB2AGMASABSAEQAYQBH
>> "%~1" echo AGwAdwBJAEgATgB0AFkAVwB4AHMAZQAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFcAMQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABkAGwAYQBX
>> "%~1" echo AGQAbwBkAEQAbwAwAE0ARABCADkAQwBpADgAcQBJAEgAUgBvAFoAUwBCAHQAYgAz
>> "%~1" echo AEoAdwBhAEcAbAB1AFoAeQBCAHAAYgBuAE4AMABZAFcAeABzAEkARwBKADEAZABI
>> "%~1" echo AFIAdgBiAGkAQQBxAEwAdwBvAHUAYQBXADUAegBkAEcARgBzAGIARQBKADAAYgBu
>> "%~1" echo AHQAdwBiADMATgBwAGQARwBsAHYAYgBqAHAAeQBaAFcAeABoAGQARwBsADIAWgBU
>> "%~1" echo AHQAdgBkAG0AVgB5AFoAbQB4AHYAZAB6AHAAbwBhAFcAUgBrAFoAVwA0ADcAZAAy
>> "%~1" echo AGwAawBkAEcAZwA2AE0AVABBAHcASgBUAHQAbwBaAFcAbABuAGEASABRADYATgBU
>> "%~1" echo AFIAdwBlAEQAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8AagBFADQAYwBI
>> "%~1" echo AGcANwBZAG0AOQB5AFoARwBWAHkATwBtADUAdgBiAG0AVQA3AFkAbQA5AHkAWgBH
>> "%~1" echo AFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8AeABNAG4AQgA0AE8AMgBKAGgAWQAy
>> "%~1" echo AHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBT
>> "%~1" echo AGsANwBZADIAOQBzAGIAMwBJADYASQAyAFoAbQBaAGoAdABtAGIAMgA1ADAATABY
>> "%~1" echo AE4AcABlAG0AVQA2AE0AVABaAHcAZQBEAHQAbQBiADIANQAwAEwAWABkAGwAYQBX
>> "%~1" echo AGQAbwBkAEQAbwA0AE0ARABBADcAWQAzAFYAeQBjADIAOQB5AE8AbgBCAHYAYQBX
>> "%~1" echo ADUAMABaAFgASQA3AGQASABKAGgAYgBuAE4AcABkAEcAbAB2AGIAagBwAG0AYQBX
>> "%~1" echo AHgAMABaAFgASQBnAEwAagBFADEAYwB5AHgAMABjAG0ARgB1AGMAMgBaAHYAYwBt
>> "%~1" echo ADAAZwBMAGoAQQA0AGMAMwAwAEsATABtAGwAdQBjADMAUgBoAGIARwB4AEMAZABH
>> "%~1" echo ADQANgBhAEcAOQAyAFoAWABKADcAWgBtAGwAcwBkAEcAVgB5AE8AbQBKAHkAYQBX
>> "%~1" echo AGQAbwBkAEcANQBsAGMAMwBNAG8ATQBTADQAdwBOAFMAbAA5AEwAbQBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAeABDAGQARwA0ADYAWQBXAE4AMABhAFgAWgBsAGUAMwBSAHkAWQBX
>> "%~1" echo ADUAegBaAG0AOQB5AGIAVABwADAAYwBtAEYAdQBjADIAeABoAGQARwBWAFoASwBE
>> "%~1" echo AEYAdwBlAEMAbAA5AEMAaQA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUASQBD
>> "%~1" echo ADUAcABiAG4ATgAwAFkAVwB4AHMAUgBtAGwAcwBiAEgAdAB3AGIAMwBOAHAAZABH
>> "%~1" echo AGwAdgBiAGoAcABoAFkAbgBOAHYAYgBIAFYAMABaAFQAdABwAGIAbgBOAGwAZABE
>> "%~1" echo AG8AdwBJAEcARgAxAGQARwA4AGcATQBDAEEAdwBPADMAZABwAFoASABSAG8ATwBq
>> "%~1" echo AEEANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcABzAGEAVwA1AGwAWQBY
>> "%~1" echo AEkAdABaADMASgBoAFoARwBsAGwAYgBuAFEAbwBPAFQAQgBrAFoAVwBjAHMAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsAcwBkAG0ARgB5AEsAQwAwAHQAWQBt
>> "%~1" echo AHgAMQBaAFQASQBwAEsAVAB0ADAAYwBtAEYAdQBjADIAbAAwAGEAVwA5AHUATwBu
>> "%~1" echo AGQAcABaAEgAUgBvAEkAQwA0AHoAYwB5AEIAbABZAFgATgBsAGYAUQBvAHUAYQBX
>> "%~1" echo ADUAegBkAEcARgBzAGIARQBKADAAYgBpADUAcABiAG4ATgAwAFkAVwB4AHMAYQBX
>> "%~1" echo ADUAbgBlADIATgAxAGMAbgBOAHYAYwBqAHAAdwBjAG0AOQBuAGMAbQBWAHoAYwB6
>> "%~1" echo AHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4ASgBuAFkAbQBFAG8ATQB6
>> "%~1" echo AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAeABPAEMAbAA5AEMAaQA1AHAAYgBu
>> "%~1" echo AE4AMABZAFcAeABzAFEAbgBSAHUATABtAGwAdQBjADMAUgBoAGIARwB4AHAAYgBt
>> "%~1" echo AGMAZwBMAG0AbAB1AGMAMwBSAGgAYgBHAHgARwBhAFcAeABzAGUAMgBKAHYAZQBD
>> "%~1" echo ADEAegBhAEcARgBrAGIAMwBjADYATQBDAEEAdwBJAEQARQA0AGMASABnAGcAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB6AE4AeQB3ADUATwBTAHcAeQBNAHoAVQBzAEwAagBVAHAAZgBR
>> "%~1" echo AG8AdQBhAFcANQB6AGQARwBGAHMAYgBFAEoAMABiAGkANQBwAGIAbgBOADAAWQBX
>> "%~1" echo AHgAcwBhAFcANQBuAEkAQwA1AHAAYgBuAE4AMABZAFcAeABzAFIAbQBsAHMAYgBE
>> "%~1" echo AHAAaABaAG4AUgBsAGMAbgB0AGoAYgAyADUAMABaAFcANQAwAE8AaQBJAGkATwAz
>> "%~1" echo AEIAdgBjADIAbAAwAGEAVwA5AHUATwBtAEYAaQBjADIAOQBzAGQAWABSAGwATwAy
>> "%~1" echo AGwAdQBjADIAVgAwAE8AagBBADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBE
>> "%~1" echo AHAAcwBhAFcANQBsAFkAWABJAHQAWgAzAEoAaABaAEcAbABsAGIAbgBRAG8ATwBU
>> "%~1" echo AEIAawBaAFcAYwBzAGQASABKAGgAYgBuAE4AdwBZAFgASgBsAGIAbgBRAHMAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB5AE4AVABVAHMATQBqAFUAMQBMAEQASQAxAE4AUwB3AHUATQB6
>> "%~1" echo AFUAcABMAEgAUgB5AFkAVwA1AHoAYwBHAEYAeQBaAFcANQAwAEsAVAB0AGgAYgBt
>> "%~1" echo AGwAdABZAFgAUgBwAGIAMgA0ADYAYwAyAGgAbABaAFcANABnAE0AUwA0AHkAYwB5
>> "%~1" echo AEIAcwBhAFcANQBsAFkAWABJAGcAYQBXADUAbQBhAFcANQBwAGQARwBWADkAQwBr
>> "%~1" echo AEIAcgBaAFgAbABtAGMAbQBGAHQAWgBYAE0AZwBjADIAaABsAFoAVwA1ADcAWgBu
>> "%~1" echo AEoAdgBiAFgAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGQASABKAGgAYgBu
>> "%~1" echo AE4AcwBZAFgAUgBsAFcAQwBnAHQATQBUAEEAdwBKAFMAbAA5AGQARwA5ADcAZABI
>> "%~1" echo AEoAaABiAG4ATgBtAGIAMwBKAHQATwBuAFIAeQBZAFcANQB6AGIARwBGADAAWgBW
>> "%~1" echo AGcAbwBNAFQAQQB3AEoAUwBsADkAZgBRAG8AdQBhAFcANQB6AGQARwBGAHMAYgBF
>> "%~1" echo AEoAMABiAGkAQQB1AGEAVwA1AHoAZABHAEYAcwBiAEUAeABoAFkAbQBWAHMAZQAz
>> "%~1" echo AEIAdgBjADIAbAAwAGEAVwA5AHUATwBuAEoAbABiAEcARgAwAGEAWABaAGwATwAz
>> "%~1" echo AG8AdABhAFcANQBrAFoAWABnADYATQBUAHQAawBhAFgATgB3AGIARwBGADUATwBt
>> "%~1" echo AFoAcwBaAFgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAy
>> "%~1" echo AFYAdQBkAEcAVgB5AE8AMgBwADEAYwAzAFIAcABaAG4AawB0AFkAMgA5AHUAZABH
>> "%~1" echo AFYAdQBkAEQAcABqAFoAVwA1ADAAWgBYAEkANwBaADIARgB3AE8AagBsAHcAZQBE
>> "%~1" echo AHQAbwBaAFcAbABuAGEASABRADYATQBUAEEAdwBKAFgAMABLAEwAbQBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAeABDAGQARwA0AHUAWgBHADkAdQBaAFgAdABpAFkAVwBOAHIAWgAz
>> "%~1" echo AEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcAdABMAFcAZAB5AFoAVwBWAHUASwBY
>> "%~1" echo ADAAdQBhAFcANQB6AGQARwBGAHMAYgBFAEoAMABiAGkANQBrAGIAMgA1AGwASQBD
>> "%~1" echo ADUAcABiAG4ATgAwAFkAVwB4AHMAUgBtAGwAcwBiAEgAdAAzAGEAVwBSADAAYQBE
>> "%~1" echo AG8AeABNAEQAQQBsAEkAVwBsAHQAYwBHADkAeQBkAEcARgB1AGQARAB0AGkAWQBX
>> "%~1" echo AE4AcgBaADMASgB2AGQAVwA1AGsATwBuAFoAaABjAGkAZwB0AEwAVwBkAHkAWgBX
>> "%~1" echo AFYAdQBLAFgAMABLAEwAbQBsAHUAYwAzAFIAaABiAEcAeABDAGQARwA0AHUAWgBt
>> "%~1" echo AEYAcABiAEcAVgBrAGUAMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAAdQBhAFcANQB6AGQARwBGAHMAYgBF
>> "%~1" echo AEoAMABiAGkANQBtAFkAVwBsAHMAWgBXAFEAZwBMAG0AbAB1AGMAMwBSAGgAYgBH
>> "%~1" echo AHgARwBhAFcAeABzAGUAMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAASwBMAG0AbAB1AGMAMwBSAGgAYgBH
>> "%~1" echo AHgAQwBkAEcANAB1AFoAbQBGAHAAYgBHAFYAawBlADIARgB1AGEAVwAxAGgAZABH
>> "%~1" echo AGwAdgBiAGoAcAB6AGEARwBGAHIAWgBTAEEAdQBOAEgATgA5AEMAawBCAHIAWgBY
>> "%~1" echo AGwAbQBjAG0ARgB0AFoAWABNAGcAYwAyAGgAaABhADIAVgA3AE0AVABBAGwATABE
>> "%~1" echo AGsAdwBKAFgAdAAwAGMAbQBGAHUAYwAyAFoAdgBjAG0AMAA2AGQASABKAGgAYgBu
>> "%~1" echo AE4AcwBZAFgAUgBsAFcAQwBnAHQATQBuAEIANABLAFgAMAB6AE0AQwBVAHMATgB6
>> "%~1" echo AEEAbABlADMAUgB5AFkAVwA1AHoAWgBtADkAeQBiAFQAcAAwAGMAbQBGAHUAYwAy
>> "%~1" echo AHgAaABkAEcAVgBZAEsARABSAHcAZQBDAGwAOQBOAFQAQQBsAGUAMwBSAHkAWQBX
>> "%~1" echo ADUAegBaAG0AOQB5AGIAVABwADAAYwBtAEYAdQBjADIAeABoAGQARwBWAFkASwBD
>> "%~1" echo ADAAMABjAEgAZwBwAGYAWAAwAEsATABtAE4AbwBhADMAdAAzAGEAVwBSADAAYQBE
>> "%~1" echo AG8AeQBNAG4AQgA0AE8AMgBoAGwAYQBXAGQAbwBkAEQAbwB5AE0AbgBCADQAZgBT
>> "%~1" echo ADUAagBhAEcAcwBnAGMARwBGADAAYQBIAHQAegBkAEgASgB2AGEAMgBVADYASQAy
>> "%~1" echo AFoAbQBaAGoAdAB6AGQASABKAHYAYQAyAFUAdABkADIAbABrAGQARwBnADYATQB6
>> "%~1" echo AHQAbQBhAFcAeABzAE8AbQA1AHYAYgBtAFUANwBjADMAUgB5AGIAMgB0AGwATABX
>> "%~1" echo AHgAcABiAG0AVgBqAFkAWABBADYAYwBtADkAMQBiAG0AUQA3AGMAMwBSAHkAYgAy
>> "%~1" echo AHQAbABMAFcAeABwAGIAbQBWAHEAYgAyAGwAdQBPAG4ASgB2AGQAVwA1AGsATwAz
>> "%~1" echo AE4AMABjAG0AOQByAFoAUwAxAGsAWQBYAE4AbwBZAFgASgB5AFkAWABrADYATQBq
>> "%~1" echo AFkANwBjADMAUgB5AGIAMgB0AGwATABXAFIAaABjADIAaAB2AFoAbQBaAHoAWgBY
>> "%~1" echo AFEANgBNAGoAWgA5AEMAaQA1AHAAYgBuAE4AMABZAFcAeABzAFEAbgBSAHUATABt
>> "%~1" echo AFIAdgBiAG0AVQBnAEwAbQBOAG8AYQB5AEIAdwBZAFgAUgBvAGUAMgBGAHUAYQBX
>> "%~1" echo ADEAaABkAEcAbAB2AGIAagBwAGoAYQBHAHQARQBjAG0ARgAzAEkAQwA0ADEAYwB5
>> "%~1" echo AEEAdQBNAFgATQBnAFoAbQA5AHkAZAAyAEYAeQBaAEgATQBnAFoAVwBGAHoAWgBY
>> "%~1" echo ADAASwBRAEcAdABsAGUAVwBaAHkAWQBXADEAbABjAHkAQgBqAGEARwB0AEUAYwBt
>> "%~1" echo AEYAMwBlADMAUgB2AGUAMwBOADAAYwBtADkAcgBaAFMAMQBrAFkAWABOAG8AYgAy
>> "%~1" echo AFoAbQBjADIAVgAwAE8AagBCADkAZgBRAG8AdgBLAGkAQgB6AGQARwBGAG4AWgBT
>> "%~1" echo AEEAcgBJAEgATgAwAGMAbQBWAGgAYgBXAFYAawBJAEcARgBrAFkAaQBCAHYAZABY
>> "%~1" echo AFIAdwBkAFgAUQBnAEsAaQA4AEsATABuAE4AMABZAFcAZABsAFUAbQA5ADMAZQAy
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAYgBtADkAdQBaAFQAdABoAGIARwBsAG4AYgBp
>> "%~1" echo ADEAcABkAEcAVgB0AGMAegBwAGoAWgBXADUAMABaAFgASQA3AGEAbgBWAHoAZABH
>> "%~1" echo AGwAbQBlAFMAMQBqAGIAMgA1ADAAWgBXADUAMABPAG4ATgB3AFkAVwBOAGwATABX
>> "%~1" echo AEoAbABkAEgAZABsAFoAVwA0ADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBE
>> "%~1" echo AG8AeABOAEgAQgA0AE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBq
>> "%~1" echo AGMAdwBNAEgAMABLAEwAbgBOADAAWQBXAGQAbABVAG0AOQAzAEwAbgBOAG8AYgAz
>> "%~1" echo AGQANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbQBiAEcAVgA0AGYAUQBvAHUAYwAz
>> "%~1" echo AFIAaABaADIAVgBTAGIAMwBjAGcATABtAFYAcwBZAFgAQgB6AFoAVwBSADcAWgBt
>> "%~1" echo ADkAdQBkAEMAMQBtAFkAVwAxAHAAYgBIAGsANgBRADIAOQB1AGMAMgA5AHMAWQBY
>> "%~1" echo AE0AcwBiAFcAOQB1AGIAMwBOAHcAWQBXAE4AbABPADIATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABY
>> "%~1" echo AGQAbABhAFcAZABvAGQARABvADAATQBEAEIAOQBDAGkANQBoAFoARwBKAFAAZABY
>> "%~1" echo AFIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAdQBiADIANQBsAE8AMgAxAGgAYwBt
>> "%~1" echo AGQAcABiAGkAMQAwAGIAMwBBADYATQBUAEoAdwBlAEQAdAB0AFkAWABnAHQAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBFADMATQBIAEIANABPADIAOQAyAFoAWABKAG0AYgBH
>> "%~1" echo ADkAMwBPAG0ARgAxAGQARwA4ADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBD
>> "%~1" echo AEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBU
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8AagBFAHcAYwBI
>> "%~1" echo AGcANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAbwBqAE0ARwBFAHcAWgBq
>> "%~1" echo AEUAMgBPADIATgB2AGIARwA5AHkATwBpAE0ANQBaAG0ASQB6AFkAegBnADcAYwBH
>> "%~1" echo AEYAawBaAEcAbAB1AFoAegBvAHgATQBYAEIANABJAEQARQB5AGMASABnADcAWgBt
>> "%~1" echo ADkAdQBkAEMAMQBtAFkAVwAxAHAAYgBIAGsANgBRADIAOQB1AGMAMgA5AHMAWQBY
>> "%~1" echo AE0AcwBiAFcAOQB1AGIAMwBOAHcAWQBXAE4AbABPADIAWgB2AGIAbgBRAHQAYwAy
>> "%~1" echo AGwANgBaAFQAbwB4AE0AbgBCADQATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAy
>> "%~1" echo AGgAMABPAGoARQB1AE4AVABVADcAZAAyAGgAcABkAEcAVQB0AGMAMwBCAGgAWQAy
>> "%~1" echo AFUANgBjAEgASgBsAEwAWABkAHkAWQBYAEEANwBkADIAOQB5AFoAQwAxAGkAYwBt
>> "%~1" echo AFYAaABhAHoAcABpAGMAbQBWAGgAYQB5ADEAMwBiADMASgBrAGYAUQBwAGkAYgAy
>> "%~1" echo AFIANQBPAG0ANQB2AGQAQwBnAHUAWgBHAEYAeQBhAHkAawBnAEwAbQBGAGsAWQBr
>> "%~1" echo ADkAMQBkAEgAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AaQBNAHcAWgBq
>> "%~1" echo AEUAMwBNAGoAQQA3AFkAMgA5AHMAYgAzAEkANgBJADIATgBtAFoAVABCAG0ATQBI
>> "%~1" echo ADAASwBMAG0ARgBrAFkAawA5ADEAZABDADUAegBhAEcAOQAzAGUAMgBSAHAAYwAz
>> "%~1" echo AEIAcwBZAFgAawA2AFkAbQB4AHYAWQAyAHQAOQBDAGkANQB3AFoAWABKAHQAYwAx
>> "%~1" echo AEIAdgBjAEgAdABrAGEAWABOAHcAYgBHAEYANQBPAG0ANQB2AGIAbQBVADcAYgBX
>> "%~1" echo AEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8AeABNAG4AQgA0AE8AMgAxAGgAZQBD
>> "%~1" echo ADEAbwBaAFcAbABuAGEASABRADYATQBUAFUAdwBjAEgAZwA3AGIAMwBaAGwAYwBt
>> "%~1" echo AFoAcwBiADMAYwA2AFkAWABWADAAYgB6AHQAaQBiADMASgBrAFoAWABJADYATQBY
>> "%~1" echo AEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBt
>> "%~1" echo AFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATQBU
>> "%~1" echo AEIAdwBlAEQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBp
>> "%~1" echo AGcAdABMAFgATgB2AFoAbgBRAHAATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBU
>> "%~1" echo AEYAdwBlAEQAdABtAGIAMgA1ADAATABXAFoAaABiAFcAbABzAGUAVABwAEQAYgAy
>> "%~1" echo ADUAegBiADIAeABoAGMAeQB4AHQAYgAyADUAdgBjADMAQgBoAFkAMgBVADcAWgBt
>> "%~1" echo ADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAeQBjAEgAZwA3AFkAMgA5AHMAYgAz
>> "%~1" echo AEkANgBkAG0ARgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMwBkAG8AYQBY
>> "%~1" echo AFIAbABMAFgATgB3AFkAVwBOAGwATwBuAEIAeQBaAFMAMQAzAGMAbQBGAHcATwAy
>> "%~1" echo AHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgAMABPAGoARQB1AE4AbgAwAEsATABu
>> "%~1" echo AEIAbABjAG0AMQB6AFUARwA5AHcATABuAE4AbwBiADMAZAA3AFoARwBsAHoAYwBH
>> "%~1" echo AHgAaABlAFQAcABpAGIARwA5AGoAYQAzADAASwBRAEcAMQBsAFoARwBsAGgASQBD
>> "%~1" echo AGgAdwBjAG0AVgBtAFoAWABKAHoATABYAEoAbABaAEgAVgBqAFoAVwBRAHQAYgBX
>> "%~1" echo ADkAMABhAFcAOQB1AE8AaQBCAHkAWgBXAFIAMQBZADIAVQBwAGUAeQA1AGgAYwBI
>> "%~1" echo AEIARABZAFgASgBrAEwAQwA1AGgAYwBIAEIARABZAFgASgBrAEwAbQBkAHMAYgAz
>> "%~1" echo AGMAcwBMAG0AUgB5AGIAMwBCAEYAYgBYAEIAMABlAFMAQgB6AGQAbQBjAHMATABt
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB4AEMAZABHADQAdQBhAFcANQB6AGQARwBGAHMAYgBH
>> "%~1" echo AGwAdQBaAHkAQQB1AGEAVwA1AHoAZABHAEYAcwBiAEUAWgBwAGIARwB3ADYAWQBX
>> "%~1" echo AFoAMABaAFgASQBzAEwAbQBsAHUAYwAzAFIAaABiAEcAeABDAGQARwA0AHUAWgBH
>> "%~1" echo ADkAdQBaAFMAQQB1AFkAMgBoAHIASQBIAEIAaABkAEcAZwBzAEwAbQBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAeABDAGQARwA0AHUAWgBtAEYAcABiAEcAVgBrAGUAMgBGAHUAYQBX
>> "%~1" echo ADEAaABkAEcAbAB2AGIAagBwAHUAYgAyADUAbABmAFgAMABLAFEARwAxAGwAWgBH
>> "%~1" echo AGwAaABLAEcAMQBoAGUAQwAxADMAYQBXAFIAMABhAEQAbwA0AE0AagBCAHcAZQBD
>> "%~1" echo AGwANwBMAG0ARgB3AGMARQBoAGwAYwBtADkANwBaADMASgBwAFoAQwAxADAAWgBX
>> "%~1" echo ADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8AagBGAG0AYwBq
>> "%~1" echo AHQAMABaAFgAaAAwAEwAVwBGAHMAYQBXAGQAdQBPAG0ATgBsAGIAbgBSAGwAYwBq
>> "%~1" echo AHQAcQBkAFgATgAwAGEAVwBaADUATABXAGwAMABaAFcAMQB6AE8AbQBOAGwAYgBu
>> "%~1" echo AFIAbABjAG4AMQA5AEMAaQA4AHEASQBDADAAdABMAFMAQgB6AGEARwBGAHkAWgBX
>> "%~1" echo AFEAZwBMAFMAMAB0AEkAQwBvAHYAQwBpADUAdwBZAFgASgBoAGIAVQB4AHAAYwAz
>> "%~1" echo AFIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAGgAYwBE
>> "%~1" echo AG8AeABNAFgAQgA0AGYAUQBvAHUAYwBHAEYAeQBZAFcAMQBKAGQARwBWAHQAZQAy
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABY
>> "%~1" echo AFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBT
>> "%~1" echo ADQAeQBaAG4ASQBnAEwAagBoAG0AYwBpAEEAdQBPAEcAWgB5AEkARwBGADEAZABH
>> "%~1" echo ADgANwBaADIARgB3AE8AagBFAHgAYwBIAGcANwBZAFcAeABwAFoAMgA0AHQAYQBY
>> "%~1" echo AFIAbABiAFgATQA2AFkAMgBWAHUAZABHAFYAeQBPADIASgB2AGMAbQBSAGwAYwBq
>> "%~1" echo AG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBH
>> "%~1" echo AGwAdQBaAFMAawA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQB6AGIAMgBaADAASwBUAHQAaQBiADMASgBrAFoAWABJAHQAYwBt
>> "%~1" echo AEYAawBhAFgAVgB6AE8AagBsAHcAZQBEAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBq
>> "%~1" echo AEUAeABjAEgAZwBnAE0AVABOAHcAZQBIADAASwBMAG4AQgBoAGMAbQBGAHQAVABt
>> "%~1" echo AEYAdABaAFMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFkAbQB4AHYAWQAy
>> "%~1" echo AHQAOQBMAG4AQgBoAGMAbQBGAHQAVABtAEYAdABaAFMAQgB6AGMARwBGAHUATABD
>> "%~1" echo ADUAdwBZAFgASgBoAGIAVgBaAGgAYgBIAFYAbABJAEgATgB3AFkAVwA1ADcAWgBH
>> "%~1" echo AGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkAagBhAHoAdABqAGIAMgB4AHYAYwBq
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABD
>> "%~1" echo ADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGcANwBiAFcARgB5AFoAMgBsAHUATABY
>> "%~1" echo AFIAdgBjAEQAbwB6AGMASABoADkATABuAEIAaABjAG0ARgB0AFYAbQBGAHMAZABX
>> "%~1" echo AFUAZwBZAG4AdABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAz
>> "%~1" echo AGQAdgBjAG0AUQB0AFkAbgBKAGwAWQBXAHMANgBZAG4ASgBsAFkAVwBzAHQAZAAy
>> "%~1" echo ADkAeQBaAEgAMABLAEwAbgBCAGgAYwBtAEYAdABVADMAUgBoAGQARwBWADcAYQBH
>> "%~1" echo AFYAcABaADIAaAAwAE8AagBJADIAYwBIAGcANwBZAG0AOQB5AFoARwBWAHkATwBq
>> "%~1" echo AEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBX
>> "%~1" echo ADUAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBq
>> "%~1" echo AGsANQBPAFgAQgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AGEAVwA1AHMAYQBX
>> "%~1" echo ADUAbABMAFcAWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEAWABSAGwAYgBY
>> "%~1" echo AE0ANgBZADIAVgB1AGQARwBWAHkATwAyAHAAMQBjADMAUgBwAFoAbgBrAHQAWQAy
>> "%~1" echo ADkAdQBkAEcAVgB1AGQARABwAGoAWgBXADUAMABaAFgASQA3AGMARwBGAGsAWgBH
>> "%~1" echo AGwAdQBaAHoAbwB3AEkARABFAHgAYwBIAGcANwBaAG0AOQB1AGQAQwAxADMAWgBX
>> "%~1" echo AGwAbgBhAEgAUQA2AE8ARABBAHcATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBU
>> "%~1" echo AG8AeABNAG4AQgA0AGYAUQBvAHUAYwBHAEYAeQBZAFcAMQBKAGQARwBWAHQATABt
>> "%~1" echo AE4AbwBZAFcANQBuAFoAVwBSADcAWQBtADkAeQBaAEcAVgB5AEwAVwBOAHYAYgBH
>> "%~1" echo ADkAeQBPAG4ASgBuAFkAbQBFAG8ATQBqAEUAMwBMAEQARQB4AE8AUwB3ADIATABD
>> "%~1" echo ADQAMABOAFMAawA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwAHkAWgAy
>> "%~1" echo AEoAaABLAEQASQB4AE4AeQB3AHgATQBUAGsAcwBOAGkAdwB1AE0ARABZAHAAZgBT
>> "%~1" echo ADUAdwBZAFgASgBoAGIAVQBsADAAWgBXADAAdQBZADIAaABoAGIAbQBkAGwAWgBD
>> "%~1" echo AEEAdQBjAEcARgB5AFkAVwAxAFQAZABHAEYAMABaAFgAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABZADIAOQBzAGIAMwBJADYAYwBtAGQAaQBZAFMAZwB5AE0AVABjAHMATQBU
>> "%~1" echo AEUANQBMAEQAWQBzAEwAagBRADEASwBUAHQAagBiADIAeAB2AGMAagBwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQBoAGIAVwBKAGwAYwBpAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAz
>> "%~1" echo AFYAdQBaAEQAcAB5AFoAMgBKAGgASwBEAEkAeABOAHkAdwB4AE0AVABrAHMATgBp
>> "%~1" echo AHcAdQBNAEQAZwBwAGYAUQBvAHUAYwBHAEYAeQBZAFcAMQBKAGQARwBWAHQATABt
>> "%~1" echo ADkAcgBJAEMANQB3AFkAWABKAGgAYgBWAE4AMABZAFgAUgBsAGUAMgBKAHYAYwBt
>> "%~1" echo AFIAbABjAGkAMQBqAGIAMgB4AHYAYwBqAHAAeQBaADIASgBoAEsARABJAHkATABE
>> "%~1" echo AEUAMgBNAHkAdwAzAE4AQwB3AHUATQB6AFUAcABPADIATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwBkAHkAWgBXAFYAdQBLAFQAdABpAFkAVwBOAHIAWgAz
>> "%~1" echo AEoAdgBkAFcANQBrAE8AbgBKAG4AWQBtAEUAbwBNAGoASQBzAE0AVABZAHoATABE
>> "%~1" echo AGMAMABMAEMANAB3AE8AQwBsADkAQwBpADUAeQBaAFgATgBsAGQARQBKADAAYgBu
>> "%~1" echo AHQAbwBaAFcAbABuAGEASABRADYATQB6AEYAdwBlAEQAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkAdABjAG0ARgBrAGEAWABWAHoATwBqAGgAdwBlAEQAdABpAGIAMwBKAGsAWgBY
>> "%~1" echo AEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABX
>> "%~1" echo AHgAcABiAG0AVQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AFkAMgBGAHkAWgBDAGsANwBZADIAOQBzAGIAMwBJADYAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGQARwBWADQAZABDAGsANwBaAG0AOQB1AGQAQwAxADMAWgBX
>> "%~1" echo AGwAbgBhAEgAUQA2AE8ARABBAHcATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBD
>> "%~1" echo AEEAeABNAFgAQgA0AE8AMgBOADEAYwBuAE4AdgBjAGoAcAB3AGIAMgBsAHUAZABH
>> "%~1" echo AFYAeQBmAFMANQB5AFoAWABOAGwAZABFAEoAMABiAGkANQB3AGMAbQBsAHQAWQBY
>> "%~1" echo AEoANQBlADIASgB2AGMAbQBSAGwAYwBpADEAagBiADIAeAB2AGMAagBwAHkAWgAy
>> "%~1" echo AEoAaABLAEQATQAzAEwARABrADUATABEAEkAegBOAFMAdwB1AE4ARABVAHAATwAy
>> "%~1" echo AE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAAZgBR
>> "%~1" echo AG8AdQBkAEcAOQBoAGMAMwBSAHoAZQAzAEIAdgBjADIAbAAwAGEAVwA5AHUATwBt
>> "%~1" echo AFoAcABlAEcAVgBrAE8AMwBKAHAAWgAyAGgAMABPAGoASQB5AGMASABnADcAWQBt
>> "%~1" echo ADkAMABkAEcAOQB0AE8AagBJAHkAYwBIAGcANwBlAGkAMQBwAGIAbQBSAGwAZQBE
>> "%~1" echo AG8AMgBNAEQAdABrAGEAWABOAHcAYgBHAEYANQBPAG0AWgBzAFoAWABnADcAWgBt
>> "%~1" echo AHgAbABlAEMAMQBrAGEAWABKAGwAWQAzAFIAcABiADIANAA2AFkAMgA5AHMAZABX
>> "%~1" echo ADEAdQBMAFgASgBsAGQAbQBWAHkAYwAyAFUANwBaADIARgB3AE8AagBFAHcAYwBI
>> "%~1" echo AGcANwBkADIAbABrAGQARwBnADYAYgBXAGwAdQBLAEQATQA1AE0ASABCADQATABH
>> "%~1" echo AE4AaABiAEcATQBvAE0AVABBAHcAZABuAGMAZwBMAFMAQQB5AE8ASABCADQASwBT
>> "%~1" echo AGsANwBjAEcAOQBwAGIAbgBSAGwAYwBpADEAbABkAG0AVgB1AGQASABNADYAYgBt
>> "%~1" echo ADkAdQBaAFgAMABLAEwAbgBSAHYAWQBYAE4AMABlADIASgB2AGMAbQBSAGwAYwBq
>> "%~1" echo AG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBH
>> "%~1" echo AGwAdQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFcAeABsAFoAbgBRADYATgBI
>> "%~1" echo AEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwBKAHMAZABX
>> "%~1" echo AFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABZADIARgB5AFoAQwBrADcAWQBtADkANABMAFgATgBvAFkAVwBSAHYAZAB6
>> "%~1" echo AG8AdwBJAEQARQAyAGMASABnAGcATQB6AGgAdwBlAEMAQgB5AFoAMgBKAGgASwBE
>> "%~1" echo AEUAMQBMAEQASQB6AEwARABRAHkATABDADQAeQBNAEMAawA3AFkAbQA5AHkAWgBH
>> "%~1" echo AFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8AeABNAEgAQgA0AE8AMwBCAGgAWgBH
>> "%~1" echo AFIAcABiAG0AYwA2AE0AVABKAHcAZQBDAEEAeABNADMAQgA0AE8AMgA5AHcAWQBX
>> "%~1" echo AE4AcABkAEgAawA2AE0ARAB0ADAAYwBtAEYAdQBjADIAWgB2AGMAbQAwADYAZABI
>> "%~1" echo AEoAaABiAG4ATgBzAFkAWABSAGwAVwBDAGcAeQBOAEgAQgA0AEsAUwBCADAAYwBt
>> "%~1" echo AEYAdQBjADIAeABoAGQARwBWAFoASwBEAEUAdwBjAEgAZwBwAEkASABOAGoAWQBX
>> "%~1" echo AHgAbABLAEMANAA1AE8AQwBrADcAZABIAEoAaABiAG4ATgBwAGQARwBsAHYAYgBq
>> "%~1" echo AHAAdgBjAEcARgBqAGEAWABSADUASQBDADQAeQBNAG4ATQBnAFoAVwBGAHoAWgBT
>> "%~1" echo AHgAMABjAG0ARgB1AGMAMgBaAHYAYwBtADAAZwBMAGoASQB5AGMAeQBCAGoAZABX
>> "%~1" echo AEoAcABZAHkAMQBpAFoAWABwAHAAWgBYAEkAbwBMAGoASQBzAEwAagBnAHMATABq
>> "%~1" echo AEkAcwBNAFMAawA3AGMARwA5AHAAYgBuAFIAbABjAGkAMQBsAGQAbQBWAHUAZABI
>> "%~1" echo AE0ANgBZAFgAVgAwAGIAMwAwAEsATABuAFIAdgBZAFgATgAwAEwAbgBOAG8AYgAz
>> "%~1" echo AGQANwBiADMAQgBoAFkAMgBsADAAZQBUAG8AeABPADMAUgB5AFkAVwA1AHoAWgBt
>> "%~1" echo ADkAeQBiAFQAcAB1AGIAMgA1AGwAZgBTADUAMABiADIARgB6AGQAQwBCAGkAZQAy
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAWQBtAHgAdgBZADIAcwA3AGIAVwBGAHkAWgAy
>> "%~1" echo AGwAdQBMAFcASgB2AGQASABSAHYAYgBUAG8AMABjAEgAaAA5AEwAbgBSAHYAWQBY
>> "%~1" echo AE4AMABJAEgATgB3AFkAVwA1ADcAWgBHAGwAegBjAEcAeABoAGUAVABwAGkAYgBH
>> "%~1" echo ADkAagBhAHoAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABY
>> "%~1" echo AFIAbABaAEMAawA3AGIARwBsAHUAWgBTADEAbwBaAFcAbABuAGEASABRADYATQBT
>> "%~1" echo ADQAMABOAFQAdAAzAGIAMwBKAGsATABXAEoAeQBaAFcARgByAE8AbQBKAHkAWgBX
>> "%~1" echo AEYAcgBMAFgAZAB2AGMAbQBSADkAQwBpADUAMABiADIARgB6AGQAQwA1AHYAYQAz
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYAbQBkAEMAMQBqAGIAMgB4AHYAYwBq
>> "%~1" echo AHAAMgBZAFgASQBvAEwAUwAxAG4AYwBtAFYAbABiAGkAbAA5AEwAbgBSAHYAWQBY
>> "%~1" echo AE4AMABMAG0AVgB5AGMAbgB0AGkAYgAzAEoAawBaAFgASQB0AGIARwBWAG0AZABD
>> "%~1" echo ADEAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB5AFoAVwBRAHAAZgBT
>> "%~1" echo ADUAMABiADIARgB6AGQAQwA1ADMAWQBYAEoAdQBlADIASgB2AGMAbQBSAGwAYwBp
>> "%~1" echo ADEAcwBaAFcAWgAwAEwAVwBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABX
>> "%~1" echo AEYAdABZAG0AVgB5AEsAWAAwAEsATABtADEAdgBaAEcARgBzAFQAVwBGAHoAYQAz
>> "%~1" echo AHQAdwBiADMATgBwAGQARwBsAHYAYgBqAHAAbQBhAFgAaABsAFoARAB0AHAAYgBu
>> "%~1" echo AE4AbABkAEQAbwB3AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAYwBt
>> "%~1" echo AGQAaQBZAFMAZwB5AEwARABZAHMATQBqAE0AcwBMAGoAVQAyAEsAVAB0ADYATABX
>> "%~1" echo AGwAdQBaAEcAVgA0AE8AagBjAHcATwAyAFIAcABjADMAQgBzAFkAWABrADYAYgBt
>> "%~1" echo ADkAdQBaAFQAdAB3AGIARwBGAGoAWgBTADEAcABkAEcAVgB0AGMAegBwAGoAWgBX
>> "%~1" echo ADUAMABaAFgASQA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE8ASABCADQAZgBT
>> "%~1" echo ADUAdABiADIAUgBoAGIARQAxAGgAYwAyAHMAdQBjADIAaAB2AGQAMwB0AGsAYQBY
>> "%~1" echo AE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFIAOQBDAGkANQB0AGIAMgBSAGgAYgBI
>> "%~1" echo AHQAMwBhAFcAUgAwAGEARABwAHQAYQBXADQAbwBOAEQAYwB3AGMASABnAHMATQBU
>> "%~1" echo AEEAdwBKAFMAawA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBY
>> "%~1" echo AEkAbwBMAFMAMQBqAFkAWABKAGsASwBUAHQAaQBiADMASgBrAFoAWABJADYATQBY
>> "%~1" echo AEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBt
>> "%~1" echo AFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATQBU
>> "%~1" echo AEoAdwBlAEQAdABpAGIAMwBnAHQAYwAyAGgAaABaAEcAOQAzAE8AagBBAGcATQBq
>> "%~1" echo AFIAdwBlAEMAQQAzAE0ASABCADQASQBIAEoAbgBZAG0ARQBvAE0AQwB3AHcATABE
>> "%~1" echo AEEAcwBMAGoATQAxAEsAVAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBJAHcAYwBI
>> "%~1" echo AGgAOQBDAGkANQB0AGIAMgBSAGgAYgBDAEIAbwBNADMAdAB0AFkAWABKAG4AYQBX
>> "%~1" echo ADQANgBNAEMAQQB3AEkARABoAHcAZQBEAHQAbQBiADIANQAwAEwAWABOAHAAZQBt
>> "%~1" echo AFUANgBNAFQAaAB3AGUASAAwAHUAYgBXADkAawBZAFcAdwBnAGMASAB0AHQAWQBY
>> "%~1" echo AEoAbgBhAFcANAA2AE0ARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABT
>> "%~1" echo ADEAdABkAFgAUgBsAFoAQwBrADcAYgBHAGwAdQBaAFMAMQBvAFoAVwBsAG4AYQBI
>> "%~1" echo AFEANgBNAFMANAAyAE4AVAB0ADMAYQBHAGwAMABaAFMAMQB6AGMARwBGAGoAWgBU
>> "%~1" echo AHAAdwBjAG0AVQB0AGQAMwBKAGgAYwBEAHQAMwBiADMASgBrAEwAVwBKAHkAWgBX
>> "%~1" echo AEYAcgBPAG0ASgB5AFoAVwBGAHIATABYAGQAdgBjAG0AUgA5AEMAaQA1AHQAYgAy
>> "%~1" echo AFIAaABiAEUARgBqAGQARwBsAHYAYgBuAE4ANwBaAEcAbAB6AGMARwB4AGgAZQBU
>> "%~1" echo AHAAbQBiAEcAVgA0AE8AMgBwADEAYwAzAFIAcABaAG4AawB0AFkAMgA5AHUAZABH
>> "%~1" echo AFYAdQBkAEQAcABtAGIARwBWADQATABXAFYAdQBaAEQAdABuAFkAWABBADYATQBU
>> "%~1" echo AEIAdwBlAEQAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8AagBFADQAYwBI
>> "%~1" echo AGgAOQBDAGkANQB0AGIAMgBSAGgAYgBFAEYAagBkAEcAbAB2AGIAbgBNAGcAWQBu
>> "%~1" echo AFYAMABkAEcAOQB1AGUAMgBoAGwAYQBXAGQAbwBkAEQAbwB6AE4AbgBCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8ASABCADQATwAy
>> "%~1" echo AEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABt
>> "%~1" echo AEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAz
>> "%~1" echo AFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIAWgAwAEsAVAB0AGoAYgAy
>> "%~1" echo AHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAMABaAFgAaAAwAEsAVAB0AHcAWQBX
>> "%~1" echo AFIAawBhAFcANQBuAE8AagBBAGcATQBUAFIAdwBlAEQAdABtAGIAMgA1ADAATABY
>> "%~1" echo AGQAbABhAFcAZABvAGQARABvADQATQBEAEEANwBZADMAVgB5AGMAMgA5AHkATwBu
>> "%~1" echo AEIAdgBhAFcANQAwAFoAWABKADkAQwBpADUAdABiADIAUgBoAGIARQBGAGoAZABH
>> "%~1" echo AGwAdgBiAG4ATQBnAEwAbQBSAGgAYgBtAGQAbABjAG4AdABpAFkAVwBOAHIAWgAz
>> "%~1" echo AEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcAdABMAFcARgB0AFkAbQBWAHkASwBU
>> "%~1" echo AHQAaQBiADMASgBrAFoAWABJAHQAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBD
>> "%~1" echo ADAAdABZAFcAMQBpAFoAWABJAHAATwAyAE4AdgBiAEcAOQB5AE8AaQBNAHgATQBU
>> "%~1" echo AEUANABNAGoAZAA5AEMAaQA1AGoAYgBXAFEAdQBhAFgATQB0AFkAbgBWAHoAZQBT
>> "%~1" echo AHcAdQBZAG4AUgB1AEwAbQBsAHoATABXAEoAMQBjADMAbAA3AGIAMwBCAGgAWQAy
>> "%~1" echo AGwAMABlAFQAbwB1AE4AagBnADcAWQAzAFYAeQBjADIAOQB5AE8AbgBkAGgAYQBY
>> "%~1" echo AFIAOQBMAG0ATgB0AFoARABwAGsAYQBYAE4AaABZAG0AeABsAFoAQwB3AHUAWQBu
>> "%~1" echo AFIAdQBPAG0AUgBwAGMAMgBGAGkAYgBHAFYAawBMAEMANQB5AFoAWABOAGwAZABF
>> "%~1" echo AEoAMABiAGoAcABrAGEAWABOAGgAWQBtAHgAbABaAEgAdAB3AGIAMgBsAHUAZABH
>> "%~1" echo AFYAeQBMAFcAVgAyAFoAVwA1ADAAYwB6AHAAdQBiADIANQBsAE8AMgA5AHcAWQBX
>> "%~1" echo AE4AcABkAEgAawA2AEwAagBaADkAQwBrAEIAdABaAFcAUgBwAFkAUwBoAHQAWQBY
>> "%~1" echo AGcAdABkADIAbABrAGQARwBnADYATQBUAEUANABNAEgAQgA0AEsAWABzAHUAYwBt
>> "%~1" echo ADkAMwBMAEMANQB5AGIAMwBjAHoAZQAyAGQAeQBhAFcAUQB0AGQARwBWAHQAYwBH
>> "%~1" echo AHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoAbwB4AFoAbgBKADkATABt
>> "%~1" echo AGwAdQBaAG0AOQBIAGMAbQBsAGsATABDADUAaABjAEcAdABIAGMAbQBsAGsAZQAy
>> "%~1" echo AGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABX
>> "%~1" echo ADEAdQBjAHoAbwB4AFoAbgBJAGcATQBXAFoAeQBmAFgAMABLAFEARwAxAGwAWgBH
>> "%~1" echo AGwAaABLAEcAMQBoAGUAQwAxADMAYQBXAFIAMABhAEQAbwA0AE0AagBCAHcAZQBD
>> "%~1" echo AGwANwBMAG0ARgB3AGMASAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBY
>> "%~1" echo AFIAbABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AGYAUwA1AHoAYQBX
>> "%~1" echo AFIAbABlADMAQgB2AGMAMgBsADAAYQBXADkAdQBPAG4ATgAwAFkAWABSAHAAWQB6
>> "%~1" echo AHQAMwBhAFcAUgAwAGEARABwAGgAZABYAFIAdgBPADIAaABsAGEAVwBkAG8AZABE
>> "%~1" echo AHAAaABkAFgAUgB2AGYAUwA1AHQAWQBXAGwAdQBlADIAZAB5AGEAVwBRAHQAWQAy
>> "%~1" echo ADkAcwBkAFcAMQB1AE8AagBGADkATABuAFIAdgBjAEgAdAB3AGIAMwBOAHAAZABH
>> "%~1" echo AGwAdgBiAGoAcAB6AGQARwBGADAAYQBXAE0ANwBhAEcAVgBwAFoAMgBoADAATwBt
>> "%~1" echo AEYAMQBkAEcAOAA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWgBt
>> "%~1" echo AHgAbABlAEMAMQB6AGQARwBGAHkAZABEAHQAbQBiAEcAVgA0AEwAVwBSAHAAYwBt
>> "%~1" echo AFYAagBkAEcAbAB2AGIAagBwAGoAYgAyAHgAMQBiAFcANAA3AFoAMgBGAHcATwBq
>> "%~1" echo AEUAdwBjAEgAZwA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE4AbgBCADQAZgBT
>> "%~1" echo ADUAMwBjAG0ARgB3AGUAMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABSAHcAZQBI
>> "%~1" echo ADAAdQBiAFcAVgAwAGMAbQBsAGoAUgAzAEoAcABaAEMAdwB1AFkAMgAxAGsAUgAz
>> "%~1" echo AEoAcABaAEMAdwB1AFoAbQA5AHkAYgBTAHcAdQBjAEcARgB5AFkAVwAxAEoAZABH
>> "%~1" echo AFYAdABMAEMANQBwAGIAbQBaAHYAUgAzAEoAcABaAEMAdwB1AFkAWABCAHIAUgAz
>> "%~1" echo AEoAcABaAEMAdwB1AFoAWABoAHcAYgAzAEoAMABRAG0AOQA0AGUAMgBkAHkAYQBX
>> "%~1" echo AFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6
>> "%~1" echo AG8AeABaAG4ASgA5AEwAbgBKAHAAWgAzAHQAbgBjAG0AbABrAEwAWABSAGwAYgBY
>> "%~1" echo AEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AE0AVwBaAHkAZgBT
>> "%~1" echo ADUAMABiADIARgB6AGQASABOADcAYwBtAGwAbgBhAEgAUQA2AE0AVABSAHcAZQBE
>> "%~1" echo AHQAaQBiADMAUgAwAGIAMgAwADYATQBUAFIAdwBlAEgAMQA5AEMAagB3AHYAYwAz
>> "%~1" echo AFIANQBiAEcAVQArAEMAagB3AHYAYQBHAFYAaABaAEQANABLAFAARwBKAHYAWgBI
>> "%~1" echo AGsAZwBZADIAeABoAGMAMwBNADkASQBtAFIAaABjAG0AcwBpAFAAZwBvADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAMABiADIARgB6AGQASABNAGkASQBH
>> "%~1" echo AGwAawBQAFMASgAwAGIAMgBGAHoAZABIAE0AaQBQAGoAdwB2AFoARwBsADIAUABn
>> "%~1" echo AG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB0AGIAMgBSAGgAYgBF
>> "%~1" echo ADEAaABjADIAcwBpAEkARwBsAGsAUABTAEoAagBiADIANQBtAGEAWABKAHQAVABX
>> "%~1" echo AEYAegBhAHkASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBX
>> "%~1" echo ADkAawBZAFcAdwBpAFAAagB4AG8ATQB5AEIAcABaAEQAMABpAFkAMgA5AHUAWgBt
>> "%~1" echo AGwAeQBiAFYAUgBwAGQARwB4AGwASQBqADcAbgBvAGEANwBvAHIAcQBUAG0AaQBh
>> "%~1" echo AGYAbwBvAFkAdwA4AEwAMgBnAHoAUABqAHgAdwBJAEcAbABrAFAAUwBKAGoAYgAy
>> "%~1" echo ADUAbQBhAFgASgB0AFQAWABOAG4ASQBqADcAbwB2ADUAbgBrAHUASwByAG0AawA0
>> "%~1" echo ADMAawB2AFoAegBrAHYASgByAGsAdgA2ADcAbQBsAEwAawBnAFUAWABWAGwAYwAz
>> "%~1" echo AFEAZwA1ADQAcQAyADUAbwBDAEIANAA0AEMAQwBQAEMAOQB3AFAAagB4AGsAYQBY
>> "%~1" echo AFkAZwBZADIAeABoAGMAMwBNADkASQBtADEAdgBaAEcARgBzAFEAVwBOADAAYQBX
>> "%~1" echo ADkAdQBjAHkASQArAFAARwBKADEAZABIAFIAdgBiAGkAQgBwAFoARAAwAGkAWQAy
>> "%~1" echo ADkAdQBaAG0AbAB5AGIAVQBOAGgAYgBtAE4AbABiAEMASQArADUAWQArAFcANQBy
>> "%~1" echo AGEASQBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcASgAxAGQASABSAHYAYgBp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAWgBHAEYAdQBaADIAVgB5AEkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBZADIAOQB1AFoAbQBsAHkAYgBVADkAcgBJAGoANwBuAG8AYQA3AG8AcgBx
>> "%~1" echo AFQAbQBpAGEAZgBvAG8AWQB3ADgATAAyAEoAMQBkAEgAUgB2AGIAagA0ADgATAAy
>> "%~1" echo AFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0AEsAUABI
>> "%~1" echo AE4AMgBaAHkAQgAzAGEAVwBSADAAYQBEADAAaQBNAEMASQBnAGEARwBWAHAAWgAy
>> "%~1" echo AGgAMABQAFMASQB3AEkAaQBCAHoAZABIAGwAcwBaAFQAMABpAGMARwA5AHoAYQBY
>> "%~1" echo AFIAcABiADIANAA2AFkAVwBKAHoAYgAyAHgAMQBkAEcAVQBpAFAAZwBvADgAYwAz
>> "%~1" echo AGwAdABZAG0AOQBzAEkARwBsAGsAUABTAEoAcABMAFgAWgB5AEkAaQBCADIAYQBX
>> "%~1" echo AFYAMwBRAG0AOQA0AFAAUwBJAHcASQBEAEEAZwBNAGoAUQBnAE0AagBRAGkAUABq
>> "%~1" echo AHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAAMgBJAEQAbABvAE0AVABKAGgATQB5
>> "%~1" echo AEEAegBJAEQAQQBnAE0AQwBBAHgASQBEAE0AZwBNADMAWQB6AFkAVABNAGcATQB5
>> "%~1" echo AEEAdwBJAEQAQQBnAE0AUwAwAHoASQBEAE4AbwBMAFQARQB1AE4AVwB3AHQATQBp
>> "%~1" echo ADQAMQBMAFQATgBvAEwAVABSAHMATABUAEkAdQBOAFMAQQB6AFMARABaAGgATQB5
>> "%~1" echo AEEAegBJAEQAQQBnAE0AQwBBAHgATABUAE0AdABNADMAWQB0AE0AMgBFAHoASQBE
>> "%~1" echo AE0AZwBNAEMAQQB3AEkARABFAGcATQB5ADAAegBlAGkASQB2AFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwADUASQBEAEUAeQBhAEMANAB3AE0AUwBJAHYAUABq
>> "%~1" echo AHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAAeABOAFMAQQB4AE0AbQBnAHUATQBE
>> "%~1" echo AEUAaQBMAHoANAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE0AVABBAGcATQBU
>> "%~1" echo AFYAbwBOAEMASQB2AFAAagB3AHYAYwAzAGwAdABZAG0AOQBzAFAAZwBvADgAYwAz
>> "%~1" echo AGwAdABZAG0AOQBzAEkARwBsAGsAUABTAEoAcABMAFcAaAB2AGIAVwBVAGkASQBI
>> "%~1" echo AFoAcABaAFgAZABDAGIAMwBnADkASQBqAEEAZwBNAEMAQQB5AE4AQwBBAHkATgBD
>> "%~1" echo AEkAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAVQBnAE0AVABKAHMATgB5
>> "%~1" echo ADAAMwBiAEQAYwBnAE4AeQBJAHYAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBr
>> "%~1" echo ADAAMgBJAEQARQB3AGQAagBsAG8ATQBUAEoAMgBMAFQAawBpAEwAegA0ADgATAAz
>> "%~1" echo AE4ANQBiAFcASgB2AGIARAA0AEsAUABIAE4ANQBiAFcASgB2AGIAQwBCAHAAWgBE
>> "%~1" echo ADAAaQBhAFMAMQBqAGIAMgA1AHoAYgAyAHgAbABJAGkAQgAyAGEAVwBWADMAUQBt
>> "%~1" echo ADkANABQAFMASQB3AEkARABBAGcATQBqAFEAZwBNAGoAUQBpAFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwADQASQBEAGwAcwBNAHkAQQB6AGIAQwAwAHoASQBE
>> "%~1" echo AE0AaQBMAHoANAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE0AVABNAGcATQBU
>> "%~1" echo AFYAbwBNAHkASQB2AFAAagB4AHcAWQBYAFIAbwBJAEcAUQA5AEkAawAwAHoASQBE
>> "%~1" echo AFIAbwBNAFQAaAAyAE0AVABaAEkATQAzAG8AaQBMAHoANAA4AEwAMwBOADUAYgBX
>> "%~1" echo AEoAdgBiAEQANABLAFAASABOADUAYgBXAEoAdgBiAEMAQgBwAFoARAAwAGkAYQBT
>> "%~1" echo ADEAaABjAEcAcwBpAEkASABaAHAAWgBYAGQAQwBiADMAZwA5AEkAagBBAGcATQBD
>> "%~1" echo AEEAeQBOAEMAQQB5AE4AQwBJACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABU
>> "%~1" echo AEUAeQBJAEQATgAyAE0AVABJAGkATAB6ADQAOABjAEcARgAwAGEAQwBCAGsAUABT
>> "%~1" echo AEoATgBPAEMAQQB4AE0AVwB3ADAASQBEAFIAcwBOAEMAMAAwAEkAaQA4ACsAUABI
>> "%~1" echo AEIAaABkAEcAZwBnAFoARAAwAGkAVABUAFEAZwBNAFQAZAAyAE0AbQBFAHkASQBE
>> "%~1" echo AEkAZwBNAEMAQQB3AEkARABBAGcATQBpAEEAeQBhAEQARQB5AFkAVABJAGcATQBp
>> "%~1" echo AEEAdwBJAEQAQQBnAE0AQwBBAHkATABUAEoAMgBMAFQASQBpAEwAegA0ADgATAAz
>> "%~1" echo AE4ANQBiAFcASgB2AGIARAA0AEsAUABIAE4ANQBiAFcASgB2AGIAQwBCAHAAWgBE
>> "%~1" echo ADAAaQBhAFMAMQBwAGIAbQBaAHYASQBpAEIAMgBhAFcAVgAzAFEAbQA5ADQAUABT
>> "%~1" echo AEkAdwBJAEQAQQBnAE0AagBRAGcATQBqAFEAaQBQAGoAeAB3AFkAWABSAG8ASQBH
>> "%~1" echo AFEAOQBJAGsAMAB4AE0AaQBBADUAYQBDADQAdwBNAFMASQB2AFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwAHgATQBTAEEAeABNAG0AZwB4AGQAagBSAG8ATQBT
>> "%~1" echo AEkAdgBQAGoAeAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAB4AE0AaQBBAHoAWQBU
>> "%~1" echo AGsAZwBPAFMAQQB3AEkARABFAGcATQBDAEEAdwBJAEQARQA0AFkAVABrAGcATwBT
>> "%~1" echo AEEAdwBJAEQAQQBnAE0AQwBBAHcATABUAEUANABlAGkASQB2AFAAagB3AHYAYwAz
>> "%~1" echo AGwAdABZAG0AOQBzAFAAZwBvADgAYwAzAGwAdABZAG0AOQBzAEkARwBsAGsAUABT
>> "%~1" echo AEoAcABMAFgATgBsAGQASABSAHAAYgBtAGQAegBJAGkAQgAyAGEAVwBWADMAUQBt
>> "%~1" echo ADkANABQAFMASQB3AEkARABBAGcATQBqAFEAZwBNAGoAUQBpAFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwAHgATQBDADQAegBNAGoAVQBnAE4AQwA0AHoATQBU
>> "%~1" echo AGQAaABNAGkAQQB5AEkARABBAGcATQBDAEEAeABJAEQATQB1AE0AegBVAGcATQBH
>> "%~1" echo AHcAdQBNAGkANAB6AE4ARABSAGgATQBpAEEAeQBJAEQAQQBnAE0AQwBBAHcASQBE
>> "%~1" echo AEkAdQBNAEQAQQA1AEwAagBrADIAYgBDADQAegBPAFQASQB0AEwAagBBADMATgBH
>> "%~1" echo AEUAeQBJAEQASQBnAE0AQwBBAHcASQBEAEUAZwBNAGkANAB6AE4AaQBBAHkATABq
>> "%~1" echo AE0AMgBiAEMAMAB1AE0ARABjADAATABqAE0ANQBNAG0ARQB5AEkARABJAGcATQBD
>> "%~1" echo AEEAdwBJAEQAQQBnAEwAagBrADIASQBEAEkAdQBNAEQAQQA1AGIAQwA0AHoATgBE
>> "%~1" echo AFEAdQBNAG0ARQB5AEkARABJAGcATQBDAEEAdwBJAEQARQBnAE0AQwBBAHoATABq
>> "%~1" echo AE0AMQBiAEMAMAB1AE0AegBRADAATABqAEoAaABNAGkAQQB5AEkARABBAGcATQBD
>> "%~1" echo AEEAdwBMAFMANAA1AE4AaQBBAHkATABqAEEAdwBPAFcAdwB1AE0ARABjADAATABq
>> "%~1" echo AE0ANQBNAG0ARQB5AEkARABJAGcATQBDAEEAdwBJAEQARQB0AE0AaQA0AHoATgBp
>> "%~1" echo AEEAeQBMAGoATQAyAGIAQwAwAHUATQB6AGsAeQBMAFMANAB3AE4AegBSAGgATQBp
>> "%~1" echo AEEAeQBJAEQAQQBnAE0AQwBBAHcATABUAEkAdQBNAEQAQQA1AEwAagBrADIAYgBD
>> "%~1" echo ADAAdQBNAGkANAB6AE4ARABSAGgATQBpAEEAeQBJAEQAQQBnAE0AQwBBAHgATABU
>> "%~1" echo AE0AdQBNAHoAVQBnAE0ARwB3AHQATABqAEkAdABMAGoATQAwAE4ARwBFAHkASQBE
>> "%~1" echo AEkAZwBNAEMAQQB3AEkARABBAHQATQBpADQAdwBNAEQAawB0AEwAagBrADIAYgBD
>> "%~1" echo ADAAdQBNAHoAawB5AEwAagBBADMATgBHAEUAeQBJAEQASQBnAE0AQwBBAHcASQBE
>> "%~1" echo AEUAdABNAGkANAB6AE4AaQAwAHkATABqAE0AMgBiAEMANAB3AE4AegBRAHQATABq
>> "%~1" echo AE0ANQBNAG0ARQB5AEkARABJAGcATQBDAEEAdwBJAEQAQQB0AEwAagBrADIATABU
>> "%~1" echo AEkAdQBNAEQAQQA1AGIAQwAwAHUATQB6AFEAMABMAFMANAB5AFkAVABJAGcATQBp
>> "%~1" echo AEEAdwBJAEQAQQBnAE0AUwBBAHcATABUAE0AdQBNAHoAVgBzAEwAagBNADAATgBD
>> "%~1" echo ADAAdQBNAG0ARQB5AEkARABJAGcATQBDAEEAdwBJAEQAQQBnAEwAagBrADIATABU
>> "%~1" echo AEkAdQBNAEQAQQA1AGIAQwAwAHUATQBEAGMAMABMAFMANAB6AE8AVABKAGgATQBp
>> "%~1" echo AEEAeQBJAEQAQQBnAE0AQwBBAHgASQBEAEkAdQBNAHoAWQB0AE0AaQA0AHoATgBt
>> "%~1" echo AHcAdQBNAHoAawB5AEwAagBBADMATgBHAEUAeQBJAEQASQBnAE0AQwBBAHcASQBE
>> "%~1" echo AEEAZwBNAGkANAB3AE0ARABrAHQATABqAGsAMgBlAGkASQB2AFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwADUASQBEAEUAeQBZAFQATQBnAE0AeQBBAHcASQBE
>> "%~1" echo AEUAZwBNAEMAQQAyAEkARABCAGgATQB5AEEAegBJAEQAQQBnAE0AQwBBAHcATABU
>> "%~1" echo AFkAZwBNAEMASQB2AFAAagB3AHYAYwAzAGwAdABZAG0AOQBzAFAAZwBvADgAYwAz
>> "%~1" echo AGwAdABZAG0AOQBzAEkARwBsAGsAUABTAEoAcABMAFcAeAB2AFoAeQBJAGcAZABt
>> "%~1" echo AGwAbABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQASQAwAEkARABJADAASQBq
>> "%~1" echo ADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBOAFMAQQAxAGEARABFADAAZABq
>> "%~1" echo AEUAMABTAEQAVgA2AEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABU
>> "%~1" echo AGsAZwBPAFcAZwAyAEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABU
>> "%~1" echo AGsAZwBNAFQATgBvAE4AaQBJAHYAUABqAHcAdgBjADMAbAB0AFkAbQA5AHMAUABn
>> "%~1" echo AG8AOABjADMAbAB0AFkAbQA5AHMASQBHAGwAawBQAFMASgBwAEwAWABWAHcAYgBH
>> "%~1" echo ADkAaABaAEMASQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQAMABpAE0AQwBBAHcASQBE
>> "%~1" echo AEkAMABJAEQASQAwAEkAagA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATQBU
>> "%~1" echo AEkAZwBNAFQAVgBXAE4AQwBJAHYAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBr
>> "%~1" echo ADAANABJAEQAaABzAE4AQwAwADAAYgBEAFEAZwBOAEMASQB2AFAAagB4AHcAWQBY
>> "%~1" echo AFIAbwBJAEcAUQA5AEkAawAwADAASQBEAEUAMQBkAGoATgBoAE0AaQBBAHkASQBE
>> "%~1" echo AEEAZwBNAEMAQQB3AEkARABJAGcATQBtAGcAeABNAG0ARQB5AEkARABJAGcATQBD
>> "%~1" echo AEEAdwBJAEQAQQBnAE0AaQAwAHkAZABpADAAegBJAGkAOAArAFAAQwA5AHoAZQBX
>> "%~1" echo ADEAaQBiADIAdwArAEMAagB3AHYAYwAzAFoAbgBQAGcAbwA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGgAYwBIAEEAaQBQAGcAbwA4AFkAWABOAHAAWgBH
>> "%~1" echo AFUAZwBZADIAeABoAGMAMwBNADkASQBuAE4AcABaAEcAVQBpAFAAZwBvADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBjAG0ARgB1AFoAQwBJACsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG4ASgBoAGIAbQBSAEoAWQAy
>> "%~1" echo ADkAdQBJAGoANAA4AGMAMwBaAG4ASQBIAGQAcABaAEgAUgBvAFAAUwBJAHkATQBp
>> "%~1" echo AEkAZwBhAEcAVgBwAFoAMgBoADAAUABTAEkAeQBNAGkASQArAFAASABWAHoAWgBT
>> "%~1" echo AEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBTADEAMgBjAGkASQB2AFAAagB3AHYAYwAz
>> "%~1" echo AFoAbgBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQArAFAARwBJACsAVQBY
>> "%~1" echo AFYAbABjADMAUQBnAFEAVQBSAEMAUABDADkAaQBQAGoAeAB6AGMARwBGAHUAUABs
>> "%~1" echo AE4AcABiAG0AZABzAFoAUwAxAEMAUQBWAFEAZwBWADIAVgBpAFYAVQBrADgATAAz
>> "%~1" echo AE4AdwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAQwBq
>> "%~1" echo AHgAdQBZAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ANQBoAGQAaQBJACsAQwBq
>> "%~1" echo AHgAaABJAEcAaAB5AFoAVwBZADkASQBpAE4AdgBkAG0AVgB5AGQAbQBsAGwAZAB5
>> "%~1" echo AEkAZwBZADIAeABoAGMAMwBNADkASQBtAEYAagBkAEcAbAAyAFoAUwBJACsAUABI
>> "%~1" echo AE4AMgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkAaQBOAHAATABX
>> "%~1" echo AGgAdgBiAFcAVQBpAEwAegA0ADgATAAzAE4AMgBaAHoANwBtAGcATAB2AG8AcAA0
>> "%~1" echo AGcAOABMADIARQArAEMAagB4AGgASQBHAGgAeQBaAFcAWQA5AEkAaQBOAGoAYgAy
>> "%~1" echo ADUAegBiADIAeABsAEkAagA0ADgAYwAzAFoAbgBQAGoAeAAxAGMAMgBVAGcAYQBI
>> "%~1" echo AEoAbABaAGoAMABpAEkAMgBrAHQAWQAyADkAdQBjADIAOQBzAFoAUwBJAHYAUABq
>> "%~1" echo AHcAdgBjADMAWgBuAFAAdQBXAC8AcQArAGEATgB0ACsAYQBPAHAAKwBXAEkAdAB1
>> "%~1" echo AFcAUABzAEQAdwB2AFkAVAA0AEsAUABHAEUAZwBhAEgASgBsAFoAagAwAGkASQAy
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB3AGkAUABqAHgAegBkAG0AYwArAFAASABWAHoAWgBT
>> "%~1" echo AEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBTADEAaABjAEcAcwBpAEwAegA0ADgATAAz
>> "%~1" echo AE4AMgBaAHoANwBsAHUAcABUAG4AbABLAGoAbAByAG8AbgBvAG8ANABVADgATAAy
>> "%~1" echo AEUAKwBDAGoAeABoAEkARwBoAHkAWgBXAFkAOQBJAGkATgBrAFoAWABaAHAAWQAy
>> "%~1" echo AFUAaQBQAGoAeAB6AGQAbQBjACsAUABIAFYAegBaAFMAQgBvAGMAbQBWAG0AUABT
>> "%~1" echo AEkAagBhAFMAMQBwAGIAbQBaAHYASQBpADgAKwBQAEMAOQB6AGQAbQBjACsANgBL
>> "%~1" echo ADYAKwA1AGEAUwBIADUATAArAGgANQBvAEcAdgBQAEMAOQBoAFAAZwBvADgAWQBT
>> "%~1" echo AEIAbwBjAG0AVgBtAFAAUwBJAGoAYwAyAFYAMABkAEcAbAB1AFoAMwBNAGkAUABq
>> "%~1" echo AHgAegBkAG0AYwArAFAASABWAHoAWgBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBT
>> "%~1" echo ADEAegBaAFgAUgAwAGEAVwA1AG4AYwB5AEkAdgBQAGoAdwB2AGMAMwBaAG4AUAB1
>> "%~1" echo AG0AcgBtAE8AZQA2AHAAeQBCAHoAWgBYAFIAMABhAFcANQBuAGMAegB3AHYAWQBU
>> "%~1" echo ADQASwBQAEcARQBnAGEASABKAGwAWgBqADAAaQBJADIAeAB2AFoAMwBNAGkAUABq
>> "%~1" echo AHgAegBkAG0AYwArAFAASABWAHoAWgBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBT
>> "%~1" echo ADEAcwBiADIAYwBpAEwAegA0ADgATAAzAE4AMgBaAHoANwBtAGwANgBYAGwAdgA1
>> "%~1" echo AGMAOABMADIARQArAEMAagB3AHYAYgBtAEYAMgBQAGcAbwA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAHUAWQBYAFoARwBiADIAOQAwAEkAagA3AGwAagA2
>> "%~1" echo AHIAbgBtADUASABsAGsASwB3AGcATQBUAEkAMwBMAGoAQQB1AE0AQwA0AHgAUABH
>> "%~1" echo AEoAeQBQAHUAVwBGAHMAKwBtAFgAcgBlAGUAcQBsACsAVwBQAG8AKwBXAE4AcwAr
>> "%~1" echo AFcAQgBuAE8AYQB0AG8AdQBhAGMAagBlAFcASwBvAFQAdwB2AFoARwBsADIAUABn
>> "%~1" echo AG8AOABMADIARgB6AGEAVwBSAGwAUABnAG8AOABiAFcARgBwAGIAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAGIAVwBGAHAAYgBpAEkAKwBDAGoAeABvAFoAVwBGAGsAWgBY
>> "%~1" echo AEkAZwBZADIAeABoAGMAMwBNADkASQBuAFIAdgBjAEMASQArAEMAagB4AGsAYQBY
>> "%~1" echo AFkAZwBZADIAeABoAGMAMwBNADkASQBuAFIAcABkAEcAeABsAEkAagA0ADgAYQBE
>> "%~1" echo AEUAZwBhAFcAUQA5AEkAbgBCAGgAWgAyAFYAVQBhAFgAUgBzAFoAUwBJACsANQBv
>> "%~1" echo AEMANwA2AEsAZQBJAFAAQwA5AG8ATQBUADQAOABjAEMAQgBwAFoARAAwAGkAYwBH
>> "%~1" echo AEYAbgBaAFYATgAxAFkAaQBJACsANQA0AHEAMgA1AG8AQwBCADUAbwB5AEgANQBx
>> "%~1" echo AEMASAA1AFoASwBNADYASwA2ACsANQBhAFMASAA1AHEAYQBDADYASwBlAEkAUABD
>> "%~1" echo ADkAdwBQAGoAdwB2AFoARwBsADIAUABnAG8AOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgAwAGIAMgA5AHMAWQBtAEYAeQBJAGoANABLAFAASABOAHcAWQBX
>> "%~1" echo ADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AbwBhAFgAQQBpAEkARwBsAGsAUABT
>> "%~1" echo AEoAegBkAEcARgAwAGQAWABOAEQAYQBHAGwAdwBJAGoANAA4AGEAUwBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAMgBoAHAAYwBFAFIAdgBkAEMASQArAFAAQwA5AHAAUABq
>> "%~1" echo AHgAegBjAEcARgB1AFAAdQBhAGMAcQB1AGkALwBuAHUAYQBPAHAAVAB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AEwAMwBOAHcAWQBXADQAKwBDAGoAeAB6AGMARwBGAHUASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGoAYQBHAGwAdwBJAGoANQBCAFIARQBJAGcAUABH
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbQBGAGsAWQBsAE4AbwBiADMASgAwAEkAagA1AGgAWgBH
>> "%~1" echo AEkAdQBaAFgAaABsAFAAQwA5AGkAUABqAHcAdgBjADMAQgBoAGIAagA0AEsAUABI
>> "%~1" echo AE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBvAGEAWABBAGkAUABs
>> "%~1" echo AGQAcABMAFUAWgBwAEkARAB4AGkASQBHAGwAawBQAFMASgAzAGEAVwBaAHAAUQAy
>> "%~1" echo AGgAcABjAEMASQArAEwAVAB3AHYAWQBqADQAOABMADMATgB3AFkAVwA0ACsAQwBq
>> "%~1" echo AHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBKADAAYgBp
>> "%~1" echo AEIAbgBhAEcAOQB6AGQAQwBJAGcAYQBXAFEAOQBJAG4AUgBvAFoAVwAxAGwAUQBu
>> "%~1" echo AFIAdQBJAGoANwBtAHQAWQBYAG8AaQBiAEkAOABMADIASgAxAGQASABSAHYAYgBq
>> "%~1" echo ADQASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQBu
>> "%~1" echo AFIAdQBJAEgAQgB5AGEAVwAxAGgAYwBuAGsAaQBJAEcAbABrAFAAUwBKAHkAWgBX
>> "%~1" echo AFoAeQBaAFgATgBvAFEAbgBSAHUASQBqADcAbABpAEwAZgBtAGwAcgBBADgATAAy
>> "%~1" echo AEoAMQBkAEgAUgB2AGIAagA0AEsAUABDADkAawBhAFgAWQArAEMAagB3AHYAYQBH
>> "%~1" echo AFYAaABaAEcAVgB5AFAAZwBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAMwBjAG0ARgB3AEkAagA0AEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBiAG0AOQAwAGEAVwBOAGwASQBqADcAawB2ADUAMwBtAHQATAB2AGoAZwBJ
>> "%~1" echo AEUAeQBOAEMARABsAHMASQAvAG0AbAA3AGIAawB1AHEANwBsAHMAWQAvAGwAawBv
>> "%~1" echo AHoAbQBsADYARABuAHUAcgA4AGcAUQBVAFIAQwBJAE8AVwBQAHEAdQBXADcAdQB1
>> "%~1" echo AGkAdQByAHUAZQBmAHIAZQBhAFgAdAB1AG0AWAB0AE8AYQAxAGkAKwBpAHYAbABl
>> "%~1" echo ACsAOABtACsAZQA3AGsAKwBhAGQAbgArAFcAUQBqAHUAYQBKAHAAKwBpAGgAagBP
>> "%~1" echo AEsAQQBuAE8AVwB1AGkAZQBXAEYAcQBPAGUARwBoAE8AVwB4AGoAKwBLAEEAbgBl
>> "%~1" echo AGEASQBsAHUASwBBAG4ATwBTAC8AbgBlAFcAdQBpAE8AbQA3AG0ATwBpAHUAcABP
>> "%~1" echo AFcAQQB2AE8ASwBBAG4AZQBPAEEAZwB1AFcAdQBpAGUAaQBqAGgAUwBCAEIAVQBF
>> "%~1" echo AHMAZwA1AEwAeQBhADUATAArAHUANQBwAFMANQA2AEsANgArADUAYQBTAEgANwA3
>> "%~1" echo AHkATQA2AEsAKwAzADUANgBHAHUANgBLADYAawA1AHAAMgBsADUAcgBxAFEANQBZ
>> "%~1" echo ACsAdgA1AEwAKwBoADQANABDAEMAUABDADkAawBhAFgAWQArAEMAZwBvADgAYwAy
>> "%~1" echo AFYAagBkAEcAbAB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMARwBGAG4AWgBT
>> "%~1" echo AEIAaABZADMAUgBwAGQAbQBVAGkASQBHAGwAawBQAFMASgB2AGQAbQBWAHkAZABt
>> "%~1" echo AGwAbABkAHkASQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBu
>> "%~1" echo AEoAdgBkAHkASQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAbwByAHIANwBsAHAASQBjADgATAAy
>> "%~1" echo AGcAeQBQAGoAeAB6AGMARwBGAHUASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAWQBX
>> "%~1" echo AGMAaQBJAEcAbABrAFAAUwBKAGsAWgBYAFoAcABZADIAVgBVAFkAVwBjAGkAUABs
>> "%~1" echo AEYAMQBaAFgATgAwAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoARwBsADIAUABq
>> "%~1" echo AHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABn
>> "%~1" echo AG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsAYwAy
>> "%~1" echo AFYAMABRAG0AOQA0AEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAawBaAFgAWgBwAFkAMgBWAEoAWQAyADkAdQBJAGoANAA4AGMAMwBaAG4AUABq
>> "%~1" echo AHgAMQBjADIAVQBnAGEASABKAGwAWgBqADAAaQBJADIAawB0AGQAbgBJAGkATAB6
>> "%~1" echo ADQAOABMADMATgAyAFoAegA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIAUABq
>> "%~1" echo AHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AUgBsAGQAbQBsAGoAWgBV
>> "%~1" echo ADUAaABiAFcAVQBpAEkARwBsAGsAUABTAEoAbwBaAFgASgB2AFQAVwA5AGsAWgBX
>> "%~1" echo AHcAaQBQAGwARgAxAFoAWABOADAAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYQBHAGwAdQBkAEMASQBnAGEAVwBRADkASQBu
>> "%~1" echo AE4AMABZAFgAUgBsAFMARwBsAHUAZABDAEkAKwA1ADYAMgBKADUAYgA2AEYANgBL
>> "%~1" echo ACsANwA1AFkAKwBXADYASwA2ACsANQBhAFMASAA1ADQAcQAyADUAbwBDAEIANAA0
>> "%~1" echo AEMAQwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBjADMAUgBoAGQARwBVAGkASQBHAGwAawBQAFMASgB6AGQARwBGADAAWgBV
>> "%~1" echo AEoAcABaAHkASQArAGIAbQA5AHUAWgBUAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGoAdwB2AFoARwBsADIAUABnAG8AOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgB5AGEAVwBjAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0ATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBDAGIAMwBnAGcAYgBH
>> "%~1" echo AFYAbQBkAEMASQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBu
>> "%~1" echo AEoAdgBiAEcAVQBpAFAAdQBXADMAcAB1AGEASgBpACsAYQBmAGgARAB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AFkAaQBCAHAAWgBEADAAaQBiAEcAVgBtAGQARQBOAHYAYgBu
>> "%~1" echo AFIAeQBiADIAeABzAFoAWABKAE0AYQBYAFIAbABJAGoANAB0AEwAVAB3AHYAWQBq
>> "%~1" echo ADQAOABjADMAQgBoAGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMAMwBSAGgAZABH
>> "%~1" echo AFYAVQBaAFgAaAAwAEkAaQBCAHAAWgBEADAAaQBiAEcAVgBtAGQARQBOAHYAYgBu
>> "%~1" echo AFIAeQBiADIAeABzAFoAWABKAFQAZABHAEYAMABaAFMASQArAEwAVAB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgB0AFoAWABSAGgAUwBYAFIAbABiAFMASQArAFAASABOAHcAWQBX
>> "%~1" echo ADQAKwBWADIAawB0AFIAbQBrAGcAUwBWAEEAOABMADMATgB3AFkAVwA0ACsAUABH
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbgBkAHAAWgBtAGwASgBjAEUAeABwAGQARwBVAGkAUABp
>> "%~1" echo ADAAOABMADIASQArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAMgA5AHUAZABIAEoAdgBiAEcAeABsAGMAawBKAHYAZQBD
>> "%~1" echo AEIAeQBhAFcAZABvAGQAQwBJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG4ASgB2AGIARwBVAGkAUAB1AFcAUABzACsAYQBKAGkAKwBhAGYAaABE
>> "%~1" echo AHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAGMAbQBsAG4AYQBI
>> "%~1" echo AFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoAUwBJACsATABT
>> "%~1" echo ADAAOABMADIASQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBu
>> "%~1" echo AE4AMABZAFgAUgBsAFYARwBWADQAZABDAEkAZwBhAFcAUQA5AEkAbgBKAHAAWgAy
>> "%~1" echo AGgAMABRADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGwATgAwAFkAWABSAGwASQBq
>> "%~1" echo ADQAdABQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABH
>> "%~1" echo AGcAeQBQAHUAZQBLAHQAdQBhAEEAZwBlAGEATQBoACsAYQBnAGgAegB3AHYAYQBE
>> "%~1" echo AEkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbQBOAHMAYgAyAE4AcgBWAEcAVgA0AGQAQwBJACsATABU
>> "%~1" echo AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoANABLAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYAMABjAG0AbABqAFIAMwBKAHAAWgBD
>> "%~1" echo AEkAKwBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABI
>> "%~1" echo AEoAcABZAHkASQBnAGEAVwBRADkASQBtAEoAaABkAEgAUgBsAGMAbgBsAEgAWQBY
>> "%~1" echo AFYAbgBaAFMASQArAFAASABOADIAWgB5AEIAagBiAEcARgB6AGMAegAwAGkAYwBt
>> "%~1" echo AGwAdQBaAHkASQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQAMABpAE0AQwBBAHcASQBE
>> "%~1" echo AEUAdwBNAEMAQQB4AE0ARABBAGkAUABqAHgAagBhAFgASgBqAGIARwBVAGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbgBSAHkAWQBXAE4AcgBJAGkAQgBqAGUARAAwAGkATgBU
>> "%~1" echo AEEAaQBJAEcATgA1AFAAUwBJADEATQBDAEkAZwBjAGoAMABpAE4ARABBAGkASQBI
>> "%~1" echo AEIAaABkAEcAaABNAFoAVwA1AG4AZABHAGcAOQBJAGoARQB3AE0AQwBJAHYAUABq
>> "%~1" echo AHgAagBhAFgASgBqAGIARwBVAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABH
>> "%~1" echo AFYAeQBJAGkAQgBqAGUARAAwAGkATgBUAEEAaQBJAEcATgA1AFAAUwBJADEATQBD
>> "%~1" echo AEkAZwBjAGoAMABpAE4ARABBAGkASQBIAEIAaABkAEcAaABNAFoAVwA1AG4AZABH
>> "%~1" echo AGcAOQBJAGoARQB3AE0AQwBJAGcAYwAzAFIAeQBiADIAdABsAEwAVwBSAGgAYwAy
>> "%~1" echo AGgAaABjAG4ASgBoAGUAVAAwAGkATQBDAEEAeABNAEQAQQBpAEwAegA0ADgATAAz
>> "%~1" echo AE4AMgBaAHoANAA4AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0AMQBsAGQASABKAHAAWQAxAFoAaABiAEgAVgBsAEkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBZAG0ARgAwAGQARwBWAHkAZQBWAFIAbABlAEgAUQBpAFAAaQAwAHQASgBU
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo ADEAbABkAEgASgBwAFkAMAB4AGgAWQBtAFYAcwBJAGkAQgBwAFoARAAwAGkAWQBt
>> "%~1" echo AEYAMABkAEcAVgB5AGUAVgBOADEAWQBpAEkAKwA1ADUAUwAxADYAWQBlAFAAUABD
>> "%~1" echo ADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAQwBq
>> "%~1" echo AHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQASABKAHAAWQB5
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbgBSAGwAYgBYAEIASABZAFgAVgBuAFoAUwBJACsAUABI
>> "%~1" echo AE4AMgBaAHkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAG0AbAB1AFoAeQBJAGcAZABt
>> "%~1" echo AGwAbABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQARQB3AE0AQwBBAHgATQBE
>> "%~1" echo AEEAaQBQAGoAeABqAGEAWABKAGoAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBu
>> "%~1" echo AFIAeQBZAFcATgByAEkAaQBCAGoAZQBEADAAaQBOAFQAQQBpAEkARwBOADUAUABT
>> "%~1" echo AEkAMQBNAEMASQBnAGMAagAwAGkATgBEAEEAaQBJAEgAQgBoAGQARwBoAE0AWgBX
>> "%~1" echo ADUAbgBkAEcAZwA5AEkAagBFAHcATQBDAEkAdgBQAGoAeABqAGEAWABKAGoAYgBH
>> "%~1" echo AFUAZwBZADIAeABoAGMAMwBNADkASQBtADEAbABkAEcAVgB5AEkAaQBCAGoAZQBE
>> "%~1" echo ADAAaQBOAFQAQQBpAEkARwBOADUAUABTAEkAMQBNAEMASQBnAGMAagAwAGkATgBE
>> "%~1" echo AEEAaQBJAEgAQgBoAGQARwBoAE0AWgBXADUAbgBkAEcAZwA5AEkAagBFAHcATQBD
>> "%~1" echo AEkAZwBjADMAUgB5AGIAMgB0AGwATABXAFIAaABjADIAaABoAGMAbgBKAGgAZQBU
>> "%~1" echo ADAAaQBNAEMAQQB4AE0ARABBAGkATAB6ADQAOABMADMATgAyAFoAegA0ADgAWgBH
>> "%~1" echo AGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABI
>> "%~1" echo AEoAcABZADEAWgBoAGIASABWAGwASQBpAEIAcABaAEQAMABpAGQARwBWAHQAYwBG
>> "%~1" echo AFIAbABlAEgAUQBpAFAAaQAwAHQAdwByAEIARABQAEMAOQBrAGEAWABZACsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMAbQBsAGoAVABH
>> "%~1" echo AEYAaQBaAFcAdwBpAEkARwBsAGsAUABTAEoAMABaAFcAMQB3AFUAMwBWAGkASQBq
>> "%~1" echo ADcAbQB1AEsAbgBsAHUAcQBZADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABq
>> "%~1" echo ADQAOABMADIAUgBwAGQAagA0AEsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBiAFcAVgAwAGMAbQBsAGoASQBpAEIAcABaAEQAMABpAGMAMgB4AGwAWgBY
>> "%~1" echo AEIASABZAFgAVgBuAFoAUwBJACsAUABIAE4AMgBaAHkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBjAG0AbAB1AFoAeQBJAGcAZABtAGwAbABkADAASgB2AGUARAAwAGkATQBD
>> "%~1" echo AEEAdwBJAEQARQB3AE0AQwBBAHgATQBEAEEAaQBQAGoAeABqAGEAWABKAGoAYgBH
>> "%~1" echo AFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIAeQBZAFcATgByAEkAaQBCAGoAZQBE
>> "%~1" echo ADAAaQBOAFQAQQBpAEkARwBOADUAUABTAEkAMQBNAEMASQBnAGMAagAwAGkATgBE
>> "%~1" echo AEEAaQBJAEgAQgBoAGQARwBoAE0AWgBXADUAbgBkAEcAZwA5AEkAagBFAHcATQBD
>> "%~1" echo AEkAdgBQAGoAeABqAGEAWABKAGoAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo ADEAbABkAEcAVgB5AEkAaQBCAGoAZQBEADAAaQBOAFQAQQBpAEkARwBOADUAUABT
>> "%~1" echo AEkAMQBNAEMASQBnAGMAagAwAGkATgBEAEEAaQBJAEgAQgBoAGQARwBoAE0AWgBX
>> "%~1" echo ADUAbgBkAEcAZwA5AEkAagBFAHcATQBDAEkAZwBjADMAUgB5AGIAMgB0AGwATABX
>> "%~1" echo AFIAaABjADIAaABoAGMAbgBKAGgAZQBUADAAaQBNAEMAQQB4AE0ARABBAGkATAB6
>> "%~1" echo ADQAOABMADMATgAyAFoAegA0ADgAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbQAxAGwAZABIAEoAcABZADEAWgBoAGIASABWAGwASQBp
>> "%~1" echo AEIAcABaAEQAMABpAGMAMgB4AGwAWgBYAEIAVQBaAFgAaAAwAEkAagA0AHQAUABD
>> "%~1" echo ADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBX
>> "%~1" echo AFYAMABjAG0AbABqAFQARwBGAGkAWgBXAHcAaQBJAEcAbABrAFAAUwBKAHoAYgBH
>> "%~1" echo AFYAbABjAEYATgAxAFkAaQBJACsANQBaAFMAawA2AFkAYQBTAFAAQwA5AGsAYQBY
>> "%~1" echo AFkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAEMAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0AEsAUABD
>> "%~1" echo ADkAawBhAFgAWQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAawB1AEkARABwAGwASwA3AGwAcgA3
>> "%~1" echo AHoAbABoADcAbwA4AEwAMgBnAHkAUABqAHgAegBjAEcARgB1AEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AFcAUABxAHUAaQB2AHUAKwBtAEgAaAAr
>> "%~1" echo AG0AYgBoAGoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBaAFgAaAB3AGIAMwBKADAAUQBt
>> "%~1" echo ADkANABJAGoANAA4AFoARwBsADIAUABqAHgAaQBQAHUAVwB2AHYATwBXAEgAdQB1
>> "%~1" echo AGkAdQB2AHUAVwBrAGgAKwBXAEYAcQBPAG0ARABxAE8AUwAvAG8AZQBhAEIAcgB6
>> "%~1" echo AHcAdgBZAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AYQBX
>> "%~1" echo ADUAMABJAGkAQgBwAFoARAAwAGkAWgBYAGgAdwBiADMASgAwAFUAMwBSAGgAZABI
>> "%~1" echo AFYAegBJAGoANwBuAGwASgAvAG0AaQBKAEQAbgBwADQASABtAG4ASQBuAGwAcgBv
>> "%~1" echo AHoAbQBsAGIAVABuAGkAWQBqAGsAdQBJADcAbABpAEkAYgBrAHUAcQB2AGwAcgBv
>> "%~1" echo AG4AbABoAGEAagBuAGkAWQBqAGsAdQBLAFQAawB1ADcAMABnAFMARgBSAE4AVABP
>> "%~1" echo AE8AQQBnAHUAVwBJAGgAdQBTADYAcQArAFcASgBqAGUAaQB2AHQAKwBTADYAdQB1
>> "%~1" echo AFcAMwBwAGUAVwBrAGoAZQBhAGcAdQBPAE8AQQBnAGoAdwB2AFoARwBsADIAUABq
>> "%~1" echo AHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AVgA0AGMARwA5AHkAZABF
>> "%~1" echo AHgAcABiAG0AdAB6AEkAaQBCAHAAWgBEADAAaQBaAFgAaAB3AGIAMwBKADAAVABH
>> "%~1" echo AGwAdQBhADMATQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABq
>> "%~1" echo AHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBKADAAYgBp
>> "%~1" echo AEIAdwBjAG0AbAB0AFkAWABKADUASQBpAEIAcABaAEQAMABpAFoAWABoAHcAYgAz
>> "%~1" echo AEoAMABRAG4AUgB1AEkAagA3AGwAdgBJAEQAbABwADQAdgBsAHIANwB6AGwAaAA3
>> "%~1" echo AG8AOABMADIASgAxAGQASABSAHYAYgBqADQAOABMADIAUgBwAGQAagA0AEsAUABD
>> "%~1" echo ADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBDAGoAdwB2AGMAMgBWAGoAZABH
>> "%~1" echo AGwAdgBiAGoANABLAEMAagB4AHoAWgBXAE4AMABhAFcAOQB1AEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgB3AFkAVwBkAGwASQBpAEIAcABaAEQAMABpAFkAMgA5AHUAYwAy
>> "%~1" echo ADkAcwBaAFMASQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAbAB1AEwAagBuAGwASwBqAG0AawA0
>> "%~1" echo ADMAawB2AFoAdwA4AEwAMgBnAHkAUABqAHgAegBjAEcARgB1AEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AGUAQwB1AGUAVwBIAHUAKwBhAEoAcAAr
>> "%~1" echo AGkAaABqAEQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIAMQBrAFIAMwBKAHAAWgBD
>> "%~1" echo AEkAKwBDAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AdABaAEMAQgBuAGMAbQBWAGwAYgBpAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAz
>> "%~1" echo AFIAcABiADIANAA5AEkAbQB0AGwAZQBWADkAMwBZAFcAdABsAGQAWABBAGkAUABq
>> "%~1" echo AHgAaQBQAHUAVwBVAHAATwBtAEcAawB1AFcAeABqACsAVwA1AGwAVAB3AHYAWQBq
>> "%~1" echo ADQAOABjADMAQgBoAGIAagA1AEwAUgBWAGwARABUADAAUgBGAFgAMQBkAEIAUwAw
>> "%~1" echo AFYAVgBVAEQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBq
>> "%~1" echo ADQASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAy
>> "%~1" echo ADEAawBJAEcASgBzAGQAVwBVAGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBQAFMASgB6AFkAVwBaAGwAWAAzAE4AcwBaAFcAVgB3AEkAagA0ADgAWQBq
>> "%~1" echo ADcAbAByAG8AbgBsAGgAYQBqAG4AaABvAFQAbABzAFkAOAA4AEwAMgBJACsAUABI
>> "%~1" echo AE4AdwBZAFcANAArADUAbwBHAGkANQBhAFMATgA1AEwAKwBkADUAYQA2AEkANQBZ
>> "%~1" echo AEMAOAA1AGIAbQAyAEkARgBOAE0AUgBVAFYAUQBQAEMAOQB6AGMARwBGAHUAUABq
>> "%~1" echo AHcAdgBZAG4AVgAwAGQARwA5AHUAUABnAG8AOABZAG4AVgAwAGQARwA5AHUASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGoAYgBXAFEAZwBZAG0AeAAxAFoAUwBJAGcAWgBH
>> "%~1" echo AEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4ASgBsAGMAMwBSAHYAYwBt
>> "%~1" echo AFYAZgBjADIAeABsAFoAWABBAGkAUABqAHgAaQBQAHUAYQBCAG8AdQBXAGsAagBl
>> "%~1" echo AFMAOABrAGUAZQBjAG8ARAB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AG0AcgBh
>> "%~1" echo AFAAbAB1AEwAagBrAHYASgBIAG4AbgBLAEEAZwBLAHkAQQAxAEkATwBXAEkAaAB1
>> "%~1" echo AG0AUwBuACsAaQAyAGgAZQBhAFgAdABqAHcAdgBjADMAQgBoAGIAagA0ADgATAAy
>> "%~1" echo AEoAMQBkAEgAUgB2AGIAagA0AEsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAMgAxAGsASQBHAEoAcwBkAFcAVQBpAEkARwBSAGgAZABH
>> "%~1" echo AEUAdABZAFcATgAwAGEAVwA5AHUAUABTAEoAagBiADIANQB6AFoAWABKADIAWQBY
>> "%~1" echo AFIAcABkAG0AVQBpAFAAagB4AGkAUAB1AFMALwBuAGUAVwB1AGkATwBtADcAbQBP
>> "%~1" echo AGkAdQBwAE8AVwBBAHYARAB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AG0AZwBh
>> "%~1" echo AEwAbABwAEkAMwBsAHIAbwBuAGwAaABhAGoAcAB1ADUAagBvAHIAcQBUAGwAagA0
>> "%~1" echo AEwAbQBsAGIAQQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAy
>> "%~1" echo ADQAKwBDAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AdABaAEMAQgBoAGIAVwBKAGwAYwBpAEIAawBZAFcANQBuAFoAWABKAEIAWQAz
>> "%~1" echo AFIAcABiADIANABpAEkARwBSAGgAZABHAEUAdABZAFcATgAwAGEAVwA5AHUAUABT
>> "%~1" echo AEoAawBaAFcASgAxAFoAMQA5AHQAYgAyAFIAbABJAGoANAA4AFkAagA3AG8AcwBJ
>> "%~1" echo AFAAbwByADUAWABsAHQANgBYAGsAdgBaAHoAbQBxAEsASABsAHYASQA4ADgATAAy
>> "%~1" echo AEkAKwBQAEgATgB3AFkAVwA0ACsANQBMACsAZAA1AHIAUwA3AEkAQwBzAGcATQBq
>> "%~1" echo AFIAbwBJAE8AUwA2AHIAdQBXAHgAagArACsAOABpAE8AZQBmAHIAZQBhAFgAdAB1
>> "%~1" echo ACsAOABpAFQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBq
>> "%~1" echo ADQASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAy
>> "%~1" echo ADEAawBJAEcARgB0AFkAbQBWAHkASQBHAFIAaABiAG0AZABsAGMAawBGAGoAZABH
>> "%~1" echo AGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBt
>> "%~1" echo AHQAbABaAFgAQgBmAFkAWABkAGgAYQAyAFUAaQBQAGoAeABpAFAAdQBlAGYAcgBl
>> "%~1" echo AGEAWAB0AHUAUwAvAG4AZQBhADAAdQB6AHcAdgBZAGoANAA4AGMAMwBCAGgAYgBq
>> "%~1" echo ADcAbABoAHAAbgBsAGgAYQBYAGsAdgA1ADMAbQBqAEkASABsAGwASwBUAHAAaABw
>> "%~1" echo AEwAbABqADQATABtAGwAYgBBADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABY
>> "%~1" echo AFIAMABiADIANAArAEMAagB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0ATgB0AFoAQwBCAGgAYgBXAEoAbABjAGkAQgBrAFkAVwA1AG4AWgBY
>> "%~1" echo AEoAQgBZADMAUgBwAGIAMgA0AGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBQAFMASgAzAGEAWABKAGwAYgBHAFYAegBjAHkASQArAFAARwBJACsANQBi
>> "%~1" echo AHkAQQA1AFoAQwB2ADUAcABlAGcANQA3AHEALwBJAEUARgBFAFEAagB3AHYAWQBq
>> "%~1" echo ADQAOABjADMAQgBoAGIAagA1ADAAWQAzAEIAcABjAEMAQQAxAE4AVABVADEAUABD
>> "%~1" echo ADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAZwBvADgAWQBu
>> "%~1" echo AFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGcAWQBX
>> "%~1" echo ADEAaQBaAFgASQBnAFoARwBGAHUAWgAyAFYAeQBRAFcATgAwAGEAVwA5AHUASQBp
>> "%~1" echo AEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGQAMgBsAHkAWgBX
>> "%~1" echo AHgAbABjADMATgBmAGIAMgBaAG0ASQBqADQAOABZAGoANwBsAGgAYgBQAHAAbAA2
>> "%~1" echo ADMAbQBsADYARABuAHUAcgA4AGcAUQBVAFIAQwBQAEMAOQBpAFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBQAHUAVwBJAGgAKwBXAGIAbgBpAEIAVgBVADAASQA4AEwAMwBOAHcAWQBX
>> "%~1" echo ADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBDAGoAeABpAGQAWABSADAAYgAy
>> "%~1" echo ADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBpAGIASABWAGwASQBp
>> "%~1" echo AEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGEAMgBWADUAWAAz
>> "%~1" echo AE4AcwBaAFcAVgB3AEkAagA0ADgAWQBqADcAbABqADUASABwAGcASQBFAGcAVQAw
>> "%~1" echo AHgARgBSAFYAQQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAFMAMABWAFoAUQAw
>> "%~1" echo ADkARQBSAFYAOQBUAFQARQBWAEYAVQBEAHcAdgBjADMAQgBoAGIAagA0ADgATAAy
>> "%~1" echo AEoAMQBkAEgAUgB2AGIAagA0AEsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAMgAxAGsASQBHAEoAcwBkAFcAVQBpAEkARwBSAGgAZABH
>> "%~1" echo AEUAdABZAFcATgAwAGEAVwA5AHUAUABTAEoAdwBjAG0AOQA0AFgAMgA5AHcAWgBX
>> "%~1" echo ADQAaQBQAGoAeABpAFAAbgBCAHkAYgAzAGgAZgBiADMAQgBsAGIAagB3AHYAWQBq
>> "%~1" echo ADQAOABjADMAQgBoAGIAagA3AG8AcAA2AFAAcABtAGEAVABtAHEASwBIAG0AaQA1
>> "%~1" echo AC8AawB2AGEAbgBtAGkATABRADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABY
>> "%~1" echo AFIAMABiADIANAArAEMAagB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0ATgB0AFoAQwBCAGgAYgBXAEoAbABjAGkAQgBrAFkAVwA1AG4AWgBY
>> "%~1" echo AEoAQgBZADMAUgBwAGIAMgA0AGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBQAFMASgB3AGMAbQA5ADQAWAAyAE4AcwBiADMATgBsAEkAagA0ADgAWQBq
>> "%~1" echo ADUAdwBjAG0AOQA0AFgAMgBOAHMAYgAzAE4AbABQAEMAOQBpAFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBQAHUAYQBvAG8AZQBhAEwAbgArAFMAOQBxAGUAYQBJAHQATwBtAGQAbwBP
>> "%~1" echo AGkALwBrAFQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBq
>> "%~1" echo ADQASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAy
>> "%~1" echo ADEAawBJAEcASgBzAGQAVwBVAGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBQAFMASgB6AFkAMwBKAGwAWgBXADUAZgBOAFcAMABpAFAAagB4AGkAUAB1
>> "%~1" echo AFcAeABqACsAVwA1AGwAZQBpADIAaABlAGEAWAB0AGkAQQAxAEkATwBXAEkAaAB1
>> "%~1" echo AG0AUwBuAHoAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoANQB6AFkAMwBKAGwAWgBX
>> "%~1" echo ADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgAUQA4AEwAMwBOAHcAWQBX
>> "%~1" echo ADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBDAGoAeABpAGQAWABSADAAYgAy
>> "%~1" echo ADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBoAGIAVwBKAGwAYwBp
>> "%~1" echo AEIAawBZAFcANQBuAFoAWABKAEIAWQAzAFIAcABiADIANABpAEkARwBSAGgAZABH
>> "%~1" echo AEUAdABZAFcATgAwAGEAVwA5AHUAUABTAEoAegBZADMASgBsAFoAVwA1AGYATQBq
>> "%~1" echo AFIAbwBJAGoANAA4AFkAagA3AGwAcwBZAC8AbAB1AFoAWABvAHQAbwBYAG0AbAA3
>> "%~1" echo AFkAZwBNAGoAUQBnADUAYgBDAFAANQBwAGUAMgBQAEMAOQBpAFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBQAHUAbQBWAHYAKwBhAFgAdAB1AG0AWAB0AE8AUwA0AGoAZQBlAEcAaABP
>> "%~1" echo AFcAeABqAHoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBq
>> "%~1" echo ADQASwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAy
>> "%~1" echo ADEAawBJAEcASgBzAGQAVwBVAGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBQAFMASgB6AGQARwBGADUAWAAyADkAbQBaAGkASQArAFAARwBJACsANQBZ
>> "%~1" echo ACsAVwA1AHIAYQBJADUAbwArAFMANQA1AFMAMQA1AEwAKwBkADUAbwB5AEIAUABD
>> "%~1" echo ADkAaQBQAGoAeAB6AGMARwBGAHUAUABuAE4AMABZAFgAbABmAGIAMgA0AGcAUABT
>> "%~1" echo AEEAdwBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBZAG4AVgAwAGQARwA5AHUAUABn
>> "%~1" echo AG8AOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYgBX
>> "%~1" echo AFEAZwBZAFcAMQBpAFoAWABJAGcAWgBHAEYAdQBaADIAVgB5AFEAVwBOADAAYQBX
>> "%~1" echo ADkAdQBJAGkAQgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwAz
>> "%~1" echo AFIAaABlAFYAOQAxAGMAMgBKAGYAWQBXAE0AaQBQAGoAeABpAFAAbABWAFQAUQBp
>> "%~1" echo ADkAQgBRAHkARABrAHYANQAzAG0AagBJAEgAbABsAEsAVABwAGgAcABJADgATAAy
>> "%~1" echo AEkAKwBQAEgATgB3AFkAVwA0ACsAYwAzAFIAaABlAFYAOQB2AGIAaQBBADkASQBE
>> "%~1" echo AE0AOABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsAQwBq
>> "%~1" echo AHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBOAHQAWgBD
>> "%~1" echo AEIAaQBiAEgAVgBsAEkAaQBCAGsAWQBYAFIAaABMAFcARgBqAGQARwBsAHYAYgBq
>> "%~1" echo ADAAaQBjAG0AVgB6AGQARwBGAHkAZABGADkAaABaAEcASQBpAFAAagB4AGkAUAB1
>> "%~1" echo AG0ASABqAGUAVwBRAHIAeQBCAEIAUgBFAEkAZwA1AHAAeQBOADUAWQBxAGgAUABD
>> "%~1" echo ADkAaQBQAGoAeAB6AGMARwBGAHUAUABtAHQAcABiAEcAdwBnAEsAeQBCAHoAZABH
>> "%~1" echo AEYAeQBkAEMAQgB6AFoAWABKADIAWgBYAEkAOABMADMATgB3AFkAVwA0ACsAUABD
>> "%~1" echo ADkAaQBkAFgAUgAwAGIAMgA0ACsAQwBqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbQBOAHQAWgBDAEIAaABiAFcASgBsAGMAaQBCAGsAWQBX
>> "%~1" echo ADUAbgBaAFgASgBCAFkAMwBSAHAAYgAyADQAaQBJAEcAUgBoAGQARwBFAHQAWQBX
>> "%~1" echo AE4AMABhAFcAOQB1AFAAUwBKAHkAWgBYAE4AMABiADMASgBsAFgAMgBKAGgAWQAy
>> "%~1" echo AHQAMQBjAEMASQArAFAARwBJACsANQBMAHUATwA1AGEAUwBIADUATAB1ADkANQBv
>> "%~1" echo AEcAaQA1AGEAUwBOAFAAQwA5AGkAUABqAHgAegBjAEcARgB1AFAAdQBpAC8AbQBP
>> "%~1" echo AFcATwBuACsAbQBtAGwAdQBhAHMAbwBlAFcARwBtAGUAVwBGAHAAZQBXAEoAagBl
>> "%~1" echo AGUAYQBoAE8AVwBBAHYARAB3AHYAYwAzAEIAaABiAGoANAA4AEwAMgBKADEAZABI
>> "%~1" echo AFIAdgBiAGoANABLAFAAQwA5AGsAYQBYAFkAKwBDAGoAdwB2AFoARwBsADIAUABq
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAZwBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkAKwA1AGEANgBlADUAcABlADIANQBx
>> "%~1" echo AGEAQwA2AEsAZQBJAFAAQwA5AG8ATQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0ADgAZABH
>> "%~1" echo AEYAaQBiAEcAVQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFkAbQB4AGwASQBq
>> "%~1" echo ADQASwBQAEgAUgB5AFAAagB4ADAAWgBEADcAbwB2ADUANwBtAGoAcQBVADgATAAz
>> "%~1" echo AFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBZADIAOQB1AGMAMgA5AHMAWgBV
>> "%~1" echo AE4AdgBiAG0ANABpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABI
>> "%~1" echo AFIAeQBQAGoAeAAwAFoARAA3AG4AbABMAFgAcABoADQAOAA4AEwAMwBSAGsAUABq
>> "%~1" echo AHgAMABaAEMAQgBwAFoARAAwAGkAWQAyADkAdQBjADIAOQBzAFoAVQBKAGgAZABI
>> "%~1" echo AFIAbABjAG4AawBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABI
>> "%~1" echo AFIAeQBQAGoAeAAwAFoARAA3AGsAdgBKAEgAbgBuAEsAQQA4AEwAMwBSAGsAUABq
>> "%~1" echo AHgAMABaAEMAQgBwAFoARAAwAGkAWQAyADkAdQBjADIAOQBzAFoAVgBkAGgAYQAy
>> "%~1" echo AFUAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABq
>> "%~1" echo AHgAMABaAEQANQBYAGEAUwAxAEcAYQBUAHcAdgBkAEcAUQArAFAASABSAGsASQBH
>> "%~1" echo AGwAawBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABWADIAbABtAGEAUwBJACsATABU
>> "%~1" echo AHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUAB1
>> "%~1" echo AGkAdQB2AHUAVwBrAGgAKwBlAEsAdAB1AGEAQQBnAFQAdwB2AGQARwBRACsAUABI
>> "%~1" echo AFIAawBJAEcAbABrAFAAUwBKAGoAYgAyADUAegBiADIAeABsAFUAMwBSAGgAZABH
>> "%~1" echo AFUAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABq
>> "%~1" echo AHgAMABaAEQANwBuAGwATABYAG0AdQBwAEEAOABMADMAUgBrAFAAagB4ADAAWgBD
>> "%~1" echo AEIAcABaAEQAMABpAGMARwA5ADMAWgBYAEoAVABiADMAVgB5AFkAMgBVAHkASQBq
>> "%~1" echo ADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGcAbwA4AEwAMwBSAGgAWQBt
>> "%~1" echo AHgAbABQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAZwBvADgATAAz
>> "%~1" echo AE4AbABZADMAUgBwAGIAMgA0ACsAQwBnAG8AOABjADIAVgBqAGQARwBsAHYAYgBp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYwBHAEYAbgBaAFMASQBnAGEAVwBRADkASQBt
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB3AGkAUABnAG8AOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgBoAGMASABCAFgAYwBtAEYAdwBJAGoANABLAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAWQBYAEIAdwBRADIARgB5AFoAQwBJAGcAYQBX
>> "%~1" echo AFEAOQBJAG0ARgB3AGMARQBOAGgAYwBtAFEAaQBQAGcAbwA4AEkAUwAwAHQASQBH
>> "%~1" echo AFYAdABjAEgAUgA1AEkAQwA4AGcAWgBIAEoAdgBjAEMAQgB6AGQARwBGADAAWgBT
>> "%~1" echo AEEAdABMAFQANABLAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWgBI
>> "%~1" echo AEoAdgBjAEUAVgB0AGMASABSADUASQBpAEIAcABaAEQAMABpAFkAWABCAHIAUgBI
>> "%~1" echo AEoAdgBjAEMASQArAFAASABOADIAWgB6ADQAOABkAFgATgBsAEkARwBoAHkAWgBX
>> "%~1" echo AFkAOQBJAGkATgBwAEwAWABWAHcAYgBHADkAaABaAEMASQB2AFAAagB3AHYAYwAz
>> "%~1" echo AFoAbgBQAGoAeABpAFAAdQBhAEwAbAB1AGEATAB2AFMAQgBCAFUARQBzAGcANQBZ
>> "%~1" echo AGkAdwA2AEwAKwBaADYAWQBlAE0ANwA3AHkATQA1AG8AaQBXADUANABLADUANQBZ
>> "%~1" echo AGUANwA2AFkAQwBKADUAbwB1AHAAUABDADkAaQBQAGoAeAB6AGMARwBGAHUASQBH
>> "%~1" echo AGwAawBQAFMASgBrAGMAbQA5AHcAUwBHAGwAdQBkAEMASQArADUAcAB5AHMANQBa
>> "%~1" echo AHkAdwA1AEwAaQBLADUATAB5AGcANQBaAEMATwA1ADUAUwB4AEkARQBGAEUAUQBp
>> "%~1" echo AEQAbAByAG8AbgBvAG8ANABYAGwAaQBMAEQAbAB0ADcATABvAHYANQA3AG0AagBx
>> "%~1" echo AFgAbgBtAG8AUQBnAFUAWABWAGwAYwAzAFQAagBnAEkATABsAHIAbwBuAG8AbwA0
>> "%~1" echo AFgAbABpAFkAMwBrAHYASgByAGsAdQBvAHoAbQByAEsASABuAG8AYQA3AG8AcgBx
>> "%~1" echo AFQAagBnAEkASQA4AEwAMwBOAHcAWQBXADQAKwBQAEcAbAB1AGMASABWADAASQBI
>> "%~1" echo AFIANQBjAEcAVQA5AEkAbQBaAHAAYgBHAFUAaQBJAEcAbABrAFAAUwBKAGgAYwBH
>> "%~1" echo AHQARwBhAFcAeABsAEkAaQBCAGgAWQAyAE4AbABjAEgAUQA5AEkAaQA1AGgAYwBH
>> "%~1" echo AHMAcwBZAFgAQgB3AGIARwBsAGoAWQBYAFIAcABiADIANAB2AGQAbQA1AGsATABt
>> "%~1" echo AEYAdQBaAEgASgB2AGEAVwBRAHUAYwBHAEYAagBhADIARgBuAFoAUwAxAGgAYwBt
>> "%~1" echo AE4AbwBhAFgAWgBsAEkAaQBCAHoAZABIAGwAcwBaAFQAMABpAFoARwBsAHoAYwBH
>> "%~1" echo AHgAaABlAFQAcAB1AGIAMgA1AGwASQBqADQAOABMADIAUgBwAGQAagA0AEsAUABD
>> "%~1" echo AEUAdABMAFMAQgBrAFoAWABSAGgAYQBXAHcAZwBjADMAUgBoAGQARwBVAGcASwBI
>> "%~1" echo AEoAbABkAG0AVgBoAGIARwBWAGsASQBHAEYAbQBkAEcAVgB5AEkASABWAHcAYgBH
>> "%~1" echo ADkAaABaAEMAawBnAEwAUwAwACsAQwBqAHgAawBhAFgAWQBnAGEAVwBRADkASQBt
>> "%~1" echo AEYAdwBhADAAUgBsAGQARwBGAHAAYgBDAEkAZwBjADMAUgA1AGIARwBVADkASQBt
>> "%~1" echo AFIAcABjADMAQgBzAFkAWABrADYAYgBtADkAdQBaAFMASQArAEMAagB4AGsAYQBY
>> "%~1" echo AFkAZwBZADIAeABoAGMAMwBNADkASQBtAEYAdwBjAEUAaABsAGMAbQA4AGkAUABn
>> "%~1" echo AG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBoAGMASABCAEoAWQAy
>> "%~1" echo ADkAdQBWAEcAbABzAFoAUwBJAGcAYQBXAFEAOQBJAG0ARgB3AGEAMABsAGoAYgAy
>> "%~1" echo ADUAVQBhAFcAeABsAEkAagA0ADgAYwAzAFoAbgBJAEgAWgBwAFoAWABkAEMAYgAz
>> "%~1" echo AGcAOQBJAGoAQQBnAE0AQwBBAHkATgBDAEEAeQBOAEMASQArAFAASABWAHoAWgBT
>> "%~1" echo AEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBTADEAaABjAEcAcwBpAEwAegA0ADgATAAz
>> "%~1" echo AE4AMgBaAHoANAA4AEwAMgBSAHAAZABqADQASwBQAEcAUgBwAGQAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAFgAQgB3AFQAbQBGAHQAWgBT
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbQBGAHcAYQAwADUAaABiAFcAVQBpAFAAaQAwADgATAAy
>> "%~1" echo AFIAcABkAGoANABLAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYwBH
>> "%~1" echo AGwAcwBiAEYASgB2AGQAeQBJAGcAYQBXAFEAOQBJAG0ARgB3AGEAMQBCAHAAYgBH
>> "%~1" echo AHgAegBJAGoANAA4AEwAMgBSAHAAZABqADQASwBQAEMAOQBrAGEAWABZACsAQwBq
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAZwBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAMgBaAFgASgBDAFkAVwBSAG4AWgBTAEkAZwBhAFcAUQA5AEkAbQBGAHcAYQAx
>> "%~1" echo AFoAbABjAGsASgBoAFoARwBkAGwASQBqADQAOABMADIAUgBwAGQAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiADMAQgAwAFUAbQA5ADMASQBq
>> "%~1" echo ADQASwBQAEcAeABoAFkAbQBWAHMASQBHAE4AcwBZAFgATgB6AFAAUwBKAHYAYwBI
>> "%~1" echo AFIARABhAEcAbAB3AEkAagA0ADgAYQBXADUAdwBkAFgAUQBnAGQASABsAHcAWgBU
>> "%~1" echo ADAAaQBZADIAaABsAFkAMgB0AGkAYgAzAGcAaQBJAEcAbABrAFAAUwBKAHYAYwBI
>> "%~1" echo AFIAUwBaAFgAQgBzAFkAVwBOAGwASQBpAEIAagBhAEcAVgBqAGEAMgBWAGsAUAB1
>> "%~1" echo AG0ASABqAGUAaQBqAGgAZQBTAC8AbgBlAGUAVgBtAGUAYQBWAHMATwBhAE4AcgBp
>> "%~1" echo AEEAOABjADIAMQBoAGIARwB3ACsATABYAEkAOABMADMATgB0AFkAVwB4AHMAUABq
>> "%~1" echo AHcAdgBiAEcARgBpAFoAVwB3ACsAQwBqAHgAcwBZAFcASgBsAGIAQwBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAGIAMwBCADAAUQAyAGgAcABjAEMASQArAFAARwBsAHUAYwBI
>> "%~1" echo AFYAMABJAEgAUgA1AGMARwBVADkASQBtAE4AbwBaAFcATgByAFkAbQA5ADQASQBp
>> "%~1" echo AEIAcABaAEQAMABpAGIAMwBCADAAUgAzAEoAaABiAG4AUQBpAFAAdQBhAE8AaQBP
>> "%~1" echo AFMANgBpAE8AVwBGAHEATwBtAEQAcQBPAGEAZABnACsAbQBaAGsAQwBBADgAYwAy
>> "%~1" echo ADEAaABiAEcAdwArAEwAVwBjADgATAAzAE4AdABZAFcAeABzAFAAagB3AHYAYgBH
>> "%~1" echo AEYAaQBaAFcAdwArAEMAagB4AHMAWQBXAEoAbABiAEMAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBiADMAQgAwAFEAMgBoAHAAYwBDAEkAKwBQAEcAbAB1AGMASABWADAASQBI
>> "%~1" echo AFIANQBjAEcAVQA5AEkAbQBOAG8AWgBXAE4AcgBZAG0AOQA0AEkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBiADMAQgAwAFIARwA5ADMAYgBtAGQAeQBZAFcAUgBsAEkAagA3AGwAaABZ
>> "%~1" echo AEgAbwByAHIAagBwAG0AWQAzAG4AdQBxAGMAZwBQAEgATgB0AFkAVwB4AHMAUABp
>> "%~1" echo ADEAawBQAEMAOQB6AGIAVwBGAHMAYgBEADQAOABMADIAeABoAFkAbQBWAHMAUABn
>> "%~1" echo AG8AOABiAEcARgBpAFoAVwB3AGcAWQAyAHgAaABjADMATQA5AEkAbQA5AHcAZABF
>> "%~1" echo AE4AbwBhAFgAQQBpAFAAagB4AHAAYgBuAEIAMQBkAEMAQgAwAGUAWABCAGwAUABT
>> "%~1" echo AEoAagBhAEcAVgBqAGEAMgBKAHYAZQBDAEkAZwBhAFcAUQA5AEkAbQA5AHcAZABG
>> "%~1" echo AFYAdQBhAFcANQB6AGQARwBGAHMAYgBFAFoAcABjAG4ATgAwAEkAagA3AG4AcgBi
>> "%~1" echo ADcAbABrAEkAMwBrAHUASQAzAG4AcgBLAGIAbABoAFkAagBsAGoAYgBqAG8AdgBi
>> "%~1" echo ADAAZwBQAEgATgB0AFkAVwB4AHMAUAB1AGEANABoAGUAYQBWAHMATwBhAE4AcgBq
>> "%~1" echo AHcAdgBjADIAMQBoAGIARwB3ACsAUABDADkAcwBZAFcASgBsAGIARAA0AEsAUABD
>> "%~1" echo ADkAawBhAFgAWQArAEMAagB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0AbAB1AGMAMwBSAGgAYgBHAHgAQwBkAEcANABpAEkARwBsAGsAUABT
>> "%~1" echo AEoAcABiAG4ATgAwAFkAVwB4AHMAUQBuAFIAdQBJAGoANAA4AGMAMwBCAGgAYgBp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYQBXADUAegBkAEcARgBzAGIARQBaAHAAYgBH
>> "%~1" echo AHcAaQBJAEcAbABrAFAAUwBKAHAAYgBuAE4AMABZAFcAeABzAFIAbQBsAHMAYgBD
>> "%~1" echo AEkAKwBQAEMAOQB6AGMARwBGAHUAUABqAHgAegBjAEcARgB1AEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgBwAGIAbgBOADAAWQBXAHgAcwBUAEcARgBpAFoAVwB3AGkASQBH
>> "%~1" echo AGwAawBQAFMASgBwAGIAbgBOADAAWQBXAHgAcwBUAEcARgBpAFoAVwB3AGkAUAB1
>> "%~1" echo AFcAdQBpAGUAaQBqAGgAZQBXAEkAcwBDAEIAUgBkAFcAVgB6AGQARAB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANABLAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYwAzAFIAaABaADIAVgBTAGIAMwBjAGkASQBH
>> "%~1" echo AGwAawBQAFMASgB6AGQARwBGAG4AWgBWAEoAdgBkAHkASQArAFAASABOAHcAWQBX
>> "%~1" echo ADQAZwBhAFcAUQA5AEkAbgBOADAAWQBXAGQAbABWAEcAVgA0AGQAQwBJACsANQBZ
>> "%~1" echo AGUARwA1AGEAUwBIADUATABpAHQANABvAEMAbQBQAEMAOQB6AGMARwBGAHUAUABq
>> "%~1" echo AHgAegBjAEcARgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBsAGIARwBGAHcAYwAy
>> "%~1" echo AFYAawBJAGkAQgBwAFoARAAwAGkAWgBXAHgAaABjAEgATgBsAFoAQwBJACsATQBE
>> "%~1" echo AG8AdwBNAEQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAEcAVgB5AGIAWABOAFEAYgAz
>> "%~1" echo AEEAaQBJAEcAbABrAFAAUwBKAGgAYwBHAHQAUQBaAFgASgB0AGMAeQBJACsAUABD
>> "%~1" echo ADkAawBhAFgAWQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AEYAawBZAGsAOQAxAGQAQwBJAGcAYQBXAFEAOQBJAG0ARgBrAFkAawA5ADEAZABD
>> "%~1" echo AEkAKwBQAEMAOQBrAGEAWABZACsAQwBqAHgAawBhAFgAWQBnAGMAMwBSADUAYgBH
>> "%~1" echo AFUAOQBJAG0AMQBoAGMAbQBkAHAAYgBpADEAMABiADMAQQA2AE0AVABKAHcAZQBE
>> "%~1" echo AHQAawBhAFgATgB3AGIARwBGADUATwBtAFoAcwBaAFgAZwA3AFoAMgBGAHcATwBq
>> "%~1" echo AEUAMABjAEgAZwA3AFoAbQB4AGwAZQBDADEAMwBjAG0ARgB3AE8AbgBkAHkAWQBY
>> "%~1" echo AEEAaQBQAGoAeABoAEkARwBoAHkAWgBXAFkAOQBJAGkATQBpAEkARwBsAGsAUABT
>> "%~1" echo AEoAaABjAEcAdABRAFoAWABKAHQAYwAwAEoAMABiAGkASQBnAGMAMwBSADUAYgBH
>> "%~1" echo AFUAOQBJAG0ATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwBKAHMAZABX
>> "%~1" echo AFUAcABPADIAWgB2AGIAbgBRAHQAZAAyAFYAcABaADIAaAAwAE8AagBjAHcATQBE
>> "%~1" echo AHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAFQATgB3AGUAQwBJACsANQBw
>> "%~1" echo ACsAbAA1ADUAeQBMADUAcAAyAEQANgBaAG0AUQBQAEMAOQBoAFAAagB4AGgASQBH
>> "%~1" echo AGgAeQBaAFcAWQA5AEkAaQBNAGkASQBHAGwAawBQAFMASgBoAGMARwB0AFMAWgBY
>> "%~1" echo AE4AbABkAEMASQBnAGMAMwBSADUAYgBHAFUAOQBJAG0ATgB2AGIARwA5AHkATwBu
>> "%~1" echo AFoAaABjAGkAZwB0AEwAVwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABY
>> "%~1" echo AGQAbABhAFcAZABvAGQARABvADMATQBEAEEANwBaAG0AOQB1AGQAQwAxAHoAYQBY
>> "%~1" echo AHAAbABPAGoARQB6AGMASABnAGkAUAB1AGEATgBvAHUAUwA0AGcATwBTADQAcQBp
>> "%~1" echo AEIAQgBVAEUAcwA4AEwAMgBFACsAUABDADkAawBhAFgAWQArAEMAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AEwAMgBSAHAAZABqADQASwBQAEMAOQBrAGEAWABZACsAQwBq
>> "%~1" echo AHcAdgBjADIAVgBqAGQARwBsAHYAYgBqADQASwBDAGcAbwA4AGMAMgBWAGoAZABH
>> "%~1" echo AGwAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAEcARgBuAFoAUwBJAGcAYQBX
>> "%~1" echo AFEAOQBJAG0AUgBsAGQAbQBsAGoAWgBTAEkAKwBDAGoAeABrAGEAWABZAGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbQBOAGgAYwBtAFEAaQBQAGoAeABrAGEAWABZAGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbQBoAGwAWQBXAFEAaQBQAGoAeABvAE0AagA3AG8AcgBy
>> "%~1" echo ADcAbABwAEkAZgBtAG8AYQBQAG0AbwBZAGcAOABMADIAZwB5AFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAMABZAFcAYwBpAFAAdQBXAEYAcgBP
>> "%~1" echo AFcAOABnAEMAQgBCAFIARQBJAGcANQBZACsAcQA2AEsAKwA3AFAAQwA5AHoAYwBH
>> "%~1" echo AEYAdQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0AbAB1AFoAbQA5AEgAYwBtAGwAawBJAGoANABLAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYQBXADUAbQBiADEAUgBwAGIARwBVAGkAUABq
>> "%~1" echo AHgAegBjAEcARgB1AFAAdQBXAE8AZwB1AFcAVgBoAGkAQQB2AEkATwBXAFQAZwBl
>> "%~1" echo AGUASgBqAEQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGoANAA4AGMAMwBCAGgAYgBp
>> "%~1" echo AEIAcABaAEQAMABpAGIAVwBGAHUAZABXAFoAaABZADMAUgAxAGMAbQBWAHkASQBq
>> "%~1" echo ADQAdABQAEMAOQB6AGMARwBGAHUAUABpAEEAdgBJAEQAeAB6AGMARwBGAHUASQBH
>> "%~1" echo AGwAawBQAFMASgBpAGMAbQBGAHUAWgBDAEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBq
>> "%~1" echo ADQAOABMADIASQArAFAAQwA5AGsAYQBYAFkAKwBDAGoAeABrAGEAWABZAGcAWQAy
>> "%~1" echo AHgAaABjADMATQA5AEkAbQBsAHUAWgBtADkAVQBhAFcAeABsAEkAagA0ADgAYwAz
>> "%~1" echo AEIAaABiAGoANwBsAG4AbwB2AGwAagA3AGMAOABMADMATgB3AFkAVwA0ACsAUABH
>> "%~1" echo AEkAZwBhAFcAUQA5AEkAbQAxAHYAWgBHAFYAcwBJAGoANAB0AFAAQwA5AGkAUABq
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAZwBvADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABT
>> "%~1" echo AEoAcABiAG0AWgB2AFYARwBsAHMAWgBTAEkAKwBQAEgATgB3AFkAVwA0ACsANQBM
>> "%~1" echo AHEAbgA1AFoATwBCAEkAQwA4AGcANgBLADYAKwA1AGEAUwBIAEkAQwA4AGcANQBw
>> "%~1" echo ADIALwA1ADcAcQBuAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBJAEcAbABrAFAAUwBKAHcAYwBtADkAawBkAFcATgAwAFQAbQBGAHQAWgBT
>> "%~1" echo AEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMAMwBCAGgAYgBp
>> "%~1" echo AEIAcABaAEQAMABpAGMASABKAHYAWgBIAFYAagBkAEUAUgBsAGQAbQBsAGoAWgBT
>> "%~1" echo AEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMAMwBCAGgAYgBp
>> "%~1" echo AEIAcABaAEQAMABpAFkAbQA5AGgAYwBtAFEAaQBQAGkAMAA4AEwAMwBOAHcAWQBX
>> "%~1" echo ADQAKwBQAEMAOQBpAFAAagB3AHYAWgBHAGwAMgBQAGcAbwA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABI
>> "%~1" echo AE4AdwBZAFcANAArAFUAMgA5AEQAUABDADkAegBjAEcARgB1AFAAagB4AGkASQBH
>> "%~1" echo AGwAawBQAFMASgB6AGIAMgBNAGkAUABpADAAOABMADIASQArAFAAQwA5AGsAYQBY
>> "%~1" echo AFkAKwBDAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBsAHUAWgBt
>> "%~1" echo ADkAVQBhAFcAeABsAEkAagA0ADgAYwAzAEIAaABiAGoANQBDAGQAVwBsAHMAWgBE
>> "%~1" echo AHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAFkAbgBWAHAAYgBH
>> "%~1" echo AFIASgBaAEMASQArAEwAVAB3AHYAWQBqADQAOABMADIAUgBwAGQAagA0AEsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAFcANQBtAGIAMQBSAHAAYgBH
>> "%~1" echo AFUAaQBQAGoAeAB6AGMARwBGAHUAUABrAEoAeQBZAFcANQBqAGEARAB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AFkAaQBCAHAAWgBEADAAaQBZAG4AVgBwAGIARwBSAEMAYwBt
>> "%~1" echo AEYAdQBZADIAZwBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQBrAGEAWABZACsAQwBq
>> "%~1" echo AHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AbAB1AFoAbQA5AFUAYQBX
>> "%~1" echo AHgAbABJAGoANAA4AGMAMwBCAGgAYgBqADUASgBiAG0ATgB5AFoAVwAxAGwAYgBu
>> "%~1" echo AFIAaABiAEQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGkAQgBwAFoARAAwAGkAWQBu
>> "%~1" echo AFYAcABiAEcAUgBKAGIAbQBOAHkAWgBXADEAbABiAG4AUgBoAGIAQwBJACsATABU
>> "%~1" echo AHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQASwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAGEAVwA1AG0AYgAxAFIAcABiAEcAVQBpAFAAagB4AHoAYwBH
>> "%~1" echo AEYAdQBQAGsARgBDAFMAVAB3AHYAYwAzAEIAaABiAGoANAA4AFkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBZAFcASgBwAEkAagA0AHQAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABn
>> "%~1" echo AG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBwAGIAbQBaAHYAVgBH
>> "%~1" echo AGwAcwBaAFMASQArAFAASABOAHcAWQBXADQAKwBWAG0AVgB1AFoARwA5AHkASQBG
>> "%~1" echo AEIAaABkAEcATgBvAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAEkARwBsAGsAUABT
>> "%~1" echo AEoAMgBaAFcANQBrAGIAMwBKAFEAWQBYAFIAagBhAEMASQArAEwAVAB3AHYAWQBq
>> "%~1" echo ADQAOABMADIAUgBwAGQAagA0AEsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBY
>> "%~1" echo AFkAKwBQAEMAOQBrAGEAWABZACsAQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG4ASgB2AGQAeQBJACsAQwBqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0ATgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAz
>> "%~1" echo AE0AOQBJAG0AaABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBvAHIAcgA3AGwAcABJ
>> "%~1" echo AGYAawB1AEkANwBvAHYANQA3AG0AagBxAFUAOABMADIAZwB5AFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBI
>> "%~1" echo AGsAaQBQAGoAeAAwAFkAVwBKAHMAWgBTAEIAagBiAEcARgB6AGMAegAwAGkAZABH
>> "%~1" echo AEYAaQBiAEcAVQBpAFAAZwBvADgAZABIAEkAKwBQAEgAUgBrAFAAawBGAEUAUQBp
>> "%~1" echo AEQAbwB0ADYALwBsAHYAbwBRADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBE
>> "%~1" echo ADAAaQBZAFcAUgBpAFUARwBGADAAYQBDAEkAKwBMAFQAdwB2AGQARwBRACsAUABD
>> "%~1" echo ADkAMABjAGoANAA4AGQASABJACsAUABIAFIAawBQAHUAaQB1AHYAdQBXAGsAaAAr
>> "%~1" echo AGkAaABqAEQAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAGsAWgBY
>> "%~1" echo AFoAcABZADIAVgBNAGEAVwA1AGwASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAz
>> "%~1" echo AFIAeQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwBWADIAawB0AFIAbQBrAGcAUwBW
>> "%~1" echo AEEAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQAMABpAGQAMgBsAG0AYQBV
>> "%~1" echo AGwAdwBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB4ADAAYwBq
>> "%~1" echo ADQAOABkAEcAUQArAFEAVwA1AGsAYwBtADkAcABaAEQAdwB2AGQARwBRACsAUABI
>> "%~1" echo AFIAawBJAEcAbABrAFAAUwBKAGgAYgBtAFIAeQBiADIAbABrAEkAagA0AHQAUABD
>> "%~1" echo ADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQARwBRACsAVQAw
>> "%~1" echo AFIATABQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbgBOAGsAYQB5
>> "%~1" echo AEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABI
>> "%~1" echo AFIAawBQAHUAVwB1AGkAZQBXAEYAcQBPAGkAaABwAGUAUwA0AGcAVAB3AHYAZABH
>> "%~1" echo AFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoAegBaAFcATgAxAGMAbQBsADAAZQBW
>> "%~1" echo AEIAaABkAEcATgBvAEkAagA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABn
>> "%~1" echo AG8AOABMADMAUgBoAFkAbQB4AGwAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAWQBY
>> "%~1" echo AEoAawBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AWgBX
>> "%~1" echo AEYAawBJAGoANAA4AGEARABJACsANQA2AEcAcwA1AEwAdQAyADUAcABHAFkANgBL
>> "%~1" echo AGEAQgBQAEMAOQBvAE0AagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoANAA4AGQARwBGAGkAYgBH
>> "%~1" echo AFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABZAG0AeABsAEkAagA0AEsAUABI
>> "%~1" echo AFIAeQBQAGoAeAAwAFoARAA3AG0AbQBMADcAbgBwAEwAbwA4AEwAMwBSAGsAUABq
>> "%~1" echo AHgAMABaAEMAQgBwAFoARAAwAGkAWgBHAGwAegBjAEcAeABoAGUAVgBOADEAYgBX
>> "%~1" echo ADEAaABjAG4AawBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABI
>> "%~1" echo AFIAeQBQAGoAeAAwAFoARAA3AG4AZwA2ADMAbgBpAHIAYgBtAGcASQBFADgATAAz
>> "%~1" echo AFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBkAEcAaABsAGMAbQAxAGgAYgBG
>> "%~1" echo AE4AMQBiAFcAMQBoAGMAbgBrAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABI
>> "%~1" echo AEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADcAbAB0ADYAWABsAGoAbwBJAHYANQBx
>> "%~1" echo AEMAaAA1AFkAZQBHAFAAQwA5ADAAWgBEADQAOABkAEcAUQBnAGEAVwBRADkASQBt
>> "%~1" echo AFoAaABZADMAUgB2AGMAbgBsAFQAZABXADEAdABZAFgASgA1AEkAagA0AHQAUABD
>> "%~1" echo ADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQARwBRACsAVgBt
>> "%~1" echo AGwAeQBkAEgAVgBoAGIAQwBCAEUAWgBYAE4AcgBkAEcAOQB3AFAAQwA5ADAAWgBE
>> "%~1" echo ADQAOABkAEcAUQArAFAASABOAHcAWQBXADQAZwBhAFcAUQA5AEkAbgBaAGsAVQBH
>> "%~1" echo AEYAagBhADIARgBuAFoAUwBJACsATABUAHcAdgBjADMAQgBoAGIAagA0AGcAUABI
>> "%~1" echo AE4AdwBZAFcANABnAGEAVwBRADkASQBuAFoAawBWAG0AVgB5AGMAMgBsAHYAYgBp
>> "%~1" echo AEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAOABMADMAUgBrAFAAagB3AHYAZABI
>> "%~1" echo AEkAKwBDAGoAdwB2AGQARwBGAGkAYgBHAFUAKwBQAEMAOQBrAGEAWABZACsAUABD
>> "%~1" echo ADkAawBhAFgAWQArAEMAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAbQBpAFkAdgBtAG4ANABUAG4AdQBy
>> "%~1" echo AC8AbgB0AEsASQA4AEwAMgBnAHkAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBY
>> "%~1" echo AFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgAawBpAFAAagB4ADAAWQBX
>> "%~1" echo AEoAcwBaAFMAQgBqAGIARwBGAHoAYwB6ADAAaQBkAEcARgBpAGIARwBVAGkAUABn
>> "%~1" echo AG8AOABkAEgASQArAFAASABSAGsAUAB1AFcAMwBwAHUAYQBKAGkAKwBhAGYAaABP
>> "%~1" echo AGUAVQB0AGUAbQBIAGoAegB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABT
>> "%~1" echo AEoAagBiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcAVgBtAGQARQBKAGgAZABI
>> "%~1" echo AFIAbABjAG4AawBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABI
>> "%~1" echo AFIAeQBQAGoAeAAwAFoARAA3AGwAagA3AFAAbQBpAFkAdgBtAG4ANABUAG4AbABM
>> "%~1" echo AFgAcABoADQAOAA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAWQAy
>> "%~1" echo ADkAdQBkAEgASgB2AGIARwB4AGwAYwBsAEoAcABaADIAaAAwAFEAbQBGADAAZABH
>> "%~1" echo AFYAeQBlAFMASQArAEwAVAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0ADgAZABI
>> "%~1" echo AEkAKwBQAEgAUgBrAFAAdQBXADMAcAB1AGEASgBpACsAYQBmAGgATwBlAEsAdAB1
>> "%~1" echo AGEAQQBnAFQAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAGoAYgAy
>> "%~1" echo ADUAMABjAG0AOQBzAGIARwBWAHkAVABHAFYAbQBkAEYATgAwAFkAWABSADEAYwB5
>> "%~1" echo AEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABI
>> "%~1" echo AFIAawBQAHUAVwBQAHMAKwBhAEoAaQArAGEAZgBoAE8AZQBLAHQAdQBhAEEAZwBU
>> "%~1" echo AHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMASgBqAGIAMgA1ADAAYwBt
>> "%~1" echo ADkAcwBiAEcAVgB5AFUAbQBsAG4AYQBIAFIAVABkAEcARgAwAGQAWABNAGkAUABp
>> "%~1" echo ADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBDAGoAdwB2AGQARwBGAGkAYgBH
>> "%~1" echo AFUAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIARwA5AG4ASQBp
>> "%~1" echo AEIAcABaAEQAMABpAFkAMgA5AHUAZABIAEoAdgBiAEcAeABsAGMAawBoAHAAYgBu
>> "%~1" echo AFEAaQBQAGkAMAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgATAAy
>> "%~1" echo AFIAcABkAGoANABLAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAy
>> "%~1" echo AEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBH
>> "%~1" echo AFYAaABaAEMASQArAFAARwBnAHkAUAB1AGUAVQB0AGUAYQA2AGsATwBlAEsAdAB1
>> "%~1" echo AGEAQQBnAFQAdwB2AGEARABJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAWQBtADkAawBlAFMASQArAFAASABSAGgAWQBt
>> "%~1" echo AHgAbABJAEcATgBzAFkAWABOAHoAUABTAEoAMABZAFcASgBzAFoAUwBJACsAQwBq
>> "%~1" echo AHgAMABjAGoANAA4AGQARwBRACsAYgBWAE4AMABZAFgAbABQAGIAagB3AHYAZABH
>> "%~1" echo AFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoAdABVADMAUgBoAGUAVQA5AHUASQBq
>> "%~1" echo ADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGoAeAAwAGMAagA0ADgAZABH
>> "%~1" echo AFEAKwBiAFYAQgB5AGIAMwBoAHAAYgBXAGwAMABlAFYAQgB2AGMAMgBsADAAYQBY
>> "%~1" echo AFoAbABQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQAxAFEAYwBt
>> "%~1" echo ADkANABhAFcAMQBwAGQASABsAFEAYgAzAE4AcABkAEcAbAAyAFoAUwBJACsATABU
>> "%~1" echo AHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUABt
>> "%~1" echo ADEAVABkAEcARgA1AFQAMgA1AFgAYQBHAGwAcwBaAFYAQgBzAGQAVwBkAG4AWgBX
>> "%~1" echo AFIASgBiAGwATgBsAGQASABSAHAAYgBtAGMAOABMADMAUgBrAFAAagB4ADAAWgBD
>> "%~1" echo AEIAcABaAEQAMABpAGIAVgBOADAAWQBYAGwAUABiAGwATgBsAGQASABSAHAAYgBt
>> "%~1" echo AGMAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABq
>> "%~1" echo AHgAMABaAEQANQBUAGIARwBWAGwAYwBDAEIAMABhAFcAMQBsAGIAMwBWADAAUABD
>> "%~1" echo ADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG4AQgB2AGQAMgBWAHkAVQAy
>> "%~1" echo AHgAbABaAFgAQgBNAGEAVwA1AGwASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAz
>> "%~1" echo AFIAeQBQAGcAbwA4AEwAMwBSAGgAWQBtAHgAbABQAGoAdwB2AFoARwBsADIAUABq
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAZwBvADgATAAyAFIAcABkAGoANABLAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1
>> "%~1" echo AFcAUABnAHUAYQBWAHMATwBXAHYAdQBlAGUARgBwAHoAdwB2AGEARABJACsAUABI
>> "%~1" echo AE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoAeQBJAGcAYQBX
>> "%~1" echo AFEAOQBJAG4AQgBoAGMAbQBGAHQAVQAzAFYAdABiAFcARgB5AGUAUwBJACsATABU
>> "%~1" echo AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoANAA4AFoARwBsADIASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAHcAWQBYAEoAaABiAFUAeABwAGMAMwBRAGkASQBH
>> "%~1" echo AGwAawBQAFMASgB3AFkAWABKAGgAYgBVAHgAcABjADMAUQBpAFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAZwBvADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBE
>> "%~1" echo AEkAKwA1AGIAZQBsADUAWQA2AEMASQBDADgAZwA1AHEAQwBoADUAWQBlAEcANQBv
>> "%~1" echo ADYAbwA1AHAAYQB0ADYATAA2ADUANQA1AFcATQBQAEMAOQBvAE0AagA0ADgATAAy
>> "%~1" echo AFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAy
>> "%~1" echo AFIANQBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHMAYgAy
>> "%~1" echo AGMAaQBQAHUAVwBQAHIAKwBTADcAcABlAGEAWQB2AHUAZQBrAHUAaQBCAFIAZABX
>> "%~1" echo AFYAegBkAEMARABsAGgAYQB6AGwAdgBJAEEAZwBRAFUAUgBDAEkATwBhAGEAdABP
>> "%~1" echo AG0AYwBzAHUAZQBhAGgAQwBCAEcAWQBXAE4AMABiADMASgA1AEkAQwA4AGcAVAAy
>> "%~1" echo ADUAcwBhAFcANQBsAEkARwBOAGgAYgBHAGwAaQBjAG0ARgAwAGEAVwA5AHUASQBP
>> "%~1" echo AGUANgB2ACsAZQAwAG8AdQArADgAagBPAFMAKwBpACsAVwBtAGcAaQBCAEYAZABY
>> "%~1" echo AEoAbABhADIASABqAGcASQBGAFEAVgBsAFEAeABMAGoASABqAGcASQBGAHoAZABH
>> "%~1" echo AEYAMABhAFcAOQB1AEwAMgB4AHYAWQAyAEYAMABhAFcAOQB1AEwAMwBSAGwAYwAz
>> "%~1" echo AFEAZwA1AEwAdQBqADUANgBDAEIANAA0AEMAQwA1AEwAaQBOADYASQBPADkANQBv
>> "%~1" echo AHEASwA1AFkAYQBGADYAWQBPAG8ANQBMAHUAagA1ADYAQwBCADUAWQArAHYANgBa
>> "%~1" echo ADIAZwA1ADcAKwA3ADYASwArAFIANQBvAGkAUQA1AFkAVwAzADUATAAyAFQANQBa
>> "%~1" echo AHUAOQA1AGEANgAyADQANABDAEIANQBaACsATwA1AGIAaQBDADUAbwBpAFcANQBi
>> "%~1" echo AGUAbAA1AFkANgBDADcANwB5AGIAVgAyAGsAdABSAG0AawBnADUAWgB1ADkANQBh
>> "%~1" echo ADYAMgA1ADYAQwBCADUATABtAGYANQBMAGkATgA1ADYAMgBKADUATABxAE8ANQBZ
>> "%~1" echo AGUANgA1AEwAcQBuADUAWgB5AHcANAA0AEMAQwA1AGEANgBNADUAcABXADAANQBh
>> "%~1" echo ADIAWAA1AHEANgAxADYASwArADMANQA1AFMAbwA0AG8AQwBjADUATABpAEEANgBa
>> "%~1" echo AFMAdQA1AGEAKwA4ADUAWQBlADYANgBLADYAKwA1AGEAUwBIADUAWQBXAG8ANgBZ
>> "%~1" echo AE8AbwA1AEwAKwBoADUAbwBHAHYANABvAEMAZAA0ADQAQwBDAFAAQwA5AGsAYQBY
>> "%~1" echo AFkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAEMAagB3AHYAYwAy
>> "%~1" echo AFYAagBkAEcAbAB2AGIAagA0AEsAQwBqAHgAegBaAFcATgAwAGEAVwA5AHUASQBH
>> "%~1" echo AE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkAQgBwAFoARAAwAGkAYwAy
>> "%~1" echo AFYAMABkAEcAbAB1AFoAMwBNAGkAUABnAG8AOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgBqAFkAWABKAGsASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQAOABhAEQASQArADYASQBlAHEANQBh
>> "%~1" echo ADYAYQA1AEwAbQBKAEkASABOAGwAZABIAFIAcABiAG0AZAB6AEkASABCADEAZABE
>> "%~1" echo AHcAdgBhAEQASQArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAbQA5AGsAZQBTAEIAbQBiADMASgB0AEkAagA0ADgAYwAy
>> "%~1" echo AFYAcwBaAFcATgAwAEkARwBsAGsAUABTAEoAagBkAFgATgAwAGIAMgAxAE8AYwB5
>> "%~1" echo AEkAKwBQAEcAOQB3AGQARwBsAHYAYgBqADUAbgBiAEcAOQBpAFkAVwB3ADgATAAy
>> "%~1" echo ADkAdwBkAEcAbAB2AGIAagA0ADgAYgAzAEIAMABhAFcAOQB1AFAAbgBOADUAYwAz
>> "%~1" echo AFIAbABiAFQAdwB2AGIAMwBCADAAYQBXADkAdQBQAGoAeAB2AGMASABSAHAAYgAy
>> "%~1" echo ADQAKwBjADIAVgBqAGQAWABKAGwAUABDADkAdgBjAEgAUgBwAGIAMgA0ACsAUABD
>> "%~1" echo ADkAegBaAFcAeABsAFkAMwBRACsAUABHAGwAdQBjAEgAVgAwAEkARwBsAGsAUABT
>> "%~1" echo AEoAagBkAFgATgAwAGIAMgAxAEwAWgBYAGsAaQBJAEgAQgBzAFkAVwBOAGwAYQBH
>> "%~1" echo ADkAcwBaAEcAVgB5AFAAUwBMAHAAbABLADcAbABrAEkAMwB2AHYASQB6AGsAdgBv
>> "%~1" echo AHYAbABwAG8ASQBnAGMAMgBOAHkAWgBXAFYAdQBYADIAOQBtAFoAbAA5ADAAYQBX
>> "%~1" echo ADEAbABiADMAVgAwAEkAagA0ADgAYQBXADUAdwBkAFgAUQBnAGEAVwBRADkASQBt
>> "%~1" echo AE4AMQBjADMAUgB2AGIAVgBaAGgAYgBIAFYAbABJAGkAQgB3AGIARwBGAGoAWgBX
>> "%~1" echo AGgAdgBiAEcAUgBsAGMAagAwAGkANQBZAEMAOABJAGoANAA4AFkAbgBWADAAZABH
>> "%~1" echo ADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBkAEcANABpAEkARwBsAGsAUABT
>> "%~1" echo AEoAagBkAFgATgAwAGIAMgAxAFQAWgBYAFEAaQBQAHUAVwBHAG0AZQBXAEYAcABU
>> "%~1" echo AHcAdgBZAG4AVgAwAGQARwA5AHUAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAWQBY
>> "%~1" echo AEoAawBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AWgBX
>> "%~1" echo AEYAawBJAGoANAA4AGEARABJACsANQBZACsAUgA2AFkAQwBCADYASQBlAHEANQBh
>> "%~1" echo ADYAYQA1AEwAbQBKADUAYgBtAC8ANQBwAEsAdABQAEMAOQBvAE0AagA0ADgATAAy
>> "%~1" echo AFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAy
>> "%~1" echo AFIANQBJAEcAWgB2AGMAbQAwAGkASQBIAE4AMABlAFcAeABsAFAAUwBKAG4AYwBt
>> "%~1" echo AGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcATgB2AGIASABWAHQAYgBu
>> "%~1" echo AE0ANgBNAFcAWgB5AEkARABrAHcAYwBIAGcAaQBQAGoAeABwAGIAbgBCADEAZABD
>> "%~1" echo AEIAcABaAEQAMABpAFkAbgBKAHYAWQBXAFIAagBZAFgATgAwAFQAbQBGAHQAWgBT
>> "%~1" echo AEkAZwBjAEcAeABoAFkAMgBWAG8AYgAyAHgAawBaAFgASQA5AEkAdQBTACsAaQAr
>> "%~1" echo AFcAbQBnAGkAQgBqAGIAMgAwAHUAYgAyAE4AMQBiAEgAVgB6AEwAbgBaAHkAYwBH
>> "%~1" echo ADkAMwBaAFgASgB0AFkAVwA1AGgAWgAyAFYAeQBMAG4AQgB5AGIAMwBoAGYAYgAz
>> "%~1" echo AEIAbABiAGkASQArAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBZAG4AUgB1AEkAaQBCAHAAWgBEADAAaQBZADMAVgB6AGQARwA5AHQAUQBu
>> "%~1" echo AEoAdgBZAFcAUgBqAFkAWABOADAASQBqADcAbABqADUASABwAGcASQBFADgATAAy
>> "%~1" echo AEoAMQBkAEgAUgB2AGIAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABq
>> "%~1" echo ADQASwBQAEMAOQB6AFoAVwBOADAAYQBXADkAdQBQAGcAbwBLAFAASABOAGwAWQAz
>> "%~1" echo AFIAcABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AQgBoAFoAMgBVAGkASQBH
>> "%~1" echo AGwAawBQAFMASgBzAGIAMgBkAHoASQBqADQASwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAMgBGAHkAWgBDAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAGEARwBWAGgAWgBDAEkAKwBQAEcAZwB5AFAAdQBhAFgAcABl
>> "%~1" echo AFcALwBsAHoAdwB2AGEARABJACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAFkAbgBSAHUASQBHAGQAbwBiADMATgAwAEkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBjAG0AVgBtAGMAbQBWAHoAYQBFAHgAdgBaADMATQBpAFAAdQBXAEkAdAAr
>> "%~1" echo AGEAVwBzAE8AYQBYAHAAZQBXAC8AbAB6AHcAdgBZAG4AVgAwAGQARwA5AHUAUABq
>> "%~1" echo AHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo AEoAdgBaAEgAawBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBt
>> "%~1" echo ADEAbABkAEcARgBKAGQARwBWAHQASQBpAEIAegBkAEgAbABzAFoAVAAwAGkAYgBX
>> "%~1" echo AEYAeQBaADIAbAB1AEwAVwBKAHYAZABIAFIAdgBiAFQAbwB4AE0AbgBCADQASQBq
>> "%~1" echo ADQAOABjADMAQgBoAGIAagA3AG0AbAA2AFgAbAB2ADUAZgBtAGwAbwBmAGsAdQA3
>> "%~1" echo AFkAOABMADMATgB3AFkAVwA0ACsAUABHAEkAZwBhAFcAUQA5AEkAbQB4AHYAWgAx
>> "%~1" echo AEIAaABkAEcAZwBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQBrAGEAWABZACsAUABH
>> "%~1" echo AFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAEcAOQBuAEkAaQBCAHAAWgBE
>> "%~1" echo ADAAaQBiAEcAOQBuAFEAbQA5ADQASQBqADcAbgByAFkAbgBsAHYAbwBYAG0AawA0
>> "%~1" echo ADMAawB2AFoAdwB1AEwAaQA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABq
>> "%~1" echo ADQAOABMADIAUgBwAGQAagA0AEsAUABDADkAegBaAFcATgAwAGEAVwA5AHUAUABn
>> "%~1" echo AG8ASwBQAEMAOQBrAGEAWABZACsAUABDADkAdABZAFcAbAB1AFAAagB3AHYAWgBH
>> "%~1" echo AGwAMgBQAGcAbwA4AGMAMgBOAHkAYQBYAEIAMABQAGcAcABqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAVQBUADAAdABGAFQAagAwAG4AVwAxAHQAVQBUADAAdABGAFQAbAAxAGQASgB6
>> "%~1" echo AHMASwBZADIAOQB1AGMAMwBRAGcASgBEADEAcABaAEQAMAArAFoARwA5AGoAZABX
>> "%~1" echo ADEAbABiAG4AUQB1AFoAMgBWADAAUgBXAHgAbABiAFcAVgB1AGQARQBKADUAUwBX
>> "%~1" echo AFEAbwBhAFcAUQBwAE8AdwBwAGoAYgAyADUAegBkAEMAQgB3AFkAVwBkAGwAYwB6
>> "%~1" echo ADEANwBiADMAWgBsAGMAbgBaAHAAWgBYAGMANgBXAHkAZgBtAGcATAB2AG8AcAA0
>> "%~1" echo AGcAbgBMAEMAZgBuAGkAcgBiAG0AZwBJAEgAbQBqAEkAZgBtAG8ASQBmAGwAawBv
>> "%~1" echo AHoAbwByAHIANwBsAHAASQBmAG0AcABvAEwAbwBwADQAZwBuAFgAUwB4AGoAYgAy
>> "%~1" echo ADUAegBiADIAeABsAE8AbABzAG4ANQBiACsAcgA1AG8AMgAzADUAbwA2AG4ANQBZ
>> "%~1" echo AGkAMgA1AFkAKwB3AEoAeQB3AG4ANQBwAHUAMAA1AGEAUwBhADUAYgBpADQANQA1
>> "%~1" echo AFMAbwBJAEUARgBFAFEAaQBEAG0AawA0ADMAawB2AFoAegBsAGgAYQBYAGwAagA2
>> "%~1" echo AE0AbgBYAFMAeABwAGIAbgBOADAAWQBXAHgAcwBPAGwAcwBuADUAYgBxAFUANQA1
>> "%~1" echo AFMAbwA1AGEANgBKADYASwBPAEYASgB5AHcAbgA1AG8AdQBXADUAWQBXAGwASQBF
>> "%~1" echo AEYAUQBTACsAKwA4AGoATwBlAFUAcQBDAEIAQgBSAEUASQBnADUAYQA2AEoANgBL
>> "%~1" echo AE8ARgA1AFkAaQB3AEkARgBGADEAWgBYAE4AMABKADEAMABzAFoARwBWADIAYQBX
>> "%~1" echo AE4AbABPAGwAcwBuADYASwA2ACsANQBhAFMASAA1AEwAKwBoADUAbwBHAHYASgB5
>> "%~1" echo AHcAbgA1ADcATwA3ADUANwB1AGYANAA0AEMAQgBWAG0AbAB5AGQASABWAGgAYgBD
>> "%~1" echo AEIARQBaAFgATgByAGQARwA5AHcANAA0AEMAQgA1AG8AbQBMADUAcAArAEUANQBa
>> "%~1" echo AEsATQA1ADUAUwAxADUAcgBxAFEANQA3AHEALwA1ADcAUwBpAEoAMQAwAHMAYwAy
>> "%~1" echo AFYAMABkAEcAbAB1AFoAMwBNADYAVwB5AGYAcABxADUAagBuAHUAcQBjAGcAYwAy
>> "%~1" echo AFYAMABkAEcAbAB1AFoAMwBNAG4ATABDAGYAbwBzAEsAagBtAGgAWQA3AGwAaABw
>> "%~1" echo AG4AbABoAGEAVQBnAFEAVwA1AGsAYwBtADkAcABaAEMAQgB6AFoAWABSADAAYQBX
>> "%~1" echo ADUAbgBjAHkARABtAGkASgBiAGwAdQBiAC8AbQBrAHEAMABuAFgAUwB4AHMAYgAy
>> "%~1" echo AGQAegBPAGwAcwBuADUAcABlAGwANQBiACsAWABKAHkAdwBuADUAcAB5AEEANgBM
>> "%~1" echo ACsAUgA1AEwAaQBBADUAcQB5AGgANQBwAE8ATgA1AEwAMgBjADUANwB1AFQANQBw
>> "%~1" echo ADYAYwBKADEAMQA5AE8AdwBwAGoAYgAyADUAegBkAEMAQgAwAGEARwBWAHQAWgBV
>> "%~1" echo AHQAbABlAFQAMABuAGMAWABWAGwAYwAzAFIAQgBaAEcASgBVAGEARwBWAHQAWgBW
>> "%~1" echo AFkAMwBKAHoAcwBLAFkAMgA5AHUAYwAzAFEAZwBZADIAOQB1AFoAbQBsAHkAYgBW
>> "%~1" echo AFIAbABlAEgAUQA5AGUAdwBvAGcASQBHAFIAbABZAG4AVgBuAFgAMgAxAHYAWgBH
>> "%~1" echo AFUANgBKACsAUwA4AG0AdQBXADgAZwBPAFcAUQByACsAUwAvAG4AZQBhAE0AZwBl
>> "%~1" echo AFcAVQBwAE8AbQBHAGsAdQBPAEEAZwBWAGQAcABMAFUAWgBwAEkATwBTADQAagBl
>> "%~1" echo AFMAOABrAGUAZQBjAG8ATwBPAEEAZwBUAEkAMABJAE8AVwB3AGoAKwBhAFgAdAB1
>> "%~1" echo AFcAeABqACsAVwA1AGwAZQBXAFMAagBDAEIAdwBjAG0AOQA0AFgAMgBOAHMAYgAz
>> "%~1" echo AE4AbAA3ADcAeQBNADUAWQArAHEANQBiAHUANgA2AEsANgB1ADUANQArAHQANQBw
>> "%~1" echo AGUAMgA2AFoAZQAwADYATABDAEQANgBLACsAVgA0ADQAQwBDAEoAeQB3AEsASQBD
>> "%~1" echo AEIAcgBaAFcAVgB3AFgAMgBGADMAWQBXAHQAbABPAGkAZgBrAHYASgByAGwAaABw
>> "%~1" echo AG4AbABoAGEAWABrAHYANQAzAG0AagBJAEgAbABsAEsAVABwAGgAcABMAGoAZwBJ
>> "%~1" echo AEYAWABhAFMAMQBHAGEAUwBEAGsAdQBJADMAawB2AEoASABuAG4ASwBEAGoAZwBJ
>> "%~1" echo AEUAeQBOAEMARABsAHMASQAvAG0AbAA3AGIAbABzAFkALwBsAHUAWgBYAGoAZwBJ
>> "%~1" echo AEYAegBiAEcAVgBsAGMARgA5ADAAYQBXADEAbABiADMAVgAwAFAAUwAwAHgANwA3
>> "%~1" echo AHkATQA1AGIAbQAyADUAWQArAFIANgBZAEMAQgBJAEgAQgB5AGIAMwBoAGYAWQAy
>> "%~1" echo AHgAdgBjADIAWABqAGcASQBJAG4ATABBAG8AZwBJAEgAZABwAGMAbQBWAHMAWgBY
>> "%~1" echo AE4AegBPAGkAZgBrAHYASgByAGwAdgBJAEQAbABrAEsAOABnAE4AVABVADEATgBT
>> "%~1" echo AEQAbQBsADYARABuAHUAcgA4AGcAUQBVAFIAQwA3ADcAeQBNADUAWgBDAE0ANQBM
>> "%~1" echo AGkAQQA1AGIARwBBADUAWgArAGYANQA3ADIAUgA1AFkAYQBGADUAWQArAHYANgBJ
>> "%~1" echo AE8AOQA2AEsASwByADYATAArAGUANQBvADYAbAA0ADQAQwBDADUANQBTAG8ANQBh
>> "%~1" echo ADYATQA2AEsAKwAzADUAWQBXAHoANgBaAGUAdAA1AHAAZQBnADUANwBxAC8ASQBF
>> "%~1" echo AEYARQBRAHUATwBBAGcAaQBjAHMAQwBpAEEAZwBkADIAbAB5AFoAVwB4AGwAYwAz
>> "%~1" echo AE4AZgBiADIAWgBtAE8AaQBmAGsAdgBKAHIAbwByAHEAawBnAFkAVwBSAGkAWgBD
>> "%~1" echo AEQAbABpAEkAZgBsAG0ANQA0AGcAVgBWAE4AQwA3ADcAeQBiADUAYQBhAEMANQBw
>> "%~1" echo ADYAYwA1AGIAMgBUADUAWQBtAE4ANgBaADIAZwBJAEYAZABwAEwAVQBaAHAASQBP
>> "%~1" echo AGkALwBuAHUAYQBPAHAAZQArADgAagBPAGEAVwByAGUAVwA4AGcATwBXAHgAbgB1
>> "%~1" echo AFMANgBqAHUAYQB0AG8AKwBXADQAdQBPAGUATwBzAE8AaQB4AG8AZQBPAEEAZwBp
>> "%~1" echo AGMAcwBDAGkAQQBnAGMAMgBOAHkAWgBXAFYAdQBYAHoASQAwAGEARABvAG4ANQBM
>> "%~1" echo AHkAYQA1AG8AcQBLADUAYgBHAFAANQBiAG0AVgA2AEwAYQBGADUAcABlADIANQBw
>> "%~1" echo AFMANQA1AEwAaQA2AEkARABJADAASQBPAFcAdwBqACsAYQBYAHQAdQArADgAagBP
>> "%~1" echo AFcAUAByACsAaQBEAHYAZQBXAHYAdgBPAGkASAB0AE8AVwBrAHQATwBhAFkAdgB1
>> "%~1" echo AG0AVgB2ACsAYQBYAHQAdQBtAFgAdABPAFMANABqAGUAZQBHAGgATwBXAHgAagAr
>> "%~1" echo AE8AQQBnAGkAYwBzAEMAaQBBAGcAYwAzAFIAaABlAFYAOQAxAGMAMgBKAGYAWQBX
>> "%~1" echo AE0ANgBKACsAUwA4AG0AdQBpAHUAcQBTAEIAVgBVADAASQB2AFEAVQBNAGcANQBv
>> "%~1" echo ACsAUwA1ADUAUwAxADUAcABlADIANQBMACsAZAA1AG8AeQBCADUAWgBTAGsANgBZ
>> "%~1" echo AGEAUwA0ADQAQwBDAEoAeQB3AEsASQBDAEIAdwBjAG0AOQA0AFgAMgBOAHMAYgAz
>> "%~1" echo AE4AbABPAGkAZgBrAHYASgByAG0AcQBLAEgAbQBpADUALwBrAHYAYQBuAG0AaQBM
>> "%~1" echo AFQAcABuAGEARABvAHYANQBIAHYAdgBJAHoAbABqADYALwBvAGcANwAzAHAAbQBM
>> "%~1" echo AHYAbQByAGEATABvAGgANgByAGwAaQBxAGoAbgBoAG8AVABsAHMAWQAvAGoAZwBJ
>> "%~1" echo AEkAbgBMAEEAbwBnAEkASABKAGwAYwAzAFIAdgBjAG0AVgBmAFkAbQBGAGoAYQAz
>> "%~1" echo AFYAdwBPAGkAZgBrAHYASgByAG0AaQBvAHIAcABwAHAAYgBtAHIASwBIAGwAaABw
>> "%~1" echo AG4AbABoAGEAWABsAGkAWQAzAGwAcABJAGYAawB1ADcAMwBsAGcATAB6AG0AZwBh
>> "%~1" echo AEwAbABwAEkAMwBsAG0ANQA0AGcAVQBYAFYAbABjADMAVAB2AHYASQB6AGwAdQBi
>> "%~1" echo AGIAbABqADUASABwAGcASQBFAGcAYwBIAEoAdgBlAEYAOQB2AGMARwBWAHUANAA0
>> "%~1" echo AEMAQwBKAHkAdwBLAEkAQwBCAGoAZABYAE4AMABiADIAMQBmAGMAMgBWADAAZABH
>> "%~1" echo AGwAdQBaAHoAbwBuADUATAB5AGEANQA1AHUAMAA1AG8ANgBsADUAWQBhAFoASQBF
>> "%~1" echo AEYAdQBaAEgASgB2AGEAVwBRAGcAYwAyAFYAMABkAEcAbAB1AFoAMwBQAGoAZwBJ
>> "%~1" echo AEwAcABsAEoAbgBvAHIANgAvAHAAbABLADcAbABnAEwAegBsAGoANgAvAG8AZwA3
>> "%~1" echo ADMAbAB2AGIASABsAGsANAAzAGsAdgBKAEgAbgBuAEsARABqAGcASQBIAG4AdgBa
>> "%~1" echo AEgAbgB1ADUAegBtAGkASgBiAG8AcwBJAFAAbwByADUAWABqAGcASQBJAG4ATABB
>> "%~1" echo AG8AZwBJAEcATgAxAGMAMwBSAHYAYgBWADkAaQBjAG0AOQBoAFoARwBOAGgAYwAz
>> "%~1" echo AFEANgBKACsAUwA4AG0AdQBXAFAAawBlAG0AQQBnAGUAaQBIAHEAdQBXAHUAbQB1
>> "%~1" echo AFMANQBpAFMAQgBCAGIAbQBSAHkAYgAyAGwAawBJAE8AVwA1AHYAKwBhAFMAcgBl
>> "%~1" echo ACsAOABqAE8AVwBQAHEAdQBXADcAdQB1AGkAdQByAHUAUwA5AG8ATwBhAFkAagB1
>> "%~1" echo AGUAaAByAHUAZQBmAHAAZQBtAEIAawB5AEIAaABZADMAUgBwAGIAMgA0AGcANQBa
>> "%~1" echo AEMAcgA1AEwAbQBKADUAcABlADIANQBMADIALwA1ADUAUwBvADQANABDAEMASgB3
>> "%~1" echo AHAAOQBPAHcAcABqAGIAMgA1AHoAZABDAEIAdwBZAFgASgBoAGIAVQBSAGwAWgBu
>> "%~1" echo AE0AOQBXAHcAbwBnAEkASAB0AHIAWgBYAGsANgBKADMATgAwAFkAWABsAFAAYgBp
>> "%~1" echo AGMAcwBiAG0ARgB0AFoAVABvAG4ANQBMACsAZAA1AG8AeQBCADUAWgBTAGsANgBZ
>> "%~1" echo AGEAUwBKAHkAeAB6AFoAWABSADAAYQBXADUAbgBPAGkAZABuAGIARwA5AGkAWQBX
>> "%~1" echo AHcAdQBjADMAUgBoAGUAVgA5AHYAYgBsADkAMwBhAEcAbABzAFoAVgA5AHcAYgBI
>> "%~1" echo AFYAbgBaADIAVgBrAFgAMgBsAHUASgB5AHgAegBZAFcAWgBsAE8AaQBjAHcASgB5
>> "%~1" echo AHgAaABZADMAUgBwAGIAMgA0ADYASgAzAEoAbABjADIAVgAwAFgAMwBOADAAWQBY
>> "%~1" echo AGwAZgBiADIANABuAEwARwA1AHYAZABHAFUANgBKAHoAQQA5ADUAWQBXAEIANgBL
>> "%~1" echo ADYANAA1AHEAMgBqADUAYgBpADQANQBMAHkAUgA1ADUAeQBnADcANwB5AGIATQB6
>> "%~1" echo ADEAVgBVADAASQB2AFEAVQBNAGcANQBvACsAUwA1ADUAUwAxADUATAArAGQANQBv
>> "%~1" echo AHkAQgA1AFoAUwBrADYAWQBhAFMASgAzADAAcwBDAGkAQQBnAGUAMgB0AGwAZQBU
>> "%~1" echo AG8AbgBkADIAbABtAGEAVgBOAHMAWgBXAFYAdwBKAHkAeAB1AFkAVwAxAGwATwBp
>> "%~1" echo AGQAWABhAFMAMQBHAGEAUwBEAGsAdgBKAEgAbgBuAEsARABuAHIAWgBiAG4AbABh
>> "%~1" echo AFUAbgBMAEgATgBsAGQASABSAHAAYgBtAGMANgBKADIAZABzAGIAMgBKAGgAYgBD
>> "%~1" echo ADUAMwBhAFcAWgBwAFgAMwBOAHMAWgBXAFYAdwBYADMAQgB2AGIARwBsAGoAZQBT
>> "%~1" echo AGMAcwBjADIARgBtAFoAVABvAG4ATQBTAGMAcwBZAFcATgAwAGEAVwA5AHUATwBp
>> "%~1" echo AGQAeQBaAFgATgBsAGQARgA5ADMAYQBXAFoAcABYADMATgBzAFoAVwBWAHcASgB5
>> "%~1" echo AHgAdQBiADMAUgBsAE8AaQBjAHgAUABlAFMALwBuAGUAVwB1AGkATwBtADcAbQBP
>> "%~1" echo AGkAdQBwAE8AKwA4AG0AegBJADkANQBwAGUAbgA1ADQAbQBJADUAcgBDADQANQBM
>> "%~1" echo AGkATgA1AEwAeQBSADUANQB5AGcASgAzADAAcwBDAGkAQQBnAGUAMgB0AGwAZQBU
>> "%~1" echo AG8AbgBjADIATgB5AFoAVwBWAHUAVAAyAFoAbQBKAHkAeAB1AFkAVwAxAGwATwBp
>> "%~1" echo AGYAbABzAFkALwBsAHUAWgBYAG8AdABvAFgAbQBsADcAWQBuAEwASABOAGwAZABI
>> "%~1" echo AFIAcABiAG0AYwA2AEoAMwBOADUAYwAzAFIAbABiAFMANQB6AFkAMwBKAGwAWgBX
>> "%~1" echo ADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgAUQBuAEwASABOAGgAWgBt
>> "%~1" echo AFUANgBKAHoATQB3AE0ARABBAHcATQBDAGMAcwBZAFcATgAwAGEAVwA5AHUATwBp
>> "%~1" echo AGQAeQBaAFgATgBsAGQARgA5AHoAWQAzAEoAbABaAFcANQBmAGIAMgBaAG0ASgB5
>> "%~1" echo AHgAdQBiADMAUgBsAE8AaQBmAGwAagBaAFgAawB2AFkAMwBtAHIANgB2AG4AcAA1
>> "%~1" echo AEwAdgB2AEoAcwB6AE0ARABBAHcATQBEAEEAOQBOAFMARABsAGkASQBiAHAAawBw
>> "%~1" echo AC8AdgB2AEkAdwA0AE4AagBRAHcATQBEAEEAdwBNAEQAMAB5AE4AQwBEAGwAcwBJ
>> "%~1" echo AC8AbQBsADcAWQBuAGYAUwB3AEsASQBDAEIANwBhADIAVgA1AE8AaQBkAHoAYgBH
>> "%~1" echo AFYAbABjAEYAUgBwAGIAVwBWAHYAZABYAFEAbgBMAEcANQBoAGIAVwBVADYASgAr
>> "%~1" echo AGUAegB1ACsAZQA3AG4AKwBlAGQAbwBlAGUAYwBvAE8AaQAyAGgAZQBhAFgAdABp
>> "%~1" echo AGMAcwBjADIAVgAwAGQARwBsAHUAWgB6AG8AbgBjADIAVgBqAGQAWABKAGwATABu
>> "%~1" echo AE4AcwBaAFcAVgB3AFgAMwBSAHAAYgBXAFYAdgBkAFgAUQBuAEwASABOAGgAWgBt
>> "%~1" echo AFUANgBKADIANQAxAGIARwB3AG4ATABHAEYAagBkAEcAbAB2AGIAagBvAG4AYwBt
>> "%~1" echo AFYAegBaAFgAUgBmAGMAMgB4AGwAWgBYAEIAZgBkAEcAbAB0AFoAVwA5ADEAZABD
>> "%~1" echo AGMAcwBiAG0AOQAwAFoAVABvAG4AYgBuAFYAcwBiAEQAMwBuAHMANwB2AG4AdQA1
>> "%~1" echo AC8AcAB1ADUAagBvAHIAcQBUAHYAdgBKAHMAdABNAFQAMwBrAHUASQAzAG8AaAA2
>> "%~1" echo AHIAbABpAHEAagBuAG4AYQBIAG4AbgBLAEEAbgBmAFEAcABkAE8AdwBwAHMAWgBY
>> "%~1" echo AFEAZwBiAEcARgB6AGQARAAxADcAZgBTAHgAaQBkAFgATgA1AFAAVwBaAGgAYgBI
>> "%~1" echo AE4AbABMAEgAQgBsAGIAbQBSAHAAYgBtAGQARABiADIANQBtAGEAWABKAHQAUABX
>> "%~1" echo ADUAMQBiAEcAdwBzAFkAWABCAHIAUABXADUAMQBiAEcAdwA3AEMAbQBaADEAYgBt
>> "%~1" echo AE4AMABhAFcAOQB1AEkARwBWAHoAWQB5AGgAegBLAFgAdAB5AFoAWABSADEAYwBt
>> "%~1" echo ADQAZwBVADMAUgB5AGEAVwA1AG4ASwBIAE0ALwBQAHkAYwBuAEsAUwA1AHkAWgBY
>> "%~1" echo AEIAcwBZAFcATgBsAEsAQwA5AGIASgBqAHcAKwBJAGkAZABkAEwAMgBjAHMAWQB6
>> "%~1" echo ADAAKwBLAEgAcwBuAEoAaQBjADYASgB5AFoAaABiAFgAQQA3AEoAeQB3AG4AUABD
>> "%~1" echo AGMANgBKAHkAWgBzAGQARABzAG4ATABDAGMAKwBKAHoAbwBuAEoAbQBkADAATwB5
>> "%~1" echo AGMAcwBKAHkASQBuAE8AaQBjAG0AYwBYAFYAdgBkAEQAcwBuAEwAQwBJAG4ASQBq
>> "%~1" echo AG8AbgBKAGkATQB6AE8AVABzAG4AZgBWAHQAagBYAFMAawBwAGYAUQBwAG0AZABX
>> "%~1" echo ADUAagBkAEcAbAB2AGIAaQBCAGwAYgBYAEIAMABlAFMAaAAyAEsAWAB0AHkAWgBY
>> "%~1" echo AFIAMQBjAG0ANABnAGQAagAwADkAUABYAFYAdQBaAEcAVgBtAGEAVwA1AGwAWgBI
>> "%~1" echo AHgAOABkAGoAMAA5AFAAVwA1ADEAYgBHAHgAOABmAEgAWQA5AFAAVAAwAG4ASgAz
>> "%~1" echo AHgAOABkAGoAMAA5AFAAUwBkAHUAZABXAHgAcwBKADMAMABLAFoAbgBWAHUAWQAz
>> "%~1" echo AFIAcABiADIANABnAGMAMgBoAHYAZAAyADQAbwBkAGkAbAA3AGMAbQBWADAAZABY
>> "%~1" echo AEoAdQBJAEcAVgB0AGMASABSADUASwBIAFkAcABQAHkAYwB0AEoAegBwAFQAZABI
>> "%~1" echo AEoAcABiAG0AYwBvAGQAaQBsADkAQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBI
>> "%~1" echo AE4AbABkAEMAaABwAFoAQwB4ADIASwBYAHQAagBiADIANQB6AGQAQwBCAGwAUABT
>> "%~1" echo AFEAbwBhAFcAUQBwAE8AMgBsAG0ASwBHAFUAcABaAFMANQAwAFoAWABoADAAUQAy
>> "%~1" echo ADkAdQBkAEcAVgB1AGQARAAxAHoAYQBHADkAMwBiAGkAaAAyAEsAWAAwAEsAWgBu
>> "%~1" echo AFYAdQBZADMAUgBwAGIAMgA0AGcAZABpAGgAcgBLAFgAdAB5AFoAWABSADEAYwBt
>> "%~1" echo ADQAZwBjADIAaAB2AGQAMgA0AG8AYgBHAEYAegBkAEYAdAByAFgAUwBrADcAZgBR
>> "%~1" echo AHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAdQBiADMAUgBwAFoAbgBrAG8AZABH
>> "%~1" echo AGwAMABiAEcAVQBzAGIAWABOAG4ATABIAFIANQBjAEcAVQA5AEoAMgA5AHIASgB5
>> "%~1" echo AHgAdABjAHoAMAB6AE0AagBBAHcASwBYAHQAagBiADIANQB6AGQAQwBCAG8AYgAz
>> "%~1" echo AE4AMABQAFMAUQBvAEoAMwBSAHYAWQBYAE4AMABjAHkAYwBwAE8AMgBsAG0ASwBD
>> "%~1" echo AEYAbwBiADMATgAwAEsAWABKAGwAZABIAFYAeQBiAGoAdABqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAbABiAEQAMQBrAGIAMgBOADEAYgBXAFYAdQBkAEMANQBqAGMAbQBWAGgAZABH
>> "%~1" echo AFYARgBiAEcAVgB0AFoAVwA1ADAASwBDAGQAawBhAFgAWQBuAEsAVAB0AGwAYgBD
>> "%~1" echo ADUAagBiAEcARgB6AGMAMAA1AGgAYgBXAFUAOQBKADMAUgB2AFkAWABOADAASQBD
>> "%~1" echo AGMAcgBkAEgAbAB3AFoAVAB0AGwAYgBDADUAcABiAG0ANQBsAGMAawBoAFUAVABV
>> "%~1" echo AHcAOQBKAHoAeABpAFAAaQBjAHIAWgBYAE4AagBLAEgAUgBwAGQARwB4AGwASwBT
>> "%~1" echo AHMAbgBQAEMAOQBpAFAAagB4AHoAYwBHAEYAdQBQAGkAYwByAFoAWABOAGoASwBH
>> "%~1" echo ADEAegBaADMAeAA4AEoAeQBjAHAASwB5AGMAOABMADMATgB3AFkAVwA0ACsASgB6
>> "%~1" echo AHQAbwBiADMATgAwAEwAbQBGAHcAYwBHAFYAdQBaAEUATgBvAGEAVwB4AGsASwBH
>> "%~1" echo AFYAcwBLAFQAdAB5AFoAWABGADEAWgBYAE4AMABRAFcANQBwAGIAVwBGADAAYQBX
>> "%~1" echo ADkAdQBSAG4ASgBoAGIAVwBVAG8ASwBDAGsAOQBQAG0AVgBzAEwAbQBOAHMAWQBY
>> "%~1" echo AE4AegBUAEcAbAB6AGQAQwA1AGgAWgBHAFEAbwBKADMATgBvAGIAMwBjAG4ASwBT
>> "%~1" echo AGsANwBjADIAVgAwAFYARwBsAHQAWgBXADkAMQBkAEMAZwBvAEsAVAAwACsAZQAy
>> "%~1" echo AFYAcwBMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMANQB5AFoAVwAxAHYAZABt
>> "%~1" echo AFUAbwBKADMATgBvAGIAMwBjAG4ASwBUAHQAegBaAFgAUgBVAGEAVwAxAGwAYgAz
>> "%~1" echo AFYAMABLAEMAZwBwAFAAVAA1AGwAYgBDADUAeQBaAFcAMQB2AGQAbQBVAG8ASwBT
>> "%~1" echo AHcAeQBNAGoAQQBwAGYAUwB4AHQAYwB5AGwAOQBDAG0AWgAxAGIAbQBOADAAYQBX
>> "%~1" echo ADkAdQBJAEgATgBvAGIAMwBkAEQAYgAyADUAbQBhAFgASgB0AEsARwBGAGoAZABH
>> "%~1" echo AGwAdgBiAGkAeABzAFkAVwBKAGwAYgBDAHgAbABlAEgAUgB5AFkAVAAwAG4ASgB5
>> "%~1" echo AGwANwBjAEcAVgB1AFoARwBsAHUAWgAwAE4AdgBiAG0AWgBwAGMAbQAwADkAZQAy
>> "%~1" echo AEYAagBkAEcAbAB2AGIAaQB4AHMAWQBXAEoAbABiAEMAeABsAGUASABSAHkAWQBY
>> "%~1" echo ADAANwBKAEMAZwBuAFkAMgA5AHUAWgBtAGwAeQBiAFYAUgBwAGQARwB4AGwASgB5
>> "%~1" echo AGsAdQBkAEcAVgA0AGQARQBOAHYAYgBuAFIAbABiAG4AUQA5AEoAKwBlAGgAcgB1
>> "%~1" echo AGkAdQBwAE8AYQBKAHAAKwBpAGgAagBPACsAOABtAGkAYwByAGIARwBGAGkAWgBX
>> "%~1" echo AHcANwBKAEMAZwBuAFkAMgA5AHUAWgBtAGwAeQBiAFUAMQB6AFoAeQBjAHAATABu
>> "%~1" echo AFIAbABlAEgAUgBEAGIAMgA1ADAAWgBXADUAMABQAFcATgB2AGIAbQBaAHAAYwBt
>> "%~1" echo ADEAVQBaAFgAaAAwAFcAMgBGAGoAZABHAGwAdgBiAGwAMQA4AGYAQwBmAG8AdgA1
>> "%~1" echo AG4AawB1AEsAcgBtAGsANAAzAGsAdgBaAHoAawB2AEoAcgBrAHYANgA3AG0AbABM
>> "%~1" echo AGsAZwBVAFgAVgBsAGMAMwBRAGcANQA0AHEAMgA1AG8AQwBCADQANABDAEMASgB6
>> "%~1" echo AHMAawBLAEMAZABqAGIAMgA1AG0AYQBYAEoAdABUAFcARgB6AGEAeQBjAHAATABt
>> "%~1" echo AE4AcwBZAFgATgB6AFQARwBsAHoAZABDADUAaABaAEcAUQBvAEoAMwBOAG8AYgAz
>> "%~1" echo AGMAbgBLAFgAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAFkAWABOAHIAUQAy
>> "%~1" echo ADkAdQBaAG0AbAB5AGIAUwBoADAAYQBYAFIAcwBaAFMAeAB0AGMAMgBjAHAAZQAz
>> "%~1" echo AEoAbABkAEgAVgB5AGIAaQBCAHUAWgBYAGMAZwBVAEgASgB2AGIAVwBsAHoAWgBT
>> "%~1" echo AGgAeQBaAFgATQA5AFAAbgB0AHcAWgBXADUAawBhAFcANQBuAFEAMgA5AHUAWgBt
>> "%~1" echo AGwAeQBiAFQAMQA3AFkAMwBWAHoAZABHADkAdABPAG4AUgB5AGQAVwBVAHMAYwBt
>> "%~1" echo AFYAegBiADIAeAAyAFoAVABwAHkAWgBYAE4AOQBPAHkAUQBvAEoAMgBOAHYAYgBt
>> "%~1" echo AFoAcABjAG0AMQBVAGEAWABSAHMAWgBTAGMAcABMAG4AUgBsAGUASABSAEQAYgAy
>> "%~1" echo ADUAMABaAFcANQAwAFAAWABSAHAAZABHAHgAbABPAHkAUQBvAEoAMgBOAHYAYgBt
>> "%~1" echo AFoAcABjAG0AMQBOAGMAMgBjAG4ASwBTADUAMABaAFgAaAAwAFEAMgA5AHUAZABH
>> "%~1" echo AFYAdQBkAEQAMQB0AGMAMgBjADcASgBDAGcAbgBZADIAOQB1AFoAbQBsAHkAYgBV
>> "%~1" echo ADEAaABjADIAcwBuAEsAUwA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAWQBX
>> "%~1" echo AFIAawBLAEMAZAB6AGEARwA5ADMASgB5AGwAOQBLAFgAMABLAFoAbgBWAHUAWQAz
>> "%~1" echo AFIAcABiADIANABnAFkAMgB4AHYAYwAyAFYARABiADIANQBtAGEAWABKAHQASwBD
>> "%~1" echo AGwANwBZADIAOQB1AGMAMwBRAGcAYwBEADEAdwBaAFcANQBrAGEAVwA1AG4AUQAy
>> "%~1" echo ADkAdQBaAG0AbAB5AGIAVAB0AHcAWgBXADUAawBhAFcANQBuAFEAMgA5AHUAWgBt
>> "%~1" echo AGwAeQBiAFQAMQB1AGQAVwB4AHMATwB5AFEAbwBKADIATgB2AGIAbQBaAHAAYwBt
>> "%~1" echo ADEATgBZAFgATgByAEoAeQBrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABu
>> "%~1" echo AEoAbABiAFcAOQAyAFoAUwBnAG4AYwAyAGgAdgBkAHkAYwBwAE8AMgBsAG0ASwBI
>> "%~1" echo AEEAbQBKAG4AQQB1AFkAMwBWAHoAZABHADkAdABKAGkAWgB3AEwAbgBKAGwAYwAy
>> "%~1" echo ADkAcwBkAG0AVQBwAGMAQwA1AHkAWgBYAE4AdgBiAEgAWgBsAEsARwBaAGgAYgBI
>> "%~1" echo AE4AbABLAFgAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGQARwBoAGwAYgBX
>> "%~1" echo AFUAbwBLAFgAdABqAGIAMgA1AHoAZABDAEIAcwBhAFcAZABvAGQARAAxAHMAYgAy
>> "%~1" echo AE4AaABiAEYATgAwAGIAMwBKAGgAWgAyAFUAdQBaADIAVgAwAFMAWABSAGwAYgBT
>> "%~1" echo AGgAMABhAEcAVgB0AFoAVQB0AGwAZQBTAGsAOQBQAFQAMABuAGIARwBsAG4AYQBI
>> "%~1" echo AFEAbgBPADIAUgB2AFkAMwBWAHQAWgBXADUAMABMAG0ASgB2AFoASABrAHUAWQAy
>> "%~1" echo AHgAaABjADMATgBNAGEAWABOADAATABuAFIAdgBaADIAZABzAFoAUwBnAG4AWgBH
>> "%~1" echo AEYAeQBhAHkAYwBzAEkAVwB4AHAAWgAyAGgAMABLAFQAcwBrAEsAQwBkADAAYQBH
>> "%~1" echo AFYAdABaAFUASgAwAGIAaQBjAHAATABuAFIAbABlAEgAUgBEAGIAMgA1ADAAWgBX
>> "%~1" echo ADUAMABQAFcAeABwAFoAMgBoADAAUAB5AGYAbQB0ADcASABvAGkAYgBJAG4ATwBp
>> "%~1" echo AGYAbQB0AFkAWABvAGkAYgBJAG4AZgBRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBp
>> "%~1" echo AEIAcwBiADIAYwBvAGQAQwBsADcAYwAyAFYAMABLAEMAZABzAGIAMgBkAEMAYgAz
>> "%~1" echo AGcAbgBMAEcANQBsAGQAeQBCAEUAWQBYAFIAbABLAEMAawB1AGQARwA5AE0AYgAy
>> "%~1" echo AE4AaABiAEcAVgBVAGEAVwAxAGwAVQAzAFIAeQBhAFcANQBuAEsAQwBrAHIASgB5
>> "%~1" echo AEEAZwBKAHkAdAAwAEsAWAAwAEsAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAYwAy
>> "%~1" echo AGgAdgBjAG4AUgBRAFkAWABSAG8ASwBIAEEAcABlADIAbABtAEsAQwBGAHcASwBY
>> "%~1" echo AEoAbABkAEgAVgB5AGIAaQBkAGgAWgBHAEkAdQBaAFgAaABsAEoAegB0AGoAYgAy
>> "%~1" echo ADUAegBkAEMAQgBoAFAAVgBOADAAYwBtAGwAdQBaAHkAaAB3AEsAUwA1AHoAYwBH
>> "%~1" echo AHgAcABkAEMAZwB2AFcAMQB4AGMATAAxADAAdgBLAFQAdAB5AFoAWABSADEAYwBt
>> "%~1" echo ADQAZwBZAFYAdABoAEwAbQB4AGwAYgBtAGQAMABhAEMAMAB4AFgAWAB4ADgAYwBI
>> "%~1" echo ADAASwBaAG4AVgB1AFkAMwBSAHAAYgAyADQAZwBjAEcATgAwAEsASABnAHMAYgBX
>> "%~1" echo AEYANABQAFQARQB3AE0AQwBsADcAWQAyADkAdQBjADMAUQBnAGIAagAxAHcAWQBY
>> "%~1" echo AEoAegBaAFUAWgBzAGIAMgBGADAASwBIAGcAcABPADMASgBsAGQASABWAHkAYgBp
>> "%~1" echo AEIAcABjADAAWgBwAGIAbQBsADAAWgBTAGgAdQBLAFQAOQBOAFkAWABSAG8ATABt
>> "%~1" echo ADEAaABlAEMAZwB3AEwARQAxAGgAZABHAGcAdQBiAFcAbAB1AEsARABFAHcATQBD
>> "%~1" echo AHgAdQBMADIAMQBoAGUAQwBvAHgATQBEAEEAcABLAFQAbwB3AGYAUQBwAG0AZABX
>> "%~1" echo ADUAagBkAEcAbAB2AGIAaQBCAHkAYQBXADUAbgBLAEcAbABrAEwASABSAGwAZQBI
>> "%~1" echo AFEAcwBiAEcARgBpAFoAVwB3AHMAYwBHAFYAeQBZADIAVgB1AGQAQwB4AGoAYgBI
>> "%~1" echo AE0AcABlADIATgB2AGIAbgBOADAASQBHAEoAdgBlAEQAMABrAEsARwBsAGsASwBU
>> "%~1" echo AHQAcABaAGkAZwBoAFkAbQA5ADQASwBYAEoAbABkAEgAVgB5AGIAagB0AGkAYgAz
>> "%~1" echo AGcAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4AMABMAG4ASgBsAGIAVwA5ADIAWgBT
>> "%~1" echo AGcAbgBaADMASgBsAFoAVwA0AG4ATABDAGQAaABiAFcASgBsAGMAaQBjAHMASgAz
>> "%~1" echo AEoAbABaAEMAYwBwAE8AMgBsAG0ASwBHAE4AcwBjAHkAbABpAGIAMwBnAHUAWQAy
>> "%~1" echo AHgAaABjADMATgBNAGEAWABOADAATABtAEYAawBaAEMAaABqAGIASABNAHAATwAy
>> "%~1" echo AE4AdgBiAG4ATgAwAEkARwAxAGwAZABHAFYAeQBQAFcASgB2AGUAQwA1AHgAZABX
>> "%~1" echo AFYAeQBlAFYATgBsAGIARwBWAGoAZABHADkAeQBLAEMAYwB1AGIAVwBWADAAWgBY
>> "%~1" echo AEkAbgBLAFQAdABwAFoAaQBoAHQAWgBYAFIAbABjAGkAbAB0AFoAWABSAGwAYwBp
>> "%~1" echo ADUAegBaAFgAUgBCAGQASABSAHkAYQBXAEoAMQBkAEcAVQBvAEoAMwBOADAAYwBt
>> "%~1" echo ADkAcgBaAFMAMQBrAFkAWABOAG8AWQBYAEoAeQBZAFgAawBuAEwAQwBoAHcAWgBY
>> "%~1" echo AEoAagBaAFcANQAwAGYASAB3AHcASwBTAHMAbgBJAEQARQB3AE0AQwBjAHAATwAy
>> "%~1" echo AGwAbQBLAEcAbABrAFAAVAAwADkASgAyAEoAaABkAEgAUgBsAGMAbgBsAEgAWQBY
>> "%~1" echo AFYAbgBaAFMAYwBwAGUAMwBOAGwAZABDAGcAbgBZAG0ARgAwAGQARwBWAHkAZQBW
>> "%~1" echo AFIAbABlAEgAUQBuAEwASABSAGwAZQBIAFEAcABPADMATgBsAGQAQwBnAG4AWQBt
>> "%~1" echo AEYAMABkAEcAVgB5AGUAVgBOADEAWQBpAGMAcwBiAEcARgBpAFoAVwB3AHAAZgBX
>> "%~1" echo AGwAbQBLAEcAbABrAFAAVAAwADkASgAzAFIAbABiAFgAQgBIAFkAWABWAG4AWgBT
>> "%~1" echo AGMAcABlADMATgBsAGQAQwBnAG4AZABHAFYAdABjAEYAUgBsAGUASABRAG4ATABI
>> "%~1" echo AFIAbABlAEgAUQBwAE8AMwBOAGwAZABDAGcAbgBkAEcAVgB0AGMARgBOADEAWQBp
>> "%~1" echo AGMAcwBiAEcARgBpAFoAVwB3AHAAZgBXAGwAbQBLAEcAbABrAFAAVAAwADkASgAz
>> "%~1" echo AE4AcwBaAFcAVgB3AFIAMgBGADEAWgAyAFUAbgBLAFgAdAB6AFoAWABRAG8ASgAz
>> "%~1" echo AE4AcwBaAFcAVgB3AFYARwBWADQAZABDAGMAcwBkAEcAVgA0AGQAQwBrADcAYwAy
>> "%~1" echo AFYAMABLAEMAZAB6AGIARwBWAGwAYwBGAE4AMQBZAGkAYwBzAGIARwBGAGkAWgBX
>> "%~1" echo AHcAcABmAFgAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGIAbQA5AHkAYgBT
>> "%~1" echo AGgANABLAFgAdAB5AFoAWABSADEAYwBtADQAZwBjADIAaAB2AGQAMgA0AG8AZQBD
>> "%~1" echo AGsAdQBkAEgASgBwAGIAUwBnAHAAZgBRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBp
>> "%~1" echo AEIAcABjADEATgBoAFoAbQBWAFcAWQBXAHgAMQBaAFMAaABrAFoAVwBZAHMAZABt
>> "%~1" echo AEYAcwBkAFcAVQBwAGUAMgBOAHYAYgBuAE4AMABJAEgAWgBoAGIARAAxAHUAYgAz
>> "%~1" echo AEoAdABLAEgAWgBoAGIASABWAGwASwBUAHQAcABaAGkAaABrAFoAVwBZAHUAYwAy
>> "%~1" echo AEYAbQBaAFQAMAA5AFAAUwBkAHUAZABXAHgAcwBKAHkAbAB5AFoAWABSADEAYwBt
>> "%~1" echo ADQAZwBkAG0ARgBzAFAAVAAwADkASgAyADUAMQBiAEcAdwBuAGYASAB4ADIAWQBX
>> "%~1" echo AHcAOQBQAFQAMABuAEwAUwBjADcAYwBtAFYAMABkAFgASgB1AEkASABaAGgAYgBE
>> "%~1" echo ADAAOQBQAFcAUgBsAFoAaQA1AHoAWQBXAFoAbABmAFEAcABtAGQAVwA1AGoAZABH
>> "%~1" echo AGwAdgBiAGkAQgB5AFoAVwA1AGsAWgBYAEoAUQBZAFgASgBoAGIAWABNAG8ASwBY
>> "%~1" echo AHQAagBiADIANQB6AGQAQwBCAG8AYgAzAE4AMABQAFMAUQBvAEoAMwBCAGgAYwBt
>> "%~1" echo AEYAdABUAEcAbAB6AGQAQwBjAHAATwAyAGwAbQBLAEMARgBvAGIAMwBOADAASwBY
>> "%~1" echo AEoAbABkAEgAVgB5AGIAagB0AG8AYgAzAE4AMABMAG0AbAB1AGIAbQBWAHkAUwBG
>> "%~1" echo AFIATgBUAEQAMABuAEoAegB0AHMAWgBYAFEAZwBZADIAaABoAGIAbQBkAGwAWgBE
>> "%~1" echo ADAAdwBPADIATgB2AGIAbgBOADAASQBHADkAbQBaAG0AeABwAGIAbQBVADkAYgBH
>> "%~1" echo AEYAegBkAEMANQBqAGIAMgA1AHUAWgBXAE4AMABaAFcAUQBoAFAAVAAwAG4AZABI
>> "%~1" echo AEoAMQBaAFMAYwA3AGMARwBGAHkAWQBXADEARQBaAFcAWgB6AEwAbQBaAHYAYwBr
>> "%~1" echo AFYAaABZADIAZwBvAFoARwBWAG0AUABUADUANwBZADIAOQB1AGMAMwBRAGcAZABt
>> "%~1" echo AEYAcwBQAFcANQB2AGMAbQAwAG8AYgBHAEYAegBkAEYAdABrAFoAVwBZAHUAYQAy
>> "%~1" echo AFYANQBYAFMAawA3AFkAMgA5AHUAYwAzAFEAZwBiADIAcwA5AEkAVwA5AG0AWgBt
>> "%~1" echo AHgAcABiAG0AVQBtAEoAbQBsAHoAVQAyAEYAbQBaAFYAWgBoAGIASABWAGwASwBH
>> "%~1" echo AFIAbABaAGkAeAAyAFkAVwB3AHAATwAyAGwAbQBLAEMARgB2AGEAeQBZAG0ASQBX
>> "%~1" echo ADkAbQBaAG0AeABwAGIAbQBVAHAAWQAyAGgAaABiAG0AZABsAFoAQwBzAHIATwAy
>> "%~1" echo AE4AdgBiAG4ATgAwAEkARwBsADAAWgBXADAAOQBaAEcAOQBqAGQAVwAxAGwAYgBu
>> "%~1" echo AFEAdQBZADMASgBsAFkAWABSAGwAUgBXAHgAbABiAFcAVgB1AGQAQwBnAG4AWgBH
>> "%~1" echo AGwAMgBKAHkAawA3AGEAWABSAGwAYgBTADUAagBiAEcARgB6AGMAMAA1AGgAYgBX
>> "%~1" echo AFUAOQBKADMAQgBoAGMAbQBGAHQAUwBYAFIAbABiAFMAQQBuAEsAeQBoAHYAWgBt
>> "%~1" echo AFoAcwBhAFcANQBsAFAAeQBjAG4ATwBtADkAcgBQAHkAZAB2AGEAeQBjADYASgAy
>> "%~1" echo AE4AbwBZAFcANQBuAFoAVwBRAG4ASwBUAHQAagBiADIANQB6AGQAQwBCAHoAZABH
>> "%~1" echo AEYAMABaAFQAMQB2AFoAbQBaAHMAYQBXADUAbABQAHkAZgBtAG4ASwByAG8AcgA3
>> "%~1" echo AHYAbABqADUAWQBuAE8AaQBoAHYAYQB6ADgAbgA2AGIAdQBZADYASwA2AGsANQBZ
>> "%~1" echo AEMAOABKAHoAbwBuADUAYgBlAHkANQBMACsAdQA1AHAAUwA1AEoAeQBrADcAYQBY
>> "%~1" echo AFIAbABiAFMANQBwAGIAbQA1AGwAYwBrAGgAVQBUAFUAdwA5AEoAegB4AGsAYQBY
>> "%~1" echo AFkAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABjAG0ARgB0AFQAbQBGAHQAWgBT
>> "%~1" echo AEkAKwBQAEcASQArAEoAeQB0AGwAYwAyAE0AbwBaAEcAVgBtAEwAbQA1AGgAYgBX
>> "%~1" echo AFUAcABLAHkAYwA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAEoAeQB0AGwAYwAy
>> "%~1" echo AE0AbwBaAEcAVgBtAEwAbgBOAGwAZABIAFIAcABiAG0AYwBwAEsAeQBjADgATAAz
>> "%~1" echo AE4AdwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBH
>> "%~1" echo AEYAegBjAHoAMABpAGMARwBGAHkAWQBXADEAVwBZAFcAeAAxAFoAUwBJACsAUABI
>> "%~1" echo AE4AdwBZAFcANAArADUAYgAyAFQANQBZAG0ATgA1AFkAQwA4AFAAQwA5AHoAYwBH
>> "%~1" echo AEYAdQBQAGoAeABpAFAAaQBjAHIAWgBYAE4AagBLAEgAWgBoAGIAQwBrAHIASgB6
>> "%~1" echo AHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBY
>> "%~1" echo AE4AegBQAFMASgB3AFkAWABKAGgAYgBWAFoAaABiAEgAVgBsAEkAagA0ADgAYwAz
>> "%~1" echo AEIAaABiAGoANwBwAHUANQBqAG8AcgBxAFQAbABnAEwAdwA4AEwAMwBOAHcAWQBX
>> "%~1" echo ADQAKwBQAEcASQArAEoAeQB0AGwAYwAyAE0AbwBaAEcAVgBtAEwAbgBOAGgAWgBt
>> "%~1" echo AFUAcABLAHkAYwA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABq
>> "%~1" echo ADQAOABjADMAQgBoAGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMARwBGAHkAWQBX
>> "%~1" echo ADEAVABkAEcARgAwAFoAUwBJACsASgB5AHQAbABjADIATQBvAGMAMwBSAGgAZABH
>> "%~1" echo AFUAcABLAHkAYwA4AEwAMwBOAHcAWQBXADQAKwBJAEMAYwByAEsAQwBGAHYAWgBt
>> "%~1" echo AFoAcwBhAFcANQBsAEoAaQBZAGgAYgAyAHMALwBKAHoAeABpAGQAWABSADAAYgAy
>> "%~1" echo ADQAZwBZADIAeABoAGMAMwBNADkASQBuAEoAbABjADIAVgAwAFEAbgBSAHUASQBI
>> "%~1" echo AEIAeQBhAFcAMQBoAGMAbgBrAGkASQBHAFIAaABkAEcARQB0AGMAbQBWAHoAWgBY
>> "%~1" echo AFEAOQBJAGkAYwByAFoAWABOAGoASwBHAFIAbABaAGkANQBoAFkAMwBSAHAAYgAy
>> "%~1" echo ADQAcABLAHkAYwBpAFAAdQBtAEgAagBlAGUAOQByAGoAdwB2AFkAbgBWADAAZABH
>> "%~1" echo ADkAdQBQAGkAYwA2AEoAeQBjAHAASwB5AGMAOABMADIAUgBwAGQAagA0ADgAWgBH
>> "%~1" echo AGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdwBZAFgASgBoAGIAVQA1AGgAYgBX
>> "%~1" echo AFUAaQBJAEgATgAwAGUAVwB4AGwAUABTAEoAbgBjAG0AbABrAEwAVwBOAHYAYgBI
>> "%~1" echo AFYAdABiAGoAbwB4AEwAeQAwAHgASQBqADQAOABjADMAQgBoAGIAagA0AG4ASwAy
>> "%~1" echo AFYAegBZAHkAaABrAFoAVwBZAHUAYgBtADkAMABaAFMAawByAEoAegB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANAA4AEwAMgBSAHAAZABqADQAbgBPADIAaAB2AGMAMwBRAHUAWQBY
>> "%~1" echo AEIAdwBaAFcANQBrAFEAMgBoAHAAYgBHAFEAbwBhAFgAUgBsAGIAUwBsADkASwBU
>> "%~1" echo AHQAegBaAFgAUQBvAEoAMwBCAGgAYwBtAEYAdABVADMAVgB0AGIAVwBGAHkAZQBT
>> "%~1" echo AGMAcwBiADIAWgBtAGIARwBsAHUAWgBUADgAbgA1AHAAeQBxADYATAArAGUANQBv
>> "%~1" echo ADYAbABKAHoAcABqAGEARwBGAHUAWgAyAFYAawBQADIATgBvAFkAVwA1AG4AWgBX
>> "%~1" echo AFEAcgBKAHkARABwAG8AYgBuAGwAdAA3AEwAawB2ADYANwBtAGwATABrAG4ATwBp
>> "%~1" echo AGYAbABoAGEAagBwAGcANgBqAHAAdQA1AGoAbwByAHEAUQBuAEsAVAB0AG8AYgAz
>> "%~1" echo AE4AMABMAG4ARgAxAFoAWABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBKAEIAYgBH
>> "%~1" echo AHcAbwBKADEAdABrAFkAWABSAGgATABYAEoAbABjADIAVgAwAFgAUwBjAHAATABt
>> "%~1" echo AFoAdgBjAGsAVgBoAFkAMgBnAG8AWQBuAFIAdQBQAFQANQBpAGQARwA0AHUAYgAy
>> "%~1" echo ADUAagBiAEcAbABqAGEAegAwAG8ASwBUADAAKwBZAFcATgAwAGEAVwA5AHUASwBH
>> "%~1" echo AEoAMABiAGkANQBrAFkAWABSAGgAYwAyAFYAMABMAG4ASgBsAGMAMgBWADAATABD
>> "%~1" echo AGMAbgBMAEMAZgBwAGgANAAzAG4AdgBhADcAbABqADQATABtAGwAYgBBAG4ATABH
>> "%~1" echo AEoAMABiAGkAeABtAFkAVwB4AHoAWgBTAGsAcABmAFEAcABoAGMAMwBsAHUAWQB5
>> "%~1" echo AEIAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAaABjAEcAawBvAGMARwBGADAAYQBD
>> "%~1" echo AHgAdgBjAEgAUgB6AFAAWAB0ADkASwBYAHQAagBiADIANQB6AGQAQwBCAHYAUABV
>> "%~1" echo ADkAaQBhAG0AVgBqAGQAQwA1AGgAYwAzAE4AcABaADIANABvAGUAMgBOAGgAWQAy
>> "%~1" echo AGgAbABPAGkAZAB1AGIAeQAxAHoAZABHADkAeQBaAFMAZAA5AEwARwA5AHcAZABI
>> "%~1" echo AE0AcABPADIAOAB1AGEARwBWAGgAWgBHAFYAeQBjAHoAMQBQAFkAbQBwAGwAWQAz
>> "%~1" echo AFEAdQBZAFgATgB6AGEAVwBkAHUASwBIAHMAbgBXAEMAMQBSAGQAVwBWAHoAZABD
>> "%~1" echo ADEAVQBiADIAdABsAGIAaQBjADYAVgBFADkATABSAFUANQA5AEwARwA5AHcAZABI
>> "%~1" echo AE0AdQBhAEcAVgBoAFoARwBWAHkAYwAzAHgAOABlADMAMABwAE8AMgBOAHYAYgBu
>> "%~1" echo AE4AMABJAEgASQA5AFkAWABkAGgAYQBYAFEAZwBaAG0AVgAwAFkAMgBnAG8AYwBH
>> "%~1" echo AEYAMABhAEMAeAB2AEsAVAB0AHAAWgBpAGcAaABjAGkANQB2AGEAeQBsADAAYQBI
>> "%~1" echo AEoAdgBkAHkAQgB1AFoAWABjAGcAUgBYAEoAeQBiADMASQBvAEoAMABoAFUAVgBG
>> "%~1" echo AEEAZwBKAHkAdAB5AEwAbgBOADAAWQBYAFIAMQBjAHkAawA3AGMAbQBWADAAZABY
>> "%~1" echo AEoAdQBJAEcARgAzAFkAVwBsADAASQBIAEkAdQBhAG4ATgB2AGIAaQBnAHAAZgBR
>> "%~1" echo AHAAaABjADMAbAB1AFkAeQBCAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHMAYgAy
>> "%~1" echo AEYAawBUAEcAOQBuAGMAeQBoAHoAYQBHADkAMwBUAG0AOQAwAGEAVwBOAGwAUABX
>> "%~1" echo AFoAaABiAEgATgBsAEsAWAB0ADAAYwBuAGwANwBZADIAOQB1AGMAMwBRAGcAYwBq
>> "%~1" echo ADEAaABkADIARgBwAGQAQwBCAGgAYwBHAGsAbwBKAHkAOQBoAGMARwBrAHYAYgBH
>> "%~1" echo ADkAbgBjAHkAYwBwAE8AMwBOAGwAZABDAGcAbgBiAEcAOQBuAFUARwBGADAAYQBD
>> "%~1" echo AGMAcwBjAGkANQBzAGIAMgBkAEcAYQBXAHgAbABLAFQAdAB6AFoAWABRAG8ASgAy
>> "%~1" echo AHgAdgBaADAASgB2AGUAQwBjAHMAYwBpADUAMABaAFgAaAAwAGYASAB3AG4ANQBw
>> "%~1" echo AHEAQwA1AHAAZQBnADUAcABlAGwANQBiACsAWABKAHkAawA3AGEAVwBZAG8AYwAy
>> "%~1" echo AGgAdgBkADAANQB2AGQARwBsAGoAWgBTAGwAdQBiADMAUgBwAFoAbgBrAG8ASgAr
>> "%~1" echo AGEAWABwAGUAVwAvAGwAKwBXADMAcwB1AFcASQB0ACsAYQBXAHMAQwBjAHMAYwBp
>> "%~1" echo ADUAcwBiADIAZABHAGEAVwB4AGwAZgBIAHcAbgBMAFMAYwBzAEoAMgA5AHIASgB5
>> "%~1" echo AGwAOQBZADIARgAwAFkAMgBnAG8AWgBTAGwANwBjADIAVgAwAEsAQwBkAHMAYgAy
>> "%~1" echo AGQAQwBiADMAZwBuAEwAQwBmAG0AbAA2AFgAbAB2ADUAZgBvAHIANwB2AGwAagA1
>> "%~1" echo AGIAbABwAEwASABvAHQASwBYAHYAdgBKAG8AbgBLADIAVQB1AGIAVwBWAHoAYwAy
>> "%~1" echo AEYAbgBaAFMAawA3AGEAVwBZAG8AYwAyAGgAdgBkADAANQB2AGQARwBsAGoAWgBT
>> "%~1" echo AGwAdQBiADMAUgBwAFoAbgBrAG8ASgArAGEAWABwAGUAVwAvAGwAKwBpAHYAdQAr
>> "%~1" echo AFcAUABsAHUAVwBrAHMAZQBpADAAcABTAGMAcwBaAFMANQB0AFoAWABOAHoAWQBX
>> "%~1" echo AGQAbABMAEMAZABsAGMAbgBJAG4ATABEAFEAeQBNAEQAQQBwAGYAWAAwAEsAWQBY
>> "%~1" echo AE4ANQBiAG0ATQBnAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGMAbQBWAG0AYwBt
>> "%~1" echo AFYAegBhAEMAaAB6AGEARwA5ADMAVABtADkAMABhAFcATgBsAFAAVwBaAGgAYgBI
>> "%~1" echo AE4AbABLAFgAdAAwAGMAbgBsADcAYgBHAEYAegBkAEQAMQBoAGQAMgBGAHAAZABD
>> "%~1" echo AEIAaABjAEcAawBvAEoAeQA5AGgAYwBHAGsAdgBjADMAUgBoAGQASABWAHoASgB5
>> "%~1" echo AGsANwBZADIAOQB1AGMAMwBRAGcAWQB6ADEAcwBZAFgATgAwAEwAbQBOAHYAYgBt
>> "%~1" echo ADUAbABZADMAUgBsAFoARAAwADkAUABTAGQAMABjAG4AVgBsAEoAegBzAGsASwBD
>> "%~1" echo AGQAegBkAEcARgAwAGQAWABOAEQAYQBHAGwAdwBKAHkAawB1AFkAMgB4AGgAYwAz
>> "%~1" echo AE4ATQBhAFgATgAwAEwAbgBSAHYAWgAyAGQAcwBaAFMAZwBuAFkAMgA5AHUAYgBt
>> "%~1" echo AFYAagBkAEcAVgBrAEoAeQB4AGoASwBUAHMAawBLAEMAZAB6AGQARwBGADAAZABY
>> "%~1" echo AE4ARABhAEcAbAB3AEoAeQBrAHUAYwBYAFYAbABjAG4AbABUAFoAVwB4AGwAWQAz
>> "%~1" echo AFIAdgBjAGkAZwBuAGMAMwBCAGgAYgBpAGMAcABMAG4AUgBsAGUASABSAEQAYgAy
>> "%~1" echo ADUAMABaAFcANQAwAFAAVwBNAC8ASgArAFcAMwBzAHUAaQAvAG4AdQBhAE8AcABT
>> "%~1" echo AGMANgBLAEcAeABoAGMAMwBRAHUAWgBHAFYAMgBhAFcATgBsAFUAMwBSAGgAZABH
>> "%~1" echo AFUAOQBQAFQAMABuAGQAVwA1AGgAZABYAFIAbwBiADMASgBwAGUAbQBWAGsASgB6
>> "%~1" echo ADgAbgA1AHAAeQBxADUAbwA2AEkANQBwADIARABKAHoAcABzAFkAWABOADAATABt
>> "%~1" echo AFIAbABkAG0AbABqAFoAVgBOADAAWQBYAFIAbABQAFQAMAA5AEoAMgA5AG0AWgBt
>> "%~1" echo AHgAcABiAG0AVQBuAFAAeQBmAG4AcAByAHYAbgB1AHIAOABuAE8AaQBmAG0AbgBL
>> "%~1" echo AHIAbwB2ADUANwBtAGoAcQBVAG4ASwBUAHQAegBaAFgAUQBvAEoAMwBOADAAWQBY
>> "%~1" echo AFIAbABRAG0AbABuAEoAeQB4AHMAWQBYAE4AMABMAG0AUgBsAGQAbQBsAGoAWgBW
>> "%~1" echo AE4AMABZAFgAUgBsAGYASAB3AG4AYgBtADkAdQBaAFMAYwBwAE8AeQBRAG8ASgAz
>> "%~1" echo AE4AMABZAFgAUgBsAFEAbQBsAG4ASgB5AGsAdQBZADIAeABoAGMAMwBOAE0AYQBY
>> "%~1" echo AE4AMABMAG4AUgB2AFoAMgBkAHMAWgBTAGcAbgBaADIAOQB2AFoAQwBjAHMAWQB5
>> "%~1" echo AGsANwBjADIAVgAwAEsAQwBkAHoAZABHAEYAMABaAFUAaABwAGIAbgBRAG4ATABH
>> "%~1" echo AHgAaABjADMAUQB1AGEARwBsAHUAZABDAGsANwBjADIAVgAwAEsAQwBkAG8AWgBY
>> "%~1" echo AEoAdgBUAFcAOQBrAFoAVwB3AG4ATABHAHgAaABjADMAUQB1AGIAVwA5AGsAWgBX
>> "%~1" echo AHcAbQBKAG0AeABoAGMAMwBRAHUAYgBXADkAawBaAFcAdwBoAFAAVAAwAG4ATABT
>> "%~1" echo AGMALwBiAEcARgB6AGQAQwA1AHQAYgAyAFIAbABiAEQAbwBuAFUAWABWAGwAYwAz
>> "%~1" echo AFEAbgBLAFQAdAB6AFoAWABRAG8ASgAyAFIAbABkAG0AbABqAFoAVgBSAGgAWgB5
>> "%~1" echo AGMAcwBiAEcARgB6AGQAQwA1AGsAWgBYAFoAcABZADIAVgBUAGQARwBGADAAWgBY
>> "%~1" echo AHgAOABKADIANQB2AGIAbQBVAG4ASwBUAHQAegBaAFgAUQBvAEoAMgBGAGsAWQBs
>> "%~1" echo AE4AbwBiADMASgAwAEoAeQB4AHoAYQBHADkAeQBkAEYAQgBoAGQARwBnAG8AYgBH
>> "%~1" echo AEYAegBkAEMANQBoAFoARwBKAFEAWQBYAFIAbwBLAFMAawA3AGMAMgBWADAASwBD
>> "%~1" echo AGQAMwBhAFcAWgBwAFEAMgBoAHAAYwBDAGMAcwBkAGkAZwBuAGQAMgBsAG0AYQBV
>> "%~1" echo AGwAdwBKAHkAawBwAE8AMwBOAGwAZABDAGcAbgBkADIAbABtAGEAVQBsAHcAVABH
>> "%~1" echo AGwAMABaAFMAYwBzAGQAaQBnAG4AZAAyAGwAbQBhAFUAbAB3AEoAeQBrAHAATwAz
>> "%~1" echo AE4AbABkAEMAZwBuAGIARwBWAG0AZABFAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBY
>> "%~1" echo AEoATQBhAFgAUgBsAEoAeQB4ADIASwBDAGQAagBiADIANQAwAGMAbQA5AHMAYgBH
>> "%~1" echo AFYAeQBUAEcAVgBtAGQARQBKAGgAZABIAFIAbABjAG4AawBuAEsAUwBrADcAYwAy
>> "%~1" echo AFYAMABLAEMAZAB5AGEAVwBkAG8AZABFAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBY
>> "%~1" echo AEoATQBhAFgAUgBsAEoAeQB4ADIASwBDAGQAagBiADIANQAwAGMAbQA5AHMAYgBH
>> "%~1" echo AFYAeQBVAG0AbABuAGEASABSAEMAWQBYAFIAMABaAFgASgA1AEoAeQBrAHAATwAz
>> "%~1" echo AE4AbABkAEMAZwBuAGIARwBWAG0AZABFAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBY
>> "%~1" echo AEoAVABkAEcARgAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBH
>> "%~1" echo AHgAbABjAGsAeABsAFoAbgBSAFQAZABHAEYAMABkAFgATQBuAEsAUwBrADcAYwAy
>> "%~1" echo AFYAMABLAEMAZAB5AGEAVwBkAG8AZABFAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBY
>> "%~1" echo AEoAVABkAEcARgAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBH
>> "%~1" echo AHgAbABjAGwASgBwAFoAMgBoADAAVQAzAFIAaABkAEgAVgB6AEoAeQBrAHAATwAz
>> "%~1" echo AE4AbABkAEMAZwBuAFkAMgB4AHYAWQAyAHQAVQBaAFgAaAAwAEoAeQB4AHUAWgBY
>> "%~1" echo AGMAZwBSAEcARgAwAFoAUwBnAHAATABuAFIAdgBUAEcAOQBqAFkAVwB4AGwAVgBH
>> "%~1" echo AGwAdABaAFYATgAwAGMAbQBsAHUAWgB5AGcAcABLAFQAdABqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAaQBQAFgAWQBvAEoAMgBKAGgAZABIAFIAbABjAG4AbABNAFoAWABaAGwAYgBD
>> "%~1" echo AGMAcABMAEgAUQA5AGQAaQBnAG4AWQBtAEYAMABkAEcAVgB5AGUAVgBSAGwAYgBY
>> "%~1" echo AEEAbgBLAFMAeAAzAFAAWABZAG8ASgAzAGQAaABhADIAVgBtAGQAVwB4AHUAWgBY
>> "%~1" echo AE4AegBKAHkAawBzAFkAbQA0ADkAYwBHAEYAeQBjADIAVgBHAGIARwA5AGgAZABD
>> "%~1" echo AGgAaQBLAFMAeAAwAGIAagAxAHcAWQBYAEoAegBaAFUAWgBzAGIAMgBGADAASwBI
>> "%~1" echo AFEAcABPADMASgBwAGIAbQBjAG8ASgAyAEoAaABkAEgAUgBsAGMAbgBsAEgAWQBY
>> "%~1" echo AFYAbgBaAFMAYwBzAFkAagAwADkAUABTAGMAdABKAHoAOABuAEwAUwAwAGwASgB6
>> "%~1" echo AHAAaQBLAHkAYwBsAEoAeQB3AG4ANQA1AFMAMQA2AFkAZQBQAEoAeQB4AHcAWQAz
>> "%~1" echo AFEAbwBZAGkAawBzAEkAVwBsAHoAUgBtAGwAdQBhAFgAUgBsAEsARwBKAHUASwBU
>> "%~1" echo ADgAbgBKAHoAcABpAGIAagB3AHkATQBEADgAbgBjAG0AVgBrAEoAegBwAGkAYgBq
>> "%~1" echo AHcAMABOAFQAOABuAFkAVwAxAGkAWgBYAEkAbgBPAGkAZABuAGMAbQBWAGwAYgBp
>> "%~1" echo AGMAcABPADMASgBwAGIAbQBjAG8ASgAzAFIAbABiAFgAQgBIAFkAWABWAG4AWgBT
>> "%~1" echo AGMAcwBkAEQAMAA5AFAAUwBjAHQASgB6ADgAbgBMAFMAMwBDAHMARQBNAG4ATwBu
>> "%~1" echo AFEAcgBKADgASwB3AFEAeQBjAHMASgArAGEANABxAGUAVwA2AHAAaQBjAHMAYwBH
>> "%~1" echo AE4AMABLAEgAUQBzAE4AVABVAHAATABDAEYAcABjADAAWgBwAGIAbQBsADAAWgBT
>> "%~1" echo AGgAMABiAGkAawAvAEoAeQBjADYAZABHADQAKwBQAFQAUQAxAFAAeQBkAHkAWgBX
>> "%~1" echo AFEAbgBPAG4AUgB1AFAAagAwAHoATwBEADgAbgBZAFcAMQBpAFoAWABJAG4ATwBp
>> "%~1" echo AGQAbgBjAG0AVgBsAGIAaQBjAHAATwAyAE4AdgBiAG4ATgAwAEkARwBGADMAWQBX
>> "%~1" echo AHQAbABQAFMAaAAzAGYASAB3AG4ASgB5AGsAdQBkAEcAOQBNAGIAMwBkAGwAYwBr
>> "%~1" echo AE4AaABjADIAVQBvAEsAUwA1AHAAYgBtAE4AcwBkAFcAUgBsAGMAeQBnAG4AWQBY
>> "%~1" echo AGQAaABhADIAVQBuAEsAVAB0AHkAYQBXADUAbgBLAEMAZAB6AGIARwBWAGwAYwBF
>> "%~1" echo AGQAaABkAFcAZABsAEoAeQB4ADMAUABUADAAOQBKAHkAMABuAFAAeQBjAHQASgB6
>> "%~1" echo AHAAMwBMAEcAeABoAGMAMwBRAHUAYgBWAE4AMABZAFgAbABQAGIAagAwADkAUABT
>> "%~1" echo AGQAMABjAG4AVgBsAEoAegA4AG4ANQBMACsAZAA1AG8AeQBCADUAWgBTAGsANgBZ
>> "%~1" echo AGEAUwBKAHoAbwBuADUATAB5AFIANQA1AHkAZwBKAHkAeABoAGQAMgBGAHIAWgBU
>> "%~1" echo ADgAeABNAEQAQQA2AE0AagBnAHMAWQBYAGQAaABhADIAVQAvAEoAMgBGAHQAWQBt
>> "%~1" echo AFYAeQBKAHoAbwBuAFoAMwBKAGwAWgBXADQAbgBLAFQAdABQAFkAbQBwAGwAWQAz
>> "%~1" echo AFEAdQBhADIAVgA1AGMAeQBoAHMAWQBYAE4AMABLAFMANQBtAGIAMwBKAEYAWQBX
>> "%~1" echo AE4AbwBLAEcAcwA5AFAAbgBOAGwAZABDAGgAcgBMAEcAeABoAGMAMwBSAGIAYQAx
>> "%~1" echo ADAAcABLAFQAdAB6AFoAWABRAG8ASgAzAEIAdgBkADIAVgB5AFUAMgA5ADEAYwBt
>> "%~1" echo AE4AbABNAGkAYwBzAGIARwBGAHoAZABDADUAdwBiADMAZABsAGMAbABOAHYAZABY
>> "%~1" echo AEoAagBaAFMAawA3AGMAMgBWADAASwBDAGQAcwBiADIAZABRAFkAWABSAG8ASgB5
>> "%~1" echo AHgAcwBZAFgATgAwAEwAbQB4AHYAWgAwAFoAcABiAEcAVQBwAE8AMwBOAGwAZABD
>> "%~1" echo AGcAbgBZADIAOQB1AGMAMgA5AHMAWgBWAE4AMABZAFgAUgBsAEoAeQB4AHMAWQBY
>> "%~1" echo AE4AMABMAG0AUgBsAGQAbQBsAGoAWgBWAE4AMABZAFgAUgBsAEsAVAB0AHoAWgBY
>> "%~1" echo AFEAbwBKADIATgB2AGIAbgBOAHYAYgBHAFYARABiADIANQB1AEoAeQB4AGoAUAB5
>> "%~1" echo AGYAbAB0ADcATABvAHYANQA3AG0AagBxAFUAbgBPAGkAZgBtAG4ASwByAG8AdgA1
>> "%~1" echo ADcAbQBqAHEAVQBuAEsAVAB0AHoAWgBYAFEAbwBKADIATgB2AGIAbgBOAHYAYgBH
>> "%~1" echo AFYAQwBZAFgAUgAwAFoAWABKADUASgB5AHgAaQBQAFQAMAA5AEoAeQAwAG4AUAB5
>> "%~1" echo AGMAdABKAHoAcABpAEsAeQBjAGwASgB5AGsANwBjADIAVgAwAEsAQwBkAGoAYgAy
>> "%~1" echo ADUAegBiADIAeABsAFYAMgBGAHIAWgBTAGMAcwBkAHkAawA3AGMAMgBWADAASwBD
>> "%~1" echo AGQAagBiADIANQB6AGIAMgB4AGwAVgAyAGwAbQBhAFMAYwBzAGQAaQBnAG4AZAAy
>> "%~1" echo AGwAbQBhAFUAbAB3AEoAeQBrAHAATwAzAEoAbABiAG0AUgBsAGMAbABCAGgAYwBt
>> "%~1" echo AEYAdABjAHkAZwBwAE8AMgBsAG0ASwBIAE4AbwBiADMAZABPAGIAMwBSAHAAWQAy
>> "%~1" echo AFUAcABiAG0AOQAwAGEAVwBaADUASwBDAGYAbABpAEwAZgBtAGwAcgBEAGwAcgBv
>> "%~1" echo AHoAbQBpAEoAQQBuAEwARwBNAC8ASgArAFcAMwBzAHUAaQAvAG4AdQBhAE8AcABl
>> "%~1" echo ACsAOABtAGkAYwByAEsARwB4AGgAYwAzAFEAdQBiAFcAOQBrAFoAVwB4ADgAZgBD
>> "%~1" echo AGQAUgBkAFcAVgB6AGQAQwBjAHAASwB5AGYAdgB2AEkAegBuAGwATABYAHAAaAA0
>> "%~1" echo ADgAZwBKAHkAdABpAEsAeQBjAGwASgB6AG8AbwBiAEcARgB6AGQAQwA1AG8AYQBX
>> "%~1" echo ADUAMABmAEgAdwBuADUAcAB5AHEANgBMACsAZQA1AG8ANgBsAEoAeQBrAHMAWQB6
>> "%~1" echo ADgAbgBiADIAcwBuAE8AaQBkADMAWQBYAEoAdQBKAHkAbAA5AFkAMgBGADAAWQAy
>> "%~1" echo AGcAbwBaAFMAbAA3AGIARwA5AG4ASwBDAGYAbABpAEwAZgBtAGwAcgBEAGwAcABM
>> "%~1" echo AEgAbwB0AEsAWAB2AHYASgBvAG4ASwAyAFUAdQBiAFcAVgB6AGMAMgBGAG4AWgBT
>> "%~1" echo AGsANwBjAG0AVgB1AFoARwBWAHkAVQBHAEYAeQBZAFcAMQB6AEsAQwBrADcAYQBX
>> "%~1" echo AFkAbwBjADIAaAB2AGQAMAA1AHYAZABHAGwAagBaAFMAbAB1AGIAMwBSAHAAWgBu
>> "%~1" echo AGsAbwBKACsAVwBJAHQAKwBhAFcAcwBPAFcAawBzAGUAaQAwAHAAUwBjAHMAWgBT
>> "%~1" echo ADUAdABaAFgATgB6AFkAVwBkAGwATABDAGQAbABjAG4ASQBuAEwARABRAHkATQBE
>> "%~1" echo AEEAcABmAFgAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGMAMgBWADAAUQBu
>> "%~1" echo AFYAegBlAFMAaAB2AGIAaQB4AGkAZABHADQAcABlADIASgAxAGMAMwBrADkAYgAy
>> "%~1" echo ADQANwBaAEcAOQBqAGQAVwAxAGwAYgBuAFEAdQBjAFgAVgBsAGMAbgBsAFQAWgBX
>> "%~1" echo AHgAbABZADMAUgB2AGMAawBGAHMAYgBDAGcAbgBZAG4AVgAwAGQARwA5AHUASgB5
>> "%~1" echo AGsAdQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAaQBQAFQANQBpAEwAbQBSAHAAYwAy
>> "%~1" echo AEYAaQBiAEcAVgBrAFAAVwA5AHUASwBUAHQAcABaAGkAaABpAGQARwA0AHAAWQBu
>> "%~1" echo AFIAdQBMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMANQAwAGIAMgBkAG4AYgBH
>> "%~1" echo AFUAbwBKADIAbAB6AEwAVwBKADEAYwAzAGsAbgBMAEcAOQB1AEsAWAAwAEsAWQBY
>> "%~1" echo AE4ANQBiAG0ATQBnAFoAbgBWAHUAWQAzAFIAcABiADIANABnAFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBLAEcARQBzAFoAWABoADAAYwBtAEUAOQBKAHkAYwBzAGIARwBGAGkAWgBX
>> "%~1" echo AHcAOQBKACsAYQBUAGoAZQBTADkAbgBDAGMAcwBZAG4AUgB1AFAAVwA1ADEAYgBH
>> "%~1" echo AHcAcwBZADIAOQB1AFoAbQBsAHkAYgBXAFYAawBQAFcAWgBoAGIASABOAGwASwBY
>> "%~1" echo AHQAcABaAGkAaABpAGQAWABOADUASwBYAEoAbABkAEgAVgB5AGIAaQBCAHUAYgAz
>> "%~1" echo AFIAcABaAG4AawBvAEoAKwBXADMAcwB1AGEAYwBpAGUAYQBUAGoAZQBTADkAbgBP
>> "%~1" echo AGEASgBwACsAaQBoAGoATwBTADQAcgBTAGMAcwBKACsAaQB2AHQAKwBlAHQAaQBl
>> "%~1" echo AFcAKwBoAGUAUwA0AGkAdQBTADQAZwBPAGEAZABvAGUAVwBSAHYAZQBTADcAcABP
>> "%~1" echo AFcAdQBqAE8AYQBJAGsATwBPAEEAZwBpAGMAcwBKADMAZABoAGMAbQA0AG4ASwBU
>> "%~1" echo AHQAMABjAG4AbAA3AGMAMgBWADAAUQBuAFYAegBlAFMAaAAwAGMAbgBWAGwATABH
>> "%~1" echo AEoAMABiAGkAawA3AGIARwA5AG4ASwBDAGYAbQBpAGEAZgBvAG8AWQB6AGsAdQBL
>> "%~1" echo ADMAdgB2AEoAbwBuAEsAMgB4AGgAWQBtAFYAcwBLAFQAdAB1AGIAMwBSAHAAWgBu
>> "%~1" echo AGsAbwBiAEcARgBpAFoAVwB3AHMASgArAGEAdABvACsAVwBjAHEATwBXAFAAawBl
>> "%~1" echo AG0AQQBnAGUAVwBSAHYAZQBTADcAcABDADQAdQBMAGkAYwBzAEoAMwBkAGgAYwBt
>> "%~1" echo ADQAbgBMAEQARQA0AE0ARABBAHAATwAyAHgAbABkAEMAQgAxAGMAbQB3ADkASgB5
>> "%~1" echo ADkAaABjAEcAawB2AFkAVwBOADAAYQBXADkAdQBQADIARgBqAGQARwBsAHYAYgBq
>> "%~1" echo ADAAbgBLADIAVgB1AFkAMgA5AGsAWgBWAFYAUwBTAFUATgB2AGIAWABCAHYAYgBt
>> "%~1" echo AFYAdQBkAEMAaABoAEsAUwB0AGwAZQBIAFIAeQBZAFQAdABwAFoAaQBoAGoAYgAy
>> "%~1" echo ADUAbQBhAFgASgB0AFoAVwBRAHAAZABYAEoAcwBLAHoAMABuAEoAbQBOAHYAYgBt
>> "%~1" echo AFoAcABjAG0AMAA5AFcAVQBWAFQASgB6AHQAagBiADIANQB6AGQAQwBCAHkAUABX
>> "%~1" echo AEYAMwBZAFcAbAAwAEkARwBGAHcAYQBTAGgAMQBjAG0AdwBzAGUAMgAxAGwAZABH
>> "%~1" echo AGgAdgBaAEQAbwBuAFUARQA5AFQAVgBDAGQAOQBLAFQAdABwAFoAaQBoAHkATABt
>> "%~1" echo ADkAcgBJAFQAMAA5AEoAMwBSAHkAZABXAFUAbgBLAFgAUgBvAGMAbQA5ADMASQBH
>> "%~1" echo ADUAbABkAHkAQgBGAGMAbgBKAHYAYwBpAGgAeQBMAG0AVgB5AGMAbQA5AHkAZgBI
>> "%~1" echo AHcAbgA1AHAATwBOADUATAAyAGMANQBhAFMAeAA2AEwAUwBsAEoAeQBrADcAYgBH
>> "%~1" echo ADkAbgBLAEgASQB1AGMAbQBWAHoAZABXAHgAMABmAEgAdwBuADUAYQA2AE0ANQBv
>> "%~1" echo AGkAUQBKAHkAawA3AGIAbQA5ADAAYQBXAFoANQBLAEcAeABoAFkAbQBWAHMASwB5
>> "%~1" echo AGYAbAByAG8AegBtAGkASgBBAG4ATABIAEkAdQBjAG0AVgB6AGQAVwB4ADAAZgBI
>> "%~1" echo AHcAbgA1AGEANgBNADUAbwBpAFEASgB5AHcAbgBiADIAcwBuAEsAVAB0AHoAWgBY
>> "%~1" echo AFIAVQBhAFcAMQBsAGIAMwBWADAASwBDAGcAcABQAFQANQA3AGMAbQBWAG0AYwBt
>> "%~1" echo AFYAegBhAEMAaABtAFkAVwB4AHoAWgBTAGsANwBiAEcAOQBoAFoARQB4AHYAWgAz
>> "%~1" echo AE0AbwBaAG0ARgBzAGMAMgBVAHAAZgBTAHcAMQBNAEQAQQBwAGYAVwBOAGgAZABH
>> "%~1" echo AE4AbwBLAEcAVQBwAGUAMgB4AHYAWgB5AGcAbgA1AHAATwBOADUATAAyAGMANQBh
>> "%~1" echo AFMAeAA2AEwAUwBsADcANwB5AGEASgB5AHQAbABMAG0AMQBsAGMAMwBOAGgAWgAy
>> "%~1" echo AFUAcABPADIANQB2AGQARwBsAG0AZQBTAGgAcwBZAFcASgBsAGIAQwBzAG4ANQBh
>> "%~1" echo AFMAeAA2AEwAUwBsAEoAeQB4AGwATABtADEAbABjADMATgBoAFoAMgBVAHMASgAy
>> "%~1" echo AFYAeQBjAGkAYwBzAE4ARABZAHcATQBDAGsANwBiAEcAOQBoAFoARQB4AHYAWgAz
>> "%~1" echo AE0AbwBaAG0ARgBzAGMAMgBVAHAAZgBXAFoAcABiAG0ARgBzAGIASABsADcAYwAy
>> "%~1" echo AFYAMABRAG4AVgB6AGUAUwBoAG0AWQBXAHgAegBaAFMAeABpAGQARwA0AHAAZgBY
>> "%~1" echo ADAASwBZAFgATgA1AGIAbQBNAGcAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAWgBY
>> "%~1" echo AGgAdwBiADMASgAwAFMASABSAHQAYgBDAGcAcABlADIAbABtAEsARwBKADEAYwAz
>> "%~1" echo AGsAcABjAG0AVgAwAGQAWABKAHUASQBHADUAdgBkAEcAbABtAGUAUwBnAG4ANQBi
>> "%~1" echo AGUAeQA1AHAAeQBKADUAcABPAE4ANQBMADIAYwA1AG8AbQBuADYASwBHAE0ANQBM
>> "%~1" echo AGkAdABKAHkAdwBuADYASwArADMANQA2ADIASgA1AGIANgBGADUATABpAEsANQBM
>> "%~1" echo AGkAQQA1AHAAMgBoADUAWgBHADkANQBMAHUAawA1AGEANgBNADUAbwBpAFEANAA0
>> "%~1" echo AEMAQwBKAHkAdwBuAGQAMgBGAHkAYgBpAGMAcABPADIATgB2AGIAbgBOADAASQBH
>> "%~1" echo AEoAMABiAGoAMABrAEsAQwBkAGwAZQBIAEIAdgBjAG4AUgBDAGQARwA0AG4ASwBU
>> "%~1" echo AHQAMABjAG4AbAA3AGMAMgBWADAAUQBuAFYAegBlAFMAaAAwAGMAbgBWAGwATABH
>> "%~1" echo AEoAMABiAGkAawA3AGMAMgBWADAASwBDAGQAbABlAEgAQgB2AGMAbgBSAFQAZABH
>> "%~1" echo AEYAMABkAFgATQBuAEwAQwBmAG0AcgBhAFAAbABuAEsAagBsAGoANgByAG8AcgA3
>> "%~1" echo AHYAcABoADQAZgBwAG0ANABiAGwAcgBvAHoAbQBsAGIAVABvAHIAcgA3AGwAcABJ
>> "%~1" echo AGYAawB2ADYASABtAGcAYQAvAHYAdgBJAHoAbABqADYALwBvAGcANwAzAHAAbgBJ
>> "%~1" echo AEQAbwBwAG8ARQBnAE0AVABBAHQATgBEAEEAZwA1ADYAZQBTAEwAaQA0AHUASgB5
>> "%~1" echo AGsANwBKAEMAZwBuAFoAWABoAHcAYgAzAEoAMABUAEcAbAB1AGEAMwBNAG4ASwBT
>> "%~1" echo ADUAcABiAG0ANQBsAGMAawBoAFUAVABVAHcAOQBKAHkAYwA3AGIAbQA5ADAAYQBX
>> "%~1" echo AFoANQBLAEMAZgBsAHYASQBEAGwAcAA0AHYAbAByADcAegBsAGgANwBvAG4ATABD
>> "%~1" echo AGYAbQByAGEAUABsAG4ASwBqAG4AbABKAC8AbQBpAEoARABuAHAANABIAG0AbgBJ
>> "%~1" echo AG4AbAByAG8AegBtAGwAYgBUAG4AaQBZAGoAbABrAG8AegBsAGkASQBiAGsAdQBx
>> "%~1" echo AHYAbAByAG8AbgBsAGgAYQBqAG4AaQBZAGcAZwBTAEYAUgBOAFQAQwBjAHMASgAz
>> "%~1" echo AGQAaABjAG0ANABuAEwARABJAHkATQBEAEEAcABPADIATgB2AGIAbgBOADAASQBI
>> "%~1" echo AEkAOQBZAFgAZABoAGEAWABRAGcAWQBYAEIAcABLAEMAYwB2AFkAWABCAHAATAAy
>> "%~1" echo AFYANABjAEcAOQB5AGQARAA5AHQAYgAyAFIAbABQAFcASgB2AGQARwBnAG4ATABI
>> "%~1" echo AHQAdABaAFgAUgBvAGIAMgBRADYASgAxAEIAUABVADEAUQBuAGYAUwBrADcAYQBX
>> "%~1" echo AFkAbwBjAGkANQB2AGEAeQBFADkAUABTAGQAMABjAG4AVgBsAEoAeQBsADAAYQBI
>> "%~1" echo AEoAdgBkAHkAQgB1AFoAWABjAGcAUgBYAEoAeQBiADMASQBvAGMAaQA1AGwAYwBu
>> "%~1" echo AEoAdgBjAG4AeAA4AEoAKwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABT
>> "%~1" echo AGMAcABPADMATgBsAGQAQwBnAG4AWgBYAGgAdwBiADMASgAwAFUAMwBSAGgAZABI
>> "%~1" echo AFYAegBKAHkAdwBuADUAYQArADgANQBZAGUANgA1AGEANgBNADUAbwBpAFEANwA3
>> "%~1" echo AHkAYQBKAHkAcwBvAGMAaQA1AHoAWgBXAE4AMABhAFcAOQB1AFEAMgA5ADEAYgBu
>> "%~1" echo AFIAOABmAEMAYwB0AEoAeQBrAHIASgB5AEQAawB1AEsAcgBwAGgANABmAHAAbQA0
>> "%~1" echo AGIAbQByAHIAWAB2AHYASQB6AG8AZwBKAGYAbQBsADcAWQBnAEoAeQB0AE4AWQBY
>> "%~1" echo AFIAbwBMAG4ASgB2AGQAVwA1AGsASwBDAGgAdwBZAFgASgB6AFoAVQBsAHUAZABD
>> "%~1" echo AGgAeQBMAG0AUgAxAGMAbQBGADAAYQBXADkAdQBUAFgATgA4AGYAQwBjAHcASgB5
>> "%~1" echo AHcAeABNAEMAbAA4AGYARABBAHAATAB6AEUAdwBNAEQAQQBwAEsAeQBjAGcANQA2
>> "%~1" echo AGUAUwA0ADQAQwBDAEoAeQBrADcASgBDAGcAbgBaAFgAaAB3AGIAMwBKADAAVABH
>> "%~1" echo AGwAdQBhADMATQBuAEsAUwA1AHAAYgBtADUAbABjAGsAaABVAFQAVQB3ADkASgB6
>> "%~1" echo AHgAaABJAEgAUgBoAGMAbQBkAGwAZABEADAAaQBYADIASgBzAFkAVwA1AHIASQBp
>> "%~1" echo AEIAbwBjAG0AVgBtAFAAUwBJAG4ASwAyAFYAegBZAHkAaAB5AEwAbgBCAHkAYQBY
>> "%~1" echo AFoAaABkAEcAVgBWAGMAbQB3AHAASwB5AGMAaQBQAHUAYQBKAGsAKwBXADgAZwBP
>> "%~1" echo AGUAbgBnAGUAYQBjAGkAZQBXAHUAagBPAGEAVgB0AE8AZQBKAGkAQwBCAEkAVgBF
>> "%~1" echo ADEATQBQAEMAOQBoAFAAagB4AGgASQBIAFIAaABjAG0AZABsAGQARAAwAGkAWAAy
>> "%~1" echo AEoAcwBZAFcANQByAEkAaQBCAG8AYwBtAFYAbQBQAFMASQBuAEsAMgBWAHoAWQB5
>> "%~1" echo AGgAeQBMAG4ATgBoAFoAbQBWAFYAYwBtAHcAcABLAHkAYwBpAFAAdQBhAEoAawAr
>> "%~1" echo AFcAOABnAE8AVwBJAGgAdQBTADYAcQArAFcAdQBpAGUAVwBGAHEATwBlAEoAaQBD
>> "%~1" echo AEIASQBWAEUAMQBNAFAAQwA5AGgAUABqAHgAegBjAEcARgB1AFAAaQBjAHIAWgBY
>> "%~1" echo AE4AagBLAEgASQB1AGMAMgBGAG0AWgBWAEIAaABkAEcAaAA4AGYAQwBjAG4ASwBT
>> "%~1" echo AHMAbgBQAEMAOQB6AGMARwBGAHUAUABpAGMANwBiAG0AOQAwAGEAVwBaADUASwBD
>> "%~1" echo AGYAbAByADcAegBsAGgANwByAGwAcgBvAHoAbQBpAEoAQQBuAEwAQwBmAGwAdAA3
>> "%~1" echo AEwAbgBsAEoALwBtAGkASgBEAGsAdQBLAFQAawB1ADcAMABnAFMARgBSAE4AVABD
>> "%~1" echo AEQAbQBpAHEAWABsAGsAWQBvAG4ATABDAGQAdgBhAHkAYwBwAE8AMgB4AHYAWQBX
>> "%~1" echo AFIATQBiADIAZAB6AEsARwBaAGgAYgBIAE4AbABLAFgAMQBqAFkAWABSAGoAYQBD
>> "%~1" echo AGgAbABLAFgAdAB6AFoAWABRAG8ASgAyAFYANABjAEcAOQB5AGQARgBOADAAWQBY
>> "%~1" echo AFIAMQBjAHkAYwBzAEoAKwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABl
>> "%~1" echo ACsAOABtAGkAYwByAFoAUwA1AHQAWgBYAE4AegBZAFcAZABsAEsAVAB0AHUAYgAz
>> "%~1" echo AFIAcABaAG4AawBvAEoAKwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABT
>> "%~1" echo AGMAcwBaAFMANQB0AFoAWABOAHoAWQBXAGQAbABMAEMAZABsAGMAbgBJAG4ATABE
>> "%~1" echo AFUAeQBNAEQAQQBwAE8AMgB4AHYAWQBXAFIATQBiADIAZAB6AEsARwBaAGgAYgBI
>> "%~1" echo AE4AbABLAFgAMQBtAGEAVwA1AGgAYgBHAHgANQBlADMATgBsAGQARQBKADEAYwAz
>> "%~1" echo AGsAbwBaAG0ARgBzAGMAMgBVAHMAWQBuAFIAdQBLAFgAMQA5AEMAZwBvAHYASwBp
>> "%~1" echo AEEAdABMAFMAMAB0AEwAUwAwAHQATABTADAAdABJAEUARgBRAFMAeQBCAHAAYgBu
>> "%~1" echo AE4AMABZAFcAeABzAFoAWABJAGcASwBFAEYAdwBjAEMAQgBUAGQARwA5AHkAWgBT
>> "%~1" echo AEIAagBZAFgASgBrAEkAQwBzAGcAVQAxAE4ARgBJAEgAQgB5AGIAMgBkAHkAWgBY
>> "%~1" echo AE4AegBLAFMAQQB0AEwAUwAwAHQATABTADAAdABMAFMAMAB0AEkAQwBvAHYAQwBt
>> "%~1" echo AFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAEoAbABjADIAVgAwAFEAWABCAHIASwBD
>> "%~1" echo AGwANwBZAFgAQgByAFAAVwA1ADEAYgBHAHcANwBKAEMAZwBuAFkAWABCAHIAUgBH
>> "%~1" echo AFYAMABZAFcAbABzAEoAeQBrAHUAYwAzAFIANQBiAEcAVQB1AFoARwBsAHoAYwBH
>> "%~1" echo AHgAaABlAFQAMABuAGIAbQA5AHUAWgBTAGMANwBKAEMAZwBuAFkAWABCAHIAUgBI
>> "%~1" echo AEoAdgBjAEMAYwBwAEwAbgBOADAAZQBXAHgAbABMAG0AUgBwAGMAMwBCAHMAWQBY
>> "%~1" echo AGsAOQBKAHkAYwA3AEoAQwBnAG4AWQBYAEIAcgBVAEcAVgB5AGIAWABNAG4ASwBT
>> "%~1" echo ADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIAMwBaAGwASwBD
>> "%~1" echo AGQAegBhAEcAOQAzAEoAeQBrADcASgBDAGcAbgBZAFcAUgBpAFQAMwBWADAASgB5
>> "%~1" echo AGsAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4AMABMAG4ASgBsAGIAVwA5ADIAWgBT
>> "%~1" echo AGcAbgBjADIAaAB2AGQAeQBjAHAATwB5AFEAbwBKADIARgBrAFkAawA5ADEAZABD
>> "%~1" echo AGMAcABMAG4AUgBsAGUASABSAEQAYgAyADUAMABaAFcANQAwAFAAUwBjAG4ATwB5
>> "%~1" echo AFEAbwBKADMATgAwAFkAVwBkAGwAVQBtADkAMwBKAHkAawB1AFkAMgB4AGgAYwAz
>> "%~1" echo AE4ATQBhAFgATgAwAEwAbgBKAGwAYgBXADkAMgBaAFMAZwBuAGMAMgBoAHYAZAB5
>> "%~1" echo AGMAcABPADIATgB2AGIAbgBOADAASQBHAEkAOQBKAEMAZwBuAGEAVwA1AHoAZABH
>> "%~1" echo AEYAcwBiAEUASgAwAGIAaQBjAHAATwAyAEkAdQBZADIAeABoAGMAMwBOAE8AWQBX
>> "%~1" echo ADEAbABQAFMAZABwAGIAbgBOADAAWQBXAHgAcwBRAG4AUgB1AEoAegB0AGkATABt
>> "%~1" echo AFIAcABjADIARgBpAGIARwBWAGsAUABXAFoAaABiAEgATgBsAE8AeQBRAG8ASgAy
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB4AEcAYQBXAHgAcwBKAHkAawB1AGMAMwBSADUAYgBH
>> "%~1" echo AFUAdQBkADIAbABrAGQARwBnADkASgB6AEEAbgBPAHkAUQBvAEoAMgBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAeABNAFkAVwBKAGwAYgBDAGMAcABMAG4AUgBsAGUASABSAEQAYgAy
>> "%~1" echo ADUAMABaAFcANQAwAFAAUwBmAGwAcgBvAG4AbwBvADQAWABsAGkATABBAGcAVQBY
>> "%~1" echo AFYAbABjADMAUQBuAE8AeQBRAG8ASgAyAEYAdwBjAEUATgBoAGMAbQBRAG4ASwBT
>> "%~1" echo ADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBjAG0AVgB0AGIAMwBaAGwASwBD
>> "%~1" echo AGQAbgBiAEcAOQAzAEoAeQBsADkAQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBI
>> "%~1" echo AFYAdwBiAEcAOQBoAFoARQBGAHcAYQB5AGgAbQBhAFcAeABsAEsAWABzAEsASQBD
>> "%~1" echo AEIAcABaAGkAaABpAGQAWABOADUASwBYAEoAbABkAEgAVgB5AGIAaQBCAHUAYgAz
>> "%~1" echo AFIAcABaAG4AawBvAEoAKwBXADMAcwB1AGEAYwBpAGUAYQBUAGoAZQBTADkAbgBP
>> "%~1" echo AGEASgBwACsAaQBoAGoATwBTADQAcgBTAGMAcwBKACsAaQB2AHQAKwBlAHQAaQBl
>> "%~1" echo AFcAKwBoAGUAUwA0AGkAdQBTADQAZwBPAGEAZABvAGUAVwBSAHYAZQBTADcAcABP
>> "%~1" echo AFcAdQBqAE8AYQBJAGsATwBPAEEAZwBpAGMAcwBKADMAZABoAGMAbQA0AG4ASwBU
>> "%~1" echo AHMASwBJAEMAQgBwAFoAaQBnAGgAWgBtAGwAcwBaAFMAbAB5AFoAWABSADEAYwBt
>> "%~1" echo ADQANwBDAGkAQQBnAGEAVwBZAG8ASQBTADkAYwBMAG0ARgB3AGEAeQBRAHYAYQBT
>> "%~1" echo ADUAMABaAFgATgAwAEsARwBaAHAAYgBHAFUAdQBiAG0ARgB0AFoAUwBrAHAAYwBt
>> "%~1" echo AFYAMABkAFgASgB1AEkARwA1AHYAZABHAGwAbQBlAFMAZwBuADUAcABhAEgANQBM
>> "%~1" echo AHUAMgA1ADcARwA3ADUAWgA2AEwANQBMAGkATgA1AHAAUwB2ADUAbwB5AEIASgB5
>> "%~1" echo AHcAbgA2AEsAKwAzADYAWQBDAEoANQBvAHUAcABJAEMANQBoAGMARwBzAGcANQBw
>> "%~1" echo AGEASAA1AEwAdQAyADQANABDAEMASgB5AHcAbgBkADIARgB5AGIAaQBjAHAATwB3
>> "%~1" echo AG8AZwBJAEMAOAB2AEkASABOAG8AYgAzAGMAZwBZAFMAQgBzAGEAVwBkAG8AZABI
>> "%~1" echo AGQAbABhAFcAZABvAGQAQwBCADEAYwBHAHgAdgBZAFcAUgBwAGIAbQBjAGcAYwAz
>> "%~1" echo AFIAaABkAEcAVQBnAGIAMgA0AGcAZABHAGgAbABJAEcAUgB5AGIAMwBBAGcAZABH
>> "%~1" echo AGwAcwBaAFEAbwBnAEkARwBOAHYAYgBuAE4AMABJAEcAUgB5AGIAMwBBADkASgBD
>> "%~1" echo AGcAbgBZAFgAQgByAFIASABKAHYAYwBDAGMAcABPADIAUgB5AGIAMwBBAHUAYwBY
>> "%~1" echo AFYAbABjAG4AbABUAFoAVwB4AGwAWQAzAFIAdgBjAGkAZwBuAFkAaQBjAHAATABu
>> "%~1" echo AFIAbABlAEgAUgBEAGIAMgA1ADAAWgBXADUAMABQAFMAZgBtAHIAYQBQAGwAbgBL
>> "%~1" echo AGoAawB1AEkAcgBrAHYASwBBAGcASgB5AHQAbQBhAFcAeABsAEwAbQA1AGgAYgBX
>> "%~1" echo AFUAcgBKAHkARABpAGcASwBZAG4ATwB3AG8AZwBJAEcATgB2AGIAbgBOADAASQBI
>> "%~1" echo AGgAbwBjAGoAMQB1AFoAWABjAGcAVwBFADEATQBTAEgAUgAwAGMARgBKAGwAYwBY
>> "%~1" echo AFYAbABjADMAUQBvAEsAVABzAEsASQBDAEIANABhAEgASQB1AGIAMwBCAGwAYgBp
>> "%~1" echo AGcAbgBVAEUAOQBUAFYAQwBjAHMASgB5ADkAaABjAEcAawB2AFkAWABCAHIATAAz
>> "%~1" echo AFYAdwBiAEcAOQBoAFoARAA5AHUAWQBXADEAbABQAFMAYwByAFoAVwA1AGoAYgAy
>> "%~1" echo AFIAbABWAFYASgBKAFEAMgA5AHQAYwBHADkAdQBaAFcANQAwAEsARwBaAHAAYgBH
>> "%~1" echo AFUAdQBiAG0ARgB0AFoAUwBrAHAATwB3AG8AZwBJAEgAaABvAGMAaQA1AHoAWgBY
>> "%~1" echo AFIAUwBaAFgARgAxAFoAWABOADAAUwBHAFYAaABaAEcAVgB5AEsAQwBkAFkATABW
>> "%~1" echo AEYAMQBaAFgATgAwAEwAVgBSAHYAYQAyAFYAdQBKAHkAeABVAFQAMAB0AEYAVABp
>> "%~1" echo AGsANwBDAGkAQQBnAGUARwBoAHkATABuAE4AbABkAEYASgBsAGMAWABWAGwAYwAz
>> "%~1" echo AFIASQBaAFcARgBrAFoAWABJAG8ASgAwAE4AdgBiAG4AUgBsAGIAbgBRAHQAVgBI
>> "%~1" echo AGwAdwBaAFMAYwBzAEoAMgBGAHcAYwBHAHgAcABZADIARgAwAGEAVwA5AHUATAAy
>> "%~1" echo ADkAagBkAEcAVgAwAEwAWABOADAAYwBtAFYAaABiAFMAYwBwAE8AdwBvAGcASQBI
>> "%~1" echo AGgAbwBjAGkANQAxAGMARwB4AHYAWQBXAFEAdQBiADIANQB3AGMAbQA5AG4AYwBt
>> "%~1" echo AFYAegBjAHoAMQBsAFAAVAA1ADcAYQBXAFkAbwBaAFMANQBzAFoAVwA1AG4AZABH
>> "%~1" echo AGgARABiADIAMQB3AGQAWABSAGgAWQBtAHgAbABLAFgAdABqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAdwBQAFUAMQBoAGQARwBnAHUAYwBtADkAMQBiAG0AUQBvAFoAUwA1AHMAYgAy
>> "%~1" echo AEYAawBaAFcAUQB2AFoAUwA1ADAAYgAzAFIAaABiAEMAbwB4AE0ARABBAHAATwAy
>> "%~1" echo AFIAeQBiADMAQQB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBp
>> "%~1" echo AGcAbgBJADIAUgB5AGIAMwBCAEkAYQBXADUAMABKAHkAawB1AGQARwBWADQAZABF
>> "%~1" echo AE4AdgBiAG4AUgBsAGIAbgBRADkASgArAFMANABpAHUAUwA4AG8ATwBTADQAcgBT
>> "%~1" echo AEEAbgBLADMAQQByAEoAeQBVAG4AZgBYADAANwBDAGkAQQBnAGMAMgBWADAAUQBu
>> "%~1" echo AFYAegBlAFMAaAAwAGMAbgBWAGwATABHADUAMQBiAEcAdwBwAE8AdwBvAGcASQBI
>> "%~1" echo AGgAbwBjAGkANQB2AGIAbQB4AHYAWQBXAFEAOQBLAEMAawA5AFAAbgB0AHoAWgBY
>> "%~1" echo AFIAQwBkAFgATgA1AEsARwBaAGgAYgBIAE4AbABMAEcANQAxAGIARwB3AHAATwAz
>> "%~1" echo AFIAeQBlAFgAdABqAGIAMgA1AHoAZABDAEIAeQBQAFUAcABUAFQAMAA0AHUAYwBH
>> "%~1" echo AEYAeQBjADIAVQBvAGUARwBoAHkATABuAEoAbABjADMAQgB2AGIAbgBOAGwAVgBH
>> "%~1" echo AFYANABkAEMAawA3AGEAVwBZAG8AYwBpADUAdgBhAHkARQA5AFAAUwBkADAAYwBu
>> "%~1" echo AFYAbABKAHkAbAAwAGEASABKAHYAZAB5AEIAdQBaAFgAYwBnAFIAWABKAHkAYgAz
>> "%~1" echo AEkAbwBjAGkANQBsAGMAbgBKAHYAYwBuAHgAOABKACsAUwA0AGkAdQBTADgAbwBP
>> "%~1" echo AFcAawBzAGUAaQAwAHAAUwBjAHAATwAyAEYAdwBhAHoAMQB5AE8AMwBOAG8AYgAz
>> "%~1" echo AGQAQgBjAEcAcwBvAGMAaQBrADcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGsAdQBJ
>> "%~1" echo AHIAawB2AEsARABsAHIAbwB6AG0AaQBKAEEAbgBMAEMAaAB5AEwAbgBCAGgAWQAy
>> "%~1" echo AHQAaABaADIAVgA4AGYASABJAHUAWgBtAGwAcwBaAFUANQBoAGIAVwBVAHAASwB5
>> "%~1" echo AGMAZwA1AGIAZQB5ADYASwBlAGoANQBwADYAUQBKAHkAdwBuAGIAMgBzAG4ASwBY
>> "%~1" echo ADEAagBZAFgAUgBqAGEAQwBoAGwASwBYAHQAdQBiADMAUgBwAFoAbgBrAG8ASgAr
>> "%~1" echo AFMANABpAHUAUwA4AG8ATwBXAGsAcwBlAGkAMABwAFMAYwBzAFoAUwA1AHQAWgBY
>> "%~1" echo AE4AegBZAFcAZABsAEwAQwBkAGwAYwBuAEkAbgBMAEQAVQB3AE0ARABBAHAATwAy
>> "%~1" echo AFIAeQBiADMAQQB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBp
>> "%~1" echo AGcAbgBZAGkAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABT
>> "%~1" echo AGYAbQBpADUAYgBtAGkANwAwAGcAUQBWAEIATABJAE8AVwBJAHMATwBpAC8AbQBl
>> "%~1" echo AG0ASABqAE8AKwA4AGoATwBhAEkAbAB1AGUAQwB1AGUAVwBIAHUAKwBtAEEAaQBl
>> "%~1" echo AGEATABxAFMAYwA3AFoASABKAHYAYwBDADUAeABkAFcAVgB5AGUAVgBOAGwAYgBH
>> "%~1" echo AFYAagBkAEcAOQB5AEsAQwBjAGoAWgBIAEoAdgBjAEUAaABwAGIAbgBRAG4ASwBT
>> "%~1" echo ADUAMABaAFgAaAAwAFEAMgA5AHUAZABHAFYAdQBkAEQAMABuADUAcAB5AHMANQBa
>> "%~1" echo AHkAdwA1AEwAaQBLADUATAB5AGcANQBaAEMATwA1ADUAUwB4AEkARQBGAEUAUQBp
>> "%~1" echo AEQAbAByAG8AbgBvAG8ANABYAGwAaQBMAEQAbAB0ADcATABvAHYANQA3AG0AagBx
>> "%~1" echo AFgAbgBtAG8AUQBnAFUAWABWAGwAYwAzAFQAagBnAEkATABsAHIAbwBuAG8AbwA0
>> "%~1" echo AFgAbABpAFkAMwBrAHYASgByAGsAdQBvAHoAbQByAEsASABuAG8AYQA3AG8AcgBx
>> "%~1" echo AFQAagBnAEkASQBuAGYAWAAwADcAQwBpAEEAZwBlAEcAaAB5AEwAbQA5AHUAWgBY
>> "%~1" echo AEoAeQBiADMASQA5AEsAQwBrADkAUABuAHQAegBaAFgAUgBDAGQAWABOADUASwBH
>> "%~1" echo AFoAaABiAEgATgBsAEwARwA1ADEAYgBHAHcAcABPADIANQB2AGQARwBsAG0AZQBT
>> "%~1" echo AGcAbgA1AEwAaQBLADUATAB5AGcANQBhAFMAeAA2AEwAUwBsAEoAeQB3AG4ANQA3
>> "%~1" echo ADIAUgA1ADcAdQBjADYAWgBTAFoANgBLACsAdgBKAHkAdwBuAFoAWABKAHkASgB5
>> "%~1" echo AGsANwBaAEgASgB2AGMAQwA1AHgAZABXAFYAeQBlAFYATgBsAGIARwBWAGoAZABH
>> "%~1" echo ADkAeQBLAEMAZABpAEoAeQBrAHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBu
>> "%~1" echo AFEAOQBKACsAYQBMAGwAdQBhAEwAdgBTAEIAQgBVAEUAcwBnADUAWQBpAHcANgBM
>> "%~1" echo ACsAWgA2AFkAZQBNADcANwB5AE0ANQBvAGkAVwA1ADQASwA1ADUAWQBlADcANgBZ
>> "%~1" echo AEMASgA1AG8AdQBwAEoAMwAwADcAQwBpAEEAZwBlAEcAaAB5AEwAbgBOAGwAYgBt
>> "%~1" echo AFEAbwBaAG0AbABzAFoAUwBrADcAQwBuADAASwBaAG4AVgB1AFkAMwBSAHAAYgAy
>> "%~1" echo ADQAZwBjADIAaAB2AGQAMABGAHcAYQB5AGgAeQBLAFgAcwBLAEkAQwBBAHYATAB5
>> "%~1" echo AEIAbwBaAFgASgB2AEMAaQBBAGcAWQAyADkAdQBjADMAUQBnAGEAVwA1AHAAZABH
>> "%~1" echo AGwAaABiAEQAMABvAGMAaQA1AHcAWQBXAE4AcgBZAFcAZABsAGYASAB4AHkATABt
>> "%~1" echo AFoAcABiAEcAVgBPAFkAVwAxAGwAZgBIAHcAbgBRAFMAYwBwAEwAbgBKAGwAYwBH
>> "%~1" echo AHgAaABZADIAVQBvAEwAMQA0AHUASwBsAHcAdQBMAHkAdwBuAEoAeQBrAHUAWQAy
>> "%~1" echo AGgAaABjAGsARgAwAEsARABBAHAATABuAFIAdgBWAFgAQgB3AFoAWABKAEQAWQBY
>> "%~1" echo AE4AbABLAEMAbAA4AGYAQwBkAEIASgB6AHMASwBJAEMAQQBrAEsAQwBkAGgAYwBH
>> "%~1" echo AHQASgBZADIAOQB1AFYARwBsAHMAWgBTAGMAcABMAG0AbAB1AGIAbQBWAHkAUwBG
>> "%~1" echo AFIATgBUAEQAMABuAFAASABOADIAWgB5AEIAMgBhAFcAVgAzAFEAbQA5ADQAUABT
>> "%~1" echo AEkAdwBJAEQAQQBnAE0AagBRAGcATQBqAFEAaQBQAGoAeAAxAGMAMgBVAGcAYQBI
>> "%~1" echo AEoAbABaAGoAMABpAEkAMgBrAHQAWQBYAEIAcgBJAGkAOAArAFAAQwA5AHoAZABt
>> "%~1" echo AGMAKwBKAHoAcwBLAEkAQwBCAHoAWgBYAFEAbwBKADIARgB3AGEAMAA1AGgAYgBX
>> "%~1" echo AFUAbgBMAEgASQB1AGMARwBGAGoAYQAyAEYAbgBaAFgAeAA4AGMAaQA1AG0AYQBX
>> "%~1" echo AHgAbABUAG0ARgB0AFoAWAB4ADgASgAyAEYAdwBjAEMANQBoAGMARwBzAG4ASwBU
>> "%~1" echo AHMASwBJAEMAQQB2AEwAeQBCAHcAYQBXAHgAcwBjAHoAbwBnAGQAbQBWAHkAYwAy
>> "%~1" echo AGwAdgBiAGkAdwBnAGMAMgBsADYAWgBTAHcAZwBjAEcAVgB5AGIAUwAxAGoAYgAz
>> "%~1" echo AFYAdQBkAEEAbwBnAEkARwBOAHYAYgBuAE4AMABJAEgAQgBsAGMAbQAxAHoAUABT
>> "%~1" echo AGgAeQBMAG4AQgBsAGMAbQAxAHAAYwAzAE4AcABiADIANQB6AGYASAB3AG4ASgB5
>> "%~1" echo AGsAdQBjADMAQgBzAGEAWABRAG8ASgAxAHgAdQBKAHkAawB1AFoAbQBsAHMAZABH
>> "%~1" echo AFYAeQBLAEgAZwA5AFAAbgBnAHAATwB3AG8AZwBJAEcATgB2AGIAbgBOADAASQBI
>> "%~1" echo AEIAagBQAFgASQB1AGMARwBWAHkAYgBXAGwAegBjADIAbAB2AGIAawBOAHYAZABX
>> "%~1" echo ADUAMABmAEgAeAB3AFoAWABKAHQAYwB5ADUAcwBaAFcANQBuAGQARwBoADgAZgBE
>> "%~1" echo AEEANwBDAGkAQQBnAGIARwBWADAASQBIAEIAcABiAEcAeAB6AFAAUwBjAG4ATwB3
>> "%~1" echo AG8AZwBJAEcAbABtAEsASABJAHUAZABtAFYAeQBjADIAbAB2AGIAawA1AGgAYgBX
>> "%~1" echo AFYAOABmAEgASQB1AGQAbQBWAHkAYwAyAGwAdgBiAGsATgB2AFoARwBVAHAAYwBH
>> "%~1" echo AGwAcwBiAEgATQByAFAAUwBjADgAYwAzAEIAaABiAGkAQgBqAGIARwBGAHoAYwB6
>> "%~1" echo ADAAaQBjAEcAbABzAGIAQwBCADIAWgBYAEkAaQBQAG4AWQBuAEsAMgBWAHoAWQB5
>> "%~1" echo AGgAeQBMAG4AWgBsAGMAbgBOAHAAYgAyADUATwBZAFcAMQBsAGYASAB3AG4AUAB5
>> "%~1" echo AGMAcABLAHkAaAB5AEwAbgBaAGwAYwBuAE4AcABiADIANQBEAGIAMgBSAGwAUAB5
>> "%~1" echo AGMAZwBLAEMAYwByAFoAWABOAGoASwBIAEkAdQBkAG0AVgB5AGMAMgBsAHYAYgBr
>> "%~1" echo AE4AdgBaAEcAVQBwAEsAeQBjAHAASgB6AG8AbgBKAHkAawByAEoAegB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANABuAE8AdwBvAGcASQBHAGwAbQBLAEgASQB1AGMAMgBsADYAWgBW
>> "%~1" echo AFIAbABlAEgAUQBwAGMARwBsAHMAYgBIAE0AcgBQAFMAYwA4AGMAMwBCAGgAYgBp
>> "%~1" echo AEIAagBiAEcARgB6AGMAegAwAGkAYwBHAGwAcwBiAEMASQArAEoAeQB0AGwAYwAy
>> "%~1" echo AE0AbwBjAGkANQB6AGEAWABwAGwAVgBHAFYANABkAEMAawByAEoAegB3AHYAYwAz
>> "%~1" echo AEIAaABiAGoANABuAE8AdwBvAGcASQBIAEIAcABiAEcAeAB6AEsAegAwAG4AUABI
>> "%~1" echo AE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AQgBwAGIARwB3AGcAYwBH
>> "%~1" echo AFYAeQBiAFMASQBnAGEAVwBRADkASQBuAEIAbABjAG0AMQBRAGEAVwB4AHMASQBq
>> "%~1" echo ADcAbQBuAFkAUABwAG0AWgBBAGcASgB5AHQAdwBZAHkAcwBuAFAAQwA5AHoAYwBH
>> "%~1" echo AEYAdQBQAGkAYwA3AEMAaQBBAGcAYQBXAFkAbwBjAGkANQB3AFkAWABKAHoAWgBV
>> "%~1" echo ADkAcgBJAFQAMAA5AEoAMwBSAHkAZABXAFUAbgBLAFgAQgBwAGIARwB4AHoASwB6
>> "%~1" echo ADAAbgBQAEgATgB3AFkAVwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBCAHAAYgBH
>> "%~1" echo AHcAZwBkADIARgB5AGIAaQBJACsANgBLAGUAagA1AHAANgBRADUAWQArAFgANgBa
>> "%~1" echo AG0AUQBQAEMAOQB6AGMARwBGAHUAUABpAGMANwBDAGkAQQBnAEoAQwBnAG4AWQBY
>> "%~1" echo AEIAcgBVAEcAbABzAGIASABNAG4ASwBTADUAcABiAG0ANQBsAGMAawBoAFUAVABV
>> "%~1" echo AHcAOQBjAEcAbABzAGIASABNADcAQwBpAEEAZwBMAHkAOABnAGQAbQBWAHkAYwAy
>> "%~1" echo AGwAdgBiAGkAQgBpAFkAVwBSAG4AWgBTAEEAbwBkAFgAQgBuAGMAbQBGAGsAWgBT
>> "%~1" echo ADkAawBiADMAZAB1AFoAMwBKAGgAWgBHAFUAdgBjADIARgB0AFoAUwBrAEsASQBD
>> "%~1" echo AEIAagBiADIANQB6AGQAQwBCAGkAWQBXAFIAbgBaAFQAMABrAEsAQwBkAGgAYwBH
>> "%~1" echo AHQAVwBaAFgASgBDAFkAVwBSAG4AWgBTAGMAcABPADIASgBoAFoARwBkAGwATABt
>> "%~1" echo AE4AcwBZAFgATgB6AFQAbQBGAHQAWgBUADAAbgBkAG0AVgB5AFEAbQBGAGsAWgAy
>> "%~1" echo AFUAbgBPAHcAbwBnAEkARwBsAG0ASwBIAEkAdQBZAFcAeAB5AFoAVwBGAGsAZQBV
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB4AGwAWgBEADAAOQBQAFMAZAAwAGMAbgBWAGwASgB5
>> "%~1" echo AGwANwBDAGkAQQBnAEkAQwBCAGoAYgAyADUAegBkAEMAQgBwAGQAagAxAHcAWQBY
>> "%~1" echo AEoAegBaAFUAbAB1AGQAQwBoAHkATABtAGwAdQBjADMAUgBoAGIARwB4AGwAWgBG
>> "%~1" echo AFoAbABjAG4ATgBwAGIAMgA1AEQAYgAyAFIAbABmAEgAdwBuAE0AQwBjAHMATQBU
>> "%~1" echo AEEAcABMAEcANQAyAFAAWABCAGgAYwBuAE4AbABTAFcANQAwAEsASABJAHUAZABt
>> "%~1" echo AFYAeQBjADIAbAB2AGIAawBOAHYAWgBHAFYAOABmAEMAYwB3AEoAeQB3AHgATQBD
>> "%~1" echo AGsANwBDAGkAQQBnAEkAQwBCAHAAWgBpAGgAdQBkAGkAWQBtAGEAWABZAHAAZQAy
>> "%~1" echo AGwAbQBLAEcANQAyAFAARwBsADIASwBYAHQAaQBZAFcAUgBuAFoAUwA1AGoAYgBH
>> "%~1" echo AEYAegBjADAANQBoAGIAVwBVADkASgAzAFoAbABjAGsASgBoAFoARwBkAGwASQBI
>> "%~1" echo AE4AbwBiADMAYwBnAFoARwA5ADMAYgBpAGMANwBZAG0ARgBrAFoAMgBVAHUAZABH
>> "%~1" echo AFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBKACsASwBhAG8AQwBEAHAAbQBZ
>> "%~1" echo ADMAbgB1AHEAZgB2AHYASgByAG8AcgByADcAbABwAEkAYwBnAGQAaQBjAHIAYQBY
>> "%~1" echo AFkAcgBKAHkARABpAGgAcABJAGcAUQBWAEIATABJAEgAWQBuAEsAMgA1ADIASwB5
>> "%~1" echo AGYAdgB2AEkAagBwAHUANQBqAG8AcgBxAFQAbAB0ADcATABsAGkANwA3AHAAZwBJ
>> "%~1" echo AG4AbABoAFkASABvAHIAcgBqAHAAbQBZADMAbgB1AHEAZgB2AHYASQBrAG4ATwB5
>> "%~1" echo AFEAbwBKADIAOQB3AGQARQBSAHYAZAAyADUAbgBjAG0ARgBrAFoAUwBjAHAATABt
>> "%~1" echo AE4AbwBaAFcATgByAFoAVwBRADkAZABIAEoAMQBaAFgAMABLAEkAQwBBAGcASQBD
>> "%~1" echo AEEAZwBaAFcAeAB6AFoAUwBCAHAAWgBpAGgAdQBkAGoAMAA5AFAAVwBsADIASwBY
>> "%~1" echo AHQAaQBZAFcAUgBuAFoAUwA1AGoAYgBHAEYAegBjADAANQBoAGIAVwBVADkASgAz
>> "%~1" echo AFoAbABjAGsASgBoAFoARwBkAGwASQBIAE4AbwBiADMAYwBuAE8AMgBKAGgAWgBH
>> "%~1" echo AGQAbABMAG4AUgBsAGUASABSAEQAYgAyADUAMABaAFcANQAwAFAAUwBmAG4AaQBZ
>> "%~1" echo AGoAbQBuAEsAegBuAG0ANwBqAGwAawBJAHcAZwBkAGkAYwByAGEAWABZAHIASgAr
>> "%~1" echo ACsAOABpAE8AbQBIAGoAZQBpAGoAaABlAFMALwBuAGUAZQBWAG0AZQBhAFYAcwBP
>> "%~1" echo AGEATgByAHUAKwA4AGkAUwBkADkAQwBpAEEAZwBJAEMAQQBnAEkARwBWAHMAYwAy
>> "%~1" echo AFYANwBZAG0ARgBrAFoAMgBVAHUAWQAyAHgAaABjADMATgBPAFkAVwAxAGwAUABT
>> "%~1" echo AGQAMgBaAFgASgBDAFkAVwBSAG4AWgBTAEIAegBhAEcAOQAzAEkASABWAHcASgB6
>> "%~1" echo AHQAaQBZAFcAUgBuAFoAUwA1ADAAWgBYAGgAMABRADIAOQB1AGQARwBWAHUAZABE
>> "%~1" echo ADAAbgA1AFkAMgBIADUANwBxAG4ANwA3AHkAYQA2AEsANgArADUAYQBTAEgASQBI
>> "%~1" echo AFkAbgBLADIAbAAyAEsAeQBjAGcANABvAGEAUwBJAEUARgBRAFMAeQBCADIASgB5
>> "%~1" echo AHQAdQBkAG4AMQA5AEMAaQBBAGcASQBDAEIAbABiAEgATgBsAGUAMgBKAGgAWgBH
>> "%~1" echo AGQAbABMAG0ATgBzAFkAWABOAHoAVABtAEYAdABaAFQAMABuAGQAbQBWAHkAUQBt
>> "%~1" echo AEYAawBaADIAVQBnAGMAMgBoAHYAZAB5AGMANwBZAG0ARgBrAFoAMgBVAHUAZABH
>> "%~1" echo AFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBKACsAaQB1AHYAdQBXAGsAaAAr
>> "%~1" echo AFcAMwBzAHUAVwB1AGkAZQBpAGoAaABTAEIAMgBKAHkAdABsAGMAMgBNAG8AYwBp
>> "%~1" echo ADUAcABiAG4ATgAwAFkAVwB4AHMAWgBXAFIAVwBaAFgASgB6AGEAVwA5AHUAUQAy
>> "%~1" echo ADkAawBaAFMAbAA5AEMAaQBBAGcASQBDAEEAawBLAEMAZAB2AGMASABSAFMAWgBY
>> "%~1" echo AEIAcwBZAFcATgBsAEoAeQBrAHUAWQAyAGgAbABZADIAdABsAFoARAAxADAAYwBu
>> "%~1" echo AFYAbABPAHcAbwBnAEkASAAwAEsASQBDAEEAawBLAEMAZABoAGMARwB0AFEAWgBY
>> "%~1" echo AEoAdABjAHkAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABY
>> "%~1" echo AEIAbABjAG0AMQB6AEwAbQB4AGwAYgBtAGQAMABhAEQAOQB3AFoAWABKAHQAYwB5
>> "%~1" echo ADUAcQBiADIAbAB1AEsAQwBkAGMAYgBpAGMAcABPAGkAZgB2AHYASQBqAG0AbgBL
>> "%~1" echo AHIAbwBwADYAUABtAG4AcABEAGwAaQBMAEQAbQBuAFkAUABwAG0AWgBEAGwAbwA3
>> "%~1" echo AEQAbQBtAEkANwB2AHYASQBrAG4ATwB3AG8AZwBJAEMAUQBvAEoAMgBGAHcAYQAx
>> "%~1" echo AEIAbABjAG0AMQB6AEoAeQBrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABu
>> "%~1" echo AEoAbABiAFcAOQAyAFoAUwBnAG4AYwAyAGgAdgBkAHkAYwBwAE8AdwBvAGcASQBD
>> "%~1" echo AFEAbwBKADIARgB3AGEAMABSAHkAYgAzAEEAbgBLAFMANQB6AGQASABsAHMAWgBT
>> "%~1" echo ADUAawBhAFgATgB3AGIARwBGADUAUABTAGQAdQBiADIANQBsAEoAegBzAEsASQBD
>> "%~1" echo AEEAawBLAEMAZABoAGMARwB0AEUAWgBYAFIAaABhAFcAdwBuAEsAUwA1AHoAZABI
>> "%~1" echo AGwAcwBaAFMANQBrAGEAWABOAHcAYgBHAEYANQBQAFMAYwBuAE8AdwBwADkAQwBt
>> "%~1" echo AEYAegBlAFcANQBqAEkARwBaADEAYgBtAE4AMABhAFcAOQB1AEkARwBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAeABCAGMARwBzAG8ASwBYAHMASwBJAEMAQgBwAFoAaQBnAGgAWQBY
>> "%~1" echo AEIAcgBmAEgAdwBoAFkAWABCAHIATABuAFYAdwBiAEcAOQBoAFoARQBsAGsASwBY
>> "%~1" echo AEoAbABkAEgAVgB5AGIAaQBCAHUAYgAzAFIAcABaAG4AawBvAEoAKwBpAHYAdAAr
>> "%~1" echo AFcARgBpAE8AUwA0AGkAdQBTADgAbwBDAEIAQgBVAEUAcwBuAEwAQwBmAG0AaQA1
>> "%~1" echo AGIAbABoAGEAWABtAGkASgBiAHAAZwBJAG4AbQBpADYAbgBrAHUASQBEAGsAdQBL
>> "%~1" echo AG8AZwBMAG0ARgB3AGEAeQBEAG0AbABvAGYAawB1ADcAYgBqAGcASQBJAG4ATABD
>> "%~1" echo AGQAMwBZAFgASgB1AEoAeQBrADcAQwBpAEEAZwBhAFcAWQBvAFkAbgBWAHoAZQBT
>> "%~1" echo AGwAeQBaAFgAUgAxAGMAbQA0AGcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGwAdAA3
>> "%~1" echo AEwAbQBuAEkAbgBtAGsANAAzAGsAdgBaAHoAbQBpAGEAZgBvAG8AWQB6AGsAdQBL
>> "%~1" echo ADAAbgBMAEMAZgBvAHIANwBmAG4AcgBZAG4AbAB2AG8AWABrAHUASQByAGsAdQBJ
>> "%~1" echo AEQAbQBuAGEASABsAGsAYgAzAGsAdQA2AFQAbAByAG8AegBtAGkASgBEAGoAZwBJ
>> "%~1" echo AEkAbgBMAEMAZAAzAFkAWABKAHUASgB5AGsANwBDAGkAQQBnAFkAMgA5AHUAYwAz
>> "%~1" echo AFEAZwBjAGoAMQBoAGMARwBzADcAQwBpAEEAZwBZADIAOQB1AGMAMwBRAGcAYgAz
>> "%~1" echo AEIAMABjAHoAMQBiAFgAVAB0AHAAWgBpAGcAawBLAEMAZAB2AGMASABSAFMAWgBY
>> "%~1" echo AEIAcwBZAFcATgBsAEoAeQBrAHUAWQAyAGgAbABZADIAdABsAFoAQwBsAHYAYwBI
>> "%~1" echo AFIAegBMAG4AQgAxAGMAMgBnAG8ASgB5ADEAeQBKAHkAawA3AGEAVwBZAG8ASgBD
>> "%~1" echo AGcAbgBiADMAQgAwAFIAMwBKAGgAYgBuAFEAbgBLAFMANQBqAGEARwBWAGoAYQAy
>> "%~1" echo AFYAawBLAFcAOQB3AGQASABNAHUAYwBIAFYAegBhAEMAZwBuAEwAVwBjAG4ASwBU
>> "%~1" echo AHQAcABaAGkAZwBrAEsAQwBkAHYAYwBIAFIARQBiADMAZAB1AFoAMwBKAGgAWgBH
>> "%~1" echo AFUAbgBLAFMANQBqAGEARwBWAGoAYQAyAFYAawBLAFcAOQB3AGQASABNAHUAYwBI
>> "%~1" echo AFYAegBhAEMAZwBuAEwAVwBRAG4ASwBUAHMASwBJAEMAQgBqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAMQBaAGoAMABrAEsAQwBkAHYAYwBIAFIAVgBiAG0AbAB1AGMAMwBSAGgAYgBH
>> "%~1" echo AHgARwBhAFgASgB6AGQAQwBjAHAATABtAE4AbwBaAFcATgByAFoAVwBRADcAQwBp
>> "%~1" echo AEEAZwBZADIAOQB1AGMAMwBRAGcAWQAyADEAawBQAFMAZABoAFoARwBJAGcATABY
>> "%~1" echo AE0AZwBQAEcAUgBsAGQAbQBsAGoAWgBUADQAZwBhAFcANQB6AGQARwBGAHMAYgBD
>> "%~1" echo AEEAbgBLADIAOQB3AGQASABNAHUAYQBtADkAcABiAGkAZwBuAEkAQwBjAHAASwB5
>> "%~1" echo AGMAZwBKAHkAcwBvAGMAaQA1AG0AYQBXAHgAbABUAG0ARgB0AFoAWAB4ADgASgAy
>> "%~1" echo AEYAdwBjAEMANQBoAGMARwBzAG4ASwBUAHMASwBJAEMAQgBqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAdABjADIAYwA5AEoAKwBXAE4AcwArAFcAdwBoAHUAYQBKAHAAKwBpAGgAagBP
>> "%~1" echo ACsAOABtAGwAeAB1AEoAeQB0AGoAYgBXAFEAcgBLAEgAVgBtAFAAeQBkAGMAYgB1
>> "%~1" echo ACsAOABpAE8AVwB1AGkAZQBpAGoAaABlAFcASgBqAGUAUwA4AG0AdQBXAEYAaQBP
>> "%~1" echo AFcATgB1AE8AaQA5AHYAUwBBAG4ASwB5AGgAeQBMAG4AQgBoAFkAMgB0AGgAWgAy
>> "%~1" echo AFYAOABmAEMAZgBvAHIANgBYAGwAagBJAFUAbgBLAFMAcwBuADcANwB5AE0ANQBy
>> "%~1" echo AGkARgA2AFoAbQBrADUAWQBXADIANQBwAFcAdwA1AG8AMgB1ADcANwB5AEoASgB6
>> "%~1" echo AG8AbgBKAHkAawByAEoAMQB4AHUAWABHADcAbgBtADYANwBtAG8ASQBmAHYAdgBK
>> "%~1" echo AG8AbgBLAHkAaAB5AEwAbgBCAGgAWQAyAHQAaABaADIAVgA4AGYAQwBmAG0AbgBL
>> "%~1" echo AHIAbgBuADYAWABsAGoASQBYAGwAawBJADAAbgBLAFMAcwBuAEkAQwBBAG4ASwB5
>> "%~1" echo AGgAeQBMAG4AWgBsAGMAbgBOAHAAYgAyADUATwBZAFcAMQBsAGYASAB3AG4ASgB5
>> "%~1" echo AGsANwBDAGkAQQBnAFkAMgA5AHUAYwAzAFEAZwBiADIAcwA5AFkAWABkAGgAYQBY
>> "%~1" echo AFEAZwBZAFgATgByAFEAMgA5AHUAWgBtAGwAeQBiAFMAZwBuADUANgBHAHUANgBL
>> "%~1" echo ADYAawA1AGEANgBKADYASwBPAEYASQBFAEYAUQBTAHkAYwBzAGIAWABOAG4ASwBU
>> "%~1" echo AHMASwBJAEMAQgBwAFoAaQBnAGgAYgAyAHMAcABjAG0AVgAwAGQAWABKAHUATwB3
>> "%~1" echo AG8AZwBJAEcATgB2AGIAbgBOADAASQBHAEoAMABiAGoAMABrAEsAQwBkAHAAYgBu
>> "%~1" echo AE4AMABZAFcAeABzAFEAbgBSAHUASgB5AGsAcwBaAG0AbABzAGIARAAwAGsASwBD
>> "%~1" echo AGQAcABiAG4ATgAwAFkAVwB4AHMAUgBtAGwAcwBiAEMAYwBwAEwARwB4AGgAWQBt
>> "%~1" echo AFYAcwBQAFMAUQBvAEoAMgBsAHUAYwAzAFIAaABiAEcAeABNAFkAVwBKAGwAYgBD
>> "%~1" echo AGMAcABMAEgATgAwAFkAVwBkAGwAVQBtADkAMwBQAFMAUQBvAEoAMwBOADAAWQBX
>> "%~1" echo AGQAbABVAG0AOQAzAEoAeQBrAHMAYgAzAFYAMABQAFMAUQBvAEoAMgBGAGsAWQBr
>> "%~1" echo ADkAMQBkAEMAYwBwAE8AdwBvAGcASQBDADgAdgBJAEcAVgB1AGQARwBWAHkASQBH
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB4AHAAYgBtAGMAZwBjADMAUgBoAGQARwBVADYASQBH
>> "%~1" echo AEoAMQBkAEgAUgB2AGIAaQBCAHQAYgAzAEoAdwBhAEgATQBnAGEAVwA1ADAAYgB5
>> "%~1" echo AEIAaABJAEgAQgB5AGIAMgBkAHkAWgBYAE4AegBJAEgAUgB5AFkAVwBOAHIAQwBp
>> "%~1" echo AEEAZwBjADIAVgAwAFEAbgBWAHoAZQBTAGgAMABjAG4AVgBsAEwARwA1ADEAYgBH
>> "%~1" echo AHcAcABPADIASgAwAGIAaQA1AGsAYQBYAE4AaABZAG0AeABsAFoARAAxADAAYwBu
>> "%~1" echo AFYAbABPADIASgAwAGIAaQA1AGoAYgBHAEYAegBjADAANQBoAGIAVwBVADkASgAy
>> "%~1" echo AGwAdQBjADMAUgBoAGIARwB4AEMAZABHADQAZwBhAFcANQB6AGQARwBGAHMAYgBH
>> "%~1" echo AGwAdQBaAHkAYwA3AFoAbQBsAHMAYgBDADUAegBkAEgAbABzAFoAUwA1ADMAYQBX
>> "%~1" echo AFIAMABhAEQAMABuAE0AQwBjADcAQwBpAEEAZwBiAEcARgBpAFoAVwB3AHUAZABH
>> "%~1" echo AFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBKACsAVwB1AGkAZQBpAGoAaABl
>> "%~1" echo AFMANAByAFMAQQB3AEoAUwBjADcAYwAzAFIAaABaADIAVgBTAGIAMwBjAHUAWQAy
>> "%~1" echo AHgAaABjADMATgBNAGEAWABOADAATABtAEYAawBaAEMAZwBuAGMAMgBoAHYAZAB5
>> "%~1" echo AGMAcABPADMATgBsAGQAQwBnAG4AYwAzAFIAaABaADIAVgBVAFoAWABoADAASgB5
>> "%~1" echo AHcAbgA2AEwAKwBlADUAbwA2AGwANQBMAGkAdAA0AG8AQwBtAEoAeQBrADcAYgAz
>> "%~1" echo AFYAMABMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMANQBoAFoARwBRAG8ASgAz
>> "%~1" echo AE4AbwBiADMAYwBuAEsAVAB0AHYAZABYAFEAdQBkAEcAVgA0AGQARQBOAHYAYgBu
>> "%~1" echo AFIAbABiAG4AUQA5AEoAeQBjADcAQwBpAEEAZwBZADIAOQB1AGMAMwBRAGcAZABE
>> "%~1" echo AEEAOQBSAEcARgAwAFoAUwA1AHUAYgAzAGMAbwBLAFQAdABqAGIAMgA1AHoAZABD
>> "%~1" echo AEIAMABhAFcAMQBsAGMAagAxAHoAWgBYAFIASgBiAG4AUgBsAGMAbgBaAGgAYgBD
>> "%~1" echo AGcAbwBLAFQAMAArAGUAMgBOAHYAYgBuAE4AMABJAEgATQA5AFQAVwBGADAAYQBD
>> "%~1" echo ADUAbQBiAEcAOQB2AGMAaQBnAG8AUgBHAEYAMABaAFMANQB1AGIAMwBjAG8ASwBT
>> "%~1" echo ADEAMABNAEMAawB2AE0AVABBAHcATQBDAGsANwBjADIAVgAwAEsAQwBkAGwAYgBH
>> "%~1" echo AEYAdwBjADIAVgBrAEoAeQB4AE4AWQBYAFIAbwBMAG0AWgBzAGIAMgA5AHkASwBI
>> "%~1" echo AE0AdgBOAGoAQQBwAEsAeQBjADYASgB5AHQAVABkAEgASgBwAGIAbQBjAG8AYwB5
>> "%~1" echo AFUAMgBNAEMAawB1AGMARwBGAGsAVQAzAFIAaABjAG4AUQBvAE0AaQB3AG4ATQBD
>> "%~1" echo AGMAcABLAFgAMABzAE0AagBVAHcASwBUAHMASwBJAEMAQgBzAFoAWABRAGcAWQAz
>> "%~1" echo AFYAeQBVAEcATgAwAFAAVABBADcAQwBpAEEAZwBaAG4AVgB1AFkAMwBSAHAAYgAy
>> "%~1" echo ADQAZwBjADIAVgAwAFUARwBOADAASwBIAEEAcABlADIATgAxAGMAbABCAGoAZABE
>> "%~1" echo ADEATgBZAFgAUgBvAEwAbQAxAGgAZQBDAGgAagBkAFgASgBRAFkAMwBRAHMAYwBD
>> "%~1" echo AGsANwBaAG0AbABzAGIAQwA1AHoAZABIAGwAcwBaAFMANQAzAGEAVwBSADAAYQBE
>> "%~1" echo ADEAagBkAFgASgBRAFkAMwBRAHIASgB5AFUAbgBPADIAeABoAFkAbQBWAHMATABu
>> "%~1" echo AFIAbABlAEgAUgBEAGIAMgA1ADAAWgBXADUAMABQAFMAZgBsAHIAbwBuAG8AbwA0
>> "%~1" echo AFgAawB1AEsAMABnAEoAeQB0AGoAZABYAEoAUQBZADMAUQByAEoAeQBVAG4AZgBR
>> "%~1" echo AG8AZwBJAEcAeABsAGQAQwBCAHgAYwB6ADAAbgBMADIARgB3AGEAUwA5AGgAYwBH
>> "%~1" echo AHMAdgBhAFcANQB6AGQARwBGAHMAYgBDADEAegBkAEgASgBsAFkAVwAwAC8AWQAy
>> "%~1" echo ADkAdQBaAG0AbAB5AGIAVAAxAFoAUgBWAE0AbQBkAEcAOQByAFoAVwA0ADkASgB5
>> "%~1" echo AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwARABiADIAMQB3AGIAMgA1AGwAYgBu
>> "%~1" echo AFEAbwBWAEUAOQBMAFIAVQA0AHAASwB5AGMAbQBkAFgAQgBzAGIAMgBGAGsAUwBX
>> "%~1" echo AFEAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIAMgAxAHcAYgAy
>> "%~1" echo ADUAbABiAG4AUQBvAGMAaQA1ADEAYwBHAHgAdgBZAFcAUgBKAFoAQwBrADcAQwBp
>> "%~1" echo AEEAZwBjAFgATQByAFAAUwBjAG0AYwBtAFYAdwBiAEcARgBqAFoAVAAwAG4ASwB5
>> "%~1" echo AGcAawBLAEMAZAB2AGMASABSAFMAWgBYAEIAcwBZAFcATgBsAEoAeQBrAHUAWQAy
>> "%~1" echo AGgAbABZADIAdABsAFoARAA4AHgATwBqAEEAcABLAHkAYwBtAFoAMwBKAGgAYgBu
>> "%~1" echo AFEAOQBKAHkAcwBvAEoAQwBnAG4AYgAzAEIAMABSADMASgBoAGIAbgBRAG4ASwBT
>> "%~1" echo ADUAagBhAEcAVgBqAGEAMgBWAGsAUAB6AEUANgBNAEMAawByAEoAeQBaAGsAYgAz
>> "%~1" echo AGQAdQBaADMASgBoAFoARwBVADkASgB5AHMAbwBKAEMAZwBuAGIAMwBCADAAUgBH
>> "%~1" echo ADkAMwBiAG0AZAB5AFkAVwBSAGwASgB5AGsAdQBZADIAaABsAFkAMgB0AGwAWgBE
>> "%~1" echo ADgAeABPAGoAQQBwAEsAeQBjAG0AZABXADUAcABiAG4ATgAwAFkAVwB4AHMAUgBt
>> "%~1" echo AGwAeQBjADMAUQA5AEoAeQBzAG8AZABXAFkALwBNAFQAbwB3AEsAVABzAEsASQBD
>> "%~1" echo AEIAcABaAGkAaAB5AEwAbgBCAGgAWQAyAHQAaABaADIAVQBwAGMAWABNAHIAUABT
>> "%~1" echo AGMAbQBjAEcARgBqAGEAMgBGAG4AWgBUADAAbgBLADIAVgB1AFkAMgA5AGsAWgBW
>> "%~1" echo AFYAUwBTAFUATgB2AGIAWABCAHYAYgBtAFYAdQBkAEMAaAB5AEwAbgBCAGgAWQAy
>> "%~1" echo AHQAaABaADIAVQBwAE8AdwBvAGcASQBHADUAdgBkAEcAbABtAGUAUwBnAG4ANQBi
>> "%~1" echo AHkAQQA1AGEAZQBMADUAYQA2AEoANgBLAE8ARgBKAHkAeAB5AEwAbgBCAGgAWQAy
>> "%~1" echo AHQAaABaADIAVgA4AGYASABJAHUAWgBtAGwAcwBaAFUANQBoAGIAVwBVAHMASgAz
>> "%~1" echo AGQAaABjAG0ANABuAEwARABJAHcATQBEAEEAcABPAHcAbwBnAEkARwBOAHYAYgBu
>> "%~1" echo AE4AMABJAEcAVgB6AFAAVwA1AGwAZAB5AEIARgBkAG0AVgB1AGQARgBOAHYAZABY
>> "%~1" echo AEoAagBaAFMAaAB4AGMAeQBrADcAQwBpAEEAZwBaAG4AVgB1AFkAMwBSAHAAYgAy
>> "%~1" echo ADQAZwBZAFgAQgB3AFoAVwA1AGsAVAAzAFYAMABLAEcAeABwAGIAbQBVAHAAZQAy
>> "%~1" echo ADkAMQBkAEMANQAwAFoAWABoADAAUQAyADkAdQBkAEcAVgB1AGQAQwBzADkASwBH
>> "%~1" echo ADkAMQBkAEMANQAwAFoAWABoADAAUQAyADkAdQBkAEcAVgB1AGQARAA4AG4AWABH
>> "%~1" echo ADQAbgBPAGkAYwBuAEsAUwB0AHMAYQBXADUAbABPADIAOQAxAGQAQwA1AHoAWQAz
>> "%~1" echo AEoAdgBiAEcAeABVAGIAMwBBADkAYgAzAFYAMABMAG4ATgBqAGMAbQA5AHMAYgBF
>> "%~1" echo AGgAbABhAFcAZABvAGQASAAwAEsASQBDAEIAbABjAHkANQBoAFoARwBSAEYAZABt
>> "%~1" echo AFYAdQBkAEUAeABwAGMAMwBSAGwAYgBtAFYAeQBLAEMAZAB6AGQARwBGAG4AWgBT
>> "%~1" echo AGMAcwBaAFQAMAArAGUAMwBSAHkAZQBYAHQAagBiADIANQB6AGQAQwBCAGsAUABV
>> "%~1" echo AHAAVABUADAANAB1AGMARwBGAHkAYwAyAFUAbwBaAFMANQBrAFkAWABSAGgASwBU
>> "%~1" echo AHQAegBaAFgAUQBvAEoAMwBOADAAWQBXAGQAbABWAEcAVgA0AGQAQwBjAHMAWgBD
>> "%~1" echo ADUAMABaAFgAaAAwAGYASAB3AG4ASgB5AGsANwBhAFcAWQBvAFoAQwA1AHcAWgBY
>> "%~1" echo AEoAagBaAFcANQAwAEsAWABOAGwAZABGAEIAagBkAEMAaAB3AFkAWABKAHoAWgBV
>> "%~1" echo AGwAdQBkAEMAaABrAEwAbgBCAGwAYwBtAE4AbABiAG4AUQBzAE0AVABBAHAAZgBI
>> "%~1" echo AHcAdwBLAFgAMQBqAFkAWABSAGoAYQBDAGgAZgBLAFgAdAA5AGYAUwBrADcAQwBp
>> "%~1" echo AEEAZwBaAFgATQB1AFkAVwBSAGsAUgBYAFoAbABiAG4AUgBNAGEAWABOADAAWgBX
>> "%~1" echo ADUAbABjAGkAZwBuAGIAMwBWADAAYwBIAFYAMABKAHkAeABsAFAAVAA1ADcAZABI
>> "%~1" echo AEoANQBlADIATgB2AGIAbgBOADAASQBHAFEAOQBTAGwATgBQAFQAaQA1AHcAWQBY
>> "%~1" echo AEoAegBaAFMAaABsAEwAbQBSAGgAZABHAEUAcABPADIAbABtAEsARwBRAHUAYgBH
>> "%~1" echo AGwAdQBaAFMAbABoAGMASABCAGwAYgBtAFIAUABkAFgAUQBvAFoAQwA1AHMAYQBX
>> "%~1" echo ADUAbABLAFgAMQBqAFkAWABSAGoAYQBDAGgAZgBLAFgAdAA5AGYAUwBrADcAQwBp
>> "%~1" echo AEEAZwBaAFgATQB1AFkAVwBSAGsAUgBYAFoAbABiAG4AUgBNAGEAWABOADAAWgBX
>> "%~1" echo ADUAbABjAGkAZwBuAFoARwA5AHUAWgBTAGMAcwBaAFQAMAArAGUAdwBvAGcASQBD
>> "%~1" echo AEEAZwBaAFgATQB1AFkAMgB4AHYAYwAyAFUAbwBLAFQAdABqAGIARwBWAGgAYwBr
>> "%~1" echo AGwAdQBkAEcAVgB5AGQAbQBGAHMASwBIAFIAcABiAFcAVgB5AEsAVAB0AHoAWgBY
>> "%~1" echo AFIAQwBkAFgATgA1AEsARwBaAGgAYgBIAE4AbABMAEcANQAxAGIARwB3AHAATwAy
>> "%~1" echo AEoAMABiAGkANQBrAGEAWABOAGgAWQBtAHgAbABaAEQAMQBtAFkAVwB4AHoAWgBU
>> "%~1" echo AHMASwBJAEMAQQBnAEkARwB4AGwAZABDAEIAawBQAFgAdAA5AE8AMwBSAHkAZQBY
>> "%~1" echo AHQAawBQAFUAcABUAFQAMAA0AHUAYwBHAEYAeQBjADIAVQBvAFoAUwA1AGsAWQBY
>> "%~1" echo AFIAaABLAFgAMQBqAFkAWABSAGoAYQBDAGgAZgBLAFgAdAA5AEMAaQBBAGcASQBD
>> "%~1" echo AEIAcABaAGkAaABrAEwAbQA5AHIAUABUADAAOQBKADMAUgB5AGQAVwBVAG4ASwBY
>> "%~1" echo AHMASwBJAEMAQQBnAEkAQwBBAGcAYwAyAFYAMABVAEcATgAwAEsARABFAHcATQBD
>> "%~1" echo AGsANwBZAG4AUgB1AEwAbQBOAHMAWQBYAE4AegBUAG0ARgB0AFoAVAAwAG4AYQBX
>> "%~1" echo ADUAegBkAEcARgBzAGIARQBKADAAYgBpAEIAawBiADIANQBsAEoAegBzAEsASQBD
>> "%~1" echo AEEAZwBJAEMAQQBnAGIARwBGAGkAWgBXAHcAdQBhAFcANQB1AFoAWABKAEkAVgBF
>> "%~1" echo ADEATQBQAFMAYwA4AGMAMwBaAG4ASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYQBH
>> "%~1" echo AHMAaQBJAEgAWgBwAFoAWABkAEMAYgAzAGcAOQBJAGoAQQBnAE0AQwBBAHkATgBD
>> "%~1" echo AEEAeQBOAEMASQArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQAVABRAGcATQBU
>> "%~1" echo AEoAcwBOAFMAQQAxAGIARABFAHgATABUAEUAeABJAGkAOAArAFAAQwA5AHoAZABt
>> "%~1" echo AGMAKwBJAE8AVwB1AGkAZQBpAGoAaABlAGEASQBrAE8AVwBLAG4AeQBjADcAQwBp
>> "%~1" echo AEEAZwBJAEMAQQBnAEkASABOAGwAZABDAGcAbgBjADMAUgBoAFoAMgBWAFUAWgBY
>> "%~1" echo AGgAMABKAHkAdwBuADUAYQA2AE0ANQBvAGkAUQBKAHkAawA3AEoAQwBnAG4AWQBY
>> "%~1" echo AEIAdwBRADIARgB5AFoAQwBjAHAATABtAE4AcwBZAFgATgB6AFQARwBsAHoAZABD
>> "%~1" echo ADUAaABaAEcAUQBvAEoAMgBkAHMAYgAzAGMAbgBLAFQAcwBLAEkAQwBBAGcASQBD
>> "%~1" echo AEEAZwBiAG0AOQAwAGEAVwBaADUASwBDAGYAbAByAG8AbgBvAG8ANABYAG0AaQBK
>> "%~1" echo AEQAbABpAHAAOABuAEwARwBRAHUAYgBXAFYAegBjADIARgBuAFoAWAB4ADgAYwBp
>> "%~1" echo ADUAdwBZAFcATgByAFkAVwBkAGwAZgBIAHgAeQBMAG0AWgBwAGIARwBWAE8AWQBX
>> "%~1" echo ADEAbABMAEMAZAB2AGEAeQBjAHMATgBEAFkAdwBNAEMAawA3AGMAbQBWAG0AYwBt
>> "%~1" echo AFYAegBhAEMAaABtAFkAVwB4AHoAWgBTAGsANwBiAEcAOQBoAFoARQB4AHYAWgAz
>> "%~1" echo AE0AbwBaAG0ARgBzAGMAMgBVAHAATwB3AG8AZwBJAEMAQQBnAGYAVwBWAHMAYwAy
>> "%~1" echo AFYANwBDAGkAQQBnAEkAQwBBAGcASQBHAEoAMABiAGkANQBqAGIARwBGAHoAYwAw
>> "%~1" echo ADUAaABiAFcAVQA5AEoAMgBsAHUAYwAzAFIAaABiAEcAeABDAGQARwA0AGcAWgBt
>> "%~1" echo AEYAcABiAEcAVgBrAEoAegB0AHMAWQBXAEoAbABiAEMANQAwAFoAWABoADAAUQAy
>> "%~1" echo ADkAdQBkAEcAVgB1AGQARAAwAG4ANQBhADYASgA2AEsATwBGADUAYQBTAHgANgBM
>> "%~1" echo AFMAbABKAHoAcwBLAEkAQwBBAGcASQBDAEEAZwBjADIAVgAwAEsAQwBkAHoAZABH
>> "%~1" echo AEYAbgBaAFYAUgBsAGUASABRAG4ATABHAFEAdQBiAFcAVgB6AGMAMgBGAG4AWgBY
>> "%~1" echo AHgAOABKACsAVwB1AGkAZQBpAGoAaABlAFcAawBzAGUAaQAwAHAAUwBjAHAATwB3
>> "%~1" echo AG8AZwBJAEMAQQBnAEkAQwBCAHUAYgAzAFIAcABaAG4AawBvAEoAKwBXAHUAaQBl
>> "%~1" echo AGkAagBoAGUAVwBrAHMAZQBpADAAcABTAGMAcwBaAEMANQB0AFoAWABOAHoAWQBX
>> "%~1" echo AGQAbABmAEgAdwBuADUAYQA2AEoANgBLAE8ARgA1AGEAUwB4ADYATABTAGwASgB5
>> "%~1" echo AHcAbgBaAFgASgB5AEoAeQB3ADIATQBEAEEAdwBLAFQAdABzAGIAMgBGAGsAVABH
>> "%~1" echo ADkAbgBjAHkAaABtAFkAVwB4AHoAWgBTAGsANwBDAGkAQQBnAEkAQwBBAGcASQBD
>> "%~1" echo ADgAdgBJAEcAeABsAGQAQwBCADAAYQBHAFUAZwBkAFgATgBsAGMAaQBCAHkAWgBY
>> "%~1" echo AFIAeQBlAFQAbwBnAGMAbQBWADIAWgBYAEoAMABJAEgAUgBvAFoAUwBCAGkAZABY
>> "%~1" echo AFIAMABiADIANABnAGQARwA4AGcAYQBXAFIAcwBaAFMAQgBoAFoAbgBSAGwAYwBp
>> "%~1" echo AEIAaABJAEcAMQB2AGIAVwBWAHUAZABBAG8AZwBJAEMAQQBnAEkAQwBCAHoAWgBY
>> "%~1" echo AFIAVQBhAFcAMQBsAGIAMwBWADAASwBDAGcAcABQAFQANQA3AFkAbgBSAHUATABt
>> "%~1" echo AE4AcwBZAFgATgB6AFQAbQBGAHQAWgBUADAAbgBhAFcANQB6AGQARwBGAHMAYgBF
>> "%~1" echo AEoAMABiAGkAYwA3AGIARwBGAGkAWgBXAHcAdQBkAEcAVgA0AGQARQBOAHYAYgBu
>> "%~1" echo AFIAbABiAG4AUQA5AEoAKwBtAEgAagBlAGkAdgBsAGUAVwB1AGkAZQBpAGoAaABT
>> "%~1" echo AGMANwBaAG0AbABzAGIAQwA1AHoAZABIAGwAcwBaAFMANQAzAGEAVwBSADAAYQBE
>> "%~1" echo ADAAbgBNAEMAZAA5AEwARABJADIATQBEAEEAcABPAHcAbwBnAEkAQwBBAGcAZgBR
>> "%~1" echo AG8AZwBJAEgAMABwAE8AdwBvAGcASQBHAFYAegBMAG0AOQB1AFoAWABKAHkAYgAz
>> "%~1" echo AEkAOQBLAEMAawA5AFAAbgB0AGwAYwB5ADUAagBiAEcAOQB6AFoAUwBnAHAATwAy
>> "%~1" echo AE4AcwBaAFcARgB5AFMAVwA1ADAAWgBYAEoAMgBZAFcAdwBvAGQARwBsAHQAWgBY
>> "%~1" echo AEkAcABPADMATgBsAGQARQBKADEAYwAzAGsAbwBaAG0ARgBzAGMAMgBVAHMAYgBu
>> "%~1" echo AFYAcwBiAEMAawA3AFkAbgBSAHUATABtAFIAcABjADIARgBpAGIARwBWAGsAUABX
>> "%~1" echo AFoAaABiAEgATgBsAE8AMgBKADAAYgBpADUAagBiAEcARgB6AGMAMAA1AGgAYgBX
>> "%~1" echo AFUAOQBKADIAbAB1AGMAMwBSAGgAYgBHAHgAQwBkAEcANABnAFoAbQBGAHAAYgBH
>> "%~1" echo AFYAawBKAHoAdABzAFkAVwBKAGwAYgBDADUAMABaAFgAaAAwAFEAMgA5AHUAZABH
>> "%~1" echo AFYAdQBkAEQAMABuADYATAArAGUANQBvADYAbAA1AEwAaQB0ADUAcABhAHQASgB6
>> "%~1" echo AHQAegBaAFgAUQBvAEoAMwBOADAAWQBXAGQAbABWAEcAVgA0AGQAQwBjAHMASgAr
>> "%~1" echo AFMANABqAHUAYQBjAHIATwBXAGMAcwBPAGEAYwBqAGUAVwBLAG8AZQBlAGEAaABP
>> "%~1" echo AGkALwBuAHUAYQBPAHAAZQBTADQAcgBlAGEAVwByAFMAYwBwAE8AMgA1AHYAZABH
>> "%~1" echo AGwAbQBlAFMAZwBuADUAYQA2AEoANgBLAE8ARgA1AEwAaQB0ADUAcABhAHQASgB5
>> "%~1" echo AHcAbgBVADEATgBGAEkATwBpAC8AbgB1AGEATwBwAGUAbQBVAG0AZQBpAHYAcgB5
>> "%~1" echo AGMAcwBKADIAVgB5AGMAaQBjAHMATgBUAEEAdwBNAEMAawA3AGMAMgBWADAAVgBH
>> "%~1" echo AGwAdABaAFcAOQAxAGQAQwBnAG8ASwBUADAAKwBlADIASgAwAGIAaQA1AGoAYgBH
>> "%~1" echo AEYAegBjADAANQBoAGIAVwBVADkASgAyAGwAdQBjADMAUgBoAGIARwB4AEMAZABH
>> "%~1" echo ADQAbgBPADIAeABoAFkAbQBWAHMATABuAFIAbABlAEgAUgBEAGIAMgA1ADAAWgBX
>> "%~1" echo ADUAMABQAFMAZgBwAGgANAAzAG8AcgA1AFgAbAByAG8AbgBvAG8ANABVAG4ATwAy
>> "%~1" echo AFoAcABiAEcAdwB1AGMAMwBSADUAYgBHAFUAdQBkADIAbABrAGQARwBnADkASgB6
>> "%~1" echo AEEAbgBmAFMAdwB5AE4AagBBAHcASwBYADAANwBDAG4AMABLAFoAbgBWAHUAWQAz
>> "%~1" echo AFIAcABiADIANABnAGEAVwA1AHAAZABFAGwAdQBjADMAUgBoAGIARwB4AGwAYwBp
>> "%~1" echo AGcAcABlAHcAbwBnAEkARwBOAHYAYgBuAE4AMABJAEcAUgB5AGIAMwBBADkASgBD
>> "%~1" echo AGcAbgBZAFgAQgByAFIASABKAHYAYwBDAGMAcABMAEcAWgBwAGIARwBVADkASgBD
>> "%~1" echo AGcAbgBZAFgAQgByAFIAbQBsAHMAWgBTAGMAcABPAHcAbwBnAEkARwBSAHkAYgAz
>> "%~1" echo AEEAdQBiADIANQBqAGIARwBsAGoAYQB6ADAAbwBLAFQAMAArAFoAbQBsAHMAWgBT
>> "%~1" echo ADUAagBiAEcAbABqAGEAeQBnAHAATwB3AG8AZwBJAEcAWgBwAGIARwBVAHUAYgAy
>> "%~1" echo ADUAagBhAEcARgB1AFoAMgBVADkASwBDAGsAOQBQAG4AdABwAFoAaQBoAG0AYQBX
>> "%~1" echo AHgAbABMAG0AWgBwAGIARwBWAHoASgBpAFoAbQBhAFcAeABsAEwAbQBaAHAAYgBH
>> "%~1" echo AFYAegBXAHoAQgBkAEsAWABWAHcAYgBHADkAaABaAEUARgB3AGEAeQBoAG0AYQBX
>> "%~1" echo AHgAbABMAG0AWgBwAGIARwBWAHoAVwB6AEIAZABLAFQAdABtAGEAVwB4AGwATABu
>> "%~1" echo AFoAaABiAEgAVgBsAFAAUwBjAG4AZgBUAHMASwBJAEMAQgBiAEoAMgBSAHkAWQBX
>> "%~1" echo AGQAbABiAG4AUgBsAGMAaQBjAHMASgAyAFIAeQBZAFcAZAB2AGQAbQBWAHkASgAx
>> "%~1" echo ADAAdQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAbABkAGoAMAArAFoASABKAHYAYwBD
>> "%~1" echo ADUAaABaAEcAUgBGAGQAbQBWAHUAZABFAHgAcABjADMAUgBsAGIAbQBWAHkASwBH
>> "%~1" echo AFYAMgBMAEcAVQA5AFAAbgB0AGwATABuAEIAeQBaAFgAWgBsAGIAbgBSAEUAWgBX
>> "%~1" echo AFoAaABkAFcAeAAwAEsAQwBrADcAWgBIAEoAdgBjAEMANQBqAGIARwBGAHoAYwAw
>> "%~1" echo AHgAcABjADMAUQB1AFkAVwBSAGsASwBDAGQAdgBkAG0AVgB5AEoAeQBsADkASwBT
>> "%~1" echo AGsANwBDAGkAQQBnAFcAeQBkAGsAYwBtAEYAbgBiAEcAVgBoAGQAbQBVAG4ATABD
>> "%~1" echo AGQAawBjAG0AOQB3AEoAMQAwAHUAWgBtADkAeQBSAFcARgBqAGEAQwBoAGwAZABq
>> "%~1" echo ADAAKwBaAEgASgB2AGMAQwA1AGgAWgBHAFIARgBkAG0AVgB1AGQARQB4AHAAYwAz
>> "%~1" echo AFIAbABiAG0AVgB5AEsARwBWADIATABHAFUAOQBQAG4AdABsAEwAbgBCAHkAWgBY
>> "%~1" echo AFoAbABiAG4AUgBFAFoAVwBaAGgAZABXAHgAMABLAEMAawA3AGEAVwBZAG8AWgBY
>> "%~1" echo AFkAOQBQAFQAMABuAFoASABKAGgAWgAyAHgAbABZAFgAWgBsAEoAeQBZAG0AWgBI
>> "%~1" echo AEoAdgBjAEMANQBqAGIAMgA1ADAAWQBXAGwAdQBjAHkAaABsAEwAbgBKAGwAYgBH
>> "%~1" echo AEYAMABaAFcAUgBVAFkAWABKAG4AWgBYAFEAcABLAFgASgBsAGQASABWAHkAYgBq
>> "%~1" echo AHQAawBjAG0AOQB3AEwAbQBOAHMAWQBYAE4AegBUAEcAbAB6AGQAQwA1AHkAWgBX
>> "%~1" echo ADEAdgBkAG0AVQBvAEoAMgA5ADIAWgBYAEkAbgBLAFgAMABwAEsAVABzAEsASQBD
>> "%~1" echo AEIAawBjAG0AOQB3AEwAbQBGAGsAWgBFAFYAMgBaAFcANQAwAFQARwBsAHoAZABH
>> "%~1" echo AFYAdQBaAFgASQBvAEoAMgBSAHkAYgAzAEEAbgBMAEcAVQA5AFAAbgB0AGoAYgAy
>> "%~1" echo ADUAegBkAEMAQgBtAFAAVwBVAHUAWgBHAEYAMABZAFYAUgB5AFkAVwA1AHoAWgBt
>> "%~1" echo AFYAeQBKAGkAWgBsAEwAbQBSAGgAZABHAEYAVQBjAG0ARgB1AGMAMgBaAGwAYwBp
>> "%~1" echo ADUAbQBhAFcAeABsAGMAeQBZAG0AWgBTADUAawBZAFgAUgBoAFYASABKAGgAYgBu
>> "%~1" echo AE4AbQBaAFgASQB1AFoAbQBsAHMAWgBYAE4AYgBNAEYAMAA3AGEAVwBZAG8AWgBp
>> "%~1" echo AGwAMQBjAEcAeAB2AFkAVwBSAEIAYwBHAHMAbwBaAGkAbAA5AEsAVABzAEsASQBD
>> "%~1" echo AEIAagBiADIANQB6AGQAQwBCAHcAWQBXAGQAbABQAFMAUQBvAEoAMgBsAHUAYwAz
>> "%~1" echo AFIAaABiAEcAdwBuAEsAVAB0AHcAWQBXAGQAbABMAG0ARgBrAFoARQBWADIAWgBX
>> "%~1" echo ADUAMABUAEcAbAB6AGQARwBWAHUAWgBYAEkAbwBKADIAUgB5AFkAVwBkAHYAZABt
>> "%~1" echo AFYAeQBKAHkAeABsAFAAVAA1AGwATABuAEIAeQBaAFgAWgBsAGIAbgBSAEUAWgBX
>> "%~1" echo AFoAaABkAFcAeAAwAEsAQwBrAHAATwAzAEIAaABaADIAVQB1AFkAVwBSAGsAUgBY
>> "%~1" echo AFoAbABiAG4AUgBNAGEAWABOADAAWgBXADUAbABjAGkAZwBuAFoASABKAHYAYwBD
>> "%~1" echo AGMAcwBaAFQAMAArAGUAMgBVAHUAYwBIAEoAbABkAG0AVgB1AGQARQBSAGwAWgBt
>> "%~1" echo AEYAMQBiAEgAUQBvAEsAVAB0AGoAYgAyADUAegBkAEMAQgBtAFAAVwBVAHUAWgBH
>> "%~1" echo AEYAMABZAFYAUgB5AFkAVwA1AHoAWgBtAFYAeQBKAGkAWgBsAEwAbQBSAGgAZABH
>> "%~1" echo AEYAVQBjAG0ARgB1AGMAMgBaAGwAYwBpADUAbQBhAFcAeABsAGMAeQBZAG0AWgBT
>> "%~1" echo ADUAawBZAFgAUgBoAFYASABKAGgAYgBuAE4AbQBaAFgASQB1AFoAbQBsAHMAWgBY
>> "%~1" echo AE4AYgBNAEYAMAA3AGEAVwBZAG8AWgBpAFkAbQBMADEAdwB1AFkAWABCAHIASgBD
>> "%~1" echo ADkAcABMAG4AUgBsAGMAMwBRAG8AWgBpADUAdQBZAFcAMQBsAEsAUwBsADEAYwBH
>> "%~1" echo AHgAdgBZAFcAUgBCAGMARwBzAG8AWgBpAGwAOQBLAFQAcwBLAEkAQwBBAGsASwBD
>> "%~1" echo AGQAcABiAG4ATgAwAFkAVwB4AHMAUQBuAFIAdQBKAHkAawB1AGIAMgA1AGoAYgBH
>> "%~1" echo AGwAagBhAHoAMQBwAGIAbgBOADAAWQBXAHgAcwBRAFgAQgByAE8AdwBvAGcASQBD
>> "%~1" echo AFEAbwBKADIARgB3AGEAMQBCAGwAYwBtADEAegBRAG4AUgB1AEoAeQBrAHUAYgAy
>> "%~1" echo ADUAagBiAEcAbABqAGEAegAxAGwAUABUADUANwBaAFMANQB3AGMAbQBWADIAWgBX
>> "%~1" echo ADUAMABSAEcAVgBtAFkAWABWAHMAZABDAGcAcABPAHkAUQBvAEoAMgBGAHcAYQAx
>> "%~1" echo AEIAbABjAG0AMQB6AEoAeQBrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABu
>> "%~1" echo AFIAdgBaADIAZABzAFoAUwBnAG4AYwAyAGgAdgBkAHkAYwBwAGYAVABzAEsASQBD
>> "%~1" echo AEEAawBLAEMAZABoAGMARwB0AFMAWgBYAE4AbABkAEMAYwBwAEwAbQA5AHUAWQAy
>> "%~1" echo AHgAcABZADIAcwA5AFoAVAAwACsAZQAyAFUAdQBjAEgASgBsAGQAbQBWAHUAZABF
>> "%~1" echo AFIAbABaAG0ARgAxAGIASABRAG8ASwBUAHMAawBLAEMAZABoAGMARwB0AEUAYwBt
>> "%~1" echo ADkAdwBKAHkAawB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBp
>> "%~1" echo AGcAbgBZAGkAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABT
>> "%~1" echo AGYAbQBpADUAYgBtAGkANwAwAGcAUQBWAEIATABJAE8AVwBJAHMATwBpAC8AbQBl
>> "%~1" echo AG0ASABqAE8AKwA4AGoATwBhAEkAbAB1AGUAQwB1AGUAVwBIAHUAKwBtAEEAaQBl
>> "%~1" echo AGEATABxAFMAYwA3AEoAQwBnAG4AWQBYAEIAcgBSAEgASgB2AGMAQwBjAHAATABu
>> "%~1" echo AEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMASQBvAEoAeQBOAGsAYwBt
>> "%~1" echo ADkAdwBTAEcAbAB1AGQAQwBjAHAATABuAFIAbABlAEgAUgBEAGIAMgA1ADAAWgBX
>> "%~1" echo ADUAMABQAFMAZgBtAG4ASwB6AGwAbgBMAEQAawB1AEkAcgBrAHYASwBEAGwAawBJ
>> "%~1" echo ADcAbgBsAEwARQBnAFEAVQBSAEMASQBPAFcAdQBpAGUAaQBqAGgAZQBXAEkAcwBP
>> "%~1" echo AFcAMwBzAHUAaQAvAG4AdQBhAE8AcABlAGUAYQBoAEMAQgBSAGQAVwBWAHoAZABP
>> "%~1" echo AE8AQQBnAHUAVwB1AGkAZQBpAGoAaABlAFcASgBqAGUAUwA4AG0AdQBTADYAagBP
>> "%~1" echo AGEAcwBvAGUAZQBoAHIAdQBpAHUAcABPAE8AQQBnAGkAYwA3AGMAbQBWAHoAWgBY
>> "%~1" echo AFIAQgBjAEcAcwBvAEsAWAAwADcAQwBpAEEAZwBMAHkAOABnAFkAMgB4AHAAWQAy
>> "%~1" echo AHQAcABiAG0AYwBnAGQARwBoAGwASQBIAEIAbABjAG0AMABnAGMARwBsAHMAYgBD
>> "%~1" echo AEIAaABiAEgATgB2AEkARwA5AHcAWgBXADUAegBJAEgAQgBsAGMAbQAxAHoAQwBp
>> "%~1" echo AEEAZwBaAEcAOQBqAGQAVwAxAGwAYgBuAFEAdQBZAFcAUgBrAFIAWABaAGwAYgBu
>> "%~1" echo AFIATQBhAFgATgAwAFoAVwA1AGwAYwBpAGcAbgBZADIAeABwAFkAMgBzAG4ATABH
>> "%~1" echo AFUAOQBQAG4AdABwAFoAaQBoAGwATABuAFIAaABjAG0AZABsAGQAQwBZAG0AWgBT
>> "%~1" echo ADUAMABZAFgASgBuAFoAWABRAHUAYQBXAFEAOQBQAFQAMABuAGMARwBWAHkAYgBW
>> "%~1" echo AEIAcABiAEcAdwBuAEsAUwBRAG8ASgAyAEYAdwBhADEAQgBsAGMAbQAxAHoASgB5
>> "%~1" echo AGsAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4AMABMAG4AUgB2AFoAMgBkAHMAWgBT
>> "%~1" echo AGcAbgBjADIAaAB2AGQAeQBjAHAAZgBTAGsANwBDAG4AMABLAEMAaQA4AHEASQBD
>> "%~1" echo ADAAdABMAFMAMAB0AEwAUwAwAHQATABTADAAZwBkADIAbAB5AGEAVwA1AG4ASQBD
>> "%~1" echo ADAAdABMAFMAMAB0AEwAUwAwAHQATABTADAAZwBLAGkAOABLAFoARwA5AGoAZABX
>> "%~1" echo ADEAbABiAG4AUQB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBr
>> "%~1" echo AEYAcwBiAEMAZwBuAFcAMgBSAGgAZABHAEUAdABZAFcATgAwAGEAVwA5AHUAWABT
>> "%~1" echo AGMAcABMAG0AWgB2AGMAawBWAGgAWQAyAGcAbwBZAGoAMAArAFkAaQA1AHYAYgBt
>> "%~1" echo AE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUANwBZADIAOQB1AGMAMwBRAGcAYgBH
>> "%~1" echo AEYAaQBaAFcAdwA5AFkAaQA1AHgAZABXAFYAeQBlAFYATgBsAGIARwBWAGoAZABH
>> "%~1" echo ADkAeQBLAEMAZABpAEoAeQBrAC8ATABuAFIAbABlAEgAUgBEAGIAMgA1ADAAWgBX
>> "%~1" echo ADUAMABmAEgAeABpAEwAbQBSAGgAZABHAEYAegBaAFgAUQB1AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBPADIAbABtAEsARwBJAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABt
>> "%~1" echo AE4AdgBiAG4AUgBoAGEAVwA1AHoASwBDAGQAawBZAFcANQBuAFoAWABKAEIAWQAz
>> "%~1" echo AFIAcABiADIANABuAEsAUwBsAHoAYQBHADkAMwBRADIAOQB1AFoAbQBsAHkAYgBT
>> "%~1" echo AGgAaQBMAG0AUgBoAGQARwBGAHoAWgBYAFEAdQBZAFcATgAwAGEAVwA5AHUATABH
>> "%~1" echo AHgAaABZAG0AVgBzAEwAQwBjAG4ASwBUAHQAbABiAEgATgBsAEkARwBGAGoAZABH
>> "%~1" echo AGwAdgBiAGkAaABpAEwAbQBSAGgAZABHAEYAegBaAFgAUQB1AFkAVwBOADAAYQBX
>> "%~1" echo ADkAdQBMAEMAYwBuAEwARwB4AGgAWQBtAFYAcwBMAEcASQBzAFoAbQBGAHMAYwAy
>> "%~1" echo AFUAcABmAFMAawA3AEMAaQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMAbQAxAEQAWQBX
>> "%~1" echo ADUAagBaAFcAdwBuAEsAUwA1AHYAYgBtAE4AcwBhAFcATgByAFAAVwBOAHMAYgAz
>> "%~1" echo AE4AbABRADIAOQB1AFoAbQBsAHkAYgBUAHMASwBKAEMAZwBuAFkAMgA5AHUAWgBt
>> "%~1" echo AGwAeQBiAFUAOQByAEoAeQBrAHUAYgAyADUAagBiAEcAbABqAGEAegAwAG8ASwBU
>> "%~1" echo ADAAKwBlADIATgB2AGIAbgBOADAASQBIAEEAOQBjAEcAVgB1AFoARwBsAHUAWgAw
>> "%~1" echo AE4AdgBiAG0AWgBwAGMAbQAwADcAYwBHAFYAdQBaAEcAbAB1AFoAMABOAHYAYgBt
>> "%~1" echo AFoAcABjAG0AMAA5AGIAbgBWAHMAYgBEAHMAawBLAEMAZABqAGIAMgA1AG0AYQBY
>> "%~1" echo AEoAdABUAFcARgB6AGEAeQBjAHAATABtAE4AcwBZAFgATgB6AFQARwBsAHoAZABD
>> "%~1" echo ADUAeQBaAFcAMQB2AGQAbQBVAG8ASgAzAE4AbwBiADMAYwBuAEsAVAB0AHAAWgBp
>> "%~1" echo AGcAaABjAEMAbAB5AFoAWABSADEAYwBtADQANwBhAFcAWQBvAGMAQwA1AGoAZABY
>> "%~1" echo AE4AMABiADIAMABtAEoAbgBBAHUAYwBtAFYAegBiADIAeAAyAFoAUwBsADcAYwBD
>> "%~1" echo ADUAeQBaAFgATgB2AGIASABaAGwASwBIAFIAeQBkAFcAVQBwAE8AMwBKAGwAZABI
>> "%~1" echo AFYAeQBiAG4AMQBwAFoAaQBoAHcASwBXAEYAagBkAEcAbAB2AGIAaQBoAHcATABt
>> "%~1" echo AEYAagBkAEcAbAB2AGIAaQB4AHcATABtAFYANABkAEgASgBoAEwASABBAHUAYgBH
>> "%~1" echo AEYAaQBaAFcAdwBzAGIAbgBWAHMAYgBDAHgAMABjAG4AVgBsAEsAWAAwADcAQwBp
>> "%~1" echo AFEAbwBKADMASgBsAFoAbgBKAGwAYwAyAGgAQwBkAEcANABuAEsAUwA1AHYAYgBt
>> "%~1" echo AE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUANwBiAG0AOQAwAGEAVwBaADUASwBD
>> "%~1" echo AGYAbABpAEwAZgBtAGwAcgBEAG4AaQByAGIAbQBnAEkARQBuAEwAQwBmAG0AcgBh
>> "%~1" echo AFAAbABuAEsAagBvAHIANwB2AGwAagA1AFkAZwBVAFgAVgBsAGMAMwBRAGcANQA0
>> "%~1" echo AHEAMgA1AG8AQwBCAEwAaQA0AHUASgB5AHcAbgBkADIARgB5AGIAaQBjAHMATQBU
>> "%~1" echo AFkAdwBNAEMAawA3AGMAbQBWAG0AYwBtAFYAegBhAEMAaAAwAGMAbgBWAGwASwBU
>> "%~1" echo AHQAcwBiADIARgBrAFQARwA5AG4AYwB5AGgAbQBZAFcAeAB6AFoAUwBsADkATwB3
>> "%~1" echo AG8AawBLAEMAZAB5AFoAVwBaAHkAWgBYAE4AbwBUAEcAOQBuAGMAeQBjAHAATABt
>> "%~1" echo ADkAdQBZADIAeABwAFkAMgBzADkASwBDAGsAOQBQAG0AeAB2AFkAVwBSAE0AYgAy
>> "%~1" echo AGQAegBLAEgAUgB5AGQAVwBVAHAATwB3AG8AawBLAEMAZABsAGUASABCAHYAYwBu
>> "%~1" echo AFIAQwBkAEcANABuAEsAUwA1AHYAYgBtAE4AcwBhAFcATgByAFAAVwBWADQAYwBH
>> "%~1" echo ADkAeQBkAEUAaAAwAGIAVwB3ADcAQwBpAFEAbwBKADMAUgBvAFoAVwAxAGwAUQBu
>> "%~1" echo AFIAdQBKAHkAawB1AGIAMgA1AGoAYgBHAGwAagBhAHoAMABvAEsAVAAwACsAZQAy
>> "%~1" echo AHgAdgBZADIARgBzAFUAMwBSAHYAYwBtAEYAbgBaAFMANQB6AFoAWABSAEoAZABH
>> "%~1" echo AFYAdABLAEgAUgBvAFoAVwAxAGwAUwAyAFYANQBMAEcAUgB2AFkAMwBWAHQAWgBX
>> "%~1" echo ADUAMABMAG0ASgB2AFoASABrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABt
>> "%~1" echo AE4AdgBiAG4AUgBoAGEAVwA1AHoASwBDAGQAawBZAFgASgByAEoAeQBrAC8ASgAy
>> "%~1" echo AHgAcABaADIAaAAwAEoAegBvAG4AWgBHAEYAeQBhAHkAYwBwAE8AMwBSAG8AWgBX
>> "%~1" echo ADEAbABLAEMAawA3AGIAbQA5ADAAYQBXAFoANQBLAEMAZgBrAHUATAB2AHAAbwBw
>> "%~1" echo AGoAbAB0ADcATABsAGkASQBmAG0AagBhAEkAbgBMAEcAUgB2AFkAMwBWAHQAWgBX
>> "%~1" echo ADUAMABMAG0ASgB2AFoASABrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABt
>> "%~1" echo AE4AdgBiAG4AUgBoAGEAVwA1AHoASwBDAGQAawBZAFgASgByAEoAeQBrAC8ASgAr
>> "%~1" echo AFcAOQBrACsAVwBKAGoAZQBTADQAdQB1AGEAMwBzAGUAaQBKAHMAdQBhAG8AbwBl
>> "%~1" echo AFcAOABqAHkAYwA2AEoAKwBXADkAawArAFcASgBqAGUAUwA0AHUAdQBhADEAaABl
>> "%~1" echo AGkASgBzAHUAYQBvAG8AZQBXADgAagB5AGMAcwBKADIAOQByAEoAeQBsADkATwB3
>> "%~1" echo AG8AawBLAEMAZABqAGQAWABOADAAYgAyADEAVABaAFgAUQBuAEsAUwA1AHYAYgBt
>> "%~1" echo AE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUAegBhAEcAOQAzAFEAMgA5AHUAWgBt
>> "%~1" echo AGwAeQBiAFMAZwBuAFkAMwBWAHoAZABHADkAdABYADMATgBsAGQASABSAHAAYgBt
>> "%~1" echo AGMAbgBMAEMAZgBsAGgAcABuAGwAaABhAFUAZwBjADIAVgAwAGQARwBsAHUAWgAz
>> "%~1" echo AE0AbgBMAEMAYwBtAGIAbgBNADkASgB5AHQAbABiAG0ATgB2AFoARwBWAFYAVQBr
>> "%~1" echo AGwARABiADIAMQB3AGIAMgA1AGwAYgBuAFEAbwBKAEMAZwBuAFkAMwBWAHoAZABH
>> "%~1" echo ADkAdABUAG4ATQBuAEsAUwA1ADIAWQBXAHgAMQBaAFMAawByAEoAeQBaAHIAWgBY
>> "%~1" echo AGsAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIAMgAxAHcAYgAy
>> "%~1" echo ADUAbABiAG4AUQBvAEoAQwBnAG4AWQAzAFYAegBkAEcAOQB0AFMAMgBWADUASgB5
>> "%~1" echo AGsAdQBkAG0ARgBzAGQAVwBVAHAASwB5AGMAbQBkAG0ARgBzAGQAVwBVADkASgB5
>> "%~1" echo AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwARABiADIAMQB3AGIAMgA1AGwAYgBu
>> "%~1" echo AFEAbwBKAEMAZwBuAFkAMwBWAHoAZABHADkAdABWAG0ARgBzAGQAVwBVAG4ASwBT
>> "%~1" echo ADUAMgBZAFcAeAAxAFoAUwBrAHAATwB3AG8AawBLAEMAZABqAGQAWABOADAAYgAy
>> "%~1" echo ADEAQwBjAG0AOQBoAFoARwBOAGgAYwAzAFEAbgBLAFMANQB2AGIAbQBOAHMAYQBX
>> "%~1" echo AE4AcgBQAFMAZwBwAFAAVAA1AHoAYQBHADkAMwBRADIAOQB1AFoAbQBsAHkAYgBT
>> "%~1" echo AGcAbgBZADMAVgB6AGQARwA5AHQAWAAyAEoAeQBiADIARgBrAFkAMgBGAHoAZABD
>> "%~1" echo AGMAcwBKACsAVwBQAGsAZQBtAEEAZwBlAFcANQB2ACsAYQBTAHIAUwBjAHMASgB5
>> "%~1" echo AFoAdQBZAFcAMQBsAFAAUwBjAHIAWgBXADUAagBiADIAUgBsAFYAVgBKAEoAUQAy
>> "%~1" echo ADkAdABjAEcAOQB1AFoAVwA1ADAASwBDAFEAbwBKADIASgB5AGIAMgBGAGsAWQAy
>> "%~1" echo AEYAegBkAEUANQBoAGIAVwBVAG4ASwBTADUAMgBZAFcAeAAxAFoAUwBrAHAATwB3
>> "%~1" echo AHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAeQBiADMAVgAwAFoAUwBnAHAAZQAy
>> "%~1" echo AE4AdgBiAG4ATgAwAEkARwBsAGsAUABTAGgAcwBiADIATgBoAGQARwBsAHYAYgBp
>> "%~1" echo ADUAbwBZAFgATgBvAGYASAB3AG4ASQAyADkAMgBaAFgASgAyAGEAVwBWADMASgB5
>> "%~1" echo AGsAdQBjADIAeABwAFkAMgBVAG8ATQBTAGsANwBaAEcAOQBqAGQAVwAxAGwAYgBu
>> "%~1" echo AFEAdQBjAFgAVgBsAGMAbgBsAFQAWgBXAHgAbABZADMAUgB2AGMAawBGAHMAYgBD
>> "%~1" echo AGcAbgBMAG4AQgBoAFoAMgBVAG4ASwBTADUAbQBiADMASgBGAFkAVwBOAG8ASwBI
>> "%~1" echo AEEAOQBQAG4AQQB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwAbgBSAHYAWgAy
>> "%~1" echo AGQAcwBaAFMAZwBuAFkAVwBOADAAYQBYAFoAbABKAHkAeAB3AEwAbQBsAGsAUABU
>> "%~1" echo ADAAOQBhAFcAUQBwAEsAVAB0AGsAYgAyAE4AMQBiAFcAVgB1AGQAQwA1AHgAZABX
>> "%~1" echo AFYAeQBlAFYATgBsAGIARwBWAGoAZABHADkAeQBRAFcAeABzAEsAQwBjAHUAYgBt
>> "%~1" echo AEYAMgBJAEcARQBuAEsAUwA1AG0AYgAzAEoARgBZAFcATgBvAEsARwBFADkAUABt
>> "%~1" echo AEUAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4AMABMAG4AUgB2AFoAMgBkAHMAWgBT
>> "%~1" echo AGcAbgBZAFcATgAwAGEAWABaAGwASgB5AHgAaABMAG0AZABsAGQARQBGADAAZABI
>> "%~1" echo AEoAcABZAG4AVgAwAFoAUwBnAG4AYQBIAEoAbABaAGkAYwBwAFAAVAAwADkASgB5
>> "%~1" echo AE0AbgBLADIAbABrAEsAUwBrADcAWQAyADkAdQBjADMAUQBnAGIAVAAxAHcAWQBX
>> "%~1" echo AGQAbABjADEAdABwAFoARgAxADgAZgBIAEIAaABaADIAVgB6AEwAbQA5ADIAWgBY
>> "%~1" echo AEoAMgBhAFcAVgAzAE8AMwBOAGwAZABDAGcAbgBjAEcARgBuAFoAVgBSAHAAZABH
>> "%~1" echo AHgAbABKAHkAeAB0AFcAegBCAGQASwBUAHQAegBaAFgAUQBvAEoAMwBCAGgAWgAy
>> "%~1" echo AFYAVABkAFcASQBuAEwARwAxAGIATQBWADAAcABPADIAbABtAEsARwBsAGsAUABU
>> "%~1" echo ADAAOQBKADIAeAB2AFoAMwBNAG4ASwBXAHgAdgBZAFcAUgBNAGIAMgBkAHoASwBH
>> "%~1" echo AFoAaABiAEgATgBsAEsAWAAwAEsAZABHAGgAbABiAFcAVQBvAEsAVAB0AHAAYgBt
>> "%~1" echo AGwAMABTAFcANQB6AGQARwBGAHMAYgBHAFYAeQBLAEMAawA3AFkAVwBSAGsAUgBY
>> "%~1" echo AFoAbABiAG4AUgBNAGEAWABOADAAWgBXADUAbABjAGkAZwBuAGEARwBGAHoAYQBH
>> "%~1" echo AE4AbwBZAFcANQBuAFoAUwBjAHMAYwBtADkAMQBkAEcAVQBwAE8AMwBKAHYAZABY
>> "%~1" echo AFIAbABLAEMAawA3AGMAbQBWAG0AYwBtAFYAegBhAEMAZwBwAE8AMgB4AHYAWQBX
>> "%~1" echo AFIATQBiADIAZAB6AEsARwBaAGgAYgBIAE4AbABLAFQAdAB6AFoAWABSAEoAYgBu
>> "%~1" echo AFIAbABjAG4AWgBoAGIAQwBnAG8ASwBUADAAKwBjADIAVgAwAEsAQwBkAGoAYgBH
>> "%~1" echo ADkAagBhADEAUgBsAGUASABRAG4ATABHADUAbABkAHkAQgBFAFkAWABSAGwASwBD
>> "%~1" echo AGsAdQBkAEcAOQBNAGIAMgBOAGgAYgBHAFYAVQBhAFcAMQBsAFUAMwBSAHkAYQBX
>> "%~1" echo ADUAbgBLAEMAawBwAEwARABFAHcATQBEAEEAcABPADMATgBsAGQARQBsAHUAZABH
>> "%~1" echo AFYAeQBkAG0ARgBzAEsAQwBnAHAAUABUADUAeQBaAFcAWgB5AFoAWABOAG8ASwBH
>> "%~1" echo AFoAaABiAEgATgBsAEsAUwB3AHgATgBUAEEAdwBNAEMAawA3AEMAagB3AHYAYwAy
>> "%~1" echo AE4AeQBhAFgAQgAwAFAAagB3AHYAWQBtADkAawBlAFQANAA4AEwAMgBoADAAYgBX
>> "%~1" echo AHcAKwBDAGcAPQA9AAATWwBbAFQATwBLAEUATgBdAF0AAANOAAAAAKmt1b3PnAtF
>> "%~1" echo gFlZ1harQG4ACLd6XFYZNOCJAgYKCAAAAAABAAAAAgYOAgYIAgYcAwYSCQUAAQEd
>> "%~1" echo DgMAAAgLAAQBFRINAQ4ODg4MAAQBFRINAQ4ODh0OBQABARIRCAACAhIVEB0FCAAE
>> "%~1" echo ChIVCg4KBgACARIVCggAABUSGQIODgoAAhUSGQIODg4OBQACDg4OBgACARIVDgYA
>> "%~1" echo AggdBQgGAAIKHQUIBQABEhgOCQAEARIdCh0FCAcAAh0FEh0OBwACAR0FEhgLAAUB
>> "%~1" echo HQUICB0OEhgKAAUOHQUICB0ODgYAAg4dDggHAAIdDh0FCAYAAg4dBQgHBhUSGQIO
>> "%~1" echo DgQAAQEIDAADFRIZAg4OEhUOCgkAARUSGQIODg4FAAEBEhUMAAMBEhUOFRIZAg4O
>> "%~1" echo CAAEARIVDg4ICAAEARIVAg4OBQACDg4CBAABAg4EAAEODgQAAQ4KBAABAQ4DAAAO
>> "%~1" echo BwACDhAOEA4GAAMODg4OBgADDg4IDgYAAg4IHQ4IAAQBEiEODg4KAAIBFRIZAg4O
>> "%~1" echo DgYAAhIUDg4JAAUBEhQODggOCgAFARIUDggCHQ4HAAISEBIUDgUAAQESFAYAAg4S
>> "%~1" echo FAIPAAUBEiEOFRIZAg4OAh0OCAADARIhEhQCBwADDg4dDggIAAMSDA4dDggNAAQS
>> "%~1" echo DA4dDggVEiUBDgUAAQ4dDgQAAQgOBQACCA4OCgACDhUSGQIODg4GAAIODhIUBQAB
>> "%~1" echo HQ4OCwACARIVFRIZAg4OCAADARIVDh0FCQABDhUSGQIODgMgAAECBgIDIAAOAygA
>> "%~1" echo DgcGFRINARIQBgYVEg0BDgQBAAAABCABAQgEAAEBHAMGEjkEBwESQQQAABIJBQAB
>> "%~1" echo ARIJBQACAg4OBAAAElEFAAESVQ4GIAIBElUIBAAAEV0FAAEOHRwGAAMOHBwcBiAC
>> "%~1" echo Ag4RZQUAARJpDgQgABIRBSACARwYBgACAhI5HBEHChJZCA4ODhIREkECHRwdDgUV
>> "%~1" echo Eg0BDgMgAAgIIAAVEXEBEwAFFRFxAQ4EIAATAAQAABJ1BCABAQ4DIAACEwcIFRIN
>> "%~1" echo AQ4ODg4IHQ4CFRFxAQ4FIAEBEwAFBwICHQ4GIAIIDhFlCQcFDh0OCAIdDgQgABJ9
>> "%~1" echo BSABDh0FCSACHQ4dDhGAgQYgAR0OHQMEIAEIAwUgAg4ICAQgAQ4IBgACAg4QCgUg
>> "%~1" echo AR0FDiAHFRIVHQUOHQ4dDg4OCg4IDggODhKAjQIOEhECHQ4dAwUVEg0BBQcgAwgd
>> "%~1" echo BQgIBSAAHRMADwcIFRINAQUdBQgICAUCAgogAwEOEYCVEYCZBQACCgoKByADAR0F
>> "%~1" echo CAgMBwgKCh0FEh0ICAoCCAcFCh0FCAgCBQACDhwcBhUSGQIODgcgAgETABMBBiAB
>> "%~1" echo EwETABcHCRUSGQIODg4ODg4VEhkCDg4CHQ4dAwcABA4ODg4OBSABAhMAGAcKFRIZ
>> "%~1" echo Ag4ODg4ODg4SQRUSGQIODgIdDg4HAhUSGQIODhUSGQIODgUAABGApQQgAQ4OBgAB
>> "%~1" echo EoCxDgcAAwEODhIJCwACEYC5EYClEYClAyAADQUAABKAvQYgAQ4SgMEGFRINARIQ
>> "%~1" echo BgACDg4dDioHFRUSGQIODhGApQ4ODg4SFA4ODg4ODhGAuRJBFRIZAg4OAh0DEYCl
>> "%~1" echo CggFBwIOHQ4CBgMFIAIOAwMFAAEdBQ4IBwUODg4SQQIDBwEIAwcBCg0HBhIYEh0d
>> "%~1" echo BRJBEhgCByACCgoRgMUFBwMICAIDIAAKByADDh0FCAgFIAEBHQUIIAIBEhURgNUE
>> "%~1" echo IAAdBSwHHgoIHQUICAgKCh0FCAgICggICAoOHQUICAodBRKAzRKA0RKAzR0FCB0F
>> "%~1" echo AhIHCx0OCBUSDQEOCAoIDggIDgIKBwgICAgOCAoIAgoHCAgICAgICg4CBAcCDgIQ
>> "%~1" echo BwwICgoCHQ4ICAgKCB0OAgYHBAgIDgIKIAEBFRKA2QETAAUAABKA3QogAQEVEoDh
>> "%~1" echo ARMABSABEwAIBQACAQ4CCgcEDhUSDQEOCAIGAAIBHBACKAcVFRIZAg4ODg4ODg4K
>> "%~1" echo HQUSHQgSGA4OAhJBFRIZAg4OAhGApRwIHQ4IIAICEwAQEwEFIAESIQ4vBxgVEhkC
>> "%~1" echo Dg4ODg4CAgICDhIhEgwVEg0BDhIMDgISDA4CEkEVEhkCDg4cAh0cHQ4FBwIOHQUG
>> "%~1" echo BwISIR0FCAcBFRIZAg4OAwYSFQMGEhwDBhIgAwcBAgUVEiUBDi8HGA4ODgICAgIO
>> "%~1" echo EgwVEg0BDhIMAhIMEiQCEiASQRUSJQEOFRIlAQ4SHBwCHRwdDg4HCw4ODggOCA4O
>> "%~1" echo Ah0OCAYHBA4ODgIEIAEDCAQAAQIDBwcFAwICDggFIAESIQMKBwcSIQMODgIOCAcg
>> "%~1" echo Ag4OEoDBBwcFDQ0NDgIKBwcODg4OHQ4IAgcHBA4ODh0DBSABDh0DCQcEDh0DAhGA
>> "%~1" echo pQgHBAIcEYClAgwHCB0FCAgOCBJBDgIJIAIdDh0DEYCBFgcQDg4ODg4ODg4dDgIO
>> "%~1" echo HQ4dDggCHQMDBwEOBAcCDg4JBwUSDA4OAh0cCQcEDhIhAhGApQcAAh0ODhIJByAC
>> "%~1" echo HQ4dAwgPBwkODg4dDgIdDggdAx0OBSACDg4OBQcDDg4ODAAEAg4RgPESgMEQDQcH
>> "%~1" echo BQ4ODQINEQcKDhUSDQEODg4ODg4dDggCEgcMDg4OHQ4ODg4dDggCHQMdDg4HCA4O
>> "%~1" echo Dg4ODhUSDQEOAgsHBBIUEhQRgKUdDgQHAR0OBQAAEoD1CgcEEoD1EgwSEAIGFRFx
>> "%~1" echo ARIQDQcEEhASEBURcQESEAIZBxIVEhkCDg4ODg4ODg4ODg4ODg4ODQINCBQHCRUS
>> "%~1" echo GQIODg4ODg4SIQ4RgKUdDhEHCw4dDg4ODg4dDggdAwIdDg4HBRIQDhURcQESEAId
>> "%~1" echo DgQgAQgODQcKDg4OCA4IDgIdDggDBhIMAwYSKAMGEmkFIAASgPkEIAEBAgcAARJp
>> "%~1" echo EoEBBiABARKBBQQgAQIIFAcIEoEBEoChEoChEiwSQRIoEgwCBgYVEiUBDgMGEjAG
>> "%~1" echo BwQOAgIcGAcLEgwSgQESgKESgKESNBJBAhIwEgwCHAcHBBIhCA4CAwYRPAkAAgES
>> "%~1" echo gRERgRUFIAEIHQMEIAECDgkHBg4ODh0OCAIMBwkODggOCA4dDggCCAcGDggOCA4C
>> "%~1" echo CgcHDg4IDh0OCAIPBwoODh0ODQ4dDggCHQMNDAcIDg4ODh0OCAIdAwcgAwgOCBFl
>> "%~1" echo CgADEoEdDg4RgSEFIAASgSkGIAESgSUIBgcCEoEdDgUAAgIcHAkHBBKBHQ4CHQMG
>> "%~1" echo BwQOCA4CDwcJDg4dDg4dDggCHQMdDgYHBAgODgIPBwkODg4ODhUSDQEODggCDAcG
>> "%~1" echo Dg4OFRINAQ4OAg4HCA4ODg4OFRINAQ4OAhAHCQgOCAgIFRINAQ4OAh0cBQcDDg4C
>> "%~1" echo CQcGCA4IHQ4IAgoAAxKBMQ4OEYEhBgABDhKBHQQGEoE5CAADDg4OEoE5CQAEDg4O
>> "%~1" echo DhGBIQYHAh0OHQMNBwkOCA4ODgIdAx0OCAcHAw4dBR0cCyAAFRGBPQITABMBBxUR
>> "%~1" echo gT0CDg4LIAAVEYFBAhMAEwEHFRGBQQIODgQgABMBFQcGEiECFRGBQQIODg4VEYE9
>> "%~1" echo Ag4OAgoHBxIhAw4OCAIIAwAAAQUAABGBSQUHARGBSQgBAAgAAAAAAB4BAAEAVAIW
>> "%~1" echo V3JhcE5vbkV4Y2VwdGlvblRocm93cwEAULkDAAAAAAAAAAAAbrkDAAAgAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAGC5AwAAAAAAAAAAAAAAAAAAAF9Db3JFeGVNYWluAG1z
>> "%~1" echo Y29yZWUuZGxsAAAAAAD/JQAgQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAACABAAAAAgAACAGAAAADgAAIAAAAAAAAAAAAAAAAAAAAEA
>> "%~1" echo AQAAAFAAAIAAAAAAAAAAAAAAAAAAAAEAAQAAAGgAAIAAAAAAAAAAAAAAAAAAAAEA
>> "%~1" echo AAAAAIAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAJAAAACgwAMAXAIAAAAAAAAAAAAA
>> "%~1" echo AMMDAOoBAAAAAAAAAAAAAFwCNAAAAFYAUwBfAFYARQBSAFMASQBPAE4AXwBJAE4A
>> "%~1" echo RgBPAAAAAAC9BO/+AAABAAAAAAAAAAAAAAAAAAAAAAA/AAAAAAAAAAQAAAABAAAA
>> "%~1" echo AAAAAAAAAAAAAAAARAAAAAEAVgBhAHIARgBpAGwAZQBJAG4AZgBvAAAAAAAkAAQA
>> "%~1" echo AABUAHIAYQBuAHMAbABhAHQAaQBvAG4AAAAAAAAAsAS8AQAAAQBTAHQAcgBpAG4A
>> "%~1" echo ZwBGAGkAbABlAEkAbgBmAG8AAACYAQAAAQAwADAAMAAwADAANABiADAAAAAsAAIA
>> "%~1" echo AQBGAGkAbABlAEQAZQBzAGMAcgBpAHAAdABpAG8AbgAAAAAAIAAAADAACAABAEYA
>> "%~1" echo aQBsAGUAVgBlAHIAcwBpAG8AbgAAAAAAMAAuADAALgAwAC4AMAAAAEQAEgABAEkA
>> "%~1" echo bgB0AGUAcgBuAGEAbABOAGEAbQBlAAAAUQB1AGUAcwB0AEEAZABiAFcAZQBiAFUA
>> "%~1" echo aQAuAGUAeABlAAAAKAACAAEATABlAGcAYQBsAEMAbwBwAHkAcgBpAGcAaAB0AAAA
>> "%~1" echo IAAAAEwAEgABAE8AcgBpAGcAaQBuAGEAbABGAGkAbABlAG4AYQBtAGUAAABRAHUA
>> "%~1" echo ZQBzAHQAQQBkAGIAVwBlAGIAVQBpAC4AZQB4AGUAAAA0AAgAAQBQAHIAbwBkAHUA
>> "%~1" echo YwB0AFYAZQByAHMAaQBvAG4AAAAwAC4AMAAuADAALgAwAAAAOAAIAAEAQQBzAHMA
>> "%~1" echo ZQBtAGIAbAB5ACAAVgBlAHIAcwBpAG8AbgAAADAALgAwAC4AMAAuADAAAAAAAAAA
>> "%~1" echo 77u/PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxv
>> "%~1" echo bmU9InllcyI/Pg0KPGFzc2VtYmx5IHhtbG5zPSJ1cm46c2NoZW1hcy1taWNyb3Nv
>> "%~1" echo ZnQtY29tOmFzbS52MSIgbWFuaWZlc3RWZXJzaW9uPSIxLjAiPg0KICA8YXNzZW1i
>> "%~1" echo bHlJZGVudGl0eSB2ZXJzaW9uPSIxLjAuMC4wIiBuYW1lPSJNeUFwcGxpY2F0aW9u
>> "%~1" echo LmFwcCIvPg0KICA8dHJ1c3RJbmZvIHhtbG5zPSJ1cm46c2NoZW1hcy1taWNyb3Nv
>> "%~1" echo ZnQtY29tOmFzbS52MiI+DQogICAgPHNlY3VyaXR5Pg0KICAgICAgPHJlcXVlc3Rl
>> "%~1" echo ZFByaXZpbGVnZXMgeG1sbnM9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206YXNt
>> "%~1" echo LnYzIj4NCiAgICAgICAgPHJlcXVlc3RlZEV4ZWN1dGlvbkxldmVsIGxldmVsPSJh
>> "%~1" echo c0ludm9rZXIiIHVpQWNjZXNzPSJmYWxzZSIvPg0KICAgICAgPC9yZXF1ZXN0ZWRQ
>> "%~1" echo cml2aWxlZ2VzPg0KICAgIDwvc2VjdXJpdHk+DQogIDwvdHJ1c3RJbmZvPg0KPC9h
>> "%~1" echo c3NlbWJseT4NCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo ALADAAwAAACAOQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
>> "%~1" echo -----END CERTIFICATE-----
exit /b 0
