extends Node

## Core plague spawn constants. Flies are the green-marble payoff (not a relic), so
## they always release on an infected death; relics (carrion/pustule) layer on top.
const FLY_SCENE_PATH: String = "res://Combat/effects/plague_fly/plague_fly.tscn"
const BASE_FLY_LIFETIME: float = 5.0
const BASE_FLY_DAMAGE: int = 1
## Radial scatter for extra pustule flies so they don't stack on one pixel.
const EXTRA_FLY_SCATTER_RADIUS: float = 12.0

var _active_effects: Dictionary = {}
var _loadout: RefCounted = null
var _progression: RefCounted = null


func configure(loadout: RefCounted, progression: RefCounted) -> bool:
	if not _has_port_api(loadout, [&"relics"]) \
			or not _has_port_api(progression, [&"level_of"]):
		return false
	_disconnect_port_signals()
	_loadout = loadout
	_progression = progression
	_connect_port_signals()
	_sync_active_effects()
	return true


func _ready() -> void:
	_connect_port_signals()
	_sync_active_effects()


func _exit_tree() -> void:
	_disconnect_port_signals()


func on_enemy_hit_by_marble(enemy: Node2D, packet: DamagePacket = null) -> void:
	_dispatch("on_enemy_hit_by_marble", [enemy, packet])


func on_enemy_hit_resolved(enemy: Node2D, was_burning: bool, was_frozen: bool, packet: DamagePacket = null) -> void:
	_dispatch("on_enemy_hit_resolved", [enemy, was_burning, was_frozen, packet])


func on_poison_tick(enemy: Node2D, stacks: int = 1) -> void:
	_dispatch("on_poison_tick", [enemy, stacks])


func on_damage_dealt(enemy: Node2D, packet: DamagePacket) -> void:
	_dispatch("on_damage_dealt", [enemy, packet])


func modify_damage_packet(enemy: Node2D, packet: DamagePacket) -> void:
	_dispatch("modify_damage_packet", [enemy, packet])


func on_enemy_defeated(enemy: Node2D, packet: DamagePacket) -> void:
	_dispatch("on_enemy_defeated", [enemy, packet])
	_spawn_plague_flies(enemy)


## Friendly plague flies broadcast each bite so the parasite relic can layer poison.
func on_fly_bite(enemy: Node2D, packet: DamagePacket = null) -> void:
	_dispatch("on_fly_bite", [enemy, packet])


func on_status_applied(enemy: Node2D, status_id: StringName, stacks: int, packet: DamagePacket = null) -> void:
	_dispatch("on_status_applied", [enemy, status_id, stacks, packet])


func on_burn_tick(enemy: Node2D, stacks: int) -> void:
	_dispatch("on_burn_tick", [enemy, stacks])


## 冻结敌人与弹珠、世界或另一敌人碰撞时由 Enemy 分发。快照语义：
## velocity 为碰撞前速度；kind ∈ {&"marble", &"enemy", &"world"}；hit_body 仅
## kind==&"enemy" 时有效。全部为分发时刻的不可变快照。
func on_frozen_body_impact(
	enemy: Node2D, hit_body: Node2D, velocity: Vector2, kind: StringName
) -> void:
	_dispatch("on_frozen_body_impact", [enemy, hit_body, velocity, kind])


## 本发边界事件：Head 落入 KillZone、本发结束时由 Main 分发（每发一次）。
## 有存活投射物的 Effect 可在本发结束时自行清理。无参数：清理范围由各 Effect 自持。
func on_ball_lost() -> void:
	_dispatch("on_ball_lost", [])


func on_explosion(center: Vector2, radius: float) -> void:
	_dispatch("on_explosion", [center, radius])


func on_skill_hit(enemy: Node2D, skill_id: StringName, packet: DamagePacket) -> void:
	_dispatch("on_skill_hit", [enemy, skill_id, packet])


func on_chain_hit(target: Node2D, bounce_index: int, packet: DamagePacket) -> void:
	_dispatch("on_chain_hit", [target, bounce_index, packet])


func on_surface_bounce(surface_type: StringName, shot_ctx: Dictionary) -> void:
	_dispatch("on_surface_bounce", [surface_type, shot_ctx])


func _sync_active_effects() -> void:
	var registry: Node = _get_relic_registry()
	var owned_effect_levels := _get_owned_effect_levels(registry)
	var owned_effects: Array = owned_effect_levels.keys()

	for effect_id in owned_effects:
		if not _active_effects.has(effect_id):
			var script: GDScript = null
			if registry != null and registry.has_method("get_relic_script"):
				script = registry.call("get_relic_script", effect_id) as GDScript
			if script == null:
				continue
			_active_effects[effect_id] = script.new()
		var effect: Variant = _active_effects[effect_id]
		if effect != null and effect.has_method("set_level"):
			var effect_state: Dictionary = owned_effect_levels[effect_id]
			effect.call("set_level", int(effect_state.get("level", 1)))
			if effect.has_method("set_awakened"):
				effect.call("set_awakened", bool(effect_state.get("awakened", false)))

	for effect_type in _active_effects.keys():
		if not owned_effects.has(effect_type):
			var removed: Variant = _active_effects[effect_type]
			if removed != null and removed.has_method("deactivate"):
				removed.call("deactivate")
			if removed != null and removed.has_method("dispose"):
				removed.call("dispose")
			_active_effects.erase(effect_type)


