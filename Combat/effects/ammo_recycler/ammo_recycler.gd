# 弹药回收器 —— 每次爆炸结算（PRIMARY 与 SECONDARY 都算）后按概率补 1 发。
#
# 概率 10/20/30%，觉醒 45%（extra.awakened_chance）。自带 RNG，
# seed_rng() 供测试固定随机序列。补弹不超当前 ceiling（AmmoState.add 保证）。

extends RefCounted
class_name AmmoRecyclerEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/ammo_recycler.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var _ammo_state: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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


func configure_runtime(ammo_state: Node) -> void:
	_ammo_state = ammo_state


func seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func dispose() -> void:
	_ammo_state = null


## 爆炸结算后掷概率：命中且未满则补 1 发。二次爆炸同样计入（每次爆炸后）。
func on_explosion_resolved(_context: ExplosionContext) -> void:
	if _ammo_state == null or not is_instance_valid(_ammo_state):
		return
	if _rng.randf() * 100.0 >= float(_chance()):
		return
	if _ammo_state.has_method("add"):
		_ammo_state.call("add", 1)


func _chance() -> int:
	if _awakened:
		return int(_config.extra.get("awakened_chance", 0))
	return _config.get_value(_level)
