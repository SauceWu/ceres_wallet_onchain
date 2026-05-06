/// ceres_wallet_onchain — multi-chain RPC SDK example
///
/// Demonstrates read-only queries across all four supported chains,
/// a BSC testnet walkthrough, ABI encoding, and the DApp codec layer
/// (EIP-712/191 hashing, Solana transaction wire-bytes codec).
///
/// Run with: dart run example/ceres_wallet_onchain_example.dart
library;

import 'dart:typed_data';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';

void main() async {
  await evmMainnetExample();
  await evmBscTestnetExample();
  await tronExample();
  await solanaExample();
  await suiExample();
  await abiExample();
  await eip712Example();
  await eip191Example();
  await solanaTxCodecExample();
}

// ---------------------------------------------------------------------------
// EVM — Ethereum mainnet
// ---------------------------------------------------------------------------

Future<void> evmMainnetExample() async {
  print('=== EVM — Ethereum Mainnet ===');

  final client = EvmRpcClient(
    transport: JsonRpcTransport(
      config: RpcClientConfig(baseUrl: 'https://eth.llamarpc.com'),
    ),
  );

  try {
    final blockNumber = await client.blockNumber();
    print('Latest block    : $blockNumber');

    final gasPrice = await client.gasPrice();
    print('Gas price       : $gasPrice wei');

    // Vitalik's address
    final balance = await client.getBalance(
      EvmAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'),
    );
    print('Vitalik balance : $balance wei');

    final chainId = await client.chainId();
    print('Chain ID        : $chainId');
  } on RpcException catch (e) {
    print('RPC error: $e');
  } catch (e) {
    print('Network error: $e');
  } finally {
    client.close();
  }

  print('');
}

// ---------------------------------------------------------------------------
// EVM — BSC Testnet (chain ID 97)
// ---------------------------------------------------------------------------

Future<void> evmBscTestnetExample() async {
  print('=== EVM — BSC Testnet (chain ID 97) ===');

  final client = EvmRpcClient(
    transport: JsonRpcTransport(
      config: RpcClientConfig(
        baseUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545',
        timeout: const Duration(seconds: 15),
        maxRetries: 2,
      ),
    ),
  );

  try {
    final chainId = await client.chainId();
    print('Chain ID        : $chainId'); // expect 97

    final blockNumber = await client.blockNumber();
    print('Latest block    : $blockNumber');

    final gasPrice = await client.gasPrice();
    print('Gas price       : $gasPrice wei');

    // BSC testnet validator contract always has tBNB
    final balance = await client.getBalance(
      EvmAddress('0x0000000000000000000000000000000000001004'),
    );
    print('Validator bal   : $balance wei');

    // Latest block details
    final block = await client.getBlockByNumber();
    if (block != null) {
      print('Block hash      : ${block.hash}');
      print('Gas used        : ${block.gasUsed}');
    }

    // eth_call — read WBNB name() on BSC testnet
    // selector for name(): 0x06fdde03
    const nameSelector = '0x06fdde03';
    const wbnbTestnet = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd';
    final hexResult = await client.call({
      'to': wbnbTestnet,
      'data': nameSelector,
    });
    // ABI-decode the returned hex string as string type
    final resultBytes = _hexToBytes(hexResult);
    final decoded = AbiCoder.decode([AbiParam(type: 'string')], resultBytes);
    print('WBNB name()     : ${decoded[0]}'); // "Wrapped BNB"
  } on RpcException catch (e) {
    print('RPC error: $e');
  } catch (e) {
    print('Network error: $e');
  } finally {
    client.close();
  }

  print('');
}

// ---------------------------------------------------------------------------
// Tron — mainnet
// ---------------------------------------------------------------------------

Future<void> tronExample() async {
  print('=== Tron — Mainnet ===');

  final client = TronHttpClient(
    transport: RestTransport(
      config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    ),
  );

  try {
    final block = await client.getNowBlock();
    print('Latest block    : ${block.blockHeader?.number}');
    print('Block ID        : ${block.blockID}');

    // Chain parameters — bandwidth price
    final chainParams = await client.getChainParameters();
    final txFee = chainParams.parameters.firstWhere(
      (p) => p.key == 'getTransactionFee',
      orElse: () => TronChainParameter(key: 'getTransactionFee'),
    );
    print('Tx fee          : ${txFee.value} sun/byte');
  } on RpcException catch (e) {
    print('RPC error: $e');
  } catch (e) {
    print('Network error: $e');
  } finally {
    client.close();
  }

  print('');
}

