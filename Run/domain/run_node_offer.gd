extends RefCounted
class_name RunNodeOffer

var token: RunFlowToken:
	get:
		return _token
var offer_id: StringName:
	get:
		return _offer_id
var floor_number: int:
	get:
		return _floor_number
var choice_wave_index: int:
	get:
		return _choice_wave_index
var consumed: bool:
	get:
		return _consumed

var _token: RunFlowToken = null
var _offer_id: StringName = &""
var _floor_number: int = 0
var _choice_wave_index: int = 0
var _choices: Array[RunNodeChoice] = []
var _consumed: bool = false


func _init(
	value_token: RunFlowToken,
	value_offer_id: StringName,
	value_floor_number: int,
	value_choice_wave_index: int,
	value_choices: Array[RunNodeChoice]
) -> void:
	_token = value_token
	_offer_id = value_offer_id
	_floor_number = value_floor_number
	_choice_wave_index = value_choice_wave_index
	_choices = value_choices.duplicate()


func choices() -> Array[RunNodeChoice]:
	return _choices.duplicate()


func options() -> Array[RunNodeChoice]:
	return choices()


func choice_by_id(option_id: StringName) -> RunNodeChoice:
	for choice: RunNodeChoice in _choices:
		if choice != null and choice.option_id == option_id:
			return choice
	return null


func is_valid() -> bool:
	if _token == null or not _token.is_valid() or _offer_id.is_empty() \
			or _floor_number < 2 or _choice_wave_index < 1 or _choices.size() != 3:
		return false
	var seen_kinds: Array[RunNodeOption.Kind] = []
	for choice: RunNodeChoice in _choices:
		if choice == null or not choice.is_valid() or seen_kinds.has(choice.kind):
			return false
		seen_kinds.append(choice.kind)
	return true


func _consume() -> void:
	_consumed = true
