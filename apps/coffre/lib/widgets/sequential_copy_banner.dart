import 'package:flutter/material.dart';

import '../services/sequential_clipboard_service.dart';
import '../theme/app_theme.dart';

class SequentialCopyBanner extends StatelessWidget {
  const SequentialCopyBanner({
    super.key,
    required this.sequential,
  });

  final SequentialClipboardService sequential;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sequential,
      builder: (context, _) {
        if (!sequential.isArmed) return const SizedBox.shrink();
        return Material(
          color: AppTheme.tealDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.content_paste, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Identifiant copié. Collez-le, puis touchez Mot de passe.',
                      style: TextStyle(color: Colors.white, height: 1.3),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await sequential.copyPasswordNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mot de passe copié — effacé dans 30 s'),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Mot de passe',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
