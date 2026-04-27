import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Creates a [SuiRpcClient] backed by a [MockClient] that intercepts requests.
///
/// The [handler] receives the parsed JSON-RPC request body and returns
/// the `result` value for the response.
SuiRpcClient _createClient(
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
  return SuiRpcClient(
    transport: JsonRpcTransport(
      config: RpcClientConfig(baseUrl: 'https://fullnode.testnet.sui.io'),
      httpClient: mockClient,
    ),
  );
}

void main() {
  group('SuiRpcClient integration', () {
    test('getTransactionBlock returns digest and effects status', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return {
          'digest': 'TxDigest123',
          'effects': {
            'status': {'status': 'success'},
            'gasUsed': {
              'computationCost': '1000',
              'storageCost': '500',
              'storageRebate': '200',
              'nonRefundableStorageFee': '0',
            },
            'transactionDigest': 'TxDigest123',
          },
        };
      });

      final tx = await client.getTransactionBlock(
        'TxDigest123',
        options: SuiTransactionBlockResponseOptions(showEffects: true),
      );

      expect(capturedMethod, 'sui_getTransactionBlock');
      expect(tx.digest, 'TxDigest123');
      expect(tx.effects, isNotNull);
      expect(tx.effects!.status.isSuccess, isTrue);
      client.close();
    });

    test(
      'executeTransactionBlock sends txBytes and signatures in params',
      () async {
        late List<dynamic> capturedParams;
        final client = _createClient((req) {
          capturedParams = req['params'] as List<dynamic>;
          return {'digest': 'ExecDigest456'};
        });

        final tx = await client.executeTransactionBlock('base64TxBytes==', [
          'sig1base64',
          'sig2base64',
        ]);

        expect(capturedParams[0], 'base64TxBytes==');
        expect(capturedParams[1], ['sig1base64', 'sig2base64']);
        expect(tx.digest, 'ExecDigest456');
        client.close();
      },
    );

    test('getObject deserializes AddressOwner correctly', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return {
          'data': {
            'objectId':
                '0x0000000000000000000000000000000000000000000000000000000000000002',
            'version': '1',
            'digest': 'ObjDigest',
            'owner': {
              'AddressOwner':
                  '0x1111111111111111111111111111111111111111111111111111111111111111',
            },
          },
        };
      });

      final obj = await client.getObject(
        '0x2',
        options: SuiObjectDataOptions(showOwner: true),
      );

      expect(capturedMethod, 'sui_getObject');
      expect(obj.data, isNotNull);
      expect(obj.data!.owner, isNotNull);
      expect(obj.data!.owner, isA<SuiObjectOwnerAddress>());
      final addrOwner = obj.data!.owner! as SuiObjectOwnerAddress;
      expect(
        addrOwner.address,
        '0x1111111111111111111111111111111111111111111111111111111111111111',
      );
      client.close();
    });

    test('getBalance returns totalBalance as BigInt', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return {
          'coinType': '0x2::sui::SUI',
          'coinObjectCount': 3,
          'totalBalance': '9876543210',
          'lockedBalance': {},
        };
      });

      final owner = SuiAddress('0xabc');
      final balance = await client.getBalance(owner);

      expect(capturedMethod, 'suix_getBalance');
      expect(balance.totalBalance, BigInt.parse('9876543210'));
      expect(balance.coinType, '0x2::sui::SUI');
      expect(balance.coinObjectCount, 3);
      client.close();
    });

    test('getAllBalances returns multi-coin balance list', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return [
          {
            'coinType': '0x2::sui::SUI',
            'coinObjectCount': 2,
            'totalBalance': '1000000000',
            'lockedBalance': {},
          },
          {
            'coinType': '0xabc::token::USDC',
            'coinObjectCount': 1,
            'totalBalance': '500000',
            'lockedBalance': {},
          },
        ];
      });

      final owner = SuiAddress('0xdef');
      final balances = await client.getAllBalances(owner);

      expect(capturedMethod, 'suix_getAllBalances');
      expect(balances, hasLength(2));
      expect(balances[0].coinType, '0x2::sui::SUI');
      expect(balances[1].coinType, '0xabc::token::USDC');
      expect(balances[1].totalBalance, BigInt.parse('500000'));
      client.close();
    });

    test('getCheckpoint returns sequenceNumber as BigInt', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return {
          'epoch': '100',
          'sequenceNumber': '999888777',
          'digest': 'CpDigest',
          'networkTotalTransactions': '12345678',
          'timestampMs': '1700000000000',
          'previousDigest': 'PrevDigest',
          'epochRollingGasCostSummary': {
            'computationCost': '1000',
            'storageCost': '500',
            'storageRebate': '200',
            'nonRefundableStorageFee': '0',
          },
          'transactions': ['tx1', 'tx2'],
        };
      });

      final cp = await client.getCheckpoint('999888777');

      expect(capturedMethod, 'sui_getCheckpoint');
      expect(cp.sequenceNumber, BigInt.parse('999888777'));
      expect(cp.epoch, '100');
      expect(cp.digest, 'CpDigest');
      expect(cp.transactions, ['tx1', 'tx2']);
      client.close();
    });

    test('getCoins returns paginated coins with hasNextPage', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return {
          'data': [
            {
              'coinType': '0x2::sui::SUI',
              'coinObjectId': '0xobj1',
              'version': '10',
              'digest': 'CoinDigest1',
              'balance': '5000000000',
              'previousTransaction': 'PrevTx1',
            },
          ],
          'nextCursor': 'cursor123',
          'hasNextPage': true,
        };
      });

      final owner = SuiAddress('0xabc');
      final page = await client.getCoins(owner, limit: 1);

      expect(capturedMethod, 'suix_getCoins');
      expect(page.hasNextPage, isTrue);
      expect(page.nextCursor, 'cursor123');
      expect(page.data, hasLength(1));
      expect(page.data[0].coinObjectId, '0xobj1');
      expect(page.data[0].balance, BigInt.parse('5000000000'));
      client.close();
    });

    test('resolveNameServiceAddress returns null for unknown domain', () async {
      late String capturedMethod;
      final client = _createClient((req) {
        capturedMethod = req['method'] as String;
        return null;
      });

      final result = await client.resolveNameServiceAddress('unknown.sui');

      expect(capturedMethod, 'suix_resolveNameServiceAddress');
      expect(result, isNull);
      client.close();
    });
  });
}