// ---------------------------------------------------------------------------
// Solana — mainnet
// ---------------------------------------------------------------------------

Future<void> solanaExample() async {
  print('=== Solana — Mainnet ===');

  final client = SolanaRpcClient(
    transport: JsonRpcTransport(
      config: RpcClientConfig(baseUrl: 'https://api.mainnet-beta.solana.com'),
    ),
  );

  try {
    final slot = await client.getSlot();
    print('Current slot    : $slot');

    final blockhash = await client.getLatestBlockhash();
    print('Latest blockhash: ${blockhash.blockhash}');
    print('Last valid slot : ${blockhash.lastValidBlockHeight}');

    // System program balance
    final balance = await client.getBalance(
      SolanaAddress('11111111111111111111111111111111'),
    );
    print('System prog bal : $balance lamports');

    // Recent priority fees
    final fees = await client.getRecentPrioritizationFees();
    if (fees.isNotEmpty) {
      print('Priority fee    : ${fees.first.prioritizationFee} microLamports');
    }
  } on RpcException catch (e) {
    print('RPC error: $e');
  } catch (e) {
    print('Network error: $e');
  } finally {
    client.close();
  }

  print('');
}

// ---------------------------------------------------------------------------
// Sui — mainnet
// ---------------------------------------------------------------------------

Future<void> suiExample() async {
  print('=== Sui — Mainnet ===');

  final client = SuiRpcClient(
    transport: JsonRpcTransport(
      config: RpcClientConfig(baseUrl: 'https://fullnode.mainnet.sui.io'),
    ),
  );

  try {
    final gasPrice = await client.getReferenceGasPrice();
    print('Ref gas price   : $gasPrice MIST');

    final checkpoint = await client.getLatestCheckpointSequenceNumber();
    print('Latest checkpoint: $checkpoint');
  } on RpcException catch (e) {
    print('RPC error: $e');
  } catch (e) {
    print('Network error: $e');
  } finally {
    client.close();
  }

  print('');
}

// ---------------------------------------------------------------------------
// ABI encoding / decoding (no network required)
// ---------------------------------------------------------------------------

