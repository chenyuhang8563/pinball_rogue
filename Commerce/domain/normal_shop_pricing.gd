extends RefCounted


static func quote(item: Item, multiplier: float = 1.0) -> int:
	if item == null:
		return 0
	return maxi(0, roundi(float(item.price) * multiplier))


static func price_for(item: Item, multiplier: float = 1.0) -> int:
	return quote(item, multiplier)


static func sell_quote(item: Item, multiplier: float = 0.5) -> int:
	if item == null:
		return 0
	return maxi(0, floori(float(item.price) * multiplier))
