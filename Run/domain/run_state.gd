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


## The sole run-identity mutation. A live run cannot be replaced; restart is
## admitted only after FAILED/COMPLETED so callers cannot silently discard it.
func begin_run() -> bool:
	if _run_id > 0 and not is_terminal():
		return false
	_run_id += 1
	_floor_number = 0
	_node_id = 0
	_node_kind = &""
	_phase_id = 0
	_clear_battle()
	_phase = Phase.IDLE
	return true


## Commits floor/node identity and the mandatory first battle in one state
## operation. The controller builds the plan before exposing this transition.
func begin_first_battle(plan: BattlePlan) -> bool:
	if _phase != Phase.IDLE or _run_id <= 0 or _floor_number != 0 or _node_id != 0 \
			or plan == null or not plan.is_valid() or plan.origin != BattlePlan.Origin.RUN_START:
		return false
	_floor_number = 1
	_node_id = 1
	_node_kind = &"battle"
	_set_battle(plan)
	return _transition(Phase.BATTLE_ACTIVE)


## Advances floor and node together. The selected kind is deliberately empty
## until select_node() commits kind + target phase in one operation.
func advance_to_node() -> bool:
	if not _can_advance_node():
		return false
	_floor_number += 1
	_node_id += 1
	_node_kind = &""
	_clear_battle()
	return _transition(Phase.CHOOSING_NODE)


## Boss bypass: advances floor/node and enters its prebuilt battle without a
## transient CHOOSING_NODE presentation.
func advance_to_battle(node_kind_value: StringName, plan: BattlePlan) -> bool:
	if not _can_advance_node() or node_kind_value.is_empty() \
			or plan == null or not plan.is_valid():
		return false
	_floor_number += 1
	_node_id += 1
	_node_kind = node_kind_value
	_set_battle(plan)
	return _transition(Phase.BATTLE_ACTIVE)


## Commits the business selection and its target presentation as one phase
## identity change. Battle choices must supply their already-built plan.
func select_node(
	node_kind_value: StringName,
	target_phase: Phase,
	plan: BattlePlan = null
) -> bool:
	if _phase != Phase.CHOOSING_NODE or node_kind_value.is_empty():
		return false
	if target_phase not in [
		Phase.BATTLE_ACTIVE,
		Phase.REWARD_ACTIVE,
		Phase.EVENT_ACTIVE,
		Phase.UPGRADE_ACTIVE,
		Phase.NORMAL_SHOP_ACTIVE,
		Phase.DEVIL_SHOP_ACTIVE,
	]:
		return false
	if target_phase == Phase.BATTLE_ACTIVE:
		if plan == null or not plan.is_valid() or plan.origin != BattlePlan.Origin.NODE:
			return false
		_set_battle(plan)
	else:
		if plan != null:
			return false
		_clear_battle()
	_node_kind = node_kind_value
	return _transition(target_phase)


func begin_battle(plan: BattlePlan, selected_kind: StringName = &"") -> bool:
	if plan == null or not plan.is_valid():
		return false
	if _phase == Phase.EVENT_ACTIVE:
		if plan.origin != BattlePlan.Origin.EVENT:
			return false
		_set_battle(plan)
		return _transition(Phase.BATTLE_ACTIVE)
	if _phase != Phase.CHOOSING_NODE:
		return false
	var kind := selected_kind
	if kind.is_empty():
		kind = &"elite" if plan.reward_policy == BattlePlan.RewardPolicy.ELITE else &"battle"
	return select_node(kind, Phase.BATTLE_ACTIVE, plan)


func present_reward(selected_kind: StringName = &"reward") -> bool:
	if _phase == Phase.BATTLE_ACTIVE:
		if _reward_policy == BattlePlan.RewardPolicy.NONE:
			return false
		return _transition(Phase.REWARD_ACTIVE)
	return select_node(selected_kind, Phase.REWARD_ACTIVE)


func present_event() -> bool:
	return select_node(&"event", Phase.EVENT_ACTIVE)


