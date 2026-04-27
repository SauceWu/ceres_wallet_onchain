/// Sui transaction-related RPC methods.
///
/// Provides methods for querying, executing, and simulating transactions
/// on the Sui network via JSON-RPC.
///
/// All 7 methods correspond to SUI-01 through SUI-07:
/// - [getTransactionBlock] — query a single transaction by digest
/// - [multiGetTransactionBlocks] — batch query multiple transactions
/// - [queryTransactionBlocks] — paginated query with filters
/// - [getTotalTransactionBlocks] — total transaction count
/// - [dryRunTransactionBlock] — simulate transaction without execution
/// - [devInspectTransactionBlock] — developer inspection of transaction
/// - [executeTransactionBlock] — submit signed transaction (no signing)
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_dry_run_result.dart';
import '../models/sui_options.dart';
import '../models/sui_paginated.dart';
import '../models/sui_transaction_block_response.dart';

/// Transaction-related Sui RPC methods.
///
/// Requires a [transport] accessor for sending JSON-RPC requests.
/// Mix into a Sui client class that provides the transport.
mixin SuiTransactionMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the transaction block response for the given [digest].
  ///
  /// Calls `sui_getTransactionBlock`. The [options] parameter controls
  /// which fields are included in the response (effects, events, etc.).
  ///
  /// ```dart
  /// final tx = await client.getTransactionBlock(
  ///   'DigestHex123',
  ///   options: SuiTransactionBlockResponseOptions(showEffects: true),
  /// );
  /// print(tx.digest);
  /// ```
  Future<SuiTransactionBlockResponse> getTransactionBlock(
    String digest, {
    SuiTransactionBlockResponseOptions? options,
  }) async {
    final result = await transport.send('sui_getTransactionBlock', [
      digest,
      options?.toJson(),
    ]);
    return SuiTransactionBlockResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Returns transaction block responses for multiple [digests] in one call.
  ///
  /// Calls `sui_multiGetTransactionBlocks`.
  ///
  /// ```dart
  /// final txs = await client.multiGetTransactionBlocks(
  ///   ['Digest1', 'Digest2'],
  /// );
  /// ```
  Future<List<SuiTransactionBlockResponse>> multiGetTransactionBlocks(
    List<String> digests, {
    SuiTransactionBlockResponseOptions? options,
  }) async {
    final result = await transport.send('sui_multiGetTransactionBlocks', [
      digests,
      options?.toJson(),
    ]);
    return (result as List<dynamic>)
        .map(
          (item) => SuiTransactionBlockResponse.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Queries transaction blocks with optional [filter], pagination, and ordering.
  ///
  /// Calls `sui_queryTransactionBlocks`. Parameters are packed into a single
  /// query object as required by the Sui JSON-RPC API.
  ///
  /// ```dart
  /// final page = await client.queryTransactionBlocks(
  ///   filter: {'FromAddress': '0xabc'},
  ///   limit: 10,
  /// );
  /// for (final tx in page.data) {
  ///   print(tx.digest);
  /// }
  /// ```
  Future<SuiPaginatedResponse<SuiTransactionBlockResponse>>
  queryTransactionBlocks({
    Map<String, dynamic>? filter,
    SuiTransactionBlockResponseOptions? options,
    String? cursor,
    int? limit,
    bool descendingOrder = false,
  }) async {
    final queryParam = <String, dynamic>{
      'filter': filter,
      'options': options?.toJson(),
      'cursor': cursor,
      'limit': limit,
      'order': descendingOrder ? 'descending' : 'ascending',
    };
    final result = await transport.send('sui_queryTransactionBlocks', [
      queryParam,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) =>
          SuiTransactionBlockResponse.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns the total number of transaction blocks on the network.
  ///
  /// Calls `sui_getTotalTransactionBlocks`. Returns [BigInt] to safely
  /// represent the potentially large count.
  Future<BigInt> getTotalTransactionBlocks() async {
    final result = await transport.send('sui_getTotalTransactionBlocks', []);
    return BigInt.parse(result as String);
  }

  /// Dry-runs a transaction block without executing it on-chain.
  ///
  /// Calls `sui_dryRunTransactionBlock` with [txBytes] (base64-encoded).
  /// Returns a [SuiDryRunResult] containing simulated effects, events,
  /// and balance changes.
  ///
  /// ```dart
  /// final result = await client.dryRunTransactionBlock('base64Tx==');
  /// if (result.effects.status.isSuccess) {
  ///   print('Simulation succeeded');
  /// }
  /// ```
  Future<SuiDryRunResult> dryRunTransactionBlock(String txBytes) async {
    final result = await transport.send('sui_dryRunTransactionBlock', [
      txBytes,
    ]);
    return SuiDryRunResult.fromJson(result as Map<String, dynamic>);
  }

  /// Runs a developer inspection on a transaction block.
  ///
  /// Calls `sui_devInspectTransactionBlock`. Returns the raw response
  /// map since DevInspectResults has a complex structure that varies.
  ///
  /// Optional [gasPrice] and [epoch] allow overriding execution context.
  Future<Map<String, dynamic>> devInspectTransactionBlock(
    String sender,
    String txBytes, {
    BigInt? gasPrice,
    String? epoch,
  }) async {
    final result = await transport.send('sui_devInspectTransactionBlock', [
      sender,
      txBytes,
      gasPrice?.toString(),
      epoch,
    ]);
    return result as Map<String, dynamic>;
  }

  /// Executes a signed transaction block on the Sui network.
  ///
  /// Calls `sui_executeTransactionBlock` with [txBytes] and [signatures]
  /// passed through as-is. **This method does NOT perform any signing** —
  /// the caller is responsible for providing pre-signed data.
  ///
  /// The `requestType` is fixed to `"WaitForLocalExecution"` to ensure
  /// the response includes execution results.
  ///
  /// ```dart
  /// final result = await client.executeTransactionBlock(
  ///   txBytesBase64,
  ///   [signatureBase64],
  ///   options: SuiTransactionBlockResponseOptions(showEffects: true),
  /// );
  /// print(result.digest);
  /// ```
  Future<SuiTransactionBlockResponse> executeTransactionBlock(
    String txBytes,
    List<String> signatures, {
    SuiTransactionBlockResponseOptions? options,
  }) async {
    final result = await transport.send('sui_executeTransactionBlock', [
      txBytes,
      signatures,
      options?.toJson(),
      'WaitForLocalExecution',
    ]);
    return SuiTransactionBlockResponse.fromJson(result as Map<String, dynamic>);
  }
}
