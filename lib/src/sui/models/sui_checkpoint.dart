/// Sui checkpoint response model.
///
/// Returned by `sui_getCheckpoint` and `sui_getLatestCheckpointSequenceNumber`.
library;

import 'sui_gas_cost_summary.dart';

/// A Sui network checkpoint.
class SuiCheckpoint {
  /// The epoch this checkpoint belongs to.
  final String epoch;

  /// The checkpoint sequence number as [BigInt].
  final BigInt sequenceNumber;

  /// The checkpoint digest.
  final String digest;

  /// Total transactions across the network at this checkpoint.
  final BigInt networkTotalTransactions;

  /// Timestamp in milliseconds.
  final String timestampMs;

  /// The digest of the previous checkpoint, or `null` for genesis.
  final String? previousDigest;

  /// Rolling gas cost summary for the epoch.
  final GasCostSummary epochRollingGasCostSummary;

  /// List of transaction digests in this checkpoint.
  final List<String> transactions;

  /// Creates a [SuiCheckpoint].
  const SuiCheckpoint({
    required this.epoch,
    required this.sequenceNumber,
    required this.digest,
    required this.networkTotalTransactions,
    required this.timestampMs,
    this.previousDigest,
    required this.epochRollingGasCostSummary,
    required this.transactions,
  });

  /// Parses a [SuiCheckpoint] from a JSON map.
  factory SuiCheckpoint.fromJson(Map<String, dynamic> json) {
    return SuiCheckpoint(
      epoch: json['epoch'] as String,
      sequenceNumber: BigInt.parse(json['sequenceNumber'] as String),
      digest: json['digest'] as String,
      networkTotalTransactions: BigInt.parse(
        json['networkTotalTransactions'] as String,
      ),
      timestampMs: json['timestampMs'] as String,
      previousDigest: json['previousDigest'] as String?,
      epochRollingGasCostSummary: GasCostSummary.fromJson(
        json['epochRollingGasCostSummary'] as Map<String, dynamic>,
      ),
      transactions: (json['transactions'] as List<dynamic>).cast<String>(),
    );
  }
}
