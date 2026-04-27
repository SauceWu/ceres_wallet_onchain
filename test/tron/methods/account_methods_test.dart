import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_exception.dart';
import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/account_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_account_resource.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Known valid Tron base58 address for testing.
const _knownBase58 = 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA';

/// Second valid Tron address (hex format, 41 + 20 zero bytes).
const _knownHex2 = '410000000000000000000000000000000000000000';

/// Test harness that mixes in [TronAccountMethods].
class _TestClient with TronAccountMethods {
  @override
  final RestTransport transport;
  _TestClient(this.transport);
}

/// Creates a [_TestClient] backed by a [MockClient] that routes responses
/// based on the request path.
_TestClient _clientWithPathRouter(Map<String, Object> pathResponses) {
  final mockHttp = MockClient((request) async {
    final path = request.url.path;
    final response = pathResponses[path] ?? <String, dynamic>{};
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = RestTransport(
    config: const RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mockHttp,
  );
  return _TestClient(transport);
}

/// Creates a [_TestClient] that captures requests and returns [response].
({_TestClient client, List<http.Request> captured}) _clientCapturing(
  Object response,
) {
  final captured = <http.Request>[];
  final mockHttp = MockClient((request) async {
    captured.add(request);
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = RestTransport(
    config: const RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mockHttp,
  );
  return (client: _TestClient(transport), captured: captured);
}

void main() {
  final testAddr = TronAddress(_knownBase58);

  group('TronAccountMethods', () {
    group('getAccount', () {
      test('returns TronAccount for existing account', () async {
        final client = _clientWithPathRouter({
          '/wallet/getaccount': {
            'address': _knownBase58,
            'balance': 1000000,
            'create_time': 1600000000000,
          },
        });
        final account = await client.getAccount(testAddr);
        expect(account, isNotNull);
        expect(account!.balance, equals(BigInt.from(1000000)));
        expect(account.address, equals(_knownBase58));
      });

      test('returns null for empty account', () async {
        final client = _clientWithPathRouter({
          '/wallet/getaccount': <String, dynamic>{},
        });
        final account = await client.getAccount(testAddr);
        expect(account, isNull);
      });

      test('sends visible: true in request body', () async {
        final (:client, :captured) = _clientCapturing({
          'address': _knownBase58,
          'balance': 0,
        });
        await client.getAccount(testAddr);
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['visible'], isTrue);
        expect(body['address'], equals(_knownBase58));
      });
    });

    group('getAccountSolidity', () {
      test('uses /walletsolidity/getaccount path', () async {
        final (:client, :captured) = _clientCapturing({
          'address': _knownBase58,
          'balance': 500000,
        });
        final account = await client.getAccountSolidity(testAddr);
        expect(account, isNotNull);
        expect(captured.first.url.path, equals('/walletsolidity/getaccount'));
      });

      test('returns null for empty account', () async {
        final client = _clientWithPathRouter({
          '/walletsolidity/getaccount': <String, dynamic>{},
        });
        final account = await client.getAccountSolidity(testAddr);
        expect(account, isNull);
      });
    });

    group('getAccountBalance', () {
      test('sends correct block info', () async {
        final (:client, :captured) = _clientCapturing({'balance': 100});
        await client.getAccountBalance(
          address: testAddr,
          blockNum: 12345,
          blockHash: '0000000000003039abc',
        );
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['account_identifier']['address'], equals(_knownBase58));
        expect(body['block_identifier']['number'], equals(12345));
        expect(body['block_identifier']['hash'], equals('0000000000003039abc'));
        expect(body['visible'], isTrue);
      });
    });

    group('getAccountNet', () {
      test('returns raw JSON map', () async {
        final client = _clientWithPathRouter({
          '/wallet/getaccountnet': {'freeNetUsed': 100, 'freeNetLimit': 5000},
        });
        final result = await client.getAccountNet(testAddr);
        expect(result['freeNetUsed'], equals(100));
        expect(result['freeNetLimit'], equals(5000));
      });
    });

    group('getAccountResource', () {
      test('returns TronAccountResource', () async {
        final client = _clientWithPathRouter({
          '/wallet/getaccountresource': {
            'freeNetLimit': 5000,
            'TotalEnergyLimit': 90000000000,
          },
        });
        final resource = await client.getAccountResource(testAddr);
        expect(resource, isA<TronAccountResource>());
        expect(resource.freeNetLimit, equals(BigInt.from(5000)));
      });
    });

    group('createAccount', () {
      test('returns TronTransaction on success', () async {
        final ownerAddr = TronAddress(_knownBase58);
        final newAddr = TronAddress(_knownHex2);
        final client = _clientWithPathRouter({
          '/wallet/createaccount': {
            'txID': 'abc123',
            'raw_data': {
              'contract': [
                {'type': 'AccountCreateContract'},
              ],
              'ref_block_bytes': '1234',
              'ref_block_hash': '5678abcd',
              'expiration': 1700000000000,
            },
          },
        });
        final tx = await client.createAccount(
          ownerAddress: ownerAddr,
          accountAddress: newAddr,
        );
        expect(tx.txID, equals('abc123'));
        expect(tx.rawData, isNotNull);
      });

      test('throws on error response', () async {
        final client = _clientWithPathRouter({
          '/wallet/createaccount': {'Error': 'Account already exists'},
        });
        expect(
          () => client.createAccount(
            ownerAddress: testAddr,
            accountAddress: testAddr,
          ),
          throwsA(isA<RpcException>()),
        );
      });
    });

    group('updateAccount', () {
      test('sends account name in body', () async {
        final (:client, :captured) = _clientCapturing({
          'txID': 'update123',
          'raw_data': {
            'contract': [
              {'type': 'AccountUpdateContract'},
            ],
          },
        });
        final tx = await client.updateAccount(
          ownerAddress: testAddr,
          accountName: 'MyAccount',
        );
        expect(tx.txID, equals('update123'));
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['account_name'], equals('MyAccount'));
        expect(body['visible'], isTrue);
      });

      test('calls checkTronError', () async {
        final client = _clientWithPathRouter({
          '/wallet/updateaccount': {
            'result': {
              'result': false,
              'code': 'CONTRACT_VALIDATE_ERROR',
              'message': '636f6e747261637420657272',
            },
          },
        });
        expect(
          () =>
              client.updateAccount(ownerAddress: testAddr, accountName: 'Bad'),
          throwsA(isA<RpcException>()),
        );
      });
    });

    group('validateAddress', () {
      test('returns validation result map', () async {
        final client = _clientWithPathRouter({
          '/wallet/validateaddress': {
            'result': true,
            'message': 'Base58check format',
          },
        });
        final result = await client.validateAddress(_knownBase58);
        expect(result['result'], isTrue);
        expect(result['message'], equals('Base58check format'));
      });

      test('sends address in body', () async {
        final (:client, :captured) = _clientCapturing({
          'result': true,
          'message': 'Hex format',
        });
        await client.validateAddress('41abcdef1234567890');
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['address'], equals('41abcdef1234567890'));
      });
    });
  });
}
