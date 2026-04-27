/// Generic paginated response container for Sui RPC methods.
///
/// Many Sui RPC methods return paginated results with `data`,
/// `hasNextPage`, and `nextCursor` fields. This class provides
/// a typed container that can be reused across all paginated endpoints.
///
/// ```dart
/// final page = SuiPaginatedResponse.fromJson(
///   json,
///   (item) => SuiCoin.fromJson(item as Map<String, dynamic>),
/// );
/// if (page.hasNextPage) {
///   // fetch next page using page.nextCursor
/// }
/// ```
library;

import 'sui_dynamic_field.dart';

/// A paginated response from a Sui RPC method.
///
/// Type parameter [T] represents the item type in the [data] list.
class SuiPaginatedResponse<T> {
  /// The list of items in this page.
  final List<T> data;

  /// Whether more pages are available after this one.
  final bool hasNextPage;

  /// The cursor to pass for fetching the next page, or `null` if
  /// this is the last page.
  final String? nextCursor;

  /// Creates a [SuiPaginatedResponse] with the given fields.
  const SuiPaginatedResponse({
    required this.data,
    required this.hasNextPage,
    this.nextCursor,
  });

  /// Parses a paginated response from a JSON map.
  ///
  /// The [itemParser] function converts each raw item in the `data`
  /// array to the target type [T].
  factory SuiPaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemParser,
  ) {
    final rawData = json['data'] as List<dynamic>;
    return SuiPaginatedResponse(
      data: rawData.map(itemParser).toList(),
      hasNextPage: json['hasNextPage'] as bool,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

/// Paginated response of [SuiDynamicFieldInfo] items.
///
/// Returned by `suix_getDynamicFields`.
typedef SuiPaginatedDynamicFields = SuiPaginatedResponse<SuiDynamicFieldInfo>;

/// Paginated response of name strings.
///
/// Returned by `suix_resolveNameServiceNames`.
typedef SuiPaginatedNames = SuiPaginatedResponse<String>;
