@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "MODE=%~1"
if /I "%MODE%"=="light" goto :run
if /I "%MODE%"=="dark" goto :run
if /I "%MODE%"=="auto" goto :run
goto :usage

:run
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" set "POWERSHELL=powershell.exe"

"%POWERSHELL%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%~dp0windows-theme.ps1" -Mode "%MODE%"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo ERROR: Theme switch failed with exit code %EXIT_CODE%.
exit /b %EXIT_CODE%

:usage
echo Usage: %~nx0 light^|dark^|auto
echo   light - Force Windows light mode.
echo   dark  - Force Windows dark mode.
echo   auto  - Use light mode from 07:00 through 22:59, otherwise dark mode.
exit /b 2
