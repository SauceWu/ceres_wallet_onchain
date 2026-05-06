/// Internal helper: GET against an [EndpointPool] with query/headers
/// and JSON parsing. Reused by [EvmBlockscoutProvider],
/// [EvmEtherscanProvider] (plan 11-06), and [TronGridProvider] (plan
/// 11-07) — every REST history provider shares the same multi-endpoint
/// failover, https-only validation, captive-portal guard, 429 → Retry-After
/// mapping, and api-key-redacted error reporting.
///
/// Currently NOT exported from `lib/tx_history.dart` — plan 11-08 will
/// decide whether to expose it under an `advanced` namespace for adopters
/// who want to build their own REST providers on the same primitives.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/rpc_exception.dart';
import '../endpoint_pool.dart';
import '../tx_history_exception.dart';

/// Thin GET helper around an [EndpointPool] with header support, https-only
/// validation, and JSON parsing.
///
/// Composition contract:
///
/// - [pool] picks the next non-banned base URL on every [get] call.
/// - The [http.Client] passed via `httpClient` is owned by the caller and
///   will NOT be closed by [close]; an internally created client IS closed.
/// - [defaultHeaders] are merged with per-call `headers`; per-call wins on
///   conflict.
/// - Every base URL in the pool MUST start with `https://` unless
///   [allowInsecure] is `true` (local dev convenience for `http://localhost`).
///
/// Error mapping (each thrown exception flows back into [EndpointPool] which
/// decides whether to walk to the next endpoint or rethrow):
///
/// | Upstream                                 | Thrown                     |
/// |------------------------------------------|----------------------------|
/// | `TimeoutException` from `http.get(...)`  | [RpcTimeoutException]      |
/// | HTTP 429 (with optional `Retry-After`)   | [RateLimitedException]     |
/// | HTTP 4xx (non-429) / 5xx                 | [RpcHttpException]         |
/// | 200 OK with non-JSON `Content-Type`      | [TxHistoryApiException]    |
/// | 200 OK body that fails `jsonDecode`      | [TxHistoryApiException]    |
class RestHistoryClient {
  /// The pool that supplies the next base URL on each [get] call.
  final EndpointPool pool;

  /// Per-request timeout applied to every endpoint attempt independently.
  final Duration timeout;

  /// Headers merged into every request. Per-call `headers` override these
  /// on key conflict.
  final Map<String, String> defaultHeaders;

  /// When `true`, the constructor accepts non-https base URLs. Intended
  /// only for local dev (`http://localhost`); production callers must
  /// leave this `false` so the SSRF guard fires on misconfiguration
  /// (T-11-15 mitigation).
  final bool allowInsecure;

  final http.Client _http;
  final bool _ownsHttp;

  /// Idempotency guard so repeated [close] calls cannot drive the
  /// underlying [http.Client] through `close()` twice (HIST-OPS-03 —
  /// the contract requires `close()` to be safe to call repeatedly).
  bool _closed = false;

  /// Creates a [RestHistoryClient].
  ///
  /// Throws [ArgumentError] if [allowInsecure] is `false` and any base URL
  /// in [pool] does not start with `https://`.
  RestHistoryClient({
    required this.pool,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.defaultHeaders = const {},
    this.allowInsecure = false,
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null {
    if (!allowInsecure) {
      for (final url in pool.baseUrls) {
        if (!url.startsWith('https://')) {
          throw ArgumentError.value(
            url,
            'baseUrls',
            'must start with https:// '
                '(use allowInsecure: true for local dev)',
          );
        }
      }
    }
  }

  /// Performs `GET {baseUrl}{path}?{query}` against the next pool endpoint
  /// and returns the parsed JSON body (a [Map] or [List]).
  ///
  /// [query] entries are percent-encoded by [Uri]. [headers] are merged
  /// with [defaultHeaders] (per-call wins).
  Future<dynamic> get({
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = <String, String>{
      ...defaultHeaders,
      if (headers != null) ...headers,
    };
    return pool.execute<dynamic>((baseUrl) async {
      final base = Uri.parse(baseUrl);
      final uri = base.replace(
        path: _joinPath(base.path, path),
        queryParameters: query == null || query.isEmpty ? null : query,
      );
      final http.Response response;
      try {
        response = await _http
            .get(uri, headers: mergedHeaders)
            .timeout(timeout);
      } on TimeoutException {
        throw RpcTimeoutException(timeout: timeout);
      }

      if (response.statusCode == 429) {
        throw RateLimitedException(
          message: 'rate limited by $baseUrl',
          rateLimit: _parseRateLimit(response.headers),
        );
      }
      if (response.statusCode >= 400) {
        throw RpcHttpException(
          statusCode: response.statusCode,
          message: utf8.decode(response.bodyBytes),
        );
      }

      final ct = response.headers['content-type'] ?? '';
      if (ct.isNotEmpty && !ct.contains('json')) {
        throw TxHistoryApiException(
          code: -2002,
          message: 'unexpected content-type from $baseUrl: $ct',
          endpoint: baseUrl,
        );
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (e) {
        throw TxHistoryApiException(
          code: -2002,
          message: 'malformed JSON from $baseUrl: ${e.message}',
          endpoint: baseUrl,
        );
      }
    });
  }

  /// Closes the owned [http.Client]. No-op if the client was injected by
  /// the caller (the caller owns the lifecycle in that case).
  ///
  /// Idempotent (HIST-OPS-03 contract): calling [close] more than once
  /// does NOT throw and the second call is a no-op.
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsHttp) _http.close();
  }

  static String _joinPath(String base, String path) {
    final left = base.endsWith('/') && base.isNotEmpty
        ? base.substring(0, base.length - 1)
        : base;
    final right = path.startsWith('/') ? path : '/$path';
    return '$left$right';
  }

  static RateLimitInfo? _parseRateLimit(Map<String, String> headers) {
    final raw = headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    final capped = seconds > 30 ? 30 : seconds;
    return RateLimitInfo(retryAfter: Duration(seconds: capped));
  }
}
