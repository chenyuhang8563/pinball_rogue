# 遗物、弹珠与技能系统勘察报告

> 范围：当前 `Game/Bootstrap` 运行时架构（Godot 4.6）。
>
> 本文依据源码和资源的静态审阅整理，旨在为后续遗物、流派和数值设计提供事实基线；不代表运行时试玩或 GUT 执行结果。

> 增量更新 2026-07-23：刺客弹珠与「方位破绽 / 暴击」核心循环（M1）已实现并通过 GUT。下文「暴击与方位破绽（刺客 M1）」小节记录其事实基线；首批 5 件暴击遗物仍为设计稿（M2）。

## 结论摘要

当前项目已有完整的单局流程、背包、成长、商店、战斗和状态异常骨架。构筑的可用协同集中在火、毒、霜、回响、爆炸五类弹珠机制与四个遗物之间；技能只与弹珠 Head 和有限的全局伤害乘区相连。

优点是遗物 Effect、Buff 定义、成长和战斗生命周期均有相对清晰的单一入口。主要限制是：弹珠链只有一个物理 Head、遗物/物品池硬编码分散、不同伤害来源未统一、护甲/闪避等多个 Stat 尚未接入，以及物品 identity 禁止同类弹珠或遗物叠层。暴击已由刺客方位破绽接入（见下文「暴击与方位破绽（刺客 M1）」），但通用 `crit_rate`/`crit_damage` 仍无消费者。

## 运行时入口与全局服务

- 主场景：`Game/Bootstrap/main.tscn`，由 `Game/Bootstrap/main.gd` 组合运行时对象。
- `RunScope` 持有一局的 `Loadout`、`ItemProgression`、`RunWallet`、`RunHealth`。
- Autoload：`Localization`、`EffectManager`、`EffectRegistry`、`StatSystem`、`BuffRegistry`、`FloatDamageTextPool` 等。
- 没有 `Event` Autoload，也没有全局 `Inventory` 或 `Shop` 单例。
- 关键的跨系统通信主要是 typed signal 和 `EffectManager` 的定向分发，而不是统一事件总线。

## 遗物系统

### 数据和注册

所有物品都使用 `Content/domain/item.gd` 的 `Item : Resource`。它包含 `id`、本地化 title/description、图标、价格、`ItemType`、`EffectType`、弹珠类型和技能定义引用。

`Item` 不包含 rarity、掉落权重、标签、可叠层次数或获取渠道等字段。遗物只是 `ItemType.RELIC` 的 Item，当前没有独立 Relic 数据类。

运行时遗物脚本仅在 `Combat/effects/effect_registry.gd` 注册四种：

| EffectType | ID | 名称 | 物品资源 | 效果实现 |
|---|---|---|---|---|
| `LIGHTNING_CHAIN` | `lightning` | 闪电链 | `Content/data/lightning.tres` | `Combat/effects/lightning_effect/lightning.gd` |
| `FIRE_BELLOWS` | `fire_bellows` | 风箱核心 | `Content/data/fire_bellows.tres` | `Combat/effects/fire_bellows/fire_bellows.gd` |
| `POISON_CULTURE` | `poison_culture` | 瘟疫培养皿 | `Content/data/poison_culture.tres` | `Combat/effects/poison_culture/poison_culture.gd` |
| `ICE_HAMMER` | `ice_hammer` | 碎冰锤 | `Content/data/ice_hammer.tres` | `Combat/effects/ice_hammer/ice_hammer.gd` |

`EffectManager` 监听 `Loadout.changed` 和 `ItemProgression.item_progressed`，扫描已持有 relic 并从注册表实例化 Effect。一个 effect_type 只保留一个 Effect 实例；若同 effect_type 理论上出现多个持有物品，取最高等级与任一觉醒状态。

### 遗物条目与数值

