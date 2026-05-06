/// Multi-endpoint round-robin failover with circuit-break and Retry-After
/// honoring.
///
/// Used by REST history providers (Blockscout / Etherscan / TronGrid) to
/// transparently fall over from a slow / 5xx / 429 endpoint to the next
/// configured base URL without infinite retries (T-11-02).
library;

import '../core/rpc_exception.dart';
import 'tx_history_exception.dart';

/// Optional metadata describing a 429 response so [EndpointPool] can
/// honor the upstream `Retry-After` directive.
///
/// Providers populate [retryAfter] when surfacing rate-limit failures.
class RateLimitInfo {
  /// How long the upstream asked us to wait before retrying.
  final Duration retryAfter;

  /// Creates a [RateLimitInfo] with the given [retryAfter] duration.
  const RateLimitInfo({required this.retryAfter});
}

/// 429-class HTTP exception carrying [RateLimitInfo].
///
/// Providers throw this when they parse a 429 response from a REST
/// endpoint. [EndpointPool] catches it specifically so it can honor
/// `Retry-After` instead of using the default circuit-break window.
///
/// Lives next to [EndpointPool] (NOT in `tx_history_exception.dart`)
/// because it extends [RpcHttpException] from the v1.0 transport layer
/// rather than [TxHistoryException].
class RateLimitedException extends RpcHttpException {
  /// Optional rate-limit hint extracted from the upstream response.
  final RateLimitInfo? rateLimit;

  /// Creates a [RateLimitedException].
  ///
  /// [statusCode] defaults to 429 — providers can override only if the
  /// upstream uses a non-standard rate-limit code.
  const RateLimitedException({
    required super.message,
    this.rateLimit,
    super.statusCode = 429,
  });
}

/// Round-robin failover across N base URLs with circuit-break.
///
/// Walks endpoints on transient failures (timeout / 5xx / 429), bans
/// failing endpoints for [circuitBreakDuration] (or the upstream
/// `Retry-After` if it's larger), and fails fast on caller errors
/// (4xx other than 429, non-`RpcException` throws).
///
/// Use one instance per provider/chain. NOT thread-safe across
/// isolates — instantiate per isolate if needed.
///
/// ```dart
/// final pool = EndpointPool(baseUrls: [
///   'https://eth.blockscout.com',
///   'https://blockscout.com/eth/mainnet',
/// ]);
/// final json = await pool.execute<Map<String, dynamic>>(
///   (baseUrl) => doHttpGet('$baseUrl/api/v2/addresses/0x.../transactions'),
/// );
/// ```
class EndpointPool {
  /// Endpoints in priority order — the cursor walks them round-robin.
  final List<String> baseUrls;

  /// How long a failing endpoint stays banned after a transient error.
  /// Honored as a floor when `Retry-After` is shorter; the larger of the
  /// two wins.
  final Duration circuitBreakDuration;

  /// Hard upper bound on attempts per [execute] call. Prevents infinite
  /// retry loops on misconfigured clocks (T-11-02). Defaults to
  /// `baseUrls.length`.
  final int maxAttempts;

  final DateTime Function() _now;
  final Map<String, DateTime> _bannedUntil = {};
  int _cursor = 0;

  /// Creates an [EndpointPool] over [baseUrls].
  ///
  /// Throws [ArgumentError] if [baseUrls] is empty. [now] is injectable
  /// for tests so ban expiry can be exercised without `Future.delayed`.
  EndpointPool({
    required this.baseUrls,
    this.circuitBreakDuration = const Duration(seconds: 30),
    int? maxAttempts,
    DateTime Function()? now,
  }) : maxAttempts = maxAttempts ?? baseUrls.length,
       _now = now ?? DateTime.now {
    if (baseUrls.isEmpty) {
      throw ArgumentError.value(baseUrls, 'baseUrls', 'must be non-empty');
    }
  }

  /// Runs [action] against the next available endpoint, walking to the
  /// next on transient failure.
  ///
  /// [action] receives the chosen `baseUrl` and returns the provider's
  /// parsed response. Behavior on throw:
  ///
  /// | Thrown                        | Pool reaction                          |
  /// |-------------------------------|----------------------------------------|
  /// | [RateLimitedException]        | ban for `max(retryAfter, circuitBreak)`|
  /// | [RpcHttpException] 5xx        | ban for `circuitBreakDuration`         |
  /// | [RpcHttpException] 429        | ban for `circuitBreakDuration`         |
  /// | [RpcHttpException] other 4xx  | rethrow immediately (caller error)     |
  /// | [RpcTimeoutException]         | ban for `circuitBreakDuration`         |
  /// | anything else                 | rethrow immediately (caller bug)       |
  ///
  /// When all endpoints are banned or [maxAttempts] is reached, throws
  /// [TxHistoryApiException] with code `-2002` and a message containing
  /// `all endpoints exhausted`.
  Future<T> execute<T>(Future<T> Function(String baseUrl) action) async {
    Object? lastError;
    var attempts = 0;
    while (attempts < maxAttempts) {
      final endpoint = _next();
      if (endpoint == null) break;
      attempts++;
      try {
        return await action(endpoint);
      } on RateLimitedException catch (e) {
        lastError = e;
        final hint = e.rateLimit?.retryAfter ?? circuitBreakDuration;
        final ban = hint > circuitBreakDuration ? hint : circuitBreakDuration;
        _bannedUntil[endpoint] = _now().add(ban);
        continue;
      } on RpcHttpException catch (e) {
        lastError = e;
        if (e.statusCode >= 500 || e.statusCode == 429) {
          _bannedUntil[endpoint] = _now().add(circuitBreakDuration);
          continue;
        }
        rethrow;
      } on RpcTimeoutException catch (e) {
        lastError = e;
        _bannedUntil[endpoint] = _now().add(circuitBreakDuration);
        continue;
      }
    }
    throw TxHistoryApiException(
      code: -2002,
      message:
          'EndpointPool: all endpoints exhausted '
          '(attempts: $attempts, baseUrls: ${baseUrls.length}). '
          'Last error: $lastError',
    );
  }

  /// Returns the next non-banned endpoint, or `null` if every endpoint
  /// is currently banned. Rotates the internal cursor forward on each
  /// successful pick so consecutive [execute] calls fan out across
  /// the pool.
  String? _next() {
    final now = _now();
    for (var i = 0; i < baseUrls.length; i++) {
      final candidate = baseUrls[(_cursor + i) % baseUrls.length];
      final ban = _bannedUntil[candidate];
      if (ban == null || ban.isBefore(now)) {
        _cursor = (_cursor + i + 1) % baseUrls.length;
        return candidate;
      }
    }
    return null;
  }
}
