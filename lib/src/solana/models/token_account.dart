/// A Solana token account returned by `getTokenAccountsByOwner` and similar methods.
///
/// Contains the account's public key and its full account data including
/// lamports, owner program, parsed token data, and rent epoch.
///
/// ```dart
/// final tokenAccount = TokenAccount.fromJson(jsonMap);
/// print(tokenAccount.pubkey);
/// print(tokenAccount.account['lamports']);
/// ```
class TokenAccount {
  /// The public key of this token account (base-58 encoded).
  final String pubkey;

  /// The full account data map containing `lamports`, `owner`, `data`,
  /// `executable`, and `rentEpoch` fields.
  final Map<String, dynamic> account;

  /// Creates a [TokenAccount] with the given [pubkey] and [account] data.
  const TokenAccount({required this.pubkey, required this.account});

  /// Parses a [TokenAccount] from a Solana RPC JSON response map.
  factory TokenAccount.fromJson(Map<String, dynamic> json) {
    return TokenAccount(
      pubkey: json['pubkey'] as String,
      account: json['account'] as Map<String, dynamic>,
    );
  }
}
