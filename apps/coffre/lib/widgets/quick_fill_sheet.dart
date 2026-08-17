import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/sequential_clipboard_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import '../utils/entry_display.dart';
import '../utils/entry_groups.dart';
import 'entry_group_card.dart';

/// Équivalent tactile de Ctrl+Shift+C : feuille du bas, au-dessus du clavier.
Future<void> showQuickFillSheet({
  required BuildContext context,
  required VaultService vault,
  required SequentialClipboardService sequential,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.mist,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _QuickFillBody(vault: vault, sequential: sequential),
      );
    },
  );
}

class _QuickFillBody extends StatefulWidget {
  const _QuickFillBody({required this.vault, required this.sequential});

  final VaultService vault;
  final SequentialClipboardService sequential;

  @override
  State<_QuickFillBody> createState() => _QuickFillBodyState();
}

class _QuickFillBodyState extends State<_QuickFillBody> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _use(VaultEntry e) async {
    final hasUser = e.username.isNotEmpty;
    final hasPwd = e.password.isNotEmpty;
    Navigator.pop(context);
    if (hasUser && hasPwd) {
      await widget.sequential.start(username: e.username, password: e.password);
    } else if (hasUser) {
      await widget.sequential.copySingle(e.username);
    } else if (hasPwd) {
      await widget.sequential.copySingle(e.password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    var list = widget.vault.entries;
    if (q.isNotEmpty) {
      list = list.where((e) {
        return EntryDisplay.title(e).toLowerCase().contains(q) ||
            e.username.toLowerCase().contains(q) ||
            EntryDisplay.subtitle(e).toLowerCase().contains(q);
      }).toList();
    }
    final groups = EntryGroups.from(list);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Accès rapide',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.tealDark,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un compte…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Aucun compte'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return EntryGroupCard(
                        group: groups[index],
                        compact: true,
                        showMenu: false,
                        onUse: _use,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Utiliser copie l’identifiant. Collez-le, puis touchez « Mot de passe » sur le bandeau.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
