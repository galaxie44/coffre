import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'secret_store.dart';

/// Secondary unlock: master password wrapped in OS secure storage,
/// gated by biometric / Windows Hello via [LocalAuthentication].
class BiometricService extends ChangeNotifier {
  BiometricService({
    SecretStore? storage,
    LocalAuthentication? auth,
  })  : _storage = storage ?? SecretStore.create(),
        _auth = auth ?? LocalAuthentication();

  static const _secretKey = 'coffre_master_secret_v1';
  static const _enabledKey = 'coffre_biometric_enabled_v1';

  final SecretStore _storage;
  final LocalAuthentication _auth;

  bool _enabled = false;
  bool _available = false;
  bool _ready = false;

  bool get isEnabled => _enabled;
  bool get isAvailable => _available;
  bool get isReady => _ready;

  Future<void> init() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      _available = supported || canCheck;
      final flag = await _storage.read(_enabledKey);
      final secret = await _storage.read(_secretKey);
      _enabled = flag == '1' && secret != null && secret.isNotEmpty;
      if (flag == '1' && (secret == null || secret.isEmpty)) {
        await _storage.delete(_enabledKey);
        _enabled = false;
      }
    } catch (_) {
      _available = false;
      _enabled = false;
    }
    _ready = true;
    notifyListeners();
  }

  Future<bool> enable(String masterPassword) async {
    if (!_available) {
      throw StateError('Biométrie / Windows Hello indisponible sur cet appareil');
    }
    if (masterPassword.isEmpty) {
      throw ArgumentError('Mot de passe maître requis');
    }
    final ok = await _auth.authenticate(
      localizedReason: 'Activez le déverrouillage biométrique pour Coffre',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
    if (!ok) return false;
    await _storage.write(_secretKey, masterPassword);
    await _storage.write(_enabledKey, '1');
    _enabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    await _storage.delete(_secretKey);
    await _storage.delete(_enabledKey);
    _enabled = false;
    notifyListeners();
  }

  /// Returns the wrapped master password after successful biometric auth.
  Future<String?> unlockWithBiometrics() async {
    if (!_enabled) return null;
    final ok = await _auth.authenticate(
      localizedReason: Platform.isWindows
          ? 'Déverrouiller Coffre avec Windows Hello'
          : 'Déverrouiller Coffre',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
    if (!ok) return null;
    final secret = await _storage.read(_secretKey);
    if (secret == null || secret.isEmpty) {
      await disable();
      return null;
    }
    return secret;
  }

  Future<void> clearAll() => disable();
}
