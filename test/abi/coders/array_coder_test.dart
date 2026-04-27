import 'package:test/test.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_param.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/tuple_coder.dart';

void main() {
  group('ArrayCoder dynamic T[]', () {
    test('uint256[] empty array encodes to 32 bytes (length=0)', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      final result = coder.encode(<BigInt>[]);

      expect(result.encoded.length, equals(32));
      // length = 0
      expect(result.encoded, everyElement(0));
    });

    test('uint256[] with [1, 2, 3] encodes correctly', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      final result = coder.encode([BigInt.one, BigInt.two, BigInt.from(3)]);

      // 32 (length=3) + 3 * 32 = 128 bytes
      expect(result.encoded.length, equals(128));
      expect(result.isDynamic, isTrue);

      // Length = 3
      expect(result.encoded[31], equals(3));

      // Element 0 = 1
      expect(result.encoded[63], equals(1));
      // Element 1 = 2
      expect(result.encoded[95], equals(2));
      // Element 2 = 3
      expect(result.encoded[127], equals(3));
    });

    test('string[] with [hello, world] encodes with head/tail', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.string()));
      final result = coder.encode(['hello', 'world']);

      expect(result.isDynamic, isTrue);

      // 32 (length=2) + head (2 * 32 offsets) + tail (2 string data blocks)
      // Each string: 32 (length) + 32 (padded data) = 64
      // Total: 32 + 64 + 128 = 224
      expect(result.encoded.length, equals(224));

      // Length = 2
      expect(result.encoded[31], equals(2));
    });

    test('bool[] is always dynamic', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.bool()));
      expect(coder.isDynamic, isTrue);
    });
  });

  group('ArrayCoder fixed T[N]', () {
    test('uint256[3] with [1, 2, 3] encodes without length prefix', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.uint256(), 3));
      final result = coder.encode([BigInt.one, BigInt.two, BigInt.from(3)]);

      // No length prefix: 3 * 32 = 96 bytes
      expect(result.encoded.length, equals(96));

      // Element 0 = 1
      expect(result.encoded[31], equals(1));
      // Element 1 = 2
      expect(result.encoded[63], equals(2));
      // Element 2 = 3
      expect(result.encoded[95], equals(3));
    });

    test('uint256[3] isDynamic is false', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.uint256(), 3));
      expect(coder.isDynamic, isFalse);
    });

    test('string[2] isDynamic is true (dynamic element type)', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.string(), 2));
      expect(coder.isDynamic, isTrue);
    });

    test('string[2] encodes with head/tail but no length prefix', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.string(), 2));
      final result = coder.encode(['hello', 'world']);

      // No length prefix, but dynamic elements use head/tail
      // Head: 2 * 32 = 64 (offsets)
      // Tail: 2 * (32 + 32) = 128 (each string: length + padded data)
      // Total: 64 + 128 = 192
      expect(result.encoded.length, equals(192));
    });

    test('throws when element count does not match fixed length', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.uint256(), 3));
      expect(
        () => coder.encode([BigInt.one, BigInt.two]),
        throwsA(isA<AbiException>()),
      );
    });
  });

  group('ArrayCoder tuple[]', () {
    test('tuple(address,bool,bytes)[] multicall3 pattern', () {
      final tupleParam = AbiParam.tuple([
        AbiParam.address(),
        AbiParam.bool(),
        AbiParam.bytes(),
      ]);
      final coder = ArrayCoder(AbiParam.array(tupleParam));

      final result = coder.encode([
        [
          '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
          true,
          <int>[0x01, 0x02],
        ],
        [
          '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
          false,
          <int>[0x03],
        ],
      ]);

      expect(result.isDynamic, isTrue);
      // Length prefix (32) + 2 tuple offsets (64) + 2 tuples with head/tail
      expect(result.encoded.length, greaterThan(32 + 64));

      // Roundtrip decode
      final decoded = coder.decode(result.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(2));

      final tuple0 = values[0] as List;
      expect(
        tuple0[0].toString().toLowerCase(),
        contains('d8da6bf26964af9d7eed9e03e53415d37aa96045'),
      );
      expect(tuple0[1], isTrue);
      expect(tuple0[2], equals([0x01, 0x02]));

      final tuple1 = values[1] as List;
      expect(
        tuple1[0].toString().toLowerCase(),
        contains('a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'),
      );
      expect(tuple1[1], isFalse);
      expect(tuple1[2], equals([0x03]));
    });
  });

  group('ArrayCoder decode roundtrip', () {
    test('uint256[] roundtrip', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      final original = [BigInt.one, BigInt.two, BigInt.from(3)];
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(3));
      expect(values[0], equals(BigInt.one));
      expect(values[1], equals(BigInt.two));
      expect(values[2], equals(BigInt.from(3)));
    });

    test('uint256[3] roundtrip', () {
      final coder = ArrayCoder(AbiParam.fixedArray(AbiParam.uint256(), 3));
      final original = [BigInt.one, BigInt.two, BigInt.from(3)];
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(3));
      expect(values[0], equals(BigInt.one));
      expect(values[1], equals(BigInt.two));
      expect(values[2], equals(BigInt.from(3)));
    });

    test('string[] roundtrip', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.string()));
      final original = ['hello', 'world'];
      final encoded = coder.encode(original);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(2));
      expect(values[0], equals('hello'));
      expect(values[1], equals('world'));
    });

    test('empty array roundtrip', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      final encoded = coder.encode(<BigInt>[]);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values, isEmpty);
    });
  });

  group('ArrayCoder validation', () {
    test('throws on non-List value', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      expect(() => coder.encode('not a list'), throwsA(isA<AbiException>()));
    });

    test('throws on insufficient decode data', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      expect(() => coder.decode(<int>[], 0), throwsA(isA<AbiException>()));
    });

    test('T-03-10: throws when decoded length exceeds maximum', () {
      final coder = ArrayCoder(AbiParam.array(AbiParam.uint256()));
      // Craft data with length = 10001
      final data = List<int>.filled(32, 0);
      data[31] = 0x01; // lower byte
      data[29] = 0x27; // 10001 = 0x2711
      data[30] = 0x11;
      expect(() => coder.decode(data, 0), throwsA(isA<AbiException>()));
    });
  });
}
