# Content ownership（Phase 1）

Phase 1 只建立内容定义的逻辑所有权边界，不移动现有 `Items/item.gd`、`.tres` 资源或任何场景资源。Commerce 可以读取当前 `Item` Resource，但不取得战斗行为的所有权。

Content 负责：

- 不可变的物品定义数据；
- 跨存档、报价与系统边界使用的稳定 ID；
- 弹珠、遗物、技能等内容类别。

效果执行、属性修改、技能运行时和其他行为映射继续由 Combat 侧负责。后续迁移资源时必须保持稳定 ID 与类别语义不变，避免 Commerce、存档和 Combat 对同一内容产生不同身份解释。
