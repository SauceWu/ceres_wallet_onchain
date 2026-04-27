import 'tron_transaction.dart';

/// A Tron block object returned by `getblock` / `getNowBlock` API.
///
/// Contains the block ID, header information, and a list of transactions.
///
/// ```dart
/// final block = TronBlock.fromJson(responseJson);
/// print(block.blockID);
/// print(block.blockHeader?.number);
/// ```
class TronBlock {
  /// Block hash (hex string).
  final String? blockID;

  /// Block header containing metadata.
  final TronBlockHeader? blockHeader;

  /// Transactions included in this block.
  final List<TronTransaction> transactions;

  /// Creates a [TronBlock] with all fields.
  const TronBlock({
    this.blockID,
    this.blockHeader,
    this.transactions = const [],
  });

  /// Parses a [TronBlock] from a Tron HTTP API response map.
  factory TronBlock.fromJson(Map<String, dynamic> json) {
    return TronBlock(
      blockID: json['blockID'] as String?,
      blockHeader: json['block_header'] != null
          ? TronBlockHeader.fromJson(
              json['block_header'] as Map<String, dynamic>,
            )
          : null,
      transactions: _parseTransactions(json['transactions']),
    );
  }

  static List<TronTransaction> _parseTransactions(dynamic value) {
    if (value == null) return const [];
    return (value as List)
        .map((e) => TronTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Block header containing metadata fields.
///
/// The raw data is nested under `raw_data` in the Tron API response.
class TronBlockHeader {
  /// Merkle root of the transaction trie.
  final String? txTrieRoot;

  /// Parent block hash.
  final String? parentHash;

  /// Witness (super representative) address.
  final String? witnessAddress;

  /// Block number.
  final int? number;

  /// Block timestamp (milliseconds since epoch).
  final int? timestamp;

  /// Block version.
  final int? version;

  /// Witness signature.
  final String? witnessSignature;

  /// Creates a [TronBlockHeader].
  const TronBlockHeader({
    this.txTrieRoot,
    this.parentHash,
    this.witnessAddress,
    this.number,
    this.timestamp,
    this.version,
    this.witnessSignature,
  });

  /// Parses a [TronBlockHeader] from the `block_header` JSON object.
  ///
  /// The Tron API nests header fields under `raw_data`:
  /// ```json
  /// {"raw_data": {"number": 123, ...}, "witness_signature": "..."}
  /// ```
  factory TronBlockHeader.fromJson(Map<String, dynamic> json) {
    final rawData = json['raw_data'] as Map<String, dynamic>? ?? {};
    return TronBlockHeader(
      txTrieRoot: rawData['txTrieRoot'] as String?,
      parentHash: rawData['parentHash'] as String?,
      witnessAddress: rawData['witness_address'] as String?,
      number: rawData['number'] as int?,
      timestamp: rawData['timestamp'] as int?,
      version: rawData['version'] as int?,
      witnessSignature: json['witness_signature'] as String?,
    );
  }
}
