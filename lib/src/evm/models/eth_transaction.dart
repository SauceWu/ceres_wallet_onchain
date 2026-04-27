import '../evm_address.dart';
import '../../utils/bigint_utils.dart';
import 'access_list_entry.dart';

/// An Ethereum transaction object returned by `eth_getTransactionBy*` methods.
///
/// Supports all four transaction types:
/// - **Type 0** (legacy): [gasPrice] present, no [accessList] or EIP-1559 fields.
/// - **Type 1** (EIP-2930): [accessList] and [chainId] present, [gasPrice] present.
/// - **Type 2** (EIP-1559): [maxFeePerGas] and [maxPriorityFeePerGas] present.
/// - **Type 3** (EIP-4844): [blobVersionedHashes] and [maxFeePerBlobGas] present.
///
/// Pending transactions (not yet included in a block) have `null` for
/// [blockHash], [blockNumber], and [transactionIndex].
///
/// ```dart
/// final tx = EthTransaction.fromJson(jsonMap);
/// print(tx.type); // 0, 1, 2, or 3
/// print(tx.hash); // 0xe670ec64...
/// ```
class EthTransaction {
  /// Hash of the block containing this transaction, or `null` for pending.
  final String? blockHash;

  /// Number of the block containing this transaction, or `null` for pending.
  final BigInt? blockNumber;

  /// Address of the sender, or `null` if unavailable.
  final EvmAddress? from;

  /// Gas provided by the sender.
  final BigInt gas;

  /// Transaction hash.
  final String hash;

  /// Transaction input data (hex string).
  final String input;

  /// Number of transactions sent by the sender prior to this one.
  final BigInt nonce;

  /// Address of the receiver, or `null` for contract creation.
  final EvmAddress? to;

  /// Position of this transaction within the block, or `null` for pending.
  final BigInt? transactionIndex;

  /// Value transferred in wei.
  final BigInt value;

  /// Transaction type: 0 (legacy), 1 (EIP-2930), 2 (EIP-1559), 3 (EIP-4844).
  final int type;

  /// ECDSA recovery id.
  final BigInt v;

  /// ECDSA signature r value (hex string).
  final String r;

  /// ECDSA signature s value (hex string).
  final String s;

  // -- Type 0 field --

  /// Gas price in wei. Present for Type 0/1 transactions. May also be present
  /// in Type 2 responses as the effective gas price.
  final BigInt? gasPrice;

  // -- Type 1+ fields --

  /// Chain ID. Present for Type 1, 2, and 3 transactions.
  final BigInt? chainId;

  /// EIP-2930 access list. Present for Type 1, 2, and 3 transactions.
  final List<AccessListEntry>? accessList;

  // -- Type 2 fields --

  /// Maximum fee per gas the sender is willing to pay (EIP-1559).
  final BigInt? maxFeePerGas;

  /// Maximum priority fee per gas (tip) the sender is willing to pay (EIP-1559).
  final BigInt? maxPriorityFeePerGas;

  // -- Type 3 fields --

  /// Blob versioned hashes for EIP-4844 blob transactions.
  final List<String>? blobVersionedHashes;

  /// Maximum fee per blob gas (EIP-4844).
  final BigInt? maxFeePerBlobGas;

  /// Creates an [EthTransaction] with all fields.
  const EthTransaction({
    required this.blockHash,
    required this.blockNumber,
    required this.from,
    required this.gas,
    required this.hash,
    required this.input,
    required this.nonce,
    required this.to,
    required this.transactionIndex,
    required this.value,
    required this.type,
    required this.v,
    required this.r,
    required this.s,
    this.gasPrice,
    this.chainId,
    this.accessList,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.blobVersionedHashes,
    this.maxFeePerBlobGas,
  });

  /// Parses an [EthTransaction] from a JSON-RPC response map.
  ///
  /// All hex quantity fields are converted to [BigInt]. Nullable fields
  /// handle pending transactions and type-specific optional fields.
  factory EthTransaction.fromJson(Map<String, dynamic> json) {
    return EthTransaction(
      blockHash: json['blockHash'] as String?,
      blockNumber: _hexOrNull(json['blockNumber']),
      from: _addressOrNull(json['from']),
      gas: BigIntUtils.hexToBigInt(json['gas'] as String),
      hash: json['hash'] as String,
      input: json['input'] as String,
      nonce: BigIntUtils.hexToBigInt(json['nonce'] as String),
      to: _addressOrNull(json['to']),
      transactionIndex: _hexOrNull(json['transactionIndex']),
      value: BigIntUtils.hexToBigInt(json['value'] as String),
      type: _hexToInt(json['type'] as String),
      v: BigIntUtils.hexToBigInt(json['v'] as String),
      r: json['r'] as String,
      s: json['s'] as String,
      gasPrice: _hexOrNull(json['gasPrice']),
      chainId: _hexOrNull(json['chainId']),
      accessList: _parseAccessList(json['accessList']),
      maxFeePerGas: _hexOrNull(json['maxFeePerGas']),
      maxPriorityFeePerGas: _hexOrNull(json['maxPriorityFeePerGas']),
      blobVersionedHashes: _parseStringList(json['blobVersionedHashes']),
      maxFeePerBlobGas: _hexOrNull(json['maxFeePerBlobGas']),
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

  static List<AccessListEntry>? _parseAccessList(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => AccessListEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<String>();
  }
}
