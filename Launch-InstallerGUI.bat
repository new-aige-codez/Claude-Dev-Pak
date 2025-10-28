@echo off
REM Claude Code Installer GUI Launcher
REM Double-click this file to open the configuration tool

echo.
echo ============================================================
echo    Claude Code Installer - Configuration Tool
echo ============================================================
echo.
echo Starting configuration GUI...
echo.

REM Check if PowerShell is available
where powershell.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell is not installed or not in PATH
    echo Please install PowerShell to use this installer.
    echo.
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Launch PowerShell GUI script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Show-InstallerConfiguration.ps1"

REM Check if GUI succeeded
if %errorlevel% neq 0 (
    echo.
    echo Configuration failed or was cancelled.
    echo.
    pause
)

exit /b %errorlevel%
