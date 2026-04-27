/// Solana account-related RPC methods.
///
/// Provides methods for querying account state: balance, account info,
/// multiple accounts, program accounts, and largest accounts.
///
/// All lamport values are returned as [BigInt] to safely represent u64.
library;

import '../../core/json_rpc_transport.dart';
import '../models/account_balance.dart';
import '../models/account_info.dart';
import '../models/token_account.dart';
import '../solana_address.dart';
import '../solana_commitment.dart';

/// Account-related Solana RPC methods.
///
/// Provides SOL-01 through SOL-05:
/// - [getAccountInfo] — query a single account
/// - [getBalance] — query lamport balance
/// - [getMultipleAccounts] — batch account query
/// - [getProgramAccounts] — query accounts owned by a program
/// - [getLargestAccounts] — query largest accounts by balance
mixin SolanaAccountMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the [AccountInfo] for the account at [address], or `null`
  /// if the account does not exist.
  ///
  /// Calls `getAccountInfo` with the given [commitment] (default
  /// [SolanaCommitment.finalized]) and [encoding] (default `'base64'`).
  ///
  /// ```dart
  /// final info = await client.getAccountInfo(addr);
  /// if (info != null) print(info.lamports);
  /// ```
  Future<AccountInfo?> getAccountInfo(
    SolanaAddress address, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String encoding = 'base64',
    int? minContextSlot,
  }) async {
    final config = <String, dynamic>{
      'commitment': commitment.name,
      'encoding': encoding,
    };
    if (minContextSlot != null) {
      config['minContextSlot'] = minContextSlot;
    }

    final result = await transport.send('getAccountInfo', [
      address.toBase58(),
      config,
    ]);

    final value = (result as Map<String, dynamic>)['value'];
    if (value == null) return null;
    return AccountInfo.fromJson(value as Map<String, dynamic>);
  }

  /// Returns the lamport balance of the account at [address].
  ///
  /// Calls `getBalance`. Returns [BigInt] to safely represent u64 values
  /// (threat mitigation T-06-07: uses [BigInt.from] instead of `as int`).
  ///
  /// ```dart
  /// final balance = await client.getBalance(addr);
  /// print('$balance lamports');
  /// ```
  Future<BigInt> getBalance(
    SolanaAddress address, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
  }) async {
    final result = await transport.send('getBalance', [
      address.toBase58(),
      {'commitment': commitment.name},
    ]);

    final value = (result as Map<String, dynamic>)['value'];
    return BigInt.from(value as num);
  }

  /// Returns account information for multiple addresses in a single request.
  ///
  /// Calls `getMultipleAccounts`. Each element in the returned list may be
  /// `null` if the corresponding account does not exist.
  ///
  /// ```dart
  /// final accounts = await client.getMultipleAccounts([addr1, addr2]);
  /// for (final info in accounts) {
  ///   if (info != null) print(info.lamports);
  /// }
  /// ```
  Future<List<AccountInfo?>> getMultipleAccounts(
    List<SolanaAddress> addresses, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String encoding = 'base64',
  }) async {
    final result = await transport.send('getMultipleAccounts', [
      addresses.map((a) => a.toBase58()).toList(),
      {'commitment': commitment.name, 'encoding': encoding},
    ]);

    final value = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    return value.map((item) {
      if (item == null) return null;
      return AccountInfo.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  /// Returns all accounts owned by the given [programId].
  ///
  /// Calls `getProgramAccounts`. Supports optional [filters] and [dataSlice]
  /// parameters to narrow and truncate results.
  ///
  /// Note: Large result sets are limited by the RPC node, not by this SDK
  /// (threat acceptance T-06-08).
  ///
  /// ```dart
  /// final accounts = await client.getProgramAccounts(tokenProgram);
  /// ```
  Future<List<TokenAccount>> getProgramAccounts(
    SolanaAddress programId, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String encoding = 'base64',
    List<Map<String, dynamic>>? filters,
    Map<String, dynamic>? dataSlice,
  }) async {
    final config = <String, dynamic>{
      'commitment': commitment.name,
      'encoding': encoding,
    };
    if (filters != null) config['filters'] = filters;
    if (dataSlice != null) config['dataSlice'] = dataSlice;

    final result = await transport.send('getProgramAccounts', [
      programId.toBase58(),
      config,
    ]);

    return (result as List<dynamic>)
        .map((item) => TokenAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Returns the 20 largest accounts by lamport balance.
  ///
  /// Calls `getLargestAccounts`. The optional [filter] can be `'circulating'`
  /// or `'nonCirculating'` to narrow results.
  ///
  /// ```dart
  /// final largest = await client.getLargestAccounts();
  /// print(largest.first.address);
  /// ```
  Future<List<AccountBalance>> getLargestAccounts({
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String? filter,
  }) async {
    final config = <String, dynamic>{'commitment': commitment.name};
    if (filter != null) config['filter'] = filter;

    final result = await transport.send('getLargestAccounts', [config]);

    final value = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    return value
        .map((item) => AccountBalance.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
