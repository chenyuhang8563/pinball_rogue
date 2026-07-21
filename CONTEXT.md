# Pinball Rogue 领域词汇

本文是当前代码与文档的术语基线；历史阶段文档中的旧路径和过渡名称不构成当前入口。

## 一局流程

**RunScope**：一局游戏状态的唯一生命周期所有者。它显式持有 `Loadout`、`ItemProgression`、`RunWallet`、`RunHealth` 与 scoped `StatSystem`，并在新 run 初始化、重开或销毁时执行对应生命周期操作。

**流程令牌（RunFlowToken）**：由 run、节点与 phase identity 组成的 typed 身份。异步或重复的 UI、战斗、奖励和事件回调必须先通过令牌校验，过期令牌不能改变当前流程。

**RunFlowController**：流程编排器，只负责在节点选择、战斗、奖励、事件、升级、商店、失败与完成状态间迁移；不拥有物品、金币、生命、奖励规则或事件规则。

**战斗计划（BattlePlan）**：一次战斗的不可变输入封套，包含稳定 `battle_id`、`group`、来源和奖励策略。`group` 是唯一战斗编队字段。

**战斗会话（BattleSession）**：当前战斗生命周期的唯一所有者；登记本批 Enemy、接收击败和掉球事实，并向 `BattleGateway` 发出已接受的完成或掉球信号。

## 构筑与交易

**同一物品**：遗物与技能具有相同稳定身份，或弹珠属于相同弹珠类型时，视为同一物品。同一物品共享等级，且不能作为独立副本重复持有。

**Loadout**：玩家持有物的唯一状态源，投影出弹珠、遗物和技能；`MarbleLoadout` 同时是弹珠链顺序的唯一状态源。

**技能等级**：当前装备技能的成长阶段。替换技能时旧技能的等级进度随旧技能移除；重新获得时按新报价等级开始。

**升级报价**：商店或奖励为已拥有且仍可升级的同一物品提供的报价。结算提升原有物品，不创建第二份副本。

**奖励报价（RewardOffer）**：带 token、版本和消费状态的可领取奖励集合。`RewardOption.offer_id` 是奖励意图唯一标识；已消费或版本过期的报价不能重复结算。

**Commerce Session**：正常商店或恶魔商店的一次报价与原子结算边界。它通过显式注入的 Loadout、成长、钱包和生命端口进行 snapshot/restore，不拥有第二份玩家状态。

## 战斗状态

**状态修饰（Buff）**：附着在宿主上的有持续时间和叠层的运行时状态；由 `BuffDef` 定义、`BuffHost` 承载、`BuffRegistry` 作为定义唯一来源。毒、冰霜、冻结和燃烧均属于此类。

**遗物效果（Effect）**：由玩家持有遗物驱动、按战斗事实触发的 proc 行为。`EffectManager` 从 `EffectRegistry` 同步实例并分发事件；Effect 只经 Enemy/`BuffHost` 门面施加或移除 Buff，Buff 不反向调用 Effect。

**迁移期兼容层**：为一次架构切换临时存在的 facade、bridge 或旧入口。当前运行时不保留此类层；`RunFlowUIAdapter` 是呈现边界、`BattleGateway` 是战斗边界，二者不是旧新实现之间的兼容层。
