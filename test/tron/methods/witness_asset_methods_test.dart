import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/asset_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/witness_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_asset_issue.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_transaction.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_witness.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in both [TronWitnessMethods] and
/// [TronAssetMethods] for testing.
class _TestClient with TronWitnessMethods, TronAssetMethods {
  @override
  final RestTransport transport;
  _TestClient(this.transport);
}

/// Creates a [_TestClient] backed by a [MockClient].
///
/// For POST requests, returns [postResponse].
/// For GET requests, returns [getResponse].
({_TestClient client, List<http.BaseRequest> requests}) _setup({
  Map<String, dynamic>? postResponse,
  Map<String, dynamic>? getResponse,
}) {
  final requests = <http.BaseRequest>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    final body = request.method == 'GET'
        ? (getResponse ?? <String, dynamic>{})
        : (postResponse ?? <String, dynamic>{});
    return http.Response(jsonEncode(body), 200);
  });
  final transport = RestTransport(
    config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mockClient,
  );
  return (client: _TestClient(transport), requests: requests);
}

/// Sample unsigned transaction JSON.
final _sampleTxJson = <String, dynamic>{
  'txID': 'vote123',
  'raw_data': {
    'contract': [
      {
        'parameter': {'value': {}},
        'type': 'VoteWitnessContract',
      },
    ],
    'ref_block_bytes': '1234',
    'ref_block_hash': 'abcdef',
    'expiration': 1700000000000,
    'timestamp': 1699999990000,
  },
  'raw_data_hex': 'deadbeef',
};

/// Known valid test address.
const _knownBase58 = 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA';

