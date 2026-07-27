extends RefCounted
class_name FireBellowsEffect

const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/fire_bellows.tres")
const SparkProjectileScene: PackedScene = preload("res://Combat/effects/fire_bellows/spark_projectile.tscn")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_enemy_hit_resolved(enemy: Node2D, was_burning: bool, _was_frozen: bool, _packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("has_buff"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	# 只在命中前已燃烧时触发，避免火弹珠首次点燃就触发风箱
	if not was_burning:
		return

	var target: Node2D = _find_spark_target(enemy)
	if target == null:
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return
	for _index: int in range(_get_spark_count()):
		var spark: SparkProjectile = SparkProjectileScene.instantiate() as SparkProjectile
		if spark == null:
			continue
		spark.call_deferred("spawn_from", scene, enemy.global_position, target)


func _get_spark_count() -> int:
	var spark_count: int = maxi(0, _config.get_value(_level))
	if _awakened:
		spark_count += int(_config.extra.get("awakened_bonus", 1))
	return spark_count


func _find_spark_target(source: Node2D) -> Node2D:
	var tree: SceneTree = source.get_tree()
	if tree == null:
		return null
	var radius: float = float(_config.extra.get("search_radius", 150.0))
	var best_target: Node2D = null
	var best_is_burning: bool = true
	var best_fuel: int = 0
	var best_distance: float = INF

	for candidate: Node in tree.get_nodes_in_group("enemies"):
		if candidate == source or not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target: Node2D = candidate as Node2D
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		var distance: float = source.global_position.distance_to(target.global_position)
		if distance > radius:
			continue
		var is_burning: bool = target.has_method("has_buff") and bool(target.call("has_buff", FIRE_BURN_DEBUFF_ID))
		var fuel: int = int(target.call("get_buff_stacks", FIRE_BURN_DEBUFF_ID)) if target.has_method("get_buff_stacks") else 0
		if _is_better_target(is_burning, fuel, distance, best_is_burning, best_fuel, best_distance):
			best_target = target
			best_is_burning = is_burning
			best_fuel = fuel
			best_distance = distance

	return best_target


func _is_better_target(is_burning: bool, fuel: int, distance: float, best_is_burning: bool, best_fuel: int, best_distance: float) -> bool:
	if best_distance == INF:
		return true
	if is_burning != best_is_burning:
		return not is_burning
	if fuel != best_fuel:
		return fuel < best_fuel
	return distance < best_distance
