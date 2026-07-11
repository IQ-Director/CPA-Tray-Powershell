@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Always resolve the PID file from the directory containing this script.
cd /d "%~dp0"
set "PIDFILE=%~dp0cli-proxy-api.pid"

rem The PID file is required so an unrelated process is never stopped by name alone.
if not exist "%PIDFILE%" (
    echo PID file not found: "%PIDFILE%"
    echo Try: taskkill /IM cli-proxy-api.exe /F
    exit /b 1
)

set "PID="
set /p PID=<"%PIDFILE%"

rem Reject empty and non-numeric PID values before querying the process table.
if not defined PID (
    echo PID file is empty: "%PIDFILE%"
    exit /b 1
)

echo(!PID!| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid PID in file: !PID!
    del "%PIDFILE%" >nul 2>nul
    exit /b 1
)

rem Confirm that the PID still belongs to cli-proxy-api.exe before terminating it.
set "TARGET_FOUND="
for /f "tokens=1 delims=," %%A in ('tasklist /FI "PID eq !PID!" /FI "IMAGENAME eq cli-proxy-api.exe" /FO CSV /NH 2^>nul') do (
    if /I "%%~A"=="cli-proxy-api.exe" set "TARGET_FOUND=1"
)

if not defined TARGET_FOUND (
    echo PID !PID! is not a running cli-proxy-api.exe process.
    del "%PIDFILE%" >nul 2>nul
    exit /b 1
)

rem Stop the complete process tree and remove the PID file only after taskkill succeeds.
taskkill /PID !PID! /T /F
if not errorlevel 1 (
    del "%PIDFILE%" >nul 2>nul
)
