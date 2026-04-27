import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:ceres_wallet_onchain/src/core/rest_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_exception.dart';
import 'package:ceres_wallet_onchain/src/tron/methods/contract_methods.dart';
import 'package:ceres_wallet_onchain/src/tron/tron_address.dart';

/// Test harness class that applies the mixin.
class _TestContractClient with TronContractMethods {
  @override
  final RestTransport transport;
  _TestContractClient(this.transport);
}

/// Creates a [MockClient] that captures requests and returns [responseBody].
MockClient _mockClient(
  Object responseBody, {
  void Function(http.Request request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode(responseBody),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Helper: build a test client with request capture.
_TestContractClient _buildClient(
  Object responseBody, {
  required void Function(String path, Map<String, dynamic> body) onCapture,
}) {
  final mock = _mockClient(
    responseBody,
    onRequest: (req) {
      onCapture(req.url.path, jsonDecode(req.body) as Map<String, dynamic>);
    },
  );
  final transport = RestTransport(
    config: RpcClientConfig(baseUrl: 'https://api.trongrid.io'),
    httpClient: mock,
  );
  return _TestContractClient(transport);
}

// Known valid test addresses (verified base58check).
final _ownerAddr = TronAddress('TUzkbvJDzsbqdP3T4Gm35RebBDNJoeVgFA');
// Second address from hex (different 20-byte address).
final _contractAddr = TronAddress('419e62be7f4f103c36507cb2a753418791b1cdc182');

/// Successful triggerSmartContract response with transaction.
Map<String, dynamic> _triggerSuccessJson() => {
  'result': {'result': true},
  'energy_used': 30000,
  'transaction': {
    'txID': 'tx_abc123',
    'raw_data': {
      'contract': [
        {'type': 'TriggerSmartContract'},
      ],
      'ref_block_bytes': 'abcd',
      'ref_block_hash': '1234567890abcdef',
      'expiration': 1700000060000,
      'timestamp': 1700000000000,
      'fee_limit': 100000000,
    },
    'raw_data_hex': 'cafebabe',
  },
};

/// Failed trigger response.
Map<String, dynamic> _triggerFailJson() => {
  'result': {
    'result': false,
    'code': 'CONTRACT_VALIDATE_ERROR',
    'message': utf8
        .encode('balance is not sufficient')
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(),
  },
};

/// Successful constant call response.
Map<String, dynamic> _constantResultJson() => {
  'result': {'result': true},
  'energy_used': 895,
  'energy_penalty': 0,
  'constant_result': [
    '0000000000000000000000000000000000000000000000000000000005f5e100',
  ],
};

/// Transaction response for deploy/update/clearAbi.
Map<String, dynamic> _transactionJson() => {
  'txID': 'deploy_tx_123',
  'raw_data': {
    'contract': [
      {'type': 'CreateSmartContract'},
    ],
    'ref_block_bytes': 'abcd',
    'ref_block_hash': '1234567890abcdef',
    'expiration': 1700000060000,
    'timestamp': 1700000000000,
  },
  'raw_data_hex': 'deadbeef',
};

void main() {
  late String capturedPath;
  late Map<String, dynamic> capturedBody;

  void capture(String path, Map<String, dynamic> body) {
    capturedPath = path;
    capturedBody = body;
  }

  group('TronContractMethods', () {
    // TRON-25: triggerSmartContract
    group('triggerSmartContract', () {
      test(
        'POSTs to /wallet/triggersmartcontract and returns TronTriggerResult',
        () async {
          final client = _buildClient(
            _triggerSuccessJson(),
            onCapture: capture,
          );
          final result = await client.triggerSmartContract(
            ownerAddress: _ownerAddr,
            contractAddress: _contractAddr,
            functionSelector: 'transfer(address,uint256)',
            parameter: 'abcdef',
            feeLimit: BigInt.from(100000000),
            callValue: BigInt.from(0),
          );

          expect(capturedPath, '/wallet/triggersmartcontract');
          expect(capturedBody['owner_address'], _ownerAddr.toBase58());
          expect(capturedBody['contract_address'], _contractAddr.toBase58());
          expect(
            capturedBody['function_selector'],
            'transfer(address,uint256)',
          );
          expect(capturedBody['parameter'], 'abcdef');
          expect(capturedBody['fee_limit'], 100000000);
          expect(capturedBody['call_value'], 0);
          expect(capturedBody['visible'], true);
          expect(result.resultOk, true);
          expect(result.transaction, isNotNull);
          expect(result.transaction!.txID, 'tx_abc123');
        },
      );

      test('throws RpcException on error result', () async {
        final client = _buildClient(_triggerFailJson(), onCapture: capture);

        expect(
          () => client.triggerSmartContract(
            ownerAddress: _ownerAddr,
            contractAddress: _contractAddr,
            functionSelector: 'transfer(address,uint256)',
          ),
          throwsA(
            isA<RpcException>().having(
              (e) => e.message,
              'message',
              contains('balance is not sufficient'),
            ),
          ),
        );
      });

      test('omits optional fields when not provided', () async {
        final client = _buildClient(_triggerSuccessJson(), onCapture: capture);
        await client.triggerSmartContract(
          ownerAddress: _ownerAddr,
          contractAddress: _contractAddr,
          functionSelector: 'balanceOf(address)',
        );

        expect(capturedBody.containsKey('fee_limit'), false);
        expect(capturedBody.containsKey('call_value'), false);
        expect(capturedBody['parameter'], '');
      });
    });

    // TRON-26: triggerConstantContract
    group('triggerConstantContract', () {
      test('POSTs to /wallet/triggerconstantcontract', () async {
        final client = _buildClient(_constantResultJson(), onCapture: capture);
        final result = await client.triggerConstantContract(
          ownerAddress: _ownerAddr,
          contractAddress: _contractAddr,
          functionSelector: 'balanceOf(address)',
          parameter: '0000000000000000000000001234',
        );

        expect(capturedPath, '/wallet/triggerconstantcontract');
        expect(capturedBody['visible'], true);
        expect(result.resultOk, true);
        expect(result.constantResult.length, 1);
      });
    });

    // TRON-27: triggerConstantContractSolidity
    test(
      'triggerConstantContractSolidity POSTs to /walletsolidity/triggerconstantcontract',
      () async {
        final client = _buildClient(_constantResultJson(), onCapture: capture);
        final result = await client.triggerConstantContractSolidity(
          ownerAddress: _ownerAddr,
          contractAddress: _contractAddr,
          functionSelector: 'balanceOf(address)',
        );

        expect(capturedPath, '/walletsolidity/triggerconstantcontract');
        expect(result.constantResult, isNotEmpty);
      },
    );

    // TRON-28: deployContract
    test('deployContract POSTs to /wallet/deploycontract', () async {
      final client = _buildClient(_transactionJson(), onCapture: capture);
      final tx = await client.deployContract(
        ownerAddress: _ownerAddr,
        abi: '[{"inputs":[],"type":"constructor"}]',
        bytecode: '608060405234801561001057600080fd',
        feeLimit: BigInt.from(1000000000),
        name: 'TestContract',
        consumeUserResourcePercent: 10,
        originEnergyLimit: 100000,
      );

      expect(capturedPath, '/wallet/deploycontract');
      expect(capturedBody['owner_address'], _ownerAddr.toBase58());
      expect(capturedBody['abi'], '[{"inputs":[],"type":"constructor"}]');
      expect(capturedBody['bytecode'], '608060405234801561001057600080fd');
      expect(capturedBody['fee_limit'], 1000000000);
      expect(capturedBody['name'], 'TestContract');
      expect(capturedBody['consume_user_resource_percent'], 10);
      expect(capturedBody['origin_energy_limit'], 100000);
      expect(capturedBody['visible'], true);
      expect(tx.txID, 'deploy_tx_123');
    });

    // TRON-29: estimateEnergy
    test('estimateEnergy POSTs to /wallet/estimateenergy', () async {
      final client = _buildClient({
        'energy_required': 50000,
      }, onCapture: capture);
      final result = await client.estimateEnergy(
        ownerAddress: _ownerAddr,
        contractAddress: _contractAddr,
        functionSelector: 'transfer(address,uint256)',
        parameter: 'abcdef',
      );

      expect(capturedPath, '/wallet/estimateenergy');
      expect(capturedBody['visible'], true);
      expect(result['energy_required'], 50000);
    });

    // TRON-30: getContract
    test('getContract POSTs to /wallet/getcontract', () async {
      final client = _buildClient({
        'bytecode': 'abc',
        'abi': {'entrys': []},
      }, onCapture: capture);
      final result = await client.getContract(_contractAddr);

      expect(capturedPath, '/wallet/getcontract');
      expect(capturedBody['value'], _contractAddr.toBase58());
      expect(capturedBody['visible'], true);
      expect(result['bytecode'], 'abc');
    });

    // TRON-31: getContractInfo
    test('getContractInfo POSTs to /wallet/getcontractinfo', () async {
      final client = _buildClient({
        'contract_state': 'normal',
      }, onCapture: capture);
      final result = await client.getContractInfo(_contractAddr);

      expect(capturedPath, '/wallet/getcontractinfo');
      expect(capturedBody['value'], _contractAddr.toBase58());
      expect(capturedBody['visible'], true);
      expect(result['contract_state'], 'normal');
    });

    // TRON-32: updateSetting
    test('updateSetting POSTs to /wallet/updatesetting', () async {
      final client = _buildClient(_transactionJson(), onCapture: capture);
      final tx = await client.updateSetting(
        ownerAddress: _ownerAddr,
        contractAddress: _contractAddr,
        consumeUserResourcePercent: 50,
      );

      expect(capturedPath, '/wallet/updatesetting');
      expect(capturedBody['owner_address'], _ownerAddr.toBase58());
      expect(capturedBody['contract_address'], _contractAddr.toBase58());
      expect(capturedBody['consume_user_resource_percent'], 50);
      expect(capturedBody['visible'], true);
      expect(tx.txID, isNotNull);
    });

    // TRON-33: updateEnergyLimit
    test('updateEnergyLimit POSTs to /wallet/updateenergylimit', () async {
      final client = _buildClient(_transactionJson(), onCapture: capture);
      final tx = await client.updateEnergyLimit(
        ownerAddress: _ownerAddr,
        contractAddress: _contractAddr,
        originEnergyLimit: 200000,
      );

      expect(capturedPath, '/wallet/updateenergylimit');
      expect(capturedBody['owner_address'], _ownerAddr.toBase58());
      expect(capturedBody['contract_address'], _contractAddr.toBase58());
      expect(capturedBody['origin_energy_limit'], 200000);
      expect(capturedBody['visible'], true);
      expect(tx.txID, isNotNull);
    });

    // TRON-34: clearAbi
    test('clearAbi POSTs to /wallet/clearabi', () async {
      final client = _buildClient(_transactionJson(), onCapture: capture);
      final tx = await client.clearAbi(
        ownerAddress: _ownerAddr,
        contractAddress: _contractAddr,
      );

      expect(capturedPath, '/wallet/clearabi');
      expect(capturedBody['owner_address'], _ownerAddr.toBase58());
      expect(capturedBody['contract_address'], _contractAddr.toBase58());
      expect(capturedBody['visible'], true);
      expect(tx.txID, isNotNull);
    });
  });
}
