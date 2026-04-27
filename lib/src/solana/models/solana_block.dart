import 'solana_transaction.dart';

/// A Solana block object returned by `getBlock`.
///
/// The [transactions] field is optional — it may be `null` when the RPC
/// request uses `transactionDetails: "none"` or `"signatures"` (threat T-06-04).
///
/// ```dart
/// final block = SolanaBlock.fromJson(jsonMap);
/// if (block.transactions != null) {
///   for (final tx in block.transactions!) {
///     print(tx.meta?.fee);
///   }
/// }
/// ```
class SolanaBlock {
  /// The blockhash of this block (base-58 encoded).
  final String blockhash;

  /// The blockhash of this block's parent (base-58 encoded).
  final String previousBlockhash;

  /// The slot index of this block's parent.
  final int parentSlot;

  /// Transactions in this block, or `null` if not requested.
  final List<SolanaTransactionResponse>? transactions;

  /// Unix timestamp when this block was produced, or `null`.
  final int? blockTime;

  /// The block height of this block, or `null`.
  final int? blockHeight;

  /// Block rewards, or `null` if not available.
  final List<Map<String, dynamic>>? rewards;

  /// Creates a [SolanaBlock] with all fields.
  const SolanaBlock({
    required this.blockhash,
    required this.previousBlockhash,
    required this.parentSlot,
    this.transactions,
    this.blockTime,
    this.blockHeight,
    this.rewards,
  });

  /// Parses a [SolanaBlock] from a Solana RPC JSON response map.
  ///
  /// The [transactions] field is defensively parsed as optional (threat T-06-04).
  factory SolanaBlock.fromJson(Map<String, dynamic> json) {
    return SolanaBlock(
      blockhash: json['blockhash'] as String,
      previousBlockhash: json['previousBlockhash'] as String,
      parentSlot: json['parentSlot'] as int,
      transactions: _parseTransactions(json['transactions']),
      blockTime: json['blockTime'] as int?,
      blockHeight: json['blockHeight'] as int?,
      rewards: _parseRewards(json['rewards']),
    );
  }

  static List<SolanaTransactionResponse>? _parseTransactions(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map(
          (e) => SolanaTransactionResponse.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  static List<Map<String, dynamic>>? _parseRewards(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<Map<String, dynamic>>();
  }
}
