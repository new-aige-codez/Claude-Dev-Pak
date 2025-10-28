<#
.SYNOPSIS
    Configuration management module for Claude Code Installer
.DESCRIPTION
    Provides functions for loading, saving, validating, and merging configuration files
.NOTES
    Version: 1.0.0
    Part of Claude Code Installer v4.2.0+
#>

#region Get-InstallConfiguration

function Get-InstallConfiguration {
    <#
    .SYNOPSIS
        Loads configuration from file or creates default
    .PARAMETER ConfigPath
        Path to JSON config file
    .PARAMETER UseDefaults
        Create default config without loading file
    .OUTPUTS
        PSCustomObject with all configuration settings
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\InstallConfig.json",
        [switch]$UseDefaults
    )

    # Default configuration structure
    $defaultConfig = [PSCustomObject]@{
        installationType = "Full"
        silent = $false
        createDesktopShortcuts = $true
        authenticateNow = $true
        authenticationMethod = "SeparateWindow"
        components = [PSCustomObject]@{
            nodejs = [PSCustomObject]@{
                wingetId = "OpenJS.NodeJS.LTS"
                chocoId = "nodejs-lts"
                displayName = "Node.js"
                required = $true
                testCommand = "node"
                testArgs = "--version"
                testPattern = "^v"
                pathsToAdd = @("C:\Program Files\nodejs", "$env:APPDATA\npm")
            }
            git = [PSCustomObject]@{
                wingetId = "Git.Git"
                chocoId = "git"
                displayName = "Git"
                required = $true
                testCommand = "git"
                testArgs = "--version"
                testPattern = "git version"
                pathsToAdd = @("C:\Program Files\Git\cmd")
            }
            vscode = [PSCustomObject]@{
                wingetId = "Microsoft.VisualStudioCode"
                chocoId = "vscode"
                displayName = "Visual Studio Code"
                required = $true
                testCommand = "code"
                testArgs = "--version"
                testPattern = "."
                pathsToAdd = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin")
            }
            'claude-cli' = [PSCustomObject]@{
                source = "npm"
                package = "@anthropic-ai/claude-code"
                global = $true
                displayName = "Claude Code CLI"
                required = $true
                testCommand = "claude"
                testArgs = "--version"
                testPattern = "."
                pathsToAdd = @("$env:APPDATA\npm")
            }
            'github-desktop' = [PSCustomObject]@{
                wingetId = "GitHub.GitHubDesktop"
                chocoId = "github-desktop"
                displayName = "GitHub Desktop"
                required = $false
                includeInFullInstall = $true
                pathsToAdd = @("$env:LOCALAPPDATA\GitHubDesktop")
            }
            'pieces-desktop' = [PSCustomObject]@{
                source = "msstore"
                storeId = "9P5JNQ0XR5W6"
                displayName = "Pieces Desktop"
                required = $false
                includeInFullInstall = $true
            }
        }
        paths = [PSCustomObject]@{
            claudeProjects = "$env:USERPROFILE\ClaudeProjects"
            logDirectory = "$env:LOCALAPPDATA\ClaudeCodeInstaller"
        }
        timeouts = [PSCustomObject]@{
            authenticationMinutes = 15
            installationMinutes = 30
        }
    }

    # If -UseDefaults specified, return default config
    if ($UseDefaults) {
        Write-Verbose "Using default configuration (file ignored)"
        return $defaultConfig
    }

    # Try to load from file
    if (Test-Path $ConfigPath) {
        try {
            Write-Verbose "Loading configuration from: $ConfigPath"
            $jsonContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
            $loadedConfig = $jsonContent | ConvertFrom-Json -ErrorAction Stop

            Write-Verbose "Configuration loaded successfully"
            return $loadedConfig

        } catch {
            Write-Warning "Failed to parse configuration file: $($_.Exception.Message)"
            Write-Warning "Using default configuration"
            return $defaultConfig
        }
    } else {
        Write-Verbose "Configuration file not found at: $ConfigPath"
        Write-Verbose "Using default configuration"
        return $defaultConfig
    }
}

#endregion

#region Save-InstallConfiguration

