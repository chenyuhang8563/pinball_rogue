# 毒系遗物设计文档：瘟疫苍蝇经济（现状实现）

> 状态：现状梳理 + 改名提案 · 2026-07-24
>
> 依据：源码勘察 `Combat/effects/{carrion,parasite,pustule,scorpion_tail,venom_knife,witch_hat,plague_fly}`、
> `Combat/status/buffs/{poison_debuff,infection_debuff}.gd`、`Combat/effects/effect_manager.gd`、
> `Content/data/*.tres` 与 `Content/data/relic_configs/*.tres`。
>
> **阅读约定：** 【事实】来自源码与配置；【提案】命名与设计调整建议。

---

## 0. 与 v4 流派文档的关系（重要）

`docs/design/archetypes/plague.md`（v4 草案）把瘟疫设想为**三阶段感染（潜伏→发病→宿主）+ 孢子区/孢子体**的延迟宿主经营。
本工作树实际实现的是一条**「瘟疫苍蝇」路线**：感染是「毒层数到达阈值即永久感染」的单向闸门，
**感染宿主死亡放出友方瘟疫苍蝇**，苍蝇叮咬敌人并传播毒——**苍蝇就是 v4 设想的「传播媒介」**，只是用苍蝇群替代了孢子区/孢子体，
感染用「阈值闸门」替代了「三阶段成熟」。两者共享同一幻想（把敌人变成会扩散的传染媒介），但具体机制不同。

**本文档以已实现机制为准**，描述当前 6 件毒系遗物。若后续要回归 v4 的阶段制/孢子区，应以独立迁移文档处理，不在本文范围。

---

## 1. 改名提案【提案】

三件苍蝇遗物构成语义簇：喂蝇 → 传毒 → 爆蝇。`parasite`（寄生）保留不改名，另两件改为与「寄生」并列的具体瘟疫实物名词。

| id | 现名(中/英) | 建议名(中/英) | 理由 |
|---|---|---|---|
| `carrion` | 腐肉 / Carrion | **死畜 / Carrion** | 染疫病死的牲畜是苍蝇的食源，「食源充足、苍蝇久久不散」贴合「延长苍蝇寿命」机制；不依赖图标，纯粹取瘟疫意象 |
| `pustule` | 脓爆 / Pustule | **疫疱 / Plague Blister** | 「鼓胀随时会破的瘟疫水疱」直观对应「宿主死亡爆裂放蝇」；与「寄生」同为生物名词 |

备选：`carrion` 腐尸/蛆巢/疫肉；`pustule` 脓疮/黑疫疱/熟脓包。
改名仅涉及本地化键 `ITEM_CARRION_*`、`ITEM_PUSTULE_*` 的中文/英文文案；**已拍板不改 `id`**（见 §7）。

---

## 2. 瘟疫苍蝇经济基线【事实】

毒系玩法由「毒 → 感染 → 苍蝇」三段经济驱动，遗物全部挂在这条链上。

| 环节 | 机制 | 关键常量 |
|---|---|---|
| 施毒 | 弹珠命中叠毒层；`poison_stacks_per_hit` 基础 **1** | `VenomKnife` 增加每次命中叠层 |
| 毒 DoT | 每层每次跳伤 = `poison_damage_per_layer`（基础 **1**）×层数；跳伤间隔 `poison_tick_seconds`（基础 **1.0s**） | `ScorpionTail` 抬高每层跳伤 |
| 毒上限 | `poison_max_stacks` 基础 **10**，绿弹珠升级到 15/20；硬顶 **30** | `WitchHat` 抬高上限 |
| 感染闸门 | 毒层数 ≥ **4**（`INFECTION_THRESHOLD`）→ 永久感染；感染不随毒衰减而消失 | 单向、不可逆 |
| 放蝇 | 感染宿主死亡 → 放出 **1** 只基础苍蝇 | 即使无任何遗物也放（绿弹珠身份） |
| 苍蝇行为 | 追踪最近活敌，进入范围后每 **0.5s** 叮咬一次；`bite_damage` 基础 **1**（→2 DPS）；`lifetime` 基础 **5.0s** | `Carrion`/`Pustule`/`Parasite` 改造苍蝇 |

**基础苍蝇参数**（`plague_fly.gd`）：`lifetime 5.0` / `bite_damage 1` / `bite_interval 0.5` / `move_speed 130` / `bite_range 16`。

