# 背水一击 —— 弹药恰为 1（扣弹前快照）时，爆炸伤害倍率放大。
#
# 倍率 1.5/2/2.5 存于 extra.multipliers（float，不适合 level_values）；
# 觉醒额外把爆炸半径 ×1.5。必须扣弹前判定（ammo_before 快照），
# 弹药 2+ 时完全不生效。

extends RefCounted
class_name LastShotEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/last_shot.tres")

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


func configure_runtime(_ammo_state: Node) -> void:
	pass


func dispose() -> void:
	pass


func modify_explosion(context: ExplosionContext) -> void:
	if context == null:
		return
	if context.ammo_before != 1:
		return
	context.multiply_damage(_multiplier())
	if _awakened:
		context.multiply_radius(float(_config.extra.get("awakened_radius_multiplier", 1.5)))


func _multiplier() -> float:
	var multipliers: Array = _config.extra.get("multipliers", [1.5, 2.0, 2.5]) as Array
	if multipliers.is_empty():
		return 1.5
	return float(multipliers[clampi(_level - 1, 0, multipliers.size() - 1)])
