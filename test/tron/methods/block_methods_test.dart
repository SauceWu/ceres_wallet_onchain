import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/block_methods.dart';

/// Test harness class that applies the mixin.
class _TestBlockClient with TronBlockMethods {
  @override
  final RestTransport transport;
  _TestBlockClient(this.transport);
}

/// Creates a [MockClient] that captures requests and returns [responseBody].
MockClient _mockClient(
  Object responseBody, {
  void Function(http.Request request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode(responseBody),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Minimal TronBlock JSON fixture.
Map<String, dynamic> _blockJson({int number = 33813686}) => {
  'blockID': '000000000202f4b6a0c54a4d3c5e8d1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d',
  'block_header': {
    'raw_data': {
      'number': number,
      'txTrieRoot': 'abc123',
      'parentHash': 'def456',
      'witness_address': 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
      'timestamp': 1700000000000,
      'version': 29,
    },
    'witness_signature': 'aabbccdd',
  },
  'transactions': [],
};

void main() {
  late String capturedPath;
  late Map<String, dynamic> capturedBody;

  /// Helper: build a client that captures path + body.
  _TestBlockClient buildClient(Object responseBody) {
    final mock = _mockClient(
      responseBody,
      onRequest: (req) {
        capturedPath = req.url.path;
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
      },
    );
    final transport = RestTransport(
      config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
      httpClient: mock,
    );
    return _TestBlockClient(transport);
  }

  group('TronBlockMethods', () {
    // TRON-17: getNowBlock
    test('getNowBlock POSTs to /wallet/getnowblock with empty body', () async {
      final client = buildClient(_blockJson());
      final block = await client.getNowBlock();

      expect(capturedPath, '/wallet/getnowblock');
      expect(capturedBody, isEmpty);
      expect(block.blockHeader?.number, 33813686);
    });

    // TRON-18: getNowBlockSolidity
    test('getNowBlockSolidity POSTs to /walletsolidity/getnowblock', () async {
      final client = buildClient(_blockJson(number: 33813680));
      final block = await client.getNowBlockSolidity();

      expect(capturedPath, '/walletsolidity/getnowblock');
      expect(capturedBody, isEmpty);
      expect(block.blockHeader?.number, 33813680);
    });

    // TRON-19: getBlockByNum
    test('getBlockByNum POSTs num to /wallet/getblockbynum', () async {
      final client = buildClient(_blockJson(number: 100));
      final block = await client.getBlockByNum(100);

      expect(capturedPath, '/wallet/getblockbynum');
      expect(capturedBody['num'], 100);
      expect(block.blockHeader?.number, 100);
    });

    // TRON-20: getBlockByNumSolidity
    test(
      'getBlockByNumSolidity POSTs to /walletsolidity/getblockbynum',
      () async {
        final client = buildClient(_blockJson(number: 99));
        final block = await client.getBlockByNumSolidity(99);

        expect(capturedPath, '/walletsolidity/getblockbynum');
        expect(capturedBody['num'], 99);
        expect(block.blockHeader?.number, 99);
      },
    );

    // TRON-21: getBlockById
    test('getBlockById POSTs value to /wallet/getblockbyid', () async {
      final client = buildClient(_blockJson());
      final block = await client.getBlockById('0000000002abc');

      expect(capturedPath, '/wallet/getblockbyid');
      expect(capturedBody['value'], '0000000002abc');
      expect(block.blockID, isNotNull);
    });

    // TRON-22: getBlockByLimitNext
    test('getBlockByLimitNext returns List<TronBlock>', () async {
      final client = buildClient({
        'block': [_blockJson(number: 1), _blockJson(number: 2)],
      });
      final blocks = await client.getBlockByLimitNext(startNum: 1, endNum: 3);

      expect(capturedPath, '/wallet/getblockbylimitnext');
      expect(capturedBody['startNum'], 1);
      expect(capturedBody['endNum'], 3);
      expect(blocks.length, 2);
      expect(blocks[0].blockHeader?.number, 1);
      expect(blocks[1].blockHeader?.number, 2);
    });

    test('getBlockByLimitNext returns empty list when no blocks', () async {
      final client = buildClient({});
      final blocks = await client.getBlockByLimitNext(startNum: 1, endNum: 1);
      expect(blocks, isEmpty);
    });

    // TRON-23: getBlockByLatestNum
    test('getBlockByLatestNum returns List<TronBlock>', () async {
      final client = buildClient({
        'block': [_blockJson(number: 10), _blockJson(number: 11)],
      });
      final blocks = await client.getBlockByLatestNum(2);

      expect(capturedPath, '/wallet/getblockbylatestnum');
      expect(capturedBody['num'], 2);
      expect(blocks.length, 2);
    });

    // TRON-24: getBlock
    test(
      'getBlock POSTs to /wallet/getblock with idOrNum and detail',
      () async {
        final client = buildClient(_blockJson(number: 500));
        final block = await client.getBlock(idOrNum: '500', detail: true);

        expect(capturedPath, '/wallet/getblock');
        expect(capturedBody['id_or_num'], '500');
        expect(capturedBody['detail'], true);
        expect(block.blockHeader?.number, 500);
      },
    );

    test('getBlock with default params', () async {
      final client = buildClient(_blockJson());
      await client.getBlock();

      expect(capturedPath, '/wallet/getblock');
      expect(capturedBody['detail'], false);
      expect(capturedBody.containsKey('id_or_num'), false);
    });
  });
}
