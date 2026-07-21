extends RefCounted

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const NONE := 0
const BEFORE_MUTATION := 1
const AFTER_MUTATION := 2

var levels: Dictionary = {}
var revision_value: int = 0
var upgrade_failure_call: int = -1
var upgrade_failure: int = NONE
var reset_failure: int = NONE
var reset_item_failure: int = NONE
var restore_fails: bool = false
var upgrade_calls: int = 0


func level_of(item: Item) -> int:
	return int(levels.get(ItemIdentityScript.key(item), 1)) if item != null else 0


func set_level(item: Item, level: int) -> void:
	levels[ItemIdentityScript.key(item)] = level


func can_upgrade(item: Item) -> bool:
	return item != null and level_of(item) < 4


func upgrade_one(item: Item) -> bool:
	upgrade_calls += 1
	var should_fail := upgrade_calls == upgrade_failure_call
	if should_fail and upgrade_failure == BEFORE_MUTATION:
		return false
	levels[ItemIdentityScript.key(item)] = level_of(item) + 1
	revision_value += 1
	return not should_fail or upgrade_failure != AFTER_MUTATION


func reset_skill(skill_id: String) -> bool:
	if reset_failure == BEFORE_MUTATION:
		return false
	levels.erase("type:%d:id:%s" % [Item.ItemType.SKILL, skill_id])
	revision_value += 1
	return reset_failure != AFTER_MUTATION


func reset_item(item: Item) -> bool:
	if reset_item_failure == BEFORE_MUTATION:
		return false
	levels.erase(ItemIdentityScript.key(item))
	revision_value += 1
	return reset_item_failure != AFTER_MUTATION


func revision() -> int:
	return revision_value


func bump_revision() -> void:
	revision_value += 1


func snapshot() -> Dictionary:
	return {
		&"levels": levels.duplicate(true),
		&"revision": revision_value,
		&"upgrade_calls": upgrade_calls,
	}


func restore(state: Dictionary) -> bool:
	if restore_fails:
		return false
	levels = (state[&"levels"] as Dictionary).duplicate(true)
	revision_value = int(state[&"revision"])
	upgrade_calls = int(state[&"upgrade_calls"])
	return true
