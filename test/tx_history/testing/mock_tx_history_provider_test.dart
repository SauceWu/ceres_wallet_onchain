/// Behavioural tests for [MockTxHistoryProvider].
///
/// The mock is the test double that downstream wallet integration tests
/// consume via `package:ceres_wallet_onchain/tx_history_testing.dart`
/// (LD-10, HIST-DOC-06). These tests pin its contract:
///
///  - first call before any enqueue → [StateError] ('no responses enqueued')
///  - enqueueResponse(items, nextCursor: …) → exact page returned next call
///  - sequential enqueueResponse calls → FIFO; over-pop → [StateError]
///  - enqueueError(e) → next call throws `e` verbatim
///  - recordedQueries captures every [TxHistoryQuery] in order
///  - close() flips `isClosed`; subsequent calls throw [StateError]
///  - hasMore inferred from nextCursor (null → false; non-null → true)
library;

import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:ceres_wallet_onchain/tx_history_testing.dart';
import 'package:test/test.dart';

void main() {
  group('MockTxHistoryProvider — empty state', () {
    test('listTransactions before any enqueue → StateError', () async {
      final mock = MockTxHistoryProvider<String>();
      await expectLater(
        () => mock.listTransactions(const TxHistoryQuery(address: '0xabc')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no responses enqueued'),
          ),
        ),
      );
    });

    test('list() convenience also throws when no enqueue', () async {
      final mock = MockTxHistoryProvider<String>();
      await expectLater(
        () => mock.list(address: '0xabc'),
        throwsA(isA<StateError>()),
      );
    });

    test('isClosed starts false', () {
      final mock = MockTxHistoryProvider<String>();
      expect(mock.isClosed, isFalse);
    });
  });

  group('MockTxHistoryProvider — enqueueResponse', () {
    test('returns the enqueued page exactly', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const [
        'tx1',
        'tx2',
      ], nextCursor: SolanaCursor('s1'));
      final page = await mock.listTransactions(
        const TxHistoryQuery(address: 'A'),
      );
      expect(page.items, ['tx1', 'tx2']);
      expect(page.nextCursor, isA<SolanaCursor>());
      expect((page.nextCursor! as SolanaCursor).beforeSignature, 's1');
    });

    test('hasMore is true when nextCursor is non-null', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const ['x'], nextCursor: SolanaCursor('sig'));
      final page = await mock.list(address: 'A');
      expect(page.hasMore, isTrue);
    });

    test('hasMore is false when nextCursor is null', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const ['x']);
      final page = await mock.list(address: 'A');
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('FIFO sequential responses', () async {
      final mock = MockTxHistoryProvider<int>();
      mock.enqueueResponse(const [1, 2], nextCursor: SolanaCursor('p1'));
      mock.enqueueResponse(const [3, 4], nextCursor: SolanaCursor('p2'));
      mock.enqueueResponse(const [5]);

      final p1 = await mock.list(address: 'A');
      final p2 = await mock.list(address: 'A');
      final p3 = await mock.list(address: 'A');

      expect(p1.items, [1, 2]);
      expect(p2.items, [3, 4]);
      expect(p3.items, [5]);
      expect(p3.hasMore, isFalse);
    });

    test('over-pop after last enqueue → StateError', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const []);
      await mock.list(address: 'A');
      await expectLater(
        () => mock.list(address: 'A'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MockTxHistoryProvider — enqueueError', () {
    test('next call throws the enqueued exception verbatim', () async {
      final mock = MockTxHistoryProvider<String>();
      const err = InvalidCursorException(message: 'bad');
      mock.enqueueError(err);
      await expectLater(() => mock.list(address: 'A'), throwsA(same(err)));
    });

    test('error counts as a consumed slot — subsequent listTransactions '
        'pulls the next enqueued response', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueError(StateError('boom'));
      mock.enqueueResponse(const ['ok']);

      await expectLater(
        () => mock.list(address: 'A'),
        throwsA(isA<StateError>()),
      );
      final p = await mock.list(address: 'A');
      expect(p.items, ['ok']);
    });
  });

  group('MockTxHistoryProvider — recordedQueries', () {
    test('captures each TxHistoryQuery in order', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const ['a']);
      mock.enqueueResponse(const ['b']);

      await mock.listTransactions(
        const TxHistoryQuery(address: 'first', limit: 5),
      );
      await mock.list(address: 'second', limit: 10);

      expect(mock.recordedQueries, hasLength(2));
      expect(mock.recordedQueries[0].address, 'first');
      expect(mock.recordedQueries[0].limit, 5);
      expect(mock.recordedQueries[1].address, 'second');
      expect(mock.recordedQueries[1].limit, 10);
    });

    test('failed (error) calls are also recorded', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueError(StateError('x'));

      await expectLater(
        () => mock.list(address: 'errAddr'),
        throwsA(isA<StateError>()),
      );

      expect(mock.recordedQueries, hasLength(1));
      expect(mock.recordedQueries.first.address, 'errAddr');
    });
  });

  group('MockTxHistoryProvider — close()', () {
    test('flips isClosed and short-circuits subsequent calls', () async {
      final mock = MockTxHistoryProvider<String>();
      mock.enqueueResponse(const ['x']);

      mock.close();
      expect(mock.isClosed, isTrue);

      await expectLater(
        () => mock.list(address: 'A'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('closed'),
          ),
        ),
      );
    });

    test('close() is idempotent — calling twice does not throw', () {
      final mock = MockTxHistoryProvider<String>();
      mock.close();
      expect(mock.close, returnsNormally);
      expect(mock.isClosed, isTrue);
    });
  });

  group('MockTxHistoryProvider — TxHistoryProvider contract', () {
    test('is assignable to TxHistoryProvider<T>', () {
      final mock = MockTxHistoryProvider<int>();
      expect(mock, isA<TxHistoryProvider<int>>());
    });
  });
}
