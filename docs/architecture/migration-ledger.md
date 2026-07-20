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
| 3 | **完成（production cutover 已落地）** | `42adaba` 提交 modular core；`38b64df` 完成 P3-A 组合与 P3-B 原子生产切换：Main 组装并只启动 `RunFlowController`，UI 经 `RunFlowUIAdapter` typed 呈现/意图，删除 `Run/run_controller.gd` 及 UID。 | 无；递归 full GUT 140/140 已入库（`38b64df`）。 |
| 4 | **完成** | `38b64df`：P4-A 真实 `class_name Enemy` guarded `defeat`、`BattleSpawner` 原子 batch、`BattleSession`；P4-B KillZone/MarbleChain 局部 typed source；P4-C Gateway 持有 Session 并唯一解析固定 `TableBase/KillZone`；P4-D 消费者迁移（Main/BuffManager/SkillController）；P4-E 退役 Event Autoload 与 `Main/event.gd`。 | 无；递归 full GUT 140/140 入库、headless 生产 smoke exit 0；交互式截图不可用（Hastur broker 未运行）已如实记录。 |
| 5 | **完成** | Effect/Buff 边界收敛：删除生产零调用的 `BuffManager` 与 `damage_up/speed_up/shield`、`BuffDef.effect_script`；debuff 构造统一走 `BuffRegistry`（含 `fire_burn_debuff` 登记）；毒循环反转为 `BuffHost.buff_ticked` typed 事件 + 宿主门面单向转发；遗物脚本表合并到 `EffectRegistry`（删除 `EffectManager.EFFECT_SCRIPTS` 重复与死的 `get_relic_effect_types`）。 | 无；递归 full GUT 148/148 入库、headless smoke exit 0；`Buffs/**` 对 EffectManager 引用静态归零。 |
| 6 | **完成** | Bootstrap 组合可视化：`BattleSpawner`/`Enemies`/`BattleGateway`/`RunFlowController` 预置于 `main.tscn`（等价 `game_main.tscn`，保留主场景 UID）；`RunScope` 改为从新场景 `Game/Bootstrap/run_scope.tscn` 实例化（创建/激活/销毁均为场景树明确节点）；`_resolve_composition_node` 事务式 slot 解析（override 优先、错误类型/外部 parent 拒绝且不触碰预置节点）。 | 无；递归 full GUT 153/153 入库、headless smoke exit 0；UI 面板预置/字体治理移交 Phase 7。 |
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
- 该提交没有改变 Phase 3 flow、Main 或 UI 装配。

### `83a108d` — `docs: record phase 3 status and phase 4 plan`

- 更新当前运行图、Autoload/Event 消费者、场景契约、目标依赖与测试证据边界，并新增 [Phase 4 执行方案](phase4-plan.md)。
- 明确区分 Phase 3 modular core 已提交与 production cutover/UI adapter/旧实现删除尚未完成，未把后者计为 Phase 4 成果。
- 仅修改 9 个 `docs/**/*.md`；没有修改生产代码或测试，也没有新增 GUT `PASS` 证据。
- 当前 `phase3/run-flow` 本地与远端分支均指向 `83a108d0b0a6822e3f718a00b4be3c425724c305`。

### `38b64df` — `feat(run): phase 3 production cutover and phase 4 battle session + Event retirement`

