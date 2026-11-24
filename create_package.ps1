$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$sourceDir = "d:\Hekal\build\windows\x64\runner\Release"
$packageDir = "d:\Hekal\Hekal_Garage_Package"
$zipFile = "d:\Hekal\Hekal_Garage_ERP_v1.0.zip"

Write-Host "Creating package folder..."
if (Test-Path $packageDir) { Remove-Item -Path $packageDir -Recurse -Force }
New-Item -ItemType Directory -Path "$packageDir\App" -Force | Out-Null

Write-Host "Copying application release files..."
Copy-Item -Path "$sourceDir\*" -Destination "$packageDir\App" -Recurse -Force

Write-Host "Copying installer and launcher scripts..."
Copy-Item -Path "d:\Hekal\deployment\*" -Destination "$packageDir\" -Recurse -Force

Write-Host "Compressing package into ZIP..."
if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force }
Compress-Archive -Path "$packageDir\*" -DestinationPath $zipFile -Force

Write-Host "Package successfully created: $zipFile"
