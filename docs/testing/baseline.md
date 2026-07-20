# 测试证据基线（HEAD `592c7db`）

## 环境与证据等级

- 引擎：Godot **4.6.1**；项目特性声明 `4.6`（`project.godot`）。
- 测试框架：GUT **9.6.0**（`addons/gut/plugin.cfg`）。
- 当前 Autoload：**9 个**，见 `project.godot:18-28`；Shop/Inventory 已退役，不再计数。
- 测试 `PASS` 必须来自 GUT 原始输出和 exit code。startup smoke、import、静态扫描、test function 计数、交接报告都不能替代 GUT。

可靠命令必须把 `--path` 指向正在验证的 checkout。机器上的基准调用（当目标分支位于主项目目录时）为：

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

若实施发生在独立 worktree，只替换 `--path` 为该 worktree 的绝对路径，并把该路径与 HEAD 一起写入日志；不得用主项目目录的结果证明另一 checkout。

执行前先静态审阅受影响 GDScript、场景和 UID，确认 GUT 可以正常发现/解析；GUT 卡住且不产出有效输出时应先终止准确记录的 PID、保留诊断，再修复风险。

## 历史归档证据

这些结果只证明日志对应的历史版本和范围，不自动证明当前 HEAD：

| 证据 | 历史范围 | 可审计结果 | 限制 |
| --- | --- | --- | --- |
| [phase0-gut-baseline.log](evidence/phase0-gut-baseline.log) | Phase 0 顶层三份旧测试 | 3 scripts / 22 tests / 160 asserts，exit 0 | 当时包含后来由 `7366094` 删除的 `tests/test_skill_upgrade_system.gd`；不是当前清单。 |
| [phase0-gut-contracts.log](evidence/phase0-gut-contracts.log) | Phase 0 + scene contracts | 4 scripts / 24 tests / 196 asserts，exit 0 | 历史契约内容后来已提交/演进。 |
| [phase0-gut-uid-fixed.log](evidence/phase0-gut-uid-fixed.log) | Phase 0 UID 修复后递归套件 | 4 scripts / 24 tests / 196 asserts，exit 0 | 第一方 UID warning 当时归零；仍有 GUT 第三方 UID warning。 |
| [phase1-gut.log](evidence/phase1-gut.log) | Phase 1 Commerce 收口 | 9 scripts / 54 tests / 494 asserts，exit 0 | 最后一份入库 GUT 成功日志；不覆盖 Phase 2/3。 |

Phase 0 还保存启动日志 `phase0-main-smoke*.log`。其中 `phase0-main-smoke-uid-fixed.log` 只证明当时 Main 可启动 3 帧；`phase0-main-smoke-headless.log` 含 shader compiler `ERROR`。它们都是 runtime observation，不是 GUT 证据。

当前 `docs/testing/evidence/` 的缓存范围仅为：

- Phase 0 三份 GUT 日志；
- Phase 1 一份 GUT 日志；
- Phase 0 的若干 Main smoke/import 日志。

没有 Phase 2 GUT 原始日志、Phase 3 focused GUT 原始日志或当前 HEAD 的 full GUT 日志。

`phase1-test-assets.md` 中 `fc453fc...`、`00d26a...`、`6810ae...` 三项只有历史交接 digest，对应 blob 未归档，当前仓库不可恢复/重算；它们的证据等级低于可由 Git object 或入库日志复核的资产。

## 当前测试资产事实

- `7366094` 提交了 Phase 0–2 的 Commerce、Loadout、Run 与 Integration 测试，并删除 `tests/test_skill_upgrade_system.gd`。因此当前覆盖说明不得再引用该已删除脚本。
- 当前成长/技能覆盖位于 `tests/Loadout/test_item_progression.gd`、`test_loadout.gd`、`test_run_scope.gd`、Commerce 报价/Session 测试及 Run 升级流程测试。
- `42adaba` 提交 `tests/Run/test_run_flow_controller_phase3.gd`。当前文件 blob hash 为 `0b68debd1490840411335d1af7e45e7701519921`，静态可见 **8 个**测试函数：

  1. first weak + typed node offer policy；
  2. normal/elite reward policy routing；
  3. event escape/fight/result table routing；
  4. upgrade available/unavailable typed revisions；
  5. normal/devil shop close exactly once；
  6. Boss bypass 与 NONE policy completion；
  7. failure/restart/stale/marble health guard；
  8. reentrant external command 与同步 completion ordering。

