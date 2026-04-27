import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_exception.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_error.dart';
import 'package:test/test.dart';

void main() {
  group('checkTronError', () {
    test('throws RpcException on Error field', () {
      expect(
        () => checkTronError({'Error': 'Account not found'}),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', -2)
              .having(
                (e) => e.message,
                'message',
                contains('Account not found'),
              ),
        ),
      );
    });

    test('throws RpcException on result.result==false with hex message', () {
      final hexMessage = _toHex('balance is not sufficient');
      expect(
        () => checkTronError({
          'result': {
            'result': false,
            'code': 'CONTRACT_VALIDATE_ERROR',
            'message': hexMessage,
          },
        }),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', -2)
              .having(
                (e) => e.message,
                'message',
                contains('balance is not sufficient'),
              ),
        ),
      );
    });

    test('does not throw on result.result==true', () {
      expect(
        () => checkTronError({
          'result': {'result': true},
        }),
        returnsNormally,
      );
    });

    test('does not throw on normal response', () {
      expect(() => checkTronError({'balance': 1000}), returnsNormally);
    });

    test('throws with code field in message', () {
      final hexMessage = _toHex('some error');
      expect(
        () => checkTronError({
          'result': {
            'result': false,
            'code': 'BANDWITH_ERROR',
            'message': hexMessage,
          },
        }),
        throwsA(
          isA<RpcException>().having(
            (e) => e.message,
            'message',
            contains('BANDWITH_ERROR'),
          ),
        ),
      );
    });
  });

  group('decodeTronErrorMessage', () {
    test('decodes hex-encoded UTF-8 string', () {
      final hex = _toHex('balance is not sufficient');
      expect(decodeTronErrorMessage(hex), equals('balance is not sufficient'));
    });

    test('empty string returns empty string', () {
      expect(decodeTronErrorMessage(''), equals(''));
    });

    test('invalid hex returns original string', () {
      expect(
        decodeTronErrorMessage('not-hex-at-all'),
        equals('not-hex-at-all'),
      );
    });
  });
}

/// Helper: convert a string to hex-encoded UTF-8.
String _toHex(String s) {
  final bytes = utf8.encode(s);
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
