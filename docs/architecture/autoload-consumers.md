# Autoload 消费者与退出策略（Phase 0 历史基线）

> 本文记录 Phase 0–4 的迁移输入与中间消费者。当前 7 项 Autoload 及其运行时边界以 [current-runtime.md](current-runtime.md) 为准；下文的旧路径、Event、RunController 和数量不构成当前实现。

## 当前 9 个 Autoload

`project.godot:18-28` 当前注册 9 项。下表列生产代码中的代表性直接消费；实施迁移时仍须用 `rg` 重新扫描完整调用点。

| Autoload | 当前职责与代表性消费者 | 最终策略 |
| --- | --- | --- |
| `Event` | 全局玩法信号总线；完整映射见下节。 | **Phase 4 退役**，消费者归零后删除注册和 `Main/event.gd`。 |
| `Localization` | `Items/slot.gd:96`、`Shop/shop.gd:542`、`UI/node_choice_panel.gd:129`、`UI/draft_reward_panel.gd:514`、`UI/inventory_panel.gd:391`、`UI/pause_panel.gd:265`、`UI/run_event_panel.gd:100`、`UI/run_failure_panel.gd:41`。 | 保留为应用级服务，最终归 `Core/localization/`。 |
| `EffectManager` | Main 注入 Loadout/Progression；Enemy、PoisonDebuff 查询：`Main/main.gd:186-190`、`Enemies/enemy.gd:286`、`Buffs/buffs/poison_debuff.gd:87`。 | Phase 5 迁为 run-scoped effect service。 |
| `EffectRegistry` | 当前未发现生产脚本按 Autoload 名直接查询；实现为 `Items/effect_registry.gd`。 | Phase 5 与重复映射收敛后删除。 |
| `GameExecutor` | 未发现玩法生产消费者；Hastur 开发工具注册。 | 开发期保留，不进入领域依赖。 |
| `StatSystem` | Main/RunController、Enemy、Marble/MarbleChain、SkillController、Buff/Effect 脚本均有 `/root` 查询。 | 后续迁为 RunScope 显式持有的 scoped stats 服务。 |
| `BuffManager` | 当前未发现其他生产脚本按 Autoload 名直接查询；自身管理玩家 Buff 并订阅 Event。 | Phase 4 只迁移信号来源；Phase 5 再做 service/registry 重构。 |
| `BuffRegistry` | `BuffManager` 查询 `/root/BuffRegistry`，缺失时回退 `new()`（`Buffs/buff_manager.gd:200-204`）。 | Phase 5 收敛为唯一 catalog 后删除。 |
| `FloatDamageTextPool` | `Enemies/enemy.gd:293`、`Run/run_controller.gd:969`。 | 后续迁为场景作用域 Combat presentation 依赖。 |

## Event 当前活动 production 接线

`Main/event.gd` 定义 8 个信号。当前接线事实如下：

| Event signal | 当前生产者 | 当前消费者 | Phase 4 目标 |
| --- | --- | --- | --- |
| `marble_fell(marble)` | `Main/kill_zone.gd:16-18` | `Main/main.gd:43-45`；旧 `RunController` 在 `Run/run_controller.gd:1077-1084` | KillZone raw typed source 经 BattleSession instance-ID 去重；Main 链重建与 RunFlow health 只消费 accepted session signal。 |
| `enemy_killed(enemy)` | `Enemies/enemy.gd:300-310`；KillZone 对敌人也会发射（`Main/kill_zone.gd:23-25`） | `BattleSpawner`（`Run/battle_spawner.gd:14-19`）；`BuffManager`（`Buffs/buff_manager.gd:207-214`） | P4-A 原子增加 `class_name Enemy`/`defeat`/`defeated` 和 Spawner 所有的唯一 typed bridge，同时删除 Enemy direct emit；P4-B 再让 KillZone 调 `defeat` 并删其 direct emit；P4-C/D 依次迁 Spawner/BuffManager 后删 bridge。 |
| `wave_completed(wave)` | 当前静态扫描未发现生产 emitter | `BuffManager`（`Buffs/buff_manager.gd:212-226`） | P4-D 删除 Event signal、连接、`_on_wave_completed()` 与 `on_wave_completed` dispatch seam；不映射为 battle completion。 |
| `chain_collision(collider, collision_type)` | `Marbles/marble_chain.gd:303-314` | `BuffManager`（`Buffs/buff_manager.gd:215-218`） | MarbleChain 直接 typed signal → BuffManager。 |
| `run_node_completed(node_kind)` | 旧 `RunController` 经 `Main._connect_run_signal()` 转发 | 当前静态扫描未发现除 Event 外的生产消费者 | 若无真实消费者则直接删除 bridge；不为兼容保留空总线。 |
| `battle_started(group_id)` | 旧 `RunController` 经 Main 转发 | 当前静态扫描未发现 Event 消费者；SkillSlot 另直接连旧 controller | Main composition 改接 `RunFlowController.battle_started(token, plan)`。 |
| `battle_completed(group_id)` | 旧 `RunController` 经 Main 转发 | `SkillController`（`Skills/skill_controller.gd:318-325`） | SkillController 显式配置并直连 RunFlowController typed signal。 |
| `run_completed` | 旧 `RunController` 经 Main 转发 | `SkillController`（`Skills/skill_controller.gd:326-329`） | SkillController 直连 RunFlowController；删除 Main bridge。 |

