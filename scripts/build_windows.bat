@echo off
setlocal EnableExtensions
set ROOT=C:\Dev\Coffre
set APP=%ROOT%\apps\coffre
set DIST=%ROOT%\dist\windows\Coffre
set DESKTOP=%USERPROFILE%\Desktop
set FLUTTER=%USERPROFILE%\flutter\bin\flutter.bat

echo === Sync projet vers C:\Dev\Coffre ===
robocopy "%~dp0.." "%ROOT%" /E /XD build .dart_tool .idea .gradle dist /NFL /NDL /NJH /NJS /nc /ns /np >nul

echo === Coffre : build Windows ===
cd /d "%APP%"
call "%FLUTTER%" pub get
if errorlevel 1 exit /b 1

call "%FLUTTER%" build windows --release
if errorlevel 1 (
  echo.
  echo Echec du build Windows.
  echo Cause frequente: Mode developpeur Windows desactive (symlinks).
  echo Ouvrez Parametres ^> Mode developpeur, activez-le, puis relancez.
  start ms-settings:developers
  exit /b 1
)

if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%" 2>nul
xcopy /E /I /Y "%APP%\build\windows\x64\runner\Release\*" "%DIST%\" >nul
if exist "%APP%\assets\icon\coffre.ico" copy /Y "%APP%\assets\icon\coffre.ico" "%DIST%\Coffre.ico" >nul

REM Copie aussi vers le dossier projet original
if not exist "%~dp0..\dist\windows\Coffre" mkdir "%~dp0..\dist\windows\Coffre"
xcopy /E /I /Y "%DIST%\*" "%~dp0..\dist\windows\Coffre\" >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create_desktop_shortcut.ps1" -ExePath "%DIST%\coffre.exe" -IconPath "%DIST%\Coffre.ico"
if errorlevel 1 exit /b 1

echo.
echo OK - Application: %DIST%\coffre.exe
echo OK - Raccourci Bureau: Coffre.lnk
endlocal
