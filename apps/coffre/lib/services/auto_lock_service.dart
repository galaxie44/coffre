import 'dart:async';

import 'package:flutter/foundation.dart';

class AutoLockService extends ChangeNotifier {
  AutoLockService({required this.onLock});

  final VoidCallback onLock;
  Timer? _timer;
  int _seconds = 60;
  bool _enabled = true;

  int get seconds => _seconds;

  void configure({required int seconds, bool enabled = true}) {
    _seconds = seconds;
    _enabled = enabled;
    bump();
  }

  void bump() {
    _timer?.cancel();
    if (!_enabled || _seconds <= 0) return;
    _timer = Timer(Duration(seconds: _seconds), () {
      onLock();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
