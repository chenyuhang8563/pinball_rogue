extends RefCounted

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const NONE := 0
const BEFORE_MUTATION := 1
const AFTER_MUTATION := 2

var items: Array[Item] = []
var equipped_skill: Item = null
var capacity_available: bool = true
var revision_value: int = 0
var add_failure: int = NONE
var remove_failure: int = NONE
var replace_failure: int = NONE
var restore_fails: bool = false


func find_owned(candidate: Item) -> Item:
	for item: Item in items:
		if ItemIdentityScript.same(item, candidate):
			return item
	return null


func can_add(_item: Item) -> bool:
	return capacity_available


func add(item: Item) -> bool:
	if add_failure == BEFORE_MUTATION:
		return false
	items.append(item)
	if item.type == Item.ItemType.SKILL:
		equipped_skill = item
	revision_value += 1
	return add_failure != AFTER_MUTATION


func remove(item: Item) -> bool:
	if remove_failure == BEFORE_MUTATION or find_owned(item) == null:
		return false
	items.erase(find_owned(item))
	if equipped_skill != null and ItemIdentityScript.same(equipped_skill, item):
		equipped_skill = null
	revision_value += 1
	return remove_failure != AFTER_MUTATION


func replace_skill(item: Item) -> bool:
	if replace_failure == BEFORE_MUTATION:
		return false
	if equipped_skill != null:
		items.erase(equipped_skill)
	items.append(item)
	equipped_skill = item
	revision_value += 1
	return replace_failure != AFTER_MUTATION


func current_skill() -> Item:
	return equipped_skill


func revision() -> int:
	return revision_value


func bump_revision() -> void:
	revision_value += 1


func snapshot() -> Dictionary:
	return {
		&"items": items.duplicate(),
		&"equipped_skill": equipped_skill,
		&"capacity_available": capacity_available,
		&"revision": revision_value,
	}


func restore(state: Dictionary) -> bool:
	if restore_fails:
		return false
	items.assign(state[&"items"])
	equipped_skill = state[&"equipped_skill"] as Item
	capacity_available = bool(state[&"capacity_available"])
	revision_value = int(state[&"revision"])
	return true
