import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/src/evm/methods/log_methods.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class _TestLogClient with EvmLogMethods {
  @override
  final JsonRpcTransport transport;
  _TestLogClient(this.transport);
}

const _config = RpcClientConfig(
  baseUrl: 'https://rpc.example.com',
  timeout: Duration(seconds: 5),
);

Map<String, dynamic> _rpcResponse(dynamic result) => {
  'jsonrpc': '2.0',
  'id': 1,
  'result': result,
};

final _sampleLog = {
  'logIndex': '0x1',
  'transactionIndex': '0x0',
  'transactionHash':
      '0xabc123def456789012345678901234567890123456789012345678901234abcd',
  'blockHash':
      '0xdef456789012345678901234567890123456789012345678901234567890abcd',
  'blockNumber': '0x10',
  'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
  'data': '0x000000000000000000000000000000000000000000000000000000003b9aca00',
  'topics': [
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
  ],
  'removed': false,
};

void main() {
  group('EvmLogMethods', () {
    test('getLogs with empty result returns empty list', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_getLogs'));
        return http.Response(jsonEncode(_rpcResponse([])), 200);
      });

      final logClient = _TestLogClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final logs = await logClient.getLogs({
        'fromBlock': '0x0',
        'toBlock': 'latest',
      });
      expect(logs, isEmpty);
      logClient.transport.close();
    });

    test('getLogs with multiple logs returns List<EthLog>', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_getLogs'));
        expect(body['params'], isList);
        return http.Response(
          jsonEncode(_rpcResponse([_sampleLog, _sampleLog])),
          200,
        );
      });

      final logClient = _TestLogClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final logs = await logClient.getLogs({
        'fromBlock': '0x0',
        'toBlock': 'latest',
        'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      });
      expect(logs, hasLength(2));
      expect(logs.first, isA<EthLog>());
      expect(
        logs.first.address.toHex(),
        equals('dac17f958d2ee523a2206206994597c13d831ec7'),
      );
      expect(logs.first.removed, isFalse);
      expect(logs.first.topics, hasLength(1));
      logClient.transport.close();
    });

    test('getLogs passes filterParams correctly', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final params = body['params'] as List;
        final filter = params[0] as Map<String, dynamic>;
        expect(filter['fromBlock'], equals('0x100'));
        expect(filter['topics'], contains(null));
        return http.Response(jsonEncode(_rpcResponse([])), 200);
      });

      final logClient = _TestLogClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      await logClient.getLogs({
        'fromBlock': '0x100',
        'toBlock': 'latest',
        'topics': [
          '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
          null,
        ],
      });
      logClient.transport.close();
    });
  });
}
