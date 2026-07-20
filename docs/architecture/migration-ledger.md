# 架构迁移台账（Phase 0–9）

## 证据规则

本台账区分三类事实：已提交实现、仓库内可审计验证证据、仅存在于交接报告的运行结果。只有带原始日志并可对应到明确代码版本的 GUT 结果，才能写成可复验的 `PASS`；启动检查、静态检查和交接数字都不能替代 GUT。

早期约定“所有 `tests/**` 永不提交”已经被仓库历史否定：`7366094` 提交了 Phase 0–2 测试，`42adaba` 又提交了 Phase 3 focused 测试。因此当前政策是：测试可以作为对应实现的版本化验收资产提交；暂存和提交时仍需逐路径审阅，禁止用宽泛暂存误带无关文件。`docs/testing/phase1-test-assets.md` 与 `docs/testing/phase2-test-assets.md` 保留的是当时 checkpoint 的路径/hash manifest，用于审计历史内容，不再代表当前工作树必须保持未提交。

## 阶段状态

| Phase | 当前状态 | 已完成事实 | 尚未完成的关键验收 |
| --- | --- | --- | --- |
| 0 | **历史 checkpoint 完成** | 冻结运行图、依赖、Autoload、场景、UID 与测试基线。 | 无；历史证据见下文。 |
| 1 | **历史 checkpoint 完成** | Content 边界与 Commerce 垂直切片；普通店/恶魔店委托 scoped Session。 | 运行时交互当时明确记为 `DEFERRED`。 |
| 2 | **core 与 scope 迁移完成** | 唯一 `RunScope` 持有 Loadout、ItemProgression、RunWallet、RunHealth；Shop/Inventory Autoload、旧 Inventory 与 MarbleUpgradeSystem 已删除。 | 当时没有全量 GUT 或完整跑图证据。 |
| 3 | **modular core implementation committed；production acceptance 未完成** | `42adaba` 提交 typed Run state/offer/result、`RunFlowController` 及 5 个拆分模块。 | Main 未组装新 flow；UI 未切成 pure adapters；旧 `RunController` 仍是 production orchestrator；旧流程业务实现尚未删除。 |
| 4 | **未开始；先满足 Phase 3 production cutover 门槛** | 方案见 [phase4-plan.md](phase4-plan.md)。 | P4-A 不可拆地建立真实 `class_name Enemy` typed surface、唯一 Enemy→Event bridge、`BattleSession` 与原子 sealed/failed spawn batch；随后迁其余局部 signals，删除 wave 幽灵契约并在消费者清零后退役 Event Autoload。 |
| 5 | 未开始 | Effect/Buff 收敛。 | registry/service 唯一化及状态效果验证。 |
| 6 | 未开始 | 正式可视化 Bootstrap composition。 | `game_main.tscn` / `run_scope.tscn` 与 scoped 生命周期验收。 |
| 7 | 未开始 | UI presentation、构建与字体治理。 | UI 场景、字体、交互与截图验收。 |
| 8 | 未开始 | 编辑器/Hastur 资源与目录迁移。 | UID、引用、相关及完整 GUT 验收。 |
| 9 | 未开始 | 最终 ADR/README/CONTEXT、测试镜像与去兼容审计。 | adapter/bridge/旧实现清零及完整运行流程。 |

Phase 3 的两层状态不得合并表述。`Run/run_flow_controller.gd` 已存在并提交，不等于它已进入生产路径；`Main/main.gd:3`、`:269-293` 仍 preload、实例化并启动 `Run/run_controller.gd`，且仓库中没有 Main/UI 对 `RunFlowController` 的调用。按原 Phase 3 spec，“Main 生产切换、UI adapter 化、删除旧流程业务实现”仍是 Phase 3 acceptance，不得作为 Phase 4 成果冒领。可执行 cutover 分为 [phase4-plan.md](phase4-plan.md) 的 P3-A 组合准备与 P3-B 原子生产切换；P3-B 完成前 Phase 4 保持未开始。

## 提交事实

### `7366094` — `phase0-2`

- 提交 Phase 0–2 的 Run domain/application、Commerce/Loadout/Integration/Run 测试与 UID 侧车；这也是测试已进入版本控制的直接证据。
- 新增 `BattlePlanFactory`、`BattleGateway`、`RewardService`、`EventResolver`、typed domain 模型及对应 GUT。
- 删除 `tests/test_skill_upgrade_system.gd` 及 UID；当前文档不得继续把它列为现有测试。

