import 'dart:convert';

import 'package:ceres_wallet_onchain/src/core/json_rpc_transport.dart';
import 'package:ceres_wallet_onchain/src/core/rpc_client_config.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_options.dart';
import 'package:ceres_wallet_onchain/src/sui/models/sui_transaction_block_response.dart';
import 'package:ceres_wallet_onchain/src/sui/sui_rpc_client.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _suiAddr =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _otherAddr =
    '0x2222222222222222222222222222222222222222222222222222222222222222';

/// Mock JSON-RPC handler. Captures every request and returns the result
/// produced by [handler] for that request, wrapped in a JSON-RPC envelope.
JsonRpcTransport _mockTransport(
  List<Map<String, dynamic>> capturedRequests, {
  required dynamic Function(Map<String, dynamic> request) handler,
}) {
  final mockClient = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    capturedRequests.add(body);
    final result = handler(body);
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
  return JsonRpcTransport(
    config: const RpcClientConfig(baseUrl: 'https://fullnode.testnet.sui.io'),
    httpClient: mockClient,
  );
}

/// Builds a single-page response.
Map<String, dynamic> _pageResponse({
  List<Map<String, dynamic>> data = const [],
  String? nextCursor,
  bool hasNextPage = false,
}) => {
  'data': data,
  'hasNextPage': hasNextPage,
  if (nextCursor != null) 'nextCursor': nextCursor,
};

Map<String, dynamic> _suiTxJson(String digest) => {'digest': digest};

