/// In-memory test double for [TxHistoryProvider]. Lives in its own
/// `testing/` subdirectory and is exposed via the SEPARATE
/// `package:ceres_wallet_onchain/tx_history_testing.dart` barrel
/// (LD-10, HIST-DOC-06) so it never enters the production API surface.
library;

import 'dart:collection';

import '../tx_history_cursor.dart';
import '../tx_history_page.dart';
import '../tx_history_provider.dart';
import '../tx_history_query.dart';

/// Test double for [TxHistoryProvider] consumed by downstream wallet
/// integration tests.
///
/// Not part of the production API surface — exposed via the SEPARATE
/// import path `package:ceres_wallet_onchain/tx_history_testing.dart`
/// (LD-10) so production builds that do not import the testing barrel
/// pay no tree-shaking cost.
///
/// ## Contract
///
/// - [enqueueResponse] / [enqueueError] enqueue ONE response each, in
///   FIFO order. Each call to [listTransactions] (or [list]) consumes
///   exactly one queued entry.
/// - Calling [listTransactions] / [list] when nothing is enqueued
///   throws [StateError] — the mock NEVER fabricates pages, because a
///   silent empty page would mask a missing test setup.
/// - [recordedQueries] captures every [TxHistoryQuery] in the order it
///   was received, useful for asserting that the unit under test
///   paginated correctly.
/// - [close] flips [isClosed]; subsequent calls to [listTransactions]
///   throw [StateError]. [close] itself is idempotent (HIST-OPS-03
///   contract — calling twice MUST NOT throw).
///
/// ## Usage
///
/// ```dart
/// import 'package:ceres_wallet_onchain/tx_history.dart';
/// import 'package:ceres_wallet_onchain/tx_history_testing.dart';
///
/// final mock = MockTxHistoryProvider<String>();
/// mock.enqueueResponse(['tx1', 'tx2'], nextCursor: SolanaCursor('sigA'));
/// mock.enqueueResponse([]);
///
/// final page = await mock.listTransactions(
///   const TxHistoryQuery(address: 'addr'),
/// );
/// expect(page.items, ['tx1', 'tx2']);
/// expect(page.hasMore, isTrue);
///
/// expect(mock.recordedQueries.first.address, 'addr');
///
/// mock.close();
/// expect(mock.isClosed, isTrue);
/// ```
class MockTxHistoryProvider<T> implements TxHistoryProvider<T> {
  /// FIFO queue of pre-staged responses. Each entry is either a
  /// [TxHistoryPage] (success) or an [_MockError] wrapper (failure).
  final Queue<Object> _enqueued = Queue<Object>();

  /// Every [TxHistoryQuery] this mock has received, in submission order.
  ///
  /// Includes queries that ended in an error — useful for asserting that
  /// the unit under test made the expected call before the failure.
  final List<TxHistoryQuery> recordedQueries = <TxHistoryQuery>[];

  bool _closed = false;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Enqueues a successful response. The next [listTransactions] /
  /// [list] call will return a [TxHistoryPage] with [items] and
  /// [nextCursor]; [TxHistoryPage.hasMore] is inferred (`true` when
  /// [nextCursor] is non-null, `false` otherwise).
  void enqueueResponse(List<T> items, {TxHistoryCursor? nextCursor}) {
    _enqueued.addLast(TxHistoryPage<T>(items: items, nextCursor: nextCursor));
  }

  /// Enqueues a failure. The next [listTransactions] / [list] call will
  /// throw [error] verbatim (preserving identity, so `same(error)`
  /// matchers work in callers).
  void enqueueError(Object error) {
    _enqueued.addLast(_MockError(error));
  }

  @override
  Future<TxHistoryPage<T>> listTransactions(TxHistoryQuery query) async {
    if (_closed) {
      throw StateError('MockTxHistoryProvider has been closed');
    }
    recordedQueries.add(query);
    if (_enqueued.isEmpty) {
      throw StateError(
        'MockTxHistoryProvider: no responses enqueued '
        '(received query: address=${query.address}, '
        'hasCursor=${query.cursor != null}). '
        'Call enqueueResponse(...) or enqueueError(...) before invoking '
        'listTransactions in your test setup.',
      );
    }
    final next = _enqueued.removeFirst();
    if (next is _MockError) {
      throw next.error;
    }
    return next as TxHistoryPage<T>;
  }

  @override
  Future<TxHistoryPage<T>> list({
    required String address,
    TxHistoryCursor? cursor,
    int? limit,
  }) => listTransactions(
    TxHistoryQuery(address: address, cursor: cursor, limit: limit),
  );

  /// Marks the mock as closed. Subsequent [listTransactions] / [list]
  /// calls throw [StateError]. Idempotent — calling more than once is a
  /// no-op (HIST-OPS-03 contract).
  @override
  void close() {
    _closed = true;
  }
}

/// Internal sentinel that distinguishes an enqueued failure from an
/// enqueued page when both share the same `Object` slot in the queue.
class _MockError {
  final Object error;
  const _MockError(this.error);
}
