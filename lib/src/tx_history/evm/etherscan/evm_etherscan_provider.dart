/// EVM transaction-history provider backed by the Etherscan API family.
///
/// Returns RAW Etherscan JSON shape per LD-3 — items are
/// `Map<String, dynamic>` and the SDK never normalises across chains.
/// Callers self-parse fields against Etherscan's documented schema.
library;

import 'package:http/http.dart' as http;

import '../../_internal/rest_history_client.dart';
import '../../endpoint_pool.dart';
import '../../tx_history_cursor.dart';
import '../../tx_history_exception.dart';
import '../../tx_history_page.dart';
import '../../tx_history_provider.dart';
import '../../tx_history_query.dart';

/// Etherscan-compatible transaction-history provider supporting both
/// **v1 per-chain hosts** and **v2 multichain mode**.
///
/// ## Construction modes
///
/// - **v1 per-chain hosts** (`api.etherscan.io`, `api.bscscan.com`,
///   `api.polygonscan.com`, `api.arbiscan.io`, `api.optimistic.etherscan.io`,
///   `api.basescan.org`, `api.snowtrace.io`, `api.ftmscan.com`):
///
///   ```dart
///   final p = EvmEtherscanProvider(
///     baseUrl: 'https://api.etherscan.io',
///     apiKey: 'YOUR_KEY',
///   );
///   ```
///
///   No `chainId` is sent — the host itself disambiguates the chain.
///
/// - **v2 multichain mode** (`api.etherscan.io/v2/api` with `chainid=`):
///
///   ```dart
///   final p = EvmEtherscanProvider(
///     baseUrl: 'https://api.etherscan.io/v2',
///     chainId: 1,
///     apiKey: 'YOUR_KEY',
///   );
///   ```
///
///   Caller is responsible for supplying the `/v2` segment in [baseUrl];
///   [chainId] is forwarded as the `chainid` query parameter on every
///   request. Both modes preserve the `module=account&action=txlist|tokentx`
///   surface (PITFALLS.md D-04 — schema unification).
///
/// ## Methods
///
/// Native transactions and token transfers are SEPARATE methods (LD-5):
///
/// - [listNativeTransactions] — `module=account&action=txlist`
/// - [listTokenTransfers] — `module=account&action=tokentx` with optional
///   `contractAddress` filter (`null` = all token transfers).
///
/// ## API keys
///
/// The SDK ships **no default key** (LD-9, PITFALLS.md D-01). Callers
/// either supply one via [apiKey] or run keyless (Etherscan accepts
/// unkeyed requests at ~1 call/5s in v2). Whatever the caller passes,
/// it is appended as the `apikey=` query parameter and **redacted to
/// `REDACTED`** in [TxHistoryApiException.endpoint] strings before they
/// reach logs (T-11-20 mitigation).
///
/// ## Pagination
///
/// Etherscan paginates by integer `page` (1-based) and `offset` (page
/// size). The provider returns an [EtherscanCursor] when the current
/// page is full (`items.length >= offset` heuristic — Etherscan does
/// not expose a `totalCount` field) and `null` when fewer items than
/// `offset` come back, signalling exhaustion. The corner case where the
/// last page has exactly `offset` items causes one extra request that
/// returns empty success — documented and acceptable.
///
/// ## Envelope parsing (PITFALLS.md C-07)
///
/// Etherscan returns `{"status": "0|1", "message": "...", "result": ...}`
/// on top of HTTP 200. The provider applies STRICT mapping:
///
/// | status | message                   | Behaviour                       |
/// |--------|---------------------------|---------------------------------|
/// | `"1"`  | (any)                     | success — `result` parsed       |
/// | `"0"`  | `"No transactions found"` | success — empty page            |
/// | `"0"`  | `"No records found"`      | success — empty page            |
/// | `"0"`  | (any other)               | `TxHistoryApiException(-2002)`  |
///
/// Silent mapping of `NOTOK` to empty would be data corruption (T-11-22).
class EvmEtherscanProvider implements TxHistoryProvider<Map<String, dynamic>> {
  final RestHistoryClient _rest;
  final String? _apiKey;

