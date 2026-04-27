/// Sui staking response models.
///
/// Returned by `suix_getStakes` and `suix_getStakesByIds`.
library;

/// A single stake object within a delegated stake.
class StakeObject {
  /// The object ID of the staked SUI.
  final String stakedSuiId;

  /// The epoch when the stake was requested.
  final String stakeRequestEpoch;

  /// The epoch when the stake became active.
  final String stakeActiveEpoch;

  /// The principal amount staked as [BigInt].
  final BigInt principal;

  /// The stake status (`Active`, `Pending`, `Unstaked`).
  final String status;

  /// Estimated reward in MIST, or `null` if not yet calculated.
  final BigInt? estimatedReward;

  /// Creates a [StakeObject].
  const StakeObject({
    required this.stakedSuiId,
    required this.stakeRequestEpoch,
    required this.stakeActiveEpoch,
    required this.principal,
    required this.status,
    this.estimatedReward,
  });

  /// Parses a [StakeObject] from a JSON map.
  factory StakeObject.fromJson(Map<String, dynamic> json) {
    return StakeObject(
      stakedSuiId: json['stakedSuiId'] as String,
      stakeRequestEpoch: json['stakeRequestEpoch'] as String,
      stakeActiveEpoch: json['stakeActiveEpoch'] as String,
      principal: BigInt.parse(json['principal'] as String),
      status: json['status'] as String,
      estimatedReward: json['estimatedReward'] != null
          ? BigInt.parse(json['estimatedReward'] as String)
          : null,
    );
  }
}

/// Delegated stake information for a validator.
class DelegatedStake {
  /// The validator address.
  final String validatorAddress;

  /// The staking pool object ID.
  final String stakingPool;

  /// The list of stake objects.
  final List<StakeObject> stakes;

  /// Creates a [DelegatedStake].
  const DelegatedStake({
    required this.validatorAddress,
    required this.stakingPool,
    required this.stakes,
  });

  /// Parses a [DelegatedStake] from a JSON map.
  factory DelegatedStake.fromJson(Map<String, dynamic> json) {
    return DelegatedStake(
      validatorAddress: json['validatorAddress'] as String,
      stakingPool: json['stakingPool'] as String,
      stakes: (json['stakes'] as List<dynamic>)
          .map((e) => StakeObject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
