<#
.MODULE
    Authentication.psm1
.SYNOPSIS
    Claude Code authentication module
.DESCRIPTION
    Provides unified authentication functions for Claude Code CLI
.VERSION
    1.0.0
#>

function Test-ClaudeAuthentication {
    <#
    .SYNOPSIS
        Checks if Claude CLI is authenticated
    .PARAMETER Verbose
        Show detailed diagnostic output
    .OUTPUTS
        [PSCustomObject] with properties: IsAuthenticated, CredentialPath, Method, ExpiresAt, HasRefreshToken
    .EXAMPLE
        $authStatus = Test-ClaudeAuthentication -Verbose
        if ($authStatus.IsAuthenticated) { Write-Host "Already authenticated" }
    #>
    [CmdletBinding()]
    param(
        [switch]$Verbose
    )

    # Check all possible credential file locations
    $credentialPaths = @(
        "$env:USERPROFILE\.claude\.credentials.json",
        "$env:USERPROFILE\.config\claude-code\auth.json",
        "$env:USERPROFILE\.config\claude\auth.json",
        "$env:APPDATA\claude\credentials.json"
    )

    if ($Verbose) {
        Write-Host "  [VERBOSE] Checking credential file locations..." -ForegroundColor Magenta
    }

    foreach ($path in $credentialPaths) {
        if ($Verbose) {
            Write-Host "  [VERBOSE] Checking: $path" -ForegroundColor Magenta
        }

        if (Test-Path $path) {
            if ($Verbose) {
                $fileInfo = Get-Item $path
                $fileAge = (Get-Date) - $fileInfo.LastWriteTime
                Write-Host "  [VERBOSE] File found! Age: $([Math]::Round($fileAge.TotalSeconds, 1))s" -ForegroundColor Magenta
            }

            # Wait briefly if file is very new (ensure complete write)
            $fileInfo = Get-Item $path
            $fileAge = (Get-Date) - $fileInfo.LastWriteTime
            if ($fileAge.TotalSeconds -lt 2) {
                if ($Verbose) {
                    Write-Host "  [VERBOSE] File is very new, waiting 2s for complete write..." -ForegroundColor Magenta
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
                            Write-Host "  [VERBOSE] Read attempt $retryCount failed, retrying..." -ForegroundColor Magenta
                        }
                        Start-Sleep -Seconds 1
                    } else {
                        if ($Verbose) {
                            Write-Host "  [VERBOSE] Failed to read after $maxRetries attempts" -ForegroundColor Magenta
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
                    Write-Host "  [VERBOSE] File does not contain claudeAiOauth object" -ForegroundColor Magenta
                }
                continue
            }

            $oauthCreds = $credentials.claudeAiOauth

            if ($Verbose) {
                Write-Host "  [VERBOSE] claudeAiOauth object found" -ForegroundColor Magenta
            }

            # Check for required token fields
            $hasAccessToken = $null -ne $oauthCreds.accessToken -and $oauthCreds.accessToken -ne ""
            $hasRefreshToken = $null -ne $oauthCreds.refreshToken -and $oauthCreds.refreshToken -ne ""

            if ($Verbose) {
                Write-Host "  [VERBOSE] Has access token: $hasAccessToken" -ForegroundColor Magenta
                Write-Host "  [VERBOSE] Has refresh token: $hasRefreshToken" -ForegroundColor Magenta
            }

            if ($hasAccessToken -or $hasRefreshToken) {
                # Check token expiration if available
                $expiresAt = $null
                $isExpired = $false

                if ($oauthCreds.PSObject.Properties.Name -contains 'expiresAt') {
                    # expiresAt is in MILLISECONDS, not seconds
                    $expiresAtMs = $oauthCreds.expiresAt
                    $expiresAt = [DateTimeOffset]::FromUnixTimeMilliseconds($expiresAtMs).DateTime
                    $isExpired = (Get-Date) -gt $expiresAt

                    if ($Verbose) {
                        $timeUntilExpiry = $expiresAt - (Get-Date)
                        Write-Host "  [VERBOSE] Token expires at: $expiresAt" -ForegroundColor Magenta
                        Write-Host "  [VERBOSE] Time until expiry: $([Math]::Round($timeUntilExpiry.TotalHours, 1)) hours" -ForegroundColor Magenta
                        Write-Host "  [VERBOSE] Is expired: $isExpired" -ForegroundColor Magenta
                    }

                    # If expired but has refresh token, still valid (Claude will auto-refresh)
                    if ($isExpired -and -not $hasRefreshToken) {
                        if ($Verbose) {
                            Write-Host "  [VERBOSE] Token expired and no refresh token" -ForegroundColor Yellow
                        }
                        continue
                    }
                }

                if ($Verbose) {
                    Write-Host "  [VERBOSE] Authentication VALID" -ForegroundColor Green
                }

                # Return success object
                return [PSCustomObject]@{
                    IsAuthenticated = $true
                    CredentialPath = $path
                    Method = "OAuth"
                    ExpiresAt = $expiresAt
                    HasRefreshToken = $hasRefreshToken
                }
            }
        } else {
            if ($Verbose) {
                Write-Host "  [VERBOSE] File not found" -ForegroundColor Magenta
            }
        }
    }

    if ($Verbose) {
        Write-Host "  [VERBOSE] No valid authentication found" -ForegroundColor Yellow
    }

    # Return failure object
    return [PSCustomObject]@{
        IsAuthenticated = $false
        CredentialPath = $null
        Method = $null
        ExpiresAt = $null
        HasRefreshToken = $false
    }
}

