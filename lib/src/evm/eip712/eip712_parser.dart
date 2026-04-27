// ignore_for_file: public_member_api_docs

import 'eip712_types.dart';

/// Parses raw EIP-712 JSON payloads into [TypedDataV4].
class EIP712Parser {
  const EIP712Parser._();

  static TypedDataV4 parse(Map<String, dynamic> json) {
    final rawTypes = json['types'];
    if (rawTypes is! Map) {
      throw ArgumentError('types is required');
    }
    if (!rawTypes.containsKey('EIP712Domain')) {
      throw ArgumentError('EIP712Domain missing from types');
    }

    final primaryType = json['primaryType'];
    if (primaryType is! String || primaryType.isEmpty) {
      throw ArgumentError('primaryType is required');
    }

    final domain = json['domain'];
    if (domain is! Map) {
      throw ArgumentError('domain is required');
    }

    final message = json['message'];
    if (message is! Map) {
      throw ArgumentError('message is required');
    }

    final types = <String, List<TypeField>>{};
    for (final entry in rawTypes.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) {
        throw ArgumentError('EIP-712 type names must be strings');
      }
      if (value is! List) {
        throw ArgumentError('EIP-712 type "$key" must be a list');
      }
      types[key] = value
          .map(
            (field) =>
                TypeField.fromJson(Map<String, dynamic>.from(field as Map)),
          )
          .toList(growable: false);
    }

    if (!types.containsKey(primaryType)) {
      throw ArgumentError('primaryType "$primaryType" missing from types');
    }

    return TypedDataV4(
      types: types,
      primaryType: primaryType,
      domain: Map<String, dynamic>.from(domain),
      message: Map<String, dynamic>.from(message),
    );
  }
}
