import 'package:ceres_wallet_onchain/src/sui/models/sui_object_owner.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_object_data.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_object_response.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_object_change.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_effects.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_transaction_block_response.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_dry_run_result.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_system_state.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_protocol_config.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_move_module.dart';
import 'package:test/test.dart';

void main() {
  group('SuiObjectOwner', () {
    test('fromJson parses "Immutable" string', () {
      final owner = SuiObjectOwner.fromJson('Immutable');
      expect(owner, isA<SuiObjectOwnerImmutable>());
    });

    test('fromJson parses AddressOwner map', () {
      final owner = SuiObjectOwner.fromJson({
        'AddressOwner':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      });
      expect(owner, isA<SuiObjectOwnerAddress>());
      expect(
        (owner as SuiObjectOwnerAddress).address,
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
    });

    test('fromJson parses ObjectOwner map', () {
      final owner = SuiObjectOwner.fromJson({
        'ObjectOwner':
            '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      });
      expect(owner, isA<SuiObjectOwnerObject>());
      expect(
        (owner as SuiObjectOwnerObject).objectId,
        '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      );
    });

    test('fromJson parses Shared map', () {
      final owner = SuiObjectOwner.fromJson({
        'Shared': {'initial_shared_version': 1},
      });
      expect(owner, isA<SuiObjectOwnerShared>());
      expect((owner as SuiObjectOwnerShared).initialSharedVersion, BigInt.one);
    });

    test('fromJson parses ConsensusV2 map', () {
      final owner = SuiObjectOwner.fromJson({
        'ConsensusV2': {
          'start_version': 42,
          'authenticator': {'type': 'SingleOwner', 'owner': '0xabc'},
        },
      });
      expect(owner, isA<SuiObjectOwnerConsensusV2>());
      final cv2 = owner as SuiObjectOwnerConsensusV2;
      expect(cv2.startVersion, BigInt.from(42));
      expect(cv2.authenticator['type'], 'SingleOwner');
    });

    test('fromJson returns Unknown for unrecognized types', () {
      final owner = SuiObjectOwner.fromJson({'FutureType': 'data'});
      expect(owner, isA<SuiObjectOwnerUnknown>());
    });

    test('fromJson returns Unknown for null input', () {
      final owner = SuiObjectOwner.fromJson(null);
      expect(owner, isA<SuiObjectOwnerUnknown>());
    });
  });

  group('SuiObjectData', () {
    test('fromJson parses all fields', () {
      final data = SuiObjectData.fromJson({
        'objectId': '0xobj1',
        'version': '100',
        'digest': 'abc123',
        'type': '0x2::coin::Coin<0x2::sui::SUI>',
        'owner': {'AddressOwner': '0xowner'},
        'previousTransaction': 'txdigest1',
        'storageRebate': '1000',
        'content': {'type': 'moveObject', 'fields': {}},
        'bcs': {'type': 'moveObject', 'bcsBytes': 'AA=='},
        'display': {'data': null, 'error': null},
      });
      expect(data.objectId, '0xobj1');
      expect(data.version, BigInt.from(100));
      expect(data.digest, 'abc123');
      expect(data.type, '0x2::coin::Coin<0x2::sui::SUI>');
      expect(data.owner, isA<SuiObjectOwnerAddress>());
      expect(data.previousTransaction, 'txdigest1');
      expect(data.storageRebate, BigInt.from(1000));
      expect(data.content, isNotNull);
      expect(data.bcs, isNotNull);
      expect(data.display, isNotNull);
    });

    test('fromJson handles nullable fields as null', () {
      final data = SuiObjectData.fromJson({
        'objectId': '0xobj2',
        'version': '1',
        'digest': 'xyz',
      });
      expect(data.objectId, '0xobj2');
      expect(data.version, BigInt.one);
      expect(data.type, isNull);
      expect(data.owner, isNull);
      expect(data.previousTransaction, isNull);
      expect(data.storageRebate, isNull);
      expect(data.content, isNull);
      expect(data.bcs, isNull);
      expect(data.display, isNull);
    });
  });

  group('SuiObjectResponse', () {
    test('fromJson parses data field', () {
      final resp = SuiObjectResponse.fromJson({
        'data': {'objectId': '0xobj', 'version': '5', 'digest': 'dig'},
      });
      expect(resp.data, isNotNull);
      expect(resp.data!.objectId, '0xobj');
      expect(resp.error, isNull);
    });

    test('fromJson parses error field', () {
      final resp = SuiObjectResponse.fromJson({
        'error': {'code': 'notExists', 'object_id': '0xmissing'},
      });
      expect(resp.data, isNull);
      expect(resp.error, isNotNull);
      expect(resp.error!.code, 'notExists');
      expect(resp.error!.objectId, '0xmissing');
    });
  });

  group('SuiPastObjectResponse', () {
    test('fromJson parses status and details', () {
      final past = SuiPastObjectResponse.fromJson({
        'status': 'VersionFound',
        'details': {'objectId': '0xpast', 'version': '10', 'digest': 'pastdig'},
      });
      expect(past.status, 'VersionFound');
      expect(past.details, isNotNull);
      expect(past.details!.objectId, '0xpast');
    });

    test('fromJson handles missing details', () {
      final past = SuiPastObjectResponse.fromJson({
        'status': 'ObjectNotExists',
      });
      expect(past.status, 'ObjectNotExists');
      expect(past.details, isNull);
    });
  });

  group('SuiObjectChange', () {
    test('fromJson parses published change', () {
      final change = SuiObjectChange.fromJson({
        'type': 'published',
        'packageId': '0xpkg1',
        'version': '1',
        'digest': 'pkgdig',
        'modules': ['module1', 'module2'],
      });
      expect(change.type, 'published');
      expect(change.packageId, '0xpkg1');
      expect(change.modules, ['module1', 'module2']);
    });

    test('fromJson parses created change', () {
      final change = SuiObjectChange.fromJson({
        'type': 'created',
        'sender': '0xsender',
        'owner': {'AddressOwner': '0xowner'},
        'objectType': '0x2::coin::Coin<0x2::sui::SUI>',
        'objectId': '0xnewobj',
        'version': '1',
        'digest': 'newdig',
      });
      expect(change.type, 'created');
      expect(change.sender, '0xsender');
      expect(change.owner, isA<SuiObjectOwnerAddress>());
      expect(change.objectType, '0x2::coin::Coin<0x2::sui::SUI>');
      expect(change.objectId, '0xnewobj');
    });

    test('fromJson parses mutated change', () {
      final change = SuiObjectChange.fromJson({
        'type': 'mutated',
        'sender': '0xsender',
        'owner': {'AddressOwner': '0xowner'},
        'objectType': '0x2::coin::Coin<0x2::sui::SUI>',
        'objectId': '0xmutobj',
        'version': '5',
        'previousVersion': '4',
        'digest': 'mutdig',
      });
      expect(change.type, 'mutated');
      expect(change.objectId, '0xmutobj');
      expect(change.previousVersion, BigInt.from(4));
    });
  });

  group('SuiExecutionStatus', () {
    test('fromJson parses success status', () {
      final status = SuiExecutionStatus.fromJson({'status': 'success'});
      expect(status.isSuccess, isTrue);
      expect(status.error, isNull);
    });

    test('fromJson parses failure status with error', () {
      final status = SuiExecutionStatus.fromJson({
        'status': 'failure',
        'error': 'InsufficientGas',
      });
      expect(status.isSuccess, isFalse);
      expect(status.error, 'InsufficientGas');
    });
  });

  group('SuiTransactionEffects', () {
    test('fromJson parses all core fields', () {
      final effects = SuiTransactionEffects.fromJson({
        'messageVersion': 'v1',
        'status': {'status': 'success'},
        'executedEpoch': '100',
        'gasUsed': {
          'computationCost': '1000000',
          'storageCost': '2000000',
          'storageRebate': '500000',
          'nonRefundableStorageFee': '100000',
        },
        'transactionDigest': 'txdig123',
        'mutated': [
          {
            'owner': {'AddressOwner': '0xowner'},
            'reference': {'objectId': '0xobj', 'version': 5, 'digest': 'd'},
          },
        ],
        'created': [],
        'deleted': [],
        'gasObject': {
          'owner': {'AddressOwner': '0xowner'},
          'reference': {'objectId': '0xgas', 'version': 5, 'digest': 'gd'},
        },
      });
      expect(effects.status.isSuccess, isTrue);
      expect(effects.gasUsed.computationCost, BigInt.from(1000000));
      expect(effects.transactionDigest, 'txdig123');
      expect(effects.executedEpoch, '100');
    });
  });

  group('SuiBalanceChange', () {
    test('fromJson parses positive amount', () {
      final bc = SuiBalanceChange.fromJson({
        'owner': {'AddressOwner': '0xowner'},
        'coinType': '0x2::sui::SUI',
        'amount': '1000000000',
      });
      expect(bc.owner, isA<SuiObjectOwnerAddress>());
      expect(bc.coinType, '0x2::sui::SUI');
      expect(bc.amount, BigInt.from(1000000000));
    });

    test('fromJson parses negative amount', () {
      final bc = SuiBalanceChange.fromJson({
        'owner': {'AddressOwner': '0xowner'},
        'coinType': '0x2::sui::SUI',
        'amount': '-500000',
      });
      expect(bc.amount, BigInt.from(-500000));
    });
  });

  group('SuiTransactionBlockResponse', () {
    test('fromJson parses minimal response (digest only)', () {
      final resp = SuiTransactionBlockResponse.fromJson({
        'digest': 'txdigest123',
      });
      expect(resp.digest, 'txdigest123');
      expect(resp.effects, isNull);
      expect(resp.events, isNull);
      expect(resp.objectChanges, isNull);
      expect(resp.balanceChanges, isNull);
      expect(resp.transaction, isNull);
      expect(resp.timestampMs, isNull);
      expect(resp.checkpoint, isNull);
    });

    test('fromJson parses full response with effects and events', () {
      final resp = SuiTransactionBlockResponse.fromJson({
        'digest': 'txdig456',
        'effects': {
          'messageVersion': 'v1',
          'status': {'status': 'success'},
          'executedEpoch': '50',
          'gasUsed': {
            'computationCost': '100',
            'storageCost': '200',
            'storageRebate': '50',
            'nonRefundableStorageFee': '10',
          },
          'transactionDigest': 'txdig456',
        },
        'events': [
          {
            'id': {'txDigest': 'txdig456', 'eventSeq': '0'},
            'packageId': '0xpkg',
            'transactionModule': 'module',
            'sender': '0xsender',
            'type': '0xpkg::module::Event',
          },
        ],
        'timestampMs': '1700000000000',
        'checkpoint': '12345',
        'confirmedLocalExecution': true,
      });
      expect(resp.digest, 'txdig456');
      expect(resp.effects, isNotNull);
      expect(resp.effects!.status.isSuccess, isTrue);
      expect(resp.events, isNotNull);
      expect(resp.events!.length, 1);
      expect(resp.timestampMs, '1700000000000');
      expect(resp.checkpoint, '12345');
      expect(resp.confirmedLocalExecution, isTrue);
    });
  });

  group('SuiDryRunResult', () {
    test('fromJson parses effects and events', () {
      final result = SuiDryRunResult.fromJson({
        'effects': {
          'messageVersion': 'v1',
          'status': {'status': 'success'},
          'executedEpoch': '0',
          'gasUsed': {
            'computationCost': '100',
            'storageCost': '200',
            'storageRebate': '50',
            'nonRefundableStorageFee': '10',
          },
          'transactionDigest': 'drydig',
        },
        'events': [],
        'balanceChanges': [
          {
            'owner': {'AddressOwner': '0xowner'},
            'coinType': '0x2::sui::SUI',
            'amount': '-100',
          },
        ],
        'input': {'type': 'pure', 'valueType': 'u64', 'value': '100'},
      });
      expect(result.effects.status.isSuccess, isTrue);
      expect(result.events, isEmpty);
      expect(result.balanceChanges.length, 1);
      expect(result.balanceChanges[0].amount, BigInt.from(-100));
      expect(result.input, isNotNull);
    });
  });

  group('SuiSystemState', () {
    test('fromJson wraps raw map and exposes shortcuts', () {
      final state = SuiSystemState.fromJson({
        'epoch': '100',
        'protocolVersion': '42',
        'systemStateVersion': '1',
        'referenceGasPrice': '1000',
        'safeMode': false,
        'stakingPoolMappingsId': '0xabc',
        'validatorsAtRisk': [],
      });
      expect(state.epoch, '100');
      expect(state.protocolVersion, '42');
      expect(state.systemStateVersion, '1');
      expect(state.referenceGasPrice, BigInt.from(1000));
      expect(state.safeMode, isFalse);
      expect(state.raw['stakingPoolMappingsId'], '0xabc');
    });
  });

  group('SuiProtocolConfig', () {
    test('fromJson parses version fields and attributes', () {
      final config = SuiProtocolConfig.fromJson({
        'protocolVersion': '42',
        'minSupportedProtocolVersion': '1',
        'maxSupportedProtocolVersion': '42',
        'featureFlags': {'some_flag': true},
        'attributes': {
          'max_gas': {'u64': '1000000'},
        },
      });
      expect(config.protocolVersion, '42');
      expect(config.minSupportedProtocolVersion, '1');
      expect(config.maxSupportedProtocolVersion, '42');
      expect(config.attributes['max_gas'], isNotNull);
      expect(config.featureFlags['some_flag'], isTrue);
    });
  });

  group('MoveNormalizedModule', () {
    test('fromJson parses module structure', () {
      final module = MoveNormalizedModule.fromJson({
        'fileFormatVersion': 6,
        'address': '0x2',
        'name': 'coin',
        'friends': [
          {'address': '0x2', 'name': 'pay'},
        ],
        'structs': {
          'Coin': {
            'abilities': {
              'abilities': ['drop', 'store'],
            },
            'typeParameters': [],
            'fields': [
              {
                'name': 'id',
                'type': {'Struct': {}},
              },
              {
                'name': 'balance',
                'type': {'Struct': {}},
              },
            ],
          },
        },
        'exposedFunctions': {
          'transfer': {
            'visibility': 'Public',
            'isEntry': true,
            'typeParameters': [],
            'parameters': [],
            'return': [],
          },
        },
      });
      expect(module.fileFormatVersion, 6);
      expect(module.address, '0x2');
      expect(module.name, 'coin');
      expect(module.friends.length, 1);
      expect(module.structs.containsKey('Coin'), isTrue);
      expect(module.exposedFunctions.containsKey('transfer'), isTrue);
    });
  });

  group('MoveNormalizedFunction', () {
    test('fromJson parses function details', () {
      final fn = MoveNormalizedFunction.fromJson({
        'visibility': 'Public',
        'isEntry': true,
        'typeParameters': [
          {
            'abilities': ['drop'],
          },
        ],
        'parameters': [
          {
            'MutableReference': {'Struct': {}},
          },
        ],
        'return': ['U64'],
      });
      expect(fn.visibility, 'Public');
      expect(fn.isEntry, isTrue);
      expect(fn.typeParameters.length, 1);
      expect(fn.parameters.length, 1);
      expect(fn.returnTypes.length, 1);
    });
  });

  group('MoveNormalizedStruct', () {
    test('fromJson parses struct with fields', () {
      final s = MoveNormalizedStruct.fromJson({
        'abilities': {
          'abilities': ['drop', 'store'],
        },
        'typeParameters': [],
        'fields': [
          {'name': 'value', 'type': 'U64'},
        ],
      });
      expect(s.abilities, isNotNull);
      expect(s.typeParameters, isEmpty);
      expect(s.fields.length, 1);
      expect(s.fields[0].name, 'value');
    });
  });
}
