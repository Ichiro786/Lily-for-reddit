import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/storage/deferred_pref_writer.dart';

void main() {
  testWidgets('burst of schedules coalesces into a single write',
      (tester) async {
    var writes = 0;
    final writer = DeferredPrefWriter(() async => writes++);

    // Events keep arriving every 100ms — inside the quiet window each time.
    for (var i = 0; i < 25; i++) {
      writer.schedule();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(writes, 0);
    expect(writer.hasPendingWrite, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    expect(writes, 1);
    expect(writer.hasPendingWrite, isFalse);
  });

  testWidgets('flush forces an immediate durable write and clears pending',
      (tester) async {
    var writes = 0;
    final writer = DeferredPrefWriter(() async => writes++);

    writer.schedule();
    writer.schedule();
    expect(writes, 0);

    final flushed = writer.flush();
    expect(writes, 1);
    expect(writer.hasPendingWrite, isFalse);
    await flushed;

    // Timer already cancelled by flush: no further write occurs.
    await tester.pump(const Duration(seconds: 2));
    expect(writes, 1);
  });

  testWidgets('cancel drops the pending write entirely', (tester) async {
    var writes = 0;
    final writer = DeferredPrefWriter(() async => writes++);

    writer.schedule();
    writer.cancel();
    await tester.pump(const Duration(seconds: 5));

    expect(writes, 0);
    expect(writer.hasPendingWrite, isFalse);
  });
}
