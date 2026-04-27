/// Inflation governor parameters returned by `getInflationGovernor`.
///
/// All fields are [double] representing percentage rates.
///
/// ```dart
/// final gov = InflationGovernor.fromJson(jsonMap);
/// print('Initial rate: ${gov.initial}');
/// ```
class InflationGovernor {
  /// The initial inflation percentage from time 0.
  final double initial;

  /// Terminal inflation percentage.
  final double terminal;

  /// Rate per year at which inflation is lowered. Rate reduction is derived
  /// using the target slot time in genesis config.
  final double taper;

  /// Percentage of total inflation allocated to the foundation.
  final double foundation;

  /// Duration of foundation pool inflation in years.
  final double foundationTerm;

  /// Creates an [InflationGovernor] with all fields.
  const InflationGovernor({
    required this.initial,
    required this.terminal,
    required this.taper,
    required this.foundation,
    required this.foundationTerm,
  });

  /// Parses an [InflationGovernor] from a Solana RPC JSON response map.
  factory InflationGovernor.fromJson(Map<String, dynamic> json) {
    return InflationGovernor(
      initial: (json['initial'] as num).toDouble(),
      terminal: (json['terminal'] as num).toDouble(),
      taper: (json['taper'] as num).toDouble(),
      foundation: (json['foundation'] as num).toDouble(),
      foundationTerm: (json['foundationTerm'] as num).toDouble(),
    );
  }
}

/// Specific inflation values for the current epoch returned by `getInflationRate`.
///
/// ```dart
/// final rate = InflationRate.fromJson(jsonMap);
/// print('Total rate: ${rate.total}, epoch: ${rate.epoch}');
/// ```
class InflationRate {
  /// Total inflation rate.
  final double total;

  /// Inflation allocated to validators.
  final double validator;

  /// Inflation allocated to the foundation.
  final double foundation;

  /// Epoch for which these values are valid.
  final int epoch;

  /// Creates an [InflationRate] with all fields.
  const InflationRate({
    required this.total,
    required this.validator,
    required this.foundation,
    required this.epoch,
  });

  /// Parses an [InflationRate] from a Solana RPC JSON response map.
  factory InflationRate.fromJson(Map<String, dynamic> json) {
    return InflationRate(
      total: (json['total'] as num).toDouble(),
      validator: (json['validator'] as num).toDouble(),
      foundation: (json['foundation'] as num).toDouble(),
      epoch: json['epoch'] as int,
    );
  }
}

/// Inflation reward for a single account returned by `getInflationReward`.
///
/// [amount] and [postBalance] use [BigInt] for safe lamport handling.
///
/// ```dart
/// final reward = InflationReward.fromJson(jsonMap);
/// print('Reward: ${reward.amount} lamports in epoch ${reward.epoch}');
/// ```
class InflationReward {
  /// Epoch for which the reward was credited.
  final int epoch;

  /// The slot in which the rewards were effective.
  final int effectiveSlot;

  /// Reward amount in lamports.
  final BigInt amount;

  /// Post-balance of the account in lamports.
  final BigInt postBalance;

  /// Vote account commission when the reward was credited, or `null`.
  final int? commission;

  /// Creates an [InflationReward] with all fields.
  const InflationReward({
    required this.epoch,
    required this.effectiveSlot,
    required this.amount,
    required this.postBalance,
    this.commission,
  });

  /// Parses an [InflationReward] from a Solana RPC JSON response map.
  factory InflationReward.fromJson(Map<String, dynamic> json) {
    return InflationReward(
      epoch: json['epoch'] as int,
      effectiveSlot: json['effectiveSlot'] as int,
      amount: BigInt.from(json['amount'] as num),
      postBalance: BigInt.from(json['postBalance'] as num),
      commission: json['commission'] as int?,
    );
  }
}