**觉醒规则**（`effect_manager.gd`）：物品等级 ≥ 4 视为觉醒（`awakened`）；`set_level` 仍按配置 `max_level=3` 钳制，
故每件遗物实际为 **Lv1 / Lv2 / Lv3 / 觉醒** 四档，觉醒 = Lv3 数值 + 配置里的 `awakened_*` 加成。

---

## 3. 遗物总览【事实】

6 件遗物分两簇：**苍蝇经济**（tag 含 `fly`，改造苍蝇本身）与**毒属性增幅**（tag 含 `enhance`，改造毒的数值轴）。

| 簇 | id / 名 | 改造对象 | 一句话 | 价 | 标签 |
|---|---|---|---|---|---|
| 苍蝇经济 | `carrion` 死畜 | 苍蝇寿命/叮咬 | 苍蝇停留更久；觉醒叮咬更疼 | 20 | poison,fly |
| 苍蝇经济 | `parasite` 寄生 | 苍蝇叮咬 | 苍蝇叮咬时为目标叠毒 | 20 | poison,fly |
| 苍蝇经济 | `pustule` 疫疱 | 放蝇数量 | 感染宿主死亡爆裂，多放苍蝇 | 20 | poison,fly,burst |
| 毒增幅 | `venom_knife` 淬毒短刃 | `poison_stacks_per_hit` | 施毒时额外叠层 | 20 | poison,enhance |
| 毒增幅 | `scorpion_tail` 蝎尾针 | `poison_damage_per_layer` | 每层每次跳伤更高 | 20 | poison,enhance |
| 毒增幅 | `witch_hat` 巫毒帽 | `poison_max_stacks` | 毒可叠到更高层 | 20 | poison,enhance |

> 资格门槛：6 件均 `requires_tags=["poison"]`，需先有带 `poison` 标签的内容（绿弹珠）才会作为候选出现。

---

## 4. 苍蝇经济簇（改造苍蝇）

### 4.1 死畜 `carrion`（现：腐肉）

- **幻想**：一具染疫死畜持续喂养苍蝇，让它们久久不散；觉醒后苍蝇被养得更凶，叮咬更疼。
- **机制**：被放出的苍蝇**寿命延长**（`get_fly_duration_bonus`，加在基础 5.0s 上）；觉醒时苍蝇**叮咬伤害 +1**（`get_fly_damage_bonus`）。
- **触发**：`EffectManager._spawn_plague_flies` 放蝇时查询，作用于该次放出的**所有**苍蝇（含 `pustule` 的额外苍蝇）。
- **配置**：`level_values=[2,4,6]`，`extra.awakened_damage_bonus=1`。

| 档位 | 苍蝇寿命 | 单只苍蝇 DPS |
|---|---|---|
| Lv1 | 5 + 2 = **7s** | 2（1 伤 / 0.5s） |
| Lv2 | 5 + 4 = **9s** | 2 |
| Lv3 | 5 + 6 = **11s** | 2 |
| 觉醒 | **11s**（Lv3 值） | **4**（2 伤 / 0.5s） |

### 4.2 寄生 `parasite`（保留不改名）

- **幻想**：苍蝇成为带毒媒介，叮一口就往伤口里种毒，维持感染经济滚动。
- **机制**：苍蝇每次叮咬通过 `EffectManager.on_fly_bite` 触发 `on_fly_bite`，为目标叠加 `get_stacks_per_bite()` 层毒。
- **配置**：`level_values=[1,1,1]`，`extra.awakened_bonus=1`。

| 档位 | 每次叮咬叠毒 |
|---|---|
| Lv1 / Lv2 / Lv3 | **1** 层 |
| 觉醒 | **2** 层 |

> 【观察】Lv1→Lv3 数值不变（恒为 1），升级体验只来自觉醒。见 §7。

### 4.3 疫疱 `pustule`（现：脓爆）

- **幻想**：感染宿主体内鼓满疫疱，死亡时「啪」地爆裂，额外炸出一群苍蝇。
- **机制**：感染宿主死亡时，在基础 1 只之外**额外放蝇**（`get_extra_fly_count`）；额外苍蝇有寿命折损（`get_extra_fly_duration_penalty`，从 `base_duration` 扣），折损随等级递减，觉醒无折损。额外苍蝇以 `EXTRA_FLY_SCATTER_RADIUS=12` 环形散开避免叠在一点。
- **配置**：`level_values=[2,1,0]`（折损秒数），`extra.base_count=1`，`extra.awakened_count=2`。

