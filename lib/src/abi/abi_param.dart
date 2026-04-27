/// Describes an ABI parameter type for encoding and decoding.
///
/// [AbiParam] is a lightweight descriptor that holds the Solidity type string
/// (e.g. `'uint256'`, `'address'`, `'tuple'`) along with optional metadata
/// such as the parameter name and sub-components for tuple types.
///
/// Use the convenience factory constructors for common types:
/// ```dart
/// AbiParam.uint256()           // uint256
/// AbiParam.address()           // address
/// AbiParam.bytesN(32)          // bytes32
/// AbiParam.tuple([...])        // tuple with components
/// AbiParam.array(AbiParam.uint256())  // uint256[]
/// ```
class AbiParam {
  /// The Solidity type string (e.g. `'uint256'`, `'address'`, `'bytes32'`).
  final String type;

  /// Optional parameter name from the ABI JSON.
  final String? name;

  /// Sub-components for `tuple` types. Empty for non-tuple types.
  final List<AbiParam> components;

  /// Creates an [AbiParam] with the given [type], optional [name], and
  /// [components] (for tuple types).
  const AbiParam({required this.type, this.name, this.components = const []});

  /// Creates an `address` parameter.
  factory AbiParam.address() => const AbiParam(type: 'address');

  /// Creates a `uint256` parameter.
  factory AbiParam.uint256() => const AbiParam(type: 'uint256');

  /// Creates an `int256` parameter.
  factory AbiParam.int256() => const AbiParam(type: 'int256');

  /// Creates a `bool` parameter.
  factory AbiParam.bool() => const AbiParam(type: 'bool');

  /// Creates a `string` parameter.
  factory AbiParam.string() => const AbiParam(type: 'string');

  /// Creates a `bytes` (dynamic) parameter.
  factory AbiParam.bytes() => const AbiParam(type: 'bytes');

  /// Creates a `bytesN` fixed-length parameter where [n] is 1..32.
  factory AbiParam.bytesN(int n) => AbiParam(type: 'bytes$n');

  /// Creates a `uintN` parameter where [n] is 8..256 in steps of 8.
  factory AbiParam.uintN(int n) => AbiParam(type: 'uint$n');

  /// Creates an `intN` parameter where [n] is 8..256 in steps of 8.
  factory AbiParam.intN(int n) => AbiParam(type: 'int$n');

  /// Creates a `tuple` parameter with the given [components].
  factory AbiParam.tuple(List<AbiParam> components) =>
      AbiParam(type: 'tuple', components: components);

  /// Creates a dynamic array parameter `element[]`.
  factory AbiParam.array(AbiParam element) => AbiParam(
    type: '${element.type}[]',
    components: element.type == 'tuple' ? element.components : const [],
  );

  /// Creates a fixed-length array parameter `element[length]`.
  factory AbiParam.fixedArray(AbiParam element, int length) => AbiParam(
    type: '${element.type}[$length]',
    components: element.type == 'tuple' ? element.components : const [],
  );

  /// Whether this type is dynamically sized in the ABI encoding.
  ///
  /// Dynamic types require an offset pointer in the head section and their
  /// actual data is appended to the tail section. Static types are encoded
  /// inline in the head.
  ///
  /// Dynamic types: `string`, `bytes`, `T[]`, tuples containing dynamic
  /// members, and fixed arrays `T[N]` where `T` is dynamic.
  bool get isDynamic {
    if (type == 'string' || type == 'bytes') return true;
    if (type == 'tuple') return components.any((c) => c.isDynamic);
    if (type.endsWith('[]')) return true;
    final fixedMatch = RegExp(r'^(.+)\[(\d+)\]$').firstMatch(type);
    if (fixedMatch != null) {
      final elementType = fixedMatch.group(1)!;
      final elementParam = AbiParam(type: elementType, components: components);
      return elementParam.isDynamic;
    }
    return false;
  }
}
