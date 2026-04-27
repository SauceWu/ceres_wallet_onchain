import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';

/// Mixin providing Ethereum `net_` namespace RPC methods.
///
/// These methods query network-level information about the connected node.
///
/// Requires [transport] to be provided by the implementing class.
///
/// ```dart
/// class MyClient with EvmNetMethods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmNetMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the current network ID as a decimal string.
  ///
  /// Sends `net_version`. Common return values:
  /// - `"1"` for Ethereum mainnet
  /// - `"5"` for Goerli testnet
  /// - `"11155111"` for Sepolia testnet
  ///
  /// Note: This is the network ID, not the chain ID (though they are often
  /// the same for Ethereum networks).
  Future<String> netVersion() async {
    final result = await transport.send('net_version');
    return result as String;
  }

  /// Returns whether the node is actively listening for network connections.
  ///
  /// Sends `net_listening` and returns `true` if the node is listening.
  Future<bool> netListening() async {
    final result = await transport.send('net_listening');
    return result as bool;
  }

  /// Returns the number of peers currently connected to the node.
  ///
  /// Sends `net_peerCount` and decodes the hex quantity response
  /// to a [BigInt].
  Future<BigInt> netPeerCount() async {
    final result = await transport.send('net_peerCount');
    return BigIntUtils.hexToBigInt(result as String);
  }
}
