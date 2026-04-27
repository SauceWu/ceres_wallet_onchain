import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/bool_coder.dart';
import 'package:test/test.dart';

void main() {
  String toHex(List<int> bytes) => BytesUtils.toHexString(bytes);

  group('BoolCoder encode', () {
    test('true encodes as 32 bytes with last byte 1', () {
      final coder = BoolCoder();
      final result = coder.encode(true);
      expect(result.encoded.length, 32);
      expect(toHex(result.encoded), '${'00' * 31}01');
    });

    test('false encodes as 32 zero bytes', () {
      final coder = BoolCoder();
      final result = coder.encode(false);
      expect(result.encoded.length, 32);
      expect(toHex(result.encoded), '00' * 32);
    });

    test('isDynamic is false', () {
      expect(BoolCoder().isDynamic, false);
    });
  });

  group('BoolCoder decode', () {
    test('decode true roundtrip', () {
      final coder = BoolCoder();
      final encoded = coder.encode(true);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, true);
      expect(decoded.consumed, 32);
    });

    test('decode false roundtrip', () {
      final coder = BoolCoder();
      final encoded = coder.encode(false);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value, false);
    });

    test('decode with offset', () {
      final coder = BoolCoder();
      final padding = List<int>.filled(32, 0);
      final trueBytes = List<int>.filled(32, 0);
      trueBytes[31] = 1;
      final data = [...padding, ...trueBytes];
      final result = coder.decode(data, 32);
      expect(result.value, true);
    });
  });

  group('BoolCoder validation', () {
    test('non-bool value throws AbiException', () {
      final coder = BoolCoder();
      expect(() => coder.encode(1), throwsA(isA<AbiException>()));
      expect(() => coder.encode('true'), throwsA(isA<AbiException>()));
    });

    test('insufficient data for decode throws AbiException', () {
      final coder = BoolCoder();
      expect(
        () => coder.decode(List<int>.filled(16, 0), 0),
        throwsA(isA<AbiException>()),
      );
    });
  });
}
