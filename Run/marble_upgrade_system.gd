extends Node
class_name MarbleUpgradeSystem

signal marble_upgraded(marble_type: Marble.MARBLE_TYPE, level: int)

const StatModifierScript: GDScript = preload("res://Stats/stat_modifier.gd")

const MAX_LEVEL: int = 3
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const MODIFIER_SOURCE: String = "marble_upgrade"
const OP_OVERRIDE: int = 2

const STAT_DARK_MARBLE_DAMAGE: String = "dark_marble_damage"
const STAT_BLUE_FROST_DURATION: String = "blue_frost_duration"
const STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED: String = "blue_frost_bonus_damage_enabled"
const STAT_BLUE_FROST_STACKS_PER_HIT: String = "blue_frost_stacks_per_hit"
const STAT_POISON_DAMAGE_PER_TICK: String = "poison_damage_per_tick"
const STAT_POISON_TICK_SECONDS: String = "poison_tick_seconds"
const STAT_ECHO_TIMEOUT: String = "echo_timeout"
const STAT_EXPLOSION_EFFECT_SCALE: String = "explosion_effect_scale"
const STAT_EXPLOSION_DAMAGE: String = "explosion_damage"
const STAT_EXPLOSION_RADIUS: String = "explosion_radius"
const STAT_ECHO_BONUS_DAMAGE: String = "echo_bonus_damage"

const UPGRADE_VALUES: Dictionary = {
	Marble.MARBLE_TYPE.DEFAULT: {
		"title": "Dark Marble",
		"stat": STAT_DARK_MARBLE_DAMAGE,
		"values": [1.0, 2.0, 3.0],
		"awakened_value": 4.0,
		"descriptions": [
			"Damage 2",
			"Damage 3",
			"Awaken: Damage 4",
		],
	},
	Marble.MARBLE_TYPE.BOMB: {
		"title": "Bomb Marble",
		"stat": STAT_EXPLOSION_DAMAGE,
		"values": [5.0, 8.0, 8.0],
		"descriptions": [
			"Explosion damage 5",
			"Explosion damage 8",
			"Awaken: radius 100, effect x4",
		],
	},
	Marble.MARBLE_TYPE.GREEN: {
		"title": "Green Marble",
		"stat": STAT_POISON_DAMAGE_PER_TICK,
		"values": [2.0, 4.0, 4.0],
		"descriptions": [
			"Poison 2 per tick",
			"Poison 4 per tick",
			"Awaken: Poison 4 every 0.5s",
		],
	},
	Marble.MARBLE_TYPE.BROWN: {
		"title": "Brown Marble",
		"stat": STAT_ECHO_BONUS_DAMAGE,
		"values": [2.0, 4.0, 8.0],
		"descriptions": [
			"Echo damage 2",
			"Echo damage 4",
			"Awaken: Echo 8, 15s, spend 1 stack",
		],
	},
	Marble.MARBLE_TYPE.BLUE: {
		"title": "Blue Marble",
		"stat": STAT_BLUE_FROST_DURATION,
		"values": [4.0, 4.0, 4.0],
		"descriptions": [
			"Frost duration +2s",
			"Bonus damage equals frost stacks",
			"Awaken: +1 frost stack on Blue hit",
		],
	},
}

var _levels: Dictionary = {}
var _awakened_types: Dictionary = {}


func reset_upgrades() -> void:
	_levels.clear()
	_awakened_types.clear()
	_clear_upgrade_modifiers()


func get_level(marble_type: Marble.MARBLE_TYPE) -> int:
	if not UPGRADE_VALUES.has(marble_type):
		return 0
	return clampi(int(_levels.get(int(marble_type), 1)), 1, MAX_LEVEL)


func is_awakened(marble_type: Marble.MARBLE_TYPE) -> bool:
	return bool(_awakened_types.get(int(marble_type), false))


func is_max_level(marble_type: Marble.MARBLE_TYPE) -> bool:
	return is_awakened(marble_type)


func upgrade_marble(marble_type: Marble.MARBLE_TYPE) -> bool:
	if not UPGRADE_VALUES.has(marble_type):
		return false
	if is_awakened(marble_type):
		return false
	var current_level: int = get_level(marble_type)
	var next_level: int = mini(current_level + 1, MAX_LEVEL)
	if current_level >= MAX_LEVEL:
		_awakened_types[int(marble_type)] = true
	else:
		_levels[int(marble_type)] = next_level
	_sync_stat_modifiers()
	marble_upgraded.emit(marble_type, next_level)
	return true


