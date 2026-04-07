class StorageBucket {
  /// 分区名称（必填）
  final String name;

  /// 加密配置（非直接引用具体的安全库类，由底层引擎自行强转）
  final Object? encryptionCipher;

  /// 分类标签（如 `user`、`cache`、`setting`），用于逻辑分组
  final String? category;

  /// 存储路径（可选，针对支持本地路径挂载的引擎）
  final String? path;

  const StorageBucket({
    required this.name,
    this.encryptionCipher,
    this.category,
    this.path,
  });

  @override
  String toString() => 'StorageBucket(name: $name, category: $category)';
}
