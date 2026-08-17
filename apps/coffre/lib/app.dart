import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/quick_pick_overlay.dart';
import 'screens/unlock_screen.dart';
import 'services/auto_lock_service.dart';
import 'services/biometric_service.dart';
import 'services/bridge_service.dart';
import 'services/clipboard_service.dart';
import 'services/global_autofill_service.dart';
import 'services/preferences_service.dart';
import 'services/sequential_clipboard_service.dart';
import 'services/single_instance_guard.dart';
import 'services/vault_service.dart';
import 'services/foreground_window.dart';
import 'services/windows_desktop_service.dart';
import 'theme/app_theme.dart';

class CoffreApp extends StatefulWidget {
  const CoffreApp({super.key, this.instanceGuard});

  final SingleInstanceGuard? instanceGuard;

  @override
  State<CoffreApp> createState() => _CoffreAppState();
}

class _CoffreAppState extends State<CoffreApp> with WidgetsBindingObserver {
  final VaultService _vault = VaultService();
  final ClipboardService _clipboard = ClipboardService();
  late final SequentialClipboardService _sequentialClipboard =
      SequentialClipboardService(clipboard: _clipboard);
  final BiometricService _biometric = BiometricService();
  final PreferencesService _preferences = PreferencesService();

  late final AutoLockService _autoLock;
  late final BridgeService _bridge;
  GlobalAutofillService? _globalAutofill;
  WindowsDesktopService? _windows;

  bool _booting = true;
  bool _vaultExists = false;
  bool _quickPickVisible = false;
  bool _quickPickWarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockService(onLock: _lock);
    _bridge = BridgeService(_vault);
    _vault.addListener(_onVaultChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _preferences.load();
    await _biometric.init();
    final exists = await _vault.vaultExists();

    if (Platform.isWindows) {
      _windows = WindowsDesktopService(
        onShowWindow: () => setState(() {}),
        onLock: _lock,
        onQuit: _quit,
        onQuickPick: _triggerQuickPick,
        onQuickPickClosed: _onQuickPickClosed,
      );
      await _windows!.init();
      widget.instanceGuard?.listenForShow(() {
        unawaited(_windows?.showFromTray());
      });
      _globalAutofill = GlobalAutofillService(onQuickPick: _triggerQuickPick);
      _globalAutofill!.start();
      _quickPickWarm = true;

      final enabled = await _windows!.isLaunchAtStartupEnabled();
      if (!enabled) {
        await _windows!.enableLaunchAtStartup(true);
      }
    }

    if (mounted) {
      setState(() {
        _vaultExists = exists;
        _booting = false;
      });
    }
  }

  Future<void> _triggerQuickPick() async {
    if (!_vault.isUnlocked) {
      if (_windows != null && !_quickPickVisible) {
        unawaited(_windows!.showFromTray());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déverrouillez Coffre pour utiliser l’accès rapide'),
          ),
        );
      }
      return;
    }

    if (_quickPickVisible) {
      await _windows?.focusQuickPick();
      return;
    }

    final captured =
        _globalAutofill?.consumePendingTarget() ?? ForegroundWindow.captureQuick();
    _windows?.setCapturedTarget(captured);

    if (mounted) {
      setState(() => _quickPickVisible = true);
    }

    unawaited(_windows?.openQuickPick());
  }

  void _onQuickPickClosed() {
    if (mounted) setState(() => _quickPickVisible = false);
  }

  Future<void> _closeQuickPick() async {
    if (mounted && _quickPickVisible) {
      setState(() => _quickPickVisible = false);
    }
    await _windows?.closeQuickPick();
  }

  void _onVaultChanged() {
    if (!mounted) return;

    if (_vault.isUnlocked) {
      final seconds = _vault.payload?.autoLockSeconds ?? 60;
      _autoLock.configure(seconds: seconds, enabled: seconds > 0);
      _bridge.start();
      _windows?.updateTrayTooltip(bridgeActive: true);
      if (Platform.isAndroid) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } else {
      _autoLock.stop();
      _bridge.stop();
      _sequentialClipboard.cancel();
      _windows?.updateTrayTooltip(bridgeActive: false);
      if (_quickPickVisible) _closeQuickPick();
    }

    setState(() {});
  }

  Future<void> _lock() async {
    await _vault.lock();
    await _bridge.stop();
    final exists = await _vault.vaultExists();
    if (mounted) setState(() => _vaultExists = exists);
  }

  Future<void> _quit() async {
    await _bridge.stop();
    _globalAutofill?.dispose();
    await _windows?.dispose();
    await _vault.lock();
    exit(0);
  }

  void _activity() => _autoLock.bump();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Windows : masquer dans le tray ne doit pas verrouiller.
    if (Platform.isWindows) return;
    // Android : ne pas verrouiller dès que l’app passe en arrière-plan.
    // Sinon le clavier / autofill et la copie identifiant → mot de passe
    // ne fonctionnent plus une fois dans Chrome ou une autre app.
    if (state == AppLifecycleState.paused && _vault.isUnlocked) {
      if (_sequentialClipboard.isArmed) {
        _autoLock.bump();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vault.removeListener(_onVaultChanged);
    _autoLock.dispose();
    _clipboard.dispose();
    _sequentialClipboard.dispose();
    _biometric.dispose();
    _globalAutofill?.dispose();
    _bridge.stop();
    _windows?.dispose();
    widget.instanceGuard?.dispose();
    super.dispose();
  }

  Widget _buildHome() {
    if (!_vaultExists && !_vault.isUnlocked) {
      return OnboardingScreen(vault: _vault);
    }
    if (_vault.isUnlocked) {
      return HomeScreen(
        vault: _vault,
        clipboard: _clipboard,
        sequentialClipboard: _sequentialClipboard,
        biometric: _biometric,
        preferences: _preferences,
        onLock: _lock,
        onActivity: _activity,
        windows: _windows,
        onQuitForUpdate: _quit,
      );
    }
    return UnlockScreen(vault: _vault, biometric: _biometric);
  }

  Widget _buildQuickPick() {
    return QuickPickShortcuts(
      onClose: _closeQuickPick,
      child: QuickPickOverlay(
        vault: _vault,
        sequentialClipboard: _sequentialClipboard,
        preferences: _preferences,
        targetWindow: _windows!.capturedTarget,
        isActive: _quickPickVisible,
        onClose: _closeQuickPick,
      ),
    );
  }

  Widget _buildShell() {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final showQuickPick = _quickPickWarm && _vault.isUnlocked && _windows != null;

    return IndexedStack(
      index: _quickPickVisible && showQuickPick ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        _buildHome(),
        if (showQuickPick) _buildQuickPick() else const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffre',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _activity(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildShell(),
    );
  }
}
