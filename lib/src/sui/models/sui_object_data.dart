/// Sui object data model.
///
/// Represents the `data` field in a `sui_getObject` response.
/// All option-dependent fields are nullable since they only appear
/// when the corresponding `SuiObjectDataOptions` flag is set.
///
/// ```dart
/// final data = SuiObjectData.fromJson(json['data']);
/// print(data.objectId); // always present
/// print(data.owner);    // null unless showOwner was requested
/// ```
library;

import 'sui_object_owner.dart';

/// Parsed object data from a Sui RPC response.
class SuiObjectData {
  /// The unique identifier of this object.
  final String objectId;

  /// The version (sequence number) of this object.
  final BigInt version;

  /// The base64-encoded digest of this object.
  final String digest;

  /// The Move type of this object (e.g., `0x2::coin::Coin<0x2::sui::SUI>`).
  ///
  /// Null unless `showType` option was set.
  final String? type;

  /// The ownership information for this object.
  ///
  /// Null unless `showOwner` option was set.
  final SuiObjectOwner? owner;

  /// The digest of the transaction that last mutated this object.
  ///
  /// Null unless `showPreviousTransaction` option was set.
  final String? previousTransaction;

  /// The storage rebate in MIST for this object.
  ///
  /// Null unless `showStorageRebate` option was set.
  final BigInt? storageRebate;

  /// The Move content of this object (parsed).
  ///
  /// Null unless `showContent` option was set.
  final Map<String, dynamic>? content;

  /// The BCS-encoded content of this object.
  ///
  /// Null unless `showBcs` option was set.
  final Map<String, dynamic>? bcs;

  /// The display metadata for this object.
  ///
  /// Null unless `showDisplay` option was set.
  final Map<String, dynamic>? display;

  /// Creates a [SuiObjectData] with the given field values.
  const SuiObjectData({
    required this.objectId,
    required this.version,
    required this.digest,
    this.type,
    this.owner,
    this.previousTransaction,
    this.storageRebate,
    this.content,
    this.bcs,
    this.display,
  });

  /// Parses a [SuiObjectData] from a JSON map returned by Sui RPC.
  ///
  /// All option-dependent fields safely handle null/missing keys.
  factory SuiObjectData.fromJson(Map<String, dynamic> json) {
    return SuiObjectData(
      objectId: json['objectId'] as String,
      version: BigInt.parse(json['version'].toString()),
      digest: json['digest'] as String,
      type: json['type'] as String?,
      owner: json['owner'] != null
          ? SuiObjectOwner.fromJson(json['owner'])
          : null,
      previousTransaction: json['previousTransaction'] as String?,
      storageRebate: json['storageRebate'] != null
          ? BigInt.parse(json['storageRebate'].toString())
          : null,
      content: json['content'] as Map<String, dynamic>?,
      bcs: json['bcs'] as Map<String, dynamic>?,
      display: json['display'] as Map<String, dynamic>?,
    );
  }
}
