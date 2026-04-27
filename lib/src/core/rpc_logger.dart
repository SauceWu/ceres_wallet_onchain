/// Logging callback types for RPC request/response monitoring.
///
/// The SDK uses a simple callback-based logging approach rather than
/// a chain-of-interceptors pattern. Users provide an [RpcLogger] callback
/// that receives [RpcLogEntry] instances for each request and response.
///
/// ```dart
/// final config = RpcClientConfig(
///   baseUrl: 'https://rpc.example.com',
///   logger: (entry) {
///     print('${entry.direction.name}: ${entry.method}');
///   },
/// );
/// ```
library;

/// Callback type for receiving RPC log entries.
///
/// Provide a function matching this signature to [RpcClientConfig.logger]
/// to receive notifications for all RPC requests and responses.
typedef RpcLogger = void Function(RpcLogEntry entry);

/// Direction of an RPC log entry.
enum RpcLogDirection {
  /// Log entry for an outgoing request.
  request,

  /// Log entry for an incoming response.
  response,
}

/// A single log entry capturing an RPC request or response.
///
/// Each RPC call generates two log entries: one with
/// [RpcLogDirection.request] before sending, and one with
/// [RpcLogDirection.response] after receiving the result (or error).
class RpcLogEntry {
  /// Whether this entry represents a request or response.
  final RpcLogDirection direction;

  /// The RPC method name (e.g., `'eth_blockNumber'`).
  final String method;

  /// The request parameters (for request entries) or `null`.
  final dynamic params;

  /// The response result (for successful response entries) or `null`.
  final dynamic result;

  /// The error object (for failed response entries) or `null`.
  final Object? error;

  /// The round-trip duration (for response entries) or `null`.
  final Duration? duration;

  /// The timestamp when this log entry was created.
  final DateTime timestamp;

  /// Creates an [RpcLogEntry].
  ///
  /// If [timestamp] is not provided, [DateTime.now] is used.
  RpcLogEntry({
    required this.direction,
    required this.method,
    this.params,
    this.result,
    this.error,
    this.duration,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
