extends RefCounted
class_name StatModifier

enum ModOp {
	ADD,
	MULTIPLY,
	OVERRIDE,
}

var id: String = ""
var stat_id: String = ""
var operation: ModOp = ModOp.ADD
var value: float = 0.0
var source: String = ""
var duration: float = -1.0
var remaining_time: float = -1.0


func _init(
	p_id: String = "",
	p_stat_id: String = "",
	p_operation: ModOp = ModOp.ADD,
	p_value: float = 0.0,
	p_source: String = "",
	p_duration: float = -1.0
) -> void:
	id = p_id
	stat_id = p_stat_id
	operation = p_operation
	value = p_value
	source = p_source
	duration = p_duration
	remaining_time = p_duration


func is_timed() -> bool:
	return duration >= 0.0


func tick(delta: float) -> void:
	if not is_timed():
		return
	remaining_time -= delta


func is_expired() -> bool:
	return is_timed() and remaining_time <= 0.0
