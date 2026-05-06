/// ceres_wallet_onchain — optional transaction-history extension example.
///
/// One query per chain against live mainnet endpoints, demonstrating the
/// opt-in `tx_history.dart` barrel + the test-only `tx_history_testing.dart`
/// barrel. Mirrors the structure of `ceres_wallet_onchain_example.dart`
/// (one async function per chain, sequential await main).
///
/// Run with:
/// ```bash
/// dart run example/tx_history_example.dart
/// ```
///
/// Network considerations:
///  - Solana, Sui, Blockscout, and TronGrid public mainnet endpoints
///    occasionally rate-limit; set the `*_RPC_URL` environment variable
///    to point at your own keyed endpoint if you hit 429s.
///  - The Etherscan slot is intentionally OMITTED from the live demo
///    because Etherscan v1/v2 require an API key — see the
///    [etherscanExampleSketch] function for the call shape.
///
/// All five providers below implement the same `TxHistoryProvider<T>`
/// contract — pagination, cursor handling, and `close()` lifecycle look
/// identical regardless of chain.
library;

import 'dart:io';

// Real-world apps will typically import the core barrel as well:
//   import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
// to access the v1.0 RPC clients alongside the history layer. This
// example only exercises the optional `tx_history` surface, so we skip
// the core import to keep the analyzer clean (`unused_import`).
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:ceres_wallet_onchain/tx_history_testing.dart';

void main() async {
  await solanaHistoryExample();
  await suiHistoryExample();
  await blockscoutHistoryExample();
  await trongridHistoryExample();
  etherscanExampleSketch();
  await mockProviderExample();
}

// ---------------------------------------------------------------------------
// Solana — mainnet beta, two-step composite (signatures → batched txs)
// ---------------------------------------------------------------------------

Future<void> solanaHistoryExample() async {
  final url =
      Platform.environment['SOLANA_RPC_URL'] ??
      'https://api.mainnet-beta.solana.com';

  final provider = SolanaNativeProvider.fromUrl(url);
  try {
    // USDC token program — guaranteed to have recent activity.
    const address = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
    final page = await provider.listTransactions(
      const TxHistoryQuery(address: address, limit: 3),
    );

    print('--- Solana mainnet ---');
    print('  $address');
    print(
      '  fetched ${page.items.length} signature${page.items.length == 1 ? "" : "s"}',
    );
    for (final tx in page.items) {
      final sig = tx.signatureInfo.signature;
      final slot = tx.signatureInfo.slot;
      print('  - slot=$slot sig=${_short(sig)}');
    }
    print('  next cursor: ${page.nextCursor}');
    print('  has more:    ${page.hasMore}');
  } finally {
    provider.close();
  }
}

// ---------------------------------------------------------------------------
// Sui — mainnet, sui_queryTransactionBlocks (FromAddress filter)
// ---------------------------------------------------------------------------

Future<void> suiHistoryExample() async {
  final url =
      Platform.environment['SUI_RPC_URL'] ?? 'https://fullnode.mainnet.sui.io';

  final provider = SuiNativeProvider.fromUrl(url);
  try {
    // Sui Foundation deployer — known active address.
    const address =
        '0x0000000000000000000000000000000000000000000000000000000000000005';
    final page = await provider.listFromAddress(address, limit: 3);

    print('--- Sui mainnet ---');
    print('  $address');
    print(
      '  fetched ${page.items.length} block${page.items.length == 1 ? "" : "s"}',
    );
    for (final tx in page.items) {
      print('  - digest=${_short(tx.digest)}');
    }
    print('  next cursor: ${page.nextCursor}');
    print('  has more:    ${page.hasMore}');
  } finally {
    provider.close();
  }
}

// ---------------------------------------------------------------------------
// EVM — Blockscout (Ethereum mainnet instance)
// ---------------------------------------------------------------------------

