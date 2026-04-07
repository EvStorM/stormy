import 'package:hive_ce_flutter/hive_flutter.dart';

import '../interfaces/storage_engine.dart';
import '../models/storage_bucket.dart';
import 'hive_adapters.dart';

/// Hive 实现的底层引擎
class HiveStorageEngine implements IStorageEngine {
  final Map<String, Box> _boxes = {};
  final Map<String, StorageBucket> _configs = {};

  bool _isInitialized = false;

  @override
  Future<void> init({void Function()? registerAdapters}) async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    registerAdapters?.call();
    if (!Hive.isAdapterRegistered(StorageEntryAdapter().typeId)) {
      Hive.registerAdapter(StorageEntryAdapter());
    }
    _isInitialized = true;
  }

  @override
  Future<void> openBucket(StorageBucket bucketConfig) async {
    final cipher = bucketConfig.encryptionCipher is HiveCipher
        ? bucketConfig.encryptionCipher as HiveCipher
        : null;

    final box = await Hive.openBox(
      bucketConfig.name,
      encryptionCipher: cipher,
      path: bucketConfig.path,
    );
    _boxes[bucketConfig.name] = box;
    _configs[bucketConfig.name] = bucketConfig;
  }

  @override
  List<String> get bucketNames => _boxes.keys.toList();

  @override
  StorageBucket? getBucketConfig(String bucketName) => _configs[bucketName];

  Box _resolveBox(String bucketName) {
    final box = _boxes[bucketName];
    if (box == null) {
      throw Exception('StorageException: Bucket "$bucketName" 未找到或尚未加载');
    }
    return box;
  }

  @override
  Future<void> set(
    String key,
    dynamic value, {
    required String bucketName,
  }) async {
    final box = _resolveBox(bucketName);
    await box.put(key, value);
  }

  @override
  dynamic get(String key, {required String bucketName}) {
    final box = _resolveBox(bucketName);
    return box.get(key);
  }

  @override
  bool containsKey(String key, {required String bucketName}) {
    final box = _resolveBox(bucketName);
    return box.containsKey(key);
  }

  @override
  Future<void> remove(String key, {required String bucketName}) async {
    final box = _resolveBox(bucketName);
    await box.delete(key);
  }

  @override
  Future<void> removeMany(
    List<String> keys, {
    required String bucketName,
  }) async {
    final box = _resolveBox(bucketName);
    for (final k in keys) {
      await box.delete(k);
    }
  }

  @override
  List<String> getKeys({required String bucketName}) {
    final box = _resolveBox(bucketName);
    return box.keys.map((k) => k.toString()).toList();
  }

  @override
  List<dynamic> getValues({required String bucketName}) {
    final box = _resolveBox(bucketName);
    return box.values.toList();
  }

  @override
  Future<int> add(dynamic value, {required String bucketName}) async {
    final box = _resolveBox(bucketName);
    return await box.add(value);
  }

  @override
  Future<void> clearBucket(String bucketName) async {
    final box = _resolveBox(bucketName);
    await box.clear();
  }

  @override
  Future<void> close() async {
    for (final box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();
    _configs.clear();
    _isInitialized = false;
  }
}
