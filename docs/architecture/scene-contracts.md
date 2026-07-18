# 场景与面板契约（Phase 0）

## 稳定契约

### Main 场景

`Main/main.tscn` 是启动场景（`project.godot:14`）。稳定的结构契约如下：

| 路径 | 类型/作用 | 证据 |
| --- | --- | --- |
| `Main` | 根 `Node2D`，挂载 `main.gd` | `Main/main.tscn:22-24` |
| `Main/Marbles` | 弹珠链的父节点 | `Main/main.tscn:26`；`Main/main.gd — 成员字段:13` |
| `Main/CanvasLayer` | 预置 HUD 与流程面板的展示层 | `Main/main.tscn:28-70` |
| `Main/CanvasLayer/BattleHealthHud` | `set_health` / `set_gold` 的 HUD 接收者 | `Main/main.tscn:30-37`；`Main/main.gd — _on_run_health_changed():380-382`、`_on_shop_gold_changed():425-427` |
| `Main/CanvasLayer/PausePanel` | 暂停 UI，负责暂停/恢复树 | `Main/main.tscn:39-48`；`UI/pause_panel.gd — open_pause():45-50`、`close_pause():53-55` |
| `Main/CanvasLayer/SkillSlot` | 与 SkillController 的按压/释放信号接线 | `Main/main.tscn:54-61`；`Main/main.gd — _setup_skill_system():155-166` |
| `Main/CanvasLayer/RunFailurePanel` | 发射 `restart_requested`，由 Main 连接并在重开时关闭 | `Main/main.tscn:63-70`；`UI/run_failure_panel.gd — _on_confirm_pressed():36-37`；`Main/main.gd — _setup_run_failure_panel():361-367`、`_on_failure_restart_requested():396-403` |
| `Main/SkillController` | 技能运行时节点 | `Main/main.tscn:72-73` |

运行流面板的稳定接口是各自场景脚本的公开信号，而非其内部节点路径：

| 面板 | RunController 消费的信号 | 证据 |
| --- | --- | --- |
| NodeChoicePanel | `option_selected(option)`、`message_dismissed` | `UI/node_choice_panel.gd:4-5`；`Run/run_controller.gd — _connect_panels():1110-1119` |
| DraftRewardPanel | `draft_closed` | `UI/draft_reward_panel.gd:4-5`；`Run/run_controller.gd — _connect_panels():1116-1119` |
| InventoryPanel（升级选择） | `upgrade_item_selected` | `Run/run_controller.gd — _connect_panels():1121-1124` |
| RunEventPanel | `wager_requested`、`fight_requested`、`escape_requested`、`continued` | `UI/run_event_panel.gd:4-7`；`Run/run_controller.gd — _connect_panels():1126-1136` |
| DevilShop | `closed`、`health_changed` | `DevilShop/devil_shop.gd:10-13`；当前接线见风险项 |
| RunFailurePanel | `restart_requested` | `UI/run_failure_panel.gd:4`；`Main/main.gd — _setup_run_failure_panel():361-367` |

### 关卡场景

每个可由 `LevelDef.level_scene` 载入的关卡根下必须有：

- `EnemySpawns`：子节点必须是 `LevelEnemySpawn`/`Marker2D`，其位置、`enemy_scene`、角色和生命覆盖用于生成 `BattleGroupDef.EnemyEntry`。RunController 明确查询根级路径并遍历子节点（`Run/run_controller.gd:698-717`）；`LevelEnemySpawn` 的导出数据在 `Levels/level_enemy_spawn.gd:1-19`。
- `Enemies`：`Node2D`，作为激活关卡后 BattleSpawner 的运行时敌人容器。RunController 查询根级路径、替换 `enemy_container` 并重新注入 BattleSpawner（`Run/run_controller.gd:845-870`）。

现有弱、强、精英、Boss 关卡均有这两个根级节点，例如 `Levels/level_001_weak.tscn:11-38`、`Levels/level_strong_normal.tscn:11-56`、`Levels/level_elite.tscn:11-39`、`Levels/level_boss.tscn:11-40`。

### MarbleUpgradeSystem 查找

RunController 的局内升级系统稳定行为是：若已有有效实例则复用；否则先找自己子节点 `MarbleUpgradeSystem`，再创建并添加为子节点（`Run/run_controller.gd:1156-1163`）。调用方必须通过注入的实例或此局内节点获取升级能力，不能把它提升为 Autoload。该系统的升级信号和等级常量定义在 `Run/marble_upgrade_system.gd:1-12`。

## 已知偶然风险（不得固化为契约）

- `CanvsLayer` 是 `CanvasLayer` 缺失时的拼写回退（`Main/main.gd:233-239`），不是允许的新场景使用的节点名；最终契约只有 `CanvasLayer`。
- Main 现在会动态实例化 `NodeChoicePanel`、`DraftRewardPanel`、`RunEventPanel`、`DevilShop`，并在缺失时创建 `RunFlowLayer`（`Main/main.gd:233-255`）。这是现状兼容行为，不能作为“面板可任意缺失”的契约。
- DevilShop 的连接代码意外嵌套在 `_connect_event_panel_signal()` 内（`Run/run_controller.gd:1133-1144`）。因此“恶魔商店必须由事件面板信号触发才会接线”不是合法依赖，后续应移至独立装配点。
- `PausePanel` 会发射 `exit_requested`（`UI/pause_panel.gd:4`、`77-80`），但当前 Main 不消费它（`Main/main.gd — _setup_pause_panel():347-358`）。在有明确用例和消费者前，该信号不构成应用退出或返回菜单契约。
- 面板内部 Control 路径、动画名、预览敌人和 `BattleHealthHud` 被恶魔商店通过内部路径查找（`DevilShop/devil_shop.gd:33-46`）都是实现细节；对外只承诺上表的公开信号与明确注入接口。

## 目标规则

场景根级命名与公开面板信号是可由 smoke contract 覆盖的稳定边界；动态回退、隐式 `get_node_or_null` 链和嵌套接线必须在迁移期登记，并在对应阶段删除。新增 UI 应由编辑器场景表达结构，脚本只处理数据、状态刷新和信号绑定。
