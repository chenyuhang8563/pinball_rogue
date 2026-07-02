# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**RoguePinball** — a 2D pinball-roguelike prototype built in Godot 4.6.1 (GDScript).
Viewport: 240×320, window: 720×960, renderer: GL Compatibility, physics: Jolt.

## Godot Executable

Not on `PATH`. Full path on this machine:

```
C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe
```

### Headless commands

```powershell
# Smoke test (parse + autoload check, quits after ~1s)
& 'C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --quit-after 1

# Run a standalone test script
& 'C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . -s res://tests/<test_file>.gd
```

A shader-compiler warning like `Condition "!actions.custom_samplers.has(...)" is true` fires on every headless start. Ignore it unless the change touches shaders or rendering setup.

## Architecture

### Autoloads (defined in `project.godot`)

| Name             | Script                                  | Role                                                       |
|------------------|-----------------------------------------|------------------------------------------------------------|
| `Event`          | `Main/event.gd`                         | Signal bus — `marble_fell`, `dash_skill_activated`.         |
| `Shop`           | `Shop/shop.gd`                          | Gold, buy/sell, shop UI, collection rows, starting marbles.|
| `Inventory`      | `Inventory/inventory.gd`                | Owned items split into `marble_items` / `relic_items`.     |
| `EffectManager`  | `Effects/effect_manager.gd`             | Instantiates/dispatches relic effect scripts on combat events. |
| `EffectRegistry` | `Items/effect_registry.gd`             | Single source of truth: `effect_type → relic script` and `effect_type → MarbleSpec`. |
| `GameExecutor`   | `addons/hasturoperationgd/...`          | Remote-execution plugin (Hastur).                          |

Autoloads resolve before the main scene. In standalone `-s` test scripts, autoload singletons are **not** guaranteed to exist as global identifiers — resolve via `get_node_or_null("/root/Event")` etc. (see `Main/main.gd::_get_autoload_node` for the helper used throughout).

### Build system (content pipeline)

New content flows through one path: **`Shop → Slot → Inventory.add_item()`**. Never drop ad-hoc test marbles into `Main/main.tscn`; add them as `Item` resources purchasable from the shop.

`EffectRegistry` is the data-driven core. Adding new content means registering in its constants:

- **New marble type** → add entry to `Item.EffectType`, create a `MarbleSpec` `.tres` in `Resources/marble_specs/`, register it in `EffectRegistry.MARBLE_SPECS`.
- **New relic effect** → add entry to `Item.EffectType`, create a `RefCounted` script under `Effects/` with callback methods (e.g. `on_enemy_hit_by_marble`), register it in `EffectRegistry.RELIC_EFFECT_SCRIPTS`.

`main.gd` reads marble specs from the registry to build the chain. `EffectManager` reads relic scripts from the registry to dispatch combat events. Neither file should contain per-type `match`/`if` branches.

### Marble chain

The active marble is a **`MarbleChain`** (Node2D), not a set of independent `RigidBody2D` marbles:

```
MarbleChain (Node2D)
  ├── Head (Marble / RigidBody2D)  ← only physics body
  └── BodyContainer (Node2D)
        ├── Segment0 (ChainSegment)  ← visual only
        └── ...
```

- **Only the Head** is a `RigidBody2D`; Body segments are `ChainSegment` (pure `Node2D`).
- Body segments follow the Head via a **path-history trail**: Head records `(pos, rot)` into a ring buffer each `_physics_process`; segments lerp toward the trail point at their target distance.
- **Damage aggregation**: `Enemy → Head.get_hit_damage() → MarbleChain.get_total_damage()` sums Head base damage + each segment's contribution (BROWN echo bonus, BOMB contributes 0 contact damage — damage comes from explosion).
- **BROWN echo**: stacks on non-enemy collisions (walls, flippers); bonus damage on full stacks, then resets.
- **BOMB explosion**: triggers on enemy collision, AoE damage + knockback to Head.
- On marble fall (KillZone), the **entire chain is rebuilt**, not just the fallen marble.

### Groups (scene-level tags, defined in `project.godot` `[global_group]`)

- `marbles` — assigned to marble bodies (Head in chain mode).
- `enemies` — assigned in `Enemy._ready()`.

### Physics layers

1: world, 2: marble, 3: flipper, 4: enemy.

## Controls

- Left/Right arrow: flippers
- `U`: toggle shop (pauses game)
- `Q`: dash skill (consumes charge, aims at nearest enemy)
- Left-click shop slot: buy; right-click inventory slot in shop: sell (50% refund)

## Testing conventions

- Tests live under `/tests` (gitignored).
- For `SceneTree` tests, manually create/autoload required nodes under `get_root()` — do not rely on editor-only autoload state.
- Free test-created `Node`s / `Resource`s to avoid RID / `ObjectDB` leak warnings.
- Cast `Event.marble_fell`'s `RigidBody2D` body to `Marble` before reading `marble_type`; non-marble bodies should be ignored.

## Worktree / dirty-file hygiene

Before editing, run `git status --short` and distinguish pre-existing user changes from agent changes. `Marbles/bomb_marble.tscn`, `Main/util.gd`, and `Main/util.gd.uid` may already be dirty or untracked from user work — do not revert or fold them into unrelated fixes without explicit instruction.

