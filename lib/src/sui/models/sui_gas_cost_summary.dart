/// Sui gas cost summary model.
///
/// Represents the gas costs associated with a transaction execution.
/// All amounts are in MIST (the smallest Sui unit) stored as [BigInt]
/// to avoid overflow (T-07-05 mitigation).
///
/// ```dart
/// final gas = GasCostSummary.fromJson(json['gasUsed']);
/// print(gas.computationCost); // BigInt
/// print(gas.totalCost);       // computed total
/// ```
library;

/// Gas cost breakdown for a Sui transaction.
class GasCostSummary {
  /// The computation cost in MIST.
  final BigInt computationCost;

  /// The storage cost in MIST.
  final BigInt storageCost;

  /// The storage rebate in MIST.
  final BigInt storageRebate;

  /// The non-refundable storage fee in MIST.
  final BigInt nonRefundableStorageFee;

  /// Creates a [GasCostSummary] with the given cost values.
  const GasCostSummary({
    required this.computationCost,
    required this.storageCost,
    required this.storageRebate,
    required this.nonRefundableStorageFee,
  });

  /// The total gas cost (computation + storage - rebate).
  BigInt get totalCost => computationCost + storageCost - storageRebate;

  /// Parses a [GasCostSummary] from a JSON map returned by Sui RPC.
  factory GasCostSummary.fromJson(Map<String, dynamic> json) {
    return GasCostSummary(
      computationCost: BigInt.parse(json['computationCost'].toString()),
      storageCost: BigInt.parse(json['storageCost'].toString()),
      storageRebate: BigInt.parse(json['storageRebate'].toString()),
      nonRefundableStorageFee: BigInt.parse(
        json['nonRefundableStorageFee'].toString(),
      ),
    );
  }
}
