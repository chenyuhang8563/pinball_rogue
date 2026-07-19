extends RefCounted

signal changed(value: int)

var _current: int = 10
var _minimum_remaining: int = 1


func _init(initial_value: int = 10, minimum: int = 1) -> void:
	_minimum_remaining = maxi(1, minimum)
	_current = maxi(0, initial_value)


func current() -> int:
	return _current


func set_current(value: int) -> bool:
	if value < 0:
		return false
	if _current == value:
		return true
	_current = value
	changed.emit(_current)
	return true


func minimum_remaining() -> int:
	return _minimum_remaining


func can_debit(amount: int) -> bool:
	return amount >= 0 and _current - amount >= _minimum_remaining


func debit(amount: int) -> bool:
	return can_debit(amount) and set_current(_current - amount)


func damage(amount: int) -> bool:
	return amount >= 0 and set_current(maxi(0, _current - amount))


func credit(amount: int) -> bool:
	return amount >= 0 and set_current(_current + amount)


func snapshot() -> Dictionary:
	return {
		&"current": _current,
		&"minimum_remaining": _minimum_remaining,
		&"revision": revision(),
	}


func restore(state: Dictionary) -> bool:
	if not state.has(&"current"):
		return false
	return set_current(int(state[&"current"])) \
		and revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	return {&"current": _current, &"minimum_remaining": _minimum_remaining}.hash()


func reset(value: int) -> bool:
	return set_current(value)
