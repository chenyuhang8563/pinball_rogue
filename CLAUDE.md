# CLAUDE.md

Guidance for Claude Code when working in this repository.

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

- 不要为了 TDD 人为编写“因为缺失某个实现而预期失败”的 GUT 测试；这类失败没有验证价值。
- 只有在测试可正常执行时才运行 GUT：GUT 失败时 Godot 可能卡死且不产生有效输出，应先通过静态检查或代码审阅定位并消除该风险。

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

## UI 字体规范
- 中文字形一律使用 Fusion Pixel 系列字体；英文字母和数字一律使用 `quaver.ttf`。
- UI 字体只允许使用 10px 和 12px 两档；禁止使用 8px、9px、11px 或其他字号。**例外：** 漂浮伤害数字（如 `burn_floating_text.tscn`、`floating_text.tscn`）统一使用 `quaver.ttf` 16px，与普通伤害字号对齐，无需走 `.tres` 复合字体。
- 禁止引用 Fusion Pixel 8px 字体及其派生资源（包括 `quaver_fusion_8.tres`、`text_8.tres`）；已有界面在修改时必须迁移到 10px 或 12px。
- 10px 文本使用 `quaver_fusion_10.tres` / `text_10.tres`，12px 文本使用 `quaver_fusion_12.tres` / `text_12.tres`。
- 中英混排必须使用 `.tres` 复合字体资源：以 Quaver 为主字体、对应字号的 Fusion Pixel 为中文 fallback，确保英文和数字不会随中文语言环境切换为 Fusion。

