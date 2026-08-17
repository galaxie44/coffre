import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/vault_entry.dart';
import 'vault_service.dart';

/// Localhost bridge for the browser extension (Windows).
class BridgeService {
  BridgeService(this.vault);

  final VaultService vault;
  HttpServer? _server;
  String? _token;
  int? _port;

  int? get port => _port;
  String? get token => _token;
  bool get isRunning => _server != null;

  Future<File> _bridgeFile() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        final bridgeDir = Directory(p.join(appData, 'Coffre'));
        if (!await bridgeDir.exists()) await bridgeDir.create(recursive: true);
        return File(p.join(bridgeDir.path, 'bridge.json'));
      }
    }
    final dir = await getApplicationSupportDirectory();
    final bridgeDir = Directory(p.join(dir.path, 'Coffre'));
    if (!await bridgeDir.exists()) await bridgeDir.create(recursive: true);
    return File(p.join(bridgeDir.path, 'bridge.json'));
  }

  Future<void> start() async {
    if (!Platform.isWindows) return;
    await stop();
    _token = _randomToken();
    final router = Router();

    router.get('/health', (Request request) {
      if (!_authorized(request)) {
        return Response.forbidden(jsonEncode({'error': 'forbidden'}));
      }
      return Response.ok(
        jsonEncode({
          'ok': true,
          'unlocked': vault.isUnlocked,
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    router.get('/credentials', (Request request) {
      if (!_authorized(request)) {
        return Response.forbidden(jsonEncode({'error': 'forbidden'}));
      }
      if (!vault.isUnlocked) {
        return Response(
          401,
          body: jsonEncode({'error': 'locked', 'message': 'Déverrouillez Coffre'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final domain = request.url.queryParameters['domain'] ?? '';
      final matches = vault.matchForDomain(domain);
      return Response.ok(
        jsonEncode({
          'domain': domain,
          'entries': matches.map(_publicEntry).toList(),
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    router.get('/entries', (Request request) {
      if (!_authorized(request)) {
        return Response.forbidden(jsonEncode({'error': 'forbidden'}));
      }
      if (!vault.isUnlocked) {
        return Response(
          401,
          body: jsonEncode({'error': 'locked', 'message': 'Déverrouillez Coffre'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return Response.ok(
        jsonEncode({
          'entries': vault.entries.map(_publicEntry).toList(),
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/save', (Request request) async {
      if (!_authorized(request)) {
        return Response.forbidden(jsonEncode({'error': 'forbidden'}));
      }
      if (!vault.isUnlocked) {
        return Response(
          401,
          body: jsonEncode({'error': 'locked', 'message': 'Déverrouillez Coffre'}),
          headers: {'content-type': 'application/json'},
        );
      }
      try {
        final raw = jsonDecode(await request.readAsString());
        if (raw is! Map) {
          return Response.badRequest(body: jsonEncode({'error': 'invalid'}));
        }
        final body = Map<String, dynamic>.from(raw);
        final username = (body['username'] as String? ?? '').trim();
        final password = body['password'] as String? ?? '';
        if (username.isEmpty || password.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'missing'}));
        }
        final result = await vault.saveCapturedCredential(
          username: username,
          password: password,
          url: body['url'] as String? ?? '',
          domain: body['domain'] as String? ?? '',
        );
        return Response.ok(
          jsonEncode(result),
          headers: {'content-type': 'application/json'},
        );
      } catch (_) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'save_failed'}),
        );
      }
    });

    _server = await shelf_io.serve(router.call, InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    final file = await _bridgeFile();
    await file.writeAsString(
      jsonEncode({
        'port': _port,
        'token': _token,
        'pid': pid,
      }),
      flush: true,
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _token = null;
    try {
      final file = await _bridgeFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  bool _authorized(Request request) {
    final header = request.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) return false;
    return header.substring(7) == _token;
  }

  Map<String, dynamic> _publicEntry(VaultEntry e) => {
        'id': e.id,
        'title': e.title,
        'username': e.username,
        'password': e.password,
        'url': e.url,
        'domain': e.domain,
        'windowsProcess': e.windowsProcess,
        'windowsTitleHint': e.windowsTitleHint,
      };

  String _randomToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

String base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
