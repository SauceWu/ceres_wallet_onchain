import '../core/rest_transport.dart';
import 'methods/account_methods.dart';
import 'methods/transaction_methods.dart';
import 'methods/block_methods.dart';
import 'methods/contract_methods.dart';
import 'methods/staking_methods.dart';
import 'methods/witness_methods.dart';
import 'methods/asset_methods.dart';
import 'methods/network_methods.dart';
import 'methods/multisig_methods.dart';

/// The main Tron HTTP API client.
///
/// Exposes all 65 Tron REST API methods via mixin composition.
/// Each method group is implemented in a separate mixin for modularity.
///
/// **Signing boundary:** This client does NOT handle transaction signing.
/// Methods like [triggerSmartContract] and [createTransaction] return
/// unsigned transaction bodies. Signing must be done externally
/// (e.g., via `ceres_wallet_core`) before calling [broadcastHex].
///
/// ```dart
/// final client = TronHttpClient(
///   transport: RestTransport(
///     config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
///   ),
/// );
///
/// final account = await client.getAccount(TronAddress('T...'));
/// print('Balance: ${account?.balance} sun');
///
/// client.close();
/// ```
class TronHttpClient
    with
        TronAccountMethods,
        TronTransactionMethods,
        TronBlockMethods,
        TronContractMethods,
        TronStakingMethods,
        TronWitnessMethods,
        TronAssetMethods,
        TronNetworkMethods,
        TronMultisigMethods {
  @override
  final RestTransport transport;

  /// Creates a [TronHttpClient] with the given [transport].
  TronHttpClient({required this.transport});

  /// Closes the underlying HTTP transport.
  void close() => transport.close();
}