Future<void> blockscoutHistoryExample() async {
  // Blockscout provider takes a pool of base URLs for failover; pass one.
  final provider = EvmBlockscoutProvider(
    baseUrls: const ['https://eth.blockscout.com'],
  );
  try {
    // Vitalik's address — guaranteed to have history.
    const address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
    final page = await provider.listNativeTransactions(address, limit: 3);

    print('--- EVM Blockscout (eth.blockscout.com) ---');
    print('  $address');
    print(
      '  fetched ${page.items.length} tx${page.items.length == 1 ? "" : "s"}',
    );
    for (final tx in page.items) {
      final hash = tx['hash']?.toString() ?? '<no hash>';
      print('  - hash=${_short(hash)}');
    }
    print('  next cursor: ${page.nextCursor}');
    print('  has more:    ${page.hasMore}');
  } finally {
    provider.close();
  }
}

// ---------------------------------------------------------------------------
// EVM — Etherscan (sketch only — requires API key)
// ---------------------------------------------------------------------------

void etherscanExampleSketch() {
  print('--- EVM Etherscan (sketch — requires ETHERSCAN_API_KEY) ---');
  print('  ');
  print('  // const provider = EvmEtherscanProvider(');
  print('  //   baseUrl: "https://api.etherscan.io",');
  print('  //   apiKey: Platform.environment["ETHERSCAN_API_KEY"]!,');
  print('  //   chainId: 1,');
  print('  // );');
  print('  // final page = await provider.listNativeTransactions(');
  print('  //   "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",');
  print('  //   limit: 3,');
  print('  // );');
  print('  ');
  print('  (skipped at runtime — set ETHERSCAN_API_KEY to enable)');
}

// ---------------------------------------------------------------------------
// Tron — TronGrid mainnet, /v1/accounts/{addr}/transactions
// ---------------------------------------------------------------------------

Future<void> trongridHistoryExample() async {
  final url =
      Platform.environment['TRONGRID_BASE_URL'] ?? 'https://api.trongrid.io';

  final provider = TronGridProvider(
    baseUrl: url,
    apiKey: Platform.environment['TRONGRID_API_KEY'],
  );
  try {
    // Justin Sun's TRX address — guaranteed activity.
    const address = 'TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy';
    final page = await provider.listTrxTransactions(address, limit: 3);

    print('--- Tron TronGrid mainnet ---');
    print('  $address');
    print(
      '  fetched ${page.items.length} tx${page.items.length == 1 ? "" : "s"}',
    );
    for (final tx in page.items) {
      final txID = tx['txID']?.toString() ?? '<no txID>';
      print('  - txID=${_short(txID)}');
    }
    print('  next cursor: ${page.nextCursor}');
    print('  has more:    ${page.hasMore}');
  } finally {
    provider.close();
  }
}

// ---------------------------------------------------------------------------
// MockTxHistoryProvider — opt-in test barrel
// ---------------------------------------------------------------------------

Future<void> mockProviderExample() async {
  print('--- MockTxHistoryProvider (tx_history_testing.dart) ---');

  final mock = MockTxHistoryProvider<String>()
    ..enqueueResponse(const [
      'mocked-sig-1',
      'mocked-sig-2',
    ], nextCursor: SolanaCursor('mocked-sig-2'))
    ..enqueueResponse(const ['mocked-sig-3']);

  final first = await mock.listTransactions(
    const TxHistoryQuery(address: 'demo', limit: 2),
  );
  print('  page 1: ${first.items}  hasMore=${first.hasMore}');

  final second = await mock.list(address: 'demo', cursor: first.nextCursor);
  print('  page 2: ${second.items}  hasMore=${second.hasMore}');

  print('  recorded queries: ${mock.recordedQueries.length}');
  mock.close();
  print('  closed: ${mock.isClosed}');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _short(String s) =>
    s.length <= 16 ? s : '${s.substring(0, 8)}…${s.substring(s.length - 6)}';
