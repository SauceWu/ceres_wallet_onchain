/// Staking and inflation-related Solana RPC methods.
///
/// Provides methods for querying validator vote accounts, stake delegation,
/// inflation parameters, and inflation rewards.
///
/// Contains 6 methods: getVoteAccounts, getStakeMinimumDelegation,
/// getStakeActivation, getInflationGovernor, getInflationRate,
/// getInflationReward.
library;

import '../../core/json_rpc_transport.dart';
import '../models/inflation.dart';
import '../models/stake_activation.dart';
import '../models/vote_account.dart';
import '../solana_address.dart';
import '../solana_commitment.dart';

/// Staking and inflation RPC methods for Solana.
///
/// Requires access to a [JsonRpcTransport] via the `transport` getter.
mixin SolanaStakingMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the account info and associated stake for all voting validators.
  ///
  /// Calls `getVoteAccounts`. Returns a [VoteAccountsResult] containing
  /// both [VoteAccountsResult.current] and [VoteAccountsResult.delinquent]
  /// validator lists.
  ///
  /// Optional filters:
  /// - [votePubkey]: Only return results for this vote account.
  /// - [keepUnstakedDelinquents]: Do not filter out delinquent validators
  ///   with no stake.
  /// - [delinquentSlotDistance]: Specify the number of slots behind the tip
  ///   that a validator must be to be considered delinquent.
  /// - [commitment]: The commitment level for the query.
  ///
  /// ```dart
  /// final votes = await client.getVoteAccounts();
  /// print('${votes.current.length} active validators');
  /// ```
  Future<VoteAccountsResult> getVoteAccounts({
    String? votePubkey,
    bool? keepUnstakedDelinquents,
    int? delinquentSlotDistance,
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;
    if (votePubkey != null) config['votePubkey'] = votePubkey;
    if (keepUnstakedDelinquents != null) {
      config['keepUnstakedDelinquents'] = keepUnstakedDelinquents;
    }
    if (delinquentSlotDistance != null) {
      config['delinquentSlotDistance'] = delinquentSlotDistance;
    }

    final params = config.isEmpty ? <dynamic>[] : <dynamic>[config];
    final result = await transport.send('getVoteAccounts', params);
    return VoteAccountsResult.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the minimum delegation amount for stake accounts in lamports.
  ///
  /// Calls `getStakeMinimumDelegation`. Returns a [BigInt] extracted from
  /// the RpcResponse `value` field.
  ///
  /// ```dart
  /// final minDelegation = await client.getStakeMinimumDelegation();
  /// print('Minimum delegation: $minDelegation lamports');
  /// ```
  Future<BigInt> getStakeMinimumDelegation({
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = config.isEmpty ? <dynamic>[] : <dynamic>[config];
    final result = await transport.send('getStakeMinimumDelegation', params);
    final map = result as Map<String, dynamic>;
    return BigInt.from(map['value'] as num);
  }

  /// Returns the activation state of a stake account.
  ///
  /// Calls `getStakeActivation` with the given [pubkey]. Returns a
  /// [StakeActivation] with state, active, and inactive lamport amounts.
  ///
  /// ```dart
  /// final activation = await client.getStakeActivation(stakeAddr);
  /// print('State: ${activation.state}');
  /// ```
  Future<StakeActivation> getStakeActivation(
    SolanaAddress pubkey, {
    SolanaCommitment? commitment,
    int? epoch,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;
    if (epoch != null) config['epoch'] = epoch;

    final params = <dynamic>[pubkey.toBase58()];
    if (config.isNotEmpty) params.add(config);
    final result = await transport.send('getStakeActivation', params);
    return StakeActivation.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the current inflation governor parameters.
  ///
  /// Calls `getInflationGovernor`. Returns an [InflationGovernor] with
  /// initial, terminal, taper, foundation, and foundationTerm rates.
  ///
  /// ```dart
  /// final governor = await client.getInflationGovernor();
  /// print('Initial rate: ${governor.initial}');
  /// ```
  Future<InflationGovernor> getInflationGovernor({
    SolanaCommitment? commitment,
  }) async {
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;

    final params = config.isEmpty ? <dynamic>[] : <dynamic>[config];
    final result = await transport.send('getInflationGovernor', params);
    return InflationGovernor.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the specific inflation values for the current epoch.
  ///
  /// Calls `getInflationRate`. Returns an [InflationRate] with total,
  /// validator, foundation rates and the epoch number.
  ///
  /// ```dart
  /// final rate = await client.getInflationRate();
  /// print('Total inflation: ${rate.total}');
  /// ```
  Future<InflationRate> getInflationRate() async {
    final result = await transport.send('getInflationRate');
    return InflationRate.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the inflation rewards for a list of addresses for an epoch.
  ///
  /// Calls `getInflationReward`. Returns a list of nullable [InflationReward]
  /// objects; entries are `null` for addresses with no reward in the epoch.
  ///
  /// ```dart
  /// final rewards = await client.getInflationReward([addr1, addr2]);
  /// for (final r in rewards) {
  ///   if (r != null) print('Reward: ${r.amount} lamports');
  /// }
  /// ```
  Future<List<InflationReward?>> getInflationReward(
    List<SolanaAddress> addresses, {
    SolanaCommitment? commitment,
    int? epoch,
    int? minContextSlot,
  }) async {
    final addressList = addresses.map((a) => a.toBase58()).toList();
    final config = <String, dynamic>{};
    if (commitment != null) config['commitment'] = commitment.name;
    if (epoch != null) config['epoch'] = epoch;
    if (minContextSlot != null) config['minContextSlot'] = minContextSlot;

    final params = <dynamic>[addressList];
    if (config.isNotEmpty) params.add(config);
    final result = await transport.send('getInflationReward', params);
    return (result as List).map((item) {
      if (item == null) return null;
      return InflationReward.fromJson(item as Map<String, dynamic>);
    }).toList();
  }
}
