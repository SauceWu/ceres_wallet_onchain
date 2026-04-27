/// A Solana vote account returned within `getVoteAccounts` results.
///
/// [activatedStake] uses [BigInt] to handle large lamport values safely.
///
/// ```dart
/// final account = VoteAccount.fromJson(jsonMap);
/// print('${account.votePubkey}: ${account.activatedStake} lamports staked');
/// ```
class VoteAccount {
  /// The vote account public key (base-58 encoded).
  final String votePubkey;

  /// The validator identity public key (base-58 encoded).
  final String nodePubkey;

  /// The stake delegated to this vote account in lamports.
  final BigInt activatedStake;

  /// Whether this account is staked for the current epoch.
  final bool epochVoteAccount;

  /// The validator commission percentage (0-100).
  final int commission;

  /// The most recent slot voted on by this account.
  final int lastVote;

  /// The current root slot for this vote account, or `null`.
  final int? rootSlot;

  /// History of earned credits as `[epoch, credits, previousCredits]` tuples.
  final List<List<int>>? epochCredits;

  /// Creates a [VoteAccount] with all fields.
  const VoteAccount({
    required this.votePubkey,
    required this.nodePubkey,
    required this.activatedStake,
    required this.epochVoteAccount,
    required this.commission,
    required this.lastVote,
    this.rootSlot,
    this.epochCredits,
  });

  /// Parses a [VoteAccount] from a Solana RPC JSON response map.
  factory VoteAccount.fromJson(Map<String, dynamic> json) {
    return VoteAccount(
      votePubkey: json['votePubkey'] as String,
      nodePubkey: json['nodePubkey'] as String,
      activatedStake: BigInt.from(json['activatedStake'] as num),
      epochVoteAccount: json['epochVoteAccount'] as bool,
      commission: json['commission'] as int,
      lastVote: json['lastVote'] as int,
      rootSlot: json['rootSlot'] as int?,
      epochCredits: _parseEpochCredits(json['epochCredits']),
    );
  }

  static List<List<int>>? _parseEpochCredits(dynamic value) {
    if (value == null) return null;
    return (value as List).map((e) => (e as List).cast<int>()).toList();
  }
}

/// Result of `getVoteAccounts` containing current and delinquent validators.
///
/// ```dart
/// final result = VoteAccountsResult.fromJson(jsonMap);
/// print('${result.current.length} active, ${result.delinquent.length} delinquent');
/// ```
class VoteAccountsResult {
  /// Vote accounts that are currently active.
  final List<VoteAccount> current;

  /// Vote accounts that are delinquent (not voting).
  final List<VoteAccount> delinquent;

  /// Creates a [VoteAccountsResult] with [current] and [delinquent] lists.
  const VoteAccountsResult({required this.current, required this.delinquent});

  /// Parses a [VoteAccountsResult] from a Solana RPC JSON response map.
  factory VoteAccountsResult.fromJson(Map<String, dynamic> json) {
    return VoteAccountsResult(
      current: (json['current'] as List)
          .map((e) => VoteAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      delinquent: (json['delinquent'] as List)
          .map((e) => VoteAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
