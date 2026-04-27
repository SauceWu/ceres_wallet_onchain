/// Snapshot slot information returned by `getSnapshotSlot` or
/// `getHighestSnapshotSlot`.
///
/// ```dart
/// final snapshot = SnapshotSlot.fromJson(jsonMap);
/// print('Full: ${snapshot.full}, incremental: ${snapshot.incremental}');
/// ```
class SnapshotSlot {
  /// The highest full snapshot slot.
  final int full;

  /// The highest incremental snapshot slot based on [full], or `null`.
  final int? incremental;

  /// Creates a [SnapshotSlot] with all fields.
  const SnapshotSlot({required this.full, this.incremental});

  /// Parses a [SnapshotSlot] from a Solana RPC JSON response map.
  factory SnapshotSlot.fromJson(Map<String, dynamic> json) {
    return SnapshotSlot(
      full: json['full'] as int,
      incremental: json['incremental'] as int?,
    );
  }
}
