# Phase 4 执行方案：BattleSession、局部 typed signals 与 Event 退役

## 结论与范围

Phase 4 的交付物是：一个拥有战斗生命周期的 `BattleSession`，一条从 Enemy/KillZone/MarbleChain 到 BattleSpawner/BattleGateway/RunFlow 的局部 typed signal 链，以及生产代码中 Event 消费者归零后删除 `Event` Autoload。

HEAD `592c7db` 只有 Phase 3 modular core；Main 仍启动旧 `RunController`。因此必须先执行下一节的 **Phase 3 production cutover**。它是 Phase 3 acceptance 的欠项和 Phase 4 的硬门槛，不能计为 Phase 4 成果。

本方案不授权提前进行 Effect/Buff registry 重构、visual composition、UI 视觉/字体治理或目录移动。

## Phase 3 production cutover（前置执行段）

### P3-A：依赖组合准备（尚不切生产）

先让新 composition 可被 Main integration GUT 独立构造，但 Main 的活动生产入口仍保持旧 `RunController`；因此这个准备 checkpoint 的唯一生产战斗完成路径仍是：

```text
Enemy/KillZone -> Event.enemy_killed -> old BattleSpawner.battle_completed
  -> old RunController._on_battle_completed
```

准备内容如下：

1. Main 创建或提供一个 `BattleSpawner`、一个初始 `Node2D` base `Enemies` container，并保证 `battle_spawner.enemy_container` 指向它。两者是 gameplay runtime node，不是 UI；Main/组合 helper 负责加入树、命名、所有权和失败回收。
2. `BattleGateway` 的 `level_parent` 明确为 Main；活动 `LevelDef.level_scene` 仍由 Gateway 挂到该 parent，base `Enemies` 只作为未激活关卡或清理后的恢复目标。
3. Main 提供以下三个 Callable，签名和失败语义固定：
   - `reset_battle: Callable()`：调用 `Main.reset_battle_state()`，清技能投射物并按当前 Loadout 重建 MarbleChain；
   - `release_floating_texts: Callable()`：安全解析 `/root/FloatDamageTextPool`，仅在节点存在且有 `release_all_active()` 时调用；缺失时可 no-op，不能持有旧 pool 引用；
   - `read_stat: Callable(stat_id: StringName, entity_id: StringName) -> Variant`：安全解析 `/root/StatSystem` 并调用 `get_stat(String(stat_id), String(entity_id))`；StatSystem/API 缺失时 composition configure 失败，不能悄悄用第二套常量替代。
4. 配置资源来源固定：
   - `BattleRewardConfig` 来自 `res://Run/default_battle_reward_config.tres`；
   - `RunFloorConfig` 来自 `res://Run/default_run_floor_config.tres`；
   - 资源按只读配置使用；若实现需要在运行时改字段，必须先 `duplicate(true)`，不能修改共享 preload 实例。
5. Main 每次创建 run-flow composition 时只创建 **一个** `RunRandomSource`。同一实例同时传给 RewardService、EventResolver、RunFlowController；后者再把同一实例交给 node policy/event flow/BattlePlanFactory。禁止为奖励、事件和节点各建 RNG，避免随机序列分叉。
6. `BattlePlanFactory` 使用当前默认内容路径；若 Main 提供 content override，必须先以完整 dictionary 调用 `BattlePlanFactory.configure(content)` 并检查返回值。没有 override 时不得为了“显式”而传入不完整 dictionary 覆盖默认内容。

### P3-A 的完整 configure 顺序

必须按以下顺序逐项检查返回值，前一步失败不得继续：

```text
run_scope.initialize(stat_system)

reward_service.configure(
  run_scope.loadout,
  run_scope.progression,
  run_scope.wallet,
  battle_reward_config,
  shared_random
)

event_resolver.configure(
  run_scope.wallet,
  shared_random
)

battle_gateway.configure(
  battle_spawner,
  base_enemies,
  Main,                              # level_parent
  Callable(Main, "reset_battle_state"),
  release_floating_texts_callable,
  read_stat_callable,
  Event                              # 仅 Phase 3 cutover 的 legacy marble source
)

run_flow_controller.configure(
  run_scope,
  battle_plan_factory,
  reward_service,
  event_resolver,
  run_floor_config,
  shared_random,
  battle_gateway
)
```

只有所有 configure、UI signal wiring 和临时 bridge wiring 都成功后，才允许调用 `run_flow_controller.start_run()`。

### 配置失败的反向清理

Main 必须有幂等的 `_dispose_run_flow_composition()` 或等价 helper，并按反向顺序清理：

1. 不调用 `start_run()`；拒绝 UI 意图并关闭/清空已绑定 presentation；
2. 断开所有 UI、SkillSlot、HUD、临时 Event bridge 和 controller signals；
3. 从树中移除/free `RunFlowController`，触发其 `_exit_tree()` 断 health 与 `RunBattleFlow`；
4. `RewardService.clear_active()`、`EventResolver.clear_active()`；
5. `BattleGateway.dispose()`，确保断开 spawner/legacy Event、清 active level、恢复 base container；
6. `BattleSpawner.clear_enemies()`，从树移除/free spawner 与 Main 为本次组合创建的 base `Enemies`；
7. 清空本次 factory/config/random/Callable 引用；若整个 Main 启动因此失败，再调用既有 `_discard_run_scope()`，不能留下半配置 Scope 或第二次 `_ready()` 可见的连接。

