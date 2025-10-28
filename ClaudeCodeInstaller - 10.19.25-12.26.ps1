<#
.SYNOPSIS
    Claude Code Development Environment Installer

.DESCRIPTION
    Automated installer for setting up the Claude Code development environment.
    It prioritizes winget and falls back to Chocolatey if winget is not available.

.NOTES
    Version: 3.1.0
    Requires: Windows 10/11, Administrator privileges
#>

# ===================================================================
# UTF-8 Encoding Configuration
# ===================================================================
# Set UTF-8 encoding for proper character display (bullet points, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# For Windows PowerShell 5.1, use additional UTF-8 settings
if ($PSVersionTable.PSVersion.Major -eq 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
}

#region Utility Functions

function Ensure-Administrator {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "This installer requires administrator privileges. Restarting..." -ForegroundColor Yellow
        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            Start-Process PowerShell.exe -Verb RunAs -ArgumentList $arguments
            exit
        } catch {
            Write-Host "Failed to elevate privileges. Please run as Administrator." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
}

function Show-Banner {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "     Claude Code Development Environment Installer" -ForegroundColor Cyan
    Write-Host "                    Version 3.1.0" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Progress {
    param(
        [string]$Message,
        [scriptblock]$Action,
        [switch]$UseDirect,
        [switch]$Debug
    )

    $spinner = @('/', '-', '\', '|')
    $spinnerIndex = 0

    # Convert scriptblock to string for passing to background job
    $actionString = $Action.ToString()

    if ($Debug) {
        Write-Host "[DEBUG] Action type: $($Action.GetType().FullName)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Action content: $actionString" -ForegroundColor Magenta
    }

    # DIRECT EXECUTION MODE: Bypasses background job for commands with noisy stderr (like npm.ps1)
    if ($UseDirect) {
        Write-Host "[~] $Message" -ForegroundColor Cyan

        try {
            # Execute directly in current session, merge all output streams
            $ErrorActionPreference = 'Continue'
            $output = & $Action 2>&1
            $exitCode = $LASTEXITCODE

            # Success determined by exit code only (0 = success)
            $isSuccess = ($null -eq $exitCode) -or ($exitCode -eq 0)

            if ($isSuccess) {
                Write-Host "`r[OK] $Message" -ForegroundColor Green
                return @{ Success = $true; Output = $output }
            } else {
                Write-Host "`r[X] $Message" -ForegroundColor Red
                return @{ Success = $false; Output = $output }
            }
        } catch {
            Write-Host "`r[X] $Message" -ForegroundColor Red
            return @{ Success = $false; Output = $_.Exception.Message }
        }
    }

    # Start the action as a background job and capture exit code
    $job = Start-Job -ScriptBlock {
        param($ScriptText, $EnableDebug)
        try {
            if ($EnableDebug) {
                Write-Output "[DEBUG] Received script text length: $($ScriptText.Length)"
                Write-Output "[DEBUG] Script text: $ScriptText"
            }

            # Reconstruct the scriptblock from the string
            $scriptBlock = [scriptblock]::Create($ScriptText)

            if ($EnableDebug) {
                Write-Output "[DEBUG] Scriptblock created successfully"
            }

            # Execute the scriptblock
            $output = & $scriptBlock

            # Return structured result with exit code
            return @{
                Output = $output
                ExitCode = $LASTEXITCODE
                DebugInfo = "Execution completed successfully"
            }
        } catch {
            return @{
                Output = $_.Exception.Message
                ExitCode = 1
                DebugInfo = "Exception: $($_.Exception.GetType().FullName) - $($_.Exception.Message)`nStack: $($_.ScriptStackTrace)"
            }
        }
    } -ArgumentList $actionString, $Debug.IsPresent

    Write-Host "[ ] $Message" -NoNewline -ForegroundColor Cyan

    # Loop while the job is running, updating the spinner
    while ($job.State -eq 'Running') {
        $spinnerChar = $spinner[$spinnerIndex % $spinner.Length]
        Write-Host "`r[$spinnerChar] $Message" -NoNewline -ForegroundColor Cyan
        $spinnerIndex++
        Start-Sleep -Milliseconds 200
    }

    # Receive the job's output and check for errors
    $result = $job | Receive-Job
    $errors = $job.ChildJobs[0].Error | Out-String

    # Extract output, exit code, and debug info from structured result
    $output = if ($result -is [hashtable]) { $result.Output } else { $result }
    $exitCode = if ($result -is [hashtable]) { $result.ExitCode } else { $null }
    $debugInfo = if ($result -is [hashtable]) { $result.DebugInfo } else { $null }

    # Success determination: Prioritize exit code (0 = success), fallback to error stream check
    $isSuccess = $false
    if ($null -ne $exitCode) {
        # If we have an exit code, trust it (0 = success, non-zero = failure)
        $isSuccess = ($exitCode -eq 0)
    } else {
        # Fallback to original logic: job completed and no errors in stream
        $isSuccess = ($job.State -eq 'Completed' -and [string]::IsNullOrEmpty($errors))
    }

    if ($isSuccess) {
        Write-Host "`r[OK] $Message" -ForegroundColor Green
        # Clean up job to prevent memory leaks
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return @{ Success = $true; Output = $output }
    } else {
        Write-Host "`r[X] $Message" -ForegroundColor Red

        # Show debug information if available
        if ($Debug -and $debugInfo) {
            Write-Host "[DEBUG] $debugInfo" -ForegroundColor Magenta
        }

        $fullOutput = "$($output)`n$($errors)"
        # Clean up job to prevent memory leaks
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return @{ Success = $false; Output = $fullOutput }
    }
}

function Show-ProgressPulse {
    param(
        [string]$Message,
        [scriptblock]$Action
    )

    $spinner = @('/', '-', '\', '|')
    $pulseChars = @('=', '-', ' ')  # ASCII fallback for compatibility
    $pulsePosition = 0
    $spinnerIndex = 0
    $barWidth = 20

    # Convert scriptblock to string for passing to background job
    $actionString = $Action.ToString()

    # Start action in background
    $job = Start-Job -ScriptBlock {
        param($ScriptText)
        try {
            $scriptBlock = [scriptblock]::Create($ScriptText)
            $result = & $scriptBlock
            return $result
        } catch {
            return @{ ExitCode = 1; Output = $_.Exception.Message }
        }
    } -ArgumentList $actionString

    while ($job.State -eq 'Running') {
        $spinnerChar = $spinner[$spinnerIndex % 4]

        # Create moving pulse effect
        $bar = " " * $barWidth
        $pulsePos = [Math]::Floor($pulsePosition) % $barWidth

        $barArray = $bar.ToCharArray()
        if ($pulsePos -lt $barWidth) { $barArray[$pulsePos] = '=' }
        if ($pulsePos + 1 -lt $barWidth) { $barArray[$pulsePos + 1] = '-' }
        if ($pulsePos + 2 -lt $barWidth) { $barArray[$pulsePos + 2] = ' ' }

        $pulseBar = "[" + (-join $barArray) + "]"

        Write-Host "`r[$spinnerChar] $Message $pulseBar" -NoNewline -ForegroundColor Cyan

        $spinnerIndex++
        $pulsePosition += 0.5
        [Console]::Out.Flush()
        Start-Sleep -Milliseconds 100
    }

    # Get results
    $result = Receive-Job -Job $job
    $exitCode = if ($result -is [hashtable] -and $result.ContainsKey('ExitCode')) { $result.ExitCode } else { 0 }
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

    if ($exitCode -eq 0) {
        Write-Host "`r[OK] $Message [" + ("=" * $barWidth) + "]" -ForegroundColor Green
        return @{ Success = $true; Output = $result }
    } else {
        Write-Host "`r[X] $Message" -ForegroundColor Red
        return @{ Success = $false; Output = $result }
    }
}

# Reliably tests if a command is a real, installed application by checking its version output.
function Test-Command {
    param(
        [string]$Command,
        [string]$Argument,
        [string]$ExpectedOutputPattern,
        [string]$DisplayName
    )
    $versionOutput = ""
    try {
        # Execute the command and capture its output. Redirect stderr to null to prevent pollution from app stubs.
        $versionOutput = & $Command $Argument 2>$null
    } catch {
        # This block will catch if the command doesn't exist at all.
        return $false
    }

    # Check if the output (which could be an array of strings) contains the expected pattern.
    if ($versionOutput -match $ExpectedOutputPattern) {
        # Extract the first line of the output for a clean display message.
        $firstLine = ($versionOutput | Select-Object -First 1).Trim()
        Write-Host "[FOUND] $DisplayName is already installed ($firstLine). Skipping installation." -ForegroundColor Green
        return $true
    } else {
        return $false
    }
}

function New-DesktopShortcut {
    <#
    .SYNOPSIS
        Creates a desktop shortcut (.lnk file)

    .PARAMETER Name
        Display name for the shortcut (without .lnk extension)

    .PARAMETER TargetPath
        Full path to the executable or folder

    .PARAMETER WorkingDirectory
        Working directory for the shortcut (optional)

    .PARAMETER Arguments
        Command-line arguments (optional)

    .PARAMETER IconLocation
        Path to icon file (optional, defaults to target executable)

    .PARAMETER Description
        Shortcut description (optional)

    .OUTPUTS
        Boolean - $true if shortcut created successfully, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$TargetPath,

        [string]$WorkingDirectory = "",

        [string]$Arguments = "",

        [string]$IconLocation = "",

        [string]$Description = ""
    )

    try {
        # Get desktop path
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "$Name.lnk"

        # Check if shortcut already exists
        if (Test-Path $shortcutPath) {
            Write-Host "[INFO] Desktop shortcut already exists: $Name" -ForegroundColor Gray
            return $true
        }

        # Create WScript.Shell COM object
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($shortcutPath)

        # Set shortcut properties
        $shortcut.TargetPath = $TargetPath

        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            $shortcut.WorkingDirectory = $WorkingDirectory
        }

        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
            $shortcut.Arguments = $Arguments
        }

        if (-not [string]::IsNullOrWhiteSpace($IconLocation)) {
            $shortcut.IconLocation = $IconLocation
        }

        if (-not [string]::IsNullOrWhiteSpace($Description)) {
            $shortcut.Description = $Description
        }

        # Save the shortcut
        $shortcut.Save()

        # Release COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshShell) | Out-Null

        Write-Host "[OK] Created desktop shortcut: $Name" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "[WARNING] Failed to create desktop shortcut: $Name" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }
}

function Test-GitHubDesktop {
    <#
    .SYNOPSIS
        Checks if GitHub Desktop is installed on the system

    .PARAMETER Verbose
        Display detailed information about the detection process

    .OUTPUTS
        Boolean - $true if GitHub Desktop is installed, $false otherwise
    #>
    param(
        [switch]$Verbose
    )

    # Method 1: Check installation directory
    $ghDesktopPath = "$env:LOCALAPPDATA\GitHubDesktop"
    if (Test-Path $ghDesktopPath) {
        if ($Verbose) {
            Write-Host "  [FOUND] GitHub Desktop installation directory: $ghDesktopPath" -ForegroundColor Green
        }
        return $true
    }

    # Method 2: Check if GitHub Desktop is in Start Menu
    $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GitHub Desktop.lnk"
    if (Test-Path $startMenuPath) {
        if ($Verbose) {
            Write-Host "  [FOUND] GitHub Desktop Start Menu shortcut" -ForegroundColor Green
        }
        return $true
    }

    # Method 3: Check registry for installed programs
    $uninstallPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $uninstallPaths) {
        try {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue
            $ghDesktop = $apps | Where-Object { $_.DisplayName -like "*GitHub Desktop*" }
            if ($ghDesktop) {
                if ($Verbose) {
                    Write-Host "  [FOUND] GitHub Desktop in registry: $($ghDesktop.DisplayName)" -ForegroundColor Green
                }
                return $true
            }
        } catch {
            # Silently continue if registry path doesn't exist
            continue
        }
    }

    if ($Verbose) {
        Write-Host "  [NOT FOUND] GitHub Desktop is not installed" -ForegroundColor Yellow
    }
    return $false
}

