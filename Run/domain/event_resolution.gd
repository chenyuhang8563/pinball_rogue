extends RefCounted
class_name EventResolution

enum Code {
	RESOLVED,
	NOT_CONFIGURED,
	NO_ACTIVE_SESSION,
	STALE_TOKEN,
	STALE_PRESENTATION,
	UNKNOWN_EVENT,
	UNKNOWN_OPTION,
	INTENT_MISMATCH,
	INSUFFICIENT_FUNDS,
	INVALID_ROLL,
	COMMIT_FAILED,
	ROLLBACK_FAILED,
	REENTRANT,
}

# Failed outcomes use -1. Successful outcomes are deliberately restricted to
# these orchestration requests; the resolver never advances RunState itself.
enum Action {
	SHOW_RESULT,
	START_EVENT_BATTLE,
	ADVANCE_NODE,
}

var code: Code
var action: int
var token: RunFlowToken
var event_id: StringName
var option_id: StringName
var roll: int
var gold_delta: int
var presentation: EventPresentation
var rollback_completed: bool
var detail: String


func _init(
	value_code: Code,
	value_action: int = -1,
	value_token: RunFlowToken = null,
	value_event_id: StringName = &"",
	value_option_id: StringName = &"",
	value_roll: int = 0,
	value_gold_delta: int = 0,
	value_presentation: EventPresentation = null,
	value_rollback_completed: bool = true,
	value_detail: String = ""
) -> void:
	code = value_code
	action = value_action
	token = value_token
	event_id = value_event_id
	option_id = value_option_id
	roll = value_roll
	gold_delta = value_gold_delta
	presentation = value_presentation
	rollback_completed = value_rollback_completed
	detail = value_detail


func was_resolved() -> bool:
	return code == Code.RESOLVED
