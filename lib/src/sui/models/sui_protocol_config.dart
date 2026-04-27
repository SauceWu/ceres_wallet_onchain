/// Sui protocol configuration model.
///
/// Wraps the JSON map returned by `sui_getProtocolConfig` and provides
/// typed shortcuts for version fields and the attributes map.
///
/// ```dart
/// final config = SuiProtocolConfig.fromJson(rpcResult);
/// print('Protocol v${config.protocolVersion}');
/// print(config.attributes['max_gas']);
/// ```
library;

/// Sui protocol configuration with convenience accessors.
///
/// The protocol config contains version information and a large
/// attributes map of protocol parameters. This class provides
/// typed access to version fields and exposes the raw maps
/// for detailed parameter inspection.
class SuiProtocolConfig {
  /// The complete raw JSON map from the RPC response.
  final Map<String, dynamic> raw;

  /// Creates a [SuiProtocolConfig] wrapping the given [raw] map.
  const SuiProtocolConfig(this.raw);

  /// The current protocol version (as string from RPC).
  String get protocolVersion => raw['protocolVersion'] as String;

  /// The minimum supported protocol version (as string from RPC).
  String get minSupportedProtocolVersion =>
      raw['minSupportedProtocolVersion'] as String;

  /// The maximum supported protocol version (as string from RPC).
  String get maxSupportedProtocolVersion =>
      raw['maxSupportedProtocolVersion'] as String;

  /// The protocol attributes (parameter name -> value).
  Map<String, dynamic> get attributes =>
      (raw['attributes'] as Map<String, dynamic>?) ?? {};

  /// The feature flags (flag name -> enabled).
  Map<String, dynamic> get featureFlags =>
      (raw['featureFlags'] as Map<String, dynamic>?) ?? {};

  /// Parses a [SuiProtocolConfig] from a JSON map returned by Sui RPC.
  factory SuiProtocolConfig.fromJson(Map<String, dynamic> json) {
    return SuiProtocolConfig(json);
  }
}
