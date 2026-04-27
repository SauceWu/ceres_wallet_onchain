import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/account_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Helper that creates a [JsonRpcTransport] backed by a [MockClient].
///
/// The [handler] receives the decoded JSON-RPC request body and returns
/// the `result` field to wrap in a JSON-RPC response.
JsonRpcTransport _createMockTransport(
  dynamic Function(Map<String, dynamic> request) handler,
) {
  final mockClient = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final result = handler(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'http://localhost:8899'),
    httpClient: mockClient,
  );
}

/// Test harness that uses [SolanaAccountMethods] via a concrete class.
class _TestClient with SolanaAccountMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);
}

void main() {
  // Known 32-byte base58 address (System Program)
  const systemProgram = '11111111111111111111111111111111';
  // Another known address (Token Program)
  const tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  group('SolanaAccountMethods', () {
    group('getAccountInfo', () {
      test('returns AccountInfo when value is non-null', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getAccountInfo');
          final params = req['params'] as List;
          expect(params[0], systemProgram);
          final config = params[1] as Map<String, dynamic>;
          expect(config['commitment'], 'finalized');
          expect(config['encoding'], 'base64');
          return {
            'context': {'slot': 123},
            'value': {
              'lamports': 1000000,
              'owner': systemProgram,
              'executable': false,
              'rentEpoch': 361,
              'data': ['', 'base64'],
            },
          };
        });
        final client = _TestClient(transport);

        final result = await client.getAccountInfo(
          SolanaAddress(systemProgram),
        );

        expect(result, isNotNull);
        expect(result!.lamports, BigInt.from(1000000));
        expect(result.owner, systemProgram);
        expect(result.executable, false);
        expect(result.data, ['', 'base64']);
      });

      test('returns null when value is null', () async {
        final transport = _createMockTransport((req) {
          return {
            'context': {'slot': 123},
            'value': null,
          };
        });
        final client = _TestClient(transport);

        final result = await client.getAccountInfo(
          SolanaAddress(systemProgram),
        );

        expect(result, isNull);
      });

      test('passes custom commitment', () async {
        late Map<String, dynamic> capturedConfig;
        final transport = _createMockTransport((req) {
          capturedConfig = (req['params'] as List)[1] as Map<String, dynamic>;
          return {
            'context': {'slot': 123},
            'value': null,
          };
        });
        final client = _TestClient(transport);

        await client.getAccountInfo(
          SolanaAddress(systemProgram),
          commitment: SolanaCommitment.confirmed,
        );

        expect(capturedConfig['commitment'], 'confirmed');
      });
    });

    group('getBalance', () {
      test('returns BigInt lamport balance', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getBalance');
          return {
            'context': {'slot': 123},
            'value': 5000000000,
          };
        });
        final client = _TestClient(transport);

        final result = await client.getBalance(SolanaAddress(systemProgram));

        expect(result, BigInt.from(5000000000));
      });

      test('returns zero for empty account', () async {
        final transport = _createMockTransport((req) {
          return {
            'context': {'slot': 123},
            'value': 0,
          };
        });
        final client = _TestClient(transport);

        final result = await client.getBalance(SolanaAddress(systemProgram));

        expect(result, BigInt.zero);
      });
    });

    group('getMultipleAccounts', () {
      test('returns list of AccountInfo with nulls', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getMultipleAccounts');
          final params = req['params'] as List;
          expect(params[0], [systemProgram, tokenProgram]);
          return {
            'context': {'slot': 123},
            'value': [
              {
                'lamports': 1,
                'owner': systemProgram,
                'executable': true,
                'rentEpoch': 0,
                'data': ['', 'base64'],
              },
              null,
            ],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getMultipleAccounts([
          SolanaAddress(systemProgram),
          SolanaAddress(tokenProgram),
        ]);

        expect(result.length, 2);
        expect(result[0], isNotNull);
        expect(result[0]!.lamports, BigInt.from(1));
        expect(result[0]!.executable, true);
        expect(result[1], isNull);
      });
    });

    group('getProgramAccounts', () {
      test('returns list of TokenAccount', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getProgramAccounts');
          return [
            {
              'pubkey': 'account1Pubkey',
              'account': {
                'lamports': 2039280,
                'owner': tokenProgram,
                'executable': false,
                'rentEpoch': 361,
                'data': ['', 'base64'],
              },
            },
          ];
        });
        final client = _TestClient(transport);

        final result = await client.getProgramAccounts(
          SolanaAddress(tokenProgram),
        );

        expect(result.length, 1);
        expect(result[0].pubkey, 'account1Pubkey');
      });

      test('returns empty list when no accounts', () async {
        final transport = _createMockTransport((req) => []);
        final client = _TestClient(transport);

        final result = await client.getProgramAccounts(
          SolanaAddress(tokenProgram),
        );

        expect(result, isEmpty);
      });

      test('passes filters and dataSlice', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          capturedParams = req['params'] as List;
          return [];
        });
        final client = _TestClient(transport);

        await client.getProgramAccounts(
          SolanaAddress(tokenProgram),
          filters: [
            {'dataSize': 165},
          ],
          dataSlice: {'offset': 0, 'length': 32},
        );

        final config = capturedParams[1] as Map<String, dynamic>;
        expect(config['filters'], [
          {'dataSize': 165},
        ]);
        expect(config['dataSlice'], {'offset': 0, 'length': 32});
      });
    });

    group('getLargestAccounts', () {
      test('returns list of AccountBalance', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getLargestAccounts');
          return {
            'context': {'slot': 123},
            'value': [
              {'address': systemProgram, 'lamports': 99999999999},
              {'address': tokenProgram, 'lamports': 88888888888},
            ],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getLargestAccounts();

        expect(result.length, 2);
        expect(result[0].address, systemProgram);
        expect(result[0].lamports, BigInt.from(99999999999));
        expect(result[1].address, tokenProgram);
      });

      test('passes filter parameter', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          capturedParams = req['params'] as List;
          return {
            'context': {'slot': 123},
            'value': [],
          };
        });
        final client = _TestClient(transport);

        await client.getLargestAccounts(filter: 'circulating');

        final config = capturedParams[0] as Map<String, dynamic>;
        expect(config['filter'], 'circulating');
      });
    });
  });
}
