# Phase 5 → Phase 6 交接文档

## 一句话总结

Effect 与 Buff 收敛为两个边界清晰、单向依赖（Effect→Buff 允许、Buff→Effect 禁止）的独立系统：删除生产零调用的 `BuffManager` 与全局 buff 死代码，debuff 构造统一走 `BuffRegistry`，毒循环反转为 typed 事件，遗物脚本表合并到 `EffectRegistry`。递归 full GUT 148/148 通过。

## 起点与终点

- 起点 HEAD：`814ed5d`（Phase 4 完成，Event autoload 已退役，唯一战斗完成路径已建立）。
- 终点：Phase 5 五个 checkpoint（5-A…5-E）全部完成；本交接随 Phase 自动化流水线提交入库。
- 规格来源：GitHub Issue #9（`ready-for-agent`），用户已确认两项关键决策：
  1. `BuffManager` **YAGNI 整体删除**（不保留全局 buff 机制）；
  2. debuff 构造**统一走 `BuffRegistry`**。

## 完成的变更（按 checkpoint）

### 5-A 删除 BuffManager 与 Buff 域清理
- 删除 `Buffs/buff_manager.gd`（+UID）、`damage_up/speed_up/shield` 定义（+UID）、`project.godot` 的 `BuffManager` autoload。
- 删除 `BuffDef.effect_script` 字段（从未被赋值的第二扩展模型）；内联生命周期钩子为唯一机制。
- `Main` 移除 `_reconfigure_buff_manager`/`_clear_buff_manager_sources` 及其全部调用——该接线 feeding 的是无消费者的死路径，删除零行为变化。
- `BuffRegistry` 移除三个全局 buff、登记 `fire_burn_debuff`；`get_buff_def` 只保留 BuffDef 单一分支。

### 5-B debuff 构造统一走 BuffRegistry
- 绿/蓝/火弹珠经新增 `Marble.make_buff(id)`；`frost→frozen`、fire_burn 死亡扩散经 `BuffDef.make_buff(id)`；`poison_culture`/`ice_hammer` 经各自 `_make_buff(id)`。全部不再 `preload` buff 脚本。
- `BuffRegistry` 成为 Buff 定义唯一来源。

### 5-C 毒循环反转（核心解耦）
- `BuffHost` 新增 typed 信号 `buff_ticked(buff_id: String, host: Node)` 与 `notify_ticked()`。
- `poison_debuff` 不再调用 `EffectManager`；改为经宿主门面 `Enemy.notify_buff_ticked` → `BuffHost` 发事件 → `Enemy._on_buff_ticked` 单向把 poison tick 转发给 `EffectManager.on_poison_tick`。
- 静态审计：`Buffs/**` 对 `EffectManager`/`on_poison_tick` 引用为 0。

### 5-D 遗物脚本表合并
- `EffectManager` 从 `EffectRegistry` 取脚本表，删除自身重复的 `EFFECT_SCRIPTS` 与死的 `_get_owned_effect_types`。
- `EffectRegistry` 删除读取 Phase 2 已删 `relic_items` 的 `get_relic_effect_types`，新增 `has_relic_script`。

### 5-E 词汇 / 台账 / 证据
- `CONTEXT.md` 增补「状态修饰（Buff）」「遗物效果（Effect）」词条与单向依赖约束。
- 台账阶段状态表与提交事实更新；证据日志入库。

## 当前架构事实（Phase 6 继承的基线）

- **Buff 域**：`BuffDef`（数据+内联钩子）+ `BuffHost`（每宿主运行时唯一所有者，发 `buff_ticked`）+ `BuffRegistry`（定义唯一来源：poison/frost/frozen/fire_burn）。无全局 buff 服务。
- **Effect 域**：`EffectRegistry`（遗物脚本唯一表）+ `EffectManager`（从 Loadout 同步实例、分发战斗事件）。
- **单向规则**：Effect→Buff 仅经 `Enemy/BuffHost` 门面（`add_buff`/`remove_buff`/`trigger_fire_relic_hit`）；Buff→Effect 禁止，Buff 只发 typed 事件。
- **战斗完成路径**（Phase 4 建立，Phase 5 未变）：`Enemy.defeat → Enemy.defeated → BattleSession → BattleGateway → RunBattleFlow → RunFlowController`。
- Main 只启动 `RunFlowController`；UI 经 `RunFlowUIAdapter`。

## 验证状态

- 递归 full GUT：**148/148，1649 asserts，exit 0**（`docs/testing/evidence/phase5-full-gut.log`，27 scripts）。
- 新增测试：`tests/Buffs/test_buff_state_effects.gd`（registry 单一来源/弹珠施加/冰霜转冻结/燃烧余烬扩散）、`tests/Buffs/test_poison_inversion.gd`（typed tick 事件/无 tick 不扩散/tick 到达 poison_culture）、`tests/Effects/test_effect_registry_manager.gd`（脚本表唯一来源/EffectManager 从 registry 实例化）。
- headless 生产 smoke：exit 0（`docs/testing/evidence/phase5-headless-smoke.log`）。
- 行为不变性：状态效果（毒/冰霜/冻结/燃烧）伤害、叠层、扩散、过期与遗物触发结果均未改变（仅改构造来源与解耦路径）。

## 已知限制 / 遗留

- **交互式 gameplay 截图未取得**：Hastur broker 未运行、无 `game` executor；行为正确性由真实场景 GUT 覆盖，截图待 broker 可用后补。
- 全局/玩家 buff（damage_up/speed_up/shield）已删除；若未来内容需要全局 buff，应另行设计一个有明确授予源的服务，不要复活旧 `BuffManager`。
- 状态效果数值依赖 `StatSystem` 注册（裸测试中未注册 stat 走 fallback），测试按可观察 buff 状态断言而非精确伤害。

## Phase 6 注意事项

- Phase 6 = 正式可视化 Bootstrap composition（`game_main.tscn` / `run_scope.tscn` 与 scoped 生命周期验收）。
- 组合 `RunScope`/`RunFlowController`/`BattleGateway` 时沿用现有 `_setup_run_flow_composition` 的 configure 顺序与幂等反向清理；`BuffRegistry`/`EffectRegistry` 为 autoload，敌人 debuff 与遗物效果均已走 registry，无需在 Bootstrap 额外接线。
- 保持单向依赖不变式：任何新增 Buff 不得引用 Effect 域；需要触发遗物逻辑时经宿主 typed 事件。
- 停止条件（沿用台账）：Effect↔Buff 反向调用回归、状态效果行为改变、debuff 来源绕过 Registry、删除项遗留引用、focused/full GUT 卡住或失败时，停在当前 checkpoint 先消除风险。
