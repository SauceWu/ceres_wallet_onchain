/// Shared 429-retry contract tests for v1.0 transports.
///
/// Validates that both [JsonRpcTransport] and [RestTransport] retry on
/// HTTP 429 (Too Many Requests) in addition to 5xx, honor the
/// `Retry-After` response header (capped at 30s to guard against malicious
/// servers stalling clients), and preserve all existing retry semantics
/// for 5xx, timeouts, and other 4xx codes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRpcTransport - HTTP 429 retry', () {
    late RpcClientConfig fastConfig;

    setUp(() {
      fastConfig = const RpcClientConfig(
        baseUrl: 'https://rpc.example.com',
        timeout: Duration(seconds: 5),
        maxRetries: 2,
        retryBaseDelay: Duration(milliseconds: 50),
      );
    });

    test('429 once then 200 retries successfully', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) return http.Response('Rate limited', 429);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x1'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: fastConfig,
        httpClient: client,
      );
      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x1'));
      expect(callCount, equals(2));
      transport.close();
    });

    test(
      '429 forever rethrows RpcHttpException(statusCode: 429) after maxRetries',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          return http.Response('Rate limited', 429);
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

        try {
          await transport.send('eth_blockNumber', []);
          fail('should have thrown RpcHttpException');
        } on RpcHttpException catch (e) {
          expect(e.statusCode, equals(429));
        }
        // initial attempt + 1 retry = 2 calls
        expect(callCount, equals(2));
        transport.close();
      },
    );

    test('429 with Retry-After: 1 honors header (delay >= 900ms)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            'Rate limited',
            429,
            headers: {'retry-after': '1'},
          );
        }
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x2'}),
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

      final stopwatch = Stopwatch()..start();
      final result = await transport.send('eth_blockNumber', []);
      stopwatch.stop();
      expect(result, equals('0x2'));
      expect(callCount, equals(2));
      // Honored Retry-After: 1 → at least ~900ms delay (1s minus tolerance)
      expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(900));
      // Never exceeds the 30s cap, and far below it for this case
      expect(stopwatch.elapsed.inSeconds, lessThan(5));
      transport.close();
    });

    test('429 with Retry-After: 100 caps retryAfter at 30s', () async {
      final client = MockClient((request) async {
        return http.Response(
          'Rate limited',
          429,
          headers: {'retry-after': '100'},
        );
      });

      final transport = JsonRpcTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://rpc.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 0,
        ),
        httpClient: client,
      );

      try {
        await transport.send('eth_blockNumber', []);
        fail('should have thrown RpcHttpException');
      } on RpcHttpException catch (e) {
        expect(e.statusCode, equals(429));
        // Cap: 100s server value → 30s effective (anti-DoS guard)
        expect(e.retryAfter, equals(const Duration(seconds: 30)));
      }
      transport.close();
    });

    test(
      '429 with malformed Retry-After falls back to exponential backoff',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              'Rate limited',
              429,
              headers: {'retry-after': 'not-a-number'},
            );
          }
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x3'}),
            200,
          );
        });

        final transport = JsonRpcTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://rpc.example.com',
            timeout: Duration(seconds: 5),
            maxRetries: 1,
            retryBaseDelay: Duration(milliseconds: 50),
          ),
          httpClient: client,
        );

        final stopwatch = Stopwatch()..start();
        final result = await transport.send('eth_blockNumber', []);
        stopwatch.stop();
        expect(result, equals('0x3'));
        expect(callCount, equals(2));
        // Falls through to exponential _backoff (~50ms), not 1s+ Retry-After delay
        expect(stopwatch.elapsed.inMilliseconds, lessThan(500));
        transport.close();
      },
    );

    test('500 still retries (regression)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) return http.Response('Server Error', 500);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x4'}),
          200,
        );
      });

      final transport = JsonRpcTransport(
        config: fastConfig,
        httpClient: client,
      );
      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x4'));
      expect(callCount, equals(2));
      transport.close();
    });

    test('timeout still retries (regression)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x5'}),
          200,
        );
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

      final result = await transport.send('eth_blockNumber', []);
      expect(result, equals('0x5'));
      expect(callCount, equals(2));
      transport.close();
    });

    test('4xx other than 429 (401) does NOT retry', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('Unauthorized', 401);
      });

      final transport = JsonRpcTransport(
        config: fastConfig,
        httpClient: client,
      );

      try {
        await transport.send('eth_blockNumber', []);
        fail('should have thrown RpcHttpException');
      } on RpcHttpException catch (e) {
        expect(e.statusCode, equals(401));
      }
      expect(callCount, equals(1));
      transport.close();
    });
  });

  group('RestTransport - HTTP 429 retry', () {
    late RpcClientConfig fastConfig;

    setUp(() {
      fastConfig = const RpcClientConfig(
        baseUrl: 'https://api.example.com',
        timeout: Duration(seconds: 5),
        maxRetries: 2,
        retryBaseDelay: Duration(milliseconds: 50),
      );
    });

    test('429 once then 200 retries successfully (POST)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) return http.Response('Rate limited', 429);
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(config: fastConfig, httpClient: client);
      final result = await transport.post('/api/v1', {'foo': 'bar'});
      expect(result, equals({'ok': true}));
      expect(callCount, equals(2));
      transport.close();
    });

    test(
      '429 forever rethrows RpcHttpException(statusCode: 429) (POST)',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          return http.Response('Rate limited', 429);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.example.com',
            timeout: Duration(seconds: 5),
            maxRetries: 1,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          httpClient: client,
        );

        try {
          await transport.post('/api/v1', {});
          fail('should have thrown RpcHttpException');
        } on RpcHttpException catch (e) {
          expect(e.statusCode, equals(429));
        }
        expect(callCount, equals(2));
        transport.close();
      },
    );

    test(
      '429 with Retry-After: 1 honors header (POST, delay >= 900ms)',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              'Rate limited',
              429,
              headers: {'retry-after': '1'},
            );
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.example.com',
            timeout: Duration(seconds: 5),
            maxRetries: 1,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          httpClient: client,
        );

        final stopwatch = Stopwatch()..start();
        final result = await transport.post('/api/v1', {});
        stopwatch.stop();
        expect(result, equals({'ok': true}));
        expect(callCount, equals(2));
        expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(900));
        expect(stopwatch.elapsed.inSeconds, lessThan(5));
        transport.close();
      },
    );

    test('429 with Retry-After: 100 caps retryAfter at 30s (POST)', () async {
      final client = MockClient((request) async {
        return http.Response(
          'Rate limited',
          429,
          headers: {'retry-after': '100'},
        );
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 0,
        ),
        httpClient: client,
      );

      try {
        await transport.post('/api/v1', {});
        fail('should have thrown RpcHttpException');
      } on RpcHttpException catch (e) {
        expect(e.statusCode, equals(429));
        expect(e.retryAfter, equals(const Duration(seconds: 30)));
      }
      transport.close();
    });

    test(
      '429 with malformed Retry-After falls back to exponential backoff (POST)',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              'Rate limited',
              429,
              headers: {'retry-after': 'not-a-number'},
            );
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final transport = RestTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.example.com',
            timeout: Duration(seconds: 5),
            maxRetries: 1,
            retryBaseDelay: Duration(milliseconds: 50),
          ),
          httpClient: client,
        );

        final stopwatch = Stopwatch()..start();
        await transport.post('/api/v1', {});
        stopwatch.stop();
        expect(callCount, equals(2));
        expect(stopwatch.elapsed.inMilliseconds, lessThan(500));
        transport.close();
      },
    );

    test('500 still retries (regression, POST)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) return http.Response('Server Error', 500);
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(config: fastConfig, httpClient: client);
      final result = await transport.post('/api/v1', {});
      expect(result, equals({'ok': true}));
      expect(callCount, equals(2));
      transport.close();
    });

    test('GET also retries on 429 (covers _doGet path)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        expect(request.method, equals('GET'));
        if (callCount == 1) {
          return http.Response(
            'Rate limited',
            429,
            headers: {'retry-after': '0'},
          );
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final transport = RestTransport(
        config: const RpcClientConfig(
          baseUrl: 'https://api.example.com',
          timeout: Duration(seconds: 5),
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
        httpClient: client,
      );

      final result = await transport.get('/api/v1');
      expect(result, equals({'ok': true}));
      expect(callCount, equals(2));
      transport.close();
    });

    test('4xx other than 429 (404) does NOT retry (POST)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('Not Found', 404);
      });

      final transport = RestTransport(config: fastConfig, httpClient: client);

      try {
        await transport.post('/api/v1', {});
        fail('should have thrown RpcHttpException');
      } on RpcHttpException catch (e) {
        expect(e.statusCode, equals(404));
      }
      expect(callCount, equals(1));
      transport.close();
    });
  });
}
