import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/token_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Helper that creates a [JsonRpcTransport] backed by a [MockClient].
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

/// Test harness that uses [SolanaTokenMethods] via a concrete class.
class _TestClient with SolanaTokenMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);
}

void main() {
  const systemProgram = '11111111111111111111111111111111';
  const tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  // A known mint address (USDC on Solana mainnet)
  const usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  group('SolanaTokenMethods', () {
    group('getTokenAccountBalance', () {
      test('returns TokenAmount', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getTokenAccountBalance');
          final params = req['params'] as List;
          expect(params[0], systemProgram);
          return {
            'context': {'slot': 123},
            'value': {
              'amount': '1000000',
              'decimals': 6,
              'uiAmountString': '1.0',
            },
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenAccountBalance(systemProgram);

        expect(result.amount, '1000000');
        expect(result.decimals, 6);
        expect(result.uiAmountString, '1.0');
      });
    });

    group('getTokenAccountsByOwner', () {
      test('sends mint filter', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getTokenAccountsByOwner');
          capturedParams = req['params'] as List;
          return {
            'context': {'slot': 123},
            'value': [
              {
                'pubkey': 'tokenAccount1',
                'account': {
                  'lamports': 2039280,
                  'owner': tokenProgram,
                  'executable': false,
                  'rentEpoch': 361,
                  'data': ['', 'base64'],
                },
              },
            ],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenAccountsByOwner(
          SolanaAddress(systemProgram),
          mint: SolanaAddress(usdcMint),
        );

        expect(result.length, 1);
        expect(result[0].pubkey, 'tokenAccount1');
        // Verify the filter was sent as mint
        final filter = capturedParams[1] as Map<String, dynamic>;
        expect(filter['mint'], usdcMint);
      });

      test('sends programId filter', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          capturedParams = req['params'] as List;
          return {
            'context': {'slot': 123},
            'value': [],
          };
        });
        final client = _TestClient(transport);

        await client.getTokenAccountsByOwner(
          SolanaAddress(systemProgram),
          programId: SolanaAddress(tokenProgram),
        );

        final filter = capturedParams[1] as Map<String, dynamic>;
        expect(filter['programId'], tokenProgram);
        expect(filter.containsKey('mint'), false);
      });

      test('throws when neither mint nor programId provided', () async {
        final transport = _createMockTransport((req) => null);
        final client = _TestClient(transport);

        expect(
          () => client.getTokenAccountsByOwner(SolanaAddress(systemProgram)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('returns empty list when no accounts', () async {
        final transport = _createMockTransport((req) {
          return {
            'context': {'slot': 123},
            'value': [],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenAccountsByOwner(
          SolanaAddress(systemProgram),
          mint: SolanaAddress(usdcMint),
        );

        expect(result, isEmpty);
      });
    });

    group('getTokenAccountsByDelegate', () {
      test('returns list of TokenAccount', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getTokenAccountsByDelegate');
          return {
            'context': {'slot': 123},
            'value': [
              {
                'pubkey': 'delegatedAccount1',
                'account': {
                  'lamports': 2039280,
                  'owner': tokenProgram,
                  'executable': false,
                  'rentEpoch': 361,
                  'data': ['', 'base64'],
                },
              },
            ],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenAccountsByDelegate(
          SolanaAddress(systemProgram),
          programId: SolanaAddress(tokenProgram),
        );

        expect(result.length, 1);
        expect(result[0].pubkey, 'delegatedAccount1');
      });

      test('throws when neither mint nor programId provided', () async {
        final transport = _createMockTransport((req) => null);
        final client = _TestClient(transport);

        expect(
          () => client.getTokenAccountsByDelegate(SolanaAddress(systemProgram)),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('getTokenLargestAccounts', () {
      test('returns list with address, amount, decimals', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getTokenLargestAccounts');
          final params = req['params'] as List;
          expect(params[0], usdcMint);
          return {
            'context': {'slot': 123},
            'value': [
              {
                'address': 'bigHolder1',
                'amount': '999999999',
                'decimals': 6,
                'uiAmountString': '999.999999',
              },
              {
                'address': 'bigHolder2',
                'amount': '888888888',
                'decimals': 6,
                'uiAmountString': '888.888888',
              },
            ],
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenLargestAccounts(
          SolanaAddress(usdcMint),
        );

        expect(result.length, 2);
        expect(result[0].address, 'bigHolder1');
        expect(result[0].amount, '999999999');
        expect(result[0].decimals, 6);
        expect(result[0].uiAmountString, '999.999999');
      });
    });

    group('getTokenSupply', () {
      test('returns TokenAmount', () async {
        final transport = _createMockTransport((req) {
          expect(req['method'], 'getTokenSupply');
          final params = req['params'] as List;
          expect(params[0], usdcMint);
          return {
            'context': {'slot': 123},
            'value': {
              'amount': '10000000000000',
              'decimals': 6,
              'uiAmountString': '10000000.0',
            },
          };
        });
        final client = _TestClient(transport);

        final result = await client.getTokenSupply(SolanaAddress(usdcMint));

        expect(result.amount, '10000000000000');
        expect(result.decimals, 6);
        expect(result.uiAmountString, '10000000.0');
      });
    });
  });
}
