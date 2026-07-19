extends RefCounted

const NONE := 0
const BEFORE_MUTATION := 1
const AFTER_MUTATION := 2

var amount: int = 0
var revision_value: int = 0
var debit_failure: int = NONE
var restore_fails: bool = false


func _init(starting_amount: int = 0) -> void:
	amount = starting_amount


func current() -> int:
	return amount


func can_debit(value: int) -> bool:
	return value >= 0 and amount >= value


func debit(value: int) -> bool:
	if debit_failure == BEFORE_MUTATION:
		return false
	amount -= value
	revision_value += 1
	return debit_failure != AFTER_MUTATION


func revision() -> int:
	return revision_value


func bump_revision() -> void:
	revision_value += 1


func snapshot() -> Dictionary:
	return {&"amount": amount, &"revision": revision_value}


func restore(state: Dictionary) -> bool:
	if restore_fails:
		return false
	amount = int(state[&"amount"])
	revision_value = int(state[&"revision"])
	return true
