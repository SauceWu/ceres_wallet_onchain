/// Sui chain information and checkpoint RPC methods.
///
/// Provides methods for querying checkpoints, chain identifier,
/// protocol configuration, system state, and reference gas price.
///
/// Contains 7 methods: getLatestCheckpointSequenceNumber, getCheckpoint,
/// getCheckpoints, getChainIdentifier, getProtocolConfig,
/// getLatestSuiSystemState, getReferenceGasPrice.
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_checkpoint.dart';
import '../models/sui_paginated.dart';
import '../models/sui_protocol_config.dart';
import '../models/sui_system_state.dart';

/// Chain information and checkpoint RPC methods for Sui.
///
/// Requires access to a [JsonRpcTransport] via the `transport` getter.
mixin SuiChainMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the sequence number of the latest checkpoint.
  ///
  /// Calls `sui_getLatestCheckpointSequenceNumber`. Returns the sequence
  /// number as a [BigInt].
  ///
  /// ```dart
  /// final seq = await client.getLatestCheckpointSequenceNumber();
  /// print('Latest checkpoint: $seq');
  /// ```
  Future<BigInt> getLatestCheckpointSequenceNumber() async {
    final result = await transport.send(
      'sui_getLatestCheckpointSequenceNumber',
    );
    return BigInt.parse(result as String);
  }

  /// Returns a checkpoint by its sequence number or digest.
  ///
  /// Calls `sui_getCheckpoint` with [id] which can be either a checkpoint
  /// sequence number (as string) or a checkpoint digest.
  ///
  /// ```dart
  /// final cp = await client.getCheckpoint('1000');
  /// print('Epoch: ${cp.epoch}, digest: ${cp.digest}');
  /// ```
  Future<SuiCheckpoint> getCheckpoint(String id) async {
    final result = await transport.send('sui_getCheckpoint', [id]);
    return SuiCheckpoint.fromJson(result as Map<String, dynamic>);
  }

  /// Returns a paginated list of checkpoints.
  ///
  /// Calls `sui_getCheckpoints` with optional pagination parameters.
  ///
  /// - [cursor]: An optional paging cursor. If provided, the query will
  ///   start from the next item after the specified cursor.
  /// - [limit]: Maximum number of items per page.
  /// - [descendingOrder]: Whether to return results in descending order.
  ///
  /// ```dart
  /// final page = await client.getCheckpoints(limit: 10);
  /// for (final cp in page.data) {
  ///   print('${cp.sequenceNumber}: ${cp.digest}');
  /// }
  /// ```
  Future<SuiPaginatedResponse<SuiCheckpoint>> getCheckpoints({
    String? cursor,
    int? limit,
    bool descendingOrder = false,
  }) async {
    final result = await transport.send('sui_getCheckpoints', [
      cursor,
      limit,
      descendingOrder,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiCheckpoint.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns the chain identifier (first 4 bytes of genesis checkpoint digest).
  ///
  /// Calls `sui_getChainIdentifier`. Returns a hex string.
  ///
  /// ```dart
  /// final chainId = await client.getChainIdentifier();
  /// print('Chain: $chainId'); // e.g. "4c78adac"
  /// ```
  Future<String> getChainIdentifier() async {
    final result = await transport.send('sui_getChainIdentifier');
    return result as String;
  }

  /// Returns the protocol config table for the given version.
  ///
  /// Calls `sui_getProtocolConfig`. If [version] is `null`, returns the
  /// config for the current protocol version.
  ///
  /// ```dart
  /// final config = await client.getProtocolConfig();
  /// print('Protocol v${config.protocolVersion}');
  /// ```
  Future<SuiProtocolConfig> getProtocolConfig({BigInt? version}) async {
    final params = version != null
        ? <dynamic>[version.toString()]
        : <dynamic>[];
    final result = await transport.send('sui_getProtocolConfig', params);
    return SuiProtocolConfig.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the latest Sui system state object.
  ///
  /// Calls `suix_getLatestSuiSystemState`. Returns a [SuiSystemState]
  /// with convenience accessors for epoch, protocol version, gas price, etc.
  ///
  /// ```dart
  /// final state = await client.getLatestSuiSystemState();
  /// print('Epoch: ${state.epoch}, gas: ${state.referenceGasPrice}');
  /// ```
  Future<SuiSystemState> getLatestSuiSystemState() async {
    final result = await transport.send('suix_getLatestSuiSystemState');
    return SuiSystemState.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the reference gas price for the current epoch.
  ///
  /// Calls `suix_getReferenceGasPrice`. Returns the price as [BigInt].
  ///
  /// ```dart
  /// final gasPrice = await client.getReferenceGasPrice();
  /// print('Gas price: $gasPrice MIST');
  /// ```
  Future<BigInt> getReferenceGasPrice() async {
    final result = await transport.send('suix_getReferenceGasPrice');
    return BigInt.parse(result as String);
  }
}
