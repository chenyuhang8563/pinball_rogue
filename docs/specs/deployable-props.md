# Spec: 布设系统（Deployable Props）

> 状态：draft（待发布 issue tracker）  
> 领域词汇见 `CONTEXT.md`；架构决策见 `docs/adr/0001-activate-then-deploy.md`；组件行为规范见 `docs/design/components/level-base-environment-components.md`。

## Problem Statement

玩家只能通过固定的桌面布局与敌人碰撞体验战斗，无法主动改变桌面拓扑。现有战斗环境组件（木桶、弹力板、弹弓、传送门）全部由关卡编辑器预放置，玩家对桌面没有任何塑造能力。

## Solution

在每次战斗开始前引入**布置阶段**：玩家选定下一战斗节点后，进入一个可暂停的配置界面，把自己**持有**的桌面组件**布设**到新关卡的战斗桌面上（自由定位 + 自由角度旋转），确认后开始战斗。布设物贯穿本场战斗，随本场关卡释放自动销毁。组件是**持有资产**（可积累、可重复布设、布设不消耗），第一版以初始套件起步。

## User Stories

1. As a player, I want to deploy held components (barrel, booster, slingshot, portal) onto the battle table before a battle, so that I can shape the battle to my advantage.
2. As a player, I want a deployment phase to appear after I select a battle node and before combat starts, so that I can prepare my table layout.
3. As a player, I want the deployment phase to pause the game, so that I can place components carefully without the marble rolling.
4. As a player, I want the deployment phase to show the actual upcoming battle table, so that I can see where enemies and terrain are before placing.
5. As a player, I want a bottom prop-card bar showing my held components, so that I know what I can place.
6. As a player, I want to select a prop-card to enter placement mode, so that I can start positioning that component.
7. As a player, I want a ghost preview of the component following my cursor, so that I can see where it will land before confirming.
8. As a player, I want the ghost to turn green when valid and red when invalid, so that I know whether my placement is legal.
9. As a player, I want to rotate the ghost freely (scroll wheel or Q/E keys, Shift to snap 15°), so that I can orient direction-sensitive components.
10. As a player, I want to left-click to confirm a placement, so that the component lands on the table.
11. As a player, I want to right-click or press Esc to cancel placement, so that I can back out without placing.
12. As a player, I want invalid placements blocked (overlapping other components/flippers/walls, out of table bounds, inside kill zone), so that I cannot create broken or unfair layouts.
13. As a player, I want a barrel I place to behave exactly like an editor-placed barrel (hit counting, coin drops, break), so that my placed props work the same as native ones.
14. As a player, I want a booster I place to have a proper orientation, so that its forward-axis launch works in my chosen direction.
15. As a player, I want to place portal endpoints one at a time and have matching endpoints auto-pair in placement order, so that I can build a functional portal pair.
16. As a player, I want to see a ghost connection line to the already-placed endpoint when placing a portal's second endpoint, so that I know which pair I'm completing.
17. As a player, I want the second portal endpoint validated for whole-pair safety (exit clear, not in kill zone) before it can land, so that I never create a disabled/dead portal.
18. As a player, I want my placed components to remain for the whole battle, so that my investment in the table layout pays off.
19. As a player, I want my placed components cleared automatically when the battle ends, so that each battle starts from a fresh table.
20. As a player, I want to deploy the same component type multiple times if I hold enough, so that I can place several barrels for a farming strategy.
21. As a player, I want the deployment phase to be skippable (deploy nothing and start), so that I'm not forced to place if I don't want to.
22. As a player, I want to be able to start with an initial kit of components (barrel, booster, portal), so that the feature is usable from the first run without needing to earn components.
23. As a player, I want component acquisition (drops, shop, rewards) to be deferred to a later slice, so that the first version focuses on placement interaction.
24. As a player, I want the active-skill slot to be disabled while the deployment panel is open, so that I cannot fire a skill during deployment.
25. As a player, I want the deployment phase to also run before a boss battle (after the final reward), so that I can prepare for the boss too.
26. As a player, I want a bottom prop-card bar showing each held component as a card with its icon, name and held-count badge, so that I can see and pick what I own.
27. As a player, I want a selected prop-card to visually highlight, so that I know which component I'm about to place.
28. As a player, I want the ghost preview to render semi-transparent so that the real table beneath it stays visible while I position.
29. As a player, I want the ghost to tint green when valid and red when invalid, so that placement legality is readable at a glance.
30. As a player, I want direction-sensitive components to show a direction indicator on the ghost while I rotate, so that I can see which way the booster/portal will face.
31. As a player, I want a ghost connection line linking to the already-placed portal endpoint, so that I can see the pair I'm completing.
32. As a player, I want the deployment phase to present as a full-screen modal with a scrim backdrop, a title and hint text, and a Start Battle button, so that the mode is clearly separated from combat.

