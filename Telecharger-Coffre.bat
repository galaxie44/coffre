@echo off
setlocal EnableExtensions
REM Telecharge et lance le dernier installateur Coffre (Windows).
set "URL=https://github.com/galaxie44/coffre/releases/latest/download/Coffre-Setup-Windows.exe"
set "OUT=%TEMP%\Coffre-Setup-Windows.exe"

echo Coffre — telechargement de l'installateur...
curl.exe -L --fail --retry 3 -o "%OUT%" "%URL%"
if errorlevel 1 (
  echo Echec du telechargement. Ouvrez :
  echo https://github.com/galaxie44/coffre/releases/latest
  pause
  exit /b 1
)

echo Lancement de l'installateur...
start "" "%OUT%"
endlocal
