@echo off
chcp 936 >nul
cd /d "%~dp0Web"
set "PY=C:\Users\98343\AppData\Local\hermes\installs\ad722f740750bddf\environments\fc96b714acd94d169a3f67a4bebc2fff\venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"
"%PY%" serve.py
if errorlevel 1 pause
