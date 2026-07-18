extends RefCounted

enum Code {
	SUCCESS,
	NOT_CONFIGURED,
	UNKNOWN_OFFER,
	STALE_SNAPSHOT,
	OFFER_CONSUMED,
	INSUFFICIENT_FUNDS,
	MINIMUM_HEALTH_VIOLATED,
	OWNERSHIP_CHANGED,
	LEVEL_CHANGED,
	CAPACITY_CHANGED,
	SKILL_REPLACEMENT_REQUIRED,
	PAYMENT_NOT_SELECTED,
	INVALID_PAYMENT,
	COMMIT_FAILED,
	ROLLBACK_FAILED,
}

var code: Code = Code.SUCCESS
var committed: bool = false
var rollback_completed: bool = true
var offer_id: StringName = &""
var snapshot_version: int = 0
var balance_before: int = 0
var balance_after: int = 0
var health_before: int = 0
var health_after: int = 0
var item_identity: String = ""
var detail: String = ""


func _init(value_code: Code = Code.SUCCESS) -> void:
	code = value_code


static func success(
	value_offer_id: StringName = &"",
	value_snapshot_version: int = 0,
	value_balance_before: int = 0,
	value_balance_after: int = 0,
	value_health_before: int = 0,
	value_health_after: int = 0,
	value_item_identity: String = "",
	value_detail: String = ""
) -> RefCounted:
	var result: RefCounted = new(Code.SUCCESS)
	result.committed = true
	result.rollback_completed = true
	result.offer_id = value_offer_id
	result.snapshot_version = value_snapshot_version
	result.balance_before = value_balance_before
	result.balance_after = value_balance_after
	result.health_before = value_health_before
	result.health_after = value_health_after
	result.item_identity = value_item_identity
	result.detail = value_detail
	return result


static func failure(
	value_code: Code,
	value_offer_id: StringName = &"",
	value_snapshot_version: int = 0,
	value_detail: String = "",
	value_balance_before: int = 0,
	value_balance_after: int = 0,
	value_health_before: int = 0,
	value_health_after: int = 0,
	value_item_identity: String = "",
	value_rollback_completed: bool = true
) -> RefCounted:
	var result: RefCounted = new(value_code)
	result.committed = false
	result.rollback_completed = value_rollback_completed
	result.offer_id = value_offer_id
	result.snapshot_version = value_snapshot_version
	result.balance_before = value_balance_before
	result.balance_after = value_balance_after
	result.health_before = value_health_before
	result.health_after = value_health_after
	result.item_identity = value_item_identity
	result.detail = value_detail
	return result
