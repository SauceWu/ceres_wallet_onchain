/// Epoch information returned by `getEpochInfo`.
///
/// ```dart
/// final info = EpochInfo.fromJson(jsonMap);
/// print('Epoch ${info.epoch}, slot ${info.slotIndex}/${info.slotsInEpoch}');
/// ```
class EpochInfo {
  /// The current epoch.
  final int epoch;

  /// The current slot index relative to the start of the current epoch.
  final int slotIndex;

  /// The number of slots in this epoch.
  final int slotsInEpoch;

  /// The current slot (absolute).
  final int absoluteSlot;

  /// The current block height.
  final int blockHeight;

  /// Total number of transactions processed, or `null` if not available.
  final BigInt? transactionCount;

  /// Creates an [EpochInfo] with all fields.
  const EpochInfo({
    required this.epoch,
    required this.slotIndex,
    required this.slotsInEpoch,
    required this.absoluteSlot,
    required this.blockHeight,
    this.transactionCount,
  });

  /// Parses an [EpochInfo] from a Solana RPC JSON response map.
  factory EpochInfo.fromJson(Map<String, dynamic> json) {
    return EpochInfo(
      epoch: json['epoch'] as int,
      slotIndex: json['slotIndex'] as int,
      slotsInEpoch: json['slotsInEpoch'] as int,
      absoluteSlot: json['absoluteSlot'] as int,
      blockHeight: json['blockHeight'] as int,
      transactionCount: json['transactionCount'] != null
          ? BigInt.from(json['transactionCount'] as num)
          : null,
    );
  }
}

/// Epoch schedule configuration returned by `getEpochSchedule`.
///
/// ```dart
/// final schedule = EpochSchedule.fromJson(jsonMap);
/// print('Slots per epoch: ${schedule.slotsPerEpoch}');
/// ```
class EpochSchedule {
  /// The maximum number of slots in each epoch.
  final int slotsPerEpoch;

  /// The number of slots before the beginning of an epoch to calculate
  /// the leader schedule for that epoch.
  final int leaderScheduleSlotOffset;

  /// Whether epochs start short and grow.
  final bool warmup;

  /// The first normal-length epoch.
  final int firstNormalEpoch;

  /// The first normal-length slot.
  final int firstNormalSlot;

  /// Creates an [EpochSchedule] with all fields.
  const EpochSchedule({
    required this.slotsPerEpoch,
    required this.leaderScheduleSlotOffset,
    required this.warmup,
    required this.firstNormalEpoch,
    required this.firstNormalSlot,
  });

  /// Parses an [EpochSchedule] from a Solana RPC JSON response map.
  factory EpochSchedule.fromJson(Map<String, dynamic> json) {
    return EpochSchedule(
      slotsPerEpoch: json['slotsPerEpoch'] as int,
      leaderScheduleSlotOffset: json['leaderScheduleSlotOffset'] as int,
      warmup: json['warmup'] as bool,
      firstNormalEpoch: json['firstNormalEpoch'] as int,
      firstNormalSlot: json['firstNormalSlot'] as int,
    );
  }
}
