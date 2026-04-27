import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/src/evm/methods/filter_methods.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class _TestFilterClient with EvmFilterMethods {
  @override
  final JsonRpcTransport transport;
  _TestFilterClient(this.transport);
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
  group('EvmFilterMethods', () {
    test('newFilter returns filter ID string', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_newFilter'));
        return http.Response(jsonEncode(_rpcResponse('0x1')), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final filterId = await filterClient.newFilter({
        'fromBlock': '0x0',
        'toBlock': 'latest',
      });
      expect(filterId, equals('0x1'));
      filterClient.transport.close();
    });

    test('newBlockFilter returns filter ID string', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_newBlockFilter'));
        return http.Response(jsonEncode(_rpcResponse('0x2')), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final filterId = await filterClient.newBlockFilter();
      expect(filterId, equals('0x2'));
      filterClient.transport.close();
    });

    test('newPendingTransactionFilter returns filter ID string', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_newPendingTransactionFilter'));
        return http.Response(jsonEncode(_rpcResponse('0x3')), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final filterId = await filterClient.newPendingTransactionFilter();
      expect(filterId, equals('0x3'));
      filterClient.transport.close();
    });

    test('getFilterChanges returns raw List<dynamic>', () async {
      final txHashes = [
        '0xaaa111222333444555666777888999000aaabbbcccdddeeefff000111222333',
        '0xbbb111222333444555666777888999000aaabbbcccdddeeefff000111222333',
      ];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_getFilterChanges'));
        expect(body['params'], equals(['0x1']));
        return http.Response(jsonEncode(_rpcResponse(txHashes)), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final changes = await filterClient.getFilterChanges('0x1');
      expect(changes, isA<List<dynamic>>());
      expect(changes, hasLength(2));
      expect(changes.first, isA<String>());
      filterClient.transport.close();
    });

    test('getFilterChanges returns log objects for log filters', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(_rpcResponse([_sampleLog])), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final changes = await filterClient.getFilterChanges('0x1');
      expect(changes, isA<List<dynamic>>());
      expect(changes.first, isA<Map<String, dynamic>>());
      filterClient.transport.close();
    });

    test('getFilterLogs returns List<EthLog>', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_getFilterLogs'));
        expect(body['params'], equals(['0x1']));
        return http.Response(
          jsonEncode(_rpcResponse([_sampleLog, _sampleLog])),
          200,
        );
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final logs = await filterClient.getFilterLogs('0x1');
      expect(logs, hasLength(2));
      expect(logs.first, isA<EthLog>());
      expect(logs.first.logIndex, equals(BigInt.one));
      filterClient.transport.close();
    });

    test('uninstallFilter returns bool', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], equals('eth_uninstallFilter'));
        expect(body['params'], equals(['0x1']));
        return http.Response(jsonEncode(_rpcResponse(true)), 200);
      });

      final filterClient = _TestFilterClient(
        JsonRpcTransport(config: _config, httpClient: client),
      );

      final result = await filterClient.uninstallFilter('0x1');
      expect(result, isTrue);
      filterClient.transport.close();
    });
  });
}
