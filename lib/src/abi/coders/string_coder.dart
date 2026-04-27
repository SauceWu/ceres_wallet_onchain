import 'dart:convert';

import '../abi_type.dart';
import '../abi_type_coder.dart';
import 'dynamic_bytes_coder.dart';

/// ABI encoder/decoder for the Solidity `string` dynamic type.
///
/// Strings are UTF-8 encoded and then processed identically to `bytes`.
/// Encoding layout is the same as [DynamicBytesCoder]:
/// `[length (32 bytes)] [utf8-data (ceil(len/32)*32 bytes)]`
///
/// ```dart
/// final coder = StringCoder();
/// final result = coder.encode('Hello, world!');
/// // result.encoded: 32 bytes length (13) + 32 bytes padded UTF-8 data
/// ```
class StringCoder extends AbiTypeCoder {
  final DynamicBytesCoder _bytesCoder = DynamicBytesCoder();

  @override
  bool get isDynamic => true;

  @override
  EncoderResult encode(dynamic value) {
    if (value is! String) {
      throw AbiException(
        'StringCoder expects String, got ${value.runtimeType}',
      );
    }

    final utf8Bytes = utf8.encode(value);
    return _bytesCoder.encode(utf8Bytes);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    final bytesResult = _bytesCoder.decode(data, offset);
    final decodedString = utf8.decode(bytesResult.value as List<int>);
    return DecoderResult(decodedString, consumed: 32);
  }
}
