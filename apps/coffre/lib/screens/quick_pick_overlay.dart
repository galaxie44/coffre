import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vault_entry.dart';
import '../services/foreground_window.dart';
import '../services/preferences_service.dart';
import '../services/sequential_clipboard_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import '../utils/entry_display.dart';
import '../utils/entry_filters.dart';
import '../utils/entry_groups.dart';
import '../widgets/entry_filter_bar.dart';
import '../widgets/entry_group_card.dart';

class QuickPickOverlay extends StatefulWidget {
  const QuickPickOverlay({
    super.key,
    required this.vault,
    required this.sequentialClipboard,
    required this.preferences,
    required this.targetWindow,
    required this.isActive,
    required this.onClose,
  });

  final VaultService vault;
  final SequentialClipboardService sequentialClipboard;
  final PreferencesService preferences;
  final ForegroundWindowInfo targetWindow;
  final bool isActive;
  final VoidCallback onClose;

  @override
  State<QuickPickOverlay> createState() => _QuickPickOverlayState();
}

class _QuickPickOverlayState extends State<QuickPickOverlay>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  List<VaultEntry> _cachedEntries = const [];
  Set<String> _selectedFilters = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_rebuildCache);
    _rebuildCache();
  }

  @override
  void didUpdateWidget(QuickPickOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetWindow.hwnd != widget.targetWindow.hwnd) {
      _search.clear();
      _selectedFilters = {};
      _rebuildCache();
    }
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
    if (oldWidget.targetWindow.processName.isEmpty &&
        widget.targetWindow.processName.isNotEmpty) {
      _rebuildCache();
    }
  }

  @override
  void dispose() {
    widget.vault.removeListener(_rebuildCache);
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuildCache() {
    final target = widget.targetWindow;
    final sorted = [...widget.vault.entries];
    sorted.sort((a, b) {
      final am = matchesWindowsApp(
        processName: target.processName,
        windowTitle: target.windowTitle,
        entryProcess: a.windowsProcess,
        entryTitleHint: a.windowsTitleHint,
      );
      final bm = matchesWindowsApp(
        processName: target.processName,
        windowTitle: target.windowTitle,
        entryProcess: b.windowsProcess,
        entryTitleHint: b.windowsTitleHint,
      );
      if (am != bm) return am ? -1 : 1;
      return EntryDisplay.title(a).compareTo(EntryDisplay.title(b));
    });
    _cachedEntries = sorted;
    if (mounted) setState(() {});
  }

  VaultEntry _preferredEntry(EntryGroup group, ForegroundWindowInfo target) {
    for (final e in group.entries) {
      if (matchesWindowsApp(
        processName: target.processName,
        windowTitle: target.windowTitle,
        entryProcess: e.windowsProcess,
        entryTitleHint: e.windowsTitleHint,
      )) {
        return e;
      }
    }
    return group.primary;
  }

  List<VaultEntry> _entries(List<EntryFilter> filters, Set<String> selected) {
    var list = _cachedEntries;
    final q = _search.text.trim();
    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      list = list.where((e) {
        return EntryDisplay.title(e).toLowerCase().contains(lower) ||
            e.username.toLowerCase().contains(lower) ||
            EntryDisplay.subtitle(e).toLowerCase().contains(lower);
      }).toList();
    }
    return EntryFilters.apply(list, filters, selected);
  }

  Future<void> _pickEntry(VaultEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);

    final hasUser = entry.username.isNotEmpty;
    final hasPwd = entry.password.isNotEmpty;
    final hwnd = widget.targetWindow.hwnd;
    final autoPaste = widget.preferences.prefs.autoPasteEnabled;

    widget.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    try {
      if (hasUser && hasPwd) {
        await widget.sequentialClipboard.start(
          username: entry.username,
          password: entry.password,
          targetHwnd: hwnd,
          autoPasteUsername: autoPaste,
        );
      } else if (hasUser) {
        await widget.sequentialClipboard.copySingle(entry.username, targetHwnd: hwnd);
      } else if (hasPwd) {
        await widget.sequentialClipboard.copySingle(entry.password, targetHwnd: hwnd);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copySingle(String value) async {
    if (_busy) return;
    setState(() => _busy = true);
    widget.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await widget.sequentialClipboard.copySingle(
        value,
        targetHwnd: widget.targetWindow.hwnd,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filters = EntryFilters.available(_cachedEntries);
    final selected = EntryFilters.prune(_selectedFilters, filters);
    if (selected.length != _selectedFilters.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedFilters = selected);
      });
    }
    final entries = _entries(filters, selected);
    final groups = EntryGroups.from(entries);
    final target = widget.targetWindow;
    final contextLabel = EntryDisplay.friendlyWindowContext(
      processName: target.processName,
      windowTitle: target.windowTitle,
    );

    return Scaffold(
      backgroundColor: AppTheme.mist,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Accès rapide', style: TextStyle(fontSize: 18)),
            if (contextLabel.isNotEmpty)
              Text(
                contextLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.ink.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Fermer (Échap)',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              focusNode: _focus,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Rechercher…',
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          EntryFilterBar(
            compact: true,
            filters: filters,
            selectedIds: selected,
            onChanged: (next) => setState(() => _selectedFilters = next),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Aucun compte trouvé',
                      style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.55)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final preferred = _preferredEntry(group, target);
                      final matched = group.entries.any(
                        (e) => matchesWindowsApp(
                          processName: target.processName,
                          windowTitle: target.windowTitle,
                          entryProcess: e.windowsProcess,
                          entryTitleHint: e.windowsTitleHint,
                        ),
                      );
                      return EntryGroupCard(
                        group: group,
                        compact: true,
                        highlighted: matched,
                        onUse: _busy ? (_) {} : (_) => _pickEntry(preferred),
                        onCopyUsername: _busy
                            ? null
                            : (e) => _copySingle(e.username),
                        onCopyPassword: _busy
                            ? null
                            : (e) => _copySingle(e.password),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.06)),
              ),
            ),
            child: Text(
              'Clic = identifiant puis mot de passe · ⋮ = options · Échap = fermer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.ink.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickPickShortcuts extends StatelessWidget {
  const QuickPickShortcuts({
    super.key,
    required this.onClose,
    required this.child,
  });

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: {
          _CloseIntent: CallbackAction<_CloseIntent>(onInvoke: (_) {
            onClose();
            return null;
          }),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
