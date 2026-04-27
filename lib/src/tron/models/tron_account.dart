/// Tron account response model returned by `getaccount` API.
///
/// Contains account balance, TRC-10 assets, frozen resources, and permissions.
/// All balance/amount fields use [BigInt] to handle large sun values safely.
///
/// ```dart
/// final account = TronAccount.fromJson(responseJson);
/// print(account.balance); // TRX balance in sun
/// ```
class TronAccount {
  /// Account address in base58 format (when `visible: true`).
  final String? address;

  /// TRX balance in sun.
  final BigInt balance;

  /// Account creation timestamp (milliseconds since epoch).
  final int? createTime;

  /// TRC-10 asset balances (asset ID -> amount).
  final List<TronAssetAmount> assetV2;

  /// Frozen v2 resources (bandwidth/energy).
  final List<TronFrozenV2>? frozenV2;

  /// Pending unfreeze v2 entries.
  final List<TronUnfreezeV2>? unfreezeV2;

  /// Delegated frozen v2 balance for bandwidth.
  final BigInt? delegatedFrozenV2BalanceForBandwidth;

  /// Acquired delegated frozen v2 balance for bandwidth.
  final BigInt? acquiredDelegatedFrozenV2BalanceForBandwidth;

  /// Account resource details (energy/bandwidth delegation info).
  final Map<String, dynamic>? accountResource;

  /// Owner permission configuration.
  final Map<String, dynamic>? ownerPermission;

  /// Active permissions list.
  final List<Map<String, dynamic>>? activePermission;

  /// Net window size.
  final int? netWindowSize;

  /// Whether net window is optimized.
  final bool? netWindowOptimized;

  /// Creates a [TronAccount] with all fields.
  const TronAccount({
    required this.address,
    required this.balance,
    this.createTime,
    this.assetV2 = const [],
    this.frozenV2,
    this.unfreezeV2,
    this.delegatedFrozenV2BalanceForBandwidth,
    this.acquiredDelegatedFrozenV2BalanceForBandwidth,
    this.accountResource,
    this.ownerPermission,
    this.activePermission,
    this.netWindowSize,
    this.netWindowOptimized,
  });

  /// Parses a [TronAccount] from a Tron HTTP API response map.
  ///
  /// Handles missing fields gracefully with safe defaults. BigInt fields
  /// use `BigInt.from(value ?? 0)` pattern for null safety.
  factory TronAccount.fromJson(Map<String, dynamic> json) {
    return TronAccount(
      address: json['address'] as String?,
      balance: BigInt.from(json['balance'] ?? 0),
      createTime: json['create_time'] as int?,
      assetV2: _parseAssetV2(json['assetV2']),
      frozenV2: _parseFrozenV2(json['frozenV2']),
      unfreezeV2: _parseUnfreezeV2(json['unfreezeV2']),
      delegatedFrozenV2BalanceForBandwidth: _bigIntOrNull(
        json['delegated_frozenV2_balance_for_bandwidth'],
      ),
      acquiredDelegatedFrozenV2BalanceForBandwidth: _bigIntOrNull(
        json['acquired_delegated_frozenV2_balance_for_bandwidth'],
      ),
      accountResource: json['account_resource'] as Map<String, dynamic>?,
      ownerPermission: json['owner_permission'] as Map<String, dynamic>?,
      activePermission: _parseMapList(json['active_permission']),
      netWindowSize: json['net_window_size'] as int?,
      netWindowOptimized: json['net_window_optimized'] as bool?,
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }

  static List<TronAssetAmount> _parseAssetV2(dynamic value) {
    if (value == null) return const [];
    return (value as List)
        .map((e) => TronAssetAmount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<TronFrozenV2>? _parseFrozenV2(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => TronFrozenV2.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<TronUnfreezeV2>? _parseUnfreezeV2(dynamic value) {
    if (value == null) return null;
    return (value as List)
        .map((e) => TronUnfreezeV2.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    return (value as List).cast<Map<String, dynamic>>();
  }
}

/// A TRC-10 asset balance entry.
class TronAssetAmount {
  /// Asset ID (string key).
  final String key;

  /// Asset balance amount.
  final BigInt value;

  /// Creates a [TronAssetAmount].
  const TronAssetAmount({required this.key, required this.value});

  /// Parses from JSON `{"key": "1000001", "value": 100}`.
  factory TronAssetAmount.fromJson(Map<String, dynamic> json) {
    return TronAssetAmount(
      key: json['key'] as String,
      value: BigInt.from(json['value'] ?? 0),
    );
  }
}

/// A frozen v2 resource entry.
class TronFrozenV2 {
  /// Resource type: `BANDWIDTH`, `ENERGY`, or `TRON_POWER`.
  final String? type;

  /// Frozen amount in sun.
  final BigInt? amount;

  /// Creates a [TronFrozenV2].
  const TronFrozenV2({this.type, this.amount});

  /// Parses from JSON `{"type": "ENERGY", "amount": 1000000}`.
  factory TronFrozenV2.fromJson(Map<String, dynamic> json) {
    return TronFrozenV2(
      type: json['type'] as String?,
      amount: _bigIntOrNull(json['amount']),
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}

/// A pending unfreeze v2 entry.
class TronUnfreezeV2 {
  /// Resource type being unfrozen.
  final String? type;

  /// Amount being unfrozen in sun.
  final BigInt? unfreezeAmount;

  /// Timestamp when unfreeze expires (milliseconds since epoch).
  final int? unfreezeExpireTime;

  /// Creates a [TronUnfreezeV2].
  const TronUnfreezeV2({
    this.type,
    this.unfreezeAmount,
    this.unfreezeExpireTime,
  });

  /// Parses from JSON.
  factory TronUnfreezeV2.fromJson(Map<String, dynamic> json) {
    return TronUnfreezeV2(
      type: json['type'] as String?,
      unfreezeAmount: _bigIntOrNull(json['unfreeze_amount']),
      unfreezeExpireTime: json['unfreeze_expire_time'] as int?,
    );
  }

  static BigInt? _bigIntOrNull(dynamic value) {
    if (value == null) return null;
    return BigInt.from(value as num);
  }
}