“8 个函数”与 blob hash 是静态内容事实，不是运行结果。

## Phase 3 交接结果与当前阻塞

交接报告称 Phase 3 focused GUT 为 **8 tests / 167 assertions**。原始成功日志未入库，无法确认运行命令、checkout、exit code 与完整 stdout/stderr；因此只记录为：**交接报告结果（原始成功日志未入库）**，不得标记当前可复验 `PASS`。

交接还称 PID `7668` 已精确终止，并提及 `warning-as-error` / signal 11 风险。仓库没有对应运行日志，故不能把它写成已复现根因；复跑时必须保存命令、PID、输出和 exit code。已有 Phase 0/1 日志确实在 `Main/event.gd` 的多个 signal 声明处出现 “declared but never explicitly used” warning，说明 warnings-as-errors 配置变化可能在测试发现前阻断解析，但这仍不证明交接中的 signal 11 与某一具体文件完全相同。

当前 full GUT 还有一个可静态确认的旧测试/新契约冲突：

- `Run/reward_service.gd:333-336` 禁止在 active、未消费 draft 上覆盖创建第二份 draft；
- `tests/Run/test_reward_service.gd:206-235` 在 stale draft 后未 `clear_active()` 就创建 `fresh` draft；
- 创建会返回 `null`，后续 helper `tests/Run/test_reward_service.gd:337` 调用 `draft.options()`。

该冲突修复并实际运行前，禁止宣称当前 full GUT 通过。本次文档更新没有修改测试，也没有运行 GUT。

## 当前需要覆盖但尚无 HEAD 级证据的范围

- Main 从旧 RunController 切到 RunFlowController 的 production composition；
- UI pure adapter 的 typed token/offer/intent 接线；
- BattleGateway 到真实 BattleSpawner/LevelDef/Enemies 的 Main 路径；
- BattleSession 尚未实现的重复/迟到 signal、exactly-once completion 与 dispose；
- P4-A 不可拆 checkpoint：真实 `res://Enemies/enemy.tscn` 在新增唯一 `class_name Enemy` 后可解析为 Enemy，具备 typed `defeat`/`defeated`；Enemy direct Event emit 为 0、每实例 typed→Event bridge 为 1且 exactly-once；
- BattleSpawner/BattleSession 原子 spawn batch：真实 Enemy 的 0/1/N live set；无 container、空 scene、非 Enemy、部分/全部失败时 Session/bridge 断连与整批清理；合法零-entry 才可 sealed 后同步完成；Gateway 同步 start failure 恢复 level/base container且不 complete；
- Phase 3 production cutover 的真实 Main composition、共享 RunRandomSource、全部 configure 参数与失败反向清理；
- Enemy 唯一 `defeat(cause) -> bool`、正常/KillZone/同帧/重复路径中 `notify_host_death` → `defeated` → queue_free 的顺序及 Buff/completion exactly-once；
- BattleSession accepted marble identity：同 body 双 entered 只 health `-1`、链重建一次，旧 session callback 无效；
- P4-D 删除无生产 emitter 的 `wave_completed`、BuffManager handler 和 `on_wave_completed` dispatch seam；两个字符串生产归零且不映射 battle completion；
- Event consumer 清零和 Autoload 删除；
- 从首战到奖励、节点、Boss/失败重开的真实运行流程；
- UID/import 后的完整资源引用以及 ObjectDB/RID 泄漏变化。

完整 Phase 4 测试矩阵和运行验收见 [../architecture/phase4-plan.md](../architecture/phase4-plan.md)。

## 运行与截图证据规则

只有相关 GUT 通过后才做运行验收。运行游戏用于验证真实 composition、信号接线和生命周期，不可替代 GUT。需要测试场景时，每个场景通过 Godot 编辑器/Hastur 建为独立 `.tscn`，分别由 `godot-remote-executor` 运行；只有连接 `game` executor 时才截图，保存到 `E:\Projects\pinball_rogue\.codex\hud_screenshots`，不得使用 `.codex_validation`。

新增/移动脚本、场景或资源后先完成 Godot import/UID 解析，再运行 GUT。startup/static inspection 只能辅助发现 Parse、Missing Script/Resource 或 UID 问题，不能被写为测试 `PASS`。