function Start-ClaudeAuthentication {
    <#
    .SYNOPSIS
        Initiates Claude authentication process
    .PARAMETER WorkingDirectory
        Safe directory to run claude command from (default: $env:USERPROFILE\ClaudeProjects)
    .PARAMETER Method
        Authentication method: 'Blocking', 'SeparateWindow', 'Skip'
    .PARAMETER TimeoutMinutes
        Maximum wait time in minutes (default: 15)
    .OUTPUTS
        [PSCustomObject] Result with Success, Method, TimeTaken, ErrorMessage properties
    .EXAMPLE
        $result = Start-ClaudeAuthentication -WorkingDirectory "C:\Projects" -Method SeparateWindow
        if ($result.Success) { Write-Host "Authentication completed in $($result.TimeTaken.TotalSeconds)s" }
    #>
    [CmdletBinding()]
    param(
        [string]$WorkingDirectory = "$env:USERPROFILE\ClaudeProjects",

        [ValidateSet('Blocking','SeparateWindow','Skip')]
        [string]$Method = 'SeparateWindow',

        [int]$TimeoutMinutes = 15
    )

    $startTime = Get-Date

    # Ensure working directory exists
    if (-not (Test-Path $WorkingDirectory)) {
        try {
            New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        } catch {
            return [PSCustomObject]@{
                Success = $false
                Method = $Method
                TimeTaken = (Get-Date) - $startTime
                ErrorMessage = "Failed to create working directory: $_"
            }
        }
    }

    # Handle Skip method
    if ($Method -eq 'Skip') {
        return [PSCustomObject]@{
            Success = $false
            Method = 'Skip'
            TimeTaken = (Get-Date) - $startTime
            ErrorMessage = "Authentication skipped by user"
        }
    }

    # Handle Blocking method
    if ($Method -eq 'Blocking') {
        Write-Host "`n[~] Starting authentication (blocking mode)..." -ForegroundColor Cyan
        Write-Host "  Your browser will open. Follow the authentication steps." -ForegroundColor Gray
        Write-Host ""

        try {
            Push-Location $WorkingDirectory
            & claude
            Pop-Location

            Start-Sleep -Seconds 2
            $authCheck = Test-ClaudeAuthentication

            return [PSCustomObject]@{
                Success = $authCheck.IsAuthenticated
                Method = 'Blocking'
                TimeTaken = (Get-Date) - $startTime
                ErrorMessage = if ($authCheck.IsAuthenticated) { $null } else { "Authentication failed or incomplete" }
            }
        } catch {
            Pop-Location
            return [PSCustomObject]@{
                Success = $false
                Method = 'Blocking'
                TimeTaken = (Get-Date) - $startTime
                ErrorMessage = "Error during authentication: $_"
            }
        }
    }

    # Handle SeparateWindow method
    if ($Method -eq 'SeparateWindow') {
        Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
        Write-Host "  Claude Authentication" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "`nA new window will open. Follow these steps:" -ForegroundColor Yellow
        Write-Host "  1. Enter your EMAIL address" -ForegroundColor Gray
        Write-Host "  2. Check email for authentication link" -ForegroundColor Gray
        Write-Host "  3. Click link in ANY browser" -ForegroundColor Gray
        Write-Host "  4. Wait for success URL" -ForegroundColor Gray
        Write-Host "  5. Close the auth window when done`n" -ForegroundColor Gray

        Start-Sleep -Seconds 2

        # Create flag file path for synchronization
        $flagFile = Join-Path $env:TEMP "claude-auth-$([Guid]::NewGuid().ToString('N').Substring(0,8)).flag"

        # Get path to external authentication script
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $authScriptPath = Join-Path $scriptRoot "Scripts\Start-AuthenticationWindow.ps1"

        # Check if external script exists
        if (Test-Path $authScriptPath) {
            # Use external script
            $proc = Start-Process powershell -ArgumentList `
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$authScriptPath`"", `
                "-WorkingDirectory", "`"$WorkingDirectory`"", "-FlagFilePath", "`"$flagFile`"" `
                -PassThru
        } else {
            # Fallback: Use embedded script
            $authScript = @"
Set-Location '$WorkingDirectory'
Write-Host '`n============================================================' -ForegroundColor Cyan
Write-Host '  Claude Authentication Window' -ForegroundColor Cyan
Write-Host '============================================================`n' -ForegroundColor Cyan
Write-Host 'Your browser will open shortly...' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Steps:' -ForegroundColor Cyan
Write-Host '  1. Enter your EMAIL' -ForegroundColor Gray
Write-Host '  2. Check your EMAIL for link' -ForegroundColor Gray
Write-Host '  3. CLICK THE LINK' -ForegroundColor Gray
Write-Host '  4. Wait for SUCCESS URL' -ForegroundColor Gray
Write-Host '  5. Close this window`n' -ForegroundColor Gray
claude
Write-Host ''
if (`$LASTEXITCODE -eq 0) {
    Set-Content -Path '$flagFile' -Value 'SUCCESS'
    Write-Host 'Authentication completed successfully!' -ForegroundColor Green
} else {
    Set-Content -Path '$flagFile' -Value 'FAILED'
    Write-Host 'Authentication may have failed. Check credentials.' -ForegroundColor Yellow
}
Write-Host ''
Read-Host 'Press Enter to close'
"@
            $proc = Start-Process powershell -ArgumentList "-NoExit", "-Command", $authScript -PassThru
        }

        # Wait for completion using flag file
        $result = Wait-ForAuthenticationCompletion -FlagFilePath $flagFile -TimeoutMinutes $TimeoutMinutes

        # Final verification
        $authCheck = Test-ClaudeAuthentication

        # Clean up flag file
        if (Test-Path $flagFile) {
            Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
        }

        return [PSCustomObject]@{
            Success = $authCheck.IsAuthenticated
            Method = 'SeparateWindow'
            TimeTaken = (Get-Date) - $startTime
            ErrorMessage = if ($authCheck.IsAuthenticated) { $null } else { "Authentication not detected or incomplete" }
        }
    }
}

function Wait-ForAuthenticationCompletion {
    <#
    .SYNOPSIS
        Monitors for authentication completion via flag file
    .PARAMETER FlagFilePath
        Path to synchronization flag file
    .PARAMETER TimeoutMinutes
        Maximum wait time in minutes
    .OUTPUTS
        Boolean indicating whether flag file was detected
    .EXAMPLE
        $completed = Wait-ForAuthenticationCompletion -FlagFilePath "C:\temp\auth.flag" -TimeoutMinutes 15
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FlagFilePath,

        [int]$TimeoutMinutes = 15
    )

    $timeout = $TimeoutMinutes * 60  # Convert to seconds
    $elapsed = 0
    $checkInterval = 2  # Check every 2 seconds

    Write-Host "[~] Monitoring authentication..." -ForegroundColor Cyan
    Write-Host "  (Checking every 2 seconds, timeout: $TimeoutMinutes minutes)" -ForegroundColor Gray
    Write-Host ""

    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0

    while ($elapsed -lt $timeout) {
        # Check if flag file exists
        if (Test-Path $FlagFilePath) {
            Write-Host "`r[OK] Authentication signal detected!                                        " -ForegroundColor Green
            return $true
        }

        # Check if authentication completed (credential file check)
        $authCheck = Test-ClaudeAuthentication
        if ($authCheck.IsAuthenticated) {
            Write-Host "`r[OK] Authentication detected via credential file!                           " -ForegroundColor Green
            return $true
        }

        # Show spinner
        $remainingMinutes = [Math]::Floor(($timeout - $elapsed) / 60)
        $remainingSeconds = ($timeout - $elapsed) % 60
        Write-Host "`r  [$($spinner[$spinnerIndex % 4])] Waiting... (${remainingMinutes}m ${remainingSeconds}s remaining)" -NoNewline -ForegroundColor Cyan

        $spinnerIndex++
        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
    }

    Write-Host "`r[!] Authentication timeout reached                                              " -ForegroundColor Yellow
    return $false
}

function Confirm-AuthenticationManually {
    <#
    .SYNOPSIS
        Fallback method - asks user to manually verify authentication
    .OUTPUTS
        Boolean based on user confirmation
    .EXAMPLE
        $confirmed = Confirm-AuthenticationManually
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Yellow
    Write-Host "  Manual Authentication Verification" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Yellow
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

# Export module functions
Export-ModuleMember -Function @(
    'Test-ClaudeAuthentication',
    'Start-ClaudeAuthentication',
    'Wait-ForAuthenticationCompletion',
    'Confirm-AuthenticationManually'
)
