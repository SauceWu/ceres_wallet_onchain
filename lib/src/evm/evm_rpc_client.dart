import '../core/json_rpc_transport.dart';
import 'methods/account_methods.dart';
import 'methods/block_methods.dart';
import 'methods/call_methods.dart';
import 'methods/filter_methods.dart';
import 'methods/gas_methods.dart';
import 'methods/log_methods.dart';
import 'methods/mining_methods.dart';
import 'methods/net_methods.dart';
import 'methods/send_methods.dart';
import 'methods/state_methods.dart';
import 'methods/transaction_methods.dart';
import 'methods/web3_methods.dart';

/// The main EVM JSON-RPC client.
///
/// Exposes all EVM RPC methods via mixin composition. Each method group
/// is implemented in a separate mixin for modularity.
///
/// ```dart
/// final client = EvmRpcClient(
///   transport: JsonRpcTransport(
///     config: RpcClientConfig(baseUrl: 'https://mainnet.infura.io/v3/KEY'),
///   ),
/// );
///
/// final balance = await client.getBalance(EvmAddress('0x...'));
/// final gasPrice = await client.gasPrice();
/// final chainId = await client.chainId();
///
/// client.close();
/// ```
class EvmRpcClient
    with
        EvmAccountMethods,
        EvmGasMethods,
        EvmCallMethods,
        EvmSendMethods,
        EvmStateMethods,
        EvmMiningMethods,
        EvmBlockMethods,
        EvmTransactionMethods,
        EvmFilterMethods,
        EvmLogMethods,
        EvmNetMethods,
        EvmWeb3Methods {
  @override
  final JsonRpcTransport transport;

  /// Creates an [EvmRpcClient] with the given [transport].
  EvmRpcClient({required this.transport});

  /// Closes the underlying transport connection.
  ///
  /// After calling [close], the client should not be used for further requests.
  void close() => transport.close();
}
