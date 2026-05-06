import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:test/test.dart';

void main() {
  group('BlockscoutCursor', () {
    test('stores nextPageParams map verbatim', () {
      final c = BlockscoutCursor(const {
        'block_number': '12345',
        'index': '7',
        'items_count': '50',
      });
      expect(c.nextPageParams['block_number'], '12345');
      expect(c.nextPageParams['index'], '7');
      expect(c.nextPageParams.length, 3);
    });

    test('equality is content-based', () {
      final a = BlockscoutCursor(const {'a': '1', 'b': '2'});
      final b = BlockscoutCursor(const {'a': '1', 'b': '2'});
      final c = BlockscoutCursor(const {'a': '1', 'b': '3'});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('EtherscanCursor', () {
    test('accepts valid page and offset', () {
      final c = EtherscanCursor(page: 1, offset: 10);
      expect(c.page, 1);
      expect(c.offset, 10);
    });

    test('throws on page < 1', () {
      expect(
        () => EtherscanCursor(page: 0, offset: 100),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EtherscanCursor(page: -1, offset: 100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on offset out of range (1..10000)', () {
      expect(
        () => EtherscanCursor(page: 1, offset: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => EtherscanCursor(page: 1, offset: 10001),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('boundary values 1 and 10000 accepted', () {
      expect(EtherscanCursor(page: 1, offset: 1).offset, 1);
      expect(EtherscanCursor(page: 1, offset: 10000).offset, 10000);
    });
  });

  group('SolanaCursor', () {
    test('stores beforeSignature', () {
      final c = SolanaCursor('5abc');
      expect(c.beforeSignature, '5abc');
    });

    test('throws on empty signature', () {
      expect(() => SolanaCursor(''), throwsA(isA<ArgumentError>()));
    });
  });

  group('SuiCursor', () {
    test('stores opaque cursor verbatim', () {
      final c = SuiCursor('opaque-string-do-not-parse');
      expect(c.cursor, 'opaque-string-do-not-parse');
    });

    test('throws on empty cursor', () {
      expect(() => SuiCursor(''), throwsA(isA<ArgumentError>()));
    });
  });

  group('TronGridCursor', () {
    test('stores fingerprint', () {
      final c = TronGridCursor('fp123');
      expect(c.fingerprint, 'fp123');
    });

    test('throws on empty fingerprint', () {
      expect(() => TronGridCursor(''), throwsA(isA<ArgumentError>()));
    });
  });

  group('TxHistoryCursor sealed exhaustiveness', () {
    test('switch over all 5 variants compiles and dispatches', () {
      String describe(TxHistoryCursor c) => switch (c) {
        BlockscoutCursor() => 'blockscout',
        EtherscanCursor() => 'etherscan',
        SolanaCursor() => 'solana',
        SuiCursor() => 'sui',
        TronGridCursor() => 'trongrid',
      };

      expect(describe(BlockscoutCursor(const {'k': 'v'})), 'blockscout');
      expect(describe(EtherscanCursor(page: 1, offset: 10)), 'etherscan');
      expect(describe(SolanaCursor('sig')), 'solana');
      expect(describe(SuiCursor('s')), 'sui');
      expect(describe(TronGridCursor('fp')), 'trongrid');
    });
  });
}
