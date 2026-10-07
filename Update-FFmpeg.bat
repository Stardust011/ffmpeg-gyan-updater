@echo off
setlocal DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%Update-FFmpeg.ps1"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS1_FILE%" (
    echo [ERR ] Could not find "%PS1_FILE%".
    echo Please keep Update-FFmpeg.ps1 in the same folder as this BAT file.
    pause
    exit /b 1
)

if not exist "%PS_EXE%" set "PS_EXE=powershell.exe"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo [ERR ] Update failed with exit code %EXIT_CODE%.
    pause
)

exit /b %EXIT_CODE%
