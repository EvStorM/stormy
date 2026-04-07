import '../../config/models/storage_config.dart';
import 'interfaces/storage_engine.dart';
import 'mixins/storage_operations.dart';

/// 分区访问控制器代理类
class StorageBucketAccessor with StorageOperations {
  final IStorageEngine _engine;
  final StormyStorageConfig? _config;
  final String _bucketName;

  StorageBucketAccessor(this._engine, this._config, this._bucketName);

  @override
  IStorageEngine get storageEngine => _engine;

  @override
  StormyStorageConfig? get storageConfig => _config;

  @override
  String get currentBucketName => _bucketName;

  @override
  void ensureStorageInitialized() {
    // 假设拿到了 accessor 说明已经由外部初始化检查通过
  }
}
