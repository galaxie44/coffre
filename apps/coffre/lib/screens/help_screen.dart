import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _HelpSection(
            title: 'Qu’est-ce que Coffre ?',
            body:
                'Coffre stocke vos mots de passe localement, chiffrés avec votre mot de passe maître. Il n’y a pas de compte cloud ni de synchronisation en V1 : chaque appareil a son propre coffre.',
          ),
          const _HelpSection(
            title: 'Mot de passe maître',
            body:
                'Il déverrouille le coffre. Minimum 12 caractères. S’il est oublié, les données sont irrécupérables — c’est volontaire pour la sécurité.',
          ),
          const _HelpSection(
            title: 'Ajouter une entrée',
            body:
                'Titre, identifiant, mot de passe. Pour le web : domaine (ex. accounts.google.com). Android : package ou puce rapide (Gmail, Steam…). Windows : steam.exe + titre fenêtre pour l’accès rapide.',
          ),
          if (Platform.isWindows)
            const _HelpSection(
              title: 'Apps Windows (Steam, Discord…)',
              body:
                  'Gardez Coffre déverrouillé. Ctrl+Shift+C : touchez une ligne — l’identifiant est copié, puis le mot de passe arrive dans le presse-papier après votre Ctrl+V. Effacement auto après 30 s. Renseignez « steam.exe » sur l’entrée Steam pour la voir en premier.',
            ),
          if (Platform.isAndroid) ...[
            const _HelpSection(
              title: 'Remplir un login (clavier)',
              body:
                  'C’est l’équivalent de Ctrl+Shift+C sur téléphone. Paramètres Coffre → Activer le remplissage automatique → choisissez Coffre. Ouvrez Chrome ou une app, touchez le champ identifiant : une suggestion Coffre apparaît au-dessus du clavier. Un tap remplit identifiant et mot de passe. Le coffre doit être déverrouillé ; il reste ouvert le temps du verrouillage automatique (Paramètres).',
            ),
            const _HelpSection(
              title: 'Enregistrer un nouveau compte',
              body:
                  'Comme Google : si vous créez un compte ou tapez un identifiant / mot de passe que Coffre ne connaît pas encore pour ce site, Android propose d’enregistrer. Même identifiant avec un nouveau mot de passe → mise à jour. Combinaison déjà dans le coffre → aucune proposition. Coffre doit être le service de saisie automatique et rester déverrouillé.',
            ),
            const _HelpSection(
              title: 'Accès rapide dans Coffre',
              body:
                  'Icône éclair en haut de l’accueil. Recherchez, cochez un filtre si le même e-mail apparaît plusieurs fois, puis Utiliser. L’identifiant est copié. Collez-le dans l’autre app, revenez (ou restez) et touchez « Mot de passe » sur le bandeau teal. Appui long sur une ligne de la liste = même action. Le menu ⋮ copie identifiant ou mot de passe seul.',
            ),
            const _HelpSection(
              title: 'Filtres',
              body:
                  'Si un identifiant, un site ou un domaine e-mail apparaît au moins deux fois, le bouton Filtres s’affiche. Cochez les cases dans la feuille du bas ; les filtres actifs restent visibles sous la recherche.',
            ),
            const _HelpSection(
              title: 'Importer Chrome',
              body:
                  'Sur Android, Google n’autorise pas la lecture directe du coffre Chrome. Exportez un CSV depuis Google Password Manager, puis Paramètres Coffre → Importer depuis Chrome → Choisir le fichier CSV. Les doublons (même site + identifiant) sont ignorés.',
            ),
          ],
          const _HelpSection(
            title: 'Biométrie / Windows Hello',
            body:
                'Dans Paramètres, activez le déverrouillage secondaire. Le mot de passe maître reste obligatoire pour la création du coffre et la zone danger.',
          ),
          if (Platform.isWindows) ...[
            const _HelpSection(
              title: 'Importer Chrome',
              body:
                  'Paramètres → Importer maintenant depuis Chrome. Optionnel : « Importer Chrome à l’ouverture » pour ajouter uniquement les nouveaux (doublons ignorés). Fermez Chrome si la lecture échoue.',
            ),
            const _HelpSection(
              title: 'Remplissage navigateur (Windows)',
              body:
                  'Extension Coffre (recharger après mise à jour). Le menu Google n’est pas Coffre : Paramètres Coffre → « Désactiver Google Password Manager », puis fermez complètement Chrome. Cliquez ensuite un champ : la liste teal Coffre s’affiche. Si vous vous inscrivez ou tapez un nouveau couple identifiant / mot de passe, une barre Coffre propose d’enregistrer (ou de mettre à jour). Une combinaison déjà connue n’est pas reproposée.',
            ),
          ],
          const _HelpSection(
            title: '2FA / TOTP',
            body:
                'Ajoutez le secret Base32 dans une entrée pour générer des codes à 6 chiffres localement (Steam Guard, Google Authenticator…).',
          ),
          const _HelpSection(
            title: 'Santé du coffre',
            body:
                'Détecte mots de passe faibles, réutilisés ou anciens. Vérification fuites HIBP optionnelle (Internet, k-anonymity).',
          ),
          const _HelpSection(
            title: 'Presse-papier',
            body:
                'La copie d’un secret est effacée automatiquement après environ 30 secondes.',
          ),
          const _HelpSection(
            title: 'Zone danger',
            body:
                'Efface le coffre (écrasement puis suppression). Irréversible.',
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.tealDark,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: AppTheme.ink.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}
