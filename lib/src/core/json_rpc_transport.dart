/// JSON-RPC 2.0 transport implementation over HTTP.
///
/// Provides the standard transport for EVM, Solana, and Sui chains,
/// handling JSON-RPC envelope construction, response parsing, timeout
/// management, retry with exponential backoff, and logging.
///
/// ```dart
/// final transport = JsonRpcTransport(
///   config: RpcClientConfig(
///     baseUrl: 'https://mainnet.infura.io/v3/KEY',
///     timeout: Duration(seconds: 15),
///     maxRetries: 2,
///   ),
/// );
///
/// final blockNumber = await transport.send('eth_blockNumber', []);
/// transport.close();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'rpc_client_config.dart';
import 'rpc_exception.dart';
import 'rpc_logger.dart';
import 'rpc_transport.dart';

/// JSON-RPC 2.0 transport over HTTP POST.
///
/// Sends JSON-RPC requests to the configured [RpcClientConfig.baseUrl]
/// and parses the response `result` field. Handles:
///
/// - **Timeout:** Throws [RpcTimeoutException] when a request exceeds
///   [RpcClientConfig.timeout].
/// - **HTTP errors:** Throws [RpcHttpException] for non-2xx status codes.
/// - **JSON-RPC errors:** Throws [RpcResponseException] when the response
///   contains an `error` object.
/// - **Retry:** Automatically retries on timeout, 5xx errors, and HTTP 429
///   (rate-limited) up to [RpcClientConfig.maxRetries] times with
///   exponential backoff. When a `Retry-After` response header is present
///   (delta-seconds, capped at 30 seconds), it is honored in place of the
///   exponential delay.
/// - **Logging:** Calls [RpcClientConfig.logger] with request/response
///   entries when configured.
class JsonRpcTransport implements RpcTransport {
  final RpcClientConfig _config;
  final http.Client _client;
  final bool _ownsClient;
  int _nextId = 1;

  /// Creates a [JsonRpcTransport] with the given [config].
  ///
  /// If [httpClient] is provided, it will be used for all requests and
  /// will NOT be closed when [close] is called. If omitted, an internal
  /// [http.Client] is created and will be closed on [close].
  JsonRpcTransport({required RpcClientConfig config, http.Client? httpClient})
    : _config = config,
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  @override
  Future<dynamic> send(String method, [List<dynamic> params = const []]) async {
    final id = _nextId++;
    final body = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    // Log request
    _config.logger?.call(
      RpcLogEntry(
        direction: RpcLogDirection.request,
        method: method,
        params: params,
      ),
    );

    final stopwatch = Stopwatch()..start();
    Object? error;
    dynamic result;

    try {
      final response = await _withRetry(() => _doPost(body));
      stopwatch.stop();

      // Check for JSON-RPC error response
      if (response.containsKey('error') && response['error'] != null) {
        final err = response['error'] as Map<String, dynamic>;
        final rpcError = RpcResponseException(
          code: err['code'] as int,
          message: err['message'] as String,
          data: err['data'],
        );
        error = rpcError;
        throw rpcError;
      }

      result = response['result'];
      return result;
    } catch (e) {
      stopwatch.stop();
      error ??= e;
      rethrow;
    } finally {
      // Log response
      _config.logger?.call(
        RpcLogEntry(
          direction: RpcLogDirection.response,
          method: method,
          result: result,
          error: error,
          duration: stopwatch.elapsed,
        ),
      );
    }
  }

  /// Performs an HTTP POST and returns the parsed JSON response.
  Future<Map<String, dynamic>> _doPost(Map<String, dynamic> body) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._config.extraHeaders,
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_config.baseUrl),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_config.timeout);
    } on TimeoutException {
      throw RpcTimeoutException(timeout: _config.timeout);
    }

    if (response.statusCode >= 400) {
      throw RpcHttpException(
        statusCode: response.statusCode,
        message: utf8.decode(response.bodyBytes),
        retryAfter: _parseRetryAfter(response.headers),
      );
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Parses the `Retry-After` header (RFC 7231 §7.1.3) from [headers].
  ///
  /// Returns `null` when the header is absent, negative, malformed, or in
  /// HTTP-date format (only `delta-seconds` is honored).
  ///
  /// The result is capped at 30 seconds to guard against malicious or
  /// misconfigured servers supplying a huge value that would stall the
  /// client indefinitely.
  Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    final capped = seconds > 30 ? 30 : seconds;
    return Duration(seconds: capped);
  }

  /// Executes [action] with retry logic for transient failures.
  ///
  /// Retries on [RpcTimeoutException] and [RpcHttpException] with
  /// status code >= 500 OR exactly 429 (rate-limited), up to
  /// [RpcClientConfig.maxRetries] times. When the offending response carried
  /// a `Retry-After` header, the parsed delay (capped at 30s) is used in
  /// place of exponential backoff.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } on RpcTimeoutException {
        if (attempt >= _config.maxRetries) rethrow;
        await _backoff(attempt);
        attempt++;
      } on RpcHttpException catch (e) {
        final retryable = e.statusCode >= 500 || e.statusCode == 429;
        if (!retryable || attempt >= _config.maxRetries) rethrow;
        if (e.retryAfter != null) {
          await Future.delayed(e.retryAfter!);
        } else {
          await _backoff(attempt);
        }
        attempt++;
      }
    }
  }

  /// Waits for exponential backoff delay.
  Future<void> _backoff(int attempt) async {
    final delayMs = min(
      _config.retryBaseDelay.inMilliseconds * (1 << attempt),
      30000,
    );
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
