/// Stake activation status returned by `getStakeActivation`.
///
/// [active] and [inactive] use [BigInt] for safe lamport handling.
///
/// ```dart
/// final stake = StakeActivation.fromJson(jsonMap);
/// print('State: ${stake.state}, active: ${stake.active} lamports');
/// ```
class StakeActivation {
  /// The activation state: `"activating"`, `"active"`, `"deactivating"`,
  /// or `"inactive"`.
  final String state;

  /// The amount of active stake in lamports.
  final BigInt active;

  /// The amount of inactive stake in lamports.
  final BigInt inactive;

  /// Creates a [StakeActivation] with all fields.
  const StakeActivation({
    required this.state,
    required this.active,
    required this.inactive,
  });

  /// Parses a [StakeActivation] from a Solana RPC JSON response map.
  factory StakeActivation.fromJson(Map<String, dynamic> json) {
    return StakeActivation(
      state: json['state'] as String,
      active: BigInt.from(json['active'] as num),
      inactive: BigInt.from(json['inactive'] as num),
    );
  }
}
