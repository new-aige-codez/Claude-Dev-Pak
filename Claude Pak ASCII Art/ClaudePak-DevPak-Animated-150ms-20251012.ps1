# ClaudePak Installer - Clean Block Style - DEV-PAK Version (Animated - Interlaced 4-pass)
# PowerShell 5.1+ Compatible - No BOM encoding issues!

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ANSI Colors - Enhanced to match target
$reset = "$([char]27)[0m"
$o1 = "$([char]27)[38;2;255;140;70m"    # Bright warm orange (lighter blocks)
$o2 = "$([char]27)[38;2;220;90;40m"     # Deep warm orange (darker blocks)
$blue = "$([char]27)[38;2;100;150;255m"  # Rich blue (D, E letters)
$cyan = "$([char]27)[38;2;100;200;220m"  # Bright cyan (V, -, P letters)
$green = "$([char]27)[38;2;100;220;150m" # Vibrant green (A, K letters)
$border = "$([char]27)[38;2;200;110;60m" # Warm orange border
$gray = "$([char]27)[38;2;160;160;160m"
$shadowColor = "$([char]27)[38;2;150;80;45m" # Darker orange for shadow

# Unicode characters built dynamically
$b = [char]0x2588  # Full block
$dtl = [char]0x2554 # Double top-left
$dtr = [char]0x2557 # Double top-right
$dbl = [char]0x255A # Double bottom-left
$dbr = [char]0x255D # Double bottom-right
$dh = [char]0x2550  # Double horizontal
$dv = [char]0x2551  # Double vertical
$h = [char]0x2500  # Horizontal

# Heavy box-drawing characters for border effect
$heavyH = [char]0x2501   # Heavy horizontal
$heavyV = [char]0x2503   # Heavy vertical
$heavyTR = [char]0x2513  # Heavy top-right
$heavyBL = [char]0x2517  # Heavy bottom-left
$heavyBR = [char]0x251B  # Heavy bottom-right

