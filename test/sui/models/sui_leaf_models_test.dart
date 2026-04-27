import 'package:ceres_wallet_onchain/src/sui/models/sui_balance.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_coin.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_coin_metadata.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_event.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_checkpoint.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_dynamic_field.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_stake.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_validators_apy.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_committee_info.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_paginated.dart';
import 'package:test/test.dart';

void main() {
  group('SuiBalance', () {
    test('fromJson parses correctly with BigInt totalBalance', () {
      final json = {
        'coinType': '0x2::sui::SUI',
        'coinObjectCount': 5,
        'totalBalance': '1000000000',
      };
      final balance = SuiBalance.fromJson(json);
      expect(balance.coinType, '0x2::sui::SUI');
      expect(balance.coinObjectCount, 5);
      expect(balance.totalBalance, BigInt.from(1000000000));
    });

    test('fromJson handles large totalBalance', () {
      final json = {
        'coinType': '0x2::sui::SUI',
        'coinObjectCount': 1,
        'totalBalance': '99999999999999999999',
      };
      final balance = SuiBalance.fromJson(json);
      expect(balance.totalBalance, BigInt.parse('99999999999999999999'));
    });
  });

  group('SuiCoin', () {
    test('fromJson parses all fields', () {
      final json = {
        'coinType': '0x2::sui::SUI',
        'coinObjectId': '0xabc123',
        'version': '1',
        'digest': 'digestHash',
        'balance': '500',
        'previousTransaction': 'txDigest123',
      };
      final coin = SuiCoin.fromJson(json);
      expect(coin.coinType, '0x2::sui::SUI');
      expect(coin.coinObjectId, '0xabc123');
      expect(coin.version, '1');
      expect(coin.digest, 'digestHash');
      expect(coin.balance, BigInt.from(500));
      expect(coin.previousTransaction, 'txDigest123');
    });

    test('paginated coins fromJson works', () {
      final json = {
        'data': [
          {
            'coinType': '0x2::sui::SUI',
            'coinObjectId': '0x1',
            'version': '1',
            'digest': 'd1',
            'balance': '100',
            'previousTransaction': 'tx1',
          },
        ],
        'hasNextPage': false,
      };
      final page = SuiPaginatedResponse.fromJson(
        json,
        (item) => SuiCoin.fromJson(item as Map<String, dynamic>),
      );
      expect(page.data.length, 1);
      expect(page.data.first.balance, BigInt.from(100));
    });
  });

  group('SuiCoinMetadata', () {
    test('fromJson parses all fields including nullable', () {
      final json = {
        'decimals': 9,
        'name': 'Sui',
        'symbol': 'SUI',
        'description': 'The native token',
        'iconUrl': 'https://example.com/icon.png',
        'id': '0xmeta123',
      };
      final meta = SuiCoinMetadata.fromJson(json);
      expect(meta.decimals, 9);
      expect(meta.name, 'Sui');
      expect(meta.symbol, 'SUI');
      expect(meta.description, 'The native token');
      expect(meta.iconUrl, 'https://example.com/icon.png');
      expect(meta.id, '0xmeta123');
    });

    test('fromJson handles null iconUrl', () {
      final json = {
        'decimals': 6,
        'name': 'USDC',
        'symbol': 'USDC',
        'description': 'USD Coin',
        'id': '0xusdc',
      };
      final meta = SuiCoinMetadata.fromJson(json);
      expect(meta.iconUrl, isNull);
    });
  });

  group('SuiEvent', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': {'txDigest': 'tx123', 'eventSeq': '0'},
        'packageId': '0xpkg',
        'transactionModule': 'module',
        'sender': '0xsender',
        'type': '0x2::coin::CoinEvent',
        'parsedJson': {'amount': '100'},
        'bcs': 'bcsdata',
        'timestampMs': '1700000000000',
      };
      final event = SuiEvent.fromJson(json);
      expect(event.id['txDigest'], 'tx123');
      expect(event.id['eventSeq'], '0');
      expect(event.packageId, '0xpkg');
      expect(event.transactionModule, 'module');
      expect(event.sender, '0xsender');
      expect(event.type, '0x2::coin::CoinEvent');
      expect(event.parsedJson, {'amount': '100'});
      expect(event.bcs, 'bcsdata');
      expect(event.timestampMs, '1700000000000');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': {'txDigest': 'tx456', 'eventSeq': '1'},
        'packageId': '0xpkg2',
        'transactionModule': 'mod2',
        'sender': '0xsender2',
        'type': '0x2::event::Type',
      };
      final event = SuiEvent.fromJson(json);
      expect(event.parsedJson, isNull);
      expect(event.bcs, isNull);
      expect(event.timestampMs, isNull);
    });
  });

  group('SuiCheckpoint', () {
    test('fromJson parses all fields with BigInt', () {
      final json = {
        'epoch': '0',
        'sequenceNumber': '1000',
        'digest': 'cpDigest',
        'networkTotalTransactions': '5000',
        'timestampMs': '1700000000000',
        'previousDigest': 'prevDigest',
        'epochRollingGasCostSummary': {
          'computationCost': '100',
          'storageCost': '200',
          'storageRebate': '50',
          'nonRefundableStorageFee': '10',
        },
        'transactions': ['tx1', 'tx2'],
      };
      final cp = SuiCheckpoint.fromJson(json);
      expect(cp.epoch, '0');
      expect(cp.sequenceNumber, BigInt.from(1000));
      expect(cp.digest, 'cpDigest');
      expect(cp.networkTotalTransactions, BigInt.from(5000));
      expect(cp.timestampMs, '1700000000000');
      expect(cp.previousDigest, 'prevDigest');
      expect(cp.epochRollingGasCostSummary.computationCost, BigInt.from(100));
      expect(cp.epochRollingGasCostSummary.storageCost, BigInt.from(200));
      expect(cp.epochRollingGasCostSummary.storageRebate, BigInt.from(50));
      expect(
        cp.epochRollingGasCostSummary.nonRefundableStorageFee,
        BigInt.from(10),
      );
      expect(cp.transactions, ['tx1', 'tx2']);
    });

    test('fromJson handles null previousDigest', () {
      final json = {
        'epoch': '1',
        'sequenceNumber': '0',
        'digest': 'genesis',
        'networkTotalTransactions': '0',
        'timestampMs': '0',
        'epochRollingGasCostSummary': {
          'computationCost': '0',
          'storageCost': '0',
          'storageRebate': '0',
          'nonRefundableStorageFee': '0',
        },
        'transactions': <String>[],
      };
      final cp = SuiCheckpoint.fromJson(json);
      expect(cp.previousDigest, isNull);
    });
  });

  group('SuiDynamicFieldInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': {'type': 'u64', 'value': '42'},
        'bcsName': 'bcsEncoded',
        'type': 'DynamicField',
        'objectType': '0x2::dynamic_field::Field<u64, u64>',
        'objectId': '0xobj123',
        'version': 5,
        'digest': 'dfDigest',
      };
      final df = SuiDynamicFieldInfo.fromJson(json);
      expect(df.name, {'type': 'u64', 'value': '42'});
      expect(df.bcsName, 'bcsEncoded');
      expect(df.type, 'DynamicField');
      expect(df.objectType, '0x2::dynamic_field::Field<u64, u64>');
      expect(df.objectId, '0xobj123');
      expect(df.version, 5);
      expect(df.digest, 'dfDigest');
    });
  });

  group('DelegatedStake', () {
    test('fromJson parses with stakes list', () {
      final json = {
        'validatorAddress': '0xval1',
        'stakingPool': '0xpool1',
        'stakes': [
          {
            'stakedSuiId': '0xstake1',
            'stakeRequestEpoch': '10',
            'stakeActiveEpoch': '11',
            'principal': '1000000000',
            'status': 'Active',
            'estimatedReward': '50000',
          },
        ],
      };
      final ds = DelegatedStake.fromJson(json);
      expect(ds.validatorAddress, '0xval1');
      expect(ds.stakingPool, '0xpool1');
      expect(ds.stakes.length, 1);
      expect(ds.stakes.first.stakedSuiId, '0xstake1');
      expect(ds.stakes.first.principal, BigInt.from(1000000000));
      expect(ds.stakes.first.status, 'Active');
      expect(ds.stakes.first.estimatedReward, BigInt.from(50000));
    });

    test('StakeObject handles null estimatedReward', () {
      final json = {
        'validatorAddress': '0xval2',
        'stakingPool': '0xpool2',
        'stakes': [
          {
            'stakedSuiId': '0xstake2',
            'stakeRequestEpoch': '5',
            'stakeActiveEpoch': '6',
            'principal': '500',
            'status': 'Pending',
          },
        ],
      };
      final ds = DelegatedStake.fromJson(json);
      expect(ds.stakes.first.estimatedReward, isNull);
    });
  });

  group('ValidatorsApy', () {
    test('fromJson parses apys list and epoch', () {
      final json = {
        'apys': [
          {'address': '0xval1', 'apy': 0.05},
          {'address': '0xval2', 'apy': 0.03},
        ],
        'epoch': '100',
      };
      final va = ValidatorsApy.fromJson(json);
      expect(va.epoch, '100');
      expect(va.apys.length, 2);
      expect(va.apys.first.address, '0xval1');
      expect(va.apys.first.apy, 0.05);
    });
  });

  group('CommitteeInfo', () {
    test('fromJson parses validators list and epoch', () {
      final json = {
        'epoch': '50',
        'validators': [
          ['authorityKey1', '1000000'],
          ['authorityKey2', '2000000'],
        ],
      };
      final ci = CommitteeInfo.fromJson(json);
      expect(ci.epoch, '50');
      expect(ci.validators.length, 2);
      expect(ci.validators.first.authorityName, 'authorityKey1');
      expect(ci.validators.first.stakeUnit, BigInt.from(1000000));
    });
  });

  group('SuiSupply', () {
    test('fromJson parses value as BigInt', () {
      final json = {'value': '10000000000000000000'};
      final supply = SuiSupply.fromJson(json);
      expect(supply.value, BigInt.parse('10000000000000000000'));
    });
  });
}
