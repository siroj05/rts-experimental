@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uji-bukit.ps1" -Hijau
if errorlevel 1 pause
