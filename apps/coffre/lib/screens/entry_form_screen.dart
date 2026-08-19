import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/known_android_apps.dart';
import '../models/vault_entry.dart';
import '../services/breach_check_service.dart';
import '../services/clipboard_service.dart';
import '../services/password_generator.dart';
import '../services/preferences_service.dart';
import '../services/totp_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.vault,
    required this.clipboard,
    required this.preferences,
    this.existing,
  });

  final VaultService vault;
  final ClipboardService clipboard;
  final PreferencesService preferences;
  final VaultEntry? existing;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _package;
  late final TextEditingController _windowsProcess;
  late final TextEditingController _windowsTitle;
  late final TextEditingController _totpSecret;
  late final TextEditingController _notes;
  final _totp = TotpService();
  final _breach = BreachCheckService();
  bool _obscure = true;
  bool _busy = false;
  String? _totpCode;
  BreachCheckResult? _breachResult;
  Timer? _totpTimer;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _package = TextEditingController(text: e?.androidPackage ?? '');
    _windowsProcess = TextEditingController(text: e?.windowsProcess ?? '');
    _windowsTitle = TextEditingController(text: e?.windowsTitleHint ?? '');
    _totpSecret = TextEditingController(text: e?.totpSecret ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e == null) {
      _password.text = PasswordGenerator().generate();
    }
    _refreshTotp();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshTotp());
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _package.dispose();
    _windowsProcess.dispose();
    _windowsTitle.dispose();
    _totpSecret.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _refreshTotp() {
    final code = _totp.generateCode(_totpSecret.text);
    if (code != _totpCode && mounted) {
      setState(() => _totpCode = code);
    }
  }

  void _applyKnownApp(KnownAndroidApp app) {
    setState(() {
      if (_title.text.trim().isEmpty) _title.text = app.label;
      if (app.packageName.isNotEmpty) _package.text = app.packageName;
      if (app.urlHint.isNotEmpty && _url.text.trim().isEmpty) {
        _url.text = app.urlHint;
      }
      if (Platform.isWindows) {
        if (app.windowsProcess.isNotEmpty) {
          _windowsProcess.text = app.windowsProcess;
        }
        if (app.windowsTitleHint.isNotEmpty) {
          _windowsTitle.text = app.windowsTitleHint;
        }
      }
    });
  }

  Future<void> _checkBreach() async {
    if (_password.text.isEmpty) return;
    setState(() => _busy = true);
    final result = await _breach.checkPassword(_password.text);
    if (mounted) {
      setState(() {
        _breachResult = result;
        _busy = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.existing == null) {
        await widget.vault.addEntry(VaultEntry.create(
          title: _title.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
          url: _url.text.trim(),
          androidPackage: _package.text.trim(),
          windowsProcess: _windowsProcess.text.trim(),
          windowsTitleHint: _windowsTitle.text.trim(),
          totpSecret: _totpSecret.text.trim(),
          notes: _notes.text.trim(),
        ));
      } else {
        await widget.vault.updateEntry(widget.existing!.copyWith(
          title: _title.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
          url: _url.text.trim(),
          androidPackage: _package.text.trim(),
          windowsProcess: _windowsProcess.text.trim(),
          windowsTitleHint: _windowsTitle.text.trim(),
          totpSecret: _totpSecret.text.trim(),
          notes: _notes.text.trim(),
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier' : 'Nouvelle entrée'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer ?'),
                    content: const Text('Cette entrée sera définitivement effacée du coffre.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await widget.vault.deleteEntry(widget.existing!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              Platform.isAndroid
                  ? 'Puces pour lier une app (clavier / remplissage auto)'
                  : 'Raccourcis d’apps connues',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: knownAndroidApps.map((app) {
                return ActionChip(
                  label: Text(app.label),
                  onPressed: () => _applyKnownApp(app),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Identifiant / e-mail'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Générer',
                      onPressed: () => setState(() {
                        _password.text = PasswordGenerator().generate();
                        _obscure = false;
                        _breachResult = null;
                      }),
                      icon: const Icon(Icons.auto_awesome),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                    IconButton(
                      tooltip: 'Copier',
                      onPressed: () async {
                        await widget.clipboard.copySecret(_password.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copié — effacé dans 30 s')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            if (widget.preferences.prefs.breachCheckEnabled) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _checkBreach,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Vérifier ce mot de passe (HIBP)'),
              ),
              if (_breachResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _breachResult!.error != null
                        ? 'Erreur : ${_breachResult!.error}'
                        : _breachResult!.pwned
                            ? '⚠ Trouvé dans ${_breachResult!.count} fuite(s)'
                            : '✓ Non trouvé dans les fuites connues',
                    style: TextStyle(
                      color: _breachResult!.pwned ? AppTheme.danger : AppTheme.tealDark,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'URL / domaine (web)',
                hintText: 'accounts.google.com',
                helperText: 'Le domaine suffit pour le navigateur.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _package,
              decoration: const InputDecoration(
                labelText: 'Package Android (recommandé pour le clavier)',
                hintText: 'com.exemple.app',
                helperText: 'Utilisez une puce ci-dessus, ou le clavier proposera aussi par titre / site.',
              ),
            ),
            if (Platform.isWindows) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _windowsProcess,
                decoration: const InputDecoration(
                  labelText: 'Application Windows (optionnel)',
                  hintText: 'steam.exe',
                  helperText: 'Pour l’accès rapide Ctrl+Shift+Espace dans cette app.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _windowsTitle,
                decoration: const InputDecoration(
                  labelText: 'Titre fenêtre (optionnel)',
                  hintText: 'Steam',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _totpSecret,
              decoration: InputDecoration(
                labelText: 'Secret 2FA / TOTP (optionnel)',
                hintText: 'Base32',
                suffixIcon: _totpCode == null
                    ? null
                    : IconButton(
                        tooltip: 'Copier le code',
                        onPressed: () async {
                          await widget.clipboard.copySecret(_totpCode!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Code $_totpCode copié (${_totp.secondsRemaining()}s restantes)'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                      ),
              ),
              onChanged: (_) => _refreshTotp(),
            ),
            if (_totpCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Code actuel : $_totpCode (${_totp.secondsRemaining()}s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tealDark,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(editing ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
