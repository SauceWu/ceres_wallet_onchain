import '../../utils/bigint_utils.dart';

/// Fee history data returned by `eth_feeHistory`.
///
/// Contains historical base fee and gas usage data for a range of blocks,
/// useful for gas price estimation.
///
/// [baseFeePerGas] always has N+1 entries (one extra for the next block's
/// predicted base fee), where N is the number of requested blocks.
///
/// EIP-4844 fields [baseFeePerBlobGas] and [blobGasUsedRatio] are present
/// on Dencun-enabled networks.
///
/// ```dart
/// final history = EthFeeHistory.fromJson(jsonMap);
/// print(history.baseFeePerGas.length); // N+1 entries
/// print(history.gasUsedRatio);         // N entries
/// ```
class EthFeeHistory {
  /// The oldest block number in the returned range.
  final BigInt oldestBlock;

  /// Base fee per gas for each block in the range, plus the next block.
  /// Always has N+1 entries.
  final List<BigInt> baseFeePerGas;

  /// Ratio of gas used to gas limit for each block in the range.
  final List<double> gasUsedRatio;

  /// Effective priority fees at the requested percentiles for each block.
  /// Outer list has N entries, inner list has one entry per percentile.
  /// `null` if no reward percentiles were requested.
  final List<List<BigInt>>? reward;

  /// Base fee per blob gas for each block (EIP-4844), or `null`.
  final List<BigInt>? baseFeePerBlobGas;

  /// Ratio of blob gas used to blob gas limit for each block (EIP-4844), or `null`.
  final List<double>? blobGasUsedRatio;

  /// Creates an [EthFeeHistory] with all fields.
  const EthFeeHistory({
    required this.oldestBlock,
    required this.baseFeePerGas,
    required this.gasUsedRatio,
    this.reward,
    this.baseFeePerBlobGas,
    this.blobGasUsedRatio,
  });

  /// Parses an [EthFeeHistory] from a JSON-RPC response map.
  factory EthFeeHistory.fromJson(Map<String, dynamic> json) {
    return EthFeeHistory(
      oldestBlock: BigIntUtils.hexToBigInt(json['oldestBlock'] as String),
      baseFeePerGas: (json['baseFeePerGas'] as List)
          .map((e) => BigIntUtils.hexToBigInt(e as String))
          .toList(),
      gasUsedRatio: (json['gasUsedRatio'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      reward: _parseReward(json['reward']),
      baseFeePerBlobGas: _parseHexList(json['baseFeePerBlobGas']),
      blobGasUsedRatio: _parseDoubleList(json['blobGasUsedRatio']),
    );
  }

  static List<List<BigInt>>? _parseReward(dynamic value) {
    if (value == null) return null;
    return (value as List).map((blockRewards) {
      return (blockRewards as List)
          .map((e) => BigIntUtils.hexToBigInt(e as String))
          .toList();
    }).toList();
  }

  static List<BigInt>? _parseHexList(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => BigIntUtils.hexToBigInt(e as String))
        .toList();
  }

  static List<double>? _parseDoubleList(dynamic value) {
    if (value == null) return null;
    return (value as List).map((e) => (e as num).toDouble()).toList();
  }
}
