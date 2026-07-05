# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Basics

- 使用中文回答。
- Project: **RoguePinball**, a Godot 4.6.1 GDScript pinball-roguelike prototype.
- Godot executable: `C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe`.
- `godot` is not on `PATH`.
- Viewport: 240x320. Window: 720x960. Renderer: GL Compatibility.

## Verification

- Use GUT as the test evidence. Do not treat startup/load checks or standalone scripts as proof that tests passed.
- Reliable local GUT invocation on this machine:

```powershell
cmd /c "C:\Users\16085\Desktop\Godot_v4.6.1-stable_win64.exe -d -s addons\gut\gut_cmdln.gd --path E:\Projects\pinball_rogue -gdir=res://tests -ginclude_subdirs -gexit -glog=1 -gconfig="
```

- After GUT passes, run the game in Godot when runtime validation is relevant.
- For screenshots, use Hastur/godot-screenshot against a connected `game` executor.
- `GameExecutor` exists only while the game process is running and connected.

## Autoloads

Autoloads are defined in `project.godot`. Important ones:

| Name | Role |
| --- | --- |
| `Event` | Signal bus. |
| `Shop` | Gold, buy/sell, shop UI, collection rows, starting marbles. |
| `Inventory` | Owned marble/relic items. |
| `EffectManager` | Dispatches relic effect scripts on combat events. |
| `EffectRegistry` | Maps item effects to relic scripts and marble specs. |
| `GameExecutor` | Hastur runtime executor. |
| `StatSystem` | Data-driven stats, modifiers, formulas, final-value queries. |
| `BuffManager` / `BuffRegistry` | Buff lifetime, definitions, and stat modifiers. |

Do not assume autoload names are compile-time globals. Resolve from `/root` with `get_node_or_null()` before use.

## Content Flow

- New content should enter through `Shop -> Slot -> Inventory.add_item()`.
- Do not place ad-hoc test marbles in `Main/main.tscn`.
- New marble type: add `Item.EffectType`, create/register a marble spec in `EffectRegistry`.
- New relic effect: add `Item.EffectType`, create a `RefCounted` effect script, register it in `EffectRegistry.RELIC_EFFECT_SCRIPTS`.
- Keep per-type branching out of `main.gd` and `EffectManager` when registry data can drive it.

## Stat System

- Final gameplay values flow through `StatSystem.get_stat(stat_id, entity_id, context)`.
- Static bases live in `Resources/stats/**/*.tres` as `StatDef` resources.
- Runtime changes are `StatModifier`s attached to entity ids such as `marble_chain`, `player`, or `enemy_<instance_id>`.
- When adding a stat, create the resource, register it in `Stats/stat_registry.gd`, and query through `StatSystem`.
- Avoid new hard-coded numeric getters in gameplay managers.

Integrated stat paths include damage, enemy health, buffs, shop prices, inventory capacity, marble speed/dash values, and table physics tuning.

## Marble Chain

- Active play uses one `MarbleChain`, not independent marble bodies.
- Only the head is a `RigidBody2D`; body segments are visual `ChainSegment` nodes.
- Body segments follow the head via path-history trail.
- On fall into KillZone, rebuild the whole chain.
- Cast `Event.marble_fell` bodies to `Marble` before reading `marble_type`; ignore non-marble bodies safely.

## Worktree Hygiene

- Before editing, run `git status --short` and distinguish pre-existing user changes from agent changes.
- Do not revert user changes unless explicitly requested.
- `Marbles/bomb_marble.tscn`, `Main/util.gd`, and `Main/util.gd.uid` may be dirty or untracked from user work; do not fold them into unrelated fixes.
