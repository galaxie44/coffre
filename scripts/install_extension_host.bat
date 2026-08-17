@echo off
setlocal EnableExtensions
cd /d "%~dp0..\extension\native_host"

echo ========================================
echo  Coffre - Host Native Messaging Chrome
echo ========================================
echo.
echo 1. Ouvrez Chrome : chrome://extensions
echo 2. Activez "Mode developpeur"
echo 3. "Charger l'extension non empaquetee"
echo 4. Selectionnez le dossier :
echo    %~dp0..\extension
echo 5. Copiez l'ID de l'extension (long code sous le nom Coffre)
echo.
set /p EXT_ID=Collez l'ID ici puis Entree : 
if "%EXT_ID%"=="" (
  echo ID manquant.
  exit /b 1
)

python "%~dp0..\extension\native_host\install_host.py" %EXT_ID%
if errorlevel 1 (
  echo Echec installation host.
  exit /b 1
)

echo.
echo OK. Rechargez l'extension dans Chrome, gardez Coffre deverrouille,
echo puis cliquez un champ email/mot de passe sur un site de login.
echo.
pause
endlocal
