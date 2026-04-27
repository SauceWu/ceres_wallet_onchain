/// Transaction-related Tron HTTP API methods.
///
/// Provides 8 endpoints for creating, broadcasting, and querying
/// Tron transactions.
///
/// All methods use base58 visible format (`visible: true`) for addresses.
library;

import '../models/tron_broadcast_result.dart';
import '../models/tron_transaction.dart';
import '../models/tron_transaction_info.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// Transaction-related Tron REST API methods.
///
/// Requires a [RestTransport] to send HTTP POST requests to Tron nodes.
/// Mix this into a Tron client class that provides the [transport].
///
/// All 8 methods correspond to TRON-09 through TRON-16:
///
/// | ID      | Method                         | Endpoint                               |
/// |---------|--------------------------------|----------------------------------------|
/// | TRON-09 | createTransaction              | /wallet/createtransaction               |
/// | TRON-10 | broadcastTransaction           | /wallet/broadcasttransaction            |
/// | TRON-11 | broadcastHex                   | /wallet/broadcasthex                   |
/// | TRON-12 | getTransactionById             | /wallet/gettransactionbyid              |
/// | TRON-13 | getTransactionByIdSolidity     | /walletsolidity/gettransactionbyid      |
/// | TRON-14 | getTransactionInfoById         | /wallet/gettransactioninfobyid          |
/// | TRON-15 | getTransactionInfoByIdSolidity | /walletsolidity/gettransactioninfobyid  |
/// | TRON-16 | getTransactionInfoByBlockNum   | /wallet/gettransactioninfobyblocknum    |
mixin TronTransactionMethods {
  /// The REST transport used to send requests.
  RestTransport get transport;

  /// Creates an unsigned TRX transfer transaction.
  ///
  /// Calls `POST /wallet/createtransaction`. Returns an unsigned
  /// [TronTransaction] that must be signed before broadcasting.
  ///
  /// The [amount] is in sun (1 TRX = 1,000,000 sun).
  ///
  /// Throws [RpcException] if the Tron node returns an error.
  ///
  /// ```dart
  /// final tx = await client.createTransaction(
  ///   ownerAddress: sender,
  ///   toAddress: receiver,
  ///   amount: BigInt.from(1000000), // 1 TRX
  /// );
  /// ```
  Future<TronTransaction> createTransaction({
    required TronAddress ownerAddress,
    required TronAddress toAddress,
    required BigInt amount,
  }) async {
    final result = await transport.post('/wallet/createtransaction', {
      'owner_address': ownerAddress.toBase58(),
      'to_address': toAddress.toBase58(),
      'amount': amount.toInt(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Broadcasts a signed transaction to the network.
  ///
  /// Calls `POST /wallet/broadcasttransaction`. The [signedTransaction]
  /// must be a complete transaction JSON including the `signature` field.
  ///
  /// Returns a [TronBroadcastResult] indicating success or failure.
  Future<TronBroadcastResult> broadcastTransaction(
    Map<String, dynamic> signedTransaction,
  ) async {
    final result = await transport.post(
      '/wallet/broadcasttransaction',
      signedTransaction,
    );
    return TronBroadcastResult.fromJson(result);
  }

  /// Broadcasts a signed transaction as a hex string.
  ///
  /// Calls `POST /wallet/broadcasthex`. The [transaction] is the
  /// hex-encoded signed transaction bytes.
  ///
  /// Returns a [TronBroadcastResult] indicating success or failure.
  Future<TronBroadcastResult> broadcastHex(String transaction) async {
    final result = await transport.post('/wallet/broadcasthex', {
      'transaction': transaction,
    });
    return TronBroadcastResult.fromJson(result);
  }

  /// Returns a transaction by its ID, or `null` if not found.
  ///
  /// Calls `POST /wallet/gettransactionbyid`.
  Future<TronTransaction?> getTransactionById(String txId) async {
    final result = await transport.post('/wallet/gettransactionbyid', {
      'value': txId,
    });
    if (result.isEmpty) return null;
    return TronTransaction.fromJson(result);
  }

  /// Returns a transaction by its ID from a Solidity node, or `null`.
  ///
  /// Calls `POST /walletsolidity/gettransactionbyid`.
  Future<TronTransaction?> getTransactionByIdSolidity(String txId) async {
    final result = await transport.post('/walletsolidity/gettransactionbyid', {
      'value': txId,
    });
    if (result.isEmpty) return null;
    return TronTransaction.fromJson(result);
  }

  /// Returns transaction info (receipt) by ID, or `null` if not found.
  ///
  /// Calls `POST /wallet/gettransactioninfobyid`.
  Future<TronTransactionInfo?> getTransactionInfoById(String txId) async {
    final result = await transport.post('/wallet/gettransactioninfobyid', {
      'value': txId,
    });
    if (result.isEmpty) return null;
    return TronTransactionInfo.fromJson(result);
  }

  /// Returns transaction info by ID from a Solidity node, or `null`.
  ///
  /// Calls `POST /walletsolidity/gettransactioninfobyid`.
  Future<TronTransactionInfo?> getTransactionInfoByIdSolidity(
    String txId,
  ) async {
    final result = await transport.post(
      '/walletsolidity/gettransactioninfobyid',
      {'value': txId},
    );
    if (result.isEmpty) return null;
    return TronTransactionInfo.fromJson(result);
  }

  /// Returns all transaction info entries in a specific block.
  ///
  /// Calls `POST /wallet/gettransactioninfobyblocknum`.
  /// Returns an empty list if no transactions exist in the block.
  Future<List<TronTransactionInfo>> getTransactionInfoByBlockNum(
    int blockNum,
  ) async {
    final result = await transport.post(
      '/wallet/gettransactioninfobyblocknum',
      {'num': blockNum},
    );
    // The API returns a map with an array, or an empty map
    if (result.isEmpty) return [];
    // The response wraps the list in a map when using REST transport
    // but getTransactionInfoByBlockNum returns a JSON array directly.
    // Since RestTransport.post returns Map, we handle the wrapper.
    if (result.containsKey('transactionInfo')) {
      final list = result['transactionInfo'] as List<dynamic>;
      return list
          .map((e) => TronTransactionInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
