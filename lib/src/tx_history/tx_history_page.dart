/// One page of raw transaction-history items returned by a [TxHistoryProvider].
library;

import 'tx_history_cursor.dart';

/// One page of raw chain history items.
///
/// `T` is the chain-native raw shape:
/// - `Map<String, dynamic>` for REST chains (Blockscout, Etherscan, TronGrid)
/// - existing v1.0 typed responses for Solana / Sui (e.g. `SignatureInfo`,
///   `SuiTransactionBlockResponse`)
///
/// Providers expose RAW chain data — the SDK never normalises across chains
/// (LD-3). To advance pagination, pass [nextCursor] back into the provider's
/// next call; when [nextCursor] is `null` there are no more pages.
class TxHistoryPage<T> {
  /// Items in this page, in the order returned by the upstream indexer.
  final List<T> items;

  /// Cursor to fetch the next page, or `null` if this is the last page.
  final TxHistoryCursor? nextCursor;

  /// Whether more pages are available — i.e. [nextCursor] is non-null.
  bool get hasMore => nextCursor != null;

  /// Creates a [TxHistoryPage] with the given [items] and optional
  /// [nextCursor].
  const TxHistoryPage({required this.items, this.nextCursor});
}
