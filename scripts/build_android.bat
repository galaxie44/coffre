@echo off
setlocal EnableExtensions
REM Build depuis un chemin ASCII (evite le bug accents Windows/Android)
set ROOT=C:\Dev\Coffre
set APP=%ROOT%\apps\coffre
set DIST=%ROOT%\dist\android
set FLUTTER=%USERPROFILE%\flutter\bin\flutter.bat
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set ANDROID_SDK_ROOT=%ANDROID_HOME%
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

echo === Sync projet vers C:\Dev\Coffre ===
robocopy "%~dp0.." "%ROOT%" /E /XD build .dart_tool .idea .gradle dist /NFL /NDL /NJH /NJS /nc /ns /np >nul

echo === Coffre : build APK Android ===
cd /d "%APP%"
call "%FLUTTER%" pub get
if errorlevel 1 exit /b 1

call "%FLUTTER%" build apk --release
if errorlevel 1 (
  echo Echec build APK
  exit /b 1
)

if not exist "%DIST%" mkdir "%DIST%"
copy /Y "%APP%\build\app\outputs\flutter-apk\app-release.apk" "%DIST%\Coffre.apk" >nul
if not exist "%~dp0..\dist\android" mkdir "%~dp0..\dist\android"
copy /Y "%DIST%\Coffre.apk" "%~dp0..\dist\android\Coffre.apk" >nul
copy /Y "%DIST%\Coffre.apk" "%USERPROFILE%\Desktop\Coffre.apk" >nul

echo.
echo OK - APK: %USERPROFILE%\Desktop\Coffre.apk
echo Copiez ce fichier sur le telephone, ouvrez-le et installez.
echo L'icone Coffre apparaitra sur l'ecran d'accueil.
endlocal
