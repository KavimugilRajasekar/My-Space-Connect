import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mirror the XOR encryption logic from qr_popup.dart
  String encryptData(String data, String key) {
    final dataBytes = data.codeUnits;
    final keyBytes = key.codeUnits;
    final result = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      result.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return result.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

  List<int> hexToBytes(String hexString) {
    final bytes = <int>[];
    for (int i = 0; i < hexString.length; i += 2) {
      final hexPair = hexString.substring(i, i + 2);
      bytes.add(int.parse(hexPair, radix: 16));
    }
    return bytes;
  }

  String decryptData(String hexData, String key) {
    final dataBytes = hexToBytes(hexData);
    final keyBytes = key.codeUnits;
    final result = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      result.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return String.fromCharCodes(result);
  }

  const encryptionKey = 'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780';

  group('QR Encryption / Decryption', () {
    test('encrypts and decrypts user data correctly', () {
      final payload = '{"name":"Alice","uuid":"abc-123","profileImage":""}';

      final encrypted = encryptData(payload, encryptionKey);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(payload)));

      final decrypted = decryptData(encrypted, encryptionKey);
      expect(decrypted, equals(payload));
    });

    test('encrypted output is hex-encoded', () {
      final payload = '{"test":"data"}';
      final encrypted = encryptData(payload, encryptionKey);

      // Every pair of characters should be valid hex
      expect(encrypted.length % 2, 0);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(encrypted), true);
    });

    test('same input produces same output (deterministic)', () {
      final payload = '{"name":"Bob"}';

      final encrypted1 = encryptData(payload, encryptionKey);
      final encrypted2 = encryptData(payload, encryptionKey);

      expect(encrypted1, equals(encrypted2));
    });

    test('different payloads produce different ciphertext', () {
      final payload1 = '{"name":"Alice"}';
      final payload2 = '{"name":"Bob"}';

      final encrypted1 = encryptData(payload1, encryptionKey);
      final encrypted2 = encryptData(payload2, encryptionKey);

      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('handles special characters in name', () {
      final payload = '{"name":"Alice O\'Brien","uuid":"xyz","profileImage":""}';

      final encrypted = encryptData(payload, encryptionKey);
      final decrypted = decryptData(encrypted, encryptionKey);

      expect(decrypted, equals(payload));
    });

    test('handles empty profile image', () {
      final payload = '{"name":"Test","uuid":"123","profileImage":""}';

      final encrypted = encryptData(payload, encryptionKey);
      final decrypted = decryptData(encrypted, encryptionKey);

      expect(decrypted, contains('"name":"Test"'));
      expect(decrypted, contains('"profileImage":""'));
    });

    test('XOR decryption with wrong key fails', () {
      final payload = '{"name":"Secret"}';
      const wrongKey = '0000000000000000000000000000000000000000000000000000000000000000';

      final encrypted = encryptData(payload, encryptionKey);
      final decrypted = decryptData(encrypted, wrongKey);

      expect(decrypted, isNot(equals(payload)));
    });
  });
}
