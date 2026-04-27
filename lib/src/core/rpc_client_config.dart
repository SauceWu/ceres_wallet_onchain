/// Configuration object for RPC transport clients.
///
/// Encapsulates all settings needed to create an RPC client instance,
/// including the endpoint URL, timeout, retry policy, logging, and
/// custom headers.
///
/// ```dart
/// final config = RpcClientConfig(
///   baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY',
///   timeout: Duration(seconds: 15),
///   maxRetries: 2,
///   logger: (entry) => print(entry.method),
/// );
/// ```
library;

import 'rpc_logger.dart';

/// Configuration for an RPC transport client.
///
/// Create an instance with at minimum a [baseUrl], then pass it to
/// a transport constructor (e.g., `JsonRpcTransport` or `RestTransport`).
class RpcClientConfig {
  /// The base URL of the RPC endpoint.
  ///
  /// For JSON-RPC endpoints this is the full URL (e.g.,
  /// `'https://mainnet.infura.io/v3/KEY'`).
  /// For REST endpoints (Tron), this is the base URL without path
  /// (e.g., `'https://api.trongrid.io'`).
  final String baseUrl;

  /// The timeout duration for each individual request.
  ///
  /// Defaults to 30 seconds. If a request does not complete within
  /// this duration, an [RpcTimeoutException] is thrown.
  final Duration timeout;

  /// Maximum number of retry attempts after a retryable failure.
  ///
  /// Defaults to `0` (no retries). Only network timeouts and HTTP 5xx
  /// errors trigger retries; 4xx and JSON-RPC business errors do not.
  final int maxRetries;

  /// Base delay for exponential backoff between retries.
  ///
  /// The actual delay for attempt `n` is `baseDelay * 2^n`, capped
  /// at 30 seconds. Defaults to 1 second.
  final Duration retryBaseDelay;

  /// Optional logging callback for request/response monitoring.
  ///
  /// When set, the transport calls this function with an [RpcLogEntry]
  /// for each outgoing request and incoming response.
  final RpcLogger? logger;

  /// Additional HTTP headers to include in every request.
  ///
  /// These are merged with the transport's default headers
  /// (`Content-Type: application/json`). Useful for API keys or
  /// custom authentication headers.
  final Map<String, String> extraHeaders;

  /// Creates an [RpcClientConfig] with the given settings.
  ///
  /// Only [baseUrl] is required; all other parameters have sensible
  /// defaults.
  const RpcClientConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 0,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.logger,
    this.extraHeaders = const {},
  });
}
