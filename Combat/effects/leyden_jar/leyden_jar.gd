extends RefCounted
class_name LeydenJarEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/leyden_jar.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config if config != null else DEFAULT_CONFIG


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func get_arc_cap() -> int:
	return _config.get_value(_level)


func get_breakthrough_multiplier() -> float:
	return float(_config.extra.get("breakthrough_multiplier", 1.5))
