import 'package:otp/otp.dart';

class TotpService {
  String? generateCode(String secret) {
    final cleaned = secret.replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    try {
      return OTP.generateTOTPCodeString(
        cleaned,
        DateTime.now().millisecondsSinceEpoch,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
    } catch (_) {
      return null;
    }
  }

  int secondsRemaining() {
    final now = DateTime.now().second;
    return 30 - (now % 30);
  }
}
