import 'package:test/test.dart';
import 'package:ceres_wallet_onchain/src/abi/function_selector.dart';

void main() {
  group('FunctionSelector.compute', () {
    test('balanceOf(address) returns correct selector', () {
      expect(
        FunctionSelector.compute('balanceOf(address)'),
        equals([0x70, 0xa0, 0x82, 0x31]),
      );
    });

    test('transfer(address,uint256) returns correct selector', () {
      expect(
        FunctionSelector.compute('transfer(address,uint256)'),
        equals([0xa9, 0x05, 0x9c, 0xbb]),
      );
    });

    test('approve(address,uint256) returns correct selector', () {
      expect(
        FunctionSelector.compute('approve(address,uint256)'),
        equals([0x09, 0x5e, 0xa7, 0xb3]),
      );
    });

    test('transferFrom(address,address,uint256) returns correct selector', () {
      expect(
        FunctionSelector.compute('transferFrom(address,address,uint256)'),
        equals([0x23, 0xb8, 0x72, 0xdd]),
      );
    });
  });

  group('FunctionSelector normalization', () {
    test('removes single spaces in signature', () {
      expect(
        FunctionSelector.compute('transfer(address, uint256)'),
        equals(FunctionSelector.compute('transfer(address,uint256)')),
      );
    });

    test('removes multiple spaces in signature', () {
      expect(
        FunctionSelector.compute('transfer( address , uint256 )'),
        equals(FunctionSelector.compute('transfer(address,uint256)')),
      );
    });
  });

  group('FunctionSelector constants consistency', () {
    final constantMap = <String, List<int>>{
      'balanceOf(address)': FunctionSelector.balanceOf,
      'name()': FunctionSelector.name,
      'symbol()': FunctionSelector.symbol,
      'decimals()': FunctionSelector.decimals,
      'totalSupply()': FunctionSelector.totalSupply,
      'transfer(address,uint256)': FunctionSelector.transfer,
      'approve(address,uint256)': FunctionSelector.approve,
      'transferFrom(address,address,uint256)': FunctionSelector.transferFrom,
      'allowance(address,address)': FunctionSelector.allowance,
      'aggregate3((address,bool,bytes)[])': FunctionSelector.aggregate3,
    };

    for (final entry in constantMap.entries) {
      test('${entry.key} constant matches compute()', () {
        expect(FunctionSelector.compute(entry.key), equals(entry.value));
      });
    }
  });

  group('FunctionSelector.computeHex', () {
    test('balanceOf(address) returns hex string', () {
      expect(
        FunctionSelector.computeHex('balanceOf(address)'),
        equals('70a08231'),
      );
    });

    test('transfer(address,uint256) returns hex string', () {
      expect(
        FunctionSelector.computeHex('transfer(address,uint256)'),
        equals('a9059cbb'),
      );
    });
  });
}
