import 'dart:convert';
import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

Uint8List _bytes32(int seed) => Uint8List.fromList(
  List<int>.generate(32, (index) => (seed + index) & 0xff),
);

AccountInfo _makeAltAccountInfo(List<Uint8List> addresses) {
  final bytes = Uint8List(56 + addresses.length * 32);
  for (var i = 0; i < addresses.length; i++) {
    bytes.setRange(56 + i * 32, 56 + (i + 1) * 32, addresses[i]);
  }
  return AccountInfo(
    lamports: BigInt.zero,
    owner: '11111111111111111111111111111111',
    executable: false,
    rentEpoch: BigInt.zero,
    data: [base64.encode(bytes), 'base64'],
  );
}

void main() {
  group('AltResolver', () {
    test('returns static accounts for legacy transactions', () async {
      final staticKey = _bytes32(1);
      final tx = SolanaTransaction(
        signatures: const [],
        version: null,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [staticKey],
        recentBlockhash: _bytes32(2),
        instructions: const [],
      );

      final resolved = await AltResolver.resolve(tx, (_) async => null);
      expect(resolved, hasLength(1));
      expect(resolved.first, staticKey);
    });

    test('expands one ALT into writable then readonly accounts', () async {
      final altKey = _bytes32(9);
      final addresses = [_bytes32(10), _bytes32(11), _bytes32(12)];
      final tx = SolanaTransaction(
        signatures: const [],
        version: 0,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [_bytes32(1)],
        recentBlockhash: _bytes32(2),
        instructions: const [],
        addressTableLookups: [
          AddressTableLookup(
            accountKey: altKey,
            writableIndexes: const [0, 1],
            readonlyIndexes: const [2],
          ),
        ],
      );

      final resolved = await AltResolver.resolve(
        tx,
        (_) async => _makeAltAccountInfo(addresses),
      );

      expect(resolved, hasLength(4));
      expect(resolved[1], addresses[0]);
      expect(resolved[2], addresses[1]);
      expect(resolved[3], addresses[2]);
    });

    test('resolves multiple ALTs concurrently', () async {
      final firstAltKey = _bytes32(20);
      final secondAltKey = _bytes32(30);
      var calls = 0;
      final responses = <String, AccountInfo>{
        SolanaAddress.fromBytes(firstAltKey).toBase58(): _makeAltAccountInfo([
          _bytes32(21),
          _bytes32(22),
        ]),
        SolanaAddress.fromBytes(secondAltKey).toBase58(): _makeAltAccountInfo([
          _bytes32(31),
          _bytes32(32),
        ]),
      };
      final tx = SolanaTransaction(
        signatures: const [],
        version: 0,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [_bytes32(1)],
        recentBlockhash: _bytes32(2),
        instructions: const [],
        addressTableLookups: [
          AddressTableLookup(
            accountKey: firstAltKey,
            writableIndexes: const [0],
            readonlyIndexes: const [1],
          ),
          AddressTableLookup(
            accountKey: secondAltKey,
            writableIndexes: const [0],
            readonlyIndexes: const [1],
          ),
        ],
      );

      final resolved = await AltResolver.resolve(tx, (pubkey) async {
        calls++;
        return responses[pubkey];
      });

      expect(calls, 2);
      expect(resolved, hasLength(5));
    });

    test('throws ArgumentError when ALT account data list is empty', () async {
      final altKey = _bytes32(40);
      final emptyDataInfo = AccountInfo(
        lamports: BigInt.zero,
        owner: '11111111111111111111111111111111',
        executable: false,
        rentEpoch: BigInt.zero,
        data: [],
      );
      final tx = SolanaTransaction(
        signatures: const [],
        version: 0,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [_bytes32(1)],
        recentBlockhash: _bytes32(2),
        instructions: const [],
        addressTableLookups: [
          AddressTableLookup(
            accountKey: altKey,
            writableIndexes: const [0],
            readonlyIndexes: const [],
          ),
        ],
      );

      await expectLater(
        () => AltResolver.resolve(tx, (_) async => emptyDataInfo),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for non-base64 ALT encoding', () async {
      final altKey = _bytes32(50);
      final wrongEncodingInfo = AccountInfo(
        lamports: BigInt.zero,
        owner: '11111111111111111111111111111111',
        executable: false,
        rentEpoch: BigInt.zero,
        data: ['somedata', 'base58'],
      );
      final tx = SolanaTransaction(
        signatures: const [],
        version: 0,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [_bytes32(1)],
        recentBlockhash: _bytes32(2),
        instructions: const [],
        addressTableLookups: [
          AddressTableLookup(
            accountKey: altKey,
            writableIndexes: const [0],
            readonlyIndexes: const [],
          ),
        ],
      );

      await expectLater(
        () => AltResolver.resolve(tx, (_) async => wrongEncodingInfo),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when an ALT account is missing', () async {
      final tx = SolanaTransaction(
        signatures: const [],
        version: 0,
        header: const MessageHeader(
          numRequiredSignatures: 1,
          numReadonlySignedAccounts: 0,
          numReadonlyUnsignedAccounts: 0,
        ),
        staticAccountKeys: [_bytes32(1)],
        recentBlockhash: _bytes32(2),
        instructions: const [],
        addressTableLookups: [
          AddressTableLookup(
            accountKey: _bytes32(3),
            writableIndexes: const [0],
            readonlyIndexes: const [],
          ),
        ],
      );

      await expectLater(
        () => AltResolver.resolve(tx, (_) async => null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
