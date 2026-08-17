import '../models/vault_entry.dart';

enum PasswordIssueKind { weak, reused, old }

class PasswordIssue {
  const PasswordIssue({
    required this.entry,
    required this.kind,
    required this.detail,
  });

  final VaultEntry entry;
  final PasswordIssueKind kind;
  final String detail;
}

class PasswordAuditReport {
  const PasswordAuditReport({
    required this.issues,
    required this.score,
  });

  final List<PasswordIssue> issues;
  final int score;
}

class PasswordAudit {
  PasswordAuditReport analyze(List<VaultEntry> entries) {
    final issues = <PasswordIssue>[];
    final passwordCounts = <String, int>{};
    for (final e in entries) {
      if (e.password.isEmpty) continue;
      passwordCounts[e.password] = (passwordCounts[e.password] ?? 0) + 1;
    }

    for (final e in entries) {
      if (_isWeak(e.password)) {
        issues.add(PasswordIssue(
          entry: e,
          kind: PasswordIssueKind.weak,
          detail: 'Mot de passe court ou peu complexe',
        ));
      }
      if ((passwordCounts[e.password] ?? 0) > 1) {
        issues.add(PasswordIssue(
          entry: e,
          kind: PasswordIssueKind.reused,
          detail: 'Mot de passe réutilisé ailleurs dans le coffre',
        ));
      }
      final age = DateTime.now().toUtc().difference(e.updatedAt);
      if (age.inDays > 365) {
        issues.add(PasswordIssue(
          entry: e,
          kind: PasswordIssueKind.old,
          detail: 'Non modifié depuis ${age.inDays} jours',
        ));
      }
    }

    final penalty = issues.length * 8;
    final score = (100 - penalty).clamp(0, 100);
    return PasswordAuditReport(issues: issues, score: score);
  }

  bool _isWeak(String password) {
    if (password.length < 10) return true;
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    final kinds = [hasLower, hasUpper, hasDigit, hasSymbol].where((x) => x).length;
    return kinds < 3;
  }
}
