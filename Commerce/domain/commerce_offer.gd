extends RefCounted

var offer_id: StringName = &""
var snapshot_version: int = 0
var item: Item = null
var item_identity: String = ""
var target_level: int = 0
var price: int = 0
var original_price: int = 0
var is_upgrade: bool = false
var consumed: bool = false
var inventory_revision: int = 0
var progression_revision: int = 0
var wallet_revision: int = 0
var health_revision: int = 0


func _init(
	value_offer_id: StringName = &"",
	value_snapshot_version: int = 0,
	value_item: Item = null,
	value_item_identity: String = "",
	value_target_level: int = 0,
	value_price: int = 0,
	value_original_price: int = 0,
	value_is_upgrade: bool = false,
	value_consumed: bool = false,
	value_inventory_revision: int = 0,
	value_progression_revision: int = 0,
	value_wallet_revision: int = 0,
	value_health_revision: int = 0
) -> void:
	offer_id = value_offer_id
	snapshot_version = value_snapshot_version
	item = value_item
	item_identity = value_item_identity
	target_level = value_target_level
	price = value_price
	original_price = value_original_price
	is_upgrade = value_is_upgrade
	consumed = value_consumed
	inventory_revision = value_inventory_revision
	progression_revision = value_progression_revision
	wallet_revision = value_wallet_revision
	health_revision = value_health_revision


func duplicate_view() -> RefCounted:
	return get_script().new(
		offer_id,
		snapshot_version,
		item,
		item_identity,
		target_level,
		price,
		original_price,
		is_upgrade,
		consumed,
		inventory_revision,
		progression_revision,
		wallet_revision,
		health_revision
	)
