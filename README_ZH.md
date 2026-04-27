# ceres_wallet_onchain

[![pub package](https://img.shields.io/pub/v/ceres_wallet_onchain.svg)](https://pub.dev/packages/ceres_wallet_onchain)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.8.0-blue)](https://dart.dev)

纯 Dart 多链 RPC SDK，覆盖 **EVM / Tron / Solana / Sui** 四条链的完整 RPC 方法集、类型化响应解析、ABI 编解码，以及 DApp 接入所需的 EIP-712/191 hashing 与 Solana 交易 wire-bytes codec。

[English Documentation](README.md)

---

## 功能一览

| 模块 | 内容 |
|------|------|
| **EVM RPC** | 49 个类型化方法 — `eth_`、`net_`、`web3_` 命名空间 |
| **Tron HTTP** | 65 个类型化端点 — 账户、交易、质押、TRC-20 合约 |
| **Solana RPC** | 50 个类型化方法 — 账户、SPL Token、区块、质押、费用 |
| **Sui RPC** | 39 个类型化方法 — `sui_` 和 `suix_` 命名空间 |
| **ABI 编解码** | 编解码 `address`、`uint/int`、`bool`、`bytes`、`string`、`tuple`、数组 |
| **函数选择器** | keccak256 计算 4-byte selector |
| **EIP-712 / EIP-191** | 解析 typed data → `TypedDataV4`，计算 32 字节 digest，供 MPC/签名消费 |
| **Solana tx codec** | 解码/重编码 legacy + v0 交易 wire bytes，compact-u16，ALT 解析，ComputeBudget 识别 |
| **统一异常模型** | `RpcException` 体系，自动重试与超时 |
| **纯 Dart** | 无 Flutter 依赖，可在任意 Dart 环境使用 |

---

## 安装

```yaml
dependencies:
  ceres_wallet_onchain: ^0.1.1
```

```bash
dart pub add ceres_wallet_onchain
```

```dart
import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
```

---

## 快速开始

### EVM

```dart
final client = EvmRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY'),
  ),
);

// 查询余额（返回 BigInt，单位 wei）
final balance = await client.getBalance(
  EvmAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'),
);
print('余额：$balance wei');

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

// 查询账户信息
final account = await client.getAccount(
  TronAddress('TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy'),
);
print('余额：${account?.balance} sun');

client.close();
```

### Solana

```dart
final client = SolanaRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://api.mainnet-beta.solana.com'),
  ),
);

// 查询 lamport 余额
final balance   = await client.getBalance(SolanaAddress('11111111111111111111111111111111'));
final blockhash = await client.getLatestBlockhash();
print('$balance lamports，最新 blockhash：${blockhash.blockhash}');

client.close();
```

### Sui

```dart
final client = SuiRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(baseUrl: 'https://fullnode.mainnet.sui.io'),
  ),
);

// 查询所有余额
final balance = await client.getBalance(SuiAddress('0xabc...'));
print('SUI 总余额：${balance.totalBalance}');

client.close();
```

---

## ABI 编解码

```dart
// 编码 transfer(address,uint256) 调用数据
final selector = FunctionSelector.fromSignature('transfer(address,uint256)');
final params   = AbiCoder.encode(
  [AbiParam(type: 'address'), AbiParam(type: 'uint256')],
  ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', BigInt.from(1000000)],
);
final calldata = [...selector.bytes, ...params];

// 解码 uint256 返回值
final decoded = AbiCoder.decode([AbiParam(type: 'uint256')], params);
print('解码值：${decoded[0]}');
```

---

## DApp 接入层

### EIP-712（signTypedData_v4 前置 hash）

```dart
// 解析来自 WalletConnect / MetaMask 的 JSON payload
final typedData = EIP712Parser.parse(rawJsonMap);

// 计算 32 字节 digest，传给外部签名器
final digest = EIP712Hasher.digest(typedData);

// 结构化数据可直接用于审批 UI 展示
print(typedData.primaryType);         // 例如 'Permit'
print(typedData.message['spender']);  // '0x...'
```

### EIP-191（personal_sign 前置 hash）

```dart
// 计算 personal_sign 前置 hash
final digest = EIP191Hasher.digest('Hello Ethereum');
// 将 digest 传给外部签名器
```

### Solana 交易 codec

```dart
// 解码来自 WalletConnect 的 wire bytes
final tx = SolanaTxDecoder.decode(wireBytes);
print(tx.version);            // null（legacy）或 0（v0）
print(tx.instructions.length);

// 审批后重新编码（例如附上签名后）
final reEncoded = SolanaTxEncoder.encode(tx);

// 解析 v0 交易的 ALT 账户（并发拉取）
final allAccounts = await AltResolver.resolve(
  tx,
  (pubkey) => solanaClient.getAccountInfo(SolanaAddress(pubkey)),
);

// 识别 ComputeBudget 指令
for (final ix in tx.instructions) {
  final budget = ComputeBudgetDecoder.decode(ix, tx.staticAccountKeys);
  if (budget is SetComputeUnitPrice) {
    print('优先费：${budget.microLamports} microLamports');
  }
}
```

---

## 错误处理

```dart
final client = EvmRpcClient(
  transport: JsonRpcTransport(
    config: RpcClientConfig(
      baseUrl: 'https://mainnet.infura.io/v3/YOUR_KEY',
      timeout: Duration(seconds: 10),
      maxRetries: 2,        // 超时/5xx 自动重试
    ),
  ),
);

try {
  final balance = await client.getBalance(EvmAddress('0x000...'));
  print('余额：$balance');
} on RpcTimeoutException catch (e) {
  print('超时：${e.message}');
} on RpcResponseException catch (e) {
  print('RPC 错误 ${e.code}：${e.message}');
} on RpcException catch (e) {
  print('错误：${e.message}');
} finally {
  client.close();
}
```

---

## 链支持总览

| 链 | 客户端类 | 传输层 | 方法数 |
|----|----------|--------|-------|
| EVM | `EvmRpcClient` | `JsonRpcTransport` | 49 |
| Tron | `TronHttpClient` | `RestTransport` | 65 |
| Solana | `SolanaRpcClient` | `JsonRpcTransport` | 50 |
| Sui | `SuiRpcClient` | `JsonRpcTransport` | 39 |

---

## 签名边界说明

本包只负责 **RPC 调用、ABI 编解码，以及签名前置 digest 计算**，不包含任何私钥操作。

- `sendRawTransaction`（EVM）、`broadcastHex`（Tron）、`sendTransaction`（Solana）、`executeTransactionBlock`（Sui）均接受**已签名**的 payload。
- `EIP712Hasher.digest()` 和 `EIP191Hasher.digest()` 只输出 hash，不执行签名。

签名请使用外部库（如 `ceres_wallet_core`）或你自己的签名实现。

---

## API 文档

完整 API 文档：[pub.dev/documentation/ceres_wallet_onchain/latest](https://pub.dev/documentation/ceres_wallet_onchain/latest/)

## 许可证

MIT — 详见 [LICENSE](LICENSE)
