$ErrorActionPreference = "Stop"
$sourceDir = "d:\Hekal\build\windows\x64\runner\Release"
$packageDir = "d:\Hekal\Hekal_Garage_Package"
$zipFile = "d:\Hekal\Hekal_Garage_ERP_v1.0.zip"
$installerExe = "d:\Hekal\Hekal_Garage_Setup_v1.0.exe"
$payloadZip = "d:\Hekal\deployment\payload.zip"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

Write-Host "Preparing deployment package..."

# 1. Ensure all Visual C++ CRT Runtime DLLs are bundled in Release directory
Write-Host "Checking Visual C++ CRT DLLs (msvcp140.dll, vcruntime140.dll, etc.)..."
$crtDir = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\14.44.35112\x64\Microsoft.VC143.CRT"
if (Test-Path $crtDir) {
    Copy-Item -Path "$crtDir\*" -Destination $sourceDir -Force
    Write-Host "Successfully bundled MSVC runtime DLLs into release directory."
} else {
    # Fallback to system32
    $systemDlls = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll")
    foreach ($dll in $systemDlls) {
        $srcPath = "C:\Windows\System32\$dll"
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $sourceDir -Force
        }
    }
}

# 2. Re-create payload.zip containing the entire application release + CRT DLLs
Write-Host "Creating compressed application payload..."
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
if (Test-Path $payloadZip) { 
    Remove-Item -Path $payloadZip -Force 
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($sourceDir, $payloadZip)

# 3. Compile Hekal_Garage_Setup_v1.0.exe with embedded payload and app icon
Write-Host "Compiling native Setup installer with embedded payload..."
& $csc /target:winexe /optimize+ /platform:anycpu `
  /win32icon:"d:\Hekal\windows\runner\resources\app_icon.ico" `
  /resource:"$payloadZip,app_payload" `
  /r:System.IO.Compression.dll,System.IO.Compression.FileSystem.dll,System.Windows.Forms.dll,System.Drawing.dll,Microsoft.CSharp.dll `
  /out:"$installerExe" "d:\Hekal\deployment\Setup.cs"

# Also compile Setup.exe in deployment folder
Copy-Item -Path $installerExe -Destination "d:\Hekal\deployment\Setup.exe" -Force

# 4. Compile Run_App.exe launcher
Write-Host "Compiling Run_App.exe launcher..."
& $csc /target:winexe /optimize+ /platform:anycpu `
  /win32icon:"d:\Hekal\windows\runner\resources\app_icon.ico" `
  /r:System.Windows.Forms.dll,System.Drawing.dll `
  /out:"d:\Hekal\deployment\Run_App.exe" "d:\Hekal\deployment\Run_App.cs"

# 5. Recreate package directory
Write-Host "Assembling package directory..."
if (Test-Path $packageDir) { 
    Remove-Item -Path $packageDir -Recurse -Force 
}
New-Item -ItemType Directory -Path "$packageDir\App" -Force | Out-Null

# 6. Copy application release files to App\
Copy-Item -Path "$sourceDir\*" -Destination "$packageDir\App" -Recurse -Force

# 7. Copy deployment files, setup, and launchers to root of package
Copy-Item -Path "d:\Hekal\deployment\*" -Destination "$packageDir\" -Recurse -Force

# Clean up internal source files from the delivery package
if (Test-Path "$packageDir\payload.zip") { Remove-Item -Path "$packageDir\payload.zip" -Force }
if (Test-Path "$packageDir\Setup.cs") { Remove-Item -Path "$packageDir\Setup.cs" -Force }
if (Test-Path "$packageDir\Run_App.cs") { Remove-Item -Path "$packageDir\Run_App.cs" -Force }

# 8. Compress package into ZIP
Write-Host "Compressing package into ZIP..."
if (Test-Path $zipFile) { 
    Remove-Item -Path $zipFile -Force 
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $zipFile)

$zipSize = [math]::Round((Get-Item $zipFile).Length / 1MB, 2)
$exeSize = [math]::Round((Get-Item $installerExe).Length / 1MB, 2)
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Setup Executable: $installerExe ($exeSize MB)" -ForegroundColor Green
Write-Host "ZIP Package:      $zipFile ($zipSize MB)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
