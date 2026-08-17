import 'package:coffre/models/vault_entry.dart';
import 'package:coffre/utils/entry_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate emails produce a filter chip', () {
    const mail = 'edouard.clemenceau.pro@gmail.com';
    final entries = [
      VaultEntry.create(title: 'Gmail', username: mail, password: 'a'),
      VaultEntry.create(title: 'Steam', username: mail, password: 'b'),
      VaultEntry.create(title: 'Foryouawards', username: mail, password: 'c'),
      VaultEntry.create(title: 'Univ', username: 'eclemence001', password: 'd'),
    ];

    final filters = EntryFilters.available(entries);
    expect(filters.any((f) => f.value == mail && f.count == 3), isTrue);
    expect(filters.any((f) => f.value == '@gmail.com' && f.count == 3), isTrue);
  });
}
