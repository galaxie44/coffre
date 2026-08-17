import 'dart:async';

import 'package:flutter/services.dart';

class ClipboardService {
  Timer? _clearTimer;

  Future<void> copySecret(String value, {Duration clearAfter = const Duration(seconds: 30)}) async {
    await Clipboard.setData(ClipboardData(text: value));
    _clearTimer?.cancel();
    _clearTimer = Timer(clearAfter, () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void dispose() {
    _clearTimer?.cancel();
  }
}
