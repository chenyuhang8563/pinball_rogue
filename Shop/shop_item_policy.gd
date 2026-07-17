extends RefCounted
class_name ShopItemPolicy


static func has_same_identity(first: Item, second: Item) -> bool:
	if first == null or second == null or first.type != second.type:
		return false
	if first.type == Item.ItemType.MARBLE:
		return first.marble_type == second.marble_type
	if first.id != "" or second.id != "":
		return first.id != "" and first.id == second.id
	return first.effect_type == second.effect_type


static func find_owned_item(candidate: Item, inventory: Node) -> Item:
	if candidate == null or inventory == null:
		return null
	var collection_name := ""
	match candidate.type:
		Item.ItemType.MARBLE:
			collection_name = "marble_items"
		Item.ItemType.RELIC:
			collection_name = "relic_items"
		Item.ItemType.SKILL:
			collection_name = "skill_items"
		_:
			return null
	var raw_items: Variant = inventory.get(collection_name)
	if not raw_items is Array:
		return null
	for owned_item: Item in raw_items as Array:
		if has_same_identity(owned_item, candidate):
			return owned_item
	return null


static func get_level(item: Item, inventory: Node, upgrade_system: Node) -> int:
	if item == null or upgrade_system == null:
		return 0
	if item.type == Item.ItemType.MARBLE:
		if bool(upgrade_system.call("is_awakened", item.marble_type)):
			return 4
		return int(upgrade_system.call("get_level", item.marble_type))
	if item.type == Item.ItemType.RELIC:
		if inventory == null:
			return 0
		if bool(inventory.call("is_relic_awakened", item)):
			return 4
		return int(inventory.call("get_relic_level", item))
	if item.type == Item.ItemType.SKILL:
		return int(upgrade_system.call("get_skill_level", item.id))
	return 0
