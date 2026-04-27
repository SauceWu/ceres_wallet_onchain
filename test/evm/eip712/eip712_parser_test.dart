import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:test/test.dart';

void main() {
  group('EIP712Parser', () {
    test('parses Permit payload', () {
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'Permit': [
            {'name': 'owner', 'type': 'address'},
            {'name': 'spender', 'type': 'address'},
            {'name': 'value', 'type': 'uint256'},
            {'name': 'nonce', 'type': 'uint256'},
            {'name': 'deadline', 'type': 'uint256'},
          ],
        },
        'primaryType': 'Permit',
        'domain': {
          'name': 'Uniswap V2',
          'version': '1',
          'chainId': 1,
          'verifyingContract': '0x0000000000000000000000000000000000000001',
        },
        'message': {
          'owner': '0x0000000000000000000000000000000000000002',
          'spender': '0x0000000000000000000000000000000000000003',
          'value': '100',
          'nonce': '1',
          'deadline': '2',
        },
      });

      expect(typedData.primaryType, 'Permit');
      expect(typedData.types.keys, containsAll(['EIP712Domain', 'Permit']));
      expect(typedData.types['Permit'], hasLength(5));
      expect(typedData.domain['name'], 'Uniswap V2');
      expect(
        typedData.message['owner'],
        '0x0000000000000000000000000000000000000002',
      );
    });

    test('parses nested Permit2 payload', () {
      final typedData = EIP712Parser.parse({
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'TokenPermissions': [
            {'name': 'token', 'type': 'address'},
            {'name': 'amount', 'type': 'uint256'},
          ],
          'PermitTransferFrom': [
            {'name': 'permitted', 'type': 'TokenPermissions'},
            {'name': 'nonce', 'type': 'uint256'},
            {'name': 'deadline', 'type': 'uint256'},
          ],
        },
        'primaryType': 'PermitTransferFrom',
        'domain': {
          'name': 'Permit2',
          'chainId': 1,
          'verifyingContract': '0x0000000000000000000000000000000000000004',
        },
        'message': {
          'permitted': {
            'token': '0x0000000000000000000000000000000000000005',
            'amount': '42',
          },
          'nonce': '7',
          'deadline': '8',
        },
      });

      expect(typedData.types.keys, containsAll(['TokenPermissions']));
      expect(
        typedData.types['PermitTransferFrom']!.first.type,
        'TokenPermissions',
      );
    });

    test('throws when EIP712Domain is missing', () {
      expect(
        () => EIP712Parser.parse({
          'types': {
            'Permit': [
              {'name': 'owner', 'type': 'address'},
            ],
          },
          'primaryType': 'Permit',
          'domain': {},
          'message': {'owner': '0x0'},
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('EIP712Domain'),
          ),
        ),
      );
    });

    test('throws when primaryType is missing', () {
      expect(
        () => EIP712Parser.parse({
          'types': {'EIP712Domain': <Map<String, String>>[]},
          'domain': {},
          'message': {},
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('primaryType'),
          ),
        ),
      );
    });
  });
}
