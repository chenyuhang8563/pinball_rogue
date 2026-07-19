extends RefCounted
class_name RunEventResult

enum Code {
	RESOLVED,
	INSUFFICIENT_FUNDS,
	STALE_TOKEN,
	UNKNOWN_CHOICE,
	REJECTED,
}

var token: RunFlowToken:
	get:
		return _token
var event_id: StringName:
	get:
		return _event_id
var choice_id: StringName:
	get:
		return _choice_id
var code: Code:
	get:
		return _code
var roll: int:
	get:
		return _roll
var gold_delta: int:
	get:
		return _gold_delta
var battle_plan: BattlePlan:
	get:
		return _battle_plan

var _token: RunFlowToken = null
var _event_id: StringName = &""
var _choice_id: StringName = &""
var _code: Code = Code.REJECTED
var _roll: int = 0
var _gold_delta: int = 0
var _battle_plan: BattlePlan = null


func _init(
	value_token: RunFlowToken,
	value_event_id: StringName,
	value_choice_id: StringName,
	value_code: Code,
	value_roll: int = 0,
	value_gold_delta: int = 0,
	value_battle_plan: BattlePlan = null
) -> void:
	_token = value_token
	_event_id = value_event_id
	_choice_id = value_choice_id
	_code = value_code
	_roll = value_roll
	_gold_delta = value_gold_delta
	_battle_plan = value_battle_plan


func was_resolved() -> bool:
	return _code == Code.RESOLVED
