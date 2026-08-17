import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

class KeyboardPasteService {
  Future<void> pasteText(String text) async {
    if (!Platform.isWindows || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _sendCtrlV();
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  static bool isQuickPickHotkeyDown() {
    if (!Platform.isWindows) return false;
    final ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
    final shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    final c = (GetAsyncKeyState(0x43) & 0x8000) != 0;
    return ctrl && shift && c;
  }

  static bool isPasteHotkeyDown() {
    if (!Platform.isWindows) return false;
    final ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
    final shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    final v = (GetAsyncKeyState(0x56) & 0x8000) != 0;
    final insert = (GetAsyncKeyState(VK_INSERT) & 0x8000) != 0;
    return (ctrl && v) || (shift && insert);
  }

  void _sendCtrlV() {
    final inputs = calloc<INPUT>(4);
    try {
      inputs[0].type = INPUT_KEYBOARD;
      inputs[0].ki.wVk = VK_CONTROL;
      inputs[1].type = INPUT_KEYBOARD;
      inputs[1].ki.wVk = 0x56; // V
      inputs[2].type = INPUT_KEYBOARD;
      inputs[2].ki.wVk = 0x56;
      inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
      inputs[3].type = INPUT_KEYBOARD;
      inputs[3].ki.wVk = VK_CONTROL;
      inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(4, inputs, sizeOf<INPUT>());
    } finally {
      free(inputs);
    }
  }
}
