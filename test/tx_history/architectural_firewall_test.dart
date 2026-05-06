/// Architectural firewall (LD-2 / T-11-31).
///
/// Phase 11 ships the tx_history extension layer **alongside** the
/// existing v1.0 surface, never inside it. The `lib/ceres_wallet_onchain.dart`
/// main barrel must remain byte-identical to v0.1.1 (no `tx_history`
/// references), and no v1.0 source file (under `lib/src/{core,abi,evm,
/// solana,sui,tron,utils}/`) may import anything from the tx_history
/// extension. This pure-Dart test wraps the canonical `grep` checks so
/// the invariant holds on every CI run regardless of platform.
///
/// Failure here means a future contributor pulled the extension layer
/// into the core — see PITFALLS.md B-03 (no reverse imports) and threat
/// register entry T-11-31 (mitigation: this test).
library;

import 'dart:io';

import 'package:test/test.dart';

/// Returns the absolute path to the project root (where `pubspec.yaml`
/// lives). Walks up from the current working directory until found.
String _projectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Cannot locate project root from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// Walks [dir] recursively yielding every regular file ending in `.dart`.
Iterable<File> _dartFilesUnder(Directory dir) sync* {
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

void main() {
  final root = _projectRoot();

  group('LD-2 main barrel firewall', () {
    test(
      'lib/ceres_wallet_onchain.dart contains no "tx_history" reference',
      () {
        final barrel = File('$root/lib/ceres_wallet_onchain.dart');
        expect(
          barrel.existsSync(),
          isTrue,
          reason: 'main barrel missing at lib/ceres_wallet_onchain.dart',
        );
        final source = barrel.readAsStringSync();
        expect(
          source.contains('tx_history'),
          isFalse,
          reason:
              'lib/ceres_wallet_onchain.dart must NOT mention "tx_history" '
              '(LD-2 — extension is opt-in via lib/tx_history.dart only). '
              'A future contributor probably re-exported the extension; '
              'revert it.',
        );
      },
    );
  });

  group('B-03 reverse-import firewall', () {
    /// v1.0 source directories that must NEVER import the tx_history layer.
    /// (`lib/src/tx_history/` and `lib/tx_history*.dart` are intentionally
    /// excluded — those ARE the extension.)
    const v1Dirs = [
      'lib/src/core',
      'lib/src/abi',
      'lib/src/evm',
      'lib/src/solana',
      'lib/src/sui',
      'lib/src/tron',
      'lib/src/utils',
    ];

    test('no v1.0 source file imports tx_history', () {
      final offenders = <String>[];
      for (final relDir in v1Dirs) {
        final dir = Directory('$root/$relDir');
        if (!dir.existsSync()) continue;
        for (final file in _dartFilesUnder(dir)) {
          final source = file.readAsStringSync();
          // Detect ANY tx_history reference: import 'src/tx_history/...',
          // import 'package:ceres_wallet_onchain/tx_history.dart',
          // export of either, or a stray symbol mention. Substring match
          // is acceptable here — the extension namespace is unique to the
          // package.
          if (source.contains('tx_history') ||
              source.contains('TxHistoryProvider') ||
              source.contains('TxHistoryPage') ||
              source.contains('TxHistoryCursor') ||
              source.contains('TxHistoryQuery') ||
              source.contains('TxHistoryException')) {
            offenders.add(file.path.replaceFirst('$root/', ''));
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'v1.0 source files must NOT import or reference the tx_history '
            'extension layer (B-03, T-11-31). Offending files:\n'
            '${offenders.map((f) => '  - $f').join('\n')}',
      );
    });
  });

  group('LD-2 main barrel surface stability', () {
    test('main barrel still re-exports the v1.0 chain client classes', () {
      // Spot-check that the barrel was not gutted while removing
      // tx_history references — the four v1.0 RPC clients must remain
      // reachable through the unchanged main barrel surface.
      final source = File(
        '$root/lib/ceres_wallet_onchain.dart',
      ).readAsStringSync();
      const requiredExports = [
        'evm_rpc_client.dart',
        'tron_http_client.dart',
        'solana_rpc_client.dart',
        'sui_rpc_client.dart',
      ];
      final missing = requiredExports
          .where((e) => !source.contains(e))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'main barrel lost a v1.0 export — phase 11 must NOT touch '
            'lib/ceres_wallet_onchain.dart. Missing: $missing',
      );
    });
  });
}
