import '../evm_address.dart';
import '../../utils/bigint_utils.dart';
import 'eth_transaction.dart';
import 'eth_withdrawal.dart';

/// An Ethereum block object returned by `eth_getBlockBy*` methods.
///
/// Supports all post-merge block fields including:
/// - **EIP-1559** (London): [baseFeePerGas]
/// - **EIP-4895** (Shanghai): [withdrawals], [withdrawalsRoot]
/// - **EIP-4844** (Dencun): [blobGasUsed], [excessBlobGas], [parentBeaconBlockRoot]
///
/// Transactions are returned in one of two modes depending on the
/// `fullTransactions` parameter of the RPC call:
/// - **Hash mode:** [transactionHashes] contains transaction hash strings,
///   [transactions] is `null`.
/// - **Full mode:** [transactions] contains full [EthTransaction] objects,
///   [transactionHashes] is `null`.
///
/// Pending blocks have `null` for [number], [hash], and [nonce].
///
/// ```dart
/// final block = EthBlock.fromJson(jsonMap);
/// if (block.transactions != null) {
///   // full transaction objects
/// } else {
///   // hash strings only
/// }
/// ```
class EthBlock {
  /// Block number, or `null` for pending blocks.
  final BigInt? number;

  /// Block hash, or `null` for pending blocks.
  final String? hash;

  /// Hash of the parent block.
  final String parentHash;

  /// Nonce of the block (proof-of-work), or `null` for pending/PoS blocks.
  final String? nonce;

  /// SHA3 hash of the uncles data in the block.
  final String sha3Uncles;

  /// Bloom filter for the logs of the block.
  final String logsBloom;

  /// Root of the transaction trie of the block.
  final String transactionsRoot;

  /// Root of the state trie of the block.
  final String stateRoot;

  /// Root of the receipts trie of the block.
  final String receiptsRoot;

  /// Address of the block miner/validator.
  final EvmAddress miner;

  /// Block difficulty (always `0` post-merge).
  final BigInt difficulty;

  /// Total difficulty of the chain up to this block.
  final BigInt? totalDifficulty;

  /// Extra data included by the miner/validator.
  final String extraData;

  /// Block size in bytes.
  final BigInt size;

  /// Maximum gas allowed in this block.
  final BigInt gasLimit;

  /// Total gas used by all transactions in this block.
  final BigInt gasUsed;

  /// Block timestamp (seconds since epoch).
  final BigInt timestamp;

  /// Hashes of uncle blocks.
  final List<String> uncles;

  /// Mix hash used in proof-of-work.
  final String? mixHash;

  // -- Dual-mode transactions (D-09) --

  /// Transaction hashes when `fullTransactions=false`, otherwise `null`.
  final List<String>? transactionHashes;

  /// Full transaction objects when `fullTransactions=true`, otherwise `null`.
  final List<EthTransaction>? transactions;

  // -- EIP-1559 fields --

  /// Base fee per gas for this block (EIP-1559), or `null` for pre-London blocks.
  final BigInt? baseFeePerGas;

  // -- EIP-4895 fields --

  /// Beacon chain withdrawals included in this block (EIP-4895), or `null`.
  final List<EthWithdrawal>? withdrawals;

  /// Root of the withdrawals trie (EIP-4895), or `null`.
  final String? withdrawalsRoot;

  // -- EIP-4844 fields --

  /// Total blob gas used by transactions in this block (EIP-4844), or `null`.
  final BigInt? blobGasUsed;

  /// Excess blob gas for this block (EIP-4844), or `null`.
  final BigInt? excessBlobGas;

  /// Parent beacon block root (EIP-4844), or `null`.
  final String? parentBeaconBlockRoot;

  /// Creates an [EthBlock] with all fields.
  const EthBlock({
    required this.number,
    required this.hash,
    required this.parentHash,
    required this.nonce,
    required this.sha3Uncles,
    required this.logsBloom,
    required this.transactionsRoot,
    required this.stateRoot,
    required this.receiptsRoot,
    required this.miner,
    required this.difficulty,
    required this.totalDifficulty,
    required this.extraData,
    required this.size,
    required this.gasLimit,
    required this.gasUsed,
    required this.timestamp,
    required this.uncles,
    required this.mixHash,
    this.transactionHashes,
    this.transactions,
    this.baseFeePerGas,
    this.withdrawals,
    this.withdrawalsRoot,
    this.blobGasUsed,
    this.excessBlobGas,
    this.parentBeaconBlockRoot,
  });

  /// Parses an [EthBlock] from a JSON-RPC response map.
  ///
  /// Automatically detects whether the `transactions` field contains
  /// hash strings or full transaction objects and populates either
  /// [transactionHashes] or [transactions] accordingly.
  factory EthBlock.fromJson(Map<String, dynamic> json) {
    final txList = json['transactions'] as List;
    List<String>? txHashes;
    List<EthTransaction>? txObjects;

    if (txList.isEmpty || txList.first is String) {
      txHashes = txList.cast<String>();
    } else {
      txObjects = txList
          .map((e) => EthTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return EthBlock(
      number: _hexOrNull(json['number']),
      hash: json['hash'] as String?,
      parentHash: json['parentHash'] as String,
      nonce: json['nonce'] as String?,
      sha3Uncles: json['sha3Uncles'] as String,
      logsBloom: json['logsBloom'] as String,
      transactionsRoot: json['transactionsRoot'] as String,
      stateRoot: json['stateRoot'] as String,
      receiptsRoot: json['receiptsRoot'] as String,
      miner: EvmAddress(json['miner'] as String),
      difficulty: BigIntUtils.hexToBigInt(json['difficulty'] as String),
      totalDifficulty: _hexOrNull(json['totalDifficulty']),
      extraData: json['extraData'] as String,
      size: BigIntUtils.hexToBigInt(json['size'] as String),
      gasLimit: BigIntUtils.hexToBigInt(json['gasLimit'] as String),
      gasUsed: BigIntUtils.hexToBigInt(json['gasUsed'] as String),
      timestamp: BigIntUtils.hexToBigInt(json['timestamp'] as String),
      uncles: (json['uncles'] as List).cast<String>(),
      mixHash: json['mixHash'] as String?,
      transactionHashes: txHashes,
      transactions: txObjects,
      baseFeePerGas: _hexOrNull(json['baseFeePerGas']),
      withdrawals: _parseWithdrawals(json['withdrawals']),
      withdrawalsRoot: json['withdrawalsRoot'] as String?,
      blobGasUsed: _hexOrNull(json['blobGasUsed']),
      excessBlobGas: _hexOrNull(json['excessBlobGas']),
      parentBeaconBlockRoot: json['parentBeaconBlockRoot'] as String?,
    );
  }

  static BigInt? _hexOrNull(dynamic value) {
    if (value == null) return null;
    return BigIntUtils.hexToBigInt(value as String);
  }

  static List<EthWithdrawal>? _parseWithdrawals(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => EthWithdrawal.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
