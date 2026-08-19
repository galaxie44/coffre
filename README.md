# Coffre

Gestionnaire de mots de passe **local** pour Windows et Android.  
Pas de compte, pas de cloud, pas de serveur à vous : les données restent chiffrées sur l’appareil.

Page de téléchargement : [galaxie44.github.io/coffre](https://galaxie44.github.io/coffre/)

## Télécharger

| Appareil | Fichier |
|----------|---------|
| **Windows** | [Coffre-Setup-Windows.exe](https://github.com/galaxie44/coffre/releases/latest/download/Coffre-Setup-Windows.exe) |
| **Android** | [Coffre.apk](https://github.com/galaxie44/coffre/releases/latest/download/Coffre.apk) |
| **Tout supprimer (Windows)** | [Coffre-Supprimer-Tout.exe](https://github.com/galaxie44/coffre/releases/latest/download/Coffre-Supprimer-Tout.exe) |

Toutes les versions : [Releases](https://github.com/galaxie44/coffre/releases).

## Installation

### Windows

1. Téléchargez `Coffre-Setup-Windows.exe`.
2. Double-cliquez → Installer (pas besoin d’administrateur).
3. Ouvrez Coffre depuis le Bureau ou le menu Démarrer.
4. Créez un **mot de passe maître** (12 caractères minimum). S’il est oublié, le coffre est irrécupérable.

### Android

1. Téléchargez `Coffre.apk` sur le téléphone.
2. Ouvrez le fichier et autorisez l’installation si Android le demande.
3. Créez le mot de passe maître.
4. **Paramètres → Activer le remplissage automatique** et choisissez Coffre.

## Utilisation

- **Liste** : recherchez un compte, touchez une ligne pour l’ouvrir, **Utiliser** pour copier l’identifiant puis le mot de passe.
- **Ajouter** : titre, identifiant, mot de passe, domaine du site (ex. `github.com`).
- **Windows — accès rapide** : `Ctrl+Shift+Espace` dans n’importe quelle app. Coffre doit rester déverrouillé.
- **Android — clavier** : touchez un champ de connexion ; une suggestion Coffre apparaît au-dessus du clavier.
- **Nouveaux comptes** : si vous créez un identifiant / mot de passe que Coffre ne connaît pas encore, l’app propose de l’enregistrer (ou de le mettre à jour).
- **2FA** : collez le secret TOTP (Base32) dans une entrée pour générer le code à 6 chiffres.
- **Santé du coffre** : mots de passe faibles, réutilisés ou anciens. Vérification des fuites (HIBP) optionnelle, désactivée par défaut.

Le presse-papier est effacé environ 30 secondes après la copie d’un secret.

## Mises à jour (Windows)

Quand une nouvelle version est publiée sur GitHub, Coffre **propose de l’installer à l’ouverture**.  
Le coffre local n’est pas modifié.

- **Installer** : télécharge `Coffre-Setup-Windows.exe` et lance la mise à jour.
- **Plus tard** : la même version ne sera plus proposée ; une version plus récente le sera.
- Vérification manuelle : **Paramètres → Mettre à jour Coffre**.

Les PC collègues voient la proposition dès qu’ils ouvrent Coffre, **à condition d’avoir déjà une version qui contient cette fonction**. La première installation se fait encore à la main (Setup). Ensuite, les Releases suffisent.

## Extension Chrome / Edge (Windows)

Coffre n’apparaît **pas** dans le menu « mots de passe Google ». Il faut l’extension du dossier `extension/`.

1. Coffre ouvert et déverrouillé.
2. `chrome://extensions` → Mode développeur → **Charger l’extension non empaquetée** → dossier `extension/`.
3. Copiez l’ID de l’extension, lancez `scripts\install_extension_host.bat`, collez l’ID.
4. Rechargez l’extension.

Dans Coffre : **Paramètres → Désactiver Google Password Manager**, puis fermez complètement Chrome.  
Détails : [extension/README.md](extension/README.md).

L’extension ne s’ouvre pas sur les champs de code (2FA, Authenticator, code appareil GitHub).

## Développement

Prérequis : Flutter, Visual Studio (C++ desktop) pour Windows, SDK Android pour l’APK.

```bat
cd apps\coffre
flutter pub get
flutter test
flutter run -d windows
```

Build installateurs (Windows + APK) :

```bat
scripts\package_release.bat
```

Fichiers produits : `dist\release\Coffre-Setup-Windows.exe` et `dist\release\Coffre.apk`.

### Publier une version pour les autres PC

1. Augmentez le numéro dans `apps/coffre/pubspec.yaml` (`1.0.1`, etc.) et `installer/windows/coffre.iss`.
2. Lancez `scripts\package_release.bat`.
3. Créez une [Release GitHub](https://github.com/galaxie44/coffre/releases/new) avec le tag `v1.0.1` et joignez les deux fichiers ci-dessus.
4. Les PC déjà à jour avec le système de mises à jour proposeront cette version à l’ouverture.

## Dossier du projet

| Chemin | Rôle |
|--------|------|
| `apps/coffre/` | Application Flutter (Windows + Android) |
| `extension/` | Extension Chrome / Edge |
| `installer/windows/` | Script Inno Setup |
| `scripts/` | Build, host d’extension, publication |
| `docs/` | Page de téléchargement GitHub Pages |
| `docs/SECURITY.md` | Modèle de menace |

## Sécurité

- Chiffrement local : **Argon2id** puis **AES-256-GCM**.
- Rien n’est envoyé dans un cloud Coffre. Les mises à jour Windows consultent uniquement l’API GitHub `releases/latest` et téléchargent l’installateur officiel du dépôt.
- Ne commitez jamais `vault.enc`, `*.pem` ni de clés.

Détail : [docs/SECURITY.md](docs/SECURITY.md).
