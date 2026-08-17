import '../data/known_android_apps.dart';
import '../models/vault_entry.dart';

/// Libellés courts et cohérents pour l'affichage (Chrome, Android, URLs brutes).
class EntryDisplay {
  EntryDisplay._();

  static const _domainLabels = {
    'accounts.google.com': 'Google',
    'google.com': 'Google',
    'mail.google.com': 'Gmail',
    'store.steampowered.com': 'Steam',
    'steamcommunity.com': 'Steam',
    'help.steampowered.com': 'Steam',
    'discord.com': 'Discord',
    'discordapp.com': 'Discord',
    'facebook.com': 'Facebook',
    'instagram.com': 'Instagram',
    'twitter.com': 'X',
    'x.com': 'X',
    'netflix.com': 'Netflix',
    'spotify.com': 'Spotify',
    'accounts.spotify.com': 'Spotify',
    'paypal.com': 'PayPal',
    'amazon.fr': 'Amazon',
    'amazon.com': 'Amazon',
    'github.com': 'GitHub',
    'microsoft.com': 'Microsoft',
    'live.com': 'Microsoft',
    'login.live.com': 'Microsoft',
    'apple.com': 'Apple',
    'id.apple.com': 'Apple',
    'reddit.com': 'Reddit',
    'twitch.tv': 'Twitch',
    'linkedin.com': 'LinkedIn',
  };

  static const _processLabels = {
    'steam.exe': 'Steam',
    'steamwebhelper.exe': 'Steam',
    'discord.exe': 'Discord',
    'spotify.exe': 'Spotify',
    'chrome.exe': 'Chrome',
    'firefox.exe': 'Firefox',
    'msedge.exe': 'Edge',
    'opera.exe': 'Opera',
    'brave.exe': 'Brave',
  };

  /// Titre affiché (liste, accès rapide, etc.).
  static String title(VaultEntry entry) {
    final raw = entry.title.trim();
    if (raw.isNotEmpty && !_looksLikeRawUrl(raw)) {
      return _cleanUserTitle(raw);
    }
    return _inferTitle(entry);
  }

  /// Sous-titre : identifiant · site/app.
  static String subtitle(VaultEntry entry) {
    final user = entry.username.trim();
    final hint = _siteHint(entry);
    if (user.isNotEmpty && hint.isNotEmpty) return '$user · $hint';
    if (user.isNotEmpty) return user;
    return hint;
  }

  /// Normalise titre + champs techniques (import Chrome / Android).
  static VaultEntry normalize(VaultEntry entry) {
    final pkg = entry.androidPackage.trim().isNotEmpty
        ? entry.androidPackage.trim()
        : _extractAndroidPackage(entry.url) ??
            _extractAndroidPackage(entry.title);

    final known = pkg != null ? findKnownAppByPackage(pkg) : null;
    final url = _cleanUrl(entry.url, pkg: pkg);
    final title = entry.title.trim().isNotEmpty && !_looksLikeRawUrl(entry.title.trim())
        ? _cleanUserTitle(entry.title.trim())
        : _inferTitle(
            entry.copyWith(
              url: url,
              androidPackage: pkg ?? entry.androidPackage,
            ),
          );

    return entry.copyWith(
      title: title,
      url: url,
      androidPackage: pkg ?? entry.androidPackage,
      windowsProcess: entry.windowsProcess.trim().isNotEmpty
          ? entry.windowsProcess
          : (known?.windowsProcess ?? entry.windowsProcess),
      windowsTitleHint: entry.windowsTitleHint.trim().isNotEmpty
          ? entry.windowsTitleHint
          : (known?.windowsTitleHint ?? entry.windowsTitleHint),
    );
  }

  static String friendlyProcess(String processName) {
    final key = processName.trim().toLowerCase();
    if (key.isEmpty) return '';
    if (_processLabels.containsKey(key)) return _processLabels[key]!;
    if (key.contains('steam')) return 'Steam';
    if (key.contains('discord')) return 'Discord';
    return key.replaceAll('.exe', '');
  }

  static String friendlyWindowContext({
    required String processName,
    required String windowTitle,
  }) {
    final app = friendlyProcess(processName);
    final title = windowTitle.trim();
    if (app.isNotEmpty && title.isNotEmpty) return '$app · $title';
    return app.isNotEmpty ? app : title;
  }

