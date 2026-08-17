# Extension navigateur Coffre

## Important

Chrome **ne propose pas Coffre** dans son menu « Gestionnaire de mots de passe de Google ».
Ce menu est celui de Google. Coffre fonctionne via **son extension** :

1. Coffre ouvert et **déverrouillé**
2. Extension chargée dans Chrome/Edge
3. Host Native Messaging installé

Ensuite, cliquez un champ email / mot de passe → une liste **Coffre** apparaît pour choisir l’entrée (ou ouvrez le popup de l’extension).

Si vous **créez un compte** ou tapez une combinaison que Coffre ne connaît pas encore pour ce site, une barre propose **Enregistrer dans Coffre**. Même identifiant avec un mot de passe différent → **Mettre à jour**. Combinaison déjà enregistrée → rien.

## Installation

1. Lancez l’application Windows `Coffre` et déverrouillez le coffre.
2. Chrome ou Edge → `chrome://extensions` → Mode développeur → **Charger l’extension non empaquetée** → dossier `extension/`.
3. Copiez l’ID de l’extension.
4. Double-cliquez `scripts\install_extension_host.bat` et collez l’ID  
   (ou dans `extension/native_host/` : `install_host.bat <ID_EXTENSION>`).
5. Rechargez l’extension.

## URL à enregistrer dans Coffre

Le **domaine** suffit, par ex. `accounts.google.com` ou `https://accounts.google.com`.  
Inutile de coller toute l’URL Google avec `?continue=...`.

## Dépannage

| Message / symptôme | Cause probable |
|---|---|
| Menu Google uniquement | Extension non installée / non utilisée |
| « Bridge indisponible » | App fermée, verrouillée, ou host non installé |
| « Aucune entrée pour ce site » | Domaine de l’entrée ≠ domaine de la page |

Le host lit `%APPDATA%\Coffre\bridge.json` (écrit uniquement tant que l’app est déverrouillée).

## Désactiver le menu Google (obligatoire)

Chrome affiche **son** gestionnaire par-dessus Coffre. Une extension ne peut pas le cacher.

Dans Coffre : **Paramètres → Désactiver Google Password Manager**,  
puis **fermez toutes les fenêtres Chrome** et rouvrez-le.

Ou à la main : `chrome://password-manager/settings` → désactiver la saisie automatique des mots de passe et des clés d’accès.
