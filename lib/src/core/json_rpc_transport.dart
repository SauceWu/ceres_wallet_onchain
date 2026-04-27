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
/// - **Retry:** Automatically retries on timeout and 5xx errors up to
///   [RpcClientConfig.maxRetries] times with exponential backoff.
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
      );
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Executes [action] with retry logic for transient failures.
  ///
  /// Retries on [RpcTimeoutException] and [RpcHttpException] with
  /// status code >= 500, up to [RpcClientConfig.maxRetries] times.
  /// Uses exponential backoff capped at 30 seconds.
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
        if (e.statusCode < 500 || attempt >= _config.maxRetries) rethrow;
        await _backoff(attempt);
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
