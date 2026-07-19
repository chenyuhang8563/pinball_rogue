extends RefCounted
class_name RunState

enum Phase {
	IDLE,
	CHOOSING_NODE,
	BATTLE_ACTIVE,
	REWARD_ACTIVE,
	EVENT_ACTIVE,
	EVENT_RESULT_ACTIVE,
	UPGRADE_ACTIVE,
	NORMAL_SHOP_ACTIVE,
	DEVIL_SHOP_ACTIVE,
	FAILED,
	COMPLETED,
}

var phase: Phase:
	get:
		return _phase
var run_id: int:
	get:
		return _run_id
var floor_number: int:
	get:
		return _floor_number
var node_id: int:
	get:
		return _node_id
var node_kind: StringName:
	get:
		return _node_kind
var phase_id: int:
	get:
		return _phase_id
var battle_origin: BattlePlan.Origin:
	get:
		return _battle_origin
var reward_policy: BattlePlan.RewardPolicy:
	get:
		return _reward_policy
var battle_plan: BattlePlan:
	get:
		return _battle_plan

var _phase: Phase = Phase.IDLE
var _run_id: int = 0
var _floor_number: int = 0
var _node_id: int = 0
var _node_kind: StringName = &""
var _phase_id: int = 0
var _battle_origin: BattlePlan.Origin = BattlePlan.Origin.NODE
var _reward_policy: BattlePlan.RewardPolicy = BattlePlan.RewardPolicy.NONE
var _battle_plan: BattlePlan = null


func begin_run() -> bool:
	if _run_id > 0 and not is_terminal():
		return false
	_run_id += 1
	_floor_number = 0
	_node_id = 0
	_node_kind = &""
	_phase_id = 0
	_battle_plan = null
	_battle_origin = BattlePlan.Origin.NODE
	_reward_policy = BattlePlan.RewardPolicy.NONE
	_phase = Phase.IDLE
	return true


func advance_to_node(node_kind_value: StringName) -> bool:
	if not _can_advance_node() or node_kind_value.is_empty():
		return false
	_floor_number += 1
	_node_id += 1
	_node_kind = node_kind_value
	_battle_plan = null
	_battle_origin = BattlePlan.Origin.NODE
	_reward_policy = BattlePlan.RewardPolicy.NONE
	return _present(Phase.CHOOSING_NODE)


func begin_battle(plan: BattlePlan) -> bool:
	if (_phase != Phase.CHOOSING_NODE and _phase != Phase.EVENT_ACTIVE) \
		or not _can_present() or plan == null or not plan.is_valid():
		return false
	_battle_plan = plan
	_battle_origin = plan.origin
	_reward_policy = plan.reward_policy
	return _present(Phase.BATTLE_ACTIVE)


func present_reward() -> bool:
	if _phase != Phase.BATTLE_ACTIVE and _phase != Phase.CHOOSING_NODE:
		return false
	return _present(Phase.REWARD_ACTIVE)


func present_event() -> bool:
	return _present_from_choice(Phase.EVENT_ACTIVE)


func present_event_result() -> bool:
	if _phase != Phase.EVENT_ACTIVE:
		return false
	return _present(Phase.EVENT_RESULT_ACTIVE)


func present_upgrade() -> bool:
	return _present_from_choice(Phase.UPGRADE_ACTIVE)


func present_normal_shop() -> bool:
	return _present_from_choice(Phase.NORMAL_SHOP_ACTIVE)


func present_devil_shop() -> bool:
	return _present_from_choice(Phase.DEVIL_SHOP_ACTIVE)


func fail() -> bool:
	if not _can_present():
		return false
	return _present(Phase.FAILED)


func complete() -> bool:
	if not _can_present():
		return false
	return _present(Phase.COMPLETED)


func token() -> RunFlowToken:
	return RunFlowToken.new(_run_id, _node_id, _phase_id)


func accepts(candidate: RunFlowToken) -> bool:
	return candidate != null and token().matches(candidate) and not is_terminal()


func is_terminal() -> bool:
	return _phase == Phase.FAILED or _phase == Phase.COMPLETED


func _present_from_choice(next_phase: Phase) -> bool:
	if _phase != Phase.CHOOSING_NODE:
		return false
	return _present(next_phase)


func _present(next_phase: Phase) -> bool:
	if not _can_present():
		return false
	_phase = next_phase
	_phase_id += 1
	return true


func _can_present() -> bool:
	return _run_id > 0 and _node_id > 0 and not is_terminal()


func _can_advance_node() -> bool:
	if _run_id <= 0 or is_terminal():
		return false
	return _phase == Phase.IDLE or _phase == Phase.REWARD_ACTIVE \
		or _phase == Phase.EVENT_RESULT_ACTIVE or _phase == Phase.UPGRADE_ACTIVE \
		or _phase == Phase.NORMAL_SHOP_ACTIVE or _phase == Phase.DEVIL_SHOP_ACTIVE
