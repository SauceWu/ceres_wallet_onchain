/// Exception thrown when ABI encoding or decoding fails.
///
/// Indicates invalid input values, out-of-range numbers, malformed byte data,
/// or type mismatches during ABI operations.
///
/// ```dart
/// throw AbiException('uint8 value 256 exceeds maximum 255');
/// ```
class AbiException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// Creates an [AbiException] with the given [message].
  AbiException(this.message);

  @override
  String toString() => 'AbiException: $message';
}
