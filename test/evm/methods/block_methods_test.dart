import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/evm/methods/block_methods.dart';

class _TestBlockClient with EvmBlockMethods {
  @override
  final JsonRpcTransport transport;
  _TestBlockClient(this.transport);
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

/// Minimal block JSON for hash-only mode.
Map<String, dynamic> _blockJsonHashMode() => {
  'number': '0x10',
  'hash': '0xblock_hash',
  'parentHash': '0xparent_hash',
  'nonce': '0x0000000000000000',
  'sha3Uncles': '0xuncles_hash',
  'logsBloom': '0x${'00' * 256}',
  'transactionsRoot': '0xtx_root',
  'stateRoot': '0xstate_root',
  'receiptsRoot': '0xreceipts_root',
  'miner': '0x0000000000000000000000000000000000000001',
  'difficulty': '0x0',
  'totalDifficulty': '0x0',
  'extraData': '0x',
  'size': '0x100',
  'gasLimit': '0x1c9c380',
  'gasUsed': '0xf4240',
  'timestamp': '0x6400',
  'uncles': <String>[],
  'mixHash': '0xmix',
  'transactions': ['0xtx1', '0xtx2'],
};

/// Minimal block JSON for full-transaction mode.
Map<String, dynamic> _blockJsonFullTxMode() {
  final block = _blockJsonHashMode();
  block['transactions'] = [
    {
      'blockHash': '0xblock_hash',
      'blockNumber': '0x10',
      'from': '0x0000000000000000000000000000000000000001',
      'gas': '0x5208',
      'hash': '0xtx1',
      'input': '0x',
      'nonce': '0x0',
      'to': '0x0000000000000000000000000000000000000002',
      'transactionIndex': '0x0',
      'value': '0xde0b6b3a7640000',
      'type': '0x0',
      'v': '0x1b',
      'r': '0x1',
      's': '0x2',
      'gasPrice': '0x3b9aca00',
    },
  ];
  return block;
}

void main() {
  const config = RpcClientConfig(baseUrl: 'http://localhost:8545');

  group('EvmBlockMethods', () {
    test(
      'getBlockByNumber with fullTransactions=false returns hash list',
      () async {
        final mock = _mockClient(_blockJsonHashMode());
        final client = _TestBlockClient(
          JsonRpcTransport(config: config, httpClient: mock),
        );

        final block = await client.getBlockByNumber();
        expect(block, isNotNull);
        expect(block!.number, equals(BigInt.from(16)));
        expect(block.transactionHashes, equals(['0xtx1', '0xtx2']));
        expect(block.transactions, isNull);
      },
    );

    test(
      'getBlockByNumber with fullTransactions=true returns EthTransaction list',
      () async {
        final mock = _mockClient(_blockJsonFullTxMode());
        final client = _TestBlockClient(
          JsonRpcTransport(config: config, httpClient: mock),
        );

        final block = await client.getBlockByNumber(fullTransactions: true);
        expect(block, isNotNull);
        expect(block!.transactions, isNotNull);
        expect(block.transactions!.length, equals(1));
        expect(block.transactions!.first.hash, equals('0xtx1'));
        expect(block.transactionHashes, isNull);
      },
    );

    test('getBlockByNumber sends correct RPC method and params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_blockJsonHashMode(), (body) {
        captured = body;
      });
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlockByNumber(blockTag: '0x1b4', fullTransactions: true);
      expect(captured!['method'], equals('eth_getBlockByNumber'));
      expect(captured!['params'], equals(['0x1b4', true]));
    });

    test('getBlockByHash returning null (block not found)', () async {
      final mock = _mockClient(null);
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final block = await client.getBlockByHash('0xnonexistent');
      expect(block, isNull);
    });

    test('getBlockByHash sends correct RPC method and params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_blockJsonHashMode(), (body) {
        captured = body;
      });
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlockByHash('0xabc', fullTransactions: true);
      expect(captured!['method'], equals('eth_getBlockByHash'));
      expect(captured!['params'], equals(['0xabc', true]));
    });

    test('getBlockTransactionCountByHash returning count', () async {
      final mock = _mockClient('0xa');
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final count = await client.getBlockTransactionCountByHash('0xblock');
      expect(count, equals(BigInt.from(10)));
    });

    test('getBlockTransactionCountByHash returning null', () async {
      final mock = _mockClient(null);
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final count = await client.getBlockTransactionCountByHash('0xmissing');
      expect(count, isNull);
    });

    test('getBlockTransactionCountByNumber sends correct params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture('0x5', (body) {
        captured = body;
      });
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final count = await client.getBlockTransactionCountByNumber(
        blockTag: '0x100',
      );
      expect(count, equals(BigInt.from(5)));
      expect(
        captured!['method'],
        equals('eth_getBlockTransactionCountByNumber'),
      );
      expect(captured!['params'], equals(['0x100']));
    });

    test('getUncleCountByBlockHash returns count', () async {
      final mock = _mockClient('0x2');
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final count = await client.getUncleCountByBlockHash('0xblock');
      expect(count, equals(BigInt.from(2)));
    });

    test('getUncleCountByBlockNumber returns null', () async {
      final mock = _mockClient(null);
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final count = await client.getUncleCountByBlockNumber();
      expect(count, isNull);
    });

    test('getUncleByBlockHashAndIndex sends hex index', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_blockJsonHashMode(), (body) {
        captured = body;
      });
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getUncleByBlockHashAndIndex('0xblock', 2);
      expect(captured!['method'], equals('eth_getUncleByBlockHashAndIndex'));
      expect(captured!['params'], equals(['0xblock', '0x2']));
    });

    test('getUncleByBlockNumberAndIndex sends hex index', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_blockJsonHashMode(), (body) {
        captured = body;
      });
      final client = _TestBlockClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getUncleByBlockNumberAndIndex(blockTag: '0x100', index: 15);
      expect(captured!['method'], equals('eth_getUncleByBlockNumberAndIndex'));
      expect(captured!['params'], equals(['0x100', '0xf']));
    });
  });
}
