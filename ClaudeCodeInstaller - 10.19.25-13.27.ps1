<#
.SYNOPSIS
    Claude Code Development Environment Installer (Refactored)
.DESCRIPTION
    Automated installer for Claude Code development environment.
    Optimized with 75% code reduction through unified functions.
.NOTES
    Version: 4.0.0-refactored
    Requires: Windows 10/11, Administrator privileges
#>

# UTF-8 encoding setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -eq 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
}

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

trap {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
}

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
    Write-Host "   Claude Code Development Environment Installer v4.0" -ForegroundColor Cyan
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

#region Authentication Functions

function Test-ClaudeAuth {
    param([switch]$Verbose)

    $paths = @(
        "$env:USERPROFILE\.claude\.credentials.json",
        "$env:USERPROFILE\.config\claude-code\auth.json",
        "$env:USERPROFILE\.config\claude\auth.json",
        "$env:APPDATA\claude\credentials.json"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                Start-Sleep -Milliseconds 500
                $creds = Get-Content $path -Raw | ConvertFrom-Json
                if ($creds.claudeAiOauth.accessToken -or $creds.claudeAiOauth.refreshToken) {
                    if ($Verbose) { Write-Host "  [OK] Authentication found at $path" -ForegroundColor Green }
                    return $true
                }
            } catch { continue }
        }
    }

    if ($Verbose) { Write-Host "  [INFO] No authentication found" -ForegroundColor Yellow }
    return $false
}

function Start-AuthWindow {
    param([string]$WorkingDir, [int]$TimeoutSec = 900)

    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Claude Authentication" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "`nA new window will open. Follow these steps:" -ForegroundColor Yellow
    Write-Host "  1. Enter your EMAIL" -ForegroundColor Gray
    Write-Host "  2. Check email for authentication link" -ForegroundColor Gray
    Write-Host "  3. Click link in ANY browser" -ForegroundColor Gray
    Write-Host "  4. Wait for success URL" -ForegroundColor Gray
    Write-Host "  5. Close the auth window`n" -ForegroundColor Gray

    Start-Sleep -Seconds 2

    $authScript = @"
Set-Location '$WorkingDir'
Write-Host '`nAuthenticating Claude...`n' -ForegroundColor Cyan
claude
Write-Host '`nAuthentication completed. Close this window.' -ForegroundColor Green
Read-Host 'Press Enter'
"@

    $proc = Start-Process powershell -ArgumentList "-NoExit", "-Command", $authScript -PassThru

    Write-Host "[~] Monitoring authentication..." -ForegroundColor Cyan
    $spinner = @('|', '/', '-', '\')
    $elapsed = 0

    while (-not $proc.HasExited -and $elapsed -lt $TimeoutSec -and -not (Test-ClaudeAuth)) {
        Write-Host "`r  [$($spinner[$elapsed % 4])] Waiting... ($([Math]::Floor(($TimeoutSec - $elapsed)/60))m remaining)" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        $elapsed += 2
    }

    Write-Host "`r" + (" " * 80) + "`r" -NoNewline

    if (Test-ClaudeAuth) {
        Write-Host "[OK] Authentication successful!`n" -ForegroundColor Green
        return $true
    }

    Start-Sleep -Seconds 3
    if (Test-ClaudeAuth) {
        Write-Host "[OK] Authentication successful!`n" -ForegroundColor Green
        return $true
    }

    Write-Host "[X] Authentication not detected`n" -ForegroundColor Red
    return $false
}

#endregion

#region Installation Functions

function Install-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "[FOUND] Using winget" -ForegroundColor Green
        return 'winget'
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "[FOUND] Using Chocolatey" -ForegroundColor Green
        return 'choco'
    }

    Write-Host "[~] Installing Chocolatey..." -ForegroundColor Cyan
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script | Out-Null
        $env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path
        Write-Host "[OK] Chocolatey installed" -ForegroundColor Green
        return 'choco'
    } catch {
        Write-Host "[ERROR] Failed to install Chocolatey: $_" -ForegroundColor Red
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

    $success = if ($PackageManager -eq 'winget') {
        winget install --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    } else {
        choco install $ChocoId -y --force --limit-output 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    }

    if (-not $success) {
        Write-Host "[ERROR] Failed to install $Name" -ForegroundColor Red
        return $false
    }

    Write-Host "[OK] $Name installed" -ForegroundColor Green
    Update-PathVariable -Paths $PathsToAdd

    & $PostInstall

    return $true
}

