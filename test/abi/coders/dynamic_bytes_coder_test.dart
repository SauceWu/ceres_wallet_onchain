import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/dynamic_bytes_coder.dart';
import 'package:test/test.dart';

void main() {
  final coder = DynamicBytesCoder();

  group('DynamicBytesCoder isDynamic', () {
    test('isDynamic is true', () {
      expect(coder.isDynamic, isTrue);
    });
  });

  group('DynamicBytesCoder encode', () {
    test('empty bytes produces 32 bytes (length only)', () {
      final result = coder.encode(<int>[]);
      expect(result.encoded.length, 32);
      expect(result.isDynamic, isTrue);
      // length = 0
      expect(
        BytesUtils.toHexString(result.encoded),
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test(
      '[0x01, 0x02, 0x03] produces 64 bytes (32 length + 32 padded data)',
      () {
        final result = coder.encode([0x01, 0x02, 0x03]);
        expect(result.encoded.length, 64);
        expect(result.isDynamic, isTrue);

        final hex = BytesUtils.toHexString(result.encoded);
        // length = 3
        expect(
          hex.substring(0, 64),
          '0000000000000000000000000000000000000000000000000000000000000003',
        );
        // data: 01 02 03 + 29 zero bytes
        expect(
          hex.substring(64),
          '0102030000000000000000000000000000000000000000000000000000000000',
        );
      },
    );

    test('32 bytes data produces 64 bytes (no extra padding)', () {
      final data = List<int>.generate(32, (i) => i + 1);
      final result = coder.encode(data);
      expect(result.encoded.length, 64);
    });

    test('33 bytes data produces 96 bytes (32 length + 64 padded data)', () {
      final data = List<int>.generate(33, (i) => i + 1);
      final result = coder.encode(data);
      expect(result.encoded.length, 96);
    });

    test('64 bytes data produces 96 bytes (no extra padding)', () {
      final data = List<int>.filled(64, 0xab);
      final result = coder.encode(data);
      expect(result.encoded.length, 96);
    });

    test('rejects non-List<int> input', () {
      expect(() => coder.encode('hello'), throwsA(isA<AbiException>()));
    });
  });

  group('DynamicBytesCoder decode', () {
    test('roundtrip empty bytes', () {
      final encoded = coder.encode(<int>[]);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, <int>[]);
      expect(decoded.consumed, 32);
    });

    test('roundtrip [0x01, 0x02, 0x03]', () {
      final original = [0x01, 0x02, 0x03];
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, original);
      expect(decoded.consumed, 32);
    });

    test('roundtrip 32 bytes', () {
      final original = List<int>.generate(32, (i) => i);
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, original);
    });

    test('roundtrip 33 bytes', () {
      final original = List<int>.generate(33, (i) => i);
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, original);
    });

    test('decode with offset', () {
      final original = [0x01, 0x02, 0x03];
      final encoded = coder.encode(original);
      // Prepend 32 bytes of padding to simulate offset
      final withOffset = [...List<int>.filled(32, 0), ...encoded.encoded];
      final decoded = coder.decode(withOffset, 32);
      expect(decoded.value, original);
    });

    test('throws on insufficient data for length', () {
      expect(
        () => coder.decode(List<int>.filled(16, 0), 0),
        throwsA(isA<AbiException>()),
      );
    });

    test('throws on truncated data (length says more than available)', () {
      // length = 32 but only 16 bytes of data
      final lengthBytes = List<int>.filled(32, 0);
      lengthBytes[31] = 32;
      final truncated = [...lengthBytes, ...List<int>.filled(16, 0)];
      expect(() => coder.decode(truncated, 0), throwsA(isA<AbiException>()));
    });
  });
}
