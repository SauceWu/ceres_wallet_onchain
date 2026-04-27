import '../../core/json_rpc_transport.dart';

/// Mixin providing Ethereum `web3_` namespace RPC methods.
///
/// These methods query Web3-level information and utilities from the
/// connected node.
///
/// Requires [transport] to be provided by the implementing class.
///
/// ```dart
/// class MyClient with EvmWeb3Methods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmWeb3Methods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the client version string of the connected node.
  ///
  /// Sends `web3_clientVersion`. The format varies by client implementation,
  /// for example:
  /// - `"Geth/v1.13.0-stable/linux-amd64/go1.21"` for Geth
  /// - `"Nethermind/v1.20.0/linux-x64/dotnet8.0"` for Nethermind
  Future<String> web3ClientVersion() async {
    final result = await transport.send('web3_clientVersion');
    return result as String;
  }

  /// Returns the Keccak-256 hash of the given [data] as computed by the node.
  ///
  /// Sends `web3_sha3` with [data] (a hex-encoded string, must be
  /// `0x`-prefixed) and returns the Keccak-256 hash as a hex string.
  ///
  /// Example:
  /// ```dart
  /// final hash = await client.web3Sha3('0x68656c6c6f');
  /// // Returns keccak256 of "hello"
  /// ```
  Future<String> web3Sha3(String data) async {
    final result = await transport.send('web3_sha3', [data]);
    return result as String;
  }
}
