/// Sui balance response model.
///
/// Returned by `suix_getBalance` and `suix_getAllBalances`.
library;

/// The balance of a specific coin type for an address.
class SuiBalance {
  /// The fully qualified coin type (e.g., `0x2::sui::SUI`).
  final String coinType;

  /// The number of coin objects of this type owned by the address.
  final int coinObjectCount;

  /// The total balance across all coin objects, as [BigInt] to avoid
  /// overflow on large balances.
  final BigInt totalBalance;

  /// Creates a [SuiBalance] with the given fields.
  const SuiBalance({
    required this.coinType,
    required this.coinObjectCount,
    required this.totalBalance,
  });

  /// Parses a [SuiBalance] from a JSON map.
  factory SuiBalance.fromJson(Map<String, dynamic> json) {
    return SuiBalance(
      coinType: json['coinType'] as String,
      coinObjectCount: json['coinObjectCount'] as int,
      totalBalance: BigInt.parse(json['totalBalance'] as String),
    );
  }
}

/// Total supply of a coin type.
///
/// Returned by `suix_getTotalSupply`.
class SuiSupply {
  /// The total supply value as [BigInt].
  final BigInt value;

  /// Creates a [SuiSupply].
  const SuiSupply({required this.value});

  /// Parses a [SuiSupply] from a JSON map.
  factory SuiSupply.fromJson(Map<String, dynamic> json) {
    return SuiSupply(value: BigInt.parse(json['value'] as String));
  }
}
