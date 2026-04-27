import '../abi_param.dart';
import '../abi_type.dart';
import '../abi_type_coder.dart';
import '../../utils/bigint_utils.dart';
import 'address_coder.dart';
import 'bool_coder.dart';
import 'dynamic_bytes_coder.dart';
import 'fixed_bytes_coder.dart';
import 'number_coder.dart';
import 'string_coder.dart';

/// ABI encoder/decoder for Solidity `tuple` types.
///
/// Tuples are encoded using the head/tail algorithm:
/// - **Static tuple** (all components static): values concatenated directly
/// - **Dynamic tuple** (any component dynamic): head section contains static
///   values inline and offset pointers for dynamic values; tail section
///   contains the dynamic data
///
/// ```dart
/// final coder = TupleCoder([AbiParam.address(), AbiParam.uint256()]);
/// final result = coder.encode(['0xd8dA...96045', BigInt.from(100)]);
/// // result.encoded == 64 bytes (two 32-byte values concatenated)
/// ```
class TupleCoder extends AbiTypeCoder {
  /// The tuple component definitions.
  final List<AbiParam> components;

  /// Coders for each component, created via [coderForParam].
  final List<AbiTypeCoder> _coders;

  /// Creates a [TupleCoder] for the given [components].
  TupleCoder(this.components)
    : _coders = components.map(coderForParam).toList(growable: false);

  @override
  bool get isDynamic => _coders.any((c) => c.isDynamic);

