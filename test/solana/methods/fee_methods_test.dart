import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/fee_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/models/blockhash_result.dart';
import 'package:ceres_wallet_onchain/src/solana/models/prioritization_fee.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Test helper that mixes in [SolanaFeeMethods].
class _TestClient with SolanaFeeMethods {
  @override
  final JsonRpcTransport transport;
  _TestClient(this.transport);
}

/// Creates a [MockClient] that returns a raw result.
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
  group('SolanaFeeMethods', () {
    group('getLatestBlockhash', () {
      test('returns BlockhashResult from RpcResponse', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 500},
          'value': {
            'blockhash': 'GHtXQBtaU7SZByFnHg2RTcYVRMJXGe7NzACe66hCPpSM',
            'lastValidBlockHeight': 150000000,
          },
        });
        final client = _createClient(mock);

        final result = await client.getLatestBlockhash();

        expect(result, isA<BlockhashResult>());
        expect(
          result.blockhash,
          equals('GHtXQBtaU7SZByFnHg2RTcYVRMJXGe7NzACe66hCPpSM'),
        );
        expect(result.lastValidBlockHeight, equals(150000000));
      });

      test('passes commitment when provided', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'context': {'slot': 500},
          'value': {'blockhash': 'hash123', 'lastValidBlockHeight': 100},
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getLatestBlockhash(commitment: SolanaCommitment.finalized);

        final params = captured!['params'] as List;
        final config = params[0] as Map<String, dynamic>;
        expect(config['commitment'], equals('finalized'));
      });
    });

    group('isBlockhashValid', () {
      test('returns true when valid', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 600},
          'value': true,
        });
        final client = _createClient(mock);

        final result = await client.isBlockhashValid('validBlockhash');
        expect(result, isTrue);
      });

      test('returns false when invalid', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 600},
          'value': false,
        });
        final client = _createClient(mock);

        final result = await client.isBlockhashValid('expiredBlockhash');
        expect(result, isFalse);
      });

      test('passes blockhash as first param', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'context': {'slot': 600},
          'value': true,
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.isBlockhashValid(
          'myBlockhash',
          commitment: SolanaCommitment.processed,
        );

        final params = captured!['params'] as List;
        expect(params[0], equals('myBlockhash'));
        final config = params[1] as Map<String, dynamic>;
        expect(config['commitment'], equals('processed'));
      });
    });

    group('getFeeForMessage', () {
      test('returns BigInt when fee is available', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 700},
          'value': 5000,
        });
        final client = _createClient(mock);

        final result = await client.getFeeForMessage('base64Message==');
        expect(result, equals(BigInt.from(5000)));
      });

      test('returns null when value is null', () async {
        final mock = _mockClientRaw({
          'context': {'slot': 700},
          'value': null,
        });
        final client = _createClient(mock);

        final result = await client.getFeeForMessage('invalidMessage');
        expect(result, isNull);
      });

      test('sends correct params', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw({
          'context': {'slot': 700},
          'value': 5000,
        }, onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getFeeForMessage(
          'base64Msg',
          commitment: SolanaCommitment.confirmed,
        );

        final params = captured!['params'] as List;
        expect(params[0], equals('base64Msg'));
        final config = params[1] as Map<String, dynamic>;
        expect(config['commitment'], equals('confirmed'));
      });
    });

    group('getMinimumBalanceForRentExemption', () {
      test('returns BigInt for data length', () async {
        final mock = _mockClientRaw(2039280);
        final client = _createClient(mock);

        final result = await client.getMinimumBalanceForRentExemption(165);
        expect(result, equals(BigInt.from(2039280)));
      });

      test('sends data length as first param', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw(
          890880,
          onRequest: (body) => captured = body,
        );
        final client = _createClient(mock);

        await client.getMinimumBalanceForRentExemption(
          0,
          commitment: SolanaCommitment.finalized,
        );

        final params = captured!['params'] as List;
        expect(params[0], equals(0));
        final config = params[1] as Map<String, dynamic>;
        expect(config['commitment'], equals('finalized'));
      });
    });

    group('getRecentPrioritizationFees', () {
      test('returns List<PrioritizationFee>', () async {
        final mock = _mockClientRaw([
          {'slot': 100, 'prioritizationFee': 500},
          {'slot': 101, 'prioritizationFee': 1000},
        ]);
        final client = _createClient(mock);

        final result = await client.getRecentPrioritizationFees();

        expect(result, hasLength(2));
        expect(result[0], isA<PrioritizationFee>());
        expect(result[0].slot, equals(100));
        expect(result[0].prioritizationFee, equals(BigInt.from(500)));
        expect(result[1].prioritizationFee, equals(BigInt.from(1000)));
      });

      test('passes addresses when provided', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw([], onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getRecentPrioritizationFees(addresses: ['addr1', 'addr2']);

        final params = captured!['params'] as List;
        expect(params[0], equals(['addr1', 'addr2']));
      });

      test('sends empty params when no addresses', () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientRaw([], onRequest: (body) => captured = body);
        final client = _createClient(mock);

        await client.getRecentPrioritizationFees();

        final params = captured!['params'] as List;
        expect(params, isEmpty);
      });
    });
  });
}
