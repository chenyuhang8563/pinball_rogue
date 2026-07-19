# 架构迁移台账（Phase 0–9）

## 使用规则

每阶段结束前记录实际变更、GUT/运行证据、临时 adapter/bridge 和已知风险。所有 `tests/**` 变更都是用户要求保留在工作树中的验证资产，**不得暂存或提交**；这不授权跳过 GUT。状态“待最终 review / checkpoint”只表示证据已收集，不表示 review 或 checkpoint 已完成。

| Phase | 状态 | 目标 | 关键验收 |
| --- | --- | --- | --- |
| 0 | **完成；本提交为 Phase 0 checkpoint** | 冻结运行图、依赖、Autoload、场景、UID 与测试基线。 | 初始 GUT 3/22/160；契约套件及 UID 修复后完整 GUT 4/24/196；图形主场景启动 smoke；未移动资源、未改变节点属性或业务行为。 |
| 1 | **完成；本提交为 Phase 1 checkpoint** | 建立 Content 逻辑边界与 Commerce 首个垂直切片；普通店/恶魔店委托 scoped Session。 | 完整 GUT 9 scripts / 54 tests / 494 asserts；覆盖交易原子性、报价过期、容量、技能替换、出售、重复结算及真实 presentation delegation；旧迁移入口与第二套报价/结算规则清零；Commerce domain/application 无 `Control`、`get_tree()`、`/root`、`NodePath`。 |
| 2 | **完成；本提交为 Phase 2 checkpoint** | 将持有物品、弹珠排列、容量、技能槽与成长迁入 Loadout 和 run-scoped 状态。 | 唯一 RunScope 同时持有 Loadout/ItemProgression/RunWallet/RunHealth；Main 不再从 Shop UI 读取领域顺序；旧 Inventory、MarbleUpgradeSystem、四个 current adapter 与 Shop/Inventory Autoload 已删除。 |
| 3 | 未开始 | 拆分 RunState、RunFlowController、BattlePlanFactory、RewardService、EventResolver。 | RunController 只编排；所有节点类型路径只推进一次；验收前删除旧奖励、事件和流程实现。 |
| 4 | 未开始 | 建立 BattleSession，并将敌人死亡、弹珠跌落/碰撞、战斗生命周期迁为局部 typed signals；退役 Event。 | 业务目录无 `/root/Event`；正常死亡/跌出、多敌人、重复信号均只完成一次战斗；Event bridge 归零。 |
| 5 | 未开始 | 合并 Effect/Buff registry，建立 RelicEffectService、PlayerBuffService、BuffCatalog，保留 BuffHost 单位组件。 | registry 唯一、无 root 服务查找、modifier 可按稳定 source 清理，遗物与毒/冰/火状态有 GUT。 |
| 6 | 未开始 | 通过 Godot 编辑器/Hastur 创建 `Game/Bootstrap/game_main.tscn` 与 `run_scope.tscn`，Main 成为可视化组合根。 | composition 只用 typed 引用/configure/direct signals；切换 main_scene 后删除旧动态装配；run restart 无 scoped 状态泄漏。 |
| 7 | 未开始 | 迁移领域 presentation，治理 UI 构建、运行时属性写入和字体。 | UI 结构来自 `.tscn`；普通字体仅 10/12px 复合字体，漂浮伤害 Quaver 16px；各 UI 场景独立运行并按规定截图。 |
| 8 | 未开始 | 经 Godot 编辑器/Hastur 逐领域移动资源、保持 UID、清理旧目录和命名。 | 每组移动后无旧路径、Missing Script/Resource，相关及完整 GUT 通过；最终目录符合锁定目标。 |
| 9 | 未开始 | 完成 ADR/README/CONTEXT、测试镜像与去兼容审计。 | tests 迁至模块目录但仍未提交；adapter/bridge/旧实现/无消费者 Autoload 清零；完整 GUT 与开始到 Boss/失败重开流程通过。 |

## Phase 0 实际证据

