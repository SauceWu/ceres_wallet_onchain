import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

void main() {
  group('RpcException', () {
    test('constructs with code and message', () {
      const e = RpcException(code: 100, message: 'test');
      expect(e.code, 100);
      expect(e.message, 'test');
      expect(e.data, isNull);
    });

    test('toString returns formatted string', () {
      const e = RpcException(code: 100, message: 'test');
      expect(e.toString(), 'RpcException(100): test');
    });

    test('data field is accessible when provided', () {
      const e = RpcException(
        code: 200,
        message: 'with data',
        data: {'key': 'val'},
      );
      expect(e.data, {'key': 'val'});
    });

    test('implements Exception', () {
      const e = RpcException(code: 0, message: 'base');
      expect(e, isA<Exception>());
    });
  });

  group('RpcTimeoutException', () {
    test('constructs with timeout duration', () {
      final e = RpcTimeoutException(timeout: const Duration(seconds: 30));
      expect(e.code, -1);
      expect(e.message, contains('30s'));
      expect(e.timeout, const Duration(seconds: 30));
    });

    test('is RpcException', () {
      final e = RpcTimeoutException(timeout: const Duration(seconds: 5));
      expect(e, isA<RpcException>());
    });

    test('is Exception', () {
      final e = RpcTimeoutException(timeout: const Duration(seconds: 5));
      expect(e, isA<Exception>());
    });
  });

  group('RpcHttpException', () {
    test('constructs with statusCode and message', () {
      const e = RpcHttpException(
        statusCode: 503,
        message: 'Service Unavailable',
      );
      expect(e.code, 503);
      expect(e.statusCode, 503);
      expect(e.message, 'Service Unavailable');
    });

    test('is RpcException', () {
      const e = RpcHttpException(statusCode: 404, message: 'Not Found');
      expect(e, isA<RpcException>());
    });

    test('is Exception', () {
      const e = RpcHttpException(statusCode: 404, message: 'Not Found');
      expect(e, isA<Exception>());
    });
  });

  group('RpcResponseException', () {
    test('constructs with code, message, and optional data', () {
      const e = RpcResponseException(code: -32601, message: 'Method not found');
      expect(e.code, -32601);
      expect(e.message, 'Method not found');
      expect(e.data, isNull);
    });

    test('accepts data field', () {
      const e = RpcResponseException(
        code: -32602,
        message: 'Invalid params',
        data: 'missing required field',
      );
      expect(e.data, 'missing required field');
    });

    test('is RpcException', () {
      const e = RpcResponseException(code: -32601, message: 'Method not found');
      expect(e, isA<RpcException>());
    });

    test('is Exception', () {
      const e = RpcResponseException(code: -32601, message: 'Method not found');
      expect(e, isA<Exception>());
    });
  });

  group('type hierarchy', () {
    test('all subtypes are RpcException', () {
      final timeout = RpcTimeoutException(timeout: const Duration(seconds: 10));
      const http = RpcHttpException(statusCode: 500, message: 'Error');
      const response = RpcResponseException(
        code: -32600,
        message: 'Invalid Request',
      );

      expect(timeout, isA<RpcException>());
      expect(http, isA<RpcException>());
      expect(response, isA<RpcException>());
    });

    test('all subtypes are Exception', () {
      final timeout = RpcTimeoutException(timeout: const Duration(seconds: 10));
      const http = RpcHttpException(statusCode: 500, message: 'Error');
      const response = RpcResponseException(
        code: -32600,
        message: 'Invalid Request',
      );

      expect(timeout, isA<Exception>());
      expect(http, isA<Exception>());
      expect(response, isA<Exception>());
    });
  });
}
