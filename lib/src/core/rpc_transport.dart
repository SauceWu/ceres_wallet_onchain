/// Abstract transport interface for all RPC operations.
///
/// All chain-specific RPC clients use a transport implementation
/// to send requests over the network. [JsonRpcTransport] provides
/// the JSON-RPC 2.0 implementation used by EVM, Solana, and Sui.
///
/// ```dart
/// final transport = JsonRpcTransport(config: config);
/// final result = await transport.send('eth_blockNumber', []);
/// transport.close();
/// ```
library;

/// Transport layer abstraction for sending RPC requests.
///
/// Implementations handle the wire protocol (JSON-RPC 2.0, REST, etc.),
/// timeout management, retry logic, and error mapping.
abstract class RpcTransport {
  /// Sends an RPC request and returns the parsed result.
  ///
  /// The [method] is the RPC method name (e.g., `'eth_blockNumber'`).
  /// The [params] are the method parameters, defaulting to an empty list.
  ///
  /// Throws [RpcTimeoutException] if the request exceeds the configured
  /// timeout, [RpcHttpException] for HTTP-level errors, and
  /// [RpcResponseException] for JSON-RPC error responses.
  Future<dynamic> send(String method, [List<dynamic> params = const []]);

  /// Closes the underlying HTTP connection.
  ///
  /// After calling [close], the transport should not be used for further
  /// requests. Only closes the HTTP client if it was internally created
  /// (not injected via constructor).
  void close();
}
