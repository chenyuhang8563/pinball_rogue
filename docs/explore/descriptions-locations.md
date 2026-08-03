# 遗物 / 弹珠 / 技能 description 文本位置勘察

> 调研日期：2026-08-03（Godot 4.7）。
> 目的：定位三类物品所有 description/title 文本的**准确定义位置**，为后续「更直观的配置方式」提供事实基线。
> 方法：静态审阅 `.tres` 资源、`.gd` 脚本与 `translations/*.csv`；`get_csv_line()` 解析行为已用 Godot 4.7.1 headless 实测复现。

## 结论摘要

1. 三类条目（遗物 27 / 弹珠 8 / 技能 2，共 37）的 `Content/data/*.tres` 中，`title` / `description` 字段**全部保存本地化 key**，不存正文。
2. 正文集中在 **3 个 CSV**：`translations/game.csv`（基础标题/描述 + 旧 `UPGRADE_*`）、`translations/item_levels.csv`（每条目 4 条等级描述 `ITEM_<ID>_DESC_LV1..LV4` + `TERM_*` 术语）、`translations/skills.csv`（技能 `SKILL_*` + 重复的 `ITEM_*`）。
3. Tooltip 显示优先级：`ITEM_<ID>_DESC_LV<n>` → `ITEM_<ID>_DESC` → `Item.description`。等级描述是实际主用路径。
4. **已确认 bug**：`translations/game.csv:3` 的 `ITEM_FIRE_MARBLE_DESC`（火焰弹珠基础描述）英文含未加引号的逗号，Godot `get_csv_line()` 会拆错列——en 截断、zh_CN 被挤为英文残段、真正中文丢失（详见 §7）。

## 1. 文本定义的分层

```text
Item 资源层（存 key）                正文层（存文本）                 消费层
Content/data/*.tres                 translations/*.csv              UI/shared/item_tooltip.gd 等
  id / title / description          en / zh_CN 两列                   按优先级查 key 并渲染
  （title/description 是 key）       游戏启动时被 Localization 加载
```

### 1.1 字段声明

- `Content/domain/item.gd:60-73`：`id`、`title`、`price`、`description`、`type`、`marble_type`、`skill_definition`。
- `Combat/skills/skill_definition.gd:9-14`：`id`、`name_key`、`description_key`、`price`。
- `Content/data/relic_configs/*.tres`（27 个）：只承载等级数值（`max_level` / `level_values` / `extra`，见 `Combat/effects/relic_level_config.gd:5-7`），**不含任何 title/description**。

### 1.2 资源与本地化键示例

| 类别 | 资源 | key | 正文位置 |
|---|---|---|---|
| 遗物 | `Content/data/lightning.tres:8-14` | `ITEM_LIGHTNING_TITLE` / `ITEM_LIGHTNING_DESC` | `game.csv:81-82`（基础）、`item_levels.csv:64-67`（LV1-4） |
| 弹珠 | `Content/data/assassin_marble.tres:8-17` | `ITEM_ASSASSIN_MARBLE_TITLE` / `_DESC` | `game.csv:155-156`、`item_levels.csv:60-63` |
| 技能 | `Content/data/dash_skill.tres:9-17` | `SKILL_DASH_NAME` / `SKILL_DASH_DESC` | `skills.csv:11-12`；另重复 `ITEM_DASH_DESC`（`skills.csv:15-16`） |

普通遗物/弹珠字段行号基本固定：`id`:8、`title`:9、`price`:11、`description`:12、`type`:13-14；技能 Item 多一个 `skill_definition` 引用。

### 1.3 本地化加载

- `Core/localization/localization.gd:6-10` 注册 3 个 CSV；`project.godot:20` 将其设为 autoload。
- `Core/localization/localization.gd:58-90` 用 `FileAccess.get_csv_line()` 按列读入 `Translation`。
- `translations/*.en.translation` / `*.zh_CN.translation` 是 `.csv.import` 的生成物，**不是独立维护源**。
- 注意：根目录 `Localization/` 目前只有 `.uid`，无脚本；实际 autoload 在 `Core/localization/`。