  /// Etherscan v2 chain ID. `null` selects v1 per-chain mode (the host
  /// implicitly identifies the chain). When set, forwarded as `chainid=`
  /// on every request.
  final int? chainId;

  /// Default page size used when neither [TxHistoryQuery.limit] nor
  /// the per-method `limit` argument is supplied. Etherscan accepts
  /// 1..10000; 50 mirrors Etherscan's own UI default.
  final int defaultPageSize;

  /// Idempotent close guard so [close] can be called more than once
  /// without throwing (HIST-OPS-03 contract).
  bool _closed = false;

  /// Creates an [EvmEtherscanProvider].
  ///
  /// [baseUrl] — Etherscan-compatible host. For v1 mode pass the chain's
  /// dedicated host (e.g. `https://api.etherscan.io`,
  /// `https://api.bscscan.com`); for v2 multichain mode pass
  /// `https://api.etherscan.io/v2` and set [chainId].
  /// [apiKey] — optional Etherscan API key. Forwarded as `apikey=` query
  /// param. `null` enables keyless mode (rate-limited but functional).
  /// [chainId] — required for v2 multichain mode; leave `null` for v1.
  /// [httpClient] — optional injected `http.Client`. When supplied, the
  /// caller owns the lifecycle and the provider will NOT close it.
  /// [timeout] — per-request timeout (default 15s).
  /// [defaultPageSize] — default `offset` value when caller omits `limit`.
  /// [allowInsecure] — set `true` ONLY for `http://localhost` dev. Leave
  /// `false` in production so the SSRF guard fires (T-11-15 mitigation).
  EvmEtherscanProvider({
    required String baseUrl,
    String? apiKey,
    this.chainId,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    this.defaultPageSize = 50,
    bool allowInsecure = false,
  }) : _apiKey = apiKey,
       _rest = RestHistoryClient(
         pool: EndpointPool(baseUrls: [baseUrl]),
         httpClient: httpClient,
         timeout: timeout,
         allowInsecure: allowInsecure,
       );

