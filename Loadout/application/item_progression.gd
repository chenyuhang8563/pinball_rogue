extends RefCounted

const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const LevelConfigLoaderScript: GDScript = preload("res://Content/application/level_config_loader.gd")

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
const STAT_ECHO_FLIPPER_SPEED_MULTIPLIER: String = "echo_flipper_speed_multiplier"
const STAT_EXPLOSION_EFFECT_SCALE: String = "explosion_effect_scale"
const STAT_EXPLOSION_DAMAGE: String = "explosion_damage"
const STAT_EXPLOSION_RADIUS: String = "explosion_radius"
const STAT_ECHO_BONUS_DAMAGE: String = "echo_bonus_damage"
const STAT_ASSASSIN_SEGMENT_DAMAGE: String = "assassin_segment_damage"
const STAT_ASSASSIN_WEAK_POINT_COUNT: String = "assassin_weak_point_count"
const STAT_LIGHTNING_DISCHARGE_DAMAGE: String = "lightning_discharge_damage_per_stack"
const STAT_LIGHTNING_REPEAT_ARC_STACKS: String = "lightning_repeat_arc_stacks"

## Stat ids the marble_chain entity registers. This list is the StatSystem
## contract for marble upgrades: a bad CSV must never change what gets
## registered. assassin_weak_point_count is intentionally not in the CSV — it
## depends on the live chain and is applied separately.
const REGISTERED_MARBLE_STAT_IDS: Array = [
	STAT_DARK_MARBLE_DAMAGE,
	STAT_POISON_MAX_STACKS,
	STAT_POISON_STACKS_PER_HIT,
	STAT_ECHO_FLIPPER_SPEED_MULTIPLIER,
	STAT_EXPLOSION_EFFECT_SCALE,
	STAT_EXPLOSION_DAMAGE,
	STAT_EXPLOSION_RADIUS,
	STAT_ECHO_BONUS_DAMAGE,
	STAT_BLUE_FROST_DURATION,
	STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED,
	STAT_BLUE_FROST_STACKS_PER_HIT,
	STAT_FIRE_BURN_MAX_STACKS,
	STAT_FIRE_BURN_DAMAGE_PER_LAYER,
	STAT_ASSASSIN_SEGMENT_DAMAGE,
	STAT_ASSASSIN_WEAK_POINT_COUNT,
	STAT_LIGHTNING_DISCHARGE_DAMAGE,
	STAT_LIGHTNING_REPEAT_ARC_STACKS,
]

var _loadout: RefCounted = null
var _stat_system: Object = null
var _marble_levels: Dictionary = {}
var _marble_awakened: Dictionary = {}
var _relic_levels: Dictionary = {}
var _relic_awakened: Dictionary = {}
var _skill_levels: Dictionary = {}
## CSV data (marble_type_int -> {stat_id -> [{min_level, value}]}) and
## (skill_id -> [{stat fields} ...] ordered by level 1..4).
var _marble_level_modifiers: Dictionary = {}
var _skill_level_values: Dictionary = {}


func _init(loadout: RefCounted = null, stat_system: Object = null, level_config: Dictionary = {}) -> void:
	_loadout = loadout
	_stat_system = stat_system
	if level_config.is_empty():
		var result: Dictionary = LevelConfigLoaderScript.load_config()
		if bool(result.get(&"ok", false)):
			_install_level_config(result[&"config"] as Dictionary)
		else:
			# Fail closed: bad config leaves _marble_level_modifiers empty and
			# level_of() returns 0 rather than falling back to stale numbers.
			for message in result.get(&"errors", PackedStringArray()):
				push_error("ItemProgression config: %s" % message)
	else:
		_install_level_config(level_config)
	_connect_loadout_signals()


func _install_level_config(config: Dictionary) -> void:
	var marble_modifiers: Variant = config.get(&"marble_modifiers", {})
	if marble_modifiers is Dictionary:
		_marble_level_modifiers = marble_modifiers
	var skill_values: Variant = config.get(&"skill_level_values", {})
	if skill_values is Dictionary:
		_skill_level_values = skill_values


## Assassin weak-point presence depends on the live chain (an owned marble that is
## not slotted must not reveal weak points), so re-sync whenever the marble loadout
## changes. Awakening state is tracked locally and handled in _sync_stat_modifiers.
func _connect_loadout_signals() -> void:
	if _loadout != null and is_instance_valid(_loadout) \
			and _loadout.has_signal("marble_loadout_changed") \
			and not _loadout.is_connected("marble_loadout_changed", _on_loadout_marble_changed):
		_loadout.connect("marble_loadout_changed", _on_loadout_marble_changed)


