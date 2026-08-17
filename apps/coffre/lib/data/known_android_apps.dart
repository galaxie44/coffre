class KnownAndroidApp {
  const KnownAndroidApp({
    required this.label,
    required this.packageName,
    this.windowsProcess = '',
    this.windowsTitleHint = '',
    this.urlHint = '',
  });

  final String label;
  final String packageName;
  final String windowsProcess;
  final String windowsTitleHint;
  final String urlHint;
}

const knownAndroidApps = [
  KnownAndroidApp(
    label: 'Gmail',
    packageName: 'com.google.android.gm',
    urlHint: 'accounts.google.com',
  ),
  KnownAndroidApp(
    label: 'Chrome',
    packageName: 'com.android.chrome',
  ),
  KnownAndroidApp(
    label: 'Steam (mobile)',
    packageName: 'com.valvesoftware.android.steam.community',
    windowsProcess: 'steam.exe',
    windowsTitleHint: 'Steam',
    urlHint: 'store.steampowered.com',
  ),
  KnownAndroidApp(
    label: 'Discord',
    packageName: 'com.discord',
    windowsProcess: 'Discord.exe',
    windowsTitleHint: 'Discord',
    urlHint: 'discord.com',
  ),
  KnownAndroidApp(
    label: 'Netflix',
    packageName: 'com.netflix.mediaclient',
    urlHint: 'netflix.com',
  ),
  KnownAndroidApp(
    label: 'Spotify',
    packageName: 'com.spotify.music',
    windowsProcess: 'Spotify.exe',
    urlHint: 'accounts.spotify.com',
  ),
  KnownAndroidApp(
    label: 'Facebook',
    packageName: 'com.facebook.katana',
    urlHint: 'facebook.com',
  ),
  KnownAndroidApp(
    label: 'Instagram',
    packageName: 'com.instagram.android',
    urlHint: 'instagram.com',
  ),
  KnownAndroidApp(
    label: 'PayPal',
    packageName: 'com.paypal.android.p2pmobile',
    urlHint: 'paypal.com',
  ),
  KnownAndroidApp(
    label: 'Amazon',
    packageName: 'com.amazon.mShop.android.shopping',
    urlHint: 'amazon.fr',
  ),
  KnownAndroidApp(
    label: 'Webtoon',
    packageName: 'com.naver.linewebtoon',
  ),
  KnownAndroidApp(
    label: 'Boost Your Team',
    packageName: 'com.digitalplumecompany.boostyourteam',
  ),
];

KnownAndroidApp? findKnownApp(String label) {
  final q = label.trim().toLowerCase();
  for (final app in knownAndroidApps) {
    if (app.label.toLowerCase() == q) return app;
  }
  return null;
}

KnownAndroidApp? findKnownAppByPackage(String package) {
  final q = package.trim().toLowerCase();
  for (final app in knownAndroidApps) {
    if (app.packageName.toLowerCase() == q) return app;
  }
  return null;
}

KnownAndroidApp? findKnownAppByUrlHint(String domain) {
  final d = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  KnownAndroidApp? partial;
  for (final app in knownAndroidApps) {
    final hint = app.urlHint.toLowerCase();
    if (hint.isEmpty) continue;
    if (d == hint || d.endsWith('.$hint')) return app;
    if (d.contains(hint)) partial ??= app;
  }
  return partial;
}
