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

for %%A in (
  "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  "D:\Software\Android\Sdk\platform-tools\adb.exe"
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
if exist "!WEBUI_EXE!" goto :start_webui_launch
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
:start_webui_launch
call :say_b64 "5q2j5Zyo5ZCv5YqoIFdlYlVJ77yM5Y+q55uR5ZCsIDEyNy4wLjAuMS4uLg=="
call :write_b64 "5pel5b+X55uu5b2V77ya"
echo %SCRIPT_DIR%Quest_ADB_Logs
start "Quest ADB WebUI" "!WEBUI_EXE!" "!WEBUI_ADB!" "!WEBUI_LOG_ROOT!"
exit /b 0

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
>> "%~1" echo dCBiZSBydW4gaW4gRE9TIG1vZGUuDQ0KJAAAAAAAAABQRQAATAEDAIMiOmoAAAAA
>> "%~1" echo AAAAAOAAAgELAQsAALQCAAAIAAAAAAAArtICAAAgAAAA4AIAAABAAAAgAAAAAgAA
>> "%~1" echo BAAAAAAAAAAEAAAAAAAAAAAgAwAAAgAAAAAAAAMAQIUAABAAABAAAAAAEAAAEAAA
>> "%~1" echo AAAAABAAAAAAAAAAAAAAAFjSAgBTAAAAAOACAPAEAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAADAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAIAAACAAAAAAAAAAAAAAACCAAAEgAAAAAAAAAAAAAAC50ZXh0AAAA
>> "%~1" echo tLICAAAgAAAAtAIAAAIAAAAAAAAAAAAAAAAAACAAAGAucnNyYwAAAPAEAAAA4AIA
>> "%~1" echo AAYAAAC2AgAAAAAAAAAAAAAAAABAAABALnJlbG9jAAAMAAAAAAADAAACAAAAvAIA
>> "%~1" echo AAAAAAAAAAAAAAAAQAAAQgAAAAAAAAAAAAAAAAAAAACQ0gIAAAAAAEgAAAACAAUA
>> "%~1" echo UIYAAAhMAgABAAAAAQAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAABswAgBEAAAAAQAAEQAAAnQEAAABKAUAAAYAAN4xCgAA
>> "%~1" echo AnQEAAABbwYAAAoAAN4FJgAA3gAAcgEAAHAGbwcAAAooCAAACigQAAAGAADeAAAq
>> "%~1" echo ARwAAAAAEwAQIwAFAQAAAQAAAQAQEQAxDgAAARswBACeAgAAAgAAEQAAKAkAAAoo
>> "%~1" echo CgAACgAA3gUmAADeAAACjmkWMRICFppyEQAAcCgLAAAKFv4BKwEXABMHEQctEQAo
>> "%~1" echo AgAABigMAAAKADhWAgAAAo5pFv4CFv4BEwcRBy0IAhaagAEAAAQCjmkXMAwoDQAA
>> "%~1" echo Cm8OAAAKKwMCF5oAKA8AAAYAFAogPSIAAAsrLwAAcikAAHAoDwAACgdzEAAACgoG
>> "%~1" echo bxEAAAoAB4ADAAAE3h4mABQKAN4AAAAHF1gLByBRIgAA/gIW/gETBxEHLcAABhT+
>> "%~1" echo ARb+ARMHEQctIgByPQAAcCgSAAAKAHKLAABwKBAAAAYAKBMAAAomOKkBAAAajQEA
>> "%~1" echo AAETCBEIFnK5AABwohEIF34DAAAEjBYAAAGiEQgYct0AAHCiEQgZfgIAAASiEQgo
>> "%~1" echo FAAACgxy7wAAcAgoCAAACigSAAAKAHIdAQBwKBIAAAoAclsBAHB+AQAABCgIAAAK
>> "%~1" echo KBIAAAoAcmcBAHB+BgAABCgIAAAKKBIAAAoAcnEBAHB+AwAABIwWAAABcp8BAHAo
>> "%~1" echo FQAACigQAAAGAHJbAQBwfgEAAAQoCAAACigQAAAGAAAcjQ8AAAETCREJFnKjAQBw
>> "%~1" echo ohEJFxIDEgQoEgAABqIRCRhyswEAcKIRCRkJKFkAAAaiEQkacrMBAHCiEQkbEQSi
>> "%~1" echo EQkoFgAACigQAAAGAADeBSYAAN4AAHK3AQBwcrsBAHAoFwAAChtvGAAAChMHEQct
>> "%~1" echo EwAACCgZAAAKJgDeBSYAAN4AAAAragAABm8aAAAKEwV+CQAABC0TFP4GawAABnMb
>> "%~1" echo AAAKgAkAAAQrAH4JAAAEEQUoHAAACiYA3jQTBgBy8QEAcBEGbwcAAAooCAAACigS
>> "%~1" echo AAAKAHLxAQBwEQZvBwAACigIAAAKKBAAAAYAAN4AAAAXEwcrkSoAAAFAAAAAAAEA
>> "%~1" echo DxAABQEAAAEAAIUAIaYABwEAAAEAAKcBUfgBBQEAAAEAABoCCyUCBQEAAAEAAC8C
>> "%~1" echo M2ICNA4AAAEbMAYAhAEAAAMAABEAcx0AAAoKcgECAHALBnLsAwBwcgIEAHAHcuwD
>> "%~1" echo AHAoQQAABigDAAAGAAZyEAQAcHIkBABwB3IQBABwKEEAAAYoAwAABgAGcjIEAHBy
>> "%~1" echo RgQAcAdyMgQAcChBAAAGKAMAAAYABnJuBABwcoYEAHAHcm4EAHAoQQAABigDAAAG
>> "%~1" echo AAZyjgQAcHKkBABwB3KOBABwKEEAAAYoAwAABgAGcs4EAHAHKE0AAAYajQ8AAAET
>> "%~1" echo BREFFnICBABwohEFF3IkBABwohEFGHLsBABwohEFGXL8BABwohEFKAQAAAYAcjYF
>> "%~1" echo AHAMBnLZBQBwcvUFAHAIKEwAAAYZjQ8AAAETBREFFnL3BQBwohEFF3IHBgBwohEF
>> "%~1" echo GHIZBgBwohEFKAQAAAYABm8eAAAKFv4BFv4BEwYRBi0RAHIrBgBwKBIAAAoAFhME
>> "%~1" echo K0MABm8fAAAKEwcrFBIHKCAAAAoNKCEAAAoJbyIAAAoAEgcoIwAAChMGEQYt394P
>> "%~1" echo Egf+FgIAABtvJAAACgDcABcTBCsAEQQqARAAAAIARwElbAEPAAAAABMwBABIAAAA
>> "%~1" echo BAAAEQAFBCglAAAKFv4BCgYtOAIcjQ8AAAELBxYDogcXcmUGAHCiBxgEogcZcn8G
>> "%~1" echo AHCiBxoFogcbcpcGAHCiBygWAAAKbyYAAAoAKhMwBAB9AAAABQAAEQAABQsWDCtq
>> "%~1" echo BwiaCgAEJS0GJnL1BQBwBhtvJwAAChb+BBb+AQ0JLUUCHI0PAAABEwQRBBYDohEE
>> "%~1" echo F3KbBgBwohEEGAaiEQQZcrMGAHCiEQQaBChZAAAGohEEG3KXBgBwohEEKBYAAApv
>> "%~1" echo JgAACgAACBdYDAgHjmn+BA0JLYwqAAAAGzAEAJgDAAAGAAARAAITCQACIBAnAABv
>> "%~1" echo KAAACgACIBAnAABvKQAACgACbyoAAAoKBigJAAAKcysAAAoLB28sAAAKDAgoLQAA
>> "%~1" echo Chb+ARMKEQotBd1LAwAACBeNIAAAARMLEQsWHyCdEQtvLgAACg0JjmkY/gQW/gET
>> "%~1" echo ChEKLQXdIAMAAAkWmm8vAAAKEwQJF5oTBQAHbywAAAoTBgARBigtAAAKFv4BEwoR
>> "%~1" echo Ci3mcrkAAHB+AwAABIwWAAABEQUoFQAACnMwAAAKEwcRB28xAAAKcsEGAHAoCwAA
>> "%~1" echo Chb+ARMKEQotOwARB28yAAAKKGIAAAYTChEKLRcABnLZBgBwKGEAAAYoZQAABgDd
>> "%~1" echo lgIAAAYoBgAABihlAAAGAN2FAgAAEQdvMQAACnLrBgBwKAsAAAoW/gETChEKOssA
>> "%~1" echo AAAAEQdvMgAACihiAAAGEwoRCi0XAAZy2QYAcChhAAAGKGUAAAYA3T4CAAARBHID
>> "%~1" echo BwBwKCUAAAoW/gETChEKLRcABnINBwBwKGEAAAYoZQAABgDdEgIAABEHbzIAAApy
>> "%~1" echo MQcAcChjAAAGEwgRCChdAAAGLCARB28yAAAKcj8HAHAoYwAABnJPBwBwKCUAAAoW
>> "%~1" echo /gErARcAEwoRCi0XAAZyVwcAcChhAAAGKGUAAAYA3bcBAAAGEQgRB28yAAAKKAcA
>> "%~1" echo AAYoZQAABgDdnQEAABEHbzEAAApybwcAcCgLAAAKFv4BEwoRCi07ABEHbzIAAAoo
>> "%~1" echo YgAABhMKEQotFwAGctkGAHAoYQAABihlAAAGAN1ZAQAABigIAAAGKGUAAAYA3UgB
>> "%~1" echo AAARB28xAAAKcoMHAHAoCwAAChb+ARMKEQotZwARB28yAAAKKGIAAAYTChEKLRcA
>> "%~1" echo BnLZBgBwKGEAAAYoZQAABgDdBAEAABEEcgMHAHAoJQAAChb+ARMKEQotFwAGcpsH
>> "%~1" echo AHAoYQAABihlAAAGAN3YAAAABigJAAAGKGUAAAYA3ccAAAARB28xAAAKcrsHAHAb
>> "%~1" echo bzMAAAoW/gETChEKLUEAEQdvMgAACihiAAAGEwoRCi0eAAZyzwcAcCgJAAAKctkG
>> "%~1" echo AHBvNAAACihmAAAGAN57BhEHbzEAAAooCwAABgDeaxEHbzEAAApyAwgAcCgLAAAK
>> "%~1" echo Fv4BEwoRCi0eAAZyHQgAcCgJAAAKcjkIAHBvNAAACihmAAAGAN4zBnLuCQBwKAkA
>> "%~1" echo AAooaQAABm80AAAKKGYAAAYAAN4UEQkU/gETChEKLQgRCW8kAAAKANwAACpBHAAA
>> "%~1" echo AgAAAAQAAAB9AwAAgQMAABQAAAAAAAAAEzAFAH4EAAAHAAARAChgAAAGCgZyIAoA
>> "%~1" echo cHIwCgBwfgMAAASMFgAAASg1AAAKbzYAAAoABnJGCgBwfgEAAARvNgAACgAGclYK
>> "%~1" echo AHB+BgAABG82AAAKABIBEgIoEgAABg0GcmYKAHAJbzYAAAoABnJ+CgBwByhZAAAG
>> "%~1" echo bzYAAAoABnKUCgBwCG82AAAKAAZyngoAcAlysgoAcCgLAAAKLQdywAoAcCsFcswK
>> "%~1" echo AHAAbzYAAAoACXKyCgBwKCUAAAoW/gETBhEGLU0AHI0PAAABEwcRBxZy1goAcKIR
>> "%~1" echo BxcJohEHGHKzAQBwohEHGQcoWQAABqIRBxpyswEAcKIRBxsIohEHKBYAAAooEAAA
>> "%~1" echo BgAGEwU4dQMAAAcXjSAAAAETCBEIFh8gnREIby4AAAoWmhMEBnLiCgBwEQRvNgAA
>> "%~1" echo CgAGcvAKAHARBHL8CgBwKBMAAAZvNgAACgAGch4LAHARBHIuCwBwKBMAAAZvNgAA
>> "%~1" echo CgAGcmALAHARBHJoCwBwKBMAAAZvNgAACgAGcpILAHARBHKuCwBwKBMAAAZvNgAA
>> "%~1" echo CgAGcu4LAHARBHIIDABwKBMAAAZvNgAACgAGcjgMAHARBHJEDABwKBMAAAZvNgAA
>> "%~1" echo CgAGcmYMAHARBHJ+DABwKBMAAAZvNgAACgAGcp4MAHARBHK6DABwKBMAAAZvNgAA
>> "%~1" echo CgAGct4MAHARBHLqDABwKBMAAAZvNgAACgAGcgwNAHARBHIUDQBwKBMAAAYRBHI8
>> "%~1" echo DQBwKBMAAAYoMgAABm82AAAKAAZyVg0AcBEEcmYNAHAoEwAABm82AAAKAAZyjg0A
>> "%~1" echo cBEEcqYNAHAoEwAABm82AAAKAAZyxg0AcBEEcugNAHAoEwAABm82AAAKAAZyIg4A
>> "%~1" echo cBEEcjoOAHAoEwAABm82AAAKAAZyeA4AcBEEcoAOAHAoEwAABm82AAAKAAZypg4A
>> "%~1" echo cBEEKC0AAAZvNgAACgAGcrQOAHARBHLKDgBwctgOAHAoFAAABm82AAAKAAZy8A4A
>> "%~1" echo cBEEcsoOAHByAA8AcCgUAAAGbzYAAAoABnIiDwBwEQRyyg4AcHIwDwBwKBQAAAZv
>> "%~1" echo NgAACgAGcmIPAHARBHLKDgBwcnYPAHAoFAAABm82AAAKAAZymg8AcBEEcq4PAHBy
>> "%~1" echo vA8AcCgUAAAGbzYAAAoABnLiDwBwEQRy/A8AcHIKEABwKBQAAAZvNgAACgAGciYQ
>> "%~1" echo AHARBHLKDgBwcjgQAHAoFAAABm82AAAKAAYRBCgdAAAGAAYRBCgeAAAGAAYRBCgf
>> "%~1" echo AAAGAAYRBCggAAAGAAYRBCghAAAGAAYRBCgiAAAGAAYRBCgjAAAGAAYRBCgkAAAG
>> "%~1" echo AB8MjQ8AAAETBxEHFnJMEABwohEHFwZy8AoAcG83AAAKohEHGHJmEABwohEHGQZy
>> "%~1" echo ehAAcG83AAAKohEHGnKUEABwohEHGwZypBAAcG83AAAKohEHHHK8EABwohEHHQZy
>> "%~1" echo zBAAcG83AAAKohEHHnLkEABwohEHHwkGciIPAHBvNwAACqIRBx8KcvYQAHCiEQcf
>> "%~1" echo CwZy8A4AcG83AAAKohEHKBYAAAooEAAABgAGEwUrABEFKgAAGzAFAPoHAAAIAAAR
>> "%~1" echo AChgAAAGCgZyMQcAcAIoWQAABm82AAAKACgOAAAGC3IKEQBwAihZAAAGchYRAHAH
>> "%~1" echo KDgAAAooEAAABgAAAnIoEQBwKAsAAAoW/gETCBEILV8AIKAPAAAXjQ8AAAETCREJ
>> "%~1" echo FnJAEQBwohEJKBgAAAYmIF4BAAAoOQAACgAgoA8AABeNDwAAARMJEQkWclgRAHCi
>> "%~1" echo EQkoGAAABiYGcnIRAHBygBEAcG82AAAKAAA4uAYAAAAHcp4RAHAoCwAAChb+ARMI
>> "%~1" echo EQgtC3KiEQBwczoAAAp6AnLEEQBwKAsAAAoW/gETCBEILTsABygNAAAGACD6AAAA
>> "%~1" echo KDkAAAoAByCsDQAActoRAHAoFwAABiYGcnIRAHByFBIAcG82AAAKAAA4SAYAAAJy
>> "%~1" echo XhIAcCgLAAAKFv4BEwgRCC0fAAcoDAAABgAGcnIRAHBydBIAcG82AAAKAAA4FQYA
>> "%~1" echo AAJyhhIAcCgLAAAKFv4BEwgRCC0fAAcoDAAABgAGcnIRAHBynBIAcG82AAAKAAA4
>> "%~1" echo 4gUAAAJyHBMAcCgLAAAKFv4BEwgRCC0fAAcoDQAABgAGcnIRAHByOBMAcG82AAAK
>> "%~1" echo AAA4rwUAAAJyXhMAcCgLAAAKFv4BEwgRCC0fAAcoDQAABgAGcnIRAHByeBMAcG82
>> "%~1" echo AAAKAAA4fAUAAAJyjBMAcCgLAAAKFv4BEwgRCC0fAAcoGwAABgAGcnIRAHByqhMA
>> "%~1" echo cG82AAAKAAA4SQUAAAJy2hMAcCgLAAAKFv4BEwgRCC0pAAcgrA0AAHLuEwBwKBcA
>> "%~1" echo AAYmBnJyEQBwclYUAHBvNgAACgAAOAwFAAACcnQUAHAoCwAAChb+ARMIEQgtKQAH
>> "%~1" echo IKwNAAByihQAcCgXAAAGJgZychEAcHL0FABwbzYAAAoAADjPBAAAAnIUFQBwKAsA
>> "%~1" echo AAoW/gETCBEILU0AIIgTAAAajQ8AAAETCREJFnImFQBwohEJFweiEQkYciwVAHCi
>> "%~1" echo EQkZcjgVAHCiEQkoGAAABiYGcnIRAHByQhUAcG82AAAKAAA4bgQAAAJyZhUAcCgL
>> "%~1" echo AAAKFv4BEwgRCC1VAAcgrA0AAHKAFQBwKBcAAAYmIIgTAAAZjQ8AAAETCREJFnIm
>> "%~1" echo FQBwohEJFweiEQkYcs4VAHCiEQkoGAAABiYGcnIRAHBy1hUAcG82AAAKAAA4BQQA
>> "%~1" echo AAJyNBYAcCgLAAAKFv4BEwgRCC0pAAcgrA0AAHLaEQBwKBcAAAYmBnJyEQBwckgW
>> "%~1" echo AHBvNgAACgAAOMgDAAACcm4WAHAoCwAAChb+ARMIEQgtKQAHIKwNAAByhBYAcCgX
>> "%~1" echo AAAGJgZychEAcHLAFgBwbzYAAAoAADiLAwAAAnIEFwBwKAsAAAoW/gETCBEILSkA
>> "%~1" echo ByCsDQAAchgXAHAoFwAABiYGcnIRAHBydBcAcG82AAAKAAA4TgMAAAJyrhcAcCgL
>> "%~1" echo AAAKFv4BEwgRCC0wAAcoGQAABgAHIKwNAAByxBcAcCgXAAAGJgZychEAcHIkGABw
>> "%~1" echo bzYAAAoAADgKAwAAAnJiGABwKAsAAAoW/gETCBEILSkAByCsDQAAcnQYAHAoFwAA
>> "%~1" echo BiYGcnIRAHBy0hgAcG82AAAKAAA4zQIAAAJyDhkAcCgLAAAKFv4BEwgRCC0wAAco
>> "%~1" echo GQAABgAHIKwNAAByJhkAcCgXAAAGJgZychEAcHKEGQBwbzYAAAoAADiJAgAAAnLA
>> "%~1" echo GQBwKAsAAAoW/gETCBEILSkAByCsDQAAchgXAHAoFwAABiYGcnIRAHBy4hkAcG82
>> "%~1" echo AAAKAAA4TAIAAAJyJBoAcCgLAAAKFv4BEwgRCC0pAAcgrA0AAHJ0GABwKBcAAAYm
>> "%~1" echo BnJyEQBwckAaAHBvNgAACgAAOA8CAAACcoQaAHAoCwAAChb+ARMIEQgtKQAHIKwN
>> "%~1" echo AAByphoAcCgXAAAGJgZychEAcHL2GgBwbzYAAAoAADjSAQAAAnIsGwBwKAsAAAoW
>> "%~1" echo /gETCBEILToAByCsDQAAclQbAHAoFwAABiYHIKwNAABy7hMAcCgXAAAGJgZychEA
>> "%~1" echo cHKeGwBwbzYAAAoAADiEAQAAAnLgGwBwKAsAAAoW/gETCBEIOvUAAAAAA3L+GwBw
>> "%~1" echo KGMAAAYMA3IEHABwKGMAAAYNA3IMHABwKGMAAAYTBAgoWwAABiwICShcAAAGKwEW
>> "%~1" echo ABMIEQgtC3IYHABwczoAAAp6CSheAAAGFv4BEwgRCC0LcjwcAHBzOgAACnoHKBkA
>> "%~1" echo AAYAByCsDQAAHI0PAAABEwkRCRZyaBwAcKIRCRcIohEJGHKzAQBwohEJGQmiEQka
>> "%~1" echo crMBAHCiEQkbEQQoXwAABqIRCSgWAAAKKBcAAAYmBnJyEQBwG40PAAABEwkRCRYI
>> "%~1" echo ohEJF3KEHABwohEJGAmiEQkZcogcAHCiEQkaEQSiEQkoFgAACm82AAAKAAAreAJy
>> "%~1" echo kBwAcCgLAAAKFv4BEwgRCC1ZAANyshwAcChjAAAGEwURBShcAAAGEwgRCC0Lcrwc
>> "%~1" echo AHBzOgAACnoHIKwNAAByzhwAcBEFKAgAAAooFwAABiYGcnIRAHBy8BwAcBEFKAgA
>> "%~1" echo AApvNgAACgAAKwty/hwAcHM6AAAKegByCh0AcAIoWQAABnIWHQBwBnJyEQBwbzsA
>> "%~1" echo AAotB3KeEQBwKwsGcnIRAHBvNwAACgAoOAAACigQAAAGAADeTBMGAAZyKB0AcHLA
>> "%~1" echo CgBwbzYAAAoABnIuHQBwEQZvBwAACm82AAAKAHI6HQBwAihZAAAGckYdAHARBm8H
>> "%~1" echo AAAKKDgAAAooEAAABgAA3gAABhMHKwARByoAAEEcAAAAAAAAOwAAAGoHAAClBwAA
>> "%~1" echo TAAAAA4AAAETMAMALwAAAAkAABEAKGAAAAYKBnJWCgBwfgYAAARvNgAACgAGclYd
>> "%~1" echo AHAoEQAABm82AAAKAAYLKwAHKgAbMAQARAIAAAoAABEAKGAAAAYKKDwAAAoLcmAd
>> "%~1" echo AHAoEAAABgAAEgISAygSAAAGEwQRBHKyCgBwKCUAAAoW/gETEBEQLQcJczoAAAp6
>> "%~1" echo CBeNIAAAARMREREWHyCdERFvLgAAChaaEwURBQgoJQAABhMGKDwAAAoTEhIScoYd
>> "%~1" echo AHAoPQAAChMHfgUAAARyph0AcBEHKD4AAAoTCBEIKD8AAAomcrYdAHARB3LuHQBw
>> "%~1" echo KEAAAAoTCXL6HQBwEQdy7h0AcChAAAAKEwoRCBEJKEEAAAoTCxEIEQooQQAAChMM
>> "%~1" echo EQsRBhYoKgAABn4IAAAEKEIAAAoAEQwRBhcoKgAABn4IAAAEKEIAAAoAKDwAAAoH
>> "%~1" echo KEMAAAoTDQZyLh4AcBELbzYAAAoABnJGHgBwEQxvNgAACgAGclgeAHARBxEJKAoA
>> "%~1" echo AAZvNgAACgAGcm4eAHARBxEKKAoAAAZvNgAACgAGcn4eAHASDShEAAAKahMTEhMo
>> "%~1" echo RQAACihGAAAKbzYAAAoABnKUHgBwEQZ7GgAABG9HAAAKExQSFChFAAAKKEgAAApv
>> "%~1" echo NgAACgAGcq4eAHARBnsbAAAEbx4AAAosGHLAHgBwEQZ7GwAABG9JAAAKKEoAAAor
>> "%~1" echo BXKeEQBwAG82AAAKAAZychEAcHLIHgBwbzYAAAoAcvIeAHARC3L+HgBwEQwoOAAA
>> "%~1" echo CigQAAAGAADeQRMOAAZyKB0AcHLACgBwbzYAAAoABnIuHQBwEQ5vBwAACm82AAAK
>> "%~1" echo AHIGHwBwEQ5vBwAACigIAAAKKBAAAAYAAN4AAAYTDysAEQ8qQRwAAAAAAAAYAAAA
>> "%~1" echo 4gEAAPoBAABBAAAADgAAARMwAwBKAAAACwAAEQAcjQ8AAAELBxZyuwcAcKIHFwIo
>> "%~1" echo SwAACqIHGHKfAQBwogcZAyhLAAAKogcachIfAHCiBxt+AgAABChLAAAKogcoFgAA
>> "%~1" echo CgorAAYqAAAbMAUAEgEAAAwAABEAAANyuwcAcG9MAAAKb00AAAooTgAACh8vfk8A
>> "%~1" echo AApvUAAACgoGciIfAHAabycAAAoWLxkGHzpvUQAAChYvDgZy7h0AcBtvUgAACisB
>> "%~1" echo FgATBBEELSEAAnLPBwBwKAkAAApyKB8AcG80AAAKKGYAAAYA3ZsAAAB+BQAABHKm
>> "%~1" echo HQBwKEEAAAooUwAACgsHBihBAAAKKFMAAAoMCAcbbzMAAAosCAgoVAAACisBFgAT
>> "%~1" echo BBEELR4AAnLPBwBwKAkAAApyNh8AcG80AAAKKGYAAAYA3kECcu4JAHAIKFUAAAoo
>> "%~1" echo ZgAABgAA3isNAAJyzwcAcCgJAAAKckIfAHAJbwcAAAooCAAACm80AAAKKGYAAAYA
>> "%~1" echo AN4AAAAqAAABEAAAAAABAOPkACsOAAABAzADAF4AAAAAAAAAAAIoGQAABgACIKwN
>> "%~1" echo AAByJhkAcCgXAAAGJgIgrA0AAHJSHwBwKBcAAAYmAiCsDQAAcsQXAHAoFwAABiYC
>> "%~1" echo IKwNAAByoh8AcCgXAAAGJgIgrA0AAHKKFABwKBcAAAYmKgAAAzADAFcAAAAAAAAA
>> "%~1" echo AAIgrA0AAHJ0GABwKBcAAAYmAiCsDQAAcqYaAHAoFwAABiYCIKwNAAByGBcAcCgX
>> "%~1" echo AAAGJgIgrA0AAHJUGwBwKBcAAAYmAiCsDQAAcu4TAHAoFwAABiYqABMwBAA4AAAA
>> "%~1" echo DQAAEQASABIBKBIAAAZysgoAcCgLAAAKLQdynhEAcCsVBheNIAAAAQ0JFh8gnQlv
>> "%~1" echo LgAAChaaAAwrAAgqGzAEAOIAAAAOAAARAAACKC0AAAotAwIrCigNAAAKbw4AAAoA
>> "%~1" echo CgYXjSAAAAELBxYfIp0Hb1YAAAoKBihTAAAKCgYoVwAACgwILQcGKD8AAAomBoAE
>> "%~1" echo AAAEBnLsHwBwKEEAAAqABQAABH4FAAAEKD8AAAomfgUAAARyCiAAcCg8AAAKDRID
>> "%~1" echo coYdAHAoPQAACnIYIABwKEAAAAooQQAACoAGAAAEfgYAAARy9QUAcH4IAAAEKFgA
>> "%~1" echo AAoAAN4yJgAoDQAACm8OAAAKgAQAAAR+BAAABIAFAAAEfgUAAARyIiAAcChBAAAK
>> "%~1" echo gAYAAAQA3gAAKgAAARAAAAAAAQCtrgAyAQAAARswBQBkAAAADwAAEQAAFgp+BwAA
>> "%~1" echo BCULEgAoWQAACgAAfgYAAAQoPAAACgwSAnJKIABwKD0AAApyeiAAcAIoWgAACig4
>> "%~1" echo AAAKfggAAAQoWAAACgAA3hAGFv4BDQktBwcoWwAACgDcAADeBSYAAN4AACoBHAAA
>> "%~1" echo AgAEAEVJABAAAAAAAAABAFxdAAUBAAABGzAFAKwAAAAQAAARAAB+BgAABCgtAAAK
>> "%~1" echo LQx+BgAABChUAAAKKwEWABMHEQctCXKAIABwEwbefX4GAAAEKFUAAAoKIFBGAAAL
>> "%~1" echo Bo5pBzADFisFBo5pB1kADCgJAAAKBggGjmkIWW9cAAAKDQkfCm9RAAAKEwQIFjEH
>> "%~1" echo EQQW/gQrARcAEwcRBy0LCREEF1hvTQAACg0JKFkAAAYTBt4YEwUAcpQgAHARBW8H
>> "%~1" echo AAAKKAgAAAoTBt4AABEGKgEQAAAAAAEAj5AAGA4AAAETMAQAFgMAABEAABEAAnL1
>> "%~1" echo BQBwUQNypCAAcFFy9QUAcApy9QUAcAty9QUAcAxy9QUAcA1y9QUAcBMEcvUFAHAT
>> "%~1" echo BQAguAsAABiNDwAAARMLEQsWcv4gAHCiEQsXcg4hAHCiEQsoFgAABihaAAAGEwwW
>> "%~1" echo Ew04lwEAABEMEQ2aEwYAEQZvXQAAChMHEQdvTAAACiwSEQdyFCEAcBtvMwAAChb+
>> "%~1" echo ASsBFgATDhEOLQU4WAEAABEHGI0gAAABEw8RDxYfIJ0RDxcfCZ0RDxdvXgAAChMI
>> "%~1" echo EQiOaRj+BBb+ARMOEQ4tBTgjAQAAEQgXmnKyCgBwKAsAAAoW/gETDhEOOp0AAAAA
>> "%~1" echo CW9MAAAKFv4BFv4BEw4RDi0DEQcNEQdyJCEAcBtvJwAAChYvJREHcjwhAHAbbycA
>> "%~1" echo AAoWLxURB3JaIQBwG28nAAAKFv4EFv4BKwEXABMJEQksDxEEb0wAAAoW/gEW/gEr
>> "%~1" echo ARcAEw4RDi0EEQcTBBEJLB0RCBaaHzpvUQAAChYvDxEFb0wAAAoW/gEW/gErARcA
>> "%~1" echo Ew4RDi0EEQcTBStsEQgXmnJ2IQBwKAsAAAosDgZvTAAAChb+ARb+ASsBFwATDhEO
>> "%~1" echo LQURBworQBEIF5pykCEAcCgLAAAKLA4Hb0wAAAoW/gEW/gErARcAEw4RDi0FEQcL
>> "%~1" echo KxUIb0wAAAoW/gEW/gETDhEOLQMRBwwAEQ0XWBMNEQ0RDI5p/gQTDhEOOlj+//8R
>> "%~1" echo BW9MAAAKFv4CFv4BEw4RDi0YAAIRBVEDcqAhAHBRcrIKAHATCjjVAAAAEQRvTAAA
>> "%~1" echo Chb+Ahb+ARMOEQ4tGAACEQRRA3LSIQBwUXKyCgBwEwo4qgAAAAlvTAAAChb+Ahb+
>> "%~1" echo ARMOEQ4tFwACCVEDcvghAHBRcrIKAHATCjiBAAAABm9MAAAKFv4CFv4BEw4RDi0U
>> "%~1" echo AAIGUQNySCIAcFFydiEAcBMKK1sHb0wAAAoW/gIW/gETDhEOLRQAAgdRA3KEIgBw
>> "%~1" echo UXKQIQBwEworNQhvTAAAChb+Ahb+ARMOEQ4tGgACCFEDcsAiAHAIKAgAAApRctYi
>> "%~1" echo AHATCisJcuYiAHATCisAEQoqAAATMAQAIQAAABIAABEAAiDECQAAcvAiAHADKAgA
>> "%~1" echo AAooFQAABihZAAAGCisABioAAAATMAYAPgAAABMAABEAAiDECQAAcgIjAHADcrMB
>> "%~1" echo AHAEKDgAAAooFQAABihZAAAGCgZyHiMAcCgLAAAKLQMGKwVyHiMAcAALKwAHKgAA
>> "%~1" echo EzAEADEAAAALAAARAAMajQ8AAAELBxZyJhUAcKIHFwKiBxhyKCMAcKIHGQSiBygW
>> "%~1" echo AAAGKFkAAAYKKwAGKgAAABMwAwASAAAAEgAAEQB+AQAABAMCKC4AAAYKKwAGKgAA
>> "%~1" echo EzAEADEAAAALAAARAAMajQ8AAAELBxZyJhUAcKIHFwKiBxhyKCMAcKIHGQSiBygY
>> "%~1" echo AAAGKFkAAAYKKwAGKgAAABMwAwCLAAAAFAAAEQB+AQAABAMCKC8AAAYKBm9uAAAG
>> "%~1" echo KFkAAAYLBnsOAAAEFv4BDQktFnI0IwBwAygwAAAGKAgAAApzOgAACnoGew0AAAQW
>> "%~1" echo /gENCS07Go0BAAABEwQRBBZySCMAcKIRBBcGew0AAASMFgAAAaIRBBhyXCMAcKIR
>> "%~1" echo BBkHohEEKBQAAApzOgAACnoHDCsACCoAEzAEAM0AAAAVAAARAAIoHAAABgoGKFQA
>> "%~1" echo AAoW/gEMCC0FOLIAAABzXwAACgsHcmIjAHBvYAAACiYHcogjAHACKAgAAApvYAAA
>> "%~1" echo CiYHcpwjAHAoPAAACg0SA3KyIwBwKD0AAAooCAAACm9gAAAKJgcCcsoOAHByMA8A
>> "%~1" echo cCgaAAAGAAcCcsoOAHBydg8AcCgaAAAGAAcCcq4PAHByvA8AcCgaAAAGAAcCcvwP
>> "%~1" echo AHByChAAcCgaAAAGAAYHb2EAAAp+CAAABChCAAAKAHLaIwBwBigIAAAKKBAAAAYA
>> "%~1" echo KgAAABMwBgBqAAAAFgAAEQADIKwNAAByAiMAcARyswEAcAUoOAAACigXAAAGCgZy
>> "%~1" echo nhEAcCgLAAAKFv4BCwctF3LsIwBwBHKEHABwBSg4AAAKczoAAAp6AgRvYgAACh8g
>> "%~1" echo b2MAAAoFb2IAAAofIG9jAAAKBm9gAAAKJioAABMwBwByAQAAFwAAEQACKBwAAAYK
>> "%~1" echo BihUAAAKEwQRBC0Rcv4jAHAGKAgAAApzOgAACnoABigJAAAKKGQAAAoTBRYTBjgD
>> "%~1" echo AQAAEQURBpoLAAdvXQAACgwIb0wAAAosEQhyEiQAcBpvMwAAChb+ASsBFgATBBEE
>> "%~1" echo LQU4yQAAAAgXjSAAAAETBxEHFh8gnREHGW9lAAAKDQmOaRkyFAkWmihbAAAGLAoJ
>> "%~1" echo F5ooXAAABisBFgATBBEELQU4igAAAAkYmnIeIwBwKAsAAAoW/gETBBEELSMCIKwN
>> "%~1" echo AAByFiQAcAkWmnKzAQBwCReaKDgAAAooFwAABiYrUAIgrA0AAByNDwAAARMIEQgW
>> "%~1" echo cmgcAHCiEQgXCRaaohEIGHKzAQBwohEIGQkXmqIRCBpyswEAcKIRCBsJGJooXwAA
>> "%~1" echo BqIRCCgWAAAKKBcAAAYmABEGF1gTBhEGEQWOaf4EEwQRBDrs/v//AiCsDQAAcu4T
>> "%~1" echo AHAoFwAABiZyOCQAcAYoCAAACigQAAAGACoAABMwBACEAAAAGAAAEQACJS0GJnKy
>> "%~1" echo CgBwCgZySCQAcHJMJABwb2YAAApyhBwAcHJMJABwb2YAAApyUCQAcHJMJABwb2YA
>> "%~1" echo AApynwEAcHJMJABwb2YAAAoKfgQAAAQoLQAACi0HfgQAAAQrCigNAAAKbw4AAAoA
>> "%~1" echo CwdyVCQAcAZyfCQAcChAAAAKKEEAAAoMKwAIKhMwBADXAAAAGQAAEQADIMQJAABy
>> "%~1" echo hiQAcCgVAAAGCgJyehAAcAZypiQAcCg2AAAGbzYAAAoABnKyJABwKDYAAAYLByD/
>> "%~1" echo AQAAKEUAAAoSAihnAAAKLBEIIwAAAAAAAFlA/gIW/gErARcADQktHwgjAAAAAAAA
>> "%~1" echo JEBbEwQSBHLKJABwKEUAAAooaAAACgsCcqQQAHAHbzYAAAoAAnLSJABwBnLuJABw
>> "%~1" echo KDYAAAYoMwAABm82AAAKAAJy/CQAcAZyGCUAcCg2AAAGKDQAAAZvNgAACgACciYl
>> "%~1" echo AHAGKDUAAAZvNgAACgAqABMwBACGAAAAEgAAEQADIIgTAAByPiUAcCgVAAAGCgJy
>> "%~1" echo zBAAcAZyWiUAcCg3AAAGbzYAAAoAAnJ0JQBwBnJ0JQBwKDcAAAZvNgAACgACcoQl
>> "%~1" echo AHAGcoQlAHAoNwAABm82AAAKAAJyqiUAcAZyyCUAcCg3AAAGbzYAAAoAAnICJgBw
>> "%~1" echo BnIgJgBwKDgAAAZvNgAACgAqAAATMAQAtgEAABoAABEAAnI+JgBwcp4RAHBvNgAA
>> "%~1" echo CgACcmomAHBynhEAcG82AAAKAAJymCYAcHKeEQBwbzYAAAoAAnLCJgBwcp4RAHBv
>> "%~1" echo NgAACgACcu4mAHByDCcAcG82AAAKAAMgiBMAAHIgJwBwKBUAAAYKcx0AAAoLAAYo
>> "%~1" echo WgAABhMHFhMIOPgAAAARBxEImgwACG9dAAAKDQlyUicAcBtvJwAAChYyFAlyZCcA
>> "%~1" echo cBtvJwAAChb+BBb+ASsBFgATCREJLQU4tAAAAAlycCcAcCg5AAAGEwQJcnonAHAo
>> "%~1" echo OQAABhMFCXKKJwBwKDkAAAYTBhEEcpgnAHAbbxgAAAoW/gETCREJLR4AAnI+JgBw
>> "%~1" echo EQVvNgAACgACcpgmAHARBm82AAAKAAARBHKiJwBwG28YAAAKFv4BEwkRCS0eAAJy
>> "%~1" echo aiYAcBEFbzYAAAoAAnLCJgBwEQZvNgAACgAABwlvTAAACiCMAAAAMAMJKwwJFiCM
>> "%~1" echo AAAAb2kAAAoAbyYAAAoAABEIF1gTCBEIEQeOaf4EEwkRCTr3/v//B28eAAAKFv4C
>> "%~1" echo Fv4BEwkRCS0cAnLuJgBwcsAeAHAHb0kAAAooSgAACm82AAAKACoAABMwBgByAQAA
>> "%~1" echo GwAAEQACcq4nAHBynhEAcG82AAAKAAJyvicAcHKeEQBwbzYAAAoAAyCsDQAAcswn
>> "%~1" echo AHAoFQAABgoABihaAAAGEwcWEwg4pwAAABEHEQiaCwAHb10AAAoMCG9MAAAKLBEI
>> "%~1" echo cugnAHAbbzMAAAoW/gErARYAEwkRCS0CK3AIGI0gAAABEwoRChYfIJ0RChcfCZ0R
>> "%~1" echo ChdvXgAACg0Jjmkb/gQTCREJLUUAAnKuJwBwG40PAAABEwsRCxYJGJqiEQsXcv4e
>> "%~1" echo AHCiEQsYCReaohELGXL+JwBwohELGgkamqIRCygWAAAKbzYAAAoAKxgAEQgXWBMI
>> "%~1" echo EQgRB45p/gQTCREJOkj///8DIKwNAAByCCgAcCgVAAAGEwQRBHIsKABwKDsAAAYT
>> "%~1" echo BREEckAoAHAoOwAABhMGEQVynhEAcCglAAAKLBERBnKeEQBwKCUAAAoW/gErARcA
>> "%~1" echo EwkRCS0fAnK+JwBwclwoAHARBnJkKABwEQUoOAAACm82AAAKACoAABMwBACcAAAA
>> "%~1" echo HAAAEQACcnIoAHBynhEAcG82AAAKAAJyhigAcHKeEQBwbzYAAAoAcpooAHAKAyCI
>> "%~1" echo EwAAcsgoAHAGKAgAAAooFQAABgsHcuooAHAGcpcGAHAoQAAAChtvJwAAChb+BBb+
>> "%~1" echo AQ0JLQIrOAJycigAcAZvNgAACgAHcv4oAHAoOgAABgwIcp4RAHAoJQAAChb+AQ0J
>> "%~1" echo LQ0CcoYoAHAIbzYAAAoAKhMwBABQAQAAHQAAEQACchgpAHBynhEAcG82AAAKAAMg
>> "%~1" echo iBMAAHI2KQBwKBUAAAYKBnJWKQBwKDgAAAYLB3KeEQBwKAsAAAoW/gETBxEHLQU4
>> "%~1" echo BwEAAAdyeikAcCg/AAAGDAdyqikAcCg/AAAGDQdy4ikAcCg/AAAGEwQHcggqAHBy
>> "%~1" echo OCoAcCg+AAAGEwVzHQAAChMGCHKeEQBwKCUAAAoW/gETBxEHLRgRBghyswEAcHL1
>> "%~1" echo BQBwb2YAAApvJgAACgAJcp4RAHAoJQAAChb+ARMHEQctExEGCXI8KgBwKAgAAApv
>> "%~1" echo JgAACgARBHKeEQBwKCUAAAoW/gETBxEHLRQRBnJCKgBwEQQoCAAACm8mAAAKABEF
>> "%~1" echo cp4RAHAoJQAAChb+ARMHEQctChEGEQVvJgAACgACchgpAHARBm8eAAAKLBNy/h4A
>> "%~1" echo cBEGb0kAAAooSgAACisFcp4RAHAAbzYAAAoAKhMwBwC5AAAAHAAAEQACclQqAHBy
>> "%~1" echo nhEAcG82AAAKAAMgiBMAAHJyKgBwKBUAAAYKBnKgKgBwKDYAAAYLBnK+KgBwKEAA
>> "%~1" echo AAYMCHKeEQBwKAsAAAoW/gENCS0MBnICKwBwKEAAAAYMB3KeEQBwKCUAAAotEAhy
>> "%~1" echo nhEAcCglAAAKFv4BKwEWAA0JLTwCclQqAHByQCsAcAcIcp4RAHAoJQAACi0HcvUF
>> "%~1" echo AHArEHJQKwBwCHJoKwBwKEAAAAoAKEAAAApvNgAACgAqAAAAEzAEAEoBAAAdAAAR
>> "%~1" echo AAJybCsAcHKeEQBwbzYAAAoAAyBwFwAAcoorAHAoFQAABgoGchAEAHAoQQAABgsG
>> "%~1" echo cuwDAHAoQQAABgwGcjIEAHAoQQAABg0Gcm4EAHAoQQAABhMEBnKOBABwKEEAAAYT
>> "%~1" echo BXMdAAAKEwYIcp4RAHAoJQAAChb+ARMHEQctCREGCG8mAAAKAAdynhEAcCglAAAK
>> "%~1" echo Fv4BEwcRBy0JEQYHbyYAAAoACXKeEQBwKCUAAAoW/gETBxEHLRMRBnK2KwBwCSgI
>> "%~1" echo AAAKbyYAAAoAEQRynhEAcCglAAAKFv4BEwcRBy0UEQZyyCsAcBEEKAgAAApvJgAA
>> "%~1" echo CgARBXKeEQBwKCUAAAoW/gETBxEHLRQRBnLSKwBwEQUoCAAACm8mAAAKAAJybCsA
>> "%~1" echo cBEGbx4AAAosE3L+HgBwEQZvSQAACihKAAAKKwVynhEAcABvNgAACgAqAAATMAcA
>> "%~1" echo 6AIAAB4AABEAc3IAAAYKBig8AAAKDBICcrIjAHAoPQAACn0WAAAEBgJ9FwAABAYD
>> "%~1" echo fRgAAAQGcuQrAHAgoA8AABYYjQ8AAAENCRZy/iAAcKIJF3IOIQBwogkoJwAABgAG
>> "%~1" echo cvwrAHACILgLAABy/CsAcCgmAAAGAAZyAiwAcAIgcBcAAHICLABwKCYAAAYABnIS
>> "%~1" echo LABwAiBwFwAAcjIsAHAoJgAABgAGclwsAHACIHAXAAByfCwAcCgmAAAGAAZypiwA
>> "%~1" echo cAIgcBcAAHLGLABwKCYAAAYABnLwLABwAiCIEwAAcoYkAHAoJgAABgAGcgAtAHAC
>> "%~1" echo IFgbAAByPiUAcCgmAAAGAAZyDC0AcAIgKCMAAHI2KQBwKCYAAAYABnLOFQBwAiBY
>> "%~1" echo GwAAchwtAHAoJgAABgAGcjQtAHACICgjAAByPi0AcCgmAAAGAAZyWC0AcAIgQB8A
>> "%~1" echo AHJyLQBwKCYAAAYABnKcLQBwAiBYGwAAcrAtAHAoJgAABgAGcuQtAHACIEAfAABy
>> "%~1" echo 8i0AcCgmAAAGAAZyHC4AcAIg4C4AAHKKKwBwKCYAAAYABnI4LgBwAiBYGwAAcnIq
>> "%~1" echo AHAoJgAABgAGckguAHACIFgbAAByVC4AcCgmAAAGAAZycC4AcAIg4C4AAHKCLgBw
>> "%~1" echo KCYAAAYABnKwLgBwAiBAHwAAcsIuAHAoJgAABgAGcuQuAHACIEAfAABy+C4AcCgm
>> "%~1" echo AAAGAAZyLi8AcAIgiBMAAHI0LwBwKCYAAAYABnJcLwBwAiCIEwAAcggoAHAoJgAA
>> "%~1" echo BgAGcmwvAHACIIgTAAByfC8AcCgmAAAGAAZyoC8AcAIguAsAAHKsLwBwKCYAAAYA
>> "%~1" echo BnK+LwBwAiCIEwAAcs4vAHAoJgAABgAGct4vAHACIIgTAABy8C8AcCgmAAAGAAZy
>> "%~1" echo AjAAcAIgQB8AAHIgMABwKCYAAAYABnJuMABwAiAQJwAAco4wAHAoJgAABgAGcsQw
>> "%~1" echo AHACIBAnAABy7DAAcCgmAAAGAAYoKQAABgAGCysAByoTMAcALQAAAB8AABEAAgMF
>> "%~1" echo FhqNDwAAAQoGFnImFQBwogYXBKIGGHIoIwBwogYZDgSiBignAAAGACoAAAATMAQA
>> "%~1" echo FgEAACAAABEAKGoAAAoKfgEAAAQOBAQoLwAABgsGb2sAAAoAc3EAAAYMCAN9DwAA
>> "%~1" echo BAhyEDEAcA4EKDAAAAYoCAAACn0QAAAECAd7CwAABChZAAAGfREAAAQIB3sMAAAE
>> "%~1" echo KFkAAAZ9EgAABAgHew0AAAR9EwAABAgHew4AAAR9FAAABAgGb2wAAAp9FQAABAJ7
>> "%~1" echo GgAABAhvbQAACgAHew4AAAQW/gENCS0ZAnsbAAAEA3IaMQBwKAgAAApvJgAACgAr
>> "%~1" echo XAd7DQAABCwGBRb+ASsBFwANCS0kAnsbAAAEA3IiMQBwB29uAAAGKFkAAAYoQAAA
>> "%~1" echo Cm8mAAAKACskB3sNAAAEFv4BDQktFwJ7GwAABANyLDEAcCgIAAAKbyYAAAoAKgAA
>> "%~1" echo GzACAFcAAAAhAAARAAACexoAAARvbgAACgwrHxICKG8AAAoKBnsPAAAEAygLAAAK
>> "%~1" echo Fv4BDQktBAYL3iUSAihwAAAKDQkt1t4PEgL+FgUAABtvJAAACgDcAHNxAAAGCysA
>> "%~1" echo AAcqAAEQAAACAA4ALjwADwAAAAATMAUAlAYAACIAABEAAnsZAAAECgJyAiwAcCgo
>> "%~1" echo AAAGb3AAAAYLAnLwLABwKCgAAAZvcAAABgwCcgAtAHAoKAAABm9wAAAGDQJyDC0A
>> "%~1" echo cCgoAAAGb3AAAAYTBAJyOC4AcCgoAAAGb3AAAAYTBQJyHC4AcCgoAAAGb3AAAAYT
>> "%~1" echo BgJyNC0AcCgoAAAGb3AAAAYTBwJynC0AcCgoAAAGb3AAAAYTCAJyzhUAcCgoAAAG
>> "%~1" echo b3AAAAYTCQJy5C0AcCgoAAAGb3AAAAYTCgJycC4AcCgoAAAGb3AAAAYTCwJysC4A
>> "%~1" echo cCgoAAAGb3AAAAYTDAZy4goAcAJ7FwAABG82AAAKAAZyfgoAcAJ7GAAABG82AAAK
>> "%~1" echo AAZyPDEAcAJ7FgAABG82AAAKAAZy8AoAcAdy/AoAcCg8AAAGbzYAAAoABnLuCwBw
>> "%~1" echo B3IIDABwKDwAAAZvNgAACgAGcjgMAHAHckQMAHAoPAAABm82AAAKAAZyTDEAcAdy
>> "%~1" echo fgwAcCg8AAAGbzYAAAoABnKyCgBwB3K6DABwKDwAAAZvNgAACgAGct4MAHAHcuoM
>> "%~1" echo AHAoPAAABm82AAAKAAZyDA0AcAdyFA0AcCg8AAAGB3I8DQBwKDwAAAYoMgAABm82
>> "%~1" echo AAAKAAZyHgsAcAdyLgsAcCg8AAAGbzYAAAoABnJgCwBwB3JoCwBwKDwAAAZvNgAA
>> "%~1" echo CgAGcpILAHAHcq4LAHAoPAAABm82AAAKAAZyIg4AcAdyOg4AcCg8AAAGbzYAAAoA
>> "%~1" echo BnJWDQBwB3JmDQBwKDwAAAZvNgAACgAGcsYNAHAHcugNAHAoPAAABm82AAAKAAZy
>> "%~1" echo jg0AcAdypg0AcCg8AAAGbzYAAAoABnJcMQBwB3J0MQBwKDwAAAZvNgAACgAGcngO
>> "%~1" echo AHAHcoAOAHAoPAAABm82AAAKAAZynjEAcAJyoC8AcCgoAAAGb3AAAAYoPQAABm82
>> "%~1" echo AAAKAAZyehAAcAhypiQAcCg2AAAGcqwxAHAoCAAACm82AAAKAAhysiQAcCg2AAAG
>> "%~1" echo Ew0RDSD/AQAAKEUAAAoSDihnAAAKLBIRDiMAAAAAAABZQP4CFv4BKwEXABMPEQ8t
>> "%~1" echo IREOIwAAAAAAACRAWxMQEhByyiQAcChFAAAKKGgAAAoTDQZypBAAcBENcp4RAHAo
>> "%~1" echo CwAACi0OEQ1yaCsAcCgIAAAKKwVynhEAcABvNgAACgAGcvwkAHAIchglAHAoNgAA
>> "%~1" echo Big0AAAGbzYAAAoABnImJQBwCCg1AAAGbzYAAAoABnLMEABwCXJaJQBwKDcAAAZv
>> "%~1" echo NgAACgAGciIPAHAJcnQlAHAoNwAABm82AAAKAAZysDEAcAlyhCUAcCg3AAAGbzYA
>> "%~1" echo AAoABnKuJwBwAnIuLwBwKCgAAAZvcAAABihEAAAGbzYAAAoABnK+JwBwAnJcLwBw
>> "%~1" echo KCgAAAZvcAAABihFAAAGbzYAAAoABnLEMQBwAnJsLwBwKCgAAAZvcAAABihGAAAG
>> "%~1" echo bzYAAAoABnIMLQBwEQQoRwAABm82AAAKAAZyzDEAcBEEctgxAHAoOAAABnIIKgBw
>> "%~1" echo cjgqAHAoPgAABm82AAAKAAZyOC4AcBEFKEgAAAZvNgAACgAGcs4VAHARCShJAAAG
>> "%~1" echo bzYAAAoABnI0LQBwEQcCcr4vAHAoKAAABm9wAAAGKEoAAAZvNgAACgAGcpwtAHAR
>> "%~1" echo CChLAAAGbzYAAAoABnLkLQBwEQoRBihMAAAGbzYAAAoABnL8MQBwEQYoTQAABm82
>> "%~1" echo AAAKAAZyDDIAcBEGcuwDAHAoQQAABm82AAAKAAZyKDIAcBEGchAEAHAoQQAABm82
>> "%~1" echo AAAKAAZyQjIAcBEGcjIEAHAoQQAABm82AAAKAAZyWjIAcBEGcm4EAHAoQQAABm82
>> "%~1" echo AAAKAAZyejIAcBEGco4EAHAoQQAABm82AAAKAAZymDIAcBEGcr4yAHAoQQAABm82
>> "%~1" echo AAAKAAZy2DIAcBEGcvAyAHAoQQAABm82AAAKAAZyCDMAcBEGcigzAHAoQQAABm82
>> "%~1" echo AAAKAAZyQDMAcBEGcmYzAHAoQQAABm82AAAKAAZyiDMAcBEGcqwzAHAbbycAAAoW
>> "%~1" echo LwdynhEAcCsFctwzAHAAbzYAAAoABnJwLgBwEQsoTwAABhMREhEoRQAACihIAAAK
>> "%~1" echo bzYAAAoABnKwLgBwEQxyFDQAcChQAAAGExESEShFAAAKKEgAAApvNgAACgAGciY0
>> "%~1" echo AHACcgIwAHAoKAAABm9wAAAGKE4AAAZvNgAACgAGcq4eAHACexsAAARvHgAACiwX
>> "%~1" echo csAeAHACexsAAARvSQAACihKAAAKKwVynhEAcABvNgAACgAqEzAHAN8GAAAjAAAR
>> "%~1" echo AAJ7GQAABAoDLQdyLDQAcCsFcl40AHAACwMtB3KQNABwKwVyqjQAcAAMcsA0AHAo
>> "%~1" echo PAAAChMHEgdyzDQAcChFAAAKKHEAAAooCAAACg0GcuIKAHAoUgAABgMoVAAABhME
>> "%~1" echo c18AAAoTBREFcuw0AHAHKFMAAAZy/zUAcChAAAAKb2AAAAomEQVyETYAcG9gAAAK
>> "%~1" echo JhEFG40PAAABEwgRCBZyITYAcKIRCBcDLQdy1kMAcCsFcu5DAHAAohEIGHICRABw
>> "%~1" echo ohEIGQMtB3LWQwBwKwVy7kMAcACiEQgachJEAHCiEQgoFgAACm9gAAAKJhEFchtf
>> "%~1" echo AHBvYAAACiYRBXJHXwBwb2AAAAomEQVy4mAAcG9gAAAKJhEFci5hAHBvYAAACiYR
>> "%~1" echo BR8LjQ8AAAETCBEIFnLxYgBwohEIFwkoUwAABqIRCBhyb2MAcKIRCBkGcjwxAHAo
>> "%~1" echo UgAABihTAAAGohEIGnLZYwBwohEIGwgoUwAABqIRCBxyZmQAcKIRCB0GckYKAHAo
>> "%~1" echo UgAABihTAAAGohEIHnLrZABwohEIHwkGckYKAHAoUgAABihVAAAGKFMAAAaiEQgf
>> "%~1" echo CnLxZABwohEIKBYAAApvYAAACiYRBR8RjQ8AAAETCBEIFnIpZQBwohEIFwZy8AoA
>> "%~1" echo cChSAAAGKFMAAAaiEQgYcuplAHCiEQgZBnLuCwBwKFIAAAYoUwAABqIRCBpy/h4A
>> "%~1" echo cKIRCBsGckwxAHAoUgAABihTAAAGohEIHHL+HgBwohEIHQZysgoAcChSAAAGKFMA
>> "%~1" echo AAaiEQgech5mAHCiEQgfCREEKFMAAAaiEQgfCnKGZgBwohEIHwsGch4LAHAoUgAA
>> "%~1" echo BihTAAAGohEIHwxyvGYAcKIRCB8NBnJgCwBwKFIAAAYoUwAABqIRCB8OcoZmAHCi
>> "%~1" echo EQgfDwZyDA0AcChSAAAGKFMAAAaiEQgfEHLMZgBwohEIKBYAAApvYAAACiYRBRuN
>> "%~1" echo DwAAARMIEQgWcgBnAHCiEQgXAy0Hco1nAHArBXKZZwBwAChTAAAGohEIGHLqZQBw
>> "%~1" echo ohEIGQMtB3KlZwBwKwVy2WcAcAAoUwAABqIRCBpyV2gAcKIRCCgWAAAKb2AAAAom
>> "%~1" echo EQUfC40PAAABEwgRCBZyrmkAcKIRCBcGcnoQAHAoUgAABihTAAAGohEIGHL+HgBw
>> "%~1" echo ohEIGQZypBAAcChSAAAGKFMAAAaiEQgacj1qAHCiEQgbBnIMLQBwKFIAAAYoUwAA
>> "%~1" echo BqIRCBxyo2oAcKIRCB0Gcq4nAHAoUgAABihTAAAGohEIHnIJawBwohEIHwkGcvwx
>> "%~1" echo AHAoUgAABihTAAAGohEIHwpyb2sAcKIRCCgWAAAKb2AAAAomEQVymWsAcAYDHwqN
>> "%~1" echo DwAAARMIEQgWcqNrAHCiEQgXcuVrAHCiEQgYcilsAHCiEQgZcnlsAHCiEQgacq1s
>> "%~1" echo AHCiEQgbcuFsAHCiEQgcchttAHCiEQgdcldtAHCiEQgecottAHCiEQgfCXK1bQBw
>> "%~1" echo ohEIKCsAAAYAEQVy620AcAYDHwmNDwAAARMIEQgWcvdtAHCiEQgXciduAHCiEQgY
>> "%~1" echo ckduAHCiEQgZcoFuAHCiEQgacsFuAHCiEQgbcvNuAHCiEQgccj1vAHCiEQgdcnNv
>> "%~1" echo AHCiEQgecrNvAHCiEQgoKwAABgARBXLhbwBwBgMfEY0PAAABEwgRCBZyA3AAcKIR
>> "%~1" echo CBdyPXAAcKIRCBhyc3AAcKIRCBlys3AAcKIRCBpy9XAAcKIRCBtyO3EAcKIRCBxy
>> "%~1" echo eXEAcKIRCB1yt3EAcKIRCB5yAXIAcKIRCB8JcktyAHCiEQgfCnKRcgBwohEIHwty
>> "%~1" echo uXIAcKIRCB8Mcv1yAHCiEQgfDXJLcwBwohEIHw5ysXMAcKIRCB8PctNzAHCiEQgf
>> "%~1" echo EHIDdABwohEIKCsAAAYAEQVyL3QAcAYDHwqNDwAAARMIEQgWcmN0AHCiEQgXcsN0
>> "%~1" echo AHCiEQgYch91AHCiEQgZcol1AHCiEQgacu91AHCiEQgbclF2AHCiEQgccr92AHCi
>> "%~1" echo EQgdch13AHCiEQgecoN3AHCiEQgfCXL5dwBwohEIKCsAAAYAEQVycXgAcG9gAAAK
>> "%~1" echo JhEFcvB5AHAGAxqNDwAAARMIEQgWcv55AHCiEQgXcjp6AHCiEQgYcoR6AHCiEQgZ
>> "%~1" echo cvh6AHCiEQgoKwAABgARBQIDKCwAAAYAEQUdjQ8AAAETCBEIFnI2ewBwohEIFwZy
>> "%~1" echo cC4AcChSAAAGKFMAAAaiEQgYchd9AHCiEQgZBnKwLgBwKFIAAAYoUwAABqIRCBpy
>> "%~1" echo Z30AcKIRCBsDLQdys30AcCsFcsN9AHAAKFMAAAaiEQgcctl9AHCiEQgoFgAACm9g
>> "%~1" echo AAAKJhEFcg1+AHBvYAAACiYRBW9hAAAKEwYrABEGKgATMAQACgEAACQAABEAAnJF
>> "%~1" echo fgBwAyhTAAAGcoF+AHAoQAAACm9gAAAKJgAOBBMGFhMHOMIAAAARBhEHmgoABheN
>> "%~1" echo IAAAARMIEQgWH3ydEQgZb2UAAAoLBxaaDAeOaRcwAwgrAwcXmgANB45pGDAHckZ/
>> "%~1" echo AHArAwcYmgATBAQIKFIAAAYTBQUW/gETCREJLQoRBRcoVAAABhMFAh2NDwAAARMK
>> "%~1" echo EQoWck5/AHCiEQoXCShTAAAGohEKGHJgfwBwohEKGREFKFMAAAaiEQoacmB/AHCi
>> "%~1" echo EQobEQQoUwAABqIRChxydH8AcKIRCigWAAAKb2AAAAomABEHF1gTBxEHEQaOaf4E
>> "%~1" echo EwkRCTot////AnKKfwBwb2AAAAomKgAAGzAFAGUBAAAlAAARAAJywH8AcG9gAAAK
>> "%~1" echo JgADexoAAARvbgAACgw4GQEAABICKG8AAAoKAAQsFgZ7DwAABHIkgABwG28nAAAK
>> "%~1" echo Fv4EKwEXAA0JLQU47AAAAAZvcAAABgsEFv4BDQktCAcDKFcAAAYLB29MAAAKIGDq
>> "%~1" echo AAD+Ahb+AQ0JLRcHFiBg6gAAb2kAAApyMoAAcCgIAAAKCwIfCo0PAAABEwQRBBZy
>> "%~1" echo ZIAAcKIRBBcGew8AAAQoUwAABqIRBBhyioAAcKIRBBkGfBUAAAQoRQAACihGAAAK
>> "%~1" echo KFMAAAaiEQQacpKAAHCiEQQbBnwTAAAEKEUAAAooSAAACihTAAAGohEEHAZ7FAAA
>> "%~1" echo BC0HcvUFAHArBXKogABwAKIRBB1yvoAAcKIRBB4HKFMAAAaiEQQfCXLegABwohEE
>> "%~1" echo KBYAAApvYAAACiYAEgIocAAACg0JOtn+///eDxIC/hYFAAAbbyQAAAoA3AACcgCB
>> "%~1" echo AHBvYAAACiYqAAAAQRwAAAIAAAAaAAAALgEAAEgBAAAPAAAAAAAAABMwAwDbAAAA
>> "%~1" echo JgAAEQACIMQJAAByFoEAcCgVAAAGCgZynhEAcCglAAAKLBAGclCBAHAoJQAAChb+
>> "%~1" echo ASsBFwATBxEHLQgGEwY4mAAAAAACIMQJAAByYIEAcCgVAAAGKFoAAAYTCBYTCStk
>> "%~1" echo EQgRCZoLAAdvXQAACgwIcpaBAHBvcgAACg0JFv4EEwcRBy05AAgJG1hvTQAACm9d
>> "%~1" echo AAAKEwQRBB8vb1EAAAoTBREFFv4CFv4BEwcRBy0OEQQWEQVvaQAAChMG3h8AABEJ
>> "%~1" echo F1gTCREJEQiOaf4EEwcRBy2Ocp4RAHATBisAABEGKgATMAMAGAAAABIAABEAAgME
>> "%~1" echo KC8AAAZvbgAABihZAAAGCisABioeAihzAAAKKh4CKHMAAAoqCzACACwAAAAAAAAA
>> "%~1" echo AAACex0AAAR7HAAABAJ7HgAABG90AAAKb3UAAAp9CwAABADeBSYAAN4AACoBEAAA
>> "%~1" echo AAABACQlAAUBAAABCzACACwAAAAAAAAAAAACex0AAAR7HAAABAJ7HgAABG92AAAK
>> "%~1" echo b3UAAAp9DAAABADeBSYAAN4AACoBEAAAAAABACQlAAUBAAABGzACADwBAAAnAAAR
>> "%~1" echo c3MAAAYTBQARBXNvAAAGfRwAAARzdAAABg0JEQV9HQAABABzdwAACgoGAm94AAAK
>> "%~1" echo AAYDKDAAAAZveQAACgAGFm96AAAKAAYXb3sAAAoABhdvfAAACgAGF299AAAKAAkG
>> "%~1" echo KH4AAAp9HgAABAn+BnUAAAZzfwAACnOAAAAKCwn+BnYAAAZzfwAACnOAAAAKDAdv
>> "%~1" echo gQAACgAIb4EAAAoACXseAAAEBG+CAAAKEwcRBy0vABEFexwAAAQXfQ4AAAQACXse
>> "%~1" echo AAAEb4MAAAoAAN4FJgAA3gAAEQV7HAAABBMG3lsRBXscAAAECXseAAAEb4QAAAp9
>> "%~1" echo DQAABAcg6AMAAG+FAAAKJggg6AMAAG+FAAAKJhEFexwAAAQTBt4hEwQAEQV7HAAA
>> "%~1" echo BBEEbwcAAAp9DAAABBEFexwAAAQTBt4AABEGKkE0AAAAAAAAvAAAABAAAADMAAAA
>> "%~1" echo BQAAAAEAAAEAAAAAFAAAAAMBAAAXAQAAIQAAAA4AAAETMAMASQAAACgAABEAc18A
>> "%~1" echo AAoKFgsrKQAHFv4CFv4BDQktCQYfIG9jAAAKJgYCB5ooMQAABm9iAAAKJgAHF1gL
>> "%~1" echo BwKOaf4EDQktzQZvYQAACgwrAAgqAAAAIAAJACIAJgB8ADwAPgBeABMwBABdAAAA
>> "%~1" echo FgAAEQACFP4BFv4BCwctCHKigQBwCitHAh6NIAAAASXQHwAABCiGAAAKb4cAAAoW
>> "%~1" echo /gQW/gELBy0EAgorInKogQBwAnKogQBwcqyBAHBvZgAACnKogQBwKEAAAAoKKwAG
>> "%~1" echo KgAAABMwAwBOAAAAFgAAEQACKFkAAAYQAAMoWQAABhABAnKeEQBwKAsAAAoW/gEL
>> "%~1" echo By0EAworJQNynhEAcCgLAAAKFv4BCwctBAIKKw8CcrMBAHADKEAAAAoKKwAGKgAA
>> "%~1" echo EzACAGsAAAAWAAARAAJysoEAcCgLAAAKFv4BCwctCHK2gQBwCitOAnK+gQBwKAsA
>> "%~1" echo AAotEAJywoEAcCgLAAAKFv4BKwEWAAsHLQhyxoEAcAorIwJyzoEAcCgLAAAKFv4B
>> "%~1" echo CwctCHLSgQBwCisJAihZAAAGCisABioAEzACAI4AAAAWAAARAAJysoEAcCgLAAAK
>> "%~1" echo Fv4BCwctCHLagQBwCitxAnK+gQBwKAsAAAoW/gELBy0IcuCBAHAKK1cCcsKBAHAo
>> "%~1" echo CwAAChb+AQsHLQhy5oEAcAorPQJyzoEAcCgLAAAKFv4BCwctCHLsgQBwCisjAnLy
>> "%~1" echo gQBwKAsAAAoW/gELBy0IcvaBAHAKKwkCKFkAAAYKKwAGKgAAEzACAHcAAAAWAAAR
>> "%~1" echo AAJy/IEAcCg4AAAGcswKAHBviAAAChb+AQsHLQhyFIIAcAorUAJyGoIAcCg4AAAG
>> "%~1" echo cswKAHBviAAAChb+AQsHLQhyNIIAcAorLAJyPIIAcCg4AAAGcswKAHBviAAAChb+
>> "%~1" echo AQsHLQhyYIIAcAorCHJmggBwCisABioAEzADAGsAAAApAAARAAACKFoAAAYNFhME
>> "%~1" echo K0UJEQSaCgAGb10AAAoLBwNySCQAcCgIAAAKG28zAAAKFv4BEwURBS0WBwNvTAAA
>> "%~1" echo ChdYb00AAAooWQAABgzeHAARBBdYEwQRBAmOaf4EEwURBS2ucp4RAHAMKwAACCoA
>> "%~1" echo EzADAJMAAAAqAAARAAACKFoAAAYTBhYTBytpEQYRB5oKAAZvXQAACgsHA3JuggBw
>> "%~1" echo KAgAAAoabycAAAoMCBb+BBMIEQgtNwAHCANvTAAAClgXWG9NAAAKDQkfLG9RAAAK
>> "%~1" echo EwQRBBYvAwkrCQkWEQRvaQAACgAoWQAABhMF3h4AEQcXWBMHEQcRBo5p/gQTCBEI
>> "%~1" echo LYlynhEAcBMFKwAAEQUqABMwAwBUAAAAKQAAEQAAAihaAAAGDRYTBCsuCREEmgoA
>> "%~1" echo Bm9dAAAKCwcDG28nAAAKFv4EEwURBS0JByhZAAAGDN4cABEEF1gTBBEECY5p/gQT
>> "%~1" echo BREFLcVynhEAcAwrAAAIKhMwAwBlAAAAKwAAEQADckgkAHAoCAAACgoCBhtvJwAA
>> "%~1" echo CgsHFv4EFv4BEwURBS0Jcp4RAHATBCs2AgcGb0wAAApYb00AAApvXQAACgwIHyxv
>> "%~1" echo UQAACg0JFi8DCCsICBYJb2kAAAoAKFkAAAYTBCsAEQQqAAAAEzADAGYAAAAsAAAR
>> "%~1" echo AAACKFoAAAYTBBYTBSs+EQQRBZoKAAZvXQAACgsHAxtvJwAACgwIFv4EEwYRBi0W
>> "%~1" echo BwgDb0wAAApYb00AAAooWQAABg3eHQARBRdYEwURBREEjmn+BBMGEQYttHKeEQBw
>> "%~1" echo DSsAAAkqAAATMAQAxgAAAC0AABEAAAIoWgAABhMFFhMGOJYAAAARBREGmgoABm9d
>> "%~1" echo AAAKCwcDG28zAAAKEwcRBy0CK3IHGI0gAAABEwgRCBYfIJ0RCBcfCZ0RCBdvXgAA
>> "%~1" echo CgwIjmkYMhkIF5og/wEAAChFAAAKEgMoZwAAChb+ASsBFwATBxEHLSwJIwAAAAAA
>> "%~1" echo ADBBWxMJEglyyiQAcChFAAAKKGgAAApycoIAcCgIAAAKEwTeIQARBhdYEwYRBhEF
>> "%~1" echo jmn+BBMHEQc6Wf///3KeEQBwEwQrAAARBCoAABMwBAC/AAAALgAAEQAAAihaAAAG
>> "%~1" echo EwQWEwU4kQAAABEEEQWaCgAGb10AAAoLcnqCAHADcn6CAHAoQAAACgwHCBpvMwAA
>> "%~1" echo Chb+ARMGEQYtKQcIb0wAAApvTQAACheNIAAAARMHEQcWH12dEQdviQAACihZAAAG
>> "%~1" echo Dd5RBwNyboIAcCgIAAAKGm8zAAAKFv4BEwYRBi0WBwNvTAAAChdYb00AAAooWQAA
>> "%~1" echo Bg3eIAARBRdYEwURBREEjmn+BBMGEQY6Xv///3KeEQBwDSsAAAkqABMwAgBSAAAA
>> "%~1" echo KQAAEQAAAihaAAAGDRYTBCssCREEmgoABihZAAAGCwdynhEAcCglAAAKFv4BEwUR
>> "%~1" echo BS0EBwzeHAARBBdYEwQRBAmOaf4EEwURBS3Hcp4RAHAMKwAACCoAABMwBABnAAAA
>> "%~1" echo LwAAEQACJS0GJnL1BQBwAxtvJwAACgoGFv4EFv4BDQktCHKeEQBwDCs/BgNvTAAA
>> "%~1" echo ClgKAgQGG2+KAAAKCwcW/gQW/gENCS0PAgZvTQAACihZAAAGDCsSAgYHBllvaQAA
>> "%~1" echo CihZAAAGDCsACCoAEzADAEwAAAAwAAARAAIlLQYmcvUFAHADFyiLAAAKCgZvjAAA
>> "%~1" echo CiwOBm+NAAAKb44AAAoXMAdynhEAcCsWBm+NAAAKF2+PAAAKb5AAAAooWQAABgAL
>> "%~1" echo KwAHKhMwAgANAAAAEgAAEQACAyg/AAAGCisABioAAAATMAIARQAAABwAABEAAgMo
>> "%~1" echo QgAABgoGcp4RAHAoJQAAChb+AQ0JLQQGDCskAihDAAAGCwcCKJEAAAoNCS0KBwMo
>> "%~1" echo QgAABgwrCHKeEQBwDCsACCoAAAATMAQAsAAAADEAABEAAiUtBiZy9QUAcHKsgQBw
>> "%~1" echo AyiSAAAKcoiCAHAoQAAAChcoiwAACgoGb4wAAAoW/gEMCC0ZBm+NAAAKF2+PAAAK
>> "%~1" echo b5AAAAooWQAABgsrYQIlLQYmcvUFAHByrIEAcAMokgAACnK0ggBwKEAAAAoXKIsA
>> "%~1" echo AAoKBm+MAAAKLQdynhEAcCsoBm+NAAAKF2+PAAAKb5AAAAoXjSAAAAENCRYfIp0J
>> "%~1" echo b1YAAAooWQAABgALKwAHKhMwAwBJAAAAMgAAEQACJS0GJnL1BQBwChYLKxUGcqyB
>> "%~1" echo AHByqIEAcG9mAAAKCgcXWAsHGC8UBnKsgQBwGm8nAAAKFv4EFv4BKwEWAA0JLc0G
>> "%~1" echo DCsACCoAAAATMAQA/AAAADMAABEAAAIoWgAABhMEFhMFOM4AAAARBBEFmgoABm9d
>> "%~1" echo AAAKCwdvTAAACiwRB3LoJwBwG28zAAAKFv4BKwEWABMGEQYtBTiUAAAABxiNIAAA
>> "%~1" echo ARMHEQcWHyCdEQcXHwmdEQcXb14AAAoMCI5pHDIuCAiOaRdZmnLcggBwKAsAAAot
>> "%~1" echo FwgIjmkXWZpy6IIAcBtvJwAAChb+BCsBFgArARcAEwYRBi05G40PAAABEwgRCBYI
>> "%~1" echo GJqiEQgXcv4eAHCiEQgYCBeaohEIGXL6ggBwohEIGggamqIRCCgWAAAKDd4gABEF
>> "%~1" echo F1gTBREFEQSOaf4EEwYRBjoh////cp4RAHANKwAACSoTMAQAWgAAABwAABEAAnIs
>> "%~1" echo KABwKDsAAAYKAnJAKABwKDsAAAYLBnKeEQBwKAsAAAosEAdynhEAcCgLAAAKFv4B
>> "%~1" echo KwEXAA0JLQhynhEAcAwrFHJcKABwB3JkKABwBig4AAAKDCsACCoAABMwAwBWAAAA
>> "%~1" echo NAAAEQACcgiDAHAoUAAABgoCchyDAHAoPwAABgsGLRAHcp4RAHAoCwAAChb+ASsB
>> "%~1" echo FwANCS0Icp4RAHAMKxoSAChFAAAKKEgAAApyXIMAcAcoQAAACgwrAAgqAAATMAQA
>> "%~1" echo HwEAADUAABEAAnJWKQBwKDgAAAYKBnJ6KQBwKD8AAAYLBnKqKQBwKD8AAAYMBnLi
>> "%~1" echo KQBwKD8AAAYNBnJwgwBwKFEAAAYTBxIHKEUAAAooSAAAChMEcx0AAAoTBQdynhEA
>> "%~1" echo cCglAAAKFv4BEwgRCC0YEQUHcrMBAHBy9QUAcG9mAAAKbyYAAAoACHKeEQBwKCUA
>> "%~1" echo AAoW/gETCBEILRMRBQhyPCoAcCgIAAAKbyYAAAoACXKeEQBwKCUAAAoW/gETCBEI
>> "%~1" echo LRMRBXJCKgBwCSgIAAAKbyYAAAoAEQRykoMAcCglAAAKFv4BEwgRCC0UEQURBHKW
>> "%~1" echo gwBwKAgAAApvJgAACgARBW8eAAAKLBNy/h4AcBEFb0kAAAooSgAACisFcp4RAHAA
>> "%~1" echo EwYrABEGKgATMAQAyQAAADYAABEAAnKgKgBwKDYAAAYKAnKkgwBwKDYAAAYLAnK+
>> "%~1" echo KgBwKEAAAAYMcx0AAAoNBnKeEQBwKCUAAAoW/gETBREFLRIJckArAHAGKAgAAApv
>> "%~1" echo JgAACgAHcp4RAHAoJQAAChb+ARMFEQUtEglyuIMAcAcoCAAACm8mAAAKAAhynhEA
>> "%~1" echo cCglAAAKFv4BEwURBS0XCXLCgwBwCHJoKwBwKEAAAApvJgAACgAJbx4AAAosEnL+
>> "%~1" echo HgBwCW9JAAAKKEoAAAorBXKeEQBwABMEKwARBCoAAAATMAMAugAAADYAABEAAnLU
>> "%~1" echo gwBwKD8AAAYKAnL6gwBwKD8AAAYLAnIihABwKD8AAAYMcx0AAAoNBnKeEQBwKCUA
>> "%~1" echo AAoW/gETBREFLRIJclyEAHAGKAgAAApvJgAACgAHcp4RAHAoJQAAChb+ARMFEQUt
>> "%~1" echo EglycoQAcAcoCAAACm8mAAAKAAhynhEAcCglAAAKFv4BEwURBS0ICQhvJgAACgAJ
>> "%~1" echo bx4AAAosEnL+HgBwCW9JAAAKKEoAAAorBXKeEQBwABMEKwARBCoAABMwAwAzAQAA
>> "%~1" echo NwAAEQACcoqEAHAoPwAABgoCcsiEAHAoPwAABgsCcvSEAHAoPwAABgwCciKFAHAo
>> "%~1" echo PwAABg0DckiFAHAoPwAABhMEcx0AAAoTBREEcp4RAHAoJQAAChb+ARMHEQctFBEF
>> "%~1" echo cpiFAHARBCgIAAAKbyYAAAoABnKeEQBwKCUAAAoW/gETBxEHLRMRBXKghQBwBigI
>> "%~1" echo AAAKbyYAAAoAB3KeEQBwKCUAAAoW/gETBxEHLRMRBQdytIUAcCgIAAAKbyYAAAoA
>> "%~1" echo CHKeEQBwKCUAAAoW/gETBxEHLRMRBQhyvIUAcCgIAAAKbyYAAAoACXKeEQBwKCUA
>> "%~1" echo AAoW/gETBxEHLRMRBXLGhQBwCSgIAAAKbyYAAAoAEQVvHgAACiwTcv4eAHARBW9J
>> "%~1" echo AAAKKEoAAAorBXKeEQBwABMGKwARBioAEzAEAGAAAAAcAAARAAJy0oUAcCg/AAAG
>> "%~1" echo CgJy+oUAcCg/AAAGCwZynhEAcCgLAAAKLBAHcp4RAHAoCwAAChb+ASsBFwANCS0O
>> "%~1" echo AnIghgBwKDgAAAYMKxRyQoYAcAZy/h4AcAcoOAAACgwrAAgqEzAEAPEAAAA4AAAR
>> "%~1" echo AAJyVIYAcChRAAAGCgMoQwAABgsHcrSGAHAoUQAABgwHcuqGAHAoUQAABg0HciKH
>> "%~1" echo AHAoUQAABhMEcx0AAAoTBQYW/gIW/gETBxEHLRgRBQaMFgAAAXJahwBwKDUAAApv
>> "%~1" echo JgAACgAICVgRBFgW/gIW/gETBxEHLVERBRyNAQAAARMIEQgWcnqHAHCiEQgXCIwW
>> "%~1" echo AAABohEIGHKghwBwohEIGQmMFgAAAaIRCBpytocAcKIRCBsRBIwWAAABohEIKBQA
>> "%~1" echo AApvJgAACgARBW8eAAAKLBNy/h4AcBEFb0kAAAooSgAACisFcp4RAHAAEwYrABEG
>> "%~1" echo KgAAABMwAwAfAQAANwAAEQACcuwDAHAoQQAABgoCchAEAHAoQQAABgsCcjIEAHAo
>> "%~1" echo QQAABgwCcm4EAHAoQQAABg0Cco4EAHAoQQAABhMEcx0AAAoTBQZynhEAcCglAAAK
>> "%~1" echo Fv4BEwcRBy0JEQUGbyYAAAoAB3KeEQBwKCUAAAoW/gETBxEHLQkRBQdvJgAACgAI
>> "%~1" echo cp4RAHAoJQAAChb+ARMHEQctExEFcrYrAHAIKAgAAApvJgAACgAJcp4RAHAoJQAA
>> "%~1" echo Chb+ARMHEQctExEFcsgrAHAJKAgAAApvJgAACgARBHKeEQBwKCUAAAoW/gETBxEH
>> "%~1" echo LRQRBXLSKwBwEQQoCAAACm8mAAAKABEFbx4AAAosE3L+HgBwEQVvSQAACihKAAAK
>> "%~1" echo KwVynhEAcAATBisAEQYqABMwAwBaAAAAOQAAEQACcsyHAHAbbycAAAoW/gQW/gEM
>> "%~1" echo CC0Icp4RAHALKzkCcv4oAHAoOgAABgpymigAcAZynhEAcCgLAAAKLQ1y/h4AcAYo
>> "%~1" echo CAAACisFcvUFAHAAKAgAAAoLKwAHKgAAEzADAEwAAAA6AAARABYKAAIoWgAABg0W
>> "%~1" echo EwQrKQkRBJoLB29dAAAKcg6IAHAbbzMAAAoW/gETBREFLQQGF1gKEQQXWBMEEQQJ
>> "%~1" echo jmn+BBMFEQUtygYMKwAIKhMwAwBIAAAAOgAAEQAWCgACKFoAAAYNFhMEKyUJEQSa
>> "%~1" echo CwdvXQAACgMbbzMAAAoW/gETBREFLQQGF1gKEQQXWBMEEQQJjmn+BBMFEQUtzgYM
>> "%~1" echo KwAIKhMwAwAcAAAAOwAAEQACJS0GJnL1BQBwAxcokwAACm+UAAAKCisABioTMAIA
>> "%~1" echo IwAAABIAABEAAgNvOwAACi0Hcp4RAHArDAIDbzcAAAooWQAABgAKKwAGKgATMAEA
>> "%~1" echo EQAAABIAABEAAihZAAAGKJUAAAoKKwAGKgAAABMwAQAYAAAAEgAAEQADLQgCKFkA
>> "%~1" echo AAYrBgIoVgAABgAKKwAGKhMwAwCvAAAAOQAAEQACKFkAAAYKBnKeEQBwKAsAAAoW
>> "%~1" echo /gEMCC0HBgs4jAAAAAZyIIgAcBtvJwAAChb+BAwILQhyUIgAcAsrcQZyiIgAcBtv
>> "%~1" echo JwAAChYyEQZymIgAcBtvJwAAChb+BCsBFwAMCC0IcraIAHALK0MGcuyIAHAbb1IA
>> "%~1" echo AAotEQZy/IgAcBtvUgAAChb+ASsBFgAMCC0IcgSJAHALKxYGb0wAAAofNP4CDAgt
>> "%~1" echo BAYLKwQGCysAByoAEzACADoAAAA5AAARAAJvkAAACgoGciKJAHAolgAACiwQBnIu
>> "%~1" echo iQBwKJYAAAoW/gErARcADAgtCQYoWAAABgsrBAYLKwAHKgAAEzAEADoAAAATAAAR
>> "%~1" echo AAIUKFcAAAYKBnI6iQBwfgoAAAQtExT+BmwAAAZzlwAACoAKAAAEKwB+CgAABCiY
>> "%~1" echo AAAKCgYLKwAHKgAAEzAEAO8AAAA5AAARAAIoWQAABgoDLCIDexcAAAQoLQAACi0V
>> "%~1" echo A3sXAAAEcp4RAHAoJQAAChb+ASsBFwAMCC0YBgN7FwAABAN7FwAABChYAAAGb2YA
>> "%~1" echo AAoKBnJiiQBwcrCJAHAomQAACgoGctSJAHByEooAcCiZAAAKCgZyKooAcHJuigBw
>> "%~1" echo KJkAAAoKBnKAigBwcuSKAHAomQAACgoGcviKAHBySosAcBcomgAACgoGcmaLAHBy
>> "%~1" echo tIsAcBcomgAACgoGcvqLAHByJowAcBcomgAACgoGclSMAHByiowAcBcomgAACgoG
>> "%~1" echo cr6MAHBy7IwAcBcomgAACgoGCysAByoAEzAFAEoAAAAWAAARAAIoLQAACi0OAm9M
>> "%~1" echo AAAKHP4EFv4BKwEWAAsHLQhyGI0AcAorIwIWGW9pAAAKciqNAHACAm9MAAAKGVlv
>> "%~1" echo TQAACihAAAAKCisABioAABMwAwBBAAAAFgAAEQACFP4BFv4BCwctCHKeEQBwCisr
>> "%~1" echo AnIyjQBwcvUFAHBvZgAACm9dAAAKEAACb0wAAAosAwIrBXKeEQBwAAorAAYqAAAA
>> "%~1" echo EzAEADEAAAA8AAARAAIlLQYmcvUFAHByMo0AcHL1BQBwb2YAAAoXjSAAAAELBxYf
>> "%~1" echo Cp0Hby4AAAoKKwAGKgAAABMwAgAvAAAAPQAAEQACcsoOAHAoCwAACi0aAnKuDwBw
>> "%~1" echo KAsAAAotDQJy/A8AcCgLAAAKKwEXAAorAAYqABMwAgBhAAAAPgAAEQACKC0AAAoW
>> "%~1" echo /gEMCC0EFgsrTAACDRYTBCsyCREEb5sAAAoKBiicAAAKLREGH18uDAYfLi4HBh8t
>> "%~1" echo /gErARcADAgtBBYL3hgRBBdYEwQRBAlvTAAACv4EDAgtwBcLKwAAByoAAAATMAIA
>> "%~1" echo igAAAD0AABEAAnKGEgBwKAsAAAotdQJyXhIAcCgLAAAKLWgCchQVAHAoCwAACi1b
>> "%~1" echo AnJmFQBwKAsAAAotTgJydBQAcCgLAAAKLUECcq4XAHAoCwAACi00AnIOGQBwKAsA
>> "%~1" echo AAotJwJyjBMAcCgLAAAKLRoCcuAbAHAoCwAACi0NAnKQHABwKAsAAAorARcACisA
>> "%~1" echo BioAABMwAgCqAAAAFgAAEQACJS0GJnL1BQBwb50AAAoKBnLYDgBwKAsAAAo6ggAA
>> "%~1" echo AAZyAA8AcCgLAAAKLXUGcjaNAHAoCwAACi1oBnJwjQBwKAsAAAotWwZylo0AcCgL
>> "%~1" echo AAAKLU4Gcr6NAHAoCwAACi1BBnLOjQBwKAsAAAotNAZy8I0AcCgLAAAKLScGcgaO
>> "%~1" echo AHAoCwAACi0aBnIqjgBwKAsAAAotDQZyWo4AcCgLAAAKKwEXAAsrAAcqAAATMAQA
>> "%~1" echo LgAAABIAABEAcpSOAHACJS0GJnL1BQBwcpSOAHBymI4AcG9mAAAKcpSOAHAoQAAA
>> "%~1" echo CgorAAYqAAATMAMAHgAAAAkAABEAc54AAAoKBnIoHQBwcswKAHBvNgAACgAGCysA
>> "%~1" echo ByoAABMwAwArAAAACQAAEQAoYAAABgoGcigdAHBywAoAcG82AAAKAAZyLh0AcAJv
>> "%~1" echo NgAACgAGCysAByoAEzACABsAAAA9AAARAAJyoo4AcChjAAAGfgIAAAQoCwAACgor
>> "%~1" echo AAYqABMwBAC0AAAAPwAAEQACcq6OAHBvnwAAChb+ARMFEQUtCQIXb00AAAoQAAAC
>> "%~1" echo F40gAAABEwYRBhYfJp0RBm8uAAAKEwcWEwgrXREHEQiaCgAGHz1vUQAACgsHFi8D
>> "%~1" echo BisIBhYHb2kAAAoADAcWLwdy9QUAcCsJBgcXWG9NAAAKAA0IKGQAAAYDKAsAAAoW
>> "%~1" echo /gETBREFLQoJKGQAAAYTBN4eABEIF1gTCBEIEQeOaf4EEwURBS2VcvUFAHATBCsA
>> "%~1" echo ABEEKhMwAwAkAAAAEgAAEQACJS0GJnL1BQBwcrKOAHByswEAcG9mAAAKKE4AAAoK
>> "%~1" echo KwAGKnoAAnK2jgBwKAkAAAoDKGcAAAZvNAAACihmAAAGACoAEzAEAFsAAABAAAAR
>> "%~1" echo ABuNAQAAAQwIFnL2jgBwoggXA6IIGHI2jwBwoggZBI5pjBYAAAGiCBpyXI8AcKII
>> "%~1" echo KBQAAAoKKKAAAAoGbzQAAAoLAgcWB45pb6EAAAoAAgQWBI5pb6EAAAoAKgAbMAIA
>> "%~1" echo rgAAAEEAABEAcr6PAHBzogAACgoXCwACb6MAAAoTBCthEgQopAAACgwABxMFEQUt
>> "%~1" echo DAZyOCoAcG9iAAAKJhYLBnKogQBwb2IAAAoSAiilAAAKKGgAAAZvYgAACnLCjwBw
>> "%~1" echo b2IAAAoSAiimAAAKKGgAAAZvYgAACnKogQBwb2IAAAomABIEKKcAAAoTBREFLZLe
>> "%~1" echo DxIE/hYGAAAbbyQAAAoA3AAGcsqPAHBvYgAACm9hAAAKDSsACSoAAAEQAAACABcA
>> "%~1" echo cokADwAAAAATMAMAFAEAAEIAABEAc18AAAoKAAIlLQYmcvUFAHANFhMEONsAAAAJ
>> "%~1" echo EQRvmwAACgsABx9c/gEW/gETBREFLREGcs6PAHBvYgAACiY4qwAAAAcfIv4BFv4B
>> "%~1" echo EwURBS0RBnKsgQBwb2IAAAomOIwAAAAHHwr+ARb+ARMFEQUtDgZy1I8AcG9iAAAK
>> "%~1" echo JitwBx8N/gEW/gETBREFLQ4GctqPAHBvYgAACiYrVAcfCf4BFv4BEwURBS0OBnLg
>> "%~1" echo jwBwb2IAAAomKzgHHyD+BBb+ARMFEQUtIgZy5o8AcG9iAAAKBxMGEgZy7I8AcCio
>> "%~1" echo AAAKb2IAAAomKwgGB29jAAAKJgARBBdYEwQRBAlvTAAACv4EEwURBToS////Bm9h
>> "%~1" echo AAAKDCsACCoTMAMAKwAAABMAABEAcvKPAHAKKAkAAAoGKKkAAApvqgAACnLPHwJw
>> "%~1" echo fgIAAARvZgAACgsrAAcqABMwAgBfAAAAQwAAEXLsiABwgAEAAAQoqwAACgoSAHLj
>> "%~1" echo HwJwKKwAAAqAAgAABCA9IgAAgAMAAARy9QUAcIAEAAAEcvUFAHCABQAABHL1BQBw
>> "%~1" echo gAYAAARzcwAACoAHAAAEFnOtAAAKgAgAAAQqHgIocwAACioAEzACACMAAAASAAAR
>> "%~1" echo AAJ7CwAABG9MAAAKFjAIAnsMAAAEKwYCewsAAAQACisABiqyAnL1BQBwfQsAAAQC
>> "%~1" echo cvUFAHB9DAAABAIVfQ0AAAQCFn0OAAAEAihzAAAKACoTMAIAIwAAABIAABEAAnsR
>> "%~1" echo AAAEb0wAAAoWMAgCexIAAAQrBgJ7EQAABAAKKwAGKgADMAIASgAAAAAAAAACcvUF
>> "%~1" echo AHB9DwAABAJy9QUAcH0QAAAEAnL1BQBwfREAAAQCcvUFAHB9EgAABAIVfRMAAAQC
>> "%~1" echo Fn0UAAAEAhZqfRUAAAQCKHMAAAoAKgAAAzACAEoAAAAAAAAAAnL1BQBwfRYAAAQC
>> "%~1" echo cvUFAHB9FwAABAJy9QUAcH0YAAAEAnOeAAAKfRkAAAQCc64AAAp9GgAABAJzHQAA
>> "%~1" echo Cn0bAAAEAihzAAAKACoAAEJTSkIBAAEAAAAAAAwAAAB2NC4wLjMwMzE5AAAAAAUA
>> "%~1" echo bAAAAEQTAAAjfgAAsBMAAMwQAAAjU3RyaW5ncwAAAAB8JAAA6B8CACNVUwBkRAIA
>> "%~1" echo EAAAACNHVUlEAAAAdEQCAJQHAAAjQmxvYgAAAAAAAAACAAABV5WiKQkCAAAA+iUz
>> "%~1" echo ABYAAAEAAABEAAAACQAAAB8AAAB2AAAArwAAAK4AAAANAAAAAQAAAEMAAAACAAAA
>> "%~1" echo AgAAAAIAAAAHAAAAAQAAAAEAAAACAAAABgAAAAAACgABAAAAAAAGAFUATgAGAJoA
>> "%~1" echo jgAGANYAuwAKAAYB8wAGABYBuwAGAFcBTQEGAOABjgAGADUGTgAGAK0GjgYGAKAH
>> "%~1" echo gAcGAMAHgAcGAPwH6wcGADAIgAcGAFEITgAGAGcITgAGAH4ITgAGAKUITgAGALYI
>> "%~1" echo TgAKAO8I5AgKAP8I8wAGABsJTgAGADIJTgAGAE8JTgAKAHoJZwkGAJIJ6wcPALkJ
>> "%~1" echo AAAGAN4JTQEGAPwJTgAKAE0K8wAGAGUKTQEGAHIKTQEGAJQKTgAKALAKTgAGAPUK
>> "%~1" echo 6wcGAA4LTgAGACgLTQEGADULTQEGAD8LTQEGAF0LTQEGAG8LTgAGALILnQsGANML
>> "%~1" echo TgAGANkLTgAGAIoM6wcGAK4MTgAGAOAMTgAGAOcMnQsKAP0MZwkKALsNZwkGAEMO
>> "%~1" echo 6wcGALIOTgAGAO0OgAcGAPwOTgAGAAIPTgAKAFcPOA8KAF0POA8KAGMPOA8KAHAP
>> "%~1" echo OA8KAIIPOA8KADQAOA8KAL4POA8KANYP5AgKAAAQOA8XALkJAAAGAHkQuwAGAJAQ
>> "%~1" echo TgAGALAQTgAGAL0QjgAAAAAAAQAAAAAAAQABAAAAEAAcAAAABQABAAEAAwAQACoA
>> "%~1" echo AAAFAAsAbgADABAANAAAAAUADwBwAAMAEAA8AAAABQAWAHIAAwEQAC0NAAAFABwA
>> "%~1" echo cwADARAARw0AAAUAHQB0AAAAAABtDgAABQAfAHcAEwEAALwOAADNACAAdwARAFwA
>> "%~1" echo CgARAGQACgARAGoADQARAG8ACgARAHcACgARAH4ACgAxAIYAEAAxAKMAEwARAAkI
>> "%~1" echo kAERAA8QtAYGAJgFCgAGAFQFCgAGAJ8FDQAGAKgFXAEGAL8FCgAGAMQFCgAGAJgF
>> "%~1" echo CgAGAFQFCgAGAJ8FDQAGAKgFXAEGAMwFZwEGANcFCgAGAN8FCgAGAOYFCgAGAPEF
>> "%~1" echo agEGAPgFcgEGAAEGegEGAEANTQUGAFoNUQUGAGoNVQUTAdkOlAW8IAAAAACRAK0A
>> "%~1" echo FwABAKgjAAAAAJEAsgAdAAIASCUAAAAAkQDdACEAAgCcJQAAAACRAOQALQAGACgm
>> "%~1" echo AAAAAJEAEAE6AAoA6CkAAAAAkQAjAUAACwB0LgAAAACRACoBSQALAJg2AAAAAJEA
>> "%~1" echo MQFAAA0A1DYAAAAAkQA2AUAADQBAOQAAAACRAEMBVAANAJg5AAAAAJEAXgFaAA8A
>> "%~1" echo yDoAAAAAkQBqAWEAEQA0OwAAAACRAHQBYQASAJg7AAAAAJEAgQFmABMA3DsAAAAA
>> "%~1" echo kQCPAWEAEwDcPAAAAACRAJcBYQAUAGg9AAAAAJEAmwFmABUAMD4AAAAAkQCnAWoA
>> "%~1" echo FQBUQQAAAACRALQBVAAXAIRBAAAAAJEAuQFyABkA0EEAAAAAkQDBAXkAHAAQQgAA
>> "%~1" echo AACRAMQBgAAfADBCAAAAAJEAxgF5ACEAcEIAAAAAkQDNAYAAJAAIQwAAAACRANMB
>> "%~1" echo YQAmAORDAAAAAJEA7gGHACcAXEQAAAAAkQD+AWEAKwDcRQAAAACRAAwCkAAsAGxG
>> "%~1" echo AAAAAJEAFwKVAC0AUEcAAAAAkQAjApUALwDkRwAAAACRAC0ClQAxAKhJAAAAAJEA
>> "%~1" echo QQKVADMAKEsAAAAAkQBPApUANQDQSwAAAACRAGIClQA3ACxNAAAAAJEAcgKVADkA
>> "%~1" echo 9E0AAAAAkQCCApUAOwBMTwAAAACRAJICoAA9AEBSAAAAAJEAogKnAD8AfFIAAAAA
>> "%~1" echo kQCyArEARACgUwAAAACRAL0CvABJABRUAAAAAJEAwQLEAEsAtFoAAAAAkQDUAsoA
>> "%~1" echo TACgYQAAAACRAOQC0QBOALhiAAAAAJEA9ALhAFMASGQAAAAAkQACA5AAVgAwZQAA
>> "%~1" echo AACRAAkD6gBXAPRlAAAAAJEADQPyAFoAcGcAAAAAkQAXA/sAXQDYZwAAAACRACAD
>> "%~1" echo kABeAERoAAAAAJEAKQNUAF8AoGgAAAAAkQA2A5AAYQAYaQAAAACRAEQDkABiALRp
>> "%~1" echo AAAAAJEAUgOQAGMAOGoAAAAAkQBeA1QAZACwagAAAACRAGkDVABmAFBrAAAAAJEA
>> "%~1" echo dQNUAGgAsGsAAAAAkQB+A1QAagAkbAAAAACRAIQDVABsAJhsAAAAAJEAlQNUAG4A
>> "%~1" echo bG0AAAAAkQCbA1QAcAA4bgAAAACRAKQDkAByAJhuAAAAAJEArgNyAHMADG8AAAAA
>> "%~1" echo kQC2A1QAdgBkbwAAAACRAMEDVAB4AIBvAAAAAJEAzANUAHoA1G8AAAAAkQDbA1QA
>> "%~1" echo fACQcAAAAACRAO0DkAB+AOhwAAAAAJEAAwSQAH8A8HEAAAAAkQASBJAAgABYcgAA
>> "%~1" echo AACRACAEkACBALxyAAAAAJEAKwSQAIIA6HMAAAAAkQA6BJAAgwDAdAAAAACRAEkE
>> "%~1" echo kACEAIh1AAAAAJEAVARUAIUAyHYAAAAAkQBgBJAAhwA0dwAAAACRAHEEVACIADR4
>> "%~1" echo AAAAAJEAfwSQAIoAYHkAAAAAkQCOBJAAiwDIeQAAAACRAKQEAQGMACB6AAAAAJEA
>> "%~1" echo tgQGAY0AdHoAAAAAkQDHBAYBjwCcegAAAACRANIEDAGRAMx6AAAAAJEA1ASQAJMA
>> "%~1" echo 7HoAAAAAkQDWBBcBlAAQewAAAACRAN4EkACWABR8AAAAAJEA7QSQAJcAXHwAAAAA
>> "%~1" echo kQD5BB0BmABYfQAAAACRAAAFkACaALB9AAAAAJEACwWQAJsAAH4AAAAAkQARBSQB
>> "%~1" echo nABAfgAAAACRABcFKgGdAHx+AAAAAJEAHwUqAZ4A7H4AAAAAkQAoBSoBnwCEfwAA
>> "%~1" echo AACRADgFKgGgADyAAAAAAJEARgWQAKEAeIAAAAAAkQBRBUAAogCkgAAAAACRAFQF
>> "%~1" echo LwGiANyAAAAAAJEAWgUqAaMABIEAAAAAkQBlBVQApADEgQAAAACRAGsFkACmAPSB
>> "%~1" echo AAAAAJEAbwU5AacAFIIAAAAAkQB5BUUBqQB8ggAAAACRAIQFTgGsAEiDAAAAAJEA
>> "%~1" echo iQWQAK0AaIQAAAAAkQCNBWYArgALhQAAAACGGJIFWAGuAFAgAAAAAJEA3geLAa4A
>> "%~1" echo zHsAAAAAkQDsD60GrwCghAAAAACRGKkQWwewABSFAAAAAIYIsQVfAbAAQ4UAAAAA
>> "%~1" echo hhiSBVgBsABwhQAAAACGCLEFXwGwAKCFAAAAAIYYkgVYAbAA+IUAAAAAhhiSBVgB
>> "%~1" echo sABUZQAAAACGGJIFWAGwAFxlAAAAAIYYkgVYAbAAZGUAAAAAhgBsDVgBsACsZQAA
>> "%~1" echo AACGAHwNWAGwAAAAAQAKBgAAAQAPBgAAAgAYBgAAAwAdBgAABAAmBgAAAQAPBgAA
>> "%~1" echo AgAYBgAAAwAmBgAABAAtBgAAAQBJBgAAAQBQBgAAAgBXBgAAAQBdBgAAAgAYBgAA
>> "%~1" echo AQBjBgAAAgBqBgAAAQBvBgAAAQBvBgAAAQB2BgAAAQB+BgIAAQCDBgIAAgC6BgAA
>> "%~1" echo AQBvBgAAAgAYBgAAAQBvBgAAAgC/BgAAAwDCBgAAAQBvBgAAAgDGBgAAAwDOBgAA
>> "%~1" echo AQDGBgAAAgAKBgAAAQBvBgAAAgDGBgAAAwDOBgAAAQDGBgAAAgAKBgAAAQBvBgAA
>> "%~1" echo AQDWBgAAAgBvBgAAAwC/BgAABADCBgAAAQBvBgAAAQBvBgAAAQDZBgAAAgBvBgAA
>> "%~1" echo AQDZBgAAAgBvBgAAAQDZBgAAAgBvBgAAAQDZBgAAAgBvBgAAAQDZBgAAAgBvBgAA
>> "%~1" echo AQDZBgAAAgBvBgAAAQDZBgAAAgBvBgAAAQDZBgAAAgBvBgAAAQBvBgAAAgCDBgAA
>> "%~1" echo AQDbBgAAAgAYBgAAAwBvBgAABADGBgAABQDOBgAAAQDbBgAAAgAYBgAAAwDGBgAA
>> "%~1" echo BADgBgAABQAKBgAAAQDbBgAAAgAYBgAAAQDbBgAAAQDbBgAAAgDpBgAAAQDWBgAA
>> "%~1" echo AgDuBgAAAwD0BgAABADpBgAABQD2BgAAAQDWBgAAAgDbBgAAAwDpBgAAAQBvBgAA
>> "%~1" echo AQD7BgAAAgAKBgAAAwDGBgAAAQD7BgAAAgAKBgAAAwDGBgAAAQAKBgAAAQAABwAA
>> "%~1" echo AQACBwAAAgAEBwAAAQAGBwAAAQAGBwAAAQAABwAAAQB+BgAAAgDCBgAAAQB+BgAA
>> "%~1" echo AgDCBgAAAQB+BgAAAgAIBwAAAQAPBwAAAgDCBgAAAQB+BgAAAgDCBgAAAQB+BgAA
>> "%~1" echo AgDCBgAAAQB+BgAAAgDCBgAAAQB+BgAAAQB+BgAAAgAUBwAAAwAZBwAAAQB+BgAA
>> "%~1" echo AgAfBwAAAQB+BgAAAgAfBwAAAQB+BgAAAgDCBgAAAQB+BgAAAgDCBgAAAQB+BgAA
>> "%~1" echo AQAnBwAAAQAqBwAAAQAuBwAAAQAyBwAAAQA6BwAAAQBCBwAAAQBGBwAAAgBLBwAA
>> "%~1" echo AQBSBwAAAQBVBwAAAgBcBwAAAQBcBwAAAQB+BgAAAQB+BgAAAQB+BgAAAgBjBwAA
>> "%~1" echo AQB+BgAAAgAfBwAAAQDZBgAAAgDCBgAAAQAABwAAAQB+BgAAAgDpBgAAAQBqBgAA
>> "%~1" echo AQB+BgAAAQB+BgAAAgDbBgAAAQBvBgAAAQAABwAAAQAABwAAAQC/BgAAAQAYBgAA
>> "%~1" echo AQBQBgAAAQDCBgAAAQBqBwAAAQBwBwAAAQB0BwAAAQBXBgAAAgDCBgAAAQAABwAA
>> "%~1" echo AQAABwAAAgDZBgAAAQBjBgAAAgB2BwAAAwB7BwAAAQDZBgAAAQAABwAAAQDpBwAA
>> "%~1" echo AQD+D0EAkgVYAUkAkgVYAVEAkgWGAVkAkgVYAWkAkgVYASEASwhYAXEAWwhfAXkA
>> "%~1" echo bghUABEAdQiZAYEAhgieAXkAmQikAYkAsQiqAZEAwAivAZEA0ghfAZkA+Qi0AaEA
>> "%~1" echo kgW6AaEACwlYAYEAEQlhAIEAKgnBAXkAbgjGAXkAbgjMAXkAbgj7AIkAOAmQAHkA
>> "%~1" echo YAnTAcEACwnaAaEAggngAWEAkgXlAckAnQnrAQwAkgVYAQwArwkKAgwAxAkOAhQA
>> "%~1" echo 0gkdAoEA6QkiAtkAEQknAhQA8wksAuEACApYAXkAEAqkAQwAHgpEAnkAIgpQAiEA
>> "%~1" echo KgqGASEAPQqGASEAWwphAvEAkgVmAvkAfQpfAXkAhgoqAXkAmQpuAnkAnwpfAQkB
>> "%~1" echo kgUnAgkBtApfAQkBxQpfAXkAzwrTAREA2gp1AnkAbgiRAhwA4wqeAhwA7AqmAnkA
>> "%~1" echo bgjFAhEB/AqqAXEAkgUnAhwAAgvNAhkBFwv7AhkBHwsBAyEBLQtyACkBTQsGA3kA
>> "%~1" echo bghyACEBLQtUADkBYgsNAxkBeAsVA0EBhwshA0kBvgslA1EBHwsrAyQArwkKArEA
>> "%~1" echo HwsrAwwA6Qs5A3kA8Qs/AwkB9guQAHkABwwKAnkAEgx3AwkBHAyQACEBLwx8A3kA
>> "%~1" echo Rgx/A3kAIgqFA3kATgzTASEBVwyQADkBYwwqATkBagyKA3kAdwyhAykBYwwqATkB
>> "%~1" echo fAwNA2EBkgyxA4kAmAxmAGEBsQiLAREApAzBA3kAdwxfAXkAmQrWAzkAkgVYATkA
>> "%~1" echo wQwKBAkAHwtfATkAzAwKBDkAzAwaBDkB0wwlBHkAmQotBHkARgxFBHEB9AxRBHEB
>> "%~1" echo HwteBHkAEgxuBIEBBw3ABIEBEA1YAYEBFQ3GBCQAHgpEAiQAxAkOAiwA0gkdAiwA
>> "%~1" echo 8wksAhkBHwteBHkAIgo6BQkAkgVYAcEAjA1ZBfkAnw1fAcEAqQ1ZBYkBkgVYAYkB
>> "%~1" echo zA0nAokB2Q0nAokB5w1eBYkB+w1eBYkBFg5eBYkBMA5eBcEACwljBZEBkgXlAREB
>> "%~1" echo kgVrBREBCwlYAcEATw5yBcEAWw5YAcEAYA4KAhEB8QtyBaEBFQ+YBXkAJQ+iBXkA
>> "%~1" echo TgyoBXkAMA+hA3kAIgr1BbkBXQ8EBtEBdg8sAsEBkg8PBtkBrwkKAtkB7AoVBuEB
>> "%~1" echo nQ9fAQkApw8jBrkBtw+QALkBzg+eBukBrwkKAvEB4Q+QALkBNhCkAfkBkgXlAbkB
>> "%~1" echo Rgy5BrkBRgxyALkBRgzCBnkAPhDXBgEBSBDcBnkAWBBfARwAkgVYAXkAzwqoBREA
>> "%~1" echo aRCZATEAcxD3BjkAkgUnAhwAxAkHBzQA0gkbBzwAiBAdAjwAnQ8vBzQA8wksArEA
>> "%~1" echo HwsBAxECmBCKAxEApAxVBxkCtRBfBxkCHwsBAyECkgVeBSQAkgVYAS4AGwBrBy4A
>> "%~1" echo IwB0B8MAKwCBAeMAKwCBAQMBKwCBASEBKwCBASQBCwCBAUEBKwCBAQQECwCBAaQE
>> "%~1" echo CwCBAQQJCwCBAWANKwCBAYANKwCBAQEAEAAAAAkAlAHyATACSgJXAnsCrQLTAuwC
>> "%~1" echo RgNxA5ADmQOnA7gDyQPgA/cD+wMABBAEIAQ1BEsEZgR0BIYEmQSgBK8EuwTKBNwE
>> "%~1" echo 6gQEBRkFKwU/BXcFjAWtBbcFxAXNBdgF6AX9BRwGKQYzBjoGSgZRBmEGbgZ9Bo4G
>> "%~1" echo lAapBswG0wbhBukG/wY0B0oHZQcDAAEABAACAAAAugVjAQAAugVjAQIAbgADAAIA
>> "%~1" echo cAAFAAQCFwKXAjID1QQTBycHyGcAAB8ABIAAAAAAAAAAAAAAAAAAAAAAHAAAAAQA
>> "%~1" echo AAAAAAAAAAAAAAEARQAAAAAABAAAAAAAAAAAAAAAAQBOAAAAAAADAAIABAACAAUA
>> "%~1" echo AgAGAAIABwACAAkACAAAAAA8TW9kdWxlPgBRdWVzdEFkYldlYlVpLmV4ZQBRdWVz
>> "%~1" echo dEFkYldlYlVpAENtZFJlc3VsdABDYXB0dXJlAFNuYXBzaG90AG1zY29ybGliAFN5
>> "%~1" echo c3RlbQBPYmplY3QAQWRiUGF0aABUb2tlbgBQb3J0AFJvb3REaXIATG9nRGlyAExv
>> "%~1" echo Z0ZpbGUATG9nTG9jawBTeXN0ZW0uVGV4dABFbmNvZGluZwBVdGY4Tm9Cb20ATWFp
>> "%~1" echo bgBTZWxmVGVzdABTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYwBMaXN0YDEARXhw
>> "%~1" echo ZWN0AEV4cGVjdENvbnRhaW5zAFN5c3RlbS5OZXQuU29ja2V0cwBUY3BDbGllbnQA
>> "%~1" echo U2VydmUARGljdGlvbmFyeWAyAFN0YXR1cwBBY3Rpb24ATG9ncwBFeHBvcnRSZXBv
>> "%~1" echo cnQARXhwb3J0VXJsAFN5c3RlbS5JTwBTdHJlYW0AU2VydmVFeHBvcnQARGVidWdN
>> "%~1" echo b2RlAENvbnNlcnZhdGl2ZQBDdXJyZW50U2VyaWFsAEluaXRMb2cATG9nAFJlYWRM
>> "%~1" echo b2dUYWlsAFNlbGVjdERldmljZQBQcm9wAFNldHRpbmcAU2gAQQBNdXN0U2gATXVz
>> "%~1" echo dEEARW5zdXJlQmFja3VwAFN0cmluZ0J1aWxkZXIAV3JpdGVCYWNrdXBMaW5lAFJl
>> "%~1" echo c3RvcmVCYWNrdXAAQmFja3VwRmlsZQBGaWxsQmF0dGVyeQBGaWxsUG93ZXIARmls
>> "%~1" echo bENvbnRyb2xsZXJzRmFzdABGaWxsUmVzb3VyY2VzAEZpbGxWaXJ0dWFsRGVza3Rv
>> "%~1" echo cABGaWxsRGlzcGxheUxpdGUARmlsbFRoZXJtYWxMaXRlAEZpbGxGYWN0b3J5TGl0
>> "%~1" echo ZQBDb2xsZWN0U25hcHNob3QAQWRkU2hlbGxDYXB0dXJlAEFkZENhcHR1cmUAQ2Fw
>> "%~1" echo AEZpbGxTbmFwc2hvdEZpZWxkcwBCdWlsZFJlcG9ydEh0bWwAQWRkSW52b2ljZUZh
>> "%~1" echo Y3RzAEFkZEludm9pY2VSYXcAV2lmaUlwAFJ1bgBSdW5SZXN1bHQASm9pbkFyZ3MA
>> "%~1" echo UXVvdGVBcmcASm9pbk5vbkVtcHR5AEJhdHRlcnlTdGF0dXMAQmF0dGVyeUhlYWx0
>> "%~1" echo aABQb3dlclNvdXJjZQBBZnRlckNvbG9uAEFmdGVyRXF1YWxzAEZpbmRMaW5lAEZp
>> "%~1" echo ZWxkAEZpbmRQYWNrYWdlRmllbGQATWVtR2IAUHJvcEZyb20ARmlyc3RMaW5lAEJl
>> "%~1" echo dHdlZW4AUmVnZXhWYWx1ZQBGaXJzdFJlZ2V4AEV4dHJhY3RKc29uaXNoAEV4dHJh
>> "%~1" echo Y3RKc29uaXNoUmF3AE5vcm1hbGl6ZUVtYmVkZGVkSnNvbgBTdG9yYWdlU3VtbWFy
>> "%~1" echo eQBNZW1vcnlTdW1tYXJ5AENwdVN1bW1hcnkARGlzcGxheVN1bW1hcnkAVGhlcm1h
>> "%~1" echo bFN1bW1hcnkAVXNiU3VtbWFyeQBXaWZpU3VtbWFyeQBCbHVldG9vdGhTdW1tYXJ5
>> "%~1" echo AENhbWVyYVN1bW1hcnkARmFjdG9yeVN1bW1hcnkAVmlydHVhbERlc2t0b3BTdW1t
>> "%~1" echo YXJ5AENvdW50UGFja2FnZUxpbmVzAENvdW50UHJlZml4TGluZXMAQ291bnRSZWdl
>> "%~1" echo eABWAEgAUHJpdmFjeQBBZGJTb3VyY2VMYWJlbABSZWRhY3RMb29zZQBSZWRhY3QA
>> "%~1" echo U2VyaWFsTWFzawBDbGVhbgBMaW5lcwBWYWxpZE5zAFNhZmVOYW1lAERhbmdlcm91
>> "%~1" echo c0FjdGlvbgBEZW5pZWRTZXR0aW5nAFNoZWxsUXVvdGUAT2sARXJyb3IAQ2hlY2tU
>> "%~1" echo b2tlbgBRdWVyeQBVcmwAV3JpdGVKc29uAFdyaXRlQnl0ZXMASnNvbgBFc2MASHRt
>> "%~1" echo bAAuY3RvcgBPdXRwdXQARXhpdENvZGUAVGltZWRPdXQAZ2V0X1RleHQAVGV4dABO
>> "%~1" echo YW1lAENvbW1hbmQARHVyYXRpb25NcwBDcmVhdGVkAFNlcmlhbABEZXZpY2VMaW5l
>> "%~1" echo AEZpZWxkcwBDYXB0dXJlcwBXYXJuaW5ncwBhcmdzAGZhaWx1cmVzAG5hbWUAZXhw
>> "%~1" echo ZWN0ZWQAYWN0dWFsAG5lZWRsZXMAUGFyYW1BcnJheUF0dHJpYnV0ZQBjbGllbnQA
>> "%~1" echo YWN0aW9uAHF1ZXJ5AHN0YW1wAHN0cmVhbQBwYXRoAHNlcmlhbABiYXNlRGlyAHRl
>> "%~1" echo eHQAZGV2aWNlTGluZQBTeXN0ZW0uUnVudGltZS5JbnRlcm9wU2VydmljZXMAT3V0
>> "%~1" echo QXR0cmlidXRlAGhpbnQAbnMAa2V5AHRpbWVvdXQAY29tbWFuZABzYgBkAHNuYXAA
>> "%~1" echo cmVxdWlyZWQAc2FmZQB0aXRsZQBmAGRlZnMAZmlsZQBzAGEAYgB2AG5lZWRsZQBs
>> "%~1" echo aW5lAGxlZnQAcmlnaHQAcGF0dGVybgBkZgBtZW0AY3B1AGRpc3BsYXkAdGhlcm1h
>> "%~1" echo bAB1c2IAd2lmaQBpcEFkZHIAYnQAY2FtZXJhAHNlbnNvcgBwcmVmaXgAdmFsdWUA
>> "%~1" echo bXNnAHEAdHlwZQBib2R5AFN5c3RlbS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMA
>> "%~1" echo Q29tcGlsYXRpb25SZWxheGF0aW9uc0F0dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJp
>> "%~1" echo bGl0eUF0dHJpYnV0ZQA8TWFpbj5iX18wAG8AU3lzdGVtLlRocmVhZGluZwBXYWl0
>> "%~1" echo Q2FsbGJhY2sAQ1MkPD45X19DYWNoZWRBbm9ueW1vdXNNZXRob2REZWxlZ2F0ZTEA
>> "%~1" echo Q29tcGlsZXJHZW5lcmF0ZWRBdHRyaWJ1dGUAQ2xvc2UARXhjZXB0aW9uAGdldF9N
>> "%~1" echo ZXNzYWdlAFN0cmluZwBDb25jYXQAZ2V0X1VURjgAQ29uc29sZQBzZXRfT3V0cHV0
>> "%~1" echo RW5jb2RpbmcAb3BfRXF1YWxpdHkARW52aXJvbm1lbnQARXhpdABBcHBEb21haW4A
>> "%~1" echo Z2V0X0N1cnJlbnREb21haW4AZ2V0X0Jhc2VEaXJlY3RvcnkAU3lzdGVtLk5ldABJ
>> "%~1" echo UEFkZHJlc3MAUGFyc2UAVGNwTGlzdGVuZXIAU3RhcnQAV3JpdGVMaW5lAENvbnNv
>> "%~1" echo bGVLZXlJbmZvAFJlYWRLZXkASW50MzIAR2V0RW52aXJvbm1lbnRWYXJpYWJsZQBT
>> "%~1" echo dHJpbmdDb21wYXJpc29uAEVxdWFscwBTeXN0ZW0uRGlhZ25vc3RpY3MAUHJvY2Vz
>> "%~1" echo cwBBY2NlcHRUY3BDbGllbnQAVGhyZWFkUG9vbABRdWV1ZVVzZXJXb3JrSXRlbQBn
>> "%~1" echo ZXRfQ291bnQARW51bWVyYXRvcgBHZXRFbnVtZXJhdG9yAGdldF9DdXJyZW50AFRl
>> "%~1" echo eHRXcml0ZXIAZ2V0X0Vycm9yAE1vdmVOZXh0AElEaXNwb3NhYmxlAERpc3Bvc2UA
>> "%~1" echo b3BfSW5lcXVhbGl0eQBBZGQASW5kZXhPZgBzZXRfUmVjZWl2ZVRpbWVvdXQAc2V0
>> "%~1" echo X1NlbmRUaW1lb3V0AE5ldHdvcmtTdHJlYW0AR2V0U3RyZWFtAFN0cmVhbVJlYWRl
>> "%~1" echo cgBUZXh0UmVhZGVyAFJlYWRMaW5lAElzTnVsbE9yRW1wdHkAQ2hhcgBTcGxpdABU
>> "%~1" echo b1VwcGVySW52YXJpYW50AFVyaQBnZXRfQWJzb2x1dGVQYXRoAGdldF9RdWVyeQBT
>> "%~1" echo dGFydHNXaXRoAEdldEJ5dGVzAHNldF9JdGVtAGdldF9JdGVtAFRocmVhZABTbGVl
>> "%~1" echo cABDb250YWluc0tleQBEYXRlVGltZQBnZXRfTm93AFRvU3RyaW5nAFBhdGgAQ29t
>> "%~1" echo YmluZQBEaXJlY3RvcnkARGlyZWN0b3J5SW5mbwBDcmVhdGVEaXJlY3RvcnkARmls
>> "%~1" echo ZQBXcml0ZUFsbFRleHQAVGltZVNwYW4Ab3BfU3VidHJhY3Rpb24AZ2V0X1RvdGFs
>> "%~1" echo TWlsbGlzZWNvbmRzAFN5c3RlbS5HbG9iYWxpemF0aW9uAEN1bHR1cmVJbmZvAGdl
>> "%~1" echo dF9JbnZhcmlhbnRDdWx0dXJlAEludDY0AElGb3JtYXRQcm92aWRlcgBUb0FycmF5
>> "%~1" echo AEpvaW4ARXNjYXBlRGF0YVN0cmluZwBnZXRfTGVuZ3RoAFN1YnN0cmluZwBVbmVz
>> "%~1" echo Y2FwZURhdGFTdHJpbmcARGlyZWN0b3J5U2VwYXJhdG9yQ2hhcgBSZXBsYWNlAEVu
>> "%~1" echo ZHNXaXRoAEdldEZ1bGxQYXRoAEV4aXN0cwBSZWFkQWxsQnl0ZXMAVHJpbQBBcHBl
>> "%~1" echo bmRBbGxUZXh0AE1vbml0b3IARW50ZXIAZ2V0X05ld0xpbmUAR2V0U3RyaW5nAFN0
>> "%~1" echo cmluZ1NwbGl0T3B0aW9ucwBBcHBlbmRMaW5lAEFwcGVuZABSZWFkQWxsTGluZXMA
>> "%~1" echo RG91YmxlAE51bWJlclN0eWxlcwBUcnlQYXJzZQBTdG9wd2F0Y2gAU3RhcnROZXcA
>> "%~1" echo U3RvcABnZXRfRWxhcHNlZE1pbGxpc2Vjb25kcwA8PmNfX0Rpc3BsYXlDbGFzczUA
>> "%~1" echo cmVzdWx0ADw+Y19fRGlzcGxheUNsYXNzNwBDUyQ8PjhfX2xvY2FsczYAcAA8UnVu
>> "%~1" echo UmVzdWx0PmJfXzMAPFJ1blJlc3VsdD5iX180AGdldF9TdGFuZGFyZE91dHB1dABS
>> "%~1" echo ZWFkVG9FbmQAZ2V0X1N0YW5kYXJkRXJyb3IAUHJvY2Vzc1N0YXJ0SW5mbwBzZXRf
>> "%~1" echo RmlsZU5hbWUAc2V0X0FyZ3VtZW50cwBzZXRfVXNlU2hlbGxFeGVjdXRlAHNldF9S
>> "%~1" echo ZWRpcmVjdFN0YW5kYXJkT3V0cHV0AHNldF9SZWRpcmVjdFN0YW5kYXJkRXJyb3IA
>> "%~1" echo c2V0X0NyZWF0ZU5vV2luZG93AFRocmVhZFN0YXJ0AFdhaXRGb3JFeGl0AEtpbGwA
>> "%~1" echo Z2V0X0V4aXRDb2RlADxQcml2YXRlSW1wbGVtZW50YXRpb25EZXRhaWxzPntDQkZG
>> "%~1" echo Q0UwOS01NkU4LTRFQzUtQkUwNy0yQkNGMzBGRTM1N0J9AFZhbHVlVHlwZQBfX1N0
>> "%~1" echo YXRpY0FycmF5SW5pdFR5cGVTaXplPTE2ACQkbWV0aG9kMHg2MDAwMDMxLTEAUnVu
>> "%~1" echo dGltZUhlbHBlcnMAQXJyYXkAUnVudGltZUZpZWxkSGFuZGxlAEluaXRpYWxpemVB
>> "%~1" echo cnJheQBJbmRleE9mQW55AFRyaW1FbmQAU3lzdGVtLlRleHQuUmVndWxhckV4cHJl
>> "%~1" echo c3Npb25zAFJlZ2V4AE1hdGNoAFJlZ2V4T3B0aW9ucwBHcm91cABnZXRfU3VjY2Vz
>> "%~1" echo cwBHcm91cENvbGxlY3Rpb24AZ2V0X0dyb3VwcwBnZXRfVmFsdWUAUmVmZXJlbmNl
>> "%~1" echo RXF1YWxzAEVzY2FwZQBNYXRjaENvbGxlY3Rpb24ATWF0Y2hlcwBXZWJVdGlsaXR5
>> "%~1" echo AEh0bWxFbmNvZGUAPFJlZGFjdExvb3NlPmJfXzkAbQBNYXRjaEV2YWx1YXRvcgBD
>> "%~1" echo UyQ8PjlfX0NhY2hlZEFub255bW91c01ldGhvZERlbGVnYXRlYQBJc01hdGNoAGdl
>> "%~1" echo dF9DaGFycwBJc0xldHRlck9yRGlnaXQAVG9Mb3dlckludmFyaWFudABnZXRfQVND
>> "%~1" echo SUkAV3JpdGUAS2V5VmFsdWVQYWlyYDIAZ2V0X0tleQBDb252ZXJ0AEZyb21CYXNl
>> "%~1" echo NjRTdHJpbmcALmNjdG9yAEd1aWQATmV3R3VpZABVVEY4RW5jb2RpbmcAAAAAD/eL
>> "%~1" echo Qmy/fgt6Al84Xhr/ARctAC0AcwBlAGwAZgAtAHQAZQBzAHQAARMxADIANwAuADAA
>> "%~1" echo LgAwAC4AMQAATVEAdQBlAHMAdAAgAEEARABCACAAVwBlAGIAVQBJACAAL1SoUjFZ
>> "%~1" echo JY0a/zgANwA2ADUALQA4ADcAOAA1ACAA73rjU/2QDU7vUyh1AjABLS9UqFIxWSWN
>> "%~1" echo Gv84ADcANgA1AC0AOAA3ADgANQAgAO9641P9kA1O71ModQIwASNoAHQAdABwADoA
>> "%~1" echo LwAvADEAMgA3AC4AMAAuADAALgAxADoAABEvAD8AdABvAGsAZQBuAD0AAC1RAHUA
>> "%~1" echo ZQBzAHQAIABBAEQAQgAgAFcAZQBiAFUASQAgAA1noVLyXS9UqFIa/wE96lPRdixU
>> "%~1" echo IAAxADIANwAuADAALgAwAC4AMQAb/3NR7ZUsZ5d641MOVCAAVwBlAGIAVQBJACAA
>> "%~1" echo XFBiawIwAQtBAEQAQgA6ACAAAAnlZddfOgAgAAEtDWehUi9UqFIa/2gAdAB0AHAA
>> "%~1" echo OgAvAC8AMQAyADcALgAwAC4AMAAuADEAOgABAy8AAA8dUstZ3o+lY7ZyAWAa/wED
>> "%~1" echo IAAAAzEAADVRAFUARQBTAFQAXwBBAEQAQgBfAFcARQBCAFUASQBfAE4ATwBfAEIA
>> "%~1" echo UgBPAFcAUwBFAFIAAA/3i0JsBFkGdDFZJY0a/wGB6XsAXAAiAEQAZQB2AGkAYwBl
>> "%~1" echo AFwAIgA6AHsAXAAiAEIAdQBpAGwAZABUAHkAcABlAFwAIgA6AFwAIgBQAFYAVAAx
>> "%~1" echo AC4AMQBcACIALABcACIARABlAHYAaQBjAGUAVAB5AHAAZQBcACIAOgBcACIARQB1
>> "%~1" echo AHIAZQBrAGEAXAAiAH0ALABcACIARgBpAGwAZQBGAG8AcgBtAGEAdABcACIAOgB7
>> "%~1" echo AFwAIgBUAGkAbQBlAHMAdABhAG0AcABcACIAOgBcACIAMgAwADIANQAtADEAMQAt
>> "%~1" echo ADEANQBUADAAOAA6ADEANQA6ADQANQBcACIAfQAsAFwAIgBNAGUAdABhAGQAYQB0
>> "%~1" echo AGEAXAAiADoAewBcACIATgBhAG0AZQBkAFQAYQBnAHMAXAAiADoAewBcACIAbABv
>> "%~1" echo AGMAYQB0AGkAbwBuAF8AaQBkAFwAIgA6AFwAIgBnAHQAawBcACIALABcACIAcwB0
>> "%~1" echo AGEAdABpAG8AbgBfAGkAZABcACIAOgBcACIAdwBmAC0AZQB1AHIAZQBrAGEALQBp
>> "%~1" echo AG8AdAAtADIAdQBwAC0ANAAxAFwAIgAsAFwAIgBjAGEAbABpAGIAcgBhAHQAaQBv
>> "%~1" echo AG4AXwB0AHkAcABlAFwAIgA6AFwAIgBJAE8AVABcACIAfQB9AH0AARVEAGUAdgBp
>> "%~1" echo AGMAZQBUAHkAcABlAAANRQB1AHIAZQBrAGEAABNCAHUAaQBsAGQAVAB5AHAAZQAA
>> "%~1" echo DVAAVgBUADEALgAxAAATVABpAG0AZQBzAHQAYQBtAHAAACcyADAAMgA1AC0AMQAx
>> "%~1" echo AC0AMQA1AFQAMAA4ADoAMQA1ADoANAA1AAEXbABvAGMAYQB0AGkAbwBuAF8AaQBk
>> "%~1" echo AAAHZwB0AGsAABVzAHQAYQB0AGkAbwBuAF8AaQBkAAApdwBmAC0AZQB1AHIAZQBr
>> "%~1" echo AGEALQBpAG8AdAAtADIAdQBwAC0ANAAxAAEdRgBhAGMAdABvAHIAeQBTAHUAbQBt
>> "%~1" echo AGEAcgB5AAAPbABvAGMAIABnAHQAawAAOXMAdABhAHQAaQBvAG4AIAB3AGYALQBl
>> "%~1" echo AHUAcgBlAGsAYQAtAGkAbwB0AC0AMgB1AHAALQA0ADEAAYChewBcACIAUwBlAG4A
>> "%~1" echo cwBvAHIAVAB5AHAAZQBcACIAOgBcACIATwBHADAAMQBBAFwAIgB9AHsAXAAiAFMA
>> "%~1" echo ZQBuAHMAbwByAFQAeQBwAGUAXAAiADoAXAAiAE8AVgA3ADIANQAxAFwAIgB9AHsA
>> "%~1" echo XAAiAFMAZQBuAHMAbwByAFQAeQBwAGUAXAAiADoAXAAiAEkATQBYADQANwAxAFwA
>> "%~1" echo IgB9AAAbQwBhAG0AZQByAGEAUwB1AG0AbQBhAHIAeQAAAQAPTwBHADAAMQBBACAA
>> "%~1" echo MQAAEU8AVgA3ADIANQAxACAAMQAAEUkATQBYADQANwAxACAAMQAAOVEAdQBlAHMA
>> "%~1" echo dABBAGQAYgBXAGUAYgBVAGkAIABzAGUAbABmAC0AdABlAHMAdAAgAFAAQQBTAFMA
>> "%~1" echo ARk6ACAAZQB4AHAAZQBjAHQAZQBkACAAWwAAF10AIABiAHUAdAAgAGcAbwB0ACAA
>> "%~1" echo WwAAA10AABc6ACAAbQBpAHMAcwBpAG4AZwAgAFsAAA1dACAAaQBuACAAWwAAFy8A
>> "%~1" echo YQBwAGkALwBzAHQAYQB0AHUAcwAAEXQAbwBrAGUAbgAgAOBlSGUBFy8AYQBwAGkA
>> "%~1" echo LwBhAGMAdABpAG8AbgAACVAATwBTAFQAACPuTzllzWRcT8Vfe5h/Tyh1IABQAE8A
>> "%~1" echo UwBUACAA94tCbAIwAQ1hAGMAdABpAG8AbgAAD2MAbwBuAGYAaQByAG0AAAdZAEUA
>> "%~1" echo UwAAF3FTaZbNZFxPAJeBiYxOIWtueKSLAjABEy8AYQBwAGkALwBsAG8AZwBzAAAX
>> "%~1" echo LwBhAHAAaQAvAGUAeABwAG8AcgB0AAAf/Fv6UcVfe5h/Tyh1IABQAE8AUwBUACAA
>> "%~1" echo 94tCbAIwARMvAGUAeABwAG8AcgB0AHMALwAAM3QAZQB4AHQALwBwAGwAYQBpAG4A
>> "%~1" echo OwAgAGMAaABhAHIAcwBlAHQAPQB1AHQAZgAtADgAARkvAGYAYQB2AGkAYwBvAG4A
>> "%~1" echo LgBpAGMAbwAAG2kAbQBhAGcAZQAvAHMAdgBnACsAeABtAGwAAIGzPABzAHYAZwAg
>> "%~1" echo AHgAbQBsAG4AcwA9ACcAaAB0AHQAcAA6AC8ALwB3AHcAdwAuAHcAMwAuAG8AcgBn
>> "%~1" echo AC8AMgAwADAAMAAvAHMAdgBnACcAIAB2AGkAZQB3AEIAbwB4AD0AJwAwACAAMAAg
>> "%~1" echo ADIANAAgADIANAAnACAAZgBpAGwAbAA9ACcAbgBvAG4AZQAnACAAcwB0AHIAbwBr
>> "%~1" echo AGUAPQAnACMAMgA1ADYAMwBlAGIAJwAgAHMAdAByAG8AawBlAC0AdwBpAGQAdABo
>> "%~1" echo AD0AJwAyACcAPgA8AHAAYQB0AGgAIABkAD0AJwBNADYAIAA5AGgAMQAyAGEAMwAg
>> "%~1" echo ADMAIAAwACAAMAAgADEAIAAzACAAMwB2ADMAYQAzACAAMwAgADAAIAAwACAAMQAt
>> "%~1" echo ADMAIAAzAGgALQAxAC4ANQBsAC0AMgAuADUALQAzAGgALQA0AGwALQAyAC4ANQAg
>> "%~1" echo ADMASAA2AGEAMwAgADMAIAAwACAAMAAgADEALQAzAC0AMwB2AC0AMwBhADMAIAAz
>> "%~1" echo ACAAMAAgADAAIAAxACAAMwAtADMAegAnAC8APgA8AC8AcwB2AGcAPgABMXQAZQB4
>> "%~1" echo AHQALwBoAHQAbQBsADsAIABjAGgAYQByAHMAZQB0AD0AdQB0AGYALQA4AAEPcwBl
>> "%~1" echo AHIAdgBpAGMAZQAAFTEAMgA3AC4AMAAuADAALgAxADoAAA9hAGQAYgBQAGEAdABo
>> "%~1" echo AAAPbABvAGcARgBpAGwAZQAAF2QAZQB2AGkAYwBlAFMAdABhAHQAZQAAFWQAZQB2
>> "%~1" echo AGkAYwBlAEwAaQBuAGUAAAloAGkAbgB0AAATYwBvAG4AbgBlAGMAdABlAGQAAA1k
>> "%~1" echo AGUAdgBpAGMAZQAAC2YAYQBsAHMAZQAACXQAcgB1AGUAAAu2cgFg+4vWUxr/AQ1z
>> "%~1" echo AGUAcgBpAGEAbAAAC20AbwBkAGUAbAAAIXIAbwAuAHAAcgBvAGQAdQBjAHQALgBt
>> "%~1" echo AG8AZABlAGwAAA9hAG4AZAByAG8AaQBkAAAxcgBvAC4AYgB1AGkAbABkAC4AdgBl
>> "%~1" echo AHIAcwBpAG8AbgAuAHIAZQBsAGUAYQBzAGUAAAdzAGQAawAAKXIAbwAuAGIAdQBp
>> "%~1" echo AGwAZAAuAHYAZQByAHMAaQBvAG4ALgBzAGQAawAAG3MAZQBjAHUAcgBpAHQAeQBQ
>> "%~1" echo AGEAdABjAGgAAD9yAG8ALgBiAHUAaQBsAGQALgB2AGUAcgBzAGkAbwBuAC4AcwBl
>> "%~1" echo AGMAdQByAGkAdAB5AF8AcABhAHQAYwBoAAAZbQBhAG4AdQBmAGEAYwB0AHUAcgBl
>> "%~1" echo AHIAAC9yAG8ALgBwAHIAbwBkAHUAYwB0AC4AbQBhAG4AdQBmAGEAYwB0AHUAcgBl
>> "%~1" echo AHIAAAtiAHIAYQBuAGQAACFyAG8ALgBwAHIAbwBkAHUAYwB0AC4AYgByAGEAbgBk
>> "%~1" echo AAAXcAByAG8AZAB1AGMAdABOAGEAbQBlAAAfcgBvAC4AcAByAG8AZAB1AGMAdAAu
>> "%~1" echo AG4AYQBtAGUAABtwAHIAbwBkAHUAYwB0AEQAZQB2AGkAYwBlAAAjcgBvAC4AcABy
>> "%~1" echo AG8AZAB1AGMAdAAuAGQAZQB2AGkAYwBlAAALYgBvAGEAcgBkAAAhcgBvAC4AcABy
>> "%~1" echo AG8AZAB1AGMAdAAuAGIAbwBhAHIAZAAAB3MAbwBjAAAncgBvAC4AcwBvAGMALgBt
>> "%~1" echo AGEAbgB1AGYAYQBjAHQAdQByAGUAcgAAGXIAbwAuAHMAbwBjAC4AbQBvAGQAZQBs
>> "%~1" echo AAAPYgB1AGkAbABkAEkAZAAAJ3IAbwAuAGIAdQBpAGwAZAAuAGQAaQBzAHAAbABh
>> "%~1" echo AHkALgBpAGQAABdiAHUAaQBsAGQAQgByAGEAbgBjAGgAAB9yAG8ALgBiAHUAaQBs
>> "%~1" echo AGQALgBiAHIAYQBuAGMAaAAAIWIAdQBpAGwAZABJAG4AYwByAGUAbQBlAG4AdABh
>> "%~1" echo AGwAADlyAG8ALgBiAHUAaQBsAGQALgB2AGUAcgBzAGkAbwBuAC4AaQBuAGMAcgBl
>> "%~1" echo AG0AZQBuAHQAYQBsAAAXdgBlAG4AZABvAHIAUABhAHQAYwBoAAA9cgBvAC4AdgBl
>> "%~1" echo AG4AZABvAHIALgBiAHUAaQBsAGQALgBzAGUAYwB1AHIAaQB0AHkAXwBwAGEAdABj
>> "%~1" echo AGgAAAdhAGIAaQAAJXIAbwAuAHAAcgBvAGQAdQBjAHQALgBjAHAAdQAuAGEAYgBp
>> "%~1" echo AAANdwBpAGYAaQBJAHAAABVhAGQAYgBFAG4AYQBiAGwAZQBkAAANZwBsAG8AYgBh
>> "%~1" echo AGwAABdhAGQAYgBfAGUAbgBhAGIAbABlAGQAAA9hAGQAYgBXAGkAZgBpAAAhYQBk
>> "%~1" echo AGIAXwB3AGkAZgBpAF8AZQBuAGEAYgBsAGUAZAAADXMAdABhAHkATwBuAAAxcwB0
>> "%~1" echo AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4AABN3
>> "%~1" echo AGkAZgBpAFMAbABlAGUAcAAAI3cAaQBmAGkAXwBzAGwAZQBlAHAAXwBwAG8AbABp
>> "%~1" echo AGMAeQAAE3MAYwByAGUAZQBuAE8AZgBmAAANcwB5AHMAdABlAG0AACVzAGMAcgBl
>> "%~1" echo AGUAbgBfAG8AZgBmAF8AdABpAG0AZQBvAHUAdAAAGXMAbABlAGUAcABUAGkAbQBl
>> "%~1" echo AG8AdQB0AAANcwBlAGMAdQByAGUAABtzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0
>> "%~1" echo AAARbABvAHcAUABvAHcAZQByAAATbABvAHcAXwBwAG8AdwBlAHIAABm2cgFg+4vW
>> "%~1" echo Uxr/ZABlAHYAaQBjAGUAIAABEyAAYgBhAHQAdABlAHIAeQA9AAAZYgBhAHQAdABl
>> "%~1" echo AHIAeQBMAGUAdgBlAGwAAA8lACAAdABlAG0AcAA9AAAXYgBhAHQAdABlAHIAeQBU
>> "%~1" echo AGUAbQBwAAAPQwAgAHcAYQBrAGUAPQAAF3cAYQBrAGUAZgB1AGwAbgBlAHMAcwAA
>> "%~1" echo ESAAcwB0AGEAeQBPAG4APQAAEyAAYQBkAGIAVwBpAGYAaQA9AAALzWRcTwBfy1ka
>> "%~1" echo /wERIABzAGUAcgBpAGEAbAA9AAAXcgBlAHMAdABhAHIAdABfAGEAZABiAAAXawBp
>> "%~1" echo AGwAbAAtAHMAZQByAHYAZQByAAEZcwB0AGEAcgB0AC0AcwBlAHIAdgBlAHIAAQ1y
>> "%~1" echo AGUAcwB1AGwAdAAAHfJdzZEvVDV1EYHveiAAQQBEAEIAIAANZ6FSAjABAy0AASGh
>> "%~1" echo bAlnKFe/fhRO8l2IY0NnhHYgAFEAdQBlAHMAdAACMAEVcwBhAGYAZQBfAHMAbABl
>> "%~1" echo AGUAcAAAOWkAbgBwAHUAdAAgAGsAZQB5AGUAdgBlAG4AdAAgAEsARQBZAEMATwBE
>> "%~1" echo AEUAXwBTAEwARQBFAFAAAEnyXWJgDVndT4hbPFB2XtFTAZAgAHAAcgBvAHgAXwBv
>> "%~1" echo AHAAZQBuACAAKwAgAEsARQBZAEMATwBEAEUAXwBTAEwARQBFAFAAAjABFWsAZQBl
>> "%~1" echo AHAAXwBhAHcAYQBrAGUAABHyXZReKHXtd/Zl3U87bQIwARVkAGUAYgB1AGcAXwBt
>> "%~1" echo AG8AZABlAAB/8l0vVCh1A4zVi+VdXE8hag9fGv9VAFMAQgAvAEEAQwAgAN1PAWMk
>> "%~1" echo VZKRATBXAGkALQBGAGkAIAANThFPIHcBME9cVV4gADIANAAgAA9c9mUBMCFq32Jp
>> "%~1" echo TzRiYJfRjwIw035fZw5U94tnYkyIHCBiYA1ZEU8gd4WN9mUdIAIwARtyAGUAcwB0
>> "%~1" echo AG8AcgBlAF8AcwBsAGUAZQBwAAAl8l1iYA1ZY2s4XhFPIHcOTiAANQAgAAZSn5RP
>> "%~1" echo XFVehY32ZQIwARljAG8AbgBzAGUAcgB2AGEAdABpAHYAZQAAE/JdYmANWd1PiFvY
>> "%~1" echo nqSLPFACMAEdcgBlAHMAdABvAHIAZQBfAGIAYQBjAGsAdQBwAAAv8l3OTgdZ/U5i
>> "%~1" echo YA1Zvotufwz/dl7RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgACMAETcAByAG8AeABf
>> "%~1" echo AG8AcABlAG4AAGdhAG0AIABiAHIAbwBhAGQAYwBhAHMAdAAgAC0AYQAgAGMAbwBt
>> "%~1" echo AC4AbwBjAHUAbAB1AHMALgB2AHIAcABvAHcAZQByAG0AYQBuAGEAZwBlAHIALgBw
>> "%~1" echo AHIAbwB4AF8AbwBwAGUAbgABHfJd0VMBkCAAcAByAG8AeABfAG8AcABlAG4AAjAB
>> "%~1" echo FXAAcgBvAHgAXwBjAGwAbwBzAGUAAGlhAG0AIABiAHIAbwBhAGQAYwBhAHMAdAAg
>> "%~1" echo AC0AYQAgAGMAbwBtAC4AbwBjAHUAbAB1AHMALgB2AHIAcABvAHcAZQByAG0AYQBu
>> "%~1" echo AGEAZwBlAHIALgBwAHIAbwB4AF8AYwBsAG8AcwBlAAEf8l3RUwGQIABwAHIAbwB4
>> "%~1" echo AF8AYwBsAG8AcwBlAAIwARF3AGkAcgBlAGwAZQBzAHMAAAUtAHMAAQt0AGMAcABp
>> "%~1" echo AHAAAAk1ADUANQA1AAAj8l33i0JsAF8vVOBlv34gAEEARABCACAANQA1ADUANQAC
>> "%~1" echo MAEZdwBpAHIAZQBsAGUAcwBzAF8AbwBmAGYAAE1zAGUAdAB0AGkAbgBnAHMAIABw
>> "%~1" echo AHUAdAAgAGcAbABvAGIAYQBsACAAYQBkAGIAXwB3AGkAZgBpAF8AZQBuAGEAYgBs
>> "%~1" echo AGUAZAAgADAAAAd1AHMAYgAAXfJd94tCbHNR7ZXgZb9+IABBAEQAQgAM/2EAZABi
>> "%~1" echo AGQAIADyXQdS3lYgAFUAUwBCACAAIWoPXwIw5YJTX01SL2bgZb9+3o+lYwz/rWUA
>> "%~1" echo X15cjk5jazhesHNhjAIwARNrAGUAeQBfAHMAbABlAGUAcAAAJfJd0VMBkCAASwBF
>> "%~1" echo AFkAQwBPAEQARQBfAFMATABFAEUAUAACMAEVawBlAHkAXwB3AGEAawBlAHUAcAAA
>> "%~1" echo O2kAbgBwAHUAdAAgAGsAZQB5AGUAdgBlAG4AdAAgAEsARQBZAEMATwBEAEUAXwBX
>> "%~1" echo AEEASwBFAFUAUAAAQ/Jd0VMBkCAASwBFAFkAQwBPAEQARQBfAFcAQQBLAEUAVQBQ
>> "%~1" echo AAIwxU4oVyAAQQBEAEIAIADNTihXv372ZQlnSGUCMAETcwBjAHIAZQBlAG4AXwA1
>> "%~1" echo AG0AAFtzAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAHMAeQBzAHQAZQBtACAAcwBj
>> "%~1" echo AHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAIAAzADAAMAAwADAAMAAA
>> "%~1" echo OXMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAAPQAgADMAMAAw
>> "%~1" echo ADAAMAAwAAIwARVzAGMAcgBlAGUAbgBfADIANABoAABfcwBlAHQAdABpAG4AZwBz
>> "%~1" echo ACAAcAB1AHQAIABzAHkAcwB0AGUAbQAgAHMAYwByAGUAZQBuAF8AbwBmAGYAXwB0
>> "%~1" echo AGkAbQBlAG8AdQB0ACAAOAA2ADQAMAAwADAAMAAwAAA9cwBjAHIAZQBlAG4AXwBv
>> "%~1" echo AGYAZgBfAHQAaQBtAGUAbwB1AHQAIAA9ACAAOAA2ADQAMAAwADAAMAAwAAIwARFz
>> "%~1" echo AHQAYQB5AF8AbwBmAGYAAF1zAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcAbABv
>> "%~1" echo AGIAYQBsACAAcwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBl
>> "%~1" echo AGQAXwBpAG4AIAAwAAA7cwB0AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1
>> "%~1" echo AGcAZwBlAGQAXwBpAG4AIAA9ACAAMAACMAEXcwB0AGEAeQBfAHUAcwBiAF8AYQBj
>> "%~1" echo AABdcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHMAdABh
>> "%~1" echo AHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBuACAAMwAA
>> "%~1" echo O3MAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBu
>> "%~1" echo ACAAPQAgADMAAjABIXIAZQBzAGUAdABfAHMAYwByAGUAZQBuAF8AbwBmAGYAAEHy
>> "%~1" echo Xc2Rbn8gAHMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAAPQAg
>> "%~1" echo ADMAMAAwADAAMAAwAAIwARtyAGUAcwBlAHQAXwBzAHQAYQB5AF8AbwBuAABD8l3N
>> "%~1" echo kW5/IABzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUAZABf
>> "%~1" echo AGkAbgAgAD0AIAAwAAIwASFyAGUAcwBlAHQAXwB3AGkAZgBpAF8AcwBsAGUAZQBw
>> "%~1" echo AABPcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHcAaQBm
>> "%~1" echo AGkAXwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAgADEAADXyXc2Rbn8gAHcAaQBm
>> "%~1" echo AGkAXwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAgAD0AIAAxAAIwASdyAGUAcwBl
>> "%~1" echo AHQAXwBzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0AABJcwBlAHQAdABpAG4AZwBz
>> "%~1" echo ACAAZABlAGwAZQB0AGUAIABzAGUAYwB1AHIAZQAgAHMAbABlAGUAcABfAHQAaQBt
>> "%~1" echo AGUAbwB1AHQAAEHyXSBSZJYgAHMAbABlAGUAcABfAHQAaQBtAGUAbwB1AHQAIAB2
>> "%~1" echo XtFTAZAgAHAAcgBvAHgAXwBvAHAAZQBuAAIwAR1jAHUAcwB0AG8AbQBfAHMAZQB0
>> "%~1" echo AHQAaQBuAGcAAAVuAHMAAAdrAGUAeQAAC3YAYQBsAHUAZQAAI24AYQBtAGUAcwBw
>> "%~1" echo AGEAYwBlACAAFmIulQ1UDU4IVNVsAjABK+WLLpUNVF5cjk7Yms6YaZb7fN9+LpUM
>> "%~1" echo //JdO5Zia+qBmltJTplRZVECMAEbcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIAAA
>> "%~1" echo Ay4AAAcgAD0AIAAAIWMAdQBzAHQAbwBtAF8AYgByAG8AYQBkAGMAYQBzAHQAAAlu
>> "%~1" echo AGEAbQBlAAARf16tZA1U8HkNTghU1WwCMAEhYQBtACAAYgByAG8AYQBkAGMAYQBz
>> "%~1" echo AHQAIAAtAGEAIAABDfJd0VMBkH9erWQa/wELKmfld81kXE8CMAELzWRcT4xbEGIa
>> "%~1" echo /wERIAByAGUAcwB1AGwAdAA9AAAFbwBrAAALZQByAHIAbwByAAALzWRcTzFZJY0a
>> "%~1" echo /wEPIABlAHIAcgBvAHIAPQAACXQAZQB4AHQAACX8W/pRAF/LWRr/6lP7i4xbdGW+
>> "%~1" echo iwdZ4U9vYCAASABUAE0ATAABH3kAeQB5AHkATQBNAGQAZABfAEgASABtAG0AcwBz
>> "%~1" echo AAAPZQB4AHAAbwByAHQAcwAAN1EAdQBlAHMAdAAzAF8AZABlAHYAaQBjAGUAXwBw
>> "%~1" echo AHIAaQB2AGEAdABlAF8AZgB1AGwAbABfAAALLgBoAHQAbQBsAAAzUQB1AGUAcwB0
>> "%~1" echo ADMAXwBkAGUAdgBpAGMAZQBfAHMAaABhAHIAZQBfAHMAYQBmAGUAXwAAF3AAcgBp
>> "%~1" echo AHYAYQB0AGUAUABhAHQAaAAAEXMAYQBmAGUAUABhAHQAaAAAFXAAcgBpAHYAYQB0
>> "%~1" echo AGUAVQByAGwAAA9zAGEAZgBlAFUAcgBsAAAVZAB1AHIAYQB0AGkAbwBuAE0AcwAA
>> "%~1" echo GXMAZQBjAHQAaQBvAG4AQwBvAHUAbgB0AAARdwBhAHIAbgBpAG4AZwBzAAAHIAB8
>> "%~1" echo ACAAACnyXR91EGLBeQlnjFt0ZUhyjFQGUqtOiVtoUUhyIABIAFQATQBMAAIwAQv8
>> "%~1" echo W/pRjFsQYhr/AQcgAC8AIAAAC/xb+lExWSWNGv8BDz8AdABvAGsAZQBuAD0AAAUu
>> "%~1" echo AC4AAA1el9VspWJKVO+NhF8BC6ViSlQNTlhbKFcBD/uL1lOlYkpUMVkljRr/AU9z
>> "%~1" echo AGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcAbABvAGIAYQBsACAAdwBpAGYAaQBf
>> "%~1" echo AHMAbABlAGUAcABfAHAAbwBsAGkAYwB5ACAAMgAASXMAZQB0AHQAaQBuAGcAcwAg
>> "%~1" echo AHAAdQB0ACAAcwBlAGMAdQByAGUAIABzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0
>> "%~1" echo ACAALQAxAAEdUQB1AGUAcwB0AF8AQQBEAEIAXwBMAG8AZwBzAAANdwBlAGIAdQBp
>> "%~1" echo AF8AAAkuAGwAbwBnAAAnUQB1AGUAcwB0AF8AQQBEAEIAXwBXAGUAYgBVAEkALgBs
>> "%~1" echo AG8AZwAAL3kAeQB5AHkALQBNAE0ALQBkAGQAIABIAEgAOgBtAG0AOgBzAHMALgBm
>> "%~1" echo AGYAZgABBSAAIAAAE+Vl11+HZfZOGlwqZxtS+l4CMAEP+4vWU+Vl118xWSWNGv8B
>> "%~1" echo WSpn0VOwcyAAQQBEAEIAIAC+iwdZAjDAaOVnAF/RUwWAIWoPXwEwVQBTAEIAIAAD
>> "%~1" echo jNWLiGNDZwEwcGVuY79+jFQgAFcAaQBuAGQAbwB3AHMAIABxmqhSAjABD2QAZQB2
>> "%~1" echo AGkAYwBlAHMAAAUtAGwAAQ9MAGkAcwB0ACAAbwBmAAAXbQBvAGQAZQBsADoAUQB1
>> "%~1" echo AGUAcwB0AAAdcAByAG8AZAB1AGMAdAA6AGUAdQByAGUAawBhAAAbZABlAHYAaQBj
>> "%~1" echo AGUAOgBlAHUAcgBlAGsAYQAAGXUAbgBhAHUAdABoAG8AcgBpAHoAZQBkAAAPbwBm
>> "%~1" echo AGYAbABpAG4AZQAAMfJd3o+lY3Ze8l2IY0NnDP/yXRhPSFEJkOliIABVAFMAQgAg
>> "%~1" echo AFEAdQBlAHMAdAACMAEl8l3ej6Vjdl7yXYhjQ2cM//JdCZDpYiAAUQB1AGUAcwB0
>> "%~1" echo AAIwAU/yXd6PpWN2XvJdiGNDZwIw6GwPYRr/KmfGiytSMFIgAFEAdQBlAHMAdAAg
>> "%~1" echo AItX91MM//JdCZDpYix7AE4qTiAAQQBEAEIAIAC+iwdZAjABO76LB1kqZ4hjQ2ca
>> "%~1" echo /zRiCk40WT5mDP8oVyAAVQBTAEIAIAADjNWLiGNDZzlfl3rMkQmQ6WJBUbiLAjAB
>> "%~1" echo O76LB1m7eb9+Gv/NkS9UIABBAEQAQgAgAA1noVIBMM2R0mMgAFUAUwBCACAAFmL0
>> "%~1" echo ZmJjcGVuY79+AjABFdFTsHO+iwdZRk+2cgFgAl84Xhr/AQ91AG4AawBuAG8AdwBu
>> "%~1" echo AAAJbgBvAG4AZQAAEWcAZQB0AHAAcgBvAHAAIAAAG3MAZQB0AHQAaQBuAGcAcwAg
>> "%~1" echo AGcAZQB0ACAAAAluAHUAbABsAAALcwBoAGUAbABsAAATQQBEAEIAIAB9VOROhY32
>> "%~1" echo ZRr/ARNBAEQAQgAgAH1U5E4xWSWNKAABBSkAGv8BJSMAIABRAHUAZQBzAHQAIABB
>> "%~1" echo AEQAQgAgAOVdd1G+i25/B1n9TgETIwAgAGQAZQB2AGkAYwBlAD0AABUjACAAYwBy
>> "%~1" echo AGUAYQB0AGUAZAA9AAAneQB5AHkAeQAtAE0ATQAtAGQAZAAgAEgASAA6AG0AbQA6
>> "%~1" echo AHMAcwABEfJdG1L6Xr6Lbn8HWf1OGv8BEfuL1lMHWf1OPFAxWSWNGv8BE6FsCWd+
>> "%~1" echo YjBSB1n9Todl9k4a/wEDIwAAIXMAZQB0AHQAaQBuAGcAcwAgAGQAZQBsAGUAdABl
>> "%~1" echo ACAAAA/yXc5OB1n9TmJgDVka/wEDOgAAA18AAANcAAAncQB1AGUAcwB0AF8AYQBk
>> "%~1" echo AGIAXwBzAGUAdAB0AGkAbgBnAHMAXwAACS4AYgBhAGsAAB9kAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAYgBhAHQAdABlAHIAeQAAC2wAZQB2AGUAbAAAF3QAZQBtAHAAZQByAGEAdAB1
>> "%~1" echo AHIAZQAABzAALgAjAAAbYgBhAHQAdABlAHIAeQBTAHQAYQB0AHUAcwAADXMAdABh
>> "%~1" echo AHQAdQBzAAAbYgBhAHQAdABlAHIAeQBIAGUAYQBsAHQAaAAADWgAZQBhAGwAdABo
>> "%~1" echo AAAXcABvAHcAZQByAFMAbwB1AHIAYwBlAAAbZAB1AG0AcABzAHkAcwAgAHAAbwB3
>> "%~1" echo AGUAcgAAGW0AVwBhAGsAZQBmAHUAbABuAGUAcwBzAAAPbQBTAHQAYQB5AE8AbgAA
>> "%~1" echo JW0AUAByAG8AeABpAG0AaQB0AHkAUABvAHMAaQB0AGkAdgBlAAAdbQBTAHQAYQB5
>> "%~1" echo AE8AbgBTAGUAdAB0AGkAbgBnAAA5bQBTAHQAYQB5AE8AbgBXAGgAaQBsAGUAUABs
>> "%~1" echo AHUAZwBnAGUAZABJAG4AUwBlAHQAdABpAG4AZwAAHXAAbwB3AGUAcgBTAGwAZQBl
>> "%~1" echo AHAATABpAG4AZQAAHVMAbABlAGUAcAAgAHQAaQBtAGUAbwB1AHQAOgAAK2MAbwBu
>> "%~1" echo AHQAcgBvAGwAbABlAHIATABlAGYAdABCAGEAdAB0AGUAcgB5AAAtYwBvAG4AdABy
>> "%~1" echo AG8AbABsAGUAcgBSAGkAZwBoAHQAQgBhAHQAdABlAHIAeQAAKWMAbwBuAHQAcgBv
>> "%~1" echo AGwAbABlAHIATABlAGYAdABTAHQAYQB0AHUAcwAAK2MAbwBuAHQAcgBvAGwAbABl
>> "%~1" echo AHIAUgBpAGcAaAB0AFMAdABhAHQAdQBzAAAdYwBvAG4AdAByAG8AbABsAGUAcgBI
>> "%~1" echo AGkAbgB0AAATKmf7i9ZTMFJLYsRnNXXPkQIwATFkAHUAbQBwAHMAeQBzACAATwBW
>> "%~1" echo AFIAUgBlAG0AbwB0AGUAUwBlAHIAdgBpAGMAZQAAEUIAYQB0AHQAZQByAHkAOgAA
>> "%~1" echo C1QAeQBwAGUAOgAACVQAeQBwAGUAAA9CAGEAdAB0AGUAcgB5AAANUwB0AGEAdAB1
>> "%~1" echo AHMAAAlMAGUAZgB0AAALUgBpAGcAaAB0AAAPcwB0AG8AcgBhAGcAZQAADW0AZQBt
>> "%~1" echo AG8AcgB5AAAbZABmACAALQBoACAALwBzAGQAYwBhAHIAZAABFUYAaQBsAGUAcwB5
>> "%~1" echo AHMAdABlAG0AAAkgAPJdKHUgAAEjYwBhAHQAIAAvAHAAcgBvAGMALwBtAGUAbQBp
>> "%~1" echo AG4AZgBvAAATTQBlAG0AVABvAHQAYQBsADoAABtNAGUAbQBBAHYAYQBpAGwAYQBi
>> "%~1" echo AGwAZQA6AAAH71ModSAAAQ0gAC8AIAA7YKGLIAABE3YAZABQAGEAYwBrAGEAZwBl
>> "%~1" echo AAATdgBkAFYAZQByAHMAaQBvAG4AAC1WAGkAcgB0AHUAYQBsAEQAZQBzAGsAdABv
>> "%~1" echo AHAALgBBAG4AZAByAG8AaQBkAAAhZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBn
>> "%~1" echo AGUAIAAAE1AAYQBjAGsAYQBnAGUAIABbAAAZdgBlAHIAcwBpAG8AbgBOAGEAbQBl
>> "%~1" echo AD0AAB1kAGkAcwBwAGwAYQB5AFMAdQBtAG0AYQByAHkAAB9kAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAZABpAHMAcABsAGEAeQAAI0QAaQBzAHAAbABhAHkARABlAHYAaQBjAGUASQBu
>> "%~1" echo AGYAbwAALygAXABkAHsAMwAsADUAfQBcAHMAKgB4AFwAcwAqAFwAZAB7ADMALAA1
>> "%~1" echo AH0AKQAAN3IAZQBuAGQAZQByAEYAcgBhAG0AZQBSAGEAdABlAFwAcwArACgAWwAw
>> "%~1" echo AC0AOQAuAF0AKwApAAElZABlAG4AcwBpAHQAeQBcAHMAKwAoAFsAMAAtADkAXQAr
>> "%~1" echo ACkAAS9EAGUAdgBpAGMAZQBQAHIAbwBkAHUAYwB0AEkAbgBmAG8AewBuAGEAbQBl
>> "%~1" echo AD0AAAMsAAAFSAB6AAARZABlAG4AcwBpAHQAeQAgAAAddABoAGUAcgBtAGEAbABT
>> "%~1" echo AHUAbQBtAGEAcgB5AAAtZAB1AG0AcABzAHkAcwAgAHQAaABlAHIAbQBhAGwAcwBl
>> "%~1" echo AHIAdgBpAGMAZQAAHVQAaABlAHIAbQBhAGwAIABTAHQAYQB0AHUAcwAAQ20ATgBh
>> "%~1" echo AG0AZQA9AGIAYQB0AHQAZQByAHkALABcAHMAKgBtAFYAYQBsAHUAZQA9ACgAWwAw
>> "%~1" echo AC0AOQAuAF0AKwApAAE9YgBhAHQAdABlAHIAeQBbAF4AMAAtADkAXQArACgAWwAw
>> "%~1" echo AC0AOQBdACsAXAAuAFsAMAAtADkAXQArACkAAQ9zAHQAYQB0AHUAcwAgAAAXIAAv
>> "%~1" echo ACAAYgBhAHQAdABlAHIAeQAgAAADQwAAHWYAYQBjAHQAbwByAHkAUwB1AG0AbQBh
>> "%~1" echo AHIAeQAAK2QAdQBtAHAAcwB5AHMAIABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBl
>> "%~1" echo AAARRgBhAGMAdABvAHIAeQAgAAAJbABvAGMAIAAAEXMAdABhAHQAaQBvAG4AIAAA
>> "%~1" echo F2EAZABiAF8AZABlAHYAaQBjAGUAcwAABWkAZAAAD2cAZQB0AHAAcgBvAHAAAB9z
>> "%~1" echo AGUAdAB0AGkAbgBnAHMAXwBnAGwAbwBiAGEAbAAAKXMAZQB0AHQAaQBuAGcAcwAg
>> "%~1" echo AGwAaQBzAHQAIABnAGwAbwBiAGEAbAAAH3MAZQB0AHQAaQBuAGcAcwBfAHMAeQBz
>> "%~1" echo AHQAZQBtAAApcwBlAHQAdABpAG4AZwBzACAAbABpAHMAdAAgAHMAeQBzAHQAZQBt
>> "%~1" echo AAAfcwBlAHQAdABpAG4AZwBzAF8AcwBlAGMAdQByAGUAAClzAGUAdAB0AGkAbgBn
>> "%~1" echo AHMAIABsAGkAcwB0ACAAcwBlAGMAdQByAGUAAA9iAGEAdAB0AGUAcgB5AAALcABv
>> "%~1" echo AHcAZQByAAAPZABpAHMAcABsAGEAeQAAF2QAdQBtAHAAcwB5AHMAIAB1AHMAYgAA
>> "%~1" echo CXcAaQBmAGkAABlkAHUAbQBwAHMAeQBzACAAdwBpAGYAaQAAGWMAbwBuAG4AZQBj
>> "%~1" echo AHQAaQB2AGkAdAB5AAApZAB1AG0AcABzAHkAcwAgAGMAbwBuAG4AZQBjAHQAaQB2
>> "%~1" echo AGkAdAB5AAATYgBsAHUAZQB0AG8AbwB0AGgAADNkAHUAbQBwAHMAeQBzACAAYgBs
>> "%~1" echo AHUAZQB0AG8AbwB0AGgAXwBtAGEAbgBhAGcAZQByAAANYwBhAG0AZQByAGEAAClk
>> "%~1" echo AHUAbQBwAHMAeQBzACAAbQBlAGQAaQBhAC4AYwBhAG0AZQByAGEAABtzAGUAbgBz
>> "%~1" echo AG8AcgBzAGUAcgB2AGkAYwBlAAAPdABoAGUAcgBtAGEAbAAAC2kAbgBwAHUAdAAA
>> "%~1" echo G2QAdQBtAHAAcwB5AHMAIABpAG4AcAB1AHQAABFwAGEAYwBrAGEAZwBlAHMAAC1w
>> "%~1" echo AG0AIABsAGkAcwB0ACAAcABhAGMAawBhAGcAZQBzACAALQBmACAALQBpAAERZgBl
>> "%~1" echo AGEAdAB1AHIAZQBzAAAhcABtACAAbABpAHMAdAAgAGYAZQBhAHQAdQByAGUAcwAA
>> "%~1" echo E2wAaQBiAHIAYQByAGkAZQBzAAA1YwBtAGQAIABwAGEAYwBrAGEAZwBlACAAbABp
>> "%~1" echo AHMAdAAgAGwAaQBiAHIAYQByAGkAZQBzAAAFZABmAAAnZABmACAALQBoACAALwBk
>> "%~1" echo AGEAdABhACAALwBzAGQAYwBhAHIAZAABD20AZQBtAGkAbgBmAG8AAA9jAHAAdQBp
>> "%~1" echo AG4AZgBvAAAjYwBhAHQAIAAvAHAAcgBvAGMALwBjAHAAdQBpAG4AZgBvAAALdQBu
>> "%~1" echo AGEAbQBlAAARdQBuAGEAbQBlACAALQBhAAEPaQBwAF8AYQBkAGQAcgAAD2kAcAAg
>> "%~1" echo AGEAZABkAHIAABFpAHAAXwByAG8AdQB0AGUAABFpAHAAIAByAG8AdQB0AGUAAB12
>> "%~1" echo AGkAcgB0AHUAYQBsAGQAZQBzAGsAdABvAHAAAE1kAHUAbQBwAHMAeQBzACAAcABh
>> "%~1" echo AGMAawBhAGcAZQAgAFYAaQByAHQAdQBhAGwARABlAHMAawB0AG8AcAAuAEEAbgBk
>> "%~1" echo AHIAbwBpAGQAAB9vAGMAdQBsAHUAcwBfAHAAYQBjAGsAYQBnAGUAcwAANWQAdQBt
>> "%~1" echo AHAAcwB5AHMAIABwAGEAYwBrAGEAZwBlACAAYwBvAG0ALgBvAGMAdQBsAHUAcwAA
>> "%~1" echo J2wAbwBnAGMAYQB0AF8AdABhAGkAbABfAHAAcgBpAHYAYQB0AGUAACNsAG8AZwBj
>> "%~1" echo AGEAdAAgAC0AZAAgAC0AdAAgADMAMAAwADAAAQlhAGQAYgAgAAAHIACFjfZlAQkg
>> "%~1" echo ADFZJY0a/wEPIADXU1CWFmLgZZOP+lEBD2MAcgBlAGEAdABlAGQAAA9wAHIAbwBk
>> "%~1" echo AHUAYwB0AAAXZgBpAG4AZwBlAHIAcAByAGkAbgB0AAApcgBvAC4AYgB1AGkAbABk
>> "%~1" echo AC4AZgBpAG4AZwBlAHIAcAByAGkAbgB0AAANawBlAHIAbgBlAGwAAAMlAAATcABy
>> "%~1" echo AG8AeABpAG0AaQB0AHkAAAdjAHAAdQAAC3AAYQBuAGUAbAAAI0QAZQB2AGkAYwBl
>> "%~1" echo AFAAcgBvAGQAdQBjAHQASQBuAGYAbwAAD2YAYQBjAHQAbwByAHkAABtmAGEAYwB0
>> "%~1" echo AG8AcgB5AEQAZQB2AGkAYwBlAAAZZgBhAGMAdABvAHIAeQBCAHUAaQBsAGQAABdm
>> "%~1" echo AGEAYwB0AG8AcgB5AFQAaQBtAGUAAB9mAGEAYwB0AG8AcgB5AEwAbwBjAGEAdABp
>> "%~1" echo AG8AbgAAHWYAYQBjAHQAbwByAHkAUwB0AGEAdABpAG8AbgAAJWYAYQBjAHQAbwBy
>> "%~1" echo AHkAUwB0AGEAdABpAG8AbgBUAHkAcABlAAAZcwB0AGEAdABpAG8AbgBfAHQAeQBw
>> "%~1" echo AGUAABdmAGEAYwB0AG8AcgB5AFQAZQBzAHQAABdjAGEAbABfAHQAZQBzAHQAXwBp
>> "%~1" echo AGQAAB9mAGEAYwB0AG8AcgB5AE8AcABlAHIAYQB0AG8AcgAAF28AcABlAHIAYQB0
>> "%~1" echo AG8AcgBfAGkAZAAAJWYAYQBjAHQAbwByAHkAQwBhAGwAaQBiAHIAYQB0AGkAbwBu
>> "%~1" echo AAAhYwBhAGwAaQBiAHIAYQB0AGkAbwBuAF8AdAB5AHAAZQAAI28AbgBsAGkAbgBl
>> "%~1" echo AEMAYQBsAGkAYgByAGEAdABpAG8AbgAAL3YAZQBnAGEAXwBvAG4AbABpAG4AZQBf
>> "%~1" echo AGMAYQBsAGkAYgByAGEAdABpAG8AbgAAN8BoS20wUiAAdgBlAGcAYQBfAG8AbgBs
>> "%~1" echo AGkAbgBlAF8AYwBhAGwAaQBiAHIAYQB0AGkAbwBuAAERZgBlAGEAdAB1AHIAZQA6
>> "%~1" echo AAAFdgBkAAAxUQB1AGUAcwB0ACAAQQBEAEIAIAC+iwdZoVuhi6ViSlQgAC0AIADB
>> "%~1" echo eQlnjFt0ZUhyATFRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mhW6GLpWJKVCAALQAg
>> "%~1" echo AAZSq06JW2hRSHIBGVAAUgBJAFYAQQBUAEUAIABGAFUATABMAAAVUwBIAEEAUgBF
>> "%~1" echo AC0AUwBBAEYARQABC1EAQQBEAEIALQABH3kAeQB5AHkATQBNAGQAZAAtAEgASABt
>> "%~1" echo AG0AcwBzAAGBETwAIQBkAG8AYwB0AHkAcABlACAAaAB0AG0AbAA+ADwAaAB0AG0A
>> "%~1" echo bAAgAGwAYQBuAGcAPQAiAHoAaAAtAEMATgAiAD4APABoAGUAYQBkAD4APABtAGUA
>> "%~1" echo dABhACAAYwBoAGEAcgBzAGUAdAA9ACIAdQB0AGYALQA4ACIAPgA8AG0AZQB0AGEA
>> "%~1" echo IABuAGEAbQBlAD0AIgB2AGkAZQB3AHAAbwByAHQAIgAgAGMAbwBuAHQAZQBuAHQA
>> "%~1" echo PQAiAHcAaQBkAHQAaAA9AGQAZQB2AGkAYwBlAC0AdwBpAGQAdABoACwAaQBuAGkA
>> "%~1" echo dABpAGEAbAAtAHMAYwBhAGwAZQA9ADEAIgA+ADwAdABpAHQAbABlAD4AARE8AC8A
>> "%~1" echo dABpAHQAbABlAD4AAA88AHMAdAB5AGwAZQA+AACNszoAcgBvAG8AdAB7AC0ALQBw
>> "%~1" echo AGEAZwBlADoAIwBlAGUAZgAxAGYANQA7AC0ALQBwAGEAcABlAHIAOgAjAGYAZgBm
>> "%~1" echo ADsALQAtAGkAbgBrADoAIwAxADgAMgAwADMAMwA7AC0ALQBtAHUAdABlAGQAOgAj
>> "%~1" echo ADYANgA3ADAAOAA1ADsALQAtAGwAaQBuAGUAOgAjAGQAOABlADAAZQBiADsALQAt
>> "%~1" echo AGwAaQBuAGUAMgA6ACMAZQBkAGYAMQBmADYAOwAtAC0AcwBvAGYAdAA6ACMAZgA3
>> "%~1" echo AGYAOQBmAGMAOwAtAC0AYQBjAGMAZQBuAHQAOgAjADEAZAA0AGUAZAA4ADsALQAt
>> "%~1" echo AGEAYwBjAGUAbgB0ADIAOgAjADAAZgAxADcAMgBhADsALQAtAG8AawA6ACMAMQAx
>> "%~1" echo ADgANAA0ADcAOwAtAC0AdwBhAHIAbgA6ACMAOQBhADUAYgAwADAAOwAtAC0AcwBo
>> "%~1" echo AGEAZABvAHcAOgAwACAAMQA4AHAAeAAgADQAOABwAHgAIAByAGcAYgBhACgAMQA1
>> "%~1" echo ACwAMgAzACwANAAyACwALgAxADMAKQB9ACoAewBiAG8AeAAtAHMAaQB6AGkAbgBn
>> "%~1" echo ADoAYgBvAHIAZABlAHIALQBiAG8AeAB9AGgAdABtAGwALABiAG8AZAB5AHsAbQBh
>> "%~1" echo AHIAZwBpAG4AOgAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAt
>> "%~1" echo AHAAYQBnAGUAKQA7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAGkAbgBrACkAOwBm
>> "%~1" echo AG8AbgB0ADoAMQA0AHAAeAAvADEALgA1ADIAIAAiAFMAZQBnAG8AZQAgAFUASQAi
>> "%~1" echo ACwAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFkAYQBIAGUAaQAiACwAQQByAGkAYQBs
>> "%~1" echo ACwAcwBhAG4AcwAtAHMAZQByAGkAZgA7AGwAZQB0AHQAZQByAC0AcwBwAGEAYwBp
>> "%~1" echo AG4AZwA6ADAAfQAuAHMAaABlAGUAdAB7AHcAaQBkAHQAaAA6AG0AaQBuACgAMQAx
>> "%~1" echo ADIAMABwAHgALABjAGEAbABjACgAMQAwADAAJQAgAC0AIAA0ADAAcAB4ACkAKQA7
>> "%~1" echo AG0AYQByAGcAaQBuADoAMwAwAHAAeAAgAGEAdQB0AG8AOwBiAGEAYwBrAGcAcgBv
>> "%~1" echo AHUAbgBkADoAdgBhAHIAKAAtAC0AcABhAHAAZQByACkAOwBiAG8AcgBkAGUAcgA6
>> "%~1" echo ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBkAGYAZQA2AGYAMAA7AGIAbwB4AC0AcwBo
>> "%~1" echo AGEAZABvAHcAOgB2AGEAcgAoAC0ALQBzAGgAYQBkAG8AdwApAH0ALgBwAGEAZAB7
>> "%~1" echo AHAAYQBkAGQAaQBuAGcAOgAzADgAcAB4ACAANAA0AHAAeAB9AC4AYQBjAHQAaQBv
>> "%~1" echo AG4AcwB7AHAAbwBzAGkAdABpAG8AbgA6AHMAdABpAGMAawB5ADsAdABvAHAAOgAw
>> "%~1" echo ADsAegAtAGkAbgBkAGUAeAA6ADMAOwBkAGkAcwBwAGwAYQB5ADoAZgBsAGUAeAA7
>> "%~1" echo AGoAdQBzAHQAaQBmAHkALQBjAG8AbgB0AGUAbgB0ADoAZgBsAGUAeAAtAGUAbgBk
>> "%~1" echo ADsAZwBhAHAAOgA4AHAAeAA7AHcAaQBkAHQAaAA6AG0AaQBuACgAMQAxADIAMABw
>> "%~1" echo AHgALABjAGEAbABjACgAMQAwADAAJQAgAC0AIAA0ADAAcAB4ACkAKQA7AG0AYQBy
>> "%~1" echo AGcAaQBuADoAMQA4AHAAeAAgAGEAdQB0AG8AIAAtADEANgBwAHgAfQAuAGIAdABu
>> "%~1" echo AHsAYgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAYwBiAGQANQBl
>> "%~1" echo ADEAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgA7AGMAbwBsAG8AcgA6
>> "%~1" echo ACMAMABmADEANwAyAGEAOwBiAG8AcgBkAGUAcgAtAHIAYQBkAGkAdQBzADoANgBw
>> "%~1" echo AHgAOwBwAGEAZABkAGkAbgBnADoAOABwAHgAIAAxADIAcAB4ADsAZgBvAG4AdAAt
>> "%~1" echo AHcAZQBpAGcAaAB0ADoAOAAwADAAOwBjAHUAcgBzAG8AcgA6AHAAbwBpAG4AdABl
>> "%~1" echo AHIAfQAuAGIAdABuAC4AcAByAGkAbQBhAHIAeQB7AGIAYQBjAGsAZwByAG8AdQBu
>> "%~1" echo AGQAOgB2AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAApADsAYgBvAHIAZABlAHIALQBj
>> "%~1" echo AG8AbABvAHIAOgB2AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAApADsAYwBvAGwAbwBy
>> "%~1" echo ADoAIwBmAGYAZgB9AC4AZABvAGMALQBoAGUAYQBkAHsAZABpAHMAcABsAGEAeQA6
>> "%~1" echo AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBt
>> "%~1" echo AG4AcwA6ADEAZgByACAAMwA0ADAAcAB4ADsAZwBhAHAAOgAyADgAcAB4ADsAYgBv
>> "%~1" echo AHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADMAcAB4ACAAcwBvAGwAaQBkACAAdgBh
>> "%~1" echo AHIAKAAtAC0AYQBjAGMAZQBuAHQAMgApADsAcABhAGQAZABpAG4AZwAtAGIAbwB0
>> "%~1" echo AHQAbwBtADoAMgA0AHAAeAB9AC4AawBpAGMAawBlAHIAewBkAGkAcwBwAGwAYQB5
>> "%~1" echo ADoAaQBuAGwAaQBuAGUALQBiAGwAbwBjAGsAOwBjAG8AbABvAHIAOgB2AGEAcgAo
>> "%~1" echo AC0ALQBhAGMAYwBlAG4AdAApADsAZgBvAG4AdAAtAHMAaQB6AGUAOgAxADIAcAB4
>> "%~1" echo ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOQAwADAAOwBsAGUAdAB0AGUAcgAt
>> "%~1" echo AHMAcABhAGMAaQBuAGcAOgAuADAAOABlAG0AOwB0AGUAeAB0AC0AdAByAGEAbgBz
>> "%~1" echo AGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AG0AYQByAGcAaQBuAC0AYgBv
>> "%~1" echo AHQAdABvAG0AOgAxADAAcAB4AH0AaAAxAHsAZgBvAG4AdAAtAHMAaQB6AGUAOgAz
>> "%~1" echo ADIAcAB4ADsAbABpAG4AZQAtAGgAZQBpAGcAaAB0ADoAMQAuADEAMgA7AG0AYQBy
>> "%~1" echo AGcAaQBuADoAMAAgADAAIAAxADAAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0
>> "%~1" echo ADoAOQAwADAAOwBjAG8AbABvAHIAOgAjADAAZgAxADcAMgBhAH0ALgBzAHUAYgB7
>> "%~1" echo AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAG0AdQB0AGUAZAApADsAbQBhAHgALQB3
>> "%~1" echo AGkAZAB0AGgAOgA2ADgAMABwAHgAOwBtAGEAcgBnAGkAbgA6ADAAfQAuAG0AZQB0
>> "%~1" echo AGEAewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAt
>> "%~1" echo AC0AbABpAG4AZQApADsAYQBsAGkAZwBuAC0AcwBlAGwAZgA6AHMAdABhAHIAdAA7
>> "%~1" echo AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9AC4AbQBlAHQAYQAtAHIAbwB3AHsAZABp
>> "%~1" echo AHMAcABsAGEAeQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABl
>> "%~1" echo AC0AYwBvAGwAdQBtAG4AcwA6ADEAMQA4AHAAeAAgAG0AaQBuAG0AYQB4ACgAMAAs
>> "%~1" echo ADEAZgByACkAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABz
>> "%~1" echo AG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AG0AaQBuAC0AaABl
>> "%~1" echo AGkAZwBoAHQAOgAzADgAcAB4AH0ALgBtAGUAdABhAC0AcgBvAHcAOgBsAGEAcwB0
>> "%~1" echo AC0AYwBoAGkAbABkAHsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADAAfQAu
>> "%~1" echo AG0AZQB0AGEALQByAG8AdwAgAHMAcABhAG4AewBiAGEAYwBrAGcAcgBvAHUAbgBk
>> "%~1" echo ADoAdgBhAHIAKAAtAC0AcwBvAGYAdAApADsAYwBvAGwAbwByADoAdgBhAHIAKAAt
>> "%~1" echo AC0AbQB1AHQAZQBkACkAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAA7
>> "%~1" echo AHAAYQBkAGQAaQBuAGcAOgA5AHAAeAAgADEAMgBwAHgAOwBiAG8AcgBkAGUAcgAt
>> "%~1" echo AHIAaQBnAGgAdAA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABp
>> "%~1" echo AG4AZQAyACkAfQAuAG0AZQB0AGEALQByAG8AdwAgAGIAewBwAGEAZABkAGkAbgBn
>> "%~1" echo ADoAOQBwAHgAIAAxADIAcAB4ADsAbQBpAG4ALQB3AGkAZAB0AGgAOgAwADsAbwB2
>> "%~1" echo AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcAaABlAHIAZQA7AHcAbwBy
>> "%~1" echo AGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8AcgBkAH0ALgBzAHQAYQBt
>> "%~1" echo AHAAewBkAGkAcwBwAGwAYQB5ADoAaQBuAGwAaQBuAGUALQBiAGwAbwBjAGsAOwBi
>> "%~1" echo AG8AcgBkAGUAcgA6ADIAcAB4ACAAcwBvAGwAaQBkACAAARd2AGEAcgAoAC0ALQB3
>> "%~1" echo AGEAcgBuACkAARN2AGEAcgAoAC0ALQBvAGsAKQABDzsAYwBvAGwAbwByADoAAJsH
>> "%~1" echo OwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAA7AHAAYQBkAGQAaQBuAGcA
>> "%~1" echo OgA0AHAAeAAgADgAcAB4ADsAYgBvAHIAZABlAHIALQByAGEAZABpAHUAcwA6ADQA
>> "%~1" echo cAB4ADsAdAByAGEAbgBzAGYAbwByAG0AOgByAG8AdABhAHQAZQAoAC0AMQBkAGUA
>> "%~1" echo ZwApAH0ALgBwAGEAcgB0AHkALQBnAHIAaQBkAHsAZABpAHMAcABsAGEAeQA6AGcA
>> "%~1" echo cgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4A
>> "%~1" echo cwA6ADEAZgByACAAMQBmAHIAOwBnAGEAcAA6ADEAOABwAHgAOwBtAGEAcgBnAGkA
>> "%~1" echo bgA6ADIANgBwAHgAIAAwAH0ALgBiAG8AeAB7AGIAbwByAGQAZQByADoAMQBwAHgA
>> "%~1" echo IABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBiAGEAYwBrAGcA
>> "%~1" echo cgBvAHUAbgBkADoAIwBmAGYAZgA7AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9AC4A
>> "%~1" echo YgBvAHgAIABoADIALAAuAHMAZQBjAHQAaQBvAG4AIABoADIAewBmAG8AbgB0AC0A
>> "%~1" echo cwBpAHoAZQA6ADEAMwBwAHgAOwB0AGUAeAB0AC0AdAByAGEAbgBzAGYAbwByAG0A
>> "%~1" echo OgB1AHAAcABlAHIAYwBhAHMAZQA7AGwAZQB0AHQAZQByAC0AcwBwAGEAYwBpAG4A
>> "%~1" echo ZwA6AC4AMAA4AGUAbQA7AGMAbwBsAG8AcgA6ACMAMwA0ADQAMAA1ADQAOwBtAGEA
>> "%~1" echo cgBnAGkAbgA6ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0A
>> "%~1" echo cwBvAGYAdAApADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAA
>> "%~1" echo cwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQApADsAcABhAGQAZABpAG4A
>> "%~1" echo ZwA6ADEAMABwAHgAIAAxADIAcAB4AH0ALgBiAG8AeAAtAGIAbwBkAHkAewBwAGEA
>> "%~1" echo ZABkAGkAbgBnADoAMQAzAHAAeAAgADEANABwAHgAfQAuAGIAaQBnAHsAZgBvAG4A
>> "%~1" echo dAAtAHMAaQB6AGUAOgAyADIAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoA
>> "%~1" echo OQAwADAAOwBtAGEAcgBnAGkAbgAtAGIAbwB0AHQAbwBtADoANgBwAHgAfQAuAG0A
>> "%~1" echo dQB0AGUAZAB7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAG0AdQB0AGUAZAApAH0A
>> "%~1" echo LgBjAGgAaQBwAHMAewBkAGkAcwBwAGwAYQB5ADoAZgBsAGUAeAA7AGYAbABlAHgA
>> "%~1" echo LQB3AHIAYQBwADoAdwByAGEAcAA7AGcAYQBwADoANwBwAHgAOwBtAGEAcgBnAGkA
>> "%~1" echo bgAtAHQAbwBwADoAMQAyAHAAeAB9AC4AYwBoAGkAcAB7AGIAbwByAGQAZQByADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBiAGEA
>> "%~1" echo YwBrAGcAcgBvAHUAbgBkADoAdgBhAHIAKAAtAC0AcwBvAGYAdAApADsAYgBvAHIA
>> "%~1" echo ZABlAHIALQByAGEAZABpAHUAcwA6ADkAOQA5AHAAeAA7AHAAYQBkAGQAaQBuAGcA
>> "%~1" echo OgA1AHAAeAAgADkAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOAAwADAA
>> "%~1" echo fQAuAHMAdQBtAG0AYQByAHkAewBkAGkAcwBwAGwAYQB5ADoAZwByAGkAZAA7AGcA
>> "%~1" echo cgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAcgBlAHAA
>> "%~1" echo ZQBhAHQAKAA0ACwAbQBpAG4AbQBhAHgAKAAwACwAMQBmAHIAKQApADsAYgBvAHIA
>> "%~1" echo ZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUA
>> "%~1" echo KQA7AG0AYQByAGcAaQBuADoAMgAwAHAAeAAgADAAIAAyADQAcAB4AH0ALgBzAHUA
>> "%~1" echo bQAtAGMAZQBsAGwAewBwAGEAZABkAGkAbgBnADoAMQAzAHAAeAAgADEANABwAHgA
>> "%~1" echo OwBiAG8AcgBkAGUAcgAtAHIAaQBnAGgAdAA6ADEAcAB4ACAAcwBvAGwAaQBkACAA
>> "%~1" echo dgBhAHIAKAAtAC0AbABpAG4AZQAyACkAOwBtAGkAbgAtAHcAaQBkAHQAaAA6ADAA
>> "%~1" echo fQAuAHMAdQBtAC0AYwBlAGwAbAA6AGwAYQBzAHQALQBjAGgAaQBsAGQAewBiAG8A
>> "%~1" echo cgBkAGUAcgAtAHIAaQBnAGgAdAA6ADAAfQAuAHMAdQBtAC0AYwBlAGwAbAAgAHMA
>> "%~1" echo cABhAG4AewBkAGkAcwBwAGwAYQB5ADoAYgBsAG8AYwBrADsAYwBvAGwAbwByADoA
>> "%~1" echo dgBhAHIAKAAtAC0AbQB1AHQAZQBkACkAOwBmAG8AbgB0AC0AcwBpAHoAZQA6ADEA
>> "%~1" echo MgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAA7AHQAZQB4AHQA
>> "%~1" echo LQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlAH0ALgBzAHUA
>> "%~1" echo bQAtAGMAZQBsAGwAIABiAHsAZABpAHMAcABsAGEAeQA6AGIAbABvAGMAawA7AGYA
>> "%~1" echo bwBuAHQALQBzAGkAegBlADoAMQA4AHAAeAA7AG0AYQByAGcAaQBuAC0AdABvAHAA
>> "%~1" echo OgA1AHAAeAA7AG8AdgBlAHIAZgBsAG8AdwAtAHcAcgBhAHAAOgBhAG4AeQB3AGgA
>> "%~1" echo ZQByAGUAOwB3AG8AcgBkAC0AYgByAGUAYQBrADoAYgByAGUAYQBrAC0AdwBvAHIA
>> "%~1" echo ZAB9AC4AcwBlAGMAdABpAG8AbgB7AG0AYQByAGcAaQBuAC0AdABvAHAAOgAyADIA
>> "%~1" echo cAB4AH0ALgBhAHUAZABpAHQALQB0AGEAYgBsAGUAewB3AGkAZAB0AGgAOgAxADAA
>> "%~1" echo MAAlADsAYgBvAHIAZABlAHIALQBjAG8AbABsAGEAcABzAGUAOgBjAG8AbABsAGEA
>> "%~1" echo cABzAGUAOwBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIA
>> "%~1" echo KAAtAC0AbABpAG4AZQApADsAdABhAGIAbABlAC0AbABhAHkAbwB1AHQAOgBmAGkA
>> "%~1" echo eABlAGQAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAaAB7AGIAYQBjAGsA
>> "%~1" echo ZwByAG8AdQBuAGQAOgAjAGYAMgBmADUAZgA5ADsAYwBvAGwAbwByADoAIwAzADQA
>> "%~1" echo NAAwADUANAA7AHQAZQB4AHQALQBhAGwAaQBnAG4AOgBsAGUAZgB0ADsAZgBvAG4A
>> "%~1" echo dAAtAHMAaQB6AGUAOgAxADIAcAB4ADsAdABlAHgAdAAtAHQAcgBhAG4AcwBmAG8A
>> "%~1" echo cgBtADoAdQBwAHAAZQByAGMAYQBzAGUAOwBsAGUAdAB0AGUAcgAtAHMAcABhAGMA
>> "%~1" echo aQBuAGcAOgAuADAANgBlAG0AOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoA
>> "%~1" echo MgBwAHgAIABzAG8AbABpAGQAIAAjADEAMQAxADgAMgA3ADsAcABhAGQAZABpAG4A
>> "%~1" echo ZwA6ADEAMABwAHgAIAAxADIAcAB4AH0ALgBhAHUAZABpAHQALQB0AGEAYgBsAGUA
>> "%~1" echo IAB0AGQAewBiAG8AcgBkAGUAcgAtAHQAbwBwADoAMQBwAHgAIABzAG8AbABpAGQA
>> "%~1" echo IAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AHAAYQBkAGQAaQBuAGcAOgAxADAA
>> "%~1" echo cAB4ACAAMQAyAHAAeAA7AHYAZQByAHQAaQBjAGEAbAAtAGEAbABpAGcAbgA6AHQA
>> "%~1" echo bwBwADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcAaABlAHIA
>> "%~1" echo ZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8AcgBkAH0A
>> "%~1" echo LgBhAHUAZABpAHQALQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwA
>> "%~1" echo ZAAoADEAKQB7AHcAaQBkAHQAaAA6ADIAMgAlADsAYwBvAGwAbwByADoAIwA0ADcA
>> "%~1" echo NQA0ADYANwA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwAH0ALgBhAHUA
>> "%~1" echo ZABpAHQALQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwAZAAoADIA
>> "%~1" echo KQB7AHcAaQBkAHQAaAA6ADQANAAlADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoA
>> "%~1" echo OAAwADAAOwBjAG8AbABvAHIAOgAjADEAMAAxADgAMgA4AH0ALgBhAHUAZABpAHQA
>> "%~1" echo LQB0AGEAYgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwAZAAoADMAKQB7AHcA
>> "%~1" echo aQBkAHQAaAA6ADMANAAlADsAYwBvAGwAbwByADoAIwA2ADYANwAwADgANQB9AC4A
>> "%~1" echo bgBvAHQAZQB7AGIAbwByAGQAZQByAC0AbABlAGYAdAA6ADQAcAB4ACAAcwBvAGwA
>> "%~1" echo aQBkACAAdgBhAHIAKAAtAC0AdwBhAHIAbgApADsAYgBhAGMAawBnAHIAbwB1AG4A
>> "%~1" echo ZAA6ACMAZgBmAGYAOABlAGIAOwBiAG8AcgBkAGUAcgAtAHQAbwBwADoAMQBwAHgA
>> "%~1" echo IABzAG8AbABpAGQAIAAjAGYAMwBkADEAOQBjADsAYgBvAHIAZABlAHIALQByAGkA
>> "%~1" echo ZwBoAHQAOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAZgAzAGQAMQA5AGMAOwBiAG8A
>> "%~1" echo cgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABzAG8AbABpAGQAIAAjAGYA
>> "%~1" echo MwBkADEAOQBjADsAcABhAGQAZABpAG4AZwA6ADEAMwBwAHgAIAAxADQAcAB4ADsA
>> "%~1" echo bQBhAHIAZwBpAG4ALQB0AG8AcAA6ADEAOABwAHgAfQAuAHIAYQB3ACAAZABlAHQA
>> "%~1" echo YQBpAGwAcwB7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEA
>> "%~1" echo cgAoAC0ALQBsAGkAbgBlACkAOwBtAGEAcgBnAGkAbgA6ADEAMABwAHgAIAAwADsA
>> "%~1" echo YgBhAGMAawBnAHIAbwB1AG4AZAA6ACMAZgBmAGYAfQAuAHIAYQB3ACAAcwB1AG0A
>> "%~1" echo bQBhAHIAeQB7AGMAdQByAHMAbwByADoAcABvAGkAbgB0AGUAcgA7AGIAYQBjAGsA
>> "%~1" echo ZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBwAGEAZABkAGkA
>> "%~1" echo bgBnADoAMQAwAHAAeAAgADEAMgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQA
>> "%~1" echo OgA5ADAAMAB9AC4AcgBhAHcAIABwAHIAZQB7AG0AYQByAGcAaQBuADoAMAA7AG0A
>> "%~1" echo YQB4AC0AaABlAGkAZwBoAHQAOgA0ADIAMABwAHgAOwBvAHYAZQByAGYAbABvAHcA
>> "%~1" echo OgBhAHUAdABvADsAdwBoAGkAdABlAC0AcwBwAGEAYwBlADoAcAByAGUALQB3AHIA
>> "%~1" echo YQBwADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEAcAA6AGEAbgB5AHcAaABlAHIA
>> "%~1" echo ZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIAZQBhAGsALQB3AG8AcgBkADsA
>> "%~1" echo YwBvAGwAbwByADoAIwA0ADcANQA0ADYANwA7AHAAYQBkAGQAaQBuAGcAOgAxADIA
>> "%~1" echo cAB4ADsAZgBvAG4AdAA6ADEAMgBwAHgALwAxAC4ANQAgAEMAbwBuAHMAbwBsAGEA
>> "%~1" echo cwAsACIATQBpAGMAcgBvAHMAbwBmAHQAIABZAGEASABlAGkAIgAsAG0AbwBuAG8A
>> "%~1" echo cwBwAGEAYwBlAH0ALgBmAG8AbwB0AHsAZABpAHMAcABsAGEAeQA6AGcAcgBpAGQA
>> "%~1" echo OwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEA
>> "%~1" echo ZgByACAAYQB1AHQAbwA7AGcAYQBwADoAMgAwAHAAeAA7AGEAbABpAGcAbgAtAGkA
>> "%~1" echo dABlAG0AcwA6AGUAbgBkADsAbQBhAHIAZwBpAG4ALQB0AG8AcAA6ADIAOABwAHgA
>> "%~1" echo OwBiAG8AcgBkAGUAcgAtAHQAbwBwADoAMgBwAHgAIABzAG8AbABpAGQAIAAjADEA
>> "%~1" echo MQAxADgAMgA3ADsAcABhAGQAZABpAG4AZwAtAHQAbwBwADoAMQA2AHAAeAB9AC4A
>> "%~1" echo ZgBvAG8AdAAgAGIAewBmAG8AbgB0AC0AcwBpAHoAZQA6ADEAMgBwAHgAOwB0AGUA
>> "%~1" echo eAB0AC0AdAByAGEAbgBzAGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AGwA
>> "%~1" echo ZQB0AHQAZQByAC0AcwBwAGEAYwBpAG4AZwA6AC4AMAA4AGUAbQB9AC4AdABvAHQA
>> "%~1" echo YQBsAHsAbQBpAG4ALQB3AGkAZAB0AGgAOgAyADUAMABwAHgAOwBiAG8AcgBkAGUA
>> "%~1" echo cgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQApAH0A
>> "%~1" echo LgB0AG8AdABhAGwAIABkAGkAdgB7AGQAaQBzAHAAbABhAHkAOgBnAHIAaQBkADsA
>> "%~1" echo ZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAxAGYA
>> "%~1" echo cgAgAGEAdQB0AG8AOwBwAGEAZABkAGkAbgBnADoAOQBwAHgAIAAxADIAcAB4ADsA
>> "%~1" echo YgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwAaQBkACAA
>> "%~1" echo dgBhAHIAKAAtAC0AbABpAG4AZQAyACkAfQAuAHQAbwB0AGEAbAAgAGQAaQB2ADoA
>> "%~1" echo bABhAHMAdAAtAGMAaABpAGwAZAB7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0A
>> "%~1" echo OgAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAtAHMAbwBmAHQA
>> "%~1" echo KQA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwAH0AQABtAGUAZABpAGEA
>> "%~1" echo KABtAGEAeAAtAHcAaQBkAHQAaAA6ADgANgAwAHAAeAApAHsALgBkAG8AYwAtAGgA
>> "%~1" echo ZQBhAGQALAAuAHAAYQByAHQAeQAtAGcAcgBpAGQALAAuAHMAdQBtAG0AYQByAHkA
>> "%~1" echo ewBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEA
>> "%~1" echo ZgByAH0ALgBwAGEAZAB7AHAAYQBkAGQAaQBuAGcAOgAyADQAcAB4ACAAMQA4AHAA
>> "%~1" echo eAB9AC4AcwBoAGUAZQB0ACwALgBhAGMAdABpAG8AbgBzAHsAdwBpAGQAdABoADoA
>> "%~1" echo YwBhAGwAYwAoADEAMAAwACUAIAAtACAAMQA4AHAAeAApAH0ALgBzAHUAbQBtAGEA
>> "%~1" echo cgB5AHsAZABpAHMAcABsAGEAeQA6AGIAbABvAGMAawB9AC4AcwB1AG0ALQBjAGUA
>> "%~1" echo bABsAHsAYgBvAHIAZABlAHIALQByAGkAZwBoAHQAOgAwADsAYgBvAHIAZABlAHIA
>> "%~1" echo LQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0A
>> "%~1" echo bABpAG4AZQAyACkAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQB7AHQAYQBiAGwA
>> "%~1" echo ZQAtAGwAYQB5AG8AdQB0ADoAYQB1AHQAbwB9AC4AYQB1AGQAaQB0AC0AdABhAGIA
>> "%~1" echo bABlACAAdABoADoAbgB0AGgALQBjAGgAaQBsAGQAKAAzACkALAAuAGEAdQBkAGkA
>> "%~1" echo dAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkAbABkACgAMwApAHsA
>> "%~1" echo ZABpAHMAcABsAGEAeQA6AG4AbwBuAGUAfQAuAGYAbwBvAHQAewBnAHIAaQBkAC0A
>> "%~1" echo dABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6ADEAZgByAH0ALgB0AG8A
>> "%~1" echo dABhAGwAewBtAGkAbgAtAHcAaQBkAHQAaAA6ADAAfQB9AEAAbQBlAGQAaQBhACgA
>> "%~1" echo bQBhAHgALQB3AGkAZAB0AGgAOgA1ADIAMABwAHgAKQB7AC4AbQBlAHQAYQAtAHIA
>> "%~1" echo bwB3AHsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMA
>> "%~1" echo OgAxADAANQBwAHgAIABtAGkAbgBtAGEAeAAoADAALAAxAGYAcgApAH0AaAAxAHsA
>> "%~1" echo ZgBvAG4AdAAtAHMAaQB6AGUAOgAyADgAcAB4AH0ALgBhAGMAdABpAG8AbgBzAHsA
>> "%~1" echo agB1AHMAdABpAGYAeQAtAGMAbwBuAHQAZQBuAHQAOgBmAGwAZQB4AC0AcwB0AGEA
>> "%~1" echo cgB0ADsAbwB2AGUAcgBmAGwAbwB3ADoAYQB1AHQAbwB9AH0AQABtAGUAZABpAGEA
>> "%~1" echo IABwAHIAaQBuAHQAewBiAG8AZAB5AHsAYgBhAGMAawBnAHIAbwB1AG4AZAA6ACMA
>> "%~1" echo ZgBmAGYAfQAuAGEAYwB0AGkAbwBuAHMAewBkAGkAcwBwAGwAYQB5ADoAbgBvAG4A
>> "%~1" echo ZQB9AC4AcwBoAGUAZQB0AHsAdwBpAGQAdABoADoAYQB1AHQAbwA7AG0AYQByAGcA
>> "%~1" echo aQBuADoAMAA7AGIAbwByAGQAZQByADoAMAA7AGIAbwB4AC0AcwBoAGEAZABvAHcA
>> "%~1" echo OgBuAG8AbgBlAH0ALgBwAGEAZAB7AHAAYQBkAGQAaQBuAGcAOgAwAH0ALgByAGEA
>> "%~1" echo dwAgAHAAcgBlAHsAbQBhAHgALQBoAGUAaQBnAGgAdAA6AG4AbwBuAGUAfQAuAGIA
>> "%~1" echo bwB4ACwALgBhAHUAZABpAHQALQB0AGEAYgBsAGUALAAuAHIAYQB3ACAAZABlAHQA
>> "%~1" echo YQBpAGwAcwB7AGIAcgBlAGEAawAtAGkAbgBzAGkAZABlADoAYQB2AG8AaQBkAH0A
>> "%~1" echo QABwAGEAZwBlAHsAcwBpAHoAZQA6AEEANAA7AG0AYQByAGcAaQBuADoAMQAzAG0A
>> "%~1" echo bQB9AH0AASs8AC8AcwB0AHkAbABlAD4APAAvAGgAZQBhAGQAPgA8AGIAbwBkAHkA
>> "%~1" echo PgAAgZk8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBhAGMAdABpAG8AbgBzACIAPgA8
>> "%~1" echo AGIAdQB0AHQAbwBuACAAYwBsAGEAcwBzAD0AIgBiAHQAbgAgAHAAcgBpAG0AYQBy
>> "%~1" echo AHkAIgAgAG8AbgBjAGwAaQBjAGsAPQAiAHcAaQBuAGQAbwB3AC4AcAByAGkAbgB0
>> "%~1" echo ACgAKQAiAD4AU2JwUyAALwAgAN1PWFsgAFAARABGADwALwBiAHUAdAB0AG8AbgA+
>> "%~1" echo ADwAYgB1AHQAdABvAG4AIABjAGwAYQBzAHMAPQAiAGIAdABuACIAIABvAG4AYwBs
>> "%~1" echo AGkAYwBrAD0AIgBkAG8AYwB1AG0AZQBuAHQALgBxAHUAZQByAHkAUwBlAGwAZQBj
>> "%~1" echo AHQAbwByAEEAbABsACgAJwBkAGUAdABhAGkAbABzACcAKQAuAGYAbwByAEUAYQBj
>> "%~1" echo AGgAKABkAD0APgBkAC4AbwBwAGUAbgA9AHQAcgB1AGUAKQAiAD4AVVwAX0SWVV88
>> "%~1" echo AC8AYgB1AHQAdABvAG4APgA8AC8AZABpAHYAPgABSzwAbQBhAGkAbgAgAGMAbABh
>> "%~1" echo AHMAcwA9ACIAcwBoAGUAZQB0ACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBw
>> "%~1" echo AGEAZAAiAD4AAIHBPABoAGUAYQBkAGUAcgAgAGMAbABhAHMAcwA9ACIAZABvAGMA
>> "%~1" echo LQBoAGUAYQBkACIAPgA8AGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo awBpAGMAawBlAHIAIgA+AFEAdQBlAHMAdAAgAEEARABCACAAVABvAG8AbABzACAA
>> "%~1" echo LwAgAFIAZQBhAGQALQBvAG4AbAB5ACAAZQB4AHAAbwByAHQAPAAvAGQAaQB2AD4A
>> "%~1" echo PABoADEAPgBRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mhW6GLpWJKVDwALwBoADEA
>> "%~1" echo PgA8AHAAIABjAGwAYQBzAHMAPQAiAHMAdQBiACIAPgD6V45ObFEAXyAAQQBEAEIA
>> "%~1" echo IADqU/uLfVTkTh91EGIM/yh1jk50ZQZ0IABRAHUAZQBzAHQAIAA0WT5mq479TgEw
>> "%~1" echo +3zffgEwZVC3XgEw5V2CUy8AIWjGUb9+In0BMAVTDk79gJtSAjD8W/pRQW0Leg1O
>> "%~1" echo mVFlUb6Lbn8M/w1O7k85Zb6LB1kCMFxPBYBLbdWLvosHWUhyLGca/1EAdQBlAHMA
>> "%~1" echo dAAgADMAAjA8AC8AcAA+ADwALwBkAGkAdgA+AAF9PABhAHMAaQBkAGUAIABjAGwA
>> "%~1" echo YQBzAHMAPQAiAG0AZQB0AGEAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAG0A
>> "%~1" echo ZQB0AGEALQByAG8AdwAiAD4APABzAHAAYQBuAD4ApWJKVBZ/91M8AC8AcwBwAGEA
>> "%~1" echo bgA+ADwAYgA+AAFpPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBsAGEA
>> "%~1" echo cwBzAD0AIgBtAGUAdABhAC0AcgBvAHcAIgA+ADwAcwBwAGEAbgA+AB91EGL2ZfSV
>> "%~1" echo PAAvAHMAcABhAG4APgA8AGIAPgABgIs8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABp
>> "%~1" echo AHYAIABjAGwAYQBzAHMAPQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABzAHAAYQBu
>> "%~1" echo AD4AkJbBead+K1I8AC8AcwBwAGEAbgA+ADwAYgA+ADwAaQAgAGMAbABhAHMAcwA9
>> "%~1" echo ACIAcwB0AGEAbQBwACIAPgABgIM8AC8AaQA+ADwALwBiAD4APAAvAGQAaQB2AD4A
>> "%~1" echo PABkAGkAdgAgAGMAbABhAHMAcwA9ACIAbQBlAHQAYQAtAHIAbwB3ACIAPgA8AHMA
>> "%~1" echo cABhAG4APgBBAEQAQgAgAGVnkG48AC8AcwBwAGEAbgA+ADwAYgAgAHQAaQB0AGwA
>> "%~1" echo ZQA9ACIAAQUiAD4AADc8AC8AYgA+ADwALwBkAGkAdgA+ADwALwBhAHMAaQBkAGUA
>> "%~1" echo PgA8AC8AaABlAGEAZABlAHIAPgAAgL88AHMAZQBjAHQAaQBvAG4AIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAHAAYQByAHQAeQAtAGcAcgBpAGQAIgA+ADwAZABpAHYAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAGIAbwB4ACIAPgA8AGgAMgA+AL6LB1k8AC8AaAAyAD4APABkAGkAdgAg
>> "%~1" echo AGMAbABhAHMAcwA9ACIAYgBvAHgALQBiAG8AZAB5ACIAPgA8AGQAaQB2ACAAYwBs
>> "%~1" echo AGEAcwBzAD0AIgBiAGkAZwAiAD4AATM8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBs
>> "%~1" echo AGEAcwBzAD0AIgBtAHUAdABlAGQAIgA+AABnPAAvAGQAaQB2AD4APABkAGkAdgAg
>> "%~1" echo AGMAbABhAHMAcwA9ACIAYwBoAGkAcABzACIAPgA8AHMAcABhAG4AIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAGMAaABpAHAAIgA+AFMAZQByAGkAYQBsACAAADU8AC8AcwBwAGEAbgA+
>> "%~1" echo ADwAcwBwAGEAbgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4AAA8gAC8AIABT
>> "%~1" echo AEQASwAgAAAzPAAvAHMAcABhAG4APgA8AC8AZABpAHYAPgA8AC8AZABpAHYAPgA8
>> "%~1" echo AC8AZABpAHYAPgAAgIs8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBiAG8AeAAiAD4A
>> "%~1" echo PABoADIAPgDHkcaWVntldTwALwBoADIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0A
>> "%~1" echo IgBiAG8AeAAtAGIAbwBkAHkAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGIA
>> "%~1" echo aQBnACIAPgABC8F5CWeMW3RlSHIBCwZSq06JW2hRSHIBM91PWXWMW3RlwXkJZ8GL
>> "%~1" echo bmMM/wKQCFQsZzpnWXVjaBv/DU6BifR2pWNsUQBfBlKrTgIwAX3yXW6QPYWPXhdS
>> "%~1" echo 91MBMEBc31dRfzBXQFcBME0AQQBDAC8AQgBTAFMASQBEAAEwZgBpAG4AZwBlAHIA
>> "%~1" echo cAByAGkAbgB0AAEwcwBlAHMAcwBpAG8AbgAgAEl7T2UfYVdbtWsb//ONx48gAGwA
>> "%~1" echo bwBnAGMAYQB0ACAARJZVXwIwAYFVPAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABh
>> "%~1" echo AHMAcwA9ACIAYwBoAGkAcABzACIAPgA8AHMAcABhAG4AIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AGMAaABpAHAAIgA+AE4AbwAgAEEARABCACAAdwByAGkAdABlADwALwBzAHAAYQBu
>> "%~1" echo AD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBwACIAPgBIAFQATQBM
>> "%~1" echo AC8AUABEAEYAIAByAGUAYQBkAHkAPAAvAHMAcABhAG4APgA8AHMAcABhAG4AIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AFEAdQBlAHMAdAAgADMAIABuAG8AdABl
>> "%~1" echo AGQAPAAvAHMAcABhAG4APgA8AC8AZABpAHYAPgA8AC8AZABpAHYAPgA8AC8AZABp
>> "%~1" echo AHYAPgA8AC8AcwBlAGMAdABpAG8AbgA+AACAjTwAcwBlAGMAdABpAG8AbgAgAGMA
>> "%~1" echo bABhAHMAcwA9ACIAcwB1AG0AbQBhAHIAeQAiAD4APABkAGkAdgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAcwB1AG0ALQBjAGUAbABsACIAPgA8AHMAcABhAG4APgA1dc+RIAAvACAA
>> "%~1" echo KW6mXjwALwBzAHAAYQBuAD4APABiAD4AAWU8AC8AYgA+ADwALwBkAGkAdgA+ADwA
>> "%~1" echo ZABpAHYAIABjAGwAYQBzAHMAPQAiAHMAdQBtAC0AYwBlAGwAbAAiAD4APABzAHAA
>> "%~1" echo YQBuAD4APmY6eTwALwBzAHAAYQBuAD4APABiAD4AAWU8AC8AYgA+ADwALwBkAGkA
>> "%~1" echo dgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHMAdQBtAC0AYwBlAGwAbAAiAD4A
>> "%~1" echo PABzAHAAYQBuAD4AWFuoUDwALwBzAHAAYQBuAD4APABiAD4AAWU8AC8AYgA+ADwA
>> "%~1" echo LwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHMAdQBtAC0AYwBlAGwA
>> "%~1" echo bAAiAD4APABzAHAAYQBuAD4AIWjGUTwALwBzAHAAYQBuAD4APABiAD4AASk8AC8A
>> "%~1" echo YgA+ADwALwBkAGkAdgA+ADwALwBzAGUAYwB0AGkAbwBuAD4AAAm+iwdZq479TgFB
>> "%~1" echo cwBlAHIAaQBhAGwAfACPXhdS91N8AGEAZABiACAAZABlAHYAaQBjAGUAcwAgAC8A
>> "%~1" echo IABnAGUAdABwAHIAbwBwAAFDZABlAHYAaQBjAGUATABpAG4AZQB8AEEARABCACAA
>> "%~1" echo vosHWUyIfABhAGQAYgAgAGQAZQB2AGkAYwBlAHMAIAAtAGwAAU9tAGEAbgB1AGYA
>> "%~1" echo YQBjAHQAdQByAGUAcgB8AIJTRlV8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBtAGEA
>> "%~1" echo bgB1AGYAYQBjAHQAdQByAGUAcgABM2IAcgBhAG4AZAB8AMFUTHJ8AHIAbwAuAHAA
>> "%~1" echo cgBvAGQAdQBjAHQALgBiAHIAYQBuAGQAATNtAG8AZABlAGwAfACLV/dTfAByAG8A
>> "%~1" echo LgBwAHIAbwBkAHUAYwB0AC4AbQBvAGQAZQBsAAE5cAByAG8AZAB1AGMAdAB8AKdO
>> "%~1" echo wVTjTvdTfAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AbgBhAG0AZQABO2QAZQB2AGkA
>> "%~1" echo YwBlAHwAvosHWeNO91N8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBkAGUAdgBpAGMA
>> "%~1" echo ZQABM2IAbwBhAHIAZAB8AH9np358AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBiAG8A
>> "%~1" echo YQByAGQAASlzAG8AYwB8AFMAbwBDAHwAcgBvAC4AcwBvAGMALgBtAG8AZABlAGwA
>> "%~1" echo ADVhAGIAaQB8AEEAQgBJAHwAcgBvAC4AcAByAG8AZAB1AGMAdAAuAGMAcAB1AC4A
>> "%~1" echo YQBiAGkAAAv7fN9+Dk6EZ/peAS9hAG4AZAByAG8AaQBkAHwAQQBuAGQAcgBvAGkA
>> "%~1" echo ZAB8AGcAZQB0AHAAcgBvAHAAAB9zAGQAawB8AFMARABLAHwAZwBlAHQAcAByAG8A
>> "%~1" echo cAAAOXMAZQBjAHUAcgBpAHQAeQBQAGEAdABjAGgAfAD7fN9+iVtoUWWIAU58AGcA
>> "%~1" echo ZQB0AHAAcgBvAHAAAT92AGUAbgBkAG8AcgBQAGEAdABjAGgAfABWAGUAbgBkAG8A
>> "%~1" echo cgAgAIlbaFFliAFOfABnAGUAdABwAHIAbwBwAAExYgB1AGkAbABkAEkAZAB8AEIA
>> "%~1" echo dQBpAGwAZAAgAEkARAB8AGcAZQB0AHAAcgBvAHAAAEliAHUAaQBsAGQASQBuAGMA
>> "%~1" echo cgBlAG0AZQBuAHQAYQBsAHwASQBuAGMAcgBlAG0AZQBuAHQAYQBsAHwAZwBlAHQA
>> "%~1" echo cAByAG8AcAAANWIAdQBpAGwAZABCAHIAYQBuAGMAaAB8AEIAcgBhAG4AYwBoAHwA
>> "%~1" echo ZwBlAHQAcAByAG8AcAAAP2YAaQBuAGcAZQByAHAAcgBpAG4AdAB8AEYAaQBuAGcA
>> "%~1" echo ZQByAHAAcgBpAG4AdAB8AGcAZQB0AHAAcgBvAHAAAC1rAGUAcgBuAGUAbAB8AEsA
>> "%~1" echo ZQByAG4AZQBsAHwAdQBuAGEAbQBlACAALQBhAAEhPmY6eSAALwAgADV1kG4gAC8A
>> "%~1" echo IABRf9x+IAAvACAA7XABOWQAaQBzAHAAbABhAHkAfAA+Zjp5WGSBiXwAZAB1AG0A
>> "%~1" echo cABzAHkAcwAgAGQAaQBzAHAAbABhAHkAATVwAGEAbgBlAGwAfABil39nv34ifXwA
>> "%~1" echo ZAB1AG0AcABzAHkAcwAgAGQAaQBzAHAAbABhAHkAAT9iAGEAdAB0AGUAcgB5AEwA
>> "%~1" echo ZQB2AGUAbAB8ADV1z5F8AGQAdQBtAHAAcwB5AHMAIABiAGEAdAB0AGUAcgB5AAFB
>> "%~1" echo YgBhAHQAdABlAHIAeQBUAGUAbQBwAHwANXVgbClupl58AGQAdQBtAHAAcwB5AHMA
>> "%~1" echo IABiAGEAdAB0AGUAcgB5AAFFYgBhAHQAdABlAHIAeQBIAGUAYQBsAHQAaAB8ADV1
>> "%~1" echo YGxlULdefABkAHUAbQBwAHMAeQBzACAAYgBhAHQAdABlAHIAeQABPXAAbwB3AGUA
>> "%~1" echo cgBTAG8AdQByAGMAZQB8AJtPNXV8AGQAdQBtAHAAcwB5AHMAIABiAGEAdAB0AGUA
>> "%~1" echo cgB5AAE9dwBhAGsAZQBmAHUAbABuAGUAcwBzAHwAJFWSkbZyAWB8AGQAdQBtAHAA
>> "%~1" echo cwB5AHMAIABwAG8AdwBlAHIAAUlzAHQAYQB5AE8AbgB8AN1PAWMkVZKRfABzAGUA
>> "%~1" echo dAB0AGkAbgBnAHMAIAAvACAAZAB1AG0AcABzAHkAcwAgAHAAbwB3AGUAcgABSXAA
>> "%~1" echo cgBvAHgAaQBtAGkAdAB5AHwApWPRj7ZyAWB8AGQAdQBtAHAAcwB5AHMAIABzAGUA
>> "%~1" echo bgBzAG8AcgBzAGUAcgB2AGkAYwBlAAFFdABoAGUAcgBtAGEAbAB8AO1wtnIBYHwA
>> "%~1" echo ZAB1AG0AcABzAHkAcwAgAHQAaABlAHIAbQBhAGwAcwBlAHIAdgBpAGMAZQABJ3UA
>> "%~1" echo cwBiAHwAVQBTAEIAfABkAHUAbQBwAHMAeQBzACAAdQBzAGIAAEN3AGkAZgBpAHwA
>> "%~1" echo VwBpAC0ARgBpAHwAZAB1AG0AcABzAHkAcwAgAHcAaQBmAGkAIAAvACAAaQBwACAA
>> "%~1" echo YQBkAGQAcgABTWIAbAB1AGUAdABvAG8AdABoAHwA3YRZcnwAZAB1AG0AcABzAHkA
>> "%~1" echo cwAgAGIAbAB1AGUAdABvAG8AdABoAF8AbQBhAG4AYQBnAGUAcgABZWMAYQBtAGUA
>> "%~1" echo cgBhAHwA+HY6Zy8AIE8fYWhWfABkAHUAbQBwAHMAeQBzACAAbQBlAGQAaQBhAC4A
>> "%~1" echo YwBhAG0AZQByAGEAIAAvACAAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQABIXMA
>> "%~1" echo dABvAHIAYQBnAGUAfABYW6hQfABkAGYAIAAtAGgAAS9tAGUAbQBvAHIAeQB8AIVR
>> "%~1" echo WFt8AC8AcAByAG8AYwAvAG0AZQBtAGkAbgBmAG8AAStjAHAAdQB8AEMAUABVAHwA
>> "%~1" echo LwBwAHIAbwBjAC8AYwBwAHUAaQBuAGYAbwAAM0YAYQBjAHQAbwByAHkAIAAvACAA
>> "%~1" echo QwBhAGwAaQBiAHIAYQB0AGkAbwBuACAAQ1FwZW5jAV9mAGEAYwB0AG8AcgB5AEQA
>> "%~1" echo ZQB2AGkAYwBlAHwARABlAHYAaQBjAGUAVAB5AHAAZQB8AHMAZQBuAHMAbwByAHMA
>> "%~1" echo ZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAFtmAGEAYwB0AG8AcgB5AEIA
>> "%~1" echo dQBpAGwAZAB8AEIAdQBpAGwAZABUAHkAcABlAHwAcwBlAG4AcwBvAHIAcwBlAHIA
>> "%~1" echo dgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAaWYAYQBjAHQAbwByAHkAVABpAG0A
>> "%~1" echo ZQB8AEYAYQBjAHQAbwByAHkAIABUAGkAbQBlAHMAdABhAG0AcAB8AHMAZQBuAHMA
>> "%~1" echo bwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAGVmAGEAYwB0AG8A
>> "%~1" echo cgB5AEwAbwBjAGEAdABpAG8AbgB8AGwAbwBjAGEAdABpAG8AbgBfAGkAZAB8AHMA
>> "%~1" echo ZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAGFmAGEA
>> "%~1" echo YwB0AG8AcgB5AFMAdABhAHQAaQBvAG4AfABzAHQAYQB0AGkAbwBuAF8AaQBkAHwA
>> "%~1" echo cwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAbWYA
>> "%~1" echo YQBjAHQAbwByAHkAUwB0AGEAdABpAG8AbgBUAHkAcABlAHwAcwB0AGEAdABpAG8A
>> "%~1" echo bgBfAHQAeQBwAGUAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQA
>> "%~1" echo YQBkAGEAdABhAABdZgBhAGMAdABvAHIAeQBUAGUAcwB0AHwAYwBhAGwAXwB0AGUA
>> "%~1" echo cwB0AF8AaQBkAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEA
>> "%~1" echo ZABhAHQAYQAAZWYAYQBjAHQAbwByAHkATwBwAGUAcgBhAHQAbwByAHwAbwBwAGUA
>> "%~1" echo cgBhAHQAbwByAF8AaQBkAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0A
>> "%~1" echo ZQB0AGEAZABhAHQAYQAAdWYAYQBjAHQAbwByAHkAQwBhAGwAaQBiAHIAYQB0AGkA
>> "%~1" echo bwBuAHwAYwBhAGwAaQBiAHIAYQB0AGkAbwBuAF8AdAB5AHAAZQB8AHMAZQBuAHMA
>> "%~1" echo bwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAHdvAG4AbABpAG4A
>> "%~1" echo ZQBDAGEAbABpAGIAcgBhAHQAaQBvAG4AfABPAG4AbABpAG4AZQAgAGMAYQBsAGkA
>> "%~1" echo YgByAGEAdABpAG8AbgB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUA
>> "%~1" echo dABhAGQAYQB0AGEAAIF9PABkAGkAdgAgAGMAbABhAHMAcwA9ACIAbgBvAHQAZQAi
>> "%~1" echo AD4APABiAD4AqGOtZbmPTHUa/zwALwBiAD4A71PlTrCLVV++iwdZz2UBMGx49k42
>> "%~1" echo lrVrATAhaMZRsItVX4xU5V2CU0tt1Yu/fiJ9DP+LT4JZIABRAHUAZQBzAHQAIAAz
>> "%~1" echo ACAALwAgAEUAdQByAGUAawBhACAALwAgAFAAVgBUACAALwAgAEYAYQBjAHQAbwBy
>> "%~1" echo AHkAIAAvACAATwBuAGwAaQBuAGUAIABjAGEAbABpAGIAcgBhAHQAaQBvAG4AAjAN
>> "%~1" echo Tv2AimIgAGwAbwBjAGEAdABpAG8AbgBfAGkAZAABMHMAdABhAHQAaQBvAG4AXwBp
>> "%~1" echo AGQAATBzAHQAYQB0AGkAbwBuAF8AdAB5AHAAZQAgAO9TYJf7f9GLEGL9VrZbATDO
>> "%~1" echo VwJeFmJ3UVNP5V2CUxv/VwBpAC0ARgBpACAA/Va2WwF4X04NTi9m+lGnTjBXAjA8
>> "%~1" echo AC8AZABpAHYAPgABDQVTDk77fN9+/YCbUgE7cABhAGMAawBhAGcAZQBzAHwABVNw
>> "%~1" echo Zc+RfABwAG0AIABsAGkAcwB0ACAAcABhAGMAawBhAGcAZQBzAAFJZgBlAGEAdAB1
>> "%~1" echo AHIAZQBzAHwARgBlAGEAdAB1AHIAZQAgAHBlz5F8AHAAbQAgAGwAaQBzAHQAIABm
>> "%~1" echo AGUAYQB0AHUAcgBlAHMAAXN2AGQAfABWAGkAcgB0AHUAYQBsACAARABlAHMAawB0
>> "%~1" echo AG8AcAB8AGQAdQBtAHAAcwB5AHMAIABwAGEAYwBrAGEAZwBlACAAVgBpAHIAdAB1
>> "%~1" echo AGEAbABEAGUAcwBrAHQAbwBwAC4AQQBuAGQAcgBvAGkAZAAAPXcAYQByAG4AaQBu
>> "%~1" echo AGcAcwB8AMeRxpZmi0pUfABlAHgAcABvAHIAdAAgAGMAbwBsAGwAZQBjAHQAbwBy
>> "%~1" echo AAGB3zwAZgBvAG8AdABlAHIAIABjAGwAYQBzAHMAPQAiAGYAbwBvAHQAIgA+ADwA
>> "%~1" echo ZABpAHYAPgA8AGIAPgBRAHUAZQBzAHQAIABBAEQAQgAgAFQAbwBvAGwAcwAgAGIA
>> "%~1" echo eQAgAGQAdwBnAHgAMQAzADMANwA8AC8AYgA+ADwAYgByAD4APABzAHAAYQBuACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBtAHUAdABlAGQAIgA+AFAAdQBiAGwAaQBjACAAcgBlAHAA
>> "%~1" echo bwAgAHMAYQBtAHAAbABlACAAbQB1AHMAdAAgAHUAcwBlACAAcwBoAGEAcgBlAC0A
>> "%~1" echo cwBhAGYAZQAgAGUAeABwAG8AcgB0AC4AIABQAHIAaQB2AGEAdABlACAAZgB1AGwA
>> "%~1" echo bAAgAGUAeABwAG8AcgB0ACAAaQBzACAAZgBvAHIAIABsAG8AYwBhAGwAIABlAHYA
>> "%~1" echo aQBkAGUAbgBjAGUAIABvAG4AbAB5AC4APAAvAHMAcABhAG4APgA8AC8AZABpAHYA
>> "%~1" echo PgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgB0AG8AdABhAGwAIgA+ADwAZABpAHYA
>> "%~1" echo PgA8AHMAcABhAG4APgBQAGEAYwBrAGEAZwBlAHMAPAAvAHMAcABhAG4APgA8AGIA
>> "%~1" echo PgABTzwALwBiAD4APAAvAGQAaQB2AD4APABkAGkAdgA+ADwAcwBwAGEAbgA+AEYA
>> "%~1" echo ZQBhAHQAdQByAGUAcwA8AC8AcwBwAGEAbgA+ADwAYgA+AABLPAAvAGIAPgA8AC8A
>> "%~1" echo ZABpAHYAPgA8AGQAaQB2AD4APABzAHAAYQBuAD4AUwB0AGEAdAB1AHMAPAAvAHMA
>> "%~1" echo cABhAG4APgA8AGIAPgAAD1AAcgBpAHYAYQB0AGUAABVTAGgAYQByAGUALQBzAGEA
>> "%~1" echo ZgBlAAEzPAAvAGIAPgA8AC8AZABpAHYAPgA8AC8AZABpAHYAPgA8AC8AZgBvAG8A
>> "%~1" echo dABlAHIAPgAANzwALwBkAGkAdgA+ADwALwBtAGEAaQBuAD4APAAvAGIAbwBkAHkA
>> "%~1" echo PgA8AC8AaAB0AG0AbAA+AAA7PABzAGUAYwB0AGkAbwBuACAAYwBsAGEAcwBzAD0A
>> "%~1" echo IgBzAGUAYwB0AGkAbwBuACIAPgA8AGgAMgA+AACAwzwALwBoADIAPgA8AHQAYQBi
>> "%~1" echo AGwAZQAgAGMAbABhAHMAcwA9ACIAYQB1AGQAaQB0AC0AdABhAGIAbABlACIAPgA8
>> "%~1" echo AHQAaABlAGEAZAA+ADwAdAByAD4APAB0AGgAPgBXW7VrPAAvAHQAaAA+ADwAdABo
>> "%~1" echo AD4APFA8AC8AdABoAD4APAB0AGgAPgDBi25jZWeQbjwALwB0AGgAPgA8AC8AdABy
>> "%~1" echo AD4APAAvAHQAaABlAGEAZAA+ADwAdABiAG8AZAB5AD4AAQdBAEQAQgAAETwAdABy
>> "%~1" echo AD4APAB0AGQAPgAAEzwALwB0AGQAPgA8AHQAZAA+AAAVPAAvAHQAZAA+ADwALwB0
>> "%~1" echo AHIAPgAANTwALwB0AGIAbwBkAHkAPgA8AC8AdABhAGIAbABlAD4APAAvAHMAZQBj
>> "%~1" echo AHQAaQBvAG4APgAAYzwAcwBlAGMAdABpAG8AbgAgAGMAbABhAHMAcwA9ACIAcwBl
>> "%~1" echo AGMAdABpAG8AbgAgAHIAYQB3ACIAPgA8AGgAMgA+AJ9Ty1kgAEEARABCACAAk4/6
>> "%~1" echo UUSWVV88AC8AaAAyAD4AAQ1sAG8AZwBjAGEAdAAAMQoALgAuAC4AIADyXSpirWUM
>> "%~1" echo /4xbdGWFUblb94sLd8F5CWeMW3RlSHIgAC4ALgAuAAElPABkAGUAdABhAGkAbABz
>> "%~1" echo AD4APABzAHUAbQBtAGEAcgB5AD4AAAcgALcAIAABFW0AcwAgALcAIABlAHgAaQB0
>> "%~1" echo ACAAARUgALcAIAB0AGkAbQBlAG8AdQB0AAEfPAAvAHMAdQBtAG0AYQByAHkAPgA8
>> "%~1" echo AHAAcgBlAD4AACE8AC8AcAByAGUAPgA8AC8AZABlAHQAYQBpAGwAcwA+AAAVPAAv
>> "%~1" echo AHMAZQBjAHQAaQBvAG4APgAAOWcAZQB0AHAAcgBvAHAAIABkAGgAYwBwAC4AdwBs
>> "%~1" echo AGEAbgAwAC4AaQBwAGEAZABkAHIAZQBzAHMAAA8wAC4AMAAuADAALgAwAAA1aQBw
>> "%~1" echo ACAALQBmACAAaQBuAGUAdAAgAGEAZABkAHIAIABzAGgAbwB3ACAAdwBsAGEAbgAw
>> "%~1" echo AAELaQBuAGUAdAAgAAAFIgAiAAADIgAABVwAIgAAAzIAAAdFUTV1LU4BAzMAAAM0
>> "%~1" echo AAAHKmdFUTV1AQM1AAAH8l1FUeFuAQVjazheAQXHj+1wAQVfY09XAQXHj4tTAQM3
>> "%~1" echo AAAFx4+3UQEXQQBDACAAcABvAHcAZQByAGUAZAA6AAAFQQBDAAAZVQBTAEIAIABw
>> "%~1" echo AG8AdwBlAHIAZQBkADoAAAdVAFMAQgAAI1cAaQByAGUAbABlAHMAcwAgAHAAbwB3
>> "%~1" echo AGUAcgBlAGQAOgAABeBlv34BBypnm081dQEDPQAAByAARwBCAAADWwAACV0AOgAg
>> "%~1" echo AFsAACtcACIAXABzACoAOgBcAHMAKgBcACIAKABbAF4AXAAiAF0AKgApAFwAIgAA
>> "%~1" echo J1wAIgBcAHMAKgA6AFwAcwAqACgAWwBeACwAfQBcAHMAXQArACkAAAsvAGQAYQB0
>> "%~1" echo AGEAABEvAHMAdABvAHIAYQBnAGUAAA0gAHUAcwBlAGQAIAAAE3AAcgBvAGMAZQBz
>> "%~1" echo AHMAbwByAAA/QwBQAFUAIABwAGEAcgB0AFwAcwAqADoAXABzACoAKAAwAHgAWwAw
>> "%~1" echo AC0AOQBhAC0AZgBBAC0ARgBdACsAKQABEyAAYwBvAHIAZQBzACAALwAgAAAhaQBk
>> "%~1" echo AD0AXABkACsALABcAHMAKgB3AGkAZAB0AGgAPQAAAzAAAA0gAG0AbwBkAGUAcwAA
>> "%~1" echo E0gAQQBMACAAUgBlAGEAZAB5AAAJSABBAEwAIAAAEWIAYQB0AHQAZQByAHkAIAAA
>> "%~1" echo JWMAbwBuAG4AZQBjAHQAZQBkAD0AKABbAGEALQB6AF0AKwApAAEnYwBvAG4AZgBp
>> "%~1" echo AGcAdQByAGUAZAA9ACgAWwBhAC0AegBdACsAKQABOW0AQwB1AHIAcgBlAG4AdABG
>> "%~1" echo AHUAbgBjAHQAaQBvAG4AcwA9ACgAWwBeAFwAbgBcAHIAXQArACkAABVjAG8AbgBu
>> "%~1" echo AGUAYwB0AGUAZAAgAAAXYwBvAG4AZgBpAGcAdQByAGUAZAAgAAA9cwB0AGEAbgBk
>> "%~1" echo AGEAcgBkADoAXABzACoAKABbADAALQA5AEEALQBaAGEALQB6ACAALgBfAC0AXQAr
>> "%~1" echo ACkAAStGAHIAZQBxAHUAZQBuAGMAeQA6AFwAcwAqACgAWwAwAC0AOQBdACsAKQAB
>> "%~1" echo LUwAaQBuAGsAIABzAHAAZQBlAGQAOgBcAHMAKgAoAFsAMAAtADkAXQArACkAASVS
>> "%~1" echo AFMAUwBJADoAXABzACoAKAAtAD8AWwAwAC0AOQBdACsAKQABT2kAbgBlAHQAXABz
>> "%~1" echo ACsAKABbADAALQA5AF0AKwBcAC4AWwAwAC0AOQBdACsAXAAuAFsAMAAtADkAXQAr
>> "%~1" echo AFwALgBbADAALQA5AF0AKwApAAEHSQBQACAAABNzAHQAYQBuAGQAYQByAGQAIAAA
>> "%~1" echo B00ASAB6AAAJTQBiAHAAcwAAC1IAUwBTAEkAIAAAJ2UAbgBhAGIAbABlAGQAOgBc
>> "%~1" echo AHMAKgAoAFsAYQAtAHoAXQArACkAASVzAHQAYQB0AGUAOgBcAHMAKgAoAFsAQQAt
>> "%~1" echo AFoAXwBdACsAKQABIUIAbAB1AGUAdABvAG8AdABoACAAUwB0AGEAdAB1AHMAABFl
>> "%~1" echo AG4AYQBiAGwAZQBkACAAAF9DAGEAbQBlAHIAYQBEAGUAdgBpAGMAZQBDAGwAaQBl
>> "%~1" echo AG4AdAB8AEMAYQBtAGUAcgBhAFwAcwArAEkARAB8AD0APQAgAEMAYQBtAGUAcgBh
>> "%~1" echo ACAAZABlAHYAaQBjAGUAADUiAFMAZQBuAHMAbwByAFQAeQBwAGUAIgBcAHMAKgA6
>> "%~1" echo AFwAcwAqACIATwBHADAAMQBBACIAADciAFMAZQBuAHMAbwByAFQAeQBwAGUAIgBc
>> "%~1" echo AHMAKgA6AFwAcwAqACIATwBWADcAMgA1ADEAIgAANyIAUwBlAG4AcwBvAHIAVAB5
>> "%~1" echo AHAAZQAiAFwAcwAqADoAXABzACoAIgBJAE0AWAA0ADcAMQAiAAAfIABjAGEAbQBl
>> "%~1" echo AHIAYQAgAGUAbgB0AHIAaQBlAHMAACVjAGEAbAAgAHMAZQBuAHMAbwByAHMAIABP
>> "%~1" echo AEcAMAAxAEEAIAAAFSAALwAgAE8AVgA3ADIANQAxACAAABUgAC8AIABJAE0AWAA0
>> "%~1" echo ADcAMQAgAABBUABhAGMAawBhAGcAZQAgAFsAVgBpAHIAdAB1AGEAbABEAGUAcwBr
>> "%~1" echo AHQAbwBwAC4AQQBuAGQAcgBvAGkAZABdAAARcABhAGMAawBhAGcAZQA6AAAvVgBJ
>> "%~1" echo AFYARQAgAEIAdQBzAGkAbgBlAHMAcwAgAFMAdAByAGUAYQBtAGkAbgBnAAA3VgBJ
>> "%~1" echo AFYARQAgAEIAdQBzAGkAbgBlAHMAcwAgAFMAdAByAGUAYQBtAGkAbgBnACAAQQBE
>> "%~1" echo AEIAAA9BAG4AZAByAG8AaQBkAAAdcABsAGEAdABmAG8AcgBtAC0AdABvAG8AbABz
>> "%~1" echo AAE1QQBuAGQAcgBvAGkAZAAgAHAAbABhAHQAZgBvAHIAbQAtAHQAbwBvAGwAcwAg
>> "%~1" echo AEEARABCAAEPYQBkAGIALgBlAHgAZQAAB2EAZABiAAAdQQBEAEIAIABlAHgAZQBj
>> "%~1" echo AHUAdABhAGIAbABlAAALWwBBAC0AWgBdAAELWwAwAC0AOQBdAAEnXABiAFsAQQAt
>> "%~1" echo AFoAMAAtADkAXQB7ADEAMgAsADIAMAB9AFwAYgABTVwAYgAoAFsAMAAtADkAQQAt
>> "%~1" echo AEYAYQAtAGYAXQB7ADIAfQA6ACkAewA1AH0AWwAwAC0AOQBBAC0ARgBhAC0AZgBd
>> "%~1" echo AHsAMgB9AFwAYgABIyoAKgA6ACoAKgA6ACoAKgA6ACoAKgA6ACoAKgA6ACoAKgAA
>> "%~1" echo PVwAYgAxADkAMgBcAC4AMQA2ADgAXAAuAFwAZAB7ADEALAAzAH0AXAAuAFwAZAB7
>> "%~1" echo ADEALAAzAH0AXABiAAAXMQA5ADIALgAxADYAOAAuAHgALgB4AABDXABiADEAMABc
>> "%~1" echo AC4AXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAs
>> "%~1" echo ADMAfQBcAGIAABExADAALgB4AC4AeAAuAHgAAGNcAGIAMQA3ADIAXAAuACgAMQBb
>> "%~1" echo ADYALQA5AF0AfAAyAFsAMAAtADkAXQB8ADMAWwAwAC0AMQBdACkAXAAuAFwAZAB7
>> "%~1" echo ADEALAAzAH0AXAAuAFwAZAB7ADEALAAzAH0AXABiAAETMQA3ADIALgB4AC4AeAAu
>> "%~1" echo AHgAAFEoAFMAUwBJAEQAfABCAFMAUwBJAEQAfABXAGkAZgBpAFMAcwBpAGQAfABt
>> "%~1" echo AFcAaQBmAGkASQBuAGYAbwApAFsAXgAsAFwAbgBcAHIAXQAqAAAbJAAxAD0APABy
>> "%~1" echo AGUAZABhAGMAdABlAGQAPgAATXIAbwBcAC4AYgB1AGkAbABkAFwALgBmAGkAbgBn
>> "%~1" echo AGUAcgBwAHIAaQBuAHQAXABdADoAIABcAFsAWwBeAFwAXQBcAG4AXAByAF0AKwAA
>> "%~1" echo RXIAbwAuAGIAdQBpAGwAZAAuAGYAaQBuAGcAZQByAHAAcgBpAG4AdABdADoAIABb
>> "%~1" echo ADwAcgBlAGQAYQBjAHQAZQBkAD4AACtmAGkAbgBnAGUAcgBwAHIAaQBuAHQAPQBb
>> "%~1" echo AF4ALABcAG4AXAByAF0AKwAALWYAaQBuAGcAZQByAHAAcgBpAG4AdAA9ADwAcgBl
>> "%~1" echo AGQAYQBjAHQAZQBkAD4AADVvAHMAXwBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAWwBe
>> "%~1" echo ACwAXABuAFwAcgBcAFwAfQBdACsAADNvAHMAXwBmAGkAbgBnAGUAcgBwAHIAaQBu
>> "%~1" echo AHQAPQA8AHIAZQBkAGEAYwB0AGUAZAA+AAAtcwBlAHMAcwBpAG8AbgBfAGkAZABb
>> "%~1" echo AF4ALABcAG4AXAByAFwAXAB9AF0AKwAAK3MAZQBzAHMAaQBvAG4AXwBpAGQAPQA8
>> "%~1" echo AHIAZQBkAGEAYwB0AGUAZAA+AAARPABzAGUAcgBpAGEAbAA+AAAHKgAqACoAAAMN
>> "%~1" echo AAA5ZABlAHYAZQBsAG8AcABtAGUAbgB0AF8AcwBlAHQAdABpAG4AZwBzAF8AZQBu
>> "%~1" echo AGEAYgBsAGUAZAAAJWQAZQB2AGkAYwBlAF8AcAByAG8AdgBpAHMAaQBvAG4AZQBk
>> "%~1" echo AAAndQBzAGUAcgBfAHMAZQB0AHUAcABfAGMAbwBtAHAAbABlAHQAZQAAD3cAaQBm
>> "%~1" echo AGkAXwBvAG4AACFhAGkAcgBwAGwAYQBuAGUAXwBtAG8AZABlAF8AbwBuAAAVaAB0
>> "%~1" echo AHQAcABfAHAAcgBvAHgAeQAAI2cAbABvAGIAYQBsAF8AaAB0AHQAcABfAHAAcgBv
>> "%~1" echo AHgAeQAAL2kAbgBzAHQAYQBsAGwAXwBuAG8AbgBfAG0AYQByAGsAZQB0AF8AYQBw
>> "%~1" echo AHAAcwAAOXYAZQByAGkAZgBpAGUAcgBfAHYAZQByAGkAZgB5AF8AYQBkAGIAXwBp
>> "%~1" echo AG4AcwB0AGEAbABsAHMAAAMnAAEJJwBcACcAJwABC3QAbwBrAGUAbgAAAz8AAAMr
>> "%~1" echo AAA/YQBwAHAAbABpAGMAYQB0AGkAbwBuAC8AagBzAG8AbgA7ACAAYwBoAGEAcgBz
>> "%~1" echo AGUAdAA9AHUAdABmAC0AOAABP0gAVABUAFAALwAxAC4AMQAgADIAMAAwACAATwBL
>> "%~1" echo AA0ACgBDAG8AbgB0AGUAbgB0AC0AVAB5AHAAZQA6ACAAASUNAAoAQwBvAG4AdABl
>> "%~1" echo AG4AdAAtAEwAZQBuAGcAdABoADoAIAABYQ0ACgBDAGEAYwBoAGUALQBDAG8AbgB0
>> "%~1" echo AHIAbwBsADoAIABuAG8ALQBzAHQAbwByAGUADQAKAEMAbwBuAG4AZQBjAHQAaQBv
>> "%~1" echo AG4AOgAgAGMAbABvAHMAZQANAAoADQAKAAEDewAAByIAOgAiAAADfQAABVwAXAAA
>> "%~1" echo BVwAbgAABVwAcgAABVwAdAAABVwAdQAABXgANAAAwAGP2VAAQwBGAGsAYgAyAE4A
>> "%~1" echo MABlAFgAQgBsAEkARwBoADAAYgBXAHcAKwBEAFEAbwA4AGEASABSAHQAYgBDAEIA
>> "%~1" echo cwBZAFcANQBuAFAAUwBKADYAYQBDADEARABUAGkASQArAEQAUQBvADgAYQBHAFYA
>> "%~1" echo aABaAEQANABOAEMAagB4AHQAWgBYAFIAaABJAEcATgBvAFkAWABKAHoAWgBYAFEA
>> "%~1" echo OQBJAG4AVgAwAFoAaQAwADQASQBqADQATgBDAGoAeAB0AFoAWABSAGgASQBHADUA
>> "%~1" echo aABiAFcAVQA5AEkAbgBaAHAAWgBYAGQAdwBiADMASgAwAEkAaQBCAGoAYgAyADUA
>> "%~1" echo MABaAFcANQAwAFAAUwBKADMAYQBXAFIAMABhAEQAMQBrAFoAWABaAHAAWQAyAFUA
>> "%~1" echo dABkADIAbABrAGQARwBnAHMAYQBXADUAcABkAEcAbABoAGIAQwAxAHoAWQAyAEYA
>> "%~1" echo cwBaAFQAMAB4AEkAagA0AE4AQwBqAHgAMABhAFgAUgBzAFoAVAA1AFIAZABXAFYA
>> "%~1" echo egBkAEMAQgBCAFIARQBJAGcANQBvADYAbgA1AFkAaQAyADUAWQArAHcAUABDADkA
>> "%~1" echo MABhAFgAUgBzAFoAVAA0AE4AQwBqAHgAegBkAEgAbABzAFoAVAA0AE4AQwBqAHAA
>> "%~1" echo eQBiADIAOQAwAGUAeQAwAHQAWQBtAGMANgBJADIAWQAxAFoAagBkAG0AWQBqAHMA
>> "%~1" echo dABMAFgATgBwAFoARwBVADYASQAyAFoAbQBaAGoAcwB0AEwAVwBOAGgAYwBtAFEA
>> "%~1" echo NgBJADIAWgBtAFoAagBzAHQATABYAE4AdgBaAG4AUQA2AEkAMgBZADQAWgBtAEYA
>> "%~1" echo bQBZAHoAcwB0AEwAVwB4AHAAYgBtAFUANgBJADIAVQB5AFoAVABoAG0ATQBEAHMA
>> "%~1" echo dABMAFgAUgBsAGUASABRADYASQB6AEUAeABNAFQAZwB5AE4AegBzAHQATABXADEA
>> "%~1" echo MQBkAEcAVgBrAE8AaQBNADIATgBEAGMAMABPAEcASQA3AEwAUwAxAGkAYgBIAFYA
>> "%~1" echo bABPAGkATQB5AE4AVABZAHoAWgBXAEkANwBMAFMAMQBuAGMAbQBWAGwAYgBqAG8A
>> "%~1" echo agBNAFQAWgBoAE0AegBSAGgATwB5ADAAdABZAFcAMQBpAFoAWABJADYASQAyAFEA
>> "%~1" echo NQBOAHoAYwB3AE4AagBzAHQATABYAEoAbABaAEQAbwBqAFoAVABFAHgAWgBEAFEA
>> "%~1" echo NABPAHkAMAB0AGIAbQBGADIATwBqAEkAegBOAG4AQgA0AE8AeQAwAHQAYwBtAEYA
>> "%~1" echo awBhAFgAVgB6AE8AagBoAHcAZQBIADAATgBDAG0ASgB2AFoASABrAHUAWgBHAEYA
>> "%~1" echo eQBhADMAcwB0AEwAVwBKAG4ATwBpAE0AdwBaAGoARQAwAE0AVwBNADcATABTADEA
>> "%~1" echo egBhAFcAUgBsAE8AaQBNAHgATQBUAEUANABNAGoARQA3AEwAUwAxAGoAWQBYAEoA
>> "%~1" echo awBPAGkATQB4AE4AVABGAGsATQBqAGcANwBMAFMAMQB6AGIAMgBaADAATwBpAE0A
>> "%~1" echo eABNAFQARQA0AE0AagBJADcATABTADEAcwBhAFcANQBsAE8AaQBNAHkATgBqAE0A
>> "%~1" echo eQBOAEQAUQA3AEwAUwAxADAAWgBYAGgAMABPAGkATgBsAE4AVwBWAGsAWgBqAGMA
>> "%~1" echo NwBMAFMAMQB0AGQAWABSAGwAWgBEAG8AagBPAFQAUgBoAE0AMgBJADQAZgBRADAA
>> "%~1" echo SwBLAG4AdABpAGIAMwBnAHQAYwAyAGwANgBhAFcANQBuAE8AbQBKAHYAYwBtAFIA
>> "%~1" echo bABjAGkAMQBpAGIAMwBoADkAYQBIAFIAdABiAEMAeABpAGIAMgBSADUAZQAyADEA
>> "%~1" echo aABjAG0AZABwAGIAagBvAHcATwAyADEAcABiAGkAMQBvAFoAVwBsAG4AYQBIAFEA
>> "%~1" echo NgBNAFQAQQB3AEoAVAB0AG0AYgAyADUAMABMAFcAWgBoAGIAVwBsAHMAZQBUAG8A
>> "%~1" echo aQBVADIAVgBuAGIAMgBVAGcAVgBVAGsAaQBMAEMASgBOAGEAVwBOAHkAYgAzAE4A
>> "%~1" echo dgBaAG4AUQBnAFcAVwBGAEkAWgBXAGsAaQBMAEUARgB5AGEAVwBGAHMATABIAE4A
>> "%~1" echo aABiAG4ATQB0AGMAMgBWAHkAYQBXAFkANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYA
>> "%~1" echo dQBaAEQAcAAyAFkAWABJAG8ATABTADEAaQBaAHkAawA3AFkAMgA5AHMAYgAzAEkA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAZABHAFYANABkAEMAawA3AFoAbQA5AHUAZABDADEA
>> "%~1" echo egBhAFgAcABsAE8AagBFADAAYwBIAGcANwBiAEcAVgAwAGQARwBWAHkATABYAE4A
>> "%~1" echo dwBZAFcATgBwAGIAbQBjADYATQBIADEAaQBkAFgAUgAwAGIAMgA0AHMAYQBXADUA
>> "%~1" echo dwBkAFgAUQBzAGMAMgBWAHMAWgBXAE4AMABlADIAWgB2AGIAbgBRADYAYQBXADUA
>> "%~1" echo bwBaAFgASgBwAGQASAAwAE4AQwBpADUAaABjAEgAQgA3AGIAVwBsAHUATABXAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvAHgATQBEAEIAMgBhAEQAdABrAGEAWABOAHcAYgBHAEYA
>> "%~1" echo NQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoAVwAxAHcAYgBHAEYA
>> "%~1" echo MABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAG4AWgBoAGMAaQBnAHQATABXADUA
>> "%~1" echo aABkAGkAawBnAE0AVwBaAHkATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAWQBtAGMAcABmAFMANQB6AGEAVwBSAGwAZQAzAEIA
>> "%~1" echo dgBjADIAbAAwAGEAVwA5AHUATwBtAFoAcABlAEcAVgBrAE8AMgBsAHUAYwAyAFYA
>> "%~1" echo MABPAGoAQQBnAFkAWABWADAAYgB5AEEAdwBJAEQAQQA3AGQAMgBsAGsAZABHAGcA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAYgBtAEYAMgBLAFQAdABvAFoAVwBsAG4AYQBIAFEA
>> "%~1" echo NgBNAFQAQQB3AGQAbQBnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAHoAYQBXAFIAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkA
>> "%~1" echo dABjAG0AbABuAGEASABRADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoA
>> "%~1" echo aABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIAUgBwAGMAMwBCAHMAWQBYAGsA
>> "%~1" echo NgBaAG0AeABsAGUARAB0AG0AYgBHAFYANABMAFcAUgBwAGMAbQBWAGoAZABHAGwA
>> "%~1" echo dgBiAGoAcABqAGIAMgB4ADEAYgBXADUAOQBMAG0ASgB5AFkAVwA1AGsAZQAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvADMATgBuAEIANABPADIAUgBwAGMAMwBCAHMAWQBYAGsA
>> "%~1" echo NgBaAG0AeABsAGUARAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQARwBWAHQAYwB6AHAA
>> "%~1" echo agBaAFcANQAwAFoAWABJADcAWgAyAEYAdwBPAGoARQB5AGMASABnADcAYwBHAEYA
>> "%~1" echo awBaAEcAbAB1AFoAegBvAHcASQBEAEUANABjAEgAZwA3AFkAbQA5AHkAWgBHAFYA
>> "%~1" echo eQBMAFcASgB2AGQASABSAHYAYgBUAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEA
>> "%~1" echo ZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAbAA5AEwAbQBKAHkAWQBXADUA
>> "%~1" echo awBTAFcATgB2AGIAbgB0ADMAYQBXAFIAMABhAEQAbwB6AE4AbgBCADQATwAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvAHoATgBuAEIANABPADIASgB2AGMAbQBSAGwAYwBpADEA
>> "%~1" echo eQBZAFcAUgBwAGQAWABNADYATwBIAEIANABPADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABZAG0AeAAxAFoAUwBrADcAWgBHAGwA
>> "%~1" echo egBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADMAQgBzAFkAVwBOAGwATABXAGwA
>> "%~1" echo MABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABqAGIAMgB4AHYAYwBqAHAA
>> "%~1" echo MwBhAEcAbAAwAFoAWAAwAHUAWQBuAEoAaABiAG0AUQBnAFkAbgB0AGsAYQBYAE4A
>> "%~1" echo dwBiAEcARgA1AE8AbQBKAHMAYgAyAE4AcgBPADIAWgB2AGIAbgBRAHQAYwAyAGwA
>> "%~1" echo NgBaAFQAbwB4AE4AbgBCADQAZgBTADUAaQBjAG0ARgB1AFoAQwBCAHoAYwBHAEYA
>> "%~1" echo dQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgBzADcAYgBXAEYA
>> "%~1" echo eQBaADIAbAB1AEwAWABSAHYAYwBEAG8AegBjAEgAZwA3AFkAMgA5AHMAYgAzAEkA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMgBaAHYAYgBuAFEA
>> "%~1" echo dABjADIAbAA2AFoAVABvAHgATQBuAEIANABmAFMANQBpAGMAbQBGAHUAWgBFAGwA
>> "%~1" echo agBiADIANABnAGMAMwBaAG4ATABDADUAdQBZAFgAWQBnAGMAMwBaAG4ATABDADUA
>> "%~1" echo awBaAFgAWgBwAFkAMgBWAEoAWQAyADkAdQBJAEgATgAyAFoAMwB0AG0AYQBXAHgA
>> "%~1" echo cwBPAG0ANQB2AGIAbQBVADcAYwAzAFIAeQBiADIAdABsAE8AbQBOADEAYwBuAEoA
>> "%~1" echo bABiAG4AUgBEAGIAMgB4AHYAYwBqAHQAegBkAEgASgB2AGEAMgBVAHQAZAAyAGwA
>> "%~1" echo awBkAEcAZwA2AE0AagB0AHoAZABIAEoAdgBhADIAVQB0AGIARwBsAHUAWgBXAE4A
>> "%~1" echo aABjAEQAcAB5AGIAMwBWAHUAWgBEAHQAegBkAEgASgB2AGEAMgBVAHQAYgBHAGwA
>> "%~1" echo dQBaAFcAcAB2AGEAVwA0ADYAYwBtADkAMQBiAG0AUgA5AEQAUQBvAHUAYgBtAEYA
>> "%~1" echo MgBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AWQBYAEEA
>> "%~1" echo NgBOAEgAQgA0AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABKAHcAZQBIADAA
>> "%~1" echo dQBiAG0ARgAyAEkARwBGADcAYQBHAFYAcABaADIAaAAwAE8AagBNADQAYwBIAGcA
>> "%~1" echo NwBZAG0AOQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADMAYwBIAGcA
>> "%~1" echo NwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbQBiAEcAVgA0AE8AMgBGAHMAYQBXAGQA
>> "%~1" echo dQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMAagB0AG4AWQBYAEEA
>> "%~1" echo NgBNAFQAQgB3AGUARAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBBAGcATQBUAEoA
>> "%~1" echo dwBlAEQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIA
>> "%~1" echo bABaAEMAawA3AGQARwBWADQAZABDADEAawBaAFcATgB2AGMAbQBGADAAYQBXADkA
>> "%~1" echo dQBPAG0ANQB2AGIAbQBVADcAWgBtADkAdQBkAEMAMQAzAFoAVwBsAG4AYQBIAFEA
>> "%~1" echo NgBOAHoAQQB3AGYAUwA1AHUAWQBYAFkAZwBZAFMAQgB6AGQAbQBkADcAZAAyAGwA
>> "%~1" echo awBkAEcAZwA2AE0AVABoAHcAZQBEAHQAbwBaAFcAbABuAGEASABRADYATQBUAGgA
>> "%~1" echo dwBlAEgAMAB1AGIAbQBGADIASQBHAEUAdQBZAFcATgAwAGEAWABaAGwAZQAyAEoA
>> "%~1" echo aABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBjAG0AZABpAFkAUwBnAHoATgB5AHcA
>> "%~1" echo NQBPAFMAdwB5AE0AegBVAHMATABqAEUAdwBLAFQAdABqAGIAMgB4AHYAYwBqAHAA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAGkAYgBIAFYAbABLAFgAMABOAEMAaQA1AHQAWQBXAGwA
>> "%~1" echo dQBlADIAZAB5AGEAVwBRAHQAWQAyADkAcwBkAFcAMQB1AE8AagBJADcAYgBXAGwA
>> "%~1" echo dQBMAFgAZABwAFoASABSAG8ATwBqAEEANwBiAFcAbAB1AEwAVwBoAGwAYQBXAGQA
>> "%~1" echo bwBkAEQAbwB4AE0ARABCADIAYQBEAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUA
>> "%~1" echo awBPAG4AWgBoAGMAaQBnAHQATABXAEoAbgBLAFgAMAB1AGQARwA5AHcAZQAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvADMATgBuAEIANABPADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABZADIARgB5AFoAQwBrADcAWQBtADkA
>> "%~1" echo eQBaAEcAVgB5AEwAVwBKAHYAZABIAFIAdgBiAFQAbwB4AGMASABnAGcAYwAyADkA
>> "%~1" echo cwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoAUwBrADcAWgBHAGwA
>> "%~1" echo egBjAEcAeABoAGUAVABwAG0AYgBHAFYANABPADIARgBzAGEAVwBkAHUATABXAGwA
>> "%~1" echo MABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABxAGQAWABOADAAYQBXAFoA
>> "%~1" echo NQBMAFcATgB2AGIAbgBSAGwAYgBuAFEANgBjADMAQgBoAFkAMgBVAHQAWQBtAFYA
>> "%~1" echo MABkADIAVgBsAGIAagB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBBAGcATQBqAFIA
>> "%~1" echo dwBlAEQAdAB3AGIAMwBOAHAAZABHAGwAdgBiAGoAcAB6AGQARwBsAGoAYQAzAGsA
>> "%~1" echo NwBkAEcAOQB3AE8AagBBADcAZQBpADEAcABiAG0AUgBsAGUARABvAHoAZgBTADUA
>> "%~1" echo MABhAFgAUgBzAFoAUwBCAG8ATQBYAHQAdABZAFgASgBuAGEAVwA0ADYATQBEAHQA
>> "%~1" echo bQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAGoARgB3AGUASAAwAHUAZABHAGwA
>> "%~1" echo MABiAEcAVQBnAGMASAB0AHQAWQBYAEoAbgBhAFcANAA2AE4AWABCADQASQBEAEEA
>> "%~1" echo ZwBNAEQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIA
>> "%~1" echo bABaAEMAawA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFAHoAYwBIAGgA
>> "%~1" echo OQBEAFEAbwB1AGQARwA5AHYAYgBHAEoAaABjAG4AdABrAGEAWABOAHcAYgBHAEYA
>> "%~1" echo NQBPAG0AWgBzAFoAWABnADcAWQBXAHgAcABaADIANAB0AGEAWABSAGwAYgBYAE0A
>> "%~1" echo NgBZADIAVgB1AGQARwBWAHkATwAyAGQAaABjAEQAbwA0AGMASABnADcAWgBtAHgA
>> "%~1" echo bABlAEMAMQAzAGMAbQBGAHcATwBuAGQAeQBZAFgAQQA3AGEAbgBWAHoAZABHAGwA
>> "%~1" echo bQBlAFMAMQBqAGIAMgA1ADAAWgBXADUAMABPAG0AWgBzAFoAWABnAHQAWgBXADUA
>> "%~1" echo awBmAFMANQBqAGEARwBsAHcATABDADUAaQBkAEcANQA3AGEARwBWAHAAWgAyAGgA
>> "%~1" echo MABPAGoATQAwAGMASABnADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBDAEIA
>> "%~1" echo egBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQA
>> "%~1" echo aQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMAaQBnAHQATABYAE4A
>> "%~1" echo dgBaAG4AUQBwAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIA
>> "%~1" echo bABlAEgAUQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0A
>> "%~1" echo NgBOADMAQgA0AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AQwBBAHgATQBYAEIA
>> "%~1" echo NABPADIAUgBwAGMAMwBCAHMAWQBYAGsANgBhAFcANQBzAGEAVwA1AGwATABXAFoA
>> "%~1" echo cwBaAFgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAyAFYA
>> "%~1" echo dQBkAEcAVgB5AE8AMgBkAGgAYwBEAG8AMwBjAEgAZwA3AFoAbQA5AHUAZABDADEA
>> "%~1" echo MwBaAFcAbABuAGEASABRADYATgB6AEEAdwBmAFMANQBqAGEARwBsAHcAUgBHADkA
>> "%~1" echo MABlADMAZABwAFoASABSAG8ATwBqAGgAdwBlAEQAdABvAFoAVwBsAG4AYQBIAFEA
>> "%~1" echo NgBPAEgAQgA0AE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0A
>> "%~1" echo NgBOAFQAQQBsAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYA
>> "%~1" echo eQBLAEMAMAB0AGMAbQBWAGsASwBYADAAdQBZADIAOQB1AGIAbQBWAGoAZABHAFYA
>> "%~1" echo awBJAEMANQBqAGEARwBsAHcAUgBHADkAMABlADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABaADMASgBsAFoAVwA0AHAAZgBTADUA
>> "%~1" echo aQBkAEcANQA3AFkAMwBWAHkAYwAyADkAeQBPAG4AQgB2AGEAVwA1ADAAWgBYAEoA
>> "%~1" echo OQBMAG0ASgAwAGIAaQA1AHcAYwBtAGwAdABZAFgASgA1AGUAMgBKAGgAWQAyAHQA
>> "%~1" echo bgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsA
>> "%~1" echo NwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcA
>> "%~1" echo dABMAFcASgBzAGQAVwBVAHAATwAyAE4AdgBiAEcAOQB5AE8AbgBkAG8AYQBYAFIA
>> "%~1" echo bABmAFMANQBpAGQARwA0AHUAWgAyAGgAdgBjADMAUgA3AFkAbQBGAGoAYQAyAGQA
>> "%~1" echo eQBiADMAVgB1AFoARABwADAAYwBtAEYAdQBjADMAQgBoAGMAbQBWAHUAZABIADAA
>> "%~1" echo TgBDAGkANQAzAGMAbQBGAHcAZQAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBUAGgA
>> "%~1" echo dwBlAEMAQQB5AE4ASABCADQASQBEAE0AeQBjAEgAZwA3AFoARwBsAHoAYwBHAHgA
>> "%~1" echo aABlAFQAcABtAGIARwBWADQATwAyAFoAcwBaAFgAZwB0AFoARwBsAHkAWgBXAE4A
>> "%~1" echo MABhAFcAOQB1AE8AbQBOAHYAYgBIAFYAdABiAGoAdABuAFkAWABBADYATQBUAFIA
>> "%~1" echo dwBlAEQAdAB0AFkAWABnAHQAZAAyAGwAawBkAEcAZwA2AE0AVABRADQATQBIAEIA
>> "%~1" echo NABPADIAMQBwAGIAaQAxAG8AWgBXAGwAbgBhAEgAUQA2AFkAMgBGAHMAWQB5AGcA
>> "%~1" echo eABNAEQAQgAyAGEAQwBBAHQASQBEAGMAMgBjAEgAZwBwAE8AMgBKAGgAWQAyAHQA
>> "%~1" echo bgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AFkAbQBjAHAAZgBTADUA
>> "%~1" echo dQBiADMAUgBwAFkAMgBWADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBDAEIA
>> "%~1" echo egBiADIAeABwAFoAQwBCAHkAWgAyAEoAaABLAEQASQB4AE4AeQB3AHgATQBUAGsA
>> "%~1" echo cwBOAGkAdwB1AE0AegBBAHAATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEA
>> "%~1" echo NgBjAG0AZABpAFkAUwBnAHkATQBUAGMAcwBNAFQARQA1AEwARABZAHMATABqAEEA
>> "%~1" echo MwBLAFQAdABqAGIAMgB4AHYAYwBqAG8AagBZAGoATQAyAE4AVABBADEATwAyAEoA
>> "%~1" echo dgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8ASABCADQATwAzAEIA
>> "%~1" echo aABaAEcAUgBwAGIAbQBjADYATQBUAEIAdwBlAEMAQQB4AE0AMwBCADQATwAyAFoA
>> "%~1" echo dgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAYwB3AE0ARAB0AHQAYQBXADQA
>> "%~1" echo dABhAEcAVgBwAFoAMgBoADAATwBqAEEANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwA
>> "%~1" echo bgBhAEgAUQA2AE0AUwA0ADAATgBYADEAaQBiADIAUgA1AEwAbQBSAGgAYwBtAHMA
>> "%~1" echo ZwBMAG0ANQB2AGQARwBsAGoAWgBYAHQAagBiADIAeAB2AGMAagBvAGoAWgBqAFIA
>> "%~1" echo agBNAEQAWgBoAGYAUwA1AHcAWQBXAGQAbABlADIAUgBwAGMAMwBCAHMAWQBYAGsA
>> "%~1" echo NgBiAG0AOQB1AFoAWAAwAHUAYwBHAEYAbgBaAFMANQBoAFkAMwBSAHAAZABtAFYA
>> "%~1" echo NwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAGgAYwBEAG8A
>> "%~1" echo eABOAEgAQgA0AGYAUwA1AHkAYgAzAGQANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAA
>> "%~1" echo bgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUA
>> "%~1" echo dABZADIAOQBzAGQAVwAxAHUAYwB6AG8AeABaAG4ASQBnAE0AVwBaAHkATwAyAGQA
>> "%~1" echo aABjAEQAbwB4AE4ASABCADQAZgBTADUAeQBiADMAYwB6AGUAMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIA
>> "%~1" echo cwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AGMAbQBWAHcAWgBXAEYA
>> "%~1" echo MABLAEQATQBzAE0AVwBaAHkASwBUAHQAbgBZAFgAQQA2AE0AVABSAHcAZQBIADAA
>> "%~1" echo TgBDAGkANQBqAFkAWABKAGsAZQAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAWQAyAEYAeQBaAEMAawA3AFkAbQA5AHkAWgBHAFYA
>> "%~1" echo eQBPAGoARgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEA
>> "%~1" echo cwBhAFcANQBsAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYA
>> "%~1" echo egBPAG4AWgBoAGMAaQBnAHQATABYAEoAaABaAEcAbAAxAGMAeQBrADcAYgAzAFoA
>> "%~1" echo bABjAG0AWgBzAGIAMwBjADYAYQBHAGwAawBaAEcAVgB1AGYAUwA1AG8AWgBXAEYA
>> "%~1" echo awBlADIAaABsAGEAVwBkAG8AZABEAG8AMABOAEgAQgA0AE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGkAMQBpAGIAMwBSADAAYgAyADAANgBNAFgAQgA0AEkASABOAHYAYgBHAGwA
>> "%~1" echo awBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcAbABuAGIAaQAxAHAAZABHAFYA
>> "%~1" echo dABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBhAG4AVgB6AGQARwBsAG0AZQBTADEA
>> "%~1" echo agBiADIANQAwAFoAVwA1ADAATwBuAE4AdwBZAFcATgBsAEwAVwBKAGwAZABIAGQA
>> "%~1" echo bABaAFcANAA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB3AEkARABFADAAYwBIAGgA
>> "%~1" echo OQBMAG0AaABsAFkAVwBRAGcAYQBEAEoANwBiAFcARgB5AFoAMgBsAHUATwBqAEEA
>> "%~1" echo NwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQAxAGMASABoADkATABuAFIA
>> "%~1" echo aABaADMAdABvAFoAVwBsAG4AYQBIAFEANgBNAGoAUgB3AGUARAB0AGsAYQBYAE4A
>> "%~1" echo dwBiAEcARgA1AE8AbQBsAHUAYgBHAGwAdQBaAFMAMQBtAGIARwBWADQATwAyAEYA
>> "%~1" echo cwBhAFcAZAB1AEwAVwBsADAAWgBXADEAegBPAG0ATgBsAGIAbgBSAGwAYwBqAHQA
>> "%~1" echo aQBiADMASgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoA
>> "%~1" echo aABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrADcAWQBtADkA
>> "%~1" echo eQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwA1AE8AVABsAHcAZQBEAHQA
>> "%~1" echo dwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEAZwBPAFgAQgA0AE8AMgBOAHYAYgBHADkA
>> "%~1" echo eQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsAVAB0AG0AYgAyADUA
>> "%~1" echo MABMAFgATgBwAGUAbQBVADYATQBUAEoAdwBlAEgAMAB1AFkAbQA5AGsAZQBYAHQA
>> "%~1" echo dwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUAMABjAEgAaAA5AEQAUQBvAHUAWgBHAFYA
>> "%~1" echo MgBhAFcATgBsAFUAMwBSAHkAYQBYAEIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAA
>> "%~1" echo bgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUA
>> "%~1" echo dABZADIAOQBzAGQAVwAxAHUAYwB6AG8AMwBNAEgAQgA0AEkARABGAG0AYwBpAEIA
>> "%~1" echo aABkAFgAUgB2AE8AMgBkAGgAYwBEAG8AeABOAEgAQgA0AE8AMgBGAHMAYQBXAGQA
>> "%~1" echo dQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMAbgAwAHUAWgBHAFYA
>> "%~1" echo MgBhAFcATgBsAFMAVwBOAHYAYgBuAHQAMwBhAFcAUgAwAGEARABvADMATQBIAEIA
>> "%~1" echo NABPADIAaABsAGEAVwBkAG8AZABEAG8AMwBNAEgAQgA0AE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBNAFQASgB3AGUARAB0AGsAYQBYAE4A
>> "%~1" echo dwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBjAEcAeABoAFkAMgBVAHQAYQBYAFIA
>> "%~1" echo bABiAFgATQA2AFkAMgBWAHUAZABHAFYAeQBPADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8AUwB3AHkATQB6AFUA
>> "%~1" echo cwBMAGoARQB3AEsAVAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEA
>> "%~1" echo aQBiAEgAVgBsAEsAWAAwAHUAWgBHAFYAMgBhAFcATgBsAFMAVwBOAHYAYgBpAEIA
>> "%~1" echo egBkAG0AZAA3AGQAMgBsAGsAZABHAGcANgBOAEQAUgB3AGUARAB0AG8AWgBXAGwA
>> "%~1" echo bgBhAEgAUQA2AE4ARABSAHcAZQBIADAAdQBaAEcAVgAyAGEAVwBOAGwAVABtAEYA
>> "%~1" echo dABaAFgAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0AagBCAHcAZQBEAHQA
>> "%~1" echo bQBiADIANQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwA0AE0ARABCADkATABtAGgA
>> "%~1" echo cABiAG4AUgA3AGIAVwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMARABvADMAYwBIAGcA
>> "%~1" echo NwBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEA
>> "%~1" echo cABPADIAeABwAGIAbQBVAHQAYQBHAFYAcABaADIAaAAwAE8AagBFAHUATgBUAFYA
>> "%~1" echo OQBMAG4ATgAwAFkAWABSAGwAZQAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8A
>> "%~1" echo eQBOAG4AQgA0AE8AMgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBqAGsA
>> "%~1" echo dwBNAEQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHkAWgBXAFEA
>> "%~1" echo cABmAFMANQB6AGQARwBGADAAWgBTADUAbgBiADIAOQBrAGUAMgBOAHYAYgBHADkA
>> "%~1" echo eQBPAG4AWgBoAGMAaQBnAHQATABXAGQAeQBaAFcAVgB1AEsAWAAwAHUAYwBtAGwA
>> "%~1" echo bgBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AYwBtAGwA
>> "%~1" echo awBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcATgB2AGIASABWAHQAYgBuAE0A
>> "%~1" echo NgBNAFcAWgB5AEkARABFAHUATgBHAFoAeQBJAEQARgBtAGMAagB0AG4AWQBYAEEA
>> "%~1" echo NgBNAFQASgB3AGUARAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQARwBWAHQAYwB6AHAA
>> "%~1" echo agBaAFcANQAwAFoAWABJADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8A
>> "%~1" echo eABOAEgAQgA0AGYAUwA1AGoAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAUQBtADkA
>> "%~1" echo NABlADIAMQBwAGIAaQAxAG8AWgBXAGwAbgBhAEgAUQA2AE4AegBoAHcAZQBEAHQA
>> "%~1" echo aQBiADMASgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoA
>> "%~1" echo aABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEA
>> "%~1" echo eQBZAFcAUgBwAGQAWABNADYATwBIAEIANABPADIASgBoAFkAMgB0AG4AYwBtADkA
>> "%~1" echo MQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrADcAYwBHAEYA
>> "%~1" echo awBaAEcAbAB1AFoAegBvAHgATQBIAEIANABJAEQARQB5AGMASABnADcAWgBHAGwA
>> "%~1" echo egBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADIARgBzAGEAVwBkAHUATABXAE4A
>> "%~1" echo dgBiAG4AUgBsAGIAbgBRADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBkAGgAYwBEAG8A
>> "%~1" echo MgBjAEgAaAA5AEwAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAEMAYgAzAGcA
>> "%~1" echo ZwBMAG4ASgB2AGIARwBWADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABiAFgAVgAwAFoAVwBRAHAATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8A
>> "%~1" echo eABNAG4AQgA0AGYAUwA1AGoAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAUQBtADkA
>> "%~1" echo NABJAEcASgA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBJAHcAYwBIAGgA
>> "%~1" echo OQBMAG0ATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBDAGIAMwBnAGcATABuAE4A
>> "%~1" echo MABZAFgAUgBsAFYARwBWADQAZABIAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUA
>> "%~1" echo NgBNAFQASgB3AGUARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEA
>> "%~1" echo dABkAFgAUgBsAFoAQwBsADkATABtAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoA
>> "%~1" echo QwBiADMAZwB1AGIARwBWAG0AZABIAHQAMABaAFgAaAAwAEwAVwBGAHMAYQBXAGQA
>> "%~1" echo dQBPAG0AeABsAFoAbgBRADcAWQBtADkAeQBaAEcAVgB5AEwAVwB4AGwAWgBuAFEA
>> "%~1" echo NgBNADMAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAEoA
>> "%~1" echo cwBkAFcAVQBwAGYAUwA1AGoAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAUQBtADkA
>> "%~1" echo NABMAG4ASgBwAFoAMgBoADAAZQAzAFIAbABlAEgAUQB0AFkAVwB4AHAAWgAyADQA
>> "%~1" echo NgBjAG0AbABuAGEASABRADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAHAAWgAyAGgA
>> "%~1" echo MABPAGoATgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEA
>> "%~1" echo aQBiAEgAVgBsAEsAWAAwAHUAYQBHAFYAaABaAEgATgBsAGQARQBKAHYAZQBIAHQA
>> "%~1" echo dABhAFcANAB0AGEARwBWAHAAWgAyAGgAMABPAGoAawB3AGMASABnADcAWQBtADkA
>> "%~1" echo eQBaAEcAVgB5AE8AagBGAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkA
>> "%~1" echo bwBMAFMAMQBzAGEAVwA1AGwASwBUAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYA
>> "%~1" echo awBhAFgAVgB6AE8AagBFAHcAYwBIAGcANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYA
>> "%~1" echo dQBaAEQAcABzAGEAVwA1AGwAWQBYAEkAdABaADMASgBoAFoARwBsAGwAYgBuAFEA
>> "%~1" echo bwBNAFQAZwB3AFoARwBWAG4ATABIAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsA
>> "%~1" echo cwBNAGoATQAxAEwAQwA0AHgATQBDAGsAcwBkAG0ARgB5AEsAQwAwAHQAYwAyADkA
>> "%~1" echo bQBkAEMAawBwAE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBEAHQA
>> "%~1" echo bgBjAG0AbABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYA
>> "%~1" echo dABiAG4ATQA2AE4AagBSAHcAZQBDAEEAeABaAG4ASQA3AFoAMgBGAHcATwBqAEUA
>> "%~1" echo eQBjAEgAZwA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAyAFYA
>> "%~1" echo dQBkAEcAVgB5AE8AMwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABKAHcAZQBIADAA
>> "%~1" echo TgBDAGkANQBrAFoAWABaAHAAWQAyAFYATgBaAFgAUgBoAGUAMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIA
>> "%~1" echo cwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AE0AVwBaAHkASQBEAEYA
>> "%~1" echo bQBjAGoAdABuAFkAWABBADYATQBUAEIAdwBlAEQAdAB0AFkAWABKAG4AYQBXADQA
>> "%~1" echo dABkAEcAOQB3AE8AagBFAHoAYwBIAGgAOQBMAG0AMQBsAGQARwBGAEoAZABHAFYA
>> "%~1" echo dABlADIAaABsAGEAVwBkAG8AZABEAG8AMQBNAG4AQgA0AE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGoAbwB4AGMASABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAA
>> "%~1" echo dABiAEcAbAB1AFoAUwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwA
>> "%~1" echo MQBjAHoAbwAzAGMASABnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAHoAYgAyAFoAMABLAFQAdAB3AFkAVwBSAGsAYQBXADUA
>> "%~1" echo bgBPAGoAbAB3AGUAQwBBAHgATQBuAEIANABmAFMANQB0AFoAWABSAGgAUwBYAFIA
>> "%~1" echo bABiAFMAQgB6AGMARwBGAHUAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWQBtAHgA
>> "%~1" echo dgBZADIAcwA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAYgBYAFYA
>> "%~1" echo MABaAFcAUQBwAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHgATQBuAEIA
>> "%~1" echo NABmAFMANQB0AFoAWABSAGgAUwBYAFIAbABiAFMAQgBpAGUAMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFkAbQB4AHYAWQAyAHMANwBiAFcARgB5AFoAMgBsAHUATABYAFIA
>> "%~1" echo dgBjAEQAbwAwAGMASABnADcAZAAyAGgAcABkAEcAVQB0AGMAMwBCAGgAWQAyAFUA
>> "%~1" echo NgBiAG0AOQAzAGMAbQBGAHcATwAyADkAMgBaAFgASgBtAGIARwA5ADMATwBtAGgA
>> "%~1" echo cABaAEcAUgBsAGIAagB0ADAAWgBYAGgAMABMAFcAOQAyAFoAWABKAG0AYgBHADkA
>> "%~1" echo MwBPAG0AVgBzAGIARwBsAHcAYwAyAGwAegBmAFEAMABLAEwAbQAxAGwAZABIAEoA
>> "%~1" echo cABZADAAZAB5AGEAVwBSADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwA
>> "%~1" echo awBPADIAZAB5AGEAVwBRAHQAZABHAFYAdABjAEcAeABoAGQARwBVAHQAWQAyADkA
>> "%~1" echo cwBkAFcAMQB1AGMAegBwAHkAWgBYAEIAbABZAFgAUQBvAE0AeQB3AHgAWgBuAEkA
>> "%~1" echo cABPADIAZABoAGMARABvAHgATQBIAEIANABmAFMANQB0AFoAWABSAHkAYQBXAE4A
>> "%~1" echo NwBhAEcAVgBwAFoAMgBoADAATwBqAEUAeABNAG4AQgA0AE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGoAbwB4AGMASABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAA
>> "%~1" echo dABiAEcAbAB1AFoAUwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwA
>> "%~1" echo MQBjAHoAbwA0AGMASABnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAHoAYgAyAFoAMABLAFQAdAB3AFkAVwBSAGsAYQBXADUA
>> "%~1" echo bgBPAGoARQB5AGMASABnADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG4AYwBtAGwA
>> "%~1" echo awBPADIAZAB5AGEAVwBRAHQAZABHAFYAdABjAEcAeABoAGQARwBVAHQAWQAyADkA
>> "%~1" echo cwBkAFcAMQB1AGMAegBvADIATwBIAEIANABJAEQARgBtAGMAagB0AGgAYgBHAGwA
>> "%~1" echo bgBiAGkAMQBwAGQARwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAWgAyAEYA
>> "%~1" echo dwBPAGoARQB3AGMASABoADkATABtADEAbABkAEgASgBwAFkAeQBCAHoAZABtAGMA
>> "%~1" echo dQBjAG0AbAB1AFoAMwB0ADMAYQBXAFIAMABhAEQAbwAyAE8ASABCADQATwAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvADIATwBIAEIANABPADMAUgB5AFkAVwA1AHoAWgBtADkA
>> "%~1" echo eQBiAFQAcAB5AGIAMwBSAGgAZABHAFUAbwBMAFQAawB3AFoARwBWAG4ASwBYADAA
>> "%~1" echo dQBkAEgASgBoAFkAMgB0ADcAWgBtAGwAcwBiAEQAcAB1AGIAMgA1AGwATwAzAE4A
>> "%~1" echo MABjAG0AOQByAFoAVABwAHkAWgAyAEoAaABLAEQARQAwAE8AQwB3AHgATgBqAE0A
>> "%~1" echo cwBNAFQAZwAwAEwAQwA0AHkATgBTAGsANwBjADMAUgB5AGIAMgB0AGwATABYAGQA
>> "%~1" echo cABaAEgAUgBvAE8AagBoADkATABtADEAbABkAEcAVgB5AGUAMgBaAHAAYgBHAHcA
>> "%~1" echo NgBiAG0AOQB1AFoAVAB0AHoAZABIAEoAdgBhADIAVQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABZAG0AeAAxAFoAUwBrADcAYwAzAFIAeQBiADIAdABsAEwAWABkAHAAWgBIAFIA
>> "%~1" echo bwBPAGoAZwA3AGMAMwBSAHkAYgAyAHQAbABMAFcAeABwAGIAbQBWAGoAWQBYAEEA
>> "%~1" echo NgBjAG0AOQAxAGIAbQBSADkATABtADEAbABkAEgASgBwAFkAeQA1AG4AYwBtAFYA
>> "%~1" echo bABiAGkAQQB1AGIAVwBWADAAWgBYAEoANwBjADMAUgB5AGIAMgB0AGwATwBuAFoA
>> "%~1" echo aABjAGkAZwB0AEwAVwBkAHkAWgBXAFYAdQBLAFgAMAB1AGIAVwBWADAAYwBtAGwA
>> "%~1" echo agBMAG0ARgB0AFkAbQBWAHkASQBDADUAdABaAFgAUgBsAGMAbgB0AHoAZABIAEoA
>> "%~1" echo dgBhADIAVQA2AGQAbQBGAHkASwBDADAAdABZAFcAMQBpAFoAWABJAHAAZgBTADUA
>> "%~1" echo dABaAFgAUgB5AGEAVwBNAHUAYwBtAFYAawBJAEMANQB0AFoAWABSAGwAYwBuAHQA
>> "%~1" echo egBkAEgASgB2AGEAMgBVADYAZABtAEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAA
>> "%~1" echo dQBiAFcAVgAwAGMAbQBsAGoAVgBtAEYAcwBkAFcAVgA3AFoAbQA5AHUAZABDADEA
>> "%~1" echo egBhAFgAcABsAE8AagBJAHoAYwBIAGcANwBaAG0AOQB1AGQAQwAxADMAWgBXAGwA
>> "%~1" echo bgBhAEgAUQA2AE8AVABBAHcATwAzAGQAbwBhAFgAUgBsAEwAWABOAHcAWQBXAE4A
>> "%~1" echo bABPAG0ANQB2AGQAMwBKAGgAYwBIADAAdQBiAFcAVgAwAGMAbQBsAGoAVABHAEYA
>> "%~1" echo aQBaAFcAeAA3AGIAVwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMARABvADIAYwBIAGcA
>> "%~1" echo NwBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEA
>> "%~1" echo cABPADIAWgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB4AE0AbgBCADQAZgBRADAA
>> "%~1" echo SwBMAG0AMQBwAGIAbQBsAEgAYwBtAGwAawBlADIAUgBwAGMAMwBCAHMAWQBYAGsA
>> "%~1" echo NgBaADMASgBwAFoARAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIA
>> "%~1" echo bABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBjAG0AVgB3AFoAVwBGADAASwBEAFEA
>> "%~1" echo cwBNAFcAWgB5AEsAVAB0AG4AWQBYAEEANgBNAFQAQgB3AGUASAAwAHUAYgBXAGwA
>> "%~1" echo dQBhAFgAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwA
>> "%~1" echo awBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAEgAQgA0AE8AMgBKAGgAWQAyAHQA
>> "%~1" echo bgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsA
>> "%~1" echo NwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABNAFgAQgA0AGYAUwA1AHQAYQBXADUA
>> "%~1" echo cABJAEgATgB3AFkAVwA1ADcAWgBHAGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkA
>> "%~1" echo agBhAHoAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIA
>> "%~1" echo bABaAEMAawA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGgA
>> "%~1" echo OQBMAG0AMQBwAGIAbQBrAGcAWQBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoA
>> "%~1" echo cwBiADIATgByAE8AMgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYATgBuAEIA
>> "%~1" echo NABPADMAZABvAGEAWABSAGwATABYAE4AdwBZAFcATgBsAE8AbQA1AHYAZAAzAEoA
>> "%~1" echo aABjAEQAdAB2AGQAbQBWAHkAWgBtAHgAdgBkAHoAcABvAGEAVwBSAGsAWgBXADQA
>> "%~1" echo NwBkAEcAVgA0AGQAQwAxAHYAZABtAFYAeQBaAG0AeAB2AGQAegBwAGwAYgBHAHgA
>> "%~1" echo cABjAEgATgBwAGMAMwAwAHUAYQBXADUAbQBiADAAZAB5AGEAVwBSADcAWgBHAGwA
>> "%~1" echo egBjAEcAeABoAGUAVABwAG4AYwBtAGwAawBPADIAZAB5AGEAVwBRAHQAZABHAFYA
>> "%~1" echo dABjAEcAeABoAGQARwBVAHQAWQAyADkAcwBkAFcAMQB1AGMAegBwAHkAWgBYAEIA
>> "%~1" echo bABZAFgAUQBvAE0AeQB3AHgAWgBuAEkAcABPADIAZABoAGMARABvAHgATQBIAEIA
>> "%~1" echo NABmAFMANQBwAGIAbQBaAHYAVgBHAGwAcwBaAFgAdABpAGIAMwBKAGsAWgBYAEkA
>> "%~1" echo NgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgA
>> "%~1" echo cABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0A
>> "%~1" echo NgBPAEgAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYA
>> "%~1" echo eQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBjAEcARgBrAFoARwBsAHUAWgB6AG8A
>> "%~1" echo eABNAFgAQgA0AE8AMgAxAHAAYgBpADEAbwBaAFcAbABuAGEASABRADYATgBUAGgA
>> "%~1" echo dwBlAEgAMAB1AGEAVwA1AG0AYgAxAFIAcABiAEcAVQBnAGMAMwBCAGgAYgBuAHQA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIATgByAE8AMgBOAHYAYgBHADkA
>> "%~1" echo eQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsAVAB0AG0AYgAyADUA
>> "%~1" echo MABMAFgATgBwAGUAbQBVADYATQBUAEoAdwBlAEgAMAB1AGEAVwA1AG0AYgAxAFIA
>> "%~1" echo cABiAEcAVQBnAFkAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBKAHMAYgAyAE4A
>> "%~1" echo cgBPADIAMQBoAGMAbQBkAHAAYgBpADEAMABiADMAQQA2AE4AWABCADQATwAzAGQA
>> "%~1" echo dgBjAG0AUQB0AFkAbgBKAGwAWQBXAHMANgBZAG4ASgBsAFkAVwBzAHQAZAAyADkA
>> "%~1" echo eQBaAEgAMAB1AFoAWABoAHcAYgAzAEoAMABRAG0AOQA0AGUAMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIA
>> "%~1" echo cwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AE0AVwBaAHkASQBHAEYA
>> "%~1" echo MQBkAEcAOAA3AFoAMgBGAHcATwBqAEUAeQBjAEgAZwA3AFkAVwB4AHAAWgAyADQA
>> "%~1" echo dABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcAVgB5AE8AMgBKAHYAYwBtAFIA
>> "%~1" echo bABjAGoAbwB4AGMASABnAGcAYwAyADkAcwBhAFcAUQBnAGMAbQBkAGkAWQBTAGcA
>> "%~1" echo egBOAHkAdwA1AE8AUwB3AHkATQB6AFUAcwBMAGoATQAxAEsAVAB0AGkAWQBXAE4A
>> "%~1" echo cgBaADMASgB2AGQAVwA1AGsATwBuAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsA
>> "%~1" echo cwBNAGoATQAxAEwAQwA0AHcATwBDAGsANwBZAG0AOQB5AFoARwBWAHkATABYAEoA
>> "%~1" echo aABaAEcAbAAxAGMAegBvADQAYwBIAGcANwBjAEcARgBrAFoARwBsAHUAWgB6AG8A
>> "%~1" echo eABNADMAQgA0AGYAUwA1AGwAZQBIAEIAdgBjAG4AUgBNAGEAVwA1AHIAYwAzAHQA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUQA3AFoAMgBGAHcATwBqAGgA
>> "%~1" echo dwBlAEgAMAB1AFoAWABoAHcAYgAzAEoAMABUAEcAbAB1AGEAMwBNAGcAWQBYAHQA
>> "%~1" echo agBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQBpAGIASABWAGwASwBUAHQA
>> "%~1" echo bQBiADIANQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwA1AE0ARABBADcAZAAyADkA
>> "%~1" echo eQBaAEMAMQBpAGMAbQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEAeQAxAGgAYgBHAHgA
>> "%~1" echo OQBMAG4AUgBoAFkAbQB4AGwAZQAzAGQAcABaAEgAUgBvAE8AagBFAHcATQBDAFUA
>> "%~1" echo NwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAeABoAGMASABOAGwATwBtAE4A
>> "%~1" echo dgBiAEcAeABoAGMASABOAGwAZgBTADUAMABZAFcASgBzAFoAUwBCADAAWgBIAHQA
>> "%~1" echo aQBiADMASgBrAFoAWABJAHQAWQBtADkAMABkAEcAOQB0AE8AagBGAHcAZQBDAEIA
>> "%~1" echo egBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQA
>> "%~1" echo dwBZAFcAUgBrAGEAVwA1AG4ATwBqAGwAdwBlAEMAQQB3AE8AMgBOAHYAYgBHADkA
>> "%~1" echo eQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsAVAB0ADIAWgBYAEoA
>> "%~1" echo MABhAFcATgBoAGIAQwAxAGgAYgBHAGwAbgBiAGoAcAAwAGIAMwBCADkATABuAFIA
>> "%~1" echo aABZAG0AeABsAEkASABSAHkATwBtAHgAaABjADMAUQB0AFkAMgBoAHAAYgBHAFEA
>> "%~1" echo ZwBkAEcAUgA3AFkAbQA5AHkAWgBHAFYAeQBMAFcASgB2AGQASABSAHYAYgBUAG8A
>> "%~1" echo dwBmAFMANQAwAFkAVwBKAHMAWgBTAEIAMABaAEQAcABzAFkAWABOADAATABXAE4A
>> "%~1" echo bwBhAFcAeABrAGUAMwBSAGwAZQBIAFEAdABZAFcAeABwAFoAMgA0ADYAYwBtAGwA
>> "%~1" echo bgBhAEgAUQA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAZABHAFYA
>> "%~1" echo NABkAEMAawA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATgB6AEEA
>> "%~1" echo dwBPADMAZAB2AGMAbQBRAHQAWQBuAEoAbABZAFcAcwA2AFkAbgBKAGwAWQBXAHMA
>> "%~1" echo dABkADIAOQB5AFoASAAwAE4AQwBpADUAagBiAFcAUgBIAGMAbQBsAGsAZQAyAFIA
>> "%~1" echo cABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIA
>> "%~1" echo bABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYAYwBtAFYA
>> "%~1" echo dwBaAFcARgAwAEsARABJAHMAYgBXAGwAdQBiAFcARgA0AEsARABBAHMATQBXAFoA
>> "%~1" echo eQBLAFMAawA3AFoAMgBGAHcATwBqAEUAdwBjAEgAaAA5AEwAbQBOAHQAWgBIAHQA
>> "%~1" echo bwBaAFcAbABuAGEASABRADYATgBUAGgAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkA
>> "%~1" echo NgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgA
>> "%~1" echo cABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQBzAFoAVwBaADAATwBqAE4A
>> "%~1" echo dwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUA
>> "%~1" echo bABLAFQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcA
>> "%~1" echo dABMAFgATgB2AFoAbgBRAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIA
>> "%~1" echo cABkAFgATQA2AE4AMwBCADQATwAzAFIAbABlAEgAUQB0AFkAVwB4AHAAWgAyADQA
>> "%~1" echo NgBiAEcAVgBtAGQARAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBsAHcAZQBDAEEA
>> "%~1" echo eABNAFgAQgA0AE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIA
>> "%~1" echo bABlAEgAUQBwAE8AMgBOADEAYwBuAE4AdgBjAGoAcAB3AGIAMgBsAHUAZABHAFYA
>> "%~1" echo eQBmAFMANQBqAGIAVwBRAGcAWQBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoA
>> "%~1" echo cwBiADIATgByAGYAUwA1AGoAYgBXAFEAZwBjADMAQgBoAGIAbgB0AGsAYQBYAE4A
>> "%~1" echo dwBiAEcARgA1AE8AbQBKAHMAYgAyAE4AcgBPADIAMQBoAGMAbQBkAHAAYgBpADEA
>> "%~1" echo MABiADMAQQA2AE4ASABCADQATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcA
>> "%~1" echo dABMAFcAMQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUA
>> "%~1" echo NgBNAFQASgB3AGUASAAwAHUAWQAyADEAawBMAG0ASgBzAGQAVwBWADcAWQBtADkA
>> "%~1" echo eQBaAEcAVgB5AEwAVwB4AGwAWgBuAFEAdABZADIAOQBzAGIAMwBJADYAZABtAEYA
>> "%~1" echo eQBLAEMAMAB0AFkAbQB4ADEAWgBTAGwAOQBMAG0ATgB0AFoAQwA1AG4AYwBtAFYA
>> "%~1" echo bABiAG4AdABpAGIAMwBKAGsAWgBYAEkAdABiAEcAVgBtAGQAQwAxAGoAYgAyAHgA
>> "%~1" echo dgBjAGoAcAAyAFkAWABJAG8ATABTADEAbgBjAG0AVgBsAGIAaQBsADkATABtAE4A
>> "%~1" echo dABaAEMANQBoAGIAVwBKAGwAYwBuAHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYA
>> "%~1" echo bQBkAEMAMQBqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAGgAYgBXAEoA
>> "%~1" echo bABjAGkAbAA5AEwAbQBOAHQAWgBDADUAeQBaAFcAUgA3AFkAbQA5AHkAWgBHAFYA
>> "%~1" echo eQBMAFcAeABsAFoAbgBRAHQAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABjAG0AVgBrAEsAWAAwAE4AQwBpADUAbQBiADMASgB0AGUAMgBSAHAAYwAzAEIA
>> "%~1" echo cwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIA
>> "%~1" echo cwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AE0AVABNAHcAYwBIAGcA
>> "%~1" echo ZwBNAFcAWgB5AEkARABGAG0AYwBpAEEANABNAG4AQgA0AE8AMgBkAGgAYwBEAG8A
>> "%~1" echo NQBjAEgAaAA5AGEAVwA1AHcAZABYAFEAcwBjADIAVgBzAFoAVwBOADAAZQAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABvAHoATgBuAEIANABPADIASgB2AGMAbQBSAGwAYwBqAG8A
>> "%~1" echo eABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwA
>> "%~1" echo dQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8A
>> "%~1" echo MwBjAEgAZwA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkA
>> "%~1" echo bwBMAFMAMQB6AGIAMgBaADAASwBUAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkA
>> "%~1" echo bwBMAFMAMQAwAFoAWABoADAASwBUAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEA
>> "%~1" echo ZwBNAFQAQgB3AGUASAAwAHUAYgBHADkAbgBlADMAZABvAGEAWABSAGwATABYAE4A
>> "%~1" echo dwBZAFcATgBsAE8AbgBCAHkAWgBTADEAMwBjAG0ARgB3AE8AMgAxAHAAYgBpADEA
>> "%~1" echo bwBaAFcAbABuAGEASABRADYATwBEAEIAdwBlAEQAdABqAGIAMgB4AHYAYwBqAHAA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABDADEA
>> "%~1" echo bQBZAFcAMQBwAGIASABrADYAUQAyADkAdQBjADIAOQBzAFkAWABNAHMASQBrADEA
>> "%~1" echo cABZADMASgB2AGMAMgA5AG0AZABDAEIAWgBZAFUAaABsAGEAUwBJAHMAYgBXADkA
>> "%~1" echo dQBiADMATgB3AFkAVwBOAGwATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgA
>> "%~1" echo MABPAGoARQB1AE4AVABWADkARABRAG8AdQBkAEcAOQBoAGMAMwBSAHoAZQAzAEIA
>> "%~1" echo dgBjADIAbAAwAGEAVwA5AHUATwBtAFoAcABlAEcAVgBrAE8AMwBKAHAAWgAyAGgA
>> "%~1" echo MABPAGoASQB5AGMASABnADcAWQBtADkAMABkAEcAOQB0AE8AagBJAHkAYwBIAGcA
>> "%~1" echo NwBlAGkAMQBwAGIAbQBSAGwAZQBEAG8AegBNAEQAdABrAGEAWABOAHcAYgBHAEYA
>> "%~1" echo NQBPAG0AWgBzAFoAWABnADcAWgBtAHgAbABlAEMAMQBrAGEAWABKAGwAWQAzAFIA
>> "%~1" echo cABiADIANAA2AFkAMgA5AHMAZABXADEAdQBMAFgASgBsAGQAbQBWAHkAYwAyAFUA
>> "%~1" echo NwBaADIARgB3AE8AagBFAHcAYwBIAGcANwBkADIAbABrAGQARwBnADYAYgBXAGwA
>> "%~1" echo dQBLAEQATQA1AE0ASABCADQATABHAE4AaABiAEcATQBvAE0AVABBAHcAZABuAGMA
>> "%~1" echo ZwBMAFMAQQB5AE8ASABCADQASwBTAGsANwBjAEcAOQBwAGIAbgBSAGwAYwBpADEA
>> "%~1" echo bABkAG0AVgB1AGQASABNADYAYgBtADkAdQBaAFgAMAB1AGQARwA5AGgAYwAzAFIA
>> "%~1" echo NwBZAG0AOQB5AFoARwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIA
>> "%~1" echo MgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkA
>> "%~1" echo dABiAEcAVgBtAGQARABvADAAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYA
>> "%~1" echo eQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYA
>> "%~1" echo dQBaAEQAcAAyAFkAWABJAG8ATABTADEAagBZAFgASgBrAEsAVAB0AGkAYgAzAGcA
>> "%~1" echo dABjADIAaABoAFoARwA5ADMATwBqAEEAZwBNAFQAWgB3AGUAQwBBAHoATwBIAEIA
>> "%~1" echo NABJAEgASgBuAFkAbQBFAG8ATQBUAFUAcwBNAGoATQBzAE4ARABJAHMATABqAEkA
>> "%~1" echo dwBLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBqAGgA
>> "%~1" echo dwBlAEQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoARQB4AGMASABnAGcATQBUAEoA
>> "%~1" echo dwBlAEQAdAB2AGMARwBGAGoAYQBYAFIANQBPAGoAQQA3AGQASABKAGgAYgBuAE4A
>> "%~1" echo bQBiADMASgB0AE8AbgBSAHkAWQBXADUAegBiAEcARgAwAFoAVgBnAG8ATQBqAFIA
>> "%~1" echo dwBlAEMAawBnAGQASABKAGgAYgBuAE4AcwBZAFgAUgBsAFcAUwBnAHgATQBIAEIA
>> "%~1" echo NABLAFMAQgB6AFkAMgBGAHMAWgBTAGcAdQBPAFQAZwBwAE8AMwBSAHkAWQBXADUA
>> "%~1" echo egBhAFgAUgBwAGIAMgA0ADYAYgAzAEIAaABZADIAbAAwAGUAUwBBAHUATQBqAEoA
>> "%~1" echo egBJAEcAVgBoAGMAMgBVAHMAZABIAEoAaABiAG4ATgBtAGIAMwBKAHQASQBDADQA
>> "%~1" echo eQBNAG4ATQBnAFkAMwBWAGkAYQBXAE0AdABZAG0AVgA2AGEAVwBWAHkASwBDADQA
>> "%~1" echo eQBMAEMANAA0AEwAQwA0AHkATABEAEUAcABPADIATgB2AGIARwA5AHkATwBuAFoA
>> "%~1" echo aABjAGkAZwB0AEwAWABSAGwAZQBIAFEAcABPADMAQgB2AGEAVwA1ADAAWgBYAEkA
>> "%~1" echo dABaAFgAWgBsAGIAbgBSAHoATwBtAEYAMQBkAEcAOQA5AEwAbgBSAHYAWQBYAE4A
>> "%~1" echo MABMAG4ATgBvAGIAMwBkADcAYgAzAEIAaABZADIAbAAwAGUAVABvAHgATwAzAFIA
>> "%~1" echo eQBZAFcANQB6AFoAbQA5AHkAYgBUAHAAMABjAG0ARgB1AGMAMgB4AGgAZABHAFYA
>> "%~1" echo WQBLAEQAQQBwAEkASABSAHkAWQBXADUAegBiAEcARgAwAFoAVgBrAG8ATQBDAGsA
>> "%~1" echo ZwBjADIATgBoAGIARwBVAG8ATQBTAGwAOQBMAG4AUgB2AFkAWABOADAASQBHAEoA
>> "%~1" echo NwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEAegB0AHQAWQBYAEoA
>> "%~1" echo bgBhAFcANAB0AFkAbQA5ADAAZABHADkAdABPAGoAUgB3AGUASAAwAHUAZABHADkA
>> "%~1" echo aABjADMAUQBnAGMAMwBCAGgAYgBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoA
>> "%~1" echo cwBiADIATgByAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXADEA
>> "%~1" echo MQBkAEcAVgBrAEsAVAB0AHMAYQBXADUAbABMAFcAaABsAGEAVwBkAG8AZABEAG8A
>> "%~1" echo eABMAGoAUQAxAE8AMwBkAHYAYwBtAFEAdABZAG4ASgBsAFkAVwBzADYAWQBuAEoA
>> "%~1" echo bABZAFcAcwB0AGQAMgA5AHkAWgBIADAAdQBkAEcAOQBoAGMAMwBRAHUAYgAyAHQA
>> "%~1" echo NwBZAG0AOQB5AFoARwBWAHkATABXAHgAbABaAG4AUQB0AFkAMgA5AHMAYgAzAEkA
>> "%~1" echo NgBkAG0ARgB5AEsAQwAwAHQAWgAzAEoAbABaAFcANABwAGYAUwA1ADAAYgAyAEYA
>> "%~1" echo egBkAEMANQBsAGMAbgBKADcAWQBtADkAeQBaAEcAVgB5AEwAVwB4AGwAWgBuAFEA
>> "%~1" echo dABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAA
>> "%~1" echo dQBkAEcAOQBoAGMAMwBRAHUAZAAyAEYAeQBiAG4AdABpAGIAMwBKAGsAWgBYAEkA
>> "%~1" echo dABiAEcAVgBtAGQAQwAxAGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEA
>> "%~1" echo aABiAFcASgBsAGMAaQBsADkATABuAEIAaABjAG0ARgB0AFQARwBsAHoAZABIAHQA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUQA3AFoAMgBGAHcATwBqAEUA
>> "%~1" echo dwBjAEgAaAA5AEwAbgBCAGgAYwBtAEYAdABTAFgAUgBsAGIAWAB0AGsAYQBYAE4A
>> "%~1" echo dwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMASgBwAFoAQwAxADAAWgBXADEA
>> "%~1" echo dwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8AagBFAHUATQBtAFoA
>> "%~1" echo eQBJAEMANAA0AFoAbgBJAGcATABqAGgAbQBjAGkAQgBoAGQAWABSAHYATwAyAGQA
>> "%~1" echo aABjAEQAbwB4AE0ASABCADQATwAyAEYAcwBhAFcAZAB1AEwAVwBsADAAWgBXADEA
>> "%~1" echo egBPAG0ATgBsAGIAbgBSAGwAYwBqAHQAaQBiADMASgBrAFoAWABJADYATQBYAEIA
>> "%~1" echo NABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUA
>> "%~1" echo cABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABjADIAOQBtAGQAQwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwA
>> "%~1" echo MQBjAHoAbwA0AGMASABnADcAYwBHAEYAawBaAEcAbAB1AFoAegBvAHgATQBIAEIA
>> "%~1" echo NABJAEQARQB5AGMASABoADkATABuAEIAaABjAG0ARgB0AFQAbQBGAHQAWgBTAEIA
>> "%~1" echo aQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgB0ADkATABuAEIA
>> "%~1" echo aABjAG0ARgB0AFQAbQBGAHQAWgBTAEIAegBjAEcARgB1AEwAQwA1AHcAWQBYAEoA
>> "%~1" echo aABiAFYAWgBoAGIASABWAGwASQBIAE4AdwBZAFcANQA3AFoARwBsAHoAYwBHAHgA
>> "%~1" echo aABlAFQAcABpAGIARwA5AGoAYQB6AHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkA
>> "%~1" echo bwBMAFMAMQB0AGQAWABSAGwAWgBDAGsANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAA
>> "%~1" echo bABPAGoARQB5AGMASABnADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8A
>> "%~1" echo egBjAEgAaAA5AEwAbgBCAGgAYwBtAEYAdABWAG0ARgBzAGQAVwBVAGcAWQBuAHQA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIATgByAE8AMwBkAHYAYwBtAFEA
>> "%~1" echo dABZAG4ASgBsAFkAVwBzADYAWQBuAEoAbABZAFcAcwB0AGQAMgA5AHkAWgBIADAA
>> "%~1" echo dQBjAEcARgB5AFkAVwAxAFQAZABHAEYAMABaAFgAdABvAFoAVwBsAG4AYQBIAFEA
>> "%~1" echo NgBNAGoAWgB3AGUARAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBIAE4A
>> "%~1" echo dgBiAEcAbABrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAEoA
>> "%~1" echo dgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8AVABrADUAYwBIAGcA
>> "%~1" echo NwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAcABiAG0AeABwAGIAbQBVAHQAWgBtAHgA
>> "%~1" echo bABlAEQAdABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMAegBwAGoAWgBXADUA
>> "%~1" echo MABaAFgASQA3AGEAbgBWAHoAZABHAGwAbQBlAFMAMQBqAGIAMgA1ADAAWgBXADUA
>> "%~1" echo MABPAG0ATgBsAGIAbgBSAGwAYwBqAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEA
>> "%~1" echo ZwBNAFQAQgB3AGUARAB0AG0AYgAyADUAMABMAFgAZABsAGEAVwBkAG8AZABEAG8A
>> "%~1" echo NABNAEQAQQA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGgA
>> "%~1" echo OQBMAG4AQgBoAGMAbQBGAHQAUwBYAFIAbABiAFMANQBqAGEARwBGAHUAWgAyAFYA
>> "%~1" echo awBlADIASgB2AGMAbQBSAGwAYwBpADEAagBiADIAeAB2AGMAagBwAHkAWgAyAEoA
>> "%~1" echo aABLAEQASQB4AE4AeQB3AHgATQBUAGsAcwBOAGkAdwB1AE4ARABVAHAATwAyAEoA
>> "%~1" echo aABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBjAG0AZABpAFkAUwBnAHkATQBUAGMA
>> "%~1" echo cwBNAFQARQA1AEwARABZAHMATABqAEEAMgBLAFgAMAB1AGMARwBGAHkAWQBXADEA
>> "%~1" echo SgBkAEcAVgB0AEwAbQBOAG8AWQBXADUAbgBaAFcAUQBnAEwAbgBCAGgAYwBtAEYA
>> "%~1" echo dABVADMAUgBoAGQARwBWADcAWQBtADkAeQBaAEcAVgB5AEwAVwBOAHYAYgBHADkA
>> "%~1" echo eQBPAG4ASgBuAFkAbQBFAG8ATQBqAEUAMwBMAEQARQB4AE8AUwB3ADIATABDADQA
>> "%~1" echo MABOAFMAawA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBXADEA
>> "%~1" echo aQBaAFgASQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQA
>> "%~1" echo aQBZAFMAZwB5AE0AVABjAHMATQBUAEUANQBMAEQAWQBzAEwAagBBADQASwBYADAA
>> "%~1" echo dQBjAEcARgB5AFkAVwAxAEoAZABHAFYAdABMAG0AOQByAEkAQwA1AHcAWQBYAEoA
>> "%~1" echo aABiAFYATgAwAFkAWABSAGwAZQAyAEoAdgBjAG0AUgBsAGMAaQAxAGoAYgAyAHgA
>> "%~1" echo dgBjAGoAcAB5AFoAMgBKAGgASwBEAEkAeQBMAEQARQAyAE0AeQB3ADMATgBDAHcA
>> "%~1" echo dQBNAHoAVQBwAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXAGQA
>> "%~1" echo eQBaAFcAVgB1AEsAVAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBuAEoA
>> "%~1" echo bgBZAG0ARQBvAE0AagBJAHMATQBUAFkAegBMAEQAYwAwAEwAQwA0AHcATwBDAGwA
>> "%~1" echo OQBMAG4ASgBsAGMAMgBWADAAUQBuAFIAdQBlADIAaABsAGEAVwBkAG8AZABEAG8A
>> "%~1" echo egBNAEgAQgA0AE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0A
>> "%~1" echo NgBOADMAQgA0AE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMASABnAGcAYwAyADkA
>> "%~1" echo cwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoAUwBrADcAWQBtAEYA
>> "%~1" echo agBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAGoAWQBYAEoA
>> "%~1" echo awBLAFQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxADAAWgBYAGgA
>> "%~1" echo MABLAFQAdABtAGIAMgA1ADAATABYAGQAbABhAFcAZABvAGQARABvADQATQBEAEEA
>> "%~1" echo NwBjAEcARgBrAFoARwBsAHUAWgB6AG8AdwBJAEQARQB3AGMASABnADcAWQAzAFYA
>> "%~1" echo eQBjADIAOQB5AE8AbgBCAHYAYQBXADUAMABaAFgASgA5AEwAbgBKAGwAYwAyAFYA
>> "%~1" echo MABRAG4AUgB1AEwAbgBCAHkAYQBXADEAaABjAG4AbAA3AFkAbQA5AHkAWgBHAFYA
>> "%~1" echo eQBMAFcATgB2AGIARwA5AHkATwBuAEoAbgBZAG0ARQBvAE0AegBjAHMATwBUAGsA
>> "%~1" echo cwBNAGoATQAxAEwAQwA0ADAATgBTAGsANwBZADIAOQBzAGIAMwBJADYAZABtAEYA
>> "%~1" echo eQBLAEMAMAB0AFkAbQB4ADEAWgBTAGwAOQBMAG0AMQB2AFoARwBGAHMAVABXAEYA
>> "%~1" echo egBhADMAdAB3AGIAMwBOAHAAZABHAGwAdgBiAGoAcABtAGEAWABoAGwAWgBEAHQA
>> "%~1" echo cABiAG4ATgBsAGQARABvAHcATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEA
>> "%~1" echo NgBjAG0AZABpAFkAUwBnAHkATABEAFkAcwBNAGoATQBzAEwAagBVADIASwBUAHQA
>> "%~1" echo NgBMAFcAbAB1AFoARwBWADQATwBqAFEAdwBPADIAUgBwAGMAMwBCAHMAWQBYAGsA
>> "%~1" echo NgBiAG0AOQB1AFoAVAB0AHcAYgBHAEYAagBaAFMAMQBwAGQARwBWAHQAYwB6AHAA
>> "%~1" echo agBaAFcANQAwAFoAWABJADcAYwBHAEYAawBaAEcAbAB1AFoAegBvAHgATwBIAEIA
>> "%~1" echo NABmAFMANQB0AGIAMgBSAGgAYgBFADEAaABjADIAcwB1AGMAMgBoAHYAZAAzAHQA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcAUgA5AEwAbQAxAHYAWgBHAEYA
>> "%~1" echo cwBlADMAZABwAFoASABSAG8ATwBtADEAcABiAGkAZwAwAE4AagBCAHcAZQBDAHcA
>> "%~1" echo eABNAEQAQQBsAEsAVAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBuAFoA
>> "%~1" echo aABjAGkAZwB0AEwAVwBOAGgAYwBtAFEAcABPADIASgB2AGMAbQBSAGwAYwBqAG8A
>> "%~1" echo eABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwA
>> "%~1" echo dQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8A
>> "%~1" echo eABNAEgAQgA0AE8AMgBKAHYAZQBDADEAegBhAEcARgBrAGIAMwBjADYATQBDAEEA
>> "%~1" echo eQBOAEgAQgA0AEkARABjAHcAYwBIAGcAZwBjAG0AZABpAFkAUwBnAHcATABEAEEA
>> "%~1" echo cwBNAEMAdwB1AE0AegBVAHAATwAzAEIAaABaAEcAUgBwAGIAbQBjADYATQBUAGgA
>> "%~1" echo dwBlAEgAMAB1AGIAVwA5AGsAWQBXAHcAZwBhAEQATgA3AGIAVwBGAHkAWgAyAGwA
>> "%~1" echo dQBPAGoAQQBnAE0AQwBBADQAYwBIAGcANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAA
>> "%~1" echo bABPAGoARQA0AGMASABoADkATABtADEAdgBaAEcARgBzAEkASABCADcAYgBXAEYA
>> "%~1" echo eQBaADIAbAB1AE8AagBBADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABiAFgAVgAwAFoAVwBRAHAATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgA
>> "%~1" echo MABPAGoARQB1AE4AagBWADkATABtADEAdgBaAEcARgBzAFEAVwBOADAAYQBXADkA
>> "%~1" echo dQBjADMAdABrAGEAWABOAHcAYgBHAEYANQBPAG0AWgBzAFoAWABnADcAYQBuAFYA
>> "%~1" echo egBkAEcAbABtAGUAUwAxAGoAYgAyADUAMABaAFcANQAwAE8AbQBaAHMAWgBYAGcA
>> "%~1" echo dABaAFcANQBrAE8AMgBkAGgAYwBEAG8AeABNAEgAQgA0AE8AMgAxAGgAYwBtAGQA
>> "%~1" echo cABiAGkAMQAwAGIAMwBBADYATQBUAGgAdwBlAEgAMAB1AGIAVwA5AGsAWQBXAHgA
>> "%~1" echo QgBZADMAUgBwAGIAMgA1AHoASQBHAEoAMQBkAEgAUgB2AGIAbgB0AG8AWgBXAGwA
>> "%~1" echo bgBhAEgAUQA2AE0AegBSAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYA
>> "%~1" echo awBhAFgAVgB6AE8AagBkAHcAZQBEAHQAaQBiADMASgBrAFoAWABJADYATQBYAEIA
>> "%~1" echo NABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUA
>> "%~1" echo cABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABjADIAOQBtAGQAQwBrADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAA
>> "%~1" echo dABkAEcAVgA0AGQAQwBrADcAYwBHAEYAawBaAEcAbAB1AFoAegBvAHcASQBEAEUA
>> "%~1" echo egBjAEgAZwA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATwBEAEEA
>> "%~1" echo dwBPADIATgAxAGMAbgBOAHYAYwBqAHAAdwBiADIAbAB1AGQARwBWAHkAZgBTADUA
>> "%~1" echo dABiADIAUgBoAGIARQBGAGoAZABHAGwAdgBiAG4ATQBnAEwAbQBSAGgAYgBtAGQA
>> "%~1" echo bABjAG4AdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcA
>> "%~1" echo dABMAFcARgB0AFkAbQBWAHkASwBUAHQAaQBiADMASgBrAFoAWABJAHQAWQAyADkA
>> "%~1" echo cwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAFcAMQBpAFoAWABJAHAATwAyAE4A
>> "%~1" echo dgBiAEcAOQB5AE8AaQBNAHgATQBUAEUANABNAGoAZAA5AEwAbQBOAHQAWgBDADUA
>> "%~1" echo cABjAHkAMQBpAGQAWABOADUATABDADUAaQBkAEcANAB1AGEAWABNAHQAWQBuAFYA
>> "%~1" echo egBlAFgAdAB2AGMARwBGAGoAYQBYAFIANQBPAGkANAAyAE8ARAB0AGoAZABYAEoA
>> "%~1" echo egBiADMASQA2AGQAMgBGAHAAZABIADAAdQBZADIAMQBrAE8AbQBSAHAAYwAyAEYA
>> "%~1" echo aQBiAEcAVgBrAEwAQwA1AGkAZABHADQANgBaAEcAbAB6AFkAVwBKAHMAWgBXAFEA
>> "%~1" echo cwBMAG4ASgBsAGMAMgBWADAAUQBuAFIAdQBPAG0AUgBwAGMAMgBGAGkAYgBHAFYA
>> "%~1" echo awBlADMAQgB2AGEAVwA1ADAAWgBYAEkAdABaAFgAWgBsAGIAbgBSAHoATwBtADUA
>> "%~1" echo dgBiAG0AVgA5AEQAUQBwAEEAYgBXAFYAawBhAFcARQBvAGIAVwBGADQATABYAGQA
>> "%~1" echo cABaAEgAUgBvAE8AagBFAHgATwBEAEIAdwBlAEMAbAA3AEwAbgBKAHYAZAB5AHcA
>> "%~1" echo dQBjAG0AOQAzAE0AMwB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIA
>> "%~1" echo bABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AGYAUwA1AHAAYgBtAFoA
>> "%~1" echo dgBSADMASgBwAFoASAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIA
>> "%~1" echo bABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AEkARABGAG0AYwBuADEA
>> "%~1" echo OQBRAEcAMQBsAFoARwBsAGgASwBHADEAaABlAEMAMQAzAGEAVwBSADAAYQBEAG8A
>> "%~1" echo NABNAGoAQgB3AGUAQwBsADcATABtAEYAdwBjAEgAdABuAGMAbQBsAGsATABYAFIA
>> "%~1" echo bABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBXAFoA
>> "%~1" echo eQBmAFMANQB6AGEAVwBSAGwAZQAzAEIAdgBjADIAbAAwAGEAVwA5AHUATwBuAE4A
>> "%~1" echo MABZAFgAUgBwAFkAegB0ADMAYQBXAFIAMABhAEQAcABoAGQAWABSAHYATwAyAGgA
>> "%~1" echo bABhAFcAZABvAGQARABwAGgAZABYAFIAdgBmAFMANQB0AFkAVwBsAHUAZQAyAGQA
>> "%~1" echo eQBhAFcAUQB0AFkAMgA5AHMAZABXADEAdQBPAGoARgA5AEwAbgBSAHYAYwBIAHQA
>> "%~1" echo dwBiADMATgBwAGQARwBsAHYAYgBqAHAAegBkAEcARgAwAGEAVwBNADcAYQBHAFYA
>> "%~1" echo cABaADIAaAAwAE8AbQBGADEAZABHADgANwBZAFcAeABwAFoAMgA0AHQAYQBYAFIA
>> "%~1" echo bABiAFgATQA2AFoAbQB4AGwAZQBDADEAegBkAEcARgB5AGQARAB0AG0AYgBHAFYA
>> "%~1" echo NABMAFcAUgBwAGMAbQBWAGoAZABHAGwAdgBiAGoAcABqAGIAMgB4ADEAYgBXADQA
>> "%~1" echo NwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABOAG4AQgA0AGYAUwA1ADMAYwBtAEYA
>> "%~1" echo dwBlADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQAUgB3AGUASAAwAHUAYgBXAFYA
>> "%~1" echo MABjAG0AbABqAFIAMwBKAHAAWgBDAHcAdQBiAFcAbAB1AGEAVQBkAHkAYQBXAFEA
>> "%~1" echo cwBMAG0ATgB0AFoARQBkAHkAYQBXAFEAcwBMAG0AWgB2AGMAbQAwAHMATABuAEIA
>> "%~1" echo aABjAG0ARgB0AFMAWABSAGwAYgBTAHcAdQBhAFcANQBtAGIAMABkAHkAYQBXAFEA
>> "%~1" echo cwBMAG0AVgA0AGMARwA5AHkAZABFAEoAdgBlAEgAdABuAGMAbQBsAGsATABYAFIA
>> "%~1" echo bABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBXAFoA
>> "%~1" echo eQBmAFMANQAwAGIAMgBGAHoAZABIAE4ANwBjAG0AbABuAGEASABRADYATQBUAFIA
>> "%~1" echo dwBlAEQAdABpAGIAMwBSADAAYgAyADAANgBNAFQAUgB3AGUASAAxADkARABRAG8A
>> "%~1" echo OABMADMATgAwAGUAVwB4AGwAUABnADAASwBQAEMAOQBvAFoAVwBGAGsAUABnADAA
>> "%~1" echo SwBQAEcASgB2AFoASABrAGcAWQAyAHgAaABjADMATQA5AEkAbQBSAGgAYwBtAHMA
>> "%~1" echo aQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbgBSAHYAWQBYAE4A
>> "%~1" echo MABjAHkASQBnAGEAVwBRADkASQBuAFIAdgBZAFgATgAwAGMAeQBJACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBXADkA
>> "%~1" echo awBZAFcAeABOAFkAWABOAHIASQBpAEIAcABaAEQAMABpAFkAMgA5AHUAWgBtAGwA
>> "%~1" echo eQBiAFUAMQBoAGMAMgBzAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG0AMQB2AFoARwBGAHMASQBqADQAOABhAEQATQBnAGEAVwBRADkASQBtAE4A
>> "%~1" echo dgBiAG0AWgBwAGMAbQAxAFUAYQBYAFIAcwBaAFMASQArADUANgBHAHUANgBLADYA
>> "%~1" echo awA1AG8AbQBuADYASwBHAE0AUABDADkAbwBNAHoANAA4AGMAQwBCAHAAWgBEADAA
>> "%~1" echo aQBZADIAOQB1AFoAbQBsAHkAYgBVADEAegBaAHkASQArADYATAArAFoANQBMAGkA
>> "%~1" echo cQA1AHAATwBOADUATAAyAGMANQBMAHkAYQA1AEwAKwB1ADUAcABTADUASQBGAEYA
>> "%~1" echo MQBaAFgATgAwAEkATwBlAEsAdAB1AGEAQQBnAGUATwBBAGcAagB3AHYAYwBEADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB0AGIAMgBSAGgAYgBFAEYA
>> "%~1" echo agBkAEcAbAB2AGIAbgBNAGkAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAYQBXAFEA
>> "%~1" echo OQBJAG0ATgB2AGIAbQBaAHAAYwBtADEARABZAFcANQBqAFoAVwB3AGkAUAB1AFcA
>> "%~1" echo UABsAHUAYQAyAGkARAB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB4AGkAZABYAFIA
>> "%~1" echo MABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0AUgBoAGIAbQBkAGwAYwBpAEkA
>> "%~1" echo ZwBhAFcAUQA5AEkAbQBOAHYAYgBtAFoAcABjAG0AMQBQAGEAeQBJACsANQA2AEcA
>> "%~1" echo dQA2AEsANgBrADUAbwBtAG4ANgBLAEcATQBQAEMAOQBpAGQAWABSADAAYgAyADQA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBEAFEAbwA4AGMAMwBaAG4ASQBIAGQAcABaAEgAUgBvAFAAUwBJAHcASQBpAEIA
>> "%~1" echo bwBaAFcAbABuAGEASABRADkASQBqAEEAaQBJAEgATgAwAGUAVwB4AGwAUABTAEoA
>> "%~1" echo dwBiADMATgBwAGQARwBsAHYAYgBqAHAAaABZAG4ATgB2AGIASABWADAAWgBTAEkA
>> "%~1" echo KwBQAEgATgA1AGIAVwBKAHYAYgBDAEIAcABaAEQAMABpAGEAUwAxADIAYwBpAEkA
>> "%~1" echo ZwBkAG0AbABsAGQAMABKAHYAZQBEADAAaQBNAEMAQQB3AEkARABJADAASQBEAEkA
>> "%~1" echo MABJAGoANAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE0AQwBBAHcAYQBEAEkA
>> "%~1" echo MABkAGoASQAwAFMARABCADYASQBpAEIAbQBhAFcAeABzAFAAUwBKAHUAYgAyADUA
>> "%~1" echo bABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQAVABZAGcATwBXAGcA
>> "%~1" echo eABNAG0ARQB6AEkARABNAGcATQBDAEEAdwBJAEQARQBnAE0AeQBBAHoAZABqAE4A
>> "%~1" echo aABNAHkAQQB6AEkARABBAGcATQBDAEEAeABMAFQATQBnAE0AMgBnAHQATQBTADQA
>> "%~1" echo MQBiAEMAMAB5AEwAagBVAHQATQAyAGcAdABOAEcAdwB0AE0AaQA0ADEASQBEAE4A
>> "%~1" echo SQBOAG0ARQB6AEkARABNAGcATQBDAEEAdwBJAEQARQB0AE0AeQAwAHoAZABpADAA
>> "%~1" echo egBZAFQATQBnAE0AeQBBAHcASQBEAEEAZwBNAFMAQQB6AEwAVABOADYASQBpADgA
>> "%~1" echo KwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAawBnAE0AVABKAG8ATABqAEEA
>> "%~1" echo eABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQAVABFADEASQBEAEUA
>> "%~1" echo eQBhAEMANAB3AE0AUwBJAHYAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAA
>> "%~1" echo eABNAEMAQQB4AE4AVwBnADAASQBpADgAKwBQAEMAOQB6AGUAVwAxAGkAYgAyAHcA
>> "%~1" echo KwBQAEgATgA1AGIAVwBKAHYAYgBDAEIAcABaAEQAMABpAGEAUwAxAG8AYgAyADEA
>> "%~1" echo bABJAGkAQgAyAGEAVwBWADMAUQBtADkANABQAFMASQB3AEkARABBAGcATQBqAFEA
>> "%~1" echo ZwBNAGoAUQBpAFAAagB4AHcAWQBYAFIAbwBJAEcAUQA5AEkAawAwAHcASQBEAEIA
>> "%~1" echo bwBNAGoAUgAyAE0AagBSAEkATQBIAG8AaQBJAEcAWgBwAGIARwB3ADkASQBtADUA
>> "%~1" echo dgBiAG0AVQBpAEwAegA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATgBTAEEA
>> "%~1" echo eABNAG0AdwAzAEwAVABkAHMATgB5AEEAMwBJAGkAOAArAFAASABCAGgAZABHAGcA
>> "%~1" echo ZwBaAEQAMABpAFQAVABZAGcATQBUAEIAMgBPAFcAZwB4AE0AbgBZAHQATwBTAEkA
>> "%~1" echo dgBQAGoAdwB2AGMAMwBsAHQAWQBtADkAcwBQAGoAeAB6AGUAVwAxAGkAYgAyAHcA
>> "%~1" echo ZwBhAFcAUQA5AEkAbQBrAHQAWQAyADkAdQBjADIAOQBzAFoAUwBJAGcAZABtAGwA
>> "%~1" echo bABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQASQAwAEkARABJADAASQBqADQA
>> "%~1" echo OABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBNAEMAQQB3AGEARABJADAAZABqAEkA
>> "%~1" echo MABTAEQAQgA2AEkAaQBCAG0AYQBXAHgAcwBQAFMASgB1AGIAMgA1AGwASQBpADgA
>> "%~1" echo KwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAZwBnAE8AVwB3AHoASQBEAE4A
>> "%~1" echo cwBMAFQATQBnAE0AeQBJAHYAUABqAHgAdwBZAFgAUgBvAEkARwBRADkASQBrADAA
>> "%~1" echo eABNAHkAQQB4AE4AVwBnAHoASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAA
>> "%~1" echo aQBUAFQATQBnAE4ARwBnAHgATwBIAFkAeABOAGsAZwB6AGUAaQBJAHYAUABqAHcA
>> "%~1" echo dgBjADMAbAB0AFkAbQA5AHMAUABqAHgAegBlAFcAMQBpAGIAMgB3AGcAYQBXAFEA
>> "%~1" echo OQBJAG0AawB0AGEAVwA1AG0AYgB5AEkAZwBkAG0AbABsAGQAMABKAHYAZQBEADAA
>> "%~1" echo aQBNAEMAQQB3AEkARABJADAASQBEAEkAMABJAGoANAA4AGMARwBGADAAYQBDAEIA
>> "%~1" echo awBQAFMASgBOAE0AQwBBAHcAYQBEAEkAMABkAGoASQAwAFMARABCADYASQBpAEIA
>> "%~1" echo bQBhAFcAeABzAFAAUwBKAHUAYgAyADUAbABJAGkAOAArAFAASABCAGgAZABHAGcA
>> "%~1" echo ZwBaAEQAMABpAFQAVABFAHkASQBEAGwAbwBMAGoAQQB4AEkAaQA4ACsAUABIAEIA
>> "%~1" echo aABkAEcAZwBnAFoARAAwAGkAVABUAEUAeABJAEQARQB5AGEARABGADIATgBHAGcA
>> "%~1" echo eABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQAVABFAHkASQBEAE4A
>> "%~1" echo aABPAFMAQQA1AEkARABBAGcATQBTAEEAdwBJAEQAQQBnAE0AVABoAGgATwBTAEEA
>> "%~1" echo NQBJAEQAQQBnAE0AQwBBAHcASQBEAEEAdABNAFQAaAA2AEkAaQA4ACsAUABDADkA
>> "%~1" echo egBlAFcAMQBpAGIAMgB3ACsAUABIAE4ANQBiAFcASgB2AGIAQwBCAHAAWgBEADAA
>> "%~1" echo aQBhAFMAMQB6AFoAWABSADAAYQBXADUAbgBjAHkASQBnAGQAbQBsAGwAZAAwAEoA
>> "%~1" echo dgBlAEQAMABpAE0AQwBBAHcASQBEAEkAMABJAEQASQAwAEkAagA0ADgAYwBHAEYA
>> "%~1" echo MABhAEMAQgBrAFAAUwBKAE4ATQBDAEEAdwBhAEQASQAwAGQAagBJADAAUwBEAEIA
>> "%~1" echo NgBJAGkAQgBtAGEAVwB4AHMAUABTAEoAdQBiADIANQBsAEkAaQA4ACsAUABIAEIA
>> "%~1" echo aABkAEcAZwBnAFoARAAwAGkAVABUAEUAdwBMAGoATQB5AE4AUwBBADAATABqAE0A
>> "%~1" echo eABOADIARQB5AEkARABJAGcATQBDAEEAdwBJAEQARQBnAE0AeQA0AHoATgBTAEEA
>> "%~1" echo dwBiAEMANAB5AEwAagBNADAATgBHAEUAeQBJAEQASQBnAE0AQwBBAHcASQBEAEEA
>> "%~1" echo ZwBNAGkANAB3AE0ARABrAHUATwBUAFoAcwBMAGoATQA1AE0AaQAwAHUATQBEAGMA
>> "%~1" echo MABZAFQASQBnAE0AaQBBAHcASQBEAEEAZwBNAFMAQQB5AEwAagBNADIASQBEAEkA
>> "%~1" echo dQBNAHoAWgBzAEwAUwA0AHcATgB6AFEAdQBNAHoAawB5AFkAVABJAGcATQBpAEEA
>> "%~1" echo dwBJAEQAQQBnAE0AQwBBAHUATwBUAFkAZwBNAGkANAB3AE0ARABsAHMATABqAE0A
>> "%~1" echo MABOAEMANAB5AFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AUwBBAHcASQBEAE0A
>> "%~1" echo dQBNAHoAVgBzAEwAUwA0AHoATgBEAFEAdQBNAG0ARQB5AEkARABJAGcATQBDAEEA
>> "%~1" echo dwBJAEQAQQB0AEwAagBrADIASQBEAEkAdQBNAEQAQQA1AGIAQwA0AHcATgB6AFEA
>> "%~1" echo dQBNAHoAawB5AFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AUwAwAHkATABqAE0A
>> "%~1" echo MgBJAEQASQB1AE0AegBaAHMATABTADQAegBPAFQASQB0AEwAagBBADMATgBHAEUA
>> "%~1" echo eQBJAEQASQBnAE0AQwBBAHcASQBEAEEAdABNAGkANAB3AE0ARABrAHUATwBUAFoA
>> "%~1" echo cwBMAFMANAB5AEwAagBNADAATgBHAEUAeQBJAEQASQBnAE0AQwBBAHcASQBEAEUA
>> "%~1" echo dABNAHkANAB6AE4AUwBBAHcAYgBDADAAdQBNAGkAMAB1AE0AegBRADAAWQBUAEkA
>> "%~1" echo ZwBNAGkAQQB3AEkARABBAGcATQBDADAAeQBMAGoAQQB3AE8AUwAwAHUATwBUAFoA
>> "%~1" echo cwBMAFMANAB6AE8AVABJAHUATQBEAGMAMABZAFQASQBnAE0AaQBBAHcASQBEAEEA
>> "%~1" echo ZwBNAFMAMAB5AEwAagBNADIATABUAEkAdQBNAHoAWgBzAEwAagBBADMATgBDADAA
>> "%~1" echo dQBNAHoAawB5AFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AQwAwAHUATwBUAFkA
>> "%~1" echo dABNAGkANAB3AE0ARABsAHMATABTADQAegBOAEQAUQB0AEwAagBKAGgATQBpAEEA
>> "%~1" echo eQBJAEQAQQBnAE0AQwBBAHgASQBEAEEAdABNAHkANAB6AE4AVwB3AHUATQB6AFEA
>> "%~1" echo MABMAFMANAB5AFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AQwBBAHUATwBUAFkA
>> "%~1" echo dABNAGkANAB3AE0ARABsAHMATABTADQAdwBOAHoAUQB0AEwAagBNADUATQBtAEUA
>> "%~1" echo eQBJAEQASQBnAE0AQwBBAHcASQBEAEUAZwBNAGkANAB6AE4AaQAwAHkATABqAE0A
>> "%~1" echo MgBiAEMANAB6AE8AVABJAHUATQBEAGMAMABZAFQASQBnAE0AaQBBAHcASQBEAEEA
>> "%~1" echo ZwBNAEMAQQB5AEwAagBBAHcATwBTADAAdQBPAFQAWgA2AEkAaQA4ACsAUABIAEIA
>> "%~1" echo aABkAEcAZwBnAFoARAAwAGkAVABUAGsAZwBNAFQASgBoAE0AeQBBAHoASQBEAEEA
>> "%~1" echo ZwBNAFMAQQB3AEkARABZAGcATQBHAEUAegBJAEQATQBnAE0AQwBBAHcASQBEAEEA
>> "%~1" echo dABOAGkAQQB3AEkAaQA4ACsAUABDADkAegBlAFcAMQBpAGIAMgB3ACsAUABIAE4A
>> "%~1" echo NQBiAFcASgB2AGIAQwBCAHAAWgBEADAAaQBhAFMAMQBzAGIAMgBjAGkASQBIAFoA
>> "%~1" echo cABaAFgAZABDAGIAMwBnADkASQBqAEEAZwBNAEMAQQB5AE4AQwBBAHkATgBDAEkA
>> "%~1" echo KwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAQQBnAE0ARwBnAHkATgBIAFkA
>> "%~1" echo eQBOAEUAZwB3AGUAaQBJAGcAWgBtAGwAcwBiAEQAMABpAGIAbQA5AHUAWgBTAEkA
>> "%~1" echo dgBQAGoAeAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAAxAEkARABWAG8ATQBUAFIA
>> "%~1" echo MgBNAFQAUgBJAE4AWABvAGkATAB6ADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoA
>> "%~1" echo TgBPAFMAQQA1AGEARABZAGkATAB6ADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoA
>> "%~1" echo TgBPAFMAQQB4AE0AMgBnADIASQBpADgAKwBQAEMAOQB6AGUAVwAxAGkAYgAyAHcA
>> "%~1" echo KwBQAEMAOQB6AGQAbQBjACsARABRAG8AOABaAEcAbAAyAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBoAGMASABBAGkAUABqAHgAaABjADIAbABrAFoAUwBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAGMAMgBsAGsAWgBTAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAbgBKAGgAYgBtAFEAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBKAHkAWQBXADUAawBTAFcATgB2AGIAaQBJACsAUABIAE4A
>> "%~1" echo MgBaAHkAQgAzAGEAVwBSADAAYQBEADAAaQBNAGoASQBpAEkARwBoAGwAYQBXAGQA
>> "%~1" echo bwBkAEQAMABpAE0AagBJAGkAUABqAHgAMQBjADIAVQBnAGEASABKAGwAWgBqADAA
>> "%~1" echo aQBJADIAawB0AGQAbgBJAGkATAB6ADQAOABMADMATgAyAFoAegA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIAUABqAHgAaQBQAGwARgAxAFoAWABOADAASQBFAEYA
>> "%~1" echo RQBRAGoAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoANQBUAGEAVwA1AG4AYgBHAFUA
>> "%~1" echo ZwBRAGsARgBVAEkARgBkAGwAWQBsAFYASgBQAEMAOQB6AGMARwBGAHUAUABqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAeAB1AFkAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQA1AGgAZABpAEkAKwBQAEcARQBnAGEASABKAGwAWgBqADAA
>> "%~1" echo aQBJADIAOQAyAFoAWABKADIAYQBXAFYAMwBJAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBZAFcATgAwAGEAWABaAGwASQBqADQAOABjADMAWgBuAFAAagB4ADEAYwAyAFUA
>> "%~1" echo ZwBhAEgASgBsAFoAagAwAGkASQAyAGsAdABhAEcAOQB0AFoAUwBJAHYAUABqAHcA
>> "%~1" echo dgBjADMAWgBuAFAAdQBhAEEAdQArAGkAbgBpAEQAdwB2AFkAVAA0ADgAWQBTAEIA
>> "%~1" echo bwBjAG0AVgBtAFAAUwBJAGoAWQAyADkAdQBjADIAOQBzAFoAUwBJACsAUABIAE4A
>> "%~1" echo MgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkAaQBOAHAATABXAE4A
>> "%~1" echo dgBiAG4ATgB2AGIARwBVAGkATAB6ADQAOABMADMATgAyAFoAegA3AGwAdgA2AHYA
>> "%~1" echo bQBqAGIAZgBtAGoAcQBmAGwAaQBMAGIAbABqADcAQQA4AEwAMgBFACsAUABHAEUA
>> "%~1" echo ZwBhAEgASgBsAFoAagAwAGkASQAyAFIAbABkAG0AbABqAFoAUwBJACsAUABIAE4A
>> "%~1" echo MgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkAaQBOAHAATABXAGwA
>> "%~1" echo dQBaAG0AOABpAEwAegA0ADgATAAzAE4AMgBaAHoANwBvAHIAcgA3AGwAcABJAGYA
>> "%~1" echo awB2ADYASABtAGcAYQA4ADgATAAyAEUAKwBQAEcARQBnAGEASABKAGwAWgBqADAA
>> "%~1" echo aQBJADMATgBsAGQASABSAHAAYgBtAGQAegBJAGoANAA4AGMAMwBaAG4AUABqAHgA
>> "%~1" echo MQBjADIAVQBnAGEASABKAGwAWgBqADAAaQBJADIAawB0AGMAMgBWADAAZABHAGwA
>> "%~1" echo dQBaADMATQBpAEwAegA0ADgATAAzAE4AMgBaAHoANwBwAHEANQBqAG4AdQBxAGMA
>> "%~1" echo ZwBjADIAVgAwAGQARwBsAHUAWgAzAE0AOABMADIARQArAFAARwBFAGcAYQBIAEoA
>> "%~1" echo bABaAGoAMABpAEkAMgB4AHYAWgAzAE0AaQBQAGoAeAB6AGQAbQBjACsAUABIAFYA
>> "%~1" echo egBaAFMAQgBvAGMAbQBWAG0AUABTAEkAagBhAFMAMQBzAGIAMgBjAGkATAB6ADQA
>> "%~1" echo OABMADMATgAyAFoAegA3AG0AbAA2AFgAbAB2ADUAYwA4AEwAMgBFACsAUABDADkA
>> "%~1" echo dQBZAFgAWQArAFAAQwA5AGgAYwAyAGwAawBaAFQANAA4AGIAVwBGAHAAYgBpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAYgBXAEYAcABiAGkASQArAFAARwBoAGwAWQBXAFIA
>> "%~1" echo bABjAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBkAEcAOQB3AEkAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAMABhAFgAUgBzAFoAUwBJACsAUABHAGcA
>> "%~1" echo eABJAEcAbABrAFAAUwBKAHcAWQBXAGQAbABWAEcAbAAwAGIARwBVAGkAUAB1AGEA
>> "%~1" echo QQB1ACsAaQBuAGkARAB3AHYAYQBEAEUAKwBQAEgAQQBnAGEAVwBRADkASQBuAEIA
>> "%~1" echo aABaADIAVgBUAGQAVwBJAGkAUAB1AGUASwB0AHUAYQBBAGcAZQBhAE0AaAArAGEA
>> "%~1" echo ZwBoACsAVwBTAGoATwBpAHUAdgB1AFcAawBoACsAYQBtAGcAdQBpAG4AaQBEAHcA
>> "%~1" echo dgBjAEQANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgAwAGIAMgA5AHMAWQBtAEYAeQBJAGoANAA4AGMAMwBCAGgAYgBpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQAyAGgAcABjAEMASQBnAGEAVwBRADkASQBuAE4A
>> "%~1" echo MABZAFgAUgAxAGMAMABOAG8AYQBYAEEAaQBQAGoAeABwAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBqAGEARwBsAHcAUgBHADkAMABJAGoANAA4AEwAMgBrACsAUABIAE4A
>> "%~1" echo dwBZAFcANAArADUAcAB5AHEANgBMACsAZQA1AG8ANgBsAFAAQwA5AHoAYwBHAEYA
>> "%~1" echo dQBQAGoAdwB2AGMAMwBCAGgAYgBqADQAOABjADMAQgBoAGIAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAMgBoAHAAYwBDAEkAKwBRAFUAUgBDAEkARAB4AGkASQBHAGwA
>> "%~1" echo awBQAFMASgBoAFoARwBKAFQAYQBHADkAeQBkAEMASQArAFkAVwBSAGkATABtAFYA
>> "%~1" echo NABaAFQAdwB2AFkAagA0ADgATAAzAE4AdwBZAFcANAArAFAASABOAHcAWQBXADQA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AbwBhAFgAQQBpAFAAbABkAHAATABVAFoA
>> "%~1" echo cABJAEQAeABpAEkARwBsAGsAUABTAEoAMwBhAFcAWgBwAFEAMgBoAHAAYwBDAEkA
>> "%~1" echo KwBMAFQAdwB2AFkAagA0ADgATAAzAE4AdwBZAFcANAArAFAARwBKADEAZABIAFIA
>> "%~1" echo dgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG4AUgB1AEkARwBkAG8AYgAzAE4A
>> "%~1" echo MABJAGkAQgBwAFoARAAwAGkAZABHAGgAbABiAFcAVgBDAGQARwA0AGkAUAB1AGEA
>> "%~1" echo MQBoAGUAaQBKAHMAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB4AGkAZABYAFIA
>> "%~1" echo MABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgAwAGIAaQBCAHcAYwBtAGwA
>> "%~1" echo dABZAFgASgA1AEkAaQBCAHAAWgBEADAAaQBjAG0AVgBtAGMAbQBWAHoAYQBFAEoA
>> "%~1" echo MABiAGkASQArADUAWQBpADMANQBwAGEAdwBQAEMAOQBpAGQAWABSADAAYgAyADQA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAbwBaAFcARgBrAFoAWABJACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBkADMASgBoAGMAQwBJACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAG0AOQAwAGEAVwBOAGwASQBqADcA
>> "%~1" echo awB2ADUAMwBtAHQATAB2AGoAZwBJAEUAeQBOAEMARABsAHMASQAvAG0AbAA3AGIA
>> "%~1" echo awB1AHEANwBsAHMAWQAvAGwAawBvAHoAbQBsADYARABuAHUAcgA4AGcAUQBVAFIA
>> "%~1" echo QwBJAE8AVwBQAHEAdQBXADcAdQB1AGkAdQByAHUAZQBmAHIAZQBhAFgAdAB1AG0A
>> "%~1" echo WAB0AE8AYQAxAGkAKwBpAHYAbABlACsAOABtACsAZQA3AGsAKwBhAGQAbgArAFcA
>> "%~1" echo UQBqAHUAYQBKAHAAKwBpAGgAagBPAEsAQQBuAE8AVwB1AGkAZQBXAEYAcQBPAGUA
>> "%~1" echo RwBoAE8AVwB4AGoAKwBLAEEAbgBlAGEASQBsAHUASwBBAG4ATwBTAC8AbgBlAFcA
>> "%~1" echo dQBpAE8AbQA3AG0ATwBpAHUAcABPAFcAQQB2AE8ASwBBAG4AZQBPAEEAZwBqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAZwAwAEsAUABIAE4AbABZADMAUgBwAGIAMgA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBCAGgAWgAyAFUAZwBZAFcATgAwAGEAWABaAGwASQBpAEIA
>> "%~1" echo cABaAEQAMABpAGIAMwBaAGwAYwBuAFoAcABaAFgAYwBpAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBuAEoAdgBkAHkASQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AGkA
>> "%~1" echo dQB2AHUAVwBrAGgAegB3AHYAYQBEAEkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBSAGgAWgB5AEkAZwBhAFcAUQA5AEkAbQBSAGwAZABtAGwA
>> "%~1" echo agBaAFYAUgBoAFoAeQBJACsAVQBYAFYAbABjADMAUQA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBZAG0AOQBrAGUAUwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBhAEcAVgBoAFoASABOAGwAZABFAEoAdgBlAEMASQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWgBHAFYAMgBhAFcATgBsAFMAVwBOAHYAYgBpAEkA
>> "%~1" echo KwBQAEgATgAyAFoAegA0ADgAZABYAE4AbABJAEcAaAB5AFoAVwBZADkASQBpAE4A
>> "%~1" echo cABMAFgAWgB5AEkAaQA4ACsAUABDADkAegBkAG0AYwArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo awBaAFgAWgBwAFkAMgBWAE8AWQBXADEAbABJAGkAQgBwAFoARAAwAGkAYQBHAFYA
>> "%~1" echo eQBiADAAMQB2AFoARwBWAHMASQBqADUAUgBkAFcAVgB6AGQARAB3AHYAWgBHAGwA
>> "%~1" echo MgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAHAAYgBuAFEA
>> "%~1" echo aQBJAEcAbABrAFAAUwBKAHoAZABHAEYAMABaAFUAaABwAGIAbgBRAGkAUAB1AGUA
>> "%~1" echo dABpAGUAVwArAGgAZQBpAHYAdQArAFcAUABsAHUAaQB1AHYAdQBXAGsAaAArAGUA
>> "%~1" echo SwB0AHUAYQBBAGcAZQBPAEEAZwBqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBuAE4AMABZAFgAUgBsAEkAaQBCAHAAWgBEADAA
>> "%~1" echo aQBjADMAUgBoAGQARwBWAEMAYQBXAGMAaQBQAG0ANQB2AGIAbQBVADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAeQBhAFcAYwBpAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoA
>> "%~1" echo QwBiADMAZwBnAGIARwBWAG0AZABDAEkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBKAHYAYgBHAFUAaQBQAHUAVwAzAHAAdQBhAEoAaQArAGEA
>> "%~1" echo ZgBoAEQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGkAQgBwAFoARAAwAGkAYgBHAFYA
>> "%~1" echo bQBkAEUATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBNAGEAWABSAGwASQBqADQA
>> "%~1" echo dABMAFQAdwB2AFkAagA0ADgAYwAzAEIAaABiAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBjADMAUgBoAGQARwBWAFUAWgBYAGgAMABJAGkAQgBwAFoARAAwAGkAYgBHAFYA
>> "%~1" echo bQBkAEUATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBUAGQARwBGADAAWgBTAEkA
>> "%~1" echo KwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABaAFgAUgBoAFMAWABSAGwAYgBTAEkA
>> "%~1" echo KwBQAEgATgB3AFkAVwA0ACsAVgAyAGsAdABSAG0AawBnAFMAVgBBADgATAAzAE4A
>> "%~1" echo dwBZAFcANAArAFAARwBJAGcAYQBXAFEAOQBJAG4AZABwAFoAbQBsAEoAYwBFAHgA
>> "%~1" echo cABkAEcAVQBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIAOQB1AGQASABKAHYAYgBHAHgA
>> "%~1" echo bABjAGsASgB2AGUAQwBCAHkAYQBXAGQAbwBkAEMASQArAFAASABOAHcAWQBXADQA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBuAEoAdgBiAEcAVQBpAFAAdQBXAFAAcwArAGEA
>> "%~1" echo SgBpACsAYQBmAGgARAB3AHYAYwAzAEIAaABiAGoANAA4AFkAaQBCAHAAWgBEADAA
>> "%~1" echo aQBjAG0AbABuAGEASABSAEQAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAVABHAGwA
>> "%~1" echo MABaAFMASQArAEwAUwAwADgATAAyAEkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBOADAAWQBYAFIAbABWAEcAVgA0AGQAQwBJAGcAYQBXAFEA
>> "%~1" echo OQBJAG4ASgBwAFoAMgBoADAAUQAyADkAdQBkAEgASgB2AGIARwB4AGwAYwBsAE4A
>> "%~1" echo MABZAFgAUgBsAEkAagA0AHQAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwA
>> "%~1" echo MgBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwA
>> "%~1" echo MgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBOAGgAYwBtAFEA
>> "%~1" echo aQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAGwAWQBXAFEA
>> "%~1" echo aQBQAGoAeABvAE0AagA3AG4AaQByAGIAbQBnAEkASABtAGoASQBmAG0AbwBJAGMA
>> "%~1" echo OABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo MABZAFcAYwBpAEkARwBsAGsAUABTAEoAagBiAEcAOQBqAGEAMQBSAGwAZQBIAFEA
>> "%~1" echo aQBQAGkAMAA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBrAGEAWABZACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUAUwBJACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMAbQBsAGoAUgAzAEoA
>> "%~1" echo cABaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYA
>> "%~1" echo MABjAG0AbABqAEkAaQBCAHAAWgBEADAAaQBZAG0ARgAwAGQARwBWAHkAZQBVAGQA
>> "%~1" echo aABkAFcAZABsAEkAagA0ADgAYwAzAFoAbgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo eQBhAFcANQBuAEkAaQBCADIAYQBXAFYAMwBRAG0AOQA0AFAAUwBJAHcASQBEAEEA
>> "%~1" echo ZwBNAFQAQQB3AEkARABFAHcATQBDAEkAKwBQAEcATgBwAGMAbQBOAHMAWgBTAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAZABIAEoAaABZADIAcwBpAEkARwBOADQAUABTAEkA
>> "%~1" echo MQBNAEMASQBnAFkAMwBrADkASQBqAFUAdwBJAGkAQgB5AFAAUwBJADAATQBDAEkA
>> "%~1" echo ZwBjAEcARgAwAGEARQB4AGwAYgBtAGQAMABhAEQAMABpAE0AVABBAHcASQBpADgA
>> "%~1" echo KwBQAEcATgBwAGMAbQBOAHMAWgBTAEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYA
>> "%~1" echo MABaAFgASQBpAEkARwBOADQAUABTAEkAMQBNAEMASQBnAFkAMwBrADkASQBqAFUA
>> "%~1" echo dwBJAGkAQgB5AFAAUwBJADAATQBDAEkAZwBjAEcARgAwAGEARQB4AGwAYgBtAGQA
>> "%~1" echo MABhAEQAMABpAE0AVABBAHcASQBpAEIAegBkAEgASgB2AGEAMgBVAHQAWgBHAEYA
>> "%~1" echo egBhAEcARgB5AGMAbQBGADUAUABTAEkAdwBJAEQARQB3AE0AQwBJAHYAUABqAHcA
>> "%~1" echo dgBjADMAWgBuAFAAagB4AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAGIAVwBWADAAYwBtAGwAagBWAG0ARgBzAGQAVwBVAGkASQBHAGwA
>> "%~1" echo awBQAFMASgBpAFkAWABSADAAWgBYAEoANQBWAEcAVgA0AGQAQwBJACsATABTADAA
>> "%~1" echo bABQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBiAFcAVgAwAGMAbQBsAGoAVABHAEYAaQBaAFcAdwBpAEkARwBsAGsAUABTAEoA
>> "%~1" echo aQBZAFgAUgAwAFoAWABKADUAVQAzAFYAaQBJAGoANwBuAGwATABYAHAAaAA0ADgA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB0AFoAWABSAHkAYQBXAE0A
>> "%~1" echo aQBJAEcAbABrAFAAUwBKADAAWgBXADEAdwBSADIARgAxAFoAMgBVAGkAUABqAHgA
>> "%~1" echo egBkAG0AYwBnAFkAMgB4AGgAYwAzAE0AOQBJAG4ASgBwAGIAbQBjAGkASQBIAFoA
>> "%~1" echo cABaAFgAZABDAGIAMwBnADkASQBqAEEAZwBNAEMAQQB4AE0ARABBAGcATQBUAEEA
>> "%~1" echo dwBJAGoANAA4AFkAMgBsAHkAWQAyAHgAbABJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo MABjAG0ARgBqAGEAeQBJAGcAWQAzAGcAOQBJAGoAVQB3AEkAaQBCAGoAZQBUADAA
>> "%~1" echo aQBOAFQAQQBpAEkASABJADkASQBqAFEAdwBJAGkAQgB3AFkAWABSAG8AVABHAFYA
>> "%~1" echo dQBaADMAUgBvAFAAUwBJAHgATQBEAEEAaQBMAHoANAA4AFkAMgBsAHkAWQAyAHgA
>> "%~1" echo bABJAEcATgBzAFkAWABOAHoAUABTAEoAdABaAFgAUgBsAGMAaQBJAGcAWQAzAGcA
>> "%~1" echo OQBJAGoAVQB3AEkAaQBCAGoAZQBUADAAaQBOAFQAQQBpAEkASABJADkASQBqAFEA
>> "%~1" echo dwBJAGkAQgB3AFkAWABSAG8AVABHAFYAdQBaADMAUgBvAFAAUwBJAHgATQBEAEEA
>> "%~1" echo aQBJAEgATgAwAGMAbQA5AHIAWgBTADEAawBZAFgATgBvAFkAWABKAHkAWQBYAGsA
>> "%~1" echo OQBJAGoAQQBnAE0AVABBAHcASQBpADgAKwBQAEMAOQB6AGQAbQBjACsAUABHAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHQAWgBYAFIA
>> "%~1" echo eQBhAFcATgBXAFkAVwB4ADEAWgBTAEkAZwBhAFcAUQA5AEkAbgBSAGwAYgBYAEIA
>> "%~1" echo VQBaAFgAaAAwAEkAagA0AHQATABjAEsAdwBRAHoAdwB2AFoARwBsADIAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQASABKAHAAWQAwAHgA
>> "%~1" echo aABZAG0AVgBzAEkAaQBCAHAAWgBEADAAaQBkAEcAVgB0AGMARgBOADEAWQBpAEkA
>> "%~1" echo KwA1AHIAaQBwADUAYgBxAG0AUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBiAFcAVgAwAGMAbQBsAGoASQBpAEIAcABaAEQAMABpAGMAMgB4AGwAWgBYAEIA
>> "%~1" echo SABZAFgAVgBuAFoAUwBJACsAUABIAE4AMgBaAHkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBjAG0AbAB1AFoAeQBJAGcAZABtAGwAbABkADAASgB2AGUARAAwAGkATQBDAEEA
>> "%~1" echo dwBJAEQARQB3AE0AQwBBAHgATQBEAEEAaQBQAGoAeABqAGEAWABKAGoAYgBHAFUA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBuAFIAeQBZAFcATgByAEkAaQBCAGoAZQBEADAA
>> "%~1" echo aQBOAFQAQQBpAEkARwBOADUAUABTAEkAMQBNAEMASQBnAGMAagAwAGkATgBEAEEA
>> "%~1" echo aQBJAEgAQgBoAGQARwBoAE0AWgBXADUAbgBkAEcAZwA5AEkAagBFAHcATQBDAEkA
>> "%~1" echo dgBQAGoAeABqAGEAWABKAGoAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBtADEA
>> "%~1" echo bABkAEcAVgB5AEkAaQBCAGoAZQBEADAAaQBOAFQAQQBpAEkARwBOADUAUABTAEkA
>> "%~1" echo MQBNAEMASQBnAGMAagAwAGkATgBEAEEAaQBJAEgAQgBoAGQARwBoAE0AWgBXADUA
>> "%~1" echo bgBkAEcAZwA5AEkAagBFAHcATQBDAEkAZwBjADMAUgB5AGIAMgB0AGwATABXAFIA
>> "%~1" echo aABjADIAaABoAGMAbgBKAGgAZQBUADAAaQBNAEMAQQB4AE0ARABBAGkATAB6ADQA
>> "%~1" echo OABMADMATgAyAFoAegA0ADgAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQAxAGwAZABIAEoAcABZADEAWgBoAGIASABWAGwASQBpAEIA
>> "%~1" echo cABaAEQAMABpAGMAMgB4AGwAWgBYAEIAVQBaAFgAaAAwAEkAagA0AHQAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYA
>> "%~1" echo MABjAG0AbABqAFQARwBGAGkAWgBXAHcAaQBJAEcAbABrAFAAUwBKAHoAYgBHAFYA
>> "%~1" echo bABjAEYATgAxAFkAaQBJACsANQBMAHkAUgA1ADUAeQBnAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIAVwBsAHUAYQBVAGQA
>> "%~1" echo eQBhAFcAUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADEA
>> "%~1" echo cABiAG0AawBpAFAAagB4AHoAYwBHAEYAdQBQAGwATgB2AFEAegB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AFkAaQBCAHAAWgBEADAAaQBjADIAOQBqAFQARwBsADAAWgBTAEkA
>> "%~1" echo KwBMAFQAdwB2AFkAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAUwBKAHQAYQBXADUAcABJAGoANAA4AGMAMwBCAGgAYgBqADcA
>> "%~1" echo bQBtAEwANwBuAHAATABvADgATAAzAE4AdwBZAFcANAArAFAARwBJAGcAYQBXAFEA
>> "%~1" echo OQBJAG0AUgBwAGMAMwBCAHMAWQBYAGwAVABkAFcAMQB0AFkAWABKADUAVABHAGwA
>> "%~1" echo MABaAFMASQArAEwAVAB3AHYAWQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABhAFcANQBwAEkAagA0ADgAYwAzAEIA
>> "%~1" echo aABiAGoANwBuAGcANgAzAG4AaQByAGIAbQBnAEkARQA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEcASQBnAGEAVwBRADkASQBuAFIAbwBaAFgASgB0AFkAVwB4AFQAZABXADEA
>> "%~1" echo dABZAFgASgA1AFQARwBsADAAWgBTAEkAKwBMAFQAdwB2AFkAagA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHQAYQBXADUA
>> "%~1" echo cABJAGoANAA4AGMAMwBCAGgAYgBqADcAbAB0ADYAWABsAGoAbwBJAHYANQBxAEMA
>> "%~1" echo aAA1AFkAZQBHAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAEkARwBsAGsAUABTAEoA
>> "%~1" echo bQBZAFcATgAwAGIAMwBKADUAVQAzAFYAdABiAFcARgB5AGUAVQB4AHAAZABHAFUA
>> "%~1" echo aQBQAGkAMAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIAVwBsAHUAYQBVAGQA
>> "%~1" echo eQBhAFcAUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADEA
>> "%~1" echo cABiAG0AawBpAFAAagB4AHoAYwBHAEYAdQBQAHUAUwArAG0AKwBlAFUAdABUAHcA
>> "%~1" echo dgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAGMARwA5ADMAWgBYAEoA
>> "%~1" echo VABiADMAVgB5AFkAMgBVAGkAUABpADAAOABMADIASQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIAVwBsAHUAYQBTAEkA
>> "%~1" echo KwBQAEgATgB3AFkAVwA0ACsAUQBVAFIAQwBJAEYAZABwAEwAVQBaAHAAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB4AGkASQBHAGwAawBQAFMASgBoAFoARwBKAFgAYQBXAFoA
>> "%~1" echo cABJAGoANAB0AFAAQwA5AGkAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtADEAcABiAG0AawBpAFAAagB4AHoAYwBHAEYA
>> "%~1" echo dQBQAHUAVwBCAHAAZQBXADYAdAB6AHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIA
>> "%~1" echo cABaAEQAMABpAFkAbQBGADAAZABHAFYAeQBlAFUAaABsAFkAVwB4ADAAYQBDAEkA
>> "%~1" echo KwBMAFQAdwB2AFkAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAUwBKAHQAYQBXADUAcABJAGoANAA4AGMAMwBCAGgAYgBqADcA
>> "%~1" echo bwB2ADUARABvAG8AWQB6AG4AaQByAGIAbQBnAEkARQA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEcASQBnAGEAVwBRADkASQBuAGQAaABhADIAVgBtAGQAVwB4AHUAWgBYAE4A
>> "%~1" echo egBJAGoANAB0AFAAQwA5AGkAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwA
>> "%~1" echo MgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBOAGgAYwBtAFEA
>> "%~1" echo aQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAGwAWQBXAFEA
>> "%~1" echo aQBQAGoAeABvAE0AagA3AGsAdQBJAEQAcABsAEsANwBsAHIANwB6AGwAaAA3AHIA
>> "%~1" echo bwByAHIANwBsAHAASQBmAGwAaABhAGoAcABnADYAagBrAHYANgBIAG0AZwBhADgA
>> "%~1" echo OABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo MABZAFcAYwBpAFAAdQBXAFAAcQB1AGkAdgB1AHkAQgBCAFIARQBJADgATAAzAE4A
>> "%~1" echo dwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAbQA5AGsAZQBTAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFoAWABoAHcAYgAzAEoAMABRAG0AOQA0AEkAagA0ADgAWgBHAGwA
>> "%~1" echo MgBQAGoAeABpAFAAdQBlAFUAbgArAGEASQBrAE8AZQBuAGcAZQBhAGMAaQBlAFcA
>> "%~1" echo dQBqAE8AYQBWAHQATwBlAEoAaQBDAEEAcgBJAE8AVwBJAGgAdQBTADYAcQArAFcA
>> "%~1" echo dQBpAGUAVwBGAHEATwBlAEoAaQBDAEIASQBWAEUAMQBNAFAAQwA5AGkAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABwAGIAbgBRAGkASQBHAGwA
>> "%~1" echo awBQAFMASgBsAGUASABCAHYAYwBuAFIAVABkAEcARgAwAGQAWABNAGkAUAB1AGUA
>> "%~1" echo QwB1AGUAVwBIAHUAKwBXAFEAagB1AG0ASABqAGUAYQBXAHMATwBlAE8AcwBPAG0A
>> "%~1" echo SABoACsAaQB1AHYAdQBXAGsAaAArAFMALwBvAGUAYQBCAHIAKwBPAEEAZwB1AGUA
>> "%~1" echo bgBnAGUAYQBjAGkAZQBlAEoAaQBPAFMALwBuAGUAZQBWAG0AZQBXAHUAagBPAGEA
>> "%~1" echo VgB0AE8AYQBWAHMATwBhAE4AcgB1ACsAOABqAE8AVwBJAGgAdQBTADYAcQArAGUA
>> "%~1" echo SgBpAE8AUwA4AG0AdQBpAEUAcwBlAGEAVgBqACsAVwA2AGoAKwBXAEkAbAArAFcA
>> "%~1" echo UAB0ACsATwBBAGcAVQBsAFEANAA0AEMAQgBUAFUARgBEADQANABDAEIAWgBtAGwA
>> "%~1" echo dQBaADIAVgB5AGMASABKAHAAYgBuAFEAZwA1ADYAMgBKADQANABDAEMAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWgBYAGgA
>> "%~1" echo dwBiADMASgAwAFQARwBsAHUAYQAzAE0AaQBJAEcAbABrAFAAUwBKAGwAZQBIAEIA
>> "%~1" echo dgBjAG4AUgBNAGEAVwA1AHIAYwB5AEkAKwBQAEMAOQBrAGEAWABZACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBZAG4AUgB1AEkASABCAHkAYQBXADEAaABjAG4AawBpAEkARwBsAGsAUABTAEoA
>> "%~1" echo bABlAEgAQgB2AGMAbgBSAEMAZABHADQAaQBQAHUAVwB2AHYATwBXAEgAdQBpAEIA
>> "%~1" echo SQBWAEUAMQBNAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AFcA
>> "%~1" echo UABnAHUAYQBWAHMATwBTAC8AcgB1AGEAVQB1AGUAVwBJAGwAKwBpAGgAcQBEAHcA
>> "%~1" echo dgBhAEQASQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAFIA
>> "%~1" echo aABaAHkASQBnAGEAVwBRADkASQBuAEIAaABjAG0ARgB0AFUAMwBWAHQAYgBXAEYA
>> "%~1" echo eQBlAFMASQArADUANgAyAEoANQBiADYARgA1AFkAaQAzADUAcABhAHcAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBCAGgAYwBtAEYAdABUAEcAbAB6AGQAQwBJAGcAYQBXAFEA
>> "%~1" echo OQBJAG4AQgBoAGMAbQBGAHQAVABHAGwAegBkAEMASQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAYwBtADkAMwBJAGoANAA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAUwBKAGoAWQBYAEoAawBJAGoANAA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAUwBKAG8AWgBXAEYAawBJAGoANAA4AGEARABJACsANQBZAFcA
>> "%~1" echo egA2AFoAUwB1ADUAWQArAEMANQBwAFcAdwBQAEMAOQBvAE0AagA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIA
>> "%~1" echo NQBJAGoANAA4AGQARwBGAGkAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIA
>> "%~1" echo aABZAG0AeABsAEkAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAbgBOADAAWQBYAGwA
>> "%~1" echo ZgBiADIANQBmAGQAMgBoAHAAYgBHAFYAZgBjAEcAeAAxAFoAMgBkAGwAWgBGADkA
>> "%~1" echo cABiAGoAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAHoAZABHAEYA
>> "%~1" echo NQBUADIANABpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIA
>> "%~1" echo eQBQAGoAeAAwAFoARAA1ADMAYQBXAFoAcABYADMATgBzAFoAVwBWAHcAWAAzAEIA
>> "%~1" echo dgBiAEcAbABqAGUAVAB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoA
>> "%~1" echo MwBhAFcAWgBwAFUAMgB4AGwAWgBYAEEAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcA
>> "%~1" echo dgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQANQB6AFkAMwBKAGwAWgBXADUA
>> "%~1" echo ZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgAUQA4AEwAMwBSAGsAUABqAHgA
>> "%~1" echo MABaAEMAQgBwAFoARAAwAGkAYwAyAE4AeQBaAFcAVgB1AFQAMgBaAG0ASQBqADQA
>> "%~1" echo dABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGoAeAAwAGMAagA0ADgAZABHAFEA
>> "%~1" echo KwBjADIAeABsAFoAWABCAGYAZABHAGwAdABaAFcAOQAxAGQARAB3AHYAZABHAFEA
>> "%~1" echo KwBQAEgAUgBrAEkARwBsAGsAUABTAEoAegBiAEcAVgBsAGMARgBSAHAAYgBXAFYA
>> "%~1" echo dgBkAFgAUQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABDADkA
>> "%~1" echo MABZAFcASgBzAFoAVAA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBqAFkAWABKAGsASQBqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQA
>> "%~1" echo OABhAEQASQArADYATABXAEUANQByAHEAUQA1ADQAcQAyADUAbwBDAEIAUABDADkA
>> "%~1" echo bwBNAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBpAGIAMgBSADUASQBqADQAOABkAEcARgBpAGIARwBVAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBSAGgAWQBtAHgAbABJAGoANAA4AGQASABJACsAUABIAFIA
>> "%~1" echo awBQAHUAVwB0AG0ATwBXAEMAcQBEAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwA
>> "%~1" echo awBQAFMASgB6AGQARwA5AHkAWQBXAGQAbABJAGoANAB0AFAAQwA5ADAAWgBEADQA
>> "%~1" echo OABMADMAUgB5AFAAagB4ADAAYwBqADQAOABkAEcAUQArADUAWQBhAEYANQBhADIA
>> "%~1" echo WQBQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQAxAGwAYgBXADkA
>> "%~1" echo eQBlAFMASQArAEwAVAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0ADgAZABIAEkA
>> "%~1" echo KwBQAEgAUgBrAFAAdQBTACsAbQArAGUAVQB0AGUAYQBkAHAAZQBhADYAawBEAHcA
>> "%~1" echo dgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMASgB3AGIAMwBkAGwAYwBsAE4A
>> "%~1" echo dgBkAFgASgBqAFoAVABJAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkA
>> "%~1" echo KwBQAEgAUgB5AFAAagB4ADAAWgBEADUAQgBSAEUASQBnADYATABlAHYANQBiADYA
>> "%~1" echo RQBQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQBGAGsAWQBsAEIA
>> "%~1" echo aABkAEcAaABUAGEARwA5AHkAZABDAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkA
>> "%~1" echo MABjAGoANAA4AEwAMwBSAGgAWQBtAHgAbABQAGoAdwB2AFoARwBsADIAUABqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AGMAMgBWAGoAZABHAGwA
>> "%~1" echo dgBiAGoANABOAEMAagB4AHoAWgBXAE4AMABhAFcAOQB1AEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgB3AFkAVwBkAGwASQBpAEIAcABaAEQAMABpAFkAMgA5AHUAYwAyADkA
>> "%~1" echo cwBaAFMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYwBtADkA
>> "%~1" echo MwBNAHkASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYA
>> "%~1" echo eQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYA
>> "%~1" echo aABaAEMASQArAFAARwBnAHkAUAB1AFMAOABrAGUAZQBjAG8ATwBTADQAagB1AFMA
>> "%~1" echo LwBuAGUAYQBLAHAARAB3AHYAYQBEAEkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBSAGgAWgB5AEkAKwA1AG8ANgBvADYASQAyAFEAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBKAHYAWgBIAGsAZwBZADIAMQBrAFIAMwBKAHAAWgBDAEkA
>> "%~1" echo KwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyADEA
>> "%~1" echo awBJAEcASgBzAGQAVwBVAGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBXADkA
>> "%~1" echo dQBQAFMASgByAFoAWABsAGYAZAAyAEYAcgBaAFgAVgB3AEkAagA0ADgAWQBqADcA
>> "%~1" echo awB1AHEANwBsAHMAWQA4AGcATAB5AEQAbABsAEsAVABwAGgAcABJADgATAAyAEkA
>> "%~1" echo KwBQAEgATgB3AFkAVwA0ACsANQBMAHUARgA1AFoAeQBvAEkARQBGAEUAUQBpAEQA
>> "%~1" echo bABuAEsAagBuAHUAcgAvAG0AbAA3AGIAbQBuAEkAbgBtAGwAWQBnADgATAAzAE4A
>> "%~1" echo dwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAARwBKADEAZABIAFIA
>> "%~1" echo dgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIAMQBrAEkARwBkAHkAWgBXAFYA
>> "%~1" echo dQBJAGkAQgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwAyAEYA
>> "%~1" echo bQBaAFYAOQB6AGIARwBWAGwAYwBDAEkAKwBQAEcASQArADUAYQA2AEoANQBZAFcA
>> "%~1" echo bwA1ADQAYQBFADUAYgBHAFAAUABDADkAaQBQAGoAeAB6AGMARwBGAHUAUAB1AGEA
>> "%~1" echo QgBvAHUAVwBrAGoAZQBTAC8AbgBlAFcAdQBpAE8AVwBBAHYATwBXADUAdAB1AFcA
>> "%~1" echo UABrAGUAbQBBAGcAZQBlAGQAbwBlAGUAYwBvAE8AbQBVAHIAagB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANAA4AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBiAFcAUQBnAFoAMwBKAGwAWgBXADQA
>> "%~1" echo aQBJAEcAUgBoAGQARwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAHkAWgBYAE4A
>> "%~1" echo MABiADMASgBsAFgAMwBOAHMAWgBXAFYAdwBJAGoANAA4AFkAagA3AG0AZwBhAEwA
>> "%~1" echo bABwAEkAMwBrAHYASgBIAG4AbgBLAEQAbwB0AG8AWABtAGwANwBZADgATAAyAEkA
>> "%~1" echo KwBQAEgATgB3AFkAVwA0ACsATgBTAEQAbABpAEkAYgBwAGsAcAAvAG4AaABvAFQA
>> "%~1" echo bABzAFkALwB2AHYASQB6AGwAdQBiAGIAbwBwADYAUABwAG0AYQBRAGcAYwBIAEoA
>> "%~1" echo dgBlAEYAOQBqAGIARwA5AHoAWgBUAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoA
>> "%~1" echo MQBkAEgAUgB2AGIAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBqAGIAVwBRAGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBXADkA
>> "%~1" echo dQBQAFMASgBqAGIAMgA1AHoAWgBYAEoAMgBZAFgAUgBwAGQAbQBVAGkAUABqAHgA
>> "%~1" echo aQBQAHUAUwAvAG4AZQBXAHUAaQBPAG0ANwBtAE8AaQB1AHAATwBXAEEAdgBEAHcA
>> "%~1" echo dgBZAGoANAA4AGMAMwBCAGgAYgBqADcAbQBnAGEATABsAHAASQAzAGwAagA0AEwA
>> "%~1" echo bQBsAGIARABsAHUAYgBiAGwAagA1AEgAcABnAEkARQBnAGMASABKAHYAZQBGADkA
>> "%~1" echo dgBjAEcAVgB1AFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcA
>> "%~1" echo bwBzAEkAUABvAHIANQBYAGwAdAA2AFgAawB2AFoAegBtAHEASwBIAGwAdgBJADgA
>> "%~1" echo OABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo MABZAFcAYwBpAFAAdQBtAGMAZwBPAGUAaAByAHUAaQB1AHAARAB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBpAGIAMgBSADUASQBHAE4AdABaAEUAZAB5AGEAVwBRAGkAUABqAHgA
>> "%~1" echo aQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBOAHQAWgBDAEIA
>> "%~1" echo aQBiAEgAVgBsAEkARwBSAGgAYgBtAGQAbABjAGsARgBqAGQARwBsAHYAYgBpAEkA
>> "%~1" echo ZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkAbQBSAGwAWQBuAFYA
>> "%~1" echo bgBYADIAMQB2AFoARwBVAGkAUABqAHgAaQBQAHUAVwBRAHIAKwBlAFUAcQBPAGkA
>> "%~1" echo dwBnACsAaQB2AGwAZQBhAG8AbwBlAFcAOABqAHoAdwB2AFkAagA0ADgAYwAzAEIA
>> "%~1" echo aABiAGoANwBrAHYANQAzAG0AagBJAEgAbABsAEsAVABwAGgAcABMAGoAZwBJAEUA
>> "%~1" echo eQBOAEMARABsAHMASQAvAG0AbAA3AGIAagBnAEkARgB3AGMAbQA5ADQAWAAyAE4A
>> "%~1" echo cwBiADMATgBsAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBQAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4A
>> "%~1" echo dABaAEMAQgBpAGIASABWAGwASQBHAFIAaABiAG0AZABsAGMAawBGAGoAZABHAGwA
>> "%~1" echo dgBiAGkASQBnAFoARwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBtAHQA
>> "%~1" echo bABaAFgAQgBmAFkAWABkAGgAYQAyAFUAaQBQAGoAeABpAFAAdQBXADYAbABPAGUA
>> "%~1" echo VQBxAE8AUwAvAG4AZQBhADAAdQB6AHcAdgBZAGoANAA4AGMAMwBCAGgAYgBqADcA
>> "%~1" echo bABrAEkAegBtAGwANwBiAG0AbABMAGsAZwBWADIAawB0AFIAbQBuAGoAZwBJAEYA
>> "%~1" echo egBiAEcAVgBsAGMARgA5ADAAYQBXADEAbABiADMAVgAwAFAAQwA5AHoAYwBHAEYA
>> "%~1" echo dQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoAeABpAGQAWABSADAAYgAyADQA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBoAGIAVwBKAGwAYwBpAEIA
>> "%~1" echo awBZAFcANQBuAFoAWABKAEIAWQAzAFIAcABiADIANABpAEkARwBSAGgAZABHAEUA
>> "%~1" echo dABZAFcATgAwAGEAVwA5AHUAUABTAEoAMwBhAFgASgBsAGIARwBWAHoAYwB5AEkA
>> "%~1" echo KwBQAEcASQArADUAYgB5AEEANQBaAEMAdgA1AHAAZQBnADUANwBxAC8ASQBFAEYA
>> "%~1" echo RQBRAGoAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoANwBwAG4ASQBEAG8AcABvAEUA
>> "%~1" echo ZwBWAFYATgBDAEkATwBXADMAcwB1AGEATwBpAE8AYQBkAGcAegB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANAA4AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBiAFcAUQBnAGMAbQBWAGsASQBHAFIA
>> "%~1" echo aABiAG0AZABsAGMAawBGAGoAZABHAGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEA
>> "%~1" echo aABZADMAUgBwAGIAMgA0ADkASQBuAGQAcABjAG0AVgBzAFoAWABOAHoAWAAyADkA
>> "%~1" echo bQBaAGkASQArAFAARwBJACsANQBZAFcAegA2AFoAZQB0ADUAcABlAGcANQA3AHEA
>> "%~1" echo LwBJAEUARgBFAFEAagB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AGwAaQBJAGYA
>> "%~1" echo bABtADUANABnAFYAVgBOAEMASQBPAGEAbwBvAGUAVwA4AGoAegB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo agBZAFgASgBrAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo bwBaAFcARgBrAEkAagA0ADgAYQBEAEkAKwA2AEwANgBUADUAWQBXAGwANQBMAGkA
>> "%~1" echo TwA1AGIAbQAvADUAcABLAHQAUABDADkAbwBNAGoANAA4AGMAMwBCAGgAYgBpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAZABHAEYAbgBJAGoANwBsAGsAYgAzAGsAdQA2AFEA
>> "%~1" echo OABMADMATgB3AFkAVwA0ACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQBtADkAawBlAFMAQgBqAGIAVwBSAEgAYwBtAGwA
>> "%~1" echo awBJAGoANAA4AFkAbgBWADAAZABHADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo agBiAFcAUQBpAEkARwBSAGgAZABHAEUAdABZAFcATgAwAGEAVwA5AHUAUABTAEoA
>> "%~1" echo cgBaAFgAbABmAGMAMgB4AGwAWgBYAEEAaQBQAGoAeABpAFAAawB0AEYAVwBVAE4A
>> "%~1" echo UABSAEUAVgBmAFUAMAB4AEYAUgBWAEEAOABMADIASQArAFAASABOAHcAWQBXADQA
>> "%~1" echo KwA1ADcATwA3ADUANwB1AGYANQA1ADIAaAA1ADUAeQBnADYAWgBTAHUAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB4AGkAZABYAFIA
>> "%~1" echo MABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoAQwBJAGcAWgBHAEYA
>> "%~1" echo MABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4AQgB5AGIAMwBoAGYAYgAzAEIA
>> "%~1" echo bABiAGkASQArAFAARwBJACsANQBiAG0ALwA1AHAASwB0AEkASABCAHkAYgAzAGgA
>> "%~1" echo ZgBiADMAQgBsAGIAagB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AG8AcAA2AFAA
>> "%~1" echo cABtAGEAVABrAHYAYQBuAG0AaQBMAFQAbQBxAEsASABtAGkANQAvAHYAdgBJAHoA
>> "%~1" echo bABoAFkASABvAHIAcgBqAG4AaABvAFQAbABzAFkAOAA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcASgAxAGQASABSAHYAYgBpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQAyADEAawBJAEcARgB0AFkAbQBWAHkASQBHAFIA
>> "%~1" echo aABiAG0AZABsAGMAawBGAGoAZABHAGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEA
>> "%~1" echo aABZADMAUgBwAGIAMgA0ADkASQBuAEIAeQBiADMAaABmAFkAMgB4AHYAYwAyAFUA
>> "%~1" echo aQBQAGoAeABpAFAAdQBXADUAdgArAGEAUwByAFMAQgB3AGMAbQA5ADQAWAAyAE4A
>> "%~1" echo cwBiADMATgBsAFAAQwA5AGkAUABqAHgAegBjAEcARgB1AFAAdQBhAG8AbwBlAGEA
>> "%~1" echo TABuACsAUwA5AHEAZQBhAEkAdABPAG0AZABvAE8AaQAvAGsAVAB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANAA4AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBiAFcAUQBnAFkAVwAxAGkAWgBYAEkA
>> "%~1" echo aQBJAEcAbABrAFAAUwBKAG4AYgAwAE4AMQBjADMAUgB2AGIAVQBKAHkAYgAyAEYA
>> "%~1" echo awBZADIARgB6AGQAQwBJACsAUABHAEkAKwA2AEkAZQBxADUAYQA2AGEANQBMAG0A
>> "%~1" echo SgA1AGIAbQAvADUAcABLAHQAUABDADkAaQBQAGoAeAB6AGMARwBGAHUAUAB1AFcA
>> "%~1" echo TwB1ACsAbQByAG0ATwBlADYAcAB5AEIAegBaAFgAUgAwAGEAVwA1AG4AYwB5AEQA
>> "%~1" echo cABvAGIAWABwAG4AYQBMAGwAagA1AEgAcABnAEkARQA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEMAOQBrAGEAWABZACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYA
>> "%~1" echo eQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYA
>> "%~1" echo aABaAEMASQArAFAARwBnAHkAUAB1AFcAeABqACsAVwA1AGwAZQBpADIAaABlAGEA
>> "%~1" echo WAB0AGoAdwB2AGEARABJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG4AUgBoAFoAeQBJACsANgBhAEsARQA2AEsANgArAFAAQwA5AHoAYwBHAEYA
>> "%~1" echo dQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG0ASgB2AFoASABrAGcAWQAyADEAawBSADMASgBwAFoAQwBJACsAUABHAEoA
>> "%~1" echo MQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAMgAxAGsASQBHAGQA
>> "%~1" echo eQBaAFcAVgB1AEkAaQBCAGsAWQBYAFIAaABMAFcARgBqAGQARwBsAHYAYgBqADAA
>> "%~1" echo aQBjADIATgB5AFoAVwBWAHUAWAB6AFYAdABJAGoANAA4AFkAagA0ADEASQBPAFcA
>> "%~1" echo SQBoAHUAbQBTAG4AKwBlAEcAaABPAFcAeABqAHoAdwB2AFkAagA0ADgAYwAzAEIA
>> "%~1" echo aABiAGoANQB6AFkAMwBKAGwAWgBXADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYA
>> "%~1" echo dgBkAFgAUQA5AE0AegBBAHcATQBEAEEAdwBQAEMAOQB6AGMARwBGAHUAUABqAHcA
>> "%~1" echo dgBZAG4AVgAwAGQARwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBOAHQAWgBDAEIAaQBiAEgAVgBsAEkARwBSAGgAYgBtAGQA
>> "%~1" echo bABjAGsARgBqAGQARwBsAHYAYgBpAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIA
>> "%~1" echo cABiADIANAA5AEkAbgBOAGoAYwBtAFYAbABiAGwAOAB5AE4ARwBnAGkAUABqAHgA
>> "%~1" echo aQBQAGoASQAwAEkATwBXAHcAagArAGEAWAB0AHUAUwA2AHIAdQBXAHgAagB6AHcA
>> "%~1" echo dgBZAGoANAA4AGMAMwBCAGgAYgBqADUAegBZADMASgBsAFoAVwA1AGYAYgAyAFoA
>> "%~1" echo bQBYADMAUgBwAGIAVwBWAHYAZABYAFEAOQBPAEQAWQAwAE0ARABBAHcATQBEAEEA
>> "%~1" echo OABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsAUABHAEoA
>> "%~1" echo MQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAMgAxAGsASQBpAEIA
>> "%~1" echo awBZAFgAUgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGMAMwBSAGgAZQBWADkA
>> "%~1" echo dgBaAG0AWQBpAFAAagB4AGkAUAB1AFcARgBzACsAbQBYAHIAZQBTAC8AbgBlAGEA
>> "%~1" echo TQBnAGUAVwBVAHAATwBtAEcAawBqAHcAdgBZAGoANAA4AGMAMwBCAGgAYgBqADUA
>> "%~1" echo egBkAEcARgA1AFgAMgA5AHUAUABUAEEAOABMADMATgB3AFkAVwA0ACsAUABDADkA
>> "%~1" echo aQBkAFgAUgAwAGIAMgA0ACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAMgAxAGsASQBHAEoAcwBkAFcAVQBnAFoARwBGAHUAWgAyAFYA
>> "%~1" echo eQBRAFcATgAwAGEAVwA5AHUASQBpAEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwA
>> "%~1" echo dgBiAGoAMABpAGMAMwBSAGgAZQBWADkAMQBjADIASgBmAFkAVwBNAGkAUABqAHgA
>> "%~1" echo aQBQAGwAVgBUAFEAaQA5AEIAUQB5AEQAawB2ADUAMwBtAGoASQBIAGwAbABLAFQA
>> "%~1" echo cABoAHAASQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAGMAMwBSAGgAZQBWADkA
>> "%~1" echo dgBiAGoAMAB6AFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkA
>> "%~1" echo dQBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcA
>> "%~1" echo bgBpAHIAYgBtAGcASQBIAGsAdQBJADcAbQBuAEkAMwBsAGkAcQBFADgATAAyAGcA
>> "%~1" echo eQBQAGoAeAB6AGMARwBGAHUASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAWQBXAGMA
>> "%~1" echo aQBQAHUAZQA3AHQATwBhAEsAcABEAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIA
>> "%~1" echo NQBJAEcATgB0AFoARQBkAHkAYQBXAFEAaQBQAGoAeABpAGQAWABSADAAYgAyADQA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMASQBnAGEAVwBRADkASQBtADEA
>> "%~1" echo aABiAG4AVgBoAGIARgBKAGwAWgBuAEoAbABjADIAZwBpAFAAagB4AGkAUAB1AFcA
>> "%~1" echo SQB0ACsAYQBXAHMATwBlAEsAdAB1AGEAQQBnAFQAdwB2AFkAagA0ADgAYwAzAEIA
>> "%~1" echo aABiAGoANwBwAGgANAAzAG0AbAByAEQAbwByADcAdgBsAGoANQBiAG8AcgByADcA
>> "%~1" echo bABwAEkAZgBtAGwAYgBEAGwAZwBMAHcAOABMADMATgB3AFkAVwA0ACsAUABDADkA
>> "%~1" echo aQBkAFgAUgAwAGIAMgA0ACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAMgAxAGsASQBpAEIAawBZAFgAUgBoAEwAVwBGAGoAZABHAGwA
>> "%~1" echo dgBiAGoAMABpAGMAbQBWAHoAZABHAEYAeQBkAEYAOQBoAFoARwBJAGkAUABqAHgA
>> "%~1" echo aQBQAHUAbQBIAGoAZQBXAFEAcgB5AEIAQgBSAEUASQA4AEwAMgBJACsAUABIAE4A
>> "%~1" echo dwBZAFcANAArADUATAB1AEYANgBZAGUATgA1AFoAQwB2ADUANQBTADEANgBJAFMA
>> "%~1" echo UgA1ADYAdQB2ADUAcAB5AE4ANQBZAHEAaABQAEMAOQB6AGMARwBGAHUAUABqAHcA
>> "%~1" echo dgBZAG4AVgAwAGQARwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBOAHQAWgBDAEIAawBZAFcANQBuAFoAWABKAEIAWQAzAFIA
>> "%~1" echo cABiADIANABpAEkARwBSAGgAZABHAEUAdABZAFcATgAwAGEAVwA5AHUAUABTAEoA
>> "%~1" echo eQBaAFgATgAwAGIAMwBKAGwAWAAyAEoAaABZADIAdAAxAGMAQwBJACsAUABHAEkA
>> "%~1" echo KwA1AEwAdQBPADUAYQBTAEgANQBMAHUAOQA1AG8ARwBpADUAYQBTAE4AUABDADkA
>> "%~1" echo aQBQAGoAeAB6AGMARwBGAHUAUAB1AGEAQgBvAHUAVwBrAGoAZQBtAG0AbAB1AGEA
>> "%~1" echo cwBvAGUAVwBHAG0AZQBXAEYAcABlAFcASgBqAGUAaQB1AHYAdQBlADkAcgBqAHcA
>> "%~1" echo dgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIAagA0ADgAWQBuAFYA
>> "%~1" echo MABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGkASQBHAGwA
>> "%~1" echo awBQAFMASgBuAGIAMAB4AHYAWgAzAE0AaQBQAGoAeABpAFAAdQBhAFQAagBlAFMA
>> "%~1" echo OQBuAE8AYQBYAHAAZQBXAC8AbAB6AHcAdgBZAGoANAA4AGMAMwBCAGgAYgBqADcA
>> "%~1" echo bQBuADYAWABuAG4ASQB2AG0AbABvAGYAawB1ADcAYgBtAGwANgBYAGwAdgA1AGMA
>> "%~1" echo OABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAMgBGAHkAWgBDAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAGEARwBWAGgAWgBDAEkAKwBQAEcAZwB5AFAAdQBXADkAawArAFcA
>> "%~1" echo SgBqAGUAYQBSAG0ATwBpAG0AZwBUAHcAdgBhAEQASQArAFAASABOAHcAWQBXADQA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABaAHkASQBnAGEAVwBRADkASQBtAE4A
>> "%~1" echo dgBiAG4ATgB2AGIARwBWAFQAZABHAEYAMABaAFMASQArAEwAVAB3AHYAYwAzAEIA
>> "%~1" echo aABiAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4A
>> "%~1" echo egBQAFMASgBpAGIAMgBSADUASQBqADQAOABkAEcARgBpAGIARwBVAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBSAGgAWQBtAHgAbABJAGoANAA4AGQASABJACsAUABIAFIA
>> "%~1" echo awBQAHUAaQAvAG4AdQBhAE8AcABUAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwA
>> "%~1" echo awBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABRADIAOQB1AGIAaQBJACsATABUAHcA
>> "%~1" echo dgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUAB1AGUA
>> "%~1" echo VQB0AGUAbQBIAGoAegB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoA
>> "%~1" echo agBiADIANQB6AGIAMgB4AGwAUQBtAEYAMABkAEcAVgB5AGUAUwBJACsATABUAHcA
>> "%~1" echo dgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUAB1AFMA
>> "%~1" echo OABrAGUAZQBjAG8ARAB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoA
>> "%~1" echo agBiADIANQB6AGIAMgB4AGwAVgAyAEYAcgBaAFMASQArAEwAVAB3AHYAZABHAFEA
>> "%~1" echo KwBQAEMAOQAwAGMAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAbABkAHAATABVAFoA
>> "%~1" echo cABQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQBOAHYAYgBuAE4A
>> "%~1" echo dgBiAEcAVgBYAGEAVwBaAHAASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIA
>> "%~1" echo eQBQAGoAdwB2AGQARwBGAGkAYgBHAFUAKwBQAEMAOQBrAGEAWABZACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQB6AFoAVwBOADAAYQBXADkA
>> "%~1" echo dQBQAGcAMABLAFAASABOAGwAWQAzAFIAcABiADIANABnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG4AQgBoAFoAMgBVAGkASQBHAGwAawBQAFMASgBrAFoAWABaAHAAWQAyAFUA
>> "%~1" echo aQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBOAGgAYwBtAFEA
>> "%~1" echo aQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAGwAWQBXAFEA
>> "%~1" echo aQBQAGoAeABvAE0AagA3AG8AcgByADcAbABwAEkAZgBtAG8AYQBQAG0AbwBZAGcA
>> "%~1" echo OABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo MABZAFcAYwBpAFAAdQBXAEYAcgBPAFcAOABnAEMAQgBCAFIARQBJAGcANQBZACsA
>> "%~1" echo cQA2AEsAKwA3AFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoARwBsADIAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AbAB1AFoAbQA5AEgAYwBtAGwA
>> "%~1" echo awBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHAAYgBtAFoA
>> "%~1" echo dgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcANAArADUAWQA2AEMANQBaAFcA
>> "%~1" echo RwBJAEMAOABnADUAWgBPAEIANQA0AG0ATQBQAEMAOQB6AGMARwBGAHUAUABqAHgA
>> "%~1" echo aQBQAGoAeAB6AGMARwBGAHUASQBHAGwAawBQAFMASgB0AFkAVwA1ADEAWgBtAEYA
>> "%~1" echo agBkAEgAVgB5AFoAWABJAGkAUABpADAAOABMADMATgB3AFkAVwA0ACsASQBDADgA
>> "%~1" echo ZwBQAEgATgB3AFkAVwA0AGcAYQBXAFEAOQBJAG0ASgB5AFkAVwA1AGsASQBqADQA
>> "%~1" echo dABQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBwAGIAbQBaAHYAVgBHAGwA
>> "%~1" echo cwBaAFMASQArAFAASABOAHcAWQBXADQAKwA1AFoANgBMADUAWQArADMAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB4AGkASQBHAGwAawBQAFMASgB0AGIAMgBSAGwAYgBDAEkA
>> "%~1" echo KwBMAFQAdwB2AFkAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAUwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4A
>> "%~1" echo dwBZAFcANAArADUATABxAG4ANQBaAE8AQgBJAEMAOABnADYASwA2ACsANQBhAFMA
>> "%~1" echo SABJAEMAOABnADUAcAAyAC8ANQA3AHEAbgBQAEMAOQB6AGMARwBGAHUAUABqAHgA
>> "%~1" echo aQBQAGoAeAB6AGMARwBGAHUASQBHAGwAawBQAFMASgB3AGMAbQA5AGsAZABXAE4A
>> "%~1" echo MABUAG0ARgB0AFoAUwBJACsATABUAHcAdgBjADMAQgBoAGIAagA0AGcATAB5AEEA
>> "%~1" echo OABjADMAQgBoAGIAaQBCAHAAWgBEADAAaQBjAEgASgB2AFoASABWAGoAZABFAFIA
>> "%~1" echo bABkAG0AbABqAFoAUwBJACsATABUAHcAdgBjADMAQgBoAGIAagA0AGcATAB5AEEA
>> "%~1" echo OABjADMAQgBoAGIAaQBCAHAAWgBEADAAaQBZAG0AOQBoAGMAbQBRAGkAUABpADAA
>> "%~1" echo OABMADMATgB3AFkAVwA0ACsAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AbAB1AFoAbQA5AFUAYQBXAHgA
>> "%~1" echo bABJAGoANAA4AGMAMwBCAGgAYgBqADUAVABiADAATQA4AEwAMwBOAHcAWQBXADQA
>> "%~1" echo KwBQAEcASQBnAGEAVwBRADkASQBuAE4AdgBZAHkASQArAEwAVAB3AHYAWQBqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo cABiAG0AWgB2AFYARwBsAHMAWgBTAEkAKwBQAEgATgB3AFkAVwA0ACsAUQBuAFYA
>> "%~1" echo cABiAEcAUQA4AEwAMwBOAHcAWQBXADQAKwBQAEcASQBnAGEAVwBRADkASQBtAEoA
>> "%~1" echo MQBhAFcAeABrAFMAVwBRAGkAUABpADAAOABMADIASQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEAVwA1AG0AYgAxAFIA
>> "%~1" echo cABiAEcAVQBpAFAAagB4AHoAYwBHAEYAdQBQAGsASgB5AFkAVwA1AGoAYQBEAHcA
>> "%~1" echo dgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAFkAbgBWAHAAYgBHAFIA
>> "%~1" echo QwBjAG0ARgB1AFkAMgBnAGkAUABpADAAOABMADIASQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEAVwA1AG0AYgAxAFIA
>> "%~1" echo cABiAEcAVQBpAFAAagB4AHoAYwBHAEYAdQBQAGsAbAB1AFkAMwBKAGwAYgBXAFYA
>> "%~1" echo dQBkAEcARgBzAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAEkARwBsAGsAUABTAEoA
>> "%~1" echo aQBkAFcAbABzAFoARQBsAHUAWQAzAEoAbABiAFcAVgB1AGQARwBGAHMASQBqADQA
>> "%~1" echo dABQAEMAOQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbQBsAHUAWgBtADkAVQBhAFcAeABsAEkAagA0ADgAYwAzAEIA
>> "%~1" echo aABiAGoANQBCAFEAawBrADgATAAzAE4AdwBZAFcANAArAFAARwBJAGcAYQBXAFEA
>> "%~1" echo OQBJAG0ARgBpAGEAUwBJACsATABUAHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBwAGIAbQBaAHYAVgBHAGwA
>> "%~1" echo cwBaAFMASQArAFAASABOAHcAWQBXADQAKwBWAG0AVgB1AFoARwA5AHkASQBGAEIA
>> "%~1" echo aABkAEcATgBvAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAEkARwBsAGsAUABTAEoA
>> "%~1" echo MgBaAFcANQBrAGIAMwBKAFEAWQBYAFIAagBhAEMASQArAEwAVAB3AHYAWQBqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo eQBiADMAYwBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAE4A
>> "%~1" echo aABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAGgA
>> "%~1" echo bABZAFcAUQBpAFAAagB4AG8ATQBqADcAbwByAHIANwBsAHAASQBmAGsAdQBJADcA
>> "%~1" echo bwB2ADUANwBtAGoAcQBVADgATAAyAGcAeQBQAGoAdwB2AFoARwBsADIAUABqAHgA
>> "%~1" echo awBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgA
>> "%~1" echo MABZAFcASgBzAFoAUwBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAGkAYgBHAFUA
>> "%~1" echo aQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwBRAFUAUgBDAEkATwBpADMAcgArAFcA
>> "%~1" echo KwBoAEQAdwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAGgAWgBHAEoA
>> "%~1" echo UQBZAFgAUgBvAEkAagA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgA
>> "%~1" echo MABjAGoANAA4AGQARwBRACsANgBLADYAKwA1AGEAUwBIADYASwBHAE0AUABDADkA
>> "%~1" echo MABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG0AUgBsAGQAbQBsAGoAWgBVAHgA
>> "%~1" echo cABiAG0AVQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIA
>> "%~1" echo eQBQAGoAeAAwAFoARAA1AFgAYQBTADEARwBhAFMAQgBKAFUARAB3AHYAZABHAFEA
>> "%~1" echo KwBQAEgAUgBrAEkARwBsAGsAUABTAEoAMwBhAFcAWgBwAFMAWABBAGkAUABpADAA
>> "%~1" echo OABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADUA
>> "%~1" echo QgBiAG0AUgB5AGIAMgBsAGsAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEA
>> "%~1" echo OQBJAG0ARgB1AFoASABKAHYAYQBXAFEAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcA
>> "%~1" echo dgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQANQBUAFIARQBzADgATAAzAFIA
>> "%~1" echo awBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBjADIAUgByAEkAagA0AHQAUABDADkA
>> "%~1" echo MABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQARwBRACsANQBhADYA
>> "%~1" echo SgA1AFkAVwBvADYASwBHAGwANQBMAGkAQgBQAEMAOQAwAFoARAA0ADgAZABHAFEA
>> "%~1" echo ZwBhAFcAUQA5AEkAbgBOAGwAWQAzAFYAeQBhAFgAUgA1AFUARwBGADAAWQAyAGcA
>> "%~1" echo aQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAAQwA5ADAAWQBXAEoA
>> "%~1" echo cwBaAFQANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkA
>> "%~1" echo KwA1ADYARwBzADUATAB1ADIANQBwAEcAWQA2AEsAYQBCAFAAQwA5AG8ATQBqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoA
>> "%~1" echo aQBiADIAUgA1AEkAagA0ADgAZABHAEYAaQBiAEcAVQBnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG4AUgBoAFkAbQB4AGwASQBqADQAOABkAEgASQArAFAASABSAGsAUAB1AGEA
>> "%~1" echo WQB2AHUAZQBrAHUAagB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoA
>> "%~1" echo awBhAFgATgB3AGIARwBGADUAVQAzAFYAdABiAFcARgB5AGUAUwBJACsATABUAHcA
>> "%~1" echo dgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUAB1AGUA
>> "%~1" echo RAByAGUAZQBLAHQAdQBhAEEAZwBUAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwA
>> "%~1" echo awBQAFMASgAwAGEARwBWAHkAYgBXAEYAcwBVADMAVgB0AGIAVwBGAHkAZQBTAEkA
>> "%~1" echo KwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABIAFIA
>> "%~1" echo awBQAHUAVwAzAHAAZQBXAE8AZwBpAC8AbQBvAEsASABsAGgANABZADgATAAzAFIA
>> "%~1" echo awBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBaAG0ARgBqAGQARwA5AHkAZQBWAE4A
>> "%~1" echo MQBiAFcAMQBoAGMAbgBrAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkA
>> "%~1" echo KwBQAEgAUgB5AFAAagB4ADAAWgBEADUAVwBhAFgASgAwAGQAVwBGAHMASQBFAFIA
>> "%~1" echo bABjADIAdAAwAGIAMwBBADgATAAzAFIAawBQAGoAeAAwAFoARAA0ADgAYwAzAEIA
>> "%~1" echo aABiAGkAQgBwAFoARAAwAGkAZABtAFIAUQBZAFcATgByAFkAVwBkAGwASQBqADQA
>> "%~1" echo dABQAEMAOQB6AGMARwBGAHUAUABpAEEAOABjADMAQgBoAGIAaQBCAHAAWgBEADAA
>> "%~1" echo aQBkAG0AUgBXAFoAWABKAHoAYQBXADkAdQBJAGoANAB0AFAAQwA5AHoAYwBHAEYA
>> "%~1" echo dQBQAGoAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AEwAMwBSAGgAWQBtAHgA
>> "%~1" echo bABQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkA
>> "%~1" echo ZwBZADIAeABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcA
>> "%~1" echo bQBpAFkAdgBtAG4ANABUAG4AdQByAC8AbgB0AEsASQA4AEwAMgBnAHkAUABqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoA
>> "%~1" echo dgBaAEgAawBpAFAAagB4ADAAWQBXAEoAcwBaAFMAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBkAEcARgBpAGIARwBVAGkAUABqAHgAMABjAGoANAA4AGQARwBRACsANQBiAGUA
>> "%~1" echo bQA1AG8AbQBMADUAcAArAEUANQA1AFMAMQA2AFkAZQBQAFAAQwA5ADAAWgBEADQA
>> "%~1" echo OABkAEcAUQBnAGEAVwBRADkASQBtAE4AdgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoA
>> "%~1" echo TQBaAFcAWgAwAFEAbQBGADAAZABHAFYAeQBlAFMASQArAEwAVAB3AHYAZABHAFEA
>> "%~1" echo KwBQAEMAOQAwAGMAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAdQBXAFAAcwArAGEA
>> "%~1" echo SgBpACsAYQBmAGgATwBlAFUAdABlAG0ASABqAHoAdwB2AGQARwBRACsAUABIAFIA
>> "%~1" echo awBJAEcAbABrAFAAUwBKAGoAYgAyADUAMABjAG0AOQBzAGIARwBWAHkAVQBtAGwA
>> "%~1" echo bgBhAEgAUgBDAFkAWABSADAAWgBYAEoANQBJAGoANAB0AFAAQwA5ADAAWgBEADQA
>> "%~1" echo OABMADMAUgB5AFAAagB4ADAAYwBqADQAOABkAEcAUQArADUAYgBlAG0ANQBvAG0A
>> "%~1" echo TAA1AHAAKwBFADUANABxADIANQBvAEMAQgBQAEMAOQAwAFoARAA0ADgAZABHAFEA
>> "%~1" echo ZwBhAFcAUQA5AEkAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAE0AWgBXAFoA
>> "%~1" echo MABVADMAUgBoAGQASABWAHoASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIA
>> "%~1" echo eQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwA1AFkAKwB6ADUAbwBtAEwANQBwACsA
>> "%~1" echo RQA1ADQAcQAyADUAbwBDAEIAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEA
>> "%~1" echo OQBJAG0ATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBTAGEAVwBkAG8AZABGAE4A
>> "%~1" echo MABZAFgAUgAxAGMAeQBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQA
>> "%~1" echo OABMADMAUgBoAFkAbQB4AGwAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG0AeAB2AFoAeQBJAGcAYQBXAFEAOQBJAG0ATgB2AGIAbgBSAHkAYgAyAHgA
>> "%~1" echo cwBaAFgASgBJAGEAVwA1ADAASQBqADQAdABQAEMAOQBrAGEAWABZACsAUABDADkA
>> "%~1" echo awBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAFkAMgBGAHkAWgBDAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMABpAGEARwBWAGgAWgBDAEkAKwBQAEcAZwB5AFAAdQBlAFUAdABlAGEA
>> "%~1" echo NgBrAE8AZQBLAHQAdQBhAEEAZwBUAHcAdgBhAEQASQArAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAbQA5AGsAZQBTAEkA
>> "%~1" echo KwBQAEgAUgBoAFkAbQB4AGwASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAWQBXAEoA
>> "%~1" echo cwBaAFMASQArAFAASABSAHkAUABqAHgAMABaAEQANQB0AFUAMwBSAGgAZQBVADkA
>> "%~1" echo dQBQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQAxAFQAZABHAEYA
>> "%~1" echo NQBUADIANABpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIA
>> "%~1" echo eQBQAGoAeAAwAFoARAA1AHQAVQBIAEoAdgBlAEcAbAB0AGEAWABSADUAVQBHADkA
>> "%~1" echo egBhAFgAUgBwAGQAbQBVADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAA
>> "%~1" echo aQBiAFYAQgB5AGIAMwBoAHAAYgBXAGwAMABlAFYAQgB2AGMAMgBsADAAYQBYAFoA
>> "%~1" echo bABJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB4ADAAYwBqADQA
>> "%~1" echo OABkAEcAUQArAGIAVgBOADAAWQBYAGwAUABiAGwAZABvAGEAVwB4AGwAVQBHAHgA
>> "%~1" echo MQBaADIAZABsAFoARQBsAHUAVQAyAFYAMABkAEcAbAB1AFoAegB3AHYAZABHAFEA
>> "%~1" echo KwBQAEgAUgBrAEkARwBsAGsAUABTAEoAdABVADMAUgBoAGUAVQA5AHUAVQAyAFYA
>> "%~1" echo MABkAEcAbAB1AFoAeQBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQA
>> "%~1" echo OABkAEgASQArAFAASABSAGsAUABsAE4AcwBaAFcAVgB3AEkASABSAHAAYgBXAFYA
>> "%~1" echo dgBkAFgAUQA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAYwBHADkA
>> "%~1" echo MwBaAFgASgBUAGIARwBWAGwAYwBFAHgAcABiAG0AVQBpAFAAaQAwADgATAAzAFIA
>> "%~1" echo awBQAGoAdwB2AGQASABJACsAUABDADkAMABZAFcASgBzAFoAVAA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwA
>> "%~1" echo MgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkA
>> "%~1" echo KwA1AGIAZQBsADUAWQA2AEMASQBDADgAZwA1AHEAQwBoADUAWQBlAEcANQBvADYA
>> "%~1" echo bwA1AHAAYQB0ADYATAA2ADUANQA1AFcATQBQAEMAOQBvAE0AagA0ADgATAAyAFIA
>> "%~1" echo cABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIA
>> "%~1" echo NQBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAHMAYgAyAGMA
>> "%~1" echo aQBQAHUAVwBQAHIAKwBTADcAcABlAGEAWQB2AHUAZQBrAHUAaQBCAFIAZABXAFYA
>> "%~1" echo egBkAEMARABsAGgAYQB6AGwAdgBJAEEAZwBRAFUAUgBDAEkATwBhAGEAdABPAG0A
>> "%~1" echo YwBzAHUAZQBhAGgAQwBCAEcAWQBXAE4AMABiADMASgA1AEkAQwA4AGcAVAAyADUA
>> "%~1" echo cwBhAFcANQBsAEkARwBOAGgAYgBHAGwAaQBjAG0ARgAwAGEAVwA5AHUASQBPAGUA
>> "%~1" echo NgB2ACsAZQAwAG8AdQArADgAagBPAFMAKwBpACsAVwBtAGcAaQBCAEYAZABYAEoA
>> "%~1" echo bABhADIASABqAGcASQBGAFEAVgBsAFEAeABMAGoASABqAGcASQBGAHoAZABHAEYA
>> "%~1" echo MABhAFcAOQB1AEwAMgB4AHYAWQAyAEYAMABhAFcAOQB1AEwAMwBSAGwAYwAzAFEA
>> "%~1" echo ZwA1AEwAdQBqADUANgBDAEIANAA0AEMAQwA1AEwAaQBOADYASQBPADkANQBvAHEA
>> "%~1" echo SwA1AFkAYQBGADYAWQBPAG8ANQBMAHUAagA1ADYAQwBCADUAWQArAHYANgBaADIA
>> "%~1" echo ZwA1ADcAKwA3ADYASwArAFIANQBvAGkAUQA1AFkAVwAzADUATAAyAFQANQBaAHUA
>> "%~1" echo OQA1AGEANgAyADQANABDAEIANQBaACsATwA1AGIAaQBDADUAbwBpAFcANQBiAGUA
>> "%~1" echo bAA1AFkANgBDADcANwB5AGIAVgAyAGsAdABSAG0AawBnADUAWgB1ADkANQBhADYA
>> "%~1" echo MgA1ADYAQwBCADUATABtAGYANQBMAGkATgA1ADYAMgBKADUATABxAE8ANQBZAGUA
>> "%~1" echo NgA1AEwAcQBuADUAWgB5AHcANAA0AEMAQwA1AGEANgBNADUAcABXADAANQBhADIA
>> "%~1" echo WAA1AHEANgAxADYASwArADMANQA1AFMAbwA0AG8AQwBjADUATABpAEEANgBaAFMA
>> "%~1" echo dQA1AGEAKwA4ADUAWQBlADYANgBLADYAKwA1AGEAUwBIADUAWQBXAG8ANgBZAE8A
>> "%~1" echo bwA1AEwAKwBoADUAbwBHAHYANABvAEMAZAA0ADQAQwBDAFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AHoAWgBXAE4A
>> "%~1" echo MABhAFcAOQB1AFAAZwAwAEsAUABIAE4AbABZADMAUgBwAGIAMgA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBCAGgAWgAyAFUAaQBJAEcAbABrAFAAUwBKAHoAWgBYAFIA
>> "%~1" echo MABhAFcANQBuAGMAeQBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAA
>> "%~1" echo aQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUAaQBIAHEAdQBXAHUAbQB1AFMA
>> "%~1" echo NQBpAFMAQgB6AFoAWABSADAAYQBXADUAbgBjAHkAQgB3AGQAWABRADgATAAyAGcA
>> "%~1" echo eQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0A
>> "%~1" echo OQBJAG0ASgB2AFoASABrAGcAWgBtADkAeQBiAFMASQArAFAASABOAGwAYgBHAFYA
>> "%~1" echo agBkAEMAQgBwAFoARAAwAGkAWQAzAFYAegBkAEcAOQB0AFQAbgBNAGkAUABqAHgA
>> "%~1" echo dgBjAEgAUgBwAGIAMgA0ACsAWgAyAHgAdgBZAG0ARgBzAFAAQwA5AHYAYwBIAFIA
>> "%~1" echo cABiADIANAArAFAARwA5AHcAZABHAGwAdgBiAGoANQB6AGUAWABOADAAWgBXADAA
>> "%~1" echo OABMADIAOQB3AGQARwBsAHYAYgBqADQAOABiADMAQgAwAGEAVwA5AHUAUABuAE4A
>> "%~1" echo bABZADMAVgB5AFoAVAB3AHYAYgAzAEIAMABhAFcAOQB1AFAAagB3AHYAYwAyAFYA
>> "%~1" echo cwBaAFcATgAwAFAAagB4AHAAYgBuAEIAMQBkAEMAQgBwAFoARAAwAGkAWQAzAFYA
>> "%~1" echo egBkAEcAOQB0AFMAMgBWADUASQBpAEIAdwBiAEcARgBqAFoAVwBoAHYAYgBHAFIA
>> "%~1" echo bABjAGoAMABpADYAWgBTAHUANQBaAEMATgA3ADcAeQBNADUATAA2AEwANQBhAGEA
>> "%~1" echo QwBJAEgATgBqAGMAbQBWAGwAYgBsADkAdgBaAG0AWgBmAGQARwBsAHQAWgBXADkA
>> "%~1" echo MQBkAEMASQArAFAARwBsAHUAYwBIAFYAMABJAEcAbABrAFAAUwBKAGoAZABYAE4A
>> "%~1" echo MABiADIAMQBXAFkAVwB4ADEAWgBTAEkAZwBjAEcAeABoAFkAMgBWAG8AYgAyAHgA
>> "%~1" echo awBaAFgASQA5AEkAdQBXAEEAdgBDAEkAKwBQAEcASgAxAGQASABSAHYAYgBpAEIA
>> "%~1" echo agBiAEcARgB6AGMAegAwAGkAWQBuAFIAdQBJAGkAQgBwAFoARAAwAGkAWQAzAFYA
>> "%~1" echo egBkAEcAOQB0AFUAMgBWADAASQBqADcAbABoAHAAbgBsAGgAYQBVADgATAAyAEoA
>> "%~1" echo MQBkAEgAUgB2AGIAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBqAFkAWABKAGsASQBqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQA
>> "%~1" echo OABhAEQASQArADUAWQArAFIANgBZAEMAQgA2AEkAZQBxADUAYQA2AGEANQBMAG0A
>> "%~1" echo SgA1AGIAbQAvADUAcABLAHQAUABDADkAbwBNAGoANAA4AEwAMgBSAHAAZABqADQA
>> "%~1" echo OABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBpAGIAMgBSADUASQBHAFoA
>> "%~1" echo dgBjAG0AMABpAEkASABOADAAZQBXAHgAbABQAFMASgBuAGMAbQBsAGsATABYAFIA
>> "%~1" echo bABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBXAFoA
>> "%~1" echo eQBJAEQAZwB5AGMASABnAGkAUABqAHgAcABiAG4AQgAxAGQAQwBCAHAAWgBEADAA
>> "%~1" echo aQBZAG4ASgB2AFkAVwBSAGoAWQBYAE4AMABUAG0ARgB0AFoAUwBJAGcAYwBHAHgA
>> "%~1" echo aABZADIAVgBvAGIAMgB4AGsAWgBYAEkAOQBJAHUAUwArAGkAKwBXAG0AZwBpAEIA
>> "%~1" echo agBiADIAMAB1AGIAMgBOADEAYgBIAFYAegBMAG4AWgB5AGMARwA5ADMAWgBYAEoA
>> "%~1" echo dABZAFcANQBoAFoAMgBWAHkATABuAEIAeQBiADMAaABmAGIAMwBCAGwAYgBpAEkA
>> "%~1" echo KwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQBuAFIA
>> "%~1" echo dQBJAGkAQgBwAFoARAAwAGkAWQAzAFYAegBkAEcAOQB0AFEAbgBKAHYAWQBXAFIA
>> "%~1" echo agBZAFgATgAwAEkAagA3AGwAagA1AEgAcABnAEkARQA4AEwAMgBKADEAZABIAFIA
>> "%~1" echo dgBiAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgATAAzAE4A
>> "%~1" echo bABZADMAUgBwAGIAMgA0ACsAUABIAE4AbABZADMAUgBwAGIAMgA0AGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AEkAbgBCAGgAWgAyAFUAaQBJAEcAbABrAFAAUwBKAHMAYgAyAGQA
>> "%~1" echo egBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAWQBYAEoA
>> "%~1" echo awBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AWgBXAEYA
>> "%~1" echo awBJAGoANAA4AGEARABJACsANQBwAGUAbAA1AGIAKwBYAFAAQwA5AG8ATQBqADQA
>> "%~1" echo OABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAZABHADQA
>> "%~1" echo ZwBaADIAaAB2AGMAMwBRAGkASQBHAGwAawBQAFMASgB5AFoAVwBaAHkAWgBYAE4A
>> "%~1" echo bwBUAEcAOQBuAGMAeQBJACsANQBZAGkAMwA1AHAAYQB3ADUAcABlAGwANQBiACsA
>> "%~1" echo WABQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEMAOQBrAGEAWABZACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUAUwBJACsAUABHAFIA
>> "%~1" echo cABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAbAB1AGEAUwBJAGcAYwAzAFIA
>> "%~1" echo NQBiAEcAVQA5AEkAbQAxAGgAYwBtAGQAcABiAGkAMQBpAGIAMwBSADAAYgAyADAA
>> "%~1" echo NgBNAFQASgB3AGUAQwBJACsAUABIAE4AdwBZAFcANAArADUAcABlAGwANQBiACsA
>> "%~1" echo WAA1AHAAYQBIADUATAB1ADIAUABDADkAegBjAEcARgB1AFAAagB4AGkASQBHAGwA
>> "%~1" echo awBQAFMASgBzAGIAMgBkAFEAWQBYAFIAbwBJAGoANAB0AFAAQwA5AGkAUABqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAHgA
>> "%~1" echo dgBaAHkASQBnAGEAVwBRADkASQBtAHgAdgBaADAASgB2AGUAQwBJACsANQA2ADIA
>> "%~1" echo SgA1AGIANgBGADUAcABPAE4ANQBMADIAYwBMAGkANAB1AFAAQwA5AGsAYQBYAFkA
>> "%~1" echo KwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AHoAWgBXAE4A
>> "%~1" echo MABhAFcAOQB1AFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AGIAVwBGAHAAYgBqADQA
>> "%~1" echo OABMADIAUgBwAGQAagA0AE4AQwBqAHgAegBZADMASgBwAGMASABRACsARABRAHAA
>> "%~1" echo agBiADIANQB6AGQAQwBCAFUAVAAwAHQARgBUAGoAMABuAFcAMQB0AFUAVAAwAHQA
>> "%~1" echo RgBUAGwAMQBkAEoAegBzAE4AQwBtAE4AdgBiAG4ATgAwAEkAQwBRADkAYQBXAFEA
>> "%~1" echo OQBQAG0AUgB2AFkAMwBWAHQAWgBXADUAMABMAG0AZABsAGQARQBWAHMAWgBXADEA
>> "%~1" echo bABiAG4AUgBDAGUAVQBsAGsASwBHAGwAawBLAFQAcwBOAEMAbQBOAHYAYgBuAE4A
>> "%~1" echo MABJAEgAQgBoAFoAMgBWAHoAUABYAHQAdgBkAG0AVgB5AGQAbQBsAGwAZAB6AHAA
>> "%~1" echo YgBKACsAYQBBAHUAKwBpAG4AaQBDAGMAcwBKACsAZQBLAHQAdQBhAEEAZwBlAGEA
>> "%~1" echo TQBoACsAYQBnAGgAKwBXAFMAagBPAGkAdQB2AHUAVwBrAGgAKwBhAG0AZwB1AGkA
>> "%~1" echo bgBpAEMAZABkAEwARwBOAHYAYgBuAE4AdgBiAEcAVQA2AFcAeQBmAGwAdgA2AHYA
>> "%~1" echo bQBqAGIAZgBtAGoAcQBmAGwAaQBMAGIAbABqADcAQQBuAEwAQwBmAG0AbQA3AFQA
>> "%~1" echo bABwAEoAcgBsAHUATABqAG4AbABLAGcAZwBRAFUAUgBDAEkATwBhAFQAagBlAFMA
>> "%~1" echo OQBuAE8AVwBGAHAAZQBXAFAAbwB5AGQAZABMAEcAUgBsAGQAbQBsAGoAWgBUAHAA
>> "%~1" echo YgBKACsAaQB1AHYAdQBXAGsAaAArAFMALwBvAGUAYQBCAHIAeQBjAHMASgArAGUA
>> "%~1" echo egB1ACsAZQA3AG4AKwBPAEEAZwBWAFoAcABjAG4AUgAxAFkAVwB3AGcAUgBHAFYA
>> "%~1" echo egBhADMAUgB2AGMATwBPAEEAZwBlAGEASgBpACsAYQBmAGgATwBXAFMAagBPAGUA
>> "%~1" echo VQB0AGUAYQA2AGsATwBlADYAdgArAGUAMABvAGkAZABkAEwASABOAGwAZABIAFIA
>> "%~1" echo cABiAG0AZAB6AE8AbABzAG4ANgBhAHUAWQA1ADcAcQBuAEkASABOAGwAZABIAFIA
>> "%~1" echo cABiAG0AZAB6AEoAeQB3AG4ANgBMAEMAbwA1AG8AVwBPADUAWQBhAFoANQBZAFcA
>> "%~1" echo bABJAEUARgB1AFoASABKAHYAYQBXAFEAZwBjADIAVgAwAGQARwBsAHUAWgAzAE0A
>> "%~1" echo ZwA1AG8AaQBXADUAYgBtAC8ANQBwAEsAdABKADEAMABzAGIARwA5AG4AYwB6AHAA
>> "%~1" echo YgBKACsAYQBYAHAAZQBXAC8AbAB5AGMAcwBKACsAYQBjAGcATwBpAC8AawBlAFMA
>> "%~1" echo NABnAE8AYQBzAG8AZQBhAFQAagBlAFMAOQBuAE8AZQA3AGsAKwBhAGUAbgBDAGQA
>> "%~1" echo ZABmAFQAcwBOAEMAbQBOAHYAYgBuAE4AMABJAEgAUgBvAFoAVwAxAGwAUwAyAFYA
>> "%~1" echo NQBQAFMAZAB4AGQAVwBWAHoAZABFAEYAawBZAGwAUgBvAFoAVwAxAGwAVgBqAFkA
>> "%~1" echo bgBPAHcAMABLAFkAMgA5AHUAYwAzAFEAZwBZADIAOQB1AFoAbQBsAHkAYgBWAFIA
>> "%~1" echo bABlAEgAUQA5AGUAdwAwAEsASQBDAEIAawBaAFcASgAxAFoAMQA5AHQAYgAyAFIA
>> "%~1" echo bABPAGkAZgBrAHYASgByAGwAdgBJAEQAbABrAEsALwBrAHYANQAzAG0AagBJAEgA
>> "%~1" echo bABsAEsAVABwAGgAcABMAGoAZwBJAEYAWABhAFMAMQBHAGEAUwBEAGsAdQBJADMA
>> "%~1" echo awB2AEoASABuAG4ASwBEAGoAZwBJAEUAeQBOAEMARABsAHMASQAvAG0AbAA3AGIA
>> "%~1" echo bABzAFkALwBsAHUAWgBYAGwAawBvAHcAZwBjAEgASgB2AGUARgA5AGoAYgBHADkA
>> "%~1" echo egBaAGUAKwA4AGoATwBXAFAAcQB1AFcANwB1AHUAaQB1AHIAdQBlAGYAcgBlAGEA
>> "%~1" echo WAB0AHUAbQBYAHQATwBpAHcAZwArAGkAdgBsAGUATwBBAGcAaQBjAHMARABRAG8A
>> "%~1" echo ZwBJAEcAdABsAFoAWABCAGYAWQBYAGQAaABhADIAVQA2AEoAKwBTADgAbQB1AFcA
>> "%~1" echo RwBtAGUAVwBGAHAAZQBTAC8AbgBlAGEATQBnAGUAVwBVAHAATwBtAEcAawB1AE8A
>> "%~1" echo QQBnAFYAZABwAEwAVQBaAHAASQBPAFMANABqAGUAUwA4AGsAZQBlAGMAbwBPAE8A
>> "%~1" echo QQBnAFQASQAwAEkATwBXAHcAagArAGEAWAB0AHUAVwB4AGoAKwBXADUAbABlAE8A
>> "%~1" echo QQBnAFgATgBzAFoAVwBWAHcAWAAzAFIAcABiAFcAVgB2AGQAWABRADkATABUAEgA
>> "%~1" echo dgB2AEkAegBsAHUAYgBiAGwAagA1AEgAcABnAEkARQBnAGMASABKAHYAZQBGADkA
>> "%~1" echo agBiAEcAOQB6AFoAZQBPAEEAZwBpAGMAcwBEAFEAbwBnAEkASABkAHAAYwBtAFYA
>> "%~1" echo cwBaAFgATgB6AE8AaQBmAGsAdgBKAHIAbAB2AEkARABsAGsASwA4AGcATgBUAFUA
>> "%~1" echo MQBOAFMARABtAGwANgBEAG4AdQByADgAZwBRAFUAUgBDADcANwB5AE0ANQBaAEMA
>> "%~1" echo TQA1AEwAaQBBADUAYgBHAEEANQBaACsAZgA1ADcAMgBSADUAWQBhAEYANQBZACsA
>> "%~1" echo dgA2AEkATwA5ADYASwBLAHIANgBMACsAZQA1AG8ANgBsADQANABDAEMANQA1AFMA
>> "%~1" echo bwA1AGEANgBNADYASwArADMANQBZAFcAegA2AFoAZQB0ADUAcABlAGcANQA3AHEA
>> "%~1" echo LwBJAEUARgBFAFEAdQBPAEEAZwBpAGMAcwBEAFEAbwBnAEkASABkAHAAYwBtAFYA
>> "%~1" echo cwBaAFgATgB6AFgAMgA5AG0AWgBqAG8AbgA1AEwAeQBhADYASwA2AHAASQBHAEYA
>> "%~1" echo awBZAG0AUQBnADUAWQBpAEgANQBaAHUAZQBJAEYAVgBUAFEAdQArADgAbQArAFcA
>> "%~1" echo bQBnAHUAYQBlAG4ATwBXADkAawArAFcASgBqAGUAbQBkAG8AQwBCAFgAYQBTADEA
>> "%~1" echo RwBhAFMARABvAHYANQA3AG0AagBxAFgAdgB2AEkAegBtAGwAcQAzAGwAdgBJAEQA
>> "%~1" echo bABzAFoANwBrAHUAbwA3AG0AcgBhAFAAbAB1AEwAagBuAGoAcgBEAG8AcwBhAEgA
>> "%~1" echo agBnAEkASQBuAEwAQQAwAEsASQBDAEIAegBZADMASgBsAFoAVwA1AGYATQBqAFIA
>> "%~1" echo bwBPAGkAZgBrAHYASgByAG0AaQBvAHIAbABzAFkALwBsAHUAWgBYAG8AdABvAFgA
>> "%~1" echo bQBsADcAYgBtAGwATABuAGsAdQBMAG8AZwBNAGoAUQBnADUAYgBDAFAANQBwAGUA
>> "%~1" echo MgA3ADcAeQBNADUAWQArAHYANgBJAE8AOQA1AGEAKwA4ADYASQBlADAANQBhAFMA
>> "%~1" echo MAA1AHAAaQArADYAWgBXAC8ANQBwAGUAMgA2AFoAZQAwADUATABpAE4ANQA0AGEA
>> "%~1" echo RQA1AGIARwBQADQANABDAEMASgB5AHcATgBDAGkAQQBnAGMAMwBSAGgAZQBWADkA
>> "%~1" echo MQBjADIASgBmAFkAVwBNADYASgArAFMAOABtAHUAaQB1AHEAUwBCAFYAVQAwAEkA
>> "%~1" echo dgBRAFUATQBnADUAbwArAFMANQA1AFMAMQA1AHAAZQAyADUATAArAGQANQBvAHkA
>> "%~1" echo QgA1AFoAUwBrADYAWQBhAFMANAA0AEMAQwBKAHkAdwBOAEMAaQBBAGcAYwBIAEoA
>> "%~1" echo dgBlAEYAOQBqAGIARwA5AHoAWgBUAG8AbgA1AEwAeQBhADUAcQBpAGgANQBvAHUA
>> "%~1" echo ZgA1AEwAMgBwADUAbwBpADAANgBaADIAZwA2AEwAKwBSADcANwB5AE0ANQBZACsA
>> "%~1" echo dgA2AEkATwA5ADYAWgBpADcANQBxADIAaQA2AEkAZQBxADUAWQBxAG8ANQA0AGEA
>> "%~1" echo RQA1AGIARwBQADQANABDAEMASgB5AHcATgBDAGkAQQBnAGMAbQBWAHoAZABHADkA
>> "%~1" echo eQBaAFYAOQBpAFkAVwBOAHIAZABYAEEANgBKACsAUwA4AG0AdQBhAEsAaQB1AG0A
>> "%~1" echo bQBsAHUAYQBzAG8AZQBXAEcAbQBlAFcARgBwAGUAVwBKAGoAZQBXAGsAaAArAFMA
>> "%~1" echo NwB2AGUAVwBBAHYATwBhAEIAbwB1AFcAawBqAGUAVwBiAG4AaQBCAFIAZABXAFYA
>> "%~1" echo egBkAE8AKwA4AGoATwBXADUAdAB1AFcAUABrAGUAbQBBAGcAUwBCAHcAYwBtADkA
>> "%~1" echo NABYADIAOQB3AFoAVwA3AGoAZwBJAEkAbgBMAEEAMABLAEkAQwBCAGoAZABYAE4A
>> "%~1" echo MABiADIAMQBmAGMAMgBWADAAZABHAGwAdQBaAHoAbwBuADUATAB5AGEANQA1AHUA
>> "%~1" echo MAA1AG8ANgBsADUAWQBhAFoASQBFAEYAdQBaAEgASgB2AGEAVwBRAGcAYwAyAFYA
>> "%~1" echo MABkAEcAbAB1AFoAMwBQAGoAZwBJAEwAcABsAEoAbgBvAHIANgAvAHAAbABLADcA
>> "%~1" echo bABnAEwAegBsAGoANgAvAG8AZwA3ADMAbAB2AGIASABsAGsANAAzAGsAdgBKAEgA
>> "%~1" echo bgBuAEsARABqAGcASQBIAG4AdgBaAEgAbgB1ADUAegBtAGkASgBiAG8AcwBJAFAA
>> "%~1" echo bwByADUAWABqAGcASQBJAG4ATABBADAASwBJAEMAQgBqAGQAWABOADAAYgAyADEA
>> "%~1" echo ZgBZAG4ASgB2AFkAVwBSAGoAWQBYAE4AMABPAGkAZgBrAHYASgByAGwAagA1AEgA
>> "%~1" echo cABnAEkASABvAGgANgByAGwAcgBwAHIAawB1AFkAawBnAFEAVwA1AGsAYwBtADkA
>> "%~1" echo cABaAEMARABsAHUAYgAvAG0AawBxADMAdgB2AEkAegBsAGoANgByAGwAdQA3AHIA
>> "%~1" echo bwByAHEANwBrAHYAYQBEAG0AbQBJADcAbgBvAGEANwBuAG4ANgBYAHAAZwBaAE0A
>> "%~1" echo ZwBZAFcATgAwAGEAVwA5AHUASQBPAFcAUQBxACsAUwA1AGkAZQBhAFgAdAB1AFMA
>> "%~1" echo OQB2ACsAZQBVAHEATwBPAEEAZwBpAGMATgBDAG4AMAA3AEQAUQBwAGoAYgAyADUA
>> "%~1" echo egBkAEMAQgB3AFkAWABKAGgAYgBVAFIAbABaAG4ATQA5AFcAdwAwAEsASQBDAEIA
>> "%~1" echo NwBhADIAVgA1AE8AaQBkAHoAZABHAEYANQBUADIANABuAEwARwA1AGgAYgBXAFUA
>> "%~1" echo NgBKACsAUwAvAG4AZQBhAE0AZwBlAFcAVQBwAE8AbQBHAGsAaQBjAHMAYwAyAFYA
>> "%~1" echo MABkAEcAbAB1AFoAegBvAG4AWgAyAHgAdgBZAG0ARgBzAEwAbgBOADAAWQBYAGwA
>> "%~1" echo ZgBiADIANQBmAGQAMgBoAHAAYgBHAFYAZgBjAEcAeAAxAFoAMgBkAGwAWgBGADkA
>> "%~1" echo cABiAGkAYwBzAGMAMgBGAG0AWgBUAG8AbgBNAEMAYwBzAFkAVwBOADAAYQBXADkA
>> "%~1" echo dQBPAGkAZAB5AFoAWABOAGwAZABGADkAegBkAEcARgA1AFgAMgA5AHUASgB5AHgA
>> "%~1" echo dQBiADMAUgBsAE8AaQBjAHcAUABlAFcARgBnAGUAaQB1AHUATwBhAHQAbwArAFcA
>> "%~1" echo NAB1AE8AUwA4AGsAZQBlAGMAbwBPACsAOABtAHoATQA5AFYAVgBOAEMATAAwAEYA
>> "%~1" echo RABJAE8AYQBQAGsAdQBlAFUAdABlAFMALwBuAGUAYQBNAGcAZQBXAFUAcABPAG0A
>> "%~1" echo RwBrAGkAZAA5AEwAQQAwAEsASQBDAEIANwBhADIAVgA1AE8AaQBkADMAYQBXAFoA
>> "%~1" echo cABVADIAeABsAFoAWABBAG4ATABHADUAaABiAFcAVQA2AEoAMQBkAHAATABVAFoA
>> "%~1" echo cABJAE8AUwA4AGsAZQBlAGMAbwBPAGUAdABsAHUAZQBWAHAAUwBjAHMAYwAyAFYA
>> "%~1" echo MABkAEcAbAB1AFoAegBvAG4AWgAyAHgAdgBZAG0ARgBzAEwAbgBkAHAAWgBtAGwA
>> "%~1" echo ZgBjADIAeABsAFoAWABCAGYAYwBHADkAcwBhAFcATgA1AEoAeQB4AHoAWQBXAFoA
>> "%~1" echo bABPAGkAYwB4AEoAeQB4AGgAWQAzAFIAcABiADIANAA2AEoAMwBKAGwAYwAyAFYA
>> "%~1" echo MABYADMAZABwAFoAbQBsAGYAYwAyAHgAbABaAFgAQQBuAEwARwA1AHYAZABHAFUA
>> "%~1" echo NgBKAHoARQA5ADUATAArAGQANQBhADYASQA2AGIAdQBZADYASwA2AGsANwA3AHkA
>> "%~1" echo YgBNAGoAMwBtAGwANgBmAG4AaQBZAGoAbQBzAEwAagBrAHUASQAzAGsAdgBKAEgA
>> "%~1" echo bgBuAEsAQQBuAGYAUwB3AE4AQwBpAEEAZwBlADIAdABsAGUAVABvAG4AYwAyAE4A
>> "%~1" echo eQBaAFcAVgB1AFQAMgBaAG0ASgB5AHgAdQBZAFcAMQBsAE8AaQBmAGwAcwBZAC8A
>> "%~1" echo bAB1AFoAWABvAHQAbwBYAG0AbAA3AFkAbgBMAEgATgBsAGQASABSAHAAYgBtAGMA
>> "%~1" echo NgBKADMATgA1AGMAMwBSAGwAYgBTADUAegBZADMASgBsAFoAVwA1AGYAYgAyAFoA
>> "%~1" echo bQBYADMAUgBwAGIAVwBWAHYAZABYAFEAbgBMAEgATgBoAFoAbQBVADYASgB6AE0A
>> "%~1" echo dwBNAEQAQQB3AE0AQwBjAHMAWQBXAE4AMABhAFcAOQB1AE8AaQBkAHkAWgBYAE4A
>> "%~1" echo bABkAEYAOQB6AFkAMwBKAGwAWgBXADUAZgBiADIAWgBtAEoAeQB4AHUAYgAzAFIA
>> "%~1" echo bABPAGkAZgBsAGoAWgBYAGsAdgBZADMAbQByADYAdgBuAHAANQBMAHYAdgBKAHMA
>> "%~1" echo egBNAEQAQQB3AE0ARABBADkATgBTAEQAbABpAEkAYgBwAGsAcAAvAHYAdgBJAHcA
>> "%~1" echo NABOAGoAUQB3AE0ARABBAHcATQBEADAAeQBOAEMARABsAHMASQAvAG0AbAA3AFkA
>> "%~1" echo bgBmAFMAdwBOAEMAaQBBAGcAZQAyAHQAbABlAFQAbwBuAGMAMgB4AGwAWgBYAEIA
>> "%~1" echo VQBhAFcAMQBsAGIAMwBWADAASgB5AHgAdQBZAFcAMQBsAE8AaQBmAG4AcwA3AHYA
>> "%~1" echo bgB1ADUALwBuAG4AYQBIAG4AbgBLAEQAbwB0AG8AWABtAGwANwBZAG4ATABIAE4A
>> "%~1" echo bABkAEgAUgBwAGIAbQBjADYASgAzAE4AbABZADMAVgB5AFoAUwA1AHoAYgBHAFYA
>> "%~1" echo bABjAEYAOQAwAGEAVwAxAGwAYgAzAFYAMABKAHkAeAB6AFkAVwBaAGwATwBpAGQA
>> "%~1" echo dQBkAFcAeABzAEoAeQB4AGgAWQAzAFIAcABiADIANAA2AEoAMwBKAGwAYwAyAFYA
>> "%~1" echo MABYADMATgBzAFoAVwBWAHcAWAAzAFIAcABiAFcAVgB2AGQAWABRAG4ATABHADUA
>> "%~1" echo dgBkAEcAVQA2AEoAMgA1ADEAYgBHAHcAOQA1ADcATwA3ADUANwB1AGYANgBiAHUA
>> "%~1" echo WQA2AEsANgBrADcANwB5AGIATABUAEUAOQA1AEwAaQBOADYASQBlAHEANQBZAHEA
>> "%~1" echo bwA1ADUAMgBoADUANQB5AGcASgAzADAATgBDAGwAMAA3AEQAUQBwAHMAWgBYAFEA
>> "%~1" echo ZwBiAEcARgB6AGQARAAxADcAZgBTAHgAaQBkAFgATgA1AFAAVwBaAGgAYgBIAE4A
>> "%~1" echo bABMAEgAQgBsAGIAbQBSAHAAYgBtAGQARABiADIANQBtAGEAWABKAHQAUABXADUA
>> "%~1" echo MQBiAEcAdwA3AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAGwAYwAyAE0A
>> "%~1" echo bwBjAHkAbAA3AGMAbQBWADAAZABYAEoAdQBJAEYATgAwAGMAbQBsAHUAWgB5AGgA
>> "%~1" echo egBQAHoAOABuAEoAeQBrAHUAYwBtAFYAdwBiAEcARgBqAFoAUwBnAHYAVwB5AFkA
>> "%~1" echo OABQAGkASQBuAFgAUwA5AG4ATABHAE0AOQBQAGkAaAA3AEoAeQBZAG4ATwBpAGMA
>> "%~1" echo bQBZAFcAMQB3AE8AeQBjAHMASgB6AHcAbgBPAGkAYwBtAGIASABRADcASgB5AHcA
>> "%~1" echo bgBQAGkAYwA2AEoAeQBaAG4AZABEAHMAbgBMAEMAYwBpAEoAegBvAG4ASgBuAEYA
>> "%~1" echo MQBiADMAUQA3AEoAeQB3AGkASgB5AEkANgBKAHkAWQBqAE0AegBrADcASgAzADEA
>> "%~1" echo YgBZADEAMABwAEsAWAAwAE4AQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBHAFYA
>> "%~1" echo dABjAEgAUgA1AEsASABZAHAAZQAzAEoAbABkAEgAVgB5AGIAaQBCADIAUABUADAA
>> "%~1" echo OQBkAFcANQBrAFoAVwBaAHAAYgBtAFYAawBmAEgAeAAyAFAAVAAwADkAYgBuAFYA
>> "%~1" echo cwBiAEgAeAA4AGQAagAwADkAUABTAGMAbgBmAEgAeAAyAFAAVAAwADkASgAyADUA
>> "%~1" echo MQBiAEcAdwBuAGYAUQAwAEsAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAYwAyAGgA
>> "%~1" echo dgBkADIANABvAGQAaQBsADcAYwBtAFYAMABkAFgASgB1AEkARwBWAHQAYwBIAFIA
>> "%~1" echo NQBLAEgAWQBwAFAAeQBjAHQASgB6AHAAVABkAEgASgBwAGIAbQBjAG8AZABpAGwA
>> "%~1" echo OQBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgB6AFoAWABRAG8AYQBXAFEA
>> "%~1" echo cwBkAGkAbAA3AFkAMgA5AHUAYwAzAFEAZwBaAFQAMABrAEsARwBsAGsASwBUAHQA
>> "%~1" echo cABaAGkAaABsAEsAVwBVAHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEA
>> "%~1" echo OQBjADIAaAB2AGQAMgA0AG8AZABpAGwAOQBEAFEAcABtAGQAVwA1AGoAZABHAGwA
>> "%~1" echo dgBiAGkAQgAyAEsARwBzAHAAZQAzAEoAbABkAEgAVgB5AGIAaQBCAHoAYQBHADkA
>> "%~1" echo MwBiAGkAaABzAFkAWABOADAAVwAyAHQAZABLAFQAdAA5AEQAUQBwAG0AZABXADUA
>> "%~1" echo agBkAEcAbAB2AGIAaQBCAHUAYgAzAFIAcABaAG4AawBvAGQARwBsADAAYgBHAFUA
>> "%~1" echo cwBiAFgATgBuAEwASABSADUAYwBHAFUAOQBKADIAOQByAEoAeQB4AHQAYwB6ADAA
>> "%~1" echo egBNAGoAQQB3AEsAWAB0AGoAYgAyADUAegBkAEMAQgBvAGIAMwBOADAAUABTAFEA
>> "%~1" echo bwBKADMAUgB2AFkAWABOADAAYwB5AGMAcABPADIAbABtAEsAQwBGAG8AYgAzAE4A
>> "%~1" echo MABLAFgASgBsAGQASABWAHkAYgBqAHQAagBiADIANQB6AGQAQwBCAGwAYgBEADEA
>> "%~1" echo awBiADIATgAxAGIAVwBWAHUAZABDADUAagBjAG0AVgBoAGQARwBWAEYAYgBHAFYA
>> "%~1" echo dABaAFcANQAwAEsAQwBkAGsAYQBYAFkAbgBLAFQAdABsAGIAQwA1AGoAYgBHAEYA
>> "%~1" echo egBjADAANQBoAGIAVwBVADkASgAzAFIAdgBZAFgATgAwAEkAQwBjAHIAZABIAGwA
>> "%~1" echo dwBaAFQAdABsAGIAQwA1AHAAYgBtADUAbABjAGsAaABVAFQAVQB3ADkASgB6AHgA
>> "%~1" echo aQBQAGkAYwByAFoAWABOAGoASwBIAFIAcABkAEcAeABsAEsAUwBzAG4AUABDADkA
>> "%~1" echo aQBQAGoAeAB6AGMARwBGAHUAUABpAGMAcgBaAFgATgBqAEsARwAxAHoAWgAzAHgA
>> "%~1" echo OABKAHkAYwBwAEsAeQBjADgATAAzAE4AdwBZAFcANAArAEoAegB0AG8AYgAzAE4A
>> "%~1" echo MABMAG0ARgB3AGMARwBWAHUAWgBFAE4AbwBhAFcAeABrAEsARwBWAHMASwBUAHQA
>> "%~1" echo eQBaAFgARgAxAFoAWABOADAAUQBXADUAcABiAFcARgAwAGEAVwA5AHUAUgBuAEoA
>> "%~1" echo aABiAFcAVQBvAEsAQwBrADkAUABtAFYAcwBMAG0ATgBzAFkAWABOAHoAVABHAGwA
>> "%~1" echo egBkAEMANQBoAFoARwBRAG8ASgAzAE4AbwBiADMAYwBuAEsAUwBrADcAYwAyAFYA
>> "%~1" echo MABWAEcAbAB0AFoAVwA5ADEAZABDAGcAbwBLAFQAMAArAGUAMgBWAHMATABtAE4A
>> "%~1" echo cwBZAFgATgB6AFQARwBsAHoAZABDADUAeQBaAFcAMQB2AGQAbQBVAG8ASgAzAE4A
>> "%~1" echo bwBiADMAYwBuAEsAVAB0AHoAWgBYAFIAVQBhAFcAMQBsAGIAMwBWADAASwBDAGcA
>> "%~1" echo cABQAFQANQBsAGIAQwA1AHkAWgBXADEAdgBkAG0AVQBvAEsAUwB3AHkATQBqAEEA
>> "%~1" echo cABmAFMAeAB0AGMAeQBsADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIA
>> "%~1" echo egBhAEcAOQAzAFEAMgA5AHUAWgBtAGwAeQBiAFMAaABoAFkAMwBSAHAAYgAyADQA
>> "%~1" echo cwBiAEcARgBpAFoAVwB3AHMAWgBYAGgAMABjAG0ARQA5AEoAeQBjAHAAZQAzAEIA
>> "%~1" echo bABiAG0AUgBwAGIAbQBkAEQAYgAyADUAbQBhAFgASgB0AFAAWAB0AGgAWQAzAFIA
>> "%~1" echo cABiADIANABzAGIARwBGAGkAWgBXAHcAcwBaAFgAaAAwAGMAbQBGADkATwB5AFEA
>> "%~1" echo bwBKADIATgB2AGIAbQBaAHAAYwBtADEAVQBhAFgAUgBzAFoAUwBjAHAATABuAFIA
>> "%~1" echo bABlAEgAUgBEAGIAMgA1ADAAWgBXADUAMABQAFMAZgBuAG8AYQA3AG8AcgBxAFQA
>> "%~1" echo bQBpAGEAZgBvAG8AWQB6AHYAdgBKAG8AbgBLADIAeABoAFkAbQBWAHMATwB5AFEA
>> "%~1" echo bwBKADIATgB2AGIAbQBaAHAAYwBtADEATgBjADIAYwBuAEsAUwA1ADAAWgBYAGgA
>> "%~1" echo MABRADIAOQB1AGQARwBWAHUAZABEADEAagBiADIANQBtAGEAWABKAHQAVgBHAFYA
>> "%~1" echo NABkAEYAdABoAFkAMwBSAHAAYgAyADUAZABmAEgAdwBuADYATAArAFoANQBMAGkA
>> "%~1" echo cQA1AHAATwBOADUATAAyAGMANQBMAHkAYQA1AEwAKwB1ADUAcABTADUASQBGAEYA
>> "%~1" echo MQBaAFgATgAwAEkATwBlAEsAdAB1AGEAQQBnAGUATwBBAGcAaQBjADcASgBDAGcA
>> "%~1" echo bgBZADIAOQB1AFoAbQBsAHkAYgBVADEAaABjADIAcwBuAEsAUwA1AGoAYgBHAEYA
>> "%~1" echo egBjADAAeABwAGMAMwBRAHUAWQBXAFIAawBLAEMAZAB6AGEARwA5ADMASgB5AGwA
>> "%~1" echo OQBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgBqAGIARwA5AHoAWgBVAE4A
>> "%~1" echo dgBiAG0AWgBwAGMAbQAwAG8ASwBYAHQAdwBaAFcANQBrAGEAVwA1AG4AUQAyADkA
>> "%~1" echo dQBaAG0AbAB5AGIAVAAxAHUAZABXAHgAcwBPAHkAUQBvAEoAMgBOAHYAYgBtAFoA
>> "%~1" echo cABjAG0AMQBOAFkAWABOAHIASgB5AGsAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4A
>> "%~1" echo MABMAG4ASgBsAGIAVwA5ADIAWgBTAGcAbgBjADIAaAB2AGQAeQBjAHAAZgBRADAA
>> "%~1" echo SwBaAG4AVgB1AFkAMwBSAHAAYgAyADQAZwBkAEcAaABsAGIAVwBVAG8ASwBYAHQA
>> "%~1" echo agBiADIANQB6AGQAQwBCAHMAYQBXAGQAbwBkAEQAMQBzAGIAMgBOAGgAYgBGAE4A
>> "%~1" echo MABiADMASgBoAFoAMgBVAHUAWgAyAFYAMABTAFgAUgBsAGIAUwBoADAAYQBHAFYA
>> "%~1" echo dABaAFUAdABsAGUAUwBrADkAUABUADAAbgBiAEcAbABuAGEASABRAG4ATwAyAFIA
>> "%~1" echo dgBZADMAVgB0AFoAVwA1ADAATABtAEoAdgBaAEgAawB1AFkAMgB4AGgAYwAzAE4A
>> "%~1" echo TQBhAFgATgAwAEwAbgBSAHYAWgAyAGQAcwBaAFMAZwBuAFoARwBGAHkAYQB5AGMA
>> "%~1" echo cwBJAFcAeABwAFoAMgBoADAASwBUAHMAawBLAEMAZAAwAGEARwBWAHQAWgBVAEoA
>> "%~1" echo MABiAGkAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoAVwA1ADAAUABXAHgA
>> "%~1" echo cABaADIAaAAwAFAAeQBmAG0AdAA3AEgAbwBpAGIASQBuAE8AaQBmAG0AdABZAFgA
>> "%~1" echo bwBpAGIASQBuAGYAUQAwAEsAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAYgBHADkA
>> "%~1" echo bgBLAEgAUQBwAGUAMwBOAGwAZABDAGcAbgBiAEcAOQBuAFEAbQA5ADQASgB5AHgA
>> "%~1" echo dQBaAFgAYwBnAFIARwBGADAAWgBTAGcAcABMAG4AUgB2AFQARwA5AGoAWQBXAHgA
>> "%~1" echo bABWAEcAbAB0AFoAVgBOADAAYwBtAGwAdQBaAHkAZwBwAEsAeQBjAGcASQBDAGMA
>> "%~1" echo cgBkAEMAbAA5AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHoAYQBHADkA
>> "%~1" echo eQBkAEYAQgBoAGQARwBnAG8AYwBDAGwANwBhAFcAWQBvAEkAWABBAHAAYwBtAFYA
>> "%~1" echo MABkAFgASgB1AEoAMgBGAGsAWQBpADUAbABlAEcAVQBuAE8AMgBOAHYAYgBuAE4A
>> "%~1" echo MABJAEcARQA5AGMAQwA1AHoAYwBHAHgAcABkAEMAZwB2AFcAMQB4AGMATAAxADAA
>> "%~1" echo dgBLAFQAdAB5AFoAWABSADEAYwBtADQAZwBZAFYAdABoAEwAbQB4AGwAYgBtAGQA
>> "%~1" echo MABhAEMAMAB4AFgAWAB4ADgAYwBIADAATgBDAG0AWgAxAGIAbQBOADAAYQBXADkA
>> "%~1" echo dQBJAEgAQgBqAGQAQwBoADQATABHADEAaABlAEQAMAB4AE0ARABBAHAAZQAyAE4A
>> "%~1" echo dgBiAG4ATgAwAEkARwA0ADkAYwBHAEYAeQBjADIAVgBHAGIARwA5AGgAZABDAGgA
>> "%~1" echo NABLAFQAdAB5AFoAWABSADEAYwBtADQAZwBhAFgATgBHAGEAVwA1AHAAZABHAFUA
>> "%~1" echo bwBiAGkAawAvAFQAVwBGADAAYQBDADUAdABZAFgAZwBvAE0AQwB4AE4AWQBYAFIA
>> "%~1" echo bwBMAG0AMQBwAGIAaQBnAHgATQBEAEEAcwBiAGkAOQB0AFkAWABnAHEATQBUAEEA
>> "%~1" echo dwBLAFMAawA2AE0ASAAwAE4AQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAEoA
>> "%~1" echo cABiAG0AYwBvAGEAVwBRAHMAZABHAFYANABkAEMAeABzAFkAVwBKAGwAYgBDAHgA
>> "%~1" echo dwBMAEcAMQB2AFoARwBVAHAAZQAyAE4AdgBiAG4ATgAwAEkARwBKAHYAZQBEADAA
>> "%~1" echo awBLAEcAbABrAEsAUwB4AHQAUABXAEoAdgBlAEMAWQBtAFkAbQA5ADQATABuAEYA
>> "%~1" echo MQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMASQBvAEoAeQA1AHQAWgBYAFIA
>> "%~1" echo bABjAGkAYwBwAE8AMgBsAG0ASwBDAEYAaQBiADMAaAA4AGYAQwBGAHQASwBYAEoA
>> "%~1" echo bABkAEgAVgB5AGIAagB0AHQATABuAE4AbABkAEUARgAwAGQASABKAHAAWQBuAFYA
>> "%~1" echo MABaAFMAZwBuAGMAMwBSAHkAYgAyAHQAbABMAFcAUgBoAGMAMgBoAGgAYwBuAEoA
>> "%~1" echo aABlAFMAYwBzAFQAVwBGADAAYQBDADUAeQBiADMAVgB1AFoAQwBoAHcASwBTAHMA
>> "%~1" echo bgBJAEQARQB3AE0AQwBjAHAATwAyAEoAdgBlAEMANQBqAGIARwBGAHoAYwAwAHgA
>> "%~1" echo cABjADMAUQB1AGMAbQBWAHQAYgAzAFoAbABLAEMAZABuAGMAbQBWAGwAYgBpAGMA
>> "%~1" echo cwBKADIARgB0AFkAbQBWAHkASgB5AHcAbgBjAG0AVgBrAEoAeQBrADcAYQBXAFkA
>> "%~1" echo bwBiAFcAOQBrAFoAUwBsAGkAYgAzAGcAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4A
>> "%~1" echo MABMAG0ARgBrAFoAQwBoAHQAYgAyAFIAbABLAFQAdABwAFoAaQBoAHAAWgBEADAA
>> "%~1" echo OQBQAFMAZABpAFkAWABSADAAWgBYAEoANQBSADIARgAxAFoAMgBVAG4ASwBYAHQA
>> "%~1" echo egBaAFgAUQBvAEoAMgBKAGgAZABIAFIAbABjAG4AbABVAFoAWABoADAASgB5AHgA
>> "%~1" echo MABaAFgAaAAwAEsAVAB0AHoAWgBYAFEAbwBKADIASgBoAGQASABSAGwAYwBuAGwA
>> "%~1" echo VABkAFcASQBuAEwARwB4AGgAWQBtAFYAcwBLAFgAMQBwAFoAaQBoAHAAWgBEADAA
>> "%~1" echo OQBQAFMAZAAwAFoAVwAxAHcAUgAyAEYAMQBaADIAVQBuAEsAWAB0AHoAWgBYAFEA
>> "%~1" echo bwBKADMAUgBsAGIAWABCAFUAWgBYAGgAMABKAHkAeAAwAFoAWABoADAASwBUAHQA
>> "%~1" echo egBaAFgAUQBvAEoAMwBSAGwAYgBYAEIAVABkAFcASQBuAEwARwB4AGgAWQBtAFYA
>> "%~1" echo cwBLAFgAMQBwAFoAaQBoAHAAWgBEADAAOQBQAFMAZAB6AGIARwBWAGwAYwBFAGQA
>> "%~1" echo aABkAFcAZABsAEoAeQBsADcAYwAyAFYAMABLAEMAZAB6AGIARwBWAGwAYwBGAFIA
>> "%~1" echo bABlAEgAUQBuAEwASABSAGwAZQBIAFEAcABPADMATgBsAGQAQwBnAG4AYwAyAHgA
>> "%~1" echo bABaAFgAQgBUAGQAVwBJAG4ATABHAHgAaABZAG0AVgBzAEsAWAAxADkARABRAHAA
>> "%~1" echo bQBkAFcANQBqAGQARwBsAHYAYgBpAEIAdQBiADMASgB0AEsASABZAHAAZQAzAEoA
>> "%~1" echo bABkAEgAVgB5AGIAaQBCAHoAYQBHADkAMwBiAGkAaAAyAEsAUwA1ADAAYwBtAGwA
>> "%~1" echo dABLAEMAbAA5AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHAAYwAxAE4A
>> "%~1" echo aABaAG0AVgBXAFkAVwB4ADEAWgBTAGgAawBaAFcAWQBzAGQAbQBGAHMAZABXAFUA
>> "%~1" echo cABlADIATgB2AGIAbgBOADAASQBIAFoAaABiAEQAMQB1AGIAMwBKAHQASwBIAFoA
>> "%~1" echo aABiAEgAVgBsAEsAVAB0AHAAWgBpAGgAawBaAFcAWQB1AGMAMgBGAG0AWgBUADAA
>> "%~1" echo OQBQAFMAZAB1AGQAVwB4AHMASgB5AGwAeQBaAFgAUgAxAGMAbQA0AGcAZABtAEYA
>> "%~1" echo cwBQAFQAMAA5AEoAMgA1ADEAYgBHAHcAbgBmAEgAeAAyAFkAVwB3ADkAUABUADAA
>> "%~1" echo bgBMAFMAYwA3AGMAbQBWADAAZABYAEoAdQBJAEgAWgBoAGIARAAwADkAUABXAFIA
>> "%~1" echo bABaAGkANQB6AFkAVwBaAGwAZgBRADAASwBaAG4AVgB1AFkAMwBSAHAAYgAyADQA
>> "%~1" echo ZwBjAG0AVgB1AFoARwBWAHkAVQBHAEYAeQBZAFcAMQB6AEsAQwBsADcAWQAyADkA
>> "%~1" echo dQBjADMAUQBnAGEARwA5AHoAZABEADAAawBLAEMAZAB3AFkAWABKAGgAYgBVAHgA
>> "%~1" echo cABjADMAUQBuAEsAVAB0AHAAWgBpAGcAaABhAEcAOQB6AGQAQwBsAHkAWgBYAFIA
>> "%~1" echo MQBjAG0ANAA3AGEARwA5AHoAZABDADUAcABiAG0ANQBsAGMAawBoAFUAVABVAHcA
>> "%~1" echo OQBKAHkAYwA3AGIARwBWADAASQBHAE4AbwBZAFcANQBuAFoAVwBRADkATQBEAHQA
>> "%~1" echo agBiADIANQB6AGQAQwBCAHYAWgBtAFoAcwBhAFcANQBsAFAAVwB4AGgAYwAzAFEA
>> "%~1" echo dQBZADIAOQB1AGIAbQBWAGoAZABHAFYAawBJAFQAMAA5AEoAMwBSAHkAZABXAFUA
>> "%~1" echo bgBPADMAQgBoAGMAbQBGAHQAUgBHAFYAbQBjAHkANQBtAGIAMwBKAEYAWQBXAE4A
>> "%~1" echo bwBLAEcAUgBsAFoAagAwACsAZQAyAE4AdgBiAG4ATgAwAEkASABaAGgAYgBEADEA
>> "%~1" echo dQBiADMASgB0AEsARwB4AGgAYwAzAFIAYgBaAEcAVgBtAEwAbQB0AGwAZQBWADAA
>> "%~1" echo cABPADIATgB2AGIAbgBOADAASQBHADkAcgBQAFMARgB2AFoAbQBaAHMAYQBXADUA
>> "%~1" echo bABKAGkAWgBwAGMAMQBOAGgAWgBtAFYAVwBZAFcAeAAxAFoAUwBoAGsAWgBXAFkA
>> "%~1" echo cwBkAG0ARgBzAEsAVAB0AHAAWgBpAGcAaABiADIAcwBtAEoAaQBGAHYAWgBtAFoA
>> "%~1" echo cwBhAFcANQBsAEsAVwBOAG8AWQBXADUAbgBaAFcAUQByAEsAegB0AGoAYgAyADUA
>> "%~1" echo egBkAEMAQgBwAGQARwBWAHQAUABXAFIAdgBZADMAVgB0AFoAVwA1ADAATABtAE4A
>> "%~1" echo eQBaAFcARgAwAFoAVQBWAHMAWgBXADEAbABiAG4AUQBvAEoAMgBSAHAAZABpAGMA
>> "%~1" echo cABPADIAbAAwAFoAVwAwAHUAWQAyAHgAaABjADMATgBPAFkAVwAxAGwAUABTAGQA
>> "%~1" echo dwBZAFgASgBoAGIAVQBsADAAWgBXADAAZwBKAHkAcwBvAGIAMgBaAG0AYgBHAGwA
>> "%~1" echo dQBaAFQAOABuAEoAegBwAHYAYQB6ADgAbgBiADIAcwBuAE8AaQBkAGoAYQBHAEYA
>> "%~1" echo dQBaADIAVgBrAEoAeQBrADcAWQAyADkAdQBjADMAUQBnAGMAMwBSAGgAZABHAFUA
>> "%~1" echo OQBiADIAWgBtAGIARwBsAHUAWgBUADgAbgA1AHAAeQBxADYASwArADcANQBZACsA
>> "%~1" echo VwBKAHoAbwBvAGIAMgBzAC8ASgArAG0ANwBtAE8AaQB1AHAATwBXAEEAdgBDAGMA
>> "%~1" echo NgBKACsAVwAzAHMAdQBTAC8AcgB1AGEAVQB1AFMAYwBwAE8AMgBsADAAWgBXADAA
>> "%~1" echo dQBhAFcANQB1AFoAWABKAEkAVgBFADEATQBQAFMAYwA4AFoARwBsADIASQBHAE4A
>> "%~1" echo cwBZAFgATgB6AFAAVgB3AGkAYwBHAEYAeQBZAFcAMQBPAFkAVwAxAGwAWABDAEkA
>> "%~1" echo KwBQAEcASQArAEoAeQB0AGwAYwAyAE0AbwBaAEcAVgBtAEwAbQA1AGgAYgBXAFUA
>> "%~1" echo cABLAHkAYwA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArAEoAeQB0AGwAYwAyAE0A
>> "%~1" echo bwBaAEcAVgBtAEwAbgBOAGwAZABIAFIAcABiAG0AYwBwAEsAeQBjADgATAAzAE4A
>> "%~1" echo dwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYA
>> "%~1" echo egBjAHoAMQBjAEkAbgBCAGgAYwBtAEYAdABWAG0ARgBzAGQAVwBWAGMASQBqADQA
>> "%~1" echo OABjADMAQgBoAGIAagA3AGwAdgBaAFAAbABpAFkAMwBsAGcATAB3ADgATAAzAE4A
>> "%~1" echo dwBZAFcANAArAFAARwBJACsASgB5AHQAbABjADIATQBvAGQAbQBGAHMASwBTAHMA
>> "%~1" echo bgBQAEMAOQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgA
>> "%~1" echo aABjADMATQA5AFgAQwBKAHcAWQBYAEoAaABiAFYAWgBoAGIASABWAGwAWABDAEkA
>> "%~1" echo KwBQAEgATgB3AFkAVwA0ACsANgBiAHUAWQA2AEsANgBrADUAWQBDADgAUABDADkA
>> "%~1" echo egBjAEcARgB1AFAAagB4AGkAUABpAGMAcgBaAFgATgBqAEsARwBSAGwAWgBpADUA
>> "%~1" echo egBZAFcAWgBsAEsAUwBzAG4AUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHgA
>> "%~1" echo awBhAFgAWQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkAWABDAEoA
>> "%~1" echo dwBZAFgASgBoAGIAVgBOADAAWQBYAFIAbABYAEMASQArAEoAeQB0AGwAYwAyAE0A
>> "%~1" echo bwBjADMAUgBoAGQARwBVAHAASwB5AGMAOABMADMATgB3AFkAVwA0ACsASQBDAGMA
>> "%~1" echo cgBLAEMARgB2AFoAbQBaAHMAYQBXADUAbABKAGkAWQBoAGIAMgBzAC8ASgB6AHgA
>> "%~1" echo aQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AFgAQwBKAHkAWgBYAE4A
>> "%~1" echo bABkAEUASgAwAGIAaQBCAHcAYwBtAGwAdABZAFgASgA1AFgAQwBJAGcAWgBHAEYA
>> "%~1" echo MABZAFMAMQB5AFoAWABOAGwAZABEADEAYwBJAGkAYwByAFoAWABOAGoASwBHAFIA
>> "%~1" echo bABaAGkANQBoAFkAMwBSAHAAYgAyADQAcABLAHkAZABjAEkAagA3AHAAaAA0ADMA
>> "%~1" echo bgB2AGEANAA4AEwAMgBKADEAZABIAFIAdgBiAGoANABuAE8AaQBjAG4ASwBTAHMA
>> "%~1" echo bgBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADEA
>> "%~1" echo YwBJAG4AQgBoAGMAbQBGAHQAVABtAEYAdABaAFYAdwBpAEkASABOADAAZQBXAHgA
>> "%~1" echo bABQAFYAdwBpAFoAMwBKAHAAWgBDADEAagBiADIAeAAxAGIAVwA0ADYATQBTADgA
>> "%~1" echo dABNAFYAdwBpAFAAagB4AHoAYwBHAEYAdQBQAGkAYwByAFoAWABOAGoASwBHAFIA
>> "%~1" echo bABaAGkANQB1AGIAMwBSAGwASwBTAHMAbgBQAEMAOQB6AGMARwBGAHUAUABqAHcA
>> "%~1" echo dgBaAEcAbAAyAFAAaQBjADcAYQBHADkAegBkAEMANQBoAGMASABCAGwAYgBtAFIA
>> "%~1" echo RABhAEcAbABzAFoAQwBoAHAAZABHAFYAdABLAFgAMABwAE8AMwBOAGwAZABDAGcA
>> "%~1" echo bgBjAEcARgB5AFkAVwAxAFQAZABXADEAdABZAFgASgA1AEoAeQB4AHYAWgBtAFoA
>> "%~1" echo cwBhAFcANQBsAFAAeQBmAG0AbgBLAHIAbwB2ADUANwBtAGoAcQBVAG4ATwBtAE4A
>> "%~1" echo bwBZAFcANQBuAFoAVwBRAC8AWQAyAGgAaABiAG0AZABsAFoAQwBzAG4ASQBPAG0A
>> "%~1" echo aAB1AGUAVwAzAHMAdQBTAC8AcgB1AGEAVQB1AFMAYwA2AEoAKwBXAEYAcQBPAG0A
>> "%~1" echo RABxAE8AbQA3AG0ATwBpAHUAcABDAGMAcABPADIAaAB2AGMAMwBRAHUAYwBYAFYA
>> "%~1" echo bABjAG4AbABUAFoAVwB4AGwAWQAzAFIAdgBjAGsARgBzAGIAQwBnAG4AVwAyAFIA
>> "%~1" echo aABkAEcARQB0AGMAbQBWAHoAWgBYAFIAZABKAHkAawB1AFoAbQA5AHkAUgBXAEYA
>> "%~1" echo agBhAEMAaABpAGQARwA0ADkAUABtAEoAMABiAGkANQB2AGIAbQBOAHMAYQBXAE4A
>> "%~1" echo cgBQAFMAZwBwAFAAVAA1AGgAWQAzAFIAcABiADIANABvAFkAbgBSAHUATABtAFIA
>> "%~1" echo aABkAEcARgB6AFoAWABRAHUAYwBtAFYAegBaAFgAUQBzAEoAeQBjAHMASgArAG0A
>> "%~1" echo SABqAGUAZQA5AHIAdQBXAFAAZwB1AGEAVgBzAEMAYwBzAFkAbgBSAHUATABHAFoA
>> "%~1" echo aABiAEgATgBsAEsAUwBsADkARABRAHAAaABjADMAbAB1AFkAeQBCAG0AZABXADUA
>> "%~1" echo agBkAEcAbAB2AGIAaQBCAGgAYwBHAGsAbwBjAEcARgAwAGEAQwB4AHYAYwBIAFIA
>> "%~1" echo egBQAFgAdAA5AEsAWAB0AGoAYgAyADUAegBkAEMAQgB6AFoAWABBADkAYwBHAEYA
>> "%~1" echo MABhAEMANQBwAGIAbQBOAHMAZABXAFIAbABjAHkAZwBuAFAAeQBjAHAAUAB5AGMA
>> "%~1" echo bQBKAHoAbwBuAFAAeQBjADcAWQAyADkAdQBjADMAUQBnAGMAagAxAGgAZAAyAEYA
>> "%~1" echo cABkAEMAQgBtAFoAWABSAGoAYQBDAGgAdwBZAFgAUgBvAEsAMwBOAGwAYwBDAHMA
>> "%~1" echo bgBkAEcAOQByAFoAVwA0ADkASgB5AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwA
>> "%~1" echo RABiADIAMQB3AGIAMgA1AGwAYgBuAFEAbwBWAEUAOQBMAFIAVQA0AHAATABFADkA
>> "%~1" echo aQBhAG0AVgBqAGQAQwA1AGgAYwAzAE4AcABaADIANABvAGUAMgBOAGgAWQAyAGgA
>> "%~1" echo bABPAGkAZAB1AGIAeQAxAHoAZABHADkAeQBaAFMAZAA5AEwARwA5AHcAZABIAE0A
>> "%~1" echo cABLAFQAdABwAFoAaQBnAGgAYwBpADUAdgBhAHkAbAAwAGEASABKAHYAZAB5AEIA
>> "%~1" echo dQBaAFgAYwBnAFIAWABKAHkAYgAzAEkAbwBKADAAaABVAFYARgBBAGcASgB5AHQA
>> "%~1" echo eQBMAG4ATgAwAFkAWABSADEAYwB5AGsANwBjAG0AVgAwAGQAWABKAHUASQBHAEYA
>> "%~1" echo MwBZAFcAbAAwAEkASABJAHUAYQBuAE4AdgBiAGkAZwBwAGYAUQAwAEsAWQBYAE4A
>> "%~1" echo NQBiAG0ATQBnAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGIARwA5AGgAWgBFAHgA
>> "%~1" echo dgBaADMATQBvAGMAMgBoAHYAZAAwADUAdgBkAEcAbABqAFoAVAAxAG0AWQBXAHgA
>> "%~1" echo egBaAFMAbAA3AGQASABKADUAZQAyAE4AdgBiAG4ATgAwAEkASABJADkAWQBYAGQA
>> "%~1" echo aABhAFgAUQBnAFkAWABCAHAASwBDAGMAdgBZAFgAQgBwAEwAMgB4AHYAWgAzAE0A
>> "%~1" echo bgBLAFQAdAB6AFoAWABRAG8ASgAyAHgAdgBaADEAQgBoAGQARwBnAG4ATABIAEkA
>> "%~1" echo dQBiAEcAOQBuAFIAbQBsAHMAWgBTAGsANwBjADIAVgAwAEsAQwBkAHMAYgAyAGQA
>> "%~1" echo QwBiADMAZwBuAEwASABJAHUAZABHAFYANABkAEgAeAA4AEoAKwBhAGEAZwB1AGEA
>> "%~1" echo WABvAE8AYQBYAHAAZQBXAC8AbAB5AGMAcABPADIAbABtAEsASABOAG8AYgAzAGQA
>> "%~1" echo TwBiADMAUgBwAFkAMgBVAHAAYgBtADkAMABhAFcAWgA1AEsAQwBmAG0AbAA2AFgA
>> "%~1" echo bAB2ADUAZgBsAHQANwBMAGwAaQBMAGYAbQBsAHIAQQBuAEwASABJAHUAYgBHADkA
>> "%~1" echo bgBSAG0AbABzAFoAWAB4ADgASgB5ADAAbgBMAEMAZAB2AGEAeQBjAHAAZgBXAE4A
>> "%~1" echo aABkAEcATgBvAEsARwBVAHAAZQAzAE4AbABkAEMAZwBuAGIARwA5AG4AUQBtADkA
>> "%~1" echo NABKAHkAdwBuADUAcABlAGwANQBiACsAWAA2AEsAKwA3ADUAWQArAFcANQBhAFMA
>> "%~1" echo eAA2AEwAUwBsADcANwB5AGEASgB5AHQAbABMAG0AMQBsAGMAMwBOAGgAWgAyAFUA
>> "%~1" echo cABPADIAbABtAEsASABOAG8AYgAzAGQATwBiADMAUgBwAFkAMgBVAHAAYgBtADkA
>> "%~1" echo MABhAFcAWgA1AEsAQwBmAG0AbAA2AFgAbAB2ADUAZgBvAHIANwB2AGwAagA1AGIA
>> "%~1" echo bABwAEwASABvAHQASwBVAG4ATABHAFUAdQBiAFcAVgB6AGMAMgBGAG4AWgBTAHcA
>> "%~1" echo bgBaAFgASgB5AEoAeQB3ADAATQBqAEEAdwBLAFgAMQA5AEQAUQBwAGgAYwAzAGwA
>> "%~1" echo dQBZAHkAQgBtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgB5AFoAVwBaAHkAWgBYAE4A
>> "%~1" echo bwBLAEgATgBvAGIAMwBkAE8AYgAzAFIAcABZADIAVQA5AFoAbQBGAHMAYwAyAFUA
>> "%~1" echo cABlADMAUgB5AGUAWAB0AHMAWQBYAE4AMABQAFcARgAzAFkAVwBsADAASQBHAEYA
>> "%~1" echo dwBhAFMAZwBuAEwAMgBGAHcAYQBTADkAegBkAEcARgAwAGQAWABNAG4ASwBUAHQA
>> "%~1" echo agBiADIANQB6AGQAQwBCAGoAUABXAHgAaABjADMAUQB1AFkAMgA5AHUAYgBtAFYA
>> "%~1" echo agBkAEcAVgBrAFAAVAAwADkASgAzAFIAeQBkAFcAVQBuAE8AeQBRAG8ASgAzAE4A
>> "%~1" echo MABZAFgAUgAxAGMAMABOAG8AYQBYAEEAbgBLAFMANQBqAGIARwBGAHoAYwAwAHgA
>> "%~1" echo cABjADMAUQB1AGQARwA5AG4AWgAyAHgAbABLAEMAZABqAGIAMgA1AHUAWgBXAE4A
>> "%~1" echo MABaAFcAUQBuAEwARwBNAHAATwB5AFEAbwBKADMATgAwAFkAWABSADEAYwAwAE4A
>> "%~1" echo bwBhAFgAQQBuAEsAUwA1AHgAZABXAFYAeQBlAFYATgBsAGIARwBWAGoAZABHADkA
>> "%~1" echo eQBLAEMAZAB6AGMARwBGAHUASgB5AGsAdQBkAEcAVgA0AGQARQBOAHYAYgBuAFIA
>> "%~1" echo bABiAG4AUQA5AFkAegA4AG4ANQBiAGUAeQA2AEwAKwBlADUAbwA2AGwASgB6AG8A
>> "%~1" echo bwBiAEcARgB6AGQAQwA1AGsAWgBYAFoAcABZADIAVgBUAGQARwBGADAAWgBUADAA
>> "%~1" echo OQBQAFMAZAAxAGIAbQBGADEAZABHAGgAdgBjAG0AbAA2AFoAVwBRAG4AUAB5AGYA
>> "%~1" echo bQBuAEsAcgBtAGoAbwBqAG0AbgBZAE0AbgBPAG0AeABoAGMAMwBRAHUAWgBHAFYA
>> "%~1" echo MgBhAFcATgBsAFUAMwBSAGgAZABHAFUAOQBQAFQAMABuAGIAMgBaAG0AYgBHAGwA
>> "%~1" echo dQBaAFMAYwAvAEoAKwBlAG0AdQArAGUANgB2AHkAYwA2AEoAKwBhAGMAcQB1AGkA
>> "%~1" echo LwBuAHUAYQBPAHAAUwBjAHAATwAzAE4AbABkAEMAZwBuAGMAMwBSAGgAZABHAFYA
>> "%~1" echo QwBhAFcAYwBuAEwARwB4AGgAYwAzAFEAdQBaAEcAVgAyAGEAVwBOAGwAVQAzAFIA
>> "%~1" echo aABkAEcAVgA4AGYAQwBkAHUAYgAyADUAbABKAHkAawA3AEoAQwBnAG4AYwAzAFIA
>> "%~1" echo aABkAEcAVgBDAGEAVwBjAG4ASwBTADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEA
>> "%~1" echo dQBkAEcAOQBuAFoAMgB4AGwASwBDAGQAbgBiADIAOQBrAEoAeQB4AGoASwBUAHQA
>> "%~1" echo egBaAFgAUQBvAEoAMwBOADAAWQBYAFIAbABTAEcAbAB1AGQAQwBjAHMAYgBHAEYA
>> "%~1" echo egBkAEMANQBvAGEAVwA1ADAASwBUAHQAegBaAFgAUQBvAEoAMgBoAGwAYwBtADkA
>> "%~1" echo TgBiADIAUgBsAGIAQwBjAHMAYgBHAEYAegBkAEMANQB0AGIAMgBSAGwAYgBDAFkA
>> "%~1" echo bQBiAEcARgB6AGQAQwA1AHQAYgAyAFIAbABiAEMARQA5AFAAUwBjAHQASgB6ADkA
>> "%~1" echo cwBZAFgATgAwAEwAbQAxAHYAWgBHAFYAcwBPAGkAZABSAGQAVwBWAHoAZABDAGMA
>> "%~1" echo cABPADMATgBsAGQAQwBnAG4AWgBHAFYAMgBhAFcATgBsAFYARwBGAG4ASgB5AHgA
>> "%~1" echo cwBZAFgATgAwAEwAbQBSAGwAZABtAGwAagBaAFYATgAwAFkAWABSAGwAZgBIAHcA
>> "%~1" echo bgBiAG0AOQB1AFoAUwBjAHAATwAzAE4AbABkAEMAZwBuAFkAVwBSAGkAVQAyAGgA
>> "%~1" echo dgBjAG4AUQBuAEwASABOAG8AYgAzAEoAMABVAEcARgAwAGEAQwBoAHMAWQBYAE4A
>> "%~1" echo MABMAG0ARgBrAFkAbABCAGgAZABHAGcAcABLAFQAdAB6AFoAWABRAG8ASgAyAEYA
>> "%~1" echo awBZAGwAQgBoAGQARwBoAFQAYQBHADkAeQBkAEMAYwBzAGMAMgBoAHYAYwBuAFIA
>> "%~1" echo UQBZAFgAUgBvAEsARwB4AGgAYwAzAFEAdQBZAFcAUgBpAFUARwBGADAAYQBDAGsA
>> "%~1" echo cABPADMATgBsAGQAQwBnAG4AZAAyAGwAbQBhAFUATgBvAGEAWABBAG4ATABIAFkA
>> "%~1" echo bwBKADMAZABwAFoAbQBsAEoAYwBDAGMAcABLAFQAdAB6AFoAWABRAG8ASgAzAGQA
>> "%~1" echo cABaAG0AbABKAGMARQB4AHAAZABHAFUAbgBMAEgAWQBvAEoAMwBkAHAAWgBtAGwA
>> "%~1" echo SgBjAEMAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADIAeABsAFoAbgBSAEQAYgAyADUA
>> "%~1" echo MABjAG0AOQBzAGIARwBWAHkAVABHAGwAMABaAFMAYwBzAGQAaQBnAG4AWQAyADkA
>> "%~1" echo dQBkAEgASgB2AGIARwB4AGwAYwBrAHgAbABaAG4AUgBDAFkAWABSADAAWgBYAEoA
>> "%~1" echo NQBKAHkAawBwAE8AMwBOAGwAZABDAGcAbgBjAG0AbABuAGEASABSAEQAYgAyADUA
>> "%~1" echo MABjAG0AOQBzAGIARwBWAHkAVABHAGwAMABaAFMAYwBzAGQAaQBnAG4AWQAyADkA
>> "%~1" echo dQBkAEgASgB2AGIARwB4AGwAYwBsAEoAcABaADIAaAAwAFEAbQBGADAAZABHAFYA
>> "%~1" echo eQBlAFMAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADIAeABsAFoAbgBSAEQAYgAyADUA
>> "%~1" echo MABjAG0AOQBzAGIARwBWAHkAVQAzAFIAaABkAEcAVQBuAEwASABZAG8ASgAyAE4A
>> "%~1" echo dgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoATQBaAFcAWgAwAFUAMwBSAGgAZABIAFYA
>> "%~1" echo egBKAHkAawBwAE8AMwBOAGwAZABDAGcAbgBjAG0AbABuAGEASABSAEQAYgAyADUA
>> "%~1" echo MABjAG0AOQBzAGIARwBWAHkAVQAzAFIAaABkAEcAVQBuAEwASABZAG8ASgAyAE4A
>> "%~1" echo dgBiAG4AUgB5AGIAMgB4AHMAWgBYAEoAUwBhAFcAZABvAGQARgBOADAAWQBYAFIA
>> "%~1" echo MQBjAHkAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADMATgB2AFkAMAB4AHAAZABHAFUA
>> "%~1" echo bgBMAEgAWQBvAEoAMwBOAHYAWQB5AGMAcABLAFQAdAB6AFoAWABRAG8ASgAyAFIA
>> "%~1" echo cABjADMAQgBzAFkAWABsAFQAZABXADEAdABZAFgASgA1AFQARwBsADAAWgBTAGMA
>> "%~1" echo cwBkAGkAZwBuAFoARwBsAHoAYwBHAHgAaABlAFYATgAxAGIAVwAxAGgAYwBuAGsA
>> "%~1" echo bgBLAFMAawA3AGMAMgBWADAASwBDAGQAMABhAEcAVgB5AGIAVwBGAHMAVQAzAFYA
>> "%~1" echo dABiAFcARgB5AGUAVQB4AHAAZABHAFUAbgBMAEgAWQBvAEoAMwBSAG8AWgBYAEoA
>> "%~1" echo dABZAFcAeABUAGQAVwAxAHQAWQBYAEoANQBKAHkAawBwAE8AMwBOAGwAZABDAGcA
>> "%~1" echo bgBaAG0ARgBqAGQARwA5AHkAZQBWAE4AMQBiAFcAMQBoAGMAbgBsAE0AYQBYAFIA
>> "%~1" echo bABKAHkAeAAyAEsAQwBkAG0AWQBXAE4AMABiADMASgA1AFUAMwBWAHQAYgBXAEYA
>> "%~1" echo eQBlAFMAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADIATgBzAGIAMgBOAHIAVgBHAFYA
>> "%~1" echo NABkAEMAYwBzAGIAbQBWADMASQBFAFIAaABkAEcAVQBvAEsAUwA1ADAAYgAwAHgA
>> "%~1" echo dgBZADIARgBzAFoAVgBSAHAAYgBXAFYAVABkAEgASgBwAGIAbQBjAG8ASwBTAGsA
>> "%~1" echo NwBZADIAOQB1AGMAMwBRAGcAWQBqADEAMgBLAEMAZABpAFkAWABSADAAWgBYAEoA
>> "%~1" echo NQBUAEcAVgAyAFoAVwB3AG4ASwBTAHgAMABQAFgAWQBvAEoAMgBKAGgAZABIAFIA
>> "%~1" echo bABjAG4AbABVAFoAVwAxAHcASgB5AGsAcwBkAHoAMQAyAEsAQwBkADMAWQBXAHQA
>> "%~1" echo bABaAG4AVgBzAGIAbQBWAHoAYwB5AGMAcABMAEcASgB1AFAAWABCAGgAYwBuAE4A
>> "%~1" echo bABSAG0AeAB2AFkAWABRAG8AWQBpAGsAcwBkAEcANAA5AGMARwBGAHkAYwAyAFYA
>> "%~1" echo RwBiAEcAOQBoAGQAQwBoADAASwBUAHQAeQBhAFcANQBuAEsAQwBkAGkAWQBYAFIA
>> "%~1" echo MABaAFgASgA1AFIAMgBGADEAWgAyAFUAbgBMAEcASQA5AFAAVAAwAG4ATABTAGMA
>> "%~1" echo LwBKAHkAMAB0AEoAUwBjADYAWQBpAHMAbgBKAFMAYwBzAEoAKwBlAFUAdABlAG0A
>> "%~1" echo SABqAHkAYwBzAGMARwBOADAASwBHAEkAcABMAEMARgBwAGMAMABaAHAAYgBtAGwA
>> "%~1" echo MABaAFMAaABpAGIAaQBrAC8ASgB5AGMANgBZAG0ANAA4AE0AagBBAC8ASgAzAEoA
>> "%~1" echo bABaAEMAYwA2AFkAbQA0ADgATgBEAFUALwBKADIARgB0AFkAbQBWAHkASgB6AG8A
>> "%~1" echo bgBaADMASgBsAFoAVwA0AG4ASwBUAHQAeQBhAFcANQBuAEsAQwBkADAAWgBXADEA
>> "%~1" echo dwBSADIARgAxAFoAMgBVAG4ATABIAFEAOQBQAFQAMABuAEwAUwBjAC8ASgB5ADAA
>> "%~1" echo dAB3AHIAQgBEAEoAegBwADAASwB5AGYAQwBzAEUATQBuAEwAQwBmAG0AdQBLAG4A
>> "%~1" echo bAB1AHEAWQBuAEwASABCAGoAZABDAGgAMABMAEQAVQAxAEsAUwB3AGgAYQBYAE4A
>> "%~1" echo RwBhAFcANQBwAGQARwBVAG8AZABHADQAcABQAHkAYwBuAE8AbgBSAHUAUABqADAA
>> "%~1" echo MABOAFQAOABuAGMAbQBWAGsASgB6AHAAMABiAGoANAA5AE0AegBnAC8ASgAyAEYA
>> "%~1" echo dABZAG0AVgB5AEoAegBvAG4AWgAzAEoAbABaAFcANABuAEsAVAB0AGoAYgAyADUA
>> "%~1" echo egBkAEMAQgBoAGQAMgBGAHIAWgBUADAAbwBkADMAeAA4AEoAeQBjAHAATABuAFIA
>> "%~1" echo dgBUAEcAOQAzAFoAWABKAEQAWQBYAE4AbABLAEMAawB1AGEAVwA1AGoAYgBIAFYA
>> "%~1" echo awBaAFgATQBvAEoAMgBGADMAWQBXAHQAbABKAHkAawA3AGMAbQBsAHUAWgB5AGcA
>> "%~1" echo bgBjADIAeABsAFoAWABCAEgAWQBYAFYAbgBaAFMAYwBzAGQAegAwADkAUABTAGMA
>> "%~1" echo dABKAHoAOABuAEwAUwBjADYAZAB5AHgAcwBZAFgATgAwAEwAbQAxAFQAZABHAEYA
>> "%~1" echo NQBUADIANAA5AFAAVAAwAG4AZABIAEoAMQBaAFMAYwAvAEoAKwBTAC8AbgBlAGEA
>> "%~1" echo TQBnAGUAVwBVAHAATwBtAEcAawBpAGMANgBKACsAUwA4AGsAZQBlAGMAbwBDAGMA
>> "%~1" echo cwBZAFgAZABoAGEAMgBVAC8ATQBUAEEAdwBPAGoASQA0AEwARwBGADMAWQBXAHQA
>> "%~1" echo bABQAHkAZABoAGIAVwBKAGwAYwBpAGMANgBKADIAZAB5AFoAVwBWAHUASgB5AGsA
>> "%~1" echo NwBUADIASgBxAFoAVwBOADAATABtAHQAbABlAFgATQBvAGIARwBGAHoAZABDAGsA
>> "%~1" echo dQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAcgBQAFQANQB6AFoAWABRAG8AYQB5AHgA
>> "%~1" echo cwBZAFgATgAwAFcAMgB0AGQASwBTAGsANwBjADIAVgAwAEsAQwBkAHcAYgAzAGQA
>> "%~1" echo bABjAGwATgB2AGQAWABKAGoAWgBUAEkAbgBMAEcAeABoAGMAMwBRAHUAYwBHADkA
>> "%~1" echo MwBaAFgASgBUAGIAMwBWAHkAWQAyAFUAcABPADMATgBsAGQAQwBnAG4AYgBHADkA
>> "%~1" echo bgBVAEcARgAwAGEAQwBjAHMAYgBHAEYAegBkAEMANQBzAGIAMgBkAEcAYQBXAHgA
>> "%~1" echo bABLAFQAdAB6AFoAWABRAG8ASgAyAE4AdgBiAG4ATgB2AGIARwBWAFQAZABHAEYA
>> "%~1" echo MABaAFMAYwBzAGIARwBGAHoAZABDADUAawBaAFgAWgBwAFkAMgBWAFQAZABHAEYA
>> "%~1" echo MABaAFMAawA3AGMAMgBWADAASwBDAGQAagBiADIANQB6AGIAMgB4AGwAUQAyADkA
>> "%~1" echo dQBiAGkAYwBzAFkAegA4AG4ANQBiAGUAeQA2AEwAKwBlADUAbwA2AGwASgB6AG8A
>> "%~1" echo bgA1AHAAeQBxADYATAArAGUANQBvADYAbABKAHkAawA3AGMAMgBWADAASwBDAGQA
>> "%~1" echo agBiADIANQB6AGIAMgB4AGwAUQBtAEYAMABkAEcAVgB5AGUAUwBjAHMAWQBqADAA
>> "%~1" echo OQBQAFMAYwB0AEoAegA4AG4ATABTAGMANgBZAGkAcwBuAEoAUwBjAHAATwAzAE4A
>> "%~1" echo bABkAEMAZwBuAFkAMgA5AHUAYwAyADkAcwBaAFYAZABoAGEAMgBVAG4ATABIAGMA
>> "%~1" echo cABPADMATgBsAGQAQwBnAG4AWQAyADkAdQBjADIAOQBzAFoAVgBkAHAAWgBtAGsA
>> "%~1" echo bgBMAEgAWQBvAEoAMwBkAHAAWgBtAGwASgBjAEMAYwBwAEsAVAB0AHkAWgBXADUA
>> "%~1" echo awBaAFgASgBRAFkAWABKAGgAYgBYAE0AbwBLAFQAdABwAFoAaQBoAHoAYQBHADkA
>> "%~1" echo MwBUAG0AOQAwAGEAVwBOAGwASwBXADUAdgBkAEcAbABtAGUAUwBnAG4ANQBZAGkA
>> "%~1" echo MwA1AHAAYQB3ADUAYQA2AE0ANQBvAGkAUQBKAHkAeABqAFAAeQBmAGwAdAA3AEwA
>> "%~1" echo bwB2ADUANwBtAGoAcQBYAHYAdgBKAG8AbgBLAHkAaABzAFkAWABOADAATABtADEA
>> "%~1" echo dgBaAEcAVgBzAGYASAB3AG4AVQBYAFYAbABjADMAUQBuAEsAUwBzAG4ANwA3AHkA
>> "%~1" echo TQA1ADUAUwAxADYAWQBlAFAASQBDAGMAcgBZAGkAcwBuAEoAUwBjADYASwBHAHgA
>> "%~1" echo aABjADMAUQB1AGEARwBsAHUAZABIAHgAOABKACsAYQBjAHEAdQBpAC8AbgB1AGEA
>> "%~1" echo TwBwAFMAYwBwAEwARwBNAC8ASgAyADkAcgBKAHoAbwBuAGQAMgBGAHkAYgBpAGMA
>> "%~1" echo cABmAFcATgBoAGQARwBOAG8ASwBHAFUAcABlADIAeAB2AFoAeQBnAG4ANQBZAGkA
>> "%~1" echo MwA1AHAAYQB3ADUAYQBTAHgANgBMAFMAbAA3ADcAeQBhAEoAeQB0AGwATABtADEA
>> "%~1" echo bABjADMATgBoAFoAMgBVAHAATwAzAEoAbABiAG0AUgBsAGMAbABCAGgAYwBtAEYA
>> "%~1" echo dABjAHkAZwBwAE8AMgBsAG0ASwBIAE4AbwBiADMAZABPAGIAMwBSAHAAWQAyAFUA
>> "%~1" echo cABiAG0AOQAwAGEAVwBaADUASwBDAGYAbABpAEwAZgBtAGwAcgBEAGwAcABMAEgA
>> "%~1" echo bwB0AEsAVQBuAEwARwBVAHUAYgBXAFYAegBjADIARgBuAFoAUwB3AG4AWgBYAEoA
>> "%~1" echo eQBKAHkAdwAwAE0AagBBAHcASwBYADEAOQBEAFEAcABtAGQAVwA1AGoAZABHAGwA
>> "%~1" echo dgBiAGkAQgB6AFoAWABSAEMAZABYAE4ANQBLAEcAOQB1AEwARwBKADAAYgBpAGwA
>> "%~1" echo NwBZAG4AVgB6AGUAVAAxAHYAYgBqAHQAawBiADIATgAxAGIAVwBWAHUAZABDADUA
>> "%~1" echo eABkAFcAVgB5AGUAVgBOAGwAYgBHAFYAagBkAEcAOQB5AFEAVwB4AHMASwBDAGQA
>> "%~1" echo aQBkAFgAUgAwAGIAMgA0AG4ASwBTADUAbQBiADMASgBGAFkAVwBOAG8ASwBHAEkA
>> "%~1" echo OQBQAG0ASQB1AFoARwBsAHoAWQBXAEoAcwBaAFcAUQA5AGIAMgA0AHAATwAyAGwA
>> "%~1" echo bQBLAEcASgAwAGIAaQBsAGkAZABHADQAdQBZADIAeABoAGMAMwBOAE0AYQBYAE4A
>> "%~1" echo MABMAG4AUgB2AFoAMgBkAHMAWgBTAGcAbgBhAFgATQB0AFkAbgBWAHoAZQBTAGMA
>> "%~1" echo cwBiADIANABwAGYAUQAwAEsAWQBYAE4ANQBiAG0ATQBnAFoAbgBWAHUAWQAzAFIA
>> "%~1" echo cABiADIANABnAFkAVwBOADAAYQBXADkAdQBLAEcARQBzAFoAWABoADAAYwBtAEUA
>> "%~1" echo OQBKAHkAYwBzAGIARwBGAGkAWgBXAHcAOQBKACsAYQBUAGoAZQBTADkAbgBDAGMA
>> "%~1" echo cwBZAG4AUgB1AFAAVwA1ADEAYgBHAHcAcwBZADIAOQB1AFoAbQBsAHkAYgBXAFYA
>> "%~1" echo awBQAFcAWgBoAGIASABOAGwASwBYAHQAcABaAGkAaABpAGQAWABOADUASwBYAEoA
>> "%~1" echo bABkAEgAVgB5AGIAaQBCAHUAYgAzAFIAcABaAG4AawBvAEoAKwBXADMAcwB1AGEA
>> "%~1" echo YwBpAGUAYQBUAGoAZQBTADkAbgBPAGEASgBwACsAaQBoAGoATwBTADQAcgBTAGMA
>> "%~1" echo cwBKACsAaQB2AHQAKwBlAHQAaQBlAFcAKwBoAGUAUwA0AGkAdQBTADQAZwBPAGEA
>> "%~1" echo ZABvAGUAVwBSAHYAZQBTADcAcABPAFcAdQBqAE8AYQBJAGsATwBPAEEAZwBpAGMA
>> "%~1" echo cwBKADMAZABoAGMAbQA0AG4ASwBUAHQAMABjAG4AbAA3AGMAMgBWADAAUQBuAFYA
>> "%~1" echo egBlAFMAaAAwAGMAbgBWAGwATABHAEoAMABiAGkAawA3AGIARwA5AG4ASwBDAGYA
>> "%~1" echo bQBpAGEAZgBvAG8AWQB6AGsAdQBLADMAdgB2AEoAbwBuAEsAMgB4AGgAWQBtAFYA
>> "%~1" echo cwBLAFQAdAB1AGIAMwBSAHAAWgBuAGsAbwBiAEcARgBpAFoAVwB3AHMASgArAGEA
>> "%~1" echo dABvACsAVwBjAHEATwBXAFAAawBlAG0AQQBnAGUAVwBSAHYAZQBTADcAcABDADQA
>> "%~1" echo dQBMAGkAYwBzAEoAMwBkAGgAYwBtADQAbgBMAEQARQA0AE0ARABBAHAATwAyAHgA
>> "%~1" echo bABkAEMAQgAxAGMAbQB3ADkASgB5ADkAaABjAEcAawB2AFkAVwBOADAAYQBXADkA
>> "%~1" echo dQBQADIARgBqAGQARwBsAHYAYgBqADAAbgBLADIAVgB1AFkAMgA5AGsAWgBWAFYA
>> "%~1" echo UwBTAFUATgB2AGIAWABCAHYAYgBtAFYAdQBkAEMAaABoAEsAUwB0AGwAZQBIAFIA
>> "%~1" echo eQBZAFQAdABwAFoAaQBoAGoAYgAyADUAbQBhAFgASgB0AFoAVwBRAHAAZABYAEoA
>> "%~1" echo cwBLAHoAMABuAEoAbQBOAHYAYgBtAFoAcABjAG0AMAA5AFcAVQBWAFQASgB6AHQA
>> "%~1" echo agBiADIANQB6AGQAQwBCAHkAUABXAEYAMwBZAFcAbAAwAEkARwBGAHcAYQBTAGgA
>> "%~1" echo MQBjAG0AdwBzAGUAMgAxAGwAZABHAGgAdgBaAEQAbwBuAFUARQA5AFQAVgBDAGQA
>> "%~1" echo OQBLAFQAdABwAFoAaQBoAHkATABtADkAcgBJAFQAMAA5AEoAMwBSAHkAZABXAFUA
>> "%~1" echo bgBLAFgAUgBvAGMAbQA5ADMASQBHADUAbABkAHkAQgBGAGMAbgBKAHYAYwBpAGgA
>> "%~1" echo eQBMAG0AVgB5AGMAbQA5AHkAZgBIAHcAbgA1AHAATwBOADUATAAyAGMANQBhAFMA
>> "%~1" echo eAA2AEwAUwBsAEoAeQBrADcAYgBHADkAbgBLAEgASQB1AGMAbQBWAHoAZABXAHgA
>> "%~1" echo MABmAEgAdwBuADUAYQA2AE0ANQBvAGkAUQBKAHkAawA3AGIAbQA5ADAAYQBXAFoA
>> "%~1" echo NQBLAEcAeABoAFkAbQBWAHMASwB5AGYAbAByAG8AegBtAGkASgBBAG4ATABIAEkA
>> "%~1" echo dQBjAG0AVgB6AGQAVwB4ADAAZgBIAHcAbgA1AGEANgBNADUAbwBpAFEASgB5AHcA
>> "%~1" echo bgBiADIAcwBuAEsAVAB0AHoAWgBYAFIAVQBhAFcAMQBsAGIAMwBWADAASwBDAGcA
>> "%~1" echo cABQAFQANQA3AGMAbQBWAG0AYwBtAFYAegBhAEMAaABtAFkAVwB4AHoAWgBTAGsA
>> "%~1" echo NwBiAEcAOQBoAFoARQB4AHYAWgAzAE0AbwBaAG0ARgBzAGMAMgBVAHAAZgBTAHcA
>> "%~1" echo MQBNAEQAQQBwAGYAVwBOAGgAZABHAE4AbwBLAEcAVQBwAGUAMgB4AHYAWgB5AGcA
>> "%~1" echo bgA1AHAATwBOADUATAAyAGMANQBhAFMAeAA2AEwAUwBsADcANwB5AGEASgB5AHQA
>> "%~1" echo bABMAG0AMQBsAGMAMwBOAGgAWgAyAFUAcABPADIANQB2AGQARwBsAG0AZQBTAGgA
>> "%~1" echo cwBZAFcASgBsAGIAQwBzAG4ANQBhAFMAeAA2AEwAUwBsAEoAeQB4AGwATABtADEA
>> "%~1" echo bABjADMATgBoAFoAMgBVAHMASgAyAFYAeQBjAGkAYwBzAE4ARABZAHcATQBDAGsA
>> "%~1" echo NwBiAEcAOQBoAFoARQB4AHYAWgAzAE0AbwBaAG0ARgBzAGMAMgBVAHAAZgBXAFoA
>> "%~1" echo cABiAG0ARgBzAGIASABsADcAYwAyAFYAMABRAG4AVgB6AGUAUwBoAG0AWQBXAHgA
>> "%~1" echo egBaAFMAeABpAGQARwA0AHAAZgBYADAATgBDAG0ARgB6AGUAVwA1AGoASQBHAFoA
>> "%~1" echo MQBiAG0ATgAwAGEAVwA5AHUASQBHAFYANABjAEcAOQB5AGQARQBoADAAYgBXAHcA
>> "%~1" echo bwBLAFgAdABwAFoAaQBoAGkAZABYAE4ANQBLAFgASgBsAGQASABWAHkAYgBpAEIA
>> "%~1" echo dQBiADMAUgBwAFoAbgBrAG8ASgArAFcAMwBzAHUAYQBjAGkAZQBhAFQAagBlAFMA
>> "%~1" echo OQBuAE8AYQBKAHAAKwBpAGgAagBPAFMANAByAFMAYwBzAEoAKwBpAHYAdAArAGUA
>> "%~1" echo dABpAGUAVwArAGgAZQBTADQAaQB1AFMANABnAE8AYQBkAG8AZQBXAFIAdgBlAFMA
>> "%~1" echo NwBwAE8AVwB1AGoATwBhAEkAawBPAE8AQQBnAGkAYwBzAEoAMwBkAGgAYwBtADQA
>> "%~1" echo bgBLAFQAdABqAGIAMgA1AHoAZABDAEIAaQBkAEcANAA5AEoAQwBnAG4AWgBYAGgA
>> "%~1" echo dwBiADMASgAwAFEAbgBSAHUASgB5AGsANwBkAEgASgA1AGUAMwBOAGwAZABFAEoA
>> "%~1" echo MQBjADMAawBvAGQASABKADEAWgBTAHgAaQBkAEcANABwAE8AMwBOAGwAZABDAGcA
>> "%~1" echo bgBaAFgAaAB3AGIAMwBKADAAVQAzAFIAaABkAEgAVgB6AEoAeQB3AG4ANQBxADIA
>> "%~1" echo agA1AFoAeQBvADUAWQArAHEANgBLACsANwA2AFkAZQBIADYAWgB1AEcANQBhADYA
>> "%~1" echo TQA1AHAAVwAwADYASwA2ACsANQBhAFMASAA1AEwAKwBoADUAbwBHAHYANwA3AHkA
>> "%~1" echo TQA1AFkAKwB2ADYASQBPADkANgBaAHkAQQA2AEsAYQBCAEkARABFAHcATABUAFEA
>> "%~1" echo dwBJAE8AZQBuAGsAaQA0AHUATABpAGMAcABPAHkAUQBvAEoAMgBWADQAYwBHADkA
>> "%~1" echo eQBkAEUAeABwAGIAbQB0AHoASgB5AGsAdQBhAFcANQB1AFoAWABKAEkAVgBFADEA
>> "%~1" echo TQBQAFMAYwBuAE8AMgA1AHYAZABHAGwAbQBlAFMAZwBuADUAYgB5AEEANQBhAGUA
>> "%~1" echo TAA1AGEAKwA4ADUAWQBlADYASgB5AHcAbgA1AHEAMgBqADUAWgB5AG8ANQA1AFMA
>> "%~1" echo ZgA1AG8AaQBRADUANgBlAEIANQBwAHkASgA1AGEANgBNADUAcABXADAANQA0AG0A
>> "%~1" echo SQA1AFoASwBNADUAWQBpAEcANQBMAHEAcgA1AGEANgBKADUAWQBXAG8ANQA0AG0A
>> "%~1" echo SQBJAEUAaABVAFQAVQB3AG4ATABDAGQAMwBZAFgASgB1AEoAeQB3AHkATQBqAEEA
>> "%~1" echo dwBLAFQAdABqAGIAMgA1AHoAZABDAEIAeQBQAFcARgAzAFkAVwBsADAASQBHAEYA
>> "%~1" echo dwBhAFMAZwBuAEwAMgBGAHcAYQBTADkAbABlAEgAQgB2AGMAbgBRAC8AYgBXADkA
>> "%~1" echo awBaAFQAMQBpAGIAMwBSAG8ASgB5AHgANwBiAFcAVgAwAGEARwA5AGsATwBpAGQA
>> "%~1" echo UQBUADEATgBVAEoAMwAwAHAATwAyAGwAbQBLAEgASQB1AGIAMgBzAGgAUABUADAA
>> "%~1" echo bgBkAEgASgAxAFoAUwBjAHAAZABHAGgAeQBiADMAYwBnAGIAbQBWADMASQBFAFYA
>> "%~1" echo eQBjAG0AOQB5AEsASABJAHUAWgBYAEoAeQBiADMASgA4AGYAQwBmAGwAcgA3AHoA
>> "%~1" echo bABoADcAcgBsAHAATABIAG8AdABLAFUAbgBLAFQAdAB6AFoAWABRAG8ASgAyAFYA
>> "%~1" echo NABjAEcAOQB5AGQARgBOADAAWQBYAFIAMQBjAHkAYwBzAEoAKwBXAHYAdgBPAFcA
>> "%~1" echo SAB1AHUAVwB1AGoATwBhAEkAawBPACsAOABtAGkAYwByAEsASABJAHUAYwAyAFYA
>> "%~1" echo agBkAEcAbAB2AGIAawBOAHYAZABXADUAMABmAEgAdwBuAEwAUwBjAHAASwB5AGMA
>> "%~1" echo ZwA1AEwAaQBxADYAWQBlAEgANgBaAHUARwA1AHEANgAxADcANwB5AE0ANgBJAEMA
>> "%~1" echo WAA1AHAAZQAyAEkAQwBjAHIAVABXAEYAMABhAEMANQB5AGIAMwBWAHUAWgBDAGcA
>> "%~1" echo bwBjAEcARgB5AGMAMgBWAEoAYgBuAFEAbwBjAGkANQBrAGQAWABKAGgAZABHAGwA
>> "%~1" echo dgBiAGsAMQB6AGYASAB3AG4ATQBDAGMAcwBNAFQAQQBwAGYASAB3AHcASwBTADgA
>> "%~1" echo eABNAEQAQQB3AEsAUwBzAG4ASQBPAGUAbgBrAHUATwBBAGcAaQBjAHAATwB5AFEA
>> "%~1" echo bwBKADIAVgA0AGMARwA5AHkAZABFAHgAcABiAG0AdAB6AEoAeQBrAHUAYQBXADUA
>> "%~1" echo dQBaAFgASgBJAFYARQAxAE0AUABTAGMAOABZAFMAQgAwAFkAWABKAG4AWgBYAFEA
>> "%~1" echo OQBYAEMASgBmAFkAbQB4AGgAYgBtAHQAYwBJAGkAQgBvAGMAbQBWAG0AUABWAHcA
>> "%~1" echo aQBKAHkAdABsAGMAMgBNAG8AYwBpADUAdwBjAG0AbAAyAFkAWABSAGwAVgBYAEoA
>> "%~1" echo cwBLAFMAcwBuAFgAQwBJACsANQBvAG0AVAA1AGIAeQBBADUANgBlAEIANQBwAHkA
>> "%~1" echo SgA1AGEANgBNADUAcABXADAANQA0AG0ASQBJAEUAaABVAFQAVQB3ADgATAAyAEUA
>> "%~1" echo KwBQAEcARQBnAGQARwBGAHkAWgAyAFYAMABQAFYAdwBpAFgAMgBKAHMAWQBXADUA
>> "%~1" echo cgBYAEMASQBnAGEASABKAGwAWgBqADEAYwBJAGkAYwByAFoAWABOAGoASwBIAEkA
>> "%~1" echo dQBjADIARgBtAFoAVgBWAHkAYgBDAGsAcgBKADEAdwBpAFAAdQBhAEoAawArAFcA
>> "%~1" echo OABnAE8AVwBJAGgAdQBTADYAcQArAFcAdQBpAGUAVwBGAHEATwBlAEoAaQBDAEIA
>> "%~1" echo SQBWAEUAMQBNAFAAQwA5AGgAUABqAHgAegBjAEcARgB1AFAAaQBjAHIAWgBYAE4A
>> "%~1" echo agBLAEgASQB1AGMAMgBGAG0AWgBWAEIAaABkAEcAaAA4AGYAQwBjAG4ASwBTAHMA
>> "%~1" echo bgBQAEMAOQB6AGMARwBGAHUAUABpAGMANwBiAG0AOQAwAGEAVwBaADUASwBDAGYA
>> "%~1" echo bAByADcAegBsAGgANwByAGwAcgBvAHoAbQBpAEoAQQBuAEwAQwBmAGwAdAA3AEwA
>> "%~1" echo bgBsAEoALwBtAGkASgBEAGsAdQBLAFQAawB1ADcAMABnAFMARgBSAE4AVABDAEQA
>> "%~1" echo bQBpAHEAWABsAGsAWQBvAG4ATABDAGQAdgBhAHkAYwBwAE8AMgB4AHYAWQBXAFIA
>> "%~1" echo TQBiADIAZAB6AEsARwBaAGgAYgBIAE4AbABLAFgAMQBqAFkAWABSAGoAYQBDAGgA
>> "%~1" echo bABLAFgAdAB6AFoAWABRAG8ASgAyAFYANABjAEcAOQB5AGQARgBOADAAWQBYAFIA
>> "%~1" echo MQBjAHkAYwBzAEoAKwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABlACsA
>> "%~1" echo OABtAGkAYwByAFoAUwA1AHQAWgBYAE4AegBZAFcAZABsAEsAVAB0AHUAYgAzAFIA
>> "%~1" echo cABaAG4AawBvAEoAKwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABTAGMA
>> "%~1" echo cwBaAFMANQB0AFoAWABOAHoAWQBXAGQAbABMAEMAZABsAGMAbgBJAG4ATABEAFUA
>> "%~1" echo eQBNAEQAQQBwAE8AMgB4AHYAWQBXAFIATQBiADIAZAB6AEsARwBaAGgAYgBIAE4A
>> "%~1" echo bABLAFgAMQBtAGEAVwA1AGgAYgBHAHgANQBlADMATgBsAGQARQBKADEAYwAzAGsA
>> "%~1" echo bwBaAG0ARgBzAGMAMgBVAHMAWQBuAFIAdQBLAFgAMQA5AEQAUQBwAGsAYgAyAE4A
>> "%~1" echo MQBiAFcAVgB1AGQAQwA1AHgAZABXAFYAeQBlAFYATgBsAGIARwBWAGoAZABHADkA
>> "%~1" echo eQBRAFcAeABzAEsAQwBkAGIAWgBHAEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADUA
>> "%~1" echo ZABKAHkAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMAaABpAFAAVAA1AGkATABtADkA
>> "%~1" echo dQBZADIAeABwAFkAMgBzADkASwBDAGsAOQBQAG4AdABqAGIAMgA1AHoAZABDAEIA
>> "%~1" echo cwBZAFcASgBsAGIARAAxAGkATABuAEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4A
>> "%~1" echo MABiADMASQBvAEoAMgBJAG4ASwBUADgAdQBkAEcAVgA0AGQARQBOAHYAYgBuAFIA
>> "%~1" echo bABiAG4AUgA4AGYARwBJAHUAWgBHAEYAMABZAFgATgBsAGQAQwA1AGgAWQAzAFIA
>> "%~1" echo cABiADIANAA3AGEAVwBZAG8AWQBpADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEA
>> "%~1" echo dQBZADIAOQB1AGQARwBGAHAAYgBuAE0AbwBKADIAUgBoAGIAbQBkAGwAYwBrAEYA
>> "%~1" echo agBkAEcAbAB2AGIAaQBjAHAASwBYAE4AbwBiADMAZABEAGIAMgA1AG0AYQBYAEoA
>> "%~1" echo dABLAEcASQB1AFoARwBGADAAWQBYAE4AbABkAEMANQBoAFkAMwBSAHAAYgAyADQA
>> "%~1" echo cwBiAEcARgBpAFoAVwB3AHMASgB5AGMAcABPADIAVgBzAGMAMgBVAGcAWQBXAE4A
>> "%~1" echo MABhAFcAOQB1AEsARwBJAHUAWgBHAEYAMABZAFgATgBsAGQAQwA1AGgAWQAzAFIA
>> "%~1" echo cABiADIANABzAEoAeQBjAHMAYgBHAEYAaQBaAFcAdwBzAFkAaQB4AG0AWQBXAHgA
>> "%~1" echo egBaAFMAbAA5AEsAVABzAE4AQwBpAFEAbwBKADIATgB2AGIAbQBaAHAAYwBtADEA
>> "%~1" echo RABZAFcANQBqAFoAVwB3AG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABXAE4A
>> "%~1" echo cwBiADMATgBsAFEAMgA5AHUAWgBtAGwAeQBiAFQAcwBrAEsAQwBkAGoAYgAyADUA
>> "%~1" echo bQBhAFgASgB0AFQAMgBzAG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcA
>> "%~1" echo cABQAFQANQA3AFkAMgA5AHUAYwAzAFEAZwBjAEQAMQB3AFoAVwA1AGsAYQBXADUA
>> "%~1" echo bgBRADIAOQB1AFoAbQBsAHkAYgBUAHQAagBiAEcAOQB6AFoAVQBOAHYAYgBtAFoA
>> "%~1" echo cABjAG0AMABvAEsAVAB0AHAAWgBpAGgAdwBLAFcARgBqAGQARwBsAHYAYgBpAGgA
>> "%~1" echo dwBMAG0ARgBqAGQARwBsAHYAYgBpAHgAdwBMAG0AVgA0AGQASABKAGgATABIAEEA
>> "%~1" echo dQBiAEcARgBpAFoAVwB3AHMAYgBuAFYAcwBiAEMAeAAwAGMAbgBWAGwASwBYADAA
>> "%~1" echo NwBEAFEAbwBrAEsAQwBkAHkAWgBXAFoAeQBaAFgATgBvAFEAbgBSAHUASgB5AGsA
>> "%~1" echo dQBiADIANQBqAGIARwBsAGoAYQB6ADAAbwBLAFQAMAArAGUAMgA1AHYAZABHAGwA
>> "%~1" echo bQBlAFMAZwBuADUAWQBpADMANQBwAGEAdwA1ADQAcQAyADUAbwBDAEIASgB5AHcA
>> "%~1" echo bgA1AHEAMgBqADUAWgB5AG8ANgBLACsANwA1AFkAKwBXAEkARgBGADEAWgBYAE4A
>> "%~1" echo MABJAE8AZQBLAHQAdQBhAEEAZwBTADQAdQBMAGkAYwBzAEoAMwBkAGgAYwBtADQA
>> "%~1" echo bgBMAEQARQAyAE0ARABBAHAATwAzAEoAbABaAG4ASgBsAGMAMgBnAG8AZABIAEoA
>> "%~1" echo MQBaAFMAawA3AGIARwA5AGgAWgBFAHgAdgBaADMATQBvAFoAbQBGAHMAYwAyAFUA
>> "%~1" echo cABmAFQAcwBOAEMAaQBRAG8ASgAyADEAaABiAG4AVgBoAGIARgBKAGwAWgBuAEoA
>> "%~1" echo bABjADIAZwBuAEsAUwA1AHYAYgBtAE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUA
>> "%~1" echo NwBiAG0AOQAwAGEAVwBaADUASwBDAGYAbABpAEwAZgBtAGwAcgBEAG4AaQByAGIA
>> "%~1" echo bQBnAEkARQBuAEwAQwBmAG0AcgBhAFAAbABuAEsAagBvAHIANwB2AGwAagA1AFkA
>> "%~1" echo ZwBVAFgAVgBsAGMAMwBRAGcANQA0AHEAMgA1AG8AQwBCAEwAaQA0AHUASgB5AHcA
>> "%~1" echo bgBkADIARgB5AGIAaQBjAHMATQBUAFkAdwBNAEMAawA3AGMAbQBWAG0AYwBtAFYA
>> "%~1" echo egBhAEMAaAAwAGMAbgBWAGwASwBUAHQAcwBiADIARgBrAFQARwA5AG4AYwB5AGgA
>> "%~1" echo bQBZAFcAeAB6AFoAUwBsADkATwB3ADAASwBKAEMAZwBuAGMAbQBWAG0AYwBtAFYA
>> "%~1" echo egBhAEUAeAB2AFoAMwBNAG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcA
>> "%~1" echo cABQAFQANQBzAGIAMgBGAGsAVABHADkAbgBjAHkAaAAwAGMAbgBWAGwASwBUAHMA
>> "%~1" echo TgBDAGkAUQBvAEoAMgBWADQAYwBHADkAeQBkAEUASgAwAGIAaQBjAHAATABtADkA
>> "%~1" echo dQBZADIAeABwAFkAMgBzADkAWgBYAGgAdwBiADMASgAwAFMASABSAHQAYgBEAHMA
>> "%~1" echo TgBDAGkAUQBvAEoAMwBSAG8AWgBXADEAbABRAG4AUgB1AEoAeQBrAHUAYgAyADUA
>> "%~1" echo agBiAEcAbABqAGEAegAwAG8ASwBUADAAKwBlADIAeAB2AFkAMgBGAHMAVQAzAFIA
>> "%~1" echo dgBjAG0ARgBuAFoAUwA1AHoAWgBYAFIASgBkAEcAVgB0AEsASABSAG8AWgBXADEA
>> "%~1" echo bABTADIAVgA1AEwARwBSAHYAWQAzAFYAdABaAFcANQAwAEwAbQBKAHYAWgBIAGsA
>> "%~1" echo dQBZADIAeABoAGMAMwBOAE0AYQBYAE4AMABMAG0ATgB2AGIAbgBSAGgAYQBXADUA
>> "%~1" echo egBLAEMAZABrAFkAWABKAHIASgB5AGsALwBKADIAeABwAFoAMgBoADAASgB6AG8A
>> "%~1" echo bgBaAEcARgB5AGEAeQBjAHAATwAzAFIAbwBaAFcAMQBsAEsAQwBrADcAYgBtADkA
>> "%~1" echo MABhAFcAWgA1AEsAQwBmAGsAdQBMAHYAcABvAHAAagBsAHQANwBMAGwAaQBJAGYA
>> "%~1" echo bQBqAGEASQBuAEwAQwBRAG8ASgAzAFIAbwBaAFcAMQBsAFEAbgBSAHUASgB5AGsA
>> "%~1" echo dQBkAEcAVgA0AGQARQBOAHYAYgBuAFIAbABiAG4AUQA5AFAAVAAwAG4ANQByAFcA
>> "%~1" echo RgA2AEkAbQB5AEoAegA4AG4ANQBiADIAVAA1AFkAbQBOADUATABpADYANQByAGUA
>> "%~1" echo eAA2AEkAbQB5ADUAcQBpAGgANQBiAHkAUABKAHoAbwBuADUAYgAyAFQANQBZAG0A
>> "%~1" echo TgA1AEwAaQA2ADUAcgBXAEYANgBJAG0AeQA1AHEAaQBoADUAYgB5AFAASgB5AHcA
>> "%~1" echo bgBiADIAcwBuAEsAWAAwADcARABRAG8AawBLAEMAZABqAGQAWABOADAAYgAyADEA
>> "%~1" echo VABaAFgAUQBuAEsAUwA1AHYAYgBtAE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUA
>> "%~1" echo egBhAEcAOQAzAFEAMgA5AHUAWgBtAGwAeQBiAFMAZwBuAFkAMwBWAHoAZABHADkA
>> "%~1" echo dABYADMATgBsAGQASABSAHAAYgBtAGMAbgBMAEMAZgBsAGgAcABuAGwAaABhAFUA
>> "%~1" echo ZwBjADIAVgAwAGQARwBsAHUAWgAzAE0AbgBMAEMAYwBtAGIAbgBNADkASgB5AHQA
>> "%~1" echo bABiAG0ATgB2AFoARwBWAFYAVQBrAGwARABiADIAMQB3AGIAMgA1AGwAYgBuAFEA
>> "%~1" echo bwBKAEMAZwBuAFkAMwBWAHoAZABHADkAdABUAG4ATQBuAEsAUwA1ADIAWQBXAHgA
>> "%~1" echo MQBaAFMAawByAEoAeQBaAHIAWgBYAGsAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYA
>> "%~1" echo VgBVAGsAbABEAGIAMgAxAHcAYgAyADUAbABiAG4AUQBvAEoAQwBnAG4AWQAzAFYA
>> "%~1" echo egBkAEcAOQB0AFMAMgBWADUASgB5AGsAdQBkAG0ARgBzAGQAVwBVAHAASwB5AGMA
>> "%~1" echo bQBkAG0ARgBzAGQAVwBVADkASgB5AHQAbABiAG0ATgB2AFoARwBWAFYAVQBrAGwA
>> "%~1" echo RABiADIAMQB3AGIAMgA1AGwAYgBuAFEAbwBKAEMAZwBuAFkAMwBWAHoAZABHADkA
>> "%~1" echo dABWAG0ARgBzAGQAVwBVAG4ASwBTADUAMgBZAFcAeAAxAFoAUwBrAHAATwB3ADAA
>> "%~1" echo SwBKAEMAZwBuAFkAMwBWAHoAZABHADkAdABRAG4ASgB2AFkAVwBSAGoAWQBYAE4A
>> "%~1" echo MABKAHkAawB1AGIAMgA1AGoAYgBHAGwAagBhAHoAMABvAEsAVAAwACsAYwAyAGgA
>> "%~1" echo dgBkADAATgB2AGIAbQBaAHAAYwBtADAAbwBKADIATgAxAGMAMwBSAHYAYgBWADkA
>> "%~1" echo aQBjAG0AOQBoAFoARwBOAGgAYwAzAFEAbgBMAEMAZgBsAGoANQBIAHAAZwBJAEgA
>> "%~1" echo bAB1AGIALwBtAGsAcQAwAG4ATABDAGMAbQBiAG0ARgB0AFoAVAAwAG4ASwAyAFYA
>> "%~1" echo dQBZADIAOQBrAFoAVgBWAFMAUwBVAE4AdgBiAFgAQgB2AGIAbQBWAHUAZABDAGcA
>> "%~1" echo awBLAEMAZABpAGMAbQA5AGgAWgBHAE4AaABjADMAUgBPAFkAVwAxAGwASgB5AGsA
>> "%~1" echo dQBkAG0ARgBzAGQAVwBVAHAASwBUAHMATgBDAGkAUQBvAEoAMgBkAHYAUQAzAFYA
>> "%~1" echo egBkAEcAOQB0AFEAbgBKAHYAWQBXAFIAagBZAFgATgAwAEoAeQBrAHUAYgAyADUA
>> "%~1" echo agBiAEcAbABqAGEAegAwAG8ASwBUADAAKwBlADIAeAB2AFkAMgBGADAAYQBXADkA
>> "%~1" echo dQBMAG0AaABoAGMAMgBnADkASgAzAE4AbABkAEgAUgBwAGIAbQBkAHoASgB6AHQA
>> "%~1" echo dQBiADMAUgBwAFoAbgBrAG8ASgArAFcAMwBzAHUAVwBJAGgAKwBhAE4AbwBpAGMA
>> "%~1" echo cwBKACsAbQByAG0ATwBlADYAcAB5AEIAegBaAFgAUgAwAGEAVwA1AG4AYwB5AGMA
>> "%~1" echo cwBKADIAOQByAEoAeQB3AHgATwBEAEEAdwBLAFgAMAA3AEQAUQBvAGsASwBDAGQA
>> "%~1" echo bgBiADAAeAB2AFoAMwBNAG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcA
>> "%~1" echo cABQAFQANQA3AGIARwA5AGoAWQBYAFIAcABiADIANAB1AGEARwBGAHoAYQBEADAA
>> "%~1" echo bgBiAEcAOQBuAGMAeQBjADcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGwAdAA3AEwA
>> "%~1" echo bABpAEkAZgBtAGoAYQBJAG4ATABDAGYAbQBsADYAWABsAHYANQBjAG4ATABDAGQA
>> "%~1" echo dgBhAHkAYwBzAE0AVABnAHcATQBDAGwAOQBPAHcAMABLAFoAbgBWAHUAWQAzAFIA
>> "%~1" echo cABiADIANABnAGMAbQA5ADEAZABHAFUAbwBLAFgAdABqAGIAMgA1AHoAZABDAEIA
>> "%~1" echo cABaAEQAMABvAGIARwA5AGoAWQBYAFIAcABiADIANAB1AGEARwBGAHoAYQBIAHgA
>> "%~1" echo OABKAHkATgB2AGQAbQBWAHkAZABtAGwAbABkAHkAYwBwAEwAbgBOAHMAYQBXAE4A
>> "%~1" echo bABLAEQARQBwAE8AMgBSAHYAWQAzAFYAdABaAFcANQAwAEwAbgBGADEAWgBYAEoA
>> "%~1" echo NQBVADIAVgBzAFoAVwBOADAAYgAzAEoAQgBiAEcAdwBvAEoAeQA1AHcAWQBXAGQA
>> "%~1" echo bABKAHkAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMAaAB3AFAAVAA1AHcATABtAE4A
>> "%~1" echo cwBZAFgATgB6AFQARwBsAHoAZABDADUAMABiADIAZABuAGIARwBVAG8ASgAyAEYA
>> "%~1" echo agBkAEcAbAAyAFoAUwBjAHMAYwBDADUAcABaAEQAMAA5AFAAVwBsAGsASwBTAGsA
>> "%~1" echo NwBaAEcAOQBqAGQAVwAxAGwAYgBuAFEAdQBjAFgAVgBsAGMAbgBsAFQAWgBXAHgA
>> "%~1" echo bABZADMAUgB2AGMAawBGAHMAYgBDAGcAbgBMAG0ANQBoAGQAaQBCAGgASgB5AGsA
>> "%~1" echo dQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAaABQAFQANQBoAEwAbQBOAHMAWQBYAE4A
>> "%~1" echo egBUAEcAbAB6AGQAQwA1ADAAYgAyAGQAbgBiAEcAVQBvAEoAMgBGAGoAZABHAGwA
>> "%~1" echo MgBaAFMAYwBzAFkAUwA1AG4AWgBYAFIAQgBkAEgAUgB5AGEAVwBKADEAZABHAFUA
>> "%~1" echo bwBKADIAaAB5AFoAVwBZAG4ASwBUADAAOQBQAFMAYwBqAEoAeQB0AHAAWgBDAGsA
>> "%~1" echo cABPADIATgB2AGIAbgBOADAASQBHADAAOQBjAEcARgBuAFoAWABOAGIAYQBXAFIA
>> "%~1" echo ZABmAEgAeAB3AFkAVwBkAGwAYwB5ADUAdgBkAG0AVgB5AGQAbQBsAGwAZAB6AHQA
>> "%~1" echo egBaAFgAUQBvAEoAMwBCAGgAWgAyAFYAVQBhAFgAUgBzAFoAUwBjAHMAYgBWAHMA
>> "%~1" echo dwBYAFMAawA3AGMAMgBWADAASwBDAGQAdwBZAFcAZABsAFUAMwBWAGkASgB5AHgA
>> "%~1" echo dABXAHoARgBkAEsAVAB0AHAAWgBpAGgAcABaAEQAMAA5AFAAUwBkAHMAYgAyAGQA
>> "%~1" echo egBKAHkAbABzAGIAMgBGAGsAVABHADkAbgBjAHkAaABtAFkAVwB4AHoAWgBTAGwA
>> "%~1" echo OQBEAFEAcAAwAGEARwBWAHQAWgBTAGcAcABPADIARgBrAFoARQBWADIAWgBXADUA
>> "%~1" echo MABUAEcAbAB6AGQARwBWAHUAWgBYAEkAbwBKADIAaABoAGMAMgBoAGoAYQBHAEYA
>> "%~1" echo dQBaADIAVQBuAEwASABKAHYAZABYAFIAbABLAFQAdAB5AGIAMwBWADAAWgBTAGcA
>> "%~1" echo cABPADMASgBsAFoAbgBKAGwAYwAyAGcAbwBLAFQAdABzAGIAMgBGAGsAVABHADkA
>> "%~1" echo bgBjAHkAaABtAFkAVwB4AHoAWgBTAGsANwBjADIAVgAwAFMAVwA1ADAAWgBYAEoA
>> "%~1" echo MgBZAFcAdwBvAEsAQwBrADkAUABuAE4AbABkAEMAZwBuAFkAMgB4AHYAWQAyAHQA
>> "%~1" echo VQBaAFgAaAAwAEoAeQB4AHUAWgBYAGMAZwBSAEcARgAwAFoAUwBnAHAATABuAFIA
>> "%~1" echo dgBUAEcAOQBqAFkAVwB4AGwAVgBHAGwAdABaAFYATgAwAGMAbQBsAHUAWgB5AGcA
>> "%~1" echo cABLAFMAdwB4AE0ARABBAHcASwBUAHQAegBaAFgAUgBKAGIAbgBSAGwAYwBuAFoA
>> "%~1" echo aABiAEMAZwBvAEsAVAAwACsAYwBtAFYAbQBjAG0AVgB6AGEAQwBoAG0AWQBXAHgA
>> "%~1" echo egBaAFMAawBzAE0AVABVAHcATQBEAEEAcABPAHcAMABLAFAAQwA5AHoAWQAzAEoA
>> "%~1" echo cABjAEgAUQArAFAAQwA5AGkAYgAyAFIANQBQAGoAdwB2AGEASABSAHQAYgBEADQA
>> "%~1" echo TgBDAGcAPQA9AAATWwBbAFQATwBLAEUATgBdAF0AAANOAAAACc7/y+hWxU6+ByvP
>> "%~1" echo MP41ewAIt3pcVhk04IkCBg4CBggCBhwDBhIJBQABAR0OAwAACAsABAEVEg0BDg4O
>> "%~1" echo DgwABAEVEg0BDg4OHQ4FAAEBEhEIAAAVEhUCDg4KAAIVEhUCDg4ODgUAAg4ODgYA
>> "%~1" echo AgESGQ4EAAEBDgMAAA4HAAIOEA4QDgYAAw4ODg4GAAMODggOBgACDggdDggABAES
>> "%~1" echo HQ4ODgQAAQ4OCgACARUSFQIODg4GAAISFA4OCQAFARIUDg4IDgoABQESFA4IAh0O
>> "%~1" echo BwACEhASFA4FAAEBEhQGAAIOEhQCDwAFARIdDhUSFQIODgIdDggAAwESHRIUAgcA
>> "%~1" echo Aw4OHQ4ICAADEgwOHQ4IBQABDh0OBAABCA4FAAIIDg4KAAIOFRIVAg4ODgUAAg4O
>> "%~1" echo AgYAAg4OEhQFAAEdDg4EAAECDgkAARUSFQIODg4LAAIBEhkVEhUCDg4IAAMBEhkO
>> "%~1" echo HQUJAAEOFRIVAg4OAyAAAQIGAgMgAA4DKAAOAgYKBwYVEhUCDg4HBhUSDQESEAYG
>> "%~1" echo FRINAQ4EAQAAAAQgAQEIBAABARwDBhIxBAcBEjkEAAASCQUAAQESCQUAAgIODgQA
>> "%~1" echo AQEIBAAAEkkFAAESTQ4GIAIBEk0IBAAAEVUFAAEOHRwGAAMOHBwcBiACAg4RXQUA
>> "%~1" echo ARJhDgQgABIRBSACARwYBgACAhIxHBEHChJRCA4ODhIREjkCHRwdDgUVEg0BDgMg
>> "%~1" echo AAgIIAAVEWkBEwAFFRFpAQ4EIAATAAQAABJtBCABAQ4DIAACEwcIFRINAQ4ODg4I
>> "%~1" echo HQ4CFRFpAQ4FIAEBEwAFBwICHQ4GIAIIDhFdCQcFDh0OCAIdDgQgABJ1ByACARIZ
>> "%~1" echo EgkGIAEdDh0DBSABHQUOFQcMEhkSeQ4dDg4ODhKAhQ4SEQIdAwUAAg4cHAYVEhUC
>> "%~1" echo Dg4HIAIBEwATAQYgARMBEwAXBwkVEhUCDg4ODg4OFRIVAg4OAh0OHQMHAAQODg4O
>> "%~1" echo DgUgAQITABgHChUSFQIODg4ODg4OEjkVEhUCDg4CHQ4OBwIVEhUCDg4VEhUCDg4F
>> "%~1" echo AAARgI0EIAEODgYAARKAmQ4HAAMBDg4SCQsAAhGAoRGAjRGAjQMgAA0FAAASgKUG
>> "%~1" echo IAEOEoCtBhUSDQESEAUgAB0TAAYAAg4OHQ4qBxUVEhUCDg4RgI0ODg4OEhQODg4O
>> "%~1" echo Dg4RgKESORUSFQIODgIdAxGAjQoIBQcCDh0OBCABDggCBgMFIAIOAwMEIAEIAwUA
>> "%~1" echo AR0FDggHBQ4ODhI5AgcHBA4ODh0DBSABDh0DCQcEDh0DAhGAjQYAAgEcEAIIBwQC
>> "%~1" echo HBGAjQIHIAMOHQUICAwHCB0FCAgOCBI5DgIJIAIdDh0DEYC1FgcQDg4ODg4ODg4d
>> "%~1" echo DgIOHQ4dDggCHQMDBwEOBAcCDg4JBwUSDA4OAh0cBSABEh0OCQcEDhIdAhGAjQUg
>> "%~1" echo ARIdAwQHAg4CBwACHQ4OEgkHIAIdDh0DCA8HCQ4ODh0OAh0OCB0DHQ4FIAIODg4F
>> "%~1" echo BwMODg4MAAQCDhGAvRKArRANByACDg4SgK0HBwUODg0CDQUgAg4ICBEHCg4VEg0B
>> "%~1" echo Dg4ODg4OHQ4IAhIHDA4ODh0ODg4OHQ4IAh0DHQ4GBwQODg4CDgcIDg4ODg4OFRIN
>> "%~1" echo AQ4CCwcEEhQSFBGAjR0OBAcBHQ4FAAASgMEDIAAKCgcEEoDBEgwSEAIGFRFpARIQ
>> "%~1" echo DQcEEhASEBURaQESEAIZBxIVEhUCDg4ODg4ODg4ODg4ODg4ODQINCBQHCRUSFQIO
>> "%~1" echo Dg4ODg4SHQ4RgI0dDhEHCw4dDg4ODg4dDggdAwIdDg4HBRIQDhURaQESEAIdDgQg
>> "%~1" echo AQgODQcKDg4OCA4IDgIdDggDBhIMAwYSGAMGEmEEIAASeQQgAQECBwABEmESgMUG
>> "%~1" echo IAEBEoDJBCABAggUBwgSgMUSgIkSgIkSHBI5EhgSDAIHBwQSHQgOAgMGESQJAAIB
>> "%~1" echo EoDVEYDZBSABCB0DBCABAg4JBwYODg4dDggCDAcJDg4IDggOHQ4IAggHBg4IDggO
>> "%~1" echo AgoHBw4OCA4dDggCDwcKDg4dDg0OHQ4IAh0DDQwHCA4ODg4dDggCHQMHIAMIDggR
>> "%~1" echo XQYHBAgIDgIKAAMSgOEODhGA5QUgABKA7QYgARKA6QgGBwISgOEOBQACAhwcCQcE
>> "%~1" echo EoDhDgIdAwYHBA4IDgIPBwkODh0ODh0OCAIdAx0OBgcECA4OAg8HCQ4ODg4OFRIN
>> "%~1" echo AQ4OCAIMBwYODg4VEg0BDg4CDgcIDg4ODg4VEg0BDg4CEAcJCA4ICAgVEg0BDg4C
>> "%~1" echo HRwFBwMODgIJBwYIDggdDggCCgADEoD1Dg4RgOUDBwEIBgABDhKA4QQGEoD9CAAD
>> "%~1" echo Dg4OEoD9CQAEDg4ODhGA5QYHAh0OHQMDBwECBCABAwgEAAECAwcHBQMCAg4IDQcJ
>> "%~1" echo DggODg4CHQMdDggHIAMBHQUICAcHAw4dBR0cCyAAFRGBAQITABMBBxURgQECDg4L
>> "%~1" echo IAAVEYEFAhMAEwEHFRGBBQIODgQgABMBFQcGEh0CFRGBBQIODg4VEYEBAg4OAgoH
>> "%~1" echo BxIdAw4OCAIIBSABDh0FAwAAAQUAABGBDQUHARGBDQgBAAgAAAAAAB4BAAEAVAIW
>> "%~1" echo V3JhcE5vbkV4Y2VwdGlvblRocm93cwEAgNICAAAAAAAAAAAAntICAAAgAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAJDSAgAAAAAAAAAAAAAAAAAAAF9Db3JFeGVNYWluAG1z
>> "%~1" echo Y29yZWUuZGxsAAAAAAD/JQAgQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAQAAAAIAAAgBgAAAA4AACA
>> "%~1" echo AAAAAAAAAAAAAAAAAAABAAEAAABQAACAAAAAAAAAAAAAAAAAAAABAAEAAABoAACA
>> "%~1" echo AAAAAAAAAAAAAAAAAAABAAAAAACAAAAAAAAAAAAAAAAAAAAAAAABAAAAAACQAAAA
>> "%~1" echo oOACAFwCAAAAAAAAAAAAAADjAgDqAQAAAAAAAAAAAABcAjQAAABWAFMAXwBWAEUA
>> "%~1" echo UgBTAEkATwBOAF8ASQBOAEYATwAAAAAAvQTv/gAAAQAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo PwAAAAAAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAEQAAAABAFYAYQByAEYAaQBsAGUA
>> "%~1" echo SQBuAGYAbwAAAAAAJAAEAAAAVAByAGEAbgBzAGwAYQB0AGkAbwBuAAAAAAAAALAE
>> "%~1" echo vAEAAAEAUwB0AHIAaQBuAGcARgBpAGwAZQBJAG4AZgBvAAAAmAEAAAEAMAAwADAA
>> "%~1" echo MAAwADQAYgAwAAAALAACAAEARgBpAGwAZQBEAGUAcwBjAHIAaQBwAHQAaQBvAG4A
>> "%~1" echo AAAAACAAAAAwAAgAAQBGAGkAbABlAFYAZQByAHMAaQBvAG4AAAAAADAALgAwAC4A
>> "%~1" echo MAAuADAAAABEABIAAQBJAG4AdABlAHIAbgBhAGwATgBhAG0AZQAAAFEAdQBlAHMA
>> "%~1" echo dABBAGQAYgBXAGUAYgBVAGkALgBlAHgAZQAAACgAAgABAEwAZQBnAGEAbABDAG8A
>> "%~1" echo cAB5AHIAaQBnAGgAdAAAACAAAABMABIAAQBPAHIAaQBnAGkAbgBhAGwARgBpAGwA
>> "%~1" echo ZQBuAGEAbQBlAAAAUQB1AGUAcwB0AEEAZABiAFcAZQBiAFUAaQAuAGUAeABlAAAA
>> "%~1" echo NAAIAAEAUAByAG8AZAB1AGMAdABWAGUAcgBzAGkAbwBuAAAAMAAuADAALgAwAC4A
>> "%~1" echo MAAAADgACAABAEEAcwBzAGUAbQBiAGwAeQAgAFYAZQByAHMAaQBvAG4AAAAwAC4A
>> "%~1" echo MAAuADAALgAwAAAAAAAAAO+7vzw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9
>> "%~1" echo IlVURi04IiBzdGFuZGFsb25lPSJ5ZXMiPz4NCjxhc3NlbWJseSB4bWxucz0idXJu
>> "%~1" echo OnNjaGVtYXMtbWljcm9zb2Z0LWNvbTphc20udjEiIG1hbmlmZXN0VmVyc2lvbj0i
>> "%~1" echo MS4wIj4NCiAgPGFzc2VtYmx5SWRlbnRpdHkgdmVyc2lvbj0iMS4wLjAuMCIgbmFt
>> "%~1" echo ZT0iTXlBcHBsaWNhdGlvbi5hcHAiLz4NCiAgPHRydXN0SW5mbyB4bWxucz0idXJu
>> "%~1" echo OnNjaGVtYXMtbWljcm9zb2Z0LWNvbTphc20udjIiPg0KICAgIDxzZWN1cml0eT4N
>> "%~1" echo CiAgICAgIDxyZXF1ZXN0ZWRQcml2aWxlZ2VzIHhtbG5zPSJ1cm46c2NoZW1hcy1t
>> "%~1" echo aWNyb3NvZnQtY29tOmFzbS52MyI+DQogICAgICAgIDxyZXF1ZXN0ZWRFeGVjdXRp
>> "%~1" echo b25MZXZlbCBsZXZlbD0iYXNJbnZva2VyIiB1aUFjY2Vzcz0iZmFsc2UiLz4NCiAg
>> "%~1" echo ICAgIDwvcmVxdWVzdGVkUHJpdmlsZWdlcz4NCiAgICA8L3NlY3VyaXR5Pg0KICA8
>> "%~1" echo L3RydXN0SW5mbz4NCjwvYXNzZW1ibHk+DQoAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAADQAgAMAAAAsDIAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
>> "%~1" echo -----END CERTIFICATE-----
exit /b 0
