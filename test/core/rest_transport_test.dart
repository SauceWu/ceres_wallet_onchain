import 'dart:async';
import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RestTransport', () {
    late RpcClientConfig config;

    setUp(() {
      config = const RpcClientConfig(
        baseUrl: 'https://api.trongrid.io',
        timeout: Duration(seconds: 5),
      );
    });

    test('successful POST returns response map', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'balance': 1000}), 200);
      });

      final transport = RestTransport(config: config, httpClient: client);

      final result = await transport.post('/wallet/getaccount', {
        'address': 'T1234',
      });
      expect(result, equals({'balance': 1000}));
      transport.close();
    });

    test('HTTP 404 throws RpcHttpException', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final transport = RestTransport(config: config, httpClient: client);

      expect(
        () => transport.post('/wallet/getaccount', {'address': 'T1234'}),
        throwsA(
          isA<RpcHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
      transport.close();
    });

    test('HTTP 500 throws RpcHttpException', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final transport = RestTransport(config: config, httpClient: client);

      expect(
        () => transport.post('/wallet/getaccount', {}),
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

    test('timeout throws RpcTimeoutException', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 10));
        return http.Response('{}', 200);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: Duration(milliseconds: 100),
        ),
        httpClient: client,
      );

      expect(
        () => transport.post('/wallet/getaccount', {}),
        throwsA(isA<RpcTimeoutException>()),
      );
      transport.close();
    });

    test('empty body POST works correctly', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, isEmpty);
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(config: config, httpClient: client);

      final result = await transport.post('/wallet/getnowblock');
      expect(result, equals({'ok': true}));
      transport.close();
    });

    test('logger receives request and response entries', () async {
      final logs = <RpcLogEntry>[];
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'balance': 500}), 200);
      });

      final transport = RestTransport(
        config: RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: const Duration(seconds: 5),
          logger: (entry) => logs.add(entry),
        ),
        httpClient: client,
      );

      await transport.post('/wallet/getaccount', {'address': 'T1234'});

      expect(logs, hasLength(2));
      expect(logs[0].direction, equals(RpcLogDirection.request));
      expect(logs[0].method, equals('/wallet/getaccount'));
      expect(logs[1].direction, equals(RpcLogDirection.response));
      expect(logs[1].result, isNotNull);
      expect(logs[1].duration, isNotNull);
      transport.close();
    });

    test('extraHeaders are included in request', () async {
      final client = MockClient((request) async {
        expect(request.headers['TRON-PRO-API-KEY'], equals('my-key'));
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: Duration(seconds: 5),
          extraHeaders: {'TRON-PRO-API-KEY': 'my-key'},
        ),
        httpClient: client,
      );

      await transport.post('/wallet/getaccount', {});
      transport.close();
    });

    test('Content-Type header is application/json', () async {
      final client = MockClient((request) async {
        expect(request.headers['content-type'], contains('application/json'));
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(config: config, httpClient: client);

      await transport.post('/wallet/getaccount', {});
      transport.close();
    });

    test('URL is correctly concatenated', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://api.trongrid.io/wallet/getaccount'),
        );
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(config: config, httpClient: client);

      await transport.post('/wallet/getaccount', {});
      transport.close();
    });

    test('uses utf8.decode on response bodyBytes', () async {
      final responseBytes = utf8.encode(jsonEncode({'msg': 'hello-utf8'}));
      final client = MockClient((request) async {
        return http.Response.bytes(responseBytes, 200);
      });

      final transport = RestTransport(config: config, httpClient: client);

      final result = await transport.post('/test', {});
      expect(result['msg'], equals('hello-utf8'));
      transport.close();
    });

    test('retry on timeout succeeds on second attempt', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('{}', 200);
        }
        return http.Response(jsonEncode({'retried': true}), 200);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: Duration(milliseconds: 100),
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      final result = await transport.post('/wallet/getaccount', {});
      expect(result, equals({'retried': true}));
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
        return http.Response(jsonEncode({'retried': true}), 200);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: Duration(seconds: 5),
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      final result = await transport.post('/wallet/getaccount', {});
      expect(result, equals({'retried': true}));
      expect(callCount, equals(2));
      transport.close();
    });

    test('4xx errors are not retried', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('Bad Request', 400);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.trongrid.io',
          timeout: Duration(seconds: 5),
          maxRetries: 2,
        ),
        httpClient: client,
      );

      try {
        await transport.post('/wallet/getaccount', {});
      } catch (_) {}
      expect(callCount, equals(1));
      transport.close();
    });

    group('GET method', () {
      test('successful GET returns response map', () async {
        final client = MockClient((request) async {
          expect(request.method, equals('GET'));
          return http.Response(
            jsonEncode({'blockID': 'abc123', 'block_header': {}}),
            200,
          );
        });

        final transport = RestTransport(config: config, httpClient: client);

        final result = await transport.get('/wallet/getnowblock');
        expect(result, equals({'blockID': 'abc123', 'block_header': {}}));
        transport.close();
      });

      test('GET does not send Content-Type header', () async {
        final client = MockClient((request) async {
          expect(request.method, equals('GET'));
          // GET requests should not have Content-Type set by our code
          expect(request.headers['content-type'], isNull);
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final transport = RestTransport(config: config, httpClient: client);

        await transport.get('/wallet/getnowblock');
        transport.close();
      });

      test('GET includes extraHeaders', () async {
        final client = MockClient((request) async {
          expect(request.headers['TRON-PRO-API-KEY'], equals('my-key'));
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.trongrid.io',
            timeout: Duration(seconds: 5),
            extraHeaders: {'TRON-PRO-API-KEY': 'my-key'},
          ),
          httpClient: client,
        );

        await transport.get('/wallet/getnowblock');
        transport.close();
      });

      test('GET timeout throws RpcTimeoutException', () async {
        final client = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('{}', 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.trongrid.io',
            timeout: Duration(milliseconds: 100),
          ),
          httpClient: client,
        );

        expect(
          () => transport.get('/wallet/getnowblock'),
          throwsA(isA<RpcTimeoutException>()),
        );
        transport.close();
      });

      test('GET HTTP 404 throws RpcHttpException', () async {
        final client = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final transport = RestTransport(config: config, httpClient: client);

        expect(
          () => transport.get('/wallet/getnowblock'),
          throwsA(
            isA<RpcHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
        transport.close();
      });

      test('GET HTTP 500 throws RpcHttpException', () async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final transport = RestTransport(config: config, httpClient: client);

        expect(
          () => transport.get('/wallet/getnowblock'),
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

      test('GET retry on timeout succeeds on second attempt', () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            await Future.delayed(const Duration(seconds: 10));
            return http.Response('{}', 200);
          }
          return http.Response(jsonEncode({'retried': true}), 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.trongrid.io',
            timeout: Duration(milliseconds: 100),
            maxRetries: 1,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          httpClient: client,
        );

        final result = await transport.get('/wallet/getnowblock');
        expect(result, equals({'retried': true}));
        expect(callCount, equals(2));
        transport.close();
      });

      test('GET logger receives request and response entries', () async {
        final logs = <RpcLogEntry>[];
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'balance': 500}), 200);
        });

        final transport = RestTransport(
          config: RpcClientConfig(
            baseUrl: 'https://api.trongrid.io',
            timeout: const Duration(seconds: 5),
            logger: (entry) => logs.add(entry),
          ),
          httpClient: client,
        );

        await transport.get('/wallet/getnowblock');

        expect(logs, hasLength(2));
        expect(logs[0].direction, equals(RpcLogDirection.request));
        expect(logs[0].method, equals('/wallet/getnowblock'));
        expect(logs[1].direction, equals(RpcLogDirection.response));
        expect(logs[1].result, isNotNull);
        expect(logs[1].duration, isNotNull);
        transport.close();
      });
    });

    group('getList method', () {
      test('successful getList returns response list', () async {
        final client = MockClient((request) async {
          expect(request.method, equals('GET'));
          return http.Response(
            jsonEncode([
              {'address': 'node1'},
              {'address': 'node2'},
            ]),
            200,
          );
        });

        final transport = RestTransport(config: config, httpClient: client);

        final result = await transport.getList('/wallet/listnodes');
        expect(result, hasLength(2));
        expect(result[0], equals({'address': 'node1'}));
        transport.close();
      });

      test('getList timeout throws RpcTimeoutException', () async {
        final client = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('[]', 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.trongrid.io',
            timeout: Duration(milliseconds: 100),
          ),
          httpClient: client,
        );

        expect(
          () => transport.getList('/wallet/listnodes'),
          throwsA(isA<RpcTimeoutException>()),
        );
        transport.close();
      });

      test('getList HTTP error throws RpcHttpException', () async {
        final client = MockClient((request) async {
          return http.Response('Bad Gateway', 502);
        });

        final transport = RestTransport(config: config, httpClient: client);

        expect(
          () => transport.getList('/wallet/listnodes'),
          throwsA(
            isA<RpcHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              502,
            ),
          ),
        );
        transport.close();
      });
    });
  });
}
