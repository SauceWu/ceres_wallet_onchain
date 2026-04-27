import 'package:ceres_wallet_onchain/src/evm/models/eth_transaction.dart';
import 'package:test/test.dart';

void main() {
  group('EthTransaction', () {
    test('fromJson parses Type 0 legacy transaction', () {
      final json = <String, dynamic>{
        'blockHash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'gasPrice': '0x9184e72a000',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x',
        'nonce': '0x15',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'transactionIndex': '0x1',
        'value': '0xf4240',
        'type': '0x0',
        'v': '0x25',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(
        tx.blockHash,
        '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
      );
      expect(tx.blockNumber, equals(BigInt.from(0x10d4f)));
      expect(
        tx.from.toString(),
        contains('a7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270'),
      );
      expect(tx.gas, equals(BigInt.from(0x76c0)));
      expect(tx.gasPrice, equals(BigInt.parse('9184e72a000', radix: 16)));
      expect(tx.nonce, equals(BigInt.from(0x15)));
      expect(tx.to, isNotNull);
      expect(tx.value, equals(BigInt.from(0xf4240)));
      expect(tx.type, equals(0));
      expect(tx.accessList, isNull);
      expect(tx.maxFeePerGas, isNull);
      expect(tx.maxPriorityFeePerGas, isNull);
      expect(tx.blobVersionedHashes, isNull);
      expect(tx.maxFeePerBlobGas, isNull);
    });

    test('fromJson parses Type 1 EIP-2930 transaction', () {
      final json = <String, dynamic>{
        'blockHash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'gasPrice': '0x9184e72a000',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x',
        'nonce': '0x15',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'transactionIndex': '0x1',
        'value': '0xf4240',
        'type': '0x1',
        'chainId': '0x1',
        'accessList': [
          {
            'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            'storageKeys': [
              '0x0000000000000000000000000000000000000000000000000000000000000001',
            ],
          },
        ],
        'v': '0x0',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(tx.type, equals(1));
      expect(tx.chainId, equals(BigInt.one));
      expect(tx.accessList, isNotNull);
      expect(tx.accessList!.length, equals(1));
      expect(tx.gasPrice, equals(BigInt.parse('9184e72a000', radix: 16)));
      expect(tx.maxFeePerGas, isNull);
    });

    test('fromJson parses Type 2 EIP-1559 transaction', () {
      final json = <String, dynamic>{
        'blockHash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'gasPrice': '0x9184e72a000',
        'maxFeePerGas': '0x12a05f200',
        'maxPriorityFeePerGas': '0x3b9aca00',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x',
        'nonce': '0x15',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'transactionIndex': '0x1',
        'value': '0xf4240',
        'type': '0x2',
        'chainId': '0x1',
        'accessList': [],
        'v': '0x0',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(tx.type, equals(2));
      expect(tx.maxFeePerGas, equals(BigInt.parse('12a05f200', radix: 16)));
      expect(tx.maxPriorityFeePerGas, equals(BigInt.from(0x3b9aca00)));
      expect(tx.chainId, equals(BigInt.one));
      expect(tx.accessList, isNotNull);
      expect(tx.accessList!.isEmpty, isTrue);
    });

    test('fromJson parses Type 3 EIP-4844 blob transaction', () {
      final json = <String, dynamic>{
        'blockHash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'maxFeePerGas': '0x12a05f200',
        'maxPriorityFeePerGas': '0x3b9aca00',
        'maxFeePerBlobGas': '0x3b9aca00',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x',
        'nonce': '0x15',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'transactionIndex': '0x1',
        'value': '0xf4240',
        'type': '0x3',
        'chainId': '0x1',
        'accessList': [],
        'blobVersionedHashes': [
          '0x01a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9',
          '0x01b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9',
        ],
        'v': '0x0',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(tx.type, equals(3));
      expect(tx.maxFeePerBlobGas, equals(BigInt.from(0x3b9aca00)));
      expect(tx.blobVersionedHashes, isNotNull);
      expect(tx.blobVersionedHashes!.length, equals(2));
    });

    test('fromJson handles contract creation (null to)', () {
      final json = <String, dynamic>{
        'blockHash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'gasPrice': '0x9184e72a000',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x6060604052341561000f57600080fd5b',
        'nonce': '0x15',
        'to': null,
        'transactionIndex': '0x1',
        'value': '0x0',
        'type': '0x0',
        'v': '0x25',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(tx.to, isNull);
      expect(tx.from, isNotNull);
    });

    test('fromJson handles pending transaction (null block fields)', () {
      final json = <String, dynamic>{
        'blockHash': null,
        'blockNumber': null,
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'gas': '0x76c0',
        'gasPrice': '0x9184e72a000',
        'hash':
            '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
        'input': '0x',
        'nonce': '0x15',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'transactionIndex': null,
        'value': '0xf4240',
        'type': '0x0',
        'v': '0x25',
        'r':
            '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
        's':
            '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
      };

      final tx = EthTransaction.fromJson(json);

      expect(tx.blockHash, isNull);
      expect(tx.blockNumber, isNull);
      expect(tx.transactionIndex, isNull);
      expect(tx.from, isNotNull);
    });
  });
}
