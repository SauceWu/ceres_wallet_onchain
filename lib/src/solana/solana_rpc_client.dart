/// The main Solana JSON-RPC client.
///
/// Exposes all 50 Solana RPC methods via mixin composition. Each method
/// group is implemented in a separate mixin for modularity:
///
/// - [SolanaAccountMethods] — account queries (getAccountInfo, getBalance, etc.)
/// - [SolanaTokenMethods] — SPL token queries (getTokenAccountBalance, etc.)
/// - [SolanaBlockMethods] — block and slot queries (getBlock, getSlot, etc.)
/// - [SolanaEpochMethods] — epoch queries (getEpochInfo, getLeaderSchedule, etc.)
/// - [SolanaTransactionMethods] — transaction queries and submission
/// - [SolanaFeeMethods] — fee estimation and blockhash queries
/// - [SolanaStakingMethods] — staking and inflation queries
/// - [SolanaClusterMethods] — cluster info, health, airdrop
///
/// **Signing boundary:** [sendTransaction] accepts a pre-signed, base64-encoded
/// transaction body. All signing must be done externally (e.g., via
/// `ceres_wallet_core`). This client does NOT perform any signing.
///
/// ```dart
/// final client = SolanaRpcClient(
///   transport: JsonRpcTransport(
///     config: RpcClientConfig(baseUrl: 'https://api.mainnet-beta.solana.com'),
///   ),
/// );
///
/// final balance = await client.getBalance(SolanaAddress('11111111111111111111111111111111'));
/// print('$balance lamports');
///
/// final blockhash = await client.getLatestBlockhash();
/// print('Blockhash: ${blockhash.blockhash}');
///
/// client.close();
/// ```
library;

import '../core/json_rpc_transport.dart';
import 'methods/account_methods.dart';
import 'methods/token_methods.dart';
import 'methods/block_methods.dart';
import 'methods/epoch_methods.dart';
import 'methods/transaction_methods.dart';
import 'methods/fee_methods.dart';
import 'methods/staking_methods.dart';
import 'methods/cluster_methods.dart';

/// The main Solana JSON-RPC client.
///
/// Combines all Solana RPC method mixins into a single client class.
/// Create an instance with a [JsonRpcTransport] and use it to call
/// any of the 50 supported Solana RPC methods.
class SolanaRpcClient
    with
        SolanaAccountMethods,
        SolanaTokenMethods,
        SolanaBlockMethods,
        SolanaEpochMethods,
        SolanaTransactionMethods,
        SolanaFeeMethods,
        SolanaStakingMethods,
        SolanaClusterMethods {
  @override
  final JsonRpcTransport transport;

  /// Creates a [SolanaRpcClient] with the given [transport].
  SolanaRpcClient({required this.transport});

  /// Closes the underlying transport connection.
  ///
  /// After calling [close], the client should not be used for further requests.
  void close() => transport.close();
}
