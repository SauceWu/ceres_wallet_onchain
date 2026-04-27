import 'package:ceres_wallet_onchain/src/evm/models/eth_fee_history.dart';
import 'package:test/test.dart';

void main() {
  group('EthFeeHistory', () {
    test('fromJson parses baseFeePerGas with N+1 entries and gasUsedRatio', () {
      final json = <String, dynamic>{
        'oldestBlock': '0x10d4f',
        'baseFeePerGas': ['0x3b9aca00', '0x3b9aca01', '0x3b9aca02'],
        'gasUsedRatio': [0.5, 0.75],
      };

      final feeHistory = EthFeeHistory.fromJson(json);

      expect(feeHistory.oldestBlock, equals(BigInt.from(0x10d4f)));
      expect(feeHistory.baseFeePerGas.length, equals(3)); // N+1
      expect(feeHistory.baseFeePerGas[0], equals(BigInt.from(0x3b9aca00)));
      expect(feeHistory.gasUsedRatio.length, equals(2));
      expect(feeHistory.gasUsedRatio[0], equals(0.5));
      expect(feeHistory.reward, isNull);
    });

    test('fromJson parses optional reward percentiles', () {
      final json = <String, dynamic>{
        'oldestBlock': '0x10d4f',
        'baseFeePerGas': ['0x3b9aca00', '0x3b9aca01'],
        'gasUsedRatio': [0.5],
        'reward': [
          ['0x3b9aca00', '0x77359400'],
        ],
      };

      final feeHistory = EthFeeHistory.fromJson(json);

      expect(feeHistory.reward, isNotNull);
      expect(feeHistory.reward!.length, equals(1));
      expect(feeHistory.reward![0].length, equals(2));
      expect(feeHistory.reward![0][0], equals(BigInt.from(0x3b9aca00)));
    });

    test('fromJson parses EIP-4844 blob fields', () {
      final json = <String, dynamic>{
        'oldestBlock': '0x10d4f',
        'baseFeePerGas': ['0x3b9aca00', '0x3b9aca01'],
        'gasUsedRatio': [0.5],
        'baseFeePerBlobGas': ['0x1', '0x2'],
        'blobGasUsedRatio': [0.25],
      };

      final feeHistory = EthFeeHistory.fromJson(json);

      expect(feeHistory.baseFeePerBlobGas, isNotNull);
      expect(feeHistory.baseFeePerBlobGas!.length, equals(2));
      expect(feeHistory.baseFeePerBlobGas![0], equals(BigInt.one));
      expect(feeHistory.blobGasUsedRatio, isNotNull);
      expect(feeHistory.blobGasUsedRatio!.length, equals(1));
      expect(feeHistory.blobGasUsedRatio![0], equals(0.25));
    });
  });
}
