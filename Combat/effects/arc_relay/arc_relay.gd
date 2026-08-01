extends RefCounted
class_name ArcRelayEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/arc_relay.tres")

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


func get_range() -> float:
	var ranges: Array = _config.extra.get("ranges", [140.0, 160.0, 180.0])
	return float(ranges[clampi(_level - 1, 0, ranges.size() - 1)]) if not ranges.is_empty() else 140.0


func get_transfer_limit() -> int:
	var limits: Array = _config.extra.get("transfer_limits", [1, 2, -1])
	return int(limits[clampi(_level - 1, 0, limits.size() - 1)]) if not limits.is_empty() else 1


func get_target_count() -> int:
	return 2 if _awakened else 1
