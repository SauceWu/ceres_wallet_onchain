import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/coin_methods.dart';
import 'package:ceres_wallet_onchain/src/sui/sui_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Test harness that applies the [SuiCoinMethods] mixin.
class _TestClient with SuiCoinMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);

  void close() => transport.close();
}

/// Captures the JSON-RPC request body and returns [result].
_TestClient _clientCapturing(
  dynamic result,
  void Function(Map<String, dynamic>) onRequest,
) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    onRequest(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
    httpClient: mockHttp,
  );
  return _TestClient(transport);
}

/// Returns a [_TestClient] that returns [result] for any request.
_TestClient _clientWithResult(dynamic result) {
  return _clientCapturing(result, (_) {});
}

void main() {
  final owner = SuiAddress(
    '0x94f1a597b4e8f709a396f7f6b1482bdcd65a673d111e49286c527fab7c2d0961',
  );

  group('SuiCoinMethods', () {
    group('getBalance', () {
      test('sends suix_getBalance with owner and default coinType', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'coinType': '0x2::sui::SUI',
            'coinObjectCount': 3,
            'totalBalance': '1000000000',
          },
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final balance = await client.getBalance(owner);
        expect(capturedMethod, equals('suix_getBalance'));
        expect(capturedParams, hasLength(2));
        expect(capturedParams![0], equals(owner.toHex()));
        expect(capturedParams![1], isNull);
        expect(balance.coinType, equals('0x2::sui::SUI'));
        expect(balance.totalBalance, equals(BigInt.from(1000000000)));
        expect(balance.coinObjectCount, equals(3));
        client.close();
      });

      test('sends custom coinType when specified', () async {
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'coinType': '0x2::usdc::USDC',
            'coinObjectCount': 1,
            'totalBalance': '500000',
          },
          (body) {
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        await client.getBalance(owner, coinType: '0x2::usdc::USDC');
        expect(capturedParams![1], equals('0x2::usdc::USDC'));
        client.close();
      });
    });

    group('getAllBalances', () {
      test('sends suix_getAllBalances and returns list', () async {
        String? capturedMethod;

        final client = _clientCapturing(
          [
            {
              'coinType': '0x2::sui::SUI',
              'coinObjectCount': 3,
              'totalBalance': '1000000000',
            },
            {
              'coinType': '0x2::usdc::USDC',
              'coinObjectCount': 1,
              'totalBalance': '500',
            },
          ],
          (body) {
            capturedMethod = body['method'] as String;
          },
        );

        final balances = await client.getAllBalances(owner);
        expect(capturedMethod, equals('suix_getAllBalances'));
        expect(balances, hasLength(2));
        expect(balances[0].coinType, equals('0x2::sui::SUI'));
        expect(balances[1].totalBalance, equals(BigInt.from(500)));
        client.close();
      });
    });

    group('getCoins', () {
      test('sends suix_getCoins with pagination params', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'data': [
              {
                'coinType': '0x2::sui::SUI',
                'coinObjectId': '0xobj1',
                'version': '100',
                'digest': 'abc123',
                'balance': '5000000000',
                'previousTransaction': '0xtx1',
              },
            ],
            'hasNextPage': true,
            'nextCursor': '0xcursor1',
          },
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final page = await client.getCoins(
          owner,
          coinType: '0x2::sui::SUI',
          cursor: '0xcursor0',
          limit: 10,
        );
        expect(capturedMethod, equals('suix_getCoins'));
        expect(capturedParams![0], equals(owner.toHex()));
        expect(capturedParams![1], equals('0x2::sui::SUI'));
        expect(capturedParams![2], equals('0xcursor0'));
        expect(capturedParams![3], equals(10));
        expect(page.data, hasLength(1));
        expect(page.data[0].balance, equals(BigInt.from(5000000000)));
        expect(page.hasNextPage, isTrue);
        expect(page.nextCursor, equals('0xcursor1'));
        client.close();
      });
    });

    group('getAllCoins', () {
      test('sends suix_getAllCoins', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'data': <Map<String, dynamic>>[],
            'hasNextPage': false,
            'nextCursor': null,
          },
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final page = await client.getAllCoins(owner);
        expect(capturedMethod, equals('suix_getAllCoins'));
        expect(capturedParams![0], equals(owner.toHex()));
        expect(capturedParams![1], isNull); // cursor
        expect(capturedParams![2], isNull); // limit
        expect(page.data, isEmpty);
        expect(page.hasNextPage, isFalse);
        client.close();
      });
    });

    group('getCoinMetadata', () {
      test('returns SuiCoinMetadata for valid coin', () async {
        String? capturedMethod;

        final client = _clientCapturing(
          {
            'decimals': 9,
            'name': 'Sui',
            'symbol': 'SUI',
            'description': 'The native coin of Sui',
            'iconUrl': 'https://example.com/sui.png',
            'id': '0xmetaId',
          },
          (body) {
            capturedMethod = body['method'] as String;
          },
        );

        final meta = await client.getCoinMetadata('0x2::sui::SUI');
        expect(capturedMethod, equals('suix_getCoinMetadata'));
        expect(meta, isNotNull);
        expect(meta!.decimals, equals(9));
        expect(meta.symbol, equals('SUI'));
        expect(meta.iconUrl, equals('https://example.com/sui.png'));
        client.close();
      });

      test('returns null when no metadata exists', () async {
        final client = _clientWithResult(null);
        final meta = await client.getCoinMetadata('0xfake::coin::FAKE');
        expect(meta, isNull);
        client.close();
      });
    });

    group('getTotalSupply', () {
      test('sends suix_getTotalSupply and returns SuiSupply', () async {
        String? capturedMethod;

        final client = _clientCapturing({'value': '10000000000000000000'}, (
          body,
        ) {
          capturedMethod = body['method'] as String;
        });

        final supply = await client.getTotalSupply('0x2::sui::SUI');
        expect(capturedMethod, equals('suix_getTotalSupply'));
        expect(supply.value, equals(BigInt.parse('10000000000000000000')));
        client.close();
      });
    });

    group('getOwnedObjects', () {
      test('sends suix_getOwnedObjects with filter and options', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'data': [
              {
                'data': {
                  'objectId': '0xobj1',
                  'version': '42',
                  'digest': 'abc',
                  'type': '0x2::coin::Coin<0x2::sui::SUI>',
                },
              },
            ],
            'hasNextPage': false,
            'nextCursor': null,
          },
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final page = await client.getOwnedObjects(
          owner,
          filter: {'StructType': '0x2::coin::Coin<0x2::sui::SUI>'},
        );
        expect(capturedMethod, equals('suix_getOwnedObjects'));
        expect(capturedParams![0], equals(owner.toHex()));
        // Second param is the query object with filter and options
        final query = capturedParams![1] as Map<String, dynamic>;
        expect(query['filter'], isNotNull);
        expect(page.data, hasLength(1));
        expect(page.data[0].data!.objectId, equals('0xobj1'));
        client.close();
      });
    });

    test('sends correct RPC method names for all 7 methods', () async {
      final methods = <String>[];
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        methods.add(body['method'] as String);

        dynamic result;
        switch (body['method']) {
          case 'suix_getBalance':
            result = {
              'coinType': '0x2::sui::SUI',
              'coinObjectCount': 0,
              'totalBalance': '0',
            };
            break;
          case 'suix_getAllBalances':
            result = <Map<String, dynamic>>[];
            break;
          case 'suix_getCoins':
          case 'suix_getAllCoins':
          case 'suix_getOwnedObjects':
            result = {
              'data': <Map<String, dynamic>>[],
              'hasNextPage': false,
              'nextCursor': null,
            };
            break;
          case 'suix_getCoinMetadata':
            result = null;
            break;
          case 'suix_getTotalSupply':
            result = {'value': '0'};
            break;
          default:
            result = null;
        }
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = JsonRpcTransport(
        config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
        httpClient: mockHttp,
      );
      final client = _TestClient(transport);

      await client.getOwnedObjects(owner);
      await client.getBalance(owner);
      await client.getAllBalances(owner);
      await client.getCoins(owner);
      await client.getAllCoins(owner);
      await client.getCoinMetadata('0x2::sui::SUI');
      await client.getTotalSupply('0x2::sui::SUI');

      expect(methods, [
        'suix_getOwnedObjects',
        'suix_getBalance',
        'suix_getAllBalances',
        'suix_getCoins',
        'suix_getAllCoins',
        'suix_getCoinMetadata',
        'suix_getTotalSupply',
      ]);
      client.close();
    });
  });
}
