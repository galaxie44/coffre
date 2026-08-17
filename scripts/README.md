# Build & install Coffre (Windows + Android)

## Prérequis (une fois)

1. **Mode développeur Windows** (symlinks Flutter)  
   `start ms-settings:developers` → activer *Mode développeur*

2. **Visual Studio Build Tools 2022** avec la charge de travail  
   *Développement Desktop en C++*

3. **Android Studio** (ou SDK Android) + un téléphone en mode développeur / USB,  
   **ou** un émulateur.

Les scripts ci-dessous tentent d’installer / builder automatiquement.

## Windows — exe + raccourci Bureau

```bat
scripts\build_windows.bat
```

Produit :
- `dist\windows\Coffre\Coffre.exe`
- Raccourci **Coffre** sur le Bureau

## Android — APK installable

```bat
scripts\build_android.bat
```

Produit :
- `dist\android\Coffre.apk`

Puis sur le téléphone : copier l’APK → ouvrir → Autoriser l’installation → Installer → icône **Coffre** sur l’écran d’accueil.
