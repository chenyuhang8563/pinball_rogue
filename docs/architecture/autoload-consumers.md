# Autoload 消费者与退出策略（Phase 0）

## 当前事实

`project.godot:18-30` 注册 11 个 Autoload。下表只统计生产代码代表性消费者；完整调用点在迁移时还须重新静态扫描。

| Autoload | 当前职责 | 生产消费者（代表性引用） | 已锁定最终策略 |
| --- | --- | --- | --- |
| `Event` | 全局玩法信号总线 | `Main/main.gd — _ready():34-37`、`_setup_run_flow():279-284`；`Main/kill_zone.gd:33`；`Run/battle_spawner.gd:91`；`Skills/skill_controller.gd:268`；`Enemies/enemy.gd:308`；`Marbles/marble_chain.gd:304`；`Buffs/buff_manager.gd:52` | **退役**。改为 `RunFlowController`、`BattleSession`、Loadout 等局部 typed signals；Phase 4 验收前 bridge 归零。 |
| `Localization` | locale 与翻译加载 | `Items/slot.gd:96`；`Shop/shop.gd:626`；`UI/node_choice_panel.gd:129`；`UI/draft_reward_panel.gd:479`；`UI/run_event_panel.gd:100`；`UI/run_failure_panel.gd:41`；`UI/pause_panel.gd:265`；`UI/inventory_panel.gd:347` | **保留**为应用级 Autoload，最终归 `Core/localization/`。 |
| `Shop` | 金币、报价、购买/出售和商店 UI | `Main/main.gd:175`；`Run/run_controller.gd:282`；`UI/draft_reward_panel.gd:206`；`Items/slot.gd:109`；`DevilShop/devil_shop.gd:130` | 迁为 scoped `RunWallet`、Commerce Session 与 presentation；Phase 2 删除 current-state adapter 和 Autoload。 |
| `Inventory` | 持有物品、容量与变更信号 | `Main/main.gd:195`；`Run/run_controller.gd:396`；`Shop/shop.gd:108`；`DevilShop/devil_shop.gd:154`；`UI/inventory_panel.gd:78`；`UI/draft_reward_panel.gd:184`；`Skills/skill_controller.gd:250`；`Effects/effect_manager.gd:103` | 迁为 run-scoped `Loadout`；Phase 2 删除 adapter、旧业务实现和 Autoload。 |
| `EffectManager` | 遗物效果同步与触发 | `Enemies/enemy.gd:286`；`Buffs/buffs/poison_debuff.gd:87` | 迁为 run-scoped `RelicEffectService`。 |
| `EffectRegistry` | 遗物 effect type 映射 | 未发现按 Autoload 名称直接消费；实现见 `Items/effect_registry.gd:3-21` | 与 EffectManager 的重复映射合并为唯一 run-scoped `RelicEffectCatalog`；由 `Game/Bootstrap` 构造、`RunScope` 持有并显式注入 `RelicEffectService`，删除 Autoload。 |
| `GameExecutor` | Hastur 开发期执行器 | 未发现玩法生产消费者；仅注册于 `project.godot:26` | **开发期保留**；不进入领域依赖。 |
| `StatSystem` | 属性实体、基础值和 modifier | `Run/run_controller.gd:1080`；`Run/marble_upgrade_system.gd:371`；`Shop/shop.gd:348`；`DevilShop/devil_shop.gd:334`；`Inventory/inventory.gd:190`；`Enemies/enemy.gd:279`；`Marbles/marble.gd:101`；`Buffs/buff_manager.gd:340` | 迁为 `RunScope` 显式持有的 scoped `Core/stats` 服务，删除 Autoload。 |
| `BuffManager` | 玩家 Buff、计时、叠层与 Event 订阅 | 未发现其他脚本按 Autoload 名称直接查询；自身订阅 `Event`（`Buffs/buff_manager.gd:48-54`） | 迁为 run-scoped `PlayerBuffService`。 |
| `BuffRegistry` | Buff ID 到定义的映射 | `Buffs/buff_manager.gd:200-204` | 迁为唯一 run-scoped `BuffCatalog`；由 `Game/Bootstrap` 构造、`RunScope` 持有并显式注入 `PlayerBuffService` 与单位 `BuffHost`，删除 Autoload。 |
| `FloatDamageTextPool` | 浮动伤害文本池 | `Enemies/enemy.gd:293`；`Run/run_controller.gd:968` | 迁为场景作用域 Combat presentation 依赖，删除 Autoload。 |

## 目标规则

- 新代码不得假定 Autoload 名称是编译期全局；迁移旧调用时先从 `/root` 安全解析。当前兼容 helper 示例为 `Main._get_autoload_node()`（`Main/main.gd:214-218`）。
- 最终仅保留 `Localization`，以及开发期 `GameExecutor`；其余局内可变服务均由 `RunScope` 显式持有和注入。
- 不引入全局 Service Locator，不以一个巨型状态对象替代多个 Autoload。
- adapter 只适配接口，不复制规则，并须在所属 Phase 内删除；Event 只允许单向 `新 signal → 旧 Event` bridge，且在消费者批次验收前删除。

## 已知风险

- “没有按 Autoload 名称直接查询”不等于没有隐式依赖；例如 `BuffManager` 自己会查询 `BuffRegistry` 并在缺失时回退 `new()`（`Buffs/buff_manager.gd:200-204`）。移除配置前必须以真实组合和 GUT 验证构造路径。
- `EffectRegistry`、`EffectManager` 与 Buff 两套 registry/service 目前职责交叠；Phase 5 必须先选定唯一 catalog，再迁移所有调用者，避免双触发。
- `GameExecutor` 是开发工具边界；不得因生产代码无消费者而在迁移中擅自删除。
