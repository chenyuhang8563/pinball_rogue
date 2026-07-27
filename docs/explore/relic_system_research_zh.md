# 主流肉鸽遗物系统与“弹珠肉鸽”设计研究

研究日期：2026-07-22。本文比较的是“局内、可改变后续决策的持久构筑件”，包括传统遗物，也包括功能相同的 Joker、被动道具、perk、boon、词缀和 sigil。它们并非完全同构：例如《Hades》的祝福占招式槽且有前置，《Dead Cells》的词缀附着于可替换装备，《Isaac》的藏品通常不占槽，《Balatro》的 Joker 有硬槽位。下文在提炼共同规律时保留这些差异。具体数值可能随补丁变化，引用数值用于解释结构而非充当当前平衡表。

## 一、常见分类框架

同一遗物可以同时属于“功能类”和“触发类”；设计数据库最好使用多标签，而不是强迫单选。

| 类别 | 设计作用 | 代表例子 |
|---|---|---|
| 直接攻击/输出 | 提高基础输出，提供早期稳定性；通常是地板而非终局引擎 | 《杀戮尖塔》**Vajra**：开局 +1 力量；《雨中冒险2》**Lens-Maker’s Glasses**：每层 +10% 暴击；《Peglin》**Powder Collector**：每 30 次钉子命中把一个钉子转成炸弹。[[STS Vajra](https://slaythespire.wiki.gg/wiki/Vajra)] [[RoR2 Glasses](https://riskofrain2.wiki.gg/wiki/Lens-Maker%27s_Glasses)] [[Peglin Powder Collector](https://peglin.wiki.gg/wiki/Powder_Collector)] |
| 防御/续航 | 把失误容忍、资源保存或输出行为转为生存 | 《杀戮尖塔》**Anchor**：首回合格挡；《雨中冒险2》**Tougher Times**：概率阻挡伤害；《Peglin》的 **Ballwark** 体系：先扣护甲层，再扣 HP，并有按 Ballwark 增伤、消耗或反击的配套件。[[Anchor](https://slaythespire.wiki.gg/wiki/Anchor)] [[Tougher Times](https://riskofrain2.wiki.gg/wiki/Tougher_Times)] [[Ballwark](https://peglin.wiki.gg/wiki/Ballwark)] |
| 经济/选择权 | 增加钱、折扣、重掷或掉落；本质是把当前战力换成未来选择质量 | 《杀戮尖塔》**Membership Card**（商店折扣）、**Golden Idol**（战后金币）；《Balatro》**Golden Joker**（回合结束收入）。[[Membership Card](https://slaythespire.wiki.gg/wiki/Membership_Card)] [[Golden Idol](https://slaythespire.wiki.gg/wiki/Golden_Idol)] [[Golden Joker](https://balatrowiki.org/wiki/Golden_Joker)] |
| 条件触发/节奏 | 奖励特定动作频率、顺序、阈值或状态 | 《杀戮尖塔》**Kunai**：一回合每打出 3 张攻击牌获得敏捷；《RoR2》**Runald’s Band**：单次伤害达到 400% 门槛才触发、且有冷却；《Peglin》**Critsomallos Fleece**：一发中激活多个暴击钉时继续增加每钉伤害。[[Kunai](https://slaythespire.wiki.gg/wiki/Kunai)] [[Runald’s Band](https://riskofrain2.wiki.gg/wiki/Runald%27s_Band)] [[Fleece](https://peglin.wiki.gg/wiki/Critsomallos_Fleece)] |
| 成长/叠加 | 把可重复行为变成永久或局内增长，形成方向承诺 | 《Balatro》**Hologram**：每加一张牌永久获得 XMult；**Vampire**：吞掉已计分牌的强化以成长 XMult；《Noita》可重复取得的 perk，行为依 perk 而异（独立计时器、额外护盾层等）。[[Hologram](https://balatrowiki.org/wiki/Hologram)] [[Vampire](https://balatrowiki.org/wiki/Vampire)] [[Noita Perks](https://noita.wiki.gg/wiki/Perks)] |
| 转化/资源循环 | 将废物、溢出或一种资源转换为另一种，最容易产生“引擎感” | 《杀戮尖塔》**Ice Cream** 把未用能量保存到后续回合；**Dead Branch** 把消耗牌转成随机牌；《吸血鬼幸存者》用满级武器 + 指定被动物品 + 宝箱条件进化武器。[[Ice Cream](https://slaythespire.wiki.gg/wiki/Ice_Cream)] [[Dead Branch](https://slaythespire.wiki.gg/wiki/Dead_Branch)] [[VS Evolution](https://vampire-survivors.fandom.com/wiki/Evolution)] |
| 规则改写/破坏 | 改变选牌评价、物理规则或资源上限；通常应稀有且显著 | 《杀戮尖塔》**Snecko Eye**：每回合多抽 2，抽到的牌费用随机为 0–3；《Peglin》**Gift That Keeps Giving**：所有钉子变 Durable；《Noita》**Unlimited Spells**：多数有限次数法术变无限。[[Snecko Eye](https://slaythespire.wiki.gg/wiki/Snecko_Eye)] [[Gift](https://peglin.wiki.gg/wiki/Gift_That_Keeps_Giving)] [[Unlimited Spells](https://noita.wiki.gg/wiki/Unlimited_Spells)] |
| 风险/诅咒/负面交易 | 用可管理的缺点购买超额强度，并让已有构筑改变缺点价值 | 《杀戮尖塔》**Cursed Key**：每回合 +1 能量，开非 Boss 宝箱加诅咒；**Coffee Dripper**：+1 能量但不能在营火休息；《Noita》**Glass Cannon**：法术伤害与爆炸范围 ×5，但最大生命封顶 50。[[Cursed Key](https://slaythespire.wiki.gg/wiki/Cursed_Key)] [[Coffee Dripper](https://slaythespire.wiki.gg/wiki/Coffee_Dripper)] [[Glass Cannon](https://noita.wiki.gg/wiki/Glass_Cannon)] |
| 复制/重触发 | 复制最强环节，放大已有协同；也是最危险的指数源 | 《Balatro》**Blueprint** 复制右侧兼容 Joker；**Mime** 重触发手牌中能力；《Monster Train》**Founding Seal** 让 Incant 能力额外触发。[[Blueprint](https://balatrowiki.org/wiki/Blueprint)] [[Mime](https://balatrowiki.org/wiki/Mime)] [[Monster Train Artifacts](https://monster-train.fandom.com/wiki/Artifacts)] |

## 二、优秀遗物如何制造协同与流派

### 1. 用“动词链”而不是同标签加成

强协同通常由四个角色构成：**生产者 → 转换器 → 放大器 → 结算器**。

- 生产者制造状态/对象：毒、Doom、暴击钉、炸弹、强化牌、额外球。
- 转换器改变资源用途：Dead Branch 把 Exhaust 转成牌；Vampire 把 Enhancement 转成永久 XMult。
- 放大器重触发或乘算：Mime、Blueprint、Founding Seal、Fleece。
- 结算器把积累兑现成清场、Boss 伤害、格挡或金币。

因此，“毒伤 +10%”只和毒发生数值关系；“击中中毒敌人会分裂一颗球”则把状态流派接到多球流派，形成跨流派桥梁。

### 2. 三种联动强度

1. **条件触发**：A 让 B 更常触发。例：快速攻击提高 Kunai/Nunchaku 触发率；《Dead Cells》先施加毒，再利用“对中毒目标 +80% 伤害”词缀。后者的优点是状态施加器和收益武器可以来自不同槽位。[[Dead Cells Affixes](https://deadcells.wiki.gg/wiki/Affixes)]
2. **数值倍乘**：A 增加事件数，B 增加每次事件价值，C 再乘总结果。Balatro 的“牌触发次数 × 每次加 Mult × 末端 XMult”就是典型三轴乘法；RoR2 的攻击频率、proc coefficient、on-hit 链也类似。
3. **机制改写**：A 改变系统规则，使一批原本普通的选择整体升值。Snecko Eye 让高费牌变好；Gift That Keeps Giving 让“每次钉命中”类效果拥有更多触发机会；《Isaac》的 Brimstone 把眼泪改为蓄力光束，因此大量射速、分裂、跟踪效果要重新解释。[[Isaac Items](https://bindingofisaacrebirth.wiki.gg/wiki/Items)]

### 3. 让组合有顺序、边界和反协同

- **顺序可操纵**会产生技术深度：Balatro 的 Joker 左右顺序决定 +Mult 与 XMult、Midas Mask 与 Vampire 的处理先后。
- **边界清楚**才能让玩家推理：Blueprint 明示哪些被动效果不可复制；RoR2 用 proc coefficient 压低高频攻击触发 on-hit 的效率。[[Proc Coefficient](https://riskofrain2.wiki.gg/wiki/Proc_Coefficient)]
- **反协同不是坏事**：Fleece 按“暴击伤害−普通伤害”的差值成长，若另一遗物大幅抬高普通伤害，它会变弱。这类冲突让选择不是自动拿取，但 UI 必须预告。

## 三、稀有度与分层如何塑造节奏

| 层级职责 | 合适内容 | 对节奏/决策的影响 |
|---|---|---|
| Common / 地板件 | 小幅即战力、基础状态生产、宽泛触发 | 早期解决“活下来”；应能独立工作，也能成为两种以上流派的入口。若 common 过窄，首章奖励会大量变成空选项。 |
| Uncommon / 定向件 | 更强的条件收益、跨系统连接、轻度成长 | 玩家看到第二/第三个信号后开始承诺；既能加强已有方向，也应保留 pivot 可能。 |
| Rare / 放大器 | 复制、重触发、永久 X 乘区、强引擎 | 不是单纯更大数字，而是提升上限、改变选取优先级。Balatro 当前资料给出的普通生成权重为 Common 70%、Uncommon 25%、Rare 5%。[[Jokers](https://balatrowiki.org/wiki/Jokers)] |
| Boss / 规则件 | 资源上限变化、核心规则改写、强收益 + 明显代价 | 放在章节边界最合适：玩家已有足够信息判断 Coffee Dripper、Cursed Key、Snecko Eye；选择又会重写下一章策略。Peglin 的 Matryoshka Shell（每发 Multiball +1）和 Gift 也属于 Boss 级规则件。[[Matryoshka Shell](https://peglin.wiki.gg/wiki/Matryoshka_Shell)] |
| Legendary / 外卡 | 极低频、极强、可成为故事性 run 的中心 | 不应是常规流派的唯一必需件。Balatro Legendary 不能正常出现在商店，只由 The Soul 产生；资料页记载 The Soul 在相应包中的替代概率为 0.3%。 |
| Curse / Lunar / 交易件 | 强收益与可构筑规避的缺点 | 缺点若不可被已有构筑评估，只是抽税；若可管理，就会产生“这个 run 能否承受？”的高质量判断。RoR2 **Shaped Glass** 每层基础伤害 ×2、最大生命 ×0.5，均指数叠加。[[Shaped Glass](https://riskofrain2.wiki.gg/wiki/Shaped_Glass)] |

并非所有游戏都应用同一种“rarity”：

- 《Hades》Common/Rare/Epic/Heroic主要缩放数值，Duo/Legendary 则是有明确前置的机制奖励；Duo 让两位神的核心状态发生新反应，如 Sea Storm 把击退接到雷击，Merciful End 把 Deflect 接到 Doom 立即结算。[[Hades Boons](https://hades.fandom.com/wiki/Boons)]
- 《Isaac》的 Item Quality 是 0–4 的隐藏属性，会影响若干自动重掷/筛选效果；它不是简单的掉率层。Transformation 通常要求取得同主题集合中至少 3 个不同藏品，是“套装阈值”而非 rarity。[[Item Quality](https://bindingofisaacrebirth.wiki.gg/wiki/Item_Quality)] [[Transformations](https://bindingofisaacrebirth.wiki.gg/wiki/Transformations)]
- 《Dead Cells》的 `+ / ++ / S / L` 是装备品质和 gear power/词缀数量体系；传奇还可出现普通组合规则不允许的固定词缀组合。不要把它直接等同于静态遗物 rarity。[[Gear](https://deadcells.wiki.gg/wiki/Gear)]
- 《Vampire Survivors》的“高级奖励”主要由进化条件和宝箱时点门控，而不是把所有关键被动都塞进 Rare 池。

## 四、数值设计手法

### 加法与乘法

- **同一池加法**适合 common：可预测、不会因多件组合突然爆炸。《杀戮尖塔》的 Strength 先进入加法，再应用乘法；多段攻击因此获得多次固定增益。
- **独立乘区**适合稀有 payoff：能让已有投入得到回报。Balatro 核心近似为 `Chips × Mult`，`+Mult` 先增长 Mult，`XMult` 再乘；顺序与重触发使位置本身成为决策。
- **总伤害系数**会放大所有上游变量。RoR2 的 AtG 当前机制页描述为 10% on-hit，造成 300%（每层再 +300%）total damage，且触发概率乘攻击 proc coefficient。[[AtG](https://riskofrain2.wiki.gg/wiki/AtG_Missile_Mk._1)]

建议为 pinball_rogue 只保留少量、名字清楚的乘区，例如：`基础每钉伤害 × 命中倍率 × 暴击倍率 × 落槽倍率`。同类遗物在同一池相加；不同池才相乘。UI 应显示本发的分解式。

### 叠加

- **线性**：Glasses 每层 +10% crit，易懂但到 100% 后失去边际价值；需溢出转化或停止投放。
- **指数**：Shaped Glass 的 `2^n` 与 `0.5^n` 同时增长风险和收益，只适合强交易件。
- **独立实例**：Noita 某些重复 perk 是多个错开计时器，而不是缩短一个计时器；手感不同，也避免除法型冷却趋近零。
- **无限叠加但局内受限**：Fleece 理论无限，实际受一发能触发多少 crit peg、轨迹和板面约束。这是物理系统天然的软上限。
- **边际递减**：概率防御、冷却、经济重掷宜用双曲线或独立掷骰，而非无限线性。

### 阈值与概率

- 阈值把连续动作变成可期待节拍：Kunai 每 3 攻击、Powder Collector 每 30 钉、Runald’s Band 要求单击 ≥400%。计数器必须可见，并说明跨回合/跨发是否保留。
- 基础概率 `p`，有 `n` 次额外重掷时，至少成功一次为 `1-(1-p)^(n+1)`；RoR2 的 57 Leaf Clover 正是失败后每件 Clover 再掷一次，而不是简单 `p×层数`。[[57 Leaf Clover](https://riskofrain2.wiki.gg/wiki/57_Leaf_Clover)]
- 高频弹珠必须有 **proc coefficient / 触发预算**：最终概率可用 `p×c`，其中小球、分裂球、幽灵球的 `c<1`；或把“每颗球一次”改成“每发一次”。否则 Multiball 会同时放大命中数、状态数、掉落数和伤害，形成四重指数。

### 滚雪球与反滚雪球

滚雪球链通常是“赢战斗 → 更多经济/选择 → 更强 → 更容易赢”。健康做法不是消灭它，而是控制反馈速度：

- 成长件需要先支付 tempo cost；例如 Vampire 吞掉牌强化后才增长。
- 槽位、手牌、球袋大小、每发次数和 Boss 门槛提供容量限制。
- 让落后玩家仍能拿到“稳定地板件”，领先玩家拿到的经济更多转化为选择而非纯数值。
- 章节后提高敌方机制复杂度，不只提高 HP；否则玩家只能追逐更大的乘区。
- 反滚雪球不要直接按玩家强度偷数值；用机会成本、递减、污染牌池、危险落槽和精英路线等可预见代价。

## 五、流派设计范式

一个成熟流派通常不是“凑齐 3 个同色遗物”，而是：**1 个入口/enable + 2–4 个供给或稳定件 + 1 个 payoff + 1 个跨流派桥梁**。

| 流派范式 | 核心/enable | 辅助与 payoff | 玩家如何识别 |
|---|---|---|---|
| 高频/多段 | Kunai、Shuriken；RoR2 on-hit；Peglin 多球 | 攻击/球数、重触发、每 N 次效果；最终接力量、导弹或总伤乘区 | 统一“命中/攻击”图标，展示计数器；第一件应单独有小收益。 |
| 状态施加 + 条件伤害 | Hades Doom/Deflect 前置；Dead Cells 毒/燃烧/流血 | Merciful End/Sea Storm；对毒 +80%、燃烧 +40%、燃油燃烧 +100% 词缀 | 状态来源和消费者用同色边框；奖励页直接显示当前每发预计覆盖率。 |
| 消耗/回收引擎 | Dead Branch；Vampire | Exhaust 供给、随机牌；Midas Mask/Pareidolia 反复制造 Gold Enhancement 给 Vampire 吞 | 文案用“当 X 被消耗时”而不是泛称 synergy；明确处理顺序。 |
| 持有/重触发乘法 | Balatro Baron | Mime 重触发手牌效果，Blueprint/Brainstorm 复制；Red Seal、Steel King 扩大单卡触发 | 玩家先看到 held-in-hand 标签，再出现 retrigger 和 copy；高阶件不应成为唯一入口。 |
| 进化/套装阈值 | VS 满级武器 + 指定被动；Isaac Transformation | Magic Wand + Empty Tome → Holy Wand；King Bible + Spellbinder → Unholy Vespers；同主题三件触发 Guppy 等 transformation | 在未解锁时给模糊线索，解锁后明确配方；避免玩家必须查 wiki。 |
| 规则改写 | Snecko Eye、Gift、Shaped Glass | 高费牌/能量、每钉触发、玻璃大炮防护 | 应在玩家已有上下文的章节节点出现；选择界面列出受益/受损的现有组件。 |
| Incant/施法次数 | Monster Train Founding Seal | 低费法术、抽牌、回能和有 Incant 的单位；“次数”与“每次价值”相乘 | 卡牌/单位明确共用 Incant 关键字，奖励池给桥梁而非只给同族件。 |

引导玩家投入但不强推的方法：

1. 前 25% 流程优先出现“宽入口”，中段才提高与现有标签相关的候选权重；相关权重只做轻推，不把随机池锁死。
2. 第二件协同出现时给短提示：“你已有 2 个【炸弹】来源”；不要提前宣布唯一正确流派。
3. 每个 enable 至少有两个供给源，每个 payoff 至少能服务两个入口；这会形成网络而不是互不相干的套装岛。
4. 提供拆解、出售、重铸或有限重掷，让玩家能退出失败方向；经济件就是 pivot 的基础设施。

## 六、弹球/弹珠肉鸽专项

### 已验证的可借鉴模式

- **命中次数变资源**：Powder Collector 每 30 钉造炸弹，把“弹得久”转成下一层板面资源；比单纯每钉 +1 更能改变路线判断。
- **同发内阶梯增长**：Fleece 在同一发激活多个 crit peg 后，按“暴击伤害−普通伤害”的差继续加每钉伤害；天然奖励玩家先规划暴击钉，再追求长轨迹。
- **物理规则改写**：Gift 令所有钉 Durable；它放大命中型效果，却对 crit/refresh/bomb 的重复触发另加平衡限制，说明“可再次碰撞”与“可再次触发能力”应是两个字段。
- **多球改变事件数量**：Matryoshka Shell 每发 Multiball +1，子球更小；这同时改轨迹分布和触发数，而不只是复制伤害。
- **落点作为结算乘区**：Weighted Chip 每发重排底部落槽，池中有 `×0.5 / ×1 / ×2`，影响整发总伤；Multiball 每颗入槽继续作用于当前伤害，产生高方差风险。[[Weighted Chip](https://peglin.wiki.gg/wiki/Weighted_Chip)]
- **钉子数量的组合公式**：Bomb Baton 开局 +3 炸弹；与 Bombulet 的翻倍按顺序得到 `(原炸弹+3)×2`。这种可推导的顺序比“神秘加成”更适合构筑游戏。[[Bomb Baton](https://peglin.wiki.gg/wiki/Bomb_Baton)]
- **板面空间就是构筑空间**：《Ballionaire》的 Trigger 被 bonk、从下方 bonk、相邻、击杀、每次 drop、离屏等事件驱动；例如 Candle 被火球击中后让相邻 Trigger ×2，Tree 只有从下方命中才收益且随 age 增长。[[Triggers](https://ballionaire.wiki.gg/wiki/Triggers)] [[Boons](https://ballionaire.wiki.gg/wiki/Boons)]
- **动作与位置融合**：《Roundguard》把 Peggle 式弹射、装备/技能和地城遭遇结合，提醒设计者：遗物不仅可改球，也可改敌人碰撞、墙面、落点和关卡路线。[[Roundguard](https://www.roundguardgame.com/)]

### 建议给 pinball_rogue 的事件模型

把物理互动标准化为可组合事件：

`OnLaunch → OnWallBounce → OnPegHit / OnUniquePegHit → OnCrit / OnRefresh / OnBomb → OnSplit → OnEnemyHit → OnSlot / OnExit`

每个衍生事件携带 `sourceBallId、shotId、generation、procCoefficient、isEcho、isUniqueHit`。遗物明确写触发域：每次命中、每颗球一次、每发一次、每块板一次。没有这些边界，多球、反弹、穿透、回顶会制造递归 bug 和不可控指数。

### 可直接立项的 7 个流派骨架（以下是设计建议，不是现有游戏事实）

| 流派 | 核心遗物 | 辅助遗物 | payoff / 制动器 |
|---|---|---|---|
| 连击/长轨迹 | **共振计数器**：每发每 12 个“不同钉”提高一级 Combo | 耐久钉、额外墙反弹、首撞不掉速 | Combo 在落槽时乘总伤；重复刷同钉不给计数，防角落永动。 |
| 暴击路线 | **二次校准**：同发第二个及以后 crit peg 可再次激活并阶梯增伤 | 增加/移动 crit peg、穿透、暴击与普通伤差值 | 高上限但依赖路线；每发阶梯封顶或 Boss 有暴击抗性而非硬禁用。 |
| 炸弹工程 | **火药压机**：每 N 个 unique hit 把下一普通钉变炸弹 | 初始炸弹、炸弹刷新、爆炸造新钉、爆炸施加状态 | 连锁爆炸有 generation 上限；衍生炸弹 proc 系数降低，保留可读性。 |
| Multiball/分裂 | **棱镜核心**：第 K 次墙反弹分裂，子球继承部分属性 | 子球尺寸、弹性、落槽重投、每颗球一次触发 | 总伤不直接完整复制；把收益分配到覆盖、状态或落槽组合，防全能。 |
| Ballwark/动能防御 | **惯性装甲**：墙撞/低伤钉积累护甲 | 护甲保留、受击反射、重球撞墙产更多甲 | 可消耗全部甲强化下一发，形成“防御蓄力→攻击兑现”；回合末衰减。 |
| Refresh/板面循环 | **再生板**：Refresh 后若本发命中足够 unique pegs，刷新钉升级 | Refresh 位置控制、耐久、刷新增暴击/炸弹 | 奖励清板而非无限局部 bounce；每发刷新触发次数有软上限。 |
| 风险落槽/经济 | **赌徒挡板**：底槽包含亏损、保本、翻倍，倍率每发重排 | 回顶保险、末段导向、把低倍率转金币 | 赚钱牺牲当发战力；Boss 战钱不能即时变纯伤，防经济与战斗双赢。 |

最重要的桥梁遗物应跨两个动词，例如：

- “炸弹命中产生一颗 `proc=0.3` 的碎片球”（炸弹 ↔ 多球）；
- “消耗 Ballwark 后，把等量普通钉暂时变成 crit peg”（防御 ↔ 暴击）；
- “Refresh 时，每存在一颗子球就降低 1 次计数需求”（刷新 ↔ 多球）；
- “落入 ×0.5 槽不会减伤，改为获得等比例金币”（风险槽 ↔ 经济）。

## 七、常见陷阱与反模式

1. **全是无条件加伤**：每件都能拿，但没有任何一件改变玩法。至少 30–40% 的池应改变触发、转换、板面或选择权，而不是只改伤害。
2. **乘区过多或含义不透明**：玩家无法预测，设计者也无法平衡。限制乘区数量，结算面板显示每层贡献。
3. **多球同时放大所有系统**：伤害、状态、金币、掉落和防御一起按球数增长。给衍生球 generation/proc coefficient，并区分“每球/每发”。
4. **无限递归**：“爆炸生成球，球触发爆炸”若没有来源过滤会锁死或溢出。任何生成事件都要有 generation cap 和 `cannotTriggerSelf`。
5. **无脑叠加**：线性暴击超过 100%、冷却无限趋零、永久成长没有 tempo cost。给溢出转化、边际递减、槽位成本或每关上限。
6. **流派孤岛**：炸弹遗物只认炸弹、暴击只认暴击，未成套就是垃圾。每个大类至少 20–30% 是双标签桥梁件。
7. **寄生式窄遗物**：只有极少球/角色可用，却进入所有人的公共池。移入角色池、事件池或仅在已有前置时出现。
8. **假稀有**：Rare 只是 Common 的三倍数字；这会让稀有度成为自动选择。Rare 应更多改变上限、复制、转化或规则。
9. **不可管理的诅咒**：缺点与构筑无关，只是随机惩罚。好交易件允许玩家通过已有防御、路线、槽位或操作技能评估风险。
10. **物理随机压过构筑决策**：玩家选对协同却因不可读碰撞失败。提供轨迹预览、钉子状态、速度档位、落槽概率/历史；让物理带来方差，不是抹除决策。
11. **奖励反而惩罚技术**：长轨迹触发全局上限后，精确多撞没有价值；或高频小球因硬冷却完全失效。优先软上限、unique-hit、递减 proc，而非突然归零。
12. **必须查 wiki 才知道前置/顺序**：套装、进化、复制兼容和触发顺序若不在 UI 呈现，就不是深度而是记忆税。

## 八、对项目最实用的落地结论

1. 先定义约 8–12 个全局动词/事件，再写遗物；不要先堆 100 个独立特例。
2. 每个流派按 `1 enable + 3 support + 1 payoff + 2 bridge` 做最小垂直切片；先验证两流派能否混构，再扩内容量。
3. Common 提供可独立工作的生产者；Rare 提供转换/乘法；Boss 提供规则改写 + 可评估代价；Curse 提供风险构筑，而不是纯惩罚。
4. 将“球属性、板面状态、轨迹事件、落槽结算”做成四个不同层，遗物可连接层，但不能暗中重复乘同一收益。
5. 为每个遗物记录：标签、触发域、计数重置点、叠加公式、衍生事件 proc、互斥/复制规则、预期独立价值、至少两个协同与一个反协同。
6. 自动化测试至少覆盖：事件递归、极端 Multiball、同发多次 refresh/crit、落槽乘法顺序、存档重载后的计数器，以及 100/500/1000 次随机 run 的死选率和倍率分布。

## 核心资料入口

- [Slay the Spire — Relics](https://slaythespire.wiki.gg/wiki/Relics)
- [The Binding of Isaac: Rebirth — Items](https://bindingofisaacrebirth.wiki.gg/wiki/Items)
- [Hades — Boons](https://hades.fandom.com/wiki/Boons)
- [Dead Cells — Affixes](https://deadcells.wiki.gg/wiki/Affixes)
- [Vampire Survivors — Evolution](https://vampire-survivors.fandom.com/wiki/Evolution)
- [Monster Train — Artifacts](https://monster-train.fandom.com/wiki/Artifacts)
- [Risk of Rain 2 — Items / Item Stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking)
- [Inscryption — Sigils](https://inscryption.fandom.com/wiki/Sigil)
- [Balatro — Jokers](https://balatrowiki.org/wiki/Jokers)
- [Noita — Perks](https://noita.wiki.gg/wiki/Perks)
- [Peglin — Relics](https://peglin.wiki.gg/wiki/Category:Relics)
- [Ballionaire — Triggers](https://ballionaire.wiki.gg/wiki/Triggers)

> 证据边界：wiki.gg 与 Balatro Wiki 页面通过 MediaWiki API 核查了描述/叠加文本；Fandom 页面在研究环境中受 Cloudflare 限制，相关 Hades、Monster Train、Vampire Survivors、Inscryption 条目仅采用稳定的机制级描述，并避免引用易随版本变化的精确小数。Roundguard 官方页只支持其类型与系统定位，不支持具体数值结论。
