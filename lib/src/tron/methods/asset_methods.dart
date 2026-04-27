/// Tron TRC-10 asset methods mixin (TRON-51 ~ TRON-56).
///
/// Provides 6 endpoints for transferring TRC-10 tokens and querying
/// asset issue information.
///
/// Transaction-producing methods return an unsigned [TronTransaction]
/// that must be signed externally before broadcasting.
///
/// ```dart
/// class TronClient with TronAssetMethods {
///   @override
///   final RestTransport transport;
///   TronClient(this.transport);
/// }
/// ```
library;

import '../models/tron_asset_issue.dart';
import '../models/tron_transaction.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// TRC-10 asset methods for Tron HTTP API.
///
/// Requires a [RestTransport] instance via the [transport] getter.
/// Mixed into a Tron client class that provides the transport.
mixin TronAssetMethods {
  /// The REST transport used for HTTP API calls.
  RestTransport get transport;

  /// Transfers TRC-10 tokens from one account to another.
  ///
  /// [ownerAddress] is the sender.
  /// [toAddress] is the recipient.
  /// [assetName] is the TRC-10 token name (asset ID string).
  /// [amount] is the amount of tokens in the smallest unit.
  ///
  /// Returns an unsigned [TronTransaction].
  ///
  /// Endpoint: `POST /wallet/transferasset`
  Future<TronTransaction> transferAsset({
    required TronAddress ownerAddress,
    required TronAddress toAddress,
    required String assetName,
    required BigInt amount,
  }) async {
    final result = await transport.post('/wallet/transferasset', {
      'owner_address': ownerAddress.toBase58(),
      'to_address': toAddress.toBase58(),
      'asset_name': assetName,
      'amount': amount.toInt(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Queries a TRC-10 asset by its ID from the full node.
  ///
  /// Returns a [TronAssetIssue] with token metadata.
  ///
  /// Endpoint: `POST /wallet/getassetissuebyid`
  Future<TronAssetIssue> getAssetIssueById(String id) async {
    final result = await transport.post('/wallet/getassetissuebyid', {
      'value': id,
    });
    return TronAssetIssue.fromJson(result);
  }

  /// Queries a TRC-10 asset by its ID from a solidity node.
  ///
  /// Solidity nodes provide confirmed (finalized) data. Use this when
  /// you need guaranteed finality.
  ///
  /// Returns a [TronAssetIssue] with token metadata.
  ///
  /// Endpoint: `POST /walletsolidity/getassetissuebyid`
  Future<TronAssetIssue> getAssetIssueByIdSolidity(String id) async {
    final result = await transport.post('/walletsolidity/getassetissuebyid', {
      'value': id,
    });
    return TronAssetIssue.fromJson(result);
  }

  /// Lists all TRC-10 asset issues on the network.
  ///
  /// Returns a list of [TronAssetIssue] objects.
  ///
  /// Endpoint: `GET /wallet/getassetissuelist`
  Future<List<TronAssetIssue>> getAssetIssueList() async {
    final result = await transport.get('/wallet/getassetissuelist');
    final assets = result['assetIssue'] as List? ?? [];
    return assets
        .map((a) => TronAssetIssue.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Lists TRC-10 asset issues with pagination.
  ///
  /// [offset] is the starting index (default 0).
  /// [limit] is the maximum number of results (default 20).
  ///
  /// Returns a list of [TronAssetIssue] objects.
  ///
  /// Endpoint: `POST /wallet/getpaginatedassetissuelist`
  Future<List<TronAssetIssue>> getPaginatedAssetIssueList({
    int offset = 0,
    int limit = 20,
  }) async {
    final result = await transport.post('/wallet/getpaginatedassetissuelist', {
      'offset': offset,
      'limit': limit,
    });
    final assets = result['assetIssue'] as List? ?? [];
    return assets
        .map((a) => TronAssetIssue.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Lists all TRC-10 assets issued by a specific account.
  ///
  /// Returns a list of [TronAssetIssue] objects.
  ///
  /// Endpoint: `POST /wallet/getassetissuebyaccount`
  Future<List<TronAssetIssue>> getAssetIssueByAccount(
    TronAddress address,
  ) async {
    final result = await transport.post('/wallet/getassetissuebyaccount', {
      'address': address.toBase58(),
      'visible': true,
    });
    final assets = result['assetIssue'] as List? ?? [];
    return assets
        .map((a) => TronAssetIssue.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}