| 遗物 | 触发条件 | Lv1 / Lv2 / Lv3 | Lv4 觉醒 | 价格 / 稀有度 |
|---|---|---:|---|---|
| 闪电链 | Head 撞敌人时 | 链伤害 1 / 3 / 5 | 每次触发寻找目标 3 次；目标不足时可在敌人间回跳 | 20 / 无稀有度 |
| 风箱核心 | 命中前已经燃烧的敌人，且此次命中后仍活着 | 每 4 / 3 / 2 次合格命中触发一跳额外燃烧 | 额外燃烧不消耗剩余燃烧 tick | 20 / 无稀有度 |
| 瘟疫培养皿 | 任一敌人的 poison tick | 每 3 次 tick 后向最近 1 / 2 / 3 个敌人施加毒 | 可刷新已有中毒目标 | 20 / 无稀有度 |
| 碎冰锤 | 命中前已经冻结的敌人，且该敌人仍活着 | 半径 100 内各受 5 / 8 / 12 伤害，并施加 1 层 Frost | 改为施加 3 层 Frost | 20 / 无稀有度 |

遗物等级配置在 `Content/data/relic_configs/*.tres`，成长入口在 `Loadout/application/item_progression.gd`。所有物品经历 Lv1、Lv2、Lv3、Lv4（觉醒），但遗物的 Effect 本身只将数值等级 clamp 至 1–3；Lv4 用单独的 `awakened` 布尔状态处理。

### 遗物事件路径

```text
Enemy 与 marble Head 碰撞
  -> EffectManager.on_enemy_hit_by_marble()    # 闪电链
  -> MarbleChain.get_total_damage()            # 应用弹珠状态、聚合直接伤害
  -> Enemy.take_damage()
  -> EffectManager.on_enemy_hit_resolved()     # 风箱核心、碎冰锤

PoisonDebuff tick
  -> BuffHost.buff_ticked
  -> Enemy._on_buff_ticked
  -> EffectManager.on_poison_tick()            # 瘟疫培养皿
```

### 获取渠道

| 渠道 | 遗物可得性 |
|---|---|
| 精英战奖励 | 四种全部；奖励为遗物和 35–40 金币共同领取 |
| 普通商店 | 四种全部存在于场景导出的 `shop_item_pool` |
| 节点奖励 | 四种全部存在于 `RewardService.DEFAULT_NODE_ITEM_PATHS` |
| 恶魔商店 | 默认池只有闪电链 |
| Debug 发放 | 四种全部 |

遗物默认容量为 3。容量通过 `relic_slot_count` stat 读取，但当前基础值为 3，未发现有任何物品修改该容量。

## 弹珠系统

### 链的真实模型

当前不是多个独立物理球，而是一条“一个物理 Head + 多个视觉段”的链：

```text
MarbleChain (Node2D)
├─ Head: Marble / RigidBody2D，唯一物理体、唯一碰撞来源
└─ BodyContainer
   └─ ChainSegment: Node2D + Sprite2D，仅轨迹跟随
```

- Head 使用 `Combat/marbles/marble.tscn`：半径 8、质量 0.2、重力 0.3、反弹 1.0、默认最大速度 800。
- Body `ChainSegment` 没有碰撞体、刚体或 Area2D，不能独立撞敌人、撞挡板或掉出场地。
- `MarbleChain` 用轨迹历史让 Body 以 24 像素间距跟随 Head。
- 掉入 KillZone 后，局内生命减 1，Head 和整条链销毁，再以当前 Loadout 重建。

### 弹珠条目

| ID | 类型 | 价格 | 直接贡献 | 效果 |
|---|---|---:|---:|---|
| `dark_marble` | DEFAULT | 0 | Head 基础 1 | 初始暗影 Head；升级直接覆盖暗影伤害 |
| `brown_marble` | BROWN | 20 | 2 | 非敌人碰撞叠回响，3 层后下次敌人命中附伤 |
| `bomb_marble` | BOMB | 30 | 0 | Head 撞敌人时爆炸 AOE |
| `green_marble` | GREEN | 25 | 1 | 命中施加 10 秒毒 |
| `blue_marble` | BLUE | 22 | 2 | 命中施加 Frost，6 层转 Frozen |
| `fire_marble` | FIRE | 25 | 1 | 命中施加递减燃烧 |
| `assassin_marble` | ASSASSIN | 25 | 1 | 链中在场时洞察敌人方位破绽；从破绽方向命中 ×1.5 暴击（见暴击小节） |

