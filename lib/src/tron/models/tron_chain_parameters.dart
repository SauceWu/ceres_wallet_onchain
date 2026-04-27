/// Chain parameters returned by `getchainparameters` API.
///
/// Contains a list of key-value configuration parameters for the Tron network.
///
/// ```dart
/// final params = TronChainParameters.fromJson(responseJson);
/// for (final p in params.parameters) {
///   print('${p.key}: ${p.value}');
/// }
/// ```
class TronChainParameters {
  /// List of chain configuration parameters.
  final List<TronChainParameter> parameters;

  /// Creates a [TronChainParameters].
  const TronChainParameters({this.parameters = const []});

  /// Parses from the API response containing `chainParameter` array.
  factory TronChainParameters.fromJson(Map<String, dynamic> json) {
    final list = json['chainParameter'] as List?;
    return TronChainParameters(
      parameters: list != null
          ? list
                .map(
                  (e) => TronChainParameter.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : const [],
    );
  }
}

/// A single chain configuration parameter.
class TronChainParameter {
  /// Parameter key name.
  final String? key;

  /// Parameter value.
  final int? value;

  /// Creates a [TronChainParameter].
  const TronChainParameter({this.key, this.value});

  /// Parses from a JSON object `{"key": "...", "value": 123}`.
  factory TronChainParameter.fromJson(Map<String, dynamic> json) {
    return TronChainParameter(
      key: json['key'] as String?,
      value: json['value'] as int?,
    );
  }
}
