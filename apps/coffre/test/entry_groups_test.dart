import 'package:coffre/models/vault_entry.dart';
import 'package:coffre/utils/entry_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identical username and password are grouped', () {
    const mail = 'ada@example.com';
    const pwd = 'same-secret';
    final entries = [
      VaultEntry.create(title: 'Google', username: mail, password: pwd),
      VaultEntry.create(title: 'Steam', username: mail, password: pwd),
      VaultEntry.create(title: 'Banque', username: mail, password: 'other'),
    ];

    final groups = EntryGroups.from(entries);
    expect(groups.length, 2);
    final shared = groups.firstWhere((g) => g.isShared);
    expect(shared.siteLabels, ['Google', 'Steam']);
    expect(groups.where((g) => !g.isShared).length, 1);
  });

  test('different passwords stay on separate rows', () {
    const mail = 'ada@example.com';
    final entries = [
      VaultEntry.create(title: 'Google', username: mail, password: 'a'),
      VaultEntry.create(title: 'Steam', username: mail, password: 'b'),
    ];
    expect(EntryGroups.from(entries).every((g) => !g.isShared), isTrue);
  });
}
