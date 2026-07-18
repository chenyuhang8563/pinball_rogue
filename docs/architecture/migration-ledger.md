# 架构迁移台账（Phase 0–9）

## 使用规则

每阶段结束前记录实际变更、GUT/运行证据、临时 adapter/bridge 和已知风险。所有 `tests/**` 变更都是用户要求保留在工作树中的验证资产，**不得暂存或提交**；这不授权跳过 GUT。状态“待最终 review / checkpoint”只表示证据已收集，不表示 review 或 checkpoint 已完成。

| Phase | 状态 | 目标 | 关键验收 |
| --- | --- | --- | --- |
| 0 | **完成；本提交为 Phase 0 checkpoint** | 冻结运行图、依赖、Autoload、场景、UID 与测试基线。 | 初始 GUT 3/22/160；契约套件及 UID 修复后完整 GUT 4/24/196；图形主场景启动 smoke；未移动资源、未改变节点属性或业务行为。 |
| 1 | **完成；本提交为 Phase 1 checkpoint** | 建立 Content 逻辑边界与 Commerce 首个垂直切片；普通店/恶魔店委托 scoped Session。 | 完整 GUT 9 scripts / 54 tests / 494 asserts；覆盖交易原子性、报价过期、容量、技能替换、出售、重复结算及真实 presentation delegation；旧迁移入口与第二套报价/结算规则清零；Commerce domain/application 无 `Control`、`get_tree()`、`/root`、`NodePath`。 |
| 2 | 未开始 | 将持有物品、弹珠排列、容量、技能槽与成长迁入 Loadout 和 run-scoped 状态。 | 不从 Shop UI 读取领域顺序；不搜索 `RunController/MarbleUpgradeSystem`；删除旧 Inventory/升级 adapter 与对应 Autoload。 |
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

## 工作树内长期未提交测试资产

当前工作树包含 24 个已修改或新增的测试脚本/UID 侧车；完整路径与 `git hash-object` 见 [Phase 1 未提交测试资产](../testing/phase1-test-assets.md)。其中包括迁移后的两份既有 Commerce characterization、`tests/Commerce/**` 和扩展后的 `tests/Integration/test_scene_contracts.gd`。

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
| Commerce current Inventory adapter | 1 | Normal/Devil Session、SaleService | Phase 2 切换 scoped Loadout 后删除 | 活跃，仅适配当前 Inventory，不保存第二份状态 |
| Commerce current Progression adapter | 1 | Normal/Devil Session、SaleService | Phase 2 切换 ItemProgression 后删除 | 活跃，仅适配 MarbleUpgradeSystem |
| Commerce current Wallet adapter | 1 | Normal/Devil Session、SaleService | Phase 2 切换 RunWallet 后删除 | 活跃，仅适配 Shop.gold |
| Commerce current Health adapter | 1 | DevilShopSession | Phase 2 切换 RunHealth 后删除 | 活跃，仅适配 scoped 前的 StatSystem |
| Phase 1 旧购买/发放 seam | 1 | 无 | Phase 1 验收前删除 | **已删除，调用者为 0** |

## 停止条件

测试无法发现、Godot UID 无法解析、Missing Script/Resource、旧/新逻辑双结算或 run reset 状态泄漏时，立即停在当前 Phase 修复，不进入后续阶段。
