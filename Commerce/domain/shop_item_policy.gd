extends RefCounted
class_name ShopItemPolicy

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")


static func has_same_identity(first: Item, second: Item) -> bool:
	return ItemIdentityScript.same(first, second)


static func find_owned_item(candidate: Item, loadout: Variant) -> Item:
	if loadout == null or not loadout.has_method("find_owned"):
		return null
	return loadout.call("find_owned", candidate) as Item


static func get_level(item: Item, _loadout: Variant, progression: Variant) -> int:
	if progression == null or not progression.has_method("level_of"):
		return 0
	return int(progression.call("level_of", item))
