import 'package:ceres_wallet_onchain/src/evm/models/eth_block.dart';
import 'package:test/test.dart';

void main() {
  group('EthBlock', () {
    test('fromJson parses block with hash-only transactions', () {
      final json = <String, dynamic>{
        'number': '0x10d4f',
        'hash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'parentHash':
            '0xa903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568237',
        'nonce': '0x0000000000000000',
        'sha3Uncles':
            '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
        'logsBloom': '0x00000000000000000000000000000000',
        'transactionsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'stateRoot':
            '0xd5855eb08b3387c0af375e9cdb6acfc05eb8f519e419b874b6ff2382a5f3f55e',
        'receiptsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'miner': '0x0000000000000000000000000000000000000000',
        'difficulty': '0x0',
        'totalDifficulty': '0xc70d815d562d3cfa955',
        'extraData': '0x',
        'size': '0x220',
        'gasLimit': '0x1c9c380',
        'gasUsed': '0x0',
        'timestamp': '0x64a0b800',
        'transactions': [
          '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
          '0xf670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527332',
        ],
        'uncles': [],
        'baseFeePerGas': '0x3b9aca00',
        'mixHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
      };

      final block = EthBlock.fromJson(json);

      expect(block.number, equals(BigInt.from(0x10d4f)));
      expect(
        block.hash,
        '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
      );
      expect(block.gasLimit, equals(BigInt.from(0x1c9c380)));
      expect(block.gasUsed, equals(BigInt.zero));
      expect(block.timestamp, equals(BigInt.from(0x64a0b800)));
      expect(block.baseFeePerGas, equals(BigInt.from(0x3b9aca00)));
      expect(block.transactionHashes, isNotNull);
      expect(block.transactionHashes!.length, equals(2));
      expect(block.transactions, isNull);
      expect(block.withdrawals, isNull);
    });

    test('fromJson parses block with full transaction objects', () {
      final json = <String, dynamic>{
        'number': '0x10d4f',
        'hash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'parentHash':
            '0xa903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568237',
        'nonce': '0x0000000000000000',
        'sha3Uncles':
            '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
        'logsBloom': '0x00000000000000000000000000000000',
        'transactionsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'stateRoot':
            '0xd5855eb08b3387c0af375e9cdb6acfc05eb8f519e419b874b6ff2382a5f3f55e',
        'receiptsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'miner': '0x0000000000000000000000000000000000000000',
        'difficulty': '0x0',
        'totalDifficulty': '0xc70d815d562d3cfa955',
        'extraData': '0x',
        'size': '0x220',
        'gasLimit': '0x1c9c380',
        'gasUsed': '0x76c0',
        'timestamp': '0x64a0b800',
        'transactions': [
          {
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
            'transactionIndex': '0x0',
            'value': '0xf4240',
            'type': '0x0',
            'v': '0x25',
            'r':
                '0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea',
            's':
                '0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c',
          },
        ],
        'uncles': [],
        'baseFeePerGas': '0x3b9aca00',
        'mixHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
      };

      final block = EthBlock.fromJson(json);

      expect(block.transactionHashes, isNull);
      expect(block.transactions, isNotNull);
      expect(block.transactions!.length, equals(1));
      expect(
        block.transactions!.first.hash,
        '0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331',
      );
    });

    test('fromJson parses EIP-4844 block with withdrawals and blob fields', () {
      final json = <String, dynamic>{
        'number': '0x10d4f',
        'hash':
            '0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238',
        'parentHash':
            '0xa903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568237',
        'nonce': '0x0000000000000000',
        'sha3Uncles':
            '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
        'logsBloom': '0x00000000000000000000000000000000',
        'transactionsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'stateRoot':
            '0xd5855eb08b3387c0af375e9cdb6acfc05eb8f519e419b874b6ff2382a5f3f55e',
        'receiptsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'miner': '0x0000000000000000000000000000000000000000',
        'difficulty': '0x0',
        'totalDifficulty': '0xc70d815d562d3cfa955',
        'extraData': '0x',
        'size': '0x220',
        'gasLimit': '0x1c9c380',
        'gasUsed': '0x76c0',
        'timestamp': '0x64a0b800',
        'transactions': [],
        'uncles': [],
        'baseFeePerGas': '0x3b9aca00',
        'mixHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        'withdrawals': [
          {
            'index': '0x0',
            'validatorIndex': '0x2a',
            'address': '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
            'amount': '0xe8d4a51000',
          },
        ],
        'withdrawalsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'blobGasUsed': '0x20000',
        'excessBlobGas': '0x0',
        'parentBeaconBlockRoot':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
      };

      final block = EthBlock.fromJson(json);

      expect(block.withdrawals, isNotNull);
      expect(block.withdrawals!.length, equals(1));
      expect(block.withdrawals!.first.validatorIndex, equals(BigInt.from(42)));
      expect(block.withdrawalsRoot, isNotNull);
      expect(block.blobGasUsed, equals(BigInt.from(0x20000)));
      expect(block.excessBlobGas, equals(BigInt.zero));
      expect(block.parentBeaconBlockRoot, isNotNull);
    });

    test('fromJson handles pending block (null number, hash, nonce)', () {
      final json = <String, dynamic>{
        'number': null,
        'hash': null,
        'parentHash':
            '0xa903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568237',
        'nonce': null,
        'sha3Uncles':
            '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
        'logsBloom': '0x00000000000000000000000000000000',
        'transactionsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'stateRoot':
            '0xd5855eb08b3387c0af375e9cdb6acfc05eb8f519e419b874b6ff2382a5f3f55e',
        'receiptsRoot':
            '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
        'miner': '0x0000000000000000000000000000000000000000',
        'difficulty': '0x0',
        'totalDifficulty': '0xc70d815d562d3cfa955',
        'extraData': '0x',
        'size': '0x220',
        'gasLimit': '0x1c9c380',
        'gasUsed': '0x0',
        'timestamp': '0x64a0b800',
        'transactions': [],
        'uncles': [],
        'mixHash':
            '0x0000000000000000000000000000000000000000000000000000000000000000',
      };

      final block = EthBlock.fromJson(json);

      expect(block.number, isNull);
      expect(block.hash, isNull);
      expect(block.nonce, isNull);
      expect(block.baseFeePerGas, isNull);
      expect(block.parentHash, isNotNull);
    });
  });
}
