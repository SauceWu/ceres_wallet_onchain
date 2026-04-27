import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/governance_methods.dart';
import 'package:ceres_wallet_onchain/src/sui/sui_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Test harness that applies the [SuiGovernanceMethods] mixin.
class _TestClient with SuiGovernanceMethods {
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

void main() {
  final owner = SuiAddress(
    '0x94f1a597b4e8f709a396f7f6b1482bdcd65a673d111e49286c527fab7c2d0961',
  );

  group('SuiGovernanceMethods', () {
    group('getStakes', () {
      test('sends suix_getStakes and returns delegated stakes', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          [
            {
              'validatorAddress': '0xvalidator1',
              'stakingPool': '0xpool1',
              'stakes': [
                {
                  'stakedSuiId': '0xstake1',
                  'stakeRequestEpoch': '100',
                  'stakeActiveEpoch': '101',
                  'principal': '2000000000',
                  'status': 'Active',
                  'estimatedReward': '50000000',
                },
              ],
            },
          ],
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final stakes = await client.getStakes(owner);
        expect(capturedMethod, equals('suix_getStakes'));
        expect(capturedParams, hasLength(1));
        expect(capturedParams![0], equals(owner.toHex()));
        expect(stakes, hasLength(1));
        expect(stakes[0].validatorAddress, equals('0xvalidator1'));
        expect(stakes[0].stakes, hasLength(1));
        expect(stakes[0].stakes[0].principal, equals(BigInt.from(2000000000)));
        expect(
          stakes[0].stakes[0].estimatedReward,
          equals(BigInt.from(50000000)),
        );
        expect(stakes[0].stakes[0].status, equals('Active'));
        client.close();
      });

      test('returns empty list when no stakes', () async {
        final client = _clientCapturing(<Map<String, dynamic>>[], (_) {});

        final stakes = await client.getStakes(owner);
        expect(stakes, isEmpty);
        client.close();
      });
    });

    group('getStakesByIds', () {
      test('sends suix_getStakesByIds with object IDs', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          [
            {
              'validatorAddress': '0xvalidator2',
              'stakingPool': '0xpool2',
              'stakes': [
                {
                  'stakedSuiId': '0xstake2',
                  'stakeRequestEpoch': '200',
                  'stakeActiveEpoch': '201',
                  'principal': '5000000000',
                  'status': 'Pending',
                },
              ],
            },
          ],
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final stakes = await client.getStakesByIds(['0xstake2', '0xstake3']);
        expect(capturedMethod, equals('suix_getStakesByIds'));
        expect(capturedParams, hasLength(1));
        expect(capturedParams![0], equals(['0xstake2', '0xstake3']));
        expect(stakes, hasLength(1));
        expect(stakes[0].stakes[0].estimatedReward, isNull);
        client.close();
      });
    });

    group('getValidatorsApy', () {
      test('sends suix_getValidatorsApy and returns ValidatorsApy', () async {
        String? capturedMethod;
        List<dynamic>? capturedParams;

        final client = _clientCapturing(
          {
            'apys': [
              {'address': '0xval1', 'apy': 0.0523},
              {'address': '0xval2', 'apy': 0.0481},
            ],
            'epoch': '350',
          },
          (body) {
            capturedMethod = body['method'] as String;
            capturedParams = body['params'] as List<dynamic>;
          },
        );

        final apys = await client.getValidatorsApy();
        expect(capturedMethod, equals('suix_getValidatorsApy'));
        expect(capturedParams, isEmpty);
        expect(apys.epoch, equals('350'));
        expect(apys.apys, hasLength(2));
        expect(apys.apys[0].address, equals('0xval1'));
        expect(apys.apys[0].apy, closeTo(0.0523, 0.0001));
        expect(apys.apys[1].apy, closeTo(0.0481, 0.0001));
        client.close();
      });
    });

    test('sends correct RPC method names for all 3 methods', () async {
      final methods = <String>[];
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        methods.add(body['method'] as String);

        dynamic result;
        switch (body['method']) {
          case 'suix_getStakes':
          case 'suix_getStakesByIds':
            result = <Map<String, dynamic>>[];
            break;
          case 'suix_getValidatorsApy':
            result = {'apys': <Map<String, dynamic>>[], 'epoch': '0'};
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

      await client.getStakes(owner);
      await client.getStakesByIds(['0xid1']);
      await client.getValidatorsApy();

      expect(methods, [
        'suix_getStakes',
        'suix_getStakesByIds',
        'suix_getValidatorsApy',
      ]);
      client.close();
    });
  });
}
