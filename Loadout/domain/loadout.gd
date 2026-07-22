extends RefCounted

const MarbleLoadoutScript: GDScript = preload("res://Loadout/domain/marble_loadout.gd")

signal changed
signal item_added(item: Item)
signal marble_loadout_changed(items: Array[Item])
signal skill_slot_changed(item: Item)

const DEFAULT_MARBLE_CAPACITY: int = 3
const DEFAULT_RELIC_CAPACITY: int = 5
const DEFAULT_SKILL_CAPACITY: int = 1

var _owned_items: Array[Item] = []
var _marble_loadout: RefCounted
var _capacity_provider: Callable = Callable()
var _suppress_marble_events: bool = false


func _init(capacity_provider: Callable = Callable()) -> void:
	_capacity_provider = capacity_provider
	_marble_loadout = MarbleLoadoutScript.new(Callable(self, "_owns_marble"))
	_marble_loadout.changed.connect(_on_marble_loadout_changed)


func configure_capacity_provider(capacity_provider: Callable) -> void:
	_capacity_provider = capacity_provider


func owned_items() -> Array[Item]:
	return _owned_items.duplicate()


func marbles() -> Array[Item]:
	return _items_of_type(Item.ItemType.MARBLE)


func relics() -> Array[Item]:
	return _items_of_type(Item.ItemType.RELIC)


func skills() -> Array[Item]:
	return _items_of_type(Item.ItemType.SKILL)


func get_chain_items() -> Array[Item]:
	return _marble_loadout.call("get_chain_items") as Array[Item]


func set_chain_items(items: Array) -> bool:
	if not _is_complete_marble_order(items):
		return false
	return bool(_marble_loadout.call("set_order", items))


func find_owned(candidate: Item) -> Item:
	if candidate == null:
		return null
	var key := _identity_key(candidate)
	for item: Item in _owned_items:
		if _identity_key(item) == key:
			return item
	return null


func contains(item: Item) -> bool:
	return find_owned(item) != null


func has_item_id(id: String) -> bool:
	if id == "":
		return false
	for item: Item in _owned_items:
		if item.id == id:
			return true
	return false


func has_effect(effect_type: Item.EffectType) -> bool:
	for item: Item in _owned_items:
		if item.effect_type == effect_type:
			return true
	return false


func can_add(item: Item) -> bool:
	if item == null or item.type not in [Item.ItemType.MARBLE, Item.ItemType.RELIC, Item.ItemType.SKILL]:
		return false
	if contains(item):
		return false
	return _items_of_type(item.type).size() < _capacity_for(item.type)


func add(item: Item) -> bool:
	if not can_add(item):
		return false
	_owned_items.append(item)
	if item.type == Item.ItemType.MARBLE:
		_suppress_marble_events = true
		var appended := bool(_marble_loadout.call("append", item))
		_suppress_marble_events = false
		if not appended:
			_owned_items.erase(item)
			return false
	item_added.emit(item)
	if item.type == Item.ItemType.MARBLE:
		marble_loadout_changed.emit(get_chain_items())
	elif item.type == Item.ItemType.SKILL:
		skill_slot_changed.emit(item)
	changed.emit()
	return true


func remove(item: Item) -> bool:
	var owned := find_owned(item)
	if owned == null:
		return false
	_owned_items.erase(owned)
	if owned.type == Item.ItemType.MARBLE:
		_suppress_marble_events = true
		var removed := bool(_marble_loadout.call("remove", owned))
		_suppress_marble_events = false
		if not removed:
			_owned_items.append(owned)
			return false
		marble_loadout_changed.emit(get_chain_items())
	elif owned.type == Item.ItemType.SKILL:
		skill_slot_changed.emit(current_skill())
	changed.emit()
	return true


