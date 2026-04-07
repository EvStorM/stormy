import '../../config/models/storage_config.dart';
import 'adapters/hive_storage_engine.dart';
import 'interfaces/storage_engine.dart';
import 'models/storage_bucket.dart';

import 'mixins/storage_operations.dart';
import 'storage_bucket_accessor.dart';

export 'interfaces/storage_engine.dart';
export 'models/storage_bucket.dart';
export 'models/storage_entry.dart';
export 'mixins/storage_operations.dart';
export 'storage_bucket_accessor.dart';

/// StormyStorage - 统一存储总控入口
/// 采用面相对象模型与 Accessor 返回隔离实例执行工作。
/// [StormyStorage] 本身混入了 [StorageOperations]，可以直接对设定的 Default Bucket 操作键值对。
class StormyStorage with StorageOperations {
  static StormyStorage? _instance;
  static StormyStorage get instance => _instance ??= StormyStorage._();

  StormyStorage._();

  StormyStorageConfig? _config;
  IStorageEngine? _engine;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  StormyStorageConfig? get storageConfig => _config;

  @override
  IStorageEngine get storageEngine => _engine!;

  @override
  String get currentBucketName {
    ensureStorageInitialized();
    return _config!.defaultBucketName;
  }

  @override
  void ensureStorageInitialized() {
    if (!_isInitialized || _engine == null) {
      throw Exception('StormyStorage 尚未初始化，请先调用 initialize()');
    }
  }

  List<String> get bucketNames => _isInitialized && _engine != null ? _engine!.bucketNames : [];

  /// 获取指定分区的配置
  StorageBucket? getBucketConfig(String bucketName) {
    ensureStorageInitialized();
    return _engine!.getBucketConfig(bucketName);
  }

  /// 初始化存储模块
  /// [config] 必填，提供存储策略和全部分区定义。
  /// [registerAdapters] 选填，支持执行 Hive.registerAdapters 等外部自定义对象注册
  /// [engine] 选填，若不注入则使用包默认提供的 [HiveStorageEngine]。
  Future<void> initialize({
    required StormyStorageConfig config,
    void Function()? registerAdapters,
    IStorageEngine? engine,
  }) async {
    _config = config;
    _engine = engine ?? HiveStorageEngine();

    await _engine!.init(registerAdapters: registerAdapters);

    for (final bucketConfig in config.buckets) {
      await _engine!.openBucket(bucketConfig);
    }

    _isInitialized = true;
  }

  // ==================== Bucket Accessor ====================

  /// 创建并获取一个专门针对某 bucket 的隔离的存储访问控制器。
  /// 可以大幅避免使用多分区存储时的并发污染风险。
  StorageBucketAccessor bucket(String bucketName) {
    ensureStorageInitialized();
    if (!_engine!.bucketNames.contains(bucketName)) {
      throw Exception('未找到名为 $bucketName 的 Bucket，请确认初始化配置中定义了该实例。');
    }
    return StorageBucketAccessor(_engine!, _config, bucketName);
  }

  // ==================== 额外宏操作 ====================
  
  /// 清理所有已知分区的过期键值
  Future<int> clearAllExpiredAcrossBuckets() async {
    ensureStorageInitialized();
    int count = 0;
    for (final bName in _engine!.bucketNames) {
      count += await bucket(bName).clearExpired();
    }
    return count;
  }

  static Future<void> reset() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }

  Future<void> close() async {
    if (_isInitialized && _engine != null) {
      await _engine!.close();
      _isInitialized = false;
    }
  }
}
