## 0.2.1

### Fixed

- `README_ZH.md`: sync version badge to `^0.2.0`, add transaction-history section and feature table entry (was missing since 0.2.0).
- Remove `.planning/` internal artifacts from git tracking.

---

## 0.2.0

### Added — Optional transaction-history extension

A new opt-in layer for paginated, multi-chain transaction history.
Imported via the **separate** `package:ceres_wallet_onchain/tx_history.dart`
barrel — the v1.0 surface is unchanged and existing 0.1.x consumers
pay zero cost (no new dependencies, no main-barrel additions, no
behavioural drift in the RPC clients).

- `TxHistoryProvider<T>` — neutral interface with `TxHistoryQuery`,
  `TxHistoryPage<T>`, and a sealed `TxHistoryCursor` hierarchy
  (compile-time exhaustiveness across chains).
- `TxHistoryException` — extends `RpcException`, with
  `InvalidCursorException` and `TxHistoryApiException` (structured
  upstream errors, api-key-redacted endpoint).
- `RateLimitedException` (extends `RpcHttpException`) — carries the
  upstream `Retry-After` hint via `RateLimitInfo`. Lives next to
  `EndpointPool` because it sits in the v1.0 transport-error
  hierarchy rather than the `tx_history` layer.
- Five concrete providers, each composing the existing v1.0 client
  (LD-6 — composition, not inheritance):
  * `SolanaNativeProvider` — two-step composite over
    `getSignaturesForAddress` + concurrency-capped `getTransaction`
    (default 4 in flight, 429 halts the batch instead of retry-storming).
  * `SuiNativeProvider` — `sui_queryTransactionBlocks` with opaque
    cursor pass-through; separate `listFromAddress` / `listToAddress`
    methods because Sui RPC enforces FromAddress xor ToAddress.
  * `EvmBlockscoutProvider` — Blockscout v2 REST with multi-instance
    failover via `EndpointPool`.
  * `EvmEtherscanProvider` — Etherscan v1 per-chain hosts OR v2
    multichain mode; api-key redaction on every error path.
  * `TronGridProvider` — `/v1/accounts/{addr}/transactions` and
    `/transactions/trc20` with opaque fingerprint cursor.
- `EndpointPool` + `RateLimitedException` — multi-endpoint
  round-robin failover primitive with `Retry-After` honouring.
- `RestHistoryClient` + `ConcurrencyLimiter` — advanced primitives
  for users building custom REST providers or fan-out batches.
- `package:ceres_wallet_onchain/tx_history_testing.dart` — separate
  test-only barrel exporting `MockTxHistoryProvider<T>` for
  downstream unit tests, kept out of the production import path so
  test scaffolding is never tree-shaken into apps.

### Architectural notes

- Architectural firewall: `lib/ceres_wallet_onchain.dart` is byte-
  identical to 0.1.1 — nothing in the v1.0 import surface mentions
  `tx_history`, and reverse imports from `lib/src/{core,abi,evm,
  solana,sui,tron,utils}` into the extension layer are blocked by
  `test/tx_history/architectural_firewall_test.dart`.
- Lifecycle contract: every provider implements an ownership-flag
  `close()` — caller-injected transports stay alive; provider-built
  transports get torn down once. Verified by
  `test/tx_history/lifecycle_close_test.dart`.
- Mobile guidance: every public `listTransactions` carries dartdoc
  steering callers to `Isolate.run` for large pages.

### Zero-impact upgrade for 0.1.x users

- No new pub dependencies (still `http`, `hex`, `blockchain_utils`).
- No new exports from the main barrel.
- No source-level changes to v1.0 RPC clients.

See `example/tx_history_example.dart` for one query per chain
against live mainnet endpoints.

## 0.1.1

- EIP-712/191 hashing layer (EIP712Parser, EIP712Hasher, EIP191Hasher)
- Solana transaction wire codec (SolanaTxDecoder, SolanaTxEncoder, compact-u16)
- AltResolver: v0 transaction address lookup table resolution with concurrent fetching
- ComputeBudgetDecoder: all 4 ComputeBudget instruction variants
- Fix: AltResolver crash on empty AccountInfo.data (WR-01)
- Fix: EIP712Hasher now treats absent optional fields as zero values, matching ethers.js behavior (WR-02)

## 0.1.0

- Initial release
- EVM RPC client with 49 typed methods (eth_, net_, web3_ namespaces)
- Tron HTTP client with 65 typed endpoints
- Solana RPC client with 50 typed methods
- Sui RPC client with 39 typed methods (sui_ and suix_ namespaces)
- Complete ABI encoder/decoder (address, uint, bool, bytes, string, tuple, arrays)
- Function selector computation via keccak256
- Unified RPC exception model with retry support
- Pure Dart -- no Flutter dependency