  static String inferTitleFromImport({
    required String title,
    required String url,
  }) {
    return normalize(
      VaultEntry.create(title: title, username: '', password: '', url: url),
    ).title;
  }

  static bool needsNormalization(VaultEntry entry) {
    final n = normalize(entry);
    return n.title != entry.title ||
        n.url != entry.url ||
        n.androidPackage != entry.androidPackage ||
        n.windowsProcess != entry.windowsProcess ||
        n.windowsTitleHint != entry.windowsTitleHint;
  }

  static String _inferTitle(VaultEntry entry) {
    final pkg = entry.androidPackage.trim().isNotEmpty
        ? entry.androidPackage.trim()
        : _extractAndroidPackage(entry.url) ??
            _extractAndroidPackage(entry.title);
    if (pkg != null && pkg.isNotEmpty) {
      final known = findKnownAppByPackage(pkg);
      if (known != null) return known.label;
      return _humanizePackage(pkg);
    }

    final domain = entry.domain;
    if (domain.isNotEmpty) {
      final byUrl = findKnownAppByUrlHint(domain);
      if (byUrl != null) return byUrl.label;
      return _domainToLabel(domain);
    }

    final raw = entry.title.trim();
    if (raw.isNotEmpty) return _cleanUserTitle(raw);
    return 'Compte';
  }

  static String _siteHint(VaultEntry entry) {
    final pkg = entry.androidPackage.trim().isNotEmpty
        ? entry.androidPackage.trim()
        : _extractAndroidPackage(entry.url);
    if (pkg != null && pkg.isNotEmpty) {
      final known = findKnownAppByPackage(pkg);
      if (known != null) return known.label;
      return _humanizePackage(pkg);
    }
    final domain = entry.domain;
    if (domain.isEmpty) return '';
    return _domainToLabel(domain);
  }

  static String? _extractAndroidPackage(String raw) {
    final s = raw.trim();
    if (!s.startsWith('android://')) return null;
    final at = s.lastIndexOf('@');
    if (at < 0) return null;
    var pkg = s.substring(at + 1);
    if (pkg.endsWith('/')) pkg = pkg.substring(0, pkg.length - 1);
    return pkg.isNotEmpty ? pkg : null;
  }

  static String _cleanUrl(String url, {String? pkg}) {
    var u = url.trim();
    if (u.startsWith('android://') && pkg != null) {
      final known = findKnownAppByPackage(pkg);
      if (known?.urlHint.isNotEmpty == true) {
        return 'https://${known!.urlHint}/';
      }
      return '';
    }
    if (u.startsWith('http://') || u.startsWith('https://')) {
      try {
        final uri = Uri.parse(u);
        if (uri.host.isNotEmpty) {
          return '${uri.scheme}://${uri.host}/';
        }
      } catch (_) {}
    }
    return u;
  }

  static bool _looksLikeRawUrl(String s) {
    return s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('android://') ||
        RegExp(r'^[\w.-]+\.(com|fr|net|org)/').hasMatch(s);
  }

  static String _cleanUserTitle(String title) {
    var t = title.trim();
    if (t.startsWith('https://') || t.startsWith('http://')) {
      try {
        final host = Uri.parse(t).host;
        if (host.isNotEmpty) return _domainToLabel(host);
      } catch (_) {}
    }
    return t;
  }

  static String _domainToLabel(String domain) {
    final d = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (_domainLabels.containsKey(d)) return _domainLabels[d]!;
    for (final entry in _domainLabels.entries) {
      if (d == entry.key || d.endsWith('.${entry.key}')) return entry.value;
    }
    final parts = d.split('.');
    if (parts.length >= 2) {
      final core = parts[parts.length - 2];
      if (core.length > 2) {
        return core[0].toUpperCase() + core.substring(1);
      }
    }
    return d;
  }

  static String _humanizePackage(String package) {
    const skip = {'com', 'org', 'net', 'android', 'app', 'mobile', 'www'};
    final parts = package
        .split('.')
        .where((p) => p.length > 2 && !skip.contains(p.toLowerCase()))
        .toList();
    if (parts.isEmpty) return package;
    return parts
        .map((p) {
          final clean = p.replaceAll('_', ' ');
          if (clean.isEmpty) return '';
          return clean[0].toUpperCase() + clean.substring(1);
        })
        .join(' ');
  }
}
