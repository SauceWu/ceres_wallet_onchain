import '../../core/json_rpc_transport.dart';

/// EVM RPC methods for contract calls.
///
/// Provides `eth_call` for executing read-only contract interactions
/// without creating a transaction on the blockchain.
mixin EvmCallMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Executes a read-only call against a contract without creating a transaction.
  ///
  /// Calls `eth_call` with the given [callObject] (a map with keys like
  /// `from`, `to`, `data`, `value`, `gas`) at the specified [blockTag].
  ///
  /// Returns the hex-encoded return data from the contract execution.
  ///
  /// ```dart
  /// final result = await client.call({
  ///   'to': '0xContractAddress',
  ///   'data': '0x70a08231...',  // balanceOf(address)
  /// });
  /// ```
  Future<String> call(
    Map<String, dynamic> callObject, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_call', [callObject, blockTag]);
    return result as String;
  }
}
