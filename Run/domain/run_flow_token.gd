extends RefCounted
class_name RunFlowToken

var run_id: int:
	get:
		return _run_id
var node_id: int:
	get:
		return _node_id
var phase_id: int:
	get:
		return _phase_id

var _run_id: int = 0
var _node_id: int = 0
var _phase_id: int = 0


func _init(value_run_id: int, value_node_id: int, value_phase_id: int) -> void:
	_run_id = maxi(0, value_run_id)
	_node_id = maxi(0, value_node_id)
	_phase_id = maxi(0, value_phase_id)


func matches(other: RunFlowToken) -> bool:
	return other != null and _run_id == other.run_id \
		and _node_id == other.node_id and _phase_id == other.phase_id


func is_valid() -> bool:
	return _run_id > 0 and _node_id > 0 and _phase_id > 0
