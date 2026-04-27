import '../evm_address.dart';
import '../../utils/bigint_utils.dart';

/// An [EIP-4895](https://eips.ethereum.org/EIPS/eip-4895) beacon chain
/// withdrawal included in a post-Shanghai block.
///
/// Each withdrawal transfers ETH from the beacon chain to an execution
/// layer [address]. The [amount] is denominated in Gwei.
///
/// ```dart
/// final w = EthWithdrawal.fromJson(jsonMap);
/// print(w.address);          // 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
/// print(w.amount);           // 1000000000000 (Gwei)
/// print(w.validatorIndex);   // 42
/// ```
class EthWithdrawal {
  /// Monotonically increasing withdrawal index.
  final BigInt index;

  /// Index of the validator that initiated the withdrawal.
  final BigInt validatorIndex;

  /// Execution layer address receiving the withdrawn ETH.
  final EvmAddress address;

  /// Amount withdrawn, in Gwei.
  final BigInt amount;

  /// Creates an [EthWithdrawal] with all fields.
  const EthWithdrawal({
    required this.index,
    required this.validatorIndex,
    required this.address,
    required this.amount,
  });

  /// Parses an [EthWithdrawal] from a JSON-RPC response map.
  ///
  /// All numeric fields are hex-encoded quantities converted to [BigInt].
  factory EthWithdrawal.fromJson(Map<String, dynamic> json) {
    return EthWithdrawal(
      index: BigIntUtils.hexToBigInt(json['index'] as String),
      validatorIndex: BigIntUtils.hexToBigInt(json['validatorIndex'] as String),
      address: EvmAddress(json['address'] as String),
      amount: BigIntUtils.hexToBigInt(json['amount'] as String),
    );
  }
}
