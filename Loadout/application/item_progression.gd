extends RefCounted

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")

signal item_progressed(item: Item, level: int, awakened: bool)
signal skill_progressed(skill_id: String, level: int)

const MAX_LEVEL: int = 3
const AWAKENED_LEVEL: int = 4
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const MODIFIER_SOURCE: String = "marble_upgrade"
const OP_OVERRIDE: int = 2

const STAT_DARK_MARBLE_DAMAGE: String = "dark_marble_damage"
const STAT_BLUE_FROST_DURATION: String = "blue_frost_duration"
const STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED: String = "blue_frost_bonus_damage_enabled"
const STAT_BLUE_FROST_STACKS_PER_HIT: String = "blue_frost_stacks_per_hit"
const STAT_POISON_MAX_STACKS: String = "poison_max_stacks"
const STAT_POISON_STACKS_PER_HIT: String = "poison_stacks_per_hit"
const STAT_FIRE_BURN_MAX_STACKS: String = "fire_burn_max_stacks"
const STAT_FIRE_BURN_DAMAGE_PER_LAYER: String = "fire_burn_damage_per_layer"
const STAT_FIRE_FUEL_PER_HIT: String = "fire_fuel_per_hit"
const STAT_ECHO_TIMEOUT: String = "echo_timeout"
const STAT_EXPLOSION_EFFECT_SCALE: String = "explosion_effect_scale"
const STAT_EXPLOSION_DAMAGE: String = "explosion_damage"
const STAT_EXPLOSION_RADIUS: String = "explosion_radius"
const STAT_ECHO_BONUS_DAMAGE: String = "echo_bonus_damage"

const UPGRADE_VALUES: Dictionary = {
	Marble.MARBLE_TYPE.DEFAULT: {
		"title": "ITEM_DARK_MARBLE_TITLE",
		"stat": STAT_DARK_MARBLE_DAMAGE,
		"values": [1.0, 2.0, 3.0],
		"awakened_value": 4.0,
		"descriptions": [
			"UPGRADE_DARK_DAMAGE_2_DESC",
			"UPGRADE_DARK_DAMAGE_3_DESC",
			"UPGRADE_DARK_AWAKEN_DESC",
		],
	},
	Marble.MARBLE_TYPE.BOMB: {
		"title": "ITEM_BOMB_MARBLE_TITLE",
		"stat": STAT_EXPLOSION_DAMAGE,
		"values": [5.0, 8.0, 8.0],
		"descriptions": [
			"UPGRADE_BOMB_DAMAGE_5_DESC",
			"UPGRADE_BOMB_DAMAGE_8_DESC",
			"UPGRADE_BOMB_AWAKEN_DESC",
		],
	},
	Marble.MARBLE_TYPE.GREEN: {
		"title": "ITEM_GREEN_MARBLE_TITLE",
		"stat": STAT_POISON_MAX_STACKS,
		"values": [10.0, 15.0, 20.0],
		"awakened_value": 20.0,
		"descriptions": [
			"UPGRADE_GREEN_POISON_2_DESC",
			"UPGRADE_GREEN_POISON_4_DESC",
			"UPGRADE_GREEN_AWAKEN_DESC",
		],
	},
	Marble.MARBLE_TYPE.BROWN: {
		"title": "ITEM_BROWN_MARBLE_TITLE",
		"stat": STAT_ECHO_BONUS_DAMAGE,
		"values": [2.0, 4.0, 8.0],
		"descriptions": [
			"UPGRADE_BROWN_ECHO_2_DESC",
			"UPGRADE_BROWN_ECHO_4_DESC",
			"UPGRADE_BROWN_AWAKEN_DESC",
		],
	},
	Marble.MARBLE_TYPE.BLUE: {
		"title": "ITEM_BLUE_MARBLE_TITLE",
		"stat": STAT_BLUE_FROST_DURATION,
		"values": [4.0, 4.0, 4.0],
		"descriptions": [
			"UPGRADE_BLUE_DURATION_DESC",
			"UPGRADE_BLUE_BONUS_DESC",
			"UPGRADE_BLUE_AWAKEN_DESC",
		],
	},
	Marble.MARBLE_TYPE.FIRE: {
		"title": "ITEM_FIRE_MARBLE_TITLE",
		"stat": STAT_FIRE_BURN_MAX_STACKS,
		"values": [10.0, 15.0, 15.0],
		"awakened_value": 15.0,
		"descriptions": [
			"UPGRADE_FIRE_DURATION_4_DESC",
			"UPGRADE_FIRE_DURATION_5_DESC",
			"UPGRADE_FIRE_AWAKEN_DESC",
		],
	},
}

