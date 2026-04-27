/// Block production information returned by `getBlockProduction`.
///
/// ```dart
/// final production = BlockProduction.fromJson(jsonMap);
/// for (final entry in production.byIdentity.entries) {
///   print('${entry.key}: ${entry.value[0]} slots, ${entry.value[1]} blocks');
/// }
/// ```
class BlockProduction {
  /// Map of validator identity to `[numLeaderSlots, numBlocksProduced]`.
  final Map<String, List<int>> byIdentity;

  /// Slot range with `firstSlot` and `lastSlot` keys.
  final Map<String, int> range;

  /// Creates a [BlockProduction] with all fields.
  const BlockProduction({required this.byIdentity, required this.range});

  /// Parses a [BlockProduction] from a Solana RPC JSON response map.
  factory BlockProduction.fromJson(Map<String, dynamic> json) {
    final rawIdentity = json['byIdentity'] as Map<String, dynamic>;
    final identity = rawIdentity.map(
      (key, value) => MapEntry(key, (value as List).cast<int>()),
    );

    final rawRange = json['range'] as Map<String, dynamic>;
    final range = rawRange.map((key, value) => MapEntry(key, value as int));

    return BlockProduction(byIdentity: identity, range: range);
  }
}