## Implementation Decisions

- **术语**：`组件` / `布设` / `布设物` / `布置阶段`（`CONTEXT.md`）。不用「道具」。
- **时机**：布置阶段在**选定战斗节点之后、开战之前**（`Run/application/run_flow_controller.gd` 的 `_commit_node_choice` → `_start_battle` 路径间插入）。BOSS 层无选节点阶段，在奖励确认后、开战前走同路径。
- **架构**：`BattleGateway.start` 拆为「激活关卡」（`_activate_level_for`，含既有校验）与「开始会话」两步（`ADR-0001`）。布置阶段插在两步之间。已知成本：所有直接 `gateway.start(...)` 调用点需迁移到新 API。
- **布设物生命周期**：布设物实例化进新关卡 `TableBase/TableComponents`，贯穿本场，随关卡释放自动销毁。复用 `ProducedMarbleSpawner` 的 `call_deferred` add_child 模式规避物理查询期错误。
- **来源**：持有组件资产（与 `InventoryPanel` 持有概念一致），布设不消耗、可重复布设。初始套件起步（桶×1、弹力板×1、传送门×1），获得途径为后续切片。
- **摆放模型**：自由摆放（无网格）+ 幽灵预览 + 红绿校验。校验规则沿用 `docs/design/components/level-base-environment-components.md` §6 + `KillZone.contains_global_point`：重叠任何组件/挡板/墙 → 红；越出桌面边界 → 红；在 kill zone 内 → 红。
- **旋转**：自由角度；滚轮/Q-E 连续旋转，Shift 吸附 15°。旋转仅改 `rotation` 属性，碰撞体/感应区同步。
- **传送门**：单端布设；按布设顺序自动配对；ghost 显示与已放端点的连线预览；落第二个端点时校验整对安全（出口前方 32px 无障碍、不在 kill zone），不安全禁止落位。
- **上限**：无上限（空间约束兜底）；每个组件种类的 CSV 上限列（默认无穷）预留数据出口。
- **接线缝**：`CombatDropDirector` 抽 `register_component()` 方法，布设物落位后注册（运行时布设的桶需手动接 `barrel_hit`）。
- **UI**：prop-card 底部栏（持有组件过滤视图）；`present_*`/`clear`/`paused`/focus 沿用 main.tscn 预置面板配方；须加入 `main.gd:_connect_active_skill_panel_blockers` 阻塞面板清单。
- **流程状态**：布置阶段需要一个 `RunState.Phase` 值（如 `DEPLOYING`）与控制器信号，遵循 `run_flow_controller.gd` 现有信号/状态模式。
- **视觉 — prop_card 底部栏**：底部横向卡片栏，复刻 `slot.tscn` 骨架（Panel + Icon + 名称 + 持有数量角标），每个持有组件一张卡片，随持有动态增删。卡片规格：尺寸与 `slot.tscn` 一致（72×72）、图标用组件自身 `Sprite2D` 纹理、名称与数量用 `text_10.tres` 字号（`text_12.tres` 用于标题）、主题沿用 `slot.tscn` 的 `theme`。选中态高亮（描边/背景色）。
- **视觉 — 幽灵预览**：布设模式下跟随鼠标的半透明组件实例：透明度约 50%、无碰撞实体（纯视觉）；有效时整幅绿色着色、无效时整幅红色着色；方向敏感组件（弹力板/传送门）叠加方向指示（箭头/朝向标记）随旋转同步；传送门布设第二个端点时，ghost 与已放端点之间画一条连线预览。复用组件自身场景的 `Sprite2D`，仅改 `modulate` 与可见性，不复制材质。
- **视觉 — 布置面板整体**：全屏模态，沿用 `node_choice_panel.tscn` 配方（`Backdrop` ColorRect 全屏吞点击 + `CenterContainer`/`Panel` 布局）；半透明 scrim 背景、顶部标题（布置阶段）+ 底部提示文案（旋转键位等）+ 右下「开始战斗」按钮；面板打开时树暂停、仅该面板可交互。字号规范：标题 `text_12`、正文/提示 `text_10`，禁止 8px 字体。

