extends Node

signal item_added(item: Item)
signal inventory_changed

@export var items: Array[Item] = []

func add_item(item: Item) -> void:
	if item == null:
		return

	items.append(item)
	item_added.emit(item)
	inventory_changed.emit()


func has_item_id(id: String) -> bool:
	for item in items:
		if item != null and item.id == id:
			return true
	return false


func has_effect(effect_type: Item.EffectType) -> bool:
	for item in items:
		if item != null and item.effect_type == effect_type:
			return true
	return false
