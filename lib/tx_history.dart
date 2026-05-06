/// Optional transaction-history extension for `ceres_wallet_onchain`.
///
/// This library is **opt-in** — it is intentionally NOT re-exported by
/// the main package barrel `package:ceres_wallet_onchain/ceres_wallet_onchain.dart`
/// (LD-2 firewall). Adopters import it explicitly alongside the core:
///
/// ```dart
/// import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart'; // core
/// import 'package:ceres_wallet_onchain/tx_history.dart';            // extension
/// ```
///
/// What's exported:
///
/// **HIST-CORE shared abstractions**
///
/// - [TxHistoryProvider] — abstract interface every chain implements
/// - [TxHistoryCursor] sealed hierarchy — `BlockscoutCursor`,
///   `EtherscanCursor`, `SolanaCursor`, `SuiCursor`, `TronGridCursor`
/// - [TxHistoryPage] — generic paginated response wrapper
/// - [TxHistoryQuery] — neutral request shape
/// - [TxHistoryException] hierarchy — extends `RpcException` (LD-7)
/// - [EndpointPool] + [RateLimitedException] — multi-endpoint round-robin
///   primitive used by REST providers (Blockscout / Etherscan / TronGrid)
///
/// **Provider classes (public API entry points)**
///
/// - [SolanaNativeProvider] + [SolanaHistoryTransaction] — composes
///   the v1.0 `SolanaRpcClient`; concurrency-capped batched
///   `getTransaction`.
/// - [SuiNativeProvider] — composes the v1.0 `SuiRpcClient`; opaque
///   cursor pass-through; separate FromAddress / ToAddress methods.
/// - [EvmBlockscoutProvider] — Blockscout v2 REST; multi-instance
///   failover via [EndpointPool].
/// - [EvmEtherscanProvider] — Etherscan v1 per-chain hosts OR v2
///   multichain mode; api-key redaction on all error paths.
/// - [TronGridProvider] — TronGrid `/v1/accounts/{addr}/transactions`
///   and `/transactions/trc20`; fingerprint cursor.
///
/// **Advanced primitives (for users building custom REST providers)**
///
/// - [RestHistoryClient] — thin GET helper around [EndpointPool] with
///   https-only validation, JSON parsing, and 429 → Retry-After mapping.
/// - [ConcurrencyLimiter] — bounded semaphore used by
///   [SolanaNativeProvider] for fan-out batches.
library ceres_wallet_onchain.tx_history;

// HIST-CORE shared abstractions.
export 'src/tx_history/tx_history_provider.dart';
export 'src/tx_history/tx_history_cursor.dart';
export 'src/tx_history/tx_history_page.dart';
export 'src/tx_history/tx_history_query.dart';
export 'src/tx_history/tx_history_exception.dart';
export 'src/tx_history/endpoint_pool.dart';

// Provider classes (public API entry points).
export 'src/tx_history/solana/solana_native_provider.dart'
    show SolanaNativeProvider;
export 'src/tx_history/solana/solana_history_models.dart'
    show SolanaHistoryTransaction;
export 'src/tx_history/sui/sui_native_provider.dart' show SuiNativeProvider;
export 'src/tx_history/evm/blockscout/evm_blockscout_provider.dart'
    show EvmBlockscoutProvider;
export 'src/tx_history/evm/etherscan/evm_etherscan_provider.dart'
    show EvmEtherscanProvider;
export 'src/tx_history/tron/trongrid_provider.dart' show TronGridProvider;

// Advanced primitives (for users building custom providers).
export 'src/tx_history/_internal/rest_history_client.dart'
    show RestHistoryClient;
export 'src/tx_history/solana/concurrency_limiter.dart' show ConcurrencyLimiter;
