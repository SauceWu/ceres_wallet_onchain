/// Sui Move normalized module, function, and struct models.
///
/// Represents the response from `sui_getNormalizedMoveModule` and related
/// Move introspection RPC methods.
///
/// ```dart
/// final module = MoveNormalizedModule.fromJson(rpcResult);
/// print(module.name);
/// for (final fn in module.exposedFunctions.entries) {
///   print('${fn.key}: entry=${fn.value.isEntry}');
/// }
/// ```
library;

/// A normalized Move module from Sui RPC.
class MoveNormalizedModule {
  /// The Move bytecode file format version.
  final int fileFormatVersion;

  /// The address of the package containing this module.
  final String address;

  /// The name of this module.
  final String name;

  /// The friend modules that have access to this module's private functions.
  final List<dynamic> friends;

  /// The structs defined in this module, keyed by struct name.
  final Map<String, dynamic> structs;

  /// The functions exposed by this module, keyed by function name.
  final Map<String, dynamic> exposedFunctions;

  /// Creates a [MoveNormalizedModule].
  const MoveNormalizedModule({
    required this.fileFormatVersion,
    required this.address,
    required this.name,
    required this.friends,
    required this.structs,
    required this.exposedFunctions,
  });

  /// Parses a [MoveNormalizedModule] from a JSON map returned by Sui RPC.
  factory MoveNormalizedModule.fromJson(Map<String, dynamic> json) {
    return MoveNormalizedModule(
      fileFormatVersion: json['fileFormatVersion'] as int,
      address: json['address'] as String,
      name: json['name'] as String,
      friends: json['friends'] as List<dynamic>,
      structs: json['structs'] as Map<String, dynamic>,
      exposedFunctions: json['exposedFunctions'] as Map<String, dynamic>,
    );
  }
}

/// A normalized Move function from Sui RPC.
class MoveNormalizedFunction {
  /// The visibility level (e.g., `Public`, `Private`, `Friend`).
  final String visibility;

  /// Whether this function is an entry function (callable from transactions).
  final bool isEntry;

  /// The type parameters of this function.
  final List<dynamic> typeParameters;

  /// The parameter types of this function.
  final List<dynamic> parameters;

  /// The return types of this function.
  final List<dynamic> returnTypes;

  /// Creates a [MoveNormalizedFunction].
  const MoveNormalizedFunction({
    required this.visibility,
    required this.isEntry,
    required this.typeParameters,
    required this.parameters,
    required this.returnTypes,
  });

  /// Parses a [MoveNormalizedFunction] from a JSON map returned by Sui RPC.
  factory MoveNormalizedFunction.fromJson(Map<String, dynamic> json) {
    return MoveNormalizedFunction(
      visibility: json['visibility'] as String,
      isEntry: json['isEntry'] as bool,
      typeParameters: json['typeParameters'] as List<dynamic>,
      parameters: json['parameters'] as List<dynamic>,
      returnTypes: json['return'] as List<dynamic>,
    );
  }
}

/// A normalized Move struct from Sui RPC.
class MoveNormalizedStruct {
  /// The abilities of this struct (e.g., `copy`, `drop`, `store`, `key`).
  final Map<String, dynamic> abilities;

  /// The type parameters of this struct.
  final List<dynamic> typeParameters;

  /// The fields of this struct.
  final List<MoveNormalizedField> fields;

  /// Creates a [MoveNormalizedStruct].
  const MoveNormalizedStruct({
    required this.abilities,
    required this.typeParameters,
    required this.fields,
  });

  /// Parses a [MoveNormalizedStruct] from a JSON map returned by Sui RPC.
  factory MoveNormalizedStruct.fromJson(Map<String, dynamic> json) {
    return MoveNormalizedStruct(
      abilities: json['abilities'] as Map<String, dynamic>,
      typeParameters: json['typeParameters'] as List<dynamic>,
      fields: (json['fields'] as List<dynamic>)
          .map((f) => MoveNormalizedField.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single field in a Move struct.
class MoveNormalizedField {
  /// The field name.
  final String name;

  /// The field type (can be a string or complex type map).
  final dynamic type;

  /// Creates a [MoveNormalizedField].
  const MoveNormalizedField({required this.name, required this.type});

  /// Parses a [MoveNormalizedField] from a JSON map.
  factory MoveNormalizedField.fromJson(Map<String, dynamic> json) {
    return MoveNormalizedField(
      name: json['name'] as String,
      type: json['type'],
    );
  }
}
