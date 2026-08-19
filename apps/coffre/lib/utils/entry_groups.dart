import '../models/vault_entry.dart';
import 'entry_display.dart';

/// Entrées qui partagent la même combinaison identifiant + mot de passe.
class EntryGroup {
  const EntryGroup({required this.entries});

  final List<VaultEntry> entries;

  VaultEntry get primary => entries.first;

  bool get isShared => entries.length > 1;

  String get username => primary.username.trim();

  String get password => primary.password;

  List<String> get siteLabels {
    final seen = <String>{};
    final labels = <String>[];
    for (final e in entries) {
      final label = EntryDisplay.title(e).trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      if (!seen.add(key)) continue;
      labels.add(label);
    }
    return labels;
  }

  List<VaultEntry> entriesForSite(String label) {
    final key = label.trim().toLowerCase();
    return entries
        .where((e) => EntryDisplay.title(e).trim().toLowerCase() == key)
        .toList();
  }
}

class EntryGroups {
  EntryGroups._();

  static String keyFor(VaultEntry entry) {
    final user = entry.username.trim().toLowerCase();
    if (user.isEmpty || entry.password.isEmpty) return 'id:${entry.id}';
    return 'combo:$user\u0000${entry.password}';
  }

  static List<EntryGroup> from(Iterable<VaultEntry> entries) {
    final buckets = <String, List<VaultEntry>>{};
    final order = <String>[];
    for (final entry in entries) {
      final key = keyFor(entry);
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add(key);
      }
      buckets[key]!.add(entry);
    }
    final groups = order.map((key) {
      final list = buckets[key]!;
      list.sort(
        (a, b) => EntryDisplay.title(a).toLowerCase().compareTo(
              EntryDisplay.title(b).toLowerCase(),
            ),
      );
      return EntryGroup(entries: list);
    }).toList();

    groups.sort(
      (a, b) => _groupLabel(a).toLowerCase().compareTo(_groupLabel(b).toLowerCase()),
    );
    return groups;
  }

  static String _groupLabel(EntryGroup group) {
    if (group.isShared) return group.username;
    return EntryDisplay.title(group.primary);
  }
}