- 初始基线：3 scripts / 22 tests / 160 asserts，exit 0（[原始日志](../testing/evidence/phase0-gut-baseline.log)）。
- 加入未提交场景契约后：4 scripts / 24 tests / 196 asserts，exit 0（[原始日志](../testing/evidence/phase0-gut-contracts.log)）。
- 首次图形 smoke 暴露 18 处第一方 `invalid UID`；用户重新导入后，经目标工作树 Godot editor executor 用 ResourceSaver 重存 13 个受影响资源：替换 18 个既有脚本引用 UID，为 2 个 path-only 外部引用补写 UID，并规范化移除 `Enemies/enemy.tscn` 的冗余 `load_steps`。未改变节点属性、资源字段、脚本正文或场景结构。修复后的完整 GUT 仍为 4/24/196、exit 0，第一方 UID warning 归零（[原始日志](../testing/evidence/phase0-gut-uid-fixed.log)）。
- 修复后的图形主场景运行 3 帧后 exit 0，日志无 `invalid UID`、`ERROR`、Parse、Missing Script/Resource（[原始日志](../testing/evidence/phase0-main-smoke-uid-fixed.log)）。这只证明启动 contract，不证明交互或完整流程。
- headless 变体出现 shader compiler 条件 `ERROR`，不作为干净证据（[原始日志](../testing/evidence/phase0-main-smoke-headless.log)）。

## Phase 1 实际证据

- 新增 `Commerce/domain` 的身份、报价、定价和结果模型，以及 `Commerce/application` 的 Normal/Devil Session、PurchasePlan、出售服务和四个 current-state adapters；`Content/README.md` 仅锁定逻辑所有权，未移动 `Items/item.gd` 或既有资源。
- `Shop` 与 `DevilShop` 只保留 presentation、依赖配置、意图转发和结果刷新；Slot 只发出稳定 `offer_id` 意图。Phase 1 使用过的 `purchase_*_with_dependencies`、`generate_upgrade_offers`、`grant_levelled_item`、`grant_offer_for_compat` 等迁移入口已在本 Phase 删除，生产与 tests 中调用者均为 0。
- PurchasePlan 对 Inventory、Progression、Wallet、Health 快照后执行奖励/支付；任一步失败逆序恢复并区分 `COMMIT_FAILED` 与 `ROLLBACK_FAILED`。普通出售同样原子覆盖移除、成长重置和入账。
- 完整 GUT：9 scripts / 54 tests / 494 asserts，exit 0；日志不含 ObjectDB、RID、orphan 或 resources-in-use 泄漏（[原始日志](../testing/evidence/phase1-gut.log)）。覆盖纯 Session、current adapters、真实 Shop Slot signal、真实 Shop 出售和 DevilShop confirm delegation。
- 用户明确当前游戏流程无需随时可运行，优先完成重构和测试。因此 verify 记录为 **DEFERRED**：本 Phase 不声明 runtime PASS，真实游戏交互验证推迟到后续收敛阶段。
- `Shop._grant_starting_marbles()` 仍直接修改当前 Inventory；它不是 Commerce 交易入口，登记为 Phase 2 Loadout 调用者迁移项。

## Phase 2 实际证据

- 新增唯一 `RunScope`，持有 `Loadout`、`MarbleLoadout`、`ItemProgression`、`RunWallet` 与 `RunHealth`。Main 首次初始化只播种 Dark marble 与 Dash；`reset_for_run()` 保留持有物和弹珠链顺序，仅重置成长、金币和生命。RunHealth 默认 10，Commerce `debit()` 至少保留 1，战斗 `damage()` 可降到 0。
- Main 通过预制场景装配普通 Shop 与 DevilShop，并向 InventoryPanel、DraftRewardPanel、SkillController、EffectManager、RunController 注入同一组 scoped ports。弹珠链只读取 `Loadout.get_chain_items()`；金币 HUD 监听 RunWallet；RunController 的奖励、事件、升级和生命访问已切换到 scoped 状态。
- 删除 `Inventory/inventory.gd`、`Run/marble_upgrade_system.gd`、四个 `Commerce/application/adapters/current_*` 及 UID 侧车，并删除 `project.godot` 的 Shop/Inventory Autoload。保留 `Inventory/inventory.tscn`、`Shop/shop.tscn`、StatSystem 与 EffectManager Autoload。
- 静态验收清零：生产代码中不存在 `/root/Inventory`、`/root/Shop`、`MarbleUpgradeSystem`、旧升级脚本路径、current adapter 路径、`RunController/MarbleUpgradeSystem`、Main 的 Shop MarbleBox 顺序回读或 Shop/Inventory Autoload 条目。`git diff --check` 通过。
- 关键 GUT：Loadout 5 scripts / 18 tests / 220 asserts；Commerce 4 / 25 / 204；普通/恶魔商店升级报价 2 / 18 / 177；Phase 2 装配契约 1 / 1 / 21，均全部通过。Commerce 测试退出时仍报告既有 RID/Texture/ObjectDB 资源泄漏信息；测试断言本身全部通过。本阶段未运行全量 GUT、完整游戏流程或截图。
- 首次 Loadout GUT 暴露 `Loadout.restore()` 的 Variant 推断解析错误；修复后又暴露 Dark marble 觉醒主属性 override 仍为 3.0。两项均修复并由上述 18/18 Loadout GUT 覆盖。
- Phase 3 的 RunFlow/Reward/Event 深拆分、Phase 5 的 Effect/Buff 收敛、Phase 6 的正式可视化 composition root、Phase 7/8 的 UI/字体与目录/资源迁移均明确延后。

