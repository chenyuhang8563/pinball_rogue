extends RefCounted

signal changed(items: Array[Item])

var _chain_items: Array[Item] = []
var _owner_validator: Callable = Callable()


func _init(owner_validator: Callable = Callable()) -> void:
	_owner_validator = owner_validator


func configure_owner_validator(owner_validator: Callable) -> bool:
	for item: Item in _chain_items:
		if not _is_owned_marble(item, owner_validator):
			return false
	_owner_validator = owner_validator
	return true


func get_chain_items() -> Array[Item]:
	return _chain_items.duplicate()


func append(item: Item) -> bool:
	if not _is_owned_marble(item, _owner_validator) or _contains_identity(_chain_items, item):
		return false
	_chain_items.append(item)
	changed.emit(get_chain_items())
	return true


func remove(item: Item) -> bool:
	var index := _find_identity(_chain_items, item)
	if index < 0:
		return false
	_chain_items.remove_at(index)
	changed.emit(get_chain_items())
	return true


func set_order(items: Array) -> bool:
	var validated: Array[Item] = []
	for value: Variant in items:
		var item := value as Item
		if not _is_owned_marble(item, _owner_validator) or _contains_identity(validated, item):
			return false
		validated.append(item)
	if _same_order(_chain_items, validated):
		return true
	_chain_items = validated
	changed.emit(get_chain_items())
	return true


func snapshot() -> Dictionary:
	return {
		&"items": get_chain_items(),
		&"revision": revision(),
	}


func restore(state: Dictionary) -> bool:
	if not state.has(&"items") or not state[&"items"] is Array:
		return false
	return set_order(state[&"items"] as Array) \
		and revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	var identities: Array[String] = []
	for item: Item in _chain_items:
		identities.append("%s@%d" % [_identity_key(item), item.get_instance_id()])
	return identities.hash()


func dispose() -> void:
	_owner_validator = Callable()
	_chain_items.clear()


func _is_owned_marble(item: Item, validator: Callable) -> bool:
	if item == null or item.type != Item.ItemType.MARBLE:
		return false
	return not validator.is_valid() or bool(validator.call(item))


func _contains_identity(items: Array[Item], candidate: Item) -> bool:
	return _find_identity(items, candidate) >= 0


func _find_identity(items: Array[Item], candidate: Item) -> int:
	if candidate == null:
		return -1
	var key := _identity_key(candidate)
	for index: int in items.size():
		if _identity_key(items[index]) == key:
			return index
	return -1


func _identity_key(item: Item) -> String:
	return "marble:%d" % int(item.marble_type) if item != null else ""


func _same_order(first: Array[Item], second: Array[Item]) -> bool:
	if first.size() != second.size():
		return false
	for index: int in first.size():
		if first[index] != second[index]:
			return false
	return true
