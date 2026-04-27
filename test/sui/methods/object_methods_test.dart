import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/methods/object_methods.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_object_response.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_options.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Helper that creates a [JsonRpcTransport] backed by a [MockClient].
JsonRpcTransport _createMockTransport(
  dynamic Function(Map<String, dynamic> request) handler,
) {
  final mockClient = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final result = handler(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://fullnode.testnet.sui.io'),
    httpClient: mockClient,
  );
}

/// Test harness that uses [SuiObjectMethods] via a concrete class.
class _TestClient with SuiObjectMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);
}

/// Minimal object data for test responses.
Map<String, dynamic> _minimalObjectData() => {
  'objectId':
      '0x0000000000000000000000000000000000000000000000000000000000000002',
  'version': '1',
  'digest': 'ObjDigest123',
};

void main() {
  const testObjectId =
      '0x0000000000000000000000000000000000000000000000000000000000000002';

  group('SuiObjectMethods', () {
    group('getObject', () {
      test('sends sui_getObject with objectId and options', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return {'data': _minimalObjectData()};
        });
        final client = _TestClient(transport);

        final result = await client.getObject(
          testObjectId,
          options: const SuiObjectDataOptions(
            showContent: true,
            showOwner: true,
          ),
        );

        expect(capturedRequest['method'], 'sui_getObject');
        final params = capturedRequest['params'] as List;
        expect(params[0], testObjectId);
        final opts = params[1] as Map<String, dynamic>;
        expect(opts['showContent'], true);
        expect(opts['showOwner'], true);
        expect(result, isA<SuiObjectResponse>());
        expect(result.data, isNotNull);
        expect(result.data!.objectId, testObjectId);
      });

      test('returns object with error when not found', () async {
        final transport = _createMockTransport((req) {
          return {
            'error': {'code': 'notExists', 'object_id': testObjectId},
          };
        });
        final client = _TestClient(transport);

        final result = await client.getObject(testObjectId);

        expect(result.data, isNull);
        expect(result.error, isNotNull);
        expect(result.error!.code, 'notExists');
      });

      test('sends null options when not provided', () async {
        late List<dynamic> capturedParams;
        final transport = _createMockTransport((req) {
          capturedParams = req['params'] as List;
          return {'data': _minimalObjectData()};
        });
        final client = _TestClient(transport);

        await client.getObject(testObjectId);

        expect(capturedParams[1], isNull);
      });
    });

    group('multiGetObjects', () {
      test('sends sui_multiGetObjects with objectIds and options', () async {
        late Map<String, dynamic> capturedRequest;
        final transport = _createMockTransport((req) {
          capturedRequest = req;
          return [
            {'data': _minimalObjectData()},
            {
              'error': {'code': 'notExists'},
            },
          ];
        });
        final client = _TestClient(transport);

        final result = await client.multiGetObjects([
          testObjectId,
          '0xdead',
        ], options: SuiObjectDataOptions.all);

        expect(capturedRequest['method'], 'sui_multiGetObjects');
        final params = capturedRequest['params'] as List;
        expect(params[0], [testObjectId, '0xdead']);
        expect(result.length, 2);
        expect(result[0].data, isNotNull);
        expect(result[1].error, isNotNull);
      });
    });

    group('tryGetPastObject', () {
      test(
        'sends sui_tryGetPastObject with objectId, version, and options',
        () async {
          late Map<String, dynamic> capturedRequest;
          final transport = _createMockTransport((req) {
            capturedRequest = req;
            return {'status': 'VersionFound', 'details': _minimalObjectData()};
          });
          final client = _TestClient(transport);

          final result = await client.tryGetPastObject(
            testObjectId,
            1,
            options: const SuiObjectDataOptions(showContent: true),
          );

          expect(capturedRequest['method'], 'sui_tryGetPastObject');
          final params = capturedRequest['params'] as List;
          expect(params[0], testObjectId);
          expect(params[1], 1);
          expect((params[2] as Map)['showContent'], true);
          expect(result, isA<SuiPastObjectResponse>());
          expect(result.status, 'VersionFound');
          expect(result.details, isNotNull);
        },
      );

      test('returns ObjectNotExists status', () async {
        final transport = _createMockTransport((req) {
          return {'status': 'ObjectNotExists'};
        });
        final client = _TestClient(transport);

        final result = await client.tryGetPastObject(testObjectId, 99);

        expect(result.status, 'ObjectNotExists');
        expect(result.details, isNull);
      });
    });

    group('tryMultiGetPastObjects', () {
      test(
        'sends sui_tryMultiGetPastObjects with objects list and options',
        () async {
          late Map<String, dynamic> capturedRequest;
          final transport = _createMockTransport((req) {
            capturedRequest = req;
            return [
              {'status': 'VersionFound', 'details': _minimalObjectData()},
              {'status': 'VersionNotFound'},
            ];
          });
          final client = _TestClient(transport);

          final objects = [
            {'objectId': testObjectId, 'version': 1},
            {'objectId': '0xdead', 'version': 5},
          ];

          final result = await client.tryMultiGetPastObjects(
            objects,
            options: const SuiObjectDataOptions(showType: true),
          );

          expect(capturedRequest['method'], 'sui_tryMultiGetPastObjects');
          final params = capturedRequest['params'] as List;
          expect(params[0], objects);
          expect((params[1] as Map)['showType'], true);
          expect(result.length, 2);
          expect(result[0].status, 'VersionFound');
          expect(result[0].details, isNotNull);
          expect(result[1].status, 'VersionNotFound');
          expect(result[1].details, isNull);
        },
      );
    });
  });
}
