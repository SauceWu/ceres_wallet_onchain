/// Tron block query methods mixin (TRON-17 ~ TRON-24).
///
/// Provides typed access to all Tron block-related HTTP API endpoints,
/// including both fullnode (`/wallet/`) and solidity (`/walletsolidity/`)
/// variants.
///
/// This mixin requires a [RestTransport] via the abstract [transport] getter.
/// It is intended to be applied to a Tron HTTP client class.
///
/// ```dart
/// class TronClient with TronBlockMethods {
///   @override
///   final RestTransport transport;
///   TronClient(this.transport);
/// }
/// ```
library;

import '../models/tron_block.dart';
import '../../core/rest_transport.dart';

/// Block-related Tron HTTP API methods.
///
/// Covers 8 endpoints:
/// - [getNowBlock] / [getNowBlockSolidity] — latest block
/// - [getBlockByNum] / [getBlockByNumSolidity] — block by number
/// - [getBlockById] — block by hash
/// - [getBlockByLimitNext] — block range
/// - [getBlockByLatestNum] — latest N blocks
/// - [getBlock] — flexible block query
mixin TronBlockMethods {
  /// The REST transport used to send requests.
  RestTransport get transport;

  /// TRON-17: Returns the latest block from the fullnode.
  ///
  /// Sends a POST request with empty body to `/wallet/getnowblock`.
  Future<TronBlock> getNowBlock() async {
    final result = await transport.post('/wallet/getnowblock');
    return TronBlock.fromJson(result);
  }

  /// TRON-18: Returns the latest confirmed block from the solidity node.
  ///
  /// Sends a POST request with empty body to `/walletsolidity/getnowblock`.
  Future<TronBlock> getNowBlockSolidity() async {
    final result = await transport.post('/walletsolidity/getnowblock');
    return TronBlock.fromJson(result);
  }

  /// TRON-19: Returns a block by its number from the fullnode.
  ///
  /// [num] is the block height (0-indexed).
  Future<TronBlock> getBlockByNum(int num) async {
    final result = await transport.post('/wallet/getblockbynum', {'num': num});
    return TronBlock.fromJson(result);
  }

  /// TRON-20: Returns a block by its number from the solidity node.
  ///
  /// [num] is the block height (0-indexed).
  Future<TronBlock> getBlockByNumSolidity(int num) async {
    final result = await transport.post('/walletsolidity/getblockbynum', {
      'num': num,
    });
    return TronBlock.fromJson(result);
  }

  /// TRON-21: Returns a block by its hash ID.
  ///
  /// [blockId] is the 64-character hex block hash.
  Future<TronBlock> getBlockById(String blockId) async {
    final result = await transport.post('/wallet/getblockbyid', {
      'value': blockId,
    });
    return TronBlock.fromJson(result);
  }

  /// TRON-22: Returns a range of blocks by block number.
  ///
  /// Returns blocks from [startNum] (inclusive) to [endNum] (exclusive).
  /// The Tron API response format is `{"block": [...]}`.
  Future<List<TronBlock>> getBlockByLimitNext({
    required int startNum,
    required int endNum,
  }) async {
    final result = await transport.post('/wallet/getblockbylimitnext', {
      'startNum': startNum,
      'endNum': endNum,
    });
    final blocks = result['block'] as List? ?? [];
    return blocks
        .map((b) => TronBlock.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// TRON-23: Returns the latest [num] blocks.
  ///
  /// The Tron API response format is `{"block": [...]}`.
  Future<List<TronBlock>> getBlockByLatestNum(int num) async {
    final result = await transport.post('/wallet/getblockbylatestnum', {
      'num': num,
    });
    final blocks = result['block'] as List? ?? [];
    return blocks
        .map((b) => TronBlock.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// TRON-24: Flexible block query by ID, number, or latest.
  ///
  /// [idOrNum] can be a block hash or block number string. If omitted,
  /// returns the latest block.
  /// [detail] controls whether full transaction details are included.
  Future<TronBlock> getBlock({String? idOrNum, bool detail = false}) async {
    final body = <String, dynamic>{'detail': detail};
    if (idOrNum != null) {
      body['id_or_num'] = idOrNum;
    }
    final result = await transport.post('/wallet/getblock', body);
    return TronBlock.fromJson(result);
  }
}
