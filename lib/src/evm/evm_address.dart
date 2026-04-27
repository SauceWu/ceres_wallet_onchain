import 'package:blockchain_utils/bip/address/eth_addr.dart';

/// An Ethereum address value object that normalizes any hex input to
/// [EIP-55](https://eips.ethereum.org/EIPS/eip-55) mixed-case checksum format.
///
/// [EvmAddress] is immutable and can safely be used as a Map key or in Sets.
/// Equality is case-insensitive: two addresses representing the same 20-byte
/// value are always `==`, regardless of how they were originally cased.
///
/// ```dart
/// final addr = EvmAddress('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
/// print(addr);         // 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
/// print(addr.toHex()); // d8da6bf26964af9d7eed9e03e53415d37aa96045
/// ```
class EvmAddress {
  /// The EIP-55 checksummed address string, always `0x`-prefixed.
  final String _checksumAddress;

  /// Creates an [EvmAddress] from a hex string.
  ///
  /// Accepts addresses with or without the `0x` prefix, in any case.
  /// The input is normalized to EIP-55 mixed-case checksum format via
  /// `EthAddrUtils.toChecksumAddress()`.
  ///
  /// Throws if the input is not a valid 20-byte hex string.
  EvmAddress(String hex)
    : _checksumAddress = EthAddrUtils.toChecksumAddress(hex);

  /// Returns the EIP-55 checksummed address string with `0x` prefix.
  ///
  /// Example: `'0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'`
  @override
  String toString() => _checksumAddress;

  /// Returns the lowercase 40-character hex representation without `0x` prefix.
  ///
  /// Useful for constructing raw byte arrays or comparing with external systems
  /// that expect lowercase hex.
  String toHex() => _checksumAddress.substring(2).toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvmAddress &&
          _checksumAddress.toLowerCase() ==
              other._checksumAddress.toLowerCase();

  @override
  int get hashCode => _checksumAddress.toLowerCase().hashCode;
}
