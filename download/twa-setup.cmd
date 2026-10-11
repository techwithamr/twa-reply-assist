@echo off
setlocal
title TWA Reply Assist Setup
cd /d "%~dp0"
if exist "%~dp0..\release\one-click-setup.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\release\one-click-setup.ps1" -ReleaseDir "%~dp0..\release"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\one-click-setup.ps1"
)
if errorlevel 1 (
  echo.
  echo Setup failed. Press any key to close.
  pause >nul
  exit /b 1
)
echo.
echo Setup finished. Press any key to close.
pause >nul