| 档位 | 额外苍蝇数 | 额外苍蝇寿命（不计死畜时） |
|---|---|---|
| Lv1 | **1** 只 | 5 − 2 = **3s** |
| Lv2 | **1** 只 | 5 − 1 = **4s** |
| Lv3 | **1** 只 | **5s**（无折损） |
| 觉醒 | **2** 只 | **5s**（无折损） |

> 额外苍蝇寿命 = `max(1.0, base_duration − 折损)`，`base_duration = 5.0 + 死畜加成`，故与死畜叠乘放大。

---

## 5. 毒属性增幅簇（改造毒数值轴）

三者均通过 `StatSystem` 对实体 `marble_chain` 注入 `ADD` 修饰（`_sync_modifier`），随等级/觉醒实时重算，移除时 `dispose` 清理。

### 5.1 淬毒短刃 `venom_knife`

- **轴**：`poison_stacks_per_hit`（每次命中叠毒层数，基础 1）。
- **配置**：`level_values=[1,1,2]`，`extra.awakened_bonus=1`。

| 档位 | 每次命中叠毒 |
|---|---|
| Lv1 | 1 + 1 = **2** 层 |
| Lv2 | 1 + 1 = **2** 层 |
| Lv3 | 1 + 2 = **3** 层 |
| 觉醒 | **4** 层 |

> 【观察】Lv1→Lv2 无提升（同为 +1）。见 §7。更快叠层 ⇒ 更快越过感染阈值（4）放蝇。

### 5.2 蝎尾针 `scorpion_tail`

- **轴**：`poison_damage_per_layer`（每层每次跳伤，基础 1）。
- **配置**：`level_values=[1,2,3]`，`extra.awakened_bonus=1`。

| 档位 | 每层每次跳伤 |
|---|---|
| Lv1 | 1 + 1 = **2** |
| Lv2 | 1 + 2 = **3** |
| Lv3 | 1 + 3 = **4** |
| 觉醒 | **5** |

> 跳伤 = 层数 × 每层跳伤，与 `witch_hat` 抬上限相乘放大。

### 5.3 巫毒帽 `witch_hat`

- **轴**：`poison_max_stacks`（毒上限，基础 10，硬顶 30）。
- **配置**：`level_values=[3,6,10]`，`extra.awakened_bonus=10`。

| 档位 | 加成 | 基础上限 10 时的实际上限 |
|---|---|---|
| Lv1 | +3 | **13** |
| Lv2 | +6 | **16** |
| Lv3 | +10 | **20** |
| 觉醒 | +10 | **30**（触硬顶） |

> 若绿弹珠已把上限升到 20，则 Lv3 即达 30 硬顶；感染阈值仍为 4，更高上限意味着 DoT 在更高层数才封顶。

---

## 6. 协同与构筑

- **核心滚雪球**：`venom_knife`（快叠层）+ `witch_hat`（高上限）→ 快速越过感染阈值放蝇，且高上限让毒 DoT 更久不封顶。
- **苍蝇放大器**：`carrion`（寿命/觉醒伤害）× `pustule`（数量）相互放大——死畜抬高的 `base_duration` 同样作用于疫疱的额外苍蝇。
- **感染续航**：`parasite` 让苍蝇叮咬回种毒，使「死亡放蝇 → 苍蝇叠毒 → 新宿主感染 → 再放蝇」形成闭环，是苍蝇经济的发动机。
- **DoT 爆发**：`scorpion_tail` × `witch_hat` 相乘，把「每层跳伤 × 层数」做大，是不依赖苍蝇的纯毒 DoT 路线。

---

## 7. 加强方案（成长曲线修复）【提案】

> 觉醒 = 等级 ≥ 4（`effect_manager.gd`），`set_level` 仍按 `max_level=3` 钳制，故每件为 **Lv1/Lv2/Lv3/觉醒** 四档。下列为配置级（改 `relic_configs/*.tres`）加强，**可逆、影响面小**；是否落地待确认。

### 7.1 `parasite` 寄生 — 让等级真正成长

| | level_values | 每次叮咬叠毒（L1/L2/L3/觉醒） |
|---|---|---|
| 现状 | [1,1,1] + awakened1 | 1 / 1 / 1 / 2 |
| 提案 | **[1,2,3]** + awakened1 | 1 / 2 / 3 / 4 |

