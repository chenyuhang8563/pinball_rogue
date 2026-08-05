extends GutTest

const FactoryScript: GDScript = preload("res://Run/application/battle_plan_factory.gd")
const OriginScript: GDScript = preload("res://Run/domain/battle_plan_origin.gd")
const RandomSourceScript: GDScript = preload("res://Run/application/run_random_source.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const NormalProfile: Resource = preload(
	"res://Combat/battle/enemies/attack_warning/normal_profile.tres"
)
const EliteProfile: Resource = preload(
	"res://Combat/battle/enemies/attack_warning/elite_profile.tres"
)


class RejectingEnemy extends Enemy:
	func configure_attack(_profile: Resource) -> bool:
		return false


var _floor_config: RunFloorConfig


func before_each() -> void:
	_floor_config = RunFloorConfig.new()
	_floor_config.boss_floor = 12


func test_factory_maps_role_defaults_and_explicit_override() -> void:
	var factory: BattlePlanFactory = FactoryScript.new()
	assert_true(factory.configure({&"normal": _level_with_attack_profile_spawns()}))

	var result: BattlePlanResult = factory.create(
		3, OriginScript.normal_node(), _floor_config, RandomSourceScript.new(7)
	)

	assert_true(result.is_ok())
	var entries: Array[BattleGroupDef.EnemyEntry] = result.plan.group.enemy_entries
	assert_eq(entries.size(), 4)
	_assert_profile(entries[0], NormalProfile)
	_assert_profile(entries[1], EliteProfile)
	_assert_profile(entries[2], null)
	_assert_profile(entries[3], EliteProfile)


func test_fallback_profiles_follow_their_group_formation() -> void:
	var weak_result := _fallback_result(&"weak", OriginScript.run_start(), 1)
	for entry: BattleGroupDef.EnemyEntry in weak_result.plan.group.enemy_entries:
		_assert_profile(entry, NormalProfile)

	var normal_result := _fallback_result(&"normal", OriginScript.normal_node(), 3)
	for entry: BattleGroupDef.EnemyEntry in normal_result.plan.group.enemy_entries:
		_assert_profile(entry, NormalProfile)

	var elite_result := _fallback_result(&"elite", OriginScript.elite_node(), 3)
	_assert_profile(elite_result.plan.group.enemy_entries[0], EliteProfile)
	_assert_profile(elite_result.plan.group.enemy_entries[1], NormalProfile)
	_assert_profile(elite_result.plan.group.enemy_entries[2], NormalProfile)

	var boss_result := _fallback_result(&"boss", OriginScript.boss(), 12)
	for entry: BattleGroupDef.EnemyEntry in boss_result.plan.group.enemy_entries:
		_assert_profile(entry, null)


func test_spawner_rejects_attack_configuration_and_rolls_back() -> void:
	var container := Node2D.new()
	add_child_autofree(container)
	var spawner := BattleSpawner.new()
	spawner.enemy_container = container
	add_child_autofree(spawner)

	var group := BattleGroupDef.new()
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = _rejecting_enemy_scene()
	entry.position = Vector2(40, 50)
	entry.health = 37
	entry.attack_profile = NormalProfile
	group.enemy_entries = [entry]

	watch_signals(spawner)
	var register_calls: int = 0
	var registered := func(_batch_id: int, _entry_index: int, _enemy: Enemy) -> bool:
		register_calls += 1
		return true

	assert_false(spawner.start_batch(group, 4, registered))
	assert_signal_emitted_with_parameters(
		spawner, "spawn_batch_failed", [4, 0, &"attack_config_rejected"]
	)
	assert_eq(register_calls, 0)
	assert_eq(container.get_child_count(), 0)


func _fallback_result(
	content_key: StringName,
	origin: BattlePlanOrigin,
	floor_number: int
) -> BattlePlanResult:
	var factory: BattlePlanFactory = FactoryScript.new()
	var missing_level := LevelDef.new()
	assert_true(factory.configure({content_key: missing_level}))
	var result: BattlePlanResult = factory.create(
		floor_number, origin, _floor_config, RandomSourceScript.new(13)
	)
	assert_true(result.is_ok())
	return result


func _level_with_attack_profile_spawns() -> LevelDef:
	var root := Node2D.new()
	var spawn_root := Node2D.new()
	spawn_root.name = "EnemySpawns"
	root.add_child(spawn_root)
	spawn_root.owner = root

	var normal_spawn := LevelEnemySpawn.new()
	normal_spawn.name = "Normal"
	normal_spawn.enemy_scene = EnemyScene
	normal_spawn.position = Vector2(20, 20)
	spawn_root.add_child(normal_spawn)
	normal_spawn.owner = root

	var elite_spawn := LevelEnemySpawn.new()
	elite_spawn.name = "Elite"
	elite_spawn.enemy_scene = EnemyScene
	elite_spawn.role = LevelEnemySpawn.Role.ELITE
	elite_spawn.position = Vector2(40, 20)
	spawn_root.add_child(elite_spawn)
	elite_spawn.owner = root

	var boss_spawn := LevelEnemySpawn.new()
	boss_spawn.name = "Boss"
	boss_spawn.enemy_scene = EnemyScene
	boss_spawn.role = LevelEnemySpawn.Role.BOSS
	boss_spawn.position = Vector2(60, 20)
	spawn_root.add_child(boss_spawn)
	boss_spawn.owner = root

	var override_spawn := LevelEnemySpawn.new()
	override_spawn.name = "Override"
	override_spawn.enemy_scene = EnemyScene
	override_spawn.attack_profile_override = EliteProfile
	override_spawn.position = Vector2(80, 20)
	spawn_root.add_child(override_spawn)
	override_spawn.owner = root

	var packed_scene := PackedScene.new()
	assert_eq(packed_scene.pack(root), OK)
	root.free()
	var level := LevelDef.new()
	level.id = "attack_profiles"
	level.title = "Attack Profiles"
	level.kind = BattleGroupDef.Kind.STRONG_NORMAL
	level.enemy_pool = LevelDef.EnemyPool.STRONG
	level.level_scene = packed_scene
	return level


func _rejecting_enemy_scene() -> PackedScene:
	var root := RejectingEnemy.new()
	var packed_scene := PackedScene.new()
	assert_eq(packed_scene.pack(root), OK)
	root.free()
	return packed_scene


func _assert_profile(entry: BattleGroupDef.EnemyEntry, expected: Resource) -> void:
	if expected == null:
		assert_null(entry.attack_profile)
		return
	assert_not_null(entry.attack_profile)
	if entry.attack_profile != null:
		assert_eq(entry.attack_profile.resource_path, expected.resource_path)
