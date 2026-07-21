# Phase 9 验证记录

- Worktree：`E:\Projects\pinball_rogue\.claude\worktrees\architecture-review`
- 分支：`phase3/run-flow`
- 验证日期：2026-07-21

## GUT

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue\.claude\worktrees\architecture-review -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

结果：exit `0`；28 scripts、161 tests、1775 asserts 全部通过。原始输出见 [stdout](phase9-full-gut.log) 与 [stderr](phase9-full-gut.stderr.log)。

首次运行发现 `tests/Run/test_run_state_contracts.gd` 的测试辅助函数仍传入已移除的兼容参数，Godot 会进入 parser debugger 循环。已同步删除三个调用点后重新完整运行并获得上述通过结果。GUT 输出仍有 1 条既有框架警告（`TestWallet` 内部类）、GUT 插件 UID fallback 以及既有 GDScript 警告；未报告测试失败或 ObjectDB/RID/orphan/resources-in-use 泄漏。

## 静态去兼容审计

生产代码（不含 `docs/`、`tests/`、`addons/`）扫描结果：

- 旧顶层资源路径 `res://Main`、`Enemies`、`Marbles`、`Skills`、`Effects`、`Buffs`、`Resources`、`Shop`、`DevilShop`、`Items`、`Stats`、`Inventory`、`Fliper`、`Platform`、`Debug`：0 项。
- `legacy_event_source`、`/root/Event`、Event 直接访问、`RunController`、`BuffManager`、`MarbleUpgradeSystem`、current adapter、compatibility/bridge：0 项。
- 已删除公开契约的调用：`BattlePlan.battle_group`、`RewardOption.option_id`、带实参的 `RunState.advance_to_node(...)`：0 项。
- `git diff --check`：通过。

逐项 tombstone 检查确认旧顶层目录 `Main`、`Enemies`、`Marbles`、`Skills`、`Effects`、`Buffs`、`Resources`、`Shop`、`DevilShop`、`Items`、`Stats`、`Inventory`、`Fliper`、`Platform`、`Debug`，以及 `Run/run_controller.gd`、`Main/event.gd`、`Buffs/buff_manager.gd`、`Inventory/inventory.gd`、`Inventory/marble_upgrade_system.gd` 都不存在；`project.godot` 也不含 `Event`、`BuffManager`、`Shop`、`Inventory` Autoload key。

生产代码仍会通过 scene root 获取当前基础设施 Autoload，并通过相对 NodePath 查询场景内部节点；审计确认这些访问不涉及退役服务或旧领域状态。`BattleGateway` 和 `RunFlowUIAdapter` 保留为当前架构边界，未命中旧实现、过渡 bridge 或第二份领域状态，因此不属于本次清零目标。

## 运行时证据

2026-07-21 已通过 Hastur 的 `game` executor 在当前 worktree（`E:/Projects/pinball_rogue/.claude/worktrees/architecture-review/`）完成 fresh 运行验证。每个预览场景均独立启动、注册新的 `game` executor、保存截图后停止；截图位于 `E:\Projects\pinball_rogue\.codex\hud_screenshots`：

- `phase9_bootstrap_main.png`：主场景 `res://Game/Bootstrap/main.tscn` 启动后的战斗画面。
- `phase9_node_after_reward.png`：真实 `Enemy.defeat → BattleSession → BattleGateway → RunFlowController` 完成后，奖励报价 `reward:1:1:2:1` 被领取（`reward-offer:1`），运行状态从 `REWARD_ACTIVE` 迁移至 `CHOOSING_NODE`，节点报价 `node-offer:1:2:1` 已显示。
- `phase9_event_from_run.png`：从上述节点报价选择事件后，运行状态进入 `EVENT_ACTIVE`，展示 `crossroads` 事件及其两个选项；随后通过真实 `EscapeButton.pressed` 信号，经 `RunEventPanel → RunFlowUIAdapter → RunFlowController` 结算事件，事件消费后返回节点报价 `node-offer:1:3:2`，见 `phase9_node_after_event_escape.png`。
- `phase9_shop_from_run.png`：通过真实 `ChoiceButton1.pressed` 信号从该节点进入普通商店（`NORMAL_SHOP_ACTIVE`）；再通过 `ExitButton.pressed` 信号退出，返回节点报价 `node-offer:1:4:3`，见 `phase9_node_after_shop_exit.png`。
- `phase9_preview_node_choice.png`、`phase9_preview_run_event.png`、`phase9_preview_shop.png`：分别独立运行 `preview_node_choice.tscn`、`preview_run_event.tscn` 与 `preview_shop.tscn` 的视觉证据。

奖励和节点面板会暂停场景树；为使远程验证通道在暂停期间仍可观测，本次仅对 `/root/GameExecutor` 施加运行期 `PROCESS_MODE_ALWAYS`，未修改项目代码、场景或 UI 属性。每次截图均由对应 game executor 返回 `screenshot_error=0`，并核对当前场景路径、运行 phase 与面板可见性；当前主流程日志只包含 Godot 4.6.1 与渲染设备启动信息，无脚本、资源或解析诊断。没有将历史 Phase 8 截图作为本次提交的运行证据。

在当前 worktree 上补做了最小启动检查：以 PID `34208` 启动主项目，5 秒后进程仍存活；新增 Godot 日志未包含 parser、资源加载、Missing Script 或 Missing Resource 诊断，随后只终止该 PID。该检查仅证明当前主场景可启动，**不能替代** game executor 下的完整交互流程和新截图。
