import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/staking_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_transaction.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [TronStakingMethods] for testing.
class _TestClient with TronStakingMethods {
  @override
  final RestTransport transport;
  _TestClient(this.transport);
}

/// Creates a [_TestClient] backed by a [MockClient] that captures the
/// last request and returns [responseBody].
({_TestClient client, List<http.Request> requests}) _setup(
  Map<String, dynamic> responseBody,
) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(responseBody), 200);
  });
  final transport = RestTransport(
    config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mockClient,
  );
  return (client: _TestClient(transport), requests: requests);
}

/// Sample unsigned transaction JSON from Tron API.
final _sampleTxJson = <String, dynamic>{
  'txID': 'abc123',
  'raw_data': {
    'contract': [
      {
        'parameter': {'value': {}},
        'type': 'FreezeBalanceV2Contract',
      },
    ],
    'ref_block_bytes': '1234',
    'ref_block_hash': 'abcdef',
    'expiration': 1700000000000,
    'timestamp': 1699999990000,
  },
  'raw_data_hex': 'deadbeef',
};

void main() {
  group('TronStakingMethods', () {
    // Known valid addresses from tron_address_test.dart
    final ownerAddr = TronAddress('TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA');
    // Second address from hex (different 20-byte payload)
    final receiverAddr = TronAddress(
      '41a0b52f6159fae55e04cbc67e0d3c21a070cab4e1',
    );

    test(
      'freezeBalanceV2 sends correct body and returns TronTransaction',
      () async {
        final (:client, :requests) = _setup(_sampleTxJson);
        final tx = await client.freezeBalanceV2(
          ownerAddress: ownerAddr,
          frozenBalance: BigInt.from(10000000),
          resource: 'BANDWIDTH',
        );

        expect(tx, isA<TronTransaction>());
        expect(tx.txID, equals('abc123'));

        final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
        expect(body['owner_address'], equals(ownerAddr.toBase58()));
        expect(body['frozen_balance'], equals(10000000));
        expect(body['resource'], equals('BANDWIDTH'));
        expect(body['visible'], isTrue);
        expect(requests.last.url.path, equals('/wallet/freezebalancev2'));
      },
    );

    test('unfreezeBalanceV2 sends correct body', () async {
      final (:client, :requests) = _setup(_sampleTxJson);
      final tx = await client.unfreezeBalanceV2(
        ownerAddress: ownerAddr,
        unfreezeBalance: BigInt.from(5000000),
        resource: 'ENERGY',
      );

      expect(tx, isA<TronTransaction>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['unfreeze_balance'], equals(5000000));
      expect(body['resource'], equals('ENERGY'));
      expect(body['visible'], isTrue);
    });

    test('withdrawExpireUnfreeze sends correct body', () async {
      final (:client, :requests) = _setup(_sampleTxJson);
      final tx = await client.withdrawExpireUnfreeze(ownerAddress: ownerAddr);

      expect(tx, isA<TronTransaction>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['owner_address'], equals(ownerAddr.toBase58()));
      expect(body['visible'], isTrue);
    });

    test('delegateResource includes lock and lockPeriod', () async {
      final (:client, :requests) = _setup(_sampleTxJson);
      final tx = await client.delegateResource(
        ownerAddress: ownerAddr,
        receiverAddress: receiverAddr,
        balance: BigInt.from(1000000),
        resource: 'ENERGY',
        lock: true,
        lockPeriod: 86400,
      );

      expect(tx, isA<TronTransaction>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['receiver_address'], equals(receiverAddr.toBase58()));
      expect(body['balance'], equals(1000000));
      expect(body['lock'], isTrue);
      expect(body['lock_period'], equals(86400));
      expect(body['visible'], isTrue);
    });

    test('delegateResource omits lockPeriod when null', () async {
      final (:client, :requests) = _setup(_sampleTxJson);
      await client.delegateResource(
        ownerAddress: ownerAddr,
        receiverAddress: receiverAddr,
        balance: BigInt.from(1000000),
        resource: 'BANDWIDTH',
      );

      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body.containsKey('lock_period'), isFalse);
    });

    test('undelegateResource sends correct body', () async {
      final (:client, :requests) = _setup(_sampleTxJson);
      final tx = await client.undelegateResource(
        ownerAddress: ownerAddr,
        receiverAddress: receiverAddr,
        balance: BigInt.from(1000000),
        resource: 'BANDWIDTH',
      );

      expect(tx, isA<TronTransaction>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['resource'], equals('BANDWIDTH'));
      expect(body['visible'], isTrue);
    });

    test('getAvailableUnfreezeCount returns Map', () async {
      final (:client, :requests) = _setup({'count': 32});
      final result = await client.getAvailableUnfreezeCount(ownerAddr);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['count'], equals(32));
      expect(
        requests.last.url.path,
        equals('/wallet/getavailableunfreezecount'),
      );
    });

    test('getCanWithdrawUnfreezeAmount with timestamp', () async {
      final (:client, :requests) = _setup({'amount': 5000000});
      final result = await client.getCanWithdrawUnfreezeAmount(
        ownerAddress: ownerAddr,
        timestamp: 1700000000000,
      );

      expect(result['amount'], equals(5000000));
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['timestamp'], equals(1700000000000));
    });

    test('getCanDelegatedMaxSize sends type parameter', () async {
      final (:client, :requests) = _setup({'max_size': 100000000});
      final result = await client.getCanDelegatedMaxSize(
        ownerAddress: ownerAddr,
        type: 1,
      );

      expect(result['max_size'], equals(100000000));
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['type'], equals(1));
    });

    test('getDelegatedResourceV2 sends both addresses', () async {
      final (:client, :requests) = _setup({
        'delegatedResource': [
          {'frozen_balance_for_bandwidth': 1000000},
        ],
      });
      final result = await client.getDelegatedResourceV2(
        fromAddress: ownerAddr,
        toAddress: receiverAddr,
      );

      expect(result, isA<Map<String, dynamic>>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['fromAddress'], equals(ownerAddr.toBase58()));
      expect(body['toAddress'], equals(receiverAddr.toBase58()));
    });

    test('getDelegatedResourceAccountIndexV2 sends address value', () async {
      final (:client, :requests) = _setup({
        'account': ownerAddr.toBase58(),
        'toAccounts': [receiverAddr.toBase58()],
      });
      final result = await client.getDelegatedResourceAccountIndexV2(ownerAddr);

      expect(result, isA<Map<String, dynamic>>());
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['value'], equals(ownerAddr.toBase58()));
    });
  });
}
