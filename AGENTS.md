# Agent Notes

## Godot Runtime

- The project uses Godot 4.6.1. On this machine the executable is `C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe`; `godot` is not on `PATH`.
- Headless runs may be used only for quick startup/load checks. Do not cite headless output as evidence that tests passed.
- Quick headless startup checks, when useful:
  - `& 'C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --quit-after 1`
  - `& 'C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . -s res://tests/<test_file>.gd`
- A shader compiler message like `Condition "!actions.custom_samplers.has(...)" is true` appears during headless startup. Do not treat it as caused by unrelated gameplay/shop changes unless the change touches shaders or rendering setup.

## Verification Workflow

- Do not use headless runs as proof that tests passed.
- Run the test suite with GUT and use the successful GUT result as the test evidence.
- After GUT tests pass, run the game in Godot.
- Once the game is running, stop the current conversation and ask the user to manually pause the SceneTree.
- Only after the user confirms the SceneTree has been paused, use the `godot-screenshot` skill/tool to capture a screenshot as evidence that the running game is normal.

## Autoloads And Tests

- Do not assume autoload singleton names such as `Event`, `Inventory`, or `Shop` are always available as compile-time global identifiers in standalone `-s` test scripts.
- For code that should load cleanly in both game scenes and headless scripts, prefer resolving autoload nodes from `/root` with `get_node_or_null()` before calling methods or connecting signals.
- When writing lightweight `SceneTree` tests, create or fetch required autoload nodes explicitly under `get_root()` so tests are not dependent on editor-only state.
- Free test-created Nodes/Resources when possible to avoid noisy RID/ObjectDB leak warnings.

## Bomb Marble Integration

- Bomb marble should enter normal gameplay through the existing `Shop -> Slot -> Inventory.add_item()` purchase path, not through a pre-placed test node in `Main/main.tscn`.
- Item-driven marble unlocks should be represented on `Item.EffectType` and checked via `Inventory.has_effect(...)`.
- Keep `Main/main.tscn` free of special marble test instances unless the user explicitly asks for test fixtures in the scene.
- Refill/spawn logic should cast falling bodies to `Marble` before reading `marble_type`; `Event.marble_fell` is typed as `RigidBody2D`, so non-marble bodies should be ignored safely.

## Worktree Hygiene

- Before editing, check `git status --short` and distinguish pre-existing user changes from agent changes.
- In this repo, `Marbles/bomb_marble.tscn`, `Main/util.gd`, and `Main/util.gd.uid` may already be dirty or untracked from user work. Do not revert or fold them into unrelated fixes without explicit instruction.
