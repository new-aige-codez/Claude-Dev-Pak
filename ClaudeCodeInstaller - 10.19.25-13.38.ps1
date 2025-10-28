<#
.SYNOPSIS
    Claude Code Development Environment Installer (Modular)
.DESCRIPTION
    Automated installer for Claude Code development environment.
    Uses modular architecture with separate Authentication and ErrorHandling modules.
.NOTES
    Version: 4.1.0-modular
    Requires: Windows 10/11, Administrator privileges
#>

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

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

#region Core Utility Functions

function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevating to administrator..." -ForegroundColor Yellow
        Start-Process PowerShell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}

function Show-Banner {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   Claude Code Development Environment Installer v4.1" -ForegroundColor Cyan
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
            Write-Host "[FOUND] $Name already installed. Skipping." -ForegroundColor Green
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
        if (-not ($env:Path -like "*$path*")) {
            $env:Path = "$path;$env:Path"
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

        Write-Host "[OK] Created shortcut: $Name" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WARNING] Failed to create shortcut: $Name" -ForegroundColor Yellow
        return $false
    }
}

#endregion

#region Installation Functions

function Install-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "[FOUND] Using winget" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "PackageManager" -Message "Using winget"
        }
        return 'winget'
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "[FOUND] Using Chocolatey" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "PackageManager" -Message "Using Chocolatey"
        }
        return 'choco'
    }

    Write-Host "[~] Installing Chocolatey..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "Chocolatey" -Message "Installing Chocolatey package manager"
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script | Out-Null
        $env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path
        Write-Host "[OK] Chocolatey installed" -ForegroundColor Green
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

function Install-Package {
    param(
        [string]$Name,
        [string]$TestCmd,
        [string]$TestArg,
        [string]$TestPattern,
        [string]$WingetId,
        [string]$ChocoId,
        [string]$PackageManager,
        [string[]]$PathsToAdd = @(),
        [scriptblock]$PostInstall = {}
    )

    if (Test-Tool -Command $TestCmd -Arg $TestArg -Pattern $TestPattern -Name $Name) {
        return $true
    }

    Write-Host "`n[~] Installing $Name..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component $Name -Message "Starting installation"
    }

    try {
        $success = if ($PackageManager -eq 'winget') {
            winget install --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
            $LASTEXITCODE -eq 0
        } else {
            choco install $ChocoId -y --force --limit-output 2>&1 | Out-Null
            $LASTEXITCODE -eq 0
        }

        if (-not $success) {
            Write-Host "[ERROR] Failed to install $Name" -ForegroundColor Red
            if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
                Add-InstallError -ErrorRecord "Package manager install failed" -Component $Name -Critical
            }
            return $false
        }

        Write-Host "[OK] $Name installed" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Success -Component $Name -Message "Installation completed"
        }

        Update-PathVariable -Paths $PathsToAdd
        & $PostInstall

        return $true

    } catch {
        Write-Host "[ERROR] Exception during installation: $_" -ForegroundColor Red
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord $_ -Component $Name -Critical
        }
        return $false
    }
}

function Install-ClaudeCLI {
    Write-Host "`n[~] Installing Claude Code CLI..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "ClaudeCLI" -Message "Starting npm installation"
    }

    try {
        $output = npm install -g @anthropic-ai/claude-code 2>&1
        $success = ($LASTEXITCODE -eq 0) -or (($output | Out-String) -match "(added \d+ package|up to date)")

        if ($success) {
            Write-Host "[OK] Claude Code CLI installed" -ForegroundColor Green
            if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                Write-InstallLog -Level Success -Component "ClaudeCLI" -Message "npm install successful"
            }
            Update-PathVariable -Paths @("$env:APPDATA\npm")
            return $true
        } else {
            Write-Host "[ERROR] Failed to install Claude Code CLI" -ForegroundColor Red
            Write-Host $output -ForegroundColor Gray
            if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
                Add-InstallError -ErrorRecord "npm install failed: $output" -Component "ClaudeCLI" -Critical
            }
            return $false
        }
    } catch {
        Write-Host "[ERROR] Exception during Claude CLI installation: $_" -ForegroundColor Red
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord $_ -Component "ClaudeCLI" -Critical
        }
        return $false
    }
}

