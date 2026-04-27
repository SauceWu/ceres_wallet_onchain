import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';
import '../evm_address.dart';
import '../models/eth_sync_status.dart';

/// EVM RPC methods for querying node and chain state.
///
/// Provides methods for chain identification, block number, sync status,
/// node-managed accounts, and node-side signing.
mixin EvmStateMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the chain ID as a [BigInt].
  ///
  /// Calls `eth_chainId`. Common values: 1 (Mainnet), 5 (Goerli),
  /// 11155111 (Sepolia), 137 (Polygon), 42161 (Arbitrum).
  ///
  /// ```dart
  /// final chainId = await client.chainId();
  /// ```
  Future<BigInt> chainId() async {
    final result = await transport.send('eth_chainId');
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the current block number.
  ///
  /// Calls `eth_blockNumber`.
  ///
  /// ```dart
  /// final blockNum = await client.blockNumber();
  /// ```
  Future<BigInt> blockNumber() async {
    final result = await transport.send('eth_blockNumber');
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the node's sync status, or `null` if fully synced.
  ///
  /// Calls `eth_syncing`. The response is polymorphic:
  /// - Returns `false` (bool) when fully synced -> this method returns `null`
  /// - Returns a sync progress object when syncing -> returns [EthSyncStatus]
  ///
  /// ```dart
  /// final status = await client.syncing();
  /// if (status != null) {
  ///   print('Syncing: ${status.currentBlock} / ${status.highestBlock}');
  /// } else {
  ///   print('Fully synced');
  /// }
  /// ```
  Future<EthSyncStatus?> syncing() async {
    final result = await transport.send('eth_syncing');
    if (result is bool) return null;
    return EthSyncStatus.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the list of accounts managed by the node.
  ///
  /// Calls `eth_accounts`. Returns an empty list for public RPC providers
  /// that do not manage private keys.
  ///
  /// ```dart
  /// final accounts = await client.accounts();
  /// ```
  Future<List<EvmAddress>> accounts() async {
    final result = await transport.send('eth_accounts');
    return (result as List).map((e) => EvmAddress(e as String)).toList();
  }

  /// Signs data with a node-managed account.
  ///
  /// Calls `eth_sign` with [address] and [data] (hex-encoded message).
  /// Returns the signature as a hex string.
  ///
  /// **Note:** Requires the node to manage the private key for [address].
  /// Not supported by most public RPC providers.
  ///
  /// ```dart
  /// final sig = await client.sign(addr, '0xdeadbeef');
  /// ```
  Future<String> sign(EvmAddress address, String data) async {
    final result = await transport.send('eth_sign', [address.toString(), data]);
    return result as String;
  }

  /// Signs a transaction with a node-managed account without sending it.
  ///
  /// Calls `eth_signTransaction` with [txParams]. Returns the signed
  /// transaction as a hex string.
  ///
  /// **Note:** Requires the node to manage the sender's private key.
  /// Not supported by most public RPC providers.
  ///
  /// ```dart
  /// final signedTx = await client.signTransaction({
  ///   'from': '0xSender',
  ///   'to': '0xRecipient',
  ///   'value': '0x1',
  /// });
  /// ```
  Future<String> signTransaction(Map<String, dynamic> txParams) async {
    final result = await transport.send('eth_signTransaction', [txParams]);
    return result as String;
  }
}
