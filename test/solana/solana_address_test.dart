import 'dart:typed_data';

import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:test/test.dart';

void main() {
  group('SolanaAddress', () {
    // System Program: 32 zero bytes => base58 '11111111111111111111111111111111'
    const systemProgramBase58 = '11111111111111111111111111111111';
    // Token Program
    const tokenProgramBase58 = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
    // SOL native mint (So1111... is wrapped SOL)
    const wrappedSolBase58 = 'So11111111111111111111111111111111111111112';

    test('creates from base58 string and round-trips', () {
      final addr = SolanaAddress(systemProgramBase58);
      expect(addr.toBase58(), equals(systemProgramBase58));
    });

    test('creates from Token Program base58 and round-trips', () {
      final addr = SolanaAddress(tokenProgramBase58);
      expect(addr.toBase58(), equals(tokenProgramBase58));
    });

    test('creates from wrapped SOL address', () {
      final addr = SolanaAddress(wrappedSolBase58);
      expect(addr.toBase58(), equals(wrappedSolBase58));
    });

    test('creates from 32-byte Uint8List and round-trips', () {
      // System program = 32 zero bytes
      final bytes = Uint8List(32);
      final addr = SolanaAddress.fromBytes(bytes);
      expect(addr.toBase58(), equals(systemProgramBase58));
    });

    test('toBytes returns 32-byte Uint8List copy', () {
      final addr = SolanaAddress(systemProgramBase58);
      final bytes = addr.toBytes();
      expect(bytes.length, equals(32));
      expect(bytes, isA<Uint8List>());
      // Verify it's a copy
      bytes[0] = 0xFF;
      expect(addr.toBytes()[0], isNot(0xFF));
    });

    test('throws ArgumentError for empty string', () {
      expect(() => SolanaAddress(''), throwsArgumentError);
    });

    test('throws ArgumentError for non-32-byte decoded address', () {
      // 'A' decodes to a single byte, not 32
      expect(() => SolanaAddress('A'), throwsArgumentError);
    });

    test('throws ArgumentError for fromBytes with wrong length', () {
      expect(() => SolanaAddress.fromBytes(Uint8List(31)), throwsArgumentError);
      expect(() => SolanaAddress.fromBytes(Uint8List(33)), throwsArgumentError);
    });

    test('equality: same address from different constructors', () {
      final bytes = Uint8List(32); // all zeros
      final fromBase58 = SolanaAddress(systemProgramBase58);
      final fromBytes = SolanaAddress.fromBytes(bytes);
      expect(fromBase58, equals(fromBytes));
      expect(fromBase58.hashCode, equals(fromBytes.hashCode));
    });

    test('inequality: different addresses', () {
      final addr1 = SolanaAddress(systemProgramBase58);
      final addr2 = SolanaAddress(tokenProgramBase58);
      expect(addr1, isNot(equals(addr2)));
    });

    test('toString returns base58', () {
      final addr = SolanaAddress(tokenProgramBase58);
      expect(addr.toString(), equals(tokenProgramBase58));
    });
  });

  group('SolanaCommitment', () {
    test('finalized toString', () {
      expect(SolanaCommitment.finalized.toString(), equals('finalized'));
    });

    test('confirmed toString', () {
      expect(SolanaCommitment.confirmed.toString(), equals('confirmed'));
    });

    test('processed toString', () {
      expect(SolanaCommitment.processed.toString(), equals('processed'));
    });

    test('all values present', () {
      expect(SolanaCommitment.values.length, equals(3));
    });
  });
}
