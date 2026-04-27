// ignore_for_file: public_member_api_docs

import 'dart:collection';

/// A single named field inside an EIP-712 struct type.
class TypeField {
  final String name;
  final String type;

  const TypeField({required this.name, required this.type});

  factory TypeField.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final type = json['type'];
    if (name is! String || name.isEmpty) {
      throw ArgumentError('EIP-712 field name is required');
    }
    if (type is! String || type.isEmpty) {
      throw ArgumentError('EIP-712 field type is required');
    }
    return TypeField(name: name, type: type);
  }
}

/// Parsed EIP-712 typed data payload.
class TypedDataV4 {
  final Map<String, List<TypeField>> types;
  final String primaryType;
  final Map<String, dynamic> domain;
  final Map<String, dynamic> message;

  const TypedDataV4({
    required this.types,
    required this.primaryType,
    required this.domain,
    required this.message,
  });

  /// Returns an immutable view of the fields for [typeName].
  List<TypeField> fieldsOf(String typeName) {
    final fields = types[typeName];
    if (fields == null) {
      throw ArgumentError('Unknown EIP-712 type: $typeName');
    }
    return UnmodifiableListView(fields);
  }
}
