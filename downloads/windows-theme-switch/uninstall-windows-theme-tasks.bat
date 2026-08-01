@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" set "POWERSHELL=powershell.exe"

"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%~dp0manage-windows-theme-tasks.ps1" -Action Uninstall
set "EXIT_CODE=%ERRORLEVEL%"

if "%EXIT_CODE%"=="0" (
    echo.
    echo Windows theme tasks were removed successfully.
) else (
    echo.
    echo ERROR: Windows theme task removal failed with exit code %EXIT_CODE%.
)

pause
exit /b %EXIT_CODE%
