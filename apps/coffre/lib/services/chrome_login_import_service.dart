import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:win32/win32.dart';

import 'import_service.dart';
import '../utils/entry_display.dart';

/// Lit les mots de passe enregistrés dans Chrome (Windows, DPAPI + AES-GCM).
class ChromeLoginImportService {
  Future<List<ImportEntry>> extract() async {
    if (!Platform.isWindows) return [];
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return [];
    final root = Directory(p.join(local, 'Google', 'Chrome', 'User Data'));
    final localState = File(p.join(root.path, 'Local State'));
    if (!await localState.exists()) return [];

    final key = await _masterKey(localState);
    final profiles = <Directory>[
      Directory(p.join(root.path, 'Default')),
      ...root
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('Profile ')),
    ];

    final seen = <String>{};
    final out = <ImportEntry>[];
    for (final profile in profiles) {
      if (!profile.existsSync()) continue;
      for (final item in await _readProfile(profile, key)) {
        final sig = '${item.url}|${item.username}|${item.password}';
        if (!seen.add(sig)) continue;
        out.add(item);
      }
    }
    return out;
  }

  Future<Uint8List> _masterKey(File localState) async {
    final data = jsonDecode(await localState.readAsString()) as Map<String, dynamic>;
    final b64 = data['os_crypt']?['encrypted_key'] as String?;
    if (b64 == null) throw StateError('Clé Chrome introuvable');
    final raw = base64.decode(b64);
    // Préfixe "DPAPI"
    return _dpapiUnprotect(Uint8List.fromList(raw.sublist(5)));
  }

  Future<List<ImportEntry>> _readProfile(Directory profile, Uint8List key) async {
    final dbFile = File(p.join(profile.path, 'Login Data'));
    if (!await dbFile.exists()) return [];
    final tmp = File(
      p.join(Directory.systemTemp.path, 'coffre_login_${p.basename(profile.path)}.db'),
    );
    try {
      await dbFile.copy(tmp.path);
    } catch (_) {
      return [];
    }

    Database? db;
    try {
      db = sqlite3.open(tmp.path, mode: OpenMode.readOnly);
      final rows = db.select(
        "SELECT origin_url, username_value, password_value FROM logins "
        "WHERE username_value != '' OR password_value != ''",
      );
      final out = <ImportEntry>[];
      for (final row in rows) {
        final url = (row['origin_url'] as String?) ?? '';
        final username = (row['username_value'] as String?) ?? '';
        final blob = row['password_value'];
        final password = await _decryptPassword(blob, key);
        if (username.isEmpty && password.isEmpty) continue;
        out.add(
          ImportEntry(
            title: EntryDisplay.inferTitleFromImport(title: url, url: url),
            username: username,
            password: password,
            url: url,
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    } finally {
      db?.dispose();
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  Future<String> _decryptPassword(Object? blob, Uint8List key) async {
    if (blob == null) return '';
    late final Uint8List raw;
    if (blob is Uint8List) {
      raw = blob;
    } else if (blob is List<int>) {
      raw = Uint8List.fromList(blob);
    } else {
      return '';
    }
    if (raw.isEmpty) return '';
    try {
      if (raw.length > 3 &&
          ((raw[0] == 0x76 && raw[1] == 0x31 && raw[2] == 0x30) ||
              (raw[0] == 0x76 && raw[1] == 0x31 && raw[2] == 0x31))) {
        final nonce = raw.sublist(3, 15);
        final rest = raw.sublist(15);
        if (rest.length < 16) return '';
        final tag = rest.sublist(rest.length - 16);
        final cipher = rest.sublist(0, rest.length - 16);
        final clear = await AesGcm.with256bits().decrypt(
          SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
          secretKey: SecretKey(key),
        );
        return utf8.decode(clear, allowMalformed: true);
      }
      return utf8.decode(_dpapiUnprotect(raw), allowMalformed: true);
    } catch (_) {
      try {
        return utf8.decode(_dpapiUnprotect(raw), allowMalformed: true);
      } catch (_) {
        return '';
      }
    }
  }

  Uint8List _dpapiUnprotect(Uint8List data) {
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();
    final buffer = calloc<Uint8>(data.length);
    buffer.asTypedList(data.length).setAll(0, data);
    input.ref.cbData = data.length;
    input.ref.pbData = buffer;
    final ok = CryptUnprotectData(
      input,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      0,
      output,
    );
    try {
      if (ok == 0) {
        throw StateError('CryptUnprotectData a échoué');
      }
      return Uint8List.fromList(output.ref.pbData.asTypedList(output.ref.cbData));
    } finally {
      if (output.ref.pbData != nullptr) {
        LocalFree(output.ref.pbData.cast());
      }
      calloc.free(buffer);
      calloc.free(input);
      calloc.free(output);
    }
  }
}
