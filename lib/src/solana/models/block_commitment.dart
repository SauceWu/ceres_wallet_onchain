/// Block commitment information returned by `getBlockCommitment`.
///
/// [totalStake] uses [BigInt] for safe lamport handling.
///
/// ```dart
/// final commitment = BlockCommitment.fromJson(jsonMap);
/// print('Total stake: ${commitment.totalStake}');
/// ```
class BlockCommitment {
  /// Array of cluster stake (in lamports) per confirmation level, or `null`
  /// if the block is unknown.
  final List<int>? commitment;

  /// Total active stake in lamports of the current epoch.
  final BigInt totalStake;

  /// Creates a [BlockCommitment] with all fields.
  const BlockCommitment({this.commitment, required this.totalStake});

  /// Parses a [BlockCommitment] from a Solana RPC JSON response map.
  factory BlockCommitment.fromJson(Map<String, dynamic> json) {
    return BlockCommitment(
      commitment: json['commitment'] != null
          ? (json['commitment'] as List).cast<int>()
          : null,
      totalStake: BigInt.from(json['totalStake'] as num),
    );
  }
}
