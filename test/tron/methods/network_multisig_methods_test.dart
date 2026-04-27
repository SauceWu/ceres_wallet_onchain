import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/network_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/multisig_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_chain_parameters.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_node_info.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_transaction.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Test harness that mixes in both network and multisig methods.
class _TestClient with TronNetworkMethods, TronMultisigMethods {
  @override
  final RestTransport transport;

  _TestClient(this.transport);
}

/// Creates a [_TestClient] backed by a [MockClient] that returns [responseBody]
/// for all requests. Captures the last request for assertion.
({_TestClient client, List<http.Request> requests}) _createMockClient(
  Object responseBody, {
  int statusCode = 200,
}) {
  final requests = <http.Request>[];
  final mockHttp = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode(responseBody),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = RestTransport(
    config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mockHttp,
  );
  return (client: _TestClient(transport), requests: requests);
}

void main() {
  group('TronNetworkMethods', () {
    test('getChainParameters returns TronChainParameters', () async {
      final (:client, :requests) = _createMockClient({
        'chainParameter': [
          {'key': 'getMaintenanceTimeInterval', 'value': 21600000},
          {'key': 'getEnergyFee', 'value': 420},
        ],
      });

      final result = await client.getChainParameters();

      expect(result, isA<TronChainParameters>());
      expect(result.parameters, hasLength(2));
      expect(result.parameters[0].key, 'getMaintenanceTimeInterval');
      expect(result.parameters[0].value, 21600000);
      expect(result.parameters[1].key, 'getEnergyFee');
      expect(result.parameters[1].value, 420);

      // Verify it used GET
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/getchainparameters');
    });

    test('getNodeInfo returns TronNodeInfo', () async {
      final (:client, :requests) = _createMockClient({
        'beginSyncNum': 1000,
        'block': 'Num:50000000,ID:abc123',
        'solidityBlock': 49999990,
        'currentConnectCount': 30,
        'activeConnectCount': 15,
        'passiveConnectCount': 15,
        'totalFlow': 123456,
      });

      final result = await client.getNodeInfo();

      expect(result, isA<TronNodeInfo>());
      expect(result.beginSyncNum, 1000);
      expect(result.currentConnectCount, 30);
      expect(result.block, 'Num:50000000,ID:abc123');

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/getnodeinfo');
    });

    test('listNodes returns list and uses GET', () async {
      final (:client, :requests) = _createMockClient({
        'nodes': [
          {
            'address': {'host': '3132372e302e302e31', 'port': 18888},
          },
        ],
      });

      final result = await client.listNodes();

      expect(result, hasLength(1));
      expect(result[0]['address'], isA<Map>());

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/listnodes');
    });

    test('listNodes returns empty list when no nodes', () async {
      final (:client, requests: _) = _createMockClient(<String, dynamic>{});

      final result = await client.listNodes();
      expect(result, isEmpty);
    });

    test('getEnergyPrices returns price string', () async {
      final (:client, :requests) = _createMockClient({
        'prices': '0:100,13000000:280,30000000:420',
      });

      final result = await client.getEnergyPrices();

      expect(result, '0:100,13000000:280,30000000:420');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/getenergyprices');
    });

    test('getEnergyPrices returns empty string when no prices', () async {
      final (:client, requests: _) = _createMockClient(<String, dynamic>{});

      final result = await client.getEnergyPrices();
      expect(result, '');
    });

    test('getBandwidthPrices returns price string', () async {
      final (:client, :requests) = _createMockClient({
        'prices': '0:10,5000000:40',
      });

      final result = await client.getBandwidthPrices();

      expect(result, '0:10,5000000:40');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/getbandwidthprices');
    });

    test('getBurnTrx returns BigInt value', () async {
      final (:client, :requests) = _createMockClient({
        'burnTrxAmount': 12345678000000,
      });

      final result = await client.getBurnTrx();

      expect(result, BigInt.from(12345678000000));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/wallet/getburntrx');
    });

    test('getBurnTrx returns zero when field missing', () async {
      final (:client, requests: _) = _createMockClient(<String, dynamic>{});

      final result = await client.getBurnTrx();
      expect(result, BigInt.zero);
    });
  });

  group('TronMultisigMethods', () {
    test('accountPermissionUpdate sends correct request body', () async {
      final (:client, :requests) = _createMockClient({
        'txID': 'abc123',
        'raw_data': {
          'contract': [
            {
              'parameter': {
                'value': {},
                'type_url': 'type.AccountPermissionUpdateContract',
              },
              'type': 'AccountPermissionUpdateContract',
            },
          ],
          'timestamp': 1700000000000,
          'expiration': 1700000060000,
        },
        'raw_data_hex': 'deadbeef',
      });

      final ownerAddr = TronAddress('TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA');
      final ownerPerm = {
        'type': 0,
        'permission_name': 'owner',
        'threshold': 2,
        'keys': [
          {'address': 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA', 'weight': 1},
        ],
      };
      final activePerm = [
        {
          'type': 2,
          'permission_name': 'active0',
          'threshold': 1,
          'keys': [
            {'address': 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA', 'weight': 1},
          ],
        },
      ];

      final result = await client.accountPermissionUpdate(
        ownerAddress: ownerAddr,
        owner: ownerPerm,
        actives: activePerm,
      );

      expect(result, isA<TronTransaction>());
      expect(result.txID, 'abc123');

      // Verify POST body
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['owner_address'], ownerAddr.toBase58());
      expect(body['owner'], ownerPerm);
      expect(body['actives'], activePerm);
      expect(body['visible'], true);
      expect(body.containsKey('witness'), false);

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/wallet/accountpermissionupdate');
    });

    test('accountPermissionUpdate includes witness when provided', () async {
      final (:client, :requests) = _createMockClient({
        'txID': 'abc123',
        'raw_data': {
          'contract': [],
          'timestamp': 1700000000000,
          'expiration': 1700000060000,
        },
        'raw_data_hex': 'deadbeef',
      });

      final witnessPerm = {
        'type': 1,
        'permission_name': 'witness',
        'threshold': 1,
        'keys': [
          {'address': 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA', 'weight': 1},
        ],
      };

      await client.accountPermissionUpdate(
        ownerAddress: TronAddress('TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA'),
        owner: {
          'type': 0,
          'permission_name': 'owner',
          'threshold': 1,
          'keys': [],
        },
        witness: witnessPerm,
        actives: [],
      );

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['witness'], witnessPerm);
    });

    test(
      'getApprovedList accepts transaction JSON and returns result',
      () async {
        final (:client, :requests) = _createMockClient({
          'approved_list': ['TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA'],
          'transaction': {'txID': 'abc123'},
        });

        final txJson = {
          'txID': 'abc123',
          'raw_data': {'contract': []},
          'signature': ['sig1'],
        };

        final result = await client.getApprovedList(txJson);

        expect(result['approved_list'], hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/wallet/getapprovedlist');

        // Verify the full transaction was sent as body
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['txID'], 'abc123');
        expect(body['signature'], ['sig1']);
      },
    );

    test('getSignWeight accepts transaction JSON and returns result', () async {
      final (:client, :requests) = _createMockClient({
        'current_weight': 1,
        'result': {'code': 'ENOUGH_PERMISSION'},
        'transaction': {'txID': 'abc123'},
      });

      final txJson = {
        'txID': 'abc123',
        'raw_data': {'contract': []},
        'signature': ['sig1', 'sig2'],
      };

      final result = await client.getSignWeight(txJson);

      expect(result['current_weight'], 1);
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/wallet/getsignweight');

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['signature'], hasLength(2));
    });
  });
}
