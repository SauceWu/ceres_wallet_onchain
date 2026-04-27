/// A Solana account balance entry from `getLargestAccounts`.
///
/// Contains the account's base58 address and its lamport balance.
///
/// ```dart
/// final entry = AccountBalance.fromJson({'address': '...', 'lamports': 1000000});
/// print(entry.address);  // base58 address
/// print(entry.lamports); // BigInt
/// ```
library;

/// Parsed account balance from a Solana RPC response.
class AccountBalance {
  /// The base58-encoded account address.
  final String address;

  /// The number of lamports held by this account.
  final BigInt lamports;

  /// Creates an [AccountBalance] with the given field values.
  const AccountBalance({required this.address, required this.lamports});

  /// Parses an [AccountBalance] from a JSON map returned by Solana RPC.
  factory AccountBalance.fromJson(Map<String, dynamic> json) {
    return AccountBalance(
      address: json['address'] as String,
      lamports: BigInt.from(json['lamports'] as num),
    );
  }
}
