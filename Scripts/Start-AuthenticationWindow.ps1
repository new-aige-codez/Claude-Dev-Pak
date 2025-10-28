<#
.SYNOPSIS
    External authentication window script for Claude Code CLI
.DESCRIPTION
    This script runs in a separate PowerShell window to handle Claude authentication.
    It creates a flag file upon completion to signal the main installer.
.PARAMETER WorkingDirectory
    Directory where the claude command will be executed
.PARAMETER FlagFilePath
    Path to the flag file that signals completion to the main installer
.NOTES
    This script is called by the Authentication.psm1 module
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory=$true)]
    [string]$FlagFilePath
)

# Set console encoding for proper display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Set window title
$host.UI.RawUI.WindowTitle = 'Claude Authentication - Follow Instructions Below'

# Change to working directory
try {
    Set-Location $WorkingDirectory
} catch {
    Write-Host "[ERROR] Failed to change to working directory: $WorkingDirectory" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Gray
    Read-Host "Press Enter to close"
    exit 1
}

# Display authentication instructions
Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Claude Code CLI Authentication Window" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your browser will open shortly for authentication." -ForegroundColor Yellow
Write-Host ""
Write-Host "Authentication Steps:" -ForegroundColor Cyan
Write-Host "  1. Browser will open automatically" -ForegroundColor Gray
Write-Host "  2. Enter your EMAIL ADDRESS on the authentication page" -ForegroundColor Gray
Write-Host "  3. Check your EMAIL inbox for the authentication link" -ForegroundColor Gray
Write-Host "  4. CLICK THE LINK in your email" -ForegroundColor Gray
Write-Host "     (You can use ANY browser - copy/paste link if needed)" -ForegroundColor DarkGray
Write-Host "  5. Browser will show SUCCESS URL:" -ForegroundColor Gray
Write-Host "     https://console.anthropic.com/oauth/code/success" -ForegroundColor Green
Write-Host "     OR: https://claude.ai/new" -ForegroundColor Green
Write-Host "  6. Return to this window and close it" -ForegroundColor Gray
Write-Host ""
Write-Host "TIP: Keep this window open until you see the success URL!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting authentication in 3 seconds..." -ForegroundColor Cyan
Write-Host ""

# Give user time to read instructions
Start-Sleep -Seconds 3

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Running: claude" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Execute claude command
try {
    & claude
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to execute claude command: $_" -ForegroundColor Red
    $exitCode = 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

# Check exit code and create flag file
if ($null -eq $exitCode -or $exitCode -eq 0) {
    # Success
    Write-Host "  Authentication Completed Successfully!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[OK] Browser should have shown success URL" -ForegroundColor Green
    Write-Host "[OK] Credentials saved to your system" -ForegroundColor Green
    Write-Host ""

    # Create success flag file
    try {
        $flagContent = @{
            Success = $true
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ExitCode = $exitCode
            WorkingDirectory = $WorkingDirectory
        } | ConvertTo-Json

        Set-Content -Path $FlagFilePath -Value $flagContent -ErrorAction Stop
        Write-Host "[OK] Signaled main installer" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Failed to create flag file: $_" -ForegroundColor Yellow
        Write-Host "  The main installer may not detect completion automatically" -ForegroundColor Gray
    }

} else {
    # Failure
    Write-Host "  Authentication Incomplete or Failed" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[!] Exit code: $exitCode" -ForegroundColor Yellow
    Write-Host "[!] This may indicate an error or incomplete authentication" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Cyan
    Write-Host "  - Didn't click the email link" -ForegroundColor Gray
    Write-Host "  - Browser didn't show success URL" -ForegroundColor Gray
    Write-Host "  - Network connection issues" -ForegroundColor Gray
    Write-Host ""

    # Create failure flag file
    try {
        $flagContent = @{
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ExitCode = $exitCode
            WorkingDirectory = $WorkingDirectory
        } | ConvertTo-Json

        Set-Content -Path $FlagFilePath -Value $flagContent -ErrorAction Stop
        Write-Host "[OK] Signaled main installer" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Failed to create flag file: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "You can now close this window." -ForegroundColor Cyan
Write-Host ""

# Wait for user to close window
Read-Host "Press Enter to close this window"

# Exit with appropriate code
exit $exitCode
