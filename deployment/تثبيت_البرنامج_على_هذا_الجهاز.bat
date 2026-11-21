@echo off
chcp 65001 >nul
title تثبيت برنامج مركز هيكل لإصلاح السيارات
echo ======================================================================
echo         تثبيت برنامج مركز هيكل لإصلاح السيارات - الإصدار 1.0
echo ======================================================================
echo.

set "TARGET_DIR=C:\HekalGarage"

echo [1/3] جاري نسخ ملفات البرنامج إلى %TARGET_DIR%...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
xcopy /E /I /Y "%~dp0App\*" "%TARGET_DIR%\" >nul
if %errorlevel% neq 0 (
    echo [خطأ] تعذر نسخ الملفات، يرجى تشغيل الملف كمسؤول (Run as Administrator).
    pause
    exit /b 1
)

echo [2/3] جاري إنشاء اختصار البرنامج على سطح المكتب...
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut([System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), 'مركز هيكل لإصلاح السيارات.lnk')); $s.TargetPath = '%TARGET_DIR%\garage_erp.exe'; $s.WorkingDirectory = '%TARGET_DIR%'; $s.Save()"

echo [3/3] جاري ضبط جدار الحماية (Windows Firewall) للسماح بربط الأجهزة...
netsh advfirewall firewall add rule name="Hekal Garage ERP LAN" dir=in action=allow protocol=TCP localport=4455 >nul 2>&1

echo.
echo ======================================================================
echo    تم تثبيت البرنامج بنجاح! تم إنشاء اختصار على سطح المكتب.
echo ======================================================================
echo.
echo للتشغيل الآن، اضغط أي مفتاح...
pause >nul
start "" "%TARGET_DIR%\garage_erp.exe"

