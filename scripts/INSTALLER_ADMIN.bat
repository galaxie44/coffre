@echo off
:: Demande les droits admin, active le Mode developpeur, puis build PC + Android
net session >nul 2>&1
if %errorLevel% NEQ 0 (
  echo Demande des droits administrateur...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo Activation Mode developpeur...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f >nul
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f >nul

set ROOT=%~dp0..
call "%ROOT%\scripts\build_windows.bat"
call "%ROOT%\scripts\build_android.bat"
echo.
echo Termine. Raccourci Bureau + APK dans dist\android\
pause