- P3-A/P3-B：`Main/main.gd` 组装并只启动 `RunFlowController`（BattleSpawner、base `Enemies`、`BattleGateway`、`RewardService`、`EventResolver`、`BattlePlanFactory`、单一共享 `RunRandomSource`、默认 `BattleRewardConfig`/`RunFloorConfig`），任一 configure/start 失败走幂等反向清理；UI 经新增 `UI/run_flow_ui_adapter.gd` 只做 typed 呈现与意图；删除 `Run/run_controller.gd` 及 UID，无双 orchestrator。
- P4-A：`Enemies/enemy.gd` 注册唯一 `class_name Enemy` 并加 guarded `defeat(cause)`（guard→`BuffHost.notify_host_death()`→`defeated`→`queue_free` 顺序固定）；新增 `Run/battle_session.gd`；`BattleSpawner` 改为 OPEN→SEALED/FAILED 互斥的树外两阶段原子 batch，sealed count 与 registered count 严格相等，marble 按 instance id 去重。
- P4-B：`Main/kill_zone.gd` 敌人分支仅调 `defeat(&"kill_zone")`、marble 发 raw typed `marble_fell`；`Marbles/marble_chain.gd` 发 typed `chain_collision`。
- P4-C：`BattleGateway` 注入并持有 `BattleSession`，激活关卡后从固定 `TableBase/KillZone` 获取 zone，只转发 accepted `completed`/`marble_fell`，删除 `legacy_event_source` 与旧 Spawner completion listener，失败同步回滚并恢复 base container。
- P4-D：Main/`RunFlowController` 只消费 Gateway accepted marble（同 body 双 entered 只扣 1 点 health、只重建链一次）；`BuffManager`/`SkillController` 显式接入当前 typed source，reconfigure 先断旧。
- P4-E：删除 `project.godot` 的 Event autoload、`Main/event.gd` 及 UID；静态审计确认生产 `.gd` 中 `/root/Event`、`legacy_event_source`、`wave_completed`/`on_wave_completed`、旧 completion consumer 均归零，`.tscn`/`.tres`/`.cfg` 无 Event 序列化残留。
- 42 files changed（+3639/−2177）；递归 full GUT 140/140、1590 asserts、exit 0（[phase4-full-gut.log](../testing/evidence/phase4-full-gut.log)）；headless 生产 smoke 90 帧 exit 0（[phase4-headless-smoke.log](../testing/evidence/phase4-headless-smoke.log)）；汇总见 [phase4-verification-summary.md](../testing/evidence/phase4-verification-summary.md)。

### Phase 5 — `feat(run): Effect/Buff 边界收敛与状态效果验证`（Phase 自动化流水线提交）

- 5-A：删除 `Buffs/buff_manager.gd` 及 `damage_up/speed_up/shield` 定义与 UID、`project.godot` 的 `BuffManager` autoload、`BuffDef.effect_script` 字段、Main 接入 BuffManager 的惰性 typed-source 接线（该接线 feeding 无消费者的死路径）；`BuffRegistry` 移除三个全局 buff 并登记 `fire_burn_debuff`，`get_buff_def` 只保留 BuffDef 单一机制。
- 5-B：绿/蓝/火弹珠、`poison_culture`、`ice_hammer`、frost→frozen、fire_burn 死亡扩散的 debuff 构造统一改为 `BuffRegistry.get_buff_def(id)`（弹珠经 `Marble.make_buff`、buff 经 `BuffDef.make_buff`、遗物效果经各自 `_make_buff`）。
- 5-C：毒循环反转——`BuffHost` 新增 typed `buff_ticked(buff_id, host)`，`poison_debuff` 不再调用 `EffectManager`，改经 `Enemy.notify_buff_ticked` 门面 → `Enemy._on_buff_ticked` 单向转发 poison tick 到 `EffectManager.on_poison_tick`；静态审计 `Buffs/**` 对 EffectManager 引用归零。
- 5-D：`EffectManager` 从 `EffectRegistry` 取遗物脚本表，删除自身重复的 `EFFECT_SCRIPTS` 与死的 `_get_owned_effect_types`；`EffectRegistry` 删除读取已删 `relic_items` 的 `get_relic_effect_types`，新增 `has_relic_script`。
- 词汇：`CONTEXT.md` 增补「状态修饰（Buff）」「遗物效果（Effect）」词条及单向依赖约束（Effect→Buff 允许、Buff→Effect 禁止）。
- 新增测试：`tests/Buffs/test_buff_state_effects.gd`、`tests/Buffs/test_poison_inversion.gd`、`tests/Effects/test_effect_registry_manager.gd`；递归 full GUT 148/148、1649 asserts、exit 0（[phase5-full-gut.log](../testing/evidence/phase5-full-gut.log)）；headless 生产 smoke exit 0（[phase5-headless-smoke.log](../testing/evidence/phase5-headless-smoke.log)）。交接见 [phase5-handoff.md](../handoffs/phase5-handoff.md)。

