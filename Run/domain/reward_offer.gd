extends RefCounted
class_name RewardOffer

enum Mode {
	NODE_EXCLUSIVE,
	NORMAL_EXCLUSIVE,
	ELITE_CLAIM_ALL,
}

var token: RunFlowToken:
	get:
		return _token
var policy: BattlePlan.RewardPolicy:
	get:
		return _policy
var source_id: StringName:
	get:
		return _source_id
var draft_id: StringName:
	get:
		return _draft_id
var mode: Mode:
	get:
		return _mode
var inventory_revision: int:
	get:
		return _inventory_revision
var progression_revision: int:
	get:
		return _progression_revision
var wallet_revision: int:
	get:
		return _wallet_revision
var consumed: bool:
	get:
		return _consumed
var completed: bool:
	get:
		return _consumed

var _token: RunFlowToken = null
var _policy: BattlePlan.RewardPolicy = BattlePlan.RewardPolicy.NONE
var _source_id: StringName = &""
var _draft_id: StringName = &""
var _mode: Mode = Mode.NODE_EXCLUSIVE
var _inventory_revision: int = 0
var _progression_revision: int = 0
var _wallet_revision: int = 0
var _consumed: bool = false
var _options: Array[RewardOption] = []


func _init(
	value_token: RunFlowToken,
	value_policy: BattlePlan.RewardPolicy,
	value_source_id: StringName,
	value_options: Array[RewardOption],
	value_draft_id: StringName = &"",
	value_mode: Mode = Mode.NODE_EXCLUSIVE,
	value_inventory_revision: int = 0,
	value_progression_revision: int = 0,
	value_wallet_revision: int = 0
) -> void:
	_token = value_token
	_policy = value_policy
	_source_id = value_source_id
	_options = value_options.duplicate()
	_draft_id = value_draft_id
	_mode = value_mode
	_inventory_revision = value_inventory_revision
	_progression_revision = value_progression_revision
	_wallet_revision = value_wallet_revision


func options() -> Array[RewardOption]:
	return _options.duplicate()


func option_by_id(option_id: StringName) -> RewardOption:
	for option: RewardOption in _options:
		if option != null and option.offer_id == option_id:
			return option
	return null


func offer_by_id(offer_id: StringName) -> RewardOption:
	return option_by_id(offer_id)


func remaining_options() -> Array[RewardOption]:
	var result: Array[RewardOption] = []
	for option: RewardOption in _options:
		if option != null and not option.consumed:
			result.append(option)
	return result


func _refresh_revisions(
	value_inventory_revision: int,
	value_progression_revision: int,
	value_wallet_revision: int
) -> void:
	_inventory_revision = value_inventory_revision
	_progression_revision = value_progression_revision
	_wallet_revision = value_wallet_revision


func _mark_completed() -> void:
	_consumed = true
