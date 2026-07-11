@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Always resolve relative files from the directory containing this script.
cd /d "%~dp0"
set "PIDFILE=%~dp0cli-proxy-api.pid"
set "SERVICE_RUNNING="
set "POWERSHELL_EXE="

rem Prefer pwsh from PATH, then its default install path, and finally Windows PowerShell 5.1.
for %%I in (pwsh.exe) do set "POWERSHELL_EXE=%%~$PATH:I"

if not defined POWERSHELL_EXE if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "POWERSHELL_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
)

if not defined POWERSHELL_EXE (
    set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)

if not exist "%POWERSHELL_EXE%" (
    echo PowerShell was not found.
    exit /b 1
)

rem Check for a newer official CLIProxyAPI release before starting the service.
"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-cli-proxy-api.ps1"
if errorlevel 1 echo CLIProxyAPI update check failed. Starting the installed version.

rem Reuse a valid running service and discard stale or invalid PID files.
if exist "%PIDFILE%" (
    set "EXISTING_PID="
    set /p EXISTING_PID=<"%PIDFILE%"

    if defined EXISTING_PID (
        echo(!EXISTING_PID!| findstr /R "^[0-9][0-9]*$" >nul
        if not errorlevel 1 (
            for /f "tokens=1 delims=," %%A in ('tasklist /FI "PID eq !EXISTING_PID!" /FI "IMAGENAME eq cli-proxy-api.exe" /FO CSV /NH 2^>nul') do (
                if /I "%%~A"=="cli-proxy-api.exe" set "SERVICE_RUNNING=1"
            )
        )
    )

    if not defined SERVICE_RUNNING (
        del "%PIDFILE%" >nul 2>nul
    )
)

rem Run the backend without a visible console and save its PID for later validation and shutdown.
if not defined SERVICE_RUNNING (
    "%~dp0RunHiddenConsole.exe" /l /n CLIProxyAPI /p "%PIDFILE%" "%~dp0cli-proxy-api.exe" -config "%~dp0config.yaml"
)

rem Start the single-instance tray controller in an STA PowerShell process.
"%~dp0RunHiddenConsole.exe" /l "%POWERSHELL_EXE%" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0watch-webui.ps1"
