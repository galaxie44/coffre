import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/single_instance_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SingleInstanceGuard? guard;
  if (Platform.isWindows) {
    guard = await SingleInstanceGuard.tryAcquire();
    if (guard == null) {
      await SingleInstanceGuard.requestShow();
      exit(0);
    }
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(CoffreApp(instanceGuard: guard));
}
