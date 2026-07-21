# Phase 6 → Phase 7 交接文档

## 一句话总结

Bootstrap 组合已可视化：四个运行时 Bootstrap 节点（BattleSpawner/Enemies/BattleGateway/RunFlowController）预置于 `main.tscn`，`RunScope` 改为从新场景 `Game/Bootstrap/run_scope.tscn` 实例化（创建/激活/销毁均为场景树中明确节点），代码只保留 configure 顺序、信号接线与生命周期决策。递归 full GUT 153/153 通过。

## 起点与终点

- 起点 HEAD：`fc71041`（Phase 5 完成，Effect/Buff 已分离）。
- 终点：Phase 6 完成；本交接随 Phase 自动化流水线提交入库。
- 规格来源：GitHub Issue（Phase 6，流水线生成）+ 台账 Phase 6 行。

## 完成的变更

### 可视化 Bootstrap 结构
- `Main/main.tscn`：在 Main 下预置四个 Bootstrap 节点——`BattleSpawner`（`Run/battle_spawner.gd`）、`Enemies`（Node2D，基础敌人容器）、`BattleGateway`（`Run/battle_gateway.gd`）、`RunFlowController`（`Run/run_flow_controller.gd`）。结构在场景中可视化、可审计；脚本 UID 与各 `.gd.uid` 一致，无 Missing Script。
- `Game/Bootstrap/run_scope.tscn`（新文件）：`RunScope` 场景（Node + `Game/Bootstrap/run_scope.gd`）。
- 等价说明：台账所指的 `game_main.tscn` 以「主场景 `main.tscn` 原地承载 Bootstrap 结构」等价实现（保留主场景 UID `uid://cbbk5l2e1na0y` 与 `project.godot` 不变，避免破坏已固化的场景契约）。

### main.gd 生命周期
- `_setup_run_scope`：`RunScope` 改为 `RunScopeScene.instantiate()`（可视化创建）；initialize（激活）、`_discard_run_scope`/`_exit_tree` dispose（销毁）语义不变，`_ever_initialized` 终止语义保持。
- `_setup_run_flow_composition`：四个节点 slot 改为 `_resolve_composition_node(slot_name, override_value, creator, type_check)` 解析——注入 override 优先（替换同名预置节点）、否则用场景预置节点、都不在才动态 `new()`（如 dispose 后重建）。configure 顺序、单一共享 `RunRandomSource`、Gateway 三回调注入、UI adapter 接线、`start_run` 位于全部接线之后——全部保持不变。
- `_resolve_composition_node` 为事务式：错误类型或已被其他分支拥有的 override 会被拒绝且**不触碰**预置节点；解析后统一类型/命名/挂载到 Main；新增空值保护，解析失败走 `_dispose_failed_run_flow_composition` 返回 false。

### 测试
- `tests/Integration/test_scene_contracts.gd`：Bootstrap 四节点存在 + 脚本基类匹配断言。
- `tests/Integration/test_main_run_flow_composition.gd`：新增 5 个测试锁定新行为——使用预置节点（而非 new）、合法 override 替换同名 slot、错误类型 override 回退到预置、外部 parent override 被拒且不误释放、dispose 后重建动态 slot。

## 关键设计决策及原因

1. **预置 + 事务式 slot 解析**（而非每运行实例化整体 composition）：保留现有测试契约（节点为 Main 直接子节点、dispose→null、override 注入），同时让 Bootstrap 结构真正可视化。事务式解析确保失败注入不会破坏合法预置节点（review F1/F2 已修复）。
2. **RunScope 不预置、从场景实例化**：`RunScope.dispose()` 是终止性的（不可重新 initialize），故每次组合创建新实例（可视化创建/销毁），预置会与其生命周期语义冲突。
3. **`main.tscn` 原地承载而非新建 `game_main.tscn`**：等价实现，避免主场景 UID/project.godot 变更破坏已固化契约。

## 验证状态

