extends RefCounted
class_name ShopItemPolicy

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const CurrentInventoryAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_inventory_adapter.gd")
const CurrentProgressionAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_progression_adapter.gd")


static func has_same_identity(first: Item, second: Item) -> bool:
	return ItemIdentityScript.same(first, second)


static func find_owned_item(candidate: Item, inventory: Node) -> Item:
	var adapter: RefCounted = CurrentInventoryAdapterScript.new(inventory)
	return adapter.call("find_owned", candidate) as Item


static func get_level(item: Item, inventory: Node, upgrade_system: Node) -> int:
	var adapter: RefCounted = CurrentProgressionAdapterScript.new(upgrade_system, inventory)
	return int(adapter.call("level_of", item))
