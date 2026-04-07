import '../../../config/models/storage_config.dart';
import '../interfaces/storage_engine.dart';
import '../models/storage_entry.dart';

mixin StorageOperations {
  IStorageEngine get storageEngine;
  StormyStorageConfig? get storageConfig;
  String get currentBucketName;
  void ensureStorageInitialized();

  String _prefixedKey(String key) {
    return storageConfig?.prefixedKey(key) ?? key;
  }

  // ============== Core KV ==============
  
  /// 保存任意值（支持过期时间）
  Future<void> set(String key, dynamic value, {Duration? expiresIn}) async {
    ensureStorageInitialized();
    final prefixedKey = _prefixedKey(key);
    if (expiresIn != null) {
      final entry = StorageEntry<dynamic>(
        value: value,
        expiresAt: DateTime.now().add(expiresIn),
      );
      await storageEngine.set(prefixedKey, entry, bucketName: currentBucketName);
    } else {
      await storageEngine.set(prefixedKey, value, bucketName: currentBucketName);
    }
  }

  /// 获取值（自动检查过期）
  T? get<T>(String key, {T Function(dynamic)? decoder}) {
    ensureStorageInitialized();
    final prefixedKey = _prefixedKey(key);
    final raw = storageEngine.get(prefixedKey, bucketName: currentBucketName);
    if (raw == null) return null;

    if (raw is StorageEntry) {
      if (raw.isExpired) {
        storageEngine.remove(prefixedKey, bucketName: currentBucketName);
        return null;
      }
      return _decodeValue<T>(raw.value, decoder);
    }
    return _decodeValue<T>(raw, decoder);
  }

  T? _decodeValue<T>(dynamic value, T Function(dynamic)? decoder) {
    if (value == null) return null;
    if (decoder != null) return decoder(value);
    if (value is T) return value;
    return null;
  }

  /// 获取分区内的所有的值（自动检查过期）
  /// [excludeExpired] 控制是否在结果中排除已过期的数据，默认排除
  List<T> getValues<T>({T Function(dynamic)? decoder, bool excludeExpired = true}) {
    ensureStorageInitialized();
    final allValues = storageEngine.getValues(bucketName: currentBucketName);
    final result = <T>[];
    for (final raw in allValues) {
      if (raw is StorageEntry) {
        if (excludeExpired && raw.isExpired) continue;
        final decoded = _decodeValue<T>(raw.value, decoder);
        if (decoded != null) result.add(decoded);
      } else {
        final decoded = _decodeValue<T>(raw, decoder);
        if (decoded != null) result.add(decoded);
      }
    }
    return result;
  }

  /// 对分区内的所有值进行过滤查询
  List<T> queryValues<T>(bool Function(T filter) test, {T Function(dynamic)? decoder}) {
    return getValues<T>(decoder: decoder).where(test).toList();
  }

  /// 追加单项到 Bucket (依靠引擎自带的 Auto Increment 机制机制存储)
  /// 
  /// 由于没有提供显式的键值，底层的 Hive 将为其自动生成一个整型自增的主键并返回。
  /// 此特性非常适合处理诸如消息列表或者经常变更的大数据量对象集合。
  Future<int> add(dynamic value, {Duration? expiresIn}) async {
    ensureStorageInitialized();
    if (expiresIn != null) {
      final entry = StorageEntry<dynamic>(
        value: value,
        expiresAt: DateTime.now().add(expiresIn),
      );
      return await storageEngine.add(entry, bucketName: currentBucketName);
    } else {
      return await storageEngine.add(value, bucketName: currentBucketName);
    }
  }

  // ============== 快捷类型安全方法 ==============
  
  Future<void> setString(String key, String value) async => set(key, value);
  String? getString(String key) => get<String>(key);
  Future<void> setInt(String key, int value) async => set(key, value);
  int? getInt(String key) => get<int>(key);
  Future<void> setBool(String key, bool value) async => set(key, value);
  bool? getBool(String key) => get<bool>(key);
  Future<void> setDouble(String key, double value) async => set(key, value);
  double? getDouble(String key) => get<double>(key);

  Future<void> setJson(String key, Map<String, dynamic> value, {Duration? expiresIn}) async {
    await set(key, value, expiresIn: expiresIn);
  }

  Map<String, dynamic>? getJson(String key) {
    final value = get<Map<dynamic, dynamic>>(key);
    if (value == null) return null;
    return value.cast<String, dynamic>();
  }

  Future<void> setJsonWithExpiry(String key, Map<String, dynamic> value, Duration expiresIn) async {
    await setJson(key, value, expiresIn: expiresIn);
  }

  Future<void> setObject(String key, dynamic object, {Duration? expiresIn}) async {
    await set(key, object, expiresIn: expiresIn);
  }

  dynamic getObject(String key) => get(key);

  // ============== 生命周期与清理 ==============
  
  Future<void> remove(String key) async {
    ensureStorageInitialized();
    await storageEngine.remove(_prefixedKey(key), bucketName: currentBucketName);
  }

  Future<void> removeMany(List<String> keys) async {
    ensureStorageInitialized();
    final formattedKeys = keys.map(_prefixedKey).toList();
    await storageEngine.removeMany(formattedKeys, bucketName: currentBucketName);
  }

  Future<void> clear() async {
    ensureStorageInitialized();
    await storageEngine.clearBucket(currentBucketName);
  }

  bool containsKey(String key) {
    ensureStorageInitialized();
    return storageEngine.containsKey(_prefixedKey(key), bucketName: currentBucketName);
  }

  List<String> getKeys({bool excludeExpired = true}) {
    ensureStorageInitialized();
    final prefix = storageConfig?.prefix ?? '';
    final allKeys = storageEngine.getKeys(bucketName: currentBucketName);
    
    final filtered = <String>[];
    for (final rawKey in allKeys) {
      if (!rawKey.startsWith(prefix)) continue;
      
      // 过滤系统内部管理的元信息键
      final internalKeyObj = rawKey.substring(prefix.length);
      if (internalKeyObj.startsWith('\$list:') || internalKeyObj.startsWith('\$meta:')) {
        continue;
      }

      if (excludeExpired) {
        final rawVal = storageEngine.get(rawKey, bucketName: currentBucketName);
        if (rawVal is StorageEntry && rawVal.isExpired) {
          continue;
        }
      }

      filtered.add(internalKeyObj);
    }
    return filtered;
  }

  bool isExpired(String key) {
    ensureStorageInitialized();
    final raw = storageEngine.get(_prefixedKey(key), bucketName: currentBucketName);
    if (raw is StorageEntry) {
      return raw.isExpired;
    }
    return false;
  }

  Duration? getExpiresIn(String key) {
    ensureStorageInitialized();
    final raw = storageEngine.get(_prefixedKey(key), bucketName: currentBucketName);
    if (raw is StorageEntry) {
      return raw.remaining;
    }
    return null;
  }

  Future<int> clearExpired() async {
    ensureStorageInitialized();
    int count = 0;
    final keys = storageEngine.getKeys(bucketName: currentBucketName);
    final keysToDelete = <String>[];
    for (final key in keys) {
      final raw = storageEngine.get(key, bucketName: currentBucketName);
      if (raw is StorageEntry && raw.isExpired) {
        keysToDelete.add(key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await storageEngine.removeMany(keysToDelete, bucketName: currentBucketName);
      count += keysToDelete.length;
    }
    return count;
  }
}
