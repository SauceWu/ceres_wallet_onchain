import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/evm/methods/transaction_methods.dart';

class _TestTxClient with EvmTransactionMethods {
  @override
  final JsonRpcTransport transport;
  _TestTxClient(this.transport);
}

/// Creates a [MockClient] that returns [result] for any JSON-RPC request.
MockClient _mockClient(dynamic result) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Creates a [MockClient] that captures the request and returns [result].
MockClient _mockClientCapture(
  dynamic result,
  void Function(Map<String, dynamic> body) onRequest,
) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    onRequest(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Minimal transaction JSON for a legacy (type 0) transaction.
Map<String, dynamic> _txJson() => {
  'blockHash': '0xblock_hash',
  'blockNumber': '0x10',
  'from': '0x0000000000000000000000000000000000000001',
  'gas': '0x5208',
  'hash': '0xtx_hash_123',
  'input': '0x',
  'nonce': '0x5',
  'to': '0x0000000000000000000000000000000000000002',
  'transactionIndex': '0x0',
  'value': '0xde0b6b3a7640000',
  'type': '0x0',
  'v': '0x1b',
  'r': '0x1',
  's': '0x2',
  'gasPrice': '0x3b9aca00',
};

/// Minimal transaction receipt JSON.
Map<String, dynamic> _receiptJson() => {
  'transactionHash': '0xtx_hash_123',
  'transactionIndex': '0x0',
  'blockHash': '0xblock_hash',
  'blockNumber': '0x10',
  'from': '0x0000000000000000000000000000000000000001',
  'to': '0x0000000000000000000000000000000000000002',
  'cumulativeGasUsed': '0x5208',
  'effectiveGasPrice': '0x3b9aca00',
  'gasUsed': '0x5208',
  'contractAddress': null,
  'logs': [
    {
      'address': '0x0000000000000000000000000000000000000003',
      'topics': ['0xtopic1'],
      'data': '0x',
      'blockNumber': '0x10',
      'transactionHash': '0xtx_hash_123',
      'transactionIndex': '0x0',
      'blockHash': '0xblock_hash',
      'logIndex': '0x0',
      'removed': false,
    },
  ],
  'logsBloom': '0x${'00' * 256}',
  'type': '0x0',
  'status': '0x1',
};

void main() {
  const config = RpcClientConfig(baseUrl: 'http://localhost:8545');

  group('EvmTransactionMethods', () {
    test('getTransactionByHash with valid response', () async {
      final mock = _mockClient(_txJson());
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final tx = await client.getTransactionByHash('0xtx_hash_123');
      expect(tx, isNotNull);
      expect(tx!.hash, equals('0xtx_hash_123'));
      expect(tx.type, equals(0));
      expect(tx.nonce, equals(BigInt.from(5)));
      expect(tx.gas, equals(BigInt.from(21000)));
    });

    test('getTransactionByHash returning null', () async {
      final mock = _mockClient(null);
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final tx = await client.getTransactionByHash('0xnonexistent');
      expect(tx, isNull);
    });

    test('getTransactionByHash sends correct RPC method', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_txJson(), (body) {
        captured = body;
      });
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getTransactionByHash('0xabc');
      expect(captured!['method'], equals('eth_getTransactionByHash'));
      expect(captured!['params'], equals(['0xabc']));
    });

    test('getTransactionByBlockHashAndIndex sends hex index', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_txJson(), (body) {
        captured = body;
      });
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getTransactionByBlockHashAndIndex('0xblock', 3);
      expect(
        captured!['method'],
        equals('eth_getTransactionByBlockHashAndIndex'),
      );
      expect(captured!['params'], equals(['0xblock', '0x3']));
    });

    test('getTransactionByBlockNumberAndIndex sends hex index', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_txJson(), (body) {
        captured = body;
      });
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getTransactionByBlockNumberAndIndex(
        blockTag: '0x100',
        index: 10,
      );
      expect(
        captured!['method'],
        equals('eth_getTransactionByBlockNumberAndIndex'),
      );
      expect(captured!['params'], equals(['0x100', '0xa']));
    });

    test('getTransactionReceipt with valid response', () async {
      final mock = _mockClient(_receiptJson());
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final receipt = await client.getTransactionReceipt('0xtx_hash_123');
      expect(receipt, isNotNull);
      expect(receipt!.transactionHash, equals('0xtx_hash_123'));
      expect(receipt.status, equals(BigInt.one));
      expect(receipt.logs.length, equals(1));
      expect(receipt.gasUsed, equals(BigInt.from(21000)));
    });

    test('getTransactionReceipt returning null (pending)', () async {
      final mock = _mockClient(null);
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final receipt = await client.getTransactionReceipt('0xpending_tx');
      expect(receipt, isNull);
    });

    test('getBlockReceipts with list response', () async {
      final mock = _mockClient([_receiptJson(), _receiptJson()]);
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final receipts = await client.getBlockReceipts(blockTag: '0x10');
      expect(receipts, isNotNull);
      expect(receipts!.length, equals(2));
      expect(receipts[0].transactionHash, equals('0xtx_hash_123'));
    });

    test('getBlockReceipts returning null (unsupported)', () async {
      final mock = _mockClient(null);
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final receipts = await client.getBlockReceipts();
      expect(receipts, isNull);
    });

    test('getBlockReceipts sends correct params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture([], (body) {
        captured = body;
      });
      final client = _TestTxClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlockReceipts(blockTag: 'latest');
      expect(captured!['method'], equals('eth_getBlockReceipts'));
      expect(captured!['params'], equals(['latest']));
    });
  });
}
