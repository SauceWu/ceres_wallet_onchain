import '../../core/json_rpc_transport.dart';
import '../../utils/bigint_utils.dart';
import '../models/eth_block.dart';

/// Block-related EVM JSON-RPC methods.
///
/// Provides typed access to `eth_getBlockBy*`, `eth_getBlockTransactionCountBy*`,
/// and `eth_getUncle*` RPC methods with proper nullable return types
/// for not-found cases.
///
/// This mixin requires a [JsonRpcTransport] via the abstract [transport] getter.
/// It is intended to be applied to an EVM RPC client class.
///
/// ```dart
/// class MyClient with EvmBlockMethods {
///   @override
///   final JsonRpcTransport transport;
///   MyClient(this.transport);
/// }
/// ```
mixin EvmBlockMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Retrieves a block by its hash.
  ///
  /// Returns `null` if no block with the given [blockHash] exists.
  ///
  /// When [fullTransactions] is `true`, the returned [EthBlock] contains
  /// full [EthTransaction] objects; otherwise it contains only transaction
  /// hash strings.
  Future<EthBlock?> getBlockByHash(
    String blockHash, {
    bool fullTransactions = false,
  }) async {
    final result = await transport.send('eth_getBlockByHash', [
      blockHash,
      fullTransactions,
    ]);
    if (result == null) return null;
    return EthBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves a block by its number or tag.
  ///
  /// Returns `null` if no block matches the given [blockTag].
  ///
  /// The [blockTag] can be a hex block number (e.g., `'0x1b4'`) or one of
  /// `'latest'`, `'earliest'`, `'pending'`, `'safe'`, `'finalized'`.
  ///
  /// When [fullTransactions] is `true`, the returned [EthBlock] contains
  /// full [EthTransaction] objects; otherwise it contains only transaction
  /// hash strings.
  Future<EthBlock?> getBlockByNumber({
    String blockTag = 'latest',
    bool fullTransactions = false,
  }) async {
    final result = await transport.send('eth_getBlockByNumber', [
      blockTag,
      fullTransactions,
    ]);
    if (result == null) return null;
    return EthBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the number of transactions in a block identified by [blockHash].
  ///
  /// Returns `null` if no block with the given hash exists.
  Future<BigInt?> getBlockTransactionCountByHash(String blockHash) async {
    final result = await transport.send('eth_getBlockTransactionCountByHash', [
      blockHash,
    ]);
    if (result == null) return null;
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the number of transactions in a block identified by [blockTag].
  ///
  /// Returns `null` if no block matches the given tag.
  Future<BigInt?> getBlockTransactionCountByNumber({
    String blockTag = 'latest',
  }) async {
    final result = await transport.send(
      'eth_getBlockTransactionCountByNumber',
      [blockTag],
    );
    if (result == null) return null;
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the number of uncles in a block identified by [blockHash].
  ///
  /// Returns `null` if no block with the given hash exists.
  Future<BigInt?> getUncleCountByBlockHash(String blockHash) async {
    final result = await transport.send('eth_getUncleCountByBlockHash', [
      blockHash,
    ]);
    if (result == null) return null;
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Returns the number of uncles in a block identified by [blockTag].
  ///
  /// Returns `null` if no block matches the given tag.
  Future<BigInt?> getUncleCountByBlockNumber({
    String blockTag = 'latest',
  }) async {
    final result = await transport.send('eth_getUncleCountByBlockNumber', [
      blockTag,
    ]);
    if (result == null) return null;
    return BigIntUtils.hexToBigInt(result as String);
  }

  /// Retrieves an uncle block by the parent block hash and uncle [index].
  ///
  /// Returns `null` if no uncle exists at the given index or the block
  /// is not found.
  Future<EthBlock?> getUncleByBlockHashAndIndex(
    String blockHash,
    int index,
  ) async {
    final result = await transport.send('eth_getUncleByBlockHashAndIndex', [
      blockHash,
      '0x${index.toRadixString(16)}',
    ]);
    if (result == null) return null;
    return EthBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Retrieves an uncle block by the parent block tag and uncle [index].
  ///
  /// Returns `null` if no uncle exists at the given index or the block
  /// is not found.
  Future<EthBlock?> getUncleByBlockNumberAndIndex({
    String blockTag = 'latest',
    required int index,
  }) async {
    final result = await transport.send('eth_getUncleByBlockNumberAndIndex', [
      blockTag,
      '0x${index.toRadixString(16)}',
    ]);
    if (result == null) return null;
    return EthBlock.fromJson(result as Map<String, dynamic>);
  }
}
