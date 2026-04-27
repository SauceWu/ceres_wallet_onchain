/// Sui dynamic field info response model.
///
/// Returned by `suix_getDynamicFields`.
library;

/// Information about a dynamic field on a Sui object.
class SuiDynamicFieldInfo {
  /// The field name as a typed value map.
  final Map<String, dynamic> name;

  /// BCS-encoded field name.
  final String bcsName;

  /// The field type (`DynamicField` or `DynamicObject`).
  final String type;

  /// The fully qualified object type of the field value.
  final String objectType;

  /// The object ID of the dynamic field.
  final String objectId;

  /// The object version.
  final int version;

  /// The object digest.
  final String digest;

  /// Creates a [SuiDynamicFieldInfo].
  const SuiDynamicFieldInfo({
    required this.name,
    required this.bcsName,
    required this.type,
    required this.objectType,
    required this.objectId,
    required this.version,
    required this.digest,
  });

  /// Parses a [SuiDynamicFieldInfo] from a JSON map.
  factory SuiDynamicFieldInfo.fromJson(Map<String, dynamic> json) {
    return SuiDynamicFieldInfo(
      name: Map<String, dynamic>.from(json['name'] as Map),
      bcsName: json['bcsName'] as String,
      type: json['type'] as String,
      objectType: json['objectType'] as String,
      objectId: json['objectId'] as String,
      version: json['version'] as int,
      digest: json['digest'] as String,
    );
  }
}