上表只统计 Main 当前实际启动的旧 `RunController` 路径。HEAD `592c7db` 尚不存在 typed flow → Event lifecycle bridge；该 bridge 只允许在 Phase 3 production cutover 中按 [Phase 4 方案](phase4-plan.md)的专用签名 adapter 创建，并必须在 Phase 4 SkillController typed 迁移时删除。

## 已提交但 production-unreachable 的 BattleGateway legacy capability

`Run/battle_gateway.gd` 已提交可选 `legacy_event_source` 参数；配置后会订阅其 `marble_fell`，把无 token 的旧 signal 绑定为带当前 token 的 `BattleGateway.marble_fell`（`Run/battle_gateway.gd:31-64`、`:213-235`）。但 Main 当前没有创建或 configure `BattleGateway`/`RunFlowController`，所以这只是 **committed capability，不是当前活动 Event consumer**。

它仍属于最终删除审计：Phase 3 cutover 可暂时传入 Event 维持新 flow 的 marble 输入；Phase 4 `P4-C` 在 BattleSession/Gateway 接管 accepted marble 后必须删除参数、字段、Callable、连接和 `tests/Run/test_battle_gateway.gd` 中的 legacy fake。文档和静态 consumer 计数必须始终把“活动接线”与“不可达 capability”分开。

## 已退役历史项

`Shop` 与 `Inventory` 曾是 Autoload，但已在 Phase 2 删除，当前 `project.godot` 没有这两个注册项：

- `Shop` 的领域职责已迁到 scoped `RunWallet`、Commerce Session 和 Shop/DevilShop presentation；
- `Inventory` 的持有物、容量、弹珠顺序与技能槽已迁到 run-scoped `Loadout`/`ItemProgression`；旧 `Inventory/inventory.gd` 已删除。

它们只能作为迁移历史出现，不得继续列入“当前 Autoload”或给出已删除脚本的当前消费者行号。

## 退出规则

1. 新代码不得假定 Autoload 名是编译期全局；迁移旧调用时从 `/root` 安全解析，最终通过显式 configure/typed 引用消除查询。
2. Phase 4 只处理 Event 信号拓扑与 BattleSession；不得提前进入 Effect/Buff registry/service 重构。
3. Event 迁移按 [phase4-plan.md](phase4-plan.md) 的 P4-A～P4-E 执行：P4-A 把真实 Enemy typed surface、唯一 Enemy→Event bridge 与 Session/Spawner registration 作为不可拆 checkpoint；P4-B 只迁 KillZone/MarbleChain source；Session/Gateway 接管完成后才迁其余消费者。每个 checkpoint 必须只有一条活动 production completion path。
4. 不引入全局 Service Locator，不让 BattleSession 持有 Loadout/Reward/RunState 等不属于战斗生命周期的状态。
5. P4-D 必须先删除没有生产 emitter 的 `wave_completed` 幽灵契约；生产 `.gd` 中 `wave_completed` 与 `on_wave_completed` 均归零，不得隐式映射成 battle completion。删除 Event Autoload 前还必须完成 Main、Enemy、KillZone、MarbleChain、BattleSpawner、BattleGateway、RunBattleFlow、RunFlowController、SkillController、BuffManager 的接线验收，并删除 Phase 3 lifecycle bridge、Phase 4 source bridges 与 Gateway legacy capability；详见 [phase4-plan.md](phase4-plan.md)。
