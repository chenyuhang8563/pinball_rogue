# 弹药袋 —— 静态 modifier 提升 max_ammo（写 "player" 实体）。
#
# 等级 1..3 各 +1/+2/+3 上限；觉醒不再加 max，改为战斗开始弹药 = max + 2
# （临时超上限，首次发射回落后恢复到 max，回收器补弹不超 ceiling）。
#
# ammo_state 经 configure_runtime 注入（EffectManager 在等级/觉醒确定后统一分发）；
# 静态 modifier 写 StatSystem，不依赖 ammo_state，因此随时可同步。

extends RefCounted
class_name AmmoPouchEffect

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/ammo_pouch.tres")
const ENTITY_ID: String = "player"
const STAT_ID: String = "max_ammo"
const MODIFIER_ID: String = "relic_upgrade:ammo_pouch"

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var _ammo_state: Node = null


func set_config(config: RelicLevelConfig) -> void:
	_config = config
	_sync_modifier()


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)
	_sync_modifier()


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened
	_sync_modifier()


func is_awakened() -> bool:
	return _awakened


## 弹药系统注入：持有 ammo_state，刷新 ceiling 并同步觉醒战斗开始加成。
func configure_runtime(ammo_state: Node) -> void:
	_ammo_state = ammo_state
	if _ammo_state == null or not is_instance_valid(_ammo_state):
		return
	if _ammo_state.has_method("refresh_capacity"):
		_ammo_state.call("refresh_capacity")
	if _ammo_state.has_method("set_battle_start_bonus"):
		_ammo_state.call("set_battle_start_bonus", 2 if _awakened else 0)


func dispose() -> void:
	_remove_modifier()
	if _ammo_state != null and is_instance_valid(_ammo_state) \
			and _ammo_state.has_method("set_battle_start_bonus"):
		_ammo_state.call("set_battle_start_bonus", 0)


func _bonus() -> int:
	return _config.get_value(_level)


func _sync_modifier() -> void:
	var stats := _get_stat_system()
	if stats == null:
		return
	_remove_modifier()
	if stats.has_method("register_entity"):
		stats.call("register_entity", ENTITY_ID, [STAT_ID])
	if stats.has_method("add_modifier"):
		stats.call("add_modifier", ENTITY_ID, StatModifierScript.new(
			MODIFIER_ID, STAT_ID, StatModifier.ModOp.ADD, float(_bonus()), MODIFIER_ID
		))


func _remove_modifier() -> void:
	var stats := _get_stat_system()
	if stats != null and stats.has_method("remove_modifier"):
		stats.call("remove_modifier", ENTITY_ID, MODIFIER_ID)


func _get_stat_system() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
