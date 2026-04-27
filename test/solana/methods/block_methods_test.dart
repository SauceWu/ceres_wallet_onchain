import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/block_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';

class _TestClient with SolanaBlockMethods {
  @override
  final JsonRpcTransport transport;
  _TestClient(this.transport);
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

/// Minimal Solana block JSON.
Map<String, dynamic> _blockJson() => {
  'blockhash': '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
  'previousBlockhash': '4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZAMdL1VZHirAn',
  'parentSlot': 99,
  'blockTime': 1625000000,
  'blockHeight': 100,
  'rewards': <Map<String, dynamic>>[],
  'transactions': [
    {
      'transaction': {
        'signatures': ['sig1'],
        'message': {
          'accountKeys': ['key1'],
          'header': {
            'numRequiredSignatures': 1,
            'numReadonlySignedAccounts': 0,
            'numReadonlyUnsignedAccounts': 0,
          },
          'recentBlockhash': '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
          'instructions': <Map<String, dynamic>>[],
        },
      },
      'meta': {
        'err': null,
        'fee': 5000,
        'preBalances': [10000000],
        'postBalances': [9995000],
        'logMessages': <String>[],
      },
      'version': 0,
    },
  ],
};

/// BlockProduction RPC response (wrapped in RpcResponse value).
Map<String, dynamic> _blockProductionJson() => {
  'byIdentity': {
    '85iYT5RuzRTDgjyRa3cP8SYhM2j21fj7NhfJ3peu1DPr': [100, 97],
  },
  'range': {'firstSlot': 0, 'lastSlot': 99},
};

/// BlockCommitment RPC response (direct, not wrapped).
Map<String, dynamic> _blockCommitmentJson() => {
  'commitment': [0, 0, 0, 1, 2, 3],
  'totalStake': 42000000000,
};

void main() {
  const config = RpcClientConfig(baseUrl: 'http://localhost:8899');

  group('SolanaBlockMethods', () {
    // --- getBlock ---
    test('getBlock returns SolanaBlock on success', () async {
      final mock = _mockClient(_blockJson());
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final block = await client.getBlock(100);
      expect(block, isNotNull);
      expect(
        block!.blockhash,
        equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d'),
      );
      expect(block.parentSlot, equals(99));
      expect(block.blockHeight, equals(100));
    });

    test('getBlock returns null when slot not available', () async {
      final mock = _mockClient(null);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final block = await client.getBlock(999999);
      expect(block, isNull);
    });

    test(
      'getBlock sends maxSupportedTransactionVersion:0 by default',
      () async {
        Map<String, dynamic>? captured;
        final mock = _mockClientCapture(_blockJson(), (body) {
          captured = body;
        });
        final client = _TestClient(
          JsonRpcTransport(config: config, httpClient: mock),
        );

        await client.getBlock(100);
        expect(captured!['method'], equals('getBlock'));
        final params = captured!['params'] as List;
        expect(params[0], equals(100));
        final config2 = params[1] as Map<String, dynamic>;
        expect(config2['maxSupportedTransactionVersion'], equals(0));
      },
    );

    test('getBlock sends transactionDetails when specified', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(_blockJson(), (body) {
        captured = body;
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlock(100, transactionDetails: 'none');
      final params = captured!['params'] as List;
      final config2 = params[1] as Map<String, dynamic>;
      expect(config2['transactionDetails'], equals('none'));
    });

    // --- getBlockHeight ---
    test('getBlockHeight returns int directly', () async {
      final mock = _mockClient(150000);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final height = await client.getBlockHeight();
      expect(height, equals(150000));
    });

    test('getBlockHeight sends commitment param', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture(150000, (body) {
        captured = body;
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlockHeight(commitment: SolanaCommitment.finalized);
      expect(captured!['method'], equals('getBlockHeight'));
      final params = captured!['params'] as List;
      expect((params[0] as Map)['commitment'], equals('finalized'));
    });

    // --- getBlocks ---
    test('getBlocks returns List<int>', () async {
      final mock = _mockClient([5, 6, 7, 8, 9, 10]);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final blocks = await client.getBlocks(5);
      expect(blocks, equals([5, 6, 7, 8, 9, 10]));
    });

    test('getBlocks sends startSlot and optional endSlot', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture([5, 6, 7], (body) {
        captured = body;
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlocks(5, endSlot: 7);
      expect(captured!['method'], equals('getBlocks'));
      final params = captured!['params'] as List;
      expect(params[0], equals(5));
      expect(params[1], equals(7));
    });

    // --- getBlocksWithLimit ---
    test('getBlocksWithLimit returns List<int>', () async {
      final mock = _mockClient([5, 6, 7]);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final blocks = await client.getBlocksWithLimit(5, 3);
      expect(blocks, equals([5, 6, 7]));
    });

    test('getBlocksWithLimit sends correct params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture([5, 6, 7], (body) {
        captured = body;
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getBlocksWithLimit(5, 3);
      expect(captured!['method'], equals('getBlocksWithLimit'));
      final params = captured!['params'] as List;
      expect(params[0], equals(5));
      expect(params[1], equals(3));
    });

    // --- getBlockTime ---
    test('getBlockTime returns int', () async {
      final mock = _mockClient(1625000000);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final time = await client.getBlockTime(100);
      expect(time, equals(1625000000));
    });

    test('getBlockTime returns null when not available', () async {
      final mock = _mockClient(null);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final time = await client.getBlockTime(100);
      expect(time, isNull);
    });

    // --- getBlockProduction ---
    test(
      'getBlockProduction returns BlockProduction from RpcResponse value',
      () async {
        // RpcResponse wrapping: result = { context: ..., value: ... }
        final mock = _mockClient({
          'context': {'slot': 100},
          'value': _blockProductionJson(),
        });
        final client = _TestClient(
          JsonRpcTransport(config: config, httpClient: mock),
        );

        final production = await client.getBlockProduction();
        expect(
          production.byIdentity['85iYT5RuzRTDgjyRa3cP8SYhM2j21fj7NhfJ3peu1DPr'],
          equals([100, 97]),
        );
        expect(production.range['firstSlot'], equals(0));
      },
    );

    // --- getBlockCommitment ---
    test('getBlockCommitment returns BlockCommitment directly', () async {
      final mock = _mockClient(_blockCommitmentJson());
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final commitment = await client.getBlockCommitment(100);
      expect(commitment.commitment, equals([0, 0, 0, 1, 2, 3]));
      expect(commitment.totalStake, equals(BigInt.from(42000000000)));
    });

    // --- getFirstAvailableBlock ---
    test('getFirstAvailableBlock returns int', () async {
      final mock = _mockClient(0);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final slot = await client.getFirstAvailableBlock();
      expect(slot, equals(0));
    });

    // --- getSlot ---
    test('getSlot returns int', () async {
      final mock = _mockClient(150000);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final slot = await client.getSlot();
      expect(slot, equals(150000));
    });

    // --- getSlotLeader ---
    test('getSlotLeader returns String', () async {
      final mock = _mockClient('ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB');
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final leader = await client.getSlotLeader();
      expect(leader, equals('ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB'));
    });

    // --- getSlotLeaders ---
    test('getSlotLeaders returns List<String>', () async {
      final mock = _mockClient([
        'ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB',
        '85iYT5RuzRTDgjyRa3cP8SYhM2j21fj7NhfJ3peu1DPr',
      ]);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final leaders = await client.getSlotLeaders(100, 2);
      expect(leaders, hasLength(2));
      expect(
        leaders[0],
        equals('ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB'),
      );
    });

    test('getSlotLeaders sends correct params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture([
        'leader1',
        'leader2',
      ], (body) => captured = body);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getSlotLeaders(100, 2);
      expect(captured!['method'], equals('getSlotLeaders'));
      final params = captured!['params'] as List;
      expect(params[0], equals(100));
      expect(params[1], equals(2));
    });
  });
}
