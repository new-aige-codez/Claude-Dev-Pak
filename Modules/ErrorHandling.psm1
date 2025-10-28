<#
.MODULE
    ErrorHandling.psm1
.SYNOPSIS
    Error handling and logging module for Claude Code installer
.DESCRIPTION
    Provides structured error collection, logging, and installation summary
.VERSION
    1.0.0
#>

# Module-scoped variables for error tracking
$script:ErrorCollection = @()
$script:WarningCollection = @()
$script:LogFilePath = $null
$script:InstallationStartTime = Get-Date
$script:ComponentSuccesses = @()

function Initialize-InstallLog {
    <#
    .SYNOPSIS
        Sets up logging infrastructure
    .PARAMETER LogDirectory
        Directory where log files will be stored (default: $env:LOCALAPPDATA\ClaudeCodeInstaller)
    .OUTPUTS
        Returns log file path
    .EXAMPLE
        $logPath = Initialize-InstallLog
        Write-Host "Logging to: $logPath"
    #>
    [CmdletBinding()]
    param(
        [string]$LogDirectory = "$env:LOCALAPPDATA\ClaudeCodeInstaller"
    )

    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogDirectory)) {
        try {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        } catch {
            Write-Host "[WARNING] Failed to create log directory: $LogDirectory" -ForegroundColor Yellow
            Write-Host "  Logging to temporary directory instead" -ForegroundColor Gray
            $LogDirectory = $env:TEMP
        }
    }

    # Generate log filename with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $logFileName = "install-log-$timestamp.txt"
    $script:LogFilePath = Join-Path $LogDirectory $logFileName

    # Initialize log file with header
    $header = @"
============================================================
Claude Code Development Environment Installer
Log File
============================================================
Installer Version: 4.0.0
Start Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
System: $env:COMPUTERNAME
OS: $([System.Environment]::OSVersion.VersionString)
PowerShell: $($PSVersionTable.PSVersion)
User: $env:USERNAME
============================================================

"@

    try {
        Set-Content -Path $script:LogFilePath -Value $header -ErrorAction Stop
        Write-Host "[OK] Log file created: $script:LogFilePath" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Failed to create log file: $_" -ForegroundColor Yellow
        $script:LogFilePath = $null
    }

    # Reset installation start time
    $script:InstallationStartTime = Get-Date

    return $script:LogFilePath
}

function Write-InstallLog {
    <#
    .SYNOPSIS
        Writes structured log entry to both console and file
    .PARAMETER Level
        Log level: Info, Success, Warning, Error, Debug
    .PARAMETER Component
        Which component is logging (e.g., "NodeJS", "Authentication", "Installer")
    .PARAMETER Message
        Log message
    .PARAMETER LogFilePath
        Optional override for log file path (uses module-scoped path if not provided)
    .EXAMPLE
        Write-InstallLog -Level Info -Component "NodeJS" -Message "Starting installation"
        Write-InstallLog -Level Success -Component "Git" -Message "Installation completed"
        Write-InstallLog -Level Error -Component "ClaudeCLI" -Message "npm install failed"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Success','Warning','Error','Debug')]
        [string]$Level = 'Info',

        [Parameter(Mandatory=$false)]
        [string]$Component = "Installer",

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [string]$LogFilePath = $script:LogFilePath
    )

    # Color mapping for console output
    $colorMap = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Debug' = 'Magenta'
    }

    # Symbol mapping for console output
    $symbolMap = @{
        'Info' = '[~]'
        'Success' = '[OK]'
        'Warning' = '[!]'
        'Error' = '[X]'
        'Debug' = '[D]'
    }

    $color = $colorMap[$Level]
    $symbol = $symbolMap[$Level]

    # Format console message
    $consoleMessage = "$symbol $Component`: $Message"

    # Write to console
    Write-Host $consoleMessage -ForegroundColor $color

    # Format file message with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileMessage = "$timestamp [$Level] [$Component] $Message"

    # Write to log file if available
    if ($LogFilePath -and (Test-Path $LogFilePath)) {
        try {
            Add-Content -Path $LogFilePath -Value $fileMessage -ErrorAction SilentlyContinue
        } catch {
            # Silently fail if log write fails
        }
    }

    # Add to collections based on level
    if ($Level -eq 'Warning') {
        $script:WarningCollection += [PSCustomObject]@{
            Timestamp = Get-Date
            Component = $Component
            Message = $Message
        }
    }

    if ($Level -eq 'Error') {
        $script:ErrorCollection += [PSCustomObject]@{
            Timestamp = Get-Date
            Component = $Component
            Message = $Message
            Critical = $false
        }
    }

    if ($Level -eq 'Success') {
        $script:ComponentSuccesses += [PSCustomObject]@{
            Timestamp = Get-Date
            Component = $Component
            Message = $Message
        }
    }
}

