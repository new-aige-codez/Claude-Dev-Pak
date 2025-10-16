# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Windows installer script for Claude Code development environment. The repository contains PowerShell installer scripts that automate the installation and configuration of:

**Core Installation:**
- Node.js (via winget or Chocolatey)
- Git (via winget or Chocolatey)
- Visual Studio Code (via winget or Chocolatey)
- Claude Code CLI (via npm)
- Claude authentication setup
- VS Code Chat GUI Extension

**Full Installation (includes Core, plus):**
- GitHub Desktop (via winget or Chocolatey)
- Pieces Desktop (via Microsoft Store)

## Script Architecture

### Core Design Pattern

The installer follows a **multi-phase execution model**:

1. **Detection Phase** - Checks for existing installations using `Test-Command`
2. **Package Manager Detection** - Prioritizes winget, falls back to Chocolatey
3. **Installation Phase** - Installs only missing components
4. **Authentication Phase** - Handles Claude OAuth in parallel with other installations
5. **Logging Phase** - Creates detailed installation logs

### Key Functions

#### Utility Functions (`#region Utility Functions`)

- **`Ensure-Administrator`** - Elevates privileges if needed
- **`Show-Progress`** - Animated progress indicator for background jobs with spinner
- **`Show-ProgressPulse`** - Pulse animation for noisy operations (npm installs)
- **`Test-Command`** - Validates installed applications by checking version output
- **`Test-GitHubDesktop`** - Checks if GitHub Desktop is installed using multiple detection methods (installation directory, Start Menu shortcut, registry)

#### Authentication Functions (`#region Authentication Validation Functions`)

- **`Test-ClaudeAuthentication`** (Lines 265-438) - Validates OAuth credentials by checking multiple possible credential file locations:
  - `%USERPROFILE%\.claude\.credentials.json` (primary)
  - `%USERPROFILE%\.config\claude-code\auth.json` (alternative)
  - `%USERPROFILE%\.config\claude\auth.json` (legacy)
  - `%APPDATA%\claude\credentials.json` (fallback)
  - Checks for `claudeAiOauth` object with `accessToken` and `refreshToken`
  - Handles token expiration (timestamps in MILLISECONDS)

- **`Start-ClaudeAuthenticationNewWindow`** (Lines 440-631) - Opens authentication in separate terminal window with automatic monitoring (15-minute timeout, 2-second poll interval)

- **`Confirm-ClaudeAuthenticationManually`** (Lines 633-657) - Fallback manual verification prompt

#### Main Installation Flow (`#region Main Installation Flow`)

- **`Start-Installation`** (Lines 663-1686) - Orchestrates entire installation process with non-blocking authentication (runs authentication in background job while other installations proceed)

### Progress Indication System

Two distinct progress modes handle different output characteristics:

1. **`Show-Progress`** (Lines 42-168) - For commands with predictable stderr/stdout
   - Uses background PowerShell jobs
   - Exit code-based success determination
   - Spinner animation during execution

2. **`Show-ProgressPulse`** (Lines 170-231) - For commands with noisy stderr (npm)
   - Pulse bar animation
   - Direct execution mode available via `-UseDirect` switch

### Authentication Flow Architecture

The authentication system uses a **non-blocking background monitor pattern**:

1. Opens authentication window with `Start-Process` (non-blocking)
2. Launches background PowerShell job to poll credential files every 2 seconds
3. Main installer continues with VS Code and extension installations
4. User can press 'A' during installation to open additional auth windows
5. Final check waits up to 5 seconds for auth job completion

## Development Commands

### Running the Installer

```powershell
# Run with administrator privileges
PowerShell.exe -ExecutionPolicy Bypass -File "ClaudeCodeInstaller - 10.13.25-05.26.ps1"
```

### Testing Components

```powershell
# Test individual functions (dot-source the script first)
. ".\ClaudeCodeInstaller - 10.13.25-05.26.ps1"

# Test authentication check
Test-ClaudeAuthentication -Verbose

# Test command detection
Test-Command -Command "node" -Argument "--version" -ExpectedOutputPattern "^v" -DisplayName "Node.js"
```

## Important Technical Details

### Credential File Format

The installer expects Claude credentials in this JSON structure:

```json
{
  "claudeAiOauth": {
    "accessToken": "string",
    "refreshToken": "string",
    "expiresAt": 1234567890000,  // MILLISECONDS (not seconds)
    "subscriptionType": "string"
  }
}
```

