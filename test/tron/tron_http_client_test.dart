import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Known valid Tron base58 address for testing.
const _knownBase58 = 'TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA';

/// Creates a [TronHttpClient] backed by a [MockClient] that routes responses
/// based on the request path.
TronHttpClient _clientWithPathRouter(Map<String, Object> pathResponses) {
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
  return TronHttpClient(transport: transport);
}

/// Creates a [TronHttpClient] with a fixed response for all requests.
TronHttpClient _clientWithFixedResponse(Object response) {
  final mockHttp = MockClient((request) async {
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
  return TronHttpClient(transport: transport);
}

void main() {
  group('TronHttpClient', () {
    group('API surface completeness', () {
      test('exposes all 9 mixin method groups', () {
        final client = _clientWithFixedResponse({});

        // Account methods (TRON-01 ~ TRON-08)
        expect(client.getAccount, isA<Function>());
        expect(client.getAccountSolidity, isA<Function>());
        expect(client.getAccountBalance, isA<Function>());
        expect(client.getAccountNet, isA<Function>());
        expect(client.getAccountResource, isA<Function>());
        expect(client.createAccount, isA<Function>());
        expect(client.updateAccount, isA<Function>());
        expect(client.validateAddress, isA<Function>());

        // Transaction methods (TRON-09 ~ TRON-16)
        expect(client.createTransaction, isA<Function>());
        expect(client.broadcastTransaction, isA<Function>());
        expect(client.broadcastHex, isA<Function>());
        expect(client.getTransactionById, isA<Function>());
        expect(client.getTransactionByIdSolidity, isA<Function>());
        expect(client.getTransactionInfoById, isA<Function>());
        expect(client.getTransactionInfoByIdSolidity, isA<Function>());
        expect(client.getTransactionInfoByBlockNum, isA<Function>());

        // Block methods (TRON-17 ~ TRON-24)
        expect(client.getNowBlock, isA<Function>());
        expect(client.getNowBlockSolidity, isA<Function>());
        expect(client.getBlockByNum, isA<Function>());
        expect(client.getBlockByNumSolidity, isA<Function>());
        expect(client.getBlockById, isA<Function>());
        expect(client.getBlockByLimitNext, isA<Function>());
        expect(client.getBlockByLatestNum, isA<Function>());
        expect(client.getBlock, isA<Function>());

        // Contract methods (TRON-25 ~ TRON-34)
        expect(client.triggerSmartContract, isA<Function>());
        expect(client.triggerConstantContract, isA<Function>());
        expect(client.triggerConstantContractSolidity, isA<Function>());
        expect(client.deployContract, isA<Function>());
        expect(client.estimateEnergy, isA<Function>());
        expect(client.getContract, isA<Function>());
        expect(client.getContractInfo, isA<Function>());
        expect(client.updateSetting, isA<Function>());
        expect(client.updateEnergyLimit, isA<Function>());
        expect(client.clearAbi, isA<Function>());

        // Staking methods (TRON-35 ~ TRON-44)
        expect(client.freezeBalanceV2, isA<Function>());
        expect(client.unfreezeBalanceV2, isA<Function>());
        expect(client.withdrawExpireUnfreeze, isA<Function>());
        expect(client.delegateResource, isA<Function>());
        expect(client.undelegateResource, isA<Function>());
        expect(client.getAvailableUnfreezeCount, isA<Function>());
        expect(client.getCanWithdrawUnfreezeAmount, isA<Function>());
        expect(client.getCanDelegatedMaxSize, isA<Function>());
        expect(client.getDelegatedResourceV2, isA<Function>());
        expect(client.getDelegatedResourceAccountIndexV2, isA<Function>());

        // Witness methods (TRON-45 ~ TRON-50)
        expect(client.voteWitnessAccount, isA<Function>());
        expect(client.listWitnesses, isA<Function>());
        expect(client.getBrokerage, isA<Function>());
        expect(client.getReward, isA<Function>());
        expect(client.withdrawBalance, isA<Function>());
        expect(client.getNextMaintenanceTime, isA<Function>());

        // Asset methods (TRON-51 ~ TRON-56)
        expect(client.transferAsset, isA<Function>());
        expect(client.getAssetIssueById, isA<Function>());
        expect(client.getAssetIssueByIdSolidity, isA<Function>());
        expect(client.getAssetIssueList, isA<Function>());
        expect(client.getPaginatedAssetIssueList, isA<Function>());
        expect(client.getAssetIssueByAccount, isA<Function>());

        // Network methods (TRON-57 ~ TRON-62)
        expect(client.getChainParameters, isA<Function>());
        expect(client.getNodeInfo, isA<Function>());
        expect(client.listNodes, isA<Function>());
        expect(client.getEnergyPrices, isA<Function>());
        expect(client.getBandwidthPrices, isA<Function>());
        expect(client.getBurnTrx, isA<Function>());

        // Multisig methods (TRON-63 ~ TRON-65)
        expect(client.accountPermissionUpdate, isA<Function>());
        expect(client.getApprovedList, isA<Function>());
        expect(client.getSignWeight, isA<Function>());

        client.close();
      });
    });

    group('core flow integration', () {
      test('getAccount returns TronAccount', () async {
        final client = _clientWithPathRouter({
          '/wallet/getaccount': {
            'address': _knownBase58,
            'balance': 5000000,
            'create_time': 1600000000000,
          },
        });

        final account = await client.getAccount(TronAddress(_knownBase58));
        expect(account, isNotNull);
        expect(account!.balance, BigInt.from(5000000));
        client.close();
      });

      test('createTransaction returns unsigned TronTransaction', () async {
        final client = _clientWithPathRouter({
          '/wallet/createtransaction': {
            'txID': 'abc123def456',
            'raw_data': {
              'contract': [
                {
                  'type': 'TransferContract',
                  'parameter': {
                    'value': {
                      'owner_address': _knownBase58,
                      'to_address': _knownBase58,
                      'amount': 1000000,
                    },
                  },
                },
              ],
              'ref_block_bytes': '1234',
              'ref_block_hash': 'abcd1234',
              'expiration': 1700000000000,
              'timestamp': 1699999990000,
            },
            'raw_data_hex': 'deadbeef',
          },
        });

        final tx = await client.createTransaction(
          ownerAddress: TronAddress(_knownBase58),
          toAddress: TronAddress(_knownBase58),
          amount: BigInt.from(1000000),
        );
        expect(tx.txID, 'abc123def456');
        client.close();
      });

      test(
        'triggerSmartContract returns TronTriggerResult with transaction',
        () async {
          final client = _clientWithPathRouter({
            '/wallet/triggersmartcontract': {
              'result': {'result': true},
              'transaction': {
                'txID': 'trigger_tx_id',
                'raw_data': {
                  'contract': [
                    {
                      'type': 'TriggerSmartContract',
                      'parameter': {'value': {}},
                    },
                  ],
                  'ref_block_bytes': '5678',
                  'ref_block_hash': 'ef012345',
                  'expiration': 1700000000000,
                  'timestamp': 1699999990000,
                },
                'raw_data_hex': 'cafebabe',
              },
            },
          });

          final result = await client.triggerSmartContract(
            ownerAddress: TronAddress(_knownBase58),
            contractAddress: TronAddress(_knownBase58),
            functionSelector: 'transfer(address,uint256)',
            parameter:
                '0000000000000000000000000000000000000000000000000000000000000001',
          );
          expect(result.resultOk, isTrue);
          expect(result.transaction, isNotNull);
          expect(result.transaction!.txID, 'trigger_tx_id');
          client.close();
        },
      );

      test('getNowBlock returns TronBlock', () async {
        final client = _clientWithPathRouter({
          '/wallet/getnowblock': {
            'blockID': 'block_hash_abc',
            'block_header': {
              'raw_data': {
                'number': 12345678,
                'txTrieRoot': 'root_hash',
                'witness_address': _knownBase58,
                'parentHash': 'parent_hash',
                'timestamp': 1699999990000,
              },
              'witness_signature': 'sig_hex',
            },
          },
        });

        final block = await client.getNowBlock();
        expect(block.blockID, 'block_hash_abc');
        expect(block.blockHeader?.number, 12345678);
        client.close();
      });

      test('broadcastHex returns TronBroadcastResult', () async {
        final client = _clientWithPathRouter({
          '/wallet/broadcasthex': {'result': true, 'txid': 'broadcast_tx_hash'},
        });

        final result = await client.broadcastHex('deadbeefcafebabe');
        expect(result.result, isTrue);
        expect(result.txid, 'broadcast_tx_hash');
        client.close();
      });
    });

    group('barrel export verification', () {
      test('all Tron types accessible from barrel import', () {
        // These type references compile only if the barrel exports them.
        // If any export is missing, this test fails at compile time.
        expect(TronHttpClient, isNotNull);
        expect(TronAddress, isNotNull);
        expect(TronAccount, isNotNull);
        expect(TronBlock, isNotNull);
        expect(TronTransaction, isNotNull);
        expect(TronTransactionInfo, isNotNull);
        expect(TronAccountResource, isNotNull);
        expect(TronTriggerResult, isNotNull);
        expect(TronBroadcastResult, isNotNull);
        expect(TronWitness, isNotNull);
        expect(TronAssetIssue, isNotNull);
        expect(TronChainParameters, isNotNull);
        expect(TronNodeInfo, isNotNull);
      });
    });

    group('error handling integration', () {
      test('Tron top-level Error field throws RpcException', () async {
        final client = _clientWithFixedResponse({'Error': 'Account not found'});

        // createAccount calls checkTronError
        expect(
          () => client.createAccount(
            ownerAddress: TronAddress(_knownBase58),
            accountAddress: TronAddress(_knownBase58),
          ),
          throwsA(
            isA<RpcException>().having(
              (e) => e.message,
              'message',
              'Account not found',
            ),
          ),
        );
        client.close();
      });

      test(
        'Tron result.result=false throws RpcException with decoded message',
        () async {
          // Hex-encoded "balance is not sufficient"
          const hexMsg = '62616c616e6365206973206e6f742073756666696369656e74';
          final client = _clientWithFixedResponse({
            'result': {
              'result': false,
              'code': 'CONTRACT_VALIDATE_ERROR',
              'message': hexMsg,
            },
          });

          expect(
            () => client.createTransaction(
              ownerAddress: TronAddress(_knownBase58),
              toAddress: TronAddress(_knownBase58),
              amount: BigInt.from(1000000),
            ),
            throwsA(
              isA<RpcException>().having(
                (e) => e.message,
                'message',
                contains('balance is not sufficient'),
              ),
            ),
          );
          client.close();
        },
      );
    });

    group('transport lifecycle', () {
      test('close delegates to transport', () {
        // Verify close() does not throw
        final client = _clientWithFixedResponse({});
        client.close();
      });
    });
  });
}
