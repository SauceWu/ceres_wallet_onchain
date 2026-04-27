/// Solana address value object using base58 encoding (no checksum).
///
/// Solana addresses are 32-byte Ed25519 public keys encoded as base58
/// strings. Unlike Tron addresses, Solana does not use base58check
/// (no checksum bytes).
///
/// ```dart
/// final addr = SolanaAddress('11111111111111111111111111111111');
/// print(addr.toBase58()); // 11111111111111111111111111111111
/// print(addr.toBytes().length); // 32
/// ```
library;

import 'dart:typed_data';

import 'package:blockchain_utils/base58/base58_base.dart';
import 'package:blockchain_utils/utils/binary/utils.dart';

/// An immutable Solana address value object.
///
/// Stores the raw 32-byte Ed25519 public key internally and provides
/// base58 encoding/decoding. Equality is based on the underlying bytes.
class SolanaAddress {
  /// The raw 32-byte public key.
  final Uint8List _bytes;

  /// Creates a [SolanaAddress] from a base58-encoded string.
  ///
  /// The decoded bytes must be exactly 32 bytes. Throws [ArgumentError]
  /// if the input is empty or does not decode to 32 bytes.
  factory SolanaAddress(String base58) {
    if (base58.isEmpty) {
      throw ArgumentError.value(base58, 'base58', 'Address cannot be empty');
    }

    final List<int> decoded;
    try {
      decoded = Base58Decoder.decode(base58);
    } catch (e) {
      throw ArgumentError.value(
        base58,
        'base58',
        'Invalid base58 encoding: $e',
      );
    }

    if (decoded.length != 32) {
      throw ArgumentError.value(
        base58,
        'base58',
        'Solana address must be 32 bytes, got ${decoded.length}',
      );
    }

    return SolanaAddress._(Uint8List.fromList(decoded));
  }

  /// Creates a [SolanaAddress] from raw 32-byte public key bytes.
  ///
  /// Throws [ArgumentError] if [bytes] is not exactly 32 bytes.
  factory SolanaAddress.fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Solana address must be 32 bytes',
      );
    }
    return SolanaAddress._(Uint8List.fromList(bytes));
  }

  SolanaAddress._(this._bytes);

  /// Returns the base58-encoded address string.
  String toBase58() => Base58Encoder.encode(_bytes);

  /// Returns a copy of the raw 32-byte public key.
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  @override
  String toString() => toBase58();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolanaAddress && BytesUtils.bytesEqual(_bytes, other._bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);
}
