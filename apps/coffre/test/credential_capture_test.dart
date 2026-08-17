import 'package:coffre/models/vault_entry.dart';
import 'package:coffre/utils/credential_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final existing = VaultEntry.create(
    title: 'Exemple',
    username: 'ada@example.com',
    password: 'old-pass',
    url: 'https://example.com/login',
  );

  test('new username on the same site is a create', () {
    final decision = CredentialCapture.classify(
      entries: [existing],
      username: 'new@example.com',
      password: 'brand-new',
      domain: 'www.example.com',
    );
    expect(decision.kind, CredentialCaptureKind.create);
  });

  test('same username and password is ignored', () {
    final decision = CredentialCapture.classify(
      entries: [existing],
      username: 'ada@example.com',
      password: 'old-pass',
      domain: 'example.com',
    );
    expect(decision.kind, CredentialCaptureKind.alreadySaved);
  });

  test('same username and new password is an update', () {
    final decision = CredentialCapture.classify(
      entries: [existing],
      username: 'ADA@example.com',
      password: 'new-pass',
      url: 'https://shop.example.com',
    );
    expect(decision.kind, CredentialCaptureKind.update);
    expect(decision.existing?.id, existing.id);
  });

  test('chrome package does not match a native app entry', () {
    final steam = VaultEntry.create(
      title: 'Steam',
      username: 'ada@example.com',
      password: 'secret',
      androidPackage: 'com.valvesoftware.android.steam.community',
    );
    final decision = CredentialCapture.classify(
      entries: [steam],
      username: 'ada@example.com',
      password: 'secret',
      domain: 'store.steampowered.com',
      androidPackage: 'com.android.chrome',
    );
    expect(decision.kind, CredentialCaptureKind.create);
  });
}
