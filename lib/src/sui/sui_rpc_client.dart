/// The main Sui JSON-RPC client.
///
/// Exposes all 39 Sui RPC methods via mixin composition. Each method
/// group is implemented in a separate mixin for modularity:
///
/// - [SuiTransactionMethods] -- transaction queries, execution, simulation (7 methods)
/// - [SuiObjectMethods] -- object queries and past version lookup (4 methods)
/// - [SuiChainMethods] -- checkpoints, chain ID, protocol config, system state (7 methods)
/// - [SuiEventMethods] -- event queries by digest and filter (2 methods)
/// - [SuiMoveMethods] -- Move module/function/struct introspection, committee info (5 methods)
/// - [SuiCoinMethods] -- balances, coin objects, metadata, supply, owned objects (7 methods)
/// - [SuiGovernanceMethods] -- delegation stakes and validator APY (3 methods)
/// - [SuiExtendedMethods] -- dynamic fields and SuiNS name service (4 methods)
///
/// **Signing boundary:** [executeTransactionBlock] accepts pre-signed transaction
/// bytes and signatures. All signing must be done externally (e.g., via
/// `ceres_wallet_core`). This client does NOT perform any signing.
///
/// ```dart
/// final client = SuiRpcClient(
///   transport: JsonRpcTransport(
///     config: RpcClientConfig(baseUrl: 'https://fullnode.mainnet.sui.io'),
///   ),
/// );
///
/// final balance = await client.getBalance(SuiAddress('0xabc...'));
/// print('SUI: ${balance.totalBalance}');
///
/// client.close();
/// ```
library;

import '../core/json_rpc_transport.dart';
import 'methods/transaction_methods.dart';
import 'methods/object_methods.dart';
import 'methods/chain_methods.dart';
import 'methods/event_methods.dart';
import 'methods/move_methods.dart';
import 'methods/coin_methods.dart';
import 'methods/governance_methods.dart';
import 'methods/extended_methods.dart';

/// The main Sui JSON-RPC client.
///
/// Combines all Sui RPC method mixins into a single client class.
/// Create an instance with a [JsonRpcTransport] and use it to call
/// any of the 39 supported Sui RPC methods.
class SuiRpcClient
    with
        SuiTransactionMethods,
        SuiObjectMethods,
        SuiChainMethods,
        SuiEventMethods,
        SuiMoveMethods,
        SuiCoinMethods,
        SuiGovernanceMethods,
        SuiExtendedMethods {
  @override
  final JsonRpcTransport transport;

  /// Creates a [SuiRpcClient] with the given [transport].
  SuiRpcClient({required this.transport});

  /// Closes the underlying transport connection.
  ///
  /// After calling [close], the client should not be used for further requests.
  void close() => transport.close();
}
