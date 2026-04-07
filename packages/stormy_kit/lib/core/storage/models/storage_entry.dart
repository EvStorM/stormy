/// 存储条目 - 用于封装带过期时间的数据
class StorageEntry<T> {
  final T value;
  final DateTime? expiresAt;

  const StorageEntry({required this.value, this.expiresAt});

  /// 检查是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 剩余有效期
  Duration? get remaining {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
