import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/number_coder.dart';
import 'package:test/test.dart';

void main() {
  String toHex(List<int> bytes) => BytesUtils.toHexString(bytes);

  group('NumberCoder encode', () {
    test('uint256(0) encodes as 32 zero bytes', () {
      final coder = NumberCoder('uint256');
      final result = coder.encode(BigInt.zero);
      expect(result.encoded.length, 32);
      expect(toHex(result.encoded), '00' * 32);
    });

    test('uint256(1) encodes correctly', () {
      final coder = NumberCoder('uint256');
      final result = coder.encode(BigInt.one);
      expect(toHex(result.encoded), '${'00' * 31}01');
    });

    test('uint256(256) encodes as 0x0100', () {
      final coder = NumberCoder('uint256');
      final result = coder.encode(BigInt.from(256));
      expect(toHex(result.encoded), '${'00' * 30}0100');
    });

    test('uint256 max (2^256-1) encodes as 32 bytes of ff', () {
      final coder = NumberCoder('uint256');
      final maxVal = (BigInt.one << 256) - BigInt.one;
      final result = coder.encode(maxVal);
      expect(toHex(result.encoded), 'ff' * 32);
    });

    test('uint8(255) encodes correctly', () {
      final coder = NumberCoder('uint8');
      final result = coder.encode(BigInt.from(255));
      expect(toHex(result.encoded), '${'00' * 31}ff');
    });

    test('int8(-1) encodes as 32 bytes of ff (two\'s complement)', () {
      final coder = NumberCoder('int8');
      final result = coder.encode(BigInt.from(-1));
      expect(toHex(result.encoded), 'ff' * 32);
    });

    test('int8(127) encodes correctly', () {
      final coder = NumberCoder('int8');
      final result = coder.encode(BigInt.from(127));
      expect(toHex(result.encoded), '${'00' * 31}7f');
    });

    test('int256(-1) encodes as 32 bytes of ff', () {
      final coder = NumberCoder('int256');
      final result = coder.encode(BigInt.from(-1));
      expect(toHex(result.encoded), 'ff' * 32);
    });

    test('int256 max positive encodes correctly', () {
      final coder = NumberCoder('int256');
      final maxPositive = (BigInt.one << 255) - BigInt.one;
      final result = coder.encode(maxPositive);
      expect(toHex(result.encoded), '7f${'ff' * 31}');
    });

    test('isDynamic is false', () {
      expect(NumberCoder('uint256').isDynamic, false);
      expect(NumberCoder('int8').isDynamic, false);
    });
  });

  group('NumberCoder decode', () {
    test('uint256 decode 0', () {
      final coder = NumberCoder('uint256');
      final bytes = List<int>.filled(32, 0);
      final result = coder.decode(bytes, 0);
      expect(result.value, BigInt.zero);
      expect(result.consumed, 32);
    });

    test('uint256 decode 1', () {
      final coder = NumberCoder('uint256');
      final bytes = List<int>.filled(32, 0);
      bytes[31] = 1;
      final result = coder.decode(bytes, 0);
      expect(result.value, BigInt.one);
    });

    test('uint256 max roundtrip', () {
      final coder = NumberCoder('uint256');
      final maxVal = (BigInt.one << 256) - BigInt.one;
      final encoded = coder.encode(maxVal);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, maxVal);
    });

    test('int8(-1) roundtrip', () {
      final coder = NumberCoder('int8');
      final encoded = coder.encode(BigInt.from(-1));
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, BigInt.from(-1));
    });

    test('int256(-1) roundtrip', () {
      final coder = NumberCoder('int256');
      final encoded = coder.encode(BigInt.from(-1));
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, BigInt.from(-1));
    });

    test('int8(127) roundtrip', () {
      final coder = NumberCoder('int8');
      final encoded = coder.encode(BigInt.from(127));
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, BigInt.from(127));
    });

    test('int8(-128) roundtrip', () {
      final coder = NumberCoder('int8');
      final encoded = coder.encode(BigInt.from(-128));
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, BigInt.from(-128));
    });

    test('decode with offset', () {
      final coder = NumberCoder('uint256');
      final padding = List<int>.filled(32, 0);
      final valueBytes = List<int>.filled(32, 0);
      valueBytes[31] = 42;
      final data = [...padding, ...valueBytes];
      final result = coder.decode(data, 32);
      expect(result.value, BigInt.from(42));
    });
  });

  group('NumberCoder validation', () {
    test('uint8(256) throws AbiException', () {
      final coder = NumberCoder('uint8');
      expect(
        () => coder.encode(BigInt.from(256)),
        throwsA(isA<AbiException>()),
      );
    });

    test('uint8(-1) throws AbiException', () {
      final coder = NumberCoder('uint8');
      expect(() => coder.encode(BigInt.from(-1)), throwsA(isA<AbiException>()));
    });

    test('int8(128) throws AbiException', () {
      final coder = NumberCoder('int8');
      expect(
        () => coder.encode(BigInt.from(128)),
        throwsA(isA<AbiException>()),
      );
    });

    test('int8(-129) throws AbiException', () {
      final coder = NumberCoder('int8');
      expect(
        () => coder.encode(BigInt.from(-129)),
        throwsA(isA<AbiException>()),
      );
    });

    test('non-BigInt value throws AbiException', () {
      final coder = NumberCoder('uint256');
      expect(() => coder.encode(42), throwsA(isA<AbiException>()));
    });

    test('insufficient data for decode throws AbiException', () {
      final coder = NumberCoder('uint256');
      expect(
        () => coder.decode(List<int>.filled(16, 0), 0),
        throwsA(isA<AbiException>()),
      );
    });

    test('invalid type string throws AbiException', () {
      expect(() => NumberCoder('uint7'), throwsA(isA<AbiException>()));
      expect(() => NumberCoder('uint512'), throwsA(isA<AbiException>()));
      expect(() => NumberCoder('float256'), throwsA(isA<AbiException>()));
    });
  });
}
