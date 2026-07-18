# 目标依赖与模块边界（Phase 0）

## 当前事实

当前源码虽按玩法概念分布在 `Run/`、`Shop/`、`Skills/` 等顶层目录，但跨模块依赖大量经 Autoload、`get_node_or_null()` 和硬编码场景路径完成。`Main._setup_run_flow()` 同时创建 UI、控制器并转发 Event（`Main/main.gd:232-286`）；`RunController` 同时编排流程、奖励、事件、关卡与状态服务（`Run/run_controller.gd:1-1163`）。因此现有目录不能证明稳定依赖方向。

## 目标目录

顶层领域目录保持仓库既有 PascalCase 风格，模块内部目录使用小写；资源与所属玩法共置，不建立全局 `scripts/scenes/resources` 技术分层。

```text
Game/Bootstrap/                  # 唯一组合根和 run scope
Content/{domain,data}/           # 不可变内容定义、稳定 ID、类别与目录
Commerce/{domain,application,presentation,data}/
Loadout/{domain,application,presentation,data}/
Run/{domain,application,presentation,data}/
Combat/{battle,marbles,skills,effects,status,levels,presentation}/
Core/{stats,localization}/
UI/shared/                       # 仅真正跨领域的展示预制
Assets/
Themes/
tests/{Commerce,Loadout,Run,Combat,Integration}/
docs/{architecture,adr,testing}/
```

只有 Commerce、Loadout、Run 这类具有完整业务闭环的模块采用四层目录；Combat 按运行时概念组织，避免机械分层。

## 固定依赖方向

```text
presentation → application → domain
application → Core 与显式注入的相邻模块接口
domain → 不依赖 Control、NodePath、Autoload 或场景树
Game/Bootstrap → 唯一跨模块装配点
```

- **Content**：拥有不可变 `ItemDefinition`、稳定物品 ID/类别和内容目录查询；不拥有玩家持有状态、价格或战斗行为。Commerce、Loadout、Combat 只读取 Content，Content 不反向依赖。
- **Commerce**：隐藏同一物品判定、报价、支付、购买/出售和发放；presentation 只提交购买/关闭等意图。
- **Loadout**：物品持有、弹珠排列、容量、技能槽与物品成长的唯一状态源。
- **Run**：流程控制器只编排状态迁移；节点决策、战斗计划、奖励和事件规则分别由深模块拥有。
- **Combat**：`BattleSession` 拥有战斗生命周期；遗物效果、玩家 Buff 与单位 `BuffHost` 各自有明确边界。
- **Core**：只放真正跨领域的数值与本地化基础能力。
- **Game/Bootstrap**：通过 `.tscn` 预置节点和 typed 引用装配依赖；不创建 UI、不做领域结算、不转发全局 Event。

## Run scope

不引入全局 Service Locator，也不创建巨型 `PlayerState`。`RunScope` 显式持有生命周期独立的 `Loadout`、`ItemProgression`、`RunWallet`、`RunHealth` 与 scoped `StatSystem`；相邻模块只接收所需的小接口或 typed 引用。

## 迁移期 facade / bridge 规则

1. facade/adapter 只能存在于正在执行的单个 Phase；只做接口适配，不保存第二份业务状态、不复制规则。
2. 新实现通过 characterization tests 后，必须在同一 Phase 迁移全部调用者并删除旧业务入口；不得让两个状态所有者跨阶段并存。
3. 唯一例外是 Event 的单向 `新 signal → 旧 Event` bridge，可按消费者批次短暂存在，并须在该批次验收前删除。
4. 禁止引入全局 Service Locator，禁止让新模块反向依赖旧 facade。
5. 每个临时入口必须在 [migration-ledger.md](migration-ledger.md) 登记创建阶段、调用者、删除条件和实际删除状态。

## 已知风险

- 该目标树是已锁定的迁移终态，不授权 Phase 0 移动文件；物理路径统一在 Phase 8 经 Godot 编辑器/Hastur 迁移。
- 当前 `Main`、`RunController`、Shop/DevilShop 与各 Autoload 仍跨越上述边界；迁移必须按 Commerce → Loadout → Run → Combat → Bootstrap → UI 的顺序稳定接口。
- 目录变短或脚本变短不是验收条件；真正标准是状态唯一所有者、显式依赖、小而稳定的接口与同一 seam 驱动真实行为。
