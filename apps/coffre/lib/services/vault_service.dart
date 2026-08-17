import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/vault_crypto.dart';
import '../models/vault_entry.dart';
import '../utils/credential_capture.dart';
import '../utils/entry_display.dart';

class VaultService extends ChangeNotifier {
  VaultService({VaultCrypto? crypto}) : _crypto = crypto ?? VaultCrypto();

  static const _autofillChannel = MethodChannel('com.coffre/autofill');

  final VaultCrypto _crypto;
  VaultPayload? _payload;
  String? _masterPassword;
  List<int>? _salt;
  bool _unlocked = false;
  int _failedUnlocks = 0;

  bool get isUnlocked => _unlocked;
  bool get hasVaultLoaded => _payload != null;
  VaultPayload? get payload => _payload;
  int get failedUnlocks => _failedUnlocks;
  List<VaultEntry> get entries =>
      List.unmodifiable(_payload?.entries ?? const []);

  /// Session master password (unlocked only). Used to wrap biometric unlock.
  String requireUnlockedMasterPassword() {
    _ensureUnlocked();
    return _masterPassword!;
  }

  /// Progressive delay after failed unlocks (brute-force friction).
  Duration unlockBackoff() {
    if (_failedUnlocks <= 0) return Duration.zero;
    final seconds = math.min(30, 1 << (_failedUnlocks.clamp(1, 5) - 1));
    return Duration(seconds: seconds);
  }

  Future<File> vaultFile() async {
    final dir = await _vaultDir();
    return File(p.join(dir.path, 'vault.enc'));
  }

