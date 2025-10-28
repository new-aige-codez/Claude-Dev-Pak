<#
.SYNOPSIS
    Claude Code Development Environment Installer (Configuration-Driven)
.DESCRIPTION
    Automated installer for Claude Code development environment.
    Supports both interactive and silent/automated installation modes.
    Uses modular architecture with separate Authentication, ErrorHandling, and Configuration modules.
.PARAMETER ConfigFile
    Path to configuration JSON file (default: .\InstallConfig.json)
.PARAMETER InstallationType
    Installation type: Full (all components) or Core (required only)
.PARAMETER Silent
    Run without prompts using configuration file or defaults
.PARAMETER CreateShortcuts
    Create desktop shortcuts for installed applications
.PARAMETER SkipAuthentication
    Skip Claude authentication step
.PARAMETER Force
    Force reinstallation even if components already exist
.PARAMETER SaveConfig
    Save current settings to configuration file after prompting
.PARAMETER UseDefaults
    Use hardcoded defaults, ignore configuration file
.EXAMPLE
    .\ClaudeCodeInstaller.ps1
    Interactive installation with prompts
.EXAMPLE
    .\ClaudeCodeInstaller.ps1 -Silent
    Silent installation using InstallConfig.json
.EXAMPLE
    .\ClaudeCodeInstaller.ps1 -Silent -InstallationType Core -SkipAuthentication
    Silent core installation without authentication
.NOTES
    Version: 4.2.0-config
    Requires: Windows 10/11, Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Path to configuration JSON file")]
    [string]$ConfigFile = "$PSScriptRoot\InstallConfig.json",

    [Parameter(HelpMessage="Installation type: Full or Core")]
    [ValidateSet('Full', 'Core')]
    [string]$InstallationType,

    [Parameter(HelpMessage="Run in silent mode without prompts")]
    [switch]$Silent,

    [Parameter(HelpMessage="Create desktop shortcuts")]
    [switch]$CreateShortcuts,

    [Parameter(HelpMessage="Skip Claude authentication")]
    [switch]$SkipAuthentication,

    [Parameter(HelpMessage="Force reinstall even if already installed")]
    [switch]$Force,

    [Parameter(HelpMessage="Save settings to configuration file")]
    [switch]$SaveConfig,

    [Parameter(HelpMessage="Use defaults, ignore config file")]
    [switch]$UseDefaults
)

# UTF-8 encoding setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -eq 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
}

# Determine script root directory
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# Import modules
$modulePath = Join-Path $ScriptRoot "Modules"
if (Test-Path "$modulePath\Authentication.psm1") {
    Import-Module "$modulePath\Authentication.psm1" -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$modulePath\ErrorHandling.psm1") {
    Import-Module "$modulePath\ErrorHandling.psm1" -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$modulePath\Configuration.psm1") {
    Import-Module "$modulePath\Configuration.psm1" -Force -ErrorAction SilentlyContinue
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

#region Core Utility Functions

function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevating to administrator..." -ForegroundColor Yellow
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")

        # Pass through parameters
        if ($ConfigFile) { $argList += "-ConfigFile", "`"$ConfigFile`"" }
        if ($InstallationType) { $argList += "-InstallationType", $InstallationType }
        if ($Silent) { $argList += "-Silent" }
        if ($CreateShortcuts) { $argList += "-CreateShortcuts" }
        if ($SkipAuthentication) { $argList += "-SkipAuthentication" }
        if ($Force) { $argList += "-Force" }
        if ($SaveConfig) { $argList += "-SaveConfig" }
        if ($UseDefaults) { $argList += "-UseDefaults" }

        Start-Process PowerShell.exe -Verb RunAs -ArgumentList $argList
        exit
    }
}

function Show-Banner {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   Claude Code Development Environment Installer v4.2" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

function Show-Progress {
    param([string]$Message, [scriptblock]$Action, [switch]$Silent)

    $spinner = @('|', '/', '-', '\')
    $i = 0

    $job = Start-Job -ScriptBlock {
        param($Script)
        try {
            $result = & ([scriptblock]::Create($Script))
            return @{Success = $true; Output = $result; ExitCode = $LASTEXITCODE}
        } catch {
            return @{Success = $false; Output = $_.Exception.Message; ExitCode = 1}
        }
    } -ArgumentList $Action.ToString()

    if (-not $Silent) {
        Write-Host "[ ] $Message" -NoNewline -ForegroundColor Cyan
        while ($job.State -eq 'Running') {
            Write-Host "`r[$($spinner[$i % 4])] $Message" -NoNewline -ForegroundColor Cyan
            $i++
            Start-Sleep -Milliseconds 200
        }
    } else {
        $job | Wait-Job | Out-Null
    }

    $result = Receive-Job $job
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    $success = $result.Success -and ($null -eq $result.ExitCode -or $result.ExitCode -eq 0)

    if (-not $Silent) {
        Write-Host "`r$( if($success){'[OK]'}else{'[X] '} ) $Message" -ForegroundColor $(if($success){'Green'}else{'Red'})
    }

    return @{Success = $success; Output = $result.Output}
}

