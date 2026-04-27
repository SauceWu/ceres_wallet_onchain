import 'dart:convert';
import 'package:blockchain_utils/crypto/quick_crypto.dart';

/// EVM function selector computation and common selector constants.
///
/// A function selector is the first 4 bytes of `keccak256(signature)`,
/// used as the calldata prefix to identify the target function in EVM
/// contract calls.
///
/// ```dart
/// // Dynamic computation
/// FunctionSelector.compute('balanceOf(address)');     // [0x70, 0xa0, 0x82, 0x31]
/// FunctionSelector.computeHex('balanceOf(address)');  // '70a08231'
///
/// // Pre-defined constants
/// FunctionSelector.balanceOf;  // [0x70, 0xa0, 0x82, 0x31]
/// FunctionSelector.transfer;   // [0xa9, 0x05, 0x9c, 0xbb]
/// ```
class FunctionSelector {
  FunctionSelector._();

  /// Computes the 4-byte selector from a function [signature].
  ///
  /// The signature is automatically normalized by removing all whitespace.
  /// For example, `'transfer(address, uint256)'` is treated identically to
  /// `'transfer(address,uint256)'`.
  static List<int> compute(String signature) {
    final normalized = signature.replaceAll(' ', '');
    final hash = QuickCrypto.keccack256Hash(utf8.encode(normalized));
    return hash.sublist(0, 4);
  }

  /// Same as [compute] but returns a lowercase hex string without `0x` prefix.
  ///
  /// Example: `computeHex('balanceOf(address)')` returns `'70a08231'`.
  static String computeHex(String signature) {
    final bytes = compute(signature);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ---- Common selector constants ----

  /// ERC-20 `balanceOf(address)` — `0x70a08231`
  static const List<int> balanceOf = [0x70, 0xa0, 0x82, 0x31];

  /// ERC-20 `name()` — `0x06fdde03`
  static const List<int> name = [0x06, 0xfd, 0xde, 0x03];

  /// ERC-20 `symbol()` — `0x95d89b41`
  static const List<int> symbol = [0x95, 0xd8, 0x9b, 0x41];

  /// ERC-20 `decimals()` — `0x313ce567`
  static const List<int> decimals = [0x31, 0x3c, 0xe5, 0x67];

  /// ERC-20 `totalSupply()` — `0x18160ddd`
  static const List<int> totalSupply = [0x18, 0x16, 0x0d, 0xdd];

  /// ERC-20 `transfer(address,uint256)` — `0xa9059cbb`
  static const List<int> transfer = [0xa9, 0x05, 0x9c, 0xbb];

  /// ERC-20 `approve(address,uint256)` — `0x095ea7b3`
  static const List<int> approve = [0x09, 0x5e, 0xa7, 0xb3];

  /// ERC-20 `transferFrom(address,address,uint256)` — `0x23b872dd`
  static const List<int> transferFrom = [0x23, 0xb8, 0x72, 0xdd];

  /// ERC-20 `allowance(address,address)` — `0xdd62ed3e`
  static const List<int> allowance = [0xdd, 0x62, 0xed, 0x3e];

  /// Multicall3 `aggregate3((address,bool,bytes)[])` — `0x82ad56cb`
  static const List<int> aggregate3 = [0x82, 0xad, 0x56, 0xcb];
}
