import '../../core/json_rpc_transport.dart';

/// EVM RPC methods for sending transactions.
///
/// Provides methods for submitting signed transactions and node-managed
/// transaction sending.
mixin EvmSendMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Submits a pre-signed transaction to the network.
  ///
  /// Calls `eth_sendRawTransaction` with the given [signedTxHex]
  /// (a hex-encoded signed transaction).
  ///
  /// Returns the 32-byte transaction hash as a hex string.
  ///
  /// ```dart
  /// final txHash = await client.sendRawTransaction('0xf86c...');
  /// ```
  Future<String> sendRawTransaction(String signedTxHex) async {
    final result = await transport.send('eth_sendRawTransaction', [
      signedTxHex,
    ]);
    return result as String;
  }

  /// Sends a transaction using a node-managed private key.
  ///
  /// Calls `eth_sendTransaction` with [txParams] (a map with keys like
  /// `from`, `to`, `value`, `data`, `gas`, `gasPrice`).
  ///
  /// Returns the 32-byte transaction hash as a hex string.
  ///
  /// **Note:** This method requires the node to manage the sender's private
  /// key. It is NOT supported by most public RPC providers (Infura, Alchemy,
  /// etc.). For production use, sign transactions locally and use
  /// [sendRawTransaction] instead.
  ///
  /// ```dart
  /// final txHash = await client.sendTransaction({
  ///   'from': '0xSenderAddress',
  ///   'to': '0xRecipientAddress',
  ///   'value': '0xDE0B6B3A7640000',
  /// });
  /// ```
  Future<String> sendTransaction(Map<String, dynamic> txParams) async {
    final result = await transport.send('eth_sendTransaction', [txParams]);
    return result as String;
  }
}
