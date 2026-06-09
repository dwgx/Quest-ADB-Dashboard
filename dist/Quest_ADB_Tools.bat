@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title Quest ADB 工具

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
echo 未找到 adb.exe。
echo.
call :print_adb_scan
echo.
call :print_adb_download_links
echo.
exit /b 1

:adb_self_check
echo Quest ADB 工具 - ADB 自检
echo.
set "ADB="
call :find_adb
call :print_adb_scan
echo.
if defined ADB (
  echo 自检结果：已找到可用 adb.exe
  echo   !ADB!
  echo.
  "!ADB!" version
  exit /b 0
)
echo 自检结果：未找到 adb.exe
echo.
call :print_adb_download_links
exit /b 1

:print_adb_scan
echo ADB 工具目录扫描：
if defined ADB_EXE (
  call :print_adb_candidate "环境变量 ADB_EXE" "%ADB_EXE%"
) else (
  echo   [--] 环境变量 ADB_EXE 未设置
)
call :print_adb_candidate "BAT 同目录 adb.exe" "%SCRIPT_DIR%adb.exe"
call :print_adb_candidate "BAT 同目录 platform-tools" "%SCRIPT_DIR%platform-tools\adb.exe"
call :print_adb_candidate "BAT 同目录 tools" "%SCRIPT_DIR%tools\adb.exe"
set "PATH_ADB_FOUND="
for /f "delims=" %%A in ('where adb 2^>nul') do (
  set "PATH_ADB_FOUND=1"
  call :print_adb_candidate "PATH 搜索" "%%A"
)
if not defined PATH_ADB_FOUND echo   [--] PATH 中未找到 adb.exe
call :print_adb_candidate "Android SDK 用户目录" "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
call :print_adb_candidate "Android SDK ProgramFiles" "%ProgramFiles%\Android\platform-tools\adb.exe"
call :print_adb_candidate "Android SDK ProgramFiles x86" "%ProgramFiles(x86)%\Android\platform-tools\adb.exe"
call :print_adb_candidate "SideQuest ProgramFiles" "%ProgramFiles%\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "SideQuest 用户目录" "%LOCALAPPDATA%\Programs\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "Oculus diagnostics" "%ProgramFiles%\Oculus\Support\oculus-diagnostics\adb.exe"
call :print_adb_candidate "Oculus runtime" "%ProgramFiles%\Oculus\Support\oculus-runtime\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub bin" "%ProgramFiles%\Meta Quest Developer Hub\resources\bin\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub 用户目录 bin" "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\bin\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub platform-tools" "%ProgramFiles%\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "Meta Quest Developer Hub 用户目录 platform-tools" "%LOCALAPPDATA%\Programs\Meta Quest Developer Hub\resources\app.asar.unpacked\build\platform-tools\adb.exe"
call :print_adb_candidate "VIVE Business Streaming" "C:\Program Files\VIVE Hub\VIVE Business Streaming\CommonTools\ADB\adb.exe"
call :print_adb_candidate "VIVE Hub" "C:\Program Files\VIVE Hub\VIVE Hub\CommonTools\ADB\adb.exe"
if defined ADB (
  echo.
  echo 当前选用：
  echo   !ADB!
) else (
  echo.
  echo 当前选用：未找到
)
exit /b 0

:print_adb_candidate
set "SCAN_LABEL=%~1"
set "SCAN_PATH=%~2"
if not defined SCAN_PATH (
  echo   [--] !SCAN_LABEL!：未设置
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
echo ADB 下载与回退方式：
echo   1. 官方 Android SDK Platform-Tools 页面：
echo      https://developer.android.com/tools/releases/platform-tools
echo   2. Windows ZIP 直链：
echo      https://dl.google.com/android/repository/platform-tools-latest-windows.zip
echo   3. Meta Quest Developer Hub（也会附带 ADB）：
echo      https://developers.meta.com/horizon/downloads/package/oculus-developer-hub-win/
echo.
echo 安装后任选一种方式：
echo   - 解压 platform-tools 到这个 BAT 同目录，形成 .\platform-tools\adb.exe
echo   - 或把 adb.exe 放到这个 BAT 同目录
echo   - 或设置环境变量 ADB_EXE 为 adb.exe 的完整路径
echo   - 或把 platform-tools 加入 Windows PATH
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
echo 当前没有已授权且在线的 ADB 设备。
echo.
"%ADB%" devices -l
echo.
if defined UNAUTH_DEVICE (
  echo 设备 !UNAUTH_DEVICE! 未授权。请戴上头显，在 USB 调试授权弹窗里选择允许。
) else if defined OFFLINE_DEVICE (
  echo 设备 !OFFLINE_DEVICE! 处于 offline 状态。请按 [S] 重启 ADB，或重插 USB。
) else if defined OTHER_DEVICE (
  echo 设备 !OTHER_DEVICE! 当前状态为 !OTHER_STATE!，不是正常 ADB 设备模式。
) else (
  echo 请插入 Quest，确认已开启开发者模式，并允许 USB 调试。
)
echo.
exit /b 1

:confirm_danger
echo.
echo 风险确认：%~1
echo 这会修改 Quest 或 ADB 状态。输入 YES 继续，直接回车取消。
set "CONFIRM="
set /p "CONFIRM=确认执行: "
if /i "!CONFIRM!"=="YES" exit /b 0
echo 已取消。
exit /b 1

:boot_intro
mode con: cols=100 lines=34 >nul 2>nul
title Quest_ADB_Tools By dwgx1337
if /i "%~1"=="menu-test" (
  call :print_intro_static
  exit /b 0
)
call :intro_animation
echo    按空格进入工具...
call :wait_space
goto :menu

:show_help
mode con: cols=100 lines=34 >nul 2>nul
cls
call :print_red "【重要】如果你进入此帮助页面，表示你已经阅读并知晓本页面中的内容。"
echo.
echo   ========================================================================
echo                         帮助 / 使用说明
echo   ========================================================================
echo.
echo   项目用途：
echo     - 读取 Quest / Meta 头显的 ADB 连接、供电、休眠、电量、手柄线索和常用设置。
echo     - 提供菜单和 WebUI 两种入口；WebUI 更直观，推荐使用。
echo     - 回到主菜单后按 [W] 即可启动 WebUI，只监听 127.0.0.1。
echo.
echo   重要说明：
echo     - 本工具不会绕过授权；必须由用户自己开启开发者模式并允许 USB 调试。
echo     - Quest 无法识别、未授权、掉线、没电、驱动异常、线材异常、网络异常，
echo       通常来自用户设备、电脑环境或连接条件；请先按 [T] 诊断。
echo     - 写入类功能会执行 ADB settings / input / broadcast 等命令。
echo     - 不敢使用时，请先审查这个 BAT 源码，确认命令含义后再操作。
echo.
echo   建议流程：
echo     1. 先按 [T] 诊断连接，再按 [1] 查看状态；确认无误后再写入设置。
echo     2. 推荐按 [W] 使用 WebUI，可查看参数修改列表、日志、通知和单项重置。
echo     3. 短时测试后执行 [P] 安全熄屏或 [6] 保守默认值，避免长时间保活。
echo     4. 想继续提升，请学习 ADB、Android settings、Quest 开发者模式和 USB 驱动。
echo.
echo   WebUI：
echo     - 推荐使用。主菜单按 [W] 启动，浏览器打开 127.0.0.1。
echo     - WebUI 提供状态查看、快捷控制台、日志、通知、参数修改列表和单项重置。
echo.
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
echo    [WEBUI] 推荐进入主菜单后按 W 启动本地 WebUI 控制面板。
echo    [HELP ] 主菜单按 H 查看帮助、说明和风险提示。
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
echo 菜单：
echo   [W] 启动 WebUI 控制面板       [H] 帮助 / 风险提示
echo   [F] ADB 自检 / 扫描目录       [T] 诊断连接 / ADB
echo   [1] 查看只读状态              [R] 查看相关 settings
echo   [S] 重启电脑端 ADB 服务       [M] 每 5 秒监控状态
echo   [P] 安全熄屏                  [6] 恢复保守默认值
echo   [K] 短期保活 / 调试模式       [L] 只读 keepalive 监控
echo   [7] 开启无线 ADB              [8] 关闭无线 ADB
echo   [9] 从备份恢复设置            [Q] 退出
echo.
set "CHOICE="
set /p "CHOICE=请选择："
if not defined CHOICE goto :menu
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
echo 未识别的选项：!CHOICE!
call :pause_back
goto :menu

:pause_back
echo.
echo 按任意键返回主菜单...
pause >nul
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
echo WebUI 控制面板：
echo   按 [W] 启动本地 WebUI，浏览器打开 127.0.0.1 控制面板。
echo   WebUI 可查看参数修改列表、手柄电量、日志、通知和单项重置。
echo.
if defined ADB (
  echo ADB 路径：
  echo   %ADB%
) else (
  echo ADB 路径：
  echo   未找到 adb.exe
)
echo.
call :select_device
call :print_connection_hint
echo.
exit /b 0

:print_connection_hint
if defined DEVICE (
  echo 连接状态：已连接并已授权
  echo 设备信息：!DEVICE_LINE!
  call :get_wifi_ip
  if defined WIFI_IP echo Wi-Fi IP：!WIFI_IP!
  exit /b 0
)
if defined UNAUTH_DEVICE (
  echo 连接状态：发现头显，但尚未授权
  echo 设备序列：!UNAUTH_DEVICE!
  echo 处理提示：戴上头显，在 USB 调试弹窗中选择允许。
  exit /b 0
)
if defined OFFLINE_DEVICE (
  echo 连接状态：发现头显，但 ADB 状态为 offline
  echo 设备序列：!OFFLINE_DEVICE!
  echo 处理提示：按 [S] 重启 ADB 服务；不行就重插 USB 或更换数据线。
  exit /b 0
)
if defined OTHER_DEVICE (
  echo 连接状态：发现设备，但状态异常
  echo 设备序列：!OTHER_DEVICE!
  echo 当前状态：!OTHER_STATE!
  echo 处理提示：重启头显后重新连接 USB。
  exit /b 0
)
echo 连接状态：未发现 ADB 设备
echo 处理提示：检查开发者模式、USB 调试授权、数据线、Windows 驱动，然后按 [T] 诊断。
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
  echo # Quest ADB 工具设置备份
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
echo 备份失败：ADB 读取 settings 不完整，本次不会继续写入危险设置。
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
if not defined _VAL set "_VAL=<空>"
echo   %~1.%~2 = !_VAL!
exit /b 0

:print_prop
set "_VAL="
for /f "delims=" %%V in ('call "%ADB%" -s "!DEVICE!" shell getprop %~1 2^>nul') do set "_VAL=%%V"
if not defined _VAL set "_VAL=<空>"
echo   %~1 = !_VAL!
exit /b 0

:print_power_lines
echo 电源状态：
"%ADB%" -s "!DEVICE!" shell dumpsys power 2>nul | findstr /i /c:"mWakefulness" /c:"mStayOn=" /c:"mProximityPositive" /c:"mStayOnWhilePluggedInSetting" /c:"Sleep timeout"
exit /b 0

:print_battery_lines
echo 电池状态：
"%ADB%" -s "!DEVICE!" shell dumpsys battery 2>nul | findstr /i /c:"level" /c:"temperature" /c:"status" /c:"health" /c:"AC powered" /c:"USB powered" /c:"Wireless powered"
exit /b 0

:print_controller_lines
echo 手柄线索：
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
echo ADB 路径：
echo   %ADB%
echo 当前设备：
echo   !DEVICE_LINE!
echo.
echo 设备属性：
call :print_prop ro.product.model
call :print_prop ro.build.version.release
call :print_prop ro.build.version.sdk
call :print_prop ro.build.version.security_patch
echo.
echo ADB 与网络：
call :print_setting global adb_enabled
call :print_setting global adb_wifi_enabled
call :print_setting global wifi_on
call :print_setting global wifi_sleep_policy
if defined WIFI_IP (echo   wlan0.ip = !WIFI_IP!) else (echo   wlan0.ip = ^<空^>)
echo.
echo 休眠与保活：
call :print_setting global stay_on_while_plugged_in
call :print_setting system screen_off_timeout
call :print_setting secure sleep_timeout
call :print_setting global low_power
echo.
echo 显示：
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
echo 数值说明：
echo   stay_on_while_plugged_in: 0=关闭，1=交流电，2=USB，3=交流电+USB，4=无线，8=底座；数值可以相加。
echo   wifi_sleep_policy: 0=默认，1=旧版插电时不休眠，2=旧版永不休眠。
echo   screen_off_timeout: 单位为毫秒。86400000 = 24 小时。
echo.
exit /b 0

:print_related_full
call :need_device
if errorlevel 1 exit /b 1
echo.
echo === global 相关设置 ===
"%ADB%" -s "!DEVICE!" shell settings list global | findstr /i "stay sleep screen wifi adb development debug power"
echo.
echo === secure 相关设置 ===
"%ADB%" -s "!DEVICE!" shell settings list secure | findstr /i "stay sleep screen wifi adb development debug power prox guardian oculus meta"
echo.
echo === system 相关设置 ===
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
echo Quest ADB 工具 - 连接诊断
echo.
echo ADB 自检：
call :print_adb_scan
echo.
if not defined ADB (
  call :adb_missing
  echo Windows 常见检查项：
  echo   - 使用支持数据传输的 USB 线，不要使用只能充电的线。
  echo   - 优先连接主板 USB 口，先不要接扩展坞或集线器。
  echo   - 安装 Meta Quest Developer Hub、SideQuest 或 Android platform-tools。
  echo   - 在 Meta 手机 App 中为该 Quest 账号开启开发者模式。
  echo.
  exit /b 1
)
echo ADB 路径：
echo   %ADB%
echo.
"%ADB%" version
echo.
echo ADB 服务：
"%ADB%" start-server
echo.
echo ADB 设备列表：
"%ADB%" devices -l
echo.
call :select_device
if defined DEVICE (
  echo 诊断结果：正常。已授权的 ADB 设备在线。
  echo   !DEVICE_LINE!
  echo.
  exit /b 0
)
if defined UNAUTH_DEVICE (
  echo 诊断结果：发现设备，但尚未授权。
  echo 处理方法：戴上头显，在 USB 调试提示里选择允许；如果没有弹窗，重插 USB 或撤销授权后重连。
  exit /b 2
)
if defined OFFLINE_DEVICE (
  echo 诊断结果：发现设备，但状态为 offline。
  echo 处理方法：按 [S] 重启 ADB，重插 USB，或更换数据线/USB 口。
  exit /b 3
)
if defined OTHER_DEVICE (
  echo 诊断结果：发现设备，但当前状态为 !OTHER_STATE!。
  echo 处理方法：请重启头显后重新连接 USB。
  exit /b 4
)
echo 诊断结果：没有发现 ADB 设备。
echo.
echo 最常见原因：
echo   1. Quest 没有开启开发者模式。
echo   2. 头显内没有允许 USB 调试。
echo   3. USB 线只能充电，或连接不稳定。
echo   4. Windows 驱动缺失或异常。
echo   5. 其他 ADB 服务正在冲突。
echo.
where pnputil >nul 2>nul
if not errorlevel 1 (
  echo Windows 已连接设备关键词：
  pnputil /enum-devices /connected | findstr /i "Quest Oculus Meta Android ADB XR MTP WinUSB Google"
)
echo.
exit /b 5

:restart_adb_server
call :need_adb
if errorlevel 1 exit /b 1
echo 正在重启 ADB 服务...
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
echo 正在恢复保守休眠默认值...
"%ADB%" -s "!DEVICE!" shell settings put global stay_on_while_plugged_in 0
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global wifi_sleep_policy 1
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put system screen_off_timeout 300000
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings delete secure sleep_timeout
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell am broadcast -a com.oculus.vrpowermanager.prox_open
echo 已恢复：允许正常休眠、Wi-Fi 保守策略、5 分钟熄屏，并解除 prox_close。
exit /b 0

:safe_sleep_headset
call :restore_sleep_defaults
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell input keyevent KEYCODE_SLEEP
echo 已发送 KEYCODE_SLEEP。
exit /b 0

:apply_keep_awake
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "启用短期保活 / 调试模式：保持唤醒、Wi-Fi 不休眠、屏幕 24 小时、prox_close。结束后请执行安全熄屏。"
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
echo 已应用短期保活 / 调试模式。
exit /b 0

:enable_wireless_adb
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "开启无线 ADB：会让 adbd 监听 5555，仅建议在可信本地网络短时间使用。"
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global adb_wifi_enabled 1
"%ADB%" -s "!DEVICE!" tcpip 5555
echo 已请求开启无线 ADB 5555。
if defined WIFI_IP (
  echo 可尝试：adb connect !WIFI_IP!:5555
) else (
  call :get_wifi_ip
  if defined WIFI_IP echo 可尝试：adb connect !WIFI_IP!:5555
)
exit /b 0

:disable_wireless_adb
call :need_device
if errorlevel 1 exit /b 1
call :confirm_danger "关闭无线 ADB 并切回 USB；如果当前靠无线连接，断开属于正常现象。"
if errorlevel 1 exit /b 1
"%ADB%" -s "!DEVICE!" shell settings put global adb_wifi_enabled 0
"%ADB%" -s "!DEVICE!" usb
echo 已请求关闭无线 ADB，并切回 USB 模式。
exit /b 0

:restore_backup
call :need_device
if errorlevel 1 exit /b 1
call :set_backup_path
if not exist "!BACKUP_FILE!" (
  echo 未找到备份文件：!BACKUP_FILE!
  exit /b 1
)
call :confirm_danger "从备份恢复 settings：!BACKUP_FILE!"
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
echo 已尝试从备份恢复设置，并发送 prox_open。
exit /b 0

:watch_loop
call :need_device
if errorlevel 1 exit /b 1
echo 每 5 秒刷新只读状态。按 Ctrl+C 可退出监控。
:watch_loop_tick
cls
call :print_status
timeout /t 5 /nobreak >nul
goto :watch_loop_tick

:keepalive_loop
call :need_device
if errorlevel 1 exit /b 1
echo 只读 keepalive 监控：每 10 秒执行 adb shell echo keepalive 并读取 power 线索。
echo 按 Ctrl+C 可退出。
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
  echo 无法启动 WebUI：没有找到 Windows certutil.exe，无法从单个 BAT 解包内嵌服务。
  echo 仍然可以使用纯 BAT 菜单。
  exit /b 1
)
set "WEBUI_DIR=%TEMP%\Quest_ADB_Tools_WebUI"
set "WEBUI_STAMP=%RANDOM%%RANDOM%"
set "WEBUI_B64=!WEBUI_DIR!\QuestAdbWebUi_!WEBUI_STAMP!.exe.b64"
set "WEBUI_EXE=!WEBUI_DIR!\QuestAdbWebUi_!WEBUI_STAMP!.exe"
set "WEBUI_ADB=%ADB%"
set "WEBUI_LOG_ROOT=%SCRIPT_DIR%."
if not exist "!WEBUI_DIR!" mkdir "!WEBUI_DIR!" >nul 2>nul
call :write_webui_payload "!WEBUI_B64!"
if errorlevel 1 (
  echo 无法写出 WebUI payload：!WEBUI_B64!
  exit /b 1
)
certutil -f -decode "!WEBUI_B64!" "!WEBUI_EXE!" >nul 2>nul
if errorlevel 1 (
  echo 无法解包 WebUI 服务程序。可能是 certutil 被系统策略或安全软件拦截。
  exit /b 1
)
del /q "!WEBUI_B64!" >nul 2>nul
if not exist "!WEBUI_EXE!" (
  echo WebUI 解包后未找到 EXE：!WEBUI_EXE!
  exit /b 1
)
echo 正在启动 WebUI，只监听 127.0.0.1...
echo 日志目录：%SCRIPT_DIR%Quest_ADB_Logs
start "Quest ADB WebUI" "!WEBUI_EXE!" "!WEBUI_ADB!" "!WEBUI_LOG_ROOT!"
exit /b 0

:write_webui_payload
break > "%~1"
>> "%~1" echo -----BEGIN CERTIFICATE-----
>> "%~1" echo TVqQAAMAAAAEAAAA//8AALgAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAgAAAAA4fug4AtAnNIbgBTM0hVGhpcyBwcm9ncmFtIGNhbm5v
>> "%~1" echo dCBiZSBydW4gaW4gRE9TIG1vZGUuDQ0KJAAAAAAAAABQRQAATAEDADiVJ2oAAAAA
>> "%~1" echo AAAAAOAAAgELAQsAAKgCAAAIAAAAAAAAnscCAAAgAAAA4AIAAABAAAAgAAAAAgAA
>> "%~1" echo BAAAAAAAAAAEAAAAAAAAAAAgAwAAAgAAAAAAAAMAQIUAABAAABAAAAAAEAAAEAAA
>> "%~1" echo AAAAABAAAAAAAAAAAAAAAEzHAgBPAAAAAOACAPAEAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAADAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAIAAACAAAAAAAAAAAAAAACCAAAEgAAAAAAAAAAAAAAC50ZXh0AAAA
>> "%~1" echo pKcCAAAgAAAAqAIAAAIAAAAAAAAAAAAAAAAAACAAAGAucnNyYwAAAPAEAAAA4AIA
>> "%~1" echo AAYAAACqAgAAAAAAAAAAAAAAAABAAABALnJlbG9jAAAMAAAAAAADAAACAAAAsAIA
>> "%~1" echo AAAAAAAAAAAAAAAAQAAAQgAAAAAAAAAAAAAAAAAAAACAxwIAAAAAAEgAAAACAAUA
>> "%~1" echo yIIAAIREAgABAAAAAQAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAABswAgBEAAAAAQAAEQAAAnQDAAABKAIAAAYAAN4xCgAA
>> "%~1" echo AnQDAAABbwYAAAoAAN4FJgAA3gAAcgEAAHAGbwcAAAooCAAACigNAAAGAADeAAAq
>> "%~1" echo ARwAAAAAEwAQIwAFAQAAAQAAAQAQEQAxDgAAARswBABQAgAAAgAAEQAAKAkAAAoo
>> "%~1" echo CgAACgAA3gUmAADeAAACjmkW/gIW/gETBxEHLQgCFpqAAQAABAKOaRcwDCgLAAAK
>> "%~1" echo bwwAAAorAwIXmgAoDAAABgAUCiA9IgAACysvAAByEQAAcCgNAAAKB3MOAAAKCgZv
>> "%~1" echo DwAACgAHgAMAAATeHiYAFAoA3gAAAAcXWAsHIFEiAAD+Ahb+ARMHEQctwAAGFP4B
>> "%~1" echo Fv4BEwcRBy0iAHIlAABwKBAAAAoAcnMAAHAoDQAABgAoEQAACiY4jAEAABqNAQAA
>> "%~1" echo ARMIEQgWcqEAAHCiEQgXfgMAAASMFQAAAaIRCBhyxQAAcKIRCBl+AgAABKIRCCgS
>> "%~1" echo AAAKDHLXAABwCCgIAAAKKBAAAAoAcgUBAHAoEAAACgByQwEAcH4BAAAEKAgAAAoo
>> "%~1" echo EAAACgByTwEAcH4GAAAEKAgAAAooEAAACgByWQEAcH4DAAAEjBUAAAFyhwEAcCgT
>> "%~1" echo AAAKKA0AAAYAckMBAHB+AQAABCgIAAAKKA0AAAYAAByNDwAAARMJEQkWcosBAHCi
>> "%~1" echo EQkXEgMSBCgPAAAGohEJGHKbAQBwohEJGQkoVAAABqIRCRpymwEAcKIRCRsRBKIR
>> "%~1" echo CSgUAAAKKA0AAAYAAN4FJgAA3gAAAAgoFQAACiYA3gUmAADeAAAragAABm8WAAAK
>> "%~1" echo EwV+CQAABC0TFP4GZgAABnMXAAAKgAkAAAQrAH4JAAAEEQUoGAAACiYA3jQTBgBy
>> "%~1" echo nwEAcBEGbwcAAAooCAAACigQAAAKAHKfAQBwEQZvBwAACigIAAAKKA0AAAYAAN4A
>> "%~1" echo AAAXEwcrkSoBQAAAAAABAA8QAAUBAAABAABUACF1AAcBAAABAAB2AVHHAQUBAAAB
>> "%~1" echo AADNAQvYAQUBAAABAADhATMUAjQOAAABGzAEAJgDAAADAAARAAITCQACIBAnAABv
>> "%~1" echo GQAACgACIBAnAABvGgAACgACbxsAAAoKBigJAAAKcxwAAAoLB28dAAAKDAgoHgAA
>> "%~1" echo Chb+ARMKEQotBd1LAwAACBeNGwAAARMLEQsWHyCdEQtvHwAACg0JjmkY/gQW/gET
>> "%~1" echo ChEKLQXdIAMAAAkWmm8gAAAKEwQJF5oTBQAHbx0AAAoTBgARBigeAAAKFv4BEwoR
>> "%~1" echo Ci3mcqEAAHB+AwAABIwVAAABEQUoEwAACnMhAAAKEwcRB28iAAAKcq8BAHAoIwAA
>> "%~1" echo Chb+ARMKEQotOwARB28kAAAKKF0AAAYTChEKLRcABnLHAQBwKFwAAAYoYAAABgDd
>> "%~1" echo lgIAAAYoAwAABihgAAAGAN2FAgAAEQdvIgAACnLZAQBwKCMAAAoW/gETChEKOssA
>> "%~1" echo AAAAEQdvJAAACihdAAAGEwoRCi0XAAZyxwEAcChcAAAGKGAAAAYA3T4CAAARBHLx
>> "%~1" echo AQBwKCUAAAoW/gETChEKLRcABnL7AQBwKFwAAAYoYAAABgDdEgIAABEHbyQAAApy
>> "%~1" echo HwIAcCheAAAGEwgRCChYAAAGLCARB28kAAAKci0CAHAoXgAABnI9AgBwKCUAAAoW
>> "%~1" echo /gErARcAEwoRCi0XAAZyRQIAcChcAAAGKGAAAAYA3bcBAAAGEQgRB28kAAAKKAQA
>> "%~1" echo AAYoYAAABgDdnQEAABEHbyIAAApyXQIAcCgjAAAKFv4BEwoRCi07ABEHbyQAAAoo
>> "%~1" echo XQAABhMKEQotFwAGcscBAHAoXAAABihgAAAGAN1ZAQAABigFAAAGKGAAAAYA3UgB
>> "%~1" echo AAARB28iAAAKcnECAHAoIwAAChb+ARMKEQotZwARB28kAAAKKF0AAAYTChEKLRcA
>> "%~1" echo BnLHAQBwKFwAAAYoYAAABgDdBAEAABEEcvEBAHAoJQAAChb+ARMKEQotFwAGcokC
>> "%~1" echo AHAoXAAABihgAAAGAN3YAAAABigGAAAGKGAAAAYA3ccAAAARB28iAAAKcqkCAHAb
>> "%~1" echo byYAAAoW/gETChEKLUEAEQdvJAAACihdAAAGEwoRCi0eAAZyvQIAcCgJAAAKcscB
>> "%~1" echo AHBvJwAACihhAAAGAN57BhEHbyIAAAooCAAABgDeaxEHbyIAAApy8QIAcCgjAAAK
>> "%~1" echo Fv4BEwoRCi0eAAZyCwMAcCgJAAAKcicDAHBvJwAACihhAAAGAN4zBnLcBABwKAkA
>> "%~1" echo AAooZAAABm8nAAAKKGEAAAYAAN4UEQkU/gETChEKLQgRCW8oAAAKANwAACpBHAAA
>> "%~1" echo AgAAAAQAAAB9AwAAgQMAABQAAAAAAAAAEzAFAH4EAAAEAAARAChbAAAGCgZyDgUA
>> "%~1" echo cHIeBQBwfgMAAASMFQAAASgpAAAKbyoAAAoABnI0BQBwfgEAAARvKgAACgAGckQF
>> "%~1" echo AHB+BgAABG8qAAAKABIBEgIoDwAABg0GclQFAHAJbyoAAAoABnJsBQBwByhUAAAG
>> "%~1" echo byoAAAoABnKCBQBwCG8qAAAKAAZyjAUAcAlyoAUAcCgjAAAKLQdyrgUAcCsFcroF
>> "%~1" echo AHAAbyoAAAoACXKgBQBwKCUAAAoW/gETBhEGLU0AHI0PAAABEwcRBxZyxAUAcKIR
>> "%~1" echo BxcJohEHGHKbAQBwohEHGQcoVAAABqIRBxpymwEAcKIRBxsIohEHKBQAAAooDQAA
>> "%~1" echo BgAGEwU4dQMAAAcXjRsAAAETCBEIFh8gnREIbx8AAAoWmhMEBnLQBQBwEQRvKgAA
>> "%~1" echo CgAGct4FAHARBHLqBQBwKBAAAAZvKgAACgAGcgwGAHARBHIcBgBwKBAAAAZvKgAA
>> "%~1" echo CgAGck4GAHARBHJWBgBwKBAAAAZvKgAACgAGcoAGAHARBHKcBgBwKBAAAAZvKgAA
>> "%~1" echo CgAGctwGAHARBHL2BgBwKBAAAAZvKgAACgAGciYHAHARBHIyBwBwKBAAAAZvKgAA
>> "%~1" echo CgAGclQHAHARBHJsBwBwKBAAAAZvKgAACgAGcowHAHARBHKoBwBwKBAAAAZvKgAA
>> "%~1" echo CgAGcswHAHARBHLYBwBwKBAAAAZvKgAACgAGcvoHAHARBHICCABwKBAAAAYRBHIq
>> "%~1" echo CABwKBAAAAYoLwAABm8qAAAKAAZyRAgAcBEEclQIAHAoEAAABm8qAAAKAAZyfAgA
>> "%~1" echo cBEEcpQIAHAoEAAABm8qAAAKAAZytAgAcBEEctYIAHAoEAAABm8qAAAKAAZyEAkA
>> "%~1" echo cBEEcigJAHAoEAAABm8qAAAKAAZyZgkAcBEEcm4JAHAoEAAABm8qAAAKAAZylAkA
>> "%~1" echo cBEEKCoAAAZvKgAACgAGcqIJAHARBHK4CQBwcsYJAHAoEQAABm8qAAAKAAZy3gkA
>> "%~1" echo cBEEcrgJAHBy7gkAcCgRAAAGbyoAAAoABnIQCgBwEQRyuAkAcHIeCgBwKBEAAAZv
>> "%~1" echo KgAACgAGclAKAHARBHK4CQBwcmQKAHAoEQAABm8qAAAKAAZyiAoAcBEEcpwKAHBy
>> "%~1" echo qgoAcCgRAAAGbyoAAAoABnLQCgBwEQRy6goAcHL4CgBwKBEAAAZvKgAACgAGchQL
>> "%~1" echo AHARBHK4CQBwciYLAHAoEQAABm8qAAAKAAYRBCgaAAAGAAYRBCgbAAAGAAYRBCgc
>> "%~1" echo AAAGAAYRBCgdAAAGAAYRBCgeAAAGAAYRBCgfAAAGAAYRBCggAAAGAAYRBCghAAAG
>> "%~1" echo AB8MjQ8AAAETBxEHFnI6CwBwohEHFwZy3gUAcG8rAAAKohEHGHJUCwBwohEHGQZy
>> "%~1" echo aAsAcG8rAAAKohEHGnKCCwBwohEHGwZykgsAcG8rAAAKohEHHHKqCwBwohEHHQZy
>> "%~1" echo ugsAcG8rAAAKohEHHnLSCwBwohEHHwkGchAKAHBvKwAACqIRBx8KcuQLAHCiEQcf
>> "%~1" echo CwZy3gkAcG8rAAAKohEHKBQAAAooDQAABgAGEwUrABEFKgAAGzAFAPoHAAAFAAAR
>> "%~1" echo AChbAAAGCgZyHwIAcAIoVAAABm8qAAAKACgLAAAGC3L4CwBwAihUAAAGcgQMAHAH
>> "%~1" echo KCwAAAooDQAABgAAAnIWDABwKCMAAAoW/gETCBEILV8AIKAPAAAXjQ8AAAETCREJ
>> "%~1" echo FnIuDABwohEJKBUAAAYmIF4BAAAoLQAACgAgoA8AABeNDwAAARMJEQkWckYMAHCi
>> "%~1" echo EQkoFQAABiYGcmAMAHBybgwAcG8qAAAKAAA4uAYAAAAHcowMAHAoIwAAChb+ARMI
>> "%~1" echo EQgtC3KQDABwcy4AAAp6AnKyDABwKCMAAAoW/gETCBEILTsABygKAAAGACD6AAAA
>> "%~1" echo KC0AAAoAByCsDQAAcsgMAHAoFAAABiYGcmAMAHByAg0AcG8qAAAKAAA4SAYAAAJy
>> "%~1" echo TA0AcCgjAAAKFv4BEwgRCC0fAAcoCQAABgAGcmAMAHByYg0AcG8qAAAKAAA4FQYA
>> "%~1" echo AAJydA0AcCgjAAAKFv4BEwgRCC0fAAcoCQAABgAGcmAMAHByig0AcG8qAAAKAAA4
>> "%~1" echo 4gUAAAJyCg4AcCgjAAAKFv4BEwgRCC0fAAcoCgAABgAGcmAMAHByJg4AcG8qAAAK
>> "%~1" echo AAA4rwUAAAJyTA4AcCgjAAAKFv4BEwgRCC0fAAcoCgAABgAGcmAMAHByZg4AcG8q
>> "%~1" echo AAAKAAA4fAUAAAJyeg4AcCgjAAAKFv4BEwgRCC0fAAcoGAAABgAGcmAMAHBymA4A
>> "%~1" echo cG8qAAAKAAA4SQUAAAJyyA4AcCgjAAAKFv4BEwgRCC0pAAcgrA0AAHLcDgBwKBQA
>> "%~1" echo AAYmBnJgDABwckQPAHBvKgAACgAAOAwFAAACcmIPAHAoIwAAChb+ARMIEQgtKQAH
>> "%~1" echo IKwNAAByeA8AcCgUAAAGJgZyYAwAcHLiDwBwbyoAAAoAADjPBAAAAnICEABwKCMA
>> "%~1" echo AAoW/gETCBEILU0AIIgTAAAajQ8AAAETCREJFnIUEABwohEJFweiEQkYchoQAHCi
>> "%~1" echo EQkZciYQAHCiEQkoFQAABiYGcmAMAHByMBAAcG8qAAAKAAA4bgQAAAJyVBAAcCgj
>> "%~1" echo AAAKFv4BEwgRCC1VAAcgrA0AAHJuEABwKBQAAAYmIIgTAAAZjQ8AAAETCREJFnIU
>> "%~1" echo EABwohEJFweiEQkYcrwQAHCiEQkoFQAABiYGcmAMAHByxBAAcG8qAAAKAAA4BQQA
>> "%~1" echo AAJyIhEAcCgjAAAKFv4BEwgRCC0pAAcgrA0AAHLIDABwKBQAAAYmBnJgDABwcjYR
>> "%~1" echo AHBvKgAACgAAOMgDAAACclwRAHAoIwAAChb+ARMIEQgtKQAHIKwNAABychEAcCgU
>> "%~1" echo AAAGJgZyYAwAcHKuEQBwbyoAAAoAADiLAwAAAnLyEQBwKCMAAAoW/gETCBEILSkA
>> "%~1" echo ByCsDQAAcgYSAHAoFAAABiYGcmAMAHByYhIAcG8qAAAKAAA4TgMAAAJynBIAcCgj
>> "%~1" echo AAAKFv4BEwgRCC0wAAcoFgAABgAHIKwNAAByshIAcCgUAAAGJgZyYAwAcHISEwBw
>> "%~1" echo byoAAAoAADgKAwAAAnJQEwBwKCMAAAoW/gETCBEILSkAByCsDQAAcmITAHAoFAAA
>> "%~1" echo BiYGcmAMAHBywBMAcG8qAAAKAAA4zQIAAAJy/BMAcCgjAAAKFv4BEwgRCC0wAAco
>> "%~1" echo FgAABgAHIKwNAAByFBQAcCgUAAAGJgZyYAwAcHJyFABwbyoAAAoAADiJAgAAAnKu
>> "%~1" echo FABwKCMAAAoW/gETCBEILSkAByCsDQAAcgYSAHAoFAAABiYGcmAMAHBy0BQAcG8q
>> "%~1" echo AAAKAAA4TAIAAAJyEhUAcCgjAAAKFv4BEwgRCC0pAAcgrA0AAHJiEwBwKBQAAAYm
>> "%~1" echo BnJgDABwci4VAHBvKgAACgAAOA8CAAACcnIVAHAoIwAAChb+ARMIEQgtKQAHIKwN
>> "%~1" echo AABylBUAcCgUAAAGJgZyYAwAcHLkFQBwbyoAAAoAADjSAQAAAnIaFgBwKCMAAAoW
>> "%~1" echo /gETCBEILToAByCsDQAAckIWAHAoFAAABiYHIKwNAABy3A4AcCgUAAAGJgZyYAwA
>> "%~1" echo cHKMFgBwbyoAAAoAADiEAQAAAnLOFgBwKCMAAAoW/gETCBEIOvUAAAAAA3LsFgBw
>> "%~1" echo KF4AAAYMA3LyFgBwKF4AAAYNA3L6FgBwKF4AAAYTBAgoVgAABiwICShXAAAGKwEW
>> "%~1" echo ABMIEQgtC3IGFwBwcy4AAAp6CShZAAAGFv4BEwgRCC0LcioXAHBzLgAACnoHKBYA
>> "%~1" echo AAYAByCsDQAAHI0PAAABEwkRCRZyVhcAcKIRCRcIohEJGHKbAQBwohEJGQmiEQka
>> "%~1" echo cpsBAHCiEQkbEQQoWgAABqIRCSgUAAAKKBQAAAYmBnJgDABwG40PAAABEwkRCRYI
>> "%~1" echo ohEJF3JyFwBwohEJGAmiEQkZcnYXAHCiEQkaEQSiEQkoFAAACm8qAAAKAAAreAJy
>> "%~1" echo fhcAcCgjAAAKFv4BEwgRCC1ZAANyoBcAcCheAAAGEwURBShXAAAGEwgRCC0LcqoX
>> "%~1" echo AHBzLgAACnoHIKwNAAByvBcAcBEFKAgAAAooFAAABiYGcmAMAHBy3hcAcBEFKAgA
>> "%~1" echo AApvKgAACgAAKwty7BcAcHMuAAAKegBy+BcAcAIoVAAABnIEGABwBnJgDABwby8A
>> "%~1" echo AAotB3KMDABwKwsGcmAMAHBvKwAACgAoLAAACigNAAAGAADeTBMGAAZyFhgAcHKu
>> "%~1" echo BQBwbyoAAAoABnIcGABwEQZvBwAACm8qAAAKAHIoGABwAihUAAAGcjQYAHARBm8H
>> "%~1" echo AAAKKCwAAAooDQAABgAA3gAABhMHKwARByoAAEEcAAAAAAAAOwAAAGoHAAClBwAA
>> "%~1" echo TAAAAA4AAAETMAMALwAAAAYAABEAKFsAAAYKBnJEBQBwfgYAAARvKgAACgAGckQY
>> "%~1" echo AHAoDgAABm8qAAAKAAYLKwAHKgAbMAQARAIAAAcAABEAKFsAAAYKKDAAAAoLck4Y
>> "%~1" echo AHAoDQAABgAAEgISAygPAAAGEwQRBHKgBQBwKCUAAAoW/gETEBEQLQcJcy4AAAp6
>> "%~1" echo CBeNGwAAARMREREWHyCdERFvHwAAChaaEwURBQgoIgAABhMGKDAAAAoTEhIScnQY
>> "%~1" echo AHAoMQAAChMHfgUAAARylBgAcBEHKDIAAAoTCBEIKDMAAAomcqQYAHARB3LcGABw
>> "%~1" echo KDQAAAoTCXLoGABwEQdy3BgAcCg0AAAKEwoRCBEJKDUAAAoTCxEIEQooNQAAChMM
>> "%~1" echo EQsRBhYoJwAABn4IAAAEKDYAAAoAEQwRBhcoJwAABn4IAAAEKDYAAAoAKDAAAAoH
>> "%~1" echo KDcAAAoTDQZyHBkAcBELbyoAAAoABnI0GQBwEQxvKgAACgAGckYZAHARBxEJKAcA
>> "%~1" echo AAZvKgAACgAGclwZAHARBxEKKAcAAAZvKgAACgAGcmwZAHASDSg4AAAKahMTEhMo
>> "%~1" echo OQAACig6AAAKbyoAAAoABnKCGQBwEQZ7GgAABG87AAAKExQSFCg5AAAKKDwAAApv
>> "%~1" echo KgAACgAGcpwZAHARBnsbAAAEbz0AAAosGHKuGQBwEQZ7GwAABG8+AAAKKD8AAAor
>> "%~1" echo BXKMDABwAG8qAAAKAAZyYAwAcHK2GQBwbyoAAAoAcuAZAHARC3LsGQBwEQwoLAAA
>> "%~1" echo CigNAAAGAADeQRMOAAZyFhgAcHKuBQBwbyoAAAoABnIcGABwEQ5vBwAACm8qAAAK
>> "%~1" echo AHL0GQBwEQ5vBwAACigIAAAKKA0AAAYAAN4AAAYTDysAEQ8qQRwAAAAAAAAYAAAA
>> "%~1" echo 4gEAAPoBAABBAAAADgAAARMwAwBKAAAACAAAEQAcjQ8AAAELBxZyqQIAcKIHFwIo
>> "%~1" echo QAAACqIHGHKHAQBwogcZAyhAAAAKogcacgAaAHCiBxt+AgAABChAAAAKogcoFAAA
>> "%~1" echo CgorAAYqAAAbMAUAEgEAAAkAABEAAANyqQIAcG9BAAAKb0IAAAooQwAACh8vfkQA
>> "%~1" echo AApvRQAACgoGchAaAHAab0YAAAoWLxkGHzpvRwAAChYvDgZy3BgAcBtvSAAACisB
>> "%~1" echo FgATBBEELSEAAnK9AgBwKAkAAApyFhoAcG8nAAAKKGEAAAYA3ZsAAAB+BQAABHKU
>> "%~1" echo GABwKDUAAAooSQAACgsHBig1AAAKKEkAAAoMCAcbbyYAAAosCAgoSgAACisBFgAT
>> "%~1" echo BBEELR4AAnK9AgBwKAkAAApyJBoAcG8nAAAKKGEAAAYA3kECctwEAHAIKEsAAAoo
>> "%~1" echo YQAABgAA3isNAAJyvQIAcCgJAAAKcjAaAHAJbwcAAAooCAAACm8nAAAKKGEAAAYA
>> "%~1" echo AN4AAAAqAAABEAAAAAABAOPkACsOAAABAzADAF4AAAAAAAAAAAIoFgAABgACIKwN
>> "%~1" echo AAByFBQAcCgUAAAGJgIgrA0AAHJAGgBwKBQAAAYmAiCsDQAAcrISAHAoFAAABiYC
>> "%~1" echo IKwNAABykBoAcCgUAAAGJgIgrA0AAHJ4DwBwKBQAAAYmKgAAAzADAFcAAAAAAAAA
>> "%~1" echo AAIgrA0AAHJiEwBwKBQAAAYmAiCsDQAAcpQVAHAoFAAABiYCIKwNAAByBhIAcCgU
>> "%~1" echo AAAGJgIgrA0AAHJCFgBwKBQAAAYmAiCsDQAActwOAHAoFAAABiYqABMwBAA4AAAA
>> "%~1" echo CgAAEQASABIBKA8AAAZyoAUAcCgjAAAKLQdyjAwAcCsVBheNGwAAAQ0JFh8gnQlv
>> "%~1" echo HwAAChaaAAwrAAgqGzAEAOIAAAALAAARAAACKB4AAAotAwIrCigLAAAKbwwAAAoA
>> "%~1" echo CgYXjRsAAAELBxYfIp0Hb0wAAAoKBihJAAAKCgYoTQAACgwILQcGKDMAAAomBoAE
>> "%~1" echo AAAEBnLaGgBwKDUAAAqABQAABH4FAAAEKDMAAAomfgUAAARy+BoAcCgwAAAKDRID
>> "%~1" echo cnQYAHAoMQAACnIGGwBwKDQAAAooNQAACoAGAAAEfgYAAARyEBsAcH4IAAAEKE4A
>> "%~1" echo AAoAAN4yJgAoCwAACm8MAAAKgAQAAAR+BAAABIAFAAAEfgUAAARyEhsAcCg1AAAK
>> "%~1" echo gAYAAAQA3gAAKgAAARAAAAAAAQCtrgAyAQAAARswBQBkAAAADAAAEQAAFgp+BwAA
>> "%~1" echo BCULEgAoTwAACgAAfgYAAAQoMAAACgwSAnI6GwBwKDEAAApyahsAcAIoUAAACigs
>> "%~1" echo AAAKfggAAAQoTgAACgAA3hAGFv4BDQktBwcoUQAACgDcAADeBSYAAN4AACoBHAAA
>> "%~1" echo AgAEAEVJABAAAAAAAAABAFxdAAUBAAABGzAFAKwAAAANAAARAAB+BgAABCgeAAAK
>> "%~1" echo LQx+BgAABChKAAAKKwEWABMHEQctCXJwGwBwEwbefX4GAAAEKEsAAAoKIFBGAAAL
>> "%~1" echo Bo5pBzADFisFBo5pB1kADCgJAAAKBggGjmkIWW9SAAAKDQkfCm9HAAAKEwQIFjEH
>> "%~1" echo EQQW/gQrARcAEwcRBy0LCREEF1hvQgAACg0JKFQAAAYTBt4YEwUAcoQbAHARBW8H
>> "%~1" echo AAAKKAgAAAoTBt4AABEGKgEQAAAAAAEAj5AAGA4AAAETMAQAFgMAAA4AABEAAnIQ
>> "%~1" echo GwBwUQNylBsAcFFyEBsAcApyEBsAcAtyEBsAcAxyEBsAcA1yEBsAcBMEchAbAHAT
>> "%~1" echo BQAguAsAABiNDwAAARMLEQsWcu4bAHCiEQsXcv4bAHCiEQsoEwAABihVAAAGEwwW
>> "%~1" echo Ew04lwEAABEMEQ2aEwYAEQZvUwAAChMHEQdvQQAACiwSEQdyBBwAcBtvJgAAChb+
>> "%~1" echo ASsBFgATDhEOLQU4WAEAABEHGI0bAAABEw8RDxYfIJ0RDxcfCZ0RDxdvVAAAChMI
>> "%~1" echo EQiOaRj+BBb+ARMOEQ4tBTgjAQAAEQgXmnKgBQBwKCMAAAoW/gETDhEOOp0AAAAA
>> "%~1" echo CW9BAAAKFv4BFv4BEw4RDi0DEQcNEQdyFBwAcBtvRgAAChYvJREHciwcAHAbb0YA
>> "%~1" echo AAoWLxURB3JKHABwG29GAAAKFv4EFv4BKwEXABMJEQksDxEEb0EAAAoW/gEW/gEr
>> "%~1" echo ARcAEw4RDi0EEQcTBBEJLB0RCBaaHzpvRwAAChYvDxEFb0EAAAoW/gEW/gErARcA
>> "%~1" echo Ew4RDi0EEQcTBStsEQgXmnJmHABwKCMAAAosDgZvQQAAChb+ARb+ASsBFwATDhEO
>> "%~1" echo LQURBworQBEIF5pygBwAcCgjAAAKLA4Hb0EAAAoW/gEW/gErARcAEw4RDi0FEQcL
>> "%~1" echo KxUIb0EAAAoW/gEW/gETDhEOLQMRBwwAEQ0XWBMNEQ0RDI5p/gQTDhEOOlj+//8R
>> "%~1" echo BW9BAAAKFv4CFv4BEw4RDi0YAAIRBVEDcpAcAHBRcqAFAHATCjjVAAAAEQRvQQAA
>> "%~1" echo Chb+Ahb+ARMOEQ4tGAACEQRRA3LCHABwUXKgBQBwEwo4qgAAAAlvQQAAChb+Ahb+
>> "%~1" echo ARMOEQ4tFwACCVEDcugcAHBRcqAFAHATCjiBAAAABm9BAAAKFv4CFv4BEw4RDi0U
>> "%~1" echo AAIGUQNyOB0AcFFyZhwAcBMKK1sHb0EAAAoW/gIW/gETDhEOLRQAAgdRA3J0HQBw
>> "%~1" echo UXKAHABwEworNQhvQQAAChb+Ahb+ARMOEQ4tGgACCFEDcrAdAHAIKAgAAApRcsYd
>> "%~1" echo AHATCisJctYdAHATCisAEQoqAAATMAQAIQAAAA8AABEAAiDECQAAcuAdAHADKAgA
>> "%~1" echo AAooEgAABihUAAAGCisABioAAAATMAYAPgAAABAAABEAAiDECQAAcvIdAHADcpsB
>> "%~1" echo AHAEKCwAAAooEgAABihUAAAGCgZyDh4AcCgjAAAKLQMGKwVyDh4AcAALKwAHKgAA
>> "%~1" echo EzAEADEAAAAIAAARAAMajQ8AAAELBxZyFBAAcKIHFwKiBxhyGB4AcKIHGQSiBygT
>> "%~1" echo AAAGKFQAAAYKKwAGKgAAABMwAwASAAAADwAAEQB+AQAABAMCKCsAAAYKKwAGKgAA
>> "%~1" echo EzAEADEAAAAIAAARAAMajQ8AAAELBxZyFBAAcKIHFwKiBxhyGB4AcKIHGQSiBygV
>> "%~1" echo AAAGKFQAAAYKKwAGKgAAABMwAwCLAAAAEQAAEQB+AQAABAMCKCwAAAYKBm9pAAAG
>> "%~1" echo KFQAAAYLBnsOAAAEFv4BDQktFnIkHgBwAygtAAAGKAgAAApzLgAACnoGew0AAAQW
>> "%~1" echo /gENCS07Go0BAAABEwQRBBZyOB4AcKIRBBcGew0AAASMFQAAAaIRBBhyTB4AcKIR
>> "%~1" echo BBkHohEEKBIAAApzLgAACnoHDCsACCoAEzAEAM0AAAASAAARAAIoGQAABgoGKEoA
>> "%~1" echo AAoW/gEMCC0FOLIAAABzVQAACgsHclIeAHBvVgAACiYHcngeAHACKAgAAApvVgAA
>> "%~1" echo CiYHcoweAHAoMAAACg0SA3KiHgBwKDEAAAooCAAACm9WAAAKJgcCcrgJAHByHgoA
>> "%~1" echo cCgXAAAGAAcCcrgJAHByZAoAcCgXAAAGAAcCcpwKAHByqgoAcCgXAAAGAAcCcuoK
>> "%~1" echo AHBy+AoAcCgXAAAGAAYHb1cAAAp+CAAABCg2AAAKAHLKHgBwBigIAAAKKA0AAAYA
>> "%~1" echo KgAAABMwBgBqAAAAEwAAEQADIKwNAABy8h0AcARymwEAcAUoLAAACigUAAAGCgZy
>> "%~1" echo jAwAcCgjAAAKFv4BCwctF3LcHgBwBHJyFwBwBSgsAAAKcy4AAAp6AgRvWAAACh8g
>> "%~1" echo b1kAAAoFb1gAAAofIG9ZAAAKBm9WAAAKJioAABMwBwByAQAAFAAAEQACKBkAAAYK
>> "%~1" echo BihKAAAKEwQRBC0Rcu4eAHAGKAgAAApzLgAACnoABigJAAAKKFoAAAoTBRYTBjgD
>> "%~1" echo AQAAEQURBpoLAAdvUwAACgwIb0EAAAosEQhyAh8AcBpvJgAAChb+ASsBFgATBBEE
>> "%~1" echo LQU4yQAAAAgXjRsAAAETBxEHFh8gnREHGW9bAAAKDQmOaRkyFAkWmihWAAAGLAoJ
>> "%~1" echo F5ooVwAABisBFgATBBEELQU4igAAAAkYmnIOHgBwKCMAAAoW/gETBBEELSMCIKwN
>> "%~1" echo AAByBh8AcAkWmnKbAQBwCReaKCwAAAooFAAABiYrUAIgrA0AAByNDwAAARMIEQgW
>> "%~1" echo clYXAHCiEQgXCRaaohEIGHKbAQBwohEIGQkXmqIRCBpymwEAcKIRCBsJGJooWgAA
>> "%~1" echo BqIRCCgUAAAKKBQAAAYmABEGF1gTBhEGEQWOaf4EEwQRBDrs/v//AiCsDQAActwO
>> "%~1" echo AHAoFAAABiZyKB8AcAYoCAAACigNAAAGACoAABMwBACEAAAAFQAAEQACJS0GJnKg
>> "%~1" echo BQBwCgZyOB8AcHI8HwBwb1wAAApychcAcHI8HwBwb1wAAApyQB8AcHI8HwBwb1wA
>> "%~1" echo AApyhwEAcHI8HwBwb1wAAAoKfgQAAAQoHgAACi0HfgQAAAQrCigLAAAKbwwAAAoA
>> "%~1" echo CwdyRB8AcAZybB8AcCg0AAAKKDUAAAoMKwAIKhMwBADXAAAAFgAAEQADIMQJAABy
>> "%~1" echo dh8AcCgSAAAGCgJyaAsAcAZylh8AcCgzAAAGbyoAAAoABnKiHwBwKDMAAAYLByD/
>> "%~1" echo AQAAKDkAAAoSAihdAAAKLBEIIwAAAAAAAFlA/gIW/gErARcADQktHwgjAAAAAAAA
>> "%~1" echo JEBbEwQSBHK6HwBwKDkAAAooXgAACgsCcpILAHAHbyoAAAoAAnLCHwBwBnLeHwBw
>> "%~1" echo KDMAAAYoMAAABm8qAAAKAAJy7B8AcAZyCCAAcCgzAAAGKDEAAAZvKgAACgACchYg
>> "%~1" echo AHAGKDIAAAZvKgAACgAqABMwBACGAAAADwAAEQADIIgTAAByLiAAcCgSAAAGCgJy
>> "%~1" echo ugsAcAZySiAAcCg0AAAGbyoAAAoAAnJkIABwBnJkIABwKDQAAAZvKgAACgACcnQg
>> "%~1" echo AHAGcnQgAHAoNAAABm8qAAAKAAJymiAAcAZyuCAAcCg0AAAGbyoAAAoAAnLyIABw
>> "%~1" echo BnIQIQBwKDUAAAZvKgAACgAqAAATMAQAtgEAABcAABEAAnIuIQBwcowMAHBvKgAA
>> "%~1" echo CgACclohAHByjAwAcG8qAAAKAAJyiCEAcHKMDABwbyoAAAoAAnKyIQBwcowMAHBv
>> "%~1" echo KgAACgACct4hAHBy/CEAcG8qAAAKAAMgiBMAAHIQIgBwKBIAAAYKc18AAAoLAAYo
>> "%~1" echo VQAABhMHFhMIOPgAAAARBxEImgwACG9TAAAKDQlyQiIAcBtvRgAAChYyFAlyVCIA
>> "%~1" echo cBtvRgAAChb+BBb+ASsBFgATCREJLQU4tAAAAAlyYCIAcCg2AAAGEwQJcmoiAHAo
>> "%~1" echo NgAABhMFCXJ6IgBwKDYAAAYTBhEEcogiAHAbb2AAAAoW/gETCREJLR4AAnIuIQBw
>> "%~1" echo EQVvKgAACgACcoghAHARBm8qAAAKAAARBHKSIgBwG29gAAAKFv4BEwkRCS0eAAJy
>> "%~1" echo WiEAcBEFbyoAAAoAAnKyIQBwEQZvKgAACgAABwlvQQAACiCMAAAAMAMJKwwJFiCM
>> "%~1" echo AAAAb2EAAAoAb2IAAAoAABEIF1gTCBEIEQeOaf4EEwkRCTr3/v//B289AAAKFv4C
>> "%~1" echo Fv4BEwkRCS0cAnLeIQBwcq4ZAHAHbz4AAAooPwAACm8qAAAKACoAABMwBgByAQAA
>> "%~1" echo GAAAEQACcp4iAHByjAwAcG8qAAAKAAJyriIAcHKMDABwbyoAAAoAAyCsDQAAcrwi
>> "%~1" echo AHAoEgAABgoABihVAAAGEwcWEwg4pwAAABEHEQiaCwAHb1MAAAoMCG9BAAAKLBEI
>> "%~1" echo ctgiAHAbbyYAAAoW/gErARYAEwkRCS0CK3AIGI0bAAABEwoRChYfIJ0RChcfCZ0R
>> "%~1" echo ChdvVAAACg0Jjmkb/gQTCREJLUUAAnKeIgBwG40PAAABEwsRCxYJGJqiEQsXcuwZ
>> "%~1" echo AHCiEQsYCReaohELGXLuIgBwohELGgkamqIRCygUAAAKbyoAAAoAKxgAEQgXWBMI
>> "%~1" echo EQgRB45p/gQTCREJOkj///8DIKwNAABy+CIAcCgSAAAGEwQRBHIcIwBwKDgAAAYT
>> "%~1" echo BREEcjAjAHAoOAAABhMGEQVyjAwAcCglAAAKLBERBnKMDABwKCUAAAoW/gErARcA
>> "%~1" echo EwkRCS0fAnKuIgBwckwjAHARBnJUIwBwEQUoLAAACm8qAAAKACoAABMwBACcAAAA
>> "%~1" echo GQAAEQACcmIjAHByjAwAcG8qAAAKAAJydiMAcHKMDABwbyoAAAoAcoojAHAKAyCI
>> "%~1" echo EwAAcrgjAHAGKAgAAAooEgAABgsHctojAHAGcu4jAHAoNAAAChtvRgAAChb+BBb+
>> "%~1" echo AQ0JLQIrOAJyYiMAcAZvKgAACgAHcvIjAHAoNwAABgwIcowMAHAoJQAAChb+AQ0J
>> "%~1" echo LQ0CcnYjAHAIbyoAAAoAKhMwBABQAQAAGgAAEQACcgwkAHByjAwAcG8qAAAKAAMg
>> "%~1" echo iBMAAHIqJABwKBIAAAYKBnJKJABwKDUAAAYLB3KMDABwKCMAAAoW/gETBxEHLQU4
>> "%~1" echo BwEAAAdybiQAcCg8AAAGDAdyniQAcCg8AAAGDQdy1iQAcCg8AAAGEwQHcvwkAHBy
>> "%~1" echo LCUAcCg7AAAGEwVzXwAAChMGCHKMDABwKCUAAAoW/gETBxEHLRgRBghymwEAcHIQ
>> "%~1" echo GwBwb1wAAApvYgAACgAJcowMAHAoJQAAChb+ARMHEQctExEGCXIwJQBwKAgAAApv
>> "%~1" echo YgAACgARBHKMDABwKCUAAAoW/gETBxEHLRQRBnI2JQBwEQQoCAAACm9iAAAKABEF
>> "%~1" echo cowMAHAoJQAAChb+ARMHEQctChEGEQVvYgAACgACcgwkAHARBm89AAAKLBNy7BkA
>> "%~1" echo cBEGbz4AAAooPwAACisFcowMAHAAbyoAAAoAKhMwBwC5AAAAGQAAEQACckglAHBy
>> "%~1" echo jAwAcG8qAAAKAAMgiBMAAHJmJQBwKBIAAAYKBnKUJQBwKDMAAAYLBnKyJQBwKD0A
>> "%~1" echo AAYMCHKMDABwKCMAAAoW/gENCS0MBnL2JQBwKD0AAAYMB3KMDABwKCUAAAotEAhy
>> "%~1" echo jAwAcCglAAAKFv4BKwEWAA0JLTwCckglAHByNCYAcAcIcowMAHAoJQAACi0HchAb
>> "%~1" echo AHArEHJEJgBwCHJcJgBwKDQAAAoAKDQAAApvKgAACgAqAAAAEzAEAEoBAAAaAAAR
>> "%~1" echo AAJyYCYAcHKMDABwbyoAAAoAAyBwFwAAcn4mAHAoEgAABgoGcqomAHAoPgAABgsG
>> "%~1" echo cr4mAHAoPgAABgwGctQmAHAoPgAABg0GcugmAHAoPgAABhMEBnIAJwBwKD4AAAYT
>> "%~1" echo BXNfAAAKEwYIcowMAHAoJQAAChb+ARMHEQctCREGCG9iAAAKAAdyjAwAcCglAAAK
>> "%~1" echo Fv4BEwcRBy0JEQYHb2IAAAoACXKMDABwKCUAAAoW/gETBxEHLRMRBnIWJwBwCSgI
>> "%~1" echo AAAKb2IAAAoAEQRyjAwAcCglAAAKFv4BEwcRBy0UEQZyKCcAcBEEKAgAAApvYgAA
>> "%~1" echo CgARBXKMDABwKCUAAAoW/gETBxEHLRQRBnIyJwBwEQUoCAAACm9iAAAKAAJyYCYA
>> "%~1" echo cBEGbz0AAAosE3LsGQBwEQZvPgAACig/AAAKKwVyjAwAcABvKgAACgAqAAATMAcA
>> "%~1" echo 6AIAABsAABEAc20AAAYKBigwAAAKDBICcqIeAHAoMQAACn0WAAAEBgJ9FwAABAYD
>> "%~1" echo fRgAAAQGckQnAHAgoA8AABYYjQ8AAAENCRZy7hsAcKIJF3L+GwBwogkoJAAABgAG
>> "%~1" echo clwnAHACILgLAAByXCcAcCgjAAAGAAZyYicAcAIgcBcAAHJiJwBwKCMAAAYABnJy
>> "%~1" echo JwBwAiBwFwAAcpInAHAoIwAABgAGcrwnAHACIHAXAABy3CcAcCgjAAAGAAZyBigA
>> "%~1" echo cAIgcBcAAHImKABwKCMAAAYABnJQKABwAiCIEwAAcnYfAHAoIwAABgAGcmAoAHAC
>> "%~1" echo IFgbAAByLiAAcCgjAAAGAAZybCgAcAIgKCMAAHIqJABwKCMAAAYABnK8EABwAiBY
>> "%~1" echo GwAAcnwoAHAoIwAABgAGcpQoAHACICgjAABynigAcCgjAAAGAAZyuCgAcAIgQB8A
>> "%~1" echo AHLSKABwKCMAAAYABnL8KABwAiBYGwAAchApAHAoIwAABgAGckQpAHACIEAfAABy
>> "%~1" echo UikAcCgjAAAGAAZyfCkAcAIg4C4AAHJ+JgBwKCMAAAYABnKYKQBwAiBYGwAAcmYl
>> "%~1" echo AHAoIwAABgAGcqgpAHACIFgbAABytCkAcCgjAAAGAAZy0CkAcAIg4C4AAHLiKQBw
>> "%~1" echo KCMAAAYABnIQKgBwAiBAHwAAciIqAHAoIwAABgAGckQqAHACIEAfAAByWCoAcCgj
>> "%~1" echo AAAGAAZyjioAcAIgiBMAAHKUKgBwKCMAAAYABnK8KgBwAiCIEwAAcvgiAHAoIwAA
>> "%~1" echo BgAGcswqAHACIIgTAABy3CoAcCgjAAAGAAZyACsAcAIguAsAAHIMKwBwKCMAAAYA
>> "%~1" echo BnIeKwBwAiCIEwAAci4rAHAoIwAABgAGcj4rAHACIIgTAAByUCsAcCgjAAAGAAZy
>> "%~1" echo YisAcAIgQB8AAHKAKwBwKCMAAAYABnLOKwBwAiAQJwAAcu4rAHAoIwAABgAGciQs
>> "%~1" echo AHACIBAnAAByTCwAcCgjAAAGAAYoJgAABgAGCysAByoTMAcALQAAABwAABEAAgMF
>> "%~1" echo FhqNDwAAAQoGFnIUEABwogYXBKIGGHIYHgBwogYZDgSiBigkAAAGACoAAAATMAQA
>> "%~1" echo FgEAAB0AABEAKGMAAAoKfgEAAAQOBAQoLAAABgsGb2QAAAoAc2wAAAYMCAN9DwAA
>> "%~1" echo BAhycCwAcA4EKC0AAAYoCAAACn0QAAAECAd7CwAABChUAAAGfREAAAQIB3sMAAAE
>> "%~1" echo KFQAAAZ9EgAABAgHew0AAAR9EwAABAgHew4AAAR9FAAABAgGb2UAAAp9FQAABAJ7
>> "%~1" echo GgAABAhvZgAACgAHew4AAAQW/gENCS0ZAnsbAAAEA3J6LABwKAgAAApvYgAACgAr
>> "%~1" echo XAd7DQAABCwGBRb+ASsBFwANCS0kAnsbAAAEA3KCLABwB29pAAAGKFQAAAYoNAAA
>> "%~1" echo Cm9iAAAKACskB3sNAAAEFv4BDQktFwJ7GwAABANyjCwAcCgIAAAKb2IAAAoAKgAA
>> "%~1" echo GzACAFcAAAAeAAARAAACexoAAARvZwAACgwrHxICKGgAAAoKBnsPAAAEAygjAAAK
>> "%~1" echo Fv4BDQktBAYL3iUSAihpAAAKDQkt1t4PEgL+FgQAABtvKAAACgDcAHNsAAAGCysA
>> "%~1" echo AAcqAAEQAAACAA4ALjwADwAAAAATMAUAlAYAAB8AABEAAnsZAAAECgJyYicAcCgl
>> "%~1" echo AAAGb2sAAAYLAnJQKABwKCUAAAZvawAABgwCcmAoAHAoJQAABm9rAAAGDQJybCgA
>> "%~1" echo cCglAAAGb2sAAAYTBAJymCkAcCglAAAGb2sAAAYTBQJyfCkAcCglAAAGb2sAAAYT
>> "%~1" echo BgJylCgAcCglAAAGb2sAAAYTBwJy/CgAcCglAAAGb2sAAAYTCAJyvBAAcCglAAAG
>> "%~1" echo b2sAAAYTCQJyRCkAcCglAAAGb2sAAAYTCgJy0CkAcCglAAAGb2sAAAYTCwJyECoA
>> "%~1" echo cCglAAAGb2sAAAYTDAZy0AUAcAJ7FwAABG8qAAAKAAZybAUAcAJ7GAAABG8qAAAK
>> "%~1" echo AAZynCwAcAJ7FgAABG8qAAAKAAZy3gUAcAdy6gUAcCg5AAAGbyoAAAoABnLcBgBw
>> "%~1" echo B3L2BgBwKDkAAAZvKgAACgAGciYHAHAHcjIHAHAoOQAABm8qAAAKAAZyrCwAcAdy
>> "%~1" echo bAcAcCg5AAAGbyoAAAoABnKgBQBwB3KoBwBwKDkAAAZvKgAACgAGcswHAHAHctgH
>> "%~1" echo AHAoOQAABm8qAAAKAAZy+gcAcAdyAggAcCg5AAAGB3IqCABwKDkAAAYoLwAABm8q
>> "%~1" echo AAAKAAZyDAYAcAdyHAYAcCg5AAAGbyoAAAoABnJOBgBwB3JWBgBwKDkAAAZvKgAA
>> "%~1" echo CgAGcoAGAHAHcpwGAHAoOQAABm8qAAAKAAZyEAkAcAdyKAkAcCg5AAAGbyoAAAoA
>> "%~1" echo BnJECABwB3JUCABwKDkAAAZvKgAACgAGcrQIAHAHctYIAHAoOQAABm8qAAAKAAZy
>> "%~1" echo fAgAcAdylAgAcCg5AAAGbyoAAAoABnK8LABwB3LULABwKDkAAAZvKgAACgAGcmYJ
>> "%~1" echo AHAHcm4JAHAoOQAABm8qAAAKAAZy/iwAcAJyACsAcCglAAAGb2sAAAYoOgAABm8q
>> "%~1" echo AAAKAAZyaAsAcAhylh8AcCgzAAAGcgwtAHAoCAAACm8qAAAKAAhyoh8AcCgzAAAG
>> "%~1" echo Ew0RDSD/AQAAKDkAAAoSDihdAAAKLBIRDiMAAAAAAABZQP4CFv4BKwEXABMPEQ8t
>> "%~1" echo IREOIwAAAAAAACRAWxMQEhByuh8AcCg5AAAKKF4AAAoTDQZykgsAcBENcowMAHAo
>> "%~1" echo IwAACi0OEQ1yXCYAcCgIAAAKKwVyjAwAcABvKgAACgAGcuwfAHAIcgggAHAoMwAA
>> "%~1" echo BigxAAAGbyoAAAoABnIWIABwCCgyAAAGbyoAAAoABnK6CwBwCXJKIABwKDQAAAZv
>> "%~1" echo KgAACgAGchAKAHAJcmQgAHAoNAAABm8qAAAKAAZyEC0AcAlydCAAcCg0AAAGbyoA
>> "%~1" echo AAoABnKeIgBwAnKOKgBwKCUAAAZvawAABig/AAAGbyoAAAoABnKuIgBwAnK8KgBw
>> "%~1" echo KCUAAAZvawAABihAAAAGbyoAAAoABnIkLQBwAnLMKgBwKCUAAAZvawAABihBAAAG
>> "%~1" echo byoAAAoABnJsKABwEQQoQgAABm8qAAAKAAZyLC0AcBEEcjgtAHAoNQAABnL8JABw
>> "%~1" echo ciwlAHAoOwAABm8qAAAKAAZymCkAcBEFKEMAAAZvKgAACgAGcrwQAHARCShEAAAG
>> "%~1" echo byoAAAoABnKUKABwEQcCch4rAHAoJQAABm9rAAAGKEUAAAZvKgAACgAGcvwoAHAR
>> "%~1" echo CChGAAAGbyoAAAoABnJEKQBwEQoRBihHAAAGbyoAAAoABnJcLQBwEQYoSAAABm8q
>> "%~1" echo AAAKAAZybC0AcBEGcr4mAHAoPgAABm8qAAAKAAZyiC0AcBEGcqomAHAoPgAABm8q
>> "%~1" echo AAAKAAZyoi0AcBEGctQmAHAoPgAABm8qAAAKAAZyui0AcBEGcugmAHAoPgAABm8q
>> "%~1" echo AAAKAAZy2i0AcBEGcgAnAHAoPgAABm8qAAAKAAZy+C0AcBEGch4uAHAoPgAABm8q
>> "%~1" echo AAAKAAZyOC4AcBEGclAuAHAoPgAABm8qAAAKAAZyaC4AcBEGcoguAHAoPgAABm8q
>> "%~1" echo AAAKAAZyoC4AcBEGcsYuAHAoPgAABm8qAAAKAAZy6C4AcBEGcgwvAHAbb0YAAAoW
>> "%~1" echo LwdyjAwAcCsFcjwvAHAAbyoAAAoABnLQKQBwEQsoSgAABhMREhEoOQAACig8AAAK
>> "%~1" echo byoAAAoABnIQKgBwEQxydC8AcChLAAAGExESESg5AAAKKDwAAApvKgAACgAGcoYv
>> "%~1" echo AHACcmIrAHAoJQAABm9rAAAGKEkAAAZvKgAACgAGcpwZAHACexsAAARvPQAACiwX
>> "%~1" echo cq4ZAHACexsAAARvPgAACig/AAAKKwVyjAwAcABvKgAACgAqEzAHAN8GAAAgAAAR
>> "%~1" echo AAJ7GQAABAoDLQdyjC8AcCsFcr4vAHAACwMtB3LwLwBwKwVyCjAAcAAMciAwAHAo
>> "%~1" echo MAAAChMHEgdyLDAAcCg5AAAKKGoAAAooCAAACg0GctAFAHAoTQAABgMoTwAABhME
>> "%~1" echo c1UAAAoTBREFckwwAHAHKE4AAAZyXzEAcCg0AAAKb1YAAAomEQVycTEAcG9WAAAK
>> "%~1" echo JhEFG40PAAABEwgRCBZygTEAcKIRCBcDLQdyNj8AcCsFck4/AHAAohEIGHJiPwBw
>> "%~1" echo ohEIGQMtB3I2PwBwKwVyTj8AcACiEQgacnI/AHCiEQgoFAAACm9WAAAKJhEFcnta
>> "%~1" echo AHBvVgAACiYRBXKnWgBwb1YAAAomEQVyQlwAcG9WAAAKJhEFco5cAHBvVgAACiYR
>> "%~1" echo BR8LjQ8AAAETCBEIFnJRXgBwohEIFwkoTgAABqIRCBhyz14AcKIRCBkGcpwsAHAo
>> "%~1" echo TQAABihOAAAGohEIGnI5XwBwohEIGwgoTgAABqIRCBxyxl8AcKIRCB0GcjQFAHAo
>> "%~1" echo TQAABihOAAAGohEIHnJLYABwohEIHwkGcjQFAHAoTQAABihQAAAGKE4AAAaiEQgf
>> "%~1" echo CnJRYABwohEIKBQAAApvVgAACiYRBR8RjQ8AAAETCBEIFnKJYABwohEIFwZy3gUA
>> "%~1" echo cChNAAAGKE4AAAaiEQgYckphAHCiEQgZBnLcBgBwKE0AAAYoTgAABqIRCBpy7BkA
>> "%~1" echo cKIRCBsGcqwsAHAoTQAABihOAAAGohEIHHLsGQBwohEIHQZyoAUAcChNAAAGKE4A
>> "%~1" echo AAaiEQgecn5hAHCiEQgfCREEKE4AAAaiEQgfCnLmYQBwohEIHwsGcgwGAHAoTQAA
>> "%~1" echo BihOAAAGohEIHwxyHGIAcKIRCB8NBnJOBgBwKE0AAAYoTgAABqIRCB8OcuZhAHCi
>> "%~1" echo EQgfDwZy+gcAcChNAAAGKE4AAAaiEQgfEHIsYgBwohEIKBQAAApvVgAACiYRBRuN
>> "%~1" echo DwAAARMIEQgWcmBiAHCiEQgXAy0Hcu1iAHArBXL5YgBwAChOAAAGohEIGHJKYQBw
>> "%~1" echo ohEIGQMtB3IFYwBwKwVyOWMAcAAoTgAABqIRCBpyt2MAcKIRCCgUAAAKb1YAAAom
>> "%~1" echo EQUfC40PAAABEwgRCBZyDmUAcKIRCBcGcmgLAHAoTQAABihOAAAGohEIGHLsGQBw
>> "%~1" echo ohEIGQZykgsAcChNAAAGKE4AAAaiEQgacp1lAHCiEQgbBnJsKABwKE0AAAYoTgAA
>> "%~1" echo BqIRCBxyA2YAcKIRCB0Gcp4iAHAoTQAABihOAAAGohEIHnJpZgBwohEIHwkGclwt
>> "%~1" echo AHAoTQAABihOAAAGohEIHwpyz2YAcKIRCCgUAAAKb1YAAAomEQVy+WYAcAYDHwqN
>> "%~1" echo DwAAARMIEQgWcgNnAHCiEQgXckVnAHCiEQgYcolnAHCiEQgZctlnAHCiEQgacg1o
>> "%~1" echo AHCiEQgbckFoAHCiEQgccntoAHCiEQgdcrdoAHCiEQgecutoAHCiEQgfCXIVaQBw
>> "%~1" echo ohEIKCgAAAYAEQVyS2kAcAYDHwmNDwAAARMIEQgWcldpAHCiEQgXcodpAHCiEQgY
>> "%~1" echo cqdpAHCiEQgZcuFpAHCiEQgaciFqAHCiEQgbclNqAHCiEQgccp1qAHCiEQgdctNq
>> "%~1" echo AHCiEQgechNrAHCiEQgoKAAABgARBXJBawBwBgMfEY0PAAABEwgRCBZyY2sAcKIR
>> "%~1" echo CBdynWsAcKIRCBhy02sAcKIRCBlyE2wAcKIRCBpyVWwAcKIRCBtym2wAcKIRCBxy
>> "%~1" echo 2WwAcKIRCB1yF20AcKIRCB5yYW0AcKIRCB8JcqttAHCiEQgfCnLxbQBwohEIHwty
>> "%~1" echo GW4AcKIRCB8Mcl1uAHCiEQgfDXKrbgBwohEIHw5yEW8AcKIRCB8PcjNvAHCiEQgf
>> "%~1" echo EHJjbwBwohEIKCgAAAYAEQVyj28AcAYDHwqNDwAAARMIEQgWcsNvAHCiEQgXciNw
>> "%~1" echo AHCiEQgYcn9wAHCiEQgZculwAHCiEQgack9xAHCiEQgbcrFxAHCiEQgcch9yAHCi
>> "%~1" echo EQgdcn1yAHCiEQgecuNyAHCiEQgfCXJZcwBwohEIKCgAAAYAEQVy0XMAcG9WAAAK
>> "%~1" echo JhEFclB1AHAGAxqNDwAAARMIEQgWcl51AHCiEQgXcpp1AHCiEQgYcuR1AHCiEQgZ
>> "%~1" echo clh2AHCiEQgoKAAABgARBQIDKCkAAAYAEQUdjQ8AAAETCBEIFnKWdgBwohEIFwZy
>> "%~1" echo 0CkAcChNAAAGKE4AAAaiEQgYcnd4AHCiEQgZBnIQKgBwKE0AAAYoTgAABqIRCBpy
>> "%~1" echo x3gAcKIRCBsDLQdyE3kAcCsFciN5AHAAKE4AAAaiEQgccjl5AHCiEQgoFAAACm9W
>> "%~1" echo AAAKJhEFcm15AHBvVgAACiYRBW9XAAAKEwYrABEGKgATMAQACgEAACEAABEAAnKl
>> "%~1" echo eQBwAyhOAAAGcuF5AHAoNAAACm9WAAAKJgAOBBMGFhMHOMIAAAARBhEHmgoABheN
>> "%~1" echo GwAAARMIEQgWH3ydEQgZb1sAAAoLBxaaDAeOaRcwAwgrAwcXmgANB45pGDAHcqZ6
>> "%~1" echo AHArAwcYmgATBAQIKE0AAAYTBQUW/gETCREJLQoRBRcoTwAABhMFAh2NDwAAARMK
>> "%~1" echo EQoWcq56AHCiEQoXCShOAAAGohEKGHLAegBwohEKGREFKE4AAAaiEQoacsB6AHCi
>> "%~1" echo EQobEQQoTgAABqIRChxy1HoAcKIRCigUAAAKb1YAAAomABEHF1gTBxEHEQaOaf4E
>> "%~1" echo EwkRCTot////AnLqegBwb1YAAAomKgAAGzAFAGUBAAAiAAARAAJyIHsAcG9WAAAK
>> "%~1" echo JgADexoAAARvZwAACgw4GQEAABICKGgAAAoKAAQsFgZ7DwAABHKEewBwG29GAAAK
>> "%~1" echo Fv4EKwEXAA0JLQU47AAAAAZvawAABgsEFv4BDQktCAcDKFIAAAYLB29BAAAKIGDq
>> "%~1" echo AAD+Ahb+AQ0JLRcHFiBg6gAAb2EAAApyknsAcCgIAAAKCwIfCo0PAAABEwQRBBZy
>> "%~1" echo xHsAcKIRBBcGew8AAAQoTgAABqIRBBhy6nsAcKIRBBkGfBUAAAQoOQAACig6AAAK
>> "%~1" echo KE4AAAaiEQQacvJ7AHCiEQQbBnwTAAAEKDkAAAooPAAACihOAAAGohEEHAZ7FAAA
>> "%~1" echo BC0HchAbAHArBXIIfABwAKIRBB1yHnwAcKIRBB4HKE4AAAaiEQQfCXI+fABwohEE
>> "%~1" echo KBQAAApvVgAACiYAEgIoaQAACg0JOtn+///eDxIC/hYEAAAbbygAAAoA3AACcmB8
>> "%~1" echo AHBvVgAACiYqAAAAQRwAAAIAAAAaAAAALgEAAEgBAAAPAAAAAAAAABMwAwDbAAAA
>> "%~1" echo IwAAEQACIMQJAABydnwAcCgSAAAGCgZyjAwAcCglAAAKLBAGcrB8AHAoJQAAChb+
>> "%~1" echo ASsBFwATBxEHLQgGEwY4mAAAAAACIMQJAABywHwAcCgSAAAGKFUAAAYTCBYTCStk
>> "%~1" echo EQgRCZoLAAdvUwAACgwIcvZ8AHBvawAACg0JFv4EEwcRBy05AAgJG1hvQgAACm9T
>> "%~1" echo AAAKEwQRBB8vb0cAAAoTBREFFv4CFv4BEwcRBy0OEQQWEQVvYQAAChMG3h8AABEJ
>> "%~1" echo F1gTCREJEQiOaf4EEwcRBy2OcowMAHATBisAABEGKgATMAMAGAAAAA8AABEAAgME
>> "%~1" echo KCwAAAZvaQAABihUAAAGCisABioeAihsAAAKKh4CKGwAAAoqCzACACwAAAAAAAAA
>> "%~1" echo AAACex0AAAR7HAAABAJ7HgAABG9tAAAKb24AAAp9CwAABADeBSYAAN4AACoBEAAA
>> "%~1" echo AAABACQlAAUBAAABCzACACwAAAAAAAAAAAACex0AAAR7HAAABAJ7HgAABG9vAAAK
>> "%~1" echo b24AAAp9DAAABADeBSYAAN4AACoBEAAAAAABACQlAAUBAAABGzACADwBAAAkAAAR
>> "%~1" echo c24AAAYTBQARBXNqAAAGfRwAAARzbwAABg0JEQV9HQAABABzcAAACgoGAm9xAAAK
>> "%~1" echo AAYDKC0AAAZvcgAACgAGFm9zAAAKAAYXb3QAAAoABhdvdQAACgAGF292AAAKAAkG
>> "%~1" echo KHcAAAp9HgAABAn+BnAAAAZzeAAACnN5AAAKCwn+BnEAAAZzeAAACnN5AAAKDAdv
>> "%~1" echo egAACgAIb3oAAAoACXseAAAEBG97AAAKEwcRBy0vABEFexwAAAQXfQ4AAAQACXse
>> "%~1" echo AAAEb3wAAAoAAN4FJgAA3gAAEQV7HAAABBMG3lsRBXscAAAECXseAAAEb30AAAp9
>> "%~1" echo DQAABAcg6AMAAG9+AAAKJggg6AMAAG9+AAAKJhEFexwAAAQTBt4hEwQAEQV7HAAA
>> "%~1" echo BBEEbwcAAAp9DAAABBEFexwAAAQTBt4AABEGKkE0AAAAAAAAvAAAABAAAADMAAAA
>> "%~1" echo BQAAAAEAAAEAAAAAFAAAAAMBAAAXAQAAIQAAAA4AAAETMAMASQAAACUAABEAc1UA
>> "%~1" echo AAoKFgsrKQAHFv4CFv4BDQktCQYfIG9ZAAAKJgYCB5ooLgAABm9YAAAKJgAHF1gL
>> "%~1" echo BwKOaf4EDQktzQZvVwAACgwrAAgqAAAAIAAJACIAJgB8ADwAPgBeABMwBABdAAAA
>> "%~1" echo EwAAEQACFP4BFv4BCwctCHICfQBwCitHAh6NGwAAASXQHwAABCh/AAAKb4AAAAoW
>> "%~1" echo /gQW/gELBy0EAgorInIIfQBwAnIIfQBwcgx9AHBvXAAACnIIfQBwKDQAAAoKKwAG
>> "%~1" echo KgAAABMwAwBOAAAAEwAAEQACKFQAAAYQAAMoVAAABhABAnKMDABwKCMAAAoW/gEL
>> "%~1" echo By0EAworJQNyjAwAcCgjAAAKFv4BCwctBAIKKw8CcpsBAHADKDQAAAoKKwAGKgAA
>> "%~1" echo EzACAGsAAAATAAARAAJyEn0AcCgjAAAKFv4BCwctCHIWfQBwCitOAnIefQBwKCMA
>> "%~1" echo AAotEAJyIn0AcCgjAAAKFv4BKwEWAAsHLQhyJn0AcAorIwJyLn0AcCgjAAAKFv4B
>> "%~1" echo CwctCHIyfQBwCisJAihUAAAGCisABioAEzACAI4AAAATAAARAAJyEn0AcCgjAAAK
>> "%~1" echo Fv4BCwctCHI6fQBwCitxAnIefQBwKCMAAAoW/gELBy0IckB9AHAKK1cCciJ9AHAo
>> "%~1" echo IwAAChb+AQsHLQhyRn0AcAorPQJyLn0AcCgjAAAKFv4BCwctCHJMfQBwCisjAnJS
>> "%~1" echo fQBwKCMAAAoW/gELBy0IclZ9AHAKKwkCKFQAAAYKKwAGKgAAEzACAHcAAAATAAAR
>> "%~1" echo AAJyXH0AcCg1AAAGcroFAHBvgQAAChb+AQsHLQhydH0AcAorUAJyen0AcCg1AAAG
>> "%~1" echo croFAHBvgQAAChb+AQsHLQhylH0AcAorLAJynH0AcCg1AAAGcroFAHBvgQAAChb+
>> "%~1" echo AQsHLQhywH0AcAorCHLGfQBwCisABioAEzADAGsAAAAmAAARAAACKFUAAAYNFhME
>> "%~1" echo K0UJEQSaCgAGb1MAAAoLBwNyOB8AcCgIAAAKG28mAAAKFv4BEwURBS0WBwNvQQAA
>> "%~1" echo ChdYb0IAAAooVAAABgzeHAARBBdYEwQRBAmOaf4EEwURBS2ucowMAHAMKwAACCoA
>> "%~1" echo EzADAJMAAAAnAAARAAACKFUAAAYTBhYTBytpEQYRB5oKAAZvUwAACgsHA3LOfQBw
>> "%~1" echo KAgAAAoab0YAAAoMCBb+BBMIEQgtNwAHCANvQQAAClgXWG9CAAAKDQkfLG9HAAAK
>> "%~1" echo EwQRBBYvAwkrCQkWEQRvYQAACgAoVAAABhMF3h4AEQcXWBMHEQcRBo5p/gQTCBEI
>> "%~1" echo LYlyjAwAcBMFKwAAEQUqABMwAwBUAAAAJgAAEQAAAihVAAAGDRYTBCsuCREEmgoA
>> "%~1" echo Bm9TAAAKCwcDG29GAAAKFv4EEwURBS0JByhUAAAGDN4cABEEF1gTBBEECY5p/gQT
>> "%~1" echo BREFLcVyjAwAcAwrAAAIKhMwAwBlAAAAKAAAEQADcjgfAHAoCAAACgoCBhtvRgAA
>> "%~1" echo CgsHFv4EFv4BEwURBS0JcowMAHATBCs2AgcGb0EAAApYb0IAAApvUwAACgwIHyxv
>> "%~1" echo RwAACg0JFi8DCCsICBYJb2EAAAoAKFQAAAYTBCsAEQQqAAAAEzADAGYAAAApAAAR
>> "%~1" echo AAACKFUAAAYTBBYTBSs+EQQRBZoKAAZvUwAACgsHAxtvRgAACgwIFv4EEwYRBi0W
>> "%~1" echo BwgDb0EAAApYb0IAAAooVAAABg3eHQARBRdYEwURBREEjmn+BBMGEQYttHKMDABw
>> "%~1" echo DSsAAAkqAAATMAQAxgAAACoAABEAAAIoVQAABhMFFhMGOJYAAAARBREGmgoABm9T
>> "%~1" echo AAAKCwcDG28mAAAKEwcRBy0CK3IHGI0bAAABEwgRCBYfIJ0RCBcfCZ0RCBdvVAAA
>> "%~1" echo CgwIjmkYMhkIF5og/wEAACg5AAAKEgMoXQAAChb+ASsBFwATBxEHLSwJIwAAAAAA
>> "%~1" echo ADBBWxMJEglyuh8AcCg5AAAKKF4AAApy0n0AcCgIAAAKEwTeIQARBhdYEwYRBhEF
>> "%~1" echo jmn+BBMHEQc6Wf///3KMDABwEwQrAAARBCoAABMwBAC/AAAAKwAAEQAAAihVAAAG
>> "%~1" echo EwQWEwU4kQAAABEEEQWaCgAGb1MAAAoLctp9AHADct59AHAoNAAACgwHCBpvJgAA
>> "%~1" echo Chb+ARMGEQYtKQcIb0EAAApvQgAACheNGwAAARMHEQcWH12dEQdvggAACihUAAAG
>> "%~1" echo Dd5RBwNyzn0AcCgIAAAKGm8mAAAKFv4BEwYRBi0WBwNvQQAAChdYb0IAAAooVAAA
>> "%~1" echo Bg3eIAARBRdYEwURBREEjmn+BBMGEQY6Xv///3KMDABwDSsAAAkqABMwAgBSAAAA
>> "%~1" echo JgAAEQAAAihVAAAGDRYTBCssCREEmgoABihUAAAGCwdyjAwAcCglAAAKFv4BEwUR
>> "%~1" echo BS0EBwzeHAARBBdYEwQRBAmOaf4EEwURBS3HcowMAHAMKwAACCoAABMwBABnAAAA
>> "%~1" echo LAAAEQACJS0GJnIQGwBwAxtvRgAACgoGFv4EFv4BDQktCHKMDABwDCs/BgNvQQAA
>> "%~1" echo ClgKAgQGG2+DAAAKCwcW/gQW/gENCS0PAgZvQgAACihUAAAGDCsSAgYHBllvYQAA
>> "%~1" echo CihUAAAGDCsACCoAEzADAEwAAAAtAAARAAIlLQYmchAbAHADFyiEAAAKCgZvhQAA
>> "%~1" echo CiwOBm+GAAAKb4cAAAoXMAdyjAwAcCsWBm+GAAAKF2+IAAAKb4kAAAooVAAABgAL
>> "%~1" echo KwAHKhMwAgANAAAADwAAEQACAyg8AAAGCisABioAAAATMAQAsAAAAC4AABEAAiUt
>> "%~1" echo BiZyEBsAcHIMfQBwAyiKAAAKcuh9AHAoNAAAChcohAAACgoGb4UAAAoW/gEMCC0Z
>> "%~1" echo Bm+GAAAKF2+IAAAKb4kAAAooVAAABgsrYQIlLQYmchAbAHByDH0AcAMoigAACnIU
>> "%~1" echo fgBwKDQAAAoXKIQAAAoKBm+FAAAKLQdyjAwAcCsoBm+GAAAKF2+IAAAKb4kAAAoX
>> "%~1" echo jRsAAAENCRYfIp0Jb0wAAAooVAAABgALKwAHKhMwBAD8AAAALwAAEQAAAihVAAAG
>> "%~1" echo EwQWEwU4zgAAABEEEQWaCgAGb1MAAAoLB29BAAAKLBEHctgiAHAbbyYAAAoW/gEr
>> "%~1" echo ARYAEwYRBi0FOJQAAAAHGI0bAAABEwcRBxYfIJ0RBxcfCZ0RBxdvVAAACgwIjmkc
>> "%~1" echo Mi4ICI5pF1macjx+AHAoIwAACi0XCAiOaRdZmnJIfgBwG29GAAAKFv4EKwEWACsB
>> "%~1" echo FwATBhEGLTkbjQ8AAAETCBEIFggYmqIRCBdy7BkAcKIRCBgIF5qiEQgZclp+AHCi
>> "%~1" echo EQgaCBqaohEIKBQAAAoN3iAAEQUXWBMFEQURBI5p/gQTBhEGOiH///9yjAwAcA0r
>> "%~1" echo AAAJKhMwBABaAAAAGQAAEQACchwjAHAoOAAABgoCcjAjAHAoOAAABgsGcowMAHAo
>> "%~1" echo IwAACiwQB3KMDABwKCMAAAoW/gErARcADQktCHKMDABwDCsUckwjAHAHclQjAHAG
>> "%~1" echo KCwAAAoMKwAIKgAAEzADAFYAAAAwAAARAAJyaH4AcChLAAAGCgJyfH4AcCg8AAAG
>> "%~1" echo CwYtEAdyjAwAcCgjAAAKFv4BKwEXAA0JLQhyjAwAcAwrGhIAKDkAAAooPAAACnK8
>> "%~1" echo fgBwByg0AAAKDCsACCoAABMwBAAfAQAAMQAAEQACckokAHAoNQAABgoGcm4kAHAo
>> "%~1" echo PAAABgsGcp4kAHAoPAAABgwGctYkAHAoPAAABg0GctB+AHAoTAAABhMHEgcoOQAA
>> "%~1" echo Cig8AAAKEwRzXwAAChMFB3KMDABwKCUAAAoW/gETCBEILRgRBQdymwEAcHIQGwBw
>> "%~1" echo b1wAAApvYgAACgAIcowMAHAoJQAAChb+ARMIEQgtExEFCHIwJQBwKAgAAApvYgAA
>> "%~1" echo CgAJcowMAHAoJQAAChb+ARMIEQgtExEFcjYlAHAJKAgAAApvYgAACgARBHLyfgBw
>> "%~1" echo KCUAAAoW/gETCBEILRQRBREEcvZ+AHAoCAAACm9iAAAKABEFbz0AAAosE3LsGQBw
>> "%~1" echo EQVvPgAACig/AAAKKwVyjAwAcAATBisAEQYqABMwBADJAAAAMgAAEQACcpQlAHAo
>> "%~1" echo MwAABgoCcgR/AHAoMwAABgsCcrIlAHAoPQAABgxzXwAACg0GcowMAHAoJQAAChb+
>> "%~1" echo ARMFEQUtEglyNCYAcAYoCAAACm9iAAAKAAdyjAwAcCglAAAKFv4BEwURBS0SCXIY
>> "%~1" echo fwBwBygIAAAKb2IAAAoACHKMDABwKCUAAAoW/gETBREFLRcJciJ/AHAIclwmAHAo
>> "%~1" echo NAAACm9iAAAKAAlvPQAACiwScuwZAHAJbz4AAAooPwAACisFcowMAHAAEwQrABEE
>> "%~1" echo KgAAABMwAwC6AAAAMgAAEQACcjR/AHAoPAAABgoCclp/AHAoPAAABgsCcoJ/AHAo
>> "%~1" echo PAAABgxzXwAACg0GcowMAHAoJQAAChb+ARMFEQUtEglyvH8AcAYoCAAACm9iAAAK
>> "%~1" echo AAdyjAwAcCglAAAKFv4BEwURBS0SCXLSfwBwBygIAAAKb2IAAAoACHKMDABwKCUA
>> "%~1" echo AAoW/gETBREFLQgJCG9iAAAKAAlvPQAACiwScuwZAHAJbz4AAAooPwAACisFcowM
>> "%~1" echo AHAAEwQrABEEKgAAEzADADMBAAAzAAARAAJy6n8AcCg8AAAGCgJyKIAAcCg8AAAG
>> "%~1" echo CwJyVIAAcCg8AAAGDAJygoAAcCg8AAAGDQNyqIAAcCg8AAAGEwRzXwAAChMFEQRy
>> "%~1" echo jAwAcCglAAAKFv4BEwcRBy0UEQVy+IAAcBEEKAgAAApvYgAACgAGcowMAHAoJQAA
>> "%~1" echo Chb+ARMHEQctExEFcgCBAHAGKAgAAApvYgAACgAHcowMAHAoJQAAChb+ARMHEQct
>> "%~1" echo ExEFB3IUgQBwKAgAAApvYgAACgAIcowMAHAoJQAAChb+ARMHEQctExEFCHIcgQBw
>> "%~1" echo KAgAAApvYgAACgAJcowMAHAoJQAAChb+ARMHEQctExEFciaBAHAJKAgAAApvYgAA
>> "%~1" echo CgARBW89AAAKLBNy7BkAcBEFbz4AAAooPwAACisFcowMAHAAEwYrABEGKgATMAQA
>> "%~1" echo YAAAABkAABEAAnIygQBwKDwAAAYKAnJagQBwKDwAAAYLBnKMDABwKCMAAAosEAdy
>> "%~1" echo jAwAcCgjAAAKFv4BKwEXAA0JLQ4CcoCBAHAoNQAABgwrFHKigQBwBnLsGQBwBygs
>> "%~1" echo AAAKDCsACCoTMAQA5wAAADQAABEAAnK0gQBwKEwAAAYKA3IUggBwKEwAAAYLA3I+
>> "%~1" echo ggBwKEwAAAYMA3JqggBwKEwAAAYNc18AAAoTBAYW/gIW/gETBhEGLRgRBAaMFQAA
>> "%~1" echo AXKWggBwKCkAAApvYgAACgAHCFgJWBb+Ahb+ARMGEQYtUBEEHI0BAAABEwcRBxZy
>> "%~1" echo toIAcKIRBxcHjBUAAAGiEQcYctyCAHCiEQcZCIwVAAABohEHGnLyggBwohEHGwmM
>> "%~1" echo FQAAAaIRBygSAAAKb2IAAAoAEQRvPQAACiwTcuwZAHARBG8+AAAKKD8AAAorBXKM
>> "%~1" echo DABwABMFKwARBSoAEzADAB8BAAAzAAARAAJyviYAcCg+AAAGCgJyqiYAcCg+AAAG
>> "%~1" echo CwJy1CYAcCg+AAAGDAJy6CYAcCg+AAAGDQJyACcAcCg+AAAGEwRzXwAAChMFBnKM
>> "%~1" echo DABwKCUAAAoW/gETBxEHLQkRBQZvYgAACgAHcowMAHAoJQAAChb+ARMHEQctCREF
>> "%~1" echo B29iAAAKAAhyjAwAcCglAAAKFv4BEwcRBy0TEQVyFicAcAgoCAAACm9iAAAKAAly
>> "%~1" echo jAwAcCglAAAKFv4BEwcRBy0TEQVyKCcAcAkoCAAACm9iAAAKABEEcowMAHAoJQAA
>> "%~1" echo Chb+ARMHEQctFBEFcjInAHARBCgIAAAKb2IAAAoAEQVvPQAACiwTcuwZAHARBW8+
>> "%~1" echo AAAKKD8AAAorBXKMDABwABMGKwARBioAEzADAFoAAAA1AAARAAJyCIMAcBtvRgAA
>> "%~1" echo Chb+BBb+AQwILQhyjAwAcAsrOQJy8iMAcCg3AAAGCnKKIwBwBnKMDABwKCMAAAot
>> "%~1" echo DXLsGQBwBigIAAAKKwVyEBsAcAAoCAAACgsrAAcqAAATMAMATAAAADYAABEAFgoA
>> "%~1" echo AihVAAAGDRYTBCspCREEmgsHb1MAAApySoMAcBtvJgAAChb+ARMFEQUtBAYXWAoR
>> "%~1" echo BBdYEwQRBAmOaf4EEwURBS3KBgwrAAgqEzADAEgAAAA2AAARABYKAAIoVQAABg0W
>> "%~1" echo EwQrJQkRBJoLB29TAAAKAxtvJgAAChb+ARMFEQUtBAYXWAoRBBdYEwQRBAmOaf4E
>> "%~1" echo EwURBS3OBgwrAAgqEzADABwAAAA3AAARAAIlLQYmchAbAHADFyiLAAAKb4wAAAoK
>> "%~1" echo KwAGKhMwAgAjAAAADwAAEQACA28vAAAKLQdyjAwAcCsMAgNvKwAACihUAAAGAAor
>> "%~1" echo AAYqABMwAQARAAAADwAAEQACKFQAAAYojQAACgorAAYqAAAAEzABABgAAAAPAAAR
>> "%~1" echo AAMtCAIoVAAABisGAihRAAAGAAorAAYqEzADAK8AAAA1AAARAAIoVAAABgoGcowM
>> "%~1" echo AHAoIwAAChb+AQwILQcGCziMAAAABnJcgwBwG29GAAAKFv4EDAgtCHKMgwBwCytx
>> "%~1" echo BnLEgwBwG29GAAAKFjIRBnLUgwBwG29GAAAKFv4EKwEXAAwILQhy8oMAcAsrQwZy
>> "%~1" echo KIQAcBtvSAAACi0RBnI4hABwG29IAAAKFv4BKwEWAAwILQhyQIQAcAsrFgZvQQAA
>> "%~1" echo Ch80/gIMCC0EBgsrBAYLKwAHKgATMAIAOgAAADUAABEAAm+JAAAKCgZyXoQAcCiO
>> "%~1" echo AAAKLBAGcmqEAHAojgAAChb+ASsBFwAMCC0JBihTAAAGCysEBgsrAAcqAAATMAQA
>> "%~1" echo OgAAABAAABEAAhQoUgAABgoGcnaEAHB+CgAABC0TFP4GZwAABnOPAAAKgAoAAAQr
>> "%~1" echo AH4KAAAEKJAAAAoKBgsrAAcqAAATMAQA7wAAADUAABEAAihUAAAGCgMsIgN7FwAA
>> "%~1" echo BCgeAAAKLRUDexcAAARyjAwAcCglAAAKFv4BKwEXAAwILRgGA3sXAAAEA3sXAAAE
>> "%~1" echo KFMAAAZvXAAACgoGcp6EAHBy7IQAcCiRAAAKCgZyEIUAcHJOhQBwKJEAAAoKBnJm
>> "%~1" echo hQBwcqqFAHAokQAACgoGcryFAHByIIYAcCiRAAAKCgZyNIYAcHKGhgBwFyiSAAAK
>> "%~1" echo CgZyooYAcHLwhgBwFyiSAAAKCgZyNocAcHJihwBwFyiSAAAKCgZykIcAcHLGhwBw
>> "%~1" echo FyiSAAAKCgZy+ocAcHIoiABwFyiSAAAKCgYLKwAHKgATMAUASgAAABMAABEAAige
>> "%~1" echo AAAKLQ4Cb0EAAAoc/gQW/gErARYACwctCHJUiABwCisjAhYZb2EAAApyZogAcAIC
>> "%~1" echo b0EAAAoZWW9CAAAKKDQAAAoKKwAGKgAAEzADAEEAAAATAAARAAIU/gEW/gELBy0I
>> "%~1" echo cowMAHAKKysCcm6IAHByEBsAcG9cAAAKb1MAAAoQAAJvQQAACiwDAisFcowMAHAA
>> "%~1" echo CisABioAAAATMAQAMQAAADgAABEAAiUtBiZyEBsAcHJuiABwchAbAHBvXAAACheN
>> "%~1" echo GwAAAQsHFh8KnQdvHwAACgorAAYqAAAAEzACAC8AAAA5AAARAAJyuAkAcCgjAAAK
>> "%~1" echo LRoCcpwKAHAoIwAACi0NAnLqCgBwKCMAAAorARcACisABioAEzACAGEAAAA6AAAR
>> "%~1" echo AAIoHgAAChb+AQwILQQWCytMAAINFhMEKzIJEQRvkwAACgoGKJQAAAotEQYfXy4M
>> "%~1" echo Bh8uLgcGHy3+ASsBFwAMCC0EFgveGBEEF1gTBBEECW9BAAAK/gQMCC3AFwsrAAAH
>> "%~1" echo KgAAABMwAgCKAAAAOQAAEQACcnQNAHAoIwAACi11AnJMDQBwKCMAAAotaAJyAhAA
>> "%~1" echo cCgjAAAKLVsCclQQAHAoIwAACi1OAnJiDwBwKCMAAAotQQJynBIAcCgjAAAKLTQC
>> "%~1" echo cvwTAHAoIwAACi0nAnJ6DgBwKCMAAAotGgJyzhYAcCgjAAAKLQ0Ccn4XAHAoIwAA
>> "%~1" echo CisBFwAKKwAGKgAAEzACAKoAAAATAAARAAIlLQYmchAbAHBvlQAACgoGcsYJAHAo
>> "%~1" echo IwAACjqCAAAABnLuCQBwKCMAAAotdQZycogAcCgjAAAKLWgGcqyIAHAoIwAACi1b
>> "%~1" echo BnLSiABwKCMAAAotTgZy+ogAcCgjAAAKLUEGcgqJAHAoIwAACi00BnIsiQBwKCMA
>> "%~1" echo AAotJwZyQokAcCgjAAAKLRoGcmaJAHAoIwAACi0NBnKWiQBwKCMAAAorARcACysA
>> "%~1" echo ByoAABMwBAAuAAAADwAAEQBy0IkAcAIlLQYmchAbAHBy0IkAcHLUiQBwb1wAAApy
>> "%~1" echo 0IkAcCg0AAAKCisABioAABMwAwAeAAAABgAAEQBzlgAACgoGchYYAHByugUAcG8q
>> "%~1" echo AAAKAAYLKwAHKgAAEzADACsAAAAGAAARAChbAAAGCgZyFhgAcHKuBQBwbyoAAAoA
>> "%~1" echo BnIcGABwAm8qAAAKAAYLKwAHKgATMAIAGwAAADkAABEAAnLeiQBwKF4AAAZ+AgAA
>> "%~1" echo BCgjAAAKCisABioAEzAEALQAAAA7AAARAAJy6okAcG+XAAAKFv4BEwURBS0JAhdv
>> "%~1" echo QgAAChAAAAIXjRsAAAETBhEGFh8mnREGbx8AAAoTBxYTCCtdEQcRCJoKAAYfPW9H
>> "%~1" echo AAAKCwcWLwMGKwgGFgdvYQAACgAMBxYvB3IQGwBwKwkGBxdYb0IAAAoADQgoXwAA
>> "%~1" echo BgMoIwAAChb+ARMFEQUtCgkoXwAABhME3h4AEQgXWBMIEQgRB45p/gQTBREFLZVy
>> "%~1" echo EBsAcBMEKwAAEQQqEzADACQAAAAPAAARAAIlLQYmchAbAHBy7okAcHKbAQBwb1wA
>> "%~1" echo AAooQwAACgorAAYqegACcvKJAHAoCQAACgMoYgAABm8nAAAKKGEAAAYAKgATMAQA
>> "%~1" echo WwAAADwAABEAG40BAAABDAgWcjKKAHCiCBcDoggYcnKKAHCiCBkEjmmMFQAAAaII
>> "%~1" echo GnKYigBwoggoEgAACgoomAAACgZvJwAACgsCBxYHjmlvmQAACgACBBYEjmlvmQAA
>> "%~1" echo CgAqABswAgCuAAAAPQAAEQBy+ooAcHOaAAAKChcLAAJvmwAAChMEK2ESBCicAAAK
>> "%~1" echo DAAHEwURBS0MBnIsJQBwb1gAAAomFgsGcgh9AHBvWAAAChICKJ0AAAooYwAABm9Y
>> "%~1" echo AAAKcv6KAHBvWAAAChICKJ4AAAooYwAABm9YAAAKcgh9AHBvWAAACiYAEgQonwAA
>> "%~1" echo ChMFEQUtkt4PEgT+FgUAABtvKAAACgDcAAZyBosAcG9YAAAKb1cAAAoNKwAJKgAA
>> "%~1" echo ARAAAAIAFwByiQAPAAAAABMwAwAUAQAAPgAAEQBzVQAACgoAAiUtBiZyEBsAcA0W
>> "%~1" echo EwQ42wAAAAkRBG+TAAAKCwAHH1z+ARb+ARMFEQUtEQZyCosAcG9YAAAKJjirAAAA
>> "%~1" echo Bx8i/gEW/gETBREFLREGcgx9AHBvWAAACiY4jAAAAAcfCv4BFv4BEwURBS0OBnIQ
>> "%~1" echo iwBwb1gAAAomK3AHHw3+ARb+ARMFEQUtDgZyFosAcG9YAAAKJitUBx8J/gEW/gET
>> "%~1" echo BREFLQ4GchyLAHBvWAAACiYrOAcfIP4EFv4BEwURBS0iBnIiiwBwb1gAAAoHEwYS
>> "%~1" echo BnIoiwBwKKAAAApvWAAACiYrCAYHb1kAAAomABEEF1gTBBEECW9BAAAK/gQTBREF
>> "%~1" echo OhL///8Gb1cAAAoMKwAIKhMwAwArAAAAEAAAEQByLosAcAooCQAACgYooQAACm+i
>> "%~1" echo AAAKchMaAnB+AgAABG9cAAAKCysAByoAEzACAF8AAAA/AAARciiEAHCAAQAABCij
>> "%~1" echo AAAKChIAcicaAnAopAAACoACAAAEID0iAACAAwAABHIQGwBwgAQAAARyEBsAcIAF
>> "%~1" echo AAAEchAbAHCABgAABHNsAAAKgAcAAAQWc6UAAAqACAAABCoeAihsAAAKKgATMAIA
>> "%~1" echo IwAAAA8AABEAAnsLAAAEb0EAAAoWMAgCewwAAAQrBgJ7CwAABAAKKwAGKrICchAb
>> "%~1" echo AHB9CwAABAJyEBsAcH0MAAAEAhV9DQAABAIWfQ4AAAQCKGwAAAoAKhMwAgAjAAAA
>> "%~1" echo DwAAEQACexEAAARvQQAAChYwCAJ7EgAABCsGAnsRAAAEAAorAAYqAAMwAgBKAAAA
>> "%~1" echo AAAAAAJyEBsAcH0PAAAEAnIQGwBwfRAAAAQCchAbAHB9EQAABAJyEBsAcH0SAAAE
>> "%~1" echo AhV9EwAABAIWfRQAAAQCFmp9FQAABAIobAAACgAqAAADMAIASgAAAAAAAAACchAb
>> "%~1" echo AHB9FgAABAJyEBsAcH0XAAAEAnIQGwBwfRgAAAQCc5YAAAp9GQAABAJzpgAACn0a
>> "%~1" echo AAAEAnNfAAAKfRsAAAQCKGwAAAoAKgAAQlNKQgEAAQAAAAAADAAAAHY0LjAuMzAz
>> "%~1" echo MTkAAAAABQBsAAAAeBIAACN+AADkEgAAKBAAACNTdHJpbmdzAAAAAAwjAAAsGgIA
>> "%~1" echo I1VTADg9AgAQAAAAI0dVSUQAAABIPQIAPAcAACNCbG9iAAAAAAAAAAIAAAFXlaIp
>> "%~1" echo CQIAAAD6JTMAFgAAAQAAAEMAAAAJAAAAHwAAAHEAAACkAAAApgAAAAwAAAABAAAA
>> "%~1" echo PwAAAAIAAAACAAAAAgAAAAYAAAABAAAAAQAAAAIAAAAGAAAAAAAKAAEAAAAAAAYA
>> "%~1" echo VQBOAAYAmgCOAAoAxQCyAAYA8ADVAAYAMQEnAQYAugGOAAYAqgXVAAYAMQYSBgYA
>> "%~1" echo WgZOAAYAOAcYBwYAWAcYBwYAlAeDBwYAyAcYBwYA6QdOAAYA/wdOAAYAFghOAAYA
>> "%~1" echo MQhOAAoAaghfCAoAegiyAAYAlghOAAYArQhOAAoAxgizCAYA3giDBwoAHgmyAAYA
>> "%~1" echo NgknAQYAQwknAQYAZQlOAAoAgQlOAAYAuglOAAYA3wlOAAYABQqDBwYAHgpOAAYA
>> "%~1" echo OAonAQYARQonAQYATwonAQYAbQonAQYAfwpOAAYAwgqtCgYA4wpOAAYA6QpOAAYA
>> "%~1" echo rAuDBwYAugtOAAYA4QtOAAYAEwxOAAYAGgytCgoAOwyzCB8AawwAAAoAJw2zCAYA
>> "%~1" echo rw2DBwYAHg5OAAYAWQ4YBwYAaA5OAAYAbg5OAAoAww6kDgoAyQ6kDgoAzw6kDgoA
>> "%~1" echo 3A6kDgoA7g6kDgoANACkDgoAGg+kDgoAMg9fCAoAXA+kDhMAawwAAAYA1Q/VAAYA
>> "%~1" echo 7A9OAAYADBBOAAYAGRCOAAAAAAABAAAAAAABAAEAAAAQABwAAAAFAAEAAQADABAA
>> "%~1" echo KgAAAAUACwBpAAMAEAA0AAAABQAPAGsAAwAQADwAAAAFABYAbQADARAAmQwAAAUA
>> "%~1" echo HABuAAMBEACzDAAABQAdAG8AAAAAANkNAAAFAB8AcgATAQAAKA4AAMkAIAByABEA
>> "%~1" echo XAAKABEAZAAKABEAagANABEAbwAKABEAdwAKABEAfgAKADEAhgAQADEAowATABEA
>> "%~1" echo oQdzAREAaw9bBgYASgUKAAYABgUKAAYAUQUNAAYAWgU/AQYAcQUKAAYAdgUKAAYA
>> "%~1" echo SgUKAAYABgUKAAYAUQUNAAYAWgU/AQYAfgVKAQYAiQUKAAYAkQUKAAYAmAUKAAYA
>> "%~1" echo owVNAQYAsQVVAQYAugVdAQYArAwEBQYAxgwIBQYA1gwMBRMBRQ5JBbwgAAAAAJEA
>> "%~1" echo rQAXAAEAWCMAAAAAkQDPAB0AAgAYJwAAAACRAP0AIwADAKQrAAAAAJEABAEsAAMA
>> "%~1" echo yDMAAAAAkQALASMABQAENAAAAACRABABIwAFAHA2AAAAAJEAHQE3AAUAyDYAAAAA
>> "%~1" echo kQA4AT0ABwD4NwAAAACRAEQBRAAJAGQ4AAAAAJEATgFEAAoAyDgAAAAAkQBbAUkA
>> "%~1" echo CwAMOQAAAACRAGkBRAALAAw6AAAAAJEAcQFEAAwAmDoAAAAAkQB1AUkADQBgOwAA
>> "%~1" echo AACRAIEBTQANAIQ+AAAAAJEAjgE3AA8AtD4AAAAAkQCTAVUAEQAAPwAAAACRAJsB
>> "%~1" echo XAAUAEA/AAAAAJEAngFjABcAYD8AAAAAkQCgAVwAGQCgPwAAAACRAKcBYwAcADhA
>> "%~1" echo AAAAAJEArQFEAB4AFEEAAAAAkQDIAWoAHwCMQQAAAACRANgBRAAjAAxDAAAAAJEA
>> "%~1" echo 5gFzACQAnEMAAAAAkQDxAXgAJQCARAAAAACRAP0BeAAnABRFAAAAAJEABwJ4ACkA
>> "%~1" echo 2EYAAAAAkQAbAngAKwBYSAAAAACRACkCeAAtAABJAAAAAJEAPAJ4AC8AXEoAAAAA
>> "%~1" echo kQBMAngAMQAkSwAAAACRAFwCeAAzAHxMAAAAAJEAbAKDADUAcE8AAAAAkQB8AooA
>> "%~1" echo NwCsTwAAAACRAIwClAA8ANBQAAAAAJEAlwKfAEEARFEAAAAAkQCbAqcAQwDkVwAA
>> "%~1" echo AACRAK4CrQBEANBeAAAAAJEAvgK0AEYA6F8AAAAAkQDOAsQASwB4YQAAAACRANwC
>> "%~1" echo cwBOAGBiAAAAAJEA4wLNAE8AJGMAAAAAkQDnAtUAUgCgZAAAAACRAPEC3gBVAAhl
>> "%~1" echo AAAAAJEA+gJzAFYAdGUAAAAAkQADAzcAVwDQZQAAAACRABADcwBZAEhmAAAAAJEA
>> "%~1" echo HgNzAFoA5GYAAAAAkQAsA3MAWwBoZwAAAACRADgDNwBcAOBnAAAAAJEAQwM3AF4A
>> "%~1" echo gGgAAAAAkQBPAzcAYADgaAAAAACRAFgDNwBiAFRpAAAAAJEAXgM3AGQAyGkAAAAA
>> "%~1" echo kQBvAzcAZgCcagAAAACRAHUDNwBoAGhrAAAAAJEAfgNzAGoAyGsAAAAAkQCIA1UA
>> "%~1" echo awA8bAAAAACRAJADNwBuAJRsAAAAAJEAmwM3AHAAsGwAAAAAkQCmAzcAcgBsbQAA
>> "%~1" echo AACRALUDcwB0AHRuAAAAAJEAxANzAHUA3G4AAAAAkQDSA3MAdgBAbwAAAACRAN0D
>> "%~1" echo cwB3AGxwAAAAAJEA7ANzAHgARHEAAAAAkQD7A3MAeQAMcgAAAACRAAYENwB6AExz
>> "%~1" echo AAAAAJEAEgRzAHwAuHMAAAAAkQAjBDcAfQCsdAAAAACRADEEcwB/ANh1AAAAAJEA
>> "%~1" echo QARzAIAAQHYAAAAAkQBWBOQAgQCYdgAAAACRAGgE6QCCAOx2AAAAAJEAeQTpAIQA
>> "%~1" echo FHcAAAAAkQCEBO8AhgBEdwAAAACRAIYEcwCIAGR3AAAAAJEAiAT6AIkAiHcAAAAA
>> "%~1" echo kQCQBHMAiwCMeAAAAACRAJ8EcwCMANR4AAAAAJEAqwQAAY0A0HkAAAAAkQCyBHMA
>> "%~1" echo jwAoegAAAACRAL0EcwCQAHh6AAAAAJEAwwQHAZEAuHoAAAAAkQDJBA0BkgD0egAA
>> "%~1" echo AACRANEEDQGTAGR7AAAAAJEA2gQNAZQA/HsAAAAAkQDqBA0BlQC0fAAAAACRAPgE
>> "%~1" echo cwCWAPB8AAAAAJEAAwUjAJcAHH0AAAAAkQAGBRIBlwBUfQAAAACRAAwFDQGYAHx9
>> "%~1" echo AAAAAJEAFwU3AJkAPH4AAAAAkQAdBXMAmwBsfgAAAACRACEFHAGcAIx+AAAAAJEA
>> "%~1" echo KwUoAZ4A9H4AAAAAkQA2BTEBoQDAfwAAAACRADsFcwCiAOCAAAAAAJEAPwVJAKMA
>> "%~1" echo g4EAAAAAhhhEBTsBowBQIAAAAACRAHYHbgGjAER4AAAAAJEASA9UBqQAGIEAAAAA
>> "%~1" echo kRgFEAIHpQCMgQAAAACGCGMFQgGlALuBAAAAAIYYRAU7AaUA6IEAAAAAhghjBUIB
>> "%~1" echo pQAYggAAAACGGEQFOwGlAHCCAAAAAIYYRAU7AaUAhGIAAAAAhhhEBTsBpQCMYgAA
>> "%~1" echo AACGGEQFOwGlAJRiAAAAAIYA2Aw7AaUA3GIAAAAAhgDoDDsBpQAAAAEAwwUAAAEA
>> "%~1" echo yAUAAAEAzwUAAAIA1gUAAAEA3AUAAAIA4gUAAAEA5wUAAAIA7gUAAAEA8wUAAAEA
>> "%~1" echo 8wUAAAEA+gUAAAEAAgYCAAEABwYCAAIAPgYAAAEA8wUAAAIA4gUAAAEA8wUAAAIA
>> "%~1" echo QwYAAAMARgYAAAEA8wUAAAIASgYAAAMAUgYAAAEASgYAAAIAwwUAAAEA8wUAAAIA
>> "%~1" echo SgYAAAMAUgYAAAEASgYAAAIAwwUAAAEA8wUAAAEAbgYAAAIA8wUAAAMAQwYAAAQA
>> "%~1" echo RgYAAAEA8wUAAAEA8wUAAAEAcQYAAAIA8wUAAAEAcQYAAAIA8wUAAAEAcQYAAAIA
>> "%~1" echo 8wUAAAEAcQYAAAIA8wUAAAEAcQYAAAIA8wUAAAEAcQYAAAIA8wUAAAEAcQYAAAIA
>> "%~1" echo 8wUAAAEAcQYAAAIA8wUAAAEA8wUAAAIABwYAAAEAcwYAAAIA4gUAAAMA8wUAAAQA
>> "%~1" echo SgYAAAUAUgYAAAEAcwYAAAIA4gUAAAMASgYAAAQAeAYAAAUAwwUAAAEAcwYAAAIA
>> "%~1" echo 4gUAAAEAcwYAAAEAcwYAAAIAgQYAAAEAbgYAAAIAhgYAAAMAjAYAAAQAgQYAAAUA
>> "%~1" echo jgYAAAEAbgYAAAIAcwYAAAMAgQYAAAEA8wUAAAEAkwYAAAIAwwUAAAMASgYAAAEA
>> "%~1" echo kwYAAAIAwwUAAAMASgYAAAEAwwUAAAEAmAYAAAEAmgYAAAIAnAYAAAEAngYAAAEA
>> "%~1" echo ngYAAAEAmAYAAAEAAgYAAAIARgYAAAEAAgYAAAIARgYAAAEAAgYAAAIAoAYAAAEA
>> "%~1" echo pwYAAAIARgYAAAEAAgYAAAIARgYAAAEAAgYAAAIARgYAAAEAAgYAAAIARgYAAAEA
>> "%~1" echo AgYAAAEAAgYAAAIArAYAAAMAsQYAAAEAAgYAAAIAtwYAAAEAAgYAAAIAtwYAAAEA
>> "%~1" echo AgYAAAIARgYAAAEAvwYAAAEAwgYAAAEAxgYAAAEAygYAAAEA0gYAAAEA2gYAAAEA
>> "%~1" echo 3gYAAAIA4wYAAAEA6gYAAAEA7QYAAAIA9AYAAAEA9AYAAAEAAgYAAAEAAgYAAAEA
>> "%~1" echo AgYAAAIA+wYAAAEAAgYAAAIAtwYAAAEAcQYAAAIARgYAAAEAmAYAAAEAAgYAAAIA
>> "%~1" echo gQYAAAEA7gUAAAEAAgYAAAEAAgYAAAIAcwYAAAEA8wUAAAEAmAYAAAEAmAYAAAEA
>> "%~1" echo QwYAAAEA4gUAAAEAzwUAAAEARgYAAAEAAgcAAAEACAcAAAEADAcAAAEA1gUAAAIA
>> "%~1" echo RgYAAAEAmAYAAAEAmAYAAAIAcQYAAAEA5wUAAAIADgcAAAMAEwcAAAEAcQYAAAEA
>> "%~1" echo mAYAAAEAgQcAAAEAWg9BAEQFOwFJAEQFOwFRAEQFaQFZAEQFOwFpAEQFOwEZAOMH
>> "%~1" echo OwFxAPMHQgF5AAYINwARAA0IfAGBAB4IgQGJADsIhwGJAE0IQgGRAHQIjAGZAEQF
>> "%~1" echo kgGZAIYIOwGBAIwIRACBAKUImQF5AAYIngF5AAYIpAF5AAYI3gCxAIYIqwGZAM4I
>> "%~1" echo sQFhAEQFtgG5AOkIvAEZAPsIaQEZAA4JaQEZACwJ1QHJAEQF2gHRAE4JQgF5AFcJ
>> "%~1" echo DQF5AGoJ4gF5AHAJQgHhAEQF6QHhAIUJQgF5AJYJ7gHhAKIJQgF5AKwJ7gF5AMsJ
>> "%~1" echo 9AERANYJ+wHxAOsJOwF5AAYIFgIMAPMJIwIMAPwJKwJ5AAYISgL5AAwKUgJxAEQF
>> "%~1" echo 6QEMABIKVwIBAScKhQIBAS8KiwIJAT0KVQARAV0KkAJ5AAYIVQAJAT0KNwAhAXIK
>> "%~1" echo lwIBAYgKnwIpAZcKqwIxAc4KrwI5AS8KtQIUAPkKwwKpAC8KtQIcAPkKwwIcAAML
>> "%~1" echo zQJ5AAsL0wLhABALcwB5ACELwwJ5ACwLCwPhADYLcwAJAUkLEAN5AGALEwN5AGgL
>> "%~1" echo GQN5AGgLIAN5AHAL9AEJAXkLcwAhAYULDQEhAYwLJQN5AJkLPAMRAYULDQEhAZ4L
>> "%~1" echo lwJJAbQLTANRAcYLSQBJAdILbgERANcLXAN5AJkLQgF5AGoJcQMxAEQFOwExAPQL
>> "%~1" echo pQMJAC8KQgExAP8LpQMxAP8LtQMhAQYMwAN5AGoJyAN5AGAL4ANhAScM7ANhAS8K
>> "%~1" echo +QMcAEQFOwF5ADAM9AF5ACwLCQQcADcMDwRxAUUMYQRxAU4MOwFxAVMMZwQUADcM
>> "%~1" echo DwQUAHYMdgQkAIQMiAQkAJAMjQQBAS8K+QN5AGgL8QQJAEQFOwGxAPgMEAXRAAsN
>> "%~1" echo QgGxABUNEAWBAUQFOwGBATgN6QGBAUUN6QGBAVMNFQWBAWcNFQWBAYINFQWBAZwN
>> "%~1" echo FQWxAIYIGgWJAUQFtgH5AEQFIgX5AIYIOwGxALsNKQWxAMcNOwGxAMwNwwL5AAsL
>> "%~1" echo KQWZAYEOTQV5AJEOVwV5AHALXQV5AJwOPAN5AGgLqgWxAckOuQXJAeIOjQS5Af4O
>> "%~1" echo xAXRAfkKwwLRAfwJygXZAQkPQgGxARMPcwCxASoPRQbhAfkKwwLpAT0PcwCxAZIP
>> "%~1" echo 7gHxAUQFtgGxAWALYAaxAWALVQCxAWALaQZ5AJoPfgbZAKQPgwZ5ALQPQgEMAEQF
>> "%~1" echo OwF5AMsJXQURAMUPfAEpAM8PngYxAEQF6QEMAHYMrgYsAIQMwgY0AOQPiAQ0AAkP
>> "%~1" echo 1gYsAJAMjQSpAC8KiwIJAvQPJQMRANcL/AYRAhEQBgcRAi8KiwIZAkQFFQUUAEQF
>> "%~1" echo OwEuABsAEgcuACMAGwfDACsAZAHjACsAZAEDASsAZAEhASsAZAFBASsAZAEEAxMA
>> "%~1" echo ZAGkAxMAZAEECBMAZAHADCsAZAHgDCsAZAEBABAAAAAJAHcBwwEBAjICXQJ2AtoC
>> "%~1" echo BQMrAzQDQgNTA2QDewOSA5YDmwOrA7sD0APmAwEEFQQnBDoEQQRQBFwEawSRBKAE
>> "%~1" echo ugTPBOEE9gQuBUEFYgVsBXkFggWNBZ0FsgXRBdgF4gXyBfkFCQYWBiUGNQY7BlAG
>> "%~1" echo cwZ6BogGkAamBtsG8QYMBwMAAQAEAAIAAABsBUYBAABsBUYBAgBpAAMAAgBrAAUA
>> "%~1" echo HAK8AscCgAS6Bs4G+GQAAB8ABIAAAAAAAAAAAAAAAAAAAAAAHAAAAAQAAAAAAAAA
>> "%~1" echo AAAAAAEARQAAAAAABAAAAAAAAAAAAAAAAQBOAAAAAAADAAIABAACAAUAAgAGAAIA
>> "%~1" echo BwACAAkACAAAAAAAADxNb2R1bGU+AFF1ZXN0QWRiV2ViVWkuZXhlAFF1ZXN0QWRi
>> "%~1" echo V2ViVWkAQ21kUmVzdWx0AENhcHR1cmUAU25hcHNob3QAbXNjb3JsaWIAU3lzdGVt
>> "%~1" echo AE9iamVjdABBZGJQYXRoAFRva2VuAFBvcnQAUm9vdERpcgBMb2dEaXIATG9nRmls
>> "%~1" echo ZQBMb2dMb2NrAFN5c3RlbS5UZXh0AEVuY29kaW5nAFV0ZjhOb0JvbQBNYWluAFN5
>> "%~1" echo c3RlbS5OZXQuU29ja2V0cwBUY3BDbGllbnQAU2VydmUAU3lzdGVtLkNvbGxlY3Rp
>> "%~1" echo b25zLkdlbmVyaWMARGljdGlvbmFyeWAyAFN0YXR1cwBBY3Rpb24ATG9ncwBFeHBv
>> "%~1" echo cnRSZXBvcnQARXhwb3J0VXJsAFN5c3RlbS5JTwBTdHJlYW0AU2VydmVFeHBvcnQA
>> "%~1" echo RGVidWdNb2RlAENvbnNlcnZhdGl2ZQBDdXJyZW50U2VyaWFsAEluaXRMb2cATG9n
>> "%~1" echo AFJlYWRMb2dUYWlsAFNlbGVjdERldmljZQBQcm9wAFNldHRpbmcAU2gAQQBNdXN0
>> "%~1" echo U2gATXVzdEEARW5zdXJlQmFja3VwAFN0cmluZ0J1aWxkZXIAV3JpdGVCYWNrdXBM
>> "%~1" echo aW5lAFJlc3RvcmVCYWNrdXAAQmFja3VwRmlsZQBGaWxsQmF0dGVyeQBGaWxsUG93
>> "%~1" echo ZXIARmlsbENvbnRyb2xsZXJzRmFzdABGaWxsUmVzb3VyY2VzAEZpbGxWaXJ0dWFs
>> "%~1" echo RGVza3RvcABGaWxsRGlzcGxheUxpdGUARmlsbFRoZXJtYWxMaXRlAEZpbGxGYWN0
>> "%~1" echo b3J5TGl0ZQBDb2xsZWN0U25hcHNob3QAQWRkU2hlbGxDYXB0dXJlAEFkZENhcHR1
>> "%~1" echo cmUAQ2FwAEZpbGxTbmFwc2hvdEZpZWxkcwBCdWlsZFJlcG9ydEh0bWwAQWRkSW52
>> "%~1" echo b2ljZUZhY3RzAEFkZEludm9pY2VSYXcAV2lmaUlwAFJ1bgBSdW5SZXN1bHQASm9p
>> "%~1" echo bkFyZ3MAUXVvdGVBcmcASm9pbk5vbkVtcHR5AEJhdHRlcnlTdGF0dXMAQmF0dGVy
>> "%~1" echo eUhlYWx0aABQb3dlclNvdXJjZQBBZnRlckNvbG9uAEFmdGVyRXF1YWxzAEZpbmRM
>> "%~1" echo aW5lAEZpZWxkAEZpbmRQYWNrYWdlRmllbGQATWVtR2IAUHJvcEZyb20ARmlyc3RM
>> "%~1" echo aW5lAEJldHdlZW4AUmVnZXhWYWx1ZQBGaXJzdFJlZ2V4AEV4dHJhY3RKc29uaXNo
>> "%~1" echo AFN0b3JhZ2VTdW1tYXJ5AE1lbW9yeVN1bW1hcnkAQ3B1U3VtbWFyeQBEaXNwbGF5
>> "%~1" echo U3VtbWFyeQBUaGVybWFsU3VtbWFyeQBVc2JTdW1tYXJ5AFdpZmlTdW1tYXJ5AEJs
>> "%~1" echo dWV0b290aFN1bW1hcnkAQ2FtZXJhU3VtbWFyeQBGYWN0b3J5U3VtbWFyeQBWaXJ0
>> "%~1" echo dWFsRGVza3RvcFN1bW1hcnkAQ291bnRQYWNrYWdlTGluZXMAQ291bnRQcmVmaXhM
>> "%~1" echo aW5lcwBDb3VudFJlZ2V4AFYASABQcml2YWN5AEFkYlNvdXJjZUxhYmVsAFJlZGFj
>> "%~1" echo dExvb3NlAFJlZGFjdABTZXJpYWxNYXNrAENsZWFuAExpbmVzAFZhbGlkTnMAU2Fm
>> "%~1" echo ZU5hbWUARGFuZ2Vyb3VzQWN0aW9uAERlbmllZFNldHRpbmcAU2hlbGxRdW90ZQBP
>> "%~1" echo awBFcnJvcgBDaGVja1Rva2VuAFF1ZXJ5AFVybABXcml0ZUpzb24AV3JpdGVCeXRl
>> "%~1" echo cwBKc29uAEVzYwBIdG1sAC5jdG9yAE91dHB1dABFeGl0Q29kZQBUaW1lZE91dABn
>> "%~1" echo ZXRfVGV4dABUZXh0AE5hbWUAQ29tbWFuZABEdXJhdGlvbk1zAENyZWF0ZWQAU2Vy
>> "%~1" echo aWFsAERldmljZUxpbmUARmllbGRzAExpc3RgMQBDYXB0dXJlcwBXYXJuaW5ncwBh
>> "%~1" echo cmdzAGNsaWVudABhY3Rpb24AcXVlcnkAc3RhbXAAbmFtZQBzdHJlYW0AcGF0aABz
>> "%~1" echo ZXJpYWwAYmFzZURpcgB0ZXh0AGRldmljZUxpbmUAU3lzdGVtLlJ1bnRpbWUuSW50
>> "%~1" echo ZXJvcFNlcnZpY2VzAE91dEF0dHJpYnV0ZQBoaW50AG5zAGtleQB0aW1lb3V0AGNv
>> "%~1" echo bW1hbmQAUGFyYW1BcnJheUF0dHJpYnV0ZQBzYgBkAHNuYXAAcmVxdWlyZWQAc2Fm
>> "%~1" echo ZQB0aXRsZQBmAGRlZnMAZmlsZQBzAGEAYgB2AG5lZWRsZQBsaW5lAGxlZnQAcmln
>> "%~1" echo aHQAcGF0dGVybgBkZgBtZW0AY3B1AGRpc3BsYXkAdGhlcm1hbAB1c2IAd2lmaQBp
>> "%~1" echo cEFkZHIAYnQAY2FtZXJhAHNlbnNvcgBwcmVmaXgAdmFsdWUAbXNnAHEAdHlwZQBi
>> "%~1" echo b2R5AFN5c3RlbS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMAQ29tcGlsYXRpb25S
>> "%~1" echo ZWxheGF0aW9uc0F0dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJpbGl0eUF0dHJpYnV0
>> "%~1" echo ZQA8TWFpbj5iX18wAG8AU3lzdGVtLlRocmVhZGluZwBXYWl0Q2FsbGJhY2sAQ1Mk
>> "%~1" echo PD45X19DYWNoZWRBbm9ueW1vdXNNZXRob2REZWxlZ2F0ZTEAQ29tcGlsZXJHZW5l
>> "%~1" echo cmF0ZWRBdHRyaWJ1dGUAQ2xvc2UARXhjZXB0aW9uAGdldF9NZXNzYWdlAFN0cmlu
>> "%~1" echo ZwBDb25jYXQAZ2V0X1VURjgAQ29uc29sZQBzZXRfT3V0cHV0RW5jb2RpbmcAQXBw
>> "%~1" echo RG9tYWluAGdldF9DdXJyZW50RG9tYWluAGdldF9CYXNlRGlyZWN0b3J5AFN5c3Rl
>> "%~1" echo bS5OZXQASVBBZGRyZXNzAFBhcnNlAFRjcExpc3RlbmVyAFN0YXJ0AFdyaXRlTGlu
>> "%~1" echo ZQBDb25zb2xlS2V5SW5mbwBSZWFkS2V5AEludDMyAFN5c3RlbS5EaWFnbm9zdGlj
>> "%~1" echo cwBQcm9jZXNzAEFjY2VwdFRjcENsaWVudABUaHJlYWRQb29sAFF1ZXVlVXNlcldv
>> "%~1" echo cmtJdGVtAHNldF9SZWNlaXZlVGltZW91dABzZXRfU2VuZFRpbWVvdXQATmV0d29y
>> "%~1" echo a1N0cmVhbQBHZXRTdHJlYW0AU3RyZWFtUmVhZGVyAFRleHRSZWFkZXIAUmVhZExp
>> "%~1" echo bmUASXNOdWxsT3JFbXB0eQBDaGFyAFNwbGl0AFRvVXBwZXJJbnZhcmlhbnQAVXJp
>> "%~1" echo AGdldF9BYnNvbHV0ZVBhdGgAb3BfRXF1YWxpdHkAZ2V0X1F1ZXJ5AG9wX0luZXF1
>> "%~1" echo YWxpdHkAU3RyaW5nQ29tcGFyaXNvbgBTdGFydHNXaXRoAEdldEJ5dGVzAElEaXNw
>> "%~1" echo b3NhYmxlAERpc3Bvc2UAc2V0X0l0ZW0AZ2V0X0l0ZW0AVGhyZWFkAFNsZWVwAENv
>> "%~1" echo bnRhaW5zS2V5AERhdGVUaW1lAGdldF9Ob3cAVG9TdHJpbmcAUGF0aABDb21iaW5l
>> "%~1" echo AERpcmVjdG9yeQBEaXJlY3RvcnlJbmZvAENyZWF0ZURpcmVjdG9yeQBGaWxlAFdy
>> "%~1" echo aXRlQWxsVGV4dABUaW1lU3BhbgBvcF9TdWJ0cmFjdGlvbgBnZXRfVG90YWxNaWxs
>> "%~1" echo aXNlY29uZHMAU3lzdGVtLkdsb2JhbGl6YXRpb24AQ3VsdHVyZUluZm8AZ2V0X0lu
>> "%~1" echo dmFyaWFudEN1bHR1cmUASW50NjQASUZvcm1hdFByb3ZpZGVyAGdldF9Db3VudABU
>> "%~1" echo b0FycmF5AEpvaW4ARXNjYXBlRGF0YVN0cmluZwBnZXRfTGVuZ3RoAFN1YnN0cmlu
>> "%~1" echo ZwBVbmVzY2FwZURhdGFTdHJpbmcARGlyZWN0b3J5U2VwYXJhdG9yQ2hhcgBSZXBs
>> "%~1" echo YWNlAEluZGV4T2YARW5kc1dpdGgAR2V0RnVsbFBhdGgARXhpc3RzAFJlYWRBbGxC
>> "%~1" echo eXRlcwBUcmltAEFwcGVuZEFsbFRleHQATW9uaXRvcgBFbnRlcgBFbnZpcm9ubWVu
>> "%~1" echo dABnZXRfTmV3TGluZQBFeGl0AEdldFN0cmluZwBTdHJpbmdTcGxpdE9wdGlvbnMA
>> "%~1" echo QXBwZW5kTGluZQBBcHBlbmQAUmVhZEFsbExpbmVzAERvdWJsZQBOdW1iZXJTdHls
>> "%~1" echo ZXMAVHJ5UGFyc2UARXF1YWxzAEFkZABTdG9wd2F0Y2gAU3RhcnROZXcAU3RvcABn
>> "%~1" echo ZXRfRWxhcHNlZE1pbGxpc2Vjb25kcwBFbnVtZXJhdG9yAEdldEVudW1lcmF0b3IA
>> "%~1" echo Z2V0X0N1cnJlbnQATW92ZU5leHQAPD5jX19EaXNwbGF5Q2xhc3M1AHJlc3VsdAA8
>> "%~1" echo PmNfX0Rpc3BsYXlDbGFzczcAQ1MkPD44X19sb2NhbHM2AHAAPFJ1blJlc3VsdD5i
>> "%~1" echo X18zADxSdW5SZXN1bHQ+Yl9fNABnZXRfU3RhbmRhcmRPdXRwdXQAUmVhZFRvRW5k
>> "%~1" echo AGdldF9TdGFuZGFyZEVycm9yAFByb2Nlc3NTdGFydEluZm8Ac2V0X0ZpbGVOYW1l
>> "%~1" echo AHNldF9Bcmd1bWVudHMAc2V0X1VzZVNoZWxsRXhlY3V0ZQBzZXRfUmVkaXJlY3RT
>> "%~1" echo dGFuZGFyZE91dHB1dABzZXRfUmVkaXJlY3RTdGFuZGFyZEVycm9yAHNldF9DcmVh
>> "%~1" echo dGVOb1dpbmRvdwBUaHJlYWRTdGFydABXYWl0Rm9yRXhpdABLaWxsAGdldF9FeGl0
>> "%~1" echo Q29kZQA8UHJpdmF0ZUltcGxlbWVudGF0aW9uRGV0YWlscz57NzI3QkZBQTUtQTQy
>> "%~1" echo RC00RDVDLTk4MjAtMEYwRkJERURCNzJCfQBWYWx1ZVR5cGUAX19TdGF0aWNBcnJh
>> "%~1" echo eUluaXRUeXBlU2l6ZT0xNgAkJG1ldGhvZDB4NjAwMDAyZS0xAFJ1bnRpbWVIZWxw
>> "%~1" echo ZXJzAEFycmF5AFJ1bnRpbWVGaWVsZEhhbmRsZQBJbml0aWFsaXplQXJyYXkASW5k
>> "%~1" echo ZXhPZkFueQBUcmltRW5kAFN5c3RlbS5UZXh0LlJlZ3VsYXJFeHByZXNzaW9ucwBS
>> "%~1" echo ZWdleABNYXRjaABSZWdleE9wdGlvbnMAR3JvdXAAZ2V0X1N1Y2Nlc3MAR3JvdXBD
>> "%~1" echo b2xsZWN0aW9uAGdldF9Hcm91cHMAZ2V0X1ZhbHVlAEVzY2FwZQBNYXRjaENvbGxl
>> "%~1" echo Y3Rpb24ATWF0Y2hlcwBXZWJVdGlsaXR5AEh0bWxFbmNvZGUAPFJlZGFjdExvb3Nl
>> "%~1" echo PmJfXzkAbQBNYXRjaEV2YWx1YXRvcgBDUyQ8PjlfX0NhY2hlZEFub255bW91c01l
>> "%~1" echo dGhvZERlbGVnYXRlYQBJc01hdGNoAGdldF9DaGFycwBJc0xldHRlck9yRGlnaXQA
>> "%~1" echo VG9Mb3dlckludmFyaWFudABnZXRfQVNDSUkAV3JpdGUAS2V5VmFsdWVQYWlyYDIA
>> "%~1" echo Z2V0X0tleQBDb252ZXJ0AEZyb21CYXNlNjRTdHJpbmcALmNjdG9yAEd1aWQATmV3
>> "%~1" echo R3VpZABVVEY4RW5jb2RpbmcAAAAAD/eLQmy/fgt6Al84Xhr/ARMxADIANwAuADAA
>> "%~1" echo LgAwAC4AMQAATVEAdQBlAHMAdAAgAEEARABCACAAVwBlAGIAVQBJACAAL1SoUjFZ
>> "%~1" echo JY0a/zgANwA2ADUALQA4ADcAOAA1ACAA73rjU/2QDU7vUyh1AjABLS9UqFIxWSWN
>> "%~1" echo Gv84ADcANgA1AC0AOAA3ADgANQAgAO9641P9kA1O71ModQIwASNoAHQAdABwADoA
>> "%~1" echo LwAvADEAMgA3AC4AMAAuADAALgAxADoAABEvAD8AdABvAGsAZQBuAD0AAC1RAHUA
>> "%~1" echo ZQBzAHQAIABBAEQAQgAgAFcAZQBiAFUASQAgAA1noVLyXS9UqFIa/wE96lPRdixU
>> "%~1" echo IAAxADIANwAuADAALgAwAC4AMQAb/3NR7ZUsZ5d641MOVCAAVwBlAGIAVQBJACAA
>> "%~1" echo XFBiawIwAQtBAEQAQgA6ACAAAAnlZddfOgAgAAEtDWehUi9UqFIa/2gAdAB0AHAA
>> "%~1" echo OgAvAC8AMQAyADcALgAwAC4AMAAuADEAOgABAy8AAA8dUstZ3o+lY7ZyAWAa/wED
>> "%~1" echo IAAAD/eLQmwEWQZ0MVkljRr/ARcvAGEAcABpAC8AcwB0AGEAdAB1AHMAABF0AG8A
>> "%~1" echo awBlAG4AIADgZUhlARcvAGEAcABpAC8AYQBjAHQAaQBvAG4AAAlQAE8AUwBUAAAj
>> "%~1" echo 7k85Zc1kXE/FX3uYf08odSAAUABPAFMAVAAgAPeLQmwCMAENYQBjAHQAaQBvAG4A
>> "%~1" echo AA9jAG8AbgBmAGkAcgBtAAAHWQBFAFMAABdxU2mWzWRcTwCXgYmMTiFrbnikiwIw
>> "%~1" echo ARMvAGEAcABpAC8AbABvAGcAcwAAFy8AYQBwAGkALwBlAHgAcABvAHIAdAAAH/xb
>> "%~1" echo +lHFX3uYf08odSAAUABPAFMAVAAgAPeLQmwCMAETLwBlAHgAcABvAHIAdABzAC8A
>> "%~1" echo ADN0AGUAeAB0AC8AcABsAGEAaQBuADsAIABjAGgAYQByAHMAZQB0AD0AdQB0AGYA
>> "%~1" echo LQA4AAEZLwBmAGEAdgBpAGMAbwBuAC4AaQBjAG8AABtpAG0AYQBnAGUALwBzAHYA
>> "%~1" echo ZwArAHgAbQBsAACBszwAcwB2AGcAIAB4AG0AbABuAHMAPQAnAGgAdAB0AHAAOgAv
>> "%~1" echo AC8AdwB3AHcALgB3ADMALgBvAHIAZwAvADIAMAAwADAALwBzAHYAZwAnACAAdgBp
>> "%~1" echo AGUAdwBCAG8AeAA9ACcAMAAgADAAIAAyADQAIAAyADQAJwAgAGYAaQBsAGwAPQAn
>> "%~1" echo AG4AbwBuAGUAJwAgAHMAdAByAG8AawBlAD0AJwAjADIANQA2ADMAZQBiACcAIABz
>> "%~1" echo AHQAcgBvAGsAZQAtAHcAaQBkAHQAaAA9ACcAMgAnAD4APABwAGEAdABoACAAZAA9
>> "%~1" echo ACcATQA2ACAAOQBoADEAMgBhADMAIAAzACAAMAAgADAAIAAxACAAMwAgADMAdgAz
>> "%~1" echo AGEAMwAgADMAIAAwACAAMAAgADEALQAzACAAMwBoAC0AMQAuADUAbAAtADIALgA1
>> "%~1" echo AC0AMwBoAC0ANABsAC0AMgAuADUAIAAzAEgANgBhADMAIAAzACAAMAAgADAAIAAx
>> "%~1" echo AC0AMwAtADMAdgAtADMAYQAzACAAMwAgADAAIAAwACAAMQAgADMALQAzAHoAJwAv
>> "%~1" echo AD4APAAvAHMAdgBnAD4AATF0AGUAeAB0AC8AaAB0AG0AbAA7ACAAYwBoAGEAcgBz
>> "%~1" echo AGUAdAA9AHUAdABmAC0AOAABD3MAZQByAHYAaQBjAGUAABUxADIANwAuADAALgAw
>> "%~1" echo AC4AMQA6AAAPYQBkAGIAUABhAHQAaAAAD2wAbwBnAEYAaQBsAGUAABdkAGUAdgBp
>> "%~1" echo AGMAZQBTAHQAYQB0AGUAABVkAGUAdgBpAGMAZQBMAGkAbgBlAAAJaABpAG4AdAAA
>> "%~1" echo E2MAbwBuAG4AZQBjAHQAZQBkAAANZABlAHYAaQBjAGUAAAtmAGEAbABzAGUAAAl0
>> "%~1" echo AHIAdQBlAAALtnIBYPuL1lMa/wENcwBlAHIAaQBhAGwAAAttAG8AZABlAGwAACFy
>> "%~1" echo AG8ALgBwAHIAbwBkAHUAYwB0AC4AbQBvAGQAZQBsAAAPYQBuAGQAcgBvAGkAZAAA
>> "%~1" echo MXIAbwAuAGIAdQBpAGwAZAAuAHYAZQByAHMAaQBvAG4ALgByAGUAbABlAGEAcwBl
>> "%~1" echo AAAHcwBkAGsAAClyAG8ALgBiAHUAaQBsAGQALgB2AGUAcgBzAGkAbwBuAC4AcwBk
>> "%~1" echo AGsAABtzAGUAYwB1AHIAaQB0AHkAUABhAHQAYwBoAAA/cgBvAC4AYgB1AGkAbABk
>> "%~1" echo AC4AdgBlAHIAcwBpAG8AbgAuAHMAZQBjAHUAcgBpAHQAeQBfAHAAYQB0AGMAaAAA
>> "%~1" echo GW0AYQBuAHUAZgBhAGMAdAB1AHIAZQByAAAvcgBvAC4AcAByAG8AZAB1AGMAdAAu
>> "%~1" echo AG0AYQBuAHUAZgBhAGMAdAB1AHIAZQByAAALYgByAGEAbgBkAAAhcgBvAC4AcABy
>> "%~1" echo AG8AZAB1AGMAdAAuAGIAcgBhAG4AZAAAF3AAcgBvAGQAdQBjAHQATgBhAG0AZQAA
>> "%~1" echo H3IAbwAuAHAAcgBvAGQAdQBjAHQALgBuAGEAbQBlAAAbcAByAG8AZAB1AGMAdABE
>> "%~1" echo AGUAdgBpAGMAZQAAI3IAbwAuAHAAcgBvAGQAdQBjAHQALgBkAGUAdgBpAGMAZQAA
>> "%~1" echo C2IAbwBhAHIAZAAAIXIAbwAuAHAAcgBvAGQAdQBjAHQALgBiAG8AYQByAGQAAAdz
>> "%~1" echo AG8AYwAAJ3IAbwAuAHMAbwBjAC4AbQBhAG4AdQBmAGEAYwB0AHUAcgBlAHIAABly
>> "%~1" echo AG8ALgBzAG8AYwAuAG0AbwBkAGUAbAAAD2IAdQBpAGwAZABJAGQAACdyAG8ALgBi
>> "%~1" echo AHUAaQBsAGQALgBkAGkAcwBwAGwAYQB5AC4AaQBkAAAXYgB1AGkAbABkAEIAcgBh
>> "%~1" echo AG4AYwBoAAAfcgBvAC4AYgB1AGkAbABkAC4AYgByAGEAbgBjAGgAACFiAHUAaQBs
>> "%~1" echo AGQASQBuAGMAcgBlAG0AZQBuAHQAYQBsAAA5cgBvAC4AYgB1AGkAbABkAC4AdgBl
>> "%~1" echo AHIAcwBpAG8AbgAuAGkAbgBjAHIAZQBtAGUAbgB0AGEAbAAAF3YAZQBuAGQAbwBy
>> "%~1" echo AFAAYQB0AGMAaAAAPXIAbwAuAHYAZQBuAGQAbwByAC4AYgB1AGkAbABkAC4AcwBl
>> "%~1" echo AGMAdQByAGkAdAB5AF8AcABhAHQAYwBoAAAHYQBiAGkAACVyAG8ALgBwAHIAbwBk
>> "%~1" echo AHUAYwB0AC4AYwBwAHUALgBhAGIAaQAADXcAaQBmAGkASQBwAAAVYQBkAGIARQBu
>> "%~1" echo AGEAYgBsAGUAZAAADWcAbABvAGIAYQBsAAAXYQBkAGIAXwBlAG4AYQBiAGwAZQBk
>> "%~1" echo AAAPYQBkAGIAVwBpAGYAaQAAIWEAZABiAF8AdwBpAGYAaQBfAGUAbgBhAGIAbABl
>> "%~1" echo AGQAAA1zAHQAYQB5AE8AbgAAMXMAdABhAHkAXwBvAG4AXwB3AGgAaQBsAGUAXwBw
>> "%~1" echo AGwAdQBnAGcAZQBkAF8AaQBuAAATdwBpAGYAaQBTAGwAZQBlAHAAACN3AGkAZgBp
>> "%~1" echo AF8AcwBsAGUAZQBwAF8AcABvAGwAaQBjAHkAABNzAGMAcgBlAGUAbgBPAGYAZgAA
>> "%~1" echo DXMAeQBzAHQAZQBtAAAlcwBjAHIAZQBlAG4AXwBvAGYAZgBfAHQAaQBtAGUAbwB1
>> "%~1" echo AHQAABlzAGwAZQBlAHAAVABpAG0AZQBvAHUAdAAADXMAZQBjAHUAcgBlAAAbcwBs
>> "%~1" echo AGUAZQBwAF8AdABpAG0AZQBvAHUAdAAAEWwAbwB3AFAAbwB3AGUAcgAAE2wAbwB3
>> "%~1" echo AF8AcABvAHcAZQByAAAZtnIBYPuL1lMa/2QAZQB2AGkAYwBlACAAARMgAGIAYQB0
>> "%~1" echo AHQAZQByAHkAPQAAGWIAYQB0AHQAZQByAHkATABlAHYAZQBsAAAPJQAgAHQAZQBt
>> "%~1" echo AHAAPQAAF2IAYQB0AHQAZQByAHkAVABlAG0AcAAAD0MAIAB3AGEAawBlAD0AABd3
>> "%~1" echo AGEAawBlAGYAdQBsAG4AZQBzAHMAABEgAHMAdABhAHkATwBuAD0AABMgAGEAZABi
>> "%~1" echo AFcAaQBmAGkAPQAAC81kXE8AX8tZGv8BESAAcwBlAHIAaQBhAGwAPQAAF3IAZQBz
>> "%~1" echo AHQAYQByAHQAXwBhAGQAYgAAF2sAaQBsAGwALQBzAGUAcgB2AGUAcgABGXMAdABh
>> "%~1" echo AHIAdAAtAHMAZQByAHYAZQByAAENcgBlAHMAdQBsAHQAAB3yXc2RL1Q1dRGB73og
>> "%~1" echo AEEARABCACAADWehUgIwAQMtAAEhoWwJZyhXv34UTvJdiGNDZ4R2IABRAHUAZQBz
>> "%~1" echo AHQAAjABFXMAYQBmAGUAXwBzAGwAZQBlAHAAADlpAG4AcAB1AHQAIABrAGUAeQBl
>> "%~1" echo AHYAZQBuAHQAIABLAEUAWQBDAE8ARABFAF8AUwBMAEUARQBQAABJ8l1iYA1Z3U+I
>> "%~1" echo WzxQdl7RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgAgACsAIABLAEUAWQBDAE8ARABF
>> "%~1" echo AF8AUwBMAEUARQBQAAIwARVrAGUAZQBwAF8AYQB3AGEAawBlAAAR8l2UXih17Xf2
>> "%~1" echo Zd1PO20CMAEVZABlAGIAdQBnAF8AbQBvAGQAZQAAf/JdL1QodQOM1YvlXVxPIWoP
>> "%~1" echo Xxr/VQBTAEIALwBBAEMAIADdTwFjJFWSkQEwVwBpAC0ARgBpACAADU4RTyB3ATBP
>> "%~1" echo XFVeIAAyADQAIAAPXPZlATAhat9iaU80YmCX0Y8CMNN+X2cOVPeLZ2JMiBwgYmAN
>> "%~1" echo WRFPIHeFjfZlHSACMAEbcgBlAHMAdABvAHIAZQBfAHMAbABlAGUAcAAAJfJdYmAN
>> "%~1" echo WWNrOF4RTyB3Dk4gADUAIAAGUp+UT1xVXoWN9mUCMAEZYwBvAG4AcwBlAHIAdgBh
>> "%~1" echo AHQAaQB2AGUAABPyXWJgDVndT4hb2J6kizxQAjABHXIAZQBzAHQAbwByAGUAXwBi
>> "%~1" echo AGEAYwBrAHUAcAAAL/Jdzk4HWf1OYmANWb6Lbn8M/3Ze0VMBkCAAcAByAG8AeABf
>> "%~1" echo AG8AcABlAG4AAjABE3AAcgBvAHgAXwBvAHAAZQBuAABnYQBtACAAYgByAG8AYQBk
>> "%~1" echo AGMAYQBzAHQAIAAtAGEAIABjAG8AbQAuAG8AYwB1AGwAdQBzAC4AdgByAHAAbwB3
>> "%~1" echo AGUAcgBtAGEAbgBhAGcAZQByAC4AcAByAG8AeABfAG8AcABlAG4AAR3yXdFTAZAg
>> "%~1" echo AHAAcgBvAHgAXwBvAHAAZQBuAAIwARVwAHIAbwB4AF8AYwBsAG8AcwBlAABpYQBt
>> "%~1" echo ACAAYgByAG8AYQBkAGMAYQBzAHQAIAAtAGEAIABjAG8AbQAuAG8AYwB1AGwAdQBz
>> "%~1" echo AC4AdgByAHAAbwB3AGUAcgBtAGEAbgBhAGcAZQByAC4AcAByAG8AeABfAGMAbABv
>> "%~1" echo AHMAZQABH/Jd0VMBkCAAcAByAG8AeABfAGMAbABvAHMAZQACMAERdwBpAHIAZQBs
>> "%~1" echo AGUAcwBzAAAFLQBzAAELdABjAHAAaQBwAAAJNQA1ADUANQAAI/Jd94tCbABfL1Tg
>> "%~1" echo Zb9+IABBAEQAQgAgADUANQA1ADUAAjABGXcAaQByAGUAbABlAHMAcwBfAG8AZgBm
>> "%~1" echo AABNcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAGEAZABi
>> "%~1" echo AF8AdwBpAGYAaQBfAGUAbgBhAGIAbABlAGQAIAAwAAAHdQBzAGIAAF3yXfeLQmxz
>> "%~1" echo Ue2V4GW/fiAAQQBEAEIADP9hAGQAYgBkACAA8l0HUt5WIABVAFMAQgAgACFqD18C
>> "%~1" echo MOWCU19NUi9m4GW/ft6PpWMM/61lAF9eXI5OY2s4XrBzYYwCMAETawBlAHkAXwBz
>> "%~1" echo AGwAZQBlAHAAACXyXdFTAZAgAEsARQBZAEMATwBEAEUAXwBTAEwARQBFAFAAAjAB
>> "%~1" echo FWsAZQB5AF8AdwBhAGsAZQB1AHAAADtpAG4AcAB1AHQAIABrAGUAeQBlAHYAZQBu
>> "%~1" echo AHQAIABLAEUAWQBDAE8ARABFAF8AVwBBAEsARQBVAFAAAEPyXdFTAZAgAEsARQBZ
>> "%~1" echo AEMATwBEAEUAXwBXAEEASwBFAFUAUAACMMVOKFcgAEEARABCACAAzU4oV79+9mUJ
>> "%~1" echo Z0hlAjABE3MAYwByAGUAZQBuAF8ANQBtAABbcwBlAHQAdABpAG4AZwBzACAAcAB1
>> "%~1" echo AHQAIABzAHkAcwB0AGUAbQAgAHMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBl
>> "%~1" echo AG8AdQB0ACAAMwAwADAAMAAwADAAADlzAGMAcgBlAGUAbgBfAG8AZgBmAF8AdABp
>> "%~1" echo AG0AZQBvAHUAdAAgAD0AIAAzADAAMAAwADAAMAACMAEVcwBjAHIAZQBlAG4AXwAy
>> "%~1" echo ADQAaAAAX3MAZQB0AHQAaQBuAGcAcwAgAHAAdQB0ACAAcwB5AHMAdABlAG0AIABz
>> "%~1" echo AGMAcgBlAGUAbgBfAG8AZgBmAF8AdABpAG0AZQBvAHUAdAAgADgANgA0ADAAMAAw
>> "%~1" echo ADAAMAAAPXMAYwByAGUAZQBuAF8AbwBmAGYAXwB0AGkAbQBlAG8AdQB0ACAAPQAg
>> "%~1" echo ADgANgA0ADAAMAAwADAAMAACMAERcwB0AGEAeQBfAG8AZgBmAABdcwBlAHQAdABp
>> "%~1" echo AG4AZwBzACAAcAB1AHQAIABnAGwAbwBiAGEAbAAgAHMAdABhAHkAXwBvAG4AXwB3
>> "%~1" echo AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBuACAAMAAAO3MAdABhAHkAXwBv
>> "%~1" echo AG4AXwB3AGgAaQBsAGUAXwBwAGwAdQBnAGcAZQBkAF8AaQBuACAAPQAgADAAAjAB
>> "%~1" echo F3MAdABhAHkAXwB1AHMAYgBfAGEAYwAAXXMAZQB0AHQAaQBuAGcAcwAgAHAAdQB0
>> "%~1" echo ACAAZwBsAG8AYgBhAGwAIABzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABlAF8AcABs
>> "%~1" echo AHUAZwBnAGUAZABfAGkAbgAgADMAADtzAHQAYQB5AF8AbwBuAF8AdwBoAGkAbABl
>> "%~1" echo AF8AcABsAHUAZwBnAGUAZABfAGkAbgAgAD0AIAAzAAIwASFyAGUAcwBlAHQAXwBz
>> "%~1" echo AGMAcgBlAGUAbgBfAG8AZgBmAABB8l3NkW5/IABzAGMAcgBlAGUAbgBfAG8AZgBm
>> "%~1" echo AF8AdABpAG0AZQBvAHUAdAAgAD0AIAAzADAAMAAwADAAMAACMAEbcgBlAHMAZQB0
>> "%~1" echo AF8AcwB0AGEAeQBfAG8AbgAAQ/JdzZFufyAAcwB0AGEAeQBfAG8AbgBfAHcAaABp
>> "%~1" echo AGwAZQBfAHAAbAB1AGcAZwBlAGQAXwBpAG4AIAA9ACAAMAACMAEhcgBlAHMAZQB0
>> "%~1" echo AF8AdwBpAGYAaQBfAHMAbABlAGUAcAAAT3MAZQB0AHQAaQBuAGcAcwAgAHAAdQB0
>> "%~1" echo ACAAZwBsAG8AYgBhAGwAIAB3AGkAZgBpAF8AcwBsAGUAZQBwAF8AcABvAGwAaQBj
>> "%~1" echo AHkAIAAxAAA18l3NkW5/IAB3AGkAZgBpAF8AcwBsAGUAZQBwAF8AcABvAGwAaQBj
>> "%~1" echo AHkAIAA9ACAAMQACMAEncgBlAHMAZQB0AF8AcwBsAGUAZQBwAF8AdABpAG0AZQBv
>> "%~1" echo AHUAdAAASXMAZQB0AHQAaQBuAGcAcwAgAGQAZQBsAGUAdABlACAAcwBlAGMAdQBy
>> "%~1" echo AGUAIABzAGwAZQBlAHAAXwB0AGkAbQBlAG8AdQB0AABB8l0gUmSWIABzAGwAZQBl
>> "%~1" echo AHAAXwB0AGkAbQBlAG8AdQB0ACAAdl7RUwGQIABwAHIAbwB4AF8AbwBwAGUAbgAC
>> "%~1" echo MAEdYwB1AHMAdABvAG0AXwBzAGUAdAB0AGkAbgBnAAAFbgBzAAAHawBlAHkAAAt2
>> "%~1" echo AGEAbAB1AGUAACNuAGEAbQBlAHMAcABhAGMAZQAgABZiLpUNVA1OCFTVbAIwASvl
>> "%~1" echo iy6VDVReXI5O2JrOmGmW+3zffi6VDP/yXTuWYmvqgZpbSU6ZUWVRAjABG3MAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAHAAdQB0ACAAAAMuAAAHIAA9ACAAACFjAHUAcwB0AG8AbQBf
>> "%~1" echo AGIAcgBvAGEAZABjAGEAcwB0AAAJbgBhAG0AZQAAEX9erWQNVPB5DU4IVNVsAjAB
>> "%~1" echo IWEAbQAgAGIAcgBvAGEAZABjAGEAcwB0ACAALQBhACAAAQ3yXdFTAZB/Xq1kGv8B
>> "%~1" echo Cypn5XfNZFxPAjABC81kXE+MWxBiGv8BESAAcgBlAHMAdQBsAHQAPQAABW8AawAA
>> "%~1" echo C2UAcgByAG8AcgAAC81kXE8xWSWNGv8BDyAAZQByAHIAbwByAD0AAAl0AGUAeAB0
>> "%~1" echo AAAl/Fv6UQBfy1ka/+pT+4uMW3RlvosHWeFPb2AgAEgAVABNAEwAAR95AHkAeQB5
>> "%~1" echo AE0ATQBkAGQAXwBIAEgAbQBtAHMAcwAAD2UAeABwAG8AcgB0AHMAADdRAHUAZQBz
>> "%~1" echo AHQAMwBfAGQAZQB2AGkAYwBlAF8AcAByAGkAdgBhAHQAZQBfAGYAdQBsAGwAXwAA
>> "%~1" echo Cy4AaAB0AG0AbAAAM1EAdQBlAHMAdAAzAF8AZABlAHYAaQBjAGUAXwBzAGgAYQBy
>> "%~1" echo AGUAXwBzAGEAZgBlAF8AABdwAHIAaQB2AGEAdABlAFAAYQB0AGgAABFzAGEAZgBl
>> "%~1" echo AFAAYQB0AGgAABVwAHIAaQB2AGEAdABlAFUAcgBsAAAPcwBhAGYAZQBVAHIAbAAA
>> "%~1" echo FWQAdQByAGEAdABpAG8AbgBNAHMAABlzAGUAYwB0AGkAbwBuAEMAbwB1AG4AdAAA
>> "%~1" echo EXcAYQByAG4AaQBuAGcAcwAAByAAfAAgAAAp8l0fdRBiwXkJZ4xbdGVIcoxUBlKr
>> "%~1" echo TolbaFFIciAASABUAE0ATAACMAEL/Fv6UYxbEGIa/wEHIAAvACAAAAv8W/pRMVkl
>> "%~1" echo jRr/AQ8/AHQAbwBrAGUAbgA9AAAFLgAuAAANXpfVbKViSlTvjYRfAQulYkpUDU5Y
>> "%~1" echo WyhXAQ/7i9ZTpWJKVDFZJY0a/wFPcwBlAHQAdABpAG4AZwBzACAAcAB1AHQAIABn
>> "%~1" echo AGwAbwBiAGEAbAAgAHcAaQBmAGkAXwBzAGwAZQBlAHAAXwBwAG8AbABpAGMAeQAg
>> "%~1" echo ADIAAElzAGUAdAB0AGkAbgBnAHMAIABwAHUAdAAgAHMAZQBjAHUAcgBlACAAcwBs
>> "%~1" echo AGUAZQBwAF8AdABpAG0AZQBvAHUAdAAgAC0AMQABHVEAdQBlAHMAdABfAEEARABC
>> "%~1" echo AF8ATABvAGcAcwAADXcAZQBiAHUAaQBfAAAJLgBsAG8AZwAAAQAnUQB1AGUAcwB0
>> "%~1" echo AF8AQQBEAEIAXwBXAGUAYgBVAEkALgBsAG8AZwAAL3kAeQB5AHkALQBNAE0ALQBk
>> "%~1" echo AGQAIABIAEgAOgBtAG0AOgBzAHMALgBmAGYAZgABBSAAIAAAE+Vl11+HZfZOGlwq
>> "%~1" echo ZxtS+l4CMAEP+4vWU+Vl118xWSWNGv8BWSpn0VOwcyAAQQBEAEIAIAC+iwdZAjDA
>> "%~1" echo aOVnAF/RUwWAIWoPXwEwVQBTAEIAIAADjNWLiGNDZwEwcGVuY79+jFQgAFcAaQBu
>> "%~1" echo AGQAbwB3AHMAIABxmqhSAjABD2QAZQB2AGkAYwBlAHMAAAUtAGwAAQ9MAGkAcwB0
>> "%~1" echo ACAAbwBmAAAXbQBvAGQAZQBsADoAUQB1AGUAcwB0AAAdcAByAG8AZAB1AGMAdAA6
>> "%~1" echo AGUAdQByAGUAawBhAAAbZABlAHYAaQBjAGUAOgBlAHUAcgBlAGsAYQAAGXUAbgBh
>> "%~1" echo AHUAdABoAG8AcgBpAHoAZQBkAAAPbwBmAGYAbABpAG4AZQAAMfJd3o+lY3Ze8l2I
>> "%~1" echo Y0NnDP/yXRhPSFEJkOliIABVAFMAQgAgAFEAdQBlAHMAdAACMAEl8l3ej6Vjdl7y
>> "%~1" echo XYhjQ2cM//JdCZDpYiAAUQB1AGUAcwB0AAIwAU/yXd6PpWN2XvJdiGNDZwIw6GwP
>> "%~1" echo YRr/KmfGiytSMFIgAFEAdQBlAHMAdAAgAItX91MM//JdCZDpYix7AE4qTiAAQQBE
>> "%~1" echo AEIAIAC+iwdZAjABO76LB1kqZ4hjQ2ca/zRiCk40WT5mDP8oVyAAVQBTAEIAIAAD
>> "%~1" echo jNWLiGNDZzlfl3rMkQmQ6WJBUbiLAjABO76LB1m7eb9+Gv/NkS9UIABBAEQAQgAg
>> "%~1" echo AA1noVIBMM2R0mMgAFUAUwBCACAAFmL0ZmJjcGVuY79+AjABFdFTsHO+iwdZRk+2
>> "%~1" echo cgFgAl84Xhr/AQ91AG4AawBuAG8AdwBuAAAJbgBvAG4AZQAAEWcAZQB0AHAAcgBv
>> "%~1" echo AHAAIAAAG3MAZQB0AHQAaQBuAGcAcwAgAGcAZQB0ACAAAAluAHUAbABsAAALcwBo
>> "%~1" echo AGUAbABsAAATQQBEAEIAIAB9VOROhY32ZRr/ARNBAEQAQgAgAH1U5E4xWSWNKAAB
>> "%~1" echo BSkAGv8BJSMAIABRAHUAZQBzAHQAIABBAEQAQgAgAOVdd1G+i25/B1n9TgETIwAg
>> "%~1" echo AGQAZQB2AGkAYwBlAD0AABUjACAAYwByAGUAYQB0AGUAZAA9AAAneQB5AHkAeQAt
>> "%~1" echo AE0ATQAtAGQAZAAgAEgASAA6AG0AbQA6AHMAcwABEfJdG1L6Xr6Lbn8HWf1OGv8B
>> "%~1" echo EfuL1lMHWf1OPFAxWSWNGv8BE6FsCWd+YjBSB1n9Todl9k4a/wEDIwAAIXMAZQB0
>> "%~1" echo AHQAaQBuAGcAcwAgAGQAZQBsAGUAdABlACAAAA/yXc5OB1n9TmJgDVka/wEDOgAA
>> "%~1" echo A18AAANcAAAncQB1AGUAcwB0AF8AYQBkAGIAXwBzAGUAdAB0AGkAbgBnAHMAXwAA
>> "%~1" echo CS4AYgBhAGsAAB9kAHUAbQBwAHMAeQBzACAAYgBhAHQAdABlAHIAeQAAC2wAZQB2
>> "%~1" echo AGUAbAAAF3QAZQBtAHAAZQByAGEAdAB1AHIAZQAABzAALgAjAAAbYgBhAHQAdABl
>> "%~1" echo AHIAeQBTAHQAYQB0AHUAcwAADXMAdABhAHQAdQBzAAAbYgBhAHQAdABlAHIAeQBI
>> "%~1" echo AGUAYQBsAHQAaAAADWgAZQBhAGwAdABoAAAXcABvAHcAZQByAFMAbwB1AHIAYwBl
>> "%~1" echo AAAbZAB1AG0AcABzAHkAcwAgAHAAbwB3AGUAcgAAGW0AVwBhAGsAZQBmAHUAbABu
>> "%~1" echo AGUAcwBzAAAPbQBTAHQAYQB5AE8AbgAAJW0AUAByAG8AeABpAG0AaQB0AHkAUABv
>> "%~1" echo AHMAaQB0AGkAdgBlAAAdbQBTAHQAYQB5AE8AbgBTAGUAdAB0AGkAbgBnAAA5bQBT
>> "%~1" echo AHQAYQB5AE8AbgBXAGgAaQBsAGUAUABsAHUAZwBnAGUAZABJAG4AUwBlAHQAdABp
>> "%~1" echo AG4AZwAAHXAAbwB3AGUAcgBTAGwAZQBlAHAATABpAG4AZQAAHVMAbABlAGUAcAAg
>> "%~1" echo AHQAaQBtAGUAbwB1AHQAOgAAK2MAbwBuAHQAcgBvAGwAbABlAHIATABlAGYAdABC
>> "%~1" echo AGEAdAB0AGUAcgB5AAAtYwBvAG4AdAByAG8AbABsAGUAcgBSAGkAZwBoAHQAQgBh
>> "%~1" echo AHQAdABlAHIAeQAAKWMAbwBuAHQAcgBvAGwAbABlAHIATABlAGYAdABTAHQAYQB0
>> "%~1" echo AHUAcwAAK2MAbwBuAHQAcgBvAGwAbABlAHIAUgBpAGcAaAB0AFMAdABhAHQAdQBz
>> "%~1" echo AAAdYwBvAG4AdAByAG8AbABsAGUAcgBIAGkAbgB0AAATKmf7i9ZTMFJLYsRnNXXP
>> "%~1" echo kQIwATFkAHUAbQBwAHMAeQBzACAATwBWAFIAUgBlAG0AbwB0AGUAUwBlAHIAdgBp
>> "%~1" echo AGMAZQAAEUIAYQB0AHQAZQByAHkAOgAAC1QAeQBwAGUAOgAACVQAeQBwAGUAAA9C
>> "%~1" echo AGEAdAB0AGUAcgB5AAANUwB0AGEAdAB1AHMAAAlMAGUAZgB0AAALUgBpAGcAaAB0
>> "%~1" echo AAAPcwB0AG8AcgBhAGcAZQAADW0AZQBtAG8AcgB5AAAbZABmACAALQBoACAALwBz
>> "%~1" echo AGQAYwBhAHIAZAABFUYAaQBsAGUAcwB5AHMAdABlAG0AAAkgAPJdKHUgAAEjYwBh
>> "%~1" echo AHQAIAAvAHAAcgBvAGMALwBtAGUAbQBpAG4AZgBvAAATTQBlAG0AVABvAHQAYQBs
>> "%~1" echo ADoAABtNAGUAbQBBAHYAYQBpAGwAYQBiAGwAZQA6AAAH71ModSAAAQ0gAC8AIAA7
>> "%~1" echo YKGLIAABE3YAZABQAGEAYwBrAGEAZwBlAAATdgBkAFYAZQByAHMAaQBvAG4AAC1W
>> "%~1" echo AGkAcgB0AHUAYQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBkAAAhZAB1
>> "%~1" echo AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBnAGUAIAAAE1AAYQBjAGsAYQBnAGUAIABb
>> "%~1" echo AAADXQAAGXYAZQByAHMAaQBvAG4ATgBhAG0AZQA9AAAdZABpAHMAcABsAGEAeQBT
>> "%~1" echo AHUAbQBtAGEAcgB5AAAfZAB1AG0AcABzAHkAcwAgAGQAaQBzAHAAbABhAHkAACNE
>> "%~1" echo AGkAcwBwAGwAYQB5AEQAZQB2AGkAYwBlAEkAbgBmAG8AAC8oAFwAZAB7ADMALAA1
>> "%~1" echo AH0AXABzACoAeABcAHMAKgBcAGQAewAzACwANQB9ACkAADdyAGUAbgBkAGUAcgBG
>> "%~1" echo AHIAYQBtAGUAUgBhAHQAZQBcAHMAKwAoAFsAMAAtADkALgBdACsAKQABJWQAZQBu
>> "%~1" echo AHMAaQB0AHkAXABzACsAKABbADAALQA5AF0AKwApAAEvRABlAHYAaQBjAGUAUABy
>> "%~1" echo AG8AZAB1AGMAdABJAG4AZgBvAHsAbgBhAG0AZQA9AAADLAAABUgAegAAEWQAZQBu
>> "%~1" echo AHMAaQB0AHkAIAAAHXQAaABlAHIAbQBhAGwAUwB1AG0AbQBhAHIAeQAALWQAdQBt
>> "%~1" echo AHAAcwB5AHMAIAB0AGgAZQByAG0AYQBsAHMAZQByAHYAaQBjAGUAAB1UAGgAZQBy
>> "%~1" echo AG0AYQBsACAAUwB0AGEAdAB1AHMAAENtAE4AYQBtAGUAPQBiAGEAdAB0AGUAcgB5
>> "%~1" echo ACwAXABzACoAbQBWAGEAbAB1AGUAPQAoAFsAMAAtADkALgBdACsAKQABPWIAYQB0
>> "%~1" echo AHQAZQByAHkAWwBeADAALQA5AF0AKwAoAFsAMAAtADkAXQArAFwALgBbADAALQA5
>> "%~1" echo AF0AKwApAAEPcwB0AGEAdAB1AHMAIAAAFyAALwAgAGIAYQB0AHQAZQByAHkAIAAA
>> "%~1" echo A0MAAB1mAGEAYwB0AG8AcgB5AFMAdQBtAG0AYQByAHkAACtkAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAAE0IAdQBpAGwAZABUAHkAcABl
>> "%~1" echo AAAVRABlAHYAaQBjAGUAVAB5AHAAZQAAE1QAaQBtAGUAcwB0AGEAbQBwAAAXbABv
>> "%~1" echo AGMAYQB0AGkAbwBuAF8AaQBkAAAVcwB0AGEAdABpAG8AbgBfAGkAZAAAEUYAYQBj
>> "%~1" echo AHQAbwByAHkAIAAACWwAbwBjACAAABFzAHQAYQB0AGkAbwBuACAAABdhAGQAYgBf
>> "%~1" echo AGQAZQB2AGkAYwBlAHMAAAVpAGQAAA9nAGUAdABwAHIAbwBwAAAfcwBlAHQAdABp
>> "%~1" echo AG4AZwBzAF8AZwBsAG8AYgBhAGwAAClzAGUAdAB0AGkAbgBnAHMAIABsAGkAcwB0
>> "%~1" echo ACAAZwBsAG8AYgBhAGwAAB9zAGUAdAB0AGkAbgBnAHMAXwBzAHkAcwB0AGUAbQAA
>> "%~1" echo KXMAZQB0AHQAaQBuAGcAcwAgAGwAaQBzAHQAIABzAHkAcwB0AGUAbQAAH3MAZQB0
>> "%~1" echo AHQAaQBuAGcAcwBfAHMAZQBjAHUAcgBlAAApcwBlAHQAdABpAG4AZwBzACAAbABp
>> "%~1" echo AHMAdAAgAHMAZQBjAHUAcgBlAAAPYgBhAHQAdABlAHIAeQAAC3AAbwB3AGUAcgAA
>> "%~1" echo D2QAaQBzAHAAbABhAHkAABdkAHUAbQBwAHMAeQBzACAAdQBzAGIAAAl3AGkAZgBp
>> "%~1" echo AAAZZAB1AG0AcABzAHkAcwAgAHcAaQBmAGkAABljAG8AbgBuAGUAYwB0AGkAdgBp
>> "%~1" echo AHQAeQAAKWQAdQBtAHAAcwB5AHMAIABjAG8AbgBuAGUAYwB0AGkAdgBpAHQAeQAA
>> "%~1" echo E2IAbAB1AGUAdABvAG8AdABoAAAzZAB1AG0AcABzAHkAcwAgAGIAbAB1AGUAdABv
>> "%~1" echo AG8AdABoAF8AbQBhAG4AYQBnAGUAcgAADWMAYQBtAGUAcgBhAAApZAB1AG0AcABz
>> "%~1" echo AHkAcwAgAG0AZQBkAGkAYQAuAGMAYQBtAGUAcgBhAAAbcwBlAG4AcwBvAHIAcwBl
>> "%~1" echo AHIAdgBpAGMAZQAAD3QAaABlAHIAbQBhAGwAAAtpAG4AcAB1AHQAABtkAHUAbQBw
>> "%~1" echo AHMAeQBzACAAaQBuAHAAdQB0AAARcABhAGMAawBhAGcAZQBzAAAtcABtACAAbABp
>> "%~1" echo AHMAdAAgAHAAYQBjAGsAYQBnAGUAcwAgAC0AZgAgAC0AaQABEWYAZQBhAHQAdQBy
>> "%~1" echo AGUAcwAAIXAAbQAgAGwAaQBzAHQAIABmAGUAYQB0AHUAcgBlAHMAABNsAGkAYgBy
>> "%~1" echo AGEAcgBpAGUAcwAANWMAbQBkACAAcABhAGMAawBhAGcAZQAgAGwAaQBzAHQAIABs
>> "%~1" echo AGkAYgByAGEAcgBpAGUAcwAABWQAZgAAJ2QAZgAgAC0AaAAgAC8AZABhAHQAYQAg
>> "%~1" echo AC8AcwBkAGMAYQByAGQAAQ9tAGUAbQBpAG4AZgBvAAAPYwBwAHUAaQBuAGYAbwAA
>> "%~1" echo I2MAYQB0ACAALwBwAHIAbwBjAC8AYwBwAHUAaQBuAGYAbwAAC3UAbgBhAG0AZQAA
>> "%~1" echo EXUAbgBhAG0AZQAgAC0AYQABD2kAcABfAGEAZABkAHIAAA9pAHAAIABhAGQAZABy
>> "%~1" echo AAARaQBwAF8AcgBvAHUAdABlAAARaQBwACAAcgBvAHUAdABlAAAddgBpAHIAdAB1
>> "%~1" echo AGEAbABkAGUAcwBrAHQAbwBwAABNZAB1AG0AcABzAHkAcwAgAHAAYQBjAGsAYQBn
>> "%~1" echo AGUAIABWAGkAcgB0AHUAYQBsAEQAZQBzAGsAdABvAHAALgBBAG4AZAByAG8AaQBk
>> "%~1" echo AAAfbwBjAHUAbAB1AHMAXwBwAGEAYwBrAGEAZwBlAHMAADVkAHUAbQBwAHMAeQBz
>> "%~1" echo ACAAcABhAGMAawBhAGcAZQAgAGMAbwBtAC4AbwBjAHUAbAB1AHMAACdsAG8AZwBj
>> "%~1" echo AGEAdABfAHQAYQBpAGwAXwBwAHIAaQB2AGEAdABlAAAjbABvAGcAYwBhAHQAIAAt
>> "%~1" echo AGQAIAAtAHQAIAAzADAAMAAwAAEJYQBkAGIAIAAAByAAhY32ZQEJIAAxWSWNGv8B
>> "%~1" echo DyAA11NQlhZi4GWTj/pRAQ9jAHIAZQBhAHQAZQBkAAAPcAByAG8AZAB1AGMAdAAA
>> "%~1" echo F2YAaQBuAGcAZQByAHAAcgBpAG4AdAAAKXIAbwAuAGIAdQBpAGwAZAAuAGYAaQBu
>> "%~1" echo AGcAZQByAHAAcgBpAG4AdAAADWsAZQByAG4AZQBsAAADJQAAE3AAcgBvAHgAaQBt
>> "%~1" echo AGkAdAB5AAAHYwBwAHUAAAtwAGEAbgBlAGwAACNEAGUAdgBpAGMAZQBQAHIAbwBk
>> "%~1" echo AHUAYwB0AEkAbgBmAG8AAA9mAGEAYwB0AG8AcgB5AAAbZgBhAGMAdABvAHIAeQBE
>> "%~1" echo AGUAdgBpAGMAZQAAGWYAYQBjAHQAbwByAHkAQgB1AGkAbABkAAAXZgBhAGMAdABv
>> "%~1" echo AHIAeQBUAGkAbQBlAAAfZgBhAGMAdABvAHIAeQBMAG8AYwBhAHQAaQBvAG4AAB1m
>> "%~1" echo AGEAYwB0AG8AcgB5AFMAdABhAHQAaQBvAG4AACVmAGEAYwB0AG8AcgB5AFMAdABh
>> "%~1" echo AHQAaQBvAG4AVAB5AHAAZQAAGXMAdABhAHQAaQBvAG4AXwB0AHkAcABlAAAXZgBh
>> "%~1" echo AGMAdABvAHIAeQBUAGUAcwB0AAAXYwBhAGwAXwB0AGUAcwB0AF8AaQBkAAAfZgBh
>> "%~1" echo AGMAdABvAHIAeQBPAHAAZQByAGEAdABvAHIAABdvAHAAZQByAGEAdABvAHIAXwBp
>> "%~1" echo AGQAACVmAGEAYwB0AG8AcgB5AEMAYQBsAGkAYgByAGEAdABpAG8AbgAAIWMAYQBs
>> "%~1" echo AGkAYgByAGEAdABpAG8AbgBfAHQAeQBwAGUAACNvAG4AbABpAG4AZQBDAGEAbABp
>> "%~1" echo AGIAcgBhAHQAaQBvAG4AAC92AGUAZwBhAF8AbwBuAGwAaQBuAGUAXwBjAGEAbABp
>> "%~1" echo AGIAcgBhAHQAaQBvAG4AADfAaEttMFIgAHYAZQBnAGEAXwBvAG4AbABpAG4AZQBf
>> "%~1" echo AGMAYQBsAGkAYgByAGEAdABpAG8AbgABEWYAZQBhAHQAdQByAGUAOgAABXYAZAAA
>> "%~1" echo MVEAdQBlAHMAdAAgAEEARABCACAAvosHWaFboYulYkpUIAAtACAAwXkJZ4xbdGVI
>> "%~1" echo cgExUQB1AGUAcwB0ACAAQQBEAEIAIAC+iwdZoVuhi6ViSlQgAC0AIAAGUqtOiVto
>> "%~1" echo UUhyARlQAFIASQBWAEEAVABFACAARgBVAEwATAAAFVMASABBAFIARQAtAFMAQQBG
>> "%~1" echo AEUAAQtRAEEARABCAC0AAR95AHkAeQB5AE0ATQBkAGQALQBIAEgAbQBtAHMAcwAB
>> "%~1" echo gRE8ACEAZABvAGMAdAB5AHAAZQAgAGgAdABtAGwAPgA8AGgAdABtAGwAIABsAGEA
>> "%~1" echo bgBnAD0AIgB6AGgALQBDAE4AIgA+ADwAaABlAGEAZAA+ADwAbQBlAHQAYQAgAGMA
>> "%~1" echo aABhAHIAcwBlAHQAPQAiAHUAdABmAC0AOAAiAD4APABtAGUAdABhACAAbgBhAG0A
>> "%~1" echo ZQA9ACIAdgBpAGUAdwBwAG8AcgB0ACIAIABjAG8AbgB0AGUAbgB0AD0AIgB3AGkA
>> "%~1" echo ZAB0AGgAPQBkAGUAdgBpAGMAZQAtAHcAaQBkAHQAaAAsAGkAbgBpAHQAaQBhAGwA
>> "%~1" echo LQBzAGMAYQBsAGUAPQAxACIAPgA8AHQAaQB0AGwAZQA+AAERPAAvAHQAaQB0AGwA
>> "%~1" echo ZQA+AAAPPABzAHQAeQBsAGUAPgAAjbM6AHIAbwBvAHQAewAtAC0AcABhAGcAZQA6
>> "%~1" echo ACMAZQBlAGYAMQBmADUAOwAtAC0AcABhAHAAZQByADoAIwBmAGYAZgA7AC0ALQBp
>> "%~1" echo AG4AawA6ACMAMQA4ADIAMAAzADMAOwAtAC0AbQB1AHQAZQBkADoAIwA2ADYANwAw
>> "%~1" echo ADgANQA7AC0ALQBsAGkAbgBlADoAIwBkADgAZQAwAGUAYgA7AC0ALQBsAGkAbgBl
>> "%~1" echo ADIAOgAjAGUAZABmADEAZgA2ADsALQAtAHMAbwBmAHQAOgAjAGYANwBmADkAZgBj
>> "%~1" echo ADsALQAtAGEAYwBjAGUAbgB0ADoAIwAxAGQANABlAGQAOAA7AC0ALQBhAGMAYwBl
>> "%~1" echo AG4AdAAyADoAIwAwAGYAMQA3ADIAYQA7AC0ALQBvAGsAOgAjADEAMQA4ADQANAA3
>> "%~1" echo ADsALQAtAHcAYQByAG4AOgAjADkAYQA1AGIAMAAwADsALQAtAHMAaABhAGQAbwB3
>> "%~1" echo ADoAMAAgADEAOABwAHgAIAA0ADgAcAB4ACAAcgBnAGIAYQAoADEANQAsADIAMwAs
>> "%~1" echo ADQAMgAsAC4AMQAzACkAfQAqAHsAYgBvAHgALQBzAGkAegBpAG4AZwA6AGIAbwBy
>> "%~1" echo AGQAZQByAC0AYgBvAHgAfQBoAHQAbQBsACwAYgBvAGQAeQB7AG0AYQByAGcAaQBu
>> "%~1" echo ADoAMAA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBwAGEAZwBl
>> "%~1" echo ACkAOwBjAG8AbABvAHIAOgB2AGEAcgAoAC0ALQBpAG4AawApADsAZgBvAG4AdAA6
>> "%~1" echo ADEANABwAHgALwAxAC4ANQAyACAAIgBTAGUAZwBvAGUAIABVAEkAIgAsACIATQBp
>> "%~1" echo AGMAcgBvAHMAbwBmAHQAIABZAGEASABlAGkAIgAsAEEAcgBpAGEAbAAsAHMAYQBu
>> "%~1" echo AHMALQBzAGUAcgBpAGYAOwBsAGUAdAB0AGUAcgAtAHMAcABhAGMAaQBuAGcAOgAw
>> "%~1" echo AH0ALgBzAGgAZQBlAHQAewB3AGkAZAB0AGgAOgBtAGkAbgAoADEAMQAyADAAcAB4
>> "%~1" echo ACwAYwBhAGwAYwAoADEAMAAwACUAIAAtACAANAAwAHAAeAApACkAOwBtAGEAcgBn
>> "%~1" echo AGkAbgA6ADMAMABwAHgAIABhAHUAdABvADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6
>> "%~1" echo AHYAYQByACgALQAtAHAAYQBwAGUAcgApADsAYgBvAHIAZABlAHIAOgAxAHAAeAAg
>> "%~1" echo AHMAbwBsAGkAZAAgACMAZABmAGUANgBmADAAOwBiAG8AeAAtAHMAaABhAGQAbwB3
>> "%~1" echo ADoAdgBhAHIAKAAtAC0AcwBoAGEAZABvAHcAKQB9AC4AcABhAGQAewBwAGEAZABk
>> "%~1" echo AGkAbgBnADoAMwA4AHAAeAAgADQANABwAHgAfQAuAGEAYwB0AGkAbwBuAHMAewBw
>> "%~1" echo AG8AcwBpAHQAaQBvAG4AOgBzAHQAaQBjAGsAeQA7AHQAbwBwADoAMAA7AHoALQBp
>> "%~1" echo AG4AZABlAHgAOgAzADsAZABpAHMAcABsAGEAeQA6AGYAbABlAHgAOwBqAHUAcwB0
>> "%~1" echo AGkAZgB5AC0AYwBvAG4AdABlAG4AdAA6AGYAbABlAHgALQBlAG4AZAA7AGcAYQBw
>> "%~1" echo ADoAOABwAHgAOwB3AGkAZAB0AGgAOgBtAGkAbgAoADEAMQAyADAAcAB4ACwAYwBh
>> "%~1" echo AGwAYwAoADEAMAAwACUAIAAtACAANAAwAHAAeAApACkAOwBtAGEAcgBnAGkAbgA6
>> "%~1" echo ADEAOABwAHgAIABhAHUAdABvACAALQAxADYAcAB4AH0ALgBiAHQAbgB7AGIAbwBy
>> "%~1" echo AGQAZQByADoAMQBwAHgAIABzAG8AbABpAGQAIAAjAGMAYgBkADUAZQAxADsAYgBh
>> "%~1" echo AGMAawBnAHIAbwB1AG4AZAA6ACMAZgBmAGYAOwBjAG8AbABvAHIAOgAjADAAZgAx
>> "%~1" echo ADcAMgBhADsAYgBvAHIAZABlAHIALQByAGEAZABpAHUAcwA6ADYAcAB4ADsAcABh
>> "%~1" echo AGQAZABpAG4AZwA6ADgAcAB4ACAAMQAyAHAAeAA7AGYAbwBuAHQALQB3AGUAaQBn
>> "%~1" echo AGgAdAA6ADgAMAAwADsAYwB1AHIAcwBvAHIAOgBwAG8AaQBuAHQAZQByAH0ALgBi
>> "%~1" echo AHQAbgAuAHAAcgBpAG0AYQByAHkAewBiAGEAYwBrAGcAcgBvAHUAbgBkADoAdgBh
>> "%~1" echo AHIAKAAtAC0AYQBjAGMAZQBuAHQAKQA7AGIAbwByAGQAZQByAC0AYwBvAGwAbwBy
>> "%~1" echo ADoAdgBhAHIAKAAtAC0AYQBjAGMAZQBuAHQAKQA7AGMAbwBsAG8AcgA6ACMAZgBm
>> "%~1" echo AGYAfQAuAGQAbwBjAC0AaABlAGEAZAB7AGQAaQBzAHAAbABhAHkAOgBnAHIAaQBk
>> "%~1" echo ADsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAx
>> "%~1" echo AGYAcgAgADMANAAwAHAAeAA7AGcAYQBwADoAMgA4AHAAeAA7AGIAbwByAGQAZQBy
>> "%~1" echo AC0AYgBvAHQAdABvAG0AOgAzAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAt
>> "%~1" echo AGEAYwBjAGUAbgB0ADIAKQA7AHAAYQBkAGQAaQBuAGcALQBiAG8AdAB0AG8AbQA6
>> "%~1" echo ADIANABwAHgAfQAuAGsAaQBjAGsAZQByAHsAZABpAHMAcABsAGEAeQA6AGkAbgBs
>> "%~1" echo AGkAbgBlAC0AYgBsAG8AYwBrADsAYwBvAGwAbwByADoAdgBhAHIAKAAtAC0AYQBj
>> "%~1" echo AGMAZQBuAHQAKQA7AGYAbwBuAHQALQBzAGkAegBlADoAMQAyAHAAeAA7AGYAbwBu
>> "%~1" echo AHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwADsAbABlAHQAdABlAHIALQBzAHAAYQBj
>> "%~1" echo AGkAbgBnADoALgAwADgAZQBtADsAdABlAHgAdAAtAHQAcgBhAG4AcwBmAG8AcgBt
>> "%~1" echo ADoAdQBwAHAAZQByAGMAYQBzAGUAOwBtAGEAcgBnAGkAbgAtAGIAbwB0AHQAbwBt
>> "%~1" echo ADoAMQAwAHAAeAB9AGgAMQB7AGYAbwBuAHQALQBzAGkAegBlADoAMwAyAHAAeAA7
>> "%~1" echo AGwAaQBuAGUALQBoAGUAaQBnAGgAdAA6ADEALgAxADIAOwBtAGEAcgBnAGkAbgA6
>> "%~1" echo ADAAIAAwACAAMQAwAHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAw
>> "%~1" echo ADsAYwBvAGwAbwByADoAIwAwAGYAMQA3ADIAYQB9AC4AcwB1AGIAewBjAG8AbABv
>> "%~1" echo AHIAOgB2AGEAcgAoAC0ALQBtAHUAdABlAGQAKQA7AG0AYQB4AC0AdwBpAGQAdABo
>> "%~1" echo ADoANgA4ADAAcAB4ADsAbQBhAHIAZwBpAG4AOgAwAH0ALgBtAGUAdABhAHsAYgBv
>> "%~1" echo AHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBu
>> "%~1" echo AGUAKQA7AGEAbABpAGcAbgAtAHMAZQBsAGYAOgBzAHQAYQByAHQAOwBtAGkAbgAt
>> "%~1" echo AHcAaQBkAHQAaAA6ADAAfQAuAG0AZQB0AGEALQByAG8AdwB7AGQAaQBzAHAAbABh
>> "%~1" echo AHkAOgBnAHIAaQBkADsAZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBs
>> "%~1" echo AHUAbQBuAHMAOgAxADEAOABwAHgAIABtAGkAbgBtAGEAeAAoADAALAAxAGYAcgAp
>> "%~1" echo ADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwAaQBk
>> "%~1" echo ACAAdgBhAHIAKAAtAC0AbABpAG4AZQAyACkAOwBtAGkAbgAtAGgAZQBpAGcAaAB0
>> "%~1" echo ADoAMwA4AHAAeAB9AC4AbQBlAHQAYQAtAHIAbwB3ADoAbABhAHMAdAAtAGMAaABp
>> "%~1" echo AGwAZAB7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0AOgAwAH0ALgBtAGUAdABh
>> "%~1" echo AC0AcgBvAHcAIABzAHAAYQBuAHsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQBy
>> "%~1" echo ACgALQAtAHMAbwBmAHQAKQA7AGMAbwBsAG8AcgA6AHYAYQByACgALQAtAG0AdQB0
>> "%~1" echo AGUAZAApADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOAAwADAAOwBwAGEAZABk
>> "%~1" echo AGkAbgBnADoAOQBwAHgAIAAxADIAcAB4ADsAYgBvAHIAZABlAHIALQByAGkAZwBo
>> "%~1" echo AHQAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAMgAp
>> "%~1" echo AH0ALgBtAGUAdABhAC0AcgBvAHcAIABiAHsAcABhAGQAZABpAG4AZwA6ADkAcAB4
>> "%~1" echo ACAAMQAyAHAAeAA7AG0AaQBuAC0AdwBpAGQAdABoADoAMAA7AG8AdgBlAHIAZgBs
>> "%~1" echo AG8AdwAtAHcAcgBhAHAAOgBhAG4AeQB3AGgAZQByAGUAOwB3AG8AcgBkAC0AYgBy
>> "%~1" echo AGUAYQBrADoAYgByAGUAYQBrAC0AdwBvAHIAZAB9AC4AcwB0AGEAbQBwAHsAZABp
>> "%~1" echo AHMAcABsAGEAeQA6AGkAbgBsAGkAbgBlAC0AYgBsAG8AYwBrADsAYgBvAHIAZABl
>> "%~1" echo AHIAOgAyAHAAeAAgAHMAbwBsAGkAZAAgAAEXdgBhAHIAKAAtAC0AdwBhAHIAbgAp
>> "%~1" echo AAETdgBhAHIAKAAtAC0AbwBrACkAAQ87AGMAbwBsAG8AcgA6AACbBzsAZgBvAG4A
>> "%~1" echo dAAtAHcAZQBpAGcAaAB0ADoAOQAwADAAOwBwAGEAZABkAGkAbgBnADoANABwAHgA
>> "%~1" echo IAA4AHAAeAA7AGIAbwByAGQAZQByAC0AcgBhAGQAaQB1AHMAOgA0AHAAeAA7AHQA
>> "%~1" echo cgBhAG4AcwBmAG8AcgBtADoAcgBvAHQAYQB0AGUAKAAtADEAZABlAGcAKQB9AC4A
>> "%~1" echo cABhAHIAdAB5AC0AZwByAGkAZAB7AGQAaQBzAHAAbABhAHkAOgBnAHIAaQBkADsA
>> "%~1" echo ZwByAGkAZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAxAGYA
>> "%~1" echo cgAgADEAZgByADsAZwBhAHAAOgAxADgAcAB4ADsAbQBhAHIAZwBpAG4AOgAyADYA
>> "%~1" echo cAB4ACAAMAB9AC4AYgBvAHgAewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwA
>> "%~1" echo aQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQApADsAYgBhAGMAawBnAHIAbwB1AG4A
>> "%~1" echo ZAA6ACMAZgBmAGYAOwBtAGkAbgAtAHcAaQBkAHQAaAA6ADAAfQAuAGIAbwB4ACAA
>> "%~1" echo aAAyACwALgBzAGUAYwB0AGkAbwBuACAAaAAyAHsAZgBvAG4AdAAtAHMAaQB6AGUA
>> "%~1" echo OgAxADMAcAB4ADsAdABlAHgAdAAtAHQAcgBhAG4AcwBmAG8AcgBtADoAdQBwAHAA
>> "%~1" echo ZQByAGMAYQBzAGUAOwBsAGUAdAB0AGUAcgAtAHMAcABhAGMAaQBuAGcAOgAuADAA
>> "%~1" echo OABlAG0AOwBjAG8AbABvAHIAOgAjADMANAA0ADAANQA0ADsAbQBhAHIAZwBpAG4A
>> "%~1" echo OgAwADsAYgBhAGMAawBnAHIAbwB1AG4AZAA6AHYAYQByACgALQAtAHMAbwBmAHQA
>> "%~1" echo KQA7AGIAbwByAGQAZQByAC0AYgBvAHQAdABvAG0AOgAxAHAAeAAgAHMAbwBsAGkA
>> "%~1" echo ZAAgAHYAYQByACgALQAtAGwAaQBuAGUAKQA7AHAAYQBkAGQAaQBuAGcAOgAxADAA
>> "%~1" echo cAB4ACAAMQAyAHAAeAB9AC4AYgBvAHgALQBiAG8AZAB5AHsAcABhAGQAZABpAG4A
>> "%~1" echo ZwA6ADEAMwBwAHgAIAAxADQAcAB4AH0ALgBiAGkAZwB7AGYAbwBuAHQALQBzAGkA
>> "%~1" echo egBlADoAMgAyAHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADkAMAAwADsA
>> "%~1" echo bQBhAHIAZwBpAG4ALQBiAG8AdAB0AG8AbQA6ADYAcAB4AH0ALgBtAHUAdABlAGQA
>> "%~1" echo ewBjAG8AbABvAHIAOgB2AGEAcgAoAC0ALQBtAHUAdABlAGQAKQB9AC4AYwBoAGkA
>> "%~1" echo cABzAHsAZABpAHMAcABsAGEAeQA6AGYAbABlAHgAOwBmAGwAZQB4AC0AdwByAGEA
>> "%~1" echo cAA6AHcAcgBhAHAAOwBnAGEAcAA6ADcAcAB4ADsAbQBhAHIAZwBpAG4ALQB0AG8A
>> "%~1" echo cAA6ADEAMgBwAHgAfQAuAGMAaABpAHAAewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAA
>> "%~1" echo cwBvAGwAaQBkACAAdgBhAHIAKAAtAC0AbABpAG4AZQApADsAYgBhAGMAawBnAHIA
>> "%~1" echo bwB1AG4AZAA6AHYAYQByACgALQAtAHMAbwBmAHQAKQA7AGIAbwByAGQAZQByAC0A
>> "%~1" echo cgBhAGQAaQB1AHMAOgA5ADkAOQBwAHgAOwBwAGEAZABkAGkAbgBnADoANQBwAHgA
>> "%~1" echo IAA5AHAAeAA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwAH0ALgBzAHUA
>> "%~1" echo bQBtAGEAcgB5AHsAZABpAHMAcABsAGEAeQA6AGcAcgBpAGQAOwBnAHIAaQBkAC0A
>> "%~1" echo dABlAG0AcABsAGEAdABlAC0AYwBvAGwAdQBtAG4AcwA6AHIAZQBwAGUAYQB0ACgA
>> "%~1" echo NAAsAG0AaQBuAG0AYQB4ACgAMAAsADEAZgByACkAKQA7AGIAbwByAGQAZQByADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAB2AGEAcgAoAC0ALQBsAGkAbgBlACkAOwBtAGEA
>> "%~1" echo cgBnAGkAbgA6ADIAMABwAHgAIAAwACAAMgA0AHAAeAB9AC4AcwB1AG0ALQBjAGUA
>> "%~1" echo bABsAHsAcABhAGQAZABpAG4AZwA6ADEAMwBwAHgAIAAxADQAcAB4ADsAYgBvAHIA
>> "%~1" echo ZABlAHIALQByAGkAZwBoAHQAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgA
>> "%~1" echo LQAtAGwAaQBuAGUAMgApADsAbQBpAG4ALQB3AGkAZAB0AGgAOgAwAH0ALgBzAHUA
>> "%~1" echo bQAtAGMAZQBsAGwAOgBsAGEAcwB0AC0AYwBoAGkAbABkAHsAYgBvAHIAZABlAHIA
>> "%~1" echo LQByAGkAZwBoAHQAOgAwAH0ALgBzAHUAbQAtAGMAZQBsAGwAIABzAHAAYQBuAHsA
>> "%~1" echo ZABpAHMAcABsAGEAeQA6AGIAbABvAGMAawA7AGMAbwBsAG8AcgA6AHYAYQByACgA
>> "%~1" echo LQAtAG0AdQB0AGUAZAApADsAZgBvAG4AdAAtAHMAaQB6AGUAOgAxADIAcAB4ADsA
>> "%~1" echo ZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOAAwADAAOwB0AGUAeAB0AC0AdAByAGEA
>> "%~1" echo bgBzAGYAbwByAG0AOgB1AHAAcABlAHIAYwBhAHMAZQB9AC4AcwB1AG0ALQBjAGUA
>> "%~1" echo bABsACAAYgB7AGQAaQBzAHAAbABhAHkAOgBiAGwAbwBjAGsAOwBmAG8AbgB0AC0A
>> "%~1" echo cwBpAHoAZQA6ADEAOABwAHgAOwBtAGEAcgBnAGkAbgAtAHQAbwBwADoANQBwAHgA
>> "%~1" echo OwBvAHYAZQByAGYAbABvAHcALQB3AHIAYQBwADoAYQBuAHkAdwBoAGUAcgBlADsA
>> "%~1" echo dwBvAHIAZAAtAGIAcgBlAGEAawA6AGIAcgBlAGEAawAtAHcAbwByAGQAfQAuAHMA
>> "%~1" echo ZQBjAHQAaQBvAG4AewBtAGEAcgBnAGkAbgAtAHQAbwBwADoAMgAyAHAAeAB9AC4A
>> "%~1" echo YQB1AGQAaQB0AC0AdABhAGIAbABlAHsAdwBpAGQAdABoADoAMQAwADAAJQA7AGIA
>> "%~1" echo bwByAGQAZQByAC0AYwBvAGwAbABhAHAAcwBlADoAYwBvAGwAbABhAHAAcwBlADsA
>> "%~1" echo YgBvAHIAZABlAHIAOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwA
>> "%~1" echo aQBuAGUAKQA7AHQAYQBiAGwAZQAtAGwAYQB5AG8AdQB0ADoAZgBpAHgAZQBkAH0A
>> "%~1" echo LgBhAHUAZABpAHQALQB0AGEAYgBsAGUAIAB0AGgAewBiAGEAYwBrAGcAcgBvAHUA
>> "%~1" echo bgBkADoAIwBmADIAZgA1AGYAOQA7AGMAbwBsAG8AcgA6ACMAMwA0ADQAMAA1ADQA
>> "%~1" echo OwB0AGUAeAB0AC0AYQBsAGkAZwBuADoAbABlAGYAdAA7AGYAbwBuAHQALQBzAGkA
>> "%~1" echo egBlADoAMQAyAHAAeAA7AHQAZQB4AHQALQB0AHIAYQBuAHMAZgBvAHIAbQA6AHUA
>> "%~1" echo cABwAGUAcgBjAGEAcwBlADsAbABlAHQAdABlAHIALQBzAHAAYQBjAGkAbgBnADoA
>> "%~1" echo LgAwADYAZQBtADsAYgBvAHIAZABlAHIALQBiAG8AdAB0AG8AbQA6ADIAcAB4ACAA
>> "%~1" echo cwBvAGwAaQBkACAAIwAxADEAMQA4ADIANwA7AHAAYQBkAGQAaQBuAGcAOgAxADAA
>> "%~1" echo cAB4ACAAMQAyAHAAeAB9AC4AYQB1AGQAaQB0AC0AdABhAGIAbABlACAAdABkAHsA
>> "%~1" echo YgBvAHIAZABlAHIALQB0AG8AcAA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIA
>> "%~1" echo KAAtAC0AbABpAG4AZQAyACkAOwBwAGEAZABkAGkAbgBnADoAMQAwAHAAeAAgADEA
>> "%~1" echo MgBwAHgAOwB2AGUAcgB0AGkAYwBhAGwALQBhAGwAaQBnAG4AOgB0AG8AcAA7AG8A
>> "%~1" echo dgBlAHIAZgBsAG8AdwAtAHcAcgBhAHAAOgBhAG4AeQB3AGgAZQByAGUAOwB3AG8A
>> "%~1" echo cgBkAC0AYgByAGUAYQBrADoAYgByAGUAYQBrAC0AdwBvAHIAZAB9AC4AYQB1AGQA
>> "%~1" echo aQB0AC0AdABhAGIAbABlACAAdABkADoAbgB0AGgALQBjAGgAaQBsAGQAKAAxACkA
>> "%~1" echo ewB3AGkAZAB0AGgAOgAyADIAJQA7AGMAbwBsAG8AcgA6ACMANAA3ADUANAA2ADcA
>> "%~1" echo OwBmAG8AbgB0AC0AdwBlAGkAZwBoAHQAOgA4ADAAMAB9AC4AYQB1AGQAaQB0AC0A
>> "%~1" echo dABhAGIAbABlACAAdABkADoAbgB0AGgALQBjAGgAaQBsAGQAKAAyACkAewB3AGkA
>> "%~1" echo ZAB0AGgAOgA0ADQAJQA7AGYAbwBuAHQALQB3AGUAaQBnAGgAdAA6ADgAMAAwADsA
>> "%~1" echo YwBvAGwAbwByADoAIwAxADAAMQA4ADIAOAB9AC4AYQB1AGQAaQB0AC0AdABhAGIA
>> "%~1" echo bABlACAAdABkADoAbgB0AGgALQBjAGgAaQBsAGQAKAAzACkAewB3AGkAZAB0AGgA
>> "%~1" echo OgAzADQAJQA7AGMAbwBsAG8AcgA6ACMANgA2ADcAMAA4ADUAfQAuAG4AbwB0AGUA
>> "%~1" echo ewBiAG8AcgBkAGUAcgAtAGwAZQBmAHQAOgA0AHAAeAAgAHMAbwBsAGkAZAAgAHYA
>> "%~1" echo YQByACgALQAtAHcAYQByAG4AKQA7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgAjAGYA
>> "%~1" echo ZgBmADgAZQBiADsAYgBvAHIAZABlAHIALQB0AG8AcAA6ADEAcAB4ACAAcwBvAGwA
>> "%~1" echo aQBkACAAIwBmADMAZAAxADkAYwA7AGIAbwByAGQAZQByAC0AcgBpAGcAaAB0ADoA
>> "%~1" echo MQBwAHgAIABzAG8AbABpAGQAIAAjAGYAMwBkADEAOQBjADsAYgBvAHIAZABlAHIA
>> "%~1" echo LQBiAG8AdAB0AG8AbQA6ADEAcAB4ACAAcwBvAGwAaQBkACAAIwBmADMAZAAxADkA
>> "%~1" echo YwA7AHAAYQBkAGQAaQBuAGcAOgAxADMAcAB4ACAAMQA0AHAAeAA7AG0AYQByAGcA
>> "%~1" echo aQBuAC0AdABvAHAAOgAxADgAcAB4AH0ALgByAGEAdwAgAGQAZQB0AGEAaQBsAHMA
>> "%~1" echo ewBiAG8AcgBkAGUAcgA6ADEAcAB4ACAAcwBvAGwAaQBkACAAdgBhAHIAKAAtAC0A
>> "%~1" echo bABpAG4AZQApADsAbQBhAHIAZwBpAG4AOgAxADAAcAB4ACAAMAA7AGIAYQBjAGsA
>> "%~1" echo ZwByAG8AdQBuAGQAOgAjAGYAZgBmAH0ALgByAGEAdwAgAHMAdQBtAG0AYQByAHkA
>> "%~1" echo ewBjAHUAcgBzAG8AcgA6AHAAbwBpAG4AdABlAHIAOwBiAGEAYwBrAGcAcgBvAHUA
>> "%~1" echo bgBkADoAdgBhAHIAKAAtAC0AcwBvAGYAdAApADsAcABhAGQAZABpAG4AZwA6ADEA
>> "%~1" echo MABwAHgAIAAxADIAcAB4ADsAZgBvAG4AdAAtAHcAZQBpAGcAaAB0ADoAOQAwADAA
>> "%~1" echo fQAuAHIAYQB3ACAAcAByAGUAewBtAGEAcgBnAGkAbgA6ADAAOwBtAGEAeAAtAGgA
>> "%~1" echo ZQBpAGcAaAB0ADoANAAyADAAcAB4ADsAbwB2AGUAcgBmAGwAbwB3ADoAYQB1AHQA
>> "%~1" echo bwA7AHcAaABpAHQAZQAtAHMAcABhAGMAZQA6AHAAcgBlAC0AdwByAGEAcAA7AG8A
>> "%~1" echo dgBlAHIAZgBsAG8AdwAtAHcAcgBhAHAAOgBhAG4AeQB3AGgAZQByAGUAOwB3AG8A
>> "%~1" echo cgBkAC0AYgByAGUAYQBrADoAYgByAGUAYQBrAC0AdwBvAHIAZAA7AGMAbwBsAG8A
>> "%~1" echo cgA6ACMANAA3ADUANAA2ADcAOwBwAGEAZABkAGkAbgBnADoAMQAyAHAAeAA7AGYA
>> "%~1" echo bwBuAHQAOgAxADIAcAB4AC8AMQAuADUAIABDAG8AbgBzAG8AbABhAHMALAAiAE0A
>> "%~1" echo aQBjAHIAbwBzAG8AZgB0ACAAWQBhAEgAZQBpACIALABtAG8AbgBvAHMAcABhAGMA
>> "%~1" echo ZQB9AC4AZgBvAG8AdAB7AGQAaQBzAHAAbABhAHkAOgBnAHIAaQBkADsAZwByAGkA
>> "%~1" echo ZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAxAGYAcgAgAGEA
>> "%~1" echo dQB0AG8AOwBnAGEAcAA6ADIAMABwAHgAOwBhAGwAaQBnAG4ALQBpAHQAZQBtAHMA
>> "%~1" echo OgBlAG4AZAA7AG0AYQByAGcAaQBuAC0AdABvAHAAOgAyADgAcAB4ADsAYgBvAHIA
>> "%~1" echo ZABlAHIALQB0AG8AcAA6ADIAcAB4ACAAcwBvAGwAaQBkACAAIwAxADEAMQA4ADIA
>> "%~1" echo NwA7AHAAYQBkAGQAaQBuAGcALQB0AG8AcAA6ADEANgBwAHgAfQAuAGYAbwBvAHQA
>> "%~1" echo IABiAHsAZgBvAG4AdAAtAHMAaQB6AGUAOgAxADIAcAB4ADsAdABlAHgAdAAtAHQA
>> "%~1" echo cgBhAG4AcwBmAG8AcgBtADoAdQBwAHAAZQByAGMAYQBzAGUAOwBsAGUAdAB0AGUA
>> "%~1" echo cgAtAHMAcABhAGMAaQBuAGcAOgAuADAAOABlAG0AfQAuAHQAbwB0AGEAbAB7AG0A
>> "%~1" echo aQBuAC0AdwBpAGQAdABoADoAMgA1ADAAcAB4ADsAYgBvAHIAZABlAHIAOgAxAHAA
>> "%~1" echo eAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUAKQB9AC4AdABvAHQA
>> "%~1" echo YQBsACAAZABpAHYAewBkAGkAcwBwAGwAYQB5ADoAZwByAGkAZAA7AGcAcgBpAGQA
>> "%~1" echo LQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQBmAHIAIABhAHUA
>> "%~1" echo dABvADsAcABhAGQAZABpAG4AZwA6ADkAcAB4ACAAMQAyAHAAeAA7AGIAbwByAGQA
>> "%~1" echo ZQByAC0AYgBvAHQAdABvAG0AOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgA
>> "%~1" echo LQAtAGwAaQBuAGUAMgApAH0ALgB0AG8AdABhAGwAIABkAGkAdgA6AGwAYQBzAHQA
>> "%~1" echo LQBjAGgAaQBsAGQAewBiAG8AcgBkAGUAcgAtAGIAbwB0AHQAbwBtADoAMAA7AGIA
>> "%~1" echo YQBjAGsAZwByAG8AdQBuAGQAOgB2AGEAcgAoAC0ALQBzAG8AZgB0ACkAOwBmAG8A
>> "%~1" echo bgB0AC0AdwBlAGkAZwBoAHQAOgA5ADAAMAB9AEAAbQBlAGQAaQBhACgAbQBhAHgA
>> "%~1" echo LQB3AGkAZAB0AGgAOgA4ADYAMABwAHgAKQB7AC4AZABvAGMALQBoAGUAYQBkACwA
>> "%~1" echo LgBwAGEAcgB0AHkALQBnAHIAaQBkACwALgBzAHUAbQBtAGEAcgB5AHsAZwByAGkA
>> "%~1" echo ZAAtAHQAZQBtAHAAbABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAxAGYAcgB9AC4A
>> "%~1" echo cABhAGQAewBwAGEAZABkAGkAbgBnADoAMgA0AHAAeAAgADEAOABwAHgAfQAuAHMA
>> "%~1" echo aABlAGUAdAAsAC4AYQBjAHQAaQBvAG4AcwB7AHcAaQBkAHQAaAA6AGMAYQBsAGMA
>> "%~1" echo KAAxADAAMAAlACAALQAgADEAOABwAHgAKQB9AC4AcwB1AG0AbQBhAHIAeQB7AGQA
>> "%~1" echo aQBzAHAAbABhAHkAOgBiAGwAbwBjAGsAfQAuAHMAdQBtAC0AYwBlAGwAbAB7AGIA
>> "%~1" echo bwByAGQAZQByAC0AcgBpAGcAaAB0ADoAMAA7AGIAbwByAGQAZQByAC0AYgBvAHQA
>> "%~1" echo dABvAG0AOgAxAHAAeAAgAHMAbwBsAGkAZAAgAHYAYQByACgALQAtAGwAaQBuAGUA
>> "%~1" echo MgApAH0ALgBhAHUAZABpAHQALQB0AGEAYgBsAGUAewB0AGEAYgBsAGUALQBsAGEA
>> "%~1" echo eQBvAHUAdAA6AGEAdQB0AG8AfQAuAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAgAHQA
>> "%~1" echo aAA6AG4AdABoAC0AYwBoAGkAbABkACgAMwApACwALgBhAHUAZABpAHQALQB0AGEA
>> "%~1" echo YgBsAGUAIAB0AGQAOgBuAHQAaAAtAGMAaABpAGwAZAAoADMAKQB7AGQAaQBzAHAA
>> "%~1" echo bABhAHkAOgBuAG8AbgBlAH0ALgBmAG8AbwB0AHsAZwByAGkAZAAtAHQAZQBtAHAA
>> "%~1" echo bABhAHQAZQAtAGMAbwBsAHUAbQBuAHMAOgAxAGYAcgB9AC4AdABvAHQAYQBsAHsA
>> "%~1" echo bQBpAG4ALQB3AGkAZAB0AGgAOgAwAH0AfQBAAG0AZQBkAGkAYQAoAG0AYQB4AC0A
>> "%~1" echo dwBpAGQAdABoADoANQAyADAAcAB4ACkAewAuAG0AZQB0AGEALQByAG8AdwB7AGcA
>> "%~1" echo cgBpAGQALQB0AGUAbQBwAGwAYQB0AGUALQBjAG8AbAB1AG0AbgBzADoAMQAwADUA
>> "%~1" echo cAB4ACAAbQBpAG4AbQBhAHgAKAAwACwAMQBmAHIAKQB9AGgAMQB7AGYAbwBuAHQA
>> "%~1" echo LQBzAGkAegBlADoAMgA4AHAAeAB9AC4AYQBjAHQAaQBvAG4AcwB7AGoAdQBzAHQA
>> "%~1" echo aQBmAHkALQBjAG8AbgB0AGUAbgB0ADoAZgBsAGUAeAAtAHMAdABhAHIAdAA7AG8A
>> "%~1" echo dgBlAHIAZgBsAG8AdwA6AGEAdQB0AG8AfQB9AEAAbQBlAGQAaQBhACAAcAByAGkA
>> "%~1" echo bgB0AHsAYgBvAGQAeQB7AGIAYQBjAGsAZwByAG8AdQBuAGQAOgAjAGYAZgBmAH0A
>> "%~1" echo LgBhAGMAdABpAG8AbgBzAHsAZABpAHMAcABsAGEAeQA6AG4AbwBuAGUAfQAuAHMA
>> "%~1" echo aABlAGUAdAB7AHcAaQBkAHQAaAA6AGEAdQB0AG8AOwBtAGEAcgBnAGkAbgA6ADAA
>> "%~1" echo OwBiAG8AcgBkAGUAcgA6ADAAOwBiAG8AeAAtAHMAaABhAGQAbwB3ADoAbgBvAG4A
>> "%~1" echo ZQB9AC4AcABhAGQAewBwAGEAZABkAGkAbgBnADoAMAB9AC4AcgBhAHcAIABwAHIA
>> "%~1" echo ZQB7AG0AYQB4AC0AaABlAGkAZwBoAHQAOgBuAG8AbgBlAH0ALgBiAG8AeAAsAC4A
>> "%~1" echo YQB1AGQAaQB0AC0AdABhAGIAbABlACwALgByAGEAdwAgAGQAZQB0AGEAaQBsAHMA
>> "%~1" echo ewBiAHIAZQBhAGsALQBpAG4AcwBpAGQAZQA6AGEAdgBvAGkAZAB9AEAAcABhAGcA
>> "%~1" echo ZQB7AHMAaQB6AGUAOgBBADQAOwBtAGEAcgBnAGkAbgA6ADEAMwBtAG0AfQB9AAEr
>> "%~1" echo PAAvAHMAdAB5AGwAZQA+ADwALwBoAGUAYQBkAD4APABiAG8AZAB5AD4AAIGZPABk
>> "%~1" echo AGkAdgAgAGMAbABhAHMAcwA9ACIAYQBjAHQAaQBvAG4AcwAiAD4APABiAHUAdAB0
>> "%~1" echo AG8AbgAgAGMAbABhAHMAcwA9ACIAYgB0AG4AIABwAHIAaQBtAGEAcgB5ACIAIABv
>> "%~1" echo AG4AYwBsAGkAYwBrAD0AIgB3AGkAbgBkAG8AdwAuAHAAcgBpAG4AdAAoACkAIgA+
>> "%~1" echo AFNicFMgAC8AIADdT1hbIABQAEQARgA8AC8AYgB1AHQAdABvAG4APgA8AGIAdQB0
>> "%~1" echo AHQAbwBuACAAYwBsAGEAcwBzAD0AIgBiAHQAbgAiACAAbwBuAGMAbABpAGMAawA9
>> "%~1" echo ACIAZABvAGMAdQBtAGUAbgB0AC4AcQB1AGUAcgB5AFMAZQBsAGUAYwB0AG8AcgBB
>> "%~1" echo AGwAbAAoACcAZABlAHQAYQBpAGwAcwAnACkALgBmAG8AcgBFAGEAYwBoACgAZAA9
>> "%~1" echo AD4AZAAuAG8AcABlAG4APQB0AHIAdQBlACkAIgA+AFVcAF9EllVfPAAvAGIAdQB0
>> "%~1" echo AHQAbwBuAD4APAAvAGQAaQB2AD4AAUs8AG0AYQBpAG4AIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AHMAaABlAGUAdAAiAD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAcABhAGQAIgA+
>> "%~1" echo AACBwTwAaABlAGEAZABlAHIAIABjAGwAYQBzAHMAPQAiAGQAbwBjAC0AaABlAGEA
>> "%~1" echo ZAAiAD4APABkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAGsAaQBjAGsA
>> "%~1" echo ZQByACIAPgBRAHUAZQBzAHQAIABBAEQAQgAgAFQAbwBvAGwAcwAgAC8AIABSAGUA
>> "%~1" echo YQBkAC0AbwBuAGwAeQAgAGUAeABwAG8AcgB0ADwALwBkAGkAdgA+ADwAaAAxAD4A
>> "%~1" echo UQB1AGUAcwB0ACAAQQBEAEIAIAC+iwdZoVuhi6ViSlQ8AC8AaAAxAD4APABwACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBzAHUAYgAiAD4A+leOTmxRAF8gAEEARABCACAA6lP7i31U
>> "%~1" echo 5E4fdRBiDP8odY5OdGUGdCAAUQB1AGUAcwB0ACAANFk+ZquO/U4BMPt8334BMGVQ
>> "%~1" echo t14BMOVdglMvACFoxlG/fiJ9ATAFUw5O/YCbUgIw/Fv6UUFtC3oNTplRZVG+i25/
>> "%~1" echo DP8NTu5POWW+iwdZAjBcTwWAS23Vi76LB1lIcixnGv9RAHUAZQBzAHQAIAAzAAIw
>> "%~1" echo PAAvAHAAPgA8AC8AZABpAHYAPgABfTwAYQBzAGkAZABlACAAYwBsAGEAcwBzAD0A
>> "%~1" echo IgBtAGUAdABhACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBtAGUAdABhAC0A
>> "%~1" echo cgBvAHcAIgA+ADwAcwBwAGEAbgA+AKViSlQWf/dTPAAvAHMAcABhAG4APgA8AGIA
>> "%~1" echo PgABaTwALwBiAD4APAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIA
>> "%~1" echo bQBlAHQAYQAtAHIAbwB3ACIAPgA8AHMAcABhAG4APgAfdRBi9mX0lTwALwBzAHAA
>> "%~1" echo YQBuAD4APABiAD4AAYCLPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2ACAAYwBs
>> "%~1" echo AGEAcwBzAD0AIgBtAGUAdABhAC0AcgBvAHcAIgA+ADwAcwBwAGEAbgA+AJCWwXmn
>> "%~1" echo fitSPAAvAHMAcABhAG4APgA8AGIAPgA8AGkAIABjAGwAYQBzAHMAPQAiAHMAdABh
>> "%~1" echo AG0AcAAiAD4AAYCDPAAvAGkAPgA8AC8AYgA+ADwALwBkAGkAdgA+ADwAZABpAHYA
>> "%~1" echo IABjAGwAYQBzAHMAPQAiAG0AZQB0AGEALQByAG8AdwAiAD4APABzAHAAYQBuAD4A
>> "%~1" echo QQBEAEIAIABlZ5BuPAAvAHMAcABhAG4APgA8AGIAIAB0AGkAdABsAGUAPQAiAAEF
>> "%~1" echo IgA+AAA3PAAvAGIAPgA8AC8AZABpAHYAPgA8AC8AYQBzAGkAZABlAD4APAAvAGgA
>> "%~1" echo ZQBhAGQAZQByAD4AAIC/PABzAGUAYwB0AGkAbwBuACAAYwBsAGEAcwBzAD0AIgBw
>> "%~1" echo AGEAcgB0AHkALQBnAHIAaQBkACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBi
>> "%~1" echo AG8AeAAiAD4APABoADIAPgC+iwdZPAAvAGgAMgA+ADwAZABpAHYAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAGIAbwB4AC0AYgBvAGQAeQAiAD4APABkAGkAdgAgAGMAbABhAHMAcwA9
>> "%~1" echo ACIAYgBpAGcAIgA+AAEzPAAvAGQAaQB2AD4APABkAGkAdgAgAGMAbABhAHMAcwA9
>> "%~1" echo ACIAbQB1AHQAZQBkACIAPgAAZzwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBz
>> "%~1" echo AHMAPQAiAGMAaABpAHAAcwAiAD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBj
>> "%~1" echo AGgAaQBwACIAPgBTAGUAcgBpAGEAbAAgAAA1PAAvAHMAcABhAG4APgA8AHMAcABh
>> "%~1" echo AG4AIABjAGwAYQBzAHMAPQAiAGMAaABpAHAAIgA+AAAPIAAvACAAUwBEAEsAIAAA
>> "%~1" echo MzwALwBzAHAAYQBuAD4APAAvAGQAaQB2AD4APAAvAGQAaQB2AD4APAAvAGQAaQB2
>> "%~1" echo AD4AAICLPABkAGkAdgAgAGMAbABhAHMAcwA9ACIAYgBvAHgAIgA+ADwAaAAyAD4A
>> "%~1" echo x5HGllZ7ZXU8AC8AaAAyAD4APABkAGkAdgAgAGMAbABhAHMAcwA9ACIAYgBvAHgA
>> "%~1" echo LQBiAG8AZAB5ACIAPgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBiAGkAZwAiAD4A
>> "%~1" echo AQvBeQlnjFt0ZUhyAQsGUqtOiVtoUUhyATPdT1l1jFt0ZcF5CWfBi25jDP8CkAhU
>> "%~1" echo LGc6Z1l1Y2gb/w1OgYn0dqVjbFEAXwZSq04CMAF98l1ukD2Fj14XUvdTATBAXN9X
>> "%~1" echo UX8wV0BXATBNAEEAQwAvAEIAUwBTAEkARAABMGYAaQBuAGcAZQByAHAAcgBpAG4A
>> "%~1" echo dAABMHMAZQBzAHMAaQBvAG4AIABJe09lH2FXW7VrG//zjcePIABsAG8AZwBjAGEA
>> "%~1" echo dAAgAESWVV8CMAGBVTwALwBkAGkAdgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAi
>> "%~1" echo AGMAaABpAHAAcwAiAD4APABzAHAAYQBuACAAYwBsAGEAcwBzAD0AIgBjAGgAaQBw
>> "%~1" echo ACIAPgBOAG8AIABBAEQAQgAgAHcAcgBpAHQAZQA8AC8AcwBwAGEAbgA+ADwAcwBw
>> "%~1" echo AGEAbgAgAGMAbABhAHMAcwA9ACIAYwBoAGkAcAAiAD4ASABUAE0ATAAvAFAARABG
>> "%~1" echo ACAAcgBlAGEAZAB5ADwALwBzAHAAYQBuAD4APABzAHAAYQBuACAAYwBsAGEAcwBz
>> "%~1" echo AD0AIgBjAGgAaQBwACIAPgBRAHUAZQBzAHQAIAAzACAAbgBvAHQAZQBkADwALwBz
>> "%~1" echo AHAAYQBuAD4APAAvAGQAaQB2AD4APAAvAGQAaQB2AD4APAAvAGQAaQB2AD4APAAv
>> "%~1" echo AHMAZQBjAHQAaQBvAG4APgAAgI08AHMAZQBjAHQAaQBvAG4AIABjAGwAYQBzAHMA
>> "%~1" echo PQAiAHMAdQBtAG0AYQByAHkAIgA+ADwAZABpAHYAIABjAGwAYQBzAHMAPQAiAHMA
>> "%~1" echo dQBtAC0AYwBlAGwAbAAiAD4APABzAHAAYQBuAD4ANXXPkSAALwAgAClupl48AC8A
>> "%~1" echo cwBwAGEAbgA+ADwAYgA+AAFlPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQAaQB2ACAA
>> "%~1" echo YwBsAGEAcwBzAD0AIgBzAHUAbQAtAGMAZQBsAGwAIgA+ADwAcwBwAGEAbgA+AD5m
>> "%~1" echo Onk8AC8AcwBwAGEAbgA+ADwAYgA+AAFlPAAvAGIAPgA8AC8AZABpAHYAPgA8AGQA
>> "%~1" echo aQB2ACAAYwBsAGEAcwBzAD0AIgBzAHUAbQAtAGMAZQBsAGwAIgA+ADwAcwBwAGEA
>> "%~1" echo bgA+AFhbqFA8AC8AcwBwAGEAbgA+ADwAYgA+AAFlPAAvAGIAPgA8AC8AZABpAHYA
>> "%~1" echo PgA8AGQAaQB2ACAAYwBsAGEAcwBzAD0AIgBzAHUAbQAtAGMAZQBsAGwAIgA+ADwA
>> "%~1" echo cwBwAGEAbgA+ACFoxlE8AC8AcwBwAGEAbgA+ADwAYgA+AAEpPAAvAGIAPgA8AC8A
>> "%~1" echo ZABpAHYAPgA8AC8AcwBlAGMAdABpAG8AbgA+AAAJvosHWauO/U4BQXMAZQByAGkA
>> "%~1" echo YQBsAHwAj14XUvdTfABhAGQAYgAgAGQAZQB2AGkAYwBlAHMAIAAvACAAZwBlAHQA
>> "%~1" echo cAByAG8AcAABQ2QAZQB2AGkAYwBlAEwAaQBuAGUAfABBAEQAQgAgAL6LB1lMiHwA
>> "%~1" echo YQBkAGIAIABkAGUAdgBpAGMAZQBzACAALQBsAAFPbQBhAG4AdQBmAGEAYwB0AHUA
>> "%~1" echo cgBlAHIAfACCU0ZVfAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AbQBhAG4AdQBmAGEA
>> "%~1" echo YwB0AHUAcgBlAHIAATNiAHIAYQBuAGQAfADBVExyfAByAG8ALgBwAHIAbwBkAHUA
>> "%~1" echo YwB0AC4AYgByAGEAbgBkAAEzbQBvAGQAZQBsAHwAi1f3U3wAcgBvAC4AcAByAG8A
>> "%~1" echo ZAB1AGMAdAAuAG0AbwBkAGUAbAABOXAAcgBvAGQAdQBjAHQAfACnTsFU4073U3wA
>> "%~1" echo cgBvAC4AcAByAG8AZAB1AGMAdAAuAG4AYQBtAGUAATtkAGUAdgBpAGMAZQB8AL6L
>> "%~1" echo B1njTvdTfAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AZABlAHYAaQBjAGUAATNiAG8A
>> "%~1" echo YQByAGQAfAB/Z6d+fAByAG8ALgBwAHIAbwBkAHUAYwB0AC4AYgBvAGEAcgBkAAEp
>> "%~1" echo cwBvAGMAfABTAG8AQwB8AHIAbwAuAHMAbwBjAC4AbQBvAGQAZQBsAAA1YQBiAGkA
>> "%~1" echo fABBAEIASQB8AHIAbwAuAHAAcgBvAGQAdQBjAHQALgBjAHAAdQAuAGEAYgBpAAAL
>> "%~1" echo +3zffg5OhGf6XgEvYQBuAGQAcgBvAGkAZAB8AEEAbgBkAHIAbwBpAGQAfABnAGUA
>> "%~1" echo dABwAHIAbwBwAAAfcwBkAGsAfABTAEQASwB8AGcAZQB0AHAAcgBvAHAAADlzAGUA
>> "%~1" echo YwB1AHIAaQB0AHkAUABhAHQAYwBoAHwA+3zffolbaFFliAFOfABnAGUAdABwAHIA
>> "%~1" echo bwBwAAE/dgBlAG4AZABvAHIAUABhAHQAYwBoAHwAVgBlAG4AZABvAHIAIACJW2hR
>> "%~1" echo ZYgBTnwAZwBlAHQAcAByAG8AcAABMWIAdQBpAGwAZABJAGQAfABCAHUAaQBsAGQA
>> "%~1" echo IABJAEQAfABnAGUAdABwAHIAbwBwAABJYgB1AGkAbABkAEkAbgBjAHIAZQBtAGUA
>> "%~1" echo bgB0AGEAbAB8AEkAbgBjAHIAZQBtAGUAbgB0AGEAbAB8AGcAZQB0AHAAcgBvAHAA
>> "%~1" echo ADViAHUAaQBsAGQAQgByAGEAbgBjAGgAfABCAHIAYQBuAGMAaAB8AGcAZQB0AHAA
>> "%~1" echo cgBvAHAAAD9mAGkAbgBnAGUAcgBwAHIAaQBuAHQAfABGAGkAbgBnAGUAcgBwAHIA
>> "%~1" echo aQBuAHQAfABnAGUAdABwAHIAbwBwAAAtawBlAHIAbgBlAGwAfABLAGUAcgBuAGUA
>> "%~1" echo bAB8AHUAbgBhAG0AZQAgAC0AYQABIT5mOnkgAC8AIAA1dZBuIAAvACAAUX/cfiAA
>> "%~1" echo LwAgAO1wATlkAGkAcwBwAGwAYQB5AHwAPmY6eVhkgYl8AGQAdQBtAHAAcwB5AHMA
>> "%~1" echo IABkAGkAcwBwAGwAYQB5AAE1cABhAG4AZQBsAHwAYpd/Z79+In18AGQAdQBtAHAA
>> "%~1" echo cwB5AHMAIABkAGkAcwBwAGwAYQB5AAE/YgBhAHQAdABlAHIAeQBMAGUAdgBlAGwA
>> "%~1" echo fAA1dc+RfABkAHUAbQBwAHMAeQBzACAAYgBhAHQAdABlAHIAeQABQWIAYQB0AHQA
>> "%~1" echo ZQByAHkAVABlAG0AcAB8ADV1YGwpbqZefABkAHUAbQBwAHMAeQBzACAAYgBhAHQA
>> "%~1" echo dABlAHIAeQABRWIAYQB0AHQAZQByAHkASABlAGEAbAB0AGgAfAA1dWBsZVC3XnwA
>> "%~1" echo ZAB1AG0AcABzAHkAcwAgAGIAYQB0AHQAZQByAHkAAT1wAG8AdwBlAHIAUwBvAHUA
>> "%~1" echo cgBjAGUAfACbTzV1fABkAHUAbQBwAHMAeQBzACAAYgBhAHQAdABlAHIAeQABPXcA
>> "%~1" echo YQBrAGUAZgB1AGwAbgBlAHMAcwB8ACRVkpG2cgFgfABkAHUAbQBwAHMAeQBzACAA
>> "%~1" echo cABvAHcAZQByAAFJcwB0AGEAeQBPAG4AfADdTwFjJFWSkXwAcwBlAHQAdABpAG4A
>> "%~1" echo ZwBzACAALwAgAGQAdQBtAHAAcwB5AHMAIABwAG8AdwBlAHIAAUlwAHIAbwB4AGkA
>> "%~1" echo bQBpAHQAeQB8AKVj0Y+2cgFgfABkAHUAbQBwAHMAeQBzACAAcwBlAG4AcwBvAHIA
>> "%~1" echo cwBlAHIAdgBpAGMAZQABRXQAaABlAHIAbQBhAGwAfADtcLZyAWB8AGQAdQBtAHAA
>> "%~1" echo cwB5AHMAIAB0AGgAZQByAG0AYQBsAHMAZQByAHYAaQBjAGUAASd1AHMAYgB8AFUA
>> "%~1" echo UwBCAHwAZAB1AG0AcABzAHkAcwAgAHUAcwBiAABDdwBpAGYAaQB8AFcAaQAtAEYA
>> "%~1" echo aQB8AGQAdQBtAHAAcwB5AHMAIAB3AGkAZgBpACAALwAgAGkAcAAgAGEAZABkAHIA
>> "%~1" echo AU1iAGwAdQBlAHQAbwBvAHQAaAB8AN2EWXJ8AGQAdQBtAHAAcwB5AHMAIABiAGwA
>> "%~1" echo dQBlAHQAbwBvAHQAaABfAG0AYQBuAGEAZwBlAHIAAWVjAGEAbQBlAHIAYQB8APh2
>> "%~1" echo OmcvACBPH2FoVnwAZAB1AG0AcABzAHkAcwAgAG0AZQBkAGkAYQAuAGMAYQBtAGUA
>> "%~1" echo cgBhACAALwAgAHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAASFzAHQAbwByAGEA
>> "%~1" echo ZwBlAHwAWFuoUHwAZABmACAALQBoAAEvbQBlAG0AbwByAHkAfACFUVhbfAAvAHAA
>> "%~1" echo cgBvAGMALwBtAGUAbQBpAG4AZgBvAAErYwBwAHUAfABDAFAAVQB8AC8AcAByAG8A
>> "%~1" echo YwAvAGMAcAB1AGkAbgBmAG8AADNGAGEAYwB0AG8AcgB5ACAALwAgAEMAYQBsAGkA
>> "%~1" echo YgByAGEAdABpAG8AbgAgAENRcGVuYwFfZgBhAGMAdABvAHIAeQBEAGUAdgBpAGMA
>> "%~1" echo ZQB8AEQAZQB2AGkAYwBlAFQAeQBwAGUAfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkA
>> "%~1" echo YwBlACAAbQBlAHQAYQBkAGEAdABhAABbZgBhAGMAdABvAHIAeQBCAHUAaQBsAGQA
>> "%~1" echo fABCAHUAaQBsAGQAVAB5AHAAZQB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUA
>> "%~1" echo IABtAGUAdABhAGQAYQB0AGEAAGlmAGEAYwB0AG8AcgB5AFQAaQBtAGUAfABGAGEA
>> "%~1" echo YwB0AG8AcgB5ACAAVABpAG0AZQBzAHQAYQBtAHAAfABzAGUAbgBzAG8AcgBzAGUA
>> "%~1" echo cgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABlZgBhAGMAdABvAHIAeQBMAG8A
>> "%~1" echo YwBhAHQAaQBvAG4AfABsAG8AYwBhAHQAaQBvAG4AXwBpAGQAfABzAGUAbgBzAG8A
>> "%~1" echo cgBzAGUAcgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAABhZgBhAGMAdABvAHIA
>> "%~1" echo eQBTAHQAYQB0AGkAbwBuAHwAcwB0AGEAdABpAG8AbgBfAGkAZAB8AHMAZQBuAHMA
>> "%~1" echo bwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEAAG1mAGEAYwB0AG8A
>> "%~1" echo cgB5AFMAdABhAHQAaQBvAG4AVAB5AHAAZQB8AHMAdABhAHQAaQBvAG4AXwB0AHkA
>> "%~1" echo cABlAHwAcwBlAG4AcwBvAHIAcwBlAHIAdgBpAGMAZQAgAG0AZQB0AGEAZABhAHQA
>> "%~1" echo YQAAXWYAYQBjAHQAbwByAHkAVABlAHMAdAB8AGMAYQBsAF8AdABlAHMAdABfAGkA
>> "%~1" echo ZAB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQAYQB0AGEA
>> "%~1" echo AGVmAGEAYwB0AG8AcgB5AE8AcABlAHIAYQB0AG8AcgB8AG8AcABlAHIAYQB0AG8A
>> "%~1" echo cgBfAGkAZAB8AHMAZQBuAHMAbwByAHMAZQByAHYAaQBjAGUAIABtAGUAdABhAGQA
>> "%~1" echo YQB0AGEAAHVmAGEAYwB0AG8AcgB5AEMAYQBsAGkAYgByAGEAdABpAG8AbgB8AGMA
>> "%~1" echo YQBsAGkAYgByAGEAdABpAG8AbgBfAHQAeQBwAGUAfABzAGUAbgBzAG8AcgBzAGUA
>> "%~1" echo cgB2AGkAYwBlACAAbQBlAHQAYQBkAGEAdABhAAB3bwBuAGwAaQBuAGUAQwBhAGwA
>> "%~1" echo aQBiAHIAYQB0AGkAbwBuAHwATwBuAGwAaQBuAGUAIABjAGEAbABpAGIAcgBhAHQA
>> "%~1" echo aQBvAG4AfABzAGUAbgBzAG8AcgBzAGUAcgB2AGkAYwBlACAAbQBlAHQAYQBkAGEA
>> "%~1" echo dABhAACBfTwAZABpAHYAIABjAGwAYQBzAHMAPQAiAG4AbwB0AGUAIgA+ADwAYgA+
>> "%~1" echo AKhjrWW5j0x1Gv88AC8AYgA+AO9T5U6wi1VfvosHWc9lATBsePZONpa1awEwIWjG
>> "%~1" echo UbCLVV+MVOVdglNLbdWLv34ifQz/i0+CWSAAUQB1AGUAcwB0ACAAMwAgAC8AIABF
>> "%~1" echo AHUAcgBlAGsAYQAgAC8AIABQAFYAVAAgAC8AIABGAGEAYwB0AG8AcgB5ACAALwAg
>> "%~1" echo AE8AbgBsAGkAbgBlACAAYwBhAGwAaQBiAHIAYQB0AGkAbwBuAAIwDU79gIpiIABs
>> "%~1" echo AG8AYwBhAHQAaQBvAG4AXwBpAGQAATBzAHQAYQB0AGkAbwBuAF8AaQBkAAEwcwB0
>> "%~1" echo AGEAdABpAG8AbgBfAHQAeQBwAGUAIADvU2CX+3/RixBi/Va2WwEwzlcCXhZid1FT
>> "%~1" echo T+VdglMb/1cAaQAtAEYAaQAgAP1WtlsBeF9ODU4vZvpRp04wVwIwPAAvAGQAaQB2
>> "%~1" echo AD4AAQ0FUw5O+3zffv2Am1IBO3AAYQBjAGsAYQBnAGUAcwB8AAVTcGXPkXwAcABt
>> "%~1" echo ACAAbABpAHMAdAAgAHAAYQBjAGsAYQBnAGUAcwABSWYAZQBhAHQAdQByAGUAcwB8
>> "%~1" echo AEYAZQBhAHQAdQByAGUAIABwZc+RfABwAG0AIABsAGkAcwB0ACAAZgBlAGEAdAB1
>> "%~1" echo AHIAZQBzAAFzdgBkAHwAVgBpAHIAdAB1AGEAbAAgAEQAZQBzAGsAdABvAHAAfABk
>> "%~1" echo AHUAbQBwAHMAeQBzACAAcABhAGMAawBhAGcAZQAgAFYAaQByAHQAdQBhAGwARABl
>> "%~1" echo AHMAawB0AG8AcAAuAEEAbgBkAHIAbwBpAGQAAD13AGEAcgBuAGkAbgBnAHMAfADH
>> "%~1" echo kcaWZotKVHwAZQB4AHAAbwByAHQAIABjAG8AbABsAGUAYwB0AG8AcgABgd88AGYA
>> "%~1" echo bwBvAHQAZQByACAAYwBsAGEAcwBzAD0AIgBmAG8AbwB0ACIAPgA8AGQAaQB2AD4A
>> "%~1" echo PABiAD4AUQB1AGUAcwB0ACAAQQBEAEIAIABUAG8AbwBsAHMAIABiAHkAIABkAHcA
>> "%~1" echo ZwB4ADEAMwAzADcAPAAvAGIAPgA8AGIAcgA+ADwAcwBwAGEAbgAgAGMAbABhAHMA
>> "%~1" echo cwA9ACIAbQB1AHQAZQBkACIAPgBQAHUAYgBsAGkAYwAgAHIAZQBwAG8AIABzAGEA
>> "%~1" echo bQBwAGwAZQAgAG0AdQBzAHQAIAB1AHMAZQAgAHMAaABhAHIAZQAtAHMAYQBmAGUA
>> "%~1" echo IABlAHgAcABvAHIAdAAuACAAUAByAGkAdgBhAHQAZQAgAGYAdQBsAGwAIABlAHgA
>> "%~1" echo cABvAHIAdAAgAGkAcwAgAGYAbwByACAAbABvAGMAYQBsACAAZQB2AGkAZABlAG4A
>> "%~1" echo YwBlACAAbwBuAGwAeQAuADwALwBzAHAAYQBuAD4APAAvAGQAaQB2AD4APABkAGkA
>> "%~1" echo dgAgAGMAbABhAHMAcwA9ACIAdABvAHQAYQBsACIAPgA8AGQAaQB2AD4APABzAHAA
>> "%~1" echo YQBuAD4AUABhAGMAawBhAGcAZQBzADwALwBzAHAAYQBuAD4APABiAD4AAU88AC8A
>> "%~1" echo YgA+ADwALwBkAGkAdgA+ADwAZABpAHYAPgA8AHMAcABhAG4APgBGAGUAYQB0AHUA
>> "%~1" echo cgBlAHMAPAAvAHMAcABhAG4APgA8AGIAPgAASzwALwBiAD4APAAvAGQAaQB2AD4A
>> "%~1" echo PABkAGkAdgA+ADwAcwBwAGEAbgA+AFMAdABhAHQAdQBzADwALwBzAHAAYQBuAD4A
>> "%~1" echo PABiAD4AAA9QAHIAaQB2AGEAdABlAAAVUwBoAGEAcgBlAC0AcwBhAGYAZQABMzwA
>> "%~1" echo LwBiAD4APAAvAGQAaQB2AD4APAAvAGQAaQB2AD4APAAvAGYAbwBvAHQAZQByAD4A
>> "%~1" echo ADc8AC8AZABpAHYAPgA8AC8AbQBhAGkAbgA+ADwALwBiAG8AZAB5AD4APAAvAGgA
>> "%~1" echo dABtAGwAPgAAOzwAcwBlAGMAdABpAG8AbgAgAGMAbABhAHMAcwA9ACIAcwBlAGMA
>> "%~1" echo dABpAG8AbgAiAD4APABoADIAPgAAgMM8AC8AaAAyAD4APAB0AGEAYgBsAGUAIABj
>> "%~1" echo AGwAYQBzAHMAPQAiAGEAdQBkAGkAdAAtAHQAYQBiAGwAZQAiAD4APAB0AGgAZQBh
>> "%~1" echo AGQAPgA8AHQAcgA+ADwAdABoAD4AV1u1azwALwB0AGgAPgA8AHQAaAA+ADxQPAAv
>> "%~1" echo AHQAaAA+ADwAdABoAD4AwYtuY2VnkG48AC8AdABoAD4APAAvAHQAcgA+ADwALwB0
>> "%~1" echo AGgAZQBhAGQAPgA8AHQAYgBvAGQAeQA+AAEHQQBEAEIAABE8AHQAcgA+ADwAdABk
>> "%~1" echo AD4AABM8AC8AdABkAD4APAB0AGQAPgAAFTwALwB0AGQAPgA8AC8AdAByAD4AADU8
>> "%~1" echo AC8AdABiAG8AZAB5AD4APAAvAHQAYQBiAGwAZQA+ADwALwBzAGUAYwB0AGkAbwBu
>> "%~1" echo AD4AAGM8AHMAZQBjAHQAaQBvAG4AIABjAGwAYQBzAHMAPQAiAHMAZQBjAHQAaQBv
>> "%~1" echo AG4AIAByAGEAdwAiAD4APABoADIAPgCfU8tZIABBAEQAQgAgAJOP+lFEllVfPAAv
>> "%~1" echo AGgAMgA+AAENbABvAGcAYwBhAHQAADEKAC4ALgAuACAA8l0qYq1lDP+MW3RlhVG5
>> "%~1" echo W/eLC3fBeQlnjFt0ZUhyIAAuAC4ALgABJTwAZABlAHQAYQBpAGwAcwA+ADwAcwB1
>> "%~1" echo AG0AbQBhAHIAeQA+AAAHIAC3ACAAARVtAHMAIAC3ACAAZQB4AGkAdAAgAAEVIAC3
>> "%~1" echo ACAAdABpAG0AZQBvAHUAdAABHzwALwBzAHUAbQBtAGEAcgB5AD4APABwAHIAZQA+
>> "%~1" echo AAAhPAAvAHAAcgBlAD4APAAvAGQAZQB0AGEAaQBsAHMAPgAAFTwALwBzAGUAYwB0
>> "%~1" echo AGkAbwBuAD4AADlnAGUAdABwAHIAbwBwACAAZABoAGMAcAAuAHcAbABhAG4AMAAu
>> "%~1" echo AGkAcABhAGQAZAByAGUAcwBzAAAPMAAuADAALgAwAC4AMAAANWkAcAAgAC0AZgAg
>> "%~1" echo AGkAbgBlAHQAIABhAGQAZAByACAAcwBoAG8AdwAgAHcAbABhAG4AMAABC2kAbgBl
>> "%~1" echo AHQAIAAABSIAIgAAAyIAAAVcACIAAAMyAAAHRVE1dS1OAQMzAAADNAAABypnRVE1
>> "%~1" echo dQEDNQAAB/JdRVHhbgEFY2s4XgEFx4/tcAEFX2NPVwEFx4+LUwEDNwAABcePt1EB
>> "%~1" echo F0EAQwAgAHAAbwB3AGUAcgBlAGQAOgAABUEAQwAAGVUAUwBCACAAcABvAHcAZQBy
>> "%~1" echo AGUAZAA6AAAHVQBTAEIAACNXAGkAcgBlAGwAZQBzAHMAIABwAG8AdwBlAHIAZQBk
>> "%~1" echo ADoAAAXgZb9+AQcqZ5tPNXUBAz0AAAcgAEcAQgAAA1sAAAldADoAIABbAAArXAAi
>> "%~1" echo AFwAcwAqADoAXABzACoAXAAiACgAWwBeAFwAIgBdACoAKQBcACIAACdcACIAXABz
>> "%~1" echo ACoAOgBcAHMAKgAoAFsAXgAsAH0AXABzAF0AKwApAAALLwBkAGEAdABhAAARLwBz
>> "%~1" echo AHQAbwByAGEAZwBlAAANIAB1AHMAZQBkACAAABNwAHIAbwBjAGUAcwBzAG8AcgAA
>> "%~1" echo P0MAUABVACAAcABhAHIAdABcAHMAKgA6AFwAcwAqACgAMAB4AFsAMAAtADkAYQAt
>> "%~1" echo AGYAQQAtAEYAXQArACkAARMgAGMAbwByAGUAcwAgAC8AIAAAIWkAZAA9AFwAZAAr
>> "%~1" echo ACwAXABzACoAdwBpAGQAdABoAD0AAAMwAAANIABtAG8AZABlAHMAABNIAEEATAAg
>> "%~1" echo AFIAZQBhAGQAeQAACUgAQQBMACAAABFiAGEAdAB0AGUAcgB5ACAAACVjAG8AbgBu
>> "%~1" echo AGUAYwB0AGUAZAA9ACgAWwBhAC0AegBdACsAKQABJ2MAbwBuAGYAaQBnAHUAcgBl
>> "%~1" echo AGQAPQAoAFsAYQAtAHoAXQArACkAATltAEMAdQByAHIAZQBuAHQARgB1AG4AYwB0
>> "%~1" echo AGkAbwBuAHMAPQAoAFsAXgBcAG4AXAByAF0AKwApAAAVYwBvAG4AbgBlAGMAdABl
>> "%~1" echo AGQAIAAAF2MAbwBuAGYAaQBnAHUAcgBlAGQAIAAAPXMAdABhAG4AZABhAHIAZAA6
>> "%~1" echo AFwAcwAqACgAWwAwAC0AOQBBAC0AWgBhAC0AegAgAC4AXwAtAF0AKwApAAErRgBy
>> "%~1" echo AGUAcQB1AGUAbgBjAHkAOgBcAHMAKgAoAFsAMAAtADkAXQArACkAAS1MAGkAbgBr
>> "%~1" echo ACAAcwBwAGUAZQBkADoAXABzACoAKABbADAALQA5AF0AKwApAAElUgBTAFMASQA6
>> "%~1" echo AFwAcwAqACgALQA/AFsAMAAtADkAXQArACkAAU9pAG4AZQB0AFwAcwArACgAWwAw
>> "%~1" echo AC0AOQBdACsAXAAuAFsAMAAtADkAXQArAFwALgBbADAALQA5AF0AKwBcAC4AWwAw
>> "%~1" echo AC0AOQBdACsAKQABB0kAUAAgAAATcwB0AGEAbgBkAGEAcgBkACAAAAdNAEgAegAA
>> "%~1" echo CU0AYgBwAHMAAAtSAFMAUwBJACAAACdlAG4AYQBiAGwAZQBkADoAXABzACoAKABb
>> "%~1" echo AGEALQB6AF0AKwApAAElcwB0AGEAdABlADoAXABzACoAKABbAEEALQBaAF8AXQAr
>> "%~1" echo ACkAASFCAGwAdQBlAHQAbwBvAHQAaAAgAFMAdABhAHQAdQBzAAARZQBuAGEAYgBs
>> "%~1" echo AGUAZAAgAABfQwBhAG0AZQByAGEARABlAHYAaQBjAGUAQwBsAGkAZQBuAHQAfABD
>> "%~1" echo AGEAbQBlAHIAYQBcAHMAKwBJAEQAfAA9AD0AIABDAGEAbQBlAHIAYQAgAGQAZQB2
>> "%~1" echo AGkAYwBlAAApIgBTAGUAbgBzAG8AcgBUAHkAcABlACIAOgAiAE8ARwAwADEAQQAi
>> "%~1" echo AAArIgBTAGUAbgBzAG8AcgBUAHkAcABlACIAOgAiAE8AVgA3ADIANQAxACIAACsi
>> "%~1" echo AFMAZQBuAHMAbwByAFQAeQBwAGUAIgA6ACIASQBNAFgANAA3ADEAIgAAHyAAYwBh
>> "%~1" echo AG0AZQByAGEAIABlAG4AdAByAGkAZQBzAAAlYwBhAGwAIABzAGUAbgBzAG8AcgBz
>> "%~1" echo ACAATwBHADAAMQBBACAAABUgAC8AIABPAFYANwAyADUAMQAgAAAVIAAvACAASQBN
>> "%~1" echo AFgANAA3ADEAIAAAQVAAYQBjAGsAYQBnAGUAIABbAFYAaQByAHQAdQBhAGwARABl
>> "%~1" echo AHMAawB0AG8AcAAuAEEAbgBkAHIAbwBpAGQAXQAAEXAAYQBjAGsAYQBnAGUAOgAA
>> "%~1" echo L1YASQBWAEUAIABCAHUAcwBpAG4AZQBzAHMAIABTAHQAcgBlAGEAbQBpAG4AZwAA
>> "%~1" echo N1YASQBWAEUAIABCAHUAcwBpAG4AZQBzAHMAIABTAHQAcgBlAGEAbQBpAG4AZwAg
>> "%~1" echo AEEARABCAAAPQQBuAGQAcgBvAGkAZAAAHXAAbABhAHQAZgBvAHIAbQAtAHQAbwBv
>> "%~1" echo AGwAcwABNUEAbgBkAHIAbwBpAGQAIABwAGwAYQB0AGYAbwByAG0ALQB0AG8AbwBs
>> "%~1" echo AHMAIABBAEQAQgABD2EAZABiAC4AZQB4AGUAAAdhAGQAYgAAHUEARABCACAAZQB4
>> "%~1" echo AGUAYwB1AHQAYQBiAGwAZQAAC1sAQQAtAFoAXQABC1sAMAAtADkAXQABJ1wAYgBb
>> "%~1" echo AEEALQBaADAALQA5AF0AewAxADIALAAyADAAfQBcAGIAAU1cAGIAKABbADAALQA5
>> "%~1" echo AEEALQBGAGEALQBmAF0AewAyAH0AOgApAHsANQB9AFsAMAAtADkAQQAtAEYAYQAt
>> "%~1" echo AGYAXQB7ADIAfQBcAGIAASMqACoAOgAqACoAOgAqACoAOgAqACoAOgAqACoAOgAq
>> "%~1" echo ACoAAD1cAGIAMQA5ADIAXAAuADEANgA4AFwALgBcAGQAewAxACwAMwB9AFwALgBc
>> "%~1" echo AGQAewAxACwAMwB9AFwAYgAAFzEAOQAyAC4AMQA2ADgALgB4AC4AeAAAQ1wAYgAx
>> "%~1" echo ADAAXAAuAFwAZAB7ADEALAAzAH0AXAAuAFwAZAB7ADEALAAzAH0AXAAuAFwAZAB7
>> "%~1" echo ADEALAAzAH0AXABiAAARMQAwAC4AeAAuAHgALgB4AABjXABiADEANwAyAFwALgAo
>> "%~1" echo ADEAWwA2AC0AOQBdAHwAMgBbADAALQA5AF0AfAAzAFsAMAAtADEAXQApAFwALgBc
>> "%~1" echo AGQAewAxACwAMwB9AFwALgBcAGQAewAxACwAMwB9AFwAYgABEzEANwAyAC4AeAAu
>> "%~1" echo AHgALgB4AABRKABTAFMASQBEAHwAQgBTAFMASQBEAHwAVwBpAGYAaQBTAHMAaQBk
>> "%~1" echo AHwAbQBXAGkAZgBpAEkAbgBmAG8AKQBbAF4ALABcAG4AXAByAF0AKgAAGyQAMQA9
>> "%~1" echo ADwAcgBlAGQAYQBjAHQAZQBkAD4AAE1yAG8AXAAuAGIAdQBpAGwAZABcAC4AZgBp
>> "%~1" echo AG4AZwBlAHIAcAByAGkAbgB0AFwAXQA6ACAAXABbAFsAXgBcAF0AXABuAFwAcgBd
>> "%~1" echo ACsAAEVyAG8ALgBiAHUAaQBsAGQALgBmAGkAbgBnAGUAcgBwAHIAaQBuAHQAXQA6
>> "%~1" echo ACAAWwA8AHIAZQBkAGEAYwB0AGUAZAA+AAArZgBpAG4AZwBlAHIAcAByAGkAbgB0
>> "%~1" echo AD0AWwBeACwAXABuAFwAcgBdACsAAC1mAGkAbgBnAGUAcgBwAHIAaQBuAHQAPQA8
>> "%~1" echo AHIAZQBkAGEAYwB0AGUAZAA+AAA1bwBzAF8AZgBpAG4AZwBlAHIAcAByAGkAbgB0
>> "%~1" echo AFsAXgAsAFwAbgBcAHIAXABcAH0AXQArAAAzbwBzAF8AZgBpAG4AZwBlAHIAcABy
>> "%~1" echo AGkAbgB0AD0APAByAGUAZABhAGMAdABlAGQAPgAALXMAZQBzAHMAaQBvAG4AXwBp
>> "%~1" echo AGQAWwBeACwAXABuAFwAcgBcAFwAfQBdACsAACtzAGUAcwBzAGkAbwBuAF8AaQBk
>> "%~1" echo AD0APAByAGUAZABhAGMAdABlAGQAPgAAETwAcwBlAHIAaQBhAGwAPgAAByoAKgAq
>> "%~1" echo AAADDQAAOWQAZQB2AGUAbABvAHAAbQBlAG4AdABfAHMAZQB0AHQAaQBuAGcAcwBf
>> "%~1" echo AGUAbgBhAGIAbABlAGQAACVkAGUAdgBpAGMAZQBfAHAAcgBvAHYAaQBzAGkAbwBu
>> "%~1" echo AGUAZAAAJ3UAcwBlAHIAXwBzAGUAdAB1AHAAXwBjAG8AbQBwAGwAZQB0AGUAAA93
>> "%~1" echo AGkAZgBpAF8AbwBuAAAhYQBpAHIAcABsAGEAbgBlAF8AbQBvAGQAZQBfAG8AbgAA
>> "%~1" echo FWgAdAB0AHAAXwBwAHIAbwB4AHkAACNnAGwAbwBiAGEAbABfAGgAdAB0AHAAXwBw
>> "%~1" echo AHIAbwB4AHkAAC9pAG4AcwB0AGEAbABsAF8AbgBvAG4AXwBtAGEAcgBrAGUAdABf
>> "%~1" echo AGEAcABwAHMAADl2AGUAcgBpAGYAaQBlAHIAXwB2AGUAcgBpAGYAeQBfAGEAZABi
>> "%~1" echo AF8AaQBuAHMAdABhAGwAbABzAAADJwABCScAXAAnACcAAQt0AG8AawBlAG4AAAM/
>> "%~1" echo AAADKwAAP2EAcABwAGwAaQBjAGEAdABpAG8AbgAvAGoAcwBvAG4AOwAgAGMAaABh
>> "%~1" echo AHIAcwBlAHQAPQB1AHQAZgAtADgAAT9IAFQAVABQAC8AMQAuADEAIAAyADAAMAAg
>> "%~1" echo AE8ASwANAAoAQwBvAG4AdABlAG4AdAAtAFQAeQBwAGUAOgAgAAElDQAKAEMAbwBu
>> "%~1" echo AHQAZQBuAHQALQBMAGUAbgBnAHQAaAA6ACAAAWENAAoAQwBhAGMAaABlAC0AQwBv
>> "%~1" echo AG4AdAByAG8AbAA6ACAAbgBvAC0AcwB0AG8AcgBlAA0ACgBDAG8AbgBuAGUAYwB0
>> "%~1" echo AGkAbwBuADoAIABjAGwAbwBzAGUADQAKAA0ACgABA3sAAAciADoAIgAAA30AAAVc
>> "%~1" echo AFwAAAVcAG4AAAVcAHIAAAVcAHQAAAVcAHUAAAV4ADQAAMABjuFQAEMARgBrAGIA
>> "%~1" echo MgBOADAAZQBYAEIAbABJAEcAaAAwAGIAVwB3ACsAQwBqAHgAbwBkAEcAMQBzAEkA
>> "%~1" echo RwB4AGgAYgBtAGMAOQBJAG4AcABvAEwAVQBOAE8ASQBqADQASwBQAEcAaABsAFkA
>> "%~1" echo VwBRACsAQwBqAHgAdABaAFgAUgBoAEkARwBOAG8AWQBYAEoAegBaAFgAUQA5AEkA
>> "%~1" echo bgBWADAAWgBpADAANABJAGoANABLAFAARwAxAGwAZABHAEUAZwBiAG0ARgB0AFoA
>> "%~1" echo VAAwAGkAZABtAGwAbABkADMAQgB2AGMAbgBRAGkASQBHAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkASQBuAGQAcABaAEgAUgBvAFAAVwBSAGwAZABtAGwAagBaAFMAMQAzAGEA
>> "%~1" echo VwBSADAAYQBDAHgAcABiAG0AbAAwAGEAVwBGAHMATABYAE4AagBZAFcAeABsAFAA
>> "%~1" echo VABFAGkAUABnAG8AOABkAEcAbAAwAGIARwBVACsAVQBYAFYAbABjADMAUQBnAFEA
>> "%~1" echo VQBSAEMASQBPAGEATwBwACsAVwBJAHQAdQBXAFAAcwBEAHcAdgBkAEcAbAAwAGIA
>> "%~1" echo RwBVACsAQwBqAHgAegBkAEgAbABzAFoAVAA0AEsATwBuAEoAdgBiADMAUgA3AEwA
>> "%~1" echo UwAxAGkAWgB6AG8AagBaAGoAVgBtAE4AMgBaAGkATwB5ADAAdABjADIAbABrAFoA
>> "%~1" echo VABvAGoAWgBtAFoAbQBPAHkAMAB0AFkAMgBGAHkAWgBEAG8AagBaAG0AWgBtAE8A
>> "%~1" echo eQAwAHQAYwAyADkAbQBkAEQAbwBqAFoAagBoAG0AWQBXAFoAagBPAHkAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBUAG8AagBaAFQASgBsAE8ARwBZAHcATwB5ADAAdABkAEcAVgA0AGQA
>> "%~1" echo RABvAGoATQBUAEUAeABPAEQASQAzAE8AeQAwAHQAYgBYAFYAMABaAFcAUQA2AEkA
>> "%~1" echo egBZADAATgB6AFEANABZAGoAcwB0AEwAVwBKAHMAZABXAFUANgBJAHoASQAxAE4A
>> "%~1" echo agBOAGwAWQBqAHMAdABMAFcAZAB5AFoAVwBWAHUATwBpAE0AeABOAG0ARQB6AE4A
>> "%~1" echo RwBFADcATABTADEAaABiAFcASgBsAGMAagBvAGoAWgBEAGsAMwBOAHoAQQAyAE8A
>> "%~1" echo eQAwAHQAYwBtAFYAawBPAGkATgBsAE0AVABGAGsATgBEAGcANwBMAFMAMQB1AFkA
>> "%~1" echo WABZADYATQBqAE0AMgBjAEgAZwA3AEwAUwAxAHkAWQBXAFIAcABkAFgATQA2AE8A
>> "%~1" echo SABCADQAZgBRAHAAaQBiADIAUgA1AEwAbQBSAGgAYwBtAHQANwBMAFMAMQBpAFoA
>> "%~1" echo egBvAGoATQBHAFkAeABOAEQARgBqAE8AeQAwAHQAYwAyAGwAawBaAFQAbwBqAE0A
>> "%~1" echo VABFAHgATwBEAEkAeABPAHkAMAB0AFkAMgBGAHkAWgBEAG8AagBNAFQAVQB4AFoA
>> "%~1" echo RABJADQATwB5ADAAdABjADIAOQBtAGQARABvAGoATQBUAEUAeABPAEQASQB5AE8A
>> "%~1" echo eQAwAHQAYgBHAGwAdQBaAFQAbwBqAE0AagBZAHoATQBqAFEAMABPAHkAMAB0AGQA
>> "%~1" echo RwBWADQAZABEAG8AagBaAFQAVgBsAFoARwBZADMATwB5ADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRADYASQB6AGsAMABZAFQATgBpAE8ASAAwAEsASwBuAHQAaQBiADMAZwB0AGMA
>> "%~1" echo MgBsADYAYQBXADUAbgBPAG0ASgB2AGMAbQBSAGwAYwBpADEAaQBiADMAaAA5AGEA
>> "%~1" echo SABSAHQAYgBDAHgAaQBiADIAUgA1AGUAMgAxAGgAYwBtAGQAcABiAGoAbwB3AE8A
>> "%~1" echo MgAxAHAAYgBpADEAbwBaAFcAbABuAGEASABRADYATQBUAEEAdwBKAFQAdABtAGIA
>> "%~1" echo MgA1ADAATABXAFoAaABiAFcAbABzAGUAVABvAGkAVQAyAFYAbgBiADIAVQBnAFYA
>> "%~1" echo VQBrAGkATABDAEoATgBhAFcATgB5AGIAMwBOAHYAWgBuAFEAZwBXAFcARgBJAFoA
>> "%~1" echo VwBrAGkATABFAEYAeQBhAFcARgBzAEwASABOAGgAYgBuAE0AdABjADIAVgB5AGEA
>> "%~1" echo VwBZADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAWgB5AGsANwBZADIAOQBzAGIAMwBJADYAZABtAEYAeQBLAEMAMAB0AGQA
>> "%~1" echo RwBWADQAZABDAGsANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQAwAGMA
>> "%~1" echo SABnADcAYgBHAFYAMABkAEcAVgB5AEwAWABOAHcAWQBXAE4AcABiAG0AYwA2AE0A
>> "%~1" echo SAAxAGkAZABYAFIAMABiADIANABzAGEAVwA1AHcAZABYAFEAcwBjADIAVgBzAFoA
>> "%~1" echo VwBOADAAZQAyAFoAdgBiAG4AUQA2AGEAVwA1AG8AWgBYAEoAcABkAEgAMABLAEwA
>> "%~1" echo bQBGAHcAYwBIAHQAdABhAFcANAB0AGEARwBWAHAAWgAyAGgAMABPAGoARQB3AE0A
>> "%~1" echo SABaAG8ATwAyAFIAcABjADMAQgBzAFkAWABrADYAWgAzAEoAcABaAEQAdABuAGMA
>> "%~1" echo bQBsAGsATABYAFIAbABiAFgAQgBzAFkAWABSAGwATABXAE4AdgBiAEgAVgB0AGIA
>> "%~1" echo bgBNADYAZABtAEYAeQBLAEMAMAB0AGIAbQBGADIASwBTAEEAeABaAG4ASQA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQBpAFoA
>> "%~1" echo eQBsADkATABuAE4AcABaAEcAVgA3AGMARwA5AHoAYQBYAFIAcABiADIANAA2AFoA
>> "%~1" echo bQBsADQAWgBXAFEANwBhAFcANQB6AFoAWABRADYATQBDAEIAaABkAFgAUgB2AEkA
>> "%~1" echo RABBAGcATQBEAHQAMwBhAFcAUgAwAGEARABwADIAWQBYAEkAbwBMAFMAMQB1AFkA
>> "%~1" echo WABZAHAATwAyAGgAbABhAFcAZABvAGQARABvAHgATQBEAEIAMgBhAEQAdABpAFkA
>> "%~1" echo VwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcAdABMAFgATgBwAFoA
>> "%~1" echo RwBVAHAATwAyAEoAdgBjAG0AUgBsAGMAaQAxAHkAYQBXAGQAbwBkAEQAbwB4AGMA
>> "%~1" echo SABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoA
>> "%~1" echo UwBrADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG0AYgBHAFYANABPADIAWgBzAFoA
>> "%~1" echo WABnAHQAWgBHAGwAeQBaAFcATgAwAGEAVwA5AHUATwBtAE4AdgBiAEgAVgB0AGIA
>> "%~1" echo bgAwAHUAWQBuAEoAaABiAG0AUgA3AGEARwBWAHAAWgAyAGgAMABPAGoAYwAyAGMA
>> "%~1" echo SABnADcAWgBHAGwAegBjAEcAeABoAGUAVABwAG0AYgBHAFYANABPADIARgBzAGEA
>> "%~1" echo VwBkAHUATABXAGwAMABaAFcAMQB6AE8AbQBOAGwAYgBuAFIAbABjAGoAdABuAFkA
>> "%~1" echo WABBADYATQBUAEoAdwBlAEQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAQQBnAE0A
>> "%~1" echo VABoAHcAZQBEAHQAaQBiADMASgBrAFoAWABJAHQAWQBtADkAMABkAEcAOQB0AE8A
>> "%~1" echo agBGAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEA
>> "%~1" echo VwA1AGwASwBYADAAdQBZAG4ASgBoAGIAbQBSAEoAWQAyADkAdQBlADMAZABwAFoA
>> "%~1" echo SABSAG8ATwBqAE0AMgBjAEgAZwA3AGEARwBWAHAAWgAyAGgAMABPAGoATQAyAGMA
>> "%~1" echo SABnADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwA0AGMA
>> "%~1" echo SABnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABLAFQAdABrAGEAWABOAHcAYgBHAEYANQBPAG0AZAB5AGEA
>> "%~1" echo VwBRADcAYwBHAHgAaABZADIAVQB0AGEAWABSAGwAYgBYAE0ANgBZADIAVgB1AGQA
>> "%~1" echo RwBWAHkATwAyAE4AdgBiAEcAOQB5AE8AbgBkAG8AYQBYAFIAbABmAFMANQBpAGMA
>> "%~1" echo bQBGAHUAWgBDAEIAaQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkA
>> "%~1" echo MgBzADcAWgBtADkAdQBkAEMAMQB6AGEAWABwAGwATwBqAEUAMgBjAEgAaAA5AEwA
>> "%~1" echo bQBKAHkAWQBXADUAawBJAEgATgB3AFkAVwA1ADcAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VABwAGkAYgBHADkAagBhAHoAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8A
>> "%~1" echo agBOAHcAZQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB0AGQA
>> "%~1" echo WABSAGwAWgBDAGsANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQB5AGMA
>> "%~1" echo SABoADkATABtAEoAeQBZAFcANQBrAFMAVwBOAHYAYgBpAEIAegBkAG0AYwBzAEwA
>> "%~1" echo bQA1AGgAZABpAEIAegBkAG0AYwBzAEwAbQBSAGwAZABtAGwAagBaAFUAbABqAGIA
>> "%~1" echo MgA0AGcAYwAzAFoAbgBlADIAWgBwAGIARwB3ADYAYgBtADkAdQBaAFQAdAB6AGQA
>> "%~1" echo SABKAHYAYQAyAFUANgBZADMAVgB5AGMAbQBWAHUAZABFAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo MwBOADAAYwBtADkAcgBaAFMAMQAzAGEAVwBSADAAYQBEAG8AeQBPADMATgAwAGMA
>> "%~1" echo bQA5AHIAWgBTADEAcwBhAFcANQBsAFkAMgBGAHcATwBuAEoAdgBkAFcANQBrAE8A
>> "%~1" echo MwBOADAAYwBtADkAcgBaAFMAMQBzAGEAVwA1AGwAYQBtADkAcABiAGoAcAB5AGIA
>> "%~1" echo MwBWAHUAWgBIADAASwBMAG0ANQBoAGQAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBkAHkAYQBXAFEANwBaADIARgB3AE8AagBSAHcAZQBEAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEUAeQBjAEgAaAA5AEwAbQA1AGgAZABpAEIAaABlADIAaABsAGEA
>> "%~1" echo VwBkAG8AZABEAG8AegBPAEgAQgA0AE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkA
>> "%~1" echo VwBSAHAAZABYAE0ANgBOADMAQgA0AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoA
>> "%~1" echo bQB4AGwAZQBEAHQAaABiAEcAbABuAGIAaQAxAHAAZABHAFYAdABjAHoAcABqAFoA
>> "%~1" echo VwA1ADAAWgBYAEkANwBaADIARgB3AE8AagBFAHcAYwBIAGcANwBjAEcARgBrAFoA
>> "%~1" echo RwBsAHUAWgB6AG8AdwBJAEQARQB5AGMASABnADcAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABiAFgAVgAwAFoAVwBRAHAATwAzAFIAbABlAEgAUQB0AFoA
>> "%~1" echo RwBWAGoAYgAzAEoAaABkAEcAbAB2AGIAagBwAHUAYgAyADUAbABPADIAWgB2AGIA
>> "%~1" echo bgBRAHQAZAAyAFYAcABaADIAaAAwAE8AagBjAHcATQBIADAAdQBiAG0ARgAyAEkA
>> "%~1" echo RwBFAGcAYwAzAFoAbgBlADMAZABwAFoASABSAG8ATwBqAEUANABjAEgAZwA3AGEA
>> "%~1" echo RwBWAHAAWgAyAGgAMABPAGoARQA0AGMASABoADkATABtADUAaABkAGkAQgBoAEwA
>> "%~1" echo bQBGAGoAZABHAGwAMgBaAFgAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBKAG4AWQBtAEUAbwBNAHoAYwBzAE8AVABrAHMATQBqAE0AMQBMAEMANAB4AE0A
>> "%~1" echo QwBrADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAG0AeAAxAFoA
>> "%~1" echo UwBsADkAQwBpADUAdABZAFcAbAB1AGUAMgBkAHkAYQBXAFEAdABZADIAOQBzAGQA
>> "%~1" echo VwAxAHUATwBqAEkANwBiAFcAbAB1AEwAWABkAHAAWgBIAFIAbwBPAGoAQQA3AGIA
>> "%~1" echo VwBsAHUATABXAGgAbABhAFcAZABvAGQARABvAHgATQBEAEIAMgBhAEQAdABpAFkA
>> "%~1" echo VwBOAHIAWgAzAEoAdgBkAFcANQBrAE8AbgBaAGgAYwBpAGcAdABMAFcASgBuAEsA
>> "%~1" echo WAAwAHUAZABHADkAdwBlADIAaABsAGEAVwBkAG8AZABEAG8AMwBOAG4AQgA0AE8A
>> "%~1" echo MgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AFkA
>> "%~1" echo MgBGAHkAWgBDAGsANwBZAG0AOQB5AFoARwBWAHkATABXAEoAdgBkAEgAUgB2AGIA
>> "%~1" echo VABvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBTAGsANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbQBiAEcAVgA0AE8A
>> "%~1" echo MgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMA
>> "%~1" echo agB0AHEAZABYAE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4AUQA2AGMA
>> "%~1" echo MwBCAGgAWQAyAFUAdABZAG0AVgAwAGQAMgBWAGwAYgBqAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEEAZwBNAGoAUgB3AGUARAB0AHcAYgAzAE4AcABkAEcAbAB2AGIA
>> "%~1" echo agBwAHoAZABHAGwAagBhADMAawA3AGQARwA5AHcATwBqAEEANwBlAGkAMQBwAGIA
>> "%~1" echo bQBSAGwAZQBEAG8AegBmAFMANQAwAGEAWABSAHMAWgBTAEIAbwBNAFgAdAB0AFkA
>> "%~1" echo WABKAG4AYQBXADQANgBNAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo agBGAHcAZQBIADAAdQBkAEcAbAAwAGIARwBVAGcAYwBIAHQAdABZAFgASgBuAGEA
>> "%~1" echo VwA0ADYATgBYAEIANABJAEQAQQBnAE0ARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQB6AGEA
>> "%~1" echo WABwAGwATwBqAEUAegBjAEgAaAA5AEMAaQA1ADAAYgAyADkAcwBZAG0ARgB5AGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcAbABuAGIA
>> "%~1" echo aQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBaADIARgB3AE8A
>> "%~1" echo agBoAHcAZQBEAHQAbQBiAEcAVgA0AEwAWABkAHkAWQBYAEEANgBkADMASgBoAGMA
>> "%~1" echo RAB0AHEAZABYAE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4AUQA2AFoA
>> "%~1" echo bQB4AGwAZQBDADEAbABiAG0AUgA5AEwAbQBOAG8AYQBYAEEAcwBMAG0ASgAwAGIA
>> "%~1" echo bgB0AG8AWgBXAGwAbgBhAEgAUQA2AE0AegBSAHcAZQBEAHQAaQBiADMASgBrAFoA
>> "%~1" echo WABJADYATQBYAEIANABJAEgATgB2AGIARwBsAGsASQBIAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwB4AHAAYgBtAFUAcABPADIASgBoAFkAMgB0AG4AYwBtADkAMQBiAG0AUQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABjADIAOQBtAGQAQwBrADcAWQAyADkAcwBiADMASQA2AGQA
>> "%~1" echo bQBGAHkASwBDADAAdABkAEcAVgA0AGQAQwBrADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo WABKAGgAWgBHAGwAMQBjAHoAbwAzAGMASABnADcAYwBHAEYAawBaAEcAbAB1AFoA
>> "%~1" echo egBvAHcASQBEAEUAeABjAEgAZwA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABwAGIA
>> "%~1" echo bQB4AHAAYgBtAFUAdABaAG0AeABsAGUARAB0AGgAYgBHAGwAbgBiAGkAMQBwAGQA
>> "%~1" echo RwBWAHQAYwB6AHAAagBaAFcANQAwAFoAWABJADcAWgAyAEYAdwBPAGoAZAB3AGUA
>> "%~1" echo RAB0AG0AYgAyADUAMABMAFgAZABsAGEAVwBkAG8AZABEAG8AMwBNAEQAQgA5AEwA
>> "%~1" echo bQBOAG8AYQBYAEIARQBiADMAUgA3AGQAMgBsAGsAZABHAGcANgBPAEgAQgA0AE8A
>> "%~1" echo MgBoAGwAYQBXAGQAbwBkAEQAbwA0AGMASABnADcAWQBtADkAeQBaAEcAVgB5AEwA
>> "%~1" echo WABKAGgAWgBHAGwAMQBjAHoAbwAxAE0AQwBVADcAWQBtAEYAagBhADIAZAB5AGIA
>> "%~1" echo MwBWAHUAWgBEAHAAMgBZAFgASQBvAEwAUwAxAHkAWgBXAFEAcABmAFMANQBqAGIA
>> "%~1" echo MgA1AHUAWgBXAE4AMABaAFcAUQBnAEwAbQBOAG8AYQBYAEIARQBiADMAUgA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQBuAGMA
>> "%~1" echo bQBWAGwAYgBpAGwAOQBMAG0ASgAwAGIAbgB0AGoAZABYAEoAegBiADMASQA2AGMA
>> "%~1" echo RwA5AHAAYgBuAFIAbABjAG4AMAB1AFkAbgBSAHUATABuAEIAeQBhAFcAMQBoAGMA
>> "%~1" echo bgBsADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AFkAbQB4ADEAWgBTAGsANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZAAyAGgAcABkAEcAVgA5AEwAbQBKADAAYgBpADUAbgBhAEcAOQB6AGQA
>> "%~1" echo SAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBuAFIAeQBZAFcANQB6AGMA
>> "%~1" echo RwBGAHkAWgBXADUAMABmAFEAbwB1AGQAMwBKAGgAYwBIAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEUANABjAEgAZwBnAE0AagBSAHcAZQBDAEEAegBNAG4AQgA0AE8A
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAbQBiAEcAVgA0AEwA
>> "%~1" echo VwBSAHAAYwBtAFYAagBkAEcAbAB2AGIAagBwAGoAYgAyAHgAMQBiAFcANAA3AFoA
>> "%~1" echo MgBGAHcATwBqAEUAMABjAEgAZwA3AGIAVwBGADQATABYAGQAcABaAEgAUgBvAE8A
>> "%~1" echo agBFADAATwBEAEIAdwBlAEQAdAB0AGEAVwA0AHQAYQBHAFYAcABaADIAaAAwAE8A
>> "%~1" echo bQBOAGgAYgBHAE0AbwBNAFQAQQB3AGQAbQBnAGcATABTAEEAMwBOAG4AQgA0AEsA
>> "%~1" echo VAB0AGkAWQBXAE4AcgBaADMASgB2AGQAVwA1AGsATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwBKAG4ASwBYADAAdQBiAG0AOQAwAGEAVwBOAGwAZQAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo agBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAYwBtAGQAaQBZAFMAZwB5AE0A
>> "%~1" echo VABjAHMATQBUAEUANQBMAEQAWQBzAEwAagBNAHcASwBUAHQAaQBZAFcATgByAFoA
>> "%~1" echo MwBKAHYAZABXADUAawBPAG4ASgBuAFkAbQBFAG8ATQBqAEUAMwBMAEQARQB4AE8A
>> "%~1" echo UwB3ADIATABDADQAdwBOAHkAawA3AFkAMgA5AHMAYgAzAEkANgBJADIASQB6AE4A
>> "%~1" echo agBVAHcATgBUAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8A
>> "%~1" echo agBoAHcAZQBEAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUAdwBjAEgAZwBnAE0A
>> "%~1" echo VABOAHcAZQBEAHQAbQBiADIANQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwAzAE0A
>> "%~1" echo RABBADcAYgBXAGwAdQBMAFcAaABsAGEAVwBkAG8AZABEAG8AdwBPADIAeABwAGIA
>> "%~1" echo bQBVAHQAYQBHAFYAcABaADIAaAAwAE8AagBFAHUATgBEAFYAOQBZAG0AOQBrAGUA
>> "%~1" echo UwA1AGsAWQBYAEoAcgBJAEMANQB1AGIAMwBSAHAAWQAyAFYANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYASQAyAFkAMABZAHoAQQAyAFkAWAAwAHUAYwBHAEYAbgBaAFgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0ANQB2AGIAbQBWADkATABuAEIAaABaADIAVQB1AFkA
>> "%~1" echo VwBOADAAYQBYAFoAbABlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBaADMASgBwAFoA
>> "%~1" echo RAB0AG4AWQBYAEEANgBNAFQAUgB3AGUASAAwAHUAYwBtADkAMwBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AYwBtAGwAawBMAFgAUgBsAGIA
>> "%~1" echo WABCAHMAWQBYAFIAbABMAFcATgB2AGIASABWAHQAYgBuAE0ANgBNAFcAWgB5AEkA
>> "%~1" echo RABGAG0AYwBqAHQAbgBZAFgAQQA2AE0AVABSAHcAZQBIADAAdQBjAG0AOQAzAE0A
>> "%~1" echo MwB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBaADMASgBwAFoA
>> "%~1" echo QwAxADAAWgBXADEAdwBiAEcARgAwAFoAUwAxAGoAYgAyAHgAMQBiAFcANQB6AE8A
>> "%~1" echo bgBKAGwAYwBHAFYAaABkAEMAZwB6AEwARABGAG0AYwBpAGsANwBaADIARgB3AE8A
>> "%~1" echo agBFADAAYwBIAGgAOQBDAGkANQBqAFkAWABKAGsAZQAyAEoAaABZADIAdABuAGMA
>> "%~1" echo bQA5ADEAYgBtAFEANgBkAG0ARgB5AEsAQwAwAHQAWQAyAEYAeQBaAEMAawA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBPAGoARgB3AGUAQwBCAHoAYgAyAHgAcABaAEMAQgAyAFkA
>> "%~1" echo WABJAG8ATABTADEAcwBhAFcANQBsAEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBGAGsAYQBYAFYAegBPAG4AWgBoAGMAaQBnAHQATABYAEoAaABaAEcAbAAxAGMA
>> "%~1" echo eQBrADcAYgAzAFoAbABjAG0AWgBzAGIAMwBjADYAYQBHAGwAawBaAEcAVgB1AGYA
>> "%~1" echo UwA1AG8AWgBXAEYAawBlADIAaABsAGEAVwBkAG8AZABEAG8AMABOAEgAQgA0AE8A
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQBpAGIAMwBSADAAYgAyADAANgBNAFgAQgA0AEkA
>> "%~1" echo SABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8A
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAaABiAEcAbABuAGIA
>> "%~1" echo aQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBhAG4AVgB6AGQA
>> "%~1" echo RwBsAG0AZQBTADEAagBiADIANQAwAFoAVwA1ADAATwBuAE4AdwBZAFcATgBsAEwA
>> "%~1" echo VwBKAGwAZABIAGQAbABaAFcANAA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB3AEkA
>> "%~1" echo RABFADAAYwBIAGgAOQBMAG0AaABsAFkAVwBRAGcAYQBEAEoANwBiAFcARgB5AFoA
>> "%~1" echo MgBsAHUATwBqAEEANwBaAG0AOQB1AGQAQwAxAHoAYQBYAHAAbABPAGoARQAxAGMA
>> "%~1" echo SABoADkATABuAFIAaABaADMAdABvAFoAVwBsAG4AYQBIAFEANgBNAGoAUgB3AGUA
>> "%~1" echo RAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBsAHUAYgBHAGwAdQBaAFMAMQBtAGIA
>> "%~1" echo RwBWADQATwAyAEYAcwBhAFcAZAB1AEwAVwBsADAAWgBXADEAegBPAG0ATgBsAGIA
>> "%~1" echo bgBSAGwAYwBqAHQAaQBiADMASgBrAFoAWABJADYATQBYAEIANABJAEgATgB2AGIA
>> "%~1" echo RwBsAGsASQBIAFoAaABjAGkAZwB0AEwAVwB4AHAAYgBtAFUAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGQAbQBGAHkASwBDADAAdABjADIAOQBtAGQA
>> "%~1" echo QwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwA1AE8A
>> "%~1" echo VABsAHcAZQBEAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEAZwBPAFgAQgA0AE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXADEAMQBkAEcAVgBrAEsA
>> "%~1" echo VAB0AG0AYgAyADUAMABMAFgATgBwAGUAbQBVADYATQBUAEoAdwBlAEgAMAB1AFkA
>> "%~1" echo bQA5AGsAZQBYAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUAMABjAEgAaAA5AEMA
>> "%~1" echo aQA1AGsAWgBYAFoAcABZADIAVgBUAGQASABKAHAAYwBIAHQAawBhAFgATgB3AGIA
>> "%~1" echo RwBGADUATwBtAGQAeQBhAFcAUQA3AFoAMwBKAHAAWgBDADEAMABaAFcAMQB3AGIA
>> "%~1" echo RwBGADAAWgBTADEAagBiADIAeAAxAGIAVwA1AHoATwBqAGMAdwBjAEgAZwBnAE0A
>> "%~1" echo VwBaAHkASQBHAEYAMQBkAEcAOAA3AFoAMgBGAHcATwBqAEUAMABjAEgAZwA3AFkA
>> "%~1" echo VwB4AHAAWgAyADQAdABhAFgAUgBsAGIAWABNADYAWQAyAFYAdQBkAEcAVgB5AGYA
>> "%~1" echo UwA1AGsAWgBYAFoAcABZADIAVgBKAFkAMgA5AHUAZQAzAGQAcABaAEgAUgBvAE8A
>> "%~1" echo agBjAHcAYwBIAGcANwBhAEcAVgBwAFoAMgBoADAATwBqAGMAdwBjAEgAZwA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFgASgBoAFoARwBsADEAYwB6AG8AeABNAG4AQgA0AE8A
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAdwBiAEcARgBqAFoA
>> "%~1" echo UwAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoAMgBKAGgASwBEAE0AMwBMAEQAawA1AEwA
>> "%~1" echo RABJAHoATgBTAHcAdQBNAFQAQQBwAE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABXAEoAcwBkAFcAVQBwAGYAUwA1AGsAWgBYAFoAcABZADIAVgBKAFkA
>> "%~1" echo MgA5AHUASQBIAE4AMgBaADMAdAAzAGEAVwBSADAAYQBEAG8AMABOAEgAQgA0AE8A
>> "%~1" echo MgBoAGwAYQBXAGQAbwBkAEQAbwAwAE4ASABCADQAZgBTADUAawBaAFgAWgBwAFkA
>> "%~1" echo MgBWAE8AWQBXADEAbABlADIAWgB2AGIAbgBRAHQAYwAyAGwANgBaAFQAbwB5AE0A
>> "%~1" echo SABCADQATwAyAFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAZwB3AE0A
>> "%~1" echo SAAwAHUAYQBHAGwAdQBkAEgAdAB0AFkAWABKAG4AYQBXADQAdABkAEcAOQB3AE8A
>> "%~1" echo agBkAHcAZQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB0AGQA
>> "%~1" echo WABSAGwAWgBDAGsANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0A
>> "%~1" echo UwA0ADEATgBYADAAdQBjADMAUgBoAGQARwBWADcAWgBtADkAdQBkAEMAMQB6AGEA
>> "%~1" echo WABwAGwATwBqAEkAMgBjAEgAZwA3AFoAbQA5AHUAZABDADEAMwBaAFcAbABuAGEA
>> "%~1" echo SABRADYATwBUAEEAdwBPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo WABKAGwAWgBDAGwAOQBMAG4ATgAwAFkAWABSAGwATABtAGQAdgBiADIAUgA3AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBkAG0ARgB5AEsAQwAwAHQAWgAzAEoAbABaAFcANABwAGYA
>> "%~1" echo UwA1AHkAYQBXAGQANwBaAEcAbAB6AGMARwB4AGgAZQBUAHAAbgBjAG0AbABrAE8A
>> "%~1" echo MgBkAHkAYQBXAFEAdABkAEcAVgB0AGMARwB4AGgAZABHAFUAdABZADIAOQBzAGQA
>> "%~1" echo VwAxAHUAYwB6AG8AeABaAG4ASQBnAE0AUwA0ADAAWgBuAEkAZwBNAFcAWgB5AE8A
>> "%~1" echo MgBkAGgAYwBEAG8AeABNAG4AQgA0AE8AMgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoA
>> "%~1" echo VwAxAHoATwBtAE4AbABiAG4AUgBsAGMAagB0AHQAWQBYAEoAbgBhAFcANAB0AGQA
>> "%~1" echo RwA5AHcATwBqAEUAMABjAEgAaAA5AEwAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoA
>> "%~1" echo WABKAEMAYgAzAGgANwBiAFcAbAB1AEwAVwBoAGwAYQBXAGQAbwBkAEQAbwAzAE8A
>> "%~1" echo SABCADQATwAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEA
>> "%~1" echo VwBRAGcAZABtAEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADQAYwBIAGcANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIAWgAwAEsA
>> "%~1" echo VAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBFAHcAYwBIAGcAZwBNAFQASgB3AGUA
>> "%~1" echo RAB0AGsAYQBYAE4AdwBiAEcARgA1AE8AbQBkAHkAYQBXAFEANwBZAFcAeABwAFoA
>> "%~1" echo MgA0AHQAWQAyADkAdQBkAEcAVgB1AGQARABwAGoAWgBXADUAMABaAFgASQA3AFoA
>> "%~1" echo MgBGAHcATwBqAFoAdwBlAEgAMAB1AFkAMgA5AHUAZABIAEoAdgBiAEcAeABsAGMA
>> "%~1" echo awBKAHYAZQBDAEEAdQBjAG0AOQBzAFoAWAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQB6AGEA
>> "%~1" echo WABwAGwATwBqAEUAeQBjAEgAaAA5AEwAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoA
>> "%~1" echo WABKAEMAYgAzAGcAZwBZAG4AdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo agBCAHcAZQBIADAAdQBZADIAOQB1AGQASABKAHYAYgBHAHgAbABjAGsASgB2AGUA
>> "%~1" echo QwBBAHUAYwAzAFIAaABkAEcAVgBVAFoAWABoADAAZQAyAFoAdgBiAG4AUQB0AGMA
>> "%~1" echo MgBsADYAWgBUAG8AeABNAG4AQgA0AE8AMgBOAHYAYgBHADkAeQBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABXADEAMQBkAEcAVgBrAEsAWAAwAHUAWQAyADkAdQBkAEgASgB2AGIA
>> "%~1" echo RwB4AGwAYwBrAEoAdgBlAEMANQBzAFoAVwBaADAAZQAzAFIAbABlAEgAUQB0AFkA
>> "%~1" echo VwB4AHAAWgAyADQANgBiAEcAVgBtAGQARAB0AGkAYgAzAEoAawBaAFgASQB0AGIA
>> "%~1" echo RwBWAG0AZABEAG8AegBjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAWQBtAHgAMQBaAFMAbAA5AEwAbQBOAHYAYgBuAFIAeQBiADIAeABzAFoA
>> "%~1" echo WABKAEMAYgAzAGcAdQBjAG0AbABuAGEASABSADcAZABHAFYANABkAEMAMQBoAGIA
>> "%~1" echo RwBsAG4AYgBqAHAAeQBhAFcAZABvAGQARAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBsAG4AYQBIAFEANgBNADMAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAEoAcwBkAFcAVQBwAGYAUwA1AG8AWgBXAEYAawBjADIAVgAwAFEA
>> "%~1" echo bQA5ADQAZQAyADEAcABiAGkAMQBvAFoAVwBsAG4AYQBIAFEANgBPAFQAQgB3AGUA
>> "%~1" echo RAB0AGkAYgAzAEoAawBaAFgASQA2AE0AWABCADQASQBIAE4AdgBiAEcAbABrAEkA
>> "%~1" echo SABaAGgAYwBpAGcAdABMAFcAeABwAGIAbQBVAHAATwAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo aQAxAHkAWQBXAFIAcABkAFgATQA2AE0AVABCAHcAZQBEAHQAaQBZAFcATgByAFoA
>> "%~1" echo MwBKAHYAZABXADUAawBPAG0AeABwAGIAbQBWAGgAYwBpADEAbgBjAG0ARgBrAGEA
>> "%~1" echo VwBWAHUAZABDAGcAeABPAEQAQgBrAFoAVwBjAHMAYwBtAGQAaQBZAFMAZwB6AE4A
>> "%~1" echo eQB3ADUATwBTAHcAeQBNAHoAVQBzAEwAagBFAHcASwBTAHgAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHoAYgAyAFoAMABLAFMAawA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMA
>> "%~1" echo bQBsAGsATwAyAGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkA
>> "%~1" echo MgA5AHMAZABXADEAdQBjAHoAbwAyAE4ASABCADQASQBEAEYAbQBjAGoAdABuAFkA
>> "%~1" echo WABBADYATQBUAEoAdwBlAEQAdABoAGIARwBsAG4AYgBpADEAcABkAEcAVgB0AGMA
>> "%~1" echo egBwAGoAWgBXADUAMABaAFgASQA3AGMARwBGAGsAWgBHAGwAdQBaAHoAbwB4AE0A
>> "%~1" echo bgBCADQAZgBRAG8AdQBaAEcAVgAyAGEAVwBOAGwAVABXAFYAMABZAFgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAGoARgBtAGMA
>> "%~1" echo aQBBAHgAWgBuAEkANwBaADIARgB3AE8AagBFAHcAYwBIAGcANwBiAFcARgB5AFoA
>> "%~1" echo MgBsAHUATABYAFIAdgBjAEQAbwB4AE0AMwBCADQAZgBTADUAdABaAFgAUgBoAFMA
>> "%~1" echo WABSAGwAYgBYAHQAbwBaAFcAbABuAGEASABRADYATgBUAEoAdwBlAEQAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQB5AFkA
>> "%~1" echo VwBSAHAAZABYAE0ANgBOADMAQgA0AE8AMgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIA
>> "%~1" echo bQBRADYAZABtAEYAeQBLAEMAMAB0AGMAMgA5AG0AZABDAGsANwBjAEcARgBrAFoA
>> "%~1" echo RwBsAHUAWgB6AG8ANQBjAEgAZwBnAE0AVABKAHcAZQBIADAAdQBiAFcAVgAwAFkA
>> "%~1" echo VQBsADAAWgBXADAAZwBjADMAQgBoAGIAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBKAHMAYgAyAE4AcgBPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo VABKAHcAZQBIADAAdQBiAFcAVgAwAFkAVQBsADAAWgBXADAAZwBZAG4AdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAyADEAaABjAG0AZABwAGIA
>> "%~1" echo aQAxADAAYgAzAEEANgBOAEgAQgA0AE8AMwBkAG8AYQBYAFIAbABMAFgATgB3AFkA
>> "%~1" echo VwBOAGwATwBtADUAdgBkADMASgBoAGMARAB0AHYAZABtAFYAeQBaAG0AeAB2AGQA
>> "%~1" echo egBwAG8AYQBXAFIAawBaAFcANAA3AGQARwBWADQAZABDADEAdgBkAG0AVgB5AFoA
>> "%~1" echo bQB4AHYAZAB6AHAAbABiAEcAeABwAGMASABOAHAAYwAzADAASwBMAG0AMQBsAGQA
>> "%~1" echo SABKAHAAWQAwAGQAeQBhAFcAUgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMA
>> "%~1" echo bQBsAGsATwAyAGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkA
>> "%~1" echo MgA5AHMAZABXADEAdQBjAHoAcAB5AFoAWABCAGwAWQBYAFEAbwBNAHkAdwB4AFoA
>> "%~1" echo bgBJAHAATwAyAGQAaABjAEQAbwB4AE0ASABCADQAZgBTADUAdABaAFgAUgB5AGEA
>> "%~1" echo VwBOADcAYQBHAFYAcABaADIAaAAwAE8AagBFAHgATQBuAEIANABPADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBqAG8AeABjAEgAZwBnAGMAMgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAYgBHAGwAdQBaAFMAawA3AFkAbQA5AHkAWgBHAFYAeQBMAFgASgBoAFoA
>> "%~1" echo RwBsADEAYwB6AG8ANABjAEgAZwA3AFkAbQBGAGoAYQAyAGQAeQBiADMAVgB1AFoA
>> "%~1" echo RABwADIAWQBYAEkAbwBMAFMAMQB6AGIAMgBaADAASwBUAHQAdwBZAFcAUgBrAGEA
>> "%~1" echo VwA1AG4ATwBqAEUAeQBjAEgAZwA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABuAGMA
>> "%~1" echo bQBsAGsATwAyAGQAeQBhAFcAUQB0AGQARwBWAHQAYwBHAHgAaABkAEcAVQB0AFkA
>> "%~1" echo MgA5AHMAZABXADEAdQBjAHoAbwAyAE8ASABCADQASQBEAEYAbQBjAGoAdABoAGIA
>> "%~1" echo RwBsAG4AYgBpADEAcABkAEcAVgB0AGMAegBwAGoAWgBXADUAMABaAFgASQA3AFoA
>> "%~1" echo MgBGAHcATwBqAEUAdwBjAEgAaAA5AEwAbQAxAGwAZABIAEoAcABZAHkAQgB6AGQA
>> "%~1" echo bQBjAHUAYwBtAGwAdQBaADMAdAAzAGEAVwBSADAAYQBEAG8AMgBPAEgAQgA0AE8A
>> "%~1" echo MgBoAGwAYQBXAGQAbwBkAEQAbwAyAE8ASABCADQATwAzAFIAeQBZAFcANQB6AFoA
>> "%~1" echo bQA5AHkAYgBUAHAAeQBiADMAUgBoAGQARwBVAG8ATABUAGsAdwBaAEcAVgBuAEsA
>> "%~1" echo WAAwAHUAZABIAEoAaABZADIAdAA3AFoAbQBsAHMAYgBEAHAAdQBiADIANQBsAE8A
>> "%~1" echo MwBOADAAYwBtADkAcgBaAFQAcAB5AFoAMgBKAGgASwBEAEUAMABPAEMAdwB4AE4A
>> "%~1" echo agBNAHMATQBUAGcAMABMAEMANAB5AE4AUwBrADcAYwAzAFIAeQBiADIAdABsAEwA
>> "%~1" echo WABkAHAAWgBIAFIAbwBPAGoAaAA5AEwAbQAxAGwAZABHAFYAeQBlADIAWgBwAGIA
>> "%~1" echo RwB3ADYAYgBtADkAdQBaAFQAdAB6AGQASABKAHYAYQAyAFUANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAWQBtAHgAMQBaAFMAawA3AGMAMwBSAHkAYgAyAHQAbABMAFgAZABwAFoA
>> "%~1" echo SABSAG8ATwBqAGcANwBjADMAUgB5AGIAMgB0AGwATABXAHgAcABiAG0AVgBqAFkA
>> "%~1" echo WABBADYAYwBtADkAMQBiAG0AUgA5AEwAbQAxAGwAZABIAEoAcABZAHkANQBuAGMA
>> "%~1" echo bQBWAGwAYgBpAEEAdQBiAFcAVgAwAFoAWABKADcAYwAzAFIAeQBiADIAdABsAE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcAZAB5AFoAVwBWAHUASwBYADAAdQBiAFcAVgAwAGMA
>> "%~1" echo bQBsAGoATABtAEYAdABZAG0AVgB5AEkAQwA1AHQAWgBYAFIAbABjAG4AdAB6AGQA
>> "%~1" echo SABKAHYAYQAyAFUANgBkAG0ARgB5AEsAQwAwAHQAWQBXADEAaQBaAFgASQBwAGYA
>> "%~1" echo UwA1AHQAWgBYAFIAeQBhAFcATQB1AGMAbQBWAGsASQBDADUAdABaAFgAUgBsAGMA
>> "%~1" echo bgB0AHoAZABIAEoAdgBhADIAVQA2AGQAbQBGAHkASwBDADAAdABjAG0AVgBrAEsA
>> "%~1" echo WAAwAHUAYgBXAFYAMABjAG0AbABqAFYAbQBGAHMAZABXAFYANwBaAG0AOQB1AGQA
>> "%~1" echo QwAxAHoAYQBYAHAAbABPAGoASQB6AGMASABnADcAWgBtADkAdQBkAEMAMQAzAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBPAFQAQQB3AE8AMwBkAG8AYQBYAFIAbABMAFgATgB3AFkA
>> "%~1" echo VwBOAGwATwBtADUAdgBkADMASgBoAGMASAAwAHUAYgBXAFYAMABjAG0AbABqAFQA
>> "%~1" echo RwBGAGkAWgBXAHgANwBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwAyAGMA
>> "%~1" echo SABnADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAyAFoAdgBiAG4AUQB0AGMAMgBsADYAWgBUAG8AeABNAG4AQgA0AGYA
>> "%~1" echo UQBvAHUAYgBXAGwAdQBhAFUAZAB5AGEAVwBSADcAWgBHAGwAegBjAEcAeABoAGUA
>> "%~1" echo VABwAG4AYwBtAGwAawBPADIAZAB5AGEAVwBRAHQAZABHAFYAdABjAEcAeABoAGQA
>> "%~1" echo RwBVAHQAWQAyADkAcwBkAFcAMQB1AGMAegBwAHkAWgBYAEIAbABZAFgAUQBvAE4A
>> "%~1" echo QwB3AHgAWgBuAEkAcABPADIAZABoAGMARABvAHgATQBIAEIANABmAFMANQB0AGEA
>> "%~1" echo VwA1AHAAZQAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEA
>> "%~1" echo VwBRAGcAZABtAEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADQAYwBIAGcANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkAWABJAG8ATABTADEAegBiADIAWgAwAEsA
>> "%~1" echo VAB0AHcAWQBXAFIAawBhAFcANQBuAE8AagBFAHgAYwBIAGgAOQBMAG0AMQBwAGIA
>> "%~1" echo bQBrAGcAYwAzAEIAaABiAG4AdABrAGEAWABOAHcAYgBHAEYANQBPAG0ASgBzAGIA
>> "%~1" echo MgBOAHIATwAyAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcAMQAxAGQA
>> "%~1" echo RwBWAGsASwBUAHQAbQBiADIANQAwAEwAWABOAHAAZQBtAFUANgBNAFQASgB3AGUA
>> "%~1" echo SAAwAHUAYgBXAGwAdQBhAFMAQgBpAGUAMgBSAHAAYwAzAEIAcwBZAFgAawA2AFkA
>> "%~1" echo bQB4AHYAWQAyAHMANwBiAFcARgB5AFoAMgBsAHUATABYAFIAdgBjAEQAbwAyAGMA
>> "%~1" echo SABnADcAZAAyAGgAcABkAEcAVQB0AGMAMwBCAGgAWQAyAFUANgBiAG0AOQAzAGMA
>> "%~1" echo bQBGAHcATwAyADkAMgBaAFgASgBtAGIARwA5ADMATwBtAGgAcABaAEcAUgBsAGIA
>> "%~1" echo agB0ADAAWgBYAGgAMABMAFcAOQAyAFoAWABKAG0AYgBHADkAMwBPAG0AVgBzAGIA
>> "%~1" echo RwBsAHcAYwAyAGwAegBmAFMANQBwAGIAbQBaAHYAUgAzAEoAcABaAEgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAG4ASgBsAGMA
>> "%~1" echo RwBWAGgAZABDAGcAegBMAEQARgBtAGMAaQBrADcAWgAyAEYAdwBPAGoARQB3AGMA
>> "%~1" echo SABoADkATABtAGwAdQBaAG0AOQBVAGEAVwB4AGwAZQAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo agBvAHgAYwBIAGcAZwBjADIAOQBzAGEAVwBRAGcAZABtAEYAeQBLAEMAMAB0AGIA
>> "%~1" echo RwBsAHUAWgBTAGsANwBZAG0AOQB5AFoARwBWAHkATABYAEoAaABaAEcAbAAxAGMA
>> "%~1" echo egBvADQAYwBIAGcANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAegBiADIAWgAwAEsAVAB0AHcAWQBXAFIAawBhAFcANQBuAE8A
>> "%~1" echo agBFAHgAYwBIAGcANwBiAFcAbAB1AEwAVwBoAGwAYQBXAGQAbwBkAEQAbwAxAE8A
>> "%~1" echo SABCADQAZgBTADUAcABiAG0AWgB2AFYARwBsAHMAWgBTAEIAegBjAEcARgB1AGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFkAbQB4AHYAWQAyAHMANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABPADIAWgB2AGIA
>> "%~1" echo bgBRAHQAYwAyAGwANgBaAFQAbwB4AE0AbgBCADQAZgBTADUAcABiAG0AWgB2AFYA
>> "%~1" echo RwBsAHMAWgBTAEIAaQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkA
>> "%~1" echo MgBzADcAYgBXAEYAeQBaADIAbAB1AEwAWABSAHYAYwBEAG8AMQBjAEgAZwA3AGQA
>> "%~1" echo MgA5AHkAWgBDADEAaQBjAG0AVgBoAGEAegBwAGkAYwBtAFYAaABhAHkAMQAzAGIA
>> "%~1" echo MwBKAGsAZgBTADUAbABlAEgAQgB2AGMAbgBSAEMAYgAzAGgANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAbgBjAG0AbABrAE8AMgBkAHkAYQBXAFEAdABkAEcAVgB0AGMA
>> "%~1" echo RwB4AGgAZABHAFUAdABZADIAOQBzAGQAVwAxAHUAYwB6AG8AeABaAG4ASQBnAFkA
>> "%~1" echo WABWADAAYgB6AHQAbgBZAFgAQQA2AE0AVABKAHcAZQBEAHQAaABiAEcAbABuAGIA
>> "%~1" echo aQAxAHAAZABHAFYAdABjAHoAcABqAFoAVwA1ADAAWgBYAEkANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATwBqAEYAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAeQBaADIASgBoAEsA
>> "%~1" echo RABNADMATABEAGsANQBMAEQASQB6AE4AUwB3AHUATQB6AFUAcABPADIASgBoAFkA
>> "%~1" echo MgB0AG4AYwBtADkAMQBiAG0AUQA2AGMAbQBkAGkAWQBTAGcAegBOAHkAdwA1AE8A
>> "%~1" echo UwB3AHkATQB6AFUAcwBMAGoAQQA0AEsAVAB0AGkAYgAzAEoAawBaAFgASQB0AGMA
>> "%~1" echo bQBGAGsAYQBYAFYAegBPAGoAaAB3AGUARAB0AHcAWQBXAFIAawBhAFcANQBuAE8A
>> "%~1" echo agBFAHoAYwBIAGgAOQBMAG0AVgA0AGMARwA5AHkAZABFAHgAcABiAG0AdAB6AGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAMwBKAHAAWgBEAHQAbgBZAFgAQQA2AE8A
>> "%~1" echo SABCADQAZgBTADUAbABlAEgAQgB2AGMAbgBSAE0AYQBXADUAcgBjAHkAQgBoAGUA
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABXAEoAcwBkAFcAVQBwAE8A
>> "%~1" echo MgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBqAGsAdwBNAEQAdAAzAGIA
>> "%~1" echo MwBKAGsATABXAEoAeQBaAFcARgByAE8AbQBKAHkAWgBXAEYAcgBMAFcARgBzAGIA
>> "%~1" echo SAAwAHUAZABHAEYAaQBiAEcAVgA3AGQAMgBsAGsAZABHAGcANgBNAFQAQQB3AEoA
>> "%~1" echo VAB0AGkAYgAzAEoAawBaAFgASQB0AFkAMgA5AHMAYgBHAEYAdwBjADIAVQA2AFkA
>> "%~1" echo MgA5AHMAYgBHAEYAdwBjADIAVgA5AEwAbgBSAGgAWQBtAHgAbABJAEgAUgBrAGUA
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQBpAGIAMwBSADAAYgAyADAANgBNAFgAQgA0AEkA
>> "%~1" echo SABOAHYAYgBHAGwAawBJAEgAWgBoAGMAaQBnAHQATABXAHgAcABiAG0AVQBwAE8A
>> "%~1" echo MwBCAGgAWgBHAFIAcABiAG0AYwA2AE8AWABCADQASQBEAEEANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AGIAWABWADAAWgBXAFEAcABPADMAWgBsAGMA
>> "%~1" echo bgBSAHAAWQAyAEYAcwBMAFcARgBzAGEAVwBkAHUATwBuAFIAdgBjAEgAMAB1AGQA
>> "%~1" echo RwBGAGkAYgBHAFUAZwBkAEgASQA2AGIARwBGAHoAZABDADEAagBhAEcAbABzAFoA
>> "%~1" echo QwBCADAAWgBIAHQAaQBiADMASgBrAFoAWABJAHQAWQBtADkAMABkAEcAOQB0AE8A
>> "%~1" echo agBCADkATABuAFIAaABZAG0AeABsAEkASABSAGsATwBtAHgAaABjADMAUQB0AFkA
>> "%~1" echo MgBoAHAAYgBHAFIANwBkAEcAVgA0AGQAQwAxAGgAYgBHAGwAbgBiAGoAcAB5AGEA
>> "%~1" echo VwBkAG8AZABEAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQAwAFoA
>> "%~1" echo WABoADAASwBUAHQAbQBiADIANQAwAEwAWABkAGwAYQBXAGQAbwBkAEQAbwAzAE0A
>> "%~1" echo RABBADcAZAAyADkAeQBaAEMAMQBpAGMAbQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEA
>> "%~1" echo eQAxADMAYgAzAEoAawBmAFEAbwB1AFkAMgAxAGsAUgAzAEoAcABaAEgAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AZAB5AGEAVwBRADcAWgAzAEoAcABaAEMAMQAwAFoA
>> "%~1" echo VwAxAHcAYgBHAEYAMABaAFMAMQBqAGIAMgB4ADEAYgBXADUAegBPAG4ASgBsAGMA
>> "%~1" echo RwBWAGgAZABDAGcAeQBMAEcAMQBwAGIAbQAxAGgAZQBDAGcAdwBMAEQARgBtAGMA
>> "%~1" echo aQBrAHAATwAyAGQAaABjAEQAbwB4AE0ASABCADQAZgBTADUAagBiAFcAUgA3AGEA
>> "%~1" echo RwBWAHAAWgAyAGgAMABPAGoAVQA0AGMASABnADcAWQBtADkAeQBaAEcAVgB5AE8A
>> "%~1" echo agBGAHcAZQBDAEIAegBiADIAeABwAFoAQwBCADIAWQBYAEkAbwBMAFMAMQBzAGEA
>> "%~1" echo VwA1AGwASwBUAHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYAbQBkAEQAbwB6AGMA
>> "%~1" echo SABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoA
>> "%~1" echo UwBrADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHoAYgAyAFoAMABLAFQAdABpAGIAMwBKAGsAWgBYAEkAdABjAG0ARgBrAGEA
>> "%~1" echo WABWAHoATwBqAGQAdwBlAEQAdAAwAFoAWABoADAATABXAEYAcwBhAFcAZAB1AE8A
>> "%~1" echo bQB4AGwAWgBuAFEANwBjAEcARgBrAFoARwBsAHUAWgB6AG8ANQBjAEgAZwBnAE0A
>> "%~1" echo VABGAHcAZQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQAwAFoA
>> "%~1" echo WABoADAASwBUAHQAagBkAFgASgB6AGIAMwBJADYAYwBHADkAcABiAG4AUgBsAGMA
>> "%~1" echo bgAwAHUAWQAyADEAawBJAEcASgA3AFoARwBsAHoAYwBHAHgAaABlAFQAcABpAGIA
>> "%~1" echo RwA5AGoAYQAzADAAdQBZADIAMQBrAEkASABOAHcAWQBXADUANwBaAEcAbAB6AGMA
>> "%~1" echo RwB4AGgAZQBUAHAAaQBiAEcAOQBqAGEAegB0AHQAWQBYAEoAbgBhAFcANAB0AGQA
>> "%~1" echo RwA5AHcATwBqAFIAdwBlAEQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHQAZABYAFIAbABaAEMAawA3AFoAbQA5AHUAZABDADEAegBhAFgAcABsAE8A
>> "%~1" echo agBFAHkAYwBIAGgAOQBMAG0ATgB0AFoAQwA1AGkAYgBIAFYAbABlADIASgB2AGMA
>> "%~1" echo bQBSAGwAYwBpADEAcwBaAFcAWgAwAEwAVwBOAHYAYgBHADkAeQBPAG4AWgBoAGMA
>> "%~1" echo aQBnAHQATABXAEoAcwBkAFcAVQBwAGYAUwA1AGoAYgBXAFEAdQBaADMASgBsAFoA
>> "%~1" echo VwA1ADcAWQBtADkAeQBaAEcAVgB5AEwAVwB4AGwAWgBuAFEAdABZADIAOQBzAGIA
>> "%~1" echo MwBJADYAZABtAEYAeQBLAEMAMAB0AFoAMwBKAGwAWgBXADQAcABmAFMANQBqAGIA
>> "%~1" echo VwBRAHUAWQBXADEAaQBaAFgASgA3AFkAbQA5AHkAWgBHAFYAeQBMAFcAeABsAFoA
>> "%~1" echo bgBRAHQAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABZAFcAMQBpAFoA
>> "%~1" echo WABJAHAAZgBTADUAagBiAFcAUQB1AGMAbQBWAGsAZQAyAEoAdgBjAG0AUgBsAGMA
>> "%~1" echo aQAxAHMAWgBXAFoAMABMAFcATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo WABKAGwAWgBDAGwAOQBDAGkANQBtAGIAMwBKAHQAZQAyAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkA
>> "%~1" echo WABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBUAE0AdwBjAEgAZwBnAE0A
>> "%~1" echo VwBaAHkASQBEAEYAbQBjAGkAQQA0AE0AbgBCADQATwAyAGQAaABjAEQAbwA1AGMA
>> "%~1" echo SABoADkAYQBXADUAdwBkAFgAUQBzAGMAMgBWAHMAWgBXAE4AMABlADIAaABsAGEA
>> "%~1" echo VwBkAG8AZABEAG8AegBOAG4AQgA0AE8AMgBKAHYAYwBtAFIAbABjAGoAbwB4AGMA
>> "%~1" echo SABnAGcAYwAyADkAcwBhAFcAUQBnAGQAbQBGAHkASwBDADAAdABiAEcAbAB1AFoA
>> "%~1" echo UwBrADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwAzAGMA
>> "%~1" echo SABnADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAHoAYgAyAFoAMABLAFQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxADAAWgBYAGgAMABLAFQAdAB3AFkAVwBSAGsAYQBXADUAbgBPAGoAQQBnAE0A
>> "%~1" echo VABCAHcAZQBIADAAdQBiAEcAOQBuAGUAMwBkAG8AYQBYAFIAbABMAFgATgB3AFkA
>> "%~1" echo VwBOAGwATwBuAEIAeQBaAFMAMQAzAGMAbQBGAHcATwAyADEAcABiAGkAMQBvAFoA
>> "%~1" echo VwBsAG4AYQBIAFEANgBPAEQAQgB3AGUARAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAdABkAFgAUgBsAFoAQwBrADcAWgBtADkAdQBkAEMAMQBtAFkA
>> "%~1" echo VwAxAHAAYgBIAGsANgBRADIAOQB1AGMAMgA5AHMAWQBYAE0AcwBJAGsAMQBwAFkA
>> "%~1" echo MwBKAHYAYwAyADkAbQBkAEMAQgBaAFkAVQBoAGwAYQBTAEkAcwBiAFcAOQB1AGIA
>> "%~1" echo MwBOAHcAWQBXAE4AbABPADIAeABwAGIAbQBVAHQAYQBHAFYAcABaADIAaAAwAE8A
>> "%~1" echo agBFAHUATgBUAFYAOQBDAGkANQAwAGIAMgBGAHoAZABIAE4ANwBjAEcAOQB6AGEA
>> "%~1" echo WABSAHAAYgAyADQANgBaAG0AbAA0AFoAVwBRADcAYwBtAGwAbgBhAEgAUQA2AE0A
>> "%~1" echo agBKAHcAZQBEAHQAaQBiADMAUgAwAGIAMgAwADYATQBqAEoAdwBlAEQAdAA2AEwA
>> "%~1" echo VwBsAHUAWgBHAFYANABPAGoATQB3AE8AMgBSAHAAYwAzAEIAcwBZAFgAawA2AFoA
>> "%~1" echo bQB4AGwAZQBEAHQAbQBiAEcAVgA0AEwAVwBSAHAAYwBtAFYAagBkAEcAbAB2AGIA
>> "%~1" echo agBwAGoAYgAyAHgAMQBiAFcANAB0AGMAbQBWADIAWgBYAEoAegBaAFQAdABuAFkA
>> "%~1" echo WABBADYATQBUAEIAdwBlAEQAdAAzAGEAVwBSADAAYQBEAHAAdABhAFcANABvAE0A
>> "%~1" echo egBrAHcAYwBIAGcAcwBZADIARgBzAFkAeQBnAHgATQBEAEIAMgBkAHkAQQB0AEkA
>> "%~1" echo RABJADQAYwBIAGcAcABLAFQAdAB3AGIAMgBsAHUAZABHAFYAeQBMAFcAVgAyAFoA
>> "%~1" echo VwA1ADAAYwB6AHAAdQBiADIANQBsAGYAUwA1ADAAYgAyAEYAegBkAEgAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkANgBNAFgAQgA0AEkASABOAHYAYgBHAGwAawBJAEgAWgBoAGMA
>> "%~1" echo aQBnAHQATABXAHgAcABiAG0AVQBwAE8AMgBKAHYAYwBtAFIAbABjAGkAMQBzAFoA
>> "%~1" echo VwBaADAATwBqAFIAdwBlAEMAQgB6AGIAMgB4AHAAWgBDAEIAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABLAFQAdABpAFkAVwBOAHIAWgAzAEoAdgBkAFcANQBrAE8A
>> "%~1" echo bgBaAGgAYwBpAGcAdABMAFcATgBoAGMAbQBRAHAATwAyAEoAdgBlAEMAMQB6AGEA
>> "%~1" echo RwBGAGsAYgAzAGMANgBNAEMAQQB4AE4AbgBCADQASQBEAE0ANABjAEgAZwBnAGMA
>> "%~1" echo bQBkAGkAWQBTAGcAeABOAFMAdwB5AE0AeQB3ADAATQBpAHcAdQBNAGoAQQBwAE8A
>> "%~1" echo MgBKAHYAYwBtAFIAbABjAGkAMQB5AFkAVwBSAHAAZABYAE0ANgBPAEgAQgA0AE8A
>> "%~1" echo MwBCAGgAWgBHAFIAcABiAG0AYwA2AE0AVABGAHcAZQBDAEEAeABNAG4AQgA0AE8A
>> "%~1" echo MgA5AHcAWQBXAE4AcABkAEgAawA2AE0ARAB0ADAAYwBtAEYAdQBjADIAWgB2AGMA
>> "%~1" echo bQAwADYAZABIAEoAaABiAG4ATgBzAFkAWABSAGwAVwBDAGcAeQBOAEgAQgA0AEsA
>> "%~1" echo UwBCADAAYwBtAEYAdQBjADIAeABoAGQARwBWAFoASwBEAEUAdwBjAEgAZwBwAEkA
>> "%~1" echo SABOAGoAWQBXAHgAbABLAEMANAA1AE8AQwBrADcAZABIAEoAaABiAG4ATgBwAGQA
>> "%~1" echo RwBsAHYAYgBqAHAAdgBjAEcARgBqAGEAWABSADUASQBDADQAeQBNAG4ATQBnAFoA
>> "%~1" echo VwBGAHoAWgBTAHgAMABjAG0ARgB1AGMAMgBaAHYAYwBtADAAZwBMAGoASQB5AGMA
>> "%~1" echo eQBCAGoAZABXAEoAcABZAHkAMQBpAFoAWABwAHAAWgBYAEkAbwBMAGoASQBzAEwA
>> "%~1" echo agBnAHMATABqAEkAcwBNAFMAawA3AFkAMgA5AHMAYgAzAEkANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAZABHAFYANABkAEMAawA3AGMARwA5AHAAYgBuAFIAbABjAGkAMQBsAGQA
>> "%~1" echo bQBWAHUAZABIAE0ANgBZAFgAVgAwAGIAMwAwAHUAZABHADkAaABjADMAUQB1AGMA
>> "%~1" echo MgBoAHYAZAAzAHQAdgBjAEcARgBqAGEAWABSADUATwBqAEUANwBkAEgASgBoAGIA
>> "%~1" echo bgBOAG0AYgAzAEoAdABPAG4AUgB5AFkAVwA1AHoAYgBHAEYAMABaAFYAZwBvAE0A
>> "%~1" echo QwBrAGcAZABIAEoAaABiAG4ATgBzAFkAWABSAGwAVwBTAGcAdwBLAFMAQgB6AFkA
>> "%~1" echo MgBGAHMAWgBTAGcAeABLAFgAMAB1AGQARwA5AGgAYwAzAFEAZwBZAG4AdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0ASgBzAGIAMgBOAHIATwAyADEAaABjAG0AZABwAGIA
>> "%~1" echo aQAxAGkAYgAzAFIAMABiADIAMAA2AE4ASABCADQAZgBTADUAMABiADIARgB6AGQA
>> "%~1" echo QwBCAHoAYwBHAEYAdQBlADIAUgBwAGMAMwBCAHMAWQBYAGsANgBZAG0AeAB2AFkA
>> "%~1" echo MgBzADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABiAFgAVgAwAFoA
>> "%~1" echo VwBRAHAATwAyAHgAcABiAG0AVQB0AGEARwBWAHAAWgAyAGgAMABPAGoARQB1AE4A
>> "%~1" echo RABVADcAZAAyADkAeQBaAEMAMQBpAGMAbQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEA
>> "%~1" echo eQAxADMAYgAzAEoAawBmAFMANQAwAGIAMgBGAHoAZABDADUAdgBhADMAdABpAGIA
>> "%~1" echo MwBKAGsAWgBYAEkAdABiAEcAVgBtAGQAQwAxAGoAYgAyAHgAdgBjAGoAcAAyAFkA
>> "%~1" echo WABJAG8ATABTADEAbgBjAG0AVgBsAGIAaQBsADkATABuAFIAdgBZAFgATgAwAEwA
>> "%~1" echo bQBWAHkAYwBuAHQAaQBiADMASgBrAFoAWABJAHQAYgBHAFYAbQBkAEMAMQBqAGIA
>> "%~1" echo MgB4AHYAYwBqAHAAMgBZAFgASQBvAEwAUwAxAHkAWgBXAFEAcABmAFMANQAwAGIA
>> "%~1" echo MgBGAHoAZABDADUAMwBZAFgASgB1AGUAMgBKAHYAYwBtAFIAbABjAGkAMQBzAFoA
>> "%~1" echo VwBaADAATABXAE4AdgBiAEcAOQB5AE8AbgBaAGgAYwBpAGcAdABMAFcARgB0AFkA
>> "%~1" echo bQBWAHkASwBYADAAdQBjAEcARgB5AFkAVwAxAE0AYQBYAE4AMABlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoARAB0AG4AWQBYAEEANgBNAFQAQgB3AGUA
>> "%~1" echo SAAwAHUAYwBHAEYAeQBZAFcAMQBKAGQARwBWAHQAZQAyAFIAcABjADMAQgBzAFkA
>> "%~1" echo WABrADYAWgAzAEoAcABaAEQAdABuAGMAbQBsAGsATABYAFIAbABiAFgAQgBzAFkA
>> "%~1" echo WABSAGwATABXAE4AdgBiAEgAVgB0AGIAbgBNADYATQBTADQAeQBaAG4ASQBnAEwA
>> "%~1" echo agBoAG0AYwBpAEEAdQBPAEcAWgB5AEkARwBGADEAZABHADgANwBaADIARgB3AE8A
>> "%~1" echo agBFAHcAYwBIAGcANwBZAFcAeABwAFoAMgA0AHQAYQBYAFIAbABiAFgATQA2AFkA
>> "%~1" echo MgBWAHUAZABHAFYAeQBPADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMA
>> "%~1" echo MgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIA
>> "%~1" echo MgBaADAASwBUAHQAaQBiADMASgBrAFoAWABJAHQAYwBtAEYAawBhAFgAVgB6AE8A
>> "%~1" echo agBoAHcAZQBEAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUAdwBjAEgAZwBnAE0A
>> "%~1" echo VABKAHcAZQBIADAAdQBjAEcARgB5AFkAVwAxAE8AWQBXADEAbABJAEcASgA3AFoA
>> "%~1" echo RwBsAHoAYwBHAHgAaABlAFQAcABpAGIARwA5AGoAYQAzADAAdQBjAEcARgB5AFkA
>> "%~1" echo VwAxAE8AWQBXADEAbABJAEgATgB3AFkAVwA0AHMATABuAEIAaABjAG0ARgB0AFYA
>> "%~1" echo bQBGAHMAZABXAFUAZwBjADMAQgBoAGIAbgB0AGsAYQBYAE4AdwBiAEcARgA1AE8A
>> "%~1" echo bQBKAHMAYgAyAE4AcgBPADIATgB2AGIARwA5AHkATwBuAFoAaABjAGkAZwB0AEwA
>> "%~1" echo VwAxADEAZABHAFYAawBLAFQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo VABKAHcAZQBEAHQAdABZAFgASgBuAGEAVwA0AHQAZABHADkAdwBPAGoATgB3AGUA
>> "%~1" echo SAAwAHUAYwBHAEYAeQBZAFcAMQBXAFkAVwB4ADEAWgBTAEIAaQBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBZAG0AeAB2AFkAMgBzADcAZAAyADkAeQBaAEMAMQBpAGMA
>> "%~1" echo bQBWAGgAYQB6AHAAaQBjAG0AVgBoAGEAeQAxADMAYgAzAEoAawBmAFMANQB3AFkA
>> "%~1" echo WABKAGgAYgBWAE4AMABZAFgAUgBsAGUAMgBoAGwAYQBXAGQAbwBkAEQAbwB5AE4A
>> "%~1" echo bgBCADQATwAyAEoAdgBjAG0AUgBsAGMAagBvAHgAYwBIAGcAZwBjADIAOQBzAGEA
>> "%~1" echo VwBRAGcAZABtAEYAeQBLAEMAMAB0AGIARwBsAHUAWgBTAGsANwBZAG0AOQB5AFoA
>> "%~1" echo RwBWAHkATABYAEoAaABaAEcAbAAxAGMAegBvADUATwBUAGwAdwBlAEQAdABrAGEA
>> "%~1" echo WABOAHcAYgBHAEYANQBPAG0AbAB1AGIARwBsAHUAWgBTADEAbQBiAEcAVgA0AE8A
>> "%~1" echo MgBGAHMAYQBXAGQAdQBMAFcAbAAwAFoAVwAxAHoATwBtAE4AbABiAG4AUgBsAGMA
>> "%~1" echo agB0AHEAZABYAE4AMABhAFcAWgA1AEwAVwBOAHYAYgBuAFIAbABiAG4AUQA2AFkA
>> "%~1" echo MgBWAHUAZABHAFYAeQBPADMAQgBoAFoARwBSAHAAYgBtAGMANgBNAEMAQQB4AE0A
>> "%~1" echo SABCADQATwAyAFoAdgBiAG4AUQB0AGQAMgBWAHAAWgAyAGgAMABPAGoAZwB3AE0A
>> "%~1" echo RAB0AG0AYgAyADUAMABMAFgATgBwAGUAbQBVADYATQBUAEoAdwBlAEgAMAB1AGMA
>> "%~1" echo RwBGAHkAWQBXADEASgBkAEcAVgB0AEwAbQBOAG8AWQBXADUAbgBaAFcAUgA3AFkA
>> "%~1" echo bQA5AHkAWgBHAFYAeQBMAFcATgB2AGIARwA5AHkATwBuAEoAbgBZAG0ARQBvAE0A
>> "%~1" echo agBFADMATABEAEUAeABPAFMAdwAyAEwAQwA0ADAATgBTAGsANwBZAG0ARgBqAGEA
>> "%~1" echo MgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoAMgBKAGgASwBEAEkAeABOAHkAdwB4AE0A
>> "%~1" echo VABrAHMATgBpAHcAdQBNAEQAWQBwAGYAUwA1AHcAWQBYAEoAaABiAFUAbAAwAFoA
>> "%~1" echo VwAwAHUAWQAyAGgAaABiAG0AZABsAFoAQwBBAHUAYwBHAEYAeQBZAFcAMQBUAGQA
>> "%~1" echo RwBGADAAWgBYAHQAaQBiADMASgBrAFoAWABJAHQAWQAyADkAcwBiADMASQA2AGMA
>> "%~1" echo bQBkAGkAWQBTAGcAeQBNAFQAYwBzAE0AVABFADUATABEAFkAcwBMAGoAUQAxAEsA
>> "%~1" echo VAB0AGoAYgAyAHgAdgBjAGoAcAAyAFkAWABJAG8ATABTADEAaABiAFcASgBsAGMA
>> "%~1" echo aQBrADcAWQBtAEYAagBhADIAZAB5AGIAMwBWAHUAWgBEAHAAeQBaADIASgBoAEsA
>> "%~1" echo RABJAHgATgB5AHcAeABNAFQAawBzAE4AaQB3AHUATQBEAGcAcABmAFMANQB3AFkA
>> "%~1" echo WABKAGgAYgBVAGwAMABaAFcAMAB1AGIAMgBzAGcATABuAEIAaABjAG0ARgB0AFUA
>> "%~1" echo MwBSAGgAZABHAFYANwBZAG0AOQB5AFoARwBWAHkATABXAE4AdgBiAEcAOQB5AE8A
>> "%~1" echo bgBKAG4AWQBtAEUAbwBNAGoASQBzAE0AVABZAHoATABEAGMAMABMAEMANAB6AE4A
>> "%~1" echo UwBrADcAWQAyADkAcwBiADMASQA2AGQAbQBGAHkASwBDADAAdABaADMASgBsAFoA
>> "%~1" echo VwA0AHAATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBjAG0AZABpAFkA
>> "%~1" echo UwBnAHkATQBpAHcAeABOAGoATQBzAE4AegBRAHMATABqAEEANABLAFgAMAB1AGMA
>> "%~1" echo bQBWAHoAWgBYAFIAQwBkAEcANQA3AGEARwBWAHAAWgAyAGgAMABPAGoATQB3AGMA
>> "%~1" echo SABnADcAWQBtADkAeQBaAEcAVgB5AEwAWABKAGgAWgBHAGwAMQBjAHoAbwAzAGMA
>> "%~1" echo SABnADcAWQBtADkAeQBaAEcAVgB5AE8AagBGAHcAZQBDAEIAegBiADIAeABwAFoA
>> "%~1" echo QwBCADIAWQBYAEkAbwBMAFMAMQBzAGEAVwA1AGwASwBUAHQAaQBZAFcATgByAFoA
>> "%~1" echo MwBKAHYAZABXADUAawBPAG4AWgBoAGMAaQBnAHQATABXAE4AaABjAG0AUQBwAE8A
>> "%~1" echo MgBOAHYAYgBHADkAeQBPAG4AWgBoAGMAaQBnAHQATABYAFIAbABlAEgAUQBwAE8A
>> "%~1" echo MgBaAHYAYgBuAFEAdABkADIAVgBwAFoAMgBoADAATwBqAGcAdwBNAEQAdAB3AFkA
>> "%~1" echo VwBSAGsAYQBXADUAbgBPAGoAQQBnAE0AVABCAHcAZQBEAHQAagBkAFgASgB6AGIA
>> "%~1" echo MwBJADYAYwBHADkAcABiAG4AUgBsAGMAbgAwAHUAYwBtAFYAegBaAFgAUgBDAGQA
>> "%~1" echo RwA0AHUAYwBIAEoAcABiAFcARgB5AGUAWAB0AGkAYgAzAEoAawBaAFgASQB0AFkA
>> "%~1" echo MgA5AHMAYgAzAEkANgBjAG0AZABpAFkAUwBnAHoATgB5AHcANQBPAFMAdwB5AE0A
>> "%~1" echo egBVAHMATABqAFEAMQBLAFQAdABqAGIAMgB4AHYAYwBqAHAAMgBZAFgASQBvAEwA
>> "%~1" echo UwAxAGkAYgBIAFYAbABLAFgAMAB1AGIAVwA5AGsAWQBXAHgATgBZAFgATgByAGUA
>> "%~1" echo MwBCAHYAYwAyAGwAMABhAFcAOQB1AE8AbQBaAHAAZQBHAFYAawBPADIAbAB1AGMA
>> "%~1" echo MgBWADAATwBqAEEANwBZAG0ARgBqAGEAMgBkAHkAYgAzAFYAdQBaAEQAcAB5AFoA
>> "%~1" echo MgBKAGgASwBEAEkAcwBOAGkAdwB5AE0AeQB3AHUATgBUAFkAcABPADMAbwB0AGEA
>> "%~1" echo VwA1AGsAWgBYAGcANgBOAEQAQQA3AFoARwBsAHoAYwBHAHgAaABlAFQAcAB1AGIA
>> "%~1" echo MgA1AGwATwAzAEIAcwBZAFcATgBsAEwAVwBsADAAWgBXADEAegBPAG0ATgBsAGIA
>> "%~1" echo bgBSAGwAYwBqAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEUANABjAEgAaAA5AEwA
>> "%~1" echo bQAxAHYAWgBHAEYAcwBUAFcARgB6AGEAeQA1AHoAYQBHADkAMwBlADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGsANgBaADMASgBwAFoASAAwAHUAYgBXADkAawBZAFcAeAA3AGQA
>> "%~1" echo MgBsAGsAZABHAGcANgBiAFcAbAB1AEsARABRADIATQBIAEIANABMAEQARQB3AE0A
>> "%~1" echo QwBVAHAATwAyAEoAaABZADIAdABuAGMAbQA5ADEAYgBtAFEANgBkAG0ARgB5AEsA
>> "%~1" echo QwAwAHQAWQAyAEYAeQBaAEMAawA3AFkAbQA5AHkAWgBHAFYAeQBPAGoARgB3AGUA
>> "%~1" echo QwBCAHoAYgAyAHgAcABaAEMAQgAyAFkAWABJAG8ATABTADEAcwBhAFcANQBsAEsA
>> "%~1" echo VAB0AGkAYgAzAEoAawBaAFgASQB0AGMAbQBGAGsAYQBYAFYAegBPAGoARQB3AGMA
>> "%~1" echo SABnADcAWQBtADkANABMAFgATgBvAFkAVwBSAHYAZAB6AG8AdwBJAEQASQAwAGMA
>> "%~1" echo SABnAGcATgB6AEIAdwBlAEMAQgB5AFoAMgBKAGgASwBEAEEAcwBNAEMAdwB3AEwA
>> "%~1" echo QwA0AHoATgBTAGsANwBjAEcARgBrAFoARwBsAHUAWgB6AG8AeABPAEgAQgA0AGYA
>> "%~1" echo UwA1AHQAYgAyAFIAaABiAEMAQgBvAE0AMwB0AHQAWQBYAEoAbgBhAFcANAA2AE0A
>> "%~1" echo QwBBAHcASQBEAGgAdwBlAEQAdABtAGIAMgA1ADAATABYAE4AcABlAG0AVQA2AE0A
>> "%~1" echo VABoAHcAZQBIADAAdQBiAFcAOQBrAFkAVwB3AGcAYwBIAHQAdABZAFgASgBuAGEA
>> "%~1" echo VwA0ADYATQBEAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQB0AGQA
>> "%~1" echo WABSAGwAWgBDAGsANwBiAEcAbAB1AFoAUwAxAG8AWgBXAGwAbgBhAEgAUQA2AE0A
>> "%~1" echo UwA0ADIATgBYADAAdQBiAFcAOQBrAFkAVwB4AEIAWQAzAFIAcABiADIANQB6AGUA
>> "%~1" echo MgBSAHAAYwAzAEIAcwBZAFgAawA2AFoAbQB4AGwAZQBEAHQAcQBkAFgATgAwAGEA
>> "%~1" echo VwBaADUATABXAE4AdgBiAG4AUgBsAGIAbgBRADYAWgBtAHgAbABlAEMAMQBsAGIA
>> "%~1" echo bQBRADcAWgAyAEYAdwBPAGoARQB3AGMASABnADcAYgBXAEYAeQBaADIAbAB1AEwA
>> "%~1" echo WABSAHYAYwBEAG8AeABPAEgAQgA0AGYAUwA1AHQAYgAyAFIAaABiAEUARgBqAGQA
>> "%~1" echo RwBsAHYAYgBuAE0AZwBZAG4AVgAwAGQARwA5AHUAZQAyAGgAbABhAFcAZABvAGQA
>> "%~1" echo RABvAHoATgBIAEIANABPADIASgB2AGMAbQBSAGwAYwBpADEAeQBZAFcAUgBwAGQA
>> "%~1" echo WABNADYATgAzAEIANABPADIASgB2AGMAbQBSAGwAYwBqAG8AeABjAEgAZwBnAGMA
>> "%~1" echo MgA5AHMAYQBXAFEAZwBkAG0ARgB5AEsAQwAwAHQAYgBHAGwAdQBaAFMAawA3AFkA
>> "%~1" echo bQBGAGoAYQAyAGQAeQBiADMAVgB1AFoARABwADIAWQBYAEkAbwBMAFMAMQB6AGIA
>> "%~1" echo MgBaADAASwBUAHQAagBiADIAeAB2AGMAagBwADIAWQBYAEkAbwBMAFMAMQAwAFoA
>> "%~1" echo WABoADAASwBUAHQAdwBZAFcAUgBrAGEAVwA1AG4ATwBqAEEAZwBNAFQATgB3AGUA
>> "%~1" echo RAB0AG0AYgAyADUAMABMAFgAZABsAGEAVwBkAG8AZABEAG8ANABNAEQAQQA3AFkA
>> "%~1" echo MwBWAHkAYwAyADkAeQBPAG4AQgB2AGEAVwA1ADAAWgBYAEoAOQBMAG0AMQB2AFoA
>> "%~1" echo RwBGAHMAUQBXAE4AMABhAFcAOQB1AGMAeQBBAHUAWgBHAEYAdQBaADIAVgB5AGUA
>> "%~1" echo MgBKAGgAWQAyAHQAbgBjAG0AOQAxAGIAbQBRADYAZABtAEYAeQBLAEMAMAB0AFkA
>> "%~1" echo VwAxAGkAWgBYAEkAcABPADIASgB2AGMAbQBSAGwAYwBpADEAagBiADIAeAB2AGMA
>> "%~1" echo agBwADIAWQBYAEkAbwBMAFMAMQBoAGIAVwBKAGwAYwBpAGsANwBZADIAOQBzAGIA
>> "%~1" echo MwBJADYASQB6AEUAeABNAFQAZwB5AE4AMwAwAHUAWQAyADEAawBMAG0AbAB6AEwA
>> "%~1" echo VwBKADEAYwAzAGsAcwBMAG0ASgAwAGIAaQA1AHAAYwB5ADEAaQBkAFgATgA1AGUA
>> "%~1" echo MgA5AHcAWQBXAE4AcABkAEgAawA2AEwAagBZADQATwAyAE4AMQBjAG4ATgB2AGMA
>> "%~1" echo agBwADMAWQBXAGwAMABmAFMANQBqAGIAVwBRADYAWgBHAGwAegBZAFcASgBzAFoA
>> "%~1" echo VwBRAHMATABtAEoAMABiAGoAcABrAGEAWABOAGgAWQBtAHgAbABaAEMAdwB1AGMA
>> "%~1" echo bQBWAHoAWgBYAFIAQwBkAEcANAA2AFoARwBsAHoAWQBXAEoAcwBaAFcAUgA3AGMA
>> "%~1" echo RwA5AHAAYgBuAFIAbABjAGkAMQBsAGQAbQBWAHUAZABIAE0ANgBiAG0AOQB1AFoA
>> "%~1" echo WAAwAEsAUQBHADEAbABaAEcAbABoAEsARwAxAGgAZQBDADEAMwBhAFcAUgAwAGEA
>> "%~1" echo RABvAHgATQBUAGcAdwBjAEgAZwBwAGUAeQA1AHkAYgAzAGMAcwBMAG4ASgB2AGQA
>> "%~1" echo egBOADcAWgAzAEoAcABaAEMAMQAwAFoAVwAxAHcAYgBHAEYAMABaAFMAMQBqAGIA
>> "%~1" echo MgB4ADEAYgBXADUAegBPAGoARgBtAGMAbgAwAHUAYQBXADUAbQBiADAAZAB5AGEA
>> "%~1" echo VwBSADcAWgAzAEoAcABaAEMAMQAwAFoAVwAxAHcAYgBHAEYAMABaAFMAMQBqAGIA
>> "%~1" echo MgB4ADEAYgBXADUAegBPAGoARgBtAGMAaQBBAHgAWgBuAEoAOQBmAFUAQgB0AFoA
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
>> "%~1" echo WABKAGwAWQAzAFIAcABiADIANAA2AFkAMgA5AHMAZABXADEAdQBPADMAQgBoAFoA
>> "%~1" echo RwBSAHAAYgBtAGMANgBNAFQAWgB3AGUASAAwAHUAZAAzAEoAaABjAEgAdAB3AFkA
>> "%~1" echo VwBSAGsAYQBXADUAbgBPAGoARQAwAGMASABoADkATABtADEAbABkAEgASgBwAFkA
>> "%~1" echo MABkAHkAYQBXAFEAcwBMAG0AMQBwAGIAbQBsAEgAYwBtAGwAawBMAEMANQBqAGIA
>> "%~1" echo VwBSAEgAYwBtAGwAawBMAEMANQBtAGIAMwBKAHQATABDADUAdwBZAFgASgBoAGIA
>> "%~1" echo VQBsADAAWgBXADAAcwBMAG0AbAB1AFoAbQA5AEgAYwBtAGwAawBMAEMANQBsAGUA
>> "%~1" echo SABCAHYAYwBuAFIAQwBiADMAaAA3AFoAMwBKAHAAWgBDADEAMABaAFcAMQB3AGIA
>> "%~1" echo RwBGADAAWgBTADEAagBiADIAeAAxAGIAVwA1AHoATwBqAEYAbQBjAG4AMAB1AGQA
>> "%~1" echo RwA5AGgAYwAzAFIAegBlADMASgBwAFoAMgBoADAATwBqAEUAMABjAEgAZwA3AFkA
>> "%~1" echo bQA5ADAAZABHADkAdABPAGoARQAwAGMASABoADkAZgBRAG8AOABMADMATgAwAGUA
>> "%~1" echo VwB4AGwAUABnAG8AOABMADIAaABsAFkAVwBRACsAQwBqAHgAaQBiADIAUgA1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBrAFkAWABKAHIASQBqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgAwAGIAMgBGAHoAZABIAE0AaQBJAEcAbABrAFAA
>> "%~1" echo UwBKADAAYgAyAEYAegBkAEgATQBpAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAHYAWgBHAEYAcwBUAFcARgB6AGEA
>> "%~1" echo eQBJAGcAYQBXAFEAOQBJAG0ATgB2AGIAbQBaAHAAYwBtADEATgBZAFgATgByAEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABiADIAUgBoAGIA
>> "%~1" echo QwBJACsAUABHAGcAegBJAEcAbABrAFAAUwBKAGoAYgAyADUAbQBhAFgASgB0AFYA
>> "%~1" echo RwBsADAAYgBHAFUAaQBQAHUAZQBoAHIAdQBpAHUAcABPAGEASgBwACsAaQBoAGoA
>> "%~1" echo RAB3AHYAYQBEAE0AKwBQAEgAQQBnAGEAVwBRADkASQBtAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAxAE4AYwAyAGMAaQBQAHUAaQAvAG0AZQBTADQAcQB1AGEAVABqAGUAUwA5AG4A
>> "%~1" echo TwBTADgAbQB1AFMALwByAHUAYQBVAHUAUwBCAFIAZABXAFYAegBkAEMARABuAGkA
>> "%~1" echo cgBiAG0AZwBJAEgAagBnAEkASQA4AEwAMwBBACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAFcAOQBrAFkAVwB4AEIAWQAzAFIAcABiADIANQB6AEkA
>> "%~1" echo agA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBsAGsAUABTAEoAagBiADIANQBtAGEA
>> "%~1" echo WABKAHQAUQAyAEYAdQBZADIAVgBzAEkAagA3AGwAagA1AGIAbQB0AG8AZwA4AEwA
>> "%~1" echo MgBKADEAZABIAFIAdgBiAGoANAA4AFkAbgBWADAAZABHADkAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAawBZAFcANQBuAFoAWABJAGkASQBHAGwAawBQAFMASgBqAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABUADIAcwBpAFAAdQBlAGgAcgB1AGkAdQBwAE8AYQBKAHAA
>> "%~1" echo KwBpAGgAagBEAHcAdgBZAG4AVgAwAGQARwA5AHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABnAG8AOABjADMAWgBuAEkA
>> "%~1" echo SABkAHAAWgBIAFIAbwBQAFMASQB3AEkAaQBCAG8AWgBXAGwAbgBhAEgAUQA5AEkA
>> "%~1" echo agBBAGkASQBIAE4AMABlAFcAeABsAFAAUwBKAHcAYgAzAE4AcABkAEcAbAB2AGIA
>> "%~1" echo agBwAGgAWQBuAE4AdgBiAEgAVgAwAFoAUwBJACsAUABIAE4ANQBiAFcASgB2AGIA
>> "%~1" echo QwBCAHAAWgBEADAAaQBhAFMAMQAyAGMAaQBJAGcAZABtAGwAbABkADAASgB2AGUA
>> "%~1" echo RAAwAGkATQBDAEEAdwBJAEQASQAwAEkARABJADAASQBqADQAOABjAEcARgAwAGEA
>> "%~1" echo QwBCAGsAUABTAEoATgBNAEMAQQB3AGEARABJADAAZABqAEkAMABTAEQAQgA2AEkA
>> "%~1" echo aQBCAG0AYQBXAHgAcwBQAFMASgB1AGIAMgA1AGwASQBpADgAKwBQAEgAQgBoAGQA
>> "%~1" echo RwBnAGcAWgBEADAAaQBUAFQAWQBnAE8AVwBnAHgATQBtAEUAegBJAEQATQBnAE0A
>> "%~1" echo QwBBAHcASQBEAEUAZwBNAHkAQQB6AGQAagBOAGgATQB5AEEAegBJAEQAQQBnAE0A
>> "%~1" echo QwBBAHgATABUAE0AZwBNADIAZwB0AE0AUwA0ADEAYgBDADAAeQBMAGoAVQB0AE0A
>> "%~1" echo MgBnAHQATgBHAHcAdABNAGkANAAxAEkARABOAEkATgBtAEUAegBJAEQATQBnAE0A
>> "%~1" echo QwBBAHcASQBEAEUAdABNAHkAMAB6AGQAaQAwAHoAWQBUAE0AZwBNAHkAQQB3AEkA
>> "%~1" echo RABBAGcATQBTAEEAegBMAFQATgA2AEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoA
>> "%~1" echo RAAwAGkAVABUAGsAZwBNAFQASgBvAEwAagBBAHgASQBpADgAKwBQAEgAQgBoAGQA
>> "%~1" echo RwBnAGcAWgBEADAAaQBUAFQARQAxAEkARABFAHkAYQBDADQAdwBNAFMASQB2AFAA
>> "%~1" echo agB4AHcAWQBYAFIAbwBJAEcAUQA5AEkAawAwAHgATQBDAEEAeABOAFcAZwAwAEkA
>> "%~1" echo aQA4ACsAUABDADkAegBlAFcAMQBpAGIAMgB3ACsAUABIAE4ANQBiAFcASgB2AGIA
>> "%~1" echo QwBCAHAAWgBEADAAaQBhAFMAMQBvAGIAMgAxAGwASQBpAEIAMgBhAFcAVgAzAFEA
>> "%~1" echo bQA5ADQAUABTAEkAdwBJAEQAQQBnAE0AagBRAGcATQBqAFEAaQBQAGoAeAB3AFkA
>> "%~1" echo WABSAG8ASQBHAFEAOQBJAGsAMAB3AEkARABCAG8ATQBqAFIAMgBNAGoAUgBJAE0A
>> "%~1" echo SABvAGkASQBHAFoAcABiAEcAdwA5AEkAbQA1AHYAYgBtAFUAaQBMAHoANAA4AGMA
>> "%~1" echo RwBGADAAYQBDAEIAawBQAFMASgBOAE4AUwBBAHgATQBtAHcAMwBMAFQAZABzAE4A
>> "%~1" echo eQBBADMASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQAWQBnAE0A
>> "%~1" echo VABCADIATwBXAGcAeABNAG4AWQB0AE8AUwBJAHYAUABqAHcAdgBjADMAbAB0AFkA
>> "%~1" echo bQA5AHMAUABqAHgAegBlAFcAMQBpAGIAMgB3AGcAYQBXAFEAOQBJAG0AawB0AFkA
>> "%~1" echo MgA5AHUAYwAyADkAcwBaAFMASQBnAGQAbQBsAGwAZAAwAEoAdgBlAEQAMABpAE0A
>> "%~1" echo QwBBAHcASQBEAEkAMABJAEQASQAwAEkAagA0ADgAYwBHAEYAMABhAEMAQgBrAFAA
>> "%~1" echo UwBKAE4ATQBDAEEAdwBhAEQASQAwAGQAagBJADAAUwBEAEIANgBJAGkAQgBtAGEA
>> "%~1" echo VwB4AHMAUABTAEoAdQBiADIANQBsAEkAaQA4ACsAUABIAEIAaABkAEcAZwBnAFoA
>> "%~1" echo RAAwAGkAVABUAGcAZwBPAFcAdwB6AEkARABOAHMATABUAE0AZwBNAHkASQB2AFAA
>> "%~1" echo agB4AHcAWQBYAFIAbwBJAEcAUQA5AEkAawAwAHgATQB5AEEAeABOAFcAZwB6AEkA
>> "%~1" echo aQA4ACsAUABIAEIAaABkAEcAZwBnAFoARAAwAGkAVABUAE0AZwBOAEcAZwB4AE8A
>> "%~1" echo SABZAHgATgBrAGcAegBlAGkASQB2AFAAagB3AHYAYwAzAGwAdABZAG0AOQBzAFAA
>> "%~1" echo agB4AHoAZQBXADEAaQBiADIAdwBnAGEAVwBRADkASQBtAGsAdABhAFcANQBtAGIA
>> "%~1" echo eQBJAGcAZABtAGwAbABkADAASgB2AGUARAAwAGkATQBDAEEAdwBJAEQASQAwAEkA
>> "%~1" echo RABJADAASQBqADQAOABjAEcARgAwAGEAQwBCAGsAUABTAEoATgBNAEMAQQB3AGEA
>> "%~1" echo RABJADAAZABqAEkAMABTAEQAQgA2AEkAaQBCAG0AYQBXAHgAcwBQAFMASgB1AGIA
>> "%~1" echo MgA1AGwASQBpADgAKwBQAEgAQgBoAGQARwBnAGcAWgBEADAAaQBUAFQARQB5AEkA
>> "%~1" echo RABsAG8ATABqAEEAeABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQA
>> "%~1" echo VABFAHgASQBEAEUAeQBhAEQARgAyAE4ARwBnAHgASQBpADgAKwBQAEgAQgBoAGQA
>> "%~1" echo RwBnAGcAWgBEADAAaQBUAFQARQB5AEkARABOAGgATwBTAEEANQBJAEQAQQBnAE0A
>> "%~1" echo UwBBAHcASQBEAEEAZwBNAFQAaABoAE8AUwBBADUASQBEAEEAZwBNAEMAQQB3AEkA
>> "%~1" echo RABBAHQATQBUAGgANgBJAGkAOAArAFAAQwA5AHoAZQBXADEAaQBiADIAdwArAFAA
>> "%~1" echo SABOADUAYgBXAEoAdgBiAEMAQgBwAFoARAAwAGkAYQBTADEAegBaAFgAUgAwAGEA
>> "%~1" echo VwA1AG4AYwB5AEkAZwBkAG0AbABsAGQAMABKAHYAZQBEADAAaQBNAEMAQQB3AEkA
>> "%~1" echo RABJADAASQBEAEkAMABJAGoANAA4AGMARwBGADAAYQBDAEIAawBQAFMASgBOAE0A
>> "%~1" echo QwBBAHcAYQBEAEkAMABkAGoASQAwAFMARABCADYASQBpAEIAbQBhAFcAeABzAFAA
>> "%~1" echo UwBKAHUAYgAyADUAbABJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQA
>> "%~1" echo VABFAHcATABqAE0AeQBOAFMAQQAwAEwAagBNAHgATgAyAEUAeQBJAEQASQBnAE0A
>> "%~1" echo QwBBAHcASQBEAEUAZwBNAHkANAB6AE4AUwBBAHcAYgBDADQAeQBMAGoATQAwAE4A
>> "%~1" echo RwBFAHkASQBEAEkAZwBNAEMAQQB3AEkARABBAGcATQBpADQAdwBNAEQAawB1AE8A
>> "%~1" echo VABaAHMATABqAE0ANQBNAGkAMAB1AE0ARABjADAAWQBUAEkAZwBNAGkAQQB3AEkA
>> "%~1" echo RABBAGcATQBTAEEAeQBMAGoATQAyAEkARABJAHUATQB6AFoAcwBMAFMANAB3AE4A
>> "%~1" echo egBRAHUATQB6AGsAeQBZAFQASQBnAE0AaQBBAHcASQBEAEEAZwBNAEMAQQB1AE8A
>> "%~1" echo VABZAGcATQBpADQAdwBNAEQAbABzAEwAagBNADAATgBDADQAeQBZAFQASQBnAE0A
>> "%~1" echo aQBBAHcASQBEAEEAZwBNAFMAQQB3AEkARABNAHUATQB6AFYAcwBMAFMANAB6AE4A
>> "%~1" echo RABRAHUATQBtAEUAeQBJAEQASQBnAE0AQwBBAHcASQBEAEEAdABMAGoAawAyAEkA
>> "%~1" echo RABJAHUATQBEAEEANQBiAEMANAB3AE4AegBRAHUATQB6AGsAeQBZAFQASQBnAE0A
>> "%~1" echo aQBBAHcASQBEAEEAZwBNAFMAMAB5AEwAagBNADIASQBEAEkAdQBNAHoAWgBzAEwA
>> "%~1" echo UwA0AHoATwBUAEkAdABMAGoAQQAzAE4ARwBFAHkASQBEAEkAZwBNAEMAQQB3AEkA
>> "%~1" echo RABBAHQATQBpADQAdwBNAEQAawB1AE8AVABaAHMATABTADQAeQBMAGoATQAwAE4A
>> "%~1" echo RwBFAHkASQBEAEkAZwBNAEMAQQB3AEkARABFAHQATQB5ADQAegBOAFMAQQB3AGIA
>> "%~1" echo QwAwAHUATQBpADAAdQBNAHoAUQAwAFkAVABJAGcATQBpAEEAdwBJAEQAQQBnAE0A
>> "%~1" echo QwAwAHkATABqAEEAdwBPAFMAMAB1AE8AVABaAHMATABTADQAegBPAFQASQB1AE0A
>> "%~1" echo RABjADAAWQBUAEkAZwBNAGkAQQB3AEkARABBAGcATQBTADAAeQBMAGoATQAyAEwA
>> "%~1" echo VABJAHUATQB6AFoAcwBMAGoAQQAzAE4AQwAwAHUATQB6AGsAeQBZAFQASQBnAE0A
>> "%~1" echo aQBBAHcASQBEAEEAZwBNAEMAMAB1AE8AVABZAHQATQBpADQAdwBNAEQAbABzAEwA
>> "%~1" echo UwA0AHoATgBEAFEAdABMAGoASgBoAE0AaQBBAHkASQBEAEEAZwBNAEMAQQB4AEkA
>> "%~1" echo RABBAHQATQB5ADQAegBOAFcAdwB1AE0AegBRADAATABTADQAeQBZAFQASQBnAE0A
>> "%~1" echo aQBBAHcASQBEAEEAZwBNAEMAQQB1AE8AVABZAHQATQBpADQAdwBNAEQAbABzAEwA
>> "%~1" echo UwA0AHcATgB6AFEAdABMAGoATQA1AE0AbQBFAHkASQBEAEkAZwBNAEMAQQB3AEkA
>> "%~1" echo RABFAGcATQBpADQAegBOAGkAMAB5AEwAagBNADIAYgBDADQAegBPAFQASQB1AE0A
>> "%~1" echo RABjADAAWQBUAEkAZwBNAGkAQQB3AEkARABBAGcATQBDAEEAeQBMAGoAQQB3AE8A
>> "%~1" echo UwAwAHUATwBUAFoANgBJAGkAOAArAFAASABCAGgAZABHAGcAZwBaAEQAMABpAFQA
>> "%~1" echo VABrAGcATQBUAEoAaABNAHkAQQB6AEkARABBAGcATQBTAEEAdwBJAEQAWQBnAE0A
>> "%~1" echo RwBFAHoASQBEAE0AZwBNAEMAQQB3AEkARABBAHQATgBpAEEAdwBJAGkAOAArAFAA
>> "%~1" echo QwA5AHoAZQBXADEAaQBiADIAdwArAFAASABOADUAYgBXAEoAdgBiAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAYQBTADEAcwBiADIAYwBpAEkASABaAHAAWgBYAGQAQwBiADMAZwA5AEkA
>> "%~1" echo agBBAGcATQBDAEEAeQBOAEMAQQB5AE4AQwBJACsAUABIAEIAaABkAEcAZwBnAFoA
>> "%~1" echo RAAwAGkAVABUAEEAZwBNAEcAZwB5AE4ASABZAHkATgBFAGcAdwBlAGkASQBnAFoA
>> "%~1" echo bQBsAHMAYgBEADAAaQBiAG0AOQB1AFoAUwBJAHYAUABqAHgAdwBZAFgAUgBvAEkA
>> "%~1" echo RwBRADkASQBrADAAMQBJAEQAVgBvAE0AVABSADIATQBUAFIASQBOAFgAbwBpAEwA
>> "%~1" echo egA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATwBTAEEANQBhAEQAWQBpAEwA
>> "%~1" echo egA0ADgAYwBHAEYAMABhAEMAQgBrAFAAUwBKAE4ATwBTAEEAeABNADIAZwAyAEkA
>> "%~1" echo aQA4ACsAUABDADkAegBlAFcAMQBpAGIAMgB3ACsAUABDADkAegBkAG0AYwArAEMA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEYAdwBjAEMASQArAFAA
>> "%~1" echo RwBGAHoAYQBXAFIAbABJAEcATgBzAFkAWABOAHoAUABTAEoAegBhAFcAUgBsAEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBjAG0ARgB1AFoA
>> "%~1" echo QwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG4ASgBoAGIA
>> "%~1" echo bQBSAEoAWQAyADkAdQBJAGoANAA4AGMAMwBaAG4ASQBIAGQAcABaAEgAUgBvAFAA
>> "%~1" echo UwBJAHkATQBpAEkAZwBhAEcAVgBwAFoAMgBoADAAUABTAEkAeQBNAGkASQArAFAA
>> "%~1" echo SABWAHoAWgBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYQBTADEAMgBjAGkASQB2AFAA
>> "%~1" echo agB3AHYAYwAzAFoAbgBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQArAFAA
>> "%~1" echo RwBJACsAVQBYAFYAbABjADMAUQBnAFEAVQBSAEMAUABDADkAaQBQAGoAeAB6AGMA
>> "%~1" echo RwBGAHUAUABsAE4AcABiAG0AZABzAFoAUwBCAEMAUQBWAFEAZwBWADIAVgBpAFYA
>> "%~1" echo VQBrADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHADUAaABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAG0ARgAyAEkA
>> "%~1" echo agA0ADgAWQBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYgAzAFoAbABjAG4AWgBwAFoA
>> "%~1" echo WABjAGkASQBHAE4AcwBZAFgATgB6AFAAUwBKAGgAWQAzAFIAcABkAG0AVQBpAFAA
>> "%~1" echo agB4AHoAZABtAGMAKwBQAEgAVgB6AFoAUwBCAG8AYwBtAFYAbQBQAFMASQBqAGEA
>> "%~1" echo UwAxAG8AYgAyADEAbABJAGkAOAArAFAAQwA5AHoAZABtAGMAKwA1AG8AQwA3ADYA
>> "%~1" echo SwBlAEkAUABDADkAaABQAGoAeABoAEkARwBoAHkAWgBXAFkAOQBJAGkATgBqAGIA
>> "%~1" echo MgA1AHoAYgAyAHgAbABJAGoANAA4AGMAMwBaAG4AUABqAHgAMQBjADIAVQBnAGEA
>> "%~1" echo SABKAGwAWgBqADAAaQBJADIAawB0AFkAMgA5AHUAYwAyADkAcwBaAFMASQB2AFAA
>> "%~1" echo agB3AHYAYwAzAFoAbgBQAHUAVwAvAHEAKwBhAE4AdAArAGEATwBwACsAVwBJAHQA
>> "%~1" echo dQBXAFAAcwBEAHcAdgBZAFQANAA4AFkAUwBCAG8AYwBtAFYAbQBQAFMASQBqAFoA
>> "%~1" echo RwBWADIAYQBXAE4AbABJAGoANAA4AGMAMwBaAG4AUABqAHgAMQBjADIAVQBnAGEA
>> "%~1" echo SABKAGwAWgBqADAAaQBJADIAawB0AGEAVwA1AG0AYgB5AEkAdgBQAGoAdwB2AGMA
>> "%~1" echo MwBaAG4AUAB1AGkAdQB2AHUAVwBrAGgAKwBTAC8AbwBlAGEAQgByAHoAdwB2AFkA
>> "%~1" echo VAA0ADgAWQBTAEIAbwBjAG0AVgBtAFAAUwBJAGoAYwAyAFYAMABkAEcAbAB1AFoA
>> "%~1" echo MwBNAGkAUABqAHgAegBkAG0AYwArAFAASABWAHoAWgBTAEIAbwBjAG0AVgBtAFAA
>> "%~1" echo UwBJAGoAYQBTADEAegBaAFgAUgAwAGEAVwA1AG4AYwB5AEkAdgBQAGoAdwB2AGMA
>> "%~1" echo MwBaAG4AUAB1AG0AcgBtAE8AZQA2AHAAeQBCAHoAWgBYAFIAMABhAFcANQBuAGMA
>> "%~1" echo egB3AHYAWQBUADQAOABZAFMAQgBvAGMAbQBWAG0AUABTAEkAagBiAEcAOQBuAGMA
>> "%~1" echo eQBJACsAUABIAE4AMgBaAHoANAA4AGQAWABOAGwASQBHAGgAeQBaAFcAWQA5AEkA
>> "%~1" echo aQBOAHAATABXAHgAdgBaAHkASQB2AFAAagB3AHYAYwAzAFoAbgBQAHUAYQBYAHAA
>> "%~1" echo ZQBXAC8AbAB6AHcAdgBZAFQANAA4AEwAMgA1AGgAZABqADQAOABMADIARgB6AGEA
>> "%~1" echo VwBSAGwAUABqAHgAdABZAFcAbAB1AEkARwBOAHMAWQBYAE4AegBQAFMASgB0AFkA
>> "%~1" echo VwBsAHUASQBqADQAOABhAEcAVgBoAFoARwBWAHkASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKADAAYgAzAEEAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bgBSAHAAZABHAHgAbABJAGoANAA4AGEARABFAGcAYQBXAFEAOQBJAG4AQgBoAFoA
>> "%~1" echo MgBWAFUAYQBYAFIAcwBaAFMASQArADUAbwBDADcANgBLAGUASQBQAEMAOQBvAE0A
>> "%~1" echo VAA0ADgAYwBDAEIAcABaAEQAMABpAGMARwBGAG4AWgBWAE4AMQBZAGkASQArADUA
>> "%~1" echo NABxADIANQBvAEMAQgA1AG8AeQBIADUAcQBDAEgANQBaAEsATQA2AEsANgArADUA
>> "%~1" echo YQBTAEgANQBxAGEAQwA2AEsAZQBJAFAAQwA5AHcAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBuAFIAdgBiADIAeABpAFkA
>> "%~1" echo WABJAGkAUABqAHgAegBjAEcARgB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGEA
>> "%~1" echo RwBsAHcASQBpAEIAcABaAEQAMABpAGMAMwBSAGgAZABIAFYAegBRADIAaABwAGMA
>> "%~1" echo QwBJACsAUABHAGsAZwBZADIAeABoAGMAMwBNADkASQBtAE4AbwBhAFgAQgBFAGIA
>> "%~1" echo MwBRAGkAUABqAHcAdgBhAFQANAA4AGMAMwBCAGgAYgBqADcAbQBuAEsAcgBvAHYA
>> "%~1" echo NQA3AG0AagBxAFUAOABMADMATgB3AFkAVwA0ACsAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAagBhAEcAbAB3AEkA
>> "%~1" echo agA1AEIAUgBFAEkAZwBQAEcASQBnAGEAVwBRADkASQBtAEYAawBZAGwATgBvAGIA
>> "%~1" echo MwBKADAASQBqADUAaABaAEcASQB1AFoAWABoAGwAUABDADkAaQBQAGoAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABjADMAQgBoAGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgBoAHAAYwBDAEkAKwBWADIAawB0AFIAbQBrAGcAUABHAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bgBkAHAAWgBtAGwARABhAEcAbAB3AEkAagA0AHQAUABDADkAaQBQAGoAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGkAZABHADQAZwBaADIAaAB2AGMAMwBRAGkASQBHAGwAawBQAFMASgAwAGEA
>> "%~1" echo RwBWAHQAWgBVAEoAMABiAGkASQArADUAcgBXAEYANgBJAG0AeQBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQBuAFIAdQBJAEgAQgB5AGEAVwAxAGgAYwBuAGsAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAHkAWgBXAFoAeQBaAFgATgBvAFEAbgBSAHUASQBqADcAbABpAEwAZgBtAGwA
>> "%~1" echo cgBBADgATAAyAEoAMQBkAEgAUgB2AGIAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBoAGwAWQBXAFIAbABjAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKADMAYwBtAEYAdwBJAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHUAYgAzAFIAcABZADIAVQBpAFAAdQBTAC8AbgBlAGEAMAB1ACsATwBBAGcA
>> "%~1" echo VABJADAASQBPAFcAdwBqACsAYQBYAHQAdQBTADYAcgB1AFcAeABqACsAVwBTAGoA
>> "%~1" echo TwBhAFgAbwBPAGUANgB2AHkAQgBCAFIARQBJAGcANQBZACsAcQA1AGIAdQA2ADYA
>> "%~1" echo SwA2AHUANQA1ACsAdAA1AHAAZQAyADYAWgBlADAANQByAFcATAA2AEsAKwBWADcA
>> "%~1" echo NwB5AGIANQA3AHUAVAA1AHAAMgBmADUAWgBDAE8ANQBvAG0AbgA2AEsARwBNADQA
>> "%~1" echo bwBDAGMANQBhADYASgA1AFkAVwBvADUANABhAEUANQBiAEcAUAA0AG8AQwBkADUA
>> "%~1" echo bwBpAFcANABvAEMAYwA1AEwAKwBkADUAYQA2AEkANgBiAHUAWQA2AEsANgBrADUA
>> "%~1" echo WQBDADgANABvAEMAZAA0ADQAQwBDAFAAQwA5AGsAYQBYAFkAKwBDAGoAeAB6AFoA
>> "%~1" echo VwBOADAAYQBXADkAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAdwBZAFcAZABsAEkA
>> "%~1" echo RwBGAGoAZABHAGwAMgBaAFMASQBnAGEAVwBRADkASQBtADkAMgBaAFgASgAyAGEA
>> "%~1" echo VwBWADMASQBqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB5AGIA
>> "%~1" echo MwBjAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBvAHIAcgA3AGwAcABJAGMAOABMADIAZwB5AFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBJAEcATgBzAFkAWABOAHoAUABTAEoAMABZAFcAYwBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAawBaAFgAWgBwAFkAMgBWAFUAWQBXAGMAaQBQAGwARgAxAFoA
>> "%~1" echo WABOADAAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAaQBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBoAGwAWQBXAFIAegBaAFgAUgBDAGIA
>> "%~1" echo MwBnAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AUgBsAGQA
>> "%~1" echo bQBsAGoAWgBVAGwAagBiADIANABpAFAAagB4AHoAZABtAGMAKwBQAEgAVgB6AFoA
>> "%~1" echo UwBCAG8AYwBtAFYAbQBQAFMASQBqAGEAUwAxADIAYwBpAEkAdgBQAGoAdwB2AGMA
>> "%~1" echo MwBaAG4AUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAKwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAFoARwBWADIAYQBXAE4AbABUAG0ARgB0AFoA
>> "%~1" echo UwBJAGcAYQBXAFEAOQBJAG0AaABsAGMAbQA5AE4AYgAyAFIAbABiAEMASQArAFUA
>> "%~1" echo WABWAGwAYwAzAFEAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAbwBhAFcANQAwAEkAaQBCAHAAWgBEADAAaQBjADMAUgBoAGQA
>> "%~1" echo RwBWAEkAYQBXADUAMABJAGoANwBuAHIAWQBuAGwAdgBvAFgAbwByADcAdgBsAGoA
>> "%~1" echo NQBiAG8AcgByADcAbABwAEkAZgBuAGkAcgBiAG0AZwBJAEgAagBnAEkASQA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB6AGQA
>> "%~1" echo RwBGADAAWgBTAEkAZwBhAFcAUQA5AEkAbgBOADAAWQBYAFIAbABRAG0AbABuAEkA
>> "%~1" echo agA1AHUAYgAyADUAbABQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGMA
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
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkAKwA1ADQAcQAyADUA
>> "%~1" echo bwBDAEIANQBvAHkASAA1AHEAQwBIAFAAQwA5AG8ATQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAG4ASQBpAEIAcABaAEQAMABpAFkA
>> "%~1" echo MgB4AHYAWQAyAHQAVQBaAFgAaAAwAEkAagA0AHQAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBKAHYAWgBIAGsAaQBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQAxAGwAZABIAEoAcABZADAAZAB5AGEAVwBRAGkAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQASABKAHAAWQB5AEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBKAGgAZABIAFIAbABjAG4AbABIAFkAWABWAG4AWgBTAEkAKwBQAEgATgAyAFoA
>> "%~1" echo eQBCAGoAYgBHAEYAegBjAHoAMABpAGMAbQBsAHUAWgB5AEkAZwBkAG0AbABsAGQA
>> "%~1" echo MABKAHYAZQBEADAAaQBNAEMAQQB3AEkARABFAHcATQBDAEEAeABNAEQAQQBpAFAA
>> "%~1" echo agB4AGoAYQBYAEoAagBiAEcAVQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgB5AFkA
>> "%~1" echo VwBOAHIASQBpAEIAagBlAEQAMABpAE4AVABBAGkASQBHAE4ANQBQAFMASQAxAE0A
>> "%~1" echo QwBJAGcAYwBqADAAaQBOAEQAQQBpAEkASABCAGgAZABHAGgATQBaAFcANQBuAGQA
>> "%~1" echo RwBnADkASQBqAEUAdwBNAEMASQB2AFAAagB4AGoAYQBYAEoAagBiAEcAVQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQARwBWAHkASQBpAEIAagBlAEQAMABpAE4A
>> "%~1" echo VABBAGkASQBHAE4ANQBQAFMASQAxAE0AQwBJAGcAYwBqADAAaQBOAEQAQQBpAEkA
>> "%~1" echo SABCAGgAZABHAGgATQBaAFcANQBuAGQARwBnADkASQBqAEUAdwBNAEMASQBnAGMA
>> "%~1" echo MwBSAHkAYgAyAHQAbABMAFcAUgBoAGMAMgBoAGgAYwBuAEoAaABlAFQAMABpAE0A
>> "%~1" echo QwBBAHgATQBEAEEAaQBMAHoANAA4AEwAMwBOADIAWgB6ADQAOABaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtADEAbABkAEgASgBwAFkA
>> "%~1" echo MQBaAGgAYgBIAFYAbABJAGkAQgBwAFoARAAwAGkAWQBtAEYAMABkAEcAVgB5AGUA
>> "%~1" echo VgBSAGwAZQBIAFEAaQBQAGkAMAB0AEoAVAB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABIAEoAcABZADAAeABoAFkA
>> "%~1" echo bQBWAHMASQBpAEIAcABaAEQAMABpAFkAbQBGADAAZABHAFYAeQBlAFYATgAxAFkA
>> "%~1" echo aQBJACsANQA1AFMAMQA2AFkAZQBQAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYgBXAFYAMABjAG0AbABqAEkAaQBCAHAAWgBEADAAaQBkAEcAVgB0AGMA
>> "%~1" echo RQBkAGgAZABXAGQAbABJAGoANAA4AGMAMwBaAG4ASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHkAYQBXADUAbgBJAGkAQgAyAGEAVwBWADMAUQBtADkANABQAFMASQB3AEkA
>> "%~1" echo RABBAGcATQBUAEEAdwBJAEQARQB3AE0AQwBJACsAUABHAE4AcABjAG0ATgBzAFoA
>> "%~1" echo UwBCAGoAYgBHAEYAegBjAHoAMABpAGQASABKAGgAWQAyAHMAaQBJAEcATgA0AFAA
>> "%~1" echo UwBJADEATQBDAEkAZwBZADMAawA5AEkAagBVAHcASQBpAEIAeQBQAFMASQAwAE0A
>> "%~1" echo QwBJAGcAYwBHAEYAMABhAEUAeABsAGIAbQBkADAAYQBEADAAaQBNAFQAQQB3AEkA
>> "%~1" echo aQA4ACsAUABHAE4AcABjAG0ATgBzAFoAUwBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo VwBWADAAWgBYAEkAaQBJAEcATgA0AFAAUwBJADEATQBDAEkAZwBZADMAawA5AEkA
>> "%~1" echo agBVAHcASQBpAEIAeQBQAFMASQAwAE0AQwBJAGcAYwBHAEYAMABhAEUAeABsAGIA
>> "%~1" echo bQBkADAAYQBEADAAaQBNAFQAQQB3AEkAaQBCAHoAZABIAEoAdgBhADIAVQB0AFoA
>> "%~1" echo RwBGAHoAYQBHAEYAeQBjAG0ARgA1AFAAUwBJAHcASQBEAEUAdwBNAEMASQB2AFAA
>> "%~1" echo agB3AHYAYwAzAFoAbgBQAGoAeABrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAFcAVgAwAGMAbQBsAGoAVgBtAEYAcwBkAFcAVQBpAEkA
>> "%~1" echo RwBsAGsAUABTAEoAMABaAFcAMQB3AFYARwBWADQAZABDAEkAKwBMAFMAMwBDAHMA
>> "%~1" echo RQBNADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHQAWgBYAFIAeQBhAFcATgBNAFkAVwBKAGwAYgBDAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bgBSAGwAYgBYAEIAVABkAFcASQBpAFAAdQBhADQAcQBlAFcANgBwAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQAxAGwAZABIAEoAcABZAHkASQBnAGEA
>> "%~1" echo VwBRADkASQBuAE4AcwBaAFcAVgB3AFIAMgBGADEAWgAyAFUAaQBQAGoAeAB6AGQA
>> "%~1" echo bQBjAGcAWQAyAHgAaABjADMATQA5AEkAbgBKAHAAYgBtAGMAaQBJAEgAWgBwAFoA
>> "%~1" echo WABkAEMAYgAzAGcAOQBJAGoAQQBnAE0AQwBBAHgATQBEAEEAZwBNAFQAQQB3AEkA
>> "%~1" echo agA0ADgAWQAyAGwAeQBZADIAeABsAEkARwBOAHMAWQBYAE4AegBQAFMASgAwAGMA
>> "%~1" echo bQBGAGoAYQB5AEkAZwBZADMAZwA5AEkAagBVAHcASQBpAEIAagBlAFQAMABpAE4A
>> "%~1" echo VABBAGkASQBIAEkAOQBJAGoAUQB3AEkAaQBCAHcAWQBYAFIAbwBUAEcAVgB1AFoA
>> "%~1" echo MwBSAG8AUABTAEkAeABNAEQAQQBpAEwAegA0ADgAWQAyAGwAeQBZADIAeABsAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgB0AFoAWABSAGwAYwBpAEkAZwBZADMAZwA5AEkA
>> "%~1" echo agBVAHcASQBpAEIAagBlAFQAMABpAE4AVABBAGkASQBIAEkAOQBJAGoAUQB3AEkA
>> "%~1" echo aQBCAHcAWQBYAFIAbwBUAEcAVgB1AFoAMwBSAG8AUABTAEkAeABNAEQAQQBpAEkA
>> "%~1" echo SABOADAAYwBtADkAcgBaAFMAMQBrAFkAWABOAG8AWQBYAEoAeQBZAFgAawA5AEkA
>> "%~1" echo agBBAGcATQBUAEEAdwBJAGkAOAArAFAAQwA5AHoAZABtAGMAKwBQAEcAUgBwAGQA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdABaAFgAUgB5AGEA
>> "%~1" echo VwBOAFcAWQBXAHgAMQBaAFMASQBnAGEAVwBRADkASQBuAE4AcwBaAFcAVgB3AFYA
>> "%~1" echo RwBWADQAZABDAEkAKwBMAFQAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AMQBsAGQASABKAHAAWQAwAHgAaABZAG0AVgBzAEkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBjADIAeABsAFoAWABCAFQAZABXAEkAaQBQAHUAUwA4AGsA
>> "%~1" echo ZQBlAGMAbwBEAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADEAcABiAG0AbABIAGMAbQBsAGsASQBqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgB0AGEAVwA1AHAASQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA1AFQAYgAwAE0AOABMADMATgB3AFkAVwA0ACsAUABHAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bgBOAHYAWQAwAHgAcABkAEcAVQBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAbAB1AGEA
>> "%~1" echo UwBJACsAUABIAE4AdwBZAFcANAArADUAcABpACsANQA2AFMANgBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABqAHgAaQBJAEcAbABrAFAAUwBKAGsAYQBYAE4AdwBiAEcARgA1AFUA
>> "%~1" echo MwBWAHQAYgBXAEYAeQBlAFUAeABwAGQARwBVAGkAUABpADAAOABMADIASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGIA
>> "%~1" echo VwBsAHUAYQBTAEkAKwBQAEgATgB3AFkAVwA0ACsANQA0AE8AdAA1ADQAcQAyADUA
>> "%~1" echo bwBDAEIAUABDADkAegBjAEcARgB1AFAAagB4AGkASQBHAGwAawBQAFMASgAwAGEA
>> "%~1" echo RwBWAHkAYgBXAEYAcwBVADMAVgB0AGIAVwBGAHkAZQBVAHgAcABkAEcAVQBpAFAA
>> "%~1" echo aQAwADgATAAyAEkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBiAFcAbAB1AGEAUwBJACsAUABIAE4AdwBZAFcANAArADUA
>> "%~1" echo YgBlAGwANQBZADYAQwBMACsAYQBnAG8AZQBXAEgAaABqAHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgAWQBpAEIAcABaAEQAMABpAFoAbQBGAGoAZABHADkAeQBlAFYATgAxAGIA
>> "%~1" echo VwAxAGgAYwBuAGwATQBhAFgAUgBsAEkAagA0AHQAUABDADkAaQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADEAcABiAG0AbABIAGMAbQBsAGsASQBqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgB0AGEAVwA1AHAASQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA3AGsAdgBwAHYAbgBsAEwAVQA4AEwAMwBOAHcAWQBXADQAKwBQAEcASQBnAGEA
>> "%~1" echo VwBRADkASQBuAEIAdgBkADIAVgB5AFUAMgA5ADEAYwBtAE4AbABJAGoANAB0AFAA
>> "%~1" echo QwA5AGkAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtADEAcABiAG0AawBpAFAAagB4AHoAYwBHAEYAdQBQAGsARgBFAFEA
>> "%~1" echo aQBCAFgAYQBTADEARwBhAFQAdwB2AGMAMwBCAGgAYgBqADQAOABZAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAWQBXAFIAaQBWADIAbABtAGEAUwBJACsATABUAHcAdgBZAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABaAEcAbAAyAEkARwBOAHMAWQBYAE4AegBQAFMASgB0AGEA
>> "%~1" echo VwA1AHAASQBqADQAOABjADMAQgBoAGIAagA3AGwAZwBhAFgAbAB1AHIAYwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEcASQBnAGEAVwBRADkASQBtAEoAaABkAEgAUgBsAGMA
>> "%~1" echo bgBsAEkAWgBXAEYAcwBkAEcAZwBpAFAAaQAwADgATAAyAEkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBiAFcAbAB1AGEA
>> "%~1" echo UwBJACsAUABIAE4AdwBZAFcANAArADYATAArAFEANgBLAEcATQA1ADQAcQAyADUA
>> "%~1" echo bwBDAEIAUABDADkAegBjAEcARgB1AFAAagB4AGkASQBHAGwAawBQAFMASgAzAFkA
>> "%~1" echo VwB0AGwAWgBuAFYAcwBiAG0AVgB6AGMAeQBJACsATABUAHcAdgBZAGoANAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAagBZAFgASgBrAEkAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAbwBaAFcARgBrAEkAagA0ADgAYQBEAEkAKwA1AEwAaQBBADYA
>> "%~1" echo WgBTAHUANQBhACsAOAA1AFkAZQA2ADYASwA2ACsANQBhAFMASAA1AFkAVwBvADYA
>> "%~1" echo WQBPAG8ANQBMACsAaAA1AG8ARwB2AFAAQwA5AG8ATQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAG4ASQBqADcAbABqADYAcgBvAHIA
>> "%~1" echo NwBzAGcAUQBVAFIAQwBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgAawBpAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAFYANABjAEcAOQB5AGQA
>> "%~1" echo RQBKAHYAZQBDAEkAKwBQAEcAUgBwAGQAagA0ADgAWQBqADcAbgBsAEoALwBtAGkA
>> "%~1" echo SgBEAG4AcAA0AEgAbQBuAEkAbgBsAHIAbwB6AG0AbABiAFQAbgBpAFkAZwBnAEsA
>> "%~1" echo eQBEAGwAaQBJAGIAawB1AHEAdgBsAHIAbwBuAGwAaABhAGoAbgBpAFkAZwBnAFMA
>> "%~1" echo RgBSAE4AVABEAHcAdgBZAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAG8AYQBXADUAMABJAGkAQgBwAFoARAAwAGkAWgBYAGgAdwBiADMASgAwAFUA
>> "%~1" echo MwBSAGgAZABIAFYAegBJAGoANwBuAGcAcgBuAGwAaAA3AHYAbABrAEkANwBwAGgA
>> "%~1" echo NAAzAG0AbAByAEQAbgBqAHIARABwAGgANABmAG8AcgByADcAbABwAEkAZgBrAHYA
>> "%~1" echo NgBIAG0AZwBhAC8AagBnAEkATABuAHAANABIAG0AbgBJAG4AbgBpAFkAagBrAHYA
>> "%~1" echo NQAzAG4AbABaAG4AbAByAG8AegBtAGwAYgBUAG0AbABiAEQAbQBqAGEANwB2AHYA
>> "%~1" echo SQB6AGwAaQBJAGIAawB1AHEAdgBuAGkAWQBqAGsAdgBKAHIAbwBoAEwASABtAGwA
>> "%~1" echo WQAvAGwAdQBvAC8AbABpAEoAZgBsAGoANwBmAGoAZwBJAEYASgBVAE8ATwBBAGcA
>> "%~1" echo VQAxAEIAUQArAE8AQQBnAFcAWgBwAGIAbQBkAGwAYwBuAEIAeQBhAFcANQAwAEkA
>> "%~1" echo TwBlAHQAaQBlAE8AQQBnAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AVgA0AGMARwA5AHkAZABFAHgAcABiAG0AdAB6AEkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBaAFgAaAB3AGIAMwBKADAAVABHAGwAdQBhADMATQBpAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHgAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0AGcAWQAyAHgAaABjADMATQA5AEkAbQBKADAAYgBpAEIAdwBjAG0AbAB0AFkA
>> "%~1" echo WABKADUASQBpAEIAcABaAEQAMABpAFoAWABoAHcAYgAzAEoAMABRAG4AUgB1AEkA
>> "%~1" echo agA3AGwAcgA3AHoAbABoADcAbwBnAFMARgBSAE4AVABEAHcAdgBZAG4AVgAwAGQA
>> "%~1" echo RwA5AHUAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBsAGoANABMAG0AbABiAEQAawB2ADYANwBtAGwA
>> "%~1" echo TABuAGwAaQBKAGYAbwBvAGEAZwA4AEwAMgBnAHkAUABqAHgAegBjAEcARgB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkASQBHAGwAawBQAFMASgB3AFkA
>> "%~1" echo WABKAGgAYgBWAE4AMQBiAFcAMQBoAGMAbgBrAGkAUAB1AGUAdABpAGUAVwArAGgA
>> "%~1" echo ZQBXAEkAdAArAGEAVwBzAEQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAaQBiADIAUgA1AEkA
>> "%~1" echo agA0ADgAWgBHAGwAMgBJAEcATgBzAFkAWABOAHoAUABTAEoAdwBZAFgASgBoAGIA
>> "%~1" echo VQB4AHAAYwAzAFEAaQBJAEcAbABrAFAAUwBKAHcAWQBYAEoAaABiAFUAeABwAGMA
>> "%~1" echo MwBRAGkAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG4ASgB2AGQA
>> "%~1" echo eQBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIARgB5AFoA
>> "%~1" echo QwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoA
>> "%~1" echo QwBJACsAUABHAGcAeQBQAHUAVwBGAHMAKwBtAFUAcgB1AFcAUABnAHUAYQBWAHMA
>> "%~1" echo RAB3AHYAYQBEAEkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUAUwBJACsAUABIAFIAaABZAG0AeABsAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBKAHMAWgBTAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADUAegBkAEcARgA1AFgAMgA5AHUAWAAzAGQAbwBhAFcAeABsAFgA
>> "%~1" echo MwBCAHMAZABXAGQAbgBaAFcAUgBmAGEAVwA0ADgATAAzAFIAawBQAGoAeAAwAFoA
>> "%~1" echo QwBCAHAAWgBEADAAaQBjADMAUgBoAGUAVQA5AHUASQBqADQAdABQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgATAAzAFIAeQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwBkADIAbABtAGEA
>> "%~1" echo VgA5AHoAYgBHAFYAbABjAEYAOQB3AGIAMgB4AHAAWQAzAGsAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAGQAMgBsAG0AYQBWAE4AcwBaAFcAVgB3AEkA
>> "%~1" echo agA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQA
>> "%~1" echo RwBRACsAYwAyAE4AeQBaAFcAVgB1AFgAMgA5AG0AWgBsADkAMABhAFcAMQBsAGIA
>> "%~1" echo MwBWADAAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG4ATgBqAGMA
>> "%~1" echo bQBWAGwAYgBrADkAbQBaAGkASQArAEwAVAB3AHYAZABHAFEAKwBQAEMAOQAwAGMA
>> "%~1" echo agA0ADgAZABIAEkAKwBQAEgAUgBrAFAAbgBOAHMAWgBXAFYAdwBYADMAUgBwAGIA
>> "%~1" echo VwBWAHYAZABYAFEAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQAMABpAGMA
>> "%~1" echo MgB4AGwAWgBYAEIAVQBhAFcAMQBsAGIAMwBWADAASQBqADQAdABQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgATAAzAFIAeQBQAGoAdwB2AGQARwBGAGkAYgBHAFUAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AGkAMQBoAE8AYQA2AGsA
>> "%~1" echo TwBlAEsAdAB1AGEAQQBnAFQAdwB2AGEARABJACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQBtADkAawBlAFMASQArAFAA
>> "%~1" echo SABSAGgAWQBtAHgAbABJAEcATgBzAFkAWABOAHoAUABTAEoAMABZAFcASgBzAFoA
>> "%~1" echo UwBJACsAUABIAFIAeQBQAGoAeAAwAFoARAA3AGwAcgBaAGoAbABnAHEAZwA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAYwAzAFIAdgBjAG0ARgBuAFoA
>> "%~1" echo UwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAA
>> "%~1" echo SABSAGsAUAB1AFcARwBoAGUAVwB0AG0ARAB3AHYAZABHAFEAKwBQAEgAUgBrAEkA
>> "%~1" echo RwBsAGsAUABTAEoAdABaAFcAMQB2AGMAbgBrAGkAUABpADAAOABMADMAUgBrAFAA
>> "%~1" echo agB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADcAawB2AHAAdgBuAGwA
>> "%~1" echo TABYAG0AbgBhAFgAbQB1AHAAQQA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAYwBHADkAMwBaAFgASgBUAGIAMwBWAHkAWQAyAFUAeQBJAGoANAB0AFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB4ADAAYwBqADQAOABkAEcAUQArAFEA
>> "%~1" echo VQBSAEMASQBPAGkAMwByACsAVwArAGgARAB3AHYAZABHAFEAKwBQAEgAUgBrAEkA
>> "%~1" echo RwBsAGsAUABTAEoAaABaAEcASgBRAFkAWABSAG8AVQAyAGgAdgBjAG4AUQBpAFAA
>> "%~1" echo aQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABDADkAMABZAFcASgBzAFoA
>> "%~1" echo VAA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgATAAzAE4AbABZADMAUgBwAGIAMgA0ACsAQwBqAHgAegBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAWQAyADkAdQBjADIAOQBzAFoAUwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBjAG0AOQAzAE0AeQBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUAUwA4AGsA
>> "%~1" echo ZQBlAGMAbwBPAFMANABqAHUAUwAvAG4AZQBhAEsAcABEAHcAdgBhAEQASQArAFAA
>> "%~1" echo SABOAHcAWQBXADQAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABaAHkASQArADUA
>> "%~1" echo bwA2AG8ANgBJADIAUQBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAEoAdgBaAEgAawBnAFkA
>> "%~1" echo MgAxAGsAUgAzAEoAcABaAEMASQArAFAARwBKADEAZABIAFIAdgBiAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIAMQBrAEkARwBKAHMAZABXAFUAaQBJAEcAUgBoAGQA
>> "%~1" echo RwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAHIAWgBYAGwAZgBkADIARgByAFoA
>> "%~1" echo WABWAHcASQBqADQAOABZAGoANwBrAHUAcQA3AGwAcwBZADgAZwBMAHkARABsAGwA
>> "%~1" echo SwBUAHAAaABwAEkAOABMADIASQArAFAASABOAHcAWQBXADQAKwA1AEwAdQBGADUA
>> "%~1" echo WgB5AG8ASQBFAEYARQBRAGkARABsAG4ASwBqAG4AdQByAC8AbQBsADcAYgBtAG4A
>> "%~1" echo SQBuAG0AbABZAGcAOABMADMATgB3AFkAVwA0ACsAUABDADkAaQBkAFgAUgAwAGIA
>> "%~1" echo MgA0ACsAUABHAEoAMQBkAEgAUgB2AGIAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgAxAGsASQBHAGQAeQBaAFcAVgB1AEkAaQBCAGsAWQBYAFIAaABMAFcARgBqAGQA
>> "%~1" echo RwBsAHYAYgBqADAAaQBjADIARgBtAFoAVgA5AHoAYgBHAFYAbABjAEMASQArAFAA
>> "%~1" echo RwBJACsANQBhADYASgA1AFkAVwBvADUANABhAEUANQBiAEcAUABQAEMAOQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBQAHUAYQBCAG8AdQBXAGsAagBlAFMALwBuAGUAVwB1AGkA
>> "%~1" echo TwBXAEEAdgBPAFcANQB0AHUAVwBQAGsAZQBtAEEAZwBlAGUAZABvAGUAZQBjAG8A
>> "%~1" echo TwBtAFUAcgBqAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIA
>> "%~1" echo VwBRAGcAWgAzAEoAbABaAFcANABpAEkARwBSAGgAZABHAEUAdABZAFcATgAwAGEA
>> "%~1" echo VwA5AHUAUABTAEoAeQBaAFgATgAwAGIAMwBKAGwAWAAzAE4AcwBaAFcAVgB3AEkA
>> "%~1" echo agA0ADgAWQBqADcAbQBnAGEATABsAHAASQAzAGsAdgBKAEgAbgBuAEsARABvAHQA
>> "%~1" echo bwBYAG0AbAA3AFkAOABMADIASQArAFAASABOAHcAWQBXADQAKwBOAFMARABsAGkA
>> "%~1" echo SQBiAHAAawBwAC8AbgBoAG8AVABsAHMAWQAvAHYAdgBJAHoAbAB1AGIAYgBvAHAA
>> "%~1" echo NgBQAHAAbQBhAFEAZwBjAEgASgB2AGUARgA5AGoAYgBHADkAegBaAFQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIASgAxAGQASABSAHYAYgBqADQAOABZAG4AVgAwAGQA
>> "%~1" echo RwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAYgBXAFEAaQBJAEcAUgBoAGQA
>> "%~1" echo RwBFAHQAWQBXAE4AMABhAFcAOQB1AFAAUwBKAGoAYgAyADUAegBaAFgASgAyAFkA
>> "%~1" echo WABSAHAAZABtAFUAaQBQAGoAeABpAFAAdQBTAC8AbgBlAFcAdQBpAE8AbQA3AG0A
>> "%~1" echo TwBpAHUAcABPAFcAQQB2AEQAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoANwBtAGcA
>> "%~1" echo YQBMAGwAcABJADMAbABqADQATABtAGwAYgBEAGwAdQBiAGIAbABqADUASABwAGcA
>> "%~1" echo SQBFAGcAYwBIAEoAdgBlAEYAOQB2AGMARwBWAHUAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBvAHMASQBQAG8AcgA1AFgAbAB0ADYAWABrAHYA
>> "%~1" echo WgB6AG0AcQBLAEgAbAB2AEkAOAA4AEwAMgBnAHkAUABqAHgAegBjAEcARgB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBjAGkAUAB1AG0AYwBnAE8AZQBoAHIA
>> "%~1" echo dQBpAHUAcABEAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoANAA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAEcATgB0AFoA
>> "%~1" echo RQBkAHkAYQBXAFEAaQBQAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAE4AdABaAEMAQgBpAGIASABWAGwASQBHAFIAaABiAG0AZABsAGMA
>> "%~1" echo awBGAGoAZABHAGwAdgBiAGkASQBnAFoARwBGADAAWQBTADEAaABZADMAUgBwAGIA
>> "%~1" echo MgA0ADkASQBtAFIAbABZAG4AVgBuAFgAMgAxAHYAWgBHAFUAaQBQAGoAeABpAFAA
>> "%~1" echo dQBXAFEAcgArAGUAVQBxAE8AaQB3AGcAKwBpAHYAbABlAGEAbwBvAGUAVwA4AGoA
>> "%~1" echo egB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AGsAdgA1ADMAbQBqAEkASABsAGwA
>> "%~1" echo SwBUAHAAaABwAEwAagBnAEkARQB5AE4AQwBEAGwAcwBJAC8AbQBsADcAYgBqAGcA
>> "%~1" echo SQBGAHcAYwBtADkANABYADIATgBzAGIAMwBOAGwAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB4AGkAZABYAFIAMABiADIANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoAQwBCAGkAYgBIAFYAbABJAEcAUgBoAGIA
>> "%~1" echo bQBkAGwAYwBrAEYAagBkAEcAbAB2AGIAaQBJAGcAWgBHAEYAMABZAFMAMQBoAFkA
>> "%~1" echo MwBSAHAAYgAyADQAOQBJAG0AdABsAFoAWABCAGYAWQBYAGQAaABhADIAVQBpAFAA
>> "%~1" echo agB4AGkAUAB1AFcANgBsAE8AZQBVAHEATwBTAC8AbgBlAGEAMAB1AHoAdwB2AFkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANwBsAGsASQB6AG0AbAA3AGIAbQBsAEwAawBnAFYA
>> "%~1" echo MgBrAHQAUgBtAG4AagBnAEkARgB6AGIARwBWAGwAYwBGADkAMABhAFcAMQBsAGIA
>> "%~1" echo MwBWADAAUABDADkAegBjAEcARgB1AFAAagB3AHYAWQBuAFYAMABkAEcAOQB1AFAA
>> "%~1" echo agB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoA
>> "%~1" echo QwBCAGgAYgBXAEoAbABjAGkAQgBrAFkAVwA1AG4AWgBYAEoAQgBZADMAUgBwAGIA
>> "%~1" echo MgA0AGkASQBHAFIAaABkAEcARQB0AFkAVwBOADAAYQBXADkAdQBQAFMASgAzAGEA
>> "%~1" echo WABKAGwAYgBHAFYAegBjAHkASQArAFAARwBJACsANQBiAHkAQQA1AFoAQwB2ADUA
>> "%~1" echo cABlAGcANQA3AHEALwBJAEUARgBFAFEAagB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA3AHAAbgBJAEQAbwBwAG8ARQBnAFYAVgBOAEMASQBPAFcAMwBzAHUAYQBPAGkA
>> "%~1" echo TwBhAGQAZwB6AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIA
>> "%~1" echo VwBRAGcAYwBtAFYAawBJAEcAUgBoAGIAbQBkAGwAYwBrAEYAagBkAEcAbAB2AGIA
>> "%~1" echo aQBJAGcAWgBHAEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4AZABwAGMA
>> "%~1" echo bQBWAHMAWgBYAE4AegBYADIAOQBtAFoAaQBJACsAUABHAEkAKwA1AFkAVwB6ADYA
>> "%~1" echo WgBlAHQANQBwAGUAZwA1ADcAcQAvAEkARQBGAEUAUQBqAHcAdgBZAGoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBqADcAbABpAEkAZgBsAG0ANQA0AGcAVgBWAE4AQwBJAE8AYQBvAG8A
>> "%~1" echo ZQBXADgAagB6AHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAFkAWABKAGsASQBqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBvAFoAVwBGAGsASQBqADQAOABhAEQASQArADYA
>> "%~1" echo TAA2AFQANQBZAFcAbAA1AEwAaQBPADUAYgBtAC8ANQBwAEsAdABQAEMAOQBvAE0A
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBkAEcARgBuAEkA
>> "%~1" echo agA3AGwAawBiADMAawB1ADYAUQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUA
>> "%~1" echo UwBCAGoAYgBXAFIASABjAG0AbABrAEkAagA0ADgAWQBuAFYAMABkAEcAOQB1AEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBqAGIAVwBRAGkASQBHAFIAaABkAEcARQB0AFkA
>> "%~1" echo VwBOADAAYQBXADkAdQBQAFMASgByAFoAWABsAGYAYwAyAHgAbABaAFgAQQBpAFAA
>> "%~1" echo agB4AGkAUABrAHQARgBXAFUATgBQAFIARQBWAGYAVQAwAHgARgBSAFYAQQA4AEwA
>> "%~1" echo MgBJACsAUABIAE4AdwBZAFcANAArADUANwBPADcANQA3AHUAZgA1ADUAMgBoADUA
>> "%~1" echo NQB5AGcANgBaAFMAdQBQAEMAOQB6AGMARwBGAHUAUABqAHcAdgBZAG4AVgAwAGQA
>> "%~1" echo RwA5AHUAUABqAHgAaQBkAFgAUgAwAGIAMgA0AGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBOAHQAWgBDAEkAZwBaAEcARgAwAFkAUwAxAGgAWQAzAFIAcABiADIANAA5AEkA
>> "%~1" echo bgBCAHkAYgAzAGgAZgBiADMAQgBsAGIAaQBJACsAUABHAEkAKwA1AGIAbQAvADUA
>> "%~1" echo cABLAHQASQBIAEIAeQBiADMAaABmAGIAMwBCAGwAYgBqAHcAdgBZAGoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBqADcAbwBwADYAUABwAG0AYQBUAGsAdgBhAG4AbQBpAEwAVABtAHEA
>> "%~1" echo SwBIAG0AaQA1AC8AdgB2AEkAegBsAGgAWQBIAG8AcgByAGoAbgBoAG8AVABsAHMA
>> "%~1" echo WQA4ADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAA
>> "%~1" echo RwBKADEAZABIAFIAdgBiAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIAMQBrAEkA
>> "%~1" echo RwBGAHQAWQBtAFYAeQBJAEcAUgBoAGIAbQBkAGwAYwBrAEYAagBkAEcAbAB2AGIA
>> "%~1" echo aQBJAGcAWgBHAEYAMABZAFMAMQBoAFkAMwBSAHAAYgAyADQAOQBJAG4AQgB5AGIA
>> "%~1" echo MwBoAGYAWQAyAHgAdgBjADIAVQBpAFAAagB4AGkAUAB1AFcANQB2ACsAYQBTAHIA
>> "%~1" echo UwBCAHcAYwBtADkANABYADIATgBzAGIAMwBOAGwAUABDADkAaQBQAGoAeAB6AGMA
>> "%~1" echo RwBGAHUAUAB1AGEAbwBvAGUAYQBMAG4AKwBTADkAcQBlAGEASQB0AE8AbQBkAG8A
>> "%~1" echo TwBpAC8AawBUAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAEoAMQBkAEgAUgB2AGIA
>> "%~1" echo agA0ADgAWQBuAFYAMABkAEcAOQB1AEkARwBOAHMAWQBYAE4AegBQAFMASgBqAGIA
>> "%~1" echo VwBRAGcAWQBXADEAaQBaAFgASQBpAEkARwBsAGsAUABTAEoAbgBiADAATgAxAGMA
>> "%~1" echo MwBSAHYAYgBVAEoAeQBiADIARgBrAFkAMgBGAHoAZABDAEkAKwBQAEcASQArADYA
>> "%~1" echo SQBlAHEANQBhADYAYQA1AEwAbQBKADUAYgBtAC8ANQBwAEsAdABQAEMAOQBpAFAA
>> "%~1" echo agB4AHoAYwBHAEYAdQBQAHUAVwBPAHUAKwBtAHIAbQBPAGUANgBwAHkAQgB6AFoA
>> "%~1" echo WABSADAAYQBXADUAbgBjAHkARABwAG8AYgBYAHAAbgBhAEwAbABqADUASABwAGcA
>> "%~1" echo SQBFADgATAAzAE4AdwBZAFcANAArAFAAQwA5AGkAZABYAFIAMABiADIANAArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUAVwB4AGoA
>> "%~1" echo KwBXADUAbABlAGkAMgBoAGUAYQBYAHQAagB3AHYAYQBEAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0AGcAWQAyAHgAaABjADMATQA5AEkAbgBSAGgAWgB5AEkAKwA2AGEASwBFADYA
>> "%~1" echo SwA2ACsAUABDADkAegBjAEcARgB1AFAAagB3AHYAWgBHAGwAMgBQAGoAeABrAGEA
>> "%~1" echo WABZAGcAWQAyAHgAaABjADMATQA5AEkAbQBKAHYAWgBIAGsAZwBZADIAMQBrAFIA
>> "%~1" echo MwBKAHAAWgBDAEkAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyADEAawBJAEcAZAB5AFoAVwBWAHUASQBpAEIAawBZAFgAUgBoAEwA
>> "%~1" echo VwBGAGoAZABHAGwAdgBiAGoAMABpAGMAMgBOAHkAWgBXAFYAdQBYAHoAVgB0AEkA
>> "%~1" echo agA0ADgAWQBqADQAMQBJAE8AVwBJAGgAdQBtAFMAbgArAGUARwBoAE8AVwB4AGoA
>> "%~1" echo egB3AHYAWQBqADQAOABjADMAQgBoAGIAagA1AHoAWQAzAEoAbABaAFcANQBmAGIA
>> "%~1" echo MgBaAG0AWAAzAFIAcABiAFcAVgB2AGQAWABRADkATQB6AEEAdwBNAEQAQQB3AFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoAeABpAGQA
>> "%~1" echo WABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBpAGIA
>> "%~1" echo SABWAGwASQBHAFIAaABiAG0AZABsAGMAawBGAGoAZABHAGwAdgBiAGkASQBnAFoA
>> "%~1" echo RwBGADAAWQBTADEAaABZADMAUgBwAGIAMgA0ADkASQBuAE4AagBjAG0AVgBsAGIA
>> "%~1" echo bAA4AHkATgBHAGcAaQBQAGoAeABpAFAAagBJADAASQBPAFcAdwBqACsAYQBYAHQA
>> "%~1" echo dQBTADYAcgB1AFcAeABqAHoAdwB2AFkAagA0ADgAYwAzAEIAaABiAGoANQB6AFkA
>> "%~1" echo MwBKAGwAWgBXADUAZgBiADIAWgBtAFgAMwBSAHAAYgBXAFYAdgBkAFgAUQA5AE8A
>> "%~1" echo RABZADAATQBEAEEAdwBNAEQAQQA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyADEAawBJAGkAQgBrAFkAWABSAGgATABXAEYAagBkAEcAbAB2AGIA
>> "%~1" echo agAwAGkAYwAzAFIAaABlAFYAOQB2AFoAbQBZAGkAUABqAHgAaQBQAHUAVwBGAHMA
>> "%~1" echo KwBtAFgAcgBlAFMALwBuAGUAYQBNAGcAZQBXAFUAcABPAG0ARwBrAGoAdwB2AFkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANQB6AGQARwBGADUAWAAyADkAdQBQAFQAQQA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyADEAawBJAEcASgBzAGQA
>> "%~1" echo VwBVAGcAWgBHAEYAdQBaADIAVgB5AFEAVwBOADAAYQBXADkAdQBJAGkAQgBrAFkA
>> "%~1" echo WABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwAzAFIAaABlAFYAOQAxAGMA
>> "%~1" echo MgBKAGYAWQBXAE0AaQBQAGoAeABpAFAAbABWAFQAUQBpADkAQgBRAHkARABrAHYA
>> "%~1" echo NQAzAG0AagBJAEgAbABsAEsAVABwAGgAcABJADgATAAyAEkAKwBQAEgATgB3AFkA
>> "%~1" echo VwA0ACsAYwAzAFIAaABlAFYAOQB2AGIAagAwAHoAUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWQBuAFYAMABkAEcAOQB1AFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBuAGkAcgBiAG0AZwBJAEgAawB1AEkANwBtAG4A
>> "%~1" echo SQAzAGwAaQBxAEUAOABMADIAZwB5AFAAagB4AHoAYwBHAEYAdQBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAMABZAFcAYwBpAFAAdQBlADcAdABPAGEASwBwAEQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAaQBiADIAUgA1AEkARwBOAHQAWgBFAGQAeQBhAFcAUQBpAFAA
>> "%~1" echo agB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgB0AFoA
>> "%~1" echo QwBJAGcAYQBXAFEAOQBJAG0AMQBoAGIAbgBWAGgAYgBGAEoAbABaAG4ASgBsAGMA
>> "%~1" echo MgBnAGkAUABqAHgAaQBQAHUAVwBJAHQAKwBhAFcAcwBPAGUASwB0AHUAYQBBAGcA
>> "%~1" echo VAB3AHYAWQBqADQAOABjADMAQgBoAGIAagA3AHAAaAA0ADMAbQBsAHIARABvAHIA
>> "%~1" echo NwB2AGwAagA1AGIAbwByAHIANwBsAHAASQBmAG0AbABiAEQAbABnAEwAdwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBpAGQAWABSADAAYgAyADQAKwBQAEcASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyADEAawBJAGkAQgBrAFkA
>> "%~1" echo WABSAGgATABXAEYAagBkAEcAbAB2AGIAagAwAGkAYwBtAFYAegBkAEcARgB5AGQA
>> "%~1" echo RgA5AGgAWgBHAEkAaQBQAGoAeABpAFAAdQBtAEgAagBlAFcAUQByAHkAQgBCAFIA
>> "%~1" echo RQBJADgATAAyAEkAKwBQAEgATgB3AFkAVwA0ACsANQBMAHUARgA2AFkAZQBOADUA
>> "%~1" echo WgBDAHYANQA1AFMAMQA2AEkAUwBSADUANgB1AHYANQBwAHkATgA1AFkAcQBoAFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoAeABpAGQA
>> "%~1" echo WABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAE4AdABaAEMAQgBrAFkA
>> "%~1" echo VwA1AG4AWgBYAEoAQgBZADMAUgBwAGIAMgA0AGkASQBHAFIAaABkAEcARQB0AFkA
>> "%~1" echo VwBOADAAYQBXADkAdQBQAFMASgB5AFoAWABOADAAYgAzAEoAbABYADIASgBoAFkA
>> "%~1" echo MgB0ADEAYwBDAEkAKwBQAEcASQArADUATAB1AE8ANQBhAFMASAA1AEwAdQA5ADUA
>> "%~1" echo bwBHAGkANQBhAFMATgBQAEMAOQBpAFAAagB4AHoAYwBHAEYAdQBQAHUAYQBCAG8A
>> "%~1" echo dQBXAGsAagBlAG0AbQBsAHUAYQBzAG8AZQBXAEcAbQBlAFcARgBwAGUAVwBKAGoA
>> "%~1" echo ZQBpAHUAdgB1AGUAOQByAGoAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASgAxAGQA
>> "%~1" echo SABSAHYAYgBqADQAOABZAG4AVgAwAGQARwA5AHUASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGoAYgBXAFEAaQBJAEcAbABrAFAAUwBKAG4AYgAwAHgAdgBaADMATQBpAFAA
>> "%~1" echo agB4AGkAUAB1AGEAVABqAGUAUwA5AG4ATwBhAFgAcABlAFcALwBsAHoAdwB2AFkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANwBtAG4ANgBYAG4AbgBJAHYAbQBsAG8AZgBrAHUA
>> "%~1" echo NwBiAG0AbAA2AFgAbAB2ADUAYwA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAGQA
>> "%~1" echo WABSADAAYgAyADQAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAWQAyAEYAeQBaAEMASQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBHAFYAaABaAEMASQArAFAA
>> "%~1" echo RwBnAHkAUAB1AFcAOQBrACsAVwBKAGoAZQBhAFIAbQBPAGkAbQBnAFQAdwB2AGEA
>> "%~1" echo RABJACsAUABIAE4AdwBZAFcANABnAFkAMgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoA
>> "%~1" echo eQBJAGcAYQBXAFEAOQBJAG0ATgB2AGIAbgBOAHYAYgBHAFYAVABkAEcARgAwAFoA
>> "%~1" echo UwBJACsATABUAHcAdgBjADMAQgBoAGIAagA0ADgATAAyAFIAcABkAGoANAA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGkAYgAyAFIANQBJAGoANAA4AGQA
>> "%~1" echo RwBGAGkAYgBHAFUAZwBZADIAeABoAGMAMwBNADkASQBuAFIAaABZAG0AeABsAEkA
>> "%~1" echo agA0ADgAZABIAEkAKwBQAEgAUgBrAFAAdQBpAC8AbgB1AGEATwBwAFQAdwB2AGQA
>> "%~1" echo RwBRACsAUABIAFIAawBJAEcAbABrAFAAUwBKAGoAYgAyADUAegBiADIAeABsAFEA
>> "%~1" echo MgA5AHUAYgBpAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAHUAZQBVAHQAZQBtAEgAagB6AHcAdgBkAEcAUQArAFAA
>> "%~1" echo SABSAGsASQBHAGwAawBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABRAG0ARgAwAGQA
>> "%~1" echo RwBWAHkAZQBTAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAHUAUwA4AGsAZQBlAGMAbwBEAHcAdgBkAEcAUQArAFAA
>> "%~1" echo SABSAGsASQBHAGwAawBQAFMASgBqAGIAMgA1AHoAYgAyAHgAbABWADIARgByAFoA
>> "%~1" echo UwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABkAEgASQArAFAA
>> "%~1" echo SABSAGsAUABsAGQAcABMAFUAWgBwAFAAQwA5ADAAWgBEADQAOABkAEcAUQBnAGEA
>> "%~1" echo VwBRADkASQBtAE4AdgBiAG4ATgB2AGIARwBWAFgAYQBXAFoAcABJAGoANAB0AFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABMADMAUgB5AFAAagB3AHYAZABHAEYAaQBiAEcAVQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEAWABZACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo QwA5AHoAWgBXAE4AMABhAFcAOQB1AFAAZwBvADgAYwAyAFYAagBkAEcAbAB2AGIA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGMARwBGAG4AWgBTAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQBSAGwAZABtAGwAagBaAFMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AGkAdQB2AHUAVwBrAGgA
>> "%~1" echo KwBhAGgAbwArAGEAaABpAEQAdwB2AGEARABJACsAUABIAE4AdwBZAFcANABnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4AUgBoAFoAeQBJACsANQBZAFcAcwA1AGIAeQBBAEkA
>> "%~1" echo RQBGAEUAUQBpAEQAbABqADYAcgBvAHIANwBzADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo bQA5AGsAZQBTAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEA
>> "%~1" echo VwA1AG0AYgAwAGQAeQBhAFcAUQBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAGwAdQBaAG0AOQBVAGEAVwB4AGwASQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA3AGwAagBvAEwAbABsAFkAWQBnAEwAeQBEAGwAawA0AEgAbgBpAFkAdwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEcASQArAFAASABOAHcAWQBXADQAZwBhAFcAUQA5AEkA
>> "%~1" echo bQAxAGgAYgBuAFYAbQBZAFcATgAwAGQAWABKAGwAYwBpAEkAKwBMAFQAdwB2AGMA
>> "%~1" echo MwBCAGgAYgBqADQAZwBMAHkAQQA4AGMAMwBCAGgAYgBpAEIAcABaAEQAMABpAFkA
>> "%~1" echo bgBKAGgAYgBtAFEAaQBQAGkAMAA4AEwAMwBOAHcAWQBXADQAKwBQAEMAOQBpAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBsAHUAWgBtADkAVQBhAFcAeABsAEkAagA0ADgAYwAzAEIAaABiAGoANwBsAG4A
>> "%~1" echo bwB2AGwAagA3AGMAOABMADMATgB3AFkAVwA0ACsAUABHAEkAZwBhAFcAUQA5AEkA
>> "%~1" echo bQAxAHYAWgBHAFYAcwBJAGoANAB0AFAAQwA5AGkAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAZwBZADIAeABoAGMAMwBNADkASQBtAGwAdQBaAG0AOQBVAGEA
>> "%~1" echo VwB4AGwASQBqADQAOABjADMAQgBoAGIAagA3AGsAdQBxAGYAbABrADQARQBnAEwA
>> "%~1" echo eQBEAG8AcgByADcAbABwAEkAYwBnAEwAeQBEAG0AbgBiAC8AbgB1AHEAYwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEcASQArAFAASABOAHcAWQBXADQAZwBhAFcAUQA5AEkA
>> "%~1" echo bgBCAHkAYgAyAFIAMQBZADMAUgBPAFkAVwAxAGwASQBqADQAdABQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABpAEEAdgBJAEQAeAB6AGMARwBGAHUASQBHAGwAawBQAFMASgB3AGMA
>> "%~1" echo bQA5AGsAZABXAE4AMABSAEcAVgAyAGEAVwBOAGwASQBqADQAdABQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABpAEEAdgBJAEQAeAB6AGMARwBGAHUASQBHAGwAawBQAFMASgBpAGIA
>> "%~1" echo MgBGAHkAWgBDAEkAKwBMAFQAdwB2AGMAMwBCAGgAYgBqADQAOABMADIASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEA
>> "%~1" echo VwA1AG0AYgAxAFIAcABiAEcAVQBpAFAAagB4AHoAYwBHAEYAdQBQAGwATgB2AFEA
>> "%~1" echo egB3AHYAYwAzAEIAaABiAGoANAA4AFkAaQBCAHAAWgBEADAAaQBjADIAOQBqAEkA
>> "%~1" echo agA0AHQAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AbAB1AFoAbQA5AFUAYQBXAHgAbABJAGoANAA4AGMA
>> "%~1" echo MwBCAGgAYgBqADUAQwBkAFcAbABzAFoARAB3AHYAYwAzAEIAaABiAGoANAA4AFkA
>> "%~1" echo aQBCAHAAWgBEADAAaQBZAG4AVgBwAGIARwBSAEoAWgBDAEkAKwBMAFQAdwB2AFkA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcANAArAFEA
>> "%~1" echo bgBKAGgAYgBtAE4AbwBQAEMAOQB6AGMARwBGAHUAUABqAHgAaQBJAEcAbABrAFAA
>> "%~1" echo UwBKAGkAZABXAGwAcwBaAEUASgB5AFkAVwA1AGoAYQBDAEkAKwBMAFQAdwB2AFkA
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAHAAYgBtAFoAdgBWAEcAbABzAFoAUwBJACsAUABIAE4AdwBZAFcANAArAFMA
>> "%~1" echo VwA1AGoAYwBtAFYAdABaAFcANQAwAFkAVwB3ADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo RwBJAGcAYQBXAFEAOQBJAG0ASgAxAGEAVwB4AGsAUwBXADUAagBjAG0AVgB0AFoA
>> "%~1" echo VwA1ADAAWQBXAHcAaQBQAGkAMAA4AEwAMgBJACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo RwBSAHAAZABpAEIAagBiAEcARgB6AGMAegAwAGkAYQBXADUAbQBiADEAUgBwAGIA
>> "%~1" echo RwBVAGkAUABqAHgAegBjAEcARgB1AFAAawBGAEMAUwBUAHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgAWQBpAEIAcABaAEQAMABpAFkAVwBKAHAASQBqADQAdABQAEMAOQBpAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAeABrAGEAWABZAGcAWQAyAHgAaABjADMATQA5AEkA
>> "%~1" echo bQBsAHUAWgBtADkAVQBhAFcAeABsAEkAagA0ADgAYwAzAEIAaABiAGoANQBXAFoA
>> "%~1" echo VwA1AGsAYgAzAEkAZwBVAEcARgAwAFkAMgBnADgATAAzAE4AdwBZAFcANAArAFAA
>> "%~1" echo RwBJAGcAYQBXAFEAOQBJAG4AWgBsAGIAbQBSAHYAYwBsAEIAaABkAEcATgBvAEkA
>> "%~1" echo agA0AHQAUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG4ASgB2AGQAeQBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZADIARgB5AFoAQwBJACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoAQwBJACsAUABHAGcAeQBQAHUAaQB1AHYA
>> "%~1" echo dQBXAGsAaAArAFMANABqAHUAaQAvAG4AdQBhAE8AcABUAHcAdgBhAEQASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo bQA5AGsAZQBTAEkAKwBQAEgAUgBoAFkAbQB4AGwASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKADAAWQBXAEoAcwBaAFMASQArAFAASABSAHkAUABqAHgAMABaAEQANQBCAFIA
>> "%~1" echo RQBJAGcANgBMAGUAdgA1AGIANgBFAFAAQwA5ADAAWgBEADQAOABkAEcAUQBnAGEA
>> "%~1" echo VwBRADkASQBtAEYAawBZAGwAQgBoAGQARwBnAGkAUABpADAAOABMADMAUgBrAFAA
>> "%~1" echo agB3AHYAZABIAEkAKwBQAEgAUgB5AFAAagB4ADAAWgBEADcAbwByAHIANwBsAHAA
>> "%~1" echo SQBmAG8AbwBZAHcAOABMADMAUgBrAFAAagB4ADAAWgBDAEIAcABaAEQAMABpAFoA
>> "%~1" echo RwBWADIAYQBXAE4AbABUAEcAbAB1AFoAUwBJACsATABUAHcAdgBkAEcAUQArAFAA
>> "%~1" echo QwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUABsAGQAcABMAFUAWgBwAEkA
>> "%~1" echo RQBsAFEAUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG4AZABwAFoA
>> "%~1" echo bQBsAEoAYwBDAEkAKwBMAFQAdwB2AGQARwBRACsAUABDADkAMABjAGoANAA4AGQA
>> "%~1" echo SABJACsAUABIAFIAawBQAGsARgB1AFoASABKAHYAYQBXAFEAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFkAVwA1AGsAYwBtADkAcABaAEMASQArAEwA
>> "%~1" echo VAB3AHYAZABHAFEAKwBQAEMAOQAwAGMAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAA
>> "%~1" echo bABOAEUAUwB6AHcAdgBkAEcAUQArAFAASABSAGsASQBHAGwAawBQAFMASgB6AFoA
>> "%~1" echo RwBzAGkAUABpADAAOABMADMAUgBrAFAAagB3AHYAZABIAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAbAByAG8AbgBsAGgAYQBqAG8AbwBhAFgAawB1AEkARQA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAYwAyAFYAagBkAFgASgBwAGQA
>> "%~1" echo SABsAFEAWQBYAFIAagBhAEMASQArAEwAVAB3AHYAZABHAFEAKwBQAEMAOQAwAGMA
>> "%~1" echo agA0ADgATAAzAFIAaABZAG0AeABsAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBuAG8AYQB6AGsAdQA3AGIAbQBrAFoAagBvAHAA
>> "%~1" echo bwBFADgATAAyAGcAeQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoASABrAGkAUABqAHgAMABZAFcASgBzAFoA
>> "%~1" echo UwBCAGoAYgBHAEYAegBjAHoAMABpAGQARwBGAGkAYgBHAFUAaQBQAGoAeAAwAGMA
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
>> "%~1" echo agB3AHYAZABHAEYAaQBiAEcAVQArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBZADIARgB5AFoA
>> "%~1" echo QwBJACsAUABHAFIAcABkAGkAQgBqAGIARwBGAHoAYwB6ADAAaQBhAEcAVgBoAFoA
>> "%~1" echo QwBJACsAUABHAGcAeQBQAHUAYQBKAGkAKwBhAGYAaABPAGUANgB2ACsAZQAwAG8A
>> "%~1" echo agB3AHYAYQBEAEkAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADAAaQBZAG0AOQBrAGUAUwBJACsAUABIAFIAaABZAG0AeABsAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgAwAFkAVwBKAHMAWgBTAEkAKwBQAEgAUgB5AFAA
>> "%~1" echo agB4ADAAWgBEADcAbAB0ADYAYgBtAGkAWQB2AG0AbgA0AFQAbgBsAEwAWABwAGgA
>> "%~1" echo NAA4ADgATAAzAFIAawBQAGoAeAAwAFoAQwBCAHAAWgBEADAAaQBZADIAOQB1AGQA
>> "%~1" echo SABKAHYAYgBHAHgAbABjAGsAeABsAFoAbgBSAEMAWQBYAFIAMABaAFgASgA1AEkA
>> "%~1" echo agA0AHQAUABDADkAMABaAEQANAA4AEwAMwBSAHkAUABqAHgAMABjAGoANAA4AGQA
>> "%~1" echo RwBRACsANQBZACsAegA1AG8AbQBMADUAcAArAEUANQA1AFMAMQA2AFkAZQBQAFAA
>> "%~1" echo QwA5ADAAWgBEADQAOABkAEcAUQBnAGEAVwBRADkASQBtAE4AdgBiAG4AUgB5AGIA
>> "%~1" echo MgB4AHMAWgBYAEoAUwBhAFcAZABvAGQARQBKAGgAZABIAFIAbABjAG4AawBpAFAA
>> "%~1" echo aQAwADgATAAzAFIAawBQAGoAdwB2AGQASABJACsAUABIAFIAeQBQAGoAeAAwAFoA
>> "%~1" echo RAA3AGwAdAA2AGIAbQBpAFkAdgBtAG4ANABUAG4AaQByAGIAbQBnAEkARQA4AEwA
>> "%~1" echo MwBSAGsAUABqAHgAMABaAEMAQgBwAFoARAAwAGkAWQAyADkAdQBkAEgASgB2AGIA
>> "%~1" echo RwB4AGwAYwBrAHgAbABaAG4AUgBUAGQARwBGADAAZABYAE0AaQBQAGkAMAA4AEwA
>> "%~1" echo MwBSAGsAUABqAHcAdgBkAEgASQArAFAASABSAHkAUABqAHgAMABaAEQANwBsAGoA
>> "%~1" echo NwBQAG0AaQBZAHYAbQBuADQAVABuAGkAcgBiAG0AZwBJAEUAOABMADMAUgBrAFAA
>> "%~1" echo agB4ADAAWgBDAEIAcABaAEQAMABpAFkAMgA5AHUAZABIAEoAdgBiAEcAeABsAGMA
>> "%~1" echo bABKAHAAWgAyAGgAMABVADMAUgBoAGQASABWAHoASQBqADQAdABQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgATAAzAFIAeQBQAGoAdwB2AGQARwBGAGkAYgBHAFUAKwBQAEcAUgBwAGQA
>> "%~1" echo aQBCAGoAYgBHAEYAegBjAHoAMABpAGIARwA5AG4ASQBpAEIAcABaAEQAMABpAFkA
>> "%~1" echo MgA5AHUAZABIAEoAdgBiAEcAeABsAGMAawBoAHAAYgBuAFEAaQBQAGkAMAA4AEwA
>> "%~1" echo MgBSAHAAZABqADQAOABMADIAUgBwAGQAagA0ADgATAAyAFIAcABkAGoANAA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAGoAWQBYAEoAawBJAGoANAA4AFoA
>> "%~1" echo RwBsADIASQBHAE4AcwBZAFgATgB6AFAAUwBKAG8AWgBXAEYAawBJAGoANAA4AGEA
>> "%~1" echo RABJACsANQA1AFMAMQA1AHIAcQBRADUANABxADIANQBvAEMAQgBQAEMAOQBvAE0A
>> "%~1" echo agA0ADgATAAyAFIAcABkAGoANAA4AFoARwBsADIASQBHAE4AcwBZAFgATgB6AFAA
>> "%~1" echo UwBKAGkAYgAyAFIANQBJAGoANAA4AGQARwBGAGkAYgBHAFUAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBuAFIAaABZAG0AeABsAEkAagA0ADgAZABIAEkAKwBQAEgAUgBrAFAA
>> "%~1" echo bQAxAFQAZABHAEYANQBUADIANAA4AEwAMwBSAGsAUABqAHgAMABaAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAYgBWAE4AMABZAFgAbABQAGIAaQBJACsATABUAHcAdgBkAEcAUQArAFAA
>> "%~1" echo QwA5ADAAYwBqADQAOABkAEgASQArAFAASABSAGsAUABtADEAUQBjAG0AOQA0AGEA
>> "%~1" echo VwAxAHAAZABIAGwAUQBiADMATgBwAGQARwBsADIAWgBUAHcAdgBkAEcAUQArAFAA
>> "%~1" echo SABSAGsASQBHAGwAawBQAFMASgB0AFUASABKAHYAZQBHAGwAdABhAFgAUgA1AFUA
>> "%~1" echo RwA5AHoAYQBYAFIAcABkAG0AVQBpAFAAaQAwADgATAAzAFIAawBQAGoAdwB2AGQA
>> "%~1" echo SABJACsAUABIAFIAeQBQAGoAeAAwAFoARAA1AHQAVQAzAFIAaABlAFUAOQB1AFYA
>> "%~1" echo MgBoAHAAYgBHAFYAUQBiAEgAVgBuAFoAMgBWAGsAUwBXADUAVABaAFgAUgAwAGEA
>> "%~1" echo VwA1AG4AUABDADkAMABaAEQANAA4AGQARwBRAGcAYQBXAFEAOQBJAG0AMQBUAGQA
>> "%~1" echo RwBGADUAVAAyADUAVABaAFgAUgAwAGEAVwA1AG4ASQBqADQAdABQAEMAOQAwAFoA
>> "%~1" echo RAA0ADgATAAzAFIAeQBQAGoAeAAwAGMAagA0ADgAZABHAFEAKwBVADIAeABsAFoA
>> "%~1" echo WABBAGcAZABHAGwAdABaAFcAOQAxAGQARAB3AHYAZABHAFEAKwBQAEgAUgBrAEkA
>> "%~1" echo RwBsAGsAUABTAEoAdwBiADMAZABsAGMAbABOAHMAWgBXAFYAdwBUAEcAbAB1AFoA
>> "%~1" echo UwBJACsATABUAHcAdgBkAEcAUQArAFAAQwA5ADAAYwBqADQAOABMADMAUgBoAFkA
>> "%~1" echo bQB4AGwAUABqAHcAdgBaAEcAbAAyAFAAagB3AHYAWgBHAGwAMgBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMA
>> "%~1" echo bQBRAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AaABsAFkA
>> "%~1" echo VwBRAGkAUABqAHgAbwBNAGoANwBsAHQANgBYAGwAagBvAEkAZwBMAHkARABtAG8A
>> "%~1" echo SwBIAGwAaAA0AGIAbQBqAHEAagBtAGwAcQAzAG8AdgByAG4AbgBsAFkAdwA4AEwA
>> "%~1" echo MgBnAHkAUABqAHcAdgBaAEcAbAAyAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEoAdgBaAEgAawBpAFAAagB4AGsAYQBYAFkAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAHgAdgBaAHkASQArADUAWQArAHYANQBMAHUAbAA1AHAAaQArADUA
>> "%~1" echo NgBTADYASQBGAEYAMQBaAFgATgAwAEkATwBXAEYAcgBPAFcAOABnAEMAQgBCAFIA
>> "%~1" echo RQBJAGcANQBwAHEAMAA2AFoAeQB5ADUANQBxAEUASQBFAFoAaABZADMAUgB2AGMA
>> "%~1" echo bgBrAGcATAB5AEIAUABiAG0AeABwAGIAbQBVAGcAWQAyAEYAcwBhAFcASgB5AFkA
>> "%~1" echo WABSAHAAYgAyADQAZwA1ADcAcQAvADUANwBTAGkANwA3AHkATQA1AEwANgBMADUA
>> "%~1" echo YQBhAEMASQBFAFYAMQBjAG0AVgByAFkAZQBPAEEAZwBWAEIAVwBWAEQARQB1AE0A
>> "%~1" echo ZQBPAEEAZwBYAE4AMABZAFgAUgBwAGIAMgA0AHYAYgBHADkAagBZAFgAUgBwAGIA
>> "%~1" echo MgA0AHYAZABHAFYAegBkAEMARABrAHUANgBQAG4AbwBJAEgAagBnAEkATABrAHUA
>> "%~1" echo SQAzAG8AZwA3ADMAbQBpAG8AcgBsAGgAbwBYAHAAZwA2AGoAawB1ADYAUABuAG8A
>> "%~1" echo SQBIAGwAagA2AC8AcABuAGEARABuAHYANwB2AG8AcgA1AEgAbQBpAEoARABsAGgA
>> "%~1" echo YgBmAGsAdgBaAFAAbABtADcAMwBsAHIAcgBiAGoAZwBJAEgAbABuADQANwBsAHUA
>> "%~1" echo SQBMAG0AaQBKAGIAbAB0ADYAWABsAGoAbwBMAHYAdgBKAHQAWABhAFMAMQBHAGEA
>> "%~1" echo UwBEAGwAbQA3ADMAbAByAHIAYgBuAG8ASQBIAGsAdQBaAC8AawB1AEkAMwBuAHIA
>> "%~1" echo WQBuAGsAdQBvADcAbABoADcAcgBrAHUAcQBmAGwAbgBMAEQAagBnAEkATABsAHIA
>> "%~1" echo bwB6AG0AbABiAFQAbAByAFoAZgBtAHIAcgBYAG8AcgA3AGYAbgBsAEsAagBpAGcA
>> "%~1" echo SgB6AGsAdQBJAEQAcABsAEsANwBsAHIANwB6AGwAaAA3AHIAbwByAHIANwBsAHAA
>> "%~1" echo SQBmAGwAaABhAGoAcABnADYAagBrAHYANgBIAG0AZwBhAC8AaQBnAEoAMwBqAGcA
>> "%~1" echo SQBJADgATAAyAFIAcABkAGoANAA4AEwAMgBSAHAAZABqADQAOABMADIAUgBwAGQA
>> "%~1" echo agA0ADgATAAzAE4AbABZADMAUgBwAGIAMgA0ACsAQwBqAHgAegBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAYwAyAFYAMABkAEcAbAB1AFoAMwBNAGkAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0ATgBoAGMAbQBRAGkAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBJAG0AaABsAFkAVwBRAGkAUABqAHgAbwBNAGoANwBvAGgA
>> "%~1" echo NgByAGwAcgBwAHIAawB1AFkAawBnAGMAMgBWADAAZABHAGwAdQBaADMATQBnAGMA
>> "%~1" echo SABWADAAUABDADkAbwBNAGoANAA4AEwAMgBSAHAAZABqADQAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFMASgBpAGIAMgBSADUASQBHAFoAdgBjAG0AMABpAFAA
>> "%~1" echo agB4AHoAWgBXAHgAbABZADMAUQBnAGEAVwBRADkASQBtAE4AMQBjADMAUgB2AGIA
>> "%~1" echo VQA1AHoASQBqADQAOABiADMAQgAwAGEAVwA5AHUAUABtAGQAcwBiADIASgBoAGIA
>> "%~1" echo RAB3AHYAYgAzAEIAMABhAFcAOQB1AFAAagB4AHYAYwBIAFIAcABiADIANAArAGMA
>> "%~1" echo MwBsAHoAZABHAFYAdABQAEMAOQB2AGMASABSAHAAYgAyADQAKwBQAEcAOQB3AGQA
>> "%~1" echo RwBsAHYAYgBqADUAegBaAFcATgAxAGMAbQBVADgATAAyADkAdwBkAEcAbAB2AGIA
>> "%~1" echo agA0ADgATAAzAE4AbABiAEcAVgBqAGQARAA0ADgAYQBXADUAdwBkAFgAUQBnAGEA
>> "%~1" echo VwBRADkASQBtAE4AMQBjADMAUgB2AGIAVQB0AGwAZQBTAEkAZwBjAEcAeABoAFkA
>> "%~1" echo MgBWAG8AYgAyAHgAawBaAFgASQA5AEkAdQBtAFUAcgB1AFcAUQBqAGUAKwA4AGoA
>> "%~1" echo TwBTACsAaQArAFcAbQBnAGkAQgB6AFkAMwBKAGwAWgBXADUAZgBiADIAWgBtAFgA
>> "%~1" echo MwBSAHAAYgBXAFYAdgBkAFgAUQBpAFAAagB4AHAAYgBuAEIAMQBkAEMAQgBwAFoA
>> "%~1" echo RAAwAGkAWQAzAFYAegBkAEcAOQB0AFYAbQBGAHMAZABXAFUAaQBJAEgAQgBzAFkA
>> "%~1" echo VwBOAGwAYQBHADkAcwBaAEcAVgB5AFAAUwBMAGwAZwBMAHcAaQBQAGoAeABpAGQA
>> "%~1" echo WABSADAAYgAyADQAZwBZADIAeABoAGMAMwBNADkASQBtAEoAMABiAGkASQBnAGEA
>> "%~1" echo VwBRADkASQBtAE4AMQBjADMAUgB2AGIAVgBOAGwAZABDAEkAKwA1AFkAYQBaADUA
>> "%~1" echo WQBXAGwAUABDADkAaQBkAFgAUgAwAGIAMgA0ACsAUABDADkAawBhAFgAWQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo MgBGAHkAWgBDAEkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAGEA
>> "%~1" echo RwBWAGgAWgBDAEkAKwBQAEcAZwB5AFAAdQBXAFAAawBlAG0AQQBnAGUAaQBIAHEA
>> "%~1" echo dQBXAHUAbQB1AFMANQBpAGUAVwA1AHYAKwBhAFMAcgBUAHcAdgBhAEQASQArAFAA
>> "%~1" echo QwA5AGsAYQBYAFkAKwBQAEcAUgBwAGQAaQBCAGoAYgBHAEYAegBjAHoAMABpAFkA
>> "%~1" echo bQA5AGsAZQBTAEIAbQBiADMASgB0AEkAaQBCAHoAZABIAGwAcwBaAFQAMABpAFoA
>> "%~1" echo MwBKAHAAWgBDADEAMABaAFcAMQB3AGIARwBGADAAWgBTADEAagBiADIAeAAxAGIA
>> "%~1" echo VwA1AHoATwBqAEYAbQBjAGkAQQA0AE0AbgBCADQASQBqADQAOABhAFcANQB3AGQA
>> "%~1" echo WABRAGcAYQBXAFEAOQBJAG0ASgB5AGIAMgBGAGsAWQAyAEYAegBkAEUANQBoAGIA
>> "%~1" echo VwBVAGkASQBIAEIAcwBZAFcATgBsAGEARwA5AHMAWgBHAFYAeQBQAFMATABrAHYA
>> "%~1" echo bwB2AGwAcABvAEkAZwBZADIAOQB0AEwAbQA5AGoAZABXAHgAMQBjAHkANQAyAGMA
>> "%~1" echo bgBCAHYAZAAyAFYAeQBiAFcARgB1AFkAVwBkAGwAYwBpADUAdwBjAG0AOQA0AFgA
>> "%~1" echo MgA5AHcAWgBXADQAaQBQAGoAeABpAGQAWABSADAAYgAyADQAZwBZADIAeABoAGMA
>> "%~1" echo MwBNADkASQBtAEoAMABiAGkASQBnAGEAVwBRADkASQBtAE4AMQBjADMAUgB2AGIA
>> "%~1" echo VQBKAHkAYgAyAEYAawBZADIARgB6AGQAQwBJACsANQBZACsAUgA2AFkAQwBCAFAA
>> "%~1" echo QwA5AGkAZABYAFIAMABiADIANAArAFAAQwA5AGsAYQBYAFkAKwBQAEMAOQBrAGEA
>> "%~1" echo WABZACsAUABDADkAegBaAFcATgAwAGEAVwA5AHUAUABqAHgAegBaAFcATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAE4AcwBZAFgATgB6AFAAUwBKAHcAWQBXAGQAbABJAGkAQgBwAFoA
>> "%~1" echo RAAwAGkAYgBHADkAbgBjAHkASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQAyAEYAeQBaAEMASQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAYQBHAFYAaABaAEMASQArAFAARwBnAHkAUAB1AGEAWABwAGUAVwAvAGwA
>> "%~1" echo egB3AHYAYQBEAEkAKwBQAEcASgAxAGQASABSAHYAYgBpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAwAGkAWQBuAFIAdQBJAEcAZABvAGIAMwBOADAASQBpAEIAcABaAEQAMABpAGMA
>> "%~1" echo bQBWAG0AYwBtAFYAegBhAEUAeAB2AFoAMwBNAGkAUAB1AFcASQB0ACsAYQBXAHMA
>> "%~1" echo TwBhAFgAcABlAFcALwBsAHoAdwB2AFkAbgBWADAAZABHADkAdQBQAGoAdwB2AFoA
>> "%~1" echo RwBsADIAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0ASgB2AFoA
>> "%~1" echo SABrAGkAUABqAHgAawBhAFgAWQBnAFkAMgB4AGgAYwAzAE0AOQBJAG0AMQBwAGIA
>> "%~1" echo bQBrAGkASQBIAE4AMABlAFcAeABsAFAAUwBKAHQAWQBYAEoAbgBhAFcANAB0AFkA
>> "%~1" echo bQA5ADAAZABHADkAdABPAGoARQB5AGMASABnAGkAUABqAHgAegBjAEcARgB1AFAA
>> "%~1" echo dQBhAFgAcABlAFcALwBsACsAYQBXAGgAKwBTADcAdABqAHcAdgBjADMAQgBoAGIA
>> "%~1" echo agA0ADgAWQBpAEIAcABaAEQAMABpAGIARwA5AG4AVQBHAEYAMABhAEMASQArAEwA
>> "%~1" echo VAB3AHYAWQBqADQAOABMADIAUgBwAGQAagA0ADgAWgBHAGwAMgBJAEcATgBzAFkA
>> "%~1" echo WABOAHoAUABTAEoAcwBiADIAYwBpAEkARwBsAGsAUABTAEoAcwBiADIAZABDAGIA
>> "%~1" echo MwBnAGkAUAB1AGUAdABpAGUAVwArAGgAZQBhAFQAagBlAFMAOQBuAEMANAB1AEwA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGoAdwB2AFoARwBsADIAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB3AHYAYwAyAFYAagBkAEcAbAB2AGIAagA0ADgATAAyAFIAcABkAGoANAA4AEwA
>> "%~1" echo MgAxAGgAYQBXADQAKwBQAEMAOQBrAGEAWABZACsAQwBqAHgAegBZADMASgBwAGMA
>> "%~1" echo SABRACsAQwBtAE4AdgBiAG4ATgAwAEkARgBSAFAAUwAwAFYATwBQAFMAZABiAFcA
>> "%~1" echo MQBSAFAAUwAwAFYATwBYAFYAMABuAE8AdwBwAGoAYgAyADUAegBkAEMAQQBrAFAA
>> "%~1" echo VwBsAGsAUABUADUAawBiADIATgAxAGIAVwBWAHUAZABDADUAbgBaAFgAUgBGAGIA
>> "%~1" echo RwBWAHQAWgBXADUAMABRAG4AbABKAFoAQwBoAHAAWgBDAGsANwBDAG0ATgB2AGIA
>> "%~1" echo bgBOADAASQBIAEIAaABaADIAVgB6AFAAWAB0AHYAZABtAFYAeQBkAG0AbABsAGQA
>> "%~1" echo egBwAGIASgArAGEAQQB1ACsAaQBuAGkAQwBjAHMASgArAGUASwB0AHUAYQBBAGcA
>> "%~1" echo ZQBhAE0AaAArAGEAZwBoACsAVwBTAGoATwBpAHUAdgB1AFcAawBoACsAYQBtAGcA
>> "%~1" echo dQBpAG4AaQBDAGQAZABMAEcATgB2AGIAbgBOAHYAYgBHAFUANgBXAHkAZgBsAHYA
>> "%~1" echo NgB2AG0AagBiAGYAbQBqAHEAZgBsAGkATABiAGwAagA3AEEAbgBMAEMAZgBtAG0A
>> "%~1" echo NwBUAGwAcABKAHIAbAB1AEwAagBuAGwASwBnAGcAUQBVAFIAQwBJAE8AYQBUAGoA
>> "%~1" echo ZQBTADkAbgBPAFcARgBwAGUAVwBQAG8AeQBkAGQATABHAFIAbABkAG0AbABqAFoA
>> "%~1" echo VABwAGIASgArAGkAdQB2AHUAVwBrAGgAKwBTAC8AbwBlAGEAQgByAHkAYwBzAEoA
>> "%~1" echo KwBlAHoAdQArAGUANwBuACsATwBBAGcAVgBaAHAAYwBuAFIAMQBZAFcAdwBnAFIA
>> "%~1" echo RwBWAHoAYQAzAFIAdgBjAE8ATwBBAGcAZQBhAEoAaQArAGEAZgBoAE8AVwBTAGoA
>> "%~1" echo TwBlAFUAdABlAGEANgBrAE8AZQA2AHYAKwBlADAAbwBpAGQAZABMAEgATgBsAGQA
>> "%~1" echo SABSAHAAYgBtAGQAegBPAGwAcwBuADYAYQB1AFkANQA3AHEAbgBJAEgATgBsAGQA
>> "%~1" echo SABSAHAAYgBtAGQAegBKAHkAdwBuADYATABDAG8ANQBvAFcATwA1AFkAYQBaADUA
>> "%~1" echo WQBXAGwASQBFAEYAdQBaAEgASgB2AGEAVwBRAGcAYwAyAFYAMABkAEcAbAB1AFoA
>> "%~1" echo MwBNAGcANQBvAGkAVwA1AGIAbQAvADUAcABLAHQASgAxADAAcwBiAEcAOQBuAGMA
>> "%~1" echo egBwAGIASgArAGEAWABwAGUAVwAvAGwAeQBjAHMASgArAGEAYwBnAE8AaQAvAGsA
>> "%~1" echo ZQBTADQAZwBPAGEAcwBvAGUAYQBUAGoAZQBTADkAbgBPAGUANwBrACsAYQBlAG4A
>> "%~1" echo QwBkAGQAZgBUAHMASwBZADIAOQB1AGMAMwBRAGcAZABHAGgAbABiAFcAVgBMAFoA
>> "%~1" echo WABrADkASgAzAEYAMQBaAFgATgAwAFEAVwBSAGkAVgBHAGgAbABiAFcAVgBXAE4A
>> "%~1" echo aQBjADcAQwBtAE4AdgBiAG4ATgAwAEkARwBOAHYAYgBtAFoAcABjAG0AMQBVAFoA
>> "%~1" echo WABoADAAUABYAHMASwBJAEMAQgBrAFoAVwBKADEAWgAxADkAdABiADIAUgBsAE8A
>> "%~1" echo aQBmAGsAdgBKAHIAbAB2AEkARABsAGsASwAvAGsAdgA1ADMAbQBqAEkASABsAGwA
>> "%~1" echo SwBUAHAAaABwAEwAagBnAEkARgBYAGEAUwAxAEcAYQBTAEQAawB1AEkAMwBrAHYA
>> "%~1" echo SgBIAG4AbgBLAEQAagBnAEkARQB5AE4AQwBEAGwAcwBJAC8AbQBsADcAYgBsAHMA
>> "%~1" echo WQAvAGwAdQBaAFgAbABrAG8AdwBnAGMASABKAHYAZQBGADkAagBiAEcAOQB6AFoA
>> "%~1" echo ZQArADgAagBPAFcAUABxAHUAVwA3AHUAdQBpAHUAcgB1AGUAZgByAGUAYQBYAHQA
>> "%~1" echo dQBtAFgAdABPAGkAdwBnACsAaQB2AGwAZQBPAEEAZwBpAGMAcwBDAGkAQQBnAGEA
>> "%~1" echo MgBWAGwAYwBGADkAaABkADIARgByAFoAVABvAG4ANQBMAHkAYQA1AFkAYQBaADUA
>> "%~1" echo WQBXAGwANQBMACsAZAA1AG8AeQBCADUAWgBTAGsANgBZAGEAUwA0ADQAQwBCAFYA
>> "%~1" echo MgBrAHQAUgBtAGsAZwA1AEwAaQBOADUATAB5AFIANQA1AHkAZwA0ADQAQwBCAE0A
>> "%~1" echo agBRAGcANQBiAEMAUAA1AHAAZQAyADUAYgBHAFAANQBiAG0AVgA0ADQAQwBCAGMA
>> "%~1" echo MgB4AGwAWgBYAEIAZgBkAEcAbAB0AFoAVwA5ADEAZABEADAAdABNAGUAKwA4AGoA
>> "%~1" echo TwBXADUAdAB1AFcAUABrAGUAbQBBAGcAUwBCAHcAYwBtADkANABYADIATgBzAGIA
>> "%~1" echo MwBOAGwANAA0AEMAQwBKAHkAdwBLAEkAQwBCADMAYQBYAEoAbABiAEcAVgB6AGMA
>> "%~1" echo egBvAG4ANQBMAHkAYQA1AGIAeQBBADUAWgBDAHYASQBEAFUAMQBOAFQAVQBnADUA
>> "%~1" echo cABlAGcANQA3AHEALwBJAEUARgBFAFEAdQArADgAagBPAFcAUQBqAE8AUwA0AGcA
>> "%~1" echo TwBXAHgAZwBPAFcAZgBuACsAZQA5AGsAZQBXAEcAaABlAFcAUAByACsAaQBEAHYA
>> "%~1" echo ZQBpAGkAcQArAGkALwBuAHUAYQBPAHAAZQBPAEEAZwB1AGUAVQBxAE8AVwB1AGoA
>> "%~1" echo TwBpAHYAdAArAFcARgBzACsAbQBYAHIAZQBhAFgAbwBPAGUANgB2AHkAQgBCAFIA
>> "%~1" echo RQBMAGoAZwBJAEkAbgBMAEEAbwBnAEkASABkAHAAYwBtAFYAcwBaAFgATgB6AFgA
>> "%~1" echo MgA5AG0AWgBqAG8AbgA1AEwAeQBhADYASwA2AHAASQBHAEYAawBZAG0AUQBnADUA
>> "%~1" echo WQBpAEgANQBaAHUAZQBJAEYAVgBUAFEAdQArADgAbQArAFcAbQBnAHUAYQBlAG4A
>> "%~1" echo TwBXADkAawArAFcASgBqAGUAbQBkAG8AQwBCAFgAYQBTADEARwBhAFMARABvAHYA
>> "%~1" echo NQA3AG0AagBxAFgAdgB2AEkAegBtAGwAcQAzAGwAdgBJAEQAbABzAFoANwBrAHUA
>> "%~1" echo bwA3AG0AcgBhAFAAbAB1AEwAagBuAGoAcgBEAG8AcwBhAEgAagBnAEkASQBuAEwA
>> "%~1" echo QQBvAGcASQBIAE4AagBjAG0AVgBsAGIAbAA4AHkATgBHAGcANgBKACsAUwA4AG0A
>> "%~1" echo dQBhAEsAaQB1AFcAeABqACsAVwA1AGwAZQBpADIAaABlAGEAWAB0AHUAYQBVAHUA
>> "%~1" echo ZQBTADQAdQBpAEEAeQBOAEMARABsAHMASQAvAG0AbAA3AGIAdgB2AEkAegBsAGoA
>> "%~1" echo NgAvAG8AZwA3ADMAbAByADcAegBvAGgANwBUAGwAcABMAFQAbQBtAEwANwBwAGwA
>> "%~1" echo YgAvAG0AbAA3AGIAcABsADcAVABrAHUASQAzAG4AaABvAFQAbABzAFkALwBqAGcA
>> "%~1" echo SQBJAG4ATABBAG8AZwBJAEgATgAwAFkAWABsAGYAZABYAE4AaQBYADIARgBqAE8A
>> "%~1" echo aQBmAGsAdgBKAHIAbwByAHEAawBnAFYAVgBOAEMATAAwAEYARABJAE8AYQBQAGsA
>> "%~1" echo dQBlAFUAdABlAGEAWAB0AHUAUwAvAG4AZQBhAE0AZwBlAFcAVQBwAE8AbQBHAGsA
>> "%~1" echo dQBPAEEAZwBpAGMAcwBDAGkAQQBnAGMASABKAHYAZQBGADkAagBiAEcAOQB6AFoA
>> "%~1" echo VABvAG4ANQBMAHkAYQA1AHEAaQBoADUAbwB1AGYANQBMADIAcAA1AG8AaQAwADYA
>> "%~1" echo WgAyAGcANgBMACsAUgA3ADcAeQBNADUAWQArAHYANgBJAE8AOQA2AFoAaQA3ADUA
>> "%~1" echo cQAyAGkANgBJAGUAcQA1AFkAcQBvADUANABhAEUANQBiAEcAUAA0ADQAQwBDAEoA
>> "%~1" echo eQB3AEsASQBDAEIAeQBaAFgATgAwAGIAMwBKAGwAWAAyAEoAaABZADIAdAAxAGMA
>> "%~1" echo RABvAG4ANQBMAHkAYQA1AG8AcQBLADYAYQBhAFcANQBxAHkAaAA1AFkAYQBaADUA
>> "%~1" echo WQBXAGwANQBZAG0ATgA1AGEAUwBIADUATAB1ADkANQBZAEMAOAA1AG8ARwBpADUA
>> "%~1" echo YQBTAE4ANQBaAHUAZQBJAEYARgAxAFoAWABOADAANwA3AHkATQA1AGIAbQAyADUA
>> "%~1" echo WQArAFIANgBZAEMAQgBJAEgAQgB5AGIAMwBoAGYAYgAzAEIAbABiAHUATwBBAGcA
>> "%~1" echo aQBjAHMAQwBpAEEAZwBZADMAVgB6AGQARwA5AHQAWAAzAE4AbABkAEgAUgBwAGIA
>> "%~1" echo bQBjADYASgArAFMAOABtAHUAZQBiAHQATwBhAE8AcABlAFcARwBtAFMAQgBCAGIA
>> "%~1" echo bQBSAHkAYgAyAGwAawBJAEgATgBsAGQASABSAHAAYgBtAGQAegA0ADQAQwBDADYA
>> "%~1" echo WgBTAFoANgBLACsAdgA2AFoAUwB1ADUAWQBDADgANQBZACsAdgA2AEkATwA5ADUA
>> "%~1" echo YgAyAHgANQBaAE8ATgA1AEwAeQBSADUANQB5AGcANAA0AEMAQgA1ADcAMgBSADUA
>> "%~1" echo NwB1AGMANQBvAGkAVwA2AEwAQwBEADYASwArAFYANAA0AEMAQwBKAHkAdwBLAEkA
>> "%~1" echo QwBCAGoAZABYAE4AMABiADIAMQBmAFkAbgBKAHYAWQBXAFIAagBZAFgATgAwAE8A
>> "%~1" echo aQBmAGsAdgBKAHIAbABqADUASABwAGcASQBIAG8AaAA2AHIAbAByAHAAcgBrAHUA
>> "%~1" echo WQBrAGcAUQBXADUAawBjAG0AOQBwAFoAQwBEAGwAdQBiAC8AbQBrAHEAMwB2AHYA
>> "%~1" echo SQB6AGwAagA2AHIAbAB1ADcAcgBvAHIAcQA3AGsAdgBhAEQAbQBtAEkANwBuAG8A
>> "%~1" echo YQA3AG4AbgA2AFgAcABnAFoATQBnAFkAVwBOADAAYQBXADkAdQBJAE8AVwBRAHEA
>> "%~1" echo KwBTADUAaQBlAGEAWAB0AHUAUwA5AHYAKwBlAFUAcQBPAE8AQQBnAGkAYwBLAGYA
>> "%~1" echo VABzAEsAWQAyADkAdQBjADMAUQBnAGMARwBGAHkAWQBXADEARQBaAFcAWgB6AFAA
>> "%~1" echo VgBzAEsASQBDAEIANwBhADIAVgA1AE8AaQBkAHoAZABHAEYANQBUADIANABuAEwA
>> "%~1" echo RwA1AGgAYgBXAFUANgBKACsAUwAvAG4AZQBhAE0AZwBlAFcAVQBwAE8AbQBHAGsA
>> "%~1" echo aQBjAHMAYwAyAFYAMABkAEcAbAB1AFoAegBvAG4AWgAyAHgAdgBZAG0ARgBzAEwA
>> "%~1" echo bgBOADAAWQBYAGwAZgBiADIANQBmAGQAMgBoAHAAYgBHAFYAZgBjAEcAeAAxAFoA
>> "%~1" echo MgBkAGwAWgBGADkAcABiAGkAYwBzAGMAMgBGAG0AWgBUAG8AbgBNAEMAYwBzAFkA
>> "%~1" echo VwBOADAAYQBXADkAdQBPAGkAZAB5AFoAWABOAGwAZABGADkAegBkAEcARgA1AFgA
>> "%~1" echo MgA5AHUASgB5AHgAdQBiADMAUgBsAE8AaQBjAHcAUABlAFcARgBnAGUAaQB1AHUA
>> "%~1" echo TwBhAHQAbwArAFcANAB1AE8AUwA4AGsAZQBlAGMAbwBPACsAOABtAHoATQA5AFYA
>> "%~1" echo VgBOAEMATAAwAEYARABJAE8AYQBQAGsAdQBlAFUAdABlAFMALwBuAGUAYQBNAGcA
>> "%~1" echo ZQBXAFUAcABPAG0ARwBrAGkAZAA5AEwAQQBvAGcASQBIAHQAcgBaAFgAawA2AEoA
>> "%~1" echo MwBkAHAAWgBtAGwAVABiAEcAVgBsAGMAQwBjAHMAYgBtAEYAdABaAFQAbwBuAFYA
>> "%~1" echo MgBrAHQAUgBtAGsAZwA1AEwAeQBSADUANQB5AGcANQA2ADIAVwA1ADUAVwBsAEoA
>> "%~1" echo eQB4AHoAWgBYAFIAMABhAFcANQBuAE8AaQBkAG4AYgBHADkAaQBZAFcAdwB1AGQA
>> "%~1" echo MgBsAG0AYQBWADkAegBiAEcAVgBsAGMARgA5AHcAYgAyAHgAcABZADMAawBuAEwA
>> "%~1" echo SABOAGgAWgBtAFUANgBKAHoARQBuAEwARwBGAGoAZABHAGwAdgBiAGoAbwBuAGMA
>> "%~1" echo bQBWAHoAWgBYAFIAZgBkADIAbABtAGEAVgA5AHoAYgBHAFYAbABjAEMAYwBzAGIA
>> "%~1" echo bQA5ADAAWgBUAG8AbgBNAFQAMwBrAHYANQAzAGwAcgBvAGoAcAB1ADUAagBvAHIA
>> "%~1" echo cQBUAHYAdgBKAHMAeQBQAGUAYQBYAHAAKwBlAEoAaQBPAGEAdwB1AE8AUwA0AGoA
>> "%~1" echo ZQBTADgAawBlAGUAYwBvAEMAZAA5AEwAQQBvAGcASQBIAHQAcgBaAFgAawA2AEoA
>> "%~1" echo MwBOAGoAYwBtAFYAbABiAGsAOQBtAFoAaQBjAHMAYgBtAEYAdABaAFQAbwBuADUA
>> "%~1" echo YgBHAFAANQBiAG0AVgA2AEwAYQBGADUAcABlADIASgB5AHgAegBaAFgAUgAwAGEA
>> "%~1" echo VwA1AG4ATwBpAGQAegBlAFgATgAwAFoAVwAwAHUAYwAyAE4AeQBaAFcAVgB1AFgA
>> "%~1" echo MgA5AG0AWgBsADkAMABhAFcAMQBsAGIAMwBWADAASgB5AHgAegBZAFcAWgBsAE8A
>> "%~1" echo aQBjAHoATQBEAEEAdwBNAEQAQQBuAEwARwBGAGoAZABHAGwAdgBiAGoAbwBuAGMA
>> "%~1" echo bQBWAHoAWgBYAFIAZgBjADIATgB5AFoAVwBWAHUAWAAyADkAbQBaAGkAYwBzAGIA
>> "%~1" echo bQA5ADAAWgBUAG8AbgA1AFkAMgBWADUATAAyAE4ANQBxACsAcgA1ADYAZQBTADcA
>> "%~1" echo NwB5AGIATQB6AEEAdwBNAEQAQQB3AFAAVABVAGcANQBZAGkARwA2AFoASwBmADcA
>> "%~1" echo NwB5AE0ATwBEAFkAMABNAEQAQQB3AE0ARABBADkATQBqAFEAZwA1AGIAQwBQADUA
>> "%~1" echo cABlADIASgAzADAAcwBDAGkAQQBnAGUAMgB0AGwAZQBUAG8AbgBjADIAeABsAFoA
>> "%~1" echo WABCAFUAYQBXADEAbABiADMAVgAwAEoAeQB4AHUAWQBXADEAbABPAGkAZgBuAHMA
>> "%~1" echo NwB2AG4AdQA1AC8AbgBuAGEASABuAG4ASwBEAG8AdABvAFgAbQBsADcAWQBuAEwA
>> "%~1" echo SABOAGwAZABIAFIAcABiAG0AYwA2AEoAMwBOAGwAWQAzAFYAeQBaAFMANQB6AGIA
>> "%~1" echo RwBWAGwAYwBGADkAMABhAFcAMQBsAGIAMwBWADAASgB5AHgAegBZAFcAWgBsAE8A
>> "%~1" echo aQBkAHUAZABXAHgAcwBKAHkAeABoAFkAMwBSAHAAYgAyADQANgBKADMASgBsAGMA
>> "%~1" echo MgBWADAAWAAzAE4AcwBaAFcAVgB3AFgAMwBSAHAAYgBXAFYAdgBkAFgAUQBuAEwA
>> "%~1" echo RwA1AHYAZABHAFUANgBKADIANQAxAGIARwB3ADkANQA3AE8ANwA1ADcAdQBmADYA
>> "%~1" echo YgB1AFkANgBLADYAawA3ADcAeQBiAEwAVABFADkANQBMAGkATgA2AEkAZQBxADUA
>> "%~1" echo WQBxAG8ANQA1ADIAaAA1ADUAeQBnAEoAMwAwAEsAWABUAHMASwBiAEcAVgAwAEkA
>> "%~1" echo RwB4AGgAYwAzAFEAOQBlADMAMABzAFkAbgBWAHoAZQBUADEAbQBZAFcAeAB6AFoA
>> "%~1" echo UwB4AHcAWgBXADUAawBhAFcANQBuAFEAMgA5AHUAWgBtAGwAeQBiAFQAMQB1AGQA
>> "%~1" echo VwB4AHMATwB3AHAAbQBkAFcANQBqAGQARwBsAHYAYgBpAEIAbABjADIATQBvAGMA
>> "%~1" echo eQBsADcAYwBtAFYAMABkAFgASgB1AEkARgBOADAAYwBtAGwAdQBaAHkAaAB6AFAA
>> "%~1" echo egA4AG4ASgB5AGsAdQBjAG0AVgB3AGIARwBGAGoAWgBTAGcAdgBXAHkAWQA4AFAA
>> "%~1" echo aQBJAG4AWABTADkAbgBMAEcATQA5AFAAaQBoADcASgB5AFkAbgBPAGkAYwBtAFkA
>> "%~1" echo VwAxAHcATwB5AGMAcwBKAHoAdwBuAE8AaQBjAG0AYgBIAFEANwBKAHkAdwBuAFAA
>> "%~1" echo aQBjADYASgB5AFoAbgBkAEQAcwBuAEwAQwBjAGkASgB6AG8AbgBKAG4ARgAxAGIA
>> "%~1" echo MwBRADcASgB5AHcAaQBKAHkASQA2AEoAeQBZAGoATQB6AGsANwBKADMAMQBiAFkA
>> "%~1" echo MQAwAHAASwBYADAASwBaAG4AVgB1AFkAMwBSAHAAYgAyADQAZwBaAFcAMQB3AGQA
>> "%~1" echo SABrAG8AZABpAGwANwBjAG0AVgAwAGQAWABKAHUASQBIAFkAOQBQAFQAMQAxAGIA
>> "%~1" echo bQBSAGwAWgBtAGwAdQBaAFcAUgA4AGYASABZADkAUABUADEAdQBkAFcAeABzAGYA
>> "%~1" echo SAB4ADIAUABUADAAOQBKAHkAZAA4AGYASABZADkAUABUADAAbgBiAG4AVgBzAGIA
>> "%~1" echo QwBkADkAQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBIAE4AbwBiADMAZAB1AEsA
>> "%~1" echo SABZAHAAZQAzAEoAbABkAEgAVgB5AGIAaQBCAGwAYgBYAEIAMABlAFMAaAAyAEsA
>> "%~1" echo VAA4AG4ATABTAGMANgBVADMAUgB5AGEAVwA1AG4ASwBIAFkAcABmAFEAcABtAGQA
>> "%~1" echo VwA1AGoAZABHAGwAdgBiAGkAQgB6AFoAWABRAG8AYQBXAFEAcwBkAGkAbAA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBaAFQAMABrAEsARwBsAGsASwBUAHQAcABaAGkAaABsAEsA
>> "%~1" echo VwBVAHUAZABHAFYANABkAEUATgB2AGIAbgBSAGwAYgBuAFEAOQBjADIAaAB2AGQA
>> "%~1" echo MgA0AG8AZABpAGwAOQBDAG0AWgAxAGIAbQBOADAAYQBXADkAdQBJAEgAWQBvAGEA
>> "%~1" echo eQBsADcAYwBtAFYAMABkAFgASgB1AEkASABOAG8AYgAzAGQAdQBLAEcAeABoAGMA
>> "%~1" echo MwBSAGIAYQAxADAAcABPADMAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGIA
>> "%~1" echo bQA5ADAAYQBXAFoANQBLAEgAUgBwAGQARwB4AGwATABHADEAegBaAHkAeAAwAGUA
>> "%~1" echo WABCAGwAUABTAGQAdgBhAHkAYwBzAGIAWABNADkATQB6AEkAdwBNAEMAbAA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBhAEcAOQB6AGQARAAwAGsASwBDAGQAMABiADIARgB6AGQA
>> "%~1" echo SABNAG4ASwBUAHQAcABaAGkAZwBoAGEARwA5AHoAZABDAGwAeQBaAFgAUgAxAGMA
>> "%~1" echo bQA0ADcAWQAyADkAdQBjADMAUQBnAFoAVwB3ADkAWgBHADkAagBkAFcAMQBsAGIA
>> "%~1" echo bgBRAHUAWQAzAEoAbABZAFgAUgBsAFIAVwB4AGwAYgBXAFYAdQBkAEMAZwBuAFoA
>> "%~1" echo RwBsADIASgB5AGsANwBaAFcAdwB1AFkAMgB4AGgAYwAzAE4ATwBZAFcAMQBsAFAA
>> "%~1" echo UwBkADAAYgAyAEYAegBkAEMAQQBuAEsAMwBSADUAYwBHAFUANwBaAFcAdwB1AGEA
>> "%~1" echo VwA1AHUAWgBYAEoASQBWAEUAMQBNAFAAUwBjADgAWQBqADQAbgBLADIAVgB6AFkA
>> "%~1" echo eQBoADAAYQBYAFIAcwBaAFMAawByAEoAegB3AHYAWQBqADQAOABjADMAQgBoAGIA
>> "%~1" echo agA0AG4ASwAyAFYAegBZAHkAaAB0AGMAMgBkADgAZgBDAGMAbgBLAFMAcwBuAFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGkAYwA3AGEARwA5AHoAZABDADUAaABjAEgAQgBsAGIA
>> "%~1" echo bQBSAEQAYQBHAGwAcwBaAEMAaABsAGIAQwBrADcAYwBtAFYAeABkAFcAVgB6AGQA
>> "%~1" echo RQBGAHUAYQBXADEAaABkAEcAbAB2AGIAawBaAHkAWQBXADEAbABLAEMAZwBwAFAA
>> "%~1" echo VAA1AGwAYgBDADUAagBiAEcARgB6AGMAMAB4AHAAYwAzAFEAdQBZAFcAUgBrAEsA
>> "%~1" echo QwBkAHoAYQBHADkAMwBKAHkAawBwAE8AMwBOAGwAZABGAFIAcABiAFcAVgB2AGQA
>> "%~1" echo WABRAG8ASwBDAGsAOQBQAG4AdABsAGIAQwA1AGoAYgBHAEYAegBjADAAeABwAGMA
>> "%~1" echo MwBRAHUAYwBtAFYAdABiADMAWgBsAEsAQwBkAHoAYQBHADkAMwBKAHkAawA3AGMA
>> "%~1" echo MgBWADAAVgBHAGwAdABaAFcAOQAxAGQAQwBnAG8ASwBUADAAKwBaAFcAdwB1AGMA
>> "%~1" echo bQBWAHQAYgAzAFoAbABLAEMAawBzAE0AagBJAHcASwBYADAAcwBiAFgATQBwAGYA
>> "%~1" echo UQBwAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHoAYQBHADkAMwBRADIAOQB1AFoA
>> "%~1" echo bQBsAHkAYgBTAGgAaABZADMAUgBwAGIAMgA0AHMAYgBHAEYAaQBaAFcAdwBzAFoA
>> "%~1" echo WABoADAAYwBtAEUAOQBKAHkAYwBwAGUAMwBCAGwAYgBtAFIAcABiAG0AZABEAGIA
>> "%~1" echo MgA1AG0AYQBYAEoAdABQAFgAdABoAFkAMwBSAHAAYgAyADQAcwBiAEcARgBpAFoA
>> "%~1" echo VwB3AHMAWgBYAGgAMABjAG0ARgA5AE8AeQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAxAFUAYQBYAFIAcwBaAFMAYwBwAEwAbgBSAGwAZQBIAFIARABiADIANQAwAFoA
>> "%~1" echo VwA1ADAAUABTAGYAbgBvAGEANwBvAHIAcQBUAG0AaQBhAGYAbwBvAFkAegB2AHYA
>> "%~1" echo SgBvAG4ASwAyAHgAaABZAG0AVgBzAE8AeQBRAG8ASgAyAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAxAE4AYwAyAGMAbgBLAFMANQAwAFoAWABoADAAUQAyADkAdQBkAEcAVgB1AGQA
>> "%~1" echo RAAxAGoAYgAyADUAbQBhAFgASgB0AFYARwBWADQAZABGAHQAaABZADMAUgBwAGIA
>> "%~1" echo MgA1AGQAZgBIAHcAbgA2AEwAKwBaADUATABpAHEANQBwAE8ATgA1AEwAMgBjADUA
>> "%~1" echo TAB5AGEANQBMACsAdQA1AHAAUwA1AEkARgBGADEAWgBYAE4AMABJAE8AZQBLAHQA
>> "%~1" echo dQBhAEEAZwBlAE8AQQBnAGkAYwA3AEoAQwBnAG4AWQAyADkAdQBaAG0AbAB5AGIA
>> "%~1" echo VQAxAGgAYwAyAHMAbgBLAFMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AFkA
>> "%~1" echo VwBSAGsASwBDAGQAegBhAEcAOQAzAEoAeQBsADkAQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAE4AcwBiADMATgBsAFEAMgA5AHUAWgBtAGwAeQBiAFMAZwBwAGUA
>> "%~1" echo MwBCAGwAYgBtAFIAcABiAG0AZABEAGIAMgA1AG0AYQBYAEoAdABQAFcANQAxAGIA
>> "%~1" echo RwB3ADcASgBDAGcAbgBZADIAOQB1AFoAbQBsAHkAYgBVADEAaABjADIAcwBuAEsA
>> "%~1" echo UwA1AGoAYgBHAEYAegBjADAAeABwAGMAMwBRAHUAYwBtAFYAdABiADMAWgBsAEsA
>> "%~1" echo QwBkAHoAYQBHADkAMwBKAHkAbAA5AEMAbQBaADEAYgBtAE4AMABhAFcAOQB1AEkA
>> "%~1" echo SABSAG8AWgBXADEAbABLAEMAbAA3AFkAMgA5AHUAYwAzAFEAZwBiAEcAbABuAGEA
>> "%~1" echo SABRADkAYgBHADkAagBZAFcAeABUAGQARwA5AHkAWQBXAGQAbABMAG0AZABsAGQA
>> "%~1" echo RQBsADAAWgBXADAAbwBkAEcAaABsAGIAVwBWAEwAWgBYAGsAcABQAFQAMAA5AEoA
>> "%~1" echo MgB4AHAAWgAyAGgAMABKAHoAdABrAGIAMgBOADEAYgBXAFYAdQBkAEMANQBpAGIA
>> "%~1" echo MgBSADUATABtAE4AcwBZAFgATgB6AFQARwBsAHoAZABDADUAMABiADIAZABuAGIA
>> "%~1" echo RwBVAG8ASgAyAFIAaABjAG0AcwBuAEwAQwBGAHMAYQBXAGQAbwBkAEMAawA3AEoA
>> "%~1" echo QwBnAG4AZABHAGgAbABiAFcAVgBDAGQARwA0AG4ASwBTADUAMABaAFgAaAAwAFEA
>> "%~1" echo MgA5AHUAZABHAFYAdQBkAEQAMQBzAGEAVwBkAG8AZABEADgAbgA1AHIAZQB4ADYA
>> "%~1" echo SQBtAHkASgB6AG8AbgA1AHIAVwBGADYASQBtAHkASgAzADAASwBaAG4AVgB1AFkA
>> "%~1" echo MwBSAHAAYgAyADQAZwBiAEcAOQBuAEsASABRAHAAZQAzAE4AbABkAEMAZwBuAGIA
>> "%~1" echo RwA5AG4AUQBtADkANABKAHkAeAB1AFoAWABjAGcAUgBHAEYAMABaAFMAZwBwAEwA
>> "%~1" echo bgBSAHYAVABHADkAagBZAFcAeABsAFYARwBsAHQAWgBWAE4AMABjAG0AbAB1AFoA
>> "%~1" echo eQBnAHAASwB5AGMAZwBJAEMAYwByAGQAQwBsADkAQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBIAE4AbwBiADMASgAwAFUARwBGADAAYQBDAGgAdwBLAFgAdABwAFoA
>> "%~1" echo aQBnAGgAYwBDAGwAeQBaAFgAUgAxAGMAbQA0AG4AWQBXAFIAaQBMAG0AVgA0AFoA
>> "%~1" echo UwBjADcAWQAyADkAdQBjADMAUQBnAFkAVAAxAHcATABuAE4AdwBiAEcAbAAwAEsA
>> "%~1" echo QwA5AGIAWABGAHcAdgBYAFMAOABwAE8AMwBKAGwAZABIAFYAeQBiAGkAQgBoAFcA
>> "%~1" echo MgBFAHUAYgBHAFYAdQBaADMAUgBvAEwAVABGAGQAZgBIAHgAdwBmAFEAcABtAGQA
>> "%~1" echo VwA1AGoAZABHAGwAdgBiAGkAQgB3AFkAMwBRAG8AZQBDAHgAdABZAFgAZwA5AE0A
>> "%~1" echo VABBAHcASwBYAHQAagBiADIANQB6AGQAQwBCAHUAUABYAEIAaABjAG4ATgBsAFIA
>> "%~1" echo bQB4AHYAWQBYAFEAbwBlAEMAawA3AGMAbQBWADAAZABYAEoAdQBJAEcAbAB6AFIA
>> "%~1" echo bQBsAHUAYQBYAFIAbABLAEcANABwAFAAMAAxAGgAZABHAGcAdQBiAFcARgA0AEsA
>> "%~1" echo RABBAHMAVABXAEYAMABhAEMANQB0AGEAVwA0AG8ATQBUAEEAdwBMAEcANAB2AGIA
>> "%~1" echo VwBGADQASwBqAEUAdwBNAEMAawBwAE8AagBCADkAQwBtAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBIAEoAcABiAG0AYwBvAGEAVwBRAHMAZABHAFYANABkAEMAeABzAFkA
>> "%~1" echo VwBKAGwAYgBDAHgAdwBMAEcAMQB2AFoARwBVAHAAZQAyAE4AdgBiAG4ATgAwAEkA
>> "%~1" echo RwBKAHYAZQBEADAAawBLAEcAbABrAEsAUwB4AHQAUABXAEoAdgBlAEMAWQBtAFkA
>> "%~1" echo bQA5ADQATABuAEYAMQBaAFgASgA1AFUAMgBWAHMAWgBXAE4AMABiADMASQBvAEoA
>> "%~1" echo eQA1AHQAWgBYAFIAbABjAGkAYwBwAE8AMgBsAG0ASwBDAEYAaQBiADMAaAA4AGYA
>> "%~1" echo QwBGAHQASwBYAEoAbABkAEgAVgB5AGIAagB0AHQATABuAE4AbABkAEUARgAwAGQA
>> "%~1" echo SABKAHAAWQBuAFYAMABaAFMAZwBuAGMAMwBSAHkAYgAyAHQAbABMAFcAUgBoAGMA
>> "%~1" echo MgBoAGgAYwBuAEoAaABlAFMAYwBzAFQAVwBGADAAYQBDADUAeQBiADMAVgB1AFoA
>> "%~1" echo QwBoAHcASwBTAHMAbgBJAEQARQB3AE0AQwBjAHAATwAyAEoAdgBlAEMANQBqAGIA
>> "%~1" echo RwBGAHoAYwAwAHgAcABjADMAUQB1AGMAbQBWAHQAYgAzAFoAbABLAEMAZABuAGMA
>> "%~1" echo bQBWAGwAYgBpAGMAcwBKADIARgB0AFkAbQBWAHkASgB5AHcAbgBjAG0AVgBrAEoA
>> "%~1" echo eQBrADcAYQBXAFkAbwBiAFcAOQBrAFoAUwBsAGkAYgAzAGcAdQBZADIAeABoAGMA
>> "%~1" echo MwBOAE0AYQBYAE4AMABMAG0ARgBrAFoAQwBoAHQAYgAyAFIAbABLAFQAdABwAFoA
>> "%~1" echo aQBoAHAAWgBEADAAOQBQAFMAZABpAFkAWABSADAAWgBYAEoANQBSADIARgAxAFoA
>> "%~1" echo MgBVAG4ASwBYAHQAegBaAFgAUQBvAEoAMgBKAGgAZABIAFIAbABjAG4AbABVAFoA
>> "%~1" echo WABoADAASgB5AHgAMABaAFgAaAAwAEsAVAB0AHoAWgBYAFEAbwBKADIASgBoAGQA
>> "%~1" echo SABSAGwAYwBuAGwAVABkAFcASQBuAEwARwB4AGgAWQBtAFYAcwBLAFgAMQBwAFoA
>> "%~1" echo aQBoAHAAWgBEADAAOQBQAFMAZAAwAFoAVwAxAHcAUgAyAEYAMQBaADIAVQBuAEsA
>> "%~1" echo WAB0AHoAWgBYAFEAbwBKADMAUgBsAGIAWABCAFUAWgBYAGgAMABKAHkAeAAwAFoA
>> "%~1" echo WABoADAASwBUAHQAegBaAFgAUQBvAEoAMwBSAGwAYgBYAEIAVABkAFcASQBuAEwA
>> "%~1" echo RwB4AGgAWQBtAFYAcwBLAFgAMQBwAFoAaQBoAHAAWgBEADAAOQBQAFMAZAB6AGIA
>> "%~1" echo RwBWAGwAYwBFAGQAaABkAFcAZABsAEoAeQBsADcAYwAyAFYAMABLAEMAZAB6AGIA
>> "%~1" echo RwBWAGwAYwBGAFIAbABlAEgAUQBuAEwASABSAGwAZQBIAFEAcABPADMATgBsAGQA
>> "%~1" echo QwBnAG4AYwAyAHgAbABaAFgAQgBUAGQAVwBJAG4ATABHAHgAaABZAG0AVgBzAEsA
>> "%~1" echo WAAxADkAQwBtAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBHADUAdgBjAG0AMABvAGQA
>> "%~1" echo aQBsADcAYwBtAFYAMABkAFgASgB1AEkASABOAG8AYgAzAGQAdQBLAEgAWQBwAEwA
>> "%~1" echo bgBSAHkAYQBXADAAbwBLAFgAMABLAFoAbgBWAHUAWQAzAFIAcABiADIANABnAGEA
>> "%~1" echo WABOAFQAWQBXAFoAbABWAG0ARgBzAGQAVwBVAG8AWgBHAFYAbQBMAEgAWgBoAGIA
>> "%~1" echo SABWAGwASwBYAHQAagBiADIANQB6AGQAQwBCADIAWQBXAHcAOQBiAG0AOQB5AGIA
>> "%~1" echo UwBoADIAWQBXAHgAMQBaAFMAawA3AGEAVwBZAG8AWgBHAFYAbQBMAG4ATgBoAFoA
>> "%~1" echo bQBVADkAUABUADAAbgBiAG4AVgBzAGIAQwBjAHAAYwBtAFYAMABkAFgASgB1AEkA
>> "%~1" echo SABaAGgAYgBEADAAOQBQAFMAZAB1AGQAVwB4AHMASgAzAHgAOABkAG0ARgBzAFAA
>> "%~1" echo VAAwADkASgB5ADAAbgBPADMASgBsAGQASABWAHkAYgBpAEIAMgBZAFcAdwA5AFAA
>> "%~1" echo VAAxAGsAWgBXAFkAdQBjADIARgBtAFoAWAAwAEsAWgBuAFYAdQBZADMAUgBwAGIA
>> "%~1" echo MgA0AGcAYwBtAFYAdQBaAEcAVgB5AFUARwBGAHkAWQBXADEAegBLAEMAbAA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBhAEcAOQB6AGQARAAwAGsASwBDAGQAdwBZAFgASgBoAGIA
>> "%~1" echo VQB4AHAAYwAzAFEAbgBLAFQAdABwAFoAaQBnAGgAYQBHADkAegBkAEMAbAB5AFoA
>> "%~1" echo WABSADEAYwBtADQANwBhAEcAOQB6AGQAQwA1AHAAYgBtADUAbABjAGsAaABVAFQA
>> "%~1" echo VQB3ADkASgB5AGMANwBiAEcAVgAwAEkARwBOAG8AWQBXADUAbgBaAFcAUQA5AE0A
>> "%~1" echo RAB0AGoAYgAyADUAegBkAEMAQgB2AFoAbQBaAHMAYQBXADUAbABQAFcAeABoAGMA
>> "%~1" echo MwBRAHUAWQAyADkAdQBiAG0AVgBqAGQARwBWAGsASQBUADAAOQBKADMAUgB5AGQA
>> "%~1" echo VwBVAG4ATwAzAEIAaABjAG0ARgB0AFIARwBWAG0AYwB5ADUAbQBiADMASgBGAFkA
>> "%~1" echo VwBOAG8ASwBHAFIAbABaAGoAMAArAGUAMgBOAHYAYgBuAE4AMABJAEgAWgBoAGIA
>> "%~1" echo RAAxAHUAYgAzAEoAdABLAEcAeABoAGMAMwBSAGIAWgBHAFYAbQBMAG0AdABsAGUA
>> "%~1" echo VgAwAHAATwAyAE4AdgBiAG4ATgAwAEkARwA5AHIAUABTAEYAdgBaAG0AWgBzAGEA
>> "%~1" echo VwA1AGwASgBpAFoAcABjADEATgBoAFoAbQBWAFcAWQBXAHgAMQBaAFMAaABrAFoA
>> "%~1" echo VwBZAHMAZABtAEYAcwBLAFQAdABwAFoAaQBnAGgAYgAyAHMAbQBKAGkARgB2AFoA
>> "%~1" echo bQBaAHMAYQBXADUAbABLAFcATgBvAFkAVwA1AG4AWgBXAFEAcgBLAHoAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAcABkAEcAVgB0AFAAVwBSAHYAWQAzAFYAdABaAFcANQAwAEwA
>> "%~1" echo bQBOAHkAWgBXAEYAMABaAFUAVgBzAFoAVwAxAGwAYgBuAFEAbwBKADIAUgBwAGQA
>> "%~1" echo aQBjAHAATwAyAGwAMABaAFcAMAB1AFkAMgB4AGgAYwAzAE4ATwBZAFcAMQBsAFAA
>> "%~1" echo UwBkAHcAWQBYAEoAaABiAFUAbAAwAFoAVwAwAGcASgB5AHMAbwBiADIAWgBtAGIA
>> "%~1" echo RwBsAHUAWgBUADgAbgBKAHoAcAB2AGEAegA4AG4AYgAyAHMAbgBPAGkAZABqAGEA
>> "%~1" echo RwBGAHUAWgAyAFYAawBKAHkAawA3AFkAMgA5AHUAYwAzAFEAZwBjADMAUgBoAGQA
>> "%~1" echo RwBVADkAYgAyAFoAbQBiAEcAbAB1AFoAVAA4AG4ANQBwAHkAcQA2AEsAKwA3ADUA
>> "%~1" echo WQArAFcASgB6AG8AbwBiADIAcwAvAEoAKwBtADcAbQBPAGkAdQBwAE8AVwBBAHYA
>> "%~1" echo QwBjADYASgArAFcAMwBzAHUAUwAvAHIAdQBhAFUAdQBTAGMAcABPADIAbAAwAFoA
>> "%~1" echo VwAwAHUAYQBXADUAdQBaAFgASgBJAFYARQAxAE0AUABTAGMAOABaAEcAbAAyAEkA
>> "%~1" echo RwBOAHMAWQBYAE4AegBQAFYAdwBpAGMARwBGAHkAWQBXADEATwBZAFcAMQBsAFgA
>> "%~1" echo QwBJACsAUABHAEkAKwBKAHkAdABsAGMAMgBNAG8AWgBHAFYAbQBMAG0ANQBoAGIA
>> "%~1" echo VwBVAHAASwB5AGMAOABMADIASQArAFAASABOAHcAWQBXADQAKwBKAHkAdABsAGMA
>> "%~1" echo MgBNAG8AWgBHAFYAbQBMAG4ATgBsAGQASABSAHAAYgBtAGMAcABLAHkAYwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEMAOQBrAGEAWABZACsAUABHAFIAcABkAGkAQgBqAGIA
>> "%~1" echo RwBGAHoAYwB6ADEAYwBJAG4AQgBoAGMAbQBGAHQAVgBtAEYAcwBkAFcAVgBjAEkA
>> "%~1" echo agA0ADgAYwAzAEIAaABiAGoANwBsAHYAWgBQAGwAaQBZADMAbABnAEwAdwA4AEwA
>> "%~1" echo MwBOAHcAWQBXADQAKwBQAEcASQArAEoAeQB0AGwAYwAyAE0AbwBkAG0ARgBzAEsA
>> "%~1" echo UwBzAG4AUABDADkAaQBQAGoAdwB2AFoARwBsADIAUABqAHgAawBhAFgAWQBnAFkA
>> "%~1" echo MgB4AGgAYwAzAE0AOQBYAEMASgB3AFkAWABKAGgAYgBWAFoAaABiAEgAVgBsAFgA
>> "%~1" echo QwBJACsAUABIAE4AdwBZAFcANAArADYAYgB1AFkANgBLADYAawA1AFkAQwA4AFAA
>> "%~1" echo QwA5AHoAYwBHAEYAdQBQAGoAeABpAFAAaQBjAHIAWgBYAE4AagBLAEcAUgBsAFoA
>> "%~1" echo aQA1AHoAWQBXAFoAbABLAFMAcwBuAFAAQwA5AGkAUABqAHcAdgBaAEcAbAAyAFAA
>> "%~1" echo agB4AGsAYQBYAFkAKwBQAEgATgB3AFkAVwA0AGcAWQAyAHgAaABjADMATQA5AFgA
>> "%~1" echo QwBKAHcAWQBYAEoAaABiAFYATgAwAFkAWABSAGwAWABDAEkAKwBKAHkAdABsAGMA
>> "%~1" echo MgBNAG8AYwAzAFIAaABkAEcAVQBwAEsAeQBjADgATAAzAE4AdwBZAFcANAArAEkA
>> "%~1" echo QwBjAHIASwBDAEYAdgBaAG0AWgBzAGEAVwA1AGwASgBpAFkAaABiADIAcwAvAEoA
>> "%~1" echo egB4AGkAZABYAFIAMABiADIANABnAFkAMgB4AGgAYwAzAE0AOQBYAEMASgB5AFoA
>> "%~1" echo WABOAGwAZABFAEoAMABiAGkAQgB3AGMAbQBsAHQAWQBYAEoANQBYAEMASQBnAFoA
>> "%~1" echo RwBGADAAWQBTADEAeQBaAFgATgBsAGQARAAxAGMASQBpAGMAcgBaAFgATgBqAEsA
>> "%~1" echo RwBSAGwAWgBpADUAaABZADMAUgBwAGIAMgA0AHAASwB5AGQAYwBJAGoANwBwAGgA
>> "%~1" echo NAAzAG4AdgBhADQAOABMADIASgAxAGQASABSAHYAYgBqADQAbgBPAGkAYwBuAEsA
>> "%~1" echo UwBzAG4AUABDADkAawBhAFgAWQArAFAARwBSAHAAZABpAEIAagBiAEcARgB6AGMA
>> "%~1" echo egAxAGMASQBuAEIAaABjAG0ARgB0AFQAbQBGAHQAWgBWAHcAaQBJAEgATgAwAGUA
>> "%~1" echo VwB4AGwAUABWAHcAaQBaADMASgBwAFoAQwAxAGoAYgAyAHgAMQBiAFcANAA2AE0A
>> "%~1" echo UwA4AHQATQBWAHcAaQBQAGoAeAB6AGMARwBGAHUAUABpAGMAcgBaAFgATgBqAEsA
>> "%~1" echo RwBSAGwAWgBpADUAdQBiADMAUgBsAEsAUwBzAG4AUABDADkAegBjAEcARgB1AFAA
>> "%~1" echo agB3AHYAWgBHAGwAMgBQAGkAYwA3AGEARwA5AHoAZABDADUAaABjAEgAQgBsAGIA
>> "%~1" echo bQBSAEQAYQBHAGwAcwBaAEMAaABwAGQARwBWAHQASwBYADAAcABPADMATgBsAGQA
>> "%~1" echo QwBnAG4AYwBHAEYAeQBZAFcAMQBUAGQAVwAxAHQAWQBYAEoANQBKAHkAeAB2AFoA
>> "%~1" echo bQBaAHMAYQBXADUAbABQAHkAZgBtAG4ASwByAG8AdgA1ADcAbQBqAHEAVQBuAE8A
>> "%~1" echo bQBOAG8AWQBXADUAbgBaAFcAUQAvAFkAMgBoAGgAYgBtAGQAbABaAEMAcwBuAEkA
>> "%~1" echo TwBtAGgAdQBlAFcAMwBzAHUAUwAvAHIAdQBhAFUAdQBTAGMANgBKACsAVwBGAHEA
>> "%~1" echo TwBtAEQAcQBPAG0ANwBtAE8AaQB1AHAAQwBjAHAATwAyAGgAdgBjADMAUQB1AGMA
>> "%~1" echo WABWAGwAYwBuAGwAVABaAFcAeABsAFkAMwBSAHYAYwBrAEYAcwBiAEMAZwBuAFcA
>> "%~1" echo MgBSAGgAZABHAEUAdABjAG0AVgB6AFoAWABSAGQASgB5AGsAdQBaAG0AOQB5AFIA
>> "%~1" echo VwBGAGoAYQBDAGgAaQBkAEcANAA5AFAAbQBKADAAYgBpADUAdgBiAG0ATgBzAGEA
>> "%~1" echo VwBOAHIAUABTAGcAcABQAFQANQBoAFkAMwBSAHAAYgAyADQAbwBZAG4AUgB1AEwA
>> "%~1" echo bQBSAGgAZABHAEYAegBaAFgAUQB1AGMAbQBWAHoAWgBYAFEAcwBKAHkAYwBzAEoA
>> "%~1" echo KwBtAEgAagBlAGUAOQByAHUAVwBQAGcAdQBhAFYAcwBDAGMAcwBZAG4AUgB1AEwA
>> "%~1" echo RwBaAGgAYgBIAE4AbABLAFMAbAA5AEMAbQBGAHoAZQBXADUAagBJAEcAWgAxAGIA
>> "%~1" echo bQBOADAAYQBXADkAdQBJAEcARgB3AGEAUwBoAHcAWQBYAFIAbwBMAEcAOQB3AGQA
>> "%~1" echo SABNADkAZQAzADAAcABlADIATgB2AGIAbgBOADAASQBIAE4AbABjAEQAMQB3AFkA
>> "%~1" echo WABSAG8ATABtAGwAdQBZADIAeAAxAFoARwBWAHoASwBDAGMALwBKAHkAawAvAEoA
>> "%~1" echo eQBZAG4ATwBpAGMALwBKAHoAdABqAGIAMgA1AHoAZABDAEIAeQBQAFcARgAzAFkA
>> "%~1" echo VwBsADAASQBHAFoAbABkAEcATgBvAEsASABCAGgAZABHAGcAcgBjADIAVgB3AEsA
>> "%~1" echo eQBkADAAYgAyAHQAbABiAGoAMABuAEsAMgBWAHUAWQAyADkAawBaAFYAVgBTAFMA
>> "%~1" echo VQBOAHYAYgBYAEIAdgBiAG0AVgB1AGQAQwBoAFUAVAAwAHQARgBUAGkAawBzAFQA
>> "%~1" echo MgBKAHEAWgBXAE4AMABMAG0ARgB6AGMAMgBsAG4AYgBpAGgANwBZADIARgBqAGEA
>> "%~1" echo RwBVADYASgAyADUAdgBMAFgATgAwAGIAMwBKAGwASgAzADAAcwBiADMAQgAwAGMA
>> "%~1" echo eQBrAHAATwAyAGwAbQBLAEMARgB5AEwAbQA5AHIASwBYAFIAbwBjAG0AOQAzAEkA
>> "%~1" echo RwA1AGwAZAB5AEIARgBjAG4ASgB2AGMAaQBnAG4AUwBGAFIAVQBVAEMAQQBuAEsA
>> "%~1" echo MwBJAHUAYwAzAFIAaABkAEgAVgB6AEsAVAB0AHkAWgBYAFIAMQBjAG0ANABnAFkA
>> "%~1" echo WABkAGgAYQBYAFEAZwBjAGkANQBxAGMAMgA5AHUASwBDAGwAOQBDAG0ARgB6AGUA
>> "%~1" echo VwA1AGoASQBHAFoAMQBiAG0ATgAwAGEAVwA5AHUASQBHAHgAdgBZAFcAUgBNAGIA
>> "%~1" echo MgBkAHoASwBIAE4AbwBiADMAZABPAGIAMwBSAHAAWQAyAFUAOQBaAG0ARgBzAGMA
>> "%~1" echo MgBVAHAAZQAzAFIAeQBlAFgAdABqAGIAMgA1AHoAZABDAEIAeQBQAFcARgAzAFkA
>> "%~1" echo VwBsADAASQBHAEYAdwBhAFMAZwBuAEwAMgBGAHcAYQBTADkAcwBiADIAZAB6AEoA
>> "%~1" echo eQBrADcAYwAyAFYAMABLAEMAZABzAGIAMgBkAFEAWQBYAFIAbwBKAHkAeAB5AEwA
>> "%~1" echo bQB4AHYAWgAwAFoAcABiAEcAVQBwAE8AMwBOAGwAZABDAGcAbgBiAEcAOQBuAFEA
>> "%~1" echo bQA5ADQASgB5AHgAeQBMAG4AUgBsAGUASABSADgAZgBDAGYAbQBtAG8ATABtAGwA
>> "%~1" echo NgBEAG0AbAA2AFgAbAB2ADUAYwBuAEsAVAB0AHAAWgBpAGgAegBhAEcAOQAzAFQA
>> "%~1" echo bQA5ADAAYQBXAE4AbABLAFcANQB2AGQARwBsAG0AZQBTAGcAbgA1AHAAZQBsADUA
>> "%~1" echo YgArAFgANQBiAGUAeQA1AFkAaQAzADUAcABhAHcASgB5AHgAeQBMAG0AeAB2AFoA
>> "%~1" echo MABaAHAAYgBHAFYAOABmAEMAYwB0AEoAeQB3AG4AYgAyAHMAbgBLAFgAMQBqAFkA
>> "%~1" echo WABSAGoAYQBDAGgAbABLAFgAdAB6AFoAWABRAG8ASgAyAHgAdgBaADAASgB2AGUA
>> "%~1" echo QwBjAHMASgArAGEAWABwAGUAVwAvAGwAKwBpAHYAdQArAFcAUABsAHUAVwBrAHMA
>> "%~1" echo ZQBpADAAcABlACsAOABtAGkAYwByAFoAUwA1AHQAWgBYAE4AegBZAFcAZABsAEsA
>> "%~1" echo VAB0AHAAWgBpAGgAegBhAEcAOQAzAFQAbQA5ADAAYQBXAE4AbABLAFcANQB2AGQA
>> "%~1" echo RwBsAG0AZQBTAGcAbgA1AHAAZQBsADUAYgArAFgANgBLACsANwA1AFkAKwBXADUA
>> "%~1" echo YQBTAHgANgBMAFMAbABKAHkAeABsAEwAbQAxAGwAYwAzAE4AaABaADIAVQBzAEoA
>> "%~1" echo MgBWAHkAYwBpAGMAcwBOAEQASQB3AE0AQwBsADkAZgBRAHAAaABjADMAbAB1AFkA
>> "%~1" echo eQBCAG0AZABXADUAagBkAEcAbAB2AGIAaQBCAHkAWgBXAFoAeQBaAFgATgBvAEsA
>> "%~1" echo SABOAG8AYgAzAGQATwBiADMAUgBwAFkAMgBVADkAWgBtAEYAcwBjADIAVQBwAGUA
>> "%~1" echo MwBSAHkAZQBYAHQAcwBZAFgATgAwAFAAVwBGADMAWQBXAGwAMABJAEcARgB3AGEA
>> "%~1" echo UwBnAG4ATAAyAEYAdwBhAFMAOQB6AGQARwBGADAAZABYAE0AbgBLAFQAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAagBQAFcAeABoAGMAMwBRAHUAWQAyADkAdQBiAG0AVgBqAGQA
>> "%~1" echo RwBWAGsAUABUADAAOQBKADMAUgB5AGQAVwBVAG4ATwB5AFEAbwBKADMATgAwAFkA
>> "%~1" echo WABSADEAYwAwAE4AbwBhAFgAQQBuAEsAUwA1AGoAYgBHAEYAegBjADAAeABwAGMA
>> "%~1" echo MwBRAHUAZABHADkAbgBaADIAeABsAEsAQwBkAGoAYgAyADUAdQBaAFcATgAwAFoA
>> "%~1" echo VwBRAG4ATABHAE0AcABPAHkAUQBvAEoAMwBOADAAWQBYAFIAMQBjADAATgBvAGEA
>> "%~1" echo WABBAG4ASwBTADUAeABkAFcAVgB5AGUAVgBOAGwAYgBHAFYAagBkAEcAOQB5AEsA
>> "%~1" echo QwBkAHoAYwBHAEYAdQBKAHkAawB1AGQARwBWADQAZABFAE4AdgBiAG4AUgBsAGIA
>> "%~1" echo bgBRADkAWQB6ADgAbgA1AGIAZQB5ADYATAArAGUANQBvADYAbABKAHoAbwBvAGIA
>> "%~1" echo RwBGAHoAZABDADUAawBaAFgAWgBwAFkAMgBWAFQAZABHAEYAMABaAFQAMAA5AFAA
>> "%~1" echo UwBkADEAYgBtAEYAMQBkAEcAaAB2AGMAbQBsADYAWgBXAFEAbgBQAHkAZgBtAG4A
>> "%~1" echo SwByAG0AagBvAGoAbQBuAFkATQBuAE8AbQB4AGgAYwAzAFEAdQBaAEcAVgAyAGEA
>> "%~1" echo VwBOAGwAVQAzAFIAaABkAEcAVQA5AFAAVAAwAG4AYgAyAFoAbQBiAEcAbAB1AFoA
>> "%~1" echo UwBjAC8ASgArAGUAbQB1ACsAZQA2AHYAeQBjADYASgArAGEAYwBxAHUAaQAvAG4A
>> "%~1" echo dQBhAE8AcABTAGMAcABPADMATgBsAGQAQwBnAG4AYwAzAFIAaABkAEcAVgBDAGEA
>> "%~1" echo VwBjAG4ATABHAHgAaABjADMAUQB1AFoARwBWADIAYQBXAE4AbABVADMAUgBoAGQA
>> "%~1" echo RwBWADgAZgBDAGQAdQBiADIANQBsAEoAeQBrADcASgBDAGcAbgBjADMAUgBoAGQA
>> "%~1" echo RwBWAEMAYQBXAGMAbgBLAFMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AGQA
>> "%~1" echo RwA5AG4AWgAyAHgAbABLAEMAZABuAGIAMgA5AGsASgB5AHgAagBLAFQAdAB6AFoA
>> "%~1" echo WABRAG8ASgAzAE4AMABZAFgAUgBsAFMARwBsAHUAZABDAGMAcwBiAEcARgB6AGQA
>> "%~1" echo QwA1AG8AYQBXADUAMABLAFQAdAB6AFoAWABRAG8ASgAyAGgAbABjAG0AOQBOAGIA
>> "%~1" echo MgBSAGwAYgBDAGMAcwBiAEcARgB6AGQAQwA1AHQAYgAyAFIAbABiAEMAWQBtAGIA
>> "%~1" echo RwBGAHoAZABDADUAdABiADIAUgBsAGIAQwBFADkAUABTAGMAdABKAHoAOQBzAFkA
>> "%~1" echo WABOADAATABtADEAdgBaAEcAVgBzAE8AaQBkAFIAZABXAFYAegBkAEMAYwBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBaAEcAVgAyAGEAVwBOAGwAVgBHAEYAbgBKAHkAeABzAFkA
>> "%~1" echo WABOADAATABtAFIAbABkAG0AbABqAFoAVgBOADAAWQBYAFIAbABmAEgAdwBuAGIA
>> "%~1" echo bQA5AHUAWgBTAGMAcABPADMATgBsAGQAQwBnAG4AWQBXAFIAaQBVADIAaAB2AGMA
>> "%~1" echo bgBRAG4ATABIAE4AbwBiADMASgAwAFUARwBGADAAYQBDAGgAcwBZAFgATgAwAEwA
>> "%~1" echo bQBGAGsAWQBsAEIAaABkAEcAZwBwAEsAVAB0AHoAWgBYAFEAbwBKADIARgBrAFkA
>> "%~1" echo bABCAGgAZABHAGgAVABhAEcAOQB5AGQAQwBjAHMAYwAyAGgAdgBjAG4AUgBRAFkA
>> "%~1" echo WABSAG8ASwBHAHgAaABjADMAUQB1AFkAVwBSAGkAVQBHAEYAMABhAEMAawBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBkADIAbABtAGEAVQBOAG8AYQBYAEEAbgBMAEgAWQBvAEoA
>> "%~1" echo MwBkAHAAWgBtAGwASgBjAEMAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADMAZABwAFoA
>> "%~1" echo bQBsAEoAYwBFAHgAcABkAEcAVQBuAEwASABZAG8ASgAzAGQAcABaAG0AbABKAGMA
>> "%~1" echo QwBjAHAASwBUAHQAegBaAFgAUQBvAEoAMgB4AGwAWgBuAFIARABiADIANQAwAGMA
>> "%~1" echo bQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQA
>> "%~1" echo SABKAHYAYgBHAHgAbABjAGsAeABsAFoAbgBSAEMAWQBYAFIAMABaAFgASgA1AEoA
>> "%~1" echo eQBrAHAATwAzAE4AbABkAEMAZwBuAGMAbQBsAG4AYQBIAFIARABiADIANQAwAGMA
>> "%~1" echo bQA5AHMAYgBHAFYAeQBUAEcAbAAwAFoAUwBjAHMAZABpAGcAbgBZADIAOQB1AGQA
>> "%~1" echo SABKAHYAYgBHAHgAbABjAGwASgBwAFoAMgBoADAAUQBtAEYAMABkAEcAVgB5AGUA
>> "%~1" echo UwBjAHAASwBUAHQAegBaAFgAUQBvAEoAMgB4AGwAWgBuAFIARABiADIANQAwAGMA
>> "%~1" echo bQA5AHMAYgBHAFYAeQBVADMAUgBoAGQARwBVAG4ATABIAFkAbwBKADIATgB2AGIA
>> "%~1" echo bgBSAHkAYgAyAHgAcwBaAFgASgBNAFoAVwBaADAAVQAzAFIAaABkAEgAVgB6AEoA
>> "%~1" echo eQBrAHAATwAzAE4AbABkAEMAZwBuAGMAbQBsAG4AYQBIAFIARABiADIANQAwAGMA
>> "%~1" echo bQA5AHMAYgBHAFYAeQBVADMAUgBoAGQARwBVAG4ATABIAFkAbwBKADIATgB2AGIA
>> "%~1" echo bgBSAHkAYgAyAHgAcwBaAFgASgBTAGEAVwBkAG8AZABGAE4AMABZAFgAUgAxAGMA
>> "%~1" echo eQBjAHAASwBUAHQAegBaAFgAUQBvAEoAMwBOAHYAWQAwAHgAcABkAEcAVQBuAEwA
>> "%~1" echo SABZAG8ASgAzAE4AdgBZAHkAYwBwAEsAVAB0AHoAWgBYAFEAbwBKADIAUgBwAGMA
>> "%~1" echo MwBCAHMAWQBYAGwAVABkAFcAMQB0AFkAWABKADUAVABHAGwAMABaAFMAYwBzAGQA
>> "%~1" echo aQBnAG4AWgBHAGwAegBjAEcAeABoAGUAVgBOADEAYgBXADEAaABjAG4AawBuAEsA
>> "%~1" echo UwBrADcAYwAyAFYAMABLAEMAZAAwAGEARwBWAHkAYgBXAEYAcwBVADMAVgB0AGIA
>> "%~1" echo VwBGAHkAZQBVAHgAcABkAEcAVQBuAEwASABZAG8ASgAzAFIAbwBaAFgASgB0AFkA
>> "%~1" echo VwB4AFQAZABXADEAdABZAFgASgA1AEoAeQBrAHAATwAzAE4AbABkAEMAZwBuAFoA
>> "%~1" echo bQBGAGoAZABHADkAeQBlAFYATgAxAGIAVwAxAGgAYwBuAGwATQBhAFgAUgBsAEoA
>> "%~1" echo eQB4ADIASwBDAGQAbQBZAFcATgAwAGIAMwBKADUAVQAzAFYAdABiAFcARgB5AGUA
>> "%~1" echo UwBjAHAASwBUAHQAegBaAFgAUQBvAEoAMgBOAHMAYgAyAE4AcgBWAEcAVgA0AGQA
>> "%~1" echo QwBjAHMAYgBtAFYAMwBJAEUAUgBoAGQARwBVAG8ASwBTADUAMABiADAAeAB2AFkA
>> "%~1" echo MgBGAHMAWgBWAFIAcABiAFcAVgBUAGQASABKAHAAYgBtAGMAbwBLAFMAawA3AFkA
>> "%~1" echo MgA5AHUAYwAzAFEAZwBZAGoAMQAyAEsAQwBkAGkAWQBYAFIAMABaAFgASgA1AFQA
>> "%~1" echo RwBWADIAWgBXAHcAbgBLAFMAeAAwAFAAWABZAG8ASgAyAEoAaABkAEgAUgBsAGMA
>> "%~1" echo bgBsAFUAWgBXADEAdwBKAHkAawBzAGQAegAxADIASwBDAGQAMwBZAFcAdABsAFoA
>> "%~1" echo bgBWAHMAYgBtAFYAegBjAHkAYwBwAEwARwBKAHUAUABYAEIAaABjAG4ATgBsAFIA
>> "%~1" echo bQB4AHYAWQBYAFEAbwBZAGkAawBzAGQARwA0ADkAYwBHAEYAeQBjADIAVgBHAGIA
>> "%~1" echo RwA5AGgAZABDAGgAMABLAFQAdAB5AGEAVwA1AG4ASwBDAGQAaQBZAFgAUgAwAFoA
>> "%~1" echo WABKADUAUgAyAEYAMQBaADIAVQBuAEwARwBJADkAUABUADAAbgBMAFMAYwAvAEoA
>> "%~1" echo eQAwAHQASgBTAGMANgBZAGkAcwBuAEoAUwBjAHMASgArAGUAVQB0AGUAbQBIAGoA
>> "%~1" echo eQBjAHMAYwBHAE4AMABLAEcASQBwAEwAQwBGAHAAYwAwAFoAcABiAG0AbAAwAFoA
>> "%~1" echo UwBoAGkAYgBpAGsALwBKAHkAYwA2AFkAbQA0ADgATQBqAEEALwBKADMASgBsAFoA
>> "%~1" echo QwBjADYAWQBtADQAOABOAEQAVQAvAEoAMgBGAHQAWQBtAFYAeQBKAHoAbwBuAFoA
>> "%~1" echo MwBKAGwAWgBXADQAbgBLAFQAdAB5AGEAVwA1AG4ASwBDAGQAMABaAFcAMQB3AFIA
>> "%~1" echo MgBGADEAWgAyAFUAbgBMAEgAUQA5AFAAVAAwAG4ATABTAGMALwBKAHkAMAB0AHcA
>> "%~1" echo cgBCAEQASgB6AHAAMABLAHkAZgBDAHMARQBNAG4ATABDAGYAbQB1AEsAbgBsAHUA
>> "%~1" echo cQBZAG4ATABIAEIAagBkAEMAaAAwAEwARABVADEASwBTAHcAaABhAFgATgBHAGEA
>> "%~1" echo VwA1AHAAZABHAFUAbwBkAEcANABwAFAAeQBjAG4ATwBuAFIAdQBQAGoAMAAwAE4A
>> "%~1" echo VAA4AG4AYwBtAFYAawBKAHoAcAAwAGIAagA0ADkATQB6AGcALwBKADIARgB0AFkA
>> "%~1" echo bQBWAHkASgB6AG8AbgBaADMASgBsAFoAVwA0AG4ASwBUAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAGgAZAAyAEYAcgBaAFQAMABvAGQAMwB4ADgASgB5AGMAcABMAG4AUgB2AFQA
>> "%~1" echo RwA5ADMAWgBYAEoARABZAFgATgBsAEsAQwBrAHUAYQBXADUAagBiAEgAVgBrAFoA
>> "%~1" echo WABNAG8ASgAyAEYAMwBZAFcAdABsAEoAeQBrADcAYwBtAGwAdQBaAHkAZwBuAGMA
>> "%~1" echo MgB4AGwAWgBYAEIASABZAFgAVgBuAFoAUwBjAHMAZAB6ADAAOQBQAFMAYwB0AEoA
>> "%~1" echo egA4AG4ATABTAGMANgBkAHkAeABzAFkAWABOADAATABtADEAVABkAEcARgA1AFQA
>> "%~1" echo MgA0ADkAUABUADAAbgBkAEgASgAxAFoAUwBjAC8ASgArAFMALwBuAGUAYQBNAGcA
>> "%~1" echo ZQBXAFUAcABPAG0ARwBrAGkAYwA2AEoAKwBTADgAawBlAGUAYwBvAEMAYwBzAFkA
>> "%~1" echo WABkAGgAYQAyAFUALwBNAFQAQQB3AE8AagBJADQATABHAEYAMwBZAFcAdABsAFAA
>> "%~1" echo eQBkAGgAYgBXAEoAbABjAGkAYwA2AEoAMgBkAHkAWgBXAFYAdQBKAHkAawA3AFQA
>> "%~1" echo MgBKAHEAWgBXAE4AMABMAG0AdABsAGUAWABNAG8AYgBHAEYAegBkAEMAawB1AFoA
>> "%~1" echo bQA5AHkAUgBXAEYAagBhAEMAaAByAFAAVAA1AHoAWgBYAFEAbwBhAHkAeABzAFkA
>> "%~1" echo WABOADAAVwAyAHQAZABLAFMAawA3AGMAMgBWADAASwBDAGQAdwBiADMAZABsAGMA
>> "%~1" echo bABOAHYAZABYAEoAagBaAFQASQBuAEwARwB4AGgAYwAzAFEAdQBjAEcAOQAzAFoA
>> "%~1" echo WABKAFQAYgAzAFYAeQBZADIAVQBwAE8AMwBOAGwAZABDAGcAbgBiAEcAOQBuAFUA
>> "%~1" echo RwBGADAAYQBDAGMAcwBiAEcARgB6AGQAQwA1AHMAYgAyAGQARwBhAFcAeABsAEsA
>> "%~1" echo VAB0AHoAWgBYAFEAbwBKADIATgB2AGIAbgBOAHYAYgBHAFYAVABkAEcARgAwAFoA
>> "%~1" echo UwBjAHMAYgBHAEYAegBkAEMANQBrAFoAWABaAHAAWQAyAFYAVABkAEcARgAwAFoA
>> "%~1" echo UwBrADcAYwAyAFYAMABLAEMAZABqAGIAMgA1AHoAYgAyAHgAbABRADIAOQB1AGIA
>> "%~1" echo aQBjAHMAWQB6ADgAbgA1AGIAZQB5ADYATAArAGUANQBvADYAbABKAHoAbwBuADUA
>> "%~1" echo cAB5AHEANgBMACsAZQA1AG8ANgBsAEoAeQBrADcAYwAyAFYAMABLAEMAZABqAGIA
>> "%~1" echo MgA1AHoAYgAyAHgAbABRAG0ARgAwAGQARwBWAHkAZQBTAGMAcwBZAGoAMAA5AFAA
>> "%~1" echo UwBjAHQASgB6ADgAbgBMAFMAYwA2AFkAaQBzAG4ASgBTAGMAcABPADMATgBsAGQA
>> "%~1" echo QwBnAG4AWQAyADkAdQBjADIAOQBzAFoAVgBkAGgAYQAyAFUAbgBMAEgAYwBwAE8A
>> "%~1" echo MwBOAGwAZABDAGcAbgBZADIAOQB1AGMAMgA5AHMAWgBWAGQAcABaAG0AawBuAEwA
>> "%~1" echo SABZAG8ASgAzAGQAcABaAG0AbABKAGMAQwBjAHAASwBUAHQAeQBaAFcANQBrAFoA
>> "%~1" echo WABKAFEAWQBYAEoAaABiAFgATQBvAEsAVAB0AHAAWgBpAGgAegBhAEcAOQAzAFQA
>> "%~1" echo bQA5ADAAYQBXAE4AbABLAFcANQB2AGQARwBsAG0AZQBTAGcAbgA1AFkAaQAzADUA
>> "%~1" echo cABhAHcANQBhADYATQA1AG8AaQBRAEoAeQB4AGoAUAB5AGYAbAB0ADcATABvAHYA
>> "%~1" echo NQA3AG0AagBxAFgAdgB2AEoAbwBuAEsAeQBoAHMAWQBYAE4AMABMAG0AMQB2AFoA
>> "%~1" echo RwBWAHMAZgBIAHcAbgBVAFgAVgBsAGMAMwBRAG4ASwBTAHMAbgA3ADcAeQBNADUA
>> "%~1" echo NQBTADEANgBZAGUAUABJAEMAYwByAFkAaQBzAG4ASgBTAGMANgBLAEcAeABoAGMA
>> "%~1" echo MwBRAHUAYQBHAGwAdQBkAEgAeAA4AEoAKwBhAGMAcQB1AGkALwBuAHUAYQBPAHAA
>> "%~1" echo UwBjAHAATABHAE0ALwBKADIAOQByAEoAegBvAG4AZAAyAEYAeQBiAGkAYwBwAGYA
>> "%~1" echo VwBOAGgAZABHAE4AbwBLAEcAVQBwAGUAMgB4AHYAWgB5AGcAbgA1AFkAaQAzADUA
>> "%~1" echo cABhAHcANQBhAFMAeAA2AEwAUwBsADcANwB5AGEASgB5AHQAbABMAG0AMQBsAGMA
>> "%~1" echo MwBOAGgAWgAyAFUAcABPADMASgBsAGIAbQBSAGwAYwBsAEIAaABjAG0ARgB0AGMA
>> "%~1" echo eQBnAHAATwAyAGwAbQBLAEgATgBvAGIAMwBkAE8AYgAzAFIAcABZADIAVQBwAGIA
>> "%~1" echo bQA5ADAAYQBXAFoANQBLAEMAZgBsAGkATABmAG0AbAByAEQAbABwAEwASABvAHQA
>> "%~1" echo SwBVAG4ATABHAFUAdQBiAFcAVgB6AGMAMgBGAG4AWgBTAHcAbgBaAFgASgB5AEoA
>> "%~1" echo eQB3ADAATQBqAEEAdwBLAFgAMQA5AEMAbQBaADEAYgBtAE4AMABhAFcAOQB1AEkA
>> "%~1" echo SABOAGwAZABFAEoAMQBjADMAawBvAGIAMgA0AHMAWQBuAFIAdQBLAFgAdABpAGQA
>> "%~1" echo WABOADUAUABXADkAdQBPADIAUgB2AFkAMwBWAHQAWgBXADUAMABMAG4ARgAxAFoA
>> "%~1" echo WABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBKAEIAYgBHAHcAbwBKADIASgAxAGQA
>> "%~1" echo SABSAHYAYgBpAGMAcABMAG0AWgB2AGMAawBWAGgAWQAyAGcAbwBZAGoAMAArAFkA
>> "%~1" echo aQA1AGsAYQBYAE4AaABZAG0AeABsAFoARAAxAHYAYgBpAGsANwBhAFcAWQBvAFkA
>> "%~1" echo bgBSAHUASwBXAEoAMABiAGkANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AGQA
>> "%~1" echo RwA5AG4AWgAyAHgAbABLAEMAZABwAGMAeQAxAGkAZABYAE4ANQBKAHkAeAB2AGIA
>> "%~1" echo aQBsADkAQwBtAEYAegBlAFcANQBqAEkARwBaADEAYgBtAE4AMABhAFcAOQB1AEkA
>> "%~1" echo RwBGAGoAZABHAGwAdgBiAGkAaABoAEwARwBWADQAZABIAEoAaABQAFMAYwBuAEwA
>> "%~1" echo RwB4AGgAWQBtAFYAcwBQAFMAZgBtAGsANAAzAGsAdgBaAHcAbgBMAEcASgAwAGIA
>> "%~1" echo agAxAHUAZABXAHgAcwBMAEcATgB2AGIAbQBaAHAAYwBtADEAbABaAEQAMQBtAFkA
>> "%~1" echo VwB4AHoAWgBTAGwANwBhAFcAWQBvAFkAbgBWAHoAZQBTAGwAeQBaAFgAUgAxAGMA
>> "%~1" echo bQA0AGcAYgBtADkAMABhAFcAWgA1AEsAQwBmAGwAdAA3AEwAbQBuAEkAbgBtAGsA
>> "%~1" echo NAAzAGsAdgBaAHoAbQBpAGEAZgBvAG8AWQB6AGsAdQBLADAAbgBMAEMAZgBvAHIA
>> "%~1" echo NwBmAG4AcgBZAG4AbAB2AG8AWABrAHUASQByAGsAdQBJAEQAbQBuAGEASABsAGsA
>> "%~1" echo YgAzAGsAdQA2AFQAbAByAG8AegBtAGkASgBEAGoAZwBJAEkAbgBMAEMAZAAzAFkA
>> "%~1" echo WABKAHUASgB5AGsANwBkAEgASgA1AGUAMwBOAGwAZABFAEoAMQBjADMAawBvAGQA
>> "%~1" echo SABKADEAWgBTAHgAaQBkAEcANABwAE8AMgB4AHYAWgB5AGcAbgA1AG8AbQBuADYA
>> "%~1" echo SwBHAE0ANQBMAGkAdAA3ADcAeQBhAEoAeQB0AHMAWQBXAEoAbABiAEMAawA3AGIA
>> "%~1" echo bQA5ADAAYQBXAFoANQBLAEcAeABoAFkAbQBWAHMATABDAGYAbQByAGEAUABsAG4A
>> "%~1" echo SwBqAGwAagA1AEgAcABnAEkASABsAGsAYgAzAGsAdQA2AFEAdQBMAGkANABuAEwA
>> "%~1" echo QwBkADMAWQBYAEoAdQBKAHkAdwB4AE8ARABBAHcASwBUAHQAcwBaAFgAUQBnAGQA
>> "%~1" echo WABKAHMAUABTAGMAdgBZAFgAQgBwAEwAMgBGAGoAZABHAGwAdgBiAGoAOQBoAFkA
>> "%~1" echo MwBSAHAAYgAyADQAOQBKAHkAdABsAGIAbQBOAHYAWgBHAFYAVgBVAGsAbABEAGIA
>> "%~1" echo MgAxAHcAYgAyADUAbABiAG4AUQBvAFkAUwBrAHIAWgBYAGgAMABjAG0ARQA3AGEA
>> "%~1" echo VwBZAG8AWQAyADkAdQBaAG0AbAB5AGIAVwBWAGsASwBYAFYAeQBiAEMAcwA5AEoA
>> "%~1" echo eQBaAGoAYgAyADUAbQBhAFgASgB0AFAAVgBsAEYAVQB5AGMANwBZADIAOQB1AGMA
>> "%~1" echo MwBRAGcAYwBqADEAaABkADIARgBwAGQAQwBCAGgAYwBHAGsAbwBkAFgASgBzAEwA
>> "%~1" echo SAB0AHQAWgBYAFIAbwBiADIAUQA2AEoAMQBCAFAAVQAxAFEAbgBmAFMAawA3AGEA
>> "%~1" echo VwBZAG8AYwBpADUAdgBhAHkARQA5AFAAUwBkADAAYwBuAFYAbABKAHkAbAAwAGEA
>> "%~1" echo SABKAHYAZAB5AEIAdQBaAFgAYwBnAFIAWABKAHkAYgAzAEkAbwBjAGkANQBsAGMA
>> "%~1" echo bgBKAHYAYwBuAHgAOABKACsAYQBUAGoAZQBTADkAbgBPAFcAawBzAGUAaQAwAHAA
>> "%~1" echo UwBjAHAATwAyAHgAdgBaAHkAaAB5AEwAbgBKAGwAYwAzAFYAcwBkAEgAeAA4AEoA
>> "%~1" echo KwBXAHUAagBPAGEASQBrAEMAYwBwAE8AMgA1AHYAZABHAGwAbQBlAFMAaABzAFkA
>> "%~1" echo VwBKAGwAYgBDAHMAbgA1AGEANgBNADUAbwBpAFEASgB5AHgAeQBMAG4ASgBsAGMA
>> "%~1" echo MwBWAHMAZABIAHgAOABKACsAVwB1AGoATwBhAEkAawBDAGMAcwBKADIAOQByAEoA
>> "%~1" echo eQBrADcAYwAyAFYAMABWAEcAbAB0AFoAVwA5ADEAZABDAGcAbwBLAFQAMAArAGUA
>> "%~1" echo MwBKAGwAWgBuAEoAbABjADIAZwBvAFoAbQBGAHMAYwAyAFUAcABPADIAeAB2AFkA
>> "%~1" echo VwBSAE0AYgAyAGQAegBLAEcAWgBoAGIASABOAGwASwBYADAAcwBOAFQAQQB3AEsA
>> "%~1" echo WAAxAGoAWQBYAFIAagBhAEMAaABsAEsAWAB0AHMAYgAyAGMAbwBKACsAYQBUAGoA
>> "%~1" echo ZQBTADkAbgBPAFcAawBzAGUAaQAwAHAAZQArADgAbQBpAGMAcgBaAFMANQB0AFoA
>> "%~1" echo WABOAHoAWQBXAGQAbABLAFQAdAB1AGIAMwBSAHAAWgBuAGsAbwBiAEcARgBpAFoA
>> "%~1" echo VwB3AHIASgArAFcAawBzAGUAaQAwAHAAUwBjAHMAWgBTADUAdABaAFgATgB6AFkA
>> "%~1" echo VwBkAGwATABDAGQAbABjAG4ASQBuAEwARABRADIATQBEAEEAcABPADIAeAB2AFkA
>> "%~1" echo VwBSAE0AYgAyAGQAegBLAEcAWgBoAGIASABOAGwASwBYADEAbQBhAFcANQBoAGIA
>> "%~1" echo RwB4ADUAZQAzAE4AbABkAEUASgAxAGMAMwBrAG8AWgBtAEYAcwBjADIAVQBzAFkA
>> "%~1" echo bgBSAHUASwBYADEAOQBDAG0ARgB6AGUAVwA1AGoASQBHAFoAMQBiAG0ATgAwAGEA
>> "%~1" echo VwA5AHUASQBHAFYANABjAEcAOQB5AGQARQBoADAAYgBXAHcAbwBLAFgAdABwAFoA
>> "%~1" echo aQBoAGkAZABYAE4ANQBLAFgASgBsAGQASABWAHkAYgBpAEIAdQBiADMAUgBwAFoA
>> "%~1" echo bgBrAG8ASgArAFcAMwBzAHUAYQBjAGkAZQBhAFQAagBlAFMAOQBuAE8AYQBKAHAA
>> "%~1" echo KwBpAGgAagBPAFMANAByAFMAYwBzAEoAKwBpAHYAdAArAGUAdABpAGUAVwArAGgA
>> "%~1" echo ZQBTADQAaQB1AFMANABnAE8AYQBkAG8AZQBXAFIAdgBlAFMANwBwAE8AVwB1AGoA
>> "%~1" echo TwBhAEkAawBPAE8AQQBnAGkAYwBzAEoAMwBkAGgAYwBtADQAbgBLAFQAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAaQBkAEcANAA5AEoAQwBnAG4AWgBYAGgAdwBiADMASgAwAFEA
>> "%~1" echo bgBSAHUASgB5AGsANwBkAEgASgA1AGUAMwBOAGwAZABFAEoAMQBjADMAawBvAGQA
>> "%~1" echo SABKADEAWgBTAHgAaQBkAEcANABwAE8AMwBOAGwAZABDAGcAbgBaAFgAaAB3AGIA
>> "%~1" echo MwBKADAAVQAzAFIAaABkAEgAVgB6AEoAeQB3AG4ANQBxADIAagA1AFoAeQBvADUA
>> "%~1" echo WQArAHEANgBLACsANwA2AFkAZQBIADYAWgB1AEcANQBhADYATQA1AHAAVwAwADYA
>> "%~1" echo SwA2ACsANQBhAFMASAA1AEwAKwBoADUAbwBHAHYANwA3AHkATQA1AFkAKwB2ADYA
>> "%~1" echo SQBPADkANgBaAHkAQQA2AEsAYQBCAEkARABFAHcATABUAFEAdwBJAE8AZQBuAGsA
>> "%~1" echo aQA0AHUATABpAGMAcABPAHkAUQBvAEoAMgBWADQAYwBHADkAeQBkAEUAeABwAGIA
>> "%~1" echo bQB0AHoASgB5AGsAdQBhAFcANQB1AFoAWABKAEkAVgBFADEATQBQAFMAYwBuAE8A
>> "%~1" echo MgA1AHYAZABHAGwAbQBlAFMAZwBuADUAYgB5AEEANQBhAGUATAA1AGEAKwA4ADUA
>> "%~1" echo WQBlADYASgB5AHcAbgA1AHEAMgBqADUAWgB5AG8ANQA1AFMAZgA1AG8AaQBRADUA
>> "%~1" echo NgBlAEIANQBwAHkASgA1AGEANgBNADUAcABXADAANQA0AG0ASQA1AFoASwBNADUA
>> "%~1" echo WQBpAEcANQBMAHEAcgA1AGEANgBKADUAWQBXAG8ANQA0AG0ASQBJAEUAaABVAFQA
>> "%~1" echo VQB3AG4ATABDAGQAMwBZAFgASgB1AEoAeQB3AHkATQBqAEEAdwBLAFQAdABqAGIA
>> "%~1" echo MgA1AHoAZABDAEIAeQBQAFcARgAzAFkAVwBsADAASQBHAEYAdwBhAFMAZwBuAEwA
>> "%~1" echo MgBGAHcAYQBTADkAbABlAEgAQgB2AGMAbgBRAC8AYgBXADkAawBaAFQAMQBpAGIA
>> "%~1" echo MwBSAG8ASgB5AHgANwBiAFcAVgAwAGEARwA5AGsATwBpAGQAUQBUADEATgBVAEoA
>> "%~1" echo MwAwAHAATwAyAGwAbQBLAEgASQB1AGIAMgBzAGgAUABUADAAbgBkAEgASgAxAFoA
>> "%~1" echo UwBjAHAAZABHAGgAeQBiADMAYwBnAGIAbQBWADMASQBFAFYAeQBjAG0AOQB5AEsA
>> "%~1" echo SABJAHUAWgBYAEoAeQBiADMASgA4AGYAQwBmAGwAcgA3AHoAbABoADcAcgBsAHAA
>> "%~1" echo TABIAG8AdABLAFUAbgBLAFQAdAB6AFoAWABRAG8ASgAyAFYANABjAEcAOQB5AGQA
>> "%~1" echo RgBOADAAWQBYAFIAMQBjAHkAYwBzAEoAKwBXAHYAdgBPAFcASAB1AHUAVwB1AGoA
>> "%~1" echo TwBhAEkAawBPACsAOABtAGkAYwByAEsASABJAHUAYwAyAFYAagBkAEcAbAB2AGIA
>> "%~1" echo awBOAHYAZABXADUAMABmAEgAdwBuAEwAUwBjAHAASwB5AGMAZwA1AEwAaQBxADYA
>> "%~1" echo WQBlAEgANgBaAHUARwA1AHEANgAxADcANwB5AE0ANgBJAEMAWAA1AHAAZQAyAEkA
>> "%~1" echo QwBjAHIAVABXAEYAMABhAEMANQB5AGIAMwBWAHUAWgBDAGcAbwBjAEcARgB5AGMA
>> "%~1" echo MgBWAEoAYgBuAFEAbwBjAGkANQBrAGQAWABKAGgAZABHAGwAdgBiAGsAMQB6AGYA
>> "%~1" echo SAB3AG4ATQBDAGMAcwBNAFQAQQBwAGYASAB3AHcASwBTADgAeABNAEQAQQB3AEsA
>> "%~1" echo UwBzAG4ASQBPAGUAbgBrAHUATwBBAGcAaQBjAHAATwB5AFEAbwBKADIAVgA0AGMA
>> "%~1" echo RwA5AHkAZABFAHgAcABiAG0AdAB6AEoAeQBrAHUAYQBXADUAdQBaAFgASgBJAFYA
>> "%~1" echo RQAxAE0AUABTAGMAOABZAFMAQgAwAFkAWABKAG4AWgBYAFEAOQBYAEMASgBmAFkA
>> "%~1" echo bQB4AGgAYgBtAHQAYwBJAGkAQgBvAGMAbQBWAG0AUABWAHcAaQBKAHkAdABsAGMA
>> "%~1" echo MgBNAG8AYwBpADUAdwBjAG0AbAAyAFkAWABSAGwAVgBYAEoAcwBLAFMAcwBuAFgA
>> "%~1" echo QwBJACsANQBvAG0AVAA1AGIAeQBBADUANgBlAEIANQBwAHkASgA1AGEANgBNADUA
>> "%~1" echo cABXADAANQA0AG0ASQBJAEUAaABVAFQAVQB3ADgATAAyAEUAKwBQAEcARQBnAGQA
>> "%~1" echo RwBGAHkAWgAyAFYAMABQAFYAdwBpAFgAMgBKAHMAWQBXADUAcgBYAEMASQBnAGEA
>> "%~1" echo SABKAGwAWgBqADEAYwBJAGkAYwByAFoAWABOAGoASwBIAEkAdQBjADIARgBtAFoA
>> "%~1" echo VgBWAHkAYgBDAGsAcgBKADEAdwBpAFAAdQBhAEoAawArAFcAOABnAE8AVwBJAGgA
>> "%~1" echo dQBTADYAcQArAFcAdQBpAGUAVwBGAHEATwBlAEoAaQBDAEIASQBWAEUAMQBNAFAA
>> "%~1" echo QwA5AGgAUABqAHgAegBjAEcARgB1AFAAaQBjAHIAWgBYAE4AagBLAEgASQB1AGMA
>> "%~1" echo MgBGAG0AWgBWAEIAaABkAEcAaAA4AGYAQwBjAG4ASwBTAHMAbgBQAEMAOQB6AGMA
>> "%~1" echo RwBGAHUAUABpAGMANwBiAG0AOQAwAGEAVwBaADUASwBDAGYAbAByADcAegBsAGgA
>> "%~1" echo NwByAGwAcgBvAHoAbQBpAEoAQQBuAEwAQwBmAGwAdAA3AEwAbgBsAEoALwBtAGkA
>> "%~1" echo SgBEAGsAdQBLAFQAawB1ADcAMABnAFMARgBSAE4AVABDAEQAbQBpAHEAWABsAGsA
>> "%~1" echo WQBvAG4ATABDAGQAdgBhAHkAYwBwAE8AMgB4AHYAWQBXAFIATQBiADIAZAB6AEsA
>> "%~1" echo RwBaAGgAYgBIAE4AbABLAFgAMQBqAFkAWABSAGoAYQBDAGgAbABLAFgAdAB6AFoA
>> "%~1" echo WABRAG8ASgAyAFYANABjAEcAOQB5AGQARgBOADAAWQBYAFIAMQBjAHkAYwBzAEoA
>> "%~1" echo KwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABlACsAOABtAGkAYwByAFoA
>> "%~1" echo UwA1AHQAWgBYAE4AegBZAFcAZABsAEsAVAB0AHUAYgAzAFIAcABaAG4AawBvAEoA
>> "%~1" echo KwBXAHYAdgBPAFcASAB1AHUAVwBrAHMAZQBpADAAcABTAGMAcwBaAFMANQB0AFoA
>> "%~1" echo WABOAHoAWQBXAGQAbABMAEMAZABsAGMAbgBJAG4ATABEAFUAeQBNAEQAQQBwAE8A
>> "%~1" echo MgB4AHYAWQBXAFIATQBiADIAZAB6AEsARwBaAGgAYgBIAE4AbABLAFgAMQBtAGEA
>> "%~1" echo VwA1AGgAYgBHAHgANQBlADMATgBsAGQARQBKADEAYwAzAGsAbwBaAG0ARgBzAGMA
>> "%~1" echo MgBVAHMAWQBuAFIAdQBLAFgAMQA5AEMAbQBSAHYAWQAzAFYAdABaAFcANQAwAEwA
>> "%~1" echo bgBGADEAWgBYAEoANQBVADIAVgBzAFoAVwBOADAAYgAzAEoAQgBiAEcAdwBvAEoA
>> "%~1" echo MQB0AGsAWQBYAFIAaABMAFcARgBqAGQARwBsAHYAYgBsADAAbgBLAFMANQBtAGIA
>> "%~1" echo MwBKAEYAWQBXAE4AbwBLAEcASQA5AFAAbQBJAHUAYgAyADUAagBiAEcAbABqAGEA
>> "%~1" echo egAwAG8ASwBUADAAKwBlADIATgB2AGIAbgBOADAASQBHAHgAaABZAG0AVgBzAFAA
>> "%~1" echo VwBJAHUAYwBYAFYAbABjAG4AbABUAFoAVwB4AGwAWQAzAFIAdgBjAGkAZwBuAFkA
>> "%~1" echo aQBjAHAAUAB5ADUAMABaAFgAaAAwAFEAMgA5AHUAZABHAFYAdQBkAEgAeAA4AFkA
>> "%~1" echo aQA1AGsAWQBYAFIAaABjADIAVgAwAEwAbQBGAGoAZABHAGwAdgBiAGoAdABwAFoA
>> "%~1" echo aQBoAGkATABtAE4AcwBZAFgATgB6AFQARwBsAHoAZABDADUAagBiADIANQAwAFkA
>> "%~1" echo VwBsAHUAYwB5AGcAbgBaAEcARgB1AFoAMgBWAHkAUQBXAE4AMABhAFcAOQB1AEoA
>> "%~1" echo eQBrAHAAYwAyAGgAdgBkADAATgB2AGIAbQBaAHAAYwBtADAAbwBZAGkANQBrAFkA
>> "%~1" echo WABSAGgAYwAyAFYAMABMAG0ARgBqAGQARwBsAHYAYgBpAHgAcwBZAFcASgBsAGIA
>> "%~1" echo QwB3AG4ASgB5AGsANwBaAFcAeAB6AFoAUwBCAGgAWQAzAFIAcABiADIANABvAFkA
>> "%~1" echo aQA1AGsAWQBYAFIAaABjADIAVgAwAEwAbQBGAGoAZABHAGwAdgBiAGkAdwBuAEoA
>> "%~1" echo eQB4AHMAWQBXAEoAbABiAEMAeABpAEwARwBaAGgAYgBIAE4AbABLAFgAMABwAE8A
>> "%~1" echo dwBvAGsASwBDAGQAagBiADIANQBtAGEAWABKAHQAUQAyAEYAdQBZADIAVgBzAEoA
>> "%~1" echo eQBrAHUAYgAyADUAagBiAEcAbABqAGEAegAxAGoAYgBHADkAegBaAFUATgB2AGIA
>> "%~1" echo bQBaAHAAYwBtADAANwBKAEMAZwBuAFkAMgA5AHUAWgBtAGwAeQBiAFUAOQByAEoA
>> "%~1" echo eQBrAHUAYgAyADUAagBiAEcAbABqAGEAegAwAG8ASwBUADAAKwBlADIATgB2AGIA
>> "%~1" echo bgBOADAASQBIAEEAOQBjAEcAVgB1AFoARwBsAHUAWgAwAE4AdgBiAG0AWgBwAGMA
>> "%~1" echo bQAwADcAWQAyAHgAdgBjADIAVgBEAGIAMgA1AG0AYQBYAEoAdABLAEMAawA3AGEA
>> "%~1" echo VwBZAG8AYwBDAGwAaABZADMAUgBwAGIAMgA0AG8AYwBDADUAaABZADMAUgBwAGIA
>> "%~1" echo MgA0AHMAYwBDADUAbABlAEgAUgB5AFkAUwB4AHcATABtAHgAaABZAG0AVgBzAEwA
>> "%~1" echo RwA1ADEAYgBHAHcAcwBkAEgASgAxAFoAUwBsADkATwB3AG8AawBLAEMAZAB5AFoA
>> "%~1" echo VwBaAHkAWgBYAE4AbwBRAG4AUgB1AEoAeQBrAHUAYgAyADUAagBiAEcAbABqAGEA
>> "%~1" echo egAwAG8ASwBUADAAKwBlADIANQB2AGQARwBsAG0AZQBTAGcAbgA1AFkAaQAzADUA
>> "%~1" echo cABhAHcANQA0AHEAMgA1AG8AQwBCAEoAeQB3AG4ANQBxADIAagA1AFoAeQBvADYA
>> "%~1" echo SwArADcANQBZACsAVwBJAEYARgAxAFoAWABOADAASQBPAGUASwB0AHUAYQBBAGcA
>> "%~1" echo UwA0AHUATABpAGMAcwBKADMAZABoAGMAbQA0AG4ATABEAEUAMgBNAEQAQQBwAE8A
>> "%~1" echo MwBKAGwAWgBuAEoAbABjADIAZwBvAGQASABKADEAWgBTAGsANwBiAEcAOQBoAFoA
>> "%~1" echo RQB4AHYAWgAzAE0AbwBaAG0ARgBzAGMAMgBVAHAAZgBUAHMASwBKAEMAZwBuAGIA
>> "%~1" echo VwBGAHUAZABXAEYAcwBVAG0AVgBtAGMAbQBWAHoAYQBDAGMAcABMAG0AOQB1AFkA
>> "%~1" echo MgB4AHAAWQAyAHMAOQBLAEMAawA5AFAAbgB0AHUAYgAzAFIAcABaAG4AawBvAEoA
>> "%~1" echo KwBXAEkAdAArAGEAVwBzAE8AZQBLAHQAdQBhAEEAZwBTAGMAcwBKACsAYQB0AG8A
>> "%~1" echo KwBXAGMAcQBPAGkAdgB1ACsAVwBQAGwAaQBCAFIAZABXAFYAegBkAEMARABuAGkA
>> "%~1" echo cgBiAG0AZwBJAEUAdQBMAGkANABuAEwAQwBkADMAWQBYAEoAdQBKAHkAdwB4AE4A
>> "%~1" echo agBBAHcASwBUAHQAeQBaAFcAWgB5AFoAWABOAG8ASwBIAFIAeQBkAFcAVQBwAE8A
>> "%~1" echo MgB4AHYAWQBXAFIATQBiADIAZAB6AEsARwBaAGgAYgBIAE4AbABLAFgAMAA3AEMA
>> "%~1" echo aQBRAG8ASgAzAEoAbABaAG4ASgBsAGMAMgBoAE0AYgAyAGQAegBKAHkAawB1AGIA
>> "%~1" echo MgA1AGoAYgBHAGwAagBhAHoAMABvAEsAVAAwACsAYgBHADkAaABaAEUAeAB2AFoA
>> "%~1" echo MwBNAG8AZABIAEoAMQBaAFMAawA3AEMAaQBRAG8ASgAyAFYANABjAEcAOQB5AGQA
>> "%~1" echo RQBKADAAYgBpAGMAcABMAG0AOQB1AFkAMgB4AHAAWQAyAHMAOQBaAFgAaAB3AGIA
>> "%~1" echo MwBKADAAUwBIAFIAdABiAEQAcwBLAEoAQwBnAG4AZABHAGgAbABiAFcAVgBDAGQA
>> "%~1" echo RwA0AG4ASwBTADUAdgBiAG0ATgBzAGEAVwBOAHIAUABTAGcAcABQAFQANQA3AGIA
>> "%~1" echo RwA5AGoAWQBXAHgAVABkAEcAOQB5AFkAVwBkAGwATABuAE4AbABkAEUAbAAwAFoA
>> "%~1" echo VwAwAG8AZABHAGgAbABiAFcAVgBMAFoAWABrAHMAWgBHADkAagBkAFcAMQBsAGIA
>> "%~1" echo bgBRAHUAWQBtADkAawBlAFMANQBqAGIARwBGAHoAYwAwAHgAcABjADMAUQB1AFkA
>> "%~1" echo MgA5AHUAZABHAEYAcABiAG4ATQBvAEoAMgBSAGgAYwBtAHMAbgBLAFQAOABuAGIA
>> "%~1" echo RwBsAG4AYQBIAFEAbgBPAGkAZABrAFkAWABKAHIASgB5AGsANwBkAEcAaABsAGIA
>> "%~1" echo VwBVAG8ASwBUAHQAdQBiADMAUgBwAFoAbgBrAG8ASgArAFMANAB1ACsAbQBpAG0A
>> "%~1" echo TwBXADMAcwB1AFcASQBoACsAYQBOAG8AaQBjAHMASgBDAGcAbgBkAEcAaABsAGIA
>> "%~1" echo VwBWAEMAZABHADQAbgBLAFMANQAwAFoAWABoADAAUQAyADkAdQBkAEcAVgB1AGQA
>> "%~1" echo RAAwADkAUABTAGYAbQB0AFkAWABvAGkAYgBJAG4AUAB5AGYAbAB2AFoAUABsAGkA
>> "%~1" echo WQAzAGsAdQBMAHIAbQB0ADcASABvAGkAYgBMAG0AcQBLAEgAbAB2AEkAOABuAE8A
>> "%~1" echo aQBmAGwAdgBaAFAAbABpAFkAMwBrAHUATAByAG0AdABZAFgAbwBpAGIATABtAHEA
>> "%~1" echo SwBIAGwAdgBJADgAbgBMAEMAZAB2AGEAeQBjAHAAZgBUAHMASwBKAEMAZwBuAFkA
>> "%~1" echo MwBWAHoAZABHADkAdABVADIAVgAwAEoAeQBrAHUAYgAyADUAagBiAEcAbABqAGEA
>> "%~1" echo egAwAG8ASwBUADAAKwBjADIAaAB2AGQAMABOAHYAYgBtAFoAcABjAG0AMABvAEoA
>> "%~1" echo MgBOADEAYwAzAFIAdgBiAFYAOQB6AFoAWABSADAAYQBXADUAbgBKAHkAdwBuADUA
>> "%~1" echo WQBhAFoANQBZAFcAbABJAEgATgBsAGQASABSAHAAYgBtAGQAegBKAHkAdwBuAEoA
>> "%~1" echo bQA1AHoAUABTAGMAcgBaAFcANQBqAGIAMgBSAGwAVgBWAEoASgBRADIAOQB0AGMA
>> "%~1" echo RwA5AHUAWgBXADUAMABLAEMAUQBvAEoAMgBOADEAYwAzAFIAdgBiAFUANQB6AEoA
>> "%~1" echo eQBrAHUAZABtAEYAcwBkAFcAVQBwAEsAeQBjAG0AYQAyAFYANQBQAFMAYwByAFoA
>> "%~1" echo VwA1AGoAYgAyAFIAbABWAFYASgBKAFEAMgA5AHQAYwBHADkAdQBaAFcANQAwAEsA
>> "%~1" echo QwBRAG8ASgAyAE4AMQBjADMAUgB2AGIAVQB0AGwAZQBTAGMAcABMAG4AWgBoAGIA
>> "%~1" echo SABWAGwASwBTAHMAbgBKAG4AWgBoAGIASABWAGwAUABTAGMAcgBaAFcANQBqAGIA
>> "%~1" echo MgBSAGwAVgBWAEoASgBRADIAOQB0AGMARwA5AHUAWgBXADUAMABLAEMAUQBvAEoA
>> "%~1" echo MgBOADEAYwAzAFIAdgBiAFYAWgBoAGIASABWAGwASgB5AGsAdQBkAG0ARgBzAGQA
>> "%~1" echo VwBVAHAASwBUAHMASwBKAEMAZwBuAFkAMwBWAHoAZABHADkAdABRAG4ASgB2AFkA
>> "%~1" echo VwBSAGoAWQBYAE4AMABKAHkAawB1AGIAMgA1AGoAYgBHAGwAagBhAHoAMABvAEsA
>> "%~1" echo VAAwACsAYwAyAGgAdgBkADAATgB2AGIAbQBaAHAAYwBtADAAbwBKADIATgAxAGMA
>> "%~1" echo MwBSAHYAYgBWADkAaQBjAG0AOQBoAFoARwBOAGgAYwAzAFEAbgBMAEMAZgBsAGoA
>> "%~1" echo NQBIAHAAZwBJAEgAbAB1AGIALwBtAGsAcQAwAG4ATABDAGMAbQBiAG0ARgB0AFoA
>> "%~1" echo VAAwAG4ASwAyAFYAdQBZADIAOQBrAFoAVgBWAFMAUwBVAE4AdgBiAFgAQgB2AGIA
>> "%~1" echo bQBWAHUAZABDAGcAawBLAEMAZABpAGMAbQA5AGgAWgBHAE4AaABjADMAUgBPAFkA
>> "%~1" echo VwAxAGwASgB5AGsAdQBkAG0ARgBzAGQAVwBVAHAASwBUAHMASwBKAEMAZwBuAFoA
>> "%~1" echo MgA5AEQAZABYAE4AMABiADIAMQBDAGMAbQA5AGgAWgBHAE4AaABjADMAUQBuAEsA
>> "%~1" echo UwA1AHYAYgBtAE4AcwBhAFcATgByAFAAUwBnAHAAUABUADUANwBiAEcAOQBqAFkA
>> "%~1" echo WABSAHAAYgAyADQAdQBhAEcARgB6AGEARAAwAG4AYwAyAFYAMABkAEcAbAB1AFoA
>> "%~1" echo MwBNAG4ATwAyADUAdgBkAEcAbABtAGUAUwBnAG4ANQBiAGUAeQA1AFkAaQBIADUA
>> "%~1" echo bwAyAGkASgB5AHcAbgA2AGEAdQBZADUANwBxAG4ASQBIAE4AbABkAEgAUgBwAGIA
>> "%~1" echo bQBkAHoASgB5AHcAbgBiADIAcwBuAEwARABFADQATQBEAEEAcABmAFQAcwBLAEoA
>> "%~1" echo QwBnAG4AWgAyADkATQBiADIAZAB6AEoAeQBrAHUAYgAyADUAagBiAEcAbABqAGEA
>> "%~1" echo egAwAG8ASwBUADAAKwBlADIAeAB2AFkAMgBGADAAYQBXADkAdQBMAG0AaABoAGMA
>> "%~1" echo MgBnADkASgAyAHgAdgBaADMATQBuAE8AMgA1AHYAZABHAGwAbQBlAFMAZwBuADUA
>> "%~1" echo YgBlAHkANQBZAGkASAA1AG8AMgBpAEoAeQB3AG4ANQBwAGUAbAA1AGIAKwBYAEoA
>> "%~1" echo eQB3AG4AYgAyAHMAbgBMAEQARQA0AE0ARABBAHAAZgBUAHMASwBaAG4AVgB1AFkA
>> "%~1" echo MwBSAHAAYgAyADQAZwBjAG0AOQAxAGQARwBVAG8ASwBYAHQAagBiADIANQB6AGQA
>> "%~1" echo QwBCAHAAWgBEADAAbwBiAEcAOQBqAFkAWABSAHAAYgAyADQAdQBhAEcARgB6AGEA
>> "%~1" echo SAB4ADgASgB5AE4AdgBkAG0AVgB5AGQAbQBsAGwAZAB5AGMAcABMAG4ATgBzAGEA
>> "%~1" echo VwBOAGwASwBEAEUAcABPADIAUgB2AFkAMwBWAHQAWgBXADUAMABMAG4ARgAxAFoA
>> "%~1" echo WABKADUAVQAyAFYAcwBaAFcATgAwAGIAMwBKAEIAYgBHAHcAbwBKAHkANQB3AFkA
>> "%~1" echo VwBkAGwASgB5AGsAdQBaAG0AOQB5AFIAVwBGAGoAYQBDAGgAdwBQAFQANQB3AEwA
>> "%~1" echo bQBOAHMAWQBYAE4AegBUAEcAbAB6AGQAQwA1ADAAYgAyAGQAbgBiAEcAVQBvAEoA
>> "%~1" echo MgBGAGoAZABHAGwAMgBaAFMAYwBzAGMAQwA1AHAAWgBEADAAOQBQAFcAbABrAEsA
>> "%~1" echo UwBrADcAWgBHADkAagBkAFcAMQBsAGIAbgBRAHUAYwBYAFYAbABjAG4AbABUAFoA
>> "%~1" echo VwB4AGwAWQAzAFIAdgBjAGsARgBzAGIAQwBnAG4ATABtADUAaABkAGkAQgBoAEoA
>> "%~1" echo eQBrAHUAWgBtADkAeQBSAFcARgBqAGEAQwBoAGgAUABUADUAaABMAG0ATgBzAFkA
>> "%~1" echo WABOAHoAVABHAGwAegBkAEMANQAwAGIAMgBkAG4AYgBHAFUAbwBKADIARgBqAGQA
>> "%~1" echo RwBsADIAWgBTAGMAcwBZAFMANQBuAFoAWABSAEIAZABIAFIAeQBhAFcASgAxAGQA
>> "%~1" echo RwBVAG8ASgAyAGgAeQBaAFcAWQBuAEsAVAAwADkAUABTAGMAagBKAHkAdABwAFoA
>> "%~1" echo QwBrAHAATwAyAE4AdgBiAG4ATgAwAEkARwAwADkAYwBHAEYAbgBaAFgATgBiAGEA
>> "%~1" echo VwBSAGQAZgBIAHgAdwBZAFcAZABsAGMAeQA1AHYAZABtAFYAeQBkAG0AbABsAGQA
>> "%~1" echo egB0AHoAWgBYAFEAbwBKADMAQgBoAFoAMgBWAFUAYQBYAFIAcwBaAFMAYwBzAGIA
>> "%~1" echo VgBzAHcAWABTAGsANwBjADIAVgAwAEsAQwBkAHcAWQBXAGQAbABVADMAVgBpAEoA
>> "%~1" echo eQB4AHQAVwB6AEYAZABLAFQAdABwAFoAaQBoAHAAWgBEADAAOQBQAFMAZABzAGIA
>> "%~1" echo MgBkAHoASgB5AGwAcwBiADIARgBrAFQARwA5AG4AYwB5AGgAbQBZAFcAeAB6AFoA
>> "%~1" echo UwBsADkAQwBuAFIAbwBaAFcAMQBsAEsAQwBrADcAWQBXAFIAawBSAFgAWgBsAGIA
>> "%~1" echo bgBSAE0AYQBYAE4AMABaAFcANQBsAGMAaQBnAG4AYQBHAEYAegBhAEcATgBvAFkA
>> "%~1" echo VwA1AG4AWgBTAGMAcwBjAG0AOQAxAGQARwBVAHAATwAzAEoAdgBkAFgAUgBsAEsA
>> "%~1" echo QwBrADcAYwBtAFYAbQBjAG0AVgB6AGEAQwBnAHAATwAyAHgAdgBZAFcAUgBNAGIA
>> "%~1" echo MgBkAHoASwBHAFoAaABiAEgATgBsAEsAVAB0AHoAWgBYAFIASgBiAG4AUgBsAGMA
>> "%~1" echo bgBaAGgAYgBDAGcAbwBLAFQAMAArAGMAMgBWADAASwBDAGQAagBiAEcAOQBqAGEA
>> "%~1" echo MQBSAGwAZQBIAFEAbgBMAEcANQBsAGQAeQBCAEUAWQBYAFIAbABLAEMAawB1AGQA
>> "%~1" echo RwA5AE0AYgAyAE4AaABiAEcAVgBVAGEAVwAxAGwAVQAzAFIAeQBhAFcANQBuAEsA
>> "%~1" echo QwBrAHAATABEAEUAdwBNAEQAQQBwAE8AMwBOAGwAZABFAGwAdQBkAEcAVgB5AGQA
>> "%~1" echo bQBGAHMASwBDAGcAcABQAFQANQB5AFoAVwBaAHkAWgBYAE4AbwBLAEcAWgBoAGIA
>> "%~1" echo SABOAGwASwBTAHcAeABOAFQAQQB3AE0AQwBrADcAQwBqAHcAdgBjADIATgB5AGEA
>> "%~1" echo WABCADAAUABqAHcAdgBZAG0AOQBrAGUAVAA0ADgATAAyAGgAMABiAFcAdwArAEMA
>> "%~1" echo ZwA9AD0AABNbAFsAVABPAEsARQBOAF0AXQAAA04AAACl+ntyLaRcTZggDw+97bcr
>> "%~1" echo AAi3elxWGTTgiQIGDgIGCAIGHAMGEgkFAAEBHQ4FAAEBEg0IAAAVEhECDg4KAAIV
>> "%~1" echo EhECDg4ODgUAAg4ODgYAAgESFQ4EAAEBDgMAAA4HAAIOEA4QDgYAAw4ODg4GAAMO
>> "%~1" echo DggOBgACDggdDggABAESGQ4ODgQAAQ4OCgACARUSEQIODg4GAAISFA4OCQAFARIU
>> "%~1" echo Dg4IDgoABQESFA4IAh0OBwACEhASFA4FAAEBEhQGAAIOEhQCDwAFARIZDhUSEQIO
>> "%~1" echo DgIdDggAAwESGRIUAgcAAw4OHQ4ICAADEgwOHQ4IBQABDh0OBAABCA4FAAIIDg4K
>> "%~1" echo AAIOFRIRAg4ODgUAAg4OAgYAAg4OEhQFAAEdDg4EAAECDgkAARUSEQIODg4LAAIB
>> "%~1" echo EhUVEhECDg4IAAMBEhUOHQUJAAEOFRIRAg4OAyAAAQIGAgMgAA4DKAAOAgYKBwYV
>> "%~1" echo EhECDg4HBhUSHQESEAYGFRIdAQ4EAQAAAAQgAQEIBAABARwDBhIxBAcBEjkEAAAS
>> "%~1" echo CQUAAQESCQQAABJFBQABEkkOBiACARJJCAQAABFRBQABDh0cBgADDhwcHAUAARJZ
>> "%~1" echo DgQgABINBSACARwYBgACAhIxHBEHChJNCA4ODhINEjkCHRwdDgQgABJhByACARIV
>> "%~1" echo EgkGIAEdDh0DBCABAQ4FAAICDg4GIAICDhF1BSABHQUOFAcMEhUSZQ4dDg4ODhJx
>> "%~1" echo DhINAh0DBQACDhwcBhUSEQIODgcgAgETABMBBiABEwETABcHCRUSEQIODg4ODg4V
>> "%~1" echo EhECDg4CHQ4dAwcABA4ODg4OBAABAQgFIAECEwAYBwoVEhECDg4ODg4ODhI5FRIR
>> "%~1" echo Ag4OAh0ODgcCFRIRAg4OFRIRAg4OBQAAEYCBBCABDg4GAAESgI0OBwADAQ4OEgkL
>> "%~1" echo AAIRgJURgIERgIEDIAANBQAAEoCZBiABDhKAoQYVEh0BEhADIAAIBRUSHQEOBSAA
>> "%~1" echo HRMABgACDg4dDioHFRUSEQIODhGAgQ4ODg4SFA4ODg4ODhGAlRI5FRIRAg4OAh0D
>> "%~1" echo EYCBCggFBwIOHQ4EIAEOCAIGAwUgAg4DAwYgAggOEXUEIAEIAwUAAR0FDggHBQ4O
>> "%~1" echo DhI5AgcHBA4ODh0DBSABDh0DCQcEDh0DAhGAgQYAAgEcEAIIBwQCHBGAgQIHIAMO
>> "%~1" echo HQUICAwHCB0FCAgOCBI5DgIJIAIdDh0DEYCtFgcQDg4ODg4ODg4dDgIOHQ4dDggC
>> "%~1" echo HQMDBwEOBAcCDg4JBwUSDA4OAh0cBSABEhkOCQcEDhIZAhGAgQUgARIZAwQHAg4C
>> "%~1" echo BwACHQ4OEgkHIAIdDh0DCA8HCQ4ODh0OAh0OCB0DHQ4FIAIODg4FBwMODg4MAAQC
>> "%~1" echo DhGAtRKAoRANByACDg4SgKEHBwUODg0CDQUgAg4ICAUgAQETABEHCg4VEh0BDg4O
>> "%~1" echo Dg4OHQ4IAhIHDA4ODh0ODg4OHQ4IAh0DHQ4GBwQODg4CDgcIDg4ODg4OFRIdAQ4C
>> "%~1" echo CwcEEhQSFBGAgR0OBAcBHQ4FAAASgLkDIAAKCgcEEoC5EgwSEAIJIAAVEYC9ARMA
>> "%~1" echo BxURgL0BEhAEIAATAAMgAAIOBwQSEBIQFRGAvQESEAIZBxIVEhECDg4ODg4ODg4O
>> "%~1" echo Dg4ODg4ODQINCBQHCRUSEQIODg4ODg4SGQ4RgIEdDhEHCw4dDg4ODg4dDggdAwId
>> "%~1" echo Dg8HBRIQDhURgL0BEhACHQ4EIAEIDg0HCg4ODggOCA4CHQ4IAwYSDAMGEhgDBhJZ
>> "%~1" echo BCAAEmUEIAEBAgcAARJZEoDBBiABARKAxQQgAQIIEgcIEoDBEn0SfRIcEjkSGBIM
>> "%~1" echo AgcHBBIZCA4CAwYRJAkAAgESgNERgNUFIAEIHQMEIAECDgkHBg4ODh0OCAIMBwkO
>> "%~1" echo DggOCA4dDggCCAcGDggOCA4CCgcHDg4IDh0OCAIPBwoODh0ODQ4dDggCHQMNDAcI
>> "%~1" echo Dg4ODh0OCAIdAwcgAwgOCBF1BgcECAgOAgoAAxKA3Q4OEYDhBSAAEoDpBiABEoDl
>> "%~1" echo CAYHAhKA3Q4JBwQSgN0OAh0DDwcJDg4dDg4dDggCHQMdDgYHBAgODgIPBwkODg4O
>> "%~1" echo DhUSHQEODggCDAcGDg4OFRIdAQ4OAg4HCA4ODg4OFRIdAQ4OAg8HCAgICAgVEh0B
>> "%~1" echo Dg4CHRwFBwMODgIJBwYIDggdDggCCgADEoDxDg4RgOEDBwEIBgABDhKA3QQGEoD5
>> "%~1" echo CAADDg4OEoD5CQAEDg4ODhGA4QYHAh0OHQMDBwECBCABAwgEAAECAwcHBQMCAg4I
>> "%~1" echo DQcJDggODg4CHQMdDggHIAMBHQUICAcHAw4dBR0cCyAAFRGA/QITABMBBxURgP0C
>> "%~1" echo Dg4LIAAVEYEBAhMAEwEHFRGBAQIODgQgABMBFQcGEhkCFRGBAQIODg4VEYD9Ag4O
>> "%~1" echo AgoHBxIZAw4OCAIIBSABDh0FAwAAAQUAABGBCQUHARGBCQgBAAgAAAAAAB4BAAEA
>> "%~1" echo VAIWV3JhcE5vbkV4Y2VwdGlvblRocm93cwEAAHTHAgAAAAAAAAAAAI7HAgAAIAAA
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAAAAAACAxwIAAAAAAAAAAAAAAF9Db3JFeGVNYWluAG1z
>> "%~1" echo Y29yZWUuZGxsAAAAAAD/JQAgQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
>> "%~1" echo AAAAAAAAAAAAAAAAAAAAAADAAgAMAAAAoDcAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
