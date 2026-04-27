import 'package:test/test.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_param.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/tuple_coder.dart';

void main() {
  group('TupleCoder encode - static', () {
    test('(address, uint256) produces 64 bytes', () {
      final coder = TupleCoder([AbiParam.address(), AbiParam.uint256()]);
      final result = coder.encode([
        '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        BigInt.from(100),
      ]);

      expect(result.encoded.length, equals(64));
      // First 32 bytes: address left-padded (12 zero bytes + 20 address bytes)
      expect(result.encoded.sublist(0, 12), everyElement(0));
      // Last 32 bytes: uint256 = 100
      expect(result.encoded[63], equals(100));
      expect(result.encoded.sublist(32, 63), everyElement(0));
    });

    test('(bool, uint256) produces 64 bytes', () {
      final coder = TupleCoder([AbiParam.bool(), AbiParam.uint256()]);
      final result = coder.encode([true, BigInt.from(42)]);

      expect(result.encoded.length, equals(64));
      expect(result.encoded[31], equals(1)); // bool true
      expect(result.encoded[63], equals(42)); // uint256 42
    });

    test('isDynamic is false for all-static tuple', () {
      final coder = TupleCoder([AbiParam.address(), AbiParam.uint256()]);
      expect(coder.isDynamic, isFalse);
    });
  });

  group('TupleCoder encode - dynamic', () {
    test('(address, bytes, uint256) uses head/tail encoding', () {
      final coder = TupleCoder([
        AbiParam.address(),
        AbiParam.bytes(),
        AbiParam.uint256(),
      ]);
      final result = coder.encode([
        '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        <int>[0x01, 0x02],
        BigInt.from(100),
      ]);

      // Head: 3 * 32 = 96 bytes
      //   address (32) + bytes offset (32) + uint256 (32)
      // Tail: bytes data = length(32) + padded data(32) = 64 bytes
      // Total: 96 + 64 = 160 bytes
      expect(result.encoded.length, equals(160));
      expect(result.isDynamic, isTrue);

      // Bytes offset should be 0x60 = 96 (pointing to start of tail)
      final offsetBytes = result.encoded.sublist(32, 64);
      expect(offsetBytes[31], equals(96));
      expect(offsetBytes.sublist(0, 31), everyElement(0));

      // Tail: bytes length = 2
      final lengthBytes = result.encoded.sublist(96, 128);
      expect(lengthBytes[31], equals(2));

      // Tail: bytes data [0x01, 0x02] right-padded
      expect(result.encoded[128], equals(0x01));
      expect(result.encoded[129], equals(0x02));
      expect(result.encoded.sublist(130, 160), everyElement(0));
    });

    test('isDynamic is true when any component is dynamic', () {
      final coder = TupleCoder([
        AbiParam.address(),
        AbiParam.bytes(),
        AbiParam.uint256(),
      ]);
      expect(coder.isDynamic, isTrue);
    });

    test('(string, uint256) uses head/tail encoding', () {
      final coder = TupleCoder([AbiParam.string(), AbiParam.uint256()]);
      final result = coder.encode(['hello', BigInt.from(1)]);

      // Head: 2 * 32 = 64 bytes (string offset + uint256)
      // string offset = 0x40 = 64
      final offsetBytes = result.encoded.sublist(0, 32);
      expect(offsetBytes[31], equals(64));

      // uint256 = 1 at offset 32
      expect(result.encoded[63], equals(1));

      // Tail at offset 64: string length (5) + padded data
      expect(result.encoded[95], equals(5)); // length
      // "hello" = [104, 101, 108, 108, 111]
      expect(result.encoded[96], equals(104)); // 'h'
    });
  });

  group('TupleCoder decode - static', () {
    test('(address, uint256) roundtrip', () {
      final coder = TupleCoder([AbiParam.address(), AbiParam.uint256()]);
      final encoded = coder.encode([
        '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        BigInt.from(100),
      ]);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(2));
      expect(
        values[0].toString().toLowerCase(),
        contains('d8da6bf26964af9d7eed9e03e53415d37aa96045'),
      );
      expect(values[1], equals(BigInt.from(100)));
    });

    test('(bool, uint256) roundtrip', () {
      final coder = TupleCoder([AbiParam.bool(), AbiParam.uint256()]);
      final encoded = coder.encode([true, BigInt.from(42)]);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values[0], isTrue);
      expect(values[1], equals(BigInt.from(42)));
    });
  });

  group('TupleCoder decode - dynamic', () {
    test('(address, bytes, uint256) roundtrip', () {
      final coder = TupleCoder([
        AbiParam.address(),
        AbiParam.bytes(),
        AbiParam.uint256(),
      ]);
      final encoded = coder.encode([
        '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        <int>[0x01, 0x02],
        BigInt.from(100),
      ]);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values.length, equals(3));
      expect(
        values[0].toString().toLowerCase(),
        contains('d8da6bf26964af9d7eed9e03e53415d37aa96045'),
      );
      expect(values[1], equals([0x01, 0x02]));
      expect(values[2], equals(BigInt.from(100)));
    });

    test('(string, uint256) roundtrip', () {
      final coder = TupleCoder([AbiParam.string(), AbiParam.uint256()]);
      final encoded = coder.encode(['hello', BigInt.from(1)]);
      final decoded = coder.decode(encoded.encoded, 0);
      final values = decoded.value as List;

      expect(values[0], equals('hello'));
      expect(values[1], equals(BigInt.from(1)));
    });
  });

  group('TupleCoder nested', () {
    test('(uint256, (address, bool)) all static, 96 bytes', () {
      final innerTuple = AbiParam.tuple([AbiParam.address(), AbiParam.bool()]);
      final coder = TupleCoder([AbiParam.uint256(), innerTuple]);
      final result = coder.encode([
        BigInt.from(42),
        ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', true],
      ]);

      // All static: 3 * 32 = 96 bytes
      expect(result.encoded.length, equals(96));
      expect(coder.isDynamic, isFalse);

      // Roundtrip
      final decoded = coder.decode(result.encoded, 0);
      final values = decoded.value as List;
      expect(values[0], equals(BigInt.from(42)));
      final innerValues = values[1] as List;
      expect(innerValues[1], isTrue);
    });

    test('(uint256, (address, string)) dynamic nested', () {
      final innerTuple = AbiParam.tuple([
        AbiParam.address(),
        AbiParam.string(),
      ]);
      final coder = TupleCoder([AbiParam.uint256(), innerTuple]);
      final result = coder.encode([
        BigInt.from(42),
        ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', 'hello'],
      ]);

      expect(coder.isDynamic, isTrue);

      // Roundtrip
      final decoded = coder.decode(result.encoded, 0);
      final values = decoded.value as List;
      expect(values[0], equals(BigInt.from(42)));
      final innerValues = values[1] as List;
      expect(innerValues[1], equals('hello'));
    });
  });

  group('TupleCoder validation', () {
    test('throws on wrong value count', () {
      final coder = TupleCoder([AbiParam.uint256(), AbiParam.bool()]);
      expect(() => coder.encode([BigInt.one]), throwsA(isA<AbiException>()));
    });

    test('throws on non-List value', () {
      final coder = TupleCoder([AbiParam.uint256()]);
      expect(() => coder.encode('not a list'), throwsA(isA<AbiException>()));
    });

    test('throws on insufficient decode data', () {
      final coder = TupleCoder([AbiParam.uint256()]);
      expect(() => coder.decode(<int>[], 0), throwsA(isA<AbiException>()));
    });
  });

  group('coderForParam factory', () {
    test('creates correct coder for address', () {
      final coder = TupleCoder.coderForParam(AbiParam.address());
      expect(coder.isDynamic, isFalse);
    });

    test('creates correct coder for uint256', () {
      final coder = TupleCoder.coderForParam(AbiParam.uint256());
      expect(coder.isDynamic, isFalse);
    });

    test('creates correct coder for string', () {
      final coder = TupleCoder.coderForParam(AbiParam.string());
      expect(coder.isDynamic, isTrue);
    });

    test('creates correct coder for bytes', () {
      final coder = TupleCoder.coderForParam(AbiParam.bytes());
      expect(coder.isDynamic, isTrue);
    });

    test('creates correct coder for bytes32', () {
      final coder = TupleCoder.coderForParam(AbiParam.bytesN(32));
      expect(coder.isDynamic, isFalse);
    });

    test('creates correct coder for bool', () {
      final coder = TupleCoder.coderForParam(AbiParam.bool());
      expect(coder.isDynamic, isFalse);
    });

    test('creates correct coder for tuple', () {
      final coder = TupleCoder.coderForParam(
        AbiParam.tuple([AbiParam.uint256()]),
      );
      expect(coder.isDynamic, isFalse);
    });

    test('creates correct coder for uint256[]', () {
      final coder = TupleCoder.coderForParam(
        AbiParam.array(AbiParam.uint256()),
      );
      expect(coder.isDynamic, isTrue);
    });

    test('throws on unsupported type', () {
      expect(
        () => TupleCoder.coderForParam(const AbiParam(type: 'unknown')),
        throwsA(isA<AbiException>()),
      );
    });
  });
}
