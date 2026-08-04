# 高爆弹头 —— 每次炸弹爆炸结算后，按概率免费产出一颗小炸弹弹珠。
#
# 概率 Lv1 15% / Lv2 25% / Lv3 35%（level_values，觉醒不改概率）；场上同时最多
# max_spawned 颗（达到上限则跳过）；小炸弹伤害 50%（觉醒 100%），半径与正常
# 炸弹相同。免费产出，不消耗弹药。小炸弹 3s 后超时消失；碰敌造成范围伤害但不
# 消失，3s 内可多次碰撞、多次造成伤害。
#
# 独立结算：小炸弹不构造/分发 ExplosionContext、不触发 on_explosion*，仅复用
# 共享径向伤害工具 RadialDamage。PRIMARY 与 SECONDARY 爆炸都掷概率（与回收器
# 一致）。产出服务经 configure_spawner 注入（EffectManager 可选分发），缺失时
# 静默安全。

extends RefCounted
class_name HighExplosiveEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/high_explosive.tres")
const SMALL_BOMB_SCENE: PackedScene = preload("res://Combat/marbles/small_bomb_marble.tscn")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var _spawner: Node = null
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


func configure_runtime(_ammo_state: Node) -> void:
	pass


## 产出服务注入：独立可选方法，EffectManager 在 _sync_active_effects 中分发。
func configure_spawner(spawner: Node) -> void:
	_spawner = spawner


func seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func dispose() -> void:
	_spawner = null


## 爆炸结算后掷概率产出小炸弹。PRIMARY 与 SECONDARY 都算（与回收器一致）。
## 达场上上限由服务返回 null 跳过；无服务/无 spawn 方法时静默安全。
func on_explosion_resolved(context: ExplosionContext) -> void:
	if context == null or _spawner == null or not is_instance_valid(_spawner):
		return
	if not _spawner.has_method("spawn"):
		return
	if _rng.randf() * 100.0 >= float(_chance()):
		return
	var inst: Variant = _spawner.call(
		"spawn",
		SMALL_BOMB_SCENE,
		context.center,
		int(_config.extra.get("max_spawned", 3))
	)
	if inst is SmallBombMarble:
		var marble: SmallBombMarble = inst as SmallBombMarble
		marble.damage_ratio = 1.0 if _awakened else 0.5
		marble.lifetime = float(_config.extra.get("lifetime", 3.0))


## 产出概率：直接取 level_values（15/25/35）。觉醒不改概率（区别于回收器）。
func _chance() -> int:
	return _config.get_value(_level)