### `42adaba` — `feat(run): implement modular phase 3 flow controller`

- 新增 582 行 `Run/run_flow_controller.gd`。
- 新增 5 个职责模块：`run_battle_flow.gd` 89 行、`run_event_flow.gd` 83 行、`run_node_offer_policy.gd` 160 行、`run_reward_flow.gd` 117 行、`run_upgrade_service.gd` 191 行。
- 新增 typed node/upgrade domain 模型，修改 `Run/domain/run_state.gd`，并收紧 `RewardService`：活动且未消费的 draft 存在时不允许创建并覆盖另一 draft。
- 新增 `tests/Run/test_run_flow_controller_phase3.gd` 及 UID；脚本当前有 8 个 `test_*`，blob hash 为 `0b68debd1490840411335d1af7e45e7701519921`。
- 该提交没有修改 `Main/main.gd`、`Main/main.tscn`、任何 UI 脚本/场景，也没有删除 `Run/run_controller.gd`，所以只证明 modular core 被提交。

### `fb56caf` — `chore(git): ignore generated GUT UID sidecars`

- 仅修改 `.gitignore`，加入 `/addons/gut/**/*.gd.uid` 忽略规则；没有修改生产、测试或文档行为。

### `592c7db` — `chore: track GUT UID files`

- 撤销 `fb56caf` 的 GUT UID 忽略规则，并提交 82 个 `addons/gut/**/*.gd.uid` 侧车。
- 当前 HEAD 为 `592c7db`；该提交没有改变 Phase 3 flow、Main 或 UI 装配。

## Phase 0–2 历史证据

- Phase 0 初始 GUT：3 scripts / 22 tests / 160 asserts，exit 0（[原始日志](../testing/evidence/phase0-gut-baseline.log)）。契约加入后与 UID 修复后分别为 4/24/196、exit 0（[契约日志](../testing/evidence/phase0-gut-contracts.log)、[UID 修复日志](../testing/evidence/phase0-gut-uid-fixed.log)）。
- Phase 0 图形主场景 3 帧 smoke 的干净记录见 [phase0-main-smoke-uid-fixed.log](../testing/evidence/phase0-main-smoke-uid-fixed.log)；它只证明启动 contract，不证明交互或完整流程。headless 记录包含 shader compiler `ERROR`，不作为干净证据。
- Phase 1 归档 GUT：9 scripts / 54 tests / 494 asserts，exit 0（[原始日志](../testing/evidence/phase1-gut.log)）。运行时交互当时明确为 `DEFERRED`。
- Phase 2 交接记录曾给出多组 focused GUT 数字，但 `docs/testing/evidence/` 没有对应 Phase 2 原始日志，因此本台账不把这些数字提升为当前可复验 `PASS`。`7366094` 证明相关测试内容已经提交，不证明该 HEAD 的全量运行结果。

## Phase 3 验证状态与已知冲突

- 交接报告结果：Phase 3 focused GUT 为 **8 tests / 167 assertions**；原始成功日志未入库，当前 `docs/testing/evidence/` 也没有 Phase 3 日志。因此只能记录为“交接报告结果（原始成功日志未入库）”，不能写成当前可复验 `PASS`。
- 交接还称一次卡住的 Godot/GUT 进程以记录到的 PID `7668` 精确终止，并提到 `warning-as-error` / signal 11 风险。仓库没有该次 stdout/stderr、命令、exit code 或时间戳，故这些只作为交接事实和复跑风险，不作为已复现根因。
- 当前旧测试 `tests/Run/test_reward_service.gd:206-235` 在 stale draft 未消费、未 `clear_active()` 时创建第二份 draft；新契约 `Run/reward_service.gd:333-336` 会拒绝覆盖 active draft并返回 `null`，随后 helper 在 `tests/Run/test_reward_service.gd:337` 调用 `draft.options()`。这是旧测试流程与新契约的真实冲突；修订测试或契约前不得声称 full GUT 通过。
- 当前没有 full GUT 的入库成功日志，也没有 Phase 3 production runtime cutover 证据。

## Phase 3 未完成清单（Phase 4 开工前门槛）