### Phase 6 — `feat(phase6): 正式可视化 Bootstrap composition`（Phase 自动化流水线提交）

- `Main/main.tscn` 预置四个 Bootstrap 节点（`BattleSpawner`/`Enemies`/`BattleGateway`/`RunFlowController`，脚本 UID 与 `.gd.uid` 一致）；等价实现台账所指 `game_main.tscn`（保留主场景 UID `uid://cbbk5l2e1na0y` 与 `project.godot` 不变）。
- 新增 `Game/Bootstrap/run_scope.tscn`（RunScope 场景）；`Main._setup_run_scope` 改为实例化该场景，创建/激活/销毁为场景树中明确节点，`_ever_initialized` 终止语义保持。
- `Main._setup_run_flow_composition` 四节点 slot 改为事务式 `_resolve_composition_node(slot, override, creator, type_check)`：override 优先替换同名预置节点，错误类型/外部 parent 的 override 被拒且不触碰预置节点，无预置时动态 `new()` 回退；新增空值保护与失败回滚。configure 顺序、单一共享 RNG、Gateway 三回调、UI adapter 接线、`start_run` 后置均不变。
- 测试：`test_scene_contracts.gd` 增 Bootstrap 节点类型断言；`test_main_run_flow_composition.gd` 增 5 个测试（使用预置节点、override 替换、错误类型回退、外部 parent 拒绝、dispose 后重建）。
- 递归 full GUT 153/153、1679 asserts、exit 0（[phase6-full-gut.log](../testing/evidence/phase6-full-gut.log)）；headless smoke exit 0（[phase6-headless-smoke.log](../testing/evidence/phase6-headless-smoke.log)）。交接见 [phase6-handoff.md](../handoffs/phase6-handoff.md)。

## Phase 0–2 历史证据

- Phase 0 初始 GUT：3 scripts / 22 tests / 160 asserts，exit 0（[原始日志](../testing/evidence/phase0-gut-baseline.log)）。契约加入后与 UID 修复后分别为 4/24/196、exit 0（[契约日志](../testing/evidence/phase0-gut-contracts.log)、[UID 修复日志](../testing/evidence/phase0-gut-uid-fixed.log)）。
- Phase 0 图形主场景 3 帧 smoke 的干净记录见 [phase0-main-smoke-uid-fixed.log](../testing/evidence/phase0-main-smoke-uid-fixed.log)；它只证明启动 contract，不证明交互或完整流程。headless 记录包含 shader compiler `ERROR`，不作为干净证据。
- Phase 1 归档 GUT：9 scripts / 54 tests / 494 asserts，exit 0（[原始日志](../testing/evidence/phase1-gut.log)）。运行时交互当时明确为 `DEFERRED`。
- Phase 2 交接记录曾给出多组 focused GUT 数字，但 `docs/testing/evidence/` 没有对应 Phase 2 原始日志，因此本台账不把这些数字提升为当前可复验 `PASS`。`7366094` 证明相关测试内容已经提交，不证明该 HEAD 的全量运行结果。

## Phase 3 验证状态与已知冲突

