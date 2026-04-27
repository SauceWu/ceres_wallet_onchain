import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

CompiledInstruction _instruction(List<int> data, {int programIdIndex = 0}) {
  return CompiledInstruction(
    programIdIndex: programIdIndex,
    accountKeyIndexes: const [],
    data: Uint8List.fromList(data),
  );
}

void main() {
  group('ComputeBudgetDecoder', () {
    test('decodes RequestUnits', () {
      final decoded =
          ComputeBudgetDecoder.decode(
                _instruction([
                  0x00,
                  0xe8,
                  0x03,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                ]),
              )
              as ComputeBudgetRequestUnits;

      expect(decoded.units, 1000);
      expect(decoded.additionalFee, 0);
    });

    test('decodes RequestHeapFrame', () {
      final decoded =
          ComputeBudgetDecoder.decode(
                _instruction([0x01, 0x00, 0x40, 0x00, 0x00]),
              )
              as ComputeBudgetRequestHeapFrame;

      expect(decoded.bytes, 16384);
    });

    test('decodes SetComputeUnitLimit', () {
      final decoded =
          ComputeBudgetDecoder.decode(
                _instruction([0x02, 0x40, 0x42, 0x0f, 0x00]),
              )
              as ComputeBudgetSetComputeUnitLimit;

      expect(decoded.units, 1000000);
    });

    test('decodes SetComputeUnitPrice', () {
      final decoded =
          ComputeBudgetDecoder.decode(
                _instruction([
                  0x03,
                  0xe8,
                  0x03,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                ]),
              )
              as ComputeBudgetSetComputeUnitPrice;

      expect(decoded.microLamports, BigInt.from(1000));
    });

    test('throws on unknown discriminator', () {
      expect(
        () => ComputeBudgetDecoder.decode(_instruction([0xff, 0x00])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('recognizes ComputeBudget program id', () {
      final accountKeys = [SolanaAddress(computeBudgetProgramId).toBytes()];

      expect(
        ComputeBudgetDecoder.isComputeBudget(
          _instruction([0x02], programIdIndex: 0),
          accountKeys,
        ),
        isTrue,
      );
    });

    test('rejects non-ComputeBudget program ids', () {
      final accountKeys = [Uint8List.fromList(List<int>.filled(32, 7))];

      expect(
        ComputeBudgetDecoder.isComputeBudget(
          _instruction([0x02], programIdIndex: 0),
          accountKeys,
        ),
        isFalse,
      );
    });
  });
}
