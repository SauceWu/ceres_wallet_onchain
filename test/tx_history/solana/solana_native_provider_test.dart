/// Behavioural tests for [SolanaNativeProvider] — Solana history reader
/// composing the v1.0 [SolanaRpcClient].
///
/// Verifies HIST-SOL-01..03:
///   - Two-step composite (getSignaturesForAddress → batched getTransaction)
///   - Concurrency cap (default 4) verified via in-flight counter probe
///   - Default encoding `base64`, default commitment `finalized`,
///     `maxSupportedTransactionVersion: 0` always set
///   - Cursor variant guard (wrong-chain cursor → InvalidCursorException)
///   - 429 halts the batch (no retry storm) → TxHistoryApiException
///   - Ownership flag: `close()` only disposes resources the provider owns
library;

import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _addr = 'GjwcWFQYzemBtpUoN5fMAP2FZviTtMRWCmrppGuTthJS';

/// Stable sample base64-encoded transaction payload returned by
/// `getTransaction` when `encoding=base64`. The Solana RPC wraps it in a
/// `[base64Bytes, "base64"]` tuple under the `transaction` field.
Map<String, dynamic> _fakeBase64Tx(String signature) => <String, dynamic>{
  'slot': 123456789,
  'blockTime': 1700000000,
  'transaction': <dynamic>['AQABAg==', 'base64'],
  'meta': <String, dynamic>{
    'err': null,
    'fee': 5000,
    'logMessages': <String>[],
  },
  'version': 0,
};

/// Sample jsonParsed transaction shape returned when `useJsonParsed=true`.
Map<String, dynamic> _fakeJsonParsedTx(String signature) => <String, dynamic>{
  'slot': 123456789,
  'blockTime': 1700000000,
  'transaction': <String, dynamic>{
    'signatures': <String>[signature],
    'message': <String, dynamic>{
      'accountKeys': <dynamic>[],
      'instructions': <dynamic>[],
    },
  },
  'meta': <String, dynamic>{'err': null, 'fee': 5000},
  'version': 'legacy',
};

Map<String, dynamic> _sigInfoJson(String sig, {int slot = 100}) =>
    <String, dynamic>{
      'signature': sig,
      'slot': slot,
      'err': null,
      'memo': null,
      'blockTime': 1700000000,
      'confirmationStatus': 'finalized',
    };

