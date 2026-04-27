import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

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
  group('SolanaTxEncoder', () {
    test('legacy round trips', () {
      final raw = _legacyFixture();
      final tx = SolanaTxDecoder.decode(raw);
      expect(SolanaTxEncoder.encode(tx), raw);
    });

    test('v0 round trips', () {
      final raw = _v0Fixture();
      final tx = SolanaTxDecoder.decode(raw);
      expect(SolanaTxEncoder.encode(tx), raw);
    });
  });
}
