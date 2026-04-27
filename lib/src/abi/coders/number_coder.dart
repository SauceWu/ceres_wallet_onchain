import 'package:blockchain_utils/utils/numbers/utils/bigint_utils.dart'
    as chain_bigint;

import '../abi_type.dart';
import '../abi_type_coder.dart';

/// ABI encoder/decoder for Solidity `uint8`..`uint256` and `int8`..`int256`.
///
/// Numbers are always encoded as 32-byte big-endian values. Unsigned values
/// are zero-padded on the left; signed negative values use two's complement
/// representation.
///
/// ```dart
/// final coder = NumberCoder('uint256');
/// final result = coder.encode(BigInt.from(256));
/// // result.encoded == 32 bytes with value 0x0100
/// ```
class NumberCoder extends AbiTypeCoder {
  /// Whether the type is signed (`intN`) or unsigned (`uintN`).
  final bool signed;

  /// The bit width of the type (8, 16, ..., 256).
  final int bitWidth;

  /// Creates a [NumberCoder] by parsing a Solidity type string.
  ///
  /// Accepts `'uint8'`..`'uint256'` and `'int8'`..`'int256'`.
  /// Throws [AbiException] if the type string is invalid.
  NumberCoder(String type)
    : signed = type.startsWith('int'),
      bitWidth = _parseBitWidth(type);

  static int _parseBitWidth(String type) {
    final match = RegExp(r'^u?int(\d+)$').firstMatch(type);
    if (match == null) {
      throw AbiException('Invalid number type: $type');
    }
    final bits = int.parse(match.group(1)!);
    if (bits < 8 || bits > 256 || bits % 8 != 0) {
      throw AbiException(
        'Invalid bit width $bits: must be 8..256 in steps of 8',
      );
    }
    return bits;
  }

  @override
  bool get isDynamic => false;

  @override
  EncoderResult encode(dynamic value) {
    if (value is! BigInt) {
      throw AbiException(
        'NumberCoder expects BigInt, got ${value.runtimeType}',
      );
    }
    _validateRange(value);

    // For signed negative values, convert to unsigned two's complement
    // representation before serializing to bytes.
    final unsigned = signed && value.isNegative ? value.toUnsigned(256) : value;

    final bytes = chain_bigint.BigintUtils.toBytes(unsigned, length: 32);
    return EncoderResult(bytes);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for number decode: '
        'need ${offset + 32}, have ${data.length}',
      );
    }

    final slice = data.sublist(offset, offset + 32);
    var value = chain_bigint.BigintUtils.fromBytes(slice);

    if (signed) {
      // Convert to signed representation using the target bit width.
      value = value.toSigned(bitWidth);
    } else {
      // Mask to the target bit width for unsigned types.
      final mask = (BigInt.one << bitWidth) - BigInt.one;
      value = value & mask;
    }

    return DecoderResult(value);
  }

  /// Validates that [value] is within the valid range for this type.
  void _validateRange(BigInt value) {
    if (signed) {
      final min = -(BigInt.one << (bitWidth - 1));
      final max = (BigInt.one << (bitWidth - 1)) - BigInt.one;
      if (value < min || value > max) {
        throw AbiException(
          'int$bitWidth value $value out of range [$min, $max]',
        );
      }
    } else {
      final max = (BigInt.one << bitWidth) - BigInt.one;
      if (value < BigInt.zero || value > max) {
        throw AbiException('uint$bitWidth value $value out of range [0, $max]');
      }
    }
  }
}
