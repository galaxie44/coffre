import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const _guideUrl = 'https://galaxie44.github.io/coffre/aide.html';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _openGuideOnline() async {
    final uri = Uri.parse(_guideUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Impossible d’ouvrir le guide en ligne.';
    }
  }

  List<_HelpStepData> _installSteps() {
    if (Platform.isAndroid) {
      return const [
        _HelpStepData('Téléchargez Coffre.apk', 'Depuis galaxie44.github.io/coffre ou GitHub Releases.'),
        _HelpStepData('Installez l’application', 'Ouvrez l’APK et autorisez l’installation si Android le demande.'),
        _HelpStepData('Créez le mot de passe maître', '12 caractères minimum. S’il est perdu, le coffre est irrécupérable.'),
        _HelpStepData('Activez le remplissage auto', 'Paramètres → Activer le remplissage automatique → choisissez Coffre.'),
        _HelpStepData('Connectez-vous', 'Touchez un champ identifiant : suggestion Coffre au-dessus du clavier.'),
      ];
    }
    if (Platform.isMacOS) {
      return const [
        _HelpStepData('Téléchargez Coffre-macOS.zip', 'Page galaxie44.github.io/coffre → section macOS.'),
        _HelpStepData('Décompressez Coffre.app', 'Glissez-le dans Applications si vous le souhaitez.'),
        _HelpStepData('Première ouverture', 'Clic droit → Ouvrir si macOS bloque l’app non signée.'),
        _HelpStepData('Créez le mot de passe maître', '12 caractères minimum. Données 100 % locales et chiffrées.'),
        _HelpStepData('Ajoutez vos comptes', 'Bouton + Ajouter : titre, identifiant, mot de passe, site.'),
      ];
    }
    if (Platform.isLinux) {
      return const [
        _HelpStepData('Téléchargez Coffre-Linux-x64.tar.gz', 'Page galaxie44.github.io/coffre → section Linux.'),
        _HelpStepData('Extrayez l’archive', 'tar -xzf Coffre-Linux-x64.tar.gz puis ./coffre'),
        _HelpStepData('Créez le mot de passe maître', '12 caractères minimum. Données 100 % locales et chiffrées.'),
        _HelpStepData('Ajoutez vos comptes', 'Bouton + Ajouter : titre, identifiant, mot de passe, site.'),
        _HelpStepData('Raccourci (optionnel)', 'Créez un lanceur .desktop vers le binaire coffre.'),
      ];
    }
    return const [
      _HelpStepData('Téléchargez l’installateur', 'Coffre-Setup-Windows.exe depuis galaxie44.github.io/coffre.'),
      _HelpStepData('Installez Coffre', 'Double-clic → Installer. Raccourci Bureau + menu Démarrer.'),
      _HelpStepData('Créez le mot de passe maître', '12 caractères minimum. S’il est perdu, le coffre est irrécupérable.'),
      _HelpStepData('Ajoutez vos comptes', 'Bouton + Ajouter : titre, identifiant, mot de passe, domaine du site.'),
      _HelpStepData('Remplissez vos apps', 'Ctrl+Shift+Espace (accès rapide) ou extension Chrome pour le web.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final installSteps = _installSteps();

    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            elevation: 0,
            color: AppTheme.teal.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppTheme.teal.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guide pas à pas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.tealDark,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suivez les étapes ci-dessous pour installer et utiliser Coffre sur cet appareil.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _openGuideOnline();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Guide complet avec visuels'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Installation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.tealDark,
                ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < installSteps.length; i++)
            _HelpStep(number: i + 1, data: installSteps[i]),
          const SizedBox(height: 12),
          Text(
            'Utilisation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.tealDark,
                ),
          ),
          const SizedBox(height: 8),
          const _HelpSection(
            title: 'Qu’est-ce que Coffre ?',
            body:
                'Coffre stocke vos mots de passe localement, chiffrés avec votre mot de passe maître. Pas de compte cloud : chaque appareil a son propre coffre.',
          ),
          const _HelpSection(
            title: 'Liste des comptes',
            body:
                'Les comptes sont triés par ordre alphabétique. Recherchez, touchez une ligne pour ouvrir, Utiliser pour copier identifiant puis mot de passe.',
          ),
          if (Platform.isWindows)
            const _HelpSection(
              title: 'Apps Windows (Steam, Discord…)',
              body:
                  'Gardez Coffre déverrouillé. Ctrl+Shift+Espace : touchez une ligne — l’identifiant est copié, puis le mot de passe après Ctrl+V. Effacement auto après 30 s.',
            ),
          if (Platform.isAndroid) ...[
            const _HelpSection(
              title: 'Remplir un login (clavier)',
              body:
                  'Paramètres → Activer le remplissage automatique → Coffre. Touchez un champ identifiant : suggestion au-dessus du clavier.',
            ),
            const _HelpSection(
              title: 'Enregistrer un nouveau compte',
              body:
                  'Si vous créez un compte inconnu de Coffre, Android propose de l’enregistrer. Même identifiant + nouveau mot de passe → mise à jour.',
            ),
          ],
          const _HelpSection(
            title: 'Mises à jour',
            body: Platform.isAndroid
                ? 'Paramètres → Rechercher les mises à jour. À partir de la 1.0.10, les APK sont signés de façon stable. Si Android affiche un conflit de package, désinstallez Coffre une fois puis réinstallez depuis le site (vos données locales seront effacées).'
                : 'Coffre vérifie GitHub à l’ouverture et propose d’installer la nouvelle version. Installez par-dessus : le coffre chiffré n’est pas modifié.',
          ),
          if (Platform.isWindows) ...[
            const _HelpSection(
              title: 'Extension navigateur',
              body:
                  'Installez l’extension Coffre. Paramètres → Désactiver Google Password Manager si besoin. Cliquez un champ : menu Comptes Coffre (tri A→Z).',
            ),
            const _HelpSection(
              title: 'Importer Chrome',
              body:
                  'Paramètres → Importer depuis Chrome. Option « Importer à l’ouverture » pour les nouveaux uniquement.',
            ),
          ],
          const _HelpSection(
            title: 'Presse-papier',
            body: 'La copie d’un secret est effacée automatiquement après environ 30 secondes.',
          ),
        ],
      ),
    );
  }
}

class _HelpStepData {
  const _HelpStepData(this.title, this.body);
  final String title;
  final String body;
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.data});

  final int number;
  final _HelpStepData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.teal,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: AppTheme.ink.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.tealDark,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: AppTheme.ink.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}
