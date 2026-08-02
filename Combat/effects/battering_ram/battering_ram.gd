extends RefCounted
class_name BatteringRamEffect

## 破城锥：强力击（发射消费蓄力）触发穿透——弹珠获得数秒穿透，穿过敌人造成
## 穿透伤害（命中照常消费回响 token，即享受强力击加成）。
## 时长 LV1-3：3 / 3.5 / 4 秒，觉醒 5 秒；觉醒额外使穿透伤害 ×1.5。
## 穿透态由 EchoFlipperChargeController 在发射时经 MarbleChain.enter_pierce_state 启用。

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/battering_ram.tres")

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


## 穿透持续时间（秒）：LV1-3 由 level_values 以十分之一秒存储（30/35/40），觉醒 5。
func get_pierce_duration() -> float:
	if _awakened:
		return float(_config.extra.get("awakened_duration_seconds", 5.0))
	return float(_config.get_value(_level)) / 10.0


## 穿透伤害倍率：基础 1.0，觉醒 1.5（穿透命中总伤害 × 倍率）。
func get_pierce_damage_multiplier() -> float:
	if _awakened:
		return float(_config.extra.get("awakened_damage_multiplier", 1.5))
	return 1.0