func _get_owned_effect_levels(registry: Node) -> Dictionary:
	var owned_effects: Dictionary = {}
	if _loadout == null or not is_instance_valid(_loadout) \
			or _progression == null or not is_instance_valid(_progression):
		return owned_effects

	for item: Item in _loadout.call("relics") as Array:
		if item == null:
			continue
		if item.id.is_empty():
			continue
		if registry == null or not registry.has_method("has_relic_script") \
			or not bool(registry.call("has_relic_script", StringName(item.id))):
			continue
		var level: int = maxi(1, int(_progression.call("level_of", item)))
		var awakened: bool = level >= 4
		var effect_key: StringName = StringName(item.id)
		var previous: Dictionary = owned_effects.get(effect_key, {"level": 0, "awakened": false})
		owned_effects[effect_key] = {
			"level": maxi(int(previous.get("level", 0)), level),
			"awakened": bool(previous.get("awakened", false)) or awakened,
		}
	return owned_effects


func _dispatch(method_name: StringName, args: Array) -> void:
	for effect in _active_effects.values():
		if effect.has_method(method_name):
			effect.callv(method_name, args)


## Core plague payoff: an infected enemy releases one base fly on death, plus extra
## flies if the pustule relic is owned. Fly lifetime/damage fold in the carrion
## relic. Runs even with zero relics (flies are the green-marble identity).
func _spawn_plague_flies(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("has_buff") or not bool(enemy.call("has_buff", InfectionDebuff.INFECTION_ID)):
		return
	if not ResourceLoader.exists(FLY_SCENE_PATH):
		return
	var scene: PackedScene = load(FLY_SCENE_PATH) as PackedScene
	if scene == null:
		return
	var parent: Node = enemy.get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var origin: Vector2 = enemy.global_position
	var base_duration: float = BASE_FLY_LIFETIME + _fly_duration_bonus()
	var fly_damage: int = BASE_FLY_DAMAGE + _fly_damage_bonus()
	_spawn_one_fly(scene, parent, origin, base_duration, fly_damage)
	var pustule: Variant = _get_active_effect(&"pustule")
	if pustule == null:
		return
	var extra_count: int = maxi(0, int(pustule.call("get_extra_fly_count")))
	var extra_duration: float = maxf(1.0, base_duration - float(pustule.call("get_extra_fly_duration_penalty")))
	for index: int in range(extra_count):
		var offset: Vector2 = Vector2.RIGHT.rotated(float(index) * TAU / float(maxi(1, extra_count))) * EXTRA_FLY_SCATTER_RADIUS
		_spawn_one_fly(scene, parent, origin + offset, extra_duration, fly_damage)


func _spawn_one_fly(scene: PackedScene, parent: Node, pos: Vector2, duration: float, damage: int) -> void:
	var instance: Node = scene.instantiate()
	if instance == null:
		return
	if not instance is PlagueFly:
		instance.free()
		return
	var fly: PlagueFly = instance as PlagueFly
	parent.add_child(fly)
	fly.global_position = pos
	fly.lifetime = duration
	fly.bite_damage = damage


func _fly_duration_bonus() -> float:
	var carrion: Variant = _get_active_effect(&"carrion")
	if carrion != null and carrion.has_method("get_fly_duration_bonus"):
		return float(carrion.call("get_fly_duration_bonus"))
	return 0.0


func _fly_damage_bonus() -> int:
	var carrion: Variant = _get_active_effect(&"carrion")
	if carrion != null and carrion.has_method("get_fly_damage_bonus"):
		return int(carrion.call("get_fly_damage_bonus"))
	return 0


func _get_active_effect(item_id: StringName) -> Variant:
	return _active_effects.get(item_id, null)


func _connect_port_signals() -> void:
	var loadout_callback := Callable(self, "_sync_active_effects")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and not _loadout.is_connected(&"changed", loadout_callback):
		_loadout.connect(&"changed", loadout_callback)
	var progression_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and not _progression.is_connected(&"item_progressed", progression_callback):
		_progression.connect(&"item_progressed", progression_callback)


func _disconnect_port_signals() -> void:
	var loadout_callback := Callable(self, "_sync_active_effects")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and _loadout.is_connected(&"changed", loadout_callback):
		_loadout.disconnect(&"changed", loadout_callback)
	var progression_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and _progression.is_connected(&"item_progressed", progression_callback):
		_progression.disconnect(&"item_progressed", progression_callback)


func _on_item_progressed(_item: Item, _level: int, _awakened: bool) -> void:
	_sync_active_effects()


func _get_relic_registry() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EffectRegistry")


func _has_port_api(port: RefCounted, methods: Array[StringName]) -> bool:
	if port == null or not is_instance_valid(port):
		return false
	for method: StringName in methods:
		if not port.has_method(method):
			return false
	return true
