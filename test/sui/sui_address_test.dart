import 'dart:typed_data';

import 'package:ceres_wallet_onchain/src/sui/sui_address.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_options.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_paginated.dart';
import 'package:test/test.dart';

void main() {
  group('SuiAddress', () {
    test('normalizes short address 0x2 to 64 hex chars', () {
      final addr = SuiAddress('0x2');
      expect(
        addr.toHex(),
        '0x0000000000000000000000000000000000000000000000000000000000000002',
      );
    });

    test('full-length address remains unchanged', () {
      const full =
          '0x0000000000000000000000000000000000000000000000000000000000000002';
      final addr = SuiAddress(full);
      expect(addr.toHex(), full);
    });

    test('address without 0x prefix normalizes correctly', () {
      final addr = SuiAddress('abc');
      expect(
        addr.toHex(),
        '0x0000000000000000000000000000000000000000000000000000000000000abc',
      );
    });

    test('fromBytes with 32 bytes succeeds', () {
      final bytes = Uint8List(32);
      bytes[31] = 0x02;
      final addr = SuiAddress.fromBytes(bytes);
      expect(
        addr.toHex(),
        '0x0000000000000000000000000000000000000000000000000000000000000002',
      );
    });

    test('fromBytes with non-32 bytes throws ArgumentError', () {
      expect(() => SuiAddress.fromBytes(Uint8List(20)), throwsArgumentError);
    });

    test('empty string throws ArgumentError', () {
      expect(() => SuiAddress(''), throwsArgumentError);
    });

    test('invalid hex throws ArgumentError', () {
      expect(() => SuiAddress('xyz_invalid'), throwsArgumentError);
    });

    test('equality and hashCode for same address', () {
      final a = SuiAddress('0x2');
      final b = SuiAddress(
        '0x0000000000000000000000000000000000000000000000000000000000000002',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toBytes returns 32-byte copy', () {
      final addr = SuiAddress('0x2');
      final bytes = addr.toBytes();
      expect(bytes.length, 32);
      expect(bytes[31], 2);
      // Verify it's a copy
      bytes[31] = 0;
      expect(addr.toBytes()[31], 2);
    });

    test('toString delegates to toHex', () {
      final addr = SuiAddress('0x2');
      expect(addr.toString(), addr.toHex());
    });
  });

  group('SuiObjectDataOptions', () {
    test('toJson only includes non-null fields', () {
      const opts = SuiObjectDataOptions(showContent: true);
      expect(opts.toJson(), {'showContent': true});
    });

    test('all sets every field to true', () {
      final json = SuiObjectDataOptions.all.toJson();
      expect(json['showBcs'], true);
      expect(json['showContent'], true);
      expect(json['showDisplay'], true);
      expect(json['showOwner'], true);
      expect(json['showPreviousTransaction'], true);
      expect(json['showStorageRebate'], true);
      expect(json['showType'], true);
      expect(json.length, 7);
    });
  });

  group('SuiTransactionBlockResponseOptions', () {
    test('toJson includes only specified fields', () {
      const opts = SuiTransactionBlockResponseOptions(
        showEffects: true,
        showEvents: true,
      );
      final json = opts.toJson();
      expect(json, {'showEffects': true, 'showEvents': true});
    });

    test('all sets every field to true', () {
      final json = SuiTransactionBlockResponseOptions.all.toJson();
      expect(json['showInput'], true);
      expect(json['showEffects'], true);
      expect(json['showEvents'], true);
      expect(json['showObjectChanges'], true);
      expect(json['showBalanceChanges'], true);
      expect(json['showRawInput'], true);
      expect(json['showRawEffects'], true);
      expect(json.length, 7);
    });
  });

  group('SuiPaginatedResponse', () {
    test('fromJson parses items and pagination', () {
      final json = {
        'data': ['a', 'b', 'c'],
        'hasNextPage': true,
        'nextCursor': 'cursor123',
      };
      final result = SuiPaginatedResponse.fromJson(
        json,
        (item) => item as String,
      );
      expect(result.data, ['a', 'b', 'c']);
      expect(result.hasNextPage, true);
      expect(result.nextCursor, 'cursor123');
    });

    test('fromJson handles no nextCursor', () {
      final json = {
        'data': [1, 2],
        'hasNextPage': false,
      };
      final result = SuiPaginatedResponse.fromJson(json, (item) => item as int);
      expect(result.data, [1, 2]);
      expect(result.hasNextPage, false);
      expect(result.nextCursor, isNull);
    });
  });
}
