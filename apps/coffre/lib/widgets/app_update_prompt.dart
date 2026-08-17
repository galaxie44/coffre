import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_version.dart';

class AppUpdatePrompt {
  AppUpdatePrompt._();

  static Future<AppUpdateInfo?> check({
    required BuildContext context,
    required PreferencesService preferences,
    Future<void> Function()? onQuit,
    bool manual = false,
  }) async {
    final service = AppUpdateService();
    try {
      final current = await service.installedVersion();
      final latest = await service.fetchLatest();
      if (!context.mounted) return null;
      if (latest == null || !AppVersion.isNewer(latest.version, current)) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coffre est à jour ($current)')),
          );
        }
        return null;
      }
      if (!manual && preferences.prefs.skippedUpdateVersion == latest.version) {
        return latest;
      }
      await show(
        context: context,
        preferences: preferences,
        info: latest,
        currentVersion: current,
        onQuit: onQuit ?? () async {},
        service: service,
        allowSkip: !manual,
      );
      return latest;
    } catch (_) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de vérifier les mises à jour (réseau).'),
          ),
        );
      }
      return null;
    }
  }

  static Future<void> show({
    required BuildContext context,
    required PreferencesService preferences,
    required AppUpdateInfo info,
    required String currentVersion,
    required Future<void> Function() onQuit,
    AppUpdateService? service,
    bool allowSkip = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(
        info: info,
        currentVersion: currentVersion,
        preferences: preferences,
        onQuit: onQuit,
        service: service ?? AppUpdateService(),
        allowSkip: allowSkip,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.info,
    required this.currentVersion,
    required this.preferences,
    required this.onQuit,
    required this.service,
    required this.allowSkip,
  });

  final AppUpdateInfo info;
  final String currentVersion;
  final PreferencesService preferences;
  final Future<void> Function() onQuit;
  final AppUpdateService service;
  final bool allowSkip;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final file = await widget.service.downloadInstaller(
        widget.info,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      await widget.service.launchInstaller(file);
      if (Platform.isWindows) {
        await widget.onQuit();
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Téléchargement impossible. Réessayez plus tard.';
        });
      }
    }
  }

  Future<void> _later() async {
    if (widget.allowSkip) {
      await widget.preferences.setSkippedUpdateVersion(widget.info.version);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_downloading ? 'Téléchargement…' : 'Mise à jour disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _downloading
                ? (Platform.isAndroid
                    ? 'Android va demander d’installer Coffre ${widget.info.version}.'
                    : 'Coffre va se fermer pour installer la version ${widget.info.version}.')
                : '${widget.info.headline} est prête (vous avez ${widget.currentVersion}). Vos mots de passe restent sur cet appareil.',
            style: const TextStyle(height: 1.4),
          ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              color: AppTheme.teal,
              backgroundColor: AppTheme.ink.withValues(alpha: 0.08),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: _later,
            child: Text(widget.allowSkip ? 'Plus tard' : 'Fermer'),
          ),
        if (!_downloading)
          FilledButton(
            onPressed: _install,
            child: const Text('Installer'),
          ),
      ],
    );
  }
}
