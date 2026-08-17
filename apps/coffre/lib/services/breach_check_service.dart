import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BreachCheckResult {
  const BreachCheckResult({
    required this.pwned,
    this.count = 0,
    this.error,
  });

  final bool pwned;
  final int count;
  final String? error;
}

class BreachCheckService {
  static const _baseUrl = 'https://api.pwnedpasswords.com/range/';

  Future<BreachCheckResult> checkPassword(String password) async {
    if (password.isEmpty) {
      return const BreachCheckResult(pwned: false);
    }
    try {
      final digest = sha1.convert(utf8.encode(password)).toString().toUpperCase();
      final prefix = digest.substring(0, 5);
      final suffix = digest.substring(5);
      final response = await http
          .get(Uri.parse('$_baseUrl$prefix'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return BreachCheckResult(
          pwned: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
      for (final line in response.body.split('\n')) {
        final parts = line.trim().split(':');
        if (parts.length != 2) continue;
        if (parts[0] == suffix) {
          return BreachCheckResult(
            pwned: true,
            count: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      return const BreachCheckResult(pwned: false);
    } catch (e) {
      return BreachCheckResult(pwned: false, error: e.toString());
    }
  }
}
