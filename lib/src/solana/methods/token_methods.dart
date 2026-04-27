/// Solana SPL Token-related RPC methods.
///
/// Provides methods for querying token accounts, balances, supply,
/// and largest token holders.
library;

import '../../core/json_rpc_transport.dart';
import '../models/token_account.dart';
import '../models/token_amount.dart';
import '../models/token_largest_account.dart';
import '../solana_address.dart';
import '../solana_commitment.dart';

/// SPL Token-related Solana RPC methods.
///
/// Provides SOL-06 through SOL-10:
/// - [getTokenAccountBalance] — query token account balance
/// - [getTokenAccountsByOwner] — query token accounts by wallet owner
/// - [getTokenAccountsByDelegate] — query token accounts by delegate
/// - [getTokenLargestAccounts] — query largest holders of a token
/// - [getTokenSupply] — query total token supply
mixin SolanaTokenMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns the token balance for the given token [pubkey] (account address).
  ///
  /// Calls `getTokenAccountBalance`. Returns a [TokenAmount] with the raw
  /// amount string, decimals, and optional UI amount string.
  ///
  /// ```dart
  /// final balance = await client.getTokenAccountBalance(tokenAccountAddr);
  /// print('${balance.uiAmountString} tokens');
  /// ```
  Future<TokenAmount> getTokenAccountBalance(
    String pubkey, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
  }) async {
    final result = await transport.send('getTokenAccountBalance', [
      pubkey,
      {'commitment': commitment.name},
    ]);

    final value = (result as Map<String, dynamic>)['value'];
    return TokenAmount.fromJson(value as Map<String, dynamic>);
  }

  /// Returns all token accounts owned by [owner] matching the given filter.
  ///
  /// Calls `getTokenAccountsByOwner`. Exactly one of [mint] or [programId]
  /// must be provided to filter results. Throws [ArgumentError] if neither
  /// or both are specified.
  ///
  /// ```dart
  /// final accounts = await client.getTokenAccountsByOwner(
  ///   walletAddr,
  ///   mint: SolanaAddress(usdcMint),
  /// );
  /// ```
  Future<List<TokenAccount>> getTokenAccountsByOwner(
    SolanaAddress owner, {
    SolanaAddress? mint,
    SolanaAddress? programId,
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String encoding = 'jsonParsed',
  }) async {
    if (mint == null && programId == null) {
      throw ArgumentError(
        'Either mint or programId must be provided for getTokenAccountsByOwner',
      );
    }

    final filter = <String, dynamic>{};
    if (mint != null) {
      filter['mint'] = mint.toBase58();
    } else {
      filter['programId'] = programId!.toBase58();
    }

    final result = await transport.send('getTokenAccountsByOwner', [
      owner.toBase58(),
      filter,
      {'commitment': commitment.name, 'encoding': encoding},
    ]);

    final value = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    return value
        .map((item) => TokenAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Returns all token accounts delegated to [delegate] matching the filter.
  ///
  /// Calls `getTokenAccountsByDelegate`. Exactly one of [mint] or [programId]
  /// must be provided. Throws [ArgumentError] if neither or both are specified.
  ///
  /// ```dart
  /// final accounts = await client.getTokenAccountsByDelegate(
  ///   delegateAddr,
  ///   programId: SolanaAddress(tokenProgram),
  /// );
  /// ```
  Future<List<TokenAccount>> getTokenAccountsByDelegate(
    SolanaAddress delegate, {
    SolanaAddress? mint,
    SolanaAddress? programId,
    SolanaCommitment commitment = SolanaCommitment.finalized,
    String encoding = 'jsonParsed',
  }) async {
    if (mint == null && programId == null) {
      throw ArgumentError(
        'Either mint or programId must be provided for getTokenAccountsByDelegate',
      );
    }

    final filter = <String, dynamic>{};
    if (mint != null) {
      filter['mint'] = mint.toBase58();
    } else {
      filter['programId'] = programId!.toBase58();
    }

    final result = await transport.send('getTokenAccountsByDelegate', [
      delegate.toBase58(),
      filter,
      {'commitment': commitment.name, 'encoding': encoding},
    ]);

    final value = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    return value
        .map((item) => TokenAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Returns the largest token accounts for the given [mint].
  ///
  /// Calls `getTokenLargestAccounts`. Returns a list of
  /// [TokenLargestAccount] entries with address, amount, decimals,
  /// and optional UI amount string.
  ///
  /// ```dart
  /// final largest = await client.getTokenLargestAccounts(usdcMint);
  /// print(largest.first.address);
  /// ```
  Future<List<TokenLargestAccount>> getTokenLargestAccounts(
    SolanaAddress mint, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
  }) async {
    final result = await transport.send('getTokenLargestAccounts', [
      mint.toBase58(),
      {'commitment': commitment.name},
    ]);

    final value = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    return value
        .map(
          (item) => TokenLargestAccount.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Returns the total supply of the token identified by [mint].
  ///
  /// Calls `getTokenSupply`. Returns a [TokenAmount] with the total
  /// supply as a raw amount string.
  ///
  /// ```dart
  /// final supply = await client.getTokenSupply(usdcMint);
  /// print('Total supply: ${supply.uiAmountString}');
  /// ```
  Future<TokenAmount> getTokenSupply(
    SolanaAddress mint, {
    SolanaCommitment commitment = SolanaCommitment.finalized,
  }) async {
    final result = await transport.send('getTokenSupply', [
      mint.toBase58(),
      {'commitment': commitment.name},
    ]);

    final value = (result as Map<String, dynamic>)['value'];
    return TokenAmount.fromJson(value as Map<String, dynamic>);
  }
}
