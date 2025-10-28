<#
.SYNOPSIS
    Introductory dialog for Development Tools Installer

.DESCRIPTION
    Displays installation requirements, security information, and disclaimer
    before proceeding with the main installation

.OUTPUTS
    Boolean - $true if user clicks Continue, $false if user clicks Cancel

.NOTES
    Version: 1.0.0
    Created: 2025-10-19
    Requires: Windows PowerShell 5.1+ with .NET Framework
#>

# Ensure we're running in a Windows environment
if ($PSVersionTable.Platform -eq 'Unix') {
    Write-Error "This script requires Windows PowerShell."
    return $false
}

# Load Windows Forms assemblies
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Warning "Failed to load Windows Forms. Falling back to console confirmation."
    $response = Read-Host "Do you want to proceed with installation? (Y/N)"
    return ($response -eq 'Y' -or $response -eq 'y')
}

# Enable visual styles for modern appearance
[System.Windows.Forms.Application]::EnableVisualStyles()

# DPI Awareness for high-DPI displays
try {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
    [DpiHelper]::SetProcessDPIAware()
} catch {
    # DPI helper already defined or not needed
}

#region Create Main Form

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Development Tools Installer - Introduction"
$form.Size = New-Object System.Drawing.Size(700, 780)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

#endregion

#region Header Panel

# Create header panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(700, 80)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 58, 138)  # Dark blue
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top

# Header label with border decoration
$headerBorder = New-Object System.Windows.Forms.Label
$headerBorder.Text = "╔═══════════════════════════════════════════════════════════════╗`r`n║              DEVELOPMENT TOOLS INSTALLER                      ║`r`n╚═══════════════════════════════════════════════════════════════╝"
$headerBorder.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$headerBorder.ForeColor = [System.Drawing.Color]::White
$headerBorder.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$headerBorder.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerPanel.Controls.Add($headerBorder)

$form.Controls.Add($headerPanel)

#endregion

#region Main Content Panel (Scrollable)

# Create scrollable content panel
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(20, 90)
$contentPanel.Size = New-Object System.Drawing.Size(640, 550)
$contentPanel.AutoScroll = $true
$contentPanel.BackColor = [System.Drawing.Color]::White
$contentPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None

# Content container (inside scrollable panel)
$contentContainer = New-Object System.Windows.Forms.Panel
$contentContainer.Location = New-Object System.Drawing.Point(0, 0)
$contentContainer.Size = New-Object System.Drawing.Size(620, 1800)  # Will auto-size
$contentContainer.AutoSize = $true
$contentContainer.BackColor = [System.Drawing.Color]::White

# Y position tracker
$yPos = 10

#region Content Labels

# Introduction
$labelIntro = New-Object System.Windows.Forms.Label
$labelIntro.Text = "Setup will install the following development tools on your computer."
$labelIntro.Location = New-Object System.Drawing.Point(10, $yPos)
$labelIntro.Size = New-Object System.Drawing.Size(600, 25)
$labelIntro.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelIntro)
$yPos += 35

# CORE COMPONENTS
$labelCoreHeader = New-Object System.Windows.Forms.Label
$labelCoreHeader.Text = "CORE COMPONENTS:"
$labelCoreHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelCoreHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelCoreHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelCoreHeader)
$yPos += 25

$labelCoreList = New-Object System.Windows.Forms.Label
$labelCoreList.Text = @"
• Node.js - JavaScript runtime environment
• Python - Python interpreter and libraries
• Git - Distributed version control system
• Visual Studio Code - Source code editor
• VS Code Extension - Modified with development protocols
• Claude Code CLI - AI development assistant
"@
$labelCoreList.Location = New-Object System.Drawing.Point(20, $yPos)
$labelCoreList.Size = New-Object System.Drawing.Size(580, 110)
$labelCoreList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelCoreList)
$yPos += 120

# OPTIONAL COMPONENTS
$labelOptionalHeader = New-Object System.Windows.Forms.Label
$labelOptionalHeader.Text = "OPTIONAL COMPONENTS:"
$labelOptionalHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelOptionalHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelOptionalHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelOptionalHeader)
$yPos += 25

$labelOptionalText = New-Object System.Windows.Forms.Label
$labelOptionalText.Text = "Additional tools may be selected on the next screen."
$labelOptionalText.Location = New-Object System.Drawing.Point(20, $yPos)
$labelOptionalText.Size = New-Object System.Drawing.Size(580, 20)
$labelOptionalText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelOptionalText)
$yPos += 35

# INSTALLATION REQUIREMENTS
$labelReqHeader = New-Object System.Windows.Forms.Label
$labelReqHeader.Text = "INSTALLATION REQUIREMENTS:"
$labelReqHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelReqHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelReqHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelReqHeader)
$yPos += 25

$labelReqList = New-Object System.Windows.Forms.Label
$labelReqList.Text = @"
• Active internet connection required for package downloads
• Approximately 2GB of available disk space (core installation)
• Up to 5GB of disk space may be required with optional components
• Windows 10 (version 1903 or later) or Windows 11
"@
$labelReqList.Location = New-Object System.Drawing.Point(20, $yPos)
$labelReqList.Size = New-Object System.Drawing.Size(580, 75)
$labelReqList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelReqList)
$yPos += 85

# ADMINISTRATOR PRIVILEGES
$labelAdminHeader = New-Object System.Windows.Forms.Label
$labelAdminHeader.Text = "ADMINISTRATOR PRIVILEGES:"
$labelAdminHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelAdminHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelAdminHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelAdminHeader)
$yPos += 25

