@echo off
chcp 65001 >nul
title تجهيز حزمة التثبيت لبرنامج مركز هيكل
echo جاري تجهيز حزمة التوزيع وضغطها إلى ZIP...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create_package.ps1"
echo.
pause
