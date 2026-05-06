import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:test/test.dart';

void main() {
  group('TxHistoryException', () {
    test('extends RpcException — single catch (RpcException) works', () {
      Object? caught;
      try {
        throw const TxHistoryException(code: -2000, message: 'msg');
      } on RpcException catch (e) {
        caught = e;
      }
      expect(caught, isA<TxHistoryException>());
      expect(caught, isA<RpcException>());
      expect((caught as TxHistoryException).code, -2000);
      expect(caught.message, 'msg');
    });
  });

  group('InvalidCursorException', () {
    test('has fixed code -2001 and extends TxHistoryException', () {
      const e = InvalidCursorException(message: 'bad');
      expect(e.code, -2001);
      expect(e.message, 'bad');
      expect(e, isA<TxHistoryException>());
      expect(e, isA<RpcException>());
    });
  });

  group('TxHistoryApiException', () {
    test('exposes endpoint and stores other fields', () {
      final e = TxHistoryApiException(
        code: -2002,
        message: 'NOTOK',
        endpoint: 'https://api.example.com/list',
      );
      expect(e.code, -2002);
      expect(e.message, 'NOTOK');
      expect(e.endpoint, 'https://api.example.com/list');
      expect(e, isA<TxHistoryException>());
    });

    test('redacts apikey query param in endpoint', () {
      final e = TxHistoryApiException(
        code: -2002,
        message: 'm',
        endpoint: 'https://api.example.com?apikey=SECRET',
      );
      expect(e.endpoint, 'https://api.example.com?apikey=REDACTED');
      expect(e.endpoint, isNot(contains('SECRET')));
    });

    test('redacts api_key, api-key, key= variants (case-insensitive)', () {
      final samples = <String, String>{
        'https://api.example.com?api_key=SECRET':
            'https://api.example.com?api_key=REDACTED',
        'https://api.example.com?API-KEY=SECRET':
            'https://api.example.com?API-KEY=REDACTED',
        'https://api.example.com?key=SECRET':
            'https://api.example.com?key=REDACTED',
        'https://etherscan.io/api?module=account&action=txlist&apikey=ABCDEF&address=0x1':
            'https://etherscan.io/api?module=account&action=txlist&apikey=REDACTED&address=0x1',
      };
      for (final entry in samples.entries) {
        final e = TxHistoryApiException(
          code: -2002,
          message: 'm',
          endpoint: entry.key,
        );
        expect(e.endpoint, entry.value, reason: 'input: ${entry.key}');
      }
    });

    test('null endpoint stays null', () {
      final e = TxHistoryApiException(code: -2002, message: 'm');
      expect(e.endpoint, isNull);
    });
  });
}
