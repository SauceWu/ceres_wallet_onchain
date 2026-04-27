import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';
import '../models/eth_access_list_result.dart';
import '../models/eth_fee_history.dart';

/// Gas and fee estimation EVM RPC methods.
///
/// Provides methods for querying current gas prices, estimating gas
/// consumption, and generating access lists.
///
/// All gas values are returned as [BigInt] to safely represent uint256.
mixin EvmGasMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the current gas price in wei.
  ///
  /// Calls `eth_gasPrice`. Useful for legacy (non-EIP-1559) transactions.
  ///
  /// ```dart
  /// final price = await client.gasPrice();
  /// ```
  Future<BigInt> gasPrice() async {
    final result = await transport.send('eth_gasPrice');
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the current max priority fee per gas in wei (EIP-1559).
  ///
  /// Calls `eth_maxPriorityFeePerGas`. Use together with base fee from
  /// [feeHistory] to calculate `maxFeePerGas`.
  ///
  /// ```dart
  /// final tip = await client.maxPriorityFeePerGas();
  /// ```
  Future<BigInt> maxPriorityFeePerGas() async {
    final result = await transport.send('eth_maxPriorityFeePerGas');
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns historical fee data for a range of blocks.
  ///
  /// Calls `eth_feeHistory` with [blockCount] blocks ending at
  /// [newestBlock] (a block tag or hex number). [rewardPercentiles]
  /// specifies which effective priority fee percentiles to include.
  ///
  /// ```dart
  /// final history = await client.feeHistory(10, 'latest', [25, 50, 75]);
  /// ```
  Future<EthFeeHistory> feeHistory(
    int blockCount,
    String newestBlock,
    List<double> rewardPercentiles,
  ) async {
    final result = await transport.send('eth_feeHistory', [
      '0x${blockCount.toRadixString(16)}',
      newestBlock,
      rewardPercentiles,
    ]);
    return EthFeeHistory.fromJson(result as Map<String, dynamic>);
  }

  /// Estimates the gas needed to execute a transaction.
  ///
  /// Calls `eth_estimateGas` with [callObject] (a map with keys like
  /// `from`, `to`, `data`, `value`, `gas`). An optional [blockTag]
  /// specifies the block state to use.
  ///
  /// ```dart
  /// final gas = await client.estimateGas({'to': '0x...', 'data': '0x...'});
  /// ```
  Future<BigInt> estimateGas(
    Map<String, dynamic> callObject, {
    String? blockTag,
  }) async {
    final params = <dynamic>[callObject];
    if (blockTag != null) params.add(blockTag);
    final result = await transport.send('eth_estimateGas', params);
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Generates an access list for the given transaction.
  ///
  /// Calls `eth_createAccessList`. Returns an [EthAccessListResult] with
  /// the optimized access list and estimated gas with that list applied.
  ///
  /// ```dart
  /// final result = await client.createAccessList({'to': '0x...', 'data': '0x...'});
  /// print(result.gasUsed);
  /// ```
  Future<EthAccessListResult> createAccessList(
    Map<String, dynamic> txObject, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_createAccessList', [
      txObject,
      blockTag,
    ]);
    return EthAccessListResult.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the base fee per blob gas in wei (EIP-4844).
  ///
  /// Calls `eth_blobBaseFee`. Only available on Dencun-enabled networks.
  ///
  /// ```dart
  /// final blobFee = await client.blobBaseFee();
  /// ```
  Future<BigInt> blobBaseFee() async {
    final result = await transport.send('eth_blobBaseFee');
    return BigIntUtils.hexToBigInt(result as String);
  }
}
