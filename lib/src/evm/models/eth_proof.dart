import '../evm_address.dart';
import '../../utils/bigint_utils.dart';

/// A storage proof entry within an [EthProof] (EIP-1186).
///
/// Each [StorageProof] verifies the value stored at a specific [key]
/// in the account's storage trie.
///
/// ```dart
/// final sp = StorageProof.fromJson(jsonMap);
/// print(sp.key);   // 0x0000...0001
/// print(sp.value); // stored BigInt value
/// ```
class StorageProof {
  /// The storage slot key (32-byte hex string).
  final String key;

  /// The value stored at this key.
  final BigInt value;

  /// Merkle proof nodes for this storage slot.
  final List<String> proof;

  /// Creates a [StorageProof] with all fields.
  const StorageProof({
    required this.key,
    required this.value,
    required this.proof,
  });

  /// Parses a [StorageProof] from a JSON-RPC response map.
  factory StorageProof.fromJson(Map<String, dynamic> json) {
    return StorageProof(
      key: json['key'] as String,
      value: BigIntUtils.hexToBigInt(json['value'] as String),
      proof: (json['proof'] as List).cast<String>(),
    );
  }
}

/// An Ethereum account proof returned by `eth_getProof` (EIP-1186).
///
/// Contains the account state ([balance], [nonce], [codeHash], [storageHash])
/// along with Merkle proofs for both the account and requested storage slots.
///
/// ```dart
/// final proof = EthProof.fromJson(jsonMap);
/// print(proof.balance);        // account balance in wei
/// print(proof.storageProof);   // storage slot proofs
/// ```
class EthProof {
  /// The account address.
  final EvmAddress address;

  /// Merkle proof nodes for the account.
  final List<String> accountProof;

  /// Account balance in wei.
  final BigInt balance;

  /// Hash of the account's code.
  final String codeHash;

  /// Account nonce (number of transactions sent).
  final BigInt nonce;

  /// Root hash of the account's storage trie.
  final String storageHash;

  /// Proofs for the requested storage slots.
  final List<StorageProof> storageProof;

  /// Creates an [EthProof] with all fields.
  const EthProof({
    required this.address,
    required this.accountProof,
    required this.balance,
    required this.codeHash,
    required this.nonce,
    required this.storageHash,
    required this.storageProof,
  });

  /// Parses an [EthProof] from a JSON-RPC response map.
  factory EthProof.fromJson(Map<String, dynamic> json) {
    return EthProof(
      address: EvmAddress(json['address'] as String),
      accountProof: (json['accountProof'] as List).cast<String>(),
      balance: BigIntUtils.hexToBigInt(json['balance'] as String),
      codeHash: json['codeHash'] as String,
      nonce: BigIntUtils.hexToBigInt(json['nonce'] as String),
      storageHash: json['storageHash'] as String,
      storageProof: (json['storageProof'] as List)
          .map((e) => StorageProof.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
