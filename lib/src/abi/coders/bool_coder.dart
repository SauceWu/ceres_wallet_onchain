import '../abi_type.dart';
import '../abi_type_coder.dart';

/// ABI encoder/decoder for the Solidity `bool` type.
///
/// Booleans are encoded as 32-byte values: `true` is `0x...01` (last byte 1,
/// all others zero) and `false` is 32 zero bytes.
///
/// ```dart
/// final coder = BoolCoder();
/// coder.encode(true);   // 32 bytes, last byte = 1
/// coder.encode(false);  // 32 zero bytes
/// ```
class BoolCoder extends AbiTypeCoder {
  @override
  bool get isDynamic => false;

  @override
  EncoderResult encode(dynamic value) {
    if (value is! bool) {
      throw AbiException('BoolCoder expects bool, got ${value.runtimeType}');
    }
    final bytes = List<int>.filled(32, 0);
    if (value) {
      bytes[31] = 1;
    }
    return EncoderResult(bytes);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for bool decode: '
        'need ${offset + 32}, have ${data.length}',
      );
    }
    // Any non-zero value in the 32-byte word is considered true.
    final lastByte = data[offset + 31];
    return DecoderResult(lastByte != 0);
  }
}
