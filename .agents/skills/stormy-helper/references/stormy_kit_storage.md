# Stormy Kit - 持久化存储模块 (`StormyStorage`) 开发指南

`StormyStorage` 基于 `hive_ce` 构建，封装了类型安全的存取接口。针对移动端业务场景，它提供了**带过期时间的时效性缓存**以及针对复杂历史记录的**列表分页 API**。

---

## 1. 初始化配置

在应用启动时，可通过链式构造完成存储 Box 的初始化：

```dart
await stormy()
    .storage(StormyStorageConfig.defaultConfig(
      boxName: 'app_main_box', // 指定存储域，自动隔离不同 App 实例的数据
    ))
    .build();
```

---

## 2. 基础类型安全读写

`StormyStorage` 会自动转换存取类型，避免手动强制转换 `as` 导致运行时崩溃。

```dart
final storage = StormyStorage.instance;

// 1. 写入
await storage.setString('token', 'abc-123');
await storage.setBool('is_dark_mode', true);
await storage.setInt('launch_count', 42);
await storage.setJson('user_profile', {'name': 'Alice', 'role': 'admin'});

// 2. 读取 (读取时支持默认缺省值)
String? token = storage.getString('token');
bool isDarkMode = storage.getBool('is_dark_mode') ?? false;
int launchCount = storage.getInt('launch_count') ?? 0;
Map<String, dynamic>? profile = storage.getJson('user_profile');
```

---

## 3. 时效性缓存 (TTL Expiry Cache)

适合缓存弱一致性数据（例如首页横幅列表、静态配置项）。它会自动在数据结构中包装时间戳。如果在读取时判定已超过生命周期，则会自动清除并返回 `null`。

```dart
// 缓存首页广告 1 小时
await storage.setJsonWithExpiry(
  'home_banners',
  {'banners': [...]},
  const Duration(hours: 1),
);

// 获取缓存 (如果时间没超过 1 小时，返回 Map 数据；如果超过 1 小时，返回 null 并在后台自动删除 key)
final bannerData = storage.getJson('home_banners');
```

---

## 4. 列表（List）存储与分页 API

专门为了解决“搜索历史记录”、“浏览足迹”等功能在频繁写入、读取和分页截取时的复杂度而设计。

### 4.1 列表中元素的增删

```dart
// 1. 向列表末尾追加一条数据
await storage.appendToList<String>('search_history', 'Flutter SDK');

// 2. 从列表中移除指定位置的元素
await storage.removeFromList<String>('search_history', 0); // 移除索引为 0 的元素
```

### 4.2 列表的分页读取

```dart
final String listKey = 'search_history';
final int pageSize = 10;

// 1. 获取分页信息数据统计
final PageInfo pageInfo = storage.getListPageInfo(listKey, pageSize: pageSize);
print('列表总数: ${pageInfo.totalCount}');
print('是否还有下一页: ${pageInfo.hasNextPage}');

// 2. 提取指定页码的数据切片 (注意：页码 page 从 1 开始)
final List<String> pageItems = storage.getListPage<String>(
  listKey,
  page: 1,
  pageSize: pageSize,
);
```

---

## 5. 多 Box 隔离

当您的 App 拥有某些特殊隔离场景（如多账号数据相互隔离，且登出时直接清空当前账号 Box，而不影响全局 Box），可以直接通过 `Hive` 实现自定义 Box 绑定，不过通常情况下使用 `StormyStorage.instance` 提供的默认隔离空间已足够满足 90% 的业务场景。