func _disconnect_loadout_signals() -> void:
	if _loadout != null and is_instance_valid(_loadout) \
			and _loadout.has_signal("marble_loadout_changed") \
			and _loadout.is_connected("marble_loadout_changed", _on_loadout_marble_changed):
		_loadout.disconnect("marble_loadout_changed", _on_loadout_marble_changed)


func _on_loadout_marble_changed(_items: Array[Item]) -> void:
	_sync_stat_modifiers()


func level_of(item: Item) -> int:
	if item == null:
		return 0
	match item.type:
		Item.ItemType.MARBLE:
			if not _marble_level_modifiers.has(int(item.marble_type)):
				return 0
			return AWAKENED_LEVEL if bool(_marble_awakened.get(int(item.marble_type), false)) \
				else clampi(int(_marble_levels.get(int(item.marble_type), 1)), 1, MAX_LEVEL)
		Item.ItemType.RELIC:
			var relic_key := _relic_key(item)
			return AWAKENED_LEVEL if bool(_relic_awakened.get(relic_key, false)) \
				else clampi(int(_relic_levels.get(relic_key, 1)), 1, MAX_LEVEL)
		Item.ItemType.SKILL:
			if not _skill_level_values.has(item.id):
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
	if skill_id == "" or not _skill_level_values.has(skill_id):
		return false
	_skill_levels.erase(skill_id)
	skill_progressed.emit(skill_id, 1)
	return true


## 直接将已拥有物品设为指定等级（调试修改器用）。觉醒等级 4 写入 _awakened 标记；
## 其余 1..3 写入普通等级并清除觉醒标记。要求物品已拥有，与 upgrade_one 一致。
func set_level(item: Item, level: int) -> bool:
	if item == null or not _loadout_available():
		return false
	var owned := _loadout.call("find_owned", item) as Item
	if owned == null:
		return false
	match owned.type:
		Item.ItemType.MARBLE:
			if not _marble_level_modifiers.has(int(owned.marble_type)):
				return false
			if level >= AWAKENED_LEVEL:
				_marble_levels[int(owned.marble_type)] = MAX_LEVEL
				_marble_awakened[int(owned.marble_type)] = true
			else:
				_marble_levels[int(owned.marble_type)] = clampi(level, 1, MAX_LEVEL)
				_marble_awakened.erase(int(owned.marble_type))
			_sync_stat_modifiers()
			item_progressed.emit(owned, level_of(owned), level_of(owned) == AWAKENED_LEVEL)
		Item.ItemType.RELIC:
			var relic_key := _relic_key(owned)
			if level >= AWAKENED_LEVEL:
				_relic_levels[relic_key] = MAX_LEVEL
				_relic_awakened[relic_key] = true
			else:
				_relic_levels[relic_key] = clampi(level, 1, MAX_LEVEL)
				_relic_awakened.erase(relic_key)
			item_progressed.emit(owned, level_of(owned), level_of(owned) == AWAKENED_LEVEL)
		Item.ItemType.SKILL:
			if not _skill_level_values.has(owned.id):
				return false
			_skill_levels[owned.id] = clampi(level, 1, AWAKENED_LEVEL)
			skill_progressed.emit(owned.id, level_of(owned))
		_:
			return false
	return true


func reset_item(item: Item) -> bool:
	if item == null:
		return false
	match item.type:
		Item.ItemType.MARBLE:
			if not _marble_level_modifiers.has(int(item.marble_type)):
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
	if not _valid_snapshot(state):
		return false
	_marble_levels = (state[&"marble_levels"] as Dictionary).duplicate(true)
	_marble_awakened = (state[&"marble_awakened"] as Dictionary).duplicate(true)
	_relic_levels = (state[&"relic_levels"] as Dictionary).duplicate(true)
	_relic_awakened = (state[&"relic_awakened"] as Dictionary).duplicate(true)
	_skill_levels = (state[&"skill_levels"] as Dictionary).duplicate(true)
	_sync_stat_modifiers()
	return revision() == int(state.get(&"revision", revision()))


