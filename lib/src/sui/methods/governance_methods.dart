/// Sui governance and staking RPC methods.
///
/// Provides methods for querying delegation stakes and validator APY
/// via the `suix_*` extended API.
///
/// ```dart
/// final stakes = await client.getStakes(owner);
/// final apys = await client.getValidatorsApy();
/// ```
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_stake.dart';
import '../models/sui_validators_apy.dart';
import '../sui_address.dart';

/// Governance and staking query methods for the Sui RPC client.
///
/// Implements 3 `suix_*` extended methods for querying delegation
/// stakes and validator annual percentage yields.
mixin SuiGovernanceMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns all delegated stakes for [owner].
  ///
  /// Calls `suix_getStakes`. Returns a list of [DelegatedStake], each
  /// containing the validator address and individual stake objects.
  ///
  /// ```dart
  /// final stakes = await client.getStakes(owner);
  /// for (final ds in stakes) {
  ///   print('Validator: ${ds.validatorAddress}');
  ///   for (final s in ds.stakes) {
  ///     print('  Principal: ${s.principal}, Status: ${s.status}');
  ///   }
  /// }
  /// ```
  Future<List<DelegatedStake>> getStakes(SuiAddress owner) async {
    final result = await transport.send('suix_getStakes', [owner.toHex()]);
    return (result as List<dynamic>)
        .map((e) => DelegatedStake.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns delegated stakes for the given staked SUI object IDs.
  ///
  /// Calls `suix_getStakesByIds`. Useful for looking up specific stakes
  /// by their object IDs rather than querying all stakes for an address.
  ///
  /// ```dart
  /// final stakes = await client.getStakesByIds(['0xstake1', '0xstake2']);
  /// ```
  Future<List<DelegatedStake>> getStakesByIds(List<String> stakedSuiIds) async {
    final result = await transport.send('suix_getStakesByIds', [stakedSuiIds]);
    return (result as List<dynamic>)
        .map((e) => DelegatedStake.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the annual percentage yield for all validators.
  ///
  /// Calls `suix_getValidatorsApy`. Returns a [ValidatorsApy] containing
  /// the epoch and APY data for each active validator.
  ///
  /// ```dart
  /// final apys = await client.getValidatorsApy();
  /// print('Epoch: ${apys.epoch}');
  /// for (final v in apys.apys) {
  ///   print('${v.address}: ${(v.apy * 100).toStringAsFixed(2)}%');
  /// }
  /// ```
  Future<ValidatorsApy> getValidatorsApy() async {
    final result = await transport.send('suix_getValidatorsApy', []);
    return ValidatorsApy.fromJson(result as Map<String, dynamic>);
  }
}
