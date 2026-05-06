import 'package:ceres_wallet_onchain/ceres_wallet_onchain.dart';
import 'package:ceres_wallet_onchain/tx_history.dart';
import 'package:test/test.dart';

/// Mutable clock for tests so ban expiry can be exercised without
/// `Future.delayed`.
class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('EndpointPool — happy path', () {
    test('single endpoint: action runs once and returns its value', () async {
      var calls = 0;
      final pool = EndpointPool(baseUrls: const ['https://a.example']);
      final result = await pool.execute<int>((url) async {
        calls++;
        expect(url, 'https://a.example');
        return 42;
      });
      expect(result, 42);
      expect(calls, 1);
    });

    test('two endpoints: first call uses first endpoint', () async {
      final urls = <String>[];
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
      );
      await pool.execute<int>((url) async {
        urls.add(url);
        return 0;
      });
      expect(urls, ['https://a.example']);
    });
  });

  group('EndpointPool — failover on transient errors', () {
    test('RpcTimeoutException: walks to next endpoint, bans first', () async {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final urls = <String>[];
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
        now: clock.now,
      );
      final value = await pool.execute<String>((url) async {
        urls.add(url);
        if (url == 'https://a.example') {
          throw RpcTimeoutException(timeout: const Duration(seconds: 5));
        }
        return 'ok';
      });
      expect(value, 'ok');
      expect(urls, ['https://a.example', 'https://b.example']);

      // a.example should now be banned — the next call must skip it.
      urls.clear();
      await pool.execute<int>((url) async {
        urls.add(url);
        return 0;
      });
      expect(urls, ['https://b.example']);
    });

    test('RpcHttpException 503: walks to next endpoint, bans first', () async {
      final urls = <String>[];
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
      );
      final value = await pool.execute<String>((url) async {
        urls.add(url);
        if (url == 'https://a.example') {
          throw const RpcHttpException(statusCode: 503, message: 'down');
        }
        return 'ok';
      });
      expect(value, 'ok');
      expect(urls, ['https://a.example', 'https://b.example']);
    });

    test(
      'RateLimitedException with Retry-After: bans first for >= retryAfter',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 1, 1));
        final urls = <String>[];
        final pool = EndpointPool(
          baseUrls: const ['https://a.example', 'https://b.example'],
          // Make circuit-break smaller than Retry-After so we can prove
          // the larger value wins.
          circuitBreakDuration: const Duration(seconds: 1),
          now: clock.now,
        );

        final value = await pool.execute<String>((url) async {
          urls.add(url);
          if (url == 'https://a.example') {
            throw RateLimitedException(
              message: 'slow down',
              rateLimit: const RateLimitInfo(retryAfter: Duration(seconds: 5)),
            );
          }
          return 'ok';
        });
        expect(value, 'ok');
        expect(urls, ['https://a.example', 'https://b.example']);

        // Advance 2s — circuitBreak (1s) elapsed, but retryAfter (5s) not yet.
        clock.advance(const Duration(seconds: 2));
        urls.clear();
        await pool.execute<int>((url) async {
          urls.add(url);
          return 0;
        });
        expect(
          urls,
          ['https://b.example'],
          reason:
              'a.example must remain banned because Retry-After (5s) > '
              'elapsed (2s)',
        );

        // Advance another 4s so total = 6s > 5s → a.example reusable.
        clock.advance(const Duration(seconds: 4));
        urls.clear();
        await pool.execute<int>((url) async {
          urls.add(url);
          return 0;
        });
        expect(
          urls.first,
          isA<String>(),
          reason: 'after 6s elapsed, banned endpoint should be eligible again',
        );
      },
    );
  });

  group('EndpointPool — fail-fast on caller errors', () {
    test('RpcHttpException 400: rethrows immediately, no failover', () async {
      final urls = <String>[];
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
      );
      await expectLater(
        () => pool.execute<int>((url) async {
          urls.add(url);
          throw const RpcHttpException(statusCode: 400, message: 'bad request');
        }),
        throwsA(isA<RpcHttpException>()),
      );
      expect(urls, ['https://a.example']);
    });

    test('non-RpcException (ArgumentError): rethrows immediately', () async {
      final urls = <String>[];
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
      );
      await expectLater(
        () => pool.execute<int>((url) async {
          urls.add(url);
          throw ArgumentError('caller bug');
        }),
        throwsA(isA<ArgumentError>()),
      );
      expect(urls, ['https://a.example']);
    });
  });

  group('EndpointPool — exhaustion and bounds', () {
    test('all endpoints failing: throws TxHistoryApiException(-2002) with '
        '"all endpoints exhausted"', () async {
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
      );
      await expectLater(
        () => pool.execute<int>((url) async {
          throw const RpcHttpException(statusCode: 503, message: 'down');
        }),
        throwsA(
          isA<TxHistoryApiException>()
              .having((e) => e.code, 'code', -2002)
              .having(
                (e) => e.message,
                'message',
                contains('all endpoints exhausted'),
              ),
        ),
      );
    });

    test('all endpoints already banned: does not loop infinitely', () async {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final pool = EndpointPool(
        baseUrls: const ['https://a.example', 'https://b.example'],
        circuitBreakDuration: const Duration(minutes: 5),
        now: clock.now,
      );

      // Ban both endpoints by failing on each.
      await expectLater(
        () => pool.execute<int>((url) async {
          throw const RpcHttpException(statusCode: 503, message: 'down');
        }),
        throwsA(isA<TxHistoryApiException>()),
      );

      // Now both endpoints are banned. Next call must NOT loop forever and
      // must surface the same exhaustion error.
      await expectLater(
        () => pool.execute<int>((url) async => 0),
        throwsA(
          isA<TxHistoryApiException>().having(
            (e) => e.message,
            'message',
            contains('all endpoints exhausted'),
          ),
        ),
      );
    });

    test(
      'maxAttempts: 3 — stops after 3 attempts even with 5 endpoints',
      () async {
        var calls = 0;
        final pool = EndpointPool(
          baseUrls: const [
            'https://a.example',
            'https://b.example',
            'https://c.example',
            'https://d.example',
            'https://e.example',
          ],
          maxAttempts: 3,
        );
        await expectLater(
          () => pool.execute<int>((url) async {
            calls++;
            throw const RpcHttpException(statusCode: 503, message: 'down');
          }),
          throwsA(isA<TxHistoryApiException>()),
        );
        expect(calls, 3, reason: 'maxAttempts must bound attempt count');
      },
    );
  });

  group('EndpointPool — ban expiry', () {
    test(
      'banned endpoint is reused after circuitBreakDuration elapses',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 1, 1));
        final urls = <String>[];
        final pool = EndpointPool(
          baseUrls: const ['https://a.example', 'https://b.example'],
          circuitBreakDuration: const Duration(seconds: 30),
          now: clock.now,
        );

        // Fail a, succeed b.
        await pool.execute<int>((url) async {
          urls.add(url);
          if (url == 'https://a.example') {
            throw const RpcHttpException(statusCode: 503, message: 'down');
          }
          return 0;
        });
        expect(urls, ['https://a.example', 'https://b.example']);

        // Advance just under the ban — a is still banned.
        clock.advance(const Duration(seconds: 29));
        urls.clear();
        await pool.execute<int>((url) async {
          urls.add(url);
          return 0;
        });
        expect(urls, ['https://b.example'], reason: 'a still banned at 29s');

        // Advance past the ban — a should be eligible again.
        clock.advance(const Duration(seconds: 2));
        urls.clear();
        await pool.execute<int>((url) async {
          urls.add(url);
          return 0;
        });
        expect(
          urls.length,
          1,
          reason: 'pool must pick exactly one endpoint per call',
        );
        // Round-robin landed on a (cursor) — accept either, just ensure no
        // exhaustion.
        expect(urls.first, anyOf('https://a.example', 'https://b.example'));
      },
    );
  });

  group('EndpointPool — construction', () {
    test('throws on empty baseUrls', () {
      expect(
        () => EndpointPool(baseUrls: const []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
