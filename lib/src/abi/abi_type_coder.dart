/// Result of encoding a value into ABI-encoded bytes.
///
/// Contains the raw [encoded] bytes and whether the value [isDynamic]
/// (requiring an offset pointer in the head section).
class EncoderResult {
  /// The ABI-encoded byte sequence.
  final List<int> encoded;

  /// Whether this result represents a dynamic type.
  final bool isDynamic;

  /// Creates an [EncoderResult] with the given [encoded] bytes.
  const EncoderResult(this.encoded, {this.isDynamic = false});
}

/// Result of decoding a value from ABI-encoded bytes.
///
/// Contains the decoded [value] and the number of bytes [consumed]
/// from the head section (always 32 for ABI encoding).
class DecoderResult {
  /// The decoded value (type depends on the coder).
  final dynamic value;

  /// Number of bytes consumed in the head section (always 32).
  final int consumed;

  /// Creates a [DecoderResult] with the given [value].
  const DecoderResult(this.value, {this.consumed = 32});
}

/// Abstract base class for ABI type encoders and decoders.
///
/// Each concrete coder handles one ABI type (or type family, like `uintN`).
/// Coders are stateless and reusable.
///
/// Subclasses must implement:
/// - [isDynamic]: whether the type requires offset-based encoding
/// - [encode]: serialize a Dart value to ABI bytes
/// - [decode]: deserialize ABI bytes back to a Dart value
abstract class AbiTypeCoder {
  /// Whether this coder handles a dynamic ABI type.
  bool get isDynamic;

  /// Encodes [value] into ABI-encoded bytes.
  ///
  /// Throws [AbiException] if the value is invalid for this type.
  EncoderResult encode(dynamic value);

  /// Decodes a value from [data] starting at [offset].
  ///
  /// Returns a [DecoderResult] containing the decoded value and bytes consumed.
  /// Throws [AbiException] if the data is too short or malformed.
  DecoderResult decode(List<int> data, int offset);
}
