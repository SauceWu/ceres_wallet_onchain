/// Sui transaction effects model.
///
/// Contains the execution result of a Sui transaction, including
/// status, gas costs, and object mutations.
///
/// ```dart
/// final effects = SuiTransactionEffects.fromJson(json['effects']);
/// if (effects.status.isSuccess) {
///   print('Gas used: ${effects.gasUsed.totalCost}');
/// }
/// ```
library;

import 'sui_gas_cost_summary.dart';
import 'sui_object_owner.dart';

/// The execution status of a Sui transaction.
class SuiExecutionStatus {
  /// Whether the transaction executed successfully.
  final bool isSuccess;

  /// The error message if execution failed, null on success.
  final String? error;

  /// Creates a [SuiExecutionStatus].
  const SuiExecutionStatus({required this.isSuccess, this.error});

  /// Parses a [SuiExecutionStatus] from a JSON map.
  factory SuiExecutionStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    return SuiExecutionStatus(
      isSuccess: status == 'success',
      error: json['error'] as String?,
    );
  }
}

/// The full effects of executing a Sui transaction.
class SuiTransactionEffects {
  /// The execution status (success or failure).
  final SuiExecutionStatus status;

  /// The gas cost breakdown.
  final GasCostSummary gasUsed;

  /// The digest of the transaction that produced these effects.
  final String transactionDigest;

  /// The epoch during which the transaction was executed.
  final String? executedEpoch;

  /// The message version of the effects structure.
  final String? messageVersion;

  /// Objects that were mutated by this transaction.
  final List<dynamic>? mutated;

  /// Objects that were created by this transaction.
  final List<dynamic>? created;

  /// Objects that were deleted by this transaction.
  final List<dynamic>? deleted;

  /// Objects that were wrapped by this transaction.
  final List<dynamic>? wrapped;

  /// Objects that were unwrapped by this transaction.
  final List<dynamic>? unwrapped;

  /// The gas object used for payment.
  final Map<String, dynamic>? gasObject;

  /// Dependencies of this transaction.
  final List<String>? dependencies;

  /// Creates a [SuiTransactionEffects] with the given fields.
  const SuiTransactionEffects({
    required this.status,
    required this.gasUsed,
    required this.transactionDigest,
    this.executedEpoch,
    this.messageVersion,
    this.mutated,
    this.created,
    this.deleted,
    this.wrapped,
    this.unwrapped,
    this.gasObject,
    this.dependencies,
  });

  /// Parses a [SuiTransactionEffects] from a JSON map returned by Sui RPC.
  factory SuiTransactionEffects.fromJson(Map<String, dynamic> json) {
    return SuiTransactionEffects(
      status: SuiExecutionStatus.fromJson(
        json['status'] as Map<String, dynamic>,
      ),
      gasUsed: GasCostSummary.fromJson(json['gasUsed'] as Map<String, dynamic>),
      transactionDigest: json['transactionDigest'] as String,
      executedEpoch: json['executedEpoch'] as String?,
      messageVersion: json['messageVersion'] as String?,
      mutated: json['mutated'] as List<dynamic>?,
      created: json['created'] as List<dynamic>?,
      deleted: json['deleted'] as List<dynamic>?,
      wrapped: json['wrapped'] as List<dynamic>?,
      unwrapped: json['unwrapped'] as List<dynamic>?,
      gasObject: json['gasObject'] as Map<String, dynamic>?,
      dependencies: (json['dependencies'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// A balance change resulting from a transaction.
///
/// The [amount] field uses [BigInt] and can be negative (for gas payments
/// or token sends). This is critical for correct display (T-07-05).
class SuiBalanceChange {
  /// The owner whose balance changed.
  final SuiObjectOwner owner;

  /// The coin type (e.g., `0x2::sui::SUI`).
  final String coinType;

  /// The amount of change in the smallest unit. Can be negative.
  final BigInt amount;

  /// Creates a [SuiBalanceChange].
  const SuiBalanceChange({
    required this.owner,
    required this.coinType,
    required this.amount,
  });

  /// Parses a [SuiBalanceChange] from a JSON map returned by Sui RPC.
  factory SuiBalanceChange.fromJson(Map<String, dynamic> json) {
    return SuiBalanceChange(
      owner: SuiObjectOwner.fromJson(json['owner']),
      coinType: json['coinType'] as String,
      amount: BigInt.parse(json['amount'].toString()),
    );
  }
}