$labelAdminText = New-Object System.Windows.Forms.Label
$labelAdminText.Text = @"
Administrator access is required to install software system-wide and
modify PATH environment variables. By clicking Continue, you authorize
this installer to run with administrator privileges.
"@
$labelAdminText.Location = New-Object System.Drawing.Point(20, $yPos)
$labelAdminText.Size = New-Object System.Drawing.Size(580, 55)
$labelAdminText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelAdminText)
$yPos += 70

# PACKAGE SOURCES
$labelSourceHeader = New-Object System.Windows.Forms.Label
$labelSourceHeader.Text = "PACKAGE SOURCES:"
$labelSourceHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelSourceHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelSourceHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelSourceHeader)
$yPos += 25

$labelSourceText = New-Object System.Windows.Forms.Label
$labelSourceText.Text = @"
All packages are downloaded from official vendor repositories using
Microsoft winget package manager.
"@
$labelSourceText.Location = New-Object System.Drawing.Point(20, $yPos)
$labelSourceText.Size = New-Object System.Drawing.Size(580, 35)
$labelSourceText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelSourceText)
$yPos += 50

# SECURITY
$labelSecurityHeader = New-Object System.Windows.Forms.Label
$labelSecurityHeader.Text = "SECURITY:"
$labelSecurityHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelSecurityHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelSecurityHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelSecurityHeader)
$yPos += 25

$labelSecurityText = New-Object System.Windows.Forms.Label
$labelSecurityText.Text = @"
This installer implements hash verification, audit logging, and secure
package management to mitigate the risk of compromised installations
and protect against potential system vulnerabilities. These measures
follow industry-standard security protocols. The complete source code
is available for review at: dummy.github.site.com
"@
$labelSecurityText.Location = New-Object System.Drawing.Point(20, $yPos)
$labelSecurityText.Size = New-Object System.Drawing.Size(580, 90)
$labelSecurityText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelSecurityText)
$yPos += 105

# NOTICE
$labelNoticeHeader = New-Object System.Windows.Forms.Label
$labelNoticeHeader.Text = "NOTICE:"
$labelNoticeHeader.Location = New-Object System.Drawing.Point(10, $yPos)
$labelNoticeHeader.Size = New-Object System.Drawing.Size(600, 20)
$labelNoticeHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelNoticeHeader)
$yPos += 25

$labelNoticeText = New-Object System.Windows.Forms.Label
$labelNoticeText.Text = @"
This software is provided "as is" without warranty. To prevent potential
installation issues, please ensure your system remains powered on and do
not interrupt the installation process. As with any software installation,
maintaining current backups of important data is recommended.
"@
$labelNoticeText.Location = New-Object System.Drawing.Point(20, $yPos)
$labelNoticeText.Size = New-Object System.Drawing.Size(580, 75)
$labelNoticeText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$contentContainer.Controls.Add($labelNoticeText)
$yPos += 90

# Final instruction
$labelFinalInstruction = New-Object System.Windows.Forms.Label
$labelFinalInstruction.Text = "Click Continue to proceed with installation."
$labelFinalInstruction.Location = New-Object System.Drawing.Point(10, $yPos)
$labelFinalInstruction.Size = New-Object System.Drawing.Size(600, 25)
$labelFinalInstruction.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$contentContainer.Controls.Add($labelFinalInstruction)

#endregion

$contentPanel.Controls.Add($contentContainer)
$form.Controls.Add($contentPanel)

#endregion

#region Button Panel

# Create button panel at bottom
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point(0, 650)
$buttonPanel.Size = New-Object System.Drawing.Size(700, 90)
$buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)  # Light gray
$buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom

# Continue button
$btnContinue = New-Object System.Windows.Forms.Button
$btnContinue.Text = "Continue"
$btnContinue.Location = New-Object System.Drawing.Point(460, 25)
$btnContinue.Size = New-Object System.Drawing.Size(110, 35)
$btnContinue.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)  # Windows blue
$btnContinue.ForeColor = [System.Drawing.Color]::White
$btnContinue.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnContinue.FlatAppearance.BorderSize = 0
$btnContinue.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnContinue.DialogResult = [System.Windows.Forms.DialogResult]::OK
$btnContinue.TabIndex = 0
$btnContinue.Cursor = [System.Windows.Forms.Cursors]::Hand

# Cancel button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(580, 25)
$btnCancel.Size = New-Object System.Drawing.Size(110, 35)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(229, 229, 229)  # Light gray
$btnCancel.ForeColor = [System.Drawing.Color]::Black
$btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCancel.FlatAppearance.BorderSize = 1
$btnCancel.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(173, 173, 173)
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$btnCancel.TabIndex = 1
$btnCancel.Cursor = [System.Windows.Forms.Cursors]::Hand

$buttonPanel.Controls.Add($btnContinue)
$buttonPanel.Controls.Add($btnCancel)
$form.Controls.Add($buttonPanel)

#endregion

#region Form Configuration

# Set form properties
$form.AcceptButton = $btnContinue  # Enter key triggers Continue
$form.CancelButton = $btnCancel    # Escape key triggers Cancel
$form.TopMost = $true              # Keep on top
$form.ShowInTaskbar = $true

# Add hover effects for buttons
$btnContinue.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 180)
})
$btnContinue.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
})

$btnCancel.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
})
$btnCancel.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(229, 229, 229)
})

#endregion

#region Show Form and Return Result

# Initialize result variable
$script:userChoice = $false

# Show the form as modal dialog
$result = $form.ShowDialog()

# Dispose form resources
$form.Dispose()

# Return based on user selection
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    return $true
} else {
    return $false
}

#endregion
