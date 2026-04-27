// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import '../solana_address.dart';
import 'solana_tx_types.dart';

const String computeBudgetProgramId =
    'ComputeBudget111111111111111111111111111111';

abstract class ComputeBudgetIx {
  const ComputeBudgetIx();
}

class ComputeBudgetRequestUnits extends ComputeBudgetIx {
  final int units;
  final int additionalFee;

  const ComputeBudgetRequestUnits({
    required this.units,
    required this.additionalFee,
  });
}

class ComputeBudgetRequestHeapFrame extends ComputeBudgetIx {
  final int bytes;

  const ComputeBudgetRequestHeapFrame({required this.bytes});
}

class ComputeBudgetSetComputeUnitLimit extends ComputeBudgetIx {
  final int units;

  const ComputeBudgetSetComputeUnitLimit({required this.units});
}

class ComputeBudgetSetComputeUnitPrice extends ComputeBudgetIx {
  final BigInt microLamports;

  const ComputeBudgetSetComputeUnitPrice({required this.microLamports});
}

class ComputeBudgetDecoder {
  const ComputeBudgetDecoder._();

  static bool isComputeBudget(
    CompiledInstruction instruction,
    List<Uint8List> accountKeys,
  ) {
    if (instruction.programIdIndex >= accountKeys.length) {
      return false;
    }
    final expected = SolanaAddress(computeBudgetProgramId).toBytes();
    final actual = accountKeys[instruction.programIdIndex];
    if (actual.length != expected.length) {
      return false;
    }
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        return false;
      }
    }
    return true;
  }

  static ComputeBudgetIx decode(CompiledInstruction instruction) {
    final data = instruction.data;
    if (data.isEmpty) {
      throw ArgumentError('Empty ComputeBudget instruction data');
    }
    switch (data[0]) {
      case 0:
        _expectLength(data, 9, 'RequestUnits');
        return ComputeBudgetRequestUnits(
          units: _readU32(data, 1),
          additionalFee: _readU32(data, 5),
        );
      case 1:
        _expectLength(data, 5, 'RequestHeapFrame');
        return ComputeBudgetRequestHeapFrame(bytes: _readU32(data, 1));
      case 2:
        _expectLength(data, 5, 'SetComputeUnitLimit');
        return ComputeBudgetSetComputeUnitLimit(units: _readU32(data, 1));
      case 3:
        _expectLength(data, 9, 'SetComputeUnitPrice');
        return ComputeBudgetSetComputeUnitPrice(
          microLamports: _readU64(data, 1),
        );
      default:
        throw ArgumentError(
          'Unknown ComputeBudget discriminator: ${data.first}',
        );
    }
  }

  static void _expectLength(Uint8List data, int minLength, String label) {
    if (data.length < minLength) {
      throw ArgumentError('$label instruction too short');
    }
  }

  static int _readU32(Uint8List data, int start) {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value |= data[start + i] << (8 * i);
    }
    return value;
  }

  static BigInt _readU64(Uint8List data, int start) {
    var value = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      value |= BigInt.from(data[start + i]) << (8 * i);
    }
    return value;
  }
}