function Test-Tool {
    param([string]$Command, [string]$Arg, [string]$Pattern, [string]$Name)

    try {
        $output = & $Command $Arg 2>$null
        if ($output -match $Pattern) {
            if (-not $script:SilentMode) {
                Write-Host "[FOUND] $Name already installed. Skipping." -ForegroundColor Green
            }
            if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                Write-InstallLog -Level Info -Component $Name -Message "Already installed, skipping"
            }
            return $true
        }
    } catch {}
    return $false
}

function Update-PathVariable {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        # Expand environment variables
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)

        if (-not ($env:Path -like "*$expandedPath*")) {
            $env:Path = "$expandedPath;$env:Path"
        }
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Get-UserChoice {
    param([string]$Prompt, [string[]]$ValidChoices, [string]$Default = "")

    while ($true) {
        $input = Read-Host $Prompt
        $choice = if ([string]::IsNullOrWhiteSpace($input) -and $Default) { $Default }
                  else { $input.Trim().ToLower().Substring(0,1) }

        if ($choice -in $ValidChoices) { return $choice }
        Write-Host "[!] Invalid choice. Try again." -ForegroundColor Yellow
    }
}

function New-DesktopShortcut {
    param([string]$Name, [string]$TargetPath, [string]$WorkingDir = "", [string]$Args = "")

    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "$Name.lnk"

        if (Test-Path $shortcutPath) { return $true }

        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $TargetPath
        if ($WorkingDir) { $shortcut.WorkingDirectory = $WorkingDir }
        if ($Args) { $shortcut.Arguments = $Args }
        $shortcut.Save()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshShell) | Out-Null

        if (-not $script:SilentMode) {
            Write-Host "[OK] Created shortcut: $Name" -ForegroundColor Green
        }
        return $true
    } catch {
        if (-not $script:SilentMode) {
            Write-Host "[WARNING] Failed to create shortcut: $Name" -ForegroundColor Yellow
        }
        return $false
    }
}

#endregion

#region Installation Functions

function Install-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        if (-not $script:SilentMode) {
            Write-Host "[FOUND] Using winget" -ForegroundColor Green
        }
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "PackageManager" -Message "Using winget"
        }
        return 'winget'
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        if (-not $script:SilentMode) {
            Write-Host "[FOUND] Using Chocolatey" -ForegroundColor Green
        }
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "PackageManager" -Message "Using Chocolatey"
        }
        return 'choco'
    }

    if (-not $script:SilentMode) {
        Write-Host "[~] Installing Chocolatey..." -ForegroundColor Cyan
    }
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "Chocolatey" -Message "Installing Chocolatey package manager"
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script | Out-Null
        $env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path
        if (-not $script:SilentMode) {
            Write-Host "[OK] Chocolatey installed" -ForegroundColor Green
        }
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Success -Component "Chocolatey" -Message "Installation successful"
        }
        return 'choco'
    } catch {
        Write-Host "[ERROR] Failed to install Chocolatey: $_" -ForegroundColor Red
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord $_ -Component "Chocolatey" -Critical
        }
        exit 1
    }
}

