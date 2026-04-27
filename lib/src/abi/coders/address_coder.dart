import 'package:blockchain_utils/utils/binary/utils.dart';

import '../../evm/evm_address.dart';
import '../abi_type.dart';
import '../abi_type_coder.dart';

/// ABI encoder/decoder for the Solidity `address` type.
///
/// Addresses are encoded as 32 bytes: 12 zero bytes followed by the 20-byte
/// address (left-padded). Decoding extracts the last 20 bytes and returns
/// an [EvmAddress] in EIP-55 checksum format.
///
/// ```dart
/// final coder = AddressCoder();
/// coder.encode('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
/// coder.encode(EvmAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'));
/// ```
class AddressCoder extends AbiTypeCoder {
  @override
  bool get isDynamic => false;

  @override
  EncoderResult encode(dynamic value) {
    final String hex;
    if (value is EvmAddress) {
      hex = value.toHex();
    } else if (value is String) {
      // Normalize through EvmAddress for validation and checksum.
      hex = EvmAddress(value).toHex();
    } else {
      throw AbiException(
        'AddressCoder expects String or EvmAddress, '
        'got ${value.runtimeType}',
      );
    }

    final addressBytes = BytesUtils.fromHexString(hex);
    if (addressBytes.length != 20) {
      throw AbiException(
        'Invalid address length: expected 20 bytes, got ${addressBytes.length}',
      );
    }

    // Left-pad with 12 zero bytes to fill 32 bytes.
    final bytes = List<int>.filled(32, 0);
    bytes.setAll(12, addressBytes);
    return EncoderResult(bytes);
  }

  @override
  DecoderResult decode(List<int> data, int offset) {
    if (data.length < offset + 32) {
      throw AbiException(
        'Insufficient data for address decode: '
        'need ${offset + 32}, have ${data.length}',
      );
    }

    // Extract the last 20 bytes from the 32-byte word.
    final addressBytes = data.sublist(offset + 12, offset + 32);
    final hexStr = BytesUtils.toHexString(addressBytes);
    return DecoderResult(EvmAddress('0x$hexStr'));
  }
}
