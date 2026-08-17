import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

/// Cross-platform secure secret storage for biometric secondary unlock.
abstract class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);

  static SecretStore create() {
    if (Platform.isAndroid) return AndroidSecretStore();
    if (Platform.isWindows) return WindowsDpapiSecretStore();
    return MemorySecretStore();
  }
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class AndroidSecretStore implements SecretStore {
  static const _channel = MethodChannel('com.coffre/secrets');

  @override
  Future<void> write(String key, String value) async {
    await _channel.invokeMethod('write', {'key': key, 'value': value});
  }

  @override
  Future<String?> read(String key) async {
    final v = await _channel.invokeMethod<String>('read', {'key': key});
    return v;
  }

  @override
  Future<void> delete(String key) async {
    await _channel.invokeMethod('delete', {'key': key});
  }
}

/// User-scoped DPAPI blob on disk (no ATL / no flutter_secure_storage_windows).
class WindowsDpapiSecretStore implements SecretStore {
  Future<File> _fileFor(String key) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(
      Platform.environment['APPDATA'] ?? support.path,
      'Coffre',
      'secrets',
    ));
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File(p.join(dir.path, '$safe.dpapi'));
  }

  @override
  Future<void> write(String key, String value) async {
    final encrypted = _protect(utf8.encode(value));
    final file = await _fileFor(key);
    await file.writeAsBytes(encrypted, flush: true);
  }

  @override
  Future<String?> read(String key) async {
    final file = await _fileFor(key);
    if (!await file.exists()) return null;
    try {
      final clear = _unprotect(await file.readAsBytes());
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = await _fileFor(key);
    if (await file.exists()) {
      final len = await file.length();
      final wipe = List<int>.generate(len < 64 ? 64 : len, (i) => 0);
      await file.writeAsBytes(wipe, flush: true);
      await file.delete();
    }
  }

  List<int> _protect(List<int> data) {
    return using((arena) {
      final blobIn = arena<CRYPT_INTEGER_BLOB>();
      final input = arena<Uint8>(data.length);
      input.asTypedList(data.length).setAll(0, data);
      blobIn.ref.cbData = data.length;
      blobIn.ref.pbData = input;

      final blobOut = arena<CRYPT_INTEGER_BLOB>();
      final ok = CryptProtectData(
        blobIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        0,
        blobOut,
      );
      if (ok == FALSE) {
        throw StateError('CryptProtectData failed (${GetLastError()})');
      }
      final outPtr = blobOut.ref.pbData;
      final outLen = blobOut.ref.cbData;
      final bytes = outPtr.asTypedList(outLen).toList();
      LocalFree(outPtr.cast());
      return bytes;
    });
  }

  List<int> _unprotect(List<int> data) {
    return using((arena) {
      final blobIn = arena<CRYPT_INTEGER_BLOB>();
      final input = arena<Uint8>(data.length);
      input.asTypedList(data.length).setAll(0, data);
      blobIn.ref.cbData = data.length;
      blobIn.ref.pbData = input;

      final blobOut = arena<CRYPT_INTEGER_BLOB>();
      final ok = CryptUnprotectData(
        blobIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        0,
        blobOut,
      );
      if (ok == FALSE) {
        throw StateError('CryptUnprotectData failed (${GetLastError()})');
      }
      final outPtr = blobOut.ref.pbData;
      final outLen = blobOut.ref.cbData;
      final bytes = outPtr.asTypedList(outLen).toList();
      LocalFree(outPtr.cast());
      return bytes;
    });
  }
}
