# 测试基线（Phase 0）

## 当前事实

- 引擎版本：Godot **4.6.1**（项目特性声明为 Godot 4.6：`project.godot:13-15`；本工作区的执行器版本以 Phase 0 约束为准）。
- 测试框架：GUT **9.6.0**（`addons/gut/plugin.cfg:1-7`）。
- 初始基线清单：**3 个脚本、22 个测试、160 个 asserts**。脚本为 `tests/test_skill_upgrade_system.gd`、`tests/test_shop_upgrade_offers.gd`、`tests/test_devil_shop_upgrade_offers.gd`；例如技能测试继承 `GutTest`（`tests/test_skill_upgrade_system.gd:1-5`）。

## 可靠 GUT 命令

必须使用目标工作树路径，而不是主仓库路径：

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue\.claude\worktrees\architecture-review -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

执行前先静态审阅受影响 GDScript 和场景引用；仅当 GUT 可以正常执行时才运行。测试证据必须来自 GUT，不能用启动检查或独立脚本声称测试通过。

## Phase 0 已执行证据

| 证据 | 范围 | 结果 | 说明 |
| --- | --- | --- | --- |
| `GUT-P0-BASELINE` | 非递归 `tests/` 顶层的三份既有测试脚本 | **3 scripts / 22 tests / 160 asserts，全通过，exit 0** | 可审计原始输出：[phase0-gut-baseline.log](evidence/phase0-gut-baseline.log)（汇总 `:122-132`）。该日志用于可重复确认冻结清单，不作为“早于契约测试文件创建”的时序证明。 |
| `GUT-P0-CONTRACTS` | 递归收集 `res://tests`，包含 `tests/Integration/test_scene_contracts.gd` | **4 scripts / 24 tests / 196 asserts，全通过，exit 0** | 可审计原始输出：[phase0-gut-contracts.log](evidence/phase0-gut-contracts.log)（汇总 `:324-334`）。集成脚本按用户要求保持未提交；其内容哈希为 `f0f0c8b80709a18dad17adfd95f12ca7b1e781bb`。 |
| `GUT-P0-UID-FIXED` | Godot 编辑器重存第一方 UID 引用后的递归完整套件 | **4 scripts / 24 tests / 196 asserts，全通过，exit 0** | [phase0-gut-uid-fixed.log](evidence/phase0-gut-uid-fixed.log)；第一方 `invalid UID` 已归零，仅剩 `addons/gut/**` 的第三方工具链 warning。 |

集成脚本当前包含两个场景契约测试：Main 的必要组合节点和关卡的生成/敌人容器（`tests/Integration/test_scene_contracts.gd:14-41`）。它是后续迁移期间的长期预期脏测试资产：每阶段必须以 `git hash-object tests/Integration/test_scene_contracts.gd` 对照 `f0f0c8b80709a18dad17adfd95f12ca7b1e781bb`；若哈希变化，必须在迁移台账登记原因、责任阶段和新的预期值，不能静默覆盖。

## Phase 1 Commerce 证据

Phase 1 收口后的递归完整 GUT 为 **9 scripts / 54 tests / 494 asserts，全通过，exit 0**。原始输出见 [phase1-gut.log](evidence/phase1-gut.log)；该日志不含 ObjectDB、RID、orphan 或 resources-in-use 泄漏。

新增/迁移测试覆盖：

- NormalShopSession 与 DevilShopSession 的稳定 offer ID、snapshot version、consumed、stale、容量、最低生命、overpay 和重复结算；
- PurchasePlan 在 add/upgrade/debit/remove/reset/credit 的 mutation-after-failure 下完整恢复，以及 rollback failure 的明确结果；
- 技能替换授权前无突变，成功后清除旧技能成长；
- Current Inventory/Progression/Wallet/Health adapters 的真实节点映射和 snapshot/restore；
- 真实 `Slot.purchase_requested → Shop → NormalShopSession`、真实 Shop 出售，以及 `DevilShop.confirm_purchase → select_payment/purchase` 的 presentation delegation。

