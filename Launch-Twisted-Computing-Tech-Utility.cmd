@echo off
setlocal
set "LAUNCHER=%~dp0Launch-TCTech-Utility.ps1"
if not exist "%LAUNCHER%" (
  echo Launch-TCTech-Utility.ps1 was not found beside this file.
  echo Extract the entire ZIP before launching.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LAUNCHER%"
endlocal
exit /b 0
