extends RefCounted
class_name ManyFacedPrismEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/many_faced_prism.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_damage_dealt(enemy: Node2D, packet: DamagePacket) -> void:
	if enemy == null or packet == null or not packet.is_crit or packet.crit_source != &"weak_point_base":
		return
	var host: Node = enemy.get_node_or_null("WeakPointHost")
	if host != null and host.has_method("try_spawn_prism"):
		var duration: float = -1.0 if _awakened else float(_config.get_value(_level))
		host.call("try_spawn_prism", packet.crit_direction, duration)
