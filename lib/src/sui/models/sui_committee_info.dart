/// Sui committee info response model.
///
/// Returned by `suix_getCommitteeInfo`.
library;

/// A single validator in the committee.
class CommitteeValidator {
  /// The authority public key name.
  final String authorityName;

  /// The validator's stake unit as [BigInt].
  final BigInt stakeUnit;

  /// Creates a [CommitteeValidator].
  const CommitteeValidator({
    required this.authorityName,
    required this.stakeUnit,
  });

  /// Parses a [CommitteeValidator] from a JSON list `[name, stakeUnit]`.
  factory CommitteeValidator.fromJson(List<dynamic> json) {
    return CommitteeValidator(
      authorityName: json[0] as String,
      stakeUnit: BigInt.parse(json[1] as String),
    );
  }
}

/// Committee information for a given epoch.
class CommitteeInfo {
  /// The epoch this committee is for.
  final String epoch;

  /// The list of validators in the committee.
  final List<CommitteeValidator> validators;

  /// Creates a [CommitteeInfo].
  const CommitteeInfo({required this.epoch, required this.validators});

  /// Parses a [CommitteeInfo] from a JSON map.
  factory CommitteeInfo.fromJson(Map<String, dynamic> json) {
    return CommitteeInfo(
      epoch: json['epoch'] as String,
      validators: (json['validators'] as List<dynamic>)
          .map((e) => CommitteeValidator.fromJson(e as List<dynamic>))
          .toList(),
    );
  }
}
