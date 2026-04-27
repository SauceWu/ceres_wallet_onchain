/// Sui event model.
///
/// Represents an event emitted during a Sui transaction execution.
/// Events are the primary mechanism for off-chain applications to
/// observe on-chain activity.
///
/// ```dart
/// final event = SuiEvent.fromJson(json);
/// print(event.type);        // Move event type
/// print(event.packageId);   // source package
/// ```
library;

/// A single event emitted by a Sui transaction.
class SuiEvent {
  /// The globally unique event ID.
  final Map<String, dynamic> id;

  /// The package ID of the Move module that emitted this event.
  final String packageId;

  /// The transaction module that emitted this event.
  final String transactionModule;

  /// The sender address of the transaction.
  final String sender;

  /// The fully qualified Move event type.
  final String type;

  /// The parsed JSON content of the event.
  final Map<String, dynamic>? parsedJson;

  /// The BCS-encoded event data.
  final String? bcs;

  /// The timestamp of the event in milliseconds (as string).
  final String? timestampMs;

  /// Creates a [SuiEvent] with the given field values.
  const SuiEvent({
    required this.id,
    required this.packageId,
    required this.transactionModule,
    required this.sender,
    required this.type,
    this.parsedJson,
    this.bcs,
    this.timestampMs,
  });

  /// Parses a [SuiEvent] from a JSON map returned by Sui RPC.
  factory SuiEvent.fromJson(Map<String, dynamic> json) {
    return SuiEvent(
      id: json['id'] as Map<String, dynamic>,
      packageId: json['packageId'] as String,
      transactionModule: json['transactionModule'] as String,
      sender: json['sender'] as String,
      type: json['type'] as String,
      parsedJson: json['parsedJson'] as Map<String, dynamic>?,
      bcs: json['bcs'] as String?,
      timestampMs: json['timestampMs'] as String?,
    );
  }
}
