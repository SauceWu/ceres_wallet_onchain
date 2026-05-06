/// Bounded-semaphore primitive that caps concurrent RPC fan-out.
/// `SolanaNativeProvider` uses it on batched `getTransaction` so public
/// mainnet RPC does not 429-storm (PITFALLS.md O-01). Orthogonal to
/// `JsonRpcTransport._withRetry` which coordinates within one call.
library;

import 'dart:async';
import 'dart:collection';

/// Bounded semaphore: at most [max] tasks are in-flight at any time.
///
/// Tasks beyond [max] are queued in submission order. Completion order
/// for `max > 1` is NOT guaranteed; at `max == 1` the semaphore degrades
/// to strict FIFO.
class ConcurrencyLimiter {
  /// Maximum number of in-flight tasks.
  final int max;

  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// Throws [ArgumentError] if [max] is less than 1.
  ConcurrencyLimiter({required this.max}) {
    if (max < 1) {
      throw ArgumentError.value(max, 'max', 'must be >= 1');
    }
  }

  /// Runs [task] under the semaphore. Releases the slot whether [task]
  /// succeeds or throws; rethrows the original error verbatim.
  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_inFlight < max) {
      _inFlight++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
    _inFlight++;
  }

  void _release() {
    _inFlight--;
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }
}