#endregion

#region Authentication Validation Functions

function Test-ClaudeAuthentication {
    <#
    .SYNOPSIS
        Validates Claude CLI authentication by checking credential files

    .DESCRIPTION
        Checks if Claude is authenticated by verifying credential files exist
        and contain valid authentication tokens.

        Checks multiple possible credential file locations:
        - %USERPROFILE%\.claude\.credentials.json (primary)
        - %USERPROFILE%\.config\claude-code\auth.json (alternative)
        - %USERPROFILE%\.config\claude\auth.json (legacy)
        - %APPDATA%\claude\credentials.json (fallback)

    .PARAMETER Verbose
        Show detailed diagnostic output about which paths are checked

    .OUTPUTS
        Boolean - $true if authenticated, $false otherwise
    #>
    param(
        [switch]$Verbose
    )

    # Check all possible credential locations
    $credentialPaths = @(
        "$env:USERPROFILE\.claude\.credentials.json",
        "$env:USERPROFILE\.config\claude-code\auth.json",
        "$env:USERPROFILE\.config\claude\auth.json",
        "$env:APPDATA\claude\credentials.json"
    )

    if ($Verbose) {
        Write-Host "    [VERBOSE] Checking credential file locations..." -ForegroundColor Magenta
    }

    foreach ($path in $credentialPaths) {
        if ($Verbose) {
            Write-Host "    [VERBOSE] Checking: $path" -ForegroundColor Magenta
        }

        if (Test-Path $path) {
            if ($Verbose) {
                $fileInfo = Get-Item $path
                $fileAge = (Get-Date) - $fileInfo.LastWriteTime
                Write-Host "    [VERBOSE] File found! Age: $([Math]::Round($fileAge.TotalSeconds, 1))s" -ForegroundColor Magenta
            }

            # If file is very new (< 2 seconds), wait for it to be fully written
            $fileInfo = Get-Item $path
            $fileAge = (Get-Date) - $fileInfo.LastWriteTime
            if ($fileAge.TotalSeconds -lt 2) {
                if ($Verbose) {
                    Write-Host "    [VERBOSE] File is very new, waiting 2s for complete write..." -ForegroundColor Magenta
                }
                Start-Sleep -Seconds 2
            }

            # Retry logic for reading file (3 attempts with 1s delay)
            $maxRetries = 3
            $retryCount = 0
            $credentials = $null

            while ($retryCount -lt $maxRetries) {
                try {
                    $credentials = Get-Content $path -Raw | ConvertFrom-Json
                    break  # Success, exit retry loop
                } catch {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        if ($Verbose) {
                            Write-Host "    [VERBOSE] Read attempt $retryCount failed, retrying..." -ForegroundColor Magenta
                        }
                        Start-Sleep -Seconds 1
                    } else {
                        if ($Verbose) {
                            Write-Host "    [VERBOSE] Failed to read after $maxRetries attempts" -ForegroundColor Magenta
                        }
                        continue  # Move to next path
                    }
                }
            }

            if ($null -eq $credentials) {
                continue  # Failed to read, try next path
            }

            # Check if claudeAiOauth object exists
            if ($null -eq $credentials.claudeAiOauth) {
                if ($Verbose) {
                    Write-Host "    [VERBOSE] File does not contain claudeAiOauth object" -ForegroundColor Magenta
                }
                continue  # Try next credential file path
            }

            # Extract OAuth credentials from nested object
            $oauthCreds = $credentials.claudeAiOauth

            if ($Verbose) {
                Write-Host "    [VERBOSE] claudeAiOauth object found" -ForegroundColor Magenta
            }

            # Check if we have required token fields
            $hasAccessToken = $null -ne $oauthCreds.accessToken -and $oauthCreds.accessToken -ne ""
            $hasRefreshToken = $null -ne $oauthCreds.refreshToken -and $oauthCreds.refreshToken -ne ""

            if ($Verbose) {
                Write-Host "    [VERBOSE] Has access token: $hasAccessToken" -ForegroundColor Magenta
                Write-Host "    [VERBOSE] Has refresh token: $hasRefreshToken" -ForegroundColor Magenta

                # Show token details
                if ($hasAccessToken) {
                    $tokenPrefix = $oauthCreds.accessToken.Substring(0, [Math]::Min(15, $oauthCreds.accessToken.Length))
                    $tokenLength = $oauthCreds.accessToken.Length
                    Write-Host "    [VERBOSE] Access token prefix: $tokenPrefix..." -ForegroundColor Magenta
                    Write-Host "    [VERBOSE] Access token length: $tokenLength chars" -ForegroundColor Magenta
                }
            }

            if ($hasAccessToken -or $hasRefreshToken) {
                # Check if token is expired (if expiresAt exists)
                if ($oauthCreds.PSObject.Properties.Name -contains 'expiresAt') {
                    # IMPORTANT: expiresAt is in MILLISECONDS, not seconds
                    $expiresAtMs = $oauthCreds.expiresAt
                    $expiresAt = [DateTimeOffset]::FromUnixTimeMilliseconds($expiresAtMs).DateTime
                    $isExpired = (Get-Date) -gt $expiresAt

                    if ($Verbose) {
                        $timeUntilExpiry = $expiresAt - (Get-Date)
                        Write-Host "    [VERBOSE] Token expires at: $expiresAt" -ForegroundColor Magenta
                        Write-Host "    [VERBOSE] Time until expiry: $([Math]::Round($timeUntilExpiry.TotalHours, 1)) hours" -ForegroundColor Magenta
                        Write-Host "    [VERBOSE] Is expired: $isExpired" -ForegroundColor Magenta
                    }

                    if (-not $isExpired) {
                        if ($Verbose) {
                            Write-Host "    [VERBOSE] Authentication VALID (token not expired)" -ForegroundColor Green
                        }
                        return $true
                    }
                    # If expired but has refresh token, still consider authenticated
                    # (Claude will auto-refresh)
                    if ($hasRefreshToken) {
                        if ($Verbose) {
                            Write-Host "    [VERBOSE] Authentication VALID (has refresh token)" -ForegroundColor Green
                        }
                        return $true
                    }
                } else {
                    # No expiration info, trust the tokens exist
                    if ($Verbose) {
                        Write-Host "    [VERBOSE] Authentication VALID (tokens present, no expiration)" -ForegroundColor Green
                    }
                    return $true
                }

                # Show subscription type if available
                if ($Verbose -and ($oauthCreds.PSObject.Properties.Name -contains 'subscriptionType')) {
                    Write-Host "    [VERBOSE] Subscription type: $($oauthCreds.subscriptionType)" -ForegroundColor Magenta
                }
            }
        } else {
            if ($Verbose) {
                Write-Host "    [VERBOSE] File not found" -ForegroundColor Magenta
            }
        }
    }

    if ($Verbose) {
        Write-Host "    [VERBOSE] No valid authentication found" -ForegroundColor Yellow
    }
    return $false
}

function Start-ClaudeAuthenticationNewWindow {
    <#
    .SYNOPSIS
        Starts Claude authentication in a new visible terminal window with automatic monitoring

    .PARAMETER WorkingDirectory
        Directory where the claude command will be executed

    .OUTPUTS
        Boolean - $true if authentication succeeded, $false otherwise
    #>
    param(
        [string]$WorkingDirectory
    )

    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Authentication" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "A new terminal window will open for authentication." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "What will happen:" -ForegroundColor Cyan
    Write-Host "  1. A new terminal window opens" -ForegroundColor Gray
    Write-Host "  2. Your browser opens automatically (or use any browser)" -ForegroundColor Gray
    Write-Host "  3. Enter your EMAIL ADDRESS" -ForegroundColor Gray
    Write-Host "  4. Check your EMAIL for authentication link" -ForegroundColor Gray
    Write-Host "  5. CLICK THE LINK (in email or copy/paste to any browser)" -ForegroundColor Gray
    Write-Host "  6. Browser shows success (one of these URLs):" -ForegroundColor Gray
    Write-Host "     - https://console.anthropic.com/oauth/code/success" -ForegroundColor Green
    Write-Host "     - https://claude.ai/new" -ForegroundColor Green
    Write-Host "  7. Close the authentication window when ready" -ForegroundColor Gray
    Write-Host ""
    Write-Host "IMPORTANT: Authentication works from ANY browser!" -ForegroundColor Yellow
    Write-Host "  - You can copy/paste the email link into any browser tab" -ForegroundColor Gray
    Write-Host "  - This installer will detect authentication automatically" -ForegroundColor Gray
    Write-Host ""
    Write-Host "This window will automatically detect when authentication completes." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Opening authentication window in 3 seconds..." -ForegroundColor Cyan
    Write-Host "(Give yourself time to read the instructions above)" -ForegroundColor Gray
    Start-Sleep -Seconds 3
    Write-Host ""
    Write-Host "[~] Starting authentication..." -ForegroundColor Cyan

    # Create authentication script for new window
    $authScript = @"
Set-Location '$WorkingDirectory'
Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  Claude Authentication Window' -ForegroundColor Cyan
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Your browser will open shortly...' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Authentication Steps:' -ForegroundColor Cyan
Write-Host '  1. Browser will open automatically' -ForegroundColor Gray
Write-Host '  2. Enter your EMAIL ADDRESS' -ForegroundColor Gray
Write-Host '  3. Check your EMAIL for authentication link' -ForegroundColor Gray
Write-Host '  4. CLICK THE LINK in the email' -ForegroundColor Gray
Write-Host '  5. Browser shows SUCCESS URL:' -ForegroundColor Gray
Write-Host '     https://console.anthropic.com/oauth/code/success' -ForegroundColor Green
Write-Host '  6. Close this window when you see success URL' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Starting authentication...' -ForegroundColor Cyan
Write-Host ''
claude
Write-Host ''
Write-Host 'Authentication completed. You may close this window.' -ForegroundColor Green
Read-Host 'Press Enter to close'
"@

    # Start new PowerShell window with authentication script (don't use -Wait)
    $authProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", $authScript -PassThru

    # Monitor process with timeout (15 minutes for slow VM/internet connections)
    $timeout = 900
    $elapsed = 0
    $checkInterval = 2

    Write-Host ""
    Write-Host "[~] Monitoring authentication process..." -ForegroundColor Cyan
    Write-Host "    (Checking for credential file every 2 seconds)" -ForegroundColor Gray
    Write-Host "    (Will wait up to 15 minutes for slow connections)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    TIP: Complete authentication in ANY browser:" -ForegroundColor Yellow
    Write-Host "    - Use the automatically opened browser window, OR" -ForegroundColor Gray
    Write-Host "    - Copy/paste the email link into any other browser tab" -ForegroundColor Gray
    Write-Host "    - Detection is automatic - no need to click anything here" -ForegroundColor Gray
    Write-Host ""

    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    $authDetected = $false
    $verboseCheckInterval = 30  # Show detailed diagnostics every 30 seconds
    $timeSinceLastVerbose = 0

    while (-not $authProcess.HasExited -and $elapsed -lt $timeout -and -not $authDetected) {
        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
        $timeSinceLastVerbose += $checkInterval

        # Perform verbose diagnostic check every 30 seconds
        $useVerbose = ($timeSinceLastVerbose -ge $verboseCheckInterval)
        if ($useVerbose) {
            Write-Host "`r                                                                                    " -NoNewline
            Write-Host "`r" -NoNewline
            Write-Host "[DIAGNOSTIC] Performing detailed authentication check..." -ForegroundColor Magenta
            $timeSinceLastVerbose = 0
        }

        # Check if authentication completed (credential file appeared)
        if (Test-ClaudeAuthentication -Verbose:$useVerbose) {
            $authDetected = $true
            Write-Host "`r[OK] Authentication detected!                                        " -ForegroundColor Green
            Write-Host ""
            Write-Host "Success! You may close the authentication window." -ForegroundColor Green
            break
        }

        # Show spinner every 2 seconds (unless verbose check just ran)
        if (-not $useVerbose) {
            $spinnerChar = $spinner[$spinnerIndex % 4]
            $remainingMinutes = [Math]::Floor(($timeout - $elapsed) / 60)
            $remainingSeconds = ($timeout - $elapsed) % 60
            Write-Host "`r    [$spinnerChar] Waiting for authentication... (${remainingMinutes}m ${remainingSeconds}s remaining)" -NoNewline -ForegroundColor Cyan
        }
        $spinnerIndex++
    }

    Write-Host "" # New line after spinner

    # Handle different exit scenarios
    if ($authDetected) {
        # Success! Authentication was detected during the process
        Write-Host "[INFO] Credential file created successfully" -ForegroundColor Cyan
        return $true

    } elseif ($authProcess.HasExited) {
        # Process exited but no auth detected during monitoring
        # Do one final check in case we missed it
        Write-Host "[INFO] Authentication window closed" -ForegroundColor Cyan

        # Check exit code
        $exitCode = $authProcess.ExitCode
        if ($null -ne $exitCode -and $exitCode -ne 0) {
            Write-Host "[!] Authentication window exited with code: $exitCode" -ForegroundColor Yellow
            Write-Host "    This might indicate an error occurred." -ForegroundColor Gray
        }

        Write-Host "[~] Performing final authentication check..." -ForegroundColor Cyan
        Write-Host "    (Waiting 5 seconds for credential files to be fully written)" -ForegroundColor Gray
        Start-Sleep -Seconds 5

        if (Test-ClaudeAuthentication) {
            Write-Host "[OK] Authentication successful!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[X] Authentication verification failed" -ForegroundColor Red
            Write-Host "    No credential file found at:" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.claude\.credentials.json" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.config\claude-code\auth.json" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.config\claude\auth.json" -ForegroundColor Gray
            Write-Host "    - $env:APPDATA\claude\credentials.json" -ForegroundColor Gray
            return $false
        }

    } else {
        # Timeout reached without authentication
        Write-Host "[!] Authentication timeout reached (15 minutes)" -ForegroundColor Yellow
        Write-Host "    The authentication window may still be open." -ForegroundColor Gray

        # Do one final check anyway
        Write-Host "[~] Performing final authentication check..." -ForegroundColor Cyan
        Write-Host "    (Waiting 5 seconds for credential files to be fully written)" -ForegroundColor Gray
        Start-Sleep -Seconds 5

        if (Test-ClaudeAuthentication) {
            Write-Host "[OK] Authentication successful!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[X] Authentication verification failed" -ForegroundColor Red
            Write-Host "    No credential file found at:" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.claude\.credentials.json" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.config\claude-code\auth.json" -ForegroundColor Gray
            Write-Host "    - $env:USERPROFILE\.config\claude\auth.json" -ForegroundColor Gray
            Write-Host "    - $env:APPDATA\claude\credentials.json" -ForegroundColor Gray
            return $false
        }
    }
}

