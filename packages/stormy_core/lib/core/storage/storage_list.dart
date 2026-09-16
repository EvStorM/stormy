import 'storage_bucket_accessor.dart';
import 'stormy_storage.dart';

/// 专门用于处理列表数据的存储封装
///
/// 根据方案 C 设计：不同的列表对应不同的 bucket（box），不会进行混用。
/// 请确保在初始化 [StormyStorageConfig] 时，已经为该列表提前注册了同名的 bucket。
class StormyListStorage<T> {
  final StorageBucketAccessor _accessor;

  /// 列表名称，同时也是它所对应的 Bucket (Box) 的名称
  final String listName;

  /// 构造一个特定名称的 List 存储器
  /// [listName] 必填，列表标识的名称（必须是预先注册好的 bucket name）。
  StormyListStorage(this.listName)
    : _accessor = StormyStorage.instance.bucket(listName);

  /// 内部工具：生成唯一 ID
  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
  }

  // ================= 增 =================

  /// 将单个元素入库，内部将自动分配唯一 ID
  /// 返回分配生成的唯一 ID，便于后续修改或删除
  Future<String> add(T item, {Duration? expiresIn}) async {
    final id = _generateId();
    await _accessor.set(id, item, expiresIn: expiresIn);
    return id;
  }

  /// 批量将元素入库，并返回各个元素分配的唯一 ID 列表
  Future<List<String>> addAll(List<T> items, {Duration? expiresIn}) async {
    final ids = <String>[];
    for (final item in items) {
      ids.add(await add(item, expiresIn: expiresIn));
    }
    return ids;
  }

  /// 以给定的自定义 ID 保存或覆盖元素
  Future<void> put(String id, T item, {Duration? expiresIn}) async {
    await _accessor.set(id, item, expiresIn: expiresIn);
  }

  // ================= 删 =================

  /// 删除指定 ID 的列表项
  Future<void> remove(String id) async {
    await _accessor.remove(id);
  }

  /// 批量删除指定 ID 的多个列表项
  Future<void> removeMany(List<String> ids) async {
    await _accessor.removeMany(ids);
  }

  /// 清空该列表（也就是整个 bucket）下的所有缓存元素
  Future<void> clear() async {
    await _accessor.clear();
  }

  // ================= 改 =================

  /// 更新指定的列表项（行为上等同于 put），提供了语义化方法名
  Future<void> update(String id, T item, {Duration? expiresIn}) async {
    await put(id, item, expiresIn: expiresIn);
  }

  // ================= 查 =================

  /// 根据 ID 获取单个列表项
  T? get(String id, {T Function(dynamic)? decoder}) {
    return _accessor.get<T>(id, decoder: decoder);
  }

  /// 获取所有分配了的内部 ID 列表
  List<String> getIds({bool excludeExpired = true}) {
    return _accessor
        .getKeys(excludeExpired: excludeExpired)
        .whereType<String>()
        .toList();
  }

  /// 获取该列表存放的所有元素
  List<T> getAll({T Function(dynamic)? decoder, bool excludeExpired = true}) {
    return _accessor.getValues<T>(
      decoder: decoder,
      excludeExpired: excludeExpired,
    );
  }

  /// 对该列表进行查询、筛选支持以及排序支持
  /// [filter] 提供保留符合条件项的测试方法
  /// [sort] 提供两个项比对的排序方法
  List<T> query({
    bool Function(T)? filter,
    int Function(T a, T b)? sort,
    T Function(dynamic)? decoder,
    bool excludeExpired = true,
  }) {
    var rawList = getAll(decoder: decoder, excludeExpired: excludeExpired);

    if (filter != null) {
      rawList = rawList.where(filter).toList();
    }

    if (sort != null) {
      rawList.sort(sort);
    }

    return rawList;
  }
}
