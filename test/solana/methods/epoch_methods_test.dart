import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/solana/methods/epoch_methods.dart';
import 'package:ceres_wallet_onchain/src/solana/solana_commitment.dart';

class _TestClient with SolanaEpochMethods {
  @override
  final JsonRpcTransport transport;
  _TestClient(this.transport);
}

/// Creates a [MockClient] that returns [result] for any JSON-RPC request.
MockClient _mockClient(dynamic result) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Creates a [MockClient] that captures the request and returns [result].
MockClient _mockClientCapture(
  dynamic result,
  void Function(Map<String, dynamic> body) onRequest,
) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    onRequest(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  const config = RpcClientConfig(baseUrl: 'http://localhost:8899');

  group('SolanaEpochMethods', () {
    // --- getEpochInfo ---
    test('getEpochInfo returns EpochInfo directly', () async {
      final mock = _mockClient({
        'epoch': 166,
        'slotIndex': 27140,
        'slotsInEpoch': 432000,
        'absoluteSlot': 71772140,
        'blockHeight': 62434080,
        'transactionCount': 2482930125,
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final info = await client.getEpochInfo();
      expect(info.epoch, equals(166));
      expect(info.slotIndex, equals(27140));
      expect(info.slotsInEpoch, equals(432000));
      expect(info.absoluteSlot, equals(71772140));
      expect(info.blockHeight, equals(62434080));
      expect(info.transactionCount, equals(BigInt.from(2482930125)));
    });

    test('getEpochInfo sends commitment when specified', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture({
        'epoch': 166,
        'slotIndex': 27140,
        'slotsInEpoch': 432000,
        'absoluteSlot': 71772140,
        'blockHeight': 62434080,
      }, (body) => captured = body);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getEpochInfo(commitment: SolanaCommitment.confirmed);
      expect(captured!['method'], equals('getEpochInfo'));
      final params = captured!['params'] as List;
      expect((params[0] as Map)['commitment'], equals('confirmed'));
    });

    // --- getEpochSchedule ---
    test('getEpochSchedule returns EpochSchedule directly', () async {
      final mock = _mockClient({
        'slotsPerEpoch': 432000,
        'leaderScheduleSlotOffset': 432000,
        'warmup': false,
        'firstNormalEpoch': 14,
        'firstNormalSlot': 524256,
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final schedule = await client.getEpochSchedule();
      expect(schedule.slotsPerEpoch, equals(432000));
      expect(schedule.leaderScheduleSlotOffset, equals(432000));
      expect(schedule.warmup, isFalse);
      expect(schedule.firstNormalEpoch, equals(14));
      expect(schedule.firstNormalSlot, equals(524256));
    });

    test('getEpochSchedule sends no params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture({
        'slotsPerEpoch': 432000,
        'leaderScheduleSlotOffset': 432000,
        'warmup': false,
        'firstNormalEpoch': 14,
        'firstNormalSlot': 524256,
      }, (body) => captured = body);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getEpochSchedule();
      expect(captured!['method'], equals('getEpochSchedule'));
      expect(captured!['params'], isEmpty);
    });

    // --- getLeaderSchedule ---
    test('getLeaderSchedule returns Map<String, List<int>>', () async {
      final mock = _mockClient({
        '85iYT5RuzRTDgjyRa3cP8SYhM2j21fj7NhfJ3peu1DPr': [0, 1, 2, 3],
        'ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB': [4, 5, 6],
      });
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final schedule = await client.getLeaderSchedule();
      expect(schedule, isNotNull);
      expect(
        schedule!['85iYT5RuzRTDgjyRa3cP8SYhM2j21fj7NhfJ3peu1DPr'],
        equals([0, 1, 2, 3]),
      );
      expect(
        schedule['ENvAW7JScgYq6o4zKZwewtkzzJgDzb1wAGcLtm1pXnBB'],
        equals([4, 5, 6]),
      );
    });

    test('getLeaderSchedule returns null when no data', () async {
      final mock = _mockClient(null);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      final schedule = await client.getLeaderSchedule();
      expect(schedule, isNull);
    });

    test('getLeaderSchedule sends slot and identity params', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture({
        'leader1': [0, 1],
      }, (body) => captured = body);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getLeaderSchedule(
        slot: 100,
        identity: 'leader1',
        commitment: SolanaCommitment.finalized,
      );
      expect(captured!['method'], equals('getLeaderSchedule'));
      final params = captured!['params'] as List;
      expect(params[0], equals(100));
      final configMap = params[1] as Map<String, dynamic>;
      expect(configMap['identity'], equals('leader1'));
      expect(configMap['commitment'], equals('finalized'));
    });

    test('getLeaderSchedule sends null slot for current epoch', () async {
      Map<String, dynamic>? captured;
      final mock = _mockClientCapture({
        'leader1': [0, 1],
      }, (body) => captured = body);
      final client = _TestClient(
        JsonRpcTransport(config: config, httpClient: mock),
      );

      await client.getLeaderSchedule();
      expect(captured!['method'], equals('getLeaderSchedule'));
      final params = captured!['params'] as List;
      // When no slot specified, first param should be null
      expect(params[0], isNull);
    });
  });
}
