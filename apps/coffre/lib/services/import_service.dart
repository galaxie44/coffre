import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/vault_entry.dart';
import '../utils/entry_display.dart';

class ImportEntry {
  const ImportEntry({
    required this.title,
    required this.username,
    required this.password,
    required this.url,
  });

  final String title;
  final String username;
  final String password;
  final String url;

  VaultEntry toVaultEntry() {
    final normalizedUrl = url.trim();
    final displayTitle = EntryDisplay.inferTitleFromImport(
      title: title,
      url: normalizedUrl,
    );
    final base = VaultEntry.create(
      title: displayTitle,
      username: username,
      password: password,
      url: normalizedUrl,
      notes: 'Importé',
    );
    return EntryDisplay.normalize(base);
  }
}

class ImportService {
  static const _filesChannel = MethodChannel('com.coffre/files');

  Future<File> chromeImportFile() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return File(p.join(appData, 'Coffre', 'chrome_import.json'));
      }
    }
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'Coffre', 'chrome_import.json'));
  }

  Future<List<ImportEntry>> loadChromeImportFile() async {
    final file = await chromeImportFile();
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final list = raw['entries'] as List<dynamic>? ?? [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ImportEntry(
        title: m['title'] as String? ?? '',
        username: m['username'] as String? ?? '',
        password: m['password'] as String? ?? '',
        url: m['url'] as String? ?? '',
      );
    }).where((e) => e.username.isNotEmpty || e.password.isNotEmpty).toList();
  }

  Future<List<ImportEntry>?> pickGoogleCsv() async {
    try {
      final content = await _filesChannel.invokeMethod<String>('pickCsv');
      if (content == null || content.trim().isEmpty) return null;
      return parseGoogleCsv(content);
    } on PlatformException {
      return null;
    }
  }

  Future<void> clearChromeImportFile() async {
    final file = await chromeImportFile();
    if (await file.exists()) await file.delete();
  }

  List<ImportEntry> parseGoogleCsv(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return [];
    final header = _parseCsvLine(lines.first).map((h) => h.toLowerCase()).toList();
    final nameIdx = header.indexOf('name');
    final urlIdx = header.indexOf('url');
    final userIdx = header.indexOf('username');
    final passIdx = header.indexOf('password');
    if (userIdx < 0 && passIdx < 0) return [];

    final out = <ImportEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = _parseCsvLine(line);
      String col(int idx) => idx >= 0 && idx < cols.length ? cols[idx] : '';
      out.add(
        ImportEntry(
          title: col(nameIdx),
          username: col(userIdx),
          password: col(passIdx),
          url: col(urlIdx),
        ),
      );
    }
    return out.where((e) => e.username.isNotEmpty || e.password.isNotEmpty).toList();
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }
}