func get_upgrade_options(inventory: Node, max_options: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if inventory == null:
		return result

	var raw_marble_items: Variant = inventory.get("marble_items")
	if not raw_marble_items is Array:
		return result

	var seen_types: Array[int] = []
	var marble_items: Array = raw_marble_items
	for item: Item in marble_items:
		if item == null or item.type != Item.ItemType.MARBLE:
			continue
		var marble_type: Marble.MARBLE_TYPE = item.marble_type
		if seen_types.has(int(marble_type)):
			continue
		seen_types.append(int(marble_type))
		if not UPGRADE_VALUES.has(marble_type):
			continue
		if is_max_level(marble_type):
			continue
		result.append(_make_option(item, marble_type))
		if result.size() >= max_options:
			break
	return result


func _make_option(item: Item, marble_type: Marble.MARBLE_TYPE) -> Dictionary:
	var current_level: int = get_level(marble_type)
	var awakens: bool = current_level >= MAX_LEVEL
	var next_level: int = MAX_LEVEL if awakens else current_level + 1
	var data: Dictionary = UPGRADE_VALUES[marble_type]
	var descriptions: Array = data.get("descriptions", [])
	var description: String = ""
	var description_index: int = current_level - 1
	if description_index >= 0 and description_index < descriptions.size():
		description = String(descriptions[description_index])
	return {
		"marble_type": marble_type,
		"title": item.title if item.title != "" else String(data.get("title", "")),
		"icon": item.icon,
		"current_level": current_level,
		"next_level": next_level,
		"awakens": awakens,
		"description": description,
	}


func _sync_stat_modifiers() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return

	_clear_upgrade_modifiers()
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, [
			STAT_DARK_MARBLE_DAMAGE,
			STAT_POISON_DAMAGE_PER_TICK,
			STAT_POISON_TICK_SECONDS,
			STAT_ECHO_TIMEOUT,
			STAT_EXPLOSION_EFFECT_SCALE,
			STAT_EXPLOSION_DAMAGE,
			STAT_EXPLOSION_RADIUS,
			STAT_ECHO_BONUS_DAMAGE,
			STAT_BLUE_FROST_DURATION,
			STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED,
			STAT_BLUE_FROST_STACKS_PER_HIT,
		])

	var types_to_sync: Array[int] = []
	for raw_type: int in _levels.keys():
		if not types_to_sync.has(raw_type):
			types_to_sync.append(raw_type)
	for raw_type: int in _awakened_types.keys():
		if not types_to_sync.has(raw_type):
			types_to_sync.append(raw_type)

	for raw_type: int in types_to_sync:
		var marble_type: Marble.MARBLE_TYPE = raw_type as Marble.MARBLE_TYPE
		var level: int = get_level(marble_type)
		if level <= 0:
			continue
		_apply_level_modifiers(stat_system, marble_type, level)


func _apply_level_modifiers(stat_system: Node, marble_type: Marble.MARBLE_TYPE, level: int) -> void:
	var data: Dictionary = UPGRADE_VALUES.get(marble_type, {})
	if data.is_empty():
		return
	var values: Array = data.get("values", [])
	var stat_id: String = String(data.get("stat", ""))
	if stat_id != "" and level - 1 >= 0 and level - 1 < values.size():
		_add_override_modifier(stat_system, stat_id, float(values[level - 1]))

	var awakened: bool = is_awakened(marble_type)
	if awakened and stat_id != "" and data.has("awakened_value"):
		_add_override_modifier(stat_system, stat_id, float(data.get("awakened_value")))

	if marble_type == Marble.MARBLE_TYPE.BOMB and awakened:
		_add_override_modifier(stat_system, STAT_EXPLOSION_RADIUS, 100.0)
		_add_override_modifier(stat_system, STAT_EXPLOSION_EFFECT_SCALE, 4.0)
	elif marble_type == Marble.MARBLE_TYPE.GREEN and awakened:
		_add_override_modifier(stat_system, STAT_POISON_TICK_SECONDS, 0.5)
	elif marble_type == Marble.MARBLE_TYPE.BROWN and awakened:
		_add_override_modifier(stat_system, STAT_ECHO_TIMEOUT, 15.0)
	elif marble_type == Marble.MARBLE_TYPE.BLUE:
		if level >= 2:
			_add_override_modifier(stat_system, STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED, 1.0)
		if awakened:
			_add_override_modifier(stat_system, STAT_BLUE_FROST_STACKS_PER_HIT, 2.0)


func _add_override_modifier(stat_system: Node, stat_id: String, value: float) -> void:
	stat_system.call(
		"add_modifier",
		STAT_ENTITY_MARBLE_CHAIN,
		StatModifierScript.new(
			"%s:%s" % [MODIFIER_SOURCE, stat_id],
			stat_id,
			OP_OVERRIDE,
			value,
			MODIFIER_SOURCE
		)
	)


func _clear_upgrade_modifiers() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("remove_modifiers_by_source"):
		return
	stat_system.call("remove_modifiers_by_source", STAT_ENTITY_MARBLE_CHAIN, MODIFIER_SOURCE)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
