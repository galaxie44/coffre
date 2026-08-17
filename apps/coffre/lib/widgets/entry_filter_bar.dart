import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/entry_filters.dart';

class EntryFilterBar extends StatelessWidget {
  const EntryFilterBar({
    super.key,
    required this.filters,
    required this.selectedIds,
    required this.onChanged,
    this.compact = false,
  });

  final List<EntryFilter> filters;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool compact;

  static Future<void> showSheet({
    required BuildContext context,
    required List<EntryFilter> filters,
    required Set<String> selectedIds,
    required ValueChanged<Set<String>> onChanged,
  }) {
    var current = {...selectedIds};
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppTheme.mist,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.tealDark,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: filters.map((filter) {
                          final checked = current.contains(filter.id);
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            activeColor: AppTheme.teal,
                            title: Text(filter.label),
                            onChanged: (_) {
                              if (!current.add(filter.id)) current.remove(filter.id);
                              onChanged({...current});
                              setModal(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    if (current.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          current = {};
                          onChanged({});
                          setModal(() {});
                        },
                        child: const Text('Tout décocher'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    if (!compact && Platform.isAndroid) {
      return _AndroidFilterHeader(
        filters: filters,
        selectedIds: selectedIds,
        onChanged: onChanged,
      );
    }

    final shown = filters.take(compact ? 8 : 14).toList();
    final minTap = compact ? 40.0 : 32.0;

    return Material(
      color: const Color(0xFFE3EEEE),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: compact ? 160 : 220),
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 6, compact ? 8 : 12, 8),
          shrinkWrap: true,
          children: [
            Text(
              'Filtres',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.tealDark,
              ),
            ),
            const SizedBox(height: 4),
            ...shown.map((filter) {
              final checked = selectedIds.contains(filter.id);
              return InkWell(
                onTap: () => _toggle(filter.id),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minTap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Checkbox(
                            value: checked,
                            activeColor: AppTheme.teal,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            visualDensity: VisualDensity.standard,
                            onChanged: (_) => _toggle(filter.id),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 13 : 14,
                              fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    final next = {...selectedIds};
    if (!next.add(id)) next.remove(id);
    onChanged(next);
  }
}

class _AndroidFilterHeader extends StatelessWidget {
  const _AndroidFilterHeader({
    required this.filters,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<EntryFilter> filters;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = filters.where((f) => selectedIds.contains(f.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => EntryFilterBar.showSheet(
                context: context,
                filters: filters,
                selectedIds: selectedIds,
                onChanged: onChanged,
              ),
              icon: const Icon(Icons.filter_list),
              label: Text(
                selectedIds.isEmpty
                    ? 'Filtres'
                    : 'Filtres (${selectedIds.length})',
              ),
            ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected.map((filter) {
                return InputChip(
                  label: Text(filter.label),
                  selected: true,
                  onDeleted: () {
                    final next = {...selectedIds}..remove(filter.id);
                    onChanged(next);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
