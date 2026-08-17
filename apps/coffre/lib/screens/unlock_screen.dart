import 'dart:io';

import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.vault,
    required this.biometric,
  });

  final VaultService vault;
  final BiometricService biometric;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.biometric.addListener(_onBio);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.biometric.isEnabled) {
        _unlockBiometric();
      }
    });
  }

  @override
  void dispose() {
    widget.biometric.removeListener(_onBio);
    _ctrl.dispose();
    super.dispose();
  }

  void _onBio() {
    if (mounted) setState(() {});
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vault.unlock(_ctrl.text);
      _ctrl.clear();
    } catch (_) {
      final next = widget.vault.unlockBackoff();
      setState(() {
        _error = next > Duration.zero
            ? 'Mot de passe incorrect. Nouvel essai possible après ${next.inSeconds}s.'
            : 'Mot de passe incorrect ou coffre illisible';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockBiometric() async {
    if (_busy || !widget.biometric.isEnabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final secret = await widget.biometric.unlockWithBiometrics();
      if (secret == null) {
        setState(() => _error = 'Authentification biométrique annulée');
        return;
      }
      await widget.vault.unlock(secret);
    } catch (_) {
      setState(() => _error = 'Échec du déverrouillage biométrique');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.vault.unlockBackoff();
    final bioLabel = Platform.isWindows ? 'Windows Hello' : 'Empreinte / Face';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8EEF2), Color(0xFFD8E8E6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 88)),
                    const SizedBox(height: 12),
                    Text(
                      'Coffre verrouillé',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (pending > Duration.zero) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Protection anti-bruteforce active (${pending.inSeconds}s).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.65)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ctrl,
                      obscureText: _obscure,
                      enabled: !_busy,
                      onSubmitted: (_) => _unlock(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe maître',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Déverrouiller'),
                    ),
                    if (widget.biometric.isEnabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _unlockBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(bioLabel),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