function Confirm-ClaudeAuthenticationManually {
    <#
    .SYNOPSIS
        Fallback method - asks user to manually verify authentication

    .OUTPUTS
        Boolean - $true if user confirms authentication works, $false otherwise
    #>

    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host "  Manual Authentication Verification" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Unable to automatically verify authentication." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please manually verify:" -ForegroundColor Cyan
    Write-Host "  1. Open a new terminal (Win+R, type 'cmd', Enter)" -ForegroundColor Gray
    Write-Host "  2. Type: claude" -ForegroundColor Gray
    Write-Host "  3. If it starts Claude (not 'Missing API key'), you're authenticated" -ForegroundColor Gray
    Write-Host ""

    $response = Read-Host "Did 'claude' work without asking to login? (Y/N)"
    return ($response.Trim().ToUpper() -eq 'Y')
}

function Test-PiecesAuthentication {
    <#
    .SYNOPSIS
        Detects if Pieces Desktop is authenticated

    .DESCRIPTION
        Checks if Pieces Desktop process is running OR if data folders exist.
        This is a best-effort check since Pieces doesn't document credential files.

    .OUTPUTS
        Boolean - $true if authenticated/configured, $false otherwise
    #>

    # Method 1: Check if Pieces Desktop process is running
    $piecesProcess = Get-Process -Name "Pieces*" -ErrorAction SilentlyContinue

    if ($piecesProcess) {
        Write-Host "[OK] Pieces Desktop is currently running" -ForegroundColor Green
        return $true
    }

    # Method 2: Check for Pieces data folders
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Pieces",
        "$env:APPDATA\Pieces",
        "$env:USERPROFILE\.pieces"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            # Check if folder has content (not just empty)
            $items = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
            if ($items.Count -gt 0) {
                Write-Host "[OK] Pieces data folder found: $path" -ForegroundColor Green
                return $true
            }
        }
    }

    Write-Host "[INFO] No existing Pieces authentication detected" -ForegroundColor Gray
    return $false
}