func present_event_result() -> bool:
	if _phase != Phase.EVENT_ACTIVE:
		return false
	return _transition(Phase.EVENT_RESULT_ACTIVE)


func present_upgrade() -> bool:
	return select_node(&"upgrade", Phase.UPGRADE_ACTIVE)


func present_normal_shop() -> bool:
	return select_node(&"shop", Phase.NORMAL_SHOP_ACTIVE)


func present_devil_shop() -> bool:
	return select_node(&"devil_shop", Phase.DEVIL_SHOP_ACTIVE)


func fail() -> bool:
	if _run_id <= 0 or is_terminal():
		return false
	return _transition(Phase.FAILED)


## Run completion is a boss-battle-only transition. A NONE policy on any other
## plan is not sufficient to complete the run.
func complete() -> bool:
	if _phase != Phase.BATTLE_ACTIVE or _battle_plan == null \
			or _battle_origin != BattlePlan.Origin.BOSS \
			or _reward_policy != BattlePlan.RewardPolicy.NONE:
		return false
	return _transition(Phase.COMPLETED)


func token() -> RunFlowToken:
	return RunFlowToken.new(_run_id, _node_id, _phase_id)


func matches(candidate: RunFlowToken) -> bool:
	return candidate != null and token().matches(candidate)


func accepts(candidate: RunFlowToken) -> bool:
	return matches(candidate) and not is_terminal()


func is_terminal() -> bool:
	return _phase == Phase.FAILED or _phase == Phase.COMPLETED


func snapshot() -> Dictionary:
	return {
		&"phase": int(_phase),
		&"run_id": _run_id,
		&"floor_number": _floor_number,
		&"node_id": _node_id,
		&"node_kind": _node_kind,
		&"phase_id": _phase_id,
		&"battle_plan": serialize_battle_plan(_battle_plan),
	}


func restore(value: Dictionary) -> bool:
	for key: StringName in [
		&"phase", &"run_id", &"floor_number", &"node_id", &"node_kind", &"phase_id", &"battle_plan",
	]:
		if not value.has(key):
			return false
	var restored_phase := int(value[&"phase"])
	var restored_run_id := int(value[&"run_id"])
	var restored_floor := int(value[&"floor_number"])
	var restored_node := int(value[&"node_id"])
	var restored_phase_id := int(value[&"phase_id"])
	if restored_phase < Phase.CHOOSING_NODE or restored_phase > Phase.DEVIL_SHOP_ACTIVE \
			or restored_run_id <= 0 or restored_floor <= 0 or restored_node <= 0 \
			or restored_phase_id <= 0:
		return false
	var plan := deserialize_battle_plan(value[&"battle_plan"] as Dictionary)
	if restored_phase == Phase.BATTLE_ACTIVE:
		if plan == null:
			return false
	elif plan != null and restored_phase != Phase.REWARD_ACTIVE:
		return false
	_phase = restored_phase as Phase
	_run_id = restored_run_id
	_floor_number = restored_floor
	_node_id = restored_node
	_node_kind = StringName(value[&"node_kind"])
	_phase_id = restored_phase_id
	if plan != null:
		_set_battle(plan)
	else:
		_clear_battle()
	return true


static func serialize_battle_plan(plan: BattlePlan) -> Dictionary:
	if plan == null or not plan.is_valid():
		return {}
	var entries: Array[Dictionary] = []
	for entry: BattleGroupDef.EnemyEntry in plan.group.enemy_entries:
		if entry == null or entry.scene == null or entry.scene.resource_path.is_empty():
			return {}
		entries.append({
			&"scene_path": entry.scene.resource_path,
			&"position": entry.position,
			&"health": entry.health,
			&"attack_profile_path": entry.attack_profile.resource_path \
				if entry.attack_profile != null else "",
		})
	return {
		&"battle_id": plan.battle_id,
		&"origin": int(plan.origin),
		&"reward_policy": int(plan.reward_policy),
		&"group": {
			&"id": plan.group.id,
			&"title": plan.group.title,
			&"kind": int(plan.group.kind),
			&"level_def_path": plan.group.level_def.resource_path \
				if plan.group.level_def != null else "",
			&"enemy_entries": entries,
		},
	}


