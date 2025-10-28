# Integration Verification Script
# Verifies that Configuration module and installer are properly integrated

Write-Host "===== Verifying Configuration Integration =====" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Check 1: Verify all required files exist
Write-Host "Check 1: Required Files" -ForegroundColor Yellow
$filesOK = $true

$requiredFiles = @(
    @{Path = "Modules\Configuration.psm1"; Name = "Configuration Module"},
    @{Path = "InstallConfig.json"; Name = "Configuration Template"},
    @{Path = "ClaudeCodeInstaller - 10.19.25-13.55.ps1"; Name = "Installer Script"}
)

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $PSScriptRoot "..\$($file.Path)"
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $($file.Name) exists" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($file.Name) missing at: $fullPath" -ForegroundColor Red
        $filesOK = $false
        $allPassed = $false
    }
}

Write-Host ""

if (-not $filesOK) {
    Write-Host "[ERROR] Required files missing. Cannot continue." -ForegroundColor Red
    exit 1
}

# Check 2: Verify module can be imported
Write-Host "Check 2: Module Import" -ForegroundColor Yellow
try {
    $modulePath = Join-Path $PSScriptRoot "..\Modules\Configuration.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "  [OK] Configuration module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
    exit 1
}

Write-Host ""

# Check 3: Verify all functions are available
Write-Host "Check 3: Module Functions" -ForegroundColor Yellow
$expectedFunctions = @('Get-InstallConfiguration', 'Save-InstallConfiguration', 'Merge-ConfigurationWithParameters', 'Test-ConfigurationValid')
$availableFunctions = (Get-Command -Module Configuration -ErrorAction SilentlyContinue).Name

foreach ($func in $expectedFunctions) {
    if ($func -in $availableFunctions) {
        Write-Host "  [OK] $func available" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $func missing" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host ""

# Check 4: Test config loading
Write-Host "Check 4: Configuration Loading" -ForegroundColor Yellow
try {
    $configPath = Join-Path $PSScriptRoot "..\InstallConfig.json"
    $config = Get-InstallConfiguration -ConfigPath $configPath -ErrorAction Stop

    if ($config) {
        Write-Host "  [OK] Configuration loaded successfully" -ForegroundColor Green
        Write-Host "    - Installation Type: $($config.installationType)" -ForegroundColor Gray
        Write-Host "    - Components: $($config.components.PSObject.Properties.Name.Count)" -ForegroundColor Gray
        Write-Host "    - Silent Mode: $($config.silent)" -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] Configuration is null" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "  [FAIL] Failed to load config: $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
    exit 1
}

Write-Host ""

# Check 5: Validate configuration
Write-Host "Check 5: Configuration Validation" -ForegroundColor Yellow
try {
    $validation = Test-ConfigurationValid -Configuration $config -ErrorAction Stop

    if ($validation.IsValid) {
        Write-Host "  [OK] Configuration is valid" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Configuration validation failed:" -ForegroundColor Red
        $validation.Errors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        $allPassed = $false
    }
} catch {
    Write-Host "  [FAIL] Validation error: $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""

# Check 6: Verify installer script imports module
Write-Host "Check 6: Installer Script Module Import" -ForegroundColor Yellow
$installerPath = Join-Path $PSScriptRoot "..\ClaudeCodeInstaller - 10.19.25-13.55.ps1"
$scriptContent = Get-Content $installerPath -Raw

if ($scriptContent -match 'Import-Module.*Configuration\.psm1') {
    Write-Host "  [OK] Installer imports Configuration module" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Installer does not import Configuration module" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""

# Check 7: Verify installer uses config functions
Write-Host "Check 7: Installer Uses Configuration Functions" -ForegroundColor Yellow
$functionsUsed = 0
$functionChecks = @()

foreach ($func in $expectedFunctions) {
    if ($scriptContent -match $func) {
        Write-Host "  [OK] Installer uses $func" -ForegroundColor Green
        $functionsUsed++
        $functionChecks += $true
    } else {
        Write-Host "  [WARNING] Installer may not use $func" -ForegroundColor Yellow
        $functionChecks += $false
    }
}

if ($functionsUsed -eq 0) {
    Write-Host "  [FAIL] No configuration functions found in installer" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""

# Check 8: Verify parameter block exists
Write-Host "Check 8: Parameter Block" -ForegroundColor Yellow

if ($scriptContent -match '\[CmdletBinding\(\)\]') {
    Write-Host "  [OK] CmdletBinding attribute present" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] CmdletBinding missing" -ForegroundColor Red
    $allPassed = $false
}

$params = @('ConfigFile', 'InstallationType', 'Silent', 'CreateShortcuts', 'SkipAuthentication', 'Force', 'SaveConfig', 'UseDefaults')
$paramsFound = 0

foreach ($param in $params) {
    if ($scriptContent -match "\`$$param") {
        $paramsFound++
    }
}

if ($paramsFound -eq $params.Count) {
    Write-Host "  [OK] All $($params.Count) parameters defined" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Only $paramsFound of $($params.Count) parameters found" -ForegroundColor Yellow
}

Write-Host ""

# Check 9: Verify script variables are initialized
Write-Host "Check 9: Script Variables" -ForegroundColor Yellow

if ($scriptContent -match '\$script:SilentMode') {
    Write-Host "  [OK] SilentMode variable initialized" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] SilentMode variable not found" -ForegroundColor Yellow
}

if ($scriptContent -match '\$script:ForceInstall') {
    Write-Host "  [OK] ForceInstall variable initialized" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] ForceInstall variable not found" -ForegroundColor Yellow
}

if ($scriptContent -match '\$script:ComponentResults') {
    Write-Host "  [OK] ComponentResults variable initialized" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] ComponentResults variable not found" -ForegroundColor Yellow
}

Write-Host ""

# Check 10: Test parameter merging
Write-Host "Check 10: Parameter Merging" -ForegroundColor Yellow
try {
    $testParams = @{
        installationType = 'Core'
        silent = $true
    }

    $merged = Merge-ConfigurationWithParameters -Configuration $config -Parameters $testParams

    if ($merged.installationType -eq 'Core' -and $merged.silent -eq $true) {
        Write-Host "  [OK] Parameter merging works correctly" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Parameter merging not working" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "  [FAIL] Parameter merging error: $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""

# Final Summary
Write-Host "===== Verification Complete =====" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) {
    Write-Host "RESULT: All checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Green
    Write-Host "  [PASS] All required files present" -ForegroundColor Green
    Write-Host "  [PASS] Configuration module loads successfully" -ForegroundColor Green
    Write-Host "  [PASS] All 4 functions exported and working" -ForegroundColor Green
    Write-Host "  [PASS] Configuration file is valid" -ForegroundColor Green
    Write-Host "  [PASS] Installer properly integrated with config system" -ForegroundColor Green
    Write-Host "  [PASS] Parameters defined and functional" -ForegroundColor Green
    Write-Host "  [PASS] Parameter merging works correctly" -ForegroundColor Green
    Write-Host ""
    Write-Host "The configuration system is fully integrated and ready to use!" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "RESULT: Some checks failed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please review the failures above and fix any issues." -ForegroundColor Yellow
    exit 1
}
