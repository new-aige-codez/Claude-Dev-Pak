# Playwright Test Script for GUI Verification
# Tests the HTML version of the Claude Code Installer GUI

Write-Host "===== Claude Code Installer GUI - Playwright Tests =====" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js/npm is installed
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Node.js is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Node.js first to run Playwright tests" -ForegroundColor Yellow
    exit 1
}

Write-Host "Node.js version:" -ForegroundColor Gray
node --version
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$htmlPath = Join-Path $projectRoot "Show-InstallerConfiguration.html"

if (-not (Test-Path $htmlPath)) {
    Write-Host "[ERROR] HTML file not found: $htmlPath" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] HTML file found: $htmlPath" -ForegroundColor Green
Write-Host ""

# Initialize npm package if needed
$packageJsonPath = Join-Path $projectRoot "package.json"
if (-not (Test-Path $packageJsonPath)) {
    Write-Host "Initializing npm package..." -ForegroundColor Cyan
    Push-Location $projectRoot
    npm init -y 2>&1 | Out-Null
    Pop-Location
    Write-Host "[OK] npm package initialized" -ForegroundColor Green
}

# Install Playwright
Write-Host "Installing Playwright (this may take a moment)..." -ForegroundColor Cyan
Push-Location $projectRoot
npm install --save-dev @playwright/test 2>&1 | Out-Null
npx playwright install chromium 2>&1 | Out-Null
Pop-Location
Write-Host "[OK] Playwright installed" -ForegroundColor Green
Write-Host ""

# Create Playwright test file
$testFilePath = Join-Path $projectRoot "gui.spec.js"

$testScript = @"
const { test, expect } = require('@playwright/test');
const path = require('path');

test.describe('Claude Code Installer GUI', () => {
    const htmlPath = 'file://' + path.resolve(__dirname, 'Show-InstallerConfiguration.html');

    test.beforeEach(async ({ page }) => {
        await page.goto(htmlPath);
    });

    test('window dimensions are correct', async ({ page }) => {
        const window = await page.locator('.window');
        await expect(window).toBeVisible();

        const box = await window.boundingBox();
        expect(box.width).toBeCloseTo(600, 5);
        expect(box.height).toBeCloseTo(550, 5);
    });

    test('header banner is visible and styled', async ({ page }) => {
        const header = page.locator('.header');
        await expect(header).toBeVisible();

        await expect(page.locator('.header h2')).toContainText('Claude Code');
        await expect(page.locator('.header p')).toContainText('Select your installation');

        // Check background color (light blue)
        const bgColor = await header.evaluate(el =>
            window.getComputedStyle(el).backgroundColor
        );
        expect(bgColor).toMatch(/rgb\(227,\s*242,\s*253\)/); // #E3F2FD
    });

    test('all installation type radios are present', async ({ page }) => {
        const radios = await page.locator('input[name="installType"]').count();
        expect(radios).toBe(3);

        // Full should be checked by default
        await expect(page.locator('#radioFull')).toBeChecked();
        await expect(page.locator('#radioCore')).not.toBeChecked();
        await expect(page.locator('#radioCustom')).not.toBeChecked();
    });

    test('core components are always checked and disabled', async ({ page }) => {
        const coreCheckboxes = await page.locator('.core-component').all();

        expect(coreCheckboxes.length).toBe(4); // nodejs, git, vscode, claude

        for (const checkbox of coreCheckboxes) {
            await expect(checkbox).toBeDisabled();
            await expect(checkbox).toBeChecked();
        }
    });

    test('full mode checks and disables optional components', async ({ page }) => {
        // Should already be in Full mode by default
        await expect(page.locator('#radioFull')).toBeChecked();

        // Optional components should be checked and disabled
        await expect(page.locator('#checkGitHubDesktop')).toBeChecked();
        await expect(page.locator('#checkGitHubDesktop')).toBeDisabled();
        await expect(page.locator('#checkPiecesDesktop')).toBeChecked();
        await expect(page.locator('#checkPiecesDesktop')).toBeDisabled();
    });

    test('core mode unchecks and disables optional components', async ({ page }) => {
        // Switch to Core mode
        await page.locator('#radioCore').click();

        // Optional components should be unchecked and disabled
        await expect(page.locator('#checkGitHubDesktop')).not.toBeChecked();
        await expect(page.locator('#checkGitHubDesktop')).toBeDisabled();
        await expect(page.locator('#checkPiecesDesktop')).not.toBeChecked();
        await expect(page.locator('#checkPiecesDesktop')).toBeDisabled();
    });

    test('custom mode enables optional components for selection', async ({ page }) => {
        // Switch to Custom mode
        await page.locator('#radioCustom').click();

        // Optional components should be enabled for user selection
        await expect(page.locator('#checkGitHubDesktop')).toBeEnabled();
        await expect(page.locator('#checkPiecesDesktop')).toBeEnabled();

        // User can check/uncheck
        await page.locator('#checkGitHubDesktop').check();
        await expect(page.locator('#checkGitHubDesktop')).toBeChecked();

        await page.locator('#checkGitHubDesktop').uncheck();
        await expect(page.locator('#checkGitHubDesktop')).not.toBeChecked();
    });

    test('additional options are present and functional', async ({ page }) => {
        // Check all three additional options exist
        await expect(page.locator('#checkShortcuts')).toBeVisible();
        await expect(page.locator('#checkAuthenticate')).toBeVisible();
        await expect(page.locator('#checkSilent')).toBeVisible();

        // First two should be checked by default
        await expect(page.locator('#checkShortcuts')).toBeChecked();
        await expect(page.locator('#checkAuthenticate')).toBeChecked();
        await expect(page.locator('#checkSilent')).not.toBeChecked();

        // All should be enabled
        await expect(page.locator('#checkShortcuts')).toBeEnabled();
        await expect(page.locator('#checkAuthenticate')).toBeEnabled();
        await expect(page.locator('#checkSilent')).toBeEnabled();
    });

    test('all three buttons are present and styled correctly', async ({ page }) => {
        await expect(page.locator('#btnSave')).toBeVisible();
        await expect(page.locator('#btnInstall')).toBeVisible();
        await expect(page.locator('#btnCancel')).toBeVisible();

        // Check Install Now button has green background
        const installButton = page.locator('#btnInstall');
        const bgColor = await installButton.evaluate(el =>
            window.getComputedStyle(el).backgroundColor
        );
        expect(bgColor).toMatch(/rgb\(40,\s*167,\s*69\)/); // #28a745
    });

    test('groupbox legends are properly positioned', async ({ page }) => {
        const legends = await page.locator('.groupbox-legend').all();
        expect(legends.length).toBe(2); // Core and Optional

        await expect(page.locator('.groupbox-legend').first()).toContainText('Core Components');
        await expect(page.locator('.groupbox-legend').last()).toContainText('Optional Components');
    });

    test('capture full screenshot for visual verification', async ({ page }) => {
        await page.screenshot({
            path: 'gui-screenshot-full.png',
            fullPage: false
        });
    });

    test('capture window screenshot only', async ({ page }) => {
        const window = page.locator('.window');
        await window.screenshot({
            path: 'gui-screenshot-window.png'
        });
    });
});
"@