任何 configure failure、signal connect failure 或 `start_run()` failure 都走同一清理路径；不得靠场景退出“自然释放”掩盖连接泄漏。

### UI pure adapters 与 Main composition GUT

在切换生产入口前，NodeChoice、DraftReward、RunEvent、Upgrade/Inventory、Shop/DevilShop、Failure 必须成为 pure adapters：

- 只渲染 `RunNodeOffer`、`RewardOffer`、`EventPresentation`、`UpgradeOffer`、shop token 和 terminal state；
- 只发携带当前 `RunFlowToken`、`offer_id`、`option_id`、`draft_id`、`replacement_token` 等稳定 identity 的意图；
- 不计算下一 phase、奖励、事件 roll、升级、商店结算或 Boss 完成；
- token/offer 过期后禁用该 presentation，不把旧点击转成新命令；
- 不用代码创建 UI 结构或写布局/视觉属性；需要 scene wiring 时经 Godot 编辑器/Hastur 修改 `.tscn`。

Main composition GUT 必须实例化真实 Main 或专用 composition fixture，并断言：

- 唯一 RunScope 的 loadout/progression/wallet/health 被所有服务和 adapter 共享；
- BattleSpawner、base `Enemies`、level parent 和三个 Callable 均由 Main 提供；
- RewardService、EventResolver 与 RunFlowController 收到同一个 RNG；两个 config 来自指定 `.tres`；
- 任一 configure 注入失败时不 start，节点/连接/active level/敌人全部清理；
- 新 controller start 一次，旧 controller start 零次；生产树不同时存在两个 orchestrator；
- UI 意图只调用新 controller，stale intent 不推进状态。

### Phase 3 的短期 typed flow → Event lifecycle bridge

正式迁移 SkillController 到 typed source 属于 Phase 4。为使 Phase 3 cutover 后 SkillController 仍工作，Main 可创建一条**已登记、单向、无状态**的短期 bridge。新 flow signal 与旧 Event 签名不同，必须分别写专用 adapter，不能复用当前只处理零/单参数的 `_connect_run_signal()` helper：

```text
RunFlowController.battle_started(token: RunFlowToken, plan: BattlePlan)
  -> Event.battle_started.emit(String(plan.battle_id))

RunFlowController.battle_completed(
  token: RunFlowToken,
  battle_id: StringName,
  plan: BattlePlan
)
  -> Event.battle_completed.emit(String(battle_id))

RunFlowController.run_completed(token: RunFlowToken)
  -> Event.run_completed.emit()
```

bridge 忽略的 typed 参数只能用于降维兼容，不能反向查询新 flow 或保存状态。当前 SkillController 实际依赖 `battle_completed`/`run_completed`；`battle_started` 只在确认仍有旧消费者时保留。每个 adapter 都必须可显式 disconnect，登记在 migration ledger，并在 Phase 4 typed SkillController checkpoint 删除。`run_node_completed` 没有活动消费者，不为它制造 bridge。

### P3-B：原子 production cutover checkpoint

下列变更必须作为一个不可拆的可保留 checkpoint：

1. Main 的活动启动入口切到上述新 composition，`RunFlowController.start_run()` 成为唯一 start；
2. UI adapters、HUD、SkillSlot、失败重开都接到新 flow；SkillController 暂时只经专用 typed flow → Event bridge 保持兼容；
3. 在调用者清零后删除 `Run/run_controller.gd` 及其 UID，并删除 Main 对它的 preload/new/start 和旧 `_connect_run_signal()` 转发；不得保留可启动旧 orchestrator 或同名兼容壳；
4. 修复 `tests/Run/test_reward_service.gd:206-235` 的 active-draft 流程，使测试显式 clear/结算旧 draft，而不是放宽“不可覆盖 active draft”契约；
5. Main composition GUT、Phase 3 focused GUT、full GUT 均有本次原始日志；随后运行首战、普通奖励、节点/事件/商店/升级、Boss 完成、marble 失败与重开。

P3-B 可保留时的唯一生产完成路径是：

```text
Enemy/KillZone -> Event.enemy_killed -> BattleSpawner.battle_completed
  -> BattleGateway.battle_completed(token, battle_id, plan)
  -> RunBattleFlow -> RunFlowController
```

此时 `BattleGateway.legacy_event_source` 仍只适配 marble fall；SkillController bridge 只发布生命周期兼容事件。两者不得形成第二条 battle completion 结算路径。P3-B 未满足时 Phase 4 状态保持“未开始”。

## Phase 4 当前图与目标图

P3-B 后、Phase 4 开始时的活动图：

```text
Enemy / KillZone --enemy_killed--> Event --> BattleSpawner --> BattleGateway
KillZone ----------marble_fell----> Event --> Main + BattleGateway legacy marble adapter
MarbleChain ------chain_collision-> Event --> BuffManager
RunFlowController --typed bridge--> Event.battle_completed/run_completed --> SkillController
```

目标图：

