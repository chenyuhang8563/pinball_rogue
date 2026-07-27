extends RefCounted
class_name PustuleEffect

## Relic 脓爆 (pustule): an infected host bursts open on death, releasing extra
## plague flies beyond the single base fly. Higher levels make the extra flies
## last longer (smaller duration penalty); awakening releases two extra flies at
## full duration.
##
## Queried by the plague spawner (EffectManager) when an infected enemy dies.

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/pustule.tres")

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


## Number of extra flies released on an infected death (on top of the base fly).
func get_extra_fly_count() -> int:
	if _awakened:
		return int(_config.extra.get("awakened_count", 2))
	return int(_config.extra.get("base_count", 1))


## Seconds shaved off each extra fly's lifetime, by level (awakened: no penalty).
func get_extra_fly_duration_penalty() -> float:
	if _awakened:
		return 0.0
	return float(_config.get_value(_level))
