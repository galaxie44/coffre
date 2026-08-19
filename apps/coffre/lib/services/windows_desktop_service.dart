import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'foreground_window.dart';

class WindowsDesktopService with TrayListener, WindowListener {
  WindowsDesktopService({
    required this.onShowWindow,
    required this.onLock,
    required this.onQuit,
    required this.onQuickPick,
    required this.onQuickPickClosed,
  });

  final VoidCallback onShowWindow;
  final VoidCallback onLock;
  final VoidCallback onQuit;
  final Future<void> Function() onQuickPick;
  final VoidCallback onQuickPickClosed;

  bool _ready = false;
  bool _quickPickMode = false;
  bool _wasHidden = false;
  bool _windowVisible = true;
  ForegroundWindowInfo _capturedTarget = ForegroundWindowInfo.empty;

  bool get isQuickPickMode => _quickPickMode;
  ForegroundWindowInfo get capturedTarget => _capturedTarget;

  void setCapturedTarget(ForegroundWindowInfo target) {
    _capturedTarget = target;
  }

  void enrichCapturedTarget() {
    final enriched = ForegroundWindow.enrich(_capturedTarget);
    if (enriched.processName != _capturedTarget.processName) {
      _capturedTarget = enriched;
      onShowWindow();
    }
  }

  Future<void> init() async {
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(980, 700),
      minimumSize: Size(720, 520),
      center: true,
      title: 'Coffre',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      try {
        await windowManager.setIcon('assets/icon/coffre.ico');
      } catch (_) {
        try {
          await windowManager.setIcon('assets/icon/coffre.png');
        } catch (_) {}
      }
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(this);
    _windowVisible = true;

    launchAtStartup.setup(
      appName: 'Coffre',
      appPath: Platform.resolvedExecutable,
      args: const [],
    );

    trayManager.addListener(this);
    try {
      await trayManager.setIcon('assets/icon/coffre.ico');
    } catch (_) {
      try {
        await trayManager.setIcon('assets/icon/coffre.png');
      } catch (_) {}
    }
    await updateTrayTooltip(bridgeActive: false);
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'quickpick', label: 'Accès rapide (Ctrl+Shift+Espace)'),
      MenuItem.separator(),
      MenuItem(key: 'show', label: 'Ouvrir Coffre'),
      MenuItem(key: 'lock', label: 'Verrouiller'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quitter'),
    ]));
    _ready = true;
  }

  Future<void> updateTrayTooltip({required bool bridgeActive}) async {
    if (!_ready) return;
    final status = bridgeActive ? ' · extension active' : ' · extension inactive';
    await trayManager.setToolTip('Coffre$status');
  }

  Future<void> enableLaunchAtStartup(bool enabled) async {
    if (!Platform.isWindows) return;
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    if (!Platform.isWindows) return false;
    return launchAtStartup.isEnabled();
  }

  Future<void> hideToTray() async {
    if (!_ready || _quickPickMode) return;
    await windowManager.hide();
    _windowVisible = false;
  }

  Future<void> showFromTray() async {
    if (!_ready) return;
    if (_quickPickMode) {
      await _exitQuickPickMode(restoreHidden: false);
    }
    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.restore();
    } catch (_) {}
    await windowManager.show();
    await windowManager.focus();
    _windowVisible = true;
    onShowWindow();
  }

  Future<void> openQuickPick() async {
    if (!_ready) return;
    _wasHidden = !_windowVisible;
    _quickPickMode = true;

    await Future.wait([
      windowManager.setTitle('Coffre — accès rapide'),
      windowManager.setAlwaysOnTop(true),
      windowManager.show(),
    ]);
    _windowVisible = true;
    await windowManager.focus();

    unawaited(Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      enrichCapturedTarget();
    }));
  }

  Future<void> focusQuickPick() async {
    if (!_ready || !_quickPickMode) return;
    if (!_windowVisible) {
      await windowManager.show();
      _windowVisible = true;
    }
    await windowManager.focus();
  }

  Future<void> closeQuickPick() async {
    await _exitQuickPickMode(restoreHidden: _wasHidden);
  }

  Future<void> _exitQuickPickMode({required bool restoreHidden}) async {
    if (!_quickPickMode) return;
    _quickPickMode = false;
    await Future.wait([
      windowManager.setTitle('Coffre'),
      windowManager.setAlwaysOnTop(false),
    ]);
    if (restoreHidden) {
      await windowManager.hide();
      _windowVisible = false;
    }
    onQuickPickClosed();
  }

  @override
  void onWindowClose() async {
    if (_quickPickMode) {
      await closeQuickPick();
      return;
    }
    await hideToTray();
  }

  @override
  void onTrayIconMouseDown() {
    showFromTray();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'quickpick':
        unawaited(onQuickPick());
        break;
      case 'show':
        showFromTray();
        break;
      case 'lock':
        onLock();
        break;
      case 'quit':
        onQuit();
        break;
    }
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
