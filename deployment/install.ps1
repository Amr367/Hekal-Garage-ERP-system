# PowerShell Robust Installer for Hekal Garage ERP
$ErrorActionPreference = "Stop"

# Self-elevate to Administrator if needed (UAC prompt)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges to install..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null
        exit 0
    } catch {
        Write-Host "Administrator privileges are required to install to C:\HekalGarage." -ForegroundColor Red
        Write-Host "Press any key to exit..."
        [Console]::ReadKey() | Out-Null
        exit 1
    }
}

$targetDir = "C:\HekalGarage"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $scriptDir "App"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Installing Hekal Garage ERP System - مركز هيكل          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $sourceDir)) {
    Write-Host "[ERROR] Could not find the 'App' directory at: $sourceDir" -ForegroundColor Red
    Write-Host "Please extract the full ZIP file before running." -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    [Console]::ReadKey() | Out-Null
    exit 1
}

Write-Host "[1/3] Copying files to $targetDir..." -ForegroundColor Green
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force

Write-Host "[2/3] Creating Desktop Shortcut..." -ForegroundColor Green
try {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "مركز هيكل لإصلاح السيارات.lnk"
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $targetDir "garage_erp.exe"
    $shortcut.WorkingDirectory = $targetDir
    $shortcut.Description = "مركز هيكل لإصلاح السيارات"
    $shortcut.Save()
} catch {
    Write-Host "Warning: Could not create desktop shortcut: $_" -ForegroundColor Yellow
}

Write-Host "[3/3] Configuring Windows Firewall for LAN..." -ForegroundColor Green
try {
    netsh advfirewall firewall delete rule name="Hekal Garage ERP LAN" 2>$null | Out-Null
    netsh advfirewall firewall add rule name="Hekal Garage ERP LAN" dir=in action=allow protocol=TCP localport=4455 | Out-Null
} catch {}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   Installation Completed Successfully!                     " -ForegroundColor Green
Write-Host "   تم التثبيت بنجاح! وتم إنشاء اختصار على سطح المكتب.      " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

# Launch application
$exePath = Join-Path $targetDir "garage_erp.exe"
if (Test-Path $exePath) {
    Write-Host "Launching Hekal Garage ERP..." -ForegroundColor Cyan
    Start-Process $exePath
}
