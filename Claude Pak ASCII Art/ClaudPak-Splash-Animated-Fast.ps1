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

# 3D shadow effect characters
$shadow = [char]0x2592 # ▒ Medium shade
$bottomShadow = [char]0x2582 # ▂ Lower one quarter block

# Animation function - outputs 2 characters at a time with 1ms delay
function Write-AnimatedHost {
    param([string]$Line)

    $i = 0
    $visibleChars = ""
    $length = $Line.Length

    while ($i -lt $length) {
        # Check if we're at the start of an ANSI escape sequence
        if ($Line[$i] -eq [char]27) {
            # Found ANSI escape sequence - output accumulated visible chars first
            if ($visibleChars.Length -gt 0) {
                Write-Host $visibleChars -NoNewline
                $visibleChars = ""
            }

            # Find the end of the ANSI sequence (ends with 'm')
            $ansiSequence = ""
            while ($i -lt $length) {
                $ansiSequence += $Line[$i]
                $currentChar = $Line[$i]
                $i++
                if ($currentChar -eq 'm') {
                    break
                }
            }

            # Output the entire ANSI sequence immediately (no delay)
            Write-Host $ansiSequence -NoNewline
        }
        else {
            # Regular visible character - add to buffer
            $visibleChars += $Line[$i]
            $i++

            # When we have 2 characters, output them with delay
            if ($visibleChars.Length -eq 2) {
                Write-Host $visibleChars -NoNewline
                Start-Sleep -Milliseconds 1
                $visibleChars = ""
            }
        }
    }

    # Output any remaining characters
    if ($visibleChars.Length -gt 0) {
        Write-Host $visibleChars -NoNewline
    }

    # Output newline
    Write-Host ""
}

Write-Host ""
Write-AnimatedHost "${border}$dtl$([string]$dh * 64)$dtr${reset}"
Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}"

# CLAUDE - Complete word with proper colors
Write-AnimatedHost "${border}$dv${reset}         ${o1}$b$b$b$b$b$b$dtr$b$b$dtr      $b$b$b$b$b$dtr $b$b$dtr   $b$b$dtr$b$b$b$b$b$b$dtr $b$b$b$b$b$b$b$dtr${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}        ${o1}$b$b$dtl$dh$dh$dh$dh$dbr$b$b$dv     $b$b$dtl$dh$dh$b$b$dtr$b$b$dv   $b$b$dv$b$b$dtl$dh$dh$b$b$dtr$b$b$dtl$dh$dh$dh$dh$dbr${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}        ${o1}$b$b$dv     $b$b$dv     $b$b$b$b$b$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$b$b$b$dtr  ${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}        ${o1}$b$b$dv     $b$b$dv     $b$b$dtl$dh$dh$b$b$dv$b$b$dv   $b$b$dv$b$b$dv  $b$b$dv$b$b$dtl$dh$dh$dbr  ${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}        ${o1}$dbl$b$b$b$b$b$b$dtr$b$b$b$b$b$b$b$dtr$b$b$dv  $b$b$dv$dbl$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$dtl$dbr$b$b$b$b$b$b$b$dtr${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}        ${o2} $dbl$dh$dh$dh$dh$dh$dbr$dbl$dh$dh$dh$dh$dh$dh$dbr$dbl$dh$dbr  $dbl$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dbr $dbl$dh$dh$dh$dh$dh$dh$dbr${reset}       ${border}$dv${reset}${shadowColor}$shadow${reset}"

Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}${shadowColor}$shadow${reset}"

# PAK with gradient - 3D block style with box-drawing characters
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$b$b$b$b$b$b$dtr${reset}  ${cyan}$b$b$b$b$b$dtr${reset} ${green}$b$b$dtr  $b$b$dtr${reset}                    ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$b$b$dtl$dh$dh$b$b$dtr${reset}${cyan}$b$b$dtl$dh$dh$b$b$dtr${reset}${green}$b$b$dv $b$b$dtl$dbr${reset}                    ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$b$b$b$b$b$b$dtl$dbr${reset}${cyan}$b$b$b$b$b$b$b$dv${reset}${green}$b$b$b$b$b$dtl$dbr${reset}                     ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$b$b$dtl$dh$dh$dh$dbr${reset} ${cyan}$b$b$dtl$dh$dh$b$b$dv${reset}${green}$b$b$dtl$dh$b$b$dtr${reset}                     ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$b$b$dv${reset}     ${cyan}$b$b$dv  $b$b$dv${reset}${green}$b$b$dv  $b$b$dtr${reset}                    ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${blue}$dbl$dh$dbr${reset}     ${cyan}$dbl$dh$dbr  $dbl$dh$dbr${reset}${green}$dbl$dh$dbr  $dbl$dh$dbr${reset}                    ${border}$dv${reset}${shadowColor}$shadow${reset}"

Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}              ${gray}Claude Toolkit Installation Wizard${reset}               ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}              ${gray}$([string]$h * 35)${reset}               ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${gray}- Claude Code CLI${reset}                         ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${gray}Git - Version control${reset}                     ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${gray}- Visual Studio Code IDE${reset}                  ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                    ${gray}- Custom Forked Chat GUI${reset}                  ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                      ${gray} w/Leading AI Dev Protocols${reset}            ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dv${reset}                                                                ${border}$dv${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost "${border}$dbl$([string]$dh * 64)$dbr${reset}${shadowColor}$shadow${reset}"
Write-AnimatedHost " ${shadowColor}$([string]$shadow * 66)${reset}"
Write-Host ""

Write-Host "  ${gray}Description of tools in Claude Pak toolkit:${reset}"
Write-Host ""
Write-Host "  ${gray}• Claude Code CLI: Advanced AI-powered terminal interface for code assistance${reset}"
Write-Host "  ${gray}• Git: Distributed version control system for tracking code changes${reset}"
Write-Host "  ${gray}• Visual Studio Code IDE: Lightweight code editor with extensive extensions${reset}"
Write-Host "  ${gray}• Custom Forked Chat GUI: Modified chat interface with built-in development protocols${reset}"
Write-Host ""
