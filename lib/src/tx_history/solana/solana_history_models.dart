/// Composite history item returned by [SolanaNativeProvider].
///
/// Pairs a [SignatureInfo] entry from `getSignaturesForAddress` with the
/// raw `getTransaction` response so callers have everything they need to
/// reconstruct one Solana history row in a single object.
library;

import '../../solana/models/signature_info.dart';

/// One Solana history item: signature info plus the raw transaction
/// payload returned by `getTransaction`.
///
/// `transaction` is intentionally typed as the raw `Map<String, dynamic>`
/// because the v1.0 [SolanaTransactionResponse] model is hard-coded for
/// the `jsonParsed` shape. Plan 11-03 defaults `getTransaction` to
/// `encoding=base64` (PITFALLS.md C-03 — raw fidelity for arbitrary
/// program payloads), where the `transaction` field becomes a
/// `[base64Bytes, "base64"]` tuple instead of a parsed object. Storing
/// the raw map sidesteps the schema mismatch and lets callers self-parse
/// against their own program registry (LD-3 — RAW chain data, no
/// cross-chain unification).
///
/// `transaction` is `null` when `getTransaction` returned `null` — i.e.
/// the signature is genuinely unknown to the cluster, or it was pruned
/// past the node's slot retention horizon. Callers can distinguish the
/// two by checking `signatureInfo.slot` against the node's first
/// available slot if needed.
class SolanaHistoryTransaction {
  /// Signature info from `getSignaturesForAddress` (always present).
  final SignatureInfo signatureInfo;

  /// Raw `getTransaction` response, or `null` when the cluster returned
  /// `null` for the signature.
  ///
  /// Shape depends on the encoding used by [SolanaNativeProvider]:
  ///
  /// - `encoding=base64` (default): `transaction` is
  ///   `[base64Bytes, "base64"]`; `meta` is a structured map; `version`
  ///   is `0` or `"legacy"`.
  /// - `encoding=jsonParsed` (when `useJsonParsed=true`): `transaction`
  ///   is a parsed object with `signatures` and `message` sub-objects.
  final Map<String, dynamic>? transaction;

  /// Creates a [SolanaHistoryTransaction].
  const SolanaHistoryTransaction({
    required this.signatureInfo,
    required this.transaction,
  });
}