static func deserialize_battle_plan(value: Dictionary) -> BattlePlan:
	if value.is_empty():
		return null
	for key: StringName in [&"battle_id", &"origin", &"reward_policy", &"group"]:
		if not value.has(key):
			return null
	if not value[&"group"] is Dictionary:
		return null
	var group_data := value[&"group"] as Dictionary
	for key: StringName in [&"id", &"title", &"kind", &"level_def_path", &"enemy_entries"]:
		if not group_data.has(key):
			return null
	var origin := int(value[&"origin"])
	var reward := int(value[&"reward_policy"])
	var kind := int(group_data[&"kind"])
	if origin < BattlePlan.Origin.RUN_START or origin > BattlePlan.Origin.BOSS \
			or reward < BattlePlan.RewardPolicy.NONE or reward > BattlePlan.RewardPolicy.ELITE \
			or kind < BattleGroupDef.Kind.WEAK_NORMAL or kind > BattleGroupDef.Kind.BOSS \
			or not group_data[&"enemy_entries"] is Array:
		return null
	var entries: Array[BattleGroupDef.EnemyEntry] = []
	for raw: Variant in group_data[&"enemy_entries"] as Array:
		if not raw is Dictionary:
			return null
		var entry_data := raw as Dictionary
		var scene_path := String(entry_data.get(&"scene_path", ""))
		var scene := load(scene_path) as PackedScene
		var health := int(entry_data.get(&"health", 0))
		var attack_profile_path := String(entry_data.get(&"attack_profile_path", ""))
		var attack_profile: Resource = null
		if not attack_profile_path.is_empty():
			if not ResourceLoader.exists(attack_profile_path):
				return null
			attack_profile = load(attack_profile_path) as Resource
			if attack_profile == null:
				return null
		if scene == null or health <= 0 or not entry_data.get(&"position") is Vector2:
			return null
		var entry := BattleGroupDef.EnemyEntry.new()
		entry.scene = scene
		entry.position = entry_data[&"position"] as Vector2
		entry.health = health
		entry.attack_profile = attack_profile
		entries.append(entry)
	if entries.is_empty():
		return null
	var group := BattleGroupDef.new()
	group.id = String(group_data[&"id"])
	group.title = String(group_data[&"title"])
	group.kind = kind as BattleGroupDef.Kind
	var level_path := String(group_data[&"level_def_path"])
	group.level_def = load(level_path) as Resource if not level_path.is_empty() else null
	if not level_path.is_empty() and group.level_def == null:
		return null
	group.enemy_entries = entries
	var plan := BattlePlan.new(
		StringName(value[&"battle_id"]), group, origin as BattlePlan.Origin,
		reward as BattlePlan.RewardPolicy
	)
	return plan if plan.is_valid() else null


func _transition(next_phase: Phase) -> bool:
	if _run_id <= 0 or is_terminal():
		return false
	_phase = next_phase
	_phase_id += 1
	return true


func _set_battle(plan: BattlePlan) -> void:
	_battle_plan = plan
	_battle_origin = plan.origin
	_reward_policy = plan.reward_policy


func _clear_battle() -> void:
	_battle_plan = null
	_battle_origin = BattlePlan.Origin.NODE
	_reward_policy = BattlePlan.RewardPolicy.NONE


func _can_advance_node() -> bool:
	if _run_id <= 0 or is_terminal():
		return false
	return _phase == Phase.REWARD_ACTIVE or _phase == Phase.EVENT_ACTIVE \
		or _phase == Phase.EVENT_RESULT_ACTIVE or _phase == Phase.UPGRADE_ACTIVE \
		or _phase == Phase.NORMAL_SHOP_ACTIVE or _phase == Phase.DEVIL_SHOP_ACTIVE
