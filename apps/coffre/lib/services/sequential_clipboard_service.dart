import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'clipboard_service.dart';
import 'foreground_window.dart';
import 'keyboard_paste_service.dart';

/// Identifiant puis mot de passe.
/// Windows : après Ctrl+V. Android : bandeau « Copier le mot de passe ».
class SequentialClipboardService extends ChangeNotifier {
  SequentialClipboardService({
    required ClipboardService clipboard,
    KeyboardPasteService? keyboard,
  })  : _clipboard = clipboard,
        _keyboard = keyboard ?? KeyboardPasteService();

  final ClipboardService _clipboard;
  final KeyboardPasteService _keyboard;

  Timer? _pollTimer;
  String? _pendingPassword;
  bool _waitingForUsernamePaste = false;
  bool _pasteWasDown = false;

  bool get isArmed => _pendingPassword != null && _pendingPassword!.isNotEmpty;

  Future<void> start({
    required String username,
    required String password,
    int targetHwnd = 0,
    bool autoPasteUsername = false,
  }) async {
    cancel();
    _pendingPassword = password;
    _waitingForUsernamePaste = true;
    await _clipboard.copySecret(username);
    notifyListeners();

    if (Platform.isWindows) {
      _restoreTarget(targetHwnd);
      if (autoPasteUsername) {
        await _keyboard.pasteText(username);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await copyPasswordNow();
        return;
      }
      _startPastePolling();
    }
  }

  Future<void> copySingle(String value, {int targetHwnd = 0}) async {
    cancel();
    await _clipboard.copySecret(value);
    if (Platform.isWindows) _restoreTarget(targetHwnd);
    notifyListeners();
  }

  Future<void> copyPasswordNow() async {
    await _advanceToPassword();
    notifyListeners();
  }

  void cancel() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingPassword = null;
    _waitingForUsernamePaste = false;
    _pasteWasDown = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _restoreTarget(int hwnd) {
    if (!Platform.isWindows || hwnd == 0) return;
    ForegroundWindow.restore(hwnd);
  }

  void _startPastePolling() {
    if (!Platform.isWindows) return;
    _pollTimer?.cancel();
    _pasteWasDown = false;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _pollPasteHotkey();
    });
  }

  void _pollPasteHotkey() {
    if (!Platform.isWindows || !_waitingForUsernamePaste) return;
    final down = KeyboardPasteService.isPasteHotkeyDown();
    final ctrlShiftC = KeyboardPasteService.isQuickPickHotkeyDown();
    if (ctrlShiftC) return;
    if (down && !_pasteWasDown) {
      unawaited(_onUsernamePasted());
    }
    _pasteWasDown = down;
  }

  Future<void> _onUsernamePasted() async {
    if (!_waitingForUsernamePaste) return;
    _waitingForUsernamePaste = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _advanceToPassword();
    notifyListeners();
  }

  Future<void> _advanceToPassword() async {
    final pwd = _pendingPassword;
    _waitingForUsernamePaste = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (pwd == null || pwd.isEmpty) {
      _pendingPassword = null;
      return;
    }
    _pendingPassword = null;
    await _clipboard.copySecret(pwd);
  }
}