# Store all lines in an array
$lines = @(
    "           "
    "           ${border}$dtl$([string]$dh * 92)$dtr${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyTR${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                       ${o1}$b$b$b$b$b$b$dtr$b$b$dtr      $b$b$b$b$b$dtr $b$b$dtr   $b$b$dtr$b$b$b$b$b$b$dtr $b$b$b$b$b$b$b$dtr${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                      ${o1}$b$b$dtl$dh$dh$dh$dh$dbr$b$b$dv     $b$b$dtl$dh$dh$b$b$dtr$b$b$dv   $b$b$dv$b$b$dtl$dh$dh$b$b$dtr$b$b$dtl$dh$dh$dh$dh$dbr${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                      ${o1}$b$b$dv     $b$b$dv     $b$b$b$b$b$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$b$b$b$dtr  ${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                      ${o1}$b$b$dv     $b$b$dv     $b$b$dtl$dh$dh$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$dtl$dh$dh$dbr  ${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                      ${o1}$dbl$b$b$b$b$b$b$dtr$b$b$b$b$b$b$b$dtr$b$b$dv  $b$b$dv$dbl$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$b$dtr${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                       ${o2}$dbl$dh$dh$dh$dh$dh$dbr$dbl$dh$dh$dh$dh$dh$dh$dbr$dbl$dh$dbr  $dbl$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dh$dbr${reset}                     ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$b$b$b$b$b$b$dtr${reset} ${blue}$b$b$b$b$b$b$b$dtr${reset}${cyan}$b$b$dv   $b$b$dv${reset}      ${cyan}$b$b$b$b$b$b$dtr${reset}  ${green}$b$b$b$b$b$dtr${reset} ${green}$b$b$dtr  $b$b$dtr${reset}                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$b$b$dtl$dh$dh$b$b$dtr${reset}${blue}$b$b$dtl$dh$dh$dh$dh$dbr${reset}${cyan}$b$b$dv   $b$b$dv${reset}      ${cyan}$b$b$dtl$dh$dh$b$b$dtr${reset}${green}$b$b$dtl$dh$dh$b$b$dtr${reset}${green}$b$b$dv $b$b$dtl$dbr${reset}                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$b$b$dv  $b$b$dv${reset}${blue}$b$b$b$b$b$dtr${reset}  ${cyan}$b$b$dv   $b$b$dv${reset}${cyan}$b$b$b$b$b$dtr${reset}${cyan}$b$b$b$b$b$b$dtl$dbr${reset}${green}$b$b$b$b$b$b$b$dv${reset}${green}$b$b$b$b$b$dtl$dbr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$b$b$dv  $b$b$dv${reset}${blue}$b$b$dtl$dh$dh$dbr${reset}  ${cyan}$dbl$b$b$dtr $b$b$dtl$dbr${reset}${cyan}$dbl$dh$dh$dh$dh$dbr${reset}${cyan}$b$b$dtl$dh$dh$dh$dbr${reset} ${green}$b$b$dtl$dh$dh$b$b$dv${reset}${green}$b$b$dtl$dh$b$b$dtr${reset}                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$b$b$b$b$b$b$dtl$dbr${reset}${blue}$b$b$b$b$b$b$b$dtr${reset} ${cyan}$dbl$b$b$b$b$dtl$dbr${reset}       ${cyan}$b$b$dv${reset}     ${green}$b$b$dv  $b$b$dv${reset}${green}$b$b$dv  $b$b$dtr${reset}                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                   ${blue}$dbl$dh$dh$dh$dh$dh$dbr${reset} ${blue}$dbl$dh$dh$dh$dh$dh$dh$dbr${reset}  ${cyan}$dbl$dh$dh$dh$dbr${reset}        ${cyan}$dbl$dh$dbr${reset}     ${green}$dbl$dh$dbr  $dbl$dh$dbr${reset}${green}$dbl$dh$dbr  $dbl$dh$dbr${reset}                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                             ${gray}Claude Toolkit Installation Wizard${reset}                             ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                             ${gray}$([string]$h * 35)${reset}                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                  ${gray}- Claude Code CLI Agent${reset}                                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                  ${gray}- Git - Version control${reset}                                   ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                  ${gray}- Visual Studio Code IDE${reset}                                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                  ${gray}- Custom Forked Chat GUI${reset}                                  ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                     ${gray}w/Leading AI Dev Protocols${reset}                             ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dv${reset}                                                                                            ${border}$dv${reset}${shadowColor}$heavyV${reset}"
    "           ${border}$dbl$([string]$dh * 92)$dbr${reset}${shadowColor}$heavyV${reset}"
    "            ${shadowColor}$heavyBL$([string]$heavyH * 92)$heavyBR${reset}"
    "           "
    "           "
    "             ${gray}Tools in Claude Pak Toolkit:${reset}"
    "           "
    "             ${gray}- Claude Code CLI: Advanced AI-powered terminal interface for code assistance${reset}"
    "             ${gray}- Git: Distributed version control system for tracking code changes${reset}"
    "             ${gray}- Visual Studio Code IDE: Lightweight code editor with extensive extensions${reset}"
    "             ${gray}- Custom Forked Chat GUI: Modified chat interface with built-in development protocols${reset}"
    "           "
)

# Hide cursor during animation
[Console]::CursorVisible = $false

# Interlaced animation: Display every 4th line with 150ms delay
# 4 passes through the array
for ($pass = 0; $pass -lt 4; $pass++) {
    for ($i = $pass; $i -lt $lines.Count; $i += 4) {
        [Console]::SetCursorPosition(0, $i)
        Write-Host $lines[$i] -NoNewline
        Start-Sleep -Milliseconds 150
    }
}

# Position cursor at end
[Console]::SetCursorPosition(0, $lines.Count)

# Show cursor again
[Console]::CursorVisible = $true
