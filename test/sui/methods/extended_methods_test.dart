import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/extended_methods.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_object_response.dart';
import 'package:ceres_wallet_onchain/src/sui/sui_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class to test the mixin.
class _TestClient with SuiExtendedMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);

  void close() => transport.close();
}

/// Creates a [_TestClient] backed by a [MockClient] that validates
/// the RPC method and params, returning the given [result].
_TestClient _clientWithMethodValidator({
  required String expectedMethod,
  List<dynamic>? expectedParams,
  required dynamic result,
}) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['method'], equals(expectedMethod));
    if (expectedParams != null) {
      expect(body['params'], equals(expectedParams));
    }
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
  return _TestClient(transport);
}

void main() {
  const parentObjectId =
      '0x0000000000000000000000000000000000000000000000000000000000000002';

  group('SuiExtendedMethods', () {
    group('getDynamicFields', () {
      test('sends suix_getDynamicFields with correct params', () async {
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_getDynamicFields',
          expectedParams: [parentObjectId, null, null],
          result: {
            'data': [
              {
                'name': {'type': 'u64', 'value': '1'},
                'bcsName': 'AQAAAAAAAAA=',
                'type': 'DynamicField',
                'objectType': '0x2::dynamic_field::Field<u64, bool>',
                'objectId':
                    '0xabc0000000000000000000000000000000000000000000000000000000000001',
                'version': 5,
                'digest': 'abc123',
              },
            ],
            'hasNextPage': false,
            'nextCursor': null,
          },
        );

        final result = await client.getDynamicFields(parentObjectId);
        expect(result.data, hasLength(1));
        expect(result.data.first.type, equals('DynamicField'));
        expect(
          result.data.first.objectType,
          equals('0x2::dynamic_field::Field<u64, bool>'),
        );
        expect(result.hasNextPage, isFalse);
        expect(result.nextCursor, isNull);
        client.close();
      });

      test('passes cursor and limit when provided', () async {
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_getDynamicFields',
          expectedParams: [parentObjectId, 'cursor_abc', 10],
          result: {
            'data': <Map<String, dynamic>>[],
            'hasNextPage': false,
            'nextCursor': null,
          },
        );

        final result = await client.getDynamicFields(
          parentObjectId,
          cursor: 'cursor_abc',
          limit: 10,
        );
        expect(result.data, isEmpty);
        client.close();
      });
    });

    group('getDynamicFieldObject', () {
      test('sends suix_getDynamicFieldObject with correct params', () async {
        final nameParam = {'type': 'u64', 'value': '1'};
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_getDynamicFieldObject',
          expectedParams: [parentObjectId, nameParam],
          result: {
            'data': {
              'objectId':
                  '0xabc0000000000000000000000000000000000000000000000000000000000002',
              'version': '10',
              'digest': 'def456',
            },
          },
        );

        final result = await client.getDynamicFieldObject(
          parentObjectId,
          nameParam,
        );
        expect(result, isA<SuiObjectResponse>());
        expect(result.data, isNotNull);
        expect(
          result.data!.objectId,
          equals(
            '0xabc0000000000000000000000000000000000000000000000000000000000002',
          ),
        );
        client.close();
      });
    });

    group('resolveNameServiceAddress', () {
      test('sends suix_resolveNameServiceAddress and returns address', () async {
        const resolvedAddress =
            '0xd8da6bf26964af9d7eed9e03e53415d37aa96045000000000000000000000000';
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_resolveNameServiceAddress',
          expectedParams: ['example.sui'],
          result: resolvedAddress,
        );

        final result = await client.resolveNameServiceAddress('example.sui');
        expect(result, equals(resolvedAddress));
        client.close();
      });

      test('returns null when domain does not exist', () async {
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_resolveNameServiceAddress',
          expectedParams: ['nonexistent.sui'],
          result: null,
        );

        final result = await client.resolveNameServiceAddress(
          'nonexistent.sui',
        );
        expect(result, isNull);
        client.close();
      });
    });

    group('resolveNameServiceNames', () {
      test('sends suix_resolveNameServiceNames with correct params', () async {
        final address = SuiAddress('0x2');
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_resolveNameServiceNames',
          expectedParams: [address.toHex(), null, null],
          result: {
            'data': ['example.sui', 'test.sui'],
            'hasNextPage': true,
            'nextCursor': 'cursor_xyz',
          },
        );

        final result = await client.resolveNameServiceNames(address);
        expect(result.data, equals(['example.sui', 'test.sui']));
        expect(result.hasNextPage, isTrue);
        expect(result.nextCursor, equals('cursor_xyz'));
        client.close();
      });

      test('passes cursor and limit when provided', () async {
        final address = SuiAddress('0x2');
        final client = _clientWithMethodValidator(
          expectedMethod: 'suix_resolveNameServiceNames',
          expectedParams: [address.toHex(), 'cur', 5],
          result: {
            'data': <String>[],
            'hasNextPage': false,
            'nextCursor': null,
          },
        );

        final result = await client.resolveNameServiceNames(
          address,
          cursor: 'cur',
          limit: 5,
        );
        expect(result.data, isEmpty);
        expect(result.hasNextPage, isFalse);
        client.close();
      });
    });
  });
}