const SKILL_LEVELS: Dictionary = {
	"dash": [
		{"recharge_time": 5.0, "dash_damage_multiplier": 1.0, "dash_damage_duration": 0.0},
		{"recharge_time": 4.0, "dash_damage_multiplier": 1.0, "dash_damage_duration": 0.0},
		{"recharge_time": 3.0, "dash_damage_multiplier": 1.2, "dash_damage_duration": 2.0},
		{"recharge_time": 3.0, "dash_damage_multiplier": 1.4, "dash_damage_duration": 2.0},
	],
	"magic_missile": [
		{"recharge_time": 4.0, "base_damage": 10, "projectile_lifetime": 4.0},
		{"recharge_time": 3.0, "base_damage": 15, "projectile_lifetime": 4.0},
		{"recharge_time": 2.5, "base_damage": 18, "projectile_lifetime": 4.0},
		{"recharge_time": 2.5, "base_damage": 24, "projectile_lifetime": 6.0},
	],
}

var _loadout: RefCounted = null
var _stat_system: Object = null
var _marble_levels: Dictionary = {}
var _marble_awakened: Dictionary = {}
var _relic_levels: Dictionary = {}
var _relic_awakened: Dictionary = {}
var _skill_levels: Dictionary = {}


func _init(loadout: RefCounted = null, stat_system: Object = null) -> void:
	_loadout = loadout
	_stat_system = stat_system


func level_of(item: Item) -> int:
	if item == null:
		return 0
	match item.type:
		Item.ItemType.MARBLE:
			if not UPGRADE_VALUES.has(item.marble_type):
				return 0
			return AWAKENED_LEVEL if bool(_marble_awakened.get(int(item.marble_type), false)) \
				else clampi(int(_marble_levels.get(int(item.marble_type), 1)), 1, MAX_LEVEL)
		Item.ItemType.RELIC:
			var relic_key := _relic_key(item)
			return AWAKENED_LEVEL if bool(_relic_awakened.get(relic_key, false)) \
				else clampi(int(_relic_levels.get(relic_key, 1)), 1, MAX_LEVEL)
		Item.ItemType.SKILL:
			if not SKILL_LEVELS.has(item.id):
				return 0
			return clampi(int(_skill_levels.get(item.id, 1)), 1, AWAKENED_LEVEL)
	return 0


func can_upgrade(item: Item) -> bool:
	var level := level_of(item)
	return level > 0 and level < AWAKENED_LEVEL


func upgrade_one(item: Item) -> bool:
	if not can_upgrade(item) or not _loadout_available():
		return false
	var owned := _loadout.call("find_owned", item) as Item
	if owned == null:
		return false
	var current_level := level_of(owned)
	match owned.type:
		Item.ItemType.MARBLE:
			var marble_key := int(owned.marble_type)
			if current_level >= MAX_LEVEL:
				_marble_awakened[marble_key] = true
			else:
				_marble_levels[marble_key] = current_level + 1
			_sync_stat_modifiers()
			item_progressed.emit(owned, level_of(owned), level_of(owned) == AWAKENED_LEVEL)
		Item.ItemType.RELIC:
			var relic_key := _relic_key(owned)
			if current_level >= MAX_LEVEL:
				_relic_awakened[relic_key] = true
			else:
				_relic_levels[relic_key] = current_level + 1
			item_progressed.emit(owned, level_of(owned), level_of(owned) == AWAKENED_LEVEL)
		Item.ItemType.SKILL:
			_skill_levels[owned.id] = current_level + 1
			skill_progressed.emit(owned.id, level_of(owned))
		_:
			return false
	return true


