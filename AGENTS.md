# Agent Notes

- 使用中文回答。
- Before editing, run `git status --short` and treat unrelated dirty files as user work.

## Godot

- Project uses Godot 4.6.1.
- Godot executable: `C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe`.
- `godot` is not on `PATH`.
- Prefer the running editor plus Hastur tools when live inspection or screenshots are needed.
- `GameExecutor` is only available while the game process is running and connected.

## Verification

- Use GUT as the test evidence. Do not use startup checks or standalone scripts as proof that tests passed.
- Reliable local GUT invocation on this machine:

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

- After GUT passes, run the game in Godot when runtime validation is relevant.
- Capture screenshots from a running game only when a `game` executor is connected.
- 生成多个测试场景，每个测试场景单独用 `godot-remote-executor` 运行并且截图保存，必须有证据支持。

## Autoloads And Tests

- Do not assume autoload singleton names such as `Event`, `Inventory`, `Shop`, or `StatSystem` are compile-time globals.
- Resolve autoloads from `/root` with `get_node_or_null()` before calling methods or connecting signals.
- Free test-created Nodes/Resources when possible to avoid RID/ObjectDB leak warnings.

## Stat System

- Final gameplay values should flow through `StatSystem.get_stat(stat_id, entity_id, context)`.
- Static bases live in `Resources/stats/**/*.tres` as `StatDef` resources.
- Register new stats in `Stats/stat_registry.gd`; avoid new hard-coded numeric getters in gameplay managers.

## Content Integration

- New gameplay content should enter through the existing `Shop -> Slot -> Inventory.add_item()` purchase path.
- Item-driven marble unlocks belong on `Item.EffectType` and should be resolved through `EffectRegistry`.
- Keep `Main/main.tscn` free of special marble test instances unless explicitly requested.
- Cast falling bodies to `Marble` before reading `marble_type`; `Event.marble_fell` is typed as `RigidBody2D`, so non-marble bodies must be ignored safely.

## Worktree Hygiene

- Do not revert user changes unless explicitly requested.
- `Marbles/bomb_marble.tscn`, `Main/util.gd`, and `Main/util.gd.uid` may be dirty or untracked from user work; do not fold them into unrelated fixes.
