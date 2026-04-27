import 'package:ceres_wallet_onchain/src/evm/evm_address.dart';
import 'package:test/test.dart';

void main() {
  // Vitalik's known EIP-55 checksummed address
  const vitalikEip55 = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

  group('EvmAddress', () {
    test('normalizes lowercase hex to EIP-55 checksum', () {
      final addr = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
      expect(addr.toString(), equals(vitalikEip55));
    });

    test('normalizes uppercase hex to EIP-55 checksum', () {
      final addr = EvmAddress('0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045');
      expect(addr.toString(), equals(vitalikEip55));
    });

    test('accepts input without 0x prefix', () {
      final addr = EvmAddress('d8da6bf26964af9d7eed9e03e53415d37aa96045');
      expect(addr.toString(), equals(vitalikEip55));
    });

    test('preserves already-checksummed input', () {
      final addr = EvmAddress(vitalikEip55);
      expect(addr.toString(), equals(vitalikEip55));
    });

    test('toHex returns lowercase 40-char hex without 0x', () {
      final addr = EvmAddress(vitalikEip55);
      expect(addr.toHex(), equals('d8da6bf26964af9d7eed9e03e53415d37aa96045'));
      expect(addr.toHex().length, equals(40));
    });

    test('toString returns 0x-prefixed EIP-55 address', () {
      final addr = EvmAddress(vitalikEip55);
      expect(addr.toString(), startsWith('0x'));
      expect(addr.toString().length, equals(42));
    });

    group('equality', () {
      test('two addresses with same hex in different cases are equal', () {
        final lower = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
        final upper = EvmAddress('0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045');
        expect(lower, equals(upper));
      });

      test('two equal addresses have same hashCode', () {
        final a = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
        final b = EvmAddress('0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045');
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different addresses are not equal', () {
        final a = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
        final b = EvmAddress('0x0000000000000000000000000000000000000001');
        expect(a, isNot(equals(b)));
      });
    });

    test('works with zero address', () {
      final addr = EvmAddress('0x0000000000000000000000000000000000000000');
      expect(addr.toHex(), equals('0000000000000000000000000000000000000000'));
    });

    test('can be used as Map key', () {
      final addr1 = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
      final addr2 = EvmAddress('0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045');
      final map = <EvmAddress, String>{addr1: 'vitalik'};
      expect(map[addr2], equals('vitalik'));
    });
  });
}
