@echo off
REM ubah path ke lokasi file PS1 
set "SCRIPT_PATH=D:\test_rename\tes_rename.ps1"

if not exist "%SCRIPT_PATH%" (
  echo ERROR: File %SCRIPT_PATH% tidak ditemukan.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
pause
