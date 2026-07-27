class_name ShopRefreshResult
extends RefCounted

enum Code {
	SUCCESS,
	NOT_CONFIGURED,
	EMPTY_CANDIDATES,
	INSUFFICIENT_FUNDS,
	PAYMENT_FAILED,
}

var code: Code = Code.SUCCESS
var committed: bool = false
var rollback_completed: bool = true
var cost: int = 0
var balance_before: int = 0
var balance_after: int = 0
var offers: Array = []


func _init(value_code: Code = Code.SUCCESS) -> void:
	code = value_code


static func success(
	value_cost: int,
	value_balance_before: int,
	value_balance_after: int,
	value_offers: Array
) -> RefCounted:
	var result := ShopRefreshResult.new(Code.SUCCESS)
	result.committed = true
	result.cost = value_cost
	result.balance_before = value_balance_before
	result.balance_after = value_balance_after
	result.offers = value_offers.duplicate()
	return result


static func failure(
	value_code: Code,
	value_cost: int,
	value_balance_before: int,
	value_balance_after: int,
	value_rollback_completed: bool = true
) -> RefCounted:
	var result := ShopRefreshResult.new(value_code)
	result.committed = false
	result.rollback_completed = value_rollback_completed
	result.cost = value_cost
	result.balance_before = value_balance_before
	result.balance_after = value_balance_after
	return result
