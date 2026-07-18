extends RefCounted

var _stat_system: Object = null
var _stat_id: String = ""
var _entity_id: String = ""
var _minimum: int = 1


func _init(
	stat_system: Object = null,
	stat_id: String = "",
	entity_id: String = "",
	minimum: int = 1
) -> void:
	_stat_system = stat_system
	_stat_id = stat_id
	_entity_id = entity_id
	_minimum = minimum


func current() -> int:
	if not _is_available() or not _stat_system.has_method("get_stat"):
		return 0
	return int(_stat_system.call("get_stat", _stat_id, _entity_id))


func minimum_remaining() -> int:
	return _minimum


func can_debit(amount: int) -> bool:
	return amount >= 0 and _is_available() and current() - amount >= _minimum


func debit(amount: int) -> bool:
	if not can_debit(amount):
		return false
	var expected := current() - amount
	return _write_current(expected) and current() == expected


func credit(amount: int) -> bool:
	if amount < 0 or not _is_available():
		return false
	var expected := current() + amount
	return _write_current(expected) and current() == expected


func snapshot() -> Dictionary:
	return {&"current": current(), &"revision": revision()} if _is_available() else {}


func restore(state: Dictionary) -> bool:
	if not _is_available() or not state.has(&"current"):
		return false
	var expected := int(state[&"current"])
	return _write_current(expected) and current() == expected


func revision() -> int:
	return {&"current": current()}.hash() if _is_available() else 0


func _write_current(value: int) -> bool:
	if not _is_available() or not _stat_system.has_method("set_stat_base"):
		return false
	_stat_system.call("set_stat_base", _entity_id, _stat_id, float(value))
	return true


func _is_available() -> bool:
	return _stat_system != null and is_instance_valid(_stat_system) and _stat_id != ""
