extends RefCounted
class_name RunNodeChoice

var option_id: StringName:
	get:
		return _option_id
var kind: RunNodeOption.Kind:
	get:
		return _kind
var kind_id: StringName:
	get:
		return _kind_id
var title: String:
	get:
		return _title
var description: String:
	get:
		return _description
var battle_plan: BattlePlan:
	get:
		return _battle_plan

var _option_id: StringName = &""
var _kind: RunNodeOption.Kind = RunNodeOption.Kind.BATTLE
var _kind_id: StringName = &""
var _title: String = ""
var _description: String = ""
var _battle_plan: BattlePlan = null


func _init(
	value_option_id: StringName,
	value_kind: RunNodeOption.Kind,
	value_kind_id: StringName,
	value_title: String,
	value_description: String = "",
	value_battle_plan: BattlePlan = null
) -> void:
	_option_id = value_option_id
	_kind = value_kind
	_kind_id = value_kind_id
	_title = value_title
	_description = value_description
	_battle_plan = value_battle_plan


func is_valid() -> bool:
	if _option_id.is_empty() or _kind_id.is_empty():
		return false
	if _kind == RunNodeOption.Kind.BATTLE or _kind == RunNodeOption.Kind.ELITE:
		return _battle_plan != null and _battle_plan.is_valid()
	return _battle_plan == null
