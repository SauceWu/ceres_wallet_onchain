/// A token holder entry from `getTokenLargestAccounts`.
///
/// Contains the account address and its token balance details.
///
/// ```dart
/// final entry = TokenLargestAccount.fromJson(jsonMap);
/// print(entry.address); // base58 account address
/// print(entry.amount);  // raw amount string
/// ```
library;

/// Parsed token largest account from a Solana RPC response.
class TokenLargestAccount {
  /// The base58-encoded account address.
  final String address;

  /// The raw token amount as a string (avoids precision loss).
  final String amount;

  /// The number of decimal places for the token.
  final int decimals;

  /// The UI-friendly amount string (e.g., "999.999999"), if provided.
  final String? uiAmountString;

  /// Creates a [TokenLargestAccount] with the given field values.
  const TokenLargestAccount({
    required this.address,
    required this.amount,
    required this.decimals,
    this.uiAmountString,
  });

  /// Parses a [TokenLargestAccount] from a JSON map returned by Solana RPC.
  factory TokenLargestAccount.fromJson(Map<String, dynamic> json) {
    return TokenLargestAccount(
      address: json['address'] as String,
      amount: json['amount'] as String,
      decimals: json['decimals'] as int,
      uiAmountString: json['uiAmountString'] as String?,
    );
  }
}
