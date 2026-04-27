import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/evm/evm_address.dart';
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
  final testAddr = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');

  group('EvmAccountMethods', () {
    test('getBalance returns BigInt from hex response', () async {
      // 1 ETH = 1e18 wei = 0xDE0B6B3A7640000
      final client = _clientWithResult('0xde0b6b3a7640000');
      final balance = await client.getBalance(testAddr);
      expect(balance, equals(BigInt.parse('1000000000000000000')));
      client.close();
    });

    test('getBalance with custom blockTag', () async {
      String? capturedBody;
      final mockHttp = MockClient((request) async {
        capturedBody = request.body;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x0'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final transport = JsonRpcTransport(
        config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
        httpClient: mockHttp,
      );
      final client = EvmRpcClient(transport: transport);

      await client.getBalance(testAddr, blockTag: '0x1');
      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['params'][1], equals('0x1'));
      client.close();
    });

    test('getBalance returns zero', () async {
      final client = _clientWithResult('0x0');
      final balance = await client.getBalance(testAddr);
      expect(balance, equals(BigInt.zero));
      client.close();
    });

    test('getStorageAt returns hex string', () async {
      const storageValue =
          '0x0000000000000000000000000000000000000000000000000000000000000001';
      final client = _clientWithResult(storageValue);
      final result = await client.getStorageAt(testAddr, BigInt.zero);
      expect(result, equals(storageValue));
      client.close();
    });

    test('getTransactionCount returns BigInt nonce', () async {
      final client = _clientWithResult('0x5');
      final nonce = await client.getTransactionCount(testAddr);
      expect(nonce, equals(BigInt.from(5)));
      client.close();
    });

    test('getCode returns hex bytecode', () async {
      const code = '0x6080604052';
      final client = _clientWithResult(code);
      final result = await client.getCode(testAddr);
      expect(result, equals(code));
      client.close();
    });

    test('getCode returns 0x for EOA', () async {
      final client = _clientWithResult('0x');
      final result = await client.getCode(testAddr);
      expect(result, equals('0x'));
      client.close();
    });

    test('getProof returns EthProof', () async {
      final proofResult = {
        'address': '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
        'accountProof': ['0xabc', '0xdef'],
        'balance': '0xde0b6b3a7640000',
        'codeHash':
            '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
        'nonce': '0x0',
        'storageHash':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'storageProof': [
          {
            'key':
                '0x0000000000000000000000000000000000000000000000000000000000000001',
            'value': '0x1',
            'proof': ['0x111', '0x222'],
          },
        ],
      };
      final client = _clientWithResult(proofResult);
      final proof = await client.getProof(testAddr, ['0x1']);
      expect(proof.balance, equals(BigInt.parse('1000000000000000000')));
      expect(proof.nonce, equals(BigInt.zero));
      expect(proof.storageProof.length, equals(1));
      expect(proof.storageProof[0].value, equals(BigInt.one));
      client.close();
    });

    test('sends correct RPC method names', () async {
      final methods = <String>[];
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        methods.add(body['method'] as String);
        // Return appropriate response for each method
        dynamic result;
        switch (body['method']) {
          case 'eth_getBalance':
          case 'eth_getTransactionCount':
            result = '0x0';
            break;
          case 'eth_getStorageAt':
          case 'eth_getCode':
            result = '0x';
            break;
          case 'eth_getProof':
            result = {
              'address': '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
              'accountProof': <String>[],
              'balance': '0x0',
              'codeHash': '0x00',
              'nonce': '0x0',
              'storageHash': '0x00',
              'storageProof': <Map<String, dynamic>>[],
            };
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

      await client.getBalance(testAddr);
      await client.getStorageAt(testAddr, BigInt.zero);
      await client.getTransactionCount(testAddr);
      await client.getCode(testAddr);
      await client.getProof(testAddr, []);

      expect(methods, [
        'eth_getBalance',
        'eth_getStorageAt',
        'eth_getTransactionCount',
        'eth_getCode',
        'eth_getProof',
      ]);
      client.close();
    });
  });
}
