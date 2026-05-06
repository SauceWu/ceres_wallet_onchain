# ceres_wallet_onchain

[![pub package](https://img.shields.io/pub/v/ceres_wallet_onchain.svg)](https://pub.dev/packages/ceres_wallet_onchain)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.8.0-blue)](https://dart.dev)

A pure Dart multi-chain RPC SDK covering **EVM / Tron / Solana / Sui** with complete RPC method coverage, typed response parsing, ABI encoding, and a DApp codec layer.

[中文文档](README_ZH.md)

---

## Features

| Category | What's included |
|----------|----------------|
| **EVM RPC** | 49 typed methods — `eth_`, `net_`, `web3_` namespaces |
| **Tron HTTP** | 65 typed endpoints — accounts, transactions, staking, TRC-20 contracts |
| **Solana RPC** | 50 typed methods — accounts, SPL tokens, blocks, staking, fees |
| **Sui RPC** | 39 typed methods — `sui_` and `suix_` namespaces |
| **ABI codec** | Encode/decode `address`, `uint/int`, `bool`, `bytes`, `string`, `tuple`, arrays |
| **Function selector** | keccak256-based 4-byte selector computation |
| **EIP-712 / EIP-191** | Parse typed data → `TypedDataV4`, compute 32-byte digest for MPC/signing |
| **Solana tx codec** | Decode/encode legacy + v0 transactions (wire bytes), compact-u16, AltResolver, ComputeBudgetDecoder |
| **Unified exceptions** | `RpcException` hierarchy with automatic retry and timeout |
| **Pure Dart** | No Flutter dependency — works in any Dart environment |

---

## Installation

```yaml
dependencies:
  ceres_wallet_onchain: ^0.2.0
```

```bash
dart pub add ceres_wallet_onchain
```

```dart
import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
```

---

## Quick Start

### EVM

```dart
final client = EvmRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY'),
  ),
);

final balance = await client.getBalance(
  EvmAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'),
);
print('Balance: $balance wei');

final gasPrice = await client.gasPrice();
final chainId  = await client.chainId();

client.close();
```

### Tron

```dart
final client = TronHttpClient(
  transport: RestTransport(
    config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
  ),
);

final account = await client.getAccount(
  TronAddress('TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy'),
);
print('Balance: ${account?.balance} sun');

client.close();
```

### Solana

```dart
final client = SolanaRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://api.mainnet-beta.solana.com'),
  ),
);

final balance   = await client.getBalance(SolanaAddress('11111111111111111111111111111111'));
final blockhash = await client.getLatestBlockhash();
print('$balance lamports, blockhash: ${blockhash.blockhash}');

client.close();
```

### Sui

```dart
final client = SuiRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://fullnode.mainnet.sui.io'),
  ),
);

final balance = await client.getBalance(SuiAddress('0xabc...'));
print('Total SUI: ${balance.totalBalance}');

client.close();
```

---

## Optional: Transaction History

Since 0.2.0 the package ships an **opt-in** transaction-history layer
behind a separate barrel — it is NOT exported from the main package
import, so existing 0.1.x users pay zero cost (no new dependencies,
no main-barrel additions).

```dart
import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart'; // core (unchanged)
import 'package:ceres_wallet_onchain/tx_history.dart';            // optional
```

| Provider                | Backend                                               |
| ----------------------- | ----------------------------------------------------- |
| `SolanaNativeProvider`  | Solana JSON-RPC `getSignaturesForAddress` + batched `getTransaction` |
| `SuiNativeProvider`     | Sui JSON-RPC `sui_queryTransactionBlocks`             |
| `EvmBlockscoutProvider` | Blockscout v2 REST (`/api/v2/addresses/.../transactions`) |
| `EvmEtherscanProvider`  | Etherscan v1 per-chain hosts OR v2 multichain         |
| `TronGridProvider`      | TronGrid `/v1/accounts/{addr}/transactions` and `/transactions/trc20` |

Every provider exposes the same `TxHistoryProvider<T>` interface
(`listTransactions`, `list`, `close`) and uses a sealed
`TxHistoryCursor` hierarchy for compile-time exhaustiveness across
chains. Providers compose the existing v1.0 clients (the Solana and
Sui providers wrap `SolanaRpcClient` / `SuiRpcClient`; the EVM and
Tron providers reuse the shared `EndpointPool` + `RestHistoryClient`
primitives).

Mobile guidance: each `listTransactions` carries dartdoc steering
callers to `Isolate.run` for large pages.

For testing, an opt-in **separate** barrel ships
`MockTxHistoryProvider<T>`:

```dart
import 'package:ceres_wallet_onchain/tx_history_testing.dart'; // tests only
```

See [`example/tx_history_example.dart`](example/tx_history_example.dart)
for one query per chain against live mainnet endpoints.

---

## ABI Encoding

```dart
// Encode a transfer(address,uint256) call
final selector = FunctionSelector.fromSignature('transfer(address,uint256)');
final params   = AbiCoder.encode(
  [AbiParam(type: 'address'), AbiParam(type: 'uint256')],
  ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', BigInt.from(1000000)],
);
final calldata = [...selector.bytes, ...params];

// Decode a uint256 return value
final decoded = AbiCoder.decode([AbiParam(type: 'uint256')], params);
print('Value: ${decoded[0]}');
```

---

## DApp Codec Layer

### EIP-712 (signTypedData_v4 pre-hash)

```dart
// Parse raw JSON payload from WalletConnect / MetaMask
final typedData = EIP712Parser.parse(rawJsonMap);

// Compute the 32-byte digest — pass to your signer
final digest = EIP712Hasher.digest(typedData);

// Access structured fields for approval UI
print(typedData.primaryType);          // 'Permit'
print(typedData.message['spender']);   // '0x...'
```

### EIP-191 (personal_sign pre-hash)

```dart
final digest = EIP191Hasher.digest('Hello Ethereum');
// Pass digest to your signing backend
```

### Solana Transaction Codec

```dart
// Decode wire bytes from WalletConnect payload
final tx = SolanaTxDecoder.decode(wireBytes);
print(tx.version);       // null (legacy) or 0 (v0)
print(tx.instructions.length);

// Re-encode after approval (e.g. after attaching signature)
final reEncoded = SolanaTxEncoder.encode(tx);

// Resolve Address Lookup Table accounts for v0 transactions
final allAccounts = await AltResolver.resolve(
  tx,
  (pubkey) => solanaClient.getAccountInfo(SolanaAddress(pubkey)),
);

// Decode ComputeBudget instructions
for (final ix in tx.instructions) {
  final budget = ComputeBudgetDecoder.decode(ix, tx.staticAccountKeys);
  if (budget is SetComputeUnitPrice) {
    print('Priority fee: ${budget.microLamports} microLamports');
  }
}
```

---

## Error Handling

```dart
final client = EvmRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(
      baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY',
      timeout: Duration(seconds: 10),
      maxRetries: 2,
    ),
  ),
);

try {
  final balance = await client.getBalance(EvmAddress('0x000...'));
  print('Balance: $balance');
} on RpcTimeoutException catch (e) {
  print('Timeout: ${e.message}');
} on RpcResponseException catch (e) {
  print('RPC error ${e.code}: ${e.message}');
} on RpcException catch (e) {
  print('Error: ${e.message}');
} finally {
  client.close();
}
```

---

## Supported Chains

| Chain  | Client             | Transport          | Methods |
|--------|--------------------|--------------------|---------|
| EVM    | `EvmRpcClient`     | `JsonRpcTransport` | 49      |
| Tron   | `TronHttpClient`   | `RestTransport`    | 65      |
| Solana | `SolanaRpcClient`  | `JsonRpcTransport` | 50      |
| Sui    | `SuiRpcClient`     | `JsonRpcTransport` | 39      |

---

## Signing Boundary

This package handles **RPC calls, ABI encoding, and pre-hash digest computation only**.
Transaction signing and key management must be done externally.

- `sendRawTransaction` (EVM), `broadcastHex` (Tron), `sendTransaction` (Solana), `executeTransactionBlock` (Sui) — all accept **pre-signed** payloads.
- `EIP712Hasher.digest()` and `EIP191Hasher.digest()` produce the hash for your external signer; they do not sign.

---

## API Reference

Full documentation: [pub.dev/documentation/ceres_wallet_onchain/latest](https://pub.dev/documentation/ceres_wallet_onchain/latest/)

## License

MIT — see [LICENSE](LICENSE) for details.
