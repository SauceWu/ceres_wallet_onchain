import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/event_methods.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [SuiEventMethods] for testing.
class _TestClient with SuiEventMethods {
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
  group('SuiEventMethods', () {
    group('getEvents', () {
      test('returns List<SuiEvent>', () async {
        final client = _clientWithResult([
          {
            'id': {'txDigest': 'tx1', 'eventSeq': '0'},
            'packageId': '0x2',
            'transactionModule': 'coin',
            'sender': '0xabc',
            'type': '0x2::coin::CoinEvent',
            'parsedJson': {'amount': '100'},
            'bcs': 'AQID',
            'timestampMs': '1700000000000',
          },
          {
            'id': {'txDigest': 'tx1', 'eventSeq': '1'},
            'packageId': '0x3',
            'transactionModule': 'transfer',
            'sender': '0xdef',
            'type': '0x3::transfer::TransferEvent',
          },
        ]);

        final events = await client.getEvents('tx1');

        expect(events, hasLength(2));
        expect(events[0].packageId, '0x2');
        expect(events[0].type, '0x2::coin::CoinEvent');
        expect(events[0].parsedJson, isNotNull);
        expect(events[1].bcs, isNull);

        client.close();
      });

      test('sends correct RPC method and params', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing([], (body) => captured = body);

        await client.getEvents('myDigest123');

        expect(captured!['method'], 'sui_getEvents');
        expect(captured!['params'], ['myDigest123']);

        client.close();
      });
    });

    group('queryEvents', () {
      test('returns paginated events', () async {
        final client = _clientWithResult({
          'data': [
            {
              'id': {'txDigest': 'tx1', 'eventSeq': '0'},
              'packageId': '0x2',
              'transactionModule': 'coin',
              'sender': '0xabc',
              'type': '0x2::coin::CoinEvent',
            },
          ],
          'hasNextPage': false,
          'nextCursor': null,
        });

        final page = await client.queryEvents(filter: {'Package': '0x2'});

        expect(page.data, hasLength(1));
        expect(page.data[0].packageId, '0x2');
        expect(page.hasNextPage, isFalse);

        client.close();
      });

      test('sends filter, cursor, limit, descendingOrder', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'data': [],
          'hasNextPage': false,
          'nextCursor': null,
        }, (body) => captured = body);

        await client.queryEvents(
          filter: {'Sender': '0xabc'},
          cursor: {'txDigest': 'tx1', 'eventSeq': '0'},
          limit: 5,
          descendingOrder: true,
        );

        expect(captured!['method'], 'suix_queryEvents');
        final params = captured!['params'] as List;
        expect(params[0], {'Sender': '0xabc'});
        expect(params[1], {'txDigest': 'tx1', 'eventSeq': '0'});
        expect(params[2], 5);
        expect(params[3], true);

        client.close();
      });
    });
  });
}
