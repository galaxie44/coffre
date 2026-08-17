import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPreferences {
  AppPreferences({
    this.autoPasteEnabled = false,
    this.breachCheckEnabled = false,
    this.chromeAutoImportEnabled = false,
    this.skippedUpdateVersion = '',
  });

  final bool autoPasteEnabled;
  final bool breachCheckEnabled;
  final bool chromeAutoImportEnabled;
  final String skippedUpdateVersion;

  AppPreferences copyWith({
    bool? autoPasteEnabled,
    bool? breachCheckEnabled,
    bool? chromeAutoImportEnabled,
    String? skippedUpdateVersion,
  }) {
    return AppPreferences(
      autoPasteEnabled: autoPasteEnabled ?? this.autoPasteEnabled,
      breachCheckEnabled: breachCheckEnabled ?? this.breachCheckEnabled,
      chromeAutoImportEnabled:
          chromeAutoImportEnabled ?? this.chromeAutoImportEnabled,
      skippedUpdateVersion: skippedUpdateVersion ?? this.skippedUpdateVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoPasteEnabled': autoPasteEnabled,
        'breachCheckEnabled': breachCheckEnabled,
        'chromeAutoImportEnabled': chromeAutoImportEnabled,
        'skippedUpdateVersion': skippedUpdateVersion,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      autoPasteEnabled: json['autoPasteEnabled'] as bool? ?? false,
      breachCheckEnabled: json['breachCheckEnabled'] as bool? ?? false,
      chromeAutoImportEnabled: json['chromeAutoImportEnabled'] as bool? ?? false,
      skippedUpdateVersion: json['skippedUpdateVersion'] as String? ?? '',
    );
  }
}

class PreferencesService {
  AppPreferences _prefs = AppPreferences();

  AppPreferences get prefs => _prefs;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'Coffre'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return File(p.join(folder.path, 'preferences.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      _prefs = AppPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
      );
    } catch (_) {}
  }

  Future<void> save(AppPreferences prefs) async {
    _prefs = prefs;
    final file = await _file();
    await file.writeAsString(jsonEncode(prefs.toJson()), flush: true);
  }

  Future<void> setAutoPaste(bool value) async {
    await save(_prefs.copyWith(autoPasteEnabled: value));
  }

  Future<void> setBreachCheck(bool value) async {
    await save(_prefs.copyWith(breachCheckEnabled: value));
  }

  Future<void> setChromeAutoImport(bool value) async {
    await save(_prefs.copyWith(chromeAutoImportEnabled: value));
  }

  Future<void> setSkippedUpdateVersion(String value) async {
    await save(_prefs.copyWith(skippedUpdateVersion: value));
  }
}
