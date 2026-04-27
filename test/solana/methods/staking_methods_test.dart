import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/staking_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_address.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Concrete class that mixes in [SolanaStakingMethods] for testing.
class _TestClient with SolanaStakingMethods {
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
  group('SolanaStakingMethods', () {
    group('getVoteAccounts', () {
      test('returns VoteAccountsResult with current and delinquent', () async {
        final client = _clientWithResult({
          'current': [
            {
              'votePubkey': 'Vote111111111111111111111111111111111111111',
              'nodePubkey': 'Node111111111111111111111111111111111111111',
              'activatedStake': 42000000000,
              'epochVoteAccount': true,
              'commission': 10,
              'lastVote': 123456,
              'rootSlot': 123400,
            },
          ],
          'delinquent': [
            {
              'votePubkey': 'Vote222222222222222222222222222222222222222',
              'nodePubkey': 'Node222222222222222222222222222222222222222',
              'activatedStake': 1000000000,
              'epochVoteAccount': false,
              'commission': 5,
              'lastVote': 100000,
              'rootSlot': null,
            },
          ],
        });

        final result = await client.getVoteAccounts();

        expect(result.current, hasLength(1));
        expect(
          result.current.first.votePubkey,
          'Vote111111111111111111111111111111111111111',
        );
        expect(
          result.current.first.activatedStake,
          equals(BigInt.from(42000000000)),
        );
        expect(result.delinquent, hasLength(1));
        expect(result.delinquent.first.commission, 5);

        client.close();
      });

      test('sends optional parameters', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'current': [],
          'delinquent': [],
        }, (body) => captured = body);

        await client.getVoteAccounts(
          votePubkey: 'Vote111111111111111111111111111111111111111',
          keepUnstakedDelinquents: true,
          delinquentSlotDistance: 128,
          commitment: SolanaCommitment.finalized,
        );

        final params = captured!['params'] as List;
        expect(params, hasLength(1));
        final config = params[0] as Map<String, dynamic>;
        expect(
          config['votePubkey'],
          'Vote111111111111111111111111111111111111111',
        );
        expect(config['keepUnstakedDelinquents'], true);
        expect(config['delinquentSlotDistance'], 128);
        expect(config['commitment'], 'finalized');

        client.close();
      });
    });

    group('getStakeMinimumDelegation', () {
      test('returns BigInt from RpcResponse value', () async {
        final client = _clientWithResult({
          'context': {'slot': 100},
          'value': 1000000000,
        });

        final result = await client.getStakeMinimumDelegation();

        expect(result, equals(BigInt.from(1000000000)));

        client.close();
      });
    });

    group('getStakeActivation', () {
      test('returns StakeActivation', () async {
        final client = _clientWithResult({
          'state': 'active',
          'active': 5000000000,
          'inactive': 0,
        });

        final pubkey = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        final result = await client.getStakeActivation(pubkey);

        expect(result.state, 'active');
        expect(result.active, equals(BigInt.from(5000000000)));
        expect(result.inactive, equals(BigInt.zero));

        client.close();
      });

      test('sends pubkey and optional epoch', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'state': 'active',
          'active': 0,
          'inactive': 0,
        }, (body) => captured = body);

        final pubkey = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        await client.getStakeActivation(pubkey, epoch: 100);

        final params = captured!['params'] as List;
        expect(params[0], pubkey.toBase58());
        final config = params[1] as Map<String, dynamic>;
        expect(config['epoch'], 100);

        client.close();
      });
    });

    group('getInflationGovernor', () {
      test('returns InflationGovernor', () async {
        final client = _clientWithResult({
          'initial': 0.15,
          'terminal': 0.015,
          'taper': 0.15,
          'foundation': 0.05,
          'foundationTerm': 7.0,
        });

        final result = await client.getInflationGovernor();

        expect(result.initial, 0.15);
        expect(result.terminal, 0.015);
        expect(result.foundation, 0.05);

        client.close();
      });
    });

    group('getInflationRate', () {
      test('returns InflationRate', () async {
        final client = _clientWithResult({
          'total': 0.065,
          'validator': 0.06,
          'foundation': 0.005,
          'epoch': 100,
        });

        final result = await client.getInflationRate();

        expect(result.total, 0.065);
        expect(result.validator, 0.06);
        expect(result.epoch, 100);

        client.close();
      });

      test('sends no params', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing({
          'total': 0.0,
          'validator': 0.0,
          'foundation': 0.0,
          'epoch': 0,
        }, (body) => captured = body);

        await client.getInflationRate();

        expect(captured!['method'], 'getInflationRate');
        expect(captured!['params'], isEmpty);

        client.close();
      });
    });

    group('getInflationReward', () {
      test('returns list with nullable InflationReward', () async {
        final client = _clientWithResult([
          {
            'epoch': 100,
            'effectiveSlot': 43200000,
            'amount': 2500,
            'postBalance': 5000000000,
            'commission': 10,
          },
          null,
        ]);

        final addr1 = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        final addr2 = SolanaAddress('11111111111111111111111111111111');
        final result = await client.getInflationReward([addr1, addr2]);

        expect(result, hasLength(2));
        expect(result[0]!.epoch, 100);
        expect(result[0]!.amount, equals(BigInt.from(2500)));
        expect(result[1], isNull);

        client.close();
      });

      test('sends addresses and optional epoch', () async {
        Map<String, dynamic>? captured;
        final client = _clientCapturing([], (body) => captured = body);

        final addr = SolanaAddress(
          'CYRJWqiSjLitBAcRxPvWpgX3s5TvmN1BQrswQ1cY36Kp',
        );
        await client.getInflationReward(
          [addr],
          epoch: 50,
          commitment: SolanaCommitment.confirmed,
        );

        final params = captured!['params'] as List;
        expect(params[0], [addr.toBase58()]);
        final config = params[1] as Map<String, dynamic>;
        expect(config['epoch'], 50);
        expect(config['commitment'], 'confirmed');

        client.close();
      });
    });
  });
}
