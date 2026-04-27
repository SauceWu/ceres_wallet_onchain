/// Sui extended (`suix_`) RPC methods for dynamic fields and name services.
///
/// Provides methods for querying dynamic fields on objects and resolving
/// SuiNS (Sui Name Service) names and addresses.
///
/// ```dart
/// class MySuiClient with SuiExtendedMethods {
///   @override
///   final JsonRpcTransport transport;
///   MySuiClient(this.transport);
/// }
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_dynamic_field.dart';
import '../models/sui_object_response.dart';
import '../models/sui_paginated.dart';
import '../sui_address.dart';

/// Mixin providing Sui `suix_` namespace extended RPC methods.
///
/// Covers dynamic field queries and SuiNS name service resolution.
/// Requires [transport] to be provided by the implementing class.
mixin SuiExtendedMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the dynamic fields for the given [parentObjectId].
  ///
  /// Sends `suix_getDynamicFields`. Results are paginated; pass [cursor]
  /// from a previous response's `nextCursor` to fetch subsequent pages.
  /// [limit] controls the maximum number of items per page.
  Future<SuiPaginatedDynamicFields> getDynamicFields(
    String parentObjectId, {
    String? cursor,
    int? limit,
  }) async {
    final result = await transport.send('suix_getDynamicFields', [
      parentObjectId,
      cursor,
      limit,
    ]);
    return SuiPaginatedDynamicFields.fromJson(
      result as Map<String, dynamic>,
      (item) => SuiDynamicFieldInfo.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Returns the object data for a specific dynamic field on [parentObjectId].
  ///
  /// Sends `suix_getDynamicFieldObject`. The [name] parameter is a typed
  /// value map with `type` and `value` keys, e.g.:
  /// ```dart
  /// {'type': 'u64', 'value': '1'}
  /// ```
  Future<SuiObjectResponse> getDynamicFieldObject(
    String parentObjectId,
    Map<String, dynamic> name,
  ) async {
    final result = await transport.send('suix_getDynamicFieldObject', [
      parentObjectId,
      name,
    ]);
    return SuiObjectResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Resolves a SuiNS domain name to a Sui address.
  ///
  /// Sends `suix_resolveNameServiceAddress`. Returns the resolved address
  /// as a hex string, or `null` if the domain name does not exist or has
  /// no associated address.
  Future<String?> resolveNameServiceAddress(String name) async {
    final result = await transport.send('suix_resolveNameServiceAddress', [
      name,
    ]);
    return result as String?;
  }

  /// Returns the SuiNS names owned by the given [address].
  ///
  /// Sends `suix_resolveNameServiceNames`. Results are paginated; pass
  /// [cursor] from a previous response's `nextCursor` to fetch subsequent
  /// pages. [limit] controls the maximum number of items per page.
  Future<SuiPaginatedNames> resolveNameServiceNames(
    SuiAddress address, {
    String? cursor,
    int? limit,
  }) async {
    final result = await transport.send('suix_resolveNameServiceNames', [
      address.toHex(),
      cursor,
      limit,
    ]);
    return SuiPaginatedNames.fromJson(
      result as Map<String, dynamic>,
      (item) => item as String,
    );
  }
}
