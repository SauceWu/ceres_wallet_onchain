/// Transaction metadata from a Solana RPC response.
///
/// Contains execution results including fees, balance changes, log messages,
/// and loaded addresses (for v0 versioned transactions).
///
/// All lamport values ([fee], [preBalances], [postBalances],
/// [computeUnitsConsumed]) use [BigInt] to prevent overflow on large balances.
///
/// ```dart
/// final meta = TransactionMeta.fromJson(jsonMap);
/// print(meta.fee);          // BigInt fee in lamports
/// print(meta.logMessages);  // execution logs
/// ```
class TransactionMeta {
  /// Transaction error, or `null` if the transaction succeeded.
  ///
  /// When non-null, contains the error object from the RPC response
  /// (e.g., `{'InstructionError': [0, 'Custom']}`).
  final dynamic err;

  /// Transaction fee in lamports.
  final BigInt fee;

  /// Account balances before the transaction was processed.
  final List<BigInt> preBalances;

  /// Account balances after the transaction was processed.
  final List<BigInt> postBalances;

  /// Token balances before the transaction, or `null` if not available.
  final List<Map<String, dynamic>>? preTokenBalances;

  /// Token balances after the transaction, or `null` if not available.
  final List<Map<String, dynamic>>? postTokenBalances;

  /// Program log messages emitted during execution, or `null`.
  final List<String>? logMessages;

  /// Compute units consumed by the transaction, or `null`.
  final BigInt? computeUnitsConsumed;

  /// Inner instructions (cross-program invocations), or `null`.
  final List<Map<String, dynamic>>? innerInstructions;

  /// Addresses loaded from address lookup tables (v0 transactions only).
  ///
  /// Contains `writable` and `readonly` address lists. `null` for legacy
  /// transactions.
  final Map<String, dynamic>? loadedAddresses;

  /// Creates a [TransactionMeta] with all fields.
  const TransactionMeta({
    required this.err,
    required this.fee,
    required this.preBalances,
    required this.postBalances,
    this.preTokenBalances,
    this.postTokenBalances,
    this.logMessages,
    this.computeUnitsConsumed,
    this.innerInstructions,
    this.loadedAddresses,
  });

  /// Parses a [TransactionMeta] from a Solana RPC JSON response map.
  ///
  /// Lamport values are converted to [BigInt] using [BigInt.from] to prevent
  /// overflow on large balances (threat T-06-05).
  factory TransactionMeta.fromJson(Map<String, dynamic> json) {
    return TransactionMeta(
      err: json['err'],
      fee: BigInt.from(json['fee'] as num),
      preBalances: _parseBigIntList(json['preBalances']),
      postBalances: _parseBigIntList(json['postBalances']),
      preTokenBalances: _parseMapList(json['preTokenBalances']),
      postTokenBalances: _parseMapList(json['postTokenBalances']),
      logMessages: _parseStringList(json['logMessages']),
      computeUnitsConsumed: json['computeUnitsConsumed'] != null
          ? BigInt.from(json['computeUnitsConsumed'] as num)
          : null,
      innerInstructions: _parseMapList(json['innerInstructions']),
      loadedAddresses: json['loadedAddresses'] as Map<String, dynamic>?,
    );
  }

  static List<BigInt> _parseBigIntList(dynamic value) {
    if (value == null) return [];
    return (value as List).map((e) => BigInt.from(e as num)).toList();
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<String>();
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<Map<String, dynamic>>();
  }
}
