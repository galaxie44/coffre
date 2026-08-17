import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Format vault.enc (JSON envelope):
/// version, kdf=argon2id, memory, iterations, parallelism,
/// salt/nonce/mac/ciphertext in base64.
class VaultCrypto {
  VaultCrypto({
    this.memory = 65536,
    this.iterations = 3,
    this.parallelism = 4,
  });

  static const int version = 1;

  /// Anti-downgrade floors when reading KDF params from an envelope.
  static const int minMemory = 65536;
  static const int minIterations = 3;
  static const int minParallelism = 1;

  final int memory;
  final int iterations;
  final int parallelism;

  final _aes = AesGcm.with256bits();
  final _random = Random.secure();

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Future<SecretKey> deriveKey(
    String masterPassword,
    List<int> salt, {
    int? memoryOverride,
    int? iterationsOverride,
    int? parallelismOverride,
  }) {
    final argon2 = Argon2id(
      parallelism: parallelismOverride ?? parallelism,
      memory: memoryOverride ?? memory,
      iterations: iterationsOverride ?? iterations,
      hashLength: 32,
    );
    return argon2.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );
  }

  Future<Map<String, dynamic>> encryptPayload({
    required String masterPassword,
    required Map<String, dynamic> payload,
    List<int>? existingSalt,
  }) async {
    final salt = existingSalt ?? _randomBytes(16);
    final key = await deriveKey(masterPassword, salt);
    final clear = utf8.encode(jsonEncode(payload));
    final secretBox = await _aes.encrypt(clear, secretKey: key);
    return {
      'version': version,
      'kdf': 'argon2id',
      'memory': memory,
      'iterations': iterations,
      'parallelism': parallelism,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    };
  }

  Future<Map<String, dynamic>> decryptEnvelope({
    required String masterPassword,
    required Map<String, dynamic> envelope,
  }) async {
    if ((envelope['version'] as int? ?? 0) != version) {
      throw StateError('Version de coffre non supportée');
    }
    if ((envelope['kdf'] as String? ?? 'argon2id') != 'argon2id') {
      throw StateError('KDF non supporté');
    }

    // Use envelope params only if they meet anti-downgrade floors.
    final mem = max(envelope['memory'] as int? ?? memory, minMemory);
    final iters = max(envelope['iterations'] as int? ?? iterations, minIterations);
    final par = max(envelope['parallelism'] as int? ?? parallelism, minParallelism);

    // Reject envelopes that claim weaker params than floors (tamper / downgrade).
    final claimedMem = envelope['memory'] as int? ?? memory;
    final claimedIters = envelope['iterations'] as int? ?? iterations;
    if (claimedMem < minMemory || claimedIters < minIterations) {
      throw StateError('Paramètres KDF trop faibles (possible altération)');
    }

    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final mac = Mac(base64Decode(envelope['mac'] as String));
    final cipherText = base64Decode(envelope['ciphertext'] as String);
    final key = await deriveKey(
      masterPassword,
      salt,
      memoryOverride: mem,
      iterationsOverride: iters,
      parallelismOverride: par,
    );
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }

  /// Overwrite helper: returns random bytes of [length].
  Uint8List randomWipeBytes(int length) => _randomBytes(length);
}

/// True if [pageDomain] may use credentials stored for [entryDomain].
/// Only allows exact match or page subdomain of the stored domain
/// (never the reverse, to avoid evil.example.com matching example.com entries wrongly
/// when the entry is the more specific host — and never title fuzzy match).
bool domainMatches(String pageDomain, String entryDomain) {
  final page = pageDomain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final entry = entryDomain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (page.isEmpty || entry.isEmpty) return false;
  return page == entry || page.endsWith('.$entry');
}
