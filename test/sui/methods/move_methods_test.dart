import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/move_methods.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [SuiMoveMethods] for testing.
class _TestClient with SuiMoveMethods {
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
  group('SuiMoveMethods', () {
    group('getNormalizedMoveModulesByPackage', () {
      test('returns Map<String, MoveNormalizedModule>', () async {
        final client = _clientWithResult({
          'coin': {
            'fileFormatVersion': 6,
            'address': '0x2',
            'name': 'coin',
            'friends': [],
            'structs': {},
            'exposedFunctions': {},
          },
          'transfer': {
            'fileFormatVersion': 6,
            'address': '0x2',
            'name': 'transfer',
            'friends': [],
            'structs': {},
            'exposedFunctions': {},
          },
        });

        final modules = await client.getNormalizedMoveModulesByPackage('0x2');

        expect(modules, hasLength(2));
        expect(modules['coin']!.name, 'coin');
        expect(modules['transfer']!.address, '0x2');

        client.close();
      });

      test('sends correct RPC method and params', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({}, (body) => captured = body);

        await client.getNormalizedMoveModulesByPackage('0xabc');

        expect(captured!['method'], 'sui_getNormalizedMoveModulesByPackage');
        expect(captured!['params'], ['0xabc']);

        client.close();
      });
    });

    group('getNormalizedMoveModule', () {
      test('returns MoveNormalizedModule', () async {
        final client = _clientWithResult({
          'fileFormatVersion': 6,
          'address': '0x2',
          'name': 'coin',
          'friends': [],
          'structs': {
            'Coin': {
              'abilities': {
                'abilities': ['Store', 'Key'],
              },
              'typeParameters': [],
              'fields': [
                {'name': 'id', 'type': 'UID'},
                {'name': 'balance', 'type': 'U64'},
              ],
            },
          },
          'exposedFunctions': {},
        });

        final module = await client.getNormalizedMoveModule('0x2', 'coin');

        expect(module.name, 'coin');
        expect(module.fileFormatVersion, 6);
        expect(module.structs.containsKey('Coin'), isTrue);

        client.close();
      });

      test('sends packageId and moduleName', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'fileFormatVersion': 6,
          'address': '0x2',
          'name': 'coin',
          'friends': [],
          'structs': {},
          'exposedFunctions': {},
        }, (body) => captured = body);

        await client.getNormalizedMoveModule('0x2', 'coin');

        expect(captured!['method'], 'sui_getNormalizedMoveModule');
        expect(captured!['params'], ['0x2', 'coin']);

        client.close();
      });
    });

    group('getNormalizedMoveFunction', () {
      test('returns MoveNormalizedFunction', () async {
        final client = _clientWithResult({
          'visibility': 'Public',
          'isEntry': true,
          'typeParameters': [],
          'parameters': ['U64', 'Address'],
          'return': ['Bool'],
        });

        final fn = await client.getNormalizedMoveFunction(
          '0x2',
          'coin',
          'transfer',
        );

        expect(fn.visibility, 'Public');
        expect(fn.isEntry, isTrue);
        expect(fn.parameters, hasLength(2));
        expect(fn.returnTypes, hasLength(1));

        client.close();
      });

      test('sends packageId, moduleName, functionName', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'visibility': 'Public',
          'isEntry': false,
          'typeParameters': [],
          'parameters': [],
          'return': [],
        }, (body) => captured = body);

        await client.getNormalizedMoveFunction('0x2', 'coin', 'balance');

        expect(captured!['method'], 'sui_getNormalizedMoveFunction');
        expect(captured!['params'], ['0x2', 'coin', 'balance']);

        client.close();
      });
    });

    group('getNormalizedMoveStruct', () {
      test('returns MoveNormalizedStruct', () async {
        final client = _clientWithResult({
          'abilities': {
            'abilities': ['Store', 'Key'],
          },
          'typeParameters': [],
          'fields': [
            {'name': 'id', 'type': 'UID'},
            {'name': 'balance', 'type': 'U64'},
          ],
        });

        final struct = await client.getNormalizedMoveStruct(
          '0x2',
          'coin',
          'Coin',
        );

        expect(struct.fields, hasLength(2));
        expect(struct.fields[0].name, 'id');
        expect(struct.fields[1].name, 'balance');

        client.close();
      });

      test('sends packageId, moduleName, structName', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'abilities': {'abilities': []},
          'typeParameters': [],
          'fields': [],
        }, (body) => captured = body);

        await client.getNormalizedMoveStruct('0x2', 'coin', 'Coin');

        expect(captured!['method'], 'sui_getNormalizedMoveStruct');
        expect(captured!['params'], ['0x2', 'coin', 'Coin']);

        client.close();
      });
    });

    group('getCommitteeInfo', () {
      test('returns CommitteeInfo', () async {
        final client = _clientWithResult({
          'epoch': '100',
          'validators': [
            ['pubkey1abc', '1000000'],
            ['pubkey2def', '2000000'],
          ],
        });

        final info = await client.getCommitteeInfo();

        expect(info.epoch, '100');
        expect(info.validators, hasLength(2));
        expect(info.validators[0].authorityName, 'pubkey1abc');
        expect(info.validators[0].stakeUnit, equals(BigInt.from(1000000)));
        expect(info.validators[1].stakeUnit, equals(BigInt.from(2000000)));

        client.close();
      });

      test('sends epoch param when provided', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'epoch': '50',
          'validators': [],
        }, (body) => captured = body);

        await client.getCommitteeInfo(epoch: '50');

        expect(captured!['method'], 'suix_getCommitteeInfo');
        expect(captured!['params'], ['50']);

        client.close();
      });

      test('sends empty params when epoch is null', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'epoch': '100',
          'validators': [],
        }, (body) => captured = body);

        await client.getCommitteeInfo();

        expect(captured!['params'], isEmpty);

        client.close();
      });
    });
  });
}
