/// Tron HTTP API error detection and message decoding utilities.
///
/// Tron's HTTP API signals errors in two ways:
///
/// 1. **Top-level `Error` field:** `{"Error": "Account not found"}`
/// 2. **Nested `result.result == false`:** Contains `code` and hex-encoded
///    `message` fields.
///
/// These utilities detect both patterns and convert them to [RpcException].
///
/// ```dart
/// final json = await transport.post('/wallet/getaccount', body);
/// checkTronError(json); // throws if error detected
/// ```
library;

import 'dart:convert';

import 'package:blockchain_utils/utils/utils.dart';

import '../core/rpc_exception.dart';

/// Tron-specific error code used for [RpcException.code].
///
/// Distinguishes Tron HTTP API errors from JSON-RPC errors (which use
/// standard JSON-RPC 2.0 codes) and timeout errors (code `-1`).
const int _tronErrorCode = -2;

/// Checks a Tron HTTP API response for error indicators.
///
/// Inspects [json] for:
/// - A top-level `"Error"` key (simple error string)
/// - A nested `result.result == false` pattern with `code` and
///   hex-encoded `message`
///
/// Throws [RpcException] with code `-2` if an error is detected.
/// Does nothing if the response indicates success.
void checkTronError(Map<String, dynamic> json) {
  // Pattern 1: top-level Error field
  if (json.containsKey('Error')) {
    throw RpcException(code: _tronErrorCode, message: json['Error'] as String);
  }

  // Pattern 2: result.result == false
  final result = json['result'];
  if (result is Map<String, dynamic> && result['result'] == false) {
    final code = result['code'] as String? ?? 'UNKNOWN_ERROR';
    final hexMsg = result['message'] as String? ?? '';
    final decoded = decodeTronErrorMessage(hexMsg);
    throw RpcException(
      code: _tronErrorCode,
      message: '$code: $decoded',
      data: result,
    );
  }
}

/// Decodes a hex-encoded UTF-8 error message from Tron's API.
///
/// Tron encodes error detail messages as hex strings of UTF-8 bytes.
/// This function converts them back to readable text.
///
/// Returns [hexMsg] unchanged if it is empty or cannot be decoded.
///
/// ```dart
/// decodeTronErrorMessage('62616c616e6365206973206e6f742073756666696369656e74');
/// // => 'balance is not sufficient'
/// ```
String decodeTronErrorMessage(String hexMsg) {
  if (hexMsg.isEmpty) return '';
  try {
    final bytes = BytesUtils.fromHexString(hexMsg);
    return utf8.decode(bytes);
  } catch (_) {
    return hexMsg;
  }
}
