// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import '../models/account_info.dart';
import '../solana_address.dart';
import 'solana_tx_types.dart';

const int _altMetaSize = 56;

class AltResolver {
  const AltResolver._();

  static Future<List<Uint8List>> resolve(
    SolanaTransaction tx,
    Future<AccountInfo?> Function(String pubkey) getAccountInfo,
  ) async {
    final resolved = List<Uint8List>.from(tx.staticAccountKeys);
    if (tx.addressTableLookups.isEmpty) {
      return resolved;
    }

    final pubkeys = tx.addressTableLookups
        .map((lookup) => SolanaAddress.fromBytes(lookup.accountKey).toBase58())
        .toList(growable: false);

    final accountInfos = await Future.wait(
      pubkeys.map((pubkey) => getAccountInfo(pubkey)),
    );

    for (var i = 0; i < tx.addressTableLookups.length; i++) {
      final accountInfo = accountInfos[i];
      if (accountInfo == null) {
        throw ArgumentError('ALT account not found: ${pubkeys[i]}');
      }

      final altData = accountInfo.data;
      if (altData.isEmpty) {
        throw ArgumentError(
          'ALT account has empty data: ${pubkeys[i]}',
        );
      }
      final encoding = altData.length >= 2 ? altData[1] : 'base64';
      if (encoding != 'base64') {
        throw ArgumentError(
          'Unsupported ALT encoding "$encoding" for ${pubkeys[i]} (expected base64)',
        );
      }
      final addresses = decodeAltAddresses(
        Uint8List.fromList(base64.decode(altData[0])),
      );
      final lookup = tx.addressTableLookups[i];
      for (final index in lookup.writableIndexes) {
        resolved.add(addresses[index]);
      }
      for (final index in lookup.readonlyIndexes) {
        resolved.add(addresses[index]);
      }
    }

    return resolved;
  }

  static List<Uint8List> decodeAltAddresses(Uint8List accountData) {
    if (accountData.length < _altMetaSize) {
      throw ArgumentError('Invalid ALT data length: ${accountData.length}');
    }
    final addressBytes = accountData.sublist(_altMetaSize);
    if (addressBytes.length % 32 != 0) {
      throw ArgumentError('ALT address bytes are not 32-byte aligned');
    }
    return [
      for (var i = 0; i < addressBytes.length; i += 32)
        Uint8List.fromList(addressBytes.sublist(i, i + 32)),
    ];
  }
}
