extends Node

const DASH_SKILL_ITEM: Item = preload("res://Resources/dash_skill.tres")

signal item_added(item: Item)
signal inventory_changed

@export var items: Array[Item] = []
@export var marble_capacity: int = 3
@export var relic_capacity: int = 3
@export var skill_capacity: int = 1

const RELIC_MAX_LEVEL: int = 3

var marble_items: Array[Item] = []
var relic_items: Array[Item] = []
var skill_items: Array[Item] = []
var skill_item: Item = null
var relic_levels: Dictionary = {}
var relic_awakened: Dictionary = {}


func _ready() -> void:
	_grant_starting_skill_once()

func add_item(item: Item) -> bool:
	if not can_add_item(item):
		return false

	if item.type == Item.ItemType.RELIC:
		var relic_key: String = _get_relic_key(item)
		var current_level: int = get_relic_level(item)
		if current_level > 0:
			if current_level >= RELIC_MAX_LEVEL:
				relic_awakened[relic_key] = true
			else:
				relic_levels[relic_key] = mini(current_level + 1, RELIC_MAX_LEVEL)
			item_added.emit(item)
			inventory_changed.emit()
			return true
		relic_levels[relic_key] = 1

	items.append(item)
	if item.type == Item.ItemType.MARBLE:
		marble_items.append(item)
	elif item.type == Item.ItemType.RELIC:
		relic_items.append(item)
	elif item.type == Item.ItemType.SKILL:
		skill_items.append(item)
		skill_item = item

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
		var relic_key: String = _get_relic_key(item)
		relic_levels.erase(relic_key)
		relic_awakened.erase(relic_key)
	elif item.type == Item.ItemType.SKILL:
		_remove_from_array(skill_items, item)
		skill_item = skill_items[0] if not skill_items.is_empty() else null

	inventory_changed.emit()
	return true


func can_add_item(item: Item) -> bool:
	if item == null:
		return false
	if item.type == Item.ItemType.MARBLE:
		return marble_items.size() < _get_capacity("marble_slot_count", marble_capacity)
	if item.type == Item.ItemType.RELIC:
		var current_level: int = get_relic_level(item)
		if current_level > 0:
			return not is_relic_awakened(item)
		return relic_items.size() < _get_capacity("relic_slot_count", relic_capacity)
	if item.type == Item.ItemType.SKILL:
		return skill_items.size() < skill_capacity and not has_item_id(item.id)
	return false


func replace_skill(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.SKILL or item.skill_definition == null:
		return false
	if has_item_id(item.id):
		return false
	var previous: Item = skill_item
	if previous != null:
		_remove_from_array(items, previous)
		_remove_from_array(skill_items, previous)
	items.append(item)
	skill_items.append(item)
	skill_item = item
	item_added.emit(item)
	inventory_changed.emit()
	return true


func get_relic_level(item: Item) -> int:
	if item == null or item.type != Item.ItemType.RELIC:
		return 0
	return clampi(int(relic_levels.get(_get_relic_key(item), 0)), 0, RELIC_MAX_LEVEL)


func get_relic_award_level(item: Item) -> int:
	if item == null or item.type != Item.ItemType.RELIC:
		return 0
	var current_level: int = get_relic_level(item)
	return 1 if current_level <= 0 else mini(current_level + 1, RELIC_MAX_LEVEL)


func is_relic_awakened(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.RELIC:
		return false
	return bool(relic_awakened.get(_get_relic_key(item), false))


func is_relic_max_level(item: Item) -> bool:
	return is_relic_awakened(item)


func upgrade_relic(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.RELIC or is_relic_awakened(item):
		return false
	var relic_key: String = _get_relic_key(item)
	var current_level: int = get_relic_level(item)
	if current_level <= 0:
		return false
	if current_level >= RELIC_MAX_LEVEL:
		relic_awakened[relic_key] = true
	else:
		relic_levels[relic_key] = current_level + 1
	item_added.emit(item)
	inventory_changed.emit()
	return true


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


func _get_relic_key(item: Item) -> String:
	if item == null:
		return ""
	if item.id != "":
		return "id:%s" % item.id
	return "effect:%d" % int(item.effect_type)


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


func _grant_starting_skill_once() -> void:
	if skill_item != null or has_item_id(DASH_SKILL_ITEM.id):
		return
	add_item(DASH_SKILL_ITEM)
