extends RefCounted


static func key(item: Item) -> String:
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


static func same(first: Item, second: Item) -> bool:
	if first == null or second == null or first.type != second.type:
		return false
	if first.type == Item.ItemType.MARBLE:
		return first.marble_type == second.marble_type
	return key(first) == key(second)
