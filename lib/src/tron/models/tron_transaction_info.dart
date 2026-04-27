/// Transaction info (receipt) returned by `gettransactioninfobyid` API.
///
/// Contains fee details, execution receipt, event logs, and error information.
///
/// ```dart
/// final info = TronTransactionInfo.fromJson(responseJson);
/// print(info.fee);
/// print(info.receipt?.result); // 'SUCCESS' or 'REVERT'
/// ```
class TronTransactionInfo {
  /// Transaction hash (hex string).
  final String? id;

  /// Total fee consumed in sun.
  final BigInt? fee;

  /// Block number containing this transaction.
  final int? blockNumber;

  /// Block timestamp (milliseconds since epoch).
  final int? blockTimeStamp;

  /// Contract execution result (hex string).
  final List<String>? contractResult;

  /// Contract address created by this transaction (base58).
  final String? contractAddress;

  /// Execution receipt with energy/bandwidth usage.
  final TronReceipt? receipt;

  /// Event logs emitted during execution.
  final List<TronEventLog>? log;

  /// Execution result: `FAILED`, etc.
  final String? result;

  /// Hex-encoded error message.
  final String? resMessage;

  /// Internal transactions triggered.
  final List<Map<String, dynamic>>? internalTransactions;

  /// Creates a [TronTransactionInfo].
  const TronTransactionInfo({
    this.id,
    this.fee,
    this.blockNumber,
    this.blockTimeStamp,
    this.contractResult,
    this.contractAddress,
    this.receipt,
    this.log,
    this.result,
    this.resMessage,
    this.internalTransactions,
  });

  /// Parses a [TronTransactionInfo] from a Tron HTTP API response map.
  factory TronTransactionInfo.fromJson(Map<String, dynamic> json) {
    return TronTransactionInfo(
      id: json['id'] as String?,
      fee: _bigIntOrNull(json['fee']),
      blockNumber: json['blockNumber'] as int?,
      blockTimeStamp: json['blockTimeStamp'] as int?,
      contractResult: _parseStringList(json['contractResult']),
      contractAddress: json['contract_address'] as String?,
      receipt: json['receipt'] != null
          ? TronReceipt.fromJson(json['receipt'] as Map<String, dynamic>)
          : null,
      log: _parseEventLogs(json['log']),
      result: json['result'] as String?,
      resMessage: json['resMessage'] as String?,
      internalTransactions: _parseMapList(json['internal_transactions']),
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<String>();
  }

  static List<TronEventLog>? _parseEventLogs(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => TronEventLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<Map<String, dynamic>>();
  }
}

/// Transaction execution receipt with resource usage details.
class TronReceipt {
  /// Energy used by this transaction.
  final BigInt? energyUsage;

  /// Energy fee paid in sun.
  final BigInt? energyFee;

  /// Energy used from the contract creator's allowance.
  final BigInt? originEnergyUsage;

  /// Total energy usage.
  final BigInt? energyUsageTotal;

  /// Net (bandwidth) usage.
  final BigInt? netUsage;

  /// Net fee paid in sun.
  final BigInt? netFee;

  /// Execution result: `SUCCESS`, `REVERT`, `OUT_OF_ENERGY`, etc.
  final String? result;

  /// Creates a [TronReceipt].
  const TronReceipt({
    this.energyUsage,
    this.energyFee,
    this.originEnergyUsage,
    this.energyUsageTotal,
    this.netUsage,
    this.netFee,
    this.result,
  });

  /// Parses from the `receipt` JSON object.
  factory TronReceipt.fromJson(Map<String, dynamic> json) {
    return TronReceipt(
      energyUsage: _bigIntOrNull(json['energy_usage']),
      energyFee: _bigIntOrNull(json['energy_fee']),
      originEnergyUsage: _bigIntOrNull(json['origin_energy_usage']),
      energyUsageTotal: _bigIntOrNull(json['energy_usage_total']),
      netUsage: _bigIntOrNull(json['net_usage']),
      netFee: _bigIntOrNull(json['net_fee']),
      result: json['result'] as String?,
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}

/// An event log emitted during contract execution.
class TronEventLog {
  /// Contract address that emitted the event (hex).
  final String? address;

  /// Indexed event topics (hex strings).
  final List<String> topics;

  /// Non-indexed event data (hex string).
  final String? data;

  /// Creates a [TronEventLog].
  const TronEventLog({this.address, this.topics = const [], this.data});

  /// Parses from a log entry JSON object.
  factory TronEventLog.fromJson(Map<String, dynamic> json) {
    return TronEventLog(
      address: json['address'] as String?,
      topics: _parseStringList(json['topics']),
      data: json['data'] as String?,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    return (value as List).cast<String>();
  }
}
