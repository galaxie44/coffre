class AppVersion {
  AppVersion._();

  static String normalize(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    return s.split(RegExp(r'[-+]')).first;
  }

  static List<int> parts(String raw) {
    final core = normalize(raw).split('.');
    final out = [
      for (var i = 0; i < 3; i++) int.tryParse(i < core.length ? core[i] : '0') ?? 0,
    ];
    return out;
  }

  static int compare(String a, String b) {
    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  static bool isNewer(String latest, String current) => compare(latest, current) > 0;
}

bool isTrustedUpdateUrl(Uri uri) {
  if (uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host == 'github.com') {
    return uri.path.toLowerCase().contains('/galaxie44/coffre/');
  }
  return host == 'objects.githubusercontent.com' ||
      host == 'release-assets.githubusercontent.com' ||
      host == 'github-releases.githubusercontent.com' ||
      host.endsWith('.githubusercontent.com');
}
