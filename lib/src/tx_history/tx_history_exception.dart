/// Exception hierarchy for the tx_history extension layer.
///
/// All tx_history-layer errors extend [RpcException] (LD-7) so callers
/// that already use `catch (RpcException)` keep working unchanged.
library;

import '../core/rpc_exception.dart';

/// Base exception for the tx_history extension layer.
///
/// Subclasses use the `-2000` block of error codes to avoid colliding
/// with JSON-RPC standard codes or the existing transport-level codes
/// (`-1` for timeout, HTTP status codes for [RpcHttpException]).
class TxHistoryException extends RpcException {
  /// Creates a [TxHistoryException].
  const TxHistoryException({
    required super.code,
    required super.message,
    super.data,
  });
}

/// Thrown when a cursor passed to [TxHistoryProvider.listTransactions] is
/// malformed, expired, or belongs to a different chain than the provider
/// expects (e.g. a [SolanaCursor] handed to an EVM Blockscout provider).
///
/// Carries the fixed code `-2001` (T-11-03 mitigation — surfaces the
/// runtime branch of the wrong-chain-cursor guard).
class InvalidCursorException extends TxHistoryException {
  /// Creates an [InvalidCursorException] with the given [message].
  const InvalidCursorException({required super.message}) : super(code: -2001);
}

/// Thrown when a REST history endpoint returns a structured error
/// envelope (e.g. Etherscan `{"status":"0","message":"NOTOK","result":...}`)
/// or any other provider-specific failure that is not a transport-level
/// timeout / HTTP error.
///
/// Uses code `-2002`. The [endpoint] field is run through [_redactApiKey]
/// at construction time so error messages, stack traces, and logs cannot
/// leak api keys (T-11-01 mitigation — quota theft via leaked logs).
class TxHistoryApiException extends TxHistoryException {
  /// Endpoint URL the error originated from, with api keys redacted.
  /// `null` when the caller did not supply one.
  final String? endpoint;

  /// Creates a [TxHistoryApiException].
  ///
  /// If [endpoint] is supplied, any `apikey=` / `api_key=` / `api-key=` /
  /// `key=` query parameter value is replaced with `REDACTED` before being
  /// stored. This is irreversible — callers must keep the original URL
  /// outside of the exception if they need it for retries.
  TxHistoryApiException({
    required super.code,
    required super.message,
    String? endpoint,
    super.data,
  }) : endpoint = endpoint == null ? null : _redactApiKey(endpoint);
}

/// Strips api-key query parameter values from a URL.
///
/// Matches `apikey=`, `api_key=`, `api-key=`, and bare `key=` (all
/// case-insensitive) and replaces the value with `REDACTED`. The
/// parameter name is preserved verbatim so log readers can still
/// see _which_ key was redacted.
String _redactApiKey(String input) {
  return input.replaceAllMapped(
    RegExp(r'(api[_-]?key|apikey|key)=[^&\s]+', caseSensitive: false),
    (m) => '${m.group(1)}=REDACTED',
  );
}
