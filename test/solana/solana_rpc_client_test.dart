/// End-to-end integration tests for [SolanaRpcClient].
///
/// These tests verify the full call chain through the assembled client
/// (not individual mixins), using [MockClient] to simulate JSON-RPC
/// responses. Imports use the barrel export to verify export completeness.
library;

import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Creates a [SolanaRpcClient] backed by a [MockClient].
///
/// The [handler] receives the decoded JSON-RPC request body and returns
/// the `result` field to wrap in a standard JSON-RPC response.
SolanaRpcClient _createClient(
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
  final transport = JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'http://localhost:8899'),
    httpClient: mockClient,
  );
  return SolanaRpcClient(transport: transport);
}

void main() {
  const systemProgram = '11111111111111111111111111111111';
  const tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  group('SolanaRpcClient end-to-end', () {
    test('getBalance returns correct BigInt', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getBalance');
        final params = req['params'] as List;
        expect(params[0], systemProgram);
        return {
          'context': {'slot': 100},
          'value': 2500000000,
        };
      });

      final balance = await client.getBalance(SolanaAddress(systemProgram));
      expect(balance, BigInt.from(2500000000));
    });

    test('getTokenAccountsByOwner returns TokenAccount list', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getTokenAccountsByOwner');
        final params = req['params'] as List;
        expect(params[0], systemProgram);
        // Filter param
        expect(params[1], containsPair('programId', tokenProgram));
        return {
          'context': {'slot': 200},
          'value': [
            {
              'pubkey': tokenProgram,
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

      final accounts = await client.getTokenAccountsByOwner(
        SolanaAddress(systemProgram),
        programId: SolanaAddress(tokenProgram),
      );
      expect(accounts, hasLength(1));
      expect(accounts.first.pubkey, tokenProgram);
    });

    test('sendTransaction returns signature string', () async {
      const fakeSig =
          '5VERv8NMhMgSfGxtGEdLgjJSuT9nLnHGytQvTzo5TLEJ7zs8Whf2nxYFoT5xFLknuHCisimLRL7KgpsGgo5fGG3i';
      const base64Tx = 'AQAAAAAAAAAAAAAAAAAAAAA==';

      final client = _createClient((req) {
        expect(req['method'], 'sendTransaction');
        final params = req['params'] as List;
        expect(params[0], base64Tx);
        final config = params[1] as Map<String, dynamic>;
        expect(config['encoding'], 'base64');
        return fakeSig;
      });

      final sig = await client.sendTransaction(base64Tx);
      expect(sig, fakeSig);
    });

    test('getAccountInfo returns null for nonexistent account', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getAccountInfo');
        return {
          'context': {'slot': 300},
          'value': null,
        };
      });

      final info = await client.getAccountInfo(SolanaAddress(systemProgram));
      expect(info, isNull);
    });

    test('getBlock returns SolanaBlock with transactions', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getBlock');
        final params = req['params'] as List;
        expect(params[0], 100);
        final config = params[1] as Map<String, dynamic>;
        expect(config['maxSupportedTransactionVersion'], 0);
        return {
          'blockhash': 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG',
          'previousBlockhash': 'H27nh8Qv4HwMFEEqnGeCBqjSWYkDQPcFGHxjGCDfN6',
          'parentSlot': 99,
          'blockHeight': 50,
          'blockTime': 1625000000,
          'transactions': [
            {
              'transaction': {
                'signatures': [
                  '5VERv8NMhMgSfGxtGEdLgjJSuT9nLnHGytQvTzo5TLEJ7zs8Whf2nxYFoT5xFLknuHCisimLRL7KgpsGgo5fGG3i',
                ],
                'message': {
                  'accountKeys': [systemProgram],
                  'recentBlockhash':
                      'EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG',
                  'instructions': [],
                },
              },
              'meta': {
                'err': null,
                'fee': 5000,
                'preBalances': [1000000000],
                'postBalances': [999995000],
                'logMessages': ['Program 11111 invoke [1]'],
              },
            },
          ],
        };
      });

      final block = await client.getBlock(100);
      expect(block, isNotNull);
      expect(block!.blockhash, 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG');
      expect(block.transactions, isNotNull);
      expect(block.transactions!, hasLength(1));
      expect(block.blockHeight, 50);
    });

    test('getLatestBlockhash returns BlockhashResult', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getLatestBlockhash');
        return {
          'context': {'slot': 400},
          'value': {
            'blockhash': 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG',
            'lastValidBlockHeight': 500,
          },
        };
      });

      final result = await client.getLatestBlockhash();
      expect(result.blockhash, 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG');
      expect(result.lastValidBlockHeight, 500);
    });

    test('getHealth returns ok string', () async {
      final client = _createClient((req) {
        expect(req['method'], 'getHealth');
        return 'ok';
      });

      final health = await client.getHealth();
      expect(health, 'ok');
    });

    test('close does not throw', () {
      final client = _createClient((_) => null);
      expect(() => client.close(), returnsNormally);
    });
  });
}
