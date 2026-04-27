import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

Uint8List _repeat(int value, int count) =>
    Uint8List.fromList(List<int>.filled(count, value));

Uint8List _legacyFixture() {
  return Uint8List.fromList([
    ...compactU16Encode(1),
    ...List<int>.filled(64, 0),
    1,
    0,
    1,
    ...compactU16Encode(1),
    ...List<int>.filled(32, 0),
    ...List<int>.filled(32, 0),
    ...compactU16Encode(1),
    0,
    ...compactU16Encode(0),
    ...compactU16Encode(0),
  ]);
}

Uint8List _v0Fixture() {
  return Uint8List.fromList([
    ...compactU16Encode(1),
    ...List<int>.filled(64, 1),
    0x80,
    1,
    0,
    1,
    ...compactU16Encode(1),
    ...List<int>.filled(32, 2),
    ...List<int>.filled(32, 3),
    ...compactU16Encode(1),
    0,
    ...compactU16Encode(1),
    0,
    ...compactU16Encode(2),
    0xaa,
    0xbb,
    ...compactU16Encode(1),
    ...List<int>.filled(32, 4),
    ...compactU16Encode(1),
    0,
    ...compactU16Encode(1),
    1,
  ]);
}

void main() {
  group('compact_u16', () {
    test('encodes boundaries', () {
      expect(compactU16Encode(0), [0x00]);
      expect(compactU16Encode(127), [0x7f]);
      expect(compactU16Encode(128), [0x80, 0x01]);
      expect(compactU16Encode(255), [0xff, 0x01]);
      expect(compactU16Encode(300), [0xac, 0x02]);
    });

    test('decodes boundaries', () {
      expect(compactU16Decode(Uint8List.fromList([0x80, 0x01]), 0), (128, 2));
      expect(compactU16Decode(Uint8List.fromList([0x7f]), 0), (127, 1));
    });

    test('round trips 0..300', () {
      for (var value = 0; value <= 300; value++) {
        final encoded = Uint8List.fromList(compactU16Encode(value));
        final (decoded, consumed) = compactU16Decode(encoded, 0);
        expect(decoded, value);
        expect(consumed, encoded.length);
      }
    });
  });

  group('SolanaTxDecoder', () {
    test('decodes a minimal legacy transaction', () {
      final tx = SolanaTxDecoder.decode(_legacyFixture());

      expect(tx.version, isNull);
      expect(tx.signatures, hasLength(1));
      expect(tx.staticAccountKeys, hasLength(1));
      expect(tx.instructions, hasLength(1));
      expect(tx.addressTableLookups, isEmpty);
    });

    test('decodes a minimal v0 transaction', () {
      final tx = SolanaTxDecoder.decode(_v0Fixture());

      expect(tx.version, 0);
      expect(tx.addressTableLookups, hasLength(1));
      expect(tx.addressTableLookups.first.writableIndexes, [0]);
      expect(tx.addressTableLookups.first.readonlyIndexes, [1]);
    });

    test('throws on truncated payload', () {
      expect(
        () => SolanaTxDecoder.decode(_repeat(0, 10)),
        throwsA(anyOf(isA<RangeError>(), isA<ArgumentError>())),
      );
    });
  });
}
