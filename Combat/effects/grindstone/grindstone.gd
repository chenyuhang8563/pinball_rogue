extends RefCounted
class_name GrindstoneEffect

## 磨轮：墙面/台面反弹为共享蓄力充能（+0.05/反弹，每发累计上限 0.5 层）；
## 挡板弹起不充能。觉醒 +0.10/反弹。每发壁充能由 EchoFlipperChargeController 封顶。

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/grindstone.tres")

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


## 每次墙面/台面反弹累计的蓄力（LV1-3: 0.05/0.06/0.07，觉醒 0.10）。
func get_charge_per_bounce() -> float:
	if _awakened:
		return float(_config.extra.get("awakened_charge_per_bounce", 0.10))
	return float(_config.get_value(_level)) / 100.0


## 每发反弹充能累计上限（0.5 层，防纯弹射永动）。
func get_wall_charge_cap() -> float:
	return float(_config.extra.get("wall_charge_cap", 0.5))
