import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/evm/evm_address.dart';
import 'package:ceres_wallet_onchain/src/evm/evm_rpc_client.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_block.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_log.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_transaction.dart';
import 'package:ceres_wallet_onchain/src/evm/models/eth_transaction_receipt.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Creates an [EvmRpcClient] backed by a [MockClient] that routes responses
/// based on the JSON-RPC method name in the request body.
EvmRpcClient _createClient(Map<String, dynamic> responses) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'] as String;
    final result = responses[method];
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://mock-rpc.test'),
    httpClient: mockHttp,
  );
  return EvmRpcClient(transport: transport);
}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const _address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

Map<String, dynamic> _blockFixture({required bool fullTx}) {
  final txField = fullTx
      ? [_transactionFixture()]
      : ['0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd'];
  return {
    'number': '0x10d4f1',
    'hash': '0xblock_hash_0000000000000000000000000000000000000000000000000000',
    'parentHash':
        '0xparent_hash_000000000000000000000000000000000000000000000000000',
    'nonce': '0x0000000000000000',
    'sha3Uncles':
        '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
    'logsBloom': '0x${'00' * 256}',
    'transactionsRoot':
        '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
    'stateRoot':
        '0xd5855eb08b3387c0af375e9cdb6acfc05eb8f519e419b874b6ff2382c998bf01',
    'receiptsRoot':
        '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
    'miner': _address,
    'difficulty': '0x0',
    'totalDifficulty': '0xc70d815d562d3cfa955',
    'extraData': '0x',
    'size': '0x220',
    'gasLimit': '0x1c9c380',
    'gasUsed': '0x0',
    'timestamp': '0x6639f8b7',
    'uncles': <String>[],
    'mixHash':
        '0x0000000000000000000000000000000000000000000000000000000000000000',
    'transactions': txField,
    'baseFeePerGas': '0x3b9aca00',
  };
}

Map<String, dynamic> _transactionFixture() => {
  'blockHash':
      '0xblock_hash_0000000000000000000000000000000000000000000000000000',
  'blockNumber': '0x10d4f1',
  'from': _address,
  'gas': '0x5208',
  'hash': '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
  'input': '0x',
  'nonce': '0x0',
  'to': '0x0000000000000000000000000000000000000001',
  'transactionIndex': '0x0',
  'value': '0xde0b6b3a7640000',
  'type': '0x2',
  'v': '0x0',
  'r': '0x0000000000000000000000000000000000000000000000000000000000000001',
  's': '0x0000000000000000000000000000000000000000000000000000000000000002',
  'maxFeePerGas': '0x4a817c800',
  'maxPriorityFeePerGas': '0x3b9aca00',
  'chainId': '0x1',
  'accessList': <dynamic>[],
};

Map<String, dynamic> _receiptFixture() => {
  'transactionHash':
      '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
  'transactionIndex': '0x0',
  'blockHash':
      '0xblock_hash_0000000000000000000000000000000000000000000000000000',
  'blockNumber': '0x10d4f1',
  'from': _address,
  'to': '0x0000000000000000000000000000000000000001',
  'cumulativeGasUsed': '0x5208',
  'effectiveGasPrice': '0x3b9aca00',
  'gasUsed': '0x5208',
  'contractAddress': null,
  'logs': [_logFixture()],
  'logsBloom': '0x${'00' * 256}',
  'type': '0x2',
  'status': '0x1',
};

Map<String, dynamic> _logFixture() => {
  'logIndex': '0x0',
  'transactionIndex': '0x0',
  'transactionHash':
      '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
  'blockHash':
      '0xblock_hash_0000000000000000000000000000000000000000000000000000',
  'blockNumber': '0x10d4f1',
  'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
  'data': '0x00000000000000000000000000000000000000000000000000000000000f4240',
  'topics': [
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
    '0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045',
  ],
  'removed': false,
};

