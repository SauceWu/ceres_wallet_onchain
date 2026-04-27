import '../evm_address.dart';
import '../../utils/bigint_utils.dart';

/// An Ethereum event log emitted by a smart contract.
///
/// Logs are produced by the `LOG0`..`LOG4` EVM opcodes and are included in
/// transaction receipts. Each log contains the emitting contract [address],
/// up to 4 indexed [topics], and an unindexed [data] payload.
///
/// Pending logs (not yet included in a block) may have `null` for
/// [logIndex], [transactionIndex], [transactionHash], [blockHash],
/// and [blockNumber].
///
/// ```dart
/// final log = EthLog.fromJson(jsonMap);
/// print(log.address); // 0xdAC17F958D2ee523a2206206994597C13D831ec7
/// print(log.topics);  // [0xddf252ad..., ...]
/// ```
class EthLog {
  /// Position of this log within the block, or `null` for pending logs.
  final BigInt? logIndex;

  /// Index of the transaction that produced this log, or `null` for pending.
  final BigInt? transactionIndex;

  /// Hash of the transaction that produced this log, or `null` for pending.
  final String? transactionHash;

  /// Hash of the block containing this log, or `null` for pending.
  final String? blockHash;

  /// Number of the block containing this log, or `null` for pending.
  final BigInt? blockNumber;

  /// Address of the contract that emitted this log.
  final EvmAddress address;

  /// ABI-encoded non-indexed event parameters (hex string).
  final String data;

  /// Indexed event parameters (topic0 is the event signature hash).
  final List<String> topics;

  /// Whether this log was removed due to a chain reorganization.
  final bool removed;

  /// Creates an [EthLog] with all fields.
  const EthLog({
    required this.logIndex,
    required this.transactionIndex,
    required this.transactionHash,
    required this.blockHash,
    required this.blockNumber,
    required this.address,
    required this.data,
    required this.topics,
    required this.removed,
  });

  /// Parses an [EthLog] from a JSON-RPC response map.
  ///
  /// Hex quantity fields ([logIndex], [transactionIndex], [blockNumber])
  /// are converted to [BigInt]. Nullable fields handle pending logs where
  /// the values may be `null`.
  factory EthLog.fromJson(Map<String, dynamic> json) {
    return EthLog(
      logIndex: _hexOrNull(json['logIndex']),
      transactionIndex: _hexOrNull(json['transactionIndex']),
      transactionHash: json['transactionHash'] as String?,
      blockHash: json['blockHash'] as String?,
      blockNumber: _hexOrNull(json['blockNumber']),
      address: EvmAddress(json['address'] as String),
      data: json['data'] as String,
      topics: (json['topics'] as List).cast<String>(),
      removed: json['removed'] as bool,
    );
  }

  static BigInt? _hexOrNull(dynamic value) {
    if (value == null) return null;
    return BigIntUtils.hexToBigInt(value as String);
  }
}
