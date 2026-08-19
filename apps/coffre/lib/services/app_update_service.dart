import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_version.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.title,
    required this.downloadUrl,
    required this.fileName,
  });

  final String version;
  final String title;
  final Uri downloadUrl;
  final String fileName;

  String get headline => title.trim().isEmpty ? 'Coffre $version' : title;
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const owner = 'galaxie44';
  static const repo = 'coffre';
  static const windowsAsset = 'Coffre-Setup-Windows.exe';
  static const androidAsset = 'Coffre.apk';
  static const _maxBytes = 80 * 1024 * 1024;
  static const _installChannel = MethodChannel('com.coffre/updates');

  final http.Client _client;

  static String get platformAsset =>
      Platform.isAndroid ? androidAsset : windowsAsset;

  static final _releasesUri = Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/releases',
    {'per_page': '30'},
  );

  static final _latestUri = Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/releases/latest',
  );

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion.normalize(info.version);
  }

  static final _tagInPath = RegExp(r'/releases/tag/([^/?#]+)');

  static String? tagFromLatestLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    return _tagInPath.firstMatch(path)?.group(1);
  }

  Future<AppUpdateInfo> fetchLatest() async {
    Object? lastError;
    try {
      final fromApi = await _fetchFromApi();
      if (fromApi != null) return fromApi;
    } catch (e) {
      lastError = e;
    }
    try {
      final fromPage = await _fetchFromRedirect();
      if (fromPage != null) return fromPage;
    } catch (e) {
      lastError = e;
    }
    throw lastError ?? const SocketException('Impossible de joindre GitHub');
  }

  Future<AppUpdateInfo?> _fetchFromApi() async {
    final current = await installedVersion();
    final headers = {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Coffre/$current',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    final response = await _client
        .get(_releasesUri, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('GitHub ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      AppUpdateInfo? newest;
      for (final release in decoded) {
        if (release is! Map) continue;
        final info = parseRelease(release, assetName: platformAsset);
        if (info == null) continue;
        if (newest == null || AppVersion.isNewer(info.version, newest.version)) {
          newest = info;
        }
      }
      return newest;
    }
    if (decoded is Map) {
      return parseRelease(decoded, assetName: platformAsset);
    }
    return null;
  }

  Future<AppUpdateInfo?> _fetchFromRedirect() async {
    final current = await installedVersion();
    final request = http.Request(
      'GET',
      Uri.https('github.com', '/$owner/$repo/releases/latest'),
    );
    request.followRedirects = false;
    request.headers['User-Agent'] = 'Coffre/$current';
    request.headers['Accept'] = 'text/html';
    final response =
        await _client.send(request).timeout(const Duration(seconds: 12));
    await response.stream.drain<void>();
    final tag = tagFromLatestLocation(response.headers['location']) ??
        tagFromLatestLocation(response.request?.url.toString());
    if (tag == null || tag.isEmpty) return null;
    final version = AppVersion.normalize(tag);
    final tagForUrl =
        tag.startsWith('v') || tag.startsWith('V') ? tag : 'v$version';
    final downloadUrl = Uri.https(
      'github.com',
      '/$owner/$repo/releases/download/$tagForUrl/$platformAsset',
    );
    if (!isTrustedUpdateUrl(downloadUrl)) return null;
    return AppUpdateInfo(
      version: version,
      title: 'Coffre $version',
      downloadUrl: downloadUrl,
      fileName: platformAsset,
    );
  }

  static AppUpdateInfo? parseLatest(
    String body, {
    String assetName = windowsAsset,
  }) {
    final json = jsonDecode(body);
    if (json is Map) return parseRelease(json, assetName: assetName);
    return null;
  }

  static AppUpdateInfo? parseRelease(
    Map<dynamic, dynamic> json, {
    String assetName = windowsAsset,
  }) {
    final tag = json['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;
    if (json['draft'] == true) return null;
    final title = (json['name'] as String?)?.trim() ?? '';
    final assets = json['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      if (asset['name'] != assetName) continue;
      final raw = asset['browser_download_url'] as String?;
      if (raw == null) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || !isTrustedUpdateUrl(uri)) continue;
      return AppUpdateInfo(
        version: AppVersion.normalize(tag),
        title: title,
        downloadUrl: uri,
        fileName: assetName,
      );
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
    final file = File(p.join(dir.path, info.fileName));
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
    if (Platform.isAndroid) {
      await _installChannel.invokeMethod<void>('installApk', {
        'path': installer.path,
      });
      return;
    }
    await Process.start(
      installer.path,
      const ['/SILENT', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );
  }
}
