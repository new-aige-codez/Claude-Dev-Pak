# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains PowerShell and HTML scripts for creating a "CLAUDE PAK" ASCII art splash screen with 3D effects, shadowing, and color gradients. The splash screen is designed for a ClaudePak Toolkit installer wizard display.

## Core Files

- **`claudepak-splash-clean.ps1`**: Main PowerShell 5.1+ script that renders the ASCII art splash screen in terminal
- **`preview.html`**: Browser-based preview for visual verification of the ASCII art (mirrors PowerShell output)

## Running the Splash Screen

```powershell
# Run in PowerShell
powershell -ExecutionPolicy Bypass -File "claudepak-splash-clean.ps1"
```

## Technical Architecture

### PowerShell Script Structure

The script uses **PowerShell 5.1+ compatible syntax** to avoid BOM encoding issues:
- All Unicode characters are defined using `[char]0xXXXX` syntax
- ANSI 24-bit color codes: `$([char]27)[38;2;R;G;Bm`
- String multiplication for repetitive characters: `[string]$char * count`

### Color Scheme

**CLAUDE text** (two-tone orange):
- Light orange: RGB(255,140,70) - `$o1`
- Dark orange: RGB(220,90,40) - `$o2`

**PAK text** (gradient):
- Blue: RGB(100,150,255) - P letter
- Cyan: RGB(100,200,220) - A letter
- Green: RGB(100,220,150) - K letter

**Border & Shadow**:
- Border: RGB(200,110,60)
- Shadow: RGB(150,80,45) - `$shadowColor`
- Gray text: RGB(160,160,160)

### 3D Shadow Implementation

The 3D effect uses two Unicode shadow characters:
- `▒` (char 0x2592) - Medium shade for right edge
- Bottom shadow row: 66 medium shade blocks with 1-space left offset

Shadow appears:
- On the right edge of all bordered content lines
- On the bottom row beneath the box border `╚═══...═══╝`

### ASCII Art Letter Construction

Letters are built using:
- **Solid blocks**: `█` (char 0x2588) - `$b`
- **Box-drawing characters** for 3D structure:
  - `╔╗╚╝` (double corners) - `$dtl`, `$dtr`, `$dbl`, `$dbr`
  - `═║` (double lines) - `$dh`, `$dv`
  - `─│┌┐└┘` (single lines) - `$h`, `$v`, `$tl`, `$tr`, `$bl`, `$br`

**Critical**: Use `╗` (top-right corner) for top rows, NOT `║` (vertical), to achieve proper 3D shadow effect.

### Border Alignment

The box border is **64 characters wide** (not including border characters themselves):
- Top: `╔` + 64×`═` + `╗`
- Sides: `║` + 64 spaces + `║` + `▒` (shadow)
- Bottom: `╚` + 64×`═` + `╝` + `▒`
- Bottom shadow: space + 66×`▒`

All content must maintain precise spacing to keep borders vertically aligned.

### HTML Preview Rendering

The `preview.html` file must have `line-height: 1.0` in both body and pre tags to prevent black line artifacts between rows. It mirrors the exact PowerShell output using RGB color spans.

## Layout Structure

```
╔═══════════════════════════════════╗
║                                   ║
║         CLAUDE (orange)           ║▒
║           PAK (gradient)          ║▒
║                                   ║▒
║  Claude Toolkit Installation Wiz  ║▒
║  ─────────────────────────────    ║▒
║                                   ║▒
║    - Claude Code CLI              ║▒
║    Git - Version control          ║▒
║    - Visual Studio Code IDE       ║▒
║    - Custom Forked Chat GUI       ║▒
║      w/Leading AI Dev Protocols   ║▒
║                                   ║▒
╚═══════════════════════════════════╝▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

Description of tools in Claude Pak toolkit:
• Claude Code CLI: ...
• Git: ...
• Visual Studio Code IDE: ...
• Custom Forked Chat GUI: ...
```

## Key Editing Principles

1. **Always maintain border alignment**: When adding/removing content, adjust spacing to keep right borders (`║`) vertically aligned at column 64
2. **Preserve shadow spacing**: Shadow characters (`▒`) must appear on every content line on the right, and one full row on the bottom
3. **Keep line-height 1.0** in HTML to prevent rendering artifacts
4. **Use box-drawing characters** (╔╗╚╝║═) for letter structure, not alternating colored blocks
5. **Test in both environments**: PowerShell terminal AND browser preview to verify alignment

## Common Modifications

**To adjust spacing between sections**:
- Add/remove blank lines: `Write-Host "${border}$dv${reset}...spaces...${border}$dv${reset}${shadowColor}$shadow${reset}"`
- Ensure shadow `▒` appears at the end of each line

**To change text positioning**:
- Count spaces carefully before/after text to maintain 64-character width
- Shift right borders left/right by adjusting trailing spaces before `${border}$dv`

**To update tool descriptions**:
- Edit lines 66-70 in PowerShell script
- Edit lines 44-48 in HTML
- Maintain list format consistency
