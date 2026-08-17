import 'dart:math';

class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#\$%^&*-_=+?';

  String generate({
    int length = 20,
    bool lower = true,
    bool upper = true,
    bool digits = true,
    bool symbols = true,
  }) {
    final pools = <String>[];
    if (lower) pools.add(_lower);
    if (upper) pools.add(_upper);
    if (digits) pools.add(_digits);
    if (symbols) pools.add(_symbols);
    if (pools.isEmpty) {
      throw ArgumentError('Au moins un jeu de caractères est requis');
    }

    final required = pools.map((p) => p[_random.nextInt(p.length)]).toList();
    final all = pools.join();
    final chars = List<String>.from(required);
    while (chars.length < length) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }
}
