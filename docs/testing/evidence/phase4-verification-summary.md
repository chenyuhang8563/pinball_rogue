# Phase 4 验证汇总（BattleSession、局部 typed signals、Event 退役）

- 日期：2026-07-21
- HEAD：`83a108d0b0a6822e3f718a00b4be3c425724c305`
- 分支：`phase3/run-flow`
- Godot：4.6.1.stable / GUT：9.6.0
- 说明：本文件仅新增证据，不改动 `docs/architecture/migration-ledger.md`（其既有用户改动保持原样）。

## 1. 递归 full GUT（全部通过）

命令：

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue\.claude\worktrees\architecture-review -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

结果（原始输出见 `phase4-full-gut.log`）：

- Scripts 24 / Tests 140 / **Passing 140** / Asserts 1590
- exit code 0（`---- All tests passed! ----`）

关键 focused 套件均绿：

| 套件 | 结果 | 覆盖 |
|---|---|---|
| `tests/Run/test_battle_gateway.gd` | 7/7 | 真实关卡 Session 唯一完成源、零 entry 同步完成、失败回滚、缺 KillZone 同步失败、stale 回调不串台、同 marble 经 Session→Gateway→RunBattleFlow 只接受一次 |
| `tests/P4A/test_battle_session_spawner.gd` | 12/12 | 0/1/N batch、树外注册后原子发布、入树同步 defeat 仍 sealed→closed→completed 一次、sealed count 严格等于 registered count、部分失败整批回滚、重复 terminal 幂等、marble 身份去重与旧回调失效、dispose 幂等 |
| `tests/P4B/test_source_slices.gd` | 6/6 | KillZone 仅对 Enemy 调 `defeat(&"kill_zone")`、raw marble typed 单次、非 Enemy 忽略、退出断连、MarbleChain typed 碰撞分类单次且无 legacy bridge |
| `tests/P4D/test_typed_consumers.gd` | 3/3 | BuffManager 换源先断旧、SkillController 生命周期换源/断开、Main 消费 Gateway accepted marble 且显式断连 |
| `tests/Enemies/test_enemy_p4a.gd` | 3/3 | 真实 enemy.tscn typed surface、guarded defeat 顺序（guard→BuffHost death→defeated→queue_free）、health 归零走 `defeat(&"health_depleted")` |
| `tests/Integration/test_main_run_flow_composition.gd` | 4/4 | 共享 scope/单一 RNG/指定 .tres、三 Callable、configure 失败反向回滚、P3-B 仅新 flow 启动且无旧 RunController |
| `tests/Run/test_run_state_contracts.gd` | 6/6 | 按现行 RunState 合法转换序列重写（begin_first_battle→present_reward→advance_to_node；BOSS/NONE 完成）|
| `tests/Run/test_reward_service.gd` | 9/9 | active-draft 显式 `clear_active()` 结算后再请求新 draft（未放宽生产契约）|
| `tests/Run/test_run_flow_controller_phase3.gd` | 8/8 | normal/elite/event/upgrade/shop/boss/失败重开/marble→health→0、同步完成顺序 |

## 2. Event 退役静态审计（生产 `.gd` 全部归零）

以下模式在生产与测试 `.gd` 中匹配数均为 0（仅剩 `EventResolver`/`RunEventPanel` 等合法领域类型，及 BuffManager 的 buff 效果契约 `on_enemy_killed`）：

- `/root/Event`、`get_node_or_null("Event")`、`_get_autoload_node(&"Event")`
- `legacy_event_source`、typed→Event adapter
- `wave_completed`、`on_wave_completed`
- 旧 Spawner `start_battle` / `battle_completed` 完成面、Event completion consumer

序列化引用审计：`.tscn` / `.tres` / `project.godot` / `.cfg` 中无 `event.gd`、Event UID（`drugq0ej64rno`）、`Event=` autoload 残留；`Main/event.gd` 及其 `.uid` 已删除；`project.godot` 不再注册 Event。

## 3. 唯一生产完成路径

```text
Enemy.defeat(cause)            # guarded，exactly-once
  → Enemy.defeated(enemy, cause)
  → BattleSession              # token/batch/live-set 校验，marble 按 instance id 去重
  → BattleGateway              # 固定 TableBase/KillZone 解析，仅转发 accepted completed / marble_fell
  → RunBattleFlow              # token/plan 二次校验
  → RunFlowController          # 奖励路由 / marble→health / 失败
```

- Main 与 RunFlowController 只消费 Gateway accepted `marble_fell`；同一 body 双 entered 只重建链一次、只扣 1 点生命。
- BuffManager 直连当前 `BattleSession.enemy_defeated` 与当前 `MarbleChain.chain_collision`，换源先断旧。
- SkillController 显式接入/断开 `RunFlowController` 生命周期 typed signals。

## 4. 运行时验证

- 无头生产 smoke（`phase4-headless-smoke.log`，exit 0）：主场景启动 90 帧无 GDScript 脚本错误，证明 `Main._ready → _setup_run_flow → RunFlowController.start_run()` 在无 Event autoload 下正常组合并启动（仅一条与本改动无关的 Godot headless shader 编译器告警）。
- 交互式 gameplay 与截图：**不可用**。Hastur broker（`http://localhost:5302`）未运行，连接被拒，无 `game` executor，故无法按场景分别运行并截图到 `E:\Projects\pinball_rogue\.codex\hud_screenshots`。首战/多敌人/health 与 KillZone 竞争/同 marble 双 entered/health 归零/奖励推进/Boss 完成/失败重开等行为已由上表真实场景 GUT 覆盖；待 broker 与 game executor 可用后再补交互式截图证据。

## 5. 遗留约束

- 未做任何 git 提交（等待用户批准）。
- `migration-ledger.md` 的既有用户改动未被触碰；台账的 Phase 4 记录合并需在用户确认后进行。
