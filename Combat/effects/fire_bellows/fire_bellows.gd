extends RefCounted
class_name FireBellowsEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/fire_bellows.tres")

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


func on_enemy_hit_resolved(enemy: Node2D, was_burning: bool, _was_frozen: bool) -> void:
	if enemy == null or not was_burning or not enemy.has_method("trigger_fire_relic_hit"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	enemy.call("trigger_fire_relic_hit", _config.get_value(_level), _awakened)