- 交接报告结果：Phase 3 focused GUT 为 **8 tests / 167 assertions**；原始成功日志未入库，当前 `docs/testing/evidence/` 也没有 Phase 3 日志。因此只能记录为“交接报告结果（原始成功日志未入库）”，不能写成当前可复验 `PASS`。
- 交接还称一次卡住的 Godot/GUT 进程以记录到的 PID `7668` 精确终止，并提到 `warning-as-error` / signal 11 风险。仓库没有该次 stdout/stderr、命令、exit code 或时间戳，故这些只作为交接事实和复跑风险，不作为已复现根因。
- 当前旧测试 `tests/Run/test_reward_service.gd:206-235` 在 stale draft 未消费、未 `clear_active()` 时创建第二份 draft；新契约 `Run/reward_service.gd:333-336` 会拒绝覆盖 active draft并返回 `null`，随后 helper 在 `tests/Run/test_reward_service.gd:337` 调用 `draft.options()`。这是旧测试流程与新契约的真实冲突；修订测试或契约前不得声称 full GUT 通过。**已解决（`38b64df`）**：测试改为在请求新 draft 前显式 `clear_active()` 结算旧 draft，未放宽生产端“不可覆盖 active draft”契约。
- 截至 `38b64df`：递归 full GUT 为 140/140、1590 asserts、exit 0，入库为 [phase4-full-gut.log](../testing/evidence/phase4-full-gut.log)；headless 生产 smoke 为 [phase4-headless-smoke.log](../testing/evidence/phase4-headless-smoke.log)（exit 0）；P3-B 生产切换已完成。交互式 gameplay 截图不可用（Hastur broker 未运行），已如实记录。

## Phase 3 未完成清单（Phase 4 开工前门槛）

> 以下各项已在 `38b64df`（P3-A/P3-B 与 Phase 4 验收）全部完成：递归 full GUT 140/140 入库；唯一活动完成路径为 `Enemy.defeated → BattleSession → BattleGateway → RunBattleFlow → RunFlowController`。

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
| `BattleGateway.legacy_event_source` | 2 | 无 | Phase 4 P4-C 的 BattleSession accepted marble 接入 Gateway | **已删除（`38b64df`，P4-C/P4-E）** |
| Main 的旧 `RunController → Event` 转发 | 现有 legacy | 无 | Phase 3 P3-B 删除 | **已删除（`38b64df`，P3-B）** |
| `RunFlowController typed lifecycle → Event` | Phase 3 P3-B | 无 | Phase 4 P4-D SkillController typed configure | **P3-B 创建、P4-D 已删除（`38b64df`）** |
| `Enemy.defeated → Event.enemy_killed` | Phase 4 P4-A | 无 | P4-C Spawner 切 Session、P4-D BuffManager typed configure 后删除 | **P4-A 创建（唯一 owner BattleSpawner）、P4-E 随 Event 退役删除（`38b64df`）** |
| KillZone/MarbleChain typed source → Event | Phase 4 P4-B | 无 | P4-C/P4-D 各消费者切到 Session/typed source | **P4-B 创建、P4-D/E 已删除（`38b64df`）** |

## 停止条件

出现测试无法发现/解析、Godot UID 或资源无法解析、`class_name Enemy` 缺失/冲突、真实 `Enemies/enemy.tscn` 不能解析为 Enemy、Missing Script/Resource、P4-A 被拆分保留、Enemy direct Event emit 与 typed bridge 同时存在或同时缺失、同一 Enemy bridge 不等于一条、旧/新 orchestrator 双运行、checkpoint 没有或有两条活动 battle completion path、同一 spawn batch 同时 sealed/failed、失败后遗留 Enemy/Session/bridge 连接/completion、Gateway start 失败后未恢复 level/base container、同一 Enemy 的 `notify_host_death`/Buff/defeated/Event/战斗双结算、同一 marble health `-2` 或链重建两次、迟到信号推进新 session、dispose 后回调、P4-D 后 `wave_completed`/`on_wave_completed` 仍存在于生产脚本、run reset 状态泄漏，或 focused/full GUT 卡住且无可审计输出时，立即停在当前 checkpoint，保留日志并先消除风险，不进入下一阶段。
