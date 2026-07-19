extends RefCounted
class_name BattlePlan

enum Origin {
	RUN_START,
	NODE,
	EVENT,
	BOSS,
}

enum RewardPolicy {
	NONE,
	NORMAL,
	ELITE,
}

var battle_id: StringName:
	get:
		return _battle_id
var group: BattleGroupDef:
	get:
		return _battle_group
## Compatibility alias for callers that still use the Phase 2 name.
var battle_group: BattleGroupDef:
	get:
		return group
var origin: Origin:
	get:
		return _origin
var reward_policy: RewardPolicy:
	get:
		return _reward_policy

var _battle_id: StringName = &""
var _battle_group: BattleGroupDef = null
var _origin: Origin = Origin.NODE
var _reward_policy: RewardPolicy = RewardPolicy.NONE


func _init(
	value_battle_id: StringName,
	value_battle_group: BattleGroupDef,
	value_origin: Origin,
	value_reward_policy: RewardPolicy
) -> void:
	_battle_id = value_battle_id
	_battle_group = value_battle_group
	_origin = value_origin
	_reward_policy = value_reward_policy


func is_valid() -> bool:
	return not _battle_id.is_empty() and _battle_group != null
