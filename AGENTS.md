# Repository Guidelines

## 项目结构与模块职责

本仓库使用 Dart Pub workspace 与 Melos 管理九个 Flutter/Dart 包，配置位于根目录 `pubspec.yaml`：

- `packages/stormy_core/`：网络、存储、日志、预加载与通用工具。
- `packages/stormy_platform/`：设备、图片、文件与原生权限，依赖 core。
- `packages/stormy_ui/`：应用根组件、主题、弹窗和 Widgets，依赖 core/platform/i18n。
- `packages/stormy_i18n_generator/`：CLI、解析与生成，作为宿主 dev_dependency。
- `packages/stormy_kit/`：配置、路由、网络、存储、主题和通用 UI。
- `packages/stormy_i18n/`：运行期语言状态管理。
- `packages/stormy_store_pay/`：Apple App Store 与 Google Play 内购。
- `packages/stormy_china_pay/`：微信、支付宝支付集成。
- `packages/stormy_gromore/`：Android/iOS GroMore 聚合广告原生插件。

各包源码位于 `lib/`，测试位于 `test/`。`stormy_kit`、`stormy_i18n` 和 `stormy_store_pay` 包含完整 `example/` 应用；`stormy_gromore/example/` 提供需宿主运行的 Dart 示例。示例资源位于各自的 `assets/` 或平台资源目录，翻译文件位于 `example/lib/l10n/`。新增临时文件放 `temp/`，辅助脚本放 `Script/`。各包接入流程见 [使用指南](docs/USAGE.md)。

## 构建、测试与本地开发

以 `.fvmrc` 的 Flutter **3.47.1** 和根 `pubspec.yaml` 的 Dart **>=3.13.0 <4.0.0** 为准；README 的旧版本要求不适用。先配置 FVM 并安装指定 SDK。

| 执行目录 | 命令 | 用途 |
| --- | --- | --- |
| 根目录 | `fvm flutter pub get` | 解析 workspace 依赖，安装 Melos |
| 根目录 | `fvm dart run melos bootstrap` | 初始化 Melos 工作区 |
| 修改的包 | `fvm dart format lib test` | 格式化源码与测试；CLI 变更另加 `bin` |
| 修改的包 | `fvm flutter analyze` | 执行静态检查 |
| 修改的包 | `fvm flutter test` | 运行该包测试 |
| `packages/stormy_kit/example` | `fvm flutter pub get` | 安装示例依赖 |
| 同上 | `fvm flutter run` | 在已连接设备或模拟器运行 |
| 同上 | `fvm flutter build apk --debug` | 构建 Android 调试包，需要 Android SDK |

## 编码风格与命名

使用 Dart 标准格式和两空格缩进，以 `dart format` 输出为准。文件采用 `snake_case.dart`，类型采用 `UpperCamelCase`，成员采用 `lowerCamelCase`，私有成员加 `_`。遵循所在包的 `analysis_options.yaml`；已有配置使用 `flutter_lints`。

公共 API 从 `lib/stormy_*.dart` 导出。业务功能优先复用对应 Stormy 包，避免重复接入底层 SDK；仅格式化本次修改涉及的文件。

## 测试规范

使用 `flutter_test` 的 `test`、`group` 和 `testWidgets`，文件命名为 `*_test.dart`。行为变更应覆盖正常路径、错误处理和相关回归场景；可参考 `packages/stormy_kit/test/network_client_stream_test.dart` 的本地 HTTP 测试。

在对应包运行 `fvm flutter test test/network_client_stream_test.dart` 可定位单个测试文件。仓库未配置覆盖率门槛；需要报告时运行 `fvm flutter test --coverage`。支付平台行为还应使用 StoreKit 或商店沙盒验证，并记录未验证的平台。

## Commit 与 Pull Request

沿用近期历史的 `feat:`、`fix:`、`refactor:`、`chore:` 前缀，例如 `fix: make tagged request cancellation deterministic`。每次提交聚焦一个改动。

PR 应说明涉及的包、变更原因、行为差异及实际运行的验证命令；有关联 issue 时附链接，UI 变更附截图。公共 API 变更同步更新对应 README 和 CHANGELOG，并明确兼容性影响。

## 配置与安全

保留根配置中有说明的依赖 override，调整前验证兼容性。不要提交真实密钥、支付凭证或签名材料；内购流程必须保留后端 `verifier` 校验。国际化修改应更新源定义，再在配置所在目录运行 `fvm dart run stormy_i18n_generator gen`，避免直接修改生成文件。
