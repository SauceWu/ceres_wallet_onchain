/// Sui event query RPC methods.
///
/// Provides methods for querying events by transaction digest
/// and by event filter with pagination.
///
/// Contains 2 methods: getEvents, queryEvents.
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_event.dart';
import '../models/sui_paginated.dart';

/// Event query RPC methods for Sui.
///
/// Requires access to a [JsonRpcTransport] via the `transport` getter.
mixin SuiEventMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the events for a given transaction digest.
  ///
  /// Calls `sui_getEvents` with [transactionDigest]. Returns a list of
  /// [SuiEvent] objects emitted during that transaction.
  ///
  /// ```dart
  /// final events = await client.getEvents('txDigest123');
  /// for (final e in events) {
  ///   print('${e.type}: ${e.parsedJson}');
  /// }
  /// ```
  Future<List<SuiEvent>> getEvents(String transactionDigest) async {
    final result = await transport.send('sui_getEvents', [transactionDigest]);
    return (result as List)
        .map((e) => SuiEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Queries events with a filter and optional pagination.
  ///
  /// Calls `suix_queryEvents` with the given [filter] and pagination
  /// parameters. Returns a paginated response of [SuiEvent] objects.
  ///
  /// Common filters:
  /// - `{'Package': '0x2'}` — events from a package
  /// - `{'Sender': '0xabc'}` — events from a sender
  /// - `{'MoveEventType': '0x2::coin::CoinEvent'}` — specific event type
  ///
  /// ```dart
  /// final page = await client.queryEvents(
  ///   filter: {'Package': '0x2'},
  ///   limit: 10,
  /// );
  /// ```
  Future<SuiPaginatedResponse<SuiEvent>> queryEvents({
    required Map<String, dynamic> filter,
    Map<String, dynamic>? cursor,
    int? limit,
    bool descendingOrder = false,
  }) async {
    final result = await transport.send('suix_queryEvents', [
      filter,
      cursor,
      limit,
      descendingOrder,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiEvent.fromJson(item as Map<String, dynamic>),
    );
  }
}
