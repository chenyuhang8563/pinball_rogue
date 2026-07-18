extends RefCounted

const SNAPSHOT_FIELDS: Array[StringName] = [
	&"_levels",
	&"_awakened_types",
	&"_skill_levels",
]

var _progression: Node = null
var _inventory_source: Variant = null


func _init(progression: Node = null, inventory_adapter_or_node: Variant = null) -> void:
	_progression = progression
	_inventory_source = inventory_adapter_or_node


func level_of(item: Item) -> int:
	if item == null or not _is_available():
		return 0
	if item.type == Item.ItemType.MARBLE:
		if _progression.has_method("is_awakened") and bool(_progression.call("is_awakened", item.marble_type)):
			return 4
		return int(_progression.call("get_level", item.marble_type)) if _progression.has_method("get_level") else 0
	if item.type == Item.ItemType.RELIC:
		var inventory := _inventory_node()
		if inventory == null:
			return 0
		if inventory.has_method("is_relic_awakened") and bool(inventory.call("is_relic_awakened", item)):
			return 4
		return int(inventory.call("get_relic_level", item)) if inventory.has_method("get_relic_level") else 0
	if item.type == Item.ItemType.SKILL:
		return int(_progression.call("get_skill_level", item.id)) if _progression.has_method("get_skill_level") else 0
	return 0


func can_upgrade(item: Item) -> bool:
	var inventory := _inventory_node()
	return item != null and inventory != null and _is_available() \
		and _progression.has_method("can_upgrade_item") \
		and bool(_progression.call("can_upgrade_item", item, inventory))


func upgrade_one(item: Item) -> bool:
	var inventory := _inventory_node()
	return item != null and inventory != null and _is_available() \
		and _progression.has_method("upgrade_item") \
		and bool(_progression.call("upgrade_item", item, inventory))


func reset_skill(skill_id: String) -> bool:
	if not _is_available() or not _progression.has_method("reset_skill_level"):
		return false
	_progression.call("reset_skill_level", skill_id)
	var levels: Variant = _progression.get("_skill_levels")
	return levels is Dictionary and not (levels as Dictionary).has(skill_id)


func reset_item(item: Item) -> bool:
	if item == null:
		return false
	if item.type != Item.ItemType.MARBLE:
		return true
	if not _is_available() or not _progression.has_method("reset_marble_level") \
			or not _progression.has_method("get_level") or not _progression.has_method("is_awakened"):
		return false
	_progression.call("reset_marble_level", item.marble_type)
	return int(_progression.call("get_level", item.marble_type)) == 1 \
		and not bool(_progression.call("is_awakened", item.marble_type))


func snapshot() -> Dictionary:
	if not _is_available():
		return {}
	var result: Dictionary = {}
	for field: StringName in SNAPSHOT_FIELDS:
		var value: Variant = _progression.get(field)
		result[field] = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	result[&"revision"] = revision()
	return result


func restore(state: Dictionary) -> bool:
	if not _is_available() or state.is_empty():
		return false
	for field: StringName in SNAPSHOT_FIELDS:
		if not state.has(field) or not state[field] is Dictionary:
			return false
	for field: StringName in SNAPSHOT_FIELDS:
		_progression.set(field, (state[field] as Dictionary).duplicate(true))
	if _progression.has_method("_sync_stat_modifiers"):
		_progression.call("_sync_stat_modifiers")
	return revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	if not _is_available():
		return 0
	var state: Dictionary = {}
	for field: StringName in SNAPSHOT_FIELDS:
		var value: Variant = _progression.get(field)
		state[field] = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return state.hash()


func _inventory_node() -> Node:
	if _inventory_source is Node:
		return _inventory_source as Node
	if _inventory_source != null and _inventory_source.has_method("get_inventory"):
		return _inventory_source.call("get_inventory") as Node
	return null


func _is_available() -> bool:
	return _progression != null and is_instance_valid(_progression)