## 2. 条目完整清单

### 2.1 遗物 relic（27，`type = 2`）

| id | 名称 en / zh | 资源 | 价格 | 等级描述 |
|---|---|---|---:|---|
| `lightning` | Lightning Staff / 闪电法杖 | `Content/data/lightning.tres` | 20 | `item_levels.csv:64-67` |
| `leyden_jar` | Leyden Jar / 莱顿瓶 | `leyden_jar.tres` | 26 | `item_levels.csv:72-75` |
| `arc_relay` | Arc Relay / 续弧继电器 | `arc_relay.tres` | 24 | `item_levels.csv:76-79` |
| `thunderstorm` | Thunderstorm Core / 雷暴核心 | `thunderstorm.tres` | 30 | `item_levels.csv:80-83` |
| `fire_bellows` | Bellows Core / 风箱核心 | `fire_bellows.tres` | 20 | `item_levels.csv:84-87` |
| `accelerant` | Accelerant / 助燃剂 | `accelerant.tres` | 25 | `item_levels.csv:88-91` |
| `cremation` | Cremation / 火葬 | `cremation.tres` | 35 | `item_levels.csv:92-95` |
| `poison_culture` | Plague / 瘟疫培养皿 | `poison_culture.tres` | 20 | `item_levels.csv:96-99` |
| `ice_hammer` | Icebreaker Hammer / 碎冰锤 | `ice_hammer.tres` | 20 | `item_levels.csv:100-103` |
| `permafrost` | Permafrost / 永冻 | `permafrost.tres` | 25 | `item_levels.csv:104-107` |
| `cryoclasm` | Cryoclasm / 冰爆 | `cryoclasm.tres` | 30 | `item_levels.csv:108-111` |
| `carrion` | Carrion / 死蝇 | `carrion.tres` | 20 | `item_levels.csv:112-115` |
| `parasite` | Parasite / 寄生 | `parasite.tres` | 20 | `item_levels.csv:116-119` |
| `pustule` | Plague Blister / 疫疱 | `pustule.tres` | 20 | `item_levels.csv:120-123` |
| `venom_knife` | Venom Knife / 淬毒短刃 | `venom_knife.tres` | 20 | `item_levels.csv:124-127` |
| `scorpion_tail` | Scorpion Tail / 蝎尾针 | `scorpion_tail.tres` | 20 | `item_levels.csv:128-131` |
| `witch_hat` | Witch Hat / 巫毒帽 | `witch_hat.tres` | 20 | `item_levels.csv:132-135` |
| `assassins_whetstone` | Assassin's Whetstone / 刺客磨刀石 | `assassins_whetstone.tres` | 20 | `item_levels.csv:136-139` |
| `fortuna_dice` | Fortuna's Dice / 福尔图娜的骰子 | `fortuna_dice.tres` | 25 | `item_levels.csv:140-143` |
| `many_faced_prism` | Many-Faced Prism / 千面棱镜 | `many_faced_prism.tres` | 30 | `item_levels.csv:144-147` |
| `scarlet_thread` | Scarlet Thread / 猩红丝线 | `scarlet_thread.tres` | 30 | `item_levels.csv:148-151` |
| `execution_decree` | Execution Decree / 处刑敕令 | `execution_decree.tres` | 50 | `item_levels.csv:152-155` |
| `thermal_shock` | Thermal Shock / 热冲击 | `thermal_shock.tres` | 30 | `item_levels.csv:156-159` |
| `miasma` | Miasma / 瘴气 | `miasma.tres` | 30 | `item_levels.csv:160-163` |
| `grindstone` | Grindstone / 磨轮 | `grindstone.tres` | 20 | `item_levels.csv:172-175` |
| `drop_hammer` | Drop Hammer / 锻锤 | `drop_hammer.tres` | 24 | `item_levels.csv:176-179` |
| `battering_ram` | Battering Ram / 破城锥 | `battering_ram.tres` | 28 | `item_levels.csv:180-183` |

基础描述（`ITEM_<ID>_DESC`）均位于 `translations/game.csv`，行号随文件变动，此处不逐一列出。

