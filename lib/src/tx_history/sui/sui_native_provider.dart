/// Sui transaction-history provider — composes the existing v1.0
/// `SuiRpcClient` to back the HIST-CORE [TxHistoryProvider] interface.
library;

import '../../core/json_rpc_transport.dart';
import '../../core/rpc_client_config.dart';
import '../../sui/models/sui_options.dart';
import '../../sui/models/sui_transaction_block_response.dart';
import '../../sui/sui_rpc_client.dart';
import '../tx_history_cursor.dart';
import '../tx_history_exception.dart';
import '../tx_history_page.dart';
import '../tx_history_provider.dart';
import '../tx_history_query.dart';

/// Sui-native [TxHistoryProvider] backed by `sui_queryTransactionBlocks`.
///
/// **Composition over reimplementation.** The provider does not speak
/// JSON-RPC directly — it composes the existing v1.0 [SuiRpcClient]
/// (LD-6) and reuses its `queryTransactionBlocks` method (a single
/// network round-trip per page).
///
/// **Two listing methods, never combined.** Sui RPC enforces
/// `FromAddress` xor `ToAddress` filters — the two cannot appear in the
/// same query. This provider exposes both as separate methods:
///
///  - [listFromAddress] — sender-side history.
///  - [listToAddress]   — receiver-side history.
///
/// [listTransactions] (the [TxHistoryProvider] entry point) delegates to
/// [listFromAddress] by default. Callers who want **inbound** history
/// (where [TxHistoryQuery.address] is the receiver) MUST call
/// [listToAddress] directly. The provider never merges the two halves
/// because Sui RPC has no cross-side primitive and a client-side merge
/// would invent ordering that the indexer does not guarantee.
///
/// **Opaque cursor (PITFALLS.md C-09).** Sui's cursor format is part of
/// the indexer implementation, not the JSON-RPC API contract. The
/// provider NEVER parses, decodes, or otherwise inspects
/// [SuiCursor.cursor]; the string is passed straight through to the
/// upstream `cursor` parameter and the response's `nextCursor` is
/// re-wrapped untouched.
///
/// **Defaults:**
///
///  - Response options: `showInput`, `showEffects`, `showEvents`,
///    `showBalanceChanges` — chosen so callers can self-parse
///    instructions, gas, balance diffs, and event logs out of one
///    response (FEATURES.md table line 6). Override via the [options]
///    constructor parameter.
///  - [descendingOrder]: `true` — mobile UX expects newest-first.
///
/// **Lifecycle (HIST-OPS-03).** The provider tracks an ownership flag:
///
///  - When constructed via [SuiNativeProvider.new] with an injected
///    [SuiRpcClient], the provider does NOT close the client on
///    [close] — the caller retains ownership of the underlying
///    transport.
///  - When constructed via [SuiNativeProvider.fromUrl], the provider
///    creates the [SuiRpcClient] internally and DOES close it on
///    [close].
///
/// ```dart
/// final rpc = SuiRpcClient(
///   transport: JsonRpcTransport(
///     config: RpcClientConfig(baseUrl: 'https://fullnode.mainnet.sui.io'),
///   ),
/// );
/// final provider = SuiNativeProvider(rpcClient: rpc);
///
/// final page = await provider.listFromAddress('0xabc…');
/// for (final tx in page.items) {
///   print(tx.digest);
/// }
/// if (page.hasMore) {
///   final next = await provider.listFromAddress('0xabc…', cursor: page.nextCursor);
/// }
///
/// provider.close(); // does not close `rpc`
/// rpc.close();      // caller owns it
/// ```
class SuiNativeProvider
    implements TxHistoryProvider<SuiTransactionBlockResponse> {
  /// Default response options sent with every page request.
  ///
  /// Chosen to give callers enough material to self-parse a transaction
  /// without a follow-up RPC call: input data, effects (status + gas),
  /// events, and balance changes.
  static const SuiTransactionBlockResponseOptions defaultOptions =
      SuiTransactionBlockResponseOptions(
        showInput: true,
        showEffects: true,
        showEvents: true,
        showBalanceChanges: true,
      );

  final SuiRpcClient _rpc;
  final bool _ownsRpc;

  /// Idempotency guard so repeated [close] calls cannot drive the
  /// underlying transport through `close()` twice (HIST-OPS-03).
  bool _closed = false;

  /// Response options forwarded verbatim to `sui_queryTransactionBlocks`.
  final SuiTransactionBlockResponseOptions options;

  /// When `true`, request newest-first ordering (`order: "descending"`).
  final bool descendingOrder;

  /// Creates a provider that COMPOSES an externally-owned [SuiRpcClient].
  ///
  /// The provider does NOT close [rpcClient] on [close] — the caller
  /// retains ownership.
  SuiNativeProvider({
    required SuiRpcClient rpcClient,
    SuiTransactionBlockResponseOptions? options,
    this.descendingOrder = true,
  }) : _rpc = rpcClient,
       _ownsRpc = false,
       options = options ?? defaultOptions;

  /// Creates a provider that OWNS its own [SuiRpcClient].
  ///
  /// Builds a [JsonRpcTransport] against [baseUrl] and wraps it in a
  /// fresh [SuiRpcClient]. [close] tears down the entire chain.
  ///
  /// [baseUrl] MUST start with `https://` unless [allowInsecure] is
  /// `true` — same SSRF / MITM guard the REST providers enforce via
  /// `RestHistoryClient` (T-11-15). Use `allowInsecure: true` only for
  /// local dev (e.g. `http://localhost:9000`).
  SuiNativeProvider.fromUrl(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 15),
    SuiTransactionBlockResponseOptions? options,
    this.descendingOrder = true,
    bool allowInsecure = false,
  }) : _rpc = SuiRpcClient(
         transport: JsonRpcTransport(
           config: RpcClientConfig(
             baseUrl: _validateBaseUrl(baseUrl, allowInsecure),
             timeout: timeout,
           ),
         ),
       ),
       _ownsRpc = true,
       options = options ?? defaultOptions;

  /// Enforces the same HTTPS-only SSRF / MITM guard as [RestHistoryClient]
  /// (T-11-15). Returns [baseUrl] unchanged on success so this can run
  /// inside the initializer list before the [SuiRpcClient] is built.
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

  /// Lists transactions where [address] is the SENDER.
  ///
  /// Calls `sui_queryTransactionBlocks` with `filter: {"FromAddress":
  /// address}`. Pass [cursor] = `null` for the first page; pass the
  /// previous response's [TxHistoryPage.nextCursor] (which is a
  /// [SuiCursor]) to advance.
  Future<TxHistoryPage<SuiTransactionBlockResponse>> listFromAddress(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
  }) => _query({'FromAddress': address}, cursor, limit);

  /// Lists transactions where [address] is the RECEIVER.
  ///
  /// Calls `sui_queryTransactionBlocks` with `filter: {"ToAddress":
  /// address}`. Sui RPC enforces FromAddress xor ToAddress — this
  /// method is the ONLY way to fetch receiver-side history through
  /// the SDK.
  Future<TxHistoryPage<SuiTransactionBlockResponse>> listToAddress(
    String address, {
    TxHistoryCursor? cursor,
    int? limit,
  }) => _query({'ToAddress': address}, cursor, limit);

  /// Default delegate: returns the SENDER-side history
  /// ([listFromAddress]). Callers who want INBOUND history MUST call
  /// [listToAddress] directly — Sui RPC enforces FromAddress xor
  /// ToAddress in a single query and the provider deliberately does
  /// not merge the two sides client-side.
  ///
  /// In other words: if you only ever call [listTransactions], you only
  /// ever see outgoing transactions.
  ///
  /// **Mobile UI thread guidance (HIST-OPS-04):** the returned
  /// [SuiTransactionBlockResponse] objects can carry large `effects` /
  /// `events` payloads; if you observe frame drops while paging on the
  /// UI isolate, hop to a worker isolate via `Isolate.run`:
  ///
  /// ```dart
  /// final page = await Isolate.run(() => provider.listTransactions(query));
  /// ```
  ///
  /// (Use [SuiNativeProvider.fromUrl] when crossing isolate boundaries
  /// because the underlying transports must be re-constructible inside
  /// the worker isolate.)
  @override
  Future<TxHistoryPage<SuiTransactionBlockResponse>> listTransactions(
    TxHistoryQuery query,
  ) => listFromAddress(query.address, cursor: query.cursor, limit: query.limit);

  @override
  Future<TxHistoryPage<SuiTransactionBlockResponse>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) => listFromAddress(address, cursor: cursor, limit: limit);

  /// Closes the provider. If the [SuiRpcClient] was constructed by
  /// [SuiNativeProvider.fromUrl] (provider-owned) it is closed too;
  /// when an external client was injected via the default constructor
  /// it is left alone (HIST-OPS-03).
  ///
  /// Idempotent (HIST-OPS-03): calling [close] more than once does NOT
  /// throw — the second and subsequent calls are no-ops.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsRpc) {
      _rpc.close();
    }
  }

  Future<TxHistoryPage<SuiTransactionBlockResponse>> _query(
    Map<String, dynamic> filter,
    TxHistoryCursor? cursor,
    int? limit,
  ) async {
    final cursorStr = _unwrapCursor(cursor);
    final paged = await _rpc.queryTransactionBlocks(
      filter: filter,
      options: options,
      cursor: cursorStr,
      limit: limit,
      descendingOrder: descendingOrder,
    );
    final next =
        paged.hasNextPage &&
            paged.nextCursor != null &&
            paged.nextCursor!.isNotEmpty
        ? SuiCursor(paged.nextCursor!)
        : null;
    return TxHistoryPage<SuiTransactionBlockResponse>(
      items: paged.data,
      nextCursor: next,
    );
  }

  /// Validates that [cursor] is a [SuiCursor] (or null) and returns its
  /// opaque string. The cursor contents are NEVER inspected beyond
  /// type-checking — that is the whole point of C-09.
  String? _unwrapCursor(TxHistoryCursor? cursor) {
    if (cursor == null) return null;
    if (cursor is! SuiCursor) {
      throw InvalidCursorException(
        message: 'expected SuiCursor; got ${cursor.runtimeType}',
      );
    }
    return cursor.cursor;
  }
}
