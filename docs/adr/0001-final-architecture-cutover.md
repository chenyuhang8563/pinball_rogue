# ADR-0001：锁定领域目录与无兼容运行时

- 状态：已接受
- 日期：2026-07-21

## 背景

Phase 0–8 已将状态所有权、流程、战斗、Effect/Buff、Bootstrap、UI 与 Godot 资源迁入目标领域目录。若保留旧名称的转发属性、可选旧参数或旧新实现之间的 bridge，后续调用者会重新依赖过渡路径，破坏单一状态所有者和可审计的依赖方向。

## 决策

1. `Game/Bootstrap` 是唯一跨领域组合根；跨领域业务状态依赖 typed 引用或显式端口，不使用退役 Autoload 或旧场景路径。当前基础设施 Autoload（例如 `StatSystem`、`Localization`、Registry）按项目约定从场景根安全解析，但不得充当旧领域状态或第二个流程所有者。
2. `RunScope` 是一局状态的唯一所有者；`RunFlowController` 只编排流程；`BattleSession` 是战斗生命周期所有者。当前唯一战斗完成路径为 `Enemy.defeated → BattleSession → BattleGateway → RunBattleFlow → RunFlowController`。
3. 迁移期 facade、bridge、旧业务入口和源代码兼容别名一律删除。具体而言，`BattlePlan.group`、`RewardOption.offer_id` 与无参 `RunState.advance_to_node()` 是唯一公开契约；不保留旧字段、旧参数或转发壳。
4. `RunFlowUIAdapter` 与 `BattleGateway` 保留为当前架构的呈现/战斗边界。它们不访问旧实现、不复制领域状态，也不属于迁移期兼容层。
5. 测试按被测领域归档，`tests/Game/` 镜像 `Game/` 的开发工具测试；只有跨领域组合、启动与场景契约测试放在 `tests/Integration/`。

## 后果

- 新调用者只能使用当前领域 API，旧路径的静态残留会直接被审计发现，而不是被兼容层掩盖。
- 迁移历史仍保留在台账、交接和证据文档中，但不得被解释为可运行入口。
- 改动公开领域 API 时必须同时迁移所有调用者与 GUT 行为断言；不得通过新增兼容别名延后迁移。

## 验证

- 递归 GUT 必须在正在验证的 worktree 上通过，且原始日志记录脚本、测试、断言、退出码与泄漏输出。
- 静态审计必须覆盖生产与测试中的 `preload/load`、场景/资源路径、Autoload、旧类名、临时 bridge 和公开兼容别名。
- 相关运行时流程须在已连接的 game executor 上独立运行并保存截图证据；没有 executor 时，缺少截图必须明确记录，不能以 GUT 取代运行时观察。
