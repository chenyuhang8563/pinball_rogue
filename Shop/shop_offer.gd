extends RefCounted
class_name ShopOffer

## 商店中的新物品或升级报价。
var item: Item
var target_level: int
var price: int
var original_price: int
var is_upgrade: bool


func _init(value: Item = null, level: int = 0, value_price: int = 0, upgrade: bool = true, full_price: int = 0) -> void:
	item = value
	target_level = level
	price = value_price
	original_price = full_price if full_price > 0 else value_price
	is_upgrade = upgrade
