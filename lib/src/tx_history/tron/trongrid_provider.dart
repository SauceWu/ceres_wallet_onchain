/// Tron transaction-history provider backed by TronGrid's `/v1/accounts/*`
/// REST API.
///
/// Returns RAW TronGrid v1 JSON shape per LD-3 — items are
/// `Map<String, dynamic>` and the SDK never normalises across chains.
/// Callers self-parse fields against TronGrid's documented schema.
library;

import 'package:http/http.dart' as http;

import '../_internal/rest_history_client.dart';
import '../endpoint_pool.dart';
import '../tx_history_cursor.dart';
import '../tx_history_exception.dart';
import '../tx_history_page.dart';
import '../tx_history_provider.dart';
import '../tx_history_query.dart';

/// TronGrid transaction history provider.
///
/// Wraps TronGrid's `/v1/accounts/{addr}/transactions` (TRX/native) and
/// `/v1/accounts/{addr}/transactions/trc20` (TRC-20 transfers) as TWO
/// SEPARATE methods (LD-5, PITFALLS.md C-02). TRC-20 is the dominant
/// Tron data family on mainnet — silently merging it into the TRX feed
/// would either drop transfers or double-count them. Callers interleave
/// the two streams themselves when they want a unified view.
///
/// **NOT a wrapper around v1.0 [TronHttpClient].** The v1.0 client targets
/// the open Tron HTTP API path family (the `wallet` namespace), which
/// works against self-hosted Java-tron nodes. This provider is
/// TronGrid-vendor-specific (`/v1/*`) and would surface confusing 404s
/// if pointed at a self-hosted node — see PITFALLS.md C-08 (T-11-29
/// mitigation, structural firewall).
///
/// API key (HIST-TRON-03, LD-9): supply via [apiKey] constructor arg →
/// sent as the `TRON-PRO-API-KEY` header on every request. A `null`
/// [apiKey] selects keyless mode (degraded TronGrid public rate limit).
/// The SDK ships NO default key.
///
/// Cursor: opaque [TronGridCursor.fingerprint] pulled from
/// `response.meta.fingerprint`. Fingerprints are PER-ENDPOINT — a
/// fingerprint returned by [listTrxTransactions] passed to
/// [listTrc20Transfers] (or vice versa) will not page correctly. The
/// runtime accepts this misuse silently because the cursor type is the
/// same; the contract is documented and tested rather than enforced.
/// Callers maintain separate cursors per endpoint.
///
/// Optional `min_timestamp` / `max_timestamp` (ms-since-epoch) lets the
/// "fetch since last opened app" mobile UX skip pages instead of paging
/// from the head of the feed.
///
/// ```dart
/// final provider = TronGridProvider(
///   baseUrl: 'https://api.trongrid.io',
///   apiKey: 'YOUR-TRON-PRO-API-KEY', // optional
/// );
///
/// // Native TRX history.
/// final trx = await provider.listTrxTransactions('TJRabPrwbZy45sba...');
///
/// // TRC-20 transfers (separate cursor!).
/// final trc20 = await provider.listTrc20Transfers('TJRabPrwbZy45sba...');
///
/// provider.close();
/// ```
class TronGridProvider implements TxHistoryProvider<Map<String, dynamic>> {
  /// Hard upper bound TronGrid documents on the `limit` query parameter.
  static const _maxLimit = 200;

  /// TronGrid default page size; mirrored here so callers omitting `limit`
  /// see deterministic behavior independent of upstream defaults.
  static const _defaultLimit = 20;

  final RestHistoryClient _rest;

  /// Default value of the `only_confirmed` query parameter when
  /// `includeUnconfirmed` is unset on a per-call basis. `true` matches
  /// FEATURES.md TS row 7 (confirmed transactions only by default).
  final bool defaultOnlyConfirmed;

  /// Idempotency guard so [close] can be called more than once
  /// without throwing (HIST-OPS-03 contract).
  bool _closed = false;

