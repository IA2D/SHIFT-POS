import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  const PasswordHasher({this.iterations = 50000});

  final int iterations;

  String hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final digest = _derive(password, salt);
    return 'pbkdf2-sha256\$$iterations\$${base64UrlEncode(salt)}'
        '\$${base64UrlEncode(digest)}';
  }

  bool verify(String password, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts.first != 'pbkdf2-sha256') return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds <= 0) return false;
    try {
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      final actual = PasswordHasher(iterations: rounds)._derive(password, salt);
      if (actual.length != expected.length) return false;
      var difference = 0;
      for (var index = 0; index < actual.length; index++) {
        difference |= actual[index] ^ expected[index];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  Uint8List _derive(String password, List<int> salt) {
    final key = utf8.encode(password);
    final block = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + 4, const [0, 0, 0, 1]);
    final hmac = Hmac(sha256, key);
    var current = Uint8List.fromList(hmac.convert(block).bytes);
    final result = Uint8List.fromList(current);
    for (var round = 1; round < iterations; round++) {
      current = Uint8List.fromList(hmac.convert(current).bytes);
      for (var index = 0; index < result.length; index++) {
        result[index] ^= current[index];
      }
    }
    return result;
  }
}
