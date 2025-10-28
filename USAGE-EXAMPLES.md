# Claude Code Installer - Usage Examples

## Overview
The Claude Code Installer now supports both **interactive** and **silent/automated** installation modes with full configuration file support.

## Quick Start

### Interactive Installation (Default)
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1
```
Prompts you for all installation options with smart defaults from `InstallConfig.json` if it exists.

### Silent Installation
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
```
No prompts - uses `InstallConfig.json` for all decisions.

---

## Installation Modes

### 1. Interactive Mode (Recommended for First-Time Users)

**Basic Usage:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1
```

**What Happens:**
- Prompts for installation type (Full/Core)
- Prompts for desktop shortcuts (Yes/No)
- Prompts for authentication (Yes/No)
- Uses `InstallConfig.json` as defaults if file exists
- Shows progress for each component

**With Save Configuration:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -SaveConfig
```
Your choices will be saved to `InstallConfig.json` for future runs.

---

### 2. Silent Mode (For Automation/CI-CD)

**Basic Silent Installation:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
```
Uses `InstallConfig.json` for all settings. No user interaction required.

**Silent Core Installation:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent -InstallationType Core
```
Installs only Node.js, Git, VS Code, and Claude CLI.

**Silent with Specific Options:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent -InstallationType Full -CreateShortcuts -SkipAuthentication
```
Full installation with shortcuts, but skip authentication step.

---

### 3. Hybrid Mode (Parameters Override Config)

**Override Installation Type:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -InstallationType Core
```
Interactive mode, but Core installation is pre-selected.

**Override Multiple Settings:**
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -InstallationType Full -CreateShortcuts
```
Interactive prompts with Full installation and shortcuts pre-selected.

---

## Configuration File

### Location
`InstallConfig.json` in the same directory as the installer script.

### Structure
```json
{
  "installationType": "Full",
  "silent": false,
  "createDesktopShortcuts": true,
  "authenticateNow": true,
  "authenticationMethod": "SeparateWindow",
  "components": {
    "nodejs": { ... },
    "git": { ... },
    "vscode": { ... },
    "claude-cli": { ... },
    "github-desktop": { ... },
    "pieces-desktop": { ... }
  },
  "paths": {
    "claudeProjects": "%USERPROFILE%\\ClaudeProjects",
    "logDirectory": "%LOCALAPPDATA%\\ClaudeCodeInstaller"
  },
  "timeouts": {
    "authenticationMinutes": 15,
    "installationMinutes": 30
  }
}
```

### Customization Examples

#### Core Installation by Default
Edit `InstallConfig.json`:
```json
{
  "installationType": "Core",
  "silent": false,
  ...
}
```

#### Silent Mode by Default
```json
{
  "installationType": "Full",
  "silent": true,
  "createDesktopShortcuts": true,
  "authenticateNow": false,
  ...
}
```

#### Custom Timeouts
```json
{
  ...
  "timeouts": {
    "authenticationMinutes": 30,
    "installationMinutes": 60
  }
}
```

---

## Parameter Reference

### Installation Type
```powershell
-InstallationType <Full|Core>
```
- **Full**: All components (Node.js, Git, VS Code, Claude CLI, GitHub Desktop, Pieces)
- **Core**: Required only (Node.js, Git, VS Code, Claude CLI)

### Silent Mode
```powershell
-Silent
```
Run without prompts using configuration file.

### Desktop Shortcuts
```powershell
-CreateShortcuts
```
Create desktop shortcuts for installed applications.

### Authentication
```powershell
-SkipAuthentication
```
Skip Claude authentication step (can authenticate later with `claude` command).

### Force Reinstall
```powershell
-Force
```
Reinstall even if components are already installed.

### Save Configuration
```powershell
-SaveConfig
```
Save your choices to `InstallConfig.json` after prompting.

### Use Defaults
```powershell
-UseDefaults
```
Ignore config file and use hardcoded defaults.

### Config File Path
```powershell
-ConfigFile "C:\path\to\custom-config.json"
```
Use a custom configuration file location.

---

## Common Scenarios

### Scenario 1: First-Time Installation
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -SaveConfig
```
Interactive mode with all prompts. Your choices are saved for next time.

### Scenario 2: Mass Deployment (Corporate)
1. Customize `InstallConfig.json` with your organization's settings
2. Deploy both installer script and config file to target machines
3. Run:
   ```powershell
   .\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
   ```