觉醒语义从「翻倍」变为「在 Lv3 基础上再 +1」。纯配置。

### 7.2 `venom_knife` 淬毒短刃 — 消除 Lv1=Lv2

| | level_values | 每次命中叠毒（L1/L2/L3/觉醒） |
|---|---|---|
| 现状 | [1,1,2] + awakened1 | 2 / 2 / 3 / 4 |
| 提案 | **[1,2,3]** + awakened1 | 2 / 3 / 4 / 5 |

保守替代 `[1,2,2]`→2/3/3/4。注意：与 parasite 同拉到 [1,2,3] 会叠加、更快越过感染阈值（4），属有意加强；若过强用保守值。纯配置。

### 7.3 `witch_hat` 巫毒帽 — 让觉醒不浪费

问题：基础上限 10 时现状 L3 已 20、觉醒触 30 硬顶；若绿弹珠已把上限升到 20，则 L3 即 30，觉醒 +10 完全无感。

| 方案 | level_values / awakened | 基础10：L1/L2/L3/觉醒 | 绿弹珠20：L3/觉醒 | 改动面 |
|---|---|---|---|---|
| 现状 | [3,6,10] / +10 | 13/16/20/30(顶) | 30(顶)/30(顶,无感) | — |
| **A 推荐** | **[2,4,7] / +10** | 12/14/17/27 | 27/30(顶) | 纯配置 |
| B | [3,6,10] / +10，并把 `poison_debuff.gd` 的 `MAX_POISON_STACKS` 30→40 | 13/16/20/30 | 30/40 | 改代码，影响所有毒上限来源 |

推荐 A：配置级、可逆，使觉醒在常见（基础 10）情形重新提供 +10 实质上限。

### 7.4 无需改动的件

`carrion`[2,4,6]、`pustule`[2,1,0]+觉醒加数量、`scorpion_tail`[1,2,3] 每档均有可见提升，曲线健康，不动。

### 7.5 仍待确认

1. 是否落地 7.1–7.3 的加强数值（配置可逆；`witch_hat` 推荐方案 A）。
2. 是否把本文与 `archetypes/plague.md`（v4 阶段制幻想）合并或互相指引，避免双份瘟疫文档漂移。

> **改名是否改 `id`**：已拍板**不改**，仅本地文案（已完成：`ITEM_CARRION_TITLE` 中→死畜、`ITEM_PUSTULE_TITLE` 中→疫疱 / 英→Plague Blister）。

---

## 8. 图标替换（苍蝇经济簇三件）

`carrion`/`parasite`/`pustule` 三件换 icon，新文件 `Assets/Items/plague_{carrion,parasite,pustule}.png`，并把对应 `Content/data/*.tres` 的 `icon` 指过去、跑一次 Godot headless import。

- 规格：32×32、透明、16-bit 像素风、瘟疫配色（病绿/瘀紫/黄疸黄/褐+乳白）、不恶心。
- **生成管线（关键约束）**：codex 侧 `image-cli` skill 用 `gpt-image-2`，其**最小尺寸 655,360 像素且不支持透明**，无法直接产 32×32 透明图。故管线 = `gpt-image-2` 生成 1024×1024（纯品红 `#FF00FF` 实底 + 强「32 逻辑网格像素风」提示词，**不传** `--background transparent`、**不降级**到 1.5）→ PIL 在 1024 上品红抠透明 → 最近邻（NEAREST）缩放到 32×32 → 存 RGBA 覆盖目标 PNG。
- 风险：最近邻缩放的像素锐利度取决于模型是否对齐 32 逻辑网格，可能略软/有杂边；若不佳则迭代提示词，或改走 skill 允许的 `gpt-image-1.5` 透明回退（需显式选择）。
- 凭据：wrapper 自读 `~/.codex/auth.json` 的 `OPENAI_API_KEY` 与 `~/.codex/config.toml` 当前 `model_provider` 的 `base_url`（`http://192.168.31.236:8080`），调用方不自设密钥。

---

## 附：配置速查

| id | level_values | extra |
|---|---|---|
| carrion | [2,4,6] | awakened_damage_bonus=1 |
| parasite | [1,1,1] | awakened_bonus=1 |
| pustule | [2,1,0] | base_count=1, awakened_count=2 |
| scorpion_tail | [1,2,3] | awakened_bonus=1 |
| venom_knife | [1,1,2] | awakened_bonus=1 |
| witch_hat | [3,6,10] | awakened_bonus=10 |
