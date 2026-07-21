extends RefCounted
class_name LightningEffect

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const LightningEffectScene := preload("res://Combat/effects/lightning_effect/lightning_effect.tscn")

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/lightning.tres")
const STAT_LIGHTNING_CHAIN_DAMAGE: String = "lightning_chain_damage"
const STAT_ENTITY_LIGHTNING_CHAIN: String = "relic:lightning_chain"
const MODIFIER_SOURCE: String = "relic_upgrade:lightning_chain"
const OP_OVERRIDE: int = 2

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)
	_sync_damage_modifier()


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_enemy_hit_by_marble(enemy: Node2D) -> void:
	if enemy == null:
		return

	var hit_count: int = int(_config.extra.get("awakened_hits", 3)) if _awakened else 1
	var previous: Node2D = enemy
	var visited: Array[Node2D] = [enemy]
	for _hit_index: int in range(hit_count):
		var target := _find_nearest_enemy(previous, visited)
		if target == null:
			target = _find_nearest_enemy(previous, [previous])
		if target == null:
			target = _find_nearest_enemy(previous, [])
		if target == null:
			return
		if target.has_method("take_damage"):
			target.take_damage(_get_damage())
		_spawn_lightning_effect(previous.global_position, target.global_position)
		previous = target
		visited.append(target)


func _find_nearest_enemy(origin: Node2D, excluded: Array[Node2D] = []) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in origin.get_tree().get_nodes_in_group("enemies"):
		if enemy == origin:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy is not Node2D:
			continue

		var enemy_node := enemy as Node2D
		if excluded.has(enemy_node):
			continue
		var distance := origin.global_position.distance_to(enemy_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy


func _get_damage() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return int(stat_system.call("get_stat", STAT_LIGHTNING_CHAIN_DAMAGE, STAT_ENTITY_LIGHTNING_CHAIN))
	return _config.get_value(_level)


func _sync_damage_modifier() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", STAT_ENTITY_LIGHTNING_CHAIN, [STAT_LIGHTNING_CHAIN_DAMAGE])
	stat_system.call(
		"add_modifier",
		STAT_ENTITY_LIGHTNING_CHAIN,
		StatModifierScript.new(
			MODIFIER_SOURCE,
			STAT_LIGHTNING_CHAIN_DAMAGE,
			OP_OVERRIDE,
			float(_config.get_value(_level)),
			MODIFIER_SOURCE
		)
	)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")


func _spawn_lightning_effect(from_position: Vector2, to_position: Vector2) -> void:
	var direction := to_position - from_position
	if direction == Vector2.ZERO:
		return

	var scene = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect := LightningEffectScene.instantiate()
	scene.add_child(effect)
	effect.global_position = (from_position + to_position) * 0.5
	effect.rotation = direction.angle()
