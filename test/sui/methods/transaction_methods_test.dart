import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/transaction_methods.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_dry_run_result.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_options.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_paginated.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_transaction_block_response.dart';
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
    config: RpcClientConfig(baseUrl: 'https://fullnode.testnet.sui.io'),
    httpClient: mockClient,
  );
}

/// Test harness that uses [SuiTransactionMethods] via a concrete class.
class _TestClient with SuiTransactionMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);
}

/// Minimal effects JSON for test responses.
Map<String, dynamic> _minimalEffects() => {
  'status': {'status': 'success'},
  'gasUsed': {
    'computationCost': '1000',
    'storageCost': '500',
    'storageRebate': '200',
    'nonRefundableStorageFee': '0',
  },
  'transactionDigest': 'TestDigest123',
};

void main() {
  const testDigest = 'Abc123TransactionDigest';

  group('SuiTransactionMethods', () {
    group('getTransactionBlock', () {
      test('sends sui_getTransactionBlock with digest and options', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return {'digest': testDigest, 'effects': _minimalEffects()};
        });
        final client = _TestClient(transport);

        final result = await client.getTransactionBlock(
          testDigest,
          options: const SuiTransactionBlockResponseOptions(showEffects: true),
        );

        expect(capturedRequest['method'], 'sui_getTransactionBlock');
        final params = capturedRequest['params'] as List;
        expect(params[0], testDigest);
        expect((params[1] as Map)['showEffects'], true);
        expect(result, isA<SuiTransactionBlockResponse>());
        expect(result.digest, testDigest);
      });

      test('sends null options when not provided', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          capturedParams = req['params'] as List;
          return {'digest': testDigest};
        });
        final client = _TestClient(transport);

        await client.getTransactionBlock(testDigest);

        expect(capturedParams[1], isNull);
      });
    });

    group('multiGetTransactionBlocks', () {
      test('sends sui_multiGetTransactionBlocks with digests', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return [
            {'digest': 'Digest1'},
            {'digest': 'Digest2'},
          ];
        });
        final client = _TestClient(transport);

        final result = await client.multiGetTransactionBlocks([
          'Digest1',
          'Digest2',
        ], options: SuiTransactionBlockResponseOptions.all);

        expect(capturedRequest['method'], 'sui_multiGetTransactionBlocks');
        final params = capturedRequest['params'] as List;
        expect(params[0], ['Digest1', 'Digest2']);
        expect(result.length, 2);
        expect(result[0].digest, 'Digest1');
        expect(result[1].digest, 'Digest2');
      });
    });

    group('queryTransactionBlocks', () {
      test('sends sui_queryTransactionBlocks with packed params', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return {
            'data': [
              {'digest': 'QDigest1'},
            ],
            'hasNextPage': true,
            'nextCursor': 'cursor123',
          };
        });
        final client = _TestClient(transport);

        final result = await client.queryTransactionBlocks(
          filter: {'FromAddress': '0xabc'},
          options: const SuiTransactionBlockResponseOptions(showEffects: true),
          cursor: 'prevCursor',
          limit: 10,
          descendingOrder: true,
        );

        expect(capturedRequest['method'], 'sui_queryTransactionBlocks');
        final params = capturedRequest['params'] as List;
        final queryParam = params[0] as Map<String, dynamic>;
        expect(queryParam['filter'], {'FromAddress': '0xabc'});
        expect((queryParam['options'] as Map)['showEffects'], true);
        expect(queryParam['cursor'], 'prevCursor');
        expect(queryParam['limit'], 10);
        expect(queryParam['order'], 'descending');
        expect(
          result,
          isA<SuiPaginatedResponse<SuiTransactionBlockResponse>>(),
        );
        expect(result.data.length, 1);
        expect(result.hasNextPage, true);
        expect(result.nextCursor, 'cursor123');
      });

      test('uses ascending order by default', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return {'data': [], 'hasNextPage': false};
        });
        final client = _TestClient(transport);

        await client.queryTransactionBlocks();

        final params = capturedRequest['params'] as List;
        final queryParam = params[0] as Map<String, dynamic>;
        expect(queryParam['order'], 'ascending');
      });
    });

    group('getTotalTransactionBlocks', () {
      test('returns BigInt from string result', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return '999999999999';
        });
        final client = _TestClient(transport);

        final result = await client.getTotalTransactionBlocks();

        expect(capturedRequest['method'], 'sui_getTotalTransactionBlocks');
        expect(result, BigInt.parse('999999999999'));
      });
    });

    group('dryRunTransactionBlock', () {
      test(
        'sends sui_dryRunTransactionBlock and returns SuiDryRunResult',
        () async {
          late Map<String, dynamic> capturedRequest;
          final transport = _createMockTransport((req) {
            capturedRequest = req;
            return {
              'effects': _minimalEffects(),
              'events': [],
              'balanceChanges': [],
            };
          });
          final client = _TestClient(transport);

          final result = await client.dryRunTransactionBlock('base64TxBytes==');

          expect(capturedRequest['method'], 'sui_dryRunTransactionBlock');
          final params = capturedRequest['params'] as List;
          expect(params[0], 'base64TxBytes==');
          expect(result, isA<SuiDryRunResult>());
          expect(result.effects.status.isSuccess, true);
        },
      );
    });

    group('devInspectTransactionBlock', () {
      test(
        'sends sui_devInspectTransactionBlock with sender and txBytes',
        () async {
          late Map<String, dynamic> capturedRequest;
          final transport = _createMockTransport((req) {
            capturedRequest = req;
            return {'effects': _minimalEffects(), 'results': []};
          });
          final client = _TestClient(transport);

          final result = await client.devInspectTransactionBlock(
            '0xSenderAddr',
            'base64TxBytes==',
            gasPrice: BigInt.from(1000),
            epoch: '100',
          );

          expect(capturedRequest['method'], 'sui_devInspectTransactionBlock');
          final params = capturedRequest['params'] as List;
          expect(params[0], '0xSenderAddr');
          expect(params[1], 'base64TxBytes==');
          expect(params[2], '1000');
          expect(params[3], '100');
          expect(result, isA<Map<String, dynamic>>());
          expect(result['effects'], isNotNull);
        },
      );
    });

    group('executeTransactionBlock', () {
      test(
        'sends sui_executeTransactionBlock with txBytes and signatures passthrough',
        () async {
          late Map<String, dynamic> capturedRequest;
          final transport = _createMockTransport((req) {
            capturedRequest = req;
            return {'digest': 'ExecDigest123', 'confirmedLocalExecution': true};
          });
          final client = _TestClient(transport);

          final txBytes = 'AAACbase64txbytes==';
          final signatures = ['sig1base64==', 'sig2base64=='];

          final result = await client.executeTransactionBlock(
            txBytes,
            signatures,
            options: const SuiTransactionBlockResponseOptions(
              showEffects: true,
            ),
          );

          expect(capturedRequest['method'], 'sui_executeTransactionBlock');
          final params = capturedRequest['params'] as List;
          // txBytes passed through as-is
          expect(params[0], txBytes);
          // signatures passed through as-is
          expect(params[1], signatures);
          // options
          expect((params[2] as Map)['showEffects'], true);
          // requestType
          expect(params[3], 'WaitForLocalExecution');
          expect(result, isA<SuiTransactionBlockResponse>());
          expect(result.digest, 'ExecDigest123');
        },
      );

      test(
        'does not contain any signing logic - signatures are passthrough',
        () async {
          final transport = _createMockTransport((req) {
            final params = req['params'] as List;
            // Verify signatures are exactly what was passed in
            expect(params[1], ['exactSig1', 'exactSig2']);
            return {'digest': 'TestDigest'};
          });
          final client = _TestClient(transport);

          await client.executeTransactionBlock('txBytes', [
            'exactSig1',
            'exactSig2',
          ]);
        },
      );
    });
  });
}
