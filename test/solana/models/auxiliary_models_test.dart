import 'package:ceres_wallet_onchain/src/solana/models/epoch_info.dart';
import 'package:ceres_wallet_onchain/src/solana/models/vote_account.dart';
import 'package:ceres_wallet_onchain/src/solana/models/stake_activation.dart';
import 'package:ceres_wallet_onchain/src/solana/models/inflation.dart';
import 'package:ceres_wallet_onchain/src/solana/models/cluster_node.dart';
import 'package:ceres_wallet_onchain/src/solana/models/supply.dart';
import 'package:ceres_wallet_onchain/src/solana/models/block_production.dart';
import 'package:ceres_wallet_onchain/src/solana/models/performance_sample.dart';
import 'package:ceres_wallet_onchain/src/solana/models/block_commitment.dart';
import 'package:ceres_wallet_onchain/src/solana/models/snapshot_slot.dart';
import 'package:test/test.dart';

void main() {
  group('EpochInfo', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'epoch': 166,
        'slotIndex': 27140,
        'slotsInEpoch': 432000,
        'absoluteSlot': 71712027,
        'blockHeight': 65442935,
        'transactionCount': 2309478216,
      };

      final info = EpochInfo.fromJson(json);

      expect(info.epoch, equals(166));
      expect(info.slotIndex, equals(27140));
      expect(info.slotsInEpoch, equals(432000));
      expect(info.absoluteSlot, equals(71712027));
      expect(info.blockHeight, equals(65442935));
      expect(info.transactionCount, equals(BigInt.from(2309478216)));
    });

    test('fromJson handles null transactionCount', () {
      final json = <String, dynamic>{
        'epoch': 100,
        'slotIndex': 0,
        'slotsInEpoch': 432000,
        'absoluteSlot': 43200000,
        'blockHeight': 40000000,
      };

      final info = EpochInfo.fromJson(json);

      expect(info.transactionCount, isNull);
    });
  });

  group('EpochSchedule', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'slotsPerEpoch': 432000,
        'leaderScheduleSlotOffset': 432000,
        'warmup': true,
        'firstNormalEpoch': 14,
        'firstNormalSlot': 524256,
      };

      final schedule = EpochSchedule.fromJson(json);

      expect(schedule.slotsPerEpoch, equals(432000));
      expect(schedule.leaderScheduleSlotOffset, equals(432000));
      expect(schedule.warmup, isTrue);
      expect(schedule.firstNormalEpoch, equals(14));
      expect(schedule.firstNormalSlot, equals(524256));
    });
  });

  group('VoteAccount', () {
    test('fromJson parses vote account with BigInt activatedStake', () {
      final json = <String, dynamic>{
        'votePubkey': 'Vote111111111111111111111111111111111111111',
        'nodePubkey': 'Node111111111111111111111111111111111111111',
        'activatedStake': 42000000000,
        'epochVoteAccount': true,
        'commission': 10,
        'lastVote': 147743196,
        'rootSlot': 147743165,
        'epochCredits': [
          [1, 64, 0],
          [2, 192, 64],
        ],
      };

      final account = VoteAccount.fromJson(json);

      expect(
        account.votePubkey,
        equals('Vote111111111111111111111111111111111111111'),
      );
      expect(
        account.nodePubkey,
        equals('Node111111111111111111111111111111111111111'),
      );
      expect(account.activatedStake, equals(BigInt.from(42000000000)));
      expect(account.epochVoteAccount, isTrue);
      expect(account.commission, equals(10));
      expect(account.lastVote, equals(147743196));
      expect(account.rootSlot, equals(147743165));
      expect(account.epochCredits, isNotNull);
      expect(account.epochCredits!.length, equals(2));
    });
  });

  group('VoteAccountsResult', () {
    test('fromJson parses current and delinquent lists', () {
      final json = <String, dynamic>{
        'current': [
          {
            'votePubkey': 'Vote1',
            'nodePubkey': 'Node1',
            'activatedStake': 1000000,
            'epochVoteAccount': true,
            'commission': 5,
            'lastVote': 100,
          },
        ],
        'delinquent': [
          {
            'votePubkey': 'Vote2',
            'nodePubkey': 'Node2',
            'activatedStake': 500000,
            'epochVoteAccount': false,
            'commission': 10,
            'lastVote': 50,
          },
        ],
      };

      final result = VoteAccountsResult.fromJson(json);

      expect(result.current.length, equals(1));
      expect(result.delinquent.length, equals(1));
      expect(result.current[0].votePubkey, equals('Vote1'));
      expect(result.delinquent[0].activatedStake, equals(BigInt.from(500000)));
    });
  });

  group('StakeActivation', () {
    test('fromJson parses with BigInt active/inactive', () {
      final json = <String, dynamic>{
        'state': 'active',
        'active': 124429280,
        'inactive': 0,
      };

      final stake = StakeActivation.fromJson(json);

      expect(stake.state, equals('active'));
      expect(stake.active, equals(BigInt.from(124429280)));
      expect(stake.inactive, equals(BigInt.zero));
    });

    test('fromJson parses activating state', () {
      final json = <String, dynamic>{
        'state': 'activating',
        'active': 50000000,
        'inactive': 74429280,
      };

      final stake = StakeActivation.fromJson(json);

      expect(stake.state, equals('activating'));
    });
  });

  group('InflationGovernor', () {
    test('fromJson parses all double fields', () {
      final json = <String, dynamic>{
        'initial': 0.08,
        'terminal': 0.015,
        'taper': 0.15,
        'foundation': 0.05,
        'foundationTerm': 7.0,
      };

      final gov = InflationGovernor.fromJson(json);

      expect(gov.initial, equals(0.08));
      expect(gov.terminal, equals(0.015));
      expect(gov.taper, equals(0.15));
      expect(gov.foundation, equals(0.05));
      expect(gov.foundationTerm, equals(7.0));
    });
  });

  group('InflationRate', () {
    test('fromJson parses rate fields', () {
      final json = <String, dynamic>{
        'total': 0.06,
        'validator': 0.056,
        'foundation': 0.003,
        'epoch': 166,
      };

      final rate = InflationRate.fromJson(json);

      expect(rate.total, equals(0.06));
      expect(rate.validator, equals(0.056));
      expect(rate.foundation, equals(0.003));
      expect(rate.epoch, equals(166));
    });
  });

  group('InflationReward', () {
    test('fromJson parses reward with BigInt amount/postBalance', () {
      final json = <String, dynamic>{
        'epoch': 166,
        'effectiveSlot': 71712000,
        'amount': 2039280,
        'postBalance': 500002039280,
        'commission': 10,
      };

      final reward = InflationReward.fromJson(json);

      expect(reward.epoch, equals(166));
      expect(reward.effectiveSlot, equals(71712000));
      expect(reward.amount, equals(BigInt.from(2039280)));
      expect(reward.postBalance, equals(BigInt.from(500002039280)));
      expect(reward.commission, equals(10));
    });

    test('fromJson handles null commission', () {
      final json = <String, dynamic>{
        'epoch': 100,
        'effectiveSlot': 43200000,
        'amount': 1000,
        'postBalance': 50001000,
      };

      final reward = InflationReward.fromJson(json);

      expect(reward.commission, isNull);
    });
  });

  group('ClusterNode', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'pubkey': 'ClusterNode111',
        'gossip': '10.0.0.1:8001',
        'tpu': '10.0.0.1:8004',
        'rpc': '10.0.0.1:8899',
        'version': '1.14.17',
        'featureSet': 3580551090,
        'shredVersion': 42,
      };

      final node = ClusterNode.fromJson(json);

      expect(node.pubkey, equals('ClusterNode111'));
      expect(node.gossip, equals('10.0.0.1:8001'));
      expect(node.tpu, equals('10.0.0.1:8004'));
      expect(node.rpc, equals('10.0.0.1:8899'));
      expect(node.version, equals('1.14.17'));
      expect(node.featureSet, equals(3580551090));
      expect(node.shredVersion, equals(42));
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{'pubkey': 'ClusterNode222'};

      final node = ClusterNode.fromJson(json);

      expect(node.pubkey, equals('ClusterNode222'));
      expect(node.gossip, isNull);
      expect(node.tpu, isNull);
      expect(node.rpc, isNull);
      expect(node.version, isNull);
    });
  });

  group('Supply', () {
    test('fromJson parses BigInt values', () {
      final json = <String, dynamic>{
        'total': 500000000000000000,
        'circulating': 350000000000000000,
        'nonCirculating': 150000000000000000,
        'nonCirculatingAccounts': ['account1', 'account2'],
      };

      final supply = Supply.fromJson(json);

      expect(supply.total, equals(BigInt.from(500000000000000000)));
      expect(supply.circulating, equals(BigInt.from(350000000000000000)));
      expect(supply.nonCirculating, equals(BigInt.from(150000000000000000)));
      expect(supply.nonCirculatingAccounts.length, equals(2));
    });
  });

  group('BlockProduction', () {
    test('fromJson parses byIdentity and range', () {
      final json = <String, dynamic>{
        'byIdentity': {
          'validator1': [100, 98],
          'validator2': [50, 45],
        },
        'range': {'firstSlot': 1000, 'lastSlot': 2000},
      };

      final production = BlockProduction.fromJson(json);

      expect(production.byIdentity['validator1'], equals([100, 98]));
      expect(production.byIdentity['validator2'], equals([50, 45]));
      expect(production.range['firstSlot'], equals(1000));
      expect(production.range['lastSlot'], equals(2000));
    });
  });

  group('PerformanceSample', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'slot': 166974442,
        'numTransactions': 78462,
        'numSlots': 60,
        'samplePeriodSecs': 60,
        'numNonVoteTransactions': 12345,
      };

      final sample = PerformanceSample.fromJson(json);

      expect(sample.slot, equals(166974442));
      expect(sample.numTransactions, equals(78462));
      expect(sample.numSlots, equals(60));
      expect(sample.samplePeriodSecs, equals(60));
      expect(sample.numNonVoteTransactions, equals(12345));
    });

    test('fromJson handles null numNonVoteTransactions', () {
      final json = <String, dynamic>{
        'slot': 100,
        'numTransactions': 50,
        'numSlots': 60,
        'samplePeriodSecs': 60,
      };

      final sample = PerformanceSample.fromJson(json);

      expect(sample.numNonVoteTransactions, isNull);
    });
  });

  group('BlockCommitment', () {
    test('fromJson parses commitment and totalStake', () {
      final json = <String, dynamic>{
        'commitment': [0, 0, 0, 1, 2, 5, 10, 20, 50, 100],
        'totalStake': 42000000000,
      };

      final commitment = BlockCommitment.fromJson(json);

      expect(commitment.commitment, isNotNull);
      expect(commitment.commitment!.length, equals(10));
      expect(commitment.totalStake, equals(BigInt.from(42000000000)));
    });

    test('fromJson handles null commitment', () {
      final json = <String, dynamic>{
        'commitment': null,
        'totalStake': 42000000000,
      };

      final commitment = BlockCommitment.fromJson(json);

      expect(commitment.commitment, isNull);
    });
  });

  group('SnapshotSlot', () {
    test('fromJson parses full and incremental', () {
      final json = <String, dynamic>{'full': 100, 'incremental': 110};

      final snapshot = SnapshotSlot.fromJson(json);

      expect(snapshot.full, equals(100));
      expect(snapshot.incremental, equals(110));
    });

    test('fromJson handles null incremental', () {
      final json = <String, dynamic>{'full': 100};

      final snapshot = SnapshotSlot.fromJson(json);

      expect(snapshot.full, equals(100));
      expect(snapshot.incremental, isNull);
    });
  });
}
