/// Solana implementation of [TxHistoryProvider].
///
/// Composes the v1.0 [SolanaRpcClient] (LD-6 — composition over
/// inheritance) and exposes the two-step composite history pattern:
///
/// 1. `getSignaturesForAddress(address, before: cursor, limit: limit)`
/// 2. For each signature: `getTransaction(sig, encoding, ...)` —
///    concurrency-capped via [ConcurrencyLimiter] (default 4) so the
///    fan-out does not 429-storm the public mainnet RPC
///    (PITFALLS.md O-01).
///
/// Defaults (overridable via constructor):
///   - encoding `base64` (raw fidelity, PITFALLS.md C-03);
///     `useJsonParsed: true` opts into `jsonParsed`.
///   - `maxSupportedTransactionVersion: 0` always set
///     (Solana Pitfall 2 / C-03).
///   - commitment `finalized` (reorg-safe, PITFALLS.md C-04).
///   - concurrency `4` — safe for unkeyed Solana mainnet RPC.
///
/// Lifecycle (HIST-OPS-03 ownership flag):
///   - [SolanaNativeProvider.new] — caller injects an existing
///     [SolanaRpcClient]. Caller owns it; [close] is a no-op for the rpc.
///   - [SolanaNativeProvider.fromUrl] — provider builds the rpc itself
///     and owns it; [close] disposes the underlying transport.
library;

import '../../core/json_rpc_transport.dart';
import '../../core/rpc_client_config.dart';
import '../../core/rpc_exception.dart';
import '../../solana/solana_commitment.dart';
import '../../solana/solana_rpc_client.dart';
import '../tx_history_cursor.dart';
import '../tx_history_exception.dart';
import '../tx_history_page.dart';
import '../tx_history_provider.dart';
import '../tx_history_query.dart';
import 'concurrency_limiter.dart';
import 'solana_history_models.dart';

