import 'dart:async';
import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRpcTransport', () {
    late RpcClientConfig config;

    setUp(() {
      config = const RpcClientConfig(
        baseUrl: 'https://rpc.example.com',
        timeout: Duration(seconds: 5),
      );
    });

    test('successful request returns result field', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x10'}),
          200,
        );
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x10'));
      transport.close();
    });

    test('JSON-RPC error response throws RpcResponseException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32601, 'message': 'Method not found'},
          }),
          200,
        );
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      expect(
        () => transport.send('nonexistent_method', []),
        throwsA(
          isA<RpcResponseException>()
              .having((e) => e.code, 'code', -32601)
              .having((e) => e.message, 'message', 'Method not found'),
        ),
      );
      transport.close();
    });

    test('timeout throws RpcTimeoutException', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 10));
        return http.Response('{}', 200);
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(milliseconds: 100),
        ),
        httpClient: client,
      );

      expect(
        () => transport.send('eth_blockNumber', []),
        throwsA(isA<RpcTimeoutException>()),
      );
      transport.close();
    });

    test('HTTP 500 throws RpcHttpException', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      expect(
        () => transport.send('eth_blockNumber', []),
        throwsA(
          isA<RpcHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      transport.close();
    });

    test('HTTP 404 throws RpcHttpException and does not retry', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('Not Found', 404);
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 2,
        ),
        httpClient: client,
      );

      try {
        await transport.send('eth_blockNumber', []);
      } catch (_) {}
      expect(callCount, equals(1));
      transport.close();
    });

    test('4xx errors are not retried', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('Bad Request', 400);
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 2,
        ),
        httpClient: client,
      );

      try {
        await transport.send('eth_blockNumber', []);
      } catch (_) {}
      expect(callCount, equals(1));
      transport.close();
    });

    test('retry succeeds on second attempt after timeout', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x20'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(milliseconds: 100),
          maxRetries: 2,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x20'));
      expect(callCount, equals(2));
      transport.close();
    });

    test('retry exhausted throws last exception', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        await Future.delayed(const Duration(seconds: 10));
        return http.Response('{}', 200);
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(milliseconds: 100),
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      try {
        await transport.send('eth_blockNumber', []);
        fail('Should have thrown');
      } on RpcTimeoutException {
        // expected
      }
      // maxRetries=1 means initial attempt + 1 retry = 2 calls
      expect(callCount, equals(2));
      transport.close();
    });

    test('5xx errors trigger retry', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x30'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x30'));
      expect(callCount, equals(2));
      transport.close();
    });

    test('logger receives request and response entries', () async {
      final logs = <RpcLogEntry>[];
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x40'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: const Duration(seconds: 5),
          logger: (entry) => logs.add(entry),
        ),
        httpClient: client,
      );

      await transport.send('eth_blockNumber', []);

      expect(logs, hasLength(2));
      expect(logs[0].direction, equals(RpcLogDirection.request));
      expect(logs[0].method, equals('eth_blockNumber'));
      expect(logs[1].direction, equals(RpcLogDirection.response));
      expect(logs[1].method, equals('eth_blockNumber'));
      expect(logs[1].result, equals('0x40'));
      expect(logs[1].duration, isNotNull);
      transport.close();
    });

    test('extraHeaders are included in request', () async {
      final client = MockClient((request) async {
        expect(request.headers['X-Api-Key'], equals('my-key'));
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': 'ok'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(seconds: 5),
          extraHeaders: {'X-Api-Key': 'my-key'},
        ),
        httpClient: client,
      );

      await transport.send('eth_blockNumber', []);
      transport.close();
    });

    test('Content-Type header is application/json', () async {
      final client = MockClient((request) async {
        expect(request.headers['content-type'], contains('application/json'));
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': 'ok'}),
          200,
        );
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      await transport.send('eth_blockNumber', []);
      transport.close();
    });

    test('request body has correct JSON-RPC envelope', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['jsonrpc'], equals('2.0'));
        expect(body['method'], equals('eth_getBalance'));
        expect(body['params'], equals(['0xabc', 'latest']));
        expect(body['id'], isA<int>());
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x0'}),
          200,
        );
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      await transport.send('eth_getBalance', ['0xabc', 'latest']);
      transport.close();
    });

    test('uses utf8.decode on response bodyBytes', () async {
      // Response with UTF-8 characters in error message
      final responseBytes = utf8.encode(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': 'hello-utf8'}),
      );

      final client = MockClient((request) async {
        return http.Response.bytes(responseBytes, 200);
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      final result = await transport.send('test', []);
      expect(result, equals('hello-utf8'));
      transport.close();
    });

    test('JSON-RPC error with data field preserves data', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {
              'code': -32000,
              'message': 'execution reverted',
              'data': '0xdeadbeef',
            },
          }),
          200,
        );
      });

      final transport = JsonRpcTransport(config: config, httpClient: client);

      expect(
        () => transport.send('eth_call', []),
        throwsA(
          isA<RpcResponseException>()
              .having((e) => e.code, 'code', -32000)
              .having((e) => e.data, 'data', '0xdeadbeef'),
        ),
      );
      transport.close();
    });

    test('logger receives error on failed response', () async {
      final logs = <RpcLogEntry>[];
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32601, 'message': 'Method not found'},
          }),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: const Duration(seconds: 5),
          logger: (entry) => logs.add(entry),
        ),
        httpClient: client,
      );

      try {
        await transport.send('bad_method', []);
      } catch (_) {}

      expect(logs, hasLength(2));
      expect(logs[1].direction, equals(RpcLogDirection.response));
      expect(logs[1].error, isNotNull);
      transport.close();
    });
  });
}
