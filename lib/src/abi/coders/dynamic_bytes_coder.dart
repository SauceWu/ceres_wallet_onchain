import '../abi_type.dart';
import '../abi_type_coder.dart';
import '../../utils/bigint_utils.dart';

/// ABI encoder/decoder for the Solidity `bytes` dynamic byte type.
///
/// Dynamic bytes are encoded with a 32-byte length prefix followed by the
/// data right-padded to the next 32-byte boundary.
///
/// Layout: `[length (32 bytes)] [data (ceil(len/32)*32 bytes)]`
///
/// ```dart
/// final coder = DynamicBytesCoder();
/// final result = coder.encode([0x01, 0x02, 0x03]);
/// // result.encoded: 32 bytes length (3) + 32 bytes padded data
/// ```
class DynamicBytesCoder extends AbiTypeCoder {
  @override
  bool get isDynamic => true;

  @override
  EncoderResult encode(dynamic value) {
    if (value is! List<int>) {
      throw AbiException(
        'DynamicBytesCoder expects List<int>, got ${value.runtimeType}',
      );
    }

    final length = value.length;
    final lengthBytes = BigIntUtils.bigIntTo32Bytes(BigInt.from(length));

    if (length == 0) {
      return EncoderResult(lengthBytes, isDynamic: true);
    }

    final paddedLength = ((length + 31) ~/ 32) * 32;
    final paddedData = List<int>.filled(paddedLength, 0);
    paddedData.setAll(0, value);

    return EncoderResult([...lengthBytes, ...paddedData], isDynamic: true);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for bytes decode: '
        'need ${offset + 32}, have ${data.length}',
      );
    }

    final lengthBytes = data.sublist(offset, offset + 32);
    final length = _bytesToInt(lengthBytes);

    if (data.length < offset + 32 + length) {
      throw AbiException(
        'Insufficient data for bytes decode: '
        'need ${offset + 32 + length}, have ${data.length}',
      );
    }

    final value = data.sublist(offset + 32, offset + 32 + length);
    return DecoderResult(value, consumed: 32);
  }

  /// Parses a 32-byte big-endian integer as a Dart [int].
  static int _bytesToInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result.toInt();
  }
}