### 2.2 弹珠 marble（8，`type = 1`）

| id | 名称 en / zh | 资源 | 价格 | 等级描述 |
|---|---|---|---:|---|
| `dark_marble` | Dark Marble / 暗影弹珠 | `Content/data/dark_marble.tres` | 0 | `item_levels.csv:36-39` |
| `bomb_marble` | Bomb Marble / 炸弹弹珠 | `bomb_marble.tres` | 30 | `item_levels.csv:40-43` |
| `brown_marble` | Brown Marble / 大地弹珠 | `brown_marble.tres` | 20 | `item_levels.csv:44-47` |
| `blue_marble` | Blue Marble / 冰霜弹珠 | `blue_marble.tres` | 22 | `item_levels.csv:48-51` |
| `green_marble` | Green Marble / 毒液弹珠 | `green_marble.tres` | 25 | `item_levels.csv:52-55` |
| `fire_marble` | Fire Marble / 火焰弹珠 | `fire_marble.tres` | 25 | `item_levels.csv:56-59` |
| `assassin_marble` | Assassin Marble / 刺客弹珠 | `assassin_marble.tres` | 25 | `item_levels.csv:60-63` |
| `lightning_marble` | Lightning Marble / 闪电弹珠 | `lightning_marble.tres` | 25 | `item_levels.csv:68-71` |

### 2.3 技能 skill（2，`type = 3`）

| id | 名称 en / zh | Item 资源 | 价格 | 技能定义资源 | 等级描述 |
|---|---|---|---:|---|---|
| `dash` | Dash / 冲刺 | `Content/data/dash_skill.tres` | 0 | `Combat/skills/Dash/dash_skill_definition.tres:9-14` | `item_levels.csv:164-167` |
| `magic_missile` | Magic Missile / 魔法飞弹 | `Content/data/magic_missile_skill.tres` | 55 | `Combat/skills/MagicMissile/magic_missile_skill_definition.tres:9-17` | `item_levels.csv:168-171` |

技能 Item 的 `description` 字段保存 `SKILL_*_DESC`；技能定义资源又保存一份 `description_key`（当前未被显示端直接读取）。

## 3. 消费端

| 位置 | 读取方式 |
|---|---|
| `UI/shared/item_tooltip.gd:45-87` | 统一 tooltip 入口。`level_description()` 优先 `ITEM_<ID>_DESC_LV<n>` → `ITEM_<ID>_DESC` → `item.description` |
| `UI/shared/item_tooltip.gd:90-113` | `[damage_*]` 颜色标签与术语金色渲染 |
| `UI/shared/item_tooltip.gd:116-150` | 从描述识别术语并生成术语解释卡 |
| `Loadout/presentation/inventory_panel.gd:256-300` | 库存弹珠/遗物/技能槽设置 tooltip |
| `Loadout/presentation/slot.gd:144-149` | 商店/恶魔商店报价槽生成 tooltip |
| `Run/presentation/reward_tooltip_button.gd:11-30`、`draft_reward_panel.gd:124-134` | 奖励行 tooltip |
| `Run/presentation/reward_marble_card.gd:45-59` | 直接调 `description_bbcode()` 写进奖励卡 |
| `Combat/presentation/active_skill_slot.gd:77-88` | 战斗 HUD 技能槽，按当前等级显示 |
| `Loadout/presentation/skill_replace_dialog.gd:161-199` | **自行重复实现** description 查找与 fallback（与 tooltip 不同步） |

## 4. 格式与约定

- key 命名：基础 `ITEM_<ID>_TITLE/DESC`、等级 `ITEM_<ID>_DESC_LV1..LV4`、技能 `SKILL_<ID>_NAME/DESC`。见 `docs/design/relic-archetype-design.md:164-169`、`docs/design/item-descriptions-levels.md:1-3`。
- 颜色标签：`[damage_fire]` / `[damage_frost]` / `[damage_lightning]` / `[damage_poison]` / `[damage_explosion]`，由 `item_tooltip.gd:4-11,102-106` 转为 `[color=...]`。
- 术语：`TERM_*_NAME/DESC` 双语文案在 `item_levels.csv:2-33`；金色 `#cead4a`，别名在 `item_tooltip.gd:12-34`。
- description 中无 `%s/%d` 运行时占位符。
- 单行无段落；工具提示多行单段排版。