Future<void> abiExample() async {
  print('=== ABI Encoding ===');

  // Compute 4-byte selector from function signature
  final transferSelector = FunctionSelector.compute(
    'transfer(address,uint256)',
  );
  final transferSelectorHex = FunctionSelector.computeHex(
    'transfer(address,uint256)',
  );
  print('transfer sel    : 0x$transferSelectorHex');

  // Encode call parameters
  final params = AbiCoder.encode(
    [AbiParam(type: 'address'), AbiParam(type: 'uint256')],
    [
      '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
      BigInt.parse('1000000000000000000'), // 1 ETH
    ],
  );

  // Full calldata = selector + encoded params
  final calldata = [...transferSelector, ...params];
  print('Calldata length : ${calldata.length} bytes');

  // Decode uint256 return value
  final decoded = AbiCoder.decode([AbiParam(type: 'uint256')], params);
  print('Decoded uint256 : ${decoded[0]}');

  // Encode and decode a tuple
  final tupleEncoded = AbiCoder.encode(
    [
      AbiParam(
        type: 'tuple',
        components: [
          AbiParam(type: 'uint256'),
          AbiParam(type: 'bool'),
          AbiParam(type: 'address'),
        ],
      ),
    ],
    [
      [BigInt.from(42), true, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
    ],
  );
  final tupleDecoded = AbiCoder.decode([
    AbiParam(
      type: 'tuple',
      components: [
        AbiParam(type: 'uint256'),
        AbiParam(type: 'bool'),
        AbiParam(type: 'address'),
      ],
    ),
  ], tupleEncoded);
  print('Decoded tuple   : ${tupleDecoded[0]}'); // [42, true, 0xd8dA...]

  // Common pre-computed selectors
  print('balanceOf sel   : 0x${_toHex(FunctionSelector.balanceOf)}');
  print('transfer sel    : 0x${_toHex(FunctionSelector.transfer)}');

  print('');
}

// ---------------------------------------------------------------------------
// EIP-712 typed data hashing (no network required)
// ---------------------------------------------------------------------------

Future<void> eip712Example() async {
  print('=== EIP-712 Typed Data Hash ===');

  // Permit payload (common in DeFi DApp interactions)
  final typedData = EIP712Parser.parse({
    'types': {
      'EIP712Domain': [
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'Permit': [
        {'name': 'owner', 'type': 'address'},
        {'name': 'spender', 'type': 'address'},
        {'name': 'value', 'type': 'uint256'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'deadline', 'type': 'uint256'},
      ],
    },
    'primaryType': 'Permit',
    'domain': {
      'name': 'Uniswap V2',
      'version': '1',
      'chainId': 1,
      'verifyingContract': '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
    },
    'message': {
      'owner': '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
      'spender': '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
      'value': BigInt.parse('1000000000000000000'),
      'nonce': BigInt.zero,
      'deadline': BigInt.from(1893456000),
    },
  });

  print('Primary type    : ${typedData.primaryType}');
  print('Domain name     : ${typedData.domain['name']}');
  print('Spender         : ${typedData.message['spender']}');

  // Compute 32-byte digest — pass to your external signer
  final digest = EIP712Hasher.digest(typedData);
  print('Digest (hex)    : ${_toHex(digest)}');

  print('');
}

// ---------------------------------------------------------------------------
// EIP-191 personal_sign hashing (no network required)
// ---------------------------------------------------------------------------

Future<void> eip191Example() async {
  print('=== EIP-191 personal_sign Hash ===');

  const message = 'Sign in to MyDApp\nNonce: abc123';
  final digest = EIP191Hasher.digest(message);
  print('Message         : $message');
  print('Digest (hex)    : ${_toHex(digest)}');
  // Pass digest to ceres_wallet_core or your signing backend

  print('');
}

// ---------------------------------------------------------------------------
// Solana transaction wire-bytes codec (no network required)
// ---------------------------------------------------------------------------

Future<void> solanaTxCodecExample() async {
  print('=== Solana Transaction Codec ===');

  final feePayer = Uint8List(32)..fillRange(0, 32, 0x01);
  final programId = Uint8List(32)..fillRange(0, 32, 0x02);
  final blockhash = Uint8List(32)..fillRange(0, 32, 0x03);

  final tx = SolanaTransaction(
    signatures: const [],
    version: null, // null = legacy, 0 = v0
    header: const MessageHeader(
      numRequiredSignatures: 1,
      numReadonlySignedAccounts: 0,
      numReadonlyUnsignedAccounts: 1,
    ),
    staticAccountKeys: [feePayer, programId],
    recentBlockhash: blockhash,
    instructions: [
      CompiledInstruction(
        programIdIndex: 1,
        accountKeyIndexes: const [0],
        data: Uint8List.fromList([0x02, 0x00, 0x00, 0x00]),
      ),
    ],
  );

  // Encode to wire bytes
  final encoded = SolanaTxEncoder.encode(tx);
  print('Wire bytes      : ${encoded.length} bytes');

  // Decode back — verify round-trip
  final decoded = SolanaTxDecoder.decode(encoded);
  print('Version         : ${decoded.version ?? "legacy"}');
  print('Account keys    : ${decoded.staticAccountKeys.length}');
  print('Instructions    : ${decoded.instructions.length}');

  final reEncoded = SolanaTxEncoder.encode(decoded);
  print('Round-trip OK   : ${_toHex(encoded) == _toHex(reEncoded)}');

  // Check each instruction for ComputeBudget
  for (final ix in decoded.instructions) {
    if (ComputeBudgetDecoder.isComputeBudget(ix, decoded.staticAccountKeys)) {
      final budget = ComputeBudgetDecoder.decode(ix);
      if (budget is ComputeBudgetSetComputeUnitLimit) {
        print('Compute units   : ${budget.units}');
      } else if (budget is ComputeBudgetSetComputeUnitPrice) {
        print('Priority fee    : ${budget.microLamports} microLamports');
      }
    }
  }

  print('');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexToBytes(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  return Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]);
}
