import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/fixed_bytes_coder.dart';
import 'package:test/test.dart';

void main() {
  String toHex(List<int> bytes) => BytesUtils.toHexString(bytes);

  group('FixedBytesCoder encode', () {
    test('bytes32 encode 32 bytes unchanged', () {
      final coder = FixedBytesCoder('bytes32');
      final input = List<int>.generate(32, (i) => i);
      final result = coder.encode(input);
      expect(result.encoded.length, 32);
      expect(result.encoded, input);
    });

    test('bytes1 encode right-pads to 32 bytes', () {
      final coder = FixedBytesCoder('bytes1');
      final result = coder.encode([0xab]);
      expect(result.encoded.length, 32);
      expect(result.encoded[0], 0xab);
      expect(result.encoded.sublist(1), List<int>.filled(31, 0));
    });

    test('bytes4 encode selector 0x70a08231 right-pads correctly', () {
      final coder = FixedBytesCoder('bytes4');
      final selector = [0x70, 0xa0, 0x82, 0x31];
      final result = coder.encode(selector);
      expect(result.encoded.length, 32);
      expect(result.encoded.sublist(0, 4), selector);
      expect(result.encoded.sublist(4), List<int>.filled(28, 0));
      expect(toHex(result.encoded), '70a08231${'00' * 28}');
    });

    test('isDynamic is false', () {
      expect(FixedBytesCoder('bytes32').isDynamic, false);
      expect(FixedBytesCoder('bytes1').isDynamic, false);
    });
  });

  group('FixedBytesCoder decode', () {
    test('bytes32 decode roundtrip', () {
      final coder = FixedBytesCoder('bytes32');
      final input = List<int>.generate(32, (i) => i);
      final encoded = coder.encode(input);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, input);
      expect(decoded.consumed, 32);
    });

    test('bytes1 decode returns only first byte', () {
      final coder = FixedBytesCoder('bytes1');
      final encoded = coder.encode([0xab]);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, [0xab]);
    });

    test('bytes4 decode returns first 4 bytes only', () {
      final coder = FixedBytesCoder('bytes4');
      final selector = [0x70, 0xa0, 0x82, 0x31];
      final encoded = coder.encode(selector);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, selector);
    });

    test('decode with offset', () {
      final coder = FixedBytesCoder('bytes4');
      final padding = List<int>.filled(32, 0);
      final selector = [0x70, 0xa0, 0x82, 0x31];
      final encoded = coder.encode(selector);
      final data = [...padding, ...encoded.encoded];
      final result = coder.decode(data, 32);
      expect(result.value, selector);
    });
  });

  group('FixedBytesCoder validation', () {
    test('wrong length input throws AbiException', () {
      final coder = FixedBytesCoder('bytes4');
      expect(
        () => coder.encode([0x01, 0x02, 0x03]),
        throwsA(isA<AbiException>()),
      );
      expect(
        () => coder.encode([0x01, 0x02, 0x03, 0x04, 0x05]),
        throwsA(isA<AbiException>()),
      );
    });

    test('non-list value throws AbiException', () {
      final coder = FixedBytesCoder('bytes4');
      expect(() => coder.encode('0x12345678'), throwsA(isA<AbiException>()));
    });

    test('insufficient data for decode throws AbiException', () {
      final coder = FixedBytesCoder('bytes4');
      expect(
        () => coder.decode(List<int>.filled(16, 0), 0),
        throwsA(isA<AbiException>()),
      );
    });

    test('invalid type string throws AbiException', () {
      expect(() => FixedBytesCoder('bytes0'), throwsA(isA<AbiException>()));
      expect(() => FixedBytesCoder('bytes33'), throwsA(isA<AbiException>()));
      expect(() => FixedBytesCoder('byte4'), throwsA(isA<AbiException>()));
    });
  });
}
