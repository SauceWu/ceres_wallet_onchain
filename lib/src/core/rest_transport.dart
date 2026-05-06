/// REST HTTP transport implementation for non-JSON-RPC endpoints.
///
/// Provides the transport layer for Tron's HTTP API, which uses standard
/// REST POST requests instead of JSON-RPC 2.0 envelopes. Handles timeout
/// management, retry with exponential backoff, and logging.
///
/// ```dart
/// final transport = RestTransport(
///   config: RpcClientConfig(
///     baseUrl: 'https://api.trongrid.io',
///     timeout: Duration(seconds: 15),
///     extraHeaders: {'TRON-PRO-API-KEY': 'your-key'},
///   ),
/// );
///
/// final account = await transport.post(
///   '/wallet/getaccount',
///   {'address': 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb'},
/// );
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

/// REST HTTP transport for standard POST JSON endpoints.
///
/// Unlike [JsonRpcTransport], this does not wrap requests in a JSON-RPC
/// envelope. Instead, it sends plain JSON POST requests and returns the
/// parsed response body directly.
///
/// Used primarily for Tron's HTTP API endpoints (e.g.,
/// `/wallet/getaccount`, `/wallet/triggersmartcontract`).
///
/// Handles:
///
/// - **Timeout:** Throws [RpcTimeoutException] when a request exceeds
///   [RpcClientConfig.timeout].
/// - **HTTP errors:** Throws [RpcHttpException] for non-2xx status codes.
/// - **Retry:** Automatically retries on timeout, 5xx errors, and HTTP 429
///   (rate-limited) up to [RpcClientConfig.maxRetries] times with
///   exponential backoff. When a `Retry-After` response header is present
///   (delta-seconds, capped at 30 seconds), it is honored in place of the
///   exponential delay.
/// - **Logging:** Calls [RpcClientConfig.logger] with request/response
///   entries when configured.
class RestTransport {
  final RpcClientConfig _config;
  final http.Client _client;
  final bool _ownsClient;

  /// Creates a [RestTransport] with the given [config].
  ///
  /// If [httpClient] is provided, it will be used for all requests and
  /// will NOT be closed when [close] is called. If omitted, an internal
  /// [http.Client] is created and will be closed on [close].
  RestTransport({required RpcClientConfig config, http.Client? httpClient})
    : _config = config,
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  /// Sends a GET request to [path] and returns the parsed JSON object.
  ///
  /// The full URL is constructed as `${config.baseUrl}${path}`.
  /// Returns the parsed JSON response as a [Map].
  ///
  /// Throws [RpcTimeoutException] on timeout, [RpcHttpException] for
  /// HTTP 4xx/5xx responses.
  Future<Map<String, dynamic>> get(String path) async {
    return await _getRaw(path) as Map<String, dynamic>;
  }

  /// Sends a GET request to [path] and returns the parsed JSON array.
  ///
  /// Some endpoints (e.g., `/wallet/listnodes`) return a JSON array
  /// instead of an object. Use this method for those endpoints.
  ///
  /// Throws [RpcTimeoutException] on timeout, [RpcHttpException] for
  /// HTTP 4xx/5xx responses.
  Future<List<dynamic>> getList(String path) async {
    return await _getRaw(path) as List<dynamic>;
  }

  /// Internal GET implementation that returns the raw parsed JSON.
  ///
  /// The result may be a [Map] or [List] depending on the endpoint.
  Future<dynamic> _getRaw(String path) async {
    final url = '${_config.baseUrl}$path';

    // Log request
    _config.logger?.call(
      RpcLogEntry(direction: RpcLogDirection.request, method: path),
    );

    final stopwatch = Stopwatch()..start();
    Object? error;
    dynamic result;

    try {
      result = await _withRetry(() => _doGet(url));
      return result;
    } on Object catch (e) {
      error = e;
      rethrow;
    } finally {
      stopwatch.stop();
      // Log response
      _config.logger?.call(
        RpcLogEntry(
          direction: RpcLogDirection.response,
          method: path,
          result: result,
          error: error,
          duration: stopwatch.elapsed,
        ),
      );
    }
  }

  /// Sends a POST request to [path] with optional JSON [body].
  ///
  /// The full URL is constructed as `${config.baseUrl}${path}`.
  /// Returns the parsed JSON response as a [Map].
  ///
  /// Throws [RpcTimeoutException] on timeout, [RpcHttpException] for
  /// HTTP 4xx/5xx responses.
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    final url = '${_config.baseUrl}$path';

    // Log request
    _config.logger?.call(
      RpcLogEntry(
        direction: RpcLogDirection.request,
        method: path,
        params: body,
      ),
    );

    final stopwatch = Stopwatch()..start();
    Object? error;
    Map<String, dynamic>? result;

    try {
      result = await _withRetry(() => _doPost(url, body));
      return result!;
    } on Object catch (e) {
      error = e;
      rethrow;
    } finally {
      stopwatch.stop();
      // Log response
      _config.logger?.call(
        RpcLogEntry(
          direction: RpcLogDirection.response,
          method: path,
          result: result,
          error: error,
          duration: stopwatch.elapsed,
        ),
      );
    }
  }

  /// Performs an HTTP POST and returns the parsed JSON response.
  Future<Map<String, dynamic>> _doPost(
    String url,
    Map<String, dynamic> body,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._config.extraHeaders,
    };

    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
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

  /// Performs an HTTP GET and returns the parsed JSON response.
  ///
  /// The response may be a [Map] or [List] depending on the endpoint.
  Future<dynamic> _doGet(String url) async {
    final headers = <String, String>{..._config.extraHeaders};

    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(url), headers: headers)
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

    return jsonDecode(utf8.decode(response.bodyBytes));
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

  /// Closes the underlying HTTP client.
  ///
  /// Only closes the client if it was internally created (not injected
  /// via constructor).
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
