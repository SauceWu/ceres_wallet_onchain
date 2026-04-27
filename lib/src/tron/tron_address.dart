/// Tron address value object with base58check/hex dual representation.
///
/// Tron addresses come in two formats:
///
/// - **Base58check:** Starts with `T`, e.g., `TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf`
/// - **Hex:** Starts with `41`, 42 characters, e.g., `41d0b52f6159fae55e04cbc67e0d3c21a070cab4e1`
///
/// [TronAddress] accepts either format and can convert between them:
///
/// ```dart
/// final addr = TronAddress('TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf');
/// print(addr.toHex());    // 41d0b52f6159fae55e04cbc67e0d3c21a070cab4e1
/// print(addr.toBase58()); // TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf
/// ```
///
/// Equality is based on the underlying 20-byte address, so the same
/// address created from different formats compares as equal.
library;

import 'dart:typed_data';

import 'package:blockchain_utils/base58/base58_base.dart';
import 'package:blockchain_utils/bip/address/trx_addr.dart';
import 'package:blockchain_utils/utils/utils.dart';

/// An immutable Tron address value object.
///
/// Stores the 20-byte raw address internally and lazily computes the
/// base58check and hex representations. Accepts both `T`-prefixed
/// base58check strings and `41`-prefixed hex strings as input.
class TronAddress {
  /// The raw 20-byte address (without the 0x41 prefix).
  final Uint8List _hexBytes;

  /// Creates a [TronAddress] from a base58check or hex string.
  ///
  /// Accepted formats:
  /// - Base58check starting with `T`
  /// - Hex starting with `41` (42 characters)
  /// - Hex starting with `0x41` (44 characters)
  ///
  /// Throws [ArgumentError] if the input is not a valid Tron address.
  factory TronAddress(String address) {
    if (address.isEmpty) {
      throw ArgumentError.value(address, 'address', 'Address cannot be empty');
    }

    try {
      if (address.startsWith('T')) {
        // Base58check format — decode to 20-byte address
        final decoded = TrxAddrDecoder().decodeAddr(address);
        return TronAddress._(Uint8List.fromList(decoded));
      }

      // Strip 0x prefix if present
      final hex = address.startsWith('0x') ? address.substring(2) : address;

      if (hex.length == 42 && hex.startsWith('41')) {
        // Hex format with 41 prefix — take the 20-byte address part
        final bytes = BytesUtils.fromHexString(hex.substring(2));
        if (bytes.length != 20) {
          throw ArgumentError.value(
            address,
            'address',
            'Invalid Tron hex address length',
          );
        }
        return TronAddress._(Uint8List.fromList(bytes));
      }
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError.value(address, 'address', 'Invalid Tron address: $e');
    }

    throw ArgumentError.value(
      address,
      'address',
      'Unrecognized Tron address format',
    );
  }

  TronAddress._(this._hexBytes);

  /// Returns the base58check representation (starts with `T`).
  String toBase58() {
    return Base58Encoder.checkEncode([0x41, ..._hexBytes]);
  }

  /// Returns the hex representation (starts with `41`, 42 characters).
  String toHex() {
    return '41${BytesUtils.toHexString(_hexBytes)}';
  }

  @override
  String toString() => toBase58();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TronAddress && BytesUtils.bytesEqual(_hexBytes, other._hexBytes);

  @override
  int get hashCode => Object.hashAll(_hexBytes);
}
