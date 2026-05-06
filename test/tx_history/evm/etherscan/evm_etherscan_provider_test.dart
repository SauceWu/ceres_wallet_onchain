import 'dart:convert';

import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _addr = '0x742d35Cc6634C0532925a3b844Bc9e7595f0BEb1';
const _key = 'TESTKEY_DO_NOT_LEAK_ME';

http.Response _json(Map<String, dynamic> body, {int code = 200}) =>
    http.Response(
      jsonEncode(body),
      code,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('EvmEtherscanProvider — construction', () {
    test('throws ArgumentError on non-https baseUrl', () {
      expect(
        () => EvmEtherscanProvider(
          baseUrl: 'http://api.etherscan.io',
          apiKey: _key,
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
        () => EvmEtherscanProvider(
          baseUrl: 'http://localhost:4000',
          httpClient: MockClient((_) async => http.Response('', 200)),
          allowInsecure: true,
        ),
        returnsNormally,
      );
    });

    test('v1 mode: chainId=null omits chainid query param', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      await p.listNativeTransactions(_addr);
      expect(captured!.host, 'api.etherscan.io');
      expect(captured!.path, '/api');
      expect(captured!.queryParameters.containsKey('chainid'), isFalse);
      expect(captured!.queryParameters['module'], 'account');
      expect(captured!.queryParameters['action'], 'txlist');
      expect(captured!.queryParameters['apikey'], _key);
      p.close();
    });

    test('v2 multichain mode: chainId set forwards as chainid param', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io/v2',
        chainId: 1,
        apiKey: _key,
        httpClient: mock,
      );
      await p.listNativeTransactions(_addr);
      expect(captured!.host, 'api.etherscan.io');
      expect(captured!.path, '/v2/api');
      expect(captured!.queryParameters['chainid'], '1');
      expect(captured!.queryParameters['module'], 'account');
      expect(captured!.queryParameters['action'], 'txlist');
      expect(captured!.queryParameters['apikey'], _key);
      p.close();
    });

    test('keyless mode: apiKey=null omits apikey query param', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        httpClient: mock,
      );
      await p.listNativeTransactions(_addr);
      expect(captured!.queryParameters.containsKey('apikey'), isFalse);
      p.close();
    });
  });

  group('EvmEtherscanProvider — listNativeTransactions', () {
    test(
      'emits module=account&action=txlist with default page/offset/sort',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return _json({
            'status': '1',
            'message': 'OK',
            'result': <Map<String, dynamic>>[],
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        await p.listNativeTransactions(_addr);
        expect(captured!.queryParameters['module'], 'account');
        expect(captured!.queryParameters['action'], 'txlist');
        expect(captured!.queryParameters['address'], _addr);
        expect(captured!.queryParameters['page'], '1');
        expect(captured!.queryParameters['offset'], '50');
        expect(captured!.queryParameters['sort'], 'asc');
        p.close();
      },
    );

    test(
      'status=1 + full-page result → nextCursor advances to EtherscanCursor(page+1)',
      () async {
        final mock = MockClient((req) async {
          return _json({
            'status': '1',
            'message': 'OK',
            'result': [
              {'hash': '0xa', 'value': '1'},
              {'hash': '0xb', 'value': '2'},
            ],
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        // Use limit=2 so the 2-item response fills the page exactly.
        final page = await p.listNativeTransactions(_addr, limit: 2);
        expect(page.items, hasLength(2));
        expect(page.items.first['hash'], '0xa');
        expect(page.items.first, isA<Map<String, dynamic>>());
        expect(page.nextCursor, isA<EtherscanCursor>());
        final c = page.nextCursor as EtherscanCursor;
        expect(c.page, 2);
        expect(c.offset, 2);
        expect(page.hasMore, isTrue);
        p.close();
      },
    );

    test('status=1 + partial-page result → nextCursor is null', () async {
      final mock = MockClient((req) async {
        return _json({
          'status': '1',
          'message': 'OK',
          'result': [
            {'hash': '0xa'},
          ],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      // Default offset=50 but only 1 item returned → exhausted.
      final page = await p.listNativeTransactions(_addr);
      expect(page.items, hasLength(1));
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      p.close();
    });

    test(
      'status=0 + "No transactions found" → empty success (no exception)',
      () async {
        final mock = MockClient((req) async {
          return _json({
            'status': '0',
            'message': 'No transactions found',
            'result': '',
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        final page = await p.listNativeTransactions(_addr);
        expect(page.items, isEmpty);
        expect(page.nextCursor, isNull);
        p.close();
      },
    );

    test(
      'status=0 + "No records found" (Blockscout-compat variant) → empty success',
      () async {
        final mock = MockClient((req) async {
          return _json({
            'status': '0',
            'message': 'No records found',
            'result': '',
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        final page = await p.listNativeTransactions(_addr);
        expect(page.items, isEmpty);
        expect(page.nextCursor, isNull);
        p.close();
      },
    );

    test('status=0 + NOTOK + "Invalid API Key" → TxHistoryApiException with '
        'apikey REDACTED in endpoint', () async {
      final mock = MockClient((req) async {
        return _json({
          'status': '0',
          'message': 'NOTOK',
          'result': 'Invalid API Key',
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      await expectLater(
        () => p.listNativeTransactions(_addr),
        throwsA(
          isA<TxHistoryApiException>()
              .having((e) => e.code, 'code', -2002)
              .having((e) => e.message, 'message', contains('Invalid API Key'))
              .having(
                (e) => e.endpoint ?? '',
                'endpoint redacted',
                allOf(contains('apikey=REDACTED'), isNot(contains(_key))),
              ),
        ),
      );
      p.close();
    });

    test(
      'status=0 + "Max rate limit reached" → TxHistoryApiException(-2002)',
      () async {
        final mock = MockClient((req) async {
          return _json({
            'status': '0',
            'message': 'NOTOK',
            'result': 'Max rate limit reached, please use API Key',
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
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
                  contains('Max rate limit'),
                ),
          ),
        );
        p.close();
      },
    );

    test(
      'forwards startBlock/endBlock as startblock/endblock query params',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return _json({
            'status': '1',
            'message': 'OK',
            'result': <Map<String, dynamic>>[],
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        await p.listNativeTransactions(
          _addr,
          startBlock: BigInt.from(100),
          endBlock: BigInt.from(200),
        );
        expect(captured!.queryParameters['startblock'], '100');
        expect(captured!.queryParameters['endblock'], '200');
        p.close();
      },
    );
  });

  group('EvmEtherscanProvider — listTokenTransfers', () {
    test('emits action=tokentx with no contract filter when omitted', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      await p.listTokenTransfers(_addr);
      expect(captured!.queryParameters['action'], 'tokentx');
      expect(captured!.queryParameters.containsKey('contractaddress'), isFalse);
      p.close();
    });

    test('contractAddress forwarded as contractaddress query param', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      const usdt = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
      await p.listTokenTransfers(_addr, contractAddress: usdt);
      expect(captured!.queryParameters['action'], 'tokentx');
      expect(captured!.queryParameters['contractaddress'], usdt);
      p.close();
    });
  });

  group('EvmEtherscanProvider — cursor handling', () {
    test(
      'EtherscanCursor(page=3, offset=25) → URL contains page=3&offset=25',
      () async {
        Uri? captured;
        final mock = MockClient((req) async {
          captured = req.url;
          return _json({
            'status': '1',
            'message': 'OK',
            'result': <Map<String, dynamic>>[],
          });
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        await p.listNativeTransactions(
          _addr,
          cursor: EtherscanCursor(page: 3, offset: 25),
        );
        expect(captured!.queryParameters['page'], '3');
        expect(captured!.queryParameters['offset'], '25');
        p.close();
      },
    );

    test(
      'wrong-chain cursor (BlockscoutCursor) → InvalidCursorException',
      () async {
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: MockClient((_) async {
            fail('http should not be hit on cursor mismatch');
          }),
        );
        await expectLater(
          () => p.listNativeTransactions(
            _addr,
            cursor: const BlockscoutCursor({'block_number': '1'}),
          ),
          throwsA(
            isA<InvalidCursorException>().having(
              (e) => e.message,
              'message',
              contains('expected EtherscanCursor'),
            ),
          ),
        );
        p.close();
      },
    );
  });

  group('EvmEtherscanProvider — TxHistoryProvider interface', () {
    test('listTransactions delegates to listNativeTransactions', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      await p.listTransactions(
        TxHistoryQuery(
          address: _addr,
          limit: 25,
          fromBlock: BigInt.from(10),
          toBlock: BigInt.from(20),
        ),
      );
      expect(captured!.queryParameters['action'], 'txlist');
      expect(captured!.queryParameters['offset'], '25');
      expect(captured!.queryParameters['startblock'], '10');
      expect(captured!.queryParameters['endblock'], '20');
      p.close();
    });

    test('list() convenience uses txlist action', () async {
      Uri? captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': '1',
          'message': 'OK',
          'result': <Map<String, dynamic>>[],
        });
      });
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: mock,
      );
      await p.list(address: _addr);
      expect(captured!.queryParameters['action'], 'txlist');
      p.close();
    });
  });

  group('EvmEtherscanProvider — API key redaction', () {
    test(
      '4xx HTTP error: thrown exception toString MUST NOT contain raw apiKey',
      () async {
        // Etherscan rarely returns true 4xx for an invalid key (it uses status=0
        // envelope inside HTTP 200), but if any upstream proxy ever does, the
        // RestHistoryClient will surface RpcHttpException whose message carries
        // the response body — never the request URL — so the apiKey value MUST
        // not appear anywhere in the exception's printed form.
        final mock = MockClient((req) async {
          return http.Response(
            'Unauthorized',
            401,
            headers: {'content-type': 'text/plain'},
          );
        });
        final p = EvmEtherscanProvider(
          baseUrl: 'https://api.etherscan.io',
          apiKey: _key,
          httpClient: mock,
        );
        await expectLater(
          () => p.listNativeTransactions(_addr),
          throwsA(
            predicate<Object>(
              (e) => !e.toString().contains(_key),
              'exception toString does not contain raw apiKey',
            ),
          ),
        );
        p.close();
      },
    );
  });

  group('EvmEtherscanProvider — close()', () {
    test('close() is idempotent', () {
      final p = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        apiKey: _key,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(() => p.close(), returnsNormally);
      expect(() => p.close(), returnsNormally);
    });
  });
}