func _valid_snapshot(state: Dictionary) -> bool:
	if not _loadout_available():
		return false
	var owned_marbles: Dictionary[int, bool] = {}
	var owned_relics: Dictionary[String, bool] = {}
	for item: Item in _loadout.call("owned_items") as Array[Item]:
		match item.type:
			Item.ItemType.MARBLE:
				owned_marbles[int(item.marble_type)] = true
			Item.ItemType.RELIC:
				owned_relics[_relic_key(item)] = true
			Item.ItemType.SKILL:
				pass
	for key: Variant in (state[&"marble_levels"] as Dictionary):
		if not key is int or not owned_marbles.has(int(key)) \
				or not (state[&"marble_levels"] as Dictionary)[key] is int \
				or int((state[&"marble_levels"] as Dictionary)[key]) < 1 \
				or int((state[&"marble_levels"] as Dictionary)[key]) > MAX_LEVEL:
			return false
	for key: Variant in (state[&"marble_awakened"] as Dictionary):
		if not key is int or not owned_marbles.has(int(key)) \
				or not (state[&"marble_awakened"] as Dictionary)[key] is bool:
			return false
	for key: Variant in (state[&"relic_levels"] as Dictionary):
		if not key is String or not owned_relics.has(String(key)) \
				or not (state[&"relic_levels"] as Dictionary)[key] is int \
				or int((state[&"relic_levels"] as Dictionary)[key]) < 1 \
				or int((state[&"relic_levels"] as Dictionary)[key]) > MAX_LEVEL:
			return false
	for key: Variant in (state[&"relic_awakened"] as Dictionary):
		if not key is String or not owned_relics.has(String(key)) \
				or not (state[&"relic_awakened"] as Dictionary)[key] is bool:
			return false
	for key: Variant in (state[&"skill_levels"] as Dictionary):
		if not key is String or not _skill_level_values.has(String(key)) \
				or not (state[&"skill_levels"] as Dictionary)[key] is int \
				or int((state[&"skill_levels"] as Dictionary)[key]) < 1 \
				or int((state[&"skill_levels"] as Dictionary)[key]) > AWAKENED_LEVEL:
			return false
	return true


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
		if item.type == Item.ItemType.SKILL and _skill_level_values.has(item.id):
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
	if not _skill_level_values.has(skill_id):
		return {}
	var values: Array = _skill_level_values[skill_id]
	var level := clampi(int(_skill_levels.get(skill_id, 1)), 1, AWAKENED_LEVEL)
	return (values[level - 1] as Dictionary).duplicate(true)


func dispose() -> void:
	_disconnect_loadout_signals()
	_clear_upgrade_modifiers()
	_loadout = null
	_stat_system = null


func _sync_stat_modifiers() -> void:
	if not _stat_system_available() or not _stat_system.has_method("add_modifier"):
		return
	_clear_upgrade_modifiers()
	if _stat_system.has_method("register_entity"):
		_stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, REGISTERED_MARBLE_STAT_IDS)
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
	_apply_assassin_weak_point_count()


func _apply_level_modifiers(marble_type: Marble.MARBLE_TYPE) -> void:
	var stat_rows_by_id: Dictionary = _marble_level_modifiers.get(int(marble_type), {})
	if stat_rows_by_id.is_empty():
		return
	var stored_level := clampi(int(_marble_levels.get(int(marble_type), 1)), 1, MAX_LEVEL)
	var effective_level := AWAKENED_LEVEL if bool(_marble_awakened.get(int(marble_type), false)) else stored_level
	# 每个 stat 取 min_level <= effective_level 中 min_level 最大的一行。
	# 显式求最大值，不依赖 loader 的行序（其排序只是可审计性的保证）。
	for raw_stat_id: Variant in stat_rows_by_id:
		var best_min_level := 0
		var best_value := 0.0
		for row: Dictionary in stat_rows_by_id[raw_stat_id] as Array:
			var min_level := int(row.get("min_level", 0))
			if min_level <= effective_level and min_level > best_min_level:
				best_min_level = min_level
				best_value = float(row.get("value", 0.0))
		if best_min_level > 0:
			_add_override_modifier(String(raw_stat_id), best_value)


## Assassin weak-point presence reflects the live chain: 0 when no assassin marble
## is slotted, 1 when present, 2 when present and awakened. Written as an OVERRIDE
## modifier on the marble_chain entity so WeakPointHost reads it directly.
func _apply_assassin_weak_point_count() -> void:
	var count: int = 0
	if _loadout_available() and _loadout.has_method("get_chain_items"):
		var in_field: bool = false
		for item: Item in _loadout.call("get_chain_items") as Array[Item]:
			if item != null and int(item.marble_type) == int(Marble.MARBLE_TYPE.ASSASSIN):
				in_field = true
				break
		if in_field:
			var awakened: bool = bool(_marble_awakened.get(int(Marble.MARBLE_TYPE.ASSASSIN), false))
			count = 2 if awakened else 1
	_add_override_modifier(STAT_ASSASSIN_WEAK_POINT_COUNT, float(count))


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
