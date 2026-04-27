import '../evm_address.dart';

/// An [EIP-2930](https://eips.ethereum.org/EIPS/eip-2930) access list entry
/// specifying a contract [address] and its accessed [storageKeys].
///
/// Access lists are used in Type 1 and Type 2 transactions to pre-declare
/// storage slots that will be accessed, reducing gas costs for warm reads.
///
/// ```dart
/// final entry = AccessListEntry.fromJson(jsonMap);
/// print(entry.address);     // 0xdAC17F958D2ee523a2206206994597C13D831ec7
/// print(entry.storageKeys); // [0x0000...0001, 0x0000...0002]
/// ```
class AccessListEntry {
  /// The contract address whose storage is being accessed.
  final EvmAddress address;

  /// List of 32-byte storage slot keys (hex strings) accessed in [address].
  final List<String> storageKeys;

  /// Creates an [AccessListEntry] with the given [address] and [storageKeys].
  const AccessListEntry({required this.address, required this.storageKeys});

  /// Parses an [AccessListEntry] from a JSON-RPC response map.
  factory AccessListEntry.fromJson(Map<String, dynamic> json) {
    return AccessListEntry(
      address: EvmAddress(json['address'] as String),
      storageKeys: (json['storageKeys'] as List).cast<String>(),
    );
  }
}
