extends Node

signal item_added(item: Item)
signal inventory_changed

@export var items: Array[Item] = []
@export var marble_capacity: int = 3
@export var relic_capacity: int = 3

var marble_items: Array[Item] = []
var relic_items: Array[Item] = []

func add_item(item: Item) -> bool:
	if not can_add_item(item):
		return false

	items.append(item)
	if item.type == Item.ItemType.MARBLE:
		marble_items.append(item)
	elif item.type == Item.ItemType.RELIC:
		relic_items.append(item)

	item_added.emit(item)
	inventory_changed.emit()
	return true


func remove_item(item: Item) -> bool:
	if item == null:
		return false
	if not _remove_from_array(items, item):
		return false

	if item.type == Item.ItemType.MARBLE:
		_remove_from_array(marble_items, item)
	elif item.type == Item.ItemType.RELIC:
		_remove_from_array(relic_items, item)

	inventory_changed.emit()
	return true


func can_add_item(item: Item) -> bool:
	if item == null:
		return false
	if item.type == Item.ItemType.MARBLE:
		return marble_items.size() < _get_capacity("marble_slot_count", marble_capacity)
	if item.type == Item.ItemType.RELIC:
		return relic_items.size() < _get_capacity("relic_slot_count", relic_capacity)
	return false


func has_item_id(id: String) -> bool:
	for item in items:
		if item != null and item.id == id:
			return true
	return false


func _remove_from_array(collection: Array, item: Item) -> bool:
	var index := collection.find(item)
	if index == -1:
		return false
	collection.remove_at(index)
	return true


func has_effect(effect_type: Item.EffectType) -> bool:
	for item in items:
		if item != null and item.effect_type == effect_type:
			return true
	return false


func _get_capacity(stat_id: String, fallback: int) -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return int(stat_system.call("get_stat", stat_id, "player"))


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
