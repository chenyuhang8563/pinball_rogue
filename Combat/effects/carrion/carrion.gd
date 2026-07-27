extends RefCounted
class_name CarrionEffect

## Relic 腐肉 (carrion): carrion sustains the plague flies. Each level extends how
## long released flies linger; awakening makes their bites hurt.
##
## Queried by the plague spawner (EffectManager) when a fly is released.

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/carrion.tres")

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


## Extra seconds added to a released fly's base lifetime, by level.
func get_fly_duration_bonus() -> float:
	return float(_config.get_value(_level))


## Extra bite damage while awakened.
func get_fly_damage_bonus() -> int:
	if not _awakened:
		return 0
	return int(_config.extra.get("awakened_damage_bonus", 1))
