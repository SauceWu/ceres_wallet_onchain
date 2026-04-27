import 'dart:convert';
import 'dart:typed_data';

import 'package:ceres_wallet_onchain/src/solana/models/account_info.dart';
import 'package:ceres_wallet_onchain/src/solana/models/blockhash_result.dart';
import 'package:ceres_wallet_onchain/src/solana/models/prioritization_fee.dart';
import 'package:ceres_wallet_onchain/src/solana/models/signature_info.dart';
import 'package:ceres_wallet_onchain/src/solana/models/signature_status.dart';
import 'package:ceres_wallet_onchain/src/solana/models/simulate_result.dart';
import 'package:ceres_wallet_onchain/src/solana/models/spl_token_account_data.dart';
import 'package:ceres_wallet_onchain/src/solana/models/token_amount.dart';
import 'package:test/test.dart';

void main() {
  group('AccountInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'lamports': 1000000000,
        'owner': '11111111111111111111111111111111',
        'executable': false,
        'rentEpoch': 361,
        'data': ['', 'base64'],
        'space': 0,
      };
      final info = AccountInfo.fromJson(json);
      expect(info.lamports, equals(BigInt.from(1000000000)));
      expect(info.owner, equals('11111111111111111111111111111111'));
      expect(info.executable, isFalse);
      expect(info.rentEpoch, equals(BigInt.from(361)));
      expect(info.data, equals(['', 'base64']));
      expect(info.space, equals(0));
    });

    test('lamports is BigInt type', () {
      final json = {
        'lamports': 9999999999999,
        'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
        'executable': true,
        'rentEpoch': 9007199254740992, // large but representable
        'data': ['AQID', 'base64'],
      };
      final info = AccountInfo.fromJson(json);
      expect(info.lamports, isA<BigInt>());
      expect(info.lamports, equals(BigInt.from(9999999999999)));
      expect(info.executable, isTrue);
    });

    test('space is optional', () {
      final json = {
        'lamports': 0,
        'owner': '11111111111111111111111111111111',
        'executable': false,
        'rentEpoch': 0,
        'data': ['', 'base64'],
      };
      final info = AccountInfo.fromJson(json);
      expect(info.space, isNull);
    });
  });

  group('TokenAmount', () {
    test('fromJson parses all fields', () {
      final json = {
        'amount': '1000000',
        'decimals': 6,
        'uiAmountString': '1.0',
      };
      final ta = TokenAmount.fromJson(json);
      expect(ta.amount, equals('1000000'));
      expect(ta.decimals, equals(6));
      expect(ta.uiAmountString, equals('1.0'));
    });

    test('uiAmountString is optional', () {
      final json = {'amount': '0', 'decimals': 9};
      final ta = TokenAmount.fromJson(json);
      expect(ta.uiAmountString, isNull);
    });
  });

  group('SplTokenAccountData', () {
    test('fromBase64 parses mint, owner, amount', () {
      // Build a 165-byte SPL token account layout:
      // [0-31]  mint (32 bytes)
      // [32-63] owner (32 bytes)
      // [64-71] amount (u64 LE)
      // [72-164] remaining fields (don't matter for this test)
      final data = Uint8List(165);
      // mint: all 1s for first byte
      data[0] = 0x06;
      data[1] = 0xDD;
      // owner: byte 32 set
      data[32] = 0xAB;
      // amount: 1000000 = 0xF4240 in LE => [0x40, 0x42, 0x0F, 0, 0, 0, 0, 0]
      data[64] = 0x40;
      data[65] = 0x42;
      data[66] = 0x0F;

      final b64 = base64Encode(data);
      final parsed = SplTokenAccountData.fromBase64(b64);

      expect(parsed.mint.toBytes()[0], equals(0x06));
      expect(parsed.mint.toBytes()[1], equals(0xDD));
      expect(parsed.owner.toBytes()[0], equals(0xAB));
      expect(parsed.amount, equals(BigInt.from(1000000)));
    });

    test('fromBase64 handles u64 max value', () {
      final data = Uint8List(165);
      // u64 max = 0xFFFFFFFFFFFFFFFF in LE => [0xFF]*8
      for (var i = 64; i < 72; i++) {
        data[i] = 0xFF;
      }
      final b64 = base64Encode(data);
      final parsed = SplTokenAccountData.fromBase64(b64);
      expect(parsed.amount, equals(BigInt.parse('18446744073709551615')));
    });

    test('fromBase64 throws FormatException for insufficient data', () {
      // Only 71 bytes - needs at least 72
      final data = Uint8List(71);
      final b64 = base64Encode(data);
      expect(() => SplTokenAccountData.fromBase64(b64), throwsFormatException);
    });

    test('fromBytes parses correctly', () {
      final data = Uint8List(72);
      data[64] = 0x01; // amount = 1
      final parsed = SplTokenAccountData.fromBytes(data);
      expect(parsed.amount, equals(BigInt.one));
    });
  });

  group('BlockhashResult', () {
    test('fromJson parses blockhash and lastValidBlockHeight', () {
      final json = {
        'blockhash': '7GFhSLrb4wwZCiAjhFsmqHBpqkfZQvchCGXfMRXEzjRR',
        'lastValidBlockHeight': 150,
      };
      final result = BlockhashResult.fromJson(json);
      expect(
        result.blockhash,
        equals('7GFhSLrb4wwZCiAjhFsmqHBpqkfZQvchCGXfMRXEzjRR'),
      );
      expect(result.lastValidBlockHeight, equals(150));
    });
  });

  group('SignatureStatus', () {
    test('fromJson parses all fields', () {
      final json = {
        'slot': 72,
        'confirmations': 10,
        'err': null,
        'confirmationStatus': 'confirmed',
      };
      final status = SignatureStatus.fromJson(json);
      expect(status.slot, equals(72));
      expect(status.confirmations, equals(10));
      expect(status.err, isNull);
      expect(status.confirmationStatus, equals('confirmed'));
    });

    test('confirmations can be null (finalized)', () {
      final json = {
        'slot': 100,
        'confirmations': null,
        'err': null,
        'confirmationStatus': 'finalized',
      };
      final status = SignatureStatus.fromJson(json);
      expect(status.confirmations, isNull);
    });

    test('err can contain error object', () {
      final json = {
        'slot': 50,
        'confirmations': null,
        'err': {
          'InstructionError': [0, 'Custom'],
        },
        'confirmationStatus': 'confirmed',
      };
      final status = SignatureStatus.fromJson(json);
      expect(status.err, isNotNull);
    });
  });

  group('SignatureInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'signature':
            '5VERv8NMhJa7QxBM7Xb2hYpKvzgFMxrGenGor1p1HH9QVejT6qJSPzR2HfAqY4w4Yg4YZL4bVtUkrW',
        'slot': 100,
        'err': null,
        'memo': 'some memo',
        'blockTime': 1625140800,
        'confirmationStatus': 'finalized',
      };
      final info = SignatureInfo.fromJson(json);
      expect(info.signature, startsWith('5VERv8N'));
      expect(info.slot, equals(100));
      expect(info.err, isNull);
      expect(info.memo, equals('some memo'));
      expect(info.blockTime, equals(1625140800));
      expect(info.confirmationStatus, equals('finalized'));
    });

    test('optional fields can be null', () {
      final json = {
        'signature': 'abc123',
        'slot': 50,
        'err': null,
        'memo': null,
        'blockTime': null,
        'confirmationStatus': null,
      };
      final info = SignatureInfo.fromJson(json);
      expect(info.memo, isNull);
      expect(info.blockTime, isNull);
      expect(info.confirmationStatus, isNull);
    });
  });

  group('SimulateResult', () {
    test('fromJson parses all fields', () {
      final json = {
        'err': null,
        'logs': ['Program log: Hello', 'Program consumed 123 units'],
        'unitsConsumed': 123456,
        'returnData': {
          'programId': '11111111111111111111111111111111',
          'data': ['AQID', 'base64'],
        },
      };
      final result = SimulateResult.fromJson(json);
      expect(result.err, isNull);
      expect(result.logs, hasLength(2));
      expect(result.unitsConsumed, equals(BigInt.from(123456)));
      expect(result.returnData, isNotNull);
    });

    test('logs and unitsConsumed can be null', () {
      final json = {
        'err': {
          'InstructionError': [0, 'Custom'],
        },
      };
      final result = SimulateResult.fromJson(json);
      expect(result.err, isNotNull);
      expect(result.logs, isNull);
      expect(result.unitsConsumed, isNull);
      expect(result.returnData, isNull);
    });
  });

  group('PrioritizationFee', () {
    test('fromJson parses slot and prioritizationFee', () {
      final json = {'slot': 348125, 'prioritizationFee': 5000};
      final fee = PrioritizationFee.fromJson(json);
      expect(fee.slot, equals(348125));
      expect(fee.prioritizationFee, equals(BigInt.from(5000)));
    });

    test('prioritizationFee zero', () {
      final json = {'slot': 100, 'prioritizationFee': 0};
      final fee = PrioritizationFee.fromJson(json);
      expect(fee.prioritizationFee, equals(BigInt.zero));
    });
  });
}
