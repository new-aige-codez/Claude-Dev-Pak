<#
.SYNOPSIS
    Development Tools Installer - Installs Docker, Python, Bruno, and DBeaver

.DESCRIPTION
    A simple PowerShell installer that uses winget to install essential development tools:
    - Docker Desktop
    - Python 3.12
    - Bruno API Client
    - DBeaver Community

.NOTES
    Version:        1.0.0
    Author:         Claude Code
    Creation Date:  2025-10-19
    Requires:       Windows 10/11, Administrator privileges, winget (App Installer)
    PowerShell:     5.1 or higher
#>

#Requires -Version 5.1

# ============================================================================
# ADMINISTRATOR PRIVILEGE CHECK
# ============================================================================

function Ensure-Administrator {
    <#
    .SYNOPSIS
        Checks if script is running with administrator privileges and elevates if needed
    #>

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ""
        Write-Host "This installer requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Attempting to restart with elevated privileges..." -ForegroundColor Yellow
        Write-Host ""

        Start-Sleep -Seconds 2

        # Restart the script with admin privileges
        $scriptPath = $MyInvocation.PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $PSCommandPath
        }

        Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}

# ============================================================================
# WINGET AVAILABILITY CHECK
# ============================================================================

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Verifies that winget is installed and accessible
    #>

    Write-Host "Checking for winget availability..." -ForegroundColor Cyan

    try {
        $wingetVersion = winget --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $wingetVersion) {
            Write-Host "  [OK] winget found: $wingetVersion" -ForegroundColor Green
            return $true
        }
    }
    catch {
        # winget not found
    }

    Write-Host ""
    Write-Host "ERROR: winget is not installed or not accessible!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install 'App Installer' from the Microsoft Store:" -ForegroundColor Yellow
    Write-Host "  https://www.microsoft.com/p/app-installer/9nblggh4nns1" -ForegroundColor White
    Write-Host ""
    Write-Host "After installation, restart this script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ============================================================================
# TOOL INSTALLATION FUNCTION
# ============================================================================

function Install-Tool {
    <#
    .SYNOPSIS
        Installs a tool using winget

    .PARAMETER DisplayName
        The friendly name to display to the user

    .PARAMETER WingetId
        The winget package identifier

    .PARAMETER UseExactMatch
        Whether to use the -e (exact match) flag
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$WingetId,

        [Parameter(Mandatory = $false)]
        [switch]$UseExactMatch = $false
    )

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Gray
    Write-Host "Installing: $DisplayName" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Gray
    Write-Host ""

    # Build the winget command
    if ($UseExactMatch) {
        $wingetArgs = "install -e --id $WingetId --silent --accept-package-agreements --accept-source-agreements"
    }
    else {
        $wingetArgs = "install $WingetId --silent --accept-package-agreements --accept-source-agreements"
    }

    Write-Host "  Running: winget $wingetArgs" -ForegroundColor DarkGray
    Write-Host ""

    # Execute winget
    $output = cmd /c "winget $wingetArgs 2>&1"
    $exitCode = $LASTEXITCODE

    # Display output
    $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    Write-Host ""

    # Check result
    if ($exitCode -eq 0) {
        Write-Host "  [SUCCESS] $DisplayName installed successfully" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  [FAILED] $DisplayName installation failed (Exit code: $exitCode)" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# BANNER DISPLAY
# ============================================================================

function Show-Banner {
    <#
    .SYNOPSIS
        Displays the welcome banner
    #>

    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                    ║" -ForegroundColor Cyan
    Write-Host "║            DEVELOPMENT TOOLS INSTALLER v1.0.0                      ║" -ForegroundColor Cyan
    Write-Host "║                                                                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This installer will install the following development tools:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Docker Desktop     - Container platform" -ForegroundColor Yellow
    Write-Host "  2. Python 3.12        - Programming language" -ForegroundColor Yellow
    Write-Host "  3. Bruno              - API client" -ForegroundColor Yellow
    Write-Host "  4. DBeaver Community  - Database management tool" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor White
    Write-Host "  - Windows 10/11" -ForegroundColor Gray
    Write-Host "  - Administrator privileges" -ForegroundColor Gray
    Write-Host "  - Active internet connection" -ForegroundColor Gray
    Write-Host "  - winget (App Installer)" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

# Ensure running as administrator
Ensure-Administrator

# Show welcome banner
Show-Banner

# Verify winget is available
if (-not (Test-WingetAvailable)) {
    exit 1
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host "READY TO INSTALL" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host ""
Write-Host "Press Y to continue or N to cancel..." -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Continue? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host ""
    Write-Host "Installation cancelled by user." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Initialize results tracking
$results = @{
    'Docker Desktop'    = $false
    'Python 3.12'       = $false
    'Bruno API Client'  = $false
    'DBeaver Community' = $false
}

# Record start time
$startTime = Get-Date

Write-Host ""
Write-Host "Starting installation process..." -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

# ============================================================================
# INSTALL TOOLS
# ============================================================================

# 1. Install Docker Desktop
$results['Docker Desktop'] = Install-Tool -DisplayName "Docker Desktop" -WingetId "Docker.DockerDesktop" -UseExactMatch
Start-Sleep -Seconds 2

# 2. Install Python 3.12
$results['Python 3.12'] = Install-Tool -DisplayName "Python 3.12" -WingetId "Python.Python.3.12"
Start-Sleep -Seconds 2

# 3. Install Bruno
$results['Bruno API Client'] = Install-Tool -DisplayName "Bruno API Client" -WingetId "Bruno.Bruno" -UseExactMatch
Start-Sleep -Seconds 2

# 4. Install DBeaver
$results['DBeaver Community'] = Install-Tool -DisplayName "DBeaver Community" -WingetId "dbeaver.dbeaver" -UseExactMatch
Start-Sleep -Seconds 2

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                     INSTALLATION COMPLETE                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Summary:" -ForegroundColor White
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($tool in $results.Keys | Sort-Object) {
    if ($results[$tool]) {
        Write-Host "  ✓ $tool" -ForegroundColor Green
        $successCount++
    }
    else {
        Write-Host "  ✗ $tool" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Results: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "Duration: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Gray
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "Note: Some installations failed. You can:" -ForegroundColor Yellow
    Write-Host "  - Re-run this installer to retry failed installations" -ForegroundColor Yellow
    Write-Host "  - Install failed tools manually using winget or their official installers" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Important:" -ForegroundColor White
Write-Host "  - Some tools may require a system restart to function properly" -ForegroundColor Gray
Write-Host "  - Docker Desktop requires WSL2 to be enabled" -ForegroundColor Gray
Write-Host "  - You may need to restart your terminal for PATH changes to take effect" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

exit 0
