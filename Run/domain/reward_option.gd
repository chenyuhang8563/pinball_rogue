extends RefCounted
class_name RewardOption

enum Kind {
	GOLD,
	ITEM,
}

enum Resolution {
	CREDIT_GOLD,
	ADD_ITEM,
	UPGRADE_RELIC,
	COMPENSATE,
	REPLACE_SKILL,
}

var offer_id: StringName:
	get:
		return _offer_id
var kind: Kind:
	get:
		return _kind
var item: Item:
	get:
		return _item
var gold_amount: int:
	get:
		return _gold_amount
var item_identity: String:
	get:
		return _item_identity
var resolution: Resolution:
	get:
		return _resolution
var compensation_amount: int:
	get:
		return _compensation_amount
var consumed: bool:
	get:
		return _consumed
var inventory_revision: int:
	get:
		return _inventory_revision
var progression_revision: int:
	get:
		return _progression_revision
var wallet_revision: int:
	get:
		return _wallet_revision
var expected_owned_instance_id: int:
	get:
		return _expected_owned_instance_id
var expected_owned_identity: String:
	get:
		return _expected_owned_identity
var expected_level: int:
	get:
		return _expected_level

var _offer_id: StringName = &""
var _kind: Kind = Kind.GOLD
var _item: Item = null
var _gold_amount: int = 0
var _item_identity: String = ""
var _resolution: Resolution = Resolution.CREDIT_GOLD
var _compensation_amount: int = 0
var _consumed: bool = false
var _inventory_revision: int = 0
var _progression_revision: int = 0
var _wallet_revision: int = 0
var _expected_owned_instance_id: int = 0
var _expected_owned_identity: String = ""
var _expected_level: int = 0


func _init(
	value_option_id: StringName,
	value_kind: Kind,
	value_item: Item = null,
	value_gold_amount: int = 0,
	value_item_identity: String = "",
	value_resolution: Resolution = Resolution.CREDIT_GOLD,
	value_compensation_amount: int = 0
) -> void:
	_offer_id = value_option_id
	_kind = value_kind
	_item = value_item
	_gold_amount = maxi(0, value_gold_amount)
	_item_identity = value_item_identity
	_resolution = value_resolution
	_compensation_amount = maxi(0, value_compensation_amount)


static func gold(value_option_id: StringName, amount: int) -> RewardOption:
	return RewardOption.new(value_option_id, Kind.GOLD, null, amount)


static func item_reward(value_option_id: StringName, value_item: Item) -> RewardOption:
	return RewardOption.new(value_option_id, Kind.ITEM, value_item)


func is_valid() -> bool:
	if _offer_id.is_empty():
		return false
	return (_kind == Kind.GOLD and _gold_amount > 0) or (_kind == Kind.ITEM and _item != null)


func _configure_settlement(
	value_item_identity: String,
	value_resolution: Resolution,
	value_compensation_amount: int,
	value_inventory_revision: int,
	value_progression_revision: int,
	value_wallet_revision: int,
	value_owned_instance_id: int,
	value_owned_identity: String,
	value_expected_level: int
) -> void:
	_item_identity = value_item_identity
	_resolution = value_resolution
	_compensation_amount = maxi(0, value_compensation_amount)
	_refresh_revisions(value_inventory_revision, value_progression_revision, value_wallet_revision)
	_expected_owned_instance_id = value_owned_instance_id
	_expected_owned_identity = value_owned_identity
	_expected_level = value_expected_level


func _refresh_revisions(
	value_inventory_revision: int,
	value_progression_revision: int,
	value_wallet_revision: int
) -> void:
	_inventory_revision = value_inventory_revision
	_progression_revision = value_progression_revision
	_wallet_revision = value_wallet_revision


func _mark_consumed() -> void:
	_consumed = true