```text
Main（组合/适配）
  ├─ RunFlowController
  │    └─ RunBattleFlow
  │         └─ BattleGateway（关卡激活、容器恢复）
  │              └─ BattleSession（唯一战斗生命周期所有者）
  │                   ├─ BattleSpawner（spawn protocol）
  │                   ├─ Enemy.defeated
  │                   └─ KillZone.marble_fell / enemy_fell
  ├─ BattleSession.accepted marble_fell ──> Main 链重建 adapter
  ├─ MarbleChain.chain_collision ─────────> BuffManager
  ├─ BattleSession.enemy_defeated ────────> BuffManager
  └─ RunFlowController lifecycle ─────────> SkillController / UI adapters
```

## Enemy 唯一 guarded command

HEAD `592c7db` 的 `Enemies/enemy.gd` 只有 `extends RigidBody2D`，尚无全局类型身份、`defeated` signal 或 `defeat()` command。P4-A 的第一步必须把真实脚本注册为全局类型；本方案统一选择 `class_name Enemy`，不再混用 preload 脚本常量、duck typing 或字符串 `is_class()` 作为 Enemy 身份：

```gdscript
class_name Enemy
extends RigidBody2D

signal defeated(enemy: Enemy, cause: StringName)
func defeat(cause: StringName) -> bool
```

`Enemy` 在本文所有 signal、数组、Callable 和断言中都指该 `class_name`。新增全局类后须先由 Godot 4.6.1 完成 import/脚本类缓存刷新，再解析 Spawner/Session 和 GUT；缺少或冲突的全局类注册是 P4-A 停止条件。

契约：

1. `defeat()` 是唯一能把 Enemy 从 alive 切为 defeated 的 command。首次成功先原子设置 `_death_emitted`/等价 guard，然后恰好一次调用 `buff_host.notify_host_death()`，再恰好一次发出 `defeated(self, cause)`，最后才安排 `queue_free()`，并返回 `true`；这四步的顺序不得交换。
2. health 归零必须调用 `defeat(&"health_depleted")`；KillZone 不直接发死亡、不先 `queue_free()`，而由 Session/local adapter 调用 `enemy.defeat(&"kill_zone")`。
3. 同帧 health 归零与 KillZone 竞争时，首个成功 command 决定 cause；后续调用返回 `false`，不再调用 `notify_host_death()`、不再发 signal，也不再触发 Buff 或完成计数。
4. Enemy 已 defeated、无效、已排队删除或所属 session 已 dispose 时，不得由 Session“补造”一个死亡事实。Session只消费 `defeated`，绝不合成死亡。
5. BattleSpawner.clear/dispose 可以清理未 defeated 敌人，但该维护操作不发布战斗击杀/Buff 事实。
6. `notify_host_death()` 的 exactly-once 与上述顺序是保留当前正常 health 死亡路径既有 Buff 行为，并把它统一到 KillZone/竞争路径；这是 Phase 4 信号迁移的一部分，不授权修改 `BuffHost` 的 `on_host_death` 分发内容、Buff 定义、registry、叠层或计时规则，后者仍属 Phase 5。

### P4-A 唯一 typed Enemy → Event bridge

P4-A 仍须保留 Event → BattleSpawner 的生产完成链，因此 Enemy typed surface 不能先以“零 producer”状态单独落地，也不能让新旧 emitter 并存。P4-A 在同一个不可拆 checkpoint 内完成以下替换：

1. `take_damage()` 的 health 归零分支只调用 `defeat(&"health_depleted")`；删除 Enemy 自身 `_emit_enemy_killed()`、`/root/Event` 查询和旧直接 `Event.enemy_killed` emit。
2. BattleSpawner 成为这条临时 bridge 的唯一所有者：它在旧 `start_battle()` 与 typed `start_batch()` 两条 spawn 路径中，都在 Enemy 暴露给活动容器前恰好一次连接 `Enemy.defeated`；专用 adapter 接受新签名 `(enemy: Enemy, cause: StringName)`，只在已注入或从 `/root` 安全解析的 `legacy_event_source` 上调用 `emit_signal(&"enemy_killed", enemy)`，丢弃 cause，不假定 Autoload 名是编译期全局，也不保存领域状态或反向查询 Enemy/Session。
3. bridge 必须在 batch rollback、`clear_enemies()`、reconfigure/dispose 时显式断开；同一 Enemy 重复注册不得产生第二条 adapter。P4-C 后它可暂时只服务未迁移的 BuffManager，P4-D 随 BuffManager typed 接线删除。
4. P4-A 尚不改 KillZone；其旧直接 `Event.enemy_killed` producer 保留到 P4-B，但不得再创建另一条 Enemy typed bridge。P4-B 把 KillZone enemy 分支改为调用同一个 `Enemy.defeat()` 后，才删除该 legacy direct producer。

以上四项与下述 Spawner/Session registration 是一个 checkpoint；任何“已有 `class_name`/signal 但没有 bridge”“bridge 与 Enemy 旧直接 emit 并存”或“bridge 已切但 Session/Spawner typed contract 未完成”的中间状态都不可保留。

## BattleSpawner typed batch contract

P4-A 锁定以下局部协议；方法名可在实现时等价调整，但 batch identity、同步注册确认和互斥 terminal result 不得弱化：

