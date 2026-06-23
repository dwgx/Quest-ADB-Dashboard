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
>> "%~1" echo dCBiZSBydW4gaW4gRE9TIG1vZGUuDQ0KJAAAAAAAAABQRQAATAEDANkVOmoAAAAA
>> "%~1" echo AAAAAOAAAgELAQsAAKoCAAAIAAAAAAAADskCAAAgAAAA4AIAAABAAAAgAAAAAgAA
>> "%~1" echo BAAAAAAAAAAEAAAAAAAAAAAgAwAAAgAAAAAAAAMAQIUAABAAABAAAAAAEAAAEAAA
>> "%~1" echo AAAAABAAAAAAAAAAAAAAALzIAgBPAAAAAOACAPAEAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAADAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAIAAACAAAAAAAAAAAAAAACCAAAEgAAAAAAAAAAAAAAC50ZXh0AAAA
>> "%~1" echo FKkCAAAgAAAAqgIAAAIAAAAAAAAAAAAAAAAAACAAAGAucnNyYwAAAPAEAAAA4AIA
>> "%~1" echo AAYAAACsAgAAAAAAAAAAAAAAAABAAABALnJlbG9jAAAMAAAAAAADAAACAAAAsgIA
>> "%~1" echo AAAAAAAAAAAAAAAAQAAAQgAAAAAAAAAAAAAAAAAAAADwyAIAAAAAAEgAAAACAAUA
>> "%~1" echo 6IIAANRFAgABAAAAAQAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAABswAgBEAAAAAQAAEQAAAnQDAAABKAIAAAYAAN4xCgAA
>> "%~1" echo AnQDAAABbwYAAAoAAN4FJgAA3gAAcgEAAHAGbwcAAAooCAAACigNAAAGAADeAAAq
>> "%~1" echo ARwAAAAAEwAQIwAFAQAAAQAAAQAQEQAxDgAAARswBABtAgAAAgAAEQAAKAkAAAoo
>> "%~1" echo CgAACgAA3gUmAADeAAACjmkW/gIW/gETBxEHLQgCFpqAAQAABAKOaRcwDCgLAAAK
>> "%~1" echo bwwAAAorAwIXmgAoDAAABgAUCiA9IgAACysvAAByEQAAcCgNAAAKB3MOAAAKCgZv
>> "%~1" echo DwAACgAHgAMAAATeHiYAFAoA3gAAAAcXWAsHIFEiAAD+Ahb+ARMHEQctwAAGFP4B
>> "%~1" echo Fv4BEwcRBy0iAHIlAABwKBAAAAoAcnMAAHAoDQAABgAoEQAACiY4qQEAABqNAQAA
>> "%~1" echo ARMIEQgWcqEAAHCiEQgXfgMAAASMFQAAAaIRCBhyxQAAcKIRCBl+AgAABKIRCCgS
>> "%~1" echo AAAKDHLXAABwCCgIAAAKKBAAAAoAcgUBAHAoEAAACgByQwEAcH4BAAAEKAgAAAoo
>> "%~1" echo EAAACgByTwEAcH4GAAAEKAgAAAooEAAACgByWQEAcH4DAAAEjBUAAAFyhwEAcCgT
>> "%~1" echo AAAKKA0AAAYAckMBAHB+AQAABCgIAAAKKA0AAAYAAByNDwAAARMJEQkWcosBAHCi
>> "%~1" echo EQkXEgMSBCgPAAAGohEJGHKbAQBwohEJGQkoVAAABqIRCRpymwEAcKIRCRsRBKIR
>> "%~1" echo CSgUAAAKKA0AAAYAAN4FJgAA3gAAcp8BAHByowEAcCgVAAAKG28WAAAKEwcRBy0T
>> "%~1" echo AAAIKBcAAAomAN4FJgAA3gAAACtqAAAGbxgAAAoTBX4JAAAELRMU/gZmAAAGcxkA
>> "%~1" echo AAqACQAABCsAfgkAAAQRBSgaAAAKJgDeNBMGAHLZAQBwEQZvBwAACigIAAAKKBAA
>> "%~1" echo AAoActkBAHARBm8HAAAKKAgAAAooDQAABgAA3gAAABcTByuRKgAAAAFAAAAAAAEA
>> "%~1" echo DxAABQEAAAEAAFQAIXUABwEAAAEAAHYBUccBBQEAAAEAAOkBC/QBBQEAAAEAAP4B
>> "%~1" echo MzECNA4AAAEbMAQAmAMAAAMAABEAAhMJAAIgECcAAG8bAAAKAAIgECcAAG8cAAAK
>> "%~1" echo AAJvHQAACgoGKAkAAApzHgAACgsHbx8AAAoMCCggAAAKFv4BEwoRCi0F3UsDAAAI
>> "%~1" echo F40dAAABEwsRCxYfIJ0RC28hAAAKDQmOaRj+BBb+ARMKEQotBd0gAwAACRaabyIA
>> "%~1" echo AAoTBAkXmhMFAAdvHwAAChMGABEGKCAAAAoW/gETChEKLeZyoQAAcH4DAAAEjBUA
>> "%~1" echo AAERBSgTAAAKcyMAAAoTBxEHbyQAAApy6QEAcCglAAAKFv4BEwoRCi07ABEHbyYA
>> "%~1" echo AAooXQAABhMKEQotFwAGcgECAHAoXAAABihgAAAGAN2WAgAABigDAAAGKGAAAAYA
>> "%~1" echo 3YUCAAARB28kAAAKchMCAHAoJQAAChb+ARMKEQo6ywAAAAARB28mAAAKKF0AAAYT
>> "%~1" echo ChEKLRcABnIBAgBwKFwAAAYoYAAABgDdPgIAABEEcisCAHAoJwAAChb+ARMKEQot
>> "%~1" echo FwAGcjUCAHAoXAAABihgAAAGAN0SAgAAEQdvJgAACnJZAgBwKF4AAAYTCBEIKFgA
>> "%~1" echo AAYsIBEHbyYAAApyZwIAcCheAAAGcncCAHAoJwAAChb+ASsBFwATChEKLRcABnJ/
>> "%~1" echo AgBwKFwAAAYoYAAABgDdtwEAAAYRCBEHbyYAAAooBAAABihgAAAGAN2dAQAAEQdv
>> "%~1" echo JAAACnKXAgBwKCUAAAoW/gETChEKLTsAEQdvJgAACihdAAAGEwoRCi0XAAZyAQIA
>> "%~1" echo cChcAAAGKGAAAAYA3VkBAAAGKAUAAAYoYAAABgDdSAEAABEHbyQAAApyqwIAcCgl
>> "%~1" echo AAAKFv4BEwoRCi1nABEHbyYAAAooXQAABhMKEQotFwAGcgECAHAoXAAABihgAAAG
>> "%~1" echo AN0EAQAAEQRyKwIAcCgnAAAKFv4BEwoRCi0XAAZywwIAcChcAAAGKGAAAAYA3dgA
>> "%~1" echo AAAGKAYAAAYoYAAABgDdxwAAABEHbyQAAApy4wIAcBtvKAAAChb+ARMKEQotQQAR
>> "%~1" echo B28mAAAKKF0AAAYTChEKLR4ABnL3AgBwKAkAAApyAQIAcG8pAAAKKGEAAAYA3nsG
>> "%~1" echo EQdvJAAACigIAAAGAN5rEQdvJAAACnIrAwBwKCUAAAoW/gETChEKLR4ABnJFAwBw
>> "%~1" echo KAkAAApyYQMAcG8pAAAKKGEAAAYA3jMGchYFAHAoCQAACihkAAAGbykAAAooYQAA
>> "%~1" echo BgAA3hQRCRT+ARMKEQotCBEJbyoAAAoA3AAAKkEcAAACAAAABAAAAH0DAACBAwAA
>> "%~1" echo FAAAAAAAAAATMAUAfgQAAAQAABEAKFsAAAYKBnJIBQBwclgFAHB+AwAABIwVAAAB
>> "%~1" echo KCsAAApvLAAACgAGcm4FAHB+AQAABG8sAAAKAAZyfgUAcH4GAAAEbywAAAoAEgES
>> "%~1" echo AigPAAAGDQZyjgUAcAlvLAAACgAGcqYFAHAHKFQAAAZvLAAACgAGcrwFAHAIbywA
>> "%~1" echo AAoABnLGBQBwCXLaBQBwKCUAAAotB3LoBQBwKwVy9AUAcABvLAAACgAJctoFAHAo
>> "%~1" echo JwAAChb+ARMGEQYtTQAcjQ8AAAETBxEHFnL+BQBwohEHFwmiEQcYcpsBAHCiEQcZ
>> "%~1" echo ByhUAAAGohEHGnKbAQBwohEHGwiiEQcoFAAACigNAAAGAAYTBTh1AwAABxeNHQAA
>> "%~1" echo ARMIEQgWHyCdEQhvIQAAChaaEwQGcgoGAHARBG8sAAAKAAZyGAYAcBEEciQGAHAo
>> "%~1" echo EAAABm8sAAAKAAZyRgYAcBEEclYGAHAoEAAABm8sAAAKAAZyiAYAcBEEcpAGAHAo
>> "%~1" echo EAAABm8sAAAKAAZyugYAcBEEctYGAHAoEAAABm8sAAAKAAZyFgcAcBEEcjAHAHAo
>> "%~1" echo EAAABm8sAAAKAAZyYAcAcBEEcmwHAHAoEAAABm8sAAAKAAZyjgcAcBEEcqYHAHAo
>> "%~1" echo EAAABm8sAAAKAAZyxgcAcBEEcuIHAHAoEAAABm8sAAAKAAZyBggAcBEEchIIAHAo
>> "%~1" echo EAAABm8sAAAKAAZyNAgAcBEEcjwIAHAoEAAABhEEcmQIAHAoEAAABigvAAAGbywA
>> "%~1" echo AAoABnJ+CABwEQRyjggAcCgQAAAGbywAAAoABnK2CABwEQRyzggAcCgQAAAGbywA
>> "%~1" echo AAoABnLuCABwEQRyEAkAcCgQAAAGbywAAAoABnJKCQBwEQRyYgkAcCgQAAAGbywA
>> "%~1" echo AAoABnKgCQBwEQRyqAkAcCgQAAAGbywAAAoABnLOCQBwEQQoKgAABm8sAAAKAAZy
>> "%~1" echo 3AkAcBEEcvIJAHByAAoAcCgRAAAGbywAAAoABnIYCgBwEQRy8gkAcHIoCgBwKBEA
>> "%~1" echo AAZvLAAACgAGckoKAHARBHLyCQBwclgKAHAoEQAABm8sAAAKAAZyigoAcBEEcvIJ
>> "%~1" echo AHByngoAcCgRAAAGbywAAAoABnLCCgBwEQRy1goAcHLkCgBwKBEAAAZvLAAACgAG
>> "%~1" echo cgoLAHARBHIkCwBwcjILAHAoEQAABm8sAAAKAAZyTgsAcBEEcvIJAHByYAsAcCgR
>> "%~1" echo AAAGbywAAAoABhEEKBoAAAYABhEEKBsAAAYABhEEKBwAAAYABhEEKB0AAAYABhEE
>> "%~1" echo KB4AAAYABhEEKB8AAAYABhEEKCAAAAYABhEEKCEAAAYAHwyNDwAAARMHEQcWcnQL
>> "%~1" echo AHCiEQcXBnIYBgBwby0AAAqiEQcYco4LAHCiEQcZBnKiCwBwby0AAAqiEQcacrwL
>> "%~1" echo AHCiEQcbBnLMCwBwby0AAAqiEQcccuQLAHCiEQcdBnL0CwBwby0AAAqiEQcecgwM
>> "%~1" echo AHCiEQcfCQZySgoAcG8tAAAKohEHHwpyHgwAcKIRBx8LBnIYCgBwby0AAAqiEQco
>> "%~1" echo FAAACigNAAAGAAYTBSsAEQUqAAAbMAUA+gcAAAUAABEAKFsAAAYKBnJZAgBwAihU
>> "%~1" echo AAAGbywAAAoAKAsAAAYLcjIMAHACKFQAAAZyPgwAcAcoLgAACigNAAAGAAACclAM
>> "%~1" echo AHAoJQAAChb+ARMIEQgtXwAgoA8AABeNDwAAARMJEQkWcmgMAHCiEQkoFQAABiYg
>> "%~1" echo XgEAACgvAAAKACCgDwAAF40PAAABEwkRCRZygAwAcKIRCSgVAAAGJgZymgwAcHKo
>> "%~1" echo DABwbywAAAoAADi4BgAAAAdyxgwAcCglAAAKFv4BEwgRCC0LcsoMAHBzMAAACnoC
>> "%~1" echo cuwMAHAoJQAAChb+ARMIEQgtOwAHKAoAAAYAIPoAAAAoLwAACgAHIKwNAAByAg0A
>> "%~1" echo cCgUAAAGJgZymgwAcHI8DQBwbywAAAoAADhIBgAAAnKGDQBwKCUAAAoW/gETCBEI
>> "%~1" echo LR8ABygJAAAGAAZymgwAcHKcDQBwbywAAAoAADgVBgAAAnKuDQBwKCUAAAoW/gET
>> "%~1" echo CBEILR8ABygJAAAGAAZymgwAcHLEDQBwbywAAAoAADjiBQAAAnJEDgBwKCUAAAoW
>> "%~1" echo /gETCBEILR8ABygKAAAGAAZymgwAcHJgDgBwbywAAAoAADivBQAAAnKGDgBwKCUA
>> "%~1" echo AAoW/gETCBEILR8ABygKAAAGAAZymgwAcHKgDgBwbywAAAoAADh8BQAAAnK0DgBw
>> "%~1" echo KCUAAAoW/gETCBEILR8ABygYAAAGAAZymgwAcHLSDgBwbywAAAoAADhJBQAAAnIC
>> "%~1" echo DwBwKCUAAAoW/gETCBEILSkAByCsDQAAchYPAHAoFAAABiYGcpoMAHByfg8AcG8s
>> "%~1" echo AAAKAAA4DAUAAAJynA8AcCglAAAKFv4BEwgRCC0pAAcgrA0AAHKyDwBwKBQAAAYm
>> "%~1" echo BnKaDABwchwQAHBvLAAACgAAOM8EAAACcjwQAHAoJQAAChb+ARMIEQgtTQAgiBMA
>> "%~1" echo ABqNDwAAARMJEQkWck4QAHCiEQkXB6IRCRhyVBAAcKIRCRlyYBAAcKIRCSgVAAAG
>> "%~1" echo JgZymgwAcHJqEABwbywAAAoAADhuBAAAAnKOEABwKCUAAAoW/gETCBEILVUAByCs
>> "%~1" echo DQAAcqgQAHAoFAAABiYgiBMAABmNDwAAARMJEQkWck4QAHCiEQkXB6IRCRhy9hAA
>> "%~1" echo cKIRCSgVAAAGJgZymgwAcHL+EABwbywAAAoAADgFBAAAAnJcEQBwKCUAAAoW/gET
>> "%~1" echo CBEILSkAByCsDQAAcgINAHAoFAAABiYGcpoMAHBycBEAcG8sAAAKAAA4yAMAAAJy
>> "%~1" echo lhEAcCglAAAKFv4BEwgRCC0pAAcgrA0AAHKsEQBwKBQAAAYmBnKaDABwcugRAHBv
>> "%~1" echo LAAACgAAOIsDAAACciwSAHAoJQAAChb+ARMIEQgtKQAHIKwNAAByQBIAcCgUAAAG
>> "%~1" echo JgZymgwAcHKcEgBwbywAAAoAADhOAwAAAnLWEgBwKCUAAAoW/gETCBEILTAABygW
>> "%~1" echo AAAGAAcgrA0AAHLsEgBwKBQAAAYmBnKaDABwckwTAHBvLAAACgAAOAoDAAACcooT
>> "%~1" echo AHAoJQAAChb+ARMIEQgtKQAHIKwNAABynBMAcCgUAAAGJgZymgwAcHL6EwBwbywA
>> "%~1" echo AAoAADjNAgAAAnI2FABwKCUAAAoW/gETCBEILTAABygWAAAGAAcgrA0AAHJOFABw
>> "%~1" echo KBQAAAYmBnKaDABwcqwUAHBvLAAACgAAOIkCAAACcugUAHAoJQAAChb+ARMIEQgt
>> "%~1" echo KQAHIKwNAAByQBIAcCgUAAAGJgZymgwAcHIKFQBwbywAAAoAADhMAgAAAnJMFQBw
>> "%~1" echo KCUAAAoW/gETCBEILSkAByCsDQAAcpwTAHAoFAAABiYGcpoMAHByaBUAcG8sAAAK
>> "%~1" echo AAA4DwIAAAJyrBUAcCglAAAKFv4BEwgRCC0pAAcgrA0AAHLOFQBwKBQAAAYmBnKa
>> "%~1" echo DABwch4WAHBvLAAACgAAONIBAAACclQWAHAoJQAAChb+ARMIEQgtOgAHIKwNAABy
>> "%~1" echo fBYAcCgUAAAGJgcgrA0AAHIWDwBwKBQAAAYmBnKaDABwcsYWAHBvLAAACgAAOIQB
>> "%~1" echo AAACcggXAHAoJQAAChb+ARMIEQg69QAAAAADciYXAHAoXgAABgwDciwXAHAoXgAA
>> "%~1" echo Bg0DcjQXAHAoXgAABhMECChWAAAGLAgJKFcAAAYrARYAEwgRCC0LckAXAHBzMAAA
>> "%~1" echo CnoJKFkAAAYW/gETCBEILQtyZBcAcHMwAAAKegcoFgAABgAHIKwNAAAcjQ8AAAET
>> "%~1" echo CREJFnKQFwBwohEJFwiiEQkYcpsBAHCiEQkZCaIRCRpymwEAcKIRCRsRBChaAAAG
>> "%~1" echo ohEJKBQAAAooFAAABiYGcpoMAHAbjQ8AAAETCREJFgiiEQkXcqwXAHCiEQkYCaIR
>> "%~1" echo CRlysBcAcKIRCRoRBKIRCSgUAAAKbywAAAoAACt4AnK4FwBwKCUAAAoW/gETCBEI
>> "%~1" echo LVkAA3LaFwBwKF4AAAYTBREFKFcAAAYTCBEILQty5BcAcHMwAAAKegcgrA0AAHL2
>> "%~1" echo FwBwEQUoCAAACigUAAAGJgZymgwAcHIYGABwEQUoCAAACm8sAAAKAAArC3ImGABw
>> "%~1" echo czAAAAp6AHIyGABwAihUAAAGcj4YAHAGcpoMAHBvMQAACi0HcsYMAHArCwZymgwA
>> "%~1" echo cG8tAAAKACguAAAKKA0AAAYAAN5MEwYABnJQGABwcugFAHBvLAAACgAGclYYAHAR
>> "%~1" echo Bm8HAAAKbywAAAoAcmIYAHACKFQAAAZybhgAcBEGbwcAAAooLgAACigNAAAGAADe
>> "%~1" echo AAAGEwcrABEHKgAAQRwAAAAAAAA7AAAAagcAAKUHAABMAAAADgAAARMwAwAvAAAA
>> "%~1" echo BgAAEQAoWwAABgoGcn4FAHB+BgAABG8sAAAKAAZyfhgAcCgOAAAGbywAAAoABgsr
>> "%~1" echo AAcqABswBABEAgAABwAAEQAoWwAABgooMgAACgtyiBgAcCgNAAAGAAASAhIDKA8A
>> "%~1" echo AAYTBBEEctoFAHAoJwAAChb+ARMQERAtBwlzMAAACnoIF40dAAABExERERYfIJ0R
>> "%~1" echo EW8hAAAKFpoTBREFCCgiAAAGEwYoMgAAChMSEhJyrhgAcCgzAAAKEwd+BQAABHLO
>> "%~1" echo GABwEQcoNAAAChMIEQgoNQAACiZy3hgAcBEHchYZAHAoNgAAChMJciIZAHARB3IW
>> "%~1" echo GQBwKDYAAAoTChEIEQkoNwAAChMLEQgRCig3AAAKEwwRCxEGFignAAAGfggAAAQo
>> "%~1" echo OAAACgARDBEGFygnAAAGfggAAAQoOAAACgAoMgAACgcoOQAAChMNBnJWGQBwEQtv
>> "%~1" echo LAAACgAGcm4ZAHARDG8sAAAKAAZygBkAcBEHEQkoBwAABm8sAAAKAAZylhkAcBEH
>> "%~1" echo EQooBwAABm8sAAAKAAZyphkAcBINKDoAAApqExMSEyg7AAAKKDwAAApvLAAACgAG
>> "%~1" echo crwZAHARBnsaAAAEbz0AAAoTFBIUKDsAAAooPgAACm8sAAAKAAZy1hkAcBEGexsA
>> "%~1" echo AARvPwAACiwYcugZAHARBnsbAAAEb0AAAAooQQAACisFcsYMAHAAbywAAAoABnKa
>> "%~1" echo DABwcvAZAHBvLAAACgByGhoAcBELciYaAHARDCguAAAKKA0AAAYAAN5BEw4ABnJQ
>> "%~1" echo GABwcugFAHBvLAAACgAGclYYAHARDm8HAAAKbywAAAoAci4aAHARDm8HAAAKKAgA
>> "%~1" echo AAooDQAABgAA3gAABhMPKwARDypBHAAAAAAAABgAAADiAQAA+gEAAEEAAAAOAAAB
>> "%~1" echo EzADAEoAAAAIAAARAByNDwAAAQsHFnLjAgBwogcXAihCAAAKogcYcocBAHCiBxkD
>> "%~1" echo KEIAAAqiBxpyOhoAcKIHG34CAAAEKEIAAAqiBygUAAAKCisABioAABswBQASAQAA
>> "%~1" echo CQAAEQAAA3LjAgBwb0MAAApvRAAACihFAAAKHy9+RgAACm9HAAAKCgZyShoAcBpv
>> "%~1" echo SAAAChYvGQYfOm9JAAAKFi8OBnIWGQBwG29KAAAKKwEWABMEEQQtIQACcvcCAHAo
>> "%~1" echo CQAACnJQGgBwbykAAAooYQAABgDdmwAAAH4FAAAEcs4YAHAoNwAACihLAAAKCwcG
>> "%~1" echo KDcAAAooSwAACgwIBxtvKAAACiwICChMAAAKKwEWABMEEQQtHgACcvcCAHAoCQAA
>> "%~1" echo CnJeGgBwbykAAAooYQAABgDeQQJyFgUAcAgoTQAACihhAAAGAADeKw0AAnL3AgBw
>> "%~1" echo KAkAAApyahoAcAlvBwAACigIAAAKbykAAAooYQAABgAA3gAAACoAAAEQAAAAAAEA
>> "%~1" echo 4+QAKw4AAAEDMAMAXgAAAAAAAAAAAigWAAAGAAIgrA0AAHJOFABwKBQAAAYmAiCs
>> "%~1" echo DQAAcnoaAHAoFAAABiYCIKwNAABy7BIAcCgUAAAGJgIgrA0AAHLKGgBwKBQAAAYm
>> "%~1" echo AiCsDQAAcrIPAHAoFAAABiYqAAADMAMAVwAAAAAAAAAAAiCsDQAAcpwTAHAoFAAA
>> "%~1" echo BiYCIKwNAAByzhUAcCgUAAAGJgIgrA0AAHJAEgBwKBQAAAYmAiCsDQAAcnwWAHAo
>> "%~1" echo FAAABiYCIKwNAAByFg8AcCgUAAAGJioAEzAEADgAAAAKAAARABIAEgEoDwAABnLa
>> "%~1" echo BQBwKCUAAAotB3LGDABwKxUGF40dAAABDQkWHyCdCW8hAAAKFpoADCsACCobMAQA
>> "%~1" echo 4gAAAAsAABEAAAIoIAAACi0DAisKKAsAAApvDAAACgAKBheNHQAAAQsHFh8inQdv
>> "%~1" echo TgAACgoGKEsAAAoKBihPAAAKDAgtBwYoNQAACiYGgAQAAAQGchQbAHAoNwAACoAF
>> "%~1" echo AAAEfgUAAAQoNQAACiZ+BQAABHIyGwBwKDIAAAoNEgNyrhgAcCgzAAAKckAbAHAo
>> "%~1" echo NgAACig3AAAKgAYAAAR+BgAABHJKGwBwfggAAAQoUAAACgAA3jImACgLAAAKbwwA
>> "%~1" echo AAqABAAABH4EAAAEgAUAAAR+BQAABHJMGwBwKDcAAAqABgAABADeAAAqAAABEAAA
>> "%~1" echo AAABAK2uADIBAAABGzAFAGQAAAAMAAARAAAWCn4HAAAEJQsSAChRAAAKAAB+BgAA
>> "%~1" echo BCgyAAAKDBICcnQbAHAoMwAACnKkGwBwAihSAAAKKC4AAAp+CAAABChQAAAKAADe
>> "%~1" echo EAYW/gENCS0HByhTAAAKANwAAN4FJgAA3gAAKgEcAAACAAQARUkAEAAAAAAAAAEA
>> "%~1" echo XF0ABQEAAAEbMAUArAAAAA0AABEAAH4GAAAEKCAAAAotDH4GAAAEKEwAAAorARYA
>> "%~1" echo EwcRBy0JcqobAHATBt59fgYAAAQoTQAACgogUEYAAAsGjmkHMAMWKwUGjmkHWQAM
>> "%~1" echo KAkAAAoGCAaOaQhZb1QAAAoNCR8Kb0kAAAoTBAgWMQcRBBb+BCsBFwATBxEHLQsJ
>> "%~1" echo EQQXWG9EAAAKDQkoVAAABhMG3hgTBQByvhsAcBEFbwcAAAooCAAAChMG3gAAEQYq
>> "%~1" echo ARAAAAAAAQCPkAAYDgAAARMwBAAWAwAADgAAEQACckobAHBRA3LOGwBwUXJKGwBw
>> "%~1" echo CnJKGwBwC3JKGwBwDHJKGwBwDXJKGwBwEwRyShsAcBMFACC4CwAAGI0PAAABEwsR
>> "%~1" echo CxZyKBwAcKIRCxdyOBwAcKIRCygTAAAGKFUAAAYTDBYTDTiXAQAAEQwRDZoTBgAR
>> "%~1" echo Bm9VAAAKEwcRB29DAAAKLBIRB3I+HABwG28oAAAKFv4BKwEWABMOEQ4tBThYAQAA
>> "%~1" echo EQcYjR0AAAETDxEPFh8gnREPFx8JnREPF29WAAAKEwgRCI5pGP4EFv4BEw4RDi0F
>> "%~1" echo OCMBAAARCBeactoFAHAoJQAAChb+ARMOEQ46nQAAAAAJb0MAAAoW/gEW/gETDhEO
>> "%~1" echo LQMRBw0RB3JOHABwG29IAAAKFi8lEQdyZhwAcBtvSAAAChYvFREHcoQcAHAbb0gA
>> "%~1" echo AAoW/gQW/gErARcAEwkRCSwPEQRvQwAAChb+ARb+ASsBFwATDhEOLQQRBxMEEQks
>> "%~1" echo HREIFpofOm9JAAAKFi8PEQVvQwAAChb+ARb+ASsBFwATDhEOLQQRBxMFK2wRCBea
>> "%~1" echo cqAcAHAoJQAACiwOBm9DAAAKFv4BFv4BKwEXABMOEQ4tBREHCitAEQgXmnK6HABw
>> "%~1" echo KCUAAAosDgdvQwAAChb+ARb+ASsBFwATDhEOLQURBwsrFQhvQwAAChb+ARb+ARMO
>> "%~1" echo EQ4tAxEHDAARDRdYEw0RDREMjmn+BBMOEQ46WP7//xEFb0MAAAoW/gIW/gETDhEO
>> "%~1" echo LRgAAhEFUQNyyhwAcFFy2gUAcBMKONUAAAARBG9DAAAKFv4CFv4BEw4RDi0YAAIR
>> "%~1" echo BFEDcvwcAHBRctoFAHATCjiqAAAACW9DAAAKFv4CFv4BEw4RDi0XAAIJUQNyIh0A
>> "%~1" echo cFFy2gUAcBMKOIEAAAAGb0MAAAoW/gIW/gETDhEOLRQAAgZRA3JyHQBwUXKgHABw
>> "%~1" echo EworWwdvQwAAChb+Ahb+ARMOEQ4tFAACB1EDcq4dAHBRcrocAHATCis1CG9DAAAK
>> "%~1" echo Fv4CFv4BEw4RDi0aAAIIUQNy6h0AcAgoCAAAClFyAB4AcBMKKwlyEB4AcBMKKwAR
>> "%~1" echo CioAABMwBAAhAAAADwAAEQACIMQJAAByGh4AcAMoCAAACigSAAAGKFQAAAYKKwAG
>> "%~1" echo KgAAABMwBgA+AAAAEAAAEQACIMQJAAByLB4AcANymwEAcAQoLgAACigSAAAGKFQA
>> "%~1" echo AAYKBnJIHgBwKCUAAAotAwYrBXJIHgBwAAsrAAcqAAATMAQAMQAAAAgAABEAAxqN
>> "%~1" echo DwAAAQsHFnJOEABwogcXAqIHGHJSHgBwogcZBKIHKBMAAAYoVAAABgorAAYqAAAA
>> "%~1" echo EzADABIAAAAPAAARAH4BAAAEAwIoKwAABgorAAYqAAATMAQAMQAAAAgAABEAAxqN
>> "%~1" echo DwAAAQsHFnJOEABwogcXAqIHGHJSHgBwogcZBKIHKBUAAAYoVAAABgorAAYqAAAA
>> "%~1" echo EzADAIsAAAARAAARAH4BAAAEAwIoLAAABgoGb2kAAAYoVAAABgsGew4AAAQW/gEN
>> "%~1" echo CS0Wcl4eAHADKC0AAAYoCAAACnMwAAAKegZ7DQAABBb+AQ0JLTsajQEAAAETBBEE
>> "%~1" echo FnJyHgBwohEEFwZ7DQAABIwVAAABohEEGHKGHgBwohEEGQeiEQQoEgAACnMwAAAK
>> "%~1" echo egcMKwAIKgATMAQAzQAAABIAABEAAigZAAAGCgYoTAAAChb+AQwILQU4sgAAAHNX
>> "%~1" echo AAAKCwdyjB4AcG9YAAAKJgdysh4AcAIoCAAACm9YAAAKJgdyxh4AcCgyAAAKDRID
>> "%~1" echo ctweAHAoMwAACigIAAAKb1gAAAomBwJy8gkAcHJYCgBwKBcAAAYABwJy8gkAcHKe
>> "%~1" echo CgBwKBcAAAYABwJy1goAcHLkCgBwKBcAAAYABwJyJAsAcHIyCwBwKBcAAAYABgdv
>> "%~1" echo WQAACn4IAAAEKDgAAAoAcgQfAHAGKAgAAAooDQAABgAqAAAAEzAGAGoAAAATAAAR
>> "%~1" echo AAMgrA0AAHIsHgBwBHKbAQBwBSguAAAKKBQAAAYKBnLGDABwKCUAAAoW/gELBy0X
>> "%~1" echo chYfAHAEcqwXAHAFKC4AAApzMAAACnoCBG9aAAAKHyBvWwAACgVvWgAACh8gb1sA
>> "%~1" echo AAoGb1gAAAomKgAAEzAHAHIBAAAUAAARAAIoGQAABgoGKEwAAAoTBBEELRFyKB8A
>> "%~1" echo cAYoCAAACnMwAAAKegAGKAkAAAooXAAAChMFFhMGOAMBAAARBREGmgsAB29VAAAK
>> "%~1" echo DAhvQwAACiwRCHI8HwBwGm8oAAAKFv4BKwEWABMEEQQtBTjJAAAACBeNHQAAARMH
>> "%~1" echo EQcWHyCdEQcZb10AAAoNCY5pGTIUCRaaKFYAAAYsCgkXmihXAAAGKwEWABMEEQQt
>> "%~1" echo BTiKAAAACRiackgeAHAoJQAAChb+ARMEEQQtIwIgrA0AAHJAHwBwCRaacpsBAHAJ
>> "%~1" echo F5ooLgAACigUAAAGJitQAiCsDQAAHI0PAAABEwgRCBZykBcAcKIRCBcJFpqiEQgY
>> "%~1" echo cpsBAHCiEQgZCReaohEIGnKbAQBwohEIGwkYmihaAAAGohEIKBQAAAooFAAABiYA
>> "%~1" echo EQYXWBMGEQYRBY5p/gQTBBEEOuz+//8CIKwNAAByFg8AcCgUAAAGJnJiHwBwBigI
>> "%~1" echo AAAKKA0AAAYAKgAAEzAEAIQAAAAVAAARAAIlLQYmctoFAHAKBnJyHwBwcnYfAHBv
>> "%~1" echo XgAACnKsFwBwcnYfAHBvXgAACnJ6HwBwcnYfAHBvXgAACnKHAQBwcnYfAHBvXgAA
>> "%~1" echo Cgp+BAAABCggAAAKLQd+BAAABCsKKAsAAApvDAAACgALB3J+HwBwBnKmHwBwKDYA
>> "%~1" echo AAooNwAACgwrAAgqEzAEANcAAAAWAAARAAMgxAkAAHKwHwBwKBIAAAYKAnKiCwBw
>> "%~1" echo BnLQHwBwKDMAAAZvLAAACgAGctwfAHAoMwAABgsHIP8BAAAoOwAAChICKF8AAAos
>> "%~1" echo EQgjAAAAAAAAWUD+Ahb+ASsBFwANCS0fCCMAAAAAAAAkQFsTBBIEcvQfAHAoOwAA
>> "%~1" echo CihgAAAKCwJyzAsAcAdvLAAACgACcvwfAHAGchggAHAoMwAABigwAAAGbywAAAoA
>> "%~1" echo AnImIABwBnJCIABwKDMAAAYoMQAABm8sAAAKAAJyUCAAcAYoMgAABm8sAAAKACoA
>> "%~1" echo EzAEAIYAAAAPAAARAAMgiBMAAHJoIABwKBIAAAYKAnL0CwBwBnKEIABwKDQAAAZv
>> "%~1" echo LAAACgACcp4gAHAGcp4gAHAoNAAABm8sAAAKAAJyriAAcAZyriAAcCg0AAAGbywA
>> "%~1" echo AAoAAnLUIABwBnLyIABwKDQAAAZvLAAACgACciwhAHAGckohAHAoNQAABm8sAAAK
>> "%~1" echo ACoAABMwBAC2AQAAFwAAEQACcmghAHByxgwAcG8sAAAKAAJylCEAcHLGDABwbywA
>> "%~1" echo AAoAAnLCIQBwcsYMAHBvLAAACgACcuwhAHByxgwAcG8sAAAKAAJyGCIAcHI2IgBw
>> "%~1" echo bywAAAoAAyCIEwAAckoiAHAoEgAABgpzYQAACgsABihVAAAGEwcWEwg4+AAAABEH
>> "%~1" echo EQiaDAAIb1UAAAoNCXJ8IgBwG29IAAAKFjIUCXKOIgBwG29IAAAKFv4EFv4BKwEW
>> "%~1" echo ABMJEQktBTi0AAAACXKaIgBwKDYAAAYTBAlypCIAcCg2AAAGEwUJcrQiAHAoNgAA
>> "%~1" echo BhMGEQRywiIAcBtvFgAAChb+ARMJEQktHgACcmghAHARBW8sAAAKAAJywiEAcBEG
>> "%~1" echo bywAAAoAABEEcswiAHAbbxYAAAoW/gETCREJLR4AAnKUIQBwEQVvLAAACgACcuwh
>> "%~1" echo AHARBm8sAAAKAAAHCW9DAAAKIIwAAAAwAwkrDAkWIIwAAABvYgAACgBvYwAACgAA
>> "%~1" echo EQgXWBMIEQgRB45p/gQTCREJOvf+//8Hbz8AAAoW/gIW/gETCREJLRwCchgiAHBy
>> "%~1" echo 6BkAcAdvQAAACihBAAAKbywAAAoAKgAAEzAGAHIBAAAYAAARAAJy2CIAcHLGDABw
>> "%~1" echo bywAAAoAAnLoIgBwcsYMAHBvLAAACgADIKwNAABy9iIAcCgSAAAGCgAGKFUAAAYT
>> "%~1" echo BxYTCDinAAAAEQcRCJoLAAdvVQAACgwIb0MAAAosEQhyEiMAcBtvKAAAChb+ASsB
>> "%~1" echo FgATCREJLQIrcAgYjR0AAAETChEKFh8gnREKFx8JnREKF29WAAAKDQmOaRv+BBMJ
>> "%~1" echo EQktRQACctgiAHAbjQ8AAAETCxELFgkYmqIRCxdyJhoAcKIRCxgJF5qiEQsZcigj
>> "%~1" echo AHCiEQsaCRqaohELKBQAAApvLAAACgArGAARCBdYEwgRCBEHjmn+BBMJEQk6SP//
>> "%~1" echo /wMgrA0AAHIyIwBwKBIAAAYTBBEEclYjAHAoOAAABhMFEQRyaiMAcCg4AAAGEwYR
>> "%~1" echo BXLGDABwKCcAAAosEREGcsYMAHAoJwAAChb+ASsBFwATCREJLR8CcugiAHByhiMA
>> "%~1" echo cBEGco4jAHARBSguAAAKbywAAAoAKgAAEzAEAJwAAAAZAAARAAJynCMAcHLGDABw
>> "%~1" echo bywAAAoAAnKwIwBwcsYMAHBvLAAACgByxCMAcAoDIIgTAABy8iMAcAYoCAAACigS
>> "%~1" echo AAAGCwdyFCQAcAZyKCQAcCg2AAAKG29IAAAKFv4EFv4BDQktAis4AnKcIwBwBm8s
>> "%~1" echo AAAKAAdyLCQAcCg3AAAGDAhyxgwAcCgnAAAKFv4BDQktDQJysCMAcAhvLAAACgAq
>> "%~1" echo EzAEAFABAAAaAAARAAJyRiQAcHLGDABwbywAAAoAAyCIEwAAcmQkAHAoEgAABgoG
>> "%~1" echo coQkAHAoNQAABgsHcsYMAHAoJQAAChb+ARMHEQctBTgHAQAAB3KoJABwKDwAAAYM
>> "%~1" echo B3LYJABwKDwAAAYNB3IQJQBwKDwAAAYTBAdyNiUAcHJmJQBwKDsAAAYTBXNhAAAK
>> "%~1" echo EwYIcsYMAHAoJwAAChb+ARMHEQctGBEGCHKbAQBwckobAHBvXgAACm9jAAAKAAly
>> "%~1" echo xgwAcCgnAAAKFv4BEwcRBy0TEQYJcmolAHAoCAAACm9jAAAKABEEcsYMAHAoJwAA
>> "%~1" echo Chb+ARMHEQctFBEGcnAlAHARBCgIAAAKb2MAAAoAEQVyxgwAcCgnAAAKFv4BEwcR
>> "%~1" echo By0KEQYRBW9jAAAKAAJyRiQAcBEGbz8AAAosE3ImGgBwEQZvQAAACihBAAAKKwVy
>> "%~1" echo xgwAcABvLAAACgAqEzAHALkAAAAZAAARAAJygiUAcHLGDABwbywAAAoAAyCIEwAA
>> "%~1" echo cqAlAHAoEgAABgoGcs4lAHAoMwAABgsGcuwlAHAoPQAABgwIcsYMAHAoJQAAChb+
>> "%~1" echo AQ0JLQwGcjAmAHAoPQAABgwHcsYMAHAoJwAACi0QCHLGDABwKCcAAAoW/gErARYA
>> "%~1" echo DQktPAJygiUAcHJuJgBwBwhyxgwAcCgnAAAKLQdyShsAcCsQcn4mAHAIcpYmAHAo
>> "%~1" echo NgAACgAoNgAACm8sAAAKACoAAAATMAQASgEAABoAABEAAnKaJgBwcsYMAHBvLAAA
>> "%~1" echo CgADIHAXAAByuCYAcCgSAAAGCgZy5CYAcCg+AAAGCwZy+CYAcCg+AAAGDAZyDicA
>> "%~1" echo cCg+AAAGDQZyIicAcCg+AAAGEwQGcjonAHAoPgAABhMFc2EAAAoTBghyxgwAcCgn
>> "%~1" echo AAAKFv4BEwcRBy0JEQYIb2MAAAoAB3LGDABwKCcAAAoW/gETBxEHLQkRBgdvYwAA
>> "%~1" echo CgAJcsYMAHAoJwAAChb+ARMHEQctExEGclAnAHAJKAgAAApvYwAACgARBHLGDABw
>> "%~1" echo KCcAAAoW/gETBxEHLRQRBnJiJwBwEQQoCAAACm9jAAAKABEFcsYMAHAoJwAAChb+
>> "%~1" echo ARMHEQctFBEGcmwnAHARBSgIAAAKb2MAAAoAAnKaJgBwEQZvPwAACiwTciYaAHAR
>> "%~1" echo Bm9AAAAKKEEAAAorBXLGDABwAG8sAAAKACoAABMwBwDoAgAAGwAAEQBzbQAABgoG
>> "%~1" echo KDIAAAoMEgJy3B4AcCgzAAAKfRYAAAQGAn0XAAAEBgN9GAAABAZyficAcCCgDwAA
>> "%~1" echo FhiNDwAAAQ0JFnIoHABwogkXcjgcAHCiCSgkAAAGAAZylicAcAIguAsAAHKWJwBw
>> "%~1" echo KCMAAAYABnKcJwBwAiBwFwAAcpwnAHAoIwAABgAGcqwnAHACIHAXAAByzCcAcCgj
>> "%~1" echo AAAGAAZy9icAcAIgcBcAAHIWKABwKCMAAAYABnJAKABwAiBwFwAAcmAoAHAoIwAA
>> "%~1" echo BgAGcoooAHACIIgTAABysB8AcCgjAAAGAAZymigAcAIgWBsAAHJoIABwKCMAAAYA
>> "%~1" echo BnKmKABwAiAoIwAAcmQkAHAoIwAABgAGcvYQAHACIFgbAABytigAcCgjAAAGAAZy
>> "%~1" echo zigAcAIgKCMAAHLYKABwKCMAAAYABnLyKABwAiBAHwAAcgwpAHAoIwAABgAGcjYp
>> "%~1" echo AHACIFgbAABySikAcCgjAAAGAAZyfikAcAIgQB8AAHKMKQBwKCMAAAYABnK2KQBw
>> "%~1" echo AiDgLgAAcrgmAHAoIwAABgAGctIpAHACIFgbAAByoCUAcCgjAAAGAAZy4ikAcAIg
>> "%~1" echo WBsAAHLuKQBwKCMAAAYABnIKKgBwAiDgLgAAchwqAHAoIwAABgAGckoqAHACIEAf
>> "%~1" echo AAByXCoAcCgjAAAGAAZyfioAcAIgQB8AAHKSKgBwKCMAAAYABnLIKgBwAiCIEwAA
>> "%~1" echo cs4qAHAoIwAABgAGcvYqAHACIIgTAAByMiMAcCgjAAAGAAZyBisAcAIgiBMAAHIW
>> "%~1" echo KwBwKCMAAAYABnI6KwBwAiC4CwAAckYrAHAoIwAABgAGclgrAHACIIgTAAByaCsA
>> "%~1" echo cCgjAAAGAAZyeCsAcAIgiBMAAHKKKwBwKCMAAAYABnKcKwBwAiBAHwAAcrorAHAo
>> "%~1" echo IwAABgAGcggsAHACIBAnAAByKCwAcCgjAAAGAAZyXiwAcAIgECcAAHKGLABwKCMA
>> "%~1" echo AAYABigmAAAGAAYLKwAHKhMwBwAtAAAAHAAAEQACAwUWGo0PAAABCgYWck4QAHCi
>> "%~1" echo BhcEogYYclIeAHCiBhkOBKIGKCQAAAYAKgAAABMwBAAWAQAAHQAAEQAoZAAACgp+
>> "%~1" echo AQAABA4EBCgsAAAGCwZvZQAACgBzbAAABgwIA30PAAAECHKqLABwDgQoLQAABigI
>> "%~1" echo AAAKfRAAAAQIB3sLAAAEKFQAAAZ9EQAABAgHewwAAAQoVAAABn0SAAAECAd7DQAA
>> "%~1" echo BH0TAAAECAd7DgAABH0UAAAECAZvZgAACn0VAAAEAnsaAAAECG9nAAAKAAd7DgAA
>> "%~1" echo BBb+AQ0JLRkCexsAAAQDcrQsAHAoCAAACm9jAAAKACtcB3sNAAAELAYFFv4BKwEX
>> "%~1" echo AA0JLSQCexsAAAQDcrwsAHAHb2kAAAYoVAAABig2AAAKb2MAAAoAKyQHew0AAAQW
>> "%~1" echo /gENCS0XAnsbAAAEA3LGLABwKAgAAApvYwAACgAqAAAbMAIAVwAAAB4AABEAAAJ7
>> "%~1" echo GgAABG9oAAAKDCsfEgIoaQAACgoGew8AAAQDKCUAAAoW/gENCS0EBgveJRICKGoA
>> "%~1" echo AAoNCS3W3g8SAv4WBAAAG28qAAAKANwAc2wAAAYLKwAAByoAARAAAAIADgAuPAAP
>> "%~1" echo AAAAABMwBQCUBgAAHwAAEQACexkAAAQKAnKcJwBwKCUAAAZvawAABgsCcoooAHAo
>> "%~1" echo JQAABm9rAAAGDAJymigAcCglAAAGb2sAAAYNAnKmKABwKCUAAAZvawAABhMEAnLS
>> "%~1" echo KQBwKCUAAAZvawAABhMFAnK2KQBwKCUAAAZvawAABhMGAnLOKABwKCUAAAZvawAA
>> "%~1" echo BhMHAnI2KQBwKCUAAAZvawAABhMIAnL2EABwKCUAAAZvawAABhMJAnJ+KQBwKCUA
>> "%~1" echo AAZvawAABhMKAnIKKgBwKCUAAAZvawAABhMLAnJKKgBwKCUAAAZvawAABhMMBnIK
>> "%~1" echo BgBwAnsXAAAEbywAAAoABnKmBQBwAnsYAAAEbywAAAoABnLWLABwAnsWAAAEbywA
>> "%~1" echo AAoABnIYBgBwB3IkBgBwKDkAAAZvLAAACgAGchYHAHAHcjAHAHAoOQAABm8sAAAK
>> "%~1" echo AAZyYAcAcAdybAcAcCg5AAAGbywAAAoABnLmLABwB3KmBwBwKDkAAAZvLAAACgAG
>> "%~1" echo ctoFAHAHcuIHAHAoOQAABm8sAAAKAAZyBggAcAdyEggAcCg5AAAGbywAAAoABnI0
>> "%~1" echo CABwB3I8CABwKDkAAAYHcmQIAHAoOQAABigvAAAGbywAAAoABnJGBgBwB3JWBgBw
>> "%~1" echo KDkAAAZvLAAACgAGcogGAHAHcpAGAHAoOQAABm8sAAAKAAZyugYAcAdy1gYAcCg5
>> "%~1" echo AAAGbywAAAoABnJKCQBwB3JiCQBwKDkAAAZvLAAACgAGcn4IAHAHco4IAHAoOQAA
>> "%~1" echo Bm8sAAAKAAZy7ggAcAdyEAkAcCg5AAAGbywAAAoABnK2CABwB3LOCABwKDkAAAZv
>> "%~1" echo LAAACgAGcvYsAHAHcg4tAHAoOQAABm8sAAAKAAZyoAkAcAdyqAkAcCg5AAAGbywA
>> "%~1" echo AAoABnI4LQBwAnI6KwBwKCUAAAZvawAABig6AAAGbywAAAoABnKiCwBwCHLQHwBw
>> "%~1" echo KDMAAAZyRi0AcCgIAAAKbywAAAoACHLcHwBwKDMAAAYTDRENIP8BAAAoOwAAChIO
>> "%~1" echo KF8AAAosEhEOIwAAAAAAAFlA/gIW/gErARcAEw8RDy0hEQ4jAAAAAAAAJEBbExAS
>> "%~1" echo EHL0HwBwKDsAAAooYAAAChMNBnLMCwBwEQ1yxgwAcCglAAAKLQ4RDXKWJgBwKAgA
>> "%~1" echo AAorBXLGDABwAG8sAAAKAAZyJiAAcAhyQiAAcCgzAAAGKDEAAAZvLAAACgAGclAg
>> "%~1" echo AHAIKDIAAAZvLAAACgAGcvQLAHAJcoQgAHAoNAAABm8sAAAKAAZySgoAcAlyniAA
>> "%~1" echo cCg0AAAGbywAAAoABnJKLQBwCXKuIABwKDQAAAZvLAAACgAGctgiAHACcsgqAHAo
>> "%~1" echo JQAABm9rAAAGKD8AAAZvLAAACgAGcugiAHACcvYqAHAoJQAABm9rAAAGKEAAAAZv
>> "%~1" echo LAAACgAGcl4tAHACcgYrAHAoJQAABm9rAAAGKEEAAAZvLAAACgAGcqYoAHARBChC
>> "%~1" echo AAAGbywAAAoABnJmLQBwEQRyci0AcCg1AAAGcjYlAHByZiUAcCg7AAAGbywAAAoA
>> "%~1" echo BnLSKQBwEQUoQwAABm8sAAAKAAZy9hAAcBEJKEQAAAZvLAAACgAGcs4oAHARBwJy
>> "%~1" echo WCsAcCglAAAGb2sAAAYoRQAABm8sAAAKAAZyNikAcBEIKEYAAAZvLAAACgAGcn4p
>> "%~1" echo AHARChEGKEcAAAZvLAAACgAGcpYtAHARBihIAAAGbywAAAoABnKmLQBwEQZy+CYA
>> "%~1" echo cCg+AAAGbywAAAoABnLCLQBwEQZy5CYAcCg+AAAGbywAAAoABnLcLQBwEQZyDicA
>> "%~1" echo cCg+AAAGbywAAAoABnL0LQBwEQZyIicAcCg+AAAGbywAAAoABnIULgBwEQZyOicA
>> "%~1" echo cCg+AAAGbywAAAoABnIyLgBwEQZyWC4AcCg+AAAGbywAAAoABnJyLgBwEQZyii4A
>> "%~1" echo cCg+AAAGbywAAAoABnKiLgBwEQZywi4AcCg+AAAGbywAAAoABnLaLgBwEQZyAC8A
>> "%~1" echo cCg+AAAGbywAAAoABnIiLwBwEQZyRi8AcBtvSAAAChYvB3LGDABwKwVydi8AcABv
>> "%~1" echo LAAACgAGcgoqAHARCyhKAAAGExESESg7AAAKKD4AAApvLAAACgAGckoqAHARDHKu
>> "%~1" echo LwBwKEsAAAYTERIRKDsAAAooPgAACm8sAAAKAAZywC8AcAJynCsAcCglAAAGb2sA
>> "%~1" echo AAYoSQAABm8sAAAKAAZy1hkAcAJ7GwAABG8/AAAKLBdy6BkAcAJ7GwAABG9AAAAK
>> "%~1" echo KEEAAAorBXLGDABwAG8sAAAKACoTMAcA3wYAACAAABEAAnsZAAAECgMtB3LGLwBw
>> "%~1" echo KwVy+C8AcAALAy0HciowAHArBXJEMABwAAxyWjAAcCgyAAAKEwcSB3JmMABwKDsA
>> "%~1" echo AAooawAACigIAAAKDQZyCgYAcChNAAAGAyhPAAAGEwRzVwAAChMFEQVyhjAAcAco
>> "%~1" echo TgAABnKZMQBwKDYAAApvWAAACiYRBXKrMQBwb1gAAAomEQUbjQ8AAAETCBEIFnK7
>> "%~1" echo MQBwohEIFwMtB3JwPwBwKwVyiD8AcACiEQgYcpw/AHCiEQgZAy0HcnA/AHArBXKI
>> "%~1" echo PwBwAKIRCBpyrD8AcKIRCCgUAAAKb1gAAAomEQVytVoAcG9YAAAKJhEFcuFaAHBv
>> "%~1" echo WAAACiYRBXJ8XABwb1gAAAomEQVyyFwAcG9YAAAKJhEFHwuNDwAAARMIEQgWcote
>> "%~1" echo AHCiEQgXCShOAAAGohEIGHIJXwBwohEIGQZy1iwAcChNAAAGKE4AAAaiEQgacnNf
>> "%~1" echo AHCiEQgbCChOAAAGohEIHHIAYABwohEIHQZybgUAcChNAAAGKE4AAAaiEQgecoVg
>> "%~1" echo AHCiEQgfCQZybgUAcChNAAAGKFAAAAYoTgAABqIRCB8KcotgAHCiEQgoFAAACm9Y
>> "%~1" echo AAAKJhEFHxGNDwAAARMIEQgWcsNgAHCiEQgXBnIYBgBwKE0AAAYoTgAABqIRCBhy
>> "%~1" echo hGEAcKIRCBkGchYHAHAoTQAABihOAAAGohEIGnImGgBwohEIGwZy5iwAcChNAAAG
>> "%~1" echo KE4AAAaiEQgcciYaAHCiEQgdBnLaBQBwKE0AAAYoTgAABqIRCB5yuGEAcKIRCB8J
>> "%~1" echo EQQoTgAABqIRCB8KciBiAHCiEQgfCwZyRgYAcChNAAAGKE4AAAaiEQgfDHJWYgBw
>> "%~1" echo ohEIHw0GcogGAHAoTQAABihOAAAGohEIHw5yIGIAcKIRCB8PBnI0CABwKE0AAAYo
>> "%~1" echo TgAABqIRCB8QcmZiAHCiEQgoFAAACm9YAAAKJhEFG40PAAABEwgRCBZymmIAcKIR
>> "%~1" echo CBcDLQdyJ2MAcCsFcjNjAHAAKE4AAAaiEQgYcoRhAHCiEQgZAy0Hcj9jAHArBXJz
>> "%~1" echo YwBwAChOAAAGohEIGnLxYwBwohEIKBQAAApvWAAACiYRBR8LjQ8AAAETCBEIFnJI
>> "%~1" echo ZQBwohEIFwZyogsAcChNAAAGKE4AAAaiEQgYciYaAHCiEQgZBnLMCwBwKE0AAAYo
>> "%~1" echo TgAABqIRCBpy12UAcKIRCBsGcqYoAHAoTQAABihOAAAGohEIHHI9ZgBwohEIHQZy
>> "%~1" echo 2CIAcChNAAAGKE4AAAaiEQgecqNmAHCiEQgfCQZyli0AcChNAAAGKE4AAAaiEQgf
>> "%~1" echo CnIJZwBwohEIKBQAAApvWAAACiYRBXIzZwBwBgMfCo0PAAABEwgRCBZyPWcAcKIR
>> "%~1" echo CBdyf2cAcKIRCBhyw2cAcKIRCBlyE2gAcKIRCBpyR2gAcKIRCBtye2gAcKIRCBxy
>> "%~1" echo tWgAcKIRCB1y8WgAcKIRCB5yJWkAcKIRCB8Jck9pAHCiEQgoKAAABgARBXKFaQBw
>> "%~1" echo BgMfCY0PAAABEwgRCBZykWkAcKIRCBdywWkAcKIRCBhy4WkAcKIRCBlyG2oAcKIR
>> "%~1" echo CBpyW2oAcKIRCBtyjWoAcKIRCBxy12oAcKIRCB1yDWsAcKIRCB5yTWsAcKIRCCgo
>> "%~1" echo AAAGABEFcntrAHAGAx8RjQ8AAAETCBEIFnKdawBwohEIF3LXawBwohEIGHINbABw
>> "%~1" echo ohEIGXJNbABwohEIGnKPbABwohEIG3LVbABwohEIHHITbQBwohEIHXJRbQBwohEI
>> "%~1" echo HnKbbQBwohEIHwly5W0AcKIRCB8KcituAHCiEQgfC3JTbgBwohEIHwxyl24AcKIR
>> "%~1" echo CB8NcuVuAHCiEQgfDnJLbwBwohEIHw9ybW8AcKIRCB8Qcp1vAHCiEQgoKAAABgAR
>> "%~1" echo BXLJbwBwBgMfCo0PAAABEwgRCBZy/W8AcKIRCBdyXXAAcKIRCBhyuXAAcKIRCBly
>> "%~1" echo I3EAcKIRCBpyiXEAcKIRCBty63EAcKIRCBxyWXIAcKIRCB1yt3IAcKIRCB5yHXMA
>> "%~1" echo cKIRCB8JcpNzAHCiEQgoKAAABgARBXILdABwb1gAAAomEQVyinUAcAYDGo0PAAAB
>> "%~1" echo EwgRCBZymHUAcKIRCBdy1HUAcKIRCBhyHnYAcKIRCBlyknYAcKIRCCgoAAAGABEF
>> "%~1" echo AgMoKQAABgARBR2NDwAAARMIEQgWctB2AHCiEQgXBnIKKgBwKE0AAAYoTgAABqIR
>> "%~1" echo CBhysXgAcKIRCBkGckoqAHAoTQAABihOAAAGohEIGnIBeQBwohEIGwMtB3JNeQBw
>> "%~1" echo KwVyXXkAcAAoTgAABqIRCBxyc3kAcKIRCCgUAAAKb1gAAAomEQVyp3kAcG9YAAAK
>> "%~1" echo JhEFb1kAAAoTBisAEQYqABMwBAAKAQAAIQAAEQACct95AHADKE4AAAZyG3oAcCg2
>> "%~1" echo AAAKb1gAAAomAA4EEwYWEwc4wgAAABEGEQeaCgAGF40dAAABEwgRCBYffJ0RCBlv
>> "%~1" echo XQAACgsHFpoMB45pFzADCCsDBxeaAA0HjmkYMAdy4HoAcCsDBxiaABMEBAgoTQAA
>> "%~1" echo BhMFBRb+ARMJEQktChEFFyhPAAAGEwUCHY0PAAABEwoRChZy6HoAcKIRChcJKE4A
>> "%~1" echo AAaiEQoYcvp6AHCiEQoZEQUoTgAABqIRChpy+noAcKIRChsRBChOAAAGohEKHHIO
>> "%~1" echo ewBwohEKKBQAAApvWAAACiYAEQcXWBMHEQcRBo5p/gQTCREJOi3///8CciR7AHBv
>> "%~1" echo WAAACiYqAAAbMAUAZQEAACIAABEAAnJaewBwb1gAAAomAAN7GgAABG9oAAAKDDgZ
>> "%~1" echo AQAAEgIoaQAACgoABCwWBnsPAAAEcr57AHAbb0gAAAoW/gQrARcADQktBTjsAAAA
>> "%~1" echo Bm9rAAAGCwQW/gENCS0IBwMoUgAABgsHb0MAAAogYOoAAP4CFv4BDQktFwcWIGDq
>> "%~1" echo AABvYgAACnLMewBwKAgAAAoLAh8KjQ8AAAETBBEEFnL+ewBwohEEFwZ7DwAABChO
>> "%~1" echo AAAGohEEGHIkfABwohEEGQZ8FQAABCg7AAAKKDwAAAooTgAABqIRBBpyLHwAcKIR
>> "%~1" echo BBsGfBMAAAQoOwAACig+AAAKKE4AAAaiEQQcBnsUAAAELQdyShsAcCsFckJ8AHAA
>> "%~1" echo ohEEHXJYfABwohEEHgcoTgAABqIRBB8Jcnh8AHCiEQQoFAAACm9YAAAKJgASAihq
>> "%~1" echo AAAKDQk62f7//94PEgL+FgQAABtvKgAACgDcAAJymnwAcG9YAAAKJioAAABBHAAA
>> "%~1" echo AgAAABoAAAAuAQAASAEAAA8AAAAAAAAAEzADANsAAAAjAAARAAIgxAkAAHKwfABw
>> "%~1" echo KBIAAAYKBnLGDABwKCcAAAosEAZy6nwAcCgnAAAKFv4BKwEXABMHEQctCAYTBjiY
>> "%~1" echo AAAAAAIgxAkAAHL6fABwKBIAAAYoVQAABhMIFhMJK2QRCBEJmgsAB29VAAAKDAhy
>> "%~1" echo MH0AcG9sAAAKDQkW/gQTBxEHLTkACAkbWG9EAAAKb1UAAAoTBBEEHy9vSQAAChMF
>> "%~1" echo EQUW/gIW/gETBxEHLQ4RBBYRBW9iAAAKEwbeHwAAEQkXWBMJEQkRCI5p/gQTBxEH
>> "%~1" echo LY5yxgwAcBMGKwAAEQYqABMwAwAYAAAADwAAEQACAwQoLAAABm9pAAAGKFQAAAYK
>> "%~1" echo KwAGKh4CKG0AAAoqHgIobQAACioLMAIALAAAAAAAAAAAAAJ7HQAABHscAAAEAnse
>> "%~1" echo AAAEb24AAApvbwAACn0LAAAEAN4FJgAA3gAAKgEQAAAAAAEAJCUABQEAAAELMAIA
>> "%~1" echo LAAAAAAAAAAAAAJ7HQAABHscAAAEAnseAAAEb3AAAApvbwAACn0MAAAEAN4FJgAA
>> "%~1" echo 3gAAKgEQAAAAAAEAJCUABQEAAAEbMAIAPAEAACQAABFzbgAABhMFABEFc2oAAAZ9
>> "%~1" echo HAAABHNvAAAGDQkRBX0dAAAEAHNxAAAKCgYCb3IAAAoABgMoLQAABm9zAAAKAAYW
>> "%~1" echo b3QAAAoABhdvdQAACgAGF292AAAKAAYXb3cAAAoACQYoeAAACn0eAAAECf4GcAAA
>> "%~1" echo BnN5AAAKc3oAAAoLCf4GcQAABnN5AAAKc3oAAAoMB297AAAKAAhvewAACgAJex4A
>> "%~1" echo AAQEb3wAAAoTBxEHLS8AEQV7HAAABBd9DgAABAAJex4AAARvfQAACgAA3gUmAADe
>> "%~1" echo AAARBXscAAAEEwbeWxEFexwAAAQJex4AAARvfgAACn0NAAAEByDoAwAAb38AAAom
>> "%~1" echo CCDoAwAAb38AAAomEQV7HAAABBMG3iETBAARBXscAAAEEQRvBwAACn0MAAAEEQV7
>> "%~1" echo HAAABBMG3gAAEQYqQTQAAAAAAAC8AAAAEAAAAMwAAAAFAAAAAQAAAQAAAAAUAAAA
>> "%~1" echo AwEAABcBAAAhAAAADgAAARMwAwBJAAAAJQAAEQBzVwAACgoWCyspAAcW/gIW/gEN
>> "%~1" echo CS0JBh8gb1sAAAomBgIHmiguAAAGb1oAAAomAAcXWAsHAo5p/gQNCS3NBm9ZAAAK
>> "%~1" echo DCsACCoAAAAgAAkAIgAmAHwAPAA+AF4AEzAEAF0AAAATAAARAAIU/gEW/gELBy0I
>> "%~1" echo cjx9AHAKK0cCHo0dAAABJdAfAAAEKIAAAApvgQAAChb+BBb+AQsHLQQCCisickJ9
>> "%~1" echo AHACckJ9AHByRn0AcG9eAAAKckJ9AHAoNgAACgorAAYqAAAAEzADAE4AAAATAAAR
>> "%~1" echo AAIoVAAABhAAAyhUAAAGEAECcsYMAHAoJQAAChb+AQsHLQQDCislA3LGDABwKCUA
>> "%~1" echo AAoW/gELBy0EAgorDwJymwEAcAMoNgAACgorAAYqAAATMAIAawAAABMAABEAAnJM
>> "%~1" echo fQBwKCUAAAoW/gELBy0IclB9AHAKK04Cclh9AHAoJQAACi0QAnJcfQBwKCUAAAoW
>> "%~1" echo /gErARYACwctCHJgfQBwCisjAnJofQBwKCUAAAoW/gELBy0Icmx9AHAKKwkCKFQA
>> "%~1" echo AAYKKwAGKgATMAIAjgAAABMAABEAAnJMfQBwKCUAAAoW/gELBy0IcnR9AHAKK3EC
>> "%~1" echo clh9AHAoJQAAChb+AQsHLQhyen0AcAorVwJyXH0AcCglAAAKFv4BCwctCHKAfQBw
>> "%~1" echo Cis9AnJofQBwKCUAAAoW/gELBy0IcoZ9AHAKKyMCcox9AHAoJQAAChb+AQsHLQhy
>> "%~1" echo kH0AcAorCQIoVAAABgorAAYqAAATMAIAdwAAABMAABEAAnKWfQBwKDUAAAZy9AUA
>> "%~1" echo cG+CAAAKFv4BCwctCHKufQBwCitQAnK0fQBwKDUAAAZy9AUAcG+CAAAKFv4BCwct
>> "%~1" echo CHLOfQBwCissAnLWfQBwKDUAAAZy9AUAcG+CAAAKFv4BCwctCHL6fQBwCisIcgB+
>> "%~1" echo AHAKKwAGKgATMAMAawAAACYAABEAAAIoVQAABg0WEwQrRQkRBJoKAAZvVQAACgsH
>> "%~1" echo A3JyHwBwKAgAAAobbygAAAoW/gETBREFLRYHA29DAAAKF1hvRAAACihUAAAGDN4c
>> "%~1" echo ABEEF1gTBBEECY5p/gQTBREFLa5yxgwAcAwrAAAIKgATMAMAkwAAACcAABEAAAIo
>> "%~1" echo VQAABhMGFhMHK2kRBhEHmgoABm9VAAAKCwcDcgh+AHAoCAAAChpvSAAACgwIFv4E
>> "%~1" echo EwgRCC03AAcIA29DAAAKWBdYb0QAAAoNCR8sb0kAAAoTBBEEFi8DCSsJCRYRBG9i
>> "%~1" echo AAAKAChUAAAGEwXeHgARBxdYEwcRBxEGjmn+BBMIEQgtiXLGDABwEwUrAAARBSoA
>> "%~1" echo EzADAFQAAAAmAAARAAACKFUAAAYNFhMEKy4JEQSaCgAGb1UAAAoLBwMbb0gAAAoW
>> "%~1" echo /gQTBREFLQkHKFQAAAYM3hwAEQQXWBMEEQQJjmn+BBMFEQUtxXLGDABwDCsAAAgq
>> "%~1" echo EzADAGUAAAAoAAARAANych8AcCgIAAAKCgIGG29IAAAKCwcW/gQW/gETBREFLQly
>> "%~1" echo xgwAcBMEKzYCBwZvQwAAClhvRAAACm9VAAAKDAgfLG9JAAAKDQkWLwMIKwgIFglv
>> "%~1" echo YgAACgAoVAAABhMEKwARBCoAAAATMAMAZgAAACkAABEAAAIoVQAABhMEFhMFKz4R
>> "%~1" echo BBEFmgoABm9VAAAKCwcDG29IAAAKDAgW/gQTBhEGLRYHCANvQwAAClhvRAAACihU
>> "%~1" echo AAAGDd4dABEFF1gTBREFEQSOaf4EEwYRBi20csYMAHANKwAACSoAABMwBADGAAAA
>> "%~1" echo KgAAEQAAAihVAAAGEwUWEwY4lgAAABEFEQaaCgAGb1UAAAoLBwMbbygAAAoTBxEH
>> "%~1" echo LQIrcgcYjR0AAAETCBEIFh8gnREIFx8JnREIF29WAAAKDAiOaRgyGQgXmiD/AQAA
>> "%~1" echo KDsAAAoSAyhfAAAKFv4BKwEXABMHEQctLAkjAAAAAAAAMEFbEwkSCXL0HwBwKDsA
>> "%~1" echo AAooYAAACnIMfgBwKAgAAAoTBN4hABEGF1gTBhEGEQWOaf4EEwcRBzpZ////csYM
>> "%~1" echo AHATBCsAABEEKgAAEzAEAL8AAAArAAARAAACKFUAAAYTBBYTBTiRAAAAEQQRBZoK
>> "%~1" echo AAZvVQAACgtyFH4AcANyGH4AcCg2AAAKDAcIGm8oAAAKFv4BEwYRBi0pBwhvQwAA
>> "%~1" echo Cm9EAAAKF40dAAABEwcRBxYfXZ0RB2+DAAAKKFQAAAYN3lEHA3IIfgBwKAgAAAoa
>> "%~1" echo bygAAAoW/gETBhEGLRYHA29DAAAKF1hvRAAACihUAAAGDd4gABEFF1gTBREFEQSO
>> "%~1" echo af4EEwYRBjpe////csYMAHANKwAACSoAEzACAFIAAAAmAAARAAACKFUAAAYNFhME
>> "%~1" echo KywJEQSaCgAGKFQAAAYLB3LGDABwKCcAAAoW/gETBREFLQQHDN4cABEEF1gTBBEE
>> "%~1" echo CY5p/gQTBREFLcdyxgwAcAwrAAAIKgAAEzAEAGcAAAAsAAARAAIlLQYmckobAHAD
>> "%~1" echo G29IAAAKCgYW/gQW/gENCS0IcsYMAHAMKz8GA29DAAAKWAoCBAYbb4QAAAoLBxb+
>> "%~1" echo BBb+AQ0JLQ8CBm9EAAAKKFQAAAYMKxICBgcGWW9iAAAKKFQAAAYMKwAIKgATMAMA
>> "%~1" echo TAAAAC0AABEAAiUtBiZyShsAcAMXKIUAAAoKBm+GAAAKLA4Gb4cAAApviAAAChcw
>> "%~1" echo B3LGDABwKxYGb4cAAAoXb4kAAApvigAACihUAAAGAAsrAAcqEzACAA0AAAAPAAAR
>> "%~1" echo AAIDKDwAAAYKKwAGKgAAABMwBACwAAAALgAAEQACJS0GJnJKGwBwckZ9AHADKIsA
>> "%~1" echo AApyIn4AcCg2AAAKFyiFAAAKCgZvhgAAChb+AQwILRkGb4cAAAoXb4kAAApvigAA
>> "%~1" echo CihUAAAGCythAiUtBiZyShsAcHJGfQBwAyiLAAAKck5+AHAoNgAAChcohQAACgoG
>> "%~1" echo b4YAAAotB3LGDABwKygGb4cAAAoXb4kAAApvigAACheNHQAAAQ0JFh8inQlvTgAA
>> "%~1" echo CihUAAAGAAsrAAcqEzAEAPwAAAAvAAARAAACKFUAAAYTBBYTBTjOAAAAEQQRBZoK
>> "%~1" echo AAZvVQAACgsHb0MAAAosEQdyEiMAcBtvKAAAChb+ASsBFgATBhEGLQU4lAAAAAcY
>> "%~1" echo jR0AAAETBxEHFh8gnREHFx8JnREHF29WAAAKDAiOaRwyLggIjmkXWZpydn4AcCgl
>> "%~1" echo AAAKLRcICI5pF1macoJ+AHAbb0gAAAoW/gQrARYAKwEXABMGEQYtORuNDwAAARMI
>> "%~1" echo EQgWCBiaohEIF3ImGgBwohEIGAgXmqIRCBlylH4AcKIRCBoIGpqiEQgoFAAACg3e
>> "%~1" echo IAARBRdYEwURBREEjmn+BBMGEQY6If///3LGDABwDSsAAAkqEzAEAFoAAAAZAAAR
>> "%~1" echo AAJyViMAcCg4AAAGCgJyaiMAcCg4AAAGCwZyxgwAcCglAAAKLBAHcsYMAHAoJQAA
>> "%~1" echo Chb+ASsBFwANCS0IcsYMAHAMKxRyhiMAcAdyjiMAcAYoLgAACgwrAAgqAAATMAMA
>> "%~1" echo VgAAADAAABEAAnKifgBwKEsAAAYKAnK2fgBwKDwAAAYLBi0QB3LGDABwKCUAAAoW
>> "%~1" echo /gErARcADQktCHLGDABwDCsaEgAoOwAACig+AAAKcvZ+AHAHKDYAAAoMKwAIKgAA
>> "%~1" echo EzAEAB8BAAAxAAARAAJyhCQAcCg1AAAGCgZyqCQAcCg8AAAGCwZy2CQAcCg8AAAG
>> "%~1" echo DAZyECUAcCg8AAAGDQZyCn8AcChMAAAGEwcSByg7AAAKKD4AAAoTBHNhAAAKEwUH
>> "%~1" echo csYMAHAoJwAAChb+ARMIEQgtGBEFB3KbAQBwckobAHBvXgAACm9jAAAKAAhyxgwA
>> "%~1" echo cCgnAAAKFv4BEwgRCC0TEQUIcmolAHAoCAAACm9jAAAKAAlyxgwAcCgnAAAKFv4B
>> "%~1" echo EwgRCC0TEQVycCUAcAkoCAAACm9jAAAKABEEcix/AHAoJwAAChb+ARMIEQgtFBEF
>> "%~1" echo EQRyMH8AcCgIAAAKb2MAAAoAEQVvPwAACiwTciYaAHARBW9AAAAKKEEAAAorBXLG
>> "%~1" echo DABwABMGKwARBioAEzAEAMkAAAAyAAARAAJyziUAcCgzAAAGCgJyPn8AcCgzAAAG
>> "%~1" echo CwJy7CUAcCg9AAAGDHNhAAAKDQZyxgwAcCgnAAAKFv4BEwURBS0SCXJuJgBwBigI
>> "%~1" echo AAAKb2MAAAoAB3LGDABwKCcAAAoW/gETBREFLRIJclJ/AHAHKAgAAApvYwAACgAI
>> "%~1" echo csYMAHAoJwAAChb+ARMFEQUtFwlyXH8AcAhyliYAcCg2AAAKb2MAAAoACW8/AAAK
>> "%~1" echo LBJyJhoAcAlvQAAACihBAAAKKwVyxgwAcAATBCsAEQQqAAAAEzADALoAAAAyAAAR
>> "%~1" echo AAJybn8AcCg8AAAGCgJylH8AcCg8AAAGCwJyvH8AcCg8AAAGDHNhAAAKDQZyxgwA
>> "%~1" echo cCgnAAAKFv4BEwURBS0SCXL2fwBwBigIAAAKb2MAAAoAB3LGDABwKCcAAAoW/gET
>> "%~1" echo BREFLRIJcgyAAHAHKAgAAApvYwAACgAIcsYMAHAoJwAAChb+ARMFEQUtCAkIb2MA
>> "%~1" echo AAoACW8/AAAKLBJyJhoAcAlvQAAACihBAAAKKwVyxgwAcAATBCsAEQQqAAATMAMA
>> "%~1" echo MwEAADMAABEAAnIkgABwKDwAAAYKAnJigABwKDwAAAYLAnKOgABwKDwAAAYMAnK8
>> "%~1" echo gABwKDwAAAYNA3LigABwKDwAAAYTBHNhAAAKEwURBHLGDABwKCcAAAoW/gETBxEH
>> "%~1" echo LRQRBXIygQBwEQQoCAAACm9jAAAKAAZyxgwAcCgnAAAKFv4BEwcRBy0TEQVyOoEA
>> "%~1" echo cAYoCAAACm9jAAAKAAdyxgwAcCgnAAAKFv4BEwcRBy0TEQUHck6BAHAoCAAACm9j
>> "%~1" echo AAAKAAhyxgwAcCgnAAAKFv4BEwcRBy0TEQUIclaBAHAoCAAACm9jAAAKAAlyxgwA
>> "%~1" echo cCgnAAAKFv4BEwcRBy0TEQVyYIEAcAkoCAAACm9jAAAKABEFbz8AAAosE3ImGgBw
>> "%~1" echo EQVvQAAACihBAAAKKwVyxgwAcAATBisAEQYqABMwBABgAAAAGQAAEQACcmyBAHAo
>> "%~1" echo PAAABgoCcpSBAHAoPAAABgsGcsYMAHAoJQAACiwQB3LGDABwKCUAAAoW/gErARcA
>> "%~1" echo DQktDgJyuoEAcCg1AAAGDCsUctyBAHAGciYaAHAHKC4AAAoMKwAIKhMwBADnAAAA
>> "%~1" echo NAAAEQACcu6BAHAoTAAABgoDck6CAHAoTAAABgsDcniCAHAoTAAABgwDcqSCAHAo
>> "%~1" echo TAAABg1zYQAAChMEBhb+Ahb+ARMGEQYtGBEEBowVAAABctCCAHAoKwAACm9jAAAK
>> "%~1" echo AAcIWAlYFv4CFv4BEwYRBi1QEQQcjQEAAAETBxEHFnLwggBwohEHFweMFQAAAaIR
>> "%~1" echo BxhyFoMAcKIRBxkIjBUAAAGiEQcaciyDAHCiEQcbCYwVAAABohEHKBIAAApvYwAA
>> "%~1" echo CgARBG8/AAAKLBNyJhoAcBEEb0AAAAooQQAACisFcsYMAHAAEwUrABEFKgATMAMA
>> "%~1" echo HwEAADMAABEAAnL4JgBwKD4AAAYKAnLkJgBwKD4AAAYLAnIOJwBwKD4AAAYMAnIi
>> "%~1" echo JwBwKD4AAAYNAnI6JwBwKD4AAAYTBHNhAAAKEwUGcsYMAHAoJwAAChb+ARMHEQct
>> "%~1" echo CREFBm9jAAAKAAdyxgwAcCgnAAAKFv4BEwcRBy0JEQUHb2MAAAoACHLGDABwKCcA
>> "%~1" echo AAoW/gETBxEHLRMRBXJQJwBwCCgIAAAKb2MAAAoACXLGDABwKCcAAAoW/gETBxEH
>> "%~1" echo LRMRBXJiJwBwCSgIAAAKb2MAAAoAEQRyxgwAcCgnAAAKFv4BEwcRBy0UEQVybCcA
>> "%~1" echo cBEEKAgAAApvYwAACgARBW8/AAAKLBNyJhoAcBEFb0AAAAooQQAACisFcsYMAHAA
>> "%~1" echo EwYrABEGKgATMAMAWgAAADUAABEAAnJCgwBwG29IAAAKFv4EFv4BDAgtCHLGDABw
>> "%~1" echo Cys5AnIsJABwKDcAAAYKcsQjAHAGcsYMAHAoJQAACi0NciYaAHAGKAgAAAorBXJK
>> "%~1" echo GwBwACgIAAAKCysAByoAABMwAwBMAAAANgAAEQAWCgACKFUAAAYNFhMEKykJEQSa
>> "%~1" echo CwdvVQAACnKEgwBwG28oAAAKFv4BEwURBS0EBhdYChEEF1gTBBEECY5p/gQTBREF
>> "%~1" echo LcoGDCsACCoTMAMASAAAADYAABEAFgoAAihVAAAGDRYTBCslCREEmgsHb1UAAAoD
>> "%~1" echo G28oAAAKFv4BEwURBS0EBhdYChEEF1gTBBEECY5p/gQTBREFLc4GDCsACCoTMAMA
>> "%~1" echo HAAAADcAABEAAiUtBiZyShsAcAMXKIwAAApvjQAACgorAAYqEzACACMAAAAPAAAR
>> "%~1" echo AAIDbzEAAAotB3LGDABwKwwCA28tAAAKKFQAAAYACisABioAEzABABEAAAAPAAAR
>> "%~1" echo AAIoVAAABiiOAAAKCisABioAAAATMAEAGAAAAA8AABEAAy0IAihUAAAGKwYCKFEA
>> "%~1" echo AAYACisABioTMAMArwAAADUAABEAAihUAAAGCgZyxgwAcCglAAAKFv4BDAgtBwYL
>> "%~1" echo OIwAAAAGcpaDAHAbb0gAAAoW/gQMCC0IcsaDAHALK3EGcv6DAHAbb0gAAAoWMhEG
>> "%~1" echo cg6EAHAbb0gAAAoW/gQrARcADAgtCHIshABwCytDBnJihABwG29KAAAKLREGcnKE
>> "%~1" echo AHAbb0oAAAoW/gErARYADAgtCHJ6hABwCysWBm9DAAAKHzT+AgwILQQGCysEBgsr
>> "%~1" echo AAcqABMwAgA6AAAANQAAEQACb4oAAAoKBnKYhABwKI8AAAosEAZypIQAcCiPAAAK
>> "%~1" echo Fv4BKwEXAAwILQkGKFMAAAYLKwQGCysAByoAABMwBAA6AAAAEAAAEQACFChSAAAG
>> "%~1" echo CgZysIQAcH4KAAAELRMU/gZnAAAGc5AAAAqACgAABCsAfgoAAAQokQAACgoGCysA
>> "%~1" echo ByoAABMwBADvAAAANQAAEQACKFQAAAYKAywiA3sXAAAEKCAAAAotFQN7FwAABHLG
>> "%~1" echo DABwKCcAAAoW/gErARcADAgtGAYDexcAAAQDexcAAAQoUwAABm9eAAAKCgZy2IQA
>> "%~1" echo cHImhQBwKJIAAAoKBnJKhQBwcoiFAHAokgAACgoGcqCFAHBy5IUAcCiSAAAKCgZy
>> "%~1" echo 9oUAcHJahgBwKJIAAAoKBnJuhgBwcsCGAHAXKJMAAAoKBnLchgBwciqHAHAXKJMA
>> "%~1" echo AAoKBnJwhwBwcpyHAHAXKJMAAAoKBnLKhwBwcgCIAHAXKJMAAAoKBnI0iABwcmKI
>> "%~1" echo AHAXKJMAAAoKBgsrAAcqABMwBQBKAAAAEwAAEQACKCAAAAotDgJvQwAAChz+BBb+
>> "%~1" echo ASsBFgALBy0Ico6IAHAKKyMCFhlvYgAACnKgiABwAgJvQwAAChlZb0QAAAooNgAA
>> "%~1" echo CgorAAYqAAATMAMAQQAAABMAABEAAhT+ARb+AQsHLQhyxgwAcAorKwJyqIgAcHJK
>> "%~1" echo GwBwb14AAApvVQAAChAAAm9DAAAKLAMCKwVyxgwAcAAKKwAGKgAAABMwBAAxAAAA
>> "%~1" echo OAAAEQACJS0GJnJKGwBwcqiIAHByShsAcG9eAAAKF40dAAABCwcWHwqdB28hAAAK
>> "%~1" echo CisABioAAAATMAIALwAAADkAABEAAnLyCQBwKCUAAAotGgJy1goAcCglAAAKLQ0C
>> "%~1" echo ciQLAHAoJQAACisBFwAKKwAGKgATMAIAYQAAADoAABEAAiggAAAKFv4BDAgtBBYL
>> "%~1" echo K0wAAg0WEwQrMgkRBG+UAAAKCgYolQAACi0RBh9fLgwGHy4uBwYfLf4BKwEXAAwI
>> "%~1" echo LQQWC94YEQQXWBMEEQQJb0MAAAr+BAwILcAXCysAAAcqAAAAEzACAIoAAAA5AAAR
>> "%~1" echo AAJyrg0AcCglAAAKLXUCcoYNAHAoJQAACi1oAnI8EABwKCUAAAotWwJyjhAAcCgl
>> "%~1" echo AAAKLU4CcpwPAHAoJQAACi1BAnLWEgBwKCUAAAotNAJyNhQAcCglAAAKLScCcrQO
>> "%~1" echo AHAoJQAACi0aAnIIFwBwKCUAAAotDQJyuBcAcCglAAAKKwEXAAorAAYqAAATMAIA
>> "%~1" echo qgAAABMAABEAAiUtBiZyShsAcG+WAAAKCgZyAAoAcCglAAAKOoIAAAAGcigKAHAo
>> "%~1" echo JQAACi11BnKsiABwKCUAAAotaAZy5ogAcCglAAAKLVsGcgyJAHAoJQAACi1OBnI0
>> "%~1" echo iQBwKCUAAAotQQZyRIkAcCglAAAKLTQGcmaJAHAoJQAACi0nBnJ8iQBwKCUAAAot
>> "%~1" echo GgZyoIkAcCglAAAKLQ0GctCJAHAoJQAACisBFwALKwAHKgAAEzAEAC4AAAAPAAAR
>> "%~1" echo AHIKigBwAiUtBiZyShsAcHIKigBwcg6KAHBvXgAACnIKigBwKDYAAAoKKwAGKgAA
>> "%~1" echo EzADAB4AAAAGAAARAHOXAAAKCgZyUBgAcHL0BQBwbywAAAoABgsrAAcqAAATMAMA
>> "%~1" echo KwAAAAYAABEAKFsAAAYKBnJQGABwcugFAHBvLAAACgAGclYYAHACbywAAAoABgsr
>> "%~1" echo AAcqABMwAgAbAAAAOQAAEQACchiKAHAoXgAABn4CAAAEKCUAAAoKKwAGKgATMAQA
>> "%~1" echo tAAAADsAABEAAnIkigBwb5gAAAoW/gETBREFLQkCF29EAAAKEAAAAheNHQAAARMG
>> "%~1" echo EQYWHyadEQZvIQAAChMHFhMIK10RBxEImgoABh89b0kAAAoLBxYvAwYrCAYWB29i
>> "%~1" echo AAAKAAwHFi8HckobAHArCQYHF1hvRAAACgANCChfAAAGAyglAAAKFv4BEwURBS0K
>> "%~1" echo CShfAAAGEwTeHgARCBdYEwgRCBEHjmn+BBMFEQUtlXJKGwBwEwQrAAARBCoTMAMA
>> "%~1" echo JAAAAA8AABEAAiUtBiZyShsAcHIoigBwcpsBAHBvXgAACihFAAAKCisABip6AAJy
>> "%~1" echo LIoAcCgJAAAKAyhiAAAGbykAAAooYQAABgAqABMwBABbAAAAPAAAEQAbjQEAAAEM
>> "%~1" echo CBZybIoAcKIIFwOiCBhyrIoAcKIIGQSOaYwVAAABoggactKKAHCiCCgSAAAKCiiZ
>> "%~1" echo AAAKBm8pAAAKCwIHFgeOaW+aAAAKAAIEFgSOaW+aAAAKACoAGzACAK4AAAA9AAAR
>> "%~1" echo AHI0iwBwc5sAAAoKFwsAAm+cAAAKEwQrYRIEKJ0AAAoMAAcTBREFLQwGcmYlAHBv
>> "%~1" echo WgAACiYWCwZyQn0AcG9aAAAKEgIongAACihjAAAGb1oAAApyOIsAcG9aAAAKEgIo
>> "%~1" echo nwAACihjAAAGb1oAAApyQn0AcG9aAAAKJgASBCigAAAKEwURBS2S3g8SBP4WBQAA
>> "%~1" echo G28qAAAKANwABnJAiwBwb1oAAApvWQAACg0rAAkqAAABEAAAAgAXAHKJAA8AAAAA
>> "%~1" echo EzADABQBAAA+AAARAHNXAAAKCgACJS0GJnJKGwBwDRYTBDjbAAAACREEb5QAAAoL
>> "%~1" echo AAcfXP4BFv4BEwURBS0RBnJEiwBwb1oAAAomOKsAAAAHHyL+ARb+ARMFEQUtEQZy
>> "%~1" echo Rn0AcG9aAAAKJjiMAAAABx8K/gEW/gETBREFLQ4GckqLAHBvWgAACiYrcAcfDf4B
>> "%~1" echo Fv4BEwURBS0OBnJQiwBwb1oAAAomK1QHHwn+ARb+ARMFEQUtDgZyVosAcG9aAAAK
>> "%~1" echo Jis4Bx8g/gQW/gETBREFLSIGclyLAHBvWgAACgcTBhIGcmKLAHAooQAACm9aAAAK
>> "%~1" echo JisIBgdvWwAACiYAEQQXWBMEEQQJb0MAAAr+BBMFEQU6Ev///wZvWQAACgwrAAgq
>> "%~1" echo EzADACsAAAAQAAARAHJoiwBwCigJAAAKBiiiAAAKb6MAAApyRRsCcH4CAAAEb14A
>> "%~1" echo AAoLKwAHKgATMAIAXwAAAD8AABFyYoQAcIABAAAEKKQAAAoKEgByWRsCcCilAAAK
>> "%~1" echo gAIAAAQgPSIAAIADAAAEckobAHCABAAABHJKGwBwgAUAAARyShsAcIAGAAAEc20A
>> "%~1" echo AAqABwAABBZzpgAACoAIAAAEKh4CKG0AAAoqABMwAgAjAAAADwAAEQACewsAAARv
>> "%~1" echo QwAAChYwCAJ7DAAABCsGAnsLAAAEAAorAAYqsgJyShsAcH0LAAAEAnJKGwBwfQwA
>> "%~1" echo AAQCFX0NAAAEAhZ9DgAABAIobQAACgAqEzACACMAAAAPAAARAAJ7EQAABG9DAAAK
>> "%~1" echo FjAIAnsSAAAEKwYCexEAAAQACisABioAAzACAEoAAAAAAAAAAnJKGwBwfQ8AAAQC
>> "%~1" echo ckobAHB9EAAABAJyShsAcH0RAAAEAnJKGwBwfRIAAAQCFX0TAAAEAhZ9FAAABAIW
>> "%~1" echo an0VAAAEAihtAAAKACoAAAMwAgBKAAAAAAAAAAJyShsAcH0WAAAEAnJKGwBwfRcA
>> "%~1" echo AAQCckobAHB9GAAABAJzlwAACn0ZAAAEAnOnAAAKfRoAAAQCc2EAAAp9GwAABAIo
>> "%~1" echo bQAACgAqAABCU0pCAQABAAAAAAAMAAAAdjQuMC4zMDMxOQAAAAAFAGwAAAB8EgAA
>> "%~1" echo I34AAOgSAABAEAAAI1N0cmluZ3MAAAAAKCMAAGAbAgAjVVMAiD4CABAAAAAjR1VJ
>> "%~1" echo RAAAAJg+AgA8BwAAI0Jsb2IAAAAAAAAAAgAAAVeVoikJAgAAAPolMwAWAAABAAAA
>> "%~1" echo QwAAAAkAAAAfAAAAcQAAAKQAAACnAAAADAAAAAEAAAA/AAAAAgAAAAIAAAACAAAA
>> "%~1" echo BgAAAAEAAAABAAAAAgAAAAYAAAAAAAoAAQAAAAAABgBVAE4ABgCaAI4ACgDFALIA
>> "%~1" echo BgDwANUABgAxAScBBgC6AY4ABgCqBdUABgAxBhIGBgBaBk4ABgA4BxgHBgBYBxgH
>> "%~1" echo BgCUB4MHBgDIBxgHBgDpB04ABgD/B04ABgAWCE4ABgAxCE4ACgBqCF8ICgB6CLIA
>> "%~1" echo BgCWCE4ABgCtCE4ABgCzCE4ABgDWCE4ACgABCe4IBgAZCYMHCgBZCbIABgBxCScB
>> "%~1" echo BgB+CScBBgCgCU4ACgC8CU4ABgAJCk4ABgAvCoMHBgBICk4ABgBiCicBBgBvCicB
>> "%~1" echo BgB5CicBBgCXCicBBgCpCk4ABgDsCtcKBgANC04ABgATC04ABgDWC4MHBgD/C04A
>> "%~1" echo BgAxDE4ABgA4DNcKCgBSDO4IHwCCDAAACgA+De4IBgDGDYMHBgA1Dk4ABgBwDhgH
>> "%~1" echo BgB/Dk4ABgCFDk4ACgDaDrsOCgDgDrsOCgDmDrsOCgDzDrsOCgAFD7sOCgA0ALsO
>> "%~1" echo CgAxD7sOCgBJD18ICgBzD7sOEwCCDAAABgDsD9UABgADEE4ABgAjEE4ABgAwEI4A
>> "%~1" echo AAAAAAEAAAAAAAEAAQAAABAAHAAAAAUAAQABAAMAEAAqAAAABQALAGkAAwAQADQA
>> "%~1" echo AAAFAA8AawADABAAPAAAAAUAFgBtAAMBEACwDAAABQAcAG4AAwEQAMoMAAAFAB0A
>> "%~1" echo bwAAAAAA8A0AAAUAHwByABMBAAA/DgAAyQAgAHIAEQBcAAoAEQBkAAoAEQBqAA0A
>> "%~1" echo EQBvAAoAEQB3AAoAEQB+AAoAMQCGABAAMQCjABMAEQChB3MBEQCCD10GBgBKBQoA
>> "%~1" echo BgAGBQoABgBRBQ0ABgBaBT8BBgBxBQoABgB2BQoABgBKBQoABgAGBQoABgBRBQ0A
>> "%~1" echo BgBaBT8BBgB+BUoBBgCJBQoABgCRBQoABgCYBQoABgCjBU0BBgCxBVUBBgC6BV0B
>> "%~1" echo BgDDDAQFBgDdDAgFBgDtDAwFEwFcDksFvCAAAAAAkQCtABcAAQB4IwAAAACRAM8A
>> "%~1" echo HQACADgnAAAAAJEA/QAjAAMAxCsAAAAAkQAEASwAAwDoMwAAAACRAAsBIwAFACQ0
>> "%~1" echo AAAAAJEAEAEjAAUAkDYAAAAAkQAdATcABQDoNgAAAACRADgBPQAHABg4AAAAAJEA
>> "%~1" echo RAFEAAkAhDgAAAAAkQBOAUQACgDoOAAAAACRAFsBSQALACw5AAAAAJEAaQFEAAsA
>> "%~1" echo LDoAAAAAkQBxAUQADAC4OgAAAACRAHUBSQANAIA7AAAAAJEAgQFNAA0ApD4AAAAA
>> "%~1" echo kQCOATcADwDUPgAAAACRAJMBVQARACA/AAAAAJEAmwFcABQAYD8AAAAAkQCeAWMA
>> "%~1" echo FwCAPwAAAACRAKABXAAZAMA/AAAAAJEApwFjABwAWEAAAAAAkQCtAUQAHgA0QQAA
>> "%~1" echo AACRAMgBagAfAKxBAAAAAJEA2AFEACMALEMAAAAAkQDmAXMAJAC8QwAAAACRAPEB
>> "%~1" echo eAAlAKBEAAAAAJEA/QF4ACcANEUAAAAAkQAHAngAKQD4RgAAAACRABsCeAArAHhI
>> "%~1" echo AAAAAJEAKQJ4AC0AIEkAAAAAkQA8AngALwB8SgAAAACRAEwCeAAxAERLAAAAAJEA
>> "%~1" echo XAJ4ADMAnEwAAAAAkQBsAoMANQCQTwAAAACRAHwCigA3AMxPAAAAAJEAjAKUADwA
>> "%~1" echo 8FAAAAAAkQCXAp8AQQBkUQAAAACRAJsCpwBDAARYAAAAAJEArgKtAEQA8F4AAAAA
>> "%~1" echo kQC+ArQARgAIYAAAAACRAM4CxABLAJhhAAAAAJEA3AJzAE4AgGIAAAAAkQDjAs0A
>> "%~1" echo TwBEYwAAAACRAOcC1QBSAMBkAAAAAJEA8QLeAFUAKGUAAAAAkQD6AnMAVgCUZQAA
>> "%~1" echo AACRAAMDNwBXAPBlAAAAAJEAEANzAFkAaGYAAAAAkQAeA3MAWgAEZwAAAACRACwD
>> "%~1" echo cwBbAIhnAAAAAJEAOAM3AFwAAGgAAAAAkQBDAzcAXgCgaAAAAACRAE8DNwBgAABp
>> "%~1" echo AAAAAJEAWAM3AGIAdGkAAAAAkQBeAzcAZADoaQAAAACRAG8DNwBmALxqAAAAAJEA
>> "%~1" echo dQM3AGgAiGsAAAAAkQB+A3MAagDoawAAAACRAIgDVQBrAFxsAAAAAJEAkAM3AG4A
>> "%~1" echo tGwAAAAAkQCbAzcAcADQbAAAAACRAKYDNwByAIxtAAAAAJEAtQNzAHQAlG4AAAAA
>> "%~1" echo kQDEA3MAdQD8bgAAAACRANIDcwB2AGBvAAAAAJEA3QNzAHcAjHAAAAAAkQDsA3MA
>> "%~1" echo eABkcQAAAACRAPsDcwB5ACxyAAAAAJEABgQ3AHoAbHMAAAAAkQASBHMAfADYcwAA
>> "%~1" echo AACRACMENwB9AMx0AAAAAJEAMQRzAH8A+HUAAAAAkQBABHMAgABgdgAAAACRAFYE
>> "%~1" echo 5ACBALh2AAAAAJEAaATpAIIADHcAAAAAkQB5BOkAhAA0dwAAAACRAIQE7wCGAGR3
>> "%~1" echo AAAAAJEAhgRzAIgAhHcAAAAAkQCIBPoAiQCodwAAAACRAJAEcwCLAKx4AAAAAJEA
>> "%~1" echo nwRzAIwA9HgAAAAAkQCrBAABjQDweQAAAACRALIEcwCPAEh6AAAAAJEAvQRzAJAA
>> "%~1" echo mHoAAAAAkQDDBAcBkQDYegAAAACRAMkEDQGSABR7AAAAAJEA0QQNAZMAhHsAAAAA
>> "%~1" echo kQDaBA0BlAAcfAAAAACRAOoEDQGVANR8AAAAAJEA+ARzAJYAEH0AAAAAkQADBSMA
>> "%~1" echo lwA8fQAAAACRAAYFEgGXAHR9AAAAAJEADAUNAZgAnH0AAAAAkQAXBTcAmQBcfgAA
>> "%~1" echo AACRAB0FcwCbAIx+AAAAAJEAIQUcAZwArH4AAAAAkQArBSgBngAUfwAAAACRADYF
>> "%~1" echo MQGhAOB/AAAAAJEAOwVzAKIAAIEAAAAAkQA/BUkAowCjgQAAAACGGEQFOwGjAFAg
>> "%~1" echo AAAAAJEAdgduAaMAZHgAAAAAkQBfD1YGpAA4gQAAAACRGBwQBAelAKyBAAAAAIYI
>> "%~1" echo YwVCAaUA24EAAAAAhhhEBTsBpQAIggAAAACGCGMFQgGlADiCAAAAAIYYRAU7AaUA
>> "%~1" echo kIIAAAAAhhhEBTsBpQCkYgAAAACGGEQFOwGlAKxiAAAAAIYYRAU7AaUAtGIAAAAA
>> "%~1" echo hgDvDDsBpQD8YgAAAACGAP8MOwGlAAAAAQDDBQAAAQDIBQAAAQDPBQAAAgDWBQAA
>> "%~1" echo AQDcBQAAAgDiBQAAAQDnBQAAAgDuBQAAAQDzBQAAAQDzBQAAAQD6BQAAAQACBgIA
>> "%~1" echo AQAHBgIAAgA+BgAAAQDzBQAAAgDiBQAAAQDzBQAAAgBDBgAAAwBGBgAAAQDzBQAA
>> "%~1" echo AgBKBgAAAwBSBgAAAQBKBgAAAgDDBQAAAQDzBQAAAgBKBgAAAwBSBgAAAQBKBgAA
>> "%~1" echo AgDDBQAAAQDzBQAAAQBuBgAAAgDzBQAAAwBDBgAABABGBgAAAQDzBQAAAQDzBQAA
>> "%~1" echo AQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAA
>> "%~1" echo AQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAAAQBxBgAAAgDzBQAA
>> "%~1" echo AQDzBQAAAgAHBgAAAQBzBgAAAgDiBQAAAwDzBQAABABKBgAABQBSBgAAAQBzBgAA
>> "%~1" echo AgDiBQAAAwBKBgAABAB4BgAABQDDBQAAAQBzBgAAAgDiBQAAAQBzBgAAAQBzBgAA
>> "%~1" echo AgCBBgAAAQBuBgAAAgCGBgAAAwCMBgAABACBBgAABQCOBgAAAQBuBgAAAgBzBgAA
>> "%~1" echo AwCBBgAAAQDzBQAAAQCTBgAAAgDDBQAAAwBKBgAAAQCTBgAAAgDDBQAAAwBKBgAA
>> "%~1" echo AQDDBQAAAQCYBgAAAQCaBgAAAgCcBgAAAQCeBgAAAQCeBgAAAQCYBgAAAQACBgAA
>> "%~1" echo AgBGBgAAAQACBgAAAgBGBgAAAQACBgAAAgCgBgAAAQCnBgAAAgBGBgAAAQACBgAA
>> "%~1" echo AgBGBgAAAQACBgAAAgBGBgAAAQACBgAAAgBGBgAAAQACBgAAAQACBgAAAgCsBgAA
>> "%~1" echo AwCxBgAAAQACBgAAAgC3BgAAAQACBgAAAgC3BgAAAQACBgAAAgBGBgAAAQC/BgAA
>> "%~1" echo AQDCBgAAAQDGBgAAAQDKBgAAAQDSBgAAAQDaBgAAAQDeBgAAAgDjBgAAAQDqBgAA
>> "%~1" echo AQDtBgAAAgD0BgAAAQD0BgAAAQACBgAAAQACBgAAAQACBgAAAgD7BgAAAQACBgAA
>> "%~1" echo AgC3BgAAAQBxBgAAAgBGBgAAAQCYBgAAAQACBgAAAgCBBgAAAQDuBQAAAQACBgAA
>> "%~1" echo AQACBgAAAgBzBgAAAQDzBQAAAQCYBgAAAQCYBgAAAQBDBgAAAQDiBQAAAQDPBQAA
>> "%~1" echo AQBGBgAAAQACBwAAAQAIBwAAAQAMBwAAAQDWBQAAAgBGBgAAAQCYBgAAAQCYBgAA
>> "%~1" echo AgBxBgAAAQDnBQAAAgAOBwAAAwATBwAAAQBxBgAAAQCYBgAAAQCBBwAAAQBxD0EA
>> "%~1" echo RAU7AUkARAU7AVEARAVpAVkARAU7AWkARAU7ARkA4wc7AXEA8wdCAXkABgg3ABEA
>> "%~1" echo DQh8AYEAHgiBAYkAOwiHAYkATQhCAZEAdAiMAZkARAWSAZkAhgg7AYEAjAhEAIEA
>> "%~1" echo pQiZAXkABgieAXkABgikAXkABgjeALEAvwhzAHkA5wirAcEAhgiyAZkACQm4AWEA
>> "%~1" echo RAW9AckAJAnDARkANglpARkASQlpARkAZwncAdkARAXhAeEAiQlCAXkAkgkNAXkA
>> "%~1" echo pQnpAXkAqwlCAfEARAXwAfEAwAlCAXkA0Qn1AfEA3QlCAXkA5wn1AXkA9QmrAREA
>> "%~1" echo AAr7AfkAFQo7AXkABggWAgwAHQojAgwAJgorAnkABghKAgEBNgpSAnEARAXwAQwA
>> "%~1" echo PApXAgkBUQqFAgkBWQqLAhEBZwpVABkBhwqQAnkABghVABEBZwo3ACkBnAqXAgkB
>> "%~1" echo sgqfAjEBwQqrAjkB+AqvAkEBWQq1AhQAIwvDAqkAWQq1AhwAIwvDAhwALQvNAnkA
>> "%~1" echo NQvTAvEAOgtzAHkASwvDAnkAVgsLA/EAYAtzABEBcwsQA3kAigsTA3kAkgsZA3kA
>> "%~1" echo kgsgA3kAmgurAREBowtzACkBrwsNASkBtgslA3kAwws8AxkBrwsNASkByAuXAlEB
>> "%~1" echo 3gtMA7EA5AtJAFEB8AtuAREA9QtcA3kAwwtCAXkApQlxAzEARAU7ATEAEgylAwkA
>> "%~1" echo WQpCATEAHQylAzEAHQy1AykBJAzAA3kApQnIA3kAigvgA2EBRQzsA2EBWQr5AxwA
>> "%~1" echo RAU7AXkAVgsJBBwATgwPBHEBXAxhBHEBZQw7AXEBagxnBBQATgwPBBQAjQx2BCQA
>> "%~1" echo mwyIBCQApwyNBAkBWQr5A3kAkgvxBAkARAU7AcEADw0QBeEAIg1CAcEALA0QBYEB
>> "%~1" echo RAU7AYEBTw3wAYEBXA3wAYEBag0VBYEBfg0VBYEBmQ0VBYEBsw0VBcEAhggaBYkB
>> "%~1" echo RAW9AQEBRAUiBQEBhgg7AcEA0g0pBcEA3g07AcEA4w3DAgEBNQspBZkBmA5PBXkA
>> "%~1" echo qA5ZBXkAmgtfBXkAsw48A3kAkgusBbEB4A67BckB+Q6NBLkBFQ/GBdEBIwvDAtEB
>> "%~1" echo JgrMBdkBIA9CAbEBKg9zALEBQQ9HBuEBIwvDAukBVA9zALEBqQ/1AfEBRAW9AbEB
>> "%~1" echo igtiBrEBigtVALEBigtrBnkAsQ+ABukAuw+FBnkAyw9CAQwARAU7AXkA9QlfBREA
>> "%~1" echo 3A98ASkA5g+gBjEARAXwAQwAjQywBiwAmwzEBjQA+w+IBDQAIA/YBiwApwyNBKkA
>> "%~1" echo WQqLAgkCCxAlAxEA9Qv+BhECKBAIBxECWQqLAhkCRAUVBRQARAU7AS4AGwAUBy4A
>> "%~1" echo IwAdB8MAKwBkAeMAKwBkAQMBKwBkASEBKwBkAUEBKwBkAQQDEwBkAaQDEwBkAQQI
>> "%~1" echo EwBkAcAMKwBkAeAMKwBkAQEAEAAAAAkAdwHKAQECMgJdAnYC2gIFAysDNANCA1MD
>> "%~1" echo ZAN7A5IDlgObA6sDuwPQA+YDAQQVBCcEOgRBBFAEXARrBJEEoAS6BM8E4QT2BC4F
>> "%~1" echo QwVkBW4FewWEBY8FnwW0BdMF2gXkBfQF+wULBhgGJwY3Bj0GUgZ1BnwGigaSBqgG
>> "%~1" echo 3QbzBg4HAwABAAQAAgAAAGwFRgEAAGwFRgECAGkAAwACAGsABQAcArwCxwKABLwG
>> "%~1" echo 0AYYZQAAHwAEgAAAAAAAAAAAAAAAAAAAAAAcAAAABAAAAAAAAAAAAAAAAQBFAAAA
>> "%~1" echo AAAEAAAAAAAAAAAAAAABAE4AAAAAAAMAAgAEAAIABQACAAYAAgAHAAIACQAIAAAA
>> "%~1" echo ADxNb2R1bGU+AFF1ZXN0QWRiV2ViVWkuZXhlAFF1ZXN0QWRiV2ViVWkAQ21kUmVz
>> "%~1" echo dWx0AENhcHR1cmUAU25hcHNob3QAbXNjb3JsaWIAU3lzdGVtAE9iamVjdABBZGJQ
>> "%~1" echo YXRoAFRva2VuAFBvcnQAUm9vdERpcgBMb2dEaXIATG9nRmlsZQBMb2dMb2NrAFN5
>> "%~1" echo c3RlbS5UZXh0AEVuY29kaW5nAFV0ZjhOb0JvbQBNYWluAFN5c3RlbS5OZXQuU29j
>> "%~1" echo a2V0cwBUY3BDbGllbnQAU2VydmUAU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMA
>> "%~1" echo RGljdGlvbmFyeWAyAFN0YXR1cwBBY3Rpb24ATG9ncwBFeHBvcnRSZXBvcnQARXhw
>> "%~1" echo b3J0VXJsAFN5c3RlbS5JTwBTdHJlYW0AU2VydmVFeHBvcnQARGVidWdNb2RlAENv
>> "%~1" echo bnNlcnZhdGl2ZQBDdXJyZW50U2VyaWFsAEluaXRMb2cATG9nAFJlYWRMb2dUYWls
>> "%~1" echo AFNlbGVjdERldmljZQBQcm9wAFNldHRpbmcAU2gAQQBNdXN0U2gATXVzdEEARW5z
>> "%~1" echo dXJlQmFja3VwAFN0cmluZ0J1aWxkZXIAV3JpdGVCYWNrdXBMaW5lAFJlc3RvcmVC
>> "%~1" echo YWNrdXAAQmFja3VwRmlsZQBGaWxsQmF0dGVyeQBGaWxsUG93ZXIARmlsbENvbnRy
>> "%~1" echo b2xsZXJzRmFzdABGaWxsUmVzb3VyY2VzAEZpbGxWaXJ0dWFsRGVza3RvcABGaWxs
>> "%~1" echo RGlzcGxheUxpdGUARmlsbFRoZXJtYWxMaXRlAEZpbGxGYWN0b3J5TGl0ZQBDb2xs
>> "%~1" echo ZWN0U25hcHNob3QAQWRkU2hlbGxDYXB0dXJlAEFkZENhcHR1cmUAQ2FwAEZpbGxT
>> "%~1" echo bmFwc2hvdEZpZWxkcwBCdWlsZFJlcG9ydEh0bWwAQWRkSW52b2ljZUZhY3RzAEFk
>> "%~1" echo ZEludm9pY2VSYXcAV2lmaUlwAFJ1bgBSdW5SZXN1bHQASm9pbkFyZ3MAUXVvdGVB
>> "%~1" echo cmcASm9pbk5vbkVtcHR5AEJhdHRlcnlTdGF0dXMAQmF0dGVyeUhlYWx0aABQb3dl
>> "%~1" echo clNvdXJjZQBBZnRlckNvbG9uAEFmdGVyRXF1YWxzAEZpbmRMaW5lAEZpZWxkAEZp
>> "%~1" echo bmRQYWNrYWdlRmllbGQATWVtR2IAUHJvcEZyb20ARmlyc3RMaW5lAEJldHdlZW4A
>> "%~1" echo UmVnZXhWYWx1ZQBGaXJzdFJlZ2V4AEV4dHJhY3RKc29uaXNoAFN0b3JhZ2VTdW1t
>> "%~1" echo YXJ5AE1lbW9yeVN1bW1hcnkAQ3B1U3VtbWFyeQBEaXNwbGF5U3VtbWFyeQBUaGVy
>> "%~1" echo bWFsU3VtbWFyeQBVc2JTdW1tYXJ5AFdpZmlTdW1tYXJ5AEJsdWV0b290aFN1bW1h
>> "%~1" echo cnkAQ2FtZXJhU3VtbWFyeQBGYWN0b3J5U3VtbWFyeQBWaXJ0dWFsRGVza3RvcFN1
>> "%~1" echo bW1hcnkAQ291bnRQYWNrYWdlTGluZXMAQ291bnRQcmVmaXhMaW5lcwBDb3VudFJl
>> "%~1" echo Z2V4AFYASABQcml2YWN5AEFkYlNvdXJjZUxhYmVsAFJlZGFjdExvb3NlAFJlZGFj
>> "%~1" echo dABTZXJpYWxNYXNrAENsZWFuAExpbmVzAFZhbGlkTnMAU2FmZU5hbWUARGFuZ2Vy
>> "%~1" echo b3VzQWN0aW9uAERlbmllZFNldHRpbmcAU2hlbGxRdW90ZQBPawBFcnJvcgBDaGVj
>> "%~1" echo a1Rva2VuAFF1ZXJ5AFVybABXcml0ZUpzb24AV3JpdGVCeXRlcwBKc29uAEVzYwBI
>> "%~1" echo dG1sAC5jdG9yAE91dHB1dABFeGl0Q29kZQBUaW1lZE91dABnZXRfVGV4dABUZXh0
>> "%~1" echo AE5hbWUAQ29tbWFuZABEdXJhdGlvbk1zAENyZWF0ZWQAU2VyaWFsAERldmljZUxp
>> "%~1" echo bmUARmllbGRzAExpc3RgMQBDYXB0dXJlcwBXYXJuaW5ncwBhcmdzAGNsaWVudABh
>> "%~1" echo Y3Rpb24AcXVlcnkAc3RhbXAAbmFtZQBzdHJlYW0AcGF0aABzZXJpYWwAYmFzZURp
>> "%~1" echo cgB0ZXh0AGRldmljZUxpbmUAU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2Vz
>> "%~1" echo AE91dEF0dHJpYnV0ZQBoaW50AG5zAGtleQB0aW1lb3V0AGNvbW1hbmQAUGFyYW1B
>> "%~1" echo cnJheUF0dHJpYnV0ZQBzYgBkAHNuYXAAcmVxdWlyZWQAc2FmZQB0aXRsZQBmAGRl
>> "%~1" echo ZnMAZmlsZQBzAGEAYgB2AG5lZWRsZQBsaW5lAGxlZnQAcmlnaHQAcGF0dGVybgBk
>> "%~1" echo ZgBtZW0AY3B1AGRpc3BsYXkAdGhlcm1hbAB1c2IAd2lmaQBpcEFkZHIAYnQAY2Ft
>> "%~1" echo ZXJhAHNlbnNvcgBwcmVmaXgAdmFsdWUAbXNnAHEAdHlwZQBib2R5AFN5c3RlbS5S
>> "%~1" echo dW50aW1lLkNvbXBpbGVyU2VydmljZXMAQ29tcGlsYXRpb25SZWxheGF0aW9uc0F0
>> "%~1" echo dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJpbGl0eUF0dHJpYnV0ZQA8TWFpbj5iX18w
>> "%~1" echo AG8AU3lzdGVtLlRocmVhZGluZwBXYWl0Q2FsbGJhY2sAQ1MkPD45X19DYWNoZWRB
>> "%~1" echo bm9ueW1vdXNNZXRob2REZWxlZ2F0ZTEAQ29tcGlsZXJHZW5lcmF0ZWRBdHRyaWJ1
>> "%~1" echo dGUAQ2xvc2UARXhjZXB0aW9uAGdldF9NZXNzYWdlAFN0cmluZwBDb25jYXQAZ2V0
>> "%~1" echo X1VURjgAQ29uc29sZQBzZXRfT3V0cHV0RW5jb2RpbmcAQXBwRG9tYWluAGdldF9D
>> "%~1" echo dXJyZW50RG9tYWluAGdldF9CYXNlRGlyZWN0b3J5AFN5c3RlbS5OZXQASVBBZGRy
>> "%~1" echo ZXNzAFBhcnNlAFRjcExpc3RlbmVyAFN0YXJ0AFdyaXRlTGluZQBDb25zb2xlS2V5
>> "%~1" echo SW5mbwBSZWFkS2V5AEludDMyAEVudmlyb25tZW50AEdldEVudmlyb25tZW50VmFy
>> "%~1" echo aWFibGUAU3RyaW5nQ29tcGFyaXNvbgBFcXVhbHMAU3lzdGVtLkRpYWdub3N0aWNz
>> "%~1" echo AFByb2Nlc3MAQWNjZXB0VGNwQ2xpZW50AFRocmVhZFBvb2wAUXVldWVVc2VyV29y
>> "%~1" echo a0l0ZW0Ac2V0X1JlY2VpdmVUaW1lb3V0AHNldF9TZW5kVGltZW91dABOZXR3b3Jr
>> "%~1" echo U3RyZWFtAEdldFN0cmVhbQBTdHJlYW1SZWFkZXIAVGV4dFJlYWRlcgBSZWFkTGlu
>> "%~1" echo ZQBJc051bGxPckVtcHR5AENoYXIAU3BsaXQAVG9VcHBlckludmFyaWFudABVcmkA
>> "%~1" echo Z2V0X0Fic29sdXRlUGF0aABvcF9FcXVhbGl0eQBnZXRfUXVlcnkAb3BfSW5lcXVh
>> "%~1" echo bGl0eQBTdGFydHNXaXRoAEdldEJ5dGVzAElEaXNwb3NhYmxlAERpc3Bvc2UAc2V0
>> "%~1" echo X0l0ZW0AZ2V0X0l0ZW0AVGhyZWFkAFNsZWVwAENvbnRhaW5zS2V5AERhdGVUaW1l
>> "%~1" echo AGdldF9Ob3cAVG9TdHJpbmcAUGF0aABDb21iaW5lAERpcmVjdG9yeQBEaXJlY3Rv
>> "%~1" echo cnlJbmZvAENyZWF0ZURpcmVjdG9yeQBGaWxlAFdyaXRlQWxsVGV4dABUaW1lU3Bh
>> "%~1" echo bgBvcF9TdWJ0cmFjdGlvbgBnZXRfVG90YWxNaWxsaXNlY29uZHMAU3lzdGVtLkds
>> "%~1" echo b2JhbGl6YXRpb24AQ3VsdHVyZUluZm8AZ2V0X0ludmFyaWFudEN1bHR1cmUASW50
>> "%~1" echo NjQASUZvcm1hdFByb3ZpZGVyAGdldF9Db3VudABUb0FycmF5AEpvaW4ARXNjYXBl
>> "%~1" echo RGF0YVN0cmluZwBnZXRfTGVuZ3RoAFN1YnN0cmluZwBVbmVzY2FwZURhdGFTdHJp
>> "%~1" echo bmcARGlyZWN0b3J5U2VwYXJhdG9yQ2hhcgBSZXBsYWNlAEluZGV4T2YARW5kc1dp
>> "%~1" echo dGgAR2V0RnVsbFBhdGgARXhpc3RzAFJlYWRBbGxCeXRlcwBUcmltAEFwcGVuZEFs
>> "%~1" echo bFRleHQATW9uaXRvcgBFbnRlcgBnZXRfTmV3TGluZQBFeGl0AEdldFN0cmluZwBT
>> "%~1" echo dHJpbmdTcGxpdE9wdGlvbnMAQXBwZW5kTGluZQBBcHBlbmQAUmVhZEFsbExpbmVz
>> "%~1" echo AERvdWJsZQBOdW1iZXJTdHlsZXMAVHJ5UGFyc2UAQWRkAFN0b3B3YXRjaABTdGFy
>> "%~1" echo dE5ldwBTdG9wAGdldF9FbGFwc2VkTWlsbGlzZWNvbmRzAEVudW1lcmF0b3IAR2V0
>> "%~1" echo RW51bWVyYXRvcgBnZXRfQ3VycmVudABNb3ZlTmV4dAA8PmNfX0Rpc3BsYXlDbGFz
>> "%~1" echo czUAcmVzdWx0ADw+Y19fRGlzcGxheUNsYXNzNwBDUyQ8PjhfX2xvY2FsczYAcAA8
>> "%~1" echo UnVuUmVzdWx0PmJfXzMAPFJ1blJlc3VsdD5iX180AGdldF9TdGFuZGFyZE91dHB1
>> "%~1" echo dABSZWFkVG9FbmQAZ2V0X1N0YW5kYXJkRXJyb3IAUHJvY2Vzc1N0YXJ0SW5mbwBz
>> "%~1" echo ZXRfRmlsZU5hbWUAc2V0X0FyZ3VtZW50cwBzZXRfVXNlU2hlbGxFeGVjdXRlAHNl
>> "%~1" echo dF9SZWRpcmVjdFN0YW5kYXJkT3V0cHV0AHNldF9SZWRpcmVjdFN0YW5kYXJkRXJy
>> "%~1" echo b3IAc2V0X0NyZWF0ZU5vV2luZG93AFRocmVhZFN0YXJ0AFdhaXRGb3JFeGl0AEtp
>> "%~1" echo bGwAZ2V0X0V4aXRDb2RlADxQcml2YXRlSW1wbGVtZW50YXRpb25EZXRhaWxzPns3
>> "%~1" echo RjU3NzA4RC0yOTRCLTQ1RTEtQkQ4Qi1CNkZCMzkxQjYxQUV9AFZhbHVlVHlwZQBf
>> "%~1" echo X1N0YXRpY0FycmF5SW5pdFR5cGVTaXplPTE2ACQkbWV0aG9kMHg2MDAwMDJlLTEA
>> "%~1" echo UnVudGltZUhlbHBlcnMAQXJyYXkAUnVudGltZUZpZWxkSGFuZGxlAEluaXRpYWxp
>> "%~1" echo emVBcnJheQBJbmRleE9mQW55AFRyaW1FbmQAU3lzdGVtLlRleHQuUmVndWxhckV4
>> "%~1" echo cHJlc3Npb25zAFJlZ2V4AE1hdGNoAFJlZ2V4T3B0aW9ucwBHcm91cABnZXRfU3Vj
>> "%~1" echo Y2VzcwBHcm91cENvbGxlY3Rpb24AZ2V0X0dyb3VwcwBnZXRfVmFsdWUARXNjYXBl
>> "%~1" echo AE1hdGNoQ29sbGVjdGlvbgBNYXRjaGVzAFdlYlV0aWxpdHkASHRtbEVuY29kZQA8
>> "%~1" echo UmVkYWN0TG9vc2U+Yl9fOQBtAE1hdGNoRXZhbHVhdG9yAENTJDw+OV9fQ2FjaGVk
>> "%~1" echo QW5vbnltb3VzTWV0aG9kRGVsZWdhdGVhAElzTWF0Y2gAZ2V0X0NoYXJzAElzTGV0
>> "%~1" echo dGVyT3JEaWdpdABUb0xvd2VySW52YXJpYW50AGdldF9BU0NJSQBXcml0ZQBLZXlW
>> "%~1" echo YWx1ZVBhaXJgMgBnZXRfS2V5AENvbnZlcnQARnJvbUJhc2U2NFN0cmluZwAuY2N0
>> "%~1" echo b3IAR3VpZABOZXdHdWlkAFVURjhFbmNvZGluZwAAAAAAD/eLQmy/fgt6Al84Xhr/
>> "%~1" echo ARMxADIANwAuADAALgAwAC4AMQAATVEAdQBlAHMAdAAgAEEARABCACAAVwBlAGIA
>> "%~1" echo VQBJACAAL1SoUjFZJY0a/zgANwA2ADUALQA4ADcAOAA1ACAA73rjU/2QDU7vUyh1
>> "%~1" echo AjABLS9UqFIxWSWNGv84ADcANgA1AC0AOAA3ADgANQAgAO9641P9kA1O71ModQIw
>> "%~1" echo ASNoAHQAdABwADoALwAvADEAMgA3AC4AMAAuADAALgAxADoAABEvAD8AdABvAGsA
>> "%~1" echo ZQBuAD0AAC1RAHUAZQBzAHQAIABBAEQAQgAgAFcAZQBiAFUASQAgAA1noVLyXS9U
>> "%~1" echo qFIa/wE96lPRdixUIAAxADIANwAuADAALgAwAC4AMQAb/3NR7ZUsZ5d641MOVCAA
>> "%~1" echo VwBlAGIAVQBJACAAXFBiawIwAQtBAEQAQgA6ACAAAAnlZddfOgAgAAEtDWehUi9U
>> "%~1" echo qFIa/2gAdAB0AHAAOgAvAC8AMQAyADcALgAwAC4AMAAuADEAOgABAy8AAA8dUstZ
>> "%~1" echo 3o+lY7ZyAWAa/wEDIAAAAzEAADVRAFUARQBTAFQAXwBBAEQAQgBfAFcARQBCAFUA
>> "%~1" echo SQBfAE4ATwBfAEIAUgBPAFcAUwBFAFIAAA/3i0JsBFkGdDFZJY0a/wEXLwBhAHAA
>> "%~1" echo aQAvAHMAdABhAHQAdQBzAAARdABvAGsAZQBuACAA4GVIZQEXLwBhAHAAaQAvAGEA
>> "%~1" echo YwB0AGkAbwBuAAAJUABPAFMAVAAAI+5POWXNZFxPxV97mH9PKHUgAFAATwBTAFQA
>> "%~1" echo IAD3i0JsAjABDWEAYwB0AGkAbwBuAAAPYwBvAG4AZgBpAHIAbQAAB1kARQBTAAAX
>> "%~1" echo cVNpls1kXE8Al4GJjE4ha254pIsCMAETLwBhAHAAaQAvAGwAbwBnAHMAABcvAGEA
>> "%~1" echo cABpAC8AZQB4AHAAbwByAHQAAB/8W/pRxV97mH9PKHUgAFAATwBTAFQAIAD3i0Js
>> "%~1" echo AjABEy8AZQB4AHAAbwByAHQAcwAvAAAzdABlAHgAdAAvAHAAbABhAGkAbgA7ACAA
>> "%~1" echo YwBoAGEAcgBzAGUAdAA9AHUAdABmAC0AOAABGS8AZgBhAHYAaQBjAG8AbgAuAGkA
>> "%~1" echo YwBvAAAbaQBtAGEAZwBlAC8AcwB2AGcAKwB4AG0AbAAAgbM8AHMAdgBnACAAeABt
>> "%~1" echo AGwAbgBzAD0AJwBoAHQAdABwADoALwAvAHcAdwB3AC4AdwAzAC4AbwByAGcALwAy
>> "%~1" echo ADAAMAAwAC8AcwB2AGcAJwAgAHYAaQBlAHcAQgBvAHgAPQAnADAAIAAwACAAMgA0
>> "%~1" echo ACAAMgA0ACcAIABmAGkAbABsAD0AJwBuAG8AbgBlACcAIABzAHQAcgBvAGsAZQA9
>> "%~1" echo ACcAIwAyADUANgAzAGUAYgAnACAAcwB0AHIAbwBrAGUALQB3AGkAZAB0AGgAPQAn
>> "%~1" echo ADIAJwA+ADwAcABhAHQAaAAgAGQAPQAnAE0ANgAgADkAaAAxADIAYQAzACAAMwAg
>> "%~1" echo ADAAIAAwACAAMQAgADMAIAAzAHYAMwBhADMAIAAzACAAMAAgADAAIAAxAC0AMwAg
>> "%~1" echo ADMAaAAtADEALgA1AGwALQAyAC4ANQAtADMAaAAtADQAbAAtADIALgA1ACAAMwBI
>> "%~1" echo ADYAYQAzACAAMwAgADAAIAAwACAAMQAtADMALQAzAHYALQAzAGEAMwAgADMAIAAw
>> "%~1" echo ACAAMAAgADEAIAAzAC0AMwB6ACcALwA+ADwALwBzAHYAZwA+AAExdABlAHgAdAAv
>> "%~1" echo AGgAdABtAGwAOwAgAGMAaABhAHIAcwBlAHQAPQB1AHQAZgAtADgAAQ9zAGUAcgB2
>> "%~1" echo AGkAYwBlAAAVMQAyADcALgAwAC4AMAAuADEAOgAAD2EAZABiAFAAYQB0AGgAAA9s
>> "%~1" echo AG8AZwBGAGkAbABlAAAXZABlAHYAaQBjAGUAUwB0AGEAdABlAAAVZABlAHYAaQBj
>> "%~1" echo AGUATABpAG4AZQAACWgAaQBuAHQAABNjAG8AbgBuAGUAYwB0AGUAZAAADWQAZQB2
>> "%~1" echo AGkAYwBlAAALZgBhAGwAcwBlAAAJdAByAHUAZQAAC7ZyAWD7i9ZTGv8BDXMAZQBy
>> "%~1" echo AGkAYQBsAAALbQBvAGQAZQBsAAAhcgBvAC4AcAByAG8AZAB1AGMAdAAuAG0AbwBk
>> "%~1" echo AGUAbAAAD2EAbgBkAHIAbwBpAGQAADFyAG8ALgBiAHUAaQBsAGQALgB2AGUAcgBz
>> "%~1" echo AGkAbwBuAC4AcgBlAGwAZQBhAHMAZQAAB3MAZABrAAApcgBvAC4AYgB1AGkAbABk
>> "%~1" echo AC4AdgBlAHIAcwBpAG8AbgAuAHMAZABrAAAbcwBlAGMAdQByAGkAdAB5AFAAYQB0
>> "%~1" echo AGMAaAAAP3IAbwAuAGIAdQBpAGwAZAAuAHYAZQByAHMAaQBvAG4ALgBzAGUAYwB1
>> "%~1" echo AHIAaQB0AHkAXwBwAGEAdABjAGgAABltAGEAbgB1AGYAYQBjAHQAdQByAGUAcgAA
>> "%~1" echo L3IAbwAuAHAAcgBvAGQAdQBjAHQALgBtAGEAbgB1AGYAYQBjAHQAdQByAGUAcgAA
>> "%~1" echo C2IAcgBhAG4AZAAAIXIAbwAuAHAAcgBvAGQAdQBjAHQALgBiAHIAYQBuAGQAABdw
>> "%~1" echo AHIAbwBkAHUAYwB0AE4AYQBtAGUAAB9yAG8ALgBwAHIAbwBkAHUAYwB0AC4AbgBh
>> "%~1" echo AG0AZQAAG3AAcgBvAGQAdQBjAHQARABlAHYAaQBjAGUAACNyAG8ALgBwAHIAbwBk
>> "%~1" echo AHUAYwB0AC4AZABlAHYAaQBjAGUAAAtiAG8AYQByAGQAACFyAG8ALgBwAHIAbwBk
>> "%~1" echo AHUAYwB0AC4AYgBvAGEAcgBkAAAHcwBvAGMAACdyAG8ALgBzAG8AYwAuAG0AYQBu
>> "%~1" echo AHUAZgBhAGMAdAB1AHIAZQByAAAZcgBvAC4AcwBvAGMALgBtAG8AZABlAGwAAA9i
>> "%~1" echo AHUAaQBsAGQASQBkAAAncgBvAC4AYgB1AGkAbABkAC4AZABpAHMAcABsAGEAeQAu
>> "%~1" echo AGkAZAAAF2IAdQBpAGwAZABCAHIAYQBuAGMAaAAAH3IAbwAuAGIAdQBpAGwAZAAu
>> "%~1" echo AGIAcgBhAG4AYwBoAAAhYgB1AGkAbABkAEkAbgBjAHIAZQBtAGUAbgB0AGEAbAAA
>> "%~1" echo OXIAbwAuAGIAdQBpAGwAZAAuAHYAZQByAHMAaQBvAG4ALgBpAG4AYwByAGUAbQBl
>> "%~1" echo AG4AdABhAGwAABd2AGUAbgBkAG8AcgBQAGEAdABjAGgAAD1yAG8ALgB2AGUAbgBk
>> "%~1" echo AG8AcgAuAGIAdQBpAGwAZAAuAHMAZQBjAHUAcgBpAHQAeQBfAHAAYQB0AGMAaAAA
>> "%~1" echo B2EAYgBpAAAlcgBvAC4AcAByAG8AZAB1AGMAdAAuAGMAcAB1AC4AYQBiAGkAAA13
>> "%~1" echo AGkAZgBpAEkAcAAAFWEAZABiAEUAbgBhAGIAbABlAGQAAA1nAGwAbwBiAGEAbAAA
>> "%~1" echo F2EAZABiAF8AZQBuAGEAYgBsAGUAZAAAD2EAZABiAFcAaQBmAGkAACFhAGQAYgBf
>> "%~1" echo AHcAaQBmAGkAXwBlAG4AYQBiAGwAZQBkAAANcwB0AGEAeQBPAG4AADFzAHQAYQB5
>> "%~1" echo AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUAZABfAGkAbgAAE3cAaQBm
>> "%~1" echo AGkAUwBsAGUAZQBwAAAjdwBpAGYAaQBfAHMAbABlAGUAcABfAHAAbwBsAGkAYwB5
>> "%~1" echo AAATcwBjAHIAZQBlAG4ATwBmAGYAAA1zAHkAcwB0AGUAbQAAJXMAYwByAGUAZQBu
>> "%~1" echo AF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0AAAZcwBsAGUAZQBwAFQAaQBtAGUAbwB1
>> "%~1" echo AHQAAA1zAGUAYwB1AHIAZQAAG3MAbABlAGUAcABfAHQAaQBtAGUAbwB1AHQAABFs
>> "%~1" echo AG8AdwBQAG8AdwBlAHIAABNsAG8AdwBfAHAAbwB3AGUAcgAAGbZyAWD7i9ZTGv9k
>> "%~1" echo AGUAdgBpAGMAZQAgAAETIABiAGEAdAB0AGUAcgB5AD0AABliAGEAdAB0AGUAcgB5
>> "%~1" echo AEwAZQB2AGUAbAAADyUAIAB0AGUAbQBwAD0AABdiAGEAdAB0AGUAcgB5AFQAZQBt
>> "%~1" echo AHAAAA9DACAAdwBhAGsAZQA9AAAXdwBhAGsAZQBmAHUAbABuAGUAcwBzAAARIABz
>> "%~1" echo AHQAYQB5AE8AbgA9AAATIABhAGQAYgBXAGkAZgBpAD0AAAvNZFxPAF/LWRr/AREg
>> "%~1" echo AHMAZQByAGkAYQBsAD0AABdyAGUAcwB0AGEAcgB0AF8AYQBkAGIAABdrAGkAbABs
>> "%~1" echo AC0AcwBlAHIAdgBlAHIAARlzAHQAYQByAHQALQBzAGUAcgB2AGUAcgABDXIAZQBz
>> "%~1" echo AHUAbAB0AAAd8l3NkS9UNXURge96IABBAEQAQgAgAA1noVICMAEDLQABIaFsCWco
>> "%~1" echo V79+FE7yXYhjQ2eEdiAAUQB1AGUAcwB0AAIwARVzAGEAZgBlAF8AcwBsAGUAZQBw
>> "%~1" echo AAA5aQBuAHAAdQB0ACAAawBlAHkAZQB2AGUAbgB0ACAASwBFAFkAQwBPAEQARQBf
>> "%~1" echo AFMATABFAEUAUAAASfJdYmANWd1PiFs8UHZe0VMBkCAAcAByAG8AeABfAG8AcABl
>> "%~1" echo AG4AIAArACAASwBFAFkAQwBPAEQARQBfAFMATABFAEUAUAACMAEVawBlAGUAcABf
>> "%~1" echo AGEAdwBhAGsAZQAAEfJdlF4ode139mXdTzttAjABFWQAZQBiAHUAZwBfAG0AbwBk
>> "%~1" echo AGUAAH/yXS9UKHUDjNWL5V1cTyFqD18a/1UAUwBCAC8AQQBDACAA3U8BYyRVkpEB
>> "%~1" echo MFcAaQAtAEYAaQAgAA1OEU8gdwEwT1xVXiAAMgA0ACAAD1z2ZQEwIWrfYmlPNGJg
>> "%~1" echo l9GPAjDTfl9nDlT3i2diTIgcIGJgDVkRTyB3hY32ZR0gAjABG3IAZQBzAHQAbwBy
>> "%~1" echo AGUAXwBzAGwAZQBlAHAAACXyXWJgDVljazheEU8gdw5OIAA1ACAABlKflE9cVV6F
>> "%~1" echo jfZlAjABGWMAbwBuAHMAZQByAHYAYQB0AGkAdgBlAAAT8l1iYA1Z3U+IW9iepIs8
>> "%~1" echo UAIwAR1yAGUAcwB0AG8AcgBlAF8AYgBhAGMAawB1AHAAAC/yXc5OB1n9TmJgDVm+
>> "%~1" echo i25/DP92XtFTAZAgAHAAcgBvAHgAXwBvAHAAZQBuAAIwARNwAHIAbwB4AF8AbwBw
>> "%~1" echo AGUAbgAAZ2EAbQAgAGIAcgBvAGEAZABjAGEAcwB0ACAALQBhACAAYwBvAG0ALgBv
>> "%~1" echo AGMAdQBsAHUAcwAuAHYAcgBwAG8AdwBlAHIAbQBhAG4AYQBnAGUAcgAuAHAAcgBv
>> "%~1" echo AHgAXwBvAHAAZQBuAAEd8l3RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgACMAEVcABy
>> "%~1" echo AG8AeABfAGMAbABvAHMAZQAAaWEAbQAgAGIAcgBvAGEAZABjAGEAcwB0ACAALQBh
>> "%~1" echo ACAAYwBvAG0ALgBvAGMAdQBsAHUAcwAuAHYAcgBwAG8AdwBlAHIAbQBhAG4AYQBn
>> "%~1" echo AGUAcgAuAHAAcgBvAHgAXwBjAGwAbwBzAGUAAR/yXdFTAZAgAHAAcgBvAHgAXwBj
>> "%~1" echo AGwAbwBzAGUAAjABEXcAaQByAGUAbABlAHMAcwAABS0AcwABC3QAYwBwAGkAcAAA
>> "%~1" echo CTUANQA1ADUAACPyXfeLQmwAXy9U4GW/fiAAQQBEAEIAIAA1ADUANQA1AAIwARl3
>> "%~1" echo AGkAcgBlAGwAZQBzAHMAXwBvAGYAZgAATXMAZQB0AHQAaQBuAGcAcwAgAHAAdQB0
>> "%~1" echo ACAAZwBsAG8AYgBhAGwAIABhAGQAYgBfAHcAaQBmAGkAXwBlAG4AYQBiAGwAZQBk
>> "%~1" echo ACAAMAAAB3UAcwBiAABd8l33i0Jsc1HtleBlv34gAEEARABCAAz/YQBkAGIAZAAg
>> "%~1" echo APJdB1LeViAAVQBTAEIAIAAhag9fAjDlglNfTVIvZuBlv37ej6VjDP+tZQBfXlyO
>> "%~1" echo TmNrOF6wc2GMAjABE2sAZQB5AF8AcwBsAGUAZQBwAAAl8l3RUwGQIABLAEUAWQBD
>> "%~1" echo AE8ARABFAF8AUwBMAEUARQBQAAIwARVrAGUAeQBfAHcAYQBrAGUAdQBwAAA7aQBu
>> "%~1" echo AHAAdQB0ACAAawBlAHkAZQB2AGUAbgB0ACAASwBFAFkAQwBPAEQARQBfAFcAQQBL
>> "%~1" echo AEUAVQBQAABD8l3RUwGQIABLAEUAWQBDAE8ARABFAF8AVwBBAEsARQBVAFAAAjDF
>> "%~1" echo TihXIABBAEQAQgAgAM1OKFe/fvZlCWdIZQIwARNzAGMAcgBlAGUAbgBfADUAbQAA
>> "%~1" echo W3MAZQB0AHQAaQBuAGcAcwAgAHAAdQB0ACAAcwB5AHMAdABlAG0AIABzAGMAcgBl
>> "%~1" echo AGUAbgBfAG8AZgBmAF8AdABpAG0AZQBvAHUAdAAgADMAMAAwADAAMAAwAAA5cwBj
>> "%~1" echo AHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAIAA9ACAAMwAwADAAMAAw
>> "%~1" echo ADAAAjABFXMAYwByAGUAZQBuAF8AMgA0AGgAAF9zAGUAdAB0AGkAbgBnAHMAIABw
>> "%~1" echo AHUAdAAgAHMAeQBzAHQAZQBtACAAcwBjAHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBt
>> "%~1" echo AGUAbwB1AHQAIAA4ADYANAAwADAAMAAwADAAAD1zAGMAcgBlAGUAbgBfAG8AZgBm
>> "%~1" echo AF8AdABpAG0AZQBvAHUAdAAgAD0AIAA4ADYANAAwADAAMAAwADAAAjABEXMAdABh
>> "%~1" echo AHkAXwBvAGYAZgAAXXMAZQB0AHQAaQBuAGcAcwAgAHAAdQB0ACAAZwBsAG8AYgBh
>> "%~1" echo AGwAIABzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBnAGUAZABf
>> "%~1" echo AGkAbgAgADAAADtzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABlAF8AcABsAHUAZwBn
>> "%~1" echo AGUAZABfAGkAbgAgAD0AIAAwAAIwARdzAHQAYQB5AF8AdQBzAGIAXwBhAGMAAF1z
>> "%~1" echo AGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcAbABvAGIAYQBsACAAcwB0AGEAeQBf
>> "%~1" echo AG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4AIAAzAAA7cwB0
>> "%~1" echo AGEAeQBfAG8AbgBfAHcAaABpAGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4AIAA9
>> "%~1" echo ACAAMwACMAEhcgBlAHMAZQB0AF8AcwBjAHIAZQBlAG4AXwBvAGYAZgAAQfJdzZFu
>> "%~1" echo fyAAcwBjAHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1AHQAIAA9ACAAMwAw
>> "%~1" echo ADAAMAAwADAAAjABG3IAZQBzAGUAdABfAHMAdABhAHkAXwBvAG4AAEPyXc2Rbn8g
>> "%~1" echo AHMAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBu
>> "%~1" echo ACAAPQAgADAAAjABIXIAZQBzAGUAdABfAHcAaQBmAGkAXwBzAGwAZQBlAHAAAE9z
>> "%~1" echo AGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAGcAbABvAGIAYQBsACAAdwBpAGYAaQBf
>> "%~1" echo AHMAbABlAGUAcABfAHAAbwBsAGkAYwB5ACAAMQAANfJdzZFufyAAdwBpAGYAaQBf
>> "%~1" echo AHMAbABlAGUAcABfAHAAbwBsAGkAYwB5ACAAPQAgADEAAjABJ3IAZQBzAGUAdABf
>> "%~1" echo AHMAbABlAGUAcABfAHQAaQBtAGUAbwB1AHQAAElzAGUAdAB0AGkAbgBnAHMAIABk
>> "%~1" echo AGUAbABlAHQAZQAgAHMAZQBjAHUAcgBlACAAcwBsAGUAZQBwAF8AdABpAG0AZQBv
>> "%~1" echo AHUAdAAAQfJdIFJkliAAcwBsAGUAZQBwAF8AdABpAG0AZQBvAHUAdAAgAHZe0VMB
>> "%~1" echo kCAAcAByAG8AeABfAG8AcABlAG4AAjABHWMAdQBzAHQAbwBtAF8AcwBlAHQAdABp
>> "%~1" echo AG4AZwAABW4AcwAAB2sAZQB5AAALdgBhAGwAdQBlAAAjbgBhAG0AZQBzAHAAYQBj
>> "%~1" echo AGUAIAAWYi6VDVQNTghU1WwCMAEr5YsulQ1UXlyOTtiazphplvt8334ulQz/8l07
>> "%~1" echo lmJr6oGaW0lOmVFlUQIwARtzAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAAADLgAA
>> "%~1" echo ByAAPQAgAAAhYwB1AHMAdABvAG0AXwBiAHIAbwBhAGQAYwBhAHMAdAAACW4AYQBt
>> "%~1" echo AGUAABF/Xq1kDVTweQ1OCFTVbAIwASFhAG0AIABiAHIAbwBhAGQAYwBhAHMAdAAg
>> "%~1" echo AC0AYQAgAAEN8l3RUwGQf16tZBr/AQsqZ+V3zWRcTwIwAQvNZFxPjFsQYhr/AREg
>> "%~1" echo AHIAZQBzAHUAbAB0AD0AAAVvAGsAAAtlAHIAcgBvAHIAAAvNZFxPMVkljRr/AQ8g
>> "%~1" echo AGUAcgByAG8AcgA9AAAJdABlAHgAdAAAJfxb+lEAX8tZGv/qU/uLjFt0Zb6LB1nh
>> "%~1" echo T29gIABIAFQATQBMAAEfeQB5AHkAeQBNAE0AZABkAF8ASABIAG0AbQBzAHMAAA9l
>> "%~1" echo AHgAcABvAHIAdABzAAA3UQB1AGUAcwB0ADMAXwBkAGUAdgBpAGMAZQBfAHAAcgBp
>> "%~1" echo AHYAYQB0AGUAXwBmAHUAbABsAF8AAAsuAGgAdABtAGwAADNRAHUAZQBzAHQAMwBf
>> "%~1" echo AGQAZQB2AGkAYwBlAF8AcwBoAGEAcgBlAF8AcwBhAGYAZQBfAAAXcAByAGkAdgBh
>> "%~1" echo AHQAZQBQAGEAdABoAAARcwBhAGYAZQBQAGEAdABoAAAVcAByAGkAdgBhAHQAZQBV
>> "%~1" echo AHIAbAAAD3MAYQBmAGUAVQByAGwAABVkAHUAcgBhAHQAaQBvAG4ATQBzAAAZcwBl
>> "%~1" echo AGMAdABpAG8AbgBDAG8AdQBuAHQAABF3AGEAcgBuAGkAbgBnAHMAAAcgAHwAIAAA
>> "%~1" echo KfJdH3UQYsF5CWeMW3RlSHKMVAZSq06JW2hRSHIgAEgAVABNAEwAAjABC/xb+lGM
>> "%~1" echo WxBiGv8BByAALwAgAAAL/Fv6UTFZJY0a/wEPPwB0AG8AawBlAG4APQAABS4ALgAA
>> "%~1" echo DV6X1WylYkpU742EXwELpWJKVA1OWFsoVwEP+4vWU6ViSlQxWSWNGv8BT3MAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAHAAdQB0ACAAZwBsAG8AYgBhAGwAIAB3AGkAZgBpAF8AcwBs
>> "%~1" echo AGUAZQBwAF8AcABvAGwAaQBjAHkAIAAyAABJcwBlAHQAdABpAG4AZwBzACAAcAB1
>> "%~1" echo AHQAIABzAGUAYwB1AHIAZQAgAHMAbABlAGUAcABfAHQAaQBtAGUAbwB1AHQAIAAt
>> "%~1" echo ADEAAR1RAHUAZQBzAHQAXwBBAEQAQgBfAEwAbwBnAHMAAA13AGUAYgB1AGkAXwAA
>> "%~1" echo CS4AbABvAGcAAAEAJ1EAdQBlAHMAdABfAEEARABCAF8AVwBlAGIAVQBJAC4AbABv
>> "%~1" echo AGcAAC95AHkAeQB5AC0ATQBNAC0AZABkACAASABIADoAbQBtADoAcwBzAC4AZgBm
>> "%~1" echo AGYAAQUgACAAABPlZddfh2X2ThpcKmcbUvpeAjABD/uL1lPlZddfMVkljRr/AVkq
>> "%~1" echo Z9FTsHMgAEEARABCACAAvosHWQIwwGjlZwBf0VMFgCFqD18BMFUAUwBCACAAA4zV
>> "%~1" echo i4hjQ2cBMHBlbmO/foxUIABXAGkAbgBkAG8AdwBzACAAcZqoUgIwAQ9kAGUAdgBp
>> "%~1" echo AGMAZQBzAAAFLQBsAAEPTABpAHMAdAAgAG8AZgAAF20AbwBkAGUAbAA6AFEAdQBl
>> "%~1" echo AHMAdAAAHXAAcgBvAGQAdQBjAHQAOgBlAHUAcgBlAGsAYQAAG2QAZQB2AGkAYwBl
>> "%~1" echo ADoAZQB1AHIAZQBrAGEAABl1AG4AYQB1AHQAaABvAHIAaQB6AGUAZAAAD28AZgBm
>> "%~1" echo AGwAaQBuAGUAADHyXd6PpWN2XvJdiGNDZwz/8l0YT0hRCZDpYiAAVQBTAEIAIABR
>> "%~1" echo AHUAZQBzAHQAAjABJfJd3o+lY3Ze8l2IY0NnDP/yXQmQ6WIgAFEAdQBlAHMAdAAC
>> "%~1" echo MAFP8l3ej6Vjdl7yXYhjQ2cCMOhsD2Ea/ypnxosrUjBSIABRAHUAZQBzAHQAIACL
>> "%~1" echo V/dTDP/yXQmQ6WIsewBOKk4gAEEARABCACAAvosHWQIwATu+iwdZKmeIY0NnGv80
>> "%~1" echo YgpONFk+Zgz/KFcgAFUAUwBCACAAA4zVi4hjQ2c5X5d6zJEJkOliQVG4iwIwATu+
>> "%~1" echo iwdZu3m/fhr/zZEvVCAAQQBEAEIAIAANZ6FSATDNkdJjIABVAFMAQgAgABZi9GZi
>> "%~1" echo Y3BlbmO/fgIwARXRU7BzvosHWUZPtnIBYAJfOF4a/wEPdQBuAGsAbgBvAHcAbgAA
>> "%~1" echo CW4AbwBuAGUAABFnAGUAdABwAHIAbwBwACAAABtzAGUAdAB0AGkAbgBnAHMAIABn
>> "%~1" echo AGUAdAAgAAAJbgB1AGwAbAAAC3MAaABlAGwAbAAAE0EARABCACAAfVTkToWN9mUa
>> "%~1" echo /wETQQBEAEIAIAB9VOROMVkljSgAAQUpABr/ASUjACAAUQB1AGUAcwB0ACAAQQBE
>> "%~1" echo AEIAIADlXXdRvotufwdZ/U4BEyMAIABkAGUAdgBpAGMAZQA9AAAVIwAgAGMAcgBl
>> "%~1" echo AGEAdABlAGQAPQAAJ3kAeQB5AHkALQBNAE0ALQBkAGQAIABIAEgAOgBtAG0AOgBz
>> "%~1" echo AHMAARHyXRtS+l6+i25/B1n9Thr/ARH7i9ZTB1n9TjxQMVkljRr/AROhbAlnfmIw
>> "%~1" echo UgdZ/U6HZfZOGv8BAyMAACFzAGUAdAB0AGkAbgBnAHMAIABkAGUAbABlAHQAZQAg
>> "%~1" echo AAAP8l3OTgdZ/U5iYA1ZGv8BAzoAAANfAAADXAAAJ3EAdQBlAHMAdABfAGEAZABi
>> "%~1" echo AF8AcwBlAHQAdABpAG4AZwBzAF8AAAkuAGIAYQBrAAAfZAB1AG0AcABzAHkAcwAg
>> "%~1" echo AGIAYQB0AHQAZQByAHkAAAtsAGUAdgBlAGwAABd0AGUAbQBwAGUAcgBhAHQAdQBy
>> "%~1" echo AGUAAAcwAC4AIwAAG2IAYQB0AHQAZQByAHkAUwB0AGEAdAB1AHMAAA1zAHQAYQB0
>> "%~1" echo AHUAcwAAG2IAYQB0AHQAZQByAHkASABlAGEAbAB0AGgAAA1oAGUAYQBsAHQAaAAA
>> "%~1" echo F3AAbwB3AGUAcgBTAG8AdQByAGMAZQAAG2QAdQBtAHAAcwB5AHMAIABwAG8AdwBl
>> "%~1" echo AHIAABltAFcAYQBrAGUAZgB1AGwAbgBlAHMAcwAAD20AUwB0AGEAeQBPAG4AACVt
>> "%~1" echo AFAAcgBvAHgAaQBtAGkAdAB5AFAAbwBzAGkAdABpAHYAZQAAHW0AUwB0AGEAeQBP
>> "%~1" echo AG4AUwBlAHQAdABpAG4AZwAAOW0AUwB0AGEAeQBPAG4AVwBoAGkAbABlAFAAbAB1
>> "%~1" echo AGcAZwBlAGQASQBuAFMAZQB0AHQAaQBuAGcAAB1wAG8AdwBlAHIAUwBsAGUAZQBw
>> "%~1" echo AEwAaQBuAGUAAB1TAGwAZQBlAHAAIAB0AGkAbQBlAG8AdQB0ADoAACtjAG8AbgB0
>> "%~1" echo AHIAbwBsAGwAZQByAEwAZQBmAHQAQgBhAHQAdABlAHIAeQAALWMAbwBuAHQAcgBv
>> "%~1" echo AGwAbABlAHIAUgBpAGcAaAB0AEIAYQB0AHQAZQByAHkAACljAG8AbgB0AHIAbwBs
>> "%~1" echo AGwAZQByAEwAZQBmAHQAUwB0AGEAdAB1AHMAACtjAG8AbgB0AHIAbwBsAGwAZQBy
>> "%~1" echo AFIAaQBnAGgAdABTAHQAYQB0AHUAcwAAHWMAbwBuAHQAcgBvAGwAbABlAHIASABp
>> "%~1" echo AG4AdAAAEypn+4vWUzBSS2LEZzV1z5ECMAExZAB1AG0AcABzAHkAcwAgAE8AVgBS
>> "%~1" echo AFIAZQBtAG8AdABlAFMAZQByAHYAaQBjAGUAABFCAGEAdAB0AGUAcgB5ADoAAAtU
>> "%~1" echo AHkAcABlADoAAAlUAHkAcABlAAAPQgBhAHQAdABlAHIAeQAADVMAdABhAHQAdQBz
>> "%~1" echo AAAJTABlAGYAdAAAC1IAaQBnAGgAdAAAD3MAdABvAHIAYQBnAGUAAA1tAGUAbQBv
>> "%~1" echo AHIAeQAAG2QAZgAgAC0AaAAgAC8AcwBkAGMAYQByAGQAARVGAGkAbABlAHMAeQBz
>> "%~1" echo AHQAZQBtAAAJIADyXSh1IAABI2MAYQB0ACAALwBwAHIAbwBjAC8AbQBlAG0AaQBu
>> "%~1" echo AGYAbwAAE00AZQBtAFQAbwB0AGEAbAA6AAAbTQBlAG0AQQB2AGEAaQBsAGEAYgBs
>> "%~1" echo AGUAOgAAB+9TKHUgAAENIAAvACAAO2ChiyAAARN2AGQAUABhAGMAawBhAGcAZQAA
>> "%~1" echo E3YAZABWAGUAcgBzAGkAbwBuAAAtVgBpAHIAdAB1AGEAbABEAGUAcwBrAHQAbwBw
>> "%~1" echo AC4AQQBuAGQAcgBvAGkAZAAAIWQAdQBtAHAAcwB5AHMAIABwAGEAYwBrAGEAZwBl
>> "%~1" echo ACAAABNQAGEAYwBrAGEAZwBlACAAWwAAA10AABl2AGUAcgBzAGkAbwBuAE4AYQBt
>> "%~1" echo AGUAPQAAHWQAaQBzAHAAbABhAHkAUwB1AG0AbQBhAHIAeQAAH2QAdQBtAHAAcwB5
>> "%~1" echo AHMAIABkAGkAcwBwAGwAYQB5AAAjRABpAHMAcABsAGEAeQBEAGUAdgBpAGMAZQBJ
>> "%~1" echo AG4AZgBvAAAvKABcAGQAewAzACwANQB9AFwAcwAqAHgAXABzACoAXABkAHsAMwAs
>> "%~1" echo ADUAfQApAAA3cgBlAG4AZABlAHIARgByAGEAbQBlAFIAYQB0AGUAXABzACsAKABb
>> "%~1" echo ADAALQA5AC4AXQArACkAASVkAGUAbgBzAGkAdAB5AFwAcwArACgAWwAwAC0AOQBd
>> "%~1" echo ACsAKQABL0QAZQB2AGkAYwBlAFAAcgBvAGQAdQBjAHQASQBuAGYAbwB7AG4AYQBt
>> "%~1" echo AGUAPQAAAywAAAVIAHoAABFkAGUAbgBzAGkAdAB5ACAAAB10AGgAZQByAG0AYQBs
>> "%~1" echo AFMAdQBtAG0AYQByAHkAAC1kAHUAbQBwAHMAeQBzACAAdABoAGUAcgBtAGEAbABz
>> "%~1" echo AGUAcgB2AGkAYwBlAAAdVABoAGUAcgBtAGEAbAAgAFMAdABhAHQAdQBzAABDbQBO
>> "%~1" echo AGEAbQBlAD0AYgBhAHQAdABlAHIAeQAsAFwAcwAqAG0AVgBhAGwAdQBlAD0AKABb
>> "%~1" echo ADAALQA5AC4AXQArACkAAT1iAGEAdAB0AGUAcgB5AFsAXgAwAC0AOQBdACsAKABb
>> "%~1" echo ADAALQA5AF0AKwBcAC4AWwAwAC0AOQBdACsAKQABD3MAdABhAHQAdQBzACAAABcg
>> "%~1" echo AC8AIABiAGEAdAB0AGUAcgB5ACAAAANDAAAdZgBhAGMAdABvAHIAeQBTAHUAbQBt
>> "%~1" echo AGEAcgB5AAArZAB1AG0AcABzAHkAcwAgAHMAZQBuAHMAbwByAHMAZQByAHYAaQBj
>> "%~1" echo AGUAABNCAHUAaQBsAGQAVAB5AHAAZQAAFUQAZQB2AGkAYwBlAFQAeQBwAGUAABNU
>> "%~1" echo AGkAbQBlAHMAdABhAG0AcAAAF2wAbwBjAGEAdABpAG8AbgBfAGkAZAAAFXMAdABh
>> "%~1" echo AHQAaQBvAG4AXwBpAGQAABFGAGEAYwB0AG8AcgB5ACAAAAlsAG8AYwAgAAARcwB0
>> "%~1" echo AGEAdABpAG8AbgAgAAAXYQBkAGIAXwBkAGUAdgBpAGMAZQBzAAAFaQBkAAAPZwBl
>> "%~1" echo AHQAcAByAG8AcAAAH3MAZQB0AHQAaQBuAGcAcwBfAGcAbABvAGIAYQBsAAApcwBl
>> "%~1" echo AHQAdABpAG4AZwBzACAAbABpAHMAdAAgAGcAbABvAGIAYQBsAAAfcwBlAHQAdABp
>> "%~1" echo AG4AZwBzAF8AcwB5AHMAdABlAG0AAClzAGUAdAB0AGkAbgBnAHMAIABsAGkAcwB0
>> "%~1" echo ACAAcwB5AHMAdABlAG0AAB9zAGUAdAB0AGkAbgBnAHMAXwBzAGUAYwB1AHIAZQAA
>> "%~1" echo KXMAZQB0AHQAaQBuAGcAcwAgAGwAaQBzAHQAIABzAGUAYwB1AHIAZQAAD2IAYQB0
>> "%~1" echo AHQAZQByAHkAAAtwAG8AdwBlAHIAAA9kAGkAcwBwAGwAYQB5AAAXZAB1AG0AcABz
>> "%~1" echo AHkAcwAgAHUAcwBiAAAJdwBpAGYAaQAAGWQAdQBtAHAAcwB5AHMAIAB3AGkAZgBp
>> "%~1" echo AAAZYwBvAG4AbgBlAGMAdABpAHYAaQB0AHkAAClkAHUAbQBwAHMAeQBzACAAYwBv
>> "%~1" echo AG4AbgBlAGMAdABpAHYAaQB0AHkAABNiAGwAdQBlAHQAbwBvAHQAaAAAM2QAdQBt
>> "%~1" echo AHAAcwB5AHMAIABiAGwAdQBlAHQAbwBvAHQAaABfAG0AYQBuAGEAZwBlAHIAAA1j
>> "%~1" echo AGEAbQBlAHIAYQAAKWQAdQBtAHAAcwB5AHMAIABtAGUAZABpAGEALgBjAGEAbQBl
>> "%~1" echo AHIAYQAAG3MAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAAA90AGgAZQByAG0AYQBs
>> "%~1" echo AAALaQBuAHAAdQB0AAAbZAB1AG0AcABzAHkAcwAgAGkAbgBwAHUAdAAAEXAAYQBj
>> "%~1" echo AGsAYQBnAGUAcwAALXAAbQAgAGwAaQBzAHQAIABwAGEAYwBrAGEAZwBlAHMAIAAt
>> "%~1" echo AGYAIAAtAGkAARFmAGUAYQB0AHUAcgBlAHMAACFwAG0AIABsAGkAcwB0ACAAZgBl
>> "%~1" echo AGEAdAB1AHIAZQBzAAATbABpAGIAcgBhAHIAaQBlAHMAADVjAG0AZAAgAHAAYQBj
>> "%~1" echo AGsAYQBnAGUAIABsAGkAcwB0ACAAbABpAGIAcgBhAHIAaQBlAHMAAAVkAGYAACdk
>> "%~1" echo AGYAIAAtAGgAIAAvAGQAYQB0AGEAIAAvAHMAZABjAGEAcgBkAAEPbQBlAG0AaQBu
>> "%~1" echo AGYAbwAAD2MAcAB1AGkAbgBmAG8AACNjAGEAdAAgAC8AcAByAG8AYwAvAGMAcAB1
>> "%~1" echo AGkAbgBmAG8AAAt1AG4AYQBtAGUAABF1AG4AYQBtAGUAIAAtAGEAAQ9pAHAAXwBh
>> "%~1" echo AGQAZAByAAAPaQBwACAAYQBkAGQAcgAAEWkAcABfAHIAbwB1AHQAZQAAEWkAcAAg
>> "%~1" echo AHIAbwB1AHQAZQAAHXYAaQByAHQAdQBhAGwAZABlAHMAawB0AG8AcAAATWQAdQBt
>> "%~1" echo AHAAcwB5AHMAIABwAGEAYwBrAGEAZwBlACAAVgBpAHIAdAB1AGEAbABEAGUAcwBr
>> "%~1" echo AHQAbwBwAC4AQQBuAGQAcgBvAGkAZAAAH28AYwB1AGwAdQBzAF8AcABhAGMAawBh
>> "%~1" echo AGcAZQBzAAA1ZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBnAGUAIABjAG8AbQAu
>> "%~1" echo AG8AYwB1AGwAdQBzAAAnbABvAGcAYwBhAHQAXwB0AGEAaQBsAF8AcAByAGkAdgBh
>> "%~1" echo AHQAZQAAI2wAbwBnAGMAYQB0ACAALQBkACAALQB0ACAAMwAwADAAMAABCWEAZABi
>> "%~1" echo ACAAAAcgAIWN9mUBCSAAMVkljRr/AQ8gANdTUJYWYuBlk4/6UQEPYwByAGUAYQB0
>> "%~1" echo AGUAZAAAD3AAcgBvAGQAdQBjAHQAABdmAGkAbgBnAGUAcgBwAHIAaQBuAHQAACly
>> "%~1" echo AG8ALgBiAHUAaQBsAGQALgBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAAA1rAGUAcgBu
>> "%~1" echo AGUAbAAAAyUAABNwAHIAbwB4AGkAbQBpAHQAeQAAB2MAcAB1AAALcABhAG4AZQBs
>> "%~1" echo AAAjRABlAHYAaQBjAGUAUAByAG8AZAB1AGMAdABJAG4AZgBvAAAPZgBhAGMAdABv
>> "%~1" echo AHIAeQAAG2YAYQBjAHQAbwByAHkARABlAHYAaQBjAGUAABlmAGEAYwB0AG8AcgB5
>> "%~1" echo AEIAdQBpAGwAZAAAF2YAYQBjAHQAbwByAHkAVABpAG0AZQAAH2YAYQBjAHQAbwBy
>> "%~1" echo AHkATABvAGMAYQB0AGkAbwBuAAAdZgBhAGMAdABvAHIAeQBTAHQAYQB0AGkAbwBu
>> "%~1" echo AAAlZgBhAGMAdABvAHIAeQBTAHQAYQB0AGkAbwBuAFQAeQBwAGUAABlzAHQAYQB0
>> "%~1" echo AGkAbwBuAF8AdAB5AHAAZQAAF2YAYQBjAHQAbwByAHkAVABlAHMAdAAAF2MAYQBs
>> "%~1" echo AF8AdABlAHMAdABfAGkAZAAAH2YAYQBjAHQAbwByAHkATwBwAGUAcgBhAHQAbwBy
>> "%~1" echo AAAXbwBwAGUAcgBhAHQAbwByAF8AaQBkAAAlZgBhAGMAdABvAHIAeQBDAGEAbABp
>> "%~1" echo AGIAcgBhAHQAaQBvAG4AACFjAGEAbABpAGIAcgBhAHQAaQBvAG4AXwB0AHkAcABl
>> "%~1" echo AAAjbwBuAGwAaQBuAGUAQwBhAGwAaQBiAHIAYQB0AGkAbwBuAAAvdgBlAGcAYQBf
>> "%~1" echo AG8AbgBsAGkAbgBlAF8AYwBhAGwAaQBiAHIAYQB0AGkAbwBuAAA3wGhLbTBSIAB2
>> "%~1" echo AGUAZwBhAF8AbwBuAGwAaQBuAGUAXwBjAGEAbABpAGIAcgBhAHQAaQBvAG4AARFm
>> "%~1" echo AGUAYQB0AHUAcgBlADoAAAV2AGQAADFRAHUAZQBzAHQAIABBAEQAQgAgAL6LB1mh
>> "%~1" echo W6GLpWJKVCAALQAgAMF5CWeMW3RlSHIBMVEAdQBlAHMAdAAgAEEARABCACAAvosH
>> "%~1" echo WaFboYulYkpUIAAtACAABlKrTolbaFFIcgEZUABSAEkAVgBBAFQARQAgAEYAVQBM
>> "%~1" echo AEwAABVTAEgAQQBSAEUALQBTAEEARgBFAAELUQBBAEQAQgAtAAEfeQB5AHkAeQBN
>> "%~1" echo AE0AZABkAC0ASABIAG0AbQBzAHMAAYERPAAhAGQAbwBjAHQAeQBwAGUAIABoAHQA
>> "%~1" echo bQBsAD4APABoAHQAbQBsACAAbABhAG4AZwA9ACIAegBoAC0AQwBOACIAPgA8AGgA
>> "%~1" echo ZQBhAGQAPgA8AG0AZQB0AGEAIABjAGgAYQByAHMAZQB0AD0AIgB1AHQAZgAtADgA
>> "%~1" echo IgA+ADwAbQBlAHQAYQAgAG4AYQBtAGUAPQAiAHYAaQBlAHcAcABvAHIAdAAiACAA
>> "%~1" echo YwBvAG4AdABlAG4AdAA9ACIAdwBpAGQAdABoAD0AZABlAHYAaQBjAGUALQB3AGkA
>> "%~1" echo ZAB0AGgALABpAG4AaQB0AGkAYQBsAC0AcwBjAGEAbABlAD0AMQAiAD4APAB0AGkA
>> "%~1" echo dABsAGUAPgABETwALwB0AGkAdABsAGUAPgAADzwAcwB0AHkAbABlAD4AAI2zOgBy
>> "%~1" echo AG8AbwB0AHsALQAtAHAAYQBnAGUAOgAjAGUAZQBmADEAZgA1ADsALQAtAHAAYQBw
>> "%~1" echo AGUAcgA6ACMAZgBmAGYAOwAtAC0AaQBuAGsAOgAjADEAOAAyADAAMwAzADsALQAt
>> "%~1" echo AG0AdQB0AGUAZAA6ACMANgA2ADcAMAA4ADUAOwAtAC0AbABpAG4AZQA6ACMAZAA4
>> "%~1" echo AGUAMABlAGIAOwAtAC0AbABpAG4AZQAyADoAIwBlAGQAZgAxAGYANgA7AC0ALQBz
>> "%~1" echo AG8AZgB0ADoAIwBmADcAZgA5AGYAYwA7AC0ALQBhAGMAYwBlAG4AdAA6ACMAMQBk
>> "%~1" echo ADQAZQBkADgAOwAtAC0AYQBjAGMAZQBuAHQAMgA6ACMAMABmADEANwAyAGEAOwAt
>> "%~1" echo AC0AbwBrADoAIwAxADEAOAA0ADQANwA7AC0ALQB3AGEAcgBuADoAIwA5AGEANQBi
>> "%~1" echo ADAAMAA7AC0ALQBzAGgAYQBkAG8AdwA6ADAAIAAxADgAcAB4ACAANAA4AHAAeAAg
>> "%~1" echo AHIAZwBiAGEAKAAxADUALAAyADMALAA0ADIALAAuADEAMwApAH0AKgB7AGIAbwB4
>> "%~1" echo AC0AcwBpAHoAaQBuAGcAOgBiAG8AcgBkAGUAcgAtAGIAbwB4AH0AaAB0AG0AbAAs
>> "%~1" echo AGIAbwBkAHkAewBtAGEAcgBnAGkAbgA6ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBk
>> "%~1" echo ADoAdgBhAHIAKAAtAC0AcABhAGcAZQApADsAYwBvAGwAbwByADoAdgBhAHIAKAAt
>> "%~1" echo AC0AaQBuAGsAKQA7AGYAbwBuAHQAOgAxADQAcAB4AC8AMQAuADUAMgAgACIAUwBl
>> "%~1" echo AGcAbwBlACAAVQBJACIALAAiAE0AaQBjAHIAbwBzAG8AZgB0ACAAWQBhAEgAZQBp
>> "%~1" echo ACIALABBAHIAaQBhAGwALABzAGEAbgBzAC0AcwBlAHIAaQBmADsAbABlAHQAdABl
>> "%~1" echo AHIALQBzAHAAYQBjAGkAbgBnADoAMAB9AC4AcwBoAGUAZQB0AHsAdwBpAGQAdABo
>> "%~1" echo ADoAbQBpAG4AKAAxADEAMgAwAHAAeAAsAGMAYQBsAGMAKAAxADAAMAAlACAALQAg
>> "%~1" echo ADQAMABwAHgAKQApADsAbQBhAHIAZwBpAG4AOgAzADAAcAB4ACAAYQB1AHQAbwA7
>> "%~1" echo AGIAYQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBwAGEAcABlAHIAKQA7
>> "%~1" echo AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAAjAGQAZgBlADYAZgAw
>> "%~1" echo ADsAYgBvAHgALQBzAGgAYQBkAG8AdwA6AHYAYQByACgALQAtAHMAaABhAGQAbwB3
>> "%~1" echo ACkAfQAuAHAAYQBkAHsAcABhAGQAZABpAG4AZwA6ADMAOABwAHgAIAA0ADQAcAB4
>> "%~1" echo AH0ALgBhAGMAdABpAG8AbgBzAHsAcABvAHMAaQB0AGkAbwBuADoAcwB0AGkAYwBr
>> "%~1" echo AHkAOwB0AG8AcAA6ADAAOwB6AC0AaQBuAGQAZQB4ADoAMwA7AGQAaQBzAHAAbABh
>> "%~1" echo AHkAOgBmAGwAZQB4ADsAagB1AHMAdABpAGYAeQAtAGMAbwBuAHQAZQBuAHQAOgBm
>> "%~1" echo AGwAZQB4AC0AZQBuAGQAOwBnAGEAcAA6ADgAcAB4ADsAdwBpAGQAdABoADoAbQBp
>> "%~1" echo AG4AKAAxADEAMgAwAHAAeAAsAGMAYQBsAGMAKAAxADAAMAAlACAALQAgADQAMABw
>> "%~1" echo AHgAKQApADsAbQBhAHIAZwBpAG4AOgAxADgAcAB4ACAAYQB1AHQAbwAgAC0AMQA2
>> "%~1" echo AHAAeAB9AC4AYgB0AG4AewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBk
>> "%~1" echo ACAAIwBjAGIAZAA1AGUAMQA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgAjAGYAZgBm
>> "%~1" echo ADsAYwBvAGwAbwByADoAIwAwAGYAMQA3ADIAYQA7AGIAbwByAGQAZQByAC0AcgBh
>> "%~1" echo AGQAaQB1AHMAOgA2AHAAeAA7AHAAYQBkAGQAaQBuAGcAOgA4AHAAeAAgADEAMgBw
>> "%~1" echo AHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAA7AGMAdQByAHMAbwBy
>> "%~1" echo ADoAcABvAGkAbgB0AGUAcgB9AC4AYgB0AG4ALgBwAHIAaQBtAGEAcgB5AHsAYgBh
>> "%~1" echo AGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAtAGEAYwBjAGUAbgB0ACkAOwBi
>> "%~1" echo AG8AcgBkAGUAcgAtAGMAbwBsAG8AcgA6AHYAYQByACgALQAtAGEAYwBjAGUAbgB0
>> "%~1" echo ACkAOwBjAG8AbABvAHIAOgAjAGYAZgBmAH0ALgBkAG8AYwAtAGgAZQBhAGQAewBk
>> "%~1" echo AGkAcwBwAGwAYQB5ADoAZwByAGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0
>> "%~1" echo AGUALQBjAG8AbAB1AG0AbgBzADoAMQBmAHIAIAAzADQAMABwAHgAOwBnAGEAcAA6
>> "%~1" echo ADIAOABwAHgAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMwBwAHgAIABz
>> "%~1" echo AG8AbABpAGQAIAB2AGEAcgAoAC0ALQBhAGMAYwBlAG4AdAAyACkAOwBwAGEAZABk
>> "%~1" echo AGkAbgBnAC0AYgBvAHQAdABvAG0AOgAyADQAcAB4AH0ALgBrAGkAYwBrAGUAcgB7
>> "%~1" echo AGQAaQBzAHAAbABhAHkAOgBpAG4AbABpAG4AZQAtAGIAbABvAGMAawA7AGMAbwBs
>> "%~1" echo AG8AcgA6AHYAYQByACgALQAtAGEAYwBjAGUAbgB0ACkAOwBmAG8AbgB0AC0AcwBp
>> "%~1" echo AHoAZQA6ADEAMgBwAHgAOwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAA7
>> "%~1" echo AGwAZQB0AHQAZQByAC0AcwBwAGEAYwBpAG4AZwA6AC4AMAA4AGUAbQA7AHQAZQB4
>> "%~1" echo AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlADsAbQBh
>> "%~1" echo AHIAZwBpAG4ALQBiAG8AdAB0AG8AbQA6ADEAMABwAHgAfQBoADEAewBmAG8AbgB0
>> "%~1" echo AC0AcwBpAHoAZQA6ADMAMgBwAHgAOwBsAGkAbgBlAC0AaABlAGkAZwBoAHQAOgAx
>> "%~1" echo AC4AMQAyADsAbQBhAHIAZwBpAG4AOgAwACAAMAAgADEAMABwAHgAOwBmAG8AbgB0
>> "%~1" echo AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAA7AGMAbwBsAG8AcgA6ACMAMABmADEANwAy
>> "%~1" echo AGEAfQAuAHMAdQBiAHsAYwBvAGwAbwByADoAdgBhAHIAKAAtAC0AbQB1AHQAZQBk
>> "%~1" echo ACkAOwBtAGEAeAAtAHcAaQBkAHQAaAA6ADYAOAAwAHAAeAA7AG0AYQByAGcAaQBu
>> "%~1" echo ADoAMAB9AC4AbQBlAHQAYQB7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABp
>> "%~1" echo AGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBhAGwAaQBnAG4ALQBzAGUAbABm
>> "%~1" echo ADoAcwB0AGEAcgB0ADsAbQBpAG4ALQB3AGkAZAB0AGgAOgAwAH0ALgBtAGUAdABh
>> "%~1" echo AC0AcgBvAHcAewBkAGkAcwBwAGwAYQB5ADoAZwByAGkAZAA7AGcAcgBpAGQALQB0
>> "%~1" echo AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQAxADgAcAB4ACAAbQBp
>> "%~1" echo AG4AbQBhAHgAKAAwACwAMQBmAHIAKQA7AGIAbwByAGQAZQByAC0AYgBvAHQAdABv
>> "%~1" echo AG0AOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAMgAp
>> "%~1" echo ADsAbQBpAG4ALQBoAGUAaQBnAGgAdAA6ADMAOABwAHgAfQAuAG0AZQB0AGEALQBy
>> "%~1" echo AG8AdwA6AGwAYQBzAHQALQBjAGgAaQBsAGQAewBiAG8AcgBkAGUAcgAtAGIAbwB0
>> "%~1" echo AHQAbwBtADoAMAB9AC4AbQBlAHQAYQAtAHIAbwB3ACAAcwBwAGEAbgB7AGIAYQBj
>> "%~1" echo AGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBjAG8AbABv
>> "%~1" echo AHIAOgB2AGEAcgAoAC0ALQBtAHUAdABlAGQAKQA7AGYAbwBuAHQALQB3AGUAaQBn
>> "%~1" echo AGgAdAA6ADgAMAAwADsAcABhAGQAZABpAG4AZwA6ADkAcAB4ACAAMQAyAHAAeAA7
>> "%~1" echo AGIAbwByAGQAZQByAC0AcgBpAGcAaAB0ADoAMQBwAHgAIABzAG8AbABpAGQAIAB2
>> "%~1" echo AGEAcgAoAC0ALQBsAGkAbgBlADIAKQB9AC4AbQBlAHQAYQAtAHIAbwB3ACAAYgB7
>> "%~1" echo AHAAYQBkAGQAaQBuAGcAOgA5AHAAeAAgADEAMgBwAHgAOwBtAGkAbgAtAHcAaQBk
>> "%~1" echo AHQAaAA6ADAAOwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoAYQBuAHkAdwBo
>> "%~1" echo AGUAcgBlADsAdwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEAawAtAHcAbwBy
>> "%~1" echo AGQAfQAuAHMAdABhAG0AcAB7AGQAaQBzAHAAbABhAHkAOgBpAG4AbABpAG4AZQAt
>> "%~1" echo AGIAbABvAGMAawA7AGIAbwByAGQAZQByADoAMgBwAHgAIABzAG8AbABpAGQAIAAB
>> "%~1" echo F3YAYQByACgALQAtAHcAYQByAG4AKQABE3YAYQByACgALQAtAG8AawApAAEPOwBj
>> "%~1" echo AG8AbABvAHIAOgAAmwc7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwADsA
>> "%~1" echo cABhAGQAZABpAG4AZwA6ADQAcAB4ACAAOABwAHgAOwBiAG8AcgBkAGUAcgAtAHIA
>> "%~1" echo YQBkAGkAdQBzADoANABwAHgAOwB0AHIAYQBuAHMAZgBvAHIAbQA6AHIAbwB0AGEA
>> "%~1" echo dABlACgALQAxAGQAZQBnACkAfQAuAHAAYQByAHQAeQAtAGcAcgBpAGQAewBkAGkA
>> "%~1" echo cwBwAGwAYQB5ADoAZwByAGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUA
>> "%~1" echo LQBjAG8AbAB1AG0AbgBzADoAMQBmAHIAIAAxAGYAcgA7AGcAYQBwADoAMQA4AHAA
>> "%~1" echo eAA7AG0AYQByAGcAaQBuADoAMgA2AHAAeAAgADAAfQAuAGIAbwB4AHsAYgBvAHIA
>> "%~1" echo ZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUA
>> "%~1" echo KQA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgAjAGYAZgBmADsAbQBpAG4ALQB3AGkA
>> "%~1" echo ZAB0AGgAOgAwAH0ALgBiAG8AeAAgAGgAMgAsAC4AcwBlAGMAdABpAG8AbgAgAGgA
>> "%~1" echo MgB7AGYAbwBuAHQALQBzAGkAegBlADoAMQAzAHAAeAA7AHQAZQB4AHQALQB0AHIA
>> "%~1" echo YQBuAHMAZgBvAHIAbQA6AHUAcABwAGUAcgBjAGEAcwBlADsAbABlAHQAdABlAHIA
>> "%~1" echo LQBzAHAAYQBjAGkAbgBnADoALgAwADgAZQBtADsAYwBvAGwAbwByADoAIwAzADQA
>> "%~1" echo NAAwADUANAA7AG0AYQByAGcAaQBuADoAMAA7AGIAYQBjAGsAZwByAG8AdQBuAGQA
>> "%~1" echo OgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQA
>> "%~1" echo bwBtADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkA
>> "%~1" echo OwBwAGEAZABkAGkAbgBnADoAMQAwAHAAeAAgADEAMgBwAHgAfQAuAGIAbwB4AC0A
>> "%~1" echo YgBvAGQAeQB7AHAAYQBkAGQAaQBuAGcAOgAxADMAcAB4ACAAMQA0AHAAeAB9AC4A
>> "%~1" echo YgBpAGcAewBmAG8AbgB0AC0AcwBpAHoAZQA6ADIAMgBwAHgAOwBmAG8AbgB0AC0A
>> "%~1" echo dwBlAGkAZwBoAHQAOgA5ADAAMAA7AG0AYQByAGcAaQBuAC0AYgBvAHQAdABvAG0A
>> "%~1" echo OgA2AHAAeAB9AC4AbQB1AHQAZQBkAHsAYwBvAGwAbwByADoAdgBhAHIAKAAtAC0A
>> "%~1" echo bQB1AHQAZQBkACkAfQAuAGMAaABpAHAAcwB7AGQAaQBzAHAAbABhAHkAOgBmAGwA
>> "%~1" echo ZQB4ADsAZgBsAGUAeAAtAHcAcgBhAHAAOgB3AHIAYQBwADsAZwBhAHAAOgA3AHAA
>> "%~1" echo eAA7AG0AYQByAGcAaQBuAC0AdABvAHAAOgAxADIAcAB4AH0ALgBjAGgAaQBwAHsA
>> "%~1" echo YgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwA
>> "%~1" echo aQBuAGUAKQA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8A
>> "%~1" echo ZgB0ACkAOwBiAG8AcgBkAGUAcgAtAHIAYQBkAGkAdQBzADoAOQA5ADkAcAB4ADsA
>> "%~1" echo cABhAGQAZABpAG4AZwA6ADUAcAB4ACAAOQBwAHgAOwBmAG8AbgB0AC0AdwBlAGkA
>> "%~1" echo ZwBoAHQAOgA4ADAAMAB9AC4AcwB1AG0AbQBhAHIAeQB7AGQAaQBzAHAAbABhAHkA
>> "%~1" echo OgBnAHIAaQBkADsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUA
>> "%~1" echo bQBuAHMAOgByAGUAcABlAGEAdAAoADQALABtAGkAbgBtAGEAeAAoADAALAAxAGYA
>> "%~1" echo cgApACkAOwBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIA
>> "%~1" echo KAAtAC0AbABpAG4AZQApADsAbQBhAHIAZwBpAG4AOgAyADAAcAB4ACAAMAAgADIA
>> "%~1" echo NABwAHgAfQAuAHMAdQBtAC0AYwBlAGwAbAB7AHAAYQBkAGQAaQBuAGcAOgAxADMA
>> "%~1" echo cAB4ACAAMQA0AHAAeAA7AGIAbwByAGQAZQByAC0AcgBpAGcAaAB0ADoAMQBwAHgA
>> "%~1" echo IABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQA7AG0AaQBuAC0A
>> "%~1" echo dwBpAGQAdABoADoAMAB9AC4AcwB1AG0ALQBjAGUAbABsADoAbABhAHMAdAAtAGMA
>> "%~1" echo aABpAGwAZAB7AGIAbwByAGQAZQByAC0AcgBpAGcAaAB0ADoAMAB9AC4AcwB1AG0A
>> "%~1" echo LQBjAGUAbABsACAAcwBwAGEAbgB7AGQAaQBzAHAAbABhAHkAOgBiAGwAbwBjAGsA
>> "%~1" echo OwBjAG8AbABvAHIAOgB2AGEAcgAoAC0ALQBtAHUAdABlAGQAKQA7AGYAbwBuAHQA
>> "%~1" echo LQBzAGkAegBlADoAMQAyAHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgA
>> "%~1" echo MAAwADsAdABlAHgAdAAtAHQAcgBhAG4AcwBmAG8AcgBtADoAdQBwAHAAZQByAGMA
>> "%~1" echo YQBzAGUAfQAuAHMAdQBtAC0AYwBlAGwAbAAgAGIAewBkAGkAcwBwAGwAYQB5ADoA
>> "%~1" echo YgBsAG8AYwBrADsAZgBvAG4AdAAtAHMAaQB6AGUAOgAxADgAcAB4ADsAbQBhAHIA
>> "%~1" echo ZwBpAG4ALQB0AG8AcAA6ADUAcAB4ADsAbwB2AGUAcgBmAGwAbwB3AC0AdwByAGEA
>> "%~1" echo cAA6AGEAbgB5AHcAaABlAHIAZQA7AHcAbwByAGQALQBiAHIAZQBhAGsAOgBiAHIA
>> "%~1" echo ZQBhAGsALQB3AG8AcgBkAH0ALgBzAGUAYwB0AGkAbwBuAHsAbQBhAHIAZwBpAG4A
>> "%~1" echo LQB0AG8AcAA6ADIAMgBwAHgAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQB7AHcA
>> "%~1" echo aQBkAHQAaAA6ADEAMAAwACUAOwBiAG8AcgBkAGUAcgAtAGMAbwBsAGwAYQBwAHMA
>> "%~1" echo ZQA6AGMAbwBsAGwAYQBwAHMAZQA7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8A
>> "%~1" echo bABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwB0AGEAYgBsAGUALQBsAGEA
>> "%~1" echo eQBvAHUAdAA6AGYAaQB4AGUAZAB9AC4AYQB1AGQAaQB0AC0AdABhAGIAbABlACAA
>> "%~1" echo dABoAHsAYgBhAGMAawBnAHIAbwB1AG4AZAA6ACMAZgAyAGYANQBmADkAOwBjAG8A
>> "%~1" echo bABvAHIAOgAjADMANAA0ADAANQA0ADsAdABlAHgAdAAtAGEAbABpAGcAbgA6AGwA
>> "%~1" echo ZQBmAHQAOwBmAG8AbgB0AC0AcwBpAHoAZQA6ADEAMgBwAHgAOwB0AGUAeAB0AC0A
>> "%~1" echo dAByAGEAbgBzAGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQA7AGwAZQB0AHQA
>> "%~1" echo ZQByAC0AcwBwAGEAYwBpAG4AZwA6AC4AMAA2AGUAbQA7AGIAbwByAGQAZQByAC0A
>> "%~1" echo YgBvAHQAdABvAG0AOgAyAHAAeAAgAHMAbwBsAGkAZAAgACMAMQAxADEAOAAyADcA
>> "%~1" echo OwBwAGEAZABkAGkAbgBnADoAMQAwAHAAeAAgADEAMgBwAHgAfQAuAGEAdQBkAGkA
>> "%~1" echo dAAtAHQAYQBiAGwAZQAgAHQAZAB7AGIAbwByAGQAZQByAC0AdABvAHAAOgAxAHAA
>> "%~1" echo eAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAMgApADsAcABhAGQA
>> "%~1" echo ZABpAG4AZwA6ADEAMABwAHgAIAAxADIAcAB4ADsAdgBlAHIAdABpAGMAYQBsAC0A
>> "%~1" echo YQBsAGkAZwBuADoAdABvAHAAOwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoA
>> "%~1" echo YQBuAHkAdwBoAGUAcgBlADsAdwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEA
>> "%~1" echo awAtAHcAbwByAGQAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4A
>> "%~1" echo dABoAC0AYwBoAGkAbABkACgAMQApAHsAdwBpAGQAdABoADoAMgAyACUAOwBjAG8A
>> "%~1" echo bABvAHIAOgAjADQANwA1ADQANgA3ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoA
>> "%~1" echo OAAwADAAfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0A
>> "%~1" echo YwBoAGkAbABkACgAMgApAHsAdwBpAGQAdABoADoANAA0ACUAOwBmAG8AbgB0AC0A
>> "%~1" echo dwBlAGkAZwBoAHQAOgA4ADAAMAA7AGMAbwBsAG8AcgA6ACMAMQAwADEAOAAyADgA
>> "%~1" echo fQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQAZAA6AG4AdABoAC0AYwBoAGkA
>> "%~1" echo bABkACgAMwApAHsAdwBpAGQAdABoADoAMwA0ACUAOwBjAG8AbABvAHIAOgAjADYA
>> "%~1" echo NgA3ADAAOAA1AH0ALgBuAG8AdABlAHsAYgBvAHIAZABlAHIALQBsAGUAZgB0ADoA
>> "%~1" echo NABwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQB3AGEAcgBuACkAOwBiAGEA
>> "%~1" echo YwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgA4AGUAYgA7AGIAbwByAGQAZQByAC0A
>> "%~1" echo dABvAHAAOgAxAHAAeAAgAHMAbwBsAGkAZAAgACMAZgAzAGQAMQA5AGMAOwBiAG8A
>> "%~1" echo cgBkAGUAcgAtAHIAaQBnAGgAdAA6ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBmADMA
>> "%~1" echo ZAAxADkAYwA7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0AOgAxAHAAeAAgAHMA
>> "%~1" echo bwBsAGkAZAAgACMAZgAzAGQAMQA5AGMAOwBwAGEAZABkAGkAbgBnADoAMQAzAHAA
>> "%~1" echo eAAgADEANABwAHgAOwBtAGEAcgBnAGkAbgAtAHQAbwBwADoAMQA4AHAAeAB9AC4A
>> "%~1" echo cgBhAHcAIABkAGUAdABhAGkAbABzAHsAYgBvAHIAZABlAHIAOgAxAHAAeAAgAHMA
>> "%~1" echo bwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAKQA7AG0AYQByAGcAaQBuADoA
>> "%~1" echo MQAwAHAAeAAgADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAIwBmAGYAZgB9AC4A
>> "%~1" echo cgBhAHcAIABzAHUAbQBtAGEAcgB5AHsAYwB1AHIAcwBvAHIAOgBwAG8AaQBuAHQA
>> "%~1" echo ZQByADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAtAHMAbwBmAHQA
>> "%~1" echo KQA7AHAAYQBkAGQAaQBuAGcAOgAxADAAcAB4ACAAMQAyAHAAeAA7AGYAbwBuAHQA
>> "%~1" echo LQB3AGUAaQBnAGgAdAA6ADkAMAAwAH0ALgByAGEAdwAgAHAAcgBlAHsAbQBhAHIA
>> "%~1" echo ZwBpAG4AOgAwADsAbQBhAHgALQBoAGUAaQBnAGgAdAA6ADQAMgAwAHAAeAA7AG8A
>> "%~1" echo dgBlAHIAZgBsAG8AdwA6AGEAdQB0AG8AOwB3AGgAaQB0AGUALQBzAHAAYQBjAGUA
>> "%~1" echo OgBwAHIAZQAtAHcAcgBhAHAAOwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoA
>> "%~1" echo YQBuAHkAdwBoAGUAcgBlADsAdwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEA
>> "%~1" echo awAtAHcAbwByAGQAOwBjAG8AbABvAHIAOgAjADQANwA1ADQANgA3ADsAcABhAGQA
>> "%~1" echo ZABpAG4AZwA6ADEAMgBwAHgAOwBmAG8AbgB0ADoAMQAyAHAAeAAvADEALgA1ACAA
>> "%~1" echo QwBvAG4AcwBvAGwAYQBzACwAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFkAYQBIAGUA
>> "%~1" echo aQAiACwAbQBvAG4AbwBzAHAAYQBjAGUAfQAuAGYAbwBvAHQAewBkAGkAcwBwAGwA
>> "%~1" echo YQB5ADoAZwByAGkAZAA7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8A
>> "%~1" echo bAB1AG0AbgBzADoAMQBmAHIAIABhAHUAdABvADsAZwBhAHAAOgAyADAAcAB4ADsA
>> "%~1" echo YQBsAGkAZwBuAC0AaQB0AGUAbQBzADoAZQBuAGQAOwBtAGEAcgBnAGkAbgAtAHQA
>> "%~1" echo bwBwADoAMgA4AHAAeAA7AGIAbwByAGQAZQByAC0AdABvAHAAOgAyAHAAeAAgAHMA
>> "%~1" echo bwBsAGkAZAAgACMAMQAxADEAOAAyADcAOwBwAGEAZABkAGkAbgBnAC0AdABvAHAA
>> "%~1" echo OgAxADYAcAB4AH0ALgBmAG8AbwB0ACAAYgB7AGYAbwBuAHQALQBzAGkAegBlADoA
>> "%~1" echo MQAyAHAAeAA7AHQAZQB4AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUAcABwAGUA
>> "%~1" echo cgBjAGEAcwBlADsAbABlAHQAdABlAHIALQBzAHAAYQBjAGkAbgBnADoALgAwADgA
>> "%~1" echo ZQBtAH0ALgB0AG8AdABhAGwAewBtAGkAbgAtAHcAaQBkAHQAaAA6ADIANQAwAHAA
>> "%~1" echo eAA7AGIAbwByAGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0A
>> "%~1" echo LQBsAGkAbgBlACkAfQAuAHQAbwB0AGEAbAAgAGQAaQB2AHsAZABpAHMAcABsAGEA
>> "%~1" echo eQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0AYwBvAGwA
>> "%~1" echo dQBtAG4AcwA6ADEAZgByACAAYQB1AHQAbwA7AHAAYQBkAGQAaQBuAGcAOgA5AHAA
>> "%~1" echo eAAgADEAMgBwAHgAOwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgA
>> "%~1" echo IABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQB9AC4AdABvAHQA
>> "%~1" echo YQBsACAAZABpAHYAOgBsAGEAcwB0AC0AYwBoAGkAbABkAHsAYgBvAHIAZABlAHIA
>> "%~1" echo LQBiAG8AdAB0AG8AbQA6ADAAOwBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBhAHIA
>> "%~1" echo KAAtAC0AcwBvAGYAdAApADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOQAwADAA
>> "%~1" echo fQBAAG0AZQBkAGkAYQAoAG0AYQB4AC0AdwBpAGQAdABoADoAOAA2ADAAcAB4ACkA
>> "%~1" echo ewAuAGQAbwBjAC0AaABlAGEAZAAsAC4AcABhAHIAdAB5AC0AZwByAGkAZAAsAC4A
>> "%~1" echo cwB1AG0AbQBhAHIAeQB7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8A
>> "%~1" echo bAB1AG0AbgBzADoAMQBmAHIAfQAuAHAAYQBkAHsAcABhAGQAZABpAG4AZwA6ADIA
>> "%~1" echo NABwAHgAIAAxADgAcAB4AH0ALgBzAGgAZQBlAHQALAAuAGEAYwB0AGkAbwBuAHMA
>> "%~1" echo ewB3AGkAZAB0AGgAOgBjAGEAbABjACgAMQAwADAAJQAgAC0AIAAxADgAcAB4ACkA
>> "%~1" echo fQAuAHMAdQBtAG0AYQByAHkAewBkAGkAcwBwAGwAYQB5ADoAYgBsAG8AYwBrAH0A
>> "%~1" echo LgBzAHUAbQAtAGMAZQBsAGwAewBiAG8AcgBkAGUAcgAtAHIAaQBnAGgAdAA6ADAA
>> "%~1" echo OwBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMQBwAHgAIABzAG8AbABpAGQA
>> "%~1" echo IAB2AGEAcgAoAC0ALQBsAGkAbgBlADIAKQB9AC4AYQB1AGQAaQB0AC0AdABhAGIA
>> "%~1" echo bABlAHsAdABhAGIAbABlAC0AbABhAHkAbwB1AHQAOgBhAHUAdABvAH0ALgBhAHUA
>> "%~1" echo ZABpAHQALQB0AGEAYgBsAGUAIAB0AGgAOgBuAHQAaAAtAGMAaABpAGwAZAAoADMA
>> "%~1" echo KQAsAC4AYQB1AGQAaQB0AC0AdABhAGIAbABlACAAdABkADoAbgB0AGgALQBjAGgA
>> "%~1" echo aQBsAGQAKAAzACkAewBkAGkAcwBwAGwAYQB5ADoAbgBvAG4AZQB9AC4AZgBvAG8A
>> "%~1" echo dAB7AGcAcgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoA
>> "%~1" echo MQBmAHIAfQAuAHQAbwB0AGEAbAB7AG0AaQBuAC0AdwBpAGQAdABoADoAMAB9AH0A
>> "%~1" echo QABtAGUAZABpAGEAKABtAGEAeAAtAHcAaQBkAHQAaAA6ADUAMgAwAHAAeAApAHsA
>> "%~1" echo LgBtAGUAdABhAC0AcgBvAHcAewBnAHIAaQBkAC0AdABlAG0AcABsAGEAdABlAC0A
>> "%~1" echo YwBvAGwAdQBtAG4AcwA6ADEAMAA1AHAAeAAgAG0AaQBuAG0AYQB4ACgAMAAsADEA
>> "%~1" echo ZgByACkAfQBoADEAewBmAG8AbgB0AC0AcwBpAHoAZQA6ADIAOABwAHgAfQAuAGEA
>> "%~1" echo YwB0AGkAbwBuAHMAewBqAHUAcwB0AGkAZgB5AC0AYwBvAG4AdABlAG4AdAA6AGYA
>> "%~1" echo bABlAHgALQBzAHQAYQByAHQAOwBvAHYAZQByAGYAbABvAHcAOgBhAHUAdABvAH0A
>> "%~1" echo fQBAAG0AZQBkAGkAYQAgAHAAcgBpAG4AdAB7AGIAbwBkAHkAewBiAGEAYwBrAGcA
>> "%~1" echo cgBvAHUAbgBkADoAIwBmAGYAZgB9AC4AYQBjAHQAaQBvAG4AcwB7AGQAaQBzAHAA
>> "%~1" echo bABhAHkAOgBuAG8AbgBlAH0ALgBzAGgAZQBlAHQAewB3AGkAZAB0AGgAOgBhAHUA
>> "%~1" echo dABvADsAbQBhAHIAZwBpAG4AOgAwADsAYgBvAHIAZABlAHIAOgAwADsAYgBvAHgA
>> "%~1" echo LQBzAGgAYQBkAG8AdwA6AG4AbwBuAGUAfQAuAHAAYQBkAHsAcABhAGQAZABpAG4A
>> "%~1" echo ZwA6ADAAfQAuAHIAYQB3ACAAcAByAGUAewBtAGEAeAAtAGgAZQBpAGcAaAB0ADoA
>> "%~1" echo bgBvAG4AZQB9AC4AYgBvAHgALAAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAsAC4A
>> "%~1" echo cgBhAHcAIABkAGUAdABhAGkAbABzAHsAYgByAGUAYQBrAC0AaQBuAHMAaQBkAGUA
>> "%~1" echo OgBhAHYAbwBpAGQAfQBAAHAAYQBnAGUAewBzAGkAegBlADoAQQA0ADsAbQBhAHIA
>> "%~1" echo ZwBpAG4AOgAxADMAbQBtAH0AfQABKzwALwBzAHQAeQBsAGUAPgA8AC8AaABlAGEA
>> "%~1" echo ZAA+ADwAYgBvAGQAeQA+AACBmTwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGEAYwB0
>> "%~1" echo AGkAbwBuAHMAIgA+ADwAYgB1AHQAdABvAG4AIABjAGwAYQBzAHMAPQAiAGIAdABu
>> "%~1" echo ACAAcAByAGkAbQBhAHIAeQAiACAAbwBuAGMAbABpAGMAawA9ACIAdwBpAG4AZABv
>> "%~1" echo AHcALgBwAHIAaQBuAHQAKAApACIAPgBTYnBTIAAvACAA3U9YWyAAUABEAEYAPAAv
>> "%~1" echo AGIAdQB0AHQAbwBuAD4APABiAHUAdAB0AG8AbgAgAGMAbABhAHMAcwA9ACIAYgB0
>> "%~1" echo AG4AIgAgAG8AbgBjAGwAaQBjAGsAPQAiAGQAbwBjAHUAbQBlAG4AdAAuAHEAdQBl
>> "%~1" echo AHIAeQBTAGUAbABlAGMAdABvAHIAQQBsAGwAKAAnAGQAZQB0AGEAaQBsAHMAJwAp
>> "%~1" echo AC4AZgBvAHIARQBhAGMAaAAoAGQAPQA+AGQALgBvAHAAZQBuAD0AdAByAHUAZQAp
>> "%~1" echo ACIAPgBVXABfRJZVXzwALwBiAHUAdAB0AG8AbgA+ADwALwBkAGkAdgA+AAFLPABt
>> "%~1" echo AGEAaQBuACAAYwBsAGEAcwBzAD0AIgBzAGgAZQBlAHQAIgA+ADwAZABpAHYAIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAHAAYQBkACIAPgAAgcE8AGgAZQBhAGQAZQByACAAYwBsAGEA
>> "%~1" echo cwBzAD0AIgBkAG8AYwAtAGgAZQBhAGQAIgA+ADwAZABpAHYAPgA8AGQAaQB2ACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBrAGkAYwBrAGUAcgAiAD4AUQB1AGUAcwB0ACAAQQBEAEIA
>> "%~1" echo IABUAG8AbwBsAHMAIAAvACAAUgBlAGEAZAAtAG8AbgBsAHkAIABlAHgAcABvAHIA
>> "%~1" echo dAA8AC8AZABpAHYAPgA8AGgAMQA+AFEAdQBlAHMAdAAgAEEARABCACAAvosHWaFb
>> "%~1" echo oYulYkpUPAAvAGgAMQA+ADwAcAAgAGMAbABhAHMAcwA9ACIAcwB1AGIAIgA+APpX
>> "%~1" echo jk5sUQBfIABBAEQAQgAgAOpT+4t9VOROH3UQYgz/KHWOTnRlBnQgAFEAdQBlAHMA
>> "%~1" echo dAAgADRZPmarjv1OATD7fN9+ATBlULdeATDlXYJTLwAhaMZRv34ifQEwBVMOTv2A
>> "%~1" echo m1ICMPxb+lFBbQt6DU6ZUWVRvotufwz/DU7uTzllvosHWQIwXE8FgEtt1Yu+iwdZ
>> "%~1" echo SHIsZxr/UQB1AGUAcwB0ACAAMwACMDwALwBwAD4APAAvAGQAaQB2AD4AAX08AGEA
>> "%~1" echo cwBpAGQAZQAgAGMAbABhAHMAcwA9ACIAbQBlAHQAYQAiAD4APABkAGkAdgAgAGMA
>> "%~1" echo bABhAHMAcwA9ACIAbQBlAHQAYQAtAHIAbwB3ACIAPgA8AHMAcABhAG4APgClYkpU
>> "%~1" echo Fn/3UzwALwBzAHAAYQBuAD4APABiAD4AAWk8AC8AYgA+ADwALwBkAGkAdgA+ADwA
>> "%~1" echo ZABpAHYAIABjAGwAYQBzAHMAPQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABzAHAA
>> "%~1" echo YQBuAD4AH3UQYvZl9JU8AC8AcwBwAGEAbgA+ADwAYgA+AAGAizwALwBiAD4APAAv
>> "%~1" echo AGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAbQBlAHQAYQAtAHIAbwB3
>> "%~1" echo ACIAPgA8AHMAcABhAG4APgCQlsF5p34rUjwALwBzAHAAYQBuAD4APABiAD4APABp
>> "%~1" echo ACAAYwBsAGEAcwBzAD0AIgBzAHQAYQBtAHAAIgA+AAGAgzwALwBpAD4APAAvAGIA
>> "%~1" echo PgA8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBtAGUAdABhAC0A
>> "%~1" echo cgBvAHcAIgA+ADwAcwBwAGEAbgA+AEEARABCACAAZWeQbjwALwBzAHAAYQBuAD4A
>> "%~1" echo PABiACAAdABpAHQAbABlAD0AIgABBSIAPgAANzwALwBiAD4APAAvAGQAaQB2AD4A
>> "%~1" echo PAAvAGEAcwBpAGQAZQA+ADwALwBoAGUAYQBkAGUAcgA+AACAvzwAcwBlAGMAdABp
>> "%~1" echo AG8AbgAgAGMAbABhAHMAcwA9ACIAcABhAHIAdAB5AC0AZwByAGkAZAAiAD4APABk
>> "%~1" echo AGkAdgAgAGMAbABhAHMAcwA9ACIAYgBvAHgAIgA+ADwAaAAyAD4AvosHWTwALwBo
>> "%~1" echo ADIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBiAG8AeAAtAGIAbwBkAHkAIgA+
>> "%~1" echo ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGIAaQBnACIAPgABMzwALwBkAGkAdgA+
>> "%~1" echo ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAG0AdQB0AGUAZAAiAD4AAGc8AC8AZABp
>> "%~1" echo AHYAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBwAHMAIgA+ADwAcwBw
>> "%~1" echo AGEAbgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4AUwBlAHIAaQBhAGwAIAAA
>> "%~1" echo NTwALwBzAHAAYQBuAD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBw
>> "%~1" echo ACIAPgAADyAALwAgAFMARABLACAAADM8AC8AcwBwAGEAbgA+ADwALwBkAGkAdgA+
>> "%~1" echo ADwALwBkAGkAdgA+ADwALwBkAGkAdgA+AACAizwAZABpAHYAIABjAGwAYQBzAHMA
>> "%~1" echo PQAiAGIAbwB4ACIAPgA8AGgAMgA+AMeRxpZWe2V1PAAvAGgAMgA+ADwAZABpAHYA
>> "%~1" echo IABjAGwAYQBzAHMAPQAiAGIAbwB4AC0AYgBvAGQAeQAiAD4APABkAGkAdgAgAGMA
>> "%~1" echo bABhAHMAcwA9ACIAYgBpAGcAIgA+AAELwXkJZ4xbdGVIcgELBlKrTolbaFFIcgEz
>> "%~1" echo 3U9ZdYxbdGXBeQlnwYtuYwz/ApAIVCxnOmdZdWNoG/8NToGJ9HalY2xRAF8GUqtO
>> "%~1" echo AjABffJdbpA9hY9eF1L3UwEwQFzfV1F/MFdAVwEwTQBBAEMALwBCAFMAUwBJAEQA
>> "%~1" echo ATBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAATBzAGUAcwBzAGkAbwBuACAASXtPZR9h
>> "%~1" echo V1u1axv/843HjyAAbABvAGcAYwBhAHQAIABEllVfAjABgVU8AC8AZABpAHYAPgA8
>> "%~1" echo AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBwAHMAIgA+ADwAcwBwAGEAbgAg
>> "%~1" echo AGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4ATgBvACAAQQBEAEIAIAB3AHIAaQB0
>> "%~1" echo AGUAPAAvAHMAcABhAG4APgA8AHMAcABhAG4AIABjAGwAYQBzAHMAPQAiAGMAaABp
>> "%~1" echo AHAAIgA+AEgAVABNAEwALwBQAEQARgAgAHIAZQBhAGQAeQA8AC8AcwBwAGEAbgA+
>> "%~1" echo ADwAcwBwAGEAbgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4AUQB1AGUAcwB0
>> "%~1" echo ACAAMwAgAG4AbwB0AGUAZAA8AC8AcwBwAGEAbgA+ADwALwBkAGkAdgA+ADwALwBk
>> "%~1" echo AGkAdgA+ADwALwBkAGkAdgA+ADwALwBzAGUAYwB0AGkAbwBuAD4AAICNPABzAGUA
>> "%~1" echo YwB0AGkAbwBuACAAYwBsAGEAcwBzAD0AIgBzAHUAbQBtAGEAcgB5ACIAPgA8AGQA
>> "%~1" echo aQB2ACAAYwBsAGEAcwBzAD0AIgBzAHUAbQAtAGMAZQBsAGwAIgA+ADwAcwBwAGEA
>> "%~1" echo bgA+ADV1z5EgAC8AIAApbqZePAAvAHMAcABhAG4APgA8AGIAPgABZTwALwBiAD4A
>> "%~1" echo PAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0ALQBjAGUA
>> "%~1" echo bABsACIAPgA8AHMAcABhAG4APgA+Zjp5PAAvAHMAcABhAG4APgA8AGIAPgABZTwA
>> "%~1" echo LwBiAD4APAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcwB1AG0A
>> "%~1" echo LQBjAGUAbABsACIAPgA8AHMAcABhAG4APgBYW6hQPAAvAHMAcABhAG4APgA8AGIA
>> "%~1" echo PgABZTwALwBiAD4APAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo cwB1AG0ALQBjAGUAbABsACIAPgA8AHMAcABhAG4APgAhaMZRPAAvAHMAcABhAG4A
>> "%~1" echo PgA8AGIAPgABKTwALwBiAD4APAAvAGQAaQB2AD4APAAvAHMAZQBjAHQAaQBvAG4A
>> "%~1" echo PgAACb6LB1mrjv1OAUFzAGUAcgBpAGEAbAB8AI9eF1L3U3wAYQBkAGIAIABkAGUA
>> "%~1" echo dgBpAGMAZQBzACAALwAgAGcAZQB0AHAAcgBvAHAAAUNkAGUAdgBpAGMAZQBMAGkA
>> "%~1" echo bgBlAHwAQQBEAEIAIAC+iwdZTIh8AGEAZABiACAAZABlAHYAaQBjAGUAcwAgAC0A
>> "%~1" echo bAABT20AYQBuAHUAZgBhAGMAdAB1AHIAZQByAHwAglNGVXwAcgBvAC4AcAByAG8A
>> "%~1" echo ZAB1AGMAdAAuAG0AYQBuAHUAZgBhAGMAdAB1AHIAZQByAAEzYgByAGEAbgBkAHwA
>> "%~1" echo wVRMcnwAcgBvAC4AcAByAG8AZAB1AGMAdAAuAGIAcgBhAG4AZAABM20AbwBkAGUA
>> "%~1" echo bAB8AItX91N8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBtAG8AZABlAGwAATlwAHIA
>> "%~1" echo bwBkAHUAYwB0AHwAp07BVONO91N8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBuAGEA
>> "%~1" echo bQBlAAE7ZABlAHYAaQBjAGUAfAC+iwdZ4073U3wAcgBvAC4AcAByAG8AZAB1AGMA
>> "%~1" echo dAAuAGQAZQB2AGkAYwBlAAEzYgBvAGEAcgBkAHwAf2enfnwAcgBvAC4AcAByAG8A
>> "%~1" echo ZAB1AGMAdAAuAGIAbwBhAHIAZAABKXMAbwBjAHwAUwBvAEMAfAByAG8ALgBzAG8A
>> "%~1" echo YwAuAG0AbwBkAGUAbAAANWEAYgBpAHwAQQBCAEkAfAByAG8ALgBwAHIAbwBkAHUA
>> "%~1" echo YwB0AC4AYwBwAHUALgBhAGIAaQAAC/t8334OToRn+l4BL2EAbgBkAHIAbwBpAGQA
>> "%~1" echo fABBAG4AZAByAG8AaQBkAHwAZwBlAHQAcAByAG8AcAAAH3MAZABrAHwAUwBEAEsA
>> "%~1" echo fABnAGUAdABwAHIAbwBwAAA5cwBlAGMAdQByAGkAdAB5AFAAYQB0AGMAaAB8APt8
>> "%~1" echo 336JW2hRZYgBTnwAZwBlAHQAcAByAG8AcAABP3YAZQBuAGQAbwByAFAAYQB0AGMA
>> "%~1" echo aAB8AFYAZQBuAGQAbwByACAAiVtoUWWIAU58AGcAZQB0AHAAcgBvAHAAATFiAHUA
>> "%~1" echo aQBsAGQASQBkAHwAQgB1AGkAbABkACAASQBEAHwAZwBlAHQAcAByAG8AcAAASWIA
>> "%~1" echo dQBpAGwAZABJAG4AYwByAGUAbQBlAG4AdABhAGwAfABJAG4AYwByAGUAbQBlAG4A
>> "%~1" echo dABhAGwAfABnAGUAdABwAHIAbwBwAAA1YgB1AGkAbABkAEIAcgBhAG4AYwBoAHwA
>> "%~1" echo QgByAGEAbgBjAGgAfABnAGUAdABwAHIAbwBwAAA/ZgBpAG4AZwBlAHIAcAByAGkA
>> "%~1" echo bgB0AHwARgBpAG4AZwBlAHIAcAByAGkAbgB0AHwAZwBlAHQAcAByAG8AcAAALWsA
>> "%~1" echo ZQByAG4AZQBsAHwASwBlAHIAbgBlAGwAfAB1AG4AYQBtAGUAIAAtAGEAASE+Zjp5
>> "%~1" echo IAAvACAANXWQbiAALwAgAFF/3H4gAC8AIADtcAE5ZABpAHMAcABsAGEAeQB8AD5m
>> "%~1" echo OnlYZIGJfABkAHUAbQBwAHMAeQBzACAAZABpAHMAcABsAGEAeQABNXAAYQBuAGUA
>> "%~1" echo bAB8AGKXf2e/fiJ9fABkAHUAbQBwAHMAeQBzACAAZABpAHMAcABsAGEAeQABP2IA
>> "%~1" echo YQB0AHQAZQByAHkATABlAHYAZQBsAHwANXXPkXwAZAB1AG0AcABzAHkAcwAgAGIA
>> "%~1" echo YQB0AHQAZQByAHkAAUFiAGEAdAB0AGUAcgB5AFQAZQBtAHAAfAA1dWBsKW6mXnwA
>> "%~1" echo ZAB1AG0AcABzAHkAcwAgAGIAYQB0AHQAZQByAHkAAUViAGEAdAB0AGUAcgB5AEgA
>> "%~1" echo ZQBhAGwAdABoAHwANXVgbGVQt158AGQAdQBtAHAAcwB5AHMAIABiAGEAdAB0AGUA
>> "%~1" echo cgB5AAE9cABvAHcAZQByAFMAbwB1AHIAYwBlAHwAm081dXwAZAB1AG0AcABzAHkA
>> "%~1" echo cwAgAGIAYQB0AHQAZQByAHkAAT13AGEAawBlAGYAdQBsAG4AZQBzAHMAfAAkVZKR
>> "%~1" echo tnIBYHwAZAB1AG0AcABzAHkAcwAgAHAAbwB3AGUAcgABSXMAdABhAHkATwBuAHwA
>> "%~1" echo 3U8BYyRVkpF8AHMAZQB0AHQAaQBuAGcAcwAgAC8AIABkAHUAbQBwAHMAeQBzACAA
>> "%~1" echo cABvAHcAZQByAAFJcAByAG8AeABpAG0AaQB0AHkAfAClY9GPtnIBYHwAZAB1AG0A
>> "%~1" echo cABzAHkAcwAgAHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAAUV0AGgAZQByAG0A
>> "%~1" echo YQBsAHwA7XC2cgFgfABkAHUAbQBwAHMAeQBzACAAdABoAGUAcgBtAGEAbABzAGUA
>> "%~1" echo cgB2AGkAYwBlAAEndQBzAGIAfABVAFMAQgB8AGQAdQBtAHAAcwB5AHMAIAB1AHMA
>> "%~1" echo YgAAQ3cAaQBmAGkAfABXAGkALQBGAGkAfABkAHUAbQBwAHMAeQBzACAAdwBpAGYA
>> "%~1" echo aQAgAC8AIABpAHAAIABhAGQAZAByAAFNYgBsAHUAZQB0AG8AbwB0AGgAfADdhFly
>> "%~1" echo fABkAHUAbQBwAHMAeQBzACAAYgBsAHUAZQB0AG8AbwB0AGgAXwBtAGEAbgBhAGcA
>> "%~1" echo ZQByAAFlYwBhAG0AZQByAGEAfAD4djpnLwAgTx9haFZ8AGQAdQBtAHAAcwB5AHMA
>> "%~1" echo IABtAGUAZABpAGEALgBjAGEAbQBlAHIAYQAgAC8AIABzAGUAbgBzAG8AcgBzAGUA
>> "%~1" echo cgB2AGkAYwBlAAEhcwB0AG8AcgBhAGcAZQB8AFhbqFB8AGQAZgAgAC0AaAABL20A
>> "%~1" echo ZQBtAG8AcgB5AHwAhVFYW3wALwBwAHIAbwBjAC8AbQBlAG0AaQBuAGYAbwABK2MA
>> "%~1" echo cAB1AHwAQwBQAFUAfAAvAHAAcgBvAGMALwBjAHAAdQBpAG4AZgBvAAAzRgBhAGMA
>> "%~1" echo dABvAHIAeQAgAC8AIABDAGEAbABpAGIAcgBhAHQAaQBvAG4AIABDUXBlbmMBX2YA
>> "%~1" echo YQBjAHQAbwByAHkARABlAHYAaQBjAGUAfABEAGUAdgBpAGMAZQBUAHkAcABlAHwA
>> "%~1" echo cwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAW2YA
>> "%~1" echo YQBjAHQAbwByAHkAQgB1AGkAbABkAHwAQgB1AGkAbABkAFQAeQBwAGUAfABzAGUA
>> "%~1" echo bgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABpZgBhAGMA
>> "%~1" echo dABvAHIAeQBUAGkAbQBlAHwARgBhAGMAdABvAHIAeQAgAFQAaQBtAGUAcwB0AGEA
>> "%~1" echo bQBwAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQA
>> "%~1" echo YQAAZWYAYQBjAHQAbwByAHkATABvAGMAYQB0AGkAbwBuAHwAbABvAGMAYQB0AGkA
>> "%~1" echo bwBuAF8AaQBkAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEA
>> "%~1" echo ZABhAHQAYQAAYWYAYQBjAHQAbwByAHkAUwB0AGEAdABpAG8AbgB8AHMAdABhAHQA
>> "%~1" echo aQBvAG4AXwBpAGQAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQA
>> "%~1" echo YQBkAGEAdABhAABtZgBhAGMAdABvAHIAeQBTAHQAYQB0AGkAbwBuAFQAeQBwAGUA
>> "%~1" echo fABzAHQAYQB0AGkAbwBuAF8AdAB5AHAAZQB8AHMAZQBuAHMAbwByAHMAZQByAHYA
>> "%~1" echo aQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAF1mAGEAYwB0AG8AcgB5AFQAZQBzAHQA
>> "%~1" echo fABjAGEAbABfAHQAZQBzAHQAXwBpAGQAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkA
>> "%~1" echo YwBlACAAbQBlAHQAYQBkAGEAdABhAABlZgBhAGMAdABvAHIAeQBPAHAAZQByAGEA
>> "%~1" echo dABvAHIAfABvAHAAZQByAGEAdABvAHIAXwBpAGQAfABzAGUAbgBzAG8AcgBzAGUA
>> "%~1" echo cgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAAB1ZgBhAGMAdABvAHIAeQBDAGEA
>> "%~1" echo bABpAGIAcgBhAHQAaQBvAG4AfABjAGEAbABpAGIAcgBhAHQAaQBvAG4AXwB0AHkA
>> "%~1" echo cABlAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQA
>> "%~1" echo YQAAd28AbgBsAGkAbgBlAEMAYQBsAGkAYgByAGEAdABpAG8AbgB8AE8AbgBsAGkA
>> "%~1" echo bgBlACAAYwBhAGwAaQBiAHIAYQB0AGkAbwBuAHwAcwBlAG4AcwBvAHIAcwBlAHIA
>> "%~1" echo dgBpAGMAZQAgAG0AZQB0AGEAZABhAHQAYQAAgX08AGQAaQB2ACAAYwBsAGEAcwBz
>> "%~1" echo AD0AIgBuAG8AdABlACIAPgA8AGIAPgCoY61luY9MdRr/PAAvAGIAPgDvU+VOsItV
>> "%~1" echo X76LB1nPZQEwbHj2TjaWtWsBMCFoxlGwi1VfjFTlXYJTS23Vi79+In0M/4tPglkg
>> "%~1" echo AFEAdQBlAHMAdAAgADMAIAAvACAARQB1AHIAZQBrAGEAIAAvACAAUABWAFQAIAAv
>> "%~1" echo ACAARgBhAGMAdABvAHIAeQAgAC8AIABPAG4AbABpAG4AZQAgAGMAYQBsAGkAYgBy
>> "%~1" echo AGEAdABpAG8AbgACMA1O/YCKYiAAbABvAGMAYQB0AGkAbwBuAF8AaQBkAAEwcwB0
>> "%~1" echo AGEAdABpAG8AbgBfAGkAZAABMHMAdABhAHQAaQBvAG4AXwB0AHkAcABlACAA71Ng
>> "%~1" echo l/t/0YsQYv1WtlsBMM5XAl4WYndRU0/lXYJTG/9XAGkALQBGAGkAIAD9VrZbAXhf
>> "%~1" echo Tg1OL2b6UadOMFcCMDwALwBkAGkAdgA+AAENBVMOTvt83379gJtSATtwAGEAYwBr
>> "%~1" echo AGEAZwBlAHMAfAAFU3Blz5F8AHAAbQAgAGwAaQBzAHQAIABwAGEAYwBrAGEAZwBl
>> "%~1" echo AHMAAUlmAGUAYQB0AHUAcgBlAHMAfABGAGUAYQB0AHUAcgBlACAAcGXPkXwAcABt
>> "%~1" echo ACAAbABpAHMAdAAgAGYAZQBhAHQAdQByAGUAcwABc3YAZAB8AFYAaQByAHQAdQBh
>> "%~1" echo AGwAIABEAGUAcwBrAHQAbwBwAHwAZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBn
>> "%~1" echo AGUAIABWAGkAcgB0AHUAYQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBk
>> "%~1" echo AAA9dwBhAHIAbgBpAG4AZwBzAHwAx5HGlmaLSlR8AGUAeABwAG8AcgB0ACAAYwBv
>> "%~1" echo AGwAbABlAGMAdABvAHIAAYHfPABmAG8AbwB0AGUAcgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo ZgBvAG8AdAAiAD4APABkAGkAdgA+ADwAYgA+AFEAdQBlAHMAdAAgAEEARABCACAA
>> "%~1" echo VABvAG8AbABzACAAYgB5ACAAZAB3AGcAeAAxADMAMwA3ADwALwBiAD4APABiAHIA
>> "%~1" echo PgA8AHMAcABhAG4AIABjAGwAYQBzAHMAPQAiAG0AdQB0AGUAZAAiAD4AUAB1AGIA
>> "%~1" echo bABpAGMAIAByAGUAcABvACAAcwBhAG0AcABsAGUAIABtAHUAcwB0ACAAdQBzAGUA
>> "%~1" echo IABzAGgAYQByAGUALQBzAGEAZgBlACAAZQB4AHAAbwByAHQALgAgAFAAcgBpAHYA
>> "%~1" echo YQB0AGUAIABmAHUAbABsACAAZQB4AHAAbwByAHQAIABpAHMAIABmAG8AcgAgAGwA
>> "%~1" echo bwBjAGEAbAAgAGUAdgBpAGQAZQBuAGMAZQAgAG8AbgBsAHkALgA8AC8AcwBwAGEA
>> "%~1" echo bgA+ADwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHQAbwB0AGEA
>> "%~1" echo bAAiAD4APABkAGkAdgA+ADwAcwBwAGEAbgA+AFAAYQBjAGsAYQBnAGUAcwA8AC8A
>> "%~1" echo cwBwAGEAbgA+ADwAYgA+AAFPPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2AD4A
>> "%~1" echo PABzAHAAYQBuAD4ARgBlAGEAdAB1AHIAZQBzADwALwBzAHAAYQBuAD4APABiAD4A
>> "%~1" echo AEs8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYAPgA8AHMAcABhAG4APgBTAHQA
>> "%~1" echo YQB0AHUAcwA8AC8AcwBwAGEAbgA+ADwAYgA+AAAPUAByAGkAdgBhAHQAZQAAFVMA
>> "%~1" echo aABhAHIAZQAtAHMAYQBmAGUAATM8AC8AYgA+ADwALwBkAGkAdgA+ADwALwBkAGkA
>> "%~1" echo dgA+ADwALwBmAG8AbwB0AGUAcgA+AAA3PAAvAGQAaQB2AD4APAAvAG0AYQBpAG4A
>> "%~1" echo PgA8AC8AYgBvAGQAeQA+ADwALwBoAHQAbQBsAD4AADs8AHMAZQBjAHQAaQBvAG4A
>> "%~1" echo IABjAGwAYQBzAHMAPQAiAHMAZQBjAHQAaQBvAG4AIgA+ADwAaAAyAD4AAIDDPAAv
>> "%~1" echo AGgAMgA+ADwAdABhAGIAbABlACAAYwBsAGEAcwBzAD0AIgBhAHUAZABpAHQALQB0
>> "%~1" echo AGEAYgBsAGUAIgA+ADwAdABoAGUAYQBkAD4APAB0AHIAPgA8AHQAaAA+AFdbtWs8
>> "%~1" echo AC8AdABoAD4APAB0AGgAPgA8UDwALwB0AGgAPgA8AHQAaAA+AMGLbmNlZ5BuPAAv
>> "%~1" echo AHQAaAA+ADwALwB0AHIAPgA8AC8AdABoAGUAYQBkAD4APAB0AGIAbwBkAHkAPgAB
>> "%~1" echo B0EARABCAAARPAB0AHIAPgA8AHQAZAA+AAATPAAvAHQAZAA+ADwAdABkAD4AABU8
>> "%~1" echo AC8AdABkAD4APAAvAHQAcgA+AAA1PAAvAHQAYgBvAGQAeQA+ADwALwB0AGEAYgBs
>> "%~1" echo AGUAPgA8AC8AcwBlAGMAdABpAG8AbgA+AABjPABzAGUAYwB0AGkAbwBuACAAYwBs
>> "%~1" echo AGEAcwBzAD0AIgBzAGUAYwB0AGkAbwBuACAAcgBhAHcAIgA+ADwAaAAyAD4An1PL
>> "%~1" echo WSAAQQBEAEIAIACTj/pRRJZVXzwALwBoADIAPgABDWwAbwBnAGMAYQB0AAAxCgAu
>> "%~1" echo AC4ALgAgAPJdKmKtZQz/jFt0ZYVRuVv3iwt3wXkJZ4xbdGVIciAALgAuAC4AASU8
>> "%~1" echo AGQAZQB0AGEAaQBsAHMAPgA8AHMAdQBtAG0AYQByAHkAPgAAByAAtwAgAAEVbQBz
>> "%~1" echo ACAAtwAgAGUAeABpAHQAIAABFSAAtwAgAHQAaQBtAGUAbwB1AHQAAR88AC8AcwB1
>> "%~1" echo AG0AbQBhAHIAeQA+ADwAcAByAGUAPgAAITwALwBwAHIAZQA+ADwALwBkAGUAdABh
>> "%~1" echo AGkAbABzAD4AABU8AC8AcwBlAGMAdABpAG8AbgA+AAA5ZwBlAHQAcAByAG8AcAAg
>> "%~1" echo AGQAaABjAHAALgB3AGwAYQBuADAALgBpAHAAYQBkAGQAcgBlAHMAcwAADzAALgAw
>> "%~1" echo AC4AMAAuADAAADVpAHAAIAAtAGYAIABpAG4AZQB0ACAAYQBkAGQAcgAgAHMAaABv
>> "%~1" echo AHcAIAB3AGwAYQBuADAAAQtpAG4AZQB0ACAAAAUiACIAAAMiAAAFXAAiAAADMgAA
>> "%~1" echo B0VRNXUtTgEDMwAAAzQAAAcqZ0VRNXUBAzUAAAfyXUVR4W4BBWNrOF4BBceP7XAB
>> "%~1" echo BV9jT1cBBcePi1MBAzcAAAXHj7dRARdBAEMAIABwAG8AdwBlAHIAZQBkADoAAAVB
>> "%~1" echo AEMAABlVAFMAQgAgAHAAbwB3AGUAcgBlAGQAOgAAB1UAUwBCAAAjVwBpAHIAZQBs
>> "%~1" echo AGUAcwBzACAAcABvAHcAZQByAGUAZAA6AAAF4GW/fgEHKmebTzV1AQM9AAAHIABH
>> "%~1" echo AEIAAANbAAAJXQA6ACAAWwAAK1wAIgBcAHMAKgA6AFwAcwAqAFwAIgAoAFsAXgBc
>> "%~1" echo ACIAXQAqACkAXAAiAAAnXAAiAFwAcwAqADoAXABzACoAKABbAF4ALAB9AFwAcwBd
>> "%~1" echo ACsAKQAACy8AZABhAHQAYQAAES8AcwB0AG8AcgBhAGcAZQAADSAAdQBzAGUAZAAg
>> "%~1" echo AAATcAByAG8AYwBlAHMAcwBvAHIAAD9DAFAAVQAgAHAAYQByAHQAXABzACoAOgBc
>> "%~1" echo AHMAKgAoADAAeABbADAALQA5AGEALQBmAEEALQBGAF0AKwApAAETIABjAG8AcgBl
>> "%~1" echo AHMAIAAvACAAACFpAGQAPQBcAGQAKwAsAFwAcwAqAHcAaQBkAHQAaAA9AAADMAAA
>> "%~1" echo DSAAbQBvAGQAZQBzAAATSABBAEwAIABSAGUAYQBkAHkAAAlIAEEATAAgAAARYgBh
>> "%~1" echo AHQAdABlAHIAeQAgAAAlYwBvAG4AbgBlAGMAdABlAGQAPQAoAFsAYQAtAHoAXQAr
>> "%~1" echo ACkAASdjAG8AbgBmAGkAZwB1AHIAZQBkAD0AKABbAGEALQB6AF0AKwApAAE5bQBD
>> "%~1" echo AHUAcgByAGUAbgB0AEYAdQBuAGMAdABpAG8AbgBzAD0AKABbAF4AXABuAFwAcgBd
>> "%~1" echo ACsAKQAAFWMAbwBuAG4AZQBjAHQAZQBkACAAABdjAG8AbgBmAGkAZwB1AHIAZQBk
>> "%~1" echo ACAAAD1zAHQAYQBuAGQAYQByAGQAOgBcAHMAKgAoAFsAMAAtADkAQQAtAFoAYQAt
>> "%~1" echo AHoAIAAuAF8ALQBdACsAKQABK0YAcgBlAHEAdQBlAG4AYwB5ADoAXABzACoAKABb
>> "%~1" echo ADAALQA5AF0AKwApAAEtTABpAG4AawAgAHMAcABlAGUAZAA6AFwAcwAqACgAWwAw
>> "%~1" echo AC0AOQBdACsAKQABJVIAUwBTAEkAOgBcAHMAKgAoAC0APwBbADAALQA5AF0AKwAp
>> "%~1" echo AAFPaQBuAGUAdABcAHMAKwAoAFsAMAAtADkAXQArAFwALgBbADAALQA5AF0AKwBc
>> "%~1" echo AC4AWwAwAC0AOQBdACsAXAAuAFsAMAAtADkAXQArACkAAQdJAFAAIAAAE3MAdABh
>> "%~1" echo AG4AZABhAHIAZAAgAAAHTQBIAHoAAAlNAGIAcABzAAALUgBTAFMASQAgAAAnZQBu
>> "%~1" echo AGEAYgBsAGUAZAA6AFwAcwAqACgAWwBhAC0AegBdACsAKQABJXMAdABhAHQAZQA6
>> "%~1" echo AFwAcwAqACgAWwBBAC0AWgBfAF0AKwApAAEhQgBsAHUAZQB0AG8AbwB0AGgAIABT
>> "%~1" echo AHQAYQB0AHUAcwAAEWUAbgBhAGIAbABlAGQAIAAAX0MAYQBtAGUAcgBhAEQAZQB2
>> "%~1" echo AGkAYwBlAEMAbABpAGUAbgB0AHwAQwBhAG0AZQByAGEAXABzACsASQBEAHwAPQA9
>> "%~1" echo ACAAQwBhAG0AZQByAGEAIABkAGUAdgBpAGMAZQAAKSIAUwBlAG4AcwBvAHIAVAB5
>> "%~1" echo AHAAZQAiADoAIgBPAEcAMAAxAEEAIgAAKyIAUwBlAG4AcwBvAHIAVAB5AHAAZQAi
>> "%~1" echo ADoAIgBPAFYANwAyADUAMQAiAAArIgBTAGUAbgBzAG8AcgBUAHkAcABlACIAOgAi
>> "%~1" echo AEkATQBYADQANwAxACIAAB8gAGMAYQBtAGUAcgBhACAAZQBuAHQAcgBpAGUAcwAA
>> "%~1" echo JWMAYQBsACAAcwBlAG4AcwBvAHIAcwAgAE8ARwAwADEAQQAgAAAVIAAvACAATwBW
>> "%~1" echo ADcAMgA1ADEAIAAAFSAALwAgAEkATQBYADQANwAxACAAAEFQAGEAYwBrAGEAZwBl
>> "%~1" echo ACAAWwBWAGkAcgB0AHUAYQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBk
>> "%~1" echo AF0AABFwAGEAYwBrAGEAZwBlADoAAC9WAEkAVgBFACAAQgB1AHMAaQBuAGUAcwBz
>> "%~1" echo ACAAUwB0AHIAZQBhAG0AaQBuAGcAADdWAEkAVgBFACAAQgB1AHMAaQBuAGUAcwBz
>> "%~1" echo ACAAUwB0AHIAZQBhAG0AaQBuAGcAIABBAEQAQgAAD0EAbgBkAHIAbwBpAGQAAB1w
>> "%~1" echo AGwAYQB0AGYAbwByAG0ALQB0AG8AbwBsAHMAATVBAG4AZAByAG8AaQBkACAAcABs
>> "%~1" echo AGEAdABmAG8AcgBtAC0AdABvAG8AbABzACAAQQBEAEIAAQ9hAGQAYgAuAGUAeABl
>> "%~1" echo AAAHYQBkAGIAAB1BAEQAQgAgAGUAeABlAGMAdQB0AGEAYgBsAGUAAAtbAEEALQBa
>> "%~1" echo AF0AAQtbADAALQA5AF0AASdcAGIAWwBBAC0AWgAwAC0AOQBdAHsAMQAyACwAMgAw
>> "%~1" echo AH0AXABiAAFNXABiACgAWwAwAC0AOQBBAC0ARgBhAC0AZgBdAHsAMgB9ADoAKQB7
>> "%~1" echo ADUAfQBbADAALQA5AEEALQBGAGEALQBmAF0AewAyAH0AXABiAAEjKgAqADoAKgAq
>> "%~1" echo ADoAKgAqADoAKgAqADoAKgAqADoAKgAqAAA9XABiADEAOQAyAFwALgAxADYAOABc
>> "%~1" echo AC4AXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAsADMAfQBcAGIAABcxADkAMgAu
>> "%~1" echo ADEANgA4AC4AeAAuAHgAAENcAGIAMQAwAFwALgBcAGQAewAxACwAMwB9AFwALgBc
>> "%~1" echo AGQAewAxACwAMwB9AFwALgBcAGQAewAxACwAMwB9AFwAYgAAETEAMAAuAHgALgB4
>> "%~1" echo AC4AeAAAY1wAYgAxADcAMgBcAC4AKAAxAFsANgAtADkAXQB8ADIAWwAwAC0AOQBd
>> "%~1" echo AHwAMwBbADAALQAxAF0AKQBcAC4AXABkAHsAMQAsADMAfQBcAC4AXABkAHsAMQAs
>> "%~1" echo ADMAfQBcAGIAARMxADcAMgAuAHgALgB4AC4AeAAAUSgAUwBTAEkARAB8AEIAUwBT
>> "%~1" echo AEkARAB8AFcAaQBmAGkAUwBzAGkAZAB8AG0AVwBpAGYAaQBJAG4AZgBvACkAWwBe
>> "%~1" echo ACwAXABuAFwAcgBdACoAABskADEAPQA8AHIAZQBkAGEAYwB0AGUAZAA+AABNcgBv
>> "%~1" echo AFwALgBiAHUAaQBsAGQAXAAuAGYAaQBuAGcAZQByAHAAcgBpAG4AdABcAF0AOgAg
>> "%~1" echo AFwAWwBbAF4AXABdAFwAbgBcAHIAXQArAABFcgBvAC4AYgB1AGkAbABkAC4AZgBp
>> "%~1" echo AG4AZwBlAHIAcAByAGkAbgB0AF0AOgAgAFsAPAByAGUAZABhAGMAdABlAGQAPgAA
>> "%~1" echo K2YAaQBuAGcAZQByAHAAcgBpAG4AdAA9AFsAXgAsAFwAbgBcAHIAXQArAAAtZgBp
>> "%~1" echo AG4AZwBlAHIAcAByAGkAbgB0AD0APAByAGUAZABhAGMAdABlAGQAPgAANW8AcwBf
>> "%~1" echo AGYAaQBuAGcAZQByAHAAcgBpAG4AdABbAF4ALABcAG4AXAByAFwAXAB9AF0AKwAA
>> "%~1" echo M28AcwBfAGYAaQBuAGcAZQByAHAAcgBpAG4AdAA9ADwAcgBlAGQAYQBjAHQAZQBk
>> "%~1" echo AD4AAC1zAGUAcwBzAGkAbwBuAF8AaQBkAFsAXgAsAFwAbgBcAHIAXABcAH0AXQAr
>> "%~1" echo AAArcwBlAHMAcwBpAG8AbgBfAGkAZAA9ADwAcgBlAGQAYQBjAHQAZQBkAD4AABE8
>> "%~1" echo AHMAZQByAGkAYQBsAD4AAAcqACoAKgAAAw0AADlkAGUAdgBlAGwAbwBwAG0AZQBu
>> "%~1" echo AHQAXwBzAGUAdAB0AGkAbgBnAHMAXwBlAG4AYQBiAGwAZQBkAAAlZABlAHYAaQBj
>> "%~1" echo AGUAXwBwAHIAbwB2AGkAcwBpAG8AbgBlAGQAACd1AHMAZQByAF8AcwBlAHQAdQBw
>> "%~1" echo AF8AYwBvAG0AcABsAGUAdABlAAAPdwBpAGYAaQBfAG8AbgAAIWEAaQByAHAAbABh
>> "%~1" echo AG4AZQBfAG0AbwBkAGUAXwBvAG4AABVoAHQAdABwAF8AcAByAG8AeAB5AAAjZwBs
>> "%~1" echo AG8AYgBhAGwAXwBoAHQAdABwAF8AcAByAG8AeAB5AAAvaQBuAHMAdABhAGwAbABf
>> "%~1" echo AG4AbwBuAF8AbQBhAHIAawBlAHQAXwBhAHAAcABzAAA5dgBlAHIAaQBmAGkAZQBy
>> "%~1" echo AF8AdgBlAHIAaQBmAHkAXwBhAGQAYgBfAGkAbgBzAHQAYQBsAGwAcwAAAycAAQkn
>> "%~1" echo AFwAJwAnAAELdABvAGsAZQBuAAADPwAAAysAAD9hAHAAcABsAGkAYwBhAHQAaQBv
>> "%~1" echo AG4ALwBqAHMAbwBuADsAIABjAGgAYQByAHMAZQB0AD0AdQB0AGYALQA4AAE/SABU
>> "%~1" echo AFQAUAAvADEALgAxACAAMgAwADAAIABPAEsADQAKAEMAbwBuAHQAZQBuAHQALQBU
>> "%~1" echo AHkAcABlADoAIAABJQ0ACgBDAG8AbgB0AGUAbgB0AC0ATABlAG4AZwB0AGgAOgAg
>> "%~1" echo AAFhDQAKAEMAYQBjAGgAZQAtAEMAbwBuAHQAcgBvAGwAOgAgAG4AbwAtAHMAdABv
>> "%~1" echo AHIAZQANAAoAQwBvAG4AbgBlAGMAdABpAG8AbgA6ACAAYwBsAG8AcwBlAA0ACgAN
>> "%~1" echo AAoAAQN7AAAHIgA6ACIAAAN9AAAFXABcAAAFXABuAAAFXAByAAAFXAB0AAAFXAB1
>> "%~1" echo AAAFeAA0AADAAY/ZUABDAEYAawBiADIATgAwAGUAWABCAGwASQBHAGgAMABiAFcA
>> "%~1" echo dwArAEQAUQBvADgAYQBIAFIAdABiAEMAQgBzAFkAVwA1AG4AUABTAEoANgBhAEMA
>> "%~1" echo MQBEAFQAaQBJACsARABRAG8AOABhAEcAVgBoAFoARAA0AE4AQwBqAHgAdABaAFgA
>> "%~1" echo UgBoAEkARwBOAG8AWQBYAEoAegBaAFgAUQA5AEkAbgBWADAAWgBpADAANABJAGoA
>> "%~1" echo NABOAEMAagB4AHQAWgBYAFIAaABJAEcANQBoAGIAVwBVADkASQBuAFoAcABaAFgA
>> "%~1" echo ZAB3AGIAMwBKADAASQBpAEIAagBiADIANQAwAFoAVwA1ADAAUABTAEoAMwBhAFcA
>> "%~1" echo UgAwAGEARAAxAGsAWgBYAFoAcABZADIAVQB0AGQAMgBsAGsAZABHAGcAcwBhAFcA
>> "%~1" echo NQBwAGQARwBsAGgAYgBDADEAegBZADIARgBzAFoAVAAwAHgASQBqADQATgBDAGoA
>> "%~1" echo eAAwAGEAWABSAHMAWgBUADUAUgBkAFcAVgB6AGQAQwBCAEIAUgBFAEkAZwA1AG8A
>> "%~1" echo NgBuADUAWQBpADIANQBZACsAdwBQAEMAOQAwAGEAWABSAHMAWgBUADQATgBDAGoA
>> "%~1" echo eAB6AGQASABsAHMAWgBUADQATgBDAGoAcAB5AGIAMgA5ADAAZQB5ADAAdABZAG0A
>> "%~1" echo YwA2AEkAMgBZADEAWgBqAGQAbQBZAGoAcwB0AEwAWABOAHAAWgBHAFUANgBJADIA
>> "%~1" echo WgBtAFoAagBzAHQATABXAE4AaABjAG0AUQA2AEkAMgBaAG0AWgBqAHMAdABMAFgA
>> "%~1" echo TgB2AFoAbgBRADYASQAyAFkANABaAG0ARgBtAFkAegBzAHQATABXAHgAcABiAG0A
>> "%~1" echo VQA2AEkAMgBVAHkAWgBUAGgAbQBNAEQAcwB0AEwAWABSAGwAZQBIAFEANgBJAHoA
>> "%~1" echo RQB4AE0AVABnAHkATgB6AHMAdABMAFcAMQAxAGQARwBWAGsATwBpAE0AMgBOAEQA
>> "%~1" echo YwAwAE8ARwBJADcATABTADEAaQBiAEgAVgBsAE8AaQBNAHkATgBUAFkAegBaAFcA
>> "%~1" echo SQA3AEwAUwAxAG4AYwBtAFYAbABiAGoAbwBqAE0AVABaAGgATQB6AFIAaABPAHkA
>> "%~1" echo MAB0AFkAVwAxAGkAWgBYAEkANgBJADIAUQA1AE4AegBjAHcATgBqAHMAdABMAFgA
>> "%~1" echo SgBsAFoARABvAGoAWgBUAEUAeABaAEQAUQA0AE8AeQAwAHQAYgBtAEYAMgBPAGoA
>> "%~1" echo SQB6AE4AbgBCADQATwB5ADAAdABjAG0ARgBrAGEAWABWAHoATwBqAGgAdwBlAEgA
>> "%~1" echo MABOAEMAbQBKAHYAWgBIAGsAdQBaAEcARgB5AGEAMwBzAHQATABXAEoAbgBPAGkA
>> "%~1" echo TQB3AFoAagBFADAATQBXAE0ANwBMAFMAMQB6AGEAVwBSAGwATwBpAE0AeABNAFQA
>> "%~1" echo RQA0AE0AagBFADcATABTADEAagBZAFgASgBrAE8AaQBNAHgATgBUAEYAawBNAGoA
>> "%~1" echo ZwA3AEwAUwAxAHoAYgAyAFoAMABPAGkATQB4AE0AVABFADQATQBqAEkANwBMAFMA
>> "%~1" echo MQBzAGEAVwA1AGwATwBpAE0AeQBOAGoATQB5AE4ARABRADcATABTADEAMABaAFgA
>> "%~1" echo aAAwAE8AaQBOAGwATgBXAFYAawBaAGoAYwA3AEwAUwAxAHQAZABYAFIAbABaAEQA
>> "%~1" echo bwBqAE8AVABSAGgATQAyAEkANABmAFEAMABLAEsAbgB0AGkAYgAzAGcAdABjADIA
>> "%~1" echo bAA2AGEAVwA1AG4ATwBtAEoAdgBjAG0AUgBsAGMAaQAxAGkAYgAzAGgAOQBhAEgA
>> "%~1" echo UgB0AGIAQwB4AGkAYgAyAFIANQBlADIAMQBoAGMAbQBkAHAAYgBqAG8AdwBPADIA
>> "%~1" echo MQBwAGIAaQAxAG8AWgBXAGwAbgBhAEgAUQA2AE0AVABBAHcASgBUAHQAbQBiADIA
>> "%~1" echo NQAwAEwAVwBaAGgAYgBXAGwAcwBlAFQAbwBpAFUAMgBWAG4AYgAyAFUAZwBWAFUA
>> "%~1" echo awBpAEwAQwBKAE4AYQBXAE4AeQBiADMATgB2AFoAbgBRAGcAVwBXAEYASQBaAFcA
>> "%~1" echo awBpAEwARQBGAHkAYQBXAEYAcwBMAEgATgBoAGIAbgBNAHQAYwAyAFYAeQBhAFcA
>> "%~1" echo WQA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMA
>> "%~1" echo MQBpAFoAeQBrADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABkAEcA
>> "%~1" echo VgA0AGQAQwBrADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAMABjAEgA
>> "%~1" echo ZwA3AGIARwBWADAAZABHAFYAeQBMAFgATgB3AFkAVwBOAHAAYgBtAGMANgBNAEgA
>> "%~1" echo MQBpAGQAWABSADAAYgAyADQAcwBhAFcANQB3AGQAWABRAHMAYwAyAFYAcwBaAFcA
>> "%~1" echo TgAwAGUAMgBaAHYAYgBuAFEANgBhAFcANQBvAFoAWABKAHAAZABIADAATgBDAGkA
>> "%~1" echo NQBoAGMASABCADcAYgBXAGwAdQBMAFcAaABsAGEAVwBkAG8AZABEAG8AeABNAEQA
>> "%~1" echo QgAyAGEARAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMA
>> "%~1" echo SgBwAFoAQwAxADAAWgBXADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcA
>> "%~1" echo NQB6AE8AbgBaAGgAYwBpAGcAdABMAFcANQBoAGQAaQBrAGcATQBXAFoAeQBPADIA
>> "%~1" echo SgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABZAG0A
>> "%~1" echo YwBwAGYAUwA1AHoAYQBXAFIAbABlADMAQgB2AGMAMgBsADAAYQBXADkAdQBPAG0A
>> "%~1" echo WgBwAGUARwBWAGsATwAyAGwAdQBjADIAVgAwAE8AagBBAGcAWQBYAFYAMABiAHkA
>> "%~1" echo QQB3AEkARABBADcAZAAyAGwAawBkAEcAZwA2AGQAbQBGAHkASwBDADAAdABiAG0A
>> "%~1" echo RgAyAEsAVAB0AG8AWgBXAGwAbgBhAEgAUQA2AE0AVABBAHcAZABtAGcANwBZAG0A
>> "%~1" echo RgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBhAFcA
>> "%~1" echo UgBsAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBsAG4AYQBIAFEANgBNAFgA
>> "%~1" echo QgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0A
>> "%~1" echo VQBwAE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAbQBiAEcA
>> "%~1" echo VgA0AEwAVwBSAHAAYwBtAFYAagBkAEcAbAB2AGIAagBwAGoAYgAyAHgAMQBiAFcA
>> "%~1" echo NQA5AEwAbQBKAHkAWQBXADUAawBlADIAaABsAGEAVwBkAG8AZABEAG8AMwBOAG4A
>> "%~1" echo QgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcA
>> "%~1" echo bABuAGIAaQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBaADIA
>> "%~1" echo RgB3AE8AagBFAHkAYwBIAGcANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AdwBJAEQA
>> "%~1" echo RQA0AGMASABnADcAWQBtADkAeQBaAEcAVgB5AEwAVwBKAHYAZABIAFIAdgBiAFQA
>> "%~1" echo bwB4AGMASABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcA
>> "%~1" echo bAB1AFoAUwBsADkATABtAEoAeQBZAFcANQBrAFMAVwBOAHYAYgBuAHQAMwBhAFcA
>> "%~1" echo UgAwAGEARABvAHoATgBuAEIANABPADIAaABsAGEAVwBkAG8AZABEAG8AegBOAG4A
>> "%~1" echo QgA0AE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAEgA
>> "%~1" echo QgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AFkAbQB4ADEAWgBTAGsANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0A
>> "%~1" echo bABrAE8AMwBCAHMAWQBXAE4AbABMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4A
>> "%~1" echo UgBsAGMAagB0AGoAYgAyAHgAdgBjAGoAcAAzAGEARwBsADAAWgBYADAAdQBZAG4A
>> "%~1" echo SgBoAGIAbQBRAGcAWQBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIA
>> "%~1" echo TgByAE8AMgBaAHYAYgBuAFEAdABjADIAbAA2AFoAVABvAHgATgBuAEIANABmAFMA
>> "%~1" echo NQBpAGMAbQBGAHUAWgBDAEIAegBjAEcARgB1AGUAMgBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo awA2AFkAbQB4AHYAWQAyAHMANwBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQA
>> "%~1" echo bwB6AGMASABnADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgA
>> "%~1" echo VgAwAFoAVwBRAHAATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNAG4A
>> "%~1" echo QgA0AGYAUwA1AGkAYwBtAEYAdQBaAEUAbABqAGIAMgA0AGcAYwAzAFoAbgBMAEMA
>> "%~1" echo NQB1AFkAWABZAGcAYwAzAFoAbgBMAEMANQBrAFoAWABaAHAAWQAyAFYASgBZADIA
>> "%~1" echo OQB1AEkASABOADIAWgAzAHQAbQBhAFcAeABzAE8AbQA1AHYAYgBtAFUANwBjADMA
>> "%~1" echo UgB5AGIAMgB0AGwATwBtAE4AMQBjAG4ASgBsAGIAbgBSAEQAYgAyAHgAdgBjAGoA
>> "%~1" echo dAB6AGQASABKAHYAYQAyAFUAdABkADIAbABrAGQARwBnADYATQBqAHQAegBkAEgA
>> "%~1" echo SgB2AGEAMgBVAHQAYgBHAGwAdQBaAFcATgBoAGMARABwAHkAYgAzAFYAdQBaAEQA
>> "%~1" echo dAB6AGQASABKAHYAYQAyAFUAdABiAEcAbAB1AFoAVwBwAHYAYQBXADQANgBjAG0A
>> "%~1" echo OQAxAGIAbQBSADkARABRAG8AdQBiAG0ARgAyAGUAMgBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo awA2AFoAMwBKAHAAWgBEAHQAbgBZAFgAQQA2AE4ASABCADQATwAzAEIAaABaAEcA
>> "%~1" echo UgBwAGIAbQBjADYATQBUAEoAdwBlAEgAMAB1AGIAbQBGADIASQBHAEYANwBhAEcA
>> "%~1" echo VgBwAFoAMgBoADAATwBqAE0ANABjAEgAZwA3AFkAbQA5AHkAWgBHAFYAeQBMAFgA
>> "%~1" echo SgBoAFoARwBsADEAYwB6AG8AMwBjAEgAZwA3AFoARwBsAHoAYwBHAHgAaABlAFQA
>> "%~1" echo cABtAGIARwBWADQATwAyAEYAcwBhAFcAZAB1AEwAVwBsADAAWgBXADEAegBPAG0A
>> "%~1" echo TgBsAGIAbgBSAGwAYwBqAHQAbgBZAFgAQQA2AE0AVABCAHcAZQBEAHQAdwBZAFcA
>> "%~1" echo UgBrAGEAVwA1AG4ATwBqAEEAZwBNAFQASgB3AGUARAB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAZABHAFYANABkAEMA
>> "%~1" echo MQBrAFoAVwBOAHYAYwBtAEYAMABhAFcAOQB1AE8AbQA1AHYAYgBtAFUANwBaAG0A
>> "%~1" echo OQB1AGQAQwAxADMAWgBXAGwAbgBhAEgAUQA2AE4AegBBAHcAZgBTADUAdQBZAFgA
>> "%~1" echo WQBnAFkAUwBCAHoAZABtAGQANwBkADIAbABrAGQARwBnADYATQBUAGgAdwBlAEQA
>> "%~1" echo dABvAFoAVwBsAG4AYQBIAFEANgBNAFQAaAB3AGUASAAwAHUAYgBtAEYAMgBJAEcA
>> "%~1" echo RQB1AFkAVwBOADAAYQBYAFoAbABlADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0A
>> "%~1" echo UQA2AGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8AUwB3AHkATQB6AFUAcwBMAGoA
>> "%~1" echo RQB3AEsAVAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAaQBiAEgA
>> "%~1" echo VgBsAEsAWAAwAE4AQwBpADUAdABZAFcAbAB1AGUAMgBkAHkAYQBXAFEAdABZADIA
>> "%~1" echo OQBzAGQAVwAxAHUATwBqAEkANwBiAFcAbAB1AEwAWABkAHAAWgBIAFIAbwBPAGoA
>> "%~1" echo QQA3AGIAVwBsAHUATABXAGgAbABhAFcAZABvAGQARABvAHgATQBEAEIAMgBhAEQA
>> "%~1" echo dABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo SgBuAEsAWAAwAHUAZABHADkAdwBlADIAaABsAGEAVwBkAG8AZABEAG8AMwBOAG4A
>> "%~1" echo QgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AFkAMgBGAHkAWgBDAGsANwBZAG0AOQB5AFoARwBWAHkATABXAEoAdgBkAEgA
>> "%~1" echo UgB2AGIAVABvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AGIARwBsAHUAWgBTAGsANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbQBiAEcA
>> "%~1" echo VgA0AE8AMgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4A
>> "%~1" echo UgBsAGMAagB0AHEAZABYAE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4A
>> "%~1" echo UQA2AGMAMwBCAGgAWQAyAFUAdABZAG0AVgAwAGQAMgBWAGwAYgBqAHQAdwBZAFcA
>> "%~1" echo UgBrAGEAVwA1AG4ATwBqAEEAZwBNAGoAUgB3AGUARAB0AHcAYgAzAE4AcABkAEcA
>> "%~1" echo bAB2AGIAagBwAHoAZABHAGwAagBhADMAawA3AGQARwA5AHcATwBqAEEANwBlAGkA
>> "%~1" echo MQBwAGIAbQBSAGwAZQBEAG8AegBmAFMANQAwAGEAWABSAHMAWgBTAEIAbwBNAFgA
>> "%~1" echo dAB0AFkAWABKAG4AYQBXADQANgBNAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0A
>> "%~1" echo VQA2AE0AagBGAHcAZQBIADAAdQBkAEcAbAAwAGIARwBVAGcAYwBIAHQAdABZAFgA
>> "%~1" echo SgBuAGEAVwA0ADYATgBYAEIANABJAEQAQQBnAE0ARAB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQB6AGEAWABwAGwATwBqAEUAegBjAEgAaAA5AEQAUQBvAHUAZABHADkAdgBiAEcA
>> "%~1" echo SgBoAGMAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBaAHMAWgBYAGcANwBZAFcA
>> "%~1" echo eABwAFoAMgA0AHQAYQBYAFIAbABiAFgATQA2AFkAMgBWAHUAZABHAFYAeQBPADIA
>> "%~1" echo ZABoAGMARABvADQAYwBIAGcANwBaAG0AeABsAGUAQwAxADMAYwBtAEYAdwBPAG4A
>> "%~1" echo ZAB5AFkAWABBADcAYQBuAFYAegBkAEcAbABtAGUAUwAxAGoAYgAyADUAMABaAFcA
>> "%~1" echo NQAwAE8AbQBaAHMAWgBYAGcAdABaAFcANQBrAGYAUwA1AGoAYQBHAGwAdwBMAEMA
>> "%~1" echo NQBpAGQARwA1ADcAYQBHAFYAcABaADIAaAAwAE8AagBNADAAYwBIAGcANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgA
>> "%~1" echo SQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcA
>> "%~1" echo NQBrAE8AbgBaAGgAYwBpAGcAdABMAFgATgB2AFoAbgBRAHAATwAyAE4AdgBiAEcA
>> "%~1" echo OQB5AE8AbgBaAGgAYwBpAGcAdABMAFgAUgBsAGUASABRAHAATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE4AMwBCADQATwAzAEIAaABaAEcA
>> "%~1" echo UgBwAGIAbQBjADYATQBDAEEAeABNAFgAQgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo awA2AGEAVwA1AHMAYQBXADUAbABMAFcAWgBzAFoAWABnADcAWQBXAHgAcABaADIA
>> "%~1" echo NAB0AGEAWABSAGwAYgBYAE0ANgBZADIAVgB1AGQARwBWAHkATwAyAGQAaABjAEQA
>> "%~1" echo bwAzAGMASABnADcAWgBtADkAdQBkAEMAMQAzAFoAVwBsAG4AYQBIAFEANgBOAHoA
>> "%~1" echo QQB3AGYAUwA1AGoAYQBHAGwAdwBSAEcAOQAwAGUAMwBkAHAAWgBIAFIAbwBPAGoA
>> "%~1" echo aAB3AGUARAB0AG8AWgBXAGwAbgBhAEgAUQA2AE8ASABCADQATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE4AVABBAGwATwAyAEoAaABZADIA
>> "%~1" echo dABuAGMAbQA5ADEAYgBtAFEANgBkAG0ARgB5AEsAQwAwAHQAYwBtAFYAawBLAFgA
>> "%~1" echo MAB1AFkAMgA5AHUAYgBtAFYAagBkAEcAVgBrAEkAQwA1AGoAYQBHAGwAdwBSAEcA
>> "%~1" echo OQAwAGUAMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AFoAMwBKAGwAWgBXADQAcABmAFMANQBpAGQARwA1ADcAWQAzAFYAeQBjADIA
>> "%~1" echo OQB5AE8AbgBCAHYAYQBXADUAMABaAFgASgA5AEwAbQBKADAAYgBpADUAdwBjAG0A
>> "%~1" echo bAB0AFkAWABKADUAZQAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAWQBtAHgAMQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFcA
>> "%~1" echo TgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwBKAHMAZABXAFUAcABPADIA
>> "%~1" echo TgB2AGIARwA5AHkATwBuAGQAbwBhAFgAUgBsAGYAUwA1AGkAZABHADQAdQBaADIA
>> "%~1" echo aAB2AGMAMwBSADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMABjAG0A
>> "%~1" echo RgB1AGMAMwBCAGgAYwBtAFYAdQBkAEgAMABOAEMAaQA1ADMAYwBtAEYAdwBlADMA
>> "%~1" echo QgBoAFoARwBSAHAAYgBtAGMANgBNAFQAaAB3AGUAQwBBAHkATgBIAEIANABJAEQA
>> "%~1" echo TQB5AGMASABnADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG0AYgBHAFYANABPADIA
>> "%~1" echo WgBzAFoAWABnAHQAWgBHAGwAeQBaAFcATgAwAGEAVwA5AHUATwBtAE4AdgBiAEgA
>> "%~1" echo VgB0AGIAagB0AG4AWQBYAEEANgBNAFQAUgB3AGUARAB0AHQAWQBYAGcAdABkADIA
>> "%~1" echo bABrAGQARwBnADYATQBUAFEANABNAEgAQgA0AE8AMgAxAHAAYgBpADEAbwBaAFcA
>> "%~1" echo bABuAGEASABRADYAWQAyAEYAcwBZAHkAZwB4AE0ARABCADIAYQBDAEEAdABJAEQA
>> "%~1" echo YwAyAGMASABnAHAATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAWQBtAGMAcABmAFMANQB1AGIAMwBSAHAAWQAyAFYANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAeQBaADIA
>> "%~1" echo SgBoAEsARABJAHgATgB5AHcAeABNAFQAawBzAE4AaQB3AHUATQB6AEEAcABPADIA
>> "%~1" echo SgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAeQBNAFQA
>> "%~1" echo YwBzAE0AVABFADUATABEAFkAcwBMAGoAQQAzAEsAVAB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo bwBqAFkAagBNADIATgBUAEEAMQBPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcA
>> "%~1" echo UgBwAGQAWABNADYATwBIAEIANABPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAFQA
>> "%~1" echo QgB3AGUAQwBBAHgATQAzAEIANABPADIAWgB2AGIAbgBRAHQAZAAyAFYAcABaADIA
>> "%~1" echo aAAwAE8AagBjAHcATQBEAHQAdABhAFcANAB0AGEARwBWAHAAWgAyAGgAMABPAGoA
>> "%~1" echo QQA3AGIARwBsAHUAWgBTADEAbwBaAFcAbABuAGEASABRADYATQBTADQAMABOAFgA
>> "%~1" echo MQBpAGIAMgBSADUATABtAFIAaABjAG0AcwBnAEwAbQA1AHYAZABHAGwAagBaAFgA
>> "%~1" echo dABqAGIAMgB4AHYAYwBqAG8AagBaAGoAUgBqAE0ARABaAGgAZgBTADUAdwBZAFcA
>> "%~1" echo ZABsAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AGIAbQA5AHUAWgBYADAAdQBjAEcA
>> "%~1" echo RgBuAFoAUwA1AGgAWQAzAFIAcABkAG0AVgA3AFoARwBsAHoAYwBHAHgAaABlAFQA
>> "%~1" echo cABuAGMAbQBsAGsATwAyAGQAaABjAEQAbwB4AE4ASABCADQAZgBTADUAeQBiADMA
>> "%~1" echo ZAA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMAbQBsAGsATwAyAGQAeQBhAFcA
>> "%~1" echo UQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoA
>> "%~1" echo bwB4AFoAbgBJAGcATQBXAFoAeQBPADIAZABoAGMARABvAHgATgBIAEIANABmAFMA
>> "%~1" echo NQB5AGIAMwBjAHoAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQA
>> "%~1" echo dABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgA
>> "%~1" echo VgB0AGIAbgBNADYAYwBtAFYAdwBaAFcARgAwAEsARABNAHMATQBXAFoAeQBLAFQA
>> "%~1" echo dABuAFkAWABBADYATQBUAFIAdwBlAEgAMABOAEMAaQA1AGoAWQBYAEoAawBlADIA
>> "%~1" echo SgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABZADIA
>> "%~1" echo RgB5AFoAQwBrADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBDAEIAegBiADIA
>> "%~1" echo eABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQAaQBiADMA
>> "%~1" echo SgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8AbgBaAGgAYwBpAGcAdABMAFgA
>> "%~1" echo SgBoAFoARwBsADEAYwB5AGsANwBiADMAWgBsAGMAbQBaAHMAYgAzAGMANgBhAEcA
>> "%~1" echo bABrAFoARwBWAHUAZgBTADUAbwBaAFcARgBrAGUAMgBoAGwAYQBXAGQAbwBkAEQA
>> "%~1" echo bwAwAE4ASABCADQATwAyAEoAdgBjAG0AUgBsAGMAaQAxAGkAYgAzAFIAMABiADIA
>> "%~1" echo MAA2AE0AWABCADQASQBIAE4AdgBiAEcAbABrAEkASABaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo eABwAGIAbQBVAHAATwAyAFIAcABjADMAQgBzAFkAWABrADYAWgBtAHgAbABlAEQA
>> "%~1" echo dABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMAegBwAGoAWgBXADUAMABaAFgA
>> "%~1" echo SQA3AGEAbgBWAHoAZABHAGwAbQBlAFMAMQBqAGIAMgA1ADAAWgBXADUAMABPAG4A
>> "%~1" echo TgB3AFkAVwBOAGwATABXAEoAbABkAEgAZABsAFoAVwA0ADcAYwBHAEYAawBaAEcA
>> "%~1" echo bAB1AFoAegBvAHcASQBEAEUAMABjAEgAaAA5AEwAbQBoAGwAWQBXAFEAZwBhAEQA
>> "%~1" echo SgA3AGIAVwBGAHkAWgAyAGwAdQBPAGoAQQA3AFoAbQA5AHUAZABDADEAegBhAFgA
>> "%~1" echo cABsAE8AagBFADEAYwBIAGgAOQBMAG4AUgBoAFoAMwB0AG8AWgBXAGwAbgBhAEgA
>> "%~1" echo UQA2AE0AagBSAHcAZQBEAHQAawBhAFgATgB3AGIARwBGADUATwBtAGwAdQBiAEcA
>> "%~1" echo bAB1AFoAUwAxAG0AYgBHAFYANABPADIARgBzAGEAVwBkAHUATABXAGwAMABaAFcA
>> "%~1" echo MQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgA
>> "%~1" echo QgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0A
>> "%~1" echo VQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AGMAMgA5AG0AZABDAGsANwBZAG0AOQB5AFoARwBWAHkATABYAEoAaABaAEcA
>> "%~1" echo bAAxAGMAegBvADUATwBUAGwAdwBlAEQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoA
>> "%~1" echo QQBnAE8AWABCADQATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo MQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAFQA
>> "%~1" echo SgB3AGUASAAwAHUAWQBtADkAawBlAFgAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoA
>> "%~1" echo RQAwAGMASABoADkARABRAG8AdQBaAEcAVgAyAGEAVwBOAGwAVQAzAFIAeQBhAFgA
>> "%~1" echo QgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMAbQBsAGsATwAyAGQAeQBhAFcA
>> "%~1" echo UQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkAMgA5AHMAZABXADEAdQBjAHoA
>> "%~1" echo bwAzAE0ASABCADQASQBEAEYAbQBjAGkAQgBoAGQAWABSAHYATwAyAGQAaABjAEQA
>> "%~1" echo bwB4AE4ASABCADQATwAyAEYAcwBhAFcAZAB1AEwAVwBsADAAWgBXADEAegBPAG0A
>> "%~1" echo TgBsAGIAbgBSAGwAYwBuADAAdQBaAEcAVgAyAGEAVwBOAGwAUwBXAE4AdgBiAG4A
>> "%~1" echo dAAzAGEAVwBSADAAYQBEAG8AMwBNAEgAQgA0AE8AMgBoAGwAYQBXAGQAbwBkAEQA
>> "%~1" echo bwAzAE0ASABCADQATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgA
>> "%~1" echo TQA2AE0AVABKAHcAZQBEAHQAawBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcA
>> "%~1" echo UQA3AGMARwB4AGgAWQAyAFUAdABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcA
>> "%~1" echo VgB5AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAYwBtAGQAaQBZAFMA
>> "%~1" echo ZwB6AE4AeQB3ADUATwBTAHcAeQBNAHoAVQBzAEwAagBFAHcASwBUAHQAagBiADIA
>> "%~1" echo eAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQBpAGIASABWAGwASwBYADAAdQBaAEcA
>> "%~1" echo VgAyAGEAVwBOAGwAUwBXAE4AdgBiAGkAQgB6AGQAbQBkADcAZAAyAGwAawBkAEcA
>> "%~1" echo ZwA2AE4ARABSAHcAZQBEAHQAbwBaAFcAbABuAGEASABRADYATgBEAFIAdwBlAEgA
>> "%~1" echo MAB1AFoARwBWADIAYQBXAE4AbABUAG0ARgB0AFoAWAB0AG0AYgAyADUAMABMAFgA
>> "%~1" echo TgBwAGUAbQBVADYATQBqAEIAdwBlAEQAdABtAGIAMgA1ADAATABYAGQAbABhAFcA
>> "%~1" echo ZABvAGQARABvADQATQBEAEIAOQBMAG0AaABwAGIAbgBSADcAYgBXAEYAeQBaADIA
>> "%~1" echo bAB1AEwAWABSAHYAYwBEAG8AMwBjAEgAZwA3AFkAMgA5AHMAYgAzAEkANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMgB4AHAAYgBtAFUAdABhAEcA
>> "%~1" echo VgBwAFoAMgBoADAATwBqAEUAdQBOAFQAVgA5AEwAbgBOADAAWQBYAFIAbABlADIA
>> "%~1" echo WgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB5AE4AbgBCADQATwAyAFoAdgBiAG4A
>> "%~1" echo UQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAawB3AE0ARAB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAeQBaAFcAUQBwAGYAUwA1AHoAZABHAEYAMABaAFMA
>> "%~1" echo NQBuAGIAMgA5AGsAZQAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo ZAB5AFoAVwBWAHUASwBYADAAdQBjAG0AbABuAGUAMgBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo awA2AFoAMwBKAHAAWgBEAHQAbgBjAG0AbABrAEwAWABSAGwAYgBYAEIAcwBZAFgA
>> "%~1" echo UgBsAEwAVwBOAHYAYgBIAFYAdABiAG4ATQA2AE0AVwBaAHkASQBEAEUAdQBOAEcA
>> "%~1" echo WgB5AEkARABGAG0AYwBqAHQAbgBZAFgAQQA2AE0AVABKAHcAZQBEAHQAaABiAEcA
>> "%~1" echo bABuAGIAaQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBiAFcA
>> "%~1" echo RgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwB4AE4ASABCADQAZgBTADUAagBiADIA
>> "%~1" echo NQAwAGMAbQA5AHMAYgBHAFYAeQBRAG0AOQA0AGUAMgAxAHAAYgBpADEAbwBaAFcA
>> "%~1" echo bABuAGEASABRADYATgB6AGgAdwBlAEQAdABpAGIAMwBKAGsAWgBYAEkANgBNAFgA
>> "%~1" echo QgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0A
>> "%~1" echo VQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAEgA
>> "%~1" echo QgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AGMAMgA5AG0AZABDAGsANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABNAEgA
>> "%~1" echo QgA0AEkARABFAHkAYwBIAGcANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0A
>> "%~1" echo bABrAE8AMgBGAHMAYQBXAGQAdQBMAFcATgB2AGIAbgBSAGwAYgBuAFEANgBZADIA
>> "%~1" echo VgB1AGQARwBWAHkATwAyAGQAaABjAEQAbwAyAGMASABoADkATABtAE4AdgBiAG4A
>> "%~1" echo UgB5AGIAMgB4AHMAWgBYAEoAQwBiADMAZwBnAEwAbgBKAHYAYgBHAFYANwBZADIA
>> "%~1" echo OQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABPADIA
>> "%~1" echo WgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB4AE0AbgBCADQAZgBTADUAagBiADIA
>> "%~1" echo NQAwAGMAbQA5AHMAYgBHAFYAeQBRAG0AOQA0AEkARwBKADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQB6AGEAWABwAGwATwBqAEkAdwBjAEgAaAA5AEwAbQBOAHYAYgBuAFIAeQBiADIA
>> "%~1" echo eABzAFoAWABKAEMAYgAzAGcAZwBMAG4ATgAwAFkAWABSAGwAVgBHAFYANABkAEgA
>> "%~1" echo dABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0AVABKAHcAZQBEAHQAagBiADIA
>> "%~1" echo eAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB0AGQAWABSAGwAWgBDAGwAOQBMAG0A
>> "%~1" echo TgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBDAGIAMwBnAHUAYgBHAFYAbQBkAEgA
>> "%~1" echo dAAwAFoAWABoADAATABXAEYAcwBhAFcAZAB1AE8AbQB4AGwAWgBuAFEANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABXAHgAbABaAG4AUQA2AE0AMwBCADQASQBIAE4AdgBiAEcA
>> "%~1" echo bABrAEkASABaAGgAYwBpAGcAdABMAFcASgBzAGQAVwBVAHAAZgBTADUAagBiADIA
>> "%~1" echo NQAwAGMAbQA5AHMAYgBHAFYAeQBRAG0AOQA0AEwAbgBKAHAAWgAyAGgAMABlADMA
>> "%~1" echo UgBsAGUASABRAHQAWQBXAHgAcABaADIANAA2AGMAbQBsAG4AYQBIAFEANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABYAEoAcABaADIAaAAwAE8AagBOAHcAZQBDAEIAegBiADIA
>> "%~1" echo eABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBpAGIASABWAGwASwBYADAAdQBhAEcA
>> "%~1" echo VgBoAFoASABOAGwAZABFAEoAdgBlAEgAdAB0AGEAVwA0AHQAYQBHAFYAcABaADIA
>> "%~1" echo aAAwAE8AagBrAHcAYwBIAGcANwBZAG0AOQB5AFoARwBWAHkATwBqAEYAdwBlAEMA
>> "%~1" echo QgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwAUwAxAHMAYQBXADUAbABLAFQA
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBqAEUAdwBjAEgA
>> "%~1" echo ZwA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwAHMAYQBXADUAbABZAFgA
>> "%~1" echo SQB0AFoAMwBKAGgAWgBHAGwAbABiAG4AUQBvAE0AVABnAHcAWgBHAFYAbgBMAEgA
>> "%~1" echo SgBuAFkAbQBFAG8ATQB6AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAeABNAEMA
>> "%~1" echo awBzAGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrAHAATwAyAFIAcABjADMA
>> "%~1" echo QgBzAFkAWABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgA
>> "%~1" echo QgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATgBqAFIAdwBlAEMA
>> "%~1" echo QQB4AFoAbgBJADcAWgAyAEYAdwBPAGoARQB5AGMASABnADcAWQBXAHgAcABaADIA
>> "%~1" echo NAB0AGEAWABSAGwAYgBYAE0ANgBZADIAVgB1AGQARwBWAHkATwAzAEIAaABaAEcA
>> "%~1" echo UgBwAGIAbQBjADYATQBUAEoAdwBlAEgAMABOAEMAaQA1AGsAWgBYAFoAcABZADIA
>> "%~1" echo VgBOAFoAWABSAGgAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQA
>> "%~1" echo dABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgA
>> "%~1" echo VgB0AGIAbgBNADYATQBXAFoAeQBJAEQARgBtAGMAagB0AG4AWQBYAEEANgBNAFQA
>> "%~1" echo QgB3AGUARAB0AHQAWQBYAEoAbgBhAFcANAB0AGQARwA5AHcATwBqAEUAegBjAEgA
>> "%~1" echo aAA5AEwAbQAxAGwAZABHAEYASgBkAEcAVgB0AGUAMgBoAGwAYQBXAGQAbwBkAEQA
>> "%~1" echo bwAxAE0AbgBCADQATwAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIA
>> "%~1" echo OQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADMAYwBIAGcANwBZAG0A
>> "%~1" echo RgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIA
>> "%~1" echo WgAwAEsAVAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBsAHcAZQBDAEEAeABNAG4A
>> "%~1" echo QgA0AGYAUwA1AHQAWgBYAFIAaABTAFgAUgBsAGIAUwBCAHoAYwBHAEYAdQBlADIA
>> "%~1" echo UgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgBzADcAWQAyADkAcwBiADMA
>> "%~1" echo SQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoAVwBRAHAATwAyAFoAdgBiAG4A
>> "%~1" echo UQB0AGMAMgBsADYAWgBUAG8AeABNAG4AQgA0AGYAUwA1AHQAWgBYAFIAaABTAFgA
>> "%~1" echo UgBsAGIAUwBCAGkAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWQBtAHgAdgBZADIA
>> "%~1" echo cwA3AGIAVwBGAHkAWgAyAGwAdQBMAFgAUgB2AGMARABvADAAYwBIAGcANwBkADIA
>> "%~1" echo aABwAGQARwBVAHQAYwAzAEIAaABZADIAVQA2AGIAbQA5ADMAYwBtAEYAdwBPADIA
>> "%~1" echo OQAyAFoAWABKAG0AYgBHADkAMwBPAG0AaABwAFoARwBSAGwAYgBqAHQAMABaAFgA
>> "%~1" echo aAAwAEwAVwA5ADIAWgBYAEoAbQBiAEcAOQAzAE8AbQBWAHMAYgBHAGwAdwBjADIA
>> "%~1" echo bAB6AGYAUQAwAEsATABtADEAbABkAEgASgBwAFkAMABkAHkAYQBXAFIANwBaAEcA
>> "%~1" echo bAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcA
>> "%~1" echo VgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AHAAeQBaAFgA
>> "%~1" echo QgBsAFkAWABRAG8ATQB5AHcAeABaAG4ASQBwAE8AMgBkAGgAYwBEAG8AeABNAEgA
>> "%~1" echo QgA0AGYAUwA1AHQAWgBYAFIAeQBhAFcATgA3AGEARwBWAHAAWgAyAGgAMABPAGoA
>> "%~1" echo RQB4AE0AbgBCADQATwAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIA
>> "%~1" echo OQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADQAYwBIAGcANwBZAG0A
>> "%~1" echo RgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIA
>> "%~1" echo WgAwAEsAVAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBFAHkAYwBIAGcANwBaAEcA
>> "%~1" echo bAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcA
>> "%~1" echo VgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AG8AMgBPAEgA
>> "%~1" echo QgA0AEkARABGAG0AYwBqAHQAaABiAEcAbABuAGIAaQAxAHAAZABHAFYAdABjAHoA
>> "%~1" echo cABqAFoAVwA1ADAAWgBYAEkANwBaADIARgB3AE8AagBFAHcAYwBIAGgAOQBMAG0A
>> "%~1" echo MQBsAGQASABKAHAAWQB5AEIAegBkAG0AYwB1AGMAbQBsAHUAWgAzAHQAMwBhAFcA
>> "%~1" echo UgAwAGEARABvADIATwBIAEIANABPADIAaABsAGEAVwBkAG8AZABEAG8AMgBPAEgA
>> "%~1" echo QgA0AE8AMwBSAHkAWQBXADUAegBaAG0AOQB5AGIAVABwAHkAYgAzAFIAaABkAEcA
>> "%~1" echo VQBvAEwAVABrAHcAWgBHAFYAbgBLAFgAMAB1AGQASABKAGgAWQAyAHQANwBaAG0A
>> "%~1" echo bABzAGIARABwAHUAYgAyADUAbABPADMATgAwAGMAbQA5AHIAWgBUAHAAeQBaADIA
>> "%~1" echo SgBoAEsARABFADAATwBDAHcAeABOAGoATQBzAE0AVABnADAATABDADQAeQBOAFMA
>> "%~1" echo awA3AGMAMwBSAHkAYgAyAHQAbABMAFgAZABwAFoASABSAG8ATwBqAGgAOQBMAG0A
>> "%~1" echo MQBsAGQARwBWAHkAZQAyAFoAcABiAEcAdwA2AGIAbQA5AHUAWgBUAHQAegBkAEgA
>> "%~1" echo SgB2AGEAMgBVADYAZABtAEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsANwBjADMA
>> "%~1" echo UgB5AGIAMgB0AGwATABYAGQAcABaAEgAUgBvAE8AagBnADcAYwAzAFIAeQBiADIA
>> "%~1" echo dABsAEwAVwB4AHAAYgBtAFYAagBZAFgAQQA2AGMAbQA5ADEAYgBtAFIAOQBMAG0A
>> "%~1" echo MQBsAGQASABKAHAAWQB5ADUAbgBjAG0AVgBsAGIAaQBBAHUAYgBXAFYAMABaAFgA
>> "%~1" echo SgA3AGMAMwBSAHkAYgAyAHQAbABPAG4AWgBoAGMAaQBnAHQATABXAGQAeQBaAFcA
>> "%~1" echo VgB1AEsAWAAwAHUAYgBXAFYAMABjAG0AbABqAEwAbQBGAHQAWQBtAFYAeQBJAEMA
>> "%~1" echo NQB0AFoAWABSAGwAYwBuAHQAegBkAEgASgB2AGEAMgBVADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AFkAVwAxAGkAWgBYAEkAcABmAFMANQB0AFoAWABSAHkAYQBXAE0AdQBjAG0A
>> "%~1" echo VgBrAEkAQwA1AHQAWgBYAFIAbABjAG4AdAB6AGQASABKAHYAYQAyAFUANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAYwBtAFYAawBLAFgAMAB1AGIAVwBWADAAYwBtAGwAagBWAG0A
>> "%~1" echo RgBzAGQAVwBWADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEkAegBjAEgA
>> "%~1" echo ZwA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEASABRADYATwBUAEEAdwBPADMA
>> "%~1" echo ZABvAGEAWABSAGwATABYAE4AdwBZAFcATgBsAE8AbQA1AHYAZAAzAEoAaABjAEgA
>> "%~1" echo MAB1AGIAVwBWADAAYwBtAGwAagBUAEcARgBpAFoAVwB4ADcAYgBXAEYAeQBaADIA
>> "%~1" echo bAB1AEwAWABSAHYAYwBEAG8AMgBjAEgAZwA3AFkAMgA5AHMAYgAzAEkANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAYgBYAFYAMABaAFcAUQBwAE8AMgBaAHYAYgBuAFEAdABjADIA
>> "%~1" echo bAA2AFoAVABvAHgATQBuAEIANABmAFEAMABLAEwAbQAxAHAAYgBtAGwASABjAG0A
>> "%~1" echo bABrAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBjAG0A
>> "%~1" echo bABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4A
>> "%~1" echo TQA2AGMAbQBWAHcAWgBXAEYAMABLAEQAUQBzAE0AVwBaAHkASwBUAHQAbgBZAFgA
>> "%~1" echo QQA2AE0AVABCAHcAZQBIADAAdQBiAFcAbAB1AGEAWAB0AGkAYgAzAEoAawBaAFgA
>> "%~1" echo SQA2AE0AWABCADQASQBIAE4AdgBiAEcAbABrAEkASABaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo eABwAGIAbQBVAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAWQBXAFIAcABkAFgA
>> "%~1" echo TQA2AE8ASABCADQATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAYwAyADkAbQBkAEMAawA3AGMARwBGAGsAWgBHAGwAdQBaAHoA
>> "%~1" echo bwB4AE0AWABCADQAZgBTADUAdABhAFcANQBwAEkASABOAHcAWQBXADUANwBaAEcA
>> "%~1" echo bAB6AGMARwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEAegB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQB6AGEAWABwAGwATwBqAEUAeQBjAEgAaAA5AEwAbQAxAHAAYgBtAGsAZwBZAG4A
>> "%~1" echo dABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAyADEAaABjAG0A
>> "%~1" echo ZABwAGIAaQAxADAAYgAzAEEANgBOAG4AQgA0AE8AMwBkAG8AYQBYAFIAbABMAFgA
>> "%~1" echo TgB3AFkAVwBOAGwATwBtADUAdgBkADMASgBoAGMARAB0AHYAZABtAFYAeQBaAG0A
>> "%~1" echo eAB2AGQAegBwAG8AYQBXAFIAawBaAFcANAA3AGQARwBWADQAZABDADEAdgBkAG0A
>> "%~1" echo VgB5AFoAbQB4AHYAZAB6AHAAbABiAEcAeABwAGMASABOAHAAYwAzADAAdQBhAFcA
>> "%~1" echo NQBtAGIAMABkAHkAYQBXAFIANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0A
>> "%~1" echo bABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIA
>> "%~1" echo OQBzAGQAVwAxAHUAYwB6AHAAeQBaAFgAQgBsAFkAWABRAG8ATQB5AHcAeABaAG4A
>> "%~1" echo SQBwAE8AMgBkAGgAYwBEAG8AeABNAEgAQgA0AGYAUwA1AHAAYgBtAFoAdgBWAEcA
>> "%~1" echo bABzAFoAWAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBIAE4AdgBiAEcA
>> "%~1" echo bABrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE8ASABCADQATwAyAEoAaABZADIA
>> "%~1" echo dABuAGMAbQA5ADEAYgBtAFEANgBkAG0ARgB5AEsAQwAwAHQAYwAyADkAbQBkAEMA
>> "%~1" echo awA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0AWABCADQATwAyADEAcABiAGkA
>> "%~1" echo MQBvAFoAVwBsAG4AYQBIAFEANgBOAFQAaAB3AGUASAAwAHUAYQBXADUAbQBiADEA
>> "%~1" echo UgBwAGIARwBVAGcAYwAzAEIAaABiAG4AdABrAGEAWABOAHcAYgBHAEYANQBPAG0A
>> "%~1" echo SgBzAGIAMgBOAHIATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo MQAxAGQARwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAFQA
>> "%~1" echo SgB3AGUASAAwAHUAYQBXADUAbQBiADEAUgBwAGIARwBVAGcAWQBuAHQAawBhAFgA
>> "%~1" echo TgB3AGIARwBGADUATwBtAEoAcwBiADIATgByAE8AMgAxAGgAYwBtAGQAcABiAGkA
>> "%~1" echo MQAwAGIAMwBBADYATgBYAEIANABPADMAZAB2AGMAbQBRAHQAWQBuAEoAbABZAFcA
>> "%~1" echo cwA2AFkAbgBKAGwAWQBXAHMAdABkADIAOQB5AFoASAAwAHUAWgBYAGgAdwBiADMA
>> "%~1" echo SgAwAFEAbQA5ADQAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQA
>> "%~1" echo dABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgA
>> "%~1" echo VgB0AGIAbgBNADYATQBXAFoAeQBJAEcARgAxAGQARwA4ADcAWgAyAEYAdwBPAGoA
>> "%~1" echo RQB5AGMASABnADcAWQBXAHgAcABaADIANAB0AGEAWABSAGwAYgBYAE0ANgBZADIA
>> "%~1" echo VgB1AGQARwBWAHkATwAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIA
>> "%~1" echo OQBzAGEAVwBRAGcAYwBtAGQAaQBZAFMAZwB6AE4AeQB3ADUATwBTAHcAeQBNAHoA
>> "%~1" echo VQBzAEwAagBNADEASwBUAHQAaQBZAFcATgByAFoAMwBKAHYAZABXADUAawBPAG4A
>> "%~1" echo SgBuAFkAbQBFAG8ATQB6AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAdwBPAEMA
>> "%~1" echo awA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8ANABjAEgA
>> "%~1" echo ZwA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0AMwBCADQAZgBTADUAbABlAEgA
>> "%~1" echo QgB2AGMAbgBSAE0AYQBXADUAcgBjADMAdABrAGEAWABOAHcAYgBHAEYANQBPAG0A
>> "%~1" echo ZAB5AGEAVwBRADcAWgAyAEYAdwBPAGoAaAB3AGUASAAwAHUAWgBYAGgAdwBiADMA
>> "%~1" echo SgAwAFQARwBsAHUAYQAzAE0AZwBZAFgAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgA
>> "%~1" echo SQBvAEwAUwAxAGkAYgBIAFYAbABLAFQAdABtAGIAMgA1ADAATABYAGQAbABhAFcA
>> "%~1" echo ZABvAGQARABvADUATQBEAEEANwBkADIAOQB5AFoAQwAxAGkAYwBtAFYAaABhAHoA
>> "%~1" echo cABpAGMAbQBWAGgAYQB5ADEAaABiAEcAeAA5AEwAbgBSAGgAWQBtAHgAbABlADMA
>> "%~1" echo ZABwAFoASABSAG8ATwBqAEUAdwBNAEMAVQA3AFkAbQA5AHkAWgBHAFYAeQBMAFcA
>> "%~1" echo TgB2AGIARwB4AGgAYwBIAE4AbABPAG0ATgB2AGIARwB4AGgAYwBIAE4AbABmAFMA
>> "%~1" echo NQAwAFkAVwBKAHMAWgBTAEIAMABaAEgAdABpAGIAMwBKAGsAWgBYAEkAdABZAG0A
>> "%~1" echo OQAwAGQARwA5AHQATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgA
>> "%~1" echo SQBvAEwAUwAxAHMAYQBXADUAbABLAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoA
>> "%~1" echo bAB3AGUAQwBBAHcATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcA
>> "%~1" echo MQAxAGQARwBWAGsASwBUAHQAMgBaAFgASgAwAGEAVwBOAGgAYgBDADEAaABiAEcA
>> "%~1" echo bABuAGIAagBwADAAYgAzAEIAOQBMAG4AUgBoAFkAbQB4AGwASQBIAFIAeQBPAG0A
>> "%~1" echo eABoAGMAMwBRAHQAWQAyAGgAcABiAEcAUQBnAGQARwBSADcAWQBtADkAeQBaAEcA
>> "%~1" echo VgB5AEwAVwBKAHYAZABIAFIAdgBiAFQAbwB3AGYAUwA1ADAAWQBXAEoAcwBaAFMA
>> "%~1" echo QgAwAFoARABwAHMAWQBYAE4AMABMAFcATgBvAGEAVwB4AGsAZQAzAFIAbABlAEgA
>> "%~1" echo UQB0AFkAVwB4AHAAWgAyADQANgBjAG0AbABuAGEASABRADcAWQAyADkAcwBiADMA
>> "%~1" echo SQA2AGQAbQBGAHkASwBDADAAdABkAEcAVgA0AGQAQwBrADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQAzAFoAVwBsAG4AYQBIAFEANgBOAHoAQQB3AE8AMwBkAHYAYwBtAFEAdABZAG4A
>> "%~1" echo SgBsAFkAVwBzADYAWQBuAEoAbABZAFcAcwB0AGQAMgA5AHkAWgBIADAATgBDAGkA
>> "%~1" echo NQBqAGIAVwBSAEgAYwBtAGwAawBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaADMA
>> "%~1" echo SgBwAFoARAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcA
>> "%~1" echo TgB2AGIASABWAHQAYgBuAE0ANgBjAG0AVgB3AFoAVwBGADAASwBEAEkAcwBiAFcA
>> "%~1" echo bAB1AGIAVwBGADQASwBEAEEAcwBNAFcAWgB5AEsAUwBrADcAWgAyAEYAdwBPAGoA
>> "%~1" echo RQB3AGMASABoADkATABtAE4AdABaAEgAdABvAFoAVwBsAG4AYQBIAFEANgBOAFQA
>> "%~1" echo aAB3AGUARAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBIAE4AdgBiAEcA
>> "%~1" echo bABrAEkASABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAaQAxAHMAWgBXAFoAMABPAGoATgB3AGUAQwBCAHoAYgAyAHgAcABaAEMA
>> "%~1" echo QgAyAFkAWABJAG8ATABTADEAcwBhAFcANQBsAEsAVAB0AGkAWQBXAE4AcgBaADMA
>> "%~1" echo SgB2AGQAVwA1AGsATwBuAFoAaABjAGkAZwB0AEwAWABOAHYAWgBuAFEAcABPADIA
>> "%~1" echo SgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQAWABNADYATgAzAEIANABPADMA
>> "%~1" echo UgBsAGUASABRAHQAWQBXAHgAcABaADIANAA2AGIARwBWAG0AZABEAHQAdwBZAFcA
>> "%~1" echo UgBrAGEAVwA1AG4ATwBqAGwAdwBlAEMAQQB4AE0AWABCADQATwAyAE4AdgBiAEcA
>> "%~1" echo OQB5AE8AbgBaAGgAYwBpAGcAdABMAFgAUgBsAGUASABRAHAATwAyAE4AMQBjAG4A
>> "%~1" echo TgB2AGMAagBwAHcAYgAyAGwAdQBkAEcAVgB5AGYAUwA1AGoAYgBXAFEAZwBZAG4A
>> "%~1" echo dABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIAZgBTADUAagBiAFcA
>> "%~1" echo UQBnAGMAMwBCAGgAYgBuAHQAawBhAFgATgB3AGIARwBGADUATwBtAEoAcwBiADIA
>> "%~1" echo TgByAE8AMgAxAGgAYwBtAGQAcABiAGkAMQAwAGIAMwBBADYATgBIAEIANABPADIA
>> "%~1" echo TgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwAVwAxADEAZABHAFYAawBLAFQA
>> "%~1" echo dABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0AVABKAHcAZQBIADAAdQBZADIA
>> "%~1" echo MQBrAEwAbQBKAHMAZABXAFYANwBZAG0AOQB5AFoARwBWAHkATABXAHgAbABaAG4A
>> "%~1" echo UQB0AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBtAHgAMQBaAFMA
>> "%~1" echo bAA5AEwAbQBOAHQAWgBDADUAbgBjAG0AVgBsAGIAbgB0AGkAYgAzAEoAawBaAFgA
>> "%~1" echo SQB0AGIARwBWAG0AZABDADEAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMA
>> "%~1" echo MQBuAGMAbQBWAGwAYgBpAGwAOQBMAG0ATgB0AFoAQwA1AGgAYgBXAEoAbABjAG4A
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkAdABiAEcAVgBtAGQAQwAxAGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAaABiAFcASgBsAGMAaQBsADkATABtAE4AdABaAEMA
>> "%~1" echo NQB5AFoAVwBSADcAWQBtADkAeQBaAEcAVgB5AEwAVwB4AGwAWgBuAFEAdABZADIA
>> "%~1" echo OQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGMAbQBWAGsASwBYADAATgBDAGkA
>> "%~1" echo NQBtAGIAMwBKAHQAZQAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQA
>> "%~1" echo dABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgA
>> "%~1" echo VgB0AGIAbgBNADYATQBUAE0AdwBjAEgAZwBnAE0AVwBaAHkASQBEAEYAbQBjAGkA
>> "%~1" echo QQA0AE0AbgBCADQATwAyAGQAaABjAEQAbwA1AGMASABoADkAYQBXADUAdwBkAFgA
>> "%~1" echo UQBzAGMAMgBWAHMAWgBXAE4AMABlADIAaABsAGEAVwBkAG8AZABEAG8AegBOAG4A
>> "%~1" echo QgA0AE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMASABnAGcAYwAyADkAcwBhAFcA
>> "%~1" echo UQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoAUwBrADcAWQBtADkAeQBaAEcA
>> "%~1" echo VgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwAzAGMASABnADcAWQBtAEYAagBhADIA
>> "%~1" echo ZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAHoAYgAyAFoAMABLAFQA
>> "%~1" echo dABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxADAAWgBYAGgAMABLAFQA
>> "%~1" echo dAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAQQBnAE0AVABCAHcAZQBIADAAdQBiAEcA
>> "%~1" echo OQBuAGUAMwBkAG8AYQBYAFIAbABMAFgATgB3AFkAVwBOAGwATwBuAEIAeQBaAFMA
>> "%~1" echo MQAzAGMAbQBGAHcATwAyADEAcABiAGkAMQBvAFoAVwBsAG4AYQBIAFEANgBPAEQA
>> "%~1" echo QgB3AGUARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAdABkAFgA
>> "%~1" echo UgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQBtAFkAVwAxAHAAYgBIAGsANgBRADIA
>> "%~1" echo OQB1AGMAMgA5AHMAWQBYAE0AcwBJAGsAMQBwAFkAMwBKAHYAYwAyADkAbQBkAEMA
>> "%~1" echo QgBaAFkAVQBoAGwAYQBTAEkAcwBiAFcAOQB1AGIAMwBOAHcAWQBXAE4AbABPADIA
>> "%~1" echo eABwAGIAbQBVAHQAYQBHAFYAcABaADIAaAAwAE8AagBFAHUATgBUAFYAOQBEAFEA
>> "%~1" echo bwB1AGQARwA5AGgAYwAzAFIAegBlADMAQgB2AGMAMgBsADAAYQBXADkAdQBPAG0A
>> "%~1" echo WgBwAGUARwBWAGsATwAzAEoAcABaADIAaAAwAE8AagBJAHkAYwBIAGcANwBZAG0A
>> "%~1" echo OQAwAGQARwA5AHQATwBqAEkAeQBjAEgAZwA3AGUAaQAxAHAAYgBtAFIAbABlAEQA
>> "%~1" echo bwB6AE0ARAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBaAHMAWgBYAGcANwBaAG0A
>> "%~1" echo eABsAGUAQwAxAGsAYQBYAEoAbABZADMAUgBwAGIAMgA0ADYAWQAyADkAcwBkAFcA
>> "%~1" echo MQB1AEwAWABKAGwAZABtAFYAeQBjADIAVQA3AFoAMgBGAHcATwBqAEUAdwBjAEgA
>> "%~1" echo ZwA3AGQAMgBsAGsAZABHAGcANgBiAFcAbAB1AEsARABNADUATQBIAEIANABMAEcA
>> "%~1" echo TgBoAGIARwBNAG8ATQBUAEEAdwBkAG4AYwBnAEwAUwBBAHkATwBIAEIANABLAFMA
>> "%~1" echo awA3AGMARwA5AHAAYgBuAFIAbABjAGkAMQBsAGQAbQBWAHUAZABIAE0ANgBiAG0A
>> "%~1" echo OQB1AFoAWAAwAHUAZABHADkAaABjADMAUgA3AFkAbQA5AHkAWgBHAFYAeQBPAGoA
>> "%~1" echo RgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEAcwBhAFcA
>> "%~1" echo NQBsAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGIARwBWAG0AZABEAG8AMABjAEgA
>> "%~1" echo ZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAWQBtAHgAMQBaAFMA
>> "%~1" echo awA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMA
>> "%~1" echo MQBqAFkAWABKAGsASwBUAHQAaQBiADMAZwB0AGMAMgBoAGgAWgBHADkAMwBPAGoA
>> "%~1" echo QQBnAE0AVABaAHcAZQBDAEEAegBPAEgAQgA0AEkASABKAG4AWQBtAEUAbwBNAFQA
>> "%~1" echo VQBzAE0AagBNAHMATgBEAEkAcwBMAGoASQB3AEsAVAB0AGkAYgAzAEoAawBaAFgA
>> "%~1" echo SQB0AGMAbQBGAGsAYQBYAFYAegBPAGoAaAB3AGUARAB0AHcAWQBXAFIAawBhAFcA
>> "%~1" echo NQBuAE8AagBFAHgAYwBIAGcAZwBNAFQASgB3AGUARAB0AHYAYwBHAEYAagBhAFgA
>> "%~1" echo UgA1AE8AagBBADcAZABIAEoAaABiAG4ATgBtAGIAMwBKAHQATwBuAFIAeQBZAFcA
>> "%~1" echo NQB6AGIARwBGADAAWgBWAGcAbwBNAGoAUgB3AGUAQwBrAGcAZABIAEoAaABiAG4A
>> "%~1" echo TgBzAFkAWABSAGwAVwBTAGcAeABNAEgAQgA0AEsAUwBCAHoAWQAyAEYAcwBaAFMA
>> "%~1" echo ZwB1AE8AVABnAHAATwAzAFIAeQBZAFcANQB6AGEAWABSAHAAYgAyADQANgBiADMA
>> "%~1" echo QgBoAFkAMgBsADAAZQBTAEEAdQBNAGoASgB6AEkARwBWAGgAYwAyAFUAcwBkAEgA
>> "%~1" echo SgBoAGIAbgBOAG0AYgAzAEoAdABJAEMANAB5AE0AbgBNAGcAWQAzAFYAaQBhAFcA
>> "%~1" echo TQB0AFkAbQBWADYAYQBXAFYAeQBLAEMANAB5AEwAQwA0ADQATABDADQAeQBMAEQA
>> "%~1" echo RQBwAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIAbABlAEgA
>> "%~1" echo UQBwAE8AMwBCAHYAYQBXADUAMABaAFgASQB0AFoAWABaAGwAYgBuAFIAegBPAG0A
>> "%~1" echo RgAxAGQARwA5ADkATABuAFIAdgBZAFgATgAwAEwAbgBOAG8AYgAzAGQANwBiADMA
>> "%~1" echo QgBoAFkAMgBsADAAZQBUAG8AeABPADMAUgB5AFkAVwA1AHoAWgBtADkAeQBiAFQA
>> "%~1" echo cAAwAGMAbQBGAHUAYwAyAHgAaABkAEcAVgBZAEsARABBAHAASQBIAFIAeQBZAFcA
>> "%~1" echo NQB6AGIARwBGADAAWgBWAGsAbwBNAEMAawBnAGMAMgBOAGgAYgBHAFUAbwBNAFMA
>> "%~1" echo bAA5AEwAbgBSAHYAWQBYAE4AMABJAEcASgA3AFoARwBsAHoAYwBHAHgAaABlAFQA
>> "%~1" echo cABpAGIARwA5AGoAYQB6AHQAdABZAFgASgBuAGEAVwA0AHQAWQBtADkAMABkAEcA
>> "%~1" echo OQB0AE8AagBSAHcAZQBIADAAdQBkAEcAOQBoAGMAMwBRAGcAYwAzAEIAaABiAG4A
>> "%~1" echo dABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAyAE4AdgBiAEcA
>> "%~1" echo OQB5AE8AbgBaAGgAYwBpAGcAdABMAFcAMQAxAGQARwBWAGsASwBUAHQAcwBhAFcA
>> "%~1" echo NQBsAEwAVwBoAGwAYQBXAGQAbwBkAEQAbwB4AEwAagBRADEATwAzAGQAdgBjAG0A
>> "%~1" echo UQB0AFkAbgBKAGwAWQBXAHMANgBZAG4ASgBsAFkAVwBzAHQAZAAyADkAeQBaAEgA
>> "%~1" echo MAB1AGQARwA5AGgAYwAzAFEAdQBiADIAdAA3AFkAbQA5AHkAWgBHAFYAeQBMAFcA
>> "%~1" echo eABsAFoAbgBRAHQAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABaADMA
>> "%~1" echo SgBsAFoAVwA0AHAAZgBTADUAMABiADIARgB6AGQAQwA1AGwAYwBuAEoANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABXAHgAbABaAG4AUQB0AFkAMgA5AHMAYgAzAEkANgBkAG0A
>> "%~1" echo RgB5AEsAQwAwAHQAYwBtAFYAawBLAFgAMAB1AGQARwA5AGgAYwAzAFEAdQBkADIA
>> "%~1" echo RgB5AGIAbgB0AGkAYgAzAEoAawBaAFgASQB0AGIARwBWAG0AZABDADEAagBiADIA
>> "%~1" echo eAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQBoAGIAVwBKAGwAYwBpAGwAOQBMAG4A
>> "%~1" echo QgBoAGMAbQBGAHQAVABHAGwAegBkAEgAdABrAGEAWABOAHcAYgBHAEYANQBPAG0A
>> "%~1" echo ZAB5AGEAVwBRADcAWgAyAEYAdwBPAGoARQB3AGMASABoADkATABuAEIAaABjAG0A
>> "%~1" echo RgB0AFMAWABSAGwAYgBYAHQAawBhAFgATgB3AGIARwBGADUATwBtAGQAeQBhAFcA
>> "%~1" echo UQA3AFoAMwBKAHAAWgBDADEAMABaAFcAMQB3AGIARwBGADAAWgBTADEAagBiADIA
>> "%~1" echo eAAxAGIAVwA1AHoATwBqAEUAdQBNAG0AWgB5AEkAQwA0ADQAWgBuAEkAZwBMAGoA
>> "%~1" echo aABtAGMAaQBCAGgAZABYAFIAdgBPADIAZABoAGMARABvAHgATQBIAEIANABPADIA
>> "%~1" echo RgBzAGEAVwBkAHUATABXAGwAMABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoA
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgA
>> "%~1" echo WgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0A
>> "%~1" echo OQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADQAYwBIAGcANwBjAEcA
>> "%~1" echo RgBrAFoARwBsAHUAWgB6AG8AeABNAEgAQgA0AEkARABFAHkAYwBIAGgAOQBMAG4A
>> "%~1" echo QgBoAGMAbQBGAHQAVABtAEYAdABaAFMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo awA2AFkAbQB4AHYAWQAyAHQAOQBMAG4AQgBoAGMAbQBGAHQAVABtAEYAdABaAFMA
>> "%~1" echo QgB6AGMARwBGAHUATABDADUAdwBZAFgASgBoAGIAVgBaAGgAYgBIAFYAbABJAEgA
>> "%~1" echo TgB3AFkAVwA1ADcAWgBHAGwAegBjAEcAeABoAGUAVABwAGkAYgBHADkAagBhAHoA
>> "%~1" echo dABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHQAZABYAFIAbABaAEMA
>> "%~1" echo awA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFAHkAYwBIAGcANwBiAFcA
>> "%~1" echo RgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwB6AGMASABoADkATABuAEIAaABjAG0A
>> "%~1" echo RgB0AFYAbQBGAHMAZABXAFUAZwBZAG4AdABrAGEAWABOAHcAYgBHAEYANQBPAG0A
>> "%~1" echo SgBzAGIAMgBOAHIATwAzAGQAdgBjAG0AUQB0AFkAbgBKAGwAWQBXAHMANgBZAG4A
>> "%~1" echo SgBsAFkAVwBzAHQAZAAyADkAeQBaAEgAMAB1AGMARwBGAHkAWQBXADEAVABkAEcA
>> "%~1" echo RgAwAFoAWAB0AG8AWgBXAGwAbgBhAEgAUQA2AE0AagBaAHcAZQBEAHQAaQBiADMA
>> "%~1" echo SgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkA
>> "%~1" echo ZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcA
>> "%~1" echo UgBwAGQAWABNADYATwBUAGsANQBjAEgAZwA3AFoARwBsAHoAYwBHAHgAaABlAFQA
>> "%~1" echo cABwAGIAbQB4AHAAYgBtAFUAdABaAG0AeABsAGUARAB0AGgAYgBHAGwAbgBiAGkA
>> "%~1" echo MQBwAGQARwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAYQBuAFYAegBkAEcA
>> "%~1" echo bABtAGUAUwAxAGoAYgAyADUAMABaAFcANQAwAE8AbQBOAGwAYgBuAFIAbABjAGoA
>> "%~1" echo dAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAQQBnAE0AVABCAHcAZQBEAHQAbQBiADIA
>> "%~1" echo NQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwA0AE0ARABBADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQB6AGEAWABwAGwATwBqAEUAeQBjAEgAaAA5AEwAbgBCAGgAYwBtAEYAdABTAFgA
>> "%~1" echo UgBsAGIAUwA1AGoAYQBHAEYAdQBaADIAVgBrAGUAMgBKAHYAYwBtAFIAbABjAGkA
>> "%~1" echo MQBqAGIAMgB4AHYAYwBqAHAAeQBaADIASgBoAEsARABJAHgATgB5AHcAeABNAFQA
>> "%~1" echo awBzAE4AaQB3AHUATgBEAFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0A
>> "%~1" echo UQA2AGMAbQBkAGkAWQBTAGcAeQBNAFQAYwBzAE0AVABFADUATABEAFkAcwBMAGoA
>> "%~1" echo QQAyAEsAWAAwAHUAYwBHAEYAeQBZAFcAMQBKAGQARwBWAHQATABtAE4AbwBZAFcA
>> "%~1" echo NQBuAFoAVwBRAGcATABuAEIAaABjAG0ARgB0AFUAMwBSAGgAZABHAFYANwBZAG0A
>> "%~1" echo OQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8AbgBKAG4AWQBtAEUAbwBNAGoA
>> "%~1" echo RQAzAEwARABFAHgATwBTAHcAMgBMAEMANAAwAE4AUwBrADcAWQAyADkAcwBiADMA
>> "%~1" echo SQA2AGQAbQBGAHkASwBDADAAdABZAFcAMQBpAFoAWABJAHAATwAyAEoAaABZADIA
>> "%~1" echo dABuAGMAbQA5ADEAYgBtAFEANgBjAG0AZABpAFkAUwBnAHkATQBUAGMAcwBNAFQA
>> "%~1" echo RQA1AEwARABZAHMATABqAEEANABLAFgAMAB1AGMARwBGAHkAWQBXADEASgBkAEcA
>> "%~1" echo VgB0AEwAbQA5AHIASQBDADUAdwBZAFgASgBoAGIAVgBOADAAWQBYAFIAbABlADIA
>> "%~1" echo SgB2AGMAbQBSAGwAYwBpADEAagBiADIAeAB2AGMAagBwAHkAWgAyAEoAaABLAEQA
>> "%~1" echo SQB5AEwARABFADIATQB5AHcAMwBOAEMAdwB1AE0AegBVAHAATwAyAE4AdgBiAEcA
>> "%~1" echo OQB5AE8AbgBaAGgAYwBpAGcAdABMAFcAZAB5AFoAVwBWAHUASwBUAHQAaQBZAFcA
>> "%~1" echo TgByAFoAMwBKAHYAZABXADUAawBPAG4ASgBuAFkAbQBFAG8ATQBqAEkAcwBNAFQA
>> "%~1" echo WQB6AEwARABjADAATABDADQAdwBPAEMAbAA5AEwAbgBKAGwAYwAyAFYAMABRAG4A
>> "%~1" echo UgB1AGUAMgBoAGwAYQBXAGQAbwBkAEQAbwB6AE0ASABCADQATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAaQAxAHkAWQBXAFIAcABkAFgATQA2AE4AMwBCADQATwAyAEoAdgBjAG0A
>> "%~1" echo UgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AGIARwBsAHUAWgBTAGsANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAagBZAFgASgBrAEsAVAB0AGoAYgAyAHgAdgBjAGoA
>> "%~1" echo cAAyAFkAWABJAG8ATABTADEAMABaAFgAaAAwAEsAVAB0AG0AYgAyADUAMABMAFgA
>> "%~1" echo ZABsAGEAVwBkAG8AZABEAG8ANABNAEQAQQA3AGMARwBGAGsAWgBHAGwAdQBaAHoA
>> "%~1" echo bwB3AEkARABFAHcAYwBIAGcANwBZADMAVgB5AGMAMgA5AHkATwBuAEIAdgBhAFcA
>> "%~1" echo NQAwAFoAWABKADkATABuAEoAbABjADIAVgAwAFEAbgBSAHUATABuAEIAeQBhAFcA
>> "%~1" echo MQBoAGMAbgBsADcAWQBtADkAeQBaAEcAVgB5AEwAVwBOAHYAYgBHADkAeQBPAG4A
>> "%~1" echo SgBuAFkAbQBFAG8ATQB6AGMAcwBPAFQAawBzAE0AagBNADEATABDADQAMABOAFMA
>> "%~1" echo awA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWQBtAHgAMQBaAFMA
>> "%~1" echo bAA5AEwAbQAxAHYAWgBHAEYAcwBUAFcARgB6AGEAMwB0AHcAYgAzAE4AcABkAEcA
>> "%~1" echo bAB2AGIAagBwAG0AYQBYAGgAbABaAEQAdABwAGIAbgBOAGwAZABEAG8AdwBPADIA
>> "%~1" echo SgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAeQBMAEQA
>> "%~1" echo WQBzAE0AagBNAHMATABqAFUAMgBLAFQAdAA2AEwAVwBsAHUAWgBHAFYANABPAGoA
>> "%~1" echo UQB3AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AGIAbQA5AHUAWgBUAHQAdwBiAEcA
>> "%~1" echo RgBqAFoAUwAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBjAEcA
>> "%~1" echo RgBrAFoARwBsAHUAWgB6AG8AeABPAEgAQgA0AGYAUwA1AHQAYgAyAFIAaABiAEUA
>> "%~1" echo MQBoAGMAMgBzAHUAYwAyAGgAdgBkADMAdABrAGEAWABOAHcAYgBHAEYANQBPAG0A
>> "%~1" echo ZAB5AGEAVwBSADkATABtADEAdgBaAEcARgBzAGUAMwBkAHAAWgBIAFIAbwBPAG0A
>> "%~1" echo MQBwAGIAaQBnADAATgBqAEIAdwBlAEMAdwB4AE0ARABBAGwASwBUAHQAaQBZAFcA
>> "%~1" echo TgByAFoAMwBKAHYAZABXADUAawBPAG4AWgBoAGMAaQBnAHQATABXAE4AaABjAG0A
>> "%~1" echo UQBwAE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMASABnAGcAYwAyADkAcwBhAFcA
>> "%~1" echo UQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoAUwBrADcAWQBtADkAeQBaAEcA
>> "%~1" echo VgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwB4AE0ASABCADQATwAyAEoAdgBlAEMA
>> "%~1" echo MQB6AGEARwBGAGsAYgAzAGMANgBNAEMAQQB5AE4ASABCADQASQBEAGMAdwBjAEgA
>> "%~1" echo ZwBnAGMAbQBkAGkAWQBTAGcAdwBMAEQAQQBzAE0AQwB3AHUATQB6AFUAcABPADMA
>> "%~1" echo QgBoAFoARwBSAHAAYgBtAGMANgBNAFQAaAB3AGUASAAwAHUAYgBXADkAawBZAFcA
>> "%~1" echo dwBnAGEARABOADcAYgBXAEYAeQBaADIAbAB1AE8AagBBAGcATQBDAEEANABjAEgA
>> "%~1" echo ZwA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8AagBFADQAYwBIAGgAOQBMAG0A
>> "%~1" echo MQB2AFoARwBGAHMASQBIAEIANwBiAFcARgB5AFoAMgBsAHUATwBqAEEANwBZADIA
>> "%~1" echo OQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABPADIA
>> "%~1" echo eABwAGIAbQBVAHQAYQBHAFYAcABaADIAaAAwAE8AagBFAHUATgBqAFYAOQBMAG0A
>> "%~1" echo MQB2AFoARwBGAHMAUQBXAE4AMABhAFcAOQB1AGMAMwB0AGsAYQBYAE4AdwBiAEcA
>> "%~1" echo RgA1AE8AbQBaAHMAWgBYAGcANwBhAG4AVgB6AGQARwBsAG0AZQBTADEAagBiADIA
>> "%~1" echo NQAwAFoAVwA1ADAATwBtAFoAcwBaAFgAZwB0AFoAVwA1AGsATwAyAGQAaABjAEQA
>> "%~1" echo bwB4AE0ASABCADQATwAyADEAaABjAG0AZABwAGIAaQAxADAAYgAzAEEANgBNAFQA
>> "%~1" echo aAB3AGUASAAwAHUAYgBXADkAawBZAFcAeABCAFkAMwBSAHAAYgAyADUAegBJAEcA
>> "%~1" echo SgAxAGQASABSAHYAYgBuAHQAbwBaAFcAbABuAGEASABRADYATQB6AFIAdwBlAEQA
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEAWABWAHoATwBqAGQAdwBlAEQA
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgA
>> "%~1" echo WgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAGgAWQAyAHQAbgBjAG0A
>> "%~1" echo OQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBZADIA
>> "%~1" echo OQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGQARwBWADQAZABDAGsANwBjAEcA
>> "%~1" echo RgBrAFoARwBsAHUAWgB6AG8AdwBJAEQARQB6AGMASABnADcAWgBtADkAdQBkAEMA
>> "%~1" echo MQAzAFoAVwBsAG4AYQBIAFEANgBPAEQAQQB3AE8AMgBOADEAYwBuAE4AdgBjAGoA
>> "%~1" echo cAB3AGIAMgBsAHUAZABHAFYAeQBmAFMANQB0AGIAMgBSAGgAYgBFAEYAagBkAEcA
>> "%~1" echo bAB2AGIAbgBNAGcATABtAFIAaABiAG0AZABsAGMAbgB0AGkAWQBXAE4AcgBaADMA
>> "%~1" echo SgB2AGQAVwA1AGsATwBuAFoAaABjAGkAZwB0AEwAVwBGAHQAWQBtAFYAeQBLAFQA
>> "%~1" echo dABpAGIAMwBKAGsAWgBYAEkAdABZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMA
>> "%~1" echo MAB0AFkAVwAxAGkAWgBYAEkAcABPADIATgB2AGIARwA5AHkATwBpAE0AeABNAFQA
>> "%~1" echo RQA0AE0AagBkADkATABtAE4AdABaAEMANQBwAGMAeQAxAGkAZABYAE4ANQBMAEMA
>> "%~1" echo NQBpAGQARwA0AHUAYQBYAE0AdABZAG4AVgB6AGUAWAB0AHYAYwBHAEYAagBhAFgA
>> "%~1" echo UgA1AE8AaQA0ADIATwBEAHQAagBkAFgASgB6AGIAMwBJADYAZAAyAEYAcABkAEgA
>> "%~1" echo MAB1AFkAMgAxAGsATwBtAFIAcABjADIARgBpAGIARwBWAGsATABDADUAaQBkAEcA
>> "%~1" echo NAA2AFoARwBsAHoAWQBXAEoAcwBaAFcAUQBzAEwAbgBKAGwAYwAyAFYAMABRAG4A
>> "%~1" echo UgB1AE8AbQBSAHAAYwAyAEYAaQBiAEcAVgBrAGUAMwBCAHYAYQBXADUAMABaAFgA
>> "%~1" echo SQB0AFoAWABaAGwAYgBuAFIAegBPAG0ANQB2AGIAbQBWADkARABRAHAAQQBiAFcA
>> "%~1" echo VgBrAGEAVwBFAG8AYgBXAEYANABMAFgAZABwAFoASABSAG8ATwBqAEUAeABPAEQA
>> "%~1" echo QgB3AGUAQwBsADcATABuAEoAdgBkAHkAdwB1AGMAbQA5ADMATQAzAHQAbgBjAG0A
>> "%~1" echo bABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4A
>> "%~1" echo TQA2AE0AVwBaAHkAZgBTADUAcABiAG0AWgB2AFIAMwBKAHAAWgBIAHQAbgBjAG0A
>> "%~1" echo bABrAEwAWABSAGwAYgBYAEIAcwBZAFgAUgBsAEwAVwBOAHYAYgBIAFYAdABiAG4A
>> "%~1" echo TQA2AE0AVwBaAHkASQBEAEYAbQBjAG4AMQA5AFEARwAxAGwAWgBHAGwAaABLAEcA
>> "%~1" echo MQBoAGUAQwAxADMAYQBXAFIAMABhAEQAbwA0AE0AagBCAHcAZQBDAGwANwBMAG0A
>> "%~1" echo RgB3AGMASAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcA
>> "%~1" echo TgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AGYAUwA1AHoAYQBXAFIAbABlADMA
>> "%~1" echo QgB2AGMAMgBsADAAYQBXADkAdQBPAG4ATgAwAFkAWABSAHAAWQB6AHQAMwBhAFcA
>> "%~1" echo UgAwAGEARABwAGgAZABYAFIAdgBPADIAaABsAGEAVwBkAG8AZABEAHAAaABkAFgA
>> "%~1" echo UgB2AGYAUwA1AHQAWQBXAGwAdQBlADIAZAB5AGEAVwBRAHQAWQAyADkAcwBkAFcA
>> "%~1" echo MQB1AE8AagBGADkATABuAFIAdgBjAEgAdAB3AGIAMwBOAHAAZABHAGwAdgBiAGoA
>> "%~1" echo cAB6AGQARwBGADAAYQBXAE0ANwBhAEcAVgBwAFoAMgBoADAATwBtAEYAMQBkAEcA
>> "%~1" echo OAA3AFkAVwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWgBtAHgAbABlAEMA
>> "%~1" echo MQB6AGQARwBGAHkAZABEAHQAbQBiAEcAVgA0AEwAVwBSAHAAYwBtAFYAagBkAEcA
>> "%~1" echo bAB2AGIAagBwAGoAYgAyAHgAMQBiAFcANAA3AGMARwBGAGsAWgBHAGwAdQBaAHoA
>> "%~1" echo bwB4AE4AbgBCADQAZgBTADUAMwBjAG0ARgB3AGUAMwBCAGgAWgBHAFIAcABiAG0A
>> "%~1" echo YwA2AE0AVABSAHcAZQBIADAAdQBiAFcAVgAwAGMAbQBsAGoAUgAzAEoAcABaAEMA
>> "%~1" echo dwB1AGIAVwBsAHUAYQBVAGQAeQBhAFcAUQBzAEwAbQBOAHQAWgBFAGQAeQBhAFcA
>> "%~1" echo UQBzAEwAbQBaAHYAYwBtADAAcwBMAG4AQgBoAGMAbQBGAHQAUwBYAFIAbABiAFMA
>> "%~1" echo dwB1AGEAVwA1AG0AYgAwAGQAeQBhAFcAUQBzAEwAbQBWADQAYwBHADkAeQBkAEUA
>> "%~1" echo SgB2AGUASAB0AG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcA
>> "%~1" echo TgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AGYAUwA1ADAAYgAyAEYAegBkAEgA
>> "%~1" echo TgA3AGMAbQBsAG4AYQBIAFEANgBNAFQAUgB3AGUARAB0AGkAYgAzAFIAMABiADIA
>> "%~1" echo MAA2AE0AVABSAHcAZQBIADEAOQBEAFEAbwA4AEwAMwBOADAAZQBXAHgAbABQAGcA
>> "%~1" echo MABLAFAAQwA5AG8AWgBXAEYAawBQAGcAMABLAFAARwBKAHYAWgBIAGsAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAFIAaABjAG0AcwBpAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBuAFIAdgBZAFgATgAwAGMAeQBJAGcAYQBXAFEAOQBJAG4A
>> "%~1" echo UgB2AFkAWABOADAAYwB5AEkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAOQBrAFkAVwB4AE4AWQBYAE4AcgBJAGkA
>> "%~1" echo QgBwAFoARAAwAGkAWQAyADkAdQBaAG0AbAB5AGIAVQAxAGgAYwAyAHMAaQBQAGoA
>> "%~1" echo eABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAHYAWgBHAEYAcwBJAGoA
>> "%~1" echo NAA4AGEARABNAGcAYQBXAFEAOQBJAG0ATgB2AGIAbQBaAHAAYwBtADEAVQBhAFgA
>> "%~1" echo UgBzAFoAUwBJACsANQA2AEcAdQA2AEsANgBrADUAbwBtAG4ANgBLAEcATQBQAEMA
>> "%~1" echo OQBvAE0AegA0ADgAYwBDAEIAcABaAEQAMABpAFkAMgA5AHUAWgBtAGwAeQBiAFUA
>> "%~1" echo MQB6AFoAeQBJACsANgBMACsAWgA1AEwAaQBxADUAcABPAE4ANQBMADIAYwA1AEwA
>> "%~1" echo eQBhADUATAArAHUANQBwAFMANQBJAEYARgAxAFoAWABOADAASQBPAGUASwB0AHUA
>> "%~1" echo YQBBAGcAZQBPAEEAZwBqAHcAdgBjAEQANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAHQAYgAyAFIAaABiAEUARgBqAGQARwBsAHYAYgBuAE0AaQBQAGoA
>> "%~1" echo eABpAGQAWABSADAAYgAyADQAZwBhAFcAUQA5AEkAbQBOAHYAYgBtAFoAcABjAG0A
>> "%~1" echo MQBEAFkAVwA1AGoAWgBXAHcAaQBQAHUAVwBQAGwAdQBhADIAaQBEAHcAdgBZAG4A
>> "%~1" echo VgAwAGQARwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBSAGgAYgBtAGQAbABjAGkASQBnAGEAVwBRADkASQBtAE4AdgBiAG0A
>> "%~1" echo WgBwAGMAbQAxAFAAYQB5AEkAKwA1ADYARwB1ADYASwA2AGsANQBvAG0AbgA2AEsA
>> "%~1" echo RwBNAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAEQAUQBvADgAYwAzAFoAbgBJAEgA
>> "%~1" echo ZABwAFoASABSAG8AUABTAEkAdwBJAGkAQgBvAFoAVwBsAG4AYQBIAFEAOQBJAGoA
>> "%~1" echo QQBpAEkASABOADAAZQBXAHgAbABQAFMASgB3AGIAMwBOAHAAZABHAGwAdgBiAGoA
>> "%~1" echo cABoAFkAbgBOAHYAYgBIAFYAMABaAFMASQArAFAASABOADUAYgBXAEoAdgBiAEMA
>> "%~1" echo QgBwAFoARAAwAGkAYQBTADEAMgBjAGkASQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQA
>> "%~1" echo MABpAE0AQwBBAHcASQBEAEkAMABJAEQASQAwAEkAagA0ADgAYwBHAEYAMABhAEMA
>> "%~1" echo QgBrAFAAUwBKAE4ATQBDAEEAdwBhAEQASQAwAGQAagBJADAAUwBEAEIANgBJAGkA
>> "%~1" echo QgBtAGEAVwB4AHMAUABTAEoAdQBiADIANQBsAEkAaQA4ACsAUABIAEIAaABkAEcA
>> "%~1" echo ZwBnAFoARAAwAGkAVABUAFkAZwBPAFcAZwB4AE0AbQBFAHoASQBEAE0AZwBNAEMA
>> "%~1" echo QQB3AEkARABFAGcATQB5AEEAegBkAGoATgBoAE0AeQBBAHoASQBEAEEAZwBNAEMA
>> "%~1" echo QQB4AEwAVABNAGcATQAyAGcAdABNAFMANAAxAGIAQwAwAHkATABqAFUAdABNADIA
>> "%~1" echo ZwB0AE4ARwB3AHQATQBpADQAMQBJAEQATgBJAE4AbQBFAHoASQBEAE0AZwBNAEMA
>> "%~1" echo QQB3AEkARABFAHQATQB5ADAAegBkAGkAMAB6AFkAVABNAGcATQB5AEEAdwBJAEQA
>> "%~1" echo QQBnAE0AUwBBAHoATABUAE4ANgBJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQA
>> "%~1" echo MABpAFQAVABrAGcATQBUAEoAbwBMAGoAQQB4AEkAaQA4ACsAUABIAEIAaABkAEcA
>> "%~1" echo ZwBnAFoARAAwAGkAVABUAEUAMQBJAEQARQB5AGEAQwA0AHcATQBTAEkAdgBQAGoA
>> "%~1" echo eAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAB4AE0AQwBBAHgATgBXAGcAMABJAGkA
>> "%~1" echo OAArAFAAQwA5AHoAZQBXADEAaQBiADIAdwArAFAASABOADUAYgBXAEoAdgBiAEMA
>> "%~1" echo QgBwAFoARAAwAGkAYQBTADEAbwBiADIAMQBsAEkAaQBCADIAYQBXAFYAMwBRAG0A
>> "%~1" echo OQA0AFAAUwBJAHcASQBEAEEAZwBNAGoAUQBnAE0AagBRAGkAUABqAHgAdwBZAFgA
>> "%~1" echo UgBvAEkARwBRADkASQBrADAAdwBJAEQAQgBvAE0AagBSADIATQBqAFIASQBNAEgA
>> "%~1" echo bwBpAEkARwBaAHAAYgBHAHcAOQBJAG0ANQB2AGIAbQBVAGkATAB6ADQAOABjAEcA
>> "%~1" echo RgAwAGEAQwBCAGsAUABTAEoATgBOAFMAQQB4AE0AbQB3ADMATABUAGQAcwBOAHkA
>> "%~1" echo QQAzAEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABUAFkAZwBNAFQA
>> "%~1" echo QgAyAE8AVwBnAHgATQBuAFkAdABPAFMASQB2AFAAagB3AHYAYwAzAGwAdABZAG0A
>> "%~1" echo OQBzAFAAagB4AHoAZQBXADEAaQBiADIAdwBnAGEAVwBRADkASQBtAGsAdABZADIA
>> "%~1" echo OQB1AGMAMgA5AHMAWgBTAEkAZwBkAG0AbABsAGQAMABKAHYAZQBEADAAaQBNAEMA
>> "%~1" echo QQB3AEkARABJADAASQBEAEkAMABJAGoANAA4AGMARwBGADAAYQBDAEIAawBQAFMA
>> "%~1" echo SgBOAE0AQwBBAHcAYQBEAEkAMABkAGoASQAwAFMARABCADYASQBpAEIAbQBhAFcA
>> "%~1" echo eABzAFAAUwBKAHUAYgAyADUAbABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQA
>> "%~1" echo MABpAFQAVABnAGcATwBXAHcAegBJAEQATgBzAEwAVABNAGcATQB5AEkAdgBQAGoA
>> "%~1" echo eAB3AFkAWABSAG8ASQBHAFEAOQBJAGsAMAB4AE0AeQBBAHgATgBXAGcAegBJAGkA
>> "%~1" echo OAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQAVABNAGcATgBHAGcAeABPAEgA
>> "%~1" echo WQB4AE4AawBnAHoAZQBpAEkAdgBQAGoAdwB2AGMAMwBsAHQAWQBtADkAcwBQAGoA
>> "%~1" echo eAB6AGUAVwAxAGkAYgAyAHcAZwBhAFcAUQA5AEkAbQBrAHQAYQBXADUAbQBiAHkA
>> "%~1" echo SQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQAMABpAE0AQwBBAHcASQBEAEkAMABJAEQA
>> "%~1" echo SQAwAEkAagA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATQBDAEEAdwBhAEQA
>> "%~1" echo SQAwAGQAagBJADAAUwBEAEIANgBJAGkAQgBtAGEAVwB4AHMAUABTAEoAdQBiADIA
>> "%~1" echo NQBsAEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABUAEUAeQBJAEQA
>> "%~1" echo bABvAEwAagBBAHgASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQA
>> "%~1" echo RQB4AEkARABFAHkAYQBEAEYAMgBOAEcAZwB4AEkAaQA4ACsAUABIAEIAaABkAEcA
>> "%~1" echo ZwBnAFoARAAwAGkAVABUAEUAeQBJAEQATgBoAE8AUwBBADUASQBEAEEAZwBNAFMA
>> "%~1" echo QQB3AEkARABBAGcATQBUAGgAaABPAFMAQQA1AEkARABBAGcATQBDAEEAdwBJAEQA
>> "%~1" echo QQB0AE0AVABoADYASQBpADgAKwBQAEMAOQB6AGUAVwAxAGkAYgAyAHcAKwBQAEgA
>> "%~1" echo TgA1AGIAVwBKAHYAYgBDAEIAcABaAEQAMABpAGEAUwAxAHoAWgBYAFIAMABhAFcA
>> "%~1" echo NQBuAGMAeQBJAGcAZABtAGwAbABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQA
>> "%~1" echo SQAwAEkARABJADAASQBqADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBNAEMA
>> "%~1" echo QQB3AGEARABJADAAZABqAEkAMABTAEQAQgA2AEkAaQBCAG0AYQBXAHgAcwBQAFMA
>> "%~1" echo SgB1AGIAMgA1AGwASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQA
>> "%~1" echo RQB3AEwAagBNAHkATgBTAEEAMABMAGoATQB4AE4AMgBFAHkASQBEAEkAZwBNAEMA
>> "%~1" echo QQB3AEkARABFAGcATQB5ADQAegBOAFMAQQB3AGIAQwA0AHkATABqAE0AMABOAEcA
>> "%~1" echo RQB5AEkARABJAGcATQBDAEEAdwBJAEQAQQBnAE0AaQA0AHcATQBEAGsAdQBPAFQA
>> "%~1" echo WgBzAEwAagBNADUATQBpADAAdQBNAEQAYwAwAFkAVABJAGcATQBpAEEAdwBJAEQA
>> "%~1" echo QQBnAE0AUwBBAHkATABqAE0AMgBJAEQASQB1AE0AegBaAHMATABTADQAdwBOAHoA
>> "%~1" echo UQB1AE0AegBrAHkAWQBUAEkAZwBNAGkAQQB3AEkARABBAGcATQBDAEEAdQBPAFQA
>> "%~1" echo WQBnAE0AaQA0AHcATQBEAGwAcwBMAGoATQAwAE4AQwA0AHkAWQBUAEkAZwBNAGkA
>> "%~1" echo QQB3AEkARABBAGcATQBTAEEAdwBJAEQATQB1AE0AegBWAHMATABTADQAegBOAEQA
>> "%~1" echo UQB1AE0AbQBFAHkASQBEAEkAZwBNAEMAQQB3AEkARABBAHQATABqAGsAMgBJAEQA
>> "%~1" echo SQB1AE0ARABBADUAYgBDADQAdwBOAHoAUQB1AE0AegBrAHkAWQBUAEkAZwBNAGkA
>> "%~1" echo QQB3AEkARABBAGcATQBTADAAeQBMAGoATQAyAEkARABJAHUATQB6AFoAcwBMAFMA
>> "%~1" echo NAB6AE8AVABJAHQATABqAEEAMwBOAEcARQB5AEkARABJAGcATQBDAEEAdwBJAEQA
>> "%~1" echo QQB0AE0AaQA0AHcATQBEAGsAdQBPAFQAWgBzAEwAUwA0AHkATABqAE0AMABOAEcA
>> "%~1" echo RQB5AEkARABJAGcATQBDAEEAdwBJAEQARQB0AE0AeQA0AHoATgBTAEEAdwBiAEMA
>> "%~1" echo MAB1AE0AaQAwAHUATQB6AFEAMABZAFQASQBnAE0AaQBBAHcASQBEAEEAZwBNAEMA
>> "%~1" echo MAB5AEwAagBBAHcATwBTADAAdQBPAFQAWgBzAEwAUwA0AHoATwBUAEkAdQBNAEQA
>> "%~1" echo YwAwAFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AUwAwAHkATABqAE0AMgBMAFQA
>> "%~1" echo SQB1AE0AegBaAHMATABqAEEAMwBOAEMAMAB1AE0AegBrAHkAWQBUAEkAZwBNAGkA
>> "%~1" echo QQB3AEkARABBAGcATQBDADAAdQBPAFQAWQB0AE0AaQA0AHcATQBEAGwAcwBMAFMA
>> "%~1" echo NAB6AE4ARABRAHQATABqAEoAaABNAGkAQQB5AEkARABBAGcATQBDAEEAeABJAEQA
>> "%~1" echo QQB0AE0AeQA0AHoATgBXAHcAdQBNAHoAUQAwAEwAUwA0AHkAWQBUAEkAZwBNAGkA
>> "%~1" echo QQB3AEkARABBAGcATQBDAEEAdQBPAFQAWQB0AE0AaQA0AHcATQBEAGwAcwBMAFMA
>> "%~1" echo NAB3AE4AegBRAHQATABqAE0ANQBNAG0ARQB5AEkARABJAGcATQBDAEEAdwBJAEQA
>> "%~1" echo RQBnAE0AaQA0AHoATgBpADAAeQBMAGoATQAyAGIAQwA0AHoATwBUAEkAdQBNAEQA
>> "%~1" echo YwAwAFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0AQwBBAHkATABqAEEAdwBPAFMA
>> "%~1" echo MAB1AE8AVABaADYASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQA
>> "%~1" echo awBnAE0AVABKAGgATQB5AEEAegBJAEQAQQBnAE0AUwBBAHcASQBEAFkAZwBNAEcA
>> "%~1" echo RQB6AEkARABNAGcATQBDAEEAdwBJAEQAQQB0AE4AaQBBAHcASQBpADgAKwBQAEMA
>> "%~1" echo OQB6AGUAVwAxAGkAYgAyAHcAKwBQAEgATgA1AGIAVwBKAHYAYgBDAEIAcABaAEQA
>> "%~1" echo MABpAGEAUwAxAHMAYgAyAGMAaQBJAEgAWgBwAFoAWABkAEMAYgAzAGcAOQBJAGoA
>> "%~1" echo QQBnAE0AQwBBAHkATgBDAEEAeQBOAEMASQArAFAASABCAGgAZABHAGcAZwBaAEQA
>> "%~1" echo MABpAFQAVABBAGcATQBHAGcAeQBOAEgAWQB5AE4ARQBnAHcAZQBpAEkAZwBaAG0A
>> "%~1" echo bABzAGIARAAwAGkAYgBtADkAdQBaAFMASQB2AFAAagB4AHcAWQBYAFIAbwBJAEcA
>> "%~1" echo UQA5AEkAawAwADEASQBEAFYAbwBNAFQAUgAyAE0AVABSAEkATgBYAG8AaQBMAHoA
>> "%~1" echo NAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE8AUwBBADUAYQBEAFkAaQBMAHoA
>> "%~1" echo NAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE8AUwBBAHgATQAyAGcAMgBJAGkA
>> "%~1" echo OAArAFAAQwA5AHoAZQBXADEAaQBiADIAdwArAFAAQwA5AHoAZABtAGMAKwBEAFEA
>> "%~1" echo bwA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGgAYwBIAEEAaQBQAGoA
>> "%~1" echo eABoAGMAMgBsAGsAWgBTAEIAagBiAEcARgB6AGMAegAwAGkAYwAyAGwAawBaAFMA
>> "%~1" echo SQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBuAEoAaABiAG0A
>> "%~1" echo UQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAeQBZAFcA
>> "%~1" echo NQBrAFMAVwBOAHYAYgBpAEkAKwBQAEgATgAyAFoAeQBCADMAYQBXAFIAMABhAEQA
>> "%~1" echo MABpAE0AagBJAGkASQBHAGgAbABhAFcAZABvAGQARAAwAGkATQBqAEkAaQBQAGoA
>> "%~1" echo eAAxAGMAMgBVAGcAYQBIAEoAbABaAGoAMABpAEkAMgBrAHQAZABuAEkAaQBMAHoA
>> "%~1" echo NAA4AEwAMwBOADIAWgB6ADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBQAGoA
>> "%~1" echo eABpAFAAbABGADEAWgBYAE4AMABJAEUARgBFAFEAagB3AHYAWQBqADQAOABjADMA
>> "%~1" echo QgBoAGIAagA1AFQAYQBXADUAbgBiAEcAVQBnAFEAawBGAFUASQBGAGQAbABZAGwA
>> "%~1" echo VgBKAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB4AHUAWQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADUAaABkAGkA
>> "%~1" echo SQArAFAARwBFAGcAYQBIAEoAbABaAGoAMABpAEkAMgA5ADIAWgBYAEoAMgBhAFcA
>> "%~1" echo VgAzAEkAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAVwBOADAAYQBYAFoAbABJAGoA
>> "%~1" echo NAA4AGMAMwBaAG4AUABqAHgAMQBjADIAVQBnAGEASABKAGwAWgBqADAAaQBJADIA
>> "%~1" echo awB0AGEARwA5AHQAWgBTAEkAdgBQAGoAdwB2AGMAMwBaAG4AUAB1AGEAQQB1ACsA
>> "%~1" echo aQBuAGkARAB3AHYAWQBUADQAOABZAFMAQgBvAGMAbQBWAG0AUABTAEkAagBZADIA
>> "%~1" echo OQB1AGMAMgA5AHMAWgBTAEkAKwBQAEgATgAyAFoAegA0ADgAZABYAE4AbABJAEcA
>> "%~1" echo aAB5AFoAVwBZADkASQBpAE4AcABMAFcATgB2AGIAbgBOAHYAYgBHAFUAaQBMAHoA
>> "%~1" echo NAA4AEwAMwBOADIAWgB6ADcAbAB2ADYAdgBtAGoAYgBmAG0AagBxAGYAbABpAEwA
>> "%~1" echo YgBsAGoANwBBADgATAAyAEUAKwBQAEcARQBnAGEASABKAGwAWgBqADAAaQBJADIA
>> "%~1" echo UgBsAGQAbQBsAGoAWgBTAEkAKwBQAEgATgAyAFoAegA0ADgAZABYAE4AbABJAEcA
>> "%~1" echo aAB5AFoAVwBZADkASQBpAE4AcABMAFcAbAB1AFoAbQA4AGkATAB6ADQAOABMADMA
>> "%~1" echo TgAyAFoAegA3AG8AcgByADcAbABwAEkAZgBrAHYANgBIAG0AZwBhADgAOABMADIA
>> "%~1" echo RQArAFAARwBFAGcAYQBIAEoAbABaAGoAMABpAEkAMwBOAGwAZABIAFIAcABiAG0A
>> "%~1" echo ZAB6AEkAagA0ADgAYwAzAFoAbgBQAGoAeAAxAGMAMgBVAGcAYQBIAEoAbABaAGoA
>> "%~1" echo MABpAEkAMgBrAHQAYwAyAFYAMABkAEcAbAB1AFoAMwBNAGkATAB6ADQAOABMADMA
>> "%~1" echo TgAyAFoAegA3AHAAcQA1AGoAbgB1AHEAYwBnAGMAMgBWADAAZABHAGwAdQBaADMA
>> "%~1" echo TQA4AEwAMgBFACsAUABHAEUAZwBhAEgASgBsAFoAagAwAGkASQAyAHgAdgBaADMA
>> "%~1" echo TQBpAFAAagB4AHoAZABtAGMAKwBQAEgAVgB6AFoAUwBCAG8AYwBtAFYAbQBQAFMA
>> "%~1" echo SQBqAGEAUwAxAHMAYgAyAGMAaQBMAHoANAA4AEwAMwBOADIAWgB6ADcAbQBsADYA
>> "%~1" echo WABsAHYANQBjADgATAAyAEUAKwBQAEMAOQB1AFkAWABZACsAUABDADkAaABjADIA
>> "%~1" echo bABrAFoAVAA0ADgAYgBXAEYAcABiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcA
>> "%~1" echo RgBwAGIAaQBJACsAUABHAGgAbABZAFcAUgBsAGMAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAGQARwA5AHcASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgAwAGEAWABSAHMAWgBTAEkAKwBQAEcAZwB4AEkARwBsAGsAUABTAEoAdwBZAFcA
>> "%~1" echo ZABsAFYARwBsADAAYgBHAFUAaQBQAHUAYQBBAHUAKwBpAG4AaQBEAHcAdgBhAEQA
>> "%~1" echo RQArAFAASABBAGcAYQBXAFEAOQBJAG4AQgBoAFoAMgBWAFQAZABXAEkAaQBQAHUA
>> "%~1" echo ZQBLAHQAdQBhAEEAZwBlAGEATQBoACsAYQBnAGgAKwBXAFMAagBPAGkAdQB2AHUA
>> "%~1" echo VwBrAGgAKwBhAG0AZwB1AGkAbgBpAEQAdwB2AGMARAA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKADAAYgAyADkAcwBZAG0A
>> "%~1" echo RgB5AEkAagA0ADgAYwAzAEIAaABiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIA
>> "%~1" echo aABwAGMAQwBJAGcAYQBXAFEAOQBJAG4ATgAwAFkAWABSADEAYwAwAE4AbwBhAFgA
>> "%~1" echo QQBpAFAAagB4AHAASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYQBHAGwAdwBSAEcA
>> "%~1" echo OQAwAEkAagA0ADgATAAyAGsAKwBQAEgATgB3AFkAVwA0ACsANQBwAHkAcQA2AEwA
>> "%~1" echo KwBlADUAbwA2AGwAUABDADkAegBjAEcARgB1AFAAagB3AHYAYwAzAEIAaABiAGoA
>> "%~1" echo NAA4AGMAMwBCAGgAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAGgAcABjAEMA
>> "%~1" echo SQArAFEAVQBSAEMASQBEAHgAaQBJAEcAbABrAFAAUwBKAGgAWgBHAEoAVABhAEcA
>> "%~1" echo OQB5AGQAQwBJACsAWQBXAFIAaQBMAG0AVgA0AFoAVAB3AHYAWQBqADQAOABMADMA
>> "%~1" echo TgB3AFkAVwA0ACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgBvAGEAWABBAGkAUABsAGQAcABMAFUAWgBwAEkARAB4AGkASQBHAGwAawBQAFMA
>> "%~1" echo SgAzAGEAVwBaAHAAUQAyAGgAcABjAEMASQArAEwAVAB3AHYAWQBqADQAOABMADMA
>> "%~1" echo TgB3AFkAVwA0ACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAFkAbgBSAHUASQBHAGQAbwBiADMATgAwAEkAaQBCAHAAWgBEADAAaQBkAEcA
>> "%~1" echo aABsAGIAVwBWAEMAZABHADQAaQBQAHUAYQAxAGgAZQBpAEoAcwBqAHcAdgBZAG4A
>> "%~1" echo VgAwAGQARwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBKADAAYgBpAEIAdwBjAG0AbAB0AFkAWABKADUASQBpAEIAcABaAEQA
>> "%~1" echo MABpAGMAbQBWAG0AYwBtAFYAegBhAEUASgAwAGIAaQBJACsANQBZAGkAMwA1AHAA
>> "%~1" echo YQB3AFAAQwA5AGkAZABYAFIAMABiADIANAArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBvAFoAVwBGAGsAWgBYAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAGQAMwBKAGgAYwBDAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAGIAbQA5ADAAYQBXAE4AbABJAGoANwBrAHYANQAzAG0AdABMAHYAagBnAEkA
>> "%~1" echo RQB5AE4AQwBEAGwAcwBJAC8AbQBsADcAYgBrAHUAcQA3AGwAcwBZAC8AbABrAG8A
>> "%~1" echo egBtAGwANgBEAG4AdQByADgAZwBRAFUAUgBDAEkATwBXAFAAcQB1AFcANwB1AHUA
>> "%~1" echo aQB1AHIAdQBlAGYAcgBlAGEAWAB0AHUAbQBYAHQATwBhADEAaQArAGkAdgBsAGUA
>> "%~1" echo KwA4AG0AKwBlADcAawArAGEAZABuACsAVwBRAGoAdQBhAEoAcAArAGkAaABqAE8A
>> "%~1" echo SwBBAG4ATwBXAHUAaQBlAFcARgBxAE8AZQBHAGgATwBXAHgAagArAEsAQQBuAGUA
>> "%~1" echo YQBJAGwAdQBLAEEAbgBPAFMALwBuAGUAVwB1AGkATwBtADcAbQBPAGkAdQBwAE8A
>> "%~1" echo VwBBAHYATwBLAEEAbgBlAE8AQQBnAGoAdwB2AFoARwBsADIAUABnADAASwBQAEgA
>> "%~1" echo TgBsAFkAMwBSAHAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABaADIA
>> "%~1" echo VQBnAFkAVwBOADAAYQBYAFoAbABJAGkAQgBwAFoARAAwAGkAYgAzAFoAbABjAG4A
>> "%~1" echo WgBwAFoAWABjAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4A
>> "%~1" echo SgB2AGQAeQBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIA
>> "%~1" echo RgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAEcA
>> "%~1" echo VgBoAFoAQwBJACsAUABHAGcAeQBQAHUAaQB1AHYAdQBXAGsAaAB6AHcAdgBhAEQA
>> "%~1" echo SQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABaAHkA
>> "%~1" echo SQBnAGEAVwBRADkASQBtAFIAbABkAG0AbABqAFoAVgBSAGgAWgB5AEkAKwBVAFgA
>> "%~1" echo VgBsAGMAMwBRADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAbQA5AGsAZQBTAEkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEARwBWAGgAWgBIAE4AbABkAEUA
>> "%~1" echo SgB2AGUAQwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBaAEcA
>> "%~1" echo VgAyAGEAVwBOAGwAUwBXAE4AdgBiAGkASQArAFAASABOADIAWgB6ADQAOABkAFgA
>> "%~1" echo TgBsAEkARwBoAHkAWgBXAFkAOQBJAGkATgBwAEwAWABaAHkASQBpADgAKwBQAEMA
>> "%~1" echo OQB6AGQAbQBjACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBrAFoAWABaAHAAWQAyAFYATwBZAFcA
>> "%~1" echo MQBsAEkAaQBCAHAAWgBEADAAaQBhAEcAVgB5AGIAMAAxAHYAWgBHAFYAcwBJAGoA
>> "%~1" echo NQBSAGQAVwBWAHoAZABEAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAGgAcABiAG4AUQBpAEkARwBsAGsAUABTAEoAegBkAEcA
>> "%~1" echo RgAwAFoAVQBoAHAAYgBuAFEAaQBQAHUAZQB0AGkAZQBXACsAaABlAGkAdgB1ACsA
>> "%~1" echo VwBQAGwAdQBpAHUAdgB1AFcAawBoACsAZQBLAHQAdQBhAEEAZwBlAE8AQQBnAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4A
>> "%~1" echo TgAwAFkAWABSAGwASQBpAEIAcABaAEQAMABpAGMAMwBSAGgAZABHAFYAQwBhAFcA
>> "%~1" echo YwBpAFAAbQA1AHYAYgBtAFUAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgB5AGEAVwBjAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBDAGIAMwBnAGcAYgBHAFYAbQBkAEMA
>> "%~1" echo SQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAEoAdgBiAEcA
>> "%~1" echo VQBpAFAAdQBXADMAcAB1AGEASgBpACsAYQBmAGgARAB3AHYAYwAzAEIAaABiAGoA
>> "%~1" echo NAA4AFkAaQBCAHAAWgBEADAAaQBiAEcAVgBtAGQARQBOAHYAYgBuAFIAeQBiADIA
>> "%~1" echo eABzAFoAWABKAE0AYQBYAFIAbABJAGoANAB0AEwAVAB3AHYAWQBqADQAOABjADMA
>> "%~1" echo QgBoAGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMAMwBSAGgAZABHAFYAVQBaAFgA
>> "%~1" echo aAAwAEkAaQBCAHAAWgBEADAAaQBiAEcAVgBtAGQARQBOAHYAYgBuAFIAeQBiADIA
>> "%~1" echo eABzAFoAWABKAFQAZABHAEYAMABaAFMASQArAEwAVAB3AHYAYwAzAEIAaABiAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgB0AFoAWABSAGgAUwBYAFIAbABiAFMASQArAFAASABOAHcAWQBXADQAKwBWADIA
>> "%~1" echo awB0AFIAbQBrAGcAUwBWAEEAOABMADMATgB3AFkAVwA0ACsAUABHAEkAZwBhAFcA
>> "%~1" echo UQA5AEkAbgBkAHAAWgBtAGwASgBjAEUAeABwAGQARwBVAGkAUABpADAAOABMADIA
>> "%~1" echo SQArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAFkAMgA5AHUAZABIAEoAdgBiAEcAeABsAGMAawBKAHYAZQBDAEIAeQBhAFcA
>> "%~1" echo ZABvAGQAQwBJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4A
>> "%~1" echo SgB2AGIARwBVAGkAUAB1AFcAUABzACsAYQBKAGkAKwBhAGYAaABEAHcAdgBjADMA
>> "%~1" echo QgBoAGIAagA0ADgAWQBpAEIAcABaAEQAMABpAGMAbQBsAG4AYQBIAFIARABiADIA
>> "%~1" echo NQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoAUwBJACsATABTADAAOABMADIA
>> "%~1" echo SQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAE4AMABZAFgA
>> "%~1" echo UgBsAFYARwBWADQAZABDAEkAZwBhAFcAUQA5AEkAbgBKAHAAWgAyAGgAMABRADIA
>> "%~1" echo OQB1AGQASABKAHYAYgBHAHgAbABjAGwATgAwAFkAWABSAGwASQBqADQAdABQAEMA
>> "%~1" echo OQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAbgBpAHIA
>> "%~1" echo YgBtAGcASQBIAG0AagBJAGYAbQBvAEkAYwA4AEwAMgBnAHkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkASQBHAGwAawBQAFMA
>> "%~1" echo SgBqAGIARwA5AGoAYQAxAFIAbABlAEgAUQBpAFAAaQAwADgATAAzAE4AdwBZAFcA
>> "%~1" echo NAArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAFkAbQA5AGsAZQBTAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAGIAVwBWADAAYwBtAGwAagBSADMASgBwAFoAQwBJACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMAbQBsAGoASQBpAEIAcABaAEQA
>> "%~1" echo MABpAFkAbQBGADAAZABHAFYAeQBlAFUAZABoAGQAVwBkAGwASQBqADQAOABjADMA
>> "%~1" echo WgBuAEkARwBOAHMAWQBYAE4AegBQAFMASgB5AGEAVwA1AG4ASQBpAEIAMgBhAFcA
>> "%~1" echo VgAzAFEAbQA5ADQAUABTAEkAdwBJAEQAQQBnAE0AVABBAHcASQBEAEUAdwBNAEMA
>> "%~1" echo SQArAFAARwBOAHAAYwBtAE4AcwBaAFMAQgBqAGIARwBGAHoAYwB6ADAAaQBkAEgA
>> "%~1" echo SgBoAFkAMgBzAGkASQBHAE4ANABQAFMASQAxAE0AQwBJAGcAWQAzAGsAOQBJAGoA
>> "%~1" echo VQB3AEkAaQBCAHkAUABTAEkAMABNAEMASQBnAGMARwBGADAAYQBFAHgAbABiAG0A
>> "%~1" echo ZAAwAGEARAAwAGkATQBUAEEAdwBJAGkAOAArAFAARwBOAHAAYwBtAE4AcwBaAFMA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAFoAWABJAGkASQBHAE4ANABQAFMA
>> "%~1" echo SQAxAE0AQwBJAGcAWQAzAGsAOQBJAGoAVQB3AEkAaQBCAHkAUABTAEkAMABNAEMA
>> "%~1" echo SQBnAGMARwBGADAAYQBFAHgAbABiAG0AZAAwAGEARAAwAGkATQBUAEEAdwBJAGkA
>> "%~1" echo QgB6AGQASABKAHYAYQAyAFUAdABaAEcARgB6AGEARwBGAHkAYwBtAEYANQBQAFMA
>> "%~1" echo SQB3AEkARABFAHcATQBDAEkAdgBQAGoAdwB2AGMAMwBaAG4AUABqAHgAawBhAFgA
>> "%~1" echo WQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYgBXAFYAMABjAG0A
>> "%~1" echo bABqAFYAbQBGAHMAZABXAFUAaQBJAEcAbABrAFAAUwBKAGkAWQBYAFIAMABaAFgA
>> "%~1" echo SgA1AFYARwBWADQAZABDAEkAKwBMAFMAMABsAFAAQwA5AGsAYQBYAFkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIAVwBWADAAYwBtAGwAagBUAEcA
>> "%~1" echo RgBpAFoAVwB3AGkASQBHAGwAawBQAFMASgBpAFkAWABSADAAWgBYAEoANQBVADMA
>> "%~1" echo VgBpAEkAagA3AG4AbABMAFgAcABoADQAOAA4AEwAMgBSAHAAZABqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAHQAWgBYAFIAeQBhAFcATQBpAEkARwBsAGsAUABTAEoAMABaAFcA
>> "%~1" echo MQB3AFIAMgBGADEAWgAyAFUAaQBQAGoAeAB6AGQAbQBjAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbgBKAHAAYgBtAGMAaQBJAEgAWgBwAFoAWABkAEMAYgAzAGcAOQBJAGoA
>> "%~1" echo QQBnAE0AQwBBAHgATQBEAEEAZwBNAFQAQQB3AEkAagA0ADgAWQAyAGwAeQBZADIA
>> "%~1" echo eABsAEkARwBOAHMAWQBYAE4AegBQAFMASgAwAGMAbQBGAGoAYQB5AEkAZwBZADMA
>> "%~1" echo ZwA5AEkAagBVAHcASQBpAEIAagBlAFQAMABpAE4AVABBAGkASQBIAEkAOQBJAGoA
>> "%~1" echo UQB3AEkAaQBCAHcAWQBYAFIAbwBUAEcAVgB1AFoAMwBSAG8AUABTAEkAeABNAEQA
>> "%~1" echo QQBpAEwAegA0ADgAWQAyAGwAeQBZADIAeABsAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgB0AFoAWABSAGwAYwBpAEkAZwBZADMAZwA5AEkAagBVAHcASQBpAEIAagBlAFQA
>> "%~1" echo MABpAE4AVABBAGkASQBIAEkAOQBJAGoAUQB3AEkAaQBCAHcAWQBYAFIAbwBUAEcA
>> "%~1" echo VgB1AFoAMwBSAG8AUABTAEkAeABNAEQAQQBpAEkASABOADAAYwBtADkAcgBaAFMA
>> "%~1" echo MQBrAFkAWABOAG8AWQBYAEoAeQBZAFgAawA5AEkAagBBAGcATQBUAEEAdwBJAGkA
>> "%~1" echo OAArAFAAQwA5AHoAZABtAGMAKwBQAEcAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAdABaAFgAUgB5AGEAVwBOAFcAWQBXAHgAMQBaAFMA
>> "%~1" echo SQBnAGEAVwBRADkASQBuAFIAbABiAFgAQgBVAFoAWABoADAASQBqADQAdABMAGMA
>> "%~1" echo SwB3AFEAegB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQAxAGwAZABIAEoAcABZADAAeABoAFkAbQBWAHMASQBpAEIAcABaAEQA
>> "%~1" echo MABpAGQARwBWAHQAYwBGAE4AMQBZAGkASQArADUAcgBpAHAANQBiAHEAbQBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIAVwBWADAAYwBtAGwAagBJAGkA
>> "%~1" echo QgBwAFoARAAwAGkAYwAyAHgAbABaAFgAQgBIAFkAWABWAG4AWgBTAEkAKwBQAEgA
>> "%~1" echo TgAyAFoAeQBCAGoAYgBHAEYAegBjAHoAMABpAGMAbQBsAHUAWgB5AEkAZwBkAG0A
>> "%~1" echo bABsAGQAMABKAHYAZQBEADAAaQBNAEMAQQB3AEkARABFAHcATQBDAEEAeABNAEQA
>> "%~1" echo QQBpAFAAagB4AGoAYQBYAEoAagBiAEcAVQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4A
>> "%~1" echo UgB5AFkAVwBOAHIASQBpAEIAagBlAEQAMABpAE4AVABBAGkASQBHAE4ANQBQAFMA
>> "%~1" echo SQAxAE0AQwBJAGcAYwBqADAAaQBOAEQAQQBpAEkASABCAGgAZABHAGgATQBaAFcA
>> "%~1" echo NQBuAGQARwBnADkASQBqAEUAdwBNAEMASQB2AFAAagB4AGoAYQBYAEoAagBiAEcA
>> "%~1" echo VQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQARwBWAHkASQBpAEIAagBlAEQA
>> "%~1" echo MABpAE4AVABBAGkASQBHAE4ANQBQAFMASQAxAE0AQwBJAGcAYwBqADAAaQBOAEQA
>> "%~1" echo QQBpAEkASABCAGgAZABHAGgATQBaAFcANQBuAGQARwBnADkASQBqAEUAdwBNAEMA
>> "%~1" echo SQBnAGMAMwBSAHkAYgAyAHQAbABMAFcAUgBoAGMAMgBoAGgAYwBuAEoAaABlAFQA
>> "%~1" echo MABpAE0AQwBBAHgATQBEAEEAaQBMAHoANAA4AEwAMwBOADIAWgB6ADQAOABaAEcA
>> "%~1" echo bAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADEAbABkAEgA
>> "%~1" echo SgBwAFkAMQBaAGgAYgBIAFYAbABJAGkAQgBwAFoARAAwAGkAYwAyAHgAbABaAFgA
>> "%~1" echo QgBVAFoAWABoADAASQBqADQAdABQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMAbQBsAGoAVABHAEYAaQBaAFcA
>> "%~1" echo dwBpAEkARwBsAGsAUABTAEoAegBiAEcAVgBsAGMARgBOADEAWQBpAEkAKwA1AEwA
>> "%~1" echo eQBSADUANQB5AGcAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAYgBXAGwAdQBhAFUAZAB5AGEAVwBRAGkAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBwAGIAbQBrAGkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AFAAbABOAHYAUQB6AHcAdgBjADMAQgBoAGIAagA0ADgAWQBpAEIAcABaAEQA
>> "%~1" echo MABpAGMAMgA5AGoAVABHAGwAMABaAFMASQArAEwAVAB3AHYAWQBqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABhAFcA
>> "%~1" echo NQBwAEkAagA0ADgAYwAzAEIAaABiAGoANwBtAG0ATAA3AG4AcABMAG8AOABMADMA
>> "%~1" echo TgB3AFkAVwA0ACsAUABHAEkAZwBhAFcAUQA5AEkAbQBSAHAAYwAzAEIAcwBZAFgA
>> "%~1" echo bABUAGQAVwAxAHQAWQBYAEoANQBUAEcAbAAwAFoAUwBJACsATABUAHcAdgBZAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgB0AGEAVwA1AHAASQBqADQAOABjADMAQgBoAGIAagA3AG4AZwA2ADMAbgBpAHIA
>> "%~1" echo YgBtAGcASQBFADgATAAzAE4AdwBZAFcANAArAFAARwBJAGcAYQBXAFEAOQBJAG4A
>> "%~1" echo UgBvAFoAWABKAHQAWQBXAHgAVABkAFcAMQB0AFkAWABKADUAVABHAGwAMABaAFMA
>> "%~1" echo SQArAEwAVAB3AHYAWQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAdABhAFcANQBwAEkAagA0ADgAYwAzAEIAaABiAGoA
>> "%~1" echo NwBsAHQANgBYAGwAagBvAEkAdgA1AHEAQwBoADUAWQBlAEcAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB4AGkASQBHAGwAawBQAFMASgBtAFkAVwBOADAAYgAzAEoANQBVADMA
>> "%~1" echo VgB0AGIAVwBGAHkAZQBVAHgAcABkAEcAVQBpAFAAaQAwADgATAAyAEkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAYgBXAGwAdQBhAFUAZAB5AGEAVwBRAGkAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBwAGIAbQBrAGkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AFAAdQBTACsAbQArAGUAVQB0AFQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGkA
>> "%~1" echo QgBwAFoARAAwAGkAYwBHADkAMwBaAFgASgBUAGIAMwBWAHkAWQAyAFUAaQBQAGkA
>> "%~1" echo MAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAYgBXAGwAdQBhAFMASQArAFAASABOAHcAWQBXADQAKwBRAFUA
>> "%~1" echo UgBDAEkARgBkAHAATABVAFoAcABQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBJAEcA
>> "%~1" echo bABrAFAAUwBKAGgAWgBHAEoAWABhAFcAWgBwAEkAagA0AHQAUABDADkAaQBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo MQBwAGIAbQBrAGkAUABqAHgAegBjAEcARgB1AFAAdQBXAEIAcABlAFcANgB0AHoA
>> "%~1" echo dwB2AGMAMwBCAGgAYgBqADQAOABZAGkAQgBwAFoARAAwAGkAWQBtAEYAMABkAEcA
>> "%~1" echo VgB5AGUAVQBoAGwAWQBXAHgAMABhAEMASQArAEwAVAB3AHYAWQBqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABhAFcA
>> "%~1" echo NQBwAEkAagA0ADgAYwAzAEIAaABiAGoANwBvAHYANQBEAG8AbwBZAHoAbgBpAHIA
>> "%~1" echo YgBtAGcASQBFADgATAAzAE4AdwBZAFcANAArAFAARwBJAGcAYQBXAFEAOQBJAG4A
>> "%~1" echo ZABoAGEAMgBWAG0AZABXAHgAdQBaAFgATgB6AEkAagA0AHQAUABDADkAaQBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAawB1AEkA
>> "%~1" echo RABwAGwASwA3AGwAcgA3AHoAbABoADcAcgBvAHIAcgA3AGwAcABJAGYAbABoAGEA
>> "%~1" echo agBwAGcANgBqAGsAdgA2AEgAbQBnAGEAOAA4AEwAMgBnAHkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AFcAUABxAHUA
>> "%~1" echo aQB2AHUAeQBCAEIAUgBFAEkAOABMADMATgB3AFkAVwA0ACsAUABDADkAawBhAFgA
>> "%~1" echo WQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBtADkAawBlAFMA
>> "%~1" echo SQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWgBYAGgAdwBiADMA
>> "%~1" echo SgAwAFEAbQA5ADQASQBqADQAOABaAEcAbAAyAFAAagB4AGkAUAB1AGUAVQBuACsA
>> "%~1" echo YQBJAGsATwBlAG4AZwBlAGEAYwBpAGUAVwB1AGoATwBhAFYAdABPAGUASgBpAEMA
>> "%~1" echo QQByAEkATwBXAEkAaAB1AFMANgBxACsAVwB1AGkAZQBXAEYAcQBPAGUASgBpAEMA
>> "%~1" echo QgBJAFYARQAxAE0AUABDADkAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBoAHAAYgBuAFEAaQBJAEcAbABrAFAAUwBKAGwAZQBIAEIAdgBjAG4A
>> "%~1" echo UgBUAGQARwBGADAAZABYAE0AaQBQAHUAZQBDAHUAZQBXAEgAdQArAFcAUQBqAHUA
>> "%~1" echo bQBIAGoAZQBhAFcAcwBPAGUATwBzAE8AbQBIAGgAKwBpAHUAdgB1AFcAawBoACsA
>> "%~1" echo UwAvAG8AZQBhAEIAcgArAE8AQQBnAHUAZQBuAGcAZQBhAGMAaQBlAGUASgBpAE8A
>> "%~1" echo UwAvAG4AZQBlAFYAbQBlAFcAdQBqAE8AYQBWAHQATwBhAFYAcwBPAGEATgByAHUA
>> "%~1" echo KwA4AGoATwBXAEkAaAB1AFMANgBxACsAZQBKAGkATwBTADgAbQB1AGkARQBzAGUA
>> "%~1" echo YQBWAGoAKwBXADYAagArAFcASQBsACsAVwBQAHQAKwBPAEEAZwBVAGwAUQA0ADQA
>> "%~1" echo QwBCAFQAVQBGAEQANAA0AEMAQgBaAG0AbAB1AFoAMgBWAHkAYwBIAEoAcABiAG4A
>> "%~1" echo UQBnADUANgAyAEoANAA0AEMAQwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBaAFgAaAB3AGIAMwBKADAAVABHAGwAdQBhADMA
>> "%~1" echo TQBpAEkARwBsAGsAUABTAEoAbABlAEgAQgB2AGMAbgBSAE0AYQBXADUAcgBjAHkA
>> "%~1" echo SQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABHAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAbgBSAHUASQBIAEIAeQBhAFcA
>> "%~1" echo MQBoAGMAbgBrAGkASQBHAGwAawBQAFMASgBsAGUASABCAHYAYwBuAFIAQwBkAEcA
>> "%~1" echo NABpAFAAdQBXAHYAdgBPAFcASAB1AGkAQgBJAFYARQAxAE0AUABDADkAaQBkAFgA
>> "%~1" echo UgAwAGIAMgA0ACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIA
>> "%~1" echo RgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAEcA
>> "%~1" echo VgBoAFoAQwBJACsAUABHAGcAeQBQAHUAVwBQAGcAdQBhAFYAcwBPAFMALwByAHUA
>> "%~1" echo YQBVAHUAZQBXAEkAbAArAGkAaABxAEQAdwB2AGEARABJACsAUABIAE4AdwBZAFcA
>> "%~1" echo NABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoAeQBJAGcAYQBXAFEAOQBJAG4A
>> "%~1" echo QgBoAGMAbQBGAHQAVQAzAFYAdABiAFcARgB5AGUAUwBJACsANQA2ADIASgA1AGIA
>> "%~1" echo NgBGADUAWQBpADMANQBwAGEAdwBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgA
>> "%~1" echo awBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABjAG0A
>> "%~1" echo RgB0AFQARwBsAHoAZABDAEkAZwBhAFcAUQA5AEkAbgBCAGgAYwBtAEYAdABUAEcA
>> "%~1" echo bAB6AGQAQwBJACsAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBjAG0A
>> "%~1" echo OQAzAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAagBZAFgA
>> "%~1" echo SgBrAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAbwBaAFcA
>> "%~1" echo RgBrAEkAagA0ADgAYQBEAEkAKwA1AFkAVwB6ADYAWgBTAHUANQBZACsAQwA1AHAA
>> "%~1" echo VwB3AFAAQwA5AG8ATQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0ADgAZABHAEYAaQBiAEcA
>> "%~1" echo VQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFkAbQB4AGwASQBqADQAOABkAEgA
>> "%~1" echo SQArAFAASABSAGsAUABuAE4AMABZAFgAbABmAGIAMgA1AGYAZAAyAGgAcABiAEcA
>> "%~1" echo VgBmAGMARwB4ADEAWgAyAGQAbABaAEYAOQBwAGIAagB3AHYAZABHAFEAKwBQAEgA
>> "%~1" echo UgBrAEkARwBsAGsAUABTAEoAegBkAEcARgA1AFQAMgA0AGkAUABpADAAOABMADMA
>> "%~1" echo UgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADUAMwBhAFcA
>> "%~1" echo WgBwAFgAMwBOAHMAWgBXAFYAdwBYADMAQgB2AGIARwBsAGoAZQBUAHcAdgBkAEcA
>> "%~1" echo UQArAFAASABSAGsASQBHAGwAawBQAFMASgAzAGEAVwBaAHAAVQAyAHgAbABaAFgA
>> "%~1" echo QQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIAeQBQAGoA
>> "%~1" echo eAAwAFoARAA1AHoAWQAzAEoAbABaAFcANQBmAGIAMgBaAG0AWAAzAFIAcABiAFcA
>> "%~1" echo VgB2AGQAWABRADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBjADIA
>> "%~1" echo TgB5AFoAVwBWAHUAVAAyAFoAbQBJAGoANAB0AFAAQwA5ADAAWgBEADQAOABMADMA
>> "%~1" echo UgB5AFAAagB4ADAAYwBqADQAOABkAEcAUQArAGMAMgB4AGwAWgBYAEIAZgBkAEcA
>> "%~1" echo bAB0AFoAVwA5ADEAZABEAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMA
>> "%~1" echo SgB6AGIARwBWAGwAYwBGAFIAcABiAFcAVgB2AGQAWABRAGkAUABpADAAOABMADMA
>> "%~1" echo UgBrAFAAagB3AHYAZABIAEkAKwBQAEMAOQAwAFkAVwBKAHMAWgBUADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAGoAWQBYAEoAawBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAG8AWgBXAEYAawBJAGoANAA4AGEARABJACsANgBMAFcARQA1AHIA
>> "%~1" echo cQBRADUANABxADIANQBvAEMAQgBQAEMAOQBvAE0AagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoA
>> "%~1" echo NAA4AGQARwBGAGkAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABZAG0A
>> "%~1" echo eABsAEkAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAdQBXAHQAbQBPAFcAQwBxAEQA
>> "%~1" echo dwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAHoAZABHADkAeQBZAFcA
>> "%~1" echo ZABsAEkAagA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoA
>> "%~1" echo NAA4AGQARwBRACsANQBZAGEARgA1AGEAMgBZAFAAQwA5ADAAWgBEADQAOABkAEcA
>> "%~1" echo UQBnAGEAVwBRADkASQBtADEAbABiAFcAOQB5AGUAUwBJACsATABUAHcAdgBkAEcA
>> "%~1" echo UQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUAB1AFMAKwBtACsA
>> "%~1" echo ZQBVAHQAZQBhAGQAcABlAGEANgBrAEQAdwB2AGQARwBRACsAUABIAFIAawBJAEcA
>> "%~1" echo bABrAFAAUwBKAHcAYgAzAGQAbABjAGwATgB2AGQAWABKAGoAWgBUAEkAaQBQAGkA
>> "%~1" echo MAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQA
>> "%~1" echo NQBCAFIARQBJAGcANgBMAGUAdgA1AGIANgBFAFAAQwA5ADAAWgBEADQAOABkAEcA
>> "%~1" echo UQBnAGEAVwBRADkASQBtAEYAawBZAGwAQgBoAGQARwBoAFQAYQBHADkAeQBkAEMA
>> "%~1" echo SQArAEwAVAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0ADgATAAzAFIAaABZAG0A
>> "%~1" echo eABsAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB3AHYAYwAyAFYAagBkAEcAbAB2AGIAagA0AE4AQwBqAHgAegBaAFcA
>> "%~1" echo TgAwAGEAVwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkA
>> "%~1" echo QgBwAFoARAAwAGkAWQAyADkAdQBjADIAOQBzAFoAUwBJACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBjAG0AOQAzAE0AeQBJACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUA
>> "%~1" echo UwA4AGsAZQBlAGMAbwBPAFMANABqAHUAUwAvAG4AZQBhAEsAcABEAHcAdgBhAEQA
>> "%~1" echo SQArAFAASABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABaAHkA
>> "%~1" echo SQArADUAbwA2AG8ANgBJADIAUQBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgA
>> "%~1" echo awBnAFkAMgAxAGsAUgAzAEoAcABaAEMASQArAFAARwBKADEAZABIAFIAdgBiAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBZADIAMQBrAEkARwBKAHMAZABXAFUAaQBJAEcA
>> "%~1" echo UgBoAGQARwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAHIAWgBYAGwAZgBkADIA
>> "%~1" echo RgByAFoAWABWAHcASQBqADQAOABZAGoANwBrAHUAcQA3AGwAcwBZADgAZwBMAHkA
>> "%~1" echo RABsAGwASwBUAHAAaABwAEkAOABMADIASQArAFAASABOAHcAWQBXADQAKwA1AEwA
>> "%~1" echo dQBGADUAWgB5AG8ASQBFAEYARQBRAGkARABsAG4ASwBqAG4AdQByAC8AbQBsADcA
>> "%~1" echo YgBtAG4ASQBuAG0AbABZAGcAOABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgA
>> "%~1" echo UgAwAGIAMgA0ACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAFkAMgAxAGsASQBHAGQAeQBaAFcAVgB1AEkAaQBCAGsAWQBYAFIAaABMAFcA
>> "%~1" echo RgBqAGQARwBsAHYAYgBqADAAaQBjADIARgBtAFoAVgA5AHoAYgBHAFYAbABjAEMA
>> "%~1" echo SQArAFAARwBJACsANQBhADYASgA1AFkAVwBvADUANABhAEUANQBiAEcAUABQAEMA
>> "%~1" echo OQBpAFAAagB4AHoAYwBHAEYAdQBQAHUAYQBCAG8AdQBXAGsAagBlAFMALwBuAGUA
>> "%~1" echo VwB1AGkATwBXAEEAdgBPAFcANQB0AHUAVwBQAGsAZQBtAEEAZwBlAGUAZABvAGUA
>> "%~1" echo ZQBjAG8ATwBtAFUAcgBqAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBqAGIAVwBRAGcAWgAzAEoAbABaAFcANABpAEkARwBSAGgAZABHAEUAdABZAFcA
>> "%~1" echo TgAwAGEAVwA5AHUAUABTAEoAeQBaAFgATgAwAGIAMwBKAGwAWAAzAE4AcwBaAFcA
>> "%~1" echo VgB3AEkAagA0ADgAWQBqADcAbQBnAGEATABsAHAASQAzAGsAdgBKAEgAbgBuAEsA
>> "%~1" echo RABvAHQAbwBYAG0AbAA3AFkAOABMADIASQArAFAASABOAHcAWQBXADQAKwBOAFMA
>> "%~1" echo RABsAGkASQBiAHAAawBwAC8AbgBoAG8AVABsAHMAWQAvAHYAdgBJAHoAbAB1AGIA
>> "%~1" echo YgBvAHAANgBQAHAAbQBhAFEAZwBjAEgASgB2AGUARgA5AGoAYgBHADkAegBaAFQA
>> "%~1" echo dwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBqADQAOABZAG4A
>> "%~1" echo VgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYgBXAFEAaQBJAEcA
>> "%~1" echo UgBoAGQARwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAGoAYgAyADUAegBaAFgA
>> "%~1" echo SgAyAFkAWABSAHAAZABtAFUAaQBQAGoAeABpAFAAdQBTAC8AbgBlAFcAdQBpAE8A
>> "%~1" echo bQA3AG0ATwBpAHUAcABPAFcAQQB2AEQAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoA
>> "%~1" echo NwBtAGcAYQBMAGwAcABJADMAbABqADQATABtAGwAYgBEAGwAdQBiAGIAbABqADUA
>> "%~1" echo SABwAGcASQBFAGcAYwBIAEoAdgBlAEYAOQB2AGMARwBWAHUAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo aABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBvAHMASQBQAG8AcgA1AFgAbAB0ADYA
>> "%~1" echo WABrAHYAWgB6AG0AcQBLAEgAbAB2AEkAOAA4AEwAMgBnAHkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AG0AYwBnAE8A
>> "%~1" echo ZQBoAHIAdQBpAHUAcABEAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAEcA
>> "%~1" echo TgB0AFoARQBkAHkAYQBXAFEAaQBQAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBpAGIASABWAGwASQBHAFIAaABiAG0A
>> "%~1" echo ZABsAGMAawBGAGoAZABHAGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEAaABZADMA
>> "%~1" echo UgBwAGIAMgA0ADkASQBtAFIAbABZAG4AVgBuAFgAMgAxAHYAWgBHAFUAaQBQAGoA
>> "%~1" echo eABpAFAAdQBXAFEAcgArAGUAVQBxAE8AaQB3AGcAKwBpAHYAbABlAGEAbwBvAGUA
>> "%~1" echo VwA4AGoAegB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AGsAdgA1ADMAbQBqAEkA
>> "%~1" echo SABsAGwASwBUAHAAaABwAEwAagBnAEkARQB5AE4AQwBEAGwAcwBJAC8AbQBsADcA
>> "%~1" echo YgBqAGcASQBGAHcAYwBtADkANABYADIATgBzAGIAMwBOAGwAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB4AGkAZABYAFIAMABiADIA
>> "%~1" echo NABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoAQwBCAGkAYgBIAFYAbABJAEcA
>> "%~1" echo UgBoAGIAbQBkAGwAYwBrAEYAagBkAEcAbAB2AGIAaQBJAGcAWgBHAEYAMABZAFMA
>> "%~1" echo MQBoAFkAMwBSAHAAYgAyADQAOQBJAG0AdABsAFoAWABCAGYAWQBYAGQAaABhADIA
>> "%~1" echo VQBpAFAAagB4AGkAUAB1AFcANgBsAE8AZQBVAHEATwBTAC8AbgBlAGEAMAB1AHoA
>> "%~1" echo dwB2AFkAagA0ADgAYwAzAEIAaABiAGoANwBsAGsASQB6AG0AbAA3AGIAbQBsAEwA
>> "%~1" echo awBnAFYAMgBrAHQAUgBtAG4AagBnAEkARgB6AGIARwBWAGwAYwBGADkAMABhAFcA
>> "%~1" echo MQBsAGIAMwBWADAAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcA
>> "%~1" echo OQB1AFAAagB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgB0AFoAQwBCAGgAYgBXAEoAbABjAGkAQgBrAFkAVwA1AG4AWgBYAEoAQgBZADMA
>> "%~1" echo UgBwAGIAMgA0AGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBXADkAdQBQAFMA
>> "%~1" echo SgAzAGEAWABKAGwAYgBHAFYAegBjAHkASQArAFAARwBJACsANQBiAHkAQQA1AFoA
>> "%~1" echo QwB2ADUAcABlAGcANQA3AHEALwBJAEUARgBFAFEAagB3AHYAWQBqADQAOABjADMA
>> "%~1" echo QgBoAGIAagA3AHAAbgBJAEQAbwBwAG8ARQBnAFYAVgBOAEMASQBPAFcAMwBzAHUA
>> "%~1" echo YQBPAGkATwBhAGQAZwB6AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBqAGIAVwBRAGcAYwBtAFYAawBJAEcAUgBoAGIAbQBkAGwAYwBrAEYAagBkAEcA
>> "%~1" echo bAB2AGIAaQBJAGcAWgBHAEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4A
>> "%~1" echo ZABwAGMAbQBWAHMAWgBYAE4AegBYADIAOQBtAFoAaQBJACsAUABHAEkAKwA1AFkA
>> "%~1" echo VwB6ADYAWgBlAHQANQBwAGUAZwA1ADcAcQAvAEkARQBGAEUAUQBqAHcAdgBZAGoA
>> "%~1" echo NAA4AGMAMwBCAGgAYgBqADcAbABpAEkAZgBsAG0ANQA0AGcAVgBWAE4AQwBJAE8A
>> "%~1" echo YQBvAG8AZQBXADgAagB6AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBqAFkAWABKAGsASQBqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQAOABhAEQA
>> "%~1" echo SQArADYATAA2AFQANQBZAFcAbAA1AEwAaQBPADUAYgBtAC8ANQBwAEsAdABQAEMA
>> "%~1" echo OQBvAE0AagA0ADgAYwAzAEIAaABiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBkAEcA
>> "%~1" echo RgBuAEkAagA3AGwAawBiADMAawB1ADYAUQA4AEwAMwBOAHcAWQBXADQAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG0A
>> "%~1" echo OQBrAGUAUwBCAGoAYgBXAFIASABjAG0AbABrAEkAagA0ADgAWQBuAFYAMABkAEcA
>> "%~1" echo OQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGkASQBHAFIAaABkAEcA
>> "%~1" echo RQB0AFkAVwBOADAAYQBXADkAdQBQAFMASgByAFoAWABsAGYAYwAyAHgAbABaAFgA
>> "%~1" echo QQBpAFAAagB4AGkAUABrAHQARgBXAFUATgBQAFIARQBWAGYAVQAwAHgARgBSAFYA
>> "%~1" echo QQA4AEwAMgBJACsAUABIAE4AdwBZAFcANAArADUANwBPADcANQA3AHUAZgA1ADUA
>> "%~1" echo MgBoADUANQB5AGcANgBaAFMAdQBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBZAG4A
>> "%~1" echo VgAwAGQARwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBOAHQAWgBDAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIA
>> "%~1" echo NAA5AEkAbgBCAHkAYgAzAGgAZgBiADMAQgBsAGIAaQBJACsAUABHAEkAKwA1AGIA
>> "%~1" echo bQAvADUAcABLAHQASQBIAEIAeQBiADMAaABmAGIAMwBCAGwAYgBqAHcAdgBZAGoA
>> "%~1" echo NAA4AGMAMwBCAGgAYgBqADcAbwBwADYAUABwAG0AYQBUAGsAdgBhAG4AbQBpAEwA
>> "%~1" echo VABtAHEASwBIAG0AaQA1AC8AdgB2AEkAegBsAGgAWQBIAG8AcgByAGoAbgBoAG8A
>> "%~1" echo VABsAHMAWQA4ADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIA
>> "%~1" echo NAArAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIA
>> "%~1" echo MQBrAEkARwBGAHQAWQBtAFYAeQBJAEcAUgBoAGIAbQBkAGwAYwBrAEYAagBkAEcA
>> "%~1" echo bAB2AGIAaQBJAGcAWgBHAEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4A
>> "%~1" echo QgB5AGIAMwBoAGYAWQAyAHgAdgBjADIAVQBpAFAAagB4AGkAUAB1AFcANQB2ACsA
>> "%~1" echo YQBTAHIAUwBCAHcAYwBtADkANABYADIATgBzAGIAMwBOAGwAUABDADkAaQBQAGoA
>> "%~1" echo eAB6AGMARwBGAHUAUAB1AGEAbwBvAGUAYQBMAG4AKwBTADkAcQBlAGEASQB0AE8A
>> "%~1" echo bQBkAG8ATwBpAC8AawBUAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBqAGIAVwBRAGcAWQBXADEAaQBaAFgASQBpAEkARwBsAGsAUABTAEoAbgBiADAA
>> "%~1" echo TgAxAGMAMwBSAHYAYgBVAEoAeQBiADIARgBrAFkAMgBGAHoAZABDAEkAKwBQAEcA
>> "%~1" echo SQArADYASQBlAHEANQBhADYAYQA1AEwAbQBKADUAYgBtAC8ANQBwAEsAdABQAEMA
>> "%~1" echo OQBpAFAAagB4AHoAYwBHAEYAdQBQAHUAVwBPAHUAKwBtAHIAbQBPAGUANgBwAHkA
>> "%~1" echo QgB6AFoAWABSADAAYQBXADUAbgBjAHkARABwAG8AYgBYAHAAbgBhAEwAbABqADUA
>> "%~1" echo SABwAGcASQBFADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIA
>> "%~1" echo NAArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUA
>> "%~1" echo VwB4AGoAKwBXADUAbABlAGkAMgBoAGUAYQBYAHQAagB3AHYAYQBEAEkAKwBQAEgA
>> "%~1" echo TgB3AFkAVwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5AEkAKwA2AGEA
>> "%~1" echo SwBFADYASwA2ACsAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo eABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAZwBZADIA
>> "%~1" echo MQBrAFIAMwBKAHAAWgBDAEkAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAWQAyADEAawBJAEcAZAB5AFoAVwBWAHUASQBpAEIAawBZAFgA
>> "%~1" echo UgBoAEwAVwBGAGoAZABHAGwAdgBiAGoAMABpAGMAMgBOAHkAWgBXAFYAdQBYAHoA
>> "%~1" echo VgB0AEkAagA0ADgAWQBqADQAMQBJAE8AVwBJAGgAdQBtAFMAbgArAGUARwBoAE8A
>> "%~1" echo VwB4AGoAegB3AHYAWQBqADQAOABjADMAQgBoAGIAagA1AHoAWQAzAEoAbABaAFcA
>> "%~1" echo NQBmAGIAMgBaAG0AWAAzAFIAcABiAFcAVgB2AGQAWABRADkATQB6AEEAdwBNAEQA
>> "%~1" echo QQB3AFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoA
>> "%~1" echo eABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMA
>> "%~1" echo QgBpAGIASABWAGwASQBHAFIAaABiAG0AZABsAGMAawBGAGoAZABHAGwAdgBiAGkA
>> "%~1" echo SQBnAFoARwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBuAE4AagBjAG0A
>> "%~1" echo VgBsAGIAbAA4AHkATgBHAGcAaQBQAGoAeABpAFAAagBJADAASQBPAFcAdwBqACsA
>> "%~1" echo YQBYAHQAdQBTADYAcgB1AFcAeABqAHoAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoA
>> "%~1" echo NQB6AFkAMwBKAGwAWgBXADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgA
>> "%~1" echo UQA5AE8ARABZADAATQBEAEEAdwBNAEQAQQA4AEwAMwBOAHcAWQBXADQAKwBQAEMA
>> "%~1" echo OQBpAGQAWABSADAAYgAyADQAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAWQAyADEAawBJAGkAQgBrAFkAWABSAGgATABXAEYAagBkAEcA
>> "%~1" echo bAB2AGIAagAwAGkAYwAzAFIAaABlAFYAOQB2AFoAbQBZAGkAUABqAHgAaQBQAHUA
>> "%~1" echo VwBGAHMAKwBtAFgAcgBlAFMALwBuAGUAYQBNAGcAZQBXAFUAcABPAG0ARwBrAGoA
>> "%~1" echo dwB2AFkAagA0ADgAYwAzAEIAaABiAGoANQB6AGQARwBGADUAWAAyADkAdQBQAFQA
>> "%~1" echo QQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcA
>> "%~1" echo SgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyADEAawBJAEcA
>> "%~1" echo SgBzAGQAVwBVAGcAWgBHAEYAdQBaADIAVgB5AFEAVwBOADAAYQBXADkAdQBJAGkA
>> "%~1" echo QgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwAzAFIAaABlAFYA
>> "%~1" echo OQAxAGMAMgBKAGYAWQBXAE0AaQBQAGoAeABpAFAAbABWAFQAUQBpADkAQgBRAHkA
>> "%~1" echo RABrAHYANQAzAG0AagBJAEgAbABsAEsAVABwAGgAcABJADgATAAyAEkAKwBQAEgA
>> "%~1" echo TgB3AFkAVwA0ACsAYwAzAFIAaABlAFYAOQB2AGIAagAwAHoAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo aABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBuAGkAcgBiAG0AZwBJAEgAawB1AEkA
>> "%~1" echo NwBtAG4ASQAzAGwAaQBxAEUAOABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAMABZAFcAYwBpAFAAdQBlADcAdABPAGEASwBwAEQA
>> "%~1" echo dwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkARwBOAHQAWgBFAGQAeQBhAFcA
>> "%~1" echo UQBpAFAAagB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgB0AFoAQwBJAGcAYQBXAFEAOQBJAG0AMQBoAGIAbgBWAGgAYgBGAEoAbABaAG4A
>> "%~1" echo SgBsAGMAMgBnAGkAUABqAHgAaQBQAHUAVwBJAHQAKwBhAFcAcwBPAGUASwB0AHUA
>> "%~1" echo YQBBAGcAVAB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AHAAaAA0ADMAbQBsAHIA
>> "%~1" echo RABvAHIANwB2AGwAagA1AGIAbwByAHIANwBsAHAASQBmAG0AbABiAEQAbABnAEwA
>> "%~1" echo dwA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcA
>> "%~1" echo SgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyADEAawBJAGkA
>> "%~1" echo QgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwBtAFYAegBkAEcA
>> "%~1" echo RgB5AGQARgA5AGgAWgBHAEkAaQBQAGoAeABpAFAAdQBtAEgAagBlAFcAUQByAHkA
>> "%~1" echo QgBCAFIARQBJADgATAAyAEkAKwBQAEgATgB3AFkAVwA0ACsANQBMAHUARgA2AFkA
>> "%~1" echo ZQBOADUAWgBDAHYANQA1AFMAMQA2AEkAUwBSADUANgB1AHYANQBwAHkATgA1AFkA
>> "%~1" echo cQBoAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoA
>> "%~1" echo eABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMA
>> "%~1" echo QgBrAFkAVwA1AG4AWgBYAEoAQgBZADMAUgBwAGIAMgA0AGkASQBHAFIAaABkAEcA
>> "%~1" echo RQB0AFkAVwBOADAAYQBXADkAdQBQAFMASgB5AFoAWABOADAAYgAzAEoAbABYADIA
>> "%~1" echo SgBoAFkAMgB0ADEAYwBDAEkAKwBQAEcASQArADUATAB1AE8ANQBhAFMASAA1AEwA
>> "%~1" echo dQA5ADUAbwBHAGkANQBhAFMATgBQAEMAOQBpAFAAagB4AHoAYwBHAEYAdQBQAHUA
>> "%~1" echo YQBCAG8AdQBXAGsAagBlAG0AbQBsAHUAYQBzAG8AZQBXAEcAbQBlAFcARgBwAGUA
>> "%~1" echo VwBKAGoAZQBpAHUAdgB1AGUAOQByAGoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIA
>> "%~1" echo SgAxAGQASABSAHYAYgBqADQAOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAGoAYgBXAFEAaQBJAEcAbABrAFAAUwBKAG4AYgAwAHgAdgBaADMA
>> "%~1" echo TQBpAFAAagB4AGkAUAB1AGEAVABqAGUAUwA5AG4ATwBhAFgAcABlAFcALwBsAHoA
>> "%~1" echo dwB2AFkAagA0ADgAYwAzAEIAaABiAGoANwBtAG4ANgBYAG4AbgBJAHYAbQBsAG8A
>> "%~1" echo ZgBrAHUANwBiAG0AbAA2AFgAbAB2ADUAYwA4AEwAMwBOAHcAWQBXADQAKwBQAEMA
>> "%~1" echo OQBpAGQAWABSADAAYgAyADQAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgA
>> "%~1" echo WQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMA
>> "%~1" echo SQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMA
>> "%~1" echo SQArAFAARwBnAHkAUAB1AFcAOQBrACsAVwBKAGoAZQBhAFIAbQBPAGkAbQBnAFQA
>> "%~1" echo dwB2AGEARABJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4A
>> "%~1" echo UgBoAFoAeQBJAGcAYQBXAFEAOQBJAG0ATgB2AGIAbgBOAHYAYgBHAFYAVABkAEcA
>> "%~1" echo RgAwAFoAUwBJACsATABUAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoA
>> "%~1" echo NAA4AGQARwBGAGkAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABZAG0A
>> "%~1" echo eABsAEkAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAdQBpAC8AbgB1AGEATwBwAFQA
>> "%~1" echo dwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAGoAYgAyADUAegBiADIA
>> "%~1" echo eABsAFEAMgA5AHUAYgBpAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoA
>> "%~1" echo NAA4AGQASABJACsAUABIAFIAawBQAHUAZQBVAHQAZQBtAEgAagB6AHcAdgBkAEcA
>> "%~1" echo UQArAFAASABSAGsASQBHAGwAawBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABRAG0A
>> "%~1" echo RgAwAGQARwBWAHkAZQBTAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoA
>> "%~1" echo NAA4AGQASABJACsAUABIAFIAawBQAHUAUwA4AGsAZQBlAGMAbwBEAHcAdgBkAEcA
>> "%~1" echo UQArAFAASABSAGsASQBHAGwAawBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABWADIA
>> "%~1" echo RgByAFoAUwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgA
>> "%~1" echo SQArAFAASABSAGsAUABsAGQAcABMAFUAWgBwAFAAQwA5ADAAWgBEADQAOABkAEcA
>> "%~1" echo UQBnAGEAVwBRADkASQBtAE4AdgBiAG4ATgB2AGIARwBWAFgAYQBXAFoAcABJAGoA
>> "%~1" echo NAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB3AHYAZABHAEYAaQBiAEcA
>> "%~1" echo VQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgA
>> "%~1" echo WQArAFAAQwA5AHoAWgBXAE4AMABhAFcAOQB1AFAAZwAwAEsAUABIAE4AbABZADMA
>> "%~1" echo UgBwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBCAGgAWgAyAFUAaQBJAEcA
>> "%~1" echo bABrAFAAUwBKAGsAWgBYAFoAcABZADIAVQBpAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAE4AaABjAG0AUQBpAFAAagB4AGsAYQBYAFkAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkASQBtAGgAbABZAFcAUQBpAFAAagB4AG8ATQBqADcAbwByAHIA
>> "%~1" echo NwBsAHAASQBmAG0AbwBhAFAAbQBvAFkAZwA4AEwAMgBnAHkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AFcARgByAE8A
>> "%~1" echo VwA4AGcAQwBCAEIAUgBFAEkAZwA1AFkAKwBxADYASwArADcAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBsAHUAWgBtADkASABjAG0AbABrAEkAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAcABiAG0AWgB2AFYARwBsAHMAWgBTAEkAKwBQAEgA
>> "%~1" echo TgB3AFkAVwA0ACsANQBZADYAQwA1AFoAVwBHAEkAQwA4AGcANQBaAE8AQgA1ADQA
>> "%~1" echo bQBNAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAFAAagB4AHoAYwBHAEYAdQBJAEcA
>> "%~1" echo bABrAFAAUwBKAHQAWQBXADUAMQBaAG0ARgBqAGQASABWAHkAWgBYAEkAaQBQAGkA
>> "%~1" echo MAA4AEwAMwBOAHcAWQBXADQAKwBJAEMAOABnAFAASABOAHcAWQBXADQAZwBhAFcA
>> "%~1" echo UQA5AEkAbQBKAHkAWQBXADUAawBJAGoANAB0AFAAQwA5AHoAYwBHAEYAdQBQAGoA
>> "%~1" echo dwB2AFkAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcA
>> "%~1" echo NAArADUAWgA2AEwANQBZACsAMwBQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBJAEcA
>> "%~1" echo bABrAFAAUwBKAHQAYgAyAFIAbABiAEMASQArAEwAVAB3AHYAWQBqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAcABiAG0A
>> "%~1" echo WgB2AFYARwBsAHMAWgBTAEkAKwBQAEgATgB3AFkAVwA0ACsANQBMAHEAbgA1AFoA
>> "%~1" echo TwBCAEkAQwA4AGcANgBLADYAKwA1AGEAUwBIAEkAQwA4AGcANQBwADIALwA1ADcA
>> "%~1" echo cQBuAFAAQwA5AHoAYwBHAEYAdQBQAGoAeABpAFAAagB4AHoAYwBHAEYAdQBJAEcA
>> "%~1" echo bABrAFAAUwBKAHcAYwBtADkAawBkAFcATgAwAFQAbQBGAHQAWgBTAEkAKwBMAFQA
>> "%~1" echo dwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMAMwBCAGgAYgBpAEIAcABaAEQA
>> "%~1" echo MABpAGMASABKAHYAWgBIAFYAagBkAEUAUgBsAGQAbQBsAGoAWgBTAEkAKwBMAFQA
>> "%~1" echo dwB2AGMAMwBCAGgAYgBqADQAZwBMAHkAQQA4AGMAMwBCAGgAYgBpAEIAcABaAEQA
>> "%~1" echo MABpAFkAbQA5AGgAYwBtAFEAaQBQAGkAMAA4AEwAMwBOAHcAWQBXADQAKwBQAEMA
>> "%~1" echo OQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBsAHUAWgBtADkAVQBhAFcAeABsAEkAagA0ADgAYwAzAEIAaABiAGoA
>> "%~1" echo NQBUAGIAMABNADgATAAzAE4AdwBZAFcANAArAFAARwBJAGcAYQBXAFEAOQBJAG4A
>> "%~1" echo TgB2AFkAeQBJACsATABUAHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBwAGIAbQBaAHYAVgBHAGwAcwBaAFMA
>> "%~1" echo SQArAFAASABOAHcAWQBXADQAKwBRAG4AVgBwAGIARwBRADgATAAzAE4AdwBZAFcA
>> "%~1" echo NAArAFAARwBJAGcAYQBXAFEAOQBJAG0ASgAxAGEAVwB4AGsAUwBXAFEAaQBQAGkA
>> "%~1" echo MAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAYQBXADUAbQBiADEAUgBwAGIARwBVAGkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AFAAawBKAHkAWQBXADUAagBhAEQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGkA
>> "%~1" echo QgBwAFoARAAwAGkAWQBuAFYAcABiAEcAUgBDAGMAbQBGAHUAWQAyAGcAaQBQAGkA
>> "%~1" echo MAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAYQBXADUAbQBiADEAUgBwAGIARwBVAGkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AFAAawBsAHUAWQAzAEoAbABiAFcAVgB1AGQARwBGAHMAUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB4AGkASQBHAGwAawBQAFMASgBpAGQAVwBsAHMAWgBFAGwAdQBZADMA
>> "%~1" echo SgBsAGIAVwBWAHUAZABHAEYAcwBJAGoANAB0AFAAQwA5AGkAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAGwAdQBaAG0A
>> "%~1" echo OQBVAGEAVwB4AGwASQBqADQAOABjADMAQgBoAGIAagA1AEIAUQBrAGsAOABMADMA
>> "%~1" echo TgB3AFkAVwA0ACsAUABHAEkAZwBhAFcAUQA5AEkAbQBGAGkAYQBTAEkAKwBMAFQA
>> "%~1" echo dwB2AFkAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcA
>> "%~1" echo NAArAFYAbQBWAHUAWgBHADkAeQBJAEYAQgBoAGQARwBOAG8AUABDADkAegBjAEcA
>> "%~1" echo RgB1AFAAagB4AGkASQBHAGwAawBQAFMASgAyAFoAVwA1AGsAYgAzAEoAUQBZAFgA
>> "%~1" echo UgBqAGEAQwBJACsATABUAHcAdgBZAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB5AGIAMwBjAGkAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMAbQBRAGkAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkAVwBRAGkAUABqAHgAbwBNAGoA
>> "%~1" echo NwBvAHIAcgA3AGwAcABJAGYAawB1AEkANwBvAHYANQA3AG0AagBxAFUAOABMADIA
>> "%~1" echo ZwB5AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMA
>> "%~1" echo TQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeAAwAFkAVwBKAHMAWgBTAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAZABHAEYAaQBiAEcAVQBpAFAAagB4ADAAYwBqADQAOABkAEcA
>> "%~1" echo UQArAFEAVQBSAEMASQBPAGkAMwByACsAVwArAGgARAB3AHYAZABHAFEAKwBQAEgA
>> "%~1" echo UgBrAEkARwBsAGsAUABTAEoAaABaAEcASgBRAFkAWABSAG8ASQBqADQAdABQAEMA
>> "%~1" echo OQAwAFoARAA0ADgATAAzAFIAeQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwA2AEsA
>> "%~1" echo NgArADUAYQBTAEgANgBLAEcATQBQAEMAOQAwAFoARAA0ADgAZABHAFEAZwBhAFcA
>> "%~1" echo UQA5AEkAbQBSAGwAZABtAGwAagBaAFUAeABwAGIAbQBVAGkAUABpADAAOABMADMA
>> "%~1" echo UgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADUAWABhAFMA
>> "%~1" echo MQBHAGEAUwBCAEoAVQBEAHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMA
>> "%~1" echo SgAzAGEAVwBaAHAAUwBYAEEAaQBQAGkAMAA4AEwAMwBSAGsAUABqAHcAdgBkAEgA
>> "%~1" echo SQArAFAASABSAHkAUABqAHgAMABaAEQANQBCAGIAbQBSAHkAYgAyAGwAawBQAEMA
>> "%~1" echo OQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQBGAHUAWgBIAEoAdgBhAFcA
>> "%~1" echo UQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIAeQBQAGoA
>> "%~1" echo eAAwAFoARAA1AFQAUgBFAHMAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQA
>> "%~1" echo MABpAGMAMgBSAHIASQBqADQAdABQAEMAOQAwAFoARAA0ADgATAAzAFIAeQBQAGoA
>> "%~1" echo eAAwAGMAagA0ADgAZABHAFEAKwA1AGEANgBKADUAWQBXAG8ANgBLAEcAbAA1AEwA
>> "%~1" echo aQBCAFAAQwA5ADAAWgBEADQAOABkAEcAUQBnAGEAVwBRADkASQBuAE4AbABZADMA
>> "%~1" echo VgB5AGEAWABSADUAVQBHAEYAMABZADIAZwBpAFAAaQAwADgATAAzAFIAawBQAGoA
>> "%~1" echo dwB2AGQASABJACsAUABDADkAMABZAFcASgBzAFoAVAA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBqAFkAWABKAGsASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBvAFoAVwBGAGsASQBqADQAOABhAEQASQArADUANgBHAHMANQBMAHUAMgA1AHAA
>> "%~1" echo RwBZADYASwBhAEIAUABDADkAbwBNAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcA
>> "%~1" echo bAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgBpAGIAMgBSADUASQBqADQAOABkAEcA
>> "%~1" echo RgBpAGIARwBVAGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWQBtAHgAbABJAGoA
>> "%~1" echo NAA4AGQASABJACsAUABIAFIAawBQAHUAYQBZAHYAdQBlAGsAdQBqAHcAdgBkAEcA
>> "%~1" echo UQArAFAASABSAGsASQBHAGwAawBQAFMASgBrAGEAWABOAHcAYgBHAEYANQBVADMA
>> "%~1" echo VgB0AGIAVwBGAHkAZQBTAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoA
>> "%~1" echo NAA4AGQASABJACsAUABIAFIAawBQAHUAZQBEAHIAZQBlAEsAdAB1AGEAQQBnAFQA
>> "%~1" echo dwB2AGQARwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKADAAYQBHAFYAeQBiAFcA
>> "%~1" echo RgBzAFUAMwBWAHQAYgBXAEYAeQBlAFMASQArAEwAVAB3AHYAZABHAFEAKwBQAEMA
>> "%~1" echo OQAwAGMAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAAdQBXADMAcABlAFcATwBnAGkA
>> "%~1" echo LwBtAG8ASwBIAGwAaAA0AFkAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQA
>> "%~1" echo MABpAFoAbQBGAGoAZABHADkAeQBlAFYATgAxAGIAVwAxAGgAYwBuAGsAaQBQAGkA
>> "%~1" echo MAA4AEwAMwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQA
>> "%~1" echo NQBXAGEAWABKADAAZABXAEYAcwBJAEUAUgBsAGMAMgB0ADAAYgAzAEEAOABMADMA
>> "%~1" echo UgBrAFAAagB4ADAAWgBEADQAOABjADMAQgBoAGIAaQBCAHAAWgBEADAAaQBkAG0A
>> "%~1" echo UgBRAFkAVwBOAHIAWQBXAGQAbABJAGoANAB0AFAAQwA5AHoAYwBHAEYAdQBQAGkA
>> "%~1" echo QQA4AGMAMwBCAGgAYgBpAEIAcABaAEQAMABpAGQAbQBSAFcAWgBYAEoAegBhAFcA
>> "%~1" echo OQB1AEkAagA0AHQAUABDADkAegBjAEcARgB1AFAAagB3AHYAZABHAFEAKwBQAEMA
>> "%~1" echo OQAwAGMAagA0ADgATAAzAFIAaABZAG0AeABsAFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo dwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo TgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0A
>> "%~1" echo aABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBtAGkAWQB2AG0AbgA0AFQAbgB1AHIA
>> "%~1" echo LwBuAHQASwBJADgATAAyAGcAeQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgAMABZAFcA
>> "%~1" echo SgBzAFoAUwBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAGkAYgBHAFUAaQBQAGoA
>> "%~1" echo eAAwAGMAagA0ADgAZABHAFEAKwA1AGIAZQBtADUAbwBtAEwANQBwACsARQA1ADUA
>> "%~1" echo UwAxADYAWQBlAFAAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG0A
>> "%~1" echo TgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgASgBNAFoAVwBaADAAUQBtAEYAMABkAEcA
>> "%~1" echo VgB5AGUAUwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgA
>> "%~1" echo SQArAFAASABSAGsAUAB1AFcAUABzACsAYQBKAGkAKwBhAGYAaABPAGUAVQB0AGUA
>> "%~1" echo bQBIAGoAegB3AHYAZABHAFEAKwBQAEgAUgBrAEkARwBsAGsAUABTAEoAagBiADIA
>> "%~1" echo NQAwAGMAbQA5AHMAYgBHAFYAeQBVAG0AbABuAGEASABSAEMAWQBYAFIAMABaAFgA
>> "%~1" echo SgA1AEkAagA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoA
>> "%~1" echo NAA4AGQARwBRACsANQBiAGUAbQA1AG8AbQBMADUAcAArAEUANQA0AHEAMgA1AG8A
>> "%~1" echo QwBCAFAAQwA5ADAAWgBEADQAOABkAEcAUQBnAGEAVwBRADkASQBtAE4AdgBiAG4A
>> "%~1" echo UgB5AGIAMgB4AHMAWgBYAEoATQBaAFcAWgAwAFUAMwBSAGgAZABIAFYAegBJAGoA
>> "%~1" echo NAB0AFAAQwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB4ADAAYwBqADQAOABkAEcA
>> "%~1" echo UQArADUAWQArAHoANQBvAG0ATAA1AHAAKwBFADUANABxADIANQBvAEMAQgBQAEMA
>> "%~1" echo OQAwAFoARAA0ADgAZABHAFEAZwBhAFcAUQA5AEkAbQBOAHYAYgBuAFIAeQBiADIA
>> "%~1" echo eABzAFoAWABKAFMAYQBXAGQAbwBkAEYATgAwAFkAWABSADEAYwB5AEkAKwBMAFQA
>> "%~1" echo dwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AEwAMwBSAGgAWQBtAHgAbABQAGoA
>> "%~1" echo eABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQB4AHYAWgB5AEkAZwBhAFcA
>> "%~1" echo UQA5AEkAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoAWABKAEkAYQBXADUAMABJAGoA
>> "%~1" echo NAB0AFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgA
>> "%~1" echo WQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMA
>> "%~1" echo SQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMA
>> "%~1" echo SQArAFAARwBnAHkAUAB1AGUAVQB0AGUAYQA2AGsATwBlAEsAdAB1AGEAQQBnAFQA
>> "%~1" echo dwB2AGEARABJACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcA
>> "%~1" echo RgB6AGMAegAwAGkAWQBtADkAawBlAFMASQArAFAASABSAGgAWQBtAHgAbABJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAMABZAFcASgBzAFoAUwBJACsAUABIAFIAeQBQAGoA
>> "%~1" echo eAAwAFoARAA1AHQAVQAzAFIAaABlAFUAOQB1AFAAQwA5ADAAWgBEADQAOABkAEcA
>> "%~1" echo UQBnAGEAVwBRADkASQBtADEAVABkAEcARgA1AFQAMgA0AGkAUABpADAAOABMADMA
>> "%~1" echo UgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADUAdABVAEgA
>> "%~1" echo SgB2AGUARwBsAHQAYQBYAFIANQBVAEcAOQB6AGEAWABSAHAAZABtAFUAOABMADMA
>> "%~1" echo UgBrAFAAagB4ADAAWgBDAEIAcABaAEQAMABpAGIAVgBCAHkAYgAzAGgAcABiAFcA
>> "%~1" echo bAAwAGUAVgBCAHYAYwAyAGwAMABhAFgAWgBsAEkAagA0AHQAUABDADkAMABaAEQA
>> "%~1" echo NAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQARwBRACsAYgBWAE4AMABZAFgA
>> "%~1" echo bABQAGIAbABkAG8AYQBXAHgAbABVAEcAeAAxAFoAMgBkAGwAWgBFAGwAdQBVADIA
>> "%~1" echo VgAwAGQARwBsAHUAWgB6AHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMA
>> "%~1" echo SgB0AFUAMwBSAGgAZQBVADkAdQBVADIAVgAwAGQARwBsAHUAWgB5AEkAKwBMAFQA
>> "%~1" echo dwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQASABJACsAUABIAFIAawBQAGwA
>> "%~1" echo TgBzAFoAVwBWAHcASQBIAFIAcABiAFcAVgB2AGQAWABRADgATAAzAFIAawBQAGoA
>> "%~1" echo eAAwAFoAQwBCAHAAWgBEADAAaQBjAEcAOQAzAFoAWABKAFQAYgBHAFYAbABjAEUA
>> "%~1" echo eABwAGIAbQBVAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEMA
>> "%~1" echo OQAwAFkAVwBKAHMAWgBUADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBqAFkAWABKAGsASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMA
>> "%~1" echo SgBvAFoAVwBGAGsASQBqADQAOABhAEQASQArADUAYgBlAGwANQBZADYAQwBJAEMA
>> "%~1" echo OABnADUAcQBDAGgANQBZAGUARwA1AG8ANgBvADUAcABhAHQANgBMADYANQA1ADUA
>> "%~1" echo VwBNAFAAQwA5AG8ATQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAcwBiADIAYwBpAFAAdQBXAFAAcgArAFMANwBwAGUA
>> "%~1" echo YQBZAHYAdQBlAGsAdQBpAEIAUgBkAFcAVgB6AGQAQwBEAGwAaABhAHoAbAB2AEkA
>> "%~1" echo QQBnAFEAVQBSAEMASQBPAGEAYQB0AE8AbQBjAHMAdQBlAGEAaABDAEIARwBZAFcA
>> "%~1" echo TgAwAGIAMwBKADUASQBDADgAZwBUADIANQBzAGEAVwA1AGwASQBHAE4AaABiAEcA
>> "%~1" echo bABpAGMAbQBGADAAYQBXADkAdQBJAE8AZQA2AHYAKwBlADAAbwB1ACsAOABqAE8A
>> "%~1" echo UwArAGkAKwBXAG0AZwBpAEIARgBkAFgASgBsAGEAMgBIAGoAZwBJAEYAUQBWAGwA
>> "%~1" echo UQB4AEwAagBIAGoAZwBJAEYAegBkAEcARgAwAGEAVwA5AHUATAAyAHgAdgBZADIA
>> "%~1" echo RgAwAGEAVwA5AHUATAAzAFIAbABjADMAUQBnADUATAB1AGoANQA2AEMAQgA0ADQA
>> "%~1" echo QwBDADUATABpAE4ANgBJAE8AOQA1AG8AcQBLADUAWQBhAEYANgBZAE8AbwA1AEwA
>> "%~1" echo dQBqADUANgBDAEIANQBZACsAdgA2AFoAMgBnADUANwArADcANgBLACsAUgA1AG8A
>> "%~1" echo aQBRADUAWQBXADMANQBMADIAVAA1AFoAdQA5ADUAYQA2ADIANAA0AEMAQgA1AFoA
>> "%~1" echo KwBPADUAYgBpAEMANQBvAGkAVwA1AGIAZQBsADUAWQA2AEMANwA3AHkAYgBWADIA
>> "%~1" echo awB0AFIAbQBrAGcANQBaAHUAOQA1AGEANgAyADUANgBDAEIANQBMAG0AZgA1AEwA
>> "%~1" echo aQBOADUANgAyAEoANQBMAHEATwA1AFkAZQA2ADUATABxAG4ANQBaAHkAdwA0ADQA
>> "%~1" echo QwBDADUAYQA2AE0ANQBwAFcAMAA1AGEAMgBYADUAcQA2ADEANgBLACsAMwA1ADUA
>> "%~1" echo UwBvADQAbwBDAGMANQBMAGkAQQA2AFoAUwB1ADUAYQArADgANQBZAGUANgA2AEsA
>> "%~1" echo NgArADUAYQBTAEgANQBZAFcAbwA2AFkATwBvADUATAArAGgANQBvAEcAdgA0AG8A
>> "%~1" echo QwBkADQANABDAEMAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAegBaAFcATgAwAGEAVwA5AHUAUABnADAASwBQAEgA
>> "%~1" echo TgBsAFkAMwBSAHAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABaADIA
>> "%~1" echo VQBpAEkARwBsAGsAUABTAEoAegBaAFgAUgAwAGEAVwA1AG4AYwB5AEkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkAMgBGAHkAWgBDAEkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEARwBWAGgAWgBDAEkAKwBQAEcA
>> "%~1" echo ZwB5AFAAdQBpAEgAcQB1AFcAdQBtAHUAUwA1AGkAUwBCAHoAWgBYAFIAMABhAFcA
>> "%~1" echo NQBuAGMAeQBCAHcAZABYAFEAOABMADIAZwB5AFAAagB3AHYAWgBHAGwAMgBQAGoA
>> "%~1" echo eABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAZwBaAG0A
>> "%~1" echo OQB5AGIAUwBJACsAUABIAE4AbABiAEcAVgBqAGQAQwBCAHAAWgBEADAAaQBZADMA
>> "%~1" echo VgB6AGQARwA5AHQAVABuAE0AaQBQAGoAeAB2AGMASABSAHAAYgAyADQAKwBaADIA
>> "%~1" echo eAB2AFkAbQBGAHMAUABDADkAdgBjAEgAUgBwAGIAMgA0ACsAUABHADkAdwBkAEcA
>> "%~1" echo bAB2AGIAagA1AHoAZQBYAE4AMABaAFcAMAA4AEwAMgA5AHcAZABHAGwAdgBiAGoA
>> "%~1" echo NAA4AGIAMwBCADAAYQBXADkAdQBQAG4ATgBsAFkAMwBWAHkAWgBUAHcAdgBiADMA
>> "%~1" echo QgAwAGEAVwA5AHUAUABqAHcAdgBjADIAVgBzAFoAVwBOADAAUABqAHgAcABiAG4A
>> "%~1" echo QgAxAGQAQwBCAHAAWgBEADAAaQBZADMAVgB6AGQARwA5AHQAUwAyAFYANQBJAGkA
>> "%~1" echo QgB3AGIARwBGAGoAWgBXAGgAdgBiAEcAUgBsAGMAagAwAGkANgBaAFMAdQA1AFoA
>> "%~1" echo QwBOADcANwB5AE0ANQBMADYATAA1AGEAYQBDAEkASABOAGoAYwBtAFYAbABiAGwA
>> "%~1" echo OQB2AFoAbQBaAGYAZABHAGwAdABaAFcAOQAxAGQAQwBJACsAUABHAGwAdQBjAEgA
>> "%~1" echo VgAwAEkARwBsAGsAUABTAEoAagBkAFgATgAwAGIAMgAxAFcAWQBXAHgAMQBaAFMA
>> "%~1" echo SQBnAGMARwB4AGgAWQAyAFYAbwBiADIAeABrAFoAWABJADkASQB1AFcAQQB2AEMA
>> "%~1" echo SQArAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG4A
>> "%~1" echo UgB1AEkAaQBCAHAAWgBEADAAaQBZADMAVgB6AGQARwA5AHQAVQAyAFYAMABJAGoA
>> "%~1" echo NwBsAGgAcABuAGwAaABhAFUAOABMADIASgAxAGQASABSAHYAYgBqADQAOABMADIA
>> "%~1" echo UgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAGoAWQBYAEoAawBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAG8AWgBXAEYAawBJAGoANAA4AGEARABJACsANQBZACsAUgA2AFkA
>> "%~1" echo QwBCADYASQBlAHEANQBhADYAYQA1AEwAbQBKADUAYgBtAC8ANQBwAEsAdABQAEMA
>> "%~1" echo OQBvAE0AagA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgA
>> "%~1" echo TgB6AFAAUwBKAGkAYgAyAFIANQBJAEcAWgB2AGMAbQAwAGkASQBIAE4AMABlAFcA
>> "%~1" echo eABsAFAAUwBKAG4AYwBtAGwAawBMAFgAUgBsAGIAWABCAHMAWQBYAFIAbABMAFcA
>> "%~1" echo TgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AEkARABnAHkAYwBIAGcAaQBQAGoA
>> "%~1" echo eABwAGIAbgBCADEAZABDAEIAcABaAEQAMABpAFkAbgBKAHYAWQBXAFIAagBZAFgA
>> "%~1" echo TgAwAFQAbQBGAHQAWgBTAEkAZwBjAEcAeABoAFkAMgBWAG8AYgAyAHgAawBaAFgA
>> "%~1" echo SQA5AEkAdQBTACsAaQArAFcAbQBnAGkAQgBqAGIAMgAwAHUAYgAyAE4AMQBiAEgA
>> "%~1" echo VgB6AEwAbgBaAHkAYwBHADkAMwBaAFgASgB0AFkAVwA1AGgAWgAyAFYAeQBMAG4A
>> "%~1" echo QgB5AGIAMwBoAGYAYgAzAEIAbABiAGkASQArAFAARwBKADEAZABIAFIAdgBiAGkA
>> "%~1" echo QgBqAGIARwBGAHoAYwB6ADAAaQBZAG4AUgB1AEkAaQBCAHAAWgBEADAAaQBZADMA
>> "%~1" echo VgB6AGQARwA5AHQAUQBuAEoAdgBZAFcAUgBqAFkAWABOADAASQBqADcAbABqADUA
>> "%~1" echo SABwAGcASQBFADgATAAyAEoAMQBkAEgAUgB2AGIAagA0ADgATAAyAFIAcABkAGoA
>> "%~1" echo NAA4AEwAMgBSAHAAZABqADQAOABMADMATgBsAFkAMwBSAHAAYgAyADQAKwBQAEgA
>> "%~1" echo TgBsAFkAMwBSAHAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBuAEIAaABaADIA
>> "%~1" echo VQBpAEkARwBsAGsAUABTAEoAcwBiADIAZAB6AEkAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwAMgBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkAKwA1AHAA
>> "%~1" echo ZQBsADUAYgArAFgAUABDADkAbwBNAGoANAA4AFkAbgBWADAAZABHADkAdQBJAEcA
>> "%~1" echo TgBzAFkAWABOAHoAUABTAEoAaQBkAEcANABnAFoAMgBoAHYAYwAzAFEAaQBJAEcA
>> "%~1" echo bABrAFAAUwBKAHkAWgBXAFoAeQBaAFgATgBvAFQARwA5AG4AYwB5AEkAKwA1AFkA
>> "%~1" echo aQAzADUAcABhAHcANQBwAGUAbAA1AGIAKwBYAFAAQwA5AGkAZABYAFIAMABiADIA
>> "%~1" echo NAArAFAAQwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAFkAbQA5AGsAZQBTAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoA
>> "%~1" echo MABpAGIAVwBsAHUAYQBTAEkAZwBjADMAUgA1AGIARwBVADkASQBtADEAaABjAG0A
>> "%~1" echo ZABwAGIAaQAxAGkAYgAzAFIAMABiADIAMAA2AE0AVABKAHcAZQBDAEkAKwBQAEgA
>> "%~1" echo TgB3AFkAVwA0ACsANQBwAGUAbAA1AGIAKwBYADUAcABhAEgANQBMAHUAMgBQAEMA
>> "%~1" echo OQB6AGMARwBGAHUAUABqAHgAaQBJAEcAbABrAFAAUwBKAHMAYgAyAGQAUQBZAFgA
>> "%~1" echo UgBvAEkAagA0AHQAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgA
>> "%~1" echo WQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AeAB2AFoAeQBJAGcAYQBXAFEAOQBJAG0A
>> "%~1" echo eAB2AFoAMABKAHYAZQBDAEkAKwA1ADYAMgBKADUAYgA2AEYANQBwAE8ATgA1AEwA
>> "%~1" echo MgBjAEwAaQA0AHUAUABDADkAawBhAFgAWQArAFAAQwA5AGsAYQBYAFkAKwBQAEMA
>> "%~1" echo OQBrAGEAWABZACsAUABDADkAegBaAFcATgAwAGEAVwA5AHUAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB3AHYAYgBXAEYAcABiAGoANAA4AEwAMgBSAHAAZABqADQATgBDAGoA
>> "%~1" echo eAB6AFkAMwBKAHAAYwBIAFEAKwBEAFEAcABqAGIAMgA1AHoAZABDAEIAVQBUADAA
>> "%~1" echo dABGAFQAagAwAG4AVwAxAHQAVQBUADAAdABGAFQAbAAxAGQASgB6AHMATgBDAG0A
>> "%~1" echo TgB2AGIAbgBOADAASQBDAFEAOQBhAFcAUQA5AFAAbQBSAHYAWQAzAFYAdABaAFcA
>> "%~1" echo NQAwAEwAbQBkAGwAZABFAFYAcwBaAFcAMQBsAGIAbgBSAEMAZQBVAGwAawBLAEcA
>> "%~1" echo bABrAEsAVABzAE4AQwBtAE4AdgBiAG4ATgAwAEkASABCAGgAWgAyAFYAegBQAFgA
>> "%~1" echo dAB2AGQAbQBWAHkAZABtAGwAbABkAHoAcABiAEoAKwBhAEEAdQArAGkAbgBpAEMA
>> "%~1" echo YwBzAEoAKwBlAEsAdAB1AGEAQQBnAGUAYQBNAGgAKwBhAGcAaAArAFcAUwBqAE8A
>> "%~1" echo aQB1AHYAdQBXAGsAaAArAGEAbQBnAHUAaQBuAGkAQwBkAGQATABHAE4AdgBiAG4A
>> "%~1" echo TgB2AGIARwBVADYAVwB5AGYAbAB2ADYAdgBtAGoAYgBmAG0AagBxAGYAbABpAEwA
>> "%~1" echo YgBsAGoANwBBAG4ATABDAGYAbQBtADcAVABsAHAASgByAGwAdQBMAGoAbgBsAEsA
>> "%~1" echo ZwBnAFEAVQBSAEMASQBPAGEAVABqAGUAUwA5AG4ATwBXAEYAcABlAFcAUABvAHkA
>> "%~1" echo ZABkAEwARwBSAGwAZABtAGwAagBaAFQAcABiAEoAKwBpAHUAdgB1AFcAawBoACsA
>> "%~1" echo UwAvAG8AZQBhAEIAcgB5AGMAcwBKACsAZQB6AHUAKwBlADcAbgArAE8AQQBnAFYA
>> "%~1" echo WgBwAGMAbgBSADEAWQBXAHcAZwBSAEcAVgB6AGEAMwBSAHYAYwBPAE8AQQBnAGUA
>> "%~1" echo YQBKAGkAKwBhAGYAaABPAFcAUwBqAE8AZQBVAHQAZQBhADYAawBPAGUANgB2ACsA
>> "%~1" echo ZQAwAG8AaQBkAGQATABIAE4AbABkAEgAUgBwAGIAbQBkAHoATwBsAHMAbgA2AGEA
>> "%~1" echo dQBZADUANwBxAG4ASQBIAE4AbABkAEgAUgBwAGIAbQBkAHoASgB5AHcAbgA2AEwA
>> "%~1" echo QwBvADUAbwBXAE8ANQBZAGEAWgA1AFkAVwBsAEkARQBGAHUAWgBIAEoAdgBhAFcA
>> "%~1" echo UQBnAGMAMgBWADAAZABHAGwAdQBaADMATQBnADUAbwBpAFcANQBiAG0ALwA1AHAA
>> "%~1" echo SwB0AEoAMQAwAHMAYgBHADkAbgBjAHoAcABiAEoAKwBhAFgAcABlAFcALwBsAHkA
>> "%~1" echo YwBzAEoAKwBhAGMAZwBPAGkALwBrAGUAUwA0AGcATwBhAHMAbwBlAGEAVABqAGUA
>> "%~1" echo UwA5AG4ATwBlADcAawArAGEAZQBuAEMAZABkAGYAVABzAE4AQwBtAE4AdgBiAG4A
>> "%~1" echo TgAwAEkASABSAG8AWgBXADEAbABTADIAVgA1AFAAUwBkAHgAZABXAFYAegBkAEUA
>> "%~1" echo RgBrAFkAbABSAG8AWgBXADEAbABWAGoAWQBuAE8AdwAwAEsAWQAyADkAdQBjADMA
>> "%~1" echo UQBnAFkAMgA5AHUAWgBtAGwAeQBiAFYAUgBsAGUASABRADkAZQB3ADAASwBJAEMA
>> "%~1" echo QgBrAFoAVwBKADEAWgAxADkAdABiADIAUgBsAE8AaQBmAGsAdgBKAHIAbAB2AEkA
>> "%~1" echo RABsAGsASwAvAGsAdgA1ADMAbQBqAEkASABsAGwASwBUAHAAaABwAEwAagBnAEkA
>> "%~1" echo RgBYAGEAUwAxAEcAYQBTAEQAawB1AEkAMwBrAHYASgBIAG4AbgBLAEQAagBnAEkA
>> "%~1" echo RQB5AE4AQwBEAGwAcwBJAC8AbQBsADcAYgBsAHMAWQAvAGwAdQBaAFgAbABrAG8A
>> "%~1" echo dwBnAGMASABKAHYAZQBGADkAagBiAEcAOQB6AFoAZQArADgAagBPAFcAUABxAHUA
>> "%~1" echo VwA3AHUAdQBpAHUAcgB1AGUAZgByAGUAYQBYAHQAdQBtAFgAdABPAGkAdwBnACsA
>> "%~1" echo aQB2AGwAZQBPAEEAZwBpAGMAcwBEAFEAbwBnAEkARwB0AGwAWgBYAEIAZgBZAFgA
>> "%~1" echo ZABoAGEAMgBVADYASgArAFMAOABtAHUAVwBHAG0AZQBXAEYAcABlAFMALwBuAGUA
>> "%~1" echo YQBNAGcAZQBXAFUAcABPAG0ARwBrAHUATwBBAGcAVgBkAHAATABVAFoAcABJAE8A
>> "%~1" echo UwA0AGoAZQBTADgAawBlAGUAYwBvAE8ATwBBAGcAVABJADAASQBPAFcAdwBqACsA
>> "%~1" echo YQBYAHQAdQBXAHgAagArAFcANQBsAGUATwBBAGcAWABOAHMAWgBXAFYAdwBYADMA
>> "%~1" echo UgBwAGIAVwBWAHYAZABYAFEAOQBMAFQASAB2AHYASQB6AGwAdQBiAGIAbABqADUA
>> "%~1" echo SABwAGcASQBFAGcAYwBIAEoAdgBlAEYAOQBqAGIARwA5AHoAWgBlAE8AQQBnAGkA
>> "%~1" echo YwBzAEQAUQBvAGcASQBIAGQAcABjAG0AVgBzAFoAWABOAHoATwBpAGYAawB2AEoA
>> "%~1" echo cgBsAHYASQBEAGwAawBLADgAZwBOAFQAVQAxAE4AUwBEAG0AbAA2AEQAbgB1AHIA
>> "%~1" echo OABnAFEAVQBSAEMANwA3AHkATQA1AFoAQwBNADUATABpAEEANQBiAEcAQQA1AFoA
>> "%~1" echo KwBmADUANwAyAFIANQBZAGEARgA1AFkAKwB2ADYASQBPADkANgBLAEsAcgA2AEwA
>> "%~1" echo KwBlADUAbwA2AGwANAA0AEMAQwA1ADUAUwBvADUAYQA2AE0ANgBLACsAMwA1AFkA
>> "%~1" echo VwB6ADYAWgBlAHQANQBwAGUAZwA1ADcAcQAvAEkARQBGAEUAUQB1AE8AQQBnAGkA
>> "%~1" echo YwBzAEQAUQBvAGcASQBIAGQAcABjAG0AVgBzAFoAWABOAHoAWAAyADkAbQBaAGoA
>> "%~1" echo bwBuADUATAB5AGEANgBLADYAcABJAEcARgBrAFkAbQBRAGcANQBZAGkASAA1AFoA
>> "%~1" echo dQBlAEkARgBWAFQAUQB1ACsAOABtACsAVwBtAGcAdQBhAGUAbgBPAFcAOQBrACsA
>> "%~1" echo VwBKAGoAZQBtAGQAbwBDAEIAWABhAFMAMQBHAGEAUwBEAG8AdgA1ADcAbQBqAHEA
>> "%~1" echo WAB2AHYASQB6AG0AbABxADMAbAB2AEkARABsAHMAWgA3AGsAdQBvADcAbQByAGEA
>> "%~1" echo UABsAHUATABqAG4AagByAEQAbwBzAGEASABqAGcASQBJAG4ATABBADAASwBJAEMA
>> "%~1" echo QgB6AFkAMwBKAGwAWgBXADUAZgBNAGoAUgBvAE8AaQBmAGsAdgBKAHIAbQBpAG8A
>> "%~1" echo cgBsAHMAWQAvAGwAdQBaAFgAbwB0AG8AWABtAGwANwBiAG0AbABMAG4AawB1AEwA
>> "%~1" echo bwBnAE0AagBRAGcANQBiAEMAUAA1AHAAZQAyADcANwB5AE0ANQBZACsAdgA2AEkA
>> "%~1" echo TwA5ADUAYQArADgANgBJAGUAMAA1AGEAUwAwADUAcABpACsANgBaAFcALwA1AHAA
>> "%~1" echo ZQAyADYAWgBlADAANQBMAGkATgA1ADQAYQBFADUAYgBHAFAANAA0AEMAQwBKAHkA
>> "%~1" echo dwBOAEMAaQBBAGcAYwAzAFIAaABlAFYAOQAxAGMAMgBKAGYAWQBXAE0ANgBKACsA
>> "%~1" echo UwA4AG0AdQBpAHUAcQBTAEIAVgBVADAASQB2AFEAVQBNAGcANQBvACsAUwA1ADUA
>> "%~1" echo UwAxADUAcABlADIANQBMACsAZAA1AG8AeQBCADUAWgBTAGsANgBZAGEAUwA0ADQA
>> "%~1" echo QwBDAEoAeQB3AE4AQwBpAEEAZwBjAEgASgB2AGUARgA5AGoAYgBHADkAegBaAFQA
>> "%~1" echo bwBuADUATAB5AGEANQBxAGkAaAA1AG8AdQBmADUATAAyAHAANQBvAGkAMAA2AFoA
>> "%~1" echo MgBnADYATAArAFIANwA3AHkATQA1AFkAKwB2ADYASQBPADkANgBaAGkANwA1AHEA
>> "%~1" echo MgBpADYASQBlAHEANQBZAHEAbwA1ADQAYQBFADUAYgBHAFAANAA0AEMAQwBKAHkA
>> "%~1" echo dwBOAEMAaQBBAGcAYwBtAFYAegBkAEcAOQB5AFoAVgA5AGkAWQBXAE4AcgBkAFgA
>> "%~1" echo QQA2AEoAKwBTADgAbQB1AGEASwBpAHUAbQBtAGwAdQBhAHMAbwBlAFcARwBtAGUA
>> "%~1" echo VwBGAHAAZQBXAEoAagBlAFcAawBoACsAUwA3AHYAZQBXAEEAdgBPAGEAQgBvAHUA
>> "%~1" echo VwBrAGoAZQBXAGIAbgBpAEIAUgBkAFcAVgB6AGQATwArADgAagBPAFcANQB0AHUA
>> "%~1" echo VwBQAGsAZQBtAEEAZwBTAEIAdwBjAG0AOQA0AFgAMgA5AHcAWgBXADcAagBnAEkA
>> "%~1" echo SQBuAEwAQQAwAEsASQBDAEIAagBkAFgATgAwAGIAMgAxAGYAYwAyAFYAMABkAEcA
>> "%~1" echo bAB1AFoAegBvAG4ANQBMAHkAYQA1ADUAdQAwADUAbwA2AGwANQBZAGEAWgBJAEUA
>> "%~1" echo RgB1AFoASABKAHYAYQBXAFEAZwBjADIAVgAwAGQARwBsAHUAWgAzAFAAagBnAEkA
>> "%~1" echo TABwAGwASgBuAG8AcgA2AC8AcABsAEsANwBsAGcATAB6AGwAagA2AC8AbwBnADcA
>> "%~1" echo MwBsAHYAYgBIAGwAawA0ADMAawB2AEoASABuAG4ASwBEAGoAZwBJAEgAbgB2AFoA
>> "%~1" echo SABuAHUANQB6AG0AaQBKAGIAbwBzAEkAUABvAHIANQBYAGoAZwBJAEkAbgBMAEEA
>> "%~1" echo MABLAEkAQwBCAGoAZABYAE4AMABiADIAMQBmAFkAbgBKAHYAWQBXAFIAagBZAFgA
>> "%~1" echo TgAwAE8AaQBmAGsAdgBKAHIAbABqADUASABwAGcASQBIAG8AaAA2AHIAbAByAHAA
>> "%~1" echo cgBrAHUAWQBrAGcAUQBXADUAawBjAG0AOQBwAFoAQwBEAGwAdQBiAC8AbQBrAHEA
>> "%~1" echo MwB2AHYASQB6AGwAagA2AHIAbAB1ADcAcgBvAHIAcQA3AGsAdgBhAEQAbQBtAEkA
>> "%~1" echo NwBuAG8AYQA3AG4AbgA2AFgAcABnAFoATQBnAFkAVwBOADAAYQBXADkAdQBJAE8A
>> "%~1" echo VwBRAHEAKwBTADUAaQBlAGEAWAB0AHUAUwA5AHYAKwBlAFUAcQBPAE8AQQBnAGkA
>> "%~1" echo YwBOAEMAbgAwADcARABRAHAAagBiADIANQB6AGQAQwBCAHcAWQBYAEoAaABiAFUA
>> "%~1" echo UgBsAFoAbgBNADkAVwB3ADAASwBJAEMAQgA3AGEAMgBWADUATwBpAGQAegBkAEcA
>> "%~1" echo RgA1AFQAMgA0AG4ATABHADUAaABiAFcAVQA2AEoAKwBTAC8AbgBlAGEATQBnAGUA
>> "%~1" echo VwBVAHAATwBtAEcAawBpAGMAcwBjADIAVgAwAGQARwBsAHUAWgB6AG8AbgBaADIA
>> "%~1" echo eAB2AFkAbQBGAHMATABuAE4AMABZAFgAbABmAGIAMgA1AGYAZAAyAGgAcABiAEcA
>> "%~1" echo VgBmAGMARwB4ADEAWgAyAGQAbABaAEYAOQBwAGIAaQBjAHMAYwAyAEYAbQBaAFQA
>> "%~1" echo bwBuAE0AQwBjAHMAWQBXAE4AMABhAFcAOQB1AE8AaQBkAHkAWgBYAE4AbABkAEYA
>> "%~1" echo OQB6AGQARwBGADUAWAAyADkAdQBKAHkAeAB1AGIAMwBSAGwATwBpAGMAdwBQAGUA
>> "%~1" echo VwBGAGcAZQBpAHUAdQBPAGEAdABvACsAVwA0AHUATwBTADgAawBlAGUAYwBvAE8A
>> "%~1" echo KwA4AG0AegBNADkAVgBWAE4AQwBMADAARgBEAEkATwBhAFAAawB1AGUAVQB0AGUA
>> "%~1" echo UwAvAG4AZQBhAE0AZwBlAFcAVQBwAE8AbQBHAGsAaQBkADkATABBADAASwBJAEMA
>> "%~1" echo QgA3AGEAMgBWADUATwBpAGQAMwBhAFcAWgBwAFUAMgB4AGwAWgBYAEEAbgBMAEcA
>> "%~1" echo NQBoAGIAVwBVADYASgAxAGQAcABMAFUAWgBwAEkATwBTADgAawBlAGUAYwBvAE8A
>> "%~1" echo ZQB0AGwAdQBlAFYAcABTAGMAcwBjADIAVgAwAGQARwBsAHUAWgB6AG8AbgBaADIA
>> "%~1" echo eAB2AFkAbQBGAHMATABuAGQAcABaAG0AbABmAGMAMgB4AGwAWgBYAEIAZgBjAEcA
>> "%~1" echo OQBzAGEAVwBOADUASgB5AHgAegBZAFcAWgBsAE8AaQBjAHgASgB5AHgAaABZADMA
>> "%~1" echo UgBwAGIAMgA0ADYASgAzAEoAbABjADIAVgAwAFgAMwBkAHAAWgBtAGwAZgBjADIA
>> "%~1" echo eABsAFoAWABBAG4ATABHADUAdgBkAEcAVQA2AEoAegBFADkANQBMACsAZAA1AGEA
>> "%~1" echo NgBJADYAYgB1AFkANgBLADYAawA3ADcAeQBiAE0AagAzAG0AbAA2AGYAbgBpAFkA
>> "%~1" echo agBtAHMATABqAGsAdQBJADMAawB2AEoASABuAG4ASwBBAG4AZgBTAHcATgBDAGkA
>> "%~1" echo QQBnAGUAMgB0AGwAZQBUAG8AbgBjADIATgB5AFoAVwBWAHUAVAAyAFoAbQBKAHkA
>> "%~1" echo eAB1AFkAVwAxAGwATwBpAGYAbABzAFkALwBsAHUAWgBYAG8AdABvAFgAbQBsADcA
>> "%~1" echo WQBuAEwASABOAGwAZABIAFIAcABiAG0AYwA2AEoAMwBOADUAYwAzAFIAbABiAFMA
>> "%~1" echo NQB6AFkAMwBKAGwAWgBXADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgA
>> "%~1" echo UQBuAEwASABOAGgAWgBtAFUANgBKAHoATQB3AE0ARABBAHcATQBDAGMAcwBZAFcA
>> "%~1" echo TgAwAGEAVwA5AHUATwBpAGQAeQBaAFgATgBsAGQARgA5AHoAWQAzAEoAbABaAFcA
>> "%~1" echo NQBmAGIAMgBaAG0ASgB5AHgAdQBiADMAUgBsAE8AaQBmAGwAagBaAFgAawB2AFkA
>> "%~1" echo MwBtAHIANgB2AG4AcAA1AEwAdgB2AEoAcwB6AE0ARABBAHcATQBEAEEAOQBOAFMA
>> "%~1" echo RABsAGkASQBiAHAAawBwAC8AdgB2AEkAdwA0AE4AagBRAHcATQBEAEEAdwBNAEQA
>> "%~1" echo MAB5AE4AQwBEAGwAcwBJAC8AbQBsADcAWQBuAGYAUwB3AE4AQwBpAEEAZwBlADIA
>> "%~1" echo dABsAGUAVABvAG4AYwAyAHgAbABaAFgAQgBVAGEAVwAxAGwAYgAzAFYAMABKAHkA
>> "%~1" echo eAB1AFkAVwAxAGwATwBpAGYAbgBzADcAdgBuAHUANQAvAG4AbgBhAEgAbgBuAEsA
>> "%~1" echo RABvAHQAbwBYAG0AbAA3AFkAbgBMAEgATgBsAGQASABSAHAAYgBtAGMANgBKADMA
>> "%~1" echo TgBsAFkAMwBWAHkAWgBTADUAegBiAEcAVgBsAGMARgA5ADAAYQBXADEAbABiADMA
>> "%~1" echo VgAwAEoAeQB4AHoAWQBXAFoAbABPAGkAZAB1AGQAVwB4AHMASgB5AHgAaABZADMA
>> "%~1" echo UgBwAGIAMgA0ADYASgAzAEoAbABjADIAVgAwAFgAMwBOAHMAWgBXAFYAdwBYADMA
>> "%~1" echo UgBwAGIAVwBWAHYAZABYAFEAbgBMAEcANQB2AGQARwBVADYASgAyADUAMQBiAEcA
>> "%~1" echo dwA5ADUANwBPADcANQA3AHUAZgA2AGIAdQBZADYASwA2AGsANwA3AHkAYgBMAFQA
>> "%~1" echo RQA5ADUATABpAE4ANgBJAGUAcQA1AFkAcQBvADUANQAyAGgANQA1AHkAZwBKADMA
>> "%~1" echo MABOAEMAbAAwADcARABRAHAAcwBaAFgAUQBnAGIARwBGAHoAZABEADEANwBmAFMA
>> "%~1" echo eABpAGQAWABOADUAUABXAFoAaABiAEgATgBsAEwASABCAGwAYgBtAFIAcABiAG0A
>> "%~1" echo ZABEAGIAMgA1AG0AYQBYAEoAdABQAFcANQAxAGIARwB3ADcARABRAHAAbQBkAFcA
>> "%~1" echo NQBqAGQARwBsAHYAYgBpAEIAbABjADIATQBvAGMAeQBsADcAYwBtAFYAMABkAFgA
>> "%~1" echo SgB1AEkARgBOADAAYwBtAGwAdQBaAHkAaAB6AFAAegA4AG4ASgB5AGsAdQBjAG0A
>> "%~1" echo VgB3AGIARwBGAGoAWgBTAGcAdgBXAHkAWQA4AFAAaQBJAG4AWABTADkAbgBMAEcA
>> "%~1" echo TQA5AFAAaQBoADcASgB5AFkAbgBPAGkAYwBtAFkAVwAxAHcATwB5AGMAcwBKAHoA
>> "%~1" echo dwBuAE8AaQBjAG0AYgBIAFEANwBKAHkAdwBuAFAAaQBjADYASgB5AFoAbgBkAEQA
>> "%~1" echo cwBuAEwAQwBjAGkASgB6AG8AbgBKAG4ARgAxAGIAMwBRADcASgB5AHcAaQBKAHkA
>> "%~1" echo SQA2AEoAeQBZAGoATQB6AGsANwBKADMAMQBiAFkAMQAwAHAASwBYADAATgBDAG0A
>> "%~1" echo WgAxAGIAbQBOADAAYQBXADkAdQBJAEcAVgB0AGMASABSADUASwBIAFkAcABlADMA
>> "%~1" echo SgBsAGQASABWAHkAYgBpAEIAMgBQAFQAMAA5AGQAVwA1AGsAWgBXAFoAcABiAG0A
>> "%~1" echo VgBrAGYASAB4ADIAUABUADAAOQBiAG4AVgBzAGIASAB4ADgAZABqADAAOQBQAFMA
>> "%~1" echo YwBuAGYASAB4ADIAUABUADAAOQBKADIANQAxAGIARwB3AG4AZgBRADAASwBaAG4A
>> "%~1" echo VgB1AFkAMwBSAHAAYgAyADQAZwBjADIAaAB2AGQAMgA0AG8AZABpAGwANwBjAG0A
>> "%~1" echo VgAwAGQAWABKAHUASQBHAFYAdABjAEgAUgA1AEsASABZAHAAUAB5AGMAdABKAHoA
>> "%~1" echo cABUAGQASABKAHAAYgBtAGMAbwBkAGkAbAA5AEQAUQBwAG0AZABXADUAagBkAEcA
>> "%~1" echo bAB2AGIAaQBCAHoAWgBYAFEAbwBhAFcAUQBzAGQAaQBsADcAWQAyADkAdQBjADMA
>> "%~1" echo UQBnAFoAVAAwAGsASwBHAGwAawBLAFQAdABwAFoAaQBoAGwASwBXAFUAdQBkAEcA
>> "%~1" echo VgA0AGQARQBOAHYAYgBuAFIAbABiAG4AUQA5AGMAMgBoAHYAZAAyADQAbwBkAGkA
>> "%~1" echo bAA5AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCADIASwBHAHMAcABlADMA
>> "%~1" echo SgBsAGQASABWAHkAYgBpAEIAegBhAEcAOQAzAGIAaQBoAHMAWQBYAE4AMABXADIA
>> "%~1" echo dABkAEsAVAB0ADkARABRAHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAdQBiADMA
>> "%~1" echo UgBwAFoAbgBrAG8AZABHAGwAMABiAEcAVQBzAGIAWABOAG4ATABIAFIANQBjAEcA
>> "%~1" echo VQA5AEoAMgA5AHIASgB5AHgAdABjAHoAMAB6AE0AagBBAHcASwBYAHQAagBiADIA
>> "%~1" echo NQB6AGQAQwBCAG8AYgAzAE4AMABQAFMAUQBvAEoAMwBSAHYAWQBYAE4AMABjAHkA
>> "%~1" echo YwBwAE8AMgBsAG0ASwBDAEYAbwBiADMATgAwAEsAWABKAGwAZABIAFYAeQBiAGoA
>> "%~1" echo dABqAGIAMgA1AHoAZABDAEIAbABiAEQAMQBrAGIAMgBOADEAYgBXAFYAdQBkAEMA
>> "%~1" echo NQBqAGMAbQBWAGgAZABHAFYARgBiAEcAVgB0AFoAVwA1ADAASwBDAGQAawBhAFgA
>> "%~1" echo WQBuAEsAVAB0AGwAYgBDADUAagBiAEcARgB6AGMAMAA1AGgAYgBXAFUAOQBKADMA
>> "%~1" echo UgB2AFkAWABOADAASQBDAGMAcgBkAEgAbAB3AFoAVAB0AGwAYgBDADUAcABiAG0A
>> "%~1" echo NQBsAGMAawBoAFUAVABVAHcAOQBKAHoAeABpAFAAaQBjAHIAWgBYAE4AagBLAEgA
>> "%~1" echo UgBwAGQARwB4AGwASwBTAHMAbgBQAEMAOQBpAFAAagB4AHoAYwBHAEYAdQBQAGkA
>> "%~1" echo YwByAFoAWABOAGoASwBHADEAegBaADMAeAA4AEoAeQBjAHAASwB5AGMAOABMADMA
>> "%~1" echo TgB3AFkAVwA0ACsASgB6AHQAbwBiADMATgAwAEwAbQBGAHcAYwBHAFYAdQBaAEUA
>> "%~1" echo TgBvAGEAVwB4AGsASwBHAFYAcwBLAFQAdAB5AFoAWABGADEAWgBYAE4AMABRAFcA
>> "%~1" echo NQBwAGIAVwBGADAAYQBXADkAdQBSAG4ASgBoAGIAVwBVAG8ASwBDAGsAOQBQAG0A
>> "%~1" echo VgBzAEwAbQBOAHMAWQBYAE4AegBUAEcAbAB6AGQAQwA1AGgAWgBHAFEAbwBKADMA
>> "%~1" echo TgBvAGIAMwBjAG4ASwBTAGsANwBjADIAVgAwAFYARwBsAHQAWgBXADkAMQBkAEMA
>> "%~1" echo ZwBvAEsAVAAwACsAZQAyAFYAcwBMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMA
>> "%~1" echo NQB5AFoAVwAxAHYAZABtAFUAbwBKADMATgBvAGIAMwBjAG4ASwBUAHQAegBaAFgA
>> "%~1" echo UgBVAGEAVwAxAGwAYgAzAFYAMABLAEMAZwBwAFAAVAA1AGwAYgBDADUAeQBaAFcA
>> "%~1" echo MQB2AGQAbQBVAG8ASwBTAHcAeQBNAGoAQQBwAGYAUwB4AHQAYwB5AGwAOQBEAFEA
>> "%~1" echo cABtAGQAVwA1AGoAZABHAGwAdgBiAGkAQgB6AGEARwA5ADMAUQAyADkAdQBaAG0A
>> "%~1" echo bAB5AGIAUwBoAGgAWQAzAFIAcABiADIANABzAGIARwBGAGkAWgBXAHcAcwBaAFgA
>> "%~1" echo aAAwAGMAbQBFADkASgB5AGMAcABlADMAQgBsAGIAbQBSAHAAYgBtAGQARABiADIA
>> "%~1" echo NQBtAGEAWABKAHQAUABYAHQAaABZADMAUgBwAGIAMgA0AHMAYgBHAEYAaQBaAFcA
>> "%~1" echo dwBzAFoAWABoADAAYwBtAEYAOQBPAHkAUQBvAEoAMgBOAHYAYgBtAFoAcABjAG0A
>> "%~1" echo MQBVAGEAWABSAHMAWgBTAGMAcABMAG4AUgBsAGUASABSAEQAYgAyADUAMABaAFcA
>> "%~1" echo NQAwAFAAUwBmAG4AbwBhADcAbwByAHEAVABtAGkAYQBmAG8AbwBZAHoAdgB2AEoA
>> "%~1" echo bwBuAEsAMgB4AGgAWQBtAFYAcwBPAHkAUQBvAEoAMgBOAHYAYgBtAFoAcABjAG0A
>> "%~1" echo MQBOAGMAMgBjAG4ASwBTADUAMABaAFgAaAAwAFEAMgA5AHUAZABHAFYAdQBkAEQA
>> "%~1" echo MQBqAGIAMgA1AG0AYQBYAEoAdABWAEcAVgA0AGQARgB0AGgAWQAzAFIAcABiADIA
>> "%~1" echo NQBkAGYASAB3AG4ANgBMACsAWgA1AEwAaQBxADUAcABPAE4ANQBMADIAYwA1AEwA
>> "%~1" echo eQBhADUATAArAHUANQBwAFMANQBJAEYARgAxAFoAWABOADAASQBPAGUASwB0AHUA
>> "%~1" echo YQBBAGcAZQBPAEEAZwBpAGMANwBKAEMAZwBuAFkAMgA5AHUAWgBtAGwAeQBiAFUA
>> "%~1" echo MQBoAGMAMgBzAG4ASwBTADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBZAFcA
>> "%~1" echo UgBrAEsAQwBkAHoAYQBHADkAMwBKAHkAbAA5AEQAUQBwAG0AZABXADUAagBkAEcA
>> "%~1" echo bAB2AGIAaQBCAGoAYgBHADkAegBaAFUATgB2AGIAbQBaAHAAYwBtADAAbwBLAFgA
>> "%~1" echo dAB3AFoAVwA1AGsAYQBXADUAbgBRADIAOQB1AFoAbQBsAHkAYgBUADEAdQBkAFcA
>> "%~1" echo eABzAE8AeQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMAbQAxAE4AWQBYAE4AcgBKAHkA
>> "%~1" echo awB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwAbgBKAGwAYgBXADkAMgBaAFMA
>> "%~1" echo ZwBuAGMAMgBoAHYAZAB5AGMAcABmAFEAMABLAFoAbgBWAHUAWQAzAFIAcABiADIA
>> "%~1" echo NABnAGQARwBoAGwAYgBXAFUAbwBLAFgAdABqAGIAMgA1AHoAZABDAEIAcwBhAFcA
>> "%~1" echo ZABvAGQARAAxAHMAYgAyAE4AaABiAEYATgAwAGIAMwBKAGgAWgAyAFUAdQBaADIA
>> "%~1" echo VgAwAFMAWABSAGwAYgBTAGgAMABhAEcAVgB0AFoAVQB0AGwAZQBTAGsAOQBQAFQA
>> "%~1" echo MABuAGIARwBsAG4AYQBIAFEAbgBPADIAUgB2AFkAMwBWAHQAWgBXADUAMABMAG0A
>> "%~1" echo SgB2AFoASABrAHUAWQAyAHgAaABjADMATgBNAGEAWABOADAATABuAFIAdgBaADIA
>> "%~1" echo ZABzAFoAUwBnAG4AWgBHAEYAeQBhAHkAYwBzAEkAVwB4AHAAWgAyAGgAMABLAFQA
>> "%~1" echo cwBrAEsAQwBkADAAYQBHAFYAdABaAFUASgAwAGIAaQBjAHAATABuAFIAbABlAEgA
>> "%~1" echo UgBEAGIAMgA1ADAAWgBXADUAMABQAFcAeABwAFoAMgBoADAAUAB5AGYAbQB0ADcA
>> "%~1" echo SABvAGkAYgBJAG4ATwBpAGYAbQB0AFkAWABvAGkAYgBJAG4AZgBRADAASwBaAG4A
>> "%~1" echo VgB1AFkAMwBSAHAAYgAyADQAZwBiAEcAOQBuAEsASABRAHAAZQAzAE4AbABkAEMA
>> "%~1" echo ZwBuAGIARwA5AG4AUQBtADkANABKAHkAeAB1AFoAWABjAGcAUgBHAEYAMABaAFMA
>> "%~1" echo ZwBwAEwAbgBSAHYAVABHADkAagBZAFcAeABsAFYARwBsAHQAWgBWAE4AMABjAG0A
>> "%~1" echo bAB1AFoAeQBnAHAASwB5AGMAZwBJAEMAYwByAGQAQwBsADkARABRAHAAbQBkAFcA
>> "%~1" echo NQBqAGQARwBsAHYAYgBpAEIAegBhAEcAOQB5AGQARgBCAGgAZABHAGcAbwBjAEMA
>> "%~1" echo bAA3AGEAVwBZAG8ASQBYAEEAcABjAG0AVgAwAGQAWABKAHUASgAyAEYAawBZAGkA
>> "%~1" echo NQBsAGUARwBVAG4ATwAyAE4AdgBiAG4ATgAwAEkARwBFADkAYwBDADUAegBjAEcA
>> "%~1" echo eABwAGQAQwBnAHYAVwAxAHgAYwBMADEAMAB2AEsAVAB0AHkAWgBYAFIAMQBjAG0A
>> "%~1" echo NABnAFkAVgB0AGgATABtAHgAbABiAG0AZAAwAGEAQwAwAHgAWABYAHgAOABjAEgA
>> "%~1" echo MABOAEMAbQBaADEAYgBtAE4AMABhAFcAOQB1AEkASABCAGoAZABDAGgANABMAEcA
>> "%~1" echo MQBoAGUARAAwAHgATQBEAEEAcABlADIATgB2AGIAbgBOADAASQBHADQAOQBjAEcA
>> "%~1" echo RgB5AGMAMgBWAEcAYgBHADkAaABkAEMAaAA0AEsAVAB0AHkAWgBYAFIAMQBjAG0A
>> "%~1" echo NABnAGEAWABOAEcAYQBXADUAcABkAEcAVQBvAGIAaQBrAC8AVABXAEYAMABhAEMA
>> "%~1" echo NQB0AFkAWABnAG8ATQBDAHgATgBZAFgAUgBvAEwAbQAxAHAAYgBpAGcAeABNAEQA
>> "%~1" echo QQBzAGIAaQA5AHQAWQBYAGcAcQBNAFQAQQB3AEsAUwBrADYATQBIADAATgBDAG0A
>> "%~1" echo WgAxAGIAbQBOADAAYQBXADkAdQBJAEgASgBwAGIAbQBjAG8AYQBXAFEAcwBkAEcA
>> "%~1" echo VgA0AGQAQwB4AHMAWQBXAEoAbABiAEMAeAB3AEwARwAxAHYAWgBHAFUAcABlADIA
>> "%~1" echo TgB2AGIAbgBOADAASQBHAEoAdgBlAEQAMABrAEsARwBsAGsASwBTAHgAdABQAFcA
>> "%~1" echo SgB2AGUAQwBZAG0AWQBtADkANABMAG4ARgAxAFoAWABKADUAVQAyAFYAcwBaAFcA
>> "%~1" echo TgAwAGIAMwBJAG8ASgB5ADUAdABaAFgAUgBsAGMAaQBjAHAATwAyAGwAbQBLAEMA
>> "%~1" echo RgBpAGIAMwBoADgAZgBDAEYAdABLAFgASgBsAGQASABWAHkAYgBqAHQAdABMAG4A
>> "%~1" echo TgBsAGQARQBGADAAZABIAEoAcABZAG4AVgAwAFoAUwBnAG4AYwAzAFIAeQBiADIA
>> "%~1" echo dABsAEwAVwBSAGgAYwAyAGgAaABjAG4ASgBoAGUAUwBjAHMAVABXAEYAMABhAEMA
>> "%~1" echo NQB5AGIAMwBWAHUAWgBDAGgAdwBLAFMAcwBuAEkARABFAHcATQBDAGMAcABPADIA
>> "%~1" echo SgB2AGUAQwA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAYwBtAFYAdABiADMA
>> "%~1" echo WgBsAEsAQwBkAG4AYwBtAFYAbABiAGkAYwBzAEoAMgBGAHQAWQBtAFYAeQBKAHkA
>> "%~1" echo dwBuAGMAbQBWAGsASgB5AGsANwBhAFcAWQBvAGIAVwA5AGsAWgBTAGwAaQBiADMA
>> "%~1" echo ZwB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwAbQBGAGsAWgBDAGgAdABiADIA
>> "%~1" echo UgBsAEsAVAB0AHAAWgBpAGgAcABaAEQAMAA5AFAAUwBkAGkAWQBYAFIAMABaAFgA
>> "%~1" echo SgA1AFIAMgBGADEAWgAyAFUAbgBLAFgAdAB6AFoAWABRAG8ASgAyAEoAaABkAEgA
>> "%~1" echo UgBsAGMAbgBsAFUAWgBYAGgAMABKAHkAeAAwAFoAWABoADAASwBUAHQAegBaAFgA
>> "%~1" echo UQBvAEoAMgBKAGgAZABIAFIAbABjAG4AbABUAGQAVwBJAG4ATABHAHgAaABZAG0A
>> "%~1" echo VgBzAEsAWAAxAHAAWgBpAGgAcABaAEQAMAA5AFAAUwBkADAAWgBXADEAdwBSADIA
>> "%~1" echo RgAxAFoAMgBVAG4ASwBYAHQAegBaAFgAUQBvAEoAMwBSAGwAYgBYAEIAVQBaAFgA
>> "%~1" echo aAAwAEoAeQB4ADAAWgBYAGgAMABLAFQAdAB6AFoAWABRAG8ASgAzAFIAbABiAFgA
>> "%~1" echo QgBUAGQAVwBJAG4ATABHAHgAaABZAG0AVgBzAEsAWAAxAHAAWgBpAGgAcABaAEQA
>> "%~1" echo MAA5AFAAUwBkAHoAYgBHAFYAbABjAEUAZABoAGQAVwBkAGwASgB5AGwANwBjADIA
>> "%~1" echo VgAwAEsAQwBkAHoAYgBHAFYAbABjAEYAUgBsAGUASABRAG4ATABIAFIAbABlAEgA
>> "%~1" echo UQBwAE8AMwBOAGwAZABDAGcAbgBjADIAeABsAFoAWABCAFQAZABXAEkAbgBMAEcA
>> "%~1" echo eABoAFkAbQBWAHMASwBYADEAOQBEAFEAcABtAGQAVwA1AGoAZABHAGwAdgBiAGkA
>> "%~1" echo QgB1AGIAMwBKAHQASwBIAFkAcABlADMASgBsAGQASABWAHkAYgBpAEIAegBhAEcA
>> "%~1" echo OQAzAGIAaQBoADIASwBTADUAMABjAG0AbAB0AEsAQwBsADkARABRAHAAbQBkAFcA
>> "%~1" echo NQBqAGQARwBsAHYAYgBpAEIAcABjADEATgBoAFoAbQBWAFcAWQBXAHgAMQBaAFMA
>> "%~1" echo aABrAFoAVwBZAHMAZABtAEYAcwBkAFcAVQBwAGUAMgBOAHYAYgBuAE4AMABJAEgA
>> "%~1" echo WgBoAGIARAAxAHUAYgAzAEoAdABLAEgAWgBoAGIASABWAGwASwBUAHQAcABaAGkA
>> "%~1" echo aABrAFoAVwBZAHUAYwAyAEYAbQBaAFQAMAA5AFAAUwBkAHUAZABXAHgAcwBKAHkA
>> "%~1" echo bAB5AFoAWABSADEAYwBtADQAZwBkAG0ARgBzAFAAVAAwADkASgAyADUAMQBiAEcA
>> "%~1" echo dwBuAGYASAB4ADIAWQBXAHcAOQBQAFQAMABuAEwAUwBjADcAYwBtAFYAMABkAFgA
>> "%~1" echo SgB1AEkASABaAGgAYgBEADAAOQBQAFcAUgBsAFoAaQA1AHoAWQBXAFoAbABmAFEA
>> "%~1" echo MABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGMAbQBWAHUAWgBHAFYAeQBVAEcA
>> "%~1" echo RgB5AFkAVwAxAHoASwBDAGwANwBZADIAOQB1AGMAMwBRAGcAYQBHADkAegBkAEQA
>> "%~1" echo MABrAEsAQwBkAHcAWQBYAEoAaABiAFUAeABwAGMAMwBRAG4ASwBUAHQAcABaAGkA
>> "%~1" echo ZwBoAGEARwA5AHoAZABDAGwAeQBaAFgAUgAxAGMAbQA0ADcAYQBHADkAegBkAEMA
>> "%~1" echo NQBwAGIAbQA1AGwAYwBrAGgAVQBUAFUAdwA5AEoAeQBjADcAYgBHAFYAMABJAEcA
>> "%~1" echo TgBvAFkAVwA1AG4AWgBXAFEAOQBNAEQAdABqAGIAMgA1AHoAZABDAEIAdgBaAG0A
>> "%~1" echo WgBzAGEAVwA1AGwAUABXAHgAaABjADMAUQB1AFkAMgA5AHUAYgBtAFYAagBkAEcA
>> "%~1" echo VgBrAEkAVAAwADkASgAzAFIAeQBkAFcAVQBuAE8AMwBCAGgAYwBtAEYAdABSAEcA
>> "%~1" echo VgBtAGMAeQA1AG0AYgAzAEoARgBZAFcATgBvAEsARwBSAGwAWgBqADAAKwBlADIA
>> "%~1" echo TgB2AGIAbgBOADAASQBIAFoAaABiAEQAMQB1AGIAMwBKAHQASwBHAHgAaABjADMA
>> "%~1" echo UgBiAFoARwBWAG0ATABtAHQAbABlAFYAMABwAE8AMgBOAHYAYgBuAE4AMABJAEcA
>> "%~1" echo OQByAFAAUwBGAHYAWgBtAFoAcwBhAFcANQBsAEoAaQBaAHAAYwAxAE4AaABaAG0A
>> "%~1" echo VgBXAFkAVwB4ADEAWgBTAGgAawBaAFcAWQBzAGQAbQBGAHMASwBUAHQAcABaAGkA
>> "%~1" echo ZwBoAGIAMgBzAG0ASgBpAEYAdgBaAG0AWgBzAGEAVwA1AGwASwBXAE4AbwBZAFcA
>> "%~1" echo NQBuAFoAVwBRAHIASwB6AHQAagBiADIANQB6AGQAQwBCAHAAZABHAFYAdABQAFcA
>> "%~1" echo UgB2AFkAMwBWAHQAWgBXADUAMABMAG0ATgB5AFoAVwBGADAAWgBVAFYAcwBaAFcA
>> "%~1" echo MQBsAGIAbgBRAG8ASgAyAFIAcABkAGkAYwBwAE8AMgBsADAAWgBXADAAdQBZADIA
>> "%~1" echo eABoAGMAMwBOAE8AWQBXADEAbABQAFMAZAB3AFkAWABKAGgAYgBVAGwAMABaAFcA
>> "%~1" echo MABnAEoAeQBzAG8AYgAyAFoAbQBiAEcAbAB1AFoAVAA4AG4ASgB6AHAAdgBhAHoA
>> "%~1" echo OABuAGIAMgBzAG4ATwBpAGQAagBhAEcARgB1AFoAMgBWAGsASgB5AGsANwBZADIA
>> "%~1" echo OQB1AGMAMwBRAGcAYwAzAFIAaABkAEcAVQA5AGIAMgBaAG0AYgBHAGwAdQBaAFQA
>> "%~1" echo OABuADUAcAB5AHEANgBLACsANwA1AFkAKwBXAEoAegBvAG8AYgAyAHMALwBKACsA
>> "%~1" echo bQA3AG0ATwBpAHUAcABPAFcAQQB2AEMAYwA2AEoAKwBXADMAcwB1AFMALwByAHUA
>> "%~1" echo YQBVAHUAUwBjAHAATwAyAGwAMABaAFcAMAB1AGEAVwA1AHUAWgBYAEoASQBWAEUA
>> "%~1" echo MQBNAFAAUwBjADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABWAHcAaQBjAEcA
>> "%~1" echo RgB5AFkAVwAxAE8AWQBXADEAbABYAEMASQArAFAARwBJACsASgB5AHQAbABjADIA
>> "%~1" echo TQBvAFoARwBWAG0ATABtADUAaABiAFcAVQBwAEsAeQBjADgATAAyAEkAKwBQAEgA
>> "%~1" echo TgB3AFkAVwA0ACsASgB5AHQAbABjADIATQBvAFoARwBWAG0ATABuAE4AbABkAEgA
>> "%~1" echo UgBwAGIAbQBjAHAASwB5AGMAOABMADMATgB3AFkAVwA0ACsAUABDADkAawBhAFgA
>> "%~1" echo WQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAxAGMASQBuAEIAaABjAG0A
>> "%~1" echo RgB0AFYAbQBGAHMAZABXAFYAYwBJAGoANAA4AGMAMwBCAGgAYgBqADcAbAB2AFoA
>> "%~1" echo UABsAGkAWQAzAGwAZwBMAHcAOABMADMATgB3AFkAVwA0ACsAUABHAEkAKwBKAHkA
>> "%~1" echo dABsAGMAMgBNAG8AZABtAEYAcwBLAFMAcwBuAFAAQwA5AGkAUABqAHcAdgBaAEcA
>> "%~1" echo bAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkAWABDAEoAdwBZAFgA
>> "%~1" echo SgBoAGIAVgBaAGgAYgBIAFYAbABYAEMASQArAFAASABOAHcAWQBXADQAKwA2AGIA
>> "%~1" echo dQBZADYASwA2AGsANQBZAEMAOABQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBQAGkA
>> "%~1" echo YwByAFoAWABOAGoASwBHAFIAbABaAGkANQB6AFkAVwBaAGwASwBTAHMAbgBQAEMA
>> "%~1" echo OQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZACsAUABIAE4AdwBZAFcA
>> "%~1" echo NABnAFkAMgB4AGgAYwAzAE0AOQBYAEMASgB3AFkAWABKAGgAYgBWAE4AMABZAFgA
>> "%~1" echo UgBsAFgAQwBJACsASgB5AHQAbABjADIATQBvAGMAMwBSAGgAZABHAFUAcABLAHkA
>> "%~1" echo YwA4AEwAMwBOAHcAWQBXADQAKwBJAEMAYwByAEsAQwBGAHYAWgBtAFoAcwBhAFcA
>> "%~1" echo NQBsAEoAaQBZAGgAYgAyAHMALwBKAHoAeABpAGQAWABSADAAYgAyADQAZwBZADIA
>> "%~1" echo eABoAGMAMwBNADkAWABDAEoAeQBaAFgATgBsAGQARQBKADAAYgBpAEIAdwBjAG0A
>> "%~1" echo bAB0AFkAWABKADUAWABDAEkAZwBaAEcARgAwAFkAUwAxAHkAWgBYAE4AbABkAEQA
>> "%~1" echo MQBjAEkAaQBjAHIAWgBYAE4AagBLAEcAUgBsAFoAaQA1AGgAWQAzAFIAcABiADIA
>> "%~1" echo NABwAEsAeQBkAGMASQBqADcAcABoADQAMwBuAHYAYQA0ADgATAAyAEoAMQBkAEgA
>> "%~1" echo UgB2AGIAagA0AG4ATwBpAGMAbgBLAFMAcwBuAFAAQwA5AGsAYQBYAFkAKwBQAEcA
>> "%~1" echo UgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMQBjAEkAbgBCAGgAYwBtAEYAdABUAG0A
>> "%~1" echo RgB0AFoAVgB3AGkASQBIAE4AMABlAFcAeABsAFAAVgB3AGkAWgAzAEoAcABaAEMA
>> "%~1" echo MQBqAGIAMgB4ADEAYgBXADQANgBNAFMAOAB0AE0AVgB3AGkAUABqAHgAegBjAEcA
>> "%~1" echo RgB1AFAAaQBjAHIAWgBYAE4AagBLAEcAUgBsAFoAaQA1AHUAYgAzAFIAbABLAFMA
>> "%~1" echo cwBuAFAAQwA5AHoAYwBHAEYAdQBQAGoAdwB2AFoARwBsADIAUABpAGMANwBhAEcA
>> "%~1" echo OQB6AGQAQwA1AGgAYwBIAEIAbABiAG0AUgBEAGEARwBsAHMAWgBDAGgAcABkAEcA
>> "%~1" echo VgB0AEsAWAAwAHAATwAzAE4AbABkAEMAZwBuAGMARwBGAHkAWQBXADEAVABkAFcA
>> "%~1" echo MQB0AFkAWABKADUASgB5AHgAdgBaAG0AWgBzAGEAVwA1AGwAUAB5AGYAbQBuAEsA
>> "%~1" echo cgBvAHYANQA3AG0AagBxAFUAbgBPAG0ATgBvAFkAVwA1AG4AWgBXAFEALwBZADIA
>> "%~1" echo aABoAGIAbQBkAGwAWgBDAHMAbgBJAE8AbQBoAHUAZQBXADMAcwB1AFMALwByAHUA
>> "%~1" echo YQBVAHUAUwBjADYASgArAFcARgBxAE8AbQBEAHEATwBtADcAbQBPAGkAdQBwAEMA
>> "%~1" echo YwBwAE8AMgBoAHYAYwAzAFEAdQBjAFgAVgBsAGMAbgBsAFQAWgBXAHgAbABZADMA
>> "%~1" echo UgB2AGMAawBGAHMAYgBDAGcAbgBXADIAUgBoAGQARwBFAHQAYwBtAFYAegBaAFgA
>> "%~1" echo UgBkAEoAeQBrAHUAWgBtADkAeQBSAFcARgBqAGEAQwBoAGkAZABHADQAOQBQAG0A
>> "%~1" echo SgAwAGIAaQA1AHYAYgBtAE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUAaABZADMA
>> "%~1" echo UgBwAGIAMgA0AG8AWQBuAFIAdQBMAG0AUgBoAGQARwBGAHoAWgBYAFEAdQBjAG0A
>> "%~1" echo VgB6AFoAWABRAHMASgB5AGMAcwBKACsAbQBIAGoAZQBlADkAcgB1AFcAUABnAHUA
>> "%~1" echo YQBWAHMAQwBjAHMAWQBuAFIAdQBMAEcAWgBoAGIASABOAGwASwBTAGwAOQBEAFEA
>> "%~1" echo cABoAGMAMwBsAHUAWQB5AEIAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAaABjAEcA
>> "%~1" echo awBvAGMARwBGADAAYQBDAHgAdgBjAEgAUgB6AFAAWAB0ADkASwBYAHQAagBiADIA
>> "%~1" echo NQB6AGQAQwBCAHoAWgBYAEEAOQBjAEcARgAwAGEAQwA1AHAAYgBtAE4AcwBkAFcA
>> "%~1" echo UgBsAGMAeQBnAG4AUAB5AGMAcABQAHkAYwBtAEoAegBvAG4AUAB5AGMANwBZADIA
>> "%~1" echo OQB1AGMAMwBRAGcAYwBqADEAaABkADIARgBwAGQAQwBCAG0AWgBYAFIAagBhAEMA
>> "%~1" echo aAB3AFkAWABSAG8ASwAzAE4AbABjAEMAcwBuAGQARwA5AHIAWgBXADQAOQBKAHkA
>> "%~1" echo dABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIAMgAxAHcAYgAyADUAbABiAG4A
>> "%~1" echo UQBvAFYARQA5AEwAUgBVADQAcABMAEUAOQBpAGEAbQBWAGoAZABDADUAaABjADMA
>> "%~1" echo TgBwAFoAMgA0AG8AZQAyAE4AaABZADIAaABsAE8AaQBkAHUAYgB5ADEAegBkAEcA
>> "%~1" echo OQB5AFoAUwBkADkATABHADkAdwBkAEgATQBwAEsAVAB0AHAAWgBpAGcAaABjAGkA
>> "%~1" echo NQB2AGEAeQBsADAAYQBIAEoAdgBkAHkAQgB1AFoAWABjAGcAUgBYAEoAeQBiADMA
>> "%~1" echo SQBvAEoAMABoAFUAVgBGAEEAZwBKAHkAdAB5AEwAbgBOADAAWQBYAFIAMQBjAHkA
>> "%~1" echo awA3AGMAbQBWADAAZABYAEoAdQBJAEcARgAzAFkAVwBsADAASQBIAEkAdQBhAG4A
>> "%~1" echo TgB2AGIAaQBnAHAAZgBRADAASwBZAFgATgA1AGIAbQBNAGcAWgBuAFYAdQBZADMA
>> "%~1" echo UgBwAGIAMgA0AGcAYgBHADkAaABaAEUAeAB2AFoAMwBNAG8AYwAyAGgAdgBkADAA
>> "%~1" echo NQB2AGQARwBsAGoAWgBUADEAbQBZAFcAeAB6AFoAUwBsADcAZABIAEoANQBlADIA
>> "%~1" echo TgB2AGIAbgBOADAASQBIAEkAOQBZAFgAZABoAGEAWABRAGcAWQBYAEIAcABLAEMA
>> "%~1" echo YwB2AFkAWABCAHAATAAyAHgAdgBaADMATQBuAEsAVAB0AHoAWgBYAFEAbwBKADIA
>> "%~1" echo eAB2AFoAMQBCAGgAZABHAGcAbgBMAEgASQB1AGIARwA5AG4AUgBtAGwAcwBaAFMA
>> "%~1" echo awA3AGMAMgBWADAASwBDAGQAcwBiADIAZABDAGIAMwBnAG4ATABIAEkAdQBkAEcA
>> "%~1" echo VgA0AGQASAB4ADgASgArAGEAYQBnAHUAYQBYAG8ATwBhAFgAcABlAFcALwBsAHkA
>> "%~1" echo YwBwAE8AMgBsAG0ASwBIAE4AbwBiADMAZABPAGIAMwBSAHAAWQAyAFUAcABiAG0A
>> "%~1" echo OQAwAGEAVwBaADUASwBDAGYAbQBsADYAWABsAHYANQBmAGwAdAA3AEwAbABpAEwA
>> "%~1" echo ZgBtAGwAcgBBAG4ATABIAEkAdQBiAEcAOQBuAFIAbQBsAHMAWgBYAHgAOABKAHkA
>> "%~1" echo MABuAEwAQwBkAHYAYQB5AGMAcABmAFcATgBoAGQARwBOAG8ASwBHAFUAcABlADMA
>> "%~1" echo TgBsAGQAQwBnAG4AYgBHADkAbgBRAG0AOQA0AEoAeQB3AG4ANQBwAGUAbAA1AGIA
>> "%~1" echo KwBYADYASwArADcANQBZACsAVwA1AGEAUwB4ADYATABTAGwANwA3AHkAYQBKAHkA
>> "%~1" echo dABsAEwAbQAxAGwAYwAzAE4AaABaADIAVQBwAE8AMgBsAG0ASwBIAE4AbwBiADMA
>> "%~1" echo ZABPAGIAMwBSAHAAWQAyAFUAcABiAG0AOQAwAGEAVwBaADUASwBDAGYAbQBsADYA
>> "%~1" echo WABsAHYANQBmAG8AcgA3AHYAbABqADUAYgBsAHAATABIAG8AdABLAFUAbgBMAEcA
>> "%~1" echo VQB1AGIAVwBWAHoAYwAyAEYAbgBaAFMAdwBuAFoAWABKAHkASgB5AHcAMABNAGoA
>> "%~1" echo QQB3AEsAWAAxADkARABRAHAAaABjADMAbAB1AFkAeQBCAG0AZABXADUAagBkAEcA
>> "%~1" echo bAB2AGIAaQBCAHkAWgBXAFoAeQBaAFgATgBvAEsASABOAG8AYgAzAGQATwBiADMA
>> "%~1" echo UgBwAFkAMgBVADkAWgBtAEYAcwBjADIAVQBwAGUAMwBSAHkAZQBYAHQAcwBZAFgA
>> "%~1" echo TgAwAFAAVwBGADMAWQBXAGwAMABJAEcARgB3AGEAUwBnAG4ATAAyAEYAdwBhAFMA
>> "%~1" echo OQB6AGQARwBGADAAZABYAE0AbgBLAFQAdABqAGIAMgA1AHoAZABDAEIAagBQAFcA
>> "%~1" echo eABoAGMAMwBRAHUAWQAyADkAdQBiAG0AVgBqAGQARwBWAGsAUABUADAAOQBKADMA
>> "%~1" echo UgB5AGQAVwBVAG4ATwB5AFEAbwBKADMATgAwAFkAWABSADEAYwAwAE4AbwBhAFgA
>> "%~1" echo QQBuAEsAUwA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAZABHADkAbgBaADIA
>> "%~1" echo eABsAEsAQwBkAGoAYgAyADUAdQBaAFcATgAwAFoAVwBRAG4ATABHAE0AcABPAHkA
>> "%~1" echo UQBvAEoAMwBOADAAWQBYAFIAMQBjADAATgBvAGEAWABBAG4ASwBTADUAeABkAFcA
>> "%~1" echo VgB5AGUAVgBOAGwAYgBHAFYAagBkAEcAOQB5AEsAQwBkAHoAYwBHAEYAdQBKAHkA
>> "%~1" echo awB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIAbgBRADkAWQB6ADgAbgA1AGIA
>> "%~1" echo ZQB5ADYATAArAGUANQBvADYAbABKAHoAbwBvAGIARwBGAHoAZABDADUAawBaAFgA
>> "%~1" echo WgBwAFkAMgBWAFQAZABHAEYAMABaAFQAMAA5AFAAUwBkADEAYgBtAEYAMQBkAEcA
>> "%~1" echo aAB2AGMAbQBsADYAWgBXAFEAbgBQAHkAZgBtAG4ASwByAG0AagBvAGoAbQBuAFkA
>> "%~1" echo TQBuAE8AbQB4AGgAYwAzAFEAdQBaAEcAVgAyAGEAVwBOAGwAVQAzAFIAaABkAEcA
>> "%~1" echo VQA5AFAAVAAwAG4AYgAyAFoAbQBiAEcAbAB1AFoAUwBjAC8ASgArAGUAbQB1ACsA
>> "%~1" echo ZQA2AHYAeQBjADYASgArAGEAYwBxAHUAaQAvAG4AdQBhAE8AcABTAGMAcABPADMA
>> "%~1" echo TgBsAGQAQwBnAG4AYwAzAFIAaABkAEcAVgBDAGEAVwBjAG4ATABHAHgAaABjADMA
>> "%~1" echo UQB1AFoARwBWADIAYQBXAE4AbABVADMAUgBoAGQARwBWADgAZgBDAGQAdQBiADIA
>> "%~1" echo NQBsAEoAeQBrADcASgBDAGcAbgBjADMAUgBoAGQARwBWAEMAYQBXAGMAbgBLAFMA
>> "%~1" echo NQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AGQARwA5AG4AWgAyAHgAbABLAEMA
>> "%~1" echo ZABuAGIAMgA5AGsASgB5AHgAagBLAFQAdAB6AFoAWABRAG8ASgAzAE4AMABZAFgA
>> "%~1" echo UgBsAFMARwBsAHUAZABDAGMAcwBiAEcARgB6AGQAQwA1AG8AYQBXADUAMABLAFQA
>> "%~1" echo dAB6AFoAWABRAG8ASgAyAGgAbABjAG0AOQBOAGIAMgBSAGwAYgBDAGMAcwBiAEcA
>> "%~1" echo RgB6AGQAQwA1AHQAYgAyAFIAbABiAEMAWQBtAGIARwBGAHoAZABDADUAdABiADIA
>> "%~1" echo UgBsAGIAQwBFADkAUABTAGMAdABKAHoAOQBzAFkAWABOADAATABtADEAdgBaAEcA
>> "%~1" echo VgBzAE8AaQBkAFIAZABXAFYAegBkAEMAYwBwAE8AMwBOAGwAZABDAGcAbgBaAEcA
>> "%~1" echo VgAyAGEAVwBOAGwAVgBHAEYAbgBKAHkAeABzAFkAWABOADAATABtAFIAbABkAG0A
>> "%~1" echo bABqAFoAVgBOADAAWQBYAFIAbABmAEgAdwBuAGIAbQA5AHUAWgBTAGMAcABPADMA
>> "%~1" echo TgBsAGQAQwBnAG4AWQBXAFIAaQBVADIAaAB2AGMAbgBRAG4ATABIAE4AbwBiADMA
>> "%~1" echo SgAwAFUARwBGADAAYQBDAGgAcwBZAFgATgAwAEwAbQBGAGsAWQBsAEIAaABkAEcA
>> "%~1" echo ZwBwAEsAVAB0AHoAWgBYAFEAbwBKADIARgBrAFkAbABCAGgAZABHAGgAVABhAEcA
>> "%~1" echo OQB5AGQAQwBjAHMAYwAyAGgAdgBjAG4AUgBRAFkAWABSAG8ASwBHAHgAaABjADMA
>> "%~1" echo UQB1AFkAVwBSAGkAVQBHAEYAMABhAEMAawBwAE8AMwBOAGwAZABDAGcAbgBkADIA
>> "%~1" echo bABtAGEAVQBOAG8AYQBYAEEAbgBMAEgAWQBvAEoAMwBkAHAAWgBtAGwASgBjAEMA
>> "%~1" echo YwBwAEsAVAB0AHoAWgBYAFEAbwBKADMAZABwAFoAbQBsAEoAYwBFAHgAcABkAEcA
>> "%~1" echo VQBuAEwASABZAG8ASgAzAGQAcABaAG0AbABKAGMAQwBjAHAASwBUAHQAegBaAFgA
>> "%~1" echo UQBvAEoAMgB4AGwAWgBuAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcA
>> "%~1" echo bAAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGsA
>> "%~1" echo eABsAFoAbgBSAEMAWQBYAFIAMABaAFgASgA1AEoAeQBrAHAATwAzAE4AbABkAEMA
>> "%~1" echo ZwBuAGMAbQBsAG4AYQBIAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBUAEcA
>> "%~1" echo bAAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGwA
>> "%~1" echo SgBwAFoAMgBoADAAUQBtAEYAMABkAEcAVgB5AGUAUwBjAHAASwBUAHQAegBaAFgA
>> "%~1" echo UQBvAEoAMgB4AGwAWgBuAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBVADMA
>> "%~1" echo UgBoAGQARwBVAG4ATABIAFkAbwBKADIATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgA
>> "%~1" echo SgBNAFoAVwBaADAAVQAzAFIAaABkAEgAVgB6AEoAeQBrAHAATwAzAE4AbABkAEMA
>> "%~1" echo ZwBuAGMAbQBsAG4AYQBIAFIARABiADIANQAwAGMAbQA5AHMAYgBHAFYAeQBVADMA
>> "%~1" echo UgBoAGQARwBVAG4ATABIAFkAbwBKADIATgB2AGIAbgBSAHkAYgAyAHgAcwBaAFgA
>> "%~1" echo SgBTAGEAVwBkAG8AZABGAE4AMABZAFgAUgAxAGMAeQBjAHAASwBUAHQAegBaAFgA
>> "%~1" echo UQBvAEoAMwBOAHYAWQAwAHgAcABkAEcAVQBuAEwASABZAG8ASgAzAE4AdgBZAHkA
>> "%~1" echo YwBwAEsAVAB0AHoAWgBYAFEAbwBKADIAUgBwAGMAMwBCAHMAWQBYAGwAVABkAFcA
>> "%~1" echo MQB0AFkAWABKADUAVABHAGwAMABaAFMAYwBzAGQAaQBnAG4AWgBHAGwAegBjAEcA
>> "%~1" echo eABoAGUAVgBOADEAYgBXADEAaABjAG4AawBuAEsAUwBrADcAYwAyAFYAMABLAEMA
>> "%~1" echo ZAAwAGEARwBWAHkAYgBXAEYAcwBVADMAVgB0AGIAVwBGAHkAZQBVAHgAcABkAEcA
>> "%~1" echo VQBuAEwASABZAG8ASgAzAFIAbwBaAFgASgB0AFkAVwB4AFQAZABXADEAdABZAFgA
>> "%~1" echo SgA1AEoAeQBrAHAATwAzAE4AbABkAEMAZwBuAFoAbQBGAGoAZABHADkAeQBlAFYA
>> "%~1" echo TgAxAGIAVwAxAGgAYwBuAGwATQBhAFgAUgBsAEoAeQB4ADIASwBDAGQAbQBZAFcA
>> "%~1" echo TgAwAGIAMwBKADUAVQAzAFYAdABiAFcARgB5AGUAUwBjAHAASwBUAHQAegBaAFgA
>> "%~1" echo UQBvAEoAMgBOAHMAYgAyAE4AcgBWAEcAVgA0AGQAQwBjAHMAYgBtAFYAMwBJAEUA
>> "%~1" echo UgBoAGQARwBVAG8ASwBTADUAMABiADAAeAB2AFkAMgBGAHMAWgBWAFIAcABiAFcA
>> "%~1" echo VgBUAGQASABKAHAAYgBtAGMAbwBLAFMAawA3AFkAMgA5AHUAYwAzAFEAZwBZAGoA
>> "%~1" echo MQAyAEsAQwBkAGkAWQBYAFIAMABaAFgASgA1AFQARwBWADIAWgBXAHcAbgBLAFMA
>> "%~1" echo eAAwAFAAWABZAG8ASgAyAEoAaABkAEgAUgBsAGMAbgBsAFUAWgBXADEAdwBKAHkA
>> "%~1" echo awBzAGQAegAxADIASwBDAGQAMwBZAFcAdABsAFoAbgBWAHMAYgBtAFYAegBjAHkA
>> "%~1" echo YwBwAEwARwBKAHUAUABYAEIAaABjAG4ATgBsAFIAbQB4AHYAWQBYAFEAbwBZAGkA
>> "%~1" echo awBzAGQARwA0ADkAYwBHAEYAeQBjADIAVgBHAGIARwA5AGgAZABDAGgAMABLAFQA
>> "%~1" echo dAB5AGEAVwA1AG4ASwBDAGQAaQBZAFgAUgAwAFoAWABKADUAUgAyAEYAMQBaADIA
>> "%~1" echo VQBuAEwARwBJADkAUABUADAAbgBMAFMAYwAvAEoAeQAwAHQASgBTAGMANgBZAGkA
>> "%~1" echo cwBuAEoAUwBjAHMASgArAGUAVQB0AGUAbQBIAGoAeQBjAHMAYwBHAE4AMABLAEcA
>> "%~1" echo SQBwAEwAQwBGAHAAYwAwAFoAcABiAG0AbAAwAFoAUwBoAGkAYgBpAGsALwBKAHkA
>> "%~1" echo YwA2AFkAbQA0ADgATQBqAEEALwBKADMASgBsAFoAQwBjADYAWQBtADQAOABOAEQA
>> "%~1" echo VQAvAEoAMgBGAHQAWQBtAFYAeQBKAHoAbwBuAFoAMwBKAGwAWgBXADQAbgBLAFQA
>> "%~1" echo dAB5AGEAVwA1AG4ASwBDAGQAMABaAFcAMQB3AFIAMgBGADEAWgAyAFUAbgBMAEgA
>> "%~1" echo UQA5AFAAVAAwAG4ATABTAGMALwBKAHkAMAB0AHcAcgBCAEQASgB6AHAAMABLAHkA
>> "%~1" echo ZgBDAHMARQBNAG4ATABDAGYAbQB1AEsAbgBsAHUAcQBZAG4ATABIAEIAagBkAEMA
>> "%~1" echo aAAwAEwARABVADEASwBTAHcAaABhAFgATgBHAGEAVwA1AHAAZABHAFUAbwBkAEcA
>> "%~1" echo NABwAFAAeQBjAG4ATwBuAFIAdQBQAGoAMAAwAE4AVAA4AG4AYwBtAFYAawBKAHoA
>> "%~1" echo cAAwAGIAagA0ADkATQB6AGcALwBKADIARgB0AFkAbQBWAHkASgB6AG8AbgBaADMA
>> "%~1" echo SgBsAFoAVwA0AG4ASwBUAHQAagBiADIANQB6AGQAQwBCAGgAZAAyAEYAcgBaAFQA
>> "%~1" echo MABvAGQAMwB4ADgASgB5AGMAcABMAG4AUgB2AFQARwA5ADMAWgBYAEoARABZAFgA
>> "%~1" echo TgBsAEsAQwBrAHUAYQBXADUAagBiAEgAVgBrAFoAWABNAG8ASgAyAEYAMwBZAFcA
>> "%~1" echo dABsAEoAeQBrADcAYwBtAGwAdQBaAHkAZwBuAGMAMgB4AGwAWgBYAEIASABZAFgA
>> "%~1" echo VgBuAFoAUwBjAHMAZAB6ADAAOQBQAFMAYwB0AEoAegA4AG4ATABTAGMANgBkAHkA
>> "%~1" echo eABzAFkAWABOADAATABtADEAVABkAEcARgA1AFQAMgA0ADkAUABUADAAbgBkAEgA
>> "%~1" echo SgAxAFoAUwBjAC8ASgArAFMALwBuAGUAYQBNAGcAZQBXAFUAcABPAG0ARwBrAGkA
>> "%~1" echo YwA2AEoAKwBTADgAawBlAGUAYwBvAEMAYwBzAFkAWABkAGgAYQAyAFUALwBNAFQA
>> "%~1" echo QQB3AE8AagBJADQATABHAEYAMwBZAFcAdABsAFAAeQBkAGgAYgBXAEoAbABjAGkA
>> "%~1" echo YwA2AEoAMgBkAHkAWgBXAFYAdQBKAHkAawA3AFQAMgBKAHEAWgBXAE4AMABMAG0A
>> "%~1" echo dABsAGUAWABNAG8AYgBHAEYAegBkAEMAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMA
>> "%~1" echo aAByAFAAVAA1AHoAWgBYAFEAbwBhAHkAeABzAFkAWABOADAAVwAyAHQAZABLAFMA
>> "%~1" echo awA3AGMAMgBWADAASwBDAGQAdwBiADMAZABsAGMAbABOAHYAZABYAEoAagBaAFQA
>> "%~1" echo SQBuAEwARwB4AGgAYwAzAFEAdQBjAEcAOQAzAFoAWABKAFQAYgAzAFYAeQBZADIA
>> "%~1" echo VQBwAE8AMwBOAGwAZABDAGcAbgBiAEcAOQBuAFUARwBGADAAYQBDAGMAcwBiAEcA
>> "%~1" echo RgB6AGQAQwA1AHMAYgAyAGQARwBhAFcAeABsAEsAVAB0AHoAWgBYAFEAbwBKADIA
>> "%~1" echo TgB2AGIAbgBOAHYAYgBHAFYAVABkAEcARgAwAFoAUwBjAHMAYgBHAEYAegBkAEMA
>> "%~1" echo NQBrAFoAWABaAHAAWQAyAFYAVABkAEcARgAwAFoAUwBrADcAYwAyAFYAMABLAEMA
>> "%~1" echo ZABqAGIAMgA1AHoAYgAyAHgAbABRADIAOQB1AGIAaQBjAHMAWQB6ADgAbgA1AGIA
>> "%~1" echo ZQB5ADYATAArAGUANQBvADYAbABKAHoAbwBuADUAcAB5AHEANgBMACsAZQA1AG8A
>> "%~1" echo NgBsAEoAeQBrADcAYwAyAFYAMABLAEMAZABqAGIAMgA1AHoAYgAyAHgAbABRAG0A
>> "%~1" echo RgAwAGQARwBWAHkAZQBTAGMAcwBZAGoAMAA5AFAAUwBjAHQASgB6ADgAbgBMAFMA
>> "%~1" echo YwA2AFkAaQBzAG4ASgBTAGMAcABPADMATgBsAGQAQwBnAG4AWQAyADkAdQBjADIA
>> "%~1" echo OQBzAFoAVgBkAGgAYQAyAFUAbgBMAEgAYwBwAE8AMwBOAGwAZABDAGcAbgBZADIA
>> "%~1" echo OQB1AGMAMgA5AHMAWgBWAGQAcABaAG0AawBuAEwASABZAG8ASgAzAGQAcABaAG0A
>> "%~1" echo bABKAGMAQwBjAHAASwBUAHQAeQBaAFcANQBrAFoAWABKAFEAWQBYAEoAaABiAFgA
>> "%~1" echo TQBvAEsAVAB0AHAAWgBpAGgAegBhAEcAOQAzAFQAbQA5ADAAYQBXAE4AbABLAFcA
>> "%~1" echo NQB2AGQARwBsAG0AZQBTAGcAbgA1AFkAaQAzADUAcABhAHcANQBhADYATQA1AG8A
>> "%~1" echo aQBRAEoAeQB4AGoAUAB5AGYAbAB0ADcATABvAHYANQA3AG0AagBxAFgAdgB2AEoA
>> "%~1" echo bwBuAEsAeQBoAHMAWQBYAE4AMABMAG0AMQB2AFoARwBWAHMAZgBIAHcAbgBVAFgA
>> "%~1" echo VgBsAGMAMwBRAG4ASwBTAHMAbgA3ADcAeQBNADUANQBTADEANgBZAGUAUABJAEMA
>> "%~1" echo YwByAFkAaQBzAG4ASgBTAGMANgBLAEcAeABoAGMAMwBRAHUAYQBHAGwAdQBkAEgA
>> "%~1" echo eAA4AEoAKwBhAGMAcQB1AGkALwBuAHUAYQBPAHAAUwBjAHAATABHAE0ALwBKADIA
>> "%~1" echo OQByAEoAegBvAG4AZAAyAEYAeQBiAGkAYwBwAGYAVwBOAGgAZABHAE4AbwBLAEcA
>> "%~1" echo VQBwAGUAMgB4AHYAWgB5AGcAbgA1AFkAaQAzADUAcABhAHcANQBhAFMAeAA2AEwA
>> "%~1" echo UwBsADcANwB5AGEASgB5AHQAbABMAG0AMQBsAGMAMwBOAGgAWgAyAFUAcABPADMA
>> "%~1" echo SgBsAGIAbQBSAGwAYwBsAEIAaABjAG0ARgB0AGMAeQBnAHAATwAyAGwAbQBLAEgA
>> "%~1" echo TgBvAGIAMwBkAE8AYgAzAFIAcABZADIAVQBwAGIAbQA5ADAAYQBXAFoANQBLAEMA
>> "%~1" echo ZgBsAGkATABmAG0AbAByAEQAbABwAEwASABvAHQASwBVAG4ATABHAFUAdQBiAFcA
>> "%~1" echo VgB6AGMAMgBGAG4AWgBTAHcAbgBaAFgASgB5AEoAeQB3ADAATQBqAEEAdwBLAFgA
>> "%~1" echo MQA5AEQAUQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHoAWgBYAFIAQwBkAFgA
>> "%~1" echo TgA1AEsARwA5AHUATABHAEoAMABiAGkAbAA3AFkAbgBWAHoAZQBUADEAdgBiAGoA
>> "%~1" echo dABrAGIAMgBOADEAYgBXAFYAdQBkAEMANQB4AGQAVwBWAHkAZQBWAE4AbABiAEcA
>> "%~1" echo VgBqAGQARwA5AHkAUQBXAHgAcwBLAEMAZABpAGQAWABSADAAYgAyADQAbgBLAFMA
>> "%~1" echo NQBtAGIAMwBKAEYAWQBXAE4AbwBLAEcASQA5AFAAbQBJAHUAWgBHAGwAegBZAFcA
>> "%~1" echo SgBzAFoAVwBRADkAYgAyADQAcABPADIAbABtAEsARwBKADAAYgBpAGwAaQBkAEcA
>> "%~1" echo NAB1AFkAMgB4AGgAYwAzAE4ATQBhAFgATgAwAEwAbgBSAHYAWgAyAGQAcwBaAFMA
>> "%~1" echo ZwBuAGEAWABNAHQAWQBuAFYAegBlAFMAYwBzAGIAMgA0AHAAZgBRADAASwBZAFgA
>> "%~1" echo TgA1AGIAbQBNAGcAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAWQBXAE4AMABhAFcA
>> "%~1" echo OQB1AEsARwBFAHMAWgBYAGgAMABjAG0ARQA5AEoAeQBjAHMAYgBHAEYAaQBaAFcA
>> "%~1" echo dwA5AEoAKwBhAFQAagBlAFMAOQBuAEMAYwBzAFkAbgBSAHUAUABXADUAMQBiAEcA
>> "%~1" echo dwBzAFkAMgA5AHUAWgBtAGwAeQBiAFcAVgBrAFAAVwBaAGgAYgBIAE4AbABLAFgA
>> "%~1" echo dABwAFoAaQBoAGkAZABYAE4ANQBLAFgASgBsAGQASABWAHkAYgBpAEIAdQBiADMA
>> "%~1" echo UgBwAFoAbgBrAG8ASgArAFcAMwBzAHUAYQBjAGkAZQBhAFQAagBlAFMAOQBuAE8A
>> "%~1" echo YQBKAHAAKwBpAGgAagBPAFMANAByAFMAYwBzAEoAKwBpAHYAdAArAGUAdABpAGUA
>> "%~1" echo VwArAGgAZQBTADQAaQB1AFMANABnAE8AYQBkAG8AZQBXAFIAdgBlAFMANwBwAE8A
>> "%~1" echo VwB1AGoATwBhAEkAawBPAE8AQQBnAGkAYwBzAEoAMwBkAGgAYwBtADQAbgBLAFQA
>> "%~1" echo dAAwAGMAbgBsADcAYwAyAFYAMABRAG4AVgB6AGUAUwBoADAAYwBuAFYAbABMAEcA
>> "%~1" echo SgAwAGIAaQBrADcAYgBHADkAbgBLAEMAZgBtAGkAYQBmAG8AbwBZAHoAawB1AEsA
>> "%~1" echo MwB2AHYASgBvAG4ASwAyAHgAaABZAG0AVgBzAEsAVAB0AHUAYgAzAFIAcABaAG4A
>> "%~1" echo awBvAGIARwBGAGkAWgBXAHcAcwBKACsAYQB0AG8AKwBXAGMAcQBPAFcAUABrAGUA
>> "%~1" echo bQBBAGcAZQBXAFIAdgBlAFMANwBwAEMANAB1AEwAaQBjAHMASgAzAGQAaABjAG0A
>> "%~1" echo NABuAEwARABFADQATQBEAEEAcABPADIAeABsAGQAQwBCADEAYwBtAHcAOQBKAHkA
>> "%~1" echo OQBoAGMARwBrAHYAWQBXAE4AMABhAFcAOQB1AFAAMgBGAGoAZABHAGwAdgBiAGoA
>> "%~1" echo MABuAEsAMgBWAHUAWQAyADkAawBaAFYAVgBTAFMAVQBOAHYAYgBYAEIAdgBiAG0A
>> "%~1" echo VgB1AGQAQwBoAGgASwBTAHQAbABlAEgAUgB5AFkAVAB0AHAAWgBpAGgAagBiADIA
>> "%~1" echo NQBtAGEAWABKAHQAWgBXAFEAcABkAFgASgBzAEsAegAwAG4ASgBtAE4AdgBiAG0A
>> "%~1" echo WgBwAGMAbQAwADkAVwBVAFYAVABKAHoAdABqAGIAMgA1AHoAZABDAEIAeQBQAFcA
>> "%~1" echo RgAzAFkAVwBsADAASQBHAEYAdwBhAFMAaAAxAGMAbQB3AHMAZQAyADEAbABkAEcA
>> "%~1" echo aAB2AFoARABvAG4AVQBFADkAVABWAEMAZAA5AEsAVAB0AHAAWgBpAGgAeQBMAG0A
>> "%~1" echo OQByAEkAVAAwADkASgAzAFIAeQBkAFcAVQBuAEsAWABSAG8AYwBtADkAMwBJAEcA
>> "%~1" echo NQBsAGQAeQBCAEYAYwBuAEoAdgBjAGkAaAB5AEwAbQBWAHkAYwBtADkAeQBmAEgA
>> "%~1" echo dwBuADUAcABPAE4ANQBMADIAYwA1AGEAUwB4ADYATABTAGwASgB5AGsANwBiAEcA
>> "%~1" echo OQBuAEsASABJAHUAYwBtAFYAegBkAFcAeAAwAGYASAB3AG4ANQBhADYATQA1AG8A
>> "%~1" echo aQBRAEoAeQBrADcAYgBtADkAMABhAFcAWgA1AEsARwB4AGgAWQBtAFYAcwBLAHkA
>> "%~1" echo ZgBsAHIAbwB6AG0AaQBKAEEAbgBMAEgASQB1AGMAbQBWAHoAZABXAHgAMABmAEgA
>> "%~1" echo dwBuADUAYQA2AE0ANQBvAGkAUQBKAHkAdwBuAGIAMgBzAG4ASwBUAHQAegBaAFgA
>> "%~1" echo UgBVAGEAVwAxAGwAYgAzAFYAMABLAEMAZwBwAFAAVAA1ADcAYwBtAFYAbQBjAG0A
>> "%~1" echo VgB6AGEAQwBoAG0AWQBXAHgAegBaAFMAawA3AGIARwA5AGgAWgBFAHgAdgBaADMA
>> "%~1" echo TQBvAFoAbQBGAHMAYwAyAFUAcABmAFMAdwAxAE0ARABBAHAAZgBXAE4AaABkAEcA
>> "%~1" echo TgBvAEsARwBVAHAAZQAyAHgAdgBaAHkAZwBuADUAcABPAE4ANQBMADIAYwA1AGEA
>> "%~1" echo UwB4ADYATABTAGwANwA3AHkAYQBKAHkAdABsAEwAbQAxAGwAYwAzAE4AaABaADIA
>> "%~1" echo VQBwAE8AMgA1AHYAZABHAGwAbQBlAFMAaABzAFkAVwBKAGwAYgBDAHMAbgA1AGEA
>> "%~1" echo UwB4ADYATABTAGwASgB5AHgAbABMAG0AMQBsAGMAMwBOAGgAWgAyAFUAcwBKADIA
>> "%~1" echo VgB5AGMAaQBjAHMATgBEAFkAdwBNAEMAawA3AGIARwA5AGgAWgBFAHgAdgBaADMA
>> "%~1" echo TQBvAFoAbQBGAHMAYwAyAFUAcABmAFcAWgBwAGIAbQBGAHMAYgBIAGwANwBjADIA
>> "%~1" echo VgAwAFEAbgBWAHoAZQBTAGgAbQBZAFcAeAB6AFoAUwB4AGkAZABHADQAcABmAFgA
>> "%~1" echo MABOAEMAbQBGAHoAZQBXADUAagBJAEcAWgAxAGIAbQBOADAAYQBXADkAdQBJAEcA
>> "%~1" echo VgA0AGMARwA5AHkAZABFAGgAMABiAFcAdwBvAEsAWAB0AHAAWgBpAGgAaQBkAFgA
>> "%~1" echo TgA1AEsAWABKAGwAZABIAFYAeQBiAGkAQgB1AGIAMwBSAHAAWgBuAGsAbwBKACsA
>> "%~1" echo VwAzAHMAdQBhAGMAaQBlAGEAVABqAGUAUwA5AG4ATwBhAEoAcAArAGkAaABqAE8A
>> "%~1" echo UwA0AHIAUwBjAHMASgArAGkAdgB0ACsAZQB0AGkAZQBXACsAaABlAFMANABpAHUA
>> "%~1" echo UwA0AGcATwBhAGQAbwBlAFcAUgB2AGUAUwA3AHAATwBXAHUAagBPAGEASQBrAE8A
>> "%~1" echo TwBBAGcAaQBjAHMASgAzAGQAaABjAG0ANABuAEsAVAB0AGoAYgAyADUAegBkAEMA
>> "%~1" echo QgBpAGQARwA0ADkASgBDAGcAbgBaAFgAaAB3AGIAMwBKADAAUQBuAFIAdQBKAHkA
>> "%~1" echo awA3AGQASABKADUAZQAzAE4AbABkAEUASgAxAGMAMwBrAG8AZABIAEoAMQBaAFMA
>> "%~1" echo eABpAGQARwA0AHAATwAzAE4AbABkAEMAZwBuAFoAWABoAHcAYgAzAEoAMABVADMA
>> "%~1" echo UgBoAGQASABWAHoASgB5AHcAbgA1AHEAMgBqADUAWgB5AG8ANQBZACsAcQA2AEsA
>> "%~1" echo KwA3ADYAWQBlAEgANgBaAHUARwA1AGEANgBNADUAcABXADAANgBLADYAKwA1AGEA
>> "%~1" echo UwBIADUATAArAGgANQBvAEcAdgA3ADcAeQBNADUAWQArAHYANgBJAE8AOQA2AFoA
>> "%~1" echo eQBBADYASwBhAEIASQBEAEUAdwBMAFQAUQB3AEkATwBlAG4AawBpADQAdQBMAGkA
>> "%~1" echo YwBwAE8AeQBRAG8ASgAyAFYANABjAEcAOQB5AGQARQB4AHAAYgBtAHQAegBKAHkA
>> "%~1" echo awB1AGEAVwA1AHUAWgBYAEoASQBWAEUAMQBNAFAAUwBjAG4ATwAyADUAdgBkAEcA
>> "%~1" echo bABtAGUAUwBnAG4ANQBiAHkAQQA1AGEAZQBMADUAYQArADgANQBZAGUANgBKAHkA
>> "%~1" echo dwBuADUAcQAyAGoANQBaAHkAbwA1ADUAUwBmADUAbwBpAFEANQA2AGUAQgA1AHAA
>> "%~1" echo eQBKADUAYQA2AE0ANQBwAFcAMAA1ADQAbQBJADUAWgBLAE0ANQBZAGkARwA1AEwA
>> "%~1" echo cQByADUAYQA2AEoANQBZAFcAbwA1ADQAbQBJAEkARQBoAFUAVABVAHcAbgBMAEMA
>> "%~1" echo ZAAzAFkAWABKAHUASgB5AHcAeQBNAGoAQQB3AEsAVAB0AGoAYgAyADUAegBkAEMA
>> "%~1" echo QgB5AFAAVwBGADMAWQBXAGwAMABJAEcARgB3AGEAUwBnAG4ATAAyAEYAdwBhAFMA
>> "%~1" echo OQBsAGUASABCAHYAYwBuAFEALwBiAFcAOQBrAFoAVAAxAGkAYgAzAFIAbwBKAHkA
>> "%~1" echo eAA3AGIAVwBWADAAYQBHADkAawBPAGkAZABRAFQAMQBOAFUASgAzADAAcABPADIA
>> "%~1" echo bABtAEsASABJAHUAYgAyAHMAaABQAFQAMABuAGQASABKADEAWgBTAGMAcABkAEcA
>> "%~1" echo aAB5AGIAMwBjAGcAYgBtAFYAMwBJAEUAVgB5AGMAbQA5AHkASwBIAEkAdQBaAFgA
>> "%~1" echo SgB5AGIAMwBKADgAZgBDAGYAbAByADcAegBsAGgANwByAGwAcABMAEgAbwB0AEsA
>> "%~1" echo VQBuAEsAVAB0AHoAWgBYAFEAbwBKADIAVgA0AGMARwA5AHkAZABGAE4AMABZAFgA
>> "%~1" echo UgAxAGMAeQBjAHMASgArAFcAdgB2AE8AVwBIAHUAdQBXAHUAagBPAGEASQBrAE8A
>> "%~1" echo KwA4AG0AaQBjAHIASwBIAEkAdQBjADIAVgBqAGQARwBsAHYAYgBrAE4AdgBkAFcA
>> "%~1" echo NQAwAGYASAB3AG4ATABTAGMAcABLAHkAYwBnADUATABpAHEANgBZAGUASAA2AFoA
>> "%~1" echo dQBHADUAcQA2ADEANwA3AHkATQA2AEkAQwBYADUAcABlADIASQBDAGMAcgBUAFcA
>> "%~1" echo RgAwAGEAQwA1AHkAYgAzAFYAdQBaAEMAZwBvAGMARwBGAHkAYwAyAFYASgBiAG4A
>> "%~1" echo UQBvAGMAaQA1AGsAZABYAEoAaABkAEcAbAB2AGIAawAxAHoAZgBIAHcAbgBNAEMA
>> "%~1" echo YwBzAE0AVABBAHAAZgBIAHcAdwBLAFMAOAB4AE0ARABBAHcASwBTAHMAbgBJAE8A
>> "%~1" echo ZQBuAGsAdQBPAEEAZwBpAGMAcABPAHkAUQBvAEoAMgBWADQAYwBHADkAeQBkAEUA
>> "%~1" echo eABwAGIAbQB0AHoASgB5AGsAdQBhAFcANQB1AFoAWABKAEkAVgBFADEATQBQAFMA
>> "%~1" echo YwA4AFkAUwBCADAAWQBYAEoAbgBaAFgAUQA5AFgAQwBKAGYAWQBtAHgAaABiAG0A
>> "%~1" echo dABjAEkAaQBCAG8AYwBtAFYAbQBQAFYAdwBpAEoAeQB0AGwAYwAyAE0AbwBjAGkA
>> "%~1" echo NQB3AGMAbQBsADIAWQBYAFIAbABWAFgASgBzAEsAUwBzAG4AWABDAEkAKwA1AG8A
>> "%~1" echo bQBUADUAYgB5AEEANQA2AGUAQgA1AHAAeQBKADUAYQA2AE0ANQBwAFcAMAA1ADQA
>> "%~1" echo bQBJAEkARQBoAFUAVABVAHcAOABMADIARQArAFAARwBFAGcAZABHAEYAeQBaADIA
>> "%~1" echo VgAwAFAAVgB3AGkAWAAyAEoAcwBZAFcANQByAFgAQwBJAGcAYQBIAEoAbABaAGoA
>> "%~1" echo MQBjAEkAaQBjAHIAWgBYAE4AagBLAEgASQB1AGMAMgBGAG0AWgBWAFYAeQBiAEMA
>> "%~1" echo awByAEoAMQB3AGkAUAB1AGEASgBrACsAVwA4AGcATwBXAEkAaAB1AFMANgBxACsA
>> "%~1" echo VwB1AGkAZQBXAEYAcQBPAGUASgBpAEMAQgBJAFYARQAxAE0AUABDADkAaABQAGoA
>> "%~1" echo eAB6AGMARwBGAHUAUABpAGMAcgBaAFgATgBqAEsASABJAHUAYwAyAEYAbQBaAFYA
>> "%~1" echo QgBoAGQARwBoADgAZgBDAGMAbgBLAFMAcwBuAFAAQwA5AHoAYwBHAEYAdQBQAGkA
>> "%~1" echo YwA3AGIAbQA5ADAAYQBXAFoANQBLAEMAZgBsAHIANwB6AGwAaAA3AHIAbAByAG8A
>> "%~1" echo egBtAGkASgBBAG4ATABDAGYAbAB0ADcATABuAGwASgAvAG0AaQBKAEQAawB1AEsA
>> "%~1" echo VABrAHUANwAwAGcAUwBGAFIATgBUAEMARABtAGkAcQBYAGwAawBZAG8AbgBMAEMA
>> "%~1" echo ZAB2AGEAeQBjAHAATwAyAHgAdgBZAFcAUgBNAGIAMgBkAHoASwBHAFoAaABiAEgA
>> "%~1" echo TgBsAEsAWAAxAGoAWQBYAFIAagBhAEMAaABsAEsAWAB0AHoAWgBYAFEAbwBKADIA
>> "%~1" echo VgA0AGMARwA5AHkAZABGAE4AMABZAFgAUgAxAGMAeQBjAHMASgArAFcAdgB2AE8A
>> "%~1" echo VwBIAHUAdQBXAGsAcwBlAGkAMABwAGUAKwA4AG0AaQBjAHIAWgBTADUAdABaAFgA
>> "%~1" echo TgB6AFkAVwBkAGwASwBUAHQAdQBiADMAUgBwAFoAbgBrAG8ASgArAFcAdgB2AE8A
>> "%~1" echo VwBIAHUAdQBXAGsAcwBlAGkAMABwAFMAYwBzAFoAUwA1AHQAWgBYAE4AegBZAFcA
>> "%~1" echo ZABsAEwAQwBkAGwAYwBuAEkAbgBMAEQAVQB5AE0ARABBAHAATwAyAHgAdgBZAFcA
>> "%~1" echo UgBNAGIAMgBkAHoASwBHAFoAaABiAEgATgBsAEsAWAAxAG0AYQBXADUAaABiAEcA
>> "%~1" echo eAA1AGUAMwBOAGwAZABFAEoAMQBjADMAawBvAFoAbQBGAHMAYwAyAFUAcwBZAG4A
>> "%~1" echo UgB1AEsAWAAxADkARABRAHAAawBiADIATgAxAGIAVwBWAHUAZABDADUAeABkAFcA
>> "%~1" echo VgB5AGUAVgBOAGwAYgBHAFYAagBkAEcAOQB5AFEAVwB4AHMASwBDAGQAYgBaAEcA
>> "%~1" echo RgAwAFkAUwAxAGgAWQAzAFIAcABiADIANQBkAEoAeQBrAHUAWgBtADkAeQBSAFcA
>> "%~1" echo RgBqAGEAQwBoAGkAUABUADUAaQBMAG0AOQB1AFkAMgB4AHAAWQAyAHMAOQBLAEMA
>> "%~1" echo awA5AFAAbgB0AGoAYgAyADUAegBkAEMAQgBzAFkAVwBKAGwAYgBEADEAaQBMAG4A
>> "%~1" echo RgAxAFoAWABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBJAG8ASgAyAEkAbgBLAFQA
>> "%~1" echo OAB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIAbgBSADgAZgBHAEkAdQBaAEcA
>> "%~1" echo RgAwAFkAWABOAGwAZABDADUAaABZADMAUgBwAGIAMgA0ADcAYQBXAFkAbwBZAGkA
>> "%~1" echo NQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AFkAMgA5AHUAZABHAEYAcABiAG4A
>> "%~1" echo TQBvAEoAMgBSAGgAYgBtAGQAbABjAGsARgBqAGQARwBsAHYAYgBpAGMAcABLAFgA
>> "%~1" echo TgBvAGIAMwBkAEQAYgAyADUAbQBhAFgASgB0AEsARwBJAHUAWgBHAEYAMABZAFgA
>> "%~1" echo TgBsAGQAQwA1AGgAWQAzAFIAcABiADIANABzAGIARwBGAGkAWgBXAHcAcwBKAHkA
>> "%~1" echo YwBwAE8AMgBWAHMAYwAyAFUAZwBZAFcATgAwAGEAVwA5AHUASwBHAEkAdQBaAEcA
>> "%~1" echo RgAwAFkAWABOAGwAZABDADUAaABZADMAUgBwAGIAMgA0AHMASgB5AGMAcwBiAEcA
>> "%~1" echo RgBpAFoAVwB3AHMAWQBpAHgAbQBZAFcAeAB6AFoAUwBsADkASwBUAHMATgBDAGkA
>> "%~1" echo UQBvAEoAMgBOAHYAYgBtAFoAcABjAG0AMQBEAFkAVwA1AGoAWgBXAHcAbgBLAFMA
>> "%~1" echo NQB2AGIAbQBOAHMAYQBXAE4AcgBQAFcATgBzAGIAMwBOAGwAUQAyADkAdQBaAG0A
>> "%~1" echo bAB5AGIAVABzAGsASwBDAGQAagBiADIANQBtAGEAWABKAHQAVAAyAHMAbgBLAFMA
>> "%~1" echo NQB2AGIAbQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAAVAA1ADcAWQAyADkAdQBjADMA
>> "%~1" echo UQBnAGMARAAxAHcAWgBXADUAawBhAFcANQBuAFEAMgA5AHUAWgBtAGwAeQBiAFQA
>> "%~1" echo dABqAGIARwA5AHoAWgBVAE4AdgBiAG0AWgBwAGMAbQAwAG8ASwBUAHQAcABaAGkA
>> "%~1" echo aAB3AEsAVwBGAGoAZABHAGwAdgBiAGkAaAB3AEwAbQBGAGoAZABHAGwAdgBiAGkA
>> "%~1" echo eAB3AEwAbQBWADQAZABIAEoAaABMAEgAQQB1AGIARwBGAGkAWgBXAHcAcwBiAG4A
>> "%~1" echo VgBzAGIAQwB4ADAAYwBuAFYAbABLAFgAMAA3AEQAUQBvAGsASwBDAGQAeQBaAFcA
>> "%~1" echo WgB5AFoAWABOAG8AUQBuAFIAdQBKAHkAawB1AGIAMgA1AGoAYgBHAGwAagBhAHoA
>> "%~1" echo MABvAEsAVAAwACsAZQAyADUAdgBkAEcAbABtAGUAUwBnAG4ANQBZAGkAMwA1AHAA
>> "%~1" echo YQB3ADUANABxADIANQBvAEMAQgBKAHkAdwBuADUAcQAyAGoANQBaAHkAbwA2AEsA
>> "%~1" echo KwA3ADUAWQArAFcASQBGAEYAMQBaAFgATgAwAEkATwBlAEsAdAB1AGEAQQBnAFMA
>> "%~1" echo NAB1AEwAaQBjAHMASgAzAGQAaABjAG0ANABuAEwARABFADIATQBEAEEAcABPADMA
>> "%~1" echo SgBsAFoAbgBKAGwAYwAyAGcAbwBkAEgASgAxAFoAUwBrADcAYgBHADkAaABaAEUA
>> "%~1" echo eAB2AFoAMwBNAG8AWgBtAEYAcwBjADIAVQBwAGYAVABzAE4AQwBpAFEAbwBKADIA
>> "%~1" echo MQBoAGIAbgBWAGgAYgBGAEoAbABaAG4ASgBsAGMAMgBnAG4ASwBTADUAdgBiAG0A
>> "%~1" echo TgBzAGEAVwBOAHIAUABTAGcAcABQAFQANQA3AGIAbQA5ADAAYQBXAFoANQBLAEMA
>> "%~1" echo ZgBsAGkATABmAG0AbAByAEQAbgBpAHIAYgBtAGcASQBFAG4ATABDAGYAbQByAGEA
>> "%~1" echo UABsAG4ASwBqAG8AcgA3AHYAbABqADUAWQBnAFUAWABWAGwAYwAzAFEAZwA1ADQA
>> "%~1" echo cQAyADUAbwBDAEIATABpADQAdQBKAHkAdwBuAGQAMgBGAHkAYgBpAGMAcwBNAFQA
>> "%~1" echo WQB3AE0AQwBrADcAYwBtAFYAbQBjAG0AVgB6AGEAQwBoADAAYwBuAFYAbABLAFQA
>> "%~1" echo dABzAGIAMgBGAGsAVABHADkAbgBjAHkAaABtAFkAVwB4AHoAWgBTAGwAOQBPAHcA
>> "%~1" echo MABLAEoAQwBnAG4AYwBtAFYAbQBjAG0AVgB6AGEARQB4AHYAWgAzAE0AbgBLAFMA
>> "%~1" echo NQB2AGIAbQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAAVAA1AHMAYgAyAEYAawBUAEcA
>> "%~1" echo OQBuAGMAeQBoADAAYwBuAFYAbABLAFQAcwBOAEMAaQBRAG8ASgAyAFYANABjAEcA
>> "%~1" echo OQB5AGQARQBKADAAYgBpAGMAcABMAG0AOQB1AFkAMgB4AHAAWQAyAHMAOQBaAFgA
>> "%~1" echo aAB3AGIAMwBKADAAUwBIAFIAdABiAEQAcwBOAEMAaQBRAG8ASgAzAFIAbwBaAFcA
>> "%~1" echo MQBsAFEAbgBSAHUASgB5AGsAdQBiADIANQBqAGIARwBsAGoAYQB6ADAAbwBLAFQA
>> "%~1" echo MAArAGUAMgB4AHYAWQAyAEYAcwBVADMAUgB2AGMAbQBGAG4AWgBTADUAegBaAFgA
>> "%~1" echo UgBKAGQARwBWAHQASwBIAFIAbwBaAFcAMQBsAFMAMgBWADUATABHAFIAdgBZADMA
>> "%~1" echo VgB0AFoAVwA1ADAATABtAEoAdgBaAEgAawB1AFkAMgB4AGgAYwAzAE4ATQBhAFgA
>> "%~1" echo TgAwAEwAbQBOAHYAYgBuAFIAaABhAFcANQB6AEsAQwBkAGsAWQBYAEoAcgBKAHkA
>> "%~1" echo awAvAEoAMgB4AHAAWgAyAGgAMABKAHoAbwBuAFoARwBGAHkAYQB5AGMAcABPADMA
>> "%~1" echo UgBvAFoAVwAxAGwASwBDAGsANwBiAG0AOQAwAGEAVwBaADUASwBDAGYAawB1AEwA
>> "%~1" echo dgBwAG8AcABqAGwAdAA3AEwAbABpAEkAZgBtAGoAYQBJAG4ATABDAFEAbwBKADMA
>> "%~1" echo UgBvAFoAVwAxAGwAUQBuAFIAdQBKAHkAawB1AGQARwBWADQAZABFAE4AdgBiAG4A
>> "%~1" echo UgBsAGIAbgBRADkAUABUADAAbgA1AHIAVwBGADYASQBtAHkASgB6ADgAbgA1AGIA
>> "%~1" echo MgBUADUAWQBtAE4ANQBMAGkANgA1AHIAZQB4ADYASQBtAHkANQBxAGkAaAA1AGIA
>> "%~1" echo eQBQAEoAegBvAG4ANQBiADIAVAA1AFkAbQBOADUATABpADYANQByAFcARgA2AEkA
>> "%~1" echo bQB5ADUAcQBpAGgANQBiAHkAUABKAHkAdwBuAGIAMgBzAG4ASwBYADAANwBEAFEA
>> "%~1" echo bwBrAEsAQwBkAGoAZABYAE4AMABiADIAMQBUAFoAWABRAG4ASwBTADUAdgBiAG0A
>> "%~1" echo TgBzAGEAVwBOAHIAUABTAGcAcABQAFQANQB6AGEARwA5ADMAUQAyADkAdQBaAG0A
>> "%~1" echo bAB5AGIAUwBnAG4AWQAzAFYAegBkAEcAOQB0AFgAMwBOAGwAZABIAFIAcABiAG0A
>> "%~1" echo YwBuAEwAQwBmAGwAaABwAG4AbABoAGEAVQBnAGMAMgBWADAAZABHAGwAdQBaADMA
>> "%~1" echo TQBuAEwAQwBjAG0AYgBuAE0AOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsA
>> "%~1" echo bABEAGIAMgAxAHcAYgAyADUAbABiAG4AUQBvAEoAQwBnAG4AWQAzAFYAegBkAEcA
>> "%~1" echo OQB0AFQAbgBNAG4ASwBTADUAMgBZAFcAeAAxAFoAUwBrAHIASgB5AFoAcgBaAFgA
>> "%~1" echo awA5AEoAeQB0AGwAYgBtAE4AdgBaAEcAVgBWAFUAawBsAEQAYgAyADEAdwBiADIA
>> "%~1" echo NQBsAGIAbgBRAG8ASgBDAGcAbgBZADMAVgB6AGQARwA5AHQAUwAyAFYANQBKAHkA
>> "%~1" echo awB1AGQAbQBGAHMAZABXAFUAcABLAHkAYwBtAGQAbQBGAHMAZABXAFUAOQBKAHkA
>> "%~1" echo dABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIAMgAxAHcAYgAyADUAbABiAG4A
>> "%~1" echo UQBvAEoAQwBnAG4AWQAzAFYAegBkAEcAOQB0AFYAbQBGAHMAZABXAFUAbgBLAFMA
>> "%~1" echo NQAyAFkAVwB4ADEAWgBTAGsAcABPAHcAMABLAEoAQwBnAG4AWQAzAFYAegBkAEcA
>> "%~1" echo OQB0AFEAbgBKAHYAWQBXAFIAagBZAFgATgAwAEoAeQBrAHUAYgAyADUAagBiAEcA
>> "%~1" echo bABqAGEAegAwAG8ASwBUADAAKwBjADIAaAB2AGQAMABOAHYAYgBtAFoAcABjAG0A
>> "%~1" echo MABvAEoAMgBOADEAYwAzAFIAdgBiAFYAOQBpAGMAbQA5AGgAWgBHAE4AaABjADMA
>> "%~1" echo UQBuAEwAQwBmAGwAagA1AEgAcABnAEkASABsAHUAYgAvAG0AawBxADAAbgBMAEMA
>> "%~1" echo YwBtAGIAbQBGAHQAWgBUADAAbgBLADIAVgB1AFkAMgA5AGsAWgBWAFYAUwBTAFUA
>> "%~1" echo TgB2AGIAWABCAHYAYgBtAFYAdQBkAEMAZwBrAEsAQwBkAGkAYwBtADkAaABaAEcA
>> "%~1" echo TgBoAGMAMwBSAE8AWQBXADEAbABKAHkAawB1AGQAbQBGAHMAZABXAFUAcABLAFQA
>> "%~1" echo cwBOAEMAaQBRAG8ASgAyAGQAdgBRADMAVgB6AGQARwA5AHQAUQBuAEoAdgBZAFcA
>> "%~1" echo UgBqAFkAWABOADAASgB5AGsAdQBiADIANQBqAGIARwBsAGoAYQB6ADAAbwBLAFQA
>> "%~1" echo MAArAGUAMgB4AHYAWQAyAEYAMABhAFcAOQB1AEwAbQBoAGgAYwAyAGcAOQBKADMA
>> "%~1" echo TgBsAGQASABSAHAAYgBtAGQAegBKAHoAdAB1AGIAMwBSAHAAWgBuAGsAbwBKACsA
>> "%~1" echo VwAzAHMAdQBXAEkAaAArAGEATgBvAGkAYwBzAEoAKwBtAHIAbQBPAGUANgBwAHkA
>> "%~1" echo QgB6AFoAWABSADAAYQBXADUAbgBjAHkAYwBzAEoAMgA5AHIASgB5AHcAeABPAEQA
>> "%~1" echo QQB3AEsAWAAwADcARABRAG8AawBLAEMAZABuAGIAMAB4AHYAWgAzAE0AbgBLAFMA
>> "%~1" echo NQB2AGIAbQBOAHMAYQBXAE4AcgBQAFMAZwBwAFAAVAA1ADcAYgBHADkAagBZAFgA
>> "%~1" echo UgBwAGIAMgA0AHUAYQBHAEYAegBhAEQAMABuAGIARwA5AG4AYwB5AGMANwBiAG0A
>> "%~1" echo OQAwAGEAVwBaADUASwBDAGYAbAB0ADcATABsAGkASQBmAG0AagBhAEkAbgBMAEMA
>> "%~1" echo ZgBtAGwANgBYAGwAdgA1AGMAbgBMAEMAZAB2AGEAeQBjAHMATQBUAGcAdwBNAEMA
>> "%~1" echo bAA5AE8AdwAwAEsAWgBuAFYAdQBZADMAUgBwAGIAMgA0AGcAYwBtADkAMQBkAEcA
>> "%~1" echo VQBvAEsAWAB0AGoAYgAyADUAegBkAEMAQgBwAFoARAAwAG8AYgBHADkAagBZAFgA
>> "%~1" echo UgBwAGIAMgA0AHUAYQBHAEYAegBhAEgAeAA4AEoAeQBOAHYAZABtAFYAeQBkAG0A
>> "%~1" echo bABsAGQAeQBjAHAATABuAE4AcwBhAFcATgBsAEsARABFAHAATwAyAFIAdgBZADMA
>> "%~1" echo VgB0AFoAVwA1ADAATABuAEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMA
>> "%~1" echo SgBCAGIARwB3AG8ASgB5ADUAdwBZAFcAZABsAEoAeQBrAHUAWgBtADkAeQBSAFcA
>> "%~1" echo RgBqAGEAQwBoAHcAUABUADUAdwBMAG0ATgBzAFkAWABOAHoAVABHAGwAegBkAEMA
>> "%~1" echo NQAwAGIAMgBkAG4AYgBHAFUAbwBKADIARgBqAGQARwBsADIAWgBTAGMAcwBjAEMA
>> "%~1" echo NQBwAFoARAAwADkAUABXAGwAawBLAFMAawA3AFoARwA5AGoAZABXADEAbABiAG4A
>> "%~1" echo UQB1AGMAWABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBrAEYAcwBiAEMA
>> "%~1" echo ZwBuAEwAbQA1AGgAZABpAEIAaABKAHkAawB1AFoAbQA5AHkAUgBXAEYAagBhAEMA
>> "%~1" echo aABoAFAAVAA1AGgATABtAE4AcwBZAFgATgB6AFQARwBsAHoAZABDADUAMABiADIA
>> "%~1" echo ZABuAGIARwBVAG8ASgAyAEYAagBkAEcAbAAyAFoAUwBjAHMAWQBTADUAbgBaAFgA
>> "%~1" echo UgBCAGQASABSAHkAYQBXAEoAMQBkAEcAVQBvAEoAMgBoAHkAWgBXAFkAbgBLAFQA
>> "%~1" echo MAA5AFAAUwBjAGoASgB5AHQAcABaAEMAawBwAE8AMgBOAHYAYgBuAE4AMABJAEcA
>> "%~1" echo MAA5AGMARwBGAG4AWgBYAE4AYgBhAFcAUgBkAGYASAB4AHcAWQBXAGQAbABjAHkA
>> "%~1" echo NQB2AGQAbQBWAHkAZABtAGwAbABkAHoAdAB6AFoAWABRAG8ASgAzAEIAaABaADIA
>> "%~1" echo VgBVAGEAWABSAHMAWgBTAGMAcwBiAFYAcwB3AFgAUwBrADcAYwAyAFYAMABLAEMA
>> "%~1" echo ZAB3AFkAVwBkAGwAVQAzAFYAaQBKAHkAeAB0AFcAegBGAGQASwBUAHQAcABaAGkA
>> "%~1" echo aABwAFoARAAwADkAUABTAGQAcwBiADIAZAB6AEoAeQBsAHMAYgAyAEYAawBUAEcA
>> "%~1" echo OQBuAGMAeQBoAG0AWQBXAHgAegBaAFMAbAA5AEQAUQBwADAAYQBHAFYAdABaAFMA
>> "%~1" echo ZwBwAE8AMgBGAGsAWgBFAFYAMgBaAFcANQAwAFQARwBsAHoAZABHAFYAdQBaAFgA
>> "%~1" echo SQBvAEoAMgBoAGgAYwAyAGgAagBhAEcARgB1AFoAMgBVAG4ATABIAEoAdgBkAFgA
>> "%~1" echo UgBsAEsAVAB0AHkAYgAzAFYAMABaAFMAZwBwAE8AMwBKAGwAWgBuAEoAbABjADIA
>> "%~1" echo ZwBvAEsAVAB0AHMAYgAyAEYAawBUAEcAOQBuAGMAeQBoAG0AWQBXAHgAegBaAFMA
>> "%~1" echo awA3AGMAMgBWADAAUwBXADUAMABaAFgASgAyAFkAVwB3AG8ASwBDAGsAOQBQAG4A
>> "%~1" echo TgBsAGQAQwBnAG4AWQAyAHgAdgBZADIAdABVAFoAWABoADAASgB5AHgAdQBaAFgA
>> "%~1" echo YwBnAFIARwBGADAAWgBTAGcAcABMAG4AUgB2AFQARwA5AGoAWQBXAHgAbABWAEcA
>> "%~1" echo bAB0AFoAVgBOADAAYwBtAGwAdQBaAHkAZwBwAEsAUwB3AHgATQBEAEEAdwBLAFQA
>> "%~1" echo dAB6AFoAWABSAEoAYgBuAFIAbABjAG4AWgBoAGIAQwBnAG8ASwBUADAAKwBjAG0A
>> "%~1" echo VgBtAGMAbQBWAHoAYQBDAGgAbQBZAFcAeAB6AFoAUwBrAHMATQBUAFUAdwBNAEQA
>> "%~1" echo QQBwAE8AdwAwAEsAUABDADkAegBZADMASgBwAGMASABRACsAUABDADkAaQBiADIA
>> "%~1" echo UgA1AFAAagB3AHYAYQBIAFIAdABiAEQANABOAEMAZwA9AD0AABNbAFsAVABPAEsA
>> "%~1" echo RQBOAF0AXQAAA04AAAAAAI1wV39LKeFFvYu2+zkbYa4ACLd6XFYZNOCJAgYOAgYI
>> "%~1" echo AgYcAwYSCQUAAQEdDgUAAQESDQgAABUSEQIODgoAAhUSEQIODg4OBQACDg4OBgAC
>> "%~1" echo ARIVDgQAAQEOAwAADgcAAg4QDhAOBgADDg4ODgYAAw4OCA4GAAIOCB0OCAAEARIZ
>> "%~1" echo Dg4OBAABDg4KAAIBFRIRAg4ODgYAAhIUDg4JAAUBEhQODggOCgAFARIUDggCHQ4H
>> "%~1" echo AAISEBIUDgUAAQESFAYAAg4SFAIPAAUBEhkOFRIRAg4OAh0OCAADARIZEhQCBwAD
>> "%~1" echo Dg4dDggIAAMSDA4dDggFAAEOHQ4EAAEIDgUAAggODgoAAg4VEhECDg4OBQACDg4C
>> "%~1" echo BgACDg4SFAUAAR0ODgQAAQIOCQABFRIRAg4ODgsAAgESFRUSEQIODggAAwESFQ4d
>> "%~1" echo BQkAAQ4VEhECDg4DIAABAgYCAyAADgMoAA4CBgoHBhUSEQIODgcGFRIdARIQBgYV
>> "%~1" echo Eh0BDgQBAAAABCABAQgEAAEBHAMGEjEEBwESOQQAABIJBQABARIJBAAAEkUFAAES
>> "%~1" echo SQ4GIAIBEkkIBAAAEVEFAAEOHRwGAAMOHBwcBiACAg4RXQUAARJhDgQgABINBSAC
>> "%~1" echo ARwYBgACAhIxHBEHChJNCA4ODhINEjkCHRwdDgQgABJpByACARIVEgkGIAEdDh0D
>> "%~1" echo BCABAQ4FAAICDg4FIAEdBQ4UBwwSFRJtDh0ODg4OEnkOEg0CHQMFAAIOHBwGFRIR
>> "%~1" echo Ag4OByACARMAEwEGIAETARMAFwcJFRIRAg4ODg4ODhUSEQIODgIdDh0DBwAEDg4O
>> "%~1" echo Dg4EAAEBCAUgAQITABgHChUSEQIODg4ODg4OEjkVEhECDg4CHQ4OBwIVEhECDg4V
>> "%~1" echo EhECDg4FAAARgIUEIAEODgYAARKAkQ4HAAMBDg4SCQsAAhGAmRGAhRGAhQMgAA0F
>> "%~1" echo AAASgJ0GIAEOEoClBhUSHQESEAMgAAgFFRIdAQ4FIAAdEwAGAAIODh0OKgcVFRIR
>> "%~1" echo Ag4OEYCFDg4ODhIUDg4ODg4OEYCZEjkVEhECDg4CHQMRgIUKCAUHAg4dDgQgAQ4I
>> "%~1" echo AgYDBSACDgMDBiACCA4RXQQgAQgDBQABHQUOCAcFDg4OEjkCBwcEDg4OHQMFIAEO
>> "%~1" echo HQMJBwQOHQMCEYCFBgACARwQAggHBAIcEYCFAgcgAw4dBQgIDAcIHQUICA4IEjkO
>> "%~1" echo AgkgAh0OHQMRgK0WBxAODg4ODg4ODh0OAg4dDh0OCAIdAwMHAQ4EBwIODgkHBRIM
>> "%~1" echo Dg4CHRwFIAESGQ4JBwQOEhkCEYCFBSABEhkDBAcCDgIHAAIdDg4SCQcgAh0OHQMI
>> "%~1" echo DwcJDg4OHQ4CHQ4IHQMdDgUgAg4ODgUHAw4ODgwABAIOEYC1EoClEA0HIAIODhKA
>> "%~1" echo pQcHBQ4ODQINBSACDggIBSABARMAEQcKDhUSHQEODg4ODg4dDggCEgcMDg4OHQ4O
>> "%~1" echo Dg4dDggCHQMdDgYHBA4ODgIOBwgODg4ODg4VEh0BDgILBwQSFBIUEYCFHQ4EBwEd
>> "%~1" echo DgUAABKAuQMgAAoKBwQSgLkSDBIQAgkgABURgL0BEwAHFRGAvQESEAQgABMAAyAA
>> "%~1" echo Ag4HBBIQEhAVEYC9ARIQAhkHEhUSEQIODg4ODg4ODg4ODg4ODg4NAg0IFAcJFRIR
>> "%~1" echo Ag4ODg4ODhIZDhGAhR0OEQcLDh0ODg4ODh0OCB0DAh0ODwcFEhAOFRGAvQESEAId
>> "%~1" echo DgQgAQgODQcKDg4OCA4IDgIdDggDBhIMAwYSGAMGEmEEIAASbQQgAQECBwABEmES
>> "%~1" echo gMEGIAEBEoDFBCABAggUBwgSgMESgIESgIESHBI5EhgSDAIHBwQSGQgOAgMGESQJ
>> "%~1" echo AAIBEoDREYDVBSABCB0DBCABAg4JBwYODg4dDggCDAcJDg4IDggOHQ4IAggHBg4I
>> "%~1" echo DggOAgoHBw4OCA4dDggCDwcKDg4dDg0OHQ4IAh0DDQwHCA4ODg4dDggCHQMHIAMI
>> "%~1" echo DggRXQYHBAgIDgIKAAMSgN0ODhGA4QUgABKA6QYgARKA5QgGBwISgN0OCQcEEoDd
>> "%~1" echo DgIdAw8HCQ4OHQ4OHQ4IAh0DHQ4GBwQIDg4CDwcJDg4ODg4VEh0BDg4IAgwHBg4O
>> "%~1" echo DhUSHQEODgIOBwgODg4ODhUSHQEODgIPBwgICAgIFRIdAQ4OAh0cBQcDDg4CCQcG
>> "%~1" echo CA4IHQ4IAgoAAxKA8Q4OEYDhAwcBCAYAAQ4SgN0EBhKA+QgAAw4ODhKA+QkABA4O
>> "%~1" echo Dg4RgOEGBwIdDh0DAwcBAgQgAQMIBAABAgMHBwUDAgIOCA0HCQ4IDg4OAh0DHQ4I
>> "%~1" echo ByADAR0FCAgHBwMOHQUdHAsgABURgP0CEwATAQcVEYD9Ag4OCyAAFRGBAQITABMB
>> "%~1" echo BxURgQECDg4EIAATARUHBhIZAhURgQECDg4OFRGA/QIODgIKBwcSGQMODggCCAUg
>> "%~1" echo AQ4dBQMAAAEFAAARgQkFBwERgQkIAQAIAAAAAAAeAQABAFQCFldyYXBOb25FeGNl
>> "%~1" echo cHRpb25UaHJvd3MB5MgCAAAAAAAAAAAA/sgCAAAgAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAPDIAgAAAAAAAAAAAAAAX0NvckV4ZU1haW4AbXNjb3JlZS5kbGwAAAAAAP8l
>> "%~1" echo ACBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAACABAAAAAgAACAGAAAADgAAIAAAAAAAAAAAAAAAAAAAAEA
>> "%~1" echo AQAAAFAAAIAAAAAAAAAAAAAAAAAAAAEAAQAAAGgAAIAAAAAAAAAAAAAAAAAAAAEA
>> "%~1" echo AAAAAIAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAJAAAACg4AIAXAIAAAAAAAAAAAAA
>> "%~1" echo AOMCAOoBAAAAAAAAAAAAAFwCNAAAAFYAUwBfAFYARQBSAFMASQBPAE4AXwBJAE4A
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
>> "%~1" echo AMACAAwAAAAQOQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
