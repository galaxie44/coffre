import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import 'foreground_window.dart';

typedef QuickPickCallback = Future<void> Function();

class GlobalAutofillService {
  GlobalAutofillService({required this.onQuickPick});

  final QuickPickCallback onQuickPick;

  Timer? _pollTimer;
  bool _comboWasDown = false;
  bool _busy = false;
  DateTime? _lastTrigger;

  /// Fenêtre cible capturée au moment exact du raccourci.
  ForegroundWindowInfo _pendingTarget = ForegroundWindowInfo.empty;

  /// Consomme la capture faite par le raccourci (avant que Coffre prenne le focus).
  ForegroundWindowInfo? consumePendingTarget() {
    if (_pendingTarget.hwnd == 0) return null;
    final target = _pendingTarget;
    _pendingTarget = ForegroundWindowInfo.empty;
    return target;
  }

  void start() {
    if (!Platform.isWindows) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      _pollHotkey();
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _comboWasDown = false;
    _busy = false;
  }

  void dispose() => stop();

  void _pollHotkey() {
    if (_busy) return;

    final ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
    final shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    final space = (GetAsyncKeyState(VK_SPACE) & 0x8000) != 0;
    final down = ctrl && shift && space;

    if (down && !_comboWasDown) {
      final now = DateTime.now();
      if (_lastTrigger != null &&
          now.difference(_lastTrigger!) < const Duration(milliseconds: 280)) {
        _comboWasDown = down;
        return;
      }
      _lastTrigger = now;
      _pendingTarget = ForegroundWindow.captureQuick();
      _busy = true;
      unawaited(_invokeQuickPick());
    }
    _comboWasDown = down;
  }

  Future<void> _invokeQuickPick() async {
    try {
      await onQuickPick();
    } catch (e, st) {
      debugPrint('Coffre quick pick: $e\n$st');
    } finally {
      _busy = false;
    }
  }
}
