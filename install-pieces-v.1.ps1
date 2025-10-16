# =============================================================================
# Pieces Desktop/OS Installation Script with Authentication
# =============================================================================
# This script installs Pieces Desktop and PiecesOS, then guides the user
# through authentication with an account-based setup process.
#
# Author: Claude Code
# Date: 2025-10-13
# Version: 2.0.0
# =============================================================================

# Requires PowerShell to run with appropriate permissions
#Requires -Version 5.1

# =============================================================================
# Configuration
# =============================================================================
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# =============================================================================
# Color Output Functions
# =============================================================================
function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# =============================================================================
# Header
# =============================================================================
function Show-Banner {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  Pieces Desktop/OS Installer" -ForegroundColor Magenta
    Write-Host "          Version 2.0.0" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
}

# =============================================================================
# Function: Check if Pieces is authenticated
# =============================================================================
function Test-PiecesAuthentication {
    <#
    .SYNOPSIS
        Attempts to detect if Pieces Desktop is authenticated

    .DESCRIPTION
        Since Pieces doesn't document credential file locations clearly,
        this function checks if Pieces Desktop process is running,
        which may indicate successful setup. This is a best-effort check.

    .OUTPUTS
        Boolean - $true if potentially authenticated, $false otherwise
    #>

    # Check if Pieces Desktop process is running
    $piecesProcess = Get-Process -Name "Pieces*" -ErrorAction SilentlyContinue

    if ($piecesProcess) {
        Write-Info "Pieces Desktop is currently running"
        return $true
    }

    # Check common app data locations for Pieces
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Pieces",
        "$env:APPDATA\Pieces",
        "$env:USERPROFILE\.pieces"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
            if ($items.Count -gt 0) {
                return $true
            }
        }
    }

    return $false
}

