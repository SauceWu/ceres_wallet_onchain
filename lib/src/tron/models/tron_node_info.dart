/// Node information returned by `getnodeinfo` API.
///
/// Contains sync status, connection counts, and machine/config details.
///
/// ```dart
/// final info = TronNodeInfo.fromJson(responseJson);
/// print(info.currentConnectCount);
/// ```
class TronNodeInfo {
  /// Starting sync block number.
  final int? beginSyncNum;

  /// Current block identifier string.
  final String? block;

  /// Solidity (confirmed) block number.
  final int? solidityBlock;

  /// Current total peer connections.
  final int? currentConnectCount;

  /// Active outbound connections.
  final int? activeConnectCount;

  /// Passive inbound connections.
  final int? passiveConnectCount;

  /// Total network traffic flow.
  final int? totalFlow;

  /// Node configuration details.
  final Map<String, dynamic>? configNodeInfo;

  /// Machine hardware/OS details.
  final Map<String, dynamic>? machineInfo;

  /// Creates a [TronNodeInfo].
  const TronNodeInfo({
    this.beginSyncNum,
    this.block,
    this.solidityBlock,
    this.currentConnectCount,
    this.activeConnectCount,
    this.passiveConnectCount,
    this.totalFlow,
    this.configNodeInfo,
    this.machineInfo,
  });

  /// Parses a [TronNodeInfo] from a JSON object.
  factory TronNodeInfo.fromJson(Map<String, dynamic> json) {
    return TronNodeInfo(
      beginSyncNum: json['beginSyncNum'] as int?,
      block: json['block'] as String?,
      solidityBlock: json['solidityBlock'] as int?,
      currentConnectCount: json['currentConnectCount'] as int?,
      activeConnectCount: json['activeConnectCount'] as int?,
      passiveConnectCount: json['passiveConnectCount'] as int?,
      totalFlow: json['totalFlow'] as int?,
      configNodeInfo: json['configNodeInfo'] as Map<String, dynamic>?,
      machineInfo: json['machineInfo'] as Map<String, dynamic>?,
    );
  }
}
