extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const NormalProfile: Resource = preload(
	"res://Combat/battle/enemies/attack_warning/normal_profile.tres"
)


func test_checkpoint_round_trip_preserves_profile_and_null_entry() -> void:
	var state := _state_with_profiles()
	var snapshot: Dictionary = state.snapshot()
	var raw_entries: Array = snapshot[&"battle_plan"][&"group"][&"enemy_entries"]
	assert_eq(raw_entries[0][&"attack_profile_path"], NormalProfile.resource_path)
	assert_eq(raw_entries[1][&"attack_profile_path"], "")

	var restored := RunState.new()
	assert_true(restored.restore(snapshot))
	var entries: Array[BattleGroupDef.EnemyEntry] = restored.battle_plan.group.enemy_entries
	assert_eq(entries.size(), 2)
	assert_not_null(entries[0].attack_profile)
	assert_eq(entries[0].attack_profile.resource_path, NormalProfile.resource_path)
	assert_null(entries[1].attack_profile)


func test_checkpoint_restore_accepts_legacy_entries_without_profile_path() -> void:
	var snapshot: Dictionary = _state_with_profiles().snapshot()
	var raw_entries: Array = snapshot[&"battle_plan"][&"group"][&"enemy_entries"]
	for raw_entry: Variant in raw_entries:
		(raw_entry as Dictionary).erase(&"attack_profile_path")

	var restored := RunState.new()
	assert_true(restored.restore(snapshot))
	for entry: BattleGroupDef.EnemyEntry in restored.battle_plan.group.enemy_entries:
		assert_null(entry.attack_profile)


func test_checkpoint_restore_rejects_non_resource_attack_profile_path() -> void:
	var snapshot: Dictionary = _state_with_profiles().snapshot()
	var raw_entries: Array = snapshot[&"battle_plan"][&"group"][&"enemy_entries"]
	(raw_entries[0] as Dictionary)[&"attack_profile_path"] = "res://missing_attack_profile.tres"

	var restored := RunState.new()
	assert_false(restored.restore(snapshot))


func _state_with_profiles() -> RunState:
	var state := RunState.new()
	assert_true(state.begin_run())
	var group := BattleGroupDef.new()
	group.id = "attack_profile_checkpoint"
	group.kind = BattleGroupDef.Kind.WEAK_NORMAL

	var profiled_entry := BattleGroupDef.EnemyEntry.new()
	profiled_entry.scene = EnemyScene
	profiled_entry.position = Vector2(20, 30)
	profiled_entry.health = 47
	profiled_entry.attack_profile = NormalProfile
	group.enemy_entries.append(profiled_entry)

	var null_entry := BattleGroupDef.EnemyEntry.new()
	null_entry.scene = EnemyScene
	null_entry.position = Vector2(40, 50)
	null_entry.health = 31
	group.enemy_entries.append(null_entry)

	var plan := BattlePlan.new(
		&"attack_profile_checkpoint", group, BattlePlan.Origin.RUN_START,
		BattlePlan.RewardPolicy.NORMAL
	)
	assert_true(state.begin_first_battle(plan))
	return state
