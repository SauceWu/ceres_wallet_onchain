// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'compact_u16.dart';
import 'solana_tx_types.dart';

class SolanaTxDecoder {
  const SolanaTxDecoder._();

  static SolanaTransaction decode(Uint8List bytes) {
    var offset = 0;
    final (signatureCount, signatureLength) = compactU16Decode(bytes, offset);
    offset += signatureLength;

    final signatures = <Uint8List>[];
    for (var i = 0; i < signatureCount; i++) {
      signatures.add(_readFixed(bytes, offset, 64));
      offset += 64;
    }

    int? version;
    var messagePrefix = _readByte(bytes, offset);
    if ((messagePrefix & 0x80) != 0) {
      version = messagePrefix & 0x7f;
      offset += 1;
      messagePrefix = _readByte(bytes, offset);
    }

    final header = MessageHeader(
      numRequiredSignatures: messagePrefix,
      numReadonlySignedAccounts: _readByte(bytes, offset + 1),
      numReadonlyUnsignedAccounts: _readByte(bytes, offset + 2),
    );
    offset += 3;

    final (accountCount, accountLen) = compactU16Decode(bytes, offset);
    offset += accountLen;
    final staticAccountKeys = <Uint8List>[];
    for (var i = 0; i < accountCount; i++) {
      staticAccountKeys.add(_readFixed(bytes, offset, 32));
      offset += 32;
    }

    final recentBlockhash = _readFixed(bytes, offset, 32);
    offset += 32;

    final (instructionCount, instructionLen) = compactU16Decode(bytes, offset);
    offset += instructionLen;
    final instructions = <CompiledInstruction>[];
    for (var i = 0; i < instructionCount; i++) {
      final programIdIndex = _readByte(bytes, offset);
      offset += 1;

      final (accountIndexCount, accountIndexLen) = compactU16Decode(
        bytes,
        offset,
      );
      offset += accountIndexLen;
      final accountKeyIndexes = bytes
          .sublist(offset, offset + accountIndexCount)
          .toList(growable: false);
      offset += accountIndexCount;

      final (dataLength, dataLenBytes) = compactU16Decode(bytes, offset);
      offset += dataLenBytes;
      final data = _readFixed(bytes, offset, dataLength);
      offset += dataLength;

      instructions.add(
        CompiledInstruction(
          programIdIndex: programIdIndex,
          accountKeyIndexes: accountKeyIndexes,
          data: data,
        ),
      );
    }

    final addressTableLookups = <AddressTableLookup>[];
    if (version != null) {
      final (lookupCount, lookupLen) = compactU16Decode(bytes, offset);
      offset += lookupLen;
      for (var i = 0; i < lookupCount; i++) {
        final accountKey = _readFixed(bytes, offset, 32);
        offset += 32;

        final (writableCount, writableLen) = compactU16Decode(bytes, offset);
        offset += writableLen;
        final writableIndexes = bytes
            .sublist(offset, offset + writableCount)
            .toList(growable: false);
        offset += writableCount;

        final (readonlyCount, readonlyLen) = compactU16Decode(bytes, offset);
        offset += readonlyLen;
        final readonlyIndexes = bytes
            .sublist(offset, offset + readonlyCount)
            .toList(growable: false);
        offset += readonlyCount;

        addressTableLookups.add(
          AddressTableLookup(
            accountKey: accountKey,
            writableIndexes: writableIndexes,
            readonlyIndexes: readonlyIndexes,
          ),
        );
      }
    }

    if (offset != bytes.length) {
      throw ArgumentError('Unexpected trailing bytes in Solana transaction');
    }

    return SolanaTransaction(
      signatures: signatures,
      version: version,
      header: header,
      staticAccountKeys: staticAccountKeys,
      recentBlockhash: recentBlockhash,
      instructions: instructions,
      addressTableLookups: addressTableLookups,
    );
  }

  static int _readByte(Uint8List bytes, int offset) {
    if (offset >= bytes.length) {
      throw RangeError('Unexpected end of Solana transaction at byte $offset');
    }
    return bytes[offset];
  }

  static Uint8List _readFixed(Uint8List bytes, int offset, int length) {
    if (offset + length > bytes.length) {
      throw RangeError(
        'Unexpected end of Solana transaction at byte ${offset + length}',
      );
    }
    return Uint8List.fromList(bytes.sublist(offset, offset + length));
  }
}
