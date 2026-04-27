/// Sui validators APY response model.
///
/// Returned by `suix_getValidatorsApy`.
library;

/// APY information for a single validator.
class ValidatorApy {
  /// The validator address.
  final String address;

  /// The annual percentage yield as a decimal (e.g., 0.05 = 5%).
  final double apy;

  /// Creates a [ValidatorApy].
  const ValidatorApy({required this.address, required this.apy});

  /// Parses a [ValidatorApy] from a JSON map.
  factory ValidatorApy.fromJson(Map<String, dynamic> json) {
    return ValidatorApy(
      address: json['address'] as String,
      apy: (json['apy'] as num).toDouble(),
    );
  }
}

/// APY information for all validators in a given epoch.
class ValidatorsApy {
  /// The list of validator APY records.
  final List<ValidatorApy> apys;

  /// The epoch this data is from.
  final String epoch;

  /// Creates a [ValidatorsApy].
  const ValidatorsApy({required this.apys, required this.epoch});

  /// Parses a [ValidatorsApy] from a JSON map.
  factory ValidatorsApy.fromJson(Map<String, dynamic> json) {
    return ValidatorsApy(
      apys: (json['apys'] as List<dynamic>)
          .map((e) => ValidatorApy.fromJson(e as Map<String, dynamic>))
          .toList(),
      epoch: json['epoch'] as String,
    );
  }
}
