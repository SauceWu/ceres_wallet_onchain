/// Inputs for [TxHistoryProvider.listTransactions].
///
/// A neutral request shape shared by every chain provider. Providers
/// validate the [address] field against their own format and may ignore
/// fields that do not apply to their chain (e.g. [fromBlock] / [toBlock]
/// are EVM/Tron-specific — Solana and Sui ignore them).
library;

import 'tx_history_cursor.dart';

/// Request inputs for fetching one page of transaction history.
///
/// Pass [cursor] = `null` to fetch the first page; subsequent pages
/// pass the previous response's [TxHistoryPage.nextCursor].
///
/// [extra] is a provider-specific escape hatch for filters not covered by
/// the neutral fields (e.g. Solana `commitment`, Etherscan `sort=asc`).
/// It is NEVER serialised by [toString] to avoid leaking sensitive content
/// (T-11-05 — extra may carry api keys or wallet identifiers).
class TxHistoryQuery {
  /// Address to query. Provider validates format (EVM hex / Solana base58 /
  /// Sui hex / Tron base58check).
  final String address;

  /// Page size hint. Provider clamps to its own limits. `null` means
  /// "use provider default".
  final int? limit;

  /// Cursor returned by the previous page, or `null` for the first page.
  final TxHistoryCursor? cursor;

  /// Inclusive lower-bound block. EVM / Tron only — `null` elsewhere.
  final BigInt? fromBlock;

  /// Inclusive upper-bound block. EVM / Tron only — `null` elsewhere.
  final BigInt? toBlock;

  /// Provider-specific extra filters. Never logged.
  final Map<String, dynamic>? extra;

  /// Creates a [TxHistoryQuery]. Only [address] is required.
  const TxHistoryQuery({
    required this.address,
    this.limit,
    this.cursor,
    this.fromBlock,
    this.toBlock,
    this.extra,
  });

  /// Renders a non-sensitive description. Deliberately omits cursor
  /// contents and the [extra] map to keep secrets out of logs.
  @override
  String toString() =>
      'TxHistoryQuery(address: $address, limit: $limit, '
      'hasCursor: ${cursor != null})';
}