```gdscript
signal enemy_spawned(batch_id: int, entry_index: int, enemy: Enemy)
signal spawn_batch_sealed(batch_id: int, enemy_count: int)
signal spawn_batch_failed(batch_id: int, entry_index: int, reason: StringName)

# register_enemy.call(batch_id, entry_index, enemy) -> bool
func start_batch(
  group: BattleGroupDef,
  batch_id: int,
  register_enemy: Callable
) -> bool
```

1. 每个 batch 有 `OPEN -> SEALED` 或 `OPEN -> FAILED` 两种且仅两种 terminal 结果；`spawn_batch_sealed` 与 `spawn_batch_failed` 互斥，各自每批最多发一次。返回 `true` 只表示 `SEALED`，返回 `false` 只表示 `FAILED`。
2. `group`、有效 `enemy_container` 与有效注册 Callable 必须在检查零-entry 前通过；即使零-entry 也不能绕过容器/协作者契约。`group.enemy_entries.is_empty()` 是唯一合法的零-entry batch，它必须同步发 `spawn_batch_sealed(batch_id, 0)` 并返回 `true`，Session 可在 sealed 后同步完成；不得把“没有容器、空/null entry、entry.scene 为空、instantiate 失败或场景根不是 Enemy”折叠成零敌人成功。
3. 数组中的每个 entry 都是预期非空 entry。Spawner 必须先成功实例化为 `Enemy`，再同步调用 Session 提供的 `register_enemy`；Session 必须在返回 `true` 前记录 `(token, batch_id, instance_id)` 并连接该 Enemy 的 `defeated`。只有注册确认后，Spawner 才可把该 Enemy 暴露给活动容器并发 `enemy_spawned`。
4. 只有所有 entry 都完成上述注册，Spawner 才可 seal。任一 entry 失败时，Spawner 先把 batch 标为 `FAILED`、停止处理后续 entry 并同步发唯一一次 `spawn_batch_failed`；Session 的同步 handler 立即进入 failed terminal，撤销本批已完成的注册并断开 `defeated`。signal 返回后，Spawner 清理本批所有已实例化/已挂树 Enemy 并返回 `false`。清理不得调用 `Enemy.defeat()`、不得触发 Buff，也不得发 `completed`。
5. `FAILED` 后禁止再注册 Enemy、seal 或完成；迟到的 `enemy_spawned`、`defeated`、sealed/failed 重复回调只能 rejected/no-op。`SEALED` 后也禁止追加注册；完成只能由 Session 根据 sealed + live-set 规则决定，Spawner 不合成 Session completion。
6. `BattleSession.start()` 收到同步 failed/`false` 时返回 `false` 并清 active batch identity。Gateway 必须把它视为 `start` 失败：断开 Session/Spawner/KillZone，清理本批敌人和 active level，恢复 base `Enemies` container，清 token/plan，且不向 RunBattleFlow 发 `completed`。合法零-entry 的同步 `completed` 是成功路径，必须与该失败回滚可区分。

## BattleSession contract

```gdscript
signal started(token: RunFlowToken, plan: BattlePlan)
signal enemy_registered(token: RunFlowToken, enemy: Enemy)
signal enemy_defeated(token: RunFlowToken, enemy: Enemy, cause: StringName)
signal marble_fell(token: RunFlowToken, marble: RigidBody2D) # 仅 accepted 后发布
signal completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal callback_rejected(kind: StringName, reason: String)

func configure(spawner: BattleSpawner) -> bool
func start(plan: BattlePlan, token: RunFlowToken, kill_zone: Node) -> bool
func clear(restart: bool = false) -> void
func dispose() -> void
```

### BattleSession invariants

1. 同时最多一个 active `(token, battle_id, plan)`；active session 未终止时第二次 `start()` 拒绝且不覆盖状态。
2. 在调用可能同步 emit 的 `BattleSpawner.start_batch()` 前提交 active token/plan/batch identity，连接 spawner sealed/failed 与当次 KillZone，并提供本 batch 专用注册 Callable；同步成功、同步零-entry 完成和同步失败都不能丢失或串入下一 session。
3. live enemy 以当前 token + batch ID + instance ID 记录。注册 Callable 只接受当前 `OPEN` batch 的有效 Enemy，并必须先连接 `defeated`、写入 live set，再返回 `true` 和发布 `enemy_registered`；错误 batch、重复 instance、sealed/failed 后注册均返回 `false`。
4. Session 只在收到唯一匹配的 `spawn_batch_sealed` 后把 batch 标为 sealed；只有 sealed 且 live set 为空时允许 `completed`。先原子切 terminal/closed，再 emit，保证每 session 最多一次；合法零-entry 因此可以同步完成。
5. 收到唯一匹配的 `spawn_batch_failed` 时，Session 先进入 failed terminal，断开并清除本批全部 Enemy 注册与 live set，再使 `start()` 返回 `false`。failed 与 completed 互斥；failed 后任何注册、defeated、sealed 或 completed 尝试均 no-op/rejected。
6. Session 拥有 `accepted_marble_instance_ids`（或等价稳定 identity set）。收到 KillZone raw marble signal 时，验证当前 token、有效 `RigidBody2D`、`marbles` group，并以 `(token, marble.get_instance_id())` 去重；只有首次加入集合成功才发布 `marble_fell(token, marble)`。
7. Main 链重建和 RunFlowController health damage **只能消费 Session/Gateway 的 accepted `marble_fell`**，不得直接再订阅 KillZone 或 typed→Event 的 raw source。同一 body 双 `body_entered` 只能 health `-1`、链重建一次。
8. 新链 head 是新 instance ID，可在同一 session 后续被接受；旧 session/token 保存的 callback 即使对象 ID 相同也不得影响新 session。
9. Enemy/KillZone 的重复、迟到、错误类型回调均 no-op/rejected；不得改变 live set、health、Buff 或当前 RunState。
10. `clear()` 断开 enemy/spawner/当次 KillZone，清 live/accepted-marble sets 和 active/batch identity，保留可再次 start 的 spawner 配置；active level/base container 由 Gateway 恢复。
11. `dispose()` 幂等并进入不可 start 状态；断开所有连接、释放引用。dispose 后保存的旧 Callable 不能发业务 signal。

