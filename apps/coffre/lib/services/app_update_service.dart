import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_version.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
  });

  final String version;
  final Uri downloadUrl;
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const owner = 'galaxie44';
  static const repo = 'coffre';
  static const windowsAsset = 'Coffre-Setup-Windows.exe';
  static const _maxBytes = 80 * 1024 * 1024;

  final http.Client _client;

  static final _latestUri = Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/releases/latest',
  );

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion.normalize(info.version);
  }

  Future<AppUpdateInfo?> fetchLatest() async {
    final current = await installedVersion();
    final response = await _client
        .get(
          _latestUri,
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Coffre/$current',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    return parseLatest(response.body);
  }

  static AppUpdateInfo? parseLatest(String body) {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final tag = json['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;
    if (json['draft'] == true) return null;
    final assets = json['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      if (asset['name'] != windowsAsset) continue;
      final raw = asset['browser_download_url'] as String?;
      if (raw == null) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || !isTrustedUpdateUrl(uri)) continue;
      return AppUpdateInfo(version: AppVersion.normalize(tag), downloadUrl: uri);
    }
    return null;
  }

  Future<File> downloadInstaller(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (!isTrustedUpdateUrl(info.downloadUrl)) {
      throw const SocketException('Source de mise à jour non fiable');
    }
    final current = await installedVersion();
    final request = http.Request('GET', info.downloadUrl);
    request.headers['User-Agent'] = 'Coffre/$current';
    final response = await _client.send(request).timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw HttpException('Téléchargement HTTP ${response.statusCode}');
    }
    final total = response.contentLength ?? 0;
    if (total > _maxBytes) {
      throw const HttpException('Fichier de mise à jour trop volumineux');
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, windowsAsset));
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maxBytes) {
          throw const HttpException('Fichier de mise à jour trop volumineux');
        }
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();
    onProgress?.call(1);
    return file;
  }

  Future<void> launchInstaller(File installer) async {
    await Process.start(
      installer.path,
      const ['/SILENT', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );
  }
}
