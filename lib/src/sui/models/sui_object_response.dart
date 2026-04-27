/// Sui object response and past object response models.
///
/// [SuiObjectResponse] wraps the result of `sui_getObject`, containing
/// either a [SuiObjectData] on success or a [SuiObjectResponseError]
/// when the object cannot be found.
///
/// [SuiPastObjectResponse] wraps the result of `sui_tryGetPastObject`,
/// containing a status string and optional object details.
///
/// ```dart
/// final resp = SuiObjectResponse.fromJson(rpcResult);
/// if (resp.data != null) {
///   print(resp.data!.objectId);
/// } else {
///   print('Error: ${resp.error!.code}');
/// }
/// ```
library;

import 'sui_object_data.dart';

/// Response from `sui_getObject` and similar object query methods.
class SuiObjectResponse {
  /// The object data, present when the query succeeds.
  final SuiObjectData? data;

  /// The error information, present when the object cannot be found.
  final SuiObjectResponseError? error;

  /// Creates a [SuiObjectResponse] with optional [data] and [error].
  const SuiObjectResponse({this.data, this.error});

  /// Parses a [SuiObjectResponse] from a JSON map returned by Sui RPC.
  factory SuiObjectResponse.fromJson(Map<String, dynamic> json) {
    return SuiObjectResponse(
      data: json['data'] != null
          ? SuiObjectData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? SuiObjectResponseError.fromJson(
              json['error'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Error details when an object query fails.
class SuiObjectResponseError {
  /// The error code (e.g., `notExists`, `deleted`, `versionNotFound`).
  final String code;

  /// The object ID that was queried, if available.
  final String? objectId;

  /// The version that was queried, if available.
  final BigInt? version;

  /// The digest associated with the error, if available.
  final String? digest;

  /// Creates a [SuiObjectResponseError] with the given fields.
  const SuiObjectResponseError({
    required this.code,
    this.objectId,
    this.version,
    this.digest,
  });

  /// Parses a [SuiObjectResponseError] from a JSON map.
  factory SuiObjectResponseError.fromJson(Map<String, dynamic> json) {
    return SuiObjectResponseError(
      code: json['code'] as String,
      objectId: json['object_id'] as String?,
      version: json['version'] != null
          ? BigInt.parse(json['version'].toString())
          : null,
      digest: json['digest'] as String?,
    );
  }
}

/// Response from `sui_tryGetPastObject`.
class SuiPastObjectResponse {
  /// The status of the past object query (e.g., `VersionFound`,
  /// `ObjectNotExists`, `VersionNotFound`, `VersionTooHigh`).
  final String status;

  /// The object data, present when `status` is `VersionFound`.
  final SuiObjectData? details;

  /// Creates a [SuiPastObjectResponse] with the given [status] and
  /// optional [details].
  const SuiPastObjectResponse({required this.status, this.details});

  /// Parses a [SuiPastObjectResponse] from a JSON map returned by Sui RPC.
  factory SuiPastObjectResponse.fromJson(Map<String, dynamic> json) {
    return SuiPastObjectResponse(
      status: json['status'] as String,
      details: json['details'] != null
          ? SuiObjectData.fromJson(json['details'] as Map<String, dynamic>)
          : null,
    );
  }
}
