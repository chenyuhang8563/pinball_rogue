extends RefCounted
class_name FireBellowsEffect

const MAX_LEVEL: int = 3
const HIT_THRESHOLDS: Array[int] = [4, 3, 2]

var _level: int = 1
var _awakened: bool = false


func set_level(level: int) -> void:
	_level = clampi(level, 1, MAX_LEVEL)


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
	enemy.call("trigger_fire_relic_hit", HIT_THRESHOLDS[_level - 1], _awakened)
