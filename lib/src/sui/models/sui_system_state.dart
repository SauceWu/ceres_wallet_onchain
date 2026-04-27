/// Sui system state summary model.
///
/// Wraps the large JSON map returned by `suix_getLatestSuiSystemState`
/// and provides typed shortcuts for commonly accessed fields.
///
/// ```dart
/// final state = SuiSystemState.fromJson(rpcResult);
/// print('Epoch: ${state.epoch}');
/// print('Gas price: ${state.referenceGasPrice}');
/// // Access any field via raw map:
/// print(state.raw['validatorsAtRisk']);
/// ```
library;

/// Sui system state summary with convenience accessors.
///
/// The Sui system state contains dozens of fields that change across
/// protocol versions. Rather than modeling every field, this class
/// exposes the most commonly needed ones as typed properties and
/// provides the full [raw] map for everything else.
class SuiSystemState {
  /// The complete raw JSON map from the RPC response.
  final Map<String, dynamic> raw;

  /// Creates a [SuiSystemState] wrapping the given [raw] map.
  const SuiSystemState(this.raw);

  /// The current epoch number (as string from RPC).
  String get epoch => raw['epoch'] as String;

  /// The current protocol version (as string from RPC).
  String get protocolVersion => raw['protocolVersion'] as String;

  /// The system state version (as string from RPC).
  String get systemStateVersion => raw['systemStateVersion'] as String;

  /// The reference gas price for the current epoch.
  BigInt get referenceGasPrice =>
      BigInt.parse(raw['referenceGasPrice'].toString());

  /// Whether safe mode is active (emergency protocol state).
  bool get safeMode => raw['safeMode'] as bool;

  /// Parses a [SuiSystemState] from a JSON map returned by Sui RPC.
  factory SuiSystemState.fromJson(Map<String, dynamic> json) {
    return SuiSystemState(json);
  }
}
