extends RefCounted
class_name IceHammerEffect

const FrostDebuffScript: GDScript = preload("res://Buffs/buffs/frost_debuff.gd")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Resources/relic_configs/ice_hammer.tres")

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


func on_enemy_hit_resolved(enemy: Node2D, _was_burning: bool, was_frozen: bool) -> void:
	if enemy == null or not was_frozen:
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if enemy.has_method("remove_buff"):
		enemy.call("remove_buff", "frozen_debuff")
	_shatter(enemy)


func _shatter(center_enemy: Node2D) -> void:
	var frost_stacks: int = int(_config.extra.get("awakened_frost_stacks", 3)) if _awakened else 1
	for candidate: Node in center_enemy.get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target: Node2D = candidate as Node2D
		if target.global_position.distance_to(center_enemy.global_position) > float(_config.extra.get("radius", 100.0)):
			continue
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("take_damage"):
			target.call("take_damage", _config.get_value(_level))
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("add_buff"):
			target.call("add_buff", FrostDebuffScript.new(), frost_stacks)
