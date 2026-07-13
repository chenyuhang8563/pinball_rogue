extends RefCounted
class_name DevilShopOffer

var item: Item
var target_level: int
var price: int


func _init(value: Item = null, level: int = 0, value_price: int = 0) -> void:
	item = value
	target_level = level
	price = value_price
