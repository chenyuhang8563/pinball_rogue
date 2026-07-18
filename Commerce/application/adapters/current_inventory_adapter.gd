extends RefCounted

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")

const SNAPSHOT_FIELDS: Array[StringName] = [
	&"items",
	&"marble_items",
	&"relic_items",
	&"skill_items",
	&"skill_item",
	&"relic_levels",
	&"relic_awakened",
]

var _inventory: Node = null


func _init(inventory: Node = null) -> void:
	_inventory = inventory


func get_inventory() -> Node:
	return _inventory


func find_owned(candidate: Item) -> Item:
	if candidate == null or not _is_available():
		return null
	var collection_name: StringName = &""
	match candidate.type:
		Item.ItemType.MARBLE:
			collection_name = &"marble_items"
		Item.ItemType.RELIC:
			collection_name = &"relic_items"
		Item.ItemType.SKILL:
			collection_name = &"skill_items"
		_:
			return null
	var values: Variant = _inventory.get(collection_name)
	if not values is Array:
		return null
	for value: Variant in values:
		var owned := value as Item
		if ItemIdentityScript.same(owned, candidate):
			return owned
	return null


func can_add(item: Item) -> bool:
	return item != null and _is_available() and _inventory.has_method("can_add_item") \
		and bool(_inventory.call("can_add_item", item))


func add(item: Item) -> bool:
	return item != null and _is_available() and _inventory.has_method("add_item") \
		and bool(_inventory.call("add_item", item))


func remove(item: Item) -> bool:
	return item != null and _is_available() and _inventory.has_method("remove_item") \
		and bool(_inventory.call("remove_item", item))


func replace_skill(item: Item) -> bool:
	return item != null and _is_available() and _inventory.has_method("replace_skill") \
		and bool(_inventory.call("replace_skill", item))


func current_skill() -> Item:
	if not _is_available():
		return null
	return _inventory.get("skill_item") as Item


func snapshot() -> Dictionary:
	if not _is_available():
		return {}
	var result: Dictionary = {}
	for field: StringName in SNAPSHOT_FIELDS:
		result[field] = _copy_value(_inventory.get(field))
	result[&"revision"] = revision()
	return result


func restore(state: Dictionary) -> bool:
	if not _is_available() or state.is_empty():
		return false
	for field: StringName in SNAPSHOT_FIELDS:
		if not state.has(field):
			return false
	for field: StringName in SNAPSHOT_FIELDS:
		_inventory.set(field, _copy_value(state[field]))
	if _inventory.has_signal(&"inventory_changed"):
		_inventory.emit_signal(&"inventory_changed")
	return revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	if not _is_available():
		return 0
	var state: Dictionary = {}
	for field: StringName in SNAPSHOT_FIELDS:
		state[field] = _copy_value(_inventory.get(field))
	return state.hash()


func _copy_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


func _is_available() -> bool:
	return _inventory != null and is_instance_valid(_inventory)
