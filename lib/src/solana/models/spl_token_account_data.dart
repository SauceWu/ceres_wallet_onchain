/// SPL Token account binary data parser.
///
/// Parses the 165-byte binary layout of an SPL Token account to extract
/// the mint address, owner address, and token amount.
///
/// Layout (first 72 bytes):
/// - `[0..31]`  — mint (32 bytes, Solana public key)
/// - `[32..63]` — owner (32 bytes, Solana public key)
/// - `[64..71]` — amount (u64 little-endian)
///
/// ```dart
/// final data = SplTokenAccountData.fromBase64(accountInfo.data[0]);
/// print(data.mint);   // SolanaAddress
/// print(data.owner);  // SolanaAddress
/// print(data.amount); // BigInt
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import '../solana_address.dart';

/// Parsed SPL Token account data.
class SplTokenAccountData {
  /// The mint (token type) address.
  final SolanaAddress mint;

  /// The owner (wallet) address.
  final SolanaAddress owner;

  /// The token amount as a raw u64 value.
  final BigInt amount;

  /// Creates an [SplTokenAccountData] with the given field values.
  const SplTokenAccountData({
    required this.mint,
    required this.owner,
    required this.amount,
  });

  /// Parses SPL Token account data from a base64-encoded string.
  ///
  /// Throws [FormatException] if the decoded data is less than 72 bytes.
  factory SplTokenAccountData.fromBase64(String base64Data) {
    final bytes = base64Decode(base64Data);
    return SplTokenAccountData.fromBytes(Uint8List.fromList(bytes));
  }

  /// Parses SPL Token account data from raw bytes.
  ///
  /// Throws [FormatException] if [bytes] is less than 72 bytes
  /// (minimum to read mint + owner + amount).
  factory SplTokenAccountData.fromBytes(Uint8List bytes) {
    if (bytes.length < 72) {
      throw FormatException(
        'SPL Token account data must be at least 72 bytes, got ${bytes.length}',
      );
    }

    final mint = SolanaAddress.fromBytes(Uint8List.sublistView(bytes, 0, 32));
    final owner = SolanaAddress.fromBytes(Uint8List.sublistView(bytes, 32, 64));
    final amount = _readU64LE(bytes, 64);

    return SplTokenAccountData(mint: mint, owner: owner, amount: amount);
  }

  /// Reads a u64 little-endian value from [bytes] at [offset].
  ///
  /// Uses byte-by-byte BigInt construction for Web safety (no 64-bit
  /// integer support in dart2js).
  static BigInt _readU64LE(Uint8List bytes, int offset) {
    var result = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      result = (result << 8) | BigInt.from(bytes[offset + i]);
    }
    return result;
  }
}