### Scenario 3: CI/CD Pipeline
```powershell
# Install core components only, skip authentication
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent -InstallationType Core -SkipAuthentication
```

### Scenario 4: Repair/Reinstall
```powershell
# Force reinstall all components
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Force
```

### Scenario 5: Custom Configuration Location
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -ConfigFile "\\shared\configs\claude-config.json" -Silent
```

### Scenario 6: Developer Laptop Setup
```powershell
# Full installation with shortcuts and authentication
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent -InstallationType Full -CreateShortcuts
```

---

## Exit Codes

The installer returns different exit codes for automation purposes:

- **0**: Success - All components installed successfully
- **1**: Critical Failure - Required component failed to install
- **2**: Partial Success - Optional component failed, but core components succeeded

### Example Usage in Batch Script
```batch
@echo off
PowerShell.exe -ExecutionPolicy Bypass -File "ClaudeCodeInstaller - 10.19.25-13.55.ps1" -Silent
IF %ERRORLEVEL% EQU 0 (
    echo Installation succeeded!
) ELSE IF %ERRORLEVEL% EQU 1 (
    echo Critical installation failure!
    exit /b 1
) ELSE IF %ERRORLEVEL% EQU 2 (
    echo Installation completed with warnings
)
```

### Example Usage in PowerShell Script
```powershell
& ".\ClaudeCodeInstaller - 10.19.25-13.55.ps1" -Silent -InstallationType Core

switch ($LASTEXITCODE) {
    0 { Write-Host "Installation successful" -ForegroundColor Green }
    1 {
        Write-Host "Critical failure" -ForegroundColor Red
        throw "Installation failed"
    }
    2 { Write-Host "Partial success - check logs" -ForegroundColor Yellow }
}
```

---

## Troubleshooting

### Configuration Not Loading
```powershell
# Test if config is valid
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -UseDefaults
```

### View Configuration Loading
```powershell
# Run with verbose output
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Verbose
```

### Reset to Defaults
Delete or rename `InstallConfig.json`:
```powershell
Rename-Item InstallConfig.json InstallConfig.json.backup
```

---

## Best Practices

### 1. Use SaveConfig for Initial Setup
```powershell
# First time: Interactive with save
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -SaveConfig

# Subsequent runs: Silent mode
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
```

### 2. Version Control Your Config
Add `InstallConfig.json` to your repository for team consistency.

### 3. Separate Configs for Different Environments
```powershell
# Development
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -ConfigFile dev-config.json -Silent

# Production
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -ConfigFile prod-config.json -Silent
```

### 4. Test Before Silent Deployment
```powershell
# Test interactively first
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1

# Then deploy silently
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
```

---

## Advanced: Component Configuration

### Add Custom Component
Edit `InstallConfig.json` to add a new component:
```json
{
  "components": {
    ...
    "my-custom-tool": {
      "wingetId": "Company.CustomTool",
      "chocoId": "custom-tool",
      "displayName": "My Custom Tool",
      "required": false,
      "testCommand": "mytool",
      "testArgs": "--version",
      "testPattern": "^\\d",
      "pathsToAdd": ["C:\\Program Files\\MyTool"]
    }
  }
}
```

### Disable Optional Components
```json
{
  "components": {
    ...
    "github-desktop": {
      ...
      "includeInFullInstall": false
    }
  }
}
```

---

## Migration from Previous Versions

### From Version 4.1.0 (Non-Config)
1. Run new installer interactively: `.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -SaveConfig`
2. Your choices are now saved to `InstallConfig.json`
3. Next run: Use silent mode for automation

### Backward Compatibility
The installer works exactly like v4.1.0 if you don't use any new parameters:
```powershell
# Works exactly like old version
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1
```

---

## Getting Help

### Show Full Help
```powershell
Get-Help .\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Full
```

### Show Examples
```powershell
Get-Help .\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Examples
```

### Show Parameters
```powershell
Get-Help .\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Parameter *
```

---

## Summary

### Interactive Mode
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1
```
Best for: First-time users, custom setups

### Silent Mode
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -Silent
```
Best for: Automation, mass deployment, CI/CD

### Hybrid Mode
```powershell
.\ClaudeCodeInstaller - 10.19.25-13.55.ps1 -InstallationType Core
```
Best for: Semi-automated setups, parameter overrides

Choose the mode that fits your workflow!