function Save-InstallConfiguration {
    <#
    .SYNOPSIS
        Saves configuration to JSON file
    .PARAMETER Configuration
        Configuration object to save
    .PARAMETER ConfigPath
        Destination file path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Configuration,

        [string]$ConfigPath = "$PSScriptRoot\..\InstallConfig.json"
    )

    try {
        # Create parent directory if needed
        $parentDir = Split-Path -Path $ConfigPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            Write-Verbose "Created directory: $parentDir"
        }

        # Convert to JSON with proper formatting
        $jsonContent = $Configuration | ConvertTo-Json -Depth 10

        # Save to file
        $jsonContent | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force

        Write-Verbose "Configuration saved to: $ConfigPath"
        return $true

    } catch {
        Write-Error "Failed to save configuration: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Merge-ConfigurationWithParameters

function Merge-ConfigurationWithParameters {
    <#
    .SYNOPSIS
        Merges CLI parameters with config file (parameters win)
    .PARAMETER Configuration
        Base configuration object
    .PARAMETER Parameters
        Hashtable of CLI parameters
    .OUTPUTS
        Merged configuration object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Configuration,

        [hashtable]$Parameters
    )

    # Create a copy of the configuration
    $mergedConfig = $Configuration | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    # Apply parameter overrides
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]

        switch ($key) {
            'installationType' {
                # Normalize to proper case (Full/Core)
                $normalizedValue = $value.Substring(0,1).ToUpper() + $value.Substring(1).ToLower()
                $mergedConfig.installationType = $normalizedValue
                Write-Verbose "Override: installationType = $normalizedValue"
            }
            'silent' {
                $mergedConfig.silent = [bool]$value
                Write-Verbose "Override: silent = $value"
            }
            'createDesktopShortcuts' {
                $mergedConfig.createDesktopShortcuts = [bool]$value
                Write-Verbose "Override: createDesktopShortcuts = $value"
            }
            'authenticateNow' {
                $mergedConfig.authenticateNow = [bool]$value
                Write-Verbose "Override: authenticateNow = $value"
            }
            'authenticationMethod' {
                $mergedConfig.authenticationMethod = $value
                Write-Verbose "Override: authenticationMethod = $value"
            }
            default {
                Write-Verbose "Unknown parameter: $key (ignored)"
            }
        }
    }

    return $mergedConfig
}

#endregion

#region Test-ConfigurationValid

function Test-ConfigurationValid {
    <#
    .SYNOPSIS
        Validates configuration object has all required fields
    .PARAMETER Configuration
        Configuration to validate
    .OUTPUTS
        ValidationResult object with IsValid, Errors properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Configuration
    )

    $errors = @()

    # Validate installationType
    if (-not $Configuration.PSObject.Properties['installationType']) {
        $errors += "Missing required property: installationType"
    } elseif ($Configuration.installationType -notin @('Full', 'Core', 'full', 'core')) {
        $errors += "Invalid installationType: '$($Configuration.installationType)'. Must be 'Full' or 'Core'"
    }

    # Validate boolean properties
    $boolProps = @('silent', 'createDesktopShortcuts', 'authenticateNow')
    foreach ($prop in $boolProps) {
        if ($Configuration.PSObject.Properties[$prop]) {
            $val = $Configuration.$prop
            if ($val -isnot [bool]) {
                $errors += "Property '$prop' must be boolean (true/false), got: $($val.GetType().Name)"
            }
        }
    }

    # Validate components exist
    if (-not $Configuration.PSObject.Properties['components']) {
        $errors += "Missing required property: components"
    } else {
        # Check required components
        $requiredComponents = @('nodejs', 'git', 'vscode', 'claude-cli')
        foreach ($compName in $requiredComponents) {
            if (-not $Configuration.components.PSObject.Properties[$compName]) {
                $errors += "Missing required component: $compName"
            } else {
                $comp = $Configuration.components.$compName

                # Validate component properties
                if (-not $comp.PSObject.Properties['displayName']) {
                    $errors += "Component '$compName' missing displayName"
                }
                if (-not $comp.PSObject.Properties['required']) {
                    $errors += "Component '$compName' missing required flag"
                }

                # Validate test command for non-msstore components
                if ($comp.PSObject.Properties['testCommand'] -and -not $comp.PSObject.Properties['testArgs']) {
                    $errors += "Component '$compName' has testCommand but missing testArgs"
                }
            }
        }
    }

    # Validate paths
    if (-not $Configuration.PSObject.Properties['paths']) {
        $errors += "Missing required property: paths"
    } else {
        if (-not $Configuration.paths.PSObject.Properties['claudeProjects']) {
            $errors += "Missing required path: claudeProjects"
        }
        if (-not $Configuration.paths.PSObject.Properties['logDirectory']) {
            $errors += "Missing required path: logDirectory"
        }
    }

    # Validate timeouts
    if ($Configuration.PSObject.Properties['timeouts']) {
        if ($Configuration.timeouts.PSObject.Properties['authenticationMinutes']) {
            $authTimeout = $Configuration.timeouts.authenticationMinutes
            if ($authTimeout -isnot [int] -or $authTimeout -le 0) {
                $errors += "authenticationMinutes must be a positive integer, got: $authTimeout"
            }
        }
        if ($Configuration.timeouts.PSObject.Properties['installationMinutes']) {
            $instTimeout = $Configuration.timeouts.installationMinutes
            if ($instTimeout -isnot [int] -or $instTimeout -le 0) {
                $errors += "installationMinutes must be a positive integer, got: $instTimeout"
            }
        }
    }

    # Return validation result
    return [PSCustomObject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Get-InstallConfiguration',
    'Save-InstallConfiguration',
    'Merge-ConfigurationWithParameters',
    'Test-ConfigurationValid'
)
