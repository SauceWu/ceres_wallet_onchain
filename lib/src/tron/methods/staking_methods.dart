/// Tron Stake 2.0 methods mixin (TRON-35 ~ TRON-44).
///
/// Provides 10 endpoints for freezing/unfreezing TRX, delegating resources,
/// and querying staking state under the Stake 2.0 protocol.
///
/// All transaction-producing methods return an unsigned [TronTransaction]
/// that must be signed externally before broadcasting.
///
/// ```dart
/// class TronClient with TronStakingMethods {
///   @override
///   final RestTransport transport;
///   TronClient(this.transport);
/// }
/// ```
library;

import '../models/tron_transaction.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// Stake 2.0 staking methods for Tron HTTP API.
///
/// Requires a [RestTransport] instance via the [transport] getter.
/// Mixed into a Tron client class that provides the transport.
mixin TronStakingMethods {
  /// The REST transport used for HTTP API calls.
  RestTransport get transport;

  /// Freezes TRX to obtain bandwidth or energy (Stake 2.0).
  ///
  /// [ownerAddress] is the account performing the freeze.
  /// [frozenBalance] is the amount of TRX in sun to freeze.
  /// [resource] must be `'BANDWIDTH'` or `'ENERGY'`.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/freezebalancev2`
  Future<TronTransaction> freezeBalanceV2({
    required TronAddress ownerAddress,
    required BigInt frozenBalance,
    required String resource,
  }) async {
    final result = await transport.post('/wallet/freezebalancev2', {
      'owner_address': ownerAddress.toBase58(),
      'frozen_balance': frozenBalance.toInt(),
      'resource': resource,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Unfreezes TRX previously frozen under Stake 2.0.
  ///
  /// [ownerAddress] is the account performing the unfreeze.
  /// [unfreezeBalance] is the amount of TRX in sun to unfreeze.
  /// [resource] must be `'BANDWIDTH'` or `'ENERGY'`.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/unfreezebalancev2`
  Future<TronTransaction> unfreezeBalanceV2({
    required TronAddress ownerAddress,
    required BigInt unfreezeBalance,
    required String resource,
  }) async {
    final result = await transport.post('/wallet/unfreezebalancev2', {
      'owner_address': ownerAddress.toBase58(),
      'unfreeze_balance': unfreezeBalance.toInt(),
      'resource': resource,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Withdraws expired unfrozen TRX to the owner's balance.
  ///
  /// After unfreezing, TRX enters a waiting period before it can be
  /// withdrawn. This method claims the available amount.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/withdrawexpireunfreeze`
  Future<TronTransaction> withdrawExpireUnfreeze({
    required TronAddress ownerAddress,
  }) async {
    final result = await transport.post('/wallet/withdrawexpireunfreeze', {
      'owner_address': ownerAddress.toBase58(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Delegates bandwidth or energy to another account.
  ///
  /// [ownerAddress] is the delegator.
  /// [receiverAddress] is the delegatee.
  /// [balance] is the amount of resource in sun to delegate.
  /// [resource] must be `'BANDWIDTH'` or `'ENERGY'`.
  /// [lock] if true, locks the delegation for [lockPeriod] blocks.
  /// [lockPeriod] lock duration in blocks (only used when [lock] is true).
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/delegateresource`
  Future<TronTransaction> delegateResource({
    required TronAddress ownerAddress,
    required TronAddress receiverAddress,
    required BigInt balance,
    required String resource,
    bool lock = false,
    int? lockPeriod,
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'receiver_address': receiverAddress.toBase58(),
      'balance': balance.toInt(),
      'resource': resource,
      'lock': lock,
      'visible': true,
    };
    if (lockPeriod != null) {
      body['lock_period'] = lockPeriod;
    }
    final result = await transport.post('/wallet/delegateresource', body);
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Revokes a previously delegated resource.
  ///
  /// [ownerAddress] is the original delegator.
  /// [receiverAddress] is the delegatee to revoke from.
  /// [balance] is the amount of resource in sun to revoke.
  /// [resource] must be `'BANDWIDTH'` or `'ENERGY'`.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/undelegateresource`
  Future<TronTransaction> undelegateResource({
    required TronAddress ownerAddress,
    required TronAddress receiverAddress,
    required BigInt balance,
    required String resource,
  }) async {
    final result = await transport.post('/wallet/undelegateresource', {
      'owner_address': ownerAddress.toBase58(),
      'receiver_address': receiverAddress.toBase58(),
      'balance': balance.toInt(),
      'resource': resource,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Queries the remaining unfreeze count for the current period.
  ///
  /// Returns a map containing `count` (the remaining unfreeze operations).
  ///
  /// Endpoint: `POST /wallet/getavailableunfreezecount`
  Future<Map<String, dynamic>> getAvailableUnfreezeCount(
    TronAddress ownerAddress,
  ) async {
    return await transport.post('/wallet/getavailableunfreezecount', {
      'owner_address': ownerAddress.toBase58(),
      'visible': true,
    });
  }

  /// Queries the amount of TRX available for withdrawal after unfreezing.
  ///
  /// [timestamp] optional timestamp in milliseconds; defaults to current time.
  ///
  /// Returns a map containing `amount` (withdrawable sun).
  ///
  /// Endpoint: `POST /wallet/getcanwithdrawunfreezeamount`
  Future<Map<String, dynamic>> getCanWithdrawUnfreezeAmount({
    required TronAddress ownerAddress,
    int? timestamp,
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'visible': true,
    };
    if (timestamp != null) {
      body['timestamp'] = timestamp;
    }
    return await transport.post('/wallet/getcanwithdrawunfreezeamount', body);
  }

  /// Queries the maximum delegatable resource size.
  ///
  /// [type] is `0` for bandwidth, `1` for energy.
  ///
  /// Returns a map containing `max_size`.
  ///
  /// Endpoint: `POST /wallet/getcandelegatedmaxsize`
  Future<Map<String, dynamic>> getCanDelegatedMaxSize({
    required TronAddress ownerAddress,
    required int type,
  }) async {
    return await transport.post('/wallet/getcandelegatedmaxsize', {
      'owner_address': ownerAddress.toBase58(),
      'type': type,
      'visible': true,
    });
  }

  /// Queries delegated resource details between two accounts.
  ///
  /// Returns a map with delegation details (bandwidth and energy).
  ///
  /// Endpoint: `POST /wallet/getdelegatedresourcev2`
  Future<Map<String, dynamic>> getDelegatedResourceV2({
    required TronAddress fromAddress,
    required TronAddress toAddress,
  }) async {
    return await transport.post('/wallet/getdelegatedresourcev2', {
      'fromAddress': fromAddress.toBase58(),
      'toAddress': toAddress.toBase58(),
      'visible': true,
    });
  }

  /// Queries the delegation index for an account.
  ///
  /// Returns a map listing all accounts that have delegated to or
  /// received delegation from the given [address].
  ///
  /// Endpoint: `POST /wallet/getdelegatedresourceaccountindexv2`
  Future<Map<String, dynamic>> getDelegatedResourceAccountIndexV2(
    TronAddress address,
  ) async {
    return await transport.post('/wallet/getdelegatedresourceaccountindexv2', {
      'value': address.toBase58(),
      'visible': true,
    });
  }
}
