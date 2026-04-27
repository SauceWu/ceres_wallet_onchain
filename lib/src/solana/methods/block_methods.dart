/// Solana block and slot related RPC methods.
///
/// Provides typed access to `getBlock`, `getBlockHeight`, `getBlocks`,
/// `getBlocksWithLimit`, `getBlockTime`, `getBlockProduction`,
/// `getBlockCommitment`, `getFirstAvailableBlock`, `getSlot`,
/// `getSlotLeader`, and `getSlotLeaders` RPC methods.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to a Solana RPC client class.
///
/// ```dart
/// class MySolanaClient with SolanaBlockMethods {
///   @override
///   final JsonRpcTransport transport;
///   MySolanaClient(this.transport);
/// }
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/block_commitment.dart';
import '../models/block_production.dart';
import '../models/solana_block.dart';
import '../solana_commitment.dart';

/// Block and slot related Solana JSON-RPC methods.
///
/// Covers SOL-11 through SOL-21: getBlock, getBlockHeight, getBlocks,
/// getBlocksWithLimit, getBlockTime, getBlockProduction, getBlockCommitment,
/// getFirstAvailableBlock, getSlot, getSlotLeader, getSlotLeaders.
mixin SolanaBlockMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Retrieves a block at the given [slot].
  ///
  /// Returns `null` if the block is not available (e.g., skipped slot).
  ///
  /// Always sends `maxSupportedTransactionVersion: 0` by default to avoid
  /// filtering out versioned transactions (threat T-06-09).
  ///
  /// The [transactionDetails] parameter controls the level of transaction
  /// detail returned: `'full'` (default), `'signatures'`, `'none'`, or
  /// `'accounts'`.
  ///
  /// The [commitment] parameter specifies the desired commitment level.
  Future<SolanaBlock?> getBlock(
    int slot, {
    SolanaCommitment? commitment,
    String? transactionDetails,
    int maxSupportedTransactionVersion = 0,
  }) async {
    final config = <String, dynamic>{
      'maxSupportedTransactionVersion': maxSupportedTransactionVersion,
    };
    if (commitment != null) {
      config['commitment'] = commitment.name;
    }
    if (transactionDetails != null) {
      config['transactionDetails'] = transactionDetails;
    }

    final result = await transport.send('getBlock', [slot, config]);
    if (result == null) return null;
    return SolanaBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the current block height of the node.
  ///
  /// Directly returns an [int] (not wrapped in RpcResponse).
  Future<int> getBlockHeight({SolanaCommitment? commitment}) async {
    final params = <dynamic>[];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result = await transport.send('getBlockHeight', params);
    return result as int;
  }

  /// Returns a list of confirmed blocks between [startSlot] and optional
  /// [endSlot].
  ///
  /// If [endSlot] is omitted, the RPC returns blocks from [startSlot] to
  /// the latest confirmed block (capped at 500,000 slots).
  Future<List<int>> getBlocks(
    int startSlot, {
    int? endSlot,
    SolanaCommitment? commitment,
  }) async {
    final params = <dynamic>[startSlot];
    if (endSlot != null) {
      params.add(endSlot);
    }
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result = await transport.send('getBlocks', params);
    return (result as List).cast<int>();
  }

  /// Returns a list of confirmed blocks starting at [startSlot] for up to
  /// [limit] blocks.
  Future<List<int>> getBlocksWithLimit(
    int startSlot,
    int limit, {
    SolanaCommitment? commitment,
  }) async {
    final params = <dynamic>[startSlot, limit];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result = await transport.send('getBlocksWithLimit', params);
    return (result as List).cast<int>();
  }

  /// Returns the estimated production time of a block at [slot].
  ///
  /// Returns `null` if timestamp is not available for the block.
  Future<int?> getBlockTime(int slot) async {
    final result = await transport.send('getBlockTime', [slot]);
    return result as int?;
  }

  /// Returns recent block production information.
  ///
  /// The response is RpcResponse-wrapped; this method extracts the `value`.
  Future<BlockProduction> getBlockProduction({
    SolanaCommitment? commitment,
  }) async {
    final params = <dynamic>[];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result =
        await transport.send('getBlockProduction', params)
            as Map<String, dynamic>;
    final value = result['value'] as Map<String, dynamic>;
    return BlockProduction.fromJson(value);
  }

  /// Returns commitment for a particular block identified by [slot].
  ///
  /// Directly returned (not RpcResponse-wrapped).
  Future<BlockCommitment> getBlockCommitment(int slot) async {
    final result =
        await transport.send('getBlockCommitment', [slot])
            as Map<String, dynamic>;
    return BlockCommitment.fromJson(result);
  }

  /// Returns the slot of the lowest confirmed block not purged from the ledger.
  Future<int> getFirstAvailableBlock() async {
    final result = await transport.send('getFirstAvailableBlock');
    return result as int;
  }

  /// Returns the slot that has reached the given or default commitment level.
  Future<int> getSlot({SolanaCommitment? commitment}) async {
    final params = <dynamic>[];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result = await transport.send('getSlot', params);
    return result as int;
  }

  /// Returns the current slot leader as a base-58 encoded public key.
  Future<String> getSlotLeader({SolanaCommitment? commitment}) async {
    final params = <dynamic>[];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result = await transport.send('getSlotLeader', params);
    return result as String;
  }

  /// Returns the slot leaders for a range starting at [startSlot] for
  /// [limit] slots.
  Future<List<String>> getSlotLeaders(int startSlot, int limit) async {
    final result = await transport.send('getSlotLeaders', [startSlot, limit]);
    return (result as List).cast<String>();
  }
}
