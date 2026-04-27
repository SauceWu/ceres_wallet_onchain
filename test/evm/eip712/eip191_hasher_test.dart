import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/crypto/quick_crypto.dart';
import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('EIP191Hasher', () {
    test('hashes ASCII personal_sign payload', () {
      expect(
        _toHex(EIP191Hasher.digest('Hello World')),
        'a1de988600a42c4b4ab089b619297c17d53cffae5d5120d82d8a92d0bb3b78f2',
      );
    });

    test('uses utf8 byte length rather than character count', () {
      final digest = EIP191Hasher.digest('你好');
      final wrongPrefix = utf8.encode('\u0019Ethereum Signed Message:\n2你好');
      final wrongDigest = Uint8List.fromList(
        QuickCrypto.keccack256Hash(wrongPrefix),
      );

      expect(digest, isNot(wrongDigest));
    });
  });
}
