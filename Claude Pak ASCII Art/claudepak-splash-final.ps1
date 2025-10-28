# ClaudePak Installer Splash Screen
# PowerShell 5.1+ Compatible - No BOM Issues!
# Uses dynamic character building to avoid encoding problems

# Enable UTF-8 output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Clear screen
Clear-Host

# ANSI Color Codes
$reset = "$([char]27)[0m"

# Orange shades for CLAUDE
$o1 = "$([char]27)[38;2;255;150;90m"
$o2 = "$([char]27)[38;2;235;130;70m"

# Blue to Green gradient for PAK
$blue = "$([char]27)[38;2;70;150;255m"
$cyan = "$([char]27)[38;2;70;190;200m"
$green = "$([char]27)[38;2;90;220;140m"

# Border and text colors
$border = "$([char]27)[38;2;150;150;150m"
$gray = "$([char]27)[38;2;180;180;180m"

# Build Unicode box-drawing characters dynamically (avoids BOM issues!)
$box = @{
    TL = [char]0x2554      # ╔
    TR = [char]0x2557      # ╗
    BL = [char]0x255A      # ╚
    BR = [char]0x255D      # ╝
    H = [char]0x2550       # ═
    V = [char]0x2551       # ║
    Block = [char]0x2588   # █
}

# Create horizontal line
$hLine = $box.H * 62

# Display banner
Write-Host ""
Write-Host "${border}$($box.TL)$hLine$($box.TR)${reset}"
Write-Host "${border}$($box.V)${reset}                                                              ${border}$($box.V)${reset}"

# CLAUDE - Built with block characters
Write-Host "${border}$($box.V)${reset}    ${o1}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${o2}$($box.Block)$($box.Block)${reset}      ${o1}$($box.Block)     ${o2}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${o1}$($box.Block)   $($box.Block)  ${o2}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}   ${o1}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}    ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}   ${o2}$($box.Block)$($box.Block)${reset}        ${o1}$($box.Block)     ${o2}$($box.Block)${reset}      ${o1}$($box.Block)   $($box.Block)  ${o2}$($box.Block)${reset}      ${o1}$($box.Block)${reset}       ${o2}$($box.Block)${reset}        ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}   ${o1}$($box.Block)$($box.Block)${reset}        ${o2}$($box.Block)     ${o1}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${o2}$($box.Block)   $($box.Block)  ${o1}$($box.Block)  $($box.Block)${reset}   ${o2}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}      ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}   ${o2}$($box.Block)$($box.Block)${reset}        ${o1}$($box.Block)     ${o2}$($box.Block)${reset}      ${o1}$($box.Block)   $($box.Block)  ${o2}$($box.Block)  $($box.Block)${reset}   ${o1}$($box.Block)${reset}            ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}    ${o1}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${o2}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${o1}$($box.Block)${reset}      ${o2}$($box.Block) $($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}   ${o1}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}   ${o2}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}    ${border}$($box.V)${reset}"

Write-Host "${border}$($box.V)${reset}                                                              ${border}$($box.V)${reset}"

# PAK - With gradient
Write-Host "${border}$($box.V)${reset}               ${blue}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}   ${cyan}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${green}$($box.Block)  $($box.Block)${reset}                   ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}               ${blue}$($box.Block)${reset}      ${cyan}$($box.Block)${reset}  ${green}$($box.Block)${reset}      ${cyan}$($box.Block)${reset}  ${green}$($box.Block) $($box.Block)${reset}                    ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}               ${blue}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}   ${cyan}$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}  ${green}$($box.Block)$($box.Block)$($box.Block)$($box.Block)${reset}                     ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}               ${blue}$($box.Block)${reset}           ${cyan}$($box.Block)${reset}      ${green}$($box.Block)${reset}  ${cyan}$($box.Block) $($box.Block)${reset}                    ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}               ${blue}$($box.Block)${reset}           ${cyan}$($box.Block)${reset}      ${green}$($box.Block)${reset}  ${cyan}$($box.Block)  $($box.Block)${reset}                   ${border}$($box.V)${reset}"

Write-Host "${border}$($box.V)${reset}                                                              ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}    ${gray}Claude Code CLI + Visual Studio Code + Custom Chat GUI${reset}    ${border}$($box.V)${reset}"
Write-Host "${border}$($box.V)${reset}                                                              ${border}$($box.V)${reset}"
Write-Host "${border}$($box.BL)$hLine$($box.BR)${reset}"
Write-Host ""

# Installation message
Write-Host "  ${gray}Installing your complete Claude development suite...${reset}"
Write-Host ""

# Optional: Pause
# Write-Host "  ${gray}Press any key to continue...${reset}" -NoNewline
# $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
# Write-Host ""
