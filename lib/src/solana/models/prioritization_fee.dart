/// Solana prioritization fee response model.
///
/// Represents entries from `getRecentPrioritizationFees` RPC method.
///
/// ```dart
/// final fee = PrioritizationFee.fromJson(feeJson);
/// print(fee.slot);              // block slot
/// print(fee.prioritizationFee); // fee in micro-lamports (BigInt)
/// ```
library;

/// Parsed prioritization fee from a Solana RPC response.
class PrioritizationFee {
  /// The slot in which the fee was observed.
  final int slot;

  /// The prioritization fee in micro-lamports.
  ///
  /// Stored as [BigInt] for consistency with Solana's u64 type.
  final BigInt prioritizationFee;

  /// Creates a [PrioritizationFee] with the given field values.
  const PrioritizationFee({
    required this.slot,
    required this.prioritizationFee,
  });

  /// Parses a [PrioritizationFee] from a JSON map returned by Solana RPC.
  factory PrioritizationFee.fromJson(Map<String, dynamic> json) {
    return PrioritizationFee(
      slot: json['slot'] as int,
      prioritizationFee: BigInt.from(json['prioritizationFee'] as num),
    );
  }
}
