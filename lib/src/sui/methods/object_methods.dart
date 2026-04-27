/// Sui object-related RPC methods.
///
/// Provides methods for querying current and historical object state
/// on the Sui network via JSON-RPC.
///
/// All 4 methods correspond to SUI-08 through SUI-11:
/// - [getObject] — query a single object by ID
/// - [multiGetObjects] — batch query multiple objects
/// - [tryGetPastObject] — query a specific version of an object
/// - [tryMultiGetPastObjects] — batch query past object versions
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_object_response.dart';
import '../models/sui_options.dart';

/// Object-related Sui RPC methods.
///
/// Requires a [transport] accessor for sending JSON-RPC requests.
/// Mix into a Sui client class that provides the transport.
mixin SuiObjectMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the object response for the given [objectId].
  ///
  /// Calls `sui_getObject`. The [options] parameter controls which
  /// fields are included in the response (content, owner, type, etc.).
  ///
  /// ```dart
  /// final obj = await client.getObject(
  ///   '0x2',
  ///   options: SuiObjectDataOptions(showContent: true),
  /// );
  /// if (obj.data != null) print(obj.data!.objectId);
  /// ```
  Future<SuiObjectResponse> getObject(
    String objectId, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await transport.send('sui_getObject', [
      objectId,
      options?.toJson(),
    ]);
    return SuiObjectResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Returns object responses for multiple [objectIds] in one call.
  ///
  /// Calls `sui_multiGetObjects`. Each element may contain data or error.
  ///
  /// ```dart
  /// final objects = await client.multiGetObjects(['0x2', '0x3']);
  /// ```
  Future<List<SuiObjectResponse>> multiGetObjects(
    List<String> objectIds, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await transport.send('sui_multiGetObjects', [
      objectIds,
      options?.toJson(),
    ]);
    return (result as List<dynamic>)
        .map((item) => SuiObjectResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Attempts to retrieve a past version of an object.
  ///
  /// Calls `sui_tryGetPastObject` with the [objectId] and [version].
  /// Returns a [SuiPastObjectResponse] with a status indicating whether
  /// the version was found.
  ///
  /// ```dart
  /// final past = await client.tryGetPastObject('0x2', 5);
  /// if (past.status == 'VersionFound') {
  ///   print(past.details!.objectId);
  /// }
  /// ```
  Future<SuiPastObjectResponse> tryGetPastObject(
    String objectId,
    int version, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await transport.send('sui_tryGetPastObject', [
      objectId,
      version,
      options?.toJson(),
    ]);
    return SuiPastObjectResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Attempts to retrieve past versions of multiple objects.
  ///
  /// Calls `sui_tryMultiGetPastObjects`. Each element in [objects]
  /// should be a map with `objectId` and `version` keys:
  /// ```json
  /// [{"objectId": "0x2", "version": 1}, ...]
  /// ```
  Future<List<SuiPastObjectResponse>> tryMultiGetPastObjects(
    List<Map<String, dynamic>> objects, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await transport.send('sui_tryMultiGetPastObjects', [
      objects,
      options?.toJson(),
    ]);
    return (result as List<dynamic>)
        .map(
          (item) =>
              SuiPastObjectResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
