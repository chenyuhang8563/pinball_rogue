extends RefCounted

var committed: bool = false
var rollback_completed: bool = true
var failed_step: int = -1

var _participants: Array = []
var _snapshots: Array[Dictionary] = []


func _init(participants: Array = []) -> void:
	_participants = participants.duplicate()


func execute(steps: Array[Callable]) -> bool:
	committed = false
	rollback_completed = true
	failed_step = -1
	_snapshots.clear()
	for participant: Variant in _participants:
		if participant == null or not participant.has_method("snapshot") \
				or not participant.has_method("restore"):
			failed_step = 0
			rollback_completed = false
			return false
		var state: Variant = participant.call("snapshot")
		if not state is Dictionary:
			failed_step = 0
			rollback_completed = false
			return false
		_snapshots.append((state as Dictionary).duplicate(true))
	for index: int in range(steps.size()):
		var step: Callable = steps[index]
		if not step.is_valid() or not bool(step.call()):
			failed_step = index
			rollback_completed = _rollback()
			return false
	committed = true
	return true


func _rollback() -> bool:
	var restored_all := true
	for index: int in range(_participants.size() - 1, -1, -1):
		if not bool(_participants[index].call("restore", _snapshots[index])):
			restored_all = false
	return restored_all