## 工作树内长期未提交测试资产

当前工作树包含 36 个已修改或新增且继续保留的测试脚本/UID 侧车；完整路径与 `git hash-object` 见 [Phase 2 未提交测试资产](../testing/phase2-test-assets.md)。其中包括 scoped Commerce、Loadout/Progression/Run 资源、presentation delegation、升级报价回归和 Phase 2 装配契约。Phase 2 另删除了 2 份只验证旧 adapter/升级所有者的测试及 UID 侧车，有效断言已迁入保留资产。

上述文件及后续新增/更新/迁移的所有 `tests/**` 文件均保持可见且未提交，并在阶段台账更新路径与哈希。

每阶段开始和结束必须：

1. 执行 `git status --short`，区分生产改动与预期未提交测试资产。
2. 对未提交测试执行 `git hash-object <path>`；内容变化必须更新台账，不得悄然覆盖。
3. 执行 `git diff --check`，并分别审阅生产 diff 与 `tests/**` diff。
4. checkpoint 只使用逐路径 allowlist 暂存，禁止 `git add -A`、`git add .` 等宽泛命令。
5. 提交前确认 `git diff --cached --name-only -- tests` 与 `git diff --cached -- tests` 均为空，并审阅完整 staged 文件清单；`.gitignore` 只保证测试/侧车可见，不是提交保护机制。
6. 运行相关 GUT、完整 GUT；有运行时表面的阶段再执行对应完整流程。
7. Phase 0 的第一方 UID allowlist 与 `.gitignore` 一致：`Buffs`、`DevilShop`、`Effects`、`Enemies`、`Fliper`、`Inventory`、`Items`、`Levels`、`Localization`、`Main`、`Marbles`、`Run`、`Shop`、`Skills`、`Stats`、`UI`，并预留目标目录 `Commerce`、`Loadout`、`Combat`、`Content`、`Core`、`Game`。本阶段应新增并暂存 82 个生产 `.gd.uid`；暂存后上述当前目录不得仍有未跟踪 `.gd.uid`，同时 `tests/**` 必须继续未暂存。

## 临时 facade / bridge

| 名称 | 创建 Phase | 调用者 | 删除条件 | 状态 |
| --- | --- | --- | --- | --- |
| Commerce current Inventory adapter | 1 | 无 | Phase 2 切换 scoped Loadout 后删除 | **Phase 2 已删除** |
| Commerce current Progression adapter | 1 | 无 | Phase 2 切换 ItemProgression 后删除 | **Phase 2 已删除** |
| Commerce current Wallet adapter | 1 | 无 | Phase 2 切换 RunWallet 后删除 | **Phase 2 已删除** |
| Commerce current Health adapter | 1 | 无 | Phase 2 切换 RunHealth 后删除 | **Phase 2 已删除** |
| Phase 1 旧购买/发放 seam | 1 | 无 | Phase 1 验收前删除 | **已删除，调用者为 0** |

## 停止条件

测试无法发现、Godot UID 无法解析、Missing Script/Resource、旧/新逻辑双结算或 run reset 状态泄漏时，立即停在当前 Phase 修复，不进入后续阶段。
