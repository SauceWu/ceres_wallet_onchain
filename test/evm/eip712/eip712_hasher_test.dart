import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('EIP712Hasher', () {
    test('computes official Mail typeHash', () {
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'Person': [
            {'name': 'name', 'type': 'string'},
            {'name': 'wallet', 'type': 'address'},
          ],
          'Mail': [
            {'name': 'from', 'type': 'Person'},
            {'name': 'to', 'type': 'Person'},
            {'name': 'contents', 'type': 'string'},
          ],
        },
        'primaryType': 'Mail',
        'domain': {
          'name': 'Ether Mail',
          'version': '1',
          'chainId': 1,
          'verifyingContract': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
        },
        'message': {
          'from': {
            'name': 'Cow',
            'wallet': '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
          },
          'to': {
            'name': 'Bob',
            'wallet': '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
          },
          'contents': 'Hello, Bob!',
        },
      });

      expect(
        _toHex(EIP712Hasher.typeHash('Mail', typedData)),
        'a0cedeb2dc280ba39b857546d74f5549c3a1d7bdc2dd96bf881f76108e23dac2',
      );
    });

    test('computes official Mail digest', () {
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'Person': [
            {'name': 'name', 'type': 'string'},
            {'name': 'wallet', 'type': 'address'},
          ],
          'Mail': [
            {'name': 'from', 'type': 'Person'},
            {'name': 'to', 'type': 'Person'},
            {'name': 'contents', 'type': 'string'},
          ],
        },
        'primaryType': 'Mail',
        'domain': {
          'name': 'Ether Mail',
          'version': '1',
          'chainId': 1,
          'verifyingContract': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
        },
        'message': {
          'from': {
            'name': 'Cow',
            'wallet': '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
          },
          'to': {
            'name': 'Bob',
            'wallet': '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
          },
          'contents': 'Hello, Bob!',
        },
      });

      expect(
        _toHex(EIP712Hasher.digest(typedData)),
        'be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2',
      );
    });

    test('treats absent optional fields as zero values', () {
      // Permit2-style payload with an optional field omitted
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
          ],
          'Transfer': [
            {'name': 'token', 'type': 'address'},
            {'name': 'amount', 'type': 'uint256'},
            {'name': 'memo', 'type': 'string'}, // optional — omitted below
          ],
        },
        'primaryType': 'Transfer',
        'domain': {'name': 'Permit2', 'chainId': 1},
        'message': {
          'token': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
          'amount': 1000,
          // 'memo' intentionally absent — should default to ''
        },
      });

      // Must not throw; result is deterministic (missing memo = empty string hash)
      final digest1 = EIP712Hasher.digest(typedData);

      // Explicitly passing empty string for memo must produce the same digest
      final typedDataExplicit = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
          ],
          'Transfer': [
            {'name': 'token', 'type': 'address'},
            {'name': 'amount', 'type': 'uint256'},
            {'name': 'memo', 'type': 'string'},
          ],
        },
        'primaryType': 'Transfer',
        'domain': {'name': 'Permit2', 'chainId': 1},
        'message': {
          'token': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
          'amount': 1000,
          'memo': '',
        },
      });

      final digest2 = EIP712Hasher.digest(typedDataExplicit);
      expect(digest1, equals(digest2));
    });

    test('sorts nested type dependencies alphabetically', () {
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': <Map<String, String>>[],
          'Mail': [
            {'name': 'from', 'type': 'Person'},
            {'name': 'attachment', 'type': 'Attachment'},
          ],
          'Person': [
            {'name': 'name', 'type': 'string'},
          ],
          'Attachment': [
            {'name': 'contents', 'type': 'bytes'},
          ],
        },
        'primaryType': 'Mail',
        'domain': {},
        'message': {
          'from': {'name': 'Cow'},
          'attachment': {'contents': Uint8List(0)},
        },
      });

      expect(
        EIP712Hasher.encodeType('Mail', typedData),
        'Mail(Person from,Attachment attachment)'
        'Attachment(bytes contents)'
        'Person(string name)',
      );
    });
  });
}
