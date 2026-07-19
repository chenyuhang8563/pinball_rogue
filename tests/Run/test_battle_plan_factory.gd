extends GutTest

const FactoryScript: GDScript = preload("res://Run/battle_plan_factory.gd")
const OriginScript: GDScript = preload("res://Run/domain/battle_plan_origin.gd")
const RandomSourceScript: GDScript = preload("res://Run/run_random_source.gd")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")

var _floor_config: RunFloorConfig


func before_each() -> void:
	_floor_config = RunFloorConfig.new()
	_floor_config.boss_floor = 12


func test_first_floor_is_weak_run_start_with_normal_reward() -> void:
	var result := _create(1, OriginScript.run_start())

	assert_true(result.is_ok())
	assert_eq(result.plan.origin, BattlePlan.Origin.RUN_START)
	assert_eq(result.plan.reward_policy, BattlePlan.RewardPolicy.NORMAL)
	assert_eq(result.plan.group.kind, BattleGroupDef.Kind.WEAK_NORMAL)
	assert_eq(result.plan.group.enemy_entries.size(), 3)
	assert_eq(result.plan.group.enemy_entries[0].health, 15)
	assert_eq(result.plan.battle_group, result.plan.group, "compatibility getter keeps the same envelope group")
	assert_eq(result.plan.battle_id, &"run_start:normal:1")


func test_normal_and_elite_nodes_scale_health_from_floor() -> void:
	var normal_result := _create(4, OriginScript.normal_node())
	var elite_result := _create(4, OriginScript.elite_node())

	assert_true(normal_result.is_ok())
	assert_eq(normal_result.plan.origin, BattlePlan.Origin.NODE)
	assert_eq(normal_result.plan.reward_policy, BattlePlan.RewardPolicy.NORMAL)
	assert_eq(normal_result.plan.group.enemy_entries[0].health, 55)
	assert_true(elite_result.is_ok())
	assert_eq(elite_result.plan.origin, BattlePlan.Origin.NODE)
	assert_eq(elite_result.plan.reward_policy, BattlePlan.RewardPolicy.ELITE)
	assert_eq(elite_result.plan.group.kind, BattleGroupDef.Kind.ELITE)
	assert_eq(elite_result.plan.group.enemy_entries[0].health, 82)
	assert_eq(elite_result.plan.group.enemy_entries[1].health, 55)


func test_crossroads_is_event_elite_without_group_id_routing() -> void:
	var result := _create(5, OriginScript.crossroads())

	assert_true(result.is_ok())
	assert_eq(result.plan.origin, BattlePlan.Origin.EVENT)
	assert_eq(result.plan.reward_policy, BattlePlan.RewardPolicy.ELITE)
	assert_eq(result.plan.group.kind, BattleGroupDef.Kind.ELITE)
	assert_eq(result.plan.group.title, "EVENT_CROSSROADS_FIGHT_TITLE")
	assert_eq(result.plan.battle_id, &"event:elite:5")
	assert_eq(result.plan.group.enemy_entries[0].health, 60)


func test_boss_uses_boss_origin_and_no_reward() -> void:
	var result := _create(12, OriginScript.boss())

	assert_true(result.is_ok())
	assert_eq(result.plan.origin, BattlePlan.Origin.BOSS)
	assert_eq(result.plan.reward_policy, BattlePlan.RewardPolicy.NONE)
	assert_eq(result.plan.group.kind, BattleGroupDef.Kind.BOSS)
	assert_eq(result.plan.group.enemy_entries[0].health, 240)
	assert_eq(result.plan.group.enemy_entries[1].health, 70)


func test_missing_level_scene_uses_fallback_formation() -> void:
	var invalid_level := LevelDef.new()
	invalid_level.id = "missing_scene"
	var factory: BattlePlanFactory = FactoryScript.new()
	assert_true(factory.configure({&"normal": invalid_level}))

	var result: BattlePlanResult = factory.create(
		3, OriginScript.normal_node(), _floor_config, RandomSourceScript.new(1)
	)

	assert_true(result.is_ok())
	assert_eq(result.plan.group.enemy_entries.size(), 5)
	assert_eq(result.plan.group.enemy_entries[0].position, Vector2(64, 48))
	assert_eq(result.plan.group.enemy_entries[4].position, Vector2(120, 132))
	assert_eq(result.plan.group.enemy_entries[0].health, 50)


func test_spawn_pool_health_and_role_overrides_are_applied() -> void:
	var custom_level := _level_with_override_spawns()
	var factory: BattlePlanFactory = FactoryScript.new()
	assert_true(factory.configure({&"normal": custom_level}))

	var result: BattlePlanResult = factory.create(
		3, OriginScript.normal_node(), _floor_config, RandomSourceScript.new(9)
	)

	assert_true(result.is_ok())
	assert_eq(result.plan.group.enemy_entries.size(), 3)
	assert_eq(result.plan.group.enemy_entries[0].health, 25, "weak pool overrides strong level pool")
	assert_eq(result.plan.group.enemy_entries[1].health, 77, "health override wins over pool and role")
	assert_eq(result.plan.group.enemy_entries[2].health, 75, "elite role scales default strong pool")


func test_invalid_content_returns_typed_failure() -> void:
	var factory: BattlePlanFactory = FactoryScript.new()
	assert_false(factory.configure({&"normal": 17}))

	var result: BattlePlanResult = factory.create(
		3, OriginScript.normal_node(), _floor_config, RandomSourceScript.new(1)
	)

	assert_false(result.is_ok())
	assert_eq(result.error, BattlePlanResult.Code.INVALID_CONTENT)
	assert_null(result.plan)


func _create(floor_number: int, origin: BattlePlanOrigin) -> BattlePlanResult:
	var factory: BattlePlanFactory = FactoryScript.new()
	return factory.create(floor_number, origin, _floor_config, RandomSourceScript.new(1234))


func _level_with_override_spawns() -> LevelDef:
	var root := Node2D.new()
	root.name = "CustomLevel"
	var spawn_root := Node2D.new()
	spawn_root.name = "EnemySpawns"
	root.add_child(spawn_root)
	spawn_root.owner = root

	var weak_spawn := LevelEnemySpawn.new()
	weak_spawn.name = "WeakOverride"
	weak_spawn.enemy_scene = EnemyScene
	weak_spawn.pool_override = LevelEnemySpawn.PoolOverride.WEAK
	spawn_root.add_child(weak_spawn)
	weak_spawn.owner = root

	var health_spawn := LevelEnemySpawn.new()
	health_spawn.name = "HealthOverride"
	health_spawn.enemy_scene = EnemyScene
	health_spawn.role = LevelEnemySpawn.Role.BOSS
	health_spawn.health_override = 77
	spawn_root.add_child(health_spawn)
	health_spawn.owner = root

	var elite_spawn := LevelEnemySpawn.new()
	elite_spawn.name = "EliteRole"
	elite_spawn.enemy_scene = EnemyScene
	elite_spawn.role = LevelEnemySpawn.Role.ELITE
	spawn_root.add_child(elite_spawn)
	elite_spawn.owner = root

	var packed_scene := PackedScene.new()
	assert_eq(packed_scene.pack(root), OK)
	root.free()
	var level := LevelDef.new()
	level.id = "custom"
	level.title = "Custom"
	level.kind = BattleGroupDef.Kind.STRONG_NORMAL
	level.enemy_pool = LevelDef.EnemyPool.STRONG
	level.level_scene = packed_scene
	return level