### 弹珠成长

| 弹珠 | Lv2 | Lv3 | Lv4 觉醒 |
|---|---|---|---|
| 暗影 | 伤害 2 | 伤害 3 | 伤害 4 |
| 炸弹 | 爆炸伤害 5 | 爆炸伤害 8 | 半径 100、视觉 x4 |
| 毒液 | 每跳 2 | 每跳 4 | 每 0.5 秒跳 4 |
| 大地 | 回响附伤 2 | 回响附伤 4 | 附伤 8、持续 15 秒、触发只消耗 1 层 |
| 冰霜 | Frost 至少 4 秒 | 附伤等于 Frost 层数 | 每次蓝珠命中加 2 Frost |
| 火焰 | 燃烧 4 秒 | 燃烧 5 秒 | 敌死时传播剩余燃烧 |
| 刺客 | 段伤 2 | 段伤 3 | 段伤 3 + 双方位破绽 |

### 伤害与状态

普通 Head 碰撞的原始伤害由以下构成：

```text
暗影 Head 伤害
+ 所有 ChainSegment 的直接伤害
+ 蓝珠 Frost 附伤（仅 Lv2 后）
+ 棕珠满层回响附伤
```

再经过：

```text
final_damage = round(base_damage * damage_multiplier)
实际扣血 = max(0, final_damage - enemy_armor)
```

炸弹使用 AOE 独立路径；毒、燃烧、碎冰、闪电、魔法飞弹直接调用 `Enemy.take_damage()`，会吃护甲但不会走通用 `final_damage` 乘区。

`DamagePipeline.resolve_pre_armor` 在既有 `resolved` 结果（公式路径或原始取整路径）之后再乘 `packet.crit_multiplier`（默认 1.0），因此非暴击包保持与旧实现完全相同的取整边界；方位破绽暴击即在敌人侧把该乘数置为 1.5 后写入包。

当前没有元素克制、元素抗性或闪避的实际实现；暴击已由刺客方位破绽接入（见下文），但通用的 `crit_rate`、`crit_damage`、`dodge_rate` 等 StatDef 仍无运行时消费者。

### 异常状态

| 状态 | 行为 |
|---|---|
| Poison | 10 秒，默认每秒 2；重复施加刷新而不叠层 |
| Frost | 最多 6 层；满层转 Frozen。代码实际持续至少 5 秒，即使 `blue_frost_duration` 基础值为 2 |
| Frozen | 4 秒；敌人变为可被 Head 推动的低摩擦冰块 |
| Burn | 默认立即造成 3，再每秒造成 2、1；重复施加忽略 |

### 挡板与场地

- 左右挡板由方向键控制，目标角度 90°，升降速度各 700°/秒。
- HitSensor 对 Head 施加 80–360 的切线冲量，同一球 0.08 秒冷却。
- 墙反弹 0.3；平台反弹 1.0；无反弹墙读取 `bounceless_wall_bounce`，基础 0.2。
- 大地弹珠将所有非敌人碰撞都视为回响充能，包括挡板、墙、平台等。

## 暴击与方位破绽（刺客 M1）

刺客流派的核心循环已落地（里程碑 1）：刺客弹珠在链中**任意段**在场即让敌人显示方位破绽（head 不特殊）；玩家规划弹道从破绽方向切入造成暴击。

