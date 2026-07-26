@echo off
setlocal
 title Twisted Computing Tech Utility
 echo Launching Twisted Computing Tech Utility...
 powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { irm 'https://raw.githubusercontent.com/jasonpsu97/TCTech-Utility/main/winutil.ps1' | iex } catch { Write-Host ''; Write-Host 'Unable to launch the utility:' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; Write-Host ''; Read-Host 'Press ENTER to close' }"
