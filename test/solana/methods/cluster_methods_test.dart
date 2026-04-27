import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/cluster_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [SolanaClusterMethods] for testing.
class _TestClient with SolanaClusterMethods {
  @override
  final JsonRpcTransport transport;

  _TestClient(this.transport);

  void close() => transport.close();
}

/// Creates a [_TestClient] that returns [result] for any RPC method.
_TestClient _clientWithResult(dynamic result) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
    httpClient: mockHttp,
  );
  return _TestClient(transport);
}

/// Creates a [_TestClient] that captures the request and returns [result].
_TestClient _clientCapturing(
  dynamic result,
  void Function(Map<String, dynamic>) onRequest,
) {
  final mockHttp = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    onRequest(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://mock.rpc'),
    httpClient: mockHttp,
  );
  return _TestClient(transport);
}

void main() {
  group('SolanaClusterMethods', () {
    group('getClusterNodes', () {
      test('returns list of ClusterNode', () async {
        final client = _clientWithResult([
          {
            'pubkey': 'Node111111111111111111111111111111111111111',
            'gossip': '10.0.0.1:8001',
            'tpu': '10.0.0.1:8003',
            'rpc': '10.0.0.1:8899',
            'version': '1.14.17',
            'featureSet': 3580551090,
            'shredVersion': 50093,
          },
          {
            'pubkey': 'Node222222222222222222222222222222222222222',
            'gossip': null,
            'tpu': null,
            'rpc': null,
            'version': null,
            'featureSet': null,
            'shredVersion': null,
          },
        ]);

        final nodes = await client.getClusterNodes();

        expect(nodes, hasLength(2));
        expect(nodes[0].pubkey, 'Node111111111111111111111111111111111111111');
        expect(nodes[0].gossip, '10.0.0.1:8001');
        expect(nodes[0].version, '1.14.17');
        expect(nodes[1].rpc, isNull);

        client.close();
      });
    });

    group('getHealth', () {
      test('returns "ok" string', () async {
        final client = _clientWithResult('ok');

        final health = await client.getHealth();

        expect(health, 'ok');

        client.close();
      });
    });

    group('getVersion', () {
      test('returns map with solana-core and feature-set', () async {
        final client = _clientWithResult({
          'solana-core': '1.14.17',
          'feature-set': 3580551090,
        });

        final version = await client.getVersion();

        expect(version['solana-core'], '1.14.17');
        expect(version['feature-set'], 3580551090);

        client.close();
      });
    });

    group('getIdentity', () {
      test('returns node public key string', () async {
        final client = _clientWithResult({
          'identity': '2r1F4iWqVcb8M1DbAjQuFpebkQHY9hcVU4WuW2DJBppN',
        });

        final identity = await client.getIdentity();

        expect(identity, '2r1F4iWqVcb8M1DbAjQuFpebkQHY9hcVU4WuW2DJBppN');

        client.close();
      });
    });

    group('getGenesisHash', () {
      test('returns genesis hash string', () async {
        final client = _clientWithResult(
          '4sGjMW1sUnHzSxGspuhSqnkYMvkS6pTCzcY1JMWawW6d',
        );

        final hash = await client.getGenesisHash();

        expect(hash, '4sGjMW1sUnHzSxGspuhSqnkYMvkS6pTCzcY1JMWawW6d');

        client.close();
      });
    });

    group('getSupply', () {
      test('returns Supply from RpcResponse value', () async {
        final client = _clientWithResult({
          'context': {'slot': 100},
          'value': {
            'total': 500000000000000000,
            'circulating': 400000000000000000,
            'nonCirculating': 100000000000000000,
            'nonCirculatingAccounts': ['11111111111111111111111111111111'],
          },
        });

        final supply = await client.getSupply();

        expect(supply.total, equals(BigInt.from(500000000000000000)));
        expect(supply.circulating, equals(BigInt.from(400000000000000000)));
        expect(supply.nonCirculatingAccounts, hasLength(1));

        client.close();
      });

      test('sends optional parameters', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'context': {'slot': 1},
          'value': {
            'total': 0,
            'circulating': 0,
            'nonCirculating': 0,
            'nonCirculatingAccounts': [],
          },
        }, (body) => captured = body);

        await client.getSupply(
          commitment: SolanaCommitment.finalized,
          excludeNonCirculatingAccountsList: true,
        );

        final params = captured!['params'] as List;
        expect(params, hasLength(1));
        final config = params[0] as Map<String, dynamic>;
        expect(config['commitment'], 'finalized');
        expect(config['excludeNonCirculatingAccountsList'], true);

        client.close();
      });
    });

    group('getRecentPerformanceSamples', () {
      test('returns list of PerformanceSample', () async {
        final client = _clientWithResult([
          {
            'slot': 348125,
            'numTransactions': 126,
            'numSlots': 126,
            'samplePeriodSecs': 60,
            'numNonVoteTransactions': 10,
          },
        ]);

        final samples = await client.getRecentPerformanceSamples();

        expect(samples, hasLength(1));
        expect(samples[0].slot, 348125);
        expect(samples[0].numTransactions, 126);
        expect(samples[0].numNonVoteTransactions, 10);

        client.close();
      });

      test('sends optional limit parameter', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing([], (body) => captured = body);

        await client.getRecentPerformanceSamples(limit: 5);

        final params = captured!['params'] as List;
        expect(params, [5]);

        client.close();
      });
    });

    group('getHighestSnapshotSlot', () {
      test('returns SnapshotSlot', () async {
        final client = _clientWithResult({'full': 100, 'incremental': 110});

        final snapshot = await client.getHighestSnapshotSlot();

        expect(snapshot.full, 100);
        expect(snapshot.incremental, 110);

        client.close();
      });

      test('handles null incremental', () async {
        final client = _clientWithResult({'full': 100, 'incremental': null});

        final snapshot = await client.getHighestSnapshotSlot();

        expect(snapshot.full, 100);
        expect(snapshot.incremental, isNull);

        client.close();
      });
    });

    group('minimumLedgerSlot', () {
      test('returns int', () async {
        final client = _clientWithResult(1234);

        final slot = await client.minimumLedgerSlot();

        expect(slot, 1234);

        client.close();
      });
    });

    group('requestAirdrop', () {
      test('returns transaction signature string', () async {
        final client = _clientWithResult(
          '5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW',
        );

        final addr = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        final sig = await client.requestAirdrop(addr, 1000000000);

        expect(
          sig,
          '5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW',
        );

        client.close();
      });

      test('sends address and lamports', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing('sig123', (body) => captured = body);

        final addr = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        await client.requestAirdrop(addr, 2000000000);

        expect(captured!['method'], 'requestAirdrop');
        final params = captured!['params'] as List;
        expect(params[0], addr.toBase58());
        expect(params[1], 2000000000);

        client.close();
      });
    });
  });
}