function Install-ComponentFromConfig {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ComponentConfig,

        [Parameter(Mandatory)]
        [string]$ComponentName,

        [Parameter(Mandatory)]
        [string]$PackageManager
    )

    $displayName = $ComponentConfig.displayName

    # Check if already installed (unless -Force)
    if (-not $script:ForceInstall) {
        if ($ComponentConfig.PSObject.Properties['testCommand']) {
            if (Test-Tool -Command $ComponentConfig.testCommand -Arg $ComponentConfig.testArgs -Pattern $ComponentConfig.testPattern -Name $displayName) {
                $script:ComponentResults[$ComponentName] = [PSCustomObject]@{
                    Success = $true
                    AlreadyInstalled = $true
                    Method = "skipped"
                }
                return $true
            }
        }
    }

    if (-not $script:SilentMode) {
        Write-Host "`n[~] Installing $displayName..." -ForegroundColor Cyan
    }
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component $displayName -Message "Starting installation"
    }

    try {
        $success = $false

        # Determine installation source
        if ($ComponentConfig.PSObject.Properties['source']) {
            $source = $ComponentConfig.source

            if ($source -eq 'npm') {
                # NPM installation
                $package = $ComponentConfig.package
                $output = npm install -g $package 2>&1
                $success = ($LASTEXITCODE -eq 0) -or (($output | Out-String) -match "(added \d+ package|up to date)")

            } elseif ($source -eq 'msstore') {
                # Microsoft Store (manual)
                if (-not $script:SilentMode) {
                    Start-Process "ms-windows-store://pdp/?ProductId=$($ComponentConfig.storeId)"
                    Write-Host "  Please complete installation in Microsoft Store window" -ForegroundColor Yellow
                    Write-Host "  Then return here" -ForegroundColor Yellow
                    $installed = Get-UserChoice "Did you install $displayName? [Y/N]" @('y', 'n')
                    $success = ($installed -eq 'y')
                } else {
                    # In silent mode, skip store apps
                    Write-Host "[SKIPPED] $displayName (requires manual Microsoft Store installation)" -ForegroundColor Yellow
                    $success = $false
                }
            }

        } else {
            # Winget/Choco installation
            if ($PackageManager -eq 'winget') {
                winget install --id $ComponentConfig.wingetId -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
                $success = ($LASTEXITCODE -eq 0)
            } else {
                choco install $ComponentConfig.chocoId -y --force --limit-output 2>&1 | Out-Null
                $success = ($LASTEXITCODE -eq 0)
            }
        }

        if ($success) {
            if (-not $script:SilentMode) {
                Write-Host "[OK] $displayName installed" -ForegroundColor Green
            }
            if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                Write-InstallLog -Level Success -Component $displayName -Message "Installation completed"
            }

            # Update PATH if needed
            if ($ComponentConfig.PSObject.Properties['pathsToAdd']) {
                Update-PathVariable -Paths $ComponentConfig.pathsToAdd
            }

            $script:ComponentResults[$ComponentName] = [PSCustomObject]@{
                Success = $true
                AlreadyInstalled = $false
                Method = if ($ComponentConfig.PSObject.Properties['source']) { $ComponentConfig.source } else { $PackageManager }
            }

            return $true
        } else {
            if (-not $script:SilentMode) {
                Write-Host "[ERROR] Failed to install $displayName" -ForegroundColor Red
            }
            if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
                Add-InstallError -ErrorRecord "Installation failed" -Component $displayName -Critical:$ComponentConfig.required
            }

            $script:ComponentResults[$ComponentName] = [PSCustomObject]@{
                Success = $false
                Error = "Installation failed"
            }

            return $false
        }

    } catch {
        if (-not $script:SilentMode) {
            Write-Host "[ERROR] Exception during installation: $_" -ForegroundColor Red
        }
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord $_ -Component $displayName -Critical:$ComponentConfig.required
        }

        $script:ComponentResults[$ComponentName] = [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }

        return $false
    }
}

function Install-VSCodeExtension {
    param([string]$ExtId, [string]$Name)

    if (-not $script:SilentMode) {
        Write-Host "[~] Installing VS Code extension: $Name..." -ForegroundColor Cyan
    }
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "VSCode Extension" -Message "Installing $Name"
    }

    code --install-extension $ExtId --force 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        if (-not $script:SilentMode) {
            Write-Host "[OK] Extension installed: $Name" -ForegroundColor Green
        }
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Success -Component "VSCode Extension" -Message "$Name installed"
        }
        return $true
    }

    if (-not $script:SilentMode) {
        Write-Host "[WARNING] Failed to install extension: $Name" -ForegroundColor Yellow
    }
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Warning -Component "VSCode Extension" -Message "Failed to install $Name"
    }
    return $false
}

