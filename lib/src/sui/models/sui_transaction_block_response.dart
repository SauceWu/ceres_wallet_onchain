/// Sui transaction block response model.
///
/// Represents the complete response from `sui_getTransactionBlock` and
/// `sui_executeTransactionBlock`. All fields except [digest] are nullable
/// because they depend on which `SuiTransactionBlockResponseOptions`
/// flags were set in the request (T-07-06 mitigation).
///
/// ```dart
/// final resp = SuiTransactionBlockResponse.fromJson(rpcResult);
/// print(resp.digest);
/// if (resp.effects != null) {
///   print('Status: ${resp.effects!.status.isSuccess}');
/// }
/// ```
library;

import 'sui_effects.dart';
import 'sui_event.dart';
import 'sui_object_change.dart';

/// Complete transaction block response from Sui RPC.
class SuiTransactionBlockResponse {
  /// The transaction digest (always present).
  final String digest;

  /// The transaction data (sender, commands, gas info).
  ///
  /// Null unless `showInput` option was set.
  final Map<String, dynamic>? transaction;

  /// The transaction execution effects.
  ///
  /// Null unless `showEffects` option was set.
  final SuiTransactionEffects? effects;

  /// The events emitted by the transaction.
  ///
  /// Null unless `showEvents` option was set.
  final List<SuiEvent>? events;

  /// The object changes caused by the transaction.
  ///
  /// Null unless `showObjectChanges` option was set.
  final List<SuiObjectChange>? objectChanges;

  /// The balance changes caused by the transaction.
  ///
  /// Null unless `showBalanceChanges` option was set.
  final List<SuiBalanceChange>? balanceChanges;

  /// The timestamp in milliseconds when the transaction was executed.
  final String? timestampMs;

  /// The checkpoint sequence number that includes this transaction.
  final String? checkpoint;

  /// Whether local execution was confirmed before returning.
  final bool? confirmedLocalExecution;

  /// The raw transaction bytes (base64).
  ///
  /// Null unless `showRawInput` option was set.
  final String? rawTransaction;

  /// The raw effects bytes.
  ///
  /// Null unless `showRawEffects` option was set.
  final List<int>? rawEffects;

  /// Creates a [SuiTransactionBlockResponse] with the given fields.
  const SuiTransactionBlockResponse({
    required this.digest,
    this.transaction,
    this.effects,
    this.events,
    this.objectChanges,
    this.balanceChanges,
    this.timestampMs,
    this.checkpoint,
    this.confirmedLocalExecution,
    this.rawTransaction,
    this.rawEffects,
  });

  /// Parses a [SuiTransactionBlockResponse] from a JSON map.
  ///
  /// All option-dependent fields safely handle null/missing keys.
  factory SuiTransactionBlockResponse.fromJson(Map<String, dynamic> json) {
    return SuiTransactionBlockResponse(
      digest: json['digest'] as String,
      transaction: json['transaction'] as Map<String, dynamic>?,
      effects: json['effects'] != null
          ? SuiTransactionEffects.fromJson(
              json['effects'] as Map<String, dynamic>,
            )
          : null,
      events: json['events'] != null
          ? (json['events'] as List<dynamic>)
                .map((e) => SuiEvent.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      objectChanges: json['objectChanges'] != null
          ? (json['objectChanges'] as List<dynamic>)
                .map((e) => SuiObjectChange.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      balanceChanges: json['balanceChanges'] != null
          ? (json['balanceChanges'] as List<dynamic>)
                .map(
                  (e) => SuiBalanceChange.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      timestampMs: json['timestampMs'] as String?,
      checkpoint: json['checkpoint'] as String?,
      confirmedLocalExecution: json['confirmedLocalExecution'] as bool?,
      rawTransaction: json['rawTransaction'] as String?,
      rawEffects: (json['rawEffects'] as List<dynamic>?)?.cast<int>(),
    );
  }
}
