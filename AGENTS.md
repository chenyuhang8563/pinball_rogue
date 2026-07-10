# Agent Notes

- 使用中文回答。
- Before editing, run `git status --short` and treat unrelated dirty files as user work.

## Godot

- Project uses Godot 4.6.1.
- Godot executable: `C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe`.
- `godot` is not on `PATH`.
- Prefer the running editor plus Hastur tools when live inspection or screenshots are needed.
- Never stop Godot by broad process-name commands such as `Stop-Process Godot_v4.6.1-stable_win64` or killing all matching Godot processes. If a process must be stopped, record the PID returned by the launch command and stop only that specific process, or use Godot/editor APIs to stop the running game.

## Verification

- Use GUT as the test evidence. Do not use startup checks or standalone scripts as proof that tests passed.
- Reliable local GUT invocation on this machine:

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

- After GUT passes, run the game in Godot when runtime validation is relevant.
- Capture screenshots from a running game only when a `game` executor is connected.
- Save screenshot evidence under `E:\Projects\pinball_rogue\.codex\hud_screenshots`; do not use `.codex_validation`.
- 生成多个测试场景，每个测试场景单独用 `godot-remote-executor` 运行并且截图保存，必须有证据支持。

## Autoloads And Tests

- Do not assume autoload singleton names such as `Event`, `Inventory`, `Shop`, or `StatSystem` are compile-time globals.
- Resolve autoloads from `/root` with `get_node_or_null()` before calling methods or connecting signals.
- Free test-created Nodes/Resources when possible to avoid RID/ObjectDB leak warnings.

## UI 搭建与架构规范 (UI Construction & Architecture)
- **UI 约束:** 严禁使用代码（如 `Control.new()`）搭建、组装 UI 结构。所有 UI 必须在 Godot 编辑器中作为场景（.tscn）可视化创建（需要使用 hastur broker mcp）。
- **代码职责:** 逻辑脚本仅允许处理数据传递、UI 状态刷新、信号（Signals）绑定与分发。动态生成的 UI 元素必须通过 `preload` 编辑器导出的场景并 `instantiate()` 载入，禁止代码硬编码布局。
- **禁止在代码中编辑 UI 属性:** 所有 UI 属性（位置、大小、颜色、字体、间距、可见性等）必须在 `.tscn` 场景文件或 `.tres` 主题/资源中设置，不得通过 GDScript 修改。代码中写 `rect_position`、`size`、`color`、`visible` 等 UI 属性赋值视为违规。运行时动态样式需求应通过主题（Theme）或场景预制变体实现。
