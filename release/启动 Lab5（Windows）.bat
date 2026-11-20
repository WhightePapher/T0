@echo off
chcp 936 >nul
cd /d "%~dp0Windows"
if not exist "Lab5办公.exe" (
  echo [x] 找不到 Windows\Lab5办公.exe
  pause
  exit /b 1
)
start "" "Lab5办公.exe"
