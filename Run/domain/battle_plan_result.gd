extends RefCounted
class_name BattlePlanResult

enum Code {
	NONE,
	INVALID_FLOOR,
	INVALID_ORIGIN,
	INVALID_FLOOR_CONFIG,
	INVALID_RANDOM_SOURCE,
	INVALID_CONTENT,
	BUILD_FAILED,
}

var plan: BattlePlan:
	get:
		return _plan
var error: Code:
	get:
		return _error
var message: String:
	get:
		return _message

var _plan: BattlePlan = null
var _error: Code = Code.NONE
var _message: String = ""


func _init(value_plan: BattlePlan, value_error: Code, value_message: String = "") -> void:
	_plan = value_plan
	_error = value_error
	_message = value_message


func is_ok() -> bool:
	return _error == Code.NONE and _plan != null and _plan.is_valid()


static func ok(value_plan: BattlePlan) -> BattlePlanResult:
	return BattlePlanResult.new(value_plan, Code.NONE)


static func failure(value_error: Code, value_message: String) -> BattlePlanResult:
	return BattlePlanResult.new(null, value_error, value_message)
