$ErrorActionPreference = "Stop"
$sourceDir = "d:\Hekal\build\windows\x64\runner\Release"
$packageDir = "d:\Hekal\Hekal_Garage_Package"
$zipFile = "d:\Hekal\Hekal_Garage_ERP_v1.0.zip"
$installerExe = "d:\Hekal\Hekal_Garage_Setup_v1.0.exe"

Write-Host "Preparing deployment package..."

# 1. Ensure Setup.exe is in deployment folder
if (Test-Path $installerExe) {
    Copy-Item -Path $installerExe -Destination "d:\Hekal\deployment\Setup.exe" -Force
}

# 2. Recreate package directory
if (Test-Path $packageDir) { 
    Remove-Item -Path $packageDir -Recurse -Force 
}
New-Item -ItemType Directory -Path "$packageDir\App" -Force | Out-Null

# 3. Copy application release files to App\
Write-Host "Copying application release files..."
Copy-Item -Path "$sourceDir\*" -Destination "$packageDir\App" -Recurse -Force

# 4. Copy deployment files, setup, and launchers to root of package
Write-Host "Copying installer and launchers..."
Copy-Item -Path "d:\Hekal\deployment\*" -Destination "$packageDir\" -Recurse -Force

# Remove intermediate payload.zip from package to keep zip size optimal
if (Test-Path "$packageDir\payload.zip") {
    Remove-Item -Path "$packageDir\payload.zip" -Force
}
if (Test-Path "$packageDir\Setup.cs") {
    Remove-Item -Path "$packageDir\Setup.cs" -Force
}
if (Test-Path "$packageDir\Run_App.cs") {
    Remove-Item -Path "$packageDir\Run_App.cs" -Force
}

# 5. Compress package into ZIP using .NET ZipFile
Write-Host "Compressing package into ZIP..."
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
if (Test-Path $zipFile) { 
    Remove-Item -Path $zipFile -Force 
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $zipFile)

$zipSize = [math]::Round((Get-Item $zipFile).Length / 1MB, 2)
Write-Host "Package successfully created: $zipFile ($zipSize MB)"
