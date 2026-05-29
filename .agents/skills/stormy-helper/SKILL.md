---
name: stormy-helper
description: Guidelines and best practices for developing and maintaining the stormy monorepo, specifically leveraging local packages including stormy_kit, stormy_i18n, stormy_store_pay, and stormy_china_pay. Always use this skill when handling user requests related to networking, local storage, persistent caches, global custom dialogs/toast, pull-to-refresh widgets, multi-language localization (i18n), WeChat/Alipay SDK integration, or double-platform in-app purchases (IAP) in Google Play and Apple App Store. Make sure to use this skill whenever the user mentions multi-language, localized texts, wechat pay, alipay, shared images, App Store IAP, Google Play billing, Dio request setups, Hive cache databases, or global error popups, even if they don't explicitly name the local packages.
---

# Stormy Helper

This skill helps developers and AI coding assistants leverage the local foundation packages within the `stormy` monorepo (`packages/`). These packages encapsulate core infrastructure capabilities like network, caching, popup dialogs, localizations, payment processing, and in-app purchases.

---

## 1. Local Packages Overview & Scope

The stormy codebase follows a monorepo structure. Core infrastructure is split into four local Dart packages inside `packages/`:

| Package Name | Core Responsibilities | Target Reference File |
| :--- | :--- | :--- |
| `stormy_kit` | Core config, Network (Dio), Expiration & Pagination Storage (Hive), Global Dialogs, Downstream Exports. | [references/stormy_kit.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit.md) |
| `stormy_i18n` | Pure Dart strong-typed translation config, dynamic CLI ARB compiler & code generator. | [references/stormy_i18n.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_i18n.md) |
| `stormy_store_pay` | Google Play and Apple App Store unified in-app purchase (IAP) and subscription SDK. | [references/stormy_store_pay.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_store_pay.md) |
| `stormy_china_pay` | WeChat & Alipay unified Chinese mainland payment SDK, image sharing, and SSO login. | [references/stormy_china_pay.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_china_pay.md) |

---

## 2. Progressive Disclosure Guidance

To optimize context token usage, do NOT read all documentation files. Follow this routing matrix to load only the specific reference file needed for your current task using the `view_file` tool:

*   **Task: App initialization, core settings, chain config builder, and using consolidated third-party dependencies (Riverpod, ScreenUtil, GoRouter, Hooks, etc.):**
    👉 Read [references/stormy_kit.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit.md)
*   **Task: Network requests, REST APIs, HTTP config, Authorization token setup, Talker logger, raw response model parsing:**
    👉 Read [references/stormy_kit_network.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_network.md)
*   **Task: Key-Value storage, Hive Box isolation, expiry (TTL) cache, page-splitting lists & search histories:**
    👉 Read [references/stormy_kit_storage.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_storage.md)
*   **Task: Context-free Dialogs, Alerts, Confirmation sheets (destructive styles), global Loading HUDs:**
    👉 Read [references/stormy_kit_dialog.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_dialog.md)
*   **Task: Custom pull-to-refresh controllers, branding style headers/footers for scroll lists:**
    👉 Read [references/stormy_kit_refresh.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_refresh.md)
*   **Task: Creating new translations, localizing texts, fixing multilingual assets, executing i18n CLIs, binding locale settings with SharedPreferences/Hive:**
    👉 Read [references/stormy_i18n.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_i18n.md)
*   **Task: Google Play Billing, App Store IAP payments, restore subscriptions, promo codes, Apple Sandbox testing, custom offers:**
    👉 Read [references/stormy_store_pay.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_store_pay.md)
*   **Task: WeChat Pay, Alipay payments, WeChat MiniProgram redirects, WeChat signature pay signing, media sharing, WeChat SSO login:**
    👉 Read [references/stormy_china_pay.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_china_pay.md)

---

## 3. Mandatory Development Safeguards

You MUST strictly comply with these development safeguards under all circumstances:

1.  **Do Not Bypass Local Packages:**
    Never add native flutter integration packages like `dio`, `hive_ce`, `fluwx`, `tobias`, `in_app_purchase`, `easy_refresh`, `flutter_smart_dialog` to custom sub-packages or business features' `pubspec.yaml` directly. Always import `package:stormy_kit/stormy_kit.dart` or resolve additions through the core package.
2.  **NavigatorKey Requirement:**
    Always bind `StormyDialog.navigatorKey` in `MaterialApp`'s setup to prevent context-free dialog drawing failures.
3.  **No dummy verifiers:**
    Never bypass purchase verification under `stormy_store_pay`. Real backend verification flows must be configured using the `verifier` callbacks.
4.  **Toast usage:**
    Prefer `StormyDialog.instance.showToast` over default Flutter Snackbars to prevent layout overlap with keyboards and route blockage.

---

## 4. Bundled Helper Scripts

The skill bundles automation scripts inside `scripts/` to handle routine commands and scans:

*   **Multilingual generation and watching (`i18n_tool.py`)**:
    Automatically searches and resolves which project/package holds the `stormy_i18n` dependencies and runs corresponding compile operations.
    ```bash
    # Generate ARBs and Dart localizations:
    python3 scripts/i18n_tool.py gen

    # Watch source folders and auto-regenerate on save:
    python3 scripts/i18n_tool.py watch
    ```

*   **Architecture compliance checking (`check_dependencies.py`)**:
    Scans the monorepo to ensure business packages do not bypass `stormy_kit` exports, and ensures the global `navigatorKey` is correctly bound to material apps:
    ```bash
    python3 scripts/check_dependencies.py
    ```


