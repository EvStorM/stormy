import '../../core/storage/models/storage_bucket.dart';

/// Storage Config - 存储配置
/// 用于配置本地存储的相关参数
class StormyStorageConfig {
  /// 存储 Bucket 配置列表
  final List<StorageBucket> buckets;

  /// Key前缀
  final String? prefix;

  /// 默认使用的 Bucket 名称
  final String defaultBucketName;

  /// 自定义对象适配器注册回调
  final void Function()? registerAdapters;

  StormyStorageConfig({
    required this.buckets,
    this.prefix,
    String? defaultBucketName,
    this.registerAdapters,
  }) : assert(buckets.isNotEmpty, '至少需要提供一个 Bucket 配置'),
       defaultBucketName = defaultBucketName ?? buckets.first.name;

  /// 创建单 Bucket 默认配置
  factory StormyStorageConfig.defaultConfig({
    String bucketName = 'stormy_storage',
    String? prefix,
    Object? encryptionCipher,
    String? storagePath,
    void Function()? registerAdapters,
  }) {
    return StormyStorageConfig(
      buckets: [
        StorageBucket(
          name: bucketName,
          encryptionCipher: encryptionCipher,
          path: storagePath,
        ),
      ],
      prefix: prefix,
      defaultBucketName: bucketName,
      registerAdapters: registerAdapters,
    );
  }

  /// 复制并修改配置
  StormyStorageConfig copyWith({
    List<StorageBucket>? buckets,
    String? prefix,
    String? defaultBucketName,
    void Function()? registerAdapters,
  }) {
    return StormyStorageConfig(
      buckets: buckets ?? this.buckets,
      prefix: prefix ?? this.prefix,
      defaultBucketName: defaultBucketName ?? this.defaultBucketName,
      registerAdapters: registerAdapters ?? this.registerAdapters,
    );
  }

  /// 生成带前缀的Key
  String prefixedKey(String key) {
    return '${prefix ?? ''}$key';
  }
}
