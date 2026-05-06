import 'dart:convert';
import 'dart:io';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _addr = 'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8';
const _baseUrl = 'https://api.trongrid.io';

http.Response _jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...?headers},
  );
}

void main() {
  group('TronGridProvider — construction', () {
    test('throws ArgumentError on non-https baseUrl', () {
      expect(
        () => TronGridProvider(
          baseUrl: 'http://api.trongrid.io',
          httpClient: MockClient((_) async => _jsonResponse({})),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('https'),
          ),
        ),
      );
    });

    test('allowInsecure: true permits http://localhost', () {
      expect(
        () => TronGridProvider(
          baseUrl: 'http://localhost:8090',
          httpClient: MockClient((_) async => _jsonResponse({})),
          allowInsecure: true,
        ),
        returnsNormally,
      );
    });

    test(
      'apiKey propagates as TRON-PRO-API-KEY header on every request',
      () async {
        String? captured;
        final mock = MockClient((req) async {
          captured =
              req.headers['TRON-PRO-API-KEY'] ??
              req.headers['tron-pro-api-key'];
          return _jsonResponse({
            'data': <Map<String, dynamic>>[],
            'meta': <String, dynamic>{},
            'success': true,
          });
        });
        final p = TronGridProvider(
          baseUrl: _baseUrl,
          apiKey: 'SECRET-KEY',
          httpClient: mock,
        );
        await p.listTrxTransactions(_addr);
        expect(captured, 'SECRET-KEY');
        p.close();
      },
    );

    test('keyless mode sends NO TRON-PRO-API-KEY header', () async {
      Map<String, String>? capturedHeaders;
      final mock = MockClient((req) async {
        capturedHeaders = req.headers;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.listTrxTransactions(_addr);
      expect(capturedHeaders, isNotNull);
      expect(
        capturedHeaders!.keys.map((k) => k.toLowerCase()),
        isNot(contains('tron-pro-api-key')),
      );
      p.close();
    });
  });

  group('TronGridProvider — listTrxTransactions', () {
    test('hits /v1/accounts/{addr}/transactions with default limit=20 & '
        'only_confirmed=true', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.listTrxTransactions(_addr);
      expect(captured, isNotNull);
      expect(captured!.host, 'api.trongrid.io');
      expect(captured!.path, '/v1/accounts/$_addr/transactions');
      expect(captured!.queryParameters['limit'], '20');
      expect(captured!.queryParameters['only_confirmed'], 'true');
      p.close();
    });

    test(
      'parses data list as items and meta.fingerprint as TronGridCursor',
      () async {
        final mock = MockClient((_) async {
          return _jsonResponse({
            'data': [
              {'txID': 'abc', 'block_timestamp': 1700000000000},
            ],
            'meta': {'fingerprint': 'FP1', 'page_size': 20},
            'success': true,
          });
        });
        final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
        final page = await p.listTrxTransactions(_addr);
        expect(page.items, hasLength(1));
        expect(page.items.first['txID'], 'abc');
        expect(page.items.first, isA<Map<String, dynamic>>());
        expect(page.nextCursor, isA<TronGridCursor>());
        expect((page.nextCursor as TronGridCursor).fingerprint, 'FP1');
        expect(page.hasMore, isTrue);
        p.close();
      },
    );

    test('missing meta.fingerprint key → page.nextCursor is null', () async {
      final mock = MockClient((_) async {
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      final page = await p.listTrxTransactions(_addr);
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      p.close();
    });

    test('empty meta.fingerprint string → page.nextCursor is null '
        '(defensive)', () async {
      final mock = MockClient((_) async {
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': {'fingerprint': ''},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      final page = await p.listTrxTransactions(_addr);
      expect(page.nextCursor, isNull);
      p.close();
    });

    test('cursor + limit replayed as ?fingerprint=PREV&limit=50', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.listTrxTransactions(
        _addr,
        cursor: TronGridCursor('FP_PREV'),
        limit: 50,
      );
      expect(captured!.queryParameters['fingerprint'], 'FP_PREV');
      expect(captured!.queryParameters['limit'], '50');
      expect(captured!.queryParameters['only_confirmed'], 'true');
      p.close();
    });

    test('limit > 200 → ArgumentError mentioning 1..200', () async {
      final p = TronGridProvider(
        baseUrl: _baseUrl,
        httpClient: MockClient((_) async {
          fail('http should not be hit on validation error');
        }),
      );
      expect(
        () => p.listTrxTransactions(_addr, limit: 201),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('1..200'),
          ),
        ),
      );
      p.close();
    });

    test('limit < 1 → ArgumentError', () async {
      final p = TronGridProvider(
        baseUrl: _baseUrl,
        httpClient: MockClient((_) async {
          fail('http should not be hit on validation error');
        }),
      );
      expect(
        () => p.listTrxTransactions(_addr, limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      p.close();
    });

    test(
      'includeUnconfirmed: true → URL has only_confirmed=false (explicit)',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return _jsonResponse({
            'data': <Map<String, dynamic>>[],
            'meta': <String, dynamic>{},
            'success': true,
          });
        });
        final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
        await p.listTrxTransactions(_addr, includeUnconfirmed: true);
        expect(captured!.queryParameters['only_confirmed'], 'false');
        p.close();
      },
    );

    test(
      'defaultOnlyConfirmed=false → URL has only_confirmed=false by default',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return _jsonResponse({
            'data': <Map<String, dynamic>>[],
            'meta': <String, dynamic>{},
            'success': true,
          });
        });
        final p = TronGridProvider(
          baseUrl: _baseUrl,
          httpClient: mock,
          defaultOnlyConfirmed: false,
        );
        await p.listTrxTransactions(_addr);
        expect(captured!.queryParameters['only_confirmed'], 'false');
        p.close();
      },
    );

    test('min/max_timestamp serialized as ms-since-epoch', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      final tMin = DateTime.fromMillisecondsSinceEpoch(
        1700000000000,
        isUtc: true,
      );
      final tMax = DateTime.fromMillisecondsSinceEpoch(
        1700000999000,
        isUtc: true,
      );
      await p.listTrxTransactions(
        _addr,
        minTimestamp: tMin,
        maxTimestamp: tMax,
      );
      expect(captured!.queryParameters['min_timestamp'], '1700000000000');
      expect(captured!.queryParameters['max_timestamp'], '1700000999000');
      p.close();
    });
  });

  group('TronGridProvider — listTrc20Transfers', () {
    test('hits /v1/accounts/{addr}/transactions/trc20', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.listTrc20Transfers(_addr);
      expect(captured!.path, '/v1/accounts/$_addr/transactions/trc20');
      p.close();
    });

    test('fingerprint reused across endpoints does not raise — provider does '
        'NOT enforce per-endpoint fingerprint discipline at runtime', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        if (req.url.path.endsWith('/transactions')) {
          return _jsonResponse({
            'data': <Map<String, dynamic>>[],
            'meta': {'fingerprint': 'FP_FROM_TRX'},
            'success': true,
          });
        }
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      final trxPage = await p.listTrxTransactions(_addr);
      final cursor = trxPage.nextCursor as TronGridCursor;
      // Reusing TRX cursor against TRC-20 endpoint must not throw — caller
      // discipline issue, surfaced via dartdoc only (PITFALLS.md C-02 echo).
      await p.listTrc20Transfers(_addr, cursor: cursor);
      expect(captured!.path, '/v1/accounts/$_addr/transactions/trc20');
      expect(captured!.queryParameters['fingerprint'], 'FP_FROM_TRX');
      p.close();
    });
  });

  group('TronGridProvider — wrong-chain cursor', () {
    test(
      'SolanaCursor → InvalidCursorException with "expected TronGridCursor"',
      () async {
        final p = TronGridProvider(
          baseUrl: _baseUrl,
          httpClient: MockClient((_) async {
            fail('http should not be hit on cursor mismatch');
          }),
        );
        await expectLater(
          () => p.listTrxTransactions(_addr, cursor: SolanaCursor('sig1')),
          throwsA(
            isA<InvalidCursorException>().having(
              (e) => e.message,
              'message',
              contains('expected TronGridCursor'),
            ),
          ),
        );
        p.close();
      },
    );

    test('SolanaCursor on TRC-20 endpoint also rejected', () async {
      final p = TronGridProvider(
        baseUrl: _baseUrl,
        httpClient: MockClient((_) async {
          fail('http should not be hit on cursor mismatch');
        }),
      );
      await expectLater(
        () => p.listTrc20Transfers(_addr, cursor: SolanaCursor('sig1')),
        throwsA(isA<InvalidCursorException>()),
      );
      p.close();
    });
  });

  group('TronGridProvider — error envelopes', () {
    test('HTTP 200 with success=false → TxHistoryApiException(-2002) carrying '
        'upstream error message', () async {
      final mock = MockClient((_) async {
        return _jsonResponse({'success': false, 'error': 'Address not valid'});
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await expectLater(
        () => p.listTrxTransactions(_addr),
        throwsA(
          isA<TxHistoryApiException>()
              .having((e) => e.code, 'code', -2002)
              .having(
                (e) => e.message,
                'message',
                contains('Address not valid'),
              ),
        ),
      );
      p.close();
    });

    test('HTTP 401 → propagates RpcHttpException via EndpointPool', () async {
      final mock = MockClient((_) async {
        return http.Response('unauthorized', 401);
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await expectLater(
        () => p.listTrxTransactions(_addr),
        throwsA(
          isA<RpcHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      p.close();
    });

    test('HTTP 429 with single endpoint → TxHistoryApiException(-2002, "all '
        'endpoints exhausted")', () async {
      final mock = MockClient((_) async {
        return http.Response(
          'rate limited',
          429,
          headers: {'retry-after': '3'},
        );
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await expectLater(
        () => p.listTrxTransactions(_addr),
        throwsA(
          isA<TxHistoryApiException>()
              .having((e) => e.code, 'code', -2002)
              .having(
                (e) => e.message,
                'message',
                contains('all endpoints exhausted'),
              ),
        ),
      );
      p.close();
    });

    test('200 OK with non-Map body → TxHistoryApiException(-2002)', () async {
      final mock = MockClient((_) async {
        return _jsonResponse([1, 2, 3]);
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await expectLater(
        () => p.listTrxTransactions(_addr),
        throwsA(
          isA<TxHistoryApiException>().having((e) => e.code, 'code', -2002),
        ),
      );
      p.close();
    });

    test(
      '200 OK Map missing "data" array → TxHistoryApiException(-2002)',
      () async {
        final mock = MockClient((_) async {
          return _jsonResponse({'meta': <String, dynamic>{}, 'success': true});
        });
        final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
        await expectLater(
          () => p.listTrxTransactions(_addr),
          throwsA(
            isA<TxHistoryApiException>()
                .having((e) => e.code, 'code', -2002)
                .having((e) => e.message, 'message', contains('data')),
          ),
        );
        p.close();
      },
    );
  });

  group('TronGridProvider — TxHistoryProvider interface', () {
    test('listTransactions delegates to listTrxTransactions', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.listTransactions(TxHistoryQuery(address: _addr, limit: 25));
      expect(captured!.path, '/v1/accounts/$_addr/transactions');
      expect(captured!.queryParameters['limit'], '25');
      p.close();
    });

    test('list() convenience hits /transactions (TRX) endpoint', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _jsonResponse({
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
          'success': true,
        });
      });
      final p = TronGridProvider(baseUrl: _baseUrl, httpClient: mock);
      await p.list(address: _addr);
      expect(captured!.path, '/v1/accounts/$_addr/transactions');
      p.close();
    });
  });

  group('TronGridProvider — close()', () {
    test('close() is idempotent (HIST-OPS-03)', () {
      final p = TronGridProvider(
        baseUrl: _baseUrl,
        httpClient: MockClient((_) async => _jsonResponse({})),
      );
      expect(() => p.close(), returnsNormally);
      expect(() => p.close(), returnsNormally);
    });
  });

  group('TronGridProvider — structural firewall (PITFALLS.md C-08)', () {
    // Source-file lint to make the `/v1/* vs /wallet/*` separation a
    // CI-enforceable invariant (T-11-29 mitigation). If a future contributor
    // bolts /wallet/* onto TronGridProvider — or pulls TronHttpClient into
    // its dependency closure — these tests fail loudly.
    final source = File(
      'lib/src/tx_history/tron/trongrid_provider.dart',
    ).readAsStringSync();

    test(
      'source does NOT import TronHttpClient (composition over inheritance)',
      () {
        expect(
          source.contains('tron_http_client'),
          isFalse,
          reason: 'TronGridProvider must remain firewalled from TronHttpClient',
        );
        expect(
          source.contains("'../../tron/"),
          isFalse,
          reason: 'No imports from lib/src/tron/* allowed',
        );
      },
    );

    test('source does NOT touch /wallet/* paths (TronGrid is /v1/* only)', () {
      expect(
        source.contains('/wallet/'),
        isFalse,
        reason: 'TronGridProvider hits /v1/accounts/* only — never /wallet/*',
      );
    });
  });
}
