extends RefCounted
class_name RunEventOffer

var token: RunFlowToken:
	get:
		return _token
var event_id: StringName:
	get:
		return _event_id

var _token: RunFlowToken = null
var _event_id: StringName = &""
var _choices: Array[RunEventChoice] = []


func _init(
	value_token: RunFlowToken,
	value_event_id: StringName,
	value_choices: Array[RunEventChoice]
) -> void:
	_token = value_token
	_event_id = value_event_id
	_choices = value_choices.duplicate()


func choices() -> Array[RunEventChoice]:
	return _choices.duplicate()


func choice_by_id(choice_id: StringName) -> RunEventChoice:
	for choice: RunEventChoice in _choices:
		if choice != null and choice.choice_id == choice_id:
			return choice
	return null
