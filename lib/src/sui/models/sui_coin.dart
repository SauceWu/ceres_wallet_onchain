/// Sui coin object response model.
///
/// Returned by `suix_getCoins` and `suix_getAllCoins`.
library;

/// A single coin object owned by an address.
class SuiCoin {
  /// The fully qualified coin type.
  final String coinType;

  /// The object ID of this coin.
  final String coinObjectId;

  /// The object version.
  final String version;

  /// The object digest.
  final String digest;

  /// The coin balance as [BigInt].
  final BigInt balance;

  /// The digest of the transaction that last modified this object.
  final String previousTransaction;

  /// Creates a [SuiCoin] with the given fields.
  const SuiCoin({
    required this.coinType,
    required this.coinObjectId,
    required this.version,
    required this.digest,
    required this.balance,
    required this.previousTransaction,
  });

  /// Parses a [SuiCoin] from a JSON map.
  factory SuiCoin.fromJson(Map<String, dynamic> json) {
    return SuiCoin(
      coinType: json['coinType'] as String,
      coinObjectId: json['coinObjectId'] as String,
      version: json['version'] as String,
      digest: json['digest'] as String,
      balance: BigInt.parse(json['balance'] as String),
      previousTransaction: json['previousTransaction'] as String,
    );
  }
}