  /// Creates a [TronGridProvider].
  ///
  /// [baseUrl] — typically `https://api.trongrid.io`. Must be `https://`
  /// unless [allowInsecure] is `true` (intended only for `http://localhost`
  /// dev — production callers should leave this `false` to keep the
  /// SSRF / MITM guard active, T-11-15 mitigation).
  ///
  /// [apiKey] — optional TronGrid API key sent as `TRON-PRO-API-KEY`
  /// header on every request (HIST-TRON-03). The SDK ships no default key.
  ///
  /// [httpClient] — optional injected client. When supplied, the caller
  /// owns the lifecycle and the provider will NOT close it on [close].
  ///
  /// [timeout] — per-attempt request timeout (default 15s).
  ///
  /// [defaultOnlyConfirmed] — see field doc. Defaults to `true`.
  TronGridProvider({
    required String baseUrl,
    String? apiKey,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    this.defaultOnlyConfirmed = true,
    bool allowInsecure = false,
  }) : _rest = RestHistoryClient(
         pool: EndpointPool(baseUrls: [baseUrl]),
         httpClient: httpClient,
         timeout: timeout,
         defaultHeaders: <String, String>{
           if (apiKey != null) 'TRON-PRO-API-KEY': apiKey,
         },
         allowInsecure: allowInsecure,
       );

