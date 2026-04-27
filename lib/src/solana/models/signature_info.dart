/// Solana transaction signature information model.
///
/// Represents entries from `getSignaturesForAddress` RPC method.
///
/// ```dart
/// final info = SignatureInfo.fromJson(signatureJson);
/// print(info.signature); // transaction signature
/// print(info.blockTime); // Unix timestamp or null
/// ```
library;

/// Parsed signature information from a Solana RPC response.
class SignatureInfo {
  /// The transaction signature (base58-encoded).
  final String signature;

  /// The slot containing the transaction.
  final int slot;

  /// The transaction error, or `null` if successful.
  final dynamic err;

  /// The memo associated with the transaction, if any.
  final String? memo;

  /// The estimated Unix timestamp of the block, or `null` if unavailable.
  final int? blockTime;

  /// The confirmation status at the time of the query.
  final String? confirmationStatus;

  /// Creates a [SignatureInfo] with the given field values.
  const SignatureInfo({
    required this.signature,
    required this.slot,
    this.err,
    this.memo,
    this.blockTime,
    this.confirmationStatus,
  });

  /// Parses a [SignatureInfo] from a JSON map returned by Solana RPC.
  factory SignatureInfo.fromJson(Map<String, dynamic> json) {
    return SignatureInfo(
      signature: json['signature'] as String,
      slot: json['slot'] as int,
      err: json['err'],
      memo: json['memo'] as String?,
      blockTime: json['blockTime'] as int?,
      confirmationStatus: json['confirmationStatus'] as String?,
    );
  }
}
