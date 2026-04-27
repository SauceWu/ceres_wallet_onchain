import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';
import '../evm_address.dart';

/// EVM RPC methods for mining and protocol information.
///
/// Provides methods for querying the node's protocol version, coinbase
/// address, mining status, and hashrate.
mixin EvmMiningMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the current Ethereum protocol version.
  ///
  /// Calls `eth_protocolVersion`.
  ///
  /// ```dart
  /// final version = await client.protocolVersion();
  /// ```
  Future<String> protocolVersion() async {
    final result = await transport.send('eth_protocolVersion');
    return result as String;
  }

  /// Returns the coinbase address (the address receiving mining rewards).
  ///
  /// Calls `eth_coinbase`. Returns an [EvmAddress].
  ///
  /// ```dart
  /// final coinbase = await client.coinbase();
  /// ```
  Future<EvmAddress> coinbase() async {
    final result = await transport.send('eth_coinbase');
    return EvmAddress(result as String);
  }

  /// Returns whether the node is actively mining.
  ///
  /// Calls `eth_mining`.
  ///
  /// ```dart
  /// final isMining = await client.mining();
  /// ```
  Future<bool> mining() async {
    final result = await transport.send('eth_mining');
    return result as bool;
  }

  /// Returns the current hashrate of the node.
  ///
  /// Calls `eth_hashrate`. Returns `BigInt.zero` for PoS nodes.
  ///
  /// ```dart
  /// final hashrate = await client.hashrate();
  /// ```
  Future<BigInt> hashrate() async {
    final result = await transport.send('eth_hashrate');
    return BigIntUtils.hexToBigInt(result as String);
  }
}
