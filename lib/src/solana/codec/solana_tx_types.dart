// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

class MessageHeader {
  final int numRequiredSignatures;
  final int numReadonlySignedAccounts;
  final int numReadonlyUnsignedAccounts;

  const MessageHeader({
    required this.numRequiredSignatures,
    required this.numReadonlySignedAccounts,
    required this.numReadonlyUnsignedAccounts,
  });
}

class CompiledInstruction {
  final int programIdIndex;
  final List<int> accountKeyIndexes;
  final Uint8List data;

  const CompiledInstruction({
    required this.programIdIndex,
    required this.accountKeyIndexes,
    required this.data,
  });
}

class AddressTableLookup {
  final Uint8List accountKey;
  final List<int> writableIndexes;
  final List<int> readonlyIndexes;

  const AddressTableLookup({
    required this.accountKey,
    required this.writableIndexes,
    required this.readonlyIndexes,
  });
}

class SolanaTransaction {
  final List<Uint8List> signatures;
  final int? version;
  final MessageHeader header;
  final List<Uint8List> staticAccountKeys;
  final Uint8List recentBlockhash;
  final List<CompiledInstruction> instructions;
  final List<AddressTableLookup> addressTableLookups;

  const SolanaTransaction({
    required this.signatures,
    required this.version,
    required this.header,
    required this.staticAccountKeys,
    required this.recentBlockhash,
    required this.instructions,
    this.addressTableLookups = const [],
  });
}