func replace_skill(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.SKILL or contains(item):
		return false
	var previous := current_skill()
	if previous == null:
		return add(item)
	var index := _owned_items.find(previous)
	if index < 0:
		return false
	_owned_items[index] = item
	item_added.emit(item)
	skill_slot_changed.emit(item)
	changed.emit()
	return true


func current_skill() -> Item:
	for item: Item in _owned_items:
		if item.type == Item.ItemType.SKILL:
			return item
	return null


func snapshot() -> Dictionary:
	return {
		&"owned_items": owned_items(),
		&"marble_loadout": _marble_loadout.call("snapshot"),
		&"revision": revision(),
	}


func restore(state: Dictionary) -> bool:
	if not state.has(&"owned_items") or not state[&"owned_items"] is Array \
			or not state.has(&"marble_loadout") or not state[&"marble_loadout"] is Dictionary:
		return false
	var validated_items: Variant = _validated_owned_items(state[&"owned_items"] as Array)
	if not validated_items is Array:
		return false
	var restored_items: Array[Item] = validated_items as Array[Item]
	var previous_items := _owned_items
	var previous_chain := get_chain_items()
	var previous_skill := current_skill()
	var ownership_changed := not _same_items(previous_items, restored_items)
	_owned_items = restored_items
	var chain_state := state[&"marble_loadout"] as Dictionary
	if not chain_state.has(&"items") or not chain_state[&"items"] is Array \
			or not _is_complete_marble_order(chain_state[&"items"] as Array):
		_owned_items = previous_items
		return false
	_suppress_marble_events = true
	var chain_restored := bool(_marble_loadout.call("restore", chain_state))
	_suppress_marble_events = false
	if not chain_restored:
		_owned_items = previous_items
		_suppress_marble_events = true
		_marble_loadout.call("set_order", previous_chain)
		_suppress_marble_events = false
		return false
	var chain_changed := not _same_items(previous_chain, get_chain_items())
	var skill_changed := previous_skill != current_skill()
	if chain_changed:
		marble_loadout_changed.emit(get_chain_items())
	if skill_changed:
		skill_slot_changed.emit(current_skill())
	if ownership_changed or chain_changed:
		changed.emit()
	return revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	var state := {
		&"owned": _item_instance_keys(_owned_items),
		&"chain_revision": int(_marble_loadout.call("revision")),
	}
	return state.hash()


func dispose() -> void:
	_capacity_provider = Callable()
	if _marble_loadout != null:
		_marble_loadout.call("dispose")
	_owned_items.clear()


func _capacity_for(item_type: Item.ItemType) -> int:
	var fallback: int
	match item_type:
		Item.ItemType.MARBLE:
			fallback = DEFAULT_MARBLE_CAPACITY
		Item.ItemType.RELIC:
			fallback = DEFAULT_RELIC_CAPACITY
		Item.ItemType.SKILL:
			fallback = DEFAULT_SKILL_CAPACITY
		_:
			return 0
	if not _capacity_provider.is_valid():
		return fallback
	return maxi(0, int(_capacity_provider.call(item_type, fallback)))


func _items_of_type(item_type: Item.ItemType) -> Array[Item]:
	var result: Array[Item] = []
	for item: Item in _owned_items:
		if item.type == item_type:
			result.append(item)
	return result


func _owns_marble(item: Item) -> bool:
	return item != null and item.type == Item.ItemType.MARBLE and find_owned(item) == item


func _on_marble_loadout_changed(items: Array[Item]) -> void:
	if _suppress_marble_events:
		return
	marble_loadout_changed.emit(items.duplicate())
	changed.emit()


func _validated_owned_items(values: Array) -> Variant:
	var result: Array[Item] = []
	var counts: Dictionary[int, int] = {}
	for value: Variant in values:
		var item := value as Item
		if item == null or item.type not in [Item.ItemType.MARBLE, Item.ItemType.RELIC, Item.ItemType.SKILL]:
			return null
		if _contains_identity(result, item):
			return null
		var type_key := int(item.type)
		var count := int(counts.get(type_key, 0)) + 1
		if count > _capacity_for(item.type):
			return null
		counts[type_key] = count
		result.append(item)
	return result


func _contains_identity(items: Array[Item], candidate: Item) -> bool:
	var key := _identity_key(candidate)
	for item: Item in items:
		if _identity_key(item) == key:
			return true
	return false


func _is_complete_marble_order(values: Array) -> bool:
	var owned_marbles := marbles()
	if values.size() != owned_marbles.size():
		return false
	var ordered: Array[Item] = []
	for value: Variant in values:
		var item := value as Item
		if item == null or item.type != Item.ItemType.MARBLE \
				or find_owned(item) != item or _contains_identity(ordered, item):
			return false
		ordered.append(item)
	return true


func _identity_key(item: Item) -> String:
	if item == null:
		return ""
	if item.type == Item.ItemType.MARBLE:
		return "type:%d:marble:%d" % [int(item.type), int(item.marble_type)]
	if item.id != "":
		return "type:%d:id:%s" % [int(item.type), item.id]
	if not item.resource_path.is_empty():
		return "type:%d:path:%s" % [int(item.type), item.resource_path]
	if item.effect_type != Item.EffectType.NONE:
		return "type:%d:effect:%d" % [int(item.type), int(item.effect_type)]
	return "type:%d:instance:%d" % [int(item.type), item.get_instance_id()]


func _item_instance_keys(items: Array[Item]) -> Array[String]:
	var result: Array[String] = []
	for item: Item in items:
		result.append("%s@%d" % [_identity_key(item), item.get_instance_id()])
	return result


func _same_items(first: Array[Item], second: Array[Item]) -> bool:
	if first.size() != second.size():
		return false
	for index: int in first.size():
		if first[index] != second[index]:
			return false
	return true
