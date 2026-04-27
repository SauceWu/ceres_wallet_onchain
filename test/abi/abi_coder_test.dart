import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

/// Helper: convert List<int> to lowercase hex string (no 0x prefix).
String toHex(List<int> bytes) => BytesUtils.toHexString(bytes);

/// Helper: convert hex string to List<int>.
List<int> fromHex(String hex) => BytesUtils.fromHexString(hex);

void main() {
  const vitalikAddr = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

  group('AbiCoder.encode - basic types', () {
    test('address', () {
      final result = AbiCoder.encode([AbiParam.address()], [vitalikAddr]);
      expect(
        toHex(result),
        '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045',
      );
    });

    test('uint256', () {
      final result = AbiCoder.encode([AbiParam.uint256()], [BigInt.from(256)]);
      expect(
        toHex(result),
        '0000000000000000000000000000000000000000000000000000000000000100',
      );
    });

    test('bool true', () {
      final result = AbiCoder.encode([AbiParam.bool()], [true]);
      expect(
        toHex(result),
        '0000000000000000000000000000000000000000000000000000000000000001',
      );
    });

    test('uint256 + bool', () {
      final result = AbiCoder.encode(
        [AbiParam.uint256(), AbiParam.bool()],
        [BigInt.from(100), true],
      );
      expect(
        toHex(result),
        '0000000000000000000000000000000000000000000000000000000000000064'
        '0000000000000000000000000000000000000000000000000000000000000001',
      );
    });
  });

  group('AbiCoder.encode - dynamic types', () {
    test('string', () {
      final result = AbiCoder.encode([AbiParam.string()], ['Hello, world!']);
      expect(
        toHex(result),
        // offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 13
        '000000000000000000000000000000000000000000000000000000000000000d'
        // "Hello, world!" UTF-8 right-padded to 32 bytes
        '48656c6c6f2c20776f726c642100000000000000000000000000000000000000',
      );
    });

    test('bytes', () {
      final result = AbiCoder.encode(
        [AbiParam.bytes()],
        [
          [0xde, 0xad, 0xbe, 0xef],
        ],
      );
      expect(
        toHex(result),
        // offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 4
        '0000000000000000000000000000000000000000000000000000000000000004'
        // deadbeef right-padded to 32 bytes
        'deadbeef00000000000000000000000000000000000000000000000000000000',
      );
    });
  });

  group('AbiCoder.encode - mixed static+dynamic', () {
    test('uint256 + string + uint256', () {
      final result = AbiCoder.encode(
        [AbiParam.uint256(), AbiParam.string(), AbiParam.uint256()],
        [BigInt.one, 'hello', BigInt.two],
      );
      // head: uint256(1) | offset(96) | uint256(2)
      // tail: length(5) | "hello" padded
      expect(
        toHex(result),
        // uint256(1)
        '0000000000000000000000000000000000000000000000000000000000000001'
        // offset = 96 (3*32)
        '0000000000000000000000000000000000000000000000000000000000000060'
        // uint256(2)
        '0000000000000000000000000000000000000000000000000000000000000002'
        // length = 5
        '0000000000000000000000000000000000000000000000000000000000000005'
        // "hello" padded
        '68656c6c6f000000000000000000000000000000000000000000000000000000',
      );
    });
  });

  group('AbiCoder.encode - tuple', () {
    test('static tuple (address, uint256)', () {
      final result = AbiCoder.encode(
        [
          AbiParam.tuple([AbiParam.address(), AbiParam.uint256()]),
        ],
        [
          [vitalikAddr, BigInt.from(1000)],
        ],
      );
      expect(
        toHex(result),
        '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045'
        '00000000000000000000000000000000000000000000000000000000000003e8',
      );
    });

    test('dynamic tuple (address, bytes)', () {
      final result = AbiCoder.encode(
        [
          AbiParam.tuple([AbiParam.address(), AbiParam.bytes()]),
        ],
        [
          [
            vitalikAddr,
            <int>[0x01],
          ],
        ],
      );
      // Outer: offset to tuple data = 32
      // Tuple head: address inline | offset to bytes = 64 (2*32)
      // Tuple tail: length=1 | 0x01 padded
      expect(
        toHex(result),
        // outer offset to tuple
        '0000000000000000000000000000000000000000000000000000000000000020'
        // address
        '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045'
        // offset to bytes data = 64
        '0000000000000000000000000000000000000000000000000000000000000040'
        // length = 1
        '0000000000000000000000000000000000000000000000000000000000000001'
        // 0x01 padded
        '0100000000000000000000000000000000000000000000000000000000000000',
      );
    });
  });

  group('AbiCoder.encode - array', () {
    test('uint256[]', () {
      final result = AbiCoder.encode(
        [AbiParam.array(AbiParam.uint256())],
        [
          [BigInt.one, BigInt.two],
        ],
      );
      expect(
        toHex(result),
        // outer offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 2
        '0000000000000000000000000000000000000000000000000000000000000002'
        // 1
        '0000000000000000000000000000000000000000000000000000000000000001'
        // 2
        '0000000000000000000000000000000000000000000000000000000000000002',
      );
    });

    test('string[]', () {
      final result = AbiCoder.encode(
        [AbiParam.array(AbiParam.string())],
        [
          ['hello', 'world'],
        ],
      );
      expect(
        toHex(result),
        // outer offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 2
        '0000000000000000000000000000000000000000000000000000000000000002'
        // offset to "hello" = 64 (2*32)
        '0000000000000000000000000000000000000000000000000000000000000040'
        // offset to "world" = 128 (64 + 32 + 32)
        '0000000000000000000000000000000000000000000000000000000000000080'
        // "hello" length = 5
        '0000000000000000000000000000000000000000000000000000000000000005'
        // "hello" padded
        '68656c6c6f000000000000000000000000000000000000000000000000000000'
        // "world" length = 5
        '0000000000000000000000000000000000000000000000000000000000000005'
        // "world" padded
        '776f726c64000000000000000000000000000000000000000000000000000000',
      );
    });
  });

  group('AbiCoder.encodeFunctionCall', () {
    test('balanceOf(address)', () {
      final result = AbiCoder.encodeFunctionCall(
        FunctionSelector.balanceOf,
        [AbiParam.address()],
        [vitalikAddr],
      );
      expect(
        toHex(result),
        '70a08231'
        '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045',
      );
    });

    test('transfer(address,uint256)', () {
      final result = AbiCoder.encodeFunctionCall(
        FunctionSelector.transfer,
        [AbiParam.address(), AbiParam.uint256()],
        [vitalikAddr, BigInt.from(1000)],
      );
      final hex = toHex(result);
      expect(hex.substring(0, 8), 'a9059cbb');
    });

    test('encodeFunctionCallBySignature matches selector', () {
      final result = AbiCoder.encodeFunctionCallBySignature(
        'balanceOf(address)',
        [AbiParam.address()],
        [vitalikAddr],
      );
      expect(
        toHex(result),
        '70a08231'
        '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045',
      );
    });
  });

  group('AbiCoder.decode roundtrip', () {
    test('address roundtrip', () {
      final params = [AbiParam.address()];
      final values = [vitalikAddr];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(
        (decoded[0] as EvmAddress).toString(),
        EvmAddress(vitalikAddr).toString(),
      );
    });

    test('uint256 + bool roundtrip', () {
      final params = [AbiParam.uint256(), AbiParam.bool()];
      final values = [BigInt.from(100), true];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(decoded[0], BigInt.from(100));
      expect(decoded[1], true);
    });

    test('string roundtrip', () {
      final params = [AbiParam.string()];
      final values = ['Hello, world!'];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(decoded[0], 'Hello, world!');
    });

    test('bytes roundtrip', () {
      final params = [AbiParam.bytes()];
      final values = [
        [0xde, 0xad, 0xbe, 0xef],
      ];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(decoded[0], [0xde, 0xad, 0xbe, 0xef]);
    });

    test('uint256[] roundtrip', () {
      final params = [AbiParam.array(AbiParam.uint256())];
      final values = [
        [BigInt.one, BigInt.two, BigInt.from(3)],
      ];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(decoded[0], [BigInt.one, BigInt.two, BigInt.from(3)]);
    });

    test('static tuple roundtrip', () {
      final params = [
        AbiParam.tuple([AbiParam.address(), AbiParam.uint256()]),
      ];
      final values = [
        [vitalikAddr, BigInt.from(42)],
      ];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      final tuple = decoded[0] as List;
      expect(
        (tuple[0] as EvmAddress).toString(),
        EvmAddress(vitalikAddr).toString(),
      );
      expect(tuple[1], BigInt.from(42));
    });

    test('mixed static+dynamic roundtrip', () {
      final params = [
        AbiParam.uint256(),
        AbiParam.string(),
        AbiParam.uint256(),
      ];
      final values = [BigInt.one, 'hello', BigInt.two];
      final encoded = AbiCoder.encode(params, values);
      final decoded = AbiCoder.decode(params, encoded);
      expect(decoded[0], BigInt.one);
      expect(decoded[1], 'hello');
      expect(decoded[2], BigInt.two);
    });
  });

  group('AbiCoder edge cases', () {
    test('uint256 zero', () {
      final result = AbiCoder.encode([AbiParam.uint256()], [BigInt.zero]);
      expect(
        toHex(result),
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('uint256 max value', () {
      final maxUint256 = BigInt.two.pow(256) - BigInt.one;
      final result = AbiCoder.encode([AbiParam.uint256()], [maxUint256]);
      expect(
        toHex(result),
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
    });

    test('empty string', () {
      final result = AbiCoder.encode([AbiParam.string()], ['']);
      expect(
        toHex(result),
        // offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 0
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('empty bytes', () {
      final result = AbiCoder.encode([AbiParam.bytes()], [<int>[]]);
      expect(
        toHex(result),
        // offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 0
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('empty uint256[]', () {
      final result = AbiCoder.encode(
        [AbiParam.array(AbiParam.uint256())],
        [<BigInt>[]],
      );
      expect(
        toHex(result),
        // offset = 32
        '0000000000000000000000000000000000000000000000000000000000000020'
        // length = 0
        '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    test('params/values length mismatch throws AbiException', () {
      expect(
        () => AbiCoder.encode([AbiParam.uint256()], []),
        throwsA(isA<AbiException>()),
      );
    });
  });
}
