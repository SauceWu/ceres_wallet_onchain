/// EVM transaction-history provider backed by the Blockscout v2 REST API.
///
/// Returns RAW Blockscout JSON shape per LD-3 — items are
/// `Map<String, dynamic>` and the SDK never normalises across chains.
/// Callers self-parse fields against Blockscout's documented schema.
library;

import 'package:http/http.dart' as http;

import '../../_internal/rest_history_client.dart';
import '../../endpoint_pool.dart';
import '../../tx_history_cursor.dart';
import '../../tx_history_exception.dart';
import '../../tx_history_page.dart';
import '../../tx_history_provider.dart';
import '../../tx_history_query.dart';

/// Allowed `type=` query values for the Blockscout token-transfers endpoint.
const _allowedTokenTypes = {'ERC-20', 'ERC-721', 'ERC-1155'};

/// Blockscout v2 transaction-history provider.
///
/// Constructed with one or more Blockscout instance base URLs (e.g.
/// `https://eth.blockscout.com`, `https://base.blockscout.com`) and uses
/// [EndpointPool] to fall over from a slow / 5xx / 429 instance to the next
/// one without infinite retries (T-11-02 mitigation, T-11-15 https guard).
///
/// Per LD-9 the SDK ships NO default URL registry — Blockscout instance
/// availability varies per chain (PITFALLS D-03), so callers supply their
/// own list. There is no automatic Etherscan failover (LD-8) — the response
/// shapes are different and unifying them silently would cause cursor
/// corruption.
///
/// Native transactions and token transfers are SEPARATE methods (LD-5):
///
/// - [listNativeTransactions] — `/api/v2/addresses/{addr}/transactions`
/// - [listTokenTransfers] — `/api/v2/addresses/{addr}/token-transfers`
///   with optional `type=ERC-20|ERC-721|ERC-1155` filter (`null` returns
///   all token types).
///
/// Pagination is bound via Blockscout's `next_page_params` JSON object,
/// wrapped in a [BlockscoutCursor] and replayed verbatim as URL query
/// parameters on the next request (FEATURES.md table line 2).
///
/// ```dart
/// final provider = EvmBlockscoutProvider(
///   baseUrls: const [
///     'https://eth.blockscout.com',
///     'https://blockscout.com/eth/mainnet',
///   ],
/// );
/// final page = await provider.listNativeTransactions('0x...');
/// for (final tx in page.items) {
///   print(tx['hash']);  // raw JSON Map
/// }
/// if (page.hasMore) {
///   final next = await provider.listNativeTransactions(
///     '0x...',
///     cursor: page.nextCursor,
///   );
/// }
/// provider.close();
/// ```
class EvmBlockscoutProvider implements TxHistoryProvider<Map<String, dynamic>> {
  final RestHistoryClient _rest;

  /// Idempotent close guard so [close] can be called more than once
  /// without throwing (HIST-OPS-03 contract).
  bool _closed = false;

  /// Creates an [EvmBlockscoutProvider].
  ///
  /// [baseUrls] — one or more Blockscout instance URLs in priority order.
  /// [httpClient] — optional injected client. When supplied, the caller
  /// owns the lifecycle and the provider will NOT close it on [close].
  /// [timeout] — per-attempt request timeout (default 15s).
  /// [circuitBreakDuration] — minimum ban window after a transient failure
  /// (default 30s; honored as a floor against `Retry-After`).
  /// [extraHeaders] — sent on every request (e.g. for self-hosted instances
  /// requiring custom headers).
  /// [allowInsecure] — set to `true` ONLY for `http://localhost` dev. In
  /// production, leaving this `false` enforces the SSRF guard
  /// (T-11-15 mitigation).
  EvmBlockscoutProvider({
    required List<String> baseUrls,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    Duration circuitBreakDuration = const Duration(seconds: 30),
    Map<String, String> extraHeaders = const {},
    bool allowInsecure = false,
  }) : _rest = RestHistoryClient(
         pool: EndpointPool(
           baseUrls: baseUrls,
           circuitBreakDuration: circuitBreakDuration,
         ),
         httpClient: httpClient,
         timeout: timeout,
         defaultHeaders: extraHeaders,
         allowInsecure: allowInsecure,
       );

