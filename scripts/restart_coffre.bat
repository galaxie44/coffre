@echo off
setlocal
echo Arret de toutes les instances Coffre...
taskkill /IM coffre.exe /F >nul 2>&1
timeout /t 1 /nobreak >nul

echo Build...
call "%~dp0build_windows.bat"
if errorlevel 1 exit /b 1

echo Lancement...
start "" "C:\Dev\Coffre\dist\windows\Coffre\coffre.exe"
echo OK - Nouvelle version lancee.
endlocal
