extends RefCounted
class_name RunEventChoice

enum Kind {
	FINISH,
	WAGER,
	BATTLE,
}

var choice_id: StringName:
	get:
		return _choice_id
var kind: Kind:
	get:
		return _kind
var cost: int:
	get:
		return _cost
var reward: int:
	get:
		return _reward
var battle_plan: BattlePlan:
	get:
		return _battle_plan

var _choice_id: StringName = &""
var _kind: Kind = Kind.FINISH
var _cost: int = 0
var _reward: int = 0
var _battle_plan: BattlePlan = null


func _init(
	value_choice_id: StringName,
	value_kind: Kind,
	value_cost: int = 0,
	value_reward: int = 0,
	value_battle_plan: BattlePlan = null
) -> void:
	_choice_id = value_choice_id
	_kind = value_kind
	_cost = maxi(0, value_cost)
	_reward = maxi(0, value_reward)
	_battle_plan = value_battle_plan


func is_valid() -> bool:
	if _choice_id.is_empty():
		return false
	if _kind == Kind.BATTLE:
		return _battle_plan != null and _battle_plan.is_valid()
	return true
