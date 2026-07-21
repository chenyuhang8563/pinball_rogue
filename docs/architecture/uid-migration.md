# Godot UID / 路径迁移规则（Phase 0）

## 历史基线

> 本节记录 Phase 0 的路径与 UID 风险模型。Phase 8 后的实际目录和入口以 [current-runtime.md](current-runtime.md) 为准；文中的 `Main/`、`RunController` 与旧路径不再是当前事实。

项目同时使用路径和 UID：启动场景由 UID 指向（`project.godot:14`），Autoload 既有 UID 也有路径（`project.godot:20-30`），而 Main 场景的外部资源同时保留 `uid` 与 `path`（`Main/main.tscn:3-12`）。代码中还大量存在字符串 `preload("res://...")`，例如 `Run/run_controller.gd:12-25` 与 `Main/main.gd:3-11`。因此一次移动需要覆盖序列化引用和脚本文本引用两条路径。

## 目标规则

1. 移动 Godot 资源优先使用 Godot 编辑器的 Move/Rename；让编辑器更新 `.tscn`、`.tres`、`project.godot` 和 import/UID 数据。不要手工批量替换 UID。
2. `.gd` 的 `.uid` 侧车文件与脚本必须作为一组移动；不得重建、复制或借用另一个资源的 UID。第一方生产脚本侧车由 `.gitignore` 按明确顶层目录解除忽略并纳入 checkpoint，以保证跨工作树稳定。测试脚本及其侧车同样可见，但按用户要求全部保持未提交；移动时仍必须成组处理。
3. 移动后以编辑器重导入/重扫为准，再审阅文本路径。UID 稳定不代表字符串路径稳定：所有 `preload/load`、`extends`、资源字段默认值、场景 `ext_resource` 路径都必须逐项检查。
4. 不编辑 `.tscn`/`.tres`/`.uid` 的 UID 值来“修复”引用；若编辑器无法解析，停止迁移，恢复到可解析状态后再分组处理。
5. 每个移动组必须在同一提交中完成“移动资源 + 更新引用 + GUT + 必要 smoke”；不允许留下半迁移的路径兼容分支，除非 [target-dependencies.md](target-dependencies.md) 中的 facade 规则明确允许。

## 逐组检查表

### A. 纯 GDScript / 纯资源类

- [ ] 通过编辑器移动 `.gd` 和其 `.uid`；测试脚本及其可见 `.gd.uid` 侧车也适用；检查 `class_name` 冲突。
- [ ] 搜索旧 `res://` 路径，更新所有 `preload`、`load`、`extends` 与测试预加载。
- [ ] 检查引用它的 `.tscn` / `.tres` 的 `ext_resource` 路径与 UID。
- [ ] 使用目标工作树的 GUT 命令运行受影响测试；通过后才进入下一组。

### B. 场景及其脚本

- [ ] 在编辑器移动 `.tscn`、挂载脚本及相关 `.uid`，保存场景。
- [ ] 检查每个场景的 `ext_resource`、嵌套 `PackedScene` 实例和动画轨道 NodePath。
- [ ] 检查 `project.godot` 的入口/Autoload 是否仍解析；入口 UID 的当前证据在 `project.godot:14`。
- [ ] 检查代码中的场景 `preload`；Main 当前预加载多个 UI 场景（`Main/main.gd:4-11`）。
- [ ] 运行 GUT，并按 baseline 的 smoke contract 验证启动场景与受影响场景契约。

### C. 关卡、定义与配置资源

- [ ] 以 `LevelDef.level_scene`、`RunFloorConfig`、奖励配置为一组，先检查资源字段后移动。
- [ ] 检查 RunController 的固定资源路径和预加载；当前弱/强/精英/Boss 路径在 `Run/run_controller.gd:18-24`。
- [ ] 验证关卡仍含根级 `EnemySpawns` 与 `Enemies`，并可由 RunController 建立编队（`Run/run_controller.gd:698-717`、`845-870`）。
- [ ] 运行对应 GUT；若关卡运行验证可用，再执行单场景 smoke 并留存证据。

### D. Autoload 与项目配置

- [ ] 先迁移消费者到注入端口或 facade，再修改 `[autoload]`；不得先删除配置。
- [ ] 对 UID 和路径两种 Autoload 条目逐项验证；当前 11 项清单在 `project.godot:20-30`。
- [ ] 检查 `/root/<Name>` 查找、`_get_autoload_node()` 和直接全局引用；消费者基线见 [autoload-consumers.md](autoload-consumers.md)。
- [ ] 验证启动、GUT 与相关 smoke，不把“无脚本搜索结果”当作运行时证明。

## 已知风险

- `project.godot` 的 UID 引用会掩盖部分路径移动问题，而 GDScript 的字符串 preload 不会自动由 UID 兜底。
- 关卡场景既含 `EnemySpawns` 数据又含 `Enemies` 预览/运行容器；只验证资源可加载不足以证明战斗生成仍正确。
- Phase 0 未移动资源，但在用户重新导入后通过目标工作树的 Godot editor executor 用 ResourceSaver 重存 13 个受影响 `.tscn/.tres`：替换 18 个既有脚本引用 UID，为 2 个 path-only 外部引用补写 UID，并移除 `Enemies/enemy.tscn` 的冗余 `load_steps` 元数据。未手工替换 UID，未改变节点属性、资源字段、脚本正文或场景结构。随后完整 GUT 与图形 smoke 中第一方 `invalid UID` 归零。第一方生产 `.gd.uid` 侧车纳入 checkpoint，`tests/**` 侧车保持可见且未提交。证据见 [docs/testing/baseline.md](../testing/baseline.md)。