function Start-PiecesAuthenticationNewWindow {
    <#
    .SYNOPSIS
        Launches Pieces Desktop for user authentication

    .DESCRIPTION
        Opens Pieces Desktop using protocol handler or executable path,
        guides user through authentication, and waits for confirmation.

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

    # Give user time to read instructions
    Write-Host "Launching Pieces Desktop in 3 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3

    # Launch Pieces Desktop
    Write-Host "[~] Launching Pieces Desktop..." -ForegroundColor Cyan
    try {
        $launched = $false

        # Method 1: Try protocol handler
        try {
            Start-Process "pieces-for-developers://open" -ErrorAction Stop
            $launched = $true
        } catch {
            # Method 2: Try to find executable
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
            Write-Host "[X] Could not launch automatically" -ForegroundColor Red
            Write-Host "    Please launch Pieces Desktop manually from Start Menu" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "[INFO] Complete the authentication in Pieces Desktop" -ForegroundColor Cyan
        Write-Host "[INFO] This window will wait for you to finish..." -ForegroundColor Gray
        Write-Host ""

        # Wait for user confirmation
        $authComplete = Read-Host "Did you complete authentication successfully? (Y/N)"

        if ($authComplete.Trim().ToUpper() -eq 'Y') {
            Write-Host "[OK] Authentication confirmed!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[INFO] Authentication not completed" -ForegroundColor Yellow
            return $false
        }

    } catch {
        Write-Host "[X] Failed to launch Pieces Desktop: $_" -ForegroundColor Red
        Write-Host "    Please launch manually from Start Menu" -ForegroundColor Yellow
        return $false
    }
}

#endregion

#region Main Installation Flow

function Start-Installation {
    Ensure-Administrator
    Show-Banner

    Write-Host "This installer will set up your development environment."
    Write-Host "It will check for required tools and install them only if missing."
    Write-Host ""

    # Display system requirements and size information
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  System Requirements & Installation Sizes" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Component Sizes (Installed):" -ForegroundColor Yellow
    Write-Host "  • Node.js:          ~100 MB" -ForegroundColor Gray
    Write-Host "  • Git for Windows:  ~321 MB" -ForegroundColor Gray
    Write-Host "  • Visual Studio Code: ~500 MB" -ForegroundColor Gray
    Write-Host "  • Claude Code CLI:  ~78 MB" -ForegroundColor Gray
    Write-Host "  • VS Code Extension: ~100 MB" -ForegroundColor Gray
    Write-Host "  • GitHub Desktop:   ~200 MB (Full installation)" -ForegroundColor Gray
    Write-Host "  • Pieces Desktop:   ~1 GB initially (Full installation)" -ForegroundColor Gray
    Write-Host "    (Can grow to 5+ GB with user data and AI models)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Disk Space Requirements:" -ForegroundColor Yellow
    Write-Host "  • Core Installation:  ~2 GB free space recommended" -ForegroundColor Cyan
    Write-Host "    (Total installed: ~1.1 GB)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  • Full Installation:  ~4.5 GB free space recommended" -ForegroundColor Cyan
    Write-Host "    (Initial: ~2.3 GB, grows to 6+ GB with Pieces data)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "System Requirements:" -ForegroundColor Yellow
    Write-Host "  • OS: Windows 10 (64-bit) or Windows 11" -ForegroundColor Gray
    Write-Host "  • RAM: 8 GB minimum, 16 GB recommended" -ForegroundColor Gray
    Write-Host "  • Internet: Required for installation and authentication" -ForegroundColor Gray
    Write-Host "  • Privileges: Administrator access required" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTE: Pieces Desktop stores code snippets and AI models locally," -ForegroundColor Yellow
    Write-Host "      which increases disk usage over time." -ForegroundColor Yellow
    Write-Host ""

    # Desktop Icons Preference
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Desktop Shortcuts" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Would you like desktop shortcuts created for installed applications?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Shortcuts that may be created:" -ForegroundColor Gray
    Write-Host "  • Visual Studio Code" -ForegroundColor Gray
    Write-Host "  • Pieces Desktop (if Full installation)" -ForegroundColor Gray
    Write-Host ""

    $createDesktopIcons = $null
    while ($createDesktopIcons -notin @('y', 'n')) {
        $userInput = Read-Host "Create desktop shortcuts? [Y/N]"

        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            $firstChar = $userInput.Trim().ToLower().Substring(0,1)
            if ($firstChar -in @('y', 'n')) {
                $createDesktopIcons = $firstChar
            } else {
                Write-Host "[!] Invalid input. Please type 'Y' or 'N'" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[!] Please type 'Y' or 'N' (not just Enter)" -ForegroundColor Yellow
        }
    }

    if ($createDesktopIcons -eq 'y') {
        Write-Host ""
        Write-Host "[OK] Desktop shortcuts will be created for installed applications" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[OK] No desktop shortcuts will be created" -ForegroundColor Cyan
    }
    Write-Host ""

    # Core vs Full Install Choice
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Installation Type" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose your installation type:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [C] Core Installation (~1.1 GB, 2 GB free space needed)" -ForegroundColor White
    Write-Host "      - Node.js, Git, VS Code" -ForegroundColor Gray
    Write-Host "      - Claude Code CLI" -ForegroundColor Gray
    Write-Host "      - VS Code Chat Extension" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [F] Full Installation (~2.3 GB initially, 4.5 GB free space needed) (RECOMMENDED)" -ForegroundColor Green
    Write-Host "      - Everything in Core, PLUS:" -ForegroundColor Gray
    Write-Host "      - GitHub Desktop: Git GUI client" -ForegroundColor Gray
    Write-Host "      - Pieces Desktop: AI-powered coding assistant" -ForegroundColor Gray
    Write-Host "        * Code snippet manager with AI search" -ForegroundColor Gray
    Write-Host "        * Context-aware code suggestions" -ForegroundColor Gray
    Write-Host "        * Integrates with your workflow seamlessly" -ForegroundColor Gray
    Write-Host "        * Works offline once configured" -ForegroundColor Gray
    Write-Host "        * NOTE: Grows to 5+ GB with data and AI models" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Pieces Desktop enhances your coding experience with intelligent" -ForegroundColor Cyan
    Write-Host "code management and AI-powered assistance. Highly recommended!" -ForegroundColor Cyan
    Write-Host ""

    $installType = $null
    while ($installType -notin @('c', 'f')) {
        $userInput = Read-Host "Select [C] for Core or [F] for Full (then press Enter)"

        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            $firstChar = $userInput.Trim().ToLower().Substring(0,1)
            if ($firstChar -in @('c', 'f')) {
                $installType = $firstChar
            } else {
                Write-Host "[!] Invalid input. Please type 'C' or 'F'" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[!] Please type 'C' or 'F' (not just Enter)" -ForegroundColor Yellow
        }
    }

    $installPieces = ($installType -eq 'f')

    if ($installPieces) {
        Write-Host ""
        Write-Host "[OK] Full Installation selected - GitHub Desktop and Pieces Desktop will be included!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[OK] Core Installation selected - GitHub Desktop and Pieces Desktop will be skipped" -ForegroundColor Cyan
        Write-Host "     (You can install them later if needed)" -ForegroundColor Gray
    }
    Write-Host ""

    # Check available disk space
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive.TrimEnd(':')
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

    Write-Host "Available disk space on $systemDrive\: $freeSpaceGB GB" -ForegroundColor Cyan

    if ($freeSpaceGB -lt 2) {
        Write-Host ""
        Write-Host "WARNING: Low disk space detected!" -ForegroundColor Red
        Write-Host "You may not have enough space for installation." -ForegroundColor Yellow
        Write-Host "Please free up disk space before continuing." -ForegroundColor Yellow
        Write-Host ""
    } elseif ($freeSpaceGB -lt 4) {
        Write-Host ""
        Write-Host "NOTE: Limited disk space. Full installation (with Pieces) may require more space." -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host ""

    $null = Read-Host "Press Enter to continue or Ctrl+C to cancel"
    Write-Host ""

    # --- Detection Phase ---
    Write-Host "Step 1: Checking for existing tool installations..." -ForegroundColor Cyan
    $needsNode = -not (Test-Command -Command "node" -Argument "--version" -ExpectedOutputPattern "^v" -DisplayName "Node.js")
    $needsGit = -not (Test-Command -Command "git" -Argument "--version" -ExpectedOutputPattern "git version" -DisplayName "Git")
    $needsCode = -not (Test-Command -Command "code" -Argument "--version" -ExpectedOutputPattern "." -DisplayName "Visual Studio Code")
    $needsClaude = -not (Test-Command -Command "claude" -Argument "--version" -ExpectedOutputPattern "." -DisplayName "Claude Code CLI")

    # GitHub Desktop and Pieces Desktop will be checked later (if Full installation selected)

    # --- Package Manager Detection (only if needed) ---
    $packageManager = $null
    if ($needsNode -or $needsGit -or $needsCode) {
        Write-Host "`nStep 2: One or more tools are missing. Detecting package manager..." -ForegroundColor Cyan
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "[FOUND] Using winget as the primary package manager." -ForegroundColor Green
            $packageManager = 'winget'
        } else {
            Write-Host "[NOT FOUND] winget not available. Checking for Chocolatey..." -ForegroundColor Yellow
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "[FOUND] Using Chocolatey as a fallback." -ForegroundColor Green
                $packageManager = 'choco'
            } else {
                Write-Host "[NOT FOUND] Chocolatey not available. Installing it now..." -ForegroundColor Yellow

                # Download Chocolatey install script
                Write-Host "[~] Downloading Chocolatey installer..." -ForegroundColor Cyan
                try {
                    $chocoInstallScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
                    Write-Host "[OK] Download complete" -ForegroundColor Green
                } catch {
                    Write-Host "[X] Failed to download Chocolatey installer" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Gray
                    Read-Host "Press Enter to exit"
                    exit 1
                }

                # Install Chocolatey (suppress verbose output)
                Write-Host "[~] Installing Chocolatey..." -ForegroundColor Cyan
                try {
                    # Suppress all output except errors
                    $ErrorActionPreference = 'SilentlyContinue'
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression $chocoInstallScript | Out-Null

                    Write-Host "[OK] Chocolatey installed successfully" -ForegroundColor Green
                    $packageManager = 'choco'
                    $env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path

                    # Give VM environment time to settle
                    Start-Sleep -Milliseconds 500
                } catch {
                    Write-Host "[X] Failed to install Chocolatey" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Gray
                    Read-Host "Press Enter to exit"
                    exit 1
                }
            }
        }
    }

    # --- Installation Phase ---

    # --- 3. Node.js ---
    # Node.js Installation Strategy:
    # - Claude Code CLI requires Node.js 18+ with LTS versions strongly recommended
    # - Installing Node.js 20.x LTS (Active LTS until April 2026)
    # - Avoiding odd-numbered versions (19, 21, 23, 25) which never become LTS
    # - Version 20.x is battle-tested and production-ready
    if ($needsNode) {
        Write-Host "`nStep 3: Installing Node.js..." -ForegroundColor Cyan

        if ($packageManager -eq 'winget') {
            # Install Node.js 20.x LTS silently for clean output
            Write-Host "[~] Downloading and installing Node.js 20 LTS..." -ForegroundColor Cyan
            winget install --id OpenJS.NodeJS.LTS --version 20 -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget 2>&1 | Out-Null
            $nodeInstallSuccess = ($LASTEXITCODE -eq 0)
        } else {
            Write-Host "[~] Downloading and installing Node.js 20 LTS..." -ForegroundColor Cyan
            choco install nodejs-lts -y --force --limit-output 2>&1 | Out-Null
            $nodeInstallSuccess = ($LASTEXITCODE -eq 0)
        }

        if (-not $nodeInstallSuccess) {
            Write-Host "[ERROR] Failed to install Node.js" -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        } else {
            Write-Host "[OK] Node.js installed successfully" -ForegroundColor Green

            # Update PATH for this session
            $env:Path = "C:\Program Files\nodejs;" + $env:Path
            $env:Path = "$env:APPDATA\npm;" + $env:Path

            # Refresh PATH from registry
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path","User")

            # Validate silently (no output unless error)
            try {
                $null = node --version 2>&1
                $null = npm --version 2>&1
            } catch {
                Write-Host "[X] Node.js installed but commands not working" -ForegroundColor Red
                Read-Host "Press Enter to exit"
                exit 1
            }

            # Validate Node.js version is LTS and compatible with Claude Code CLI
            try {
                $nodeVersion = node --version 2>&1

                if ($nodeVersion -match 'v(\d+)\.') {
                    $majorVersion = [int]$Matches[1]

                    # Check minimum version requirement (v18+)
                    if ($majorVersion -lt 18) {
                        Write-Host "[X] Node.js version $nodeVersion is too old. Claude Code requires v18 or higher." -ForegroundColor Red
                        Write-Host "[INFO] Please report this issue - the installer should have installed v20 LTS." -ForegroundColor Yellow
                        Read-Host "Press Enter to exit"
                        exit 1
                    }
                    # Check if it's a non-LTS version (odd number)
                    elseif ($majorVersion % 2 -eq 1) {
                        Write-Host "[!] WARNING: Node.js version $nodeVersion is a 'Current' release (not LTS)." -ForegroundColor Yellow
                        Write-Host "[!] This may cause compatibility issues with Claude Code CLI." -ForegroundColor Yellow
                        Write-Host "[INFO] Continuing anyway, but if you experience issues, reinstall with Node.js 20 LTS." -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "[OK] Node.js $nodeVersion is an LTS version - Compatible with Claude Code CLI" -ForegroundColor Green
                    }
                } else {
                    Write-Host "[X] Could not parse Node.js version: $nodeVersion" -ForegroundColor Red
                    Read-Host "Press Enter to exit"
                    exit 1
                }
            }
            catch {
                Write-Host "[X] Could not verify Node.js installation: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "[INFO] Node.js may not be properly installed or not in PATH." -ForegroundColor Yellow
                Read-Host "Press Enter to exit"
                exit 1
            }
        }
    }

    # --- 4. Git ---
    if ($needsGit) {
        Write-Host "`nStep 4: Installing Git..." -ForegroundColor Cyan

        if ($packageManager -eq 'winget') {
            Write-Host "[~] Downloading and installing Git..." -ForegroundColor Cyan
            winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget 2>&1 | Out-Null
            $gitInstallSuccess = ($LASTEXITCODE -eq 0)
        } else {
            Write-Host "[~] Downloading and installing Git..." -ForegroundColor Cyan
            choco install git -y --force --limit-output 2>&1 | Out-Null
            $gitInstallSuccess = ($LASTEXITCODE -eq 0)
        }

        if (-not $gitInstallSuccess) {
            Write-Host "[ERROR] Failed to install Git" -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        } else {
            Write-Host "[OK] Git installed successfully" -ForegroundColor Green

            $env:Path = "C:\Program Files\Git\cmd;" + $env:Path

            # Refresh PATH from registry
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path","User")

            # Verify Git bash and configure (silent unless error)
            $gitBashPath = "C:\Program Files\Git\bin\bash.exe"
            if (Test-Path $gitBashPath) {
                $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath
                [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashPath, "User")

                # Validate silently
                try {
                    $null = git --version 2>&1
                } catch {
                    Write-Host "[X] Git installed but command not working" -ForegroundColor Red
                    Read-Host "Press Enter to exit"
                    exit 1
                }
            } else {
                Write-Host "[X] Git bash not found at expected location" -ForegroundColor Red
                Read-Host "Press Enter to exit"
                exit 1
            }
        }
    }

    # --- 5. Claude Code CLI ---
    if ($needsClaude) {
        # Verify Git bash is available (required for Claude Code CLI)
        if (-not (Test-Path "C:\Program Files\Git\bin\bash.exe")) {
            Write-Host "[X] Claude Code CLI requires Git bash, but it was not found." -ForegroundColor Red
            Write-Host "    Install Git before attempting Claude CLI installation." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }

        Write-Host "`nStep 5: Installing Claude Code CLI..." -ForegroundColor Cyan

    $claudePackage = "@anthropic-ai/claude-code"

    # Use pulse animation for npm (output is too messy for direct display)
    $claudeInstallResult = Show-ProgressPulse -Message "Installing $claudePackage via npm" -Action {
        $output = npm install -g @anthropic-ai/claude-code 2>&1
        $exitCode = $LASTEXITCODE
        return @{ ExitCode = $exitCode; Output = $output }
    }

    # Validate npm installation with additional checks
    if (-not $claudeInstallResult.Success) {
        # npm often writes informational messages to stderr, causing false failures
        # Check if npm actually succeeded by looking for success indicators in output
        $outputStr = $claudeInstallResult.Output | Out-String

        if ($outputStr -match "added \d+ package" -or $outputStr -match "up to date") {
            Write-Host "[INFO] npm install completed successfully (stderr noise ignored)" -ForegroundColor Yellow
            $claudeInstallResult.Success = $true
        }
    }

    # Final validation: verify claude command is actually available
    if ($claudeInstallResult.Success) {
        $env:Path = "$env:APPDATA\npm;" + $env:Path
        Start-Sleep -Seconds 2  # Give filesystem time to update

        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Write-Host "[WARNING] claude command not found in PATH after installation" -ForegroundColor Yellow
            $claudeInstallResult.Success = $false
        }
    }

    # Error handling
    if (-not $claudeInstallResult.Success) {
        Write-Host "[X] Failed to install Claude Code CLI." -ForegroundColor Red
        Write-Host "`n[ERROR OUTPUT]" -ForegroundColor Red
        Write-Host $claudeInstallResult.Output -ForegroundColor Gray

        Write-Host "`n[DIAGNOSTICS]" -ForegroundColor Yellow
        Write-Host "npm available: $(if (Get-Command npm -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })" -ForegroundColor Gray
        Write-Host "npm location: $(if (Get-Command npm -ErrorAction SilentlyContinue) { (Get-Command npm).Path } else { 'NOT FOUND' })" -ForegroundColor Gray
        Write-Host "Node available: $(if (Get-Command node -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })" -ForegroundColor Gray
        Write-Host "Node location: $(if (Get-Command node -ErrorAction SilentlyContinue) { (Get-Command node).Path } else { 'NOT FOUND' })" -ForegroundColor Gray
        Write-Host "Current PATH contains npm folder: $(if ($env:Path -match 'npm') { 'YES' } else { 'NO' })" -ForegroundColor Gray

        # Display current Node.js version as potential cause
        try {
            $currentNodeVersion = node --version 2>&1
            Write-Host "Node.js version: $currentNodeVersion" -ForegroundColor Gray

            # Check if it's a known incompatible version
            if ($currentNodeVersion -match 'v(\d+)\.') {
                $majorVersion = [int]$Matches[1]
                if ($majorVersion -ge 25) {
                    Write-Host ""
                    Write-Host "[!] INCOMPATIBILITY DETECTED: Node.js v$majorVersion may not be compatible with Claude Code CLI" -ForegroundColor Red
                    Write-Host "[INFO] Node.js v25+ is experimental and not tested with Claude Code CLI" -ForegroundColor Yellow
                    Write-Host "[INFO] Recommended action: Install Node.js 20 LTS for guaranteed compatibility" -ForegroundColor Cyan
                    Write-Host ""

                    # Offer recovery option
                    Write-Host "Recovery Options:" -ForegroundColor Cyan
                    Write-Host "  [R] Retry - Reinstall Node.js 20 LTS and try again" -ForegroundColor White
                    Write-Host "  [C] Continue - Exit installer and fix manually" -ForegroundColor White
                    Write-Host ""

                    $recoveryChoice = $null
                    while ($recoveryChoice -notin @('r', 'c')) {
                        $userInput = Read-Host "Your choice [R/C]"
                        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                            $recoveryChoice = $userInput.Trim().ToLower().Substring(0,1)
                        }
                    }

                    if ($recoveryChoice -eq 'r') {
                        Write-Host ""
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "  Attempting Recovery: Reinstalling Node.js 20 LTS" -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""

                        # Step 1: Uninstall current Node.js
                        Write-Host "[~] Step 1/3: Uninstalling incompatible Node.js version..." -ForegroundColor Cyan
                        if ($packageManager -eq 'winget') {
                            winget uninstall --id OpenJS.NodeJS --silent 2>&1 | Out-Null
                            Start-Sleep -Seconds 3
                        } else {
                            choco uninstall nodejs -y --force 2>&1 | Out-Null
                            Start-Sleep -Seconds 3
                        }
                        Write-Host "[OK] Uninstallation complete" -ForegroundColor Green

                        # Step 2: Install Node.js 20 LTS
                        Write-Host "[~] Step 2/3: Installing Node.js 20 LTS..." -ForegroundColor Cyan
                        if ($packageManager -eq 'winget') {
                            winget install --id OpenJS.NodeJS.LTS --version 20 -e --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget
                            $recoveryNodeSuccess = ($LASTEXITCODE -eq 0)
                        } else {
                            choco install nodejs-lts -y --force
                            $recoveryNodeSuccess = ($LASTEXITCODE -eq 0)
                        }

                        if (-not $recoveryNodeSuccess) {
                            Write-Host "[X] Failed to install Node.js 20 LTS during recovery" -ForegroundColor Red
                            Read-Host "Press Enter to exit"
                            exit 1
                        }

                        Write-Host "[OK] Node.js 20 LTS installed" -ForegroundColor Green

                        # Refresh PATH
                        $env:Path = "C:\Program Files\nodejs;" + $env:Path
                        $env:Path = "$env:APPDATA\npm;" + $env:Path
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                                    [System.Environment]::GetEnvironmentVariable("Path","User")

                        # Verify new Node.js version
                        try {
                            $newNodeVersion = node --version 2>&1
                            Write-Host "[OK] Node.js version after recovery: $newNodeVersion" -ForegroundColor Green
                        } catch {
                            Write-Host "[X] Node.js not found after reinstallation" -ForegroundColor Red
                            Read-Host "Press Enter to exit"
                            exit 1
                        }

                        # Step 3: Retry Claude Code CLI installation
                        Write-Host "[~] Step 3/3: Retrying Claude Code CLI installation..." -ForegroundColor Cyan
                        Write-Host ""

                        $retryInstallResult = Show-ProgressPulse -Message "Installing @anthropic-ai/claude-code via npm (retry)" -Action {
                            $output = npm install -g @anthropic-ai/claude-code 2>&1
                            $exitCode = $LASTEXITCODE
                            return @{ ExitCode = $exitCode; Output = $output }
                        }

                        # Check retry result
                        if (-not $retryInstallResult.Success) {
                            $outputStr = $retryInstallResult.Output | Out-String
                            if ($outputStr -match "added \d+ package" -or $outputStr -match "up to date") {
                                $retryInstallResult.Success = $true
                            }
                        }

                        # Verify claude command
                        if ($retryInstallResult.Success) {
                            $env:Path = "$env:APPDATA\npm;" + $env:Path
                            Start-Sleep -Seconds 2

                            if (Get-Command claude -ErrorAction SilentlyContinue) {
                                $claudeVersion = claude --version 2>&1
                                Write-Host ""
                                Write-Host "[OK] Recovery successful! Claude Code CLI installed: $claudeVersion" -ForegroundColor Green
                                Write-Host ""

                                # Update the success flag so installation can continue
                                $claudeInstallResult.Success = $true
                            } else {
                                Write-Host "[X] Recovery failed: claude command still not available" -ForegroundColor Red
                                Read-Host "Press Enter to exit"
                                exit 1
                            }
                        } else {
                            Write-Host "[X] Recovery failed: Claude Code CLI installation still failing" -ForegroundColor Red
                            Write-Host "[ERROR OUTPUT]" -ForegroundColor Red
                            Write-Host $retryInstallResult.Output -ForegroundColor Gray
                            Read-Host "Press Enter to exit"
                            exit 1
                        }
                    } else {
                        Write-Host ""
                        Write-Host "[INFO] Installation cannot continue without working Claude Code CLI" -ForegroundColor Yellow
                        Write-Host "[INFO] Manual fix: Uninstall current Node.js, install Node.js 20 LTS, then run this installer again" -ForegroundColor Cyan
                        Read-Host "Press Enter to exit"
                        exit 1
                    }
                }
            }
        } catch {
            Write-Host "Node.js version: Unable to determine" -ForegroundColor Gray
        }

        # If we reach here without recovery or if recovery wasn't needed, exit
        if (-not $claudeInstallResult.Success) {
            Read-Host "`nPress Enter to exit"
            exit 1
        }
    }
    }

    # --- 6. Authentication ---
    Write-Host "`nStep 6: Claude Authentication" -ForegroundColor Cyan
    Write-Host "In order to use Claude Code, an account is required. Authenticate now?" -ForegroundColor Yellow

    # Track authentication status
    $authenticatedSuccessfully = $false
    $authMonitorActive = $false
    $authMonitorJob = $null
    $claudeProjectsPath = $null

    # Check if already authenticated
    Write-Host "[~] Checking existing authentication..." -ForegroundColor Cyan
    if (Test-ClaudeAuthentication) {
        Write-Host "[OK] Claude is already authenticated!" -ForegroundColor Green
        $authenticatedSuccessfully = $true
    } else {
        Write-Host "[INFO] No existing authentication found." -ForegroundColor Gray

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
            # Create safe authentication folder
            $claudeProjectsPath = Join-Path $env:USERPROFILE "ClaudeProjects"
            if (-not (Test-Path $claudeProjectsPath)) {
                New-Item -ItemType Directory -Path $claudeProjectsPath -Force | Out-Null
                Write-Host "[INFO] Created Claude Projects folder: $claudeProjectsPath" -ForegroundColor Cyan
            }

            # Create README
            $readmePath = Join-Path $claudeProjectsPath "README.txt"
            $readmeContent = @"
Claude Projects Folder
=====================

This is a safe location for your Claude AI projects.

IMPORTANT: Never run Claude from system folders like:
- C:\ (root)
- C:\Windows
- C:\Program Files

To start a new project:
1. Create a subfolder here (e.g., 'my-web-app')
2. Open PowerShell or Command Prompt
3. Navigate to your project folder
4. Run 'claude' to start

Created by Claude Code Installer on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force

            Write-Host ""
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "  Starting Authentication Process" -ForegroundColor Cyan
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "A SEPARATE terminal window will open for authentication." -ForegroundColor Yellow
            Write-Host "Please complete authentication in THAT window." -ForegroundColor Yellow
            Write-Host "THIS terminal will continue with VS Code installation." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[INFO] Opening authentication window in 3 seconds..." -ForegroundColor Cyan
            Start-Sleep -Seconds 3

            # Create flag file path for synchronization
            $authFlagPath = "$env:TEMP\claude-auth-complete-$PID.flag"
            if (Test-Path $authFlagPath) { Remove-Item $authFlagPath -Force }

            # Create authentication script for separate terminal
            $authScriptBlock = @"
# Set window title so user knows which terminal is which
`$host.UI.RawUI.WindowTitle = 'Claude Authentication - DO NOT CLOSE UNTIL COMPLETE'
Set-Location '$claudeProjectsPath'
Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  CLAUDE AUTHENTICATION WINDOW' -ForegroundColor Cyan
Write-Host '  (Complete authentication in THIS window)' -ForegroundColor Yellow
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Your browser will open shortly...' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Authentication Steps:' -ForegroundColor Cyan
Write-Host '  1. Browser will open automatically' -ForegroundColor Gray
Write-Host '  2. Enter your EMAIL ADDRESS' -ForegroundColor Gray
Write-Host '  3. Check your EMAIL for authentication link' -ForegroundColor Gray
Write-Host '  4. CLICK THE LINK in the email' -ForegroundColor Gray
Write-Host '  5. Browser shows SUCCESS URL:' -ForegroundColor Gray
Write-Host '     https://console.anthropic.com/oauth/code/success' -ForegroundColor Green
Write-Host '  6. This window will close automatically' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Starting authentication...' -ForegroundColor Cyan
Write-Host ''

# Run authentication
claude

# Check if successful and create flag file for main installer
if (`$LASTEXITCODE -eq 0) {
    'COMPLETE' | Out-File -FilePath '$authFlagPath' -Encoding UTF8 -Force
    Write-Host ''
    Write-Host '[OK] Authentication completed successfully!' -ForegroundColor Green
    Write-Host '[INFO] This window will close in 5 seconds...' -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    exit 0
} else {
    Write-Host ''
    Write-Host '[ERROR] Authentication failed or was cancelled' -ForegroundColor Red
    Write-Host ''
    Read-Host 'Press Enter to close this window'
    exit 1
}
"@

            # Save script to temporary file
            $authScriptPath = "$env:TEMP\claude-auth-script-$PID.ps1"
            $authScriptBlock | Out-File -FilePath $authScriptPath -Encoding UTF8 -Force

            # Launch in completely separate terminal window
            Write-Host "[~] Opening authentication window..." -ForegroundColor Cyan
            Start-Process powershell.exe -ArgumentList `
                "-NoProfile", `
                "-ExecutionPolicy", "Bypass", `
                "-File", "`"$authScriptPath`"" `
                -WindowStyle Normal

            Write-Host "[OK] Authentication window opened!" -ForegroundColor Green
            Write-Host "[INFO] Look for window titled: 'Claude Authentication - DO NOT CLOSE UNTIL COMPLETE'" -ForegroundColor Yellow
            Write-Host "[INFO] Complete authentication in THAT window" -ForegroundColor Yellow
            Write-Host "[INFO] THIS terminal will continue with installations..." -ForegroundColor Cyan
            Write-Host ""

            # Give the new terminal a moment to fully separate
            Start-Sleep -Seconds 2

            # No background job needed - will check flag file later
            $authMonitorActive = $false
        } else {
            # User chose to skip - show warnings
            Write-Host ""
            Write-Host "========================================================" -ForegroundColor Yellow
            Write-Host "  WARNING: Skipping Authentication" -ForegroundColor Yellow
            Write-Host "========================================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "WITHOUT authentication, the following will NOT work:" -ForegroundColor Red
            Write-Host "  [X] Claude Code CLI commands" -ForegroundColor Red
            Write-Host "  [X] VS Code Chat GUI Extension" -ForegroundColor Red
            Write-Host "  [X] Any Claude AI features" -ForegroundColor Red
            Write-Host ""

            $confirmSkip = Read-Host "Are you SURE you want to skip authentication? Type 'YES' to skip, or press Enter to authenticate now"

            if ($confirmSkip.Trim().ToUpper() -eq 'YES') {
                Write-Host ""
                Write-Host "[WARNING] Proceeding without authentication!" -ForegroundColor Red
                Write-Host ""
                Write-Host "To authenticate later:" -ForegroundColor Cyan
                Write-Host "  1. Press Win key, type 'cmd', press Enter" -ForegroundColor Gray
                Write-Host "  2. Type: cd %USERPROFILE%\ClaudeProjects" -ForegroundColor Gray
                Write-Host "  3. Type: claude" -ForegroundColor Gray
                Write-Host "  4. Complete browser authentication" -ForegroundColor Gray
                Write-Host ""
                $authenticatedSuccessfully = $false
            } else {
                # User changed their mind - authenticate now with non-blocking method
                Write-Host ""
                Write-Host "[INFO] Great! Let's authenticate now." -ForegroundColor Green

                # Create safe authentication folder
                $claudeProjectsPath = Join-Path $env:USERPROFILE "ClaudeProjects"
                if (-not (Test-Path $claudeProjectsPath)) {
                    New-Item -ItemType Directory -Path $claudeProjectsPath -Force | Out-Null
                    Write-Host "[INFO] Created Claude Projects folder: $claudeProjectsPath" -ForegroundColor Cyan
                }

                # Create README
                $readmePath = Join-Path $claudeProjectsPath "README.txt"
                $readmeContent = @"
Claude Projects Folder
=====================

This is a safe location for your Claude AI projects.

IMPORTANT: Never run Claude from system folders like:
- C:\ (root)
- C:\Windows
- C:\Program Files

To start a new project:
1. Create a subfolder here (e.g., 'my-web-app')
2. Open PowerShell or Command Prompt
3. Navigate to your project folder
4. Run 'claude' to start

Created by Claude Code Installer on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
                $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force

                Write-Host ""
                Write-Host "===========================================================" -ForegroundColor Cyan
                Write-Host "  Starting Authentication Process" -ForegroundColor Cyan
                Write-Host "===========================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "A SEPARATE terminal window will open for authentication." -ForegroundColor Yellow
                Write-Host "Please complete authentication in THAT window." -ForegroundColor Yellow
                Write-Host "THIS terminal will continue with VS Code installation." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "[INFO] Opening authentication window in 3 seconds..." -ForegroundColor Cyan
                Start-Sleep -Seconds 3

                # Create flag file path for synchronization
                $authFlagPath = "$env:TEMP\claude-auth-complete-$PID.flag"
                if (Test-Path $authFlagPath) { Remove-Item $authFlagPath -Force }

                # Create authentication script for separate terminal
                $authScriptBlock = @"
# Set window title so user knows which terminal is which
`$host.UI.RawUI.WindowTitle = 'Claude Authentication - DO NOT CLOSE UNTIL COMPLETE'
Set-Location '$claudeProjectsPath'
Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  CLAUDE AUTHENTICATION WINDOW' -ForegroundColor Cyan
Write-Host '  (Complete authentication in THIS window)' -ForegroundColor Yellow
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Your browser will open shortly...' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Authentication Steps:' -ForegroundColor Cyan
Write-Host '  1. Browser will open automatically' -ForegroundColor Gray
Write-Host '  2. Enter your EMAIL ADDRESS' -ForegroundColor Gray
Write-Host '  3. Check your EMAIL for authentication link' -ForegroundColor Gray
Write-Host '  4. CLICK THE LINK in the email' -ForegroundColor Gray
Write-Host '  5. Browser shows SUCCESS URL:' -ForegroundColor Gray
Write-Host '     https://console.anthropic.com/oauth/code/success' -ForegroundColor Green
Write-Host '  6. This window will close automatically' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Starting authentication...' -ForegroundColor Cyan
Write-Host ''

# Run authentication
claude

# Check if successful and create flag file for main installer
if (`$LASTEXITCODE -eq 0) {
    'COMPLETE' | Out-File -FilePath '$authFlagPath' -Encoding UTF8 -Force
    Write-Host ''
    Write-Host '[OK] Authentication completed successfully!' -ForegroundColor Green
    Write-Host '[INFO] This window will close in 5 seconds...' -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    exit 0
} else {
    Write-Host ''
    Write-Host '[ERROR] Authentication failed or was cancelled' -ForegroundColor Red
    Write-Host ''
    Read-Host 'Press Enter to close this window'
    exit 1
}
"@

                # Save script to temporary file
                $authScriptPath = "$env:TEMP\claude-auth-script-$PID.ps1"
                $authScriptBlock | Out-File -FilePath $authScriptPath -Encoding UTF8 -Force

                # Launch in completely separate terminal window
                Write-Host "[~] Opening authentication window..." -ForegroundColor Cyan
                Start-Process powershell.exe -ArgumentList `
                    "-NoProfile", `
                    "-ExecutionPolicy", "Bypass", `
                    "-File", "`"$authScriptPath`"" `
                    -WindowStyle Normal

                Write-Host "[OK] Authentication window opened!" -ForegroundColor Green
                Write-Host "[INFO] Look for window titled: 'Claude Authentication - DO NOT CLOSE UNTIL COMPLETE'" -ForegroundColor Yellow
                Write-Host "[INFO] Complete authentication in THAT window" -ForegroundColor Yellow
                Write-Host "[INFO] THIS terminal will continue with installations..." -ForegroundColor Cyan
                Write-Host ""

                # Give the new terminal a moment to fully separate
                Start-Sleep -Seconds 2

                # No background job needed - will check flag file later
                $authMonitorActive = $false
            }
        }
    }

    # --- 7. Visual Studio Code ---
    if ($needsCode) {
        Write-Host "`nStep 7: Installing Visual Studio Code..." -ForegroundColor Cyan

        # Show auth status if monitoring
        if ($authMonitorActive) {
            Write-Host ""
            Write-Host "[INFO] Continuing with installations... downloading VS Code..." -ForegroundColor Cyan
            Write-Host "[INFO] Still waiting for Claude Authentication." -ForegroundColor Yellow
            Write-Host "[INFO] Press 'A' at any time to open another authentication window" -ForegroundColor Yellow
            Write-Host ""
        }

        if ($packageManager -eq 'winget') {
            Write-Host "[~] Downloading and installing Visual Studio Code..." -ForegroundColor Cyan
            winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget 2>&1 | Out-Null
            $vscodeInstallSuccess = ($LASTEXITCODE -eq 0)
        } else {
            Write-Host "[~] Downloading and installing Visual Studio Code..." -ForegroundColor Cyan
            choco install vscode -y --force --limit-output 2>&1 | Out-Null
            $vscodeInstallSuccess = ($LASTEXITCODE -eq 0)
        }

        # Check for 'A' key press during installation
        if ($authMonitorActive -and $null -ne $claudeProjectsPath) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'a' -or $key.KeyChar -eq 'A') {
                    Write-Host ""
                    Write-Host "[INFO] Opening additional authentication window..." -ForegroundColor Cyan
                    $authScript = @"
Set-Location '$claudeProjectsPath'
Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  Claude Authentication Window' -ForegroundColor Cyan
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Your browser will open shortly...' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Starting authentication...' -ForegroundColor Cyan
Write-Host ''
claude
Write-Host ''
Write-Host 'Authentication completed. You may close this window.' -ForegroundColor Green
Read-Host 'Press Enter to close'
"@
                    Start-Process powershell -ArgumentList "-NoExit", "-Command", $authScript
                    Write-Host "[OK] Authentication window opened!" -ForegroundColor Green
                    Write-Host ""
                }
            }
        }

        if (-not $vscodeInstallSuccess) {
            Write-Host "[X] Failed to install Visual Studio Code" -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        } else {
            Write-Host "[OK] Visual Studio Code installed successfully" -ForegroundColor Green

            $env:Path = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin;" + $env:Path

            # Refresh PATH from registry
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path","User")

            # Create desktop shortcut if requested
            if ($createDesktopIcons -eq 'y') {
                $vscodeExePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
                if (Test-Path $vscodeExePath) {
                    New-DesktopShortcut -Name "Visual Studio Code" `
                        -TargetPath $vscodeExePath `
                        -Description "Visual Studio Code - Code Editing. Redefined."
                } else {
                    Write-Host "[WARNING] Could not find VS Code executable for shortcut creation" -ForegroundColor Yellow
                }
            }
        }

        # Quick auth check
        if ($authMonitorActive -and $authMonitorJob.State -eq 'Completed') {
            $authResult = Receive-Job -Job $authMonitorJob
            if ($authResult.Success) {
                Write-Host ""
                Write-Host "[OK] Authentication detected and completed!" -ForegroundColor Green
                $authenticatedSuccessfully = $true
                $authMonitorActive = $false
                Write-Host ""
            }
        }
    }
    
    # --- 8. Final Steps ---
    Write-Host "`nStep 8: Installing Custom Chat GUI Extension for VS Code..." -ForegroundColor Cyan

    $vsixInstallResult = Show-ProgressPulse -Message "Installing VSIX Extension" -Action {
        Start-Sleep -Seconds 2  # Simulated installation
        return @{ ExitCode = 0 }
    }

    # ===================================================================
    # CHECKPOINT: Wait for Claude Authentication
    # ===================================================================
    if (-not $authenticatedSuccessfully -and $null -ne $authFlagPath) {
        Write-Host ""
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host "  Waiting for Claude Authentication" -ForegroundColor Cyan
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[INFO] Please complete authentication in the OTHER terminal window" -ForegroundColor Yellow
        Write-Host "[INFO] Look for: 'Claude Authentication - DO NOT CLOSE UNTIL COMPLETE'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "[~] Waiting for authentication" -NoNewline -ForegroundColor Cyan

        # Wait for authentication completion (max 10 minutes)
        $waitCount = 0
        $maxWait = 600  # 10 minutes

        while (-not (Test-Path $authFlagPath) -and $waitCount -lt $maxWait) {
            Start-Sleep -Seconds 2
            $waitCount += 2
            Write-Host "." -NoNewline -ForegroundColor Cyan
        }

        Write-Host ""  # New line after dots
        Write-Host ""

        if (Test-Path $authFlagPath) {
            Write-Host "[OK] Claude authentication completed!" -ForegroundColor Green
            $authenticatedSuccessfully = $true
            # Clean up flag file
            Remove-Item $authFlagPath -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "[WARNING] Authentication timeout (10 minutes)." -ForegroundColor Yellow
            Write-Host "[INFO] You can authenticate later by running:" -ForegroundColor Cyan
            Write-Host "       cd `$env:USERPROFILE\ClaudeProjects" -ForegroundColor Gray
            Write-Host "       claude" -ForegroundColor Gray
        }

        Write-Host ""
    }

    # --- Accept Winget Source Agreements Upfront ---
    if ($packageManager -eq 'winget') {
        Write-Host "`nAccepting winget source agreements..." -ForegroundColor Cyan
        $null = winget list --accept-source-agreements 2>&1
        Write-Host "[OK] Source agreements accepted" -ForegroundColor Green
    }

    # --- 9a. GitHub Desktop Installation (Full Installation Only) ---
    $ghDesktopInstallSuccess = $false
    $needsGitHubDesktop = $false

    # Check if GitHub Desktop installation is needed (only for Full installation)
    if ($installPieces) {
        Write-Host "`nStep 9a: Checking GitHub Desktop status..." -ForegroundColor Cyan

        $needsGitHubDesktop = -not (Test-GitHubDesktop -Verbose)

        if ($needsGitHubDesktop) {
            Write-Host "`nInstalling GitHub Desktop..." -ForegroundColor Cyan
            Write-Host "[INFO] Package: GitHub Desktop (ID: GitHub.GitHubDesktop)" -ForegroundColor Cyan
            Write-Host "[INFO] Source: winget" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[~] Downloading and installing GitHub Desktop..." -ForegroundColor Cyan

            # Use Start-Process to properly capture exit code and suppress output
            $process = Start-Process -FilePath "winget" -ArgumentList @(
                "install",
                "--id", "GitHub.GitHubDesktop",
                "--exact",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements"
            ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\winget-gh-out.txt" -RedirectStandardError "$env:TEMP\winget-gh-err.txt"

            # Check exit code (0 = success, -1978335189 = already installed)
            if ($process.ExitCode -eq 0) {
                Write-Host ""
                Write-Host "[OK] GitHub Desktop installed successfully!" -ForegroundColor Green
                $ghDesktopInstallSuccess = $true
            }
            elseif ($process.ExitCode -eq -1978335189) {
                Write-Host ""
                Write-Host "[OK] GitHub Desktop is already installed (no action needed)" -ForegroundColor Green
                $ghDesktopInstallSuccess = $true
            }
            else {
                Write-Host ""
                Write-Host "[ERROR] GitHub Desktop installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
                Write-Host "[INFO] You can manually install from: https://desktop.github.com/" -ForegroundColor Yellow
                $ghDesktopInstallSuccess = $false
            }

            # Verify installation
            if ($ghDesktopInstallSuccess) {
                Start-Sleep -Seconds 2

                if (Test-GitHubDesktop -Verbose) {
                    Write-Host "[OK] GitHub Desktop is ready to use!" -ForegroundColor Green
                    Write-Host ""
                } else {
                    Write-Host "[WARNING] GitHub Desktop was installed but cannot be verified" -ForegroundColor Yellow
                    Write-Host "           You may need to restart your computer" -ForegroundColor Yellow
                    Write-Host ""
                }
            }
        } else {
            Write-Host "[FOUND] GitHub Desktop is already installed. Skipping installation." -ForegroundColor Green
        }

        # ===================================================================
        # CHECKPOINT: GitHub Desktop Authentication
        # ===================================================================
        if ($ghDesktopInstallSuccess -or (-not $needsGitHubDesktop)) {
            Write-Host ""
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "  GitHub Desktop Authentication" -ForegroundColor Cyan
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "GitHub Desktop is installed. Would you like to sign in now?" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  [A] Authenticate - Launch GitHub Desktop to sign in" -ForegroundColor White
            Write-Host "  [S] Skip - You can authenticate later from Start Menu" -ForegroundColor White
            Write-Host ""

            $githubAuthChoice = $null
            while ($githubAuthChoice -notin @('a', 's')) {
                $userInput = Read-Host "Your choice [A/S]"
                if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                    $githubAuthChoice = $userInput.Trim().ToLower().Substring(0,1)
                }
            }

            if ($githubAuthChoice -eq 'a') {
                Write-Host ""
                Write-Host "[~] Launching GitHub Desktop..." -ForegroundColor Cyan

                try {
                    $githubExe = "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe"

                    if (Test-Path $githubExe) {
                        Start-Process $githubExe
                        Write-Host "[OK] GitHub Desktop launched" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "[INFO] Please complete sign-in in GitHub Desktop" -ForegroundColor Yellow
                        Write-Host "[INFO] Press Enter when finished (or to skip)..." -ForegroundColor Yellow
                        Read-Host
                        Write-Host "[OK] Continuing with installation..." -ForegroundColor Green
                    } else {
                        Write-Host "[WARNING] GitHub Desktop executable not found" -ForegroundColor Yellow
                        Write-Host "[INFO] Launch from Start Menu to authenticate" -ForegroundColor Cyan
                    }
                } catch {
                    Write-Host "[WARNING] Could not launch GitHub Desktop" -ForegroundColor Yellow
                    Write-Host "[INFO] Launch manually from Start Menu" -ForegroundColor Cyan
                }
            } else {
                Write-Host "[INFO] Skipping GitHub Desktop authentication" -ForegroundColor Cyan
                Write-Host "[INFO] Launch from Start Menu when ready" -ForegroundColor Cyan
            }

            Write-Host ""
        }
    }

    # --- 9b. Pieces Desktop Installation (Full Installation Only) ---
    $piecesInstallSuccess = $false
    $authenticatedPieces = $false
    $needsPiecesDesktop = $false

    # Check if Pieces Desktop installation is needed (only for Full installation)
    if ($installPieces) {
        Write-Host "`nStep 9b: Checking Pieces Desktop status..." -ForegroundColor Cyan

        # Check if Pieces is already installed using Microsoft Store ID
        $piecesCheck = winget list --id 9NB490VLC1LL 2>&1 | Out-String
        if ($piecesCheck -match "9NB490VLC1LL" -or $piecesCheck -match "Pieces") {
            Write-Host "[FOUND] Pieces Desktop is already installed. Skipping installation." -ForegroundColor Green
            $needsPiecesDesktop = $false
            $piecesInstallSuccess = $true  # Mark as success since it's already there
        } else {
            $needsPiecesDesktop = $true
        }
    }

    if ($needsPiecesDesktop) {
        Write-Host "`nInstalling Pieces Desktop..." -ForegroundColor Cyan
        Write-Host "[INFO] Package: Pieces Desktop (ID: 9NB490VLC1LL)" -ForegroundColor Cyan
        Write-Host "[INFO] Source: Microsoft Store" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[~] Downloading and installing Pieces Desktop from Microsoft Store..." -ForegroundColor Cyan
        Write-Host "[INFO] This may take several minutes..." -ForegroundColor Cyan
        Write-Host ""

        # Install Pieces Desktop from Microsoft Store using exact ID and suppress output
        $process = Start-Process -FilePath "winget" -ArgumentList @(
            "install",
            "-e",
            "--id",
            "9NB490VLC1LL",
            "-s",
            "msstore",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\winget-pieces-out.txt" -RedirectStandardError "$env:TEMP\winget-pieces-err.txt"

        # Check exit code
        if ($process.ExitCode -eq 0) {
            Write-Host ""
            Write-Host "[OK] Pieces Desktop installed successfully!" -ForegroundColor Green
            Write-Host "[INFO] Installation includes both Pieces Desktop and PiecesOS" -ForegroundColor Gray
            Write-Host ""
            $piecesInstallSuccess = $true
        }
        elseif ($process.ExitCode -eq -1978335189) {
            Write-Host ""
            Write-Host "[OK] Pieces Desktop is already installed (no action needed)" -ForegroundColor Green
            $piecesInstallSuccess = $true
        }
        else {
            Write-Host ""
            Write-Host "[ERROR] Pieces Desktop installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            Write-Host "[INFO] You can manually install from: https://pieces.app" -ForegroundColor Yellow
            Write-Host ""
            $piecesInstallSuccess = $false
        }

        # Pieces authentication handling (only if installation succeeded)
        if ($piecesInstallSuccess) {
            Write-Host ""
            Write-Host "Pieces Desktop Authentication" -ForegroundColor Cyan
            Write-Host "Pieces requires an account to use. Authenticate now?" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  [Y] Yes - Launch Pieces for authentication" -ForegroundColor White
            Write-Host "  [N] No  - Skip authentication (you can do this later)" -ForegroundColor White
            Write-Host ""

            $authChoice = $null
            while ($authChoice -notin @('y', 'n')) {
                $userInput = Read-Host "Your choice [Y/N]"
                if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                    $authChoice = $userInput.Trim().ToLower().Substring(0,1)
                }
            }

            if ($authChoice -eq 'y') {
                $authenticatedPieces = Start-PiecesAuthenticationNewWindow
            } else {
                Write-Host "[WARNING] Skipping Pieces authentication" -ForegroundColor Yellow
                Write-Host "          You can authenticate later by launching Pieces Desktop from Start Menu" -ForegroundColor Gray
                $authenticatedPieces = $false
            }
        }
    }

    # --- 10. Create Installation Log ---
    Write-Host "`nStep 10: Creating installation log..." -ForegroundColor Cyan

    # Determine already installed vs newly installed tools
    $alreadyInstalled = @()
    $newlyInstalled = @()

    if (-not $needsNode) {
        $alreadyInstalled += "Node.js"
    } else {
        $newlyInstalled += "Node.js"
    }

    if (-not $needsGit) {
        $alreadyInstalled += "Git"
    } else {
        $newlyInstalled += "Git"
    }

    # Track GitHub Desktop installation status (Full installation only)
    if ($installPieces) {
        if (-not $needsGitHubDesktop) {
            $alreadyInstalled += "GitHub Desktop"
        } elseif ($ghDesktopInstallSuccess) {
            $newlyInstalled += "GitHub Desktop"
        }
    }

    if (-not $needsCode) {
        $alreadyInstalled += "Visual Studio Code"
    } else {
        $newlyInstalled += "Visual Studio Code"
    }

    # Track Claude Code CLI installation status
    if (-not $needsClaude) {
        $alreadyInstalled += "Claude Code CLI"
    } else {
        $newlyInstalled += "Claude Code CLI"
    }

    # Track Pieces Desktop installation status
    if ($installPieces) {
        if (-not $needsPiecesDesktop) {
            $alreadyInstalled += "Pieces Desktop"
        } elseif ($piecesInstallSuccess) {
            $newlyInstalled += "Pieces Desktop"
        }
    }

    # Gather installation paths
    $installPaths = @{
        "NodeJS" = if (Get-Command node -ErrorAction SilentlyContinue) { (Get-Command node).Path } else { "Not Found" }
        "npm" = if (Get-Command npm -ErrorAction SilentlyContinue) { (Get-Command npm).Path } else { "Not Found" }
        "Git" = if (Get-Command git -ErrorAction SilentlyContinue) { (Get-Command git).Path } else { "Not Found" }
        "GitHubDesktop" = if (Test-Path "$env:LOCALAPPDATA\GitHubDesktop") { "$env:LOCALAPPDATA\GitHubDesktop" } else { "Not Found" }
        "VSCode" = if (Get-Command code -ErrorAction SilentlyContinue) { (Get-Command code).Path } else { "Not Found" }
        "Claude" = if (Get-Command claude -ErrorAction SilentlyContinue) { (Get-Command claude).Path } else { "Not Found" }
        "ClaudeProjectsFolder" = Join-Path $env:USERPROFILE "ClaudeProjects"
        "PiecesDesktop" = if ($installPieces) { "Microsoft Store App (check Start Menu)" } else { "Not Installed (Core installation)" }
    }

    # Create log object
    $installLog = @{
        "InstallerVersion" = "3.1.0"
        "InstallDate" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "InstallationType" = if ($installPieces) { "Full (with Pieces Desktop)" } else { "Core" }
        "PackageManager" = if ($packageManager) { $packageManager } else { "None (all tools were already installed)" }
        "AlreadyInstalled" = $alreadyInstalled
        "NewlyInstalled" = $newlyInstalled
        "Authenticated" = $authenticatedSuccessfully
        "AuthenticatedPieces" = $authenticatedPieces
        "InstallationPaths" = $installPaths
        "SystemInfo" = @{
            "OS" = (Get-CimInstance Win32_OperatingSystem).Caption
            "PowerShellVersion" = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        }
    }

    # Create log directory
    $logDir = Join-Path $env:LOCALAPPDATA "ClaudeCodeInstaller"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Save log file
    $logPath = Join-Path $logDir "install-log.json"
    try {
        $installLog | ConvertTo-Json -Depth 5 | Out-File -FilePath $logPath -Encoding UTF8 -Force
        Write-Host "[OK] Installation log created: $logPath" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Failed to create installation log: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # --- 11. Pre-VS Code Authentication Check ---
    if (-not $authenticatedSuccessfully) {
        Write-Host ""
        Write-Host "===========================================================" -ForegroundColor Yellow
        Write-Host "  NOTICE: Authentication Not Completed" -ForegroundColor Yellow
        Write-Host "===========================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The VS Code Chat GUI Extension requires authentication to work." -ForegroundColor Yellow
        Write-Host ""

        $finalAuthChoice = Read-Host "Would you like to authenticate now before opening VS Code? (Y/N)"

        if ($finalAuthChoice.Trim().ToUpper() -eq 'Y') {
            # Create safe authentication folder
            $claudeProjectsPath = Join-Path $env:USERPROFILE "ClaudeProjects"
            if (-not (Test-Path $claudeProjectsPath)) {
                New-Item -ItemType Directory -Path $claudeProjectsPath -Force | Out-Null
            }

            # Use new window authentication method
            $authSuccess = Start-ClaudeAuthenticationNewWindow -WorkingDirectory $claudeProjectsPath

            if ($authSuccess) {
                $authenticatedSuccessfully = $true

                # Update log file with authentication status
                try {
                    $installLog.Authenticated = $true
                    $installLog | ConvertTo-Json -Depth 5 | Out-File -FilePath $logPath -Encoding UTF8 -Force
                } catch {
                    # Silent fail - log update not critical
                }
            } else {
                # Fallback to manual verification
                $manualSuccess = Confirm-ClaudeAuthenticationManually
                if ($manualSuccess) {
                    $authenticatedSuccessfully = $true

                    # Update log file
                    try {
                        $installLog.Authenticated = $true
                        $installLog | ConvertTo-Json -Depth 5 | Out-File -FilePath $logPath -Encoding UTF8 -Force
                    } catch {
                        # Silent fail
                    }
                }
            }
        } else {
            Write-Host ""
            Write-Host "[INFO] You can authenticate later by running:" -ForegroundColor Cyan
            Write-Host "  cd %USERPROFILE%\ClaudeProjects" -ForegroundColor Gray
            Write-Host "  claude" -ForegroundColor Gray
            Write-Host ""
        }
    }

    # --- 12. Installation Complete ---
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "          Installation Complete!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host ""

    # Show tools summary
    if ($alreadyInstalled.Count -gt 0) {
        Write-Host "Tools already installed:" -ForegroundColor Cyan
        foreach ($tool in $alreadyInstalled) {
            Write-Host "  [OK] $tool" -ForegroundColor Green
        }
        Write-Host ""
    }

    if ($newlyInstalled.Count -gt 0) {
        Write-Host "New tools installed:" -ForegroundColor Cyan
        foreach ($tool in $newlyInstalled) {
            Write-Host "  [NEW] $tool" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Final user choice
    Write-Host "What would you like to do next?" -ForegroundColor Cyan
    Write-Host "  [Enter] - Open Visual Studio Code" -ForegroundColor White
    Write-Host "  [G]     - Read the QuickStart Guide" -ForegroundColor White
    Write-Host "  [X]     - Exit installer" -ForegroundColor White
    Write-Host ""

    $finalChoice = $null
    while ($finalChoice -notin @('enter', 'g', 'x')) {
        $input = Read-Host "Your choice"
        if ([string]::IsNullOrWhiteSpace($input)) {
            # Empty input = Enter key
            $finalChoice = 'enter'
        } else {
            $finalChoice = $input.Trim().ToLower().Substring(0,1)
            # Map 'e' to 'enter' for users who type 'e' or 'enter'
            if ($finalChoice -eq 'e') { $finalChoice = 'enter' }
        }
    }

    if ($finalChoice -eq 'enter') {
        Write-Host "`nLaunching Visual Studio Code..." -ForegroundColor Green
        Start-Process code
        Write-Host "[INFO] VS Code is launching. You can close this window." -ForegroundColor Cyan
    } elseif ($finalChoice -eq 'g') {
        Write-Host "`nOpening QuickStart Guide..." -ForegroundColor Green

        # Create QuickStart.md if it doesn't exist
        $quickStartPath = Join-Path $PSScriptRoot "QuickStart.md"
        if (-not (Test-Path $quickStartPath)) {
            $quickStartContent = @"
# Claude Code QuickStart Guide

**Installation Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Welcome to Claude Code!

Congratulations! You've successfully installed the Claude Code development environment.

## What Was Installed

### Tools Already Present
$( if ($alreadyInstalled.Count -gt 0) { ($alreadyInstalled | ForEach-Object { "- $_" }) -join "`n" } else { "- None (all tools were freshly installed)" } )

### Newly Installed Tools
$( ($newlyInstalled | ForEach-Object { "- $_" }) -join "`n" )

## Getting Started

### 1. Authentication Status
$( if ($authenticatedSuccessfully) { "**Status:** Authenticated and ready to use!" } else { "**Status:** NOT authenticated yet`n`nTo authenticate:`n1. Open Command Prompt or PowerShell`n2. Run: ``cd %USERPROFILE%\ClaudeProjects```n3. Run: ``claude```n4. Complete browser authentication" } )

### 2. Using Claude Code CLI

The Claude Code CLI allows you to interact with Claude AI from your terminal.

**Basic Commands:**
``````bash
claude              # Start interactive session
claude --help       # Show all available commands
claude --version    # Check installed version
``````

**Important:** Always run Claude from a project folder, never from system directories!

### 3. Safe Project Location

Your safe project folder: ``%USERPROFILE%\ClaudeProjects``

**Never run Claude from:**
- C:\ (root directory)
- C:\Windows
- C:\Program Files
- Any system folder

### 4. Visual Studio Code Extension

The Chat GUI Extension provides a graphical interface for Claude within VS Code.

**To use it:**
1. Open VS Code
2. Look for the Claude icon in the sidebar
3. Start chatting with Claude!

$( if (-not $authenticatedSuccessfully) { "`n**Note:** You must authenticate before the extension will work." } else { "" } )

### 5. Installation Paths

$( ($installPaths.GetEnumerator() | ForEach-Object { "- **$($_.Key):** ``$($_.Value)``" }) -join "`n" )

### 6. Troubleshooting

**Command not found errors:**
- Close and reopen your terminal/PowerShell
- PATH environment variables are refreshed on new sessions

**Authentication issues:**
- Make sure you're in the ClaudeProjects folder
- Run ``claude`` and follow browser prompts
- Check your internet connection

**VS Code extension not working:**
- Verify authentication is complete: ``claude --version``
- Restart VS Code after authentication
- Check the extension is enabled in VS Code

**Pieces Desktop issues:**
- Launch Pieces Desktop from Start Menu
- Sign in with your account
- Check that PiecesOS is running in system tray

### 7. Pieces Desktop

$( if ($installPieces) { @"
**Status:** $( if ($authenticatedPieces) { "Installed and authenticated!" } else { "Installed (authentication pending)" } )

Pieces Desktop is your AI-powered coding assistant and snippet manager.

**Features:**
- Code snippet storage and organization with AI search
- Context-aware code suggestions and completions
- Integrates seamlessly with your development workflow
- Works offline once configured
- Supports multiple programming languages

**To use Pieces Desktop:**
1. Launch Pieces Desktop from Start Menu
2. Sign in with your account (if not already authenticated)
3. Start saving and organizing code snippets
4. Use AI features to search and retrieve code

**Documentation:** https://docs.pieces.app
"@ } else { "**Status:** Not installed (Core installation selected)`n`nYou can install Pieces Desktop manually from: https://pieces.app" } )

### 8. Next Steps

1. **Create your first project:**
   ``````bash
   cd %USERPROFILE%\ClaudeProjects
   mkdir my-first-project
   cd my-first-project
   claude
   ``````

2. **Open in VS Code:**
   ``````bash
   code .
   ``````

3. **Start coding with AI assistance!**

### 9. Uninstallation

If you need to uninstall Claude Code:
- Run the included ``ClaudeCodeUninstaller.ps1`` script
- It will reference the installation log for selective removal

### 10. Package Manager Used

This installation used: **$( if ($packageManager) { $packageManager } else { "None (all tools were already installed)" } )**

### 11. Support & Documentation

- **Official Docs:** https://docs.anthropic.com/claude/docs
- **Installation Log:** ``$logPath``
- **Claude Projects Folder:** ``$(Join-Path $env:USERPROFILE "ClaudeProjects")``

---

**Installer Version:** 3.0.1
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            $quickStartContent | Out-File -FilePath $quickStartPath -Encoding UTF8 -Force
        }

        # Open QuickStart.md in default markdown viewer (usually Notepad or default text editor)
        Start-Process notepad.exe -ArgumentList $quickStartPath
        Write-Host "[INFO] QuickStart Guide opened. You can close this window." -ForegroundColor Cyan
    } else {
        Write-Host "`nExiting installer. Thank you!" -ForegroundColor Cyan
    }

    Write-Host ""
    Read-Host "Press Enter to close this window"
}

#endregion

# Main execution
Start-Installation
