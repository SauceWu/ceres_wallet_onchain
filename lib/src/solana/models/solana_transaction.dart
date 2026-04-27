import 'transaction_meta.dart';

/// A Solana transaction response from `getTransaction` or block-level results.
///
/// Supports both legacy transactions ([version] is `null`) and v0 versioned
/// transactions ([version] is `0`) as required by SADDR-04.
///
/// The [transaction] field contains the raw JSON with `signatures` and
/// `message` sub-objects. The [meta] field provides execution metadata
/// including fees, balance changes, and log messages.
///
/// ```dart
/// final tx = SolanaTransactionResponse.fromJson(jsonMap);
/// if (tx.version == 0) {
///   // v0 versioned transaction with address table lookups
/// }
/// ```
class SolanaTransactionResponse {
  /// Slot in which this transaction was processed.
  final int? slot;

  /// Raw transaction data containing `signatures` and `message`.
  final Map<String, dynamic> transaction;

  /// Transaction execution metadata, or `null` if not available.
  final TransactionMeta? meta;

  /// Unix timestamp when the block was produced, or `null`.
  final int? blockTime;

  /// Transaction version. `null` for legacy, `0` for v0 versioned transactions.
  ///
  /// The Solana RPC may return this as an integer (`0`) or the string
  /// `"legacy"`. Both are normalized: integer values are kept as-is,
  /// `"legacy"` is converted to `null`.
  final int? version;

  /// Creates a [SolanaTransactionResponse] with all fields.
  const SolanaTransactionResponse({
    this.slot,
    required this.transaction,
    this.meta,
    this.blockTime,
    this.version,
  });

  /// Parses a [SolanaTransactionResponse] from a Solana RPC JSON response map.
  factory SolanaTransactionResponse.fromJson(Map<String, dynamic> json) {
    return SolanaTransactionResponse(
      slot: json['slot'] as int?,
      transaction: json['transaction'] as Map<String, dynamic>,
      meta: json['meta'] != null
          ? TransactionMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      blockTime: json['blockTime'] as int?,
      version: _parseVersion(json['version']),
    );
  }

  /// Normalizes the version field: int values pass through, `"legacy"` and
  /// `null` become `null`.
  static int? _parseVersion(dynamic value) {
    if (value == null || value == 'legacy') return null;
    if (value is int) return value;
    return null;
  }
}
