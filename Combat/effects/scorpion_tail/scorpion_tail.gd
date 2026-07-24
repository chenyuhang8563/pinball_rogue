extends RefCounted
class_name ScorpionTailEffect

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/scorpion_tail.tres")
const ENTITY_ID: String = "marble_chain"
const STAT_ID: String = "poison_damage_per_layer"
const MODIFIER_ID: String = "relic_upgrade:scorpion_tail"

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


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


func dispose() -> void:
	_remove_modifier()


func _bonus() -> int:
	return _config.get_value(_level) + (int(_config.extra.get("awakened_bonus", 0)) if _awakened else 0)


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
