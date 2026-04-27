/// Solana transaction-related JSON-RPC methods.
///
/// Provides typed access to transaction query, send, and simulation
/// RPC methods: `getTransaction`, `getSignaturesForAddress`,
/// `getSignatureStatuses`, `sendTransaction`, and `simulateTransaction`.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to a Solana RPC client class.
///
/// ```dart
/// class MySolanaClient with SolanaTransactionMethods {
///   @override
///   final JsonRpcTransport transport;
///   MySolanaClient(this.transport);
/// }
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/signature_info.dart';
import '../models/signature_status.dart';
import '../models/simulate_result.dart';
import '../models/solana_transaction.dart';
import '../solana_commitment.dart';

/// Solana transaction query, send, and simulation methods.
///
/// Covers SOL-25 through SOL-29:
/// - [getTransaction] — retrieve a parsed transaction by signature
/// - [getSignaturesForAddress] — list signatures for an address
/// - [getSignatureStatuses] — batch-check signature confirmation statuses
/// - [sendTransaction] — submit a pre-signed base64 transaction
/// - [simulateTransaction] — simulate a transaction without submitting
mixin SolanaTransactionMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Retrieves a transaction by its [signature].
  ///
  /// Returns `null` if no transaction with the given signature is found.
  /// Defaults to `maxSupportedTransactionVersion: 0` to support both
  /// legacy and v0 versioned transactions (Solana Pitfall 2).
  ///
  /// The [commitment] parameter defaults to the node's configured default.
  Future<SolanaTransactionResponse?> getTransaction(
    String signature, {
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{
      'encoding': 'jsonParsed',
      'maxSupportedTransactionVersion': 0,
    };
    if (commitment != null) config['commitment'] = commitment.name;

    final result = await transport.send('getTransaction', [signature, config]);
    if (result == null) return null;
    return SolanaTransactionResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves confirmed signatures for transactions involving [address].
  ///
  /// Returns a list of [SignatureInfo] ordered from newest to oldest.
  /// Use [before] and [until] for pagination, and [limit] to cap results
  /// (default 1000, max 1000).
  Future<List<SignatureInfo>> getSignaturesForAddress(
    String address, {
    int? limit,
    String? before,
    String? until,
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (limit != null) config['limit'] = limit;
    if (before != null) config['before'] = before;
    if (until != null) config['until'] = until;
    if (commitment != null) config['commitment'] = commitment.name;

    final params = <dynamic>[address];
    if (config.isNotEmpty) params.add(config);

    final result = await transport.send('getSignaturesForAddress', params);
    return (result as List)
        .map((e) => SignatureInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retrieves the statuses of the given transaction [signatures].
  ///
  /// Returns a list where each element is a [SignatureStatus] or `null`
  /// if the signature is not found. This uses the RpcResponse wrapper
  /// (`result.value`).
  ///
  /// Set [searchTransactionHistory] to `true` to search beyond recent
  /// slots (slower but covers older transactions).
  Future<List<SignatureStatus?>> getSignatureStatuses(
    List<String> signatures, {
    bool? searchTransactionHistory,
  }) async {
    final params = <dynamic>[signatures];
    if (searchTransactionHistory != null) {
      params.add({'searchTransactionHistory': searchTransactionHistory});
    }

    final result = await transport.send('getSignatureStatuses', params);
    final wrapped = result as Map<String, dynamic>;
    final value = wrapped['value'] as List;

    return value.map((e) {
      if (e == null) return null;
      return SignatureStatus.fromJson(e as Map<String, dynamic>);
    }).toList();
  }

  /// Submits a pre-signed transaction encoded as [base64Tx] to the cluster.
  ///
  /// **Important:** This method does NOT perform any signing. It only
  /// forwards the already-signed, base64-encoded transaction body to the
  /// RPC node. All signing must be done externally (e.g., via
  /// `ceres_wallet_core`).
  ///
  /// Returns the first transaction signature (base58-encoded string) as
  /// the transaction identifier.
  ///
  /// The [encoding] defaults to `'base64'` per Solana Pitfall 6 (avoids
  /// base58 default which has performance issues).
  Future<String> sendTransaction(
    String base64Tx, {
    bool? skipPreflight,
    SolanaCommitment? preflightCommitment,
    int? maxRetries,
  }) async {
    final config = <String, dynamic>{'encoding': 'base64'};
    if (skipPreflight != null) config['skipPreflight'] = skipPreflight;
    if (preflightCommitment != null) {
      config['preflightCommitment'] = preflightCommitment.name;
    }
    if (maxRetries != null) config['maxRetries'] = maxRetries;

    final result = await transport.send('sendTransaction', [base64Tx, config]);
    return result as String;
  }

  /// Simulates a transaction without submitting it to the cluster.
  ///
  /// Takes a [base64Tx] encoded transaction and returns a [SimulateResult]
  /// with execution logs, error info, and compute units consumed.
  ///
  /// Uses the RpcResponse wrapper (`result.value`).
  Future<SimulateResult> simulateTransaction(
    String base64Tx, {
    SolanaCommitment? commitment,
    bool? sigVerify,
    bool? replaceRecentBlockhash,
    List<String>? accounts,
  }) async {
    final config = <String, dynamic>{'encoding': 'base64'};
    if (commitment != null) config['commitment'] = commitment.name;
    if (sigVerify != null) config['sigVerify'] = sigVerify;
    if (replaceRecentBlockhash != null) {
      config['replaceRecentBlockhash'] = replaceRecentBlockhash;
    }
    if (accounts != null) {
      config['accounts'] = {'encoding': 'base64', 'addresses': accounts};
    }

    final result = await transport.send('simulateTransaction', [
      base64Tx,
      config,
    ]);
    final wrapped = result as Map<String, dynamic>;
    return SimulateResult.fromJson(wrapped['value'] as Map<String, dynamic>);
  }
}
