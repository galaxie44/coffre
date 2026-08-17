import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/biometric_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';

class DangerScreen extends StatefulWidget {
  const DangerScreen({
    super.key,
    required this.vault,
    required this.biometric,
    required this.onWiped,
  });

  final VaultService vault;
  final BiometricService biometric;
  final VoidCallback onWiped;

  @override
  State<DangerScreen> createState() => _DangerScreenState();
}

class _DangerScreenState extends State<DangerScreen> {
  final _passwordCtrl = TextEditingController();
  bool _ack1 = false;
  bool _ack2 = false;
  bool _busy = false;
  String? _error;
  static const _channel = MethodChannel('com.coffre/danger');

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _wipe() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final ok = await widget.vault.verifyMasterPassword(_passwordCtrl.text);
      if (!ok) {
        setState(() => _error = 'Mot de passe maître incorrect');
        return;
      }
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dernière confirmation'),
          content: const Text(
            'Toutes les données du coffre seront écrasées puis supprimées. Cette action est irréversible.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tout effacer'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      if (!mounted) return;

      await widget.vault.wipeCompletely();
      await widget.biometric.clearAll();

      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('requestUninstall');
        } catch (_) {}
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Coffre effacé'),
          content: Text(
            Platform.isAndroid
                ? 'Les données ont été détruites. Confirmez la désinstallation dans la fenêtre système si elle apparaît, ou désinstallez Coffre depuis les paramètres.'
                : 'Les données ont été détruites. Désinstallez Coffre via Paramètres Windows → Applications pour retirer le programme.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      widget.onWiped();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWipe = _ack1 && _ack2 && _passwordCtrl.text.isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone danger'),
        backgroundColor: AppTheme.danger.withValues(alpha: 0.08),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Effacer complètement le coffre',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cette action écrase le fichier chiffré, efface le cache autofill, puis tente de désinstaller l’application (confirmation système requise).',
            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _ack1,
            onChanged: (v) => setState(() => _ack1 = v ?? false),
            title: const Text('Je comprends que toutes les entrées seront perdues'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _ack2,
            onChanged: (v) => setState(() => _ack2 = v ?? false),
            title: const Text('Je comprends qu’il n’existe aucun moyen de récupération'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Saisir le mot de passe maître',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: canWipe ? _wipe : null,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Effacer tout et désinstaller'),
          ),
        ],
      ),
    );
  }
}