void main() {
  group('EvmRpcClient integration', () {
    // -------------------------------------------------------------------
    // Account methods
    // -------------------------------------------------------------------
    group('Account', () {
      test('getBalance returns correct BigInt', () async {
        final client = _createClient({
          'eth_getBalance': '0xde0b6b3a7640000', // 1 ETH
        });
        final balance = await client.getBalance(EvmAddress(_address));
        expect(balance, equals(BigInt.parse('1000000000000000000')));
        client.close();
      });

      test('getTransactionCount returns correct BigInt', () async {
        final client = _createClient({
          'eth_getTransactionCount': '0x2a', // 42
        });
        final count = await client.getTransactionCount(EvmAddress(_address));
        expect(count, equals(BigInt.from(42)));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Gas methods
    // -------------------------------------------------------------------
    group('Gas', () {
      test('gasPrice returns BigInt', () async {
        final client = _createClient({
          'eth_gasPrice': '0x3b9aca00', // 1 gwei
        });
        final price = await client.gasPrice();
        expect(price, equals(BigInt.from(1000000000)));
        client.close();
      });

      test('estimateGas returns BigInt', () async {
        final client = _createClient({
          'eth_estimateGas': '0x5208', // 21000
        });
        final gas = await client.estimateGas({'to': _address});
        expect(gas, equals(BigInt.from(21000)));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // State methods
    // -------------------------------------------------------------------
    group('State', () {
      test('chainId returns BigInt', () async {
        final client = _createClient({'eth_chainId': '0x1'});
        final chainId = await client.chainId();
        expect(chainId, equals(BigInt.one));
        client.close();
      });

      test('blockNumber returns BigInt', () async {
        final client = _createClient({'eth_blockNumber': '0x10d4f1'});
        final blockNum = await client.blockNumber();
        expect(blockNum, equals(BigInt.from(0x10d4f1)));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Block methods
    // -------------------------------------------------------------------
    group('Block', () {
      test('getBlockByNumber hash mode returns transactionHashes', () async {
        final client = _createClient({
          'eth_getBlockByNumber': _blockFixture(fullTx: false),
        });
        final block = await client.getBlockByNumber();
        expect(block, isA<EthBlock>());
        expect(block!.transactionHashes, isNotNull);
        expect(block.transactionHashes, hasLength(1));
        expect(block.transactions, isNull);
        expect(block.number, equals(BigInt.from(0x10d4f1)));
        client.close();
      });

      test('getBlockByNumber full mode returns EthTransaction list', () async {
        final client = _createClient({
          'eth_getBlockByNumber': _blockFixture(fullTx: true),
        });
        final block = await client.getBlockByNumber(fullTransactions: true);
        expect(block, isA<EthBlock>());
        expect(block!.transactions, isNotNull);
        expect(block.transactions, hasLength(1));
        expect(block.transactions!.first, isA<EthTransaction>());
        expect(block.transactionHashes, isNull);
        client.close();
      });

      test('getBlockByNumber returns null for non-existent block', () async {
        final client = _createClient({'eth_getBlockByNumber': null});
        final block = await client.getBlockByNumber(blockTag: '0xffffff');
        expect(block, isNull);
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Transaction methods
    // -------------------------------------------------------------------
    group('Transaction', () {
      test(
        'getTransactionByHash returns EthTransaction with correct type',
        () async {
          final client = _createClient({
            'eth_getTransactionByHash': _transactionFixture(),
          });
          final tx = await client.getTransactionByHash(
            '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
          );
          expect(tx, isA<EthTransaction>());
          expect(tx!.type, equals(2));
          expect(tx.value, equals(BigInt.parse('1000000000000000000')));
          expect(tx.maxFeePerGas, isNotNull);
          client.close();
        },
      );

      test('getTransactionByHash returns null for not-found', () async {
        final client = _createClient({'eth_getTransactionByHash': null});
        final tx = await client.getTransactionByHash('0xnonexistent');
        expect(tx, isNull);
        client.close();
      });

      test('getTransactionReceipt returns receipt with logs', () async {
        final client = _createClient({
          'eth_getTransactionReceipt': _receiptFixture(),
        });
        final receipt = await client.getTransactionReceipt(
          '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
        );
        expect(receipt, isA<EthTransactionReceipt>());
        expect(receipt!.status, equals(BigInt.one));
        expect(receipt.logs, hasLength(1));
        expect(receipt.logs.first, isA<EthLog>());
        expect(receipt.logs.first.topics, hasLength(2));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Send methods
    // -------------------------------------------------------------------
    group('Send', () {
      test('sendRawTransaction returns tx hash', () async {
        final client = _createClient({
          'eth_sendRawTransaction':
              '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
        });
        final hash = await client.sendRawTransaction('0xf86c...');
        expect(
          hash,
          equals(
            '0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd',
          ),
        );
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Log methods
    // -------------------------------------------------------------------
    group('Log', () {
      test('getLogs returns List<EthLog>', () async {
        final client = _createClient({
          'eth_getLogs': [_logFixture(), _logFixture()],
        });
        final logs = await client.getLogs({
          'fromBlock': '0x0',
          'toBlock': 'latest',
          'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        });
        expect(logs, hasLength(2));
        expect(logs.first, isA<EthLog>());
        expect(logs.first.removed, isFalse);
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Filter methods
    // -------------------------------------------------------------------
    group('Filter', () {
      test('newFilter returns filter ID', () async {
        final client = _createClient({'eth_newFilter': '0x1'});
        final id = await client.newFilter({
          'fromBlock': '0x0',
          'toBlock': 'latest',
        });
        expect(id, equals('0x1'));
        client.close();
      });

      test('uninstallFilter returns bool', () async {
        final client = _createClient({'eth_uninstallFilter': true});
        final result = await client.uninstallFilter('0x1');
        expect(result, isTrue);
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Net methods
    // -------------------------------------------------------------------
    group('Net', () {
      test('netVersion returns string', () async {
        final client = _createClient({'net_version': '1'});
        final version = await client.netVersion();
        expect(version, equals('1'));
        client.close();
      });

      test('netListening returns bool', () async {
        final client = _createClient({'net_listening': true});
        final listening = await client.netListening();
        expect(listening, isTrue);
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Web3 methods
    // -------------------------------------------------------------------
    group('Web3', () {
      test('web3ClientVersion returns string', () async {
        final client = _createClient({
          'web3_clientVersion': 'Geth/v1.13.0-stable/linux-amd64/go1.21.0',
        });
        final version = await client.web3ClientVersion();
        expect(version, equals('Geth/v1.13.0-stable/linux-amd64/go1.21.0'));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Mining methods
    // -------------------------------------------------------------------
    group('Mining', () {
      test('mining returns bool', () async {
        final client = _createClient({'eth_mining': false});
        final isMining = await client.mining();
        expect(isMining, isFalse);
        client.close();
      });

      test('hashrate returns BigInt', () async {
        final client = _createClient({'eth_hashrate': '0x0'});
        final rate = await client.hashrate();
        expect(rate, equals(BigInt.zero));
        client.close();
      });
    });

    // -------------------------------------------------------------------
    // Multi-method routing (lifecycle test)
    // -------------------------------------------------------------------
    group('Lifecycle', () {
      test('single client can call methods from multiple domains', () async {
        final client = _createClient({
          'eth_chainId': '0x1',
          'eth_blockNumber': '0x10d4f1',
          'eth_getBalance': '0xde0b6b3a7640000',
          'eth_gasPrice': '0x3b9aca00',
          'net_version': '1',
          'web3_clientVersion': 'Geth/v1.13.0',
        });

        // Call across multiple domains using same client
        final chainId = await client.chainId();
        final blockNum = await client.blockNumber();
        final balance = await client.getBalance(EvmAddress(_address));
        final gasPrice = await client.gasPrice();
        final netVersion = await client.netVersion();
        final web3Version = await client.web3ClientVersion();

        expect(chainId, equals(BigInt.one));
        expect(blockNum, equals(BigInt.from(0x10d4f1)));
        expect(balance, equals(BigInt.parse('1000000000000000000')));
        expect(gasPrice, equals(BigInt.from(1000000000)));
        expect(netVersion, equals('1'));
        expect(web3Version, equals('Geth/v1.13.0'));

        client.close();
      });
    });
  });
}
