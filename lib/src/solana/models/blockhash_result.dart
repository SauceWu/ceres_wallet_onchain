/// Solana blockhash response model.
///
/// Represents the result from `getLatestBlockhash` and
/// `getRecentBlockhash` (deprecated) RPC methods.
///
/// ```dart
/// final result = BlockhashResult.fromJson(rpcResponse['result']['value']);
/// print(result.blockhash); // base58 blockhash string
/// ```
library;

/// Parsed blockhash result from a Solana RPC response.
class BlockhashResult {
  /// The base58-encoded blockhash string.
  final String blockhash;

  /// The last block height at which this blockhash will be valid.
  final int lastValidBlockHeight;

  /// Creates a [BlockhashResult] with the given field values.
  const BlockhashResult({
    required this.blockhash,
    required this.lastValidBlockHeight,
  });

  /// Parses a [BlockhashResult] from a JSON map returned by Solana RPC.
  factory BlockhashResult.fromJson(Map<String, dynamic> json) {
    return BlockhashResult(
      blockhash: json['blockhash'] as String,
      lastValidBlockHeight: json['lastValidBlockHeight'] as int,
    );
  }
}
