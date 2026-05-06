import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _addr = '0x742d35Cc6634C0532925a3b844Bc9e7595f0BEb1';

void main() {
  group('EvmBlockscoutProvider — construction', () {
    test('throws ArgumentError on non-https baseUrl', () {
      expect(
        () => EvmBlockscoutProvider(
          baseUrls: const ['http://eth.example'],
          httpClient: MockClient((_) async => http.Response('', 200)),
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
        () => EvmBlockscoutProvider(
          baseUrls: const ['http://localhost:4000'],
          httpClient: MockClient((_) async => http.Response('', 200)),
          allowInsecure: true,
        ),
        returnsNormally,
      );
    });
  });

  group('EvmBlockscoutProvider — listNativeTransactions', () {
    test(
      'hits /api/v2/addresses/{addr}/transactions on first endpoint',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode({
              'items': <Map<String, dynamic>>[],
              'next_page_params': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.blockscout.com'],
          httpClient: mock,
        );
        await p.listNativeTransactions(_addr);
        expect(captured, isNotNull);
        expect(captured!.host, 'eth.blockscout.com');
        expect(captured!.path, '/api/v2/addresses/$_addr/transactions');
        p.close();
      },
    );

    test('parses items list as Map<String, dynamic> and BlockscoutCursor from '
        'next_page_params', () async {
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'hash': '0xaaa', 'value': '1000'},
              {'hash': '0xbbb', 'value': '2000'},
            ],
            'next_page_params': {'block_number': '123', 'index': '4'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      final page = await p.listNativeTransactions(_addr);
      expect(page.items, hasLength(2));
      expect(page.items.first['hash'], '0xaaa');
      expect(page.items.first, isA<Map<String, dynamic>>());
      expect(page.nextCursor, isA<BlockscoutCursor>());
      final cursor = page.nextCursor as BlockscoutCursor;
      expect(cursor.nextPageParams, {'block_number': '123', 'index': '4'});
      expect(page.hasMore, isTrue);
      p.close();
    });

    test('replays cursor verbatim as URL query params', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.listNativeTransactions(
        _addr,
        cursor: const BlockscoutCursor({'block_number': '123', 'index': '4'}),
      );
      expect(captured!.queryParameters['block_number'], '123');
      expect(captured!.queryParameters['index'], '4');
      p.close();
    });

    test('wrong-chain cursor → InvalidCursorException', () async {
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: MockClient((_) async {
          fail('http should not be hit on cursor mismatch');
        }),
      );
      await expectLater(
        () => p.listNativeTransactions(_addr, cursor: SolanaCursor('sig1')),
        throwsA(
          isA<InvalidCursorException>().having(
            (e) => e.message,
            'message',
            contains('expected BlockscoutCursor'),
          ),
        ),
      );
      p.close();
    });

    test(
      'next_page_params: null → page.nextCursor is null and hasMore false',
      () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode({
              'items': [
                {'hash': '0xc'},
              ],
              'next_page_params': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.example'],
          httpClient: mock,
        );
        final page = await p.listNativeTransactions(_addr);
        expect(page.nextCursor, isNull);
        expect(page.hasMore, isFalse);
        p.close();
      },
    );

    test('limit forwarded as ?limit=N', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.listNativeTransactions(_addr, limit: 100);
      expect(captured!.queryParameters['limit'], '100');
      p.close();
    });
  });

  group('EvmBlockscoutProvider — listTokenTransfers', () {
    test('type=ERC-20 forwarded as ?type=ERC-20', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.listTokenTransfers(_addr, type: 'ERC-20');
      expect(captured!.path, '/api/v2/addresses/$_addr/token-transfers');
      expect(captured!.queryParameters['type'], 'ERC-20');
      p.close();
    });

    test('type=null sends no type filter (returns all token types)', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.listTokenTransfers(_addr);
      expect(captured!.path, '/api/v2/addresses/$_addr/token-transfers');
      expect(captured!.queryParameters.containsKey('type'), isFalse);
      p.close();
    });

    test('type=INVALID → ArgumentError mentioning ERC-20/721/1155', () async {
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: MockClient((_) async {
          fail('http should not be hit on validation error');
        }),
      );
      expect(
        () => p.listTokenTransfers(_addr, type: 'INVALID'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('ERC-20'),
              contains('ERC-721'),
              contains('ERC-1155'),
            ),
          ),
        ),
      );
      p.close();
    });

    test('all three valid types accepted: ERC-20, ERC-721, ERC-1155', () async {
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      for (final type in ['ERC-20', 'ERC-721', 'ERC-1155']) {
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.example'],
          httpClient: mock,
        );
        // Should not throw.
        await p.listTokenTransfers(_addr, type: type);
        p.close();
      }
    });
  });

  group('EvmBlockscoutProvider — multi-endpoint failover', () {
    test(
      '503 from first → 200 from second succeeds via EndpointPool walk',
      () async {
        var aHits = 0;
        var bHits = 0;
        final mock = MockClient((req) async {
          if (req.url.host == 'a.example') {
            aHits++;
            return http.Response('down', 503);
          }
          bHits++;
          return http.Response(
            jsonEncode({
              'items': [
                {'hash': '0xok'},
              ],
              'next_page_params': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://a.example', 'https://b.example'],
          httpClient: mock,
        );
        final page = await p.listNativeTransactions(_addr);
        expect(page.items, hasLength(1));
        expect(page.items.first['hash'], '0xok');
        expect(aHits, 1);
        expect(bHits, 1);
        p.close();
      },
    );

    test('429 from all endpoints → TxHistoryApiException(-2002, "all '
        'endpoints exhausted")', () async {
      final mock = MockClient((req) async {
        return http.Response(
          'rate limited',
          429,
          headers: {'retry-after': '2'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://a.example', 'https://b.example'],
        httpClient: mock,
      );
      await expectLater(
        () => p.listNativeTransactions(_addr),
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
  });

  group('EvmBlockscoutProvider — error envelopes', () {
    test(
      'HTTP 400 with {"message": "..."} body → propagates as RpcHttpException',
      () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode({'message': 'Invalid address format'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        });
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.example'],
          httpClient: mock,
        );
        await expectLater(
          () => p.listNativeTransactions(_addr),
          throwsA(
            isA<Object>().having(
              (e) {
                if (e is RpcException) return e.message;
                return e.toString();
              },
              'message contains upstream error',
              contains('Invalid address format'),
            ),
          ),
        );
        p.close();
      },
    );

    test('200 OK with non-Map response → TxHistoryApiException(-2002)', () async {
      final mock = MockClient((req) async {
        // Return a JSON array — Blockscout v2 uses { items, next_page_params },
        // never a top-level array. The provider must surface this as a typed
        // error rather than crashing on a cast.
        return http.Response(
          jsonEncode([1, 2, 3]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await expectLater(
        () => p.listNativeTransactions(_addr),
        throwsA(
          isA<TxHistoryApiException>().having((e) => e.code, 'code', -2002),
        ),
      );
      p.close();
    });

    test(
      '200 OK with missing "items" array → TxHistoryApiException(-2002)',
      () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode({'data': []}), // no "items" key
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final p = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.example'],
          httpClient: mock,
        );
        await expectLater(
          () => p.listNativeTransactions(_addr),
          throwsA(
            isA<TxHistoryApiException>()
                .having((e) => e.code, 'code', -2002)
                .having((e) => e.message, 'message', contains('items')),
          ),
        );
        p.close();
      },
    );
  });

  group('EvmBlockscoutProvider — TxHistoryProvider interface', () {
    test('listTransactions delegates to listNativeTransactions', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.listTransactions(TxHistoryQuery(address: _addr, limit: 25));
      expect(captured!.path, '/api/v2/addresses/$_addr/transactions');
      expect(captured!.queryParameters['limit'], '25');
      p.close();
    });

    test('list() convenience hits /transactions endpoint', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'items': [], 'next_page_params': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: mock,
      );
      await p.list(address: _addr);
      expect(captured!.path, '/api/v2/addresses/$_addr/transactions');
      p.close();
    });
  });

  group('EvmBlockscoutProvider — close()', () {
    test('close() does not throw when called multiple times', () {
      final p = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.example'],
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(() => p.close(), returnsNormally);
      // Idempotent per HIST-OPS-03.
      expect(() => p.close(), returnsNormally);
    });
  });
}