用户已明确当前阶段无需保证完整游戏流程随时可运行。因此这份 GUT 是测试证据，不是 runtime observation；verify 状态为 **DEFERRED**，不声明实际游戏交互 PASS。

## 当前覆盖范围

已有 GUT 主要覆盖：

- MarbleUpgradeSystem 的技能等级与升级候选/应用行为（`tests/test_skill_upgrade_system.gd:8-40`）；
- 正常商店的升级报价、购买、出售、容量及槽位展示状态（`tests/test_shop_upgrade_offers.gd:12-252`）；
- 恶魔商店的等级跳价、满级过滤、未拥有物品、技能替换和去重（`tests/test_devil_shop_upgrade_offers.gd:11-175`）。

## GUT 不覆盖的范围

契约 GUT 只覆盖静态场景实例化和节点结构，没有证据覆盖以下运行契约：

- `Main` 的启动顺序、动态 UI 装配、失败重开和 RunController 注入（`Main/main.gd:232-286`、`361-403`）；
- 关卡 `EnemySpawns` 到战斗条目、激活关卡后 `Enemies` 容器切换（`Run/run_controller.gd:698-717`、`845-870`）；
- 11 个 Autoload 的完整生命周期、信号接线与退出迁移（`project.godot:18-30`）；
- PausePanel 的 `exit_requested` 消费、DevilShop 信号连接时机、CanvasLayer 回退路径；
- Godot UID/path 移动后的编辑器重导入、场景加载和资源引用完整性；
- UI 视觉、输入焦点、暂停行为、动画、字体和截图质量。

因此，GUT 全绿也不能单独证明架构迁移或场景装配正确。

## Smoke contract 与已执行证据

当运行时验证相关且已连接 `game` executor 时，smoke 应逐场景执行并保存截图到 `E:\Projects\pinball_rogue\.codex\hud_screenshots`。每个测试场景必须单独通过 `godot-remote-executor` 运行并保存截图证据。最低契约为：

1. 启动 Main 后可解析 `Marbles`、`CanvasLayer`、`SkillController` 与 RunController；
2. 首场战斗可激活关卡，关卡含 `EnemySpawns` 与 `Enemies`，敌人进入活动容器；
3. 节点选择、奖励、事件、恶魔商店、暂停和失败面板可按各自公开信号完成一次开闭/推进；
4. 重开后局内状态重置，且不存在旧关卡敌人或遗留浮动文本。

### 图形主场景 smoke（正式 Phase 0 基线）

执行命令使用图形 Godot 可执行文件、目标工作树，并在 3 帧后自动退出：

```powershell
& "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe" --path "E:\Projects\pinball_rogue\.claude\worktrees\architecture-review" --quit-after 3
```

首次归档输出 [phase0-main-smoke.log](evidence/phase0-main-smoke.log) 暴露了 18 处第一方 `invalid UID`，因此仅作为问题发现记录。用户重新导入后，主协调者通过目标工作树的 Godot editor executor 用 ResourceSaver 重存 13 个受影响 `.tscn/.tres`：替换 18 个既有脚本引用 UID，为 2 个 path-only 外部引用补写 UID，并规范化移除 `Enemies/enemy.tscn` 的冗余 `load_steps`。未手工编辑 UID、未移动资源，也未改变节点属性、资源字段、脚本正文或场景结构。

修复后的正式证据为 [phase0-main-smoke-uid-fixed.log](evidence/phase0-main-smoke-uid-fixed.log)：3 帧后 exit 0，且日志不含 `invalid UID`、`ERROR`、Parse 或 Missing Script/Resource。它只验证主场景可启动，**不验证交互、面板开闭、截图或完整跑图流程**。

### Headless smoke（非干净证据）

headless 变体 [phase0-main-smoke-headless.log](evidence/phase0-main-smoke-headless.log) 虽 exit 0，但出现 shader compiler 条件 `ERROR`，因此不作为干净运行时证据，也不替代图形 smoke。