## 5. 散落程度与重复维护点

canonical 源文件：37 个 `.tres` + 3 个 CSV = **40**；技能定义 `description_key` 镜像再加 2 = 42；`*.translation` 为生成物不计。

重复/风险清单：

1. **技能正文双份**：`SKILL_*_DESC` 与 `ITEM_*_DESC` 并存于 `skills.csv`，内容相同需同步（Dash、Magic Missile）。
2. **技能 key 三层保存**：Item 的 `description`、SkillDefinition 的 `description_key`、CSV 正文。
3. **tooltip 与技能替换对话框重复实现**查找逻辑：`item_tooltip.gd:79-87` vs `skill_replace_dialog.gd:188-199`。
4. **`UPGRADE_*_DESC` 旧数据层**：`item_progression.gd:38-115` 硬编码 24 个 key，对应正文在 `game.csv` 多段；当前无读取路径，等级文案实际走 `item_levels.csv`。
5. **术语三处维护面**：`item_tooltip.gd:12-34`（别名）、`item_levels.csv:2-33`（正文）、`docs/design/tooltip/CONTEXT.md`（口径）。

## 6. 设计文档滞后

- `docs/architecture/relic-marble-skill-audit.md` 标注 Godot 4.6，实际 `project.godot:15` 为 4.7；且文中「闪电链 / 瘟疫培养皿」等名称与当前文案（`game.csv:81` 已是 Lightning Staff / 闪电法杖）不一致。
- `docs/design/item-descriptions-levels.md:14`、`docs/design/tooltip/CONTEXT.md:10` 仍用旧称「闪电链」。

## 7. 已确认 bug：`ITEM_FIRE_MARBLE_DESC` 被 CSV 拆列

- 位置：`translations/game.csv:3`。
- 原文：`ITEM_FIRE_MARBLE_DESC,First hit applies 4 burn fuel; later hits add 1. Each second, burn deals damage based on remaining fuel and consumes 1 fuel.,首次命中附着 4 层燃烧；...`
- 问题：英文段含**未加引号**的 ASCII 逗号。`Core/localization/localization.gd:78` 用 `get_csv_line()` 解析，引号内逗号会保留、引号外逗号会拆列（已用 Godot 4.7.1 headless 实测复现）。
- 结果：en 被截断为 `...Each second`；zh_CN 被挤为英文残段 ` burn deals damage...`；真正中文落入第 4 列被丢弃。
- 影响范围：基础描述 `ITEM_FIRE_MARBLE_DESC`（tooltip 的 fallback 路径、升级比较等）；等级描述 `ITEM_FIRE_MARBLE_DESC_LV1..4` 在 `item_levels.csv` 中正常。
- 修复：给该行英文段加引号（与 `ITEM_MAGIC_MISSILE_DESC` 一致）。
- 其余两 CSV 经逐行扫描无同类问题。

## 8. 对「更直观配置方式」的启示（供后续设计参考）

当前「配置」分散在：37 个 `.tres`（条目元数据）+ 3 个 CSV（文案）+ `item_progression.gd`（升级数值）+ `relic_configs/*.tres`（遗物数值）+ `item_tooltip.gd`（术语别名/颜色）。后续若要统一，候选方向：

1. 单一数据目录（如 `Content/items/*.tres` 或 JSON），条目元数据 + 多级描述 + 数值集中一处；
2. 文案改为按条目分文件而非按 CSV 汇总，或保留 CSV 但增加校验（逗号/引号 lint）；
3. 消除技能 `SKILL_*` / `ITEM_*` / `description_key` 三层重复，统一为单一 key；
4. 合并 `item_tooltip.gd` 与 `skill_replace_dialog.gd` 的描述解析为共享工具。

> 注：§2 表格中的资源路径省略了 `Content/data/` 前缀，其余路径为完整相对路径。
