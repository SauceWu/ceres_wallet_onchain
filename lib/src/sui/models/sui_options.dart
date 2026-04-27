/// Options objects for Sui RPC request parameters.
///
/// These classes control which fields the Sui node includes in its
/// response for object and transaction queries.
library;

/// Options controlling which fields are returned for object data queries.
///
/// Pass to methods like `sui_getObject` and `sui_multiGetObjects`.
/// Only non-null fields are serialized to JSON.
///
/// ```dart
/// const opts = SuiObjectDataOptions(showContent: true, showOwner: true);
/// // toJson() => {'showContent': true, 'showOwner': true}
/// ```
class SuiObjectDataOptions {
  /// Include BCS bytes in the response.
  final bool? showBcs;

  /// Include parsed content (Move struct fields) in the response.
  final bool? showContent;

  /// Include display metadata in the response.
  final bool? showDisplay;

  /// Include owner information in the response.
  final bool? showOwner;

  /// Include the previous transaction digest in the response.
  final bool? showPreviousTransaction;

  /// Include storage rebate information in the response.
  final bool? showStorageRebate;

  /// Include the object type in the response.
  final bool? showType;

  /// Creates [SuiObjectDataOptions] with the specified fields.
  const SuiObjectDataOptions({
    this.showBcs,
    this.showContent,
    this.showDisplay,
    this.showOwner,
    this.showPreviousTransaction,
    this.showStorageRebate,
    this.showType,
  });

  /// Convenience constant with all fields set to `true`.
  static const all = SuiObjectDataOptions(
    showBcs: true,
    showContent: true,
    showDisplay: true,
    showOwner: true,
    showPreviousTransaction: true,
    showStorageRebate: true,
    showType: true,
  );

  /// Serializes to JSON, omitting null fields.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (showBcs != null) json['showBcs'] = showBcs;
    if (showContent != null) json['showContent'] = showContent;
    if (showDisplay != null) json['showDisplay'] = showDisplay;
    if (showOwner != null) json['showOwner'] = showOwner;
    if (showPreviousTransaction != null) {
      json['showPreviousTransaction'] = showPreviousTransaction;
    }
    if (showStorageRebate != null) {
      json['showStorageRebate'] = showStorageRebate;
    }
    if (showType != null) json['showType'] = showType;
    return json;
  }
}

/// Options controlling which fields are returned for transaction block queries.
///
/// Pass to methods like `sui_getTransactionBlock` and
/// `sui_multiGetTransactionBlocks`.
///
/// ```dart
/// const opts = SuiTransactionBlockResponseOptions(
///   showEffects: true,
///   showEvents: true,
/// );
/// ```
class SuiTransactionBlockResponseOptions {
  /// Include the transaction input data.
  final bool? showInput;

  /// Include the transaction effects.
  final bool? showEffects;

  /// Include emitted events.
  final bool? showEvents;

  /// Include object change records.
  final bool? showObjectChanges;

  /// Include balance change records.
  final bool? showBalanceChanges;

  /// Include raw input bytes.
  final bool? showRawInput;

  /// Include raw effects bytes.
  final bool? showRawEffects;

  /// Creates [SuiTransactionBlockResponseOptions] with the specified fields.
  const SuiTransactionBlockResponseOptions({
    this.showInput,
    this.showEffects,
    this.showEvents,
    this.showObjectChanges,
    this.showBalanceChanges,
    this.showRawInput,
    this.showRawEffects,
  });

  /// Convenience constant with all fields set to `true`.
  static const all = SuiTransactionBlockResponseOptions(
    showInput: true,
    showEffects: true,
    showEvents: true,
    showObjectChanges: true,
    showBalanceChanges: true,
    showRawInput: true,
    showRawEffects: true,
  );

  /// Serializes to JSON, omitting null fields.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (showInput != null) json['showInput'] = showInput;
    if (showEffects != null) json['showEffects'] = showEffects;
    if (showEvents != null) json['showEvents'] = showEvents;
    if (showObjectChanges != null) {
      json['showObjectChanges'] = showObjectChanges;
    }
    if (showBalanceChanges != null) {
      json['showBalanceChanges'] = showBalanceChanges;
    }
    if (showRawInput != null) json['showRawInput'] = showRawInput;
    if (showRawEffects != null) json['showRawEffects'] = showRawEffects;
    return json;
  }
}
