import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/string_coder.dart';
import 'package:test/test.dart';

void main() {
  final coder = StringCoder();

  group('StringCoder isDynamic', () {
    test('isDynamic is true', () {
      expect(coder.isDynamic, isTrue);
    });
  });

  group('StringCoder encode', () {
    test('"Hello, world!" matches ethers.js reference', () {
      final result = coder.encode('Hello, world!');
      expect(result.encoded.length, 64);
      expect(result.isDynamic, isTrue);

      final hex = BytesUtils.toHexString(result.encoded);
      // length = 13 (0x0d)
      expect(
        hex.substring(0, 64),
        '000000000000000000000000000000000000000000000000000000000000000d',
      );
      // "Hello, world!" in UTF-8: 48 65 6c 6c 6f 2c 20 77 6f 72 6c 64 21
      expect(
        hex.substring(64),
        '48656c6c6f2c20776f726c642100000000000000000000000000000000000000',
      );
    });

    test('empty string produces 32 bytes (length=0 only)', () {
      final result = coder.encode('');
      expect(result.encoded.length, 32);
      expect(
        BytesUtils.toHexString(result.encoded),
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('rejects non-String input', () {
      expect(() => coder.encode(42), throwsA(isA<AbiException>()));
    });
  });

  group('StringCoder decode', () {
    test('roundtrip "Hello, world!"', () {
      final encoded = coder.encode('Hello, world!');
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, 'Hello, world!');
      expect(decoded.consumed, 32);
    });

    test('roundtrip empty string', () {
      final encoded = coder.encode('');
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, '');
    });

    test('roundtrip UTF-8 Chinese characters', () {
      final encoded = coder.encode('你好');
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, '你好');
    });

    test('roundtrip mixed ASCII and UTF-8', () {
      final encoded = coder.encode('Hello 世界!');
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, 'Hello 世界!');
    });

    test('roundtrip long string crossing 32-byte boundary', () {
      final longStr = 'a' * 33; // 33 bytes in UTF-8
      final encoded = coder.encode(longStr);
      expect(encoded.encoded.length, 96); // 32 length + 64 padded data
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, longStr);
    });
  });
}