## Testing Decisions

- **好测试的标准**：只测外部行为（编排、落位结果、校验结果），不测实现细节（不断言内部状态/私有方法）。
- **主接缝 —— `RunFlowController` 状态机**（`tests/Run/test_run_flow_controller_phase3.gd` 模式：真实控制器 + `FakeGateway`，内存调用、无物理帧）：
  - 选战斗节点 → 进入布置阶段 → 确认 → 战斗开始；跳过布置直接开战。
  - BOSS 层奖励确认 → 布置阶段 → 开战。
  - 布置阶段不消耗组件持有（重复布设）、可跳过。
  - 现有断言 `phase == BATTLE_ACTIVE` / `gateway.started_plans` 的测试需保持不破坏（布置阶段为 `select_node` 内的同步子状态）。
- **辅接缝 1 —— `BattleGateway` 真实关卡**（`tests/Run/test_battle_gateway.gd` 模式）：激活关卡 → 布设物实例化进 `TableBase/TableComponents` → 开始会话；布设物落在真桌面并通过校验。需迁移现有 `gateway.start(...)` 调用点到新两步 API。
- **辅接缝 2 —— 组件行为**（`tests/Combat/table_components/test_environment_components.gd` 模式）：布设校验逻辑（重叠/越界/kill zone/传送门配对安全）作为组件能力直接测；运行时布设的桶 `barrel_hit` 正确接线到 `CombatDropDirector`（抽 `register_component()` 后）。
- **先例**：`tests/Combat/lightning/test_lightning_chain_full_game.gd`（boot 真实 Main 驱动完整战斗）为端到端可选测试的先例，非必须。
- **视觉断言**：prop_card 栏按持有组件渲染（数量角标、选中高亮）；幽灵半透明、绿/红着色随校验切换、方向指示随旋转更新；传送门第二个端点的 ghost 连线存在；布置面板打开时树暂停、仅该面板可交互。截图证据按 AGENTS.md 存 `.codex/hud_screenshots`，gdmcp 截图。

## Out of Scope

- 组件**获得途径**（掉落表 / 商店 / 奖励池与遗物同构）—— 后续切片。
- 布设物**跨战斗持久**（整局保留）—— 本版布设物随关卡销毁。
- 布设物**回收 / 拆除 / 移动**（本版确认后不可撤销；后续切片）。
- 每个组件种类**上限数值**的实际平衡调参（预留 CSV 列，本版不调）。
- **自由角度旋转的重叠校验 OBB** 精确几何（用组件真实碰撞形状相交即可，不手写数学）。
- 布设物对**掉落经济**的重新平衡（无上限 farm 风险：先靠掉落导演 12 枚并发上限兜底，记录不调）。

## Further Notes

- 网格方案已否决（弹珠桌路线是弧线、组件尺寸不一，网格限制布局且需新建渲染系统）。
- 布置面板须加入 `main.gd:_connect_active_skill_panel_blockers` 的阻塞面板清单。
- 布设物直接进活关卡意味着「所见即所得」——玩家布置时看到真实下一场敌人与布局。
