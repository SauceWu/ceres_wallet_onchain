import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/chain_methods.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [SuiChainMethods] for testing.
class _TestClient with SuiChainMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);

  void close() => transport.close();
}

/// Creates a [_TestClient] that returns [result] for any RPC method.
_TestClient _clientWithResult(dynamic result) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
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

/// Creates a [_TestClient] that captures the request and returns [result].
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
  group('SuiChainMethods', () {
    group('getLatestCheckpointSequenceNumber', () {
      test('returns BigInt from string result', () async {
        final client = _clientWithResult('1000000');

        final seq = await client.getLatestCheckpointSequenceNumber();

        expect(seq, equals(BigInt.from(1000000)));

        client.close();
      });

      test('sends correct RPC method name', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing('42', (body) => captured = body);

        await client.getLatestCheckpointSequenceNumber();

        expect(captured!['method'], 'sui_getLatestCheckpointSequenceNumber');
        expect(captured!['params'], isEmpty);

        client.close();
      });
    });

    group('getCheckpoint', () {
      test('returns SuiCheckpoint', () async {
        final client = _clientWithResult({
          'epoch': '100',
          'sequenceNumber': '5000',
          'digest': 'Abc123',
          'networkTotalTransactions': '999999',
          'timestampMs': '1700000000000',
          'previousDigest': 'Xyz789',
          'epochRollingGasCostSummary': {
            'computationCost': '100',
            'storageCost': '200',
            'storageRebate': '50',
            'nonRefundableStorageFee': '10',
          },
          'transactions': ['tx1', 'tx2'],
        });

        final cp = await client.getCheckpoint('5000');

        expect(cp.epoch, '100');
        expect(cp.sequenceNumber, equals(BigInt.from(5000)));
        expect(cp.digest, 'Abc123');
        expect(cp.transactions, hasLength(2));

        client.close();
      });

      test('sends checkpoint id as param', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'epoch': '1',
          'sequenceNumber': '1',
          'digest': 'd',
          'networkTotalTransactions': '1',
          'timestampMs': '0',
          'epochRollingGasCostSummary': {
            'computationCost': '0',
            'storageCost': '0',
            'storageRebate': '0',
            'nonRefundableStorageFee': '0',
          },
          'transactions': [],
        }, (body) => captured = body);

        await client.getCheckpoint('myDigest');

        expect(captured!['method'], 'sui_getCheckpoint');
        expect(captured!['params'], ['myDigest']);

        client.close();
      });
    });

    group('getCheckpoints', () {
      test('returns paginated checkpoints', () async {
        final client = _clientWithResult({
          'data': [
            {
              'epoch': '1',
              'sequenceNumber': '10',
              'digest': 'd1',
              'networkTotalTransactions': '100',
              'timestampMs': '0',
              'epochRollingGasCostSummary': {
                'computationCost': '0',
                'storageCost': '0',
                'storageRebate': '0',
                'nonRefundableStorageFee': '0',
              },
              'transactions': [],
            },
          ],
          'hasNextPage': true,
          'nextCursor': '11',
        });

        final page = await client.getCheckpoints();

        expect(page.data, hasLength(1));
        expect(page.data[0].sequenceNumber, equals(BigInt.from(10)));
        expect(page.hasNextPage, isTrue);
        expect(page.nextCursor, '11');

        client.close();
      });

      test('sends cursor, limit, descendingOrder params', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'data': [],
          'hasNextPage': false,
          'nextCursor': null,
        }, (body) => captured = body);

        await client.getCheckpoints(
          cursor: '5',
          limit: 10,
          descendingOrder: true,
        );

        expect(captured!['method'], 'sui_getCheckpoints');
        expect(captured!['params'], ['5', 10, true]);

        client.close();
      });
    });

    group('getChainIdentifier', () {
      test('returns chain identifier string', () async {
        final client = _clientWithResult('4c78adac');

        final id = await client.getChainIdentifier();

        expect(id, '4c78adac');

        client.close();
      });

      test('sends correct RPC method', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing('abc', (body) => captured = body);

        await client.getChainIdentifier();

        expect(captured!['method'], 'sui_getChainIdentifier');
        expect(captured!['params'], isEmpty);

        client.close();
      });
    });

    group('getProtocolConfig', () {
      test('returns SuiProtocolConfig', () async {
        final client = _clientWithResult({
          'protocolVersion': '50',
          'minSupportedProtocolVersion': '1',
          'maxSupportedProtocolVersion': '50',
          'attributes': {
            'max_gas': {'u64': '1000000'},
          },
          'featureFlags': {'bridge': true},
        });

        final config = await client.getProtocolConfig();

        expect(config.protocolVersion, '50');
        expect(config.attributes['max_gas'], isNotNull);

        client.close();
      });

      test('sends version param when provided', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'protocolVersion': '30',
          'minSupportedProtocolVersion': '1',
          'maxSupportedProtocolVersion': '50',
        }, (body) => captured = body);

        await client.getProtocolConfig(version: BigInt.from(30));

        expect(captured!['method'], 'sui_getProtocolConfig');
        expect(captured!['params'], ['30']);

        client.close();
      });

      test('sends empty params when version is null', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'protocolVersion': '50',
          'minSupportedProtocolVersion': '1',
          'maxSupportedProtocolVersion': '50',
        }, (body) => captured = body);

        await client.getProtocolConfig();

        expect(captured!['params'], isEmpty);

        client.close();
      });
    });

    group('getLatestSuiSystemState', () {
      test('returns SuiSystemState', () async {
        final client = _clientWithResult({
          'epoch': '200',
          'protocolVersion': '50',
          'systemStateVersion': '2',
          'referenceGasPrice': '750',
          'safeMode': false,
        });

        final state = await client.getLatestSuiSystemState();

        expect(state.epoch, '200');
        expect(state.referenceGasPrice, equals(BigInt.from(750)));
        expect(state.safeMode, isFalse);

        client.close();
      });

      test('sends correct RPC method', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'epoch': '1',
          'protocolVersion': '1',
          'systemStateVersion': '1',
          'referenceGasPrice': '1',
          'safeMode': false,
        }, (body) => captured = body);

        await client.getLatestSuiSystemState();

        expect(captured!['method'], 'suix_getLatestSuiSystemState');
        expect(captured!['params'], isEmpty);

        client.close();
      });
    });

    group('getReferenceGasPrice', () {
      test('returns BigInt from string result', () async {
        final client = _clientWithResult('750');

        final price = await client.getReferenceGasPrice();

        expect(price, equals(BigInt.from(750)));

        client.close();
      });

      test('sends correct RPC method', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing('1000', (body) => captured = body);

        await client.getReferenceGasPrice();

        expect(captured!['method'], 'suix_getReferenceGasPrice');
        expect(captured!['params'], isEmpty);

        client.close();
      });
    });
  });
}