function Install-VSCodeExtension {
    param([string]$ExtId, [string]$Name)

    Write-Host "[~] Installing VS Code extension: $Name..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "VSCode Extension" -Message "Installing $Name"
    }

    code --install-extension $ExtId --force 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Extension installed: $Name" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Success -Component "VSCode Extension" -Message "$Name installed"
        }
        return $true
    }

    Write-Host "[WARNING] Failed to install extension: $Name" -ForegroundColor Yellow
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Warning -Component "VSCode Extension" -Message "Failed to install $Name"
    }
    return $false
}

function Test-GitHubDesktop {
    $paths = @(
        "$env:LOCALAPPDATA\GitHubDesktop",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GitHub Desktop.lnk"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "[FOUND] GitHub Desktop already installed. Skipping." -ForegroundColor Green
            if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                Write-InstallLog -Level Info -Component "GitHub Desktop" -Message "Already installed, skipping"
            }
            return $true
        }
    }

    return $false
}

function Install-GitHubDesktop {
    param([string]$PackageManager)

    if (Test-GitHubDesktop) { return $true }

    Write-Host "`n[~] Installing GitHub Desktop..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "GitHub Desktop" -Message "Starting installation"
    }

    try {
        $success = if ($PackageManager -eq 'winget') {
            winget install --id GitHub.GitHubDesktop -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            $LASTEXITCODE -eq 0
        } else {
            choco install github-desktop -y --force --limit-output 2>&1 | Out-Null
            $LASTEXITCODE -eq 0
        }

        if ($success) {
            Write-Host "[OK] GitHub Desktop installed" -ForegroundColor Green
            if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                Write-InstallLog -Level Success -Component "GitHub Desktop" -Message "Installation successful"
            }
            Update-PathVariable -Paths @("$env:LOCALAPPDATA\GitHubDesktop")
            return $true
        }

        Write-Host "[ERROR] Failed to install GitHub Desktop" -ForegroundColor Red
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord "Installation failed" -Component "GitHub Desktop"
        }
        return $false

    } catch {
        Write-Host "[ERROR] Exception during GitHub Desktop installation: $_" -ForegroundColor Red
        if (Get-Command Add-InstallError -ErrorAction SilentlyContinue) {
            Add-InstallError -ErrorRecord $_ -Component "GitHub Desktop"
        }
        return $false
    }
}

function Install-PiecesDesktop {
    Write-Host "`n[~] Installing Pieces Desktop via Microsoft Store..." -ForegroundColor Cyan
    Write-Host "  Opening Microsoft Store..." -ForegroundColor Gray
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "Pieces Desktop" -Message "Opening Microsoft Store for manual installation"
    }

    Start-Process "ms-windows-store://pdp/?ProductId=9P5JNQ0XR5W6"

    Write-Host "`n  Please complete installation in Microsoft Store window" -ForegroundColor Yellow
    Write-Host "  Then return here`n" -ForegroundColor Yellow

    $installed = Get-UserChoice "Did you install Pieces Desktop? [Y/N]" @('y', 'n')

    if ($installed -eq 'y') {
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Success -Component "Pieces Desktop" -Message "User confirmed installation"
        }
        return $true
    } else {
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "Pieces Desktop" -Message "User skipped installation"
        }
        return $false
    }
}

#endregion

#region Main Installation Flow