1. `Main` 创建/提供 BattleSpawner、base `Enemies`、level parent、reset/release/read-stat Callables，并组装 `RunFlowController`、`BattlePlanFactory`、`RewardService`、`EventResolver`、单一共享 `RunRandomSource`、默认 `BattleRewardConfig`/`RunFloorConfig` 与 `BattleGateway`；全部 configure 失败必须反向清理且不得 start。
2. NodeChoice、Reward、Event、Upgrade、Shop、Failure 等 UI 只把 typed presentation 显示为状态并发出 typed intent，不持有或复制流程规则。
3. 迁移 SkillSlot、HUD、失败重开和 MarbleChain 的接线到新 flow；SkillController 在 Phase 4 正式 typed 迁移前只允许经已登记的专用 typed flow→Event lifecycle bridge 兼容，不能复用旧单参数 helper。
4. 调用者清零后删除 `Run/run_controller.gd` 及 UID；不得保留同名兼容壳或可运行的双 orchestrator。
5. 修复上述旧 RewardService 测试冲突，增加真实 Main composition GUT，运行 focused 与 full GUT 并归档原始日志；随后执行首战、奖励/节点/事件/商店/升级、Boss、失败重开。P3-B checkpoint 必须只有 `Event → BattleSpawner → BattleGateway → RunBattleFlow` 一条活动完成路径。

## 临时 facade / bridge

| 名称 | 创建阶段 | 当前调用者 | 删除条件 | 状态 |
| --- | --- | --- | --- | --- |
| Commerce current adapters | 1 | 无 | scoped Loadout/Progression/Wallet/Health 切换 | **Phase 2 已删除** |
| Phase 1 旧购买/发放 seam | 1 | 无 | Commerce delegation 验收 | **已删除** |
| `BattleGateway.legacy_event_source` | 2 | 已提交 capability；Main 未装配，当前 production-unreachable | Phase 4 P4-C 的 BattleSession accepted marble 接入 Gateway | **代码存在，非活动 consumer，待删** |
| Main 的旧 `RunController → Event` 转发 | 现有 legacy | `SkillController` 等 Event 消费者 | Phase 3 P3-B 删除并由下行专用 typed bridge 临时替代 | **当前生产存在，待 P3-B 删除** |
| `RunFlowController typed lifecycle → Event` | Phase 3 P3-B（计划） | cutover 后的 `SkillController` compatibility | Phase 4 P4-D SkillController typed configure | **尚未创建；创建时须专用签名 adapter，Phase 4 内删除** |
| `Enemy.defeated → Event.enemy_killed` | Phase 4 P4-A（计划） | 旧 Spawner/BuffManager | P4-C Spawner 切 Session、P4-D BuffManager typed configure 后删除 | **尚未创建；须与 `class_name Enemy`/guarded command/删除 Enemy direct emit/Session registration 原子落地，唯一 owner 为 BattleSpawner** |
| KillZone/MarbleChain typed source → Event | Phase 4 P4-B（计划） | 迁移期间的 Main/BuffManager；KillZone enemy 复用 P4-A Enemy bridge | P4-C/P4-D 各消费者切到 Session/typed source | **尚未创建；不得新增第二条 Enemy bridge** |

## 停止条件

出现测试无法发现/解析、Godot UID 或资源无法解析、`class_name Enemy` 缺失/冲突、真实 `Enemies/enemy.tscn` 不能解析为 Enemy、Missing Script/Resource、P4-A 被拆分保留、Enemy direct Event emit 与 typed bridge 同时存在或同时缺失、同一 Enemy bridge 不等于一条、旧/新 orchestrator 双运行、checkpoint 没有或有两条活动 battle completion path、同一 spawn batch 同时 sealed/failed、失败后遗留 Enemy/Session/bridge 连接/completion、Gateway start 失败后未恢复 level/base container、同一 Enemy 的 `notify_host_death`/Buff/defeated/Event/战斗双结算、同一 marble health `-2` 或链重建两次、迟到信号推进新 session、dispose 后回调、P4-D 后 `wave_completed`/`on_wave_completed` 仍存在于生产脚本、run reset 状态泄漏，或 focused/full GUT 卡住且无可审计输出时，立即停在当前 checkpoint，保留日志并先消除风险，不进入下一阶段。
