/// Result of `broadcasttransaction` API call.
///
/// ```dart
/// final result = TronBroadcastResult.fromJson(responseJson);
/// if (result.result) {
///   print('Broadcast success: ${result.txid}');
/// } else {
///   print('Broadcast failed: ${result.code} - ${result.message}');
/// }
/// ```
class TronBroadcastResult {
  /// Whether the broadcast was accepted by the node.
  final bool result;

  /// Transaction hash if successful.
  final String? txid;

  /// Error code if failed (e.g., `SIGERROR`, `DUP_TRANSACTION_ERROR`).
  final String? code;

  /// Error message (hex-encoded; callers may use `decodeTronErrorMessage`).
  final String? message;

  /// Creates a [TronBroadcastResult].
  const TronBroadcastResult({
    required this.result,
    this.txid,
    this.code,
    this.message,
  });

  /// Parses a [TronBroadcastResult] from the API response.
  factory TronBroadcastResult.fromJson(Map<String, dynamic> json) {
    return TronBroadcastResult(
      result: json['result'] == true,
      txid: json['txid'] as String?,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}
