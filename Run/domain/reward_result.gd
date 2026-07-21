extends RefCounted
class_name RewardResult

enum Code {
	GRANTED,
	DECLINED,
	STALE_TOKEN,
	UNKNOWN_OPTION,
	REJECTED,
	NOT_CONFIGURED,
	STALE_DRAFT,
	UNKNOWN_OFFER,
	OFFER_CONSUMED,
	DRAFT_CONSUMED,
	OWNERSHIP_CHANGED,
	LEVEL_CHANGED,
	CAPACITY_CHANGED,
	SKILL_REPLACEMENT_REQUIRED,
	INVALID_REPLACEMENT_TOKEN,
	COMMIT_FAILED,
	ROLLBACK_FAILED,
	REENTRANT,
	INVALID_DRAFT,
}

var token: RunFlowToken:
	get:
		return _token
var code: Code:
	get:
		return _code
var option: RewardOption:
	get:
		return _option
var detail: String:
	get:
		return _detail
var draft_id: StringName:
	get:
		return _draft_id
var offer_id: StringName:
	get:
		return _offer_id
var replacement_token: StringName:
	get:
		return _replacement_token
var committed: bool:
	get:
		return _committed
var rollback_completed: bool:
	get:
		return _rollback_completed
var granted_gold: int:
	get:
		return _granted_gold

var _token: RunFlowToken = null
var _code: Code = Code.REJECTED
var _option: RewardOption = null
var _detail: String = ""
var _draft_id: StringName = &""
var _offer_id: StringName = &""
var _replacement_token: StringName = &""
var _committed: bool = false
var _rollback_completed: bool = true
var _granted_gold: int = 0


func _init(
	value_token: RunFlowToken,
	value_code: Code,
	value_option: RewardOption = null,
	value_detail: String = "",
	value_draft_id: StringName = &"",
	value_offer_id: StringName = &"",
	value_replacement_token: StringName = &"",
	value_committed: bool = false,
	value_rollback_completed: bool = true,
	value_granted_gold: int = 0
) -> void:
	_token = value_token
	_code = value_code
	_option = value_option
	_detail = value_detail
	_draft_id = value_draft_id
	_offer_id = value_offer_id
	_replacement_token = value_replacement_token
	_committed = value_committed
	_rollback_completed = value_rollback_completed
	_granted_gold = maxi(0, value_granted_gold)


func was_granted() -> bool:
	return _code == Code.GRANTED


func replacement_required() -> bool:
	return _code == Code.SKILL_REPLACEMENT_REQUIRED and not _replacement_token.is_empty()
