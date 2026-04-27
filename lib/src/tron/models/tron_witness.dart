/// A Tron witness (super representative) returned by `listwitnesses` API.
///
/// ```dart
/// final witness = TronWitness.fromJson(json);
/// print(witness.address);
/// print(witness.voteCount);
/// ```
class TronWitness {
  /// Witness address (base58).
  final String? address;

  /// Total votes received.
  final BigInt? voteCount;

  /// Witness website URL.
  final String? url;

  /// Total blocks produced.
  final BigInt? totalProduced;

  /// Total blocks missed.
  final BigInt? totalMissed;

  /// Latest block number produced.
  final int? latestBlockNum;

  /// Latest slot number.
  final int? latestSlotNum;

  /// Whether this witness is currently active (producing blocks).
  final bool? isJobs;

  /// Creates a [TronWitness].
  const TronWitness({
    this.address,
    this.voteCount,
    this.url,
    this.totalProduced,
    this.totalMissed,
    this.latestBlockNum,
    this.latestSlotNum,
    this.isJobs,
  });

  /// Parses a [TronWitness] from a JSON object.
  factory TronWitness.fromJson(Map<String, dynamic> json) {
    return TronWitness(
      address: json['address'] as String?,
      voteCount: _bigIntOrNull(json['voteCount']),
      url: json['url'] as String?,
      totalProduced: _bigIntOrNull(json['totalProduced']),
      totalMissed: _bigIntOrNull(json['totalMissed']),
      latestBlockNum: json['latestBlockNum'] as int?,
      latestSlotNum: json['latestSlotNum'] as int?,
      isJobs: json['isJobs'] as bool?,
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}
