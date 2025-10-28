# Test Shadow Character Rendering in PowerShell 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$shadowColor = "$([char]27)[38;2;150;80;45m"
$reset = "$([char]27)[0m"

# Current character
$currentShadow = [char]0x2592  # Medium shade (currently used)

# Proposed new characters
$rightShadow = [char]0x2590    # Right half block
$bottomShadow = [char]0x2584   # Lower half block

Write-Host ""
Write-Host "Shadow Character Compatibility Test"
Write-Host "===================================="
Write-Host ""

Write-Host "Current character (Medium Shade U+2592):"
Write-Host "  ${shadowColor}$currentShadow$currentShadow$currentShadow$currentShadow$currentShadow${reset}"
Write-Host ""

Write-Host "Proposed RIGHT edge character (Right Half Block U+2590):"
Write-Host "  ${shadowColor}$rightShadow$rightShadow$rightShadow$rightShadow$rightShadow${reset}"
Write-Host ""

Write-Host "Proposed BOTTOM edge character (Lower Half Block U+2584):"
Write-Host "  ${shadowColor}$bottomShadow$bottomShadow$bottomShadow$bottomShadow$bottomShadow${reset}"
Write-Host ""

Write-Host "Test corner combination:"
Write-Host "  Box${shadowColor}$rightShadow${reset}"
Write-Host "     ${shadowColor}$bottomShadow$bottomShadow$bottomShadow${reset}"
Write-Host ""

Write-Host "Character Unicode values:"
Write-Host "  U+2592 - Current: Medium Shade"
Write-Host "  U+2590 - Proposed Right: Right Half Block"
Write-Host "  U+2584 - Proposed Bottom: Lower Half Block"
Write-Host ""
Write-Host "If all characters display correctly above, the new shadow style will work."
Write-Host ""
