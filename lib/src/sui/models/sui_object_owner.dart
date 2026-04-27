/// Sui object ownership model with polymorphic deserialization.
///
/// Sui objects can have 5 ownership types: Immutable, AddressOwner,
/// ObjectOwner, Shared, and ConsensusV2. The [SuiObjectOwner.fromJson]
/// factory handles all variants and falls back to [SuiObjectOwnerUnknown]
/// for unrecognized types (T-07-04 mitigation).
///
/// ```dart
/// final owner = SuiObjectOwner.fromJson({'AddressOwner': '0x123...'});
/// if (owner is SuiObjectOwnerAddress) {
///   print(owner.address);
/// }
/// ```
library;

/// Base class for Sui object ownership types.
///
/// Use [fromJson] to deserialize from RPC JSON responses.
abstract class SuiObjectOwner {
  /// Creates a [SuiObjectOwner] base instance.
  const SuiObjectOwner();

  /// Deserializes a Sui object owner from JSON.
  ///
  /// Handles all 5 ownership variants:
  /// - `"Immutable"` string -> [SuiObjectOwnerImmutable]
  /// - `{"AddressOwner": "0x..."}` -> [SuiObjectOwnerAddress]
  /// - `{"ObjectOwner": "0x..."}` -> [SuiObjectOwnerObject]
  /// - `{"Shared": {"initial_shared_version": N}}` -> [SuiObjectOwnerShared]
  /// - `{"ConsensusV2": {...}}` -> [SuiObjectOwnerConsensusV2]
  ///
  /// Returns [SuiObjectOwnerUnknown] for null or unrecognized input.
  factory SuiObjectOwner.fromJson(dynamic json) {
    if (json == null) return const SuiObjectOwnerUnknown(null);

    if (json is String) {
      if (json == 'Immutable') return const SuiObjectOwnerImmutable();
      return SuiObjectOwnerUnknown(json);
    }

    if (json is Map<String, dynamic>) {
      if (json.containsKey('AddressOwner')) {
        return SuiObjectOwnerAddress(json['AddressOwner'] as String);
      }
      if (json.containsKey('ObjectOwner')) {
        return SuiObjectOwnerObject(json['ObjectOwner'] as String);
      }
      if (json.containsKey('Shared')) {
        final shared = json['Shared'] as Map<String, dynamic>;
        return SuiObjectOwnerShared(
          BigInt.from(shared['initial_shared_version'] as num),
        );
      }
      if (json.containsKey('ConsensusV2')) {
        final cv2 = json['ConsensusV2'] as Map<String, dynamic>;
        return SuiObjectOwnerConsensusV2(
          startVersion: BigInt.from(cv2['start_version'] as num),
          authenticator: cv2['authenticator'] as Map<String, dynamic>,
        );
      }
    }

    return SuiObjectOwnerUnknown(json);
  }
}

/// An immutable (frozen) object that can never be mutated or transferred.
class SuiObjectOwnerImmutable extends SuiObjectOwner {
  /// Creates an immutable object owner instance.
  const SuiObjectOwnerImmutable();

  @override
  String toString() => 'SuiObjectOwnerImmutable';
}

/// An object owned by a specific address.
class SuiObjectOwnerAddress extends SuiObjectOwner {
  /// The Sui address that owns this object.
  final String address;

  /// Creates an address-owned object owner with the given [address].
  const SuiObjectOwnerAddress(this.address);

  @override
  String toString() => 'SuiObjectOwnerAddress($address)';
}

/// An object owned by another object.
class SuiObjectOwnerObject extends SuiObjectOwner {
  /// The object ID of the parent object.
  final String objectId;

  /// Creates an object-owned owner with the given parent [objectId].
  const SuiObjectOwnerObject(this.objectId);

  @override
  String toString() => 'SuiObjectOwnerObject($objectId)';
}

/// A shared object that can be used by any transaction.
class SuiObjectOwnerShared extends SuiObjectOwner {
  /// The version at which this object was first shared.
  final BigInt initialSharedVersion;

  /// Creates a shared object owner with the given [initialSharedVersion].
  const SuiObjectOwnerShared(this.initialSharedVersion);

  @override
  String toString() =>
      'SuiObjectOwnerShared(initialSharedVersion: $initialSharedVersion)';
}

/// A ConsensusV2 owned object (Sui protocol v2 consensus ownership).
class SuiObjectOwnerConsensusV2 extends SuiObjectOwner {
  /// The version at which consensus ownership started.
  final BigInt startVersion;

  /// The authenticator configuration.
  final Map<String, dynamic> authenticator;

  /// Creates a ConsensusV2 object owner with the given parameters.
  const SuiObjectOwnerConsensusV2({
    required this.startVersion,
    required this.authenticator,
  });

  @override
  String toString() => 'SuiObjectOwnerConsensusV2(startVersion: $startVersion)';
}

/// Fallback for unrecognized ownership types.
///
/// Ensures forward compatibility — new Sui protocol versions may
/// introduce new owner types that should not crash the SDK.
class SuiObjectOwnerUnknown extends SuiObjectOwner {
  /// The raw JSON value that could not be parsed.
  final dynamic raw;

  /// Creates an unknown object owner wrapping the [raw] JSON value.
  const SuiObjectOwnerUnknown(this.raw);

  @override
  String toString() => 'SuiObjectOwnerUnknown($raw)';
}
