# Stormy Kit - 网络模块 (`StormyNetwork`) 开发指南

`StormyNetwork` 是对 `Dio` 的强力封装，集成了类型安全响应解析器 (`Parser`)、全局 Token 自动注入拦截器以及基于 `Talker` 的统一日志记录器。

---

## 1. 核心配置与实例化

网络单例通过 `StormyNetwork.instance` 获取，但必须提前在 `stormy()` 链式构建中注入 `StormyNetworkConfig`：

```dart
await stormy()
    .network(StormyNetworkConfig(
      baseUrl: 'https://api.yourdomain.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      enableLogging: true, // 开启后会在控制台打印完整的 cURL 请求与回包 JSON
    ))
    .build();
```

---

## 2. 基础请求 API

`StormyNetwork` 支持统一的 `get`、`post`、`put`、`delete` 请求。

### GET 请求 (包含 Query 参数拼接)

```dart
// GET /api/user/info?id=123
final Map<String, dynamic>? data = await StormyNetwork.instance.get(
  '/api/user/info',
  query: {'id': '123'},
);
```

### POST 请求 (包含 JSON 请求体)

```dart
final response = await StormyNetwork.instance.post(
  '/api/user/update',
  data: {
    'nickname': 'Antigravity',
    'status': 'active',
  },
);
```

---

## 3. 强类型解析器 (`Parser`)

为了保障业务侧的响应类型安全，避免在页面级手动编写 `Map` 取值代码，所有请求方法都支持传入一个 `parser` 反序列化回调。它将在后台收到原始 JSON Map 的第一时间在最底层完成转换。

### 示例 1：解析单个 Model

```dart
final UserModel user = await StormyNetwork.instance.get<UserModel>(
  '/api/user/profile',
  parser: (json) => UserModel.fromJson(json as Map<String, dynamic>),
);
print('用户名: ${user.name}');
```

### 示例 2：解析 Model 列表

```dart
final List<UserModel> users = await StormyNetwork.instance.get<List<UserModel>>(
  '/api/users',
  parser: (json) {
    final list = json as List;
    return list.map((item) => UserModel.fromJson(item as Map<String, dynamic>)).toList();
  },
);
```

---

## 4. 认证 Token 会话接管

`StormyNetwork` 内部拦截器在检测到有效 Token 时，会自动往 Header 注入 `Authorization: Bearer <token>`。

```dart
// 1. 登录成功后写入 Token
StormyNetwork.instance.setAuthToken('eyJhbGciOiJIUzI1Ni...');

// 2. 写入后，接下来的所有接口请求都将自动携带授权请求头

// 3. 用户登出或 Token 失效报错时清空
StormyNetwork.instance.clearAuthToken();
```

---

## 5. 日志与调试

当 `enableLogging` 设为 `true` 时，底层通过 `talker_dio_logger` 自动将所有的 HTTP 请求进行染色打印。
开发者可在控制台看到请求路径、Headers、Payload 以及 Response JSON 报文，无需额外部署 Charles 抓包工具。