http.Response _rpcOk(int id, dynamic result) => http.Response(
  jsonEncode(<String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': result}),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);

http.Response _rpc429() => http.Response(
  jsonEncode(<String, String>{'error': 'rate limit'}),
  429,
  headers: <String, String>{'content-type': 'application/json'},
);

void main() {
  group('SolanaNativeProvider — listTransactions', () {
    test('empty signatures → empty page, nextCursor is null', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'getSignaturesForAddress');
        return _rpcOk(body['id'] as int, <dynamic>[]);
      });

      final provider = _build(mock);
      final page = await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: 5),
      );

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      provider.close();
    });

    test('3 signatures → 1 sig call + 3 getTransaction calls; '
        'nextCursor = SolanaCursor(last signature)', () async {
      final calls = <String>[]; // method names
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(body['method'] as String);
        if (body['method'] == 'getSignaturesForAddress') {
          return _rpcOk(body['id'] as int, <dynamic>[
            _sigInfoJson('SIG_A'),
            _sigInfoJson('SIG_B'),
            _sigInfoJson('SIG_C'),
          ]);
        }
        // getTransaction
        final params = body['params'] as List;
        final sig = params[0] as String;
        return _rpcOk(body['id'] as int, _fakeBase64Tx(sig));
      });

      final provider = _build(mock);
      final page = await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: 3),
      );

      expect(page.items.length, 3);
      expect(page.items[0].signatureInfo.signature, 'SIG_A');
      expect(page.items[1].signatureInfo.signature, 'SIG_B');
      expect(page.items[2].signatureInfo.signature, 'SIG_C');

      expect(page.nextCursor, isA<SolanaCursor>());
      expect((page.nextCursor as SolanaCursor).beforeSignature, 'SIG_C');

      // 1 getSignatures + 3 getTransaction
      expect(calls.where((m) => m == 'getSignaturesForAddress').length, 1);
      expect(calls.where((m) => m == 'getTransaction').length, 3);
      provider.close();
    });

    test('cursor: SolanaCursor("AAA") forwards before:"AAA" to RPC', () async {
      String? observedBefore;
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          final params = body['params'] as List;
          // params = [address, {limit, before, commitment, ...}]
          if (params.length > 1) {
            observedBefore =
                (params[1] as Map<String, dynamic>)['before'] as String?;
          }
          return _rpcOk(body['id'] as int, <dynamic>[]);
        }
        return _rpcOk(body['id'] as int, null);
      });

      final provider = _build(mock);
      await provider.listTransactions(
        TxHistoryQuery(address: _addr, limit: 5, cursor: SolanaCursor('AAA')),
      );

      expect(observedBefore, 'AAA');
      provider.close();
    });

    test(
      'wrong-chain cursor (EtherscanCursor) → InvalidCursorException',
      () async {
        final mock = MockClient((request) async => _rpcOk(1, <dynamic>[]));
        final provider = _build(mock);

        expect(
          () => provider.listTransactions(
            TxHistoryQuery(
              address: _addr,
              cursor: EtherscanCursor(page: 1, offset: 25),
            ),
          ),
          throwsA(
            isA<InvalidCursorException>()
                .having((e) => e.code, 'code', -2001)
                .having(
                  (e) => e.message,
                  'message',
                  contains('expected SolanaCursor'),
                ),
          ),
        );
        provider.close();
      },
    );
  });

  group('SolanaNativeProvider — encoding & commitment defaults', () {
    test('default getTransaction config: encoding=base64, '
        'maxSupportedTransactionVersion=0, commitment=finalized', () async {
      Map<String, dynamic>? observedTxConfig;
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          return _rpcOk(body['id'] as int, <dynamic>[_sigInfoJson('SIG_X')]);
        }
        // getTransaction
        final params = body['params'] as List;
        observedTxConfig = params[1] as Map<String, dynamic>;
        return _rpcOk(body['id'] as int, _fakeBase64Tx('SIG_X'));
      });

      final provider = _build(mock);
      await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: 1),
      );

      expect(observedTxConfig, isNotNull);
      expect(observedTxConfig!['encoding'], 'base64');
      expect(observedTxConfig!['maxSupportedTransactionVersion'], 0);
      expect(observedTxConfig!['commitment'], 'finalized');
      provider.close();
    });

    test('useJsonParsed=true → encoding=jsonParsed (still maxVer=0)', () async {
      Map<String, dynamic>? observedTxConfig;
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          return _rpcOk(body['id'] as int, <dynamic>[_sigInfoJson('SIG_Y')]);
        }
        final params = body['params'] as List;
        observedTxConfig = params[1] as Map<String, dynamic>;
        return _rpcOk(body['id'] as int, _fakeJsonParsedTx('SIG_Y'));
      });

      final provider = _build(mock, useJsonParsed: true);
      await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: 1),
      );

      expect(observedTxConfig!['encoding'], 'jsonParsed');
      expect(observedTxConfig!['maxSupportedTransactionVersion'], 0);
      expect(observedTxConfig!['commitment'], 'finalized');
      provider.close();
    });

    test(
      'getSignaturesForAddress request also includes commitment=finalized',
      () async {
        Map<String, dynamic>? observedSigConfig;
        final mock = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['method'] == 'getSignaturesForAddress') {
            final params = body['params'] as List;
            observedSigConfig = params.length > 1
                ? params[1] as Map<String, dynamic>
                : <String, dynamic>{};
            return _rpcOk(body['id'] as int, <dynamic>[]);
          }
          return _rpcOk(body['id'] as int, null);
        });

        final provider = _build(mock);
        await provider.listTransactions(
          const TxHistoryQuery(address: _addr, limit: 5),
        );

        expect(observedSigConfig, isNotNull);
        expect(observedSigConfig!['commitment'], 'finalized');
        provider.close();
      },
    );
  });

  group('SolanaNativeProvider — concurrency cap', () {
    test('default concurrency=4: peak in-flight getTransaction <= 4', () async {
      var inFlight = 0;
      var peak = 0;
      const total = 12;

      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          return _rpcOk(body['id'] as int, <dynamic>[
            for (var i = 0; i < total; i++) _sigInfoJson('SIG_$i'),
          ]);
        }
        // getTransaction — track in-flight count
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        // Yield so other in-flight requests can be observed.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        final params = body['params'] as List;
        return _rpcOk(body['id'] as int, _fakeBase64Tx(params[0] as String));
      });

      final provider = _build(mock);
      final page = await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: total),
      );

      expect(page.items.length, total);
      expect(peak, lessThanOrEqualTo(4));
      // Sanity: peak should actually reach 4 with 12 tasks.
      expect(peak, 4);
      provider.close();
    });

    test('concurrency=2: peak in-flight getTransaction == 2', () async {
      var inFlight = 0;
      var peak = 0;
      const total = 8;

      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          return _rpcOk(body['id'] as int, <dynamic>[
            for (var i = 0; i < total; i++) _sigInfoJson('SIG_$i'),
          ]);
        }
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        final params = body['params'] as List;
        return _rpcOk(body['id'] as int, _fakeBase64Tx(params[0] as String));
      });

      final provider = _build(mock, concurrency: 2);
      await provider.listTransactions(
        const TxHistoryQuery(address: _addr, limit: total),
      );

      expect(peak, 2);
      provider.close();
    });
  });

  group('SolanaNativeProvider — 429 halt-on-rate-limit', () {
    test('429 from getTransaction → TxHistoryApiException(-2002); '
        'no further getTransaction calls issued', () async {
      var sigCalls = 0;
      var txCalls = 0;
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'getSignaturesForAddress') {
          sigCalls++;
          return _rpcOk(body['id'] as int, <dynamic>[
            _sigInfoJson('SIG_1'),
            _sigInfoJson('SIG_2'),
            _sigInfoJson('SIG_3'),
            _sigInfoJson('SIG_4'),
          ]);
        }
        // getTransaction
        txCalls++;
        if (txCalls == 3) return _rpc429();
        final params = body['params'] as List;
        return _rpcOk(body['id'] as int, _fakeBase64Tx(params[0] as String));
      });

      // concurrency:1 keeps the order deterministic so the halt window
      // is observable at "third call throws → fourth never fires".
      final provider = _build(mock, concurrency: 1);

      await expectLater(
        provider.listTransactions(
          const TxHistoryQuery(address: _addr, limit: 4),
        ),
        throwsA(
          isA<TxHistoryApiException>()
              .having((e) => e.code, 'code', -2002)
              .having(
                (e) => e.message,
                'message',
                anyOf(
                  contains('rate limit'),
                  contains('429'),
                  contains('halted'),
                ),
              ),
        ),
      );

      expect(sigCalls, 1);
      expect(
        txCalls,
        3,
        reason: 'fourth getTransaction must not be issued after 429',
      );
      provider.close();
    });
  });

  group('SolanaHistoryTransaction', () {
    test(
      'holds raw transaction map as returned by getTransaction (base64)',
      () async {
        final mock = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['method'] == 'getSignaturesForAddress') {
            return _rpcOk(body['id'] as int, <dynamic>[_sigInfoJson('SIG_R')]);
          }
          return _rpcOk(body['id'] as int, _fakeBase64Tx('SIG_R'));
        });

        final provider = _build(mock);
        final page = await provider.listTransactions(
          const TxHistoryQuery(address: _addr, limit: 1),
        );

        final item = page.items.single;
        expect(item.signatureInfo.signature, 'SIG_R');
        expect(item.transaction, isNotNull);
        // base64 form: transaction.transaction is [bytesB64, 'base64'].
        expect(item.transaction!['transaction'], isA<List<dynamic>>());
        final tup = item.transaction!['transaction'] as List<dynamic>;
        expect(tup.last, 'base64');
        provider.close();
      },
    );

    test(
      'transaction is null when getTransaction returns null (pruned)',
      () async {
        final mock = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['method'] == 'getSignaturesForAddress') {
            return _rpcOk(body['id'] as int, <dynamic>[_sigInfoJson('SIG_N')]);
          }
          // RPC returns null for not-found / pruned signatures.
          return _rpcOk(body['id'] as int, null);
        });

        final provider = _build(mock);
        final page = await provider.listTransactions(
          const TxHistoryQuery(address: _addr, limit: 1),
        );

        final item = page.items.single;
        expect(item.signatureInfo.signature, 'SIG_N');
        expect(item.transaction, isNull);
        provider.close();
      },
    );
  });

  group('SolanaNativeProvider.fromUrl — HTTPS-only SSRF guard (T-11-15)', () {
    test('http:// baseUrl throws ArgumentError by default', () {
      expect(
        () => SolanaNativeProvider.fromUrl('http://attacker.example.com'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('https://'), contains('allowInsecure')),
          ),
        ),
      );
    });

    test('https:// baseUrl is accepted (no throw, must close)', () {
      final provider = SolanaNativeProvider.fromUrl(
        'https://api.mainnet-beta.solana.com',
      );
      expect(provider.close, returnsNormally);
    });

    test('http:// baseUrl with allowInsecure: true is accepted', () {
      final provider = SolanaNativeProvider.fromUrl(
        'http://127.0.0.1:8899',
        allowInsecure: true,
      );
      expect(provider.close, returnsNormally);
    });
  });

  group('SolanaNativeProvider — close() ownership flag (HIST-OPS-03)', () {
    test(
      'close() — fromUrl: provider closes its own resources (smoke test)',
      () {
        final provider = SolanaNativeProvider.fromUrl(
          'http://127.0.0.1:65000',
          allowInsecure: true,
        );
        // Idempotency: must not throw.
        expect(provider.close, returnsNormally);
      },
    );

    test(
      'close() — injection: does NOT close the injected SolanaRpcClient',
      () async {
        var sigCalls = 0;
        final mock = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['method'] == 'getSignaturesForAddress') {
            sigCalls++;
            return _rpcOk(body['id'] as int, <dynamic>[]);
          }
          return _rpcOk(body['id'] as int, null);
        });

        final transport = JsonRpcTransport(
          config: const RpcClientConfig(baseUrl: 'http://localhost:8899'),
          httpClient: mock,
        );
        final rpc = SolanaRpcClient(transport: transport);
        final provider = SolanaNativeProvider(rpcClient: rpc);

        // Take down the provider — must NOT close the injected rpc.
        provider.close();

        // The injected rpc is still usable.
        await rpc.getSignaturesForAddress(_addr, limit: 1);
        expect(sigCalls, 1, reason: 'injected rpc must remain alive');
      },
    );
  });
}

/// Builds a [SolanaNativeProvider] backed by [mock] for tests. Wires
/// the [MockClient] all the way through the v1.0 transport stack.
SolanaNativeProvider _build(
  MockClient mock, {
  bool useJsonParsed = false,
  int concurrency = 4,
}) {
  final transport = JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'http://localhost:8899'),
    httpClient: mock,
  );
  final rpc = SolanaRpcClient(transport: transport);
  return SolanaNativeProvider(
    rpcClient: rpc,
    useJsonParsed: useJsonParsed,
    concurrency: concurrency,
  );
}
