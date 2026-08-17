@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

where gh >nul 2>&1
if errorlevel 1 (
  echo Installez GitHub CLI : winget install GitHub.cli
  exit /b 1
)

gh auth status >nul 2>&1
if errorlevel 1 (
  echo Connexion GitHub requise...
  gh auth login --hostname github.com --git-protocol https --web
  if errorlevel 1 exit /b 1
)

gh repo view galaxie44/coffre >nul 2>&1
if errorlevel 1 (
  gh repo create coffre --public --source=. --remote=origin --push --description "Gestionnaire de mots de passe local (Windows + Android)"
) else (
  git push -u origin main
)

if not exist "dist\release\Coffre-Setup-Windows.exe" (
  echo Fichiers de release introuvables. Lancez d'abord scripts\package_release.bat
  exit /b 1
)

gh release view v1.0.0 >nul 2>&1
if errorlevel 1 (
  gh release create v1.0.0 --title "Coffre 1.0.0" --notes "## Telechargement^

- Windows : lancez Coffre-Setup-Windows.exe^
- Android : ouvrez Coffre.apk sur le telephone" "dist\release\Coffre-Setup-Windows.exe" "dist\release\Coffre.apk"
) else (
  gh release upload v1.0.0 "dist\release\Coffre-Setup-Windows.exe" "dist\release\Coffre.apk" --clobber
)

echo.
echo Depot : https://github.com/galaxie44/coffre
echo Release : https://github.com/galaxie44/coffre/releases/latest
endlocal
