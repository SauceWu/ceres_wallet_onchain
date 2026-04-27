/// Tron witness and voting methods mixin (TRON-45 ~ TRON-50).
///
/// Provides 6 endpoints for voting on super representatives, listing
/// witnesses, querying brokerage/rewards, and maintenance time.
///
/// Transaction-producing methods return an unsigned [TronTransaction]
/// that must be signed externally before broadcasting.
///
/// ```dart
/// class TronClient with TronWitnessMethods {
///   @override
///   final RestTransport transport;
///   TronClient(this.transport);
/// }
/// ```
library;

import '../models/tron_transaction.dart';
import '../models/tron_witness.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// Witness and voting methods for Tron HTTP API.
///
/// Requires a [RestTransport] instance via the [transport] getter.
/// Mixed into a Tron client class that provides the transport.
mixin TronWitnessMethods {
  /// The REST transport used for HTTP API calls.
  RestTransport get transport;

  /// Votes for super representative candidates.
  ///
  /// [ownerAddress] is the voter account.
  /// [votes] maps witness base58 addresses to vote counts.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/votewitnessaccount`
  Future<TronTransaction> voteWitnessAccount({
    required TronAddress ownerAddress,
    required Map<String, int> votes,
  }) async {
    final voteList = votes.entries
        .map((e) => {'vote_address': e.key, 'vote_count': e.value})
        .toList();
    final result = await transport.post('/wallet/votewitnessaccount', {
      'owner_address': ownerAddress.toBase58(),
      'votes': voteList,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Lists all witness (super representative) nodes.
  ///
  /// Returns a list of [TronWitness] objects with address, vote count,
  /// and block production statistics.
  ///
  /// Endpoint: `GET /wallet/listwitnesses`
  Future<List<TronWitness>> listWitnesses() async {
    final result = await transport.get('/wallet/listwitnesses');
    final witnesses = result['witnesses'] as List? ?? [];
    return witnesses
        .map((w) => TronWitness.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// Queries the brokerage ratio for a witness.
  ///
  /// The brokerage ratio determines how much of the block reward the
  /// witness keeps vs distributes to voters.
  ///
  /// Returns a map containing `brokerage` (percentage 0-100).
  ///
  /// Endpoint: `POST /wallet/getbrokerage`
  Future<Map<String, dynamic>> getBrokerage(TronAddress address) async {
    return await transport.post('/wallet/getbrokerage', {
      'address': address.toBase58(),
      'visible': true,
    });
  }

  /// Queries the unclaimed voting reward for an account.
  ///
  /// Returns a map containing `reward` (amount in sun).
  ///
  /// Endpoint: `POST /wallet/getreward`
  Future<Map<String, dynamic>> getReward(TronAddress address) async {
    return await transport.post('/wallet/getreward', {
      'address': address.toBase58(),
      'visible': true,
    });
  }

  /// Withdraws accumulated voting rewards to the owner's balance.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/withdrawbalance`
  Future<TronTransaction> withdrawBalance(TronAddress ownerAddress) async {
    final result = await transport.post('/wallet/withdrawbalance', {
      'owner_address': ownerAddress.toBase58(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Queries the next maintenance time for the Tron network.
  ///
  /// Returns a map containing `num` (timestamp in milliseconds).
  ///
  /// Endpoint: `GET /wallet/getnextmaintenancetime`
  Future<Map<String, dynamic>> getNextMaintenanceTime() async {
    return await transport.get('/wallet/getnextmaintenancetime');
  }
}