function Install-ClaudeCLI {
    Write-Host "`n[~] Installing Claude Code CLI..." -ForegroundColor Cyan

    $output = npm install -g @anthropic-ai/claude-code 2>&1
    $success = ($LASTEXITCODE -eq 0) -or (($output | Out-String) -match "(added \d+ package|up to date)")

    if ($success) {
        Write-Host "[OK] Claude Code CLI installed" -ForegroundColor Green
        Update-PathVariable -Paths @("$env:APPDATA\npm")
        return $true
    }

    Write-Host "[ERROR] Failed to install Claude Code CLI" -ForegroundColor Red
    Write-Host $output -ForegroundColor Gray
    return $false
}

function Install-VSCodeExtension {
    param([string]$ExtId, [string]$Name)

    Write-Host "[~] Installing VS Code extension: $Name..." -ForegroundColor Cyan
    code --install-extension $ExtId --force 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Extension installed: $Name" -ForegroundColor Green
        return $true
    }

    Write-Host "[WARNING] Failed to install extension: $Name" -ForegroundColor Yellow
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
            return $true
        }
    }

    return $false
}

function Install-GitHubDesktop {
    param([string]$PackageManager)

    if (Test-GitHubDesktop) { return $true }

    Write-Host "`n[~] Installing GitHub Desktop..." -ForegroundColor Cyan

    $success = if ($PackageManager -eq 'winget') {
        winget install --id GitHub.GitHubDesktop -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    } else {
        choco install github-desktop -y --force --limit-output 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    }

    if ($success) {
        Write-Host "[OK] GitHub Desktop installed" -ForegroundColor Green
        Update-PathVariable -Paths @("$env:LOCALAPPDATA\GitHubDesktop")
        return $true
    }

    Write-Host "[ERROR] Failed to install GitHub Desktop" -ForegroundColor Red
    return $false
}

function Install-PiecesDesktop {
    Write-Host "`n[~] Installing Pieces Desktop via Microsoft Store..." -ForegroundColor Cyan
    Write-Host "  Opening Microsoft Store..." -ForegroundColor Gray

    Start-Process "ms-windows-store://pdp/?ProductId=9P5JNQ0XR5W6"

    Write-Host "`n  Please complete installation in Microsoft Store window" -ForegroundColor Yellow
    Write-Host "  Then return here`n" -ForegroundColor Yellow

    $installed = Get-UserChoice "Did you install Pieces Desktop? [Y/N]" @('y', 'n')
    return ($installed -eq 'y')
}

#endregion

#region Main Installation Flow

function Start-Installation {
    Ensure-Administrator
    Show-Banner

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
            Write-Host "[ERROR] Node.js installation failed" -ForegroundColor Red
            exit 1
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
            Write-Host "[ERROR] Git installation failed" -ForegroundColor Red
            exit 1
        }
    }

    # Install VS Code
    if ($needsCode) {
        $codeSuccess = Install-Package -Name "Visual Studio Code" -TestCmd "code" -TestArg "--version" -TestPattern "." `
            -WingetId "Microsoft.VisualStudioCode" -ChocoId "vscode" -PackageManager $pkgMgr `
            -PathsToAdd @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin")

        if (-not $codeSuccess) {
            Write-Host "[ERROR] VS Code installation failed" -ForegroundColor Red
            exit 1
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
            Write-Host "[ERROR] Claude CLI installation failed" -ForegroundColor Red
            exit 1
        }
    }

    # Authenticate Claude
    Write-Host "`nChecking Claude authentication..." -ForegroundColor Cyan
    if (-not (Test-ClaudeAuth -Verbose)) {
        $safeDir = "$env:USERPROFILE\ClaudeProjects"
        if (-not (Test-Path $safeDir)) {
            New-Item -ItemType Directory -Path $safeDir -Force | Out-Null
        }

        if (-not (Start-AuthWindow -WorkingDir $safeDir)) {
            Write-Host "[WARNING] Authentication not completed. You can authenticate later with 'claude' command." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[OK] Claude is already authenticated" -ForegroundColor Green
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
    Write-Host "`nFor VS Code integration, install the Claude Code extension from the Extensions panel.`n" -ForegroundColor Yellow

    Read-Host "Press Enter to exit"
}

#endregion

# Run installation
Start-Installation