func reset_skill(skill_id: String) -> bool:
	if skill_id == "" or not SKILL_LEVELS.has(skill_id):
		return false
	_skill_levels.erase(skill_id)
	skill_progressed.emit(skill_id, 1)
	return true


func reset_item(item: Item) -> bool:
	if item == null:
		return false
	match item.type:
		Item.ItemType.MARBLE:
			if not UPGRADE_VALUES.has(item.marble_type):
				return false
			_marble_levels.erase(int(item.marble_type))
			_marble_awakened.erase(int(item.marble_type))
			_sync_stat_modifiers()
			item_progressed.emit(item, 1, false)
			return true
		Item.ItemType.RELIC:
			var key := _relic_key(item)
			_relic_levels.erase(key)
			_relic_awakened.erase(key)
			item_progressed.emit(item, 1, false)
			return true
		Item.ItemType.SKILL:
			return reset_skill(item.id)
	return false


func snapshot() -> Dictionary:
	return {
		&"marble_levels": _marble_levels.duplicate(true),
		&"marble_awakened": _marble_awakened.duplicate(true),
		&"relic_levels": _relic_levels.duplicate(true),
		&"relic_awakened": _relic_awakened.duplicate(true),
		&"skill_levels": _skill_levels.duplicate(true),
		&"revision": revision(),
	}


func restore(state: Dictionary) -> bool:
	for field: StringName in [
		&"marble_levels", &"marble_awakened", &"relic_levels", &"relic_awakened", &"skill_levels"
	]:
		if not state.has(field) or not state[field] is Dictionary:
			return false
	_marble_levels = (state[&"marble_levels"] as Dictionary).duplicate(true)
	_marble_awakened = (state[&"marble_awakened"] as Dictionary).duplicate(true)
	_relic_levels = (state[&"relic_levels"] as Dictionary).duplicate(true)
	_relic_awakened = (state[&"relic_awakened"] as Dictionary).duplicate(true)
	_skill_levels = (state[&"skill_levels"] as Dictionary).duplicate(true)
	_sync_stat_modifiers()
	return revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	return {
		&"marble_levels": _marble_levels,
		&"marble_awakened": _marble_awakened,
		&"relic_levels": _relic_levels,
		&"relic_awakened": _relic_awakened,
		&"skill_levels": _skill_levels,
	}.hash()


func reset_for_run() -> void:
	_marble_levels.clear()
	_marble_awakened.clear()
	_relic_levels.clear()
	_relic_awakened.clear()
	_skill_levels.clear()
	_clear_upgrade_modifiers()
	if not _loadout_available():
		return
	for item: Item in _loadout.call("owned_items") as Array[Item]:
		if item.type == Item.ItemType.SKILL and SKILL_LEVELS.has(item.id):
			skill_progressed.emit(item.id, 1)
		elif item.type in [Item.ItemType.MARBLE, Item.ItemType.RELIC] and level_of(item) > 0:
			item_progressed.emit(item, 1, false)


func upgradable_owned_items() -> Array[Item]:
	var result: Array[Item] = []
	if not _loadout_available():
		return result
	for item: Item in _loadout.call("owned_items") as Array[Item]:
		if can_upgrade(item):
			result.append(item)
	return result


func get_skill_values(skill_id: String) -> Dictionary:
	if not SKILL_LEVELS.has(skill_id):
		return {}
	var values: Array = SKILL_LEVELS[skill_id]
	var level := clampi(int(_skill_levels.get(skill_id, 1)), 1, AWAKENED_LEVEL)
	return (values[level - 1] as Dictionary).duplicate(true)


func dispose() -> void:
	_clear_upgrade_modifiers()
	_loadout = null
	_stat_system = null


