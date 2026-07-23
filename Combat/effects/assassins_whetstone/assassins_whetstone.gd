extends RefCounted
class_name AssassinsWhetstoneEffect

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/assassins_whetstone.tres")

const ENTITY_ID: String = "marble_chain"
const SOURCE: String = "relic:assassins_whetstone"

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)
	_sync_modifiers()


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened
	_sync_modifiers()


func is_awakened() -> bool:
	return _awakened


func dispose() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("remove_modifiers_by_source"):
		stat_system.call("remove_modifiers_by_source", ENTITY_ID, SOURCE)


func _sync_modifiers() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return
	stat_system.call("remove_modifiers_by_source", ENTITY_ID, SOURCE)
	stat_system.call("add_modifier", ENTITY_ID, StatModifierScript.new(
		"%s:tolerance" % SOURCE, "weak_point_tolerance_deg",
		StatModifier.ModOp.OVERRIDE, float(_config.get_value(_level)), SOURCE
	))
	if _awakened:
		stat_system.call("add_modifier", ENTITY_ID, StatModifierScript.new(
			"%s:perfect" % SOURCE, "perfect_crit_enabled",
			StatModifier.ModOp.OVERRIDE, 1.0, SOURCE
		))


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