  /// Lists native TRX transactions for [address].
  ///
  /// Hits `GET /v1/accounts/{address}/transactions`.
  ///
  /// [cursor] — pass [TronGridPage.nextCursor] from a previous page; pass
  /// `null` for the first page. Wrong-chain cursors raise
  /// [InvalidCursorException].
  ///
  /// [limit] — page size (default 20). Must be in `1..200` or
  /// [ArgumentError] is thrown.
  ///
  /// [includeUnconfirmed] — when non-null, overrides
  /// [defaultOnlyConfirmed]. `true` flips `only_confirmed=false`,
  /// `false` flips `only_confirmed=true`.
  ///
  /// [minTimestamp] / [maxTimestamp] — optional inclusive bounds, sent as
  /// ms-since-epoch in `min_timestamp` / `max_timestamp` query params.
  Future<TxHistoryPage<Map<String, dynamic>>> listTrxTransactions(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
    bool? includeUnconfirmed,
    DateTime? minTimestamp,
    DateTime? maxTimestamp,
  }) {
    return _query(
      path: '/v1/accounts/$address/transactions',
      cursor: cursor,
      limit: limit,
      includeUnconfirmed: includeUnconfirmed,
      minTimestamp: minTimestamp,
      maxTimestamp: maxTimestamp,
    );
  }

  /// Lists TRC-20 token transfers for [address].
  ///
  /// Hits `GET /v1/accounts/{address}/transactions/trc20`.
  ///
  /// Same parameter semantics as [listTrxTransactions]. The cursor type
  /// is structurally identical ([TronGridCursor]) but fingerprints are
  /// per-endpoint — reusing a TRX cursor here will quietly produce wrong
  /// pages. Callers MUST track separate cursors per endpoint
  /// (PITFALLS.md C-02 — accepted threat T-11-27).
  Future<TxHistoryPage<Map<String, dynamic>>> listTrc20Transfers(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
    bool? includeUnconfirmed,
    DateTime? minTimestamp,
    DateTime? maxTimestamp,
  }) {
    return _query(
      path: '/v1/accounts/$address/transactions/trc20',
      cursor: cursor,
      limit: limit,
      includeUnconfirmed: includeUnconfirmed,
      minTimestamp: minTimestamp,
      maxTimestamp: maxTimestamp,
    );
  }

  /// Default delegate: [listTransactions] forwards to [listTrxTransactions].
  /// Callers wanting TRC-20 must call [listTrc20Transfers] directly — the
  /// neutral [TxHistoryProvider] interface intentionally cannot dispatch
  /// to two endpoints (LD-5).
  ///
  /// **Mobile UI thread guidance (HIST-OPS-04):** TronGrid returns up
  /// to `limit=200` records per call and each record can include
  /// nested `internal_transactions`. If you observe frame drops while
  /// paging on the UI isolate, hop to a worker isolate via
  /// `Isolate.run`:
  ///
  /// ```dart
  /// final page = await Isolate.run(() => provider.listTransactions(query));
  /// ```
  @override
  Future<TxHistoryPage<Map<String, dynamic>>> listTransactions(
    TxHistoryQuery query,
  ) {
    return listTrxTransactions(
      query.address,
      cursor: query.cursor,
      limit: query.limit,
    );
  }

  @override
  Future<TxHistoryPage<Map<String, dynamic>>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) {
    return listTrxTransactions(address, cursor: cursor, limit: limit);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _rest.close();
  }

  Future<TxHistoryPage<Map<String, dynamic>>> _query({
    required String path,
    TxHistoryCursor? cursor,
    int? limit,
    bool? includeUnconfirmed,
    DateTime? minTimestamp,
    DateTime? maxTimestamp,
  }) async {
    final lim = limit ?? _defaultLimit;
    if (lim < 1 || lim > _maxLimit) {
      throw ArgumentError.value(
        lim,
        'limit',
        'must be 1..$_maxLimit, got $lim',
      );
    }

    // Per the truth table in the plan:
    //   defaultOnlyConfirmed=true,  includeUnconfirmed=null  -> true
    //   defaultOnlyConfirmed=true,  includeUnconfirmed=true  -> false
    //   defaultOnlyConfirmed=true,  includeUnconfirmed=false -> true
    //   defaultOnlyConfirmed=false, includeUnconfirmed=null  -> false
    //   defaultOnlyConfirmed=false, includeUnconfirmed=true  -> false
    //   defaultOnlyConfirmed=false, includeUnconfirmed=false -> true
    final unconfirmed = includeUnconfirmed ?? !defaultOnlyConfirmed;
    final query = <String, String>{
      'limit': lim.toString(),
      'only_confirmed': (!unconfirmed).toString(),
    };

    if (cursor != null) {
      if (cursor is! TronGridCursor) {
        throw InvalidCursorException(
          message:
              'expected TronGridCursor; got ${cursor.runtimeType} '
              '(TronGridProvider only accepts TronGridCursor)',
        );
      }
      query['fingerprint'] = cursor.fingerprint;
    }

    if (minTimestamp != null) {
      query['min_timestamp'] = minTimestamp.millisecondsSinceEpoch.toString();
    }
    if (maxTimestamp != null) {
      query['max_timestamp'] = maxTimestamp.millisecondsSinceEpoch.toString();
    }

    final dynamic body = await _rest.get(path: path, query: query);

    if (body is! Map<String, dynamic>) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'unexpected TronGrid response shape (path: $path, '
            'type: ${body.runtimeType})',
      );
    }

    // TronGrid sometimes signals failure with HTTP 200 + success=false
    // (PITFALLS.md C-07 echo). Surface it as a typed error rather than
    // silently mapping to an empty page (T-11-26 mitigation).
    if (body['success'] == false) {
      final upstream = body['error'] ?? body['Error'] ?? 'unknown';
      throw TxHistoryApiException(
        code: -2002,
        message: 'TronGrid error: $upstream',
      );
    }

    final dataRaw = body['data'];
    if (dataRaw is! List) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'TronGrid response missing "data" array '
            '(path: $path, keys: ${body.keys.join(",")})',
      );
    }
    final items = dataRaw.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );

    TronGridCursor? next;
    final meta = body['meta'];
    if (meta is Map<String, dynamic>) {
      final fp = meta['fingerprint'];
      if (fp is String && fp.isNotEmpty) {
        next = TronGridCursor(fp);
      }
    }
    return TxHistoryPage(items: items, nextCursor: next);
  }
}
