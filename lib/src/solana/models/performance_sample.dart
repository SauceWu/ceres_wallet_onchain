/// A performance sample returned by `getRecentPerformanceSamples`.
///
/// ```dart
/// final sample = PerformanceSample.fromJson(jsonMap);
/// print('Slot ${sample.slot}: ${sample.numTransactions} txns in ${sample.samplePeriodSecs}s');
/// ```
class PerformanceSample {
  /// Slot in which the sample was taken.
  final int slot;

  /// Number of transactions processed during the sample period.
  final int numTransactions;

  /// Number of slots completed during the sample period.
  final int numSlots;

  /// Duration of the sample period in seconds.
  final int samplePeriodSecs;

  /// Number of non-vote transactions, or `null` if not available.
  final int? numNonVoteTransactions;

  /// Creates a [PerformanceSample] with all fields.
  const PerformanceSample({
    required this.slot,
    required this.numTransactions,
    required this.numSlots,
    required this.samplePeriodSecs,
    this.numNonVoteTransactions,
  });

  /// Parses a [PerformanceSample] from a Solana RPC JSON response map.
  factory PerformanceSample.fromJson(Map<String, dynamic> json) {
    return PerformanceSample(
      slot: json['slot'] as int,
      numTransactions: json['numTransactions'] as int,
      numSlots: json['numSlots'] as int,
      samplePeriodSecs: json['samplePeriodSecs'] as int,
      numNonVoteTransactions: json['numNonVoteTransactions'] as int?,
    );
  }
}
