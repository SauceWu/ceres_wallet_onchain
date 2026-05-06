/// Abstract interface implemented by every chain-specific tx_history
/// provider.
///
/// Providers return RAW chain data (LD-3) — no cross-chain unification.
/// Cursors are sealed per chain (LD-4) so passing the wrong cursor type
/// fails at compile time when the caller exhausts the [TxHistoryCursor]
/// switch, and at runtime via [InvalidCursorException] when narrowed
/// dynamically.
library;

import 'tx_history_cursor.dart';
import 'tx_history_page.dart';
import 'tx_history_query.dart';

/// Opt-in transaction-history provider.
///
/// `T` is the chain-native raw item shape:
///
/// - `Map<String, dynamic>` for REST chains (Blockscout / Etherscan /
///   TronGrid)
/// - the existing v1.0 typed responses for Solana / Sui (e.g.
///   `SignatureInfo`, `SuiTransactionBlockResponse`)
///
/// Each provider owns its own transport (`http.Client` or
/// `JsonRpcTransport`). When the provider creates the transport
/// internally it MUST close it on [close]; when an external transport
/// is injected the provider MUST NOT close it (HIST-OPS-03 — ownership
/// flag).
abstract class TxHistoryProvider<T> {
  /// Const constructor for subclasses.
  const TxHistoryProvider();

  /// Returns one page of raw history items for the address in [query].
  ///
  /// Pass `query.cursor == null` for the first page; pass the previous
  /// response's [TxHistoryPage.nextCursor] to advance. Wrong-chain
  /// cursors raise [InvalidCursorException]; transport-level failures
  /// raise the existing [RpcException] subclasses; structured upstream
  /// errors raise [TxHistoryApiException].
  Future<TxHistoryPage<T>> listTransactions(TxHistoryQuery query);

  /// Convenience wrapper around [listTransactions] for callers that do
  /// not need [TxHistoryQuery]'s full surface.
  ///
  /// Subclasses MUST NOT override this method — it forwards verbatim so
  /// that adding new fields to [TxHistoryQuery] in the future does not
  /// require touching every provider.
  Future<TxHistoryPage<T>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) => listTransactions(
    TxHistoryQuery(address: address, cursor: cursor, limit: limit),
  );

  /// Releases owned resources (the internally-created `http.Client`,
  /// any pooled transports, …). MUST be idempotent — calling
  /// [close] more than once is allowed and must not throw.
  ///
  /// If the provider received an externally-owned transport via its
  /// constructor it MUST NOT close that transport here.
  void close();
}