## Phase 4 垂直迁移与可保留 checkpoints

原则：先建立新协议，再迁 source，再切完成所有者。任何可保留 checkpoint 都必须有 **一条且只有一条**可工作的生产 battle completion 路径，并有 Main/composition evidence；不得在 Session/Gateway 接管前切断 Event 完成路径。

### P4-A：真实 Enemy typed surface + bridge + Session/Spawner protocol（不可拆、Session 未接管）

P4-A 内部按以下顺序实施和 review，但只能整体保留，不能拆成独立 checkpoint：

1. 先在真实 `Enemies/enemy.gd` 增加唯一 `class_name Enemy`、typed `defeated(enemy, cause)` 和 guarded `defeat(cause) -> bool`，把正常 health 死亡统一为 guard → `notify_host_death()` → emit → `queue_free()`。
2. 同一批建立 BattleSpawner 所有的唯一 `Enemy.defeated -> Event.enemy_killed` bridge，并删除 Enemy 自身旧直接 Event emit；旧生产 `start_battle()` 必须也为每个真实 Enemy 接好 bridge，不能只覆盖新 typed batch。
3. 新增 BattleSession；BattleSpawner 增加 `start_batch(group, batch_id, register_enemy)` 与带 batch/entry identity 的 `enemy_spawned`、互斥 `spawn_batch_sealed`/`spawn_batch_failed`。生产旧 `_ready() -> Event.enemy_killed`、`start_battle(group)` 和 `battle_completed(group_id)` 暂时保留，但 Enemy health 事实只经上述唯一 bridge 进入 Event。
4. typed batch 原子提交：每个 entry 先实例化为全局 `Enemy` 类型，再由 Session 同步注册并连接 `defeated`；全部成功才 seal。任一失败先断 Session 与 bridge 的已建连接，再清理整批；failed 后禁止注册/完成。只有 `enemy_entries` 真为空才是可同步完成的合法零敌人 batch。
5. P4-A focused GUT 必须加载并实例化真实 `res://Enemies/enemy.tscn`，不得用只带同名方法/signal 的 fake 代替，并断言：根实例 `is Enemy`；`defeat`/`defeated` 的 typed surface 可解析；bridge 和 Session 都在 Enemy 可死亡前连接；typed 0/1/N batch 的 live set 与 sealed/completed 顺序正确；部分失败后真实 Enemy 的 Session/bridge 连接均断开且已生成节点清理；每个 Enemy 的首次成功 `defeat` 只产生一次 `notify_host_death`、`defeated` 和 `Event.enemy_killed`，重复 command 不增加计数；旧 `start_battle()` 的 1/N 敌人兼容用例只在最后一个唯一 `defeated` 后发一次 Spawner completion。
6. 其余 focused GUT 覆盖无/失效 container、null/空 scene、instantiate 失败、非 Enemy root、首项失败、全部 entry 失败、合法零-entry、sealed/failed 重复，以及同步 failed 后 Session/Gateway fixture 的 level/base-container 回滚。P4-A 可准备并测试 Gateway 的非活动 typed start seam，但不得把 Session completion 接入 Main 生产。

P4-A 可保留时只有一条活动 production completion consumer chain：Enemy health 经唯一 typed bridge、KillZone 暂经旧 direct producer 汇入同一个 `Event.enemy_killed → BattleSpawner.battle_completed → BattleGateway → RunBattleFlow`；Main 不连接 Session completion。composition GUT 必须证明 Enemy 自身直接 Event emit 为 0、活动 Enemy typed bridge 每实例为 1、Spawner 的 Event completion consumer 为 1、Session production completion consumer 为 0，不能零推进或双推进。

### P4-B：KillZone / MarbleChain source slices

Enemy 的 `class_name`、`defeat`、`defeated`、death guard 和唯一 Enemy typed → Event bridge 已由 P4-A 完成，P4-B 不得重复实现或再建第二条 bridge。这里只保留两个可独立 review 的 source slice：

