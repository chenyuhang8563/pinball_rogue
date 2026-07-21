extends "res://Commerce/domain/shop_offer.gd"
class_name DevilShopOffer


func _init(
	value: Item = null,
	level: int = 0,
	value_price: int = 0,
	upgrade: bool = true,
	full_price: int = 0
) -> void:
	super(value, level, value_price, upgrade, full_price)


static func from_commerce(view: Variant) -> DevilShopOffer:
	if view == null or not view is Object:
		return null
	var source := view as Object
	var wrapper := DevilShopOffer.new(
		source.get("item") as Item,
		int(source.get("target_level")),
		int(source.get("price")),
		bool(source.get("is_upgrade")),
		int(source.get("original_price"))
	)
	wrapper.offer_id = StringName(source.get("offer_id"))
	wrapper.snapshot_version = int(source.get("snapshot_version"))
	wrapper.item_identity = String(source.get("item_identity"))
	wrapper.consumed = bool(source.get("consumed"))
	wrapper.inventory_revision = int(source.get("inventory_revision"))
	wrapper.progression_revision = int(source.get("progression_revision"))
	wrapper.wallet_revision = int(source.get("wallet_revision"))
	wrapper.health_revision = int(source.get("health_revision"))
	return wrapper
