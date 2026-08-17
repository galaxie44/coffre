import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Une seule instance. Un second lancement réaffiche la fenêtre déjà ouverte.
class SingleInstanceGuard {
  SingleInstanceGuard._(this._socket);

  static const port = 47891;
  static const showCommand = 'SHOW';

  final ServerSocket _socket;
  StreamSubscription<Socket>? _sub;

  static Future<SingleInstanceGuard?> tryAcquire() async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      return SingleInstanceGuard._(socket);
    } on SocketException {
      return null;
    }
  }

  void listenForShow(void Function() onShow) {
    _sub = _socket.listen((client) {
      client.listen((_) {
        onShow();
      }, onDone: () {
        onShow();
      });
    });
  }

  static Future<void> requestShow() async {
    try {
      final client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 400),
      );
      client.add(utf8.encode(showCommand));
      await client.flush();
      await client.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _socket.close();
  }
}