void main() {
  group('TronWitnessMethods', () {
    final ownerAddr = TronAddress(_knownBase58);
    final witnessAddr = _knownBase58;

    test('voteWitnessAccount sends correct votes format', () async {
      final (:client, :requests) = _setup(postResponse: _sampleTxJson);
      final tx = await client.voteWitnessAccount(
        ownerAddress: ownerAddr,
        votes: {witnessAddr: 100},
      );

      expect(tx, isA<TronTransaction>());
      expect(tx.txID, equals('vote123'));

      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['owner_address'], equals(_knownBase58));
      expect(body['votes'], isList);
      final voteList = body['votes'] as List;
      expect(voteList.length, equals(1));
      expect(voteList[0]['vote_address'], equals(witnessAddr));
      expect(voteList[0]['vote_count'], equals(100));
      expect(body['visible'], isTrue);
    });

    test('listWitnesses uses GET and returns List<TronWitness>', () async {
      final (:client, :requests) = _setup(
        getResponse: {
          'witnesses': [
            {
              'address': _knownBase58,
              'voteCount': 5000000,
              'url': 'https://example.com',
              'totalProduced': 1000,
              'totalMissed': 5,
              'isJobs': true,
            },
            {'address': _knownBase58, 'voteCount': 3000000},
          ],
        },
      );
      final witnesses = await client.listWitnesses();

      expect(witnesses, hasLength(2));
      expect(witnesses[0], isA<TronWitness>());
      expect(witnesses[0].address, equals(_knownBase58));
      expect(witnesses[0].voteCount, equals(BigInt.from(5000000)));
      expect(witnesses[0].isJobs, isTrue);
      expect(witnesses[1].voteCount, equals(BigInt.from(3000000)));

      // Verify GET request
      expect(requests.last.method, equals('GET'));
      expect(requests.last.url.path, equals('/wallet/listwitnesses'));
    });

    test('listWitnesses returns empty list when no witnesses', () async {
      final (:client, requests: _) = _setup(getResponse: {});
      final witnesses = await client.listWitnesses();
      expect(witnesses, isEmpty);
    });

    test('getBrokerage sends address', () async {
      final (:client, :requests) = _setup(postResponse: {'brokerage': 20});
      final result = await client.getBrokerage(ownerAddr);

      expect(result['brokerage'], equals(20));
      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['address'], equals(_knownBase58));
      expect(body['visible'], isTrue);
    });

    test('getReward sends address', () async {
      final (:client, :requests) = _setup(postResponse: {'reward': 1000000});
      final result = await client.getReward(ownerAddr);

      expect(result['reward'], equals(1000000));
      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['address'], equals(_knownBase58));
    });

    test('withdrawBalance returns TronTransaction', () async {
      final (:client, :requests) = _setup(postResponse: _sampleTxJson);
      final tx = await client.withdrawBalance(ownerAddr);

      expect(tx, isA<TronTransaction>());
      expect(requests.last.url.path, equals('/wallet/withdrawbalance'));
    });

    test('getNextMaintenanceTime uses GET', () async {
      final (:client, :requests) = _setup(getResponse: {'num': 1700000000000});
      final result = await client.getNextMaintenanceTime();

      expect(result['num'], equals(1700000000000));
      expect(requests.last.method, equals('GET'));
      expect(requests.last.url.path, equals('/wallet/getnextmaintenancetime'));
    });
  });

  group('TronAssetMethods', () {
    final ownerAddr = TronAddress(_knownBase58);
    final toAddr = TronAddress('41a0b52f6159fae55e04cbc67e0d3c21a070cab4e1');

    final sampleAssetJson = <String, dynamic>{
      'owner_address': _knownBase58,
      'name': 'TestToken',
      'abbr': 'TT',
      'total_supply': 1000000000,
      'precision': 6,
      'id': '1000001',
    };

    test(
      'transferAsset sends correct body and returns TronTransaction',
      () async {
        final (:client, :requests) = _setup(postResponse: _sampleTxJson);
        final tx = await client.transferAsset(
          ownerAddress: ownerAddr,
          toAddress: toAddr,
          assetName: '1000001',
          amount: BigInt.from(100000),
        );

        expect(tx, isA<TronTransaction>());
        final body =
            jsonDecode((requests.last as http.Request).body)
                as Map<String, dynamic>;
        expect(body['owner_address'], equals(_knownBase58));
        expect(body['to_address'], equals(toAddr.toBase58()));
        expect(body['asset_name'], equals('1000001'));
        expect(body['amount'], equals(100000));
        expect(body['visible'], isTrue);
        expect(requests.last.url.path, equals('/wallet/transferasset'));
      },
    );

    test('getAssetIssueById returns TronAssetIssue', () async {
      final (:client, :requests) = _setup(postResponse: sampleAssetJson);
      final asset = await client.getAssetIssueById('1000001');

      expect(asset, isA<TronAssetIssue>());
      expect(asset.name, equals('TestToken'));
      expect(asset.id, equals('1000001'));
      expect(asset.precision, equals(6));

      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['value'], equals('1000001'));
    });

    test('getAssetIssueByIdSolidity uses solidity path', () async {
      final (:client, :requests) = _setup(postResponse: sampleAssetJson);
      final asset = await client.getAssetIssueByIdSolidity('1000001');

      expect(asset, isA<TronAssetIssue>());
      expect(
        requests.last.url.path,
        equals('/walletsolidity/getassetissuebyid'),
      );
    });

    test('getAssetIssueList uses GET and returns list', () async {
      final (:client, :requests) = _setup(
        getResponse: {
          'assetIssue': [sampleAssetJson, sampleAssetJson],
        },
      );
      final assets = await client.getAssetIssueList();

      expect(assets, hasLength(2));
      expect(assets[0], isA<TronAssetIssue>());
      expect(assets[0].name, equals('TestToken'));
      expect(requests.last.method, equals('GET'));
      expect(requests.last.url.path, equals('/wallet/getassetissuelist'));
    });

    test('getAssetIssueList returns empty list when no assets', () async {
      final (:client, requests: _) = _setup(getResponse: {});
      final assets = await client.getAssetIssueList();
      expect(assets, isEmpty);
    });

    test('getPaginatedAssetIssueList sends offset and limit', () async {
      final (:client, :requests) = _setup(
        postResponse: {
          'assetIssue': [sampleAssetJson],
        },
      );
      final assets = await client.getPaginatedAssetIssueList(
        offset: 10,
        limit: 5,
      );

      expect(assets, hasLength(1));
      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['offset'], equals(10));
      expect(body['limit'], equals(5));
    });

    test('getAssetIssueByAccount sends address', () async {
      final (:client, :requests) = _setup(
        postResponse: {
          'assetIssue': [sampleAssetJson],
        },
      );
      final assets = await client.getAssetIssueByAccount(ownerAddr);

      expect(assets, hasLength(1));
      final body =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(body['address'], equals(_knownBase58));
      expect(body['visible'], isTrue);
    });
  });
}
