extends RefCounted
class_name DropHammerEffect

## 锻锤：与磨轮共用本发反弹计数，发射时把反弹次数兑成 token 追加伤害——
## 每 step 次反弹 +1，封顶 cap（LV1-3: (3,3)/(3,4)/(3,5)，觉醒 (2,5)）。
## 加成由 EchoFlipperChargeController 在发射时结算，经 arm_echo_damage 武装。

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/drop_hammer.tres")

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


## 按本发反弹计数计算每 token 追加伤害：min(bounce_count / step, cap)。
func get_bonus(bounce_count: int) -> int:
	return mini(bounce_count / _current_step(), _current_cap())


func _current_step() -> int:
	if _awakened:
		return int(_config.extra.get("awakened_step", 2))
	return int(_config.extra.get("step", 3))


func _current_cap() -> int:
	if _awakened:
		return int(_config.extra.get("awakened_cap", 5))
	return _config.get_value(_level)
