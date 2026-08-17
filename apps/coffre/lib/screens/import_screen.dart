import 'dart:io';

import 'package:flutter/material.dart';

import '../services/import_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.vault,
    required this.importService,
  });

  final VaultService vault;
  final ImportService importService;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<ImportEntry> _entries = [];
  bool _loading = true;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _entries = await widget.importService.loadChromeImportFile();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picked = await widget.importService.pickGoogleCsv();
      if (picked == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (picked.isEmpty) {
        setState(() {
          _entries = [];
          _error = 'Aucun mot de passe dans ce fichier. Exportez un CSV Google (name, url, username, password).';
          _loading = false;
        });
        return;
      }
      setState(() {
        _entries = picked;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _importAll() async {
    setState(() => _importing = true);
    try {
      final count = await widget.vault.importEntries(
        _entries.map((e) => e.toVaultEntry()).toList(),
      );
      await widget.importService.clearChromeImportFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count entrée(s) importée(s)')),
        );
        Navigator.pop(context, count);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer depuis Chrome')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _entries.isEmpty
                        ? 'Importer un export Google'
                        : '${_entries.length} mot(s) de passe trouvé(s)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'Sur le téléphone : Google Password Manager → Paramètres → Exporter → fichier CSV, puis choisissez-le ici.'
                        : 'Les doublons (même site + identifiant) seront ignorés.',
                    style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.65)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                  ],
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pickCsv,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Choisir le fichier CSV'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: _entries.isEmpty
                        ? Center(
                            child: Text(
                              Platform.isAndroid
                                  ? 'Aucun fichier choisi pour l’instant.'
                                  : 'Aucun fichier d’import.\nLancez scripts\\import_chrome_passwords.py',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.6)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final e = _entries[i];
                              return ListTile(
                                title: Text(e.title.isNotEmpty ? e.title : e.username),
                                subtitle: Text(
                                  e.url.isNotEmpty ? e.url : e.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                  ),
                  FilledButton(
                    onPressed: _entries.isEmpty || _importing ? null : _importAll,
                    child: Text(_importing ? 'Import…' : 'Importer tout dans Coffre'),
                  ),
                ],
              ),
            ),
    );
  }
}
