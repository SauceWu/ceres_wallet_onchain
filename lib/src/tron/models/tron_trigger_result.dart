import 'tron_transaction.dart';

/// Result of `triggersmartcontract` / `triggerconstantcontract` API call.
///
/// For write calls, [transaction] contains the unsigned transaction to sign.
/// For read-only (constant) calls, [constantResult] contains the return data.
///
/// ```dart
/// final result = TronTriggerResult.fromJson(responseJson);
/// if (result.resultOk) {
///   print(result.constantResult); // read-only result hex
/// }
/// ```
class TronTriggerResult {
  /// Whether the trigger call succeeded (`result.result` field).
  final bool resultOk;

  /// Energy used for estimation.
  final int? energyUsed;

  /// Energy penalty applied.
  final int? energyPenalty;

  /// Return values for constant (read-only) calls (hex strings).
  final List<String> constantResult;

  /// Unsigned transaction body for write calls (per D-08).
  /// `null` for constant calls.
  final TronTransaction? transaction;

  /// Creates a [TronTriggerResult].
  const TronTriggerResult({
    required this.resultOk,
    this.energyUsed,
    this.energyPenalty,
    this.constantResult = const [],
    this.transaction,
  });

  /// Parses a [TronTriggerResult] from the API response.
  ///
  /// Does not throw on error results; callers should check [resultOk]
  /// and use the mixin-layer error checking.
  factory TronTriggerResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    return TronTriggerResult(
      resultOk: result?['result'] == true,
      energyUsed: json['energy_used'] as int?,
      energyPenalty: json['energy_penalty'] as int?,
      constantResult: _parseStringList(json['constant_result']),
      transaction: json['transaction'] != null
          ? TronTransaction.fromJson(
              json['transaction'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    return (value as List).cast<String>();
  }
}
