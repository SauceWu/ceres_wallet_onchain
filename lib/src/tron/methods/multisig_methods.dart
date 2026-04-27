/// Multi-signature account management methods for the Tron HTTP API.
///
/// Provides endpoints to update account permissions and verify
/// multi-signature transaction approval status.
///
/// ```dart
/// // Update account permissions (returns unsigned transaction):
/// final tx = await client.accountPermissionUpdate(
///   ownerAddress: TronAddress('TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf'),
///   owner: {'type': 0, 'permission_name': 'owner', ...},
///   actives: [{'type': 2, 'permission_name': 'active0', ...}],
/// );
///
/// // Check which addresses approved a signed transaction:
/// final approved = await client.getApprovedList(signedTxJson);
/// ```
library;

import '../models/tron_transaction.dart';
import '../tron_address.dart';
import '../tron_error.dart';
import '../../core/rest_transport.dart';

/// Mixin providing 3 Tron multi-signature endpoints (TRON-63 ~ TRON-65).
///
/// [accountPermissionUpdate] is a transaction-creating endpoint that
/// returns an unsigned [TronTransaction]. The other two are query
/// endpoints that accept a signed transaction JSON and return
/// approval/weight information.
mixin TronMultisigMethods {
  /// The REST transport used to send HTTP requests.
  RestTransport get transport;

  /// Updates account permissions (owner, active, witness).
  ///
  /// Endpoint: `POST /wallet/accountpermissionupdate`
  ///
  /// Returns an unsigned [TronTransaction] that must be signed by the
  /// current owner key before broadcasting.
  ///
  /// - [ownerAddress]: The account whose permissions to update.
  /// - [owner]: Owner permission configuration (threshold, keys).
  /// - [actives]: List of active permission configurations.
  /// - [witness]: Optional witness permission (for SR accounts only).
  ///
  /// Throws [RpcException] if the server returns an error (e.g.,
  /// invalid permission configuration).
  ///
  /// ```dart
  /// final tx = await client.accountPermissionUpdate(
  ///   ownerAddress: TronAddress('TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf'),
  ///   owner: {
  ///     'type': 0,
  ///     'permission_name': 'owner',
  ///     'threshold': 2,
  ///     'keys': [
  ///       {'address': 'TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf', 'weight': 1},
  ///       {'address': 'TAnother...', 'weight': 1},
  ///     ],
  ///   },
  ///   actives: [
  ///     {
  ///       'type': 2,
  ///       'permission_name': 'active0',
  ///       'threshold': 1,
  ///       'operations': '7fff1fc0033ec307...',
  ///       'keys': [
  ///         {'address': 'TVJjFxDjQhKqejxfhFhapYeCsUEKiZ6Tqf', 'weight': 1},
  ///       ],
  ///     },
  ///   ],
  /// );
  /// ```
  Future<TronTransaction> accountPermissionUpdate({
    required TronAddress ownerAddress,
    required Map<String, dynamic> owner,
    Map<String, dynamic>? witness,
    required List<Map<String, dynamic>> actives,
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'owner': owner,
      'actives': actives,
      'visible': true,
    };
    if (witness != null) body['witness'] = witness;
    final result = await transport.post(
      '/wallet/accountpermissionupdate',
      body,
    );
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// Returns the list of addresses that have approved a transaction.
  ///
  /// Endpoint: `POST /wallet/getapprovedlist`
  ///
  /// Accepts a complete signed transaction JSON (including signatures)
  /// and returns which addresses have provided valid signatures.
  ///
  /// ```dart
  /// final result = await client.getApprovedList(signedTxJson);
  /// final approved = result['approved_list'] as List?;
  /// ```
  Future<Map<String, dynamic>> getApprovedList(
    Map<String, dynamic> transaction,
  ) async {
    return await transport.post('/wallet/getapprovedlist', transaction);
  }

  /// Returns the current signature weight of a transaction.
  ///
  /// Endpoint: `POST /wallet/getsignweight`
  ///
  /// Accepts a complete signed transaction JSON and returns the
  /// total weight of valid signatures versus the required threshold.
  ///
  /// ```dart
  /// final result = await client.getSignWeight(signedTxJson);
  /// final currentWeight = result['current_weight'];
  /// ```
  Future<Map<String, dynamic>> getSignWeight(
    Map<String, dynamic> transaction,
  ) async {
    return await transport.post('/wallet/getsignweight', transaction);
  }
}
