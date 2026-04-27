import 'package:blockchain_utils/utils/numbers/utils/bigint_utils.dart'
    as chain_bigint;
import 'package:blockchain_utils/utils/binary/utils.dart';

/// Conversion utilities between [BigInt] and hex strings / byte lists.
///
/// Wraps `blockchain_utils` primitives with SDK-specific convenience methods.
/// All on-chain numeric values MUST use [BigInt] to avoid uint256 overflow.
///
/// ```dart
/// BigIntUtils.bigIntToHex(BigInt.from(255));       // '0xff'
/// BigIntUtils.bigIntTo32ByteHex(BigInt.one);       // '0x000...0001' (64 chars)
/// BigIntUtils.hexToBigInt('0xff');                  // BigInt.from(255)
/// BigIntUtils.bigIntTo32Bytes(BigInt.one);          // [0, 0, ..., 0, 1] (32 bytes)
/// ```
class BigIntUtils {
  BigIntUtils._(); // Prevent instantiation.

  /// Converts [value] to a `0x`-prefixed hex string with no zero-padding.
  ///
  /// Returns `'0x0'` for [BigInt.zero].
  ///
  /// Example: `bigIntToHex(BigInt.from(255))` returns `'0xff'`.
  static String bigIntToHex(BigInt value) {
    if (value == BigInt.zero) return '0x0';
    return '0x${value.toRadixString(16)}';
  }

  /// Converts [value] to a 32-byte zero-padded hex string (`0x` prefix, 64 hex chars).
  ///
  /// Used for ABI encoding and RPC parameter serialization.
  ///
  /// Example: `bigIntTo32ByteHex(BigInt.one)` returns `'0x0000...0001'` (64 chars).
  static String bigIntTo32ByteHex(BigInt value) {
    final bytes = chain_bigint.BigintUtils.toBytes(value, length: 32);
    return '0x${BytesUtils.toHexString(bytes)}';
  }

  /// Parses a hex string into a [BigInt]. Accepts both `0x`-prefixed and bare hex.
  ///
  /// Throws [FormatException] (via `blockchain_utils`) on invalid hex input.
  ///
  /// Example: `hexToBigInt('0xff')` returns `BigInt.from(255)`.
  static BigInt hexToBigInt(String hex) {
    return chain_bigint.BigintUtils.parse(hex);
  }

  /// Converts [value] to a 32-byte big-endian zero-padded byte list.
  ///
  /// The returned list always has length 32.
  static List<int> bigIntTo32Bytes(BigInt value) {
    return chain_bigint.BigintUtils.toBytes(value, length: 32);
  }
}
