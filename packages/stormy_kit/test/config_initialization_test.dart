import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_kit/stormy_kit.dart';

class FailingEngine implements IStorageEngine {
  final error = StateError('open failed');
  bool closed = false;
  @override
  Future<void> init({void Function()? registerAdapters}) async {}
  @override
  Future<void> openBucket(StorageBucket bucketConfig) async => throw error;
  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() async {
    await StormyStorage.reset();
    StormyConfigAccessor.reset();
  });

  test('only configured modules are validated and counted', () async {
    final config = await stormy()
        .network(StormyNetworkConfig(baseUrl: 'https://example.invalid'))
        .build(apply: false);
    final report = await config.apply();
    expect(report.isAllApplied, isTrue);
    expect(report.networkApplied, isTrue);
    expect(report.storageApplied, isFalse);
    expect(report.modules.length, 1);
  });

  test(
    'build exposes original module error and closes failed resources',
    () async {
      final engine = FailingEngine();
      final storage = StormyStorageConfig(
        buckets: [const StorageBucket(name: 'test')],
        engine: engine,
      );
      await expectLater(
        stormy().storage(storage).build(),
        throwsA(
          isA<StormyInitializationException>()
              .having(
                (e) => e.report.modules[StormyModule.storage]!.error,
                'original error',
                same(engine.error),
              )
              .having(
                (e) => e.report.modules[StormyModule.storage]!.stackTrace,
                'stack',
                isNotNull,
              ),
        ),
      );
      expect(engine.closed, isTrue);
      expect(StormyStorage.instance.isInitialized, isFalse);
      final report =
          await (StormyConfig()
                ..storage = storage
                ..i18n = const StormyI18nConfig())
              .apply();
      expect(report.localizationApplied, isFalse);
      expect(report.isAllApplied, isFalse);
    },
  );
}
