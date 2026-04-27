import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:ceres_wallet_onchain/src/abi/abi_type.dart';
import 'package:ceres_wallet_onchain/src/abi/coders/address_coder.dart';
import 'package:ceres_wallet_onchain/src/evm/evm_address.dart';
import 'package:test/test.dart';

void main() {
  String toHex(List<int> bytes) => BytesUtils.toHexString(bytes);

  // Vitalik's address for test vectors.
  const vitalikAddr = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
  const vitalikEncoded =
      '000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045';

  group('AddressCoder encode', () {
    test('encodes address string with 12 zero-byte left padding', () {
      final coder = AddressCoder();
      final result = coder.encode(vitalikAddr);
      expect(result.encoded.length, 32);
      expect(toHex(result.encoded), vitalikEncoded);
    });

    test('encodes EvmAddress object', () {
      final coder = AddressCoder();
      final addr = EvmAddress(vitalikAddr);
      final result = coder.encode(addr);
      expect(toHex(result.encoded), vitalikEncoded);
    });

    test('first 12 bytes are zero', () {
      final coder = AddressCoder();
      final result = coder.encode(vitalikAddr);
      expect(result.encoded.sublist(0, 12), List<int>.filled(12, 0));
    });

    test('isDynamic is false', () {
      expect(AddressCoder().isDynamic, false);
    });

    test('zero address encodes correctly', () {
      final coder = AddressCoder();
      final result = coder.encode('0x0000000000000000000000000000000000000000');
      expect(toHex(result.encoded), '00' * 32);
    });
  });

  group('AddressCoder decode', () {
    test('decode returns EvmAddress in EIP-55 format', () {
      final coder = AddressCoder();
      final bytes = BytesUtils.fromHexString(vitalikEncoded);
      final result = coder.decode(bytes, 0);
      expect(result.value, isA<EvmAddress>());
      expect(result.value.toString(), vitalikAddr);
      expect(result.consumed, 32);
    });

    test('encode/decode roundtrip', () {
      final coder = AddressCoder();
      final encoded = coder.encode(vitalikAddr);
      final decoded = coder.decode(encoded.encoded, 0);
      expect(decoded.value.toString(), vitalikAddr);
    });

    test('decode with offset', () {
      final coder = AddressCoder();
      final padding = List<int>.filled(32, 0);
      final addrBytes = BytesUtils.fromHexString(vitalikEncoded);
      final data = [...padding, ...addrBytes];
      final result = coder.decode(data, 32);
      expect(result.value.toString(), vitalikAddr);
    });
  });

  group('AddressCoder validation', () {
    test('non-string/EvmAddress value throws AbiException', () {
      final coder = AddressCoder();
      expect(() => coder.encode(42), throwsA(isA<AbiException>()));
      expect(() => coder.encode(true), throwsA(isA<AbiException>()));
    });

    test('insufficient data for decode throws AbiException', () {
      final coder = AddressCoder();
      expect(
        () => coder.decode(List<int>.filled(16, 0), 0),
        throwsA(isA<AbiException>()),
      );
    });
  });
}