function Add-InstallError {
    <#
    .SYNOPSIS
        Adds error to collection for summary report
    .PARAMETER ErrorRecord
        The error record or custom error object
    .PARAMETER Component
        Which component failed
    .PARAMETER Critical
        Whether this is a critical failure (affects exit code)
    .EXAMPLE
        Add-InstallError -ErrorRecord $_ -Component "NodeJS" -Critical
        Add-InstallError -ErrorRecord "Installation failed" -Component "Git"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ErrorRecord,

        [Parameter(Mandatory=$false)]
        [string]$Component = "Unknown",

        [switch]$Critical
    )

    # Extract error message
    $errorMessage = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        $ErrorRecord.Exception.Message
    } elseif ($ErrorRecord -is [string]) {
        $ErrorRecord
    } else {
        $ErrorRecord.ToString()
    }

    # Extract stack trace if available
    $stackTrace = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        $ErrorRecord.ScriptStackTrace
    } else {
        $null
    }

    # Create structured error object
    $errorObject = [PSCustomObject]@{
        Timestamp = Get-Date
        Component = $Component
        Message = $errorMessage
        Critical = $Critical.IsPresent
        StackTrace = $stackTrace
    }

    # Add to error collection
    $script:ErrorCollection += $errorObject

    # Write to log
    Write-InstallLog -Level Error -Component $Component -Message $errorMessage

    # Write stack trace to log file if available
    if ($stackTrace -and $script:LogFilePath) {
        try {
            Add-Content -Path $script:LogFilePath -Value "  Stack Trace: $stackTrace" -ErrorAction SilentlyContinue
        } catch {
            # Silently fail
        }
    }
}

function Get-InstallSummary {
    <#
    .SYNOPSIS
        Generates final installation summary with error report
    .OUTPUTS
        PSCustomObject with success/failure counts, errors, warnings, duration, exit code
    .EXAMPLE
        $summary = Get-InstallSummary
        Write-Host "Installation took $($summary.Duration.TotalMinutes) minutes"
        Write-Host "Exit code: $($summary.ExitCode)"
    #>
    [CmdletBinding()]
    param()

    # Calculate duration
    $duration = (Get-Date) - $script:InstallationStartTime

    # Count errors by type
    $criticalErrors = @($script:ErrorCollection | Where-Object { $_.Critical })
    $nonCriticalErrors = @($script:ErrorCollection | Where-Object { -not $_.Critical })

    # Determine exit code
    # 0 = success (no errors)
    # 1 = critical failure (has critical errors)
    # 2 = partial success (has non-critical errors but no critical errors)
    $exitCode = if ($criticalErrors.Count -gt 0) {
        1
    } elseif ($nonCriticalErrors.Count -gt 0) {
        2
    } else {
        0
    }

    # Create summary object
    $summary = [PSCustomObject]@{
        SuccessCount = $script:ComponentSuccesses.Count
        WarningCount = $script:WarningCollection.Count
        ErrorCount = $script:ErrorCollection.Count
        CriticalErrorCount = $criticalErrors.Count
        NonCriticalErrorCount = $nonCriticalErrors.Count
        Duration = $duration
        Errors = $script:ErrorCollection
        Warnings = $script:WarningCollection
        Successes = $script:ComponentSuccesses
        ExitCode = $exitCode
        LogFilePath = $script:LogFilePath
    }

    # Write summary to log file
    if ($script:LogFilePath -and (Test-Path $script:LogFilePath)) {
        $summaryText = @"

============================================================
Installation Summary
============================================================
Duration: $($duration.ToString('mm\:ss'))
Successful Components: $($summary.SuccessCount)
Warnings: $($summary.WarningCount)
Errors: $($summary.ErrorCount)
Critical Errors: $($summary.CriticalErrorCount)
Exit Code: $($summary.ExitCode)
============================================================

"@
        try {
            Add-Content -Path $script:LogFilePath -Value $summaryText -ErrorAction SilentlyContinue

            # Add error details if any
            if ($summary.ErrorCount -gt 0) {
                Add-Content -Path $script:LogFilePath -Value "`nErrors:" -ErrorAction SilentlyContinue
                foreach ($error in $summary.Errors) {
                    $errorDetail = "  [$($error.Component)] $($error.Message)"
                    if ($error.Critical) {
                        $errorDetail += " [CRITICAL]"
                    }
                    Add-Content -Path $script:LogFilePath -Value $errorDetail -ErrorAction SilentlyContinue
                }
            }

            # Add warning details if any
            if ($summary.WarningCount -gt 0) {
                Add-Content -Path $script:LogFilePath -Value "`nWarnings:" -ErrorAction SilentlyContinue
                foreach ($warning in $summary.Warnings) {
                    Add-Content -Path $script:LogFilePath -Value "  [$($warning.Component)] $($warning.Message)" -ErrorAction SilentlyContinue
                }
            }

        } catch {
            # Silently fail
        }
    }

    return $summary
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-InstallLog',
    'Write-InstallLog',
    'Add-InstallError',
    'Get-InstallSummary'
)
