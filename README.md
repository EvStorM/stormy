# Stormy Kit Workspace

English | [中文版](#中文版)

Stormy is a comprehensive, production-ready Flutter development framework designed to accelerate app building by providing unified configuration, SDK registration, module management, and a rich set of pre-configured tools.

This repository is managed as a monorepo using [Melos](https://melos.invertase.dev/).

See the [workspace and package usage guide](docs/USAGE.md) for all nine packages: dependencies, initialization, examples, events, and platform setup.

## 📦 Packages

The workspace is divided into several specialized packages:

| Package | Description |
| :--- | :--- |
| [`stormy_core`](./packages/stormy_core) | Network, storage, logging and preload. |
| [`stormy_platform`](./packages/stormy_platform) | Device, files, images and native permissions. |
| [`stormy_ui`](./packages/stormy_ui) | App, theme, dialogs and widgets. |
| [`stormy_i18n_generator`](./packages/stormy_i18n_generator) | Development-only CLI and generation. |
| [`stormy_kit`](./packages/stormy_kit) | The core development framework. Provides unified configuration, routing (GoRouter), networking (Dio), local storage (Hive), UI components, state management (Riverpod), and more. |
| [`stormy_i18n`](./packages/stormy_i18n) | Internationalization (i18n) support module. |
| [`stormy_china_pay`](./packages/stormy_china_pay) | Payment module tailored for the Chinese market (e.g., WeChat Pay, Alipay). *(wip)* |
| [`stormy_store_pay`](./packages/stormy_store_pay) | In-app purchase module for App Store and Google Play. *(wip)* |
| [`stormy_gromore`](./packages/stormy_gromore) | Native Android/iOS GroMore mediation: splash, rewarded, interstitial, banner, feed, and Draw ads. |

## 🚀 Features (Stormy Kit)

*   **Robust Architecture**: Built on top of Riverpod for predictable and scalable state management.
*   **Networking**: Integrated `dio` with robust interceptors and logging.
*   **Storage**: High-performance local storage powered by `hive_ce`.
*   **Theming**: Adaptive theming and screen adaptation support (`flutter_screenutil`).
*   **Ready-to-use UI Components**: Easy refresh (`easy_refresh`), smart dialogs (`flutter_smart_dialog`), loading animations, and adaptive layouts.
*   **Routing**: Pre-configured navigation using `go_router`.
*   **Utilities**: Permission handling, connectivity checks, device info, image picking, and more.

## 🛠 Getting Started

### Prerequisites

*   Flutter SDK `3.47.1`（FVM / `.fvmrc`）
*   Dart SDK `>=3.13.0 <4.0.0`
*   Melos is a workspace development dependency; install from the repository root:

```bash
fvm flutter pub get
```

### Installation

1. Clone the repository:
```bash
git clone https://github.com/EvStorM/stormy.git
cd stormy
```

2. Bootstrap the workspace pulling all dependencies:
```bash
fvm flutter pub get
fvm dart run melos bootstrap
```

3. Run the example app:
```bash
cd packages/stormy_kit/example
fvm flutter run
```

---

<h2 id="中文版">中文版</h2>

Stormy 是一个全面、生产级别的 Flutter 开发框架，提供统一配置、SDK注册、模块管理以及丰富的预配置工具，旨在加速应用的开发过程。

本项目使用 [Melos](https://melos.invertase.dev/) 作为 monorepo（单体仓库）进行管理。

完整接入流程见 [项目结构与各包使用指南](docs/USAGE.md)，包含九个包的依赖关系、初始化顺序、调用示例、事件处理和平台配置。GroMore 按需接入，不随 `stormy_kit` 自动引入。

## 📦 模块 (Packages)

工作区包含以下专业化子包：

| 包名 | 描述 |
| :--- | :--- |
| [`stormy_core`](./packages/stormy_core) | Network, storage, logging and preload. |
| [`stormy_platform`](./packages/stormy_platform) | Device, files, images and native permissions. |
| [`stormy_ui`](./packages/stormy_ui) | App, theme, dialogs and widgets. |
| [`stormy_i18n_generator`](./packages/stormy_i18n_generator) | Development-only CLI and generation. |
| [`stormy_kit`](./packages/stormy_kit) | 核心开发框架。提供统一配置、路由(GoRouter)、网络(Dio)、本地存储(Hive)、UI组件、状态管理(Riverpod)等。 |
| [`stormy_i18n`](./packages/stormy_i18n) | 国际化 (i18n) 支持模块。 |
| [`stormy_china_pay`](./packages/stormy_china_pay) | 针对中国市场的支付模块（如微信支付、支付宝等）。*(开发中)* |
| [`stormy_store_pay`](./packages/stormy_store_pay) | 针对 App Store 和 Google Play 的应用内购买模块。*(开发中)* |
| [`stormy_gromore`](./packages/stormy_gromore) | Android/iOS GroMore 原生聚合广告：开屏、激励视频、插全屏、Banner、Feed 和 Draw。 |

## 🚀 核心特性 (Stormy Kit)

*   **稳健的架构**：基于 `Riverpod` 构建可预测且易于扩展的状态管理方案。
*   **网络请求**：集成 `dio`，内置可靠的拦截器和日志记录功能。
*   **本地存储**：使用 `hive_ce` 提供高性能的本地数据存储。
*   **主题与适配**：支持自适应主题 (`adaptive_theme`) 和屏幕分辨率适配 (`flutter_screenutil`)。
*   **开箱即用的 UI 组件**：集成下拉刷新 (`easy_refresh`)、智能弹窗 (`flutter_smart_dialog`)、加载动画和响应式布局。
*   **路由管理**：基于 `go_router` 的预配置导航方案。
*   **实用工具**：包括权限管理、网络状态检查、设备信息获取、图片选择等。

## 🛠 快速上手

### 环境要求

*   Flutter SDK `3.47.1`（FVM / `.fvmrc`）
*   Dart SDK `>=3.13.0 <4.0.0`
*   Melos 已声明为工作区开发依赖，在仓库根目录安装：

```bash
fvm flutter pub get
```

### 安装与运行

1. 克隆仓库：
```bash
git clone https://github.com/EvStorM/stormy.git
cd stormy
```

2. 初始化工作区并拉取所有依赖：
```bash
fvm flutter pub get
fvm dart run melos bootstrap
```

3. 运行示例应用：
```bash
cd packages/stormy_kit/example
fvm flutter run
```

## 📄 License协议

The MIT License (MIT)
