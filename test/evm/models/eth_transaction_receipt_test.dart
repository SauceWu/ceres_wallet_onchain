import 'package:ceres_wallet_onchain/src/evm/models/eth_transaction_receipt.dart';
import 'package:test/test.dart';

void main() {
  group('EthTransactionReceipt', () {
    test('fromJson parses all standard fields including logs', () {
      final json = <String, dynamic>{
        'transactionHash':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'transactionIndex': '0x1',
        'blockHash':
            '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'cumulativeGasUsed': '0x33bc',
        'effectiveGasPrice': '0x9184e72a000',
        'gasUsed': '0x4dc',
        'contractAddress': null,
        'logs': [
          {
            'logIndex': '0x0',
            'transactionIndex': '0x1',
            'transactionHash':
                '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            'blockHash':
                '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
            'blockNumber': '0x10d4f',
            'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            'data':
                '0x000000000000000000000000000000000000000000000000000000003b9aca00',
            'topics': [
              '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
            ],
            'removed': false,
          },
        ],
        'logsBloom': '0x00000000000000000000000000000000',
        'type': '0x2',
        'status': '0x1',
      };

      final receipt = EthTransactionReceipt.fromJson(json);

      expect(
        receipt.transactionHash,
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
      expect(receipt.transactionIndex, equals(BigInt.one));
      expect(receipt.blockNumber, equals(BigInt.from(0x10d4f)));
      expect(
        receipt.from.toString(),
        contains('a7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270'),
      );
      expect(receipt.to, isNotNull);
      expect(receipt.cumulativeGasUsed, equals(BigInt.from(0x33bc)));
      expect(
        receipt.effectiveGasPrice,
        equals(BigInt.parse('9184e72a000', radix: 16)),
      );
      expect(receipt.gasUsed, equals(BigInt.from(0x4dc)));
      expect(receipt.contractAddress, isNull);
      expect(receipt.logs.length, equals(1));
      expect(receipt.type, equals(2));
      expect(receipt.status, equals(BigInt.one));
      expect(receipt.blobGasUsed, isNull);
      expect(receipt.blobGasPrice, isNull);
    });

    test('fromJson parses receipt with contract creation', () {
      final json = <String, dynamic>{
        'transactionHash':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'transactionIndex': '0x0',
        'blockHash':
            '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'to': null,
        'cumulativeGasUsed': '0x33bc',
        'effectiveGasPrice': '0x9184e72a000',
        'gasUsed': '0x4dc',
        'contractAddress': '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        'logs': [],
        'logsBloom': '0x00000000000000000000000000000000',
        'type': '0x0',
        'status': '0x1',
      };

      final receipt = EthTransactionReceipt.fromJson(json);

      expect(receipt.to, isNull);
      expect(receipt.contractAddress, isNotNull);
      expect(
        receipt.contractAddress.toString(),
        contains('6B175474E89094C44Da98b954EedeAC495271d0F'),
      );
      expect(receipt.logs.isEmpty, isTrue);
    });

    test('fromJson parses EIP-4844 blob fields', () {
      final json = <String, dynamic>{
        'transactionHash':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'transactionIndex': '0x0',
        'blockHash':
            '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        'blockNumber': '0x10d4f',
        'from': '0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270',
        'to': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'cumulativeGasUsed': '0x33bc',
        'effectiveGasPrice': '0x9184e72a000',
        'gasUsed': '0x4dc',
        'contractAddress': null,
        'logs': [],
        'logsBloom': '0x00000000000000000000000000000000',
        'type': '0x3',
        'status': '0x1',
        'blobGasUsed': '0x20000',
        'blobGasPrice': '0x1',
      };

      final receipt = EthTransactionReceipt.fromJson(json);

      expect(receipt.blobGasUsed, equals(BigInt.from(0x20000)));
      expect(receipt.blobGasPrice, equals(BigInt.one));
      expect(receipt.type, equals(3));
    });
  });
}
