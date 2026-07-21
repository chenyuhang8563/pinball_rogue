extends RefCounted


static func level_price(item: Item, level: int, level_multipliers: Dictionary) -> int:
	if item == null or level <= 0:
		return 0
	return maxi(0, roundi(float(item.price) * float(level_multipliers.get(level, 1.0))))


static func full_target_price(item: Item, target_level: int, level_multipliers: Dictionary) -> int:
	return level_price(item, target_level, level_multipliers)


static func quote(
	item: Item,
	target_level: int,
	owned_level: int,
	level_multipliers: Dictionary
) -> int:
	var full_price := full_target_price(item, target_level, level_multipliers)
	if owned_level <= 0:
		return full_price
	return maxi(0, full_price - level_price(item, owned_level, level_multipliers))


static func quote_price(
	item: Item,
	target_level: int,
	owned_level: int,
	level_multipliers: Dictionary
) -> int:
	return quote(item, target_level, owned_level, level_multipliers)
