# ClaudePak Installer - Clean Block Style
# PowerShell 5.1+ Compatible - No BOM encoding issues!

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ANSI Colors - Enhanced to match target
$reset = "$([char]27)[0m"
$o1 = "$([char]27)[38;2;255;140;70m"    # Bright warm orange (lighter blocks)
$o2 = "$([char]27)[38;2;220;90;40m"     # Deep warm orange (darker blocks)
$blue = "$([char]27)[38;2;100;150;255m"  # Rich blue (P letter)
$cyan = "$([char]27)[38;2;100;200;220m"  # Bright cyan (A letter)
$green = "$([char]27)[38;2;100;220;150m" # Vibrant green (K letter)
$border = "$([char]27)[38;2;200;110;60m" # Warm orange border
$gray = "$([char]27)[38;2;160;160;160m"
$shadowColor = "$([char]27)[38;2;150;80;45m" # Darker orange for shadow

# Unicode characters built dynamically
$b = [char]0x2588  # █ Full block
$tl = [char]0x250C # ┌ Border top-left
$tr = [char]0x2510 # ┐ Border top-right
$bl = [char]0x2514 # └ Border bottom-left
$br = [char]0x2518 # ┘ Border bottom-right
$h = [char]0x2500  # ─ Border horizontal
$v = [char]0x2502  # │ Border vertical

# Box-drawing characters for 3D letters
$dtl = [char]0x2554 # ╔ Double top-left
$dtr = [char]0x2557 # ╗ Double top-right
$dbl = [char]0x255A # ╚ Double bottom-left
$dbr = [char]0x255D # ╝ Double bottom-right
$dh = [char]0x2550  # ═ Double horizontal
$dv = [char]0x2551  # ║ Double vertical

# 3D shadow effect characters - Gradient
$medShade = [char]0x2592    # ▒ Medium shade
$darkShade = [char]0x2593   # ▓ Dark shade

# Heavy box-drawing characters for border effect
$heavyH = [char]0x2501   # ━ Heavy horizontal
$heavyV = [char]0x2503   # ┃ Heavy vertical
$heavyTR = [char]0x2513  # ┓ Heavy top-right
$heavyBL = [char]0x2517  # ┗ Heavy bottom-left
$heavyBR = [char]0x251B  # ┛ Heavy bottom-right

# Line-by-line animation function - outputs entire line with 50ms delay
function Write-AnimatedLine {
    param([string]$Line)
    Write-Host $Line
    Start-Sleep -Milliseconds 50
}

# Hide cursor during animation
try { [Console]::CursorVisible = $false } catch { }

Write-Host ""
Write-AnimatedLine "${border}$dtl$([string]$dh * 88)$dtr${reset}"
Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyTR${reset}"

# CLAUDE - Complete word with proper colors
Write-AnimatedLine "${border}$dv${reset}                     ${o1}$b$b$b$b$b$b$dtr$b$b$dtr      $b$b$b$b$b$dtr $b$b$dtr   $b$b$dtr$b$b$b$b$b$b$dtr $b$b$b$b$b$b$b$dtr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                    ${o1}$b$b$dtl$dh$dh$dh$dh$dbr$b$b$dv     $b$b$dtl$dh$dh$b$b$dtr$b$b$dv   $b$b$dv$b$b$dtl$dh$dh$b$b$dtr$b$b$dtl$dh$dh$dh$dh$dbr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                    ${o1}$b$b$dv     $b$b$dv     $b$b$b$b$b$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$b$b$b$dtr  ${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                    ${o1}$b$b$dv     $b$b$dv     $b$b$dtl$dh$dh$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$dtl$dh$dh$dbr  ${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                    ${o1}$dbl$b$b$b$b$b$b$dtr$b$b$b$b$b$b$b$dtr$b$b$dv  $b$b$dv$dbl$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$b$dtr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                    ${o2} $dbl$dh$dh$dh$dh$dh$dbr$dbl$dh$dh$dh$dh$dh$dh$dbr$dbl$dh$dbr  $dbl$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dh$dbr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"

Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyV${reset}"

# PAK with gradient - 3D block style with box-drawing characters
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$b$b$b$b$b$b$dtr${reset}  ${cyan}$b$b$b$b$b$dtr${reset} ${green}$b$b$dtr  $b$b$dtr${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$b$b$dtl$dh$dh$b$b$dtr${reset}${cyan}$b$b$dtl$dh$dh$b$b$dtr${reset}${green}$b$b$dv $b$b$dtl$dbr${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$b$b$b$b$b$b$dtl$dbr${reset}${cyan}$b$b$b$b$b$b$b$dv${reset}${green}$b$b$b$b$b$dtl$dbr${reset}                                 ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$b$b$dtl$dh$dh$dh$dbr${reset} ${cyan}$b$b$dtl$dh$dh$b$b$dv${reset}${green}$b$b$dtl$dh$b$b$dtr${reset}                                 ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$b$b$dv${reset}     ${cyan}$b$b$dv  $b$b$dv${reset}${green}$b$b$dv  $b$b$dtr${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${blue}$dbl$dh$dbr${reset}     ${cyan}$dbl$dh$dbr  $dbl$dh$dbr${reset}${green}$dbl$dh$dbr  $dbl$dh$dbr${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"

Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                           ${gray}Claude Toolkit Installation Wizard${reset}                           ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                           ${gray}$([string]$h * 35)${reset}                          ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${gray}- Claude Code CLI Agent${reset}                                 ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${gray}- Git - Version control${reset}                                 ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${gray}- Visual Studio Code IDE${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                ${gray}- Custom Forked Chat GUI${reset}                                ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                   ${gray}w/Leading AI Dev Protocols${reset}                           ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dv${reset}                                                                                        ${border}$dv${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine "${border}$dbl$([string]$dh * 88)$dbr${reset}${shadowColor}$heavyV${reset}"
Write-AnimatedLine " ${shadowColor}$heavyBL$([string]$heavyH * 88)$heavyBR${reset}"

# Show cursor again
try { [Console]::CursorVisible = $true } catch { }

Write-Host ""

Write-Host "  ${gray}Tools in Claude Pak Toolkit:${reset}"
Write-Host ""
Write-Host "  ${gray}• Claude Code CLI: Advanced AI-powered terminal interface for code assistance${reset}"
Write-Host "  ${gray}• Git: Distributed version control system for tracking code changes${reset}"
Write-Host "  ${gray}• Visual Studio Code IDE: Lightweight code editor with extensive extensions${reset}"
Write-Host "  ${gray}• Custom Forked Chat GUI: Modified chat interface with built-in development protocols${reset}"
Write-Host ""
