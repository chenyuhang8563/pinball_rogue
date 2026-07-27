extends RefCounted
class_name AccelerantEffect

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/accelerant.tres")
const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_FIRE_BURN_TICK_SECONDS: String = "fire_burn_tick_seconds"
const TICK_SECONDS_MODIFIER_ID: String = "accelerant_fire_burn_tick_seconds"
const MODIFIER_SOURCE: String = "relic:accelerant"

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config
	_sync_tick_seconds_modifier()


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)
	_sync_tick_seconds_modifier()


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


## 弹珠命中后额外施加燃料。level_values 存放每级额外燃料数（默认 [1,1,2]）。
func on_enemy_hit_resolved(enemy: Node2D, _was_burning: bool, _was_frozen: bool, _packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("has_buff") or not enemy.has_method("add_buff"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	# 只有已燃烧的目标才额外加燃料（助燃剂加速已有火焰）
	if not bool(enemy.call("has_buff", FIRE_BURN_DEBUFF_ID)):
		return
	var extra_fuel: int = _config.get_value(_level)
	if _awakened:
		extra_fuel += int(_config.extra.get("awakened_bonus", 0))
	var burn: BuffDef = _make_buff(FIRE_BURN_DEBUFF_ID)
	if burn != null:
		enemy.call("add_buff", burn, extra_fuel)


## 遗物被移除或 EffectManager 重新配置时调用，清理 stat modifier。
func deactivate() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("remove_modifier"):
		stat_system.call("remove_modifier", STAT_ENTITY_MARBLE_CHAIN, TICK_SECONDS_MODIFIER_ID)


func _sync_tick_seconds_modifier() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, [STAT_FIRE_BURN_TICK_SECONDS])
	if stat_system.has_method("remove_modifier"):
		stat_system.call("remove_modifier", STAT_ENTITY_MARBLE_CHAIN, TICK_SECONDS_MODIFIER_ID)
	stat_system.call(
		"add_modifier",
		STAT_ENTITY_MARBLE_CHAIN,
		StatModifierScript.new(
			TICK_SECONDS_MODIFIER_ID,
			STAT_FIRE_BURN_TICK_SECONDS,
			StatModifier.ModOp.MULTIPLY,
			float(_config.extra.get("tick_seconds_multiplier", 1.0)),
			MODIFIER_SOURCE
		)
	)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