#endregion

#region Main Installation Flow

function Start-Installation {
    Ensure-Administrator
    Show-Banner

    # Initialize logging
    if (Get-Command Initialize-InstallLog -ErrorAction SilentlyContinue) {
        $script:LogPath = Initialize-InstallLog
        Write-InstallLog -Level Info -Component "Installer" -Message "Installation started - Version 4.2.0-config"
    }

    #region Configuration Loading
    if (-not $script:SilentMode) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Configuration Loading" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
    }

    # Load configuration
    try {
        $configLoaded = $false

        if (Get-Command Get-InstallConfiguration -ErrorAction SilentlyContinue) {
            if ($UseDefaults) {
                if (-not $script:SilentMode) {
                    Write-Host "Using hardcoded defaults (config file ignored)" -ForegroundColor Gray
                }
                $script:Config = Get-InstallConfiguration -UseDefaults
                $configLoaded = $true
            } else {
                if (Test-Path $ConfigFile) {
                    if (-not $script:SilentMode) {
                        Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Gray
                    }
                    $script:Config = Get-InstallConfiguration -ConfigPath $ConfigFile
                    $configLoaded = $true
                } else {
                    if (-not $script:SilentMode) {
                        Write-Host "Configuration file not found, using defaults" -ForegroundColor Gray
                    }
                    $script:Config = Get-InstallConfiguration -UseDefaults
                    $configLoaded = $true
                }
            }

            # Merge CLI parameters (override config file)
            $paramOverrides = @{}
            if ($PSBoundParameters.ContainsKey('InstallationType')) {
                $paramOverrides['installationType'] = $InstallationType
            }
            if ($PSBoundParameters.ContainsKey('Silent')) {
                $paramOverrides['silent'] = $Silent.IsPresent
            }
            if ($PSBoundParameters.ContainsKey('CreateShortcuts')) {
                $paramOverrides['createDesktopShortcuts'] = $CreateShortcuts.IsPresent
            }
            if ($PSBoundParameters.ContainsKey('SkipAuthentication')) {
                $paramOverrides['authenticateNow'] = -not $SkipAuthentication.IsPresent
            }

            if ($paramOverrides.Count -gt 0 -and (Get-Command Merge-ConfigurationWithParameters -ErrorAction SilentlyContinue)) {
                if (-not $script:SilentMode) {
                    Write-Host "Applying parameter overrides: $($paramOverrides.Keys -join ', ')" -ForegroundColor Gray
                }
                $script:Config = Merge-ConfigurationWithParameters -Configuration $script:Config -Parameters $paramOverrides
            }

            # Validate configuration
            if (Get-Command Test-ConfigurationValid -ErrorAction SilentlyContinue) {
                $validation = Test-ConfigurationValid -Configuration $script:Config
                if (-not $validation.IsValid) {
                    Write-Host "`n[ERROR] Configuration validation failed:" -ForegroundColor Red
                    $validation.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
                    Write-Host "`nPlease fix the configuration file or use -UseDefaults" -ForegroundColor Yellow
                    exit 1
                }
            }

            if (-not $script:SilentMode) {
                Write-Host "[OK] Configuration loaded successfully" -ForegroundColor Green
            }

        } else {
            # Configuration module not available - use defaults
            if (-not $script:SilentMode) {
                Write-Host "[WARNING] Configuration module not available, using defaults" -ForegroundColor Yellow
            }
            # Create minimal config
            $script:Config = [PSCustomObject]@{
                installationType = if ($InstallationType) { $InstallationType } else { "Full" }
                silent = $Silent.IsPresent
                createDesktopShortcuts = if ($PSBoundParameters.ContainsKey('CreateShortcuts')) { $CreateShortcuts.IsPresent } else { $true }
                authenticateNow = if ($PSBoundParameters.ContainsKey('SkipAuthentication')) { -not $SkipAuthentication.IsPresent } else { $true }
            }
            $configLoaded = $false
        }

    } catch {
        Write-Host "`n[ERROR] Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Falling back to interactive mode..." -ForegroundColor Yellow
        $script:Config = [PSCustomObject]@{
            installationType = "Full"
            silent = $false
            createDesktopShortcuts = $true
            authenticateNow = $true
        }
        $configLoaded = $false
    }
    #endregion Configuration Loading

    # Determine mode and settings
    if ($script:Config.silent) {
        # SILENT MODE
        if (-not $script:SilentMode) {
            Write-Host "`n[SILENT MODE] Using configuration settings" -ForegroundColor Cyan
            Write-Host "  Installation Type: $($script:Config.installationType)" -ForegroundColor Gray
            Write-Host "  Desktop Shortcuts: $(if ($script:Config.createDesktopShortcuts) {'Yes'} else {'No'})" -ForegroundColor Gray
            Write-Host "  Authentication: $(if ($script:Config.authenticateNow) {'Yes'} else {'No'})" -ForegroundColor Gray
        }

        $installType = $script:Config.installationType
        $createShortcuts = $script:Config.createDesktopShortcuts
        $authenticateAfter = $script:Config.authenticateNow

    } else {
        # INTERACTIVE MODE
        Write-Host "`nThis installer will set up your Claude Code development environment.`n" -ForegroundColor Cyan

        if ($configLoaded) {
            Write-Host "[INTERACTIVE MODE]" -ForegroundColor Cyan
            Write-Host "Current defaults from configuration file:" -ForegroundColor Gray
            Write-Host "  - Installation Type: $($script:Config.installationType)" -ForegroundColor Gray
            Write-Host "  - Desktop Shortcuts: $(if ($script:Config.createDesktopShortcuts) {'Yes'} else {'No'})" -ForegroundColor Gray
            Write-Host "  - Authentication: $(if ($script:Config.authenticateNow) {'Yes'} else {'No'})" -ForegroundColor Gray
            Write-Host ""
        }

        # Show requirements
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Disk Space Requirements" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Core Installation:  ~2 GB free space" -ForegroundColor Yellow
        Write-Host "  Full Installation:  ~4.5 GB free space`n" -ForegroundColor Yellow

        # Desktop shortcuts preference
        $shortcutDefault = if ($script:Config.createDesktopShortcuts) { 'Y' } else { 'N' }
        $shortcutChoice = Get-UserChoice "Create desktop shortcuts? [Y/N] [Default: $shortcutDefault]" @('y', 'n') $shortcutDefault.ToLower()
        $createShortcuts = ($shortcutChoice -eq 'y')
        Write-Host ""

        # Installation type
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Installation Type" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  [C] Core (~1.1 GB): Node.js, Git, VS Code, Claude CLI" -ForegroundColor White
        Write-Host "  [F] Full (~2.3 GB): Core + GitHub Desktop + Pieces Desktop`n" -ForegroundColor Green

        $defaultChoice = if ($script:Config.installationType -eq 'Full') { 'f' } else { 'c' }
        $choice = Get-UserChoice "Select [C]ore or [F]ull [Default: $defaultChoice]" @('c', 'f') $defaultChoice
        $installType = if ($choice -eq 'f') { 'Full' } else { 'Core' }

        # Authentication preference
        $authDefault = if ($script:Config.authenticateNow) { 'Y' } else { 'N' }
        $authChoice = Get-UserChoice "`nAuthenticate Claude CLI after installation? [Y/N] [Default: $authDefault]" @('y', 'n') $authDefault.ToLower()
        $authenticateAfter = ($authChoice -eq 'y')

        Write-Host "`n[OK] $installType installation selected" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "Installer" -Message "Installation type: $installType"
        }

        # Save configuration if requested
        if ($SaveConfig -and (Get-Command Save-InstallConfiguration -ErrorAction SilentlyContinue)) {
            Write-Host "`nSaving configuration for future use..." -ForegroundColor Cyan
            $script:Config.installationType = $installType
            $script:Config.createDesktopShortcuts = $createShortcuts
            $script:Config.authenticateNow = $authenticateAfter

            try {
                Save-InstallConfiguration -Configuration $script:Config -ConfigPath $ConfigFile
                Write-Host "[OK] Configuration saved to: $ConfigFile" -ForegroundColor Green
            } catch {
                Write-Host "[WARNING] Failed to save configuration: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        Read-Host "`nPress Enter to begin installation"
        Write-Host ""
    }

    # Install package manager if needed
    if (-not $script:SilentMode) {
        Write-Host "`nDetecting package manager..." -ForegroundColor Cyan
    }
    $pkgMgr = Install-PackageManager

    # Component installation (config-driven if available)
    if ($configLoaded -and $script:Config.PSObject.Properties['components']) {
        if (-not $script:SilentMode) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Component Installation (Config-Driven)" -ForegroundColor Cyan
            Write-Host "========================================`n" -ForegroundColor Cyan
        }

        $script:ComponentResults = @{}
        $criticalFailures = @()

        foreach ($componentName in $script:Config.components.PSObject.Properties.Name) {
            $component = $script:Config.components.$componentName

            # Skip optional components if Core installation
            if (-not $component.required) {
                if ($installType -eq 'Core') {
                    continue
                }
                if (-not $component.PSObject.Properties['includeInFullInstall']) {
                    continue
                }
            }

            # Install component
            $installSuccess = Install-ComponentFromConfig -ComponentConfig $component -ComponentName $componentName -PackageManager $pkgMgr

            # Track critical failures
            if (-not $installSuccess -and $component.required) {
                $criticalFailures += $component.displayName
            }
        }

        # Check for critical failures
        if ($criticalFailures.Count -gt 0) {
            Write-Host "`n[CRITICAL ERROR] Required components failed to install:" -ForegroundColor Red
            $criticalFailures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            Write-Host "`nInstallation cannot continue." -ForegroundColor Red

            if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
                $summary = Get-InstallSummary
                exit $summary.ExitCode
            } else {
                exit 1
            }
        }

    } else {
        # Fallback to traditional installation
        if (-not $script:SilentMode) {
            Write-Host "Checking for existing installations..." -ForegroundColor Cyan
        }

        $needsNode = -not (Test-Tool "node" "--version" "^v" "Node.js")
        $needsGit = -not (Test-Tool "git" "--version" "git version" "Git")
        $needsCode = -not (Test-Tool "code" "--version" "." "VS Code")
        $needsClaude = -not (Test-Tool "claude" "--version" "." "Claude CLI")

        # Install components (traditional method)
        if ($needsNode) {
            if (-not $script:SilentMode) { Write-Host "`n[~] Installing Node.js..." -ForegroundColor Cyan }
            if ($pkgMgr -eq 'winget') {
                winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            } else {
                choco install nodejs-lts -y --force --limit-output 2>&1 | Out-Null
            }
            Update-PathVariable -Paths @("C:\Program Files\nodejs", "$env:APPDATA\npm")
        }

        if ($needsGit) {
            if (-not $script:SilentMode) { Write-Host "`n[~] Installing Git..." -ForegroundColor Cyan }
            if ($pkgMgr -eq 'winget') {
                winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            } else {
                choco install git -y --force --limit-output 2>&1 | Out-Null
            }
            Update-PathVariable -Paths @("C:\Program Files\Git\cmd")
            [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "C:\Program Files\Git\bin\bash.exe", "User")
        }

        if ($needsCode) {
            if (-not $script:SilentMode) { Write-Host "`n[~] Installing VS Code..." -ForegroundColor Cyan }
            if ($pkgMgr -eq 'winget') {
                winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            } else {
                choco install vscode -y --force --limit-output 2>&1 | Out-Null
            }
            Update-PathVariable -Paths @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin")
        }

        if ($needsClaude) {
            if (-not $script:SilentMode) { Write-Host "`n[~] Installing Claude CLI..." -ForegroundColor Cyan }
            npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null
            Update-PathVariable -Paths @("$env:APPDATA\npm")
        }

        if ($installType -eq 'Full') {
            # GitHub Desktop
            if (-not $script:SilentMode) { Write-Host "`n[~] Installing GitHub Desktop..." -ForegroundColor Cyan }
            if ($pkgMgr -eq 'winget') {
                winget install --id GitHub.GitHubDesktop -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            } else {
                choco install github-desktop -y --force --limit-output 2>&1 | Out-Null
            }

            # Pieces Desktop (if not silent)
            if (-not $script:SilentMode) {
                $installPieces = (Get-UserChoice "`nInstall Pieces Desktop? [Y/N]" @('y', 'n')) -eq 'y'
                if ($installPieces) {
                    Start-Process "ms-windows-store://pdp/?ProductId=9P5JNQ0XR5W6"
                    Write-Host "  Please complete installation in Microsoft Store window" -ForegroundColor Yellow
                }
            }
        }
    }

    # Desktop shortcuts
    if ($createShortcuts) {
        if (-not $script:SilentMode) {
            Write-Host "`nCreating desktop shortcuts..." -ForegroundColor Cyan
        }

        $codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
        if (Test-Path $codePath) {
            New-DesktopShortcut -Name "Visual Studio Code" -TargetPath $codePath
        }
    }

    # Authenticate Claude
    if ($authenticateAfter) {
        if (-not $script:SilentMode) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Claude Code Authentication" -ForegroundColor Cyan
            Write-Host "========================================`n" -ForegroundColor Cyan
        }

        $authStatus = if (Get-Command Test-ClaudeAuthentication -ErrorAction SilentlyContinue) {
            Test-ClaudeAuthentication
        } else {
            [PSCustomObject]@{IsAuthenticated = $false}
        }

        if (-not $authStatus.IsAuthenticated) {
            $safeDir = "$env:USERPROFILE\ClaudeProjects"
            if (-not (Test-Path $safeDir)) {
                New-Item -ItemType Directory -Path $safeDir -Force | Out-Null
            }

            if (Get-Command Start-ClaudeAuthentication -ErrorAction SilentlyContinue) {
                $authResult = Start-ClaudeAuthentication -WorkingDirectory $safeDir -Method SeparateWindow

                if ($authResult.Success) {
                    if (-not $script:SilentMode) {
                        Write-Host "[OK] Authentication successful!" -ForegroundColor Green
                    }
                    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                        Write-InstallLog -Level Success -Component "Authentication" -Message "Authentication completed"
                    }
                } else {
                    if (-not $script:SilentMode) {
                        Write-Host "[WARNING] Authentication not completed" -ForegroundColor Yellow
                        Write-Host "  You can authenticate later with 'claude' command" -ForegroundColor Gray
                    }
                }
            }
        } else {
            if (-not $script:SilentMode) {
                Write-Host "[OK] Claude is already authenticated" -ForegroundColor Green
            }
        }
    }

    # Install VS Code extensions
    if (-not $script:SilentMode) {
        Write-Host "`nInstalling VS Code extensions..." -ForegroundColor Cyan
    }
    Install-VSCodeExtension -ExtId "Anthropic.claude-dev" -Name "Claude Code Chat"

    # Create safe project folder
    $projectDir = "$env:USERPROFILE\ClaudeProjects"
    if (-not (Test-Path $projectDir)) {
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Set-Content -Path "$projectDir\README.txt" -Value "This is a safe folder for running Claude Code CLI.`nDo not run Claude in system directories (C:\, C:\Windows, etc.)"
    }

    # Generate installation summary
    if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
        $summary = Get-InstallSummary

        Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Installation Summary" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Duration: $($summary.Duration.ToString('mm\:ss'))" -ForegroundColor Gray
        Write-Host "  Successful: $($summary.SuccessCount)" -ForegroundColor Green
        Write-Host "  Warnings: $($summary.WarningCount)" -ForegroundColor Yellow
        Write-Host "  Errors: $($summary.ErrorCount)" -ForegroundColor $(if($summary.ErrorCount -eq 0){'Green'}else{'Red'})

        if ($summary.LogFilePath) {
            Write-Host "  Log: $($summary.LogFilePath)" -ForegroundColor Gray
        }
    }

    # Installation complete
    Write-Host "`n" + ("=" * 60) -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green

    if (-not $script:SilentMode) {
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "  1. Open a NEW terminal window" -ForegroundColor Gray
        Write-Host "  2. Navigate to: $projectDir" -ForegroundColor Gray
        Write-Host "  3. Run: claude" -ForegroundColor Gray
        Write-Host "`nFor VS Code integration, the Claude Code extension is installed.`n" -ForegroundColor Yellow

        Read-Host "Press Enter to exit"
    }

    # Exit with appropriate code
    if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
        $summary = Get-InstallSummary
        exit $summary.ExitCode
    } else {
        # Manual exit code determination
        if ($script:ComponentResults) {
            $failed = $script:ComponentResults.Values | Where-Object { -not $_.Success }
            if ($failed.Count -gt 0) {
                exit 2  # Partial success
            } else {
                exit 0  # Success
            }
        } else {
            exit 0  # Success
        }
    }
}

#endregion

# Initialize script variables
$script:SilentMode = $Silent.IsPresent
$script:ForceInstall = $Force.IsPresent
$script:ComponentResults = @{}

# Run installation
Start-Installation
