@echo off
setlocal
echo ============================================
echo  Coffre - Preparation lancement PC/Android
echo ============================================
echo.
echo 1) Activez le MODE DEVELOPPEUR Windows
echo    (obligatoire pour construire l'app)
echo.
start ms-settings:developers
echo.
echo Une fenetre Parametres s'est ouverte.
echo Activez "Mode developpeur", puis appuyez sur une touche ici...
pause

echo.
echo 2) Build Windows + raccourci Bureau...
call "%~dp0build_windows.bat"
if errorlevel 1 (
  echo Echec Windows.
  pause
  exit /b 1
)

echo.
echo 3) Build APK Android...
call "%~dp0build_android.bat"
if errorlevel 1 (
  echo.
  echo APK non construit. Ouvrez Android Studio une fois pour finir le SDK,
  echo puis relancez scripts\build_android.bat
)

echo.
echo Termine.
echo - PC : raccourci "Coffre" sur le Bureau
echo - Android : fichier dist\android\Coffre.apk a installer sur le telephone
pause
endlocal
