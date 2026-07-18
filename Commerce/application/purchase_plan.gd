extends RefCounted

var committed: bool = false
var rollback_completed: bool = true
var failed_step: int = -1

var _adapters: Array = []
var _snapshots: Array = []


func _init(adapters: Array = []) -> void:
	_adapters = adapters.duplicate()


func execute(commit_steps: Array[Callable]) -> bool:
	committed = false
	rollback_completed = true
	failed_step = -1
	_snapshots.clear()
	for adapter: Variant in _adapters:
		if adapter == null or not adapter.has_method("snapshot") or not adapter.has_method("restore"):
			failed_step = 0
			rollback_completed = false
			return false
		_snapshots.append(adapter.call("snapshot"))
	for index: int in range(commit_steps.size()):
		var step: Callable = commit_steps[index]
		if not step.is_valid() or not bool(step.call()):
			failed_step = index
			rollback_completed = _restore_all()
			return false
	committed = true
	return true


func run(commit_steps: Array[Callable]) -> bool:
	return execute(commit_steps)


func _restore_all() -> bool:
	var restored_all := true
	for index: int in range(_adapters.size() - 1, -1, -1):
		var restored := bool(_adapters[index].call("restore", _snapshots[index]))
		if not restored:
			restored_all = false
	return restored_all
