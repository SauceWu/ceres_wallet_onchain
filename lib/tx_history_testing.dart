/// Test infrastructure for the optional `tx_history` extension layer.
///
/// This barrel is the **opt-in test-only** entry point shipped per
/// LD-10 (research locked decision) and HIST-DOC-06 (requirement).
/// It lives at a SEPARATE import path so production builds that import
/// only `package:ceres_wallet_onchain/tx_history.dart` never pay the
/// tree-shaking cost of test scaffolding:
///
/// ```dart
/// import 'package:ceres_wallet_onchain/tx_history.dart';            // production
/// import 'package:ceres_wallet_onchain/tx_history_testing.dart';    // tests only
/// ```
///
/// What's exported:
///
/// - [MockTxHistoryProvider] — sequential-response mock for unit tests
///   in downstream wallet integrations.
library ceres_wallet_onchain.tx_history_testing;

export 'src/tx_history/testing/mock_tx_history_provider.dart';
