import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

void main() {
  final maxUint256 = BigInt.from(2).pow(256) - BigInt.one;

  group('bigIntToHex', () {
    test('zero returns 0x0', () {
      expect(BigIntUtils.bigIntToHex(BigInt.zero), equals('0x0'));
    });

    test('255 returns 0xff', () {
      expect(BigIntUtils.bigIntToHex(BigInt.from(255)), equals('0xff'));
    });

    test('16 returns 0x10', () {
      expect(BigIntUtils.bigIntToHex(BigInt.from(16)), equals('0x10'));
    });

    test('max uint256 returns 0x + 64 f', () {
      expect(BigIntUtils.bigIntToHex(maxUint256), equals('0x${'f' * 64}'));
    });
  });

  group('bigIntTo32ByteHex', () {
    test('zero returns 0x + 64 zeros', () {
      expect(
        BigIntUtils.bigIntTo32ByteHex(BigInt.zero),
        equals('0x${'0' * 64}'),
      );
    });

    test('one returns 0x + 62 zeros + 01', () {
      expect(
        BigIntUtils.bigIntTo32ByteHex(BigInt.one),
        equals('0x${'0' * 62}01'),
      );
    });

    test('max uint256 returns 0x + 64 f', () {
      expect(
        BigIntUtils.bigIntTo32ByteHex(maxUint256),
        equals('0x${'f' * 64}'),
      );
    });
  });

  group('hexToBigInt', () {
    test('0x0 returns BigInt.zero', () {
      expect(BigIntUtils.hexToBigInt('0x0'), equals(BigInt.zero));
    });

    test('0xff returns 255', () {
      expect(BigIntUtils.hexToBigInt('0xff'), equals(BigInt.from(255)));
    });

    test('0x10 returns 16', () {
      expect(BigIntUtils.hexToBigInt('0x10'), equals(BigInt.from(16)));
    });

    test('ff without 0x prefix returns 255', () {
      expect(BigIntUtils.hexToBigInt('ff'), equals(BigInt.from(255)));
    });
  });

  group('bigIntTo32Bytes', () {
    test('zero returns 32 zero bytes', () {
      final bytes = BigIntUtils.bigIntTo32Bytes(BigInt.zero);
      expect(bytes.length, equals(32));
      expect(bytes.every((b) => b == 0), isTrue);
    });

    test('one returns 32 bytes with last byte as 1', () {
      final bytes = BigIntUtils.bigIntTo32Bytes(BigInt.one);
      expect(bytes.length, equals(32));
      expect(bytes.last, equals(1));
      expect(bytes.sublist(0, 31).every((b) => b == 0), isTrue);
    });

    test('max uint256 returns 32 bytes all 0xff', () {
      final bytes = BigIntUtils.bigIntTo32Bytes(maxUint256);
      expect(bytes.length, equals(32));
      expect(bytes.every((b) => b == 0xff), isTrue);
    });
  });
}