  Future<Directory> _vaultDir() async {
    if (Platform.isAndroid) {
      final dir = await getApplicationSupportDirectory();
      final vaultDir = Directory(p.join(dir.path, 'coffre'));
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      return vaultDir;
    }
    final support = await getApplicationSupportDirectory();
    final vaultDir = Directory(p.join(support.path, 'Coffre'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  /// Legacy plaintext path (wiped on clear). Encrypted session lives in Keystore store.
  Future<File> autofillCacheFile() async {
    final dir = await _vaultDir();
    return File(p.join(dir.path, 'autofill_session.json'));
  }

  Future<bool> vaultExists() async {
    final file = await vaultFile();
    return file.exists();
  }

  Future<void> createVault(String masterPassword) async {
    if (masterPassword.length < 12) {
      throw ArgumentError(
        'Le mot de passe maître doit faire au moins 12 caractères',
      );
    }
    _masterPassword = masterPassword;
    _payload = VaultPayload();
    _salt = null;
    _unlocked = true;
    _failedUnlocks = 0;
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
  }

  Future<void> unlock(String masterPassword) async {
    final backoff = unlockBackoff();
    if (backoff > Duration.zero) {
      await Future<void>.delayed(backoff);
    }
    final file = await vaultFile();
    if (!await file.exists()) {
      throw StateError('Aucun coffre trouvé');
    }
    final envelope =
        Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    try {
      final clear = await _crypto.decryptEnvelope(
        masterPassword: masterPassword,
        envelope: envelope,
      );
      _salt = base64.decode(envelope['salt'] as String);
      _masterPassword = masterPassword;
      _payload = VaultPayload.fromJson(clear);
      _unlocked = true;
      _failedUnlocks = 0;
      await _writeAutofillCache();
      notifyListeners();
    } catch (_) {
      _failedUnlocks += 1;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> lock() async {
    _payload = null;
    _masterPassword = null;
    _salt = null;
    _unlocked = false;
    await _clearAutofillCache();
    notifyListeners();
  }

  Future<void> addEntry(VaultEntry entry) async {
    _ensureUnlocked();
    final normalized = EntryDisplay.normalize(entry);
    final next = List<VaultEntry>.from(_payload!.entries)..add(normalized);
    _payload = _payload!.copyWith(entries: next);
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
  }

  /// Enregistre une combinaison capturée (inscription / nouveau mot de passe).
  Future<Map<String, String>> saveCapturedCredential({
    required String username,
    required String password,
    String url = '',
    String domain = '',
    String androidPackage = '',
  }) async {
    _ensureUnlocked();
    final decision = CredentialCapture.classify(
      entries: entries,
      username: username,
      password: password,
      domain: domain,
      androidPackage: androidPackage,
      url: url,
    );
    switch (decision.kind) {
      case CredentialCaptureKind.alreadySaved:
        return {'status': 'unchanged', 'id': decision.existing?.id ?? ''};
      case CredentialCaptureKind.update:
        final existing = decision.existing!;
        final nextUrl = url.trim().isNotEmpty ? url.trim() : existing.url;
        await updateEntry(
          existing.copyWith(
            password: password,
            url: nextUrl,
            androidPackage: androidPackage.trim().isNotEmpty &&
                    !CredentialCapture.browserPackages
                        .contains(androidPackage.trim().toLowerCase())
                ? androidPackage.trim()
                : existing.androidPackage,
          ),
        );
        return {'status': 'updated', 'id': existing.id};
      case CredentialCaptureKind.create:
        final created = CredentialCapture.buildNewEntry(
          username: username,
          password: password,
          url: url,
          domain: domain,
          androidPackage: androidPackage,
        );
        await addEntry(created);
        return {'status': 'created', 'id': created.id};
    }
  }

  /// Returns number of entries actually imported (skips duplicates).
  Future<int> importEntries(List<VaultEntry> incoming) async {
    _ensureUnlocked();
    var count = 0;
    final next = List<VaultEntry>.from(_payload!.entries);
    for (final e in incoming) {
      final dup = next.any(
        (x) =>
            x.username.toLowerCase() == e.username.toLowerCase() &&
            x.domain == e.domain &&
            x.domain.isNotEmpty,
      );
      if (dup) continue;
      next.add(EntryDisplay.normalize(e));
      count++;
    }
    if (count == 0) return 0;
    _payload = _payload!.copyWith(entries: next);
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
    return count;
  }

  /// Corrige les titres bruts (URLs Chrome / android://) déjà enregistrés.
  Future<int> normalizeAllEntryTitles() async {
    _ensureUnlocked();
    var count = 0;
    final next = _payload!.entries.map((e) {
      if (!EntryDisplay.needsNormalization(e)) return e;
      count++;
      return EntryDisplay.normalize(e);
    }).toList();
    if (count == 0) return 0;
    _payload = _payload!.copyWith(entries: next);
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
    return count;
  }

  Future<void> updateEntry(VaultEntry entry) async {
    _ensureUnlocked();
    final normalized = EntryDisplay.normalize(entry);
    final next =
        _payload!.entries.map((e) => e.id == normalized.id ? normalized : e).toList();
    _payload = _payload!.copyWith(entries: next);
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    _ensureUnlocked();
    final next = _payload!.entries.where((e) => e.id != id).toList();
    _payload = _payload!.copyWith(entries: next);
    await _persist();
    await _writeAutofillCache();
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _ensureUnlocked();
    _payload = _payload!.copyWith(autoLockSeconds: seconds);
    await _persist();
    notifyListeners();
  }

  List<VaultEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          e.url.toLowerCase().contains(q) ||
          e.androidPackage.toLowerCase().contains(q) ||
          e.windowsProcess.toLowerCase().contains(q) ||
          e.windowsTitleHint.toLowerCase().contains(q) ||
          e.domain.contains(q);
    }).toList();
  }

  List<VaultEntry> matchForWindows({
    required String processName,
    required String windowTitle,
  }) {
    return entries
        .where(
          (e) => matchesWindowsApp(
            processName: processName,
            windowTitle: windowTitle,
            entryProcess: e.windowsProcess,
            entryTitleHint: e.windowsTitleHint,
          ),
        )
        .toList();
  }

  List<VaultEntry> matchForDomain(String domain) {
    return entries.where((e) => domainMatches(domain, e.domain)).toList();
  }

  List<VaultEntry> matchForPackage(String packageName) {
    final pkg = packageName.toLowerCase();
    if (pkg.isEmpty) return const [];
    return entries
        .where((e) => e.androidPackage.toLowerCase() == pkg)
        .toList();
  }

  /// Best-effort wipe: overwrite then delete. SSD/FTL limits apply.
  Future<void> wipeCompletely() async {
    await _clearAutofillCache();
    final cache = await autofillCacheFile();
    await _secureDeleteFile(cache);
    final file = await vaultFile();
    await _secureDeleteFile(file);
    final dir = await _vaultDir();
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    _payload = null;
    _masterPassword = null;
    _salt = null;
    _unlocked = false;
    _failedUnlocks = 0;
    notifyListeners();
  }

  Future<bool> verifyMasterPassword(String password) async {
    if (!_unlocked || _masterPassword == null) return false;
    return password == _masterPassword;
  }

  void _ensureUnlocked() {
    if (!_unlocked || _payload == null || _masterPassword == null) {
      throw StateError('Coffre verrouillé');
    }
  }

  Future<void> _persist() async {
    _ensureUnlocked();
    final envelope = await _crypto.encryptPayload(
      masterPassword: _masterPassword!,
      payload: _payload!.toJson(),
      existingSalt: _salt,
    );
    _salt = base64.decode(envelope['salt'] as String);
    final file = await vaultFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(envelope), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  Future<void> _writeAutofillCache() async {
    if (!Platform.isAndroid || !_unlocked || _payload == null) return;
    final data = {
      'unlocked': true,
      'entries': _payload!.entries
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'username': e.username,
                'password': e.password,
                'url': e.url,
                'domain': e.domain,
                'androidPackage': e.androidPackage,
                'windowsProcess': e.windowsProcess,
                'windowsTitleHint': e.windowsTitleHint,
                'totpSecret': e.totpSecret,
              })
          .toList(),
    };
    try {
      await _autofillChannel.invokeMethod('writeSession', {
        'json': jsonEncode(data),
      });
    } catch (_) {
      // Autofill unavailable in tests / desktop — ignore.
    }
  }

  Future<void> _clearAutofillCache() async {
    if (!Platform.isAndroid) return;
    try {
      await _autofillChannel.invokeMethod('clearSession');
    } catch (_) {}
    try {
      final cache = await autofillCacheFile();
      await _secureDeleteFile(cache);
    } catch (_) {}
  }

  Future<void> _secureDeleteFile(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    final wipeSize = length < 4096 ? 4096 : length;
    await file.writeAsBytes(_crypto.randomWipeBytes(wipeSize), flush: true);
    await file.writeAsBytes(_crypto.randomWipeBytes(wipeSize), flush: true);
    await file.delete();
  }
}