  /// Lists native (chain-coin-denominated) transactions for [address] via
  /// `module=account&action=txlist`.
  ///
  /// Pass [cursor] (an [EtherscanCursor]) to advance to the next page.
  /// [limit] sets the per-page `offset` (clamped to 1..10000); [startBlock]
  /// and [endBlock] forward to `startblock=` / `endblock=` for finer scope.
  Future<TxHistoryPage<Map<String, dynamic>>> listNativeTransactions(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
    BigInt? startBlock,
    BigInt? endBlock,
  }) {
    return _query(
      address: address,
      action: 'txlist',
      cursor: cursor,
      limit: limit,
      startBlock: startBlock,
      endBlock: endBlock,
    );
  }

  /// Lists ERC-20-style token transfers for [address] via
  /// `module=account&action=tokentx`.
  ///
  /// Pass [contractAddress] to filter to a single token contract; `null`
  /// returns transfers across all token contracts that touched [address].
  /// NFT transfers (`tokennfttx`, `token1155tx`) are intentionally NOT
  /// covered in v1.1 — see plan 11-06 `out_of_scope`.
  Future<TxHistoryPage<Map<String, dynamic>>> listTokenTransfers(
    String address, {
    String? contractAddress,
    TxHistoryCursor? cursor,
    int? limit,
    BigInt? startBlock,
    BigInt? endBlock,
  }) {
    return _query(
      address: address,
      action: 'tokentx',
      cursor: cursor,
      limit: limit,
      startBlock: startBlock,
      endBlock: endBlock,
      contractAddress: contractAddress,
    );
  }

  /// Default delegate: returns native EVM transactions for
  /// [TxHistoryQuery.address] (delegates to [listNativeTransactions]).
  /// Use [listTokenTransfers] for ERC-20 / ERC-721 / ERC-1155 history.
  ///
  /// **Mobile UI thread guidance (HIST-OPS-04):** Etherscan returns up
  /// to `offset=10000` rows per call by default; large pages parsed on
  /// the UI isolate may cause jank. If you observe frame drops, hop to
  /// a worker isolate via `Isolate.run`:
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
    startBlock: query.fromBlock,
    endBlock: query.toBlock,
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
    required String address,
    required String action,
    TxHistoryCursor? cursor,
    int? limit,
    BigInt? startBlock,
    BigInt? endBlock,
    String? contractAddress,
  }) async {
    // Etherscan accepts `offset` in 1..10000; values outside that range
    // produce confusing upstream errors. Clamp here so callers cannot
    // accidentally land in either degenerate bucket (T-11-04 mitigation).
    final effectiveLimit = (limit ?? defaultPageSize).clamp(1, 10000);
    var page = 1;
    var offset = effectiveLimit;
    if (cursor != null) {
      if (cursor is! EtherscanCursor) {
        throw InvalidCursorException(
          message:
              'expected EtherscanCursor; got ${cursor.runtimeType} '
              '(EvmEtherscanProvider only accepts EtherscanCursor)',
        );
      }
      page = cursor.page;
      // EtherscanCursor's constructor already validates offset in 1..10000.
      offset = cursor.offset;
    }
    final query = <String, String>{
      if (chainId != null) 'chainid': chainId.toString(),
      'module': 'account',
      'action': action,
      'address': address,
      'page': page.toString(),
      'offset': offset.toString(),
      'sort': 'asc',
      if (startBlock != null) 'startblock': startBlock.toString(),
      if (endBlock != null) 'endblock': endBlock.toString(),
      if (contractAddress != null) 'contractaddress': contractAddress,
      if (_apiKey != null) 'apikey': _apiKey,
    };

    final dynamic body = await _rest.get(path: '/api', query: query);
    if (body is! Map<String, dynamic>) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'unexpected Etherscan response shape '
            '(expected JSON object, got ${body.runtimeType})',
        endpoint: _buildRedactedEndpoint(query),
      );
    }
    final status = body['status']?.toString();
    final message = body['message']?.toString() ?? '';
    final result = body['result'];

    // Empty-success cases (PITFALLS.md C-07).
    if (status == '0' &&
        (message == 'No transactions found' || message == 'No records found')) {
      return const TxHistoryPage(items: [], nextCursor: null);
    }

    // Hard error: status != '1' with anything other than the documented
    // empty-success messages above. Includes 'NOTOK', 'Max rate limit
    // reached', 'Invalid API Key', and any future error string the
    // upstream may add — never silently mapped to empty (T-11-22).
    if (status != '1') {
      final detail = result is String ? result : '';
      throw TxHistoryApiException(
        code: -2002,
        message: 'Etherscan error: $message — $detail',
        endpoint: _buildRedactedEndpoint(query),
      );
    }

    if (result is! List) {
      throw TxHistoryApiException(
        code: -2002,
        message:
            'Etherscan status=1 but result is not a list '
            '(got ${result.runtimeType})',
        endpoint: _buildRedactedEndpoint(query),
      );
    }
    final items = result.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );

    // "More pages" heuristic: a full page suggests more items upstream.
    // Etherscan does not expose totalCount, so the only way to detect
    // exhaustion without an extra request is to compare the returned
    // count against the requested offset.
    EtherscanCursor? next;
    if (items.length >= offset) {
      next = EtherscanCursor(page: page + 1, offset: offset);
    }
    return TxHistoryPage(items: items, nextCursor: next);
  }

  /// Builds a path-with-query string suitable for [TxHistoryApiException.endpoint]
  /// with the `apikey=` value replaced by `REDACTED`.
  ///
  /// This is a defence-in-depth measure on top of
  /// `TxHistoryApiException._redactApiKey` — the constructor's regex strip
  /// runs as a second line of defence, but pre-redacting here means the
  /// raw key value never enters the exception object's memory at all.
  String _buildRedactedEndpoint(Map<String, String> query) {
    final parts = <String>[];
    query.forEach((k, v) {
      final value = (k.toLowerCase() == 'apikey') ? 'REDACTED' : v;
      parts.add('$k=${Uri.encodeQueryComponent(value)}');
    });
    return '/api?${parts.join('&')}';
  }
}
