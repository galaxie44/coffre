import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../theme/app_theme.dart';
import '../utils/entry_display.dart';
import '../utils/entry_groups.dart';

class EntryGroupCard extends StatelessWidget {
  const EntryGroupCard({
    super.key,
    required this.group,
    required this.onUse,
    this.onOpen,
    this.onCopyUsername,
    this.onCopyPassword,
    this.highlighted = false,
    this.compact = false,
    this.showMenu = true,
  });

  final EntryGroup group;
  final ValueChanged<VaultEntry> onUse;
  final ValueChanged<VaultEntry>? onOpen;
  final ValueChanged<VaultEntry>? onCopyUsername;
  final ValueChanged<VaultEntry>? onCopyPassword;
  final bool highlighted;
  final bool compact;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final entry = group.primary;
    final shared = group.isShared;
    final title = shared ? group.username : EntryDisplay.title(entry);
    final subtitle = shared ? '' : EntryDisplay.subtitle(entry);
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final radius = compact ? 14.0 : 16.0;

    return Material(
      color: highlighted
          ? AppTheme.teal.withValues(alpha: 0.08)
          : (compact ? Colors.white : AppTheme.surface),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () {
          if (shared) {
            if (onOpen == null) onUse(entry);
            return;
          }
          if (onOpen != null) {
            onOpen!(entry);
          } else {
            onUse(entry);
          }
        },
        onLongPress: () => onUse(entry),
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 14, compact ? 10 : 12, 4, compact ? 10 : 12),
          child: Row(
            crossAxisAlignment:
                shared ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: compact ? 18 : 20,
                backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
                foregroundColor: AppTheme.tealDark,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 14 : 16,
                      ),
                    ),
                    if (!shared && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.6),
                          fontSize: compact ? 12 : 13,
                        ),
                      ),
                    if (shared) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: group.siteLabels.map((label) {
                          return _SiteChip(
                            label: label,
                            compact: compact,
                            onTap: onOpen == null
                                ? () => onUse(entry)
                                : () => _openSite(context, label),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Utiliser (identifiant puis mot de passe)',
                onPressed: () => onUse(entry),
                icon: const Icon(Icons.login),
              ),
              if (showMenu)
                PopupMenuButton<String>(
                  tooltip: 'Plus',
                  onSelected: (value) => _onMenu(context, value),
                  itemBuilder: (_) {
                    final items = <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'use',
                        child: Text('Utiliser'),
                      ),
                      if (onCopyUsername != null)
                        const PopupMenuItem(
                          value: 'user',
                          child: Text('Copier l’identifiant'),
                        ),
                      if (onCopyPassword != null)
                        const PopupMenuItem(
                          value: 'password',
                          child: Text('Copier le mot de passe'),
                        ),
                    ];
                    if (onOpen != null) {
                      if (shared) {
                        for (final label in group.siteLabels) {
                          items.add(
                            PopupMenuItem(
                              value: 'edit:$label',
                              child: Text('Modifier $label'),
                            ),
                          );
                        }
                      } else {
                        items.add(
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Modifier'),
                          ),
                        );
                      }
                    }
                    return items;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, String value) {
    final entry = group.primary;
    if (value == 'use') {
      onUse(entry);
      return;
    }
    if (value == 'user') {
      onCopyUsername?.call(entry);
      return;
    }
    if (value == 'password') {
      onCopyPassword?.call(entry);
      return;
    }
    if (value == 'edit') {
      onOpen?.call(entry);
      return;
    }
    if (value.startsWith('edit:')) {
      _openSite(context, value.substring(5));
    }
  }

  Future<void> _openSite(BuildContext context, String label) async {
    if (onOpen == null) return;
    final matches = group.entriesForSite(label);
    if (matches.length <= 1) {
      onOpen!(matches.isEmpty ? group.primary : matches.first);
      return;
    }
    final chosen = await showModalBottomSheet<VaultEntry>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.mist,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  label,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.tealDark,
                      ),
                ),
              ),
              for (final e in matches)
                ListTile(
                  title: Text(e.username),
                  subtitle: Text(
                    e.url.isNotEmpty ? e.url : EntryDisplay.subtitle(e),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, e),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null) onOpen!(chosen);
  }
}

class _SiteChip extends StatelessWidget {
  const _SiteChip({
    required this.label,
    required this.compact,
    this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3EEEE),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.tealDark,
            ),
          ),
        ),
      ),
    );
  }
}
