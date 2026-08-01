extends RefCounted
class_name LightningEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/lightning.tres")

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


func get_branch_damage() -> int:
	return _config.get_value(_level)


func get_branch_count() -> int:
	var counts: Array = _config.extra.get("branch_counts", [1, 2, 3])
	return int(counts[clampi(_level - 1, 0, counts.size() - 1)]) if not counts.is_empty() else 1


func get_branch_range() -> float:
	var ranges: Array = _config.extra.get("ranges", [120.0, 140.0, 160.0])
	return float(ranges[clampi(_level - 1, 0, ranges.size() - 1)]) if not ranges.is_empty() else 120.0


func get_arc_stacks() -> int:
	return int(_config.extra.get("awakened_arc_stacks", 2)) if _awakened else 1
