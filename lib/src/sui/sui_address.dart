/// Sui address value object with hex normalization.
///
/// Sui addresses are 32-byte values displayed as `0x`-prefixed hex strings,
/// always normalized to 64 hex characters (zero-padded on the left).
/// Short forms like `0x2` are accepted and normalized to full length.
///
/// ```dart
/// final addr = SuiAddress('0x2');
/// print(addr.toHex());
/// // 0x0000000000000000000000000000000000000000000000000000000000000002
/// ```
library;

import 'dart:typed_data';

import 'package:blockchain_utils/utils/binary/utils.dart';

/// An immutable Sui address value object.
///
/// Stores the raw 32-byte address internally and provides hex
/// encoding/decoding with automatic zero-padding normalization.
/// Equality is based on the underlying bytes.
class SuiAddress {
  /// The raw 32-byte address.
  final Uint8List _bytes;

  /// Creates a [SuiAddress] from a hex string.
  ///
  /// Accepts `0x`-prefixed or bare hex strings. Short addresses are
  /// zero-padded on the left to 64 hex characters. Throws [ArgumentError]
  /// if the input is empty, contains invalid hex characters, or exceeds
  /// 32 bytes.
  factory SuiAddress(String hex) {
    if (hex.isEmpty) {
      throw ArgumentError.value(hex, 'hex', 'Address cannot be empty');
    }

    // Strip 0x/0X prefix
    var stripped = hex;
    if (stripped.startsWith('0x') || stripped.startsWith('0X')) {
      stripped = stripped.substring(2);
    }

    if (stripped.isEmpty) {
      throw ArgumentError.value(hex, 'hex', 'Address cannot be empty');
    }

    // Validate hex characters
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(stripped)) {
      throw ArgumentError.value(hex, 'hex', 'Invalid hex characters');
    }

    if (stripped.length > 64) {
      throw ArgumentError.value(hex, 'hex', 'Sui address exceeds 32 bytes');
    }

    // Pad to 64 hex chars (32 bytes)
    stripped = stripped.padLeft(64, '0');

    final bytes = BytesUtils.fromHexString(stripped);
    return SuiAddress._(Uint8List.fromList(bytes));
  }

  /// Creates a [SuiAddress] from raw 32-byte address bytes.
  ///
  /// Throws [ArgumentError] if [bytes] is not exactly 32 bytes.
  factory SuiAddress.fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Sui address must be 32 bytes',
      );
    }
    return SuiAddress._(Uint8List.fromList(bytes));
  }

  SuiAddress._(this._bytes);

  /// Returns the `0x`-prefixed 64-character hex representation.
  String toHex() => '0x${BytesUtils.toHexString(_bytes)}';

  /// Returns a copy of the raw 32-byte address.
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  @override
  String toString() => toHex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuiAddress && BytesUtils.bytesEqual(_bytes, other._bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);
}
