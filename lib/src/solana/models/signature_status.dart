/// Solana transaction signature status model.
///
/// Represents the result from `getSignatureStatuses` RPC method.
///
/// ```dart
/// final status = SignatureStatus.fromJson(statusJson);
/// if (status.err == null) print('Transaction succeeded');
/// ```
library;

/// Parsed signature status from a Solana RPC response.
class SignatureStatus {
  /// The slot in which the transaction was processed.
  final int slot;

  /// The number of confirmations, or `null` if finalized.
  final int? confirmations;

  /// The transaction error, or `null` if successful.
  final dynamic err;

  /// The confirmation status: `processed`, `confirmed`, or `finalized`.
  final String? confirmationStatus;

  /// Creates a [SignatureStatus] with the given field values.
  const SignatureStatus({
    required this.slot,
    this.confirmations,
    this.err,
    this.confirmationStatus,
  });

  /// Parses a [SignatureStatus] from a JSON map returned by Solana RPC.
  factory SignatureStatus.fromJson(Map<String, dynamic> json) {
    return SignatureStatus(
      slot: json['slot'] as int,
      confirmations: json['confirmations'] as int?,
      err: json['err'],
      confirmationStatus: json['confirmationStatus'] as String?,
    );
  }
}
