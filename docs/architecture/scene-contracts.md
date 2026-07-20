# 场景与面板契约（HEAD `592c7db`）

## Main 场景事实

`Main/main.tscn` 是启动场景。当前可审计的预置结构为：

| 路径 | 类型/作用 | 证据 |
| --- | --- | --- |
| `Main` | 根 `Node2D`，挂载 `main.gd` | `Main/main.tscn:22-24` |
| `Main/Marbles` | MarbleChain 的父节点 | `Main/main.tscn:26`、`Main/main.gd:15` |
| `Main/CanvasLayer` | 唯一预置 UI 展示层 | `Main/main.tscn:28`；`Main/main.gd:229-232` 找不到即装配失败 |
| `Main/CanvasLayer/BattleHealthHud` | 当前接收 `set_health`/`set_gold` 的现有 HUD | `Main/main.tscn:30-37`、`Main/main.gd:336-343`、`:387-389`、`:418-431` |
| `Main/CanvasLayer/PausePanel` | 暂停/恢复 UI | `Main/main.tscn:39-48`、`Main/main.gd:354-365` |
| `Main/CanvasLayer/SkillSlot` | Active skill 输入 adapter | `Main/main.tscn:54-61`、`Main/main.gd:297-318` |
| `Main/CanvasLayer/RunFailurePanel` | 发射 `restart_requested` | `Main/main.tscn:63-70`、`Main/main.gd:368-374`、`:403-410` |
| `Main/SkillController` | 技能运行时节点 | `Main/main.tscn:72-73` |

当前不存在 `CanvsLayer` 或 `RunFlowLayer` fallback。`Main._setup_run_flow()` 只查询 `CanvasLayer`，缺失就返回 `false`（`Main/main.gd:229-232`）。

以下是运行时从已有 `.tscn` 预制实例化的节点，不是 Main 场景预置子节点：`NodeChoicePanel`、`DraftRewardPanel`、`RunEventPanel`、`DevilShop`、普通 `Shop`、`InventoryPanel`；`FloorHud` 与部分现有面板在缺失时也会从预制实例化（`Main/main.gd:234-263`、`:336-384`）。这描述当前装配事实，不授权用 GDScript 新建 UI 结构。

Phase 3 P3-B cutover 后的计划 runtime composition 另要求 Main 创建/提供 `BattleSpawner`、base `Enemies: Node2D`、`level_parent = Main`、reset/release/read-stat Callables，以及完整的新 RunFlow 依赖；这些是 [phase4-plan.md](phase4-plan.md) 的待执行契约，不是 HEAD `592c7db` 的当前场景节点。真实 Main composition GUT 必须证明唯一新 orchestrator 和失败反向清理。

## 当前 legacy 面板接口

旧 `RunController` 当前消费以下公开信号；Phase 3 cutover 应把它们适配为 `RunFlowController` 的 typed presentation/intent，不让面板复制领域规则。

| 面板 | 当前公开意图 | 当前消费者 |
| --- | --- | --- |
| `NodeChoicePanel` | `option_selected(option)`、`message_dismissed` | `Run/run_controller.gd:1102-1111` |
| `DraftRewardPanel` | `draft_closed` | `Run/run_controller.gd:1108-1112` |
| `InventoryPanel` | `upgrade_item_selected` | `Run/run_controller.gd:1113-1117` |
| `RunEventPanel` | `wager_requested`、`fight_requested`、`escape_requested`、`continued` | `Run/run_controller.gd:1118-1122` |
| `DevilShop` | `closed` | `Run/run_controller.gd:1124-1127` |
| `RunFailurePanel` | `restart_requested` | `Main/main.gd:368-374` |

## LevelDef / BattlePlanFactory 契约

`Levels/level_def.gd` 的 `LevelDef.level_scene` 是关卡 PackedScene 来源；`BattlePlanFactory` 接受 `LevelDef`、资源路径或它们的数组（`Run/battle_plan_factory.gd:31-41`、`:115-129`）。当一个有效 `LevelDef.level_scene` 被用于构造实际战斗组时：

1. Factory 临时实例化场景，查找根级 `EnemySpawns`（`Run/battle_plan_factory.gd:132-155`）。
2. 只消费 `EnemySpawns` 的 `LevelEnemySpawn` 子节点；其他子节点跳过（`:156-159`）。
3. 每个 spawn 的 `global_position`、`enemy_scene`、`role`、`pool_override`、`health_override` 生成 `BattleGroupDef.EnemyEntry`（`:160-185`；字段见 `Levels/level_enemy_spawn.gd:16-19`）。spawn 未提供 `enemy_scene` 时使用 Factory 配置的 `enemy_scene` fallback；两者都没有则跳过该条目。
4. 条目为空时该 LevelDef 构建失败，Factory 会尝试自己的 formation fallback（`:67-71`、`:138-144`）。因此 fallback 是 plan 构造的兼容行为，不应掩盖生产关卡缺少 `EnemySpawns` 的场景契约错误。