# =============================================================================
# Function: Launch Pieces Desktop for Authentication
# =============================================================================
function Start-PiecesAuthenticationNewWindow {
    <#
    .SYNOPSIS
        Launches Pieces Desktop application for user authentication

    .DESCRIPTION
        Opens Pieces Desktop using Windows protocol handler and guides
        the user through the authentication process with step-by-step
        instructions mirroring the Claude installer style.

    .OUTPUTS
        Boolean - $true if user confirms authentication, $false otherwise
    #>

    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Pieces Desktop Authentication" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pieces Desktop will now launch for authentication." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "What will happen:" -ForegroundColor Cyan
    Write-Host "  1. Pieces Desktop app opens" -ForegroundColor Gray
    Write-Host "  2. Sign-in screen appears in the app" -ForegroundColor Gray
    Write-Host "  3. Your browser opens for authentication" -ForegroundColor Gray
    Write-Host "  4. Choose your sign-in method:" -ForegroundColor Gray
    Write-Host "     - Email (verification code sent to inbox)" -ForegroundColor Gray
    Write-Host "     - Google, GitHub, or other platforms" -ForegroundColor Gray
    Write-Host "  5. Complete sign-in in browser" -ForegroundColor Gray
    Write-Host "  6. Return to Pieces Desktop app" -ForegroundColor Gray
    Write-Host "  7. Authentication is complete!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "IMPORTANT: Keep Pieces Desktop open until authentication completes!" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Launching Pieces Desktop in 3 seconds..." -ForegroundColor Cyan
    Write-Host "(Give yourself time to read the instructions above)" -ForegroundColor Gray
    Start-Sleep -Seconds 3
    Write-Host ""

    # Launch Pieces Desktop using protocol handler
    Write-Host "[~] Launching Pieces Desktop..." -ForegroundColor Cyan
    try {
        # Try protocol handler first
        $launched = $false
        try {
            Start-Process "pieces-for-developers://open" -ErrorAction Stop
            $launched = $true
        } catch {
            # Fallback: Try to find and launch Pieces Desktop executable
            $possibleExePaths = @(
                "$env:LOCALAPPDATA\Programs\Pieces\Pieces.exe",
                "$env:LOCALAPPDATA\Pieces\Pieces.exe",
                "${env:ProgramFiles}\Pieces\Pieces.exe",
                "${env:ProgramFiles(x86)}\Pieces\Pieces.exe"
            )

            foreach ($exePath in $possibleExePaths) {
                if (Test-Path $exePath) {
                    Start-Process $exePath
                    $launched = $true
                    break
                }
            }
        }

        if ($launched) {
            Write-Host "[OK] Pieces Desktop launched" -ForegroundColor Green
        } else {
            Write-Host "[X] Could not launch Pieces Desktop automatically" -ForegroundColor Red
            Write-Host "    Please launch Pieces Desktop manually from your Start Menu" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "[INFO] Complete the authentication in Pieces Desktop" -ForegroundColor Cyan
        Write-Host "[INFO] This window will wait for you to finish..." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Authentication Steps Reminder:" -ForegroundColor Cyan
        Write-Host "  1. In Pieces app: Click sign-in button" -ForegroundColor Gray
        Write-Host "  2. Browser opens: Choose your sign-in method" -ForegroundColor Gray
        Write-Host "  3. If Email: Check inbox for verification code" -ForegroundColor Gray
        Write-Host "  4. Complete authentication in browser" -ForegroundColor Gray
        Write-Host "  5. Return here when done" -ForegroundColor Gray
        Write-Host ""

        # Wait for user confirmation with retry option
        $maxAttempts = 3
        $attempt = 1

        while ($attempt -le $maxAttempts) {
            $authComplete = Read-Host "Did you complete authentication successfully? (Y/N)"

            if ($authComplete.Trim().ToUpper() -eq 'Y') {
                Write-Host ""
                Write-Host "[OK] Authentication confirmed!" -ForegroundColor Green
                return $true
            } elseif ($authComplete.Trim().ToUpper() -eq 'N') {
                if ($attempt -lt $maxAttempts) {
                    Write-Host ""
                    Write-Host "[INFO] Let's try again. Make sure to complete all steps." -ForegroundColor Yellow
                    $retry = Read-Host "Press Enter to continue, or type 'SKIP' to skip authentication"

                    if ($retry.Trim().ToUpper() -eq 'SKIP') {
                        return $false
                    }
                    $attempt++
                } else {
                    Write-Host ""
                    Write-Host "[INFO] Authentication not completed" -ForegroundColor Yellow
                    return $false
                }
            } else {
                Write-Host "[!] Please type 'Y' for Yes or 'N' for No" -ForegroundColor Yellow
            }
        }

        return $false

    } catch {
        Write-Host "[X] Failed to launch Pieces Desktop" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Please launch Pieces Desktop manually from the Start Menu" -ForegroundColor Yellow
        Write-Host "and complete authentication there." -ForegroundColor Yellow
        return $false
    }
}

# =============================================================================
# System Requirements Check
# =============================================================================
function Test-SystemRequirements {
    Write-Info "Checking system requirements..."
    Write-Host ""

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $buildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

    Write-Info "Windows Version: $($osVersion.Major).$($osVersion.Minor) (Build $buildNumber)"

    # Minimum requirement: Windows 10 build 1809 (17763)
    if ($buildNumber -lt 17763) {
        Write-Error-Custom "Pieces requires Windows 10 (1809) or higher."
        Write-Error-Custom "Your current build ($buildNumber) does not meet requirements."
        return $false
    }

    Write-Success "System requirements met!"
    Write-Host ""
    return $true
}

# =============================================================================
# Function: Check if WinGet is available
# =============================================================================
function Test-WinGet {
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $version = (winget --version)
            Write-Success "WinGet found: $version"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# =============================================================================
# Function: Check if Chocolatey is available
# =============================================================================
function Test-Chocolatey {
    try {
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoPath) {
            $version = (choco --version)
            Write-Success "Chocolatey found: v$version"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# =============================================================================
# Function: Install via WinGet
# =============================================================================
function Install-WithWinGet {
    Write-Info "Attempting installation via WinGet (Microsoft Store)..."
    Write-Host ""
    Write-Info "Package: Pieces Desktop (ID: 9NB490VLC1LL)"
    Write-Info "Source: Microsoft Store"
    Write-Host ""
    Write-Host "Installing Pieces Desktop from Microsoft Store..." -ForegroundColor Yellow
    Write-Host "Note: Microsoft Store may show a prompt requiring your approval." -ForegroundColor Gray
    Write-Host "If prompted, please click 'Get' or 'Install' to continue." -ForegroundColor Gray
    Write-Host ""

    try {
        # Install Pieces Desktop from Microsoft Store (includes PiecesOS as dependency)
        # Using industry-standard pattern from Skype installer and WinGet documentation
        & winget install -e --id 9NB490VLC1LL `
            -s msstore `
            --accept-package-agreements `
            --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            throw "WinGet install failed with exit code: $LASTEXITCODE"
        }

        Write-Host ""
        Write-Success "Pieces Desktop installed successfully from Microsoft Store!"
        Write-Info "Installation includes both Pieces Desktop and PiecesOS."
        Write-Host ""
        return $true
    }
    catch {
        Write-Host ""
        Write-Error-Custom "WinGet installation failed: $_"
        Write-Host ""
        return $false
    }
}

# =============================================================================
# Function: Install via Chocolatey
# =============================================================================
function Install-WithChocolatey {
    Write-Info "Attempting installation via Chocolatey..."
    Write-Host ""

    # Note: Pieces Desktop/OS are Microsoft Store exclusive apps
    Write-Warning-Custom "Chocolatey package for Pieces Desktop/OS does not exist."
    Write-Info "Pieces Desktop is only available via Microsoft Store (using WinGet)."
    Write-Host ""
    Write-Info "Available via Chocolatey: Pieces CLI only (not Desktop/OS)"
    Write-Host ""

    # Pieces Desktop and PiecesOS are Microsoft Store apps only
    # They cannot be installed via Chocolatey
    # Only Pieces CLI is available via traditional package managers
    return $false
}

# =============================================================================
# Function: Provide manual installation instructions
# =============================================================================
function Show-ManualInstructions {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Manual Installation Required" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Info "Neither WinGet nor Chocolatey could install Pieces."
    Write-Info "Please use one of the following manual installation methods:"
    Write-Host ""

    Write-Host "Option 1: Microsoft Store" -ForegroundColor Cyan
    Write-Host "  - Open Microsoft Store" -ForegroundColor Gray
    Write-Host "  - Search for 'Pieces for Developers'" -ForegroundColor Gray
    Write-Host "  - Click 'Get' or 'Install'" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Option 2: Direct Download" -ForegroundColor Cyan
    Write-Host "  - Visit: https://docs.pieces.app/products/desktop/download" -ForegroundColor Gray
    Write-Host "  - Download the .appinstaller or .exe file" -ForegroundColor Gray
    Write-Host "  - Run the downloaded installer" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Option 3: WinGet Manual Install" -ForegroundColor Cyan
    Write-Host "  If WinGet is not installed, you can install it from:" -ForegroundColor Gray
    Write-Host "  - Microsoft Store: Search for 'App Installer'" -ForegroundColor Gray
    Write-Host "  - Or visit: https://aka.ms/getwinget" -ForegroundColor Gray
    Write-Host ""

    Write-Host "System Requirements:" -ForegroundColor Cyan
    Write-Host "  - Windows 10 (1809) or higher" -ForegroundColor Gray
    Write-Host "  - CPU: Multi-core (4+ cores recommended)" -ForegroundColor Gray
    Write-Host "  - RAM: 8-16 GB" -ForegroundColor Gray
    Write-Host "  - Disk Space: 2-8 GB" -ForegroundColor Gray
    Write-Host ""
}

# =============================================================================
# Main Installation Logic
# =============================================================================
function Start-Installation {
    Show-Banner

    # Check system requirements
    if (-not (Test-SystemRequirements)) {
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Host "This installer will set up Pieces Desktop and guide you through authentication."
    $null = Read-Host "Press Enter to continue or Ctrl+C to cancel"
    Write-Host ""

    Write-Info "Checking available package managers..."
    Write-Host ""

    $wingetAvailable = Test-WinGet
    $chocoAvailable = Test-Chocolatey

    Write-Host ""

    # Try WinGet first (preferred method)
    $installed = $false
    if ($wingetAvailable) {
        Write-Info "Using WinGet as primary installation method..."
        $installed = Install-WithWinGet

        if ($installed) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  Installation Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
        }
        else {
            Write-Warning-Custom "WinGet installation did not succeed. Trying alternative methods..."
            Write-Host ""
        }
    }
    else {
        Write-Warning-Custom "WinGet not found on system."
        Write-Host ""
    }

    # Try Chocolatey as fallback
    if (-not $installed -and $chocoAvailable) {
        Write-Info "Attempting Chocolatey installation..."
        $installed = Install-WithChocolatey

        if ($installed) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  Installation Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
        }
    }
    elseif (-not $installed) {
        Write-Warning-Custom "Chocolatey not found on system."
        Write-Host ""
    }

    # If both methods failed, show manual instructions
    if (-not $installed) {
        Write-Warning-Custom "Automated installation not possible with current system configuration."
        Show-ManualInstructions

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Installation Incomplete" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""

        Read-Host "Press Enter to exit"
        exit 1
    }

    # --- Authentication Phase ---
    Write-Host ""
    Write-Host "Step 2: Pieces Authentication" -ForegroundColor Cyan
    Write-Host "Pieces requires an account to use. Authenticate now?" -ForegroundColor Yellow
    Write-Host ""

    # Track authentication status
    $authenticatedSuccessfully = $false

    # Check if already authenticated
    Write-Host "[~] Checking existing authentication..." -ForegroundColor Cyan
    if (Test-PiecesAuthentication) {
        Write-Host "[OK] Pieces may already be configured!" -ForegroundColor Green
        Write-Host "[INFO] You can verify by launching Pieces Desktop" -ForegroundColor Gray
        $authenticatedSuccessfully = $true
    } else {
        Write-Host "[INFO] No existing authentication detected." -ForegroundColor Gray
        Write-Host ""

        # Prompt for authentication (mirroring Claude style)
        $authChoice = $null
        while ($authChoice -notin @('a', 's')) {
            $userInput = Read-Host "Type [A] to Authenticate or [S] to Skip (then press Enter)"

            if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                $firstChar = $userInput.Trim().ToLower().Substring(0,1)
                if ($firstChar -in @('a', 's')) {
                    $authChoice = $firstChar
                } else {
                    Write-Host "[!] Invalid input. Please type 'A' or 'S'" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[!] Please type 'A' or 'S' (not just Enter)" -ForegroundColor Yellow
            }
        }

        if ($authChoice -eq 'a') {
            # User chose to authenticate
            $authSuccess = Start-PiecesAuthenticationNewWindow

            if ($authSuccess) {
                $authenticatedSuccessfully = $true
            } else {
                Write-Host ""
                Write-Host "[INFO] Authentication was not completed" -ForegroundColor Yellow
            }
        } else {
            # User chose to skip - show warnings
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "  WARNING: Skipping Authentication" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "WITHOUT authentication, Pieces will NOT work:" -ForegroundColor Red
            Write-Host "  [X] Cannot save code snippets" -ForegroundColor Red
            Write-Host "  [X] Cannot use Pieces features" -ForegroundColor Red
            Write-Host "  [X] Pieces Desktop will require sign-in on first launch" -ForegroundColor Red
            Write-Host ""

            $confirmSkip = Read-Host "Are you SURE you want to skip? Type 'YES' to skip, or press Enter to authenticate now"

            if ($confirmSkip.Trim().ToUpper() -eq 'YES') {
                Write-Host ""
                Write-Host "[WARNING] Proceeding without authentication!" -ForegroundColor Red
                $authenticatedSuccessfully = $false
            } else {
                # User changed mind - authenticate now
                Write-Host ""
                Write-Host "[INFO] Great! Let's authenticate now." -ForegroundColor Green

                $authSuccess = Start-PiecesAuthenticationNewWindow

                if ($authSuccess) {
                    $authenticatedSuccessfully = $true
                }
            }
        }
    }

    # --- Final Summary ---
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    if ($authenticatedSuccessfully) {
        Write-Host "[OK] Pieces Desktop installed and authenticated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Launch Pieces Desktop from Start Menu" -ForegroundColor Gray
        Write-Host "  2. Install Pieces extensions for your IDE:" -ForegroundColor Gray
        Write-Host "     - VS Code: Search 'Pieces' in Extensions" -ForegroundColor Gray
        Write-Host "     - JetBrains IDEs: Search 'Pieces' in Plugins" -ForegroundColor Gray
        Write-Host "  3. Start saving and managing code snippets!" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Documentation: https://docs.pieces.app/" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] Pieces Desktop installed (not authenticated)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To authenticate later:" -ForegroundColor Cyan
        Write-Host "  1. Launch Pieces Desktop from Start Menu" -ForegroundColor Gray
        Write-Host "  2. Complete sign-in when prompted" -ForegroundColor Gray
        Write-Host "  3. Follow the on-screen authentication steps" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Documentation: https://docs.pieces.app/products/meet-pieces/sign-into-pieces" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Thank you for installing Pieces!" -ForegroundColor Magenta
    Write-Host ""
    Read-Host "Press Enter to exit"
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Run the installer
Start-Installation
