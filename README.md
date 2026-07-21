# RoguePinball

基于 Godot 4.6.1 的 2D 弹珠 Roguelike 原型。玩家在一局流程中选择节点、进入战斗、结算奖励或事件，并通过商店、遗物、弹珠和技能逐步构筑。

## 运行

- Godot：**4.6.1**（GL Compatibility）。
- 启动场景：`res://Game/Bootstrap/main.tscn`，由 `project.godot` 的 UID 入口引用。
- 使用 Godot 编辑器打开项目并运行主场景；左右方向键控制挡板。

## 当前架构

`Game/Bootstrap` 是唯一跨领域组合根。它从场景预置节点和显式依赖建立一次运行流程；领域模块不通过旧 Autoload、场景树搜索或兼容入口取得业务状态。

```text
Game/Bootstrap/        组合根、RunScope、主场景
Content/               不可变物品定义与内容资源
Commerce/              商店报价、交易与展示
Loadout/               持有物、弹珠链、成长
Run/                   节点、战斗计划、奖励、事件与流程
Combat/                战斗生命周期、弹珠、技能、效果与状态
Core/                  跨领域数值与本地化
UI/shared/             无领域状态的复用展示组件
tests/                 按 Game/领域归档；组合与场景契约在 Integration/
```

- `RunScope` 是一局状态的唯一所有者：`Loadout`、`ItemProgression`、`RunWallet`、`RunHealth` 与 scoped `StatSystem`。
- `RunFlowController` 只编排流程状态；节点、战斗计划、奖励和事件规则分别由其应用服务拥有。
- 战斗完成路径唯一：`Enemy.defeated → BattleSession → BattleGateway → RunBattleFlow → RunFlowController`。
- `EffectManager` 管理遗物 proc；`BuffHost` 管理宿主状态；只允许 Effect 经宿主门面施加 Buff，Buff 以 typed 事件对外通知。

详细运行时事实见 [当前运行时结构](docs/architecture/current-runtime.md)，边界与依赖方向见 [目标依赖](docs/architecture/target-dependencies.md)，设计决策见 [ADR](docs/adr/0001-final-architecture-cutover.md)。

## 验证

测试使用 GUT。请让 `--path` 指向当前 checkout：

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path <当前工作树绝对路径> -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

历史与当前的可审计证据、运行时验证边界写在 [测试证据基线](docs/testing/baseline.md)。
