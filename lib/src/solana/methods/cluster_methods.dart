/// Cluster and node information Solana RPC methods.
///
/// Provides methods for querying cluster nodes, health status, version,
/// identity, genesis hash, supply, performance samples, snapshot slots,
/// minimum ledger slot, and requesting airdrops.
///
/// Contains 10 methods: getClusterNodes, getHealth, getVersion, getIdentity,
/// getGenesisHash, getSupply, getRecentPerformanceSamples,
/// getHighestSnapshotSlot, minimumLedgerSlot, requestAirdrop.
library;

import '../../core/json_rpc_transport.dart';
import '../models/cluster_node.dart';
import '../models/performance_sample.dart';
import '../models/snapshot_slot.dart';
import '../models/supply.dart';
import '../solana_address.dart';
import '../solana_commitment.dart';

/// Cluster and node information RPC methods for Solana.
///
/// Requires access to a [JsonRpcTransport] via the `transport` getter.
mixin SolanaClusterMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns information about all the nodes participating in the cluster.
  ///
  /// Calls `getClusterNodes`. Returns a list of [ClusterNode] objects.
  ///
  /// ```dart
  /// final nodes = await client.getClusterNodes();
  /// for (final node in nodes) {
  ///   print('${node.pubkey} at ${node.gossip}');
  /// }
  /// ```
  Future<List<ClusterNode>> getClusterNodes() async {
    final result = await transport.send('getClusterNodes');
    return (result as List)
        .map((e) => ClusterNode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the current health of the node.
  ///
  /// Calls `getHealth`. Returns `"ok"` if the node is healthy.
  ///
  /// ```dart
  /// final health = await client.getHealth();
  /// assert(health == 'ok');
  /// ```
  Future<String> getHealth() async {
    final result = await transport.send('getHealth');
    return result as String;
  }

  /// Returns the current Solana version running on the node.
  ///
  /// Calls `getVersion`. Returns a map containing `solana-core` (version
  /// string) and `feature-set` (feature set identifier).
  ///
  /// ```dart
  /// final version = await client.getVersion();
  /// print('Solana ${version['solana-core']}');
  /// ```
  Future<Map<String, dynamic>> getVersion() async {
    final result = await transport.send('getVersion');
    return result as Map<String, dynamic>;
  }

  /// Returns the identity public key for the current node.
  ///
  /// Calls `getIdentity`. Returns the base-58 encoded identity public key.
  ///
  /// ```dart
  /// final identity = await client.getIdentity();
  /// print('Node identity: $identity');
  /// ```
  Future<String> getIdentity() async {
    final result = await transport.send('getIdentity');
    return (result as Map<String, dynamic>)['identity'] as String;
  }

  /// Returns the genesis hash of the ledger.
  ///
  /// Calls `getGenesisHash`. Returns a base-58 encoded hash string.
  ///
  /// ```dart
  /// final hash = await client.getGenesisHash();
  /// ```
  Future<String> getGenesisHash() async {
    final result = await transport.send('getGenesisHash');
    return result as String;
  }

  /// Returns information about the current supply.
  ///
  /// Calls `getSupply`. Returns a [Supply] extracted from the RpcResponse
  /// `value` field.
  ///
  /// - [excludeNonCirculatingAccountsList]: If `true`, the returned
  ///   [Supply.nonCirculatingAccounts] list will be empty.
  ///
  /// ```dart
  /// final supply = await client.getSupply();
  /// print('Total: ${supply.total} lamports');
  /// ```
  Future<Supply> getSupply({
    SolanaCommitment? commitment,
    bool? excludeNonCirculatingAccountsList,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;
    if (excludeNonCirculatingAccountsList != null) {
      config['excludeNonCirculatingAccountsList'] =
          excludeNonCirculatingAccountsList;
    }

    final params = config.isEmpty ? <dynamic>[] : <dynamic>[config];
    final result = await transport.send('getSupply', params);
    final map = result as Map<String, dynamic>;
    return Supply.fromJson(map['value'] as Map<String, dynamic>);
  }

  /// Returns a list of recent performance samples.
  ///
  /// Calls `getRecentPerformanceSamples`. Returns up to [limit] samples
  /// (default determined by the node, unless specified).
  ///
  /// ```dart
  /// final samples = await client.getRecentPerformanceSamples(limit: 10);
  /// ```
  Future<List<PerformanceSample>> getRecentPerformanceSamples({
    int? limit,
  }) async {
    final params = limit != null ? <dynamic>[limit] : <dynamic>[];
    final result = await transport.send('getRecentPerformanceSamples', params);
    return (result as List)
        .map((e) => PerformanceSample.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the highest slot information that the node has snapshots for.
  ///
  /// Calls `getHighestSnapshotSlot`. Returns a [SnapshotSlot] with full
  /// and optional incremental snapshot slot numbers.
  ///
  /// ```dart
  /// final snapshot = await client.getHighestSnapshotSlot();
  /// print('Full snapshot at slot ${snapshot.full}');
  /// ```
  Future<SnapshotSlot> getHighestSnapshotSlot() async {
    final result = await transport.send('getHighestSnapshotSlot');
    return SnapshotSlot.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the lowest slot that the node has information about in its
  /// ledger.
  ///
  /// Calls `minimumLedgerSlot`. Returns the slot number as an [int].
  ///
  /// ```dart
  /// final slot = await client.minimumLedgerSlot();
  /// ```
  Future<int> minimumLedgerSlot() async {
    final result = await transport.send('minimumLedgerSlot');
    return result as int;
  }

  /// Requests an airdrop of lamports to a Solana address.
  ///
  /// Calls `requestAirdrop` with the given [address] and [lamports] amount.
  /// Returns the transaction signature as a base-58 encoded string.
  ///
  /// **Note:** Only available on devnet and testnet.
  ///
  /// ```dart
  /// final sig = await client.requestAirdrop(addr, 1000000000); // 1 SOL
  /// ```
  Future<String> requestAirdrop(SolanaAddress address, int lamports) async {
    final result = await transport.send('requestAirdrop', [
      address.toBase58(),
      lamports,
    ]);
    return result as String;
  }
}
