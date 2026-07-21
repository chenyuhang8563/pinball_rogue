extends RefCounted
class_name UpgradeResult

enum Code {
	UPGRADED,
	UNAVAILABLE_ACKNOWLEDGED,
	STALE_TOKEN,
	STALE_OFFER,
	UNKNOWN_CANDIDATE,
	OWNERSHIP_CHANGED,
	LEVEL_CHANGED,
	COMMIT_FAILED,
}

var token: RunFlowToken
var code: Code
var offer_id: StringName
var candidate_id: StringName
var item: Item
var previous_level: int
var current_level: int
var detail: String


func _init(
	value_token: RunFlowToken,
	value_code: Code,
	value_offer_id: StringName,
	value_candidate_id: StringName = &"",
	value_item: Item = null,
	value_previous_level: int = 0,
	value_current_level: int = 0,
	value_detail: String = ""
) -> void:
	token = value_token
	code = value_code
	offer_id = value_offer_id
	candidate_id = value_candidate_id
	item = value_item
	previous_level = value_previous_level
	current_level = value_current_level
	detail = value_detail


func succeeded() -> bool:
	return code == Code.UPGRADED or code == Code.UNAVAILABLE_ACKNOWLEDGED
