// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/crypto/quick_crypto.dart';

import '../../abi/abi_coder.dart';
import '../../abi/abi_param.dart';
import '../evm_address.dart';
import 'eip712_types.dart';

/// EIP-712 hashing helpers.
class EIP712Hasher {
  const EIP712Hasher._();

  static Uint8List digest(TypedDataV4 typedData) {
    final domainHash = hashStruct('EIP712Domain', typedData.domain, typedData);
    final messageHash = hashStruct(
      typedData.primaryType,
      typedData.message,
      typedData,
    );
    return _keccak(<int>[0x19, 0x01, ...domainHash, ...messageHash]);
  }

  static Uint8List hashStruct(
    String typeName,
    Map<String, dynamic> data,
    TypedDataV4 typedData,
  ) {
    final fields = typedData.fieldsOf(typeName);
    final encoded = <int>[...typeHash(typeName, typedData)];
    for (final field in fields) {
      final value = data.containsKey(field.name)
          ? data[field.name]
          : _zeroValue(field.type, typedData);
      encoded.addAll(_encodeFieldValue(field.type, value, typedData));
    }
    return _keccak(encoded);
  }

  static Uint8List typeHash(String typeName, TypedDataV4 typedData) {
    return _keccak(utf8.encode(encodeType(typeName, typedData)));
  }

  static String encodeType(String typeName, TypedDataV4 typedData) {
    final dependencies = _collectDependencies(typeName, typedData)
      ..remove(typeName);
    final sortedDependencies = dependencies.toList()..sort();

    final orderedTypes = <String>[typeName, ...sortedDependencies];
    return orderedTypes.map((name) {
      final currentFields = typedData.fieldsOf(name);
      final signature = currentFields
          .map((field) => '${field.type} ${field.name}')
          .join(',');
      return '$name($signature)';
    }).join();
  }

  static Set<String> _collectDependencies(String root, TypedDataV4 typedData) {
    final collected = <String>{};

    void visit(String typeName) {
      if (!typedData.types.containsKey(typeName) ||
          collected.contains(typeName)) {
        return;
      }
      collected.add(typeName);
      for (final field in typedData.fieldsOf(typeName)) {
        final baseType = _baseType(field.type);
        if (typedData.types.containsKey(baseType)) {
          visit(baseType);
        }
      }
    }

    visit(root);
    return collected;
  }

  static List<int> _encodeFieldValue(
    String type,
    dynamic value,
    TypedDataV4 typedData,
  ) {
    final arrayMatch = RegExp(r'^(.+)\[(\d*)\]$').firstMatch(type);
    if (arrayMatch != null) {
      final elementType = arrayMatch.group(1)!;
      if (value is! List) {
        throw ArgumentError('Expected array value for type $type');
      }
      final encodedItems = <int>[];
      for (final element in value) {
        encodedItems.addAll(_encodeFieldValue(elementType, element, typedData));
      }
      return _keccak(encodedItems);
    }

    final customType = _baseType(type);
    if (typedData.types.containsKey(customType)) {
      if (value is! Map) {
        throw ArgumentError('Expected struct value for type $customType');
      }
      return hashStruct(
        customType,
        Map<String, dynamic>.from(value),
        typedData,
      );
    }

    if (type == 'string') {
      if (value is! String) {
        throw ArgumentError('Expected String for type string');
      }
      return _keccak(utf8.encode(value));
    }

    if (type == 'bytes') {
      return _keccak(_bytesValue(value));
    }

    if (RegExp(r'^bytes([1-9]|[12]\d|3[0-2])$').hasMatch(type)) {
      return AbiCoder.encode([AbiParam(type: type)], [_bytesValue(value)]);
    }

    if (type == 'bool') {
      if (value is! bool) {
        throw ArgumentError('Expected bool for type bool');
      }
      return AbiCoder.encode([AbiParam.bool()], [value]);
    }

    if (type == 'address') {
      final normalized = value is EvmAddress
          ? value
          : EvmAddress(value as String);
      return AbiCoder.encode([AbiParam.address()], [normalized]);
    }

    if (RegExp(r'^u?int(\d+)?$').hasMatch(type)) {
      return AbiCoder.encode(
        [AbiParam(type: _normalizeNumberType(type))],
        [_parseBigInt(value)],
      );
    }

    throw ArgumentError('Unsupported EIP-712 type: $type');
  }

  static dynamic _zeroValue(String type, TypedDataV4 typedData) {
    if (RegExp(r'^u?int(\d+)?$').hasMatch(type)) return BigInt.zero;
    if (type == 'bool') return false;
    if (type == 'address') return '0x0000000000000000000000000000000000000000';
    if (type == 'string') return '';
    if (type == 'bytes') return <int>[];
    if (RegExp(r'^bytes([1-9]|[12]\d|3[0-2])$').hasMatch(type)) {
      return Uint8List(int.parse(type.substring(5)));
    }
    if (type.endsWith(']')) return <dynamic>[];
    final baseType = _baseType(type);
    if (typedData.types.containsKey(baseType)) return <String, dynamic>{};
    return null;
  }

  static List<int> _bytesValue(dynamic value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return value;
    }
    if (value is String) {
      if (value.startsWith('0x')) {
        final hex = value.substring(2);
        if (hex.length.isOdd) {
          throw ArgumentError('Hex bytes must have even length');
        }
        return [
          for (var i = 0; i < hex.length; i += 2)
            int.parse(hex.substring(i, i + 2), radix: 16),
        ];
      }
      return utf8.encode(value);
    }
    throw ArgumentError('Unsupported bytes value: ${value.runtimeType}');
  }

  static BigInt _parseBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      if (value.startsWith('0x') || value.startsWith('0X')) {
        return BigInt.parse(value.substring(2), radix: 16);
      }
      return BigInt.parse(value);
    }
    throw ArgumentError('Unsupported numeric value: ${value.runtimeType}');
  }

  static String _normalizeNumberType(String type) {
    if (type == 'uint') return 'uint256';
    if (type == 'int') return 'int256';
    return type;
  }

  static String _baseType(String type) =>
      type.replaceAll(RegExp(r'\[[^\]]*\]'), '');

  static Uint8List _keccak(List<int> bytes) =>
      Uint8List.fromList(QuickCrypto.keccack256Hash(bytes));
}
