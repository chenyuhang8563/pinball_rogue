extends RefCounted


static func key(item: Item) -> String:
	if item == null:
		return ""
	if item.type == Item.ItemType.MARBLE:
		return "type:%d:marble:%d" % [int(item.type), int(item.marble_type)]
	if item.id != "":
		return "type:%d:id:%s" % [int(item.type), item.id]
	return "type:%d:effect:%d" % [int(item.type), int(item.effect_type)]


static func same(first: Item, second: Item) -> bool:
	if first == null or second == null or first.type != second.type:
		return false
	if first.type == Item.ItemType.MARBLE:
		return first.marble_type == second.marble_type
	if first.id != "" or second.id != "":
		return first.id != "" and first.id == second.id
	return first.effect_type == second.effect_type
