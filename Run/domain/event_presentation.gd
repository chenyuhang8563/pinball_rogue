extends RefCounted
class_name EventPresentation

enum Phase {
	CHOICE,
	RESULT,
}

var token: RunFlowToken:
	get:
		return _token
var event_id: StringName:
	get:
		return _event_id
var phase: Phase:
	get:
		return _phase
var consumed: bool:
	get:
		return _consumed

var _token: RunFlowToken = null
var _event_id: StringName = &""
var _phase: Phase = Phase.CHOICE
var _option_ids: Array[StringName] = []
var _consumed: bool = false


func _init(
	value_token: RunFlowToken,
	value_event_id: StringName,
	value_phase: Phase,
	value_option_ids: Array[StringName]
) -> void:
	_token = value_token
	_event_id = value_event_id
	_phase = value_phase
	_option_ids = value_option_ids.duplicate()


func option_ids() -> Array[StringName]:
	return _option_ids.duplicate()


func has_option(option_id: StringName) -> bool:
	return _option_ids.has(option_id)


func is_valid() -> bool:
	return _token != null and _token.is_valid() and not _event_id.is_empty() \
		and not _option_ids.is_empty()


func _consume() -> void:
	_consumed = true
