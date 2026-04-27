/// Tron smart contract methods mixin (TRON-25 ~ TRON-34).
///
/// Provides typed access to all Tron contract-related HTTP API endpoints,
/// including trigger (write), constant (read-only), deploy, and management
/// operations.
///
/// **Important (D-08):** [triggerSmartContract] returns an unsigned
/// transaction body in [TronTriggerResult.transaction]. The caller is
/// responsible for signing via `ceres_wallet_core` before broadcasting.
///
/// This mixin requires a [RestTransport] via the abstract [transport] getter.
///
/// ```dart
/// class TronClient with TronContractMethods {
///   @override
///   final RestTransport transport;
///   TronClient(this.transport);
/// }
/// ```
library;

import '../../core/rest_transport.dart';
import '../models/tron_transaction.dart';
import '../models/tron_trigger_result.dart';
import '../tron_address.dart';
import '../tron_error.dart';

/// Smart contract Tron HTTP API methods.
///
/// Covers 10 endpoints:
/// - [triggerSmartContract] — write call (returns unsigned tx)
/// - [triggerConstantContract] / [triggerConstantContractSolidity] — read call
/// - [deployContract] — deploy new contract
/// - [estimateEnergy] — energy estimation
/// - [getContract] / [getContractInfo] — contract metadata
/// - [updateSetting] / [updateEnergyLimit] / [clearAbi] — contract management
mixin TronContractMethods {
  /// The REST transport used to send requests.
  RestTransport get transport;

  /// TRON-25: Triggers a smart contract write call.
  ///
  /// Returns a [TronTriggerResult] containing the unsigned transaction body
  /// in [TronTriggerResult.transaction]. The caller must sign the transaction
  /// externally before broadcasting.
  ///
  /// [functionSelector] is the Solidity function signature, e.g.,
  /// `"transfer(address,uint256)"`.
  ///
  /// [parameter] is the hex-encoded ABI parameters (without `0x` prefix).
  ///
  /// Throws [RpcException] if the Tron node returns an error result
  /// (via [checkTronError]).
  Future<TronTriggerResult> triggerSmartContract({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required String functionSelector,
    String parameter = '',
    BigInt? feeLimit,
    BigInt? callValue,
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'function_selector': functionSelector,
      'parameter': parameter,
      'visible': true,
    };
    if (feeLimit != null) body['fee_limit'] = feeLimit.toInt();
    if (callValue != null) body['call_value'] = callValue.toInt();

    final result = await transport.post('/wallet/triggersmartcontract', body);
    checkTronError(result);
    return TronTriggerResult.fromJson(result);
  }

  /// TRON-26: Triggers a constant (read-only) smart contract call.
  ///
  /// Returns a [TronTriggerResult] with [TronTriggerResult.constantResult]
  /// containing the return data as hex strings.
  ///
  /// Does not create a transaction on-chain.
  Future<TronTriggerResult> triggerConstantContract({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required String functionSelector,
    String parameter = '',
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'function_selector': functionSelector,
      'parameter': parameter,
      'visible': true,
    };
    final result = await transport.post(
      '/wallet/triggerconstantcontract',
      body,
    );
    return TronTriggerResult.fromJson(result);
  }

  /// TRON-27: Triggers a constant contract call via the solidity node.
  ///
  /// Same as [triggerConstantContract] but routes to the confirmed
  /// (solidity) node for stronger consistency.
  Future<TronTriggerResult> triggerConstantContractSolidity({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required String functionSelector,
    String parameter = '',
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'function_selector': functionSelector,
      'parameter': parameter,
      'visible': true,
    };
    final result = await transport.post(
      '/walletsolidity/triggerconstantcontract',
      body,
    );
    return TronTriggerResult.fromJson(result);
  }

  /// TRON-28: Deploys a new smart contract.
  ///
  /// Returns the unsigned [TronTransaction] for signing and broadcasting.
  ///
  /// [abi] is the contract ABI JSON string.
  /// [bytecode] is the compiled contract bytecode hex string.
  Future<TronTransaction> deployContract({
    required TronAddress ownerAddress,
    required String abi,
    required String bytecode,
    BigInt? feeLimit,
    BigInt? callValue,
    int? consumeUserResourcePercent,
    int? originEnergyLimit,
    String? name,
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'abi': abi,
      'bytecode': bytecode,
      'visible': true,
    };
    if (feeLimit != null) body['fee_limit'] = feeLimit.toInt();
    if (callValue != null) body['call_value'] = callValue.toInt();
    if (consumeUserResourcePercent != null) {
      body['consume_user_resource_percent'] = consumeUserResourcePercent;
    }
    if (originEnergyLimit != null) {
      body['origin_energy_limit'] = originEnergyLimit;
    }
    if (name != null) body['name'] = name;

    final result = await transport.post('/wallet/deploycontract', body);
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// TRON-29: Estimates energy consumption for a contract call.
  ///
  /// Returns the raw API response map containing `energy_required`
  /// and other estimation fields.
  Future<Map<String, dynamic>> estimateEnergy({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required String functionSelector,
    String parameter = '',
  }) async {
    final body = <String, dynamic>{
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'function_selector': functionSelector,
      'parameter': parameter,
      'visible': true,
    };
    return await transport.post('/wallet/estimateenergy', body);
  }

  /// TRON-30: Returns the contract ABI and bytecode.
  ///
  /// [contractAddress] is the deployed contract address.
  Future<Map<String, dynamic>> getContract(TronAddress contractAddress) async {
    return await transport.post('/wallet/getcontract', {
      'value': contractAddress.toBase58(),
      'visible': true,
    });
  }

  /// TRON-31: Returns contract details including state and resource info.
  ///
  /// [contractAddress] is the deployed contract address.
  Future<Map<String, dynamic>> getContractInfo(
    TronAddress contractAddress,
  ) async {
    return await transport.post('/wallet/getcontractinfo', {
      'value': contractAddress.toBase58(),
      'visible': true,
    });
  }

  /// TRON-32: Updates the `consume_user_resource_percent` setting.
  ///
  /// Returns the unsigned [TronTransaction] for signing and broadcasting.
  Future<TronTransaction> updateSetting({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required int consumeUserResourcePercent,
  }) async {
    final result = await transport.post('/wallet/updatesetting', {
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'consume_user_resource_percent': consumeUserResourcePercent,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// TRON-33: Updates the `origin_energy_limit` for a contract.
  ///
  /// Returns the unsigned [TronTransaction] for signing and broadcasting.
  Future<TronTransaction> updateEnergyLimit({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
    required int originEnergyLimit,
  }) async {
    final result = await transport.post('/wallet/updateenergylimit', {
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'origin_energy_limit': originEnergyLimit,
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }

  /// TRON-34: Clears the contract ABI.
  ///
  /// Returns the unsigned [TronTransaction] for signing and broadcasting.
  Future<TronTransaction> clearAbi({
    required TronAddress ownerAddress,
    required TronAddress contractAddress,
  }) async {
    final result = await transport.post('/wallet/clearabi', {
      'owner_address': ownerAddress.toBase58(),
      'contract_address': contractAddress.toBase58(),
      'visible': true,
    });
    checkTronError(result);
    return TronTransaction.fromJson(result);
  }
}
