/// A Tron transaction object returned by various API endpoints.
///
/// Contains the transaction ID, raw data with contract calls, and signatures.
///
/// ```dart
/// final tx = TronTransaction.fromJson(responseJson);
/// print(tx.txID);
/// print(tx.rawData?.contract);
/// ```
class TronTransaction {
  /// Transaction hash (hex string).
  final String? txID;

  /// Raw transaction data containing contract calls and metadata.
  final TronTransactionRaw? rawData;

  /// Hex-encoded raw data.
  final String? rawDataHex;

  /// Transaction signatures (hex strings).
  final List<String> signature;

  /// Transaction execution results.
  final List<Map<String, dynamic>>? ret;

  /// Creates a [TronTransaction] with all fields.
  const TronTransaction({
    this.txID,
    this.rawData,
    this.rawDataHex,
    this.signature = const [],
    this.ret,
  });

  /// Parses a [TronTransaction] from a Tron HTTP API response map.
  factory TronTransaction.fromJson(Map<String, dynamic> json) {
    return TronTransaction(
      txID: json['txID'] as String?,
      rawData: json['raw_data'] != null
          ? TronTransactionRaw.fromJson(
              json['raw_data'] as Map<String, dynamic>,
            )
          : null,
      rawDataHex: json['raw_data_hex'] as String?,
      signature: _parseStringList(json['signature']),
      ret: _parseMapList(json['ret']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    return (value as List).cast<String>();
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<Map<String, dynamic>>();
  }
}

/// Raw transaction data containing contract calls and block references.
class TronTransactionRaw {
  /// Contract call entries. Each entry describes one contract invocation.
  final List<Map<String, dynamic>> contract;

  /// Reference block bytes (hex).
  final String? refBlockBytes;

  /// Reference block hash (hex).
  final String? refBlockHash;

  /// Transaction expiration timestamp (milliseconds since epoch).
  final int? expiration;

  /// Transaction creation timestamp (milliseconds since epoch).
  final int? timestamp;

  /// Maximum energy fee in sun.
  final BigInt? feeLimit;

  /// Transaction memo/data (UTF-8 string or hex).
  final String? data;

  /// Creates a [TronTransactionRaw].
  const TronTransactionRaw({
    this.contract = const [],
    this.refBlockBytes,
    this.refBlockHash,
    this.expiration,
    this.timestamp,
    this.feeLimit,
    this.data,
  });

  /// Parses from the `raw_data` JSON object.
  factory TronTransactionRaw.fromJson(Map<String, dynamic> json) {
    return TronTransactionRaw(
      contract: _parseContracts(json['contract']),
      refBlockBytes: json['ref_block_bytes'] as String?,
      refBlockHash: json['ref_block_hash'] as String?,
      expiration: json['expiration'] as int?,
      timestamp: json['timestamp'] as int?,
      feeLimit: _bigIntOrNull(json['fee_limit']),
      data: json['data'] as String?,
    );
  }

  static List<Map<String, dynamic>> _parseContracts(dynamic value) {
    if (value == null) return const [];
    return (value as List).cast<Map<String, dynamic>>();
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}
