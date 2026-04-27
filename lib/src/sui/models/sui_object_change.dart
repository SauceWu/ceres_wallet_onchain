/// Sui object change model for transaction effects.
///
/// Represents a single object change within a transaction's effects.
/// Sui has 6 change types: published, transferred, mutated, deleted,
/// wrapped, and created. A single class with nullable fields handles
/// all variants, keyed by the [type] discriminator.
///
/// ```dart
/// final change = SuiObjectChange.fromJson(json);
/// if (change.type == 'created') {
///   print('Created object: ${change.objectId}');
/// }
/// ```
library;

import 'sui_object_owner.dart';

/// A single object change in a Sui transaction's effects.
///
/// The [type] field discriminates between change kinds:
/// `published`, `transferred`, `mutated`, `deleted`, `wrapped`, `created`.
/// Fields not applicable to a given type will be null.
class SuiObjectChange {
  /// The type of change: published, transferred, mutated, deleted,
  /// wrapped, or created.
  final String type;

  /// The sender of the transaction that caused this change.
  final String? sender;

  /// The new owner of the object after the change.
  final SuiObjectOwner? owner;

  /// The Move type of the object (e.g., `0x2::coin::Coin<0x2::sui::SUI>`).
  final String? objectType;

  /// The object ID affected by this change.
  final String? objectId;

  /// The object version after this change.
  final BigInt? version;

  /// The previous version before this change (for mutated/transferred).
  final BigInt? previousVersion;

  /// The object digest after this change.
  final String? digest;

  /// The package ID (only for `published` type).
  final String? packageId;

  /// The modules published (only for `published` type).
  final List<String>? modules;

  /// Creates a [SuiObjectChange] with the given field values.
  const SuiObjectChange({
    required this.type,
    this.sender,
    this.owner,
    this.objectType,
    this.objectId,
    this.version,
    this.previousVersion,
    this.digest,
    this.packageId,
    this.modules,
  });

  /// Parses a [SuiObjectChange] from a JSON map returned by Sui RPC.
  factory SuiObjectChange.fromJson(Map<String, dynamic> json) {
    return SuiObjectChange(
      type: json['type'] as String,
      sender: json['sender'] as String?,
      owner: json['owner'] != null
          ? SuiObjectOwner.fromJson(json['owner'])
          : null,
      objectType: json['objectType'] as String?,
      objectId: json['objectId'] as String?,
      version: json['version'] != null
          ? BigInt.parse(json['version'].toString())
          : null,
      previousVersion: json['previousVersion'] != null
          ? BigInt.parse(json['previousVersion'].toString())
          : null,
      digest: json['digest'] as String?,
      packageId: json['packageId'] as String?,
      modules: json['modules'] != null
          ? (json['modules'] as List<dynamic>).cast<String>()
          : null,
    );
  }
}