- 在场与数量：`assassin_weak_point_count`（OVERRIDE，写在 `marble_chain` 实体）由 `item_progression.gd::_apply_assassin_weak_point_count` 依据 `get_chain_items()` 实时设置——0 隐藏 / 1 常规 / 2 觉醒双破绽，并监听 `marble_loadout_changed` 重同步（掉球重建链不闪烁）。
- 状态组件：`Combat/crit/weak_point.gd`（值对象，4 方位 UP/RIGHT/DOWN/LEFT → 中心角 -90/0/90/180，kind BASE/PRISM）、`weak_point_host.gd`（敌人子节点，类比 BuffHost：按 stat 同步破绽数、纯查询 `try_resolve_crit`、命中换边 `consume_crit`、信号 `crit_landed`）、`weak_point_visual.gd` + `.tscn`（按方位贴敌人轮廓的像素标记，`z_index` 在敌人之上；**视觉父节点是敌人 Node2D 而非 host**——host 为普通 `Node` 无 transform，挂在其下会使标记卡在世界原点 / 屏幕左上角）。
- 数值 `Core/stats/data/crit/*.tres`：`weak_point_crit_multiplier` 1.5、`weak_point_tolerance_deg` 15、`perfect_crit_multiplier` 1.75、`perfect_crit_window_deg` 5（完美窗 M1 默认关闭，留给磨刀石觉醒）、`assassin_weak_point_count` 0、`assassin_segment_damage` 1。
- 结算：`enemy.gd::_on_body_entered` 用 `to_local(body.global_position).angle()` 取接触方位 → `try_resolve_crit`（角距 ≤ 容差）→ 命中写 `packet.is_crit/crit_multiplier/crit_source` 与 `floating_style=&"crit"` 并 `consume_crit`（基础破绽换边，避免回原方向 / 与其它破绽重叠）。一次接触至多一个破绽、一次暴击。
- 浮字：`Combat/presentation/crit_floating_text.tscn`，由 `float_damage_text_pool` 的 `crit` 样式选取（Quaver 16px 浮动数字例外）。
- 视觉素材：`Assets/Crit/weak_point_{base,prism,perfect_core}.png`（32×32 透明像素，经 image-cli 生成，遵循 `critical.md` §12：银白 / 低饱和青、紫白双层、细金针芒；按方位旋转朝外）。
- 投放：`Content/data/assassin_marble.tres`（MARBLE，`marble_type` ASSASSIN，price 25，tags `marble/assassin/producer`，weight 100），经 `ContentRegistry` 自动进入奖励与商店。
- 成长：`item_progression.gd` 的 ASSASSIN `UPGRADE_VALUES`（段伤 1/2/3，觉醒 3）。
- M1 边界：完美暴击与 PRISM 棱镜破绽为 M2 骨架；只有刺客在场才存在破绽（无刺客即无破绽暴击）；战斗中途加入刺客时**已在场敌人不即时重同步**，下一场战斗的新敌人生效。
- 测试：`tests/Combat/crit/`（`test_weak_point_host` 纯逻辑、`test_assassin_crit_integration` 真实敌人、`test_assassin_progression`、`test_assassin_display_e2e` 含「标记跟随敌人 global_position、不卡左上角」回归）与 `tests/Combat/damage/test_damage_pipeline_crit.gd`。

## 技能系统

技能为 `ItemType.SKILL`，由 `Item.skill_definition` 指向 `SkillDefinition`。默认只有一个技能槽；输入为 `Q` / `active_skill`。

| ID | 方式 | 初始参数 | 升级 |
|---|---|---|---|
| `dash` / 冲刺 | 即时 | 3 充能、每格 5 秒；朝最近敌人施加 200 冲量，0.3 秒上限 850 | Lv2 冷却 4；Lv3 冷却 3 + 2 秒 x1.2 链伤；Lv4 x1.4 |
| `magic_missile` / 魔法飞弹 | 按住瞄准、释放 | 3 充能、每格 4 秒；伤害 10、速度 220、寿命 4 秒；瞄准时全局时间倍率 0.15 | Lv2：3 秒/15；Lv3：2.5 秒/18；Lv4：2.5 秒/24、寿命 6 秒 |

`SkillRuntime` 是逐格充能恢复，不是单一整体冷却。暂停、焦点丢失、Head 掉落、战斗开始/结束、Run 结束均会取消瞄准并清理飞弹。

### 技能联动边界

- Dash 操作同一个 Marble Head；Lv3 以上通过 `damage_multiplier` 修改普通链命中和当前炸弹路径。
- Magic Missile 是独立刚体，直接调用 `Enemy.take_damage()`。
- 飞弹不触发 `MarbleChain.get_total_damage()`、火/毒/霜状态、闪电链、风箱或碎冰锤，也不享受 Dash 的链伤乘区。
- 技能没有元素、能量、遗物修正或“命中事件”接口。

## 构筑协同现状

当前可确认的协同：

