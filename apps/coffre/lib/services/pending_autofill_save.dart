import 'dart:io';

import 'package:flutter/services.dart';

class PendingAutofillSave {
  PendingAutofillSave({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.coffre/autofill');

  final MethodChannel _channel;

  Future<Map<String, String>?> fetch() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('getPendingSave');
      if (raw == null) return null;
      return {
        'packageName': raw['packageName']?.toString() ?? '',
        'username': raw['username']?.toString() ?? '',
        'password': raw['password']?.toString() ?? '',
        'webDomain': raw['webDomain']?.toString() ?? '',
        'action': raw['action']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearPendingSave');
    } catch (_) {}
  }
}
