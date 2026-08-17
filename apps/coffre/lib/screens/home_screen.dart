import 'dart:io';

import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/biometric_service.dart';
import '../services/chrome_login_import_service.dart';
import '../services/clipboard_service.dart';
import '../services/import_service.dart';
import '../services/pending_autofill_save.dart';
import '../services/preferences_service.dart';
import '../services/sequential_clipboard_service.dart';
import '../services/vault_service.dart';
import '../services/windows_desktop_service.dart';
import '../theme/app_theme.dart';
import '../utils/credential_capture.dart';
import '../utils/entry_filters.dart';
import '../utils/entry_groups.dart';
import '../widgets/entry_filter_bar.dart';
import '../widgets/entry_group_card.dart';
import '../widgets/quick_fill_sheet.dart';
import '../widgets/sequential_copy_banner.dart';
import 'danger_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'import_screen.dart';
import 'security_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vault,
    required this.clipboard,
    required this.sequentialClipboard,
    required this.biometric,
    required this.preferences,
    required this.onLock,
    required this.onActivity,
    this.windows,
  });

  final VaultService vault;
  final ClipboardService clipboard;
  final SequentialClipboardService sequentialClipboard;
  final BiometricService biometric;
  final PreferencesService preferences;
  final VoidCallback onLock;
  final VoidCallback onActivity;
  final WindowsDesktopService? windows;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  Set<String> _selectedFilters = {};
  bool _handlingPendingSave = false;

  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_onVault);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingAutofillSave();
      _checkChromeImport();
      _autoImportChromeIfEnabled();
      _normalizeTitlesOnce();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingAutofillSave();
    }
  }

  Future<void> _autoImportChromeIfEnabled() async {
    if (!Platform.isWindows || !widget.preferences.prefs.chromeAutoImportEnabled) {
      return;
    }
    try {
      final extracted = await ChromeLoginImportService().extract();
      if (extracted.isEmpty || !mounted) return;
      final count = await widget.vault.importEntries(
        extracted.map((e) => e.toVaultEntry()).toList(),
      );
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count mot(s) de passe Chrome ajouté(s)')),
        );
      }
    } catch (_) {}
  }

  Future<void> _normalizeTitlesOnce() async {
    final count = await widget.vault.normalizeAllEntryTitles();
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count nom(s) d’application raccourci(s)')),
      );
    }
  }

  Future<void> _checkChromeImport() async {
    final service = ImportService();
    final entries = await service.loadChromeImportFile();
    if (entries.isEmpty || !mounted) return;

    final vaultEmpty = widget.vault.entries.isEmpty;
    if (!vaultEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importer depuis Chrome ?'),
          content: Text(
            '${entries.length} mot(s) de passe Chrome sont prêts à être importés dans Coffre.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    try {
      final count = await widget.vault.importEntries(
        entries.map((e) => e.toVaultEntry()).toList(),
      );
      await service.clearChromeImportFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count entrée(s) importée(s) depuis Chrome')),
      );
    } catch (e) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImportScreen(vault: widget.vault, importService: service),
        ),
      );
    }
  }

  Future<void> _checkPendingAutofillSave() async {
    if (!Platform.isAndroid || _handlingPendingSave) return;
    _handlingPendingSave = true;
    try {
    final pending = PendingAutofillSave();
    final data = await pending.fetch();
    if (data == null || !mounted) return;
    final pkg = data['packageName'] ?? '';
    final username = data['username'] ?? '';
    final password = data['password'] ?? '';
    final webDomain = data['webDomain'] ?? '';
    if (username.isEmpty || password.isEmpty) {
      await pending.clear();
      return;
    }

    final decision = CredentialCapture.classify(
      entries: widget.vault.entries,
      username: username,
      password: password,
      domain: webDomain,
      androidPackage: pkg,
    );
    if (decision.kind == CredentialCaptureKind.alreadySaved) {
      await pending.clear();
      return;
    }

    await pending.clear();
    widget.onActivity();
    await widget.vault.saveCapturedCredential(
      username: username,
      password: password,
      domain: webDomain,
      url: webDomain.isNotEmpty ? 'https://$webDomain' : '',
      androidPackage: pkg,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision.kind == CredentialCaptureKind.update
                ? 'Mot de passe mis à jour pour $username'
                : 'Compte enregistré : $username',
          ),
        ),
      );
    }
    } finally {
      _handlingPendingSave = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.vault.removeListener(_onVault);
    _search.dispose();
    super.dispose();
  }

  void _onVault() {
    if (mounted) setState(() {});
  }

  Future<void> _openForm([VaultEntry? entry]) async {
    widget.onActivity();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(
          vault: widget.vault,
          clipboard: widget.clipboard,
          preferences: widget.preferences,
          existing: entry,
        ),
      ),
    );
    widget.onActivity();
  }

  Future<void> _openSettings() async {
    widget.onActivity();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          vault: widget.vault,
          biometric: widget.biometric,
          preferences: widget.preferences,
          windows: widget.windows,
          onLock: widget.onLock,
          onOpenDanger: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DangerScreen(
                  vault: widget.vault,
                  biometric: widget.biometric,
                  onWiped: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    widget.onLock();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    widget.onActivity();
  }

  Future<void> _openQuickFill() async {
    widget.onActivity();
    await showQuickFillSheet(
      context: context,
      vault: widget.vault,
      sequential: widget.sequentialClipboard,
    );
    widget.onActivity();
  }

  Future<void> _useEntry(VaultEntry e) async {
    widget.onActivity();
    final hasUser = e.username.isNotEmpty;
    final hasPwd = e.password.isNotEmpty;
    if (hasUser && hasPwd) {
      await widget.sequentialClipboard.start(
        username: e.username,
        password: e.password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text('Identifiant copié — collez-le, puis Mot de passe'),
        ),
      );
    } else if (hasUser) {
      await widget.sequentialClipboard.copySingle(e.username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identifiant copié — effacé dans 30 s')),
        );
      }
    } else if (hasPwd) {
      await widget.sequentialClipboard.copySingle(e.password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe copié — effacé dans 30 s')),
        );
      }
    }
  }

  Future<void> _copyPasswordOnly(VaultEntry e) async {
    widget.onActivity();
    await widget.clipboard.copySecret(e.password);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe copié — effacé dans 30 s')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searched = widget.vault.search(_search.text);
    final filters = EntryFilters.available(widget.vault.entries);
    final selected = EntryFilters.prune(_selectedFilters, filters);
    if (selected.length != _selectedFilters.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedFilters = selected);
      });
    }
    final items = EntryFilters.apply(searched, filters, selected);
    final groups = EntryGroups.from(items);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffre'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              tooltip: 'Accès rapide',
              onPressed: _openQuickFill,
              icon: const Icon(Icons.flash_on_outlined),
            ),
          IconButton(
            tooltip: 'Santé du coffre',
            onPressed: () {
              widget.onActivity();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SecurityScreen(
                    vault: widget.vault,
                    preferences: widget.preferences,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Verrouiller',
            onPressed: widget.onLock,
            icon: const Icon(Icons.lock_outline),
          ),
          IconButton(
            tooltip: 'Paramètres',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          SequentialCopyBanner(sequential: widget.sequentialClipboard),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                widget.onActivity();
                setState(() {});
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher…',
              ),
            ),
          ),
          EntryFilterBar(
            filters: filters,
            selectedIds: selected,
            onChanged: (next) => setState(() => _selectedFilters = next),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _search.text.isEmpty && selected.isEmpty
                          ? 'Aucune entrée. Ajoutez votre premier mot de passe.'
                          : 'Aucun résultat.',
                      style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.6)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return EntryGroupCard(
                        group: group,
                        onUse: _useEntry,
                        onOpen: _openForm,
                        onCopyUsername: (e) async {
                          widget.onActivity();
                          await widget.sequentialClipboard.copySingle(e.username);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Identifiant copié — effacé dans 30 s'),
                              ),
                            );
                          }
                        },
                        onCopyPassword: _copyPasswordOnly,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