void main() {
  group('SuiNativeProvider — implements TxHistoryProvider contract', () {
    test('is assignable to TxHistoryProvider<SuiTransactionBlockResponse>', () {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);
      expect(provider, isA<TxHistoryProvider<SuiTransactionBlockResponse>>());
      provider.close();
      rpc.close();
    });
  });

  group('SuiNativeProvider — listFromAddress / listToAddress filter shape', () {
    test(
      'listFromAddress sends sui_queryTransactionBlocks with FromAddress filter',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(
            captured,
            handler: (_) => _pageResponse(
              data: [_suiTxJson('digest-1')],
              hasNextPage: false,
            ),
          ),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        final page = await provider.listFromAddress(_suiAddr);

        expect(captured, hasLength(1));
        expect(captured.single['method'], 'sui_queryTransactionBlocks');
        final params = captured.single['params'] as List;
        final query = params[0] as Map<String, dynamic>;
        expect(query['filter'], {'FromAddress': _suiAddr});
        expect(query.containsKey('ToAddress'), isFalse);
        expect(page.items, hasLength(1));
        expect(page.items.first.digest, 'digest-1');
        expect(page.nextCursor, isNull);
        expect(page.hasMore, isFalse);

        rpc.close();
      },
    );

    test(
      'listToAddress sends sui_queryTransactionBlocks with ToAddress filter',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(
            captured,
            handler: (_) => _pageResponse(
              data: [_suiTxJson('digest-recv-1')],
              hasNextPage: false,
            ),
          ),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        await provider.listToAddress(_suiAddr);

        final query =
            (captured.single['params'] as List)[0] as Map<String, dynamic>;
        expect(query['filter'], {'ToAddress': _suiAddr});

        rpc.close();
      },
    );

    test(
      'listTransactions delegates to listFromAddress (sender side)',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(captured, handler: (_) => _pageResponse()),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        await provider.listTransactions(
          const TxHistoryQuery(address: _suiAddr),
        );

        final query =
            (captured.single['params'] as List)[0] as Map<String, dynamic>;
        expect(query['filter'], {'FromAddress': _suiAddr});

        rpc.close();
      },
    );

    test('list() convenience also forwards to FromAddress', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.list(address: _otherAddr);

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['filter'], {'FromAddress': _otherAddr});

      rpc.close();
    });
  });

  group('SuiNativeProvider — default options forwarded to RPC', () {
    test(
      'defaults: showInput, showEffects, showEvents, showBalanceChanges all true',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(captured, handler: (_) => _pageResponse()),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        await provider.listFromAddress(_suiAddr);

        final query =
            (captured.single['params'] as List)[0] as Map<String, dynamic>;
        final options = query['options'] as Map<String, dynamic>;
        expect(options['showInput'], isTrue);
        expect(options['showEffects'], isTrue);
        expect(options['showEvents'], isTrue);
        expect(options['showBalanceChanges'], isTrue);

        rpc.close();
      },
    );

    test('custom options via constructor are forwarded verbatim', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(
        rpcClient: rpc,
        options: const SuiTransactionBlockResponseOptions(
          showRawInput: true,
          showEffects: false,
        ),
      );

      await provider.listFromAddress(_suiAddr);

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      final options = query['options'] as Map<String, dynamic>;
      expect(options['showRawInput'], isTrue);
      expect(options['showEffects'], isFalse);
      // Defaults must NOT leak through when caller supplies their own.
      expect(options.containsKey('showInput'), isFalse);
      expect(options.containsKey('showEvents'), isFalse);
      expect(options.containsKey('showBalanceChanges'), isFalse);

      rpc.close();
    });
  });

  group('SuiNativeProvider — order flag', () {
    test(
      'descendingOrder defaults to true (mobile UX wants newest-first)',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(captured, handler: (_) => _pageResponse()),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        await provider.listFromAddress(_suiAddr);

        final query =
            (captured.single['params'] as List)[0] as Map<String, dynamic>;
        expect(query['order'], 'descending');

        rpc.close();
      },
    );

    test('descendingOrder=false produces ascending order', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(
        rpcClient: rpc,
        descendingOrder: false,
      );

      await provider.listFromAddress(_suiAddr);

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['order'], 'ascending');

      rpc.close();
    });
  });

  group('SuiNativeProvider — opaque cursor pass-through (PITFALLS C-09)', () {
    test('cursor string is forwarded verbatim, never inspected', () async {
      const opaque = 'completely::opaque::cursor::value::not-parsed';
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.listFromAddress(_suiAddr, cursor: SuiCursor(opaque));

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['cursor'], opaque);

      rpc.close();
    });

    test('null cursor → request cursor field is null', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.listFromAddress(_suiAddr);

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['cursor'], isNull);

      rpc.close();
    });

    test(
      'wrong-chain cursor (TronGridCursor) → InvalidCursorException',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(captured, handler: (_) => _pageResponse()),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        await expectLater(
          () => provider.listFromAddress(
            _suiAddr,
            cursor: TronGridCursor('tron-fp-not-a-sui-cursor'),
          ),
          throwsA(
            isA<InvalidCursorException>()
                .having((e) => e.code, 'code', -2001)
                .having(
                  (e) => e.message,
                  'message',
                  contains('expected SuiCursor'),
                ),
          ),
        );
        // No RPC call should have been made.
        expect(captured, isEmpty);

        rpc.close();
      },
    );

    test('wrong-chain cursor on listToAddress also rejected', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await expectLater(
        () => provider.listToAddress(
          _suiAddr,
          cursor: SolanaCursor('sig-not-sui'),
        ),
        throwsA(isA<InvalidCursorException>()),
      );
      expect(captured, isEmpty);

      rpc.close();
    });
  });

  group('SuiNativeProvider — pagination', () {
    test(
      'hasNextPage=true + nextCursor → page.nextCursor is SuiCursor; hasMore=true',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(
            captured,
            handler: (_) => _pageResponse(
              data: [_suiTxJson('d1'), _suiTxJson('d2')],
              hasNextPage: true,
              nextCursor: 'opaque-X',
            ),
          ),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        final page = await provider.listFromAddress(_suiAddr);

        expect(page.items, hasLength(2));
        expect(page.hasMore, isTrue);
        expect(page.nextCursor, isA<SuiCursor>());
        expect((page.nextCursor as SuiCursor).cursor, 'opaque-X');

        rpc.close();
      },
    );

    test(
      'hasNextPage=false → page.nextCursor is null; hasMore=false',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(
            captured,
            handler: (_) =>
                _pageResponse(data: [_suiTxJson('d1')], hasNextPage: false),
          ),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        final page = await provider.listFromAddress(_suiAddr);

        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);

        rpc.close();
      },
    );

    test(
      'defensive: hasNextPage=true but nextCursor null → treated as no more pages',
      () async {
        final captured = <Map<String, dynamic>>[];
        final rpc = SuiRpcClient(
          transport: _mockTransport(
            captured,
            // Server is buggy: claims more pages but does not return a cursor.
            handler: (_) => _pageResponse(data: [], hasNextPage: true),
          ),
        );
        final provider = SuiNativeProvider(rpcClient: rpc);

        final page = await provider.listFromAddress(_suiAddr);

        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);

        rpc.close();
      },
    );
  });

  group('SuiNativeProvider — limit forwarding', () {
    test('limit param forwarded to RPC limit', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.listFromAddress(_suiAddr, limit: 25);

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['limit'], 25);

      rpc.close();
    });

    test('limit forwarded via TxHistoryQuery in listTransactions', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.listTransactions(
        const TxHistoryQuery(address: _suiAddr, limit: 50),
      );

      final query =
          (captured.single['params'] as List)[0] as Map<String, dynamic>;
      expect(query['limit'], 50);

      rpc.close();
    });
  });

  group('SuiNativeProvider.fromUrl — HTTPS-only SSRF guard (T-11-15)', () {
    test('http:// baseUrl throws ArgumentError by default', () {
      expect(
        () => SuiNativeProvider.fromUrl('http://attacker.example.com'),
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
      final provider = SuiNativeProvider.fromUrl(
        'https://fullnode.mainnet.sui.io',
      );
      expect(provider.close, returnsNormally);
    });

    test('http:// baseUrl with allowInsecure: true is accepted', () {
      final provider = SuiNativeProvider.fromUrl(
        'http://127.0.0.1:9000',
        allowInsecure: true,
      );
      expect(provider.close, returnsNormally);
    });
  });

  group('SuiNativeProvider — close() lifecycle (HIST-OPS-03)', () {
    test('injected SuiRpcClient is NOT closed by provider.close()', () async {
      final captured = <Map<String, dynamic>>[];
      final rpc = SuiRpcClient(
        transport: _mockTransport(captured, handler: (_) => _pageResponse()),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      await provider.listFromAddress(_suiAddr);
      expect(captured, hasLength(1));

      provider.close();

      // The injected SuiRpcClient must still be usable: its underlying
      // http.Client must not have been closed by the provider.
      final page = await rpc.queryTransactionBlocks(
        filter: const {'FromAddress': _suiAddr},
      );
      expect(page.data, isEmpty);
      expect(captured, hasLength(2));

      rpc.close();
    });

    test('fromUrl-built provider owns its rpc client; close() does not throw '
        'and is idempotent', () {
      final provider = SuiNativeProvider.fromUrl(
        'https://fullnode.mainnet.sui.io',
      );

      // Idempotent: multiple closes must not throw.
      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
    });
  });
}