1. 火焰弹珠 + 风箱核心：持续撞燃烧目标，加速燃烧结算。
2. 毒液弹珠 + 瘟疫培养皿：毒跳 3 次后扩散。
3. 冰霜弹珠 + 碎冰锤：叠满冻结后，再命中触发碎冰 AOE。
4. 大地弹珠 + 挡板/墙：反弹积回响，满层转化为命中附伤。
5. Dash Lv3+ + 普通命中/炸弹：短时全伤乘区。

协同主要围绕特定 Buff ID 和具体脚本实现，不存在通用 tag、伤害类型、事件类别或元素系统。

## 数值和成长曲线

### 局内资源与奖励

- 初始：100 金币、10 生命。
- 掉球：-1 生命；生命为 0 时失败。
- 普通战奖励：2 个互斥选项；金币/弹珠/技能权重 50/35/15；金币 15–20。
- 精英奖励：遗物和 35–40 金币都可领取。
- 普通商店：价格为 `round(item.price * buy_price_multiplier)`；出售为 `floor(price * 0.5)`。
- 恶魔商店：3 个库存，1 HP=5 金，可购买目标 Lv2/Lv3/Lv4，倍率 1.5/2/3。

### 敌人曲线

```text
弱敌 HP   = 15 + (floor - 1) * 5
强敌 HP   = 40 + (floor - 1) * 5
精英主怪  = floor(强敌 HP * 1.5)
Boss      = 固定 240
```

| 战斗 | 编队 |
|---|---|
| 第一层弱战 | 3 个弱敌，15 HP |
| 普通强战 | 5 个强敌 |
| 精英 | 1 个精英主怪 + 2 个强敌 |
| 第 12 层 Boss | 240 HP Boss + 2 个弱敌 |

第 3/6/9 层保证普通商店；第 8/11 层保证恶魔商店。节点随机权重为普通战 30、事件 30、精英 20、升级 20。

## 设计缺陷与风险

### 高优先级

1. **链首物品被忽略。** `MarbleChain.build_chain()` 固定创建暗影 Head，Body 从 `items[1]` 开始。重排后，把蓝/火/炸弹放第一位不会让它成为 Head，第一项只影响链长度。
2. **多弹珠不等于多物理球。** Body 是纯视觉；所有物理、碰撞、掉球、挡板操作只作用于一个 Head。
3. **技能和遗物体系割裂。** 飞弹没有弹珠命中事件，也没有遗物/元素联动。
4. **伤害结算不统一。** 普通命中、DOT、爆炸、遗物和技能走不同路径；后续“全伤害增幅”“DOT 增伤”“技能触发遗物”容易遗漏或重复计算。
5. **很多 Stat 是空壳。** 闪避、护盾、穿甲、敌人移动、run_health 等尚无完整消费者（暴击已由刺客方位破绽接入）。

### 内容扩展风险

6. **没有稀有度、标签、权重或集中内容注册表。** 新遗物需要手改枚举、注册表、资源、多个奖励/商店池与 Debug 清单。
7. **渠道池分散且不一致。** 普通战奖励没有 Blue；节点奖励没有 Blue/Dark/技能；恶魔商店只有 Lightning 遗物。
8. **瘟疫培养皿文案的“附近”与代码不符。** 代码没有传播距离上限，会在全体敌人中选最近者。
9. **物品 identity 禁止堆叠与变体。** 弹珠按 `marble_type` 去重，遗物按 ID 去重，Effect 又按 effect_type 合并；无法支持同类多枚、同色变体或可叠层遗物。
10. **重开保留上一局所有物品。** 这是显式行为，但当前没有 meta-progression 存档或规则说明，需要确认是否符合产品定位。
11. **商店随机不使用 RunRandomSource。** 普通/恶魔商店直接调用全局随机，导致 seed 不能复现整局。
12. **燃烧与风箱存在时序门槛。** 命中前先读取是否燃烧，所以首次施加火焰的命中不会同时触发风箱。
13. **冰霜时长存在数值失效区。** Frost 固定至少 5 秒，基础 2 和升级到 4 都没有实际时长收益。

## 测试覆盖现状

