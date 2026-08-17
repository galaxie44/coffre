import '../crypto/vault_crypto.dart';
import '../data/known_android_apps.dart';
import '../models/vault_entry.dart';
import 'entry_display.dart';

enum CredentialCaptureKind { create, update, alreadySaved }

class CredentialCaptureDecision {
  const CredentialCaptureDecision({
    required this.kind,
    this.existing,
  });

  final CredentialCaptureKind kind;
  final VaultEntry? existing;
}

/// Décide si une combinaison tapée est nouvelle, une mise à jour, ou déjà dans le coffre.
class CredentialCapture {
  CredentialCapture._();

  static const browserPackages = {
    'com.android.chrome',
    'com.chrome.beta',
    'com.chrome.dev',
    'com.chrome.canary',
    'com.brave.browser',
    'org.mozilla.firefox',
    'org.mozilla.firefox_beta',
    'com.microsoft.emmx',
    'com.opera.browser',
    'com.sec.android.app.sbrowser',
  };

  static CredentialCaptureDecision classify({
    required List<VaultEntry> entries,
    required String username,
    required String password,
    String domain = '',
    String androidPackage = '',
    String url = '',
  }) {
    final user = username.trim();
    final pwd = password;
    if (user.isEmpty || pwd.isEmpty) {
      return const CredentialCaptureDecision(kind: CredentialCaptureKind.alreadySaved);
    }

    final pageDomain = domain.trim().isNotEmpty
        ? domain.trim().toLowerCase().replaceFirst(RegExp(r'^www\.'), '')
        : _hostOf(url);
    final pkg = androidPackage.trim();
    final isBrowser = browserPackages.contains(pkg.toLowerCase());

    VaultEntry? sameUser;
    for (final e in entries) {
      if (e.username.trim().toLowerCase() != user.toLowerCase()) continue;
      if (!_sameSite(e, pageDomain: pageDomain, packageName: pkg, isBrowser: isBrowser)) {
        continue;
      }
      if (e.password == pwd) {
        return CredentialCaptureDecision(
          kind: CredentialCaptureKind.alreadySaved,
          existing: e,
        );
      }
      sameUser ??= e;
    }

    if (sameUser != null) {
      return CredentialCaptureDecision(
        kind: CredentialCaptureKind.update,
        existing: sameUser,
      );
    }
    return const CredentialCaptureDecision(kind: CredentialCaptureKind.create);
  }

  static VaultEntry buildNewEntry({
    required String username,
    required String password,
    String url = '',
    String domain = '',
    String androidPackage = '',
  }) {
    final pkg = androidPackage.trim();
    final isBrowser = browserPackages.contains(pkg.toLowerCase());
    final known = findKnownAppByPackage(pkg);
    final resolvedUrl = url.trim().isNotEmpty
        ? url.trim()
        : (domain.trim().isNotEmpty ? 'https://${domain.trim()}' : '');
    final title = isBrowser || pkg.isEmpty
        ? EntryDisplay.inferTitleFromImport(title: '', url: resolvedUrl)
        : (known?.label ?? pkg);
    return VaultEntry.create(
      title: title.isNotEmpty ? title : (pageLabel(domain: domain, url: url, packageName: pkg)),
      username: username.trim(),
      password: password,
      url: isBrowser || resolvedUrl.isNotEmpty ? resolvedUrl : '',
      androidPackage: isBrowser ? '' : pkg,
    );
  }

  static String pageLabel({
    String domain = '',
    String url = '',
    String packageName = '',
  }) {
    final host = domain.trim().isNotEmpty ? domain.trim() : _hostOf(url);
    if (host.isNotEmpty) {
      return EntryDisplay.inferTitleFromImport(title: '', url: 'https://$host');
    }
    final pkg = packageName.trim();
    if (pkg.isEmpty) return 'Nouveau compte';
    return findKnownAppByPackage(pkg)?.label ?? pkg;
  }

  static bool _sameSite(
    VaultEntry entry, {
    required String pageDomain,
    required String packageName,
    required bool isBrowser,
  }) {
    if (!isBrowser && packageName.isNotEmpty) {
      if (entry.androidPackage.trim().toLowerCase() == packageName.toLowerCase()) {
        return true;
      }
    }
    if (pageDomain.isEmpty) return false;
    if (entry.domain.isNotEmpty && domainMatches(pageDomain, entry.domain)) return true;
    final entryHost = _hostOf(entry.url);
    return entryHost.isNotEmpty && domainMatches(pageDomain, entryHost);
  }

  static String _hostOf(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';
    try {
      final uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
      return uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return '';
    }
  }
}