  @override
  EncoderResult encode(dynamic value) {
    if (value is! List) {
      throw AbiException('TupleCoder expects List, got ${value.runtimeType}');
    }
    if (value.length != components.length) {
      throw AbiException(
        'TupleCoder expects ${components.length} values, got ${value.length}',
      );
    }

    // Encode each component.
    final results = <EncoderResult>[];
    for (var i = 0; i < components.length; i++) {
      results.add(_coders[i].encode(value[i]));
    }

    // If all static, concatenate directly.
    if (!isDynamic) {
      final bytes = <int>[];
      for (final r in results) {
        bytes.addAll(r.encoded);
      }
      return EncoderResult(bytes);
    }

    // Head/tail encoding for tuples with dynamic components.
    final headSize = components.length * 32;
    final head = <int>[];
    final tail = <int>[];

    for (var i = 0; i < results.length; i++) {
      if (_coders[i].isDynamic) {
        // Write offset pointer in head, actual data in tail.
        final offset = BigInt.from(headSize + tail.length);
        head.addAll(BigIntUtils.bigIntTo32Bytes(offset));
        tail.addAll(results[i].encoded);
      } else {
        // Static value goes directly in head.
        head.addAll(results[i].encoded);
      }
    }

    return EncoderResult([...head, ...tail], isDynamic: true);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for tuple decode at offset $offset: '
        'have ${data.length}',
      );
    }

    final baseOffset = offset;
    var curOffset = offset;
    final values = <dynamic>[];

    for (var i = 0; i < components.length; i++) {
      if (_coders[i].isDynamic) {
        // Read relative offset from head, decode from baseOffset + relOffset.
        _checkBounds(data, curOffset, 32, 'tuple dynamic offset');
        final relOffset = _bytesToInt(data.sublist(curOffset, curOffset + 32));
        final result = _coders[i].decode(data, baseOffset + relOffset);
        values.add(result.value);
        curOffset += 32;
      } else {
        final result = _coders[i].decode(data, curOffset);
        values.add(result.value);
        curOffset += 32;
      }
    }

    return DecoderResult(values, consumed: 32);
  }

  /// Creates the appropriate [AbiTypeCoder] for the given [param].
  ///
  /// This is the central coder factory used by TupleCoder, ArrayCoder, and
  /// any higher-level ABI encoding utilities.
  ///
  /// Throws [AbiException] for unsupported types.
  static AbiTypeCoder coderForParam(AbiParam param) {
    // Handle array types first (before checking base types).
    if (param.type.endsWith(']')) {
      // Lazy import avoided — ArrayCoder is in the same package.
      return _createArrayCoder(param);
    }
    if (param.type == 'address') return AddressCoder();
    if (param.type == 'bool') return BoolCoder();
    if (param.type == 'string') return StringCoder();
    if (param.type == 'bytes') return DynamicBytesCoder();
    if (param.type.startsWith('bytes')) {
      return FixedBytesCoder(param.type);
    }
    if (param.type.startsWith('uint') || param.type.startsWith('int')) {
      return NumberCoder(param.type);
    }
    if (param.type == 'tuple') return TupleCoder(param.components);
    throw AbiException('Unsupported ABI type: ${param.type}');
  }

  /// Creates an ArrayCoder — separate method to allow lazy reference.
  static AbiTypeCoder _createArrayCoder(AbiParam param) {
    // Import is resolved at file level; this just isolates the call.
    return ArrayCoder(param);
  }

  /// Validates that [data] has at least [needed] bytes from [offset].
  static void _checkBounds(
    List<int> data,
    int offset,
    int needed,
    String context,
  ) {
    if (data.length < offset + needed) {
      throw AbiException(
        'Insufficient data for $context: '
        'need ${offset + needed}, have ${data.length}',
      );
    }
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

/// ABI encoder/decoder for Solidity array types: `T[]` and `T[N]`.
///
/// - **Dynamic arrays** (`T[]`): encoded with a 32-byte length prefix
///   followed by the elements
/// - **Fixed arrays** (`T[N]`): encoded without a length prefix
///
/// Elements may be static or dynamic. Dynamic elements use head/tail encoding
/// within the array data section (same algorithm as [TupleCoder]).
///
/// ```dart
/// final coder = ArrayCoder(AbiParam(type: 'uint256[]'));
/// final result = coder.encode([BigInt.one, BigInt.two]);
/// // 32 bytes (length=2) + 64 bytes (2 * 32 bytes)
/// ```
class ArrayCoder extends AbiTypeCoder {
  /// The base element type string (e.g. `'uint256'` for `uint256[]`).
  final String elementType;

  /// Fixed length for `T[N]` arrays, or `null` for dynamic `T[]`.
  final int? fixedLength;

  /// Components for tuple element types.
  final List<AbiParam> _components;

  /// The coder for individual array elements.
  late final AbiTypeCoder _elementCoder;

  /// Maximum array length for decode safety (T-03-10: prevent OOM).
  static const int maxDecodeLength = 10000;

  /// Creates an [ArrayCoder] by parsing the array type from [param].
  ///
  /// Supports `uint256[]`, `uint256[3]`, `tuple[]`, `tuple[5]`, etc.
  ArrayCoder(AbiParam param)
    : elementType = _parseElementType(param.type),
      fixedLength = _parseFixedLength(param.type),
      _components = param.components {
    final elementParam = AbiParam(type: elementType, components: _components);
    _elementCoder = TupleCoder.coderForParam(elementParam);
  }

  static String _parseElementType(String type) {
    final bracketIdx = type.lastIndexOf('[');
    if (bracketIdx < 0) {
      throw AbiException('Invalid array type: $type');
    }
    return type.substring(0, bracketIdx);
  }

  static int? _parseFixedLength(String type) {
    final match = RegExp(r'\[(\d+)\]$').firstMatch(type);
    if (match == null) return null; // dynamic T[]
    return int.parse(match.group(1)!);
  }

  @override
  bool get isDynamic {
    // Dynamic arrays T[] are always dynamic.
    if (fixedLength == null) return true;
    // Fixed arrays T[N] are dynamic only if the element type is dynamic.
    return _elementCoder.isDynamic;
  }

  @override
  EncoderResult encode(dynamic value) {
    if (value is! List) {
      throw AbiException('ArrayCoder expects List, got ${value.runtimeType}');
    }

    if (fixedLength != null && value.length != fixedLength) {
      throw AbiException(
        'Fixed array expects $fixedLength elements, got ${value.length}',
      );
    }

    final encoded = <int>[];

    // Dynamic arrays have a length prefix.
    if (fixedLength == null) {
      encoded.addAll(BigIntUtils.bigIntTo32Bytes(BigInt.from(value.length)));
    }

    // Encode elements.
    if (value.isEmpty) {
      return EncoderResult(encoded, isDynamic: isDynamic);
    }

    // Encode each element.
    final results = <EncoderResult>[];
    for (final item in value) {
      results.add(_elementCoder.encode(item));
    }

    if (!_elementCoder.isDynamic) {
      // All static: concatenate directly.
      for (final r in results) {
        encoded.addAll(r.encoded);
      }
    } else {
      // Dynamic elements: use head/tail encoding.
      final headSize = value.length * 32;
      final head = <int>[];
      final tail = <int>[];

      for (final r in results) {
        final offset = BigInt.from(headSize + tail.length);
        head.addAll(BigIntUtils.bigIntTo32Bytes(offset));
        tail.addAll(r.encoded);
      }

      encoded.addAll(head);
      encoded.addAll(tail);
    }

    return EncoderResult(encoded, isDynamic: isDynamic);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    var dataOffset = offset;
    final int length;

    if (fixedLength != null) {
      length = fixedLength!;
    } else {
      // Read length from data.
      TupleCoder._checkBounds(data, dataOffset, 32, 'array length');
      length = TupleCoder._bytesToInt(
        data.sublist(dataOffset, dataOffset + 32),
      );
      dataOffset += 32;

      // T-03-10: prevent OOM from malicious length.
      if (length > maxDecodeLength) {
        throw AbiException(
          'Array length $length exceeds maximum $maxDecodeLength',
        );
      }
    }

    if (length == 0) {
      return DecoderResult(<dynamic>[], consumed: 32);
    }

    // T-03-09: validate minimum data available.
    if (!_elementCoder.isDynamic) {
      final needed = length * 32;
      if (data.length < dataOffset + needed) {
        throw AbiException(
          'Insufficient data for array decode: '
          'need ${dataOffset + needed}, have ${data.length}',
        );
      }
    }

    final values = <dynamic>[];
    final baseOffset = dataOffset;

    if (!_elementCoder.isDynamic) {
      // Static elements: decode sequentially.
      for (var i = 0; i < length; i++) {
        final result = _elementCoder.decode(data, dataOffset);
        values.add(result.value);
        dataOffset += 32;
      }
    } else {
      // Dynamic elements: read offsets, then decode from base + offset.
      for (var i = 0; i < length; i++) {
        TupleCoder._checkBounds(
          data,
          baseOffset + i * 32,
          32,
          'array element offset',
        );
        final relOffset = TupleCoder._bytesToInt(
          data.sublist(baseOffset + i * 32, baseOffset + i * 32 + 32),
        );

        // T-03-08: validate offset bounds.
        if (baseOffset + relOffset >= data.length) {
          throw AbiException(
            'Array element offset $relOffset out of bounds '
            '(data length: ${data.length})',
          );
        }

        final result = _elementCoder.decode(data, baseOffset + relOffset);
        values.add(result.value);
      }
    }

    return DecoderResult(values, consumed: 32);
  }
}
