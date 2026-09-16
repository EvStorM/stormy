## Unreleased

- Android/iOS 拆分注册分发、初始化隐私、广告参数/预加载、全屏生命周期、平台视图和事件模块。
- iOS 奖励终态与宿主状态可独立测试，销毁时释放计时器、监视器及广告；SDK、Channel 与奖励保留策略不变。

## Unreleased

- Integrate into the Stormy Dart Pub workspace with the repository's Dart 3.13 baseline.
- Document standalone host setup and link the workspace usage guide.

## 0.1.0

- Add Android and iOS GroMore initialization with Flutter-owned privacy options.
- Add splash, rewarded video, and full-screen interstitial load/show lifecycles.
- Add Banner, template Feed, and template Draw platform views.
- Add structured events, errors, reward results, and shown eCPM metadata.
- Add GroMore first-precache support for splash, rewarded, full-screen
  interstitial, and feed ads with Wi-Fi-only or any-network gating.
- Add configurable post-close rewarded callback retention on Android and iOS.
- Gate Android full-screen presentation on a resumed, usable host Activity.
- Document optional host-managed WeChat setup without bundling an unused
  OpenSDK dependency or package-visibility declaration.
