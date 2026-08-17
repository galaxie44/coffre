import '../models/vault_entry.dart';
import 'entry_display.dart';

enum EntryFilterKind { username, site }

class EntryFilter {
  const EntryFilter({
    required this.kind,
    required this.value,
    required this.display,
    required this.count,
  });

  final EntryFilterKind kind;
  final String value;
  final String display;
  final int count;

  String get id => '${kind.name}:$value';

  String get label => '$display  ($count)';

  bool matches(VaultEntry entry) {
    switch (kind) {
      case EntryFilterKind.username:
        final u = EntryFilters.identity(entry);
        if (value.startsWith('@') && !value.substring(1).contains('@')) {
          return u.endsWith(value);
        }
        return u == value;
      case EntryFilterKind.site:
        return EntryDisplay.title(entry).trim().toLowerCase() == value;
    }
  }
}

class EntryFilters {
  EntryFilters._();

  static final _emailRe =
      RegExp(r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}', caseSensitive: false);

  static String identity(VaultEntry entry) {
    final user = entry.username.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (user.contains('@')) return user;
    final blob = '${entry.username} ${entry.title} ${EntryDisplay.subtitle(entry)}';
    final match = _emailRe.firstMatch(blob);
    return (match?.group(0) ?? user).toLowerCase();
  }

  /// Cases à cocher : identifiant / domaine / site dès qu’ils apparaissent 2 fois.
  static List<EntryFilter> available(Iterable<VaultEntry> entries) {
    final list = entries.toList();
    final users = <String, int>{};
    final userDisplay = <String, String>{};
    final domains = <String, int>{};
    final sites = <String, String>{};
    final siteCounts = <String, int>{};

    for (final e in list) {
      final id = identity(e);
      if (id.isNotEmpty) {
        users[id] = (users[id] ?? 0) + 1;
        userDisplay.putIfAbsent(
          id,
          () => e.username.trim().isNotEmpty ? e.username.trim() : id,
        );
        final at = id.lastIndexOf('@');
        if (at > 0 && at < id.length - 1) {
          final domain = id.substring(at);
          domains[domain] = (domains[domain] ?? 0) + 1;
        }
      }
      final site = EntryDisplay.title(e).trim();
      if (site.isNotEmpty) {
        final key = site.toLowerCase();
        sites.putIfAbsent(key, () => site);
        siteCounts[key] = (siteCounts[key] ?? 0) + 1;
      }
    }

    final out = <EntryFilter>[];
    users.forEach((key, count) {
      if (count < 2) return;
      out.add(
        EntryFilter(
          kind: EntryFilterKind.username,
          value: key,
          display: userDisplay[key] ?? key,
          count: count,
        ),
      );
    });
    domains.forEach((domain, count) {
      if (count < 2) return;
      out.add(
        EntryFilter(
          kind: EntryFilterKind.username,
          value: domain,
          display: domain,
          count: count,
        ),
      );
    });
    siteCounts.forEach((key, count) {
      if (count < 2) return;
      out.add(
        EntryFilter(
          kind: EntryFilterKind.site,
          value: key,
          display: sites[key] ?? key,
          count: count,
        ),
      );
    });

    out.sort((a, b) {
      if (a.kind != b.kind) {
        return a.kind == EntryFilterKind.username ? -1 : 1;
      }
      if (a.count != b.count) return b.count.compareTo(a.count);
      return a.display.toLowerCase().compareTo(b.display.toLowerCase());
    });
    return out;
  }

  static Set<String> prune(Set<String> selected, List<EntryFilter> available) {
    if (selected.isEmpty) return selected;
    final ids = available.map((f) => f.id).toSet();
    return selected.where(ids.contains).toSet();
  }

  static List<VaultEntry> apply(
    Iterable<VaultEntry> entries,
    List<EntryFilter> available,
    Set<String> selectedIds,
  ) {
    if (selectedIds.isEmpty) return List<VaultEntry>.from(entries);
    final active = available.where((f) => selectedIds.contains(f.id)).toList();
    if (active.isEmpty) return List<VaultEntry>.from(entries);
    return entries.where((e) => active.any((f) => f.matches(e))).toList();
  }
}
