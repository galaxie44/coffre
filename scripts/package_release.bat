@echo off
setlocal EnableExtensions
REM Construit l'installateur Windows + l'APK, copies dans dist\release
set ROOT=C:\Dev\Coffre
set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
set FLUTTER=%USERPROFILE%\flutter\bin\flutter.bat

echo === Sync vers C:\Dev\Coffre ===
robocopy "%~dp0.." "%ROOT%" /E /XD build .dart_tool .idea .gradle dist .git installer\windows\Output ephemeral .plugin_symlinks /NFL /NDL /NJH /NJS /nc /ns /np >nul
if exist "%ROOT%\apps\coffre\windows\flutter\ephemeral" rmdir /s /q "%ROOT%\apps\coffre\windows\flutter\ephemeral"

echo === Build Windows ===
cd /d "%ROOT%\apps\coffre"
call "%FLUTTER%" pub get
if errorlevel 1 exit /b 1
call "%FLUTTER%" build windows --release
if errorlevel 1 exit /b 1

if exist "%ROOT%\installer\payload" rmdir /s /q "%ROOT%\installer\payload"
mkdir "%ROOT%\installer\payload"
robocopy "%ROOT%\apps\coffre\build\windows\x64\runner\Release" "%ROOT%\installer\payload" /E /NFL /NDL /NJH /NJS /nc /ns /np
if exist "%ROOT%\apps\coffre\assets\icon\coffre.ico" copy /Y "%ROOT%\apps\coffre\assets\icon\coffre.ico" "%ROOT%\installer\payload\Coffre.ico" >nul

echo === Installateur Inno Setup ===
if not exist %ISCC% (
  echo Inno Setup introuvable. Installez-le puis relancez.
  echo winget install JRSoftware.InnoSetup
  exit /b 1
)
%ISCC% "%ROOT%\installer\windows\coffre.iss"
if errorlevel 1 exit /b 1
%ISCC% "%ROOT%\installer\windows\coffre_wipe.iss"
if errorlevel 1 exit /b 1

echo === Build APK Android ===
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set ANDROID_SDK_ROOT=%ANDROID_HOME%
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
call "%FLUTTER%" build apk --release
if errorlevel 1 exit /b 1

if not exist "%ROOT%\dist\android" mkdir "%ROOT%\dist\android"
copy /Y "%ROOT%\apps\coffre\build\app\outputs\flutter-apk\app-release.apk" "%ROOT%\dist\android\Coffre.apk" >nul

if not exist "%ROOT%\dist\release" mkdir "%ROOT%\dist\release"
copy /Y "%ROOT%\installer\windows\Output\Coffre-Setup-Windows.exe" "%ROOT%\dist\release\" >nul
copy /Y "%ROOT%\installer\windows\Output\Coffre-Supprimer-Tout.exe" "%ROOT%\dist\release\" >nul
copy /Y "%ROOT%\dist\android\Coffre.apk" "%ROOT%\dist\release\Coffre.apk" >nul

if not exist "%~dp0..\dist\release" mkdir "%~dp0..\dist\release"
xcopy /Y "%ROOT%\dist\release\*" "%~dp0..\dist\release\" >nul

echo.
echo OK
echo  Windows : %ROOT%\dist\release\Coffre-Setup-Windows.exe
echo  Wipe    : %ROOT%\dist\release\Coffre-Supprimer-Tout.exe
echo  Android : %ROOT%\dist\release\Coffre.apk
endlocal
