/// Sui coin metadata response model.
///
/// Returned by `suix_getCoinMetadata`.
library;

/// Metadata for a coin type (decimals, name, symbol, etc.).
class SuiCoinMetadata {
  /// Number of decimal places for display formatting.
  final int decimals;

  /// Human-readable name of the coin.
  final String name;

  /// Ticker symbol of the coin.
  final String symbol;

  /// Description of the coin.
  final String description;

  /// Optional URL to the coin icon.
  final String? iconUrl;

  /// The metadata object ID.
  final String id;

  /// Creates a [SuiCoinMetadata] with the given fields.
  const SuiCoinMetadata({
    required this.decimals,
    required this.name,
    required this.symbol,
    required this.description,
    this.iconUrl,
    required this.id,
  });

  /// Parses a [SuiCoinMetadata] from a JSON map.
  factory SuiCoinMetadata.fromJson(Map<String, dynamic> json) {
    return SuiCoinMetadata(
      decimals: json['decimals'] as int,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      description: json['description'] as String,
      iconUrl: json['iconUrl'] as String?,
      id: json['id'] as String,
    );
  }
}
