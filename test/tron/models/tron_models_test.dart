import 'package:test/test.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_account.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_block.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_transaction.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_transaction_info.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_account_resource.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_trigger_result.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_broadcast_result.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_witness.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_asset_issue.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_chain_parameters.dart';
import 'package:ceres_wallet_onchain/src/tron/models/tron_node_info.dart';

void main() {
  group('TronAccount', () {
    test('fromJson parses full account response', () {
      final json = {
        'address': 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
        'balance': 100000000,
        'create_time': 1629878400000,
        'assetV2': [
          {'key': '1000001', 'value': 50000},
          {'key': '1000002', 'value': 200},
        ],
        'frozenV2': [
          {'type': 'ENERGY', 'amount': 5000000},
          {'type': 'BANDWIDTH'},
        ],
        'unfreezeV2': [
          {
            'type': 'ENERGY',
            'unfreeze_amount': 1000000,
            'unfreeze_expire_time': 1700000000000,
          },
        ],
        'delegated_frozenV2_balance_for_bandwidth': 2000000,
        'acquired_delegated_frozenV2_balance_for_bandwidth': 3000000,
        'account_resource': {'energy_window_size': 1},
        'owner_permission': {'type': 0, 'permission_name': 'owner'},
        'active_permission': [
          {'type': 2, 'permission_name': 'active'},
        ],
        'net_window_size': 28800,
        'net_window_optimized': true,
      };

      final account = TronAccount.fromJson(json);
      expect(account.address, 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW');
      expect(account.balance, BigInt.from(100000000));
      expect(account.createTime, 1629878400000);
      expect(account.assetV2.length, 2);
      expect(account.assetV2[0].key, '1000001');
      expect(account.assetV2[0].value, BigInt.from(50000));
      expect(account.assetV2[1].key, '1000002');
      expect(account.frozenV2!.length, 2);
      expect(account.frozenV2![0].type, 'ENERGY');
      expect(account.frozenV2![0].amount, BigInt.from(5000000));
      expect(account.frozenV2![1].type, 'BANDWIDTH');
      expect(account.frozenV2![1].amount, isNull);
      expect(account.unfreezeV2!.length, 1);
      expect(account.unfreezeV2![0].unfreezeAmount, BigInt.from(1000000));
      expect(account.unfreezeV2![0].unfreezeExpireTime, 1700000000000);
      expect(
        account.delegatedFrozenV2BalanceForBandwidth,
        BigInt.from(2000000),
      );
      expect(
        account.acquiredDelegatedFrozenV2BalanceForBandwidth,
        BigInt.from(3000000),
      );
      expect(account.netWindowSize, 28800);
      expect(account.netWindowOptimized, true);
      expect(account.ownerPermission, isNotNull);
      expect(account.activePermission!.length, 1);
    });

    test('fromJson handles minimal/empty account', () {
      final account = TronAccount.fromJson({});
      expect(account.address, isNull);
      expect(account.balance, BigInt.zero);
      expect(account.assetV2, isEmpty);
      expect(account.frozenV2, isNull);
      expect(account.unfreezeV2, isNull);
      expect(account.createTime, isNull);
    });
  });

  group('TronBlock', () {
    test('fromJson parses block with transactions', () {
      final json = {
        'blockID':
            '000000000202f4b6a0c54a4d3c5e8d1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d',
        'block_header': {
          'raw_data': {
            'number': 33813686,
            'txTrieRoot':
                'abc123def456789012345678901234567890123456789012345678901234',
            'parentHash':
                'def456789012345678901234567890123456789012345678901234567890ab',
            'witness_address': 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
            'timestamp': 1700000000000,
            'version': 29,
          },
          'witness_signature': 'aabbccdd',
        },
        'transactions': [
          {
            'txID': 'abc123',
            'raw_data': {
              'contract': [
                {'type': 'TransferContract'},
              ],
              'ref_block_bytes': 'f4b4',
              'ref_block_hash': '1234567890abcdef',
              'expiration': 1700000060000,
              'timestamp': 1700000000000,
            },
            'raw_data_hex': 'deadbeef',
            'signature': ['sig1'],
          },
        ],
      };

      final block = TronBlock.fromJson(json);
      expect(block.blockID, startsWith('0000000002'));
      expect(block.blockHeader, isNotNull);
      expect(block.blockHeader!.number, 33813686);
      expect(block.blockHeader!.timestamp, 1700000000000);
      expect(block.blockHeader!.version, 29);
      expect(
        block.blockHeader!.witnessAddress,
        'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
      );
      expect(block.blockHeader!.witnessSignature, 'aabbccdd');
      expect(block.transactions.length, 1);
      expect(block.transactions[0].txID, 'abc123');
    });

    test('fromJson handles empty block', () {
      final block = TronBlock.fromJson({});
      expect(block.blockID, isNull);
      expect(block.blockHeader, isNull);
      expect(block.transactions, isEmpty);
    });
  });

  group('TronTransaction', () {
    test('fromJson parses full transaction', () {
      final json = {
        'txID': 'abc123def456',
        'raw_data': {
          'contract': [
            {
              'parameter': {
                'value': {
                  'amount': 1000000,
                  'owner_address': 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
                  'to_address': 'TVDGpn4hCSzJ5nkHPLetk8KQBtwaTppnkr',
                },
                'type_url': 'type.googleapis.com/protocol.TransferContract',
              },
              'type': 'TransferContract',
            },
          ],
          'ref_block_bytes': 'f4b4',
          'ref_block_hash': '1234567890abcdef',
          'expiration': 1700000060000,
          'timestamp': 1700000000000,
          'fee_limit': 100000000,
          'data': 'hello tron',
        },
        'raw_data_hex': 'deadbeef',
        'signature': ['sig1hex', 'sig2hex'],
        'ret': [
          {'contractRet': 'SUCCESS'},
        ],
      };

      final tx = TronTransaction.fromJson(json);
      expect(tx.txID, 'abc123def456');
      expect(tx.rawData, isNotNull);
      expect(tx.rawData!.contract.length, 1);
      expect(tx.rawData!.contract[0]['type'], 'TransferContract');
      expect(tx.rawData!.refBlockBytes, 'f4b4');
      expect(tx.rawData!.refBlockHash, '1234567890abcdef');
      expect(tx.rawData!.expiration, 1700000060000);
      expect(tx.rawData!.timestamp, 1700000000000);
      expect(tx.rawData!.feeLimit, BigInt.from(100000000));
      expect(tx.rawData!.data, 'hello tron');
      expect(tx.rawDataHex, 'deadbeef');
      expect(tx.signature.length, 2);
      expect(tx.ret!.length, 1);
      expect(tx.ret![0]['contractRet'], 'SUCCESS');
    });

    test('fromJson handles missing fields', () {
      final tx = TronTransaction.fromJson({'txID': 'minimal'});
      expect(tx.txID, 'minimal');
      expect(tx.rawData, isNull);
      expect(tx.rawDataHex, isNull);
      expect(tx.signature, isEmpty);
      expect(tx.ret, isNull);
    });
  });

  group('TronTransactionInfo', () {
    test('fromJson parses full transaction info with receipt and logs', () {
      final json = {
        'id': 'abc123def456',
        'fee': 1100000,
        'blockNumber': 33813686,
        'blockTimeStamp': 1700000000000,
        'contractResult': ['0000000000000000000000000000000000000001'],
        'contract_address': 'TContractAddr123',
        'receipt': {
          'energy_usage': 20000,
          'energy_fee': 500000,
          'origin_energy_usage': 10000,
          'energy_usage_total': 30000,
          'net_usage': 345,
          'net_fee': 0,
          'result': 'SUCCESS',
        },
        'log': [
          {
            'address': 'abc123',
            'topics': [
              'ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
              '0000000000000000000000001234567890abcdef1234567890abcdef12345678',
            ],
            'data':
                '0000000000000000000000000000000000000000000000000de0b6b3a7640000',
          },
        ],
        'result': null,
        'resMessage': null,
        'internal_transactions': [
          {'caller_address': 'T123', 'note': 'call'},
        ],
      };

      final info = TronTransactionInfo.fromJson(json);
      expect(info.id, 'abc123def456');
      expect(info.fee, BigInt.from(1100000));
      expect(info.blockNumber, 33813686);
      expect(info.blockTimeStamp, 1700000000000);
      expect(info.contractResult!.length, 1);
      expect(info.contractAddress, 'TContractAddr123');
      expect(info.receipt, isNotNull);
      expect(info.receipt!.energyUsage, BigInt.from(20000));
      expect(info.receipt!.energyFee, BigInt.from(500000));
      expect(info.receipt!.originEnergyUsage, BigInt.from(10000));
      expect(info.receipt!.energyUsageTotal, BigInt.from(30000));
      expect(info.receipt!.netUsage, BigInt.from(345));
      expect(info.receipt!.netFee, BigInt.zero);
      expect(info.receipt!.result, 'SUCCESS');
      expect(info.log!.length, 1);
      expect(info.log![0].topics.length, 2);
      expect(info.log![0].address, 'abc123');
      expect(info.internalTransactions!.length, 1);
    });

    test('fromJson handles failed transaction', () {
      final json = {
        'id': 'fail123',
        'fee': 2000000,
        'blockNumber': 100,
        'blockTimeStamp': 1700000000000,
        'contractResult': [''],
        'receipt': {'result': 'REVERT', 'energy_usage_total': 50000},
        'result': 'FAILED',
        'resMessage': '4f555420454e45524759',
      };

      final info = TronTransactionInfo.fromJson(json);
      expect(info.result, 'FAILED');
      expect(info.resMessage, '4f555420454e45524759');
      expect(info.receipt!.result, 'REVERT');
      expect(info.receipt!.energyUsageTotal, BigInt.from(50000));
    });

    test('fromJson handles empty info', () {
      final info = TronTransactionInfo.fromJson({});
      expect(info.id, isNull);
      expect(info.fee, isNull);
      expect(info.receipt, isNull);
      expect(info.log, isNull);
    });
  });

  group('TronAccountResource', () {
    test('fromJson parses full resource response', () {
      final json = {
        'freeNetUsed': 100,
        'freeNetLimit': 1500,
        'NetUsed': 200,
        'NetLimit': 5000,
        'EnergyUsed': 3000,
        'EnergyLimit': 100000,
        'TotalNetLimit': 43200000000,
        'TotalNetWeight': 10000000000,
        'TotalEnergyLimit': 50000000000,
        'TotalEnergyWeight': 20000000000,
        'tronPowerUsed': 50,
        'tronPowerLimit': 100,
      };

      final resource = TronAccountResource.fromJson(json);
      expect(resource.freeNetUsed, BigInt.from(100));
      expect(resource.freeNetLimit, BigInt.from(1500));
      expect(resource.netUsed, BigInt.from(200));
      expect(resource.netLimit, BigInt.from(5000));
      expect(resource.energyUsed, BigInt.from(3000));
      expect(resource.energyLimit, BigInt.from(100000));
      expect(resource.totalNetLimit, BigInt.from(43200000000));
      expect(resource.totalNetWeight, BigInt.from(10000000000));
      expect(resource.totalEnergyLimit, BigInt.from(50000000000));
      expect(resource.totalEnergyWeight, BigInt.from(20000000000));
      expect(resource.tronPowerUsed, BigInt.from(50));
      expect(resource.tronPowerLimit, BigInt.from(100));
    });

    test('fromJson handles empty response', () {
      final resource = TronAccountResource.fromJson({});
      expect(resource.freeNetUsed, isNull);
      expect(resource.energyLimit, isNull);
      expect(resource.totalNetLimit, isNull);
    });
  });

  group('TronTriggerResult', () {
    test('fromJson parses successful constant call', () {
      final json = {
        'result': {'result': true},
        'energy_used': 895,
        'energy_penalty': 0,
        'constant_result': [
          '0000000000000000000000000000000000000000000000000000000005f5e100',
        ],
      };

      final result = TronTriggerResult.fromJson(json);
      expect(result.resultOk, true);
      expect(result.energyUsed, 895);
      expect(result.energyPenalty, 0);
      expect(result.constantResult.length, 1);
      expect(result.transaction, isNull);
    });

    test('fromJson parses write call with transaction', () {
      final json = {
        'result': {'result': true},
        'energy_used': 30000,
        'transaction': {
          'txID': 'tx123',
          'raw_data': {
            'contract': [
              {'type': 'TriggerSmartContract'},
            ],
            'ref_block_bytes': 'abcd',
            'ref_block_hash': '1234567890abcdef',
            'expiration': 1700000060000,
            'timestamp': 1700000000000,
            'fee_limit': 100000000,
          },
          'raw_data_hex': 'cafebabe',
        },
      };

      final result = TronTriggerResult.fromJson(json);
      expect(result.resultOk, true);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.txID, 'tx123');
      expect(result.transaction!.rawData!.feeLimit, BigInt.from(100000000));
      expect(result.constantResult, isEmpty);
    });

    test('fromJson handles failed result', () {
      final json = {
        'result': {'result': false, 'code': 'OTHER_ERROR', 'message': 'err'},
      };

      final result = TronTriggerResult.fromJson(json);
      expect(result.resultOk, false);
      expect(result.energyUsed, isNull);
      expect(result.transaction, isNull);
    });

    test('fromJson handles missing result field', () {
      final result = TronTriggerResult.fromJson({});
      expect(result.resultOk, false);
      expect(result.constantResult, isEmpty);
    });
  });

  group('TronBroadcastResult', () {
    test('fromJson parses success response', () {
      final json = {
        'result': true,
        'txid': 'abc123def456789012345678901234567890',
      };

      final result = TronBroadcastResult.fromJson(json);
      expect(result.result, true);
      expect(result.txid, 'abc123def456789012345678901234567890');
      expect(result.code, isNull);
      expect(result.message, isNull);
    });

    test('fromJson parses failure response', () {
      final json = {
        'result': false,
        'code': 'SIGERROR',
        'message': '53494720455252',
      };

      final result = TronBroadcastResult.fromJson(json);
      expect(result.result, false);
      expect(result.code, 'SIGERROR');
      expect(result.message, '53494720455252');
      expect(result.txid, isNull);
    });

    test('fromJson handles missing result field', () {
      final result = TronBroadcastResult.fromJson({});
      expect(result.result, false);
    });
  });

  group('TronWitness', () {
    test('fromJson parses witness data', () {
      final json = {
        'address': 'TWitnessAddr123',
        'voteCount': 150000000,
        'url': 'https://example.com',
        'totalProduced': 12345,
        'totalMissed': 67,
        'latestBlockNum': 33813686,
        'latestSlotNum': 550000000,
        'isJobs': true,
      };

      final witness = TronWitness.fromJson(json);
      expect(witness.address, 'TWitnessAddr123');
      expect(witness.voteCount, BigInt.from(150000000));
      expect(witness.url, 'https://example.com');
      expect(witness.totalProduced, BigInt.from(12345));
      expect(witness.totalMissed, BigInt.from(67));
      expect(witness.latestBlockNum, 33813686);
      expect(witness.isJobs, true);
    });

    test('fromJson handles minimal witness', () {
      final witness = TronWitness.fromJson({'address': 'T123'});
      expect(witness.address, 'T123');
      expect(witness.voteCount, isNull);
      expect(witness.isJobs, isNull);
    });
  });

  group('TronAssetIssue', () {
    test('fromJson parses asset issue data', () {
      final json = {
        'owner_address': 'TOwnerAddr123',
        'name': 'TestToken',
        'abbr': 'TT',
        'total_supply': 1000000000000,
        'trx_num': 1000000,
        'precision': 6,
        'num': 1,
        'start_time': 1600000000000,
        'end_time': 1700000000000,
        'description': 'A test token',
        'url': 'https://token.example.com',
        'id': '1000001',
      };

      final asset = TronAssetIssue.fromJson(json);
      expect(asset.ownerAddress, 'TOwnerAddr123');
      expect(asset.name, 'TestToken');
      expect(asset.abbr, 'TT');
      expect(asset.totalSupply, BigInt.from(1000000000000));
      expect(asset.precision, 6);
      expect(asset.id, '1000001');
    });

    test('fromJson handles empty json', () {
      final asset = TronAssetIssue.fromJson({});
      expect(asset.name, isNull);
      expect(asset.totalSupply, isNull);
    });
  });

  group('TronChainParameters', () {
    test('fromJson parses chain parameters', () {
      final json = {
        'chainParameter': [
          {'key': 'getMaintenanceTimeInterval', 'value': 21600000},
          {'key': 'getAccountUpgradeCost', 'value': 9999000000},
          {'key': 'getCreateAccountFee', 'value': 100000},
        ],
      };

      final params = TronChainParameters.fromJson(json);
      expect(params.parameters.length, 3);
      expect(params.parameters[0].key, 'getMaintenanceTimeInterval');
      expect(params.parameters[0].value, 21600000);
      expect(params.parameters[2].key, 'getCreateAccountFee');
      expect(params.parameters[2].value, 100000);
    });

    test('fromJson handles missing chainParameter', () {
      final params = TronChainParameters.fromJson({});
      expect(params.parameters, isEmpty);
    });
  });

  group('TronNodeInfo', () {
    test('fromJson parses node info', () {
      final json = {
        'beginSyncNum': 33813000,
        'block': 'Num:33813686,ID:0000000002...',
        'solidityBlock': 33813680,
        'currentConnectCount': 30,
        'activeConnectCount': 15,
        'passiveConnectCount': 15,
        'totalFlow': 1000000,
        'configNodeInfo': {'codeVersion': '4.7.4'},
        'machineInfo': {'javaVersion': '1.8.0'},
      };

      final info = TronNodeInfo.fromJson(json);
      expect(info.beginSyncNum, 33813000);
      expect(info.block, contains('33813686'));
      expect(info.solidityBlock, 33813680);
      expect(info.currentConnectCount, 30);
      expect(info.activeConnectCount, 15);
      expect(info.passiveConnectCount, 15);
      expect(info.totalFlow, 1000000);
      expect(info.configNodeInfo, isNotNull);
      expect(info.machineInfo, isNotNull);
    });

    test('fromJson handles empty json', () {
      final info = TronNodeInfo.fromJson({});
      expect(info.beginSyncNum, isNull);
      expect(info.block, isNull);
      expect(info.configNodeInfo, isNull);
    });
  });
}
