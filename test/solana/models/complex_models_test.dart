import 'package:ceres_wallet_onchain/src/solana/models/solana_transaction.dart';
import 'package:ceres_wallet_onchain/src/solana/models/transaction_meta.dart';
import 'package:ceres_wallet_onchain/src/solana/models/solana_block.dart';
import 'package:ceres_wallet_onchain/src/solana/models/token_account.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionMeta', () {
    test('fromJson parses fee and balances as BigInt', () {
      final json = <String, dynamic>{
        'err': null,
        'fee': 5000,
        'preBalances': [10000000000, 20000000000],
        'postBalances': [9999995000, 20000005000],
        'preTokenBalances': [],
        'postTokenBalances': [],
        'logMessages': ['Program 11111111111111111111111111111111 invoke [1]'],
        'computeUnitsConsumed': 150,
        'innerInstructions': [],
      };

      final meta = TransactionMeta.fromJson(json);

      expect(meta.err, isNull);
      expect(meta.fee, equals(BigInt.from(5000)));
      expect(meta.preBalances.length, equals(2));
      expect(meta.preBalances[0], equals(BigInt.from(10000000000)));
      expect(meta.postBalances[1], equals(BigInt.from(20000005000)));
      expect(meta.logMessages, isNotNull);
      expect(meta.logMessages!.length, equals(1));
      expect(meta.computeUnitsConsumed, equals(BigInt.from(150)));
    });

    test('fromJson handles v0 loadedAddresses', () {
      final json = <String, dynamic>{
        'err': null,
        'fee': 5000,
        'preBalances': [100],
        'postBalances': [95],
        'loadedAddresses': {
          'writable': ['addr1'],
          'readonly': ['addr2'],
        },
      };

      final meta = TransactionMeta.fromJson(json);

      expect(meta.loadedAddresses, isNotNull);
    });

    test('fromJson handles error object', () {
      final json = <String, dynamic>{
        'err': {
          'InstructionError': [0, 'Custom'],
        },
        'fee': 5000,
        'preBalances': [100],
        'postBalances': [95],
      };

      final meta = TransactionMeta.fromJson(json);

      expect(meta.err, isNotNull);
    });
  });

  group('SolanaTransactionResponse', () {
    test('fromJson parses legacy transaction (version null)', () {
      final json = <String, dynamic>{
        'slot': 123456,
        'transaction': {
          'signatures': ['sig1'],
          'message': {
            'accountKeys': ['key1', 'key2'],
            'header': {
              'numRequiredSignatures': 1,
              'numReadonlySignedAccounts': 0,
              'numReadonlyUnsignedAccounts': 1,
            },
            'instructions': [],
            'recentBlockhash': 'blockhash123',
          },
        },
        'meta': {
          'err': null,
          'fee': 5000,
          'preBalances': [100],
          'postBalances': [95],
        },
        'blockTime': 1678886400,
      };

      final tx = SolanaTransactionResponse.fromJson(json);

      expect(tx.slot, equals(123456));
      expect(tx.transaction['signatures'], isNotNull);
      expect(tx.meta, isNotNull);
      expect(tx.meta!.fee, equals(BigInt.from(5000)));
      expect(tx.blockTime, equals(1678886400));
      expect(tx.version, isNull);
    });

    test('fromJson parses v0 versioned transaction', () {
      final json = <String, dynamic>{
        'slot': 789012,
        'transaction': {
          'signatures': ['sig_v0'],
          'message': {
            'accountKeys': ['key1'],
            'addressTableLookups': [
              {
                'accountKey': 'tableKey',
                'writableIndexes': [0],
                'readonlyIndexes': [1],
              },
            ],
          },
        },
        'meta': {
          'err': null,
          'fee': 5000,
          'preBalances': [100],
          'postBalances': [95],
          'loadedAddresses': {
            'writable': ['addr1'],
            'readonly': ['addr2'],
          },
        },
        'blockTime': 1678886400,
        'version': 0,
      };

      final tx = SolanaTransactionResponse.fromJson(json);

      expect(tx.version, equals(0));
      expect(tx.meta!.loadedAddresses, isNotNull);
    });

    test('fromJson parses version as "legacy" string', () {
      final json = <String, dynamic>{
        'slot': 100,
        'transaction': {
          'signatures': ['sig1'],
          'message': {'accountKeys': []},
        },
        'meta': {
          'err': null,
          'fee': 5000,
          'preBalances': [],
          'postBalances': [],
        },
        'version': 'legacy',
      };

      final tx = SolanaTransactionResponse.fromJson(json);

      expect(tx.version, isNull);
    });
  });

  group('SolanaBlock', () {
    test('fromJson parses block with transactions', () {
      final json = <String, dynamic>{
        'blockhash': 'blockhash123abc',
        'previousBlockhash': 'prevhash123abc',
        'parentSlot': 99999,
        'transactions': [
          {
            'transaction': {
              'signatures': ['sig1'],
              'message': {'accountKeys': []},
            },
            'meta': {
              'err': null,
              'fee': 5000,
              'preBalances': [100],
              'postBalances': [95],
            },
          },
        ],
        'blockTime': 1678886400,
        'blockHeight': 100000,
        'rewards': [
          {
            'pubkey': 'validatorKey',
            'lamports': 1000,
            'postBalance': 5000000,
            'rewardType': 'fee',
          },
        ],
      };

      final block = SolanaBlock.fromJson(json);

      expect(block.blockhash, equals('blockhash123abc'));
      expect(block.previousBlockhash, equals('prevhash123abc'));
      expect(block.parentSlot, equals(99999));
      expect(block.transactions, isNotNull);
      expect(block.transactions!.length, equals(1));
      expect(block.blockTime, equals(1678886400));
      expect(block.blockHeight, equals(100000));
      expect(block.rewards, isNotNull);
      expect(block.rewards!.length, equals(1));
    });

    test('fromJson parses block without transactions', () {
      final json = <String, dynamic>{
        'blockhash': 'blockhash456',
        'previousBlockhash': 'prevhash456',
        'parentSlot': 100000,
        'blockTime': null,
        'blockHeight': null,
      };

      final block = SolanaBlock.fromJson(json);

      expect(block.transactions, isNull);
      expect(block.blockTime, isNull);
      expect(block.blockHeight, isNull);
    });
  });

  group('TokenAccount', () {
    test('fromJson parses token account info', () {
      final json = <String, dynamic>{
        'pubkey': 'TokenAccountPubkey123',
        'account': {
          'lamports': 2039280,
          'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          'data': {
            'parsed': {
              'info': {
                'mint': 'MintAddress123',
                'owner': 'OwnerAddress123',
                'tokenAmount': {
                  'amount': '1000000',
                  'decimals': 6,
                  'uiAmount': 1.0,
                  'uiAmountString': '1',
                },
              },
              'type': 'account',
            },
            'program': 'spl-token',
            'space': 165,
          },
          'executable': false,
          'rentEpoch': 361,
        },
      };

      final tokenAccount = TokenAccount.fromJson(json);

      expect(tokenAccount.pubkey, equals('TokenAccountPubkey123'));
      expect(tokenAccount.account['lamports'], equals(2039280));
      expect(
        tokenAccount.account['owner'],
        equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
      );
      expect(tokenAccount.account['executable'], isFalse);
    });
  });
}
