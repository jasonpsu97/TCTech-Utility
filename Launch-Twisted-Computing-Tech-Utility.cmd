@echo off
setlocal

title Twisted Computing Tech Utility
echo Launching Twisted Computing Tech Utility...

set "SCRIPT=%~dp0winutil.ps1"

if not exist "%SCRIPT%" (
    echo.
    echo Unable to launch the utility:
    echo winutil.ps1 was not found beside this launcher.
    echo.
    echo Keep this CMD file in the extracted TCTech Utility folder.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo The utility closed with an error.
    echo Review the message above, then press ENTER to close.
    pause >nul
)

endlocal