Write-Host "Creating Playwright test file..." -ForegroundColor Cyan
$testScript | Out-File -FilePath $testFilePath -Encoding UTF8 -Force
Write-Host "[OK] Test file created: $testFilePath" -ForegroundColor Green
Write-Host ""

# Run Playwright tests
Write-Host "Running Playwright tests..." -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray
Write-Host ""

Push-Location $projectRoot
try {
    npx playwright test gui.spec.js --reporter=list
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Gray
Write-Host ""

# Check results
if ($exitCode -eq 0) {
    Write-Host "[SUCCESS] All Playwright tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Screenshots saved:" -ForegroundColor Cyan

    $screenshot1 = Join-Path $projectRoot "gui-screenshot-full.png"
    $screenshot2 = Join-Path $projectRoot "gui-screenshot-window.png"

    if (Test-Path $screenshot1) {
        Write-Host "  - gui-screenshot-full.png" -ForegroundColor White
    }
    if (Test-Path $screenshot2) {
        Write-Host "  - gui-screenshot-window.png" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Visual Verification:" -ForegroundColor Yellow
    Write-Host "  1. Open gui-screenshot-window.png to verify appearance" -ForegroundColor Gray
    Write-Host "  2. Check that window is 600x550 pixels" -ForegroundColor Gray
    Write-Host "  3. Verify header is light blue (#E3F2FD)" -ForegroundColor Gray
    Write-Host "  4. Verify Install Now button is green" -ForegroundColor Gray
    Write-Host "  5. Verify layout matches design specifications" -ForegroundColor Gray
    Write-Host ""

    # Try to open screenshot
    if (Test-Path $screenshot2) {
        $openScreenshot = Read-Host "Open screenshot now? [Y/N]"
        if ($openScreenshot -eq 'Y' -or $openScreenshot -eq 'y') {
            Start-Process $screenshot2
        }
    }

} else {
    Write-Host "[FAILED] Some Playwright tests failed" -ForegroundColor Red
    Write-Host "Please review the test output above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test complete!" -ForegroundColor Cyan
exit $exitCode
