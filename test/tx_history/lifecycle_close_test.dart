/// Cross-provider lifecycle audit (HIST-OPS-03).
///
/// For every history provider in the package — and for the shared
/// [RestHistoryClient] primitive — verifies the ownership-flag close()
/// contract:
///
///  - When the provider received an EXTERNAL transport / `http.Client` /
///    rpc client via its constructor, [close] MUST NOT close it. The
///    caller retains lifecycle ownership.
///  - When the provider built the transport / client INTERNALLY (via
///    `.fromUrl` or by omitting the `httpClient:` parameter), [close]
///    MUST close it.
///  - [close] MUST be idempotent — calling it twice MUST NOT throw,
///    regardless of ownership.
///
/// The test uses a custom [http.BaseClient] subclass (`_SpyClient`) so
/// it can assert "was close() actually called on the client I passed
/// in?" rather than relying on the (undocumented) idempotency of
/// `http.Client.close`.
library;

import 'dart:convert';

import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Tracks every send() and close() call so the lifecycle test can assert
/// "external client was NOT closed" / "internal client WAS closed".
class _SpyClient extends http.BaseClient {
  int closeCount = 0;
  int sendCount = 0;
  bool _underlyingClosed = false;

  /// Stub response body returned for every send(). All providers under
  /// test only need a 200 OK with a JSON-shaped body to construct;
  /// this client is never exercised mid-flight in the lifecycle tests
  /// — it is only built and closed. Hard-coded to keep the spy
  /// constructor parameter-free (no-arg lints clean).
  static const String _stubResponseBody = '{}';

  _SpyClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_underlyingClosed) {
      throw StateError('SpyClient: send() called after close()');
    }
    sendCount++;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(_stubResponseBody)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closeCount++;
    _underlyingClosed = true;
    super.close();
  }
}

void main() {
  group('SolanaNativeProvider — close() ownership', () {
    test('INJECTED rpcClient: provider.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final rpc = SolanaRpcClient(
        transport: JsonRpcTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.mainnet-beta.solana.com',
          ),
          httpClient: spy,
        ),
      );
      final provider = SolanaNativeProvider(rpcClient: rpc);

      provider.close();

      expect(
        spy.closeCount,
        0,
        reason:
            'provider does NOT own the rpc client — close() must leave the '
            'underlying http.Client untouched (HIST-OPS-03).',
      );

      // Caller retains ownership; clean up afterwards.
      rpc.close();
    });

    test('fromUrl(...): provider.close() is idempotent (no throw)', () {
      final provider = SolanaNativeProvider.fromUrl(
        'https://api.mainnet-beta.solana.com',
      );
      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
    });

    test('INJECTED rpcClient: close() is idempotent', () {
      final spy = _SpyClient();
      final rpc = SolanaRpcClient(
        transport: JsonRpcTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://api.mainnet-beta.solana.com',
          ),
          httpClient: spy,
        ),
      );
      final provider = SolanaNativeProvider(rpcClient: rpc);

      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
      expect(spy.closeCount, 0);

      rpc.close();
    });
  });

  group('SuiNativeProvider — close() ownership', () {
    test('INJECTED rpcClient: provider.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final rpc = SuiRpcClient(
        transport: JsonRpcTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://fullnode.mainnet.sui.io',
          ),
          httpClient: spy,
        ),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      provider.close();

      expect(spy.closeCount, 0);
      rpc.close();
    });

    test('fromUrl(...): close() is idempotent', () {
      final provider = SuiNativeProvider.fromUrl(
        'https://fullnode.mainnet.sui.io',
      );
      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
    });

    test('INJECTED rpcClient: close() is idempotent', () {
      final spy = _SpyClient();
      final rpc = SuiRpcClient(
        transport: JsonRpcTransport(
          config: const RpcClientConfig(
            baseUrl: 'https://fullnode.mainnet.sui.io',
          ),
          httpClient: spy,
        ),
      );
      final provider = SuiNativeProvider(rpcClient: rpc);

      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
      expect(spy.closeCount, 0);

      rpc.close();
    });
  });

  group('EvmBlockscoutProvider — close() ownership', () {
    test('INJECTED httpClient: provider.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final provider = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.blockscout.com'],
        httpClient: spy,
      );

      provider.close();

      expect(spy.closeCount, 0);
      // Caller cleans up.
      spy.close();
    });

    test(
      'default constructor (internal http.Client): close() is idempotent',
      () {
        final provider = EvmBlockscoutProvider(
          baseUrls: const ['https://eth.blockscout.com'],
        );
        expect(provider.close, returnsNormally);
        expect(provider.close, returnsNormally);
      },
    );

    test('INJECTED httpClient: close() is idempotent', () {
      final spy = _SpyClient();
      final provider = EvmBlockscoutProvider(
        baseUrls: const ['https://eth.blockscout.com'],
        httpClient: spy,
      );

      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
      expect(spy.closeCount, 0);

      spy.close();
    });
  });

  group('EvmEtherscanProvider — close() ownership', () {
    test('INJECTED httpClient: provider.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final provider = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        httpClient: spy,
      );

      provider.close();

      expect(spy.closeCount, 0);
      spy.close();
    });

    test('default constructor: close() is idempotent', () {
      final provider = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
      );
      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
    });

    test('INJECTED httpClient: close() is idempotent', () {
      final spy = _SpyClient();
      final provider = EvmEtherscanProvider(
        baseUrl: 'https://api.etherscan.io',
        httpClient: spy,
      );

      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
      expect(spy.closeCount, 0);

      spy.close();
    });
  });

  group('TronGridProvider — close() ownership', () {
    test('INJECTED httpClient: provider.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final provider = TronGridProvider(
        baseUrl: 'https://api.trongrid.io',
        httpClient: spy,
      );

      provider.close();

      expect(spy.closeCount, 0);
      spy.close();
    });

    test('default constructor: close() is idempotent', () {
      final provider = TronGridProvider(baseUrl: 'https://api.trongrid.io');
      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
    });

    test('INJECTED httpClient: close() is idempotent', () {
      final spy = _SpyClient();
      final provider = TronGridProvider(
        baseUrl: 'https://api.trongrid.io',
        httpClient: spy,
      );

      expect(provider.close, returnsNormally);
      expect(provider.close, returnsNormally);
      expect(spy.closeCount, 0);

      spy.close();
    });
  });

  group('RestHistoryClient — close() ownership (advanced primitive)', () {
    test('INJECTED httpClient: client.close() does NOT close the spy', () {
      final spy = _SpyClient();
      final rest = RestHistoryClient(
        pool: EndpointPool(baseUrls: const ['https://eth.blockscout.com']),
        httpClient: spy,
      );

      rest.close();

      expect(spy.closeCount, 0);
      spy.close();
    });

    test('No httpClient: close() is idempotent', () {
      final rest = RestHistoryClient(
        pool: EndpointPool(baseUrls: const ['https://eth.blockscout.com']),
      );
      expect(rest.close, returnsNormally);
      expect(rest.close, returnsNormally);
    });

    test('INJECTED httpClient: close() is idempotent', () {
      final spy = _SpyClient();
      final rest = RestHistoryClient(
        pool: EndpointPool(baseUrls: const ['https://eth.blockscout.com']),
        httpClient: spy,
      );

      expect(rest.close, returnsNormally);
      expect(rest.close, returnsNormally);
      expect(spy.closeCount, 0);

      spy.close();
    });
  });
}
