/// Sui dry run transaction result model.
///
/// Represents the response from `sui_dryRunTransactionBlock`,
/// containing the simulated effects, events, and balance changes
/// without actually executing the transaction on-chain.
///
/// ```dart
/// final result = SuiDryRunResult.fromJson(rpcResult);
/// if (result.effects.status.isSuccess) {
///   print('Dry run succeeded');
/// }
/// ```
library;

import 'sui_effects.dart';
import 'sui_event.dart';

/// Result of a dry-run transaction simulation.
class SuiDryRunResult {
  /// The simulated transaction effects.
  final SuiTransactionEffects effects;

  /// The events that would be emitted.
  final List<SuiEvent> events;

  /// The balance changes that would occur.
  final List<SuiBalanceChange> balanceChanges;

  /// The transaction input data, if available.
  final Map<String, dynamic>? input;

  /// Creates a [SuiDryRunResult] with the given fields.
  const SuiDryRunResult({
    required this.effects,
    required this.events,
    required this.balanceChanges,
    this.input,
  });

  /// Parses a [SuiDryRunResult] from a JSON map returned by Sui RPC.
  factory SuiDryRunResult.fromJson(Map<String, dynamic> json) {
    return SuiDryRunResult(
      effects: SuiTransactionEffects.fromJson(
        json['effects'] as Map<String, dynamic>,
      ),
      events: (json['events'] as List<dynamic>)
          .map((e) => SuiEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      balanceChanges: (json['balanceChanges'] as List<dynamic>)
          .map((e) => SuiBalanceChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      input: json['input'] as Map<String, dynamic>?,
    );
  }
}
