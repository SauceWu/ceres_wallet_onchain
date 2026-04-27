import '../abi_type.dart';
import '../abi_type_coder.dart';

/// ABI encoder/decoder for Solidity `bytes1`..`bytes32` fixed-length byte types.
///
/// Fixed bytes are right-padded with zeros to fill a 32-byte word.
/// For example, `bytes1(0xab)` encodes as `0xab` followed by 31 zero bytes.
///
/// ```dart
/// final coder = FixedBytesCoder('bytes4');
/// coder.encode([0x70, 0xa0, 0x82, 0x31]); // right-padded to 32 bytes
/// ```
class FixedBytesCoder extends AbiTypeCoder {
  /// The fixed byte length N (1..32).
  final int byteLength;

  /// Creates a [FixedBytesCoder] by parsing a `'bytesN'` type string.
  ///
  /// Throws [AbiException] if N is not in the range 1..32.
  FixedBytesCoder(String type) : byteLength = _parseByteLength(type);

  static int _parseByteLength(String type) {
    final match = RegExp(r'^bytes(\d+)$').firstMatch(type);
    if (match == null) {
      throw AbiException('Invalid fixed bytes type: $type');
    }
    final n = int.parse(match.group(1)!);
    if (n < 1 || n > 32) {
      throw AbiException('Invalid byte length $n: must be 1..32');
    }
    return n;
  }

  @override
  bool get isDynamic => false;

  @override
  EncoderResult encode(dynamic value) {
    if (value is! List<int>) {
      throw AbiException(
        'FixedBytesCoder expects List<int>, got ${value.runtimeType}',
      );
    }
    if (value.length != byteLength) {
      throw AbiException(
        'bytes$byteLength expects $byteLength bytes, got ${value.length}',
      );
    }

    // Right-pad with zeros to 32 bytes.
    final bytes = List<int>.filled(32, 0);
    bytes.setAll(0, value);
    return EncoderResult(bytes);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for bytes$byteLength decode: '
        'need ${offset + 32}, have ${data.length}',
      );
    }

    // Return only the first N bytes from the 32-byte word.
    final value = data.sublist(offset, offset + byteLength);
    return DecoderResult(value);
  }
}
