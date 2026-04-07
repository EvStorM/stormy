import '../models/storage_bucket.dart';

/// 存储引擎规范，定义底层具体实现的存储驱动（如 Hive、SharedPreferences）行为
abstract class IStorageEngine {
  /// 初始化存储系统基础设施
  /// 
  /// 允许在开启真正的物理分区前执行外部的自定义 [registerAdapters] 操作
  Future<void> init({void Function()? registerAdapters});

  /// 打开并加载指定的存储分区（Bucket）
  Future<void> openBucket(StorageBucket bucketConfig);

  /// 所有可用的分区名称
  List<String> get bucketNames;

  /// 获取分区配置对象
  StorageBucket? getBucketConfig(String bucketName);

  /// 写入键值对
  Future<void> set(String key, dynamic value, {required String bucketName});

  /// 读取单个键
  dynamic get(String key, {required String bucketName});

  /// 指定键是否已存在
  bool containsKey(String key, {required String bucketName});

  /// A移除某个已存储的键
  Future<void> remove(String key, {required String bucketName});

  /// 批量删除
  Future<void> removeMany(List<String> keys, {required String bucketName});

  /// 获取分区内所有的键
  List<String> getKeys({required String bucketName});

  /// 获取分区内的所有值，常用来配合实现类似于 NoSQL 表级别的列表查询与聚合
  List<dynamic> getValues({required String bucketName});

  /// 添加一个没有显式键的值（自动分配一个整型键）并返回生成的键
  /// 
  /// 专门用于频繁更新的超大列表/消息列队场景
  Future<int> add(dynamic value, {required String bucketName});

  /// 清空某个分区内所有数据
  Future<void> clearBucket(String bucketName);

  /// 释放所有正在占用的分区并关闭引擎
  Future<void> close();
}
