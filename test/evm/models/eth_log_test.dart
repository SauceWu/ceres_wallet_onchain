import 'package:ceres_wallet_onchain/src/evm/models/eth_log.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_withdrawal.dart';
import 'package:ceres_wallet_onchain/src/evm/models/access_list_entry.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_sync_status.dart';
import 'package:test/test.dart';

void main() {
  group('EthLog', () {
    test('fromJson parses a complete Ethereum log', () {
      final json = <String, dynamic>{
        'logIndex': '0x1',
        'transactionIndex': '0x0',
        'transactionHash':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'blockHash':
            '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        'blockNumber': '0x10d4f',
        'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'data':
            '0x000000000000000000000000000000000000000000000000000000003b9aca00',
        'topics': [
          '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
          '0x000000000000000000000000a7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270',
          '0x0000000000000000000000006b175474e89094c44da98b954eedeac495271d0f',
        ],
        'removed': false,
      };

      final log = EthLog.fromJson(json);

      expect(log.logIndex, equals(BigInt.one));
      expect(log.transactionIndex, equals(BigInt.zero));
      expect(
        log.transactionHash,
        equals(
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        ),
      );
      expect(
        log.blockHash,
        equals(
          '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        ),
      );
      expect(log.blockNumber, equals(BigInt.from(0x10d4f)));
      expect(
        log.address.toString(),
        equals('0xdAC17F958D2ee523a2206206994597C13D831ec7'),
      );
      expect(
        log.data,
        equals(
          '0x000000000000000000000000000000000000000000000000000000003b9aca00',
        ),
      );
      expect(log.topics.length, equals(3));
      expect(log.removed, isFalse);
    });

    test('fromJson handles pending log with null fields', () {
      final json = <String, dynamic>{
        'logIndex': null,
        'transactionIndex': null,
        'transactionHash': null,
        'blockHash': null,
        'blockNumber': null,
        'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'data': '0x',
        'topics': <String>[],
        'removed': false,
      };

      final log = EthLog.fromJson(json);

      expect(log.logIndex, isNull);
      expect(log.transactionIndex, isNull);
      expect(log.transactionHash, isNull);
      expect(log.blockHash, isNull);
      expect(log.blockNumber, isNull);
      expect(
        log.address.toHex(),
        equals('dac17f958d2ee523a2206206994597c13d831ec7'),
      );
      expect(log.data, equals('0x'));
      expect(log.topics, isEmpty);
    });

    test('fromJson handles removed=true log', () {
      final json = <String, dynamic>{
        'logIndex': '0x0',
        'transactionIndex': '0x0',
        'transactionHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        'blockHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        'blockNumber': '0x1',
        'address': '0x0000000000000000000000000000000000000001',
        'data': '0x',
        'topics': <String>[],
        'removed': true,
      };

      final log = EthLog.fromJson(json);
      expect(log.removed, isTrue);
    });
  });

  group('EthWithdrawal', () {
    test('fromJson parses EIP-4895 withdrawal', () {
      final json = <String, dynamic>{
        'index': '0x1',
        'validatorIndex': '0x2a',
        'address': '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        'amount': '0xe8d4a51000', // 1_000_000_000_000 Gwei
      };

      final w = EthWithdrawal.fromJson(json);
      expect(w.index, equals(BigInt.one));
      expect(w.validatorIndex, equals(BigInt.from(42)));
      expect(
        w.address.toHex(),
        equals('d8da6bf26964af9d7eed9e03e53415d37aa96045'),
      );
      expect(w.amount, equals(BigInt.from(1000000000000)));
    });
  });

  group('AccessListEntry', () {
    test('fromJson parses address and storageKeys', () {
      final json = <String, dynamic>{
        'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'storageKeys': [
          '0x0000000000000000000000000000000000000000000000000000000000000001',
          '0x0000000000000000000000000000000000000000000000000000000000000002',
        ],
      };

      final entry = AccessListEntry.fromJson(json);
      expect(
        entry.address.toString(),
        equals('0xdAC17F958D2ee523a2206206994597C13D831ec7'),
      );
      expect(entry.storageKeys.length, equals(2));
      expect(
        entry.storageKeys[0],
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        ),
      );
    });

    test('fromJson handles empty storageKeys', () {
      final json = <String, dynamic>{
        'address': '0x0000000000000000000000000000000000000001',
        'storageKeys': <String>[],
      };

      final entry = AccessListEntry.fromJson(json);
      expect(entry.storageKeys, isEmpty);
    });
  });

  group('EthSyncStatus', () {
    test('fromJson parses syncing block numbers', () {
      final json = <String, dynamic>{
        'startingBlock': '0x384',
        'currentBlock': '0x386',
        'highestBlock': '0x454',
      };

      final status = EthSyncStatus.fromJson(json);
      expect(status.startingBlock, equals(BigInt.from(0x384)));
      expect(status.currentBlock, equals(BigInt.from(0x386)));
      expect(status.highestBlock, equals(BigInt.from(0x454)));
    });
  });
}
