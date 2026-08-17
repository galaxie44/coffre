# Sécurité — Coffre

## Modèle de menace

Coffre protège un coffre **local** contre :

- lecture du fichier au repos sans le mot de passe maître ;
- fuite accidentelle via presse-papier (effacement après 30 s) ;
- capture d'écran Android (`FLAG_SECURE`) ;
- accès autofill / extension lorsque le coffre est verrouillé ;
- matching autofill trop large (package/domaine strict uniquement) ;
- downgrade des paramètres Argon2id dans l'enveloppe.

Coffre **ne protège pas** contre :

- malware avec droits de l'utilisateur sur une session déjà déverrouillée ;
- keyloggers pendant la saisie du mot de passe maître ;
- oubli du mot de passe maître (aucune récupération) ;
- effacement physique parfait sur SSD (limites FTL / wear-leveling).

## Format `vault.enc`

Enveloppe JSON :

| Champ | Rôle |
|-------|------|
| `version` | `1` |
| `kdf` | `argon2id` |
| `memory` / `iterations` / `parallelism` | paramètres Argon2id (plancher anti-downgrade : 65536 / 3 / 1) |
| `salt` | 16 octets (base64) |
| `nonce` | nonce AES-GCM (base64) |
| `mac` | tag GCM (base64) |
| `ciphertext` | payload JSON chiffré (base64) |

Écriture atomique via fichier `.tmp` puis rename.

## Session Android Autofill

Fichier `autofill_session.enc` chiffré **AES-256-GCM** avec une clé dans **Android Keystore** (`coffre_autofill_session_v1`).

- Flutter écrit via MethodChannel `writeSession` (jamais de JSON clair sur disque).
- `CoffreAutofillService` déchiffre via la même clé Keystore.
- Au verrouillage / wipe : overwrite + suppression + purge de l’ancien `autofill_session.json` legacy.

Matching autorisé uniquement :

- égalité stricte du package Android, ou
- domaine de la page égal / sous-domaine du domaine stocké.

## Biométrie / Windows Hello

Déverrouillage **secondaire** :

1. L’utilisateur active l’option dans Paramètres (coffre déjà déverrouillé).
2. Authentification biométrique OS.
3. Le mot de passe maître est envelopé dans `flutter_secure_storage` (Keystore / DPAPI).
4. Au prochain unlock : biométrie → lecture du secret → déchiffrement du coffre.

La zone danger et la création du coffre exigent toujours le mot de passe maître. Wipe efface aussi le secret biométrique.

## Bridge Windows (extension)

HTTP `127.0.0.1` + jeton Bearer dans `%APPDATA%\Coffre\bridge.json`, présent seulement si déverrouillé.

Endpoints : `/credentials?domain=` (par site), `/entries` (toutes les entrées pour e-mail).

## Accès rapide Windows

Raccourci `Ctrl+Shift+C` : overlay always-on-top, matching `windowsProcess` / `windowsTitleHint`.
Collage clavier opt-in via Paramètres. Tout processus utilisateur peut lire le bridge pendant la session.

## Wipe (zone danger)

1. Double confirmation UI + mot de passe maître.
2. Overwrite aléatoire du cache autofill et du coffre, puis suppression.
3. Tentative de désinstallation Android via `ACTION_DELETE`.
4. Windows : désinstallation manuelle guidée.

## Mises à jour (Windows)

Coffre interroge `https://api.github.com/repos/galaxie44/coffre/releases/latest` à l’ouverture.

- Le téléchargement n’est proposé que si l’URL est GitHub (`galaxie44/coffre` ou `*.githubusercontent.com`).
- L’installateur est lancé après accord de l’utilisateur.
- Le fichier `vault.enc` n’est pas dans le dossier d’installation ; une mise à jour ne l’écrase pas.

## Revue sécurité (post-implémentation)

Contrôles effectués :

- [x] Pas de secrets hardcodés dans le dépôt
- [x] Crypto au repos Argon2id + AES-GCM
- [x] `allowBackup=false` Android
- [x] Session autofill chiffrée Android Keystore (AES-GCM)
- [x] Biométrie / Windows Hello secondaire + wipe du secret
- [x] Suppression du match flou par titre (autofill)
- [x] Match domaine unidirectionnel
- [x] Backoff après échecs de déverrouillage
- [x] Revalidation domaine côté extension avant fill
- [x] Permissions extension réduites (plus de `storage` / host localhost inutiles)
