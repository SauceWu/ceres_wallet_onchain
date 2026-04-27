import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/transaction_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/models/signature_info.dart';
import 'package:ceres_wallet_onchain/src/solana/models/signature_status.dart';
import 'package:ceres_wallet_onchain/src/solana/models/simulate_result.dart';
import 'package:ceres_wallet_onchain/src/solana/models/solana_transaction.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Test helper that mixes in [SolanaTransactionMethods].
class _TestClient with SolanaTransactionMethods {
  @override
  final JsonRpcTransport transport;
  _TestClient(this.transport);
}

/// Creates a [MockClient] that returns a raw result (not necessarily a Map).
MockClient _mockClientRaw(
  dynamic result, {
  void Function(Map<String, dynamic> requestBody)? onRequest,
}) {
  return MockClient((request) async {
    if (onRequest != null) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      onRequest(body);
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

_TestClient _createClient(http.Client httpClient) {
  final transport = JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://api.devnet.solana.com'),
    httpClient: httpClient,
  );
  return _TestClient(transport);
}

void main() {
  group('SolanaTransactionMethods', () {
    group('getTransaction', () {
      test('returns SolanaTransactionResponse with correct params', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'slot': 12345,
          'transaction': {
            'signatures': ['sig1'],
            'message': {'accountKeys': []},
          },
          'meta': {
            'err': null,
            'fee': 5000,
            'preBalances': [100000, 50000],
            'postBalances': [95000, 55000],
          },
          'blockTime': 1700000000,
          'version': 0,
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        final result = await client.getTransaction('txSig123');

        expect(result, isNotNull);
        expect(result, isA<SolanaTransactionResponse>());
        expect(result!.slot, equals(12345));
        expect(result.blockTime, equals(1700000000));
        expect(result.version, equals(0));

        // Verify params include maxSupportedTransactionVersion: 0
        final params = captured!['params'] as List;
        expect(params[0], equals('txSig123'));
        final config = params[1] as Map<String, dynamic>;
        expect(config['maxSupportedTransactionVersion'], equals(0));
        expect(config['encoding'], equals('jsonParsed'));
      });

      test('returns null when result is null', () async {
        final mock = _mockClientRaw(null);
        final client = _createClient(mock);

        final result = await client.getTransaction('nonexistent');
        expect(result, isNull);
      });

      test('passes commitment when provided', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw(null, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getTransaction(
          'txSig',
          commitment: SolanaCommitment.finalized,
        );

        final params = captured!['params'] as List;
        final config = params[1] as Map<String, dynamic>;
        expect(config['commitment'], equals('finalized'));
      });
    });

    group('getSignaturesForAddress', () {
      test('returns List<SignatureInfo>', () async {
        final mock = _mockClientRaw([
          {
            'signature': 'sig1',
            'slot': 100,
            'err': null,
            'memo': null,
            'blockTime': 1700000000,
            'confirmationStatus': 'finalized',
          },
          {
            'signature': 'sig2',
            'slot': 101,
            'err': null,
            'memo': 'test memo',
            'blockTime': 1700000001,
            'confirmationStatus': 'confirmed',
          },
        ]);
        final client = _createClient(mock);

        final result = await client.getSignaturesForAddress('addr123');

        expect(result, hasLength(2));
        expect(result[0], isA<SignatureInfo>());
        expect(result[0].signature, equals('sig1'));
        expect(result[1].memo, equals('test memo'));
      });

      test(
        'passes optional params: limit, before, until, commitment',
        () async {
          Map<String, dynamic>? captured;
          final mock = _mockClientRaw([], onRequest: (body) => captured = body);
          final client = _createClient(mock);

          await client.getSignaturesForAddress(
            'addr123',
            limit: 10,
            before: 'sigBefore',
            until: 'sigUntil',
            commitment: SolanaCommitment.confirmed,
          );

          final params = captured!['params'] as List;
          expect(params[0], equals('addr123'));
          final config = params[1] as Map<String, dynamic>;
          expect(config['limit'], equals(10));
          expect(config['before'], equals('sigBefore'));
          expect(config['until'], equals('sigUntil'));
          expect(config['commitment'], equals('confirmed'));
        },
      );
    });

    group('getSignatureStatuses', () {
      test('returns List<SignatureStatus?> from RpcResponse', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 200},
          'value': [
            {
              'slot': 100,
              'confirmations': 10,
              'err': null,
              'confirmationStatus': 'confirmed',
            },
            null,
          ],
        });
        final client = _createClient(mock);

        final result = await client.getSignatureStatuses(['sig1', 'sig2']);

        expect(result, hasLength(2));
        expect(result[0], isA<SignatureStatus>());
        expect(result[0]!.slot, equals(100));
        expect(result[1], isNull);
      });

      test('passes searchTransactionHistory option', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'context': {'slot': 200},
          'value': [],
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getSignatureStatuses([
          'sig1',
        ], searchTransactionHistory: true);

        final params = captured!['params'] as List;
        expect(params[0], equals(['sig1']));
        final config = params[1] as Map<String, dynamic>;
        expect(config['searchTransactionHistory'], isTrue);
      });
    });

    group('sendTransaction', () {
      test('sends base64 transaction and returns signature string', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw(
          'txSignatureHash123',
          onRequest: (body) => captured = body,
        );
        final client = _createClient(mock);

        final result = await client.sendTransaction('base64EncodedTx==');

        expect(result, equals('txSignatureHash123'));

        // Verify method and params
        expect(captured!['method'], equals('sendTransaction'));
        final params = captured!['params'] as List;
        expect(params[0], equals('base64EncodedTx=='));
        final config = params[1] as Map<String, dynamic>;
        expect(config['encoding'], equals('base64'));
      });

      test('does NOT contain any signing logic', () async {
        // sendTransaction should only pass through the base64 body
        // We verify this by checking params are passed as-is
        Map<String, dynamic>? captured;
        final rawBase64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop==';
        final mock = _mockClientRaw(
          'resultSig',
          onRequest: (body) => captured = body,
        );
        final client = _createClient(mock);

        await client.sendTransaction(rawBase64);

        final params = captured!['params'] as List;
        // The base64 body should be passed unchanged
        expect(params[0], equals(rawBase64));
      });

      test('passes optional params: skipPreflight, maxRetries', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw(
          'resultSig',
          onRequest: (body) => captured = body,
        );
        final client = _createClient(mock);

        await client.sendTransaction(
          'base64Tx',
          skipPreflight: true,
          preflightCommitment: SolanaCommitment.processed,
          maxRetries: 3,
        );

        final params = captured!['params'] as List;
        final config = params[1] as Map<String, dynamic>;
        expect(config['skipPreflight'], isTrue);
        expect(config['preflightCommitment'], equals('processed'));
        expect(config['maxRetries'], equals(3));
        expect(config['encoding'], equals('base64'));
      });
    });

    group('simulateTransaction', () {
      test('returns SimulateResult from RpcResponse', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'context': {'slot': 300},
          'value': {
            'err': null,
            'logs': ['Program log: success'],
            'unitsConsumed': 50000,
          },
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        final result = await client.simulateTransaction('base64SimTx');

        expect(result, isA<SimulateResult>());
        expect(result.err, isNull);
        expect(result.logs, contains('Program log: success'));
        expect(result.unitsConsumed, equals(BigInt.from(50000)));

        // Verify default encoding is base64
        final params = captured!['params'] as List;
        final config = params[1] as Map<String, dynamic>;
        expect(config['encoding'], equals('base64'));
      });

      test(
        'passes optional params: sigVerify, replaceRecentBlockhash',
        () async {
          Map<String, dynamic>? captured;
          final mock = _mockClientRaw({
            'context': {'slot': 300},
            'value': {'err': null, 'logs': []},
          }, onRequest: (body) => captured = body);
          final client = _createClient(mock);

          await client.simulateTransaction(
            'base64Tx',
            commitment: SolanaCommitment.confirmed,
            sigVerify: false,
            replaceRecentBlockhash: true,
          );

          final params = captured!['params'] as List;
          final config = params[1] as Map<String, dynamic>;
          expect(config['commitment'], equals('confirmed'));
          expect(config['sigVerify'], isFalse);
          expect(config['replaceRecentBlockhash'], isTrue);
        },
      );
    });
  });
}