1. **KillZone slice**：enemy 分支从“直接 emit Event + queue_free”原子替换为类型检查后调用已存在的 `enemy.defeat(&"kill_zone")`，并删除 KillZone 的 legacy `Event.enemy_killed` direct producer；完成事实由 P4-A 的唯一 Enemy bridge 继续送入 Event。marble 分支发 typed raw `marble_fell(marble)`，短期 `typed raw -> Event.marble_fell(marble)` bridge 维持 Main 与 Gateway legacy marble adapter。
2. **MarbleChain slice**：MarbleChain 发 typed `chain_collision(collider, collision_type)`；短期 bridge 转成同签名 `Event.chain_collision` 维持 BuffManager。

所有 bridge 都登记 source、旧消费者、删除 checkpoint、connect/disconnect 和 GUT。P4-B 后 P4-A 的 Enemy bridge 是唯一 `Event.enemy_killed` producer，health 与 KillZone 都只能先经过 `Enemy.defeat()`；唯一生产完成链仍是 `Enemy.defeated → bridge → Event → BattleSpawner → Gateway → RunBattleFlow`。composition GUT 必须证明 Enemy/KillZone 旧直接 emit 均为 0、Enemy bridge 每实例为 1，且每个 typed 事实只进入 Event 一次。

### P4-C：BattleSession/Gateway 接管唯一完成路径

这是 Phase 4 的原子完成所有者切换：

1. BattleSpawner 生产改用 typed spawn protocol；删除其 Event.enemy_killed listener，并停止把 `battle_completed(group_id)` 作为 Gateway 的活动完成源。
2. BattleGateway 激活关卡后从当次 `ActiveLevel` 解析 `KillZone`，把它传给 `BattleSession.start(plan, token, kill_zone)`；缺失/类型错误，或 Spawner batch 在无 container、无效 entry/scene、非 Enemy/instantiate/注册失败时同步 failed，均须使 Gateway.start 返回 `false`，断开并清 Session/Spawner、清 active level、恢复 base container，且不发 completion。合法零-entry sealed 后的同步 completion 仍返回成功，不能被当作 spawn failure 回滚。
3. Gateway 只把 Session 的 accepted `completed(token, battle_id, plan)` 和 accepted `marble_fell(token, marble)` 转给 RunBattleFlow；删除 `legacy_event_source` 参数、字段、Callable 与测试 fake。
4. RunBattleFlow 保留 token/plan 二次校验；同步完成时先清 active identity 再 emit。RunFlowController 仍是奖励/Boss 路由和 health damage 的唯一所有者。
5. Enemy.defeated → Event.enemy_killed bridge 暂时只服务尚未迁移的 BuffManager，不再影响完成；MarbleChain bridge仍服务 BuffManager。
6. Main 尚未正式改直连时，若需要保留 Event marble 兼容，只允许 `BattleSession accepted marble_fell -> Event.marble_fell` bridge，删除 P4-B 的 KillZone raw marble bridge。这样 Main 每个 accepted body 只重建一次，Gateway/RunFlow 不再消费 Event marble。

切换前唯一完成路径：Event → BattleSpawner → Gateway。切换后唯一完成路径：Enemy.defeated → BattleSession → Gateway → RunBattleFlow。两条不能同时活动。composition GUT 必须证明旧 spawner completion/Event consumer 为 0、新 Session completion consumer 为 1，并覆盖真实 Main 首战。

### P4-D：迁移 Main、BuffManager、SkillController

可按小切片提交，但每个切片都保持 P4-C 的 Session 完成路径不变：

- **Main marble**：Main 直接消费 Session/Gateway accepted `marble_fell` 重建链；RunFlowController 消费同一 accepted signal扣血。删除 accepted marble → Event bridge。GUT 覆盖同 body 双 entered、health 只 `-1`、链只重建一次、旧 session callback 对新链/health 无效。
- **BuffManager enemy/chain**：显式 configure BattleSession.enemy_defeated 与当前 MarbleChain.chain_collision；链重建时先断旧 source。删除 enemy/chain typed → Event bridges。保持 BuffRegistry/叠层/计时规则不变，留给 Phase 5。
- **删除 wave 幽灵契约**：当前 `wave_completed` 没有生产 emitter，P4-D 直接删除 `Main/event.gd` 的 signal、BuffManager 的 Event connection、`_on_wave_completed()` 和无调用者 `dispatch(&"on_wave_completed", ...)` seam。不得把 BattleSession/战斗完成隐式映射成 wave completion；若未来需要 wave 语义，必须另行设计 typed identity、所有者与触发时点。该切片静态扫描生产 `.gd` 时 `wave_completed` 与 `on_wave_completed` 两个字符串都必须为 0。
- **SkillController lifecycle**：显式 configure RunFlowController typed `battle_started(token, plan)`、`battle_completed(token, battle_id, plan)`、`run_completed(token)`；重新 configure/_exit_tree 时断旧 source。删除 P3 的 typed flow → Event lifecycle bridge和 `_connect_battle_lifecycle()` Event 查询。

