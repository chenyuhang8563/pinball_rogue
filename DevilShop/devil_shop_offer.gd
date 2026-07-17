extends "res://Shop/shop_offer.gd"
class_name DevilShopOffer


func _init(
	value: Item = null,
	level: int = 0,
	value_price: int = 0,
	upgrade: bool = true,
	full_price: int = 0
) -> void:
	super(value, level, value_price, upgrade, full_price)
