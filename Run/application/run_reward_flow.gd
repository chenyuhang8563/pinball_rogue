extends RefCounted
class_name RunRewardFlow

## Typed facade over RewardService. It owns draft identity, never RunState.
var _service: RewardService = null
var _active: RewardOffer = null
var _error_detail: String = ""


func configure(service: RewardService) -> bool:
	_service = service
	_active = null
	_error_detail = ""
	return _service != null


func active_offer() -> RewardOffer:
	return _active


func error_detail() -> String:
	return _error_detail


func present_battle(token: RunFlowToken, plan: BattlePlan) -> RewardOffer:
	_error_detail = ""
	if _service == null or token == null or plan == null:
		return _fail("reward flow is not configured")
	match plan.reward_policy:
		BattlePlan.RewardPolicy.NORMAL:
			_active = _service.create_normal_draft(token, plan.battle_id)
		BattlePlan.RewardPolicy.ELITE:
			_active = _service.create_elite_draft(token, plan.battle_id)
		_:
			return _fail("battle policy does not create a reward")
	if not _matches_presentation(token, plan.reward_policy):
		return _fail("reward service returned a mismatched draft")
	return _active


func present_node(token: RunFlowToken, source_id: StringName) -> RewardOffer:
	_error_detail = ""
	if _service == null or token == null or source_id.is_empty():
		return _fail("node reward request is invalid")
	_active = _service.create_node_draft(token, source_id)
	if _active == null or _active.token == null or not _active.token.matches(token):
		return _fail("reward service returned a mismatched node draft")
	return _active


func select(token: RunFlowToken, draft_id: StringName, offer_id: StringName) -> RewardResult:
	if not _valid_offer_intent(token, draft_id, offer_id):
		return null
	return _service.claim(token, draft_id, offer_id)


func confirm_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	if not _valid_replacement_intent(token, replacement_token):
		return null
	return _service.confirm_replacement(token, replacement_token)


func cancel_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	if not _valid_replacement_intent(token, replacement_token):
		return null
	return _service.cancel_replacement(token, replacement_token)


func pending_replacement_token() -> StringName:
	return _service.pending_replacement_token() if _service != null else &""


func completed() -> bool:
	return _active != null and _active.completed


func clear() -> bool:
	_active = null
	return _service != null and _service.clear_active()


func _valid_offer_intent(
	token: RunFlowToken,
	draft_id: StringName,
	offer_id: StringName
) -> bool:
	_error_detail = ""
	if _active == null or _active.consumed or _active.token == null \
			or token == null or not _active.token.matches(token) \
			or draft_id.is_empty() or draft_id != _active.draft_id:
		_error_detail = "reward draft identity is not active"
		return false
	if _active.offer_by_id(offer_id) == null:
		_error_detail = "reward offer does not belong to draft"
		return false
	return true


func _valid_replacement_intent(token: RunFlowToken, replacement_token: StringName) -> bool:
	_error_detail = ""
	if _active == null or _active.token == null or token == null \
			or not _active.token.matches(token) or replacement_token.is_empty() \
			or replacement_token != pending_replacement_token():
		_error_detail = "replacement token is not pending for active draft"
		return false
	return true


func _matches_presentation(token: RunFlowToken, policy: BattlePlan.RewardPolicy) -> bool:
	return _active != null and _active.token != null and _active.token.matches(token) \
		and _active.policy == policy


func _fail(detail: String) -> RewardOffer:
	_error_detail = detail
	_active = null
	return null
