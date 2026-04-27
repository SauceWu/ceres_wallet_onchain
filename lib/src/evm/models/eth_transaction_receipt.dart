import '../evm_address.dart';
import '../../utils/bigint_utils.dart';
import 'eth_log.dart';

/// An Ethereum transaction receipt returned by `eth_getTransactionReceipt`.
///
/// Contains the execution result of a transaction including gas usage,
/// emitted [logs], and the execution [status].
///
/// For contract creation transactions, [contractAddress] contains the
/// deployed contract address and [to] is `null`.
///
/// EIP-4844 blob transactions include [blobGasUsed] and [blobGasPrice].
///
/// ```dart
/// final receipt = EthTransactionReceipt.fromJson(jsonMap);
/// print(receipt.status);   // 1 (success) or 0 (failure)
/// print(receipt.gasUsed);  // gas consumed by this transaction
/// ```
class EthTransactionReceipt {
  /// Hash of the transaction.
  final String transactionHash;

  /// Index of the transaction within the block.
  final BigInt transactionIndex;

  /// Hash of the block containing this transaction.
  final String blockHash;

  /// Number of the block containing this transaction.
  final BigInt blockNumber;

  /// Address of the sender.
  final EvmAddress from;

  /// Address of the receiver, or `null` for contract creation transactions.
  final EvmAddress? to;

  /// Total gas used in the block up to and including this transaction.
  final BigInt cumulativeGasUsed;

  /// Actual gas price paid per unit of gas.
  final BigInt effectiveGasPrice;

  /// Gas consumed by this specific transaction.
  final BigInt gasUsed;

  /// Address of the created contract, or `null` for non-creation transactions.
  final EvmAddress? contractAddress;

  /// Event logs emitted during transaction execution.
  final List<EthLog> logs;

  /// Bloom filter for light clients to quickly retrieve related logs.
  final String logsBloom;

  /// Transaction type: 0 (legacy), 1 (EIP-2930), 2 (EIP-1559), 3 (EIP-4844).
  final int type;

  /// Execution status: `1` for success, `0` for failure.
  final BigInt status;

  /// Blob gas consumed by this transaction (EIP-4844), or `null`.
  final BigInt? blobGasUsed;

  /// Blob gas price for this transaction (EIP-4844), or `null`.
  final BigInt? blobGasPrice;

  /// Creates an [EthTransactionReceipt] with all fields.
  const EthTransactionReceipt({
    required this.transactionHash,
    required this.transactionIndex,
    required this.blockHash,
    required this.blockNumber,
    required this.from,
    required this.to,
    required this.cumulativeGasUsed,
    required this.effectiveGasPrice,
    required this.gasUsed,
    required this.contractAddress,
    required this.logs,
    required this.logsBloom,
    required this.type,
    required this.status,
    this.blobGasUsed,
    this.blobGasPrice,
  });

  /// Parses an [EthTransactionReceipt] from a JSON-RPC response map.
  ///
  /// All hex quantity fields are converted to [BigInt]. The [logs] list
  /// is parsed into typed [EthLog] objects.
  factory EthTransactionReceipt.fromJson(Map<String, dynamic> json) {
    return EthTransactionReceipt(
      transactionHash: json['transactionHash'] as String,
      transactionIndex: BigIntUtils.hexToBigInt(
        json['transactionIndex'] as String,
      ),
      blockHash: json['blockHash'] as String,
      blockNumber: BigIntUtils.hexToBigInt(json['blockNumber'] as String),
      from: EvmAddress(json['from'] as String),
      to: _addressOrNull(json['to']),
      cumulativeGasUsed: BigIntUtils.hexToBigInt(
        json['cumulativeGasUsed'] as String,
      ),
      effectiveGasPrice: BigIntUtils.hexToBigInt(
        json['effectiveGasPrice'] as String,
      ),
      gasUsed: BigIntUtils.hexToBigInt(json['gasUsed'] as String),
      contractAddress: _addressOrNull(json['contractAddress']),
      logs: (json['logs'] as List)
          .map((e) => EthLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      logsBloom: json['logsBloom'] as String,
      type: _hexToInt(json['type'] as String),
      status: BigIntUtils.hexToBigInt(json['status'] as String),
      blobGasUsed: _hexOrNull(json['blobGasUsed']),
      blobGasPrice: _hexOrNull(json['blobGasPrice']),
    );
  }

  static BigInt? _hexOrNull(dynamic value) {
    if (value == null) return null;
    return BigIntUtils.hexToBigInt(value as String);
  }

  static EvmAddress? _addressOrNull(dynamic value) {
    if (value == null) return null;
    return EvmAddress(value as String);
  }

  static int _hexToInt(String hex) {
    return BigIntUtils.hexToBigInt(hex).toInt();
  }
}
