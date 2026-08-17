import 'dart:convert';
import 'dart:io';

/// Désactive le gestionnaire de mots de passe natif Chrome / Edge.
/// Le menu Google n’est pas dans la page : seule une préférence / politique Chrome l’enlève.
class ChromePolicyService {
  static const _chromeKey = r'HKCU\Software\Policies\Google\Chrome';
  static const _edgeKey = r'HKCU\Software\Policies\Microsoft\Edge';

  Future<bool> isChromePasswordManagerDisabled() async {
    if (!Platform.isWindows) return false;
    if (await _registryDisabled(_chromeKey)) return true;
    return _prefsDisabled(_chromeUserData());
  }

  Future<void> disableNativePasswordManagers() async {
    if (!Platform.isWindows) return;
    final registryOk = await _tryRegistryDisable();
    await _writeBrowserPrefs(disable: true);
    if (!registryOk) {
      // Les prefs JSON ne tiennent que si Chrome est fermé au moment de l’écriture.
    }
  }

  Future<void> restoreNativePasswordManagers() async {
    if (!Platform.isWindows) return;
    await _deleteValue(_chromeKey, 'PasswordManagerEnabled');
    await _deleteValue(_chromeKey, 'PasswordManagerPasskeysEnabled');
    await _deleteValue(_edgeKey, 'PasswordManagerEnabled');
    await _deleteValue(_edgeKey, 'PasswordManagerPasskeysEnabled');
    await _writeBrowserPrefs(disable: false);
  }

  bool chromeIsRunning() {
    try {
      final r = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq chrome.exe', '/NH']);
      return '${r.stdout}'.toLowerCase().contains('chrome.exe');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRegistryDisable() async {
    final a = await _setDword(_chromeKey, 'PasswordManagerEnabled', 0);
    final b = await _setDword(_chromeKey, 'PasswordManagerPasskeysEnabled', 0);
    await _setDword(_edgeKey, 'PasswordManagerEnabled', 0);
    await _setDword(_edgeKey, 'PasswordManagerPasskeysEnabled', 0);
    return a && b;
  }

  Future<bool> _registryDisabled(String key) async {
    final result = await Process.run('reg', ['query', key, '/v', 'PasswordManagerEnabled']);
    if (result.exitCode != 0) return false;
    return RegExp(r'0x0\b').hasMatch('${result.stdout}');
  }

  Directory _chromeUserData() {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    return Directory('$local\\Google\\Chrome\\User Data');
  }

  Directory _edgeUserData() {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    return Directory('$local\\Microsoft\\Edge\\User Data');
  }

  bool _prefsDisabled(Directory userData) {
    final file = File('${userData.path}\\Default\\Preferences');
    if (!file.existsSync()) return false;
    try {
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return map['credentials_enable_service'] == false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeBrowserPrefs({required bool disable}) async {
    for (final root in [_chromeUserData(), _edgeUserData()]) {
      if (!await root.exists()) continue;
      final profiles = [
        Directory('${root.path}\\Default'),
        ...root.listSync().whereType<Directory>().where(
              (d) => d.path.split(Platform.pathSeparator).last.startsWith('Profile '),
            ),
      ];
      for (final profile in profiles) {
        await _patchPreferences(File('${profile.path}\\Preferences'), disable: disable);
      }
    }
  }

  Future<void> _patchPreferences(File file, {required bool disable}) async {
    if (!await file.exists()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      map['credentials_enable_service'] = !disable;
      map['credentials_enable_autosignin'] = false;
      final autofill = Map<String, dynamic>.from(map['autofill'] as Map? ?? {});
      autofill['profile_enabled'] = map['autofill']?['profile_enabled'] ?? true;
      map['autofill'] = autofill;
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    } catch (_) {}
  }

  Future<bool> _setDword(String key, String name, int value) async {
    final r = await Process.run('reg', [
      'add',
      key,
      '/v',
      name,
      '/t',
      'REG_DWORD',
      '/d',
      '$value',
      '/f',
    ]);
    return r.exitCode == 0;
  }

  Future<void> _deleteValue(String key, String name) async {
    await Process.run('reg', ['delete', key, '/v', name, '/f']);
  }
}