Enemy/Buff GUT 必须覆盖：正常 health、KillZone、同帧 health + KillZone 竞争和重复 command 中，只有一个成功 `defeat`，且 `buff_host.notify_host_death()`/每个 Buff 的 `on_host_death`、`defeated` 与完成计数都恰好一次；重复 command 返回 false；KillZone 不先 queue_free；已 queued/free/旧 session callback不合成死亡；N 敌人只在最后一个唯一 `defeated` 后完成一次。这里验证的是现有 Buff death hook 的保留，不进入 Phase 5 registry/规则重构。

### P4-E：bridge/旧 completion/Event 全清理

- 静态扫描生产 `.gd`：`/root/Event`、`get_node_or_null("Event")`、`_get_autoload_node(&"Event")`、`legacy_event_source`、typed→Event adapter、旧 `BattleSpawner.battle_completed` 活动消费者均为 0。
- 删除无消费者的旧 completion signal/handler、`project.godot` 的 Event 注册和 `Main/event.gd`（含 UID）；相关 tests 不再构造 Event fake。
- full GUT 与完整运行验收后，才把 Event 状态改为“已退役”。

### Checkpoint 路径审计表

| Checkpoint | 唯一活动生产完成路径 | 必需 composition evidence |
| --- | --- | --- |
| P3-A | 旧 Event → old Spawner → old RunController | 新组合未接 production；旧 Main 路径仍唯一 |
| P3-B | Event → Spawner → Gateway → RunBattleFlow | Main 只启动 RunFlowController；旧 RunController 为 0 |
| P4-A | Enemy.defeated → 唯一 bridge／KillZone legacy direct → Event → Spawner → Gateway → RunBattleFlow | 真实 `enemy.tscn is Enemy`；Enemy 旧 direct emit 为 0；每 Enemy bridge 为 1；Session 仅旁路；typed batch 原子失败有 focused evidence |
| P4-B | Enemy.defeated（health/KillZone）→ P4-A 唯一 bridge → Event → Spawner → Gateway → RunBattleFlow | Enemy/KillZone direct Event emit 为 0；没有新增 Enemy bridge；每次 defeat 只入 Event 一次 |
| P4-C | Enemy.defeated → BattleSession → Gateway → RunBattleFlow | Spawner Event/completion 旧路径为 0；Session consumer 为 1；同步 start failure 恢复 level/base container且不 complete |
| P4-D | 同 P4-C | Main/Buff/Skill 每批迁移后 bridge 数下降且 completion path 不变；wave 两个生产字符串为 0 |
| P4-E | 同 P4-C，无 Event | Event/bridge/legacy completion 静态与运行消费者均为 0 |

若某 checkpoint 同时有两条 completion consumer、没有活动 completion path，或缺 Main composition evidence，则不可保留，必须回滚该批。

## 测试矩阵

| 层级 | 场景 | 必须断言 |
| --- | --- | --- |
| Phase 3 composition | 所有 configure 成功/每一项失败 | 参数和共享 RNG 正确；失败不 start；节点/连接/关卡/敌人反向清理 |
| UI adapters | typed presentation 与 stale intent | 只转发稳定 identity；不复制规则；旧 intent 不推进 |
| Enemy typed scene | 实例化真实 `res://Enemies/enemy.tscn` | 根 `is Enemy`；唯一 `class_name Enemy` 可解析；typed signal/command 可连接调用；不直接查询/emit Event |
| Enemy unit | health、KillZone、同帧竞争、重复 command | `defeat()` 首次 true 后均 false；cause 首次胜出；`notify_host_death` → `defeated` → queue_free 顺序固定且各一次 |
| Enemy legacy bridge | 真实 Enemy 首次/重复 defeat、旧 1/N battle、clear/部分 batch rollback | 每实例只连接一次；每 Enemy 首次只 emit 一次 Event；重复为 0 增量；rollback/clear 后连接为 0；旧 Spawner 仅在最后一个唯一 defeated 后 completion 一次 |
| Enemy lifecycle | queued/free/clear/dispose | KillZone 不先 free；正常/KillZone/竞争/重复均只有一次 `on_host_death`；维护清理不合成 defeated/Buff/complete |
| KillZone unit | marble/enemy/其他 body，多次 entered | enemy 调 guarded command；raw marble typed；无直接 Event emit |
| BattleSpawner batch | 真实 Enemy 的 0/1/N、无 container、空/null scene、instantiate/非 Enemy、首项/部分/全部失败、合法零-entry | 每个真实 Enemy 先接 Session + bridge；失败全部断连清理；sealed/failed 互斥且各至多一次；failed 不 completed；合法零敌人同步完成 |
| BattleSession enemy | 真实 Enemy 的 0/1/N、同步 sealed/failed、重复/迟到 defeated | live-set 准确；failed 后拒绝注册/完成；Buff/complete exactly once；最后一个唯一死亡才完成 |
| BattleSession marble | 同 body 双 entered、新 head、旧 session callback | accepted set 去重；health -1；链重建一次；旧 callback 无效 |
| BattleSession lifecycle | clear/dispose/reconfigure | 连接断开；sets 清理；dispose 幂等；旧 Callable 不发业务 signal |
| Gateway integration | LevelDef、缺 Enemies/KillZone、同步 spawn/register failure、合法零-entry | 失败返回 false且清敌/level/token/连接并恢复 base container；不 complete；零-entry 成功同步 complete；Session 唯一 source |
| RunBattleFlow | 同步完成、重复 complete、wrong token/plan | 顺序稳定；只向 RunFlowController 完成一次 |
| RunFlow | normal/elite/boss、marble 到 health 0 | 奖励策略唯一；Boss only completion；accepted fall 每次只扣 1 |
| BuffManager | enemy/chain、链重建、wave ghost 删除 | 每个 typed 事实一次；旧链/source 断开；`wave_completed`/`on_wave_completed` 生产字符串为 0；不映射 battle completion，不改 registry 规则 |
| SkillController | battle/run lifecycle、reconfigure | typed 签名适配正确；规则一次；Event bridge/source 删除 |
| Main composition | 每个 checkpoint 真实活动图 | 一条完成路径；consumer 数正确；旧 orchestrator/bridge 符合台账 |
| Static contract | P4-A / P4-D / P4-E | P4-A 的 `class_name Enemy` 唯一、Enemy 直接 Event 查询/emit 为 0且 typed bridge 唯一；P4-D 的 `wave_completed`/`on_wave_completed` 生产字符串为 0；P4-E 的 Event、bridge、legacy completion consumer 均为 0 |

