/// A TRC-10 asset issue returned by `getassetissuebyid` API.
///
/// ```dart
/// final asset = TronAssetIssue.fromJson(responseJson);
/// print(asset.name);
/// print(asset.totalSupply);
/// ```
class TronAssetIssue {
  /// Asset owner address (base58).
  final String? ownerAddress;

  /// Asset name.
  final String? name;

  /// Asset abbreviation.
  final String? abbr;

  /// Total supply.
  final BigInt? totalSupply;

  /// TRX amount for exchange.
  final int? trxNum;

  /// Decimal precision.
  final int? precision;

  /// Token amount for exchange.
  final int? tokenNum;

  /// ICO start time (milliseconds since epoch).
  final int? startTime;

  /// ICO end time (milliseconds since epoch).
  final int? endTime;

  /// Asset description.
  final String? description;

  /// Asset website URL.
  final String? url;

  /// Asset ID (string).
  final String? id;

  /// Creates a [TronAssetIssue].
  const TronAssetIssue({
    this.ownerAddress,
    this.name,
    this.abbr,
    this.totalSupply,
    this.trxNum,
    this.precision,
    this.tokenNum,
    this.startTime,
    this.endTime,
    this.description,
    this.url,
    this.id,
  });

  /// Parses a [TronAssetIssue] from a JSON object.
  factory TronAssetIssue.fromJson(Map<String, dynamic> json) {
    return TronAssetIssue(
      ownerAddress: json['owner_address'] as String?,
      name: json['name'] as String?,
      abbr: json['abbr'] as String?,
      totalSupply: _bigIntOrNull(json['total_supply']),
      trxNum: json['trx_num'] as int?,
      precision: json['precision'] as int?,
      tokenNum: json['num'] as int?,
      startTime: json['start_time'] as int?,
      endTime: json['end_time'] as int?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      id: json['id'] as String?,
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}
