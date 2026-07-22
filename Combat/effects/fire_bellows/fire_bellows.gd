extends RefCounted
class_name FireBellowsEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/fire_bellows.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var _hit_counts: Dictionary = {}


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


func on_enemy_hit_resolved(enemy: Node2D, _was_burning: bool, _was_frozen: bool, packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("has_buff") or not enemy.has_method("add_buff"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if not bool(enemy.call("has_buff", FireBurnDebuff.BURN_ID)):
		return
	_prune_hit_counts()
	var enemy_id: int = enemy.get_instance_id()
	var hit_count: int = int(_hit_counts.get(enemy_id, {"enemy": weakref(enemy), "count": 0}).get("count", 0)) + 1
	if hit_count < maxi(1, _config.get_value(_level)):
		_hit_counts[enemy_id] = {"enemy": weakref(enemy), "count": hit_count}
		return
	_hit_counts.erase(enemy_id)
	enemy.call("add_buff", FireBurnDebuff.new(), 1, packet)


func _prune_hit_counts() -> void:
	for enemy_id: int in _hit_counts.keys():
		var entry: Dictionary = _hit_counts[enemy_id]
		var enemy_ref: WeakRef = entry.get("enemy") as WeakRef
		if enemy_ref == null or enemy_ref.get_ref() == null:
			_hit_counts.erase(enemy_id)
