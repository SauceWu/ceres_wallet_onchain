/// Solana commitment levels for RPC requests.
///
/// Determines the level of finality required for queries and transactions:
///
/// - [processed] — Node has processed the block; no guarantee of finality.
/// - [confirmed] — Block has been voted on by supermajority of the cluster.
/// - [finalized] — Block has been finalized by the cluster.
///
/// ```dart
/// final commitment = SolanaCommitment.confirmed;
/// print(commitment); // confirmed
/// ```
library;

/// Commitment level for Solana RPC requests.
///
/// Maps directly to Solana's `commitment` parameter in JSON-RPC calls.
enum SolanaCommitment {
  /// Least confidence; node has processed the block.
  processed,

  /// Medium confidence; supermajority of the cluster has voted on the block.
  confirmed,

  /// Highest confidence; block has been finalized by the cluster.
  finalized;

  @override
  String toString() => name;
}
