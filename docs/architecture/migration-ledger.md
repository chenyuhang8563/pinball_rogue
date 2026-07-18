# 架构迁移台账（Phase 0–9）

## 使用规则

每阶段结束前记录实际变更、GUT/运行证据、临时 adapter/bridge 和已知风险。所有 `tests/**` 变更都是用户要求保留在工作树中的验证资产，**不得暂存或提交**；这不授权跳过 GUT。状态“待最终 review / checkpoint”只表示证据已收集，不表示 review 或 checkpoint 已完成。

| Phase | 状态 | 目标 | 关键验收 |
| --- | --- | --- | --- |
| 0 | **完成；本提交为 Phase 0 checkpoint** | 冻结运行图、依赖、Autoload、场景、UID 与测试基线。 | 初始 GUT 3/22/160；契约套件及 UID 修复后完整 GUT 4/24/196；图形主场景启动 smoke；未移动资源、未改变节点属性或业务行为。 |
| 1 | 未开始 | 建立 Content 逻辑边界与 Commerce 首个垂直切片；普通店/恶魔店委托 scoped Session。 | 交易原子性、报价过期、容量、技能替换、重复结算有 GUT；旧脚本不再保留第二套报价/结算规则；Commerce domain/application 无 `Control`、`get_tree()`、`/root`。 |
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

## 工作树内长期未提交测试资产

当前新增资产：

- `tests/Integration/test_scene_contracts.gd`：2 个契约测试，当前 `git hash-object` 为 `f0f0c8b80709a18dad17adfd95f12ca7b1e781bb`；
- `tests/Integration/test_scene_contracts.gd.uid`：`d67bcd4f71d0a260e011415436882c410ee0fa7a`；
- `tests/test_devil_shop_upgrade_offers.gd.uid`：`001f8d7cd1a6fdecb5aa2cb380493753bfe323be`；
- `tests/test_shop_upgrade_offers.gd.uid`：`c7ce8a47641760d36ad403cd75fa6bc9012e3c78`。

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
| 无 | — | — | — | Phase 0 未引入兼容层 |

## 停止条件

测试无法发现、Godot UID 无法解析、Missing Script/Resource、旧/新逻辑双结算或 run reset 状态泄漏时，立即停在当前 Phase 修复，不进入后续阶段。
