import '../../core/json_rpc_transport.dart';
import '../models/eth_transaction.dart';
import '../models/eth_transaction_receipt.dart';

/// Transaction-related EVM JSON-RPC methods.
///
/// Provides typed access to `eth_getTransactionBy*`, `eth_getTransactionReceipt`,
/// and `eth_getBlockReceipts` RPC methods with proper nullable return types
/// for pending or not-found cases.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to an EVM RPC client class.
///
/// ```dart
/// class MyClient with EvmTransactionMethods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmTransactionMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Retrieves a transaction by its hash.
  ///
  /// Returns `null` if no transaction with the given [txHash] is found.
  /// Note: a pending transaction may be returned with `null` block fields.
  Future<EthTransaction?> getTransactionByHash(String txHash) async {
    final result = await transport.send('eth_getTransactionByHash', [txHash]);
    if (result == null) return null;
    return EthTransaction.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves a transaction by block hash and transaction [index] within that block.
  ///
  /// Returns `null` if the block or transaction index is not found.
  Future<EthTransaction?> getTransactionByBlockHashAndIndex(
    String blockHash,
    int index,
  ) async {
    final result = await transport.send(
      'eth_getTransactionByBlockHashAndIndex',
      [blockHash, '0x${index.toRadixString(16)}'],
    );
    if (result == null) return null;
    return EthTransaction.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves a transaction by block number/tag and transaction [index].
  ///
  /// Returns `null` if the block or transaction index is not found.
  ///
  /// The [blockTag] can be a hex block number (e.g., `'0x1b4'`) or one of
  /// `'latest'`, `'earliest'`, `'pending'`, `'safe'`, `'finalized'`.
  Future<EthTransaction?> getTransactionByBlockNumberAndIndex({
    String blockTag = 'latest',
    required int index,
  }) async {
    final result = await transport.send(
      'eth_getTransactionByBlockNumberAndIndex',
      [blockTag, '0x${index.toRadixString(16)}'],
    );
    if (result == null) return null;
    return EthTransaction.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves the receipt of a transaction by its hash.
  ///
  /// Returns `null` if the transaction is pending or not found.
  /// A non-null receipt indicates the transaction has been mined.
  Future<EthTransactionReceipt?> getTransactionReceipt(String txHash) async {
    final result = await transport.send('eth_getTransactionReceipt', [txHash]);
    if (result == null) return null;
    return EthTransactionReceipt.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves all transaction receipts for a given block.
  ///
  /// Returns `null` if the node does not support this method or the block
  /// is not found. Returns an empty list if the block has no transactions.
  ///
  /// This method uses `eth_getBlockReceipts` which is supported by most
  /// modern Ethereum nodes but may not be available on all providers.
  Future<List<EthTransactionReceipt>?> getBlockReceipts({
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getBlockReceipts', [blockTag]);
    if (result == null) return null;
    return (result as List)
        .map((e) => EthTransactionReceipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