- 递归 full GUT：**153/153，1679 asserts，exit 0**（`docs/testing/evidence/phase6-full-gut.log`，27 scripts）。
- headless 生产 smoke：exit 0（`docs/testing/evidence/phase6-headless-smoke.log`）。
- review（codex-cowork deep）：默认启动路径无阻塞问题；F1/F2（override 类型/所有权边界）、F3（测试未锁定新行为）均已修复。

## 已知风险 / 遗留

- **运行时 gameplay 截图仍未取得**：Hastur broker 在运行但无 executor 连接（Godot 编辑器未打开）。Bootstrap 结构正确性由 GUT + headless smoke 覆盖；可视化/交互截图待编辑器可用。
- UI 面板（NodeChoice/DraftReward/RunEvent/DevilShop/Shop/Inventory）仍在代码中 instantiate（`_setup_run_flow`）；其场景化、字体与表现治理属 **Phase 7**，本阶段未动（避免同时改两个验收面）。
- `FloorHud`/`InventoryPanel` 仍走代码 fallback 创建（Phase 7 预置）。

## Phase 7 注意事项

- Phase 7 = UI presentation、构建与字体治理：普通 UI 只允许 10px/12px；除 Devil Shop 底部 reward button 外，禁止 8/9/11px 与 Fusion Pixel 8px 派生资源。英文与数字使用 `quaver.ttf`，中文使用对应字号的 Fusion Pixel；中英混排统一通过 `quaver_fusion_10.tres`/`quaver_fusion_12.tres` 复合字体实现（Quaver 为主字体、Fusion Pixel 为中文 fallback）。UI 结构 100% 由 `.tscn` 定义；代码不得设置位置、大小、颜色、字体、间距等 UI 属性，仅允许根据运行时状态控制 UI 显隐。**需通过 Hastur MCP 在编辑器搭建/验证 UI**——请先确保 Godot 编辑器（含 Hastur 插件）已连接。
- 全量审计 title 类型文本的字体主线，不限于当前已知遗漏：节点选择标题“选择下个节点”、升级标题“选择一个物品升级”和“技能”等。所有普通 UI 的 Label、RichTextLabel、Button 及主题覆盖均需接入对应的 10px/12px 复合字体资源。例外仅有两类：漂浮伤害数字继续使用 `quaver.ttf` 16px；Devil Shop 底部 reward button 可保留例外字号，但仍使用 Quaver 主字体、Fusion Pixel 中文 fallback 的复合字体。
- 将蓝色边框的 UI 窗口统一改为黑色基调，参考节点选择框的普通搭配；不增加额外装饰色。Devil Shop 的 UI 框保持原样，仅处理其他蓝色窗口。
- 将 `_setup_run_flow` 中动态 instantiate 的 UI（NodeChoice/DraftReward/RunEvent/DevilShop/Shop/Inventory/FloorHud）迁移为主场景预置节点；届时更新 `test_main_run_flow_composition` 中「尚不存在 NodeChoicePanel」「dispose 后 UI 路径为空」等断言为「存在但未配置/未呈现」。
- 保持 Bootstrap 不变式：UI 预置不得改变 configure 顺序与单向依赖（Effect→Buff）；`_resolve_composition_node` 仅用于 Bootstrap 四节点，UI 预置另行处理。
- 停止条件（沿用台账）：UI 属性出现在代码、字号违规、Missing Script/Resource、focused/full GUT 卡住或失败时，停在当前 checkpoint 先消除风险。

## Autoload 可审计性（Phase 6 附加）

- Main/组合直接依赖：`StatSystem`（Scope/`_read_stat`）、`EffectManager`（Scope 初始化后配置）、`FloatDamageTextPool`（Gateway release 回调）、`Localization`（UI 解析）。
- `EffectRegistry`/`BuffRegistry`：分别由 Effect 域/Buff 域解析（Phase 5），不由 Bootstrap 重复接线。
- `GameExecutor`：Hastur 运行时执行器，与 Bootstrap 无耦合。
