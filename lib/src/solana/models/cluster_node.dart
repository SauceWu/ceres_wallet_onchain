/// A cluster node returned by `getClusterNodes`.
///
/// All fields except [pubkey] are optional as nodes may not expose all
/// network endpoints.
///
/// ```dart
/// final node = ClusterNode.fromJson(jsonMap);
/// print('${node.pubkey} running ${node.version}');
/// ```
class ClusterNode {
  /// Node identity public key (base-58 encoded).
  final String pubkey;

  /// Gossip network address, or `null`.
  final String? gossip;

  /// TPU network address, or `null`.
  final String? tpu;

  /// JSON RPC network address, or `null`.
  final String? rpc;

  /// Software version, or `null`.
  final String? version;

  /// Feature set identifier, or `null`.
  final int? featureSet;

  /// Shred version, or `null`.
  final int? shredVersion;

  /// Creates a [ClusterNode] with all fields.
  const ClusterNode({
    required this.pubkey,
    this.gossip,
    this.tpu,
    this.rpc,
    this.version,
    this.featureSet,
    this.shredVersion,
  });

  /// Parses a [ClusterNode] from a Solana RPC JSON response map.
  factory ClusterNode.fromJson(Map<String, dynamic> json) {
    return ClusterNode(
      pubkey: json['pubkey'] as String,
      gossip: json['gossip'] as String?,
      tpu: json['tpu'] as String?,
      rpc: json['rpc'] as String?,
      version: json['version'] as String?,
      featureSet: json['featureSet'] as int?,
      shredVersion: json['shredVersion'] as int?,
    );
  }
}
