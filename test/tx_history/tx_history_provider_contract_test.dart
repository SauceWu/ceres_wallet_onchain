import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:test/test.dart';

class _FakeProvider extends TxHistoryProvider<String> {
  bool closed = false;
  int callCount = 0;

  @override
  Future<TxHistoryPage<String>> listTransactions(TxHistoryQuery query) async {
    callCount++;
    return TxHistoryPage<String>(
      items: <String>[query.address],
      nextCursor: query.cursor,
    );
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  group('TxHistoryProvider contract', () {
    test(
      'subclass implementing listTransactions + close compiles and runs',
      () async {
        final p = _FakeProvider();
        final page = await p.listTransactions(
          const TxHistoryQuery(address: '0xabc'),
        );
        expect(page.items, ['0xabc']);
        expect(p.callCount, 1);
        p.close();
        expect(p.closed, isTrue);
      },
    );

    test('list() convenience forwards to listTransactions', () async {
      final p = _FakeProvider();
      final page = await p.list(address: '0xabc', limit: 25);
      expect(page.items, ['0xabc']);
      expect(p.callCount, 1);
    });
  });

  group('TxHistoryPage', () {
    test('hasMore is true when nextCursor != null', () {
      final page = TxHistoryPage<String>(
        items: const ['a', 'b'],
        nextCursor: SolanaCursor('sig1'),
      );
      expect(page.hasMore, isTrue);
      expect(page.items.length, 2);
    });

    test('hasMore is false when nextCursor is null', () {
      const page = TxHistoryPage<String>(items: <String>[]);
      expect(page.hasMore, isFalse);
      expect(page.items, isEmpty);
    });
  });

  group('TxHistoryQuery', () {
    test(
      'only address required; limit/cursor/fromBlock/toBlock/extra optional',
      () {
        const q = TxHistoryQuery(address: '0xabc');
        expect(q.address, '0xabc');
        expect(q.limit, isNull);
        expect(q.cursor, isNull);
        expect(q.fromBlock, isNull);
        expect(q.toBlock, isNull);
        expect(q.extra, isNull);
      },
    );

    test('toString does NOT leak cursor content or extra map', () {
      final q = TxHistoryQuery(
        address: '0xabc',
        limit: 50,
        cursor: SolanaCursor('SECRET-SIG'),
        extra: const {'apikey': 'SECRET-KEY'},
      );
      final s = q.toString();
      expect(s, contains('0xabc'));
      expect(s, contains('50'));
      expect(s, contains('hasCursor'));
      expect(s, isNot(contains('SECRET-SIG')));
      expect(s, isNot(contains('SECRET-KEY')));
      expect(s, isNot(contains('apikey')));
    });
  });
}
