extends "res://Commerce/domain/commerce_offer.gd"
class_name ShopOffer

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")


func _init(value: Item = null, level: int = 0, value_price: int = 0, upgrade: bool = true, full_price: int = 0) -> void:
	var resolved_original_price := full_price if full_price > 0 else value_price
	super(
		&"",
		0,
		value,
		ItemIdentityScript.key(value),
		level,
		value_price,
		resolved_original_price,
		upgrade
	)


func duplicate_view() -> RefCounted:
	var view: RefCounted = get_script().new(item, target_level, price, is_upgrade, original_price)
	view.set("offer_id", offer_id)
	view.set("snapshot_version", snapshot_version)
	view.set("item_identity", item_identity)
	view.set("consumed", consumed)
	view.set("inventory_revision", inventory_revision)
	view.set("progression_revision", progression_revision)
	view.set("wallet_revision", wallet_revision)
	view.set("health_revision", health_revision)
	return view
