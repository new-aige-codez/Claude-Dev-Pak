<#
.SYNOPSIS
    Windows Forms GUI for Claude Code Installer configuration
.DESCRIPTION
    Visual configuration tool with checkboxes for selecting installation options.
    Saves configuration to InstallConfig.json and optionally launches the installer.
.EXAMPLE
    .\Show-InstallerConfiguration.ps1
    Opens the GUI configuration tool
.NOTES
    Version: 1.0.0
    Requires: Windows PowerShell 5.1+ with .NET Framework
#>

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Enable visual styles
[System.Windows.Forms.Application]::EnableVisualStyles()

# DPI Awareness for high-DPI displays
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
[DpiHelper]::SetProcessDPIAware()

#region Helper Functions

function Get-ConfigFromForm {
    <#
    .SYNOPSIS
        Gathers all form selections into a configuration object
    #>

    $installType = if ($script:radioFull.Checked) { "Full" }
                   elseif ($script:radioCore.Checked) { "Core" }
                   elseif ($script:radioCustom.Checked) { "Custom" }
                   else { "Full" }

    $config = [PSCustomObject]@{
        installationType = $installType
        silent = $script:checkSilent.Checked
        createDesktopShortcuts = $script:checkShortcuts.Checked
        authenticateNow = $script:checkAuthenticate.Checked
        authenticationMethod = "SeparateWindow"
        components = [PSCustomObject]@{
            nodejs = [PSCustomObject]@{
                wingetId = "OpenJS.NodeJS.LTS"
                chocoId = "nodejs-lts"
                displayName = "Node.js"
                required = $true
                enabled = $true
                testCommand = "node"
                testArgs = "--version"
                testPattern = "^v"
                pathsToAdd = @("C:\Program Files\nodejs", "%APPDATA%\npm")
            }
            git = [PSCustomObject]@{
                wingetId = "Git.Git"
                chocoId = "git"
                displayName = "Git"
                required = $true
                enabled = $true
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
                enabled = $true
                testCommand = "code"
                testArgs = "--version"
                testPattern = "."
                pathsToAdd = @("%LOCALAPPDATA%\Programs\Microsoft VS Code\bin")
            }
            'claude-cli' = [PSCustomObject]@{
                source = "npm"
                package = "@anthropic-ai/claude-code"
                global = $true
                displayName = "Claude Code CLI"
                required = $true
                enabled = $true
                testCommand = "claude"
                testArgs = "--version"
                testPattern = "."
                pathsToAdd = @("%APPDATA%\npm")
            }
            'github-desktop' = [PSCustomObject]@{
                wingetId = "GitHub.GitHubDesktop"
                chocoId = "github-desktop"
                displayName = "GitHub Desktop"
                required = $false
                enabled = $script:checkGitHubDesktop.Checked
                includeInFullInstall = $true
                pathsToAdd = @("%LOCALAPPDATA%\GitHubDesktop")
            }
            'pieces-desktop' = [PSCustomObject]@{
                source = "msstore"
                storeId = "9P5JNQ0XR5W6"
                displayName = "Pieces Desktop"
                required = $false
                enabled = $script:checkPiecesDesktop.Checked
                includeInFullInstall = $true
            }
        }
        paths = [PSCustomObject]@{
            claudeProjects = "%USERPROFILE%\ClaudeProjects"
            logDirectory = "%LOCALAPPDATA%\ClaudeCodeInstaller"
        }
        timeouts = [PSCustomObject]@{
            authenticationMinutes = 15
            installationMinutes = 30
        }
    }

    return $config
}

