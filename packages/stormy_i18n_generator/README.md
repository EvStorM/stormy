# stormy_i18n_generator

开发期 CLI、Dart 解析、ARB 与脚手架生成。宿主 dev_dependencies 添加本包，在配置目录执行 `fvm dart run stormy_i18n_generator init`、`gen` 或 `watch`。原 YAML 名和输出路径不变，失败返回非零退出码，watch 串行合并变更。可用 `--flutter=/path/to/flutter` 指定 gen-l10n SDK。

Flutter 3.47.1 / Dart >=3.13。见 [使用指南](../../docs/USAGE.md) 与 [迁移说明](../../docs/MIGRATION.md)。
