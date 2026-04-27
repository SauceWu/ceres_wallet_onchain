// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/crypto/quick_crypto.dart';

/// EIP-191 personal_sign pre-hash helper.
class EIP191Hasher {
  const EIP191Hasher._();

  static Uint8List digest(String message) {
    final messageBytes = utf8.encode(message);
    final prefix = utf8.encode(
      '\u0019Ethereum Signed Message:\n${messageBytes.length}',
    );
    return Uint8List.fromList(
      QuickCrypto.keccack256Hash([...prefix, ...messageBytes]),
    );
  }
}
