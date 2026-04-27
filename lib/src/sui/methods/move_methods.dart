/// Sui Move introspection and committee info RPC methods.
///
/// Provides methods for querying normalized Move modules, functions,
/// structs, and committee information.
///
/// Contains 5 methods: getNormalizedMoveModulesByPackage,
/// getNormalizedMoveModule, getNormalizedMoveFunction,
/// getNormalizedMoveStruct, getCommitteeInfo.
library;

import '../../core/json_rpc_transport.dart';
import '../models/sui_committee_info.dart';
import '../models/sui_move_module.dart';

/// Move introspection and committee info RPC methods for Sui.
///
/// Requires access to a [JsonRpcTransport] via the `transport` getter.
mixin SuiMoveMethods {
  /// The JSON-RPC transport used to send requests.
  JsonRpcTransport get transport;

  /// Returns all normalized Move modules in a package.
  ///
  /// Calls `sui_getNormalizedMoveModulesByPackage` with [packageId].
  /// Returns a map of module name to [MoveNormalizedModule].
  ///
  /// ```dart
  /// final modules = await client.getNormalizedMoveModulesByPackage('0x2');
  /// for (final entry in modules.entries) {
  ///   print('${entry.key}: ${entry.value.exposedFunctions.length} functions');
  /// }
  /// ```
  Future<Map<String, MoveNormalizedModule>> getNormalizedMoveModulesByPackage(
    String packageId,
  ) async {
    final result = await transport.send(
      'sui_getNormalizedMoveModulesByPackage',
      [packageId],
    );
    final raw = result as Map<String, dynamic>;
    return raw.map(
      (key, value) => MapEntry(
        key,
        MoveNormalizedModule.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  /// Returns the normalized Move module for a given package and module name.
  ///
  /// Calls `sui_getNormalizedMoveModule` with [packageId] and [moduleName].
  ///
  /// ```dart
  /// final module = await client.getNormalizedMoveModule('0x2', 'coin');
  /// print('${module.name}: ${module.structs.length} structs');
  /// ```
  Future<MoveNormalizedModule> getNormalizedMoveModule(
    String packageId,
    String moduleName,
  ) async {
    final result = await transport.send('sui_getNormalizedMoveModule', [
      packageId,
      moduleName,
    ]);
    return MoveNormalizedModule.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the normalized Move function.
  ///
  /// Calls `sui_getNormalizedMoveFunction` with [packageId], [moduleName],
  /// and [functionName].
  ///
  /// ```dart
  /// final fn = await client.getNormalizedMoveFunction('0x2', 'coin', 'transfer');
  /// print('entry: ${fn.isEntry}, params: ${fn.parameters.length}');
  /// ```
  Future<MoveNormalizedFunction> getNormalizedMoveFunction(
    String packageId,
    String moduleName,
    String functionName,
  ) async {
    final result = await transport.send('sui_getNormalizedMoveFunction', [
      packageId,
      moduleName,
      functionName,
    ]);
    return MoveNormalizedFunction.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the normalized Move struct.
  ///
  /// Calls `sui_getNormalizedMoveStruct` with [packageId], [moduleName],
  /// and [structName].
  ///
  /// ```dart
  /// final s = await client.getNormalizedMoveStruct('0x2', 'coin', 'Coin');
  /// for (final field in s.fields) {
  ///   print('${field.name}: ${field.type}');
  /// }
  /// ```
  Future<MoveNormalizedStruct> getNormalizedMoveStruct(
    String packageId,
    String moduleName,
    String structName,
  ) async {
    final result = await transport.send('sui_getNormalizedMoveStruct', [
      packageId,
      moduleName,
      structName,
    ]);
    return MoveNormalizedStruct.fromJson(result as Map<String, dynamic>);
  }

  /// Returns the committee information for the given epoch.
  ///
  /// Calls `suix_getCommitteeInfo`. If [epoch] is `null`, returns the
  /// committee for the current epoch.
  ///
  /// ```dart
  /// final info = await client.getCommitteeInfo();
  /// print('Epoch ${info.epoch}: ${info.validators.length} validators');
  /// ```
  Future<CommitteeInfo> getCommitteeInfo({String? epoch}) async {
    final params = epoch != null ? <dynamic>[epoch] : <dynamic>[];
    final result = await transport.send('suix_getCommitteeInfo', params);
    return CommitteeInfo.fromJson(result as Map<String, dynamic>);
  }
}
