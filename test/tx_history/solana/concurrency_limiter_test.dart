/// Behavioural tests for [ConcurrencyLimiter] — the bounded-semaphore
/// primitive used by [SolanaNativeProvider] to cap concurrent
/// `getTransaction` fan-out (PITFALLS.md O-01).
library;

import 'package:ceres_wallet_onchain/src/tx_history/solana/concurrency_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('ConcurrencyLimiter', () {
    test(
      'max:1 — five tasks run sequentially; in-flight never exceeds 1',
      () async {
        final limiter = ConcurrencyLimiter(max: 1);
        var inFlight = 0;
        var peak = 0;

        Future<int> task(int i) => limiter.run<int>(() async {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          // Yield to the event loop so any racing task that bypassed
          // the semaphore would actually be observed before we
          // decrement.
          await Future<void>.delayed(const Duration(milliseconds: 1));
          inFlight--;
          return i;
        });

        final results = await Future.wait(<Future<int>>[
          for (var i = 0; i < 5; i++) task(i),
        ]);

        expect(peak, 1);
        expect(results, [0, 1, 2, 3, 4]); // ordering guaranteed at max=1
      },
    );

    test('max:3 — ten tasks observe peak in-flight == 3', () async {
      final limiter = ConcurrencyLimiter(max: 3);
      var inFlight = 0;
      var peak = 0;

      final tasks = List<Future<void>>.generate(10, (_) {
        return limiter.run<void>(() async {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
        });
      });

      await Future.wait(tasks);
      expect(peak, 3);
    });

    test('max:0 throws ArgumentError', () {
      expect(() => ConcurrencyLimiter(max: 0), throwsA(isA<ArgumentError>()));
    });

    test('max:-1 throws ArgumentError', () {
      expect(() => ConcurrencyLimiter(max: -1), throwsA(isA<ArgumentError>()));
    });

    test(
      'task throws → semaphore releases the slot; subsequent tasks proceed',
      () async {
        final limiter = ConcurrencyLimiter(max: 1);
        // First task throws.
        await expectLater(
          limiter.run<void>(() async {
            throw StateError('boom');
          }),
          throwsA(isA<StateError>()),
        );

        // Subsequent task must still acquire the slot (not deadlocked).
        final result = await limiter.run<int>(() async => 7);
        expect(result, 7);
      },
    );

    test('run() returns the task value (not wrapped)', () async {
      final limiter = ConcurrencyLimiter(max: 2);
      final s = await limiter.run<String>(() async => 'hello');
      expect(s, 'hello');

      final m = await limiter.run<Map<String, int>>(() async => {'a': 1});
      expect(m, {'a': 1});
    });

    test(
      'tasks complete in submission order when concurrency=1 (FIFO queue)',
      () async {
        final limiter = ConcurrencyLimiter(max: 1);
        final completionOrder = <int>[];

        final futures = List<Future<void>>.generate(5, (i) {
          return limiter.run<void>(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            completionOrder.add(i);
          });
        });

        await Future.wait(futures);
        expect(completionOrder, [0, 1, 2, 3, 4]);
      },
    );
  });
}
