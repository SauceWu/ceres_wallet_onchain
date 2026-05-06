/// Solana Program Derived Address (PDA) utilities.
///
/// Implements the two derivation primitives used throughout Solana:
///
///   - [SolanaPda.findProgramAddress] — iterates nonces to find an off-curve address.
///   - [SolanaPda.createWithSeed]    — one-shot SHA-256 hash without nonce iteration.
///
/// Reference: https://docs.solana.com/developing/programming-model/calling-between-programs#program-derived-addresses
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/crypto/crypto/cdsa/curve/curves.dart';
import 'package:blockchain_utils/crypto/crypto/cdsa/point/edwards.dart';
import 'package:blockchain_utils/crypto/quick_crypto.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';

/// Static utility class providing Solana PDA derivation primitives.
///
/// PDAs (Program Derived Addresses) are addresses owned by a Solana
/// program that have no corresponding private key. They are derived
/// deterministically from a program ID and a set of seeds.
class SolanaPda {
  SolanaPda._();

  /// Finds the canonical Program Derived Address (PDA) for [programId]
  /// given [seeds].
  ///
  /// Iterates nonces from 255 down to 0 and returns the first 32-byte
  /// SHA-256 hash that is **not** a valid compressed Ed25519 Y-coordinate
  /// (i.e., the point is "off-curve").
  ///
  /// Returns `(pda, bump)` where `bump` is the winning nonce.
  ///
  /// Throws [ArgumentError] if any seed exceeds 32 bytes, or if no
  /// off-curve PDA is found across all 256 nonces (defense-in-depth —
  /// should never happen with well-formed inputs).
  ///
  /// ```dart
  /// final (pda, bump) = SolanaPda.findProgramAddress(
  ///   seeds: [],
  ///   programId: SolanaAddress('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
  /// );
  /// ```
  static (SolanaAddress pda, int bump) findProgramAddress({
    required List<Uint8List> seeds,
    required SolanaAddress programId,
  }) {
    // Maximum per-seed size enforced by the Solana runtime.
    const maxSeedSize = 32;
    for (final seed in seeds) {
      if (seed.length > maxSeedSize) {
        throw ArgumentError('Seed exceeds $maxSeedSize bytes: ${seed.length}');
      }
    }

    final programIdBytes = programId.toBytes();
    for (var nonce = 255; nonce >= 0; nonce--) {
      final hash = _hashSeeds(seeds, programIdBytes, nonce);
      if (!_isOnEd25519Curve(hash)) {
        return (SolanaAddress.fromBytes(Uint8List.fromList(hash)), nonce);
      }
    }
    throw ArgumentError('Could not find valid program address for $programId');
  }

  /// Derives an address deterministically from [from], [seed], and [programId]
  /// without nonce iteration (no off-curve check required).
  ///
  /// ```
  /// result = SHA-256(from.bytes || seed.utf8 || programId.bytes)
  /// ```
  ///
  /// Used by Anchor to derive the IDL storage account address:
  /// ```dart
  /// final (base, _) = SolanaPda.findProgramAddress(seeds: [], programId: programId);
  /// final idlAddr = SolanaPda.createWithSeed(
  ///   from: base,
  ///   seed: 'anchor:idl',
  ///   programId: programId,
  /// );
  /// ```
  static SolanaAddress createWithSeed({
    required SolanaAddress from,
    required String seed,
    required SolanaAddress programId,
  }) {
    final input = Uint8List.fromList([
      ...from.toBytes(),
      ...utf8.encode(seed),
      ...programId.toBytes(),
    ]);
    final hash = QuickCrypto.sha256Hash(input);
    return SolanaAddress.fromBytes(Uint8List.fromList(hash));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Computes SHA-256 of: seeds... || programId || [nonce] || "ProgramDerivedAddress"
  static List<int> _hashSeeds(
    List<Uint8List> seeds,
    Uint8List programId,
    int nonce,
  ) {
    final buffer = <int>[];
    for (final seed in seeds) {
      buffer.addAll(seed);
    }
    buffer.addAll(programId);
    buffer.add(nonce);
    buffer.addAll(utf8.encode('ProgramDerivedAddress'));
    return QuickCrypto.sha256Hash(Uint8List.fromList(buffer));
  }

  /// Returns `true` when [bytes] represents a valid compressed Ed25519
  /// Y-coordinate (i.e., the point IS on the curve → invalid as a PDA).
  ///
  /// Implementation: attempts to decode the bytes as an Ed25519 point via
  /// `EDPoint.fromBytes`. The decoder throws `CryptoException` /
  /// `SquareRootError` when the y-coordinate has no valid x — that signals
  /// an off-curve point, which is exactly what a PDA requires.
  static bool _isOnEd25519Curve(List<int> bytes) {
    try {
      EDPoint.fromBytes(curve: Curves.curveEd25519, data: bytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}
