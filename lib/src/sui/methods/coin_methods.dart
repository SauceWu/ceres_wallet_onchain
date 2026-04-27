/// Sui coin and asset query RPC methods.
///
/// Provides methods for querying coin balances, coin objects, metadata,
/// total supply, and owned objects via the `suix_*` extended API.
///
/// ```dart
/// final balance = await client.getBalance(owner);
/// print('SUI balance: ${balance.totalBalance}');
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_balance.dart';
import '../models/sui_coin.dart';
import '../models/sui_coin_metadata.dart';
import '../models/sui_object_response.dart';
import '../models/sui_options.dart';
import '../models/sui_paginated.dart';
import '../sui_address.dart';

/// Coin and asset query methods for the Sui RPC client.
///
/// Implements 7 `suix_*` extended methods for querying balances,
/// coin objects, metadata, supply, and owned objects.
mixin SuiCoinMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns objects owned by [owner], optionally filtered.
  ///
  /// Calls `suix_getOwnedObjects`. The [filter] map restricts which
  /// objects are returned (e.g., `{'StructType': '0x2::coin::Coin<0x2::sui::SUI>'}`).
  /// The [options] control which fields are included in each object response.
  ///
  /// ```dart
  /// final page = await client.getOwnedObjects(
  ///   owner,
  ///   filter: {'StructType': '0x2::coin::Coin<0x2::sui::SUI>'},
  /// );
  /// ```
  Future<SuiPaginatedResponse<SuiObjectResponse>> getOwnedObjects(
    SuiAddress owner, {
    Map<String, dynamic>? filter,
    SuiObjectDataOptions? options,
    String? cursor,
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (filter != null) query['filter'] = filter;
    if (options != null) query['options'] = options.toJson();

    final result = await transport.send('suix_getOwnedObjects', [
      owner.toHex(),
      query,
      cursor,
      limit,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiObjectResponse.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns the balance of [coinType] for [owner].
  ///
  /// Calls `suix_getBalance`. When [coinType] is omitted, the Sui node
  /// defaults to `0x2::sui::SUI`.
  ///
  /// ```dart
  /// final balance = await client.getBalance(owner);
  /// print('SUI: ${balance.totalBalance}');
  /// ```
  Future<SuiBalance> getBalance(SuiAddress owner, {String? coinType}) async {
    final result = await transport.send('suix_getBalance', [
      owner.toHex(),
      coinType,
    ]);
    return SuiBalance.fromJson(result as Map<String, dynamic>);
  }

  /// Returns all coin balances for [owner].
  ///
  /// Calls `suix_getAllBalances`. Returns one [SuiBalance] per coin type
  /// held by the address.
  ///
  /// ```dart
  /// final balances = await client.getAllBalances(owner);
  /// for (final b in balances) {
  ///   print('${b.coinType}: ${b.totalBalance}');
  /// }
  /// ```
  Future<List<SuiBalance>> getAllBalances(SuiAddress owner) async {
    final result = await transport.send('suix_getAllBalances', [owner.toHex()]);
    return (result as List<dynamic>)
        .map((e) => SuiBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns coin objects of [coinType] owned by [owner].
  ///
  /// Calls `suix_getCoins`. Results are paginated; use [cursor] and
  /// [limit] for pagination control. When [coinType] is omitted, the
  /// Sui node defaults to `0x2::sui::SUI`.
  ///
  /// ```dart
  /// final page = await client.getCoins(owner, limit: 50);
  /// ```
  Future<SuiPaginatedResponse<SuiCoin>> getCoins(
    SuiAddress owner, {
    String? coinType,
    String? cursor,
    int? limit,
  }) async {
    final result = await transport.send('suix_getCoins', [
      owner.toHex(),
      coinType,
      cursor,
      limit,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiCoin.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns all coin objects owned by [owner], regardless of type.
  ///
  /// Calls `suix_getAllCoins`. Results are paginated.
  ///
  /// ```dart
  /// final page = await client.getAllCoins(owner);
  /// ```
  Future<SuiPaginatedResponse<SuiCoin>> getAllCoins(
    SuiAddress owner, {
    String? cursor,
    int? limit,
  }) async {
    final result = await transport.send('suix_getAllCoins', [
      owner.toHex(),
      cursor,
      limit,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiCoin.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns metadata for [coinType], or `null` if none exists.
  ///
  /// Calls `suix_getCoinMetadata`. Returns `null` when the coin type
  /// has no registered metadata on-chain.
  ///
  /// ```dart
  /// final meta = await client.getCoinMetadata('0x2::sui::SUI');
  /// if (meta != null) print('Decimals: ${meta.decimals}');
  /// ```
  Future<SuiCoinMetadata?> getCoinMetadata(String coinType) async {
    final result = await transport.send('suix_getCoinMetadata', [coinType]);
    if (result == null) return null;
    return SuiCoinMetadata.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the total supply of [coinType].
  ///
  /// Calls `suix_getTotalSupply`.
  ///
  /// ```dart
  /// final supply = await client.getTotalSupply('0x2::sui::SUI');
  /// print('Total: ${supply.value}');
  /// ```
  Future<SuiSupply> getTotalSupply(String coinType) async {
    final result = await transport.send('suix_getTotalSupply', [coinType]);
    return SuiSupply.fromJson(result as Map<String, dynamic>);
  }
}
