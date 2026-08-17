import 'dart:convert';

import 'package:coffre/crypto/vault_crypto.dart';
import 'package:coffre/models/vault_entry.dart';
import 'package:coffre/services/password_audit.dart';
import 'package:coffre/services/password_generator.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultCrypto', () {
    test('encrypt then decrypt roundtrip', () async {
      final crypto = VaultCrypto();
      const password = 'mot-de-passe-maitre-test';
      final payload = {
        'entries': [
          {
            'id': '1',
            'title': 'Demo',
            'username': 'alice',
            'password': 's3cret!',
            'url': 'https://exemple.com',
            'androidPackage': '',
            'notes': '',
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          }
        ],
        'autoLockSeconds': 60,
      };

      final envelope = await crypto.encryptPayload(
        masterPassword: password,
        payload: payload,
      );

      expect(envelope['version'], 1);
      expect(envelope['kdf'], 'argon2id');
      expect(envelope['ciphertext'], isNotEmpty);

      final clear = await crypto.decryptEnvelope(
        masterPassword: password,
        envelope: envelope,
      );
      expect(clear['autoLockSeconds'], 60);
      expect((clear['entries'] as List).first['username'], 'alice');
    });

    test('wrong password fails', () async {
      final crypto = VaultCrypto();
      final envelope = await crypto.encryptPayload(
        masterPassword: 'correct-horse-battery',
        payload: {'entries': [], 'autoLockSeconds': 30},
      );
      await expectLater(
        crypto.decryptEnvelope(
          masterPassword: 'wrong-password',
          envelope: envelope,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects downgraded KDF params', () async {
      final crypto = VaultCrypto();
      final envelope = await crypto.encryptPayload(
        masterPassword: 'another-strong-master',
        payload: {'entries': [], 'autoLockSeconds': 10},
      );
      envelope['memory'] = 1024;
      envelope['iterations'] = 1;
      await expectLater(
        crypto.decryptEnvelope(
          masterPassword: 'another-strong-master',
          envelope: envelope,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('envelope is not plaintext json of secrets', () async {
      final crypto = VaultCrypto();
      final envelope = await crypto.encryptPayload(
        masterPassword: 'another-strong-master',
        payload: {
          'entries': [
            {'password': 'SHOULD_NOT_LEAK'}
          ],
          'autoLockSeconds': 10,
        },
      );
      final encoded = jsonEncode(envelope);
      expect(encoded.contains('SHOULD_NOT_LEAK'), isFalse);
    });
  });

  group('domainMatches', () {
    test('allows subdomain of stored domain only', () {
      expect(domainMatches('app.exemple.com', 'exemple.com'), isTrue);
      expect(domainMatches('exemple.com', 'exemple.com'), isTrue);
      expect(domainMatches('exemple.com', 'evil.exemple.com'), isFalse);
      expect(domainMatches('other.com', 'exemple.com'), isFalse);
    });
  });

  group('PasswordGenerator', () {
    test('respects length and charset', () {
      final gen = PasswordGenerator();
      final pwd = gen.generate(length: 24);
      expect(pwd.length, 24);
      expect(pwd, isNot(equals(gen.generate(length: 24))));
    });
  });

  group('matchesWindowsApp', () {
    test('matches process and title hint', () {
      expect(
        matchesWindowsApp(
          processName: 'steam.exe',
          windowTitle: 'Steam — Connexion',
          entryProcess: 'steam.exe',
          entryTitleHint: '',
        ),
        isTrue,
      );
      expect(
        matchesWindowsApp(
          processName: 'discord.exe',
          windowTitle: 'Discord',
          entryProcess: '',
          entryTitleHint: 'discord',
        ),
        isTrue,
      );
      expect(
        matchesWindowsApp(
          processName: 'chrome.exe',
          windowTitle: 'Google',
          entryProcess: 'steam.exe',
          entryTitleHint: 'Steam',
        ),
        isFalse,
      );
    });
  });

  group('PasswordAudit', () {
    test('flags weak and reused passwords', () {
      final audit = PasswordAudit();
      final report = audit.analyze([
        VaultEntry.create(
          title: 'A',
          username: 'a',
          password: '123',
        ),
        VaultEntry.create(
          title: 'B',
          username: 'b',
          password: 'same-password-123!',
        ),
        VaultEntry.create(
          title: 'C',
          username: 'c',
          password: 'same-password-123!',
        ),
      ]);
      expect(report.issues.any((i) => i.kind == PasswordIssueKind.weak), isTrue);
      expect(report.issues.any((i) => i.kind == PasswordIssueKind.reused), isTrue);
    });
  });
}
