import 'dart:async';

/// Coalesces repeated preference writes into a single deferred write.
///
/// Stores that mutate on every user event (feed dwell, votes, history views)
/// previously serialized their entire payload per event. This scheduler keeps
/// a single pending flag and one-shot timer so any burst collapses into at
/// most one [write] after [delay] of quiet, or immediately via [flush].
///
/// Durability contract: events become durable at most [delay] after they
/// happen; [flush] forces durability now (used by tests and dispose paths).
class DeferredPrefWriter {
  DeferredPrefWriter(this.write, {this.delay = const Duration(milliseconds: 500)});

  /// Serializes and persists the caller's CURRENT state when invoked.
  final Future<void> Function() write;
  final Duration delay;

  Timer? _timer;
  bool _pending = false;

  /// True while at least one scheduled write has not yet been performed.
  bool get hasPendingWrite => _pending;

  /// Marks state dirty and (re)arms the debounce timer.
  void schedule() {
    _pending = true;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _pending = false;
      unawaited(write());
    });
  }

  /// Cancels the pending timer and, if dirty, writes immediately.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending) {
      _pending = false;
      await write();
    }
  }

  /// Cancels any pending timer without writing.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = false;
  }
}
