import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';
import '../evm_address.dart';
import '../models/eth_proof.dart';

/// Account-related EVM RPC methods.
///
/// Provides methods for querying account state: balance, storage, nonce,
/// code, and Merkle proofs (EIP-1186).
///
/// All quantity values are returned as [BigInt] to safely represent uint256.
/// All methods accept an optional [blockTag] parameter defaulting to `'latest'`.
mixin EvmAccountMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the balance (in wei) of the account at [address].
  ///
  /// Calls `eth_getBalance` with the given [blockTag] (default `'latest'`).
  ///
  /// ```dart
  /// final balance = await client.getBalance(EvmAddress('0x...'));
  /// print('Balance: $balance wei');
  /// ```
  Future<BigInt> getBalance(
    EvmAddress address, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getBalance', [
      address.toString(),
      blockTag,
    ]);
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the value stored at [position] in the account at [address].
  ///
  /// Calls `eth_getStorageAt`. The [position] is the storage slot index,
  /// sent as a hex-encoded QUANTITY.
  ///
  /// ```dart
  /// final value = await client.getStorageAt(addr, BigInt.zero);
  /// ```
  Future<String> getStorageAt(
    EvmAddress address,
    BigInt position, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getStorageAt', [
      address.toString(),
      BigIntUtils.bigIntToHex(position),
      blockTag,
    ]);
    return result as String;
  }

  /// Returns the number of transactions sent from [address] (the nonce).
  ///
  /// Calls `eth_getTransactionCount`. Useful for constructing transactions
  /// with the correct nonce.
  ///
  /// ```dart
  /// final nonce = await client.getTransactionCount(addr);
  /// ```
  Future<BigInt> getTransactionCount(
    EvmAddress address, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getTransactionCount', [
      address.toString(),
      blockTag,
    ]);
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the bytecode at [address], or `'0x'` if no contract is deployed.
  ///
  /// Calls `eth_getCode`.
  ///
  /// ```dart
  /// final code = await client.getCode(contractAddr);
  /// final isContract = code != '0x';
  /// ```
  Future<String> getCode(
    EvmAddress address, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getCode', [
      address.toString(),
      blockTag,
    ]);
    return result as String;
  }

  /// Returns the Merkle proof for the account at [address] and the given
  /// [storageKeys] (EIP-1186).
  ///
  /// Calls `eth_getProof`. Returns an [EthProof] containing account state
  /// and storage slot proofs.
  ///
  /// ```dart
  /// final proof = await client.getProof(addr, ['0x0']);
  /// print(proof.balance);
  /// ```
  Future<EthProof> getProof(
    EvmAddress address,
    List<String> storageKeys, {
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getProof', [
      address.toString(),
      storageKeys,
      blockTag,
    ]);
    return EthProof.fromJson(result as Map<String, dynamic>);
  }
}
