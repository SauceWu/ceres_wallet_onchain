// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'compact_u16.dart';
import 'solana_tx_types.dart';

class SolanaTxEncoder {
  const SolanaTxEncoder._();

  static Uint8List encode(SolanaTransaction tx) {
    final encoded = <int>[];
    encoded.addAll(compactU16Encode(tx.signatures.length));
    for (final signature in tx.signatures) {
      if (signature.length != 64) {
        throw ArgumentError('Solana signatures must be 64 bytes');
      }
      encoded.addAll(signature);
    }

    if (tx.version != null) {
      encoded.add(0x80 | tx.version!);
    }

    encoded.addAll([
      tx.header.numRequiredSignatures,
      tx.header.numReadonlySignedAccounts,
      tx.header.numReadonlyUnsignedAccounts,
    ]);

    encoded.addAll(compactU16Encode(tx.staticAccountKeys.length));
    for (final key in tx.staticAccountKeys) {
      if (key.length != 32) {
        throw ArgumentError('Solana account keys must be 32 bytes');
      }
      encoded.addAll(key);
    }

    if (tx.recentBlockhash.length != 32) {
      throw ArgumentError('Recent blockhash must be 32 bytes');
    }
    encoded.addAll(tx.recentBlockhash);

    encoded.addAll(compactU16Encode(tx.instructions.length));
    for (final instruction in tx.instructions) {
      encoded.add(instruction.programIdIndex);
      encoded.addAll(compactU16Encode(instruction.accountKeyIndexes.length));
      encoded.addAll(instruction.accountKeyIndexes);
      encoded.addAll(compactU16Encode(instruction.data.length));
      encoded.addAll(instruction.data);
    }

    if (tx.version != null) {
      encoded.addAll(compactU16Encode(tx.addressTableLookups.length));
      for (final lookup in tx.addressTableLookups) {
        if (lookup.accountKey.length != 32) {
          throw ArgumentError('Address table account keys must be 32 bytes');
        }
        encoded.addAll(lookup.accountKey);
        encoded.addAll(compactU16Encode(lookup.writableIndexes.length));
        encoded.addAll(lookup.writableIndexes);
        encoded.addAll(compactU16Encode(lookup.readonlyIndexes.length));
        encoded.addAll(lookup.readonlyIndexes);
      }
    }

    return Uint8List.fromList(encoded);
  }
}
