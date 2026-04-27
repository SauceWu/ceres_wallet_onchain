/// Account-related Tron HTTP API methods.
///
/// Provides 8 endpoints for querying and managing Tron accounts:
/// balance, resources, activation, and address validation.
///
/// All methods use base58 visible format (`visible: true`) for addresses.
library;

import '../models/tron_account.dart';
import '../models/tron_account_resource.dart';
import '../models/tron_transaction.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// Account-related Tron REST API methods.
///
/// Requires a [RestTransport] to send HTTP POST requests to Tron nodes.
/// Mix this into a Tron client class that provides the [transport].
///
/// All 8 methods correspond to TRON-01 through TRON-08:
///
/// | ID      | Method              | Endpoint                      |
/// |---------|---------------------|-------------------------------|
/// | TRON-01 | getAccount          | /wallet/getaccount            |
/// | TRON-02 | getAccountSolidity  | /walletsolidity/getaccount    |
/// | TRON-03 | getAccountBalance   | /wallet/getaccountbalance     |
/// | TRON-04 | getAccountNet       | /wallet/getaccountnet         |
/// | TRON-05 | getAccountResource  | /wallet/getaccountresource    |
/// | TRON-06 | createAccount       | /wallet/createaccount         |
/// | TRON-07 | updateAccount       | /wallet/updateaccount         |
/// | TRON-08 | validateAddress     | /wallet/validateaddress       |
mixin TronAccountMethods {
  /// The REST transport used to send requests.
  RestTransport get transport;

  /// Returns the account info for [address], or `null` if the account
  /// does not exist on chain.
  ///
  /// Calls `POST /wallet/getaccount`.
  ///
  /// ```dart
  /// final account = await client.getAccount(addr);
  /// if (account != null) {
  ///   print('Balance: ${account.balance} sun');
  /// }
  /// ```
  Future<TronAccount?> getAccount(TronAddress address) async {
    final result = await transport.post('/wallet/getaccount', {
      'address': address.toBase58(),
      'visible': true,
    });
    if (result.isEmpty) return null;
    return TronAccount.fromJson(result);
  }

  /// Returns the account info from a Solidity node (confirmed state).
  ///
  /// Calls `POST /walletsolidity/getaccount`. Returns `null` if the
  /// account does not exist.
  Future<TronAccount?> getAccountSolidity(TronAddress address) async {
    final result = await transport.post('/walletsolidity/getaccount', {
      'address': address.toBase58(),
      'visible': true,
    });
    if (result.isEmpty) return null;
    return TronAccount.fromJson(result);
  }

  /// Returns the historical balance of [address] at a specific block.
  ///
  /// Calls `POST /wallet/getaccountbalance`.
  ///
  /// The [blockNum] and [blockHash] identify the block to query.
  /// Returns the raw JSON response map.
  Future<Map<String, dynamic>> getAccountBalance({
    required TronAddress address,
    required int blockNum,
    required String blockHash,
  }) async {
    return await transport.post('/wallet/getaccountbalance', {
      'account_identifier': {'address': address.toBase58()},
      'block_identifier': {'number': blockNum, 'hash': blockHash},
      'visible': true,
    });
  }

  /// Returns bandwidth resource info for [address] as raw JSON.
  ///
  /// Calls `POST /wallet/getaccountnet`.
  Future<Map<String, dynamic>> getAccountNet(TronAddress address) async {
    return await transport.post('/wallet/getaccountnet', {
      'address': address.toBase58(),
      'visible': true,
    });
  }

  /// Returns the account resource info (bandwidth, energy, Tron Power)
  /// for [address].
  ///
  /// Calls `POST /wallet/getaccountresource`.
  Future<TronAccountResource> getAccountResource(TronAddress address) async {
    final result = await transport.post('/wallet/getaccountresource', {
      'address': address.toBase58(),
      'visible': true,
    });
    return TronAccountResource.fromJson(result);
  }

  /// Creates (activates) a new account on chain.
  ///
  /// Calls `POST /wallet/createaccount`. Returns an unsigned
  /// [TronTransaction] that must be signed before broadcasting.
  ///
  /// Throws [RpcException] if the Tron node returns an error.
  Future<TronTransaction> createAccount({
    required TronAddress ownerAddress,
    required TronAddress accountAddress,
  }) async {
    final result = await transport.post('/wallet/createaccount', {
      'owner_address': ownerAddress.toBase58(),
      'account_address': accountAddress.toBase58(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Updates the account name for [ownerAddress].
  ///
  /// Calls `POST /wallet/updateaccount`. Returns an unsigned
  /// [TronTransaction] that must be signed before broadcasting.
  ///
  /// Throws [RpcException] if the Tron node returns an error.
  Future<TronTransaction> updateAccount({
    required TronAddress ownerAddress,
    required String accountName,
  }) async {
    final result = await transport.post('/wallet/updateaccount', {
      'owner_address': ownerAddress.toBase58(),
      'account_name': accountName,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Validates a Tron address format.
  ///
  /// Calls `POST /wallet/validateaddress`. Returns the raw response
  /// containing `result` (bool) and `message` fields.
  Future<Map<String, dynamic>> validateAddress(String address) async {
    return await transport.post('/wallet/validateaddress', {
      'address': address,
    });
  }
}
