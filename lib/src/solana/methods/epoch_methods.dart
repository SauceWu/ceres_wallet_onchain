/// Solana epoch-related RPC methods.
///
/// Provides typed access to `getEpochInfo`, `getEpochSchedule`, and
/// `getLeaderSchedule` RPC methods.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to a Solana RPC client class.
///
/// ```dart
/// class MySolanaClient with SolanaEpochMethods {
///   @override
///   final JsonRpcTransport transport;
///   MySolanaClient(this.transport);
/// }
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/epoch_info.dart';
import '../solana_commitment.dart';

/// Epoch-related Solana JSON-RPC methods.
///
/// Covers SOL-22 through SOL-24: getEpochInfo, getEpochSchedule,
/// getLeaderSchedule.
mixin SolanaEpochMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns information about the current epoch.
  ///
  /// Directly returns an [EpochInfo] (not RpcResponse-wrapped).
  Future<EpochInfo> getEpochInfo({SolanaCommitment? commitment}) async {
    final params = <dynamic>[];
    if (commitment != null) {
      params.add({'commitment': commitment.name});
    }
    final result =
        await transport.send('getEpochInfo', params) as Map<String, dynamic>;
    return EpochInfo.fromJson(result);
  }

  /// Returns the epoch schedule information from this cluster's genesis config.
  ///
  /// Directly returns an [EpochSchedule] (not RpcResponse-wrapped).
  Future<EpochSchedule> getEpochSchedule() async {
    final result =
        await transport.send('getEpochSchedule') as Map<String, dynamic>;
    return EpochSchedule.fromJson(result);
  }

  /// Returns the leader schedule for an epoch.
  ///
  /// If [slot] is provided, returns the leader schedule for the epoch
  /// containing that slot. If `null`, returns the schedule for the
  /// current epoch.
  ///
  /// Returns `null` if the leader schedule is not available.
  ///
  /// The [identity] parameter filters results to a single validator.
  Future<Map<String, List<int>>?> getLeaderSchedule({
    int? slot,
    String? identity,
    SolanaCommitment? commitment,
  }) async {
    final params = <dynamic>[slot];
    final config = <String, dynamic>{};
    if (identity != null) {
      config['identity'] = identity;
    }
    if (commitment != null) {
      config['commitment'] = commitment.name;
    }
    if (config.isNotEmpty) {
      params.add(config);
    }

    final result = await transport.send('getLeaderSchedule', params);
    if (result == null) return null;

    final raw = result as Map<String, dynamic>;
    return raw.map((key, value) => MapEntry(key, (value as List).cast<int>()));
  }
}
