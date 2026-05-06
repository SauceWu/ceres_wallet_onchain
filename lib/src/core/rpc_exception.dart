/// Unified exception model for all RPC operations.
///
/// All exceptions thrown by the SDK's transport layer extend [RpcException],
/// providing a consistent error handling interface across EVM, Tron, Solana,
/// and Sui chains.
library;

/// Base exception for all RPC operations.
///
/// Contains a numeric [code], a human-readable [message], and optional
/// [data] payload. All chain-specific RPC errors are represented through
/// this hierarchy.
///
/// ```dart
/// try {
///   await client.send('eth_blockNumber', []);
/// } on RpcException catch (e) {
///   print('RPC error ${e.code}: ${e.message}');
/// }
/// ```
class RpcException implements Exception {
  /// Numeric error code.
  ///
  /// For JSON-RPC errors, this follows the JSON-RPC 2.0 error code
  /// specification. For transport-level errors, SDK-defined codes are used.
  final int code;

  /// Human-readable error description.
  final String message;

  /// Optional additional error data from the RPC response.
  final dynamic data;

  /// Creates an [RpcException] with the given [code], [message], and
  /// optional [data].
  const RpcException({required this.code, required this.message, this.data});

  @override
  String toString() => 'RpcException($code): $message';
}

/// Exception thrown when an RPC request exceeds the configured timeout.
///
/// The [timeout] field records the duration that was exceeded.
/// Uses error code `-1` to distinguish from JSON-RPC standard error codes.
///
/// ```dart
/// try {
///   await client.send('eth_blockNumber', []);
/// } on RpcTimeoutException catch (e) {
///   print('Timed out after ${e.timeout.inSeconds}s');
/// }
/// ```
class RpcTimeoutException extends RpcException {
  /// The timeout duration that was exceeded.
  final Duration timeout;

  /// Creates an [RpcTimeoutException] for the given [timeout] duration.
  RpcTimeoutException({required this.timeout})
    : super(code: -1, message: 'Request timed out after ${timeout.inSeconds}s');
}

/// Exception thrown when the HTTP transport returns a non-2xx status code.
///
/// The [statusCode] field contains the HTTP response status code.
/// The [code] field is set to the same value as [statusCode] for consistency.
///
/// When the response includes a `Retry-After` header (RFC 7231 §7.1.3) in
/// `delta-seconds` format, [retryAfter] is populated with the parsed value
/// (capped at 30 seconds to guard against malicious servers stalling clients
/// indefinitely). HTTP-date format and malformed values yield a `null`
/// [retryAfter]; callers fall back to their default backoff strategy.
///
/// ```dart
/// try {
///   await client.send('eth_blockNumber', []);
/// } on RpcHttpException catch (e) {
///   print('HTTP ${e.statusCode}: ${e.message}');
///   if (e.retryAfter != null) {
///     print('Server asked us to wait ${e.retryAfter!.inSeconds}s');
///   }
/// }
/// ```
class RpcHttpException extends RpcException {
  /// The HTTP response status code (e.g., 503, 429, 404).
  final int statusCode;

  /// The server-supplied retry hint parsed from the `Retry-After` response
  /// header, or `null` when absent, malformed, or in HTTP-date format.
  ///
  /// Capped at 30 seconds by the transport to guard against malicious
  /// servers stalling clients indefinitely with a huge value.
  final Duration? retryAfter;

  /// Creates an [RpcHttpException] with the given [statusCode] and [message],
  /// optionally including a [retryAfter] hint from the response.
  const RpcHttpException({
    required this.statusCode,
    required super.message,
    this.retryAfter,
  }) : super(code: statusCode);
}

/// Exception thrown when the JSON-RPC response contains an `error` object.
///
/// This maps directly to the JSON-RPC 2.0 error response format:
/// ```json
/// {"jsonrpc": "2.0", "id": 1, "error": {"code": -32601, "message": "Method not found"}}
/// ```
///
/// The [code] and [message] fields come from the JSON-RPC error object,
/// and [data] contains any additional error data if present.
class RpcResponseException extends RpcException {
  /// Creates an [RpcResponseException] from a JSON-RPC error response.
  const RpcResponseException({
    required super.code,
    required super.message,
    super.data,
  });
}
