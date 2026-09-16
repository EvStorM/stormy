import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:stormy_core/utils/preload/preload.dart';
import 'package:stormy_core/utils/preload/engine/preload_engine.dart';
import 'package:stormy_core/utils/preload/tracker/preload_tracker.dart';

void main() {
  test(
    'invalid dependency graphs terminate progress and allow retry',
    () async {
      final tracker = PreloadTracker();
      addTearDown(tracker.dispose);
      final engine = PreloadEngine(
        tracker: tracker,
        config: const PreloadConfig(enableLogging: false),
      );
      final failed = await engine.execute([
        PreloadTask(
          id: 'invalid',
          dependencies: ['missing'],
          method: () async {},
        ),
      ]);
      expect(failed.result, PreloadResult.failed);
      expect(failed.failedTasks, 1);
      expect(tracker.state, PreloadManagerState.failed);
      final empty = await engine.execute([]);
      expect(empty.result, PreloadResult.success);
      expect(tracker.state, PreloadManagerState.completed);
    },
  );

  test('terminal progress includes failure/cancellation and owned containers close', () async {
    final tracker = PreloadTracker();
    addTearDown(tracker.dispose);
    final updates = <PreloadProgress>[];
    final subscription = tracker.stream.listen(updates.add);
    addTearDown(subscription.cancel);
    var disposed = false;
    final engine = PreloadEngine(
      config: const PreloadConfig(enableLogging: false, maxRetries: 0),
      tracker: tracker,
    );
    final provider = FutureProvider<int>((ref) async {
      ref.onDispose(() => disposed = true);
      throw StateError('async failure');
    });
    final result = await engine.execute([
      PreloadTask(id: 'provider', provider: provider),
      PreloadTask(
        id: 'blocked',
        dependencies: ['provider'],
        method: () async {
          fail('failed prerequisite');
        },
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isTrue);
    expect(result.cancelledTasks, 1);
    expect(updates.last.state, PreloadManagerState.failed);
    expect(updates.last.runningTasks, 0);
    expect(updates.last.failedTasks, 1);
    expect(updates.last.cancelledTasks, 1);
    expect(updates.last.progress, 1);
  });

  test(
    'caller container survives and async providers complete before dependents',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gate = Completer<int>();
      final provider = FutureProvider<int>((ref) => gate.future);
      var dependentRan = false;
      final engine = PreloadEngine(
        config: const PreloadConfig(enableLogging: false),
      );
      final run = engine.execute([
        PreloadTask(provider: provider, id: 'value'),
        PreloadTask(
          id: 'dependent',
          dependencies: ['value'],
          method: () async {
            expect(container.read(provider).requireValue, 42);
            dependentRan = true;
          },
        ),
      ], container: container);
      await Future<void>.delayed(Duration.zero);
      expect(dependentRan, isFalse);
      gate.complete(42);
      final result = await run;
      expect(result.completedTasks, 2);
      expect(result.result, PreloadResult.success);
      expect(container.read(provider).requireValue, 42);
    },
  );

  test('required failures stay failed and method timeouts finish', () async {
    final engine = PreloadEngine(
      config: const PreloadConfig(
        enableLogging: false,
        defaultTimeout: Duration(milliseconds: 10),
      ),
    );
    final result = await engine.execute([
      PreloadTask(id: 'never', method: () => Completer<void>().future),
      PreloadTask(
        id: 'dependent',
        dependencies: ['never'],
        method: () async {
          fail('must not run');
        },
      ),
    ]);
    expect(result.result, PreloadResult.failed);
    expect(result.failedTasks, 1);
    expect(result.completedTasks, 0);
  });

  test(
    'concurrent retry waits finish and cancellation releases every task',
    () async {
      final engine = PreloadEngine(
        config: const PreloadConfig(
          enableLogging: false,
          maxRetries: 1,
          retryBaseDelay: Duration(milliseconds: 10),
        ),
      );
      final result = await engine
          .execute([
            for (var i = 0; i < 3; i++)
              PreloadTask(
                id: 'fail$i',
                provider: Provider<int>((ref) => throw StateError('failure')),
                config: const TaskConfig(required: false),
              ),
          ])
          .timeout(const Duration(seconds: 2));
      expect(result.failedTasks, 3);
      expect(result.result, PreloadResult.partialSuccess);

      final started = Completer<void>();
      final run = engine.execute([
        for (var i = 0; i < 5; i++)
          PreloadTask(
            id: 'cancel$i',
            method: () {
              if (!started.isCompleted) started.complete();
              return Completer<void>().future;
            },
          ),
      ]);
      await started.future;
      engine.cancel();
      expect(
        (await run.timeout(const Duration(seconds: 2))).result,
        PreloadResult.cancelled,
      );
      final next = await engine.execute([
        PreloadTask(id: 'again', method: () async {}),
      ]);
      expect(next.completedTasks, 1);
    },
  );
}
