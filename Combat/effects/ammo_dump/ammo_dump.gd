# 弹药倾泻 —— 永续被动：每次主爆炸按「当前弹药存量」附加额外伤害。
#
# 额外伤害 = ammo_before × 系数（Lv1/2/3 = 1.0/1.5/2.0），系数存于
# extra.multipliers（float，不适合 level_values）；觉醒额外把爆炸半径 ×1.5。
# 与弹药存量正相关，天然自洽：弹药越多伤害越高，且不消耗额外弹药、
# 不清空弹药（ammo_cost 保持 1）。ammo_before 为扣弹前的快照。

extends RefCounted
class_name AmmoDumpEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/ammo_dump.tres")

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
	context.add_flat_damage(roundi(float(context.ammo_before) * _multiplier()))
	if _awakened:
		context.multiply_radius(float(_config.extra.get("awakened_radius_multiplier", 1.5)))


func _multiplier() -> float:
	var multipliers: Array = _config.extra.get("multipliers", [1.0, 1.5, 2.0]) as Array
	if multipliers.is_empty():
		return 1.0
	return float(multipliers[clampi(_level - 1, 0, multipliers.size() - 1)])
