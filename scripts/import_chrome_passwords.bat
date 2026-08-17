@echo off
setlocal
echo === Import mots de passe Google Chrome vers Coffre ===
python "%~dp0import_chrome_passwords.py"
if errorlevel 1 (
  echo.
  echo Echec. Fermez Chrome completement et relancez.
  pause
  exit /b 1
)
echo.
echo Ouvrez Coffre (deverrouille) : l'import sera propose automatiquement.
echo Ou : Parametres ^> Importer depuis Chrome
pause
endlocal
