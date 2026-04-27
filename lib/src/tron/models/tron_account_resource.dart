/// Account resource information returned by `getaccountresource` API.
///
/// Contains bandwidth, energy, and Tron Power usage and limits.
/// All numeric fields use [BigInt] for consistency with other models.
///
/// ```dart
/// final resource = TronAccountResource.fromJson(responseJson);
/// print(resource.freeNetLimit);
/// print(resource.energyLimit);
/// ```
class TronAccountResource {
  /// Free bandwidth used.
  final BigInt? freeNetUsed;

  /// Free bandwidth limit.
  final BigInt? freeNetLimit;

  /// Staked bandwidth used.
  final BigInt? netUsed;

  /// Staked bandwidth limit.
  final BigInt? netLimit;

  /// Energy used.
  final BigInt? energyUsed;

  /// Energy limit.
  final BigInt? energyLimit;

  /// Total network bandwidth limit.
  final BigInt? totalNetLimit;

  /// Total network bandwidth weight.
  final BigInt? totalNetWeight;

  /// Total network energy limit.
  final BigInt? totalEnergyLimit;

  /// Total network energy weight.
  final BigInt? totalEnergyWeight;

  /// Tron Power used.
  final BigInt? tronPowerUsed;

  /// Tron Power limit.
  final BigInt? tronPowerLimit;

  /// Creates a [TronAccountResource].
  const TronAccountResource({
    this.freeNetUsed,
    this.freeNetLimit,
    this.netUsed,
    this.netLimit,
    this.energyUsed,
    this.energyLimit,
    this.totalNetLimit,
    this.totalNetWeight,
    this.totalEnergyLimit,
    this.totalEnergyWeight,
    this.tronPowerUsed,
    this.tronPowerLimit,
  });

  /// Parses a [TronAccountResource] from a Tron HTTP API response map.
  factory TronAccountResource.fromJson(Map<String, dynamic> json) {
    return TronAccountResource(
      freeNetUsed: _bigIntOrNull(json['freeNetUsed']),
      freeNetLimit: _bigIntOrNull(json['freeNetLimit']),
      netUsed: _bigIntOrNull(json['NetUsed']),
      netLimit: _bigIntOrNull(json['NetLimit']),
      energyUsed: _bigIntOrNull(json['EnergyUsed']),
      energyLimit: _bigIntOrNull(json['EnergyLimit']),
      totalNetLimit: _bigIntOrNull(json['TotalNetLimit']),
      totalNetWeight: _bigIntOrNull(json['TotalNetWeight']),
      totalEnergyLimit: _bigIntOrNull(json['TotalEnergyLimit']),
      totalEnergyWeight: _bigIntOrNull(json['TotalEnergyWeight']),
      tronPowerUsed: _bigIntOrNull(json['tronPowerUsed']),
      tronPowerLimit: _bigIntOrNull(json['tronPowerLimit']),
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}
