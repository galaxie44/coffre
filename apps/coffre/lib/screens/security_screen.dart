import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/breach_check_service.dart';
import '../services/password_audit.dart';
import '../services/preferences_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
    required this.vault,
    required this.preferences,
  });

  final VaultService vault;
  final PreferencesService preferences;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _audit = PasswordAudit();
  final _breach = BreachCheckService();
  bool _checkingBreaches = false;
  final Map<String, BreachCheckResult> _breachResults = {};

  PasswordAuditReport get _report => _audit.analyze(widget.vault.entries);

  Future<void> _runBreachChecks() async {
    if (!widget.preferences.prefs.breachCheckEnabled) return;
    setState(() => _checkingBreaches = true);
    _breachResults.clear();
    for (final e in widget.vault.entries) {
      if (e.password.isEmpty) continue;
      final result = await _breach.checkPassword(e.password);
      if (mounted) {
        setState(() => _breachResults[e.id] = result);
      }
    }
    if (mounted) setState(() => _checkingBreaches = false);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Santé du coffre')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${report.score}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.tealDark,
                        ),
                  ),
                  const Text('Score de sécurité'),
                  const SizedBox(height: 8),
                  Text(
                    '${report.issues.length} point(s) à améliorer',
                    style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Problèmes détectés',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (report.issues.isEmpty)
            const Text('Aucun problème évident. Continuez à utiliser des mots de passe uniques.')
          else
            ...report.issues.map((issue) {
              final icon = switch (issue.kind) {
                PasswordIssueKind.weak => Icons.warning_amber,
                PasswordIssueKind.reused => Icons.copy_all,
                PasswordIssueKind.old => Icons.schedule,
              };
              return ListTile(
                leading: Icon(icon, color: AppTheme.teal),
                title: Text(issue.entry.title),
                subtitle: Text(issue.detail),
              );
            }),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Vérifier les fuites en ligne (HIBP)'),
            subtitle: const Text(
              'Envoie uniquement les 5 premiers caractères du hash SHA-1 (k-anonymity). Désactivé par défaut.',
            ),
            value: widget.preferences.prefs.breachCheckEnabled,
            onChanged: (v) async {
              await widget.preferences.setBreachCheck(v);
              setState(() {});
              if (v) await _runBreachChecks();
            },
          ),
          if (_checkingBreaches)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.preferences.prefs.breachCheckEnabled)
            ...widget.vault.entries.map((e) {
              final r = _breachResults[e.id];
              if (r == null) return const SizedBox.shrink();
              if (r.error != null) {
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text('Erreur : ${r.error}'),
                );
              }
              if (!r.pwned) {
                return ListTile(
                  title: Text(e.title),
                  subtitle: const Text('Mot de passe non trouvé dans les fuites connues'),
                );
              }
              return ListTile(
                leading: const Icon(Icons.error_outline, color: AppTheme.danger),
                title: Text(e.title),
                subtitle: Text('Trouvé dans ${r.count} fuite(s) — changez ce mot de passe'),
              );
            }),
        ],
      ),
    );
  }
}
