# Stormy Kit Workspace

English | [中文版](#中文版)

Stormy is a comprehensive, production-ready Flutter development framework designed to accelerate app building by providing unified configuration, SDK registration, module management, and a rich set of pre-configured tools.

This repository is managed as a monorepo using [Melos](https://melos.invertase.dev/).

## 📦 Packages

The workspace is divided into several specialized packages:

| Package | Description |
| :--- | :--- |
| [`stormy_kit`](./packages/stormy_kit) | The core development framework. Provides unified configuration, routing (GoRouter), networking (Dio), local storage (Hive), UI components, state management (Riverpod), and more. |
| [`stormy_i18n`](./packages/stormy_i18n) | Internationalization (i18n) support module. |
| [`stormy_china_pay`](./packages/stormy_china_pay) | Payment module tailored for the Chinese market (e.g., WeChat Pay, Alipay). *(wip)* |
| [`stormy_store_pay`](./packages/stormy_store_pay) | In-app purchase module for App Store and Google Play. *(wip)* |

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

*   Flutter SDK `>=3.10.3`
*   Dart SDK `>=3.10.3 <4.0.0`
*   [Melos](https://melos.invertase.dev/) installed globally:

```bash
dart pub global activate melos
```

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/stormy.git
cd stormy
```

2. Bootstrap the workspace pulling all dependencies:
```bash
melos bootstrap
```

3. Run the example app:
```bash
cd packages/stormy_kit/example
flutter run
```

---

<h2 id="中文版">中文版</h2>

Stormy 是一个全面、生产级别的 Flutter 开发框架，提供统一配置、SDK注册、模块管理以及丰富的预配置工具，旨在加速应用的开发过程。

本项目使用 [Melos](https://melos.invertase.dev/) 作为 monorepo（单体仓库）进行管理。

## 📦 模块 (Packages)

工作区包含以下专业化子包：

| 包名 | 描述 |
| :--- | :--- |
| [`stormy_kit`](./packages/stormy_kit) | 核心开发框架。提供统一配置、路由(GoRouter)、网络(Dio)、本地存储(Hive)、UI组件、状态管理(Riverpod)等。 |
| [`stormy_i18n`](./packages/stormy_i18n) | 国际化 (i18n) 支持模块。 |
| [`stormy_china_pay`](./packages/stormy_china_pay) | 针对中国市场的支付模块（如微信支付、支付宝等）。*(开发中)* |
| [`stormy_store_pay`](./packages/stormy_store_pay) | 针对 App Store 和 Google Play 的应用内购买模块。*(开发中)* |

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

*   Flutter SDK `>=3.10.3`
*   Dart SDK `>=3.10.3 <4.0.0`
*   全局安装 [Melos](https://melos.invertase.dev/)：

```bash
dart pub global activate melos
```

### 安装与运行

1. 克隆仓库：
```bash
git clone https://github.com/your-org/stormy.git
cd stormy
```

2. 初始化工作区并拉取所有依赖：
```bash
melos bootstrap
```

3. 运行示例应用：
```bash
cd packages/stormy_kit/example
flutter run
```

## 📄 License协议

The MIT License (MIT)
