/// Solana token amount response model.
///
/// Represents the `TokenAmount` structure returned by various Solana RPC
/// methods like `getTokenAccountBalance` and `getTokenSupply`.
///
/// ```dart
/// final ta = TokenAmount.fromJson(rpcResponse['result']['value']);
/// print(ta.amount);   // raw string amount
/// print(ta.decimals); // token decimals
/// ```
library;

/// Parsed token amount from a Solana RPC response.
class TokenAmount {
  /// The raw token amount as a string (avoids precision loss).
  final String amount;

  /// The number of decimal places for the token.
  final int decimals;

  /// The UI-friendly amount string (e.g., "1.5"), if provided.
  final String? uiAmountString;

  /// Creates a [TokenAmount] with the given field values.
  const TokenAmount({
    required this.amount,
    required this.decimals,
    this.uiAmountString,
  });

  /// Parses a [TokenAmount] from a JSON map returned by Solana RPC.
  factory TokenAmount.fromJson(Map<String, dynamic> json) {
    return TokenAmount(
      amount: json['amount'] as String,
      decimals: json['decimals'] as int,
      uiAmountString: json['uiAmountString'] as String?,
    );
  }
}
