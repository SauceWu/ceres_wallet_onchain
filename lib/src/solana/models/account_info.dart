/// Solana account information response model.
///
/// Represents the response from `getAccountInfo` and similar RPC methods.
/// All numeric fields that may exceed JavaScript's `Number.MAX_SAFE_INTEGER`
/// are stored as [BigInt] for Web safety.
///
/// ```dart
/// final info = AccountInfo.fromJson(rpcResponse['result']['value']);
/// print(info.lamports); // BigInt
/// print(info.owner);    // base58 program address
/// ```
library;

/// Parsed account information from a Solana RPC response.
class AccountInfo {
  /// The number of lamports held by this account.
  final BigInt lamports;

  /// The base58-encoded program that owns this account.
  final String owner;

  /// Whether this account's data contains a loaded program.
  final bool executable;

  /// The epoch at which this account will next owe rent.
  ///
  /// Stored as [BigInt] because Solana defines this as u64.
  final BigInt rentEpoch;

  /// The raw data associated with this account, typically
  /// `[base64_encoded_data, encoding]`.
  final List<String> data;

  /// The data size of the account (optional in some responses).
  final int? space;

  /// Creates an [AccountInfo] with the given field values.
  const AccountInfo({
    required this.lamports,
    required this.owner,
    required this.executable,
    required this.rentEpoch,
    required this.data,
    this.space,
  });

  /// Parses an [AccountInfo] from a JSON map returned by Solana RPC.
  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      lamports: BigInt.from(json['lamports'] as num),
      owner: json['owner'] as String,
      executable: json['executable'] as bool,
      rentEpoch: BigInt.from(json['rentEpoch'] as num),
      data: (json['data'] as List<dynamic>).cast<String>(),
      space: json['space'] as int?,
    );
  }
}
