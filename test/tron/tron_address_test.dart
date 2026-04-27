import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:test/test.dart';

void main() {
  group('TronAddress', () {
    // Known address pair (verified via blockchain_utils):
    // base58: TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA
    // hex: 41d0b52f6159fae55e04cbc67e0d3c21a070cab4e1
    const knownBase58 = 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA';
    const knownHex = '41d0b52f6159fae55e04cbc67e0d3c21a070cab4e1';

    test('from base58 — toBase58() returns original', () {
      final addr = TronAddress(knownBase58);
      expect(addr.toBase58(), equals(knownBase58));
    });

    test('from base58 — toHex() returns 41-prefixed 42-char hex', () {
      final addr = TronAddress(knownBase58);
      final hex = addr.toHex();
      expect(hex, startsWith('41'));
      expect(hex.length, equals(42));
      expect(hex, equals(knownHex));
    });

    test('from hex — toBase58() returns T-prefixed base58check', () {
      final addr = TronAddress(knownHex);
      expect(addr.toBase58(), startsWith('T'));
      expect(addr.toBase58(), equals(knownBase58));
    });

    test('from hex — toHex() returns original', () {
      final addr = TronAddress(knownHex);
      expect(addr.toHex(), equals(knownHex));
    });

    test('from 0x-prefixed hex', () {
      final addr = TronAddress('0x$knownHex');
      expect(addr.toBase58(), equals(knownBase58));
      expect(addr.toHex(), equals(knownHex));
    });

    test('equality: same address different formats', () {
      final fromBase58 = TronAddress(knownBase58);
      final fromHex = TronAddress(knownHex);
      expect(fromBase58, equals(fromHex));
      expect(fromBase58.hashCode, equals(fromHex.hashCode));
    });

    test('toString() returns base58 format', () {
      final addr = TronAddress(knownHex);
      expect(addr.toString(), equals(knownBase58));
    });

    test('invalid address throws ArgumentError', () {
      expect(() => TronAddress('invalid'), throwsA(isA<ArgumentError>()));
      expect(() => TronAddress(''), throwsA(isA<ArgumentError>()));
      expect(() => TronAddress('0x1234'), throwsA(isA<ArgumentError>()));
    });

    test('different addresses are not equal', () {
      // Use a different known Tron address
      final addr1 = TronAddress(knownBase58);
      // A different address (all zeros = T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb)
      final addr2 = TronAddress('41${'0' * 40}');
      expect(addr1, isNot(equals(addr2)));
    });
  });
}