function Save-ConfigToFile {
    param([PSCustomObject]$Configuration)

    $configPath = Join-Path $PSScriptRoot "InstallConfig.json"

    try {
        $jsonContent = $Configuration | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

        [System.Windows.Forms.MessageBox]::Show(
            "Configuration saved successfully to:`n$configPath",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null

        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to save configuration:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        return $false
    }
}

function Update-OptionalComponentState {
    <#
    .SYNOPSIS
        Updates the enabled/disabled state of optional components based on radio selection
    #>

    if ($script:radioFull.Checked) {
        # Full: Check and disable optional components
        $script:checkGitHubDesktop.Checked = $true
        $script:checkGitHubDesktop.Enabled = $false
        $script:checkPiecesDesktop.Checked = $true
        $script:checkPiecesDesktop.Enabled = $false

    } elseif ($script:radioCore.Checked) {
        # Core: Uncheck and disable optional components
        $script:checkGitHubDesktop.Checked = $false
        $script:checkGitHubDesktop.Enabled = $false
        $script:checkPiecesDesktop.Checked = $false
        $script:checkPiecesDesktop.Enabled = $false

    } elseif ($script:radioCustom.Checked) {
        # Custom: Enable optional components for user selection
        $script:checkGitHubDesktop.Enabled = $true
        $script:checkPiecesDesktop.Enabled = $true
    }
}

#endregion

#region Create Form

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Installer - Configuration"
$form.Size = New-Object System.Drawing.Size(600, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::White

#endregion

#region Header Panel

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(584, 80)
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#E3F2FD")
$form.Controls.Add($headerPanel)

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Claude Code Development Environment Setup"
$titleLabel.Location = New-Object System.Drawing.Point(0, 20)
$titleLabel.Size = New-Object System.Drawing.Size(584, 25)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.TextAlign = "MiddleCenter"
$headerPanel.Controls.Add($titleLabel)

# Subtitle Label
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Select your installation preferences below"
$subtitleLabel.Location = New-Object System.Drawing.Point(0, 50)
$subtitleLabel.Size = New-Object System.Drawing.Size(584, 20)
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitleLabel.TextAlign = "MiddleCenter"
$subtitleLabel.ForeColor = [System.Drawing.Color]::Gray
$headerPanel.Controls.Add($subtitleLabel)

#endregion

#region Installation Type Section

$yPos = 90

# Section Label
$installTypeLabel = New-Object System.Windows.Forms.Label
$installTypeLabel.Text = "Installation Type:"
$installTypeLabel.Location = New-Object System.Drawing.Point(20, $yPos)
$installTypeLabel.Size = New-Object System.Drawing.Size(560, 18)
$installTypeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($installTypeLabel)

$yPos += 22

# Radio: Full Installation
$script:radioFull = New-Object System.Windows.Forms.RadioButton
$script:radioFull.Text = "Full Installation (Recommended)"
$script:radioFull.Location = New-Object System.Drawing.Point(30, $yPos)
$script:radioFull.Size = New-Object System.Drawing.Size(540, 18)
$script:radioFull.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$script:radioFull.Checked = $true
$form.Controls.Add($script:radioFull)

$yPos += 20

$fullDesc = New-Object System.Windows.Forms.Label
$fullDesc.Text = "Includes: All components + GitHub Desktop + Pieces Desktop" + [Environment]::NewLine + "Size: ~2.3 GB initially, grows to 6+ GB"
$fullDesc.Location = New-Object System.Drawing.Point(50, $yPos)
$fullDesc.Size = New-Object System.Drawing.Size(520, 28)
$fullDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$fullDesc.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($fullDesc)

$yPos += 32

# Radio: Core Installation
$script:radioCore = New-Object System.Windows.Forms.RadioButton
$script:radioCore.Text = "Core Installation"
$script:radioCore.Location = New-Object System.Drawing.Point(30, $yPos)
$script:radioCore.Size = New-Object System.Drawing.Size(540, 18)
$script:radioCore.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($script:radioCore)

$yPos += 20

$coreDesc = New-Object System.Windows.Forms.Label
$coreDesc.Text = "Includes: Node.js, Git, VS Code, Claude CLI only" + [Environment]::NewLine + "Size: ~1.1 GB"
$coreDesc.Location = New-Object System.Drawing.Point(50, $yPos)
$coreDesc.Size = New-Object System.Drawing.Size(520, 28)
$coreDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$coreDesc.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($coreDesc)

$yPos += 32

# Radio: Custom Installation
$script:radioCustom = New-Object System.Windows.Forms.RadioButton
$script:radioCustom.Text = "Custom Installation"
$script:radioCustom.Location = New-Object System.Drawing.Point(30, $yPos)
$script:radioCustom.Size = New-Object System.Drawing.Size(540, 18)
$script:radioCustom.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($script:radioCustom)

$yPos += 20

$customDesc = New-Object System.Windows.Forms.Label
$customDesc.Text = "Select individual components below"
$customDesc.Location = New-Object System.Drawing.Point(50, $yPos)
$customDesc.Size = New-Object System.Drawing.Size(520, 16)
$customDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$customDesc.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($customDesc)

$yPos += 24

#endregion

#region Components Section

# Section Label
$componentsLabel = New-Object System.Windows.Forms.Label
$componentsLabel.Text = "Components to Install:"
$componentsLabel.Location = New-Object System.Drawing.Point(20, $yPos)
$componentsLabel.Size = New-Object System.Drawing.Size(560, 18)
$componentsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($componentsLabel)

$yPos += 22

# Core Components GroupBox
$coreGroupBox = New-Object System.Windows.Forms.GroupBox
$coreGroupBox.Text = "Core Components (Required)"
$coreGroupBox.Location = New-Object System.Drawing.Point(20, $yPos)
$coreGroupBox.Size = New-Object System.Drawing.Size(544, 88)
$coreGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($coreGroupBox)

# Core checkboxes
$checkNodeJS = New-Object System.Windows.Forms.CheckBox
$checkNodeJS.Text = "Node.js (v20 LTS) - JavaScript runtime"
$checkNodeJS.Location = New-Object System.Drawing.Point(10, 18)
$checkNodeJS.Size = New-Object System.Drawing.Size(520, 16)
$checkNodeJS.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$checkNodeJS.Checked = $true
$checkNodeJS.Enabled = $false
$coreGroupBox.Controls.Add($checkNodeJS)

$checkGit = New-Object System.Windows.Forms.CheckBox
$checkGit.Text = "Git for Windows - Version control system"
$checkGit.Location = New-Object System.Drawing.Point(10, 36)
$checkGit.Size = New-Object System.Drawing.Size(520, 16)
$checkGit.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$checkGit.Checked = $true
$checkGit.Enabled = $false
$coreGroupBox.Controls.Add($checkGit)

$checkVSCode = New-Object System.Windows.Forms.CheckBox
$checkVSCode.Text = "Visual Studio Code - Code editor"
$checkVSCode.Location = New-Object System.Drawing.Point(10, 54)
$checkVSCode.Size = New-Object System.Drawing.Size(520, 16)
$checkVSCode.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$checkVSCode.Checked = $true
$checkVSCode.Enabled = $false
$coreGroupBox.Controls.Add($checkVSCode)

$checkClaude = New-Object System.Windows.Forms.CheckBox
$checkClaude.Text = "Claude Code CLI - AI coding assistant"
$checkClaude.Location = New-Object System.Drawing.Point(10, 72)
$checkClaude.Size = New-Object System.Drawing.Size(520, 16)
$checkClaude.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$checkClaude.Checked = $true
$checkClaude.Enabled = $false
$coreGroupBox.Controls.Add($checkClaude)

$yPos += 92

# Optional Components GroupBox
$optionalGroupBox = New-Object System.Windows.Forms.GroupBox
$optionalGroupBox.Text = "Optional Components"
$optionalGroupBox.Location = New-Object System.Drawing.Point(20, $yPos)
$optionalGroupBox.Size = New-Object System.Drawing.Size(544, 52)
$optionalGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($optionalGroupBox)

# Optional checkboxes
$script:checkGitHubDesktop = New-Object System.Windows.Forms.CheckBox
$script:checkGitHubDesktop.Text = "GitHub Desktop - Git GUI client (~200 MB)"
$script:checkGitHubDesktop.Location = New-Object System.Drawing.Point(10, 18)
$script:checkGitHubDesktop.Size = New-Object System.Drawing.Size(520, 16)
$script:checkGitHubDesktop.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$optionalGroupBox.Controls.Add($script:checkGitHubDesktop)

$script:checkPiecesDesktop = New-Object System.Windows.Forms.CheckBox
$script:checkPiecesDesktop.Text = "Pieces Desktop - AI snippet manager (~1+ GB)"
$script:checkPiecesDesktop.Location = New-Object System.Drawing.Point(10, 36)
$script:checkPiecesDesktop.Size = New-Object System.Drawing.Size(520, 16)
$script:checkPiecesDesktop.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$optionalGroupBox.Controls.Add($script:checkPiecesDesktop)

$yPos += 58

#endregion

#region Additional Options Section

$optionsLabel = New-Object System.Windows.Forms.Label
$optionsLabel.Text = "Additional Options:"
$optionsLabel.Location = New-Object System.Drawing.Point(20, $yPos)
$optionsLabel.Size = New-Object System.Drawing.Size(560, 18)
$optionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($optionsLabel)

$yPos += 22

$script:checkShortcuts = New-Object System.Windows.Forms.CheckBox
$script:checkShortcuts.Text = "Create desktop shortcuts for installed applications"
$script:checkShortcuts.Location = New-Object System.Drawing.Point(30, $yPos)
$script:checkShortcuts.Size = New-Object System.Drawing.Size(540, 16)
$script:checkShortcuts.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$script:checkShortcuts.Checked = $true
$form.Controls.Add($script:checkShortcuts)

$yPos += 18

$script:checkAuthenticate = New-Object System.Windows.Forms.CheckBox
$script:checkAuthenticate.Text = "Authenticate Claude CLI after installation"
$script:checkAuthenticate.Location = New-Object System.Drawing.Point(30, $yPos)
$script:checkAuthenticate.Size = New-Object System.Drawing.Size(540, 16)
$script:checkAuthenticate.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$script:checkAuthenticate.Checked = $true
$form.Controls.Add($script:checkAuthenticate)

$yPos += 18

$script:checkSilent = New-Object System.Windows.Forms.CheckBox
$script:checkSilent.Text = "Run installation silently (minimal output)"
$script:checkSilent.Location = New-Object System.Drawing.Point(30, $yPos)
$script:checkSilent.Size = New-Object System.Drawing.Size(540, 16)
$script:checkSilent.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($script:checkSilent)

#endregion

#region Buttons

$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point(0, 530)
$buttonPanel.Size = New-Object System.Drawing.Size(584, 50)
$buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$form.Controls.Add($buttonPanel)

# Save Configuration Button
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Configuration"
$btnSave.Location = New-Object System.Drawing.Point(120, 12)
$btnSave.Size = New-Object System.Drawing.Size(130, 26)
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonPanel.Controls.Add($btnSave)

# Install Now Button
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Now"
$btnInstall.Location = New-Object System.Drawing.Point(260, 12)
$btnInstall.Size = New-Object System.Drawing.Size(110, 26)
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#28a745")
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = "Flat"
$buttonPanel.Controls.Add($btnInstall)

# Cancel Button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(380, 12)
$btnCancel.Size = New-Object System.Drawing.Size(80, 26)
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonPanel.Controls.Add($btnCancel)

#endregion

#region Event Handlers

# Radio button events
$script:radioFull.Add_CheckedChanged({ Update-OptionalComponentState })
$script:radioCore.Add_CheckedChanged({ Update-OptionalComponentState })
$script:radioCustom.Add_CheckedChanged({ Update-OptionalComponentState })

# Save Configuration button
$btnSave.Add_Click({
    $config = Get-ConfigFromForm
    Save-ConfigToFile -Configuration $config
})

# Install Now button
$btnInstall.Add_Click({
    $config = Get-ConfigFromForm

    $installType = $config.installationType
    $componentCount = ($config.components.PSObject.Properties.Value | Where-Object { $_.enabled }).Count

    $message = "Ready to install Claude Code with the following settings:`n`n" +
               "Installation Type: $installType`n" +
               "Components: $componentCount selected`n" +
               "Desktop Shortcuts: $(if ($config.createDesktopShortcuts) {'Yes'} else {'No'})`n" +
               "Authentication: $(if ($config.authenticateNow) {'Yes'} else {'No'})`n`n" +
               "This may take 10-30 minutes depending on your internet connection.`n`n" +
               "Proceed with installation?"

    $result = [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Confirm Installation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        # Save configuration first
        if (Save-ConfigToFile -Configuration $config) {
            # Close GUI
            $form.Close()

            # Launch installer
            $installerPath = Join-Path $PSScriptRoot "ClaudeCodeInstaller - 10.19.25-13.55.ps1"

            if (Test-Path $installerPath) {
                $args = @("-ExecutionPolicy", "Bypass", "-File", "`"$installerPath`"")

                if ($config.silent) {
                    $args += "-Silent"
                }

                Start-Process powershell.exe -ArgumentList $args -Wait
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "Installer not found at:`n$installerPath",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }
    }
})

# Cancel button
$btnCancel.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Close configuration tool without saving?",
        "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $form.Close()
    }
})

#endregion

# Initialize state
Update-OptionalComponentState

# Show form
[void]$form.ShowDialog()
