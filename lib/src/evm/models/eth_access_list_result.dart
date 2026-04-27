import '../../utils/bigint_utils.dart';
import 'access_list_entry.dart';

/// Result of `eth_createAccessList` — an optimized access list and gas estimate.
///
/// The [accessList] contains the storage slots and addresses that will be
/// accessed during transaction execution. [gasUsed] is the estimated gas
/// consumption with the generated access list applied.
///
/// ```dart
/// final result = EthAccessListResult.fromJson(jsonMap);
/// print(result.accessList.length); // number of entries
/// print(result.gasUsed);           // estimated gas
/// ```
class EthAccessListResult {
  /// The generated access list entries.
  final List<AccessListEntry> accessList;

  /// Estimated gas with the access list applied.
  final BigInt gasUsed;

  /// Creates an [EthAccessListResult] with all fields.
  const EthAccessListResult({required this.accessList, required this.gasUsed});

  /// Parses an [EthAccessListResult] from a JSON-RPC response map.
  factory EthAccessListResult.fromJson(Map<String, dynamic> json) {
    return EthAccessListResult(
      accessList: (json['accessList'] as List)
          .map((e) => AccessListEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      gasUsed: BigIntUtils.hexToBigInt(json['gasUsed'] as String),
    );
  }
}
