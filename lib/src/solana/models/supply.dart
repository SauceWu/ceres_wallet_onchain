/// Token supply information returned by `getSupply`.
///
/// All lamport values use [BigInt] for safe handling of large numbers.
///
/// ```dart
/// final supply = Supply.fromJson(jsonMap);
/// print('Total: ${supply.total}, circulating: ${supply.circulating}');
/// ```
class Supply {
  /// Total supply in lamports.
  final BigInt total;

  /// Circulating supply in lamports.
  final BigInt circulating;

  /// Non-circulating supply in lamports.
  final BigInt nonCirculating;

  /// Accounts holding non-circulating supply (base-58 encoded).
  final List<String> nonCirculatingAccounts;

  /// Creates a [Supply] with all fields.
  const Supply({
    required this.total,
    required this.circulating,
    required this.nonCirculating,
    required this.nonCirculatingAccounts,
  });

  /// Parses a [Supply] from a Solana RPC JSON response map.
  factory Supply.fromJson(Map<String, dynamic> json) {
    return Supply(
      total: BigInt.from(json['total'] as num),
      circulating: BigInt.from(json['circulating'] as num),
      nonCirculating: BigInt.from(json['nonCirculating'] as num),
      nonCirculatingAccounts: (json['nonCirculatingAccounts'] as List)
          .cast<String>(),
    );
  }
}
