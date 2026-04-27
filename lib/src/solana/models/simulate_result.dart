/// Solana transaction simulation result model.
///
/// Represents the result from `simulateTransaction` RPC method.
///
/// ```dart
/// final result = SimulateResult.fromJson(rpcResponse['result']['value']);
/// if (result.err != null) print('Simulation failed: ${result.err}');
/// print('Units consumed: ${result.unitsConsumed}');
/// ```
library;

/// Parsed simulation result from a Solana RPC response.
class SimulateResult {
  /// The error if the simulation failed, or `null` if successful.
  final dynamic err;

  /// The log messages produced by the simulation, if available.
  final List<String>? logs;

  /// The number of compute units consumed, if available.
  ///
  /// Stored as [BigInt] for consistency with other u64 fields.
  final BigInt? unitsConsumed;

  /// The return data from the simulated transaction, if any.
  final Map<String, dynamic>? returnData;

  /// Creates a [SimulateResult] with the given field values.
  const SimulateResult({
    this.err,
    this.logs,
    this.unitsConsumed,
    this.returnData,
  });

  /// Parses a [SimulateResult] from a JSON map returned by Solana RPC.
  factory SimulateResult.fromJson(Map<String, dynamic> json) {
    return SimulateResult(
      err: json['err'],
      logs: (json['logs'] as List<dynamic>?)?.cast<String>(),
      unitsConsumed: json['unitsConsumed'] != null
          ? BigInt.from(json['unitsConsumed'] as num)
          : null,
      returnData: json['returnData'] as Map<String, dynamic>?,
    );
  }
}
