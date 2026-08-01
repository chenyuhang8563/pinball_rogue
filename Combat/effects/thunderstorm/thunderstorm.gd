extends RefCounted
class_name ThunderstormEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/thunderstorm.tres")

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


func get_damage() -> int:
	return _config.get_value(_level)


func get_threshold() -> int:
	var values: Array = _config.extra.get("thresholds", [6, 5, 4])
	return int(values[clampi(_level - 1, 0, values.size() - 1)]) if not values.is_empty() else 6


func get_target_count() -> int:
	var values: Array = _config.extra.get("target_counts", [3, 4, 5])
	return int(values[clampi(_level - 1, 0, values.size() - 1)]) if not values.is_empty() else 3


func get_second_round_damage() -> int:
	return int(_config.extra.get("second_round_damage", 6))


func get_second_round_delay() -> float:
	return float(_config.extra.get("second_round_delay", 0.2))