function Start-Installation {
    Ensure-Administrator
    Show-Banner

    # Initialize logging
    if (Get-Command Initialize-InstallLog -ErrorAction SilentlyContinue) {
        $script:LogPath = Initialize-InstallLog
        Write-InstallLog -Level Info -Component "Installer" -Message "Installation started - Version 4.1.0-modular"
    }

    Write-Host "This installer will set up your Claude Code development environment.`n" -ForegroundColor Cyan

    # Show requirements
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Disk Space Requirements" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Core Installation:  ~2 GB free space" -ForegroundColor Yellow
    Write-Host "  Full Installation:  ~4.5 GB free space`n" -ForegroundColor Yellow

    # Desktop shortcuts preference
    $createShortcuts = (Get-UserChoice "Create desktop shortcuts? [Y/N]" @('y', 'n')) -eq 'y'
    Write-Host ""

    # Installation type
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Installation Type" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  [C] Core (~1.1 GB): Node.js, Git, VS Code, Claude CLI" -ForegroundColor White
    Write-Host "  [F] Full (~2.3 GB): Core + GitHub Desktop + Pieces Desktop`n" -ForegroundColor Green

    $installType = Get-UserChoice "Select [C]ore or [F]ull" @('c', 'f')
    $fullInstall = ($installType -eq 'f')

    Write-Host "`n[OK] $( if($fullInstall){'Full'}else{'Core'} ) installation selected`n" -ForegroundColor Green
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "Installer" -Message "Installation type: $( if($fullInstall){'Full'}else{'Core'} )"
    }

    Read-Host "Press Enter to begin installation"
    Write-Host ""

    # Detect existing tools
    Write-Host "Checking for existing installations..." -ForegroundColor Cyan
    $needsNode = -not (Test-Tool "node" "--version" "^v" "Node.js")
    $needsGit = -not (Test-Tool "git" "--version" "git version" "Git")
    $needsCode = -not (Test-Tool "code" "--version" "." "VS Code")
    $needsClaude = -not (Test-Tool "claude" "--version" "." "Claude CLI")

    # Install package manager if needed
    $pkgMgr = $null
    if ($needsNode -or $needsGit -or $needsCode -or $fullInstall) {
        Write-Host "`nDetecting package manager..." -ForegroundColor Cyan
        $pkgMgr = Install-PackageManager
    }

    # Install Node.js
    if ($needsNode) {
        $nodeSuccess = Install-Package -Name "Node.js 20 LTS" -TestCmd "node" -TestArg "--version" -TestPattern "^v" `
            -WingetId "OpenJS.NodeJS.LTS" -ChocoId "nodejs-lts" -PackageManager $pkgMgr `
            -PathsToAdd @("C:\Program Files\nodejs", "$env:APPDATA\npm") `
            -PostInstall {
                $version = node --version 2>&1
                Write-Host "  Installed version: $version" -ForegroundColor Gray
            }

        if (-not $nodeSuccess) {
            Write-Host "[ERROR] Node.js installation failed - Cannot continue" -ForegroundColor Red
            if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
                $summary = Get-InstallSummary
                exit $summary.ExitCode
            } else {
                exit 1
            }
        }
    }

    # Install Git
    if ($needsGit) {
        $gitSuccess = Install-Package -Name "Git" -TestCmd "git" -TestArg "--version" -TestPattern "git version" `
            -WingetId "Git.Git" -ChocoId "git" -PackageManager $pkgMgr `
            -PathsToAdd @("C:\Program Files\Git\cmd") `
            -PostInstall {
                $gitBash = "C:\Program Files\Git\bin\bash.exe"
                if (Test-Path $gitBash) {
                    $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBash
                    [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBash, "User")
                }
            }

        if (-not $gitSuccess) {
            Write-Host "[ERROR] Git installation failed - Cannot continue" -ForegroundColor Red
            if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
                $summary = Get-InstallSummary
                exit $summary.ExitCode
            } else {
                exit 1
            }
        }
    }

    # Install VS Code
    if ($needsCode) {
        $codeSuccess = Install-Package -Name "Visual Studio Code" -TestCmd "code" -TestArg "--version" -TestPattern "." `
            -WingetId "Microsoft.VisualStudioCode" -ChocoId "vscode" -PackageManager $pkgMgr `
            -PathsToAdd @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin")

        if (-not $codeSuccess) {
            Write-Host "[ERROR] VS Code installation failed - Cannot continue" -ForegroundColor Red
            if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
                $summary = Get-InstallSummary
                exit $summary.ExitCode
            } else {
                exit 1
            }
        }

        if ($createShortcuts) {
            $codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
            if (Test-Path $codePath) {
                New-DesktopShortcut -Name "Visual Studio Code" -TargetPath $codePath
            }
        }
    }

    # Install Claude CLI
    if ($needsClaude) {
        if (-not (Install-ClaudeCLI)) {
            Write-Host "[ERROR] Claude CLI installation failed - Cannot continue" -ForegroundColor Red
            if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
                $summary = Get-InstallSummary
                exit $summary.ExitCode
            } else {
                exit 1
            }
        }
    }

    # Authenticate Claude
    Write-Host "`nChecking Claude authentication..." -ForegroundColor Cyan
    if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
        Write-InstallLog -Level Info -Component "Authentication" -Message "Checking authentication status"
    }

    $authStatus = if (Get-Command Test-ClaudeAuthentication -ErrorAction SilentlyContinue) {
        Test-ClaudeAuthentication -Verbose
    } else {
        # Fallback if module not loaded
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
                Write-Host "[OK] Authentication successful!" -ForegroundColor Green
                if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                    Write-InstallLog -Level Success -Component "Authentication" -Message "Authentication completed in $($authResult.TimeTaken.TotalSeconds)s"
                }
            } else {
                Write-Host "[WARNING] Authentication not completed" -ForegroundColor Yellow
                Write-Host "  You can authenticate later with 'claude' command" -ForegroundColor Gray
                if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
                    Write-InstallLog -Level Warning -Component "Authentication" -Message "Authentication incomplete: $($authResult.ErrorMessage)"
                }
            }
        } else {
            Write-Host "[WARNING] Authentication module not available - skipping" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[OK] Claude is already authenticated" -ForegroundColor Green
        if (Get-Command Write-InstallLog -ErrorAction SilentlyContinue) {
            Write-InstallLog -Level Info -Component "Authentication" -Message "Already authenticated at $($authStatus.CredentialPath)"
        }
    }

    # Install VS Code extensions
    if ($needsCode -or $needsClaude) {
        Write-Host "`nInstalling VS Code extensions..." -ForegroundColor Cyan
        Install-VSCodeExtension -ExtId "Anthropic.claude-dev" -Name "Claude Code Chat"
    }

    # Full installation components
    if ($fullInstall) {
        Install-GitHubDesktop -PackageManager $pkgMgr

        $installPieces = (Get-UserChoice "`nInstall Pieces Desktop? [Y/N]" @('y', 'n')) -eq 'y'
        if ($installPieces) {
            Install-PiecesDesktop
        }
    }

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

        if ($summary.ErrorCount -gt 0) {
            Write-Host "`n  Errors encountered:" -ForegroundColor Red
            foreach ($err in $summary.Errors) {
                Write-Host "    [$($err.Component)] $($err.Message)" -ForegroundColor Red
            }
        }

        if ($summary.WarningCount -gt 0) {
            Write-Host "`n  Warnings:" -ForegroundColor Yellow
            foreach ($warn in $summary.Warnings) {
                Write-Host "    [$($warn.Component)] $($warn.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Installation complete
    Write-Host "`n" + ("=" * 60) -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "`nInstalled components:" -ForegroundColor Cyan
    if ($needsNode) { Write-Host "  ✓ Node.js" -ForegroundColor Green }
    if ($needsGit) { Write-Host "  ✓ Git" -ForegroundColor Green }
    if ($needsCode) { Write-Host "  ✓ VS Code" -ForegroundColor Green }
    if ($needsClaude) { Write-Host "  ✓ Claude Code CLI" -ForegroundColor Green }
    if ($fullInstall) {
        Write-Host "  ✓ GitHub Desktop" -ForegroundColor Green
        Write-Host "  ✓ Pieces Desktop (if selected)" -ForegroundColor Green
    }

    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Open a NEW terminal window" -ForegroundColor Gray
    Write-Host "  2. Navigate to: $projectDir" -ForegroundColor Gray
    Write-Host "  3. Run: claude" -ForegroundColor Gray
    Write-Host "`nFor VS Code integration, the Claude Code extension is installed.`n" -ForegroundColor Yellow

    Read-Host "Press Enter to exit"

    # Exit with appropriate code
    if (Get-Command Get-InstallSummary -ErrorAction SilentlyContinue) {
        $summary = Get-InstallSummary
        exit $summary.ExitCode
    } else {
        exit 0
    }
}

#endregion

# Run installation
Start-Installation
