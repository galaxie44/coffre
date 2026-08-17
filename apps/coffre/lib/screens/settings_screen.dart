import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_update_service.dart';
import '../services/biometric_service.dart';
import '../services/chrome_login_import_service.dart';
import '../services/chrome_policy_service.dart';
import '../services/import_service.dart';
import '../services/preferences_service.dart';
import '../services/vault_service.dart';
import '../services/windows_desktop_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_prompt.dart';
import 'help_screen.dart';
import 'import_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.vault,
    required this.biometric,
    required this.preferences,
    required this.onLock,
    required this.onOpenDanger,
    this.windows,
    this.onQuitForUpdate,
  });

  final VaultService vault;
  final BiometricService biometric;
  final PreferencesService preferences;
  final VoidCallback onLock;
  final VoidCallback onOpenDanger;
  final WindowsDesktopService? windows;
  final Future<void> Function()? onQuitForUpdate;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _launchAtStartup;
  bool _bioBusy = false;
  bool _chromePwmDisabled = false;
  bool _chromePwmBusy = false;
  bool _chromeImportBusy = false;
  bool _updateBusy = false;
  String _appVersion = '';
  final _chromePolicy = ChromePolicyService();
  final _chromeImport = ChromeLoginImportService();
  static const _autofillChannel = MethodChannel('com.coffre/autofill');

  @override
  void initState() {
    super.initState();
    widget.biometric.addListener(_onBio);
    _loadStartup();
    _loadChromePolicy();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await AppUpdateService().installedVersion();
      if (mounted) setState(() => _appVersion = version);
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    final quit = widget.onQuitForUpdate;
    if (!Platform.isWindows || quit == null || _updateBusy) return;
    setState(() => _updateBusy = true);
    try {
      await AppUpdatePrompt.check(
        context: context,
        preferences: widget.preferences,
        onQuit: quit,
        manual: true,
      );
    } finally {
      if (mounted) setState(() => _updateBusy = false);
    }
  }

  Future<void> _loadChromePolicy() async {
    if (!Platform.isWindows) return;
    final disabled = await _chromePolicy.isChromePasswordManagerDisabled();
    if (mounted) setState(() => _chromePwmDisabled = disabled);
  }

  Future<void> _toggleChromePwm(bool disable) async {
    setState(() => _chromePwmBusy = true);
    try {
      if (disable) {
        await _chromePolicy.disableNativePasswordManagers();
      } else {
        await _chromePolicy.restoreNativePasswordManagers();
      }
      if (mounted) {
        setState(() => _chromePwmDisabled = disable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              disable
                  ? (_chromePolicy.chromeIsRunning()
                      ? 'Préférence enregistrée. Fermez TOUTES les fenêtres Chrome (icône barre des tâches aussi), puis rouvrez-le.'
                      : 'Gestionnaire Google désactivé. Vous pouvez rouvrir Chrome.')
                  : 'Gestionnaire Google réactivé. Redémarrez Chrome pour appliquer.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de modifier la politique Chrome')),
        );
      }
    } finally {
      if (mounted) setState(() => _chromePwmBusy = false);
    }
  }

  @override
  void dispose() {
    widget.biometric.removeListener(_onBio);
    super.dispose();
  }

  void _onBio() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStartup() async {
    if (widget.windows == null) return;
    final enabled = await widget.windows!.isLaunchAtStartupEnabled();
    if (mounted) setState(() => _launchAtStartup = enabled);
  }

  Future<void> _importChromeNow() async {
    if (!Platform.isWindows || _chromeImportBusy) return;
    setState(() => _chromeImportBusy = true);
    try {
      final extracted = await _chromeImport.extract();
      if (!mounted) return;
      if (extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun mot de passe Chrome lu. Fermez Chrome puis réessayez.',
            ),
          ),
        );
        return;
      }
      final count = await widget.vault.importEntries(
        extracted.map((e) => e.toVaultEntry()).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? '${extracted.length} trouvé(s), déjà dans Coffre (aucun nouveau).'
                : '$count mot(s) de passe importé(s) depuis Chrome.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import Chrome impossible')),
      );
    } finally {
      if (mounted) setState(() => _chromeImportBusy = false);
    }
  }

  Future<void> _openAutofillSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _autofillChannel.invokeMethod('openAutofillSettings');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ouvrez Paramètres → Mots de passe → Service de saisie automatique → Coffre',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _bioBusy = true);
    try {
      if (value) {
        final ok = await widget.biometric.enable(
          widget.vault.requireUnlockedMasterPassword(),
        );
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activation biométrique annulée')),
          );
        }
      } else {
        await widget.biometric.disable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’activer la biométrie')),
        );
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockSeconds = widget.vault.payload?.autoLockSeconds ?? 60;
    final bioTitle = Platform.isWindows
        ? 'Déverrouillage Windows Hello'
        : 'Déverrouillage biométrique';
    final prefs = widget.preferences.prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Verrouillage automatique'),
            subtitle: Text(lockSeconds <= 0 ? 'Désactivé' : 'Après $lockSeconds s'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [0, 30, 60, 300].map((s) {
                final label = s == 0 ? 'Off' : '${s}s';
                return ChoiceChip(
                  label: Text(label),
                  selected: lockSeconds == s,
                  onSelected: (_) async {
                    await widget.vault.setAutoLockSeconds(s);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 32),
          if (Platform.isWindows) ...[
            ListTile(
              leading: const Icon(Icons.flash_on_outlined),
              title: const Text('Accès rapide Windows'),
              subtitle: const Text('Ctrl+Shift+C dans n’importe quelle app (Steam, etc.)'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.content_paste_go),
              title: const Text('Coller automatiquement'),
              subtitle: const Text(
                'Simule Ctrl+V après copie (opt-in). Sinon copie seule dans le presse-papier.',
              ),
              value: prefs.autoPasteEnabled,
              onChanged: (v) async {
                await widget.preferences.setAutoPaste(v);
                setState(() {});
              },
            ),
          ],
          if (widget.biometric.isAvailable)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(bioTitle),
              subtitle: const Text(
                'Secondaire au mot de passe maître (stockage sécurisé OS)',
              ),
              value: widget.biometric.isEnabled,
              onChanged: _bioBusy ? null : _toggleBiometric,
            ),
          if (Platform.isWindows)
            SwitchListTile(
              secondary: const Icon(Icons.power_settings_new),
              title: const Text('Lancer au démarrage de Windows'),
              value: _launchAtStartup ?? false,
              onChanged: (v) async {
                await widget.windows?.enableLaunchAtStartup(v);
                setState(() => _launchAtStartup = v);
              },
            ),
          if (Platform.isAndroid) ...[
            ListTile(
              leading: const Icon(Icons.flash_on_outlined),
              title: const Text('Accès rapide'),
              subtitle: const Text(
                'Icône éclair en haut de l’accueil : recherche, puis Utiliser (identifiant puis mot de passe).',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Activer le remplissage automatique'),
              subtitle: const Text(
                'Équivalent du clavier : Paramètres Android → Coffre. Un tap remplit identifiant et mot de passe. Une inscription ou un nouveau couple propose d’enregistrer dans Coffre.',
              ),
              onTap: _openAutofillSettings,
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.cloud_off_outlined),
            title: const Text('Vérification fuites (HIBP)'),
            subtitle: const Text('Désactivé par défaut — requiert Internet'),
            value: prefs.breachCheckEnabled,
            onChanged: (v) async {
              await widget.preferences.setBreachCheck(v);
              setState(() {});
            },
          ),
          if (Platform.isWindows) ...[
            SwitchListTile(
              secondary: const Icon(Icons.sync),
              title: const Text('Importer Chrome à l’ouverture'),
              subtitle: const Text(
                'À chaque déverrouillage, ajoute les nouveaux mots de passe Chrome (sans doublons).',
              ),
              value: prefs.chromeAutoImportEnabled,
              onChanged: (v) async {
                await widget.preferences.setChromeAutoImport(v);
                setState(() {});
                if (v) await _importChromeNow();
              },
            ),
            ListTile(
              leading: _chromeImportBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              title: const Text('Importer maintenant depuis Chrome'),
              subtitle: const Text(
                'Lit les mots de passe enregistrés dans Google Chrome et les ajoute au coffre.',
              ),
              onTap: _chromeImportBusy ? null : _importChromeNow,
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Importer depuis Chrome'),
              subtitle: const Text(
                'Choisissez un fichier CSV exporté depuis Google Password Manager.',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImportScreen(
                      vault: widget.vault,
                      importService: ImportService(),
                    ),
                  ),
                );
              },
            ),
          if (Platform.isWindows)
            SwitchListTile(
              secondary: const Icon(Icons.block),
              title: const Text('Désactiver Google Password Manager'),
              subtitle: const Text(
                'Empêche Chrome d’afficher ses mots de passe par-dessus Coffre. Redémarrer Chrome ensuite.',
              ),
              value: _chromePwmDisabled,
              onChanged: _chromePwmBusy ? null : _toggleChromePwm,
            ),
          if (Platform.isWindows)
            ListTile(
              leading: _updateBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_outlined),
              title: const Text('Mettre à jour Coffre'),
              subtitle: Text(
                _appVersion.isEmpty
                    ? 'Vérifie GitHub et propose d’installer la dernière version'
                    : 'Version $_appVersion — vérifie GitHub à l’ouverture',
              ),
              onTap: _updateBusy ? null : _checkUpdate,
            ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Santé du coffre'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SecurityScreen(
                    vault: widget.vault,
                    preferences: widget.preferences,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Verrouiller maintenant'),
            onTap: widget.onLock,
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Aide'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.warning_amber, color: AppTheme.danger),
            title: const Text('Zone danger', style: TextStyle(color: AppTheme.danger)),
            subtitle: const Text('Effacer tout le coffre'),
            onTap: widget.onOpenDanger,
          ),
        ],
      ),
    );
  }
}
