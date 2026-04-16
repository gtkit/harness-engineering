@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo 安装完成。
) else (
    echo 安装失败，退出码: %EXIT_CODE%
)

pause
exit /b %EXIT_CODE%