/// Solana history provider — composes [SolanaRpcClient].
class SolanaNativeProvider
    implements TxHistoryProvider<SolanaHistoryTransaction> {
  /// Wrapped Solana RPC client (composition target).
  final SolanaRpcClient _rpc;

  /// Whether the provider built (and therefore owns) [_rpc] itself.
  final bool _ownsRpc;

  /// When `true`, requests `encoding=jsonParsed`; otherwise `encoding=base64`.
  ///
  /// Default `false` because base64 round-trips the raw transaction bytes
  /// without Solana's program-aware parser dropping fields it does not
  /// understand (PITFALLS.md C-03).
  final bool useJsonParsed;

  /// Maximum number of in-flight `getTransaction` calls.
  ///
  /// Default `4` — empirically safe for unkeyed Solana mainnet RPC.
  /// Raise it for paid tiers, lower it (e.g. `2`) for dense paging
  /// loops on flaky networks.
  final int concurrency;

  /// Commitment level requested on every RPC call.
  ///
  /// Default [SolanaCommitment.finalized] — reorg-safe history
  /// (PITFALLS.md C-04). Override for read-your-write style flows.
  final SolanaCommitment defaultCommitment;

  final ConcurrencyLimiter _limiter;

  /// Idempotency guard so repeated [close] calls cannot disturb the
  /// underlying transport twice (HIST-OPS-03 — close() must be safe to
  /// call repeatedly even when the provider owns the rpc client).
  bool _closed = false;

  /// Creates a [SolanaNativeProvider] that wraps an externally-owned
  /// [rpcClient]. The caller retains ownership; [close] does NOT
  /// dispose [rpcClient].
  SolanaNativeProvider({
    required SolanaRpcClient rpcClient,
    this.useJsonParsed = false,
    this.concurrency = 4,
    this.defaultCommitment = SolanaCommitment.finalized,
  }) : _rpc = rpcClient,
       _ownsRpc = false,
       _limiter = ConcurrencyLimiter(max: concurrency);

  /// Creates a [SolanaNativeProvider] backed by a freshly-constructed
  /// [SolanaRpcClient] pointed at [baseUrl].
  ///
  /// The provider owns the underlying transport; [close] disposes it.
  ///
  /// [baseUrl] MUST start with `https://` unless [allowInsecure] is
  /// `true` — same SSRF / MITM guard the REST providers enforce via
  /// `RestHistoryClient` (T-11-15). Use `allowInsecure: true` only for
  /// local dev (e.g. `http://localhost:8899`).
  SolanaNativeProvider.fromUrl(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 15),
    this.useJsonParsed = false,
    this.concurrency = 4,
    this.defaultCommitment = SolanaCommitment.finalized,
    bool allowInsecure = false,
  }) : _rpc = SolanaRpcClient(
         transport: JsonRpcTransport(
           config: RpcClientConfig(
             baseUrl: _validateBaseUrl(baseUrl, allowInsecure),
             timeout: timeout,
           ),
         ),
       ),
       _ownsRpc = true,
       _limiter = ConcurrencyLimiter(max: concurrency);

  /// Enforces the same HTTPS-only SSRF / MITM guard as [RestHistoryClient]
  /// (T-11-15). Returns [baseUrl] unchanged on success so this can run
  /// inside the initializer list before the [SolanaRpcClient] is built.
  static String _validateBaseUrl(String baseUrl, bool allowInsecure) {
    if (!allowInsecure && !baseUrl.startsWith('https://')) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must start with https:// '
            '(use allowInsecure: true for local dev)',
      );
    }
    return baseUrl;
  }

  /// Fetches one page of Solana history.
  ///
  /// **Mobile UI thread guidance (HIST-OPS-04):** the returned
  /// [SolanaHistoryTransaction] list contains raw `getTransaction`
  /// JSON maps that can be tens of KB each — large pages parsed on
  /// the UI isolate may cause jank. If you observe frame drops,
  /// invoke this provider inside `Isolate.run`:
  ///
  /// ```dart
  /// final page = await Isolate.run(() => provider.listTransactions(query));
  /// ```
  ///
  /// Note: `Isolate.run` requires the provider's transports to be
  /// constructible inside the isolate, so prefer the
  /// [SolanaNativeProvider.fromUrl] pattern when crossing isolate
  /// boundaries.
  @override
  Future<TxHistoryPage<SolanaHistoryTransaction>> listTransactions(
    TxHistoryQuery query,
  ) async {
    final cursor = query.cursor;
    String? before;
    if (cursor != null) {
      if (cursor is! SolanaCursor) {
        throw InvalidCursorException(
          message:
              'expected SolanaCursor for SolanaNativeProvider; got '
              '${cursor.runtimeType}',
        );
      }
      before = cursor.beforeSignature;
    }

    final signatures = await _rpc.getSignaturesForAddress(
      query.address,
      limit: query.limit,
      before: before,
      commitment: defaultCommitment,
    );

    if (signatures.isEmpty) {
      return const TxHistoryPage(items: [], nextCursor: null);
    }

    // Halt-on-429 flag is captured by closure: when ANY in-flight
    // getTransaction returns 429, set `halted` so subsequent queued
    // tasks short-circuit instead of piling on more requests against
    // an already-throttled endpoint.
    var halted = false;
    Object? haltedError;

    List<SolanaHistoryTransaction> results;
    try {
      results = await Future.wait<SolanaHistoryTransaction>(
        signatures.map(
          (sigInfo) => _limiter.run<SolanaHistoryTransaction>(() async {
            if (halted) {
              return SolanaHistoryTransaction(
                signatureInfo: sigInfo,
                transaction: null,
              );
            }
            try {
              final raw = await _getTransactionRaw(
                sigInfo.signature,
                useJsonParsed: useJsonParsed,
                commitment: defaultCommitment,
              );
              return SolanaHistoryTransaction(
                signatureInfo: sigInfo,
                transaction: raw,
              );
            } catch (e) {
              if (_isRateLimit(e)) {
                halted = true;
                haltedError = e;
              }
              rethrow;
            }
          }),
        ),
        eagerError: true,
      );
    } catch (e) {
      if (halted) {
        throw TxHistoryApiException(
          code: -2002,
          message:
              'Solana batch getTransaction halted by rate limit '
              '(HTTP 429). Cause: $haltedError',
        );
      }
      rethrow;
    }

    // Solana paginates backwards in time: the LAST signature in this
    // page is the oldest, and the next page resumes "before" it.
    final nextCursor = SolanaCursor(signatures.last.signature);
    return TxHistoryPage<SolanaHistoryTransaction>(
      items: results,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<TxHistoryPage<SolanaHistoryTransaction>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) => listTransactions(
    TxHistoryQuery(address: address, cursor: cursor, limit: limit),
  );

  /// Strict 429 detector. Match the exception TYPE plus its
  /// `statusCode` rather than substring-matching the message —
  /// the message text is implementation-detail and substring "429"
  /// could appear coincidentally inside a transaction signature or
  /// a slot number quoted in an unrelated error body.
  bool _isRateLimit(Object e) {
    return e is RpcHttpException && e.statusCode == 429;
  }

  /// Bypasses the v1.0 typed `getTransaction` wrapper because that
  /// wrapper hard-codes `encoding=jsonParsed` (transaction_methods.dart
  /// line 50). The history layer needs `encoding=base64` by default for
  /// raw fidelity (PITFALLS.md C-03). Adding a new method to the
  /// existing mixin would violate the LD-2 firewall (no v1.0 surface
  /// changes during phase 11), so we go straight to `transport.send`.
  Future<Map<String, dynamic>?> _getTransactionRaw(
    String signature, {
    required bool useJsonParsed,
    required SolanaCommitment commitment,
  }) async {
    final config = <String, dynamic>{
      'encoding': useJsonParsed ? 'jsonParsed' : 'base64',
      'maxSupportedTransactionVersion': 0,
      'commitment': commitment.name,
    };
    final result = await _rpc.transport.send('getTransaction', <dynamic>[
      signature,
      config,
    ]);
    if (result == null) return null;
    return result as Map<String, dynamic>;
  }

  /// Disposes the underlying [SolanaRpcClient] **only if** this provider
  /// was created via [SolanaNativeProvider.fromUrl] (i.e. owns the
  /// transport). When a caller injected a pre-built [SolanaRpcClient]
  /// via the default constructor, the rpc remains alive.
  ///
  /// Idempotent (HIST-OPS-03): calling [close] more than once does NOT
  /// throw — the second and subsequent calls are no-ops.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsRpc) _rpc.close();
  }
}
