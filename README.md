# Coffre

Gestionnaire de mots de passe **100 % local** (Windows + Android). Pas de compte, pas de cloud.

## Télécharger

Un fichier à lancer, comme n’importe quelle app moderne :

| Appareil | Fichier |
|----------|---------|
| **PC Windows** | [Coffre-Setup-Windows.exe](https://github.com/galaxie44/coffre/releases/latest/download/Coffre-Setup-Windows.exe) |
| **Téléphone Android** | [Coffre.apk](https://github.com/galaxie44/coffre/releases/latest/download/Coffre.apk) |

Page de téléchargement : [galaxie44.github.io/coffre](https://galaxie44.github.io/coffre/)

### Windows

1. Téléchargez `Coffre-Setup-Windows.exe`.
2. Double-cliquez → Installer.
3. Coffre s’ouvre depuis le Bureau / le menu Démarrer.

### Android

1. Téléchargez `Coffre.apk` sur le téléphone.
2. Ouvrez le fichier → autorisez l’installation si Android le demande.
3. Dans Coffre : **Paramètres → Activer le remplissage automatique**.

Les versions se trouvent toujours dans [Releases](https://github.com/galaxie44/coffre/releases).

## Fonctions

- Coffre chiffré local (Argon2id → AES-256-GCM)
- Accès rapide Windows `Ctrl+Shift+C`
- Remplissage automatique Android (clavier)
- Proposition d’enregistrement à l’inscription
- Extension Chrome / Edge
- Audit, TOTP, fuites HIBP (opt-in)

## Développement

```bat
cd apps\coffre
flutter pub get
flutter test
flutter run -d windows
```

Installer de release en local :

```bat
scripts\package_release.bat
```

Produit `dist\release\Coffre-Setup-Windows.exe` et `dist\release\Coffre.apk`.

## Architecture

| Chemin | Rôle |
|--------|------|
| `apps/coffre/` | Application Flutter |
| `extension/` | Extension navigateur |
| `installer/windows/` | Script Inno Setup |
| `docs/` | Page de téléchargement |
| `docs/SECURITY.md` | Modèle de menace |

## Sécurité

Détails : [docs/SECURITY.md](docs/SECURITY.md). Ne commitez jamais `vault.enc` ni de clés privées.
