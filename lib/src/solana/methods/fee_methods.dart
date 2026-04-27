/// Solana fee and blockhash-related JSON-RPC methods.
///
/// Provides typed access to fee estimation and blockhash RPC methods:
/// `getLatestBlockhash`, `isBlockhashValid`, `getFeeForMessage`,
/// `getMinimumBalanceForRentExemption`, and `getRecentPrioritizationFees`.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to a Solana RPC client class.
///
/// ```dart
/// class MySolanaClient with SolanaFeeMethods {
///   @override
///   final JsonRpcTransport transport;
///   MySolanaClient(this.transport);
/// }
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/blockhash_result.dart';
import '../models/prioritization_fee.dart';
import '../solana_commitment.dart';

/// Solana fee estimation and blockhash methods.
///
/// Covers SOL-30 through SOL-34:
/// - [getLatestBlockhash] — fetch the latest blockhash and its validity window
/// - [isBlockhashValid] — check if a blockhash is still valid
/// - [getFeeForMessage] — estimate fee for a serialized message
/// - [getMinimumBalanceForRentExemption] — minimum lamports for rent exemption
/// - [getRecentPrioritizationFees] — recent prioritization fee samples
mixin SolanaFeeMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Fetches the latest blockhash and its last valid block height.
  ///
  /// Returns a [BlockhashResult] containing the blockhash string and the
  /// block height at which it expires. Uses the RpcResponse wrapper
  /// (`result.value`).
  Future<BlockhashResult> getLatestBlockhash({
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = <dynamic>[];
    if (config.isNotEmpty) params.add(config);

    final result = await transport.send('getLatestBlockhash', params);
    final wrapped = result as Map<String, dynamic>;
    return BlockhashResult.fromJson(wrapped['value'] as Map<String, dynamic>);
  }

  /// Checks whether the given [blockhash] is still valid.
  ///
  /// Returns `true` if the blockhash is valid, `false` if expired.
  /// Uses the RpcResponse wrapper (`result.value`).
  Future<bool> isBlockhashValid(
    String blockhash, {
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = <dynamic>[blockhash];
    if (config.isNotEmpty) params.add(config);

    final result = await transport.send('isBlockhashValid', params);
    final wrapped = result as Map<String, dynamic>;
    return wrapped['value'] as bool;
  }

  /// Estimates the fee for a serialized [base64Message].
  ///
  /// Returns the fee in lamports as a [BigInt], or `null` if the fee
  /// cannot be determined (e.g., invalid message). Uses the RpcResponse
  /// wrapper (`result.value`).
  Future<BigInt?> getFeeForMessage(
    String base64Message, {
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = <dynamic>[base64Message];
    if (config.isNotEmpty) params.add(config);

    final result = await transport.send('getFeeForMessage', params);
    final wrapped = result as Map<String, dynamic>;
    final value = wrapped['value'];
    if (value == null) return null;
    return BigInt.from(value as num);
  }

  /// Returns the minimum balance (in lamports) required to make an account
  /// with [dataLength] bytes rent-exempt.
  ///
  /// This method returns the result directly (not RpcResponse wrapped).
  Future<BigInt> getMinimumBalanceForRentExemption(
    int dataLength, {
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = <dynamic>[dataLength];
    if (config.isNotEmpty) params.add(config);

    final result = await transport.send(
      'getMinimumBalanceForRentExemption',
      params,
    );
    return BigInt.from(result as num);
  }

  /// Returns recent prioritization fee samples from the cluster.
  ///
  /// Optionally filters by a list of account [addresses] (base58-encoded).
  /// When no addresses are provided, returns fees from recent blocks
  /// without filtering.
  Future<List<PrioritizationFee>> getRecentPrioritizationFees({
    List<String>? addresses,
  }) async {
    final params = <dynamic>[];
    if (addresses != null && addresses.isNotEmpty) {
      params.add(addresses);
    }

    final result = await transport.send('getRecentPrioritizationFees', params);
    return (result as List)
        .map((e) => PrioritizationFee.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
