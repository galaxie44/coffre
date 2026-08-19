import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_version.dart';

enum UpdateCheckResult { upToDate, available, failed, busy }

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({required this.onQuit});

  final Future<void> Function() onQuit;
  final AppUpdateService _service = AppUpdateService();

  AppUpdateInfo? info;
  String currentVersion = '';
  bool downloading = false;
  bool _checking = false;
  double? progress;
  String? error;

  bool get visible => info != null || error != null;

  /// [silent] : pas de bandeau d’erreur si le réseau est indisponible
  /// (lancement / reprise). En manuel, l’échec est affiché.
  Future<UpdateCheckResult> checkAndInstall({bool silent = true}) async {
    if (_checking || downloading) return UpdateCheckResult.busy;
    _checking = true;
    error = null;
    notifyListeners();
    try {
      currentVersion = await _service.installedVersion();
      notifyListeners();
      final latest = await _service.fetchLatest();
      if (!AppVersion.isNewer(latest.version, currentVersion)) {
        info = null;
        notifyListeners();
        return UpdateCheckResult.upToDate;
      }
      info = latest;
      notifyListeners();
      if (Platform.isWindows) {
        await install();
      }
      return UpdateCheckResult.available;
    } catch (_) {
      if (!silent) {
        error = 'Impossible de vérifier la mise à jour (réseau).';
        notifyListeners();
      }
      return UpdateCheckResult.failed;
    } finally {
      _checking = false;
    }
  }

  Future<void> install() async {
    final update = info;
    if (update == null || downloading) return;
    downloading = true;
    progress = null;
    error = null;
    notifyListeners();
    try {
      final file = await _service.downloadInstaller(
        update,
        onProgress: (value) {
          progress = value;
          notifyListeners();
        },
      );
      await _service.launchInstaller(file);
      downloading = false;
      notifyListeners();
      if (Platform.isWindows) await onQuit();
    } on PlatformException catch (e) {
      downloading = false;
      if (e.code == 'permission') {
        error = e.message ??
            'Autorisez Coffre à installer des applications, puis touchez pour réessayer.';
      } else {
        error = e.message ?? 'Installation impossible. Touchez pour réessayer.';
      }
      notifyListeners();
    } catch (_) {
      downloading = false;
      error = 'Téléchargement impossible. Touchez pour réessayer.';
      notifyListeners();
    }
  }
}

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key, required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();
        final info = controller.info;
        final downloading = controller.downloading;
        final err = controller.error;
        final label = err ??
            (downloading
                ? 'Téléchargement de ${info?.version ?? 'la mise à jour'}…'
                : Platform.isAndroid
                    ? 'Mise à jour ${info?.headline ?? ''} — touchez pour installer. En cas de conflit de signature, désinstallez Coffre puis réinstallez.'
                    : 'Mise à jour ${info?.headline ?? ''} — installation automatique');
        return Material(
          color: err != null ? AppTheme.danger : AppTheme.teal,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: downloading ? null : controller.install,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          err != null ? Icons.error_outline : Icons.system_update_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (downloading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: controller.progress,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.28),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
