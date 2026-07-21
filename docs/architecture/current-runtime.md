# 当前运行时事实（Phase 8）

本文记录当前工作树的运行时结构；Phase 0–8 的历史决策和证据仍保留在 `docs/handoffs/`、阶段规划、迁移台账和测试证据中，不应再将那些文件中的旧路径视为当前入口。

## 入口与组合

- `project.godot` 的 `run/main_scene` 仍通过 UID 指向启动场景；当前解析路径为 `res://Game/Bootstrap/main.tscn`。
- `Game/Bootstrap/main.tscn` 是唯一跨领域组合根。运行时直接包含 `BattleSpawner`、`Enemies`、`BattleGateway`、`RunFlowController`、`RunScope`、`SkillController`、`Shop` 与 `InventoryPanel` 等预置节点。
- `RunScope` 持有 Loadout、ItemProgression、RunWallet、RunHealth 与 scoped StatSystem；流程状态迁移由 `RunFlowController` 编排，战斗生命周期由 `Combat/battle/BattleSession` 路径拥有。

## Autoload

当前登记 7 个 Autoload：

- `Localization` → `Core/localization/localization.gd`
- `EffectManager`、`EffectRegistry` → `Combat/effects/`
- `GameExecutor` → 开发期 Hastur 工具 UID
- `StatSystem` → `Core/stats/stat_system.gd`
- `BuffRegistry` → `Combat/status/buff_registry.gd`
- `FloatDamageTextPool` → `Combat/presentation/float_damage_text_pool.gd`

`Event`、`BuffManager`、`Shop` 与 `Inventory` 不是当前 Autoload。

## 目录边界

当前运行时资源遵循 [项目文件组织规范](../agents/project-structure.md)：完整业务模块使用 `presentation → application → domain`，Combat 按运行时概念组织，跨领域视觉预制仅保留在 `UI/shared`。旧顶层 `Main`、`Enemies`、`Marbles`、`Skills`、`Effects`、`Buffs`、`Resources` 等路径已迁出，不应新增引用。

## 验证

Phase 8 的目录迁移以 GUT、Godot 资源加载审计和已连接 game executor 的独立场景运行作为证据。具体规则见 [测试证据基线](../testing/baseline.md)，迁移路径规则见 [UID 迁移规则](uid-migration.md)。
