import 'abi_param.dart';
import 'abi_type.dart';
import 'function_selector.dart';
import 'coders/tuple_coder.dart';

/// ABI encoder/decoder top-level API.
///
/// Provides static methods for Solidity ABI encoding and decoding, used to
/// construct `eth_call` data fields and parse contract return values.
///
/// ```dart
/// // Encode balanceOf(address)
/// final calldata = AbiCoder.encodeFunctionCall(
///   FunctionSelector.balanceOf,
///   [AbiParam.address()],
///   [EvmAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045')],
/// );
///
/// // Decode returned uint256
/// final results = AbiCoder.decode(
///   [AbiParam.uint256()],
///   returnBytes,
/// );
/// final balance = results[0] as BigInt;
/// ```
class AbiCoder {
  AbiCoder._();

  /// Encodes a parameter list (without selector prefix).
  ///
  /// Equivalent to ethers.js `defaultAbiCoder.encode(types, values)`.
  ///
  /// Throws [AbiException] if [params] and [values] have different lengths.
  static List<int> encode(List<AbiParam> params, List<dynamic> values) {
    if (params.length != values.length) {
      throw AbiException(
        'Parameter count mismatch: '
        '${params.length} params but ${values.length} values',
      );
    }
    final tupleCoder = TupleCoder(params);
    final result = tupleCoder.encode(values);
    return result.encoded;
  }

  /// Decodes a parameter list.
  ///
  /// Equivalent to ethers.js `defaultAbiCoder.decode(types, data)`.
  static List<dynamic> decode(List<AbiParam> params, List<int> data) {
    final tupleCoder = TupleCoder(params);
    final result = tupleCoder.decode(data, 0);
    return result.value as List<dynamic>;
  }

  /// Encodes a complete function call (4-byte selector + encoded parameters).
  ///
  /// Produces calldata ready for the `eth_call` data field.
  ///
  /// Throws [AbiException] if [params] and [values] have different lengths.
  static List<int> encodeFunctionCall(
    List<int> selector,
    List<AbiParam> params,
    List<dynamic> values,
  ) {
    final encoded = encode(params, values);
    return [...selector, ...encoded];
  }

  /// Encodes a complete function call from a function signature string.
  ///
  /// ```dart
  /// final calldata = AbiCoder.encodeFunctionCallBySignature(
  ///   'balanceOf(address)',
  ///   [AbiParam.address()],
  ///   ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
  /// );
  /// ```
  static List<int> encodeFunctionCallBySignature(
    String signature,
    List<AbiParam> params,
    List<dynamic> values,
  ) {
    final selector = FunctionSelector.compute(signature);
    return encodeFunctionCall(selector, params, values);
  }
}