已有 GUT 测试覆盖：Effect/Buff 注册、毒 tick 的 typed event 桥接、火焰传播、成长等级、奖励事务、敌人 HP 编队、BattleSession 的批次/回滚/掉球身份边界，以及暴击方位破绽解析、管线暴击乘区与刺客成长 / 在场显隐的端到端接线。

缺少行为级测试：

- 闪电链、风箱核心、碎冰锤的目标/阈值/觉醒效果；
- MarbleChain 的实际总伤害、回响、炸弹、链首排序；
- Dash 和 Magic Missile 的充能、瞄准、伤害和跨系统联动；
- 火/毒/冰遗物的端到端协同；
- 伤害乘区、护甲、DOT、技能之间的统一性。

对应测试目录：`tests/Combat/effects/`、`tests/Combat/status/`、`tests/Combat/crit/`、`tests/Combat/damage/`、`tests/Loadout/`、`tests/Run/`、`tests/Combat/battle/`。

## 后续设计建议

在新增大量遗物或流派之前，优先建立：

1. 统一 `DamageContext` 和单一伤害结算服务，包含来源、元素、是否 DOT/技能/遗物、暴击和目标状态。
2. 数据化的 `ContentRegistry`，至少含 rarity、tags、权重、可叠层规则和获取渠道。
3. 通用事件分类，例如 `on_marble_hit`、`on_flipper_hit`、`on_damage_dealt`、`on_enemy_defeated`、`on_status_applied`、`on_skill_hit`。
4. 明确弹珠链首的产品语义：它是“主球”，还是始终存在的暗影 Head 加效果段；并据此限制或修复排序。
5. 将商店随机注入 `RunRandomSource`，以支持种子复现和稳定测试。

## 关键文件索引

### 内容、背包与成长

- `Content/domain/item.gd`
- `Content/data/*.tres`
- `Content/data/relic_configs/*.tres`
- `Loadout/domain/loadout.gd`
- `Loadout/domain/marble_loadout.gd`
- `Loadout/application/item_progression.gd`

### 遗物、Buff 与数值

- `Combat/effects/effect_registry.gd`
- `Combat/effects/effect_manager.gd`
- `Combat/effects/lightning_effect/lightning.gd`
- `Combat/effects/fire_bellows/fire_bellows.gd`
- `Combat/effects/poison_culture/poison_culture.gd`
- `Combat/effects/ice_hammer/ice_hammer.gd`
- `Combat/status/buff_host.gd`
- `Combat/status/buff_registry.gd`
- `Combat/status/buffs/*.gd`
- `Core/stats/stat_system.gd`
- `Core/stats/stat_registry.gd`
- `Core/stats/formulas/damage_formula.gd`
- `Core/stats/data/**/*.tres`

### 弹珠、技能、战斗和流程

- `Combat/marbles/marble.gd`
- `Combat/marbles/marble_chain.gd`
- `Combat/marbles/chain_segment.gd`
- `Combat/battle/enemies/enemy.gd`
- `Combat/battle/table/flipper/flipper.gd`
- `Combat/skills/skill_controller.gd`
- `Combat/skills/skill_runtime.gd`
- `Combat/skills/Dash/dash_skill_executor.gd`
- `Combat/skills/MagicMissile/magic_missile.gd`
- `Game/Bootstrap/main.gd`
- `Game/Bootstrap/run_scope.gd`
- `Run/application/run_flow_controller.gd`
- `Run/application/reward_service.gd`
- `Run/application/battle_plan_factory.gd`
- `Commerce/application/normal_shop_session.gd`
- `Commerce/application/devil_shop_session.gd`

### 暴击与方位破绽（刺客 M1）

- `Combat/crit/weak_point.gd`
- `Combat/crit/weak_point_host.gd`
- `Combat/crit/weak_point_visual.gd` / `weak_point_visual.tscn`
- `Combat/presentation/crit_floating_text.tscn`
- `Combat/presentation/float_damage_text_pool.gd`（`crit` 样式）
- `Core/stats/data/crit/*.tres`
- `Assets/Crit/weak_point_base.png` / `weak_point_prism.png` / `weak_point_perfect_core.png`
- `Content/data/assassin_marble.tres`
