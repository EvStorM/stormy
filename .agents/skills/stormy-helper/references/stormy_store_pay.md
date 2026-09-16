# stormy_store_pay

实际 API 与接入见 [使用指南](../../../../../docs/USAGE.md)，生命周期与类型变更见 [迁移说明](../../../../../docs/MIGRATION.md)。

使用所属包主入口；下层包不反向依赖 kit。生成器为宿主 dev_dependency，命令为 `fvm dart run stormy_i18n_generator gen`。支付先订阅再初始化，必须后端验单，purchaseAndWait 先监听再购买。Toast 使用 SmartDialog.showToast；仅使用 StormyDialog 的宿主需要绑定其 navigatorKey。