func _sync_stat_modifiers() -> void:
	if not _stat_system_available() or not _stat_system.has_method("add_modifier"):
		return
	_clear_upgrade_modifiers()
	if _stat_system.has_method("register_entity"):
		_stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, [
			STAT_DARK_MARBLE_DAMAGE,
			STAT_POISON_MAX_STACKS,
			STAT_POISON_STACKS_PER_HIT,
			STAT_ECHO_TIMEOUT,
			STAT_EXPLOSION_EFFECT_SCALE,
			STAT_EXPLOSION_DAMAGE,
			STAT_EXPLOSION_RADIUS,
			STAT_ECHO_BONUS_DAMAGE,
			STAT_BLUE_FROST_DURATION,
			STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED,
			STAT_BLUE_FROST_STACKS_PER_HIT,
			STAT_FIRE_BURN_MAX_STACKS,
			STAT_FIRE_BURN_DAMAGE_PER_LAYER,
			STAT_FIRE_FUEL_PER_HIT,
		])
	var types_to_sync: Array[int] = []
	for raw_type: Variant in _marble_levels.keys():
		var marble_type := int(raw_type)
		if not types_to_sync.has(marble_type):
			types_to_sync.append(marble_type)
	for raw_type: Variant in _marble_awakened.keys():
		var marble_type := int(raw_type)
		if not types_to_sync.has(marble_type):
			types_to_sync.append(marble_type)
	for raw_type: int in types_to_sync:
		_apply_level_modifiers(raw_type as Marble.MARBLE_TYPE)


func _apply_level_modifiers(marble_type: Marble.MARBLE_TYPE) -> void:
	var data: Dictionary = UPGRADE_VALUES.get(marble_type, {})
	if data.is_empty():
		return
	var stored_level := clampi(int(_marble_levels.get(int(marble_type), 1)), 1, MAX_LEVEL)
	var values: Array = data.get("values", [])
	var stat_id := String(data.get("stat", ""))
	var awakened := bool(_marble_awakened.get(int(marble_type), false))
	if awakened and stat_id != "" and data.has("awakened_value"):
		_add_override_modifier(stat_id, float(data["awakened_value"]))
	elif stat_id != "" and stored_level - 1 < values.size():
		_add_override_modifier(stat_id, float(values[stored_level - 1]))
	if marble_type == Marble.MARBLE_TYPE.BOMB and awakened:
		_add_override_modifier(STAT_EXPLOSION_RADIUS, 100.0)
		_add_override_modifier(STAT_EXPLOSION_EFFECT_SCALE, 4.0)
	elif marble_type == Marble.MARBLE_TYPE.GREEN and awakened:
		_add_override_modifier(STAT_POISON_STACKS_PER_HIT, 2.0)
	elif marble_type == Marble.MARBLE_TYPE.BROWN and awakened:
		_add_override_modifier(STAT_ECHO_TIMEOUT, 15.0)
	elif marble_type == Marble.MARBLE_TYPE.BLUE:
		if stored_level >= 2:
			_add_override_modifier(STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED, 1.0)
		if awakened:
			_add_override_modifier(STAT_BLUE_FROST_STACKS_PER_HIT, 2.0)
	elif marble_type == Marble.MARBLE_TYPE.FIRE:
		if stored_level >= 3:
			_add_override_modifier(STAT_FIRE_BURN_DAMAGE_PER_LAYER, 2.0)
		if awakened:
			_add_override_modifier(STAT_FIRE_FUEL_PER_HIT, 2.0)


func _add_override_modifier(stat_id: String, value: float) -> void:
	_stat_system.call(
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
	if _stat_system_available() and _stat_system.has_method("remove_modifiers_by_source"):
		_stat_system.call("remove_modifiers_by_source", STAT_ENTITY_MARBLE_CHAIN, MODIFIER_SOURCE)


func _relic_key(item: Item) -> String:
	if item.id != "":
		return "id:%s" % item.id
	return "effect:%d" % int(item.effect_type)


func _loadout_available() -> bool:
	return _loadout != null and is_instance_valid(_loadout) \
		and _loadout.has_method("find_owned") and _loadout.has_method("owned_items")


func _stat_system_available() -> bool:
	return _stat_system != null and is_instance_valid(_stat_system)