当前弱、强、精英、Boss 场景都应保留根级 `EnemySpawns` 与 `Enemies`，对应契约 GUT 为 `tests/Integration/test_scene_contracts.gd:36-49`。

## BattleGateway / Enemies 契约

`BattleGateway` 激活 `BattlePlan.group.level_def.level_scene` 时：

- 将实例命名为 `ActiveLevel` 并挂到显式注入的 `level_parent`（`Run/battle_gateway.gd:126-142`）；
- 必须从场景根级取得 `Enemies` 且类型为 `Node2D`（`:144-152`）；缺失时清理 active scene、恢复 base enemy container 并返回失败；
- 把 `BattleSpawner.enemy_container` 切到该 `Enemies`，清理/隐藏上一容器；clear/dispose 后恢复 base container（`:155-193`）；
- `dispose()` 必须断开 spawner/legacy 信号、清敌、清 active level、恢复容器并清空注入引用（`:103-123`）。

当前关卡继承的 `Levels/table_base.tscn:30-36` 还提供根级 `KillZone`（脚本 `Main/kill_zone.gd`）。现有 Gateway 尚未消费它；Phase 4 P4-C 将把“从当次 ActiveLevel 解析 KillZone 并传给 BattleSession”加入运行时契约，且不得跨关卡缓存旧实例。KillZone 的 enemy 路径只能调用 Enemy guarded `defeat(cause)`，不得先 `queue_free()`；marble 路径由 Session 按 `(token, instance_id)` 接受一次后，Main 和 RunFlow 才能消费，详见 [phase4-plan.md](phase4-plan.md)。

`BattleGateway` 不读取 `EnemySpawns`；它消费的是 Factory 已构造的 `BattleGroupDef`，并要求运行关卡提供 `Enemies`。反过来，Factory 不使用运行时 `Enemies`；它只从 `EnemySpawns` 生成计划。两份根级命名分别服务 plan construction 与 runtime activation，不能互相替代。

HEAD `592c7db` 的 `Enemies/enemy.gd` 尚无 `class_name`。Phase 4 P4-A 首先增加且只增加一个全局 `class_name Enemy`，本文所有 Enemy 类型注解和 `is Enemy` 断言都以此为唯一身份，不使用 preload 脚本类型或 duck typing。完成 Godot import/全局类刷新后，P4-A 才建立 BattleSpawner typed batch：每个 `BattleGroupDef.enemy_entries` 数组槽都必须提供可实例化且根节点 `is Enemy` 的 scene，并在加入活动 `Enemies` 前同时完成 BattleSession `defeated` registration 和唯一 typed→Event bridge 连接；无/失效 container、空 scene、非 Enemy 或任一部分生成失败都必须断开两类连接、整批清理，不能伪装成“零敌人完成”。只有数组本身为空才是合法零-entry，可在 sealed 后同步完成。P4-C 中 Gateway 遇到同步 batch failure 必须清 active level 并恢复 base container，详见 [phase4-plan.md](phase4-plan.md)。

当前 `Enemies/enemy.tscn:45-46` 提供脚本所需的 `BuffHost` 子节点。P4-A 必须实例化这份真实场景验证全局类型、typed signal/command、Session/bridge 预连接和 guarded `Enemy.defeat()`：首次 guard 后恰好一次调用该 host 的 `notify_host_death()`，再发 `defeated`、最后 `queue_free()`。正常 health 在 P4-A 先统一到该入口；KillZone 在 P4-B 改调同一 command。该要求保留既有 death-hook 行为，不修改 Buff 定义或 registry。

## 已删除的旧契约

`Run/marble_upgrade_system.gd` 已在 `7366094` 前后的 Phase 2 迁移中删除；当前升级能力由 `RunUpgradeService`、Loadout 和 ItemProgression 承担。任何“RunController 查找/创建 `MarbleUpgradeSystem` 子节点”的文档都是陈旧事实，不得恢复为场景契约。

## 稳定规则与验收

- 场景根级 `CanvasLayer`、`EnemySpawns`、`Enemies` 及面板公开 typed signals 是可测试边界；面板内部 Control 路径、动画名和预览节点不是跨模块 API。
- UI 结构和属性必须来自 `.tscn`/`.tres`；脚本只处理数据、状态刷新、信号绑定和分发。未来新增或修改 UI 场景须经 Godot 编辑器/Hastur 完成。
- 新增或移动 `.gd`/`.tscn`/`.tres` 后，必须先由目标 Godot 4.6.1 项目完成 import/UID 生成和引用解析，再运行 GUT；startup/static inspection 只能辅助定位，不能声称 GUT 通过。
- Phase 4 的 BattleSession 场景/节点契约和运行场景验收见 [phase4-plan.md](phase4-plan.md)。
