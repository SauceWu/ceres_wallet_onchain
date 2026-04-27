import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_exception.dart';
import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/transaction_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_broadcast_result.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Known valid Tron base58 addresses for testing.
const _ownerBase58 = 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA';
const _toHex = '410000000000000000000000000000000000000000';

/// Test harness that mixes in [TronTransactionMethods].
class _TestClient with TronTransactionMethods {
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

/// Sample raw_data for a TRX transfer transaction.
Map<String, dynamic> _sampleRawData() => {
  'contract': [
    {
      'parameter': {
        'value': {
          'amount': 1000000,
          'owner_address': _ownerBase58,
          'to_address': _toHex,
        },
        'type_url': 'type.googleapis.com/protocol.TransferContract',
      },
      'type': 'TransferContract',
    },
  ],
  'ref_block_bytes': 'abcd',
  'ref_block_hash': '12345678deadbeef',
  'expiration': 1700000000000,
  'timestamp': 1699999990000,
};

void main() {
  final ownerAddr = TronAddress(_ownerBase58);
  final toAddr = TronAddress(_toHex);

  group('TronTransactionMethods', () {
    group('createTransaction', () {
      test('returns unsigned TronTransaction', () async {
        final client = _clientWithPathRouter({
          '/wallet/createtransaction': {
            'txID': 'tx_create_001',
            'raw_data': _sampleRawData(),
            'raw_data_hex': 'deadbeef',
          },
        });
        final tx = await client.createTransaction(
          ownerAddress: ownerAddr,
          toAddress: toAddr,
          amount: BigInt.from(1000000),
        );
        expect(tx.txID, equals('tx_create_001'));
        expect(tx.rawData, isNotNull);
        expect(tx.rawData!.contract, isNotEmpty);
        expect(tx.signature, isEmpty);
      });

      test('sends visible:true and correct body', () async {
        final (:client, :captured) = _clientCapturing({
          'txID': 'tx_001',
          'raw_data': _sampleRawData(),
        });
        await client.createTransaction(
          ownerAddress: ownerAddr,
          toAddress: toAddr,
          amount: BigInt.from(5000000),
        );
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['owner_address'], equals(_ownerBase58));
        expect(body['amount'], equals(5000000));
        expect(body['visible'], isTrue);
      });

      test('throws on error response', () async {
        final client = _clientWithPathRouter({
          '/wallet/createtransaction': {'Error': 'owner_address is not exists'},
        });
        expect(
          () => client.createTransaction(
            ownerAddress: ownerAddr,
            toAddress: toAddr,
            amount: BigInt.from(1000000),
          ),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws on result.result false', () async {
        final client = _clientWithPathRouter({
          '/wallet/createtransaction': {
            'result': {
              'result': false,
              'code': 'CONTRACT_VALIDATE_ERROR',
              'message': '62616c616e6365206973206e6f742073756666696369656e74',
            },
          },
        });
        expect(
          () => client.createTransaction(
            ownerAddress: ownerAddr,
            toAddress: toAddr,
            amount: BigInt.from(999999999999),
          ),
          throwsA(isA<RpcException>()),
        );
      });
    });

    group('broadcastTransaction', () {
      test('returns TronBroadcastResult on success', () async {
        final client = _clientWithPathRouter({
          '/wallet/broadcasttransaction': {
            'result': true,
            'txid': 'broadcast_tx_001',
          },
        });
        final result = await client.broadcastTransaction({
          'txID': 'broadcast_tx_001',
          'raw_data': _sampleRawData(),
          'signature': ['aabbccdd'],
        });
        expect(result, isA<TronBroadcastResult>());
        expect(result.result, isTrue);
        expect(result.txid, equals('broadcast_tx_001'));
      });

      test('returns failure result', () async {
        final client = _clientWithPathRouter({
          '/wallet/broadcasttransaction': {
            'result': false,
            'code': 'SIGERROR',
            'message': '7369676e6174757265206572726f72',
          },
        });
        final result = await client.broadcastTransaction({
          'txID': 'bad_tx',
          'raw_data': _sampleRawData(),
          'signature': ['invalid_sig'],
        });
        expect(result.result, isFalse);
        expect(result.code, equals('SIGERROR'));
      });

      test('sends signed transaction directly', () async {
        final signedTx = {
          'txID': 'tx_signed',
          'raw_data': _sampleRawData(),
          'signature': ['aabb'],
        };
        final (:client, :captured) = _clientCapturing({
          'result': true,
          'txid': 'tx_signed',
        });
        await client.broadcastTransaction(signedTx);
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['txID'], equals('tx_signed'));
        expect(body['signature'], equals(['aabb']));
      });
    });

    group('broadcastHex', () {
      test('sends hex string in body', () async {
        final (:client, :captured) = _clientCapturing({
          'result': true,
          'txid': 'hex_tx_001',
        });
        await client.broadcastHex('0a1b2c3d4e5f');
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['transaction'], equals('0a1b2c3d4e5f'));
      });

      test('returns TronBroadcastResult', () async {
        final client = _clientWithPathRouter({
          '/wallet/broadcasthex': {'result': true, 'txid': 'hex_tx_002'},
        });
        final result = await client.broadcastHex('deadbeef');
        expect(result.result, isTrue);
        expect(result.txid, equals('hex_tx_002'));
      });
    });

    group('getTransactionById', () {
      test('returns TronTransaction for existing tx', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactionbyid': {
            'txID': 'found_tx_001',
            'raw_data': _sampleRawData(),
            'signature': ['aabb'],
          },
        });
        final tx = await client.getTransactionById('found_tx_001');
        expect(tx, isNotNull);
        expect(tx!.txID, equals('found_tx_001'));
        expect(tx.signature, equals(['aabb']));
      });

      test('returns null for non-existent tx', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactionbyid': <String, dynamic>{},
        });
        final tx = await client.getTransactionById('not_found');
        expect(tx, isNull);
      });

      test('sends txId as value field', () async {
        final (:client, :captured) = _clientCapturing({
          'txID': 'test_tx',
          'raw_data': _sampleRawData(),
        });
        await client.getTransactionById('my_tx_id');
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['value'], equals('my_tx_id'));
      });
    });

    group('getTransactionByIdSolidity', () {
      test('uses /walletsolidity path', () async {
        final (:client, :captured) = _clientCapturing({
          'txID': 'sol_tx_001',
          'raw_data': _sampleRawData(),
        });
        final tx = await client.getTransactionByIdSolidity('sol_tx_001');
        expect(tx, isNotNull);
        expect(captured.first.url.path, '/walletsolidity/gettransactionbyid');
      });

      test('returns null for non-existent tx', () async {
        final client = _clientWithPathRouter({
          '/walletsolidity/gettransactionbyid': <String, dynamic>{},
        });
        final tx = await client.getTransactionByIdSolidity('not_found');
        expect(tx, isNull);
      });
    });

    group('getTransactionInfoById', () {
      test('returns TronTransactionInfo', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactioninfobyid': {
            'id': 'info_tx_001',
            'fee': 100000,
            'blockNumber': 12345,
            'receipt': {'energy_usage_total': 50000, 'result': 'SUCCESS'},
          },
        });
        final info = await client.getTransactionInfoById('info_tx_001');
        expect(info, isNotNull);
        expect(info!.id, equals('info_tx_001'));
        expect(info.fee, equals(BigInt.from(100000)));
        expect(info.receipt, isNotNull);
        expect(info.receipt!.result, equals('SUCCESS'));
      });

      test('returns null for non-existent tx', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactioninfobyid': <String, dynamic>{},
        });
        final info = await client.getTransactionInfoById('not_found');
        expect(info, isNull);
      });
    });

    group('getTransactionInfoByIdSolidity', () {
      test('uses /walletsolidity path', () async {
        final (:client, :captured) = _clientCapturing({
          'id': 'sol_info_001',
          'fee': 50000,
          'blockNumber': 99999,
        });
        final info = await client.getTransactionInfoByIdSolidity(
          'sol_info_001',
        );
        expect(info, isNotNull);
        expect(
          captured.first.url.path,
          '/walletsolidity/gettransactioninfobyid',
        );
      });

      test('returns null for non-existent tx', () async {
        final client = _clientWithPathRouter({
          '/walletsolidity/gettransactioninfobyid': <String, dynamic>{},
        });
        final info = await client.getTransactionInfoByIdSolidity('not_found');
        expect(info, isNull);
      });
    });

    group('getTransactionInfoByBlockNum', () {
      test('returns list of TronTransactionInfo', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactioninfobyblocknum': {
            'transactionInfo': [
              {'id': 'block_tx_001', 'fee': 100000, 'blockNumber': 50000},
              {'id': 'block_tx_002', 'fee': 200000, 'blockNumber': 50000},
            ],
          },
        });
        final infos = await client.getTransactionInfoByBlockNum(50000);
        expect(infos.length, equals(2));
        expect(infos[0].id, equals('block_tx_001'));
        expect(infos[1].id, equals('block_tx_002'));
      });

      test('returns empty list for empty block', () async {
        final client = _clientWithPathRouter({
          '/wallet/gettransactioninfobyblocknum': <String, dynamic>{},
        });
        final infos = await client.getTransactionInfoByBlockNum(99999);
        expect(infos, isEmpty);
      });

      test('sends block number as num field', () async {
        final (:client, :captured) = _clientCapturing(<String, dynamic>{});
        await client.getTransactionInfoByBlockNum(12345);
        final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
        expect(body['num'], equals(12345));
      });
    });
  });
}