  /// Lists native (chain-coin-denominated) transactions for [address].
  ///
  /// Hits `GET /api/v2/addresses/{address}/transactions`. Pass [cursor] to
  /// fetch a subsequent page; [limit] is forwarded as `?limit=N` (Blockscout
  /// caps internally — typically 50/100 — this method does NOT clamp).
  Future<TxHistoryPage<Map<String, dynamic>>> listNativeTransactions(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
  }) {
    return _query(
      path: '/api/v2/addresses/$address/transactions',
      cursor: cursor,
      limit: limit,
    );
  }

  /// Lists token transfers for [address].
  ///
  /// Hits `GET /api/v2/addresses/{address}/token-transfers`. Pass [type] =
  /// `'ERC-20'`, `'ERC-721'`, or `'ERC-1155'` to filter; `null` returns all
  /// token types. Throws [ArgumentError] for any other [type] value
  /// (T-11-19 mitigation — type allow-list).
  Future<TxHistoryPage<Map<String, dynamic>>> listTokenTransfers(
    String address, {
    String? type,
    TxHistoryCursor? cursor,
    int? limit,
  }) {
    if (type != null && !_allowedTokenTypes.contains(type)) {
      throw ArgumentError.value(
        type,
        'type',
        'must be ERC-20, ERC-721, or ERC-1155 (or null for all types)',
      );
    }
    final extra = <String, String>{};
    if (type != null) extra['type'] = type;
    return _query(
      path: '/api/v2/addresses/$address/token-transfers',
      cursor: cursor,
      limit: limit,
      extra: extra,
    );
  }

  /// Default delegate: returns native EVM transactions for
  /// [TxHistoryQuery.address] (delegates to [listNativeTransactions]).
  /// Use [listTokenTransfers] for ERC-20 / ERC-721 / ERC-1155 history.
  ///
  /// **Mobile UI thread guidance (HIST-OPS-04):** Blockscout responses
  /// can carry decoded `internal_transactions` arrays that grow with
  /// page size. If you observe frame drops while paging on the UI
  /// isolate, hop to a worker isolate via `Isolate.run`:
  ///
  /// ```dart
  /// final page = await Isolate.run(() => provider.listTransactions(query));
  /// ```
  @override
  Future<TxHistoryPage<Map<String, dynamic>>> listTransactions(
    TxHistoryQuery query,
  ) => listNativeTransactions(
    query.address,
    cursor: query.cursor,
    limit: query.limit,
  );

  @override
  Future<TxHistoryPage<Map<String, dynamic>>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) => listNativeTransactions(address, cursor: cursor, limit: limit);

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
    Map<String, String>? extra,
  }) async {
    final query = <String, String>{};
    if (cursor != null) {
      if (cursor is! BlockscoutCursor) {
        throw InvalidCursorException(
          message:
              'expected BlockscoutCursor; got ${cursor.runtimeType} '
              '(EvmBlockscoutProvider only accepts BlockscoutCursor)',
        );
      }
      query.addAll(cursor.nextPageParams);
    }
    if (limit != null) query['limit'] = limit.toString();
    if (extra != null) query.addAll(extra);

    final body = await _rest.get(path: path, query: query);
    if (body is! Map<String, dynamic>) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'unexpected response shape from Blockscout '
            '(path: $path, type: ${body.runtimeType})',
      );
    }
    final itemsRaw = body['items'];
    if (itemsRaw is! List) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'Blockscout response missing "items" array '
            '(path: $path, keys: ${body.keys.join(",")})',
      );
    }
    final items = itemsRaw.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );

    BlockscoutCursor? next;
    final npp = body['next_page_params'];
    if (npp is Map<String, dynamic> && npp.isNotEmpty) {
      // Blockscout sometimes returns numeric values inside next_page_params;
      // coerce to strings so the cursor's nextPageParams contract holds and
      // the values can be replayed verbatim as URL query parameters.
      final flat = <String, String>{};
      npp.forEach((k, v) => flat[k] = v.toString());
      next = BlockscoutCursor(flat);
    }
    return TxHistoryPage(items: items, nextCursor: next);
  }
}
