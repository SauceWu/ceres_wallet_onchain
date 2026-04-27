import '../../utils/bigint_utils.dart';

/// Synchronization progress returned by `eth_syncing` when the node is syncing.
///
/// When a node is actively syncing, `eth_syncing` returns an object with
/// the sync progress. When fully synced, it returns `false` instead.
///
/// ```dart
/// final status = EthSyncStatus.fromJson(jsonMap);
/// print('Progress: ${status.currentBlock} / ${status.highestBlock}');
/// ```
class EthSyncStatus {
  /// Block number at which the sync started.
  final BigInt startingBlock;

  /// Current block number the node has synced to.
  final BigInt currentBlock;

  /// Highest known block number from peers.
  final BigInt highestBlock;

  /// Creates an [EthSyncStatus] with all fields.
  const EthSyncStatus({
    required this.startingBlock,
    required this.currentBlock,
    required this.highestBlock,
  });

  /// Parses an [EthSyncStatus] from a JSON-RPC response map.
  ///
  /// All fields are hex-encoded quantities converted to [BigInt].
  factory EthSyncStatus.fromJson(Map<String, dynamic> json) {
    return EthSyncStatus(
      startingBlock: BigIntUtils.hexToBigInt(json['startingBlock'] as String),
      currentBlock: BigIntUtils.hexToBigInt(json['currentBlock'] as String),
      highestBlock: BigIntUtils.hexToBigInt(json['highestBlock'] as String),
    );
  }
}
