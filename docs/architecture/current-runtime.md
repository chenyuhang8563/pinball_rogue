# 当前运行时基线（Phase 0）

## 当前事实

项目入口是 `res://Main/main.tscn`：`project.godot:14` 的 `run/main_scene` 指向该场景 UID。`Main` 场景已有 `Marbles`、`CanvasLayer`、`BattleHealthHud`、`PausePanel`、`SkillSlot`、`RunFailurePanel` 和 `SkillController`（`Main/main.tscn:22-72`）。引擎还会在场景前装配 11 个 Autoload（`project.godot:18-30`）。

启动后的实际装配顺序如下；箭头表示当前代码的调用或所有权，并非目标依赖规则。

```text
Godot
  -> Autoload 根节点（11 个）
  -> Main/main.tscn: Main._ready()
       -> 连接 Event.marble_fell、Inventory.inventory_changed
       -> 生成 MarbleChain
       -> 配置 SkillController / SkillSlot
       -> _setup_run_flow()
            -> 在 CanvasLayer 下实例化节点选择、奖励、事件、恶魔商店面板
            -> 复用或实例化 HUD、暂停、失败、背包面板
            -> new RunController，注入面板与回调，add_child()
            -> RunController.start_run()
                 -> new/查找 BattleSpawner、MarbleUpgradeSystem
                 -> 重置局内状态并开始第一个节点
```

证据（均为“文件 — 符号: 当前工作树行号”）：`Main/main.gd — _ready():34-41` 是启动顺序；`Main/main.gd — _setup_run_flow():232-286` 完成运行流的动态装配、引用注入与开局；`Run/run_controller.gd — _ready():80-84` 与 `start_run():87-102` 初始化并重置局状态。`Main/main.gd — _setup_run_flow():279-284` 将 RunController 的节点/战斗完成信号转发到 `Event`，随后在 `:286` 调用 `run_controller.start_run()`。

### Main / RunController 当前装配

`Main` 是当前 composition root，但同时承担了弹珠链生命周期、技能接线、HUD 刷新、失败重开、背包面板创建和 RunController 装配：`Main/main.gd — 成员字段:13-31`、`_setup_skill_system():155-166`、`_setup_run_flow():232-286`、`_on_run_health_changed():380-382`、`_on_failure_restart_requested():396-403`、`_on_shop_gold_changed():425-427`。它不是纯粹的场景壳。

`RunController` 是 `Main` 的子节点，而不是 Autoload；`Main/main.gd — _setup_run_flow():263-275` 以 `new()` 创建它，并注入：

- `level_parent = Main`；
- 节点选择、奖励、事件、恶魔商店、升级背包面板；
- `reset_battle_state_callable`；
- 生命、失败、层数变化的回调。

RunController 自行确保 `BattleSpawner` 和 `MarbleUpgradeSystem` 存在（`Run/run_controller.gd:1095-1107`、`1156-1163`）。它开始战斗时实例化关卡，之后将 BattleSpawner 的敌人容器改为关卡内的 `Enemies`（`Run/run_controller.gd:845-870`）。

### 当前状态所有者

| 状态 | 当前所有者 | 依据 |
| --- | --- | --- |
| 跑图索引、选择波次、局是否完成/失败、战斗活跃、当前关卡 | `RunController` | `Run/run_controller.gd:65-77` |
| 局内生命 | `StatSystem` 中实体 `run:current`；RunController 读写 | `Run/run_controller.gd:46`、`1067-1082` |
| 当前关卡实例与敌人父节点 | `RunController.active_level_scene` / `enemy_container` | `Run/run_controller.gd:71-72`、`845-870` |
| 敌人波次完成追踪 | `BattleSpawner` | `Run/battle_spawner.gd:1-84` |
| 弹珠链与其生成/重生 | `Main.marble_chain` | `Main/main.gd:24`、`46-64`、`94-103` |
| 技能运行时和投射物 | 场景内 `SkillController` | `Main/main.tscn:72-73`、`Main/main.gd — _setup_skill_system():155-166` |
| 物品、金币、属性、Buff、特效、文本池 | 相应 Autoload（详细清单见 [autoload-consumers.md](autoload-consumers.md)） | `project.godot:20-30` |
| 面板显示状态与局部交互状态 | 各 Control 场景脚本 | 例如 `UI/run_event_panel.gd:14-18`、`DevilShop/devil_shop.gd:23-31` |

## 已知风险

- 运行流 UI 大部分由 `Main` 运行时创建（`Main/main.gd:241-255`），而 `Main` 场景只预置部分 UI；这使场景树和实际运行树不同。
- `Main` 会在没有 `CanvasLayer` 时回退拼写为 `CanvsLayer` 的节点，最后甚至用代码创建 `CanvasLayer`（`Main/main.gd:233-239`）。这是迁移兼容分支，不是命名契约。
- `RunController` 将 DevilShop 信号连接写在 `_connect_event_panel_signal()` 的函数体内（`Run/run_controller.gd:1133-1144`）；因此 DevilShop 的接线取决于事件面板及其信号检查。该嵌套是当前偶然耦合，不是面板 API。
- `PausePanel.exit_requested` 会发射（`UI/pause_panel.gd:4`、`77-80`），但 Main 的暂停面板装配只负责查找/移动/实例化，没有消费该信号（`Main/main.gd — _setup_pause_panel():347-358`）。不能据此假定“退出请求会结束本局”。

## 目标规则

后续阶段应把跨模块创建与注入收敛到 `Game/Bootstrap`。不创建巨型 `PlayerState` 或泛化 `RunSession` 状态袋；`RunScope` 显式持有生命周期独立的 `Loadout`、`ItemProgression`、`RunWallet`、`RunHealth` 与 scoped `StatSystem`。具体边界见 [target-dependencies.md](target-dependencies.md)。