### PATH Management

After each installation, the script updates `$env:Path` in three ways:
1. Direct prepending for immediate session use
2. Registry refresh from Machine and User variables
3. Silent validation of installed commands

Critical paths added:
- Node.js: `C:\Program Files\nodejs` and `%APPDATA%\npm`
- Git: `C:\Program Files\Git\cmd`
- GitHub Desktop: `%LOCALAPPDATA%\GitHubDesktop`
- VS Code: `%LOCALAPPDATA%\Programs\Microsoft VS Code\bin`

### Git Bash Configuration

The installer sets `CLAUDE_CODE_GIT_BASH_PATH` environment variable to `C:\Program Files\Git\bin\bash.exe` (required for Claude Code CLI operation on Windows).

### Installation Log Structure

Log saved to: `%LOCALAPPDATA%\ClaudeCodeInstaller\install-log.json`

Contains:
- Installer version
- Installation timestamp
- Package manager used (winget/choco)
- Tools already installed vs newly installed
- Authentication status
- All installation paths
- System information

## Modifying the Installer

### Adding New Tools

1. Add detection in Step 1 (Lines 673-677):
```powershell
$needsNewTool = -not (Test-Command -Command "newtool" -Argument "--version" -ExpectedOutputPattern "." -DisplayName "New Tool")
```

2. Add to package manager detection condition (Line 681)

3. Add installation step (follow pattern from Lines 734-772)

4. Update installation log tracking (Lines 1385-1408)

### Customizing Authentication Timeout

Change `$timeout = 900` (15 minutes) in:
- Line 517: `Start-ClaudeAuthenticationNewWindow`
- Line 999: Background auth monitor job
- Line 1164: Second auth monitor job

### Modifying Progress Animations

- **Spinner characters**: Line 50 - `$spinner = @('/', '-', '\', '|')`
- **Pulse animation**: Lines 201-206 - Pulse bar construction
- **Poll interval**: Line 519 - `$checkInterval = 2` (seconds)

## Security Considerations

### Safe Execution Folder

The installer creates `%USERPROFILE%\ClaudeProjects` as a safe location for running Claude CLI, explicitly warning against system directories:
- C:\ (root)
- C:\Windows
- C:\Program Files

### Privilege Elevation

The script checks for administrator privileges (Line 16) and auto-elevates if needed, preventing partial installations due to permission errors.

### Credential File Access

Authentication validation includes retry logic (3 attempts with 1-second delays) to handle file locking and delayed writes (Lines 324-347).

## Common Issues and Solutions

### "Command not found" after installation

**Cause**: PATH not refreshed in current session

**Solution**: Close and reopen terminal, or manually refresh:
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### npm install fails with stderr noise

**Cause**: npm writes informational messages to stderr

**Solution**: Installer checks for success indicators in output (Lines 843-852):
- "added \d+ package"
- "up to date"

### Authentication timeout

**Cause**: Slow VM/internet connections

**Solution**: Installer waits 15 minutes and performs final checks even after timeout (Lines 609-629)

### Background job memory leaks

**Solution**: All jobs explicitly cleaned up with `Remove-Job -Force` (Lines 153, 165, 222, 1373)

## Version Information

- **Current Version**: 3.1.0
- **Requires**: Windows 10/11, Administrator privileges
- **Dependencies**: .NET Framework (for PowerShell), Internet connection

### Changelog

**Version 3.1.0** (Current)
- Added GitHub Desktop installation support (Full installation only)
- Added `Test-GitHubDesktop` detection function with multiple detection methods
- Updated installation log to track GitHub Desktop
- Supports both winget and Chocolatey package managers for GitHub Desktop
- GitHub Desktop is now part of Full installation alongside Pieces Desktop

**Version 3.0.1**
- Initial stable release with Core and Full installation modes
- Includes Pieces Desktop integration

## File Structure

```
Claude Dev-Pak/
└── ClaudeCodeInstaller - 10.13.25-05.26.ps1  (Main installer script)
```

After installation, the following are created:
- `%USERPROFILE%\ClaudeProjects\` - Safe project folder with README.txt
- `%LOCALAPPDATA%\ClaudeCodeInstaller\install-log.json` - Installation log
- `QuickStart.md` - Generated guide (if user selects it)
