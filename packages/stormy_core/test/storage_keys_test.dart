import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_core/stormy_core.dart';
import 'package:stormy_core/core/storage/adapters/hive_storage_engine.dart';
import 'package:stormy_core/core/storage/adapters/hive_adapters.dart';

void main() {
  late Directory directory;
  late HiveStorageEngine engine;
  late StorageBucketAccessor storage;

  setUp(() async {
    final parent = Directory('../../temp/reliability')
      ..createSync(recursive: true);
    directory = parent.createTempSync('storage-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(222))
      Hive.registerAdapter(StorageEntryAdapter());
    engine = HiveStorageEngine();
    await engine.openBucket(const StorageBucket(name: 'keys'));
    storage = StorageBucketAccessor(
      engine,
      StormyStorageConfig.defaultConfig(bucketName: 'keys', prefix: 'user:'),
      'keys',
    );
  });

  tearDown(() async {
    await engine.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'integer and prefixed string keys survive enumeration and reopening',
    () async {
      final id = await storage.add('integer');
      await storage.set('$id', 'string');
      expect(storage.getKeys(), containsAll([id, '$id']));
      expect(storage.get<String>(id), 'integer');
      expect(storage.get<String>('$id'), 'string');
      await engine.close();
      await engine.openBucket(const StorageBucket(name: 'keys'));
      expect(storage.get<String>(id), 'integer');
      expect(storage.containsKey(id), isTrue);
      await storage.removeMany([id, '$id']);
      expect(storage.getKeys(), isEmpty);
    },
  );

  test('TTL cleanup removes integer and string records', () async {
    final id = await storage.add(
      'expired',
      expiresIn: const Duration(seconds: -1),
    );
    await storage.set('expired', 'old', expiresIn: const Duration(seconds: -1));
    await storage.set('live', 'current');
    expect(await storage.clearExpired(), 2);
    expect(storage.containsKey(id), isFalse);
    expect(storage.getKeys(), ['live']);
    final next = await storage.add(
      'expired',
      expiresIn: const Duration(seconds: -1),
    );
    expect(storage.get<String>(next), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(storage.containsKey(next), isFalse);
  });

  test('invalid key types fail explicitly', () async {
    await expectLater(storage.set(1.2, 'bad'), throwsArgumentError);
    expect(() => storage.get<Object>(true), throwsArgumentError);
  });
}
