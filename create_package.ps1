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
Copy-Item -Path "d:\Hekal\deployment\Install.bat" -Destination "$packageDir\" -Force
Copy-Item -Path "d:\Hekal\deployment\install.ps1" -Destination "$packageDir\" -Force
Copy-Item -Path "d:\Hekal\deployment\Run_App.bat" -Destination "$packageDir\" -Force
Copy-Item -Path "d:\Hekal\deployment\دليل_الربط_والتثبيت.txt" -Destination "$packageDir\" -Force

Write-Host "Compressing package into ZIP..."
if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force }
Compress-Archive -Path "$packageDir\*" -DestinationPath $zipFile -Force

Write-Host "Package successfully created: $zipFile"