禁止为“尚未实现某类”人为写只验证文件缺失的失败测试。红灯必须来自真实行为差异，如双完成、错误 cause、同 body 扣血两次、链重建两次、旧 callback 推进新 session 或 dispose 后仍收到 signal。

## GUT 与运行验收

1. 每个 checkpoint 先静态审阅受影响 GDScript/场景，确认 GUT 可发现/解析，避免卡死无输出。
2. 依次运行最小 focused GUT：Phase 3 composition/UI、Enemy/KillZone、BattleSession/Spawner、Gateway/RunBattleFlow、RunFlowController、Main/BuffManager/SkillController。
3. focused 全绿后运行递归 full GUT。命令使用 Godot 4.6.1 与当前实施 worktree 的绝对 `--path`：

   ```powershell
   cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path <ACTIVE_WORKTREE> -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
   ```

4. 保存命令、HEAD、范围、scripts/tests/assertions、exit code 与完整 stdout/stderr 到 `docs/testing/evidence/`。只有 GUT 原始成功日志可标记测试 `PASS`；startup、import、静态扫描都不能替代。
5. GUT 通过后运行：首战、多敌人、正常死亡、Enemy 掉入 KillZone、同帧死亡竞争、同 marble 双 entered、health 到 0、奖励推进、Boss 完成、失败重开；验证无双完成、无迟到推进、无旧敌人/连接残留。
6. 若新增运行验收场景，须经 Godot 编辑器/Hastur 创建独立 `.tscn`；每个场景单独由 `godot-remote-executor` 运行。只有连接 `game` executor 时才截图，保存到 `E:\Projects\pinball_rogue\.codex\hud_screenshots`，不得使用 `.codex_validation`。

## Import / UID 要求

未来新增 BattleSession、bridge、测试或测试场景后，先让目标 Godot 4.6.1 项目完成 import，确认 `.gd.uid`/资源 UID 与引用解析，再运行 GUT。若必须移动资源，停止并移交 Phase 8；Phase 4 不手工改 UID 或移动目录。

## Rollback 与停止条件

每个 checkpoint 前后记录 `git status --short`、逐路径 diff、活动 completion path、consumer 计数、GUT 日志与 UID。只暂存本 checkpoint allowlist。回滚优先 revert 最近小 checkpoint 或恢复显式文件，不使用 `git reset --hard`，不覆盖无关改动。

满足任一条件立即停止：P3-B 未完成；`class_name Enemy` 缺失/冲突或真实 `enemy.tscn` 不能解析为 Enemy；P4-A 中 Enemy direct Event emit 与 typed bridge 同时存在、两者都不存在、同一 Enemy bridge 数不为 1，或把 Enemy surface/bridge/Session registration 拆成可保留 checkpoint；Main 同时启动新旧 orchestrator；checkpoint 没有或有两条 production completion path；同一 batch 同时 sealed/failed、terminal signal 重复、部分失败后遗留 Enemy/Session/bridge 连接或 failed 后仍注册/完成；Gateway 同步 start failure 后未恢复 level/base container；configure failure 留节点/连接；GUT 无法发现/解析或卡住；warning-as-error/signal 11 再现但无日志；同 Enemy 的 `notify_host_death`/Buff/defeated/Event/complete 重复；同 marble health -2 或链重建两次；旧 session callback 改变新 session；dispose 后仍回调；P4-D 后生产仍出现 `wave_completed`/`on_wave_completed`；Missing Script/Resource/UID；ObjectDB/RID 泄漏显著增加并妨碍判断。

## Phase 5–8 out of scope

- Phase 5：EffectManager/EffectRegistry、BuffManager/BuffRegistry 的 catalog/service 重构。
- Phase 6：`Game/Bootstrap/game_main.tscn`、`run_scope.tscn` 与最终 visual composition root。
- Phase 7：UI 结构/视觉、运行时属性写入、字体与视觉截图治理。
- Phase 8：目录重排、资源移动/重命名与 UID 迁移。

Phase 4 只允许为信号注入修改必要的既有场景接线，不把上述工作提前包装进本阶段。
