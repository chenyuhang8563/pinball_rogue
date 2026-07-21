extends RefCounted

const NONE := 0
const BEFORE_MUTATION := 1
const AFTER_MUTATION := 2

var amount: int = 0
var revision_value: int = 0
var debit_failure: int = NONE
var credit_failure: int = NONE
var restore_fails: bool = false


func _init(starting_amount: int = 0) -> void:
	amount = starting_amount


func balance() -> int:
	return amount


func quote_price(item: Item) -> int:
	return item.price if item != null else 0


func quote_sell_price(item: Item) -> int:
	return floori(float(item.price) * 0.5) if item != null else 0


func can_debit(value: int) -> bool:
	return value >= 0 and amount >= value


func debit(value: int) -> bool:
	if debit_failure == BEFORE_MUTATION:
		return false
	amount -= value
	revision_value += 1
	return debit_failure != AFTER_MUTATION


func credit(value: int) -> bool:
	if value < 0 or credit_failure == BEFORE_MUTATION:
		return false
	amount += value
	revision_value += 1
	return credit_failure != AFTER_MUTATION


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
