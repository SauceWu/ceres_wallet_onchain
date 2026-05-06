/// Sealed pagination cursor types for tx_history providers.
///
/// Each chain ships its own cursor variant. Because [TxHistoryCursor] is a
/// `sealed class`, switch statements over the cursor must handle all variants
/// (compile-time exhaustiveness via `dart analyze`). Passing the wrong-chain
/// cursor to a provider therefore fails at compile time when the provider
/// uses an exhaustive `switch`, and at runtime via [InvalidCursorException]
/// when narrowed via `is`/`as` (PITFALLS.md C-05).
library;

/// Base type for opaque pagination cursors returned by tx_history providers.
///
/// The SDK never inspects cursor contents beyond what each subclass declares
/// in its constructor — cursors round-trip from the upstream indexer back to
/// the indexer untouched (PITFALLS.md C-09).
sealed class TxHistoryCursor {
  /// Const base constructor for sealed subclasses.
  const TxHistoryCursor();
}

/// Cursor for Blockscout v2 `/api/v2/addresses/{addr}/transactions`.
///
/// Blockscout returns a JSON `next_page_params` object on each page. To
/// fetch the next page the entire map is replayed verbatim as URL query
/// parameters. Equality is content-based so two cursors holding the same
/// page params compare equal regardless of construction site.
final class BlockscoutCursor extends TxHistoryCursor {
  /// Verbatim copy of Blockscout's `next_page_params` JSON object.
  final Map<String, String> nextPageParams;

  /// Creates a [BlockscoutCursor] wrapping the given page params map.
  const BlockscoutCursor(this.nextPageParams);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BlockscoutCursor) return false;
    if (other.nextPageParams.length != nextPageParams.length) return false;
    for (final entry in nextPageParams.entries) {
      if (other.nextPageParams[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    nextPageParams.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Cursor for the Etherscan v1/v2 `txlist` family.
///
/// Etherscan paginates by integer `page` (1-based) and `offset` (page size).
/// The upstream API hard-caps `offset` at 10000; values outside that range
/// are rejected at construction time to surface the error early instead of
/// hitting a non-deterministic upstream response (T-11-04 mitigation).
final class EtherscanCursor extends TxHistoryCursor {
  /// 1-based page number.
  final int page;

  /// Page size; clamped to 1..10000 by Etherscan.
  final int offset;

  /// Creates an [EtherscanCursor] for the given [page] and [offset].
  ///
  /// Throws [ArgumentError] if [page] < 1 or [offset] is outside `1..10000`.
  EtherscanCursor({required this.page, required this.offset}) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'must be >= 1');
    }
    if (offset < 1 || offset > 10000) {
      throw ArgumentError.value(offset, 'offset', 'must be 1..10000');
    }
  }
}

/// Cursor for Solana `getSignaturesForAddress`.
///
/// Solana paginates backwards in time using the `before` parameter, which
/// is the signature of the oldest transaction returned in the previous page.
final class SolanaCursor extends TxHistoryCursor {
  /// Signature string used as `before` in the next `getSignaturesForAddress`
  /// call.
  final String beforeSignature;

  /// Creates a [SolanaCursor] for the given [beforeSignature].
  ///
  /// Throws [ArgumentError] if [beforeSignature] is empty.
  SolanaCursor(this.beforeSignature) {
    if (beforeSignature.isEmpty) {
      throw ArgumentError.value(
        beforeSignature,
        'beforeSignature',
        'must be non-empty',
      );
    }
  }
}

/// Cursor for Sui `suix_queryTransactionBlocks`.
///
/// The Sui cursor is opaque — its format is part of the indexer
/// implementation, not the JSON-RPC API contract, so the SDK never
/// parses it (PITFALLS.md C-09). It is returned to the upstream
/// indexer untouched on the next page request.
final class SuiCursor extends TxHistoryCursor {
  /// Opaque cursor string returned by the Sui indexer.
  final String cursor;

  /// Creates a [SuiCursor] wrapping the given opaque [cursor] string.
  ///
  /// Throws [ArgumentError] if [cursor] is empty.
  SuiCursor(this.cursor) {
    if (cursor.isEmpty) {
      throw ArgumentError.value(cursor, 'cursor', 'must be non-empty');
    }
  }
}

/// Cursor for the TronGrid `accounts/{address}/transactions` endpoint.
///
/// TronGrid returns a `meta.fingerprint` string on every page; the next
/// request echoes it back via the `fingerprint` query parameter.
final class TronGridCursor extends TxHistoryCursor {
  /// Opaque fingerprint string returned by TronGrid.
  final String fingerprint;

  /// Creates a [TronGridCursor] wrapping the given [fingerprint].
  ///
  /// Throws [ArgumentError] if [fingerprint] is empty.
  TronGridCursor(this.fingerprint) {
    if (fingerprint.isEmpty) {
      throw ArgumentError.value(
        fingerprint,
        'fingerprint',
        'must be non-empty',
      );
    }
  }
}
