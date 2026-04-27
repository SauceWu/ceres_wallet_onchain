import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/evm/evm_rpc_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Creates an [EvmRpcClient] backed by a [MockClient] that returns
/// the given [result] for any JSON-RPC request.
EvmRpcClient _clientWithResult(dynamic result) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final response = {'jsonrpc': '2.0', 'id': body['id'], 'result': result};
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
    httpClient: mockHttp,
  );
  return EvmRpcClient(transport: transport);
}

void main() {
  group('EvmGasMethods', () {
    test('gasPrice returns BigInt', () async {
      // 20 gwei = 20_000_000_000 = 0x4A817C800
      final client = _clientWithResult('0x4a817c800');
      final price = await client.gasPrice();
      expect(price, equals(BigInt.from(20000000000)));
      client.close();
    });

    test('maxPriorityFeePerGas returns BigInt', () async {
      // 2 gwei = 2_000_000_000 = 0x77359400
      final client = _clientWithResult('0x77359400');
      final tip = await client.maxPriorityFeePerGas();
      expect(tip, equals(BigInt.from(2000000000)));
      client.close();
    });

    test('estimateGas returns BigInt', () async {
      // 21000 = 0x5208
      final client = _clientWithResult('0x5208');
      final gas = await client.estimateGas({
        'to': '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
      });
      expect(gas, equals(BigInt.from(21000)));
      client.close();
    });

    test('estimateGas sends blockTag when provided', () async {
      List<dynamic>? capturedParams;
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedParams = body['params'] as List<dynamic>;
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x5208'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = JsonRpcTransport(
        config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
        httpClient: mockHttp,
      );
      final client = EvmRpcClient(transport: transport);

      await client.estimateGas({'to': '0x1'}, blockTag: 'pending');
      expect(capturedParams, hasLength(2));
      expect(capturedParams![1], equals('pending'));
      client.close();
    });

    test('blobBaseFee returns BigInt', () async {
      final client = _clientWithResult('0x1');
      final fee = await client.blobBaseFee();
      expect(fee, equals(BigInt.one));
      client.close();
    });

    test('feeHistory returns EthFeeHistory with all fields', () async {
      final feeHistoryResult = {
        'oldestBlock': '0xa',
        'baseFeePerGas': ['0x3b9aca00', '0x3b9aca01', '0x3b9aca02'],
        'gasUsedRatio': [0.5, 0.8],
        'reward': [
          ['0x3b9aca00', '0x77359400'],
          ['0x3b9aca01', '0x77359401'],
        ],
      };
      final client = _clientWithResult(feeHistoryResult);
      final history = await client.feeHistory(2, 'latest', [25.0, 50.0]);

      expect(history.oldestBlock, equals(BigInt.from(10)));
      expect(history.baseFeePerGas.length, equals(3)); // N+1
      expect(history.gasUsedRatio.length, equals(2));
      expect(history.gasUsedRatio[0], equals(0.5));
      expect(history.reward, isNotNull);
      expect(history.reward!.length, equals(2));
      expect(history.reward![0].length, equals(2));
      client.close();
    });

    test('feeHistory sends blockCount as hex QUANTITY', () async {
      List<dynamic>? capturedParams;
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedParams = body['params'] as List<dynamic>;
        final result = {
          'oldestBlock': '0x1',
          'baseFeePerGas': ['0x1', '0x2'],
          'gasUsedRatio': [0.5],
        };
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
      final client = EvmRpcClient(transport: transport);

      await client.feeHistory(10, 'latest', [25.0]);
      expect(capturedParams![0], equals('0xa')); // 10 in hex
      client.close();
    });

    test('createAccessList returns EthAccessListResult', () async {
      final accessListResult = {
        'accessList': [
          {
            'address': '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
            'storageKeys': [
              '0x0000000000000000000000000000000000000000000000000000000000000001',
            ],
          },
        ],
        'gasUsed': '0x7a120', // 500000
      };
      final client = _clientWithResult(accessListResult);
      final result = await client.createAccessList({
        'to': '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
        'data': '0x',
      });
      expect(result.gasUsed, equals(BigInt.from(500000)));
      expect(result.accessList.length, equals(1));
      expect(result.accessList[0].storageKeys.length, equals(1));
      client.close();
    });

    test('sends correct RPC method names', () async {
      final methods = <String>[];
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        methods.add(body['method'] as String);
        dynamic result;
        switch (body['method']) {
          case 'eth_feeHistory':
            result = {
              'oldestBlock': '0x1',
              'baseFeePerGas': ['0x1', '0x2'],
              'gasUsedRatio': [0.5],
            };
            break;
          case 'eth_createAccessList':
            result = {'accessList': <Map<String, dynamic>>[], 'gasUsed': '0x0'};
            break;
          default:
            result = '0x0';
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
      final client = EvmRpcClient(transport: transport);

      await client.gasPrice();
      await client.maxPriorityFeePerGas();
      await client.feeHistory(1, 'latest', []);
      await client.estimateGas({});
      await client.createAccessList({});
      await client.blobBaseFee();

      expect(methods, [
        'eth_gasPrice',
        'eth_maxPriorityFeePerGas',
        'eth_feeHistory',
        'eth_estimateGas',
        'eth_createAccessList',
        'eth_blobBaseFee',
      ]);
      client.close();
    });
  });
}
