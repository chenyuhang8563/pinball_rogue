# 当前运行时事实（HEAD `592c7db`）

## 入口与装配

项目以 `res://Main/main.tscn` 为入口；`project.godot` 的 `run/main_scene` 指向该场景 UID。`project.godot:18-28` 当前注册 **9 个** Autoload：`Event`、`Localization`、`EffectManager`、`EffectRegistry`、`GameExecutor`、`StatSystem`、`BuffManager`、`BuffRegistry`、`FloatDamageTextPool`。

`Main/main.tscn` 预置以下直接节点：

- `Main/Marbles`；
- `Main/CanvasLayer`，其下有 `BattleHealthHud`、`PausePanel`、一个普通 `Label`、`SkillSlot`、`RunFailurePanel`；
- `Main/SkillController`。

`Main/main.gd` 当前生产启动路径为：

```text
Godot + 9 Autoload
  -> Main._ready()
       -> 创建并初始化唯一 RunScope
       -> 订阅 Event.marble_fell、订阅 Loadout 变化
       -> 生成 MarbleChain，配置 SkillController / SkillSlot
       -> Main._setup_run_flow()
            -> 实例化 NodeChoicePanel / DraftRewardPanel / RunEventPanel / DevilShop
            -> 实例化普通 Shop 与 InventoryPanel
            -> 复用或实例化 HUD / FloorHud / PausePanel
            -> new RunController，注入 RunScope、面板和 reset_battle_state 回调
            -> 把旧 RunController 的节点/战斗/通关信号转发到 Event
            -> RunController.start_run()
```

依据是 `Main/main.gd:40-50`、`:162-204`、`:229-294`。`Main` 对 `CanvasLayer` 的要求是明确的：`:230-232` 找不到它就返回 `false`。当前代码不存在 `CanvsLayer` 或 `RunFlowLayer` fallback，也不会用代码创建替代 CanvasLayer。

## Phase 3 core 的生产可达性

`42adaba` 已提交：

- `Run/run_flow_controller.gd`（582 行）；
- `Run/run_battle_flow.gd`、`run_event_flow.gd`、`run_node_offer_policy.gd`、`run_reward_flow.gd`、`run_upgrade_service.gd`；
- 相应 typed domain 模型及 focused 测试。

但 production composition 没有引用它：仓库中 `RunFlowController` 的生产声明只出现在自身文件；`Main/main.gd:3` 仍 preload `res://Run/run_controller.gd`，`:269-293` 仍实例化、加入场景树并启动旧 `RunController`。因此准确结论是：**Phase 3 modular core 已提交，但 production unreachable；旧 `RunController` 仍是生产 orchestrator。**

`Run/run_controller.gd` 当前 1137 行，仍拥有节点推进、奖励/事件/升级路由、关卡激活、战斗开始/结束、失败与 Boss 完成等业务。新旧实现同时存在于代码库，但只有旧实现在 Main 启动路径上；这不是 Phase 3 acceptance 完成。

## 当前状态和生命周期所有者

| 能力/状态 | 当前生产所有者 | 依据 |
| --- | --- | --- |
| 持有物、弹珠顺序、技能槽 | `RunScope.loadout` | `Main/main.gd:162-193`、`Game/Bootstrap/run_scope.gd` |
| 成长、钱包、生命 | `RunScope.progression` / `wallet` / `health` | 同上 |
| 跑图节点、当前战斗、奖励/事件/升级/商店阶段、终局 | 旧 `RunController` | `Run/run_controller.gd`；Main 的实际创建见 `Main/main.gd:269-293` |
| 关卡实例与活动 `Enemies` 容器 | 旧 `RunController` + `BattleSpawner` | `Run/run_controller.gd:849-874`、`Run/battle_spawner.gd` |
| 弹珠链生成、掉落后的重建、战斗 reset | `Main` | `Main/main.gd:57-109` |
| 技能运行时与投射物 | 场景内 `SkillController` | `Main/main.tscn:72-73`、`Main/main.gd:141-159` |
| UI 局部展示/交互状态 | 各 Control 脚本 | `UI/*.gd`、`Shop/shop.gd`、`DevilShop/devil_shop.gd` |

当前没有独立“gold HUD”节点或旧 Shop 金币状态所有者。钱包属于 `RunScope.wallet`；Main 的实现把 wallet `changed` 值推给现有 `BattleHealthHud.set_gold()`（`Main/main.gd:418-431`）。这只是当前 HUD 适配行为，不应被描述为第二份金币领域状态。

## 当前战斗/Event 路径

```text
Enemy / KillZone --enemy_killed--> Event --> BattleSpawner, BuffManager
KillZone ----------marble_fell----> Event --> Main, old RunController
MarbleChain ------chain_collision-> Event --> BuffManager
old RunController -> Main bridge -> Event.battle_started/completed/run_completed
                                      -> SkillController
```

另有一条**已提交但 production-unreachable 的 capability**：`BattleGateway` 提供带 `RunFlowToken`/`BattlePlan` 的 typed 输出，并可接受 `legacy_event_source` 订阅 `marble_fell`（`Run/battle_gateway.gd:31-64`、`:213-235`）。Main 当前没有创建/configure Gateway 或新 flow，所以它不计入上图的活动 Event consumers，但仍须在 Phase 4 最终删除审计中清零。

## 已知风险

- Main 同时是 composition root、弹珠生命周期管理器、UI 实例化器和流程 adapter，职责尚未收敛。
- 大部分流程面板在运行时由 Main 从预制场景实例化；它们不是 `Main/main.tscn` 的预置子节点。
- Event 允许 Enemy 与 KillZone 都报告敌人死亡；BattleSpawner 依赖全局 `enemy_killed`，需要 Phase 4 的 session identity 与 exactly-once 语义消除重复/迟到完成风险。
- HEAD 的 `Enemies/enemy.gd` 尚无 `class_name Enemy`、typed `defeated` 或 `defeat()`；health 死亡仍由 Enemy 自身直接查询/emit Event。P4-A 必须把真实 Enemy typed surface、唯一 Spawner-owned Enemy→Event bridge、删除该 direct emit及 Session/Spawner registration 合并为不可拆 checkpoint，不能留下零 producer 或双 producer。
- `SkillController` 仍从 Event 监听 `battle_completed`/`run_completed`；`BuffManager` 仍从 Event 监听敌人、波次与碰撞信号。其中 `wave_completed` 当前没有生产 emitter，只有 Event 声明、BuffManager 连接、`_on_wave_completed()` 和 `on_wave_completed` dispatch seam，是待 P4-D 直接删除且不得映射为 battle completion 的幽灵契约。
- Phase 3 production cutover 需要临时以专用 typed-signature adapters 将新 flow 生命周期单向桥接到 Event，不能复用旧零/单参数 helper；该 bridge 只为 SkillController 兼容，并须在 Phase 4 内删除。
- `PausePanel.exit_requested` 当前没有 Main 消费者；不能把它当成已实现的退出本局契约。

目标边界见 [target-dependencies.md](target-dependencies.md)，Phase 3 production cutover 与 Phase 4 迁移顺序见 [phase4-plan.md](phase4-plan.md)。
